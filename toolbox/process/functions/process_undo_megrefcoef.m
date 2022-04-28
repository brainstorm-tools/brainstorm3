function varargout = process_undo_megrefcoef( varargin )
% PROCESS_UNDO_MEGREFCOEF: Undo 3rd order gradient correction (4D or CTF MEG recordings)

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
% Authors: Francois Tadel, 2017

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Undo 4D/CTF noise compensation';
    sProcess.FileTag     = 'undo';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Artifacts';
    sProcess.Index       = 113;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    % Default values for some options
    sProcess.processDim  = 2;    % Process time by time
    
    % Description
    sProcess.options.help.Comment = ['This process computes a spatial projector that cancels the effect <BR>' ...
                                     'of the 4D or CTF MEG 3rd order gradient noise cancellation. <BR><BR>' ...
                                     'To review the projector computed by this process: <BR>' ...
                                     'Tab Record > menu Artifacts > Select active projectors.'];
    sProcess.options.help.Type    = 'label';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput) %#ok<DEFNU>
    OutputFiles = {};
    % Load channel file
    ChannelMat = in_bst_channel(sInput.ChannelFile);
    % Load sFile structure
    DataMat = in_bst_data(sInput.FileName, 'F');
    sFile = DataMat.F;
    % If there is no compensation matrix available: error
    if isempty(ChannelMat.MegRefCoef)
        bst_report('Error', sProcess, sInput, 'There is no noise compensation matrix in this file.');
        return;
    % If the noise compensation matrix is currently not applied to the recordings: no need to undo
    elseif (sFile.prop.currCtfComp ~= sFile.prop.destCtfComp)
        bst_report('Warning', sProcess, sInput, ['The noise compensation is currently not applied to the recordings.' 10 ...
                                                 'You may not need this process to cancel it: ' 10 ...
                                                 'To ignore it from the display, click on the [CTF] button in the Record tab.' 10 ...
                                                 'To ignore it from the file import, unselect the corresponding option']);
    end

    % Get MEG sensors
    iMeg = channel_find(ChannelMat.Channel, 'MEG');
    iRef = channel_find(ChannelMat.Channel, 'MEG REF');
    if isempty(iRef)
        bst_report('Error', sProcess, sInput, 'The reference channels are not included in the recordings. Cannot undo the noise compensation.');
        return;
    end
    % Compute projector from MegRefCoef matrix
    P = eye(length(ChannelMat.Channel));
    P(iMeg,iRef) = -ChannelMat.MegRefCoef;
    Pinv = inv(P);
    % Create projector structure
    proj = db_template('projector');
    proj.Components = Pinv;
    proj.Comment    = 'Undo noise compensation';
    proj.Status     = 1;
    
    % Add projector to channel file
    [newproj, errMsg] = import_ssp(sInput.ChannelFile, proj, 0, 1);
    if ~isempty(errMsg)
        bst_report('Error', sProcess, sInput, errMsg);
        return;
    end
    % Return modified file
    OutputFiles = {sInput.FileName};
end




