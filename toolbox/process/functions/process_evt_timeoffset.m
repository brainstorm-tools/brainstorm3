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
% Authors: Francois Tadel, 2013-2023

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
    sProcess.options.info.Comment = ['Add a time offset to the selected event markers.<BR><BR>' ... 
                                     'Example: Event "A" occurs at 1.000s<BR>' ...
                                     ' - Time offset =&nbsp;&nbsp;100.0ms => New timing of event A will be 1.100s<BR>' ...
                                     ' - Time offset = -100.0ms => New timing of event A will be 0.900s<BR><BR>' ...
                                     'This time offset can be fixed or variable:<BR>' ...
                                     '1) <B>Fixed</B>: Same offset for all the occurrences, e.g. when compensating for a known<BR>' ...
                                     'stimulation delay between the trigger marker and the actual stimulus presentation.<BR>' ...
                                     '2) <B>Variable</B>: Different offset for each occurrence, e.g. when computing a <B>response</B><BR>' ...
                                     'event from the <B>stimulus</B> already in the recordings and the <B>reaction times</B> saved<BR>' ...
                                     'in a separate text file (list of durations in seconds, one for each occurrence).<BR>' ...
                                     'If a <B><U>file</U></B> is specified, the <B><U>fixed time offset is ignored</U></B>.<BR><BR>'];
    sProcess.options.info.Type    = 'label';
    sProcess.options.info.Value   = [];
    % Event name
    sProcess.options.eventname.Comment = 'Event names: ';
    sProcess.options.eventname.Type    = 'text';
    sProcess.options.eventname.Value   = '';
    % Fixed time offset
    sProcess.options.offset.Comment = '1) Fixed time offset:';
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
        {{'.*'}, 'Array of times (*.mat;*.*)', 'ARRAY-TIMES'}, ...
        'EventsIn'};                          % DefaultFormats: {ChannelIn,DataIn,DipolesIn,EventsIn,MriIn,NoiseCovIn,ResultsIn,SspIn,SurfaceIn,TimefreqIn
    % Option: Event file
    sProcess.options.evtfile.Comment = '2) Variable time offset (file):';
    sProcess.options.evtfile.Type    = 'filename';
    sProcess.options.evtfile.Value   = SelectOptions;
    % Suffix to append to new events name
    sProcess.options.suffix.Comment = 'Backup suffix: ';
    sProcess.options.suffix.Type    = 'text';
    sProcess.options.suffix.Value   = '';
    sProcess.options.suffix.Group   = 'output';
     % Explanations
    sProcess.options.comment1.Comment = '<FONT color="#707070"><I>If a suffix is set, event "A" is copied to "A-suffix" before being modified.</I></FONT>';
    sProcess.options.comment1.Type    = 'label';
    sProcess.options.comment1.Group   = 'output';
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
    % Get event file used for variable time offset 
    EventFile  = sProcess.options.evtfile.Value{1};
    FileFormat = sProcess.options.evtfile.Value{2};
    % Event names
    EvtNames = strtrim(str_split(sProcess.options.eventname.Value, ',;'));
    if isempty(EvtNames)
        bst_report('Error', sProcess, [], 'No events selected.');
        return;
    end
    Suffix = sProcess.options.suffix.Value;

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
        % Read ASCII or .mat
        EventsMat = load(EventFile);
        if isstruct(EventsMat)
            fields = fieldnames(EventsMat);
            EventsMat = EventsMat.(fields{1});
            if isstruct(EventsMat)
                fields = fieldnames(EventsMat);
                EventsMat = EventsMat.(fields{1});
            end
        end
        % Force to be double
        VariableOffsetTime = double(EventsMat(:)');
        % There is at least one of the input events which length differs from event file
        if sum(evLength - length(VariableOffsetTime)) ~= 0
            bst_report('Error', sProcess, sInput, 'When using variable time offset : All input events must have the same length as input file.');
            return;
        end
    else
        VariableOffsetTime = [];
    end
    
    % ===== PROCESS EVENTS =====
    for i = 1:length(iEvtList)
        % No suffix: Overwrite existing events 
        if isempty(Suffix)
            iNewEvt = iEvtList(i);
        % Suffix: Create new events
        else
            iNewEvt = length(sEvents) + 1;
            sEvents(iNewEvt) = sEvents(iEvtList(i));
            sEvents(iEvtList(i)).label = file_unique([sEvents(iEvtList(i)).label, '-', Suffix], {sEvents.label});
        end
        % Add offset: fixed OR variable
        if ~isempty(VariableOffsetTime)
            sEvents(iNewEvt).times = sEvents(iNewEvt).times + VariableOffsetTime;
        else
            sEvents(iNewEvt).times = round((sEvents(iNewEvt).times + OffsetTime) .* sFreq) ./ sFreq;
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
