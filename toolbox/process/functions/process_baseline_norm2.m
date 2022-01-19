function varargout = process_baseline_norm2( varargin )
% PROCESS_BASELINE_NORM2: Normalization with respect to a baseline (A=baseline).

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
% Authors: Francois Tadel, 2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Baseline normalization (A=baseline)';
    sProcess.FileTag     = @GetFileTag;
    sProcess.Category    = 'Filter2';
    sProcess.SubGroup    = 'Standardize';
    sProcess.Index       = 205;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/SourceEstimation#Z-score';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;
    % Default values for some options
    sProcess.isSourceAbsolute = 0;
    sProcess.processDim       = 1;    % Process channel by channel
    sProcess.isPaired         = 1;
    
    % === Process description
    sProcess.options.label1.Comment = ['This process normalizes each signal and frequency bin (FilesB)<BR>' ...
                                       'with respect to a baseline (FilesA). In the formulas below:<BR>'...
                                       '&nbsp; <B>x</B> = data to normalize (FilesB)<BR>' ...
                                       '&nbsp; <B>&mu;</B> = mean over the baseline (FilesA) <FONT color=#7F7F7F>[mean(x(iBaseline))]</FONT><BR>' ...
                                       '&nbsp; <B>&sigma;</B> = standard deviation over the baseline (FilesA) <FONT color=#7F7F7F>[std(x(iBaseline))]</FONT><BR><BR>' ...
                                       '<B><U>Data selection</U></B>:'];
    sProcess.options.label1.Type = 'label';
    % Common options
    sProcess = process_baseline_norm('DefineOptions', sProcess);
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = process_baseline_norm('FormatComment', sProcess);
end


%% ===== GET FILE TAG =====
function fileTag = GetFileTag(sProcess)
    fileTag = sProcess.options.method.Value;
end


%% ===== RUN =====
function sInputB = Run(sProcess, sInputA, sInputB) %#ok<DEFNU>
    % Call the corresponding process1
    sInputB = process_baseline_norm('Run', sProcess, sInputA, sInputB);
end



