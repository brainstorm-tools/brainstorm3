function [ sStudy ] = db_parse_study( studiesDir, studySubDir, sizeProgress )
% DB_PARSE_DIR_STUDY: Parse a study directory.
%
% USAGE:  sStudy = db_parse_study(studiesDir, studySubDir, sizeProgress);
% 
% INPUT:  
%     - studiesDir   : Top-level studies directory (protocol/data/)
%     - studySubDir  : Study subdirectory
%     - sizeProgress : The full process increments the available progress bar by this amount
% OUTPUT: 
%     - sStudy : array of Study structures (one entry for each subdirectory with a brainstormstudy file), 
%                or [] if no brainstormstudy was found in directory

% NOTES:
% In a study subdirectory (=condition) there is :
%     - '*_brainstormstudy*.mat' : One and only one
%     - '*_channel*.mat'         : One and only one
%     - '*_headmodel*.mat'       : any number
%     - '*_data*.mat'            : any number
%     - '*_result*.mat'          : any number
%     - '*_linkresult*.mat'      : any number
%     - '*_presults*.mat'        : any number
%     - '*_pdata*.mat'           : any number
%     - '*_ptimefreq*.mat'       : any number
%     - '*_dipoles*.mat'         : any number
%     - 'Default' directory      : Defaults files for current study subdirectory
%                                  => May contain : '*_channel*.mat' and '*_headmodel*.mat' files
%     - Any number of subdirectories, that will be interpreted as sub-conditions (processed recursively)
% All the .MAT files in the directory are associated with the current study.
%
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
% Authors: Francois Tadel, 2008-2022

%% ===== PARSE INPUTS =====
if ~file_exist(bst_fullfile(studiesDir, studySubDir))
    error('Path in argument does not exist, or is not a directory');
end
if (nargin < 3) || isempty(sizeProgress)
    sizeProgress = [];
end


%% ===== LOOK FOR STUDY DEFINITION =====
% List 'brainstormstudy*.mat' files in the studySubDir directory
studyFiles = dir(bst_fullfile(studiesDir, studySubDir, 'brainstormstudy*.mat'));
% List all '*.mat' files and subcondition directories in the studySubDir directory 
allFiles = dir(bst_fullfile(studiesDir, studySubDir, '*'));
% If there is no subject definition file : ignore the directory (but process subdirectories)
if isempty(studyFiles)
    studyMat = [];
% If there is more that one subject definition file : warning and ignore the directory (but process subdirectories)
elseif (length(studyFiles) > 1)
    studyMat = [];
    warning('Brainstorm:InvalidDirectory','There is more than one brainstormstudy file in directory ''%s'' : ignoring directory.', bst_fullfile(studiesDir, studySubDir));
else
    % Then there is only one file in studyFiles list
    studyFile = studyFiles(1);
    % Open file and get subject description
    try
        studyMat = load(bst_fullfile(studiesDir, studySubDir, studyFile.name));
    catch
        warning('Brainstorm:InvalidFile', 'Cannot open file ''%s'' : ignoring study', bst_fullfile(studiesDir, studySubDir, studyFile.name));
        studyMat = [];
    end
end


%% ===== READ STUDY DESCRIPTION =====
BadTrials = {};
if ~isempty(studyMat)
    % Initialize returned variable
    sStudy = db_template('Study');
    % ==== STUDY DESCRIPTION ====
    % Store subject's .MAT filename
    sStudy(1).FileName = bst_fullfile(studySubDir, studyFile.name);
    % Subject file
    if ismember(studySubDir, {bst_get('DirAnalysisInter'), bst_get('DirDefaultStudy')})
        sStudy(1).BrainStormSubject = bst_fullfile(bst_get('DirDefaultSubject'), 'brainstormsubject.mat');
    else
        sStudy(1).BrainStormSubject = bst_fullfile(bst_fileparts(studySubDir,1), 'brainstormsubject.mat');
    end
    % Name
    if isfield(studyMat, 'Name')
        sStudy(1).Name = studyMat.Name;
    end
    % DateOfStudy
    if isfield(studyMat, 'DateOfStudy')
        sStudy(1).DateOfStudy = studyMat.DateOfStudy;
    end
    % Bad trials
    if isfield(studyMat, 'BadTrials')
        % Remove files that do not exist from the list of bad trials
        if ~isempty(studyMat.BadTrials)
            iRemove = find(~ismember(studyMat.BadTrials, {allFiles.name}));
            if ~isempty(iRemove)
                studyMat.BadTrials(iRemove) = [];
                bst_save(bst_fullfile(studiesDir, sStudy(1).FileName), studyMat, 'v7');
            end
        end
        % Keep list of bad trials for parsing the rest of the folder
        BadTrials = studyMat.BadTrials;
    end
    
    % ==== STUDY CONDITION ====
    % The study subdirectory has a structure 'subject/condition/subcondition/...' 
    % To get the conditions list : split the filename, and eliminate the first part (subject)
    conditionsList = str_split(studySubDir);
    conditionsList(1) = [];
    sStudy(1).Condition = conditionsList;
else
    sStudy = repmat(db_template('Study'), 0);
end


%% ===== READ ALL FILES IN FOLDER =====
% Exclude from the list of files:
%    - Files starting with a '.' 
%    - ANALYSIS INTER directory
%    - ROOT DEFAULT STUDY directory
%    - Any other study folder that is immediately in the "data" folder
dirFiles = repmat(allFiles,0);
for iFile = 1:length(allFiles)
    if (allFiles(iFile).name(1) ~= '.') && ~strcmpi(allFiles(iFile).name, bst_get('DirAnalysisInter')) ...
                                        && ~(isempty(studySubDir) && strcmpi(allFiles(iFile).name, bst_get('DirDefaultStudy'))) 
        dirFiles(end+1,1) = allFiles(iFile);
    end
end
if isempty(dirFiles)
    return;
end
% Find channel file ('channel' tag)
isChannelFile = ~cellfun(@(c)isempty([strfind(lower(c),'_channel'), strfind(lower(c),'channel_')]), {dirFiles.name});
% Reorder directory files (put channel files first)
dirFiles = cat(1, dirFiles(isChannelFile), dirFiles(~isChannelFile));
% Initialize list of trials
trialFiles = {};
trialData = [];
trialInd = {};

% Progress bar?
isProgressBar = bst_progress('isvisible') && ~isempty(sizeProgress);
startValue = bst_progress('get');
curValue = startValue;
% Process all the files
for iFile = 1:length(dirFiles)
    % Increment progress bar
    if isProgressBar
        tmpValue = round(startValue + (iFile-1)/length(dirFiles) * sizeProgress);
        if (curValue ~= tmpValue)
            bst_progress('set', curValue);
            curValue = tmpValue;
        end
    end
    % Directories : recursively call this function, to add subconditions studies
    if (dirFiles(iFile).isdir)
        % Append studies in the subdirectory to the sStudy array
        sStudy = [sStudy, db_parse_study(studiesDir, bst_fullfile(studySubDir, dirFiles(iFile).name), round(sizeProgress / length(dirFiles)))];

    % Files (only if there is a brainstormstudy file in current directory)
    elseif ~isempty(studyMat)
        % Reconstruct filename
        filenameRelative = bst_fullfile(studySubDir, dirFiles(iFile).name);
        filenameFull     = bst_fullfile(studiesDir, studySubDir, dirFiles(iFile).name);
        % Determine filetype
        fileType = file_gettype(filenameFull);
        if isempty(fileType)
            continue;
        end
        % Process file
        switch(fileType)
            case 'channel'
                % Try to load channel info
                channelInfo = io_getChannelInfo(filenameRelative);
                % If a channel file was found : copy channel information
                if ~isempty(channelInfo)
                    sStudy(1).Channel = channelInfo;
                end
            case 'noisecov'
                % Try to load noisecov info
                noisecovInfo = io_getNoisecovInfo(filenameRelative);
                % If a channel file was found : copy channel information
                if ~isempty(noisecovInfo)
                    sStudy(1).NoiseCov(1) = noisecovInfo;
                end
            case 'ndatacov'
                % Try to load noisecov info
                noisecovInfo = io_getNoisecovInfo(filenameRelative);
                % If a channel file was found : copy channel information
                if ~isempty(noisecovInfo)
                    sStudy(1).NoiseCov(2) = noisecovInfo;
                end
                
            case {'data', 'spike'}
%                 % Get data filename without the trial block
%                 [groupName, iTrial] = str_remove_trial(filenameRelative);
%                 dataInfo = [];
%                 % If it is a trial in a group of trials
%                 if ~isempty(groupName)
%                     iTrialGroup = find(strcmpi(groupName, trialFiles));
%                     % Not existing in the trial group
%                     if isempty(iTrialGroup)
%                         trialFiles{end+1} = groupName;
%                         trialData(end+1) = length(sStudy(1).Data) + 1;
%                         trialInd{end+1} = iTrial;
%                     % Existing in the trial group
%                     elseif ~isempty(iTrial)
%                         dataInfo = sStudy(1).Data(trialData(iTrialGroup));
%                         dataInfo.Comment = strrep(dataInfo.Comment, ['(#' num2str(trialInd{iTrialGroup}) ')'], ['(#' num2str(iTrial) ')']);
%                         dataInfo.FileName = filenameRelative;
%                     end
%                 end
                % Try to load channel info
%                 if isempty(dataInfo)
                    dataInfo = io_getDataInfo(filenameRelative);
                    if ~isempty(dataInfo) && isempty(dataInfo.Comment)
                        dataInfo.Comment = '';
                    end
%                 end
                % If a data file was found : copy data information
                if ~isempty(dataInfo)
                    % Bad trial ?
                    if ~isempty(BadTrials)
                        dataInfo.BadTrial = ismember(dirFiles(iFile).name, BadTrials);
                    else
                        dataInfo.BadTrial = 0;
                    end
                    % Copy file description
                    sStudy(1).Data(end+1) = dataInfo;
                % Else : file is not valid : rename it to avoid it slowing the parsing
                else
                    fullfilename = bst_fullfile(studiesDir, filenameRelative);
                    file_move(fullfilename, [fullfilename, '.bak']);
                end

            case 'dipoles'
                % Try to load channel info
                dipolesInfo = io_getDipolesInfo(filenameRelative);
                % If a data file was found : copy data information
                if ~isempty(dipolesInfo)
                    sStudy(1).Dipoles(end+1) = dipolesInfo;
                % Else : file is not valid : rename it to avoid it slowing the parsing
                else
                    fullfilename = bst_fullfile(studiesDir, filenameRelative);
                    file_move(fullfilename, [fullfilename, '.bak']);
                end
            case 'timefreq'
                % Try to load channel info
                timefreqInfo = io_getTimefreqInfo(filenameRelative);
                % If a data file was found : copy data information
                if ~isempty(timefreqInfo)
                    sStudy(1).Timefreq(end+1) = timefreqInfo;
                % Else : file is not valid : rename it to avoid it slowing the parsing
                else
                    fullfilename = bst_fullfile(studiesDir, filenameRelative);
                    file_move(fullfilename, [fullfilename, '.bak']);
                end
            case 'headmodel'
                % Try to load headmodel info
                headModelInfo = io_getHeadModelInfo(filenameRelative);
                % If a data file was found : copy headmodel information
                if ~isempty(headModelInfo)
                    sStudy(1).HeadModel(end+1) = headModelInfo;
                end    
            case 'results'
                % Try to load result info
                resultsInfo = io_getResultInfo(filenameRelative);
                % If a data file was found : copy information
                if ~isempty(resultsInfo)
                    % Mark if it is a link-results file
                    resultsInfo.isLink = 0;
                    % Store file in study list
                    sStudy(1).Result(end+1) = resultsInfo;
                % Else : file is not valid : rename it to avoid it slowing the parsing
                else
                    fullfilename = bst_fullfile(studiesDir, filenameRelative);
                    file_move(fullfilename, [fullfilename, '.bak']);
                end

            case 'linkresults'
                % Remove file
                file_delete(bst_fullfile(studiesDir, filenameRelative), 1);
                disp(['Old linkresults file deleted: ', filenameRelative]);

            case {'presults', 'pdata', 'ptimefreq', 'pmatrix'}
                % Try to load result info
                statInfo = io_getStatInfo(filenameRelative, fileType);
                % If a data file was found : copy headmodel information
                if ~isempty(statInfo)
                    sStudy(1).Stat(end+1) = statInfo;
                % Else : file is not valid : rename it to avoid it slowing the parsing
                else
                    fullfilename = bst_fullfile(studiesDir, filenameRelative);
                    file_move(fullfilename, [fullfilename, '.bak']);
                end  
            case 'matrix'
                % Try to load headmodel info
                matrixInfo = io_getMatrixInfo(filenameRelative);
                % If a data file was found : copy headmodel information
                if ~isempty(matrixInfo)
                    sStudy(1).Matrix(end+1) = matrixInfo;
                end
            case 'image'
                [fPath, fBase, fExt] = bst_fileparts(filenameRelative);
                sStudy(1).Image(end+1) = struct('FileName', filenameRelative, ...
                                                'Comment',  [fBase, fExt]);
            case 'videolink'
                % Load file info
                try
                    % Try to load information
                    warning off MATLAB:load:variableNotFound
                    infoMat = load(bst_fullfile(studiesDir, filenameRelative), 'Comment');
                    warning on MATLAB:load:variableNotFound
                    fileComment = infoMat.Comment;
                catch
                    [fPath, fBase, fExt] = bst_fileparts(filenameRelative);
                    fileComment = [fBase, fExt];
                end
                % Create structure
                sStudy(1).Image(end+1) = struct('FileName', filenameRelative, ...
                                                'Comment',  fileComment);
        end
    end
end
% Set progress bar to the end
if isProgressBar
    bst_progress('set', round(startValue + sizeProgress));
end

% Select study defaults in the processed files
if ~isempty(studyMat)
    % HeadModel : last file
    if ~isempty(sStudy(1).HeadModel)
        sStudy(1).iHeadModel = length(sStudy(1).HeadModel);
    else
        sStudy(1).iHeadModel = [];
    end
end

return




%% ===================================================================================
%  === HELPER FUNCTIONS ==============================================================
%  ===================================================================================
    % CHANNEL : Load channel*.mat file information from a relative filename
    % Return a Channel structure :
    %    |- FileName
    %    |- Comment
    %    |- nbChannels
    
    % or an empty structure if error
    function sInfo = io_getChannelInfo(relativeFilename)
        sInfo = repmat(db_template('Channel'),0);
        % Check if the file exists, and load information fields
        if file_exist(bst_fullfile(studiesDir, relativeFilename))
            try
                % Try to load whole file
                warning off MATLAB:load:variableNotFound
                infoMat = load(bst_fullfile(studiesDir, relativeFilename),'Channel','Comment');
                warning on MATLAB:load:variableNotFound
                % Process all the channels, to count canals of each type
                sInfo(1).nbChannels = length(infoMat.Channel);
                channelList = infoMat.Channel;
                % Comment field
                if isfield(infoMat, 'Comment')
                    sInfo(1).Comment = infoMat.Comment; 
                else
                    % Build channel name
                    [tmp__, chComment] = bst_fileparts(relativeFilename);
                    chComment = lower(chComment);
                    chComment = strrep(chComment, '_channel', '');
                    chComment = strrep(chComment, 'channel_', '');
                    chComment = strrep(chComment, 'channel', '');
                    if ~isempty(chComment)
                        sInfo(1).Comment = chComment;
                    else
                        sInfo(1).Comment = sprintf('Channels ', sInfo(1).nbChannels);
                    end
                end
                if isempty(strfind(sInfo(1).Comment, ')'))
                    sInfo(1).Comment = sprintf('%s (%d)', sInfo(1).Comment, sInfo(1).nbChannels);
                end
                % Copy filename
                sInfo(1).FileName = relativeFilename;
                % Get all available modalities
                if ~isempty(channelList)
                    [sInfo(1).Modalities, sInfo(1).DisplayableSensorTypes] = channel_get_modalities(channelList);
                end
            catch
                % An error occured during the 'load' operation
                warning('Cannot open file ''%s''.', bst_fullfile(studiesDir, relativeFilename));
                sInfo = [];
            end
        else
            % File does not exist
            warning('File ''%s'' was not found.', bst_fullfile(studiesDir, relativeFilename));
            sInfo = [];
        end
    end


    % HEADMODEL : Load *headmodel*.mat file information from a relative filename
    % Return a Headmodel info structure :
    %    |- FileName
    %    |- Comment
    %    |- HeadModelType
    %    |- MEGMethod
    %    |- EEGMethod
    %    |- ECOGMethod
    %    |- SEEGMethod
    % or an empty structure if error
    function sInfo = io_getHeadModelInfo(relativeFilename)
        sInfo = repmat(db_template('HeadModel'),0);
        % Check if the file exists, and load information fields
        if file_exist(bst_fullfile(studiesDir, relativeFilename))
            try
                % Try to load information
                warning off MATLAB:load:variableNotFound
                infoMat = in_bst_headmodel(bst_fullfile(studiesDir, relativeFilename), 0, ...
                    'Comment', 'HeadModelType', 'MEGMethod', 'EEGMethod', 'ECOGMethod', 'SEEGMethod');
                warning on MATLAB:load:variableNotFound
                % Try to copy information
                if isfield(infoMat, 'Comment')
                    sInfo(1).Comment = infoMat.Comment;
                end
                if isfield(infoMat, 'HeadModelType')
                    sInfo(1).HeadModelType = infoMat.HeadModelType;
                end
                if isfield(infoMat, 'MEGMethod')
                    sInfo(1).MEGMethod   = infoMat.MEGMethod;
                end
                if isfield(infoMat, 'EEGMethod')
                    sInfo(1).EEGMethod   = infoMat.EEGMethod;
                end
                if isfield(infoMat, 'ECOGMethod')
                    sInfo(1).ECOGMethod   = infoMat.ECOGMethod;
                end
                if isfield(infoMat, 'SEEGMethod')
                    sInfo(1).SEEGMethod   = infoMat.SEEGMethod;
                end
                % Copy filename
                sInfo(1).FileName = relativeFilename;
            catch
                % An error occured during the 'load' operation
                warning('Cannot open file ''%s''.', bst_fullfile(studiesDir, relativeFilename));
                sInfo = [];
            end
        else
            % File does not exist
            warning('File ''%s'' was not found.', bst_fullfile(studiesDir, relativeFilename));
            sInfo = [];
        end
    end
    
    
    % DATA : Load *data*.mat file information from a relative filename
    % Return a Data info structure :
    %    |- FileName
    %    |- Comment
    % or an empty structure if error
    function sInfo = io_getDataInfo(relativeFilename)
        sInfo = repmat(db_template('Data'),0);
        % Check if the file exists, and load information fields
        if file_exist(bst_fullfile(studiesDir, relativeFilename))
            try
                % Try to load information
                infoMat = in_bst_data(bst_fullfile(studiesDir, relativeFilename), 'Comment', 'DataType');
                % Copy information (required fields)
                sInfo(1).Comment  = infoMat.Comment;
                sInfo(1).FileName = relativeFilename;
                sInfo(1).DataType = infoMat.DataType;
            catch
                % An error occured during the 'load' operation
                warning('Cannot open file ''%s''.', bst_fullfile(studiesDir, relativeFilename));
                sInfo = [];
            end
        else
            % File does not exist
            warning('File ''%s'' was not found.', bst_fullfile(studiesDir, relativeFilename));
            sInfo = [];
        end
    end
    

    % DIPOLES : Load *dipoles*.mat file information from a relative filename
    % Return a Dipoles info structure :
    %    |- FileName
    %    |- Comment
    %    |- DataFile
    % or an empty structure if error
    function sInfo = io_getDipolesInfo(relativeFilename)
        sInfo = repmat(db_template('Dipoles'),0);
        % Check if the file exists, and load information fields
        if file_exist(bst_fullfile(studiesDir, relativeFilename))
            try
                % Try to load information
                warning off MATLAB:load:variableNotFound
                infoMat = load(bst_fullfile(studiesDir, relativeFilename), 'Comment', 'DataFile');
                warning on MATLAB:load:variableNotFound
                % Check if data was loaded
                if ~all(isfield(infoMat, 'Comment'))
                    warning('File "%s" is not a valid result file. Appending ''.bak'' at the filename...', relativeFilename);
                    return
                end
                % Copy information (required fields)
                sInfo(1).Comment  = infoMat.Comment;
                sInfo(1).FileName = relativeFilename;
                sInfo(1).DataFile = infoMat.DataFile;
            catch
                % An error occured during the 'load' operation
                warning('Cannot open file ''%s''.', bst_fullfile(studiesDir, relativeFilename));
                sInfo = [];
            end
        else
            % File does not exist
            warning('File ''%s'' was not found.', bst_fullfile(studiesDir, relativeFilename));
            sInfo = [];
        end
    end



    % TIMEFREQ : Load *timefreq*.mat file information from a relative filename
    % Return a Timefreq info structure :
    %    |- FileName
    %    |- Comment
    %    |- DataFile
    % or an empty structure if error
    function sInfo = io_getTimefreqInfo(relativeFilename)
        sInfo = repmat(db_template('Timefreq'),0);
        % Check if the file exists, and load information fields
        if file_exist(bst_fullfile(studiesDir, relativeFilename))
            try
                % Try to load information
                warning off MATLAB:load:variableNotFound
                infoMat = load(bst_fullfile(studiesDir, relativeFilename), 'Comment', 'DataFile', 'DataType');
                warning on MATLAB:load:variableNotFound
                % Check if data was loaded
                if ~all(isfield(infoMat, 'Comment'))
                    warning('File "%s" is not a valid result file. Appending ''.bak'' at the filename...', relativeFilename);
                    return
                end
                % Copy information (required fields)
                sInfo(1).Comment  = infoMat.Comment;
                sInfo(1).FileName = relativeFilename;
                sInfo(1).DataFile = infoMat.DataFile;
                sInfo(1).DataType = infoMat.DataType;
            catch
                % An error occured during the 'load' operation
                warning('Cannot open file ''%s''.', bst_fullfile(studiesDir, relativeFilename));
                sInfo = [];
            end
        else
            % File does not exist
            warning('File ''%s'' was not found.', bst_fullfile(studiesDir, relativeFilename));
            sInfo = [];
        end
    end


    % STAT : Load pdata, presults, ptimefreq file information from a relative filename
    % Return a Data info structure :
    %    |- FileName
    %    |- Comment
    %    |- Type
    % or an empty structure if error
    function sInfo = io_getStatInfo(relativeFilename, fileType)
        sInfo = repmat(db_template('Stat'),0);
        % Check if the file exists, and load information fields
        if file_exist(bst_fullfile(studiesDir, relativeFilename))
            try
                % Try to load information
                warning off MATLAB:load:variableNotFound
                infoMat = load(bst_fullfile(studiesDir, relativeFilename), 'Comment', 'Type');
                warning on MATLAB:load:variableNotFound
                % Check if data was loaded
                if ~all(isfield(infoMat, {'Comment'}))
                    warning('File "%s" is not a valid stat file. Appending ''.bak'' at the filename...', relativeFilename);
                    return
                end
                % Copy information (required fields)
                sInfo(1).Comment    = infoMat.Comment;
                sInfo(1).FileName   = relativeFilename;
                % Type
                if isfield(infoMat, 'Type')
                    sInfo(1).Type = infoMat.Type;
                else
                    switch(fileType)
                        case 'pdata',      sInfo(1).Type = 'data';
                        case 'presults',   sInfo(1).Type = 'results';
                        case 'ptimefreq',  sInfo(1).Type = 'timefreq';
                        case 'pmatrix',    sInfo(1).Type = 'matrix';
                    end
                end
            catch
                % An error occured during the 'load' operation
                warning('Cannot open file ''%s''.', bst_fullfile(studiesDir, relativeFilename));
                sInfo = [];
            end
        else
            % File does not exist
            warning('File ''%s'' was not found.', bst_fullfile(studiesDir, relativeFilename));
            sInfo = [];
        end
    end
    
   
    % RESULT : Load *result*.mat file information from a relative filename
    % Return a Result info structure :
    %    |- FileName
    %    |- Comment
    %    |- DataFile
    % or an empty structure if error
    function sInfo = io_getResultInfo(relativeFilename)
        sInfo = repmat(db_template('Results'),0);
        % Check if the file exists, and load information fields
        if file_exist(bst_fullfile(studiesDir, relativeFilename))
            try
                % Try to load information
                warning off MATLAB:load:variableNotFound
                infoMat = load(bst_fullfile(studiesDir, relativeFilename), 'Comment', 'DataFile', 'HeadModelType');
                warning on MATLAB:load:variableNotFound
                % Check if data was loaded
                if ~all(isfield(infoMat, {'DataFile', 'Comment'}))
                    warning('File "%s" is not a valid result file. Appending ''.bak'' at the filename...', relativeFilename);
                    return
                end
                % Create results structure
                sInfo(1).Comment  = infoMat.Comment;
                sInfo(1).DataFile = infoMat.DataFile;
                sInfo(1).FileName = relativeFilename;
                if isfield(infoMat, 'HeadModelType') && ~isempty(infoMat.HeadModelType)
                    sInfo(1).HeadModelType = infoMat.HeadModelType;
                else
                    sInfo(1).HeadModelType = 'surface';
                end
            catch
                % An error occured during the 'load' operation
                warning('Cannot open file ''%s''.', bst_fullfile(studiesDir, relativeFilename));
                sInfo = [];
            end
        else
            % File does not exist
            warning('File ''%s'' was not found.', bst_fullfile(studiesDir, relativeFilename));
            sInfo = [];
        end
    end  


    % NOISECOV : Load *noisecov*.mat file information from a relative filename
    % Return a NoiseCov info structure :
    %    |- FileName
    %    |- Comment
    % or an empty structure if error
    function sInfo = io_getNoisecovInfo(relativeFilename)
        sInfo = repmat(db_template('NoiseCov'),0);
        % Check if the file exists, and load information fields
        if file_exist(bst_fullfile(studiesDir, relativeFilename))
            try
                % Try to load information
                warning off MATLAB:load:variableNotFound
                infoMat = load(bst_fullfile(studiesDir, relativeFilename), 'Comment');
                warning on MATLAB:load:variableNotFound
                % Check if data was loaded
                if ~all(isfield(infoMat, {'Comment'}))
                    warning('File "%s" is not a valid brainstorm file. Appending ''.bak'' at the filename...', relativeFilename);
                    return
                end
                % Create results structure
                sInfo(1).Comment  = infoMat.Comment;
                sInfo(1).FileName = relativeFilename;
            catch
                % An error occured during the 'load' operation
                warning('Cannot open file ''%s''.', bst_fullfile(studiesDir, relativeFilename));
                sInfo = [];
            end
        else
            % File does not exist
            warning('File ''%s'' was not found.', bst_fullfile(studiesDir, relativeFilename));
            sInfo = [];
        end
    end  

    % MATRIX : Load *matrix*.mat file information from a relative filename
    % Return a Matrix info structure :
    %    |- FileName
    %    |- Comment
    % or an empty structure if error
    function sInfo = io_getMatrixInfo(relativeFilename)
        sInfo = repmat(db_template('Matrix'),0);
        % Check if the file exists, and load information fields
        if file_exist(bst_fullfile(studiesDir, relativeFilename))
            try
                % Try to load information
                warning off MATLAB:load:variableNotFound
                infoMat = load(bst_fullfile(studiesDir, relativeFilename), 'Comment');
                warning on MATLAB:load:variableNotFound
                % Check if data was loaded
                if ~all(isfield(infoMat, {'Comment'}))
                    warning('File "%s" is not a valid brainstorm file. Appending ''.bak'' at the filename...', relativeFilename);
                    return
                end
                % Create results structure
                sInfo(1).Comment  = infoMat.Comment;
                sInfo(1).FileName = relativeFilename;
            catch
                % An error occured during the 'load' operation
                warning('Cannot open file ''%s''.', bst_fullfile(studiesDir, relativeFilename));
                sInfo = [];
            end
        else
            % File does not exist
            warning('File ''%s'' was not found.', bst_fullfile(studiesDir, relativeFilename));
            sInfo = [];
        end
    end

end












