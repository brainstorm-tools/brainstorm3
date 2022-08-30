function varargout = process_spike_field_coherence( varargin )
% PROCESS_SPIKE_FIELD_COHERENCE: Computes the spike field coherence.

% DESCRIPTION: Algorithm
%    - Selects a time window around the spike
%    - Applies a FFT to each spike
%    - Normalizes by the FFT of the spike triggered average on the averages of the spikes FFTs.

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
% Authors: Konstantinos Nasiotis, 2018
%          Martin Cousineau, 2018
%          Francois Tadel, 2022

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Spike field coherence';
    sProcess.FileTag     = 'SFC';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Electrophysiology';
    sProcess.Index       = 1220;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/e-phys/functions#Spike_field_coherence';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Options: Segment around spike
    sProcess.options.timewindow.Comment  = 'Spike time window: ';
    sProcess.options.timewindow.Type     = 'range';
    sProcess.options.timewindow.Value    = {[-0.150, 0.150],'ms',[]};    
    % Options: Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'EEG, SEEG';
    % Options: Parallel
    sProcess.options.parallel.Comment = 'Parallel processing';
    sProcess.options.parallel.Type    = 'checkbox';
    sProcess.options.parallel.Value   = 0;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs)
    % Initialize returned values
    OutputFiles = {};
    % Get options
    isParallel = sProcess.options.parallel.Value;
    TimeWindow = sProcess.options.timewindow.Value{1};
    SensorTypes = sProcess.options.sensortypes.Value;
    
    % ===== PROCESS FILES =====
    % Check how many event groups we're processing
    listComments = cellfun(@str_remove_parenth, {sInputs.Comment}, 'UniformOutput', 0);
    [uniqueComments,tmp,iData2List] = unique(listComments);
    nLists = length(uniqueComments);
    % Process each even group seperately
    for iList = 1:nLists

        % === LOAD INPUTS ===
        % Get trials in this group
        sCurrentInputs = sInputs(iData2List == iList);
        nTrials = length(sCurrentInputs);

        % Load all the trials outside of the parfor so it won't fail
        DataMats = cell(1, nTrials);
        for iFile = 1:nTrials
            DataMats{iFile} = in_bst_data(sCurrentInputs(iFile).FileName);
        end

        % Check time window
        if TimeWindow(1)>=0 || TimeWindow(2)<=0
            bst_report('Error', sProcess, sInputs, 'The time-selection must be around the spikes.');
            return;
        elseif (TimeWindow(1) <= DataMats{1}.Time(1)) && (TimeWindow(2) >= DataMats{1}.Time(end))
            bst_report('Error', sProcess, sInputs, 'The spike window has to be smaller than the trial window.');
            return;
        end
        % Sampling frequency
        sampling_rate = round(abs(1. / (DataMats{1}.Time(2) - DataMats{1}.Time(1))));

        % Load channel file
        ChannelMat = in_bst_channel(sCurrentInputs(1).ChannelFile);
        % Find channel indices
        iChannels = channel_find(ChannelMat.Channel, SensorTypes);
        if isempty(iChannels)
            bst_report('Error', sProcess, sInputs, ['Channels not found: "' SensorTypes '".']);
            return;
        end


        % === COMPUTE FFT ===
        % Time around spike
        time_segmentAroundSpikes = linspace(TimeWindow(1), TimeWindow(2), abs(TimeWindow(2))* sampling_rate + abs(TimeWindow(1))* sampling_rate + 1);
        % Compute FFTs (in parallel if possible)
        FFT_trials = cell(1, nTrials);
        Freqs = cell(1, nTrials);
        if isParallel
            parfor iFile = 1:nTrials
                [FFT_trials{iFile}, Freqs{iFile}] = get_FFTs(DataMats{iFile}, iChannels, TimeWindow, time_segmentAroundSpikes, sampling_rate, ChannelMat);
            end
        else
            for iFile = 1:nTrials
                [FFT_trials{iFile}, Freqs{iFile}] = get_FFTs(DataMats{iFile}, iChannels, TimeWindow, time_segmentAroundSpikes, sampling_rate, ChannelMat);
            end
        end

        % ===== COMPUTE SFC =====
        % The Spike Field Coherence should be a 3d matrix
        % Number of neurons x Frequencies x Electrodes
        % Ultimately the user will select the NEURON that wants to be displayed,
        % and a 2D image with the other two dimensions will appear, showing the
        % coherence of the spikes of that neuron with the LFPs on every
        % electrode on all frequencies.

        % Create a cell that holds all of the labels and one for the unique labels
        % This will be used to take the averages using the appropriate indices
        all_labels = struct;
        labelsNeurons = {}; % Unique neuron labels (each trial might have different number of neurons). We need everything that appears.
        for iFile = 1:nTrials
            for iNeuron = 1:length(FFT_trials{iFile})
                if ~isempty(FFT_trials{iFile}(iNeuron)) % An empty struct here would be caused by no selection of spikes. This would be caused by the combination of large windows around the spiking events, and small trial window
                    all_labels.labels{iNeuron,iFile} = FFT_trials{iFile}(iNeuron).label;
                    if panel_spikes('IsSpikeEvent', FFT_trials{iFile}(iNeuron).label)
                        labelsNeurons{end+1} = FFT_trials{iFile}(iNeuron).label;
                    end
                end
            end
        end
        % Give an error if there were no spikes on any of the selected trials
        if isempty(labelsNeurons)
            bst_report('Error', sProcess, sInputs, ['No spikes selected for ' uniqueComments{iList} '.' ...
                'Select a smaller time-window around the spikes, or make sure there are spikes on these trials.']);
            return;
        end

        all_labels = all_labels.labels;
        labelsNeurons = unique(labelsNeurons,'stable');

        SFC = zeros(length(labelsNeurons), length(Freqs{iFile}), length(iChannels)); % Number of neurons x Frequencies x Electrodes
        
        for iNeuron = 1:length(labelsNeurons)
            
            temp_All_trials_sum_LFP = zeros(1, length(iChannels), length(time_segmentAroundSpikes)); 
            temp_All_trials_sum_FFT = zeros(length(Freqs{iFile}), length(iChannels));

            % For each TRIAL, get the index of the label that corresponds to the appropriate neuron.
            for ii = 1:size(all_labels,1)
                for jj = 1:size(all_labels,2)
                    logicalEvents(ii,jj) = strcmp(all_labels{ii,jj}, labelsNeurons{iNeuron});
                end
            end

            iEvents = zeros(size(all_labels,2),1);
            for iTrial = 1:size(all_labels,2)
                temp = find(logicalEvents(:,iTrial));
                if ~isempty(temp)
                    iEvents(iTrial) = temp;
                else
                    iEvents(iTrial) = 0; % This shows that that neuron didn't fire any spikes on that trial
                end
            end


            % Take the Averages of the appropriate indices
            divideBy = 0;
            for iTrial = 1:size(all_labels,2)
                if iEvents(iTrial)~=0
                    temp_All_trials_sum_LFP = temp_All_trials_sum_LFP + FFT_trials{iTrial}(iEvents(iTrial)).sumLFP;
                    temp_All_trials_sum_FFT = temp_All_trials_sum_FFT + FFT_trials{iTrial}(iEvents(iTrial)).sumFFT;
                    divideBy = divideBy + FFT_trials{iTrial}(iEvents(iTrial)).nSpikes;
                end
            end

            average_LFP = temp_All_trials_sum_LFP./divideBy;
            average_FFT = temp_All_trials_sum_FFT./divideBy;

            % Get The FFT of the AverageLFP
            FFTofAverageLFP = compute_FFT(average_LFP, time_segmentAroundSpikes);

            SFC_singleNeuron = squeeze(FFTofAverageLFP)./average_FFT; % Normalize by the FFT of the average LFP
            SFC_singleNeuron(isnan(SFC_singleNeuron))=0;              % If the spikes of a neuron only occur at the edges of the window that was selected, the Average LFP would be 0, 
                                                                      % and the division by 0 would give NaN as an output. This line takes care of that.

            SFC(iNeuron,:,:) = SFC_singleNeuron;
        end


        % ===== SAVE FILE =====
        % Prepare output file structure
        TfMat = db_template('timefreqmat');
        TfMat.TF       = SFC;
        TfMat.Time     = Freqs{iFile}; % These values are in order to trick Brainstorm with the correct values (This needs to be improved. Talk to Martin)
        TfMat.Freqs    = 1:length(iChannels);      % These values are in order to trick Brainstorm with the correct values (This needs to be improved. Talk to Martin)
        TfMat.Comment  = ['Spike Field Coherence: ' uniqueComments{iList}];
        TfMat.DataType = 'data';
        TfMat.RowNames = labelsNeurons;
        TfMat.Measure  = 'power';
        TfMat.Method   = 'morlet';
        TfMat.DataFile = []; % Leave blank because multiple parents
        TfMat.Options  = [];

        % Add history field
        TfMat = bst_history('add', TfMat, 'compute', ['Spike Field Coherence: [' num2str(TimeWindow(1)) ', ' num2str(TimeWindow(2)) '] ms']);
        for iFile = 1:length(sInputs)
            TfMat = bst_history('add', TfMat, 'average', [' - ' sInputs(iFile).FileName]);
        end

        % Get output study
        [tmp, iTargetStudy] = bst_process('GetOutputStudy', sProcess, sCurrentInputs);
        sTargetStudy = bst_get('Study', iTargetStudy);
        % Output filename
        FileName = bst_process('GetNewFilename', bst_fileparts(sTargetStudy.FileName), 'timefreq_spike_field_coherence');
        OutputFiles{end + 1} = FileName;
        % Save output file and add to database
        bst_save(FileName, TfMat, 'v6');
        db_add_data(iTargetStudy, FileName, TfMat);
    end
end


%% ===== GET FFT =====
function [all, Freqs] = get_FFTs(trial, iChannels, TimeWindow, time_segmentAroundSpikes, sampling_rate, ChannelMat)
    %% Get the events that show the NEURONS' activity =====
    spikeEvents = []; % The spikeEvents variable holds the indices of the events that correspond to spikes.

    allChannelEvents = cellfun(@(x) panel_spikes('GetChannelOfSpikeEvent', x), ...
        {trial.Events.label}, 'UniformOutput', 0);
    allChannelEvents = allChannelEvents(~cellfun('isempty', allChannelEvents));
    if isempty(allChannelEvents)
        error('No spike event found in this file.');
    end
    
    for iElec = 1:length(iChannels)
        ielectrode = iChannels(iElec);
        iEvents = find(strcmp(allChannelEvents, ChannelMat.Channel(ielectrode).Name)); % Find the index of the spike-events that correspond to that electrode (Exact string match)
        if ~isempty(iEvents)
            spikeEvents(end+1:end+length(iEvents)) = iEvents;
        end
    end

    all = struct();
    %% Get segments around each spike, FOR EACH NEURON
    for iNeuron = 1:length(spikeEvents) 

        % Check that the entire segment around the spikes i.e. :[-150,150]ms
        % is inside the trial segment and keep only those events
        iSel = trial.Events(spikeEvents(iNeuron)).times > trial.Time(1)   + abs(TimeWindow(1)) & ...
               trial.Events(spikeEvents(iNeuron)).times < trial.Time(end) - abs(TimeWindow(2));
        events_within_segment = round(trial.Events(spikeEvents(iNeuron)).times(iSel) .* sampling_rate);

        %% Create a matrix that holds all the segments around the spike
        % of that neuron, for all electrodes.
        allSpikeSegments_singleNeuron_singleTrial = zeros(length(events_within_segment),size(trial.F(iChannels,:),1),abs(TimeWindow(2))* sampling_rate + abs(TimeWindow(1))* sampling_rate + 1);

        for ispike = 1:length(events_within_segment)
            allSpikeSegments_singleNeuron_singleTrial(ispike,:,:) = trial.F(iChannels, ...
                events_within_segment(ispike) - abs(TimeWindow(1)) * sampling_rate + round(abs(trial.Time(1)) * sampling_rate) + 1: ...
                events_within_segment(ispike) + abs(TimeWindow(2)) * sampling_rate + round(abs(trial.Time(1)) * sampling_rate) + 1  ...
            );
        end

        [FFT_allSpike_singleNeuron_singleTrial, Freqs] = compute_FFT(allSpikeSegments_singleNeuron_singleTrial, time_segmentAroundSpikes);

        all(iNeuron).label   = trial.Events(spikeEvents(iNeuron)).label;
        all(iNeuron).nSpikes = length(events_within_segment);
        all(iNeuron).sumFFT  = squeeze(sum(FFT_allSpike_singleNeuron_singleTrial,1)); % Sum of the FFTs of all spike segments
        all(iNeuron).sumLFP  = sum(allSpikeSegments_singleNeuron_singleTrial,1);      % Spike-Triggered-Sum (not average yet). I intentionally leave it 3d so it can be imported in compute_FFT
        all(iNeuron).Used    = 0; % This indicates if this entry has already been used for computing the SFC (some spikes might not appear on every trial imported, so a new Neuron should be identified on a later trial).

    end
    
    %% Check if any events had no spikes in the time-region of interest and remove them!
    %  Some spikes might be on the edges of the trial. Ultimately, the
    %  Spikes Channel i events would be considered in the STA (I mean the event group, not the events themselves), 
    %  but there would be a zeroed avgLFP included. Get rid of those events
    iEventsToRemove = find([all.nSpikes]==0);
    
    all = all(~ismember(1:length(all),iEventsToRemove));
end


%% ===== COMPUTE FFT =====
function [TF, Freqs] = compute_FFT(F, time)

    % This function if made for 3-dimensional F
    dim = 3;

    % Next power of 2 from length of signal
    nTime = length(time);
    % NFFT = 2^nextpow2(nTime);    % Function fft() pads the signal with zeros before computing the FT
    NFFT = nTime;                  % No zero-padding: Nfft = Ntime
    sfreq = 1 / (time(2) - time(1));
    % Positive frequency bins spanned by FFT
    Freqs = sfreq / 2 * linspace(0, 1, NFFT / 2 + 1);
    % Remove mean of the signal
    F = bst_bsxfun(@minus, F, mean(F,dim));
    
    % % % % % % %  % Apply a hamming window to the signal
    % Add a fake dimension on the hamming window to use in bsxfun
    hamming_window = zeros(1,1, size(F,dim));
    hamming_window_temp = bst_window('hamming', size(F,dim)');
    hamming_window(1,1,:) = hamming_window_temp; clear hamming_window_temp
    F = bst_bsxfun(@times, F, hamming_window);

    % Compute FFT
    Ffft = fft(F, NFFT, dim);
    % Keep only first half
    % (x2 to recover full power from negative frequencies)
    TF = 2 * Ffft(:, :, 1:floor(NFFT / 2) + 1) ./ nTime; % I added floor
    
    %%%%%%%%%%%% This is added. SFC doesn't need the complex values %%%%%%%
    TF = abs(TF) .^ 2;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Permute dimensions: time and frequency
    TF = permute(TF, [1 3 2]);
end




