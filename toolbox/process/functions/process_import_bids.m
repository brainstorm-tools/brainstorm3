function varargout = process_import_bids( varargin )
% PROCESS_IMPORT_BIDS: Import a dataset organized following the BIDS specficiations (http://bids.neuroimaging.io/)
%
% USAGE:           OutputFiles = process_import_bids('Run', sProcess, sInputs)
%         [RawFiles, Messages] = process_import_bids('ImportBidsDataset', BidsDir=[ask], nVertices=[ask], isInteractive=1, ChannelAlign=0)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2016-2019; Martin Cousineau, 2018

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Import BIDS dataset';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Import';
    sProcess.Index       = 41;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/RestingOmega';
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
    sProcess.options.selectsubj.Comment = 'Names of subjects to import:';
    sProcess.options.selectsubj.Type    = 'text';
    sProcess.options.selectsubj.Value   = '';
    % Option: Number of vertices
    sProcess.options.nvertices.Comment = 'Number of vertices (cortex): ';
    sProcess.options.nvertices.Type    = 'value';
    sProcess.options.nvertices.Value   = {15000, '', 0};
    % Align sensors
    sProcess.options.channelalign.Comment = 'Align sensors using headpoints';
    sProcess.options.channelalign.Type    = 'checkbox';
    sProcess.options.channelalign.Value   = 1;
    % Group sessions
    sProcess.options.groupsessions.Comment = 'Import multiple anat sessions to the same subject';
    sProcess.options.groupsessions.Type    = 'checkbox';
    sProcess.options.groupsessions.Value   = 1;
    % Compute BEM surfaces
    sProcess.options.bem.Comment = 'Generate BEM skull surfaces (recommended for ECoG)';
    sProcess.options.bem.Type    = 'checkbox';
    sProcess.options.bem.Value   = 1;
    % Register anatomy
    sProcess.options.anatregister.Comment = {'SPM12', 'No', 'Coregister anatomical volumes:'; ...
                                             'spm12', 'no', ''};
    sProcess.options.anatregister.Type    = 'radio_linelabel';
    sProcess.options.anatregister.Value   = 'spm12';
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
    OPTIONS.ChannelAlign     = 2 * double(sProcess.options.channelalign.Value);
    OPTIONS.SelectedSubjects = strtrim(str_split(sProcess.options.selectsubj.Value, ','));
    OPTIONS.isGroupSessions  = sProcess.options.groupsessions.Value;
    OPTIONS.isGenerateBem    = sProcess.options.bem.Value;
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
% USAGE:  [RawFiles, Messages] = process_import_bids('ImportBidsDataset', BidsDir=[ask], OPTIONS=[])
function [RawFiles, Messages] = ImportBidsDataset(BidsDir, OPTIONS)
    % Initialize returned values
    RawFiles = {};
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
        'isGenerateBem',    1, ...
        'RegisterMethod',   'spm12');
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
    OPTIONS.SelectedSubjects = unique([OPTIONS.SelectedSubjects, selSubjects]);
    
    % ===== IDENTIFY SUBJECTS =====
    % List all the subject folders
    subjDir = dir(bst_fullfile(BidsDir, 'sub-*'));
    % If no subject are available, try in the derivatives folder (if we are importing tsss data only for instance)
    if isempty(subjDir)
        subjDir = dir(bst_fullfile(BidsDir, 'derivatives', 'meg_derivatives', 'sub-*'));
    end
    if isempty(subjDir)
        subjDir = dir(bst_fullfile(BidsDir, 'derivatives', 'freesurfer', 'sub-*'));
    end
    % Loop on the subjects
    SubjectName = {};
    SubjectAnatDir = {};
    SubjectAnatFormat = {};
    SubjectSessDir = {};
    SubjectMriFiles = {};
    for iSubj = 1:length(subjDir)
        % Default subject name
        subjName = subjDir(iSubj).name;
        % Check if this is a subject selected for import
        if ~isempty(OPTIONS.SelectedSubjects) && ((iscell(OPTIONS.SelectedSubjects) && ~ismember(subjName, OPTIONS.SelectedSubjects)) || (ischar(OPTIONS.SelectedSubjects) && ~strcmpi(subjName, OPTIONS.SelectedSubjects)))
            disp(['BIDS> Subject "' subjName '" was not selected. Skipping...']);
            continue;
        end
        % Get session folders
        sessDir = dir(bst_fullfile(BidsDir, subjName, 'ses-*'));
        % Check if sessions are defined for the derivatives
        if isempty(sessDir) && isdir(bst_fullfile(BidsDir, 'derivatives', 'meg_derivatives', subjName))
            sessDir = dir(bst_fullfile(BidsDir, 'derivatives', 'meg_derivatives', subjName, 'ses-*'));
        end
        if isempty(sessDir)
            sessFolders = {bst_fullfile(BidsDir, subjName)};
            derivFolders = {bst_fullfile(BidsDir, 'derivatives', 'meg_derivatives', subjName)};
        else
            sessFolders = cellfun(@(c)fullfile(BidsDir, subjName, c), {sessDir.name}, 'UniformOutput', 0);
            derivFolders = cellfun(@(c)fullfile(BidsDir, 'derivatives', 'meg_derivatives', subjName, c), {sessDir.name}, 'UniformOutput', 0);
        end
        
        % If there is one unique segmented anatomy: group all the sessions together
        [AnatDir, AnatFormat] = GetSubjectSeg(BidsDir, subjName);
        % If there is no segmented folder, try SUBJID_SESSID
        if isempty(AnatDir) && (length(sessDir) == 1)
            [AnatDir, AnatFormat] = GetSubjectSeg(BidsDir, [subjName, '_', sessDir(1).name]);
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
        
        % If a single anatomy folder is found
        if ~isempty(AnatDir)
            SubjectName{end+1}       = subjName;
            SubjectAnatDir{end+1}    = AnatDir;
            SubjectAnatFormat{end+1} = AnatFormat;
            SubjectSessDir{end+1}    = cat(2, sessFolders, derivFolders);
            SubjectMriFiles{end+1}   = allMriFiles;
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
                    SubjectName{end+1}       = [subjName, '_', sessDir(isess).name];
                    SubjectAnatDir{end+1}    = sessAnatDir;
                    SubjectAnatFormat{end+1} = sessAnatFormat;
                    SubjectSessDir{end+1}    = {sessFolders{isess}, derivFolders{isess}};
                    SubjectMriFiles{end+1}   = allMriFiles;
                end
            % There are no segmentations, check if there is one T1 volume per session or per subject
            else
                % If there is one anatomy per session
                if isSessMri && ~OPTIONS.isGroupSessions
                    for isess = 1:length(sessFolders)
                        sessMriFiles = GetSubjectMri(bst_fullfile(sessFolders{isess}, 'anat'));
                        SubjectName{end+1}       = [subjName, '_', sessDir(isess).name];
                        SubjectAnatDir{end+1}    = [];
                        SubjectAnatFormat{end+1} = [];
                        SubjectSessDir{end+1}    = {sessFolders{isess}, derivFolders{isess}};
                        SubjectMriFiles{end+1}   = sessMriFiles;
                    end
                % One common anatomy for all the sessions
                else
                    SubjectName{end+1}       = subjName;
                    SubjectAnatDir{end+1}    = [];
                    SubjectAnatFormat{end+1} = [];
                    SubjectSessDir{end+1}    = cat(2, sessFolders, derivFolders);
                    SubjectMriFiles{end+1}   = allMriFiles;
                end
            end
        % One session
        elseif (length(sessFolders) == 1)
            SubjectName{end+1}       = subjName;
            SubjectAnatDir{end+1}    = [];
            SubjectAnatFormat{end+1} = [];
            SubjectSessDir{end+1}    = cat(2, sessFolders, derivFolders);
            SubjectMriFiles{end+1}   = GetSubjectMri(bst_fullfile(sessFolders{1}, 'anat'));
        end
        
        % Reorder MRI: Add the onesin "ses-pre" in front of the others, so that they are imported first and become the defaults
        if (length(SubjectMriFiles{end}) > 1)
            iSesPre = find(~cellfun(@(c)isempty(strfind(c,'ses-pre')), SubjectMriFiles{end}));
            if ~isempty(iSesPre) && (length(iSesPre) < length(SubjectMriFiles{end}))
                iReorder = [iSesPre, setdiff(1:length(SubjectMriFiles{end}),iSesPre)];
                SubjectMriFiles{end} = SubjectMriFiles{end}(iReorder);
            end
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
    for iSubj = 1:length(SubjectName)
        errorMsg = [];
        
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
        
        % === IMPORT ANATOMY ===
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
            % Import subject anatomy
            switch (SubjectAnatFormat{iSubj})
                case 'FreeSurfer'
                    errorMsg = import_anatomy_fs(iSubject, SubjectAnatDir{iSubj}, OPTIONS.nVertices, isInteractiveAnat, [], 0);
                case 'BrainSuite'
                    errorMsg = import_anatomy_bs(iSubject, SubjectAnatDir{iSubj}, OPTIONS.nVertices, isInteractiveAnat, []);
                case 'BrainVISA'
                    errorMsg = import_anatomy_bv(iSubject, SubjectAnatDir{iSubj}, OPTIONS.nVertices, isInteractiveAnat, []);
                case 'CIVET'
                    errorMsg = import_anatomy_civet(iSubject, SubjectAnatDir{iSubj}, OPTIONS.nVertices, isInteractiveAnat, [], 0);
                otherwise
                    errorMsg = ['Invalid file format: ' SubjectAnatFormat{iSubj}];
            end
        end
        % Import MRI
        if ~isSkipAnat && ~isempty(SubjectMriFiles{iSubj})
            MrisToRegister = {};
            % Import first MRI
            BstMriFile = import_mri(iSubject, SubjectMriFiles{iSubj}{1}, 'ALL', isInteractiveAnat, 0);
            if isempty(BstMriFile)
                if ~isempty(errorMsg)
                    errorMsg = [errorMsg, 10];
                end
                errorMsg = [errorMsg, 'Could not load MRI file: ', SubjectMriFiles{iSubj}];
            % Compute additional files
            else
                % If there was no segmentation imported before: normalize and create head surface
                if isempty(SubjectAnatDir{iSubj})
                    % Compute MNI transformation
                    [sMri, errorMsg] = bst_normalize_mni(BstMriFile);
                    % Generate head surface
                    tess_isohead(iSubject, 10000, 0, 2);
                else
                    MrisToRegister{end+1} = BstMriFile;
                end
                % Add other volumes
                for i = 2:length(SubjectMriFiles{iSubj})
                    MrisToRegister{end+1} = import_mri(iSubject, SubjectMriFiles{iSubj}{i}, 'ALL', 0, 1);
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
                        end
                    end
                end
            end
        end
        % Compute BEM skull surfaces
        if ~isSkipAnat && OPTIONS.isGenerateBem
            sFiles = bst_process('CallProcess', 'process_generate_bem', [], [], ...
                'subjectname', SubjectName{iSubj}, ...
                'nscalp',      1922, ...
                'nouter',      1922, ...
                'ninner',      1922, ...
                'thickness',   4);
            if isempty(sFiles)
                if ~isempty(errorMsg)
                    errorMsg = [errorMsg, 10];
                end
                errorMsg = [errorMsg, 'Could not generate BEM surfaces for subject: ', SubjectName{iSubj}];
            end
        end
        % Error handling
        if ~isempty(errorMsg)
            Messages = [Messages, 10, errorMsg];
            if OPTIONS.isInteractive
                bst_error(Messages, 'Import BIDS dataset', 0);
                return;
            else
                continue;
            end
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
        subjConditions = bst_get('ConditionsForSubject', sSubject.FileName);
%         DefaultMri = [];
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
                                disp(['BIDS> Warning: Date format not recognized: "' tsvValues{iDate,2} '"']);
                                fDate = [0 0 0];
                            end
                            tsvDates{iDate} = datestr(datenum(fDate(1), fDate(2), fDate(3)), 'dd-mmm-yyyy');
                        end
                    end
                end
                % Loop on the supported modalities
                for mod = {'meg', 'eeg', 'ieeg'}
                    posUnits = 'mm';
                    electrodesFile = [];
                    electrodesSpace = 'orig';
                    
                    % === COORDSYSTEM.JSON ===
                    % Get _coordsystem.json files
                    coordsystemDir = dir(bst_fullfile(SubjectSessDir{iSubj}{isess}, mod{1}, '*_coordsystem.json'));
                    if (length(coordsystemDir) > 1)
                        % Select by order of preference: subject space or MNI space
                        coordsystemDir = SelectCoordSystem(coordsystemDir);
                    end
                    if (length(coordsystemDir) == 1)
                        sCoordsystem = bst_jsondecode(bst_fullfile(SubjectSessDir{iSubj}{isess}, mod{1}, coordsystemDir(1).name));
                        if isfield(sCoordsystem, 'iEEGCoordinateUnits') && ~isempty(sCoordsystem.iEEGCoordinateUnits) && ismember(sCoordsystem.iEEGCoordinateUnits, {'mm','cm','m'})
                            posUnits = sCoordsystem.iEEGCoordinateUnits;
                        end
%                         if isfield(sCoordsystem, 'IntendedFor') && ~isempty(sCoordsystem.IntendedFor) && file_exist(bst_fullfile(BidsDir, sCoordsystem.IntendedFor))
%                             DefaultMri = bst_fullfile(BidsDir, sCoordsystem.IntendedFor);
%                         end
                    end
                    
                    % === ELECTRODES.TSV ===
                    % Get electrodes positions
                    electrodesDir = dir(bst_fullfile(SubjectSessDir{iSubj}{isess}, mod{1}, '*_electrodes.tsv'));
                    if (length(electrodesDir) >= 1)
                        % Select by order of preference: subject space, MNI space or first in the list
                        [electrodesDir, electrodesSpace] = SelectCoordSystem(electrodesDir);
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
                otherwise,     FileFormat = [];
            end
            % Import file if file was identified
            if ~isempty(FileFormat)
                % Import files to database
                newFiles = import_raw(allMeegFiles{iFile}, FileFormat, iSubject, ImportOptions, DateOfStudy);
                RawFiles = [RawFiles{:}, newFiles];
                % Add electrodes positions if available
                if ~isempty(allMeegElecFiles{iFile}) && ~isempty(allMeegElecFormats{iFile})
                    % Is is subject or MNI coordinates
                    isVox2ras = ~isempty(strfind(allMeegElecFormats{iFile}, '-ORIG-'));
                    % Import 
                    bst_process('CallProcess', 'process_channel_addloc', newFiles, [], ...
                        'channelfile', {allMeegElecFiles{iFile}, allMeegElecFormats{iFile}}, ...
                        'usedefault',  1, ...
                        'fixunits',    0, ...
                        'vox2ras',     isVox2ras);
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
                        'evtfile', {EventsFile, 'BIDS'});
                end
                
                % Load _channels.tsv
                ChannelsFile = [baseName, '_channels.tsv'];
                if file_exist(ChannelsFile)
                    % Read tsv file
                    ChanInfo = in_tsv(ChannelsFile, {'name', 'type', 'group', 'status'});
                    % Try to add info to the existing Brainstorm channel file
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
                                    continue;
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
                                    end
                                    ChannelMat.Channel(iChanBst).Type = chanType;
                                    isModifiedChan = 1;
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
            end
        end
    end
end


%% ===== FIND SUBJECT ANATOMY =====
function [AnatDir, AnatFormat] = GetSubjectSeg(BidsDir, subjName)
    % Inialize returned structures
    AnatDir    = [];
    AnatFormat = [];
    DerivDir = bst_fullfile(BidsDir, 'derivatives');
    % FreeSurfer
    if file_exist(bst_fullfile(DerivDir, 'freesurfer', subjName)) && ~isempty(file_find(bst_fullfile(DerivDir, 'freesurfer', subjName), 'T1.mgz'))
        TestFile = file_find(bst_fullfile(DerivDir, 'freesurfer', subjName), 'T1.mgz');
        if ~isempty(TestFile)
            AnatDir = bst_fileparts(bst_fileparts(TestFile));
            AnatFormat = 'FreeSurfer';
        end
    % BrainSuite
    elseif file_exist(bst_fullfile(DerivDir, 'brainsuite', subjName)) && ~isempty(file_find(bst_fullfile(DerivDir, 'brainsuite', subjName), '*.left.pial.cortex.svreg.dfs'))
        TestFile = file_find(bst_fullfile(DerivDir, 'brainsuite', subjName), '*.left.pial.cortex.svreg.dfs');
        if ~isempty(TestFile)
            AnatDir = bst_fileparts(TestFile);
            AnatFormat = 'BrainSuite';
        end
    % BrainVISA
    elseif file_exist(bst_fullfile(DerivDir, 'brainvisa', subjName)) && ~isempty(file_find(bst_fullfile(DerivDir, 'brainvisa', subjName), 'nobias_*.*'))
        TestFile = file_find(bst_fullfile(DerivDir, 'brainvisa', subjName), 'nobias_*.*');
        if ~isempty(TestFile)
            AnatDir = bst_fileparts(bst_fileparts(bst_fileparts(bst_fileparts(TestFile))));
            AnatFormat = 'BrainVISA';
        end
    % CIVET
    elseif file_exist(bst_fullfile(DerivDir, 'civet', subjName)) && ~isempty(file_find(bst_fullfile(DerivDir, 'civet', subjName), '*_t1.mnc'))
        TestFile = file_find(bst_fullfile(DerivDir, 'civet', subjName), '*_t1.mnc');
        if ~isempty(TestFile)
            AnatDir = bst_fileparts(bst_fileparts(TestFile));
            AnatFormat = 'CIVET';
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
function [fileList, fileSpace] = SelectCoordSystem(fileList)
    % Orig subject space
    iSel = find(~cellfun(@(c)isempty(strfind(lower(c),'-orig')), {fileList.name}) | ...
                ~cellfun(@(c)isempty(strfind(lower(c),'-head')), {fileList.name}) | ...
                ~cellfun(@(c)isempty(strfind(lower(c),'-subject')), {fileList.name}) | ...
                ~cellfun(@(c)isempty(strfind(lower(c),'-scanner')), {fileList.name}) | ...
                ~cellfun(@(c)isempty(strfind(lower(c),'-sform')), {fileList.name}) | ...
                ~cellfun(@(c)isempty(strfind(lower(c),'-other')), {fileList.name}));
    if ~isempty(iSel)
        fileList = fileList(iSel);
        fileSpace = 'orig';
        return;
    end
    % MNI
    iSel = find(~cellfun(@(c)isempty(strfind(lower(c),'-mni')), {fileList.name}));
    if ~isempty(iSel)
        fileList = fileList(iSel);
        fileSpace = 'mni';
        return;
    end
    % Nothing interpretable found: Use first in the list
    disp(['BIDS> Warning: Could not detect subject coordinate system, using randomly "' fileList(1).name '".']);
    fileList = fileList(1);
    fileSpace = 'unknown';
end


