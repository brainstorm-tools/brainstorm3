function varargout = process_spiking_phase_locking( varargin )
% PROCESS_SPIKING_PHASE_LOCKING: Computes the phase locking of spikes on the timeseries.

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
% Authors: Konstantinos Nasiotis, 2020
%          Francois Tadel, 2022

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Spiking phase locking';
    sProcess.FileTag     = 'phaseLocking';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Electrophysiology';
    sProcess.Index       = 1235;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/e-phys/functions#Spiking_phase_locking_values';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Options: Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types, indices, names or groups (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'EEG';
    % Band-pass filter
    sProcess.options.bandpass.Comment = 'Frequency band (0=ignore): ';
    sProcess.options.bandpass.Type    = 'range';
    sProcess.options.bandpass.Value   = {[600, 800], 'Hz', 1};
    % Phase Binning
    sProcess.options.phaseBin.Comment = 'Phase binning: ';
    sProcess.options.phaseBin.Type    = 'value';
    sProcess.options.phaseBin.Value   = {30, 'degrees', 0};
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
    SensorTypes = sProcess.options.sensortypes.Value;
    BandPass = sProcess.options.bandpass.Value{1};
    PhaseBin = sProcess.options.phaseBin.Value{1};
    % Check if the signal processing toolbox is available
    if bst_get('UseSigProcToolbox')
        hilbert_fcn = @hilbert;
    else
        hilbert_fcn = @oc_hilbert;
    end

    % ===== PROCESS FILES =====
    % Check how many event groups we're processing
    listComments = cellfun(@str_remove_parenth, {sInputs.Comment}, 'UniformOutput', 0);
    [uniqueComments,tmp,iData2List] = unique(listComments);
    nLists = length(uniqueComments);
    % Process each event group seperately
    for iList = 1:nLists
        bst_progress('text', ['Detecting unique neurons on all "' uniqueComments{iList} '" trials...']);

        % === LOAD INPUTS ===
        % Get trials in this group
        sCurrentInputs = sInputs(iData2List == iList);
        nTrials = length(sCurrentInputs);

        % Loads all the data
        ChannelFlag = [];
        neuronLabels = {}; 
        for iFile = 1:length(sInputs)
            % Load file
            DataEvt = in_bst_data(sInputs(iFile).FileName, 'Events', 'ChannelFlag');
            % Accumulate bad channels: good channels must be good for all the input files
            if isempty(ChannelFlag)
                ChannelFlag = DataEvt.ChannelFlag;
            else
                ChannelFlag(DataEvt.ChannelFlag == -1) = -1;
            end
            % Find neuron events
            for iEvent = 1:length(DataEvt.Events)
                if panel_spikes('IsSpikeEvent', DataEvt.Events(iEvent).label)
                    neuronLabels{end+1} = DataEvt.Events(iEvent).label;
                end
            end
        end
        % If no neuron was found
        if isempty(neuronLabels)
            bst_report('Error', sProcess, sCurrentInputs(1), 'No neurons/spiking events detected.');
            return;
        end
        % Sort neurons alphabetically
        neuronLabels = unique(neuronLabels, 'stable');
        neuronLabels = sort_nat(neuronLabels);

        % Load channel file (from the first file in the list)
        ChannelMat = in_bst_channel(sCurrentInputs(1).ChannelFile);
        % Select good channels
        iSelectedChannels = select_channels(ChannelMat, ChannelFlag, SensorTypes);
        nChannels = length(iSelectedChannels); 
        if isempty(iSelectedChannels)
            bst_report('Error', sProcess, sCurrentInputs(1), 'No channels to process. Make sure that the Names/Groups assigned are correct');
            return;
        end
        
        % Now get the labels for the Dropdown - this is to show the spiking
        % firing rate from each neuron based on the oscillations on each
        % selected electrode.
        labelsForDropDownMenu = cell(length(neuronLabels)*nChannels,1);
        for iNeuron = 1:length(neuronLabels)
            for iChannel = 1:nChannels
                labelsForDropDownMenu{(iNeuron-1)*nChannels + iChannel} = ['Neuron ' erase(neuronLabels{iNeuron},'Spikes Channel ') ' - Ch ' ChannelMat.Channel(iSelectedChannels(iChannel)).Name];
            end
        end
        
        %% ===== COMPUTE PHASES =====
        bst_progress('text', 'Accumulating spiking phases for each neuron...');
        % Accumulate the phases that each neuron fired upon
        nBins = round(360/PhaseBin) + 1;
        all_phases = zeros(length(labelsForDropDownMenu), nBins-1);
        total_spikes = zeros(length(labelsForDropDownMenu), 1);
        EDGES = linspace(-pi,pi,nBins);
        centerOfBins = EDGES(1:end-1) + (pi/180*PhaseBin)/2;
        
        for iFile = 1:nTrials
            % Load data file
            DataMat = in_bst_data(sCurrentInputs(iFile).FileName);
            events = DataMat.Events;
            if isempty(events)
                continue;
            end

            % Filter the data based on the user input
            sFreq = round(1/diff(DataMat.Time(1:2)));
            filtered_F = process_bandpass('Compute', DataMat.F(iSelectedChannels,:), sFreq, BandPass(1), BandPass(2));
            % Compute the phase
            angle_filtered_F = zeros(size(filtered_F));
            for iChannel = 1:size(filtered_F,1)
                angle_filtered_F(iChannel,:) = angle(transpose(hilbert_fcn(transpose(filtered_F(iChannel,:)))));
            end

            for iNeuron = 1:length(neuronLabels)
                iEvent_Neuron = find(ismember({events.label},neuronLabels{iNeuron}));

                if ~isempty(iEvent_Neuron)
                    
                    % Make sure the spike is not at the edge of the
                    % time window of the trial (This causes problems during the binning)
                    events(iEvent_Neuron).times = events(iEvent_Neuron).times(events(iEvent_Neuron).times>DataMat.Time(1) & ...
                                                                              events(iEvent_Neuron).times<DataMat.Time(end));
                    
                    total_spikes(iNeuron) = total_spikes(iNeuron) + length(events(iEvent_Neuron).times);

                    % Get the index of the closest timeBin
                    [temp, iClosest] = histc(events(iEvent_Neuron).times,DataMat.Time);
                    
                    % ===============================================================     
                    % % TEST TO CHECK THAT THE CODE WORKS
                    % iClosest = angle_filtered_F(1,:)<0 & angle_filtered_F(1,:)>-pi/6;
                    % figure(1);
                    % plot(DataMat.Time, angle_filtered_F(1,:))
                    % hold on
                    % plot(DataMat.Time(iClosest), angle_filtered_F(1,iClosest),'*')
                    % ===============================================================                       

                    % Function hist fails to give correct output when a single spike occurs. Taking care of it here
                    if length(iClosest) == 1
                        single_spike_entry = zeros(nChannels, nBins-1);
                        for iChannel = 1:nChannels
                            [temp,edges] = histcounts(angle_filtered_F(iChannel,iClosest),EDGES);
                            iBin = find(temp);
                            single_spike_entry(iChannel, iBin) = 1;
                        end
                        all_phases((iNeuron-1)*nChannels+1:iNeuron*nChannels,:) = all_phases((iNeuron-1)*nChannels+1:iNeuron*nChannels,:) + single_spike_entry;
                    else
                        [all_phases_single_neuron,edges] = histcounts(angle_filtered_F(:,iClosest)',EDGES);
                        
                        if size(all_phases_single_neuron, 1) ~= 1 % If a vector then transpose to 
                            all_phases_single_neuron = all_phases_single_neuron';
                        end
                        all_phases((iNeuron-1)*nChannels+1:iNeuron*nChannels,:) = all_phases((iNeuron-1)*nChannels+1:iNeuron*nChannels,:) + all_phases_single_neuron;
                    end                      
                end
            end
        end
        
        % Compute the p-values for both Rayleigh and Omnibus tests
        pValues = struct;
        preferredPhase = zeros(size(all_phases,1),1);
        for iNeuron = 1:size(all_phases,1)
            bins_with_values = all_phases(iNeuron,:)~=0;
            [pValues(iNeuron).Rayleigh, z] = circ_rtest(EDGES(bins_with_values), all_phases(iNeuron,bins_with_values));
            [pValues(iNeuron).OmniBus, m]  = circ_otest(EDGES(bins_with_values), all_phases(iNeuron,bins_with_values));
            
            % Get the preferred Phase
            w = all_phases(iNeuron,:);
            single_neuron_phase = [];
            for iBin = 1:size(all_phases,2)
                single_neuron_phase = [single_neuron_phase; ones(w(iBin),1) * EDGES(iBin)];
            end
            mean_value = circ_mean(single_neuron_phase);
            preferredPhase(iNeuron) = mean_value * (180/pi);
        end

        % Change the dimensions to make it compatible with Brainstorm TF
        all_phases = permute(all_phases, [1,3,2]);
        

        % ===== SAVE FILE =====
        % Prepare output file structure
        TfMat = db_template('timefreqmat');
        TfMat.TF       = all_phases;
        TfMat.Comment  = ['Phase Locking: ' uniqueComments{iList} ' | band (' num2str(BandPass(1)) ',' num2str(BandPass(2)) ')Hz'];
        TfMat.DataType = 'data';
        TfMat.Time     = 1;
        TfMat.Freqs    = centerOfBins;
        TfMat.RowNames = labelsForDropDownMenu;
        TfMat.Measure  = 'power';
        TfMat.Method   = 'morlet';
        TfMat.DataFile = []; % Leave blank because multiple parents
        TfMat.Options  = [];
        % Save phases
        TfMat.neurons.phase.pValues = pValues;
        TfMat.neurons.phase.preferredPhase = preferredPhase;
        TfMat.neurons.phase.total_spikes = total_spikes;

        % Add history field
        TfMat = bst_history('add', TfMat, 'compute', 'Spiking phase locking per neuron');

        % Get output study
        [tmp, iTargetStudy] = bst_process('GetOutputStudy', sProcess, sInputs);
        sTargetStudy = bst_get('Study', iTargetStudy);
        % Output filename
        FileName = bst_process('GetNewFilename', bst_fileparts(sTargetStudy.FileName), 'timefreq_spiking_phase_locking');
        OutputFiles = {FileName};
        % Save output file and add to database
        bst_save(FileName, TfMat, 'v6');
        db_add_data(iTargetStudy, FileName, TfMat);
    end
end



%% ===== SELECT CHANNELS =====
function iChannels = select_channels(ChannelMat, ChannelFlag, target)
    % Get channels to process
    iChannels = channel_find(ChannelMat.Channel, target);
    % Check for Group selection
    if ~iscell(target)
        if any(target == ',') || any(target == ';')
            % Split string based on the commas
            target = strtrim(str_split(target, ',;'));
        else
            target = {strtrim(target)};
        end
    end    
    
    % Select which channels to compute the spiking phase on
    if isempty(iChannels)
        if ~all(cellfun(@isempty,{ChannelMat.Channel.Group})) % In case not all groups are empty
            allGroups = upper(unique({ChannelMat.Channel.Group}));
            % Process all the targets
            for i = 1:length(target)
                % Search by type: return all the channels from this Group
                if ismember(upper(strtrim(target{i})), allGroups)
                    iChan = [];
                    for iChannel = 1:length(ChannelMat.Channel)
                        % Get only good channels
                        if strcmp(upper(strtrim(target{i})), upper(strtrim(ChannelMat.Channel(iChannel).Group))) && ChannelFlag(iChannel) == 1
                            iChan = [iChan, iChannel];
                        end
                    end                             
                end
                % Comment
                if ~isempty(iChan)
                    iChannels = [iChannels, iChan];
                else
                    bst_error('No channels were selected. Make sure that the Group name is spelled properly. Also make sure that not ALL channels in that bank are marked as BAD')
                end
            end
            % Sort channels indices, and remove duplicates
            iChannels = unique(iChannels);
        else
            iChannels = [];
        end
    end
end
