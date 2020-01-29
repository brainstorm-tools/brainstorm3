function varargout = process_rasterplot_per_neuron( varargin )
% PROCESS_RASTERPLOT_PER_NEURON: Computes a rasterplot per neuron.
% 
% USAGE:    sProcess = process_rasterplot_per_neuron('GetDescription')
%        OutputFiles = process_rasterplot_per_neuron('Run', sProcess, sInput)

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
    sProcess.Comment     = 'Raster Plot Per Neuron';
    sProcess.FileTag     = 'raster';
    sProcess.Category    = 'custom';
    sProcess.SubGroup    = 'Electrophysiology';
    sProcess.Index       = 1506;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/e-phys/functions#Raster_Plots';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Options: Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'EEG';
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
    
    % If a time window was specified
    if isfield(sProcess.options, 'timewindow') && ~isempty(sProcess.options.timewindow) && ~isempty(sProcess.options.timewindow.Value) && iscell(sProcess.options.timewindow.Value)
        tfOPTIONS.TimeWindow = sProcess.options.timewindow.Value{1};
    elseif ~isfield(tfOPTIONS, 'TimeWindow')
        tfOPTIONS.TimeWindow = [];
    end
    
    tfOPTIONS.TimeVector = in_bst(sInputs(1).FileName, 'Time');

    % Check how many event groups we're processing
    listComments = cellfun(@str_remove_parenth, {sInputs.Comment}, 'UniformOutput', 0);
    [uniqueComments,tmp,iData2List] = unique(listComments);
    nLists = length(uniqueComments);
    
    % Process each even group seperately
    for iList = 1:nLists
        sCurrentInputs = sInputs(iData2List == iList);
    
        % === OUTPUT STUDY ===
        % Get output study
        [tmp, iStudy] = bst_process('GetOutputStudy', sProcess, sCurrentInputs);
        tfOPTIONS.iTargetStudy = iStudy;

        % Get channel file
        sChannel = bst_get('ChannelForStudy', iStudy);
        % Load channel file
        ChannelMat = in_bst_channel(sChannel.FileName);

        %% Get only the unique neurons along all of the trials
        nTrials = length(sCurrentInputs);

        % I get the files outside of the parfor so it won't fail.
        % This loads the information from ALL TRIALS on ALL_TRIALS_files
        % (Shouldn't create a memory problem).
        ALL_TRIALS_files = struct();
        for iFile = 1:nTrials
            DataMat = in_bst(sCurrentInputs(iFile).FileName);
            ALL_TRIALS_files(iFile).Events = DataMat.Events;
        end

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
        
            
        %% === START COMPUTATION ===
        sampling_rate = round(abs(1. / (tfOPTIONS.TimeVector(2) - tfOPTIONS.TimeVector(1))));

        temp = in_bst(sCurrentInputs(1).FileName);
        nElectrodes = size(temp.ChannelFlag,1);
        nBins = length(tfOPTIONS.TimeVector);
        raster = zeros(length(labelsForDropDownMenu), nBins, nTrials);
        bins = linspace(temp.Time(1), temp.Time(end), nBins);

        bst_progress('start', 'Raster Plot per Neuron', 'Binning Spikes...', 0, length(sCurrentInputs));

        for ifile = 1:length(sCurrentInputs)
            trial = in_bst(sCurrentInputs(ifile).FileName);
            single_file_binning = zeros(length(labelsForDropDownMenu), nBins);

            for iNeuron = 1:length(labelsForDropDownMenu)
                for ievent = 1:size(trial.Events,2)
                    if strcmp(trial.Events(ievent).label, labelsForDropDownMenu{iNeuron})

                        outside_up = trial.Events(ievent).times >= bins(end); % This snippet takes care of some spikes that occur outside of the window of Time due to precision incompatibility.
                        trial.Events(ievent).times(outside_up) = bins(end) - 0.001; % I assign those spikes just 1ms inside the bin
                        outside_down = trial.Events(ievent).times <= bins(1);
                        trial.Events(ievent).times(outside_down) = bins(1) + 0.001; % I assign those spikes just 1ms inside the bin

                        [tmp, bin_it_belongs_to] = histc(trial.Events(ievent).times, bins);

                        unique_bin = unique(bin_it_belongs_to);
                        occurences = [unique_bin; histc(bin_it_belongs_to, unique_bin)];

                        single_file_binning(iNeuron,occurences(1,:)) = occurences(2,:); 
                        break
                    end
                end
            end

            raster(:, :, ifile) = single_file_binning;
            bst_progress('inc', 1);
        end

        %% Build the output file
        tfOPTIONS.ParentFiles = {sCurrentInputs.FileName};

        % Prepare output file structure
        FileMat.TF = raster;
        FileMat.Time = tfOPTIONS.TimeVector;
        FileMat.TFmask = true(size(raster, 2), size(raster, 3));
        FileMat.Freqs = 1:size(FileMat.TF, 3);
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
    end
        
    % Display report to user
    bst_report('Info', sProcess, sInputs, 'Success');
    disp('BST> process_timefreq: Success');
end




