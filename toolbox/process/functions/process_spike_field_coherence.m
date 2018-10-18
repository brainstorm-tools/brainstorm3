function varargout = process_spike_field_coherence( varargin )
% PROCESS_SPIKE_FIELD_COHERENCE: Computes the spike field coherence.
% 

% There are two different TimeWindow Notations here:
% 1. Timewindow around the spike (This is the one that is asked as input when the function is called).
% 2. Timewindow of the trials imported to the function.

% The function selects a TimeWindow around the Spike.
% Then applies an FFT to each Spike TimeWindow.
% Then nomralizes by the FFT of the spike triggered average on the averages of
% the SpikeWindow FFTs.

% If this Spike TimeWindow is outside the TimeWindow of the Trial, the
% spike is ignored for computation.



% USAGE:    sProcess = process_spike_field_coherence('GetDescription')
%        OutputFiles = process_spike_field_coherence('Run', sProcess, sInput)

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Konstantinos Nasiotis, 2018; Martin Cousineau, 2018

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Spike Field Coherence';
    sProcess.FileTag     = 'SFC';
    sProcess.Category    = 'custom';
    sProcess.SubGroup    = 'Electrophysiology';
    sProcess.Index       = 1607;
    sProcess.Description = 'http://science.sciencemag.org/content/suppl/2003/05/02/291.5508.1560.DC1';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'timefreq'};
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
    strProcess = strrep(strrep(func2str(sProcess.Function), 'process_', ''), 'timefreq', 'morlet');
    
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
    
    % Check how many event groups we're processing
    listComments = cellfun(@str_remove_parenth, {sInputs.Comment}, 'UniformOutput', 0);
    [uniqueComments,tmp,iData2List] = unique(listComments);
    nLists = length(uniqueComments);
    
    % Process each even group seperately
    for iList = 1:nLists
        sCurrentInputs = sInputs(iData2List == iList);
    
        % === OUTPUT STUDY ===
        % Get output study
        [~, iStudy, ~] = bst_process('GetOutputStudy', sProcess, sCurrentInputs);
        tfOPTIONS.iTargetStudy = iStudy;

        % Get channel file
        sChannel = bst_get('ChannelForStudy', iStudy);
        % Load channel file
        ChannelMat = in_bst_channel(sChannel.FileName);


        % === START COMPUTATION ===
        sampling_rate = round(abs(1. / (tfOPTIONS.TimeVector(2) - tfOPTIONS.TimeVector(1))));

        % Select the appropriate sensors
        nElectrodes = 0;
        selectedChannels = [];
        for iChannel = 1:length(ChannelMat.Channel)
           if strcmp(ChannelMat.Channel(iChannel).Type, 'EEG') || strcmp(ChannelMat.Channel(iChannel).Type, 'SEEG')
              nElectrodes = nElectrodes + 1;
              selectedChannels(end + 1) = iChannel;
           end
        end

        nTrials = length(sCurrentInputs);
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
            end
        else
            poolobj = [];
        end


        %% Compute the FFTs and collect all the average FFTs and LFPs for each trial.
        everything = struct(); % This is a struct 1xnTrials

        % I get the files outside of the parfor so it won't fail.
        % This loads the information from ALL TRIALS on ALL_TRIALS_files
        % (Shouldn't create a memory problem).
        ALL_TRIALS_files = struct();
        for iFile = 1:nTrials
            ALL_TRIALS_files(iFile).trial = in_bst(sCurrentInputs(iFile).FileName);
        end


        % Start Parallel Pool if needed
        if ~isempty(poolobj)
            parfor iFile = 1:nTrials
                [FFTs_single_trial, Freqs] = get_FFTs(ALL_TRIALS_files(iFile).trial, selectedChannels, sProcess, time_segmentAroundSpikes, sampling_rate, ChannelMat);
                everything(iFile).FFTs_single_trial = FFTs_single_trial;
                everything(iFile).Freqs = Freqs;
            end
        else
            for iFile = 1:nTrials
                [FFTs_single_trial, Freqs] = get_FFTs(ALL_TRIALS_files(iFile).trial, selectedChannels, sProcess, time_segmentAroundSpikes, sampling_rate, ChannelMat);
                everything(iFile).FFTs_single_trial = FFTs_single_trial;
                everything(iFile).Freqs = Freqs;
            end
        end



        %% Calculate the SFC
        % The Spike Field Coherence should be a 3d matrix
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
            for iNeuron = 1:length(everything(iFile).FFTs_single_trial)
                if ~isempty(everything(iFile).FFTs_single_trial(iNeuron)) % An empty struct here would be caused by no selectrion of spikes. This would be caused by the combination of large windows around the spiking events, and small trial window
                    all_labels.labels{iNeuron,iFile} = everything(iFile).FFTs_single_trial(iNeuron).label;
                    labelsForDropDownMenu{end+1} = everything(iFile).FFTs_single_trial(iNeuron).label;
                end
            end
        end
        
        % Give an error if there were no spikes on any of the selected
        % trials
        if isempty(labelsForDropDownMenu)
            error(['No spikes selected for ' uniqueComments{iList} '. Select a smaller time-window around the spikes, or make sure there are spikes on these trials'])
        end
        
        all_labels = all_labels.labels;
        labelsForDropDownMenu = unique(labelsForDropDownMenu,'stable');



        SFC = zeros(length(labelsForDropDownMenu), length(everything(1).Freqs), nElectrodes); % Number of neurons x Frequencies x Electrodes : 161x151x192
        
        for iNeuron = 1:length(labelsForDropDownMenu)
            
            temp_All_trials_sum_LFP = zeros(1,nElectrodes, length(time_segmentAroundSpikes));              %   1 x 192 x 301
            temp_All_trials_sum_FFT = zeros(length(everything(1).Freqs), nElectrodes);                     % 151 x 192
            
            
            %% For each TRIAL, get the index of the label that corresponds to the appropriate neuron.
%           logicalEvents = ismember(all_labels, labelsForDropDownMenu{iNeuron}); % Find the index of the spike-events that correspond to that electrode (Exact string match). This linearizes the cell. I need to dilenearize it.
            for ii = 1:size(all_labels,1)
                for jj = 1:size(all_labels,2)
                    logicalEvents(ii,jj) = strcmp(all_labels{ii,jj}, labelsForDropDownMenu{iNeuron});
                end
            end

            iEvents = zeros(size(all_labels,2),1);
            for iTrial = 1:size(all_labels,2)
                [temp, ~] = find(logicalEvents(:,iTrial));
                if ~isempty(temp)
                    iEvents(iTrial) = temp;
                else
                    iEvents(iTrial) = 0; % This shows that that neuron didn't fire any spikes on that trial
                end
            end


            %% Take the Averages of the appropriate indices
            divideBy = 0;
            for iTrial = 1:size(all_labels,2)
                if iEvents(iTrial)~=0
                    temp_All_trials_sum_LFP = temp_All_trials_sum_LFP + everything(iTrial).FFTs_single_trial(iEvents(iTrial)).sumLFP;
                    temp_All_trials_sum_FFT = temp_All_trials_sum_FFT + everything(iTrial).FFTs_single_trial(iEvents(iTrial)).sumFFT;
                    divideBy = divideBy + everything(iTrial).FFTs_single_trial(iEvents(iTrial)).nSpikes;
                end
            end

            average_LFP = temp_All_trials_sum_LFP./divideBy;
            average_FFT = temp_All_trials_sum_FFT./divideBy;

            % Get The FFT of the AverageLFP

            [FFTofAverageLFP, ~] = compute_FFT(average_LFP, time_segmentAroundSpikes);

            SFC_singleNeuron = squeeze(FFTofAverageLFP)./average_FFT; % Normalize by the FFT of the average LFP
            SFC_singleNeuron(isnan(SFC_singleNeuron))=0; % If the spikes of a neuron only occur at the edges of the window that was selected, the Average LFP would be 0, and the division by 0 would give NaN as an output. This line takes care of that.

            SFC(iNeuron,:,:) = SFC_singleNeuron;


        end

        
    %% Plot an example for proof of concept
% % % %    
% % % %     figure(1);
% % % %     
% % % %     iNeuron = 300
% % % %     
% % % %     imagesc(everything(1).Freqs,1:nElectrodes,squeeze(SFC(iNeuron,:,:))')        % SFC: Number of neurons x Frequencies x Electrodes : 161x151x192
% % % % %     imagesc(squeeze(abs(SFC_singleNeuron(:,:)))')        % SFC: Number of neurons x Frequencies x Electrodes : 161x151x192
% % % %     ylabel 'iElectrode'
% % % %     xlabel 'Frequency (Hz)'
% % % %     title ({'Spike Field Coherence';['Neuron ' labelsForDropDownMenu{iNeuron}]})
% % % %     colorbar

        %% Wrap everything into the output file

        tfOPTIONS.ParentFiles = {sCurrentInputs.FileName};

        % Prepare output file structure
        FileMat.TF = SFC;
        FileMat.Time = everything(1).Freqs; % These values are in order to trick Brainstorm with the correct values (This needs to be improved. Talk to Martin)
        FileMat.TFmask = [];
        FileMat.Freqs = 1:nElectrodes;      % These values are in order to trick Brainstorm with the correct values (This needs to be improved. Talk to Martin)
        FileMat.Std = [];
        FileMat.Comment = ['Spike Field Coherence: ' uniqueComments{iList}];
        FileMat.DataType = 'data';
        FileMat.TimeBands = [];
        FileMat.RefRowNames = [];
        FileMat.RowNames = labelsForDropDownMenu;
        FileMat.Measure = 'power';
        FileMat.Method = 'morlet';
        FileMat.DataFile = []; % Leave blank because multiple parents
        FileMat.SurfaceFile = [];
        FileMat.GridLoc = [];
        FileMat.GridAtlas = [];
        FileMat.Atlas = [];
        FileMat.HeadModelFile = [];
        FileMat.HeadModelType = [];
        FileMat.nAvg = [];
        FileMat.ColormapType = [];
        FileMat.DisplayUnits = [];
        FileMat.Options = tfOPTIONS;
        FileMat.History = [];

        % Add history field
        FileMat = bst_history('add', FileMat, 'compute', ...
            ['Spike Field Coherence: [' num2str(tfOPTIONS.TimeWindow(1)) ', ' num2str(tfOPTIONS.TimeWindow(2)) '] ms']);

        % Get output study
        sTargetStudy = bst_get('Study', iStudy);
        % Output filename
        FileName = bst_process('GetNewFilename', bst_fileparts(sTargetStudy.FileName), 'timefreq_spike_field_coherence');
        OutputFiles{end + 1} = FileName;
        % Save output file and add to database
        bst_save(FileName, FileMat, 'v6');
        db_add_data(tfOPTIONS.iTargetStudy, FileName, FileMat);
    end
        
    % Display report to user
    bst_report('Info', sProcess, sInputs, 'Success');
    disp('BST> process_spike_field_coherence: Success');
    
    
%     % Close parallel pool
%     if sProcess.options.paral.Value
%         if ~isempty(poolobj)
%             delete(poolobj);
%         end
%     end
end






function [all, Freqs] = get_FFTs(trial, selectedChannels, sProcess, time_segmentAroundSpikes, sampling_rate, ChannelMat)
    %% Get the events that show NEURONS' activity

    % Important Variable here!
    spikeEvents = []; % The spikeEvents variable holds the indices of the events that correspond to spikes.

    % Added the following snippet to avoid using a call to
    % process_spikesorting_supervised
    allChannelEvents = {};
    for iEvent = 1:length(trial.Events)
        if strfind(trial.Events(iEvent).label,'Spikes Channel')
            allChannelEvents{1,iEvent} = erase(trial.Events(iEvent).label,'Spikes Channel ');
            multiple_neurons_index_start = strfind(allChannelEvents{1,iEvent},'|');
            if multiple_neurons_index_start
                allChannelEvents{1,iEvent} = allChannelEvents{1,iEvent}(1:multiple_neurons_index_start(1)-2);
            end
        end
    end

    if isempty(allChannelEvents)
        error('No spike event found in this file.');
    end
    
    for iElec = 1:length(selectedChannels)
        ielectrode = selectedChannels(iElec);
        iEvents = find(strcmp(allChannelEvents, ChannelMat.Channel(ielectrode).Name)); % Find the index of the spike-events that correspond to that electrode (Exact string match)
        if ~isempty(iEvents)
            spikeEvents(end+1:end+length(iEvents)) = iEvents;
        end
    end

    all = struct();
    %% Get segments around each spike, FOR EACH NEURON
    for iNeuron = 1:length(spikeEvents) 

        % Check that the entire segment around the spikes [-150,150]ms
        % is inside the trial segment and keep only those events
        events_within_segment = trial.Events(spikeEvents(iNeuron)).samples(trial.Events(spikeEvents(iNeuron)).times > trial.Time(1)   + abs(sProcess.options.timewindow.Value{1}(1)) & ...
                                                                           trial.Events(spikeEvents(iNeuron)).times < trial.Time(end) - abs(sProcess.options.timewindow.Value{1}(2)));

        %% Create a matrix that holds all the segments around the spike
        % of that neuron, for all electrodes.
        allSpikeSegments_singleNeuron_singleTrial = zeros(length(events_within_segment),size(trial.F(selectedChannels,:),1),abs(sProcess.options.timewindow.Value{1}(2))* sampling_rate + abs(sProcess.options.timewindow.Value{1}(1))* sampling_rate + 1);

        for ispike = 1:length(events_within_segment)
            allSpikeSegments_singleNeuron_singleTrial(ispike,:,:) = trial.F(selectedChannels, events_within_segment(ispike) - abs(sProcess.options.timewindow.Value{1}(1)) * sampling_rate + round(abs(trial.Time(1))* sampling_rate): ...
                                                                                              events_within_segment(ispike) + abs(sProcess.options.timewindow.Value{1}(2)) * sampling_rate + round(abs(trial.Time(1))* sampling_rate)  ...
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




function [TF, Freqs] = compute_FFT(F, time)

% This is for testing the FFT output.
% Just add in different dimensions of F the created data
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %% Create a 3dimensional matrix to test the fft on it
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % Fs = 1000;                    % Sampling frequency
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % T = 1/Fs;                     % Sampling period
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % L = 301;                     % Length of signal
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % t = (0:L-1)*T;                % Time vector
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % x11 = cos(2*pi*50*t);      
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % x12 = cos(2*pi*150*t);      
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % x13 = cos(2*pi*300*t);
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % x21 = cos(2*pi*10*t); 
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % x22 = cos(2*pi*450*t);
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % x23 = cos(2*pi*80*t);
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % all = zeros(2,3,L);
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % all(1,1,:) = x11;
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % all(1,2,:) = x12;
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % all(1,3,:) = x13;
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % all(2,1,:) = x21;
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % all(2,2,:) = x22;
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % all(2,3,:) = x23;
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % n = 2^nextpow2(L);
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % dim = 3;
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % Y = fft(all,n,dim);
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % P2 = abs(Y/n);
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % P1 = P2(:,:,1:n/2+1);
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % P1(:,:,2:end-1) = 2*P1(:,:,2:end-1);
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % for i=1:2
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %     for j = 1:3
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %         disp(num2str((i-1)*3+j))
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %         subplot(3,2,(i-1)*3+j)
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %         plot(0:(Fs/n):(Fs/2-Fs/n),squeeze(P1(i,j,1:n/2)))
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %         title(['Row ',num2str(i), '  Column ',num2str(j),' in the Frequency Domain'])
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %         grid on
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %         xlabel 'Frequency (Hz)'
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %         ylabel 'Power'
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %     end
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % end



    %% This function if made for 3-dimensional F
    dim = 3;

    % Next power of 2 from length of signal
    nTime = length(time);
    % NFFT = 2^nextpow2(nTime);    % Function fft() pads the signal with zeros before computing the FT
    NFFT = nTime;                  % No zero-padding: Nfft = Ntime
    sfreq = 1 / (time(2) - time(1));
    % Positive frequency bins spanned by FFT
    Freqs = sfreq / 2 * linspace(0, 1, NFFT / 2 + 1);
    % Keep only first and last time instants
    time = time([1, end]);
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




