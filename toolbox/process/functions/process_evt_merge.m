function varargout = process_evt_merge( varargin )
% PROCESS_EVT_RENAME: Rename an event.

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
% Authors: Francois Tadel, 2016-2022

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Duplicate / merge events';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 54;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/EventMarkers#Other_menus';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw', 'matrix'};
    sProcess.OutputTypes = {'data', 'raw', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Explanations
    sProcess.options.desc.Comment  = [...
        '<FONT COLOR="#707070"><I>Combine the input events and save them as a new event group.<BR>' ... 
        'To duplicate an event: select it in input and uncheck "delete".</I></FONT><BR><BR>'];
    sProcess.options.desc.Type     = 'label';
    % Event name
    sProcess.options.evtnames.Comment  = 'Events to copy (separated with commas): ';
    sProcess.options.evtnames.Type     = 'text';
    sProcess.options.evtnames.Value    = '';
    % New name
    sProcess.options.newname.Comment = 'New event name: ';
    sProcess.options.newname.Type    = 'text';
    sProcess.options.newname.Value   = '';
    % Delete original events
    sProcess.options.delete.Comment = 'Delete the original events';
    sProcess.options.delete.Type    = 'checkbox';
    sProcess.options.delete.Value   = 1; 
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs)
    % Return all the input files
    OutputFiles = {};
    
    % Get options
    EvtNames = strtrim(sProcess.options.evtnames.Value);
    NewName  = strtrim(sProcess.options.newname.Value);
    isDelete = sProcess.options.delete.Value;
    if isempty(EvtNames) || isempty(NewName)
        bst_report('Error', sProcess, [], 'You must enter a list of events to merge and a destination name.');
        return;
    end
    % Split names
    EvtNames = strtrim(str_split(EvtNames, ',;'));
    if (length(EvtNames) < 1) || isempty(EvtNames{1})
        bst_report('Error', sProcess, [], 'You must enter at least one event name to copy.');
        return;
    end

    % For each file
    for iFile = 1:length(sInputs)
        % ===== GET FILE DESCRIPTOR =====
        % Load the raw file descriptor
        isRaw = strcmpi(sInputs(iFile).FileType, 'raw');
        if isRaw
            DataMat = in_bst_data(sInputs(iFile).FileName, 'F');
            sEvents = DataMat.F.events;
        else
            DataMat = in_bst_data(sInputs(iFile).FileName, 'Events');
            sEvents = DataMat.Events;
        end
        % If no markers are present in this file
        if isempty(sEvents)
            bst_report('Error', sProcess, sInputs(iFile), 'This file does not contain any event. Skipping File...');
            continue;
        end
        % Call the renaming function
        [sEvents, isModified] = Compute(sInputs(iFile), sEvents, EvtNames, NewName, isDelete);

        % ===== SAVE RESULT =====
        % Only save changes if something was change
        if isModified
            % Report changes in .mat structure
            if isRaw
                DataMat.F.events = sEvents;
            else
                DataMat.Events = sEvents;
            end
            % Save file definition
            bst_save(file_fullpath(sInputs(iFile).FileName), DataMat, 'v6', 1);
        end
        % Return all the input files
        OutputFiles{end+1} = sInputs(iFile).FileName;
    end
end


%% ===== MERGE EVENTS =====
function [events, isModified] = Compute(sInput, events, EvtNames, NewName, isDelete)
    if isempty(sInput)
        sInput = '';
    end
    % No modification
    isModified = 0;

    % Check that destination name doesn't already exist
    iEvtNew = find(strcmpi({events.label}, NewName));
    if ~isempty(iEvtNew)
        bst_report('Error', 'process_evt_merge', sInput, ['Event "' NewName '" already exists.']);
        return;
    end
    
    % Find events to merge
    iEvents = [];
    for i = 1:length(EvtNames)
        iEvt = find(strcmpi({events.label}, EvtNames{i}));
        if isempty(iEvt)
            bst_report('Warning', 'process_evt_merge', sInput, ['Event "' EvtNames{i} '" does not exist.']);
        else
            iEvents(end+1) = iEvt;
        end
    end
    % Make sure there are at least two events to merge
    if (length(iEvents) < 1)
        bst_report('Error', 'process_evt_merge', sInput, 'You must enter at least one event name to copy.');
        return;
    end
    % Make sure selected events are all of same type
    try
        [events(iEvents).times];
    catch
        bst_report('Error', 'process_evt_merge', sInput, 'You cannot merge simple and extended events together.');
        return;
    end

    % Inialize new event group
    newEvent = events(iEvents(1));
    newEvent.label      = NewName;
    newEvent.times      = [events(iEvents).times];
    newEvent.epochs     = [events(iEvents).epochs];
    % Reaction time, channels, notes: only if all the events have them
    if all(cellfun(@isempty, {events(iEvents).channels}))
        newEvent.channels = [];
    else
        % Expand empty channels if needed
        for ie = 1 : length(iEvents)
            if isempty(events(iEvents(ie)).channels)
                events(iEvents(ie)).channels = cell(1, size(events(iEvents(ie)).times, 2));
            end
        end
        newEvent.channels = [events(iEvents).channels];
    end
    if all(cellfun(@isempty, {events(iEvents).notes}))
        newEvent.notes = [];
    else
        % Expand empty notes if needed
        for ie = 1 : length(iEvents)
            if isempty(events(iEvents(ie)).notes)
                events(iEvents(ie)).notes = cell(1, size(events(iEvents(ie)).notes, 2));
            end
        end
        newEvent.notes = [events(iEvents).notes];
    end
    if all(cellfun(@isempty, {events(iEvents).reactTimes}))
        newEvent.reactTimes = [];
    else
        % Expand empty reactTimes if needed
        for ie = 1 : length(iEvents)
            if isempty(events(iEvents(ie)).reactTimes)
                events(iEvents(ie)).reactTimes = zeros(1, size(events(iEvents(ie)).reactTimes, 2));
            end
        end
        newEvent.reactTimes = [events(iEvents).reactTimes];
    end
    % Find duplicated events
    iRemoveDuplicate = [];
    [~, ics, ias] = unique(bst_round(newEvent.times', 9), 'rows', 'stable');
    % Check if duplicated times are really duplicated events
    for ix = 1 : length(ics)
        ids = find(ias == ix);
        for iy = 2 : length(ids)
            id = ids(iy);
            if (isempty(newEvent.channels)   || isequal(newEvent.channels{ids(1)}, newEvent.channels{id})) && ...
               (isempty(newEvent.notes)      || isequal(newEvent.notes{ids(1)}, newEvent.notes{id})) && ...
               (isempty(newEvent.reactTimes) || isequal(newEvent.reactTimes(ids(1)), newEvent(id).reactTimes))
               iRemoveDuplicate = [iRemoveDuplicate, id];
            end
        end
    end
    % Sort by samples indices
    [~, iSort] = sort(bst_round(newEvent.times(1,:), 9));
    % Remove indices of duplicated events
    iSort = iSort(~ismember(iSort, iRemoveDuplicate));
    newEvent.times    = newEvent.times(:,iSort);
    newEvent.epochs   = newEvent.epochs(iSort);
    if ~isempty(newEvent.channels)
        newEvent.channels = newEvent.channels(iSort);
    end
    if ~isempty(newEvent.notes)
        newEvent.notes = newEvent.notes(iSort);
    end
    if ~isempty(newEvent.reactTimes)
        newEvent.reactTimes = newEvent.reactTimes(iSort);
    end
    
    % Remove merged events
    if isDelete
        events(iEvents) = [];
    % If creating new events without deleting the existing: use a new color
    else
        newEvent.color = panel_record('GetNewEventColor', length(events) + 1, events);
    end
    % Add new event
    events(end + 1) = newEvent;

    % File was modified
    isModified = 1;
end






