function varargout = process_spikesorting_kilosort( varargin )
% PROCESS_SPIKESORTING_KILOSORT:
% This process separates the initial raw signal to nChannels binary signals
% and performs spike sorting individually on each channel with the KiloSort
% spike-sorter. The spikes are clustered and assigned to individual
% neurons. The code ultimately produces a raw_elec(i)_spikes.mat
% for each electrode that can be used later for supervised spike-sorting.
% When all spikes on all electrodes have been clustered, all the spikes for
% each neuron is assigned to an events file in brainstorm format.
%
% USAGE: OutputFiles = process_spikesorting_kilosort('Run', sProcess, sInputs)

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
% Authors: Konstantinos Nasiotis, 2018; Martin Cousineau, 2018

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'KiloSort';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Electrophysiology','Unsupervised Spike Sorting'};
    sProcess.Index       = 1203;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/e-phys/SpikeSorting';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 0;
    sProcess.options.spikesorter.Type   = 'text';
    sProcess.options.spikesorter.Value  = 'kilosort';
    sProcess.options.spikesorter.Hidden = 1;
    sProcess.options.GPU.Comment = 'GPU processing';
    sProcess.options.GPU.Type    = 'checkbox';
    sProcess.options.GPU.Value   = 0;
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
    % Check for Excel writer toolbox
    TestExcel = 'excelWriterTest.xlsx';
    try
        xlswrite(TestExcel, 1);
        delete(TestExcel);
    catch
        bst_report('Error', sProcess, sInputs, 'This process requires Excel installed. Apologies to Linux users.');
        return;
    end
    % Check for the Signal Processing toolbox
    if ~bst_get('UseSigProcToolbox')
        bst_report('Error', sProcess, sInputs, 'This process requires the Signal Processing Toolbox.');
        return;
    end
    % Check for the Statistics toolbox
    if exist('cvpartition', 'file') ~= 2
        bst_report('Error', sProcess, sInputs, 'This process requires the Statistics and Machine Learning Toolbox.');
        return;
    end
    % Check for the Parallel Computing toolbox (external dependencies)
    if (exist('matlabpool', 'file') ~= 2) && (exist('parpool', 'file') ~= 2)
        bst_report('Error', sProcess, sInputs, 'This process requires the Parallel Computing Toolbox.');
        return;
    end
    
    % Ensure we are including the KiloSort folder in the Matlab path
    KiloSortDir = bst_fullfile(bst_get('BrainstormUserDir'), 'kilosort');
    if exist(KiloSortDir, 'file')
        addpath(genpath(KiloSortDir));
    end

    % Install KiloSort if missing
    if ~exist('make_eMouseData.m', 'file')
        rmpath(genpath(KiloSortDir));
        isOk = java_dialog('confirm', ...
            ['The KiloSort spike-sorter is not installed on your computer.' 10 10 ...
                 'Download and install the latest version?'], 'KiloSort');
        if ~isOk
            bst_report('Error', sProcess, sInputs, 'This process requires the KiloSort spike-sorter.');
            return;
        end
        downloadAndInstallKiloSort();
    end
    
    %% Prepare parallel pool
    try
        poolobj = gcp('nocreate');
        if isempty(poolobj)
            parpool;
        end
    catch
        poolobj = [];
    end
    
    %% Initialize KiloSort Parameters (This is a copy of StandardConfig_MOVEME)
    KilosortStandardConfig();
    ops.GPU = sProcess.options.GPU.Value;
    
    
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
        
        
        
        %% %%%%%%%%%%%%%%%%%%% Prepare output folder %%%%%%%%%%%%%%%%%%%%%%        
        outputPath = bst_fullfile(ProtocolInfo.STUDIES, fPath, [fBase '_kilosort_spikes']);
        
        % Clear if directory already exists
        if exist(outputPath, 'dir') == 7
            try
                rmdir(outputPath, 's');
            catch
                error('Couldnt remove spikes folder. Make sure the current directory is not that folder.')
            end
        end
        
        mkdir(outputPath);
        
        %% Prepare the ChannelMat File
        % This is a file that just contains information for the location of
        % the electrodes.
        
        Nchannels = numChannels;
        connected = true(Nchannels, 1);
        chanMap   = 1:Nchannels;
        chanMap0ind = chanMap - 1;
        
        
        %% Use the same algorithm that I use for the 2d channel display for converting 3d to 2d
        
        Channels = ChannelMat.Channel;
        
        try
            Montages = unique({Channels.Group});
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
                
        catch
            Montages = 'All';
            
            for iChannel = 1:length(Channels)
                Channels(iChannel).Group = 'All';
            end
            
            montageOccurences = length(Channels);
            channelsMontage = ones(1,length(Channels)); % This holds the code of the montage each channel holds 
        end

        
        %% Adjust the possible clusters based on the number of channels
                
        doubleChannels = 2*max(montageOccurences); % Each Montage will be treated as its own entity.
        ops.Nfilt = ceil(doubleChannels/32)*32;    % number of clusters to use (2-4 times more than Nchan, should be a multiple of 32)
        
        
        %% If the coordinates are assigned, convert 3d to 2d
        
        if sum(sum([ChannelMat.Channel.Loc]))~=0 % If values are already assigned
            alreadyAssignedLocations = 1;
        else
            alreadyAssignedLocations = 0;
        end
        
        
        channelsCoords  = zeros(length(Channels),3); % THE 3D COORDINATES
        
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
            xcoords = [1:length(Channels)]';
            ycoords = ones(length(Channels),1);
        end
        
        kcoords = channelsMontage'; % grouping of channels (i.e. tetrode groups)
        fs = sFile.prop.sfreq; % sampling frequency

        save(bst_fullfile(outputPath, 'chanMap.mat'), ...
            'chanMap','connected', 'xcoords', 'ycoords', 'kcoords', 'chanMap0ind', 'fs')
        
        
        %% Width of the spike-waveforms - NEEDS TO BE EVEN
        ops.nt0  = 0.0017*fs; % Width of the spike Waveforms. (1.7ms) THIS NEEDS TO BE EVEN. AN ODD VALUE DOESN'T GIVE ANY WAVEFORMS (The Kilosort2Neurosuite Function doesn't accommodate odd numbers)
        if mod(ops.nt0,2)
            ops.nt0 =ops.nt0+1;
        end
        
        
        
        
        %% Kilosort outputs a rez.mat file. The supervised part (Klusters) gets as input the rez file, and a .xml file (with parameters).
        % I can create this .xml file from an excel file according to what
        % the Buzsaki lab uses.
        %  The buzsaki lab has a converter for "intan" files. Using this:
        
        % Create .xml file (Compatible with Buzsaki lab inputs)
        xml_filename = bst_fullfile(outputPath, [fBase '.xlsx']);

        A1 = {'SEE DERIVATION BELOW','','','','','X','Y','','BY VERTICAL POSITION/SHANK (IE FOR DISPLAY)','','','Neuroscope Channel';
              'Neronexus/ Omnetics site','Intan pin','Intan Channel','','','X Coordinates','Y Coordinates','','','Neuronexus/ Omnetics Site','Intan Pin','Intan Channel'};
        
        uniqueKCoords = unique(kcoords)';
        nChannelsInMontage = cell(length(uniqueKCoords),1);
        for iType = uniqueKCoords
            nChannelsInMontage{iType} = find(kcoords==iType);
        end

        ii = 0;
        for iType = uniqueKCoords
            for iChannel = nChannelsInMontage{iType}' % 1x96
                ii = ii+1;
                A3{ii,1}  = iChannel;
                A3{ii,2}  = iChannel-1; % Acquisition system codename - INTAN STARTS CHANNEL NUMBERING FROM 0. These .xlsx are made for INTAN I assume
                A3{ii,3}  = iChannel-1;
                A3{ii,4}  = ['SHANK ' num2str(iType)];
                A3{ii,5}  = '';
                A3{ii,6}  = xcoords(iChannel); % x coord - THIS PROBABLY SHOULD BE RELATIVE TO EACH ARRAY - NOT GLOBAL COORDINATES
                A3{ii,7}  = ycoords(iChannel);
                A3{ii,8}  = '';
                A3{ii,9}  = ['SHANK ' num2str(iType)];
                A3{ii,10} = iChannel; % This is for the display - Neuronexus/Omnetics Site
                A3{ii,11} = iChannel-1; % This is for the display - Intan Pin
                A3{ii,12} = iChannel-1; % This is for the display - Intan Channel
            end
        end
        
        sheet = 1;
        xlswrite(xml_filename,A1,sheet,'A1')
        xlswrite(xml_filename,A3,sheet,'A3')
        
        
        previous_directory = pwd;
        cd(outputPath);
        
        
        % Some defaults values I found in bz.MakeXMLFromProbeMaps
        defaults.NumberOfChannels = length(kcoords);
        defaults.SampleRate = fs;
        defaults.BitsPerSample = 16;
        defaults.VoltageRange = 20;
        defaults.Amplification = 1000;
        defaults.LfpSampleRate = 1250;
        defaults.PointsPerWaveform = ops.nt0;
        defaults.PeakPointInWaveform = 16;
        defaults.FeaturesPerWave = 3;
        
        [tmp, xmlFileBase] = bst_fileparts(xml_filename);
        bz_MakeXMLFromProbeMaps({xmlFileBase}, '','',1,defaults) % This creates a Barcode_f096_kilosort_spikes.xml
        weird_xml_filename = dir('*.xml');
        [tmp, weird_xml_fileBase] = bst_fileparts(weird_xml_filename.name);
        file_move([weird_xml_fileBase '.xml'],[xmlFileBase '.xml']); % Barcode_f096.xml
        
        
        %% Convert to the right input for KiloSort
        
        bst_progress('start', 'KiloSort spike-sorting', 'Converting to KiloSort Input...');
        
        converted_raw_File = in_spikesorting_convertforkilosort(sInputs(i), sProcess.options.binsize.Value{1} * 1e9); % This converts into int16.
        
        %%%%%%%%%%%%%%%%%%%%%%% Start the spike sorting %%%%%%%%%%%%%%%%%%%
        bst_progress('text', 'Spike-sorting...');
        
       
        
        %% Some residual parameters that need the outputPath and the converted Raw signal
        ops.fbinary  =  converted_raw_File; % will be created for 'openEphys'
        ops.fproc    = bst_fullfile(outputPath, 'temp_wh.bin'); % residual from RAM of preprocessed data		% It was .dat, I changed it to .bin - Make sure this is correct
        ops.chanMap  = bst_fullfile(outputPath, 'chanMap.mat'); % make this file using createChannelMapFile.m
        ops.root     = outputPath; % 'openEphys' only: where raw files are
        ops.basename = xmlFileBase;
        ops.fs       = fs; % sampling rate
        ops.NchanTOT = numChannels; % total number of channels
        ops.Nchan    = numChannels; % number of active channels
        
        
        %% KiloSort
        if ops.GPU     
            gpuDevice(1); % initialize GPU (will erase any existing GPU arrays)
        end
        
        
        [rez, DATA, uproj] = preprocessData(ops); % preprocess data and extract spikes for initialization
        rez                = fitTemplates(rez, DATA, uproj);  % fit templates iteratively
        rez                = fullMPMU(rez, DATA);% extract final spike times (overlapping extraction)        
        
        %% save matlab results file
        save(fullfile(ops.root,  'rez.mat'), 'rez', '-v7.3');
        % remove temporary file
        delete(ops.fproc);

        
        
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


%% ===== DOWNLOAD AND INSTALL KiloSort =====
function downloadAndInstallKiloSort()

    % Kilosort just does unsupervised clustering. In order to visualize the
    % clusters and perform supervised clustering, you need to download a
    % python software called Phy. So 3 things are needed:
    % 1. KiloSort
    % 2. Phy
    % 3. npy-matlab that enables input-output from Matlab to Python

    KiloSortDir = bst_fullfile(bst_get('BrainstormUserDir'), 'kilosort');
    KiloSortTmpDir = bst_fullfile(bst_get('BrainstormUserDir'), 'kilosort_tmp');
    
    % If folders exists: delete
    if isdir(KiloSortDir)
        file_delete(KiloSortDir, 1, 3);
    end

    % Create folders
    mkdir(KiloSortDir);
    if ~isdir(KiloSortTmpDir)
        mkdir(KiloSortTmpDir);
    end
    
    
    % Download KiloSort
    url_KiloSort = 'https://github.com/cortex-lab/KiloSort/archive/master.zip';
    KiloSortZipFile = bst_fullfile(KiloSortTmpDir, 'kilosort.zip');
    if exist(KiloSortZipFile, 'file') ~= 2
        errMsg = gui_brainstorm('DownloadFile', url_KiloSort, KiloSortZipFile, 'KiloSort download');
        
        % Check if the download was succesful and try again if it wasn't
        time_before_entering = clock;
        updated_time = clock;
        time_out = 60;% timeout within 60 seconds of trying to download the file

        % Keep trying to download until a timeout is reached
        while etime(updated_time, time_before_entering) <time_out && ~isempty(errMsg)
            % Try to download until the timeout is reached
            pause(0.1);
            errMsg = gui_brainstorm('DownloadFile', url_KiloSort, KiloSortZipFile, 'KiloSort download');
            updated_time = clock;
        end
        % If the timeout is reached and there is still an error, abort
        if etime(updated_time, time_before_entering) >time_out && ~isempty(errMsg)
            error(['Impossible to download KiloSort.' 10 errMsg]);
        end
    end
    
    
    % Download KiloSortWrapper (For conversion to Neurosuite - Klusters)
    url_KiloSort_wrapper = 'https://github.com/brendonw1/KilosortWrapper/archive/master.zip';
    KiloSortWrapperZipFile = bst_fullfile(KiloSortTmpDir, 'kilosort_wrapper.zip');
    if exist(KiloSortWrapperZipFile, 'file') ~= 2
        errMsg = gui_brainstorm('DownloadFile', url_KiloSort_wrapper, KiloSortWrapperZipFile, 'KiloSortWrapper download');
        
        % Check if the download was succesful and try again if it wasn't
        time_before_entering = clock;
        updated_time = clock;
        time_out = 60;% timeout within 60 seconds of trying to download the file
        
        % Keep trying to download until a timeout is reached
        while etime(updated_time, time_before_entering) <time_out && ~isempty(errMsg)
            % Try to download until the timeout is reached
            pause(0.1);
            errMsg = gui_brainstorm('DownloadFile', url_KiloSort_wrapper, KiloSortWrapperZipFile, 'KiloSortWrapper download');
            updated_time = clock;
        end
        % If the timeout is reached and there is still an error, abort
        if etime(updated_time, time_before_entering) >time_out && ~isempty(errMsg)
            error(['Impossible to download KiloSortWrapper.' 10 errMsg]);
        end
    end
    
    % Download Phy
    url_Phy = 'https://github.com/kwikteam/phy/archive/master.zip';
    PhyZipFile = bst_fullfile(KiloSortTmpDir, 'phy.zip');
    if exist(PhyZipFile, 'file') ~= 2
        errMsg = gui_brainstorm('DownloadFile', url_Phy, PhyZipFile, 'Phy download');
        
        % Check if the download was succesful and try again if it wasn't
        time_before_entering = clock;
        updated_time = clock;
        time_out = 60;% timeout within 60 seconds of trying to download the file
        
        % Keep trying to download until a timeout is reached
        while etime(updated_time, time_before_entering) <time_out && ~isempty(errMsg)
            % Try to download until the timeout is reached
            pause(0.1);
            errMsg = gui_brainstorm('DownloadFile', url_Phy, PhyZipFile, 'Phy download');
            updated_time = clock;
        end
        % If the timeout is reached and there is still an error, abort
        if etime(updated_time, time_before_entering) >time_out && ~isempty(errMsg)
            error(['Impossible to download Phy.' 10 errMsg]);
        end
    end
    
    % Download npy-matlab
    url_npy = 'https://github.com/kwikteam/npy-matlab/archive/master.zip';
    npyZipFile = bst_fullfile(KiloSortTmpDir, 'npy.zip');
    if exist(npyZipFile, 'file') ~= 2
        errMsg = gui_brainstorm('DownloadFile', url_npy, npyZipFile, 'npy-matlab download');
        
        % Check if the download was succesful and try again if it wasn't
        time_before_entering = clock;
        updated_time = clock;
        time_out = 60;% timeout within 60 seconds of trying to download the file
        
        % Keep trying to download until a timeout is reached
        while etime(updated_time, time_before_entering) <time_out && ~isempty(errMsg)
            % Try to download until the timeout is reached
            pause(0.1);
            errMsg = gui_brainstorm('DownloadFile', url_npy, npyZipFile, 'npy-matlab download');
            updated_time = clock;
        end
        % If the timeout is reached and there is still an error, abort
        if etime(updated_time, time_before_entering) >time_out && ~isempty(errMsg)
            error(['Impossible to download npy-matlab.' 10 errMsg]);
        end
    end
    
    % Unzip KiloSort zip-file
    bst_progress('start', 'KiloSort', 'Installing KiloSort...');
    unzip(KiloSortZipFile, KiloSortTmpDir);
    % Move KiloSort directory to proper location
    file_move(bst_fullfile(KiloSortTmpDir, 'KiloSort-master'), ...
        bst_fullfile(KiloSortDir, 'kilosort'));
    % Copy config file
    copyKilosortConfig(bst_fullfile(KiloSortDir, 'kilosort', 'configFiles', 'StandardConfig_MOVEME.m'), ...
        bst_fullfile(KiloSortDir, 'KilosortStandardConfig.m'));
    
    % Unzip KiloSort Wrapper zip-file
    unzip(KiloSortWrapperZipFile, KiloSortTmpDir);
    % Move KiloSort Wrapper directory to proper location
    file_move(bst_fullfile(KiloSortTmpDir, 'KilosortWrapper-master'), ...
        bst_fullfile(KiloSortDir, 'wrapper'));
    
    % Unzip Phy zip-file
    unzip(PhyZipFile, KiloSortTmpDir);
    % Move Phy directory to proper location
    file_move(bst_fullfile(KiloSortTmpDir, 'phy-master'), ...
        bst_fullfile(KiloSortDir, 'phy'));
    
    
    % Unzip npy-matlab zip-file
    unzip(npyZipFile, KiloSortTmpDir);
    % Move npy directory to proper location
    file_move(bst_fullfile(KiloSortTmpDir, 'npy-matlab-master'), ...
        bst_fullfile(KiloSortDir, 'npy'));
    
    % Delete unnecessary files
    file_delete(KiloSortTmpDir, 1, 3);
    % Add KiloSort to Matlab path
    addpath(genpath(KiloSortDir));
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
