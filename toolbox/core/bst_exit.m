function status = bst_exit()
% BST_EXIT: Exit Brainstorm
% Save database, remove callbacks, close windows, reset environment.
%
% Return : 1 if exited
%          0 if Brainstorm was not started
%         -1 if exit process was cancelled

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2013
global GlobalData

% Check that Brainstorm was fully started
if ~isappdata(0, 'BrainstormRunning')
    disp('BST> Warning: Brainstorm is not started.');
    status = 0;
    return
end
% Get GUI handles
ctrl = bst_get('BstControls');


%% ===== UNLOAD DATASETS ====
% Unload all data
isCancel = bst_memory('UnloadAll', 'Forced');
if isCancel
    status = -1;
    return;
end


%% ===== REMOVE ALL IMPORTANT CALLBACKS =====
% Stop execution
rmappdata(0, 'BrainstormRunning');
% Protocols list
if isfield(ctrl, 'jComboBoxProtocols') && ~isempty(ctrl.jComboBoxProtocols)
    java_setcb(ctrl.jToolButtonSubject,     'ItemStateChangedCallback', []);
    java_setcb(ctrl.jToolButtonStudiesSubj, 'ItemStateChangedCallback', []);
    java_setcb(ctrl.jToolButtonStudiesCond, 'ItemStateChangedCallback', []);
    comboBoxModel = ctrl.jComboBoxProtocols.getModel();
    java_setcb(comboBoxModel, 'ContentsChangedCallback', []);
end
% Panel SCOUTS
scoutsManagerControls = bst_get('PanelControls', 'Scout');
if ~isempty(scoutsManagerControls)
    java_setcb(scoutsManagerControls.jListScouts, 'ValueChangedCallback', []);
end
% Panel CLUSTERS
clustersManagerControls = bst_get('PanelControls', 'Cluster');
if ~isempty(clustersManagerControls)
    java_setcb(clustersManagerControls.jListClusters, 'ValueChangedCallback', []);
end
% PanelContainer TOOLS
jTabpaneTools = bst_get('PanelContainer', 'Tools');
if ~isempty(jTabpaneTools)
    java_setcb(jTabpaneTools, 'StateChangedCallback', []);
end


%% ===== CLOSE WINDOW =====
% Hide all the registered panels
listPanels = GlobalData.Program.GUI.panels;
for iPanel = 1:length(listPanels)
    gui_hide(listPanels(iPanel)); 
end
% Close Brainstorm main window
ctrl.jBstFrame.dispose();
% Release Brainstorm global mutex
bst_mutex('release', 'Brainstorm');


%% ===== SAVE DATABASE =====
db_save(1);
% Close file to indicate that Brainstorm was started
StartFile = bst_fullfile(bst_get('BrainstormUserDir'), 'is_started.txt');
fclose('all');
% Delete the start file
if file_exist(StartFile)
    file_delete(StartFile, 1);
end

%% ===== RESET ALL VARIABLES =====
% Remove global data
GlobalData = [];

disp('BST> Brainstorm stopped.');
status = 1;


