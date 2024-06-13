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
% Process based on the AUTO method from Trial Exclusion in ArtifactScanTool
% https://github.com/nichrishayes/ArtifactScanTool

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Detect bad: MAD peak-to-peak and gradient';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Artifacts';
    sProcess.Index       = 116;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ArtifactsDetect#Other_detection_processes';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'raw', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    % Warning
    sProcess.options.warning.Comment = ['<B>Warning</B>: ONLY FOR MEG, AUTOMATIC<BR>' ...
                                        '<BR>' ...
                                        '<BR>' ...
                                        '<BR>' ...
                                        '<BR><BR>'];
    sProcess.options.warning.Type    = 'label';
    % Time window
    sProcess.options.timewindow.Comment = 'Time window:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    sProcess.options.sep1.Type    = 'separator';
    % Option: Window length
    sProcess.options.win_length.Comment = 'Length of analysis window: ';
    sProcess.options.win_length.Type    = 'value';
    sProcess.options.win_length.Value   = {1, 's', []};
    sProcess.options.win_length.InputTypes = {'raw'};
    % TODO for raw, only complete windows will be analyzed

    % Option: Number of std for amplitude and grandient
    sProcess.options.n_std.Comment = 'Number of std for Amplitude and Gradient: ';
    sProcess.options.n_std.Type    = 'value';
    sProcess.options.n_std.Value   = {3, 'std', []};
    % Option: Ignore sign for gradient
    sProcess.options.abs_gradient.Comment = 'Ignore sign for Gradient: ';
    sProcess.options.abs_gradient.Type    = 'checkbox';
    sProcess.options.abs_gradient.Value   = 1;
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
    % Number of std
    nStd = sProcess.options.n_std.Value{1};
    if nStd <= 0
        bst_error('Number of std must be greater than 0', 'Detect bad segments', 0);
        return;
    end
    abs_gradient = sProcess.options.abs_gradient.Value;

    % TODO error if modality is not MEG, MEG GRAD or MEG MAG
    modality = 'MEG';

    % Group files by Study
    [iGroups, ~, StudyPaths] = process_average('SortFiles', sInputsAll, 3);

    OutputFiles = {};
    % ===== LOOP ON STUDIES =====
    for ix = 1 : length(StudyPaths)
        % TODO progressbar
        %bst_progress('set', progressPos + round(ix / length(StudyPaths) * 100));
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
        if ~ismember(modality, Modalities)
            % TODO ERROR, modality was not found
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
            % MEG channels
            iMegChannels = good_channel(ChannelMat.Channel, DataMat.ChannelFlag, modality);
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
            % Compute thresholds
            threshold_p2p      = median(max_p2p)      + (nStd * mad(max_p2p,1));
            threshold_gradient = median(max_gradient) + (nStd * mad(max_gradient,1));
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
            bst_report('Info', sProcess, sInputs(1), sprintf('Subject = %s, Study = %s, P2P threshold = %E, Gradient threshold %E, Total windows = %d, Acepted files = %d', ...
                                                             sSubject.Name, sStudy.Name, threshold_p2p, threshold_gradient, nWindows, nWindows-length(iBadWindows)));
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
                % MEG channels
                iMegChannels = good_channel(ChannelMat.Channel, DataMat.ChannelFlag, modality);
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
            % Compute thresholds
            threshold_p2p      = median(max_p2p)      + (nStd * mad(max_p2p,1));
            threshold_gradient = median(max_gradient) + (nStd * mad(max_gradient,1));
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
            % Report by Study
            bst_report('Info', sProcess, sInputs(1), sprintf('Subject = %s, Study =%s, P2P threshold = %E, Gradient threshold %E, Total files = %d, Acepted files = %d', ...
                                                             sSubject.Name, sStudy.Name, threshold_p2p, threshold_gradient, nFiles, nFiles-length(iBadTrials)));
            % Return only good files
            iGoodTrials = setdiff(1:length(sInputs), iBadTrials);
            OutputFiles = [OutputFiles, sInputs(iGoodTrials).FileName];
        end
    end
end
