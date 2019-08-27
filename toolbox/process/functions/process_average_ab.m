function varargout = process_average_ab( varargin )
% PROCESS_AVERAGE_AB: Average of each couple of samples (A,B).
%
% NOTES: Each pair must share the same anatomy. Result is stored in a new condition.

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
    sProcess.Comment     = 'Average A&B';
    sProcess.Category    = 'Filter2';
    sProcess.SubGroup    = 'Other';
    sProcess.Index       = 901;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;
    sProcess.isPaired    = 1;
    sProcess.isSeparator = 1;
    % Default values for some options
    sProcess.isSourceAbsolute = -1;
    
    % === WEIGHTED AVERAGE
    sProcess.options.weighted.Comment    = 'Weighted average:  <FONT color="#777777">mean(x) = sum(Leff_i * x(i)) / sum(Leff_i)</FONT>';
    sProcess.options.weighted.Type       = 'checkbox';
    sProcess.options.weighted.Value      = 0;
    sProcess.options.weightedlabel.Comment    = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<FONT color="#777777">Leff_i = Effective number of averages for file #i</FONT>';
    sProcess.options.weightedlabel.Type       = 'label';
    % === SCALE NORMALIZE SOURCE MAPS (DEPRECATED AFTER INVERSE 2018) 
    sProcess.options.scalenormalized.Comment    = 'Adjust normalized source maps for SNR increase.<BR><FONT color="#777777"><I>Example: dSPM(Average) = sqrt(Navg) * Average(dSPM)</I></FONT>';
    sProcess.options.scalenormalized.Type       = 'checkbox';
    sProcess.options.scalenormalized.Value      = 0;
    sProcess.options.scalenormalized.InputTypes = {'results'};
    sProcess.options.scalenormalized.Hidden     = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
    % Absolute values 
    if isfield(sProcess.options, 'source_abs') && sProcess.options.source_abs.Value
        Comment = [Comment, ', abs'];
    end
    % Weighted
    if isfield(sProcess.options, 'weighted') && isfield(sProcess.options.weighted, 'Value') && ~isempty(sProcess.options.weighted.Value) && sProcess.options.weighted.Value
        Comment = ['Weighted ' Comment];
    end
end


%% ===== RUN =====
function sOutput = Run(sProcess, sInputA, sInputB) %#ok<DEFNU>
    % Weighted
    if isfield(sProcess.options, 'weighted') && isfield(sProcess.options.weighted, 'Value') && ~isempty(sProcess.options.weighted.Value)
        isWeighted = sProcess.options.weighted.Value;
    else
        isWeighted = 0;
    end
    % Scale normalized source maps (DEPRECATED AFTER INVERSE 2018)
    if isfield(sProcess.options, 'scalenormalized') && isfield(sProcess.options.scalenormalized, 'Value') && ~isempty(sProcess.options.scalenormalized.Value)
        isScaleDspm = sProcess.options.scalenormalized.Value;
    else
        isScaleDspm = 0;
    end
    % Initialize output variable
    sOutput = sInputA;
    
    % === COMPUTE THE AVERAGES ===
    % Weighted average
    if isWeighted
        % sOutput.A = (sInputA.nAvg .* sInputA.A + sInputB.nAvg .* sInputB.A) ./ (sInputA.nAvg + sInputB.nAvg);
        sOutput.A = (sInputA.Leff .* sInputA.A + sInputB.Leff .* sInputB.A) ./ (sInputA.Leff + sInputB.Leff);
        sOutput.nAvg = sInputA.nAvg + sInputB.nAvg;
        sOutput.Leff = sInputA.Leff + sInputB.Leff;
    % Regular average
    else
        sOutput.A = (sInputA.A + sInputB.A) ./ 2;
        sOutput.nAvg = 2;
        % Effective number of averages
        % Leff = 1 / sum_i(w_i^2 / Leff_i),    with N=2, w1=1/N, w2=1/N
        %      = N^2 / (1/Leff_A + 1/Leff_B))
        sOutput.Leff = 2^2 ./ (1./sInputA.Leff + 1./sInputB.Leff);
    end
    
    % === SCALE dSPM VALUES (DEPRECATED AFTER INVERSE 2018) ===
    % Apply a scaling to the dSPM functions, to compensate for the fact that the scaling applied to the NoiseCov was not correct
    if isScaleDspm && strcmpi(sInputA.FileType, 'results')
        % Load what function was used to estimate the sources
        sMat = in_bst_results(sInputA.FileName, 0, 'Function', 'nAvg');
        % Only use the option if the sources are normalized values that have to be fixed
        if ~isempty(sMat.Function) && ismember(sMat.Function, {'dspm','mnp','glsp','lcmvp'})
            % Must be a weighted average
            if ~isWeighted
                bst_report('Warning', sProcess, [], 'You cannot scale the normalized maps if you do not compute a weighted average. Select the option "Weighted" to enable this option.');
            else
                nAvg = sInputA.nAvg + sInputB.nAvg;
                Factor = sqrt(nAvg) / sqrt(sInputA.nAvg);
                bst_report('Warning', sProcess, [], sprintf('Averaging normalized maps (%s): scaling the values by %1.3f to match the number of trials averaged (%d => %d)', sMat.Function, Factor, sInputA.nAvg, nAvg));
                sOutput.A = Factor * sOutput.A;
            end
        end
    end
    
    % Output condition name
    sOutput.Condition = [sInputA.Condition, '.', sInputB.Condition];
    sOutput.Comment = [sInputA.Comment ' & ' sInputB.Comment];
end




