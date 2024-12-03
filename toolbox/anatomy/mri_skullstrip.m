function [MriFileMask, errMsg, fileTag, binBrainMask] = mri_skullstrip(MriFileSrc, MriFileRef, Method)
% MRI_SKULLSTRIP: Skull stripping on 'MriFileSrc' using 'MriFileRef' as reference MRI.
%                 Both volumes must have the same Cube and Voxel size
%
% USAGE:  [MriFileMask, errMsg, fileTag, binBrainMask] = mri_skullstrip(MriFileSrc, MriFileRef, Method)
%            [sMriMask, errMsg, fileTag, binBrainMask] = mri_skullstrip(sMriSrc,    sMriRef,    Method)
%
% INPUTS:
%    - MriFileSrc   : MRI structure or MRI file to apply skull stripping on
%    - MriFileRef   : MRI structure or MRI file to find brain masking for skull stripping
%                     If empty, the Default MRI for that Subject with 'MriFileSrc' is used
%    - Method       : If 'BrainSuite', use BrainSuite's Brain Surface Extractor (BSE)
%                     If 'SPM', use SPM Tissue Segmentation
%
% OUTPUTS:
%    - MriFileMask  : MRI structure or MRI file after skull stripping
%    - errMsg       : Error message. Empty if no error
%    - fileTag      : Tag added to the comment and filename
%    - binBrainMask : Volumetric binary mask of the skull stripped 'MriFileRef' reference MRI
%
% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Raymundo Cassani, 2024
%           Chinmay Chinara, 2024

% ===== PARSE INPUTS =====
% Parse inputs
if (nargin < 3)
    Method = [];
end

% Initialize outputs
MriFileMask  = [];
errMsg       = '';
fileTag      = '';
binBrainMask = [];

% Return if invalid Method
if isempty(Method) || strcmpi(Method, 'Skip')
    return;
end

% Progress bar
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'MRI skull stripping', 'Loading input volumes...');
end
% USAGE: mri_reslice(sMriSrc, sMriRef)
if isstruct(MriFileSrc)
    sMriSrc = MriFileSrc;
    sMriRef = MriFileRef;
    MriFileSrc = [];
    MriFileRef = [];
% USAGE: mri_reslice(MriFileSrc, MriFileRef)
elseif ischar(MriFileSrc)
    % Get the default MRI for this subject
    if isempty(MriFileRef)
        sSubject = bst_get('MriFile', MriFileSrc);
        MriFileRef = sSubject.Anatomy(sSubject.iAnatomy).FileName;
    end
    % Load MRI volumes
    sMriSrc = in_mri_bst(MriFileSrc);
    sMriRef = in_mri_bst(MriFileRef);
else
    error('Invalid call.');
end

% Check that same size
refSize = size(sMriRef.Cube(:,:,:,1));
srcSize = size(sMriSrc.Cube(:,:,:,1));
if ~all(refSize == srcSize) || ~all(round(sMriRef.Voxsize(1:3) .* 1000) == round(sMriSrc.Voxsize(1:3) .* 1000))
    errMsg = 'Skull stripping cannot be performed if the reference MRI has different size';
    return
end

% === SKULL STRIPPING ===
% Reset any previous logo
bst_plugin('SetProgressLogo', []);
switch lower(Method)
    case 'brainsuite'
        % Check for BrainSuite Installation
        [~, errMsg] = process_dwi2dti('CheckBrainSuiteInstall');
        if ~isempty(errMsg)
            bst_progress('text', 'Skipping skull stripping. BrainSuite not installed.');
            return
        end
        % Set the BrainSuite logo
        bst_progress('setimage', bst_fullfile(bst_get('BrainstormDocDir'), 'plugins', 'brainsuite_logo.png'));
        % Get temporary folder
        TmpDir = bst_get('BrainstormTmpDir', 0, 'brainsuite');
        % Save reference MRI in .nii format
        NiiRefFile = bst_fullfile(TmpDir, 'mri_ref.nii');
        out_mri_nii(sMriRef, NiiRefFile);
        % Perform skull stripping using Brain Surface Extractor (BSE)
        bst_progress('text', 'Skull Stripping: BrainSuite Brain Surface Extractor...');
        strCall = [...
            'bse -i "' NiiRefFile '" --auto' ...
            ' -o "'            fullfile(TmpDir, 'skull_stripped_mri.nii.gz"') ...
            ' --trim --mask "' fullfile(TmpDir, 'bse_smooth_brain.mask.nii.gz"') ...
            ' --hires "'       fullfile(TmpDir, 'bse_detailled_brain.mask.nii.gz"') ...
            ' --cortex "'      fullfile(TmpDir, 'bse_cortex_file.nii.gz"')];
        disp(['BST> System call: ' strCall]);
        status = system(strCall);
        % Error handling
        if (status ~= 0)
            errMsg = ['BrainSuite failed at step BSE.', 10, 'Check the Matlab command window for more information.'];
            return
        end
        % Get the brain mask
        NiiBrainMaskFile = bst_fullfile(TmpDir, 'bse_smooth_brain.mask.nii.gz');
        sMriBrainMask = in_mri(NiiBrainMaskFile, 'ALL', 0, 0);
        % Make it a binary mask
        sMriBrainMask.Cube = sMriBrainMask.Cube/255;
        % Some erosion to reduce any artefacts
        sMriBrainMask.Cube = sMriBrainMask.Cube & ~mri_dilate(~sMriBrainMask.Cube, 3);
        % Logic brain mask cube
        binBrainMask = sMriBrainMask.Cube > 0;
        % Temporary files to delete
        filesDel = TmpDir;

    case 'spm'
        % Check for SPM12 installation
        [isInstalledSpm, errMsg] = bst_plugin('Install', 'spm12');
        if ~isInstalledSpm
            bst_progress('text', 'Skipping skull stripping. SPM not installed.');
            return;
        end
        % Set the SPM logo
        bst_plugin('SetProgressLogo', 'spm12');
        % Perform skull stripping using SPM Tissue Segmentation
        bst_progress('text', 'Skull Stripping: SPM Segment...');
        % Reset matlabbatch to start fresh
        clear matlabbatch;
        % Get the TPM atlas
        TpmFile = bst_get('SpmTpmAtlas', 'SPM');
        % Get the SPM tissue segments
        [~, TpmFiles] = mri_normalize_segment(sMriRef, TpmFile);
        % Compute brain mask: union(GM, WM, CSF)
        sGm =  in_mri_nii(TpmFiles{2}, 0, 0, 0);
        sWm =  in_mri_nii(TpmFiles{1}, 0, 0, 0);
        sCsf = in_mri_nii(TpmFiles{3}, 0, 0, 0);
        binBrainMask = (sGm.Cube + sWm.Cube + sCsf.Cube) > 0;
        % Temporary files to delete
        filesDel = bst_fileparts(TpmFiles{1});

    otherwise
        errMsg = ['Invalid skull stripping method: ' Method];
        return
end
% Reset logo
bst_progress('removeimage');

% Apply brain mask
sMriMask = sMriSrc;
sMriMask.Cube(~binBrainMask) = 0;
% File tag
fileTag = sprintf('_masked_%s', lower(Method));

% ===== SAVE NEW FILE =====
% Add file tag
sMriMask.Comment = [sMriSrc.Comment, fileTag];
% Save output
if ~isempty(MriFileSrc)
    bst_progress('text', 'Saving new file...');
    % Get subject
    [sSubject, iSubject] = bst_get('MriFile', MriFileSrc);
    % Update comment
    sMriMask.Comment = file_unique(sMriMask.Comment, {sSubject.Anatomy.Comment});
    % Add history entry
    sMriMask = bst_history('add', sMriMask, 'resample', ['Skull stripping with "' Method '" using on default file: ' MriFileRef]);
    % Save new file
    MriFileMaskFull = file_unique(strrep(file_fullpath(MriFileSrc), '.mat', [fileTag '.mat']));
    MriFileMask = file_short(MriFileMaskFull);
    % Save new MRI in Brainstorm format
    sMriMask = out_mri_bst(sMriMask, MriFileMaskFull);

    % Register new MRI
    iAnatomy = length(sSubject.Anatomy) + 1;
    sSubject.Anatomy(iAnatomy) = db_template('Anatomy');
    sSubject.Anatomy(iAnatomy).FileName = MriFileMask;
    sSubject.Anatomy(iAnatomy).Comment  = sMriMask.Comment;
    % Update subject structure
    bst_set('Subject', iSubject, sSubject);
    % Refresh tree
    panel_protocols('UpdateNode', 'Subject', iSubject);
    panel_protocols('SelectNode', [], 'anatomy', iSubject, iAnatomy);
    % Save database
    db_save();
else
    % Return output structure
    MriFileMask = sMriMask;
end

% Delete the temporary files
file_delete(filesDel, 1, 1);
% Close progress bar
if ~isProgress
    bst_progress('stop');
end