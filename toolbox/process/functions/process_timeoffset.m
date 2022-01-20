function varargout = process_timeoffset( varargin )
% PROCESS_TIMEOFFSET: Add/subtract a time offset to the Time vector.

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
% Authors: Francois Tadel, 2010-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Add time offset';
    sProcess.FileTag     = 'timeoffset';
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Pre-process';
    sProcess.Index       = 76;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'matrix', 'timefreq'};
    sProcess.OutputTypes = {'data', 'results', 'matrix', 'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    % Description
    sProcess.options.info.Comment = ['Adds a given time offset (in milliseconds) to the time vector.<BR>' ... 
                                     'The offset can be positive or negative: add a minus sign to remove this offset.<BR><BR>' ...
                                     'Example: The time definition of the input file is [-100ms, +300ms]<BR>' ...
                                     ' - Time offset =&nbsp;&nbsp;100.0ms => New timing will be [0ms, +400ms]<BR>' ...
                                     ' - Time offset = -100.0ms => New timing will be [-200ms, +200ms]<BR><BR>'];
    sProcess.options.info.Type    = 'label';
    sProcess.options.info.Value   = [];
    % === Time offset
    sProcess.options.offset.Comment = 'Time offset:';
    sProcess.options.offset.Type    = 'value';
    sProcess.options.offset.Value   = {0, 'ms', []};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sprintf('%s: %1.2fms', sProcess.Comment, sProcess.options.offset.Value{1} * 1000);
end


%% ===== RUN =====
function sInput = Run(sProcess, sInput) %#ok<DEFNU>
    % Get inputs
    TimeOffset = sProcess.options.offset.Value{1};
    % Apply offset
    sInput.TimeVector = sInput.TimeVector + TimeOffset;
end




