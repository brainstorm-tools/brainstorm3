function [atlasLabels, MriFileRescale, errMsg, fileTag] = mri_rescale(MriFile, AtlasName, roiName, sSubject)
% MRI_RESCALE: Rescale an MRI volume by the mean value of a specified ROI in an atlas.
%
% USAGE:
%   [atlasLabels, MriFileRescale, errMsg, fileTag] = mri_rescale(MriFile, 'ASEG', 'Cerebellum')
%   [atlasLabels, sMriRescale, errMsg, fileTag] = mri_rescale(sMri, 'ASEG', 'Cerebellum', sSubject)
%
% INPUTS:
%   - MriFile   : MRI file to be rescaled (string or struct)
%   - AtlasName : Name of the atlas (e.g., 'ASEG', 'DKT', etc.)
%   - roiName   : Name of the ROI to use for rescaling (string)
%   - sSubject  : (optional) Subject structure, required if MriFile is a structure
%
% OUTPUTS:
%   - atlasLabels    : Cell array of region names in the atlas
%   - MriFileRescale : Path to the rescaled MRI file (string) or structure if input is struct
%   - errMsg         : Error message, if any
%   - fileTag        : File tag used for output file

atlasLabels = {};
MriFileRescale = [];
errMsg = '';
fileTag = '';

try
    % Progress bar
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'Rescaling', 'Loading input volumes...');
end

    if isstruct(MriFile)
        sMri = MriFile;
        if nargin < 4 || isempty(sSubject)
            errMsg = 'sSubject must be provided when using sMri structure as input.';
            return;
        end
        mriFilePath = '';
    elseif ischar(MriFile)
        sMri = in_mri_bst(MriFile);
        [sSubject, ~, ~] = bst_get('MriFile', MriFile);
        mriFilePath = MriFile;
    else
        bst_progress('stop');
        error('Invalid call.');
    end
bst_progress('stop');
    % Mask region
    [atlasLabels, ~, errMsg, maskFileTag, binMask] = mri_mask(sMri, AtlasName, roiName, 1, sSubject);
  
    if ~isempty(errMsg)
        return;
    end

    if isempty(sMri) || ~isfield(sMri, 'Cube')
        errMsg = 'Could not load MRI volume.';
        return;
    end

    % Compute mean value in the ROI
    roiVals = double(sMri.Cube(binMask));
    if isempty(roiVals) || all(roiVals == 0)
        errMsg = sprintf('No nonzero voxels found in ROI "%s".', roiName);
        return;
    end
    roiMean = mean(roiVals);

    % Rescale MRI volume
    sMriRescale = sMri;
    sMriRescale.Cube = double(sMri.Cube) ./ roiMean;

    % Carry over fileTag and append rescale tag before last underscore
    rescaleTag = sprintf('_rescaled_%s_%s', lower(AtlasName), lower(roiName));
    fileTag = [maskFileTag, rescaleTag];

    % Carry over history from mri_mask if present
    if isfield(sMri, 'History')
        sMriRescale.History = sMri.History;
    end

    % Update comment
    sMriRescale.Comment = [sMri.Comment, rescaleTag];

    % ===== SAVE NEW FILE =====
    if ~isempty(mriFilePath) && ischar(mriFilePath)
        bst_progress('text', 'Saving new file...');
        [sSubject, iSubject] = bst_get('MriFile', mriFilePath);
        if isempty(sSubject) || ~isfield(sSubject, 'Anatomy')
            errMsg = 'Could not find subject for the provided MRI file.';
            return;
        end
        % Insert rescaleTag before the last underscore-tag
        [folder, base, ext] = fileparts(file_fullpath(mriFilePath));
        lastUnderscore = find(base == '_', 1, 'last');
        if ~isempty(lastUnderscore)
            newBase = [base(1:lastUnderscore-1), rescaleTag, base(lastUnderscore:end)];
        else
            newBase = [base, rescaleTag];
        end
        MriFileRescaleFull = file_unique(fullfile(folder, [newBase, ext]));
        MriFileRescale = file_short(MriFileRescaleFull);
        % Update comment to be unique
        sMriRescale.Comment = file_unique(sMriRescale.Comment, {sSubject.Anatomy.Comment});
        % Add history entry
        sMriRescale = bst_history('add', sMriRescale, 'rescale', ...
            sprintf('Rescaled with "%s" (%s)', AtlasName, roiName));
        % Save new MRI in Brainstorm format
        sMriRescale = out_mri_bst(sMriRescale, MriFileRescaleFull);
        % Register new MRI in subject
        iAnatomy = length(sSubject.Anatomy) + 1;
        sSubject.Anatomy(iAnatomy) = db_template('Anatomy');
        sSubject.Anatomy(iAnatomy).FileName = MriFileRescale;
        sSubject.Anatomy(iAnatomy).Comment  = sMriRescale.Comment;
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
        MriFileRescale = sMriRescale;
        bst_progress('stop');
        return;
    end
catch ME
    errMsg = ME.message;
end