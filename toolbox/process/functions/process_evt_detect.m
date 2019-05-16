function varargout = process_evt_detect( varargin )
% PROCESS_EVT_DETECT: Artifact rejection for a group of recordings file
%
% USAGE:  OutputFiles = process_evt_detect('Run', sProcess, sInputs)
%                 evt = process_evt_detect('Compute', F, TimeVector, OPTIONS, Fmask)
%                 evt = process_evt_detect('Compute', F, TimeVector, OPTIONS)
%             OPTIONS = process_evt_detect('Compute')                                : Get the default options structure
%   [iCh, iChWeights] = process_evt_detect('ParseChannelMontage', strMontage, ChannelNames)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Elizabeth Bock, Francois Tadel, 2011-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Detect custom events';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 45;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ArtifactsDetect#Custom_detection';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'raw', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Event name
    sProcess.options.eventname.Comment = 'Event name: ';
    sProcess.options.eventname.Type    = 'text';
    sProcess.options.eventname.Value   = 'cardiac';
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
    % Filter
    sProcess.options.bandpass.Comment = 'Frequency band: ';
    sProcess.options.bandpass.Type    = 'range';
    sProcess.options.bandpass.Value   = {[10, 40], 'Hz', 2};
    % Threshold
    sProcess.options.threshold.Comment = 'Amplitude threshold: ';
    sProcess.options.threshold.Type    = 'value';
    sProcess.options.threshold.Value   = {4, ' x std', 2};
    % Blanking period
    sProcess.options.blanking.Comment = 'Min duration between two events: ';
    sProcess.options.blanking.Type    = 'value';
    sProcess.options.blanking.Value   = {0.5, 'ms', []};
    % Examples: EOG, ECG
    sProcess.options.example.Comment = ['<BR>&nbsp; Examples:<BR>' ...
                                        '&nbsp;&nbsp;&nbsp;- EOG: [1.5-15] Hz, 2 x Std, min: 800ms<BR>' ...
                                        '&nbsp;&nbsp;&nbsp;- ECG: [10-40] Hz, 4 x Std, min: 500ms'];
    sProcess.options.example.Type    = 'label';
    % Separator
    sProcess.options.sep2.Type = 'separator';
    sProcess.options.sep2.Comment = ' ';
    % Ignore noisy segments
    sProcess.options.isnoisecheck.Comment = 'Ignore noisy segments';
    sProcess.options.isnoisecheck.Type    = 'checkbox';
    sProcess.options.isnoisecheck.Value   = 1;
    % Enable classification
    sProcess.options.isclassify.Comment = 'Enable classification';
    sProcess.options.isclassify.Type    = 'checkbox';
    sProcess.options.isclassify.Value   = 1;
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
    % Ignore bad segments? (not in the options: always enforced)
    isIgnoreBad = 1;
    % Prepare options structure for the detection function
    OPTIONS = Compute();
    OPTIONS.threshold    = sProcess.options.threshold.Value{1};
    OPTIONS.bandpass     = sProcess.options.bandpass.Value{1};
    OPTIONS.blanking     = sProcess.options.blanking.Value{1};
    OPTIONS.isnoisecheck = sProcess.options.isnoisecheck.Value;
    OPTIONS.isclassify   = sProcess.options.isclassify.Value;
    if isfield(sProcess.options,'maxcross')
        OPTIONS.maxcross   = sProcess.options.maxcross.Value;
    end
    if isfield(sProcess.options,'ismaxpeak')
        OPTIONS.ismaxpeak   = sProcess.options.ismaxpeak.Value;
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
            [iChannels, iChanWeights] = ParseChannelMontage(chanName, {ChannelMat.Channel.Name});
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
            SamplesBounds = round(sFile.prop.times(1) .* sFile.prop.sfreq) + bst_closest(TimeWindow, DataMat.Time) - 1;
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
        
        % ===== BAD SEGMENTS =====
        % If ignore bad segments
        Fmask = [];
        if isIgnoreBad
            % Get list of bad segments in file
            badSeg = panel_record('GetBadSegments', sFile);
            % Adjust with beginning of file
            badSeg = badSeg - round(sFile.prop.times(1) .* sFile.prop.sfreq) + 1;
            if ~isempty(badSeg)
                % Create file mask
                Fmask = true(size(F));
                % Loop on each segment: mark as bad
                for iSeg = 1:size(badSeg, 2)
                    Fmask(badSeg(1,iSeg):badSeg(2,iSeg)) = false;
                end
            end
        end
        
        % ===== DETECT PEAKS =====
        % Progress bar
        bst_progress('text', 'Detecting peaks...');
        bst_progress('set', progressPos + round(2 * iFile / length(sInputs) / 3 * 100));
        % Perform detection
        detectedEvt = Compute(F, TimeVector, OPTIONS, Fmask);

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
                sEvent.epochs     = [];
                sEvent.times      = [];
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
            sEvent.times    = detectedEvt{i};
            sEvent.epochs   = ones(1, size(sEvent.times,2));
            sEvent.channels = cell(1, size(sEvent.times, 2));
            sEvent.notes    = cell(1, size(sEvent.times, 2));
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
% USAGE:      evt = Compute(F, TimeVector, OPTIONS, Fmask)
%             evt = Compute(F, TimeVector, OPTIONS)
%         OPTIONS = Compute()                              : Get the default options structure
function evt = Compute(F, TimeVector, OPTIONS, Fmask)
    % Options structure
    defOptions = struct('bandpass',     [10, 40], ...   % Filter the signal before performing the detection, [highpass, lowpass]
                        'threshold',    2, ...          % Create an event if the value goes > threshold * standard deviation
                        'blanking',     .5, ...         % No events can be detected during the blanking period
                        'maxcross',     10, ...         % Max number of bounces accepted in one blanking period (to ignore high-frequency oscillations)
                        'ampmin',       0, ...          % Minimum absolute value accepted for a detected peak
                        'isnoisecheck', 1, ...          % If 1, perform a noise quality check on the detected events
                        'noisethresh',  2.5, ...        %    => Noise threshold (x standard deviation or the rms)
                        'isclassify',   1, ...          % If 1, classify the events in different morphological categories
                        'corrval',      .8, ...         %    => Correlation threshold
                        'ismaxpeak',    1);             % If 1, the max point defines the event, else, first thresh crossing defines the event 
    % Parse inputs
    if (nargin == 0)
        evt = defOptions;
        return;
    end
    if (nargin < 4)
        Fmask = [];
    end
    % Copy the missing parameters
    OPTIONS = struct_copy_fields(OPTIONS, defOptions, 0);
    % Sampling frequency
    sFreq = 1 ./ (TimeVector(2) - TimeVector(1));
    % Convert blanking period to number of samples
    blankSmp = round(OPTIONS.blanking * sFreq);
    % Initialize output
    evt = {};
    % If blanking period longer than the signal to process: exit
    if (blankSmp >= length(F))
        bst_report('Warning', 'process_evt_detect', [], 'The blanking period between two events is longer than the signal. Cannot perform detection.');
        return;
    end
    
    % ===== FILTER RECORDINGS =====
    % Filter recordings
    if ~isempty(OPTIONS.bandpass)
        [F, FiltSpec] = process_bandpass('Compute', F, sFreq, OPTIONS.bandpass(1), OPTIONS.bandpass(2), 'bst-hfilter-2019', 0);
        smpTransient = round(FiltSpec.transient * sFreq);
    else
        FiltSpec = [];
        smpTransient = 0;
    end
    % Absolute value
    Fabs = abs(F);
    % Remove the bad bad segments from the signal (if any)
    if ~isempty(Fmask)
        Fsig = F(Fmask);
    else
        Fsig = F;
    end
    % Ignore the first and last 2% of the signal (in case of artifacts): Max of 2s
    nIgnore = size(Fsig,2) * 0.02 + smpTransient;
    nIgnore = round(min(2*sFreq, nIgnore));
    Fsig = Fsig(nIgnore:end-nIgnore+1);
    % Compute standard deviation
    stdF = std(Fsig);
    
    % ===== DETERMINE THRESHOLD =====
    % Theshold, in number of times the std
    threshVal = OPTIONS.threshold * stdF;
    % Find all the indices that are above the threshold
    iThresh = find(Fabs(1:end-blankSmp) > threshVal);
    % Nothing detected: exit
    if isempty(iThresh)
        return;
    end

    % ===== FIND EVENTS =====
    events = repmat(struct('index',[], 'rms',0), 0);
    i = 1;
    while ~isempty(i)
        % Get window
        iWindow = iThresh(i) + (0:blankSmp-1);
        % Find number of peaks
        iTh = find(Fabs(iWindow) > threshVal);
        diTh = diff(iTh);
        iPeak = find(diTh > 1);
        nPeaks = max(length(iPeak),1);
        if OPTIONS.ismaxpeak
            [FmaxWin, iMaxWin] = max(Fabs(iWindow));
        else %is first maximum after threshold crossing
            [FmaxWin, iMaxWin] = max(Fabs(iWindow(1:iPeak(1))));
        end
        % Event sample
        iMax = iThresh(i) + iMaxWin - 1;
        % If the peaks meet the criteria, this is an event
        if (nPeaks < OPTIONS.maxcross) && (Fabs(iMax) > OPTIONS.ampmin) && (isempty(Fmask) || (Fmask(iMax) == 1))
            iEvt = length(events) + 1;
            events(iEvt).rms   = sqrt(mean(Fabs(iWindow).^2));
            events(iEvt).index = iMax;
        end
        % Skip ahead past blank period
        i = find(iThresh > iMax + blankSmp, 1);
    end
    % Nothing detected: exit
    if isempty(events)
        return;
    end
    
    % ===== NOISE CHECKING =====
    if OPTIONS.isnoisecheck
        % Exclude events that do not meet noise criteria
        rms_mean = mean([events.rms]); % mean rms of all events
        rms_std = std([events.rms]); % std of rms for all events
        rms_thresh = rms_mean + (rms_std * OPTIONS.noisethresh); % rms threshold
        b = [events.rms] < rms_thresh; % find events less than rms threshold
        events = [events(b).index];
    else
        events = [events.index];
    end
    % Nothing detected: exit
    if isempty(events)
        return;
    end

    % ===== SORT BY MORPHOLOGY =====
    if OPTIONS.isclassify
        % Time window: [-200,200]ms
        iWindow = [round(-.2 .* sFreq), round(.2 .* sFreq)];
        % We need to remove all the events that are before or after this time window
        iRmEvt = find((events <= -iWindow(1)) | (events >= length(F) - iWindow(2)));
        if ~isempty(iRmEvt)
            events(iRmEvt) = [];
        end
        % No events left: exit
        if isempty(events)
            bst_report('Warning', 'process_evt_detect', [], 'The classification removed all the possible events.');
            return;
        end
        % Create first ref event type
        refEvt = F(events(1) + (iWindow(1):iWindow(2)));
        evtType = -1 * ones(size(events));
        evtCount = 1;
        % Loop through all events
        for i = 2:length(events)
            newEvt = F(events(i) + (iWindow(1):iWindow(2)));
            % Loop through all types
            for j = 1:size(refEvt,1)
                c = corrcoef(newEvt, refEvt(j,:));
                if (c(1,2) > OPTIONS.corrval)
                    evtType(i)  = j;
                    evtCount(j) = evtCount(j) + 1;
                    break;
                end
            end
            % If no match create a new type
            if (evtType(i) == -1)
                j = size(refEvt,1) + 1;
                refEvt(j,:) = newEvt;
                evtType(i)  = j;
                evtCount(j) = 1;
            end
        end
        % Keep only the bigger clusters
        if any(evtCount > 5)
            iOkType = find(evtCount > 5);
        else
            iOkType = 1:length(evtCount);
        end
        % Order by cluster size
        [tmp__, iSort] = sort(evtCount(iOkType), 'descend');
        iOkType = iOkType(iSort);

        % Create output cell array
        for i = 1:length(iOkType)
            evt{i} = TimeVector(events(evtType == iOkType(i)));
        end
    else
        evt = {TimeVector(events)};
    end
end


%% ===== PARSE CHANNEL MONTAGE =====
function [iChannels, iChanWeights] = ParseChannelMontage(strMontage, ChannelNames)
    % Split with ','
    sline = str_split(strMontage, ',');
    % Inialize list of channels
    iChannels = zeros(1, length(sline));
    iChanWeights = zeros(1, length(sline));
    % Loop on all the entries
    for i = 1:length(sline)
        % Split with '*'
        schan = str_split(strtrim(sline{i}), '*');
        % No multiplication: "Cz" or "-Cz" or "+Cz"
        if (length(schan) == 1)
            schan = strtrim(schan{1});
            if (schan(1) == '+')
                chfactor = 1;
                chname = schan(2:end);
            elseif (schan(1) == '-')
                chfactor = -1;
                chname = schan(2:end);
            else
                chfactor = 1;
                chname = schan;
            end
        % One multiplication: "<factor>*<chname>"
        elseif (length(schan) == 2)
            chfactor = str2num(strtrim(schan{1}));
            chname = strtrim(schan{2});
        else
            iChannels = [];
            iChanWeights = [];
            return;
        end
        % Look for existing channel name
        iChan = find(strcmpi(ChannelNames, chname));
        if isempty(iChan)
            iChannels = [];
            iChanWeights = [];
            return;
        end
        % If not referenced yet: add new channel entry
        iChannels(i) = iChan;
        iChanWeights(i) = chfactor;
    end
    % Sort channels
    [iChannels,I] = sort(iChannels);
    iChanWeights = iChanWeights(I);
end
            


