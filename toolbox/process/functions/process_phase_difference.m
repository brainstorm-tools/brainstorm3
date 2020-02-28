function varargout = process_phase_difference( varargin )
% PROCESS_PHASE_DIFFERENCE: Computes the phase difference histogram between
% timeseries

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
    sProcess.Comment     = 'Phase Difference';
    sProcess.FileTag     = 'phaseLocking';
    sProcess.Category    = 'custom';
    sProcess.SubGroup    = {'Peyrache Lab', 'Ripples'};
    sProcess.Index       = 2224;
    sProcess.Description = 'https://www.jstatsoft.org/article/view/v031i10';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Options: Sensor types
    sProcess.options.sensortypesA.Comment = 'A: Sensor types, indices, names or Groups (empty=all): ';
    sProcess.options.sensortypesA.Type    = 'text';
    sProcess.options.sensortypesA.Value   = 'EEG';
    % Save ERP
    sProcess.options.medianA.Comment = 'Compute phase of median LFP of the selected channels';
    sProcess.options.medianA.Type    = 'checkbox';
    sProcess.options.medianA.Value   = 0;
    % Options: Sensor types
    sProcess.options.sensortypesB.Comment = 'B: Sensor types, indices, names or Groups (empty=all): ';
    sProcess.options.sensortypesB.Type    = 'text';
    sProcess.options.sensortypesB.Value   = 'EEG';
    % Save ERP
    sProcess.options.medianB.Comment = 'Compute phase of median LFP of the selected channels';
    sProcess.options.medianB.Type    = 'checkbox';
    sProcess.options.medianB.Value   = 0;
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
    if isfield(sProcess.options, 'sensortypesA')
        tfOPTIONS.SensorTypesA = sProcess.options.sensortypesA.Value;
    else
        tfOPTIONS.SensorTypesA = [];
    end
    % Add other options
    if isfield(sProcess.options, 'sensortypesB')
        tfOPTIONS.SensorTypesB = sProcess.options.sensortypesB.Value;
    else
        tfOPTIONS.SensorTypesB = [];
    end
    
    % Bin size
    if isfield(sProcess.options, 'phaseBin') && ~isempty(sProcess.options.phaseBin) && ~isempty(sProcess.options.phaseBin.Value) && iscell(sProcess.options.phaseBin.Value) && sProcess.options.phaseBin.Value{1} > 0
        bin_size = sProcess.options.phaseBin.Value{1};
    else
        bst_report('Error', sProcess, sInputs, 'Positive phase bin size required.');
        return;
    end
    
    use_medianA = sProcess.options.medianA.Value;
    use_medianB = sProcess.options.medianB.Value;

    % === OUTPUT STUDY ===
    % Get output study
    [tmp, iStudy] = bst_process('GetOutputStudy', sProcess, sInputs);
    tfOPTIONS.iTargetStudy = iStudy;
    
    % Check how many event groups we're processing
    listComments = cellfun(@str_remove_parenth, {sInputs.Comment}, 'UniformOutput', 0);
    [uniqueComments,tmp,iData2List] = unique(listComments);
    nLists = length(uniqueComments);
    
    % Process each event group separately
    for iList = 1:nLists
        sCurrentInputs = sInputs(iData2List == iList);
    
        %% Get channel file
        sChannel    = bst_get('ChannelForStudy', iStudy);
        ChannelMat  = in_bst_channel(sChannel.FileName);
        dataMat_channelFlag = in_bst_data(sCurrentInputs(1).FileName, 'ChannelFlag');

        iSelectedChannelsA = select_channels(ChannelMat, dataMat_channelFlag.ChannelFlag, sProcess.options.sensortypesA.Value);
        nChannelsA = length(iSelectedChannelsA); 
                
        
        % No need for median if only one channel was selected
        if nChannelsA == 1
            use_medianA = 0;
        end
        
        if isempty(iSelectedChannelsA)
            bst_report('Error', sProcess, sCurrentInputs(1), 'No channels to process in group A. Make sure that the Names/Groups assigned are correct');
            return;
        end
        
        % Do the same for ChannelSelection B
        iSelectedChannelsB = select_channels(ChannelMat, dataMat_channelFlag.ChannelFlag, sProcess.options.sensortypesB.Value);
        nChannelsB = length(iSelectedChannelsB); 
        
        % No need for median if only one channel was selected
        if nChannelsB == 1
            use_medianB = 0;
        end
        
        if isempty(iSelectedChannelsB)
            bst_report('Error', sProcess, sCurrentInputs(1), 'No channels to process in group B. Make sure that the Names/Groups assigned are correct');
            return;
        end
        
        if use_medianA
            nChannelsA = 1;
        end
        if use_medianB
            nChannelsB = 1;
        end
        
        
        %% Create the label of the file on the database based on the selection
        labelsForDropDownMenu = cell(nChannelsA * nChannelsB, 1);
        
        for iChannelA = 1:nChannelsA
            for iChannelB = 1:nChannelsB
        
                if use_medianA
                    suffixA = ['Ch: median [' ChannelMat.Channel(iSelectedChannelsA(1)).Name];
                    all_selected_channels_labelsA = {ChannelMat.Channel(iSelectedChannelsA).Name}';
                    for iChannel = 2:length(all_selected_channels_labelsA)
                        suffixA = [suffixA ' ' all_selected_channels_labelsA{iChannel}];
                    end
                    suffixA = [suffixA ']'];
                else
                    suffixA = ['Ch: ' ChannelMat.Channel(iSelectedChannelsA(iChannelA)).Name];
                end

                if use_medianB
                    suffixB = [' - median [' ChannelMat.Channel(iSelectedChannelsB(1)).Name];
                    all_selected_channels_labelsB = {ChannelMat.Channel(iSelectedChannelsB).Name}';
                    for iChannel = 2:length(all_selected_channels_labelsB)
                        suffixB = [suffixB ' ' all_selected_channels_labelsB{iChannel}];
                    end
                    suffixB = [suffixB ']'];
                else
                    suffixB = [' - ' ChannelMat.Channel(iSelectedChannelsB(iChannelB)).Name];
                end

                labelsForDropDownMenu{(iChannelA-1)*nChannelsB+ iChannelB} = [suffixA suffixB];
            end
        end
  
        %% Accumulate the phases that each neuron fired upon
        nBins = round(360/sProcess.options.phaseBin.Value{1});
        all_phases = zeros(length(labelsForDropDownMenu), nBins+1);

        EDGES = linspace(-pi, pi, nBins+1);

        progressPos = bst_progress('set',0);
        bst_progress('text', 'Accumulating phase differences for each trial...');
        
        nTrials = length(sCurrentInputs);
        for iFile = 1:nTrials

            % Collect required fields
            DataMat = in_bst(sCurrentInputs(iFile).FileName);

            %% Filter the data based on the user input
            sFreq = round(1/diff(DataMat.Time(1:2)));
            [filtered_F_A, FiltSpec, Messages] = process_bandpass('Compute', DataMat.F(iSelectedChannelsA,:), sFreq, sProcess.options.bandpass.Value{1}(1), sProcess.options.bandpass.Value{1}(2));
            [filtered_F_B, FiltSpec, Messages] = process_bandpass('Compute', DataMat.F(iSelectedChannelsB,:), sFreq, sProcess.options.bandpass.Value{1}(1), sProcess.options.bandpass.Value{1}(2));

            %Extract phase
            if use_medianA
            	angle_filtered_F_A = angle(hilbert(median(filtered_F_A)));
            else 
                angle_filtered_F_A = angle(hilbert(filtered_F_A));
            end
            %Extract phase
            if use_medianB
            	angle_filtered_F_B = angle(hilbert(median(filtered_F_B)));
            else 
                angle_filtered_F_B = angle(hilbert(filtered_F_B));
            end

            ii = 0;
            for iChannelA = 1:nChannelsA
                for iChannelB = 1:nChannelsB
                    ii = ii + 1;
                    ph = abs(angle_filtered_F_A(iChannelA,:) - angle_filtered_F_B(iChannelB,:));
                    ph(ph>pi) = 2*pi-ph(ph>pi);
                    [nBinOccurences, iBin] = histc(ph, EDGES); 
                    
                    all_phases(ii,:) = all_phases(ii,:) + nBinOccurences;
                end
            end
            bst_progress('set', round(iFile / nTrials * 100));
        end
        
        % Change the dimensions to make it compatible with Brainstorm TF
        all_phases = permute(all_phases, [1,3,2]);
        
        %% Compute the p-values for both Rayleigh and Omnibus tests
        pValues = struct;
        
        for iDistribution = 1:size(all_phases,1)
            bins_with_values = all_phases(iDistribution,:)~=0;
            [pValues(iDistribution).Rayleigh, z] = circ_rtest(EDGES(bins_with_values), all_phases(iDistribution,bins_with_values));
            [pValues(iDistribution).OmniBus, m]  = circ_otest(EDGES(bins_with_values), all_phases(iDistribution,bins_with_values));
        end
        
%%         %%
% %         Instead of the edges, keep only the mid-point of the bins
% %         bins = EDGES(1:end-1) + diff(EDGES)/2;
% 
%         %%Plots
%         % This is what the final call to the phases should print
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
        FileMat.Comment = ['Phase Locking difference: ' uniqueComments{iList} ' | band (' num2str(sProcess.options.bandpass.Value{1}(1)) ',' num2str(sProcess.options.bandpass.Value{1}(2)) ')Hz'];
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
