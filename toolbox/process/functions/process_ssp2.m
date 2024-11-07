function varargout = process_ssp2( varargin )
% PROCESS_SSP2: Artifact rejection for a group of recordings file (calculates SSP from FilesA and applies them to FilesB)
%
% USAGE:  OutputFiles = process_ssp2('Run', sProcess, sInputsA, sInputsB)
%                proj = process_ssp2('Compute', F, chanmask)
%           Projector = process_ssp2('BuildProjector', ListSsp, ProjStatus)
%           Projector = process_ssp2('ConvertOldFormat', OldProj)

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
% Authors: Francois Tadel, 2011-2022
%          Elizabeth Bock, 2011-2018

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'SSP: Generic';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Artifacts';
    sProcess.Index       = 302;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ArtifactsSsp?highlight=%28Process2%29#Troubleshooting';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'raw', 'raw'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 0;
    
    % Notice
    sProcess.options.label1.Comment = '<B>Files A</B> = Artifacts samples (raw or epoched)<BR>&nbsp;<B>Files B</B> = Files to clean (raw)<BR><BR>';
    sProcess.options.label1.Type    = 'label';
    % Time window
    sProcess.options.timewindow.Comment   = 'Time window: ';
    sProcess.options.timewindow.Type      = 'timewindow';
    sProcess.options.timewindow.Value     = [];
    sProcess.options.timewindow.InputTypes = {'raw'};
    % Event name
    sProcess.options.eventname.Comment = 'Event name (empty=continuous): ';
    sProcess.options.eventname.Type    = 'text';
    sProcess.options.eventname.Value   = 'blink';
    sProcess.options.eventname.InputTypes = {'raw'};
    % Event window
    sProcess.options.eventtime.Comment = 'Event window (ignore if no event): ';
    sProcess.options.eventtime.Type    = 'range';
    sProcess.options.eventtime.Value   = {[-.200, .200], 'ms', []};
    sProcess.options.eventtime.InputTypes = {'raw'};
    % Filter
    sProcess.options.bandpass.Comment = 'Frequency band: ';
    sProcess.options.bandpass.Type    = 'range';
    sProcess.options.bandpass.Value   = {[1.5, 15], 'Hz', 2};
    %  Number of components
    sProcess.options.nicacomp.Comment = 'Number of ICA components (0=default): ';
    sProcess.options.nicacomp.Type    = 'value';
    sProcess.options.nicacomp.Value   = {0, '', 0};
    sProcess.options.nicacomp.Hidden  = 1;
    % Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    % Use existing SSPs
    sProcess.options.usessp.Comment = 'Compute using existing SSP/ICA projectors';
    sProcess.options.usessp.Type    = 'checkbox';
    sProcess.options.usessp.Value   = 1;
    sProcess.options.usessp.InputTypes = {'raw'};
    % Ignore bad segments
    sProcess.options.ignorebad.Comment = 'Ignore bad segments';
    sProcess.options.ignorebad.Type    = 'checkbox';
    sProcess.options.ignorebad.Value   = 1;
    sProcess.options.ignorebad.InputTypes = {'raw'};
    sProcess.options.ignorebad.Hidden  = 1;
    % Save ERP
    sProcess.options.saveerp.Comment = 'Save averaged artifact in the database';
    sProcess.options.saveerp.Type    = 'checkbox';
    sProcess.options.saveerp.Value   = 0;
    % Method: Average or PCA
    sProcess.options.label2.Comment = '<BR>Method to calculate the projectors:';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.method.Comment = {'PCA: One component per sensor', 'Average: One component only'};
    sProcess.options.method.Type    = 'radio';
    sProcess.options.method.Value   = 1;
    % Examples: EOG, ECG
    sProcess.options.example.Comment = ['<BR>Examples:<BR>' ...
                                        '&nbsp;&nbsp;&nbsp;- EOG: [-200,+200] ms, [1.5-15] Hz<BR>' ...
                                        '&nbsp;&nbsp;&nbsp;- ECG: [-40,+40] ms, [13-40] Hz<BR><BR>'];
    sProcess.options.example.Type    = 'label';
    % Default selection of components
    sProcess.options.select.Comment = 'Selected components:';
    sProcess.options.select.Type    = 'value';
    sProcess.options.select.Value   = {1, 'list', 0};
    sProcess.options.select.Hidden  = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    if isfield(sProcess.options, 'eventname') && ~isempty(sProcess.options.eventname.Value)
        Comment = ['SSP: ' sProcess.options.eventname.Value];
    else
        Comment = 'SSP';
    end
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputsA, sInputsB)
    OutputFiles = {};
    strOptions = '=> ';
    
    % ===== GET OPTIONS =====
    % Get time window
    if isfield(sProcess.options, 'timewindow') && isfield(sProcess.options.timewindow, 'Value') && iscell(sProcess.options.timewindow.Value) && ~isempty(sProcess.options.timewindow.Value)
        TimeWindow = sProcess.options.timewindow.Value{1};
    else
        TimeWindow = [];
    end
    % Get options values
    if isfield(sProcess.options, 'eventname') && isfield(sProcess.options.eventname, 'Value') && ~isempty(sProcess.options.eventname.Value)
        % Event name
        evtName = strtrim(sProcess.options.eventname.Value);
        if isempty(evtName)
            bst_report('Warning', sProcess, [], 'Event name is not specified: starting from the beginning of the file.');
        end
        strOptions = [strOptions, 'Event=' evtName ', '];
    else
        evtName = [];
    end
    % Event time window (only used if event is a point in time, not a window)
    if isfield(sProcess.options, 'eventtime') && isfield(sProcess.options.eventtime, 'Value') && ~isempty(sProcess.options.eventtime.Value) && ~isempty(sProcess.options.eventtime.Value{1})
        evtTimeWindow = sProcess.options.eventtime.Value{1};
        strOptions = [strOptions, sprintf('Epoch=[%1.3f,%1.3f]s, ', evtTimeWindow(1), evtTimeWindow(2))];
    else
        evtTimeWindow = [];
    end
    % Get downsampling value
    if isfield(sProcess.options, 'resample') && isfield(sProcess.options.resample, 'Value') && ~isempty(sProcess.options.resample.Value)
        resample = sProcess.options.resample.Value{1};
        strOptions = [strOptions, 'resample=' num2str(resample) ', '];
    else
        resample = 0;
    end
    % Get bandpass range
    BandPass = sProcess.options.bandpass.Value{1};
    if isempty(BandPass) || all(BandPass <= 0)
        bst_report('Info', sProcess, sInputsA, 'The bandpass filter was disabled.');
        BandPass = [];
        strOptions = [strOptions, 'NoBandPass, '];
    else
        strOptions = [strOptions, 'BandPass=[' num2str(BandPass(1)) ',' num2str(BandPass(2)), ']Hz, '];
    end
    % WARNING: Channel file should be the same for all the files
    if ~all(strcmpi(sInputsA(1).ChannelFile, {sInputsA.ChannelFile, sInputsB.ChannelFile}))
        bst_report('Warning', sProcess, sInputsA, [...
            'All the files should relate to the same channel file. ' ...
            'If the head position is different between two files, the values recorded for one channel do not mean ' ... 
            'the same thing, therefore the calculation or the application of spatial filters (SSP) cannot be reliable.' 10 ...
            'If you decide to use the results of this process, you should understand this problem and check ' ...
            'your analysis for possible errors.']);
    end
    % Check input file types
    isRawA = strcmpi(sInputsA(1).FileType, 'raw');
    isRawB = strcmpi(sInputsB(1).FileType, 'raw');
    if ~isRawB
        bst_report('Error', sProcess, sInputsB, ['You can apply the calculated projectors only to a continuous file (Link to raw file).' 10 'Files B cannot contain any imported data blocks.']);
        return;
    end
    % Use existing SSPs
    if isfield(sProcess.options, 'usessp') && isfield(sProcess.options.usessp, 'Value') && ~isempty(sProcess.options.usessp.Value)
        UseSsp = sProcess.options.usessp.Value;
    else
        UseSsp = 0;
    end
    strOptions = [strOptions, 'UseSsp=' num2str(UseSsp) ', '];
    % Force selection of specific components
    if isfield(sProcess.options, 'select') && isfield(sProcess.options.select, 'Value') && ~isempty(sProcess.options.select.Value)
        if iscell(sProcess.options.select.Value)
            SelectComp = sProcess.options.select.Value{1};
        elseif isnumeric(sProcess.options.select.Value)
            SelectComp = sProcess.options.select.Value;
        else
            error('Invalid value for option "select".');
        end
    else
        SelectComp = [];
    end
    % Force selection of specific components
    if isfield(sProcess.options, 'nicacomp') && isfield(sProcess.options.nicacomp, 'Value') && ~isempty(sProcess.options.nicacomp.Value)
        nIcaComp = sProcess.options.nicacomp.Value{1};
        strOptions = [strOptions, 'nIcaComp=' num2str(nIcaComp) ', '];
    else
        nIcaComp = 0;
    end
    % Find components correlated to reference signals
    if isfield(sProcess.options, 'icasort')
        icaSort = sProcess.options.icasort.Value;
    else
        icaSort = [];
    end    
    % Ignore bad segments
    if panel_record('IsEventBad', evtName)
        % If the event name contains the tag "bad", we need to include the bad segments
        bst_report('Info', sProcess, sInputsA, 'The selected event contains the tag "bad": including all the bad segments...');
        isIgnoreBad = 0;
    elseif isfield(sProcess.options, 'ignorebad') && isfield(sProcess.options.ignorebad, 'Value') && ~isempty(sProcess.options.ignorebad.Value)
        isIgnoreBad = sProcess.options.ignorebad.Value;
    else
        isIgnoreBad = 1;
    end
    strOptions = [strOptions, 'IgnoreBadSegments=' num2str(isIgnoreBad) 10];
    % Save ERP
    if isfield(sProcess.options, 'saveerp') && isfield(sProcess.options.saveerp, 'Value') && ~isempty(sProcess.options.saveerp.Value)
        SaveErp = sProcess.options.saveerp.Value;
    else
        SaveErp = 0;
    end
    % Method
    if isfield(sProcess.options, 'method') && isfield(sProcess.options.method, 'Value') && ~isempty(sProcess.options.method.Value)
        if ischar(sProcess.options.method.Value)
            Method = sProcess.options.method.Value;
        else
            switch (sProcess.options.method.Value)
                case 1,   Method = 'SSP_pca';
                case 2,   Method = 'SSP_mean';
                otherwise, error('Invalid method.');
            end
        end
    else
        Method = 'SSP_pca';
    end
    strOptions = [strOptions, '=> Method=' Method ', '];
    isICA = ~isempty(strfind(Method, 'ICA'));
    % Check method/inputs incompabilities
    if strcmpi(Method, 'SSP_mean') && isRawA && isempty(evtName)
        bst_report('Error', sProcess, sInputsA, 'The method SSP_mean cannot be applied to continuous recordings.');
        return;
    end

    % ===== COMPUTE BANDPASS FILTER =====
    % Get the time vector for the first file
    DataMat = in_bst_data(sInputsA(1).FileName, 'Time');
    sfreq = 1 ./ (DataMat.Time(2) - DataMat.Time(1));
    % Design band-pass filter
    if ~isempty(BandPass) && ~all(BandPass == 0)
        % If we need to resample the recordings
        if (resample > 0)
            filterFreq = resample;
        % Use the original sampling frequency
        else
            filterFreq = sfreq;
        end
        % Design the filter
        isMirror = 0;
        [tmp, FiltSpec] = process_bandpass('Compute', [], filterFreq, BandPass(1), BandPass(2), 'bst-hfilter-2019', isMirror);
        % Estimate transient period (before and after resampling)
        nTransientLoad    = round(FiltSpec.transient * sfreq);
        nTransientDiscard = round(FiltSpec.transient * filterFreq);
        % Show warning when computing epoched files
        if ~isRawA
            bst_report('Warning', sProcess, sInputsA, sprintf('Removing %1.3fs at the beginning and the end of each input for filtering.', FiltSpec.transient));
        end
    else
        nTransientLoad    = [];
        nTransientDiscard = [];
    end

    % ===== READ ARTIFACTS (FILES A) =====
    % Initialize progress bar
    bst_progress('text', 'Reading recordings...');
    progressPos = bst_progress('get');
    % Initialize concatenated data matrix
    F = {};
    Fref = {}; % for holding reference signals (EOG, ECG)
    iBad = [];
    iTimeZero = [];
    nSamples = 0;
    nMaxSamples = 100000;
    projChan = [];
    projChanNames = [];
    % Read together all the files in group A
    for iFile = 1:length(sInputsA)
        % ===== GET CHANNEL FILE =====
        if isempty(projChan) || ~isequal(projChan, sInputsA(iFile).ChannelFile)
            % Load channel file
            ChannelMat = in_bst_channel(sInputsA(iFile).ChannelFile);
            % Check for different channel structures in FilesA
            if isempty(projChanNames)
                projChanNames = {ChannelMat.Channel.Name};
            elseif ~isequal(projChanNames, {ChannelMat.Channel.Name})
                bst_report('Error', sProcess, sInputsA(iFile), 'All the files A must have the exact same list of channels.');
                return;
            end
            % Get channels to process
            iChannels = channel_find(ChannelMat.Channel, sProcess.options.sensortypes.Value);
            if isempty(iChannels)
                bst_report('Error', sProcess, sInputsA(iFile), 'No channels to process.');
                return;
            end
            % Warning if more than one channel type
            allTypes = unique({ChannelMat.Channel(iChannels).Type});
            if (length(allTypes) > 1) && ~isequal(allTypes, {'MEG GRAD', 'MEG MAG'})
                for iType = 1:length(allTypes)-1
                    allTypes{iType} = [allTypes{iType}, ', '];
                end
                bst_report('Warning', sProcess, sInputsA, ...
                    ['Mixing different channel types to compute the projector: ' [allTypes{:}], '.' 10 ...
                     'You should compute projectors separately for each sensor type.']);
            end
            if ~isempty(icaSort)
                iRef = channel_find(ChannelMat.Channel, icaSort);
                if isempty(iRef)
                    bst_report('Error', sProcess, sInputsA(iFile), sprintf('Channels %s not found.', icaSort));
                end
                iSensors = iChannels;
                iChannels = [iSensors iRef];
            end
        end

        % ===== GET DATA =====
        % === RAW: EVENTS ===
        if isRawA && ~isempty(evtName)
            % Load the raw file descriptor
            DataMat = in_bst_data(sInputsA(iFile).FileName, 'F', 'ChannelFlag');
            sFile = DataMat.F;
            sfreq_file = sFile.prop.sfreq;
            if isempty(sFile.events)
                bst_report('Error', sProcess, sInputsA(iFile), 'No events in the input file.');
                return;
            end
            % Get list of bad segments in file
            [badSeg, badEpochs] = panel_record('GetBadSegments', sFile);
            % Get the event to process
            events = sFile.events;
            iEvt = find(strcmpi({events.label}, evtName));
            nOcc = size(events(iEvt).times, 2);
            if isempty(iEvt) || (nOcc == 0)
                bst_report('Error', sProcess, sInputsA(iFile), ['Event type "' evtName '" not found, or has no occurrence.']);
                return;
            end
            % Extended / simple event
            isExtended = (size(events(iEvt).times, 1) == 2);
            % Simple events: get the samples to read around each event
            if ~isExtended
                evtSmpRange = round(evtTimeWindow .* sFile.prop.sfreq);
            % Extended: cannot work with "mean" option
            elseif strcmpi(Method, 'SSP_mean')
                bst_report('Error', sProcess, sInputsA, 'Method "SSP_mean" cannot be used for extended events.');
                return;
            % Extended: read the full block
            else
                evtSmpRange = [0 0];
            end
            % Add transients for bandpass
            if ~isempty(nTransientLoad)
                evtSmpRange = evtSmpRange + [-1 1] .* nTransientLoad;
            end
            % Reading options
            % NOTE: FORCE READING CLEAN DATA (Baseline correction + CTF compensators + Previous SSP)
            ImportOptions = db_template('ImportOptions');
            ImportOptions.ImportMode      = 'Event';
            ImportOptions.EventsTimeRange = evtSmpRange ./ sFile.prop.sfreq;
            ImportOptions.UseCtfComp      = 1;
            ImportOptions.UseSsp          = UseSsp;    % ADDED OPTION (FT: 27-Jun-2014) - Before we were always applying the previous SSPs
            ImportOptions.RemoveBaseline  = 'all';
            ImportOptions.DisplayMessages = 0;
            nInfoBad = 0;
            % Loop on each occurrence of the event
            for iOcc = 1:nOcc
                % Progress bar
                bst_progress('set', progressPos + round(iOcc / nOcc * 50));
                % Simple event: read a time window around the marker
                if ~isExtended
                    SamplesBounds = round(events(iEvt).times(1,iOcc) .* sFile.prop.sfreq) + evtSmpRange;
                % Extended event: read the full event
                else
                    SamplesBounds = round(events(iEvt).times(:,iOcc)' .* sFile.prop.sfreq) + evtSmpRange;
                end
                % Check that this epoch is within the segment of file to consider
                TimeBounds = SamplesBounds ./ sFile.prop.sfreq;
                if ~isempty(TimeWindow) && ((TimeBounds(1) < TimeWindow(1)) || (TimeBounds(2) > TimeWindow(2)))
                    continue;
                end
                % Check if this segment is outside of ALL the bad segments (either entirely before or entirely after)
                if isIgnoreBad && ~isempty(badSeg) && (~all((SamplesBounds(2) < badSeg(1,:)) | (SamplesBounds(1) > badSeg(2,:))))
                    nInfoBad = nInfoBad + 1;
                    continue;
                % Check if this this segment is  outside of the file bounds
                elseif (TimeBounds(1) < sFile.prop.times(1)) || (TimeBounds(2) > sFile.prop.times(2)) 
                    bst_report('Info', sProcess, sInputsA(iFile), sprintf('Event %s #%d is too close to the beginning or end of the file: ignored...', evtName, iOcc));
                    continue;
                end
                % Read block
                [Fevt, TimeVector] = in_fread(sFile, ChannelMat, events(iEvt).epochs(iOcc), SamplesBounds, [], ImportOptions);
                % SSP_mean: Check that we can get a time zero
                if strcmpi(Method, 'SSP_mean')
                    if ((TimeVector(1) > 0) || (TimeVector(end) < 0))
                        bst_report('Warning', sProcess, sInputsA(iFile), ['File #"' num2str(iFile) '" does not have a time t=0, it cannot be used for the method "mean".']);
                        continue;
                    end
                    % Get the sample where t=0
                    iTimeZero{end+1} = bst_closest(0, TimeVector);
                end
                % Concatenate to final matrix
                F{end+1} = Fevt;
                nSamples = nSamples + size(Fevt,2);
                % Check whether we read already all the samples we need
                if ~isICA && (nSamples >= nMaxSamples)
                    bst_report('Info', sProcess, sInputsA(iFile), sprintf('Reached the maximum number of samples at event %d / %d', iOcc, nOcc));
                    break;
                end
            end
            % Display message with number of events ignored
            if (nInfoBad > 0)
                bst_report('Info', sProcess, sInputsA(iFile), sprintf('Event %s: %d/%d events were in bad segments and ignored.', evtName, nInfoBad, nOcc));
            end
            
        % === RAW: CONTINUOUS ===
        elseif isRawA && isempty(evtName)
            % Load the raw file descriptor
            DataMat = in_bst_data(sInputsA(iFile).FileName, 'F', 'ChannelFlag');
            sFile = DataMat.F;
            sfreq_file = sFile.prop.sfreq;
            % Options for LoadInputFile()
            LoadOptions.IgnoreBad      = isIgnoreBad;  % From raw files: ignore the bad segments
            LoadOptions.ProcessName    = func2str(sProcess.Function);
            LoadOptions.RemoveBaseline = 'all';
            LoadOptions.UseSsp         = UseSsp;
            % Add transients for bandpass filter
            if ~isempty(nTransientLoad) && ~isempty(TimeWindow)
                rawTime = TimeWindow + [-1 1] .* (nTransientLoad / sfreq_file);
            else
                rawTime = TimeWindow;
            end
            % Load input signals
            [sMat, nSignals, iRows] = bst_process('LoadInputFile', sInputsA(iFile).FileName, [], rawTime, LoadOptions);
            if isempty(sMat.Data)
                bst_report('Error', sProcess, [], 'No data could be read from the input file.');
                return
            end
            % Use the loaded block
            F{end+1} = zeros(length(ChannelMat.Channel), size(sMat.Data,2));
            F{end}(iRows,:) = sMat.Data;
            TimeVector = sMat.Time;

        % === IMPORTED DATA ===
        else
            % Progress bar
            bst_progress('set', progressPos + round(iFile / length(sInputsA) * 50));
            % Load file
            DataMat = in_bst_data(sInputsA(iFile).FileName, 'F', 'ChannelFlag', 'Time');
            % Sampling frquency
            TimeVector = DataMat.Time;
            sfreq_file = 1 ./ (TimeVector(2) - TimeVector(1));
            % SSP_mean: Check that we can get a time zero
            if strcmpi(Method, 'SSP_mean')
                if ((TimeVector(1) > 0) || (TimeVector(end) < 0))
                    bst_report('Warning', sProcess, sInputsA(iFile), ['File #"' num2str(iFile) '" does not have a time t=0, it cannot be used for the method "mean".']);
                    continue;
                end
                % Get the sample where t=0
                iTimeZero{end+1} = bst_closest(0, TimeVector);
            end
            % Concatenate to final matrix
            F{end+1} = DataMat.F;
            nSamples = nSamples + size(DataMat.F,2);
            % Check whether we read already all the samples we need
            if ~isICA && (nSamples >= nMaxSamples)
                bst_report('Info', sProcess, sInputsA(iFile), sprintf('Reached the maximum number of samples at file %d / %d', iFile, length(sInputsA)));
                break;
            end
        end
        % Check that the sampling frequency is the same
        if (abs(sfreq_file - sfreq) > 1e-3)
            bst_report('Error', sProcess, sInputsA(iFile), 'Input files have different sampling rates.');
            break;
        end
        % Add bad channels in this file to the global list
        iBad = union(iBad, find(DataMat.ChannelFlag == -1));
    end
    % No data was read...
    if isempty(F)
        bst_report('Error', sProcess, sInputsA, 'No data could be read from the input file.');
        return;
    end
    
    % ===== DOWNSAMPLE =====
    % Downsample data to specified rate.
    if (resample > 0)
        bst_progress('text', 'Downsampling recordings...');
        bst_progress('set', progressPos + 25);
        for iFile = 1:length(F)
            [F{iFile}, TimeResample] = process_resample('Compute', F{iFile}, TimeVector, resample);
        end
        sfreq = resample;
        TimeVector = TimeResample;
    end
    
    % ===== COMPUTE AVERAGE =====
    % Compute the average of the data blocks (unfiltered)
    if SaveErp
        % Check that the size is the same for all the blocks
        if ~all(cellfun(@(c)isequal(size(c), size(F{1})), F))
            bst_report('Warning', sProcess, [], 'Input files have different sizes, cannot compute average');
            SaveErp = 0;
        else
            Favg = mean(cat(3, F{:}), 3);
        end
    end
    
    
    % ===== PROCESS DATA =====
    % Set the progress bar to 50%
    bst_progress('text', 'Processing recordings...');
    bst_progress('set', progressPos + 50);
    % Initializations for this loop
    Fzero = zeros(size(F{1},1), 1);
    nAvg = length(F);
    % Apply montages and filters
    for iBlock = 1:length(F)
        % Progress bar
        bst_progress('set', progressPos + 50 + round(iBlock / length(F) * 50));
        % Remove the bad channels from the matrix
        [iBad, iChanRemove] = intersect(iChannels, iBad);
        if ~isempty(iBad) && ~isempty(F{iBlock})
            iChannels(iChanRemove) = [];
        end
        % Filter recordings 
        if ~isempty(BandPass) && ~all(BandPass == 0)
            F{iBlock}(iChannels,:) = process_bandpass('Compute', F{iBlock}(iChannels,:), sfreq, FiltSpec);
        end
        % Compute the average at time zero (filtered)
        if strcmpi(Method, 'SSP_mean')
            Fzero = Fzero + F{iBlock}(:,iTimeZero{iBlock});
        end
        % Filter recordings: Remove transients
        if ~isempty(BandPass) && ~all(BandPass == 0)
            F{iBlock} = F{iBlock}(:, (nTransientDiscard+1):(end-nTransientDiscard));
        end
        % Keep only the needed channels
        if ~isempty(icaSort)
            Fref{iBlock} = F{iBlock}(iRef,:);
            F{iBlock} = F{iBlock}(iSensors,:);
        else
            F{iBlock} = F{iBlock}(iChannels,:);
        end
    end
    % Comment
    nSamplesFinal = sum(cellfun(@(c)size(c,2), F));
    strOptions = [strOptions, 'Nsamples=' num2str(nSamplesFinal) ' from ' num2str(length(F)) ' blocks'];
    % Concatenate all the loaded data
    F = [F{:}];
    if ~isempty(icaSort)
        Fref = [Fref{:}];
        iChannels = iSensors;
    end    
    % Error if nothing was loaded
    if isempty(F)
        bst_report('Error', sProcess, sInputsA, 'No data could be read from the input files.');
        return;
    elseif (size(F,2) < size(F,1))
        bst_report('Error', sProcess, sInputsA, 'Not enough data could be read from the input files.');
        return;
    elseif ~isICA && (size(F,1) < 32)
        bst_report('Warning', sProcess, sInputsA, ['You selected only ' num2str(size(F,1)) ' channels to compute the projectors. ' 10 ...
            'The SSP approach may not work correctly with a low number of sensors. ' ...
            'Make sure you selected correctly all the channels of data you have in your file.']);
    end
    % ICA: Check that the number of time samples is sufficient
    % Recommended number of time samples (from S Makeig):  Ntime/Nchan^2 >> 10
    nTime = size(F,2);
    if (nIcaComp > 0)
        nChan = nIcaComp;
    else
        nChan = size(F,1);
    end
    if isICA && (nTime / nChan^2 < 10)
        % Warning message
        strWarning = ['There is probably not enough data for a correct ICA decomposition.' 10 ...
            'Number time samples in input: '    num2str(nTime)      ' (' num2str(round(nTime / sfreq)) 's)' 10 ...
            'Recommend number of time samples:' num2str(10*nChan^2) ' (' num2str(round(10*nChan^2 / sfreq)) 's)'];
        % Add to the report
        bst_report('Warning', sProcess, [], strWarning);
        % Display on the console
        disp([10 'WARNING: ' strWarning]);
    end
            
    % ===== COMPUTE PROJECTORS =====
    Y = [];
    bst_progress('text', 'Computing projector...');
    switch (Method)
        
        % === SSP: PCA ===
        case 'SSP_pca'
            % === CHECK NUMBER OF SAMPLES ===
            % Minimum number of time samples required to estimate covariance
            nMinSmp = 10 * size(F,1);
            if (size(F,2) < nMinSmp)
                nTimePerBlock = length(TimeVector);
                nBlock = ceil(size(F,2) / nTimePerBlock);
                nBlockTotal = ceil(nMinSmp / nTimePerBlock);
                if isRawA && ~isempty(evtName)
                    errMsg = sprintf(' - Add %d events (Total: %d)', nBlockTotal - nBlock, nBlockTotal);
                    if ~isExtended
                        nAddTime = ceil((nMinSmp - size(F,2)) / nBlock / 2);
                        newTimeWin = round([evtSmpRange(1) - nAddTime, evtSmpRange(2) + nAddTime] ./ sFile.prop.sfreq .* 1000);
                        errMsg = sprintf([errMsg, 10, ' - Increase the time window around each event to [%d,%d] ms'], newTimeWin(1), newTimeWin(2));
                    end
                elseif isRawA && strcmpi(sFile.format, 'CTF') && length(sFile.epochs) > 1
                    errMsg = ' - Convert the input files to continuous.';
                else
                    errMsg = sprintf(' - Add %d files in the process list (Total: %d)', nBlockTotal - nBlock, nBlockTotal);
                end
                bst_report('Error', sProcess, sInputsA, ['Not enough time samples to compute projectors. You may:' 10 errMsg]);
                return;
            end
            
            % === COMPUTE PROJECTOR ===
            % Create channel mask matrix
            chanmask = zeros(length(ChannelMat.Channel), 1);
            chanmask(iChannels) = 1;
            % Call computation function
            proj = Compute(F, chanmask);
            proj.Method = Method;
%             % Select the components with a singular value > threshold
%             if isempty(ForceSelect)
%                 singThresh = 0.12;
%                 proj.CompMask = double(proj.SingVal ./ sum(proj.SingVal) > singThresh);
%             % Force selection of specific components
%             else
%                 proj.CompMask(ForceSelect) = 1;
%             end
            % By default: first component selected
            if isempty(SelectComp)
                SelectComp = 1;
            end
            % Apply component selection (default: first component only)
            proj.CompMask(SelectComp) = 1;
            % Set the category as active if there is one selected component
            proj.Status = any(proj.CompMask);
            
            
        % === SSP: MEAN ===
        case 'SSP_mean'
            % Check number of samples
            if isempty(Fzero)
                bst_report('Error', sProcess, sInputsA, 'No data could be read from the input files.');
                return;
            else
                bst_report('Info', sProcess, sInputsA, sprintf('Computing projectors based on an average of %d events.', nAvg));
            end
            % Get the average at t=0
            Components = zeros(length(ChannelMat.Channel), 1);
            Components(iChannels) = Fzero(iChannels,:) ./ nAvg;
            % Normalize columns of the components
            Components = Components ./ sqrt(sum(Components .^2));
            % Build projector structure
            proj = db_template('projector');
            proj.Components = Components;
            proj.CompMask   = 1;
            proj.Status     = 1;
            proj.SingVal    = [];
            proj.Method     = Method;
            
            
        % === ICA: JADE ===
        case 'ICA_jade'
            bst_progress('text', 'Calling external function: jadeR()...');
            % Run decomposition
            if ~isempty(nIcaComp) && (nIcaComp ~= 0)
                W = jadeR(F, nIcaComp);
            else
                W = jadeR(F);
            end
            % Error handling
            if isempty(W)
                bst_report('Error', sProcess, sInputsA, 'Function "jadeR" did not return any results.');
                return;
            end
            
        % === INFOMAX ===
        case 'ICA_infomax'
            bst_progress('text', 'Calling external function: EEGLAB''s runica()...');
            % Remove the mean
            F = bst_bsxfun(@minus, F, mean(F,2));
            rankF = rank(F);
            isLowRank = rank(F) < size(F,1);
            if isLowRank
                % Warning message
                strWarning = [sprintf('INFOMAX: The rank of your data (%d) is lower than the number of channels (%d) in it.', rankF, size(F,1)), 10 ...
                                      '         This could be caused because a refrence channel is included, or AVERAGE re-referencing is applied to this data.', 10 ...
                                      '         Please consider limiting the "Number of ICA components" to the rank of the data.'];
                % Add to the report
                bst_report('Warning', sProcess, [], strWarning);
                % Display on the console
                disp([10 'WARNING: ' strWarning]);
            end
            % Run EEGLAB ICA function
            if ~isempty(nIcaComp) && (nIcaComp ~= 0)
                [icaweights, icasphere] = runica(F, 'pca', nIcaComp, 'lrate', 0.001, 'extended', 1, 'interupt', 'off');
            else
                [icaweights, icasphere] = runica(F, 'lrate', 0.001, 'extended', 1, 'interupt', 'off');
            end
            % Error handling
            if isempty(icaweights) || isempty(icasphere)
                bst_report('Error', sProcess, sInputsA, 'Function "runica" did not return any results.');
                return;
            end
            % Reconstruct unmixing matrix
            W = icaweights * icasphere;
            
        % === ICA: PICARD ===
        case 'ICA_picard'
            bst_progress('text', 'Calling external function: picard()...');
            % Install picard plugin
            [isInstalled, errMsg] = bst_plugin('Install', 'picard');
            if ~isInstalled
                error(errMsg);
            end
            % Run decomposition
            if ~isempty(nIcaComp) && (nIcaComp ~= 0)
                [Y,W] = picard(F, 'pca', nIcaComp);
            else
                [Y,W] = picard(F);
            end

        % === ICA: FASTICA ===
        case 'ICA_fastica'
            bst_progress('text', 'Calling external function: fastica()...');
            % Install fastica plugin
            [isInstalled, errMsg] = bst_plugin('Install', 'fastica');
            if ~isInstalled
                error(errMsg);
            end
            % Scale the values to higher values, so that the pcamat function doesn't complain for small eigenvalues
            F = F ./ mean(abs(F(:)));
            % Run decomposition
            if ~isempty(nIcaComp) && (nIcaComp ~= 0)
                [M,W] = fastica(F, 'numOfIC', nIcaComp);
            else
                [M,W] = fastica(F);
            end

        otherwise
            bst_report('Error', sProcess, sInputsA, ['Invalid method: "' Method '".']);
            return;
    end

    % Finish assembling ICA results
    if ismember(Method, {'ICA_jade', 'ICA_infomax', 'ICA_picard', 'ICA_fastica'})
        % Fill with the missing channels with zeros
        Wall = zeros(length(ChannelMat.Channel), size(W,1));
        Wall(iChannels,:) = W';
        % Build projector structure
        proj = db_template('projector');
        proj.Components = Wall;
        proj.CompMask   = zeros(size(Wall,2), 1);   % No component selected by default
        proj.Status     = 1;
        proj.Method     = Method;

        % Apply component selection (if set explicitly)
        if ~isempty(SelectComp)
            proj.CompMask(SelectComp) = 1;
        end
        % Compute IC
        if isempty(Y)
            Y = W * F;
        end
        % Compute mixing matrix
        if diff(size(W)) == 0
            M = inv(W);
        else
            M = pinv(W);
        end
        % Variance in recovered data explained by each component
        varIcs = sum(M.^2, 1) .* sum(Y.^2, 2)';
        varIcs = varIcs ./ sum(varIcs);
        % Find sorting order for ICA components
        iSort = [];
        if ~isempty(icaSort)
            % By correlation with reference channel
            C = bst_corrn(Fref, Y);
            [~, iSort] = sort(max(abs(C),[],1), 'descend');
        elseif ismember(Method, {'ICA_picard', 'ICA_fastica'})
            [~, iSort] = sort(varIcs, 'descend');
        end
        % Explained variance ratio
        Fdiff = (F - M * Y);
        rVarExp = 1 - (sum(sum(Fdiff.^2, 2)) ./ sum(sum(F.^2, 2)));
        % Variance in original data by each component
        proj.SingVal = rVarExp * varIcs;
        % Sort components and their variances
        if ~isempty(iSort)
            proj.Components = proj.Components(:,iSort);
            proj.SingVal    = proj.SingVal(iSort);
        end
    end
    
    % Modality used in the end
    AllMod = unique({ChannelMat.Channel(iChannels).Type});
    strMod = '';
    for iMod = 1:length(AllMod)
        strMod = [strMod, AllMod{iMod} '+'];
    end
    strMod = strMod(1:end-1);
    % Comment
    if ~isempty(evtName)
        proj.Comment = [evtName ': ' Method ', ' strMod ', ' datestr(clock)];
    else
        proj.Comment = [Method ': ' strMod  ', ' datestr(clock)];
    end
    
    
    % ===== APPLY PROJECTORS (FILES B) =====
    bst_progress('text', 'Applying projector to the recordings...');
    % Get all the channel files
    ChannelFiles = unique({sInputsB.ChannelFile});
    % Apply projectors to all the files in input
    for iFile = 1:length(ChannelFiles)
        % Load destination channel file
        ChannelMatB = in_bst_channel(ChannelFiles{iFile});
        destChanNames = {ChannelMatB.Channel.Name};
        % If channel names in projector and destination files do not match at all: ERROR
        [commonNames,I,J] = intersect(projChanNames, destChanNames);
        if isempty(commonNames)
            bst_report('Error', sProcess, sInputsB(iFile), 'List of channels are too different in the source and destination files.');
            return;
        end
        % If the channels list is not the same: re-order them to match the destination channel file
        if ~isequal(projChanNames, destChanNames)
            fixComponents = zeros(length(destChanNames), size(proj.Components,2));
            fixComponents(J,:) = proj.Components(I,:);
            proj.Components = fixComponents;
            bst_report('Warning', sProcess, sInputsB(iFile), sprintf('List of channels differ in FilesA (%d) and FilesB (%d). The common channels (%d) have been re-ordered to match the channels in FilesB.', length(projChanNames), length(destChanNames), length(commonNames)));
        end
        % Add projector to channel file
        [newproj, errMsg] = import_ssp(ChannelFiles{iFile}, proj, 1, 1, strOptions);
        if ~isempty(errMsg)
            bst_report('Error', sProcess, sInputsB(iFile), errMsg);
            return;
        end
    end
    
    
    % ===== SAVE THE AVERAGE =====
    if SaveErp && ~isempty(Favg)
        % Divide by number of average
        ChannelFlag = ones(size(Favg,1), 1);
        ChannelFlag(iBad) = -1;
        % Remove transients
        if ~isempty(nTransientDiscard)
            Favg = Favg(:, (nTransientDiscard+1):(end-nTransientDiscard));
            TimeVector = TimeVector((nTransientDiscard+1):(end-nTransientDiscard));
        end
        
        % === BEFORE ===
        % Create new output structure
        sOutput = db_template('datamat');
        sOutput.F           = Favg;
        sOutput.Comment     = [proj.Comment ' (before)'];
        sOutput.ChannelFlag = ChannelFlag;
        sOutput.Time        = TimeVector;
        sOutput.DataType    = 'recordings';
        sOutput.Device      = 'ArtifactERP';
        sOutput.nAvg        = nAvg;
        sOutput.Leff        = nAvg;
        % Get output study
        [tmp, iOutputStudy] = bst_process('GetOutputStudy', sProcess, sInputsB);
        sOutputStudy = bst_get('Study', iOutputStudy);
        % Output filename
        OutputFileERP = bst_process('GetNewFilename', bst_fileparts(sOutputStudy.FileName), 'data_artifact_before');
        % Save file
        bst_save(OutputFileERP, sOutput, 'v6');
        % Add file to database structure
        db_add_data(iOutputStudy, OutputFileERP, sOutput);
        
        % === SSP COMPONENTS ===
        if ~isICA
            % Force the first component to be used (allow multiple components by default)
            projErp = proj;
            projErp.Status(1) = 1;
            %projErp.CompMask = 0 * projErp.CompMask;
            projErp.CompMask(1) = 1;
            % Build projector
            Projector = BuildProjector(projErp, 1);
            % Apply to average data
            sOutput.F       = Projector * Favg;
            sOutput.Comment = [proj.Comment ' (after)'];
            % Output filename
            OutputFileERP = bst_process('GetNewFilename', bst_fileparts(sOutputStudy.FileName), 'data_artifact_after');
            % Save file
            bst_save(OutputFileERP, sOutput, 'v6');
            % Add file to database structure
            db_add_data(iOutputStudy, OutputFileERP, sOutput);
        % === ICA COMPONENTS ===
        else
            % Create file structure
            sOutput = db_template('matrixmat');
            sOutput.Value       = proj.Components' * Favg;
            sOutput.Comment     = [proj.Comment ' (ICA)'];
            sOutput.Time        = TimeVector;
            sOutput.ChannelFlag = [];
            sOutput.nAvg        = nAvg;
            sOutput.Leff        = nAvg;
            % Description of the signals: IC*
            sOutput.Description = cell(size(proj.Components,1),1);
            for i = 1:size(proj.Components,1)
                sOutput.Description{i} = sprintf('IC%d', i);
            end
            % Output filename
            OutputFileIC = bst_process('GetNewFilename', bst_fileparts(sOutputStudy.FileName), 'matrix_artifact_ica');
            % Save file
            bst_save(OutputFileIC, sOutput, 'v6');
            % Add file to database structure
            db_add_data(iOutputStudy, OutputFileIC, sOutput);
        end
    end
    % Return all the input files
    OutputFiles = {sInputsB.FileName};
end


%% ===== COMPUTE PROJECTOR =====
function proj = Compute(F, chanmask)
    % SVD decomposition
    [U,S,V] = svd(F, 'econ'); 
    % Create projector structure
    proj = db_template('projector');
    % Keep all the dimensions
    nChannel = length(chanmask);
    nProj    = size(U,2);
    proj.Components = zeros(nChannel, nProj);
    proj.Components(chanmask == 1,:) = U;
    % Other fields
    proj.SingVal  = diag(S)';
    proj.CompMask = zeros(1,nProj);
    proj.Status   = 1;
end


%% ===== BUILD PROJECTOR ====
% Combine all the projectors in decomposed form to create a [nChan x nChan] matrix
%
% USAGE: Projector = process_ssp2('BuildProjector', ListProj, ProjStatus)
%
% INPUT:
%    - ListProj   : Array of db_template('projector')
%    - ProjStatus : List of the projector status to include 
%                   0 = not applied, not used
%                   1 = have to be used, but still have to be applied on the fly
%                   2 = already applied, saved in the file, not revertible
% OUTPUT:
%    - Projector  : [nChannels x nChannels] matrix, projector in the condensed form (I-UUt)
%
% COMMENTS: 
%    There are 5 categories of projectors:
%    - SSP_pca:   Method = 'SSP_pca'      CompMask=[Ncomp x 1],   SingVal=[Ncomp x 1],   Components=[Nchan x Ncomp]=U
%    - SSP_mean:  Method = 'SSP_pca'      CompMask=1,             SingVal=[],            Components=[Nchan x 1]=U
%    - ICA:       Method = 'ICA_variant'  CompMask=[Ncomp x 1],   SingVal=[Ncomp x 1],   Components=[Nchan x Ncomp]=W'
%    - REF:       Method = 'REF'          CompMask=[],            SingVal=[],            Components=[Nchan x Ncomp]=Wmontage
%    - Other:     Method = 'Other'        CompMask=[],            SingVal=[],            Components=[Nchan x Nchan]=Projector=I-UUt
%
%  For ICA projectors, 'SingVal' contains the fraction explained variance with respect to the original signal
%
%    Description of the notations used here:
%    - W: Unmixing matrix  [Ncomponents x Nelectrodes]
%    - Winv = pinv(W) = [Nelectrodes x Ncomponents]
%    - In EEGLAB:  W = icaweights * icasphere;
%    - Activations_IC = W * Data
%    - CleanData = Winv(:,iComp) * Activations(iComp,:)
%                = Winv(:,iComp) * W(iComp,:) * Data
%  
function Projector = BuildProjector(ListProj, ProjStatus) %#ok<*DEFNU>
    % Call on an old form of Projector (I-UUt)
    if ~isstruct(ListProj)
        Projector = ListProj;
        return
    end
    % Initialize matrices
    nChannel = size(ListProj(1).Components,1);
    
    % === SORT PROJECTORS ===
    % Find projectors to group or remove
    iProjDel = [];
    iProjSsp = [];
    U = [];
    for i = 1:length(ListProj)
        % Is entry not selected: skip
        if ~ismember(ListProj(i).Status, ProjStatus) || (~isempty(ListProj(i).CompMask) && all(ListProj(i).CompMask == 0))
            iProjDel(end+1) = i;
        % New SSP: Stack selected vectors all together
        elseif ~isempty(ListProj(i).CompMask) && ~ismember(ListProj(i).Method(1:3), {'ICA', 'REF'})
            iProjSsp(end+1) = i;
            U = [U, ListProj(i).Components(:,ListProj(i).CompMask == 1)];
        end
    end
    
    % === ORTHOGONALIZE SSP VECTORS ===
    if ~isempty(U) && ~all(U(:) == 0)
        % Reorthogonalize the vectors
        [U,S,V] = svd(U,0);
        S = diag(S);
        % Enforce strict zero values (because Matlab SVD function can randomly return small values instead of zeros !!!)
        % If not, sometimes it adds small contributions of some channels that have nothing to do with the projectors (<1e-16).
        % If this added channel contains high values (eg. Stim channel in Volts) it can corrupt significantly the MEG values.
        iZero = find((abs(U) < 1e-15) & (U ~= 0));
        if ~isempty(iZero)
            U(iZero) = 0;
        end
        % Throw away the linearly dependent guys (threshold on singular values: 0.01 * the first one)
        iThresh = find(S < 0.01 * S(1),1);
        if ~isempty(iThresh)
            disp(sprintf('SSP> %d linearly dependent vectors removed...', size(U,2)-iThresh+1));
            U = U(:, 1:iThresh-1);
        end
        % Compute projector in the form: I-UUt
        SspProj = eye(nChannel) - U*U';
        % Copy the projector in the Components field of the first SSP entry
        ListProj(iProjSsp(1)).Components = SspProj;
        % Remove all the other SSP entries
        if (length(iProjSsp) >= 2)
            iProjDel = [iProjDel, iProjSsp(2:end)];
        end
    % Remove all the SSP projectors
    elseif ~isempty(iProjSsp)
        iProjDel = [iProjDel, iProjSsp];
    end

    % === CLEANING LIST ===
    % Remove unwanted projectors
    ListProj(iProjDel) = [];
    % Nothing left: return
    if isempty(ListProj)
        Projector = [];
        return;
    end

    % === BUILD FINAL PROJECTOR ===
    % Initialize returned projector as an identity matrix
    Projector = eye(nChannel);
    % Add the projectors in the order of appearance
    for i = 1:length(ListProj)
        % ICA
        if isequal(ListProj(i).Method(1:3), 'ICA')
            % Get selected channels (find the non-zero channels)
            iChan = find(any(ListProj(i).Components ~= 0, 2));
            % Get selected components
            iComp = find(ListProj(i).CompMask == 1);
            % Initialize projector
            P = eye(size(ListProj(i).Components,1));
            % Compute projector
            W = ListProj(i).Components(iChan,:)';
            Winv = pinv(W);
            P(iChan,iChan) = eye(size(W,2)) - Winv(:,iComp) * W(iComp,:);
            % Check if there are any complex values in the projector
            if any(~isreal(P))
                warning('WARNING: ICA components contain complex values. Something went wrong in their computation.');
                P = real(P);
            end
        % Other projectors
        else
            P = ListProj(i).Components;
        end
        % Add to the final operator
        Projector = P * Projector;
    end
    % Make sure it is not an identity matrix
    if isequal(Projector, eye(nChannel))
        Projector = [];
    end
end


%% ===== CONVERT OLD FORMAT =====
% Old format: I - UUt
% New format: Structure with decomposed form (U, maskU...)
function proj = ConvertOldFormat(OldProj)
    if isempty(OldProj)
        proj = [];
    elseif ~isstruct(OldProj)
        proj = db_template('projector');
        proj.Components  = OldProj;
        proj.Comment     = 'Unnamed';
        proj.Status      = 1;
        proj.Method      = 'Other';
    elseif ~isfield(OldProj, 'Method') || isempty(OldProj.Method)
        proj = db_template('projector');
        proj = struct_copy_fields(proj, OldProj, 1);
        % Add projector method
        if isnumeric(proj.SingVal) && (length(proj.SingVal) == length(proj.CompMask))
            proj.Method  = 'SSP_pca';
        elseif isempty(proj.SingVal) && length(proj.CompMask) == 1 && proj.CompMask == 1
            proj.Method  = 'SSP_mean';
        elseif ischar(proj.SingVal) && strcmpi(proj.SingVal, 'ICA')
            proj.Method  = 'ICA';
            proj.SingVal = [];
        elseif ischar(proj.SingVal) && strcmpi(proj.SingVal, 'REF')
            proj.Method  = 'REF';
            proj.SingVal = [];
        elseif isempty(proj.SingVal) && isempty(proj.CompMask)
            proj.Method  = 'Other';
        end
        % Try to get ICA method from comment
        if strcmp(proj.Method, 'ICA')
            tmp = regexp(proj.Comment, 'ICA_\w*', 'match');
            if ~isempty(tmp)
                proj.Method = tmp{1};
            end
        end
    else
        proj = OldProj;
    end
end
