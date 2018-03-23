function varargout = process_tuning_curves( varargin )
% PROCESS_TUNING_CURVES
%
% USAGE: OutputFiles = process_tuning_curves('Run', sProcess, sInputs)

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
% Authors: Martin Cousineau, 2018

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Tuning Curves';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Electrophysiology';
    sProcess.Index       = 1203;
    sProcess.Description = 'www.in.gr';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 0;
    % === EVENTS SELECTION ===
    sProcess.options.label1.Comment = 'Select which events to plot (X axis) and spikes (Y axis) to count.';
    sProcess.options.label1.Type    = 'label';
    sProcess.options.eventsel.Comment = 'Events';
    sProcess.options.eventsel.Type    = 'event_ordered';
    sProcess.options.eventsel.Value   = {};
    sProcess.options.eventsel.Spikes  = 'exclude';
    % === SPIKES SELECTION ===
    sProcess.options.spikesel.Comment    = 'Spikes';
    sProcess.options.spikesel.Type       = 'event';
    sProcess.options.spikesel.Value      = {};
    sProcess.options.spikesel.Spikes  = 'only';
    % === SELECT: TIME WINDOW
    sProcess.options.timewindow.Comment    = 'Time window:';
    sProcess.options.timewindow.Type       = 'timewindow';
    sProcess.options.timewindow.Value      = [];
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    global GlobalData;
    OutputFiles = {};
    ProtocolInfo = bst_get('ProtocolInfo');
    
    % Compute on each raw input independently
    for i = 1:length(sInputs)
        disp(sProcess.options.eventsel.Value);
        disp(sProcess.options.spikesel.Value);
    end
    
end


