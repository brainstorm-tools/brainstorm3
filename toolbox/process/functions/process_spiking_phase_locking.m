function varargout = process_spiking_phase_locking( varargin )
% PROCESS_SPIKING_PHASE_LOCKING: Computes the phase locking of spikes on
% the timeseries.

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
    sProcess.Comment     = 'Spiking Phase Locking';
    sProcess.FileTag     = 'phaseLocking';
    sProcess.Category    = 'custom';
    sProcess.SubGroup    = {'Peyrache Lab', 'Ripples'};
    sProcess.Index       = 2223;
    sProcess.Description = 'www.peyrachelab.com';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Options: Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'EEG';
    % Band-pass filter
    sProcess.options.bandpass.Comment = 'Frequency band (0=ignore): ';
    sProcess.options.bandpass.Type    = 'range';
    sProcess.options.bandpass.Value   = {[600, 800], 'Hz', 1};
    % Phase Binning
    sProcess.options.phaseBin.Comment = 'Phase Binning: ';
    sProcess.options.phaseBin.Type    = 'value';
    sProcess.options.phaseBin.Value   = {30, 'degrees', 0};
    % Options: Parallel Processing
    sProcess.options.paral.Comment = 'Parallel processing';
    sProcess.options.paral.Type    = 'checkbox';
    sProcess.options.paral.Value   = 1;
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
    if isfield(sProcess.options, 'sensortypes')
        tfOPTIONS.SensorTypes = sProcess.options.sensortypes.Value;
    else
        tfOPTIONS.SensorTypes = [];
    end
    
    % Bin size
    if isfield(sProcess.options, 'phaseBin') && ~isempty(sProcess.options.phaseBin) && ~isempty(sProcess.options.phaseBin.Value) && iscell(sProcess.options.phaseBin.Value) && sProcess.options.phaseBin.Value{1} > 0
        bin_size = sProcess.options.phaseBin.Value{1};
    else
        bst_report('Error', sProcess, sInputs, 'Positive phase bin size required.');
        return;
    end

    if sProcess.options.paral.Value
        compute_in_parallel = true;
    else
        do_paralell = false;
    end
    
   
    % === OUTPUT STUDY ===
    % Get output study
    [tmp, iStudy] = bst_process('GetOutputStudy', sProcess, sInputs);
    tfOPTIONS.iTargetStudy = iStudy;


    % Get channel file
    sChannel = bst_get('ChannelForStudy', iStudy);
    % Load channel file
    ChannelMat = in_bst_channel(sChannel.FileName);

    %% Select which channels to compute the spiking phase on
    iSelectedChannels = 3:12;
    
    nChannels = length(iSelectedChannels);
    
    %% Get only the unique neurons along all of the trials
    progressPos = bst_progress('get');
    bst_progress('text', 'Detecting unique neurons on all trials...');
    
    nTrials = length(sInputs);

    % I get the files outside of the parfor so it won't fail.
    % This loads the information from ALL TRIALS on ALL_TRIALS_files
    % (Shouldn't create a memory problem).
    ALL_TRIALS_files = struct();
    for iFile = 1:nTrials
        DataMat = in_bst(sInputs(iFile).FileName);
        ALL_TRIALS_files(iFile).Events = DataMat.Events;
        progressPos = bst_progress('set', iFile/nTrials*100);
    end

    
    % ADD AN IF STATEMENT HERE TO GENERALIZE ON ALL EVENTS, NOT JUST SPIKES
    % THE FUNCTION SHOULD BE MODIFIED TO ENABLE INPUT OF THE EVENTS FROM
    % THE USER
    
    % Create a cell that holds all of the labels and one for the unique labels
    % This will be used to take the averages using the appropriate indices
    labelsForDropDownMenu = {}; % Unique neuron labels (each trial might have different number of neurons). We need everything that appears.
    for iFile = 1:nTrials
        for iEvent = 1:length(ALL_TRIALS_files(iFile).Events)
            if process_spikesorting_supervised('IsSpikeEvent', ALL_TRIALS_files(iFile).Events(iEvent).label)
                labelsForDropDownMenu{end+1} = ALL_TRIALS_files(iFile).Events(iEvent).label;
            end
        end
    end
    labelsForDropDownMenu = unique(labelsForDropDownMenu,'stable');
    labelsForDropDownMenu = sort_nat(labelsForDropDownMenu);
    
    %% Accumulate the phases that each neuron fired upon
    nBins = round(360/sProcess.options.phaseBin.Value{1});
    all_phases = zeros(length(labelsForDropDownMenu), nChannels, nBins);
    
    
    [temp, EDGES] = histcounts(-pi:0.01:pi, nBins-1);
    
    progressPos = bst_progress('set',0);
    bst_progress('text', 'Accumulating spiking phases for each neuron...');
    for iFile = 1:nTrials
        DataMat = in_bst(sInputs(iFile).FileName);
        events = DataMat.Events;
        
        % Filter the data based on the user input
        sFreq = round(1/diff(DataMat.Time(1:2)));
        [filtered_F, FiltSpec, Messages] = process_bandpass('Compute', DataMat.F, sFreq, sProcess.options.bandpass.Value{1}(1), sProcess.options.bandpass.Value{1}(2));

        %Extract phase
        angle_filtered_F = angle(hilbert(filtered_F(iSelectedChannels,:)));

        for iNeuron = 1:length(labelsForDropDownMenu)
            iEvent_Neuron = find(ismember({events.label},labelsForDropDownMenu{iNeuron}));
            
            if ~isempty(iEvent_Neuron)
                % Get the index of the closest timeBin
                [temp, iClosest] = histc(events(iEvent_Neuron).times,DataMat.Time);
                
                % Function hist fails to give correct output when a single
                % spike occurs. Taking care of it here
                if length(iClosest) == 1
                    single_spike_entry = zeros(nChannels, nBins);
                    [temp, iBin] = histc(angle_filtered_F(:,iClosest), EDGES); 
                    for iChannel = 1:nChannels
                        single_spike_entry(iChannel, iBin(iChannel)) = 1;
                    end
                    all_phases(iNeuron,:,:) = single_spike_entry;
                else
                    [all_phases_single_neuron, bins] = hist(angle_filtered_F(:,iClosest)', EDGES);
                    all_phases(iNeuron,:,:) = all_phases_single_neuron';
                end
                
            end
        end
        bst_progress('set', round(iFile / nTrials * 100));
    end
    
    % Instead of the edges, keep only the mid-point of the bins
    bins = bins(1:end-1) + diff(bins)/2;
    
    %% Plots
%     %% This is what the final call to the phases should print
%     iNeuron = 15;
%     iChannel = 3;
%     
%     w = squeeze(all_phases(iNeuron, iChannel, :));
%     
%     single_neuron_and_channel_phase = [];
%     for iBin = 1:nBins
%         single_neuron_and_channel_phase = [single_neuron_and_channel_phase ;ones(w(iBin),1)*EDGES(iBin)];
%     end
%         
%     [pval_rayleigh z] = circ_rtest(single_neuron_and_channel_phase);
%     [pval_omnibus m] = circ_otest(single_neuron_and_channel_phase);
%     [mean_value, upper_limit, lower_limit] = circ_mean(single_neuron_and_channel_phase);
%     mean_value_degrees = mean_value * (180/pi);
%     
% %     figure(1); polarhistogram(single_neuron_and_channel_phase, nBins,'FaceColor','blue','FaceAlpha',.3, 'Normalization','probability');
% % %     figure(1); polarhistogram(single_neuron_and_channel_phase,12,'FaceColor','red','FaceAlpha',.3);
% %     pax = gca;
% %     pax.ThetaAxisUnits = 'radians';
% %     title({['Rayleigh test p=' num2str(pval_rayleigh)], ['Omnibus test p=' num2str(pval_omnibus)], ['Preferred phase: ' num2str(mean_value_degrees) '^o']})
% % %     rlim([0 1])
% 
%     figure(2);
%     circ_plot(single_neuron_and_channel_phase,'hist',[], nBins,true,true,'linewidth',2,'color','r');
%     pax = gca;
%     title({['Rayleigh test p=' num2str(pval_rayleigh)], ['Omnibus test p=' num2str(pval_omnibus)], ['Preferred phase: ' num2str(mean_value_degrees) '^o']})
    
    %% Build the output file
    tfOPTIONS.ParentFiles = {sInputs.FileName};

    % Prepare output file structure
    FileMat.TF = all_phases;
    FileMat.Time = 1:nBins;
    FileMat.TFmask = true(size(raster, 2), size(raster, 3));
    FileMat.Freqs = 1:size(FileMat.TF, 3);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % This is added here - Let's hear it from Francois
    FileMat.Bins = bins;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    FileMat.Std = [];
    FileMat.Comment = ['Raster Plot: ' uniqueComments{iList}];
    FileMat.DataType = 'data';
    FileMat.TimeBands = [];
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
    FileMat.DisplayUnits = 'Spikes';
    FileMat.Options = tfOPTIONS;
    FileMat.History = [];

    % Add history field
    FileMat = bst_history('add', FileMat, 'compute', ...
        ['Raster Plot per neuron']);


    % Get output study
    sTargetStudy = bst_get('Study', iStudy);
    % Output filename
    FileName = bst_process('GetNewFilename', bst_fileparts(sTargetStudy.FileName), 'timefreq_rasterplot');
    OutputFiles = {FileName};
    % Save output file and add to database
    bst_save(FileName, FileMat, 'v6');
    db_add_data(tfOPTIONS.iTargetStudy, FileName, FileMat);
        
    % Display report to user
    bst_report('Info', sProcess, sInputs, 'Success');
    disp('BST> process_timefreq: Success');
    
    
    
    
    
    
    
    
    
end







function downloadAndInstallCST()
    % Downloads and install circular statistics toolbox on the temp folder
    CSTDir = bst_fullfile(bst_get('BrainstormUserDir'), 'CST');
    CSTTmpDir = bst_fullfile(bst_get('BrainstormUserDir'), 'CST_tmp');
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%
    % THIS REFUSES TO DOWNLOAD
    url = 'https://www.jstatsoft.org/index.php/jss/article/downloadSuppFile/v031i10/CircStat.zip';
    %%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    % If folders exists: delete
    if isdir(CSTDir)
        file_delete(CSTDir, 1, 3);
    end
    if isdir(CSTTmpDir)
        file_delete(CSTTmpDir, 1, 3);
    end
    % Create folder
	mkdir(CSTTmpDir);
    % Download file
    zipFile = bst_fullfile(CSTTmpDir, 'CST.zip');
    errMsg = gui_brainstorm('DownloadFile', url, zipFile, 'CST download');
    
    % Check if the download was succesful and try again if it wasn't
    time_before_entering = clock;
    updated_time = clock;
    time_out = 60;% timeout within 60 seconds of trying to download the file
    
    % Keep trying to download until a timeout is reached
    while etime(updated_time, time_before_entering) <time_out && ~isempty(errMsg)
        % Try to download until the timeout is reached
        pause(0.1);
        errMsg = gui_brainstorm('DownloadFile', url, zipFile, 'CST download');
        updated_time = clock;
    end
    % If the timeout is reached and there is still an error, abort
    if etime(updated_time, time_before_entering) >time_out && ~isempty(errMsg)
        error(['Impossible to download CST.' 10 errMsg]);
    end
    
    % Unzip file
    bst_progress('start', 'CST', 'Installing CST...');
    unzip(zipFile, CSTTmpDir);
    % Get parent folder of the unzipped file
    diropen = dir(CSTTmpDir);
    idir = find([diropen.isdir] & ~cellfun(@(c)isequal(c(1),'.'), {diropen.name}), 1);
    newCSTDir = bst_fullfile(CSTTmpDir, diropen(idir).name);
    % Move CST directory to proper location
    file_move(newCSTDir, CSTDir);
    % Delete unnecessary files
    file_delete(CSTTmpDir, 1, 3);
end




