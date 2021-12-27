function varargout = process_ssp_apply( varargin )
% PROCESS_APPLY_COMP: Apply 3rd order gradient correction + SSP to a continuous file

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
% Authors: Francois Tadel, 2011

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Apply SSP & CTF compensation';
    sProcess.FileTag     = 'clean';
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Artifacts';
    sProcess.Index       = 113;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/TutMindNeuromag?highlight=(Apply+SSP)#Remove:_60Hz_and_harmonics';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Default values for some options
    sProcess.processDim  = 2;    % Process time by time
    % Description
    sProcess.options.label1.Comment = ['This process creates an exact copy of the input file, but<BR>' ...
                                       'with all the selected linear operators applied to the values in the file,<BR>' ...
                                       'instead of being applied on the fly to the original recordings<BR>' ...
                                       '(SSP projectors, ICA mixing matrices, EEG re-referencing, CTF compensation).<BR><BR>' ...
                                       'Before using this process, check the linear operator currently selected:<BR>' ...
                                       'tab Record > menu Artifacts > Select active projectors.<BR><BR>' ...
                                       'In the new copy of the file, the projectors cannot be unselected anymore.'];
    sProcess.options.label1.Type    = 'label';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function sInput = Run(sProcess, sInput) %#ok<DEFNU>
    % NOTHING TO DO
    % CTF 3rd order comp + SSP are applied by default when reading in bst_process
end




