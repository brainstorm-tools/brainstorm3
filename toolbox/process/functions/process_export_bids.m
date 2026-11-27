function varargout = process_export_bids( varargin )
% PROCESS_EXPORT_BIDS: Exports selected raw files in BIDS format.

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
% Authors: Martin Cousineau, 2018-2019
%          Francois Tadel, 2023

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() 
    % Description the processc
    sProcess.Comment     = 'Export BIDS dataset [experimental]';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 982;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/ExportBids';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % File selection options
    SelectOptions = {...
        '', ...                            % Filename
        '', ...                            % FileFormat
        'open', ...                        % Dialog type: {open,save}
        'Select BIDS dataset output folder...', ...     % Window title
        'ExportData', ...                  % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                    % Selection mode: {single,multiple}
        'dirs', ...                        % Selection mode: {files,dirs,files_and_dirs}
        {{'.folder'}, 'BIDS dataset folder', 'BIDS'}, ... % Available file formats
        []};                               % DefaultFormats: {ChannelIn,DataIn,DipolesIn,EventsIn,AnatIn,MriIn,NoiseCovIn,ResultsIn,SspIn,SurfaceIn,TimefreqIn}
    % Output folder
    sProcess.options.bidsdir.Comment = 'Output folder:';
    sProcess.options.bidsdir.Type    = 'filename';
    sProcess.options.bidsdir.Value   = SelectOptions;
    % Identify naming schemes
    sProcess.options.subscheme.Comment = {'Custom names', 'Number index', 'Subject names (sub-XXXX): '};
    sProcess.options.subscheme.Type    = 'radio_line';
    sProcess.options.subscheme.Value   = 2;
    sProcess.options.sesscheme.Comment = {'Acquisition date', 'Number index', 'Custom names', 'Session names (ses-XXXX): '};
    sProcess.options.sesscheme.Type    = 'radio_line';
    sProcess.options.sesscheme.Value   = 1;
    % Identifying empty room
    sProcess.options.emptyroom.Comment = 'Keywords to detect empty room recordings: ';
    sProcess.options.emptyroom.Type    = 'text';
    sProcess.options.emptyroom.Value   = 'emptyroom, noise';
    % Replace existing files
    sProcess.options.defacemri.Comment = 'Deface MRI before export?';
    sProcess.options.defacemri.Type    = 'checkbox';
    sProcess.options.defacemri.Value   = 0;
    % Replace existing files
    sProcess.options.overwrite.Comment = 'Overwrite existing files?';
    sProcess.options.overwrite.Type    = 'checkbox';
    sProcess.options.overwrite.Value   = 0;
    
    % Options: BIDS metadata (project, dataset description, MEG/EEG/NIRS sidecars).
    % If the output folder already contains a BIDS dataset, its metadata is loaded in the panel.
    sProcess.options.edit.Comment = {'panel_export_bids', ' BIDS metadata (authors, license, modality-specific fields): '};
    sProcess.options.edit.Type    = 'editpref';
    sProcess.options.edit.Value   = [];
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) 
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function sInputs = Run(sProcess, sInputs) 
    %% ===== PARSE OPTIONS =====
    outputFolder  = sProcess.options.bidsdir.Value{1};
    defaceMri     = sProcess.options.defacemri.Value;
    overwrite     = sProcess.options.overwrite.Value;
    emptyRoomKeywords = strtrim(str_split(lower(sProcess.options.emptyroom.Value), ',;'));
    if isempty(outputFolder)
        bst_report('Error', sProcess, sInputs, 'No output folder specified.');
        return;
    end
    
    % Metadata: from the panel, or from the existing dataset if the panel was not validated for this folder
    OPTIONS = LoadMetadataOptions(sProcess, outputFolder);
    if isempty(strtrim(OPTIONS.Authors))
        bst_report('Error', sProcess, sInputs, 'List of authors cannot be empty. Click "Edit..." to fill in the BIDS metadata.');
        return;
    end
    if any(OPTIONS.PowerLine == [50, 60])
        powerline = OPTIONS.PowerLine;
    else
        powerline = 'n/a';
    end
    % Additional JSON fields: dataset description + one sidecar per modality
    jsonList = {'JsonDataset', 'dataset description'; 'JsonMeg', 'MEG sidecar'; 'JsonEeg', 'EEG sidecar'; 'JsonNirs', 'NIRS sidecar'};
    jsonStructs = cell(1, size(jsonList, 1));
    for iJson = 1:size(jsonList, 1)
        jsonStructs{iJson} = struct();
        if ~isempty(OPTIONS.(jsonList{iJson,1}))
            try
                jsonStructs{iJson} = bst_jsondecode(OPTIONS.(jsonList{iJson,1}));
            catch e
                bst_report('Error', sProcess, sInputs, ['Invalid ' jsonList{iJson,2} ' metadata: ' e.message]);
                return;
            end
        end
    end
    [datasetMetadata, megMetadata, eegMetadata, nirsMetadata] = deal(jsonStructs{:});
    % Settings shared by all the exported files
    settings = struct('Overwrite',    overwrite, ...
                      'PowerLine',    powerline, ...
                      'Options',      OPTIONS, ...
                      'SidecarExtra', struct('meg', megMetadata, 'eeg', eegMetadata, 'nirs', nirsMetadata));
    naming = GetNamingSchemes(sProcess);
    
    %% ===== OUTPUT FOLDER =====
    % Create it, or load the subject/session mapping of a previous export
    [data, naming.LastSub, errMsg] = PrepareOutputFolder(outputFolder, naming);
    if ~isempty(errMsg)
        bst_report('Error', sProcess, sInputs, errMsg);
        return;
    end
    
    %% ===== SORT INPUTS, DEFACE =====
    bst_progress('start', 'Export', 'Sorting input files...');
    [sInputs, mrisToDeface] = SortInputs(sInputs, defaceMri);
    if defaceMri && ~isempty(mrisToDeface)
        defaceResult = process_mri_deface('Compute', mrisToDeface, struct('isDefaceHead', 0));
        if isempty(defaceResult)
            defaceMri = 0;
        end
    end
    
    %% ===== PLAN: INPUTS => SUBJECT / SESSION / RUN / MODALITY =====
    % Assign all the BIDS identifiers before writing anything
    bst_progress('text', 'Identifying subjects, sessions and runs...');
    [plan, data, errMsg] = BuildExportPlan(sInputs, data, outputFolder, naming, emptyRoomKeywords);
    if ~isempty(errMsg)
        bst_report('Error', sProcess, sInputs, errMsg);
        return;
    end
    
    %% ===== EXPORT =====
    CreateDatasetDescription(outputFolder, overwrite, datasetMetadata, OPTIONS, 'raw');
    
    Summary = struct('StimChannelNames', {{}}, 'EventNames', {{}});
    bst_progress('start', 'Export', 'Exporting dataset files...', 0, plan.nRuns);
    
    for iSubject = 1:length(plan.Subjects)
        sub = plan.Subjects{iSubject};
        subjectFolder = bst_fullfile(outputFolder, sub.Label);
        EnsureDir(subjectFolder);
        
        for iSession = 1:length(sub.Sessions)
            ses = sub.Sessions{iSession};
            sessionFolder = bst_fullfile(subjectFolder, ses.Label);
            EnsureDir(sessionFolder);
            
            % Export anatomy (once per subject, in the first session)
            if ~sub.IsEmptyRoom && SameIds(ses.Id, GetFirstSessionId(data, sub.Id))
                ExportAnatomy(sub.sSubject, sessionFolder, ses.Prefix, defaceMri, overwrite);
            end
            
            for iRun = 1:length(ses.Runs)
                sRun = ses.Runs{iRun};
                ChannelMat = in_bst_channel(sRun.sInput.ChannelFile);
                Summary = UpdateSummary(Summary, ChannelMat, sRun.sFile);
                
                for iMod = 1:length(sRun.Modalities)
                    modality = sRun.Modalities{iMod};
                    bids = GetBidsPaths(sessionFolder, ses.Prefix, sRun, modality);
                    
                    % Export the recording {subject, session, run, modality}
                    switch modality
                        case 'meg'
                            ExportMeg(sRun, ChannelMat, bids, settings);
                        case 'eeg'
                            ExportEeg(sRun, ChannelMat, bids, settings);
                        case 'nirs'
                            ExportNirs(sRun, ChannelMat, bids, settings);
                    end
                end
                bst_progress('inc', 1);
            end
        end
    end
    
    %% ===== DATASET-LEVEL FILES =====
    CreateDatasetReadme(outputFolder, overwrite, OPTIONS, plan.FirstAcq, plan.LastAcq, Summary.StimChannelNames, Summary.EventNames);
    % Save condition to subject/session mapping for future exports.
    SaveExistingData(data, outputFolder);
end


%% ===== NAMING SCHEMES =====
% Subjects:  -1 = custom names, 4 = zero-padded index
% Sessions:  -2 = acquisition date, -1 = custom names, 4 = zero-padded index
% Runs:       2 = zero-padded index
function naming = GetNamingSchemes(sProcess)
    naming = struct('SubScheme', -1, 'SesScheme', -2, 'RunScheme', 2, 'LastSub', 0);
    if isfield(sProcess.options, 'subscheme') && ~isempty(sProcess.options.subscheme.Value)
        if sProcess.options.subscheme.Value == 1
            naming.SubScheme = -1;
        else
            naming.SubScheme = 4;
        end
    end
    if isfield(sProcess.options, 'sesscheme') && ~isempty(sProcess.options.sesscheme.Value)
        if sProcess.options.sesscheme.Value == 1
            naming.SesScheme = -2;
        elseif sProcess.options.sesscheme.Value == 3
            naming.SesScheme = -1;
        else
            naming.SesScheme = 4;
        end
    end
end

% Create the output folder, or load the mapping of an existing one.
% iLastSub: last numbered subject in the folder (for numbered subject names).
function [data, iLastSub, errMsg] = PrepareOutputFolder(outputFolder, naming)
    iLastSub = 0;
    errMsg = '';
    data = EmptyData();
    % New folder
    if exist(outputFolder, 'dir') ~= 7
        [success, mkdirMsg] = mkdir(outputFolder);
        if ~success
            errMsg = ['Could not create output folder:' 10 mkdirMsg];
        end
        return;
    end
    % Existing folder: detect the naming scheme
    [prevSubScheme, prevSesScheme, prevRunScheme] = DetectNamingScheme(outputFolder);
    if isempty(prevSubScheme) || isempty(prevSesScheme) || isempty(prevRunScheme)
        data = EmptyData();
    % Warn user for different naming schemes
    elseif naming.SubScheme ~= prevSubScheme || naming.SesScheme ~= prevSesScheme || naming.RunScheme ~= prevRunScheme
        disp(['Warning: Chosen naming scheme(s) different from existing one.' ...
            10 '         Ignoring existing subjects/sessions in output folder.']);
        data = EmptyData();
    else
        data = LoadExistingData(outputFolder);
    end
    % If numbered subject IDs, extract last subject ID
    if naming.SubScheme >= 0
        iLastSub = GetLastId(outputFolder, 'sub');
    end
end


%% =================================================================================
%  === EXPORT PLAN =================================================================
%  =================================================================================
% Group the (sorted) inputs in a tree, and assign the BIDS identifiers:
%
%   plan.Subjects{i}                BIDS subject (sub-emptyroom is a subject like any other)
%       .Id, .Label, .sSubject, .IsEmptyRoom
%       .Sessions{j}                BIDS session
%           .Id, .Label, .Prefix    (Prefix = 'sub-XX_ses-YY')
%           .Runs{k}                One input file
%               .sInput, .sFile, .DataMat, .DateOfStudy
%               .RunId, .TaskName, .Entities (e.g. '_acq-sub0001_run-01')
%               .Modalities         {'meg'}, {'eeg'} or {'nirs'}
%
% data = subject/session mapping saved in derivatives/bst_db_mapping.mat
function [plan, data, errMsg] = BuildExportPlan(sInputs, data, outputFolder, naming, emptyRoomKeywords)
    plan = struct('Subjects', {{}}, 'nRuns', 0, 'FirstAcq', [], 'LastAcq', []);
    errMsg = '';
    
    for iInput = 1:length(sInputs)
        info = GetInputInfo(sInputs(iInput));
        if isempty(info)
            continue;
        end
        % Acquisition period of the dataset
        if isempty(plan.FirstAcq) || info.DateOfStudy < plan.FirstAcq
            plan.FirstAcq = info.DateOfStudy;
        end
        if isempty(plan.LastAcq) || info.DateOfStudy > plan.LastAcq
            plan.LastAcq = info.DateOfStudy;
        end
        
        %% Subject
        [data, subjectId, naming, errMsg] = ResolveSubject(data, info.sSubject, naming);
        if ~isempty(errMsg)
            return;
        end
        isEmptyRoom = strcmp(info.sSubject.Name, 'sub-emptyroom') || ...
                      (~isempty(emptyRoomKeywords) && containsKeyword(lower(info.SessionName), emptyRoomKeywords));
        if isEmptyRoom
            % Empty room recordings are stored in sub-emptyroom, with the real subject in the "acq" entity
            bidsSubjectId = 'emptyroom';
        else
            bidsSubjectId = subjectId;
        end
        iSub = FindNodeById(plan.Subjects, bidsSubjectId);
        if isempty(iSub)
            subLabel = FormatId(bidsSubjectId, naming.SubScheme, 'sub');
            % Last numbered session already in the subject folder
            lastSesNum = 0;
            if ~isEmptyRoom && naming.SesScheme >= 0
                lastSesNum = GetLastId(bst_fullfile(outputFolder, subLabel), 'ses');
            end
            if isEmptyRoom
                sSubjectAnat = [];
            else
                sSubjectAnat = info.sSubject;
            end
            plan.Subjects{end + 1} = struct('Id', bidsSubjectId, 'Label', subLabel, 'sSubject', sSubjectAnat, ...
                'IsEmptyRoom', isEmptyRoom, 'LastSesNum', lastSesNum, 'Sessions', {{}});
            iSub = length(plan.Subjects);
        end
        sub = plan.Subjects{iSub};
        
        %% Session and run index
        if isEmptyRoom
            [data, sessionId, runId] = ResolveEmptyRoomSession(data, subjectId, info);
        else
            [data, sessionId, runId, sub.LastSesNum, errMsg] = ResolveSession(data, subjectId, info, naming.SesScheme, sub.LastSesNum);
            if ~isempty(errMsg)
                return;
            end
        end
        iSes = FindNodeById(sub.Sessions, sessionId);
        if isempty(iSes)
            sesLabel = FormatId(sessionId, naming.SesScheme, 'ses');
            sub.Sessions{end + 1} = struct('Id', sessionId, 'Label', sesLabel, ...
                'Prefix', [sub.Label '_' sesLabel], 'Runs', {{}});
            iSes = length(sub.Sessions);
        end
        ses = sub.Sessions{iSes};
        
        %% Run
        entities = '';
        if isEmptyRoom && ~isempty(subjectId)
            entities = ['_acq-sub' FormatId(subjectId, naming.SubScheme)];
        end
        if ~isempty(runId) && ~isempty(FormatId(runId, naming.RunScheme))
            entities = [entities '_run-' FormatId(runId, naming.RunScheme)];
        end
        sRun = struct('sInput',      sInputs(iInput), ...
                      'sFile',       info.sFile, ...
                      'DataMat',     info.DataMat, ...
                      'Modalities',  {info.Modalities}, ...
                      'DateOfStudy', info.DateOfStudy, ...
                      'RunId',       runId, ...
                      'TaskName',    GetTaskName(info.sFile, [ses.Prefix '_task-'], isEmptyRoom), ...
                      'Entities',    entities);
        
        ses.Runs{end + 1} = sRun;
        sub.Sessions{iSes} = ses;
        plan.Subjects{iSub} = sub;
        plan.nRuns = plan.nRuns + 1;
    end
end

% Extract everything needed from an input. Returns [] if the file cannot be exported.
function info = GetInputInfo(sInput)
    info = [];
    sStudy   = bst_get('Study', sInput.iStudy);
    sSubject = bst_get('Subject', sStudy.BrainStormSubject);
    DataMat  = in_bst_data(sInput.FileName);
    sFile    = DataMat.F;
    
    % Skip unsupported formats
    modalities = GetModalities(sFile, sInput.ChannelTypes);
    if isempty(modalities)
        disp(['Skipping file "' sFile.filename '" due to unsupported format...']);
        return;
    end
    % If BST/CTF binary file, find original raw file
    if strcmpi(sFile.format, 'BST-BIN') && strcmpi(sFile.device, 'CTF')
        origFile = ExtractOriginalBstFilename(DataMat);
        if isempty(origFile)
            disp(['Skipping file "' sFile.comment '" due to raw link no longer existing...']);
            return;
        end
        disp(['Warning: File "', sFile.comment, '" already imported in binary format.', ...
            10, '         Using raw link "', origFile, '" instead.']);
        sFile.filename = origFile;
    end
    % Session name: name of the Brainstorm study
    if strncmp(sStudy.Name, '@raw', 4)
        sessionName = sStudy.Name(5:end);
    else
        sessionName = sStudy.Name;
    end
    
    info = struct('sSubject',    sSubject, ...
                  'DataMat',     DataMat, ...
                  'sFile',       sFile, ...
                  'Modalities',  {modalities}, ...
                  'SessionName', sessionName, ...
                  'DateOfStudy', ExtractAcquisitionTime(sFile, sInput.iStudy));
end

% Modalities recorded in a file. Currently one per file, with priority MEG > EEG > NIRS.
% Returns {} if not supported. (Simultaneous recordings could return several here.)
function modalities = GetModalities(sFile, channelTypes)
    isMeg  = strcmpi(sFile.device, 'CTF') || strcmpi(sFile.device, 'Neuromag');
    isEeg  = strncmpi(sFile.format, 'EEG-', 4) || ismember('EEG', channelTypes);
    isNirs = ismember('NIRS', channelTypes);
    if isMeg
        modalities = {'meg'};
    elseif isEeg
        modalities = {'eeg'};
    elseif isNirs
        modalities = {'nirs'};
    else
        modalities = {};
    end
end

% Find the BIDS subject for a Brainstorm subject, create it in the mapping if new
function [data, subjectId, naming, errMsg] = ResolveSubject(data, sSubject, naming)
    errMsg = '';
    % Already exported
    subjectId = GetSubjectId(data, sSubject.Name);
    if ~isempty(subjectId)
        return;
    end
    % Subject names formatted as "sub-<n>"
    if strncmp(sSubject.Name, 'sub-', 4) && length(sSubject.Name) > 5
        if naming.SubScheme == -1
            subjectId = sSubject.Name(5:end);
            data = AddSubject(data, sSubject.Name, subjectId);
            return;
        else
            disp('Warning: BIDS-formatted subject name detected, but numbered index subject names selected. A new index will be assigned. Select custom names to avoid this.');
        end
    end
    % New subject
    if naming.SubScheme == -1
        % Char-based naming scheme
        subjectId = FormatId(sSubject.Name, naming.SubScheme);
    else
        % Number-based naming scheme, increment from previous
        subjectId = naming.LastSub + 1;
        maxSubjects = power(10, naming.SubScheme);
        if naming.SubScheme > 1 && subjectId >= maxSubjects
            errMsg = ['Exceeded maximum number of subjects supported by your naming scheme (' num2str(maxSubjects) ').'];
            return;
        end
        naming.LastSub = subjectId;
    end
    data = AddSubject(data, sSubject.Name, subjectId);
end

% Find the BIDS session and run index for a Brainstorm study, create them in the mapping if new
function [data, sessionId, runId, lastSesNum, errMsg] = ResolveSession(data, subjectId, info, sesScheme, lastSesNum)
    errMsg = '';
    sessionName = info.SessionName;

    % Session names formatted as "<subject>_ses-<id>_..."
    subLen = length(info.sSubject.Name);
    if length(sessionName) > (subLen + 6) && strncmp(sessionName(subLen+6:end), 'ses-', 4)  
        tokens = regexp(sessionName, '_ses-(\w+)_', 'tokens', 'once');
        if ~isempty(tokens)
            sessionName = tokens{1};
        end
    end

    % Already exported
    [sessionId, runId] = GetSessionId(data, subjectId, sessionName);
    if ~isempty(sessionId)
        return;
    end

    % New session
    if sesScheme == -1
        % Char-based naming scheme
        sessionId = FormatId(sessionName, sesScheme);
    elseif sesScheme == -2
        % Date-based naming scheme
        sessionId = datestr(info.DateOfStudy, 'yyyymmdd');
    else
        % Number-based naming scheme, increment from previous
        sessionId = lastSesNum + 1;
        maxSessions = power(10, sesScheme);
        if sesScheme > 1 && sessionId >= maxSessions
            errMsg = ['Exceeded maximum number of sessions supported by your naming scheme (' num2str(maxSessions) ').'];
            return;
        end
        lastSesNum = sessionId;
    end
    [data, runId] = AddSession(data, subjectId, sessionName, sessionId);
end

% Empty room recordings: the session is always the acquisition date.
% The mapping is stored under the real subject (subjectId).
function [data, sessionId, runId] = ResolveEmptyRoomSession(data, subjectId, info)
    [sessionId, runId] = GetSessionId(data, subjectId, info.SessionName);
    if isempty(sessionId)
        sessionId = datestr(info.DateOfStudy, 'yyyymmdd');
        [data, runId] = AddSession(data, subjectId, info.SessionName, sessionId);
    end
end

% Index of the node with a given Id in a cell array of subjects or sessions
function iNode = FindNodeById(nodes, id)
    iNode = [];
    for i = 1:length(nodes)
        if SameIds(nodes{i}.Id, id)
            iNode = i;
            return;
        end
    end
end

function taskName = GetTaskName(sFile, prefixTask, isEmptyRoom)
    if isEmptyRoom
        taskName = 'noise';
        return;
    end
    taskName = [];
    [rawFolder, rawName] = fileparts(sFile.filename); %#ok<ASGLU>
    % File already named following the BIDS convention
    if strncmp(rawName, prefixTask, length(prefixTask))
        rawNameUnprefixed = rawName(length(prefixTask) + 1:end);
        endTask = strfind(rawNameUnprefixed, '_');
        if ~isempty(endTask)
            taskName = rawNameUnprefixed(1:endTask(1) - 1);
        end
    end
    % Find task name from format specific metadata if possible
    if isempty(taskName)
        if strcmpi(sFile.device, 'CTF')
            taskName = ExtractCtfTaskname(sFile);
        elseif strcmpi(sFile.device, 'Neuromag')
            taskName = ExtractFifTaskname(sFile);
        else
            tokens = regexp(rawName, 'task-([a-zA-Z0-9]+)', 'tokens');
            if ~isempty(tokens)
                taskName = tokens{1}{1};
            end
        end
    end
    % Otherwise, extract task name from condition
    if isempty(taskName)
        taskName = regexprep(rawName, '[^a-zA-Z0-9]', '');
    end
end


%% =================================================================================
%  === EXPORT: ONE RECORDING {subject, session, run, modality} =====================
%  =================================================================================
function EnsureDir(folder)
    if exist(folder, 'dir') ~= 7
        mkdir(folder);
    end
end

% Paths and file names of a recording:
%   <session>/<modality>/<prefix>_task-<task><entities>_<modality>.<ext>
function bids = GetBidsPaths(sessionFolder, prefix, sRun, modality)
    bids = struct();
    bids.SessionFolder = sessionFolder;
    bids.DataFolder    = bst_fullfile(sessionFolder, modality);
    bids.Prefix        = prefix;
    bids.BaseName      = [prefix '_task-' sRun.TaskName sRun.Entities];
    bids.NewName       = [bids.BaseName '_' modality];
    EnsureDir(bids.DataFolder);
end

function ExportAnatomy(sSubject, sessionFolder, prefix, defaceMri, overwrite)
    if isempty(sSubject.Anatomy) || isempty(sSubject.Anatomy(1).FileName)
        return;
    end
    anatFolder = bst_fullfile(sessionFolder, 'anat');
    EnsureDir(anatFolder);
    mriFile = bst_fullfile(anatFolder, [prefix '_T1w.nii']);
    if (exist(mriFile, 'file') ~= 2 && exist([mriFile '.gz'], 'file') ~= 2) || overwrite
        if defaceMri
            origMri = GetDefacedMri(sSubject);
        else
            origMri = sSubject.Anatomy(1).FileName;
        end
        export_mri(origMri, mriFile, 'bids');
        mriGzFile = gzip(mriFile);
        if ~isempty(mriGzFile)
            delete(mriFile);
        end
    end
end

% Trigger channels and event names, listed in the README
function Summary = UpdateSummary(Summary, ChannelMat, sFile)
    iStimChans = find(strcmpi('stim', {ChannelMat.Channel.Type}));
    for iStimChan = 1:length(iStimChans)
        chan = ChannelMat.Channel(iStimChans(iStimChan)).Name;
        if ~any(strcmpi(chan, Summary.StimChannelNames))
            Summary.StimChannelNames{end + 1} = chan;
        end
    end
    for iEvent = 1:length(sFile.events)
        event = sFile.events(iEvent).label;
        if ~any(strcmpi(event, Summary.EventNames))
            Summary.EventNames{end + 1} = event;
        end
    end
end

%% ===== MEG =====
function ExportMeg(sRun, ChannelMat, bids, settings)
    sFile = sRun.sFile;
    isCtf = strcmpi(sFile.device, 'CTF');
    [rawFolder, rawName, rawExt] = fileparts(sFile.filename); %#ok<ASGLU>
    if isCtf
        rawExt = '.ds';
    end
    newPath = bst_fullfile(bids.DataFolder, [bids.NewName, rawExt]);
    if exist(newPath, 'file') && ~settings.Overwrite
        return;
    end
    [hasHeadPoints, hasLandmarks] = ExtractHeadPoints(ChannelMat);
    
    % Data files
    if isCtf
        % Rename internal DS files
        dsFolder = fileparts(sFile.filename);
        tempPath = bst_fullfile(bids.DataFolder, [rawName, rawExt]);
        file_copy(dsFolder, tempPath);
        if ~strcmp(tempPath, newPath)
            ctf_rename_ds(tempPath, newPath, []);
        end
        % Save Polhemus file
        if hasHeadPoints
            posFile = bst_fullfile(bids.DataFolder, [bids.Prefix '_headshape.pos']);
            out_channel_pos(sRun.sInput.ChannelFile, posFile);
        end
        % Remove internal Polhemus files
        delete(bst_fullfile(newPath, '*.pos'));
    else
        file_copy(sFile.filename, newPath);
    end
    
    % Sidecar fields
    metadata = GetCommonMetadata(settings.SidecarExtra.meg, sRun, settings);
    metadata = addField(metadata, 'DewarPosition', valueOrNA(settings.Options.DewarPosition));
    metadata = addField(metadata, 'DigitizedLandmarks', bool2str(hasLandmarks));
    metadata = addField(metadata, 'DigitizedHeadPoints', bool2str(hasHeadPoints));
    WriteRecordingFiles(sRun, ChannelMat, 'meg', newPath, metadata, bids);
end

%% ===== EEG =====
function ExportEeg(sRun, ChannelMat, bids, settings)
    sFile = sRun.sFile;
    [rawFolder, rawName, rawExt] = fileparts(sFile.filename);
    isEegBids = ismember(sFile.format, {'EEG-EDF', 'EEG-BRAINAMP', 'EEG-EEGLAB', 'EEG-BDF'});
    if ~isEegBids
        rawExt = '.eeg';
    end
    newPath = bst_fullfile(bids.DataFolder, [bids.NewName, rawExt]);
    if exist(newPath, 'file') && ~settings.Overwrite
        return;
    end
    
    % Data files
    if ~isEegBids
        % For EEG-BIDS, only a handful of formats are supported.
        % Convert unsupported formats to BrainVision.
        disp(['Warning: Format of file "', sFile.comment, '" is not supported by EEG-BIDS. Converting to BrainVision EEG/VHDR.']);
        export_data(sRun.sInput.FileName, [], newPath, 'EEG-BRAINAMP');
    else
        file_copy(sFile.filename, newPath);
        % Copy BrainVision meta-data files (.vhdr, .vmrk)
        if strcmp(sFile.format, 'EEG-BRAINAMP')
            VhdrFile = bst_fullfile(rawFolder, [rawName, '.vhdr']);
            if file_exist(VhdrFile)
                file_copy(VhdrFile, bst_fullfile(bids.DataFolder, [bids.NewName, '.vhdr']));
            end
            VmrkFile = bst_fullfile(rawFolder, [rawName, '.vmrk']);
            if file_exist(VmrkFile)
                file_copy(VmrkFile, bst_fullfile(bids.DataFolder, [bids.NewName, '.vmrk']));
            end
        end
    end
    
    % Sidecar fields
    OPTIONS = settings.Options;
    metadata = GetCommonMetadata(settings.SidecarExtra.eeg, sRun, settings);
    metadata = addField(metadata, 'EEGReference', valueOrNA(OPTIONS.EegReference));
    metadata = addIfNotEmpty(metadata, 'EEGGround', OPTIONS.EegGround);
    metadata = addIfNotEmpty(metadata, 'CapManufacturer', OPTIONS.EegCapManufacturer);
    metadata = addIfNotEmpty(metadata, 'CapManufacturersModelName', OPTIONS.EegCapModel);
    WriteRecordingFiles(sRun, ChannelMat, 'eeg', newPath, metadata, bids);
end

%% ===== NIRS =====
function ExportNirs(sRun, ChannelMat, bids, settings)
    newPath = bst_fullfile(bids.DataFolder, [bids.NewName, '.snirf']);
    if exist(newPath, 'file') && ~settings.Overwrite
        return;
    end
    
    % Data files
    export_data(sRun.sInput.FileName, [], newPath, 'NIRS-SNIRF');
    export_channel(sRun.sInput.ChannelFile, bst_fullfile(bids.DataFolder, [bids.Prefix, '_optodes.tsv']), 'BIDS-NIRS-ALS-MM', 0);
    out_channel_bids_nirs(sRun.sInput.ChannelFile, bst_fullfile(bids.DataFolder, [bids.BaseName, '_channels.tsv']), sRun.DataMat.DisplayUnits, sRun.DataMat.F.channelflag);
    
    % Sidecar fields
    OPTIONS = settings.Options;
    [isrcs, idets] = nst_unformat_channels({ChannelMat.Channel(strcmp({ChannelMat.Channel.Type}, 'NIRS')).Name});
    metadata = GetCommonMetadata(settings.SidecarExtra.nirs, sRun, settings);
    metadata = addField(metadata, 'NIRSChannelCount',       length(isrcs));
    metadata = addField(metadata, 'NIRSSourceOptodeCount',  length(unique(isrcs)));
    metadata = addField(metadata, 'NIRSDetectorOptodeCount', length(unique(idets)));
    metadata = addField(metadata, 'SourceType',   valueOrNA(OPTIONS.NirsSourceType));
    metadata = addField(metadata, 'DetectorType', valueOrNA(OPTIONS.NirsDetectorType));
    metadata = addIfNotEmpty(metadata, 'CapManufacturer', OPTIONS.NirsCapManufacturer);
    metadata = addIfNotEmpty(metadata, 'CapManufacturersModelName', OPTIONS.NirsCapModel);

    sData = in_bst_data(sRun.sInput.FileName, 'Time');
    metadata = addField(metadata, 'RecordingDuration', sData.Time(end) - sData.Time(1));

    WriteRecordingFiles(sRun, ChannelMat, 'nirs', newPath, metadata, bids);
end

%% ===== FILES COMMON TO ALL MODALITIES =====
% Sidecar fields common to all modalities, on top of the additional fields entered in the panel
function metadata = GetCommonMetadata(extraMetadata, sRun, settings)
    metadata = extraMetadata;
    metadata = addField(metadata, 'TaskName', sRun.TaskName);
    metadata = addField(metadata, 'Manufacturer', sRun.sFile.device);
    metadata = addField(metadata, 'SamplingFrequency', sRun.sFile.prop.sfreq);
    metadata = addField(metadata, 'PowerLineFrequency', settings.PowerLine);
end

% Fields extracted from the original recording, depending on the device
function metadata = GetDeviceMetadata(sFile)
    if strcmpi(sFile.device, 'CTF')
        metadata = ExtractCtfMetadata(fileparts(sFile.filename));
    elseif strcmpi(sFile.device, 'Neuromag')
        metadata = ExtractFifMetadata(sFile.filename);
    else
        metadata = struct('SoftwareFilters', 'n/a');
    end
end

% Fiducials (and NIRS) coordinate system
function coorddata = GetCoordSystem(ChannelMat, modality)
    SCSfields = fieldnames(ChannelMat.SCS);
    field_to_remove = setdiff(SCSfields, {'LPA', 'NAS', 'RPA'});
    SCSprint = rmfield(ChannelMat.SCS, field_to_remove);
    description = 'Scanner-based RAS coordinates matching the description for ScanRAS at: https://bids-specification.readthedocs.io/en/stable/appendices/coordinate-systems.html';
    
    coorddata = struct();
    coorddata = addField(coorddata, 'FiducialsCoordinates', SCSprint);
    coorddata = addField(coorddata, 'FiducialsCoordinateUnits', 'm');
    coorddata = addField(coorddata, 'FiducialsCoordinateSystem', 'CTF');
    coorddata = addField(coorddata, 'FiducialsCoordinateSystemDescription', description);
    coorddata = addField(coorddata, 'AnatomicalLandmarkCoordinates', SCSprint);
    coorddata = addField(coorddata, 'AnatomicalLandmarkCoordinateUnits', 'm');
    coorddata = addField(coorddata, 'AnatomicalLandmarkCoordinateSystem', 'CTF');
    coorddata = addField(coorddata, 'AnatomicalLandmarkCoordinateSystemDescription', description);
    if strcmp(modality, 'nirs')
        coorddata = addField(coorddata, 'NIRSCoordinateSystem', 'CTF'); % Make sure it isnt CapRAS
        coorddata = addField(coorddata, 'NIRSCoordinateSystemDescription', description);
        coorddata = addField(coorddata, 'NIRSCoordinateUnits', 'mm');
    end
end

% Sidecar JSON, scans.tsv, events.tsv and coordsystem.json
function WriteRecordingFiles(sRun, ChannelMat, modality, dataPath, metadata, bids)
    % Device-specific fields, not overwriting the ones defined above
    metadata = struct_copy_fields(metadata, GetDeviceMetadata(sRun.sFile), 0);
    % Create JSON sidecar
    WriteJson(bst_fullfile(bids.DataFolder, [bids.NewName '.json']), metadata);
    % Create session TSV file
    CreateSessionTsv(bst_fullfile(bids.SessionFolder, [bids.Prefix '_scans.tsv']), dataPath, sRun.DateOfStudy);
    % Create event TSV file
    out_events_bids(sRun.sFile, bst_fullfile(bids.DataFolder, [bids.BaseName, '_events.tsv']));
    % Create coordinates JSON
    WriteJson(bst_fullfile(bids.DataFolder, [bids.Prefix '_coordsystem.json']), GetCoordSystem(ChannelMat, modality));
end


%% =================================================================================
%  === MAPPING OF PREVIOUS EXPORTS, IDENTIFIERS ====================================
%  =================================================================================
function string = zero_prefix(num, num_digits)
    string = num2str(num);
    while length(string) < num_digits
        string = ['0' string];
    end
end

function data = LoadExistingData(folder)
    bstMapping = bst_fullfile(folder, 'derivatives', 'bst_db_mapping.mat');
    if exist(bstMapping, 'file') == 2
        data = load(bstMapping);
        data = data.data;
    else
        data = EmptyData();
    end
end

function data = EmptyData()
    data = struct();
    data.Subjects = [];
end

function SaveExistingData(data, folder)
    derivatives = bst_fullfile(folder, 'derivatives');
    bstMapping = bst_fullfile(derivatives, 'bst_db_mapping.mat');
    if exist(derivatives, 'dir') ~= 7
        mkdir(derivatives);
    end
    save(bstMapping, 'data');
end

function subjectId = GetSubjectId(data, subjectName)
    subjectId = [];
    if ~isempty(data.Subjects)
        for iSubject = 1:length(data.Subjects)
            if strcmp(data.Subjects(iSubject).Name, subjectName)
                subjectId = data.Subjects(iSubject).Id;
                return;
            end
        end
    end
end

function iSub = GetPrivateSubjectId(data, subjectId)
    iSub = [];
    if ~isempty(data.Subjects)
        for iSubject = 1:length(data.Subjects)
            if SameIds(data.Subjects(iSubject).Id, subjectId)
                iSub = iSubject;
                return;
            end
        end
    end
end

function [sessionId, runId] = GetSessionId(data, subjectId, sessionName)
    iSub = GetPrivateSubjectId(data, subjectId);
    sessionId = [];
    runId = [];
    if ~isempty(data.Subjects(iSub).Sessions)
        for iSession = 1:length(data.Subjects(iSub).Sessions)
            if strcmp(data.Subjects(iSub).Sessions(iSession).Name, sessionName)
                sessionId = data.Subjects(iSub).Sessions(iSession).Id;
                runId = data.Subjects(iSub).Sessions(iSession).Run;
                return;
            end
        end
    end
end

function sessionId = GetFirstSessionId(data, subjectId)
    iSub = GetPrivateSubjectId(data, subjectId);
    if ~isempty(data.Subjects(iSub).Sessions)
        sessionId = data.Subjects(iSub).Sessions(1).Id;
    else
        sessionId = [];
    end
end

function same = SameIds(id1, id2)
    if ischar(id1) || ischar(id2)
        same = ischar(id1) && ischar(id2) && strcmp(id1, id2);
    else
        same = isequal(id1, id2);
    end
end

function data = AddSubject(data, subjectName, subjectId)
    iSub = length(data.Subjects) + 1;
    if iSub == 1
        data.Subjects = struct();
    end
    data.Subjects(iSub).Name = subjectName;
    data.Subjects(iSub).Id = subjectId;
    data.Subjects(iSub).Sessions = [];
end

function [data, runId] = AddSession(data, subjectId, sessionName, sessionId)
    iSub = GetPrivateSubjectId(data, subjectId);
    iSes = length(data.Subjects(iSub).Sessions) + 1;
    runId = CountSessionIds(data, iSub, sessionId) + 1;
    if iSes == 1
        data.Subjects(iSub).Sessions = struct();
    end
    data.Subjects(iSub).Sessions(iSes).Name = sessionName;
    data.Subjects(iSub).Sessions(iSes).Id   = sessionId;
    data.Subjects(iSub).Sessions(iSes).Run = runId;
end

function count = CountSessionIds(data, iSub, sessionId)
    count = 0;
    if ~isempty(data.Subjects(iSub).Sessions)
        for iSession = 1:length(data.Subjects(iSub).Sessions)
            if SameIds(data.Subjects(iSub).Sessions(iSession).Id, sessionId)
                count = count + 1;
            end
        end
    end
end

function formattedId = FormatId(id, namingScheme, prefix)
    if nargin < 3
        prefix = [];
    end

    if namingScheme == -1
        % Char-based scheme: only keep alphanumeric characters
        id = id(isstrprop(id, 'alphanum'));
    elseif namingScheme == 0
        % Num-based scheme
        id = num2str(id);
    elseif namingScheme > 0
        id = zero_prefix(id, namingScheme);
    end
    if ~isempty(prefix)
        formattedId = [prefix '-' id];
    else
        formattedId = id;
    end
end

function id = GetLastId(parentFolder, prefix)
    id = 0;
    dirs = dir(bst_fullfile(parentFolder, [prefix '-*']));
    if ~isempty(dirs)
        dirs = fliplr(sort({dirs.name}));
        for iDir = 1:length(dirs)
            if length(dirs{iDir}) > 5
                suffix = dirs{iDir}(5:end);
                n = str2num(suffix);
                if ~isempty(n)
                    % Skip dates
                    try
                        datenum(suffix, 'yyyymmdd');
                    catch
                        id = n;
                        return;
                    end
                end
            end
        end
    end
end

function WriteJson(jsonFile, metadata)
    fid = fopen(jsonFile, 'wt');

    if fid < 0
        error('Unable to write %s', jsonFile);
    end

    jsonText = bst_jsonencode(metadata);
    fprintf(fid, '%s', jsonText);
    fclose(fid);
end

function CreateDatasetDescription(parentFolder, overwrite, description, OPTIONS, FileType)
    if nargin < 3 || isempty(description)
        description = struct();
    end
    if nargin < 5
        FileType = 'raw';
    end
    jsonFile = bst_fullfile(parentFolder, 'dataset_description.json');
    ProtocolInfo = bst_get('ProtocolInfo');

    % Fields edited in the panel
    if ~isempty(OPTIONS.ProjName)
        datasetName = OPTIONS.ProjName;
    else
        datasetName = ProtocolInfo.Comment;
    end
    description = addField(description, 'Name', datasetName);
    description = addField(description, 'BIDSVersion', '1.3.0');
    description = addField(description, 'DatasetType', FileType);
    description = addField(description, 'Authors', strtrim(str_split(OPTIONS.Authors, ',')));
    description = addIfNotEmpty(description, 'License', OPTIONS.License);
    description = addIfNotEmpty(description, 'DatasetDOI', OPTIONS.DatasetDOI);
    description = addIfNotEmpty(description, 'HowToAcknowledge', OPTIONS.HowToAcknowledge);
    description = addIfNotEmpty(description, 'Acknowledgements', OPTIONS.Acknowledgements);
    description = addIfNotEmpty(description, 'Funding', SplitLines(OPTIONS.Funding));
    description = addIfNotEmpty(description, 'EthicsApprovals', SplitLines(OPTIONS.Ethics));
    description = addIfNotEmpty(description, 'ReferencesAndLinks', SplitLines(OPTIONS.References));
    
    % GeneratedBy: keep the entries of other software, update the Brainstorm one
    generatedBy = {};
    if isfield(description, 'GeneratedBy') && ~isempty(description.GeneratedBy)
        prev = description.GeneratedBy;
        if isstruct(prev)
            prev = num2cell(prev(:)');
        elseif ~iscell(prev)
            prev = {};
        end
        for iPrev = 1:length(prev)
            if ~(isstruct(prev{iPrev}) && isfield(prev{iPrev}, 'Name') && strcmp(prev{iPrev}.Name, 'Brainstorm3'))
                generatedBy{end + 1} = prev{iPrev};
            end
        end
    end
    generatedBy{end + 1} = struct('Name', 'Brainstorm3', ...
                                  'Version', bst_get('Version').Version, ...
                                  'CodeURL', 'https://github.com/brainstorm-tools/brainstorm3');
    description.GeneratedBy = generatedBy;
    
    % Existing file: only rewrite it if overwriting, or if its content changed
    if exist(jsonFile, 'file') == 2 && ~overwrite
        try
            if isequal(bst_jsondecode(fileread(jsonFile)), bst_jsondecode(bst_jsonencode(description)))
                return;
            end
        catch
        end
    end
    WriteJson(jsonFile, description);
end

function CreateDatasetReadme(parentFolder, overwrite, OPTIONS, firstAcq, lastAcq, AllChannelNames, AllEventNames)
    txtFile = bst_fullfile(parentFolder, 'README');

    % Default Project name/ID: Protocol name
    ProtocolInfo = bst_get('ProtocolInfo');
    if isempty(OPTIONS.ProjName)
        OPTIONS.ProjName = ProtocolInfo.Comment;
    end
    if isempty(OPTIONS.ProjID)
        OPTIONS.ProjID = ProtocolInfo.Comment;
    end
    
    % Default Project description / participant categories: n/a
    if isempty(OPTIONS.ProjDesc)
        OPTIONS.ProjDesc = 'n/a';
    end
    if isempty(OPTIONS.Categories)
        OPTIONS.Categories = 'n/a';
    end
    
    % Existing README: only rewrite it if overwriting, or if the project fields changed in the panel
    if exist(txtFile, 'file') == 2 && ~overwrite
        prev = panel_export_bids('ParseReadme', txtFile);
        if isempty(prev)
            return;
        elseif prev.IsForeign
            % README not written by Brainstorm: the whole text is the project description
            if strcmp(prev.ProjDesc, strtrim(OPTIONS.ProjDesc))
                return;
            end
        elseif strcmp(prev.ProjName, strtrim(OPTIONS.ProjName)) && strcmp(prev.ProjID, strtrim(OPTIONS.ProjID)) && ...
               strcmp(prev.ProjDesc, strtrim(OPTIONS.ProjDesc)) && strcmp(prev.Categories, strtrim(OPTIONS.Categories))
            return;
        end
    end
    
    % Default acquisition dates: n/a
    if isempty(firstAcq)
        firstAcq = 'n/a';
    else
        firstAcq = datestr(firstAcq, 'dd/mm/yyyy');
    end
    if isempty(lastAcq)
        lastAcq = 'n/a';
    else
        lastAcq = datestr(lastAcq, 'dd/mm/yyyy');
    end
    
    % Channels & Events
    if isempty(AllChannelNames)
        channels = ['n/a' 10];
    else
        channels = [];
        for iChannel = 1:length(AllChannelNames)
            channels = [channels num2str(iChannel) '. ' AllChannelNames{iChannel} 10];
        end
    end
    if isempty(AllEventNames)
        events = 'n/a';
    else
        events = [];
        for iEvent = 1:length(AllEventNames)
            events = [events num2str(iEvent) '. ' AllEventNames{iEvent} 10];
        end
    end
    
    % Create README file
    txt = ['Project Title: ' OPTIONS.ProjName 10 ...
           'Project ID: ' OPTIONS.ProjID 10 10 ...
           'Expected experimentation period:' 10 ...
           'Start date: ' firstAcq 10 ...
           'End date: ' lastAcq 10 10 ...
           'Project Description:' 10 ...
           OPTIONS.ProjDesc 10 10 ...
           'Participant categories:' 10 ...
           OPTIONS.Categories 10 10 ...
           'Trigger channels:' 10 ...
           channels 10 ...
           'Events:' 10 ...
           events];
    fid = fopen(txtFile, 'wt');
    fprintf(fid, '%s', txt);
    fclose(fid);
end

function res = containsKeyword(str, keywords)
    res = 0;
    for iKey = 1:length(keywords)
        if ~isempty(strfind(str, keywords{iKey}))
            res = 1;
            return;
        end
    end
end

function CreateSessionTsv(tsvFile, megFile, acqDate)
    acqTime = datestr(acqDate, 'yyyy-mm-ddTHH:MM:SS');
    [megFolder, megFile, megExt] = fileparts(megFile);
    [tmp, megFolder] = fileparts(megFolder);
    megFile = bst_fullfile(megFolder, [megFile megExt]);

    fid = fopen(tsvFile, 'wt');
    fprintf(fid, ['filename' 9 'acq_time' 13 10]);
    fprintf(fid, [megFile 9 acqTime]);
    fclose(fid);
end

% [] : Unknown scheme
% -2 : Date-based IDs (session only)
% -1 : Char-based custom IDs
%  0 : Numbered IDs of variable length
%  N : Numbered IDs of fixed length N (zero-padded)
function [subScheme, sesScheme, runScheme] = DetectNamingScheme(bidsDir)
    % Unknown schemes by default
    subScheme = [];
    sesScheme = [];
    runScheme = [];

    subjects = dir(bst_fullfile(bidsDir, 'sub-*'));
    if ~isempty(subjects)
        %% Detect subject scheme
        subjectName = subjects(1).name(5:end);
        subjectId   = str2num(subjectName);
        if ~isempty(subjectId)
            strLen = length(subjectName);
            numLen = length(num2str(subjectId));
            if strLen > numLen
                % Zero-padded IDs
                subScheme = strLen;
            else
                % Non-padded IDs
                subScheme = 0;
            end
        else
            % Char-based scheme
            subScheme = -1;
        end
        
        %% Detect session scheme
        sessions = dir(bst_fullfile(bidsDir, subjects(1).name, 'ses-*'));
        if ~isempty(sessions)
            sessionName = sessions(1).name(5:end);
            sessionId   = str2num(sessionName);
            if ~isempty(sessionId)
                strLen = length(sessionName);
                numLen = length(num2str(sessionId));
                if strLen > numLen
                    % Zero-padded IDs
                    sesScheme = strLen;
                elseif strLen == 8
                    % Date based IDs (e.g. 20180925)
                    sesScheme = -2;
                else
                    % Non-padded IDs
                    sesScheme = 0;
                end
            else
                % Char-based scheme
                sesScheme = -1;
            end
            
            %% Detect run scheme
            megFiles = dir(bst_fullfile(bidsDir, subjects(1).name, sessions(1).name, 'meg'));
            if isempty(megFiles)
                megFiles = dir(bst_fullfile(bidsDir, subjects(1).name, sessions(1).name, 'eeg'));
            end
            for iFile = 1:length(megFiles)
                run = regexp(megFiles(iFile).name, '_run-(\d+)', 'match');
                if ~isempty(run)
                    runScheme = length(run{1}) - 5;
                    break;
                end
            end
        end
    end
end

function metadata = ExtractCtfMetadata(ds_directory)
    metadata = struct();
    [DataSetName, meg4_files, res4_file] = ctf_get_files(ds_directory, 0);
    [header, ChannelMat] = ctf_read_res4(res4_file);
    
    % Software Filters
    metadata.SoftwareFilters = struct();
    if isfield(header, 'SensorRes') && ~isempty(header.SensorRes)
        GradOrder = header.SensorRes(find([header.SensorRes.sensorTypeIndex] == 5, 1)).grad_order_no;
        metadata.SoftwareFilters.SpatialCompensation = struct('GradientOrder', GradOrder);
    end
    if isfield(header, 'filter') && ~isempty(header.filter)
        for iFilter = 1:length(header.filter)
            metadata.SoftwareFilters.TemporalFilter(iFilter).Type = header.filter(iFilter).fType;
            metadata.SoftwareFilters.TemporalFilter(iFilter).Class = header.filter(iFilter).fClass;
            metadata.SoftwareFilters.TemporalFilter(iFilter).Frequency = header.filter(iFilter).freq;
            metadata.SoftwareFilters.TemporalFilter(iFilter).Parameters = header.filter(iFilter).params;
        end
    end
end

function metadata = ExtractFifMetadata(fifFile)
    metadata = struct();
    metadata.SoftwareFilters = 'n/a';
    %TODO: Current MNE matlab readers do not import the processing history
    % and SSS info from FIF files. Someone more experienced with the format
    % could implement something similar to mne/io/proc_history.py and add
    % that information here under SoftwareFilters. For now, let the user
    % enter them manually if they so desire, like other BIDS exporters.
end


function taskName = ExtractCtfTaskname(sFile)
    taskName = [];
    dsFolder = fileparts(sFile.filename);
    infoDs = dir(fullfile(dsFolder, '*.infods'));
    if ~isempty(infoDs)
        infoTag = readCPersist(fullfile(dsFolder, infoDs.name), 0);
        if ~isempty(infoTag)
            iTag = find(strcmp('_DATASET_PROCSTEPPROTOCOL', {infoTag.name}));
            if ~isempty(iTag)
                protocol = deblank(infoTag(iTag).data);
                if ~isempty(protocol)
                    taskName = protocol;
                end
            end
        end
    end
end

function taskName = ExtractFifTaskname(sFile)
    try
        [fid, tree] = fiff_open(sFile.filename);
        info = fiff_read_meas_info(fid, tree);
        fclose(fid);
        taskName = info.proj_name;
    catch
        taskName = [];
    end
end

function [hasHeadPoints, hasLandmarks] = ExtractHeadPoints(ChannelMat)
    if isfield(ChannelMat, 'HeadPoints') && ~isempty(ChannelMat.HeadPoints) && ~isempty(ChannelMat.HeadPoints.Loc)
        nHS = size(ChannelMat.HeadPoints.Loc, 2);
    else
        nHS = 0;
    end
    
    hasHeadPoints = nHS > 0;
    
    if hasHeadPoints
        hasLandmarks = any(strcmpi(ChannelMat.HeadPoints.Type, 'CARDINAL'));
    else
        hasLandmarks = 0;
    end
end

function str = bool2str(bool)
    if bool == 1
        str = 'true';
    elseif bool == 0
        str = 'false';
    else
        error('Unsupported input.');
    end
end

function [sInputs, mrisToDeface] = SortInputs(sInputs, defaceMri)
    % Group inputs by subject
    iOrder = zeros(1, length(sInputs));
    iNext = 1;
    [uniqueSubj,I,J] = unique({sInputs.SubjectFile});
    mrisToDeface = {};
    
    for iUniqueSub = 1:length(uniqueSubj)
        iSubs = find(J == iUniqueSub);
        nSubs = length(iSubs);
        skip  = zeros(1,nSubs);
        
        % If the subject does not have a defaced MRI, add its MRI file to
        % the list of MRIs to deface.
        if defaceMri
            sSubject = bst_get('Subject', uniqueSubj{iUniqueSub});
            if ~isempty(sSubject.Anatomy) && isempty(GetDefacedMri(sSubject)) && ~isempty(sSubject.Anatomy(1).FileName)
                mrisToDeface{end + 1} = sSubject.Anatomy(1).FileName;
            end
        end
        
        % Within subjects, group inputs by acquisition time
        for iSub = 1:nSubs
            sInput = sInputs(iSubs(iSub));
            DataMat = in_bst_data(sInput.FileName, {'F', 'History'});
            sFile = DataMat.F;
            % Try to find original raw file
            if strcmpi(sFile.format, 'BST-BIN') && strcmpi(sFile.device, 'CTF')
                origFilename = ExtractOriginalBstFilename(DataMat);
                if ~isempty(origFilename)
                    sFile.filename = origFilename;
                else
                    % Skip if we can't find original raw file
                    skip(iSub) = 1;
                    disp(['Skipping file "' sFile.comment '" due to raw link no longer existing...']);
                end
            end
            % Extract acquisition time
            acqTime = ExtractAcquisitionTime(sFile, sInput.iStudy);
            if iSub == 1
                acqTimes = acqTime;
            else
                acqTimes(end + 1) = acqTime;
            end
        end
        [sortedTimes, iSorts] = sort(acqTimes);
        for iSort = 1:nSubs
            if ~skip(iSub)
                iOrder(iNext) = iSubs(iSorts(iSort));
                iNext = iNext + 1;
            end
        end
    end
    sInputs = sInputs(iOrder);
end

function acqTime = ExtractAcquisitionTime(sFile, iStudy)
    % Try to detect exact acquisition time from CTF metadata
    if strcmpi(sFile.device, 'CTF')
        ds_directory = fileparts(sFile.filename);
        [DataSetName, meg4_files, res4_file] = ctf_get_files(ds_directory, 0);
        header = ctf_read_res4(res4_file);
        if ~isempty(header) && isfield(header, 'res4') && ~isempty(header.res4) ...
                && isfield(header.res4, 'data_date') && ~isempty(header.res4.data_date) ...
                && isfield(header.res4, 'data_time') && ~isempty(header.res4.data_time)
            ctfDate = deblank(header.res4.data_date);
            ctfTime = deblank(header.res4.data_time);
            if ~isempty(ctfDate) && ~isempty(ctfTime)
                try
                    acqTime = datenum([ctfDate ' ' ctfTime], 'dd-mmm-yyyy HH:MM');
                    if ~isempty(acqTime)
                        return;
                    end
                catch
                end
            end
        end
    end

    % Otherwise, get study date
    sStudy = bst_get('Study', iStudy);
    if isfield(sStudy, 'DateOfStudy') && ~isempty(sStudy.DateOfStudy)
        acqTime = datetime(sStudy.DateOfStudy);
    else
        % When all else fails, return today's date...
        acqTime = now;
    end
end

function filename = ExtractOriginalBstFilename(DataMat)
    filename = [];
    if isfield(DataMat, 'History') && ~isempty(DataMat.History)
        for iHist = 1:size(DataMat.History, 1)
            if strcmpi(DataMat.History{iHist, 2}, 'import')
                rawFile = strrep(DataMat.History{iHist, 3}, 'Link to raw file: ', '');
                if ~isempty(rawFile) && (exist(rawFile, 'file') == 2 || exist(rawFile, 'dir') == 7)
                    [DataSetName, meg4_files] = ctf_get_files(rawFile, 0);
                    if ~isempty(meg4_files)
                        filename = meg4_files{1};
                        return;
                    end
                end
            end
        end
    end
end

function myStruct = addField(myStruct, field, value)
    if isfield(myStruct, field)
        disp(['Warning: Specified field "' field '" will be ignored.']);
    end
    myStruct.(field) = value;
end

function defacedMri = GetDefacedMri(sSubject)
    defacedMri = [];
    
    for iAnatomy = 1:length(sSubject.Anatomy)
        if ~isempty(strfind(sSubject.Anatomy(iAnatomy).Comment, ' | deface'))
            defacedMri = sSubject.Anatomy(iAnatomy).FileName;
        end
    end
end

% Metadata options: panel values, or metadata of the existing dataset if the panel was not
% validated for this output folder (keeps the existing metadata identical by default)
function OPTIONS = LoadMetadataOptions(sProcess, outputFolder)
    OPTIONS = panel_export_bids('GetOptions');
    panelValue = [];
    if isfield(sProcess.options, 'edit') && isfield(sProcess.options.edit, 'Value')
        panelValue = sProcess.options.edit.Value;
    end
    if isstruct(panelValue) && ~isempty(panelValue)
        OPTIONS = struct_copy_fields(OPTIONS, panelValue, 1);
    elseif ~strcmp(OPTIONS.PreparedFor, outputFolder)
        [existing, nFound] = panel_export_bids('ReadExistingMetadata', outputFolder);
        if nFound > 0
            disp('BIDS> Using the metadata found in the existing output folder. Click "Edit..." to modify it.');
            OPTIONS = struct_copy_fields(panel_export_bids('GetDefaultOptions'), existing, 1);
        end
    end
end

function myStruct = addIfNotEmpty(myStruct, field, value)
    if ~isempty(value)
        myStruct = addField(myStruct, field, value);
    end
end

function value = valueOrNA(value)
    if isempty(value)
        value = 'n/a';
    end
end

% Split a multi-line text in a cell array of non-empty lines
function lines = SplitLines(txt)
    lines = strtrim(regexp(txt, '\r?\n', 'split'));
    lines(cellfun(@isempty, lines)) = [];
end