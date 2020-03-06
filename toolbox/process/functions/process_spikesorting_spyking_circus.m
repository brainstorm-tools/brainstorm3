function varargout = process_spikesorting_spyking_circus( varargin )
% PROCESS_SPIKESORTING_SPYKING_CIRCUS:
% This process separates the initial raw signal to nChannels binary signals
% and performs spike sorting individually on each channel with the KiloSort
% spike-sorter. The spikes are clustered and assigned to individual
% neurons. The code ultimately produces a raw_elec(i)_spikes.mat
% for each electrode that can be used later for supervised spike-sorting.
% When all spikes on all electrodes have been clustered, all the spikes for
% each neuron is assigned to an events file in brainstorm format.
%
% USAGE: OutputFiles = process_spikesorting_spyking_circus('Run', sProcess, sInputs)

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
    sProcess.Comment     = 'Spyking Circus';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Electrophysiology','Unsupervised Spike Sorting'};
    sProcess.Index       = 1204;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/e-phys/SpikeSorting';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 0;
    sProcess.options.spikesorter.Type   = 'text';
    sProcess.options.spikesorter.Value  = 'spykingCircus';
    sProcess.options.spikesorter.Hidden = 1;
    sProcess.options.binsize.Comment = 'Maximum RAM to use: ';
    sProcess.options.binsize.Type    = 'value';
    sProcess.options.binsize.Value   = {2, 'GB', 1};
    % Options: Edit parameters
    sProcess.options.edit.Comment = {'panel_spikesorting_options', '<U><B>Parameters</B></U>: '};
    sProcess.options.edit.Type    = 'editpref';
    sProcess.options.edit.Value   = [];
    % Show warning that pre-spikesorted events will be overwritten
    sProcess.options.warning.Comment = '<B><FONT color="#FF0000">Spike Events created from the acquisition system will be overwritten</FONT></B>';
    sProcess.options.warning.Type    = 'label';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    ProtocolInfo = bst_get('ProtocolInfo');

    % Not available in the compiled version
    if (exist('isdeployed', 'builtin') && isdeployed)
        error('This function is not available in the compiled version of Brainstorm.');
    end

    
    %% Compute on each raw input independently
    for i = 1:length(sInputs)
        [fPath, fBase] = bst_fileparts(sInputs(i).FileName);
        % Remove "data_0raw" or "data_" tag
        if (length(fBase) > 10 && strcmp(fBase(1:10), 'data_0raw_'))
            fBase = fBase(11:end);
        elseif (length(fBase) > 5) && strcmp(fBase(1:5), 'data_')
            fBase = fBase(6:end);
        end
        
        DataMat = in_bst_data(sInputs(i).FileName, 'F');
        ChannelMat = in_bst_channel(sInputs(i).ChannelFile);
        
        %% Make sure we perform the spike sorting on the channels that have spikes. IS THIS REALLY NECESSARY? it would just take longer

        numChannels = 0;
        for iChannel = 1:length(ChannelMat.Channel)
           if strcmp(ChannelMat.Channel(iChannel).Type,'EEG') || strcmp(ChannelMat.Channel(iChannel).Type,'SEEG')
              numChannels = numChannels + 1;               
           end
        end
        
        sFile = DataMat.F;
        events = DataMat.F.events;
        
% % % % % % % % % % % % %         %% %%%%%%%%%%%%%%%%%%% Prepare output folder %%%%%%%%%%%%%%%%%%%%%%        
% % % % % % % % % % % % %         outputPath = bst_fullfile(ProtocolInfo.STUDIES, fPath, [fBase '_kilosort_spikes']);
% % % % % % % % % % % % %         
% % % % % % % % % % % % %         % Clear if directory already exists
% % % % % % % % % % % % %         if exist(outputPath, 'dir') == 7
% % % % % % % % % % % % %             try
% % % % % % % % % % % % %                 rmdir(outputPath, 's');
% % % % % % % % % % % % %             catch
% % % % % % % % % % % % %                 error('Couldnt remove spikes folder. Make sure the current directory is not that folder.')
% % % % % % % % % % % % %             end
% % % % % % % % % % % % %         end
% % % % % % % % % % % % %         mkdir(outputPath);
        
        %% Convert the raw data to the right input for SpykingCircus
        bst_progress('start', 'SpykingCircus spike-sorting', 'Converting to SpykingCircus Input...');
        
        % Converting to int16. Using the same converter as for kilosort
        convertedRawFilename = in_spikesorting_convertforkilosort(sInputs(i), sProcess.options.binsize.Value{1} * 1e9); % This converts into int16.
        
        %%%%%%%%%%%%%%%%%%%%%%% Start the spike sorting %%%%%%%%%%%%%%%%%%%
        bst_progress('text', 'Spike-sorting...');
        
        
        %% Initialize Spyking circus Parameters 
        Fs = DataMat.F.prop.sfreq;
        
        protocol = bst_get('ProtocolInfo');
        convertedFilePath = bst_fullfile(bst_get('BrainstormTmpDir'), ...
                                        'Unsupervised_Spike_Sorting', ...
                                        protocol.Comment, ...
                                        sInputs(i).FileName);

                                    
        % Create the prameters files
        deadFile = initializeDeadFile(fBase, convertedFilePath, events);
        probeFile = initializeProbeFile(fBase, convertedFilePath, ChannelMat);
        initializeSpykingCircusParameters(fBase, probeFile, deadFile, convertedFilePath, Fs)        
        
        
        %% Now convert the rez.mat and the .xml to Neuroscope format so it can be read from Klusters
        %  Downloaded from: https://github.com/brendonw1/KilosortWrapper
        %  This creates 4 types of files x Number of montages (Groups of electrodes)
        % .clu: holds the cluster each spike belongs to
        % .fet: holds the feature values of each spike
        % .res: holds the spiketimes
        % .spk: holds the spike waveforms
        
        
        Kilosort2Neurosuite(rez)
        
        
        
        %% %%%%%%%%%%%%%%%%%%%  Create Brainstorm Events %%%%%%%%%%%%%%%%%%%
        
        bst_progress('text', 'Saving events file...');
        
        % Delete existing spike events
        process_spikesorting_supervised('DeleteSpikeEvents', sInputs(i).FileName);
        
        sFile.RawFile = sInputs(i).FileName;
        convertKilosort2BrainstormEvents(sFile, ChannelMat, bst_fullfile(ProtocolInfo.STUDIES, fPath), rez);
        
        cd(previous_directory);
        
        % Fetch FET files
        spikes = [];
        if ~iscell(Montages)
            Montages = {Montages};
        end
        for iMontage = 1:length(Montages)
            fetFile = dir(bst_fullfile(outputPath, ['*.fet.' num2str(iMontage)]));
            if isempty(fetFile)
                continue;
            end
            curStruct = struct();
            curStruct.Path = outputPath;
            curStruct.File = fetFile.name;
            curStruct.Name = Montages{iMontage};
            curStruct.Mod  = 0;
            if isempty(spikes)
                spikes = curStruct;
            else
                spikes(end+1) = curStruct;
            end
        end
        
        % ===== SAVE LINK FILE =====
        % Build output filename
        NewBstFile = bst_fullfile(ProtocolInfo.STUDIES, fPath, ['data_0ephys_' fBase '.mat']);
        % Build output structure
        DataMat = struct();
        %DataMat.F          = sFile;
        DataMat.Comment     = 'KiloSort Spike Sorting';
        DataMat.DataType    = 'raw';%'ephys';
        DataMat.Device      = 'KiloSort';
        DataMat.Parent      = outputPath;
        DataMat.Spikes      = spikes;
        DataMat.RawFile     = sInputs(i).FileName;
        DataMat.Name        = NewBstFile;
        % Add history field
        DataMat = bst_history('add', DataMat, 'import', ['Link to unsupervised electrophysiology files: ' outputPath]);
        % Save file on hard drive
        bst_save(NewBstFile, DataMat, 'v6');
        % Add file to database
        sOutputStudy = db_add_data(sInputs(i).iStudy, NewBstFile, DataMat);
        % Return new file
        OutputFiles{end+1} = NewBstFile;

        % ===== UPDATE DATABASE =====
        % Update links
        db_links('Study', sInputs(i).iStudy);
        panel_protocols('UpdateNode', 'Study', sInputs(i).iStudy);
    end
    
    %%%%%%%%%%%%%%%%%%%%%%   Prepare to exit    %%%%%%%%%%%%%%%%%%%%%%%
    % Turn off parallel processing and return to the initial directory
    if ~isempty(poolobj)
        delete(poolobj);
    end
end




function convertKilosort2BrainstormEvents(sFile, ChannelMat, parentPath, rez)

    events = struct();
    index = 0;
    
%     st: first column is the spike time in samples, 
%         second column is the spike template, 
%         third column is the extracted amplitude, 
%     and fifth column is the post auto-merge cluster (if you run the auto-merger).
    spikeTimes     = rez.st3(:,1); % spikes - TIMESTAMPS in SAMPLES
    spikeTemplates = rez.st3(:,2); % spikes - TEMPLATE THEY MATCH WITH
    uniqueClusters = unique(spikeTemplates);

    templates = zeros(length(ChannelMat.Channel), size(rez.W,1), rez.ops.Nfilt, 'single');
    for iNN = 1:rez.ops.Nfilt
        templates(:,:,iNN) = squeeze(rez.U(:,iNN,:)) * squeeze(rez.W(:,iNN,:))';
    end
    amplitude_max_channel = [];
    for i = 1:size(templates,3)
        [tmp, amplitude_max_channel(i)] = max(range(templates(:,:,i)')); %CHANNEL WHERE EACH TEMPLATE HAS THE BIGGEST AMPLITUDE
    end
    
    
    % I assign each spike on the channel that it has the highest amplitude for the template it was matched with
    amplitude_max_channel = amplitude_max_channel';
    spike2ChannelAssignment = amplitude_max_channel(spikeTemplates);
    
    spikeEventPrefix = process_spikesorting_supervised('GetSpikesEventPrefix');
    
    % Fill the events fields
    for iCluster = 1:length(unique(spikeTemplates))
        selectedSpikes = find(spikeTemplates==uniqueClusters(iCluster));
        
        index = index+1;
        
        % Write the packet to events
        if uniqueClusters(iCluster)==1 || uniqueClusters(iCluster)==0
            events(index).label       = ['Spikes Noise |' num2str(uniqueClusters(iCluster)) '|'];
        else
            events(index).label       = [spikeEventPrefix ' ' ChannelMat.Channel(amplitude_max_channel(uniqueClusters(iCluster))).Name ' |' num2str(uniqueClusters(iCluster)) '|'];
        end
        events(index).color       = rand(1,3);
        events(index).epochs      = ones(1,length(spikeTimes(selectedSpikes)));
        events(index).times       = spikeTimes(selectedSpikes)' ./ sFile.prop.sfreq; % The timestamps are in SAMPLES
        events(index).reactTimes  = [];
        events(index).select      = 1;
        events(index).channels    = cell(1, size(events(index).times, 2));
        events(index).notes       = cell(1, size(events(index).times, 2));
    end
    
    % Add existing non-spike events for backup
    DataMat = in_bst_data(sFile.RawFile);
    existingEvents = DataMat.F.events;
    for iEvent = 1:length(existingEvents)
        if ~process_spikesorting_supervised('IsSpikeEvent', existingEvents(iEvent).label)
            if index == 0
                events = existingEvents(iEvent);
            else
                events(index + 1) = existingEvents(iEvent);
            end
            index = index + 1;
        end
    end

    save(fullfile(parentPath,'events_UNSUPERVISED.mat'),'events')
end




function events = LoadKlustersEvents(SpikeSortedMat, iMontage)
    % Information about the Neuroscope file can be found here:
    % http://neurosuite.sourceforge.net/formats.html

    %% Load necessary files
    ChannelMat = in_bst_channel(bst_get('ChannelFileForStudy', SpikeSortedMat.RawFile));
    DataMat = in_bst_data(SpikeSortedMat.RawFile, 'F');
    sFile = DataMat.F;
    % Extract filename from 'filename.fet.1'
    [tmp, study] = fileparts(SpikeSortedMat.Spikes(iMontage).File);
    [tmp, study] = fileparts(study);
    sMontage = num2str(iMontage);
    clu = load(bst_fullfile(SpikeSortedMat.Parent, [study '.clu.' sMontage]));
    res = load(bst_fullfile(SpikeSortedMat.Parent, [study '.res.' sMontage]));
    fet = dlmread(bst_fullfile(SpikeSortedMat.Parent, [study '.fet.' sMontage]));


    ChannelsInMontage = ChannelMat.Channel(strcmp({ChannelMat.Channel.Group},SpikeSortedMat.Spikes(iMontage).Name)); % Only the channels from the Montage should be loaded here to be used in the spike-events
    
    
    %% The combination of the .clu files and the .fet file is enough to use on the converter.

    % Brainstorm assign each spike to a SINGLE NEURON on each electrode. This
    % converter picks up the electrode that showed the strongest (absolute)
    % component on the .fet file and assigns the spike to that electrode. Consecutively, it
    % checks the .clu file to assign the spike to a specific neuron. If more
    % than one clusters are assigned to that electrode, different labels will
    % be created for each neuron.

    iChannels = zeros(size(fet,1),1);
    for iSpike = 2:size(fet,1) % The first entry will be zeros. Ignore
        [tmp,iPCA] = max(abs(fet(iSpike,1:end-3)));
        iChannels(iSpike) = ceil(iPCA/3);
    end
    
    % Now iChannels holds the Channel that each spike belongs to, and clu
    % holds the cluster that each spike belongs to. Assign unique labels to
    % multiple neurons on the same electrode.

    % Initialize output structure
    events = struct();
    index = 0;
    
    spikesPrefix = process_spikesorting_supervised('GetSpikesEventPrefix');

    uniqueClusters = unique(clu(2:end))'; % The first entry is just the number of clusters

    for iCluster = 1:length(uniqueClusters)
        selectedSpikes = find(clu==uniqueClusters(iCluster));

        [tmp,iMaxFeature] = max(sum(abs(fet(selectedSpikes,1:end-3))));
        iElectrode = ceil(iMaxFeature/3);

        index = index+1;
        % Write the packet to events
        if uniqueClusters(iCluster)==1 || uniqueClusters(iCluster)==0
            events(index).label       = ['Spikes Noise |' num2str(uniqueClusters(iCluster)) '|'];
        else
            events(index).label       = [spikesPrefix ' ' ChannelsInMontage(iElectrode).Name ' |' num2str(uniqueClusters(iCluster)) '|'];
        end
        events(index).color       = rand(1,3);
        events(index).times       = fet(selectedSpikes,end)' ./ sFile.prop.sfreq;  % The timestamps are in SAMPLES
        events(index).epochs      = ones(1,length(events(index).times));
        events(index).reactTimes  = [];
        events(index).select      = 1;
        events(index).channels    = cell(1, size(events(index).times, 2));
        events(index).notes       = cell(1, size(events(index).times, 2));
    end
end

function CreateSpikingCircusParametersFile(outputFile)
    if exist(outputFile, 'file') == 2
        delete(outputFile);
    end

    outFid = fopen(outputFile, 'w');
    
    
    
    fclose(inFid);
    fclose(outFid);
end
