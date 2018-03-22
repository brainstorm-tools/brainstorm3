function varargout = process_rasterplot_Nas( varargin )
% PROCESS_RASTERPLOT_NAS: Computes a rasterplot per electrode.
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
% Authors: Konstantinos Nasiotis, 2017; Martin Cousineau, 2017

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'e-Phys Raster Plot';
    sProcess.FileTag     = 'raster';
    sProcess.Category    = 'custom';
    sProcess.SubGroup    = 'e-Phys Functions';
    sProcess.Index       = 1505;
    sProcess.Description = 'www.in.gr';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Options: Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'EEG';
    sProcess.options.sensortypes.InputTypes = {'data'};
    sProcess.options.sensortypes.Group   = 'input';
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
   
    % Get the channels IDs
    ChannelID = zeros(length(ChannelMat.Channel),1);
    for iChannel = 1:length(ChannelMat.Channel)
        temp = strrep(ChannelMat.Channel(iChannel).Name,'LFP ','');
        ChannelID(iChannel) = str2double(temp); clear temp;
    end
    
    % === START COMPUTATION ===
    sampling_rate = round(abs(1. / (tfOPTIONS.TimeVector(2) - tfOPTIONS.TimeVector(1))));
    
    [temp, ~] = in_bst(sInputs(1).FileName);
    nElectrodes = size(temp.ChannelFlag,1); 
    nTrials = length(sInputs);
    nBins = round(length(tfOPTIONS.TimeVector) / (bin_size * sampling_rate));
    raster = zeros(nElectrodes, nBins, nTrials);
    
    bins = unique([linspace(temp.Time(1),0 ,nBins/2+1)  linspace(0, temp.Time(end), nBins/2+1)]); % This doesn't give the eact bin_size if the bin_size doesn't divide the length of the signal
    
    for ifile = 1:length(sInputs)
        [trial, ~] = in_bst(sInputs(ifile).FileName);
        single_file_binning = zeros(nElectrodes, nBins);

        for ielectrode = 1:size(trial.F,1)
            for ievent = 1:size(trial.Events,2)
                
                if strcmp(trial.Events(ievent).label, ['Spikes Electrode ' num2str(ChannelID(ielectrode))])
                    
                    outside_up = trial.Events(ievent).times > bins(end); % This snippet takes care of some spikes that occur outside of the window of Time due to precision incompatibility.
                    trial.Events(ievent).times(outside_up) = bins(end);
                    outside_down = trial.Events(ievent).times < bins(1);
                    trial.Events(ievent).times(outside_down) = bins(1);
                    
                    [~, ~, bin_it_belongs_to] = histcounts(trial.Events(ievent).times, bins);
                     
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
            [~, ~, bin_it_belongs_to] = histcounts(trial.Events(iEvent).times, bins);
            convertedEvents(iEvent).samples = bin_it_belongs_to;
            convertedEvents(iEvent).times   = bins(bin_it_belongs_to);
        end
        Events = convertedEvents; clear convertedEvents
            
        
        
        
        %%
        tfOPTIONS.ParentFiles = {sInputs.FileName};

        % Prepare output file structure
        FileMat.F = single_file_binning;
        FileMat.Time = diff(bins(1:2))/2+bins(1:end-1); % CHECK THIS OUT - IT WILL NOT GO ALL THE WAY BUT IT WILL HAVE THE CORRECT NUMBER OF BINS

        FileMat.Std = [];
        FileMat.Comment = ['Raster Plot: ' trial.Comment];
        FileMat.DataType = 'recordings';
        
        FileMat.ChannelFlag = ones(length(ChannelID),1);            % GET THE GOOD CHANNELS HERE
        FileMat.Device      = trial.Device;
        FileMat.Events      = Events;
        
        FileMat.nAvg = 1;
        FileMat.ColormapType = [];
        FileMat.DisplayUnits = [];
        FileMat.History = trial.History;

        % Get output study
        sTargetStudy = bst_get('Study', iStudy);
        % Output filename
        FileName = bst_process('GetNewFilename', bst_fileparts(sTargetStudy.FileName), 'data_rasterplot');
        OutputFiles = {FileName};
        % Save output file and add to database
        bst_save(FileName, FileMat, 'v6');
        db_add_data(tfOPTIONS.iTargetStudy, FileName, FileMat);
    
    end

    
    
    % Display report to user
    bst_report('Info', sProcess, sInputs, 'Success');
    disp('BST> process_timefreq: Success');
end




