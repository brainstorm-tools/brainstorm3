function varargout = process_source_dspmscale( varargin )
% PROCESS_SOURCE_DSPMSCALE: Scale dSPM value to adjust for the number of trials.
%
% USAGE:  OutputFiles = process_source_dspmscale('Run', sProcess, sInput)
%          ResultsMat = process_source_dspmscale('Compute', ResultsMat, Method, Field)

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
% Authors: Francois Tadel, 2018-2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % ===== PROCESS =====
    % Description the process
    sProcess.Comment     = 'Scale averaged dSPM';
    sProcess.FileTag     = 'scaled';
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Sources';
    sProcess.Index       = 338;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/SourceEstimation#Averaging_normalized_values';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'results'};
    sProcess.OutputTypes = {'results'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    % === SELECT METHOD
    sProcess.options.label1.Comment = ['Adjust averaged normalized source maps for SNR increase:<BR>' ...
                                       'dSPM(Average(trials)) = sqrt(Ntrials) * Average(dSPM(trials))<BR><BR>' ...
                                       'You should use this process for visualization and interpretation<BR>' ...
                                       'only, eg. in order to display cortical maps that can be interpreted<BR>' ...
                                       'as Z values. Scaled dSPM should never be averaged or used for any<BR>' ...
                                       'other statistical analysis.<BR><BR>' ...
                                       'This process is only useful when using "Compute sources [2018]",<BR>' ...
                                       'for dSPM files computed with previous versions of the inverse<BR>' ...
                                       'estimation functions, this is done automatically.<BR><BR>'];
    sProcess.options.label1.Type    = 'label';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function sInput = Run(sProcess, sInput) %#ok<DEFNU>
    % Load additional fields from the source file
    ResultsMat = in_bst_results(sInput.FileName, 0, 'Leff', 'Function');
    % If the input file is a single trial: stop
    if ~strcmpi(ResultsMat.Function, 'dspm2018')
        bst_report('Warning', sProcess, sInput, 'The input file is not an average (nAvg=1), no scaling could be performed.');
        return;
    end
    % If trying to process something that is not a dspm2018 file: warning
    if strcmpi(ResultsMat.Function, 'dspm2018sc')
        bst_report('Error', sProcess, sInput, 'The input file has already been scaled with this process.');
        sInput = [];
        return;
    elseif ~strcmpi(ResultsMat.Function, 'dspm2018')
        bst_report('Warning', sProcess, sInput, ['The input file is not a dSPM file estimated with "Compute sources [2018].' 10 'Applying the process on this file may not make sense...']);
    end
    % Considering that the file is necessarily starting as if (Leff = 1)
    % nAvgOrig = ResultsMat.nAvg;
    LeffOrig = 1;

    % Apply scaling
    if (LeffOrig ~= ResultsMat.Leff)
        Factor = sqrt(ResultsMat.Leff) / sqrt(LeffOrig);
        % Display information message
        msg = sprintf('Scaling the values by %1.2f to match the number of trials averaged (%d => %d)', Factor, LeffOrig, ResultsMat.Leff);
        bst_report('Info', sProcess, sInput, msg);
        disp(['dSPM> ' msg]);
        sInput.HistoryComment = msg;
        % Apply on full source matrix
        sInput.A = Factor * sInput.A;
        % Change file tag so we don't allow rescaling
        sInput.Function = 'dspm2018sc';
        sInput.Comment = strrep(sInput.Comment, '-unscaled', '');
        sInput.Leff = 0;
    end
end





