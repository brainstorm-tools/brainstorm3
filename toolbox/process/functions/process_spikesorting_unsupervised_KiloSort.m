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
    sProcess.Comment     = 'KiloSort unsupervised spike sorting';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Spike Sorting';
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
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% MARTIN %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % These two files need to be accessible to the user
    % The parameters file is created in StandardCOnfig_MOVEME
    
    % The Channel Positions file is created in createChannelMapFile
    % In theory, the acquisition system should give the positions of the
    % electrodes (ChannelMat.Channel.Loc). We have to make sure this works
    % with the coordinates of the positions (0.11, 0.22, 0.33 mm), or it
    % only takes indices (1,2,3)
    
    
    % Options: Edit parameters
    sProcess.options.edit.Comment = {'panel_timefreq_options',  ' Edit parameters file:'};
    sProcess.options.edit.Type    = 'editpref'; 
    sProcess.options.edit.Value   = [];
    % Options: Edit electrodes positions
    sProcess.options.edit2.Comment = {'panel_timefreq_options', ' Edit Channel Positions file: '};
    sProcess.options.edit2.Type    = 'editpref';
    sProcess.options.edit2.Value   = [];
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
    
    
    
    
    %% Initialize KiloSort Parameters (This is a copy of StandardConfig_MOVEME)
    
    ops.GPU                 = sProcess.options.GPU.Value; % whether to run this code on an Nvidia GPU (much faster, mexGPUall first)		
    ops.parfor              = sProcess.options.paral.Value; % whether to use parfor to accelerate some parts of the algorithm		
    ops.verbose             = 1; % whether to print command line progress		
    ops.showfigures         = 1; % whether to plot figures during optimization		

    ops.datatype            = 'bin';  % binary ('dat', 'bin') or 'openEphys'		
%     ops.fbinary             = 'C:\DATA\Spikes\Piroska\piroska_example_short.dat'; % will be created for 'openEphys'		
%     ops.fproc   = 'C:\DATA\Spikes\Piroska\temp_wh.dat'; % residual from RAM of preprocessed data		
% ops.fproc is defined later on the code so I have the outputPath
%     ops.root                = 'C:\DATA\Spikes\Piroska'; % 'openEphys' only: where raw files are		

%     ops.fs                  = 25000;        % sampling rate		(omit if already in chanMap file)
%     ops.NchanTOT            = 32;           % total number of channels (omit if already in chanMap file)
%     ops.Nchan               = 32;           % number of active channels (omit if already in chanMap file)
    ops.Nfilt               = 64;           % number of clusters to use (2-4 times more than Nchan, should be a multiple of 32)     		
    ops.nNeighPC            = 12; % visualization only (Phy): number of channnels to mask the PCs, leave empty to skip (12)		
    ops.nNeigh              = 16; % visualization only (Phy): number of neighboring templates to retain projections of (16)		

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
        
        
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%% MARTIN %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        %%%%%%numChannels = length(ChannelMat.Channel);  % THIS WILL FAIL IF THE RECORDING SYSTEM HAS EXTRA CHANNEL TYPES (EOG - Photodiode etc.)

        %Correct for other spike sorters as well
        %Do:
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        numChannels = 0;
        for iChannel = 1:length(ChannelMat.Channel)
           if ChannelMat.Channel(iChannel).Type == 'EEG'
              numChannels = numChannels + 1;               
           end
        end
        
        sFile = DataMat.F;
               
        %% %%%%%%%%%%%%%%%%%%% Prepare output folder %%%%%%%%%%%%%%%%%%%%%%        
        outputPath = bst_fullfile(ProtocolInfo.STUDIES, fPath, [fBase '_spikes']);
        
        % Clear if directory already exists        
        if exist(outputPath, 'dir') == 7
            rmdir(outputPath, 's');
        end
        mkdir(outputPath);
        
        
        
        %% Prepare the ChannelMat File
        % This is a file that just contains information for the location of
        % the electrodes.
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%% MARTIN %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % I assume that each acquisition system provides information for
        % the location of the electrodes here (ChannelMatChannel.Loc)
        % Make sure that each importer (in_fread) populates the location values 
        
        
        Nchannels = numChannels;
        connected = true(Nchannels, 1);
        chanMap   = 1:Nchannels;
        chanMap0ind = chanMap - 1;

        
        xcoords = [];
        ycoords = [];
        for iChannel = 1:length(ChannelMat.Channel)
           if ChannelMat.Channel(iChannel).Type == 'EEG'
              temp = ChannelMat.Channel(iChannel).Loc;
              xcoords = [xcoords ; temp(1)];
              ycoords = [ycoords ; temp(2)];
           end
        end
        clear temp
        
        kcoords   = ones(Nchannels,1); % grouping of channels (i.e. tetrode groups)
        fs = sFile.prop.sfreq; % sampling frequency

        
        
        
        %%%%%%%%%%%%%  WE HAVE TO FIGURE OUT A SOLUTION FOR THIS %%%%%%%%%%
        
        % The datafile I'm using doesnt provide the locations of the
        % electrodes (everything is 0). I create random positions for just
        % making the spikesorter work. Delete these lines until the save
        % after corrections
        xcoords   = repmat([1 2 3 4]', 1, Nchannels/4);
        xcoords   = xcoords(:);
        ycoords   = repmat(1:Nchannels/4, 4, 1);
        ycoords   = ycoords(:);
        kcoords   = ones(Nchannels,1); % grouping of channels (i.e. tetrode groups)
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        save([outputPath '\chanMap.mat'], ...
            'chanMap','connected', 'xcoords', 'ycoords', 'kcoords', 'chanMap0ind', 'fs')
        
        %% Convert to the right input for KiloSort
        
        bst_progress('start', 'KiloSort spike-sorting', 'Converting to KiloSort Input...');
        
        converted_raw_File = in_spikesorting_convertForKiloSort(sInputs(i), sProcess); % This converts into int16. Confirm that it's the only precision acceptable
        
        %%%%%%%%%%%%%%%%%%%%%%% Start the spike sorting %%%%%%%%%%%%%%%%%%%
        bst_progress('text', 'Spike-sorting...');
        
        
        %% Some residual parameters that need the outputPath and the converted Raw signal
        ops.fbinary =  converted_raw_File; % will be created for 'openEphys'		
        ops.fproc   = [outputPath '\temp_wh.bin']; % residual from RAM of preprocessed data		% It was .dat, I changed it to .bin - Make sure this is correct
        ops.chanMap = [outputPath '\chanMap.mat']; % make this file using createChannelMapFile.m		
        ops.root    = outputPath; % 'openEphys' only: where raw files are

        
        
        %% KiloSort
        
        previous_directory = pwd;
        cd(outputPath);
        
        if ops.GPU     
            gpuDevice(1); % initialize GPU (will erase any existing GPU arrays)
        end
        
        
        [rez, DATA, uproj] = preprocessData(ops); % preprocess data and extract spikes for initialization
        rez                = fitTemplates(rez, DATA, uproj);  % fit templates iteratively
        rez                = fullMPMU(rez, DATA);% extract final spike times (overlapping extraction)

        % AutoMerge. rez2Phy will use for clusters the new 5th column of st3 if you run this)
        %     rez = merge_posthoc2(rez);

        % save matlab results file
        save(fullfile(ops.root,  'rez.mat'), 'rez', '-v7.3');

        % save python results file for Phy
        rezToPhy(rez, ops.root);

        % remove temporary file
        delete(ops.fproc);

        
        
        
        
        %% %%%%%%%%%%%%%%%%%%%  Create Brainstorm Events %%%%%%%%%%%%%%%%%%%
        
        bst_progress('text', 'Saving events file...');
        convert2BrainstormEvents(sFile, bst_fullfile(ProtocolInfo.STUDIES, fPath), rez);
        
        cd(previous_directory);
        
        % ===== SAVE LINK FILE =====
        % Build output filename
        NewBstFile = bst_fullfile(ProtocolInfo.STUDIES, fPath, ['data_0ephys_' fBase '.mat']);
        % Build output structure
        DataMat = struct();
        %DataMat.F          = sFile;
        DataMat.Comment     = 'Spike Sorting';
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




function convert2BrainstormEvents(sFile, parentPath, rez)

    events = struct;
    events(2).label = [];
    events(2).epochs = [];
    events(2).times = [];
    events(2).color = [];
    events(2).samples = [];
    events(2).reactTimes = [];
    events(2).select = [];
    index = 0;
    
    
    
    
    
    
    for ielectrode = 1:length(rez.xc) % sFile.header.ChannelID'
        
        
        
        try       
            nNeurons = size(spikes.labels,1); % This gives the number of neurons that are picked up on that electrode
            if nNeurons==1
                index = index+1;

                % Write the packet to events
                events(index).label       = ['Spikes Electrode ' num2str(sFile.header.ChannelID(ielectrode))];
                events(index).color       = [rand(1,1),rand(1,1),rand(1,1)];
                events(index).epochs      = ones(1,length(spikes.assigns));   % There is no noise automatic assignment on UltraMegaSorter2000. Everything is assigned to neurons
                events(index).times       = spikes.spiketimes; % The timestamps are in seconds
                events(index).samples     = events(index).times.*sFile.prop.sfreq;
                events(index).reactTimes  = [];
                events(index).select      = 1;

            elseif nNeurons>1
                for ineuron = 1:nNeurons
                    % Write the packet to events
                    index = index+1;
                    events(index).label = ['Spikes Electrode ' num2str(sFile.header.ChannelID(ielectrode)) ' |' num2str(ineuron) '|'];

                    events(index).color       = [rand(1,1),rand(1,1),rand(1,1)];
                    events(index).epochs      = ones(1,length(spikes.assigns(spikes.assigns==spikes.labels(ineuron,1))));
                    events(index).times       = spikes.spiketimes(spikes.assigns==spikes.labels(ineuron,1)); % The timestamps are in seconds
                    events(index).samples     = events(index).times.*sFile.prop.sfreq;
                    events(index).reactTimes  = [];
                    events(index).select      = 1;
                end
            elseif nNeurons == 0
                disp(['Electrode: ' num2str(sFile.header.ChannelID(ielectrode)) ' just picked up noise'])
                continue % This electrode just picked up noise
            end
            
        catch
            disp(['Electrode: ' num2str(sFile.header.ChannelID(ielectrode)) ' had no clustered spikes'])
        end
    end


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
    
    % If folders exists: delete
    if isdir(KiloSortDir)
        file_delete(KiloSortDir, 1, 3);
    end
    if isdir(KiloSortTmpDir)
        file_delete(KiloSortTmpDir, 1, 3);
    end
    
    % Create folders
    KiloSortTmp = [KiloSortTmpDir '\KiloSort'];
    PhyTmp = [KiloSortTmpDir '\Phy'];
    npyTemp = [KiloSortTmpDir '\npy'];
	mkdir(KiloSortTmp);
	mkdir(PhyTmp);
	mkdir(npyTemp);
    
    
    % Download KiloSort
    url_KiloSort = 'https://github.com/cortex-lab/KiloSort/archive/master.zip';
    KiloSortZipFile = bst_fullfile(KiloSortTmpDir, 'master.zip');
    errMsg = gui_brainstorm('DownloadFile', url_KiloSort, KiloSortZipFile, 'KiloSort download');
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










