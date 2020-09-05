function gui_hide( varargin )
% GUI_HIDE: Hide a panel that was shown with the gui_show() function.
%
% USAGE: gui_hide(panelName)
%        gui_hide(bstPanel)
%
% SEE ALSO gui_show

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
% Authors: Francois Tadel, 2008-2014

global GlobalData;

% Headless mode: exit
if (GlobalData.Program.GuiLevel == -1)
    return
end


%% ===== PARSE INPUTS =====
if (nargin == 1)
    % If panel to hide is referenced by its name
    if (ischar(varargin{1}))
        panelName = varargin{1};
    % If panel to hide is referenced by a BstPanel object
    elseif (isa(varargin{1}, 'BstPanel'))
        % Find again panel (to see if it correctly registered in BrainStrom GUI context)
        panelName = get(varargin{1}, 'name');
    else
        error('Usage : gui_hide(panelName) or gui_hide(bstPanel)');
    end
else
    error('Usage : gui_hide(panelName) or gui_hide(bstPanel)');
end
        
% Get the panel object
[bstPanel, iPanel] = bst_get('Panel', panelName);
% If panel is not defined : nothing to do
if isempty(bstPanel)
    return;
end

% Special case: Frequency slider
if strcmpi(panelName, 'FreqPanel')
    jPanelFreq = bst_get('PanelContainer', 'freq');
    jPanelFreq.setVisible(0);
    return;
end


%% ===== EXECUTE HIDING CALLBACK =====
isAccepted = 1;
switch (panelName)
    case 'ChannelEditor'
        isAccepted = panel_channel_editor('PanelHidingCallback');
    case 'EditBfs'
        % Close BFS check 3D viz
        close(findobj(0, '-depth', 1, 'Tag', 'SphereVisuFigure'));
        % Release mutex
        bst_mutex('release', 'EditBfs');
    case 'EeglabConditions'
        bst_mutex('release', 'EeglabConditions');
    case 'ImportBstRawData'
        bst_mutex('release', 'ImportBstRawData');
    case 'ImportEegRawOptions'
        bst_mutex('release', 'ImportEegRawOptions');
    case 'ImportDataOptions'
        bst_mutex('release', 'ImportDataOptions');
    case 'HeadmodelOptions'
        bst_mutex('release', 'HeadmodelOptions');
    case 'InverseOptions'
        bst_mutex('release', 'InverseOptions');
    case 'InverseOptionsBeamformer'
        bst_mutex('release', 'InverseOptionsBeamformer');
    case 'InverseOptionsMinnormOld'
        bst_mutex('release', 'InverseOptionsMinnormOld');
    case 'InverseOptionsWMNE'
        bst_mutex('release', 'InverseOptionsWMNE');
    case 'InverseOptionsMEM'
        bst_mutex('release', 'InverseOptionsMEM');
    case 'OpenmeegOptions'
        bst_mutex('release', 'OpenmeegOptions');
    case 'DuneuroOptions'
        bst_mutex('release', 'DuneuroOptions');
    case 'FemCondOptions'
        bst_mutex('release', 'FemCondOptions');
    case 'BemOptions'
        bst_mutex('release', 'BemOptions');
    case 'SourceGrid'
        bst_mutex('release', 'SourceGrid');
    case 'NoiseCovOptions'
        bst_mutex('release', 'NoiseCovOptions');
    case 'TimefreqOptions'
        bst_mutex('release', 'TimefreqOptions');
    case 'SpikesortingOptions'
        bst_mutex('release', 'SpikesortingOptions');
    case 'ExportBidsOptions'
        bst_mutex('release', 'ExportBidsOptions');
    case 'SearchDatabase'
        bst_mutex('release', 'SearchDatabase');
    case 'Coordinates'
        if gui_brainstorm('isTabVisible', 'Coordinates')
            panel_coordinates('RemoveSelection');
        end
    case 'Dipinfo'
        if gui_brainstorm('isTabVisible', 'Dipinfo')
            panel_dipinfo('RemoveSelection');
        end
    case 'Command'
        
    case 'Record'
        panel_record('PanelHidingCallback');
    case 'EditSsp'
        panel_ssp_selection('PanelHidingCallback');
    case 'ProcessOne'
        bst_mutex('release', 'ProcessOne');
    case 'ProcessTwo'
        bst_mutex('release', 'ProcessTwo');
    case 'Digitize'
        isAccepted = panel_digitize('PanelHidingCallback');
end
% If closing was not accepted
if ~isAccepted
    jContainer = get(bstPanel, 'container');
    if strcmpi(jContainer.type, 'JavaWindow') && isjava(jContainer.handle{1})
        jContainer.handle{1}.show();
    end
    return
end

%% ===== CLOSE CONTAINER =====
% Get panel container
panelContainer = get(bstPanel, 'container');
% Switch between types of panel containers
switch(panelContainer.type)
    % JAVA WINDOW
    case 'JavaWindow'
        % Close the Java window that owns the panel
        panelContainer.handle{1}.dispose();
        
    % MATLAB FIGURE
    case 'MatlabFigure'
        close(panelContainer.handle{1});
        
    % BRAINSTORM PANEL
    case 'BrainstormPanel'
%         % Get Brainstorm panel container
%         jPanel = bst_get('PanelContainer', panelContainer.handle{1});
%         % Remove component from its parent
%         panelParent = jPanel.getParent();
%         panelParent.remove(jPanel);
            
    % BRAINSTORM TAB
    case 'BrainstormTab'
        % Get Brainstorm panel container : can be either a tabbed panel or another panel
        jTabbedPanel = bst_get('PanelContainer', panelContainer.handle{1});

        % Look for a tab that has the panel name in Title
        iTab = 0;
        found = 0;
        while ((iTab < jTabbedPanel.getTabCount()) && ~found)
            tabTitle = jTabbedPanel.getTitleAt(iTab);
            if strcmpi(panelName, tabTitle)
                % Select previous tab
                if (iTab > 0)
                    jTabbedPanel.setSelectedIndex(iTab - 1);
                end
                % Remove tab
                jTabbedPanel.removeTabAt(iTab);
                found = 1;
            else
                iTab = iTab + 1;
            end
        end
            
        % If the tab was not found, it might be in the panel that contains the JTabbedPane
        % (it is the case for non-tabbed panels)
        if (~found)
            % Try to remove component, see what happens
            panelParent = jTabbedPanel.getParent();
            panelParent.remove(get(bstPanel, 'jHandle'));
        end
        
    % PANEL NOT DISPLAYED
    otherwise
        % Nothing to do
end

% Remove panel reference
GlobalData.Program.GUI.panels(iPanel) = [];


end





