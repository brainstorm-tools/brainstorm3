function varargout = process_noise_correlation( varargin )
% process_noise_correlation: Computes noise Correlation of all neurons (nxn)
% 
% USAGE:    sProcess = process_noise_correlation('GetDescription')
%        OutputFiles = process_noise_correlation('Run', sProcess, sInput)

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
% Authors: Konstantinos Nasiotis, 2018
%          Francois Tadel, 2022

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Noise correlation';
    sProcess.FileTag     = 'NoiseCorrelation';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Electrophysiology';
    sProcess.Index       = 1215;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/e-phys/functions#Noise_correlation';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 2;
    % Time window
    sProcess.options.timewindow.Comment = 'Time window:';
    sProcess.options.timewindow.Type    = 'range';
    sProcess.options.timewindow.Value   = {[0, 0.200],'ms',[]};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs)
    % Initialize returned values
    OutputFiles = {};
    % Get options
    TimeWindow = sProcess.options.timewindow.Value{1};
    
    % ===== LOAD INPUTS =====
    % Loads the events information, and get the list of unique neurons
    DataMats = cell(1, length(sInputs));
    uniqueNeurons = {};  % Unique neuron labels (each trial might have different number of neurons). We need everything that appears.
    for iFile = 1:length(sInputs)
        % Load file
        DataMats{iFile} = in_bst_data(sInputs(iFile).FileName, 'Events');
        % Find unique neurons
        for iEvent = 1:length(DataMats{iFile}.Events)
            if panel_spikes('IsSpikeEvent', DataMats{iFile}.Events(iEvent).label) && any(DataMats{iFile}.Events(iEvent).times > TimeWindow(1) & DataMats{iFile}.Events(iEvent).times < TimeWindow(2))
                uniqueNeurons{end+1} = DataMats{iFile}.Events(iEvent).label;
            end
        end
    end
    % If no neuron was found
    if isempty(uniqueNeurons)
        bst_report('Error', sProcess, sCurrentInputs(1), 'No neurons/spiking events detected.');
        return;
    end
    % Sort the neurons based on the array they belong to.
    % The visualization is greatly affected by the order of the neurons.
    uniqueNeurons = unique(uniqueNeurons, 'stable');
    uniqueNeurons = sort_nat(uniqueNeurons);

    
    % ===== CORRELATION COMPUTATION =====
    % Gather the spikes
    all_binned = zeros(length(sInputs), length(uniqueNeurons));
    for iFile = 1:length(sInputs)
        for iNeuron = 1:length(uniqueNeurons)
            for iEvent = 1:length(DataMats{iFile}.Events)
                evt = DataMats{iFile}.Events(iEvent);
                if strcmp(evt.label, uniqueNeurons{iNeuron})
                    all_binned(iFile, iNeuron) = length(evt.times( (evt.times > TimeWindow(1)) & (evt.times < TimeWindow(2)) ));
                    break
                end
            end
        end
    end

    % Subtract mean from each neuron (this is needed for noise correlation)
    all_binned = all_binned - repmat(mean(all_binned), size(all_binned,1),1);

    % Compute the Correlation for nxn Neurons
    noise_correlation = zeros(1,size(all_binned, 2), size(all_binned, 2));
    opts.normalize      = true;
    opts.nTrials        = 1;
    opts.flagStatistics = 0;
    connectivity = bst_correlation(all_binned', all_binned', opts);
    noise_correlation(1,:,:) = connectivity; 
    
    % Get list of unique conditions for output label
    conditions = unique({sInputs.Condition});
    condition = [];
    for iCond = 1:length(conditions)
        if iCond > 1
            condition = [condition ', '];
        end
        condition = [condition conditions{iCond}];
    end


    % ===== SAVE FILE =====
    % Prepare output file structure
    TfMat = db_template('timefreqmat');
    TfMat.TF          = noise_correlation;
    TfMat.Time        = 1:length(uniqueNeurons);
    TfMat.TFmask      = true(size(noise_correlation, 2), size(noise_correlation, 3));
    TfMat.Freqs       = 1:size(TfMat.TF, 3);
    TfMat.Comment     = ['Noise Correlation: ' condition];
    TfMat.DataType    = 'data';
    TfMat.RowNames    = {'NxN Noise Correlation'};
    TfMat.NeuronNames = uniqueNeurons;
    TfMat.Measure     = 'power';
    TfMat.Method      = 'morlet';
    TfMat.DataFile    = []; % Leave blank because multiple parents
    TfMat.Options     = [];
    % Add history field
	TfMat = bst_history('add', TfMat, 'compute', ['Noise correlation: [' num2str(TimeWindow(1)) ', ' num2str(TimeWindow(2)) '] ms']);
    % History: List files
    TfMat = bst_history('add', TfMat, 'noise_correlation', 'List of input files:');
    for iFile = 1:length(sInputs)
        TfMat = bst_history('add', TfMat, 'average', [' - ' sInputs(iFile).FileName]);
    end

    % Get output study
    [tmp, iTargetStudy] = bst_process('GetOutputStudy', sProcess, sInputs);
    sTargetStudy = bst_get('Study', iTargetStudy);
    % Output filename
    OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sTargetStudy.FileName), 'timefreq_noise_correlation');
    % Save output file and add to database
    bst_save(OutputFiles{1}, TfMat, 'v6');
    db_add_data(iTargetStudy, OutputFiles{1}, TfMat);
end
