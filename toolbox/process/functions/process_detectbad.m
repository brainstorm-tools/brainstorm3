function varargout = process_detectbad( varargin )
% PROCESS_DETECTBAD: Detection of bad channels based peak-to-peak thresholds.

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
% Authors: Francois Tadel, 2010-2011

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Detect bad channels: peak-to-peak';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Artifacts';
    sProcess.Index       = 115;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/MedianNerveCtf#Review_the_individual_trials';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'data'};
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
    % Reject entire trial
    sProcess.options.sep2.Type    = 'separator';
    sProcess.options.rejectmode.Comment = {'Reject only the bad channels', 'Reject the entire trial'};
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
        Comment = 'Detect bad trials: Peak-to-peak ';
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
    % Reject entire trial
    isRejectTrial = (sProcess.options.rejectmode.Value == 2);
    
    % Initializations
    iBadTrials = [];
    progressPos = bst_progress('get');
    prevChannelFile = '';
    
    % ===== LOOP ON FILES =====
    for iFile = 1:length(sInputs)
        % === LOAD ALL DATA ===
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
        % Get modalities
        Modalities = unique({ChannelMat.Channel.Type});
        % Load file
        DataMat = in_bst_data(sInputs(iFile).FileName, 'F', 'ChannelFlag', 'History', 'Time');
        % Scale gradiometers / magnetometers:
        %    - Neuromag: Apply axial factor to MEG GRAD sensors, to convert in fT/cm
        %    - CTF: Apply factor to MEG REF gradiometers
        DataMat.F = bst_scale_gradmag(DataMat.F, ChannelMat.Channel);
        % Get time window
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
        % List of bad channels for this file
        iBadChan = [];
        
        % === LOOP ON MODALITIES ===
        for iMod = 1:length(Modalities)
            % === GET REJECTION CRITERIA ===
            % Get threshold according to the modality
            if ismember(Modalities{iMod}, {'MEG', 'MEG GRAD'})
                Threshold = Criteria.meggrad;
            elseif strcmpi(Modalities{iMod}, 'MEG MAG')
                Threshold = Criteria.megmag;
            elseif strcmpi(Modalities{iMod}, 'EEG')
                Threshold = Criteria.eeg;
            elseif ~isempty(strfind(lower(Modalities{iMod}), 'eog'))
                Threshold = Criteria.eog;
            elseif ~isempty(strfind(lower(Modalities{iMod}), 'ecg')) || ~isempty(strfind(lower(Modalities{iMod}), 'ekg'))
                Threshold = Criteria.ecg;
            else
                continue;
            end
            % If threshold is [0 0]: nothing to do
            if isequal(Threshold, [0 0])
                continue;
            end
            
            % === DETECT BAD CHANNELS ===
            % Get channels for this modality
            iChan = good_channel(ChannelMat.Channel, DataMat.ChannelFlag, Modalities{iMod});
            % Get data to test
            DataToTest = DataMat.F(iChan, iTime);
            % Compute peak-to-peak values for all the sensors
            p2p = (max(DataToTest,[],2) - min(DataToTest,[],2));
            % Get bad channels
            iBadChanMod = find((p2p < Threshold(1)) | (p2p > Threshold(2)));
            % If some bad channels were detected
            if ~isempty(iBadChanMod)
                % Convert indices back into the intial Channels structure
                iBadChan = [iBadChan, iChan(iBadChanMod)];
            end
        end
        
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
    % Record bad trials in study
    if ~isempty(iBadTrials)
        SetTrialStatus({sInputs(iBadTrials).FileName}, 1);
        bst_report('Info', sProcess, sInputs(iFile), sprintf('Epochs tested: %d - Bad epochs: %d (%d%%)', length(sInputs), length(iBadTrials), round(nnz(iBadTrials)/length(sInputs)*100)));
    end
    % Return only good trials
    iGoodTrials = setdiff(1:length(sInputs), iBadTrials);
    OutputFiles = {sInputs(iGoodTrials).FileName};
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
    % Remove path from all files
    for i = 1:length(FileNames)
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




