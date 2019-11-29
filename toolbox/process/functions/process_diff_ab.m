function varargout = process_diff_ab( varargin )
% PROCESS_DIFF: Difference of each couple of samples (A-B).

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
% Authors: Francois Tadel, 2010-2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Difference: A-B';
    sProcess.Category    = 'Filter2';
    sProcess.SubGroup    = 'Difference';
    sProcess.Index       = 150;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Difference';
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
    Comment = sProcess.Comment;
    % Absolute values 
    if isfield(sProcess.options, 'source_abs') && sProcess.options.source_abs.Value
        Comment = [Comment, ', abs'];
    end
end


%% ===== RUN =====
function sOutput = Run(sProcess, sInputsA, sInputsB) %#ok<DEFNU>
    % Difference
    sOutput = sInputsA;
    sOutput.A = sInputsA.A - sInputsB.A;
    % Output condition name
    sOutput.Condition = [sInputsA.Condition, '-', sInputsB.Condition];
    if isequal(sInputsA.Comment, sInputsB.Comment) && ~isequal(sInputsA.Condition, sInputsB.Condition)
        sOutput.Comment = [sInputsA.Condition ' - ' sInputsB.Condition];
    else
        sOutput.Comment = [sInputsA.Comment ' - ' sInputsB.Comment];
    end
    % Add absolute value tag
    if isfield(sProcess.options, 'source_abs') && sProcess.options.source_abs.Value
        sOutput.Comment = [sOutput.Comment, ' [abs]'];
    end
    % Colormap for recordings: keep the original
    % Colormap for sources, timefreq... : difference (stat2)
    if ~strcmpi(sInputsA(1).FileType, 'data')
        sOutput.ColormapType = 'stat2';
    end
    % Time-frequency: Change the measure type
    if strcmpi(sInputsA(1).FileType, 'timefreq')
        sOutput.Measure = 'other';
    end
    sOutput.nAvg = sInputsA.nAvg + sInputsB.nAvg;
    % Effective number of averages
    % Leff = 1 / sum_i(w_i^2 / Leff_i),  with w1=1 and w2=-1
    %      = 1 / (1/Leff_A + 1/Leff_B))
    sOutput.Leff = 1 ./ (1 ./ sInputsA.Leff + 1 ./ sInputsB.Leff);
end




