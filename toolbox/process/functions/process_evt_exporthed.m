function varargout = process_evt_exporthed(varargin)
% PROCESS_EVT_EXPORTHED: Export HED tags to a JSON sidecar file
% USAGE:  OutputFiles = process_evt_exporthed('Run', sProcess, sInput);

    % === DO NOT EDIT BELOW ===
    eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    sProcess.Comment     = 'Export HEDs to File';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 1003;
    sProcess.Description = 'Write a HED JSON sidecar from the event tags';
    sProcess.InputTypes  = {'data','raw','matrix'};
    sProcess.OutputTypes = {'data','raw','matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    % --- Option: choose output JSON sidecar ---
    SaveOptions = { ...
        '', '', 'save', ...                         % mode = save
        'Select output HED sidecar file...', ...    % dialog title
        'HED_JSON', 'single', 'files', ...
        {{'.json'}, 'JSON sidecar files (*.json)'}, ...
        {} ...
    };
    sProcess.options.sidecar.Comment = 'Output HED sidecar JSON file:';
    sProcess.options.sidecar.Type    = 'filename';
    sProcess.options.sidecar.Value   = SaveOptions;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFile = Run(sProcess, sInput) %#ok<DEFNU>
    OutputFile = { sInput.FileName };

    % File to write
    jsonFile = sProcess.options.sidecar.Value{1};
    if isempty(jsonFile)
        bst_report('Error', sProcess, sInput, 'No output JSON file specified.');
        return;
    end

    % If it already exists, ask before overwriting
    if file_exist(jsonFile)
        if ~java_dialog('confirm', ...
                ['File already exists: ', file_short(jsonFile), char(10), 'Overwrite?'], ...
                'Export HED sidecar')
            bst_report('Warning', sProcess, sInput, 'Export canceled by user.');
            return;
        end
    end

    % Build the HED JSON skeleton
    hedInfo = struct();
    hedInfo.onset    = struct(...
        'Description', 'Time at which the event occurred, in seconds.', ...
        'Units',       'seconds' ...
    );
    hedInfo.duration = struct(...
        'Description', 'Duration of the event, in seconds.', ...
        'Units',       'seconds' ...
    );
    hedInfo.trial_type            = struct();
    hedInfo.trial_type.Description = 'Type of trial.';
    hedInfo.trial_type.Levels      = struct();

    % Load your events
    isRaw = strcmpi(sInput.FileType, 'raw');
    if isRaw
        DataMat = in_bst_data(sInput.FileName, 'F', 'History');
        sEvents = DataMat.F.events;
    else
        DataMat = in_bst_data(sInput.FileName, 'Events', 'History');
        sEvents = DataMat.Events;
    end

    % Collect HED tags for each event label
    for iEvt = 1:numel(sEvents)
        lbl = sEvents(iEvt).label;
        if isfield(sEvents(iEvt), 'hedTags')
            h = sEvents(iEvt).hedTags;
        else
            h = '';
        end
        % Create a sub‐struct with the HED string
        hedInfo.trial_type.Levels.(lbl) = struct('HED', h);
    end

    % Serialize and write JSON
    try
        jsonText = bst_jsonencode(hedInfo);
        fid = fopen(jsonFile, 'w');
        fprintf(fid, '%s', jsonText);
        fclose(fid);
    catch ME
        bst_report('Error', sProcess, sInput, ['Failed to write JSON: ' ME.message]);
        return;
    end

    bst_report('Info', sProcess, sInput, ['Exported HED sidecar: ' file_short(jsonFile)]);
end
