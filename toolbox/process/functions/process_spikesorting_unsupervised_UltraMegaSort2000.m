function varargout = process_spikesorting_unsupervised_UltraMegaSort2000( varargin )
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
    sProcess.Comment     = 'UltraMegaSort unsupervised spike sorting';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Spike Sorting';
    sProcess.Index       = 1202;
    sProcess.Description = 'www.in.gr';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 0;
    sProcess.options.paral.Comment = 'Parallel processing';
    sProcess.options.paral.Type    = 'checkbox';
    sProcess.options.paral.Value   = 0;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    ProtocolInfo = bst_get('ProtocolInfo');
    
    % Ensure we are including the UltraMegaSort2000 folder in the Matlab path
    UltraMegaSort2000Dir = bst_fullfile(bst_get('BrainstormUserDir'), 'UltraMegaSort2000');
    if exist(UltraMegaSort2000Dir, 'file')
        addpath(genpath(UltraMegaSort2000Dir));
    end

    % Install UltraMegaSort2000 if missing
    if ~exist('UltraMegaSort2000 Manual.pdf', 'file')
        rmpath(genpath(UltraMegaSort2000Dir));
        isOk = java_dialog('confirm', ...
            ['The UltraMegaSort2000 spike-sorter is not installed on your computer.' 10 10 ...
                 'Download and install the latest version?'], 'UltraMegaSort2000');
        if ~isOk
            bst_report('Error', sProcess, sInputs, 'This process requires the UltraMegaSort2000 spike-sorter.');
            return;
        end
        downloadAndInstallUltraMegaSort2000();
    end
    
    % Compute on each raw input independently
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
        numChannels = length(ChannelMat.Channel);
        sFile = DataMat.F;
        
        bst_progress('start', 'UltraMegaSort2000 spike-sorting', 'Demultiplexing raw file...');
        sFiles = in_spikesorting_rawelectrodes(sInputs(i));
        
        % Prepare parallel pool, if requested
        if sProcess.options.paral.Value
            poolobj = gcp('nocreate');
            if isempty(poolobj)
                parpool;
            end
        end
        
        %%%%%%%%%%%%%%%%%%%%% Prepare output folder %%%%%%%%%%%%%%%%%%%%%%        
        outputPath = bst_fullfile(ProtocolInfo.STUDIES, fPath, [fBase '_spikes']);
        
        % Clear if directory already exists
        
        
        
        
        
        % I ADDED THE TRY HERE REMOVE
        
        if exist(outputPath, 'dir') == 7
            try
                rmdir(outputPath, 's');
            catch
                continue
            end
        end
        mkdir(outputPath);
        
        %%%%%%%%%%%%%%%%%%%%%%% Start the spike sorting %%%%%%%%%%%%%%%%%%%
        bst_progress('text', 'Spike-sorting...');
        
        
        
        %% UltraMegaSorter2000 needs manual filtering of the raw files
        
        Wp = [ 700 5000] * 2 / sFile.prop.sfreq; % pass band for filtering
        Ws = [ 500 7000] * 2 / sFile.prop.sfreq; % transition zone
        [N,Wn] = buttord( Wp, Ws, 3, 20); % determine filter parameters
        [B,A] = butter(N,Wn); % builds filter
        
        previous_directory = pwd;
        cd(outputPath);

        if sProcess.options.paral.Value  
            parfor ielectrode = 1:numChannels
                do_UltraMegaSorting(A,B,sFiles,ielectrode,sFile)
            end
        else
            for ielectrode = 1:numChannels
                do_UltraMegaSorting(A,B,sFiles,ielectrode,sFile)
            end
        end

        
        %%%%%%%%%%%%%%%%%%%%%  Create Brainstorm Events %%%%%%%%%%%%%%%%%%%
        bst_progress('text', 'Saving events file...');
        convert2BrainstormEvents(sFile, bst_fullfile(ProtocolInfo.STUDIES, fPath));
        
        
        cd(previous_directory);
        
        % ===== SAVE LINK FILE =====
        % Build output filename
        NewBstFile = bst_fullfile(ProtocolInfo.STUDIES, fPath, ['data_0ephys_' fBase '.mat']);
        % Build output structure
        DataMat = struct();
        %DataMat.F          = sFile;
        DataMat.Comment     = 'Spike Sorting';
        DataMat.DataType    = 'raw';%'ephys';
        DataMat.Device      = 'UltraMegaSort2000';
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



function do_UltraMegaSorting(A,B,sFiles,ielectrode,sFile)
    
    single_electrode_filename = sFiles{ielectrode};
    electrodeID = sFile.header.ChannelID(ielectrode);

    load(single_electrode_filename)
    filtered_data_temp = filtfilt( B, A, data); % runs filter
    filtered_data = cell(1,1);
    filtered_data{1} = filtered_data_temp; %should be a column vector clear filter
    clear filtered_data_temp
    
    spikes = ss_default_params(sFile.prop.sfreq);
    spikes = ss_detect(filtered_data,spikes);
    spikes = ss_align(spikes);
    spikes = ss_kmeans(spikes);
    spikes = ss_energy(spikes);
    spikes = ss_aggregate(spikes);
    
    save(['times_raw_elec' num2str(electrodeID) '.mat'], 'spikes')
    
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% MARTIN %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % THIS STARTS THE SUPERVISED PART:
%     splitmerge_tool(spikes)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    
end



function convert2BrainstormEvents(sFile, parentPath)

    events = struct;
    events(2).label = [];
    events(2).epochs = [];
    events(2).times = [];
    events(2).color = [];
    events(2).samples = [];
    events(2).reactTimes = [];
    events(2).select = [];
    index = 0;
    for ielectrode = sFile.header.ChannelID'
        
        try
            load(['times_raw_elec' num2str(ielectrode) '.mat'],'spikes') % This will fail if the electrode picked up less than 16 spikes. Consider putting a try-catch block

            spikes.spiketimes = double(spikes.spiketimes);
       
            nNeurons = size(spikes.labels,1); % This gives the number of neurons that are picked up on that electrode
            if nNeurons==1
                index = index+1;

                % Write the packet to events
                events(index).label       = ['Spikes Electrode ' num2str(ielectrode)];
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
                    events(index).label = ['Spikes Electrode ' num2str(ielectrode) ' |' num2str(ineuron) '|'];

                    events(index).color       = [rand(1,1),rand(1,1),rand(1,1)];
                    events(index).epochs      = ones(1,length(spikes.assigns(spikes.assigns==spikes.labels(ineuron,1))));
                    events(index).times       = spikes.spiketimes(spikes.assigns==spikes.labels(ineuron,1)); % The timestamps are in seconds
                    events(index).samples     = events(index).times.*sFile.prop.sfreq;
                    events(index).reactTimes  = [];
                    events(index).select      = 1;
                end
            elseif nNeurons == 0
                disp(['Electrode: ' num2str(ielectrode) ' just picked up noise'])
                continue % This electrode just picked up noise
            end
            
        catch
            disp(['Electrode: ' num2str(ielectrode) ' had no clustered spikes'])
        end
    end


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    save(fullfile(parentPath,'events_UNSUPERVISED.mat'),'events')
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



end


%% ===== DOWNLOAD AND INSTALL UltraMegaSort2000 =====
function downloadAndInstallUltraMegaSort2000()
    UltraMegaSort2000Dir = bst_fullfile(bst_get('BrainstormUserDir'), 'UltraMegaSort2000');
    UltraMegaSort2000TmpDir = bst_fullfile(bst_get('BrainstormUserDir'), 'UltraMegaSort2000_tmp');
    url = 'https://github.com/danamics/UMS2K/archive/master.zip';
    % If folders exists: delete
    if isdir(UltraMegaSort2000Dir)
        file_delete(UltraMegaSort2000Dir, 1, 3);
    end
    if isdir(UltraMegaSort2000TmpDir)
        file_delete(UltraMegaSort2000TmpDir, 1, 3);
    end
    % Create folder
	mkdir(UltraMegaSort2000TmpDir);
    % Download file
    zipFile = bst_fullfile(UltraMegaSort2000TmpDir, 'master.zip');
    errMsg = gui_brainstorm('DownloadFile', url, zipFile, 'UltraMegaSort2000 download');
    if ~isempty(errMsg)
        error(['Impossible to download UltraMegaSort2000:' errMsg]);
    end
    % Unzip file
    bst_progress('start', 'UltraMegaSort2000', 'Installing UltraMegaSort2000...');
    unzip(zipFile, UltraMegaSort2000TmpDir);
    % Get parent folder of the unzipped file
    diropen = dir(fullfile(UltraMegaSort2000TmpDir, 'MATLAB*'));
    idir = find([diropen.isdir] & ~cellfun(@(c)isequal(c(1),'.'), {diropen.name}), 1);
    newUltraMegaSort2000Dir = bst_fullfile(UltraMegaSort2000TmpDir, diropen(idir).name, 'UMS2K-master');
    % Move WaveClus directory to proper location
    movefile(newUltraMegaSort2000Dir, UltraMegaSort2000Dir);
    % Delete unnecessary files
    file_delete(UltraMegaSort2000TmpDir, 1, 3);
    % Add WaveClus to Matlab path
    addpath(genpath(UltraMegaSort2000Dir));
end










