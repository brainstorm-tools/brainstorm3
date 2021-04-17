function varargout = process_ssp2_ecg( varargin )
% PROCESS_SSP2_ECG: Reject cardiac artifact for a group of recordings file (calculates SSP from FilesA and applies them to FilesB)
%
% USAGE:  OutputFiles = process_ssp2_ecg('Run', sProcess, sInputs)

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
% Authors: Francois Tadel, Elizabeth Bock, 2011-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'SSP: Heartbeats';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Artifacts';
    sProcess.Index       = 300;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ArtifactsSsp?highlight=%28Process2%29#Troubleshooting';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'raw', 'raw'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;

    % Notice
    sProcess.options.label1.Comment = '<B>Files A</B> = Artifacts samples (raw or epoched)<BR>&nbsp;<B>Files B</B> = Files to clean (raw)<BR><BR>';
    sProcess.options.label1.Type    = 'label';
    % Event name
    sProcess.options.eventname.Comment = 'Event name: ';
    sProcess.options.eventname.Type    = 'text';
    sProcess.options.eventname.Value   = 'cardiac';
    sProcess.options.eventname.InputTypes = {'raw'};
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
        Comment = ['SSP ECG: ' sProcess.options.eventname.Value];
    else
        Comment = sProcess.Comment;
    end
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputsA, sInputsB) %#ok<DEFNU>
    % Pre-defined values for ECG
    sProcess.options.eventtime.Value  = {[-.040, .040], 'ms'};
    sProcess.options.bandpass.Value   = {[13, 40], 'Hz'};
    sProcess.options.saveerp.Value    = 0;
    sProcess.options.method.Value     = 1;
    % Call the generic version of the event detection
    OutputFiles = process_ssp2('Run', sProcess, sInputsA, sInputsB);
end



