function gui_release_dialog(panelName)
% GUI_RELEASE_DIALOG: Release (by set isVisible to 0) a blocking modal JDialog
% 
% USAGE: gui_release_dialog(contName)

% INPUT: 
%     - panelName : Panel name, name of the Panel with the modal JDialog
%
% SEE ALSO gui_hide gui_show gui_show_dialog

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
% Authors: Raymundo Cassani, 2026

% Headless mode: exit
global GlobalData;
if (GlobalData.Program.GuiLevel == -1)
    return
end

% No valid argument
if nargin < 1 || isempty(panelName) || ~ischar(panelName)
    return
end

% Get panel
bstPanel = bst_get('Panel', panelName);
if ~isempty(bstPanel)
    jContainer = get(bstPanel, 'container');
    % Check that container is modal JDialog
    if ~isempty(jContainer) && strcmpi(jContainer.type, 'JavaWindow') && ...
            isa(jContainer.handle{1}, 'javax.swing.JDialog') && jContainer.handle{1}.isModal()
        java_call(jContainer.handle{1}, 'setVisible', 'Z', 0);
    end
end