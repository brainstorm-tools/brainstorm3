function varargout = process_noise_Correlation( varargin )
% process_noise_Correlation: Computes noise Correlation of all neurons (nxn)
% 
% USAGE:    sProcess = process_rasterplot_Nas('GetDescription')
%        OutputFiles = process_rasterplot_Nas('Run', sProcess, sInput)

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Konstantinos Nasiotis, 2017

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Noise Correlation';
    sProcess.FileTag     = 'NoiseCorrelation';
    sProcess.Category    = 'custom';
    sProcess.SubGroup    = 'Electrophysiology';
    sProcess.Index       = 1508;
    sProcess.Description = 'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3586814/';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Time window
    sProcess.options.timewindow.Comment = 'Time window:';
    sProcess.options.timewindow.Type    = 'range';
    sProcess.options.timewindow.Value    = {[0, 0.200],'ms',[]};
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
    
    tfOPTIONS.Method = strProcess;
    % Add other options

    if isfield(sProcess.options, 'sensortypes')
        tfOPTIONS.SensorTypes = sProcess.options.sensortypes.Value;
    else
        tfOPTIONS.SensorTypes = [];
    end
    
    % Time window
    if isfield(sProcess.options, 'timewindow') && ~isempty(sProcess.options.timewindow) && ~isempty(sProcess.options.timewindow.Value)...
                                               && iscell(sProcess.options.timewindow.Value) && (sProcess.options.timewindow.Value{1}(1) < sProcess.options.timewindow.Value{1}(2))
        time_window = sProcess.options.timewindow.Value{1}; % [0, 0.2]
    else
        bst_report('Error', sProcess, sInputs, 'Check window inputs');
        return;
    end
    
    
    % Output
    if isfield(sProcess.options, 'avgoutput') && ~isempty(sProcess.options.avgoutput) && ~isempty(sProcess.options.avgoutput.Value)
        if sProcess.options.avgoutput.Value
            tfOPTIONS.Output = 'average';
        else
            tfOPTIONS.Output = 'all';
        end
    end
    
    tfOPTIONS.TimeVector = in_bst(sInputs(1).FileName, 'Time');

    
    % === OUTPUT STUDY ===
    % Get output study
    [~, iStudy, ~] = bst_process('GetOutputStudy', sProcess, sInputs);
    tfOPTIONS.iTargetStudy = iStudy;
    
   
    % Get channel file
    sChannel = bst_get('ChannelForStudy', iStudy);
    % Load channel file
    ChannelMat = in_bst_channel(sChannel.FileName);
   
    
    %% Get only the unique neurons along all of the trials
    nTrials = length(sInputs);
    
    % This loads the information from ALL TRIALS on ALL_TRIALS_files
    % (Shouldn't create a memory problem).
    ALL_TRIALS_files = struct();
    for iFile = 1:nTrials
        ALL_TRIALS_files(iFile).a = in_bst(sInputs(iFile).FileName);
    end
    
    % Create a cell that holds all of the labels and one for the unique labels
    % This will be used to take the averages using the appropriate indices
    uniqueNeurons = {}; % Unique neuron labels (each trial might have different number of neurons). We need everything that appears.
    for iFile = 1:nTrials
        for iEvent = 1:length(ALL_TRIALS_files(iFile).a.Events)
            if strfind(ALL_TRIALS_files(iFile).a.Events(iEvent).label, 'Spikes Channel') && sum(ALL_TRIALS_files(iFile).a.Events(iEvent).times>time_window(1) & ALL_TRIALS_files(iFile).a.Events(iEvent).times<time_window(2))~=0
                uniqueNeurons{end+1} = ALL_TRIALS_files(iFile).a.Events(iEvent).label;
            end
        end
    end
    uniqueNeurons = unique(uniqueNeurons,'stable');
    

    
    %% Sort the neurons based on the array they belong to.
    % The visualization is greatly affected by the order of the neurons.
    % TODO - this is hardcoded for channels names "Raw 1" etc. (String then space then number)
    
    %     uniqueNeurons = sort(uniqueNeurons)';
    
    channel_of_neurons = zeros(length(uniqueNeurons),1);
    for iNeuron = 1:length(uniqueNeurons)
        separate_strings = strsplit(uniqueNeurons{iNeuron})';
        channel_of_neurons(iNeuron) = str2double(separate_strings{4});
    end
    
    [~, ii] = sort(channel_of_neurons);
    
    uniqueNeurons_new = cell(length(uniqueNeurons),1);
    
    for iNeuron = 1:length(uniqueNeurons)
        uniqueNeurons_new{iNeuron} = uniqueNeurons{ii(iNeuron)};
    end
    
    
    uniqueNeurons = uniqueNeurons_new; clear uniqueNeurons_new ii
    
    
    
    %% === START COMPUTATION ===
    protocol   = bst_get('ProtocolInfo');
    
    
    %% Gather the spikes
    all_binned = zeros(length(sInputs), length(uniqueNeurons));
    for iFile = 1:length(sInputs)
        
        trial = load(fullfile(protocol.STUDIES, sInputs(iFile).FileName));
        events = trial.Events;
        
        for iNeuron = 1:length(uniqueNeurons)
            for iEvent = 1:length(events)
                
                if strcmp(events(iEvent).label, uniqueNeurons{iNeuron})
                    
                    all_binned(iFile, iNeuron) = length(events(iEvent).times(events(iEvent).times>time_window(1) & events(iEvent).times<time_window(2)));
                    
                    break
                end
            end
            
        end
        
    end

    
    %% Subtract mean from each neuron (this is needed for noise correlation)
    
    all_binned = all_binned - mean(all_binned);
    
    
    %% Compute the Pearson Correlation for nxn Neurons
    noise_correlation = zeros(1,size(all_binned, 2), size(all_binned, 2));
    noise_correlation(1,:,:) = corr(all_binned, all_binned);
    
%     figure;
%     imagesc(squeeze(noise_correlation))
%     
%     
%     myColorMap = jet(256);
%     myColorMap(1,:) = 1;
%     colormap(myColorMap);
%     colorbar
        
    %% Build the output file
    
    tfOPTIONS.ParentFiles = {sInputs.FileName};

    % Prepare output file structure
    FileMat.TF     = noise_correlation;
    FileMat.Time   = 1:length(uniqueNeurons); % CHECK THIS OUT - IT WILL NOT GO ALL THE WAY BUT IT WILL HAVE THE CORRECT NUMBER OF BINS
    FileMat.TFmask = true(size(noise_correlation, 2), size(noise_correlation, 3));
    FileMat.Freqs  = 1:size(FileMat.TF, 3);
    FileMat.Std = [];
    FileMat.Comment = ['Noise Correlation'];
%     FileMat.Comment = ['Noise Correlation: ' linkToRaw.Comment];
    FileMat.DataType = 'data';
    FileMat.TimeBands = [];
    FileMat.RefRowNames = [];
    FileMat.RowNames = {'nxn Noise Correlation'};
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
    FileMat.DisplayUnits = [];
    FileMat.Options = tfOPTIONS;
    FileMat.History = [];
    

    
    
% % % % % %         % Add history field
% % % % % %         DataMat = bst_history('add', DataMat, 'import', ['Link to unsupervised electrophysiology files: ' outputPath]);


    % Get output study
    sTargetStudy = bst_get('Study', iStudy);
    % Output filename
    FileName = bst_process('GetNewFilename', bst_fileparts(sTargetStudy.FileName), 'timefreq_noiseCorrelation');
    OutputFiles = {FileName};
    % Save output file and add to database
    bst_save(FileName, FileMat, 'v6');
    db_add_data(tfOPTIONS.iTargetStudy, FileName, FileMat);
    

    
    
    % Display report to user
    bst_report('Info', sProcess, sInputs, 'Success');
    disp('BST> process_noise_Correlation: Success');
end




