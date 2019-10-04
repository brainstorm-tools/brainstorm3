function varargout = process_evt_detect_badsegment( varargin )
% PROCESS_EVT_DETECT_BADSEGMENT: Artifact rejection for a group of recordings file
%
% USAGE:  OutputFiles = process_evt_detect_badsegment('Run', sProcess, sInputs)

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
% Authors: Elizabeth Bock, Francois Tadel, 2015-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Detect other artifacts';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 46;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/BadSegments#Automatic_detection';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'raw', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    
    % Time window
    sProcess.options.timewindow.Comment   = 'Time window: ';
    sProcess.options.timewindow.Type      = 'timewindow';
    sProcess.options.timewindow.Value     = [];
    % Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    % Threshold
    sProcess.options.threshold.Comment = {'1', '2', '3', '4', '5', 'Sensitivity: '};
    sProcess.options.threshold.Type    = 'radio_line';
    sProcess.options.threshold.Value   = 3;
    % Ignore noisy segments
    sProcess.options.isLowFreq.Comment = '1-7 Hz: <FONT color="#555555"><I>Eye movements, subject movements, dental work</I></FONT>';
    sProcess.options.isLowFreq.Type    = 'checkbox';
    sProcess.options.isLowFreq.Value   = 1;
    % Enable classification
    sProcess.options.isHighFreq.Comment = '40-240 Hz: <FONT color="#555555"><I>Muscle noise, sensor artifacts</I></FONT>';
    sProcess.options.isHighFreq.Type    = 'checkbox';
    sProcess.options.isHighFreq.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % ===== GET OPTIONS ===== 
    ThreshInd  = sProcess.options.threshold.Value;
    isLowFreq  = sProcess.options.isLowFreq.Value;
    isHighFreq = sProcess.options.isHighFreq.Value;
    SensorTypes = sProcess.options.sensortypes.Value;
    % Time window to process
    if isfield(sProcess.options, 'timewindow') && isfield(sProcess.options.timewindow, 'Value') && iscell(sProcess.options.timewindow.Value) && ~isempty(sProcess.options.timewindow.Value)
        TimeWindow = sProcess.options.timewindow.Value{1};
    else
        TimeWindow = [];
    end 
    
    % Constants
    percentBadThresh = 10;
    % Reference is the first 60 seconds
    LongRefTimeWindow = [0,60];
    % Time window to process
    RefTimeWindow = 1; %seconds
   
    % Option structure for function in_fread()
    ImportOptions = db_template('ImportOptions');
    ImportOptions.ImportMode = 'Time';
    ImportOptions.RemoveBaseline = 'no';
    % Get current progressbar position
    progressPos = bst_progress('get');

    % For each file
    iOk = false(1,length(sInputs));
    for iFile = 1:length(sInputs)
        % ===== GET DATA =====
        % Progress bar
        bst_progress('text', 'Reading channel to process...');
        % Load the raw file descriptor
        isRaw = strcmpi(sInputs(iFile).FileType, 'raw');
        if isRaw
            DataMat = in_bst_data(sInputs(iFile).FileName, 'F', 'Time');
            sFile = DataMat.F;
        else
            DataMat = in_bst_data(sInputs(iFile).FileName, 'Time');
            sFile = in_fopen(sInputs(iFile).FileName, 'BST-DATA');
        end
        % Get sampling frequency
        sfreq = sFile.prop.sfreq;
        fileSamples = round(sFile.prop.times .* sFile.prop.sfreq);
        % Select the time samples
        if isempty(TimeWindow)
            TimeSamples = round([DataMat.Time(1), DataMat.Time(end)]*sfreq);
        else
            TimeSamples = round(TimeWindow * sfreq);
        end

        % === LOAD CHANNEL FILE ===
        % Load channel file
        ChannelMat = in_bst_channel(sInputs(iFile).ChannelFile);
        % Process only continuous files
        if ~isempty(sFile.epochs)
            bst_report('Error', sProcess, sInputs(iFile), 'This function can only process continuous recordings (no epochs).');
            continue;
        end
        % Get channel to process
        iChannel = channel_find(ChannelMat.Channel, SensorTypes);
        iBadChannels = find(sFile.channelflag == -1);
        iChannel = setdiff(iChannel, iBadChannels);
        if isempty(iChannel)
            bst_report('Error', sProcess, sInputs(iFile), 'Channel name not found in the channel file.');
            continue;
        end

        % ===== GET REFERENCE ======
        SamplesBounds = round(LongRefTimeWindow * sfreq) + TimeSamples(1);
        Fraw = in_fread(sFile, ChannelMat,1, SamplesBounds, iChannel, ImportOptions);
        % If nothing was read
        if isempty(Fraw)
            bst_report('Error', sProcess, sInputs(iFile), 'Time window is not valid.');
            continue;
        end
        
        % ===== detect bad seg over selected freq bands =====
        freqs = [];
        threshOffsetRange = [];
        if isLowFreq
            freqs = [1 7];
            threshOffsetRange = [5 6 7 8 9];
        end
        if isHighFreq
            freqs = [freqs;40 240];
            threshOffsetRange = [threshOffsetRange;0.5 1 2 3 4];
        end
        for ff = 1:size(freqs,1)
            ThreshVal = threshOffsetRange(ff,ThreshInd);
            % Event name
            evtName = [num2str(freqs(ff,1)) '-' num2str(freqs(ff,2)) 'Hz'];

            % Apply filtering if requested, otherwise remove the DC
            lowCut = freqs(ff,1);
            highCut = freqs(ff,2);
            % Design band-pass filter
            % [tmp, FiltSpec] = process_bandpass('Compute', [], sfreq, lowCut, highCut, [], 0);
            % Make sure the filters are not too high for the sampling frequency
            if (lowCut > sfreq / 2)
                bst_report('Error', sProcess, sInputs(iFile), sprintf('Frequency band is too high for file sampling frequency: %d-%dHz', round([lowCut highCut])));
                return;
            elseif (highCut > sfreq / 2)
                highCut = round(sfreq / 2);
                highCut = round(highCut - min(10, highCut * 0.2)) - 1;
                bst_report('Warning', sProcess, sInputs(iFile), sprintf('Adjusting frequency band for file sampling frequency: %d-%dHz', round([lowCut highCut])));
            end
            % Filter file
            % Fbp = process_bandpass('Compute', Fraw, sfreq, FiltSpec);
            Fbp = process_bandpass('Compute', Fraw, sfreq, lowCut, highCut, 'bst-hfilter-2019', 1);
            if isempty(Fbp)
                return;
            end

            refData = Fbp';
            winSamps = round(RefTimeWindow*sfreq);
            winBeg = 1:winSamps:size(refData,1);
            for jj=1:length(winBeg)-1
                % refRMS(jj,:) = rms(refData(winBeg(jj):winBeg(jj)+winSamps-1,:));
                refRMS(jj,:) = sqrt(mean(refData(winBeg(jj):winBeg(jj)+winSamps-1,:) .^ 2));
            end
            cleanRMS = min(refRMS);

            % ===== BAD SEGMENTS =====
            % If ignore bad segments
            isIgnoreBad = 1;
            if isIgnoreBad
                % Get list of bad segments in file
                badSeg = panel_record('GetBadSegments', sFile);
                % Adjust with beginning of file
                badSeg = badSeg - fileSamples(1) + 1;
                % Create file mask
                Fmask = false(1, fileSamples(2) - fileSamples(1) + 1);
                if ~isempty(badSeg) 
                    % Loop on each segment: mark as bad
                    for iSeg = 1:size(badSeg, 2)
                        Fmask(badSeg(1,iSeg):badSeg(2,iSeg)) = true;
                    end
                end
            else
                Fmask = [];
            end
        
            % ===== DETECT ARTIFACTS =====
            % Progress bar
            bst_progress('text', ['Detecting bad segments for: [' num2str(lowCut) ',' num2str(highCut) '] Hz...']);
            % Find number of windows to measure
            winSamps = round(RefTimeWindow*sfreq);
            winSt = round(TimeSamples(1):winSamps/2:TimeSamples(2)-winSamps);
            evt = zeros(1,length(winSt)-1);
            r = zeros(length(winSt)-1,length(iChannel));
            % loop on all windows
            for ii=1:length(winSt)-1
                bst_progress('set', min(progressPos + round(ii/(length(winSt)-1) * 100),100));
                % get next data window
                SamplesBounds = [winSt(ii), winSt(ii)+winSamps-1];
                % Check for bad segments
                iSamplesMask = SamplesBounds - fileSamples(1) + 1;
                if (sum(Fmask(iSamplesMask(1):iSamplesMask(2))) > 0)
                    continue;
                end
                % read data
                [F, TimeVector] = in_fread(sFile, ChannelMat,1, SamplesBounds, iChannel, ImportOptions);
                % If nothing was read
                if isempty(F)
                    bst_report('Error', sProcess, sInputs(iFile), 'Time window is not valid.');
                end
                % Apply filtering if requested, otherwise remove the DC
                %F = process_bandpass('Compute', F, sfreq, FiltSpec);
                F = process_bandpass('Compute', F, sfreq, lowCut, highCut, 'bst-hfilter-2019', 1);
                if isempty(F)
                    return;
                end
            
                % find the RMS
                mData = F';
                r(ii,:) = sqrt(mean((mData).^2));
            end

        
            badchan = [];
            % Apply threshold to find events
            for jj=1:size(r,1)
                ind = find(r(jj,:) > (cleanRMS*ThreshVal));
                badchan = [badchan ind];
                if ~isempty(ind)
                    evt(jj)=1;
                end
            end
        
            % find possible bad channels
            allbadchan = unique(badchan);
            if ~isempty(allbadchan)
                for kk=1:length(allbadchan)
                    ntimes = sum(allbadchan(kk)==badchan);
                    % find percent time the channel is bad
                    perc = (ntimes/size(r,1))*100;
                    % find channels that are bad more than pre-determined
                    % percent
                    if perc < percentBadThresh
                        allbadchan(kk) = 0;
                    end
                end
                markbadchan = allbadchan(find(allbadchan));

                if ~isempty(markbadchan)
                    badchan = {ChannelMat.Channel(iChannel(markbadchan)).Name};
                    bst_report('Warning', sProcess, sInputs(iFile), ['Possible bad channels: ' sprintf(' %s', badchan{:})] );
                end
            end

            % combine adjacent events - make extended events
            stEve = find(diff([0 evt]) == 1);
            enEve = find(diff([evt 0]) == -1);
            detectedEvt = {[winSt(stEve); winSt(enEve)+winSamps]};

            % ===== CREATE EVENTS =====
            sEvent = [];
            nEvents = 0;
            nTotalOcc = 0;
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
                    sEvent.times   = [];
                    sEvent.reactTimes = [];
                % Else: create new event
                else
                    % Initialize new event
                    iEvt = length(sFile.events) + 1;
                    sEvent = db_template('event');
                    sEvent.label = newName;
                    % Color
                    ColorTable = panel_record('GetEventColorTable');
                    iColor = mod(iEvt - 1, length(ColorTable)) + 1;
                    sEvent.color = ColorTable(iColor,:);
                end
                % Times, samples, epochs
                %sEvent.times    = (detectedEvt{i} + TimeSamples(1)) ./ sfreq - sFile.prop.times(1);
                sEvent.times    = detectedEvt{i} ./ sfreq;
                sEvent.epochs   = ones(1, size(sEvent.times,2));
                sEvent.channels = cell(1, size(sEvent.times, 2));
                sEvent.notes    = cell(1, size(sEvent.times, 2));
                % Add to events structure
                sFile.events(iEvt) = sEvent;
                nEvents = nEvents + 1;
                nTotalOcc = nTotalOcc + size(sEvent.times, 2);
            end
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
            save(file_fullpath(sInputs(iFile).FileName), '-struct', 'DataMat', '-append');
            % Report number of detected events
            bst_report('Info', sProcess, sInputs(iFile), sprintf('%d events detected in %d categories', nTotalOcc, nEvents));
        else
            bst_report('Info', sProcess, sInputs(iFile), 'No events detected.');
        end
        iOk(iFile) = true;
    end
    % Return all the input files
    OutputFiles = {sInputs(iOk).FileName};
end







