function varargout = process_customize_spes_nk( varargin )
% PROCESS_CUSTOMIZE_SPES_NK: Customize Single-Pulse Electrical Stimulation (SPES) blocks 
% in raw data recorded using Nihon Kohden system.
%
% This process:
%   1. Finds Nihon Kohden "Stim Start" and "Stim Stop" events.
%   2. If provided, renames those stimulation block events.
%   3. Detects individual analog stimulation trigger pulses within each
%      stimulation block.
%   4. If provided, splits detected trigger pulses into ODD and EVEN events,
%      useful for alternating monophasic stimulation study.
%
% USAGE:
%   OutputFiles = process_customize_spes_nk('Run', sProcess, sInputs)

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
% Authors: Kenneth N. Taylor, 2020
%          John C. Mosher, 2020          
%          Chinmay Chinara, 2026

eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
% Description the process
sProcess.Comment     = 'Customize SPES (Nihon Kohden)';
sProcess.Category    = 'Custom';
sProcess.SubGroup    = 'Stimulation';
sProcess.Index       = 901;
% Definition of the input accepted by this process
sProcess.InputTypes  = {'raw'};
sProcess.OutputTypes = {'raw'};
sProcess.nInputs     = 1;
sProcess.nMinFiles   = 1;
% Update stimulation start event label
% If empty, the original Nihon Kohden label "Stim Start" is kept
sProcess.options.stimstartlabel.Comment = 'Update stimulation start event label (empty=''Stim Start''): ';
sProcess.options.stimstartlabel.Type    = 'text';
sProcess.options.stimstartlabel.Value   = 'SB';
% Update stimulation stop event label
% If empty, the original Nihon Kohden label "Stim Stop" is kept
sProcess.options.stimstoplabel.Comment = 'Update stimulation stop event label (empty=''Stim Stop''): ';
sProcess.options.stimstoplabel.Type    = 'text';
sProcess.options.stimstoplabel.Value   = 'SE';
% Stimulation trigger channel name
sProcess.options.stimchan.Comment = 'Stimulation trigger channel: ';
sProcess.options.stimchan.Type    = 'text';
sProcess.options.stimchan.Value   = 'DC10';
% Update stimulation trigger label
% If empty, the stimulation trigger channel name is used
sProcess.options.stimlabel.Comment = 'Update stimulation trigger label (empty=No change): ';
sProcess.options.stimlabel.Type    = 'text';
sProcess.options.stimlabel.Value   = 'STIM';
% Buffer time around stimulation block
sProcess.options.label1.Comment = '<HTML><I><FONT color="#777777">Time window buffer for detecting the stimulation trigger</FONT></I>';
sProcess.options.label1.Type    = 'label';
sProcess.options.buffertime.Comment = 'Buffer time around stimulation block: ';
sProcess.options.buffertime.Type    = 'value';
sProcess.options.buffertime.Value   = {5,'s', 2};
% Option: Trigger time offset
sProcess.options.label2.Comment = ['<HTML><I><FONT color="#777777">' ...
                                   'Add a fixed time offset to stimulation trigger event. It compensates for a known<BR>' ...
                                   'stimulation delay/advance between the trigger and the actual stimulus presentation<BR>' ... 
                                   'Example: Event occurs at 1.000s<BR>' ...
                                   ' - Time offset =&nbsp;&nbsp;1.0ms => New timing of event will be 1.001s<BR>' ...
                                   ' - Time offset = -1.0ms => New timing of event will be 0.999s</FONT></I>'];
sProcess.options.label2.Type    = 'label';
sProcess.options.offset.Comment = 'Trigger time offset:';
sProcess.options.offset.Type    = 'value';
sProcess.options.offset.Value   = {0, 'ms', []};
% Add 'ODD' and 'EVEN' events to stimulation blocks
sProcess.options.label3.Comment = '<HTML><I><FONT color="#777777">Add alternating monophasic stimulation trigger events</FONT></I>';
sProcess.options.label3.Type    = 'label';
sProcess.options.evtaddoddeven.Comment = 'Add ''ODD'' and ''EVEN'' events';
sProcess.options.evtaddoddeven.Type    = 'checkbox';
sProcess.options.evtaddoddeven.Value   = 1;
end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end

%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Initialize output
    OutputFiles = {};

    % Get proccess options
    StimStartLabel = sProcess.options.stimstartlabel.Value;
    StimStopLabel  = sProcess.options.stimstoplabel.Value;
    StimChan       = sProcess.options.stimchan.Value;
    StimLabel      = sProcess.options.stimlabel.Value;    
    BufferTime     = sProcess.options.buffertime.Value{1};
    OffsetTime     = sProcess.options.offset.Value{1};
    EvtAddOddEven  = sProcess.options.evtaddoddeven.Value;
    
    % Check whether custom start/stop labels were provided
    isUpdateStimStartLabel = ~isempty(StimStartLabel);
    isUpdateStimStopLabel  = ~isempty(StimStopLabel);
    % Use the default Nihon Kohden labels when no custom labels are provided
    if ~isUpdateStimStartLabel
        StimStartLabel = 'Stim Start';
    end
    if ~isUpdateStimStopLabel
        StimStopLabel = 'Stim Stop';
    end
    % If no custom stimulation trigger event label is provided, use the analog 
    % trigger channel name as the event label
    if isempty(StimLabel)
        StimLabel = StimChan;
    end
    
    for iFile = 1:length(sInputs)
        % Locate Nihon Kohden stimulation block events
        EventMat = in_bst_data(sInputs(iFile).FileName, 'F');
        iStart = find(strncmp({EventMat.F.events.label}, 'Stim Start', 10));
        iStop  = find(strncmp({EventMat.F.events.label}, 'Stim Stop', 9));
        
        % If provided, rename stimulation block start events
        if isUpdateStimStartLabel
            srcTag = {EventMat.F.events(iStart).label};
            destTag = strrep(srcTag, 'Stim Start', StimStartLabel);
            bst_process('CallProcess', 'process_evt_rename', sInputs(iFile), [], ...
                    'src',  strjoin(srcTag, ', '), ...
                    'dest', strjoin(destTag, ', '));
        end
        % If provided, rename stimulation block stop events
        if isUpdateStimStopLabel
            srcTag = {EventMat.F.events(iStop).label};
            destTag = strrep(srcTag, 'Stim Stop', StimStopLabel);
            bst_process('CallProcess', 'process_evt_rename', sInputs(iFile), [], ...
                    'src',  strjoin(srcTag, ', '), ...
                    'dest', strjoin(destTag, ', '));
        end
        
        % Reload the event structure
        EventMat = in_bst_data(sInputs(iFile).FileName, 'F');
        % Extract event times
        stimStartTimes = {EventMat.F.events(iStart).times};
        stimStopTimes  = {EventMat.F.events(iStop).times};
        % Extract start event labels
        stimStartLabels = {EventMat.F.events(iStart).label};
    
        % === Detect analog stimulation trigger pulses inside each stimulation block ===
        % Each start/stop pair defines a time window. Within that window, individual
        % trigger pulses are detected from the selected analog stimulation channel
        for iLabel = 1:length(stimStartLabels)
            % Extract stimulation site information
            % Example: "SB O6-O7 4.0" -> "O6-O7 4.0"
            stimSiteInfo = strtrim(strrep(stimStartLabels{iLabel}, StimStartLabel, ''));
            
            for iTime = 1:length(stimStartTimes{iLabel})
                % Stimulation trigger event name
                % Example: "STIM O6-O7 4.0 #1"
                stimEventName = sprintf('%s %s #%d', StimLabel, stimSiteInfo, iTime);
                % Define time window (stimulation block plus some context before and after it) 
                preStim = stimStartTimes{iLabel}(iTime) - BufferTime;
                postStim = stimStopTimes{iLabel}(iTime) + BufferTime;
                % Detect individual analog trigger pulses within the current stimulation block
                bst_process('CallProcess', 'process_evt_detect_analog', sInputs(iFile).FileName, [], ...
                        'eventname',   stimEventName, ...
                        'timewindow',  [preStim postStim], ...
                        'channelname', StimChan, ...
                        'threshold',   1, ...        % Standard deviations from noise 
                        'blanking',    0.8, ...      % Minimum duration between two events (in seconds)
                        'highpass',    0, ...
                        'lowpass',     0, ...
                        'refevent',    '', ...
                        'isfalling',   0, ...
                        'ispullup',    0, ...        % No DC offset removal
                        'isclassify',  0);
                
                % Process: Add fixed time offset
                if OffsetTime ~= 0
                    bst_process('CallProcess', 'process_evt_timeoffset', sInputs(iFile), [], ...
                        'info',      [], ...
                        'eventname', stimEventName, ...
                        'offset',    OffsetTime);   % in ms
                end
                
                % If provided, split detected pulses into 'ODD' and 'EVEN' events
                if EvtAddOddEven
                    % Reload the event structure
                    EventMat = in_bst_data(sInputs(iFile).FileName, 'F');
                    % Update color for the stimulation trigger event
                    EventMat.F.events(end).color = [0.8, 0.8, 0.8]; % Gray
                    % Create 'ODD' event from odd-numbered stimulation trigger pulses
                    sEventOdd = db_template('event');
                    sEventOdd.label  = sprintf('ODD %s #%d', stimSiteInfo, iTime);
                    sEventOdd.times = EventMat.F.events(end).times(1:2:end);
                    sEventOdd.epochs = EventMat.F.events(end).epochs(1:2:end);
                    sEventOdd.color = [0.9, 0, 0]; % Red
                    EventMat.F.events(end+1) = sEventOdd;
                    % Create 'EVEN' event from even-numbered stimulation trigger pulses
                    sEventEven = db_template('event');
                    sEventEven.label  = sprintf('EVEN %s #%d', stimSiteInfo, iTime);
                    sEventEven.times = EventMat.F.events(end-1).times(2:2:end);
                    sEventEven.epochs = EventMat.F.events(end-1).epochs(2:2:end);
                    sEventEven.color = [ 0, 0, 0.9]; % Blue
                    EventMat.F.events(end+1) = sEventEven;            
                    % Save the updated event structure back to the raw file
                    bst_save(file_fullpath(sInputs(iFile).FileName), EventMat, 'v7', 1);
                end
            end
        end

        % Return the processed raw file
        OutputFiles{end+1} = sInputs(iFile).FileName;
    end
end