function varargout = process_headpoints_refine( varargin )
% PROCESS_HEADPOINTS_REMOVE: Remove head points from the channel file below a certain level.
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
% Authors: Francois Tadel, 2015-2021

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Refine registration';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Channel file'};
    sProcess.Index       = 60;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ChannelFile#Automatic_registration';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Title
    sProcess.options.title.Comment = [...
        'Refine the MEG/MRI registration using digitized head points.<BR>' ...
        '<FONT color="#707070">If (tolerance > 0): fit the head points, remove the digitized points the most<BR>' ...
        'distant to the scalp surface, and fit again the the head points on the scalp.</FONT><BR><BR>'];
    sProcess.options.title.Type    = 'label';
    % Tolerance
    sProcess.options.tolerance.Comment = 'Tolerance (outlier points to ignore):';
    sProcess.options.tolerance.Type    = 'value';
    sProcess.options.tolerance.Value   = {0, '%', 0};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Get options
    tolerance = sProcess.options.tolerance.Value{1} / 100;
    % Get all the channel files 
    uniqueChan = unique({sInputs.ChannelFile});
    % Loop on all the channel files
    for i = 1:length(uniqueChan)
        % Refine registration
        [ChannelMat, R, T, isSkip, isUserCancel, strReport] = channel_align_auto(uniqueChan{i}, [], 0, 0, tolerance);
        if ~isempty(strReport)
            bst_report('Info', sProcess, sInputs, strReport);
        end
    end
    % Return all the files in input
    OutputFiles = {sInputs.FileName};
end




