function varargout = process_spikesorting_ultramegasort2000( varargin )
% PROCESS_SPIKESORTING_ULTRAMEGASORT2000:
% This process separates the initial raw signal to nChannels binary signals
% and performs spike sorting individually on each channel with the
% UltraMegaSort2000 spike-sorter. The spikes are clustered and assigned to
% individual neurons. The code ultimately produces a raw_elec(i)_spikes.mat
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
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'UltraMegaSort2000';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = {'Electrophysiology','Unsupervised Spike Sorting'};
    sProcess.Index       = 1202;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/e-phys/SpikeSorting';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 0;
    % Spike sorter name
    sProcess.options.spikesorter.Type   = 'text';
    sProcess.options.spikesorter.Value  = 'ultramegasort2000';
    sProcess.options.spikesorter.Hidden = 1;
    % RAM limitation
    sProcess.options.binsize.Comment = 'Maximum RAM to use: ';
    sProcess.options.binsize.Type    = 'value';
    sProcess.options.binsize.Value   = {2, 'GB', 1};
    % Parallel processing
    sProcess.options.parallel.Comment = 'Parallel processing';
    sProcess.options.parallel.Type    = 'checkbox';
    sProcess.options.parallel.Value   = 0;
    % Use SSP/ICA
    sProcess.options.usessp.Comment = 'Apply the existing SSP/ICA projectors';
    sProcess.options.usessp.Type    = 'checkbox';
    sProcess.options.usessp.Value   = 1;
    % Separator
    sProcess.options.sep1.Type = 'label';
    sProcess.options.sep1.Comment = '<BR>';
    % === Low bound
    sProcess.options.highpass.Comment = 'Lower cutoff frequency:';
    sProcess.options.highpass.Type    = 'value';
    sProcess.options.highpass.Value   = {700,'Hz ',0};
    % === High bound
    sProcess.options.lowpass.Comment = 'Upper cutoff frequency:';
    sProcess.options.lowpass.Type    = 'value';
    sProcess.options.lowpass.Value   = {5000,'Hz ',0};
    % Separator
    sProcess.options.sep2.Type = 'label';
    sProcess.options.sep2.Comment = '<BR>';
    % Options: Options
    sProcess.options.edit.Comment = {'panel_spikesorting_options', 'UltraMegaSort2000 parameters: '};
    sProcess.options.edit.Type    = 'editpref';
    sProcess.options.edit.Value   = [];
    % Label: Reset options
    sProcess.options.edit_help.Comment = '<I><FONT color="#777777">To restore default options: re-install the ultramegasort plugin.</FONT></I>';
    sProcess.options.edit_help.Type    = 'label';
    % Label: Warning that pre-spikesorted events will be overwritten
    sProcess.options.warning.Comment = '<BR><B><FONT color="#FF0000">Warning: Existing spike events will be overwritten</FONT></B>';
    sProcess.options.warning.Type    = 'label';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput) %#ok<DEFNU>
    OutputFiles = {};

    % ===== DEPENDENCIES =====
    % Not available in the compiled version
    if bst_iscompiled()
        bst_report('Error', sProcess, sInput, 'This function is not available in the compiled version of Brainstorm.');
        return
    end
    % Load plugin
    [isInstalled, errMsg] = bst_plugin('Install', 'ultramegasort2000');
    if ~isInstalled
        error(errMsg);
    end

    % ===== OPTIONS =====
    % Get option: bin size
    BinSize = sProcess.options.binsize.Value{1};
    if (BinSize <= 0)
        bst_report('Error', sProcess, sInput, 'Invalid maximum amount of RAM specified.');
        return
    end
    % Get other options
    isParallel = sProcess.options.parallel.Value;
    UseSsp = sProcess.options.usessp.Value;
    LowPass = sProcess.options.lowpass.Value{1}(1);
    HighPass = sProcess.options.highpass.Value{1}(1);

    % ===== LOAD INPUTS =====
    % Get protocol info
    ProtocolInfo = bst_get('ProtocolInfo');
    BrainstormTmpDir = bst_get('BrainstormTmpDir');
    % File path
    [fPath, fBase] = bst_fileparts(file_fullpath(sInput.FileName));
    % Remove "data_0raw" or "data_" tag
    if (length(fBase) > 10 && strcmp(fBase(1:10), 'data_0raw_'))
        fBase = fBase(11:end);
    elseif (length(fBase) > 5) && strcmp(fBase(1:5), 'data_')
        fBase = fBase(6:end);
    end
    
    % Load input files
    DataMat = in_bst_data(sInput.FileName, 'F');
    sFile = DataMat.F;
    % Check filtering frequencies
    nyq = floor(sFile.prop.sfreq/2);
    if (LowPass >= nyq)
        bst_report('Error', sProcess, sInput, ['Higher cutoff frequency must be lower than Nyquist frequency (' num2str(nyq) ' Hz).']);
        return;
    elseif (HighPass >= LowPass) 
        bst_report('Error', sProcess, sInput, 'Higher cutoff frequency must be lower lower cutoff frequency.');
        return;
    end
    % Load channel file
    ChannelMat = in_bst_channel(sInput.ChannelFile);
    numChannels = length(ChannelMat.Channel);
    % Demultiplex channels
    demultiplexDir = bst_fullfile(BrainstormTmpDir, 'Unsupervised_Spike_Sorting', ProtocolInfo.Comment, sInput.FileName);
    elecFiles = out_demultiplex(sInput.FileName, sInput.ChannelFile, demultiplexDir, UseSsp, BinSize * 1e9, isParallel);
    
    % ===== OUTPUT FOLDER =====
    outputPath = bst_fullfile(fPath, [fBase '_ums2k_spikes']);
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
        	error(['Could not remove spikes folder: ' 10 outputPath 10 ' Make sure this folder is not open in another program.'])
        end
    end
    % Create output folder
    mkdir(outputPath);
    

    % ===== SPIKE SORTING =====
    cd(outputPath);
    if isParallel
        bst_progress('start', 'Spike-sorting', 'Extracting spikes...');
        parfor ielectrode = 1:numChannels
            do_UltraMegaSorting(elecFiles{ielectrode}, sFile, LowPass, HighPass, sFile.prop.sfreq);
        end
    else
        bst_progress('start', 'Spike-sorting', 'Extracting spikes...', 0, numChannels);
        for ielectrode = 1:numChannels
            do_UltraMegaSorting(elecFiles{ielectrode}, sFile, LowPass, HighPass, sFile.prop.sfreq);
            bst_progress('inc', 1);
        end
    end
    % Restore current folder
    cd(previous_directory);

    
    % ===== IMPORT EVENTS =====
    bst_progress('start', 'UltraMegaSort2000', 'Gathering spiking events...');
    % Delete existing spike events
    panel_spikes('DeleteSpikeEvents', sInput.FileName);

    % Build output filename
    NewBstFilePrefix = bst_fullfile(fPath, ['data_0ephys_ums2k_' fBase]);
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
    DataMat.Comment     = ['UltraMegaSort2000 Spike Sorting' commentSuffix];
    DataMat.DataType    = 'raw';
    DataMat.Device      = 'ultramegasort2000';
    DataMat.Name        = file_short(NewBstFile);
    DataMat.Parent      = file_short(outputPath);
    DataMat.RawFile     = sInput.FileName;
    DataMat.Spikes      = struct();
    % Build spikes structure
    spikes = dir(bst_fullfile(outputPath, 'times_raw_elec*.mat'));
    spikes = sort_nat({spikes.name});
    for iSpike = 1:length(spikes)
        DataMat.Spikes(iSpike).Path = file_short(outputPath);
        DataMat.Spikes(iSpike).File = spikes{iSpike};
        if exist(bst_fullfile(outputPath, DataMat.Spikes(iSpike).File), 'file') ~= 2
            DataMat.Spikes(iSpike).File = '';
        end
        DataMat.Spikes(iSpike).Name = ChannelMat.Channel(iSpike).Name;
        DataMat.Spikes(iSpike).Mod  = 0;
    end
    
    % Save events file for backup
    SaveBrainstormEvents(DataMat, 'events_UNSUPERVISED.mat');

    % Add history field
    DataMat = bst_history('add', DataMat, 'import', ['Link to unsupervised electrophysiology files: ' outputPath]);
    % Save file on hard drive
    bst_save(NewBstFile, DataMat, 'v6');
    % Add file to database
    db_add_data(sInput.iStudy, file_short(NewBstFile), DataMat);
    % Return new file
    OutputFiles{end+1} = NewBstFile;

    % ===== UPDATE DATABASE =====
    % Update links
    db_links('Study', sInput.iStudy);
    panel_protocols('UpdateNode', 'Study', sInput.iStudy);
end


%% ===== SAVE BRAINSTORM EVENTS =====
function SaveBrainstormEvents(SpikeMat, outputFile, eventNamePrefix)
    if nargin < 3
        eventNamePrefix = '';
    end

    numElectrodes = length(SpikeMat.Spikes);
    iNewEvent = 0;
    events = struct();
    
    % Add existing non-spike events for backup
    DataMat = in_bst_data(SpikeMat.RawFile);
    existingEvents = DataMat.F.events;
    for iEvent = 1:length(existingEvents)
        if ~panel_spikes('IsSpikeEvent', existingEvents(iEvent).label)
            if iNewEvent == 0
                events = existingEvents(iEvent);
            else
                events(iNewEvent + 1) = existingEvents(iEvent);
            end
            iNewEvent = iNewEvent + 1;
        end
    end
    
    for iElectrode = 1:numElectrodes
        newEvents = panel_spikes(...
            'CreateSpikeEvents', ...
            SpikeMat.RawFile, ...
            SpikeMat.Device, ...
            bst_fullfile(file_fullpath(SpikeMat.Parent), SpikeMat.Spikes(iElectrode).File), ...
            SpikeMat.Spikes(iElectrode).Name, ...
            1, eventNamePrefix);
        
        if iNewEvent == 0
            events = newEvents;
            iNewEvent = length(newEvents);
        else
            numNewEvents = length(newEvents);
            events(iNewEvent+1:iNewEvent+numNewEvents) = newEvents;
            iNewEvent = iNewEvent + numNewEvents;
        end
    end

    save(bst_fullfile(file_fullpath(SpikeMat.Parent), outputFile),'events');
end


%% ===== ULTRAMEGA SORTING =====
function do_UltraMegaSorting(electrodeFile, sFile, LowPass, HighPass, Fs)
    [path, filename] = fileparts(electrodeFile);
    % Apply BST bandpass filter
    try
        DataMat = load(electrodeFile, 'data');
        filtered_data = bst_bandpass_hfilter(DataMat.data', Fs, HighPass, LowPass, 0, 0);
    catch e
        error(['Frequency filtering failed, try with a different frequency band.' 10 'Error: ' e.message]);
    end
    % Convert to a column vector in a cell array
    filtered_data = {filtered_data'};
    % Run spike sorting
    try
        spikes = ss_default_params(sFile.prop.sfreq);
        spikes = ss_detect(filtered_data,spikes);
        spikes = ss_align(spikes);
        spikes = ss_kmeans(spikes);
        spikes = ss_energy(spikes);
        spikes = ss_aggregate(spikes);
        save(['times_' filename '.mat'], 'spikes')
    catch e
        % If an error occurs, just don't create the spike file.
        clean_label = strrep(filename,'raw_elec_','');
        disp(e);
        disp(['Warning: Spiking failed on electrode ' clean_label '. Skipping this electrode.']);
    end
end
