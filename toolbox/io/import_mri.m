function [BstMriFile, sMri, Messages] = import_mri(iSubject, MriFile, FileFormat, isInteractive, isAutoAdjust, Comment, Labels)
% IMPORT_MRI: Import a volume file (MRI, Atlas, CT, PET, etc) in a subject of the Brainstorm database
% 
% USAGE: [BstMriFile, sMri, Messages] = import_mri(iSubject, MriFile, FileFormat='ALL', isInteractive=0, isAutoAdjust=1, Comment=[], Labels=[])
%               BstMriFiles = import_mri(iSubject, MriFiles, ...)   % Import multiple volumes at once
%
% INPUT:
%    - iSubject  : Indice of the subject where to import the MRI
%                  If iSubject=0 : import MRI in default subject
%    - MriFile   : Full filename of the MRI to import (format is autodetected)
%                  => if not specified : file to import is asked to the user
%    - FileFormat : String, one on the file formats in in_mri
%    - isInteractive : If 1, importation will be interactive (MRI is displayed after loading)
%    - isAutoAdjust  : If isInteractive=0 and isAutoAdjust=1, relice/resample automatically without user confirmation
%    - Comment       : Comment of the output file
%    - Labels        : Labels attached to this file (cell array {Nlabels x 3}: {index, text, RGB})
% OUTPUT:
%    - BstMriFile : Full path to the new file if success, [] if error
%    - sMri       : Brainstorm MRI structure
%    - Messages   : String, messages reported by this function

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
% Authors: Francois Tadel, 2008-2023
%          Chinmay Chinara, 2023

%% ===== PARSE INPUTS =====
if (nargin < 3) || isempty(FileFormat)
    FileFormat = 'ALL';
end
if (nargin < 4) || isempty(isInteractive)
    isInteractive = 0;
end
if (nargin < 5) || isempty(isAutoAdjust)
    isAutoAdjust = 1;
end
if (nargin < 6) || isempty(Comment)
    Comment = [];
end
if (nargin < 7) || isempty(Labels)
    Labels = [];
end
% Initialize returned variables
BstMriFile = [];
sMri = [];
Messages = [];
% Get Protocol information
ProtocolInfo     = bst_get('ProtocolInfo');
ProtocolSubjects = bst_get('ProtocolSubjects');
% Default subject
if (iSubject == 0)
	sSubject = ProtocolSubjects.DefaultSubject;
% Normal subject 
else
    sSubject = ProtocolSubjects.Subject(iSubject);
end
% Volume type
volType = 'MRI';
if ~isempty(strfind(Comment, 'CT'))
    volType = 'CT';
end
if ~isempty(strfind(Comment, 'PET'))
    volType = 'PET';
end
% Get node comment from filename
if ~isempty(strfind(Comment, 'Import'))
    Comment = [];
end

%% ===== SELECT MRI FILE =====
% If MRI file to load was not defined : open a dialog box to select it
if isempty(MriFile)    
    % Get last used directories
    LastUsedDirs = bst_get('LastUsedDirs');
    % Get last used format
    DefaultFormats = bst_get('DefaultFormats');
    if isempty(DefaultFormats.MriIn)
        DefaultFormats.MriIn = 'ALL';
    end

    % Get MRI/CT file
    [MriFile, FileFormat, FileFilter] = java_getfile( 'open', ...
        ['Import ' volType '...'], ...   % Window title
        LastUsedDirs.ImportAnat, ...      % Default directory
        'multiple', 'files_and_dirs', ... % Selection mode
        bst_get('FileFilters', 'mri'), ...
        DefaultFormats.MriIn);
    % If no file was selected: exit
    if isempty(MriFile)
        return
    end
    % Expand file selection (if inputs are folders)
    MriFile = file_expand_selection(FileFilter, MriFile);
    if isempty(MriFile)
        error(['No ' FileFormat ' file in the selected directories.']);
    end
    % Save default import directory
    LastUsedDirs.ImportAnat = bst_fileparts(MriFile{1});
    bst_set('LastUsedDirs', LastUsedDirs);
    % Save default import format
    DefaultFormats.MriIn = FileFormat;
    bst_set('DefaultFormats',  DefaultFormats);
end

%% ===== DICOM CONVERTER =====
TmpDir = [];
if strcmpi(FileFormat, 'DICOM-SPM')
    % Convert DICOM to NII
    DicomFiles = MriFile;
    TmpDir = bst_get('BrainstormTmpDir', 0, 'dicom');
    MriFile = in_mri_dicom_spm(DicomFiles, TmpDir, isInteractive);
    if isempty(MriFile)
        return;
    end
    FileFormat = 'Nifti1';
end

%% ===== LOOP ON MULTIPLE MRI =====
if iscell(MriFile) && (length(MriFile) == 1)
    MriFile = MriFile{1};
elseif iscell(MriFile) && ~strcmpi(FileFormat, 'SPM-TPM')
    % Only allow multiple import if there is already a MRI
    if isempty(sSubject.Anatomy)
        error(['You must import the first MRI in the subject folder separately.' 10 'Please select only one volume at a time.']);
    end
    % Initialize returned values
    nFiles = length(MriFile);
    BstMriFile = cell(1, nFiles);
    sMri = cell(1, nFiles);
    % Import all volumes without supervision
    for i = 1:nFiles
        [BstMriFile{i}, sMri{i}] = import_mri(iSubject, MriFile{i}, FileFormat, isInteractive, isAutoAdjust);
    end
    % All the files are imported: exit
    return;
end

%% ===== LOAD MRI FILE =====
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', ['Import ', volType], ['Loading ', volType, ' file...']);
end
% MNI / Atlas / CT / PET?
isMni   = ismember(FileFormat, {'ALL-MNI', 'ALL-MNI-ATLAS'});
isAtlas = ismember(FileFormat, {'ALL-ATLAS', 'ALL-MNI-ATLAS', 'SPM-TPM'});
isCt    = strcmpi(volType, 'CT');
isPet = strcmpi(volType,'PET');
% Tag for CT volume
if isCt
    tagVolType = '_volct';
    isAtlas = 0;
elseif isPet
    tagVolType = '_volpet';
    isAtlas = 0;    
else
    tagVolType = '';
end

% Load MRI
isNormalize = 0;
sMri = in_mri(MriFile, FileFormat, isInteractive && ~isMni && ~isPet, isNormalize);
if isempty(sMri)
    bst_progress('stop');
    return
end
% History: File name
if iscell(MriFile)
    sMri = bst_history('add', sMri, 'import', ['Import from: ' MriFile{1}]);
else
    sMri = bst_history('add', sMri, 'import', ['Import from: ' MriFile]);
end


%% ===== DELETE TEMPORARY FILES =====
if ~isempty(TmpDir)
    file_delete(TmpDir, 1, 1);
end


%% ===== GET ATLAS LABELS =====
% Try to get associated labels
if isempty(Labels) && ~iscell(MriFile) && ~isCt && ~isPet
    Labels = mri_getlabels(MriFile, sMri, isAtlas);
end
% Save labels in the file structure
if ~isempty(Labels)   % Labels were found in the input folder
    sMri.Labels = Labels;
    tagVolType = '_volatlas';
    isAtlas = 1;
elseif isAtlas    % Volume was explicitly imported as an atlas
    tagVolType = '_volatlas';
end
% Get atlas comment
if isAtlas && isempty(Comment) && ~iscell(MriFile)
    [fPath, fBase, fExt] = bst_fileparts(MriFile);
    switch (fBase)
        case 'aseg'
            Comment = 'ASEG';
        case 'aparc+aseg'
            Comment = 'Desikan-Killiany';
        case 'aparc.a2009s+aseg'
            Comment = 'Destrieux';
        case {'aparc.DKTatlas+aseg', 'aparc.mapped+aseg'}  % FreeSurfer, FastSurfer
            Comment = 'DKT';
    end
end


%% ===== MANAGE MULTIPLE MRI =====
fileTag = '';
% Add new anatomy
iAnatomy = length(sSubject.Anatomy) + 1;   
% If add an extra MRI: read the first one to check that they are compatible
if (iAnatomy > 1) && (isInteractive || isAutoAdjust)
    % Load the reference MRI (the first one)
    refMriFile = sSubject.Anatomy(1).FileName;
    sMriRef = in_mri_bst(refMriFile);
    % Adding an MNI volume to an existing subject
    if isMni
        sMri = mri_reslice_mni(sMri, sMriRef, isAtlas);
        isSameSize = 1;
        errMsg = '';
    % Regular coregistration options between volumes
    else
        % Backup history (import)
        tmpHistory.History = sMri.History;
        sMri.History = [];
        % If some transformation where made to the intial volume: apply them to the new one ?
        if isfield(sMriRef, 'InitTransf') && ~isempty(sMriRef.InitTransf) && any(ismember(sMriRef.InitTransf(:,1), {'permute', 'flipdim'}))
            isApplyTransformation = java_dialog('confirm', ['A transformation was applied to the reference MRI.' 10 10 'Do you want to apply the same transformation to this new volume?' 10 10], ['Import ', volType]);
            if ~isInteractive || isApplyTransformation
                % Apply step by step all the transformations that have been applied to the original MRI
                for it = 1:size(sMriRef.InitTransf,1)
                    ttype = sMriRef.InitTransf{it,1};
                    val   = sMriRef.InitTransf{it,2};
                    switch (ttype)
                        case 'permute'
                            sMri.Cube = permute(sMri.Cube, [val, 4]);
                            sMri.Voxsize = sMri.Voxsize(val);
                        case 'flipdim'
                            sMri.Cube = bst_flip(sMri.Cube, val(1));
                    end
                end
                % Modifying the volume disables the option "Reslice"
                isResliceDisabled = 1;
            else
                isResliceDisabled = 0;
            end
        else
            isResliceDisabled = 0;
        end

        % === ASK REGISTRATION METHOD ===
        % Get volumes dimensions
        refSize = size(sMriRef.Cube(:,:,:,1));
        newSize = size(sMri.Cube(:,:,:,1));
        isSameSize = all(refSize == newSize) && all(round(sMriRef.Voxsize(1:3) .* 1000) == round(sMri.Voxsize(1:3) .* 1000));
        nFrames = size(sMri.Cube, 4);

        % ==== ASK OPERATIONS FOR VOLUME ====
        % Ask what operation to perform with this MRI
        if isInteractive
            if ~isPet
                % Initialize list of options to register this new MRI with the existing one
                strOptions = '<HTML>How to register the new volume with the reference image?<BR>';
                cellOptions = {};
                % Register with the SPM
                strOptions = [strOptions, '<BR>- <U><B>SPM</B></U>:&nbsp;&nbsp;&nbsp;Coregister the two volumes with SPM (uses SPM plugin).'];
                cellOptions{end+1} = 'SPM';
                if isCt
                    % Register with the ct2mrireg plugin
                    strOptions = [strOptions, '<BR>- <U><B>CT2MRI</B></U>:&nbsp;&nbsp;&nbsp;Coregister using USC CT2MRI plugin.'];
                    cellOptions{end+1} = 'CT2MRI';
                end
                % Register with the MNI transformation
                strOptions = [strOptions, '<BR>- <U><B>MNI</B></U>:&nbsp;&nbsp;&nbsp;Compute the MNI transformation for both volumes (inaccurate).'];
                cellOptions{end+1} = 'MNI';
                % Skip registration
                strOptions = [strOptions, '<BR>- <U><B>Ignore</B></U>:&nbsp;&nbsp;&nbsp;The two volumes are already registered.'];
                cellOptions{end+1} = 'Ignore';
                % Ask user to make a choice
                RegMethod = java_dialog('question', [strOptions '<BR><BR></HTML>'], ['Import ', volType], [], cellOptions, 'Reg+reslice');
                % User aborted the import
                if isempty(RegMethod)
                    sMri = [];
                    bst_progress('stop');
                    return;
                end
                % === ASK RESLICE ===
                if (~strcmpi(RegMethod, 'Ignore') || ...
                        (isfield(sMriRef, 'InitTransf') && ~isempty(sMriRef.InitTransf) && ismember('vox2ras', sMriRef.InitTransf(:,1)) && ...
                        isfield(sMri,    'InitTransf') && ~isempty(sMri.InitTransf)    && ismember('vox2ras', sMri.InitTransf(:,1)) && ...
                        ~isResliceDisabled))
                    % If the volumes don't have the same size, add a warning
                    if ~isSameSize
                        strSizeWarn = '<BR>The two volumes have different sizes: if you answer no here, <BR>you will not be able to overlay them in the same figure.';
                    else
                        strSizeWarn = [];
                    end
                    % Ask to reslice
                    [isReslice, isCancel]= java_dialog('confirm', [...
                        '<HTML><B>Reslice the volume?</B><BR><BR>' ...
                        ['This operation rewrites the new ', volType, ' to match the alignment, <BR>size and resolution of the original volume.'] ...
                        strSizeWarn ...
                        '<BR><BR></HTML>'], ['Import ', volType]);
                    % User aborted the process
                    if isCancel
                        bst_progress('stop');
                        return;
                    end
                end

            % Ask for PET processing
            else
                % Collect user inputs
                petopts = gui_show_dialog('PET Pre-processing Options', @panel_import_pet, 1, [], nFrames);
                if isempty(petopts)  % User aborted the import
                    sMri = [];
                    bst_progress('stop');
                    return;
                end
                realignFileTag = '';
                % Realign and smooth
                if petopts.align
                    [sMri, realignFileTag] = mri_realign(sMri, [], petopts.fwhm, petopts.aggregate); % FWHM == 0 => no smoothing
                end
                % Aggregate values across time frames without realignment
                if ~petopts.align && ~isempty(petopts.aggregate) && ~strcmp(petopts.aggregate, 'ignore')
                    [sMri, aggregateFileTag] = mri_aggregate(sMri, petopts.aggregate);
                    realignFileTag = [realignFileTag, aggregateFileTag];           
                end
                tmpHistory.History = sMri.History;
                % Registration method
                RegMethod = petopts.register;
                % Reslice
                isReslice = petopts.reslice;
            end
        % In non-interactive mode
        else
            % Registration: ignore if possible, or use the first option available
            RegMethod = 'Ignore';
            % Reslice: never reslice
            isReslice = 0;
        end

        % Check that reference volume has set fiducials for reslicing
        if isReslice && (~isfield(sMriRef, 'SCS') || ~isfield(sMriRef.SCS, 'R') || ~isfield(sMriRef.SCS, 'T') || isempty(sMriRef.SCS.R) || isempty(sMriRef.SCS.T))
            errMsg = 'Reslice: No SCS transformation available for the reference volume. Set the fiducials first.';
            RegMethod = ''; % Registration will not be performed
        end

        % === ASK SKULL STRIPPING ===
        if isInteractive && isCt && (strcmpi(RegMethod, 'SPM') || strcmpi(RegMethod, 'CT2MRI'))
            % Ask if the user wants to mask out region outside skull in CT
            [MaskMethod, isCancel] = java_dialog('question', ['<HTML><B>Perform skull stripping on the CT volume?</B><BR>' ...
                                                            'This removes non-brain tissues (skull, scalp, fat, and other head tissues) from the CT volume.<BR><BR>' ...
                                                            'Which method do you want to proceed with?<BR><BR>' ...
                                                            '- <U><B>SPM</B></U>:&nbsp;&nbsp;&nbsp;SPM Tissue Segmentation (uses SPM plugin)<BR>' ...
                                                            '- <U><B>BrainSuite</B></U>:&nbsp;&nbsp;&nbsp;Brain Surface Extractor (requires BrainSuite installed)<BR>' ...
                                                            '- <U><B>Skip</B></U>:&nbsp;&nbsp;&nbsp;Proceed without skull stripping<BR><BR></HTML>'], ...
                                                            'Import CT', [], {'SPM', 'BrainSuite', 'Skip'}, '');
            % User aborted the process
            if isCancel
                bst_progress('stop');
                return;
            end
        else
            % In non-interactive mode: never do skull stripping
            MaskMethod = 'Skip';
        end

        % === REGISTRATION AND RESLICING ===
        switch lower(RegMethod)
            case 'mni'
                % Register the new MRI on the existing one using the MNI transformation (+ RESLICE)
                [sMri, errMsg, fileTag] = mri_coregister(sMri, sMriRef, 'mni', isReslice, isAtlas);
            case 'spm'
                % Register the new MRI on the existing one using SPM + RESLICE
                [sMri, errMsg, fileTag] = mri_coregister(sMri, sMriRef, 'spm', isReslice, isAtlas);
            case 'ct2mri'
                % Register the CT to existing MRI using USC's CT2MRI plugin + RESLICE
                [sMri, errMsg, fileTag] = mri_coregister(sMri, sMriRef, 'ct2mri', isReslice, isAtlas);
            case 'ignore'
                if isReslice
                    % Register the new MRI on the existing one using the transformation in the input files (files already registered)
                    [sMri, errMsg, fileTag] = mri_reslice(sMri, sMriRef, 'vox2ras', 'vox2ras', isAtlas);
                else
                    % Just copy the fiducials from the reference MRI
                    [sMri, errMsg, fileTag] = mri_coregister(sMri, sMriRef, 'vox2ras', isReslice, isAtlas);
                    % Transform error in warning
                    if ~isempty(errMsg) && ~isempty(sMri) && isSameSize && ~isReslice
                        disp(['BST> Warning: ' errMsg]);
                        errMsg = [];
                    end
                end
                % Copy the old SCS and NCS fields to the new file (only if registered)
                if isSameSize || isReslice
                    sMri.SCS = sMriRef.SCS;
                    %sMri.NCS = sMriRef.NCS;
                end
            otherwise
                % Do nothing
        end
        % Stop in case of error
        if ~isempty(errMsg)
            if isInteractive
                bst_error(errMsg, [RegMethod ' MRI'], 0);
                sMri = [];
                bst_progress('stop');
                return;
            else
                error(errMsg);
            end
        end
        % === SKULL STRIPPING ===
        switch lower(MaskMethod)
            case 'spm'
                [sMri, errMsg, maskFileTag] = mri_skullstrip(sMri, sMriRef, 'spm');
            case 'brainsuite'
                [sMri, errMsg, maskFileTag] = mri_skullstrip(sMri, sMriRef, 'brainsuite');
            case 'skip'
                % Do nothing
                maskFileTag = '';
        end
        fileTag = [fileTag, maskFileTag];
        % Add tag for realign
        if isPet
            fileTag = [realignFileTag, fileTag];
        end
        % Stop in case of error
        if ~isempty(errMsg)
            if isInteractive
                bst_error(errMsg, [MaskMethod ' brain mask MRI'], 0);
                sMri = [];
                bst_progress('stop');
                return;
            else
                error(errMsg);
            end
        end
        % Add history entry (co-registration)
        if ~isempty(RegMethod) && ~strcmpi(RegMethod, 'Ignore')
            % Co-registration
            sMri = bst_history('add', sMri, 'resample', ['MRI co-registered on default file (' RegMethod '): ' refMriFile]);
        end
        % Add history entry (reslice)
        if isReslice || isMni
            sMri = bst_history('add', sMri, 'resample', ['MRI resliced to default file: ' refMriFile]);
        end
        % Add history entry (skull stripping)
        if ~isempty(maskFileTag)
            sMri = bst_history('add', sMri, 'resample', ['Skull stripping with "' MaskMethod '" using on default file: ' refMriFile]);
        end
        % Add back history entry (import)
        sMri.History = [tmpHistory.History; sMri.History];
    end
end


%% ===== SAVE MRI IN BRAINSTORM FORMAT =====
% Add a Comment field in MRI structure, if it does not exist yet
if ~isempty(Comment)
    sMri.Comment = Comment;
    importedBaseName = file_standardize(Comment);
else
    if ~isfield(sMri, 'Comment') || isempty(sMri.Comment)
        sMri.Comment = 'MRI';
    end
    % Use filename as comment
    if (iAnatomy > 1) || isInteractive || ~isAutoAdjust
        [fPath, fBase, fExt] = bst_fileparts(MriFile);
        fBase = strrep(fBase, '.nii', '');
        if isMni
            sMri.Comment = file_unique(fBase, {sSubject.Anatomy.Comment});
        else
            sMri.Comment = file_unique([fBase, fileTag], {sSubject.Anatomy.Comment});
        end
    end
    % Add MNI tag
    if isMni
        if isfield(sMri, 'NCS') && isfield(sMri.NCS, 'y_method') && ~isempty(sMri.NCS.y_method)
            sMri.Comment = [sMri.Comment ' (MNI-' sMri.NCS.y_method ')'];
        elseif isfield(sMri, 'NCS') && isfield(sMri.NCS, 'y') && isfield(sMri.NCS, 'iy') && ~isempty(sMri.NCS.y) && ~isempty(sMri.NCS.iy)
            sMri.Comment = [sMri.Comment ' (MNI-nonlin)'];
        elseif isfield(sMri, 'NCS') && isfield(sMri.NCS, 'R') && isfield(sMri.NCS, 'T') && ~isempty(sMri.NCS.R) && ~isempty(sMri.NCS.T)
            sMri.Comment = [sMri.Comment ' (MNI-linear)'];
        else
            sMri.Comment = [sMri.Comment ' (MNI)'];
        end
    end
    % Get imported base name
    [tmp__, importedBaseName] = bst_fileparts(MriFile);
    importedBaseName = strrep(importedBaseName, 'subjectimage_', '');
    importedBaseName = strrep(importedBaseName, '_subjectimage', '');
    importedBaseName = strrep(importedBaseName, '.nii', '');
end


%% ===== SAVE FILE =====
% Get subject subdirectory
subjectSubDir = bst_fileparts(sSubject.FileName);
% Produce a default anatomy filename
BstMriFile = bst_fullfile(ProtocolInfo.SUBJECTS, subjectSubDir, ['subjectimage_' importedBaseName fileTag tagVolType '.mat']);
% Make this filename unique
BstMriFile = file_unique(BstMriFile);
% Save new MRI in Brainstorm format
sMri = out_mri_bst(sMri, BstMriFile);

%% ===== REFERENCE NEW MRI IN DATABASE ======
% New anatomy structure
sSubject.Anatomy(iAnatomy) = db_template('Anatomy');
sSubject.Anatomy(iAnatomy).FileName = file_short(BstMriFile);
sSubject.Anatomy(iAnatomy).Comment  = sMri.Comment;
% Default anatomy: do not change
if isempty(sSubject.iAnatomy) && ~isCt && ~isPet && ~isAtlas
    sSubject.iAnatomy = iAnatomy;
end
% Default subject
if (iSubject == 0)
	ProtocolSubjects.DefaultSubject = sSubject;
% Normal subject 
else
    ProtocolSubjects.Subject(iSubject) = sSubject;
end
bst_set('ProtocolSubjects', ProtocolSubjects);
% Save first MRI as permanent default
if (iAnatomy == 1) && ~isCt && ~isPet && ~isAtlas
    db_surface_default(iSubject, 'Anatomy', iAnatomy, 0);
end

%% ===== UPDATE GUI =====
% Refresh tree
panel_protocols('UpdateNode', 'Subject', iSubject);
panel_protocols('SelectNode', [], 'subject', iSubject, -1 );
% Save database
db_save();
% Unload MRI (if a MRI with the same name was previously loaded)
bst_memory('UnloadMri', BstMriFile);


%% ===== MRI VIEWER =====
if isInteractive
    % First MRI: Edit fiducials
    if (iAnatomy == 1)
        % MRI Visualization and selection of fiducials (in order to align surfaces/MRI)
        hFig = view_mri(BstMriFile, 'EditMri');
        drawnow;
        bst_progress('stop');
        % Wait for the MRI Viewer to be closed
        if ishandle(hFig)
            waitfor(hFig);
        end
    % Other volumes: Display registration
    else
        % If volumes are registered
        if isSameSize || isReslice
            % Open the second volume as an overlay of the first one
            hFig = view_mri(refMriFile, BstMriFile);
            % Set the amplitude threshold to 30%
            if ~isAtlas
                panel_surface('SetDataThreshold', hFig, 1, 0.3);
            end
        else
            hFig = view_mri(BstMriFile);
        end
    end
else
    if ~isProgress
        bst_progress('stop');
    end
end





    
