function varargout = process_evt_nested( varargin )
% process_evt_nested: Combine nested events based on the outer events.
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

    sProcess.options.inner_events.Comment = 'Event to classify (seperated by comma)';
    sProcess.options.inner_events.Type    = 'text';
    sProcess.options.inner_events.Value   = '';

    sProcess.options.outer_events.Comment = 'Classifying events (seperated by comma)';
    sProcess.options.outer_events.Type    = 'text';
    sProcess.options.outer_events.Value   = '';

    sProcess.options.label1.Comment = 'Method';
    sProcess.options.label1.Type = 'label';

    sProcess.options.method.Comment = { 'Interection: <FONT color=#7F7F7F>&nbsp;&nbsp;&nbsp; Todo :) </FONT>', ...
                                        'Difference: <FONT color=#7F7F7F>&nbsp;&nbsp;&nbsp; TODO </FONT>' ; ...
                                        'intersection', 'difference'};
    sProcess.options.method.Type    = 'radio_label';
    sProcess.options.method.Value   = 'intersection';


    sProcess.options.label2.Comment = 'Partial nesting. <FONT color=#7F7F7F>&nbsp;&nbsp;&nbsp; How to handle event with duration spanning multiple classssifying events </FONT>';
    sProcess.options.label2.Type = 'label';

    sProcess.options.partial_nesting.Comment = { 'Reject event: <FONT color=#7F7F7F>Remove event overlapping with multiple classifying events</FONT>', ...
                                                  'Split event: <FONT color=#7F7F7F>Split the event accros each classsifying event</FONT>' , ...
                                                    'reject', 'split'};
    sProcess.options.partial_nesting.Type    = 'radio_label';
    sProcess.options.partial_nesting.Value   = 'split';


end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput)
    % Return all the input files
    OutputFiles = {};   


    % ===== GET OPTIONS =====
    % Combination string
    innerEventsName = cellfun(@(x) strtrim(x),  strsplit(sProcess.options.inner_events.Value, ','),  'UniformOutput',  false);
    outerEventsName = cellfun(@(x) strtrim(x),  strsplit(sProcess.options.outer_events.Value, ','),  'UniformOutput',  false);

    if isempty(innerEventsName) || isempty(outerEventsName)
        bst_report('Warning', sProcess, sInput, 'No event to classsssify.');
        return;
    end

    % Method for partial nesting {'reject', 'split'}
    partial_nesting = sProcess.options.partial_nesting.Value;

    % Method
    method = sProcess.options.method.Value;

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
        sFile.epochs = [];
    end

    % Process only continuous files
    if ~isempty(sFile.epochs)
        bst_report('Error', sProcess, sInput, 'This function can only process continuous recordings (no epochs). Skipping File...');
        return;
    end

    % If no markers are present in this file
    if isempty(sFile.events)
        bst_report('Warning', sProcess, sInput, 'This file does not contain any event. skipping');
        return;
    end

    [sEventsInner, missing_events_inner] = getEvents(sFile.events, innerEventsName);
    [sEventsOuter, missing_events_outer] = getEvents(sFile.events, outerEventsName);

    missing_events = union(missing_events_inner, missing_events_outer);
    if ~isempty(missing_events)
        bst_report('Warning', sProcess, sInput, sprintf('The following events were not found in the file: %s.', strjoin(missing_events, ', ')));
    elseif isempty(sEventsInner) ||  isempty(sEventsOuter)
        bst_report('Warning', sProcess, sInput, 'This file does not contain any event. skipping');
        return;
    end
    
    isExtended = areEventExtended(sEventsOuter);
    if ~all(isExtended)
        bst_report('Error', sProcess, sInput, sprintf('All classifying events must be extended events. The following events are ssimple events %s', strjoin({sEventsOuter(~isExtended).label}, ', '  )));
        return;
    end
    
    % Create binary mask for the outer events
    mask = event2mask(sFile.Time, sEventsOuter);
    for iEvent = 1:length(sEventsInner)
        newEvents = classifyEvent(sFile.Time, sEventsInner(iEvent), mask, sEventsOuter, partial_nesting, method);
        sFile.events = [sFile.events , newEvents];
    end


    % ===== SAVE RESULT =====
    % Report results
    if isRaw
        DataMat.F = sFile;
    else
        DataMat.Events = sFile.events;
    end
    bst_save(file_fullpath(sInput.FileName), DataMat, 'v6', 1);


    % Return all the input files
    OutputFiles{end+1} = sInput.FileName;
end

function [events, missing_events] = getEvents(sEvents, eventNames)
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

function mask = event2mask(Time, sEvents)
% create a binary mask of the events. 

    mask = false(length(sEvents), length(Time));
    for iEvt = 1:length(sEvents)
    
        for iTime = 1:size(sEvents(iEvt).times, 2)
            idx_time = panel_time('GetTimeIndices', Time, sEvents(iEvt).times(:, iTime));
            mask(iEvt, idx_time) = 1;
        end
    end

end


function newEvents = createNewEvents(sEventsInner,  sEventsOuter,  partial_nesting, method)
    newEvents = repmat(db_template('event'), 1, 1 + length(sEventsOuter));

    switch method
        case 'intersection'
            separator = '^';
        case 'difference'
            separator = '^';
        otherwise
            error('Unknown opperation %', method)
    end
    
    if areEventExtended(sEventsInner)
        switch partial_nesting
            case 'split'
                suffix = '_T';
            case 'reject'
                suffix = '_F';
            otherwise
                error('Unknown partial nesting %', partial_nesting)
        end
    else
        suffix = '';
    end

    for iEvents = 1:length(sEventsOuter)
        newEvents(iEvents).label = sprintf('%s%s%s%s', sEventsInner.label, separator, sEventsOuter(iEvents).label, suffix);
        newEvents(iEvents).color = sEventsOuter(iEvents).color;
    end
    
    newEvents(end).label = sprintf('%s%s%s%s', sEventsInner.label, separator, 'unknown', suffix);
    newEvents(end).color = [0, 0, 0];
end


function newEvents = classifyEvent(Time, sEventsInner, mask, sEventsOuter, partial_nesting, method)
% classifyEvents
% out        |--------------------|     |----------| 
% inp               *    *            *         *
% inx             |----------|        |-----|          |---------|
% 
% ^  = Intersection
% -  = Differences
% _T = partial_nesting = split
% _F = partial_nesting = reject
% 
% So the resulting events would be 
% inp^out           *    *                      *
% inx^out_T       |----------|          |---|          
% inx^out_F       |----------|
% 
% inp-out                             *          
% inx-out_T                           |-|              |---------|
% inx-out_F                                            |---------|

    newEvents = createNewEvents(sEventsInner,  sEventsOuter,  partial_nesting, method);
    
    % Add one row to the mask for the other case 
    % Ensure that all time point belongs to one category
    isClasified = max(mask, [], 1);
    mask = [mask ; 1 - isClasified];
    
    % Compute each of the following 4 case separately 
    % (extended event = true/ false, operation = intersection / difference)

    isExtended = areEventExtended(sEventsInner);
    if strcmp(method, 'intersection') && ~isExtended
        for iTime = 1:size(sEventsInner.times, 2)
            [~, idx_time] = min(abs(Time - sEventsInner.times(1, iTime))); 
            
            % Find which classifying event is occurring at that time
            event_mask = mask(:, idx_time);
            [~, iEvent] = max(event_mask, [], 1);
            iEvent = unique(iEvent);

            % Assign time
            newEvents(iEvent).times(end+1) = sEventsInner.times(iTime);
            newEvents(iEvent).epochs(end+1) = 1;
        end
    elseif strcmp(method, 'intersection') && isExtended
        for iTime = 1:size(sEventsInner.times, 2)

            idx_time = panel_time('GetTimeIndices', Time, sEventsInner.times(:, iTime));

            event_mask = mask(:, idx_time);
            [~, iEvent] = max(event_mask, [], 1);
            iEvent = unique(iEvent);
            
            isOverlapping = any(sum(event_mask) ~= 1) || length(iEvent) > 1;
            
            if ~isOverlapping
                newEvents(iEvent).times(:, end+1) = sEventsInner.times(:, iTime);
                newEvents(iEvent).epochs(end+1) = 1;
            else
                if strcmp(partial_nesting, 'reject')
                    iEvent = length(sEventsOuter) + 1; 
    
                    newEvents(iEvent).times(:, end+1) = sEventsInner.times(:, iTime);
                    newEvents(iEvent).epochs(end+1) = 1;
                else
                    error('Todo: handle splitting')
                end
            end
        end
    elseif strcmp(method, 'difference') && ~isExtended
         % doesn't make sense
    elseif strcmp(method, 'difference') && isExtended
        % Todo
    else
        % Not possible
    end

    newEvents = newEvents(1:length(sEventsOuter));
end

function isExtended = areEventExtended(sEvents)
% areEventExtended: Return wether the events sEvents are extended (true) or
% simple events. isExtended is a vector that is 1 x nEvents

    isExtended = false(1, length(sEvents));
    for iEvent = 1:length(sEvents)
        isExtended(iEvent) = size(sEvents(iEvent).times, 1) == 2;
    end

end