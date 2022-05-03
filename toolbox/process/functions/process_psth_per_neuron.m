function varargout = process_psth_per_neuron( varargin )
% PROCESS_PSTH_PER_NEURON: Computes the PSTH (peristimulus time histogram) per neuron.

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
% Authors: Konstantinos Nasiotis, 2019
%          Francois Tadel, 2022

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'PSTH per neuron';
    sProcess.FileTag     = 'psth';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Electrophysiology';
    sProcess.Index       = 1227;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/e-phys/functions';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Options: Bin size
    sProcess.options.binsize.Comment = 'Bin size: ';
    sProcess.options.binsize.Type    = 'value';
    sProcess.options.binsize.Value   = {0.05, 'ms', 1};
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
    if isfield(sProcess.options, 'binsize') && ~isempty(sProcess.options.binsize) && ~isempty(sProcess.options.binsize.Value) && iscell(sProcess.options.binsize.Value) && sProcess.options.binsize.Value{1} > 0
        bin_size = sProcess.options.binsize.Value{1};
    else
        bst_report('Error', sProcess, sInputs, 'Positive bin size required.');
        return;
    end

    % ===== PROCESS FILES =====
    % Check how many event groups we're processing
    listComments = cellfun(@str_remove_parenth, {sInputs.Comment}, 'UniformOutput', 0);
    [uniqueComments,tmp,iData2List] = unique(listComments);
    nLists = length(uniqueComments);
    % Process each even group seperately
    for iList = 1:nLists

        % === LOAD INPUTS ===
        % Get trials in this group
        sCurrentInputs = sInputs(iData2List == iList);
        nTrials = length(sCurrentInputs);

        % Get all the neuron labels (each trial might have different number of neurons)
        DataMats = cell(1, nTrials);
        labelsNeurons = {};
        for iFile = 1:nTrials
            % Load file
            DataMats{iFile} = in_bst_data(sCurrentInputs(iFile).FileName, 'Events');
            % Save spike events
            for iEvent = 1:length(DataMats{iFile}.Events)
                if panel_spikes('IsSpikeEvent', DataMats{iFile}.Events(iEvent).label)
                    labelsNeurons{end+1} = DataMats{iFile}.Events(iEvent).label;
                end
            end
        end
        % If no neuron was found
        if isempty(labelsNeurons)
            bst_report('Error', sProcess, sCurrentInputs(1), 'No neurons/spiking events detected.');
            return;
        end
        % Sort neurons alphabetically
        labelsNeurons = unique(labelsNeurons, 'stable');
        labelsNeurons = sort_nat(labelsNeurons);
        
        
        % ===== COMPUTE BINNING =====
        % Get file time
        DataMat = in_bst_data(sCurrentInputs(1).FileName, 'Time');
        sampling_rate = round(abs(1. / (DataMat.Time(2) - DataMat.Time(1))));
        % Define bins
        nBins = floor(length(DataMat.Time) / (bin_size * sampling_rate));
        raster = zeros(length(labelsNeurons), nBins, nTrials);
        bins = linspace(DataMat.Time(1), DataMat.Time(end), nBins+1);

        bst_progress('start', 'PSTH per Neuron', 'Binning Spikes...', 0, length(sCurrentInputs));

        for iFile = 1:length(sCurrentInputs)
            single_file_binning = zeros(length(labelsNeurons), nBins);
            for iNeuron = 1:length(labelsNeurons)
                for ievent = 1:size(DataMats{iFile}.Events,2)
                    evt = DataMats{iFile}.Events(ievent);
                    if strcmp(evt.label, labelsNeurons{iNeuron})
                        outside_up = evt.times >= bins(end); % This snippet takes care of some spikes that occur outside of the window of Time due to precision incompatibility.
                        evt.times(outside_up) = bins(end) - 0.001; % I assign those spikes just 1ms inside the bin
                        outside_down = evt.times <= bins(1);
                        evt.times(outside_down) = bins(1) + 0.001; % I assign those spikes just 1ms inside the bin

                        [tmp, bin_it_belongs_to] = histc(evt.times, bins);

                        unique_bin = unique(bin_it_belongs_to);
                        occurences = [unique_bin; histc(bin_it_belongs_to, unique_bin)];

                        single_file_binning(iNeuron,occurences(1,:)) = occurences(2,:)/bin_size; % The division by the bin_size gives the Firing Rate 
                        break
                    end
                end
            end
            raster(:, :, iFile) = single_file_binning;
            bst_progress('inc', 1);
        end

        % ===== COMPUTE 95% CONFIDENCE INTERVALS =====
        % Initialize the 3 vectors that will be plotted (mean, and 95% confidence intervals)   
        meanData = zeros(length(labelsNeurons), nBins);    % nNeurons x nBins
        CI       = zeros(length(labelsNeurons), nBins, 1, 2); % nNeurons x nBins x 1 (unused STD dimension) x 2 (upper-lower bound)

        bst_progress('start', 'PSTH per Neuron', 'Performing permutation test for 95% confidence intervals...', 0, length(labelsNeurons));

        % Assign the confidence intervals values
        for iNeuron = 1:length(labelsNeurons)
            for iBin = 1:nBins
                meanData(iNeuron, iBin) = mean(raster(iNeuron,iBin,:));

                % Compute the 95% confidence intervals
                RESAMPLING = 1000; % Number of permutations
                CI(iNeuron,iBin,1,:) = bootci(RESAMPLING, {@mean, raster(iNeuron,iBin,:)}, 'type','cper','alpha',0.05);
            end
            bst_progress('inc', 1);
        end
        
        
        % ===== SAVE RESULTS =====
        % Prepare output file structure
        TfMat = db_template('timefreqmat');
        TfMat.Value        = meanData;
        TfMat.Std          = CI;
        TfMat.Comment      = ['PSTH: ' uniqueComments{iList}];
        TfMat.Description  = labelsNeurons';
        TfMat.Time         = diff(bins(1:2))/2+bins(1:end-1);
        TfMat.ChannelFlag  = ones(length(labelsNeurons),1);
        TfMat.nAvg         = 1;
        TfMat.DisplayUnits = 'Spikes/sec';
        
        % Add history field
        TfMat = bst_history('add', TfMat, 'compute', 'PSTH per neuron');
        for iFile = 1:length(sInputs)
            TfMat = bst_history('add', TfMat, 'average', [' - ' sInputs(iFile).FileName]);
        end

        % Get output study
        [tmp, iTargetStudy] = bst_process('GetOutputStudy', sProcess, sCurrentInputs);
        sTargetStudy = bst_get('Study', iTargetStudy);
        % Output filename
        FileName = bst_process('GetNewFilename', bst_fileparts(sTargetStudy.FileName), 'matrix');
        OutputFiles = {FileName};
        % Save output file and add to database
        bst_save(FileName, TfMat, 'v6');
        db_add_data(iTargetStudy, FileName, TfMat);
    end
end
