function varargout = process_ssp_eog( varargin )
% PROCESS_SSP_EOG: Reject cardiac artifact for a group of recordings file
%
% USAGE:  OutputFiles = process_ssp_eog('Run', sProcess, sInputs)

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
    sProcess.Comment     = 'SSP: Eye blinks';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Artifacts';
    sProcess.Index       = 111;
    sProcess.Description = 'http://neuroimage.usc.edu/brainstorm/Tutorials/ArtifactsSsp#SSP:_Eye_blinks';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
   
    % Event name
    sProcess.options.eventname.Comment = 'Event name: ';
    sProcess.options.eventname.Type    = 'text';
    sProcess.options.eventname.Value   = 'blink';
    % Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG';
    % Use existing SSPs
    sProcess.options.usessp.Comment = 'Compute using existing SSP/ICA projectors';
    sProcess.options.usessp.Type    = 'checkbox';
    sProcess.options.usessp.Value   = 1;
    % Default selection of components
    sProcess.options.select.Comment = 'Selected components:';
    sProcess.options.select.Type    = 'value';
    sProcess.options.select.Value   = {1, 'list', 0};
    sProcess.options.select.Hidden  = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    if isfield(sProcess.options, 'eventname') && ~isempty(sProcess.options.eventname.Value)
        Comment = ['SSP EOG: ' sProcess.options.eventname.Value];
    else
        Comment = sProcess.Comment;
    end
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Pre-defined values for ECG
    sProcess.options.eventtime.Value  = {[-.200, .200], 'ms'};
    sProcess.options.bandpass.Value   = {[1.5, 15], 'Hz'};
    sProcess.options.saveerp.Value    = 0;
    sProcess.options.method.Value     = 1;
    % Call the generic version of the event detection
    OutputFiles = process_ssp('Run', sProcess, sInputs);
end



