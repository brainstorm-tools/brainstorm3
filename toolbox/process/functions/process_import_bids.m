function varargout = process_import_bids( varargin )
% PROCESS_IMPORT_BIDS: Import a dataset organized following the BIDS specficiations (http://bids.neuroimaging.io/)
%
% USAGE:           OutputFiles = process_import_bids('Run', sProcess, sInputs)
%         [RawFiles, Messages] = process_import_bids('ImportBidsDataset', BidsDir=[ask], nVertices=[ask], isInteractive=1, ChannelAlign=0)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2016-2018; Martin Cousineau, 2018

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
    nVertices = sProcess.options.nvertices.Value{1};
    if isempty(nVertices) || (nVertices < 50)
        bst_report('Error', sProcess, [], 'Invalid number of vertices.');
        return
    end
    % Channels align
    ChannelAlign = 2 * double(sProcess.options.channelalign.Value);
    % Subject selection
    SelectedSubjects = strtrim(str_split(sProcess.options.selectsubj.Value, ','));
    
    % === IMPORT DATASET ===
    % Import dataset
    [OutputFiles, Messages] = ImportBidsDataset(selectedFolders, nVertices, 0, ChannelAlign, SelectedSubjects);
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
% USAGE:  [RawFiles, Messages] = process_import_bids('ImportBidsDataset', BidsDir=[ask], nVertices=[ask], isInteractive=1, ChannelAlign=2, SelectedSubjects=[])
function [RawFiles, Messages] = ImportBidsDataset(BidsDir, nVertices, isInteractive, ChannelAlign, SelectedSubjects)
    % Initialize returned values
    RawFiles = {};
    Messages = [];
    
    % ===== PARSE INPUTS =====
    if (nargin < 5) || isempty(SelectedSubjects)
        SelectedSubjects = [];
    end
    if (nargin < 4) || isempty(ChannelAlign)
        ChannelAlign = 0;
    end
    if (nargin < 3) || isempty(isInteractive)
        isInteractive = 1;
    end
    if (nargin < 2) || isempty(nVertices)
        nVertices = [];
    end
    if (nargin < 3) || isempty(BidsDir)
        BidsDir = [];
    end

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
        if isInteractive
            bst_error(errorMessage, 'Import BIDS dataset', 0);
        end
        return;
    end
    SelectedSubjects = unique([SelectedSubjects, selSubjects]);
    
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
    SubjectTag = {};
    SubjectName = {};
    SubjectAnatDir = {};
    SubjectAnatFormat = {};
    SubjectSessDir = {};
    SubjectMriFiles = {};
    for iSubj = 1:length(subjDir)
        % Default subject name
        subjName = subjDir(iSubj).name;
        % Check if this is a subject selected for import
        if ~isempty(SelectedSubjects) && ((iscell(SelectedSubjects) && ~ismember(subjName, SelectedSubjects)) || (ischar(SelectedSubjects) && ~strcmpi(subjName, SelectedSubjects)))
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
        % If a single anatomy folder is found
        if ~isempty(AnatDir)
            SubjectTag{end+1}        = subjName;
            SubjectName{end+1}       = subjName;
            SubjectAnatDir{end+1}    = AnatDir;
            SubjectAnatFormat{end+1} = AnatFormat;
            SubjectSessDir{end+1}    = cat(2, sessFolders, derivFolders);
            SubjectMriFiles{end+1}   = {};
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
                    SubjectTag{end+1}        = subjName;
                    SubjectName{end+1}       = [subjName, '_', sessDir(isess).name];
                    SubjectAnatDir{end+1}    = sessAnatDir;
                    SubjectAnatFormat{end+1} = sessAnatFormat;
                    SubjectSessDir{end+1}    = {sessFolders{isess}, derivFolders{isess}};
                    SubjectMriFiles{end+1}   = {};
                end
            % There are no segmentations, check if there is one T1 volume per sesssion or per subject
            else
                % Check for multiple session anat
                isSessSeg = 1;
                allMriFiles = {};
                for isess = 1:length(sessFolders)
                    sessMriFiles = GetSubjectMri(bst_fullfile(sessFolders{isess}, 'anat'));
                    if isempty(sessMriFiles)
                        isSessSeg = 0;
                    else
                        allMriFiles = cat(2, allMriFiles, sessMriFiles);
                    end
                end
                % If there is one anatomy per session
                if isSessSeg
                    for isess = 1:length(sessFolders)
                        sessMriFiles = GetSubjectMri(bst_fullfile(sessFolders{isess}, 'anat'));
                        SubjectTag{end+1}        = subjName;
                        SubjectName{end+1}       = [subjName, '_', sessDir(isess).name];
                        SubjectAnatDir{end+1}    = [];
                        SubjectAnatFormat{end+1} = [];
                        SubjectSessDir{end+1}    = {sessFolders{isess}, derivFolders{isess}};
                        SubjectMriFiles{end+1}   = sessMriFiles;
                    end
                % One common anatomy for all the sessions
                else
                    SubjectTag{end+1}        = subjName;
                    SubjectName{end+1}       = subjName;
                    SubjectAnatDir{end+1}    = [];
                    SubjectAnatFormat{end+1} = [];
                    SubjectSessDir{end+1}    = cat(2, sessFolders, derivFolders);
                    SubjectMriFiles{end+1}   = allMriFiles;
                end
            end
        % One session
        elseif (length(sessFolders) == 1)
            SubjectTag{end+1}        = subjName;
            SubjectName{end+1}       = subjName;
            SubjectAnatDir{end+1}    = [];
            SubjectAnatFormat{end+1} = [];
            SubjectSessDir{end+1}    = cat(2, sessFolders, derivFolders);
            SubjectMriFiles{end+1}   = GetSubjectMri(bst_fullfile(sessFolders{1}, 'anat'));
        end
    end
    
%     % Perform some checks
%     % Cannot set the fiducials when calling from a process (non-interactive)
%     if ~isInteractive && any(isSetFiducials)
%         Messages = ['You need to set the fiducials interactively before running this process.' 10 ...
%                     'Use the menu "File > Batch MRI fiducials" for creating fiducials.m files in the segmentation folders.' 10 ...
%                     'Alternatively, run this import interactively with the menu "File > Load protocol > Import BIDS dataset"'];
%         return;
%     % Ask the user whether to set all the fiducials at once
%     elseif isInteractive && any(isSetFiducials & isSegmentation)
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
            if isInteractive
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
        if ~isempty(sSubject.Anatomy)
            msgAnatSet = ['Anatomy is already set for subject "' SubjectName{iSubj} '", not overwriting...'];
            Messages = [Messages, 10, msgAnatSet];
            disp(['BST> ' msgAnatSet]);
        % Import segmentation
        elseif ~isempty(SubjectAnatDir{iSubj})
            % Ask for number of vertices (so it is not asked multiple times)
            if isempty(nVertices)
                nVertices = java_dialog('input', 'Number of vertices on the cortex surface:', 'Import FreeSurfer folder', [], '15000');
                if isempty(nVertices)
                    return;
                end
                nVertices = str2double(nVertices);
            end
            % Import subject anatomy
            switch (SubjectAnatFormat{iSubj})
                case 'FreeSurfer'
                    errorMsg = import_anatomy_fs(iSubject, SubjectAnatDir{iSubj}, nVertices, isInteractiveAnat, [], 0);
                case 'BrainSuite'
                    errorMsg = import_anatomy_bs(iSubject, SubjectAnatDir{iSubj}, nVertices, isInteractiveAnat, []);
                case 'BrainVISA'
                    errorMsg = import_anatomy_bv(iSubject, SubjectAnatDir{iSubj}, nVertices, isInteractiveAnat, []);
                case 'CIVET'
                    errorMsg = import_anatomy_civet(iSubject, SubjectAnatDir{iSubj}, nVertices, isInteractiveAnat, [], 0);
                otherwise
                    errorMsg = ['Invalid file format: ' SubjectAnatFormat{iSubj}];
            end
        % Import MRI
        elseif ~isempty(SubjectMriFiles{iSubj})
            % Import first MRI
            BstMriFile = import_mri(iSubject, SubjectMriFiles{iSubj}{1}, 'ALL', isInteractiveAnat, 0);
            if isempty(BstMriFile)
                errorMsg = ['Could not load MRI file: ' SubjectMriFiles{iSubj}];
            % Compute additional files
            else
                % Compute MNI transformation
                [sMri, errorMsg] = bst_normalize_mni(BstMriFile);
                % Generate head surface
                tess_isohead(iSubject, 10000, 0, 2);
                % Add other volumes
                for i = 2:length(SubjectMriFiles{iSubj})
                    import_mri(iSubject, SubjectMriFiles{iSubj}{i}, 'ALL', 0, 1);
                end
            end
        end
        % Error handling
        if ~isempty(errorMsg)
            Messages = [Messages, 10, errorMsg];
            if isInteractive
                bst_error(Messages, 'Import BIDS dataset', 0);
                return;
            else
                continue;
            end
        end
            
        % === IMPORT MEG FILES ===
        % Import options
        ImportOptions = db_template('ImportOptions');
        ImportOptions.ChannelReplace  = 1;
        ImportOptions.ChannelAlign    = 2 * (ChannelAlign >= 1) * ~sSubject.UseDefaultAnat;
        ImportOptions.DisplayMessages = isInteractive;
        ImportOptions.EventsMode      = 'ignore';
        ImportOptions.EventsTrackMode = 'value';
        % Get all the files in the meg folder
        allMegFiles = {};
        allMegDates = {};
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
                    % Open file
                    fid = fopen(fullfile(SubjectSessDir{iSubj}{isess}, tsvDir(1).name), 'r');
                    if (fid < 0)
                        disp(['BIDS> Warning: Cannot open file: ' tsvDir(1).name]);
                        continue;
                    end
                    % Read header
                    tsvHeader = str_split(fgetl(fid), sprintf('\t'));
                    tsvFormat = repmat('%s ', 1, length(tsvHeader));
                    tsvFormat(end) = [];
                    % Read file
                    tsvValues = textscan(fid, tsvFormat, 'Delimiter', '\t');
                    % Close file
                    fclose(fid);
                    % Get the columns "filename" and "acq_time"
                    iColFile = find(strcmpi(tsvHeader, 'filename'));
                    iColTime = find(strcmpi(tsvHeader, 'acq_time'));
                    if ~isempty(iColFile) && ~isempty(iColTime)
                        tsvFiles = tsvValues{iColFile};
                        for iDate = 1:length(tsvValues{iColTime})
                            fDate = [];
                            % Date format: YYYY-MM-DDTHH:MM:SS
                            if (length(tsvValues{iColTime}{iDate}) >= 19) && strcmpi(tsvValues{iColTime}{iDate}(11), 'T')
                                fDate = sscanf(tsvValues{iColTime}{iDate}, '%04d-%02d-%02d');
                            % Date format: YYYYMMDDTHHMMSS
                            elseif (length(tsvValues{iColTime}{iDate}) >= 15) && strcmpi(tsvValues{iColTime}{iDate}(9), 'T')
                                fDate = sscanf(tsvValues{iColTime}{iDate}, '%04d%02d%02d');
                            end
                            % Not recognized
                            if (length(fDate) ~= 3)
                                disp(['BIDS> Warning: Date format not recognized: "' tsvValues{iColTime}{iDate} '"']);
                                fDate = [0 0 0];
                            end
                            tsvDates{iDate} = datestr(datenum(fDate(1), fDate(2), fDate(3)), 'dd-mmm-yyyy');
                        end
                    end
                end
                % Read the contents of the 'meg' folder
                megDir = dir(bst_fullfile(SubjectSessDir{iSubj}{isess}, 'meg', '*.*'));
                for iFile = 1:length(megDir)
                    % Skip hidden files
                    if (megDir(iFile).name(1) == '.')
                        continue;
                    end
                    % Get full file name
                    allMegFiles{end+1} = bst_fullfile(SubjectSessDir{iSubj}{isess}, 'meg', megDir(iFile).name);
                    % Try to get the recordings date from the tsv file
                    if ~isempty(tsvFiles)
                        iFileTsv = find(strcmp(['meg', '/', megDir(iFile).name], tsvFiles));
                        if ~isempty(iFileTsv)
                            allMegDates{length(allMegFiles)} = tsvDates{iFileTsv};
                        end
                    end
                end
            end
        end
        % Try import them all, one by one
        for iFile = 1:length(allMegFiles)
            % Acquisition date
            if (length(allMegDates) >= iFile) && ~isempty(allMegDates{iFile})
                DateOfStudy = allMegDates{iFile};
            else
                DateOfStudy = [];
            end
            % Get file extension
            [tmp, fBase, fExt] = bst_fileparts(allMegFiles{iFile});
            % Import depending on this extension
            switch (fExt)
                case '.ds'
                    RawFiles = [RawFiles{:}, import_raw(allMegFiles{iFile}, 'CTF', iSubject, ImportOptions, DateOfStudy)];
                case '.fif'
                    RawFiles = [RawFiles{:}, import_raw(allMegFiles{iFile}, 'FIF', iSubject, ImportOptions, DateOfStudy)];
                case {'.json', '.tsv'}
                    % Nothing to do
                otherwise
                    % disp(['BST> Skipping unsupported file: ' megFile]);
            end
        end
    end
end


% ===== FIND SUBJECT ANATOMY =====
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
end

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
