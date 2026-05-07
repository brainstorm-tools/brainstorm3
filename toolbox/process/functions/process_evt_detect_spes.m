function varargout = process_evt_detect_spes( varargin )
% PROCESS_EVT_DETECT_SPES: Detect, label and sort single-pulse stimulation events from
% Single-Pulse Electrical Stimulation (SPES) blocks in raw data recorded using Nihon Kohden system
%
% This process:
%   1. Find stimulation blocks, defined by paired 'Stim Start' and 'Stim Stop' events
%   2. If requested, rename those 'Stim Start' and 'Stim Stop' events
%   3. Detect individual analog stimulation trigger pulses within each stimulation block
%   4. If provided, add a fixed time offset to stimulation trigger events
%   5. If provided, splits detected stimulation trigger events into ODD and EVEN instances,
%      useful for alternating monophasic stimulation study
%
% USAGE:
%   OutputFiles = process_evt_detect_spes('Run', sProcess, sInputs)

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
%          Raymundo Cassani, 2026

eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Detect single-pulse in SPES';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'FAST graphs';
    sProcess.Index       = 1;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data','raw'};
    sProcess.OutputTypes = {'data','raw'};
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
                                       'Add a fixed time offset to stimulation trigger event per block. It compensates for a known<BR>' ...
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
    defStimStartLabel = 'Stim Start';
    if ~isUpdateStimStartLabel
        StimStartLabel = defStimStartLabel;
    end
    defStimStopLabel = 'Stim Stop';
    if ~isUpdateStimStopLabel
        StimStopLabel = defStimStopLabel;
    end
    % If no custom stimulation trigger event label is provided, use the analog 
    % trigger channel name as the event label
    if isempty(StimLabel)
        StimLabel = StimChan;
    end
    
    for iFile = 1:length(sInputs)
        % Laod Events from file
        isRaw = strcmpi(sInputs(iFile).FileType, 'raw');
        if isRaw
            DataMat = in_bst_data(sInputs(iFile).FileName, 'F', 'Time', 'History');
            sFile   = DataMat.F;
            sEvents = DataMat.F.events;
            sFreq   = DataMat.F.prop.sfreq;
        else
            DataMat = in_bst_data(sInputs(iFile).FileName, 'Events', 'Time', 'History');
            sEvents = DataMat.Events;
            sFile = in_fopen(sInputs(iFile).FileName, 'BST-DATA');
            sFreq = 1 ./ (DataMat.Time(2) - DataMat.Time(1));
        end
        if isempty(sEvents)
            bst_report('Error', sProcess, sInput, 'This file does not contain any event.');
            return
        end
        % ===== 1. Find stimulation blocks, defined by paired 'Stim Start' and 'Stim Stop' events ===
        iStarts = find(strncmp({sEvents.label}, defStimStartLabel, length(defStimStartLabel)));
        iStops  = find(strncmp({sEvents.label}, defStimStopLabel,  length(defStimStopLabel)));
        if isempty(iStarts) || isempty(iStops)
            continue
        end
        % Start/Stop labels must be given in pairs, ignore single labels
        stimStartLabels = {sEvents(iStarts).label};
        stimStopLabels  = {sEvents(iStops).label};
        % Find paired stimulation Start and Stop events, i.e., stimulation blocks
        stimStartStopLabels = {};
        stimStartStopIxs    = [];
        stimStartStopTimes  = {};
        % Event names without preffix
        stimStartWoPreffixLabels = cellfun(@(x) strtrim(regexprep(x, ['^' defStimStartLabel], '')), stimStartLabels, 'UniformOutput', 0);
        stimStopWoPreffixLabels =  cellfun(@(x) strtrim(regexprep(x, ['^' defStimStopLabel], '')), stimStopLabels, 'UniformOutput', 0);                       
        for iA = 1 : length(stimStartWoPreffixLabels)
            % Check for perfect match of labels
            [isPerfectMatch, iB] = ismember(stimStartWoPreffixLabels{iA}, stimStopWoPreffixLabels);
            if isPerfectMatch
                stimStartStopLabels{end+1}  = stimStartWoPreffixLabels{iA};
                stimStartStopIxs(end+1, 1)  = iStarts(iA);
                stimStartStopIxs(end,   2)  = iStops(iB);
                stimStartStopTimes{end+1,1} = sEvents(iStarts(iA)).times;
                stimStartStopTimes{end  ,2} = sEvents(iStops(iB)).times;
            % Check for partial check of labels (specific case where Start label was clipped at 20 chars: ['Stim Start', ' ', LABEL9CHR]
            elseif length(stimStartWoPreffixLabels{iA}) == 9
                iB = find(strncmp(stimStopWoPreffixLabels, stimStartWoPreffixLabels{iA}, length(stimStartWoPreffixLabels{iA})));
                if length(iB) == 1
                    stimStartStopLabels{end+1}  = stimStartWoPreffixLabels{iA};
                    stimStartStopIxs(end+1, 1)  = iStarts(iA);
                    stimStartStopIxs(end,   2)  = iStops(iB);
                    stimStartStopTimes{end+1,1} = sEvents(iStarts(iA)).times;
                    stimStartStopTimes{end  ,2} = sEvents(iStops(iB)).times;
                end
            else
                % Ignore Start label as it does not have a related Stop label
                continue
            end
        end
        if isempty(stimStartStopIxs)
            bst_report('Error', sProcess, sInput, 'This file does not contain pairs of Start-Stop events.');
            return
        end
        % ===== 2. If requested, rename those 'Stim Start' and 'Stim Stop' events =====
        if isUpdateStimStartLabel
            srcTag = {sEvents(stimStartStopIxs(:,1)).label};
            destTag = strrep(srcTag, 'Stim Start', StimStartLabel);
            sEvents = process_evt_rename('Compute', sInputs(iFile).FileName, sEvents, srcTag, destTag);
        end
        if isUpdateStimStopLabel
            srcTag = {sEvents(stimStartStopIxs(:,2)).label};
            destTag = strrep(srcTag, 'Stim Stop', StimStopLabel);
            sEvents = process_evt_rename('Compute', sInputs(iFile).FileName, sEvents, srcTag, destTag);
        end
    
        % ===== 3. Detect individual analog stimulation trigger pulses within each stimulation block =====
        % Get index for stimulation trigger channel
        ChannelMat = in_bst_channel(sInputs(iFile).ChannelFile);
        iChannel = find(strcmpi({ChannelMat.Channel.Name}, StimChan));

        % Each start/stop pair defines a time window. Within that window, individual
        % trigger pulses are detected from the selected analog stimulation channel
        for iStimStartStop = 1:length(stimStartStopLabels)
            for iTime = 1:length(stimStartStopTimes{iStimStartStop, 1})
                % Stimulation trigger event name. E.g. "STIM O6-O7 4.0 #1"
                stimEventName = sprintf('%s %s #%d', StimLabel, stimStartStopLabels{iStimStartStop}, iTime);
                % Define time window (stimulation block plus some context before and after it)
                TimeWindow = [stimStartStopTimes{iStimStartStop, 1}(iTime) - BufferTime, stimStartStopTimes{iStimStartStop, 2}(iTime) + BufferTime];
                SamplesBounds = round(sFile.prop.times(1) .* sFile.prop.sfreq) + bst_closest(TimeWindow, DataMat.Time) - 1;
                % Option structure for function in_fread()
                ImportOptions = db_template('ImportOptions');
                ImportOptions.ImportMode      = 'Time';
                ImportOptions.EventsMode      = 'ignore';
                ImportOptions.DisplayMessages = 0;
                % Read data (F) and time Vector to analyze
                [F, TimeVector] = in_fread(sFile, ChannelMat, 1, SamplesBounds, iChannel, ImportOptions);
                % Get mask to ignore bad segments in file
                Fmask = [];
                badSeg = process_evt_detect('GetBadSegments', sFile, TimeWindow, DataMat.Time, length(TimeVector));
                if ~isempty(badSeg)
                    % Create file mask
                    Fmask = true(size(F));
                    % Loop on each segment: mark as bad
                    for iSeg = 1:size(badSeg, 2)
                        Fmask(:, badSeg(1,iSeg):badSeg(2,iSeg)) = false;
                    end
                end
                % Set import options
                EvtDetectAnalogOptions = process_evt_detect_analog('Compute');
                EvtDetectAnalogOptions.threshold = 1;
                EvtDetectAnalogOptions.blanking = 0.8;
                EvtDetectAnalogTimes = process_evt_detect_analog('Compute', F, TimeVector, [], EvtDetectAnalogOptions, Fmask);
                % Create stim event struct
                sEventStim = db_template('event');
                sEventStim.label = stimEventName;
                sEventStim.times = EvtDetectAnalogTimes{1};
                sEventStim.epochs   = ones(1, size(sEventStim.times,2));
                sEventStim.color = [0.8, 0.8, 0.8]; % Gray
                % ===== 4. If provided, add a fixed time offset to stimulation trigger events =====
                if OffsetTime ~= 0
                    sEventStim.times = round((sEventStim.times + OffsetTime) .* sFreq) ./ sFreq;
                end
                % Store stim event in sEvents
                iEvt = find(strcmpi({sEvents.label}, sEventStim.label));
                if isempty(iEvt)
                    iEvt = length(sEvents) + 1;
                end
                sEvents(iEvt) = sEventStim;

                % ===== 5. If provided, splits detected stimulation trigger events into ODD and EVEN instances =====
                if EvtAddOddEven
                    % Create 'ODD' event from odd-numbered stimulation trigger pulses
                    sEventOdd = db_template('event');
                    sEventOdd.label  = sprintf('ODD %s #%d', stimStartStopLabels{iStimStartStop}, iTime);
                    sEventOdd.times = sEventStim.times(1:2:end);
                    sEventOdd.epochs = sEventStim.epochs(1:2:end);
                    sEventOdd.color = [0.9, 0, 0]; % Red
                    % Store odd stim events in sEvents
                    iEvt = find(strcmpi({sEvents.label}, sEventOdd.label));
                    if isempty(iEvt)
                        iEvt = length(sEvents) + 1;
                    end
                    sEvents(iEvt) = sEventOdd;
                    % Create 'EVEN' event from even-numbered stimulation trigger pulses
                    sEventEven = db_template('event');
                    sEventEven.label  = sprintf('EVEN %s #%d', stimStartStopLabels{iStimStartStop}, iTime);
                    sEventEven.times = sEventStim.times(2:2:end);
                    sEventEven.epochs = sEventStim.epochs(2:2:end);
                    sEventEven.color = [ 0, 0, 0.9]; % Blue
                    % Store even stim events in sEvents
                    iEvt = find(strcmpi({sEvents.label}, sEventEven.label));
                    if isempty(iEvt)
                        iEvt = length(sEvents) + 1;
                    end
                    sEvents(iEvt) = sEventEven;
                end
            end
        end

        % Save events
        if isRaw
            DataMat.F.events = sEvents;
        else
            DataMat.Events = sEvents;
        end
        % Add history entry
        DataMat = bst_history('add', DataMat, 'NK', ['DESCRIPTION']);
        % Only save changes if something was change
        bst_save(file_fullpath(sInputs(iFile).FileName), DataMat, [], 1);
        % Return the processed raw file
        OutputFiles{end+1} = sInputs(iFile).FileName;
    end
end