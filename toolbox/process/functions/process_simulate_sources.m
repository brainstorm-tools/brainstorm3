function varargout = process_simulate_sources( varargin )
% PROCESS_SIMULATE_SOURCES: Simulate full source maps based on some scouts.
%
% USAGE:  OutputFiles = process_simulate_sources('Run', sProcess, sInputA)
 
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
% Authors: Guiomar Niso, 2013-2016
%          Francois Tadel, 2013-2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Full source maps from scouts';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Simulate'; 
    sProcess.Index       = 915;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Simulations#Generate_full_source_maps_from_scouts';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'matrix'};
    sProcess.OutputTypes = {'results'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Notice inputs
    sProcess.options.label1.Comment = ['<FONT COLOR="#777777">&nbsp;- N signals (constrained) or 3*N signals (unconstrained)<BR>' ...
                                       '&nbsp;- N scouts: selected below</FONT>'];
    sProcess.options.label1.Type    = 'label';
    sProcess.options.label1.Group   = 'input';
    % Notice algorithm
    sProcess.options.label2.Comment = ['<FONT COLOR="#777777">Algorithm (first part of process <I>Simulate recordings from scouts</I>):<BR>' ...
                                       '&nbsp;- Create an empty source file with zeros at every vertex<BR>' ...
                                       '&nbsp;- Assign each signal #i to all the vertices within scout #i<BR>' ... 
                                       '&nbsp;- Add random noise to the source maps (optional):<BR>' ...
                                       '&nbsp;&nbsp;&nbsp;<I>Src = Src + SNR1 .* (rand(size(Src))-0.5) .* max(abs(Src(:)));</I><BR><BR></FONT>'];
    sProcess.options.label2.Type    = 'label';
    % === SCOUTS
    sProcess.options.scouts.Comment = '';
    sProcess.options.scouts.Type    = 'scout';
    sProcess.options.scouts.Value   = {};
    sProcess.options.scouts.Group   = 'input';
    % === ADD NOISE
    sProcess.options.isnoise.Comment    = 'Add noise';
    sProcess.options.isnoise.Type       = 'checkbox';
    sProcess.options.isnoise.Value      = 0;
    sProcess.options.isnoise.Controller = 'Noise';
    % === LEVEL OF NOISE (SNR1)
    sProcess.options.noise1.Comment = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Level of source noise (SNR1):';
    sProcess.options.noise1.Type    = 'value';
    sProcess.options.noise1.Value   = {0, '', 2};
    sProcess.options.noise1.Class   = 'Noise';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput) %#ok<DEFNU>
    % Prepare process "Simulate recordings from scouts" without saving the data file
    sProcess.options.savesources.Value = 1;
    sProcess.options.savedata.Value = 0;
    sProcess.options.noise2.Value = {0};
    % Call process
    OutputFiles = process_simulate_recordings('Run', sProcess, sInput);
end

