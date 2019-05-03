function varargout = process_channel_settype( varargin )
% PROCESS_CHANNEL_SETTYPE: Project electrodes on the scalp surface.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2014

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Set channels type';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Channel file'};
    sProcess.Index       = 32;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Epilepsy?highlight=%28Set+channel+type%29#Prepare_the_channel_file';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Channel types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = '';
    sProcess.options.sensortypes.InputTypes = {'data', 'raw'};
    % === Channel type
    sProcess.options.newtype.Comment = 'New channel type: ';
    sProcess.options.newtype.Type    = 'text';
    sProcess.options.newtype.Value   = '';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % Get options
    ChannelSelect = sProcess.options.sensortypes.Value;
    NewType = sProcess.options.newtype.Value;
    % Check options
    if isempty(NewType)
        bst_report('Error', sProcess, [], 'Cannot set channels to an empty type.');
        return
    end
    
    % Get channel studies
    [tmp, iChanStudies] = bst_get('ChannelForStudy', [sInputs.iStudy]);
    iChanStudies = unique(iChanStudies);
    % Loop on the channel studies
    for iFile = 1:length(iChanStudies)
        % Get channel study
        sStudy = bst_get('Study', iChanStudies(iFile));
        if isempty(sStudy.Channel)
            bst_report('Error', sProcess, [], 'No channel file available.');
            return
        end
        % Read channel file
        ChannelFile = sStudy.Channel(1).FileName;
        ChannelMat = in_bst_channel(ChannelFile);
        % Find selected sensors
        iChannels = channel_find(ChannelMat.Channel, ChannelSelect);
        if isempty(iChannels)
            bst_report('Error', sProcess, [], 'No channel selected.');
            return
        end
        % Update channels type
        [ChannelMat.Channel(iChannels).Type] = deal(NewType);
        % Save modifications in channel file
        bst_save(file_fullpath(ChannelFile), ChannelMat, 'v7');
        % Update database
        [sStudy.Channel.Modalities, sStudy.Channel.DisplayableSensorTypes] = channel_get_modalities(ChannelMat.Channel);
        bst_set('Study', iChanStudies(iFile), sStudy);
    end
    % Return all the files in input
    OutputFiles = {sInputs.FileName};
end



