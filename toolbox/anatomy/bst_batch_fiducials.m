function bst_batch_fiducials(BatchFolders, isUpdate)
% BST_BATCH_FIDUCIALS Mark the fiducials in all the anatomy folders in input
% and save the selected points in a file "fiducials.m" in the folder.
%
% USAGE:  bst_batch_fiducials(BatchFolders=[ask], isUpdate=0)
% 
% INPUTS: 
%    - BatchFolders : Anatomy folders to process (asked to user if not set)
%                     Supports outputs from: FreeSurfer, BrainSuite, BrainVISA, CIVET
%    - isUpdate     : If set to 0, do not update the existing 

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
% Authors: Francois Tadel, 2016


% ===== INITIALIZATION =====
% Parse inputs
if (nargin < 2) || isempty(isUpdate)
    isUpdate = [];
end
if (nargin < 1) || isempty(BatchFolders)
    BatchFolders = [];
elseif ischar(BatchFolders)
    BatchFolders = {BatchFolders};
end

% ===== GET FOLDER =====
% Ask batch folder to user
if isempty(BatchFolders)
    % Get default import directory and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    % Select folder
    BatchFolders = java_getfile('open', 'Select anatomy folders...', bst_fileparts(LastUsedDirs.ImportAnat, 1), 'multiple', 'dirs', ...
                               {{'*'}, 'Anatomy folders', 'FsDir'}, 1);
    % If no folder was selected: exit
    if isempty(BatchFolders)
        return
    end
    % Save default import directory
    LastUsedDirs.ImportAnat = BatchFolders{1};
    bst_set('LastUsedDirs', LastUsedDirs);
end

% ===== FIND RELEVANT MRI FILES =====
% Progress bar
bst_progress('start', 'Set fiducials', 'Looking for anatomy folders...');
% Find all the possible MRI files to import in all the subfolders
MriFiles = {};
FidFiles = {};
nDispFiles = 10;
MriFormats = {};
% Loop on the input folders
for iFolder = 1:length(BatchFolders)
    % FreeSurfer: /mri/T1.mgz
    MriFileFs = file_find( BatchFolders{iFolder}, 'T1.mgz', [], 0);
    if ~isempty(MriFileFs)
        MriFiles   = cat(2, MriFiles, MriFileFs);
        MriFormats = cat(2, MriFormats, repmat({'FS'}, 1, length(MriFileFs)));
    end
    
    % BrainVISA: nobias_*.nii / nobias_*.nii.gz / nobias_*.ima
    MriFileBv = cat(2, file_find(BatchFolders{iFolder}, 'nobias_*.nii', [], 0), ...
                       file_find(BatchFolders{iFolder}, 'nobias_*.nii.gz', [], 0), ...
                       file_find(BatchFolders{iFolder}, 'nobias_*.ima', [], 0));
    if ~isempty(MriFileBv)
        MriFiles   = cat(2, MriFiles, MriFileBv);
        MriFormats = cat(2, MriFormats, repmat({'BV'}, 1, length(MriFileBv)));
    end
    
    % BrainSuite: FilePrefix.nii / FilePrefix.img
    MriFileBs = file_find(BatchFolders{iFolder}, '*.left.pial.cortex.svreg.dfs', [], 0);
    % Get the MRI from the identified BrainSuite folder
    for i = 1:length(MriFileBs)
        % Get the subject prefix
        [BsDir, FilePrefix] = bst_fileparts(MriFileBs{i}(1:end-27));
        % Find the original MRI in the folder
        BsDirMri = {file_find(BsDir, [FilePrefix '.nii.gz']), ...
                    file_find(BsDir, [FilePrefix '.nii']), ...
                    file_find(BsDir, [FilePrefix '.img.gz']),...
                    file_find(BsDir, [FilePrefix '.img'])};
        BsDirMri = [BsDirMri{find(~cellfun(@isempty, BsDirMri))}];
        if ~isempty(BsDirMri)
            MriFiles   = cat(2, MriFiles, BsDirMri);
            MriFormats = cat(2, MriFormats, repmat({'BS'}, 1, length(BsDirMri)));
        end
    end

    % Find fiducials file
    FidFilesTmp = file_find(BatchFolders{iFolder}, 'fiducials.m', [], 0);
    if ~isempty(FidFilesTmp)
        FidFiles = cat(2, FidFiles, FidFilesTmp);
    end
end
bst_progress('stop');

% Display message with number of folders that were found 
if isempty(MriFiles)
    bst_error('No anatomy segmentations were found in the selected folder.', 'Set fiducials', 0);
    return;
else
    strFiles = sprintf('   %s\n', MriFiles{1:min(nDispFiles,length(MriFiles))});
    if (length(MriFiles) > nDispFiles)
        strFiles = [strFiles, '   [...]', 10];
    end
    if ~java_dialog('confirm', [num2str(length(MriFiles)) ' MRI found in the selected folders:' 10 strFiles 10 'Set the fiducials for all of them?'], 'Set fiducials')
        return;
    end
end
% Ask to overwrite existing fiducials.m
if ~isempty(FidFiles) && isempty(isUpdate)
    strFiles = sprintf('   %s\n', FidFiles{1:min(nDispFiles,length(FidFiles))});
    if (length(FidFiles) > nDispFiles)
        strFiles = [strFiles, '   [...]', 10];
    end
    isUpdate = java_dialog('confirm', ['Some existing fiducials files were found:' 10 strFiles 10 'Overwrite existing files?'], 'Update existing fiducials');
end


% ===== CREATE TEMP SUBJECT =====
SubjectName = 'TmpEditFid';
% Get subject
[sSubject, iSubject] = bst_get('Subject', SubjectName);
% Delete existing subject
if ~isempty(sSubject)
    db_delete_subjects(iSubject);
end
% Create subject again
[sSubject, iSubject] = db_add_subject(SubjectName, [], 0, 0);


% ===== PROCESS LIST OF MRI ======
NewFidFiles = {};
% Loop on files
for iMri = 1:length(MriFiles)
    % === GET FIDUCIALS FILE ===
    % Get expected anatomy folder
    switch (MriFormats{iMri})
        case 'FS',  AnatFolder = bst_fileparts(bst_fileparts(MriFiles{iMri}));
        case 'BV',  AnatFolder = bst_fileparts(bst_fileparts(MriFiles{iMri}));
        case 'BS',  AnatFolder = bst_fileparts(MriFiles{iMri});
        case 'CV',  AnatFolder = bst_fileparts(bst_fileparts(MriFiles{iMri}));
    end
    % Check for existing fiducials.m
    FidFile = file_find(AnatFolder, 'fiducials.m', [], 0);
    if (length(FidFile) > 1)
        bst_error(['Multiple fiducials.m found in folder: ' 10 AnatFolder 10 'Check your folder structure before trying again.'], 'Set fiducials', 0);
    % One fiducials.m was found
    elseif (length(FidFile) == 1) && ~isempty(FidFile{1}) && file_exist(FidFile{1})
        FidFile = FidFile{1};
        if ~isUpdate
            disp(['Fiducials already set: ' FidFile]);
            continue;
        else
            % Overwrite the existing file
        end
    % File not found: create a new file next to the MRI file
    else
        FidFile = bst_fullfile(bst_fileparts(MriFiles{iMri}), 'fiducials.m');
    end

    % === LOAD MRI ===
    % Import T1.mgz 
    BstFile = import_mri(iSubject, MriFiles{iMri}, [], 1);
    % Load imported imported MRI file
    sMRI = in_mri_bst(BstFile);
    % Exit if aborted
    if isempty(sMRI) || ~isfield(sMRI, 'SCS') || isempty(sMRI.SCS) || ~isfield(sMRI.SCS, 'NAS') || isempty(sMRI.SCS.NAS) || isempty(sMRI.SCS.LPA) || isempty(sMRI.SCS.RPA)
        bst_error('MRI fiducials were not set properly.', 'Set fiducials', 0);
        break;
    end
    
    % === DELETE MRI ===
    % Get subject again
    sSubject = bst_get('Subject', iSubject);
    % Delete MRI
    file_delete(file_fullpath({sSubject.Anatomy.FileName}), 1);
    sSubject.Anatomy(1:end) = [];
    sSubject.iAnatomy = [];
    % Update subject structure
    bst_set('Subject', iSubject, sSubject);
    panel_protocols('UpdateNode', 'Subject', iSubject);

    % === CREATE FIDUCIALS FILE ===
    % Compute MNI normalizations
    isComputeMni = 1;
    % Save fiducials
    figure_mri('SaveFiducialsFile', sMRI, FidFile, isComputeMni);

    % Add to the list of new files
    NewFidFiles{end+1} = FidFile;
end

% Delete temporary subject
db_delete_subjects(iSubject);

% Display the list of new fiducial files
if ~isempty(NewFidFiles)
    strFiles = sprintf('   %s\n', NewFidFiles{1:min(nDispFiles,length(NewFidFiles))});
    if (length(NewFidFiles) > nDispFiles)
        strFiles = [strFiles, '   [...]', 10];
    end
    java_dialog('msgbox', [num2str(length(NewFidFiles)) ' new fiducial files created:' 10 strFiles], 'Set fiducials');
end



