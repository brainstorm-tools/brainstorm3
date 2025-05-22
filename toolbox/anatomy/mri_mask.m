function [atlasLabels, MriFileMask, errMsg, fileTag, binMask] = mri_mask(MriFile, AtlasName, maskRegion, doMask, sSubject)
% MRI_MASK: List atlas regions and optionally mask an MRI volume using a selected atlas and region.
%
% USAGE:
%   atlasLabels = mri_mask([], 'ASEG'); % List all regions in ASEG atlas for current subject
%   [atlasLabels, MriFileMask] = mri_mask(MriFile, 'ASEG', 'cerebellum', 1);
%   [atlasLabels, sMriMasked] = mri_mask(sMri, 'ASEG', 'cerebellum', 1, sSubject);
%
% INPUTS:
%   - MriFile   : MRI file to be masked (string) or MRI structure (sMri)
%   - AtlasName : Name of the atlas (e.g., 'ASEG', 'DKT', etc.)
%   - maskRegion: (optional) Region name or cell array of region names to mask (e.g., 'cerebellum', {'cortex','wm'})
%   - doMask    : (optional) 1 to perform masking, 0 (default) to only list labels
%   - sSubject  : (optional) Subject structure, required if MriFile is a structure
%
% OUTPUTS:
%   - atlasLabels : Cell array of region names in the atlas (bilateral names, see below)
%   - MriFileMask : Masked MRI file (if doMask==1 and file input), or masked MRI structure (if struct input)
%   - errMsg      : Error message, if any
%   - fileTag     : File tag used for output file
%   - binMask     : Binary mask used for masking (if doMask==1), otherwise []
%
% Authors: Diellor Basha, 2025

% Defaults
if nargin < 3, maskRegion = []; end
if nargin < 4, doMask = 0; end
if nargin < 5, sSubject = []; end
MriFileMask = [];
errMsg = '';
fileTag = '';
binMask = [];
isSaving = false;

% Progress bar
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'Masking', 'Loading input volumes...');
end

% Load MRI and get subject if possible
if isstruct(MriFile)
    sMri = MriFile;
    if isempty(sSubject)
        errMsg = 'sSubject must be provided when using sMri structure as input.';
        return;
    end
    mriFilePath = '';
    isSaving = false;
elseif ischar(MriFile)
    sMri = in_mri_bst(MriFile);
    mriFilePath = MriFile;
    [sSubject, iSubject, iMri] = bst_get('MriFile', MriFile);
    isSaving = true;
else
    bst_progress('stop');
    error('Invalid call.');
end
bst_progress('stop');
% Get atlas file for the correct subject
if ~isempty(sSubject)
    iAtlas = bst_get('AtlasFile', sSubject, AtlasName);
else
    % If no subject context, try to get atlas for current subject
    iAtlas = bst_get('AtlasFile', AtlasName);
end
if isempty(iAtlas) || ~isfield(iAtlas, 'FileName') || isempty(iAtlas.FileName)
    errMsg = ['Atlas "' AtlasName '" not found for the specified subject.'];
    atlasLabels = {};
    return;
end

% Load the atlas structure
[sAtlas, ~] = bst_memory('LoadMri', iAtlas.FileName);
if isempty(sAtlas) || ~isfield(sAtlas, 'Labels') || isempty(sAtlas.Labels)
    errMsg = ['Failed to load atlas file: ' iAtlas.FileName];
    atlasLabels = {};
    return;
end

% Original label names
labelNames = sAtlas.Labels(:,2);

% Initialize bilateral names array
bilateralNames = labelNames;
for i = 1:length(bilateralNames)
    % Remove trailing ' L' or ' R'
    bilateralNames{i} = regexprep(bilateralNames{i}, ' [LR]$', '');
    % Replace any label starting with 'CC_' with 'Corpus-Callosum'
    if startsWith(bilateralNames{i}, 'CC_')
        bilateralNames{i} = 'Corpus-Callosum';
    end
    % Replace any label containing 'Ventricle' with 'Ventricles'
    if contains(bilateralNames{i}, 'Ventricle')
        bilateralNames{i} = 'Ventricles';
    end
end

% Add "Brainmask" to the top of the list and exclude "Unknown" from returned labels
atlasLabels = unique(bilateralNames, 'stable');
atlasLabels = setdiff(atlasLabels, {'Unknown'}, 'stable');
atlasLabels = [{'Brainmask'}, atlasLabels(:)'];

% If only listing labels, return here
if ~doMask || isempty(sMri)
    return;
end

% Determine which atlas labels to use for masking
if isempty(maskRegion)
    errMsg = 'No mask region specified.';
    return;
end
if ischar(maskRegion)
    maskRegion = {maskRegion};
end

% Special handling for "Brainmask"
if any(strcmpi(maskRegion, 'Brainmask'))
    % Exclude "Unknown" and "WM-hypointensities"
    excludeLabels = {'Unknown', 'WM-hypointensities'};
    labelIdx = find(~ismember(bilateralNames, [{'Brainmask'}, excludeLabels]));
else
    % Find label indices matching the requested region(s) (case-insensitive, exact match)
    labelIdx = [];
    for i = 1:numel(maskRegion)
        idx = find(strcmpi(bilateralNames, maskRegion{i}));
        labelIdx = [labelIdx, idx];
    end
    labelIdx = unique(labelIdx);
end

if isempty(labelIdx)
    errMsg = ['Region "' strjoin(maskRegion, ', ') '" not found in atlas "' AtlasName '".'];
    return;
end

% Get label values for the selected regions
labelValues = cell2mat(sAtlas.Labels(labelIdx, 1));

% Create binary mask
binMask = ismember(sAtlas.Cube, labelValues);

% Apply mask to MRI
sMriMasked = sMri;
sMriMasked.Cube(~binMask) = 0;

% File tag
fileTag = sprintf('_masked_%s_%s', lower(AtlasName), lower(strjoin(maskRegion, '_')));

% ===== SAVE NEW FILE =====
if isSaving
   bst_progress('text', 'Saving new file...');
    % Get subject and index
    [sSubject, iSubject] = bst_get('MriFile', mriFilePath);
    if isempty(sSubject) || ~isfield(sSubject, 'Anatomy')
        errMsg = 'Could not find subject for the provided MRI file.';
        return;
    end
    % Insert fileTag before the last underscore-tag (e.g., before _volpet or _volct)
    [folder, base, ext] = fileparts(file_fullpath(mriFilePath));
    lastUnderscore = find(base == '_', 1, 'last');
    if ~isempty(lastUnderscore)
        newBase = [base(1:lastUnderscore-1), fileTag, base(lastUnderscore:end)];
    else
        newBase = [base, fileTag];
    end
    MriFileMaskFull = file_unique(fullfile(folder, [newBase, ext]));
    MriFileMask = file_short(MriFileMaskFull);
    % Update comment to be unique
    sMriMasked.Comment = file_unique([sMri.Comment, fileTag], {sSubject.Anatomy.Comment});
    % Add history entry
    sMriMasked = bst_history('add', sMriMasked, 'mask', ...
        sprintf('Masked with "%s" (%s)', AtlasName, strjoin(maskRegion, ', ')));
    % Save new MRI in Brainstorm format
    sMriMasked = out_mri_bst(sMriMasked, MriFileMaskFull);
    % Register new MRI in subject
    iAnatomy = length(sSubject.Anatomy) + 1;
    sSubject.Anatomy(iAnatomy) = db_template('Anatomy');
    sSubject.Anatomy(iAnatomy).FileName = MriFileMask;
    sSubject.Anatomy(iAnatomy).Comment  = sMriMasked.Comment;
    % Update subject structure
    bst_set('Subject', iSubject, sSubject);
    % Refresh tree
    panel_protocols('UpdateNode', 'Subject', iSubject);
    panel_protocols('SelectNode', [], 'anatomy', iSubject, iAnatomy);
    % Save database
    db_save();
    bst_progress('stop');
    return;
else
    % Return output structure if not saving to disk, and output fileTag
    MriFileMask = sMriMasked;
    bst_progress('stop');
    return;
end
