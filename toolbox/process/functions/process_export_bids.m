function varargout = process_export_bids( varargin )
% PROCESS_EXPORT_BIDS: Exports selected raw files in BIDS format.

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
% Authors: Martin Cousineau, 2018

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the processc
    sProcess.Comment     = 'Export MEG-BIDS dataset';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 72;
    sProcess.Description = '';
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
    sProcess.options.sesscheme.Comment = {'Acquisition date', 'Number index', 'Session names (ses-XXXX): '};
    sProcess.options.sesscheme.Type    = 'radio_line';
    sProcess.options.sesscheme.Value   = 1;
    % Identifying empty room
    sProcess.options.emptyroom.Comment = 'Keywords to detect empty room recordings: ';
    sProcess.options.emptyroom.Type    = 'text';
    sProcess.options.emptyroom.Value   = 'emptyroom, noise';
    % Replace existing files
    sProcess.options.overwrite.Comment = 'Overwrite existing files?';
    sProcess.options.overwrite.Type    = 'checkbox';
    sProcess.options.overwrite.Value   = 0;
    
    sProcess.options.label1.Comment = '<U><B>MEG Sidecar required fields</B></U>:';
    sProcess.options.label1.Type    = 'label';
    % Powerline frequency
    sProcess.options.powerline.Comment = {'50 Hz', '60 Hz', 'Power line frequency: '};
    sProcess.options.powerline.Type    = 'radio_line';
    sProcess.options.powerline.Value   = 2;
    % Dewar position during MEG scan
    sProcess.options.dewarposition.Comment = 'Position of the dewar during the MEG scan: ';
    sProcess.options.dewarposition.Type    = 'text';
    sProcess.options.dewarposition.Value   = 'Upright';
    % Dataset description metadata
    sProcess.options.datasetmeta.Comment = 'Additional dataset description JSON fields: ';
    sProcess.options.datasetmeta.Type    = 'textarea';
    sProcess.options.datasetmeta.Value   = ['{' 10 '  "License": "PD"' 10 '}'];
    % MEG sidecar metadata
    sProcess.options.megmeta.Comment = 'Additional MEG sidecar JSON fields: ';
    sProcess.options.megmeta.Type    = 'textarea';
    sProcess.options.megmeta.Value   = ['{' 10 '  "InstitutionName": "McGill University"' 10 '}'];
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function sInputs = Run(sProcess, sInputs) %#ok<DEFNU>
    % Parse inputs
    outputFolder  = sProcess.options.bidsdir.Value{1};
    overwrite     = sProcess.options.overwrite.Value;
    dewarPosition = sProcess.options.dewarposition.Value;
    emptyRoomKeywords = strtrim(str_split(lower(sProcess.options.emptyroom.Value), ',;'));
    if isempty(outputFolder)
        bst_report('Error', sProcess, sInputs, 'No output folder specified.');
    end
    if isfield(sProcess.options, 'powerline') && ~isempty(sProcess.options.powerline.Value)
        if sProcess.options.powerline.Value == 1
            powerline = 50;
        elseif sProcess.options.powerline.Value == 2
            powerline = 60;
        else
            bst_report('Error', sProcess, sInputs, 'Invalid power line selection.');
        end
    else
        powerline = [];
    end
    datasetMetadata = struct();
    if isfield(sProcess.options, 'datasetmeta') && ~isempty(sProcess.options.datasetmeta.Value)
        datasetMeta = strtrim(sProcess.options.datasetmeta.Value);
        if ~isempty(datasetMeta)
            try
                datasetMetadata = bst_jsondecode(datasetMeta);
            catch e
                bst_report('Error', sProcess, sInputs, ['Invalid dataset description: ' e.message]);
                return;
            end
        end
    end
    megMetadata = struct();
    if isfield(sProcess.options, 'megmeta') && ~isempty(sProcess.options.megmeta.Value)
        megMeta = strtrim(sProcess.options.megmeta.Value);
        if ~isempty(megMeta)
            try
                megMetadata = bst_jsondecode(megMeta);
            catch e
                bst_report('Error', sProcess, sInputs, ['Invalid MEG sidecar metadata: ' e.message]);
                return;
            end
        end
    end
    
    iLastSub = 0;
    % If folder does not exist, try to create it.
    if exist(outputFolder, 'dir') ~= 7
        [success, errMsg] = mkdir(outputFolder);
        subScheme = [];
        sesScheme = [];
        runScheme = [];
        if ~success
            bst_report('Error', sProcess, sInputs, ['Could not create output folder:' 10 errMsg]);
        end
    else
        % If folder exist, try to figure out naming scheme
        [subScheme, sesScheme, runScheme] = DetectNamingScheme(outputFolder);
        
        % If numbered subject IDs, extract last subject ID
        if subScheme >= 0
            iLastSub = GetLastId(outputFolder, 'sub');
        end
    end
    
    % Default naming schemes
    if isfield(sProcess.options, 'subscheme') && ~isempty(sProcess.options.subscheme.Value)
        if sProcess.options.subscheme.Value == 1
            subScheme = -1;
        else
            subScheme = 4;
        end
    elseif isempty(subScheme)
        subScheme = -1; % Char-based
    end
    if isfield(sProcess.options, 'sesscheme') && ~isempty(sProcess.options.sesscheme.Value)
        if sProcess.options.sesscheme.Value == 1
            sesScheme = -2;
        else
            sesScheme = 4;
        end
    elseif isempty(sesScheme)
        sesScheme = -2; % Date-based
    end
    if isempty(runScheme)
        runScheme = 2;  % Index-based, 2 digits
    end
    
    % Sort inputs by subjects and acquisition time
    bst_progress('start', 'Export', 'Sorting input files...');
    sInputs = SortInputs(sInputs);
    nInputs = length(sInputs);
    
    CreateDatasetDescription(outputFolder, overwrite, datasetMetadata)
    data = LoadExistingData(outputFolder);
    
    bst_progress('start', 'Export', 'Exporting dataset files...', 0, nInputs);
    for iInput = 1:nInputs
        sInput   = sInputs(iInput);
        sStudy   = bst_get('Study', sInput.iStudy);
        sSubject = bst_get('Subject', sStudy.BrainStormSubject);
        
        % Skip unsupported formats
        DataMat = in_bst_data(sInput.FileName);
        sFile = DataMat.F;
        if (~isempty(sFile.device) && ~ismember(sFile.device, {'CTF'})) || isempty(sFile.format) || ~ismember(sFile.format, {'CTF', 'CTF-CONTINUOUS', 'BST-BIN'})
            disp(['Skipping file "' sFile.comment '" due to unsupported format...']);
            continue;
        end
        
        % If BST binary file, find original raw file
        if strcmpi(sFile.format, 'BST-BIN') && strcmpi(sFile.device, 'CTF')
            sFile.filename = ExtractOriginalBstFilename(DataMat);
            disp(['Warning: File "', sFile.comment, '" already imported in binary format.', ...
                10, '         Using raw link "', sFile.filename, '" instead.']);
        end
        
        % Extract date of study
        dateOfStudy = ExtractAcquisitionTime(sFile, sInput.iStudy);
        
        %% Check if subject already exists
        newSubject = 1;
        iExistingSub = GetSubjectId(data, sSubject.Name);
        if ~isempty(iExistingSub)
            subjectId = iExistingSub;
            newSubject = 0;
        % Detect subject names formatted as "sub-<name>"
        elseif strncmp(sSubject.Name, 'sub-', 4) && length(sSubject.Name) > 5
            if subScheme == -1
                subjectId = sSubject.Name(5:end);
                data = AddSubject(data, sSubject.Name, subjectId);
                newSubject = 0;
            else
                disp('Warning: BIDS-formatted subject name detected, but numbered index subject names selected. A new index will be assigned. Select custom names to avoid this.');
            end
        end

        %% Create subject if new
        if newSubject
            if subScheme == -1
                % Char-based naming scheme
                subjectId = FormatId(sSubject.Name, subScheme);
            else
                % Number-based naming scheme, increment from previous
                subjectId = iLastSub + 1;
                maxSubjects = power(10, subScheme);
                if subScheme > 1 && subjectId >= maxSubjects
                    bst_report('Error', sProcess, sInput, ...
                        ['Exceeded maximum number of subjects supported by your naming scheme (' num2str(maxSubjects) ').']);
                end
            end
            data = AddSubject(data, sSubject.Name, subjectId);
        end
        
        %% Check if this is the empty room subject
        if strncmp(sStudy.Name, '@raw', 4)
            sessionName = sStudy.Name(5:end);
        else
            sessionName = sStudy.Name;
        end
        isEmptyRoom = strcmp(sSubject.Name, 'sub-emptyroom') || (~isempty(emptyRoomKeywords) && containsKeyword(lower(sessionName), emptyRoomKeywords));
        if isEmptyRoom
            realSubjectId = subjectId;
            subjectId = 'emptyroom';
            subjectFolder = bst_fullfile(outputFolder, FormatId(subjectId, subScheme, 'sub'));
            if exist(subjectFolder, 'dir') ~= 7
                mkdir(subjectFolder);
            end
            
            % Date of study is the session name for empty room recordings
            [sessionId, runId] = GetSessionId(data, realSubjectId, sessionName);
            if isempty(sessionId)
                sessionId = datestr(dateOfStudy, 'yyyymmdd');
                [data, runId] = AddSession(data, realSubjectId, sessionName, sessionId);
            end
            sessionFolder = bst_fullfile(subjectFolder, FormatId(sessionId, -2, 'ses'));
            if exist(sessionFolder, 'dir') ~= 7
                mkdir(sessionFolder);
            end
        else
            subjectFolder = bst_fullfile(outputFolder, FormatId(subjectId, subScheme, 'sub'));
            if exist(subjectFolder, 'dir') ~= 7
                mkdir(subjectFolder);
                iLastSub = subjectId;
            end
            
            %% Check if session already exists
            newSession = 1;
            subLen = length(sSubject.Name);
            [iExistingSes, runId] = GetSessionId(data, subjectId, sessionName);
            if ~isempty(iExistingSes)
                sessionId = iExistingSes;
                newSession = 0;
            % Detect session names formatted as "ses-<name>"
            elseif strncmp(sessionName(subLen+1:end), '_ses-', 5) && length(sessionName) > (subLen + 5)
                sessionId = regexp(sessionName, '_ses-(\w+)_', 'match');
                if ~isempty(sessionId)
                    sessionId = sessionId{1};
                    sessionId = sessionId(6:end-1);
                    if sesScheme == -1
                        [data, runId] = AddSession(data, subjectId, sessionName, sessionId);
                        newSession = 0;
                    elseif sesScheme >= 0
                        disp('Warning: BIDS-formatted session name detected, but numbered index session names selected. A new index will be assigned.');
                    end
                end
            end

            %% Create session if new
            if newSession
                if sesScheme == -1
                    % Char-based naming scheme
                    sessionId = FormatId(sessionName, sesScheme);
                elseif sesScheme == -2
                    % Date-based naming scheme
                    sessionId = datestr(dateOfStudy, 'yyyymmdd');
                else
                    % Number-based naming scheme, increment from previous
                    sessionId = GetLastId(subjectFolder, 'ses') + 1;
                    maxSessions = power(10, sesScheme);
                    if sesScheme > 1 && sessionId >= maxSessions
                        bst_report('Error', sProcess, sInput, ...
                            ['Exceeded maximum number of sessions supported by your naming scheme (' num2str(maxSubjects) ').']);
                    end
                end
                [data, runId] = AddSession(data, subjectId, sessionName, sessionId);
            end
            sessionFolder = bst_fullfile(subjectFolder, FormatId(sessionId, sesScheme, 'ses'));
            if exist(sessionFolder, 'dir') ~= 7
                mkdir(sessionFolder);
            end
        end
        
        %% Extract task name
        isCtf = strcmpi(sFile.device, 'CTF');
        [rawFolder, rawName, rawExt] = fileparts(sFile.filename);
        prefix = [FormatId(subjectId, subScheme, 'sub') '_' FormatId(sessionId, sesScheme, 'ses')];
        prefixTask = [prefix '_task-'];
        rest = [];
        if isEmptyRoom
            taskName = 'noise';
            if ~isempty(realSubjectId)
                rest = ['_acq-sub' FormatId(realSubjectId, subScheme)];
            end
        elseif strncmp(rawName, prefixTask, length(prefixTask))
            rawNameUnprefixed = rawName(length(prefixTask) + 1:end);
            endTask = strfind(rawNameUnprefixed, '_');
            if ~isempty(endTask)
                taskName = rawNameUnprefixed(1:endTask(1) - 1);
                %rest = rawNameUnprefixed(endTask(1):end);
            end
        else
            taskName = [];
            
            % Find task name from format specific metadata if possible
            if isCtf
                taskName = ExtractCtfTaskname(sFile);
            end
            
            % Otherwise, extract task name from condition
            if isempty(taskName)
                taskName = regexprep(rawName,'[^a-zA-Z0-9]','');
            end
        end
        if ~isempty(runId) && ~isempty(FormatId(runId, runScheme))
            rest = [rest '_run-' FormatId(runId, runScheme)];
        end
        
        %% If first session, save anatomy
        if ~isEmptyRoom && SameIds(sessionId, GetFirstSessionId(data, subjectId))
            if ~isempty(sSubject.Anatomy) && strcmpi(sSubject.Anatomy.Comment, 'mri') && ~isempty(sSubject.Anatomy.FileName)
                anatFolder = bst_fullfile(sessionFolder, 'anat');
                if exist(anatFolder, 'dir') ~= 7
                    mkdir(anatFolder);
                end
                mriFile = bst_fullfile(anatFolder, [prefix '_T1w.nii']);
                if (exist(mriFile, 'file') ~= 2 && exist([mriFile '.gz'], 'file') ~= 2) || overwrite
                    export_mri(sSubject.Anatomy.FileName, mriFile);
                    mriGzFile = gzip(mriFile);
                    if ~isempty(mriGzFile)
                        delete(mriFile);
                    end
                end
            end
        end
        
        %% Prepare metadata structure
        metadata = megMetadata;
        metadata = addField(metadata, 'TaskName', taskName);
        metadata = addField(metadata, 'Manufacturer', sFile.device);
        metadata = addField(metadata, 'SamplingFrequency', sFile.prop.sfreq);
        if ~isempty(powerline)
            metadata = addField(metadata, 'PowerLineFrequency', powerline);
        end
        metadata = addField(metadata, 'DewarPosition', dewarPosition);
        [hasHeadPoints, hasLandmarks] = ExtractHeadPoints(sInput.ChannelFile);
        metadata = addField(metadata, 'DigitizedLandmarks', bool2str(hasLandmarks));
        metadata = addField(metadata, 'DigitizedHeadPoints', bool2str(hasHeadPoints));
        
        % Extract format-specific metadata
        if isCtf
            customMetadata = ExtractCtfMetadata(fileparts(sFile.filename));
        else
            customMetadata = struct();
        end
        metadata = struct_copy_fields(metadata, customMetadata, 0);
        
        %% Save MEG data
        megFolder = bst_fullfile(sessionFolder, 'meg');
        if exist(megFolder, 'dir') ~= 7
            mkdir(megFolder);
        end
        % Add prefix + suffix to raw file
        newName = [prefixTask taskName rest '_meg'];
        % Copy raw file to output folder
        if isCtf
            rawExt = '.ds';
        end
        newPath = bst_fullfile(megFolder, [newName, rawExt]);
        if exist(newPath, 'file') == 0 || overwrite
            if isCtf
                % Rename internal DS files
                dsFolder = fileparts(sFile.filename);
                tempPath = bst_fullfile(megFolder, [rawName, rawExt]);
                copyfile(dsFolder, tempPath);
                if ~strcmp(tempPath, newPath)
                    ctf_rename_ds(tempPath, newPath, []);
                end
                % Save Polhemus file
                if hasHeadPoints
                    posFile = bst_fullfile(megFolder, [prefix '_headshape.pos']);
                    out_channel_pos(sInput.ChannelFile, posFile);
                end
                % Remove internal Polhemus files
                delete(bst_fullfile(newPath, '*.pos'));
            else
                copyfile(sFile.filename, newPath);
            end
            % Create JSON sidecar
            jsonFile = bst_fullfile(megFolder, [newName '.json']);
            CreateMegJson(jsonFile, metadata);
            
            % Create session TSV file
            tsvFile = bst_fullfile(sessionFolder, [prefix '_scans.tsv']);
            CreateSessionTsv(tsvFile, newPath, dateOfStudy)
        end
        
        bst_progress('inc', 1);
    end
    
    % Save condition to subject/session mapping for future exports.
    SaveExistingData(data, outputFolder);
end

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
        data = struct();
        data.Subjects = [];
    end
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
    if ischar(id1)
        same = strcmp(id1, id2);
    else
        same = id1 == id2;
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
                n = str2num(dirs{iDir}(5:end));
                if ~isempty(n)
                    id = n;
                    return;
                end
            end
        end
    end
end

function CreateMegJson(jsonFile, metadata)
    fid = fopen(jsonFile, 'wt');
    jsonText = bst_jsonencode(metadata);
    fprintf(fid, jsonText);
    fclose(fid);
end

function CreateDatasetDescription(parentFolder, overwrite, description)
    if nargin < 3
        description = struct();
    end

    jsonFile = bst_fullfile(parentFolder, 'dataset_description.json');
    if exist(jsonFile, 'file') == 2 && ~overwrite
        return;
    end
    
    ProtocolInfo = bst_get('ProtocolInfo');
    description = addField(description, 'Name', ProtocolInfo.Comment);
    description = addField(description, 'BIDSVersion', '1.1.1');
    
    fid = fopen(jsonFile, 'wt');
    jsonText = bst_jsonencode(description);
    fprintf(fid, jsonText);
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


function taskName = ExtractCtfTaskname(sFile)
    taskName = [];
    infoDs = dir(fullfile(fileparts(sFile.filename), '*.infods'));
    if ~isempty(infoDs)
        infoTag = readCPersist(fullfile(infoDs.folder, infoDs.name), 0);
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

function [hasHeadPoints, hasLandmarks] = ExtractHeadPoints(channelFile)
    ChannelMat = in_bst_channel(channelFile);
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

function sInputs = SortInputs(sInputs)
    % Group inputs by subject
    iOrder = zeros(1, length(sInputs));
    iNext = 1;
    [uniqueSubj,I,J] = unique({sInputs.SubjectFile});
    for iUniqueSub = 1:length(uniqueSubj)
        iSubs = find(J == iUniqueSub);
        nSubs = length(iSubs);
        skip  = zeros(1,nSubs);
        
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
                    acqTime = datetime([ctfDate ' ' ctfTime], 'InputFormat', 'dd-MMM-yyyy HH:mm');
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
        acqTime = datetime('today');
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
