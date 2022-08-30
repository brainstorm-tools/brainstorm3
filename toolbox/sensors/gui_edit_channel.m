function jFrame = gui_edit_channel( ChannelFile )
% GUI_EDIT_CHANNEL: Load, edit and save a channel file.
%
% USAGE: gui_edit_channel( ChannelFile )

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

% Progress bar
bst_progress('start', 'Channel editor', 'Initialization...');
% Check if a "Channel Editor" panel already exists
panel = bst_get('Panel', 'ChannelEditor');
% If panel exists
if ~isempty(panel)
    % Close it
    gui_hide(panel);
end
% Create new panel
bstPanel = panel_channel_editor('CreatePanel', ChannelFile);
if isempty(bstPanel)
    bst_progress('stop');
    return;
end
% Show panel in a Java window
bstContainer = gui_show(bstPanel, 'JavaWindow', ['Channel editor: ' ChannelFile], [], 0, 0, 1);
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
% Progress bar
bst_progress('stop');


