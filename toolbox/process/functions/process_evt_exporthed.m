function varargout = process_evt_exporthed(varargin)
% - Always write event name column as 'trial_event' (per Brainstorm export)
% - Sidecar structure: "<trial_type/event_type>" : {Description, Levels, HED}

eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    sProcess.Comment     = 'Export HED (BIDS events)';
    sProcess.FileTag     = [];
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 1001;
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'raw', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    sProcess.options.outtsv.Type    = 'filename';
    sProcess.options.outtsv.Comment = 'Output _events.tsv';
    sProcess.options.outtsv.Value   = {[], '', 'save', 'TSV files (*.tsv)|*.tsv'};

    sProcess.options.sidecar.Type    = 'filename';
    sProcess.options.sidecar.Comment = 'Output events.json sidecar';
    sProcess.options.sidecar.Value   = {[], '', 'save', 'JSON files (*.json)|*.json'};
end

%% ===== FORMAT COMMENT =====
function str = FormatComment()
    str = ['Export events to BIDS with HED: writes "trial_event" column and JSON sidecar per HED quickstart.'];
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs)
    OutputFiles = {sInputs.FileName};

    outTsv = sProcess.options.outtsv.Value{1};
    outJson = sProcess.options.sidecar.Value{1};
    if isempty(outTsv), error('Provide output _events.tsv'); end
    if isempty(outJson)
        outJson = regexprep(outTsv, '_events\.tsv$', '_events.json');
    end

    % --- Load Brainstorm file
    sMat = in_bst(sInputs.FileName, 'F');
    if ~isfield(sMat,'Events') || isempty(sMat.Events)
        error('No events to export.');
    end
    E = sMat.Events;

    % --- Flatten to BIDS table
    % with columns: onset, duration, trial_event, HED
    onset = [];
    duration = [];
    trial_event = strings(0,1);
    hedCol = strings(0,1);

    for k = 1:numel(E)
        times = E(k).times; % 2 x N
        n = size(times,2);
        onset    = [onset;    times(1,:)'];
        duration = [duration; max(0, times(2,:)' - times(1,:)')];
        trial_event = [trial_event; repmat(string(E(k).label), n, 1)];
        if isfield(E(k),'hedTags') && numel(E(k).hedTags) == n
            hedCol = [hedCol; string(E(k).hedTags(:))];
        else
            hedCol = [hedCol; strings(n,1)];
        end
    end

    T = table(onset, duration, trial_event, hedCol, 'VariableNames', {'onset','duration','trial_event','HED'});

    % --- Write TSV (tab-separated, no quotes)
    writetable_tsv_noquotes(T, outTsv);

    % --- Build sidecar JSON per HED quickstart
    ls = unique(trial_event);
    Levels = struct();
    for i = 1:numel(uLevels)
        lv = char(uLevels(i));
        mask = (trial_event == uLevels(i));
        % If all HED are identical and nonempty, store at level; else leave empty
        uniqHed = unique(hedCol(mask));
        uniqHed = uniqHed(~(uniqHed=="" | ismissing(uniqHed)));
        lvlEntry = struct('Description', '', 'HED', '');
        if numel(uniqHed) == 1
            lvlEntry.HED = char(uniqHed);
        end
        Levels.(lv) = lvlEntry;
    end
    Sidecar = struct();
    Sidecar.trial_event = struct( ...
        'Description', 'Brainstorm event label exported as BIDS trial_event', ...
        'Levels', Levels, ...
        'HED', '' ...
    );

    % --- Write sidecar
    jsonStr = jsonencode(Sidecar, 'PrettyPrint', true);
    fid = fopen(outJson,'w'); fwrite(fid, jsonStr); fclose(fid);
end

% --------- helpers ----------
function writetable_tsv_noquotes(T, pathOut)
    fid = fopen(pathOut,'w');
    fprintf(fid, '%s\n', strjoin(T.Properties.VariableNames, '\t'));
    for r = 1:height(T)
        row = T{r,:};
        for c = 1:numel(row)
            val = row{c};
            if isstring(val) || ischar(val)
                txt = string(val);
            elseif isnumeric(val) && isscalar(val)
                txt = string(val);
            else
                txt = "";
            end
            if c < numel(row)
                fprintf(fid, '%s\t', txt);
            else
                fprintf(fid, '%s\n', txt);
            end
        end
    end
    fclose(fid);
end
