function varargout = process_psth_per_channel( varargin )
% PROCESS_PSTH_PER_CHANNEL: Computes the PSTH per channel.

% It displays the binned firing rate on each channel (of only the first 
% neuron on each channel if multiple have been detected). This can be nicely
% visualized on the cortical surface if the positions of the electrodes
% have been set, and show real time firing rate.

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
% Authors: Konstantinos Nasiotis, 2018-2019
%          Francois Tadel, 2022

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'PSTH per channel';
    sProcess.FileTag     = 'raster';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Electrophysiology';
    sProcess.Index       = 1229;
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
function OutputFiles = Run(sProcess, sInput)
    % Initialize returned values
    OutputFiles = {};

    % ==== OPTIONS =====
    % Bin size
    if isfield(sProcess.options, 'binsize') && ~isempty(sProcess.options.binsize) && ~isempty(sProcess.options.binsize.Value) && iscell(sProcess.options.binsize.Value) && sProcess.options.binsize.Value{1} > 0
        bin_size = sProcess.options.binsize.Value{1};
    else
        bst_report('Error', sProcess, sInput, 'Positive bin size required.');
        return;
    end

    % ===== LOAD INPUT FILES =====
    % Load data file
    DataMat = in_bst_data(sInput.FileName, 'Time', 'Events', 'Comment', 'Device', 'ChannelFlag', 'History');
    sampling_rate = round(abs(1. / (DataMat.Time(2) - DataMat.Time(1))));
    % Load channel file
    ChannelMat = in_bst_channel(sInput.ChannelFile);

    % ===== COMPUTE BINNING =====
    % Define bins
    nBins = floor(length(DataMat.Time) / (bin_size * sampling_rate));
    bins = linspace(DataMat.Time(1), DataMat.Time(end), nBins+1);
    single_file_binning = zeros(length(ChannelMat.Channel), nBins);
    % Process channel by channel
    for iChan = 1:length(ChannelMat.Channel)
        for iEvent = 1:size(DataMat.Events,2)
            
            % Bin ONLY THE FIRST NEURON'S SPIKES if there are multiple neurons!
            if panel_spikes('IsSpikeEvent', DataMat.Events(iEvent).label) ...
                    && panel_spikes('IsFirstNeuron', DataMat.Events(iEvent).label) ...
                    && strcmp(ChannelMat.Channel(iChan).Name, panel_spikes('GetChannelOfSpikeEvent', DataMat.Events(iEvent).label))
                
                outside_up = DataMat.Events(iEvent).times >= bins(end); % This snippet takes care of some spikes that occur outside of the window of Time due to precision incompatibility.
                DataMat.Events(iEvent).times(outside_up) = bins(end) - 0.001; % Make sure it is inside the bin. Add 1ms offset
                outside_down = DataMat.Events(iEvent).times <= bins(1);
                DataMat.Events(iEvent).times(outside_down) = bins(1) + 0.001; % Make sure it is inside the bin. Add 1ms offset
                
                [tmp, bin_it_belongs_to] = histc(DataMat.Events(iEvent).times, bins);
                 
                unique_bin = unique(bin_it_belongs_to);
                occurences = [unique_bin; histc(bin_it_belongs_to, unique_bin)];
                 
                single_file_binning(iChan,occurences(1,:)) = occurences(2,:)/bin_size; % The division by the bin_size gives the Firing Rate
                break
            end
        end
        
    end

    % Events have to be converted to the sampling rate of the binning
    convertedEvents = DataMat.Events;
    for iEvent = 1:length(DataMat.Events)
        [tmp, bin_it_belongs_to] = histc(DataMat.Events(iEvent).times, bins);
        bin_it_belongs_to(bin_it_belongs_to==0) = 1;
        convertedEvents(iEvent).times   = bins(bin_it_belongs_to);
    end
    Events = convertedEvents;
        
    
    % ===== SAVE RESULTS =====
    % Prepare output file structure
    FileMat = db_template('datamat');
    FileMat.F           = single_file_binning;
    FileMat.Time        = diff(bins(1:2))/2+bins(1:end-1);
    FileMat.Comment     = ['PSTH: ' DataMat.Comment];
    FileMat.DataType    = 'recordings';
    FileMat.ChannelFlag = DataMat.ChannelFlag;
    FileMat.Device      = DataMat.Device;
    FileMat.Events      = Events;
    FileMat.nAvg        = 1;
    FileMat.History     = DataMat.History;
    
    % Add history field
    FileMat = bst_history('add', FileMat, 'ptsh', ['PSTH per electrode: ' num2str(bin_size) ' ms']);
    FileMat = bst_history('add', FileMat, 'ptsh', ['Input file: ' sInput.FileName]);
    % Output filename
    FileName = bst_process('GetNewFilename', bst_fileparts(sInput.FileName), 'data_psth');
    OutputFiles = {FileName};
    % Save output file and add to database
    bst_save(FileName, FileMat, 'v6');
    db_add_data(sInput.iStudy, FileName, FileMat);
end
