function varargout = process_evt_detect_eog( varargin )
% PROCESS_EVT_DETECT_EOG: Detect eye blinks in a continuous file, and create set of events called "blink"
%
% USAGE:  OutputFiles = process_evt_detect_eog('Run', sProcess, sInputs)

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
% Authors: Francois Tadel, Elizabeth Bock, 2011-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Detect eye blinks';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 44;
    sProcess.Description = 'http://neuroimage.usc.edu/brainstorm/Tutorials/ArtifactsDetect#Detection:_Blinks';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'raw', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Channel name
    sProcess.options.channelname.Comment = 'Channel name: ';
    sProcess.options.channelname.Type    = 'channelname';
    sProcess.options.channelname.Value   = '';
    % Channel name comment
    sProcess.options.channelhelp.Comment = '<I><FONT color="#777777">You can use the montage syntax here: "ch1, -ch2"</FONT></I>';
    sProcess.options.channelhelp.Type    = 'label';
    % Time window
    sProcess.options.timewindow.Comment = 'Time window:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    % Event name
    sProcess.options.eventname.Comment = 'Event name: ';
    sProcess.options.eventname.Type    = 'text';
    sProcess.options.eventname.Value   = 'blink';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>   
    % Pre-defined set of properties
    %sProcess.options.eventname.Value = 'blink';
    sProcess.options.threshold.Value = {2, 'x std', 2};
    sProcess.options.bandpass.Value  = {[1.5 15], 'Hz', 2};
    sProcess.options.blanking.Value  = {0.8, 'ms', []};
    sProcess.options.isnoisecheck.Value = 1;
    sProcess.options.isclassify.Value   = 1;
    % Call the generic version of the event detection
    OutputFiles = process_evt_detect('Run', sProcess, sInputs);
end




