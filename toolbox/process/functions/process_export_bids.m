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
    sProcess.Comment     = 'Export BIDS dataset';
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
    % Identifying empty room
    sProcess.options.emptyroom.Comment = 'Keywords to detect empty room recordings: ';
    sProcess.options.emptyroom.Type    = 'text';
    sProcess.options.emptyroom.Value   = 'emptyroom, noise';   
    % Replace existing files
    sProcess.options.overwrite.Comment = 'Overwrite existing files?';
    sProcess.options.overwrite.Type    = 'checkbox';
    sProcess.options.overwrite.Value   = 0;
    % Anonymize CTF files
    sProcess.options.anonymize.Comment = 'Anonymize raw files (if applicable)?';
    sProcess.options.anonymize.Type    = 'checkbox';
    sProcess.options.anonymize.Value   = 0;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function sInputs = Run(sProcess, sInputs) %#ok<DEFNU>
    outputFolder = sProcess.options.bidsdir.Value{1};
    overwrite    = sProcess.options.overwrite.Value;
    anonymize    = sProcess.options.anonymize.Value;
    emptyRoomKeywords = strtrim(str_split(lower(sProcess.options.emptyroom.Value), ',;'));
    if isempty(outputFolder)
        bst_report('Error', sProcess, sInputs, 'No output folder specified.');
    end
    
    iLastSub = 0;
    % If folder does not exist, try to create it.
    if exist(outputFolder, 'dir') ~= 7
        [success, errMsg] = mkdir(outputFolder);
        subjectScheme = [];
        sessionScheme = [];
        if ~success
            bst_report('Error', sProcess, sInputs, ['Could not create output folder:' 10 errMsg]);
        end
    else
        % If folder exist, try to figure out naming scheme
        [subjectScheme, sessionScheme] = DetectNamingScheme(outputFolder);
        
        % If numbered subject IDs, extract last subject ID
        if subjectScheme >= 0
            iLastSub = GetLastId(outputFolder, 'sub');
        end
    end
    
    % Default naming schemes
    if isempty(subjectScheme)
        subjectScheme = -1; % Char-based
    end
    if isempty(sessionScheme)
        sessionScheme = -2; % Date-based
    end
    
    CreateDatasetDescription(outputFolder, overwrite)
    data = LoadExistingData(outputFolder);
    
    for iInput = 1:length(sInputs)
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
        
        % If BST binary file, try to find original raw file, or skip otherwise
        if strcmpi(sFile.format, 'BST-BIN')
            skip = 1;
            if isfield(DataMat, 'History') && ~isempty(DataMat.History)
                for iHist = 1:size(DataMat.History, 1)
                    if strcmpi(DataMat.History{iHist, 2}, 'import')
                        rawFile = strrep(DataMat.History{iHist, 3}, 'Link to raw file: ', '');
                        if ~isempty(rawFile) && (exist(rawFile, 'file') == 2 || exist(rawFile, 'dir') == 7)
                            skip = 0;
                            sFile.filename = rawFile;
                            disp(['Warning: File "', sFile.comment, '" already imported in binary format.', ...
                                  10, '         Using raw link "', rawFile, '" instead.']);
                            break;
                        end
                    end
                end
            end
        else
            skip = 0;
        end
        if skip
            disp(['Skipping file "' sFile.comment '" due to raw link no longer existing...']);
            continue;
        end
        
        % Extract date of study
        if isfield(sStudy, 'DateOfStudy') && ~isempty(sStudy.DateOfStudy)
            dateOfStudy = datetime(sStudy.DateOfStudy);
        else
            dateOfStudy = datetime('today');
        end
        
        %% Check if this is the empty room subject
        if strncmp(sStudy.Name, '@raw', 4)
            sessionName = sStudy.Name(5:end);
        else
            sessionName = sStudy.Name;
        end
        isEmptyRoom = strcmp(sSubject.Name, 'sub-emptyroom') || (~isempty(emptyRoomKeywords) && containsKeyword(lower(sessionName), emptyRoomKeywords));
        if isEmptyRoom
            subjectName = 'sub-emptyroom';
            subjectId = 'emptyroom';
            iExistingSub = GetSubjectId(data, subjectName);
            if isempty(iExistingSub)
                data = AddSubject(data, subjectName, subjectId);
            end
            subjectFolder = bst_fullfile(outputFolder, FormatId(subjectId, subjectScheme, 'sub'));
            if exist(subjectFolder, 'dir') ~= 7
                mkdir(subjectFolder);
            end
            
            % Date of study is the session name for empty room recordings
            sessionId = datestr(dateOfStudy, 'yyyymmdd');
            sessionFolder = bst_fullfile(subjectFolder, FormatId(sessionId, -2, 'ses'));
            if exist(sessionFolder, 'dir') ~= 7
                mkdir(sessionFolder);
            end
        else
            %% Check if subject already exists
            newSubject = 1;
            iExistingSub = GetSubjectId(data, sSubject.Name);
            if ~isempty(iExistingSub)
                subjectId = iExistingSub;
                newSubject = 0;
            elseif strncmp(sSubject.Name, 'sub-', 4) && length(sSubject.Name) > 5 && exist(bst_fullfile(outputFolder, sSubject.Name), 'dir') == 7
                subjectId = sSubject.Name(5:end);
                if subjectScheme == -1 || ~isempty(str2num(subjectId))
                    data = AddSubject(data, sSubject.Name, subjectId);
                    newSubject = 0;
                end
            end

            %% Create subject if new
            if newSubject
                if subjectScheme == -1
                    subjectId = FormatId(sSubject.Name, subjectScheme);
                else
                    subjectId = iLastSub + 1;
                    maxSubjects = power(10, subjectScheme);
                    if subjectScheme > 1 && subjectId >= maxSubjects
                        bst_report('Error', sProcess, sInput, ...
                            ['Exceeded maximum number of subjects supported by your naming scheme (' num2str(maxSubjects) ').']);
                    end
                end
                data = AddSubject(data, sSubject.Name, subjectId);
            end
            subjectFolder = bst_fullfile(outputFolder, FormatId(subjectId, subjectScheme, 'sub'));
            if newSubject
                mkdir(subjectFolder);
                iLastSub = subjectId;
            end
            
            %% Check if session already exists
            newSession = 1;
            iExistingSes = GetSessionId(data, subjectId, sessionName);
            if ~isempty(iExistingSes)
                sessionId = iExistingSes;
                newSession = 0;
            elseif strncmp(sSubject.Name, 'ses-', 4) && length(sessionName) > 5 && exist(bst_fullfile(subjectFolder, sessionName), 'dir') == 7
                sessionId = sessionName(5:end);
                if sessionScheme == -1 || ~isempty(str2num(sessionId))
                    data = AddSession(data, subjectId, sessionName, sessionId);
                    newSession = 0;
                end
            end

            %% Create session if new
            if newSession
                if sessionScheme == -1 % Char-based naming scheme
                    sessionId = FormatId(sessionName, sessionScheme);
                elseif sessionScheme == -2 % Date-based naming scheme
                    sessionId = datestr(dateOfStudy, 'yyyymmdd');
                else
                    sessionId = GetLastId(subjectFolder, 'ses') + 1;
                    maxSessions = power(10, sessionScheme);
                    if sessionScheme > 1 && sessionId >= maxSessions
                        bst_report('Error', sProcess, sInput, ...
                            ['Exceeded maximum number of sessions supported by your naming scheme (' num2str(maxSubjects) ').']);
                    end
                end
                data = AddSession(data, subjectId, sessionName, sessionId);
            end
            sessionFolder = bst_fullfile(subjectFolder, FormatId(sessionId, sessionScheme, 'ses'));
            if newSession
                mkdir(sessionFolder);
            end
        end
        
        %% Extract task name
        [rawFolder, rawName, rawExt] = fileparts(sFile.filename);
        prefix = [FormatId(subjectId, subjectScheme, 'sub') '_' FormatId(sessionId, sessionScheme, 'ses')];
        prefixTask = [prefix '_task-'];
        rest = [];
        if isEmptyRoom
            taskName = 'noise';
            % Try to figure out the subject this empty room belongs to
            iExistingSub = GetSubjectId(data, sSubject.Name);
            if ~isempty(iExistingSub)
                rest = ['_acq-sub' zero_prefix(iExistingSub, 4)];
            end
        elseif strncmp(rawName, prefixTask, length(prefixTask))
            rawNameUnprefixed = rawName(length(prefixTask) + 1:end);
            endTask = strfind(rawNameUnprefixed, '_');
            if ~isempty(endTask)
                taskName = rawNameUnprefixed(1:endTask(1) - 1);
                rest = rawNameUnprefixed(endTask(1):end);
            end
        else
            taskName = regexprep(rawName,'[^a-zA-Z0-9]','');
        end
        
        %% If first session, save anatomy
        if ~isEmptyRoom && SameIds(sessionId, GetFirstSessionId(data, subjectId), sessionScheme)
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
        
        %% Save MEG data
        megFolder = bst_fullfile(sessionFolder, 'meg');
        if exist(megFolder, 'dir') ~= 7
            mkdir(megFolder);
        end
        % Add prefix + suffix to raw file
        newName = [prefixTask taskName rest '_meg'];
        % Copy raw file to output folder
        isCtf = strcmpi(sFile.format, 'CTF') || strcmpi(sFile.format, 'CTF-CONTINUOUS');
        if isCtf
            rawExt = '.ds';
        end
        newPath = bst_fullfile(megFolder, [newName, rawExt]);
        if exist(newPath, 'file') ~= 2 || overwrite
            if isCtf
                % Rename internal DS files
                dsFolder = fileparts(sFile.filename);
                tempPath = bst_fullfile(megFolder, [rawName, rawExt]);
                copyfile(dsFolder, tempPath);
                ctf_rename_ds(tempPath, newPath, [], anonymize);
                % Save Polhemus file
                posFile = bst_fullfile(megFolder, [prefix '_headshape.pos']);
                out_channel_pos(sInput.ChannelFile, posFile);
            else
                copyfile(sFile.filename, newPath);
            end
            % Create JSON sidecar
            jsonFile = bst_fullfile(megFolder, [newName '.json']);
            CreateMegJson(jsonFile, sFile, taskName);
            
            % Create session TSV file
            tsvFile = bst_fullfile(sessionFolder, [prefix '_scans.tsv']);
            CreateSessionTsv(tsvFile, newPath, dateOfStudy)
        end
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
            if data.Subjects(iSubject).Id == subjectId
                iSub = iSubject;
                return;
            end
        end
    end
end

function sessionId = GetSessionId(data, subjectId, sessionName)
    iSub = GetPrivateSubjectId(data, subjectId);
    sessionId = [];
    if ~isempty(data.Subjects(iSub).Sessions)
        for iSession = 1:length(data.Subjects(iSub).Sessions)
            if strcmp(data.Subjects(iSub).Sessions(iSession).Name, sessionName)
                sessionId = data.Subjects(iSub).Sessions(iSession).Id;
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

function same = SameIds(id1, id2, namingScheme)
    if namingScheme < 0
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

function data = AddSession(data, subjectId, sessionName, sessionId)
    iSub = GetPrivateSubjectId(data, subjectId);
    numSessions = length(data.Subjects(iSub).Sessions);
    if numSessions == 0
        data.Subjects(iSub).Sessions = struct();
    end
    data.Subjects(iSub).Sessions(numSessions + 1).Name = sessionName;
    data.Subjects(iSub).Sessions(numSessions + 1).Id = sessionId;
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

function CreateMegJson(jsonFile, sFile, taskName)
    fid = fopen(jsonFile, 'wt');
    fprintf(fid, '{');
    fprintf(fid, ['"TaskName":"' taskName '",']);
    fprintf(fid, ['"Manufacturer":"' sFile.device '",']);
    fprintf(fid, '"SamplingFrequency":%d', sFile.prop.sfreq);
    fprintf(fid, '}');
    fclose(fid);
    %TODO: missing some fields...
    % - PowerLineFrequency
    % - DewarPosition
    % - SoftwareFilters
    % - DigitizedLandmarks
    % - DigitizedHeadPoints
end

function CreateDatasetDescription(parentFolder, overwrite)
    jsonFile = bst_fullfile(parentFolder, 'dataset_description.json');
    if exist(jsonFile, 'file') == 2 && ~overwrite
        return;
    end
    ProtocolInfo = bst_get('ProtocolInfo');
    fid = fopen(jsonFile, 'wt');
    fprintf(fid, '{');
    fprintf(fid, ['"Name":"' ProtocolInfo.Comment '",']);
    fprintf(fid, '"BIDSVersion":"1.1.1"');
    fprintf(fid, '}');
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
function [subjectScheme, sessionScheme] = DetectNamingScheme(bidsDir)
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
                subjectScheme = strLen;
            else
                % Non-padded IDs
                subjectScheme = 0;
            end
        else
            % Char-based scheme
            subjectScheme = -1;
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
                    sessionScheme = strLen;
                elseif strLen == 8
                    % Date based IDs (e.g. 20180925)
                    sessionScheme = -2;
                else
                    % Non-padded IDs
                    sessionScheme = 0;
                end
            else
                % Char-based scheme
                sessionScheme = -1;
            end
        else
            % Unknown scheme
            sessionScheme = [];
        end
    else
        % Unknown scheme
        subjectScheme = [];
        sessionScheme = [];
    end
end
