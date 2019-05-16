function varargout = process_spike_triggered_average( varargin )
% PROCESS_SPIKE_TRIGGERED_AVERAGE: Computes the spike triggered average.
% 

% There are two different TimeWindow Notations here:
% 1. Timewindow around the spike (This is the one that is asked as input when the function is called).
% 2. Timewindow of the trials imported to the function.

% The function selects a TimeWindow around the Spike of a specific neuron.
% Then averages the LFPs oe each electrode.
% If this Spike TimeWindow is outside the TimeWindow of the Trial, the
% spike is ignored for computation.



% USAGE:    sProcess = process_spike_triggered_average('GetDescription')
%        OutputFiles = process_spike_triggered_average('Run', sProcess, sInput)

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
% Authors: Konstantinos Nasiotis, 2018

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Spike Triggered Average';
    sProcess.FileTag     = 'STA';
    sProcess.Category    = 'custom';
    sProcess.SubGroup    = 'Electrophysiology';
    sProcess.Index       = 1506;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/e-phys/functions#Spike_triggered_Average';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Options: Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'EEG';
    % Options: Parallel Processing
    sProcess.options.paral.Comment = 'Parallel processing';
    sProcess.options.paral.Type    = 'checkbox';
    sProcess.options.paral.Value   = 1;
    % Options: Segment around spike
    sProcess.options.timewindow.Comment  = 'Spike Time window: ';
    sProcess.options.timewindow.Type     = 'range';
    sProcess.options.timewindow.Value    = {[-0.150, 0.150],'ms',[]};
   
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Initialize returned values
    OutputFiles = {};
    % Extract method name from the process name
    strProcess = strrep(strrep(func2str(sProcess.Function), 'process_', ''), 'data', '');
    
    % Add other options
    tfOPTIONS.Method = strProcess;
    if isfield(sProcess.options, 'sensortypes')
        tfOPTIONS.SensorTypes = sProcess.options.sensortypes.Value;
    else
        tfOPTIONS.SensorTypes = [];
    end    
    
    % If a time window was specified
    if isfield(sProcess.options, 'timewindow') && ~isempty(sProcess.options.timewindow) && ~isempty(sProcess.options.timewindow.Value) && iscell(sProcess.options.timewindow.Value)
        tfOPTIONS.TimeWindow = sProcess.options.timewindow.Value{1};
    elseif ~isfield(tfOPTIONS, 'TimeWindow')
        tfOPTIONS.TimeWindow = [];
    end

    tfOPTIONS.TimeVector = in_bst(sInputs(1).FileName, 'Time');

    if sProcess.options.timewindow.Value{1}(1)>=0 || sProcess.options.timewindow.Value{1}(2)<=0
        bst_report('Error', sProcess, sInputs, 'The time-selection must be around the spikes.');
    elseif sProcess.options.timewindow.Value{1}(1)==tfOPTIONS.TimeVector(1) && sProcess.options.timewindow.Value{1}(2)==tfOPTIONS.TimeVector(end)
        bst_report('Error', sProcess, sInputs, 'The spike window has to be smaller than the trial window');
    end
 
    
    % === OUTPUT STUDY ===
    % Get output study
    [tmp, iStudy] = bst_process('GetOutputStudy', sProcess, sInputs);
    tfOPTIONS.iTargetStudy = iStudy;
    
    % Get channel file
    sChannel = bst_get('ChannelForStudy', iStudy);
    % Load channel file
    ChannelMat = in_bst_channel(sChannel.FileName);
    
    
    % === START COMPUTATION ===
    sampling_rate = round(abs(1. / (tfOPTIONS.TimeVector(2) - tfOPTIONS.TimeVector(1))));
    
    selectedChannels = [];
    nChannels = 0;
    for iChannel = 1:length(ChannelMat.Channel)
       if strcmp(ChannelMat.Channel(iChannel).Type, 'EEG') || strcmp(ChannelMat.Channel(iChannel).Type, 'SEEG')
          nChannels = nChannels + 1;
          selectedChannels(end + 1) = iChannel;
       end
    end
    
    
    nTrials = length(sInputs);
    time_segmentAroundSpikes = linspace(sProcess.options.timewindow.Value{1}(1), sProcess.options.timewindow.Value{1}(2), abs(sProcess.options.timewindow.Value{1}(2))* sampling_rate + abs(sProcess.options.timewindow.Value{1}(1))* sampling_rate + 1);    

    
    % Prepare parallel pool, if requested
    if sProcess.options.paral.Value
        try
            poolobj = gcp('nocreate');
            if isempty(poolobj)
                parpool;
            end
        catch
            sProcess.options.paral.Value = 0;
            poolobj = [];
        end
    else
        poolobj = [];
    end
    
    
    
    %% Collect all the average LFPs for each trial for all Neurons.
    everything = struct(); % This is a struct 1xnTrials
    
    % I get the files outside of the parfor so it won't fail.
    % This loads the information from ALL TRIALS on ALL_TRIALS_files
    % (Shouldn't create a memory problem).
    ALL_TRIALS_files = struct();
    for iFile = 1:nTrials
        ALL_TRIALS_files(iFile).trial = in_bst(sInputs(iFile).FileName);
    end
    
    
    % Optimize this
    if ~isempty(poolobj) 
        parfor iFile = 1:nTrials
            [LFPs_single_trial] = get_LFPs(ALL_TRIALS_files(iFile).trial, nChannels, sProcess, time_segmentAroundSpikes, sampling_rate, ChannelMat);
            everything(iFile).LFPs_single_trial = LFPs_single_trial;
        end 
    else
        for iFile = 1:nTrials
            [LFPs_single_trial] = get_LFPs(ALL_TRIALS_files(iFile).trial, nChannels, sProcess, time_segmentAroundSpikes, sampling_rate, ChannelMat);
            everything(iFile).LFPs_single_trial = LFPs_single_trial;
        end 
    end
        
        
    
    %% Calculate the STA
    % The Spike Triggered Average should be a 3d matrix
    % Number of neurons x Frequencies x Electrodes
    % Ultimately the user will select the NEURON that wants to be displayed,
    % and a 2D image with the other two dimensions will appear, showing the
    % coherence of the spikes of that neuron with the LFPs on every
    % electrode on all frequencies.
    

    % Create a cell that holds all of the labels and one for the unique labels
    % This will be used to take the averages using the appropriate indices
    all_labels = struct;
    labelsForDropDownMenu = {}; % Unique neuron labels (each trial might have different number of neurons). We need everything that appears.
    for iFile = 1:nTrials
        for iNeuron = 1:length(everything(iFile).LFPs_single_trial)
            all_labels.labels{iNeuron,iFile} = everything(iFile).LFPs_single_trial(iNeuron).label;
            labelsForDropDownMenu{end+1} = everything(iFile).LFPs_single_trial(iNeuron).label;
        end
    end
    all_labels = all_labels.labels;
    labelsForDropDownMenu = unique(labelsForDropDownMenu,'stable');
    
    
    
    
    
    
    %% Compute STA per individual Neuron
    
    for iNeuron = 1:length(labelsForDropDownMenu)
        %% For each TRIAL, get the index of the label that corresponds to the appropriate neuron.
        
        for ii = 1:size(all_labels,1)
            for jj = 1:size(all_labels,2)
                logicalEvents(ii,jj) = strcmp(all_labels{ii,jj}, labelsForDropDownMenu{iNeuron});
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
        
        STA_single_neuron = zeros(length(ChannelMat.Channel), length(time_segmentAroundSpikes)); 

        %% Take the Averages of the appropriate indices
        divideBy = 0;
        for iTrial = 1:size(all_labels,2)
            if iEvents(iTrial)~=0
                STA_single_neuron = STA_single_neuron + everything(iTrial).LFPs_single_trial(iEvents(iTrial)).nSpikes * everything(iTrial).LFPs_single_trial(iEvents(iTrial)).avgLFP; % The avgLFP are sum actually. 
                divideBy = divideBy + everything(iTrial).LFPs_single_trial(iEvents(iTrial)).nSpikes;
            end 
        end
        
        STA_single_neuron = (STA_single_neuron./divideBy)';
    

        %% Get meaningful label from neuron name
        better_label = process_spikesorting_supervised('GetChannelOfSpikeEvent', labelsForDropDownMenu{iNeuron});
        neuron = process_spikesorting_supervised('GetNeuronOfSpikeEvent', labelsForDropDownMenu{iNeuron});
        if ~isempty(neuron)
            better_label = [better_label ' #' num2str(neuron)];
        end
            
        %% Fill the fields of the output files
        tfOPTIONS.ParentFiles = {sInputs.FileName};

        % Prepare output file structure
        FileMat.F = STA_single_neuron';
        FileMat.Time = time_segmentAroundSpikes; 

        FileMat.Std = [];
        FileMat.Comment = ['Spike Triggered Average: ' ...
                           str_remove_parenth(ALL_TRIALS_files(1).trial.Comment) ...
                           ' (' better_label ')'];
        FileMat.DataType = 'recordings';
        
        temp = in_bst(sInputs(1).FileName, 'ChannelFlag');
        FileMat.ChannelFlag = temp.ChannelFlag;
        FileMat.Device      = ALL_TRIALS_files(1).trial.Device;
        FileMat.Events      = [];
        
        FileMat.nAvg = 1;
        FileMat.ColormapType = [];
        FileMat.DisplayUnits = [];
        FileMat.History = ALL_TRIALS_files(1).trial.History;
        
        % Add history field
        FileMat = bst_history('add', FileMat, 'compute', ...
            ['Spike Triggered Average: [' num2str(tfOPTIONS.TimeWindow(1)) ', ' num2str(tfOPTIONS.TimeWindow(2)) '] ms']);
        

        % Get output study
        sTargetStudy = bst_get('Study', iStudy);
        % Output filename
        FileName = bst_process('GetNewFilename', bst_fileparts(sTargetStudy.FileName), 'data_STA');
        OutputFiles = {FileName};
        % Save output file and add to database
        bst_save(FileName, FileMat, 'v6');
        db_add_data(tfOPTIONS.iTargetStudy, FileName, FileMat);
    
    end

    
    % Display report to user
    bst_report('Info', sProcess, sInputs, 'Success');
    disp('BST> process_spike_field_coherence: Success');
    
    
    % Close parallel pool
    if sProcess.options.paral.Value
        if ~isempty(poolobj)
            delete(poolobj);
        end
    end
end






function all = get_LFPs(trial, nChannels, sProcess, time_segmentAroundSpikes, sampling_rate, ChannelMat)
    %% Get the events that show NEURONS' activity

    % Important Variable here!
    spikeEvents = []; % The spikeEvents variable holds the indices of the events that correspond to spikes.
    
    allChannelEvents = cellfun(@(x) process_spikesorting_supervised('GetChannelOfSpikeEvent', x), ...
        {trial.Events.label}, 'UniformOutput', 0);
    
    for ielectrode = 1: nChannels %selectedChannels
        iEvents = find(strcmp(allChannelEvents, ChannelMat.Channel(ielectrode).Name)); % Find the index of the spike-events that correspond to that electrode (Exact string match)
        if ~isempty(iEvents)
            spikeEvents(end+1:end+length(iEvents)) = iEvents;
        end
    end

    all = struct();
    %% Get segments around each spike, FOR EACH NEURON
    for iNeuron = 1:length(spikeEvents) % iNeuron is the iEvent

        % Check that the entire segment around the spikes [-150,150]ms
        % is inside the trial segment and keep only those events
        iSel = trial.Events(spikeEvents(iNeuron)).times > trial.Time(1)   + abs(sProcess.options.timewindow.Value{1}(1)) & ...
               trial.Events(spikeEvents(iNeuron)).times < trial.Time(end) - abs(sProcess.options.timewindow.Value{1}(2));
        events_within_segment = round(trial.Events(spikeEvents(iNeuron)).times(iSel) .* sampling_rate);

        %% Create a matrix that holds all the segments around the spike
        % of that neuron, for all electrodes.
        allSpikeSegments_singleNeuron_singleTrial = zeros(length(events_within_segment),length(ChannelMat.Channel),abs(sProcess.options.timewindow.Value{1}(2))* sampling_rate + abs(sProcess.options.timewindow.Value{1}(1))* sampling_rate + 1);

        for ispike = 1:length(events_within_segment)
            allSpikeSegments_singleNeuron_singleTrial(ispike,:,:) = trial.F(:, round(abs(trial.Time(1))*sampling_rate) + events_within_segment(ispike) - abs(sProcess.options.timewindow.Value{1}(1)) * sampling_rate + 1: ...
                                                                               round(abs(trial.Time(1))*sampling_rate) + events_within_segment(ispike) + abs(sProcess.options.timewindow.Value{1}(2)) * sampling_rate + 1 ...
                                                                           );
        end

        all(iNeuron).label   = trial.Events(spikeEvents(iNeuron)).label;
        all(iNeuron).nSpikes = length(events_within_segment);
        all(iNeuron).avgLFP  = squeeze(sum(allSpikeSegments_singleNeuron_singleTrial,1));
        all(iNeuron).Used    = 0; % This indicates if this entry has already been used for computing the SFC (some spikes might not appear on every trial imported, so a new Neuron should be identified on a later trial).


    end
    
    %% Check if any events had no spikes in the time-region of interest and remove them!
    %  Some spikes might be on the edges of the trial. Ultimately, the
    %  Spikes Channel i events would be considered in the STA (I mean the event group, not the events themselves), 
    %  but there would be a zeroed avgLFP included. Get rid of those events
    iEventsToRemove = find([all.nSpikes]==0);
    
    all = all(~ismember(1:length(all),iEventsToRemove));
    
end