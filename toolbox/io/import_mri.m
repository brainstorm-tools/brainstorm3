function [BstMriFile, sMri] = import_mri(iSubject, MriFile, FileFormat, isInteractive, isAutoAdjust, Comment, Labels)
% IMPORT_MRI: Import a MRI file in a subject of the Brainstorm database
% 
% USAGE: [BstMriFile, sMri] = import_mri(iSubject, MriFile, FileFormat='ALL', isInteractive=0, isAutoAdjust=1, Comment=[], Labels=[])
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

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2020

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
    % Get MRI file
    [MriFile, FileFormat, FileFilter] = java_getfile( 'open', ...
        'Import MRI...', ...              % Window title
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
if strcmpi(FileFormat, 'DICOM-SPM')
    % Convert DICOM to NII
    DicomFiles = MriFile;
    MriFile = in_mri_dicom_spm(DicomFiles, bst_get('BrainstormTmpDir'), isInteractive);
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
    bst_progress('start', 'Import MRI', 'Loading MRI file...');
end
% MNI / Atlas?
isMni = ismember(FileFormat, {'ALL-MNI', 'ALL-MNI-ATLAS'});
isAtlas = ismember(FileFormat, {'ALL-ATLAS', 'ALL-MNI-ATLAS', 'SPM-TPM'});
% Load MRI
isNormalize = 0;
sMri = in_mri(MriFile, FileFormat, isInteractive && ~isMni, isNormalize);
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


%% ===== GET ATLAS LABELS =====
% Try to get associated labels
if isempty(Labels) && ~iscell(MriFile)
    Labels = mri_getlabels(MriFile, sMri, isAtlas);
end
% Save labels in the file structure
if ~isempty(Labels)   % Labels were found in the input folder
    sMri.Labels = Labels;
    tagAtlas = '_volatlas';
    isAtlas = 1;
elseif isAtlas    % Volume was explicitly imported as an atlas
    tagAtlas = '_volatlas';
else
    tagAtlas = '';
end
% Get atlas comment
if isAtlas && isempty(Comment) && ~iscell(MriFile)
    [fPath, fBase, fExt] = bst_fileparts(MriFile);
    switch (fBase)
        case 'aseg'
            Comment = 'ASEG';
        case 'aparc+aseg'
            Comment = 'Deskian-Killiany';
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
        % If some transformation where made to the intial volume: apply them to the new one ?
        if isfield(sMriRef, 'InitTransf') && ~isempty(sMriRef.InitTransf) && any(ismember(sMriRef.InitTransf(:,1), {'permute', 'flipdim'}))
            if ~isInteractive || java_dialog('confirm', ['A transformation was applied to the reference MRI.' 10 10 'Do you want to apply the same transformation to this new volume?' 10 10], 'Import MRI')
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
        % Ask what operation to perform with this MRI
        if isInteractive
            % Initialize list of options to register this new MRI with the existing one
            strOptions = '<HTML>How to register the new volume with the reference image?<BR>';
            cellOptions = {};
            % Register with the SPM
            strOptions = [strOptions, '<BR>- <U><B>SPM</B></U>:&nbsp;&nbsp;&nbsp;Coregister the two volumes with SPM (requires SPM toolbox).'];
            cellOptions{end+1} = 'SPM';
            % Register with the MNI transformation
            strOptions = [strOptions, '<BR>- <U><B>MNI</B></U>:&nbsp;&nbsp;&nbsp;Compute the MNI transformation for both volumes (inaccurate).'];
            cellOptions{end+1} = 'MNI';
            % Skip registration
            strOptions = [strOptions, '<BR>- <U><B>Ignore</B></U>:&nbsp;&nbsp;&nbsp;The two volumes are already registered.'];
            cellOptions{end+1} = 'Ignore';
            % Ask user to make a choice
            RegMethod = java_dialog('question', [strOptions '<BR><BR></HTML>'], 'Import MRI', [], cellOptions, 'Reg+reslice');
        % In non-interactive mode: ignore if possible, or use the first option available
        else
            RegMethod = 'Ignore';
        end
        % User aborted the import
        if isempty(RegMethod)
            sMri = [];
            bst_progress('stop');
            return;
        end

        % === ASK RESLICE ===
        if isInteractive && (~strcmpi(RegMethod, 'Ignore') || ...
            (isfield(sMriRef, 'InitTransf') && ~isempty(sMriRef.InitTransf) && any(ismember(sMriRef.InitTransf(:,1), 'vox2ras')) && ...
             isfield(sMri,    'InitTransf') && ~isempty(sMri.InitTransf)    && any(ismember(sMri.InitTransf(:,1),    'vox2ras')) && ...
             ~isResliceDisabled))
            % If the volumes don't have the same size, add a warning
            if ~isSameSize
                strSizeWarn = '<BR>The two volumes have different sizes: if you answer no here, <BR>you will not be able to overlay them in the same figure.';
            else
                strSizeWarn = [];
            end
            % Ask to reslice
            isReslice = java_dialog('confirm', [...
                '<HTML><B>Reslice the volume?</B><BR><BR>' ...
                'This operation rewrites the new MRI to match the alignment, <BR>size and resolution of the original volume.' ...
                strSizeWarn ...
                '<BR><BR></HTML>'], 'Import MRI');
        % In non-interactive mode: never reslice
        else
            isReslice = 0;
        end

        % === REGISTRATION ===
        switch (RegMethod)
            case 'MNI'
                % Register the new MRI on the existing one using the MNI transformation (+ RESLICE)
                [sMri, errMsg, fileTag] = mri_coregister(sMri, sMriRef, 'mni', isReslice, isAtlas);
            case 'SPM'
                % Register the new MRI on the existing one using SPM + RESLICE
                [sMri, errMsg, fileTag] = mri_coregister(sMri, sMriRef, 'spm', isReslice, isAtlas);
            case 'Ignore'
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
        end
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
BstMriFile = bst_fullfile(ProtocolInfo.SUBJECTS, subjectSubDir, ['subjectimage_' importedBaseName fileTag tagAtlas '.mat']);
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
if isempty(sSubject.iAnatomy)
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
if (iAnatomy == 1)
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





    
