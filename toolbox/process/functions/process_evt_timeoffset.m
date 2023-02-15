function varargout = process_evt_timeoffset( varargin )
% PROCESS_EVT_TIMEOFFSET: Add a time offset to all the events of a given category
%
% USAGE:  OutputFiles = process_evt_timeoffset('Run', sProcess, sInput)

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
% Authors: Francois Tadel, 2013-2015

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Add time offset';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 61;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/EventMarkers#Other_menus';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw', 'matrix'};
    sProcess.OutputTypes = {'data', 'raw', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Description
    sProcess.options.info.Comment = ['Adds a given time offset (in milliseconds) to the selected event markers.<BR>' ... 
                                     'The offset can be positive or negative: add a minus sign to remove this offset.<BR><BR>' ...
                                     'Example: Event "A" occurs at 1.000s<BR>' ...
                                     ' - Time offset =&nbsp;&nbsp;100.0ms => New timing of event A will be 1.100s<BR>' ...
                                     ' - Time offset = -100.0ms => New timing of event A will be 0.900s<BR><BR>'];
    sProcess.options.info.Type    = 'label';
    sProcess.options.info.Value   = [];
    % Event name
    sProcess.options.eventname.Comment = 'Event names: ';
    sProcess.options.eventname.Type    = 'text';
    sProcess.options.eventname.Value   = '';
    % Fixed time offset
    sProcess.options.offset.Comment = 'Fixed time offset:';
    sProcess.options.offset.Type    = 'value';
    sProcess.options.offset.Value   = {0, 'ms', []};
     % File selection options
    SelectOptions = {...
        '', ...                               % Filename
        '', ...                               % FileFormat
        'open', ...                           % Dialog type: {open,save}
        'Import events...', ...               % Window title
        'ImportData', ...                     % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                         % Selection mode: {single,multiple}
        'files', ...                          % Selection mode: {files,dirs,files_and_dirs}
        bst_get('FileFilters', 'events'), ... % Get all the available file formats
        'EventsIn'};                          % DefaultFormats: {ChannelIn,DataIn,DipolesIn,EventsIn,MriIn,NoiseCovIn,ResultsIn,SspIn,SurfaceIn,TimefreqIn
    % Option: Event file
    sProcess.options.evtfile.Comment = 'Relative time offset (Event file):';
    sProcess.options.evtfile.Type    = 'filename';
    sProcess.options.evtfile.Value   = SelectOptions;
    % Suffix to append to new events name
    sProcess.options.suffix.Comment = 'Suffix: ';
    sProcess.options.suffix.Type    = 'text';
    sProcess.options.suffix.Value   = '';
     % Explanations
    sProcess.options.comment1.Comment = ['<FONT color="#707070"><I>Without suffix the events will be overwritten</I></FONT>'];
    sProcess.options.comment1.Type    = 'label';
       
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
    OffsetTime = sProcess.options.offset.Value{1};
    Suffix = sProcess.options.suffix.Value;
    
    % Get event file used for variable time offset 
    EventFile  = sProcess.options.evtfile.Value{1};
    FileFormat = sProcess.options.evtfile.Value{2};
%     EventName  = sProcess.options.evtname.Value;
    
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
        DataMat = in_bst_data(sInput.FileName, 'F', 'History');
        sEvents = DataMat.F.events;
        sFreq = DataMat.F.prop.sfreq;
    else
        DataMat = in_bst_data(sInput.FileName, 'Events', 'Time', 'History');
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
        if ~isempty(iEvt)
            iEvtList(end+1) = iEvt;
            evLength(i) = length(sEvents(iEvt).times) ; 
        else
            bst_report('Warning', sProcess, sInput, ['This file does not contain any event "' EvtNames{i} '".']);
        end
    end
    % No events to process
    if isempty(sEvents)
        bst_report('Error', sProcess, sInput, 'No events to process.');
        return;
    end
   
    % Snap time offset to the closest sample
    if (OffsetTime == 0) && isempty(EventFile)
        bst_report('Error', sProcess, sInput, 'The selected time offset must be longer than one time sample.');
        return;
    end

    % Reads the event file (variable time offset)
    if ~isempty(EventFile)
   
        % Get sFile structure
        sFile = DataMat.F;
        
        % Imports event file (variable time offset) 
        [sFile, newEvents] = import_events(sFile, [], EventFile, FileFormat, [], 0,0); 
   
        % There is at least one of the input events which length differs
        % from event file
        if sum(evLength - length(newEvents.times)) ~= 0
            bst_report('Error', sProcess, sInput, 'When using variable time offset : All input events must have the same length as input file.');
            return;
        end
        % Get the variable offset time (first column because txt file comes
        % as extended events..) 
        VariableOffsetTime = newEvents.times(1,:); 
    end
    
    % No suffix -> overwrite existing events 
    if isempty(Suffix) 
        % ===== PROCESS EVENTS =====
        for i = 1:length(iEvtList)
            sEvents(iEvtList(i)).times = round((sEvents(iEvtList(i)).times + OffsetTime) .* sFreq) ./ sFreq;
            if ~isempty(VariableOffsetTime)
                sEvents(iEvtList(i)).times = sEvents(iEvtList(i)).times + VariableOffsetTime; 
            end
            
        end
    % Suffix -> Create new events
    else 
        % ===== PROCESS EVENTS =====
        for i = 1:length(iEvtList)
            % Inialize new event group
            newEvent = sEvents(iEvtList(i));
            newEvent.label      = strcat(sEvents(iEvtList(i)).label,Suffix);
            newEvent.times      = round((sEvents(iEvtList(i)).times + OffsetTime) .* sFreq) ./ sFreq;
            if ~isempty(VariableOffsetTime)
                newEvent.times = sEvents(iEvtList(i)).times + VariableOffsetTime; 
            end
            newEvent.epochs     = [sEvents(iEvtList(i)).epochs];
            newEvent.channels   = [sEvents(iEvtList(i)).channels];
            newEvent.notes      = [sEvents(iEvtList(i)).notes];
            % Reaction time: only if all the events have reaction time set
            if all(~cellfun(@isempty, {sEvents(iEvtList(i)).reactTimes}))
                newEvent.reactTimes = [sEvents(iEvtList(i)).reactTimes];
            else
                newEvent.reactTimes = [];
            end
            % Add new event
            sEvents(end + 1) = newEvent;
        end
    end
    % ===== SAVE RESULT =====
    % Report results
    if isRaw
        DataMat.F.events = sEvents;
    else
        DataMat.Events = sEvents;
    end
    % Add history entry
    DataMat = bst_history('add', DataMat, 'timeoffset', [sprintf('Added time offset %1.4fs to events: ', OffsetTime), sprintf('%s ', EvtNames{:})]);
    % Only save changes if something was change
    bst_save(file_fullpath(sInput.FileName), DataMat, 'v6', 1);
end




