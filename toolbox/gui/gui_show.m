function [panelContainer, bstPanel] = gui_show( bstPanel, contType, contName, contIcon, isModal, isAlwaysOnTop, isMaximized, winPos )
% GUI_SHOW: Display a BstPanel.
% 
% USAGE: gui_show(bstPanel, contType, contName, contIcon=[], isModal=0, isAlwaysOnTop=0, isMaximized=0)

% INPUT: 
%     - bstPanel : BstPanel object or panel function name (string)
%     - contType : {'JavaWindow', 'BrainstormTab', 'BrainstormPanel'} (Default : 'JavaWindow')
%     - contName : Container name (meaning of this argument depends on the contType value)
%                  => JavaWindow       : name of the Java frame (title of the java window)
%                  => BrainstormFigure : name of the panelContainer in which the panel should be added
%     - contIcon : Icon object (optional)
%     - isModal  : If 1, makes window modal 
%                  => If the contType is 'BrainstormTab', the panel will not be added as a tab
%                     in a Brainstorm panel container, but will fill the whole panel container.
%     - isAlwaysOnTop : If 1, makes window always on top (only for type 'JavaWindow')
%     - isMaximized   : If 1, maximizes window to fit all the available figure space (only for type 'JavaWindow')
%     - winPos        : [x,y] Window position, relative with the main Braintorm frame (only for type 'JavaWindow')
%
% SEE ALSO gui_hide gui_show_dialog

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
% Authors: Francois Tadel, 2008-2017

import org.brainstorm.icon.*;
global GlobalData;

% Initialize returned variables
panelContainer = [];
% Headless mode: exit
if (GlobalData.Program.GuiLevel == -1)
    return
end


%% ===== PARSE INPUTS =====
if (nargin < 2) || isempty(contType)
    contType = 'JavaWindow';
end
if (nargin < 3) || isempty(contName) || ~ischar(contName)
    contName = 'New panel';
end
if (nargin < 4) || isempty(contIcon) || ~isa(contIcon, 'javax.swing.Icon')
    contIcon = [];
end
if (nargin < 5) || isempty(isModal)
    isModal = 0;
end
if (nargin < 6) || isempty(isAlwaysOnTop)
    isAlwaysOnTop = 0;
end
if (nargin < 7) || isempty(isMaximized)
    isMaximized = 0;
end
if (nargin < 8) || isempty(winPos)
    winPos = [];
end


%% ===== GET PANEL =====
if ischar(bstPanel)
    bstPanel = feval(bstPanel, 'CreatePanel');
    if isempty(bstPanel)
        return;
    end
elseif ~isa(bstPanel, 'BstPanel')
    error('First argument must be a ''BstPanel'' object.');
end
panelName    = get(bstPanel, 'name');
jPanelHandle = get(bstPanel, 'jHandle');
% Check that the panel is not already registered
if gui_brainstorm('isTabVisible', panelName)
    % Focus previous panel
    bstPanel = bst_get('Panel', panelName);
    jPanelHandle = get(bstPanel, 'jHandle');
    if ~isempty(jPanelHandle.getRootPane()) && ~isempty(jPanelHandle.getRootPane.getParent())
        jPanelHandle.getTopLevelAncestor().show();
    end
    % Return container
    panelContainer = get(bstPanel, 'container');
    return
end



%% ===== SWITCH BETWEEN CONTAINER TYPES =====
switch (contType)
    % =======================================================================
    % ==== JAVA WINDOW ======================================================
    % =======================================================================
    case 'JavaWindow'
        % Get parent frame
        jParent = bst_get('BstFrame');
        % If modal window : JDIALOG
        if (isModal)
            % Make it dependent on the the main Brainstorm JFrame, if it exists
            jWindow = java_create('javax.swing.JDialog', 'Ljava.awt.Frame;Ljava.lang.String;Z', jParent, contName, 1);
        % If not modal : JFRAME
        else
            jWindow = java_create('javax.swing.JFrame', 'Ljava.lang.String;', contName);
            jWindow.setIconImage(IconLoader.ICON_APP.getImage());
        end
        % Configure window
        jWindow.setDefaultCloseOperation(javax.swing.JFrame.DO_NOTHING_ON_CLOSE);
        java_setcb(jWindow, 'WindowClosingCallback', @ClosePanelCallback);
        % Add the BST Panel
        jWindow.getContentPane.add(jPanelHandle);
        % Always on top
        if isAlwaysOnTop
            jWindow.setAlwaysOnTop(1);
        end
        % Maximized over the figure area (ONLY WHEN TILED LAYOUT)
        if isMaximized && strcmpi(bst_get('Layout', 'WindowManager'), 'TileWindows')
            % Get current layout
            [jBstArea, FigArea, nbScreens, jFigArea, jInsets] = gui_layout('GetScreenBrainstormAreas');
            % Place this figure on the screen to take all the possible figure space 
            jWindow.setSize(FigArea(3), FigArea(4));
            jWindow.setLocation(FigArea(1)-1, jBstArea.getY() - jInsets.bottom);
        % Normal display
        else
            % Set window size and location
            jWindow.pack();
            jWindow.setLocationRelativeTo(jParent);
            % Set figure position
            if (length(winPos) >= 2)
                if ~isempty(jParent)
                    winPos(1) = winPos(1) + jParent.getLocation().getX();
                    winPos(2) = winPos(2) + jParent.getLocation().getY();
                end   
                jWindow.setLocation(winPos(1),winPos(2));
            end
        end
        % Show window: KEEP IT WITH AWTINVOKE
        awtinvoke(jWindow, 'setVisible(Z)', 1);
        % Returned variable
        panelContainer.type   = 'JavaWindow';
        panelContainer.handle = {jWindow};

    % =======================================================================
    % ==== BRAINSTORM TAB ===================================================
    % =======================================================================
    case 'BrainstormTab' 
        % Add a Swing components tree to the main brainstorm window.
        % The component can be added in one of the registered panel containers.
        % The panel can be added either as a new tab in the target area, or 
        % as the whole target (in this case, the other target tabbed panels are hidden)

        % Get the 'contName' tabbed panel 
        jTabContainer = bst_get('PanelContainer', contName);
        % If container does not exist, return with a warning
        if (isempty(jTabContainer))
            warning('Brainstorm:InvalidContainer', 'Destination "%s" is not a valid Swing tab panel', contName);
            return;
        end
        % If this panel is supposed to tabbed => just add it as a new tab
        if (~isModal)
            % Attach the panel to the panel container
            if strcmpi(contName, 'tools')
                iTab = jTabContainer.getTabCount() - 1;
            else
                iTab = jTabContainer.getTabCount();
            end
            jTabContainer.insertTab(panelName, contIcon, jPanelHandle, '', iTab);
            % Make sure that the tabbed container is visible
            jTabContainer.setVisible(1);
        % Else : 1) add it to the parent of the jTabContainer
        else
            % Add panel in the container's parent
            jTabContainer.getParent().add(jPanelHandle);
            % Hide the tab container
            jTabContainer.setVisible(0);
        end
        
        % Returned variable
        panelContainer.type   = 'BrainstormTab';
        panelContainer.handle = {contName};
        

    % =======================================================================
    % ==== BRAINSTORM PANEL ===================================================
    % =======================================================================
    case 'BrainstormPanel' 
        % Get the 'contName' tabbed panel 
        jContainer = bst_get('PanelContainer', contName);
        % If container does not exist, return with a warning
        if (isempty(jContainer))
            warning('Brainstorm:InvalidContainer', 'Destination "%s" is not a valid Swing panel', contName);
            return;
        end
        % Add panel in the container
        jContainer.add(jPanelHandle);
        % Returned variable
        panelContainer.type   = 'BrainstormPanel';
        panelContainer.handle = {contName};
        
    otherwise
        error('Invalid container type.');
end


%% ===== REFERENCE NEW PANEL =====
% Update bstPanel structure
bstPanel = set(bstPanel, 'container', {panelContainer.type, panelContainer.handle{:}});
% If GUI context is defined
if isempty(GlobalData.Program.GUI.panels)
    GlobalData.Program.GUI.panels = bstPanel;
else
    % Add the new panel to the panel list
    GlobalData.Program.GUI.panels(end+1) = bstPanel;
end


%% =================================================================================
%  === CALLBACKS  ==================================================================
%  =================================================================================
    function ClosePanelCallback(varargin)
        try
            gui_hide(bstPanel);
        catch
            if strcmpi(contType, 'JavaWindow')
                warning('Brainstorm:PanelNotRegistered', 'Panel ''%s'' was not registered in Brainstorm GUI context, hide forced.', panelName);
                jWindow.dispose();
            end
        end
    end


end





