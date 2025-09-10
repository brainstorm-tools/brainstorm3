function varargout = process_evt_importhed(varargin)
% PROCESS_EVT_IMPORTHED: Import HEDs from File
% USAGE: OutputFile = process_evt_importhed('Run', sProcess, sInput);

    % === DO NOT EDIT BELOW ===
    eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    sProcess.Comment     = 'Import HED sidecar';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 42.5;
    sProcess.Description = 'Read a HED JSON sidecar and attach tags to events';
    sProcess.InputTypes  = {'data','raw','matrix'};
    sProcess.OutputTypes = {'data','raw','matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    % --- Option: select JSON sidecar ---
    SelectOptions = {...
        '', '', 'open', ...
        'Select HED sidecar JSON...', ...
        'HED_JSON', 'single', 'files', ...
        {{'.json'}, 'JSON sidecar files (*.json)', ''}, ...
        {}...
    };
    sProcess.options.sidecar.Comment = 'HED sidecar JSON file:';
    sProcess.options.sidecar.Type    = 'filename';
    sProcess.options.sidecar.Value   = SelectOptions;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFile = Run(sProcess, sInput) %#ok<DEFNU>
    % Return the input file (we edit it in place)
    OutputFile = { sInput.FileName };

    % --- Load the JSON sidecar ---
    jsonFile = sProcess.options.sidecar.Value{1};
    if ~file_exist(jsonFile)
        bst_report('Error', sProcess, sInput, 'Sidecar JSON not found.');
        return;
    end
    try
        hedInfo = bst_jsondecode(jsonFile);
    catch
        bst_report('Error', sProcess, sInput, 'Unable to parse HED JSON.');
        return;
    end

    % --- Load the events from the raw/data file ---
    isRaw = strcmpi(sInput.FileType, 'raw');
    if isRaw
        DataMat = in_bst_data(sInput.FileName, 'F', 'History');
        sEvents = DataMat.F.events;
    else
        DataMat = in_bst_data(sInput.FileName, 'Events', 'History');
        sEvents = DataMat.Events;
    end

    % --- Attach HED tags ---
    isUpdated = false;
    for iEvt = 1:numel(sEvents)
        lbl = sEvents(iEvt).label;
        % look in BIDS‐style JSON: trial_type → Levels → <label> → HED
        if isfield(hedInfo, 'trial_type') && ...
           isfield(hedInfo.trial_type, 'Levels') && ...
           isfield(hedInfo.trial_type.Levels, lbl) && ...
           isfield(hedInfo.trial_type.Levels.(lbl), 'HED')
            newHED = hedInfo.trial_type.Levels.(lbl).HED;
        else
            newHED = '';
        end
        % only overwrite if changed/missing
        if ~isfield(sEvents(iEvt), 'hedTags') || ~isequal(sEvents(iEvt).hedTags, newHED)
            sEvents(iEvt).hedTags = newHED;
            isUpdated = true;
        end
    end

    if isUpdated
        if isRaw
            DataMat.F.events = sEvents;
        else
            DataMat.Events = sEvents;
        end
        DataMat = bst_history('add', DataMat, 'HED', ...
                   sprintf('Imported HED sidecar: %s', file_short(jsonFile)));
        bst_save(file_fullpath(sInput.FileName), DataMat, 'v6', 1);
    end
end
