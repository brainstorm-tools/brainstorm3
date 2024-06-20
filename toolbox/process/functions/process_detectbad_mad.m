function varargout = process_detectbad_mad( varargin )
% PROCESS_DETECTBAD_MAD: Detection based on +-n median absolute deviation from amplitude and gradient medians

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
% Authors: Raymundo Cassani, 2024
%          Alex Wiesman, 2024
%
% Process based on the AUTO and MANUAL methods from Trial Exclusion in ArtifactScanTool
% https://github.com/nichrishayes/ArtifactScanTool

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Detect bad: amplitude and gradient thresholds';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Artifacts';
    sProcess.Index       = 116;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ArtifactsDetect#Other_detection_processes';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'raw', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    % Extra info
    sProcess.options.info.Comment = ['Reject bad segments/trials on MEG recordings, based on:<BR>'...
                                     '1. peak-to-peak amplitude, and/or<BR>' ...
                                     '2. numerical gradient values <BR> ' ...
                                     'outside of specified thresholds.<BR>' ...
                                     '<BR>', ...
                                     '<BR>'];
    sProcess.options.info.Type    = 'label';
    % Time window
    sProcess.options.timewindow.Comment     = 'Time window:';
    sProcess.options.timewindow.Type        = 'timewindow';
    sProcess.options.timewindow.Value       = [];
    % Option: Window length
    sProcess.options.win_length.Comment     = 'Length of analysis window: ';
    sProcess.options.win_length.Type        = 'value';
    sProcess.options.win_length.Value       = {1, 's', []};
    sProcess.options.win_length.InputTypes  = {'raw'};
    % Warning on complete windows
    sProcess.options.warning_raw.Comment    = 'Only will complete windows be analyzed';
    sProcess.options.warning_raw.Type       = 'label';
    sProcess.options.warning_raw.InputTypes = {'raw'};
    % Separator
    sProcess.options.sep1.Type              = 'separator';
    % Threshold method: Auto or Manual
    sProcess.options.threshold_method.Comment    = {'auto', 'manual', 'Threshold method: '; ...
                                                    'auto', 'manual', ''};
    sProcess.options.threshold_method.Type       = 'radio_linelabel';
    sProcess.options.threshold_method.Value      = 'auto';
    sProcess.options.threshold_method.Controller = struct('auto', 'auto', 'manual', 'manual');
    % AUTO
    % Option: Number of mad for amplitude and grandient
    sProcess.options.n_mad.Comment = 'Number of median absolute deviations for thresholds:';
    sProcess.options.n_mad.Type    = 'value';
    sProcess.options.n_mad.Value   = {3, 'mad', []};
    sProcess.options.n_mad.Class   = 'auto';
    % MANUAL
    % Option: Threshold p2p amplitude
    sProcess.options.threshold_p2p.Comment  = 'Threshold peak-to-peak amplitude: ';
    sProcess.options.threshold_p2p.Type     = 'value';
    sProcess.options.threshold_p2p.Value    = {0, 'fT', 2};
    sProcess.options.threshold_p2p.Class    = 'manual';
    % Option: Threshold gradiente
    sProcess.options.threshold_grad.Comment = 'Threshold gradient: ';
    sProcess.options.threshold_grad.Type    = 'value';
    sProcess.options.threshold_grad.Value   = {0, 'fT/s', 2};
    sProcess.options.threshold_grad.Class   = 'manual';
    % Separator
    sProcess.options.sep2.Type              = 'separator';
    % Option: Ignore sign for gradient
    sProcess.options.abs_gradient.Comment   = 'Use absolute gradient: ';
    sProcess.options.abs_gradient.Type      = 'checkbox';
    sProcess.options.abs_gradient.Value     = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputsAll) %#ok<DEFNU>
    % ===== GET OPTIONS =====
    % Get time window
    if isfield(sProcess.options, 'timewindow') && isfield(sProcess.options.timewindow, 'Value') && iscell(sProcess.options.timewindow.Value) && ~isempty(sProcess.options.timewindow.Value)
        TimeWindow = sProcess.options.timewindow.Value{1};
    else
        TimeWindow = [];
    end
    % Check: Same FileType for all files
    is_raw = strcmp({sInputsAll.FileType},'raw');
    if ~all(is_raw) && ~all(~is_raw)
        bst_error('Please do not mix continous (raw) and imported data', 'Detect bad segments', 0);
        return;
    end
    % If raw file, get window length
    if is_raw(1) && isfield(sProcess.options, 'win_length') && ~isempty(sProcess.options.win_length) && ~isempty(sProcess.options.win_length.Value) && iscell(sProcess.options.win_length.Value)
        winLength  = sProcess.options.win_length.Value{1};
    end
    % Number of mad
    nMad = sProcess.options.n_mad.Value{1};
    if nMad <= 0
        bst_error('Number of MAD must be greater than 0', 'Detect bad segments', 0);
        return;
    end
    abs_gradient = sProcess.options.abs_gradient.Value;

    % Threshold method
    thMethod = sProcess.options.threshold_method.Value;
    switch thMethod
        case 'auto'
            isThAuto = 1;

        case 'manual'
            isThAuto = 0;
            threshold_p2p      = sProcess.options.threshold_p2p.Value{1}  * 1e-15;
            threshold_gradient = sProcess.options.threshold_grad.Value{1} * 1e-15;
            if threshold_p2p <= 0 || threshold_gradient <=0
                bst_error('Thresholds cannot be smaller than zero', 'Detect bad segments', 0);
                return;
            end

        otherwise
            bst_error(sprintf('Threshold method "%s" is not supported', thMethod), 'Detect bad segments', 0);
            return;
    end

    % Group files by Study
    [iGroups, ~, StudyPaths] = process_average('SortFiles', sInputsAll, 3);

    % Get current progressbar position
    progressPos = bst_progress('get');

    OutputFiles = {};
    % ===== LOOP ON STUDIES =====
    for ix = 1 : length(StudyPaths)
        bst_progress('set', progressPos + round(ix / length(StudyPaths) * 100));
        % Find Study in database
        [sStudy, iStudy] = bst_get('StudyWithCondition', StudyPaths{ix});
        % Find Subject with Study
        sSubject = bst_get('Subject', sStudy.BrainStormSubject);
        sInputs = sInputsAll(iGroups{ix});
        % Load channel file
        sChannel = bst_get('ChannelForStudy', iStudy);
        ChannelMat = in_bst_channel(sChannel.FileName);
        % Get MEG channels
        Modalities = channel_get_modalities(ChannelMat.Channel);
        if ~any(ismember(Modalities, {'MEG', 'MEG GRAD', 'MEG MAG'}))
            bst_error(sprintf('Channel files "%s" does not contain MEG sensors', sChannel.FileName), 'Detect bad segments', 0);
            return;
        end

        % === PROCESS RAW DATA ===
        if is_raw
            if length(sInputs) > 1
                bst_error(sprintf('Study "%s" has more than one continous (raw) data', sStudy.Condition), 'Detect bad segments', 0);
                return;
            end
            % === LOAD FILE ===
            % Load data file
            DataMat = in_bst_data(sInputs(1).FileName, 'F', 'ChannelFlag', 'History', 'Time');
            % Get sample bounds for time window
            if ~isempty(TimeWindow)
                iTime = bst_closest(sProcess.options.timewindow.Value{1}, DataMat.Time);
                if (iTime(1) == iTime(2)) && any(iTime(1) == DataMat.Time)
                    bst_report('Error', sProcess, sInputs(1), 'Invalid time definition.');
                    OutputFiles = [];
                    return;
                end
                iTime = iTime(1):iTime(2);
            else
                iTime = 1:length(DataMat.Time);
            end
            % Sampling frequency
            fs = 1 ./ (DataMat.Time(2) - DataMat.Time(1));
            % MEG channels (includes 'MEG GRAD' and 'MEG MAG')
            iMegChannels = good_channel(ChannelMat.Channel, DataMat.ChannelFlag, 'MEG');
            nChannels = length(iMegChannels);
            % Get maximum size of a data block
            ProcessOptions = bst_get('ProcessOptions');
            blockLengthSamples = max(floor(ProcessOptions.MaxBlockSize / nChannels), 1);
            % Length of window of analysis in samples
            winLengthSamples = round(fs*winLength);
            % Block length as multiple of the length of the analysis window
            blockLengthSamples = winLengthSamples * floor(blockLengthSamples / winLengthSamples);
            if blockLengthSamples == 0
                return
            end
            % List of bad events for this file
            sBadEvents = repmat(db_template('event'), 0);
            % Indices for each block
            [~, iTimesBlocks, R] = bst_epoching(iTime, blockLengthSamples);
            nWindows = size(iTimesBlocks, 1) * floor(blockLengthSamples / winLengthSamples);
            if ~isempty(R)
                if ~isempty(iTimesBlocks)
                    lastTime = iTimesBlocks(end, 2);
                else
                    lastTime = 0;
                end
                % Add the times for the remaining block
                iTimesBlocks = [iTimesBlocks; lastTime+1, lastTime+size(R,2)];
                nWindows = nWindows + floor(size(R,2) / winLengthSamples);
            end
            % Maximum Peak-2-peak per window
            max_p2p = zeros(nWindows, 1);
            % Maximum Gradient per window
            max_gradient = zeros(nWindows, 1);
            iWindow = 1;
            iTimesWindows = [];
            for iBlock = 1 : size(iTimesBlocks, 1)
                blockTimeBounds = DataMat.Time(iTimesBlocks(iBlock, :));
                % Load data from link to raw data
                RawDataMat = in_bst(sInputs(1).FileName, blockTimeBounds, 1, 0, 'no');
                % Scale gradiometers / magnetometers:
                %    - Neuromag: Apply axial factor to MEG GRAD sensors, to convert in fT/cm
                %    - CTF: Apply factor to MEG REF gradiometers
                RawDataMat.F = bst_scale_gradmag(RawDataMat.F, ChannelMat.Channel);
                [~, iTimesSegments] = bst_epoching(RawDataMat.F, winLengthSamples);
                iTimesWindows = [iTimesWindows; iTimesSegments + (iBlock-1)*blockLengthSamples];
                % Process each segment
                for iSegment = 1 : size(iTimesSegments, 1)
                    iTimesSegment = iTimesSegments(iSegment, :);
                    % Compute metrics
                    max_p2p(iWindow) = max(max(RawDataMat.F(iMegChannels, iTimesSegment(1):iTimesSegment(2)), [], 2) - ...
                                           min(RawDataMat.F(iMegChannels, iTimesSegment(1):iTimesSegment(2)), [], 2), [], 1);
                    if abs_gradient
                        max_gradient(iWindow) = max(max(abs(gradient(RawDataMat.F(iMegChannels, iTimesSegment(1):iTimesSegment(2)), 1./fs)), [], 2), [], 1);
                    else
                        max_gradient(iWindow) = max(max(gradient(RawDataMat.F(iMegChannels, iTimesSegment(1):iTimesSegment(2)), 1./fs), [], 2), [], 1);
                    end
                    iWindow = iWindow + 1;
                end
            end
            if isThAuto
                % Compute thresholds
                threshold_p2p      = median(max_p2p)      + (nMad * mad(max_p2p,1));
                threshold_gradient = median(max_gradient) + (nMad * mad(max_gradient,1));
            end
            % Create one bad event for each window over any threshold
            iBadWindows = [];
            for iWindow = 1 : nWindows
                % Criteria
                if max_p2p(iWindow) > threshold_p2p && max_gradient(iWindow) > threshold_gradient
                    criteria_str = 'p2p_gradient';
                elseif max_p2p(iWindow) > threshold_p2p
                    criteria_str = 'p2p';
                elseif max_gradient(iWindow) > threshold_gradient
                    criteria_str = 'gradient';
                else
                    continue
                end
                iBadWindows(end+1) = iWindow;
                % Create bad event
                sBadEvent          = db_template('event');
                sBadEvent.label    = sprintf('BAD_detectbad_mad_%s_window_%d', criteria_str, iWindow);
                sBadEvent.times    = DataMat.Time(iTimesWindows(iWindow,:))';
                sBadEvent.epochs   = 1;
                sBadEvent.channels = [];
                sBadEvent.notes    = [];
                % Add to events structure
                sBadEvents(end+1) = sBadEvent;
            end
            % Merge all bad events by criteria
            badEventCriteriaNames = cellfun(@(x) regexp(x, '^BAD_detectbad_mad_.*(?=_window)', 'match'), {sBadEvents.label});
            [badEventCriteriaNamesUnique, ~, ic] = unique(badEventCriteriaNames);
            for iCriteria = 1 : length(badEventCriteriaNamesUnique)
                % If only one event for criteria
                if sum(ic == iCriteria) == 1
                    sBadEvents = [sBadEvents, sBadEvents(ic == iCriteria)];
                    sBadEvents(end).label = badEventCriteriaNamesUnique{iCriteria};
                else
                    sBadEvents = process_evt_merge('Compute', '', sBadEvents, {sBadEvents(ic == iCriteria).label}, badEventCriteriaNamesUnique{iCriteria}, 0);
                end
            end
            % Remove bad events that were merged
            sBadEvents(1:length(ic)) = [];
            % Append bad events to original events in file
            DataMat.F.events = [DataMat.F.events, sBadEvents];
            % Save bad events
            bst_save(file_fullpath(sInputs(1).FileName), DataMat, 'v6', 1);
            % Report by Study
            GenerateReportEntry(sProcess, sInputs(1), sSubject, sStudy, is_raw, ...
                                {max_p2p, max_gradient}, {threshold_p2p, threshold_gradient}, ...
                                nWindows, nWindows-length(iBadWindows));
            % Return input file
            OutputFiles = [OutputFiles, sInputs(1).FileName];


        % === PROCESS IMPORTED DATA FILES ===
        else
            nFiles = length(sInputs);
            % Maximum Peak-2-peak per trial
            max_p2p = zeros(nFiles, 1);
            % Maximum Gradient per trial
            max_gradient = zeros(nFiles, 1);
            for iFile = 1:length(sInputs)
                % === LOAD FILE ===
                % Load data file
                DataMat = in_bst_data(sInputs(iFile).FileName, 'F', 'ChannelFlag', 'History', 'Time');
                % Get sample bounds for time window
                if ~isempty(TimeWindow)
                    iTime = bst_closest(sProcess.options.timewindow.Value{1}, DataMat.Time);
                    if (iTime(1) == iTime(2)) && any(iTime(1) == DataMat.Time)
                        bst_report('Error', sProcess, sInputs(iFile), 'Invalid time definition.');
                        OutputFiles = [];
                        return;
                    end
                    iTime = iTime(1):iTime(2);
                else
                    iTime = 1:length(DataMat.Time);
                end
                % Sampling frequency
                fs = 1 ./ (DataMat.Time(2) - DataMat.Time(1));
                % MEG channels (includes 'MEG GRAD' and 'MEG MAG')
                iMegChannels = good_channel(ChannelMat.Channel, DataMat.ChannelFlag, 'MEG');
                % Scale gradiometers / magnetometers:
                %    - Neuromag: Apply axial factor to MEG GRAD sensors, to convert in fT/cm
                %    - CTF: Apply factor to MEG REF gradiometers
                DataMat.F = bst_scale_gradmag(DataMat.F, ChannelMat.Channel);
                % Compute metrics
                max_p2p(iFile) = max(max(DataMat.F(iMegChannels, iTime), [], 2) - ...
                                       min(DataMat.F(iMegChannels, iTime), [], 2), [], 1);
                if abs_gradient
                    max_gradient(iFile) = max(max(abs(gradient(DataMat.F(iMegChannels, iTime), 1./fs)), [], 2), [], 1);
                else
                    max_gradient(iFile) = max(max(gradient(DataMat.F(iMegChannels, iTime), 1./fs), [], 2), [], 1);
                end
            end
            if isThAuto
                % Compute thresholds
                threshold_p2p      = median(max_p2p)      + (nMad * mad(max_p2p,1));
                threshold_gradient = median(max_gradient) + (nMad * mad(max_gradient,1));
            end
            % Set as bad trials over any threshold
            iBadTrials = [];
            % === TAG FILE ===
            for iFile = 1 : nFiles
                % Criteria
                if max_p2p(iFile) > threshold_p2p && max_gradient(iFile) > threshold_gradient
                    criteria_str = 'p2p_gradient';
                elseif max_p2p(iFile) > threshold_p2p
                    criteria_str = 'p2p';
                elseif max_gradient(iFile) > threshold_gradient
                    criteria_str = 'gradient';
                else
                    continue
                end
                iBadTrials(end+1) = iFile;
                % Add rejection criteria to history of file
                DataMat = bst_history('add', DataMat, 'detect', [FormatComment(sProcess) ' => Detected bad with MAP due to: ' criteria_str]);
                s.History = DataMat.History;
                bst_save(file_fullpath(sInputs(iFile).FileName), s, 'v6', 1);
                % Set bad in Study
                process_detectbad('SetTrialStatus', {sInputs(iFile).FileName}, 1);
            end
            % Report by study
            GenerateReportEntry(sProcess, sInputs(1), sSubject, sStudy, is_raw, ...
                                {max_p2p, max_gradient}, {threshold_p2p, threshold_gradient}, ...
                                nFiles, nFiles-length(iBadTrials));
            % Return only good files
            iGoodTrials = setdiff(1:length(sInputs), iBadTrials);
            OutputFiles = [OutputFiles, sInputs(iGoodTrials).FileName];
        end
    end
end


function GenerateReportEntry(sProcess, sInput, sSubject, sStudy, is_raw, maxValues, thresholdValues, nTotal, nAccepted)
    histLegends = {'Max P2P range', 'Max Gradient range'};
    histColors  = {'b', 'r'};
    histUnits   = {'fT', 'fT/s'};
    itemLabel = 'windows';
    if ~is_raw
        itemLabel = 'files';
    end
    % Report thresholds and number of windows/files
    bst_report('Info', sProcess, sInput, sprintf('Subject = %s, Study = %s, P2P threshold = %E %s, Gradient threshold %E %s, Total %s = %d, Acepted %s = %d', ...
                                                  sSubject.Name, sStudy.Name, ...
                                                  thresholdValues{1}*1e15, histUnits{1}, thresholdValues{2}*1e15, histUnits{2}, ...
                                                  itemLabel, nTotal, itemLabel, nAccepted));
    % Report histograms
    hFig = figure();
    for iHist = 1 : length(maxValues)
        ax = subplot(2,1,iHist);
        histogram(ax, maxValues{iHist}*1e15,'BinWidth',(max(maxValues{iHist}) - min(maxValues{iHist}))*1e15/10, 'FaceColor', histColors{iHist});
        line(ax, [thresholdValues{iHist}, thresholdValues{iHist}]*1e15, ylim, 'Color','black','LineStyle','--');
        legend(ax, histLegends{iHist});
        xlabel(ax, histUnits{iHist});
        ylabel(ax, [itemLabel, ' count'])
    end
    bst_report('Snapshot', hFig, sInput, [sProcess.Comment, ':: Distributions P2P and Gradient']);
    close(hFig);
end
