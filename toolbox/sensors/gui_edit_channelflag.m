function gui_edit_channelflag( DataFile )
% GUI_EDIT_CHANNELFLAG: Edit the ChannelFlag array of a MEG/EEG recordings file, with the associated Channel file.
%
% USAGE: gui_edit_channelflag( DataFile )

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
% Authors: Francois Tadel, 2008-2018

global GlobalData;
ChannelFile = [];

%% ===== LOAD CHANNEL/DATA FILE =====
% Progress bar
bst_progress('start', 'Channel editor', 'Initialization...');
% Get the DataFile in the Brainstorm database
[sStudy, iStudy] = bst_get('DataFile', DataFile);
% Try to find file in stat files
if isempty(sStudy)
    [sStudy, iStudy] = bst_get('StatFile', DataFile);
end 
% If DataFile in database
if ~isempty(sStudy)
    % Get channel file
    Channel = bst_get('ChannelForStudy', iStudy);
    if ~isempty(Channel)
        ChannelFile = Channel.FileName;
    end
% DataFile not in database: try absolute reference
elseif file_exist(DataFile)
    % Try to find a channel file in the DataFile directory 
    dirFiles = dir(bst_fullfile(bst_fileparts(DataFile), 'channel*.mat'));
    if ~isempty(dirFiles)
        ChannelFile = bst_fullfile(bst_fileparts(DataFile), dirFiles(1).name);
    end
end
% No ChannelFile
if isempty(ChannelFile)
    bst_error('Channel file not found.', 'Edit ChannelFlag');
    return
end


% ===== START CHANNEL EDITOR =====
% Check if a "Channel Editor" panel already exists
panel = bst_get('Panel', 'ChannelEditor');
% If panel exists
if ~isempty(panel)
    % Close it
    gui_hide(panel);
end
% Create new panel
newpanel = panel_channel_editor('CreatePanel', ChannelFile, DataFile);
if isempty(newpanel)
    bst_progress('stop');
    return
end
% Show panel
bstContainer = gui_show(newpanel, 'JavaWindow', ['Edit ChannelFlag: ', DataFile], 0, 0, 1);
if isempty(bstContainer)
    return;
end

% Get current layout
[jBstArea, FigArea, nScreens, jFigArea, jInsets] = gui_layout('GetScreenBrainstormAreas');
% Place this figure on the screen to take all the possible figure space 
jFrame = bstContainer.handle{1};
jFrame.setLocation(jFigArea.getX(), jFigArea.getY() - jInsets.bottom);
jFrame.setSize(jFigArea.getWidth(), jFigArea.getHeight());

% Set selected sensors
if ~isempty(GlobalData.DataViewer.SelectedRows)
    panel_channel_editor('SetChannelSelection', GlobalData.DataViewer.SelectedRows, 0);
end
bst_progress('stop');





