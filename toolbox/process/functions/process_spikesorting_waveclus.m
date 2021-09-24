function varargout = process_spikesorting_waveclus( varargin )
% PROCESS_SPIKESORTING_WAVECLUS:
% This process separates the initial raw signal to nChannels binary signals
% and performs spike sorting individually on each channel with the WaveClus
% spike-sorter. The spikes are clustered and assigned to individual
% neurons. The code ultimately produces a raw_elec(i)_spikes.mat
% for each electrode that can be used later for supervised spike-sorting.
% When all spikes on all electrodes have been clustered, all the spikes for
% each neuron is assigned to an events file in brainstorm format.
%
% USAGE: OutputFiles = process_spikesorting_waveclus('Run', sProcess, sInputs)

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
% Authors: Konstantinos Nasiotis, 2018-2019; Martin Cousineau, 2018

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'WaveClus';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Electrophysiology','Unsupervised Spike Sorting'};
    sProcess.Index       = 1201;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/e-phys/SpikeSorting';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 0;
    sProcess.options.spikesorter.Type   = 'text';
    sProcess.options.spikesorter.Value  = 'waveclus';
    sProcess.options.spikesorter.Hidden = 1;
    sProcess.options.binsize.Comment = 'Maximum RAM to use: ';
    sProcess.options.binsize.Type    = 'value';
    sProcess.options.binsize.Value   = {2, 'GB', 1};
    sProcess.options.paral.Comment = 'Parallel processing';
    sProcess.options.paral.Type    = 'checkbox';
    sProcess.options.paral.Value   = 0;
    sProcess.options.make_plots.Comment = 'Create images';
    sProcess.options.make_plots.Type    = 'checkbox';
    sProcess.options.make_plots.Value   = 0;
    % Channel name comment
    sProcess.options.make_plotshelp.Comment = '<I><FONT color="#777777">This saves images of the clustered spikes</FONT></I>';
    sProcess.options.make_plotshelp.Type    = 'label';
    % Options: Options
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
    if bst_iscompiled()
        bst_report('Error', sProcess, sInputs, 'This function is not available in the compiled version of Brainstorm.');
        return
    end
    
    if sProcess.options.binsize.Value{1} <= 0
        bst_report('Error', sProcess, sInputs, 'Invalid maximum amount of RAM specified.');
        return
    end
    
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
    
    % Prepare parallel pool, if requested
    if sProcess.options.paral.Value
        try
            poolobj = gcp('nocreate');
            if isempty(poolobj)
                parpool;
            end
        catch
            sProcess.options.paral.Value = 0;
            poolobj = [];
        end
    else
        poolobj = [];
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
        
        ChannelMat = in_bst_channel(sInputs(i).ChannelFile);
        numChannels = length(ChannelMat.Channel);
        sFiles = in_spikesorting_rawelectrodes(sInputs(i), ...
            sProcess.options.binsize.Value{1} * 1e9, ...
            sProcess.options.paral.Value);
        
        %%%%%%%%%%%%%%%%%%%%% Prepare output folder %%%%%%%%%%%%%%%%%%%%%%        
        outputPath = bst_fullfile(ProtocolInfo.STUDIES, fPath, [fBase '_waveclus_spikes']);
        
        % Clear if directory already exists
        if exist(outputPath, 'dir') == 7
            rmdir(outputPath, 's');
        end
        mkdir(outputPath);
        
        %%%%%%%%%%%%%%%%%%%%%%% Start the spike sorting %%%%%%%%%%%%%%%%%%%
        if sProcess.options.paral.Value
            bst_progress('start', 'Spike-sorting', 'Extracting spikes...');
        else
            bst_progress('start', 'Spike-sorting', 'Extracting spikes...', 0, numChannels);
        end
        
        % The Get_spikes saves the _spikes files at the current directory.
        previous_directory = pwd;
        cd(outputPath);

        if sProcess.options.paral.Value  
            parfor ielectrode = 1:numChannels
                if ismember(upper(ChannelMat.Channel(ielectrode).Type), {'EEG', 'SEEG'}) % Perform spike sorting only on the channels that are (S)EEG
                    Get_spikes(sFiles{ielectrode});
                end
            end
        else
            for ielectrode = 1:numChannels
                if ismember(upper(ChannelMat.Channel(ielectrode).Type), {'EEG', 'SEEG'})
                    Get_spikes(sFiles{ielectrode});
                end
                bst_progress('inc', 1);
            end
        end

        %%%%%%%%%%%%%%%%%%%%%% Do the clustering %%%%%%%%%%%%%%%%%%%%%%%%%%
        bst_progress('start', 'Spike-sorting', 'Clustering detected spikes...');
        
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
        
        % Do the clustering
        Do_clustering(1:numChannels, 'parallel', parallel, 'make_plots', make_plots);
        
        %%%%%%%%%%%%%%%%%%%%%  Create Brainstorm Events %%%%%%%%%%%%%%%%%%%
        bst_progress('text', 'Saving events file...');        
        cd(previous_directory);
        
        % Delete existing spike events
        process_spikesorting_supervised('DeleteSpikeEvents', sInputs(i).FileName);
        
        % ===== SAVE LINK FILE =====
        % Build output filename
        NewBstFilePrefix = bst_fullfile(ProtocolInfo.STUDIES, fPath, ['data_0ephys_wclus_' fBase]);
        NewBstFile = [NewBstFilePrefix '.mat'];
        iFile = 1;
        commentSuffix = '';
        while exist(NewBstFile, 'file') == 2
            iFile = iFile + 1;
            NewBstFile = [NewBstFilePrefix '_' num2str(iFile) '.mat'];
            commentSuffix = [' (' num2str(iFile) ')'];
        end
        % Build output structure
        DataMat = struct();
        DataMat.Comment     = ['WaveClus Spike Sorting' commentSuffix];
        DataMat.DataType    = 'raw';%'ephys';
        DataMat.Device      = 'waveclus';
        DataMat.Name        = NewBstFile;
        DataMat.Parent      = outputPath;
        DataMat.RawFile     = sInputs(i).FileName;
        DataMat.Spikes      = struct();
        % Build spikes structure
        spikes = dir(bst_fullfile(outputPath, 'raw_elec*_spikes.mat'));
        spikes = sort_nat({spikes.name});
        % New channelNames - Without any special characters.
        cleanChannelNames = str_remove_spec_chars({ChannelMat.Channel.Name});
        for iChannel = 1:length(cleanChannelNames)
            DataMat.Spikes(iChannel).Path = outputPath;
            DataMat.Spikes(iChannel).File = ['times_raw_elec_' cleanChannelNames{iChannel} '.mat'];
            if exist(bst_fullfile(outputPath, DataMat.Spikes(iChannel).File), 'file') ~= 2
                DataMat.Spikes(iChannel).File = '';
                disp(['The threshold was not crossed for Channel: ' ChannelMat.Channel(iChannel).Name]);
            end
            DataMat.Spikes(iChannel).Name = ChannelMat.Channel(iChannel).Name;
            DataMat.Spikes(iChannel).Mod  = 0;
        end
        % Save events file for backup
        SaveBrainstormEvents(DataMat, 'events_UNSUPERVISED.mat');
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
    
end


%% ===== DOWNLOAD AND INSTALL WAVECLUS =====
function downloadAndInstallWaveClus()
    waveclusDir = bst_fullfile(bst_get('BrainstormUserDir'), 'waveclus');
    waveclusTmpDir = bst_fullfile(bst_get('BrainstormUserDir'), 'waveclus_tmp');
    url = 'https://github.com/csn-le/wave_clus/archive/master.zip';
    
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
    
    % Check if the download was succesful and try again if it wasn't
    time_before_entering = clock;
    updated_time = clock;
    time_out = 60;% timeout within 60 seconds of trying to download the file
    
    % Keep trying to download until a timeout is reached
    while etime(updated_time, time_before_entering) <time_out && ~isempty(errMsg)
        % Try to download until the timeout is reached
        pause(0.1);
        errMsg = gui_brainstorm('DownloadFile', url, zipFile, 'WaveClus download');
        updated_time = clock;
    end
    % If the timeout is reached and there is still an error, abort
    if etime(updated_time, time_before_entering) >time_out && ~isempty(errMsg)
        error(['Impossible to download WaveClus.' 10 errMsg]);
    end
    % Unzip file
    bst_progress('start', 'WaveClus', 'Installing WaveClus...');
    unzip(zipFile, waveclusTmpDir);
    % Get parent folder of the unzipped file
    diropen = dir(fullfile(waveclusTmpDir, 'MATLAB*'));
    idir = find([diropen.isdir] & ~cellfun(@(c)isequal(c(1),'.'), {diropen.name}), 1);
    newWaveclusDir = bst_fullfile(waveclusTmpDir, diropen(idir).name, 'wave_clus-master');
    % Move WaveClus directory to proper location
    file_move(newWaveclusDir, waveclusDir);
    % Delete unnecessary files
    file_delete(waveclusTmpDir, 1, 3);
    % Add WaveClus to Matlab path
    addpath(genpath(waveclusDir));
end

function SaveBrainstormEvents(sFile, outputFile, eventNamePrefix)
    if nargin < 3
        eventNamePrefix = '';
    end

    numElectrodes = length(sFile.Spikes);
    iNewEvent = 0;
    events = struct();
    
    % Add existing non-spike events for backup
    DataMat = in_bst_data(sFile.RawFile);
    existingEvents = DataMat.F.events;
    for iEvent = 1:length(existingEvents)
        if ~process_spikesorting_supervised('IsSpikeEvent', existingEvents(iEvent).label)
            if iNewEvent == 0
                events = existingEvents(iEvent);
            else
                events(iNewEvent + 1) = existingEvents(iEvent);
            end
            iNewEvent = iNewEvent + 1;
        end
    end
    
    for iElectrode = 1:numElectrodes
        newEvents = process_spikesorting_supervised(...
            'CreateSpikeEvents', ...
            sFile.RawFile, ...
            sFile.Device, ...
            bst_fullfile(sFile.Parent, sFile.Spikes(iElectrode).File), ...
            sFile.Spikes(iElectrode).Name, ...
            0, eventNamePrefix);
        
        if iNewEvent == 0
            events = newEvents;
            iNewEvent = length(newEvents);
        else
            numNewEvents = length(newEvents);
            events(iNewEvent+1:iNewEvent+numNewEvents) = newEvents;
            iNewEvent = iNewEvent + numNewEvents;
        end
    end

    save(bst_fullfile(sFile.Parent, outputFile),'events');
end
