function varargout = process_load_spes_nk( varargin )
% PROCESS_LOAD_SPES_NK: Import Single-Pulse Electrical Stimulation (SPES) blocks 
% from raw data recorded using Nihon Kohden system and detect stimulation triggers on 
% the selected stimulation channel
%
% USAGE:
%   OutputFiles = process_load_spes_nk('Run', sProcess, sInputs)

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
sProcess.Comment     = 'Load SPES (Nihon Kohden)';
sProcess.Category    = 'Custom';
sProcess.SubGroup    = 'Stimulation';
sProcess.Index       = 901;
% Definition of the input accepted by this process
sProcess.InputTypes  = {'raw'};
sProcess.OutputTypes = {'data'};
sProcess.nInputs     = 1;
sProcess.nMinFiles   = 1;
% Stimulation channel name
sProcess.options.stimchan.Comment = 'Stimulation channel: ';
sProcess.options.stimchan.Type    = 'text';
sProcess.options.stimchan.Value   = 'DC10';
% Custom stimulation start event label
sProcess.options.stimstartlabel.Comment = 'Custom stimulation start event label (empty=''Stim Start''): ';
sProcess.options.stimstartlabel.Type    = 'text';
sProcess.options.stimstartlabel.Value   = 'SB';
% Custom stimulation stop event label
sProcess.options.stimstoplabel.Comment = 'Custom stimulation stop event label (empty=''Stim Stop''): ';
sProcess.options.stimstoplabel.Type    = 'text';
sProcess.options.stimstoplabel.Value   = 'SE';
% Buffer time around stimulation block
sProcess.options.buffertime.Comment = 'Buffer time around stimulation block: ';
sProcess.options.buffertime.Type    = 'value';
sProcess.options.buffertime.Value   = {5,'s', 2};
% Stimulation triggers detection method
sProcess.options.label1.Comment = 'Stimulation triggers detection method:';
sProcess.options.label1.Type    = 'label';
sProcess.options.triggerdetectmethod.Comment = {'Analog', 'TTL'};
sProcess.options.triggerdetectmethod.Type    = 'radio';
sProcess.options.triggerdetectmethod.Value   = 1;
% Add 'ODD' and 'EVEN' events to stimulation blocks
sProcess.options.evtaddoddeven.Comment = 'Add ''ODD'' and ''EVEN'' events (alternating monophasic stimulation)';
sProcess.options.evtaddoddeven.Type    = 'checkbox';
sProcess.options.evtaddoddeven.Value   = 1;
end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end

%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput) %#ok<DEFNU>
    % Initialize output
    OutputFiles = {};

    % Get proccess options
    StimChan            = sProcess.options.stimchan.Value;
    StimStartLabel      = sProcess.options.stimstartlabel.Value;
    StimStopLabel       = sProcess.options.stimstoplabel.Value;
    BufferTime          = sProcess.options.buffertime.Value{1};
    TriggerDetectMethod = sProcess.options.triggerdetectmethod.Comment{sProcess.options.triggerdetectmethod.Value};
    EvtAddOddEven       = sProcess.options.evtaddoddeven.Value;
     
    % Check whether custom labels were provided
    isUpdateStimStartLabel = ~isempty(StimStartLabel);
    isUpdateStimStopLabel  = ~isempty(StimStopLabel);    
    % Use default labels if options are empty
    if ~isUpdateStimStartLabel
        StimStartLabel = 'Stim Start';
    end
    if ~isUpdateStimStopLabel
        StimStopLabel = 'Stim Stop';
    end

    % Update channel types
    ChannelFile = file_fullpath(sInput.ChannelFile);
    UpdateChannelTypesNk(ChannelFile);

    % Load raw file
    rawDataFile = file_fullpath(sInput.FileName);
    rawData = load(rawDataFile);

    % Find stimulation start and stop events
    eventLabels = {rawData.F.events.label};
    iStart = find(strncmp(eventLabels, 'Stim Start', 10));
    iStop  = find(strncmp(eventLabels, 'Stim Stop', 9));  
    % Extract event times
    startTimes = [rawData.F.events(iStart).times];
    stopTimes  = [rawData.F.events(iStop).times];
    % Check for mismatched start/stop markers and trim unmatched events
    if length(startTimes) ~= length(stopTimes)
        if startTimes(end) > stopTimes(end)
            fprintf('LOAD_SPES_NK> Missing last stop, therefore deleting last start\n');
            startTimes(end) = [];
            iStart(end)     = [];
        end
        if stopTimes(1) < startTimes(1)
            fprintf('LOAD_SPES_NK> Missing first start, therefore deleting first stop\n');
            stopTimes(1) = [];
            iStop(1)     = [];
        end
    end    
    % Estimate a uniform epoch duration from the longest start-stop interval
    durations = diff([startTimes; stopTimes]);
    duration  = max(durations);
    duration  = round(duration / BufferTime) * BufferTime;
    % Define epoch window
    preStim  = -BufferTime;
    postStim = duration + BufferTime;
    % Trim preStim if the buffer would start before the recording
    if any(([rawData.F.events(iStart).times] + preStim) < rawData.Time(1))
        preStim = -min([rawData.F.events(iStart).times] - rawData.Time(1));
        fprintf('LOAD_SPES_NK> Prestim buffer length trimmed to %.1f seconds due to recording constraints\n', preStim);
    end
    % Trim postStim if the buffer would extend beyond the recording
    if any(([rawData.F.events(iStart).times] + postStim) > rawData.Time(end))
        postStim = min(rawData.Time(end) - [rawData.F.events(iStart).times]);
        fprintf('LOAD_SPES_NK> Poststim buffer length trimmed to %.1f seconds due to recording constraints\n', postStim);
    end
    
    % Import buffered epochs around stimulation start events
    fprintf('LOAD_SPES_NK> Importing buffers of length %.0f seconds plus %.0f seconds pre and post stimulation...', duration, BufferTime);  
    startEvents = [sprintf('%s', eventLabels{iStart(1)}), sprintf(', %s', eventLabels{iStart(2:end)})];
    sFilesStimStart = bst_process('CallProcess', 'process_import_data_event', rawDataFile, [], ...
        'subjectname', sInput.SubjectName, ...
        'condition',   sInput.Condition(5:end), ... % Exclude '@raw' from condition name
        'timewindow',  [], ...
        'eventname',   startEvents, ...
        'epochtime',   [preStim, postStim], ...
        'createcond',  0, ...
        'ignoreshort', 1, ...
        'usectfcomp',  1, ...
        'usessp',      1, ...
        'freq',        [], ...
        'baseline',    []);
    fprintf('Done!\n');
    
    % Update the 'Stim Start' stimulation block's comment if custom label was provided
    if isUpdateStimStartLabel
        bst_progress('start', 'Process', sprintf('Renaming ''Stim Start'' with custom label ''%s''...', StimStartLabel), 0, 100);
        fprintf('LOAD_SPES_NK> Renaming ''Stim Start'' with custom label ''%s''...', StimStartLabel);
        for iFile = 1:length(sFilesStimStart)
            % Show progress
            progressPrc = round(100 .* iFile ./ length(sFilesStimStart));
            bst_progress('set', progressPrc);   
            % Update displayed comment
            sFilesStimStart(iFile).Comment = strrep(sFilesStimStart(iFile).Comment, 'Stim Start', StimStartLabel);    
            % Save back to disk
            bst_save(file_fullpath(sFilesStimStart(iFile).FileName), sFilesStimStart(iFile), 'v7', 1);
        end
        % Refresh this condition/study in the tree
        [~, iStudy] = bst_get('DataFile', file_fullpath(sFilesStimStart(1).FileName));
        db_reload_studies(iStudy);
        fprintf('Done!\n');
    end
    
    % Detect stimulation triggers on the selected channel
    fprintf('LOAD_SPES_NK> Detecting ''%s'' stimulation triggers on the selected channel...', TriggerDetectMethod);
    switch TriggerDetectMethod
        case 'TTL'
            % Detect TTL peaks directly from an analog stimulation channel
            sFilesStimStart = bst_process('CallProcess', 'process_evt_read', sFilesStimStart, [], ...
                'stimchan',  StimChan, ...
                'trackmode', 3, ...          % TTL: detect peaks of 5V/12V on an analog channel (baseline=0V)
                'zero',      0);
        case 'Analog'
            % Detect analog stimulation triggers
            sFilesStimStart = bst_process('CallProcess', 'process_evt_detect_analog', sFilesStimStart, [], ...
                'eventname',   StimChan, ...
                'channelname', StimChan, ...
                'threshold',   1, ...        % Standard deviations from noise
                'blanking',    0.8, ...      % Minimum duration between two events (in seconds)
                'highpass',    0, ...
                'lowpass',     0, ...
                'refevent',    '', ...
                'isfalling',   0, ...
                'ispullup',    0, ...        % No DC offset removal
                'isclassify',  0);
    end
    fprintf('Done!\n');

    % Update events in stimulation block
    bst_progress('start', 'Process', 'Updating events in stimulation blocks...', 0, 100);
    fprintf('LOAD_SPES_NK> Updating events in stimulation blocks...');
    for iFile = 1:length(sFilesStimStart)
        % Show progress
        progressPrc = round(100 .* iFile ./ length(sFilesStimStart));
        bst_progress('set', progressPrc);
        % Load events from the imported file
        fileEvents = load(file_fullpath(sFilesStimStart(iFile).FileName), 'Events');
        % Update 'Stim Start' event label if custom label was provided
        if isUpdateStimStartLabel
            iStimStart = find(strncmp({fileEvents.Events.label}, 'Stim Start', 10));
            fileEvents.Events(iStimStart).label = strrep(fileEvents.Events(iStimStart).label, 'Stim Start', StimStartLabel);
        end
        % Update 'Stim Stop' event label if custom label was provided
        if isUpdateStimStopLabel
            iStimStop  = find(strncmp({fileEvents.Events.label}, 'Stim Stop', 9));
            fileEvents.Events(iStimStop).label = strrep(fileEvents.Events(iStimStop).label, 'Stim Stop', StimStopLabel);
        end       
        % Find the stimulation event      
        iStimEvent = find(strncmp({fileEvents.Events.label}, StimChan, length(StimChan)));
        if isempty(iStimEvent)
            bst_report('Error', sProcess, [], ['No ' StimChan ' event found']);
            return;
        end
        % Get the label to be used for updating the event names
        % (e.g. extract "T1-T2 4.0 #1" from "Stim Start T1-T2 4.0 (#1)")
        stimSiteLabel = regexp(sFilesStimStart(iFile).Comment, sprintf('^%s (.*) \\((#\\d+)\\)$', StimStartLabel), 'tokens', 'once');
        % Rename the stimulation event to reflect the stimulation site               
        fileEvents.Events(end).label = sprintf('STIM %s %s', stimSiteLabel{1}, stimSiteLabel{2});
        if EvtAddOddEven
            % === Add alternating monophasic events to stimulation blocks (ODD and EVEN) ===
            % Duplicate the detected event twice: one copy each for creating ODD and EVEN pulses
            fileEvents.Events(end+(1:2)) = [fileEvents.Events(iStimEvent), fileEvents.Events(iStimEvent)];
            % Rename duplicated events
            fileEvents.Events(end-1).label = sprintf('ODD %s %s', stimSiteLabel{1}, stimSiteLabel{2});
            fileEvents.Events(end).label   = sprintf('EVEN %s %s', stimSiteLabel{1}, stimSiteLabel{2});
            % Keep alternating pulses in each event list
            fileEvents.Events(end-1).times(2:2:end)  = []; % ODD
            fileEvents.Events(end).times(1:2:end)    = []; % EVEN
            fileEvents.Events(end-1).epochs(2:2:end) = []; % ODD
            fileEvents.Events(end).epochs(1:2:end)   = []; % EVEN                                
            % Update colors
            fileEvents.Events(end-2).color = [0.8, 0.8, 0.8]; % STIM (gray)
            fileEvents.Events(end-1).color = [0.9,   0,   0]; % ODD (red)
            fileEvents.Events(end).color   = [  0,   0, 0.9]; % EVEN (blue)
        end            
        % Save changes
        if isUpdateStimStartLabel || isUpdateStimStopLabel || EvtAddOddEven
            bst_save(file_fullpath(sFilesStimStart(iFile).FileName), fileEvents, 'v7', 1);
        end

        OutputFiles{end+1} = sFilesStimStart(iFile).FileName;
    end
    fprintf('Done!\n');
    bst_progress('stop');
end

%% ===== UPDATE NIHON KOHDEN CHANNEL TYPES =====
% Update channel types for standard Nihon Kohden recordings
function UpdateChannelTypesNk(ChannelFile)
    ChannelMat = load(ChannelFile);
    for iChan = 1:numel(ChannelMat.Channel)
        % Read current channel once
        Channel = ChannelMat.Channel(iChan);
        % Update type from channel name
        ChanName = lower(Channel.Name);
        if strncmp(ChanName, 'ekg', 3)
            Channel.Type = 'EKG';
        elseif strncmp(ChanName, 'dc', 2)
            Channel.Type = 'STIM';
        elseif strncmp(ChanName, 'ref', 3) || strncmp(ChanName, 'cz', 2)
            Channel.Type = 'REF';
        elseif strncmp(ChanName, 'rtth', 4)
            Channel.Type = 'RTTH';
        elseif strncmp(ChanName, 'rtdelt', 6)
            Channel.Type = 'RTDELT';
        elseif strncmp(ChanName, 'rfc',  3) || ...
               strncmp(ChanName, 'loc',  3) || ...
               strncmp(ChanName, 'roc',  3) || ...
               strncmp(ChanName, 'mark', 4) || ...
               strncmp(ChanName, '-',    1) || ...
               strncmp(ChanName, 'tp9',  3) || ...
               strncmp(ChanName, 'pz',   2) || ...
               strncmp(ChanName, 'pol',  3)
            Channel.Type = 'UNKNOWN';
        end
        % Known special cases by channel index
        if (iChan == 20) % E
            Channel.Type = 'UNKNOWN';
        end        
        % Numeric channel names are treated as unknown
        if ~isnan(str2double(Channel.Name))
            Channel.Type = 'UNKNOWN';
        end        
        % Write updated channel back
        ChannelMat.Channel(iChan) = Channel;
    end
    bst_save(ChannelFile, ChannelMat, 'v7');
end