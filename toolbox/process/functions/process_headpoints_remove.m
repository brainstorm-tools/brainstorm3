function varargout = process_headpoints_remove( varargin )
% PROCESS_HEADPOINTS_REMOVE: Remove head points from the channel file below a certain level.
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
% Authors: Francois Tadel, 2015-2018

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Remove head points';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Channel file'};
    sProcess.Index       = 63;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ChannelFile#Automatic_registration';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    % Title
    sProcess.options.title.Comment = ['Remove the head points below a certain Z-thresold.<BR>' ... 
                                      ' - <B>Z=0</B> : Nasion, left ear, right ear<BR> - <B>Z>0</B> : Towards the top of the head<BR> - <B>Z&lt;0</B> : Towards the neck.<BR><BR>'];
    sProcess.options.title.Type    = 'label';
    % Options: tolerance
    sProcess.options.zlimit.Comment = 'Limit Z-coordinate: ';
    sProcess.options.zlimit.Type    = 'value';
    sProcess.options.zlimit.Value   = {0, 'mm', 0};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Get options
    zValue = sProcess.options.zlimit.Value{1} / 1000;
    % Get all the channel files 
    uniqueChan = unique({sInputs.ChannelFile});
    % Loop on all the channel files
    for i = 1:length(uniqueChan)
        % Get first input file for this subject
        strMsg = RemoveHeadpoints(uniqueChan{i}, zValue);
        % Report message
        if ~isempty(strMsg)
            bst_report('Info', sProcess, sInputs, strMsg);
        end
    end
    % Return all the files in input
    OutputFiles = {sInputs.FileName};
end


%% ===== REMOVE HEAD POINTS =====
function strMsg = RemoveHeadpoints(ChannelFile, zLimit)
    % Parse inputs
    if (nargin < 2) || isempty(zLimit)
        zLimit = [];
    end
    % Load channel file
    ChannelMat = in_bst_channel(ChannelFile);
    % Display warning: no head points
    if ~isfield(ChannelMat, 'HeadPoints') || isempty(ChannelMat.HeadPoints) || isempty(ChannelMat.HeadPoints.Label)
        strMsg = 'No head points in the file.';
        return;
    end
    % Initial head points number
    nPoints = length(ChannelMat.HeadPoints.Label);
    % Remove selected head points
    if isempty(zLimit) 
        ChannelMat.HeadPoints = [];
        iDelete = 1:nPoints;
    else
        % Get EXTRA points
        iExtra = find(strcmpi(ChannelMat.HeadPoints.Type, 'EXTRA'));
        % Find the points below the z-threshold
        iDelete = find(ChannelMat.HeadPoints.Loc(3,iExtra) <= zLimit);
        % Remove the points
        if (length(iDelete) == nPoints)
            ChannelMat.HeadPoints = [];
        elseif ~isempty(iDelete)
            ChannelMat.HeadPoints.Loc(:,iExtra(iDelete)) = [];
            ChannelMat.HeadPoints.Label(iExtra(iDelete)) = [];
            ChannelMat.HeadPoints.Type(iExtra(iDelete))  = [];
        end
    end
    % Message: head points removed
    strMsg = sprintf('%d head points removed, %d points left.', length(iDelete), nPoints - length(iDelete));
    % History: Reamove all head points
    ChannelMat = bst_history('add', ChannelMat, 'headpoints', strMsg);
    % Save file back
    bst_save(file_fullpath(ChannelFile), ChannelMat, 'v7');
end





