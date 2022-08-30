function varargout = process_spike_triggered_average( varargin )
% PROCESS_SPIKE_TRIGGERED_AVERAGE: Computes the spike triggered average.
% Select a time window around the spikes of a specific neuron and average the LFPs of each electrode

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
% Authors: Konstantinos Nasiotis, 2018-2019
%          Francois Tadel, 2022

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Spike triggered average';
    sProcess.FileTag     = 'STA';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Electrophysiology';
    sProcess.Index       = 1230;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/e-phys/functions#Spike_triggered_average';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 2;
    % Options: Segment around spike
    sProcess.options.timewindow.Comment  = 'Spike time window: ';
    sProcess.options.timewindow.Type     = 'range';
    sProcess.options.timewindow.Value    = {[-0.150, 0.150],'ms',[]};
    % Options: Parallel Processing
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


    % ===== LOAD INPUTS =====
    % Loads all the data outside of the parfor, so it doesn't fail
    nTrials = length(sInputs);
    DataMats = cell(1, nTrials);
    ChannelFlag = [];
    for iFile = 1:length(sInputs)
        DataMats{iFile} = in_bst_data(sInputs(iFile).FileName);
        if isempty(ChannelFlag)
            ChannelFlag = DataMats{iFile}.ChannelFlag;
        else
            ChannelFlag(DataMats{iFile}.ChannelFlag == -1) = -1;
        end
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
    ChannelMat = in_bst_channel(sInputs(1).ChannelFile);

    
    % === START COMPUTATION ===
    % Input time window
    time_segmentAroundSpikes = linspace(TimeWindow(1), TimeWindow(2), abs(TimeWindow(2))* sampling_rate + abs(TimeWindow(1))* sampling_rate + 1);    
    % Get LPFs
    LFP_trials = cell(1, nTrials);
    if isParallel
        parfor iFile = 1:nTrials
            LFP_trials{iFile} = get_LFPs(DataMats{iFile}, ChannelMat, TimeWindow, time_segmentAroundSpikes, sampling_rate);
        end 
    else
        for iFile = 1:nTrials
            LFP_trials{iFile} = get_LFPs(DataMats{iFile}, ChannelMat, TimeWindow, time_segmentAroundSpikes, sampling_rate);
        end 
    end


    % ===== COMPUTE SPIKE TRIGGERED AVERAGE =====
    % The Spike Triggered Average should be a 3d matrix
    % Number of neurons x Frequencies x Electrodes
    % Ultimately the user will select the NEURON that wants to be displayed,
    % and a 2D image with the other two dimensions will appear, showing the
    % coherence of the spikes of that neuron with the LFPs on every
    % electrode on all frequencies.
    
    % Create a cell that holds all of the labels and one for the unique labels
    % This will be used to take the averages using the appropriate indices
    all_labels = {};
    labelsNeurons = {}; % Unique neuron labels (each trial might have different number of neurons). We need everything that appears.
    for iFile = 1:nTrials
        for iNeuron = 1:length(LFP_trials{iFile})
            all_labels{iNeuron,iFile} = LFP_trials{iFile}(iNeuron).label;
            labelsNeurons{end+1} = LFP_trials{iFile}(iNeuron).label;
        end
    end
    labelsNeurons = unique(labelsNeurons,'stable');
    
    % Compute STA per individual neuron
    for iNeuron = 1:length(labelsNeurons)
        % For each TRIAL, get the index of the label that corresponds to the appropriate neuron.
        for ii = 1:size(all_labels,1)
            for jj = 1:size(all_labels,2)
                logicalEvents(ii,jj) = strcmp(all_labels{ii,jj}, labelsNeurons{iNeuron});
            end
        end
        
        iEvents = zeros(size(all_labels,2),1);
        for iFile = 1:size(all_labels,2)
            temp = find(logicalEvents(:,iFile));
            if ~isempty(temp)
                iEvents(iFile) = temp;
            else
                iEvents(iFile) = 0; % This shows that that neuron didn't fire any spikes on that trial
            end
        end
        
        % Compute the averages of the appropriate indices
        STA_single_neuron = zeros(length(ChannelMat.Channel), length(time_segmentAroundSpikes)); 
        std_single_neuron = zeros(length(ChannelMat.Channel), length(time_segmentAroundSpikes)); 
        divideBy = 0;
        for iFile = 1:size(all_labels,2)
            if iEvents(iFile)~=0
                STA_single_neuron = STA_single_neuron + LFP_trials{iFile}(iEvents(iFile)).nSpikes * LFP_trials{iFile}(iEvents(iFile)).avgLFP; % The avgLFP are sum actually. 
                divideBy = divideBy + LFP_trials{iFile}(iEvents(iFile)).nSpikes;
                
                % Here I have the assumption that the LFPs on all trials
                % have homogeneity in their variance (Cohen, 1988, p.67): 
                % http://www.utstat.toronto.edu/~brunner/oldclass/378f16/readings/CohenPower.pdf
                % https://www.statisticshowto.datasciencecentral.com/pooled-standard-deviation/
                std_single_neuron = std_single_neuron + (LFP_trials{iFile}(iEvents(iFile)).nSpikes-1) * LFP_trials{iFile}(iEvents(iFile)).stdLFP.^2;
            end 
        end
        % Divide by total number of averages
        STA_single_neuron = (STA_single_neuron./divideBy)';
        std_single_neuron = sqrt(std_single_neuron./(divideBy - size(all_labels,2)));
    

        % Get meaningful label from neuron name
        better_label = panel_spikes('GetChannelOfSpikeEvent', labelsNeurons{iNeuron});
        neuron = panel_spikes('GetNeuronOfSpikeEvent', labelsNeurons{iNeuron});
        if ~isempty(neuron)
            better_label = [better_label ' #' num2str(neuron)];
        end


        % ===== SAVE FILE =====
        % Prepare output file structure
        FileMat = db_template('datamat');
        FileMat.F           = STA_single_neuron';
        FileMat.Time        = time_segmentAroundSpikes; 
        FileMat.Std         = 2 .* std_single_neuron; % MULTIPLY BY 2 TO GET 95% CONFIDENCE (ASSUMING NORMAL DISTRIBUTION)
        FileMat.Comment     = ['Spike Triggered Average: ' str_remove_parenth(DataMats{1}.Comment) ' (' better_label ')'];
        FileMat.DataType    = 'recordings';
        FileMat.ChannelFlag = ChannelFlag;
        FileMat.Device      = DataMats{1}.Device;
        FileMat.nAvg        = 1;
        FileMat.History     = DataMats{1}.History;

        % Add history field
        FileMat = bst_history('add', FileMat, 'compute', ['Spike Triggered Average: [' num2str(TimeWindow(1)) ', ' num2str(TimeWindow(2)) '] ms']);
        for iFile = 1:length(sInputs)
            FileMat = bst_history('add', FileMat, 'average', [' - ' sInputs(iFile).FileName]);
        end

        % Get output study
        [tmp, iTargetStudy] = bst_process('GetOutputStudy', sProcess, sInputs);
        sTargetStudy = bst_get('Study', iTargetStudy);
        % Output filename
        FileName = bst_process('GetNewFilename', bst_fileparts(sTargetStudy.FileName), 'data_STA');
        OutputFiles = {FileName};
        % Save output file and add to database
        bst_save(FileName, FileMat, 'v6');
        db_add_data(iTargetStudy, FileName, FileMat);
    end
end


%% ===== GET LFP =====
% Get the events that show neurons activity
function all = get_LFPs(trial, ChannelMat, TimeWindow, time_segmentAroundSpikes, sampling_rate)
    spikeEvents = []; % The spikeEvents variable holds the indices of the events that correspond to spikes.
    
    allChannelEvents = cellfun(@(x) panel_spikes('GetChannelOfSpikeEvent', x), {trial.Events.label}, 'UniformOutput', 0);
    for ielectrode = 1:length(ChannelMat.Channel)
        iEvents = find(strcmp(allChannelEvents, ChannelMat.Channel(ielectrode).Name)); % Find the index of the spike-events that correspond to that electrode (Exact string match)
        if ~isempty(iEvents)
            spikeEvents(end+1:end+length(iEvents)) = iEvents;
        end
    end

    % Get segments around each spike, FOR EACH NEURON
    all = struct();
    for iNeuron = 1:length(spikeEvents) % iNeuron is the iEvent
        % Check that the entire segment around the spikes [-150,150]ms is inside the trial segment and keep only those events
        iSel = trial.Events(spikeEvents(iNeuron)).times > trial.Time(1)   + abs(TimeWindow(1)) & ...
               trial.Events(spikeEvents(iNeuron)).times < trial.Time(end) - abs(TimeWindow(2));
        events_within_segment = round(trial.Events(spikeEvents(iNeuron)).times(iSel) .* sampling_rate);

        % Create a matrix that holds all the segments around the spike of that neuron, for all electrodes.
        allSpikeSegments_singleNeuron_singleTrial = zeros(length(events_within_segment),length(ChannelMat.Channel),length(time_segmentAroundSpikes));
        for ispike = 1:length(events_within_segment)
            allSpikeSegments_singleNeuron_singleTrial(ispike,:,:) = trial.F(:, ...
                round(abs(trial.Time(1))*sampling_rate) + events_within_segment(ispike) - round(abs(TimeWindow(1)) * sampling_rate) + 1 : ...
                round(abs(trial.Time(1))*sampling_rate) + events_within_segment(ispike) + round(abs(TimeWindow(2)) * sampling_rate) + 1);
        end

        all(iNeuron).label   = trial.Events(spikeEvents(iNeuron)).label;
        all(iNeuron).nSpikes = length(events_within_segment);
        all(iNeuron).avgLFP  = squeeze(sum(allSpikeSegments_singleNeuron_singleTrial,1));
        all(iNeuron).stdLFP  = squeeze(std(allSpikeSegments_singleNeuron_singleTrial,[],1));
        all(iNeuron).Used    = 0; % This indicates if this entry has already been used for computing the SFC (some spikes might not appear on every trial imported, so a new Neuron should be identified on a later trial).
    end
    
    % Check if any events had no spikes in the time-region of interest and remove them!
    %  Some spikes might be on the edges of the trial. Ultimately, the
    %  Spikes Channel i events would be considered in the STA (I mean the event group, not the events themselves), 
    %  but there would be a zeroed avgLFP included. Get rid of those events
    iEventsToRemove = find([all.nSpikes]==0);
    all = all(~ismember(1:length(all),iEventsToRemove));
end
