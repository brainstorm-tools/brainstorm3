function varargout = process_granger1( varargin )
% PROCESS_GRANGER1: Compute the Granger causality between one signal and all the others, in one file.

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
% Authors: Francois Tadel, 2012-2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Bivariate Granger causality 1xN';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Connectivity';
    sProcess.Index       = 660;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Connectivity';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data',     'results',  'matrix'};
    sProcess.OutputTypes = {'timefreq', 'timefreq', 'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    % === CONNECT INPUT
    sProcess = process_corr1n('DefineConnectOptions', sProcess, 0);
    % === REMOVE EVOKED REPONSE
    sProcess.options.removeevoked.Comment = 'Remove evoked response from each trial';
    sProcess.options.removeevoked.Type    = 'checkbox';
    sProcess.options.removeevoked.Value   = 0;
    sProcess.options.removeevoked.Group   = 'input';
    % === DIRECTION
    sProcess.options.dirlabel.Comment  = 'Direction of the causality:';
    sProcess.options.dirlabel.Type     = 'label';
    sProcess.options.direction.Comment = {'From the selected node (out)', 'To the selected node (in)', 'Both (generates two files)'};
    sProcess.options.direction.Type    = 'radio';
    sProcess.options.direction.Value   = 3;
    % === GRANGER ORDER
    sProcess.options.grangerorder.Comment = 'Maximum Granger model order (default=10):';
    sProcess.options.grangerorder.Type    = 'value';
    sProcess.options.grangerorder.Value   = {10, '', 0};
    % === OUTPUT MODE
    sProcess.options.outputmode.Comment = {'Save individual results (one file per input file)', 'Concatenate input files before processing (one file)', 'Save average connectivity matrix (one file)'};
    sProcess.options.outputmode.Type    = 'radio';
    sProcess.options.outputmode.Value   = 1;
    sProcess.options.outputmode.Group   = 'output';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputA) %#ok<DEFNU>
    % Input options
    OPTIONS = process_corr1n('GetConnectOptions', sProcess, sInputA);
    if isempty(OPTIONS)
        OutputFiles = {};
        return
    end
    
    % Metric options
    OPTIONS.Method = 'granger';
    OPTIONS.RemoveEvoked = sProcess.options.removeevoked.Value;
    OPTIONS.GrangerOrder = sProcess.options.grangerorder.Value{1};
    OPTIONS.pThresh      = 0.05;
    OPTIONS.Freqs        = 0;

    % Computation depends on the direction
    OutputFiles = {};
    if ismember(sProcess.options.direction.Value, [1 3])
        OPTIONS.GrangerDir = 'out';
        OutputFiles = cat(2, OutputFiles, bst_connectivity({sInputA.FileName}, {sInputA.FileName}, OPTIONS));
    end
    if ismember(sProcess.options.direction.Value, [2 3])
        OPTIONS.GrangerDir = 'in';
        OutputFiles = cat(2, OutputFiles, bst_connectivity({sInputA.FileName}, {sInputA.FileName}, OPTIONS));
    end
end




