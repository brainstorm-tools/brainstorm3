function varargout = process_group_by_hed(varargin)

    eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description of the process
    sProcess.Comment = 'Group Events by HED Tags';
    sProcess.Category = 'Custom';
    sProcess.SubGroup = 'User';
    sProcess.Index = 1002; 
    sProcess.isSeparator = 1;

    % Define the input and output types
    sProcess.InputTypes = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs = 1;
    sProcess.nMinFiles = 1;

    % Add options for user configuration 
    sProcess.options.showOutput.Comment = 'Display grouped events in a message box';
    sProcess.options.showOutput.Type = 'checkbox';
    sProcess.options.showOutput.Value = 1;
end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end

%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput)
    % Initialize output file list
    OutputFiles = {};

    % Check for exactly one input file
    if length(sInput) ~= 1
        bst_report('Error', sProcess, sInput, 'This process requires exactly one input file.');
        return;
    end

    % Load the input data structure
    DataStruct = in_bst_data(sInput.FileName);
    if ~isfield(DataStruct, 'Events') || isempty(DataStruct.Events)
        bst_report('Error', sProcess, sInput, 'No events found in the data.');
        return;
    end

    % Extract events
    events = DataStruct.Events;

    % Group events by HED tags
    try
        groupedEvents = groupEventsByHEDTags(events);
    catch ME
        bst_report('Error', sProcess, sInput, ['Error grouping events: ' ME.message]);
        return;
    end

    % Optionally display grouped events
    if sProcess.options.showOutput.Value
        DisplayGroupedEvents(groupedEvents);
    end

    % No output modification needed; return input file
    OutputFiles{1} = sInput.FileName;
end

function groupedEvents = groupEventsByHEDTags(events)
    % Groups events based on their HED tags
    %
    % Input:
    %   events - Array of event structures with HED tags
    % Output:
    %   groupedEvents - Struct where each field is a unique HED tag, and its
    %                   value is an array of event indices

    tagMap = containers.Map('KeyType', 'char', 'ValueType', 'any');

    for i = 1:length(events)
        % Extract the HED tags for this event
        if ~isfield(events(i), 'hedTags') || isempty(events(i).hedTags)
            continue; 
        end

        % Assume hedTags is a comma-separated string; split into individual tags
        hedTags = strsplit(events(i).hedTags, ',');
        hedTags = strtrim(hedTags); 

        % Group by each tag
        for j = 1:length(hedTags)
            tag = hedTags{j};
            if ~isKey(tagMap, tag)
                tagMap(tag) = []; % Initialize empty group
            end
            tagMap(tag) = [tagMap(tag), i]; % Add event index to group
        end
    end

    % Convert map to struct for easier access
    groupedEvents = struct();
    tagKeys = keys(tagMap);
    for k = 1:length(tagKeys)
        groupedEvents.(matlab.lang.makeValidName(tagKeys{k})) = tagMap(tagKeys{k});
    end
end

function DisplayGroupedEvents(groupedEvents)
    % Display grouped events in a message box
    msg = 'Grouped Events by HED Tags:\n';
    tagNames = fieldnames(groupedEvents);
    for i = 1:length(tagNames)
        msg = sprintf('%s\n%s: [%s]', msg, tagNames{i}, num2str(groupedEvents.(tagNames{i})));
    end
    msgbox(msg, 'Grouped Events', 'help');
end
