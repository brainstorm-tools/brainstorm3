function varargout = process_spikesorting_kilosort( varargin )
% PROCESS_SPIKESORTING_KILOSORT:
% This process separates the initial raw signal to nChannels binary signals
% and performs spike sorting individually on each channel with the KiloSort
% spike-sorter. The spikes are clustered and assigned to individual
% neurons. The code ultimately produces a raw_elec(i)_spikes.mat
% for each electrode that can be used later for supervised spike-sorting.
% When all spikes on all electrodes have been clustered, all the spikes for
% each neuron is assigned to an events file in brainstorm format.

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
% Authors: Konstantinos Nasiotis, 2018-2022
%          Martin Cousineau, 2018
%          Francois Tadel, 2022

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'KiloSort';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = {'Electrophysiology','Unsupervised Spike Sorting'};
    sProcess.Index       = 1203;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/e-phys/SpikeSorting';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 0;
    % Spike sorter name
    sProcess.options.spikesorter.Type   = 'text';
    sProcess.options.spikesorter.Value  = 'kilosort';
    sProcess.options.spikesorter.Hidden = 1;
    % RAM limitation
    sProcess.options.binsize.Comment = 'Maximum RAM to use: ';
    sProcess.options.binsize.Type    = 'value';
    sProcess.options.binsize.Value   = {2, 'GB', 1};
    % GPU
    sProcess.options.GPU.Comment = 'GPU processing';
    sProcess.options.GPU.Type    = 'checkbox';
    sProcess.options.GPU.Value   = 0;
    % Use SSP/ICA
    sProcess.options.usessp.Comment = 'Apply the existing SSP/ICA projectors';
    sProcess.options.usessp.Type    = 'checkbox';
    sProcess.options.usessp.Value   = 1;
    % Separator
    sProcess.options.sep1.Type = 'label';
    sProcess.options.sep1.Comment = '<BR>';
    % Options: Edit parameters
    sProcess.options.edit.Comment = {'panel_spikesorting_options', 'KiloSort parameters: '};
    sProcess.options.edit.Type    = 'editpref';
    sProcess.options.edit.Value   = [];
    % Label: Reset options
    sProcess.options.edit_help.Comment = '<I><FONT color="#777777">To restore default options: re-install the kilosort plugin.</FONT></I>';
    sProcess.options.edit_help.Type    = 'label';
    % Label: Warning that pre-spikesorted events will be overwritten
    sProcess.options.warning.Comment = '<BR><B><FONT color="#FF0000">Warning: Existing spike events will be overwritten</FONT></B>';
    sProcess.options.warning.Type    = 'label';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput)
    OutputFiles = {};

    % ===== DEPENDENCIES =====
    % Not available in the compiled version
    if bst_iscompiled()
        error('This function is not available in the compiled version of Brainstorm.');
    end
    % Check for the Signal Processing toolbox
    if ~bst_get('UseSigProcToolbox')
        bst_report('Error', sProcess, sInput, 'This process requires the Signal Processing Toolbox.');
        return;
    end
    % Check for the Statistics toolbox
    if exist('cvpartition', 'file') ~= 2
        bst_report('Error', sProcess, sInput, 'This process requires the Statistics and Machine Learning Toolbox.');
        return;
    end
    % Check for the Parallel Computing toolbox (external dependencies - Kilosort2NeuroSuite in kilosort-wrapper)
    if (exist('matlabpool', 'file') ~= 2) && (exist('parpool', 'file') ~= 2)
        bst_report('Error', sProcess, sInput, 'This process requires the Parallel Computing Toolbox.');
        return;
    end
    % Load plugin
    [isInstalled, errMsg] = bst_plugin('Install', 'kilosort');
    if ~isInstalled
        error(errMsg);
    end
    
    % ===== OPTIONS =====
    % Get options
    BinSize = sProcess.options.binsize.Value{1};
    UseSsp = sProcess.options.usessp.Value;
    % Initialize KiloSort Parameters (This initially is a copy of StandardConfig_MOVEME)
    KilosortStandardConfig();
    ops.GPU = sProcess.options.GPU.Value;
    
    % File path
    bst_progress('text', 'Kilosort: Reading input files...');
    [fPath, fBase] = bst_fileparts(file_fullpath(sInput.FileName));
    % Remove "data_0raw" or "data_" tag
    if (length(fBase) > 10 && strcmp(fBase(1:10), 'data_0raw_'))
        fBase = fBase(11:end);
    elseif (length(fBase) > 5) && strcmp(fBase(1:5), 'data_')
        fBase = fBase(6:end);
    end
    
    % ===== LOAD INPUTS =====
    % Load input files
    DataMat = in_bst_data(sInput.FileName, 'F');
    sFile = DataMat.F;
    ChannelMat = in_bst_channel(sInput.ChannelFile);

    % Make sure we perform the spike sorting on the channels that have spikes. IS THIS REALLY NECESSARY? it would just take longer
    numChannels = 0;
    for iChannel = 1:length(ChannelMat.Channel)
       if strcmp(ChannelMat.Channel(iChannel).Type,'EEG') || strcmp(ChannelMat.Channel(iChannel).Type,'SEEG')
          numChannels = numChannels + 1;               
       end
    end
    
    % ===== OUTPUT FOLDER =====    
    outputPath = bst_fullfile(fPath, [fBase '_kilosort_spikes']);
    previous_directory = pwd;
    % If output folder already exists: delete it
    if exist(outputPath, 'dir') == 7
        % Move Matlab out of the folder to be deleted
        if ~isempty(strfind(previous_directory, outputPath))
            cd(bst_fileparts(outputPath));
        end
        % Delete existing output folder
        try
            rmdir(outputPath, 's');
        catch
        	error(['Could not remove spikes folder: ' 10 outputPath 10 ' Make sure this folder is not open in another program (e.g. Klusters).'])
        end
    end
    % Create output folder
    mkdir(outputPath);
    

    % ===== DATA CONVERSION =====
    % Prepare the ChannelMat File
    % This is a file that just contains information for the location of the electrodes.
    Nchannels = numChannels;
    connected = true(Nchannels, 1);
    chanMap   = 1:Nchannels;
    chanMap0ind = chanMap - 1;
    
    % Get the channels in the montage
    % First check if any montages have been assigned
    [Channels, Montages, channelsMontage,montageOccurences] = ParseMontage(ChannelMat);
    
    % Adjust the possible clusters based on the number of channels   
    doubleChannels = 2*max(montageOccurences); % Each Montage will be treated as its own entity.
    ops.Nfilt = ceil(doubleChannels/32)*32;    % number of clusters to use (2-4 times more than Nchan, should be a multiple of 32)
    
    
    % If the coordinates are assigned, convert 3d to 2d
    if sum(sum([ChannelMat.Channel.Loc]))~=0 % If values are already assigned
        alreadyAssignedLocations = 1;
    else
        alreadyAssignedLocations = 0;
    end
    
    channelsCoords = zeros(length(Channels),3); % THE 3D COORDINATES
    if alreadyAssignedLocations
        for iChannel = 1:length(Channels)
            for iMontage = 1:length(Montages)
                if strcmp(Channels(iChannel).Group, Montages{iMontage})
                    channelsCoords(iChannel,1:3) = Channels(iChannel).Loc;
                end
            end
        end

        % APPLY TRANSORMATION TO A FLAT SURFACE (X-Y COORDINATES: IGNORE Z)
        converted_coordinates = zeros(length(Channels),3);
        for iMontage = 1:length(Montages)
            single_array_coords = channelsCoords(channelsMontage==iMontage,:);
            % SVD approach
            [U, S, V] = svd(single_array_coords-mean(single_array_coords));
            lower_rank = 2;% Get only the first two components
            converted_coordinates(channelsMontage==iMontage,:)=U(:,1:lower_rank)*S(1:lower_rank,1:lower_rank)*V(:,1:lower_rank)'+mean(single_array_coords);
        end

        xcoords = converted_coordinates(:,1); 
        ycoords = converted_coordinates(:,2);
    else 
        xcoords = (1:length(Channels))';
        ycoords = ones(length(Channels),1);
    end
    
    kcoords = channelsMontage'; % grouping of channels (i.e. tetrode groups)
    fs = sFile.prop.sfreq; % sampling frequency

    save(bst_fullfile(outputPath, 'chanMap.mat'), ...
        'chanMap','connected', 'xcoords', 'ycoords', 'kcoords', 'chanMap0ind', 'fs')
    
    
    % Width of the spike-waveforms - NEEDS TO BE EVEN
    ops.nt0  = 0.0017*fs; % Width of the spike Waveforms. (1.7ms) THIS NEEDS TO BE EVEN. AN ODD VALUE DOESN'T GIVE ANY WAVEFORMS (The Kilosort2Neurosuite Function doesn't accommodate odd numbers)
    if mod(ops.nt0,2)
        ops.nt0 =ops.nt0+1;
    end
    ops.nt0 = round(ops.nt0); % Rounding error if not force integer here
    
    % Case of less neighbors (default config file value) than actual channels
    % For enabling PHY, make sure the value is less than the maximum
    % number of channels (maybe equal is also OK, probably not) and not empty.
%         ops.nNeighPC = []; % visualization only (Phy): number of channnels to mask the PCs, leave empty to skip (12)		
%         ops.nNeigh   = [];
    if ops.nNeighPC > numChannels
        ops.nNeighPC = numChannels - 1;
        ops.nNeigh   = numChannels - 1;
    end
    
    % Kilosort outputs a rez.mat file. The supervised part (Klusters) gets as input the rez file, and a .xml file (with parameters).
    % Create .xml
    xmlFile = bst_fullfile(outputPath, [fBase '.xml']);
    CreateXML(ChannelMat, fs, xmlFile, ops);
    
    cd(outputPath);
    
    % Convert to the right input for KiloSort
    converted_raw_File = ConvertForKilosort(sInput, BinSize * 1e9, UseSsp); % This converts into int16.
    

    % ===== SPIKE SORTING =====
    bst_progress('text', 'Kilosort: Spike-sorting');
    % Some residual parameters that need the outputPath and the converted Raw signal
    ops.fbinary  =  converted_raw_File; % will be created for 'openEphys'
    ops.fproc    = bst_fullfile(outputPath, 'temp_wh.bin'); % residual from RAM of preprocessed data		% It was .dat, I changed it to .bin - Make sure this is correct
    ops.chanMap  = bst_fullfile(outputPath, 'chanMap.mat'); % make this file using createChannelMapFile.m
    ops.root     = outputPath; % 'openEphys' only: where raw files are
    ops.basename = fBase;
    ops.fs       = fs; % sampling rate
    ops.NchanTOT = numChannels; % total number of channels
    ops.Nchan    = numChannels; % number of active channels
    
    % Initialize GPU (will erase any existing GPU arrays)
    if ops.GPU     
        gpuDevice(1);
    end
    
    [rez, DATA, uproj] = preprocessData(ops); % preprocess data and extract spikes for initialization
    try
        rez = fitTemplates(rez, DATA, uproj);  % fit templates iteratively
    catch
        if ops.GPU
            % ~\.brainstorm\plugins\kilosort\KiloSort-master\CUD?\mexGPUall.m
            % needs to be called and compile the .cu files.
            % Suggested environment: Matlab 2018a, CUDA 9.0, VS 13.
            bst_report('Error', sProcess, sInput, 'Error trying to spike-sort on the GPU. Have you set up CUDA correctly? Check https://github.com/cortex-lab/KiloSort for installation instructions');
            return;
        else
            bst_report('Error', sProcess, sInput, 'Error with Kilosort while training on the CPU');
            return;
        end
    end
        
    rez = fullMPMU(rez, DATA);% extract final spike times (overlapping extraction)
    
    % Save matlab results file
    save(fullfile(ops.root,  'rez.mat'), 'rez', '-v7.3');
    % remove temporary file
    delete(ops.fproc);

    % Now convert the rez.mat and the .xml to Neuroscope format so it can be read from Klusters
    %  Downloaded from: https://github.com/brendonw1/KilosortWrapper
    %  This creates 4 types of files x Number of montages (Groups of electrodes)
    % .clu: holds the cluster each spike belongs to
    % .fet: holds the feature values of each spike
    % .res: holds the spiketimes
    % .spk: holds the spike waveforms
    Kilosort2Neurosuite(rez)

    % Restore current folder
    cd(previous_directory);
    

    % ===== IMPORT EVENTS =====
    bst_progress('text', 'Saving events file...');
    
    % Delete existing spike events
    panel_spikes('DeleteSpikeEvents', sInput.FileName);
    % Add events to file
    sFile.RawFile = sInput.FileName;
    ImportKilosortEvents(sFile, ChannelMat, fPath, rez);

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
        curStruct.Path = file_short(outputPath);
        curStruct.File = fetFile.name;
        curStruct.Name = Montages{iMontage};
        curStruct.Mod  = 0;
        if isempty(spikes)
            spikes = curStruct;
        else
            spikes(end+1) = curStruct;
        end
    end
    
    % ===== SAVE SPIKE FILE =====
    % Build output filename
    NewBstFilePrefix = bst_fullfile(fPath, ['data_0ephys_kilo_' fBase]);
    NewBstFile = [NewBstFilePrefix '.mat'];
    iFile = 1;
    commentSuffix = '';
    while exist(NewBstFile, 'file') == 2
        iFile = iFile + 1;
        NewBstFile = [NewBstFilePrefix '_' num2str(iFile) '.mat'];
        commentSuffix = [' (' num2str(iFile) ')'];
    end
    % Build output structure
    DataMat_spikesorter = struct();
    DataMat_spikesorter.Comment  = ['KiloSort Spike Sorting' commentSuffix];
    DataMat_spikesorter.DataType = 'raw';%'ephys';
    DataMat_spikesorter.Device   = 'KiloSort';
    DataMat_spikesorter.Parent   = file_short(outputPath);
    DataMat_spikesorter.Spikes   = spikes;
    DataMat_spikesorter.RawFile  = sInput.FileName;
    DataMat_spikesorter.Name     = file_short(NewBstFile);
    % Add history field
    DataMat_spikesorter = bst_history('add', DataMat_spikesorter, 'import', ['Link to unsupervised electrophysiology files: ' outputPath]);
    % Save file on hard drive
    bst_save(NewBstFile, DataMat_spikesorter, 'v6');
    % Add file to database
    db_add_data(sInput.iStudy, file_short(NewBstFile), DataMat_spikesorter);
    % Return new file
    OutputFiles{end+1} = NewBstFile;

    % ===== UPDATE DATABASE =====
    % Update links
    db_links('Study', sInput.iStudy);
    panel_protocols('UpdateNode', 'Study', sInput.iStudy);
end


%% ===== CONVERT FOR KILOSORT =====
% Loads and creates separate raw electrode files for KiloSort (int16 file with no header)
function converted_raw_File = ConvertForKilosort(sInput, ram, UseSsp)      
    % Output folder
    ProtocolInfo = bst_get('ProtocolInfo');
    parentPath = bst_fullfile(bst_get('BrainstormTmpDir'), 'Unsupervised_Spike_Sorting', ProtocolInfo.Comment, sInput.FileName);
    % Check if file already converted
    converted_raw_File = bst_fullfile(parentPath, ['raw_data_no_header_' sInput.Condition(5:end) '.dat']);
    if exist(converted_raw_File, 'file') == 2
        disp('BST> File already converted to KiloSort input.')
        return
    end
    % Make sure the temporary directory exists, otherwise create it
    if ~exist(parentPath, 'dir')
        mkdir(parentPath);
    end
    % Apply SSP/ICA when reading from data files
    ImportOptions = db_template('ImportOptions');
    ImportOptions.UseCtfComp = 0;
    ImportOptions.UseSsp     = UseSsp;

    % Load input files
    DataMat = in_bst_data(sInput.FileName, 'F');
    sFile = DataMat.F;
    ChannelMat = in_bst_channel(sInput.ChannelFile);

    % Separate the file to max length based on RAM
    numChannels = length(ChannelMat.Channel);
    max_samples = ram / 8 / numChannels;  % Double precision
    total_samples = round((sFile.prop.times(2) - sFile.prop.times(1)) .* sFile.prop.sfreq);
    num_segments = ceil(total_samples / max_samples);
    num_samples_per_segment = ceil(total_samples / num_segments);

    % Progress bar
    bst_progress('start', 'KiloSort spike sorting', 'Converting to int16 .dat file', 0, num_segments);
    % Open file
    fid = fopen(converted_raw_File, 'a');
    % Loop on segments
    for iSegment = 1:num_segments
        sampleBounds(1) = (iSegment - 1) * num_samples_per_segment + round(sFile.prop.times(1)* sFile.prop.sfreq);
        if iSegment < num_segments
            sampleBounds(2) = sampleBounds(1) + num_samples_per_segment - 1;
        else
            sampleBounds(2) = total_samples + round(sFile.prop.times(1)* sFile.prop.sfreq);
        end
        % Read recordings
        F = in_fread(sFile, ChannelMat, [], sampleBounds, [], ImportOptions);
        % Adaptive conversion to int16 to avoid saturation
        max_abs_value = max([abs(max(max(F))) abs(min(min(F)))]);
        F = int16(F ./ max_abs_value * 15000); % The choice of 15000 for maximum is in part abstract - for 32567 the clusters look weird
        % Write to .dat file
        fwrite(fid, F, 'int16');
        % Increment progress bar
        bst_progress('inc', 1);
    end
    % Close file
    fclose(fid);
end


%% ===== IMPORT KILOSORT EVENTS =====
function ImportKilosortEvents(sFile, ChannelMat, parentPath, rez)
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
    
    spikeEventPrefix = panel_spikes('GetSpikesEventPrefix');
    
    index = 0;
    events_spikes = struct();
    % Fill the events fields
    for iCluster = 1:length(unique(spikeTemplates))
        selectedSpikes = find(spikeTemplates==uniqueClusters(iCluster));
        index = index+1;
        
        % Write the packet to events
        events_spikes(index).color      = rand(1,3);
        events_spikes(index).epochs     = ones(1,length(spikeTimes(selectedSpikes)));
        events_spikes(index).times      = spikeTimes(selectedSpikes)'./sFile.prop.sfreq + sFile.prop.times(1);
        events_spikes(index).reactTimes = [];
        events_spikes(index).select     = 1;
        events_spikes(index).notes      = [];
        
        if uniqueClusters(iCluster)==1 || uniqueClusters(iCluster)==0
            events_spikes(index).label    = ['Spikes Noise |' num2str(uniqueClusters(iCluster)) '|'];
            events_spikes(index).channels = [];
        else
            events_spikes(index).label    = [spikeEventPrefix ' ' ChannelMat.Channel(amplitude_max_channel(uniqueClusters(iCluster))).Name ' |' num2str(uniqueClusters(iCluster)) '|'];
            events_spikes(index).channels = repmat({{ChannelMat.Channel(amplitude_max_channel(uniqueClusters(iCluster))).Name}}, 1, size(events_spikes(index).times, 2));
        end
    end
    
    index = 0;
    % Add existing non-spike events for backup
    DataMat = in_bst_data(sFile.RawFile);
    existingEvents = DataMat.F.events;
    for iEvent = 1:length(existingEvents)
        if ~panel_spikes('IsSpikeEvent', existingEvents(iEvent).label)
            if index == 0
                events = existingEvents(iEvent);
            else
                events(index + 1) = existingEvents(iEvent);
            end
            index = index + 1;
        end
    end
    
    if ~isempty(existingEvents)
        events = [events events_spikes];
    else
        events = events_spikes;
    end
    
    save(fullfile(parentPath,'events_UNSUPERVISED.mat'),'events')
    
    % Assign the unsupervised spike sorted events to the link to raw file
    DataMat.F.events = events;    
    [folder, filename_link2Raw, extension] = bst_fileparts(sFile.RawFile);
    bst_save(bst_fullfile(parentPath, [filename_link2Raw extension]), DataMat, 'v6');
end


%% ===== LOAD KLUSTERS EVENTS =====
function [events, Channels] = LoadKlustersEvents(SpikeSortedMat, iMontage)
    % Information about the Neuroscope file can be found here:
    % http://neurosuite.sourceforge.net/formats.html

    % Load necessary files
    ChannelMat = in_bst_channel(bst_get('ChannelFileForStudy', SpikeSortedMat.RawFile));
    DataMat = in_bst_data(SpikeSortedMat.RawFile, 'F');
    sFile = DataMat.F;
    % Extract filename from 'filename.fet.1'
    [tmp, study] = fileparts(SpikeSortedMat.Spikes(iMontage).File);
    [tmp, study] = fileparts(study);
    sMontage = num2str(iMontage);
    clu = load(bst_fullfile(file_fullpath(SpikeSortedMat.Parent), [study '.clu.' sMontage]));
    fet = dlmread(bst_fullfile(file_fullpath(SpikeSortedMat.Parent), [study '.fet.' sMontage]));

    % Get the channels that belong in the selected montage
    [Channels, Montages, channelsMontage,montageOccurences] = ParseMontage(ChannelMat);
    ChannelsInMontage = ChannelMat.Channel(channelsMontage == iMontage); % Only the channels from the Montage should be loaded here to be used in the spike-events
    

    % The combination of the .clu files and the .fet file is enough to use on the converter.

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
    
    spikesPrefix = panel_spikes('GetSpikesEventPrefix');

    uniqueClusters = unique(clu(2:end))'; % The first entry is just the number of clusters

    for iCluster = 1:length(uniqueClusters)
        selectedSpikes = find(clu==uniqueClusters(iCluster));

        [tmp,iMaxFeature] = max(sum(abs(fet(selectedSpikes,1:end-3))));
        iElectrode = ceil(iMaxFeature/3);

        index = index+1;
        % Write the packet to events
        events(index).color      = rand(1,3);
        events(index).times      = fet(selectedSpikes,end)' ./ sFile.prop.sfreq + sFile.prop.times(1);
        events(index).epochs     = ones(1,length(events(index).times));
        events(index).reactTimes = [];
        events(index).select     = 1;
        events(index).notes      = [];
        
        if uniqueClusters(iCluster)==1 || uniqueClusters(iCluster)==0
            events(index).label    = ['Spikes Noise |' num2str(uniqueClusters(iCluster)) '|'];
            events(index).channels = [];
        else
            events(index).label    = [spikesPrefix ' ' ChannelsInMontage(iElectrode).Name ' |' num2str(uniqueClusters(iCluster)) '|'];
            events(index).channels = repmat({{ChannelsInMontage(iElectrode).Name}}, 1, size(events(index).times, 2));
        end
    end
end


%% ===== COPY KILOSORT CONFIG =====
% Called by bst_plugin after installing the kilosort plugin
function copyKilosortConfig(defaultFile, outputFile)
    if exist(outputFile, 'file') == 2
        delete(outputFile);
    end

    inFid  = fopen(defaultFile, 'r');
    outFid = fopen(outputFile, 'w');
    
    while ~feof(inFid)
        line = fgets(inFid);
        % Remove calls to load external files and their references later
        if ~isempty(strfind(line, 'load(')) || ~isempty(strfind(line, 'dd.'))
            line = ['%' line];
        end
        fprintf(outFid, '%s', line);
    end
    
    fclose(inFid);
    fclose(outFid);
end


%% ===== CREATE XML =====
function CreateXML(ChannelMat, Fs, xmlFile, ops)
    % Kilosort is designed to be used on shanks - this is like a probe
    % The users need to assign specific channels to specific shanks.
    % The following code takes into account several cases that can be
    % encountered: e.g. all channels already assigned to groups, none, or
    % partially
    % Sequentially, an .xml file with metadata is populated to be used in Klusters
    
    %% First check if any montages have been assigned
    allMontages = {ChannelMat.Channel.Group};
    nEmptyMontage = length(find(cellfun(@isempty,allMontages)));
    
    if nEmptyMontage == length(ChannelMat.Channel)
        keepChannels = find(ismember({ChannelMat.Channel.Type}, 'EEG') | ismember({ChannelMat.Channel.Type}, 'SEEG'));
        
        % No montages have been assigned. Assign all EEG/SEEG channels to a
        % single montage
        for iChannel = 1:length(ChannelMat.Channel)
            if strcmp(ChannelMat.Channel(iChannel).Type, 'EEG') || strcmp(ChannelMat.Channel(iChannel).Type, 'SEEG')
                ChannelMat.Channel(iChannel).Group = 'GROUP1'; % Just adding an entry here
            end
        end
        temp_ChannelsMat = ChannelMat.Channel(keepChannels);
    
    elseif nEmptyMontage == 0
        keepChannels = 1:length(ChannelMat.Channel);
        temp_ChannelsMat = ChannelMat.Channel(keepChannels);
    else
        % ADD AN EXTRA MONTAGE FOR CHANNELS THAT HAVENT BEEN ASSIGNED TO A MONTAGE
        for iChannel = 1:length(ChannelMat.Channel)
            if isempty(ChannelMat.Channel(iChannel).Group)
                ChannelMat.Channel(iChannel).Group = 'EMPTYGROUP'; % Just adding an entry here
            end
            temp_ChannelsMat = ChannelMat.Channel;
        end
    end

    montages = unique({temp_ChannelsMat.Group},'stable');
    montages = montages(find(~cellfun(@isempty, montages)));
    
    NumChansPerProbe = [];
    ChannelsInMontage  = cell(length(montages),2);
    for iMontage = 1:length(montages)
        ChannelsInMontage{iMontage,1} = ChannelMat.Channel(strcmp({ChannelMat.Channel.Group}, montages{iMontage})); % Only the channels from the Montage should be loaded here to be used in the spike-events
        
        for iChannel = 1:length(ChannelsInMontage{iMontage})
            ChannelsInMontage{iMontage,2} = [ChannelsInMontage{iMontage,2} find(strcmp({ChannelMat.Channel.Name}, ChannelsInMontage{iMontage}(iChannel).Name))];
        end
        NumChansPerProbe = [NumChansPerProbe length(ChannelsInMontage{iMontage,2})];
    end
    nMontages = length(montages);
    
    %% Define text components to assemble later
    
    chunk1 = {'<?xml version=''1.0''?>';...
    '<parameters version="1.0" creator="Brainstorm Converter">';...
    ' <acquisitionSystem>';...
    '  <nBits> 16 </nBits>'};
    
    channelcountlinestart = '  <nChannels>';
    channelcountlineend = '</nChannels>';
    
    chunk2 = {['  <samplingRate>' num2str(Fs) '</samplingRate>'];...
    '  <voltageRange>20</voltageRange>';...
    '  <amplification>1000</amplification>';...
    '  <offset>0</offset>';...
    ' </acquisitionSystem>';...
    ' <fieldPotentials>';...
    % % % % % ['  <lfpSamplingRate>' num2str(defaults.LfpSampleRate) '</lfpSamplingRate>'];...
    '  <lfpSamplingRate>1250</lfpSamplingRate>';...
    ' </fieldPotentials>';...
    ' <files>';...
    '  <file>';...
    '   <extension>lfp</extension>';...
    % % % % % ['   <samplingRate>' num2str(defaults.LfpSampleRate) '</samplingRate>'];...
    '   <samplingRate>1250</samplingRate>';...
    '  </file>';...
    % '  <file>';...
    % '   <extension>whl</extension>';...
    % '   <samplingRate>39.0625</samplingRate>';...
    % '  </file>';...
    ' </files>';...
    ' <anatomicalDescription>';...
    '  <channelGroups>'};
    
    anatomygroupstart = '   <group>';%repeats w every new anatomical group
    anatomychannelnumberline_start = '    <channel skip="0">';%for each channel in an anatomical group - first part of entry
    anatomychannelnumberline_end = '</channel>';%for each channel in an anatomical group - last part of entry
    anatomygroupend = '   </group>';%comes at end of each anatomical group
    
    chunk3 = {' </channelGroups>';...
      '</anatomicalDescription>';...
     '<spikeDetection>';...
      ' <channelGroups>'};%comes after anatomical groups and before spike groups
    
    spikegroupstart = {'  <group>';...
            '   <channels>'};%repeats w every new spike group
    spikechannelnumberline_start = '    <channel>';%for each channel in a spike group - first part of entry
    spikechannelnumberline_end = '</channel>';%for each channel in a spike group - last part of entry
    spikegroupend = {'   </channels>';...
    %    ['    <nSamples>' num2str(defaults.PointsPerWaveform) '</nSamples>'];...
    %    ['    <peakSampleIndex>' num2str(defaults.PeakPointInWaveform) '</peakSampleIndex>'];...
    %    ['    <nFeatures>' num2str(defaults.FeaturesPerWave) '</nFeatures>'];...
       ['    <nSamples>' num2str(ops.nt0) '</nSamples>'];...
       '    <peakSampleIndex>16</peakSampleIndex>';...
       '    <nFeatures>3</nFeatures>';...
        '  </group>'};%comes at end of each spike group
    
    chunk4 = {' </channelGroups>';...
     '</spikeDetection>';...
     '<neuroscope version="2.0.0">';...
      '<miscellaneous>';...
       '<screenGain>0.2</screenGain>';...
       '<traceBackgroundImage></traceBackgroundImage>';...
      '</miscellaneous>';...
      '<video>';...
       '<rotate>0</rotate>';...
       '<flip>0</flip>';...
       '<videoImage></videoImage>';...
       '<positionsBackground>0</positionsBackground>';...
      '</video>';...
      '<spikes>';...
      '</spikes>';...
      '<channels>'};
    
    channelcolorstart = ' <channelColors>';...
    channelcolorlinestart = '  <channel>';
    channelcolorlineend = '</channel>';
    channelcolorend = {'  <color>#0080ff</color>';...
        '  <anatomyColor>#0080ff</anatomyColor>';...
        '  <spikeColor>#0080ff</spikeColor>';...
       ' </channelColors>'};
    
    channeloffsetstart = ' <channelOffset>';
    channeloffsetlinestart = '  <channel>';
    channeloffsetlineend = '</channel>';
    channeloffsetend = {'  <defaultOffset>0</defaultOffset>';...
       ' </channelOffset>'};
    
    chunk5 = {   '</channels>';...
     '</neuroscope>';...
    '</parameters>'};
    
    
    %% Make basic text 
    s = chunk1;
    s = cat(1,s,[channelcountlinestart, num2str(length(ChannelMat.Channel)) channelcountlineend]);
    s = cat(1,s,chunk2);
    
    for iMontage = 1:nMontages %for each probe
        s = cat(1,s,anatomygroupstart);
        for iChannelWithinMontage = 1:NumChansPerProbe(iMontage)%for each spike group
            thischan = ChannelsInMontage{iMontage,2}(iChannelWithinMontage) - 1;
            s = cat(1,s,[anatomychannelnumberline_start, num2str(thischan) anatomychannelnumberline_end]);
        end
        s = cat(1,s,anatomygroupend);
    end
    
    s = cat(1,s,chunk3);
    
    for iMontage = 1:nMontages
        s = cat(1,s,spikegroupstart);
        for iChannelWithinMontage = 1:NumChansPerProbe(iMontage)
            thischan = ChannelsInMontage{iMontage,2}(iChannelWithinMontage) - 1;
            s = cat(1,s,[spikechannelnumberline_start, num2str(thischan) spikechannelnumberline_end]);
        end
        s = cat(1,s,spikegroupend);
    end
    
    s = cat(1,s, chunk4);
    
    for iMontage = 1:nMontages
        for iChannelWithinMontage = 1:NumChansPerProbe(iMontage)
            s = cat(1,s,channelcolorstart);
            thischan = ChannelsInMontage{iMontage,2}(iChannelWithinMontage) - 1;
            s = cat(1,s,[channelcolorlinestart, num2str(thischan) channelcolorlineend]);
            s = cat(1,s,channelcolorend);
            s = cat(1,s,channeloffsetstart);
            s = cat(1,s,[channeloffsetlinestart, num2str(thischan) channeloffsetlineend]);
            s = cat(1,s,channeloffsetend);
        end
    end

    s = cat(1,s, chunk5);
    
    % Output
    charcelltotext(s, xmlFile);
end


%% ===== CHAR CELL TO TEXT ====
function charcelltotext(charcell,filename)
    %based on matlab help.  Writes each row of the character cell (charcell) to a line of
    %text in the filename specified by "filename".  Char should be a cell array 
    %with format of a 1 column with many rows, each row with a single string of text.
    fid = fopen(filename, 'w');
    for row = 1:size(charcell, 1)
        fprintf(fid, '%s \n', charcell{row,:});
    end
    fclose(fid);
end


%% ===== GET MONTAGE =====
% Get the channels in the montage
function [Channels, Montages, channelsMontage, montageOccurences] = ParseMontage(ChannelMat)
    % First check if any montages have been assigned
    Channels = ChannelMat.Channel;
    allMontages = {Channels.Group};
    nEmptyMontage = length(find(cellfun(@isempty,allMontages)));

    if nEmptyMontage == length(Channels)
        keepChannels = find(ismember({Channels.Type}, 'EEG') | ismember({Channels.Type}, 'SEEG'));

        % No montages have been assigned. Assign all EEG/SEEG channels to a single montage
        for iChannel = 1:length(Channels)
            if strcmp(Channels(iChannel).Type, 'EEG') || strcmp(ChannelMat.Channel(iChannel).Type, 'SEEG')
                Channels(iChannel).Group = 'All'; % Just adding an entry here
            end
        end
        temp_ChannelsMat = Channels(keepChannels);

    elseif nEmptyMontage == 0
        keepChannels = 1:length(Channels);
        temp_ChannelsMat = Channels(keepChannels);
    else
        % ADD AN EXTRA MONTAGE FOR CHANNELS THAT HAVENT BEEN ASSIGNED TO A MONTAGE
        for iChannel = 1:length(Channels)
            if isempty(Channels(iChannel).Group)
                Channels(iChannel).Group = 'EMPTYGROUP'; % Just adding an entry here
            end
            temp_ChannelsMat = Channels;
        end
    end

    Montages = unique({temp_ChannelsMat.Group},'stable');
    Montages = Montages(find(~cellfun(@isempty, Montages)));

    channelsMontage = zeros(1,length(Channels));
    montageOccurences = zeros(1,length(Montages));
    for iChannel = 1:length(Channels)
        for iMontage = 1:length(Montages)
            if strcmp(Channels(iChannel).Group, Montages{iMontage})
                channelsMontage(iChannel) = iMontage;
                montageOccurences(iMontage) = montageOccurences(iMontage)+1;
            end
        end
    end
end


