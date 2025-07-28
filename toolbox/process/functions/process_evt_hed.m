function varargout = process_evt_hed(varargin)
% PROCESS_EVT_HED: Attach HED tags from sidecar JSON to imported events
% USAGE: OutputFiles = process_evt_hed('Run', sProcess, sInputs)
% This process reads the HED sidecar (.json) and populates S.Events(i).hedTags
% for each raw/data file in the protocol.

eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    sProcess.Comment     = 'Import HED sidecar';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 42.5;
    sProcess.InputTypes  = {'data','raw', 'matrix'};
    sProcess.OutputTypes = {'data','raw', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    SelectOptions = {...
        '', '', 'open', ...
        'Select HED sidecar JSON...', ...
        'HED_JSON', 'single', 'files', ...
        {{'.json'}, 'JSON sidecar files (*.json)', ''}, ...
        {}};

    sProcess.options.sidecar.Comment = 'HED sidecar JSON file:';
    sProcess.options.sidecar.Type    = 'filename';
    sProcess.options.sidecar.Value   = SelectOptions;
end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end

%% ===== RUN =====
function OutputFile = Run(sProcess, sInput)
    % Return all the input files
    OutputFile = {sInput.FileName};
    
    jsonFile = sProcess.options.sidecar.Value{1};
    if ~file_exist(jsonFile)
        bst_report('Error', sProcess, sInput, 'Sidecar JSON not found.');
        return;
    end
    
    % Read HEDs
    hedInfo = bst_jsondecode(jsonFile);

    % LOAD FILE
    % Get file descriptor
    isRaw = strcmpi(sInput.FileType, 'raw');
    % Load the raw file descriptor
    if isRaw
        DataMat = in_bst_data(sInput.FileName, 'F', 'History');
        sEvents = DataMat.F.events;
    else
        DataMat = in_bst_data(sInput.FileName, 'Events', 'History');
        sEvents = DataMat.Events;
    end

    % Add HED tags to each event
    isUpdated = 0;
    for iEvt = 1:numel(sEvents)
        key = sEvents(iEvt).label;
        if isfield(hedInfo.trial_type, 'Levels') && ...
           isfield(hedInfo.trial_type.Levels, key) && ...
           isfield(hedInfo.trial_type.Levels.(key), 'HED')
            sEvents(iEvt).hedTags = hedInfo.trial_type.Levels.(key).HED;
            isUpdated = 1;
        else
            sEvents(iEvt).hedTags = '';
        end
    end

    % ===== SAVE RESULT =====
    if isUpdated
        if isRaw
            DataMat.F.events = sEvents;
        else
            DataMat.Events = sEvents;
        end
        % Add history entry
        DataMat = bst_history('add', DataMat, 'HED', sprintf('Added HED to events %s', jsonFile));
        % Only save changes if something was change
        bst_save(file_fullpath(sInput.FileName), DataMat, 'v6', 1);
    end
end