function varargout = process_evt_detect_threshold( varargin )
% PROCESS_EVT_DETECT_THRESHOLD: Event detection based on a set threshold for a group of recordings file
%
% USAGE:  OutputFiles = process_evt_detect_threshold('Run', sProcess, sInputs)
%                 evt = process_evt_detect_threshold('Compute', F, TimeVector, OPTIONS)
%             OPTIONS = process_evt_detect_threshold('Compute')                         % Get the default options structure

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
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
% Authors: Elizabeth Bock, Francois Tadel, 2015-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Detect events above threshold';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 45;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/VisualSingle?highlight=%28Detect+events+above+threshold%29#Artifact_correction_with_SSP';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'raw', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
	% Notice
    sProcess.options.notice.Comment = ['This process creates <B>extended events</B> to indicate all the time<BR>' ... 
                                       'samples where the signal is above a given amplitude threshold.<BR>' ...
                                       'For creating <B>simple events</B>, use one of the following processes:<BR>' ...
                                       '"Detect custom events" or "Detect analog triggers".<BR><BR>'];
    sProcess.options.notice.Type    = 'label';
    % Event name
    sProcess.options.eventname.Comment = 'Event name: ';
    sProcess.options.eventname.Type    = 'text';
    sProcess.options.eventname.Value   = 'artifact';
    % Separator
    sProcess.options.separator.Type = 'separator';
    sProcess.options.separator.Comment = ' ';
    % Channel name
    sProcess.options.channelname.Comment = 'Channel name: ';
    sProcess.options.channelname.Type    = 'channelname';
    sProcess.options.channelname.Value   = '';
    % Channel name comment
    sProcess.options.channelhelp.Comment = '<I><FONT color="#777777">You can use the montage syntax here: "ch1, -ch2"</FONT></I>';
    sProcess.options.channelhelp.Type    = 'label';
    % Time window
    sProcess.options.timewindow.Comment = 'Time window:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    % Threshold maximum
    sProcess.options.thresholdMAX.Comment = 'Maximum threshold: ';
    sProcess.options.thresholdMAX.Type    = 'value';
    sProcess.options.thresholdMAX.Value   = {0.00, '', 2};
    % units
    sProcess.options.label1.Comment = '<BR><U><B>Threshold Units</B></U>:';
    sProcess.options.label1.Type    = 'label';
    sProcess.options.units.Comment = {'None: 10<SUP>0</SUP>', 'mV: 10<SUP>-3</SUP>', 'uV: 10<SUP>-6</SUP>', 'fT: 10<SUP>-15</SUP>', ''};
    sProcess.options.units.Type    = 'radio_line';
    sProcess.options.units.Value   = 1;
    % Filter
    sProcess.options.label2.Comment = '<BR><U><B>Filter signal before detection:</B></U>';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.bandpass.Comment = 'Frequency band: ';
    sProcess.options.bandpass.Type    = 'range';
    sProcess.options.bandpass.Value   = {[], 'Hz', 2};
    % Use absolute value
    sProcess.options.isAbsolute.Comment = 'Use absolute value of signal';
    sProcess.options.isAbsolute.Type    = 'checkbox';
    sProcess.options.isAbsolute.Value   = 0;
    % Remove DC
    sProcess.options.isDCremove.Comment = 'Remove DC offset';
    sProcess.options.isDCremove.Type    = 'checkbox';
    sProcess.options.isDCremove.Value   = 0;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = ['Detect: ', sProcess.options.eventname.Value];
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>   
    % ===== GET OPTIONS =====
    % Event name
    evtName = strtrim(sProcess.options.eventname.Value);
    chanName = strtrim(sProcess.options.channelname.Value);
    if isempty(evtName) || isempty(chanName)
        bst_report('Error', sProcess, [], 'Event and channel names must be specified.');
        OutputFiles = {};
        return;
    end
    % Ignore bad segments
    % => Consider that if the event name contains "bad", we need to include the bad segments. If not, we ignore them.
    isIgnoreBad = panel_record('IsEventBad', evtName);
    % Prepare options structure for the detection function
    OPTIONS = Compute();
    OPTIONS.thresholdMAX = sProcess.options.thresholdMAX.Value{1};
    OPTIONS.isAbsolute = sProcess.options.isAbsolute.Value;
    OPTIONS.isDCremove   = sProcess.options.isDCremove.Value;
    OPTIONS.bandpass     = sProcess.options.bandpass.Value{1};
    iUnits = sProcess.options.units.Value;
    switch iUnits
        case 1
            OPTIONS.thresholdMAX = OPTIONS.thresholdMAX * 1;
        case 2
            OPTIONS.thresholdMAX = OPTIONS.thresholdMAX * 1e-3;
        case 3
            OPTIONS.thresholdMAX = OPTIONS.thresholdMAX * 1e-6;
        case 4
            OPTIONS.thresholdMAX = OPTIONS.thresholdMAX * 1e-15;
    end
    
    % Time window to process
    if isfield(sProcess.options, 'timewindow') && isfield(sProcess.options.timewindow, 'Value') && iscell(sProcess.options.timewindow.Value) && ~isempty(sProcess.options.timewindow.Value)
        TimeWindow = sProcess.options.timewindow.Value{1};
    else
        TimeWindow = [];
    end
    
    % Get current progressbar position
    progressPos = bst_progress('get');
    nEvents = 0;
    nTotalOcc = 0;
    
    % For each file
    iOk = false(1,length(sInputs));
    for iFile = 1:length(sInputs)
        % ===== GET DATA =====
        % Progress bar
        bst_progress('text', 'Reading channel to process...');
        bst_progress('set', progressPos + round(iFile / length(sInputs) / 3 * 100));
        % Load the raw file descriptor
        isRaw = strcmpi(sInputs(iFile).FileType, 'raw');
        if isRaw
            DataMat = in_bst_data(sInputs(iFile).FileName, 'F', 'Time');
            sFile = DataMat.F;
        else
            DataMat = in_bst_data(sInputs(iFile).FileName, 'Time');
            sFile = in_fopen(sInputs(iFile).FileName, 'BST-DATA');
        end
        % Load channel file
        ChannelMat = in_bst_channel(sInputs(iFile).ChannelFile);
        % Process only continuous files
        if ~isempty(sFile.epochs)
            bst_report('Error', sProcess, sInputs(iFile), 'This function can only process continuous recordings (no epochs).');
            continue;
        end
        
        % Get channel to process: multiple channels
        if any(chanName == ',')
            [iChannels, iChanWeights] = process_evt_detect('ParseChannelMontage', chanName, {ChannelMat.Channel.Name});
            if isempty(iChannels)
                bst_report('Error', sProcess, sInputs(iFile), ['Montage "' chanName '" could not be interpreted. Please check channel names.']);
                continue;
            end
        % One channel
        else
            iChannels = find(strcmpi({ChannelMat.Channel.Name}, chanName));
            if isempty(iChannels)
                bst_report('Error', sProcess, sInputs(iFile), ['Channel "' chanName '" not found in the channel file.']);
                continue;
            elseif (length(iChannels) > 1)
                bst_report('Error', sProcess, sInputs(iFile), ['Found more than one channel with name "' chanName '" in the channel file.']);
                continue;
            end
            iChanWeights = 1;
        end
        
        % Read channel to process
        if ~isempty(TimeWindow)
            SamplesBounds = sFile.prop.samples(1) + bst_closest(TimeWindow, DataMat.Time) - 1;
        else
            SamplesBounds = [];
        end
        [F, TimeVector] = in_fread(sFile, ChannelMat, 1, SamplesBounds, iChannels);
        % Apply weights if reading multiple channels
        if (length(iChannels) > 1)
            F = iChanWeights * F;
        end
        % If nothing was read
        if isempty(F) || (length(TimeVector) < 2)
            bst_report('Error', sProcess, sInputs(iFile), 'Time window is not valid.');
            continue;
        end
        
        % ===== DETECT PEAKS =====
        % Progress bar
        bst_progress('text', 'Detecting peaks...');
        bst_progress('set', progressPos + round(2 * iFile / length(sInputs) / 3 * 100));
        % Perform detection
        detectedEvt = Compute(F, TimeVector, OPTIONS);

        % ===== CREATE EVENTS =====
        sEvent = [];
        % Basic events structure
        if ~isfield(sFile, 'events') || isempty(sFile.events)
            sFile.events = repmat(db_template('event'), 0);
        end
        % Process each event type separately
        for i = 1:length(detectedEvt)
            % Event name
            if (i > 1)
                newName = sprintf('%s%d', evtName, i);
            else
                newName = evtName;
            end
            % Get the event to create
            iEvt = find(strcmpi({sFile.events.label}, newName));
            % Existing event: reset it
            if ~isempty(iEvt)
                sEvent = sFile.events(iEvt);
                sEvent.epochs  = [];
                sEvent.samples = [];
                sEvent.times   = [];
                sEvent.reactTimes = [];
            % Else: create new event
            else
                % Initialize new event
                iEvt = length(sFile.events) + 1;
                sEvent = db_template('event');
                sEvent.label = newName;
                % Get the default color for this new event
                sEvent.color = panel_record('GetNewEventColor', iEvt, sFile.events);
            end
            % Times, samples, epochs
            sEvent.times   = detectedEvt{i};
            sEvent.samples = round(sEvent.times .* sFile.prop.sfreq);
            sEvent.epochs  = ones(1, size(sEvent.times,2));
            % Add to events structure
            sFile.events(iEvt) = sEvent;
            nEvents = nEvents + 1;
            nTotalOcc = nTotalOcc + size(sEvent.times, 2);
        end
        
        % ===== SAVE RESULT =====
        % Progress bar
        bst_progress('text', 'Saving results...');
        bst_progress('set', progressPos + round(3 * iFile / length(sInputs) / 3 * 100));
        % Only save changes if something was detected
        if ~isempty(sEvent)
            % Report changes in .mat structure
            if isRaw
                DataMat.F = sFile;
            else
                DataMat.Events = sFile.events;
            end
            DataMat = rmfield(DataMat, 'Time');
            % Save file definition
            bst_save(file_fullpath(sInputs(iFile).FileName), DataMat, 'v6', 1);
            % Report number of detected events
            bst_report('Info', sProcess, sInputs(iFile), sprintf('%s: %d events detected in %d categories', chanName, nTotalOcc, nEvents));
        else
            bst_report('Warning', sProcess, sInputs(iFile), ['No event detected on channel "' chanName '". Please check the signal quality.']);
        end
        iOk(iFile) = true;
    end
    % Return all the input files
    OutputFiles = {sInputs(iOk).FileName};
end


%% ===== PERFORM DETECTION =====
% USAGE:      evt = Compute(F, TimeVector, OPTIONS=[])
%         OPTIONS = Compute()                            % Get the default options structure
function evt = Compute(F, TimeVector, OPTIONS)
    % Options structure
    defOptions = struct('thresholdMAX',  0, ...     % Maximum threshold value 
                        'bandpass', [], ...         % bandpass filter data before detection
                        'isAbsolute', 0, ...        % If 1, the max point defines the event, else, first thresh crossing defines the event 
                        'isDCremove', 0);           % If 1, remove the DC offset of the signal before detection
    % Parse inputs
    if (nargin == 0)
        evt = defOptions;
        return;
    end
    % Copy the missing parameters
    OPTIONS = struct_copy_fields(OPTIONS, defOptions, 0);
    % Sampling frequency
    sFreq = 1 ./ (TimeVector(2) - TimeVector(1));
    % Initialize output
    evt = {};

    
    %% ===== DETECT EVENTS ABOVE THRESHOLD =====
     % Filter recordings
    if ~isempty(OPTIONS.bandpass)
        F = process_bandpass('Compute', F, sFreq, OPTIONS.bandpass(1), OPTIONS.bandpass(2), 'bst-fft-fir', 1);
    end
    
    % Remove DC offset with detrending
    if OPTIONS.isDCremove 
        % Remove the linear trend
        nTime = length(F);
        iTime = 1:nTime;
        % Basis functions
        x = [ones(1,nTime); 0:nTime-1];
        % Estimate the contribution of the basis functions
        % beta = dat(:,iTime)/x(:,iTime); <-this leads to numerical issues, even in simple examples
        invxcov = inv(x(:,iTime) * x(:,iTime)');
        beta    = F(:,iTime) * x(:,iTime)' * invxcov;
        % Remove the estimated basis functions
        F = F - beta*x;
    end
    
    % Absolute valuse
    if OPTIONS.isAbsolute
        F = abs(F);
    end
        
    % Threshold mask
    threshMask = zeros(size(F));
    % Find all the indices that are above the threshold
    threshMask(F > OPTIONS.thresholdMAX) = 1;

    % Nothing detected: exit
    if sum(threshMask) < 1
        return;
    end
    
    % Group time points into extended events
    % group events that occur withing 10ms of each other
    minNewEvent = round(sFreq*.02);
    
    diffThreshMask = diff([0 threshMask 0]);
    startEve = find(diffThreshMask == 1);
    endEve = find(diffThreshMask == -1) -1;
    iEve = 1;
    while iEve < length(startEve)-1
        if startEve(iEve + 1) - endEve(iEve) <= minNewEvent
            % combine the two events
            endEve(iEve) = endEve(iEve + 1);
            startEve(iEve+1) = [];
            endEve(iEve+1) = [];
        else
            iEve = iEve + 1;
        end
    end

    % Find times of the events
    evt = {[TimeVector(startEve); TimeVector(endEve)]};
  
end




