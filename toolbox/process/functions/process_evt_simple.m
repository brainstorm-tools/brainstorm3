function varargout = process_evt_simple( varargin )
% PROCESS_EVT_SIMPLE: Convert extended events to simple events
%
% USAGE:  OutputFiles = process_evt_simple('Run', sProcess, sInput)

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
% Authors: Francois Tadel, 2015-2018

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Convert to simple event';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 63;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/EventMarkers#Other_menus';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw', 'matrix'};
    sProcess.OutputTypes = {'data', 'raw', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Event name
    sProcess.options.eventname.Comment = 'Event names: ';
    sProcess.options.eventname.Type    = 'text';
    sProcess.options.eventname.Value   = '';
    % Method from extended to simple
    sProcess.options.method.Comment = {'Keep the start of the events', 'Keep the middle of the events', 'Keep the end of the events', 'Keep all samples of the events'; ...
                                      'start', 'middle', 'end', 'all'};
    sProcess.options.method.Type    = 'radio_label';
    sProcess.options.method.Value   = 'start';

end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFile = Run(sProcess, sInput) %#ok<DEFNU>
    % Return all the input files
    OutputFile = {sInput.FileName};
    
    % ===== GET OPTIONS =====
    % Time offset
    switch (sProcess.options.method.Value)
        case {1, 'start'},  Method = 'start';
        case {2, 'middle'}, Method = 'middle';
        case {3, 'end'},    Method = 'end';
        case {4, 'all'},    Method = 'every_sample';
    end
    % Event names
    EvtNames = strtrim(str_split(sProcess.options.eventname.Value, ',;'));
    if isempty(EvtNames)
        bst_report('Error', sProcess, [], 'No events selected.');
        return;
    end
    
    % ===== LOAD FILE =====
    % Get file descriptor
    isRaw = strcmpi(sInput.FileType, 'raw');
    % Load the raw file descriptor
    if isRaw
        DataMat = in_bst_data(sInput.FileName, 'F');
        sEvents = DataMat.F.events;
        sFreq = DataMat.F.prop.sfreq;
    else
        DataMat = in_bst_data(sInput.FileName, 'Events', 'Time');
        sEvents = DataMat.Events;
        sFreq = 1 ./ (DataMat.Time(2) - DataMat.Time(1));
    end
    % If no markers are present in this file
    if isempty(sEvents)
        bst_report('Error', sProcess, sInput, 'This file does not contain any event.');
        return;
    end
    % Find event names
    iEvtList = [];
    for i = 1:length(EvtNames)
        iEvt = find(strcmpi(EvtNames{i}, {sEvents.label}));
        if isempty(iEvt)
            bst_report('Warning', sProcess, sInput, 'This file does not contain any event.');
        elseif isempty(sEvents(iEvt).times)
            bst_report('Warning', sProcess, sInput, ['Event category "' sEvents(iEvt).label '" is empty.']);
        elseif (size(sEvents(iEvt).times,1) == 1)
            bst_report('Warning', sProcess, sInput, ['Event category "' sEvents(iEvt).label '" already contains simple events.']);
        else
            iEvtList(end+1) = iEvt;            
        end
    end
    % No events to process
    if isempty(iEvtList)
        bst_report('Error', sProcess, sInput, 'No events to process.');
        return;
    end
        
    % ===== PROCESS EVENTS =====
    sEventsMod = sEvents(iEvtList);
    sEventsMod = Compute(sEventsMod, Method, sFreq);
    sEvents(iEvtList) = sEventsMod;

    % ===== SAVE RESULT =====
    % Report results
    if isRaw
        DataMat.F.events = sEvents;
    else
        DataMat.Events = sEvents;
    end
    % Only save changes if something was change
    bst_save(file_fullpath(sInput.FileName), DataMat, 'v6', 1);
end


%% ===== COMPUTE =====
function sEvents = Compute(sEvents, modification, sFreq)
    % Apply modificiation to each event type
    for i = 1:length(sEvents)
        switch (modification)
            case 'start'
                sEvents(i).times = sEvents(i).times(1,:);
            case 'middle'
                sEvents(i).times = mean(sEvents(i).times, 1);
            case 'end'
                sEvents(i).times = sEvents(i).times(2,:);
            case 'every_sample'
                % Create an event instance for every sample in limits of the extendend event
                sEventAllOcc = repmat(db_template('Event'), 0);
                for iOccurExt = 1 : size(sEvents(i).times,2)
                    nSamples = round(diff(sEvents(i).times(:, iOccurExt)) * sFreq) + 1;
                    sEventOcc = sEvents(i);
                    sEventOcc.epochs = repmat(sEvents(i).epochs(iOccurExt), 1, nSamples);
                    sEventOcc.times  = ([0:nSamples-1] / sFreq) + sEvents(i).times(1,iOccurExt);
                    if ~isempty(sEvents(i).channels)
                        sEventOcc.channels = repmat(sEvents(i).channels(iOccurExt), 1, nSamples);
                    end
                    if ~isempty(sEvents(i).notes)
                        sEventOcc.notes = repmat(sEvents(i).notes(iOccurExt), 1, nSamples);
                    end
                    % Events for one occurence
                    sEventOcc.label = sprintf('%s_%05d', sEvents(i).label, iOccurExt);
                    sEventAllOcc(end+1) = sEventOcc;
                end
                % Merge events from all ocurrences
                sEvents(i) = process_evt_merge('Compute', '', sEventAllOcc, {sEventAllOcc.label}, sEvents(i).label, 1);
        end
    end
    sEvents(i).times = round(sEvents(i).times .* sFreq) / sFreq;
end
