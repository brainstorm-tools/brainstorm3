function varargout = process_rasterplot_per_neuron( varargin )
% PROCESS_RASTERPLOT_PER_NEURON: Computes a raster plot per neuron

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
%          Martin Cousineau, 2018
%          Francois Tadel, 2022

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Raster plot per neuron';
    sProcess.FileTag     = 'raster';
    sProcess.Category    = 'custom';
    sProcess.SubGroup    = 'Electrophysiology';
    sProcess.Index       = 1225;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/e-phys/functions#Raster_plots';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs)
    % Initialize returned values
    OutputFiles = {};

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
        labelsNeurons = unique(labelsNeurons,'stable');
        labelsNeurons = sort_nat(labelsNeurons);
        
            
        % ===== COMPUTE BINNING =====
        % Get file time
        DataMat = in_bst_data(sCurrentInputs(1).FileName, 'Time');
        TimeVector = DataMat.Time;
        % Define bins
        nBins = length(TimeVector);
        raster = zeros(length(labelsNeurons), nBins, nTrials);
        bins = linspace(TimeVector(1), TimeVector(end), nBins);

        bst_progress('start', 'Raster plot per neuron', 'Binning spikes...', 0, length(sCurrentInputs));

        for iFile = 1:nTrials
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

                        single_file_binning(iNeuron,occurences(1,:)) = occurences(2,:); 
                        break
                    end
                end
            end

            raster(:, :, iFile) = single_file_binning;
            bst_progress('inc', 1);
        end


        % ===== SAVE RESULTS =====
        % Prepare output file structure
        TfMat = db_template('timefreqmat');
        TfMat.TF           = raster;
        TfMat.Time         = TimeVector;
        TfMat.Freqs        = 1:size(TfMat.TF, 3);
        TfMat.Comment      = ['Raster Plot: ' uniqueComments{iList}];
        TfMat.DataType     = 'data';
        TfMat.RowNames     = labelsNeurons;
        TfMat.Measure      = 'power';
        TfMat.Method       = 'morlet';
        TfMat.DataFile     = []; % Leave blank because multiple parents
        TfMat.DisplayUnits = 'Spikes';
        TfMat.Options      = [];

        % Add history field
        TfMat = bst_history('add', TfMat, 'compute', 'Raster plot per neuron');
        for iFile = 1:length(sInputs)
            TfMat = bst_history('add', TfMat, 'average', [' - ' sInputs(iFile).FileName]);
        end

        % Get output study
        [tmp, iTargetStudy] = bst_process('GetOutputStudy', sProcess, sCurrentInputs);
        sTargetStudy = bst_get('Study', iTargetStudy);
        % Output filename
        OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sTargetStudy.FileName), 'timefreq_rasterplot');
        % Save output file and add to database
        bst_save(OutputFiles{1}, TfMat, 'v6');
        db_add_data(iTargetStudy, OutputFiles{1}, TfMat);
    end
end
