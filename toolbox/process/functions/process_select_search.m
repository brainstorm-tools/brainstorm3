function varargout = process_select_search( varargin )
% PROCESS_SELECT_SEARCH: Keep only the files within the current selection that pass a given database search query.
%
% USAGE:  sProcess = process_select_search('GetDescription')
%                    process_select_search('Run', sProcess, sInputs)

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
% Authors: Martin Cousineau, 2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Select files: Search query';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 1014;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/SelectFiles';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import', 'raw', 'data', 'results', 'timefreq', 'matrix', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.OutputTypes = {'raw', 'data', 'results', 'timefreq', 'matrix', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    sProcess.isSeparator = 0;
    % Definition of the options
    % === TARGET
    sProcess.options.search.Comment = 'Search query: ';
    sProcess.options.search.Type    = 'text';
    sProcess.options.search.Value   = '';
    % INCLUDE BAD TRIALS
    sProcess.options.includebad.Comment = 'Include the bad trials';
    sProcess.options.includebad.Type    = 'checkbox';
    sProcess.options.includebad.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % Option: Search
    search = strtrim(sProcess.options.search.Value);
    if isempty(search)
        search = 'Not defined';
    end
    Comment = ['Select files using search query: ' search];
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % Get search
    search = sProcess.options.search.Value;
    if isempty(search)
        bst_report('Error', sProcess, [], 'Search query is not defined.');
        return
    end
    % Bad channels
    if isfield(sProcess.options, 'includebad') && isfield(sProcess.options.includebad, 'Value') && ~isempty(sProcess.options.includebad.Value)
        IncludeBad = sProcess.options.includebad.Value;
    else
        IncludeBad = 0;
    end
    
    % Convert search string to search structure
    try
        searchRoot = panel_search_database('StringToSearch', search);
    catch e
        bst_report('Error', sProcess, [], ['Invalid search syntax: ' e.message]);
        return;
    end
    
    % No input files: get all protocol files
    if isempty(sInputs) || (length(sInputs) == 1 && strcmp(sInputs.FileType, 'import'))
        [isRequired, FileTypes] = panel_search_database('GetRequiredFileTypes', searchRoot);
        if ~isRequired
            FileTypes = {};
        end
        sInputs = GetAllProtocolFiles(FileTypes, IncludeBad);
    end
    
    % Apply search
    iFiles = find(node_apply_search(searchRoot, {sInputs.FileType}, {sInputs.Comment}, {sInputs.FileName}, [sInputs.iStudy]));
    
    % Warning: nothing found
    if isempty(iFiles)
        bst_report('Error', sProcess, [], ['No files found for search: ' search]);
        return;
    end
    % Report information
    strReport = sprintf('Files selected for search "%s": %d/%d', search, length(iFiles), length(sInputs));
    bst_report('Info', sProcess, [], strReport);
    % Return only the filenames that passed the search
    OutputFiles = {sInputs(iFiles).FileName};
end

function sOutputs = GetAllProtocolFiles(FileTypes, IncludeBad)
    FileTypes = lower(FileTypes);
    sOutputs = repmat(struct('FileName', [], 'FileType', [], 'Comment', [], 'iStudy', 0), 0);
    % Get regular studies
    sProtocolStudies = bst_get('ProtocolStudies');
    sStudies = sProtocolStudies.Study;
    iStudies = 1:length(sProtocolStudies.Study);
    % Get common files folder
    sStudies = [sStudies, sProtocolStudies.DefaultStudy];
    iStudies = [iStudies, -3];
    % Get intra subject folder
    sStudies = [sStudies, sProtocolStudies.AnalysisStudy];
    iStudies = [iStudies, -2];
    
    iOutput = 1;
    for iStudy = 1:length(iStudies)
        % Type: Data
        if isempty(FileTypes) || ismember('data', FileTypes) || ismember('rawdata', FileTypes)
            sData = [sStudies(iStudy).Data];
            % Exclude bad trials
            if ~IncludeBad
                isBadTrial = logical([sData.BadTrial]);
                sData = sData(~isBadTrial);
            end
            % Get specific data type
            FileType = {sData.DataType};
            iRaw = strcmpi(FileType, 'raw');
            % Remove raw files if not required
            if ~isempty(FileTypes) && ~ismember('rawdata', FileTypes)
                sData = sData(~iRaw);
                SaveFiles('data');
            % Remove data files if not required
            elseif ~isempty(FileTypes) && ~ismember('data', FileTypes)
                sData = sData(iRaw);
                SaveFiles('rawdata');
            else
                FileType(iRaw) = {'rawdata'};
                FileType(~iRaw) = {'data'};
                SaveFiles(FileType, 0);
            end
        end
        
        % Type: Sources
        if isempty(FileTypes) || ismember('results', FileTypes)
            sData = [sStudies(iStudy).Result];
            % Exclude shared kernels
            isSharedKernel = cellfun(@isempty, {sData.DataFile}) & ~cellfun(@(c)isempty(strfind(c, 'KERNEL')), {sData.FileName});
            sData(isSharedKernel) = [];
            % Exclude bad trials
            if ~IncludeBad
                % Get the bad trials in these folders
                sDataRef = [sStudies(iStudy).Data];
                isBadRef = logical([sDataRef.BadTrial]);
                % Get the files to which the trials are attached
                DataRefFiles = {sData.DataFile};
                iDataFile = find(~cellfun(@isempty, DataRefFiles));
                % Find which results are attached to bad trials
                iBadTrial = find(ismember({sData(iDataFile).DataFile}, {sDataRef(isBadRef).FileName}));
                % Remove results attached to bad trials
                if ~isempty(iBadTrial)
                    sData(iDataFile(iBadTrial)) = [];
                end
            end
            SaveFiles('results');
        end
        
        % Type: Time-frequency
        if isempty(FileTypes) || ismember('timefreq', FileTypes)
            sData = [sStudies(iStudy).Timefreq];
            % Exclude bad trials
            if ~IncludeBad
                iBadTrial = [];
                % Check file by file
                for iTf = 1:length(sStudies(iStudy).Timefreq)
                    if isBadDataTrial(sStudies(iStudy).Timefreq(iTf).DataFile)
                        iBadTrial(end + 1) = iTf;
                    end
                end
                % Remove all the bad files
                if ~isempty(iBadTrial)
                    sData(iBadTrial) = [];
                end
            end
            SaveFiles('timefreq');
        end
        
        % Type: Matrix
        if isempty(FileTypes) || ismember('matrix', FileTypes)
            sData = [sStudies(iStudy).Matrix];
            SaveFiles('matrix');
        end
        
        % Type: Dipoles
        if isempty(FileTypes) || ismember('dipoles', FileTypes)
            sData = [sStudies(iStudy).Dipoles];
            SaveFiles('dipoles');
        end
        
        % Type: Statistics
        if isempty(FileTypes) || ismember('pdata', FileTypes) || ismember('presults', FileTypes) ...
                || ismember('ptimefreq', FileTypes) || ismember('pmatrix', FileTypes)
            sData = [sStudies(iStudy).Stat];
            FileType = strcat('p', {sData.Type});
            SaveFiles(FileType, 0);
        end
    end
    
    % Save files as sInput structure
    function SaveFiles(FileType, repeatType)
        if nargin < 2
            repeatType = ~iscell(FileType);
        end
        
        n = length(sData);
        if n == 0
            return;
        end
        [sOutputs(iOutput:iOutput+n-1).FileName] = deal(sData.FileName);
        [sOutputs(iOutput:iOutput+n-1).Comment]  = deal(sData.Comment);
        [sOutputs(iOutput:iOutput+n-1).iStudy]   = deal(iStudies(iStudy));
        if repeatType
            [sOutputs(iOutput:iOutput+n-1).FileType] = deal(FileType);
        else
            [sOutputs(iOutput:iOutput+n-1).FileType] = FileType{:};
        end
        iOutput = iOutput + n;
    end

    % Checks whether a given parent data file is a bad trial
    function isBad = isBadDataTrial(DataFile)
        isBad = 0;
        if isempty(DataFile)
            return;
        end
        DataType = file_gettype(DataFile);
        % Results: get DataFile
        if ismember(DataType, {'results','link'})
            [tmp__,tmp__,iRes] = bst_get('ResultsFile', DataFile, iStudies(iStudy));
            if ~isempty(iRes)
                DataFile = sStudies(iStudy).Result(iRes).DataFile;
            else
                DataFile = [];
            end
        elseif strcmpi(DataType, 'matrix')
            return;
        end
        % Check if bad trials
        if ~isempty(DataFile)
            % Get the associated data file
            [tmp__,tmp__,iData] = bst_get('DataFile', DataFile, iStudies(iStudy));
            % In the case of projected sources: the source file might not be in the same folder
            if isempty(iData)
                [sStudy_tmp,iStudy_tmp,iData] = bst_get('DataFile', DataFile);
                if ~isempty(iData) && sStudy_tmp.Data(iData).BadTrial
                    isBad = 1;
                end
            % Check if data file is bad
            elseif sStudies(iStudy).Data(iData).BadTrial
                isBad = 1;
            end
        end
    end
end
