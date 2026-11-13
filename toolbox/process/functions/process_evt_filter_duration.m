function varargout = process_evt_filter_duration( varargin )
% process_evt_filter_duration: Create a copy of an event, keep occurrences based on their durations
%
% USAGE:  OutputFiles = process_evt_filter_duration('Run', sProcess, sInputs)

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
    sProcess.Comment     = 'Filter extended events by duration';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 52.3;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw', 'matrix'};
    sProcess.OutputTypes = {'data', 'raw', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    sProcess.options.events_name.Comment = 'Events';
    sProcess.options.events_name.Type    = 'text';
    sProcess.options.events_name.Value   = '';

    sProcess.options.minimum_duration.Comment = 'Keep occurrences larger than (0=disable):';
    sProcess.options.minimum_duration.Type    = 'value';
    sProcess.options.minimum_duration.Value   = {1, 's', 1};

    sProcess.options.maximum_duration.Comment = 'Keep occurrences shorter than (0=disable):';
    sProcess.options.maximum_duration.Type    = 'value';
    sProcess.options.maximum_duration.Value   = {5, 's', 1};

end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    minimum_duration = sProcess.options.minimum_duration.Value{1};
    maximum_duration = sProcess.options.maximum_duration.Value{1};
    if minimum_duration <= 0
        minimum_duration = [];
    end
    if maximum_duration <= 0
        maximum_duration = [];
    end
    Comment = ['Event duration filter: ' FormatSuffix(minimum_duration, maximum_duration)];
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput)
    % Return all the input files
    OutputFiles = {sInput.FileName};

    % ===== GET OPTIONS =====
    events_name = cellfun(@(x) strtrim(x), strsplit(sProcess.options.events_name.Value, ','),  'UniformOutput',  false);
    if isempty(events_name)
        bst_report('Warning', sProcess, sInput, 'No event to process.');
        return;
    end

    % Get options
    minimum_duration = sProcess.options.minimum_duration.Value{1};
    maximum_duration = sProcess.options.maximum_duration.Value{1};
    if minimum_duration <= 0
        minimum_duration = [];
    end
    if maximum_duration <= 0
        maximum_duration = [];
    end
    if isempty(minimum_duration) && isempty(maximum_duration)
        bst_report('Error', sProcess, sInput, 'Invalid inputs for "minimum" and "maximum" duration.');
        OutputFiles = {};
        return;
    end

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

    % Process only continuous files
    if isRaw && ~isempty(sFile.epochs)
        bst_report('Error', sProcess, sInput, 'This function can only process continuous recordings (no epochs). Skipping File...');
        OutputFiles = {};
        return;
    end

    % If no markers are present in this file
    if isempty(sFile.events)
        bst_report('Warning', sProcess, sInput, 'This file does not contain any event. Skipping file...');
        return;
    end

    % Check events to process
    [sEvents, missing_events] = GetEvents(sFile.events, events_name);
    if isempty(sEvents)
        bst_report('Warning', sProcess, sInput, 'This file does not contain any event. Skipping file...');
        return;
    end
    if ~isempty(missing_events)
        bst_report('Warning', sProcess, sInput, sprintf('The following events were not found in the file: %s.', strjoin(missing_events, ', ')));
    end
    if ~any(arrayfun(@(x) size(x.times,1), sEvents) == 2)
        bst_report('Warning', sProcess, sInput, ...
            sprintf(['Only extended events can be filtered by duration.\n', ...
                     'The following events will not be processed %s', strjoin({sEventsOuter(~isExtended).label}, ', ')]));
        return;
    end

    isModified = 0;
    for iEvent = 1:length(sEvents)
        [sEvent, nOccurs] = FilterOccurrenceDuration(sEvents(iEvent), minimum_duration, maximum_duration);
        % If there is at least one epoch, we add the event
        if nOccurs >= 1
            isModified = 1;
            sFile.events(end+1) = sEvent;
        end
    end

    % ===== SAVE RESULT =====
    if isModified
        % Report results
        if isRaw
            DataMat.F.events = sFile.events;
        else
            DataMat.Events = sFile.events;
        end
        bst_save(file_fullpath(sInput.FileName), DataMat, 'v6', 1);
    end
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


function suffix = FormatSuffix(minimum_duration, maximum_duration)
% Suffix for filtered event
    if ~isempty(minimum_duration) && ~isempty(maximum_duration)
        if maximum_duration <= minimum_duration
            suffix = 'Invalid';
        else
            suffix = sprintf('[%.3fs - %.3fs]', minimum_duration, maximum_duration);
        end
    elseif isempty(maximum_duration) && ~isempty(minimum_duration)
        suffix = sprintf('[> %.3fs]', minimum_duration);
    elseif isempty(minimum_duration) && ~isempty(maximum_duration)
        suffix = sprintf('[< %.3fs]', maximum_duration);
    else
        suffix = 'Invalid';
    end
end


function [sEvent, nOccurs] = FilterOccurrenceDuration(sEvent, minimum_duration, maximum_duration)
% Keep occurrences based on their duration
    sEvent.label = sprintf('%s %s', sEvent.label, FormatSuffix(minimum_duration, maximum_duration));
    durations = sEvent.times(2, :) - sEvent.times(1, :);
    keepEpoch = true(1, length(durations));
    if ~isempty(minimum_duration)
        keepEpoch = keepEpoch & durations >= minimum_duration;
    end
    if ~isempty(maximum_duration)
        keepEpoch = keepEpoch & durations <= maximum_duration;
    end
    sEvent.times = sEvent.times(:, keepEpoch);
    sEvent.epochs = sEvent.epochs(keepEpoch);
    nOccurs = sum(keepEpoch);
end
