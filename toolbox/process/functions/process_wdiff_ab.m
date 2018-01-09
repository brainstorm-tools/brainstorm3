function varargout = process_wdiff_ab( varargin )
% PROCESS_DIFF: Weighted difference of each couple of averaged files (A-B).

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2011-2015

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Weighted:  A-sqrt(nB/nA)*B';
    sProcess.Category    = 'Filter2';
    sProcess.SubGroup    = 'Difference';
    sProcess.Index       = 152;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;
    sProcess.isPaired    = 1;
    % Default values for some options
    sProcess.isSourceAbsolute = 1;
     % Definition of the options
    sProcess.options.ttest_label.Comment    = ['Corrects the difference of signal amplitude between two averages<BR>' ...
                                               'that were computed with different numbers of trials:<BR><BR>' ...
                                               '<B>A � sqrt(nAvg_B) / sqrt(nAvg_A) * B</B><BR><BR>'];
    sProcess.options.ttest_label.Type       = 'label';
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
    sOutput.A = sInputsA.A - sqrt(sInputsB.nAvg) ./ sqrt(sInputsA.nAvg) .* sInputsB.A;
    % Output condition name
    sOutput.Condition = [sInputsA.Condition, '-', sInputsB.Condition];
    sOutput.Comment   = [sInputsA.Comment ' - ' sInputsB.Comment];
    % Colormap for recordings: keep the original
    % Colormap for sources, timefreq... : difference (stat2)
    if ~strcmpi(sInputsA(1).FileType, 'data')
        sOutput.ColormapType = 'stat2';
    end
end




