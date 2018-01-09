function varargout = process_evt_extended( varargin )
% PROCESS_EVT_EXTENDED: Convert simple events to extended events.
%
% USAGE:  OutputFiles = process_evt_extended('Run', sProcess, sInput)

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2013

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Convert to extended event';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 62;
    sProcess.Description = 'http://neuroimage.usc.edu/brainstorm/Tutorials/EventMarkers#Other_menus';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Event name
    sProcess.options.eventname.Comment = 'Event names: ';
    sProcess.options.eventname.Type    = 'text';
    sProcess.options.eventname.Value   = '';
    % Time offset
    sProcess.options.timewindow.Comment = 'Time window around event:';
    sProcess.options.timewindow.Type    = 'range';
    sProcess.options.timewindow.Value   = {[-0.2, 0.2], 's', []};
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
    TimeWindow = sProcess.options.timewindow.Value{1};
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
        elseif isempty(sEvents(iEvt).samples)
            bst_report('Warning', sProcess, sInput, ['Event category "' sEvents(iEvt).label '" is empty.']);
        elseif (size(sEvents(iEvt).samples,1) > 1)
            bst_report('Warning', sProcess, sInput, ['Event category "' sEvents(iEvt).label '" already contains extended events.']);
        else
            iEvtList(end+1) = iEvt;            
        end
    end
    % No events to process
    if isempty(iEvtList)
        bst_report('Error', sProcess, sInput, 'No events to process.');
        return;
    end
    % Snap time offset to the closest sample
    OffsetSample = round(TimeWindow * sFreq);
        
    % ===== PROCESS EVENTS =====
    for i = 1:length(iEvtList)
        sEvents(iEvtList(i)).samples = max(0, [sEvents(iEvtList(i)).samples + OffsetSample(1); sEvents(iEvtList(i)).samples + OffsetSample(2)]);
        sEvents(iEvtList(i)).times   = sEvents(iEvtList(i)).samples / sFreq;
    end
        
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




