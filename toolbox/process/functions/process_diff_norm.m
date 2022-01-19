function varargout = process_diff_norm( varargin )
% PROCESS_DIFF_NORM: Normalized difference (A-B)/(A+B)

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
% Authors: Francois Tadel, 2015-2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Normalized:  (A-B)/(A+B)';
    sProcess.Category    = 'Filter2';
    sProcess.SubGroup    = 'Difference';
    sProcess.Index       = 151;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;
    sProcess.isPaired    = 1;
    % Default values for some options
    sProcess.isSourceAbsolute = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = 'Normalized difference';
    % Absolute values 
    if isfield(sProcess.options, 'source_abs') && sProcess.options.source_abs.Value
        Comment = [Comment, ', abs'];
    end
end


%% ===== RUN =====
function sOutput = Run(sProcess, sInputsA, sInputsB) %#ok<DEFNU>
    % Difference
    sOutput = sInputsA;
    sOutput.A = (sInputsA.A - sInputsB.A) ./ (sInputsA.A + sInputsB.A);
    % Output condition name
    sOutput.Condition = [sInputsA.Condition, '-', sInputsB.Condition];
    sOutput.Comment   = [sInputsA.Comment ' - ' sInputsB.Comment];
    % Colormap for recordings: keep the original
    % Colormap for sources, timefreq... : difference (stat2)
    if ~strcmpi(sInputsA(1).FileType, 'data')
        sOutput.ColormapType = 'stat2';
    end
    % Time-frequency: Change the measure type
    if strcmpi(sInputsA(1).FileType, 'timefreq')
        sOutput.Measure = 'other';
    end
    % Can't keep track of number of averages
    sOutput.nAvg = [];
    sOutput.Leff = [];
end




