function varargout = process_baseline( varargin )
% PROCES_BASELINE: Remove the baseline average from each channel (for the given time instants).
%
% DESCRIPTION: For each channel:
%   1) Compute the mean m for the baseline
%   2) For all the time samples, subtract m

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
% Authors: Francois Tadel, 2010-2015

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Remove DC offset';
    sProcess.FileTag     = 'bl';
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Pre-process';
    sProcess.Index       = 60;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Epoching?highlight=%28Remove+DC+offset%29#Import_in_database';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data', 'results', 'matrix'};
    sProcess.OutputTypes = {'raw', 'data', 'results', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Default values for some options
    sProcess.processDim  = 1;    % Process channel by channel

    % Definition of the options
    sProcess.options.description.Comment = ['For each signal in input:<BR>' ...
                                            '1) Compute the mean <I>m</I> over the baseline<BR>' ...
                                            '2) For each time sample, subtract <I>m</I><BR><BR>'];
    sProcess.options.description.Type    = 'label';
    % === Baseline time window
    sProcess.options.baseline.Comment = 'Baseline:';
    sProcess.options.baseline.Type    = 'baseline';
    sProcess.options.baseline.Value   = [];
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'data', 'raw'};
    % === Method
    sProcess.options.method.Comment = {'DC offset correction: <FONT color=#7F7F7F>&nbsp;&nbsp;&nbsp;x_std = x - &mu;'; 'bl'};
    sProcess.options.method.Type    = 'radio_label';
    sProcess.options.method.Value   = 'bl';
    sProcess.options.method.Hidden  = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = process_baseline_norm('FormatComment', sProcess);
end


%% ===== RUN =====
function sInputB = Run(sProcess, sInput) %#ok<DEFNU>
    % Call the baseline normalization
    sInputB = process_baseline_norm('Run', sProcess, sInput);
end


