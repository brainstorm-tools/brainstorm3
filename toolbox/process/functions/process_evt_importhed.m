function varargout = process_evt_importhed(varargin)
% PROCESS_EVT_IMPORTHED: Import HED tags from a JSON sidecar to Events in Data
%
% USAGE:  OutputFiles = process_evt_importhed('Run', sProcess, sInput)

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
% Authors: Anna Zaidi, 2024
%          Raymundo Cassani, 2025

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    sProcess.Comment     = 'Import HED tags (BIDS _events.json)';
    sProcess.FileTag     = [];
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 65;
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'raw', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % JSON side car file
    SelectOptions1 = {...
        '', ...                               % Filename
        '', ...                               % FileFormat
        'open', ...                           % Dialog type: {open,save}
        'Import HED JSON sidecar...', ...     % Window title
        'ImportEvents', ...                   % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                         % Selection mode: {single,multiple}
        'files', ...                          % Selection mode: {files,dirs,files_and_dirs}
        {{'_events.json'}, {'HED tags (*_events.json)'}, 'JSON'}, ... % Get all the available file formats
        ''};
    sProcess.options.sidecar.Type    = 'filename';
    sProcess.options.sidecar.Comment = 'JSON sidecar';
    sProcess.options.sidecar.Value   = SelectOptions1;
    % TSV file
    SelectOptions2 = {...
        '', ...                               % Filename
        '', ...                               % FileFormat
        'open', ...                           % Dialog type: {open,save}
        'Import HED JSON sidecar...', ...     % Window title
        'ImportEvents', ...                   % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                         % Selection mode: {single,multiple}
        'files', ...                          % Selection mode: {files,dirs,files_and_dirs}
        {{'_events.tsv'}, {'BIDS events (*_events.tsv)'}, 'BIDS'}, ...
        ''};
    sProcess.options.evtfile.Type    = 'filename';
    sProcess.options.evtfile.Comment = 'TSV file (Optional)';
    sProcess.options.evtfile.Value   = SelectOptions2;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFile = Run(sProcess, sInput)
    OutputFile = sInput.FileName;
    % ===== GET OPTIONS =====
    jsonFile = sProcess.options.sidecar.Value{1};
    if isempty(jsonFile)
        bst_report('Error', sProcess, sInput, 'JSON file was not provided');
        return
    elseif ~exist(jsonFile,'file')
        bst_report('Error', sProcess, sInput, ['JSON file does not exist', 10, jsonFile]);
        return
    end
    tsvFile = sProcess.options.evtfile.Value{1};
    % ===== GET EVENTS TO PROCESS =====
    isRaw = strcmpi(sInput.FileType, 'raw');
    if isRaw
        DataMat = in_bst_data(sInput.FileName, 'F', 'History');
        sEvents = DataMat.F.events;
    else
        DataMat = in_bst_data(sInput.FileName, 'Events', 'Time', 'History');
        sEvents = DataMat.Events;
    end
    if isempty(sEvents)
        bst_report('Warning', sProcess, sInput, 'There are not events in input file');
        return
    end

    % ===== ADD HED TAGS TO EVENTS =====
    % Decode JSON file
    [hedEvtNames, hedEvtHedTags, errMsg] = json2events(jsonFile, tsvFile);
    % Return if no HED tags or error
    if isempty(hedEvtNames) && isempty(hedEvtHedTags)
        if ~isempty(errMsg)
            bst_report('Error', sProcess, sInput, [errMsg, 10, jsonFile]);
        end
        return
    end
    % Add HEDs to Events in Data file
    for iHed = 1 : length(hedEvtNames)
        hedEvtName = hedEvtNames{iHed};
        iEvent = find(strcmp(hedEvtName, {sEvents.label}));
        if isempty(iEvent)
            continue
        end
        sEvents(iEvent).hedTags = hedEvtHedTags{iHed};
    end

    % ===== SAVE RESULT =====
    if isRaw
        DataMat.F.events = sEvents;
    else
        DataMat.Events = sEvents;
    end
    % Add history entry
    DataMat = bst_history('add', DataMat, 'events', sprintf('HED tags from %s were added to events', jsonFile));
    % Only save changes if something was change
    bst_save(file_fullpath(sInput.FileName), DataMat, [], 1);
end

function [hedEvtNames, hedEvtHedTags, errMsg] = json2events(jsonStr, tsvFile)
    if (nargin < 2)
        tsvFile = '';
    end
    hedEvtNames = [];
    hedEvtHedTags = [];
    errMsg = '';
    %  Load JSON sidecar
    evtSidecar = bst_jsondecode(jsonStr);
    % Find column with HED annotations
    hedColumn = IsHedJson(evtSidecar);
    if ~ismember(hedColumn, {'trial_type', 'event_type', 'value'})
        errMsg = 'HED: Only categorical HED annotations for column "trial_type", "event_type" or "value" are supported';
        return
    end
    sHed = evtSidecar.(hedColumn);
    % Set "Level" with "HED" if missing
    if ~isfield(sHed, 'Levels')
        sHed.Levels = sHed.HED;
    end
    evtKeys = fieldnames(sHed.Levels);
    % Map from 'value' to 'event.label' (using the _events.tsv file)
    valueMap = [];
    if strcmp(hedColumn, 'value') && ~isempty(tsvFile) && file_exist(tsvFile)
        [~, valueMap] = in_events_bids([], tsvFile);
        % Values as valid Matlab names (as JSON keys)
        validValues = cellfun(@matlab.lang.makeValidName, valueMap(:,1), 'UniformOutput', 0);
    end
    % Get event names and HED tags
    hedEvtNames   = repmat({''}, length(evtKeys), 1);
    hedEvtHedTags = repmat({''}, length(evtKeys), 1);
    for iEvtKey = 1 : length(evtKeys)
        % Get name
        if ~isempty(valueMap)
            % 'event.label' from 'value'
            evtNames = unique(valueMap(strcmp(validValues, evtKeys{iEvtKey}), 2));
            if (length(evtNames) == 1)
                hedEvtNames{iEvtKey} = evtNames{1};
            end
        else
            hedEvtNames{iEvtKey} = evtKeys{iEvtKey};
            % Replace with original name (Brainstorm-exported sidecars)
            % in case Matlab changed to be a valid fieldname on reading the JSON file
            if isfield(sHed.Levels, evtKeys{iEvtKey})
                levelStr = sHed.Levels.(evtKeys{iEvtKey});
                tmp = regexp(levelStr, '^Brainstorm event "(.*)"', 'tokens');
                if ~isempty(tmp) && length(tmp) == 1 && length(tmp{1}) == 1 && strcmp(evtKeys{iEvtKey}, matlab.lang.makeValidName(tmp{1}{1}))
                    hedEvtNames{iEvtKey} = tmp{1}{1};
                end
            end
        end
        % Get HED tags
        hedEvtHedTags{iEvtKey} = parsHedStr(sHed.HED.(evtKeys{iEvtKey}));
    end
end

function hedTags = parsHedStr(hedStr)
% Parse HED tags, taking into account tag-groups (HED tags within parentheses)
    hedStr = [hedStr, ','];
    hedTags = {};
    index   = 1;
    nOpen   = 0;
    for ic = 1 : length(hedStr)
        if hedStr(ic) == ','
            if nOpen == 0
                hedTags{end+1} = hedStr(index:ic-1);
                index = ic + 1;
            end
        elseif hedStr(ic) == '('
            nOpen = nOpen + 1;
        elseif hedStr(ic) == ')'
            nOpen = nOpen - 1;
        else
            % Continue scanning
        end
    end
    % Remove empty spaces
    hedTags = strtrim(hedTags);
end

function hedColumn = IsHedJson(jsonStruct)
    hedColumn = '';
    if ~isstruct(jsonStruct)
        return
    end
    colNames = fields(jsonStruct);
    for iCol = 1 : length(colNames)
        if isfield(jsonStruct, colNames{iCol}) && isstruct(jsonStruct.(colNames{iCol})) && ...
                isfield(jsonStruct.(colNames{iCol}), 'HED') && isstruct(jsonStruct.(colNames{iCol}).HED)
            hedColumn = colNames{iCol};
            break
        end
    end
end
