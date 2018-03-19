function varargout = process_spikesorting_unsupervised( varargin )
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
    sProcess.Comment     = 'WaveClus unsupervised spike sorting';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Spike Sorting';
    sProcess.Index       = 1201;
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
    sProcess.options.make_plots.Comment = 'Create Images';
    sProcess.options.make_plots.Type    = 'checkbox';
    sProcess.options.make_plots.Value   = 0;
    % Channel name comment
    sProcess.options.make_plotshelp.Comment = '<I><FONT color="#777777">This saves images of the clustered spikes</FONT></I>';
    sProcess.options.make_plotshelp.Type    = 'label';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    ProtocolInfo = bst_get('ProtocolInfo');
    
    % Ensure we are including the WaveClus folder in the Matlab path
    waveclusDir = bst_fullfile(bst_get('BrainstormUserDir'), 'waveclus');
    if exist(waveclusDir, 'file')
        addpath(genpath(waveclusDir));
    end

    % Install WaveClus if missing
    if ~exist('wave_clus_font', 'file')
        rmpath(genpath(waveclusDir));
        isOk = java_dialog('confirm', ...
            ['The WaveClus spike-sorter is not installed on your computer.' 10 10 ...
                 'Download and install the latest version?'], 'WaveClus');
        if ~isOk
            bst_report('Error', sProcess, sInputs, 'This process requires the WaveClus spike-sorter.');
            return;
        end
        downloadAndInstallWaveClus();
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
        
        bst_progress('start', 'WaveClus spike-sorting', 'Demultiplexing raw file...');
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
        if exist(outputPath, 'dir') == 7
            rmdir(outputPath, 's');
        end
        mkdir(outputPath);
        
        %%%%%%%%%%%%%%%%%%%%%%% Start the spike sorting %%%%%%%%%%%%%%%%%%%
        bst_progress('text', 'Spike-sorting...');
        
        % The Get_spikes saves the _spikes files at the current directory.
        previous_directory = pwd;
        cd(outputPath);

        if sProcess.options.paral.Value  
            parfor ielectrode = 1:numChannels
                Get_spikes(sFiles{ielectrode})
            end
        else
            for ielectrode = 1:numChannels
                Get_spikes(sFiles{ielectrode})
            end
        end

        %%%%%%%%%%%%%%%%%%%%%% Do the clustering %%%%%%%%%%%%%%%%%%%%%%%%%%
        bst_progress('text', 'Clustering detected spikes...');
        
        % The optional inputs in Do_clustering have to be true or false, not 1 or 0
        if sProcess.options.paral.Value
            parallel = true;
        else
            parallel = false;
        end
        if sProcess.options.make_plots.Value
            make_plots = true;
        else
            make_plots = false;
        end
        
        % Do the clustering in parallel
        Do_clustering(1:numChannels, 'parallel', parallel, 'make_plots', make_plots);
        
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
        DataMat.Device      = 'waveclus';
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

    %cd(previous_directory)
    
    
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
            load(['times_raw_elec' num2str(ielectrode) '.mat'],'cluster_class') % This will fail if the electrode picked up less than 16 spikes. Consider putting a try-catch block

            nNeurons = unique(cluster_class(cluster_class(:,1)>0,1)); % This gives the number of neurons that are picked up on that electrode
            if length(nNeurons)==1
                index = index+1;

                % Write the packet to events
                events(index).label       = ['Spikes Electrode ' num2str(ielectrode)];
                events(index).color       = [rand(1,1),rand(1,1),rand(1,1)];
                events(index).epochs      = ones(1,sum(cluster_class(:,1)~=0));
                events(index).times       = cluster_class(cluster_class(:,1)~=0,2)'./1000; % The timestamps in the cluster_class are in ms
                events(index).samples     = events(index).times.*sFile.prop.sfreq;
                events(index).reactTimes  = [];
                events(index).select      = 1;

            elseif length(nNeurons)>1
                for ineuron = 1:length(nNeurons)
                    % Write the packet to events
                    index = index+1;
                    events(index).label = ['Spikes Electrode ' num2str(ielectrode) ' |' num2str(ineuron) '|'];

                    events(index).color       = [rand(1,1),rand(1,1),rand(1,1)];
                    events(index).epochs      = ones(1,length(cluster_class(cluster_class(:,1)==ineuron,1)));
                    events(index).times       = cluster_class(cluster_class(:,1)==ineuron,2)'./1000; % The timestamps in the cluster_class are in ms
                    events(index).samples     = events(index).times.*sFile.prop.sfreq;
                    events(index).reactTimes  = [];
                    events(index).select      = 1;
                end
            elseif length(nNeurons) == 0
                disp(['Electrode: ' num2str(ielectrode) ' just picked up noise'])
                continue % This electrode just picked up noise
            end
            
        catch
            disp(['Electrode: ' num2str(ielectrode) ' had no clustered spikes'])
        end
    end


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    save(bst_fullfile(parentPath, 'events_UNSUPERVISED.mat'),'events');

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



end


%% ===== DOWNLOAD AND INSTALL WAVECLUS =====
function downloadAndInstallWaveClus()
    waveclusDir = bst_fullfile(bst_get('BrainstormUserDir'), 'waveclus');
    waveclusTmpDir = bst_fullfile(bst_get('BrainstormUserDir'), 'waveclus_tmp');
    url = 'https://github.com/csn-le/wave_clus/archive/testing.zip';
    % If folders exists: delete
    if isdir(waveclusDir)
        file_delete(waveclusDir, 1, 3);
    end
    if isdir(waveclusTmpDir)
        file_delete(waveclusTmpDir, 1, 3);
    end
    % Create folder
	mkdir(waveclusTmpDir);
    % Download file
    zipFile = bst_fullfile(waveclusTmpDir, 'waveclus.zip');
    errMsg = gui_brainstorm('DownloadFile', url, zipFile, 'WaveClus download');
    if ~isempty(errMsg)
        error(['Impossible to download WaveClus:' errMsg]);
    end
    % Unzip file
    bst_progress('start', 'WaveClus', 'Installing WaveClus...');
    unzip(zipFile, waveclusTmpDir);
    % Get parent folder of the unzipped file
    diropen = dir(fullfile(waveclusTmpDir, 'MATLAB*'));
    idir = find([diropen.isdir] & ~cellfun(@(c)isequal(c(1),'.'), {diropen.name}), 1);
    newWaveclusDir = bst_fullfile(waveclusTmpDir, diropen(idir).name, 'wave_clus-testing');
    % Move WaveClus directory to proper location
    movefile(newWaveclusDir, waveclusDir);
    % Delete unnecessary files
    file_delete(waveclusTmpDir, 1, 3);
    % Add WaveClus to Matlab path
    addpath(genpath(waveclusDir));
end

