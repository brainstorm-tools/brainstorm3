function varargout = process_detectbad( varargin )
% PROCESS_DETECTBAD: Detection of bad channels based peak-to-peak thresholds.

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
% Authors: Francois Tadel, 2010-2021
%          Raymundo Cassani, 2024

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Detect bad channels: peak-to-peak';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Artifacts';
    sProcess.Index       = 115;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ArtifactsDetect#Other_detection_processes';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'raw', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    
    % Warning
    sProcess.options.warning.Comment = ['<B>Warning</B>: We do not recommend using this process for<BR>' ...
                                        'automatic detection of bad channels/trials. It is based only<BR>' ...
                                        'on the maximum of the signals, which is not representative<BR>' ...
                                        'of the data quality. For accurate bad segment identification,<BR>' ...
                                        'the only reliable option is the manual inspection of the data.<BR><BR>'];
    sProcess.options.warning.Type    = 'label';
    % Time window
    sProcess.options.timewindow.Comment = 'Time window:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    sProcess.options.sep1.Type    = 'separator';
    % MEG GRAD
    sProcess.options.meggrad.Comment = str_pad('MEG gradio:');
    sProcess.options.meggrad.Type    = 'range';
    sProcess.options.meggrad.Value   = {[0,0], 'fT', 2};  % Factor 15
    % MEG MAG
    sProcess.options.megmag.Comment = str_pad('MEG magneto:');
    sProcess.options.megmag.Type    = 'range';
    sProcess.options.megmag.Value   = {[0,0], 'fT', 2};   % Factor 15
    % EEG
    sProcess.options.eeg.Comment = str_pad('EEG:');
    sProcess.options.eeg.Type    = 'range';
    sProcess.options.eeg.Value   = {[0,0], '&mu;V', 2};   % Factor 6
    % SEEG/ECOG
    sProcess.options.ieeg.Comment = str_pad('SEEG/ECOG:');
    sProcess.options.ieeg.Type    = 'range';
    sProcess.options.ieeg.Value   = {[0,0], '&mu;V', 2};   % Factor 6
    % EOG
    sProcess.options.eog.Comment = str_pad('EOG:');
    sProcess.options.eog.Type    = 'range';
    sProcess.options.eog.Value   = {[0,0], '&mu;V', 2};   % Factor 6
    % ECG
    sProcess.options.ecg.Comment = str_pad('ECG:');
    sProcess.options.ecg.Type    = 'range';
    sProcess.options.ecg.Value   = {[0,0], 'mV', 2};   % Factor 3
    % Explanations
    sProcess.options.comment1.Comment = ['<BR>  - <B>First column</B>: Signal detection threshold (peak-to-peak)<BR>' 10 ...
                                         '  - <B>Second column</B>: Signal rejection threshold (peak-to-peak)'];
    sProcess.options.comment1.Type    = 'label';
    % Separator
    sProcess.options.sep2.Type    = 'separator';
    % Option: Window length
    sProcess.options.win_length.Comment = 'Length of analysis window: ';
    sProcess.options.win_length.Type    = 'value';
    sProcess.options.win_length.Value   = {1, 's', []};
    sProcess.options.win_length.InputTypes = {'raw'};
    % Reject entire trial
    sProcess.options.rejectmode.Comment = {'Reject only the bad channels', 'Reject the entire segments/trials (all channels)'};
    sProcess.options.rejectmode.Type    = 'radio';
    sProcess.options.rejectmode.Value   = 2;
end

%% ===== PREPARE STRINGS =====
function s = str_pad(s)
    padsize = 12;
    if (length(s) < padsize)
        s = [repmat('&nbsp;', 1, padsize - length(s)), s];
    end
    s = ['<FONT FACE="monospace">' s '</FONT>'];
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    % Detect bad trials or channels
    if (sProcess.options.rejectmode.Value == 1)
        Comment = 'Detect bad channels: Peak-to-peak ';
    else
        Comment = 'Detect bad segments/trials: Peak-to-peak ';
    end
    % What are the criteria
    for critName = {'meggrad', 'megmag', 'eeg', 'eog', 'ecg'}
        if ~isequal(sProcess.options.(critName{1}).Value{1}, [0, 0])
            Comment = sprintf('%s %s(%d-%d)', Comment, upper(critName{1}), round(sProcess.options.(critName{1}).Value{1}));
        end
    end
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % ===== GET OPTIONS =====
    % Get options values
    isEmpty = [];
    Criteria.meggrad = sProcess.options.meggrad.Value{1} .* 1e-15;
    isEmpty(end+1) = all(Criteria.meggrad == 0);
    Criteria.megmag = sProcess.options.megmag.Value{1} .* 1e-15;
    isEmpty(end+1) = all(Criteria.megmag == 0);
    Criteria.eeg = sProcess.options.eeg.Value{1} .* 1e-6;
    isEmpty(end+1) = all(Criteria.eeg == 0);
    Criteria.ieeg = sProcess.options.ieeg.Value{1} .* 1e-6;
    isEmpty(end+1) = all(Criteria.ieeg == 0);
    Criteria.eog = sProcess.options.eog.Value{1} .* 1e-6;
    isEmpty(end+1) = all(Criteria.eog == 0);
    Criteria.ecg = sProcess.options.ecg.Value{1} .* 1e-6;
    isEmpty(end+1) = all(Criteria.ecg == 0);
    % Get time window
    if isfield(sProcess.options, 'timewindow') && isfield(sProcess.options.timewindow, 'Value') && iscell(sProcess.options.timewindow.Value) && ~isempty(sProcess.options.timewindow.Value)
        TimeWindow = sProcess.options.timewindow.Value{1};
    else
        TimeWindow = [];
    end
    % If no criteria defined: nothing to do
    if isempty(Criteria) || all(isEmpty)
        bst_report('Error', sProcess, [], 'No criteria was defined to detect a bad channel.');
        OutputFiles = [];
        return;
    end
    % Check: Same FileType for all files
    is_raw = strcmp({sInputs.FileType},'raw');
    if ~all(is_raw) && ~all(~is_raw)
        bst_error('Please do not mix continous (raw) and imported data', 'Detect bad segments', 0);
        return;
    end
    % Reject entire trial
    isRejectTrial = (sProcess.options.rejectmode.Value == 2);
    % If raw file, get window length
    if is_raw(1) && isfield(sProcess.options, 'win_length') && ~isempty(sProcess.options.win_length) && ~isempty(sProcess.options.win_length.Value) && iscell(sProcess.options.win_length.Value)
        winLength  = sProcess.options.win_length.Value{1};
    end

    % Initializations
    iBadTrials = []; % Bad trials for imported files
    progressPos = bst_progress('get');
    prevChannelFile = '';
    
    % ===== LOOP ON FILES =====
    for iFile = 1:length(sInputs)
        % === LOAD FILE ===
        % Progress bar
        bst_progress('set', progressPos + round(iFile / length(sInputs) * 100));
        % Get file in database
        [sStudy, iStudy, iData] = bst_get('DataFile', sInputs(iFile).FileName);
        % Load channel file (if not already loaded
        ChannelFile = sInputs(iFile).ChannelFile;
        if isempty(prevChannelFile) || ~strcmpi(ChannelFile, prevChannelFile)
            prevChannelFile = ChannelFile;
            ChannelMat = in_bst_channel(ChannelFile);
        end
        % Load file
        DataMat = in_bst_data(sInputs(iFile).FileName, 'F', 'ChannelFlag', 'History', 'Time');
        nChannels = length(DataMat.ChannelFlag);
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
        
        % ===== DETECT BAD SEGMENTS =====
        % Process raw (continuous) data file in blocks
        if strcmp(sInputs(iFile).FileType, 'raw')
            % Get maximum size of a data block
            ProcessOptions = bst_get('ProcessOptions');
            blockLengthSamples = max(floor(ProcessOptions.MaxBlockSize / nChannels), 1);
            % Sampling frequency
            fs = 1 ./ (DataMat.Time(2) - DataMat.Time(1));
            % Length of window of analysis in samples
            winLengthSamples   = round(fs*winLength);
            % List of bad events for this file
            sBadEvents = repmat(db_template('event'), 0);
            % Indices for each block
            [~, iTimesBlocks, R] = bst_epoching(iTime, blockLengthSamples);
            if ~isempty(R)
                if ~isempty(iTimesBlocks)
                    lastTime = iTimesBlocks(end, 2);
                else
                    lastTime = 0;
                end
                % Add the times for the remaining block
                iTimesBlocks = [iTimesBlocks; lastTime+1, lastTime+size(R,2)];
            end
            for iBlock = 1 : size(iTimesBlocks, 1)
                blockTimeBounds = DataMat.Time(iTimesBlocks(iBlock, :));
                % Load data from link to raw data
                RawDataMat = in_bst(sInputs(iFile).FileName, blockTimeBounds, 1, 0, 'no');
                % Scale gradiometers / magnetometers:
                %    - Neuromag: Apply axial factor to MEG GRAD sensors, to convert in fT/cm
                %    - CTF: Apply factor to MEG REF gradiometers
                RawDataMat.F = bst_scale_gradmag(RawDataMat.F, ChannelMat.Channel);
                [~, iTimesSegments, R] = bst_epoching(RawDataMat.F, winLengthSamples);
                if ~isempty(R)
                    if ~isempty(iTimesSegments)
                        lastTime = iTimesSegments(end, 2);
                    else
                        lastTime = 0;
                    end
                    % Add the times for the remaining
                    iTimesSegments = [iTimesSegments; lastTime+1, lastTime+size(R,2)];
                end
                % Detect bad segments
                for iSegment = 1 : size(iTimesSegments, 1)
                    iTimesSegment = iTimesSegments(iSegment, :);
                    [iBadChannels, criteriaModalities] = Thresholding(RawDataMat.F(:,iTimesSegment(1):iTimesSegment(2)), RawDataMat.ChannelFlag, ChannelMat, Criteria);
                    % Create one bad event for each channel-segment
                    for ix = 1 : length(iBadChannels)
                        % Create bad event
                        sBadEvent = db_template('event');
                        sBadEvent.label    = sprintf('BAD_detectbad_%s_block_%04d_segment_%04d_channel_%04d', criteriaModalities{ix}, iBlock, iSegment, iBadChannels(ix));    
                        sBadEvent.times    = RawDataMat.Time(iTimesSegment)';
                        sBadEvent.epochs   = 1;
                        sBadEvent.channels = {{ChannelMat.Channel(iBadChannels(ix)).Name}};
                        sBadEvent.notes    = [];
                        % Add to events structure
                        sBadEvents(end+1) = sBadEvent;
                    end
                end
            end
            % If reject trial, ignore 'channels' field
            if isRejectTrial
                % Remove channel information
                [sBadEvents.channels] = deal([]);
            end
            % Merge all bad events by modality
            badEventModNames = cellfun(@(x) regexp(x, '^BAD_detectbad_[^\W_]+', 'match'), {sBadEvents.label});
            [badEventModNamesUnique, ~, ic] = unique(badEventModNames);
            for iMod = 1 : length(badEventModNamesUnique)
                % If only one event for modality
                if sum(ic == iMod) == 1
                    sBadEvents = [sBadEvents, sBadEvents(ic == iMod)];
                    sBadEvents(end).label = badEventModNamesUnique{iMod};
                else
                    sBadEvents = process_evt_merge('Compute', '', sBadEvents, {sBadEvents(ic == iMod).label}, badEventModNamesUnique{iMod}, 0);
                end
            end
            % Remove bad events that were merged
            sBadEvents(1:length(ic)) = [];
            % Combine bad channels for same bad segment
            if ~isRejectTrial
                for iBadEvent = 1 : length(sBadEvents)
                    % Combine channels for each unique window
                    [~, ics, ias] = unique(bst_round(sBadEvents(iBadEvent).times', 9), 'rows', 'stable');
                    for iw = 1 : length(ics)
                        % Combine channels
                        sBadEvents(iBadEvent).channels{ics(iw)} = [sBadEvents(iBadEvent).channels{ias == iw}];
                    end
                    % Delete all but unique windows
                    sBadEvents(iBadEvent).times    = sBadEvents(iBadEvent).times(:, ics);
                    sBadEvents(iBadEvent).epochs    = sBadEvents(iBadEvent).epochs(:, ics);
                    sBadEvents(iBadEvent).channels = sBadEvents(iBadEvent).channels(:, ics);
                end
            end
            % Append bad events to original events in file
            DataMat.F.events = [DataMat.F.events, sBadEvents];
            % Save bad events
            bst_save(file_fullpath(sInputs(iFile).FileName), DataMat, 'v6', 1);

        % Process imported data file
        else
            % File is already loaded
            % Scale gradiometers / magnetometers:
            %    - Neuromag: Apply axial factor to MEG GRAD sensors, to convert in fT/cm
            %    - CTF: Apply factor to MEG REF gradiometers
            DataMat.F = bst_scale_gradmag(DataMat.F, ChannelMat.Channel);
            % List of bad channels for this file
            iBadChan = Thresholding(DataMat.F(:,iTime), DataMat.ChannelFlag, ChannelMat, Criteria);

            % === TAG FILE ===
            if ~isempty(iBadChan)
                % Reject entire trial
                if isRejectTrial
                    % Mark trial as bad
                    iBadTrials(end+1) = iFile;
                    % Report
                    bst_report('Info', sProcess, sInputs(iFile), 'Marked as bad trial.');
                    % Update study
                    sStudy.Data(iData).BadTrial = 1;
                    bst_set('Study', iStudy, sStudy);
                % Reject channels only
                else
                    % Add detected channels to list of file bad channels
                    s.ChannelFlag = DataMat.ChannelFlag;
                    s.ChannelFlag(iBadChan) = -1;
                    % History
                    DataMat = bst_history('add', DataMat, 'detect', [FormatComment(sProcess) ' => Detected bad channels:' sprintf(' %d', iBadChan)]);
                    s.History = DataMat.History;
                    bst_report('Info', sProcess, sInputs(iFile), ['Bad channels: ' sprintf(' %d', iBadChan)]);
                    % Save file
                    bst_save(file_fullpath(sInputs(iFile).FileName), s, 'v6', 1);
                end
            end
        end
    end

    % Record bad trials in study
    if ~isempty(iBadTrials)
        SetTrialStatus({sInputs(iBadTrials).FileName}, 1);
        bst_report('Info', sProcess, sInputs(iFile), sprintf('Epochs tested: %d - Bad epochs: %d (%d%%)', length(sInputs), length(iBadTrials), round(nnz(iBadTrials)/length(sInputs)*100)));
    end
    % Return only good trials
    iGoodTrials = setdiff(1:length(sInputs), iBadTrials);
    OutputFiles = {sInputs(iGoodTrials).FileName};
end


%% ===== THRESHOLDING =====
% USAGE: iBadChannel = Thresholding(Data, ChannelFile, Criteria)

function [iBadChannel, criteriaModalities] = Thresholding(F, ChannelFlag, ChannelFile,  Criteria)
    % CALL: Thresholding(FileName, ChannelFile, ...)
    if ischar(ChannelFile)
        ChannelMat = in_bst_channel(ChannelFile);
    % CALL: Thresholding(FileName, ChannelMat, ...)
    else
        ChannelMat = ChannelFile;
    end
    % Get modalities
    Modalities = unique({ChannelMat.Channel.Type});

    % List of bad channels
    iBadChannel = [];
    % List of modality criteria used for each bad channel
    criteriaModalities = {};

    % === LOOP ON MODALITIES ===
    for iMod = 1:length(Modalities)
        % === GET REJECTION CRITERIA ===
        % Get threshold according to the modality
        if ismember(Modalities{iMod}, {'MEG', 'MEG GRAD'})
            criteriaField = 'meggrad';
        elseif strcmpi(Modalities{iMod}, 'MEG MAG')
            criteriaField = 'megmag';
        elseif strcmpi(Modalities{iMod}, 'EEG')
            criteriaField = 'eeg';
        elseif ismember(Modalities{iMod}, {'SEEG', 'EOCG'})
            criteriaField = 'ieeg';
        elseif ~isempty(strfind(lower(Modalities{iMod}), 'eog'))
            criteriaField = 'eog';
        elseif ~isempty(strfind(lower(Modalities{iMod}), 'ecg')) || ~isempty(strfind(lower(Modalities{iMod}), 'ekg'))
            criteriaField = 'ecg';
        else
            return;
        end
        Threshold = Criteria.(criteriaField);
        % If threshold is [0 0]: nothing to do
        if isequal(Threshold, [0 0])
            return;
        end

        % === DETECT BAD CHANNELS ===
        % Get channels for this modality
        iChan = good_channel(ChannelMat.Channel, ChannelFlag, Modalities{iMod});
        % Get data to test
        DataToTest = F(iChan, :);
        % Compute peak-to-peak values for all the sensors
        p2p = (max(DataToTest,[],2) - min(DataToTest,[],2));
        % Get bad channels
        iBadChanMod = find((p2p < Threshold(1)) | (p2p > Threshold(2)));
        % If some bad channels were detected
        if ~isempty(iBadChanMod)
            % Convert indices back into the intial Channels structure
            iBadChannel = [iBadChannel, iChan(iBadChanMod)];
            criteriaModalities = [criteriaModalities, repmat({criteriaField}, 1, length(iBadChanMod))];
        end
    end
end


%% ===== SET STUDY BAD TRIALS =====
% USAGE:  SetTrialStatus(FileNames, isBad)
%         SetTrialStatus(FileName, isBad)
%         SetTrialStatus(BstNodes, isBad)
function SetTrialStatus(FileNames, isBad)
    bst_progress('start', 'Set trial status', 'Updating list of bad trials...');
    % ===== PARSE INPUTS =====
    % CALL: SetTrialStatus(FileName, isBad)
    if ischar(FileNames)
        FileNames = {FileNames};
        [tmp__, iStudies, iDatas] = bst_get('DataFile', FileNames{1});
    % CALL: SetTrialStatus(FileNames, isBad)
    elseif iscell(FileNames)
        % Get studies indices
        iStudies = zeros(size(FileNames));
        iDatas   = zeros(size(FileNames));
        for i = 1:length(FileNames)
            [tmp__, iStudies(i), iDatas(i)] = bst_get('DataFile', FileNames{i});
        end
    % CALL: SetTrialStatus(BstNodes, isBad)
    else
        % Get dependent nodes
        [iStudies, iDatas] = tree_dependencies(FileNames, 'data', [], 1);
        % If an error occurred when looking for the for the files in the database
        if isequal(iStudies, -10)
            bst_error('Error in file selection.', 'Set trial status', 0);
            return;
        end
        % Get study
        sStudies = bst_get('Study', iStudies);
        % Get data filenames
        FileNames = cell(size(iStudies));
        for i = 1:length(iStudies)
            FileNames{i} = sStudies(i).Data(iDatas(i)).FileName;
        end
    end
    
    % Get protocol folders
    ProtocolInfo = bst_get('ProtocolInfo');
    % Get unique list of studies
    uniqueStudies = unique(iStudies);
    % Remove path from all files + Remove all BAD events
    for i = 1:length(FileNames)
        % Remove bad events
        if ~isBad
            DataMat = in_bst_data(FileNames{i}, 'Events');
            isModifiedFile = 0;
            for iEvt = 1:length(DataMat.Events)
                [DataMat.Events(iEvt), isModifiedEvt] = panel_record('SetEventGood', DataMat.Events(iEvt), DataMat.Events);
                if isModifiedEvt
                    isModifiedFile = 1;
                end
            end
            if isModifiedFile
                bst_report('Info', 'process_detectbad', FileNames{i}, 'Event names were modified to remove the tag "bad".');
                disp('BST> Event names were modified to remove the tag "bad".');
                bst_save(file_fullpath(FileNames{i}), DataMat, 'v6', 1);
            end
        end
        % Remove path
        [fPath, fBase, fExt] = bst_fileparts(FileNames{i});
        FileNames{i} = [fBase, fExt];
    end
    
    % ===== CHANGE TRIALS STATUS =====
    % Update each the study
    for i = 1:length(uniqueStudies)
        % === CHANGE STATUS IN DATABASE ===
        % Get files for this study
        iStudy = uniqueStudies(i);
        iFiles = find(iStudy == iStudies);
        % Get study
        sStudy = bst_get('Study', iStudy);
        % Mark trial as bad
        [sStudy.Data(iDatas(iFiles)).BadTrial] = deal(isBad);
        % Update database
        bst_set('Study', iStudy, sStudy);
        
        % === CHANGE NODES STATUS ===
        for iFile = 1:length(iFiles)
            % Get node
            bstNode = panel_protocols('GetNode', [], 'data', iStudy, iDatas(iFiles(iFile)));
            % Update node
            if ~isempty(bstNode)
                bstNode.setModifier(isBad);
            end
        end
        
        % === CHANGE STATUS IN STUDY FILE ===
        % Load study file
        StudyFile = bst_fullfile(ProtocolInfo.STUDIES, sStudy.FileName);
        StudyMat = load(StudyFile);
        % Get previous list of bad trials
        if ~isfield(StudyMat, 'BadTrials') || isempty(StudyMat.BadTrials)
            StudyMat.BadTrials = {};
        end
        % Add bad/good trials to current list
        if isBad
            StudyMat.BadTrials = union(StudyMat.BadTrials, FileNames(iFiles));
        else
            StudyMat.BadTrials = setdiff(StudyMat.BadTrials, FileNames(iFiles));
        end
        % Save list of bad trials in the study file
        bst_save(StudyFile, StudyMat, 'v7');
    end
    % Update tree
    %panel_protocols('UpdateNode', 'Study', uniqueStudies);
    panel_protocols('RepaintTree');
    bst_progress('stop');
end


