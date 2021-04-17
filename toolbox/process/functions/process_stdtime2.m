function varargout = process_stdtime2( varargin )
% PROCESS_STDTIME2: Uniformize the time vector for pairs of input files.

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
% Authors: Francois Tadel, 2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Interpolate time';
    sProcess.Category    = 'File2';
    sProcess.SubGroup    = 'Standardize';
    sProcess.Index       = 201;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Epileptogenicity#Create_a_movie_with_the_SEEG_signals';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;
    sProcess.isPaired    = 1;
    % Help
    sProcess.options.help.Comment = ['Apply the time vector of the <B>file A</B> to <B>file B</B>.<BR><BR>' ...
                                     'If the number of samples is the same, it simply replaces the Time field.<BR>' ...
                                     'If the number of samples is different, it reinterpolates the values with<BR>' ...
                                     'Matlab function interp1.'];
    sProcess.options.help.Type    = 'label';
    % === Interpolation method
    sProcess.options.method.Comment = 'Interpolation method: ';
    sProcess.options.method.Type    = 'combobox_label';
    sProcess.options.method.Value   = {'spline', {'nearest', 'linear', 'spline', 'pchip', 'v5cubic', 'makima'; ...
                                                  'nearest', 'linear', 'spline', 'pchip', 'v5cubic', 'makima'}};
    % === OVERWRITE
    sProcess.options.overwrite.Comment = 'Overwrite input files';
    sProcess.options.overwrite.Type    = 'checkbox';
    sProcess.options.overwrite.Value   = 0;
    sProcess.options.overwrite.Group   = 'output';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputA, sInputB) %#ok<DEFNU>
    OutputFiles = {};
    % Call recursively the function on each pair of files
    for iFile = 1:length(sInputA)
        OutputFiles = cat(2, OutputFiles, process_stdtime('Run', sProcess, [sInputA(iFile), sInputB(iFile)]));
    end
end



