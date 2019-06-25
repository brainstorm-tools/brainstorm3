function varargout = process_psth_per_electrode( varargin )
% PROCESS_PSTH_PER_ELECTRODE: Computes the PSTH per electrode.

% It displays the binned firing rate on each electrode (of only the first 
% neuron on each electrode if multiple have been detected). This can be nicely
% visualized on the cortical surface if the positions of the electrodes
% have been set, and show real time firing rate.
% 
% USAGE:    sProcess = process_PSTH_per_electrode('GetDescription')
%        OutputFiles = process_PSTH_per_electrode('Run', sProcess, sInput)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Author: Konstantinos Nasiotis, 2018-2019;

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'PSTH Per Electrode';
    sProcess.FileTag     = 'raster';
    sProcess.Category    = 'custom';
    sProcess.SubGroup    = 'Electrophysiology';
    sProcess.Index       = 1505;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/e-phys/functions#Raster_Plots';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Options: Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'EEG';
    % Options: Bin size
    sProcess.options.binsize.Comment = 'Bin size: ';
    sProcess.options.binsize.Type    = 'value';
    sProcess.options.binsize.Value   = {0.05, 'ms', 1};
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
    
    % Bin size
    if isfield(sProcess.options, 'binsize') && ~isempty(sProcess.options.binsize) && ~isempty(sProcess.options.binsize.Value) && iscell(sProcess.options.binsize.Value) && sProcess.options.binsize.Value{1} > 0
        bin_size = sProcess.options.binsize.Value{1};
    else
        bst_report('Error', sProcess, sInputs, 'Positive bin size required.');
        return;
    end
    
    % If a time window was specified
    if isfield(sProcess.options, 'timewindow') && ~isempty(sProcess.options.timewindow) && ~isempty(sProcess.options.timewindow.Value) && iscell(sProcess.options.timewindow.Value)
        tfOPTIONS.TimeWindow = sProcess.options.timewindow.Value{1};
    elseif ~isfield(tfOPTIONS, 'TimeWindow')
        tfOPTIONS.TimeWindow = [];
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
    
    % === START COMPUTATION ===
    sampling_rate = round(abs(1. / (tfOPTIONS.TimeVector(2) - tfOPTIONS.TimeVector(1))));
    
    temp = in_bst(sInputs(1).FileName);
    nElectrodes = size(temp.ChannelFlag,1); 
    nTrials = length(sInputs);
    nBins = floor(length(tfOPTIONS.TimeVector) / (bin_size * sampling_rate));
    bins = linspace(temp.Time(1), temp.Time(end), nBins+1);
    
    for ifile = 1:length(sInputs)
        trial = in_bst(sInputs(ifile).FileName);
        single_file_binning = zeros(nElectrodes, nBins);

        for ielectrode = 1:size(trial.F,1)
            for ievent = 1:size(trial.Events,2)
                
                % Bin ONLY THE FIRST NEURON'S SPIKES if there are multiple neurons!
                if process_spikesorting_supervised('IsSpikeEvent', trial.Events(ievent).label) ...
                        && process_spikesorting_supervised('IsFirstNeuron', trial.Events(ievent).label) ...
                        && strcmp(ChannelMat.Channel(ielectrode).Name, process_spikesorting_supervised('GetChannelOfSpikeEvent', trial.Events(ievent).label))
                    
                    outside_up = trial.Events(ievent).times >= bins(end); % This snippet takes care of some spikes that occur outside of the window of Time due to precision incompatibility.
                    trial.Events(ievent).times(outside_up) = bins(end) - 0.001; % Make sure it is inside the bin. Add 1ms offset
                    outside_down = trial.Events(ievent).times <= bins(1);
                    trial.Events(ievent).times(outside_down) = bins(1) + 0.001; % Make sure it is inside the bin. Add 1ms offset
                    
                    [tmp, bin_it_belongs_to] = histc(trial.Events(ievent).times, bins);
                     
                    unique_bin = unique(bin_it_belongs_to);
                    occurences = [unique_bin; histc(bin_it_belongs_to, unique_bin)];
                     
                    single_file_binning(ielectrode,occurences(1,:)) = occurences(2,:)/bin_size; % The division by the bin_size gives the Firing Rate
                    break
                end
            end
            
        end
        
        
        % Events have to be converted to the sampling rate of the binning
        convertedEvents = trial.Events;
        
        for iEvent = 1:length(trial.Events)
            [tmp, bin_it_belongs_to] = histc(trial.Events(iEvent).times, bins);

            bin_it_belongs_to(bin_it_belongs_to==0) = 1;
            convertedEvents(iEvent).times   = bins(bin_it_belongs_to);
            
        end
        Events = convertedEvents;
            
        
        
        
        %%
        tfOPTIONS.ParentFiles = {sInputs.FileName};

        % Prepare output file structure
        FileMat.F = single_file_binning;
        FileMat.Time = diff(bins(1:2))/2+bins(1:end-1);

        FileMat.Std = [];
        FileMat.Comment = ['PSTH: ' trial.Comment];
        FileMat.DataType = 'recordings';
        
        FileMat.ChannelFlag = temp.ChannelFlag;
        FileMat.Device      = trial.Device;
        FileMat.Events      = Events;
        
        FileMat.nAvg = 1;
        FileMat.ColormapType = [];
        FileMat.DisplayUnits = [];
        FileMat.History = trial.History;
        
        % Add history field
        FileMat = bst_history('add', FileMat, 'compute', ...
            ['PSTH per electrode: ' num2str(bin_size) ' ms']);

        % Get output study
        sTargetStudy = bst_get('Study', iStudy);
        % Output filename
        FileName = bst_process('GetNewFilename', bst_fileparts(sTargetStudy.FileName), 'data_psth');
        OutputFiles = {FileName};
        % Save output file and add to database
        bst_save(FileName, FileMat, 'v6');
        db_add_data(tfOPTIONS.iTargetStudy, FileName, FileMat);
    
    end

    
    
    
    % Display report to user
    bst_report('Info', sProcess, sInputs, 'Success');
    disp('BST> process_timefreq: Success');
end




