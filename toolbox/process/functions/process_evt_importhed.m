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
    SelectOptions = {...
        '', ...                               % Filename
        '', ...                               % FileFormat
        'open', ...                           % Dialog type: {open,save}
        'Import HED JSON sidecar...', ...     % Window title
        'ImportData', ...                     % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                         % Selection mode: {single,multiple}
        'files', ...                          % Selection mode: {files,dirs,files_and_dirs}
        {{'_events.json'}, {'HED tags (*_events.json)'}, 'JSON'}, ... % Get all the available file formats
        ''};
    sProcess.options.sidecar.Type    = 'filename';
    sProcess.options.sidecar.Comment = 'JSON sidecar';
    sProcess.options.sidecar.Value   = SelectOptions;
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
    % Parse JSON file
    fid = fopen(jsonFile, 'r');
    if (fid < 0)
        error(['Cannot open JSON file: ' jsonFile]);
    end
    % Read file
    jsonFile = fread(fid, [1, Inf], '*char');
    % Close file
    fclose(fid);
    % Decode JSON string
    [hedEvtNames, hedEvtHedTags] = json2events(jsonFile);
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
    DataMat = bst_history('add', DataMat, 'events', sprintf('HED tags from % were added to events', jsonFile));
    % Only save changes if something was change
    bst_save(file_fullpath(sInput.FileName), DataMat, [], 1);
end

function [hedEvtNames, hedEvtHedTags] = json2events(jsonStr, isOnlyHed)
    if nargin < 2 || isempty(isOnlyHed)
        isOnlyHed = 0;
    end
    %  Load JSON sidecar
    evtSidecar = bst_jsondecode(jsonStr);
    % Find field with HED
    evtSidecarFields = fieldnames(evtSidecar);
    if ismember('trial_type', evtSidecarFields)
        fieldEvtName = 'trial_type';
    elseif ismember('event_type', evtSidecarFields)
        fieldEvtName = 'event_type';
    else
        bst_error('JSON file should annotate events in column "trial_type" or "event_type"');
        return
    end
    sHed = evtSidecar.(fieldEvtName);
    % Replace "Level" with "HED" if only HED
    if isOnlyHed
        sHed.Levels = sHed.HED;
    end
    % Must contain 'Levels' and 'HED'
    if ~all(ismember({'Levels', 'HED'}, fieldnames(sHed)))
        bst_error('JSON file should the fields "Levels" and "HED"');
        return
    end
    % One HED for each Level
    if ~all(ismember(fieldnames(sHed.Levels), fieldnames(sHed.HED)))
        bst_error('JSON file should the same keynames for "Levels" and "HED"');
        return
    end
    evtKeys = fieldnames(sHed.Levels);
    % Get event names and HED tags
    hedEvtNames   = repmat({''}, length(evtKeys), 1);
    hedEvtHedTags = repmat({''}, length(evtKeys), 1);
    for iEvtKey = 1 : length(evtKeys)
        % Get name
        hedEvtNames{iEvtKey} = evtKeys{iEvtKey};
        % Replace with original name, in case Matlab changed to be a valid fieldname on reading the JSON file
        levelStr = sHed.Levels.(evtKeys{iEvtKey});
        tmp = regexp(levelStr, '^Brainstorm event "(.*)"', 'tokens');
        if ~isempty(tmp) && length(tmp) == 1 && length(tmp{1}) == 1 && strcmp(evtKeys{iEvtKey}, matlab.lang.makeValidName(tmp{1}{1}))
            hedEvtNames{iEvtKey} = tmp{1}{1};
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