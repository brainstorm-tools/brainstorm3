function varargout = process_import_bids( varargin )
% PROCESS_IMPORT_BIDS: Import a dataset organized following the BIDS specficiations (http://bids.neuroimaging.io/)
%
% USAGE:           OutputFiles = process_import_bids('Run', sProcess, sInputs)
%         [RawFiles, Messages] = process_import_bids('ImportBidsDataset', BidsDir=[ask], nVertices=[ask], isInteractive=1, ChannelAlign=0)
%             [sFid, Messages] = process_import_bids('GetFiducials', json, defaultUnits)
%
% DISCUSSION:
%   - Metadata conflicts:
%     - Channel names are kept from the original data files, and can't be renamed with the BIDS metadata.
%       This simplifies a lot the implementation, as we can keep on using the original channel file and add the extra info from _channels.tsv and _electrodes.tsv.
%       This is not aligned with the idea that "In cases of conflict, the BIDS metadata is considered authoritative"
%       But the channel names are never expected to be different between the data files and the metadata: 
%       "If BIDS metadata is defined, format-specific metadata MUST NOT conflict to the extent permitted by the format"
%       (reference: https://github.com/bids-standard/bids-specification/pull/761)
%
%  - Test datasets:
%    - EEG  : https://openneuro.org/datasets/ds002578 : OK 
%    - EEG  : https://openneuro.org/datasets/ds003421 : ERROR: EEG positions not imported because of mismatch of channel names between .vmrk and electrodes.tsv
%    - EEG  : https://openneuro.org/datasets/ds004024 : OK
%    - iEEG : https://openneuro.org/datasets/ds003688 : ERROR: Wrong interpretation of ACPC coordinates (easier to see in ECOG for sub-02)
%    - iEEG : https://openneuro.org/datasets/ds003848 : WARNING: Impossible to interepret correctly the coordinates in electrodes.tsv
%    - iEEG : https://openneuro.org/datasets/ds004473 : OK
%    - iEEG : https://openneuro.org/datasets/ds004126 : OK (ACPC OK)
%    - STIM : https://openneuro.org/datasets/ds002799 : WARNING: No channel file imported because there are no SEEG recordings
%    - MEG  : https://openneuro.org/datasets/ds000117 : 
%    - MEG  : https://openneuro.org/datasets/ds000246 : 
%    - MEG  : https://openneuro.org/datasets/ds000247 : 
%    - MEG  : https://openneuro.org/datasets/ds004107 : WARNING: Multiple NAS/LPA/RPA in T1w.json, one for each MEG session => Used the average for both sessions
%    - Tutorial FEM  : https://neuroimage.usc.edu/brainstorm/Tutorials/FemMedianNerve   :
%    - Tutorial ECOG : https://neuroimage.usc.edu/brainstorm/Tutorials/ECoG             :
%    - Tutorial SEEG : https://neuroimage.usc.edu/brainstorm/Tutorials/Epileptogenicity : 
%    - NIRS : https://github.com/rob-luke/BIDS-NIRS-Tapping/tree/388d2cdc3ae831fc767e06d9b77298e9c5cd307b :
%   -  NIRS : https://osf.io/b4wck/ : 


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
% Authors: Francois Tadel, 2016-2022
%          Martin Cousineau, 2018

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Import BIDS dataset';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Import';
    sProcess.Index       = 41;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/RestingOmega#Import_the_dataset';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    % File selection options
    SelectOptions = {...
        '', ...                            % Filename
        '', ...                            % FileFormat
        'open', ...                        % Dialog type: {open,save}
        'Import BIDS dataset folder...', ...     % Window title
        'ImportAnat', ...                  % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'multiple', ...                    % Selection mode: {single,multiple}
        'dirs', ...                        % Selection mode: {files,dirs,files_and_dirs}
        {{'.folder'}, 'BIDS dataset folder', 'BIDS'}, ... % Available file formats
        []};                               % DefaultFormats: {ChannelIn,DataIn,DipolesIn,EventsIn,AnatIn,MriIn,NoiseCovIn,ResultsIn,SspIn,SurfaceIn,TimefreqIn}
    % Option: MRI file
    sProcess.options.bidsdir.Comment = 'Folder to import:';
    sProcess.options.bidsdir.Type    = 'filename';
    sProcess.options.bidsdir.Value   = SelectOptions;
    % Subject selection
    sProcess.options.selectsubj.Comment = 'Names of subjects to import (empty=all):';
    sProcess.options.selectsubj.Type    = 'text';
    sProcess.options.selectsubj.Value   = '';
    % Option: Number of vertices
    sProcess.options.nvertices.Comment = 'Number of vertices (cortex): ';
    sProcess.options.nvertices.Type    = 'value';
    sProcess.options.nvertices.Value   = {15000, '', 0};
    % MNI normalization
    sProcess.options.mni.Comment = {'Linear', 'Non-linear', 'No', 'MNI normalization:'; ...
                                    'maff8', 'segment', 'no', ''};
    sProcess.options.mni.Type    = 'radio_linelabel';
    sProcess.options.mni.Value   = 'maff8';
    % Register anatomy
    sProcess.options.anatregister.Comment = {'SPM12', 'No', 'Coregister anatomical volumes:'; ...
                                             'spm12', 'no', ''};
    sProcess.options.anatregister.Type    = 'radio_linelabel';
    sProcess.options.anatregister.Value   = 'spm12';
    % Group sessions
    sProcess.options.groupsessions.Comment = 'Import multiple anat sessions to the same subject';
    sProcess.options.groupsessions.Type    = 'checkbox';
    sProcess.options.groupsessions.Value   = 1;
    % Align sensors
    sProcess.options.channelalign.Comment = 'Align sensors using headpoints';
    sProcess.options.channelalign.Type    = 'checkbox';
    sProcess.options.channelalign.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % === GET OPTIONS ===
    % Get folder to import
    selectedFolders = sProcess.options.bidsdir.Value{1};
    [tmp, tmp2, errorMessage] = GetValidBidsDir(selectedFolders);
    if ~isempty(errorMessage)
        bst_report('Error', sProcess, [], errorMessage);
        return
    end
    % Number of vertices
    OPTIONS.nVertices = sProcess.options.nvertices.Value{1};
    if isempty(OPTIONS.nVertices) || (OPTIONS.nVertices < 50)
        bst_report('Error', sProcess, [], 'Invalid number of vertices.');
        return;
    end
    % Other options
    OPTIONS.isInteractive    = 0;
    OPTIONS.ChannelAlign     = 2 * double(sProcess.options.channelalign.Value);
    OPTIONS.SelectedSubjects = strtrim(str_split(sProcess.options.selectsubj.Value, ','));
    OPTIONS.isGroupSessions  = sProcess.options.groupsessions.Value;
    OPTIONS.MniMethod        = sProcess.options.mni.Value;
    OPTIONS.RegisterMethod   = sProcess.options.anatregister.Value;
    
    % === IMPORT DATASET ===
    % Import dataset
    [OutputFiles, Messages] = ImportBidsDataset(selectedFolders, OPTIONS);
    % Handling errors
    if ~isempty(Messages)
        if isempty(OutputFiles)
            bst_report('Error', sProcess, [], Messages);
        else
            bst_report('Warning', sProcess, [], Messages);
        end
    end
end


%% ===== IMPORT BIDS DATABASE =====
% USAGE:  [RawFiles, Messages, OrigFiles] = process_import_bids('ImportBidsDataset', BidsDir=[ask], OPTIONS=[])
function [RawFiles, Messages, OrigFiles] = ImportBidsDataset(BidsDir, OPTIONS)
    % Initialize returned values
    RawFiles = {};
    OrigFiles = {};
    Messages = [];
    
    % ===== PARSE INPUTS =====
    if (nargin < 1) || isempty(BidsDir)
        BidsDir = [];
    end
    if (nargin < 2) || isempty(OPTIONS)
        OPTIONS = struct();
    end
    % Default options
    Def_OPTIONS = struct(...
        'nVertices',        [], ...
        'isInteractive',    1, ...
        'ChannelAlign',     0, ...
        'SelectedSubjects', [], ...
        'isGroupSessions',  1, ...
        'MniMethod',        'maff8', ...  % {'maff8','segment','no'}
        'RegisterMethod',   'spm12');     % {'smp12','no'}
    OPTIONS = struct_copy_fields(OPTIONS, Def_OPTIONS, 0);

    % ===== GET THE BIDS FOLDER =====
    % Ask the folder to the user
    if isempty(BidsDir)
        % Get default directories
        LastUsedDirs = bst_get('LastUsedDirs');
        % Pick a folder
        BidsDir = java_getfile('open', 'Import BIDS dataset folder...', LastUsedDirs.ImportAnat, 'multiple', 'dirs', {{'.folder'}, 'BIDS dataset folder', 'BIDS'}, 'BIDS');
        % If nothing selected
        if isempty(BidsDir)
            return;
        end
        % Save new default path
        LastUsedDirs.ImportAnat = bst_fileparts(BidsDir);
        bst_set('LastUsedDirs', LastUsedDirs);
    end
    % Check the structure of the dataset
    [BidsDir, selSubjects, errorMessage] = GetValidBidsDir(BidsDir);
    if ~isempty(errorMessage)
        if OPTIONS.isInteractive
            bst_error(errorMessage, 'Import BIDS dataset', 0);
        end
        return;
    end

    % Add BIDS subject tag "sub-" if missing
    for iSubject = 1:length(OPTIONS.SelectedSubjects)
        if (length(OPTIONS.SelectedSubjects{iSubject}) <= 4) || ~strcmpi(OPTIONS.SelectedSubjects{iSubject}(1:4), 'sub-')
            OPTIONS.SelectedSubjects{iSubject} = ['sub-' OPTIONS.SelectedSubjects{iSubject}];
        end
    end
    OPTIONS.SelectedSubjects = unique([OPTIONS.SelectedSubjects, selSubjects]);
    
    % ===== FIND SUBJECTS =====
    % List all the subject folders: regular or derivatives (FreeSurfer, MEG tsss, ...)
    subjDir = [...
        dir(bst_fullfile(BidsDir, 'sub-*')); ...
        dir(bst_fullfile(BidsDir, 'derivatives', 'meg_derivatives', 'sub-*')); ...
        dir(bst_fullfile(BidsDir, 'derivatives', 'freesurfer*', 'sub-*')); ...
        dir(bst_fullfile(BidsDir, 'derivatives', 'cat12*', 'sub-*')); ...
        dir(bst_fullfile(BidsDir, 'derivatives', 'brainsuite*', 'sub-*'))];
    % If the folders include the session: remove it
    for i = 1:length(subjDir)
        iUnder = find(subjDir(i).name == '_', 1);
        if ~isempty(iUnder)
            subjDir(i).name = subjDir(i).name(1:iUnder-1);
        end
    end
    % Get unique subject names
    SubjectNames = unique({subjDir.name});
    
    % ===== FIND SESSIONS =====
    % Loop on the subjects
    SubjectName = {};
    SubjectAnatDir = {};
    SubjectAnatFormat = {};
    SubjectSessDir = {};
    SubjectMriFiles = {};
    SubjectFidMriFile = {};
    for iSubj = 1:length(SubjectNames)
        % Default subject name
        subjName = SubjectNames{iSubj};
        % Check if this is a subject selected for import
        if ~isempty(OPTIONS.SelectedSubjects) && ((iscell(OPTIONS.SelectedSubjects) && ~ismember(subjName, OPTIONS.SelectedSubjects)) || (ischar(OPTIONS.SelectedSubjects) && ~strcmpi(subjName, OPTIONS.SelectedSubjects)))
            disp(['BIDS> Subject "' subjName '" was not selected. Skipping...']);
            continue;
        end
        % Get session folders: regular or derivatives
        sessDir = [dir(bst_fullfile(BidsDir, subjName, 'ses-*')); ...
                   dir(bst_fullfile(BidsDir, 'derivatives', 'meg_derivatives', subjName, 'ses-*'))];
        % Get full paths to session folders (if any)
        if isempty(sessDir)
            sessFolders = {bst_fullfile(BidsDir, subjName)};
            derivFolders = {bst_fullfile(BidsDir, 'derivatives', 'meg_derivatives', subjName)};
        else
            % Re-order session names: move "ses-preimp" or "ses-pre" at the top, for iEEG (pre-implantation images are usually the reference)
            if (length(sessDir) > 1)
                iSesPreimp = find(ismember({sessDir.name}, {'ses-preimp', 'ses-pre', 'ses-preop'}));
                if ~isempty(iSesPreimp)
                    iReorder = [iSesPreimp, setdiff(1:length(sessDir), iSesPreimp)];
                    sessDir = sessDir(iReorder);
                end
            end
            % Full session paths
            sessFolders = cellfun(@(c)fullfile(BidsDir, subjName, c), {sessDir.name}, 'UniformOutput', 0);
            derivFolders = cellfun(@(c)fullfile(BidsDir, 'derivatives', 'meg_derivatives', subjName, c), {sessDir.name}, 'UniformOutput', 0);
        end

        % If there is one unique segmented anatomy: group all the sessions together
        [AnatDir, AnatFormat] = GetSubjectSeg(BidsDir, subjName);
        % If there is no segmented folder, try SUBJID_SESSID
        if isempty(AnatDir)
            for iSes = 1:length(sessDir)
                [AnatDir, AnatFormat] = GetSubjectSeg(BidsDir, [subjName, '_', sessDir(iSes).name]);
                if ~isempty(AnatDir)
                    break;
                end
            end
        end
        
        % Get all MRI files
        isSessMri = 1;
        allMriFiles = {};
        for isess = 1:length(sessFolders)
            sessMriFiles = GetSubjectMri(bst_fullfile(sessFolders{isess}, 'anat'));
            if isempty(sessMriFiles)
                isSessMri = 0;
            else
                allMriFiles = cat(2, allMriFiles, sessMriFiles);
            end
        end
        
        % Subject index
        iSubj = length(SubjectName) + 1;
        % If a single anatomy folder is found
        if ~isempty(AnatDir)
            SubjectName{iSubj}       = subjName;
            SubjectAnatDir{iSubj}    = AnatDir;
            SubjectAnatFormat{iSubj} = AnatFormat;
            SubjectSessDir{iSubj}    = cat(2, sessFolders, derivFolders);
            SubjectMriFiles{iSubj}   = allMriFiles;
        % Check for multiple sessions
        elseif (length(sessFolders) > 1)
            % Check for multiple session segmentation
            isSessSeg = 1;
            for isess = 1:length(sessFolders)
                [sessAnatDir, sessAnatFormat] = GetSubjectSeg(BidsDir, [subjName, '_', sessDir(isess).name]);
                if isempty(sessAnatDir)
                    isSessSeg = 0;
                    break;
                end
            end
            % If there is one segmentation per session
            if isSessSeg
                for isess = 1:length(sessFolders)
                    [sessAnatDir, sessAnatFormat] = GetSubjectSeg(BidsDir, [subjName, '_', sessDir(isess).name]);
                    SubjectName{iSubj}       = [subjName, '_', sessDir(isess).name];
                    SubjectAnatDir{iSubj}    = sessAnatDir;
                    SubjectAnatFormat{iSubj} = sessAnatFormat;
                    SubjectSessDir{iSubj}    = {sessFolders{isess}, derivFolders{isess}};
                    SubjectMriFiles{iSubj}   = allMriFiles;
                end
            % There are no segmentations, check if there is one T1 volume per session or per subject
            else
                % If there is one anatomy per session
                if isSessMri && ~OPTIONS.isGroupSessions
                    for isess = 1:length(sessFolders)
                        sessMriFiles = GetSubjectMri(bst_fullfile(sessFolders{isess}, 'anat'));
                        SubjectName{iSubj}       = [subjName, '_', sessDir(isess).name];
                        SubjectAnatDir{iSubj}    = [];
                        SubjectAnatFormat{iSubj} = [];
                        SubjectSessDir{iSubj}    = {sessFolders{isess}, derivFolders{isess}};
                        SubjectMriFiles{iSubj}   = sessMriFiles;
                    end
                % One common anatomy for all the sessions
                else
                    SubjectName{iSubj}       = subjName;
                    SubjectAnatDir{iSubj}    = [];
                    SubjectAnatFormat{iSubj} = [];
                    SubjectSessDir{iSubj}    = cat(2, sessFolders, derivFolders);
                    SubjectMriFiles{iSubj}   = allMriFiles;
                end
            end
        % One session
        elseif (length(sessFolders) == 1)
            SubjectName{iSubj}       = subjName;
            SubjectAnatDir{iSubj}    = [];
            SubjectAnatFormat{iSubj} = [];
            SubjectSessDir{iSubj}    = cat(2, sessFolders, derivFolders);
            SubjectMriFiles{iSubj}   = GetSubjectMri(bst_fullfile(sessFolders{1}, 'anat'));
        end

        % For each MRI, look for a JSON file with fiducials defined
        fidMriFile = [];
        iMriRef = 1;
        for iMri = 1:length(SubjectMriFiles{end})
            % Split file name
            [fPath, fBase, fExt] = bst_fileparts(SubjectMriFiles{end}{iMri});
            if strcmpi(fExt, '.gz')
                [tmp, fBase, fExt2] = bst_fileparts(fBase);
                fExt = [fExt, fExt2];
            end
            % Look for adjacent .json file with fiducials definitions (NAS/LPA/RPA)
            jsonFile = bst_fullfile(fPath, [fBase, '.json']);
            % If json file exists
            if file_exist(jsonFile)
                % Load json file
                try
                    json = bst_jsondecode(jsonFile);
                    sFid = GetFiducials(json, 'voxel');
                catch
                    disp(['BIDS> Error: Cannot read json file: ' jsonFile]);
                    sFid = [];
                end
                % If there are fiducials defined: use them as inputs to FreeSurfer import (and other segmentations)
                if ~isempty(sFid)
                    fidMriFile = SubjectMriFiles{end}{iMri};
                    iMriRef = iMri;
                    % Stop looking through volumes: only the first one with fiducials is considered
                    break;
                end
            end
        end
        SubjectFidMriFile{iSubj} = fidMriFile;
        % If there is a MRI with fiducials found: move it at the top of the MRI list, to make it the reference MRI
        if ~isempty(fidMriFile) && (iMriRef > 1)
            iReorder = [iMriRef, setdiff(1:length(SubjectMriFiles{iSubj}), iMriRef)];
            SubjectMriFiles{iSubj} = SubjectMriFiles{iSubj}(iReorder);
        end
    end
    
%     % Perform some checks
%     % Cannot set the fiducials when calling from a process (non-interactive)
%     if ~OPTIONS.isInteractive && any(isSetFiducials)
%         Messages = ['You need to set the fiducials interactively before running this process.' 10 ...
%                     'Use the menu "File > Batch MRI fiducials" for creating fiducials.m files in the segmentation folders.' 10 ...
%                     'Alternatively, run this import interactively with the menu "File > Load protocol > Import BIDS dataset"'];
%         return;
%     % Ask the user whether to set all the fiducials at once
%     elseif OPTIONS.isInteractive && any(isSetFiducials & isSegmentation)
%         res = java_dialog('question', ...
%             ['You need to set the anatomy fiducials interactively for each subject.' 10 10 ...
%              'There are two ways for doing this, depending if you have write access to the dataset:' 10 ...
%              '1) Batch: Set the fiducials for all the segmentation folders at once, save them in fiducials.m files, ' 10 ...
%              '   and then import everything. With this option, you won''t have to wait until each subject is ' 10 ...
%              '   fully processed before setting the fiducials for the next one, and the points you define will' 10 ...
%              '   be permanently saved in the dataset. But you need write access to the input folder.' 10 ...
%              '   This is equivalent to running the menu "File > Batch MRI fiducials" first.' 10 ...
%              '2) Sequencial: For each segmentation folder, set the fiducials then import it. Longer but more flexible.' 10 10], ...
%             'Import BIDS dataset', [], {'Batch', 'Sequential', 'Cancel'}, 'Sequential');
%         if isempty(res) || isequal(res, 'Cancel')
%             return;
%         end
%         % Run the setting of the fiducials in a batch
%         if strcmpi(res, 'Batch')
%             % Find one subject that needs to be defined
%             iSetSubj = find(isSetFiducials & isSegmentation);
%             % Run it for the subjects in the same folder
%             bst_batch_fiducials(bst_fileparts(SubjectAnatDirs{iSetSubj(1)}));
%         end
%     end
    
    % ===== IMPORT FILES =====
    EmptyRoomMatch = {};
    for iSubj = 1:length(SubjectName)
        errorMsg = [];
        MriMatchOrigImport = {};

        % === GET/CREATE SUBJECT ===
        % Get subject 
        [sSubject, iSubject] = bst_get('Subject', SubjectName{iSubj});
        % Create subject is it does not exist yet
        if isempty(sSubject)
            UseDefaultAnat = isempty(SubjectAnatDir{iSubj}) && isempty(SubjectMriFiles{iSubj});
            UseDefaultChannel = 0;
            [sSubject, iSubject] = db_add_subject(SubjectName{iSubj}, [], UseDefaultAnat, UseDefaultChannel);
        end
        if isempty(iSubject)
            Messages = [Messages, 10, 'Cannot create subject "' SubjectName{iSubj} '".'];
            if OPTIONS.isInteractive
                bst_error(Messages, 'Import BIDS dataset', 0);
                return;
            else
                continue;
            end
        end
        
        % === IMPORT ANATOMY: SEGMENTATION FOLDER ===
        % Do not ask interactively for anatomical fiducials: if they are not set, use default positions from MNI template
        isInteractiveAnat = 0;
        % If the anatomy is already set: issue a warning
        isSkipAnat = ~isempty(sSubject.Anatomy);
        if isSkipAnat
            msgAnatSet = ['Anatomy is already set for subject "' SubjectName{iSubj} '", not overwriting...'];
            Messages = [Messages, 10, msgAnatSet];
            disp(['BST> ' msgAnatSet]);
        end
        % Import segmentation
        if ~isSkipAnat && ~isempty(SubjectAnatDir{iSubj})
            % Ask for number of vertices (so it is not asked multiple times)
            if isempty(OPTIONS.nVertices)
                OPTIONS.nVertices = java_dialog('input', 'Number of vertices on the cortex surface:', 'Import FreeSurfer folder', [], '15000');
                if isempty(OPTIONS.nVertices)
                    return;
                end
                OPTIONS.nVertices = str2double(OPTIONS.nVertices);
            end
            % If there are fiducials define: record these, to use them when importing FreeSurfer (or other) segmentations
            if ~isempty(SubjectFidMriFile{iSubj})
                sMriFid = in_mri(SubjectFidMriFile{iSubj}, 'ALL', 0);
            else
                sMriFid = [];
            end

            % Import subject anatomy
            switch (SubjectAnatFormat{iSubj})
                case 'FreeSurfer'
                    errorMsg = import_anatomy_fs(iSubject, SubjectAnatDir{iSubj}, OPTIONS.nVertices, isInteractiveAnat, sMriFid, 0);
                case 'CAT12'
                    errorMsg = import_anatomy_cat(iSubject, SubjectAnatDir{iSubj}, OPTIONS.nVertices, isInteractiveAnat, sMriFid, 1, 2, 1);
                case 'BrainSuite'
                    errorMsg = import_anatomy_bs(iSubject, SubjectAnatDir{iSubj}, OPTIONS.nVertices, isInteractiveAnat, sMriFid);
                case 'BrainVISA'
                    errorMsg = import_anatomy_bv(iSubject, SubjectAnatDir{iSubj}, OPTIONS.nVertices, isInteractiveAnat, sMriFid);
                case 'CIVET'
                    errorMsg = import_anatomy_civet(iSubject, SubjectAnatDir{iSubj}, OPTIONS.nVertices, isInteractiveAnat, sMriFid, 0);
                otherwise
                    errorMsg = ['Invalid file format: ' SubjectAnatFormat{iSubj}];
            end
            % Compute non-linear MNI normalization if requested (the linear was already computed during the import)
            if isequal(OPTIONS.MniMethod, 'segment')
                sSubject = bst_get('Subject', iSubject);
                if ~isempty(sSubject.Anatomy)
                    [sMri, errMsg] = bst_normalize_mni(sSubject.Anatomy(1).FileName, 'segment');
                    if ~isempty(errMsg)
                        errorMsg = [errorMsg, 10, errMsg];
                    end
                end
            end
        end

        % === IMPORT ANATOMY: MRI FILES ===
        % Import MRI
        if ~isSkipAnat && ~isempty(SubjectMriFiles{iSubj})
            MrisToRegister = {};
            % Import first MRI
            [BstMriFile, sMri] = import_mri(iSubject, SubjectMriFiles{iSubj}{1}, 'ALL', isInteractiveAnat, 0);
            if isempty(BstMriFile)
                errorMsg = [errorMsg, 10, 'Could not load MRI file: ', SubjectMriFiles{iSubj}];
            % Compute additional files
            else
                % If there was no segmentation imported before: normalize and create head surface
                if isempty(SubjectAnatDir{iSubj})
                    % Compute MNI normalization
                    switch (OPTIONS.MniMethod)
                        case 'maff8'
                            [sMri, errMsg] = bst_normalize_mni(BstMriFile, 'maff8');
                        case 'segment'
                            [sMri, errMsg] = bst_normalize_mni(BstMriFile, 'segment');
                        case 'no'
                            % Nothing to do
                            errMsg = '';
                    end
                    if ~isempty(errMsg)
                        errorMsg = [errorMsg, 10, errMsg];
                    end
                    % Generate head surface
                    tess_isohead(iSubject, 10000, 0, 2);
                else
                    MrisToRegister{end+1} = BstMriFile;
                end
                % Save correspondance original MRI/imported MRI
                MriMatchOrigImport(end+1, 1:2) = {SubjectMriFiles{iSubj}{1}, BstMriFile};
                % Add other volumes
                for i = 2:length(SubjectMriFiles{iSubj})
                    MrisToRegister{end+1} = import_mri(iSubject, SubjectMriFiles{iSubj}{i}, 'ALL', 0, 1);
                    % Save correspondance original MRI/imported MRI
                    MriMatchOrigImport(end+1, 1:2) = {SubjectMriFiles{iSubj}{i}, MrisToRegister{end}};
                end
            end
            % Register anatomical volumes if requested
            if strcmpi(OPTIONS.RegisterMethod, 'spm12')
                for i = 1:length(MrisToRegister)
                    % If nothing was imported
                    if isempty(MrisToRegister{i})
                        continue;
                    end
                    % Register MRI onto first MRI imported
                    MriFileReg = mri_coregister(MrisToRegister{i}, [], 'spm', 0);
                    % If the registration was successful
                    if ~isempty(MriFileReg)
                        % Reslice volume
                        mri_reslice(MriFileReg, [], 'vox2ras', 'vox2ras');
                        % Delete original volume
                        if (file_delete(MrisToRegister{i}, 1) == 1)
                            % Find file in database
                            [sSubject, iSubject, iMri] = bst_get('MriFile', MrisToRegister{i});
                            % Delete reference
                            sSubject.Anatomy(iMri) = [];
                            % Update database
                            bst_set('Subject', iSubject, sSubject);
                            % Refresh tree
                            panel_protocols('UpdateNode', 'Subject', iSubject);
                        end
                    end
                    % Replace the MRI file path in the matching matrix
                    iMatch = find(strcmp(MriMatchOrigImport(:,2), MrisToRegister{i}));
                    if ~isempty(iMatch)
                        MriMatchOrigImport{iMatch,2} = file_fullpath(MriFileReg);
                    end
                end
            end
        % Get the previous matching of MRI file names / Brainstorm database names
        else
            % Look for the file name in the import history of all the volumes in the subject anatomy
            for iAnat = 1:length(sSubject.Anatomy)
                % Skip volume atlases
                if ~isempty(strfind(sSubject.Anatomy(iAnat).FileName, '_volatlas'))
                    continue;
                end
                % Load MRI history
                MriMat = load(file_fullpath(sSubject.Anatomy(iAnat).FileName), 'History');
                if isfield(MriMat, 'History') && ~isempty(MriMat.History)
                    % Get the import history
                    iImport = find(strcmpi(MriMat.History(:,2), 'import'), 1);
                    if isempty(iImport)
                        continue;
                    end
                    % Parse the import string
                    ImportMri = strrep(MriMat.History{iImport,3}, 'Import from: ', '');
                    if ~file_exist(ImportMri)
                        continue;
                    end
                    % If multiple files have the same import MRI: keep the one with the shortest file name (not post-processed)
                    if ~isempty(MriMatchOrigImport)
                        iPrevMri = find(strcmp(MriMatchOrigImport(:,1), ImportMri));
                    else
                        iPrevMri = [];
                    end
                    if ~isempty(iPrevMri)
                        if (length(ImportMri) < MriMatchOrigImport{iPrevMri,2})
                            MriMatchOrigImport{iPrevMri,2} = ImportMri;
                        end
                    else
                        MriMatchOrigImport(end+1,1:2) = {ImportMri, sSubject.Anatomy(iAnat).FileName};
                    end
                end
            end
        end
        % Error handling
        if ~isempty(errorMsg)
            % If first character is newline: remove it
            if (errorMsg(1) == newline)
                errorMsg = errorMsg(2:end);
            end
            Messages = [Messages, 10, 'Error importing anatomy for: ', SubjectName{iSubj}, 10, errorMsg, 10];
            % DO NOT STOP PROCESSING IF THERE IS AN IMPORT ISSUE IN THE ANATOMY OF ONE SUBJECT
            % if OPTIONS.isInteractive
            %     bst_error(Messages, 'Import BIDS dataset', 0);
            %     return;
            % else
            %     continue;
            % end
        end
            
        % === IMPORT MEG/EEG FILES ===
        % Import options
        ImportOptions = db_template('ImportOptions');
        ImportOptions.ChannelReplace  = 1;
        ImportOptions.ChannelAlign    = 2 * (OPTIONS.ChannelAlign >= 1) * ~sSubject.UseDefaultAnat;
        ImportOptions.DisplayMessages = OPTIONS.isInteractive;
        ImportOptions.EventsMode      = 'ignore';
        ImportOptions.EventsTrackMode = 'value';
        % Get all the files in the session folder
        allMeegFiles = {};
        allMeegDates = {};
        allMeegElecFiles = {};
        allMeegElecFormats = {};
        allMeegElecAnatRef = {};
        allMeegElecFiducials = {};
        subjConditions = bst_get('ConditionsForSubject', sSubject.FileName);
        for isess = 1:length(SubjectSessDir{iSubj})
            if isdir(SubjectSessDir{iSubj}{isess})
                % If the subject already has this session, skip it.
                [tmp, sessionName] = fileparts(SubjectSessDir{iSubj}{isess});
                if any(~cellfun(@isempty, strfind(subjConditions, ['@raw' SubjectName{iSubj} '_' sessionName])))
                    sessionMessage = ['Session "' sessionName '" of subject "' SubjectName{iSubj} '" already exists. Skipping...'];
                    disp(['BIDS> ' sessionMessage]);
                    Messages = [Messages, 10, sessionMessage];
                    continue;
                end
                tsvFiles = {};
                tsvDates = {};
                % Try to read the _scans.tsv file in the session folder, to get the acquisition date
                tsvDir = dir(fullfile(SubjectSessDir{iSubj}{isess}, '*_scans.tsv'));
                if (length(tsvDir) == 1)
                    % Read tsv file
                    tsvValues = in_tsv(fullfile(SubjectSessDir{iSubj}{isess}, tsvDir(1).name), {'filename', 'acq_time'});
                    % If the files and times are defined
                    if ~isempty(tsvValues) && ~isempty(tsvValues{1})
                        tsvFiles = tsvValues(:,1);
                        for iDate = 1:size(tsvValues,1)
                            fDate = [];
                            % Date format: YYYY-MM-DDTHH:MM:SS
                            if (length(tsvValues{iDate,2}) >= 19) && strcmpi(tsvValues{iDate,2}(11), 'T')
                                fDate = sscanf(tsvValues{iDate,2}, '%04d-%02d-%02d');
                            % Date format: YYYYMMDDTHHMMSS
                            elseif (length(tsvValues{iDate,2}) >= 15) && strcmpi(tsvValues{iDate,2}(9), 'T')
                                fDate = sscanf(tsvValues{iDate,2}, '%04d%02d%02d');
                            end
                            % Not recognized
                            if (length(fDate) ~= 3)
                                % Display warning only if something was set but not interpreted
                                if ~isempty(tsvValues{iDate,2}) && ~isequal(lower(tsvValues{iDate,2}), 'n/a')
                                    msg = ['Date format not recognized: "' tsvValues{iDate,2} '"'];
                                    disp(['BIDS> Warning: ' msg]);
                                    Messages = [Messages 10 msg];
                                end
                                fDate = [0 0 0];
                            end
                            tsvDates{iDate} = datestr(datenum(fDate(1), fDate(2), fDate(3)), 'dd-mmm-yyyy');
                        end
                    end
                end
                % Loop on the supported modalities
                for mod = {'meg', 'eeg', 'ieeg','nirs'}
                    posUnits = 'mm';
                    electrodesFile = [];
                    electrodesSpace = 'ScanRAS';
                    electrodesAnatRef = [];
                    electrodesCoordSystem = [];
                    coordsystemSpace = [];
                    sFid = [];
                    
                    % === COORDSYSTEM.JSON ===
                    % Get _coordsystem.json files
                    coordsystemDir = dir(bst_fullfile(SubjectSessDir{iSubj}{isess}, mod{1}, '*_coordsystem.json'));
                    % If multiple coordinate system files in the same folder: not expected unless multiple coordinate systems are available
                    if (length(coordsystemDir) > 1)
                        % Select by order of preference: subject space or MNI space
                        [coordsystemDir, coordsystemSpace, msg] = SelectCoordSystem(coordsystemDir);
                        if ~isempty(msg)
                            disp(['BIDS> Warning: ' msg]);
                            Messages = [Messages 10 msg];
                        end
                    end
                    % Read useful metadata from _coordinates.tsv file
                    if (length(coordsystemDir) == 1)
                        % Read json file
                        jsonFile = bst_fullfile(SubjectSessDir{iSubj}{isess}, mod{1}, coordsystemDir(1).name);
                        try
                            sCoordsystem = bst_jsondecode(jsonFile);
                        catch
                            disp(['BIDS> Error: Cannot read json file: ' jsonFile]);
                            sCoordsystem = [];
                        end
                        if ~isempty(sCoordsystem)
                            % Get units: Assume INAPPROPRIATELY that all the modalities saved their coordinatesi in the same units (it would be weird to do otherwise, but it might happen)
                            if isfield(sCoordsystem, 'iEEGCoordinateUnits') && ~isempty(sCoordsystem.iEEGCoordinateUnits) && ismember(sCoordsystem.iEEGCoordinateUnits, {'mm','cm','m'})
                                posUnits = sCoordsystem.iEEGCoordinateUnits;
                            elseif isfield(sCoordsystem, 'EEGCoordinateUnits') && ~isempty(sCoordsystem.EEGCoordinateUnits) && ismember(sCoordsystem.EEGCoordinateUnits, {'mm','cm','m'})
                                posUnits = sCoordsystem.EEGCoordinateUnits;
                            elseif isfield(sCoordsystem, 'MEGCoordinateUnits') && ~isempty(sCoordsystem.MEGCoordinateUnits) && ismember(sCoordsystem.MEGCoordinateUnits, {'mm','cm','m'})
                                posUnits = sCoordsystem.MEGCoordinateUnits;
                            elseif isfield(sCoordsystem, 'NIRSCoordinateUnits') && ~isempty(sCoordsystem.NIRSCoordinateUnits) && ismember(sCoordsystem.NIRSCoordinateUnits, {'mm','cm','m'})
                                 posUnits = sCoordsystem.NIRSCoordinateUnits;
                            end
                            % Get fiducials structure
                            sFid = GetFiducials(sCoordsystem, posUnits);
                            % If there are no fiducials: there is no easy way to match with the anatomy, and therefore the coordinate system should be interepreted carefully (eg. ACPC for iEEG)
                            if isempty(sFid)
                                if isfield(sCoordsystem, 'iEEGCoordinateSystem') && ~isempty(sCoordsystem.iEEGCoordinateSystem)
                                    electrodesCoordSystem = sCoordsystem.iEEGCoordinateSystem;
                                elseif isfield(sCoordsystem, 'EEGCoordinateSystem') && ~isempty(sCoordsystem.EEGCoordinateSystem)
                                    electrodesCoordSystem = sCoordsystem.EEGCoordinateSystem;
                                elseif isfield(sCoordsystem, 'MEGCoordinateSystem') && ~isempty(sCoordsystem.MEGCoordinateSystem)
                                    electrodesCoordSystem = sCoordsystem.MEGCoordinateSystem;
                               elseif isfield(sCoordsystem, 'NIRSCoordinateSystem') && ~isempty(sCoordsystem.NIRSCoordinateSystem)
                                    electrodesCoordSystem = sCoordsystem.NIRSCoordinateSystem;
                                elseif ~isempty(coordsystemSpace)
                                    electrodesCoordSystem = coordsystemSpace;
                                end
                            end
                            % Coordinates can be linked to the scanner/world coordinates of a specific volume in the dataset
                            if isfield(sCoordsystem, 'IntendedFor') && ~isempty(sCoordsystem.IntendedFor)
                                if file_exist(bst_fullfile(BidsDir, sCoordsystem.IntendedFor))
                                    % Check whether the IntendedFor files is already imported as a volume
                                    if ~isempty(MriMatchOrigImport)
                                        iMriImported = find(cellfun(@(c)file_compare(c, bst_fullfile(BidsDir, sCoordsystem.IntendedFor)), MriMatchOrigImport(:,1)));
                                    else
                                        iMriImported = [];
                                    end
                                    if ~isempty(iMriImported)
                                        electrodesAnatRef = MriMatchOrigImport{iMriImported,2};
                                    else
                                        msg = ['The file in coordsystem.json/IntendedFor is not imported to the database: ' sCoordsystem.IntendedFor];
                                        disp(['BIDS> Warning: ' msg]);
                                        Messages = [Messages 10 msg];
                                    end
                                else
                                    msg = ['The file in coordsystem.json/IntendedFor does not exist: ' sCoordsystem.IntendedFor];
                                    disp(['BIDS> Warning: ' msg]);
                                    Messages = [Messages 10 msg];
                                end
                            end
                        end
                    end
                    
                    % === ELECTRODES.TSV ===
                    % Get electrodes positions
                    if strcmp(mod,'nirs')
                        electrodesDir = dir(bst_fullfile(SubjectSessDir{iSubj}{isess}, mod{1}, '*_optodes.tsv'));
                    else
                        electrodesDir = dir(bst_fullfile(SubjectSessDir{iSubj}{isess}, mod{1}, '*_electrodes.tsv'));
                    end
                    % If multiple positions in the same folder: not expected unless multiple coordinate systems are available
                    if (length(electrodesDir) > 1)
                        % Select by order of preference: subject space, MNI space or first in the list
                        [electrodesDir, electrodesSpace, msg] = SelectCoordSystem(electrodesDir);
                        if ~isempty(msg)
                            disp(['BIDS> Warning: ' msg]);
                            Messages = [Messages 10 msg];
                        end
                    end
                    % If the coordinate system is specified in the _coordsystem.json and no fiducials are available
                    if ~isempty(electrodesCoordSystem)
                        if strcmpi(electrodesCoordSystem, 'ACPC')
                            electrodesSpace = 'ACPC';
                        elseif strcmpi(electrodesCoordSystem, 'CapTrak')
                            electrodesSpace = 'CapTrak';
                        elseif ~isempty(strfind(electrodesCoordSystem, 'MNI')) || ~isempty(strfind(electrodesCoordSystem, 'IXI')) || ~isempty(strfind(electrodesCoordSystem, 'ICBM'))  || ~isempty(strfind(electrodesCoordSystem, 'fs')) 
                            electrodesSpace = 'MNI';
                        elseif ismember(upper(electrodesCoordSystem), {'CTF', 'EEGLAB', 'EEGLAB-HJ', 'ElektaNeuromag', '4DBti', 'KitYokogawa', 'ChietiItab'})
                            electrodesSpace = 'ALS';
                        end
                    end
                    % Get full file path to _electrodes.tsv
                    if (length(electrodesDir) == 1)
                        electrodesFile = bst_fullfile(SubjectSessDir{iSubj}{isess}, mod{1}, electrodesDir(1).name);
                    end
                    % Read the contents of the session folder
                    meegDir = dir(bst_fullfile(SubjectSessDir{iSubj}{isess}, mod{1}, '*.*'));
                    for iFile = 1:length(meegDir)
                        % Skip hidden files and .json/.tsv files
                        [fPath,fBase,fExt] = bst_fileparts(meegDir(iFile).name);
                        if (meegDir(iFile).name(1) == '.') || ismember(fExt, {'.json','.tsv'})
                            continue;
                        end
                        % Get full file name
                        allMeegFiles{end+1} = bst_fullfile(SubjectSessDir{iSubj}{isess}, mod{1}, meegDir(iFile).name);
                        % Try to get the recordings date from the tsv file
                        if ~isempty(tsvFiles)
                            iFileTsv = find(strcmp([mod{1}, '/', meegDir(iFile).name], tsvFiles));
                            if ~isempty(iFileTsv)
                                allMeegDates{length(allMeegFiles)} = tsvDates{iFileTsv};
                            end
                        end
                        % Add electrodes file
                        allMeegElecFiles{end+1} = electrodesFile;
                        allMeegElecFormats{end+1} = ['BIDS-' upper(electrodesSpace) '-' upper(posUnits)];
                        allMeegElecAnatRef{end+1} = electrodesAnatRef;
                        allMeegElecFiducials{end+1} = sFid;
                    end
                end
            end
        end
        
        % === IMPORT RECORDINGS ===
        % Try import them all, one by one
        for iFile = 1:length(allMeegFiles)
            % Acquisition date
            if (length(allMeegDates) >= iFile) && ~isempty(allMeegDates{iFile})
                DateOfStudy = allMeegDates{iFile};
            else
                DateOfStudy = [];
            end
            % Get file extension
            [tmp, fBase, fExt] = bst_fileparts(allMeegFiles{iFile});
            % Import depending on this extension
            switch (fExt)
                case '.ds',    FileFormat = 'CTF';
                case '.fif',   FileFormat = 'FIF';
                case '.eeg',   FileFormat = 'EEG-BRAINAMP';
                case '.edf',   FileFormat = 'EEG-EDF';
                case '.set',   FileFormat = 'EEG-EEGLAB';
                case '.snirf', FileFormat = 'NIRS-SNIRF';    
                otherwise,     FileFormat = [];
            end
            % Import file if file was identified
            if ~isempty(FileFormat)
                % Import files to database
                newFiles = import_raw(allMeegFiles{iFile}, FileFormat, iSubject, ImportOptions, DateOfStudy);
                RawFiles = [RawFiles{:}, newFiles];
                OrigFiles = [OrigFiles{:}, repmat(allMeegFiles(iFile), length(newFiles), 1)];
                % Add electrodes positions if available
                if ~isempty(allMeegElecFiles{iFile}) && ~isempty(allMeegElecFormats{iFile})
                    % Subject T1 coordinates (space-ScanRAS)
                    if ~isempty(strfind(allMeegElecFormats{iFile}, '-SCANRAS-'))
                        % If using the vox2ras transformation: also removes the SPM coregistrations computed in Brainstorm
                        % after importing the files, as these transformation were not available in the BIDS dataset
                        isVox2ras = 2;
                    % Or MNI coordinates (space-IXI549Space or other MNI space)
                    else
                        isVox2ras = 0;
                    end
                    % Import electrode positions
                    % Note: this does not work if channel names different in data and metadata - see note in the function header
                    bst_process('CallProcess', 'process_channel_addloc', newFiles, [], ...
                        'channelfile', {allMeegElecFiles{iFile}, allMeegElecFormats{iFile}}, ...
                        'fixunits',    0, ...
                        'vox2ras',     isVox2ras, ...
                        'mrifile',     {allMeegElecAnatRef{iFile}, 'BST'}, ...
                        'fiducials',   allMeegElecFiducials{iFile});
                end
                % Get base file name
                iLast = find(allMeegFiles{iFile} == '_', 1, 'last');
                if isempty(iLast)
                    continue;
                end
                baseName = allMeegFiles{iFile}(1:iLast-1);
                
                % Load _events.tsv
                EventsFile = [baseName, '_events.tsv'];
                if file_exist(EventsFile)
                    bst_process('CallProcess', 'process_evt_import', newFiles, [], ...
                        'evtfile', {EventsFile, 'BIDS'}, ...
                        'delete',  1);
                end
                
                % Load _channels.tsv
                ChannelsFile = [baseName, '_channels.tsv'];
                if file_exist(ChannelsFile)
                    % Read tsv file
                    % For _channels.tsv, 'name', 'type' and 'units' are required.
                    % 'group' and 'status' are fields added by Brainstorm export to BIDS.
                    if strcmp(fExt,'.snirf')
                          ChanInfo_tmp = in_tsv(ChannelsFile, {'name','type','source','detector','wavelength_nominal', 'status'});
                          ChanInfo = cell(size(ChanInfo_tmp,1), 4); % {'name', 'type', 'group', 'status'}
                          ChanInfo(:,2)  = ChanInfo_tmp(:,2);
                          ChanInfo(:,4)  = ChanInfo_tmp(:,6);
                          for i = 1:size(ChanInfo,1)
                             ChanInfo{i,1} = sprintf('%s%sWL%d',ChanInfo_tmp{i,3},ChanInfo_tmp{i,4},str2double(ChanInfo_tmp{i,5}));
                             ChanInfo{i,3} = sprintf('WL%d', str2double(ChanInfo_tmp{i,5}));
                          end   
                     else    
                         ChanInfo = in_tsv(ChannelsFile, {'name', 'type', 'group', 'status'});
                    end  

                    % Try to add info to the existing Brainstorm channel file
                    % Note: this does not work if channel names different in data and metadata - see note in the function header
                    if ~isempty(ChanInfo) || ~isempty(ChanInfo{1,1})
                        % For all the loaded files
                        for iRaw = 1:length(newFiles)
                            % Get channel file
                            [ChannelFile, sStudy, iStudy] = bst_get('ChannelFileForStudy', newFiles{iRaw});
                            % Load channel file
                            ChannelMat = in_bst_channel(ChannelFile);
                            % Get current list of good/bad channels
                            DataMat = in_bst_data(newFiles{iRaw}, 'ChannelFlag', 'F');
                            % Modified flags
                            isModifiedChan = 0;
                            isModifiedData = 0;
                            % Loop to find matching channels
                            for iChanBids = 1:size(ChanInfo,1)
                                % Look for corresponding channel in Brainstorm channel file
                                iChanBst = find(strcmpi(ChanInfo{iChanBids,1}, {ChannelMat.Channel.Name}));
                                if isempty(iChanBst)
                                    iChanBst = find(strcmpi(strrep(ChanInfo{iChanBids,1}, ' ', ''), {ChannelMat.Channel.Name}));
                                    if isempty(iChanBst)
                                        continue;
                                    end
                                end
                                % Copy type
                                if ~isempty(ChanInfo{iChanBids,2}) && ~strcmpi(ChanInfo{iChanBids,2},'n/a')
                                    chanType = upper(ChanInfo{iChanBids,2});
                                    switch (chanType)
                                        case 'MEGGRADPLANAR'    % Elekta planar gradiometer
                                            chanType = 'MEG GRAD';
                                        case 'MEGMAG'           % Elekta/4D/Yokogawa magnetometer
                                            chanType = 'MEG MAG';
                                        case 'MEGGRADAXIAL'     % CTF axial gradiometer
                                            chanType = 'MEG';
                                        case {'MEGREFMAG', 'MEGREFGRADAXIAL', 'MEGREFGRADPLANAR'}  % CTF/4D references
                                            chanType = 'MEG REF';
                                        case {'NIRSCWAMPLITUDE'}
                                             chanType = 'NIRS';
                                    end
                                    % Keep the "EEG_NO_LOC" type
                                    if ~isequal(ChannelMat.Channel(iChanBst).Type, 'EEG_NO_LOC') || (~isempty(ChannelMat.Channel(iChanBst).Loc) && ~all(ChannelMat.Channel(iChanBst).Loc(:) == 0))
                                        ChannelMat.Channel(iChanBst).Type = chanType;
                                        isModifiedChan = 1;
                                    end
                                end
                                % Copy group
                                if ~isempty(ChanInfo{iChanBids,3}) && ~strcmpi(ChanInfo{iChanBids,3},'n/a')
                                    ChannelMat.Channel(iChanBst).Group = ChanInfo{iChanBids,3};
                                    isModifiedChan = 1;
                                end
                                % Copy channel status
                                if ~isempty(ChanInfo{iChanBids,4}) && strcmpi(ChanInfo{iChanBids,4}, 'good')
                                    DataMat.ChannelFlag(iChanBst) = 1;
                                    isModifiedData = 1;
                                elseif ~isempty(ChanInfo{iChanBids,4}) && strcmpi(ChanInfo{iChanBids,4}, 'bad')
                                    DataMat.ChannelFlag(iChanBst) = -1;
                                    isModifiedData = 1;
                                end
                            end
                            % Save channel file modifications
                            if isModifiedChan
                                % Update channel file
                                bst_save(file_fullpath(ChannelFile), ChannelMat, 'v7');
                                % Update database
                                [sStudy.Channel.Modalities, sStudy.Channel.DisplayableSensorTypes] = channel_get_modalities(ChannelMat.Channel);
                                bst_set('Study', iStudy, sStudy);
                            end
                            % Save data file modifications
                            if isModifiedData
                                DataMat.F.channelflag = DataMat.ChannelFlag;
                                bst_save(newFiles{iRaw}, DataMat, 'v6', 1);
                            end
                        end
                    end                   
                end

                % === MEG.JSON ===
                % Get _meg.json next to the recordings file
                MegFile = [baseName, '_meg.json'];
                % Get _meg.json in the same folder as the recordings file
                if ~file_exist(MegFile)
                    megDir = dir(fullfile(fileparts(allMeegFiles{iFile}), '*_meg.json'));
                    if (length(megDir) == 1)
                        MegFile = fullfile(fileparts(allMeegFiles{iFile}), megDir(1).name);
                    end
                end
                % Get _meg.json in the session folder (one folder above)
                if ~file_exist(MegFile)
                    megDir = dir(fullfile(fileparts(fileparts(allMeegFiles{iFile})), '*_meg.json'));
                    if (length(megDir) == 1)
                        MegFile = fullfile(fileparts(fileparts(allMeegFiles{iFile})), megDir(1).name);
                    end
                end
                % If there is a meg.json file: read it to get the AssociatedEmptyRoom field
                if file_exist(MegFile)
                    try
                        json = bst_jsondecode(MegFile);
                    catch
                        disp(['BIDS> Error: Cannot read json file: ' MegFile]);
                        json = [];
                    end
                    % Save the empty-room associations, and process them later
                    if ~isempty(json) && isfield(json, 'AssociatedEmptyRoom') && ~isempty(json.AssociatedEmptyRoom) && file_exist(fullfile(BidsDir, json.AssociatedEmptyRoom))
                        for iRaw = 1:length(newFiles)
                            EmptyRoomMatch(end+1, 1:2) = {newFiles{iRaw}, json.AssociatedEmptyRoom};
                        end
                    end
                end
            end
        end
    end

    % ===== COMPUTE NOISE COVARIANCE =====
    if ~isempty(EmptyRoomMatch)
        % Process each empty room file separately 
        uniqueEmptyRoom = unique(EmptyRoomMatch(:,2));
        % Compute the noise covariance for each file
        for iNoise = 1:length(uniqueEmptyRoom)
            % Find the link imported in the database for this emptyroom recordings
            origEmptyFile = fullfile(BidsDir, uniqueEmptyRoom{iNoise});
            iRawEmpty = find(file_compare(origEmptyFile, OrigFiles));
            if isempty(iRaw)
                continue;
            end
            % Compute the noise covariance
            sFilesEmpty = bst_process('CallProcess', 'process_noisecov', RawFiles{iRawEmpty}, [], ...
                'baseline',       [], ...
                'datatimewindow', [], ...
                'sensortypes',    '', ...
                'target',         1, ...  % Noise covariance     (covariance over baseline time window)
                'dcoffset',       1, ...  % Block by block, to avoid effects of slow shifts in data
                'identity',       0, ...
                'copycond',       0, ...
                'copysubj',       0, ...
                'copymatch',      0, ...
                'replacefile',    1);  % Replace
            % Find the studies matched with these noise recordings
            iOrigDest = find(strcmp(EmptyRoomMatch(:,2), uniqueEmptyRoom{iNoise}));
            % Copy noisecov to all the matched folders 
            for iDest = iOrigDest
                % Find study index where the file was imported
                [sStudyDest, iStudyDest] = bst_get('DataFile', EmptyRoomMatch{iDest,1});
                if isempty(iStudyDest)
                    continue;
                end
                % Copy noise covariance to destination study 
                db_set_noisecov(sFilesEmpty.iStudy, iStudyDest, 0, 1);
            end
        end
    end

    % If first character is newline: remove it
    if ~isempty(Messages) && (Messages(1) == newline)
        Messages = Messages(2:end);
    end
end


%% ===== FIND SUBJECT ANATOMY =====
function [AnatDir, AnatFormat] = GetSubjectSeg(BidsDir, subjName)
    % Inialize returned structures
    AnatDir    = [];
    AnatFormat = [];
    DerivDir = bst_fullfile(BidsDir, 'derivatives');
    % FreeSurfer
    subDir = dir(bst_fullfile(DerivDir, 'freesurfer*', subjName));
    if ~isempty(subDir)
        TestFile = file_find(subDir(1).folder, 'T1.mgz');
        if ~isempty(TestFile)
            AnatDir = bst_fileparts(bst_fileparts(TestFile));
            AnatFormat = 'FreeSurfer';
            return;
        end
    end
    % CAT12
    subDir = dir(bst_fullfile(DerivDir, 'cat12*', subjName));
    if ~isempty(subDir)
        TestFile = file_find(subDir(1).folder, 'lh.central.*.gii');
        if ~isempty(TestFile)
            AnatDir = bst_fileparts(bst_fileparts(TestFile));
            AnatFormat = 'CAT12';
        end
    end
    % BrainSuite
    subDir = dir(bst_fullfile(DerivDir, 'cat12*', subjName));
    if ~isempty(subDir)
        TestFile = file_find(subDir(1).folder, '*.left.pial.cortex.svreg.dfs');
        if ~isempty(TestFile)
            AnatDir = bst_fileparts(TestFile);
            AnatFormat = 'BrainSuite';
            return;
        end
    end
    % BrainVISA
    subDir = dir(bst_fullfile(DerivDir, 'brainvisa*', subjName));
    if ~isempty(subDir)
        TestFile = file_find(subDir(1).folder, 'nobias_*.*');
        if ~isempty(TestFile)
            AnatDir = bst_fileparts(bst_fileparts(bst_fileparts(bst_fileparts(TestFile))));
            AnatFormat = 'BrainVISA';
            return;
        end
    end
    % CIVET
    subDir = dir(bst_fullfile(DerivDir, 'civet*', subjName));
    if ~isempty(subDir)
        TestFile = file_find(subDir(1).folder, '*_t1.mnc');
        if ~isempty(TestFile)
            AnatDir = bst_fileparts(bst_fileparts(TestFile));
            AnatFormat = 'CIVET';
            return;
        end
    end
end

function MriFiles = GetSubjectMri(anatFolder)
    MriFiles = {};
    isMpRage = [];
    % Find .nii or .nii.gz in the anat folder
    mriDir = dir(bst_fullfile(anatFolder, '*T1w.nii*'));
    for i = 1:length(mriDir)
        MriFiles{end+1} = bst_fullfile(anatFolder, mriDir(i).name);
        isMpRage(i) = ~isempty(strfind(lower(mriDir(i).name), 'mprage'));
    end
    % Put mprage first
    if ~isempty(MriFiles) && any(isMpRage)
        iMpRage = find(isMpRage);
        MriFiles = cat(2, MriFiles(iMpRage), MriFiles(setdiff(1:length(MriFiles), iMpRage)));
    end
    % Find T2w volumes
    mriDir = dir(bst_fullfile(anatFolder, '*T2w.nii*'));
    for i = 1:length(mriDir)
        MriFiles{end+1} = bst_fullfile(anatFolder, mriDir(i).name);
    end
    % Find CT volumes
    mriDir = dir(bst_fullfile(anatFolder, '*CT.nii*'));
    for i = 1:length(mriDir)
        MriFiles{end+1} = bst_fullfile(anatFolder, mriDir(i).name);
    end
end

%% ===== SELECT BIDS DIR =====
% Selects a valid BIDS folder and a list of selected subject if applicable.
function [BidsDir, selectedSubjects, errorMessage] = GetValidBidsDir(inputFolders)
    BidsDir = [];
    selectedSubjects = {};
    errorMessage = [];
    
    if isempty(inputFolders)
        errorMessage = 'No BIDS folder provided.';
        return;
    elseif ~iscell(inputFolders)
        inputFolders = {inputFolders};
    end
    
    numFolders = length(inputFolders);
    json_file = 'dataset_description.json';
    
    for iFolder = 1:numFolders
        % If no dataset JSON file, this might be a subject. Check parent.
        if ~file_exist(bst_fullfile(inputFolders{iFolder}, json_file))
            [parentFolder, folderName] = fileparts(inputFolders{iFolder});
            if file_exist(bst_fullfile(parentFolder, json_file))
                if isempty(BidsDir)
                    BidsDir = parentFolder;
                elseif ~file_compare(BidsDir, parentFolder)
                    errorMessage = 'This process only supports importing multiple subjects from the same BIDS dataset.';
                    return;
                end
                selectedSubjects{end + 1} = folderName;
            else
                errorMessage = ['Invalid BIDS dataset: missing file "' json_file '"'];
                return;
            end
        % If a dataset JSON file, make sure it's the only supplied folder.
        elseif numFolders == 1
            BidsDir = inputFolders{iFolder};
        else
            errorMessage = 'This process only supports one BIDS folder at a time.';
            return;
        end
    end
end


%% ===== SELECT COORDINATE SYSTEM =====
% Tries to find the best coordinate system available: subject space, otherwise MNI space
function [fileList, fileSpace, wrnMsg] = SelectCoordSystem(fileList)
    wrnMsg = [];
    % T1 subject space (after 2022)
    iSel = find(~cellfun(@(c)isempty(strfind(lower(c),'space-scanras')), {fileList.name}));
    if ~isempty(iSel)
        fileList = fileList(iSel);
        fileSpace = 'ScanRAS';
        return;
    end
    % T1 subject space (before 2022)
    iSel = find(~cellfun(@(c)isempty(strfind(lower(c),'space-other')), {fileList.name}) | ~cellfun(@(c)isempty(strfind(lower(c),'space-orig')), {fileList.name}));
    if ~isempty(iSel)
        fileList = fileList(iSel);
        fileSpace = 'ScanRAS';
        return;
    end
    % IXI549Space SPM12 space
    iSel = find(~cellfun(@(c)isempty(strfind(lower(c),'space-ixi549space')), {fileList.name}));
    if ~isempty(iSel)
        fileList = fileList(iSel);
        fileSpace = 'MNI';
        return;
    end
    % Other MNI space
    iSel = find(~cellfun(@(c)isempty(strfind(lower(c),'space-mni')), {fileList.name}));
    if ~isempty(iSel)
        fileList = fileList(iSel);
        fileSpace = 'MNI';
        return;
    end
    % Nothing interpretable found: Use first in the list
    wrnMsg = ['Could not interpret subject coordinate system, using randomly "' fileList(1).name '".'];
    fileList = fileList(1);
    fileSpace = 'ScanRAS';
end


%% ===== GET FIDUCIALS STRUCTURE =====
function [sFid, Messages] = GetFiducials(json, defaultUnits)
    Messages = [];
    % No anatomical landmarks: NAS, LPA, RPA
    if isfield(json, 'FiducialsCoordinates') && ~isempty(json.FiducialsCoordinates)
        fieldName = 'Fiducials';
    elseif isfield(json, 'AnatomicalLandmarkCoordinates') && ~isempty(json.AnatomicalLandmarkCoordinates)
        fieldName = 'AnatomicalLandmark';
    else
        sFid = [];
        return
    end
    % Get units
    if isfield(json, [fieldName 'CoordinateUnits']) && ismember(json.([fieldName 'CoordinateUnits']), {'mm','cm','m'})
        units = json.([fieldName 'CoordinateUnits']);
    else
        units = defaultUnits;
    end
    % Get anatomical landmarks
    lm = json.([fieldName 'Coordinates']);
    % Get the positions for each fiducial
    sFid = struct('NAS', [], 'LPA', [], 'RPA', [], 'AC', [], 'PC', [], 'IH', []);
    fidNames = {};
    for fid = reshape(fieldnames(sFid), 1, [])
        % Fiducial with the exact name: use this one
        if isfield(lm, fid{1})
            fidNames = fid(1);
        % Otherwise: get all the landmarks that include the fiducial name, and later average them
        else
            fields = fieldnames(lm);
            iField = find(~cellfun(@(c)isempty(strfind(c, fid{1})), fields));
            if ~isempty(iField)
                fidNames = fields(iField);
            else
                continue;
            end
        end
        % Get all the coordinates available in this structure
        fidNamesAvg = {};
        for i = 1:length(fidNames)
            if (length(lm.(fidNames{i})) == 3) && ~isequal(reshape(lm.(fidNames{i}), 1, 3), [0,0,0])
                sFid.(fid{1}) = [sFid.(fid{1}); reshape(lm.(fidNames{i}), 1, 3)];
                fidNamesAvg{end+1} = fidNames{i};
            end
        end
        % Warning when averaging multiple positions
        if (length(fidNamesAvg) > 1)
            Messages = [Messages, fid{1}, ': Averaging fields: ', sprintf('%s ', fidNamesAvg{:}), 10];
        end
        % Average all the positions
        sFid.(fid{1}) = mean(sFid.(fid{1}), 1);
        % Voxels: 0-based
        if strcmpi(defaultUnits, 'voxel')
            % Keep it unchanged
        % Otherwise: Apply units
        else
            sFid.(fid{1}) = bst_units_ui(units, sFid.(fid{1}));
        end
    end
    % Cancel if not all fiducials were found 
    if isempty(sFid.NAS) || isempty(sFid.LPA) || isempty(sFid.RPA)
        sFid = [];
    end
end

