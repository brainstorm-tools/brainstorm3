function varargout = process_spiking_phase_locking( varargin )
% PROCESS_SPIKING_PHASE_LOCKING: Computes the phase locking of spikes on
% the timeseries.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Spiking Phase Locking';
    sProcess.FileTag     = 'phaseLocking';
    sProcess.Category    = 'custom';
    sProcess.SubGroup    = {'Peyrache Lab', 'Ripples'};
    sProcess.Index       = 2223;
    sProcess.Description = 'https://www.jstatsoft.org/article/view/v031i10';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Options: Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types, indices, names or Groups (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'EEG';
    % Save ERP
    sProcess.options.median.Comment = 'Compute phase of median LFP of the selected channels';
    sProcess.options.median.Type    = 'checkbox';
    sProcess.options.median.Value   = 0;
    % === Legacy
    sProcess.options.label.Comment = '<FONT color="#999999">If selected the median of the selected channels will be used as input</FONT>';
    sProcess.options.label.Type    = 'label';
    % Band-pass filter
    sProcess.options.bandpass.Comment = 'Frequency band (0=ignore): ';
    sProcess.options.bandpass.Type    = 'range';
    sProcess.options.bandpass.Value   = {[600, 800], 'Hz', 1};
    % Phase Binning
    sProcess.options.phaseBin.Comment = 'Phase Binning: ';
    sProcess.options.phaseBin.Type    = 'value';
    sProcess.options.phaseBin.Value   = {30, 'degrees', 0};
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
    
    % Bin size
    if isfield(sProcess.options, 'phaseBin') && ~isempty(sProcess.options.phaseBin) && ~isempty(sProcess.options.phaseBin.Value) && iscell(sProcess.options.phaseBin.Value) && sProcess.options.phaseBin.Value{1} > 0
        bin_size = sProcess.options.phaseBin.Value{1};
    else
        bst_report('Error', sProcess, sInputs, 'Positive phase bin size required.');
        return;
    end
    
    use_median = sProcess.options.median.Value;

    % === OUTPUT STUDY ===
    % Get output study
    [tmp, iStudy] = bst_process('GetOutputStudy', sProcess, sInputs);
    tfOPTIONS.iTargetStudy = iStudy;
    
    % Check how many event groups we're processing
    listComments = cellfun(@str_remove_parenth, {sInputs.Comment}, 'UniformOutput', 0);
    [uniqueComments,tmp,iData2List] = unique(listComments);
    nLists = length(uniqueComments);
    
    % Process each event group seperately
    for iList = 1:nLists
        sCurrentInputs = sInputs(iData2List == iList);
    
        %% Get channel file
        sChannel    = bst_get('ChannelForStudy', iStudy);
        ChannelMat  = in_bst_channel(sChannel.FileName);
        dataMat_channelFlag = in_bst_data(sCurrentInputs(1).FileName, 'ChannelFlag');

        iSelectedChannels = select_channels(ChannelMat, dataMat_channelFlag.ChannelFlag, sProcess.options.sensortypes.Value);
        nChannels = length(iSelectedChannels); 
        
        % No need for median if only one channel was selected
        if nChannels == 1
            use_median = 0;
        end
        
        if isempty(iSelectedChannels)
            bst_report('Error', sProcess, sCurrentInputs(1), 'No channels to process. Make sure that the Names/Groups assigned are correct');
            return;
        end

        %% Get only the unique neurons along all of the trials
        progressPos = bst_progress('get');
        bst_progress('text', ['Detecting unique neurons on all "' uniqueComments{iList} '" trials...']);

        nTrials = length(sCurrentInputs);

        % I get the files outside of the parfor so it won't fail.
        % This loads the information from ALL TRIALS on ALL_TRIALS_files
        % (Shouldn't create a memory problem).
        ALL_TRIALS_files = struct();
        for iFile = 1:nTrials
            DataMat = in_bst(sCurrentInputs(iFile).FileName);
            ALL_TRIALS_files(iFile).Events = DataMat.Events;
            progressPos = bst_progress('set', iFile/nTrials*100);
        end

        % ADD AN IF STATEMENT HERE TO GENERALIZE ON ALL EVENTS, NOT JUST SPIKES
        % THE FUNCTION SHOULD BE MODIFIED TO ENABLE INPUT OF THE EVENTS FROM
        % THE USER

        % Create a cell that holds all of the labels and one for the unique labels
        % This will be used to take the averages using the appropriate indices
        neuronLabels = {}; % Unique neuron labels (each trial might have different number of neurons). We need everything that appears.
        for iFile = 1:nTrials
            for iEvent = 1:length(ALL_TRIALS_files(iFile).Events)
                if process_spikesorting_supervised('IsSpikeEvent', ALL_TRIALS_files(iFile).Events(iEvent).label)
                    neuronLabels{end+1} = ALL_TRIALS_files(iFile).Events(iEvent).label;
                end
            end
        end
        
        if isempty(neuronLabels)
            bst_report('Error', sProcess, sCurrentInputs(1), 'No neurons/spiking events detected.');
            return;
        end 
        
        neuronLabels = unique(neuronLabels,'stable');
        neuronLabels = sort_nat(neuronLabels);
        
        % Now get the labels for the Dropdown - this is to show the spiking
        % firing rate from each neuron based on the oscillations on each
        % selected electrode.
        
        
        if use_median
            suffix = ChannelMat.Channel(iSelectedChannels(1)).Name;
            labelsForDropDownMenu = cell(length(neuronLabels),1);
            all_selected_channels_labels = {ChannelMat.Channel(iSelectedChannels).Name}';
            for iChannel = 2:length(all_selected_channels_labels)
                suffix = [suffix ' ' all_selected_channels_labels{iChannel}];
            end
            for iNeuron = 1:length(neuronLabels)
                labelsForDropDownMenu{iNeuron} = ['Neuron ' erase(neuronLabels{iNeuron},'Spikes Channel ') ' - Ch Median [' suffix ']'];
            end
        else
            labelsForDropDownMenu = cell(length(neuronLabels)*nChannels,1);
            for iNeuron = 1:length(neuronLabels)
                for iChannel = 1:nChannels
                    labelsForDropDownMenu{(iNeuron-1)*nChannels + iChannel} = ['Neuron ' erase(neuronLabels{iNeuron},'Spikes Channel ') ' - Ch ' ChannelMat.Channel(iSelectedChannels(iChannel)).Name];
                end
            end
        end
                
        %% Accumulate the phases that each neuron fired upon
        nBins = round(360/sProcess.options.phaseBin.Value{1});
        all_phases = zeros(length(labelsForDropDownMenu), nBins);

        [temp, EDGES] = histcounts(-pi:0.01:pi, nBins-1);

        progressPos = bst_progress('set',0);
        bst_progress('text', 'Accumulating spiking phases for each neuron...');
        for iFile = 1:nTrials

            % Collect required fields
            DataMat = in_bst(sCurrentInputs(iFile).FileName);
            events = DataMat.Events;

            if ~isempty(events)
                %% Filter the data based on the user input
                sFreq = round(1/diff(DataMat.Time(1:2)));
                [filtered_F, FiltSpec, Messages] = process_bandpass('Compute', DataMat.F(iSelectedChannels,:), sFreq, sProcess.options.bandpass.Value{1}(1), sProcess.options.bandpass.Value{1}(2));

                %Extract phase
                if use_median
                    angle_filtered_F = angle(hilbert(median(filtered_F)));
                    nChannels = 1;
                else 
                    angle_filtered_F = angle(hilbert(filtered_F));
                end


                for iNeuron = 1:length(neuronLabels)
                    iEvent_Neuron = find(ismember({events.label},neuronLabels{iNeuron}));

                    if ~isempty(iEvent_Neuron)
                        % Get the index of the closest timeBin
                        [temp, iClosest] = histc(events(iEvent_Neuron).times,DataMat.Time);

                        % Function hist fails to give correct output when a single
                        % spike occurs. Taking care of it here
                        if length(iClosest) == 1
                            single_spike_entry = zeros(nChannels, nBins);
                            [temp, iBin] = histc(angle_filtered_F(:,iClosest), EDGES); 
                            for iChannel = 1:nChannels
                                single_spike_entry(iChannel, iBin(iChannel)) = 1;
                            end
                            all_phases((iNeuron-1)*nChannels+1:iNeuron*nChannels,:) = all_phases((iNeuron-1)*nChannels+1:iNeuron*nChannels,:) + single_spike_entry;
                        else
                            [all_phases_single_neuron, bins] = hist(angle_filtered_F(:,iClosest)', EDGES);
                            if size(all_phases_single_neuron, 1) ~= 1 % If a vector then transpose to 
                                all_phases_single_neuron = all_phases_single_neuron';
                            end
                            all_phases((iNeuron-1)*nChannels+1:iNeuron*nChannels,:) = all_phases((iNeuron-1)*nChannels+1:iNeuron*nChannels,:) + all_phases_single_neuron;
                        end
                    end
                end
            end
            bst_progress('set', round(iFile / nTrials * 100));
        end
        
        % Change the dimensions to make it compatible with Brainstorm TF
        all_phases = permute(all_phases, [1,3,2]);
        
        %% Compute the p-values for both Rayleigh and Omnibus tests
        pValues = struct;
        
        for iDistribution = 1:length(all_phases)
            bins_with_values = all_phases(iDistribution,:)~=0;
            [pValues(iDistribution).Rayleigh, z] = circ_rtest(EDGES(bins_with_values), all_phases(iDistribution,bins_with_values));
            [pValues(iDistribution).OmniBus, m]  = circ_otest(EDGES(bins_with_values), all_phases(iDistribution,bins_with_values));
        end
        
        %%
        % Instead of the edges, keep only the mid-point of the bins
%         bins = EDGES(1:end-1) + diff(EDGES)/2;

        % Plots
%         %% This is what the final call to the phases should print
%         iNeuron = 1;
%         iChannel = 1;
%         
%         w = squeeze(all_phases(iNeuron, iChannel, :));
%         
%         single_neuron_and_channel_phase = [];
%         for iBin = 1:nBins
%             single_neuron_and_channel_phase = [single_neuron_and_channel_phase ;ones(w(iBin),1)*EDGES(iBin)];
%         end
%             
%         [pval_rayleigh z] = circ_rtest(single_neuron_and_channel_phase);
%         [pval_omnibus m] = circ_otest(single_neuron_and_channel_phase);
%         [mean_value, upper_limit, lower_limit] = circ_mean(single_neuron_and_channel_phase);
%         mean_value_degrees = mean_value * (180/pi);
%         
%     %     figure(1); polarhistogram(single_neuron_and_channel_phase, nBins,'FaceColor','blue','FaceAlpha',.3, 'Normalization','probability');
%     % %     figure(1); polarhistogram(single_neuron_and_channel_phase,12,'FaceColor','red','FaceAlpha',.3);
%     %     pax = gca;
%     %     pax.ThetaAxisUnits = 'radians';
%     %     title({['Rayleigh test p=' num2str(pval_rayleigh)], ['Omnibus test p=' num2str(pval_omnibus)], ['Preferred phase: ' num2str(mean_value_degrees) '^o']})
%     % %     rlim([0 1])
%     
%         figure(2);
%         circ_plot(single_neuron_and_channel_phase,'hist',[], nBins,true,true,'linewidth',2,'color','r');
%         pax = gca;
%         title({['Rayleigh test p=' num2str(pval_rayleigh)], ['Omnibus test p=' num2str(pval_omnibus)], ['Preferred phase: ' num2str(mean_value_degrees) '^o']})

        %% Build the output file
        tfOPTIONS.ParentFiles = {sCurrentInputs.FileName};

        % Prepare output file structure
        FileMat.TF = all_phases;
        FileMat.TFmask = true(size(all_phases, 2), size(all_phases, 3));
        FileMat.Std = [];
        if use_median
            FileMat.Comment = ['Phase Locking: ' uniqueComments{iList} ' | band (' num2str(sProcess.options.bandpass.Value{1}(1)) ',' num2str(sProcess.options.bandpass.Value{1}(2)) ')Hz | median'];
        else
            FileMat.Comment = ['Phase Locking: ' uniqueComments{iList} ' | band (' num2str(sProcess.options.bandpass.Value{1}(1)) ',' num2str(sProcess.options.bandpass.Value{1}(2)) ')Hz'];
        end
        FileMat.DataType = 'data';
        FileMat.Time = 1;
        FileMat.TimeBands = [];
        FileMat.Freqs = EDGES;
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
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % This is added here - Let's hear it from Francois
        FileMat.pValues = pValues;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


        % Add history field
        FileMat = bst_history('add', FileMat, 'compute', ...
            ['Spiking phase locking per neuron']);

        % Get output study
        sTargetStudy = bst_get('Study', iStudy);
        % Output filename
        FileName = bst_process('GetNewFilename', bst_fileparts(sTargetStudy.FileName), 'timefreq_spiking_phase_locking');
        OutputFiles = {FileName};
        % Save output file and add to database
        bst_save(FileName, FileMat, 'v6');
        db_add_data(tfOPTIONS.iTargetStudy, FileName, FileMat);

    end
    % Display report to user
    bst_report('Info', sProcess, sInputs, 'Success');
    disp('BST> process_spiking_phase_locking: Success');
end


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
    
    %% Select which channels to compute the spiking phase on
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
