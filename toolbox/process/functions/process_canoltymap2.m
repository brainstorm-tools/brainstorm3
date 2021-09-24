function varargout = process_canoltymap2( varargin )
% This function generates Canolty like maps (Science 2006, figure 1) for the input signal. 

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
% Authors: Esther Florin, Sylvain Baillet, 2011-2013
%          Francois Tadel, 2013-2014

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Canolty maps (FileB=MaxPAC)';
    sProcess.Category    = 'File2';
    sProcess.SubGroup    = 'Frequency';
    sProcess.Index       = 661;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw',      'data',     'results',  'matrix'};
    sProcess.OutputTypes = {'timefreq', 'timefreq', 'timefreq', 'timefreq'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Resting#Canolty_maps';
    % ==== INPUT ====
    sProcess.options.label_in.Comment = '<B><U>Input options</U></B>:';
    sProcess.options.label_in.Type    = 'label';
    % === TIME WINDOW
    sProcess.options.timewindow.Comment = 'Time window: ';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    % === SENSOR SELECTION
    sProcess.options.target_data.Comment    = 'Sensor types or names (empty=all): ';
    sProcess.options.target_data.Type       = 'text';
    sProcess.options.target_data.Value      = 'MEG, EEG';
    sProcess.options.target_data.InputTypes = {'data', 'raw'};
    % === SCOUTS SELECTION
    sProcess.options.scouts.Comment    = 'Use scouts';
    sProcess.options.scouts.Type       = 'scout_confirm';
    sProcess.options.scouts.Value      = {};
    sProcess.options.scouts.InputTypes = {'results'};
    % === SCOUT FUNCTION ===
    sProcess.options.scoutfunc.Comment    = {'Mean', 'Max', 'PCA', 'Std', 'All', 'Scout function:'};
    sProcess.options.scoutfunc.Type       = 'radio_line';
    sProcess.options.scoutfunc.Value      = 1;
    sProcess.options.scoutfunc.InputTypes = {'results'};
    % === SCOUT TIME ===
    sProcess.options.scouttime.Comment    = {'Before', 'After', 'When to apply the scout function:'};
    sProcess.options.scouttime.Type       = 'radio_line';
    sProcess.options.scouttime.Value      = 1;
    sProcess.options.scouttime.InputTypes = {'results'};
    % === ROW NAMES
    sProcess.options.target_tf.Comment    = 'Row names or indices (empty=all): ';
    sProcess.options.target_tf.Type       = 'text';
    sProcess.options.target_tf.Value      = '';
    sProcess.options.target_tf.InputTypes = {'timefreq', 'matrix'};
    
    % ==== ESTIMATOR ====
    sProcess.options.label_method.Comment = '<BR><B><U>Estimator options</U></B>:';
    sProcess.options.label_method.Type    = 'label';
    % === EPOCH TIME
    sProcess.options.epochtime.Comment = 'Epoch time: ';
    sProcess.options.epochtime.Type    = 'range';
    sProcess.options.epochtime.Value   = {[-0.5, 0.5], 'ms', []};
    % === MAX_BLOCK_SIZE
    sProcess.options.max_block_size.Comment = 'Number of signals to process at once: ';
    sProcess.options.max_block_size.Type    = 'value';
    sProcess.options.max_block_size.Value   = {100, ' ', 0};
    
    % ==== OUTPUT ====
    sProcess.options.label_out.Comment = '<BR><U><B>Output configuration</B></U>:';
    sProcess.options.label_out.Type    = 'label';
    % === SAVE AVERAGED LOW-FREQ SIGNALS
    sProcess.options.save_erp.Comment = 'Save averaged low frequency signals';
    sProcess.options.save_erp.Type    = 'checkbox';
    sProcess.options.save_erp.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFile = Run(sProcess, sInputA, sInputB) %#ok<DEFNU>
    % Load the optimal low-frequency values from the MaxPAC file in InputB
    DataMat = load(file_fullpath(sInputB.FileName), 'sPAC');
    if ~isfield(DataMat, 'sPAC') || isempty(DataMat.sPAC) || ~isfield(DataMat.sPAC, 'NestingFreq') || isempty(DataMat.sPAC.NestingFreq)
        bst_report('Error', sProcess, sInputB, 'Invalid MaxPAC file in FilesB.');
        OutputFile = {};
        return;
    end
    % Set option from the file
    sProcess.options.lowfreq.Value{1} = DataMat.sPAC.NestingFreq;
    % Run the megPAC process
    OutputFile = process_canoltymap('Run', sProcess, sInputA);
end

    


