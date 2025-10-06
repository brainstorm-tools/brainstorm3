function varargout = process_evt_importhed(varargin)
% - Event name column: use 'trial_type' if present, else 'event_type'
% - HED column: same rule (only one column is used)
% - Reads JSON sidecar to attach HED schema info if present

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    sProcess.Comment     = 'Import HED (BIDS events)';
    sProcess.FileTag     = [];
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 1000;
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'raw', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    sProcess.options.eventstsv.Type    = 'filename';
    sProcess.options.eventstsv.Comment = 'Path to _events.tsv';
    sProcess.options.eventstsv.Value   = {[], '', 'open', 'TSV files (*.tsv)|*.tsv'};

    sProcess.options.sidecar.Type    = 'filename';
    sProcess.options.sidecar.Comment = 'Optional events.json sidecar';
    sProcess.options.sidecar.Value   = {[], '', 'open', 'JSON files (*.json)|*.json'};
end


%% ===== FORMAT COMMENT =====
function str = FormatComment()
    str = ['Import BIDS events (+HED): uses trial\_type (fallback event\_type) for event names and HED column.'];
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs)
    OutputFiles = {sInputs.FileName};  
    % --- Read inputs
    eventsTsv = sProcess.options.eventstsv.Value{1};
    sidecar   = sProcess.options.sidecar.Value{1};
    if isempty(eventsTsv) || ~exist(eventsTsv,'file')
        error('events.tsv not found.');
    end

    % --- Parse TSV
    T = readtsv_as_table(eventsTsv);
    nameCol = pick_column(T, {'trial_type','event_type'});
    hedCol  = pick_column(T, {'trial_type','event_type'}); 
    onsetCol = pick_column(T, {'onset'});
    durCol   = pick_column(T, {'duration'}); 

    % --- Load JSON sidecar (optional)
    HedSidecar = struct();
    if ~isempty(sidecar) && exist(sidecar,'file')
        HedSidecar = jsondecode(fileread(sidecar));
    else
        guess = regexprep(eventsTsv, '_events\.tsv$', '_events.json');
        if exist(guess,'file')
            HedSidecar = jsondecode(fileread(guess));
        end
    end

    % --- Build Brainstorm events
    sMat = in_bst(sInputs.FileName, 'F');
    sEvents = [];
    if isfield(sMat,'Events') && ~isempty(sMat.Events), sEvents = sMat.Events; end

    names = string(T.(nameCol));
    onsets = double(T.(onsetCol));
    if ~isempty(durCol), durs = double(T.(durCol)); else, durs = zeros(size(onsets)); end

    % Derive list of unique Brainstorm event categories from trial_type/event_type
    evCats = unique(names(~ismissing(names)));
    for k = 1:numel(evCats)
        evName = char(evCats(k));
        idx = strcmp(names, evCats(k));
        times = [onsets(idx), onsets(idx) + durs(idx)]'; % 2 x N

        % Attach per-event HED strings if present in the chosen column + sidecar Levels/HED
        hedStrPerRow = strings(sum(idx),1);
        if isfield(T, hedCol)
            hedStrPerRow = string(T.(hedCol)(idx));
        end
        hedFromLevels = strings(sum(idx),1);
        if isstruct(HedSidecar) && isfield(HedSidecar, nameCol) ...
                && isfield(HedSidecar.(nameCol), 'Levels')
            lv = HedSidecar.(nameCol).Levels;
            % If the level matches evName and has HED content, add it
            if isfield(lv, evName)
                if isstruct(lv.(evName)) && isfield(lv.(evName),'HED')
                    hedFromLevels(:) = string(lv.(evName).HED);
                elseif ischar(lv.(evName)) || isstring(lv.(evName))
                    hedFromLevels(:) = string(lv.(evName));
                end
            end
        end
        finalHed = hedStrPerRow;
        hasEmpty = (finalHed=="" | ismissing(finalHed));
        finalHed(hasEmpty) = hedFromLevels(hasEmpty);

        % Build Brainstorm event struct (add custom field hedTags)
        sEvt = db_template('event');
        sEvt.label    = evName;
        sEvt.color    = [];            
        sEvt.epochs   = ones(1,sum(idx));
        sEvt.times    = times;
        sEvt.select   = 1;
        sEvt.channels = {};
        sEvt.notes    = repmat({''}, 1, sum(idx));
        sEvt.hedTags  = cellstr(finalHed);

        sEvents = [sEvents, sEvt]; 
    end

    % --- Save back
    sMat.Events = sEvents;
    bst_save(file_fullpath(sInputs.FileName), sMat, 'v6', 1);
end

% --------- helpers ----------
function T = readtsv_as_table(p)
    opts = detectImportOptions(p, 'FileType','text', 'Delimiter','\t', 'MissingRule','fill');
    opts = setvaropts(opts, opts.VariableNames, 'WhitespaceRule','preserve', 'EmptyFieldRule','auto');
    T = readtable(p, opts);
end

function col = pick_column(T, prefList)
    for i=1:numel(prefList)
        if any(strcmpi(prefList{i}, T.Properties.VariableNames))
            col = prefList{i};
            return;
        end
    end
    error('Required column not found: %s', strjoin(prefList, ' or '));
end
