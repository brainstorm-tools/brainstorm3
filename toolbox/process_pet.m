function [MriFileOut, errMsg] = process_pet(MriFile, sSubject, AtlasName, roiName, maskROI, applyMask)
% PROCESS_PET: Script PET processing pipeline (SUVR rescale and/or masking) with minimal redundant saving.
%
% INPUTS:
%   - MriFile   : Input MRI file path (string)
%   - sSubject  : Subject structure
%   - AtlasName : Name of the atlas (e.g., 'ASEG')
%   - roiName   : Name of the ROI for SUVR rescale (string, can be empty)
%   - maskROI   : Name of the ROI for masking (string, can be empty)
%   - applyMask : Logical, true to apply mask, false otherwise
%
% OUTPUTS:
%   - MriFileOut : Output MRI file path (string)
%   - errMsg     : Error message, if any

MriFileOut = '';
errMsg = '';

try
    % Load MRI structure
    sMri = in_mri_bst(MriFile);

    % --- SUVR Rescale ---
    if ~isempty(roiName)
        [~, sMriRescale, errMsgRescale, fileTagRescale] = mri_rescale(sMri, AtlasName, roiName, sSubject);
        if ~isempty(errMsgRescale)
            errMsg = errMsgRescale;
            return;
        end
        sMri = sMriRescale;
        fileTag = fileTagRescale;
    else
        fileTag = '';
    end

    % --- Masking (if requested) ---
    if applyMask && ~isempty(maskROI)
        [~, sMriMasked, errMsgMask, fileTagMask] = mri_mask(sMri, AtlasName, maskROI, 1, sSubject);
        if ~isempty(errMsgMask)
            errMsg = errMsgMask;
            return;
        end
        sMri = sMriMasked;
        % Combine tags for output file
        fileTag = [fileTag, fileTagMask];
    end

    % --- Save output file manually (like mri_realign) ---
    % Insert fileTag before last underscore
    [folder, base, ext] = fileparts(file_fullpath(MriFile));
    lastUnderscore = find(base == '_', 1, 'last');
    if ~isempty(lastUnderscore)
        newBase = [base(1:lastUnderscore-1), fileTag, base(lastUnderscore:end)];
    else
        newBase = [base, fileTag];
    end
    MriFileOutFull = file_unique(fullfile(folder, [newBase, ext]));
    MriFileOut = file_short(MriFileOutFull);

    % Update comment to be unique
    if isfield(sSubject, 'Anatomy')
        sMri.Comment = file_unique([sMri.Comment, fileTag], {sSubject.Anatomy.Comment});
    else
        sMri.Comment = [sMri.Comment, fileTag];
    end

    % Add history entry
    if ~isempty(roiName)
        sMri = bst_history('add', sMri, 'rescale', sprintf('Rescaled with "%s" (%s)', AtlasName, roiName));
    end
    if applyMask && ~isempty(maskROI)
        sMri = bst_history('add', sMri, 'mask', sprintf('Masked with "%s" (%s)', AtlasName, maskROI));
    end

    % Save new MRI in Brainstorm format
    sMri = out_mri_bst(sMri, MriFileOutFull);

    % Register new MRI in subject
    [~, iSubject] = bst_get('Subject', sSubject.Name);
    iAnatomy = length(sSubject.Anatomy) + 1;
    sSubject.Anatomy(iAnatomy) = db_template('Anatomy');
    sSubject.Anatomy(iAnatomy).FileName = MriFileOut;
    sSubject.Anatomy(iAnatomy).Comment  = sMri.Comment;
    bst_set('Subject', iSubject, sSubject);

    % Refresh tree and save database
    panel_protocols('UpdateNode', 'Subject', iSubject);
    panel_protocols('SelectNode', [], 'anatomy', iSubject, iAnatomy);
    db_save();

if isfield(sSubject, 'iAnatomy') && ~isempty(sSubject.iAnatomy) && ...
        isfield(sSubject, 'Anatomy') && length(sSubject.Anatomy) >= sSubject.iAnatomy
    refMriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
else
    refMriFile = sSubject.Anatomy(1).FileName;
end
view_mri(refMriFile, MriFileOut);

catch ME
    errMsg = ME.message;
end