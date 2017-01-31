function varargout = process_stdtime( varargin )
% PROCESS_STDTIME: Uniformize the time vector for a list of input files.

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2016 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2012-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Uniform epoch time';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Standardize';
    sProcess.Index       = 302;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 2;
    sProcess.isSeparator = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Options
    OutputFiles = {};
    Time = [];
    % Process files one by one
    for iFile = 1:length(sInputs)
        % Load file
        [sMatrix, matName] = in_bst(sInputs(iFile).FileName);
        % Check if there is a non-empty time vector
        if ~isfield(sMatrix, 'Time') || isempty(sMatrix.Time)
            bst_report('Error', sProcess, sInputs(iFile), 'File does not have a Time vector.');
            return;
        end
        % First file: define time reference
        if (iFile == 1)
            Time = sMatrix.Time;
        % Following files: check time
        elseif (length(sMatrix.Time) ~= length(Time))
            bst_report('Error', sProcess, sInputs(iFile), 'Time dimension is not compatible with the first file.');
            continue;
        % Save first time vector in the file
        else
            save(file_fullpath(sInputs(iFile).FileName), 'Time', '-append');
            OutputFiles{end+1} = sInputs(iFile).FileName;
        end
    end
end



