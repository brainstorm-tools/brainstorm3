function varargout = process_spikesorting_unsupervised_KiloSort( varargin )
% PROCESS_SPIKESORTING_UNSUPERVISED:
% This process separates the initial raw signal to nChannels binary signals
% and performs spike sorting individually on each channel with the WaveClus
% spike-sorter. The spikes are clustered and assigned to individual
% neurons. The code ultimately produces a raw_elec(i)_spikes.mat
% for each electrode that can be used later for supervised spike-sorting.
% When all spikes on all electrodes have been clustered, all the spikes for
% each neuron is assigned to an events file in brainstorm format.
%
% USAGE: OutputFiles = process_spikesorting_unsupervised('Run', sProcess, sInputs)

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
    sProcess.Description = 'https://github.com/cortex-lab/KiloSort';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 0;
    sProcess.options.paral.Comment = 'Parallel processing';
    sProcess.options.paral.Type    = 'checkbox';
    sProcess.options.paral.Value   = 0;
    sProcess.options.GPU.Comment = 'GPU processing';
    sProcess.options.GPU.Type    = 'checkbox';
    sProcess.options.GPU.Value   = 0;
    sProcess.options.binsize.Comment = 'Samplesize for appending: ';
    sProcess.options.binsize.Type    = 'value';
    sProcess.options.binsize.Value   = {6, 'million samples', 1};
    
    % Options: Edit parameters
    sProcess.options.edit.Comment = {'panel_timefreq_options',  ' Edit parameters file:'};
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
    
    % Ensure we are including the KiloSort folder in the Matlab path
    KiloSortDir = bst_fullfile(bst_get('BrainstormUserDir'), 'KiloSort');
    if exist(KiloSortDir, 'file')
        addpath(genpath(KiloSortDir));
    end

    % Install KiloSort if missing
    if ~exist('make_eMouseData.m', 'file')  % This just checks for a file from the Kilosort file that it exists in the path
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
    
    
    %% Prepare parallel pool, if requested
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
    
    %% Initialize KiloSort Parameters (This is a copy of StandardConfig_MOVEME)
    
    ops.GPU                 = sProcess.options.GPU.Value; % whether to run this code on an Nvidia GPU (much faster, mexGPUall first)		
    ops.parfor              = sProcess.options.paral.Value; % whether to use parfor to accelerate some parts of the algorithm		
    ops.verbose             = 1; % whether to print command line progress		
    ops.showfigures         = 1; % whether to plot figures during optimization		

    ops.datatype            = 'dat';  % binary ('dat', 'bin') or 'openEphys'		
%     ops.fbinary             = 'C:\DATA\Spikes\Piroska\piroska_example_short.dat'; % will be created for 'openEphys'		
%     ops.fproc   = 'C:\DATA\Spikes\Piroska\temp_wh.dat'; % residual from RAM of preprocessed data		
% ops.fproc is defined later on the code so I have the outputPath
%     ops.root                = 'C:\DATA\Spikes\Piroska'; % 'openEphys' only: where raw files are		

%     ops.fs                  = 25000;        % sampling rate		(omit if already in chanMap file)
%     ops.NchanTOT            = 32;           % total number of channels (omit if already in chanMap file)
%     ops.Nchan               = 32;           % number of active channels (omit if already in chanMap file)

    ops.nNeighPC            = [] %12; % visualization only (Phy): number of channnels to mask the PCs, leave empty to skip (12)		
    ops.nNeigh              = [] %16; % visualization only (Phy): number of neighboring templates to retain projections of (16)		

    % options for channel whitening		
    ops.whitening           = 'full'; % type of whitening (default 'full', for 'noSpikes' set options for spike detection below)		
    ops.nSkipCov            = 1; % compute whitening matrix from every N-th batch (1)		
    ops.whiteningRange      = 32; % how many channels to whiten together (Inf for whole probe whitening, should be fine if Nchan<=32)		

    

    
    % define the channel map as a filename (string) or simply an array	
%     ops.chanMap = 'C:\DATA\Spikes\Piroska\chanMap.mat'; % make this file using createChannelMapFile.m		
% ops.chanMap is defined later on the code so I have the outputPath
    ops.criterionNoiseChannels = 0.2; % fraction of "noise" templates allowed to span all channel groups (see createChannelMapFile for more info). 		
    % ops.chanMap = 1:ops.Nchan; % treated as linear probe if a chanMap file		

    % other options for controlling the model and optimization		
    ops.Nrank               = 3;    % matrix rank of spike template model (3)		
    ops.nfullpasses         = 6;    % number of complete passes through data during optimization (6)		
    ops.maxFR               = 20000;  % maximum number of spikes to extract per batch (20000)		
    ops.fshigh              = 300;   % frequency for high pass filtering		
    % ops.fslow             = 2000;   % frequency for low pass filtering (optional)
    ops.ntbuff              = 64;    % samples of symmetrical buffer for whitening and spike detection		
    ops.scaleproc           = 200;   % int16 scaling of whitened data		
    ops.NT                  = 32*1024+ ops.ntbuff;% this is the batch size (try decreasing if out of memory) 		
    % for GPU should be multiple of 32 + ntbuff		

    % the following options can improve/deteriorate results. 		
    % when multiple values are provided for an option, the first two are beginning and ending anneal values, 		
    % the third is the value used in the final pass. 		
    ops.Th               = [4 10 10];    % threshold for detecting spikes on template-filtered data ([6 12 12])		
    ops.lam              = [5 20 20];   % large means amplitudes are forced around the mean ([10 30 30])		
    ops.nannealpasses    = 4;            % should be less than nfullpasses (4)		
    ops.momentum         = 1./[20 400];  % start with high momentum and anneal (1./[20 1000])		
    ops.shuffle_clusters = 1;            % allow merges and splits during optimization (1)		
    ops.mergeT           = .1;           % upper threshold for merging (.1)		
    ops.splitT           = .1;           % lower threshold for splitting (.1)		

    % options for initializing spikes from data		
    ops.initialize      = 'no'; %'fromData' or 'no'		
    ops.spkTh           = -6;      % spike threshold in standard deviations (4)		
    ops.loc_range       = [3  1];  % ranges to detect peaks; plus/minus in time and channel ([3 1])		
    ops.long_range      = [30  6]; % ranges to detect isolated peaks ([30 6])		
    ops.maskMaxChannels = 5;       % how many channels to mask up/down ([5])		
    ops.crit            = .65;     % upper criterion for discarding spike repeates (0.65)		
    ops.nFiltMax        = 10000;   % maximum "unique" spikes to consider (10000)		

    % load predefined principal components (visualization only (Phy): used for features)		
    dd                  = load('PCspikes2.mat'); % you might want to recompute this from your own data		
    ops.wPCA            = dd.Wi(:,1:7);   % PCs 		

    % options for posthoc merges (under construction)		
    ops.fracse  = 0.1; % binning step along discriminant axis for posthoc merges (in units of sd)		
    ops.epu     = Inf;		

    ops.ForceMaxRAMforDat   = 20e9; % maximum RAM the algorithm will try to use; on Windows it will autodetect.


    
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
        
        
        %% Adjust the possible clusters based on the number of channels
        doubleChannels = 2*numChannels;
        nClustersToUse = ceil(doubleChannels/32)*32; % number of clusters to use (2-4 times more than Nchan, should be a multiple of 32)     
        
        ops.Nfilt = nClustersToUse;    %64; % number of clusters to use (2-4 times more than Nchan, should be a multiple of 32)    
        clear doubleChannels nClustersToUse
        
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
        
        Channels = ChannelMat.Channel; % 1x224
        
        try
            Montages = unique({Channels.Group});
            alreadyAssignedMontages = true;
            for iChannel = 1:length(Channels)
                for iMontage = 1:length(Montages)
                    if strcmp(Channels(iChannel).Group, Montages{iMontage})
                        channelsMontage(iChannel)    = iMontage;
                    end
                end
            end
                
        catch
            Montages = 'SingleGroup';
            
            for iChannel = 1:length(Channels)
                Channels(iChannel).Group = 'SingleGroup';
            end
            
            alreadyAssignedMontages = false;
            channelsMontage = ones(1,length(Channels)); % This holds the code of the montage each channel holds 
        end

        %% If the coordinates are assigned, convert 3d to 2d
        
        if sum(sum([ChannelMat.Channel.Loc]'))~=0 % If values are already assigned
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
                clear single_array_coords
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
        
       
        
% % %         %%%%%%%%%%%%%  WE HAVE TO FIGURE OUT A SOLUTION FOR THIS %%%%%%%%%%
% % %         
% % %         % The datafile I'm using doesnt provide the locations of the
% % %         % electrodes (everything is 0). I create random positions for just
% % %         % making the spikesorter work. Delete these lines until the save
% % %         % after corrections
% % %         xcoords   = repmat([1 2 3 4]', 1, Nchannels/4);
% % %         xcoords   = xcoords(:);
% % %         ycoords   = repmat(1:Nchannels/4, 4, 1);
% % %         ycoords   = ycoords(:);
% % %         kcoords   = ones(Nchannels,1); % grouping of channels (i.e. tetrode groups)
% % %         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        save([outputPath '\chanMap.mat'], ...
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
%               'Neronexus/ Omnetics site',[DataMat.F.device ' pin'],[DataMat.F.device ' Channel'],'','','X Coordinates','Y Coordinates','','','Neuronexus/ Omnetics Site',[DataMat.F.device ' Pin'],[DataMat.F.device ' Channel']};
        
        nChannelsInMontage = cell(length(unique(kcoords)),1);
        for iType = unique(kcoords)'
            nChannelsInMontage{iType} = find(kcoords==iType);
        end

        ii = 0;
        for iType = unique(kcoords)'
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


%         for iChannel = 1:length(kcoords) % 1x224
%             A3{iChannel,1}  = iChannel;
%             A3{iChannel,2}  = iChannel-1; % Acquisition system codename - INTAN STARTS CHANNEL NUMBERING FROM 0. These .xlsx are made for INTAN I assume
%             A3{iChannel,3}  = iChannel-1;
%             A3{iChannel,4}  = ['SHANK ' num2str(kcoords(iChannel))];
%             A3{iChannel,5}  = '';
%             A3{iChannel,6}  = xcoords(iChannel); % x coord - THIS PROBABLY SHOULD BE RELATIVE TO EACH ARRAY - NOT GLOBAL COORDINATES
%             A3{iChannel,7}  = ycoords(iChannel);
%             A3{iChannel,8}  = '';
%             A3{iChannel,9}  = ['SHANK ' num2str(kcoords(iChannel))];
%             A3{iChannel,10} = iChannel; % This is for the display - Neuronexus/Omnetics Site
%             A3{iChannel,11} = iChannel-1; % This is for the display - Intan Pin
%             A3{iChannel,12} = iChannel-1; % This is for the display - Intan Channel
%         end
        
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
        
        [~, xmlFileBase] = bst_fileparts(xml_filename);
        bz_MakeXMLFromProbeMaps({xmlFileBase}, '','',1,defaults) % This creates a Barcode_f096_kilosort_spikes.xml
%         bz_MakeXMLFromProbeMaps({xmlFileBase}) % This creates a Barcode_f096_kilosort_spikes.xml
        weird_xml_filename = dir('*.xml');
        [~, weird_xml_fileBase] = bst_fileparts(weird_xml_filename.name);
        movefile([weird_xml_fileBase '.xml'],[xmlFileBase '.xml']); % Barcode_f096.xml
        
        
        
        
        %% Convert to the right input for KiloSort
        
        bst_progress('start', 'KiloSort spike-sorting', 'Converting to KiloSort Input...');
        
        converted_raw_File = in_spikesorting_convertForKiloSort(sInputs(i), sProcess); % This converts into int16.
        
        %%%%%%%%%%%%%%%%%%%%%%% Start the spike sorting %%%%%%%%%%%%%%%%%%%
        bst_progress('text', 'Spike-sorting...');
        
        
       
        
        %% Some residual parameters that need the outputPath and the converted Raw signal
        ops.fbinary =  converted_raw_File; % will be created for 'openEphys'		
        ops.fproc   = [outputPath '\temp_wh.bin']; % residual from RAM of preprocessed data		% It was .dat, I changed it to .bin - Make sure this is correct
        ops.chanMap = [outputPath '\chanMap.mat']; % make this file using createChannelMapFile.m		
        ops.root    = outputPath; % 'openEphys' only: where raw files are
        ops.basename = xmlFileBase;
        
        
        
        
        %% KiloSort
        
        if ops.GPU     
            gpuDevice(1); % initialize GPU (will erase any existing GPU arrays)
        end
        
        
        [rez, DATA, uproj] = preprocessData(ops); % preprocess data and extract spikes for initialization
        rez                = fitTemplates(rez, DATA, uproj);  % fit templates iteratively
        rez                = fullMPMU(rez, DATA);% extract final spike times (overlapping extraction)

        
        
        %  rez = merge_posthoc2(rez);  

        %% Convert to Phy output
        
        % AutoMerge. rez2Phy will use for clusters the new 5th column of st3 if you run this)
        
        % save python results file for Phy
        % rezToPhy(rez, ops.root);

        
        
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
        convertKilosort2BrainstormEvents(sFile, ChannelMat, bst_fullfile(ProtocolInfo.STUDIES, fPath), rez);
        
        cd(previous_directory);
        
        % ===== SAVE LINK FILE =====
        % Build output filename
        NewBstFile = bst_fullfile(ProtocolInfo.STUDIES, fPath, ['data_0ephys_' fBase '.mat']);
        % Build output structure
        DataMat = struct();
        %DataMat.F          = sFile;
        DataMat.Comment     = 'Spike Sorting Kilosort';
        DataMat.DataType    = 'raw';%'ephys';
        DataMat.Device      = 'KiloSort';
        DataMat.Spikes      = outputPath;
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

    if sProcess.options.paral.Value
        if ~isempty(poolobj)
            delete(poolobj);
        end
    end

    cd(previous_directory)
    
    
end




function convertKilosort2BrainstormEvents(sFile, ChannelMat, parentPath, rez)

    events = struct;
    events(2).label = [];
    events(2).epochs = [];
    events(2).times = [];
    events(2).color = [];
    events(2).samples = [];
    events(2).reactTimes = [];
    events(2).select = [];
    index = 0;
    
    
    
    
% % %     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % %     THIS IS NOT COMPLETE
% % %     TRANFORM REZ TO EVENTS
% % %     
    
    
    
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
        [~,amplitude_max_channel(i)] = max(range(templates(:,:,i)')); %CHANNEL WHERE EACH TEMPLATE HAS THE BIGGEST AMPLITUDE
    end
    
    
    % I assign each spike on the channel that it has the highest amplitude for the template it was matched with
    amplitude_max_channel = amplitude_max_channel';
    spike2ChannelAssignment = amplitude_max_channel(spikeTemplates);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    % Fill the events fields
    for iCluster = 1:length(unique(spikeTemplates))
        selectedSpikes = find(spikeTemplates==uniqueClusters(iCluster));
        
        index = index+1;
        % Write the packet to events
        
        if uniqueClusters(iCluster)==1
            events(index).label       = 'Spikes Noise |1|';
        else
            events(index).label       = ['Spikes Channel ' ChannelMat.Channel(amplitude_max_channel(uniqueClusters(iCluster))).Name ' |' num2str(uniqueClusters(iCluster)) '|'];
        end
        events(index).color       = rand(1,3);
        events(index).samples     = spikeTimes(selectedSpikes)'; % The timestamps are in SAMPLES
        events(index).times       = events(index).samples./sFile.prop.sfreq;
        events(index).epochs      = ones(1,length(events(index).samples));
        events(index).reactTimes  = [];
        events(index).select      = 1;
        
        
    end
        
    
    
    
    
% % % %     % Fill the events fields
% % % %     for iElectrode = 1:length(ChannelMat.Channel)
% % % %         if strcmp(ChannelMat.Channel(iElectrode).Type,'EEG') || strcmp(ChannelMat.Channel(iElectrode).Type,'SEEG')
% % % %             NeuronalTemplates = unique(spikeTemplates(spike2ChannelAssignment==iElectrode));
% % % %             if length(NeuronalTemplates)==1
% % % %                 index = index+1;
% % % %                 % Write the packet to events
% % % %                 events(index).label       = ['Spikes Channel ' ChannelMat.Channel(iElectrode).Name];
% % % %                 events(index).color       = rand(1,3);
% % % %                 events(index).samples     = spikeTimes(spike2ChannelAssignment==iElectrode)'; % The timestamps are in SAMPLES
% % % %                 events(index).times       = events(index).samples./sFile.prop.sfreq;
% % % %                 events(index).epochs      = ones(1,length(events(index).samples));
% % % %                 events(index).reactTimes  = [];
% % % %                 events(index).select      = 1;
% % % % 
% % % %             elseif NeuronalTemplates>1
% % % %                 for ineuron = 1:length(NeuronalTemplates)
% % % %                     % Write the packet to events
% % % %                     index = index+1;
% % % %                     events(index).label = ['Spikes Channel ' ChannelMat.Channel(iElectrode).Name ' |' num2str(ineuron) '|'];
% % % % 
% % % %                     events(index).color       = [rand(1,1),rand(1,1),rand(1,1)];
% % % %                     events(index).samples     = spikeTimes(spikeTemplates(spike2ChannelAssignment==iElectrode)==NeuronalTemplates(ineuron))'; % The timestamps are in SAMPLES
% % % %                     events(index).times       = events(index).samples./sFile.prop.sfreq;
% % % %                     events(index).epochs      = ones(1,length(events(index).times));
% % % %                     events(index).reactTimes  = [];
% % % %                     events(index).select      = 1;
% % % %                 end
% % % %             elseif NeuronalTemplates == 0
% % % %                 disp(['Channel: ' num2str(sFile.header.ChannelID(iElectrode)) ' just picked up noise'])
% % % %                 continue % This electrode just picked up noise
% % % %             end
% % % %         end
% % % %     end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    save(fullfile(parentPath,'events_UNSUPERVISED.mat'),'events')
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end


%% ===== DOWNLOAD AND INSTALL KiloSort =====
function downloadAndInstallKiloSort()

    % Kilosort just does unsupervised clustering. In order to visualize the
    % clusters and perform supervised clustering, you need to download a
    % python software called Phy. So 3 things are needed:
    % 1. KiloSort
    % 2. Phy
    % 3. npy-matlab that enables input-output from Matlab to Python
    

    KiloSortDir = bst_fullfile(bst_get('BrainstormUserDir'), 'KiloSort');
    KiloSortTmpDir = bst_fullfile(bst_get('BrainstormUserDir'), 'KiloSort_tmp');
    KiloSortWrapperTmpDir = bst_fullfile(bst_get('BrainstormUserDir'), 'KiloSortWrapper_tmp');
    
    % If folders exists: delete
    if isdir(KiloSortDir)
        file_delete(KiloSortDir, 1, 3);
    end
    if isdir(KiloSortTmpDir)
        file_delete(KiloSortTmpDir, 1, 3);
    end
    
    % Create folders
    KiloSortTmp = [KiloSortTmpDir '\KiloSort'];
    KiloSortWrapperTmp = [KiloSortWrapperTmpDir '\KiloSortWrapper'];
    PhyTmp = [KiloSortTmpDir '\Phy'];
    npyTemp = [KiloSortTmpDir '\npy'];
	mkdir(KiloSortTmp);
	mkdir(KiloSortWrapperTmp);
	mkdir(PhyTmp);
	mkdir(npyTemp);
    
    
    % Download KiloSort
    url_KiloSort = 'https://github.com/cortex-lab/KiloSort/archive/master.zip';
    KiloSortZipFile = bst_fullfile(KiloSortTmpDir, 'master.zip');
    errMsg = gui_brainstorm('DownloadFile', url_KiloSort, KiloSortZipFile, 'KiloSort download');
    if ~isempty(errMsg)
        error(['Impossible to download KiloSort:' errMsg]);
    end
    % Download KiloSortWrapper (For conversion to Neurosuite - Klusters)
    url_KiloSort_wrapper = 'https://github.com/brendonw1/KilosortWrapper/archive/master.zip';
    KiloSortWrapperZipFile = bst_fullfile(KiloSortWrapperTmpDir, 'master.zip');
    errMsg = gui_brainstorm('DownloadFile', url_KiloSort_wrapper, KiloSortWrapperZipFile, 'KiloSort download');
    if ~isempty(errMsg)
        error(['Impossible to download KiloSort:' errMsg]);
    end
    
    % Download Phy
    url_Phy = 'https://github.com/kwikteam/phy/archive/master.zip';
    PhyZipFile = bst_fullfile(KiloSortTmpDir, 'master.zip');
    errMsg = gui_brainstorm('DownloadFile', url_Phy, PhyZipFile, 'Phy download');
    if ~isempty(errMsg)
        error(['Impossible to download Phy:' errMsg]);
    end
    % Download npy-matlab
    url_npy = 'https://github.com/kwikteam/npy-matlab/archive/master.zip';
    npyZipFile = bst_fullfile(KiloSortTmpDir, 'master.zip');
    errMsg = gui_brainstorm('DownloadFile', url_npy, npyZipFile, 'npy-matlab download');
    if ~isempty(errMsg)
        error(['Impossible to download npy-Matlab:' errMsg]);
    end
    
    
    % Unzip KiloSort zip-file
    bst_progress('start', 'KiloSort', 'Installing KiloSort...');
    unzip(KiloSortZipFile, KiloSortTmpDir);
    % Get parent folder of the unzipped file
    diropen = dir(fullfile(KiloSortTmpDir, 'MATLAB*'));
    idir = find([diropen.isdir] & ~cellfun(@(c)isequal(c(1),'.'), {diropen.name}), 1);
    newKiloSortDir = bst_fullfile(KiloSortTmpDir, diropen(idir).name, 'KiloSort-master');
    % Move KiloSort directory to proper location
    movefile(newKiloSortDir, KiloSortDir);
    % Delete unnecessary files
    file_delete(KiloSortTmpDir, 1, 3);
    
    % Unzip KiloSort Wrapper zip-file
    bst_progress('start', 'KiloSort', 'Installing KiloSortWrapper...');
    unzip(KiloSortWrapperZipFile, KiloSortWrapperTmpDir);
    % Get parent folder of the unzipped file
    diropen = dir(fullfile(KiloSortWrapperTmpDir, 'MATLAB*'));
    idir = find([diropen.isdir] & ~cellfun(@(c)isequal(c(1),'.'), {diropen.name}), 1);
    newKiloSortWrapperDir = bst_fullfile(KiloSortWrapperTmpDir, diropen(idir).name, 'KiloSortWrapper-master');
    % Move KiloSort directory to proper location
    movefile(newKiloSortWrapperDir, KiloSortDir);
    % Delete unnecessary files
    file_delete(KiloSortWrapperTmpDir, 1, 3);
    
    % Unzip Phy zip-file
    bst_progress('start', 'Phy', 'Installing KiloSort...');
    unzip(PhyZipFile, PhyTmp);
    % Get parent folder of the unzipped file
    diropen = dir(fullfile(PhyTmp, 'MATLAB*'));
    idir = find([diropen.isdir] & ~cellfun(@(c)isequal(c(1),'.'), {diropen.name}), 1);
    newPhyDir = bst_fullfile(PhyTmp, diropen(idir).name, 'phy-master');
    % Move KiloSort directory to proper location
    movefile(newKiloSortDir, newPhyDir);
    % Delete unnecessary files
    file_delete(PhyTmp, 1, 3);
    
    
    % Unzip npy-matlab zip-file
    bst_progress('start', 'npy-matlab', 'Installing KiloSort...');
    unzip(npyZipFile, npyTemp);
    % Get parent folder of the unzipped file
    diropen = dir(fullfile(npyTemp, 'MATLAB*'));
    idir = find([diropen.isdir] & ~cellfun(@(c)isequal(c(1),'.'), {diropen.name}), 1);
    newKiloSortDir = bst_fullfile(npyTemp, diropen(idir).name, 'npy-matlab-master');
    % Move KiloSort directory to proper location
    movefile(newKiloSortDir, KiloSortDir);
    % Delete unnecessary files
    file_delete(npyTemp, 1, 3);
    
    % Add KiloSort to Matlab path
    addpath(genpath(KiloSortDir));
    
    
end










