function varargout = process_evt_nested( varargin )
% process_evt_nested: Combine nested events based on the nesting events.
%
% USAGE:  OutputFiles = process_evt_nested('Run', sProcess, sInputs)

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
% Authors: Edouard Delaire, 2026
%          Raymundo Cassani, 2026

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() 
    % Description the process
    sProcess.Comment     = 'Combine nested events';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 52.2;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw', 'matrix'};
    sProcess.OutputTypes = {'data', 'raw', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    % Event operation
    sProcess.options.label1.Comment = ['<HTML><B>Operation</B><BR>', ...
                                       '<FONT color=#7F7F7F>Operation between nested events <B>A</B>, and extended nesting events <B>B</B></FONT>' ...
                                       '</HTML>'];
    sProcess.options.label1.Type    = 'label';

    sProcess.options.method.Comment = { ['Intersection<BR>', ...
                                          '<FONT color=#7F7F7F>Create event <B>A^B</B> for occurrences of <B>A</B> during <B>B</B></FONT><BR>'], ...
                                        ['Difference<BR>' ...
                                          '<FONT color=#7F7F7F>Create event <B>A-B</B> for occurrences of <B>A</B> outside of <B>B</B></FONT><BR>'] ; ...
                                        'intersection', 'difference'};
    sProcess.options.method.Type    = 'radio_label';
    sProcess.options.method.Value   = 'intersection';
    % Events
    sProcess.options.label2.Comment = ['<B>Events</B><BR>', ...
                                       '<FONT color=#7F7F7F>(Separate multiple events using comma)</FONT><BR>'];
    sProcess.options.label2.Type    = 'label';
    % Nested events
    sProcess.options.nested.Comment = 'Events A';
    sProcess.options.nested.Type    = 'text';
    sProcess.options.nested.Value   = '';
    % Nesting events
    sProcess.options.nesting.Comment = 'Events B';
    sProcess.options.nesting.Type    = 'text';
    sProcess.options.nesting.Value   = '';


    sProcess.options.label3.Comment = ['<B>Partially nested occurrences</B><BR>', ...
                                       '<FONT color=#7F7F7F>How to handle extended occurrences of <B>A</B> partially nested in <B>B</B></FONT>'];
    sProcess.options.label3.Type = 'label';

    sProcess.options.partial_nesting.Comment = {['Ignore<BR>', ...
                                                 '<FONT color=#7F7F7F>Ignore <B>A</B> occurrences that are partially nested in <B>B</B></FONT><BR>'], ...
                                                ['Split<BR>', ...
                                                 '<FONT color=#7F7F7F>Keep only nested part of <B>A</B> occurrences that are partially nested in <B>B</B></FONT><BR>']; ...
                                                'ignore', 'split'};
    sProcess.options.partial_nesting.Type    = 'radio_label';
    sProcess.options.partial_nesting.Value   = 'ignore';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput)
    % Return all the input files
    OutputFiles = {sInput.FileName};

    % ===== GET OPTIONS =====
    % Combination string
    nestedEventNames  = cellfun(@(x) strtrim(x), strsplit(sProcess.options.nested.Value, ','),  'UniformOutput',  false);
    nestingEventNames = cellfun(@(x) strtrim(x), strsplit(sProcess.options.nesting.Value, ','), 'UniformOutput',  false);

    if isempty(nestedEventNames) || isempty(nestingEventNames)
        bst_report('Warning', sProcess, sInput, 'No events to combine. Skipping file...');
        return;
    end

    % Get operation
    method = sProcess.options.method.Value;
    % Get options
    partial_nesting = sProcess.options.partial_nesting.Value;

    % ===== GET FILE DESCRIPTOR =====
    isRaw = strcmpi(sInput.FileType, 'raw');
    % Load the raw file descriptor
    if isRaw
        DataMat = in_bst_data(sInput.FileName, {'Time', 'F'});
        sFile = DataMat.F;
        sFile.Time = DataMat.Time;
    else
        DataMat = in_bst_data(sInput.FileName, {'Time', 'Events'});
        sFile.Time   = DataMat.Time;
        sFile.events = DataMat.Events;
    end

    % If no markers are present in this file
    if isempty(sFile.events)
        bst_report('Warning', sProcess, sInput, 'This file does not contain any event. Skipping file...');
        return;
    end

    % Process only continuous files
    if isRaw && ~isempty(sFile.epochs)
        bst_report('Error', sProcess, sInput, 'This function can only process continuous recordings (no epochs).');
        OutputFiles = {};
        return;
    end

    % Check missing events
    [sNestedEvents,  missing_nested_events]  = GetEvents(sFile.events, nestedEventNames);
    [sNestingEvents, missing_nesting_events] = GetEvents(sFile.events, nestingEventNames);
    missing_events = union(missing_nested_events, missing_nesting_events);
    if isempty(sNestedEvents) || isempty(sNestingEvents)
        bst_report('Warning', sProcess, sInput, 'This file does not contain any event. Skipping file...');
        return;
    end
    if ~isempty(missing_events)
        bst_report('Warning', sProcess, sInput, sprintf('The following events were not found in the file: %s.', strjoin(missing_events, ', ')));
    end
    
    % Nesting events must be extended
    isExtended = IsExtendedEvent(sNestingEvents);
    if ~all(isExtended)
        bst_report('Error', sProcess, sInput, ...
                   sprintf('All nesting events must be extended events. The following events are simple events %s', ...
                           strjoin({sNestingEvents(~isExtended).label}, ', ')));
        OutputFiles = {};
        return;
    end
    
    % Create binary mask for the nesting events
    mask = Event2Mask(sFile.Time, sNestingEvents);
    for iEvent = 1:length(sNestedEvents)
        newEvents = ClassifyEvent(sFile.Time, sNestedEvents(iEvent), mask, sNestingEvents, partial_nesting, method);    
        for iNewEvent = 1:length(newEvents)
            % If there is at least one occurrence, add the event
            if length(newEvents(iNewEvent).epochs) >= 1
                sFile.events(end+1) = newEvents(iNewEvent);
            end
        end
    end

    % ===== SAVE RESULT =====
    % Report results
    if isRaw
        DataMat.F.events = sFile.events;
    else
        DataMat.Events = sFile.events;
    end
    bst_save(file_fullpath(sInput.FileName), DataMat, 'v6', 1);
end

function [events, missing_events] = GetEvents(sEvents, eventNames)
% Return the events based on their name
    event_idx = zeros(1, length(eventNames));
    missing_events = {};
    for iEvt = 1:length(eventNames)
        idx = find(strcmp({sEvents.label}, eventNames{iEvt}));
        if isempty(idx)
            missing_events{end+1} =  eventNames{iEvt};
            continue;
        end
        event_idx(iEvt) = idx;
    end
    event_idx = event_idx(event_idx > 0);
    events = sEvents(event_idx);
end

function mask = Event2Mask(Time, sEvents)
% Create a binary mask of the events.
    mask = false(length(sEvents), length(Time));
    isExtended = IsExtendedEvent(sEvents);
    for iEvt = 1:length(sEvents)
        for iTime = 1:size(sEvents(iEvt).times, 2)
            if isExtended(iEvt)
                idx_time = panel_time('GetTimeIndices', Time, sEvents(iEvt).times(:, iTime));
            else
                [~, idx_time] = min(abs(Time - sEvents(iEvt).times(1, iTime)));
            end

            mask(iEvt, idx_time) = 1;
        end
    end

end

function event_time = Mask2Time(Time, mask)
% Find the event start and end from the mask.
% mask is a binary vector. The event starts at each transition from 0 to 1, and
% ends at each transition from 1 to 0.
    tmp = diff(mask); 
    start_segment = find(tmp == 1) + 1; 
    end_segment   = find(tmp == -1);
    if length(start_segment) ==  length(end_segment) -1
        start_segment = [1 start_segment];
    end     
    if length(start_segment) ==  length(end_segment) +1
        end_segment = [ end_segment length(Time)];
    end  
    event_time  = [ Time(start_segment) ;  Time(end_segment)  ];
end

function newEvents = CreateNewEvents(sNestedEvent, sNestingEvents, partial_nesting, method)
% Create (empty) new event to store results from the operation between nested and nesting events
    newEvents = repmat(db_template('event'), 1, 1 + length(sNestingEvents));

    switch method
        case 'intersection'
            separator = '^';
        case 'difference'
            separator = '-';
        otherwise
            error('Unknown opperation %s', method)
    end
    
    if IsExtendedEvent(sNestedEvent) && strcmpi(partial_nesting, 'split')
        suffix = '_partial';
    else
        suffix = '';
    end

    for iNesting = 1:length(sNestingEvents)
        newEvents(iNesting).label = sprintf('%s%s%s%s', sNestedEvent.label, separator, sNestingEvents(iNesting).label, suffix);
        newEvents(iNesting).color = MixColors(sNestedEvent.color, sNestingEvents(iNesting).color);
    end
    newEvents(end).label = sprintf('%s%s%s%s', sNestedEvent.label, separator, 'unknown', suffix);
    newEvents(end).color = [0, 0, 0];
end


function newEvents = ClassifyEvent(Time, sNestedEvent, mask, sNestingEvents, partial_nesting, method)
% Perform the operation ('method') between the sNestedEvent occurrences and sNestingEvents
%
% Example:
% out        |--------------------|     |----------| 
% inp               *    *            *         *
% inx             |----------|        |-----|          |---------|
% 
% ^  = Intersection
% -  = Differences
% _T = partial_nesting = split
% _F = partial_nesting = ignore
% 
% So the resulting events would be 
% inp^out           *    *                      *
% inx^out_T       |----------|          |---|          
% inx^out_F       |----------|
% 
% inp-out                             *          
% inx-out_T                           |-|              |---------|
% inx-out_F                                            |---------|

    newEvents = CreateNewEvents(sNestedEvent, sNestingEvents, partial_nesting, method);
    % Add one row to the mask for the other case 
    % Ensure that all time point belongs to one category
    isClasified = max(mask, [], 1);
    mask = [mask ; 1 - isClasified];
    
    % Simple nested event: Intersection and Difference
    if ~IsExtendedEvent(sNestedEvent)
        if strcmp(method, 'difference')
            mask = ~mask;
        end
        for iTime = 1:size(sNestedEvent.times, 2)
            [~, idx_time] = min(abs(Time - sNestedEvent.times(1, iTime)));
            % Find which nesting event is occurring at that time
            event_mask = mask(:, idx_time);
            iNewEvent = find(event_mask);
            % Assign occurrence to new event
            for ix = 1 : length(iNewEvent)
                newEvents(iNewEvent(ix)).times(end+1) = sNestedEvent.times(iTime);
                newEvents(iNewEvent(ix)).epochs(end+1) = 1;
            end
        end

    % Extended nested event: Intersection and Difference
    else
        % Generate binary mask for the nested event, then compute intersection
        nested_mask = Event2Mask(Time, sNestedEvent);

        % To compute the difference, we jut invert the mask
        if strcmp(method, 'difference')
            nested_mask = ~nested_mask;
        end
        
        % Compute intersection
        intersection = mask .* repmat(nested_mask, size(mask, 1), 1);

        % Remove nested event overlapping multiple nesting events
        if strcmp(partial_nesting, 'ignore')
            for iOccurance = 1:size(sNestedEvent.times, 2)
                idx_time = panel_time('GetTimeIndices', Time, sNestedEvent.times(:, iOccurance));

                event_mask = mask(:, idx_time);
                [~, iEvent] = max(event_mask, [], 1);
                iEvent = unique(iEvent);
            
                isOverlapping = length(iEvent) > 1;
                if isOverlapping
                    intersection(:, idx_time) = 0;
                end
            end
        end

        % Generate events
        for iEvent = 1:length(newEvents)
            new_time = Mask2Time(Time, intersection(iEvent, :));

            if isempty(new_time)
                continue;
            end

            newEvents(iEvent).times  = [newEvents(iEvent).times, new_time];
            newEvents(iEvent).epochs = [newEvents(iEvent).epochs , ones(size(new_time, 2), 1)];
        end
    end

    % Remove unclassified events
    newEvents = newEvents(1:length(sNestingEvents));
end

function isExtended = IsExtendedEvent(sEvents)
% IsExtendedEvent: Return whether the events sEvents are extended (true) or simple events.
% isExtended is a vector that is 1 x nEvents
    isExtended = false(1, length(sEvents));
    for iEvent = 1:length(sEvents)
        isExtended(iEvent) = size(sEvents(iEvent).times, 1) == 2;
    end
end

function mixed = MixColors(color1, color2, weight)
    % Blend two RGB colours ([0-1] range) in linear light.
    % weight = contribution of color2 (default 0.5).
    if nargin < 3
        weight = 0.5;
    end
    % Fallbacks if a colour is missing
    if isempty(color1), mixed = color2; return; end
    if isempty(color2), mixed = color1; return; end

    lin1 = SrgbToLinear(color1);
    lin2 = SrgbToLinear(color2);
    mixed = LinearToSrgb((1 - weight) * lin1 + weight * lin2);
end

function lin = SrgbToLinear(c)
    lin = c;
    mask = c <= 0.04045;
    lin(mask)  = c(mask) / 12.92;
    lin(~mask) = ((c(~mask) + 0.055) / 1.055) .^ 2.4;
end

function c = LinearToSrgb(lin)
    c = lin;
    mask = lin <= 0.0031308;
    c(mask)  = lin(mask) * 12.92;
    c(~mask) = 1.055 * lin(~mask) .^ (1/2.4) - 0.055;
end