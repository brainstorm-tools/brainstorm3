function varargout = process_noise_correlation( varargin )
% process_noise_correlation: Computes noise Correlation of all neurons (nxn)
% 
% USAGE:    sProcess = process_noise_correlation('GetDescription')
%        OutputFiles = process_noise_correlation('Run', sProcess, sInput)

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
% Authors: Konstantinos Nasiotis, 2018

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
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/e-phys/functions#Noise_Correlation';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'EEG';
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
        time_window = sProcess.options.timewindow.Value{1};
    else
        bst_report('Error', sProcess, sInputs, 'Check window inputs');
        return;
    end
    
    tfOPTIONS.TimeVector = in_bst(sInputs(1).FileName, 'Time');

    
    % === OUTPUT STUDY ===
    % Get output study
    [tmp, iStudy] = bst_process('GetOutputStudy', sProcess, sInputs);
    tfOPTIONS.iTargetStudy = iStudy;
    
   
    % Get channel file
    sChannel = bst_get('ChannelForStudy', iStudy);
    % Load channel file
    ChannelMat = in_bst_channel(sChannel.FileName);
   
    
    %% Get only the unique neurons along all of the trials
    nTrials = length(sInputs);
    
    if nTrials == 1
        bst_report('Error', sProcess, sInputs, 'More trials are needed for Noise Correlation computation.');
        return;
    end
    
    % This loads the information from ALL TRIALS on ALL_TRIALS_files
    % (Shouldn't create a memory problem).
    ALL_TRIALS_files = struct();
    for iFile = 1:nTrials
        DataMat = in_bst(sInputs(iFile).FileName);
        ALL_TRIALS_files(iFile).Events = DataMat.Events;
    end
    
    %% Create a cell that holds all of the labels and one for the unique labels
    % This will be used to take the averages using the appropriate indices
    uniqueNeurons = {}; % Unique neuron labels (each trial might have different number of neurons). We need everything that appears.
    for iFile = 1:nTrials
        for iEvent = 1:length(ALL_TRIALS_files(iFile).Events)
            if process_spikesorting_supervised('IsSpikeEvent', ALL_TRIALS_files(iFile).Events(iEvent).label) && any(ALL_TRIALS_files(iFile).Events(iEvent).times > time_window(1) & ALL_TRIALS_files(iFile).Events(iEvent).times < time_window(2))
                uniqueNeurons{end+1} = ALL_TRIALS_files(iFile).Events(iEvent).label;
            end
        end
    end
    uniqueNeurons = unique(uniqueNeurons,'stable');
    
    
    %% Sort the neurons based on the array they belong to.
    % The visualization is greatly affected by the order of the neurons.
    uniqueNeurons = sort_nat(uniqueNeurons);
    
    
    %% === START COMPUTATION ===
    protocol   = bst_get('ProtocolInfo');
    
    
    %% Gather the spikes
    all_binned = zeros(length(sInputs), length(uniqueNeurons));
    for iFile = 1:length(sInputs)
        
        trial = load(fullfile(protocol.STUDIES, sInputs(iFile).FileName), 'Events');
        
        for iNeuron = 1:length(uniqueNeurons)
            for iEvent = 1:length(trial.Events)
                
                if strcmp(trial.Events(iEvent).label, uniqueNeurons{iNeuron})
                    all_binned(iFile, iNeuron) = length(trial.Events(iEvent).times(trial.Events(iEvent).times > time_window(1) & trial.Events(iEvent).times < time_window(2)));
                    break
                end
                
            end
        end
        
    end

    
    %% Subtract mean from each neuron (this is needed for noise correlation)
    all_binned = all_binned - repmat(mean(all_binned), size(all_binned,1),1);
    
    
    %% Compute the Correlation for nxn Neurons
    noise_correlation = zeros(1,size(all_binned, 2), size(all_binned, 2));
    
    opts.normalize      = true;
    opts.nTrials        = 1;
    opts.flagStatistics = 0;
    connectivity = bst_correlation(all_binned', all_binned', opts);
    noise_correlation(1,:,:) = connectivity; 
    
    %% Get list of unique conditions for output label
    conditions = unique({sInputs.Condition});
    condition = [];
    for iCond = 1:length(conditions)
        if iCond > 1
            condition = [condition ', '];
        end
        condition = [condition conditions{iCond}];
    end

    %% Build the output file
    
    tfOPTIONS.ParentFiles = {sInputs.FileName};

    % Prepare output file structure
    FileMat = db_template('timefreqmat');
    FileMat.TF     = noise_correlation;
    FileMat.Time   = 1:length(uniqueNeurons);
    FileMat.TFmask = true(size(noise_correlation, 2), size(noise_correlation, 3));
    FileMat.Freqs  = 1:size(FileMat.TF, 3);
    FileMat.Comment = ['Noise Correlation: ' condition];
    FileMat.DataType = 'data';
    FileMat.RowNames = {'nxn Noise Correlation'};
    FileMat.NeuronNames = uniqueNeurons;
    FileMat.Measure = 'power';
    FileMat.Method = 'morlet';
    FileMat.DataFile = []; % Leave blank because multiple parents
    FileMat.Options = tfOPTIONS;
    
    % Add history field
	FileMat = bst_history('add', FileMat, 'compute', ...
        ['Noise correlation: [' num2str(time_window(1)) ', ' num2str(time_window(2)) '] ms']);

    % Get output study
    sTargetStudy = bst_get('Study', iStudy);
    % Output filename
    FileName = bst_process('GetNewFilename', bst_fileparts(sTargetStudy.FileName), 'timefreq_noise_correlation');
    OutputFiles = {FileName};
    % Save output file and add to database
    bst_save(FileName, FileMat, 'v6');
    db_add_data(tfOPTIONS.iTargetStudy, FileName, FileMat);
    
    % Display report to user
    bst_report('Info', sProcess, sInputs, 'Success');
    disp('BST> process_noise_Correlation: Success');
end




