function varargout = figure_connect_viz( varargin )
% FIGURE_CONNECT_VIZ: Creation and callbacks for connectivity figures.
%
% USAGE:  hFig = figure_connect_viz('CreateFigure', FigureId)
 
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
% Authors: Sebastien Dery, 2013; Francois Tadel, 2013-2014; Martin
% Cousineau, 2019; Helen Lin & Yaqi Li, 2020-2021
 
disp('figure_connect_viz.m : ' + string(varargin(1))) % @TODO: remove test
 
eval(macro_method);
end
 
%% ===== CREATE FIGURE =====
% NOTE: updated remove ogl
function hFig = CreateFigure(FigureId) %#ok<DEFNU>
    % Create new figure
    %TODO: replace renderer 'Renderer',              'opengl', ...
    hFig = figure('Visible',               'off', ...
                  'NumberTitle',           'off', ...
                  'IntegerHandle',         'off', ...
                  'MenuBar',               'none', ...
                  'Toolbar',               'none', ...
                  'DockControls',          'off', ...earnadd
                  'Units',                 'pixels', ...
                  'Color',                 [0 0 0], ...
                  'Pointer',               'arrow', ...
                  'BusyAction',            'queue', ...
                  'Interruptible',         'off', ...
                  'HitTest',               'on', ...
                  'Tag',                   FigureId.Type, ...
                  'CloseRequestFcn',       @(h,ev)bst_figures('DeleteFigure',h,ev), ...
                  'KeyPressFcn',           @(h,ev)bst_call(@FigureKeyPressedCallback,h,ev), ...
                  'KeyReleaseFcn',         @(h,ev)bst_call(@FigureKeyReleasedCallback,h,ev), ...
                  'WindowButtonDownFcn',   @FigureMouseDownCallback, ...
                  'WindowButtonMotionFcn', @FigureMouseMoveCallback, ...
                  'WindowButtonUpFcn',     @FigureMouseUpCallback, ...
                  'WindowScrollWheelFcn',  @(h,ev)FigureMouseWheelCallback(h,ev), ...
                  bst_get('ResizeFunction'), @(h,ev)ResizeCallback(h,ev));
    
    % Prepare figure appdata
    setappdata(hFig, 'FigureId', FigureId);
    setappdata(hFig, 'hasMoved', 0);
    setappdata(hFig, 'isPlotEditToolbar', 0);
    setappdata(hFig, 'isStatic', 0);
    setappdata(hFig, 'isStaticFreq', 1);
    setappdata(hFig, 'Colormap', db_template('ColormapInfo'));
    setappdata(hFig, 'GraphSelection', []);
    
    % Time-freq specific appdata
    setappdata(hFig, 'Timefreq', db_template('TfInfo'));
    
    % Display
    setappdata(hFig, 'NodeDisplay', 1);
    setappdata(hFig, 'HierarchyNodeIsVisible', 1);
    setappdata(hFig, 'MeasureLinksIsVisible', 1);
    setappdata(hFig, 'RegionLinksIsVisible', 0);
    setappdata(hFig, 'RegionFunction', 'mean');
    setappdata(hFig, 'LinkTransparency',  0);
        
    % Default Camera variables
    setappdata(hFig, 'CameraZoom', 6); %TODO: remove
    setappdata(hFig, 'CamPitch', 0.5 * 3.1415);
    setappdata(hFig, 'CamYaw', -0.5 * 3.1415);
    setappdata(hFig, 'CameraPosition', [0 0 36]); % %TODO: remove
    setappdata(hFig, 'CameraTarget', [0 0 -0.5]); % %TODO: remove 
    
    % Add colormap
    bst_colormaps('AddColormapToFigure', hFig, 'connectn');
end
 
%% ===========================================================================
%  ===== FIGURE CALLBACKS ====================================================
%  ===========================================================================
%% ===== COLORMAP CHANGED CALLBACK =====
function ColormapChangedCallback(hFig) %#ok<DEFNU>
    UpdateColormap(hFig);
end
 
%% ===== CURRENT TIME CHANGED =====
function CurrentTimeChangedCallback(hFig)   %#ok<DEFNU>
    % If no time in this figure
    if getappdata(hFig, 'isStatic')
        return;
    end
    % If there is time in this figure
    UpdateFigurePlot(hFig);
end
 
%% ===== CURRENT FREQ CHANGED =====
function CurrentFreqChangedCallback(hFig)   %#ok<DEFNU>
    % If no frequencies in this figure
    if getappdata(hFig, 'isStaticFreq')
        return;
    end
    % Update figure
    UpdateFigurePlot(hFig);
end
 
 
%% ===== DISPOSE FIGURE =====
% NOTE: updated and removed ogl
function Dispose(hFig) %#ok<DEFNU>
    %NOTE: do not need to delete gcf (curr figure) because this is done in
    %bst_figures(DeleteFigure)
    
    %====Delete Graphics Objects and Clear Variables====
    if (isappdata(hFig,'AllNodes')) 
        deleteAllNodes(hFig);
        rmappdata(hFig,'AllNodes');
    end
    
    if (isappdata(hFig,'MeasureLinks'))
        delete(getappdata(hFig,'MeasureLinks'));
        rmappdata(hFig,'MeasureLinks');
    end
    
    if (isappdata(hFig,'RegionLinks'))
        delete(getappdata(hFig,'RegionLinks'));
        rmappdata(hFig,'RegionLinks');
    end
    
    if (isappdata(hFig,'MeasureArrows1'))
        delete(getappdata(hFig,'MeasureArrows1'));
        rmappdata(hFig,'MeasureArrows1');
    end
    
    if (isappdata(hFig,'MeasureArrows2'))
        delete(getappdata(hFig,'MeasureArrows2'));
        rmappdata(hFig,'MeasureArrows2');
    end
    
    if (isappdata(hFig,'RegionArrows1'))
        delete(getappdata(hFig,'RegionArrows1'));
        rmappdata(hFig,'RegionArrows1');
    end
    
    if (isappdata(hFig,'RegionArrows2'))
        delete(getappdata(hFig,'RegionArrows2'));
        rmappdata(hFig,'RegionArrows2');
    end

    %===old===
    SetBackgroundColor(hFig, [1 1 1]); %[1 1 1]= white [0 0 0]= black
   
end
 
 
%% ===== RESET DISPLAY =====
% NOTE: ready, removed ogl
function ResetDisplay(hFig)
    % Default values
    setappdata(hFig, 'DisplayOutwardMeasure', 1);
    setappdata(hFig, 'DisplayInwardMeasure', 0);
    setappdata(hFig, 'DisplayBidirectionalMeasure', 0);
    setappdata(hFig, 'DataThreshold', 0.5);
    setappdata(hFig, 'DistanceThreshold', 0);
    setappdata(hFig, 'TextDisplayMode', [1 2]);
    setappdata(hFig, 'LobeFullLabel', 1); % 1 for displaying full label (e.g. 'Pre-Frontal') 0 for abbr tag ('PF')
    setappdata(hFig, 'NodeDisplay', 1);
    setappdata(hFig, 'HierarchyNodeIsVisible', 1);
    if isappdata(hFig, 'DataPair')
        rmappdata(hFig, 'DataPair');
    end
    if isappdata(hFig, 'HierarchyNodesMask')
        rmappdata(hFig, 'HierarchyNodesMask');
    end
    if isappdata(hFig, 'GroupNodesMask')
        rmappdata(hFig, 'GroupNodesMask');
    end
    if isappdata(hFig, 'NodeData')
        rmappdata(hFig, 'NodeData');
    end
    if isappdata(hFig, 'DataMinMax')
        rmappdata(hFig, 'DataMinMax');
    end
end
 
%% ===== GET BACKGROUND COLOR =====
function backgroundColor = GetBackgroundColor(hFig)
    backgroundColor = getappdata(hFig, 'BgColor');
    if isempty(backgroundColor)
        backgroundColor = [0 0 0]; %default bg color is black
    end
end
 
%% ===== RESIZE CALLBACK AND DISPLAY CONTAINER =====
function ResizeCallback(hFig, ~)
    % Update Title     
    RefreshTitle(hFig);
    % Update container
    UpdateContainer(hFig);
end
 
%TODO: Check
function UpdateContainer(hFig)
    % Get figure position
    figPos = get(hFig, 'Position');
    % Get colorbar handle
    hColorbar = findobj(hFig, '-depth', 1, 'Tag', 'Colorbar');   
    % Scale figure
    Scaling = bst_get('InterfaceScaling') / 100;
    % Define constants
    colorbarWidth = 15 .* Scaling;
    marginHeight  = 25 .* Scaling;
    marginWidth   = 45 .* Scaling;
    % If there is a colorbar 
    if ~isempty(hColorbar)
        % Reposition the colorbar
        set(hColorbar, 'Units',    'pixels', ...
                       'Position', [figPos(3) - marginWidth, ...
                                    marginHeight, ...
                                    colorbarWidth, ...
                                    max(1, min(90, figPos(4) - marginHeight - 3 .* Scaling))]);
        uistack(hColorbar,'top',1);
    end
end
 
function HasTitle = RefreshTitle(hFig)
    Title = [];
    DisplayInRegion = getappdata(hFig, 'DisplayInRegion');
    if (DisplayInRegion)
        % Label 
        hTitle = getappdata(hFig, 'TitlesHandle');
        % If data are hierarchicaly organised and we are not
        % already at the whole cortical view
        for i=1:size(hTitle,2)
            delete(hTitle(i));
        end
        hTitle = [];
        
        setappdata(hFig, 'TitlesHandle', hTitle);
        UpdateContainer(hFig);
    end    
    HasTitle = size(Title,2) > 0;
end
 
%% ===========================================================================
%  ===== KEYBOARD AND MOUSE CALLBACKS ========================================
%  ===========================================================================
 
% TODO: remove java canvas, use key events in MATLAB
% Can use WindowKeyPressFcn, KeyPressFcn 
% getkey
 
%% ===== FIGURE MOUSE CLICK CALLBACK =====
    % Mouse click callbacks include:
        % Right-click for popup menu (NOTE: DONE)
        % Double click to reset display (NOTE: DONE)
        % SHIFT+MOUSEMOVE to move/pan camera (NOTE: DONE)
        % CLICK a node to select/unselect it and its links (NOTE: DONE)
        % SHIFT+CLICK to select multiple nodes (NOTE: DONE)
        % CLICK colorbar to change colormap, double-click to reset (NOTE: DONE)
    % See https://www.mathworks.com/help/matlab/ref/matlab.ui.figure-properties.html#buiwuyk-1-SelectionType
    % for details on possible mouseclick types
function FigureMouseDownCallback(hFig, ev)
    disp('Entered FigureMouseDownCallback');
    % Note: Actual triggered events are applied at MouseUp or other points
    % (e.g. during mousedrag). This function gets information about the
    % click event to classify it
    
    % For link selection
    global GlobalData;
    MeasureLinksIsVisible = getappdata(hFig, 'MeasureLinksIsVisible');

    % Check if MouseUp was executed before MouseDown: Should ignore this MouseDown event
    if isappdata(hFig, 'clickAction') && strcmpi(getappdata(hFig,'clickAction'), 'MouseDownNotConsumed')
        return;
    end
    
    % click from Matlab figure
    if ~isempty(ev)
        if strcmpi(get(hFig, 'SelectionType'), 'alt') % right-click or CTRL+Click
            clickAction = 'popup';
        elseif strcmpi(get(hFig, 'SelectionType'), 'open') % double-click
            %double-click to reset display
            clickAction = 'ResetCamera';
        elseif strcmpi(get(hFig, 'SelectionType'), 'extend') % SHIFT is held
            clickAction = 'ShiftClick'; % POTENTIAL node click, or mousemovecamera
        else % normal click
            clickAction = 'SingleClick'; % POTENTIAL node click!        
        end
        clickPos = get(hFig, 'CurrentPoint');

    % otherwise, click from Matlab colorbar
    else
        if strcmpi(get(hFig, 'SelectionType'), 'alt')
            clickAction = 'popup';
        else
            clickAction = 'colorbar';
        end
        clickPos = get(hFig, 'CurrentPoint');
    end
    
    % Record action to perform when the mouse is moved
    setappdata(hFig, 'clickAction', clickAction);
    setappdata(hFig, 'clickSource', hFig);
    % Reset the motion flag
    setappdata(hFig, 'hasMoved', 0);
    % Record mouse location in the figure coordinates system
    setappdata(hFig, 'clickPositionFigure', clickPos);
end
 
 
%% ===== FIGURE MOUSE MOVE CALLBACK =====
function FigureMouseMoveCallback(hFig, ev)
    %disp('Entered FigureMouseMoveCallback');
    
    % Get current mouse action
    clickAction = getappdata(hFig, 'clickAction');   
    clickSource = getappdata(hFig, 'clickSource');
    % If no source, or source is not the same as the current figure: Ignore
    if isempty(clickAction) || isempty(clickSource) || (clickSource ~= hFig)
        return
    end
    % If MouseUp was executed before MouseDown: Ignore Move event
    if strcmpi(clickAction, 'MouseDownNotConsumed') || isempty(getappdata(hFig, 'clickPositionFigure'))
        return
    end
    
    % TODO: REMOVE JAVA CANVAS
    if ~isempty(ev) && isjava(ev) %Click on the Java canvas
        curPos = [ev.getX() ev.getY()];
    else  % Click on the Matlab colorbar or matlab figure
        curPos = get(hFig, 'CurrentPoint');
    end
    % Motion from the previous event
    motionFigure = 0.3 * (curPos - getappdata(hFig, 'clickPositionFigure'));
    % Update click point location
    setappdata(hFig, 'clickPositionFigure', curPos);
    % Update the motion flag
    setappdata(hFig, 'hasMoved', 1);
    % Switch between different actions
    switch(clickAction)              
        case 'colorbar'
            %TODO
            % Get colormap type
            ColormapInfo = getappdata(hFig, 'Colormap');
            % Changes contrast            
            sColormap = bst_colormaps('ColormapChangeModifiers', ColormapInfo.Type, [motionFigure(1), motionFigure(2)] ./ 100, 0);
            set(hFig, 'Colormap', sColormap.CMap);
        case 'ShiftClick'
            % check SHIFT is still held down
            isShift = getappdata(hFig, 'ShiftPressed');
            if (~isempty(isShift) && isShift)
                 motion = -motionFigure * 0.05;
                 MoveCamera(hFig, [motion(1) motion(2) 0]);
             end
    end
end
 
 
%% ===== FIGURE MOUSE UP CALLBACK =====
% This function applies certain triggered events from mouse clicks/movements
    % Left click on a node: select/deselect nodes
    % Right click: popup menu
    % Double click: reset camera
function FigureMouseUpCallback(hFig, varargin)
    disp('Entered FigureMouseUpCallback');
    
    % Get index of potentially clicked node
    % NOTE: Node index stored whenever the node is clicked (any type)
    global GlobalData;
    NodeIndex = GlobalData.FigConnect.ClickedNodeIndex; 
    GlobalData.FigConnect.ClickedNodeIndex = 0; % clear stored index
    
    % clicked link
    LinkIndex = GlobalData.FigConnect.ClickedLinkIndex; 
    GlobalData.FigConnect.ClickedLinkIndex = 0; 
    ArrowIndex = GlobalData.FigConnect.ClickedArrowIndex; 
    GlobalData.FigConnect.ClickedArrowIndex = 0; 
    
%     node1Link = GlobalData.FigConnect.ClickedNode1Index; 
%     GlobalData.FigConnect.ClickedNode1Index = 0;
%     node2Link = GlobalData.FigConnect.ClickedNode2Index; 
%     GlobalData.FigConnect.ClickedNode2Index = 0;
    
    LinkType = getappdata(hFig, 'MeasureLinksIsVisible');
    IsDirectional = getappdata(hFig, 'IsDirectionalData');
    
    % Get application data (current user/mouse actions)
    clickAction = getappdata(hFig, 'clickAction');
    hasMoved = getappdata(hFig, 'hasMoved');
    
    % Remove mouse appdata (to stop movements first)
    setappdata(hFig, 'hasMoved', 0);
    if isappdata(hFig, 'clickPositionFigure')
        rmappdata(hFig, 'clickPositionFigure');
    end
    if isappdata(hFig, 'clickAction')
        rmappdata(hFig, 'clickAction');
    else
        setappdata(hFig, 'clickAction', 'MouseDownNotConsumed');
    end
 
    % Update display panel
    bst_figures('SetCurrentFigure', hFig, 'TF');
    
    % ===== SIMPLE CLICK =====
    if ~hasMoved
        if strcmpi(clickAction, 'popup')
            DisplayFigurePopup(hFig);
        elseif strcmpi(clickAction, 'ResetCamera')
            DefaultCamera(hFig);
        elseif (strcmpi(clickAction, 'SingleClick') || strcmpi(clickAction, 'ShiftClick'))
            if (NodeIndex>0)
                NodeClickEvent(hFig,NodeIndex);
            end
            
            % left mouse click on a link
            if (strcmpi(clickAction, 'SingleClick'))        
                if (LinkIndex>0)
                    node1 = GlobalData.FigConnect.ClickedNode1Index;
                    GlobalData.FigConnect.ClickedNode1Index = 0;
                    node2 = GlobalData.FigConnect.ClickedNode2Index;
                    GlobalData.FigConnect.ClickedNode2Index = 0;
                    
                    LinkClickEvent(hFig,LinkIndex,LinkType,IsDirectional,node1,node2);
                end
                if (ArrowIndex>0)
                    node1 = GlobalData.FigConnect.ClickedNode1Index;
                    GlobalData.FigConnect.ClickedNode1Index = 0;
                    node2 = GlobalData.FigConnect.ClickedNode2Index;
                    GlobalData.FigConnect.ClickedNode2Index = 0;
                    
                    ArrowClickEvent(hFig,ArrowIndex,LinkType,node1,node2);
                end
            end
        end
        
    % ===== MOUSE HAS MOVED =====
    else
        if strcmpi(clickAction, 'colorbar')
            % Apply new colormap to all figures
            ColormapInfo = getappdata(hFig, 'Colormap');
            bst_colormaps('FireColormapChanged', ColormapInfo.Type);
        end
        
        % left mouse click on a link
        if (strcmpi(clickAction, 'SingleClick'))
            if (LinkIndex>0)
                LinkClickEvent(hFig,LinkIndex,LinkType,IsDirectional,node1,node2);
            end
            if (ArrowIndex>0)
                ArrowClickEvent(hFig,ArrowIndex,LinkType,node1,node2);
            end
        end
    end
end
 
 
%% ===== FIGURE KEY PRESSED CALLBACK =====
    %TODO: Implement/check 'OTHER' key shortcut events
function FigureKeyPressedCallback(hFig, keyEvent)
    % Convert to Matlab key event
    [keyEvent, isControl, isShift] = gui_brainstorm('ConvertKeyEvent', keyEvent);
    if isempty(keyEvent.Key)
        return;
    end
    
    % Process event
    switch (keyEvent.Key)
        % TO REMOVE AT END: test key
        case 't' 
             test(hFig);
             
        % ---NODE SELECTIONS---
        case 'a'            % DONE: Select All Nodes
            SetSelectedNodes(hFig, [], 1, 1);
        case 'leftarrow'    % DONE: Select Previous Region
            ToggleRegionSelection(hFig, 1);
        case 'rightarrow'   % DONE: Select Next Region
            ToggleRegionSelection(hFig, -1);
        
        % ---NODE LABELS DISPLAY---  
        case 'l'            % DONE: Toggle Lobe Labels and abbr type
            ToggleTextDisplayMode(hFig); 
        
        % ---TOGGLE BACKGROUND---  
        case 'b'            % DONE: Toggle Background
            ToggleBackground(hFig);
        
        % ---ZOOM CAMERA---
        case 'uparrow'      % DONE: Zoom in
            ZoomCamera(hFig, 0.95 );
        case 'downarrow'    % DONE: Zoom in
            ZoomCamera(hFig, 1.05);
        
        % ---SHIFT---
        case 'shift'        % DONE: SHIFT+MOVE to move camera, SHIFT+CLICK to select multi-nodes  
            setappdata(hFig, 'ShiftPressed', 1);
            
        % ---SNAPSHOT---
        case 'i'            % DONE: CTRL+I Save as image
            if isControl
                out_figure_image(hFig);
            end
        case 'j'            % DONE: CTRL+J Open as image
            if isControl
                out_figure_image(hFig, 'Viewer');
            end
        
        % ---OTHER---        
        case 'h' % TODO: Toggle visibility of hierarchy/region nodes (unclear if needed)
            HierarchyNodeIsVisible = getappdata(hFig, 'HierarchyNodeIsVisible');
            HierarchyNodeIsVisible = 1 - HierarchyNodeIsVisible;
            SetHierarchyNodeIsVisible(hFig, HierarchyNodeIsVisible);
      %  case 'd' % upclear if needed (does not work in previous figure_connect either)
         %   ToggleDisplayMode(hFig); % should be to toggle bi/in/out/all for directional graphs
        case 'm' % TODO: Toggle Region Links
            ToggleMeasureToRegionDisplay(hFig);
    end
end
 
%Note: ready
function FigureKeyReleasedCallback(hFig, keyEvent)
    % Convert to Matlab key event
    keyEvent = gui_brainstorm('ConvertKeyEvent', keyEvent);
    if isempty(keyEvent.Key)
        return;
    end
    % Process event
    switch (keyEvent.Key)
        case 'shift'  % no longer in SHIFT mode
            setappdata(hFig, 'ShiftPressed', 0);
    end
end
 
function NextNode = getNextCircularRegion(hFig, Node, Inc)
    DisplayInRegion = getappdata(hFig, 'DisplayInRegion');
    if (DisplayInRegion)
        % get region (mean or max) links visibility
        RegionLinksIsVisible = getappdata(hFig, 'RegionLinksIsVisible');
    end
    
    % Construct Spiral Index
    Levels = bst_figures('GetFigureHandleField', hFig, 'Levels');
    DisplayNode = find(bst_figures('GetFigureHandleField', hFig, 'DisplayNode'));
    CircularIndex = [];
    
    % Do we need to skip a level?
    skip = []; % default skip nothing
    if (DisplayInRegion)
        if (RegionLinksIsVisible) 
            skip = [1 2]; % skip Levels{1} and Levels{2} if in region links mode, 
        else
            skip = 2; % skip Levels{2} if in measure links mode
        end 
    end
    
    for i=1:size(Levels,1) 
        if (~ismember(i,skip))
            CircularIndex = [CircularIndex; Levels{i}];
        end
    end
    
    CircularIndex(~ismember(CircularIndex,DisplayNode)) = [];
    if isempty(Node)
        NextIndex = 1;
    else
        % Find index
        NextIndex = find(CircularIndex(:) == Node) + Inc;
        nIndex = size(CircularIndex,1);
        if (NextIndex > nIndex)
            NextIndex = 1;
        elseif (NextIndex < 1)
            NextIndex = nIndex;
        end
    end
    % 
    NextNode = CircularIndex(NextIndex);
end
 
function ToggleRegionSelection(hFig, Inc)
    % Get selected nodes
    selNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
    % Get number of AgregatingNode
    AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
    % 
    if (isempty(selNodes))
        % Get first node
        NextNode = getNextCircularRegion(hFig, [], Inc);
    else
        % Remove previous links
        SetSelectedNodes(hFig, selNodes, 0, 1); 
        % Remove agregating node from selection
        SelectedNode = selNodes(1);
        %
        NextNode = getNextCircularRegion(hFig, SelectedNode, Inc);
    end
    % Is the next node an agregating node?
    isAgregatingNode = ismember(NextNode, AgregatingNodes);
    if (isAgregatingNode)
        % Get agregated nodes
        AgregatedNodeIndices = getAgregatedNodesFrom(hFig, NextNode); 
        if (~isempty(AgregatedNodeIndices))
            % Select all nodes associated to NextNode
            SetSelectedNodes(hFig, AgregatedNodeIndices, 1, 1);
        end    
    else
        % Select next node
        SetSelectedNodes(hFig, NextNode, 1, 1);
    end
end
 
 
%% ===== NODE CLICK CALLBACK =====
% If mouse click was used to select or unselect a node, this function is called to apply the appropriate changes
% Basic logic:
    % - A node is clicked to select or deselect it (displays as grey X when deselected, and links are hidden)
    % - If the node is a region (lobe/hemisphere) node, selections are
    % applied to all of its parts
    % -SHIFT + CLICK to select/deselect MULTIPLE nodes at once
function NodeClickEvent(hFig, NodeIndex)
    disp('Entered NodeClickEvent');
    if(NodeIndex <= 0)
        return;
    end
    
    DisplayNode = bst_figures('GetFigureHandleField', hFig, 'DisplayNode');

    if (DisplayNode(NodeIndex) == 1)
        % 1. GET NODE SETS AND PROPERTIES
        % Get selected nodes
        selNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
        % Get agregating nodes
        MeasureNodes    = bst_figures('GetFigureHandleField', hFig, 'MeasureNodes');
        AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
        % Is the node already selected ?
        AlreadySelected = any(selNodes == NodeIndex);
        % Is the node an agregating node ?
        isAgregatingNode = any(AgregatingNodes == NodeIndex);

        % 2. IF NODE IS ALREADY SELECTED, TOGGLE IT
        if AlreadySelected
            % If all nodes are already selected
            if all(ismember(MeasureNodes, selNodes))  
                % then we want to select only this new one
                SetSelectedNodes(hFig, [], 0); % first unselect all nodes
                AlreadySelected = 0;

            % If it's the only already selected node then select
            % all and return
            elseif (length(selNodes) == 1)
                SetSelectedNodes(hFig, [], 1); 
                return;
            end

            % Aggregative nodes: select blocks of nodes
            if isAgregatingNode
                % Get agregated nodes
                AgregatedNodeIndex = getAgregatedNodesFrom(hFig, NodeIndex);
                % How many are already selected
                NodeAlreadySelected = ismember(AgregatedNodeIndex, selNodes);

                % If the agregating node and this measure node are
                % the only selected nodes, then select all and
                % return
                if (sum(NodeAlreadySelected) == size(selNodes,1))
                    SetSelectedNodes(hFig, [], 1);
                    return;
                end
            end
        end

        % 3. CHECK IF WE ARE SELECTING OR UNSELECTING A NODE
        Select = 1;
        if (AlreadySelected)
            Select = 0; % We want to deselect picked node
        end

        % 3. SHIFT Behaviour:
            % Default: toggle select this node only
            % If SHIFT is currently held, select multiple nodes
        isShift = getappdata(hFig,'ShiftPressed');
        if (isempty(isShift) || ~isShift)
            SetSelectedNodes(hFig, selNodes, 0, 1); % Deselect all
            Select = 1; % Select picked node
        end

        % 4. APPLY DE/SELECTIONS
        if (isAgregatingNode)
            SelectNodeIndex = getAgregatedNodesFrom(hFig, NodeIndex);
            SetSelectedNodes(hFig, [SelectNodeIndex(:); NodeIndex], Select); %set the selection
            % Go up the hierarchy
            UpdateHierarchySelection(hFig, NodeIndex, Select);
        else
            SetSelectedNodes(hFig, NodeIndex, Select);
        end                
    end
end

%%
function UpdateHierarchySelection(hFig, NodeIndex, Select)
    % Incorrect data
    if (size(NodeIndex,1) > 1 || isempty(NodeIndex ))
        return
    end
    % 
    if (NodeIndex == 1)
        return
    end
    % Go up the hierarchy
    NodePaths = bst_figures('GetFigureHandleField', hFig, 'NodePaths');
    PathToCenter = NodePaths{NodeIndex};
    % Retrieve Agregating node
    AgregatingNode = PathToCenter(find(PathToCenter == NodeIndex) + 1);
    % Get selected nodes
    selNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
    % Get agregated nodes
    AgregatedNodesIndex = getAgregatedNodesFrom(hFig, AgregatingNode);
    % Is everything selected ?
    if (size(AgregatedNodesIndex,1) == sum(ismember(AgregatedNodesIndex, selNodes)))
        SetSelectedNodes(hFig, AgregatingNode, Select);
        UpdateHierarchySelection(hFig, AgregatingNode, Select);
    end
end
 
%% =====  ZOOM CALLBACK USING MOUSEWHEEL =========
    % Note: Done Oct 20, 2020
function FigureMouseWheelCallback(hFig, ev)
    disp("Mouse wheel callback reached");
    % Control Zoom
    if isempty(ev)
        return;
    elseif (ev.VerticalScrollCount < 0)
        % ZOOM OUT
        Factor = 1./(1 - double(ev.VerticalScrollCount) ./ 20);
    elseif (ev.VerticalScrollCount > 0)
        % ZOOM IN
         Factor = 1 + double(ev.VerticalScrollCount) ./ 20;
    else
        Factor = 1;
    end
    ZoomCamera(hFig, Factor);
    
end
 
 
%% ===== POPUP MENU V1: Display Options menu with no sub-menus=====
%TODO: Saved image to display current values from Display Panel filters 
%TODO: Remove '(in dev)' for features once fully functional
function DisplayFigurePopup(hFig)
    import java.awt.event.KeyEvent;
    import java.awt.Dimension;
    import javax.swing.KeyStroke;
    import javax.swing.JLabel;
    import javax.swing.JSlider;
    import org.brainstorm.icon.*;
    % Get figure description
    hFig = bst_figures('GetFigure', hFig);
    % Get axes handles
    hAxes = getappdata(hFig, 'clickSource');
    if isempty(hAxes)
        return
    end
    
    DisplayInRegion = getappdata(hFig, 'DisplayInRegion');
   
    % Create popup menu
    jPopup = java_create('javax.swing.JPopupMenu');
    
    % ==== MENU: COLORMAP =====
    bst_colormaps('CreateAllMenus', jPopup, hFig, 0);
    
    % ==== MENU: SNAPSHOT ====
    jPopup.addSeparator();
    jMenuSave = gui_component('Menu', jPopup, [], 'Snapshot', IconLoader.ICON_SNAPSHOT);
        % === SAVE AS IMAGE ===
        %TODO: Saved image to display current values from Display Panel filters 
        jItem = gui_component('MenuItem', jMenuSave, [], 'Save as image', IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@out_figure_image, hFig));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_I, KeyEvent.CTRL_MASK));
        % === OPEN AS IMAGE ===
        jItem = gui_component('MenuItem', jMenuSave, [], 'Open as image', IconLoader.ICON_IMAGE, [], @(h,ev)bst_call(@out_figure_image, hFig, 'Viewer'));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_J, KeyEvent.CTRL_MASK));       
    jPopup.add(jMenuSave);
    
    % ==== MENU: 2D LAYOUT (DISPLAY OPTIONS)====
    jDisplayMenu = gui_component('Menu', jPopup, [], 'Display options', IconLoader.ICON_CONNECTN);
        
        % === LABEL DISPLAY OPTIONS ===
        if (bst_get('MatlabVersion') >= 705) % Check Matlab version: Works only for R2007b and newer
            % === MODIFY LABEL SIZE (Jan 2021) ===
            jPanelModifiers = gui_river([0 0], [0, 29, 0, 0]);
            LabelSize = GetLabelSize(hFig);
            % Label
            gui_component('label', jPanelModifiers, '', 'Label size (in dev)');
            % Slider
            jSliderContrast = JSlider(1,20); % changed Jan 3 2020 (uses factor of 2 for label sizes 0.5 to 5.0 with increments of 0.5 in actuality)
            jSliderContrast.setValue(round(LabelSize * 2));
            jSliderContrast.setPreferredSize(java_scaled('dimension',100,23));
            %jSliderContrast.setToolTipText(tooltipSliders);
            jSliderContrast.setFocusable(0);
            jSliderContrast.setOpaque(0);
            jPanelModifiers.add('tab hfill', jSliderContrast);
            % Value (text)
            jLabelContrast = gui_component('label', jPanelModifiers, '', sprintf('%.0f', round(LabelSize * 2)));
            jLabelContrast.setPreferredSize(java_scaled('dimension',50,23));
            jLabelContrast.setHorizontalAlignment(JLabel.LEFT);
            jPanelModifiers.add(jLabelContrast);
            % Slider callbacks
            java_setcb(jSliderContrast.getModel(), 'StateChangedCallback', @(h,ev)LabelSizeSliderModifiersModifying_Callback(hFig, ev, jLabelContrast));
            jDisplayMenu.add(jPanelModifiers);
        end
        
            % === TOGGLE LABELS ===
            % Lobe label abbreviations
            if (DisplayInRegion)
                jItem = gui_component('CheckBoxMenuItem', jDisplayMenu, [], 'Abbreviate lobe labels', [], [], @(h, ev)ToggleLobeLabels(hFig));
                jItem.setSelected(~getappdata(hFig,'LobeFullLabel'));
            end
            TextDisplayMode = getappdata(hFig, 'TextDisplayMode');
            % Measure (outer) node labels
            jItem = gui_component('CheckBoxMenuItem', jDisplayMenu, [], 'Show scout labels', [], [], @(h, ev)SetTextDisplayMode(hFig, 1));
            jItem.setSelected(ismember(1,TextDisplayMode));
            % Region (lobe/hemisphere) node labels
            if (DisplayInRegion)
                jItem = gui_component('CheckBoxMenuItem', jDisplayMenu, [], 'Show region labels', [], [], @(h, ev)SetTextDisplayMode(hFig, 2));
                jItem.setSelected(ismember(2,TextDisplayMode));
            end
            % Selected Nodes' labels only
            jItem = gui_component('CheckBoxMenuItem', jDisplayMenu, [], 'Show labels for selection only', [], [], @(h, ev)SetTextDisplayMode(hFig, 3));
            jItem.setSelected(ismember(3,TextDisplayMode));
        
        jDisplayMenu.addSeparator();
        
        % === NODE DISPLAY OPTIONS ===
        if (bst_get('MatlabVersion') >= 705) % Check Matlab version: Works only for R2007b and newer
            % === MODIFY NODE SIZE (Jan 2021)===
            jPanelModifiers = gui_river([0 0], [0, 29, 0, 0]);
            NodeSize = GetNodeSize(hFig);
            % Label
            gui_component('label', jPanelModifiers, '', 'Node size (in dev)');
            % Slider
            jSliderContrast = JSlider(1,15); % changed Jan 3 2020 (uses factor of 2 for node sizes 0.5 to 5.0 with increments of 0.5 in actuality)
            jSliderContrast.setValue(round(NodeSize * 2));
            jSliderContrast.setPreferredSize(java_scaled('dimension',100,23));
            %jSliderContrast.setToolTipText(tooltipSliders);
            jSliderContrast.setFocusable(0);
            jSliderContrast.setOpaque(0);
            jPanelModifiers.add('tab hfill', jSliderContrast);
            % Value (text)
            jLabelContrast = gui_component('label', jPanelModifiers, '', sprintf('%.0f', round(NodeSize * 2)));
            jLabelContrast.setPreferredSize(java_scaled('dimension',50,23));
            jLabelContrast.setHorizontalAlignment(JLabel.LEFT);
            jPanelModifiers.add(jLabelContrast);
            % Slider callbacks
            java_setcb(jSliderContrast.getModel(), 'StateChangedCallback', @(h,ev)NodeSizeSliderModifiersModifying_Callback(hFig, ev, jLabelContrast));
            jDisplayMenu.add(jPanelModifiers);
            if (~DisplayInRegion)
                jDisplayMenu.addSeparator();
            end
        end

        if (DisplayInRegion)
            % === TOGGLE HIERARCHY/REGION NODE VISIBILITY ===
            HierarchyNodeIsVisible = getappdata(hFig, 'HierarchyNodeIsVisible');
            jItem = gui_component('CheckBoxMenuItem', jDisplayMenu, [], 'Hide region nodes (in dev)', [], [], @(h, ev)SetHierarchyNodeIsVisible(hFig, 1 - HierarchyNodeIsVisible));
            jItem.setSelected(~HierarchyNodeIsVisible);
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_H, 0));
            jDisplayMenu.addSeparator();
        end
        
        % == LINK DISPLAY OPTIONS ==
        if (bst_get('MatlabVersion') >= 705) % Check Matlab version: Works only for R2007b and newer
            
            % === MODIFY NODE AND LINK SIZE (Mar 2021)===
            jPanelModifiers = gui_river([0 0], [0, 29, 0, 0]);
            % uses node size to update text and slider
            NodeSize = GetNodeSize(hFig);
            % Label
            gui_component('label', jPanelModifiers, '', 'Node & label size');
            % Slider
            jSliderContrast = JSlider(1,15); % changed Jan 3 2020 (uses factor of 2 for node sizes 0.5 to 5.0 with increments of 0.5 in actuality)
            jSliderContrast.setValue(round(NodeSize * 2));
            jSliderContrast.setPreferredSize(java_scaled('dimension',100,23));
            %jSliderContrast.setToolTipText(tooltipSliders);
            jSliderContrast.setFocusable(0);
            jSliderContrast.setOpaque(0);
            jPanelModifiers.add('tab hfill', jSliderContrast);
            % Value (text)
            jLabelContrast = gui_component('label', jPanelModifiers, '', sprintf('%.0f', round(NodeSize * 2)));
            jLabelContrast.setPreferredSize(java_scaled('dimension',50,23));
            jLabelContrast.setHorizontalAlignment(JLabel.LEFT);
            jPanelModifiers.add(jLabelContrast);
            % Slider callbacks
            java_setcb(jSliderContrast.getModel(), 'StateChangedCallback', @(h,ev)NodeLabelSizeSliderModifiersModifying_Callback(hFig, ev, jLabelContrast));
            jDisplayMenu.add(jPanelModifiers);
            if (~DisplayInRegion)
                jDisplayMenu.addSeparator();
            end
        
            % == MODIFY LINK SIZE ==
            jPanelModifiers = gui_river([0 0], [0, 29, 0, 0]);
            LinkSize = GetLinkSize(hFig);
            % Label
            gui_component('label', jPanelModifiers, '', 'Link size');
            % Slider
            jSliderContrast = JSlider(1,10); % changed Jan 3 2020 (uses factor of 2 for link sizes 0.5 to 5.0 with increments of 0.5 in actuality)
            jSliderContrast.setValue(round(LinkSize * 2));
            jSliderContrast.setPreferredSize(java_scaled('dimension',100,23));
            %jSliderContrast.setToolTipText(tooltipSliders);
            jSliderContrast.setFocusable(0);
            jSliderContrast.setOpaque(0);
            jPanelModifiers.add('tab hfill', jSliderContrast);
            % Value (text)
            jLabelContrast = gui_component('label', jPanelModifiers, '', sprintf('%.0f', round(LinkSize * 2)));
            jLabelContrast.setPreferredSize(java_scaled('dimension',50,23));
            jLabelContrast.setHorizontalAlignment(JLabel.LEFT);
            jPanelModifiers.add(jLabelContrast);
            % Slider callbacks
            java_setcb(jSliderContrast.getModel(), 'StateChangedCallback', @(h,ev)LinkSizeSliderModifiersModifying_Callback(hFig, ev, jLabelContrast));
            jDisplayMenu.add(jPanelModifiers);
            
            % == MODIFY LINK TRANSPARENCY ==
            jPanelModifiers = gui_river([0 0], [0, 29, 0, 0]);
            Transparency = getappdata(hFig, 'LinkTransparency');
            % Label
            gui_component('label', jPanelModifiers, '', 'Link transp');
            % Slider
            jSliderContrast = JSlider(0,100,100);
            jSliderContrast.setValue(round(Transparency * 100));
            jSliderContrast.setPreferredSize(java_scaled('dimension',100,23));
            %jSliderContrast.setToolTipText(tooltipSliders);
            jSliderContrast.setFocusable(0);
            jSliderContrast.setOpaque(0);
            jPanelModifiers.add('tab hfill', jSliderContrast);
            % Value (text)
            jLabelContrast = gui_component('label', jPanelModifiers, '', sprintf('%.0f %%', Transparency * 100));
            jLabelContrast.setPreferredSize(java_scaled('dimension',50,23));
            jLabelContrast.setHorizontalAlignment(JLabel.LEFT);
            jPanelModifiers.add(jLabelContrast);
            % Slider callbacks
            java_setcb(jSliderContrast.getModel(), 'StateChangedCallback', @(h,ev)TransparencySliderModifiersModifying_Callback(hFig, ev, jLabelContrast));
            jDisplayMenu.add(jPanelModifiers);
        end
        
            % === TOGGLE BINARY LINK STATUS ===
            Method = getappdata(hFig, 'Method');
            if ismember(Method, {'granger'}) || ismember(Method, {'spgranger'})
                IsBinaryData = getappdata(hFig, 'IsBinaryData');
                jItem = gui_component('CheckBoxMenuItem', jDisplayMenu, [], 'Binary Link Display', IconLoader.ICON_CHANNEL_LABEL, [], @(h, ev)SetIsBinaryData(hFig, 1 - IsBinaryData));
                jItem.setSelected(IsBinaryData);
                jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_M, 0));
            end
        
        % === BACKGROUND OPTIONS (NOTE: DONE)===
        jDisplayMenu.addSeparator();
        BackgroundColor = getappdata(hFig, 'BgColor');
        isWhite = all(BackgroundColor == [1 1 1]);
        jItem = gui_component('CheckBoxMenuItem', jDisplayMenu, [], 'White background', [], [], @(h, ev)ToggleBackground(hFig));
        jItem.setSelected(isWhite);
  
 
    % ==== GRAPH OPTIONS ====
    % NOTE: now all 'Graph Options' are directly shown in main pop-up menu
        jPopup.addSeparator();
        % === SELECT ALL THE NODES ===
        jItem = gui_component('MenuItem', jPopup, [], 'Select all', [], [], @(h, n, s, r)SetSelectedNodes(hFig, [], 1, 1));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_A, 0));
        % === SELECT NEXT REGION ===
        jItem = gui_component('MenuItem', jPopup, [], 'Select next region', [], [], @(h, ev)ToggleRegionSelection(hFig, -1));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_RIGHT, 0));
        % === SELECT PREVIOUS REGION===
        jItem = gui_component('MenuItem', jPopup, [], 'Select previous region', [], [], @(h, ev)ToggleRegionSelection(hFig, 1));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_LEFT, 0));
        jPopup.addSeparator();

        if (DisplayInRegion)
            % === TOGGLE DISPLAY REGION LINKS ===
            % TODO: IMPLEMENT REGION LINKS
            RegionLinksIsVisible = getappdata(hFig, 'RegionLinksIsVisible');
            RegionFunction = getappdata(hFig, 'RegionFunction');
            jItem = gui_component('CheckBoxMenuItem', jPopup, [], ['Display region ' RegionFunction ' (in dev)'], [], [], @(h, ev)ToggleMeasureToRegionDisplay(hFig));
            jItem.setSelected(RegionLinksIsVisible);
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_M, 0));

            % === TOGGLE REGION FUNCTIONS===
            IsMean = strcmp(RegionFunction, 'mean');
            jLabelMenu = gui_component('Menu', jPopup, [], 'Choose region function (in dev)');
                jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Mean (in dev)', [], [], @(h, ev)SetRegionFunction(hFig, 'mean'));
                jItem.setSelected(IsMean);
                jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Max (in dev)', [], [], @(h, ev)SetRegionFunction(hFig, 'max'));
                jItem.setSelected(~IsMean);
        end
    
    % Display Popup menu
    gui_popup(jPopup, hFig);
end

% Node AND label size slider
function NodeLabelSizeSliderModifiersModifying_Callback(hFig, ev, jLabel)
    disp('Entered NodeLabelSizeSliderModifiersModifying_Callback'); % TODO: remove
    % Update Modifier value
    NodeValue = ev.getSource().getValue() / 2;
    LabelValue = NodeValue * 1.4;
    % Update text value
    jLabel.setText(sprintf('%.0f', NodeValue * 2));
    SetNodeLabelSize(hFig, NodeValue, LabelValue);
end

% Node size slider
% NOTE: DONE JAN 2021
function NodeSizeSliderModifiersModifying_Callback(hFig, ev, jLabel)
    disp('Entered NodeSizeSliderModifiersModifying_Callback'); % TODO: remove
    % Update Modifier value
    newValue = ev.getSource().getValue() / 2;
    % Update text value
    jLabel.setText(sprintf('%.0f', newValue * 2));
    SetNodeSize(hFig, newValue);
end

% Label size slider
% NOTE: DONE JAN 2020
function LabelSizeSliderModifiersModifying_Callback(hFig, ev, jLabel)
    disp('Entered LabelSizeSliderModifiersModifying_Callback'); % TODO: remove
    % Update Modifier value
    newValue = ev.getSource().getValue() / 2;
    % Update text value
    jLabel.setText(sprintf('%.0f', newValue * 2));
    SetLabelSize(hFig, newValue);
end

% Link transparency slider
% NOTE: DONE DEC 2020
function TransparencySliderModifiersModifying_Callback(hFig, ev, jLabel)
    disp('Entered TransparencySliderModifiersModifying_Callback');
    % Update Modifier value
    newValue = double(ev.getSource().getValue()) / 100;
    % Update text value
    jLabel.setText(sprintf('%.0f %%', newValue * 100));
    SetLinkTransparency(hFig, newValue);
end
 
% Link size slider
% NOTE: DONE DEC 2020
function LinkSizeSliderModifiersModifying_Callback(hFig, ev, jLabel)
    disp('Entered LinkSizeSliderModifiersModifying_Callback'); % TODO: remove
    % Update Modifier value
    newValue = ev.getSource().getValue() / 2;
    % Update text value
    jLabel.setText(sprintf('%.0f', newValue * 2));
    SetLinkSize(hFig, newValue);
end

%% ===========================================================================
%  ===== PLOT FUNCTIONS ======================================================
%  ===========================================================================
 
%% ===== GET FIGURE DATA =====
% NOTE: ready, no changes needed
function [Time, Freqs, TfInfo, TF, RowNames, DataType, Method, FullTimeVector] = GetFigureData(hFig)
    global GlobalData;
    % === GET FIGURE INFO ===
    % Get selected frequencies and rows
    TfInfo = getappdata(hFig, 'Timefreq');
    if isempty(TfInfo)
        return
    end
    % Get data description
    [iDS, iTimefreq] = bst_memory('GetDataSetTimefreq', TfInfo.FileName);
    if isempty(iDS)
        return
    end
    
    % ===== GET TIME =====
    [Time, iTime] = bst_memory('GetTimeVector', iDS, [], 'CurrentTimeIndex');
    Time = Time(iTime);
    FullTimeVector = Time;
    % If it is a static figure: keep only the first and last times
    if getappdata(hFig, 'isStatic')
        Time = Time([1,end]);
    end
    
    % ===== GET FREQUENCIES =====
    % Get the current freqency
    TfInfo.iFreqs = GlobalData.UserFrequencies.iCurrentFreq;
    if isempty(TfInfo.iFreqs)
        Freqs = GlobalData.DataSet(iDS).Timefreq(iTimefreq).Freqs;
    elseif ~iscell(GlobalData.DataSet(iDS).Timefreq(iTimefreq).Freqs)
       if (GlobalData.DataSet(iDS).Timefreq(iTimefreq).Freqs == 0)
           Freqs = [];
           TfInfo.iFreqs = 1;
       else
           Freqs = GlobalData.DataSet(iDS).Timefreq(iTimefreq).Freqs(TfInfo.iFreqs);
           if (size(Freqs,1) ~= 1)
               Freqs = Freqs';
           end
       end
    else
        % Get a set of frequencies (freq bands)
        Freqs = GlobalData.DataSet(iDS).Timefreq(iTimefreq).Freqs(TfInfo.iFreqs);
    end
        
    % ===== GET DATA =====
    RowNames = GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames;
    % Only if requested
    if (nargout >= 4)
        % Get TF values
        [TF, iTimeBands] = bst_memory('GetTimefreqValues', iDS, iTimefreq, [], TfInfo.iFreqs, iTime, TfInfo.Function);
        % Get connectivity matrix
        TF = bst_memory('ReshapeConnectMatrix', iDS, iTimefreq, TF);
        % Get time bands
        if ~isempty(iTimeBands)
            Time = GlobalData.DataSet(iDS).Timefreq(iTimefreq).TimeBands(iTimeBands,:);
        end
        % Data type
        DataType = GlobalData.DataSet(iDS).Timefreq(iTimefreq).DataType;
        % Method
        Method = GlobalData.DataSet(iDS).Timefreq(iTimefreq).Method;
    end
end
 
function IsDirectional = IsDirectionalData(hFig)
    % If directional data
    IsDirectional = getappdata(hFig, 'IsDirectionalData');
    % Ensure variable
    if isempty(IsDirectional)
        IsDirectional = 0;
    end
end
 
% @NOTE: ready, no change required
function DataPair = LoadConnectivityData(hFig, Options, Atlas, Surface)
    % Parse input
    if (nargin < 2)
        Options = struct();
    end
    if (nargin < 3)
        Atlas = [];
        Surface = [];
    end
    % Maximum number of data allowed
    MaximumNumberOfData = 5000;
   
    % === GET DATA ===
    [Time, Freqs, TfInfo, M, RowNames, DataType, Method, FullTimeVector] = GetFigureData(hFig);
    % Zero-out the diagonal because its useless
    M = M - diag(diag(M));
    
    % If the matrix is symetric and Not directional
    if (isequal(M, M') && ~IsDirectionalData(hFig))
        % We don't need the upper half
        for i = 1:size(M,1)
            M(i,i:end) = 0;
        end
    end
    
    % === THRESHOLD ===
    if ((size(M,1) * size(M,2)) > MaximumNumberOfData)
        % Validity mask
        Valid = ones(size(M));
        Valid(M == 0) = 0;
        Valid(diag(ones(size(M)))) = 0;
        
        % === ZERO-OUT LOWEST VALUES ===
        if isfield(Options,'Highest') && Options.Highest
            % Retrieve min/max
            DataMinMax = [min(M(:)), max(M(:))];
            % Keep highest values only
            if (DataMinMax(1) >= 0)
                [tmp,tmp,s] = find(M(Valid == 1));
                B = sort(s, 'descend');
                if length(B) > MaximumNumberOfData
                    t = B(MaximumNumberOfData);
                    Valid = Valid & (M >= t);
                end
            else
                [tmp,tmp,s] = find(M(Valid == 1));
                B = sort(abs(s), 'descend');
                if length(B) > MaximumNumberOfData
                    t = B(MaximumNumberOfData);
                    Valid = Valid & ((M <= -t) | (M >= t));
                end
            end
        end
        
        % 
        M(~Valid) = 0;
    end
 
    % Convert matrixu to data pair 
    DataPair = MatrixToDataPair(hFig, M);
    
    fprintf('%.0f Connectivity measure loaded\n', size(DataPair,1));
 
    % ===== MATRIX STATISTICS ===== 
    DataMinMax = [min(DataPair(:,3)), max(DataPair(:,3))];
    if isempty(DataMinMax)
        DataMinMax = [0 1];
    elseif (DataMinMax(1) == DataMinMax(2))
        if (DataMinMax(1) > 0)
            DataMinMax = [0 DataMinMax(2)];
        elseif (DataMinMax(2) < 0)
            DataMinMax = [DataMinMax(1), 0];
        else
            DataMinMax = [0 1];
        end
    end
    % Update figure variable
    bst_figures('SetFigureHandleField', hFig, 'DataMinMax', DataMinMax);
    
    % Clear memory
    clear M;
end
 
 
function aDataPair = MatrixToDataPair(hFig, mMatrix)
    % Reshape
    [i,j,s] = find(mMatrix);
    i = i';
    j = j';
    mMatrix = reshape([i;j],1,[]);
    % Convert to datapair structure
    aDataPair = zeros(size(mMatrix,2)/2,3);
    aDataPair(1:size(mMatrix,2)/2,1) = mMatrix(1:2:size(mMatrix,2));
    aDataPair(1:size(mMatrix,2)/2,2) = mMatrix(2:2:size(mMatrix,2));
    aDataPair(1:size(mMatrix,2)/2,3) = s(:);
    % Add offset
    nAgregatingNode = size(bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes'),2);
    aDataPair(:,1:2) = aDataPair(:,1:2) + nAgregatingNode;
end
 
 
%% ===== UPDATE FIGURE PLOT =====
% This function creates and loads the base figure including nodes, links and default
% params
function LoadFigurePlot(hFig) %#ok<DEFNU>
  
    global GlobalData;
    %% === Initialize data @NOTE: DONE ===
    
    % Necessary for data initialization
    ResetDisplay(hFig);
    % Get figure description
    [hFig, tmp, iDS] = bst_figures('GetFigure', hFig);
    % Get connectivity matrix
    [Time, Freqs, TfInfo] = GetFigureData(hFig);
    % Get the file descriptor in memory
    iTimefreq = bst_memory('GetTimefreqInDataSet', iDS, TfInfo.FileName);
    % Data type
    DataType = GlobalData.DataSet(iDS).Timefreq(iTimefreq).DataType;
    RowNames = GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames;
    
    % ===== GET REGION POSITIONS AND HIERARCHY =====
    % Inialize variables
    sGroups = repmat(struct('Name', [], 'RowNames', [], 'Region', []), 0);
    SurfaceMat = [];
    Vertices = [];
    RowLocs = [];
    Atlas = [];
    % Technique to get the hierarchy depends on the data type
    switch (DataType)
        case 'data' 
            % ===== CHANNEL =====
            % Get selections
            sSelect = panel_montage('GetMontagesForFigure', hFig);
            % Check if all the rows to display are in the selections (if not: ignore selections)
            if ~isempty(sSelect)
                AllRows = cat(2, sSelect.ChanNames);
                if ~all(ismember(RowNames, AllRows))
                    sSelect = [];
                    disp('Oops select');
                end
            end
            % Use selections
            if ~isempty(sSelect)
                for iSel = 1:length(sSelect)
                    groupRows = intersect(RowNames, sSelect(iSel).ChanNames);
                    if ~isempty(groupRows) % empty if n x n graph
                        % Detect region based on name
                        Name = upper(sSelect(iSel).Name);
                        Region = [];
                        switch Name
                            case {'CTF LF'}
                                Region = 'LF';
                            case {'CTF LT'}
                                Region = 'LT';
                            case {'CTF LP'}
                                Region = 'LP';
                            case {'CTF LC'}
                                Region = 'LC';
                            case {'CTF LO'}
                                Region = 'LO';
                            case {'CTF RF'}
                                Region = 'RF';
                            case {'CTF RT'}
                                Region = 'RT';
                            case {'CTF RP'}
                                Region = 'RP';
                            case {'CTF RC'}
                                Region = 'RC';
                            case {'CTF RO'}
                                Region = 'RO';
                            case {'CTF ZC'}
                                Region = 'UU';
                            case {'LEFT-TEMPORAL'}
                                Region = 'LT';
                            case {'RIGHT-TEMPORAL'}
                                Region = 'RT';
                            case {'LEFT-PARIETAL'}
                                Region = 'LP';
                            case {'RIGHT-PARIETAL'}
                                Region = 'RP';
                            case {'LEFT-OCCIPITAL'}
                                Region = 'LO';
                            case {'RIGHT-OCCIPITAL'}
                                Region = 'RO';
                            case {'LEFT-FRONTAL'}
                                Region = 'LF';
                            case {'RIGHT-FRONTAL'}
                                Region = 'RF';
                        end
                        if (~isempty(Region))
                            iGroup = length(sGroups) + 1;
                            sGroups(iGroup).Name = sSelect(iSel).Name;
                            sGroups(iGroup).RowNames = groupRows;
                            sGroups(iGroup).Region = Region;
                        end
                    end
                end
            end
            % Sensors positions
            selChan = zeros(1, length(RowNames));
            for iRow = 1:length(RowNames)
                % Get indice in the 
                selChan(iRow) = find(strcmpi({GlobalData.DataSet(iDS).Channel.Name}, RowNames{iRow}));
            end
            RowLocs = figure_3d('GetChannelPositions', iDS, selChan);
 
        case {'results', 'matrix'}
            % Get the file information file
            SurfaceFile = GlobalData.DataSet(iDS).Timefreq(iTimefreq).SurfaceFile;
            Atlas       = GlobalData.DataSet(iDS).Timefreq(iTimefreq).Atlas;
            % Load surface
            if ~isempty(SurfaceFile) && ischar(SurfaceFile)
                SurfaceMat = in_tess_bst(SurfaceFile);
                Vertices = SurfaceMat.Vertices;
            end
            % If an atlas is available
            if ~isempty(Atlas) && ~isempty(SurfaceFile) && ~isempty(Vertices)
                % Create groups using the file atlas
                sGroups = GroupScouts(Atlas);
                % Get the position of each scout: use the seed position
                RowLocs = Vertices([Atlas.Scouts.Seed], :);
            elseif ~isempty(Vertices)
                RowLocs = Vertices;
            end
 
        otherwise
            error('Unsupported');
    end
    
    DisplayInCircle = 0;
    DisplayInRegion = 0;
    
    % Assign generic name if necessary
    if isempty(RowNames)
        RowNames = cellstr(num2str((1:size(Vertices,1))'));
    end
    % Ensure proper alignment
    if (size(RowNames,2) > size(RowNames,1))
        RowNames = RowNames';
    end
    % Ensure proper type
    if isa(RowNames, 'double')
        RowNames = cellstr(num2str(RowNames));
    end
    
    %% === ASSIGN GROUPS: CRUCIAL STEP @NOTE: DONE ===
    % display in circle
    if isempty(sGroups)
        % No data to arrange in groups
        if isempty(RowLocs) || isempty(SurfaceMat)
            DisplayInCircle = 1;
            % Create a group for each node
            sGroups = repmat(struct('Name', [], 'RowNames', [], 'Region', []), 0);
            for i=1:length(RowNames)
                sGroups(1).Name = RowNames{i};
                sGroups(1).RowNames = [sGroups(1).RowNames {num2str(RowNames{i})}];
                sGroups(1).Region = 'UU';
            end
        else
            % We have location data so we can aim for
            % a basic 4 quadrants display
            DisplayInRegion = 1;            
            sGroups = AssignGroupBasedOnCentroid(RowLocs, RowNames, sGroups, SurfaceMat);
        end
    else
        % Display in region
        DisplayInRegion = 1;
        % Force basic Anterior/Posterior if necessary
        if (length(sGroups) == 2 && ...
            strcmp(sGroups(1).Region(2), 'U') == 1 && ...
            strcmp(sGroups(2).Region(2), 'U') == 1)
            sGroups = AssignGroupBasedOnCentroid(RowLocs, RowNames, sGroups, SurfaceMat);
        end
    end
    setappdata(hFig, 'DisplayInCircle', DisplayInCircle);
    setappdata(hFig, 'DisplayInRegion', DisplayInRegion);
 
    % IsBinaryData -> Granger
    % IsDirectionalData -> Granger
    setappdata(hFig, 'DefaultRegionFunction', 'max');
    setappdata(hFig, 'DisplayOutwardMeasure', 1);
    setappdata(hFig, 'DisplayInwardMeasure', 1);
    setappdata(hFig, 'HasLocationsData', ~isempty(RowLocs));
    setappdata(hFig, 'MeasureDistanceFactor', 1000); % mm to m
    
    % Retrieve scout colors if possible
    RowColors = BuildNodeColorList(RowNames, Atlas);
    
    % Keep a copy of these variable for figure updates
    bst_figures('SetFigureHandleField', hFig, 'Groups', sGroups);
    bst_figures('SetFigureHandleField', hFig, 'RowNames', RowNames);
    bst_figures('SetFigureHandleField', hFig, 'RowLocs', RowLocs);
    bst_figures('SetFigureHandleField', hFig, 'RowColors', RowColors);
    
    %% ===== ORGANISE VERTICES @NOTE: DONE=====    
    if DisplayInCircle
        [Vertices Paths Names] = OrganiseNodeInCircle(hFig, RowNames, sGroups);
    elseif DisplayInRegion
        [Vertices Paths Names] = OrganiseNodesWithConstantLobe(hFig, RowNames, sGroups, RowLocs, 1);
    else
        disp('Unsupported display. Please contact administrator- Sorry for the inconvenience.');
    end
    
    % Keep graph data
    bst_figures('SetFigureHandleField', hFig, 'NumberOfNodes', size(Vertices,1));
    bst_figures('SetFigureHandleField', hFig, 'Vertices', Vertices);
    bst_figures('SetFigureHandleField', hFig, 'NodePaths', Paths);
    bst_figures('SetFigureHandleField', hFig, 'Names', Names);
    bst_figures('SetFigureHandleField', hFig, 'DisplayNode', ones(size(Vertices,1),1));
    bst_figures('SetFigureHandleField', hFig, 'ValidNode', ones(size(Vertices,1),1));
    
    %% ===== Create Nodes =====
    %  This also defines some data-based display parameters
    
    ClearAndAddNodes(hFig, Vertices, Names);
    GlobalData.FigConnect.ClickedNodeIndex = 0;  %set initial clicked node to 0 (none)
    
    GlobalData.FigConnect.Figure = hFig;
    GlobalData.FigConnect.ClickedLinkIndex = 0; 
    GlobalData.FigConnect.ClickedArrowIndex = 0;
    GlobalData.FigConnect.ClickedNode1Index = 0;
    GlobalData.FigConnect.ClickedNode2Index = 0;
    
    % background color : 
    %   White is for publications
    %   Black for visualization (default)
    BackgroundColor = GetBackgroundColor(hFig);
    SetBackgroundColor(hFig, BackgroundColor);
 
    
    %% ===== Compute Links =====
    % Data cleaning options
    Options.Neighbours = 0;
    Options.Distance = 0;
    Options.Highest = 1;
    setappdata(hFig, 'LoadingOptions', Options);
    % Clean and compute Datapair
    DataPair = LoadConnectivityData(hFig, Options, Atlas, SurfaceMat);    
    bst_figures('SetFigureHandleField', hFig, 'DataPair', DataPair);
    
    % Compute distance between regions
    MeasureDistance = [];
    if ~isempty(RowLocs)
        MeasureDistance = ComputeEuclideanMeasureDistance(hFig, DataPair, RowLocs);
    end
    bst_figures('SetFigureHandleField', hFig, 'MeasureDistance', MeasureDistance);
    
    
    %% ==== Create and Display Links =======
   
    % Create links from computed DataPair
    BuildLinks(hFig, DataPair, true);
    LinkSize = getappdata(hFig, 'LinkSize');
    SetLinkSize(hFig, LinkSize);
    SetLinkTransparency(hFig, 0.00);
        
    %% ===== Init Filters =====
    % Default intensity threshold
    MinThreshold = 0.9;
    
    % Don't refresh display for each filter at loading time
    Refresh = 0;
    
    % Clear filter masks
    bst_figures('SetFigureHandleField', hFig, 'MeasureDistanceMask', zeros(size(DataPair,1),1));
    bst_figures('SetFigureHandleField', hFig, 'MeasureThresholdMask', zeros(size(DataPair,1),1));
    bst_figures('SetFigureHandleField', hFig, 'MeasureAnatomicalMask', zeros(size(DataPair,1),1));
    bst_figures('SetFigureHandleField', hFig, 'MeasureDisplayMask', zeros(size(DataPair,1),1));
    
    % Application specific display filter
    SetMeasureDisplayFilter(hFig, ones(size(DataPair,1), Refresh));
    % Min/Max distance filter
    SetMeasureDistanceFilter(hFig, 20, 150, Refresh);
    % Anatomy filter
    SetMeasureAnatomicalFilterTo(hFig, 0, Refresh);
    % Fiber filter
    SetMeasureFiberFilterTo(hFig, 0, Refresh);
    % Causality direction filter
    IsDirectionalData = getappdata(hFig, 'IsDirectionalData');
    if (IsDirectionalData)
        setDisplayMeasureMode(hFig, 1, 1, 1, Refresh);
    end
    % Threshold in absolute values
    if isempty(DataPair)
        ThresholdMinMax = [0 0];
    else
        ThresholdAbsoluteValue = getappdata(hFig, 'ThresholdAbsoluteValue');
        if isempty(ThresholdAbsoluteValue) || ~ThresholdAbsoluteValue
            ThresholdMinMax = [min(DataPair(:,3)), max(DataPair(:,3))];
        else
            ThresholdMinMax = [min(abs(DataPair(:,3))), max(abs(DataPair(:,3)))];
        end
    end
    bst_figures('SetFigureHandleField', hFig, 'ThresholdMinMax', ThresholdMinMax);
    % Minimum measure filter
    SetMeasureThreshold(hFig, ThresholdMinMax(1) + MinThreshold * (ThresholdMinMax(2) - ThresholdMinMax(1)), Refresh);
 
    % Region links
    SetRegionFunction(hFig, getappdata(hFig, 'DefaultRegionFunction'));
    
    %% ===== Rendering option =====
    % Required: Select all on default
    SetSelectedNodes(hFig, [], 1);
    SetHierarchyNodeIsVisible(hFig, 1);
    
    % Update colormap
    UpdateColormap(hFig);
    % Refresh Text Display Mode default set in CreateFigure
    RefreshTextDisplay(hFig);
    % Last minute hiding
    HideLonelyRegionNode(hFig);
    % Position camera
    DefaultCamera(hFig);
    % display final figure on top
    shg
end
 
%% ======== Create all links as Matlab Lines =====
function BuildLinks(hFig, DataPair, isMeasureLink)
    if (isMeasureLink)
        disp('Entered BuildLinks. Creating MeasureLinks');
    else
        disp('Entered BuildLinks. Creating RegionLinks');
    end;
    
    % get pre-created nodes
    AllNodes = getappdata(hFig, 'AllNodes');
    
    % clear any previous links
    % and get scaling distance from nodes to unit circle
    if (isMeasureLink)
        levelScale = getappdata(hFig, 'MeasureLevelDistance'); % typically 4 for measure (outer) nodes
        if (isappdata(hFig,'MeasureLinks'))
            delete(getappdata(hFig,'MeasureLinks'));
            rmappdata(hFig,'MeasureLinks');
        end
        if (isappdata(hFig,'MeasureArrows1'))
            delete(getappdata(hFig,'MeasureArrows1'));
            rmappdata(hFig,'MeasureArrows1');
        end
        if (isappdata(hFig,'MeasureArrows2'))
            delete(getappdata(hFig,'MeasureArrows2'));
            rmappdata(hFig,'MeasureArrows2');
        end
    else
        levelScale = getappdata(hFig, 'RegionLevelDistance');
        
        if (isappdata(hFig,'RegionLinks'))
            delete(getappdata(hFig,'RegionLinks'));
            rmappdata(hFig,'RegionLinks');
        end
        if (isappdata(hFig,'RegionArrows1'))
            delete(getappdata(hFig,'RegionArrows1'));
            rmappdata(hFig,'RegionArrows1');
        end
        if (isappdata(hFig,'RegionArrows2'))
            delete(getappdata(hFig,'RegionArrows2'));
            rmappdata(hFig,'RegionArrows2');
        end
    end
    
    % Note: DataPair computation already removed diagonal and capped at max 5000
    % pairs
    
    % Draw Links on the Poincare hyperbolic disk.
    %
    % Equation of the circles on the disk (u,v points on boundary):
    % x^2 + y^2 
    % + 2*(u(2)-v(2))/(u(1)*v(2)-u(2)*v(1))*x
    % - 2*(u(1)-v(1))/(u(1)*v(2)-u(2)*v(1))*y + 1 = 0,
    %
    % Standard form of equation of a circle:
    % (x - x0)^2 + (y - y0)^2 = r^2
    %
    % Therefore we can identify:
    % x0 = -(u(2)-v(2))/(u(1)*v(2)-u(2)*v(1));
    % y0 = (u(1)-v(1))/(u(1)*v(2)-u(2)*v(1));
    % r^2 = x0^2 + y0^2 - 1
    
    All_u = [];
    All_v = [];
    IsDirectionalData = getappdata(hFig, 'IsDirectionalData');
    
    for i = 1:length(DataPair) %for each link
        
        % node positions (rescaled to *unit* circle)
        node1 = DataPair(i,1);
        node2 = DataPair(i,2);
        u  = [AllNodes(node1).Position(1);AllNodes(node1).Position(2)]/levelScale;
        v  = [AllNodes(node2).Position(1);AllNodes(node2).Position(2)]/levelScale;    
        
        % check if 2 bidirectional links overlap
        if(i==1)
            All_u(1,:) = u.';
            All_v(1,:) = v.';
        else
            All_u(end+1,:) = u.';
            All_v(end+1,:) = v.';
        end

        % diametric points: draw a straight line
        % can adjust the error margin (currently 0.2)
        if (abs(u(1)+v(1))<0.2 && abs(u(2)+v(2))<0.2)
            x = linspace(levelScale*u(1),levelScale*v(1),100);
            y = linspace(levelScale*u(2),levelScale*v(2),100);
            
            % check if this line has a bidirectional equivalent that would
            % overlap
            for j = 1:length(All_u)-1
                if (v(1) == All_u(j,1) & v(2) == All_u(j,2) & u(1) == All_v(j,1) & u(2) == All_v(j,2))
                    
                    % return to scaled position values
                    start_x = AllNodes(node1).Position(1);
                    stop_x = AllNodes(node2).Position(1);
                    start_y = AllNodes(node1).Position(2);
                    stop_y = AllNodes(node2).Position(2);
                    
                    p = [(start_x-stop_x) (start_y-stop_y)];          % horde vector
                    H = norm(p);                                % horde length
                    R = 0.63*H;                                  % arc radius
                    v = [-p(2) p(1)]/H;                         % perpendicular vector
                    L = sqrt(R*R-H*H/4);						% distance to circle (from horde)
                    p = [(start_x+stop_x) (start_y+stop_y)];          % vector center horde
                    p0(1,:) = p/2 + v*L;                        % circle center 1
                    p0(2,:) = p/2 - v*L;                        % circle center 2
                    d = sqrt(sum(p0.^2,2));                     % distance to circle center
                    [~,ix] = max( d );                          % get max (circle outside)
                    p0 = p0(ix,:);
                    
                    % generate arc points
                    vx = linspace(start_x,stop_x,100);				% horde points
                    vy = linspace(start_y,stop_y,100);
                    vx = vx - p0(1);
                    vy = vy - p0(2);
                    v = sqrt(vx.^2+vy.^2);
                    x = p0(1) + vx./v*R;
                    y = p0(2) + vy./v*R;
                end
            end
            
            l = line(...
                x,...
                y,...
                'LineWidth', 1.5,...
                'Color', [AllNodes(node1).Color 0.00],...
                'PickableParts','visible',...
                'Visible','off',...
                'UserData',[i IsDirectionalData isMeasureLink node1 node2],... % i is the index
                'ButtonDownFcn',@LinkButtonDownFcn); % not visible as default;

        else % else, draw an arc
            x0 = -(u(2)-v(2))/(u(1)*v(2)-u(2)*v(1));
            y0 =  (u(1)-v(1))/(u(1)*v(2)-u(2)*v( 1));
            r  = sqrt(x0^2 + y0^2 - 1);
                        
            thetaLim(1) = atan2(u(2)-y0,u(1)-x0);
            thetaLim(2) = atan2(v(2)-y0,v(1)-x0);
            
            % for arcs on the right-hand side, ensure they are drawn within the graph
            if (u(1) >= 0 && v(1) >= 0)
                first = abs(pi - max(thetaLim));
                second = abs(-pi - min(thetaLim));
                fraction = floor((first/(first + second))*100);
                remaining = 100 - fraction;
                
                % ensure the arc is within the unit disk
                
                % direction: from thetaLim(1) to thetaLim(2)
                if (max(thetaLim) == thetaLim(1))
                    theta = [linspace(max(thetaLim),pi,fraction),...
                        linspace(-pi,min(thetaLim),remaining)].';
                else
                    theta = [linspace(min(thetaLim),-pi,remaining),...
                        linspace(pi,max(thetaLim),fraction)].';
                end
            else
                theta = linspace(thetaLim(1),thetaLim(2)).';
            end    
                
            % rescale onto our graph circle
            x = levelScale*r*cos(theta)+levelScale*x0;
            y = levelScale*r*sin(theta)+levelScale*y0;

            % check if this line has a bidirectional equivalent that would
            % overlap
            for j = 1:length(All_u)-1
                if (v(1) == All_u(j,1) & v(2) == All_u(j,2) & u(1) == All_v(j,1) & u(2) == All_v(j,2))
                    
                    % return to scaled position values
                    start_x = AllNodes(node1).Position(1);
                    stop_x = AllNodes(node2).Position(1);
                    start_y = AllNodes(node1).Position(2);
                    stop_y = AllNodes(node2).Position(2);
                    
                    p = [(start_x-stop_x) (start_y-stop_y)];          % horde vector
                    H = norm(p);                                % horde length
                    R = 0.63*H;                                  % arc radius
                    v = [-p(2) p(1)]/H;                         % perpendicular vector
                    L = sqrt(R*R-H*H/4);						% distance to circle (from horde)
                    p = [(start_x+stop_x) (start_y+stop_y)];          % vector center horde
                    p0(1,:) = p/2 + v*L;                        % circle center 1
                    p0(2,:) = p/2 - v*L;                        % circle center 2
                    d = sqrt(sum(p0.^2,2));                     % distance to circle center
                    [~,ix] = max( d );                          % get max (circle outside)
                    p0 = p0(ix,:);
                    
                    % generate arc points
                    vx = linspace(start_x,stop_x,100);				% horde points
                    vy = linspace(start_y,stop_y,100);
                    vx = vx - p0(1);
                    vy = vy - p0(2);
                    v = sqrt(vx.^2+vy.^2);
                    x = p0(1) + vx./v*R;
                    y = p0(2) + vy./v*R;
                end
            end

            % Create the link as a line object
            % default colour for now, will be updated in updateColormap
            % Link Size set to 1.5 by default
            % line with no arrow marker
            l = line(...
                x,...
                y,...
                'LineWidth', 1.5,...
                'Color', [AllNodes(node1).Color 0.00],...
                'PickableParts','visible',...
                'Visible','off',...
                'UserData',[i IsDirectionalData isMeasureLink node1 node2],... % i is the index
                'ButtonDownFcn',@LinkButtonDownFcn); % not visible as default;
        end
            
        % arrows for directional links
        if (IsDirectionalData)
            
            MeasureDistance = bst_figures('GetFigureHandleField', hFig, 'MeasureDistance');

            [arrow1, new_x, new_y] = arrowh(x, y, AllNodes(node1).Color, 100, 50, 1, i, isMeasureLink, node1, node2);
            
            % return point on the line closest to the desired location of
            % the second arrowhead (tip of second arrowhead should be at
            % the base of the first one)
            pts_line = [x(:), y(:)];
            dist2 = sum((pts_line - [new_x new_y]) .^ 2, 2);
            [distances, index] = min(dist2);
            
            % if more than one index is found, return the one closest to 70
            if (size(index) > 1)
                index = min(60 - index);
            end
            
            % redraw the first arrow so that both arrows are closer to
            % the center of the link
            x_trim = pts_line(1:index,1);
            y_trim = pts_line(1:index,2);
            
            % overwrite arrowhead2
            if (length(x_trim) > 1 && length(y_trim) > 1)
                [arrow2, ~, ~] = arrowh(x_trim, y_trim, AllNodes(node1).Color, 100, 100, 0, i, isMeasureLink, node1, node2);
            end

            % store arrows
            if(i==1)
                Arrows1 = arrow1;
                if (~isempty(arrow2))
                    Arrows2 = arrow2;
                end
            else
                Arrows1(end+1) = arrow1;
                if (~isempty(arrow2))
                    Arrows2(end+1) = arrow2;
                end
            end
        end
        
        % add link to list
        if(i==1)
            Links(i) = l;
        else
            Links(end+1) = l;
        end
    end
    
    % Store Links into figure  % Very important!
    if (isMeasureLink)
        setappdata(hFig,'MeasureLinks',Links);
        if (IsDirectionalData)
            setappdata(hFig,'MeasureArrows1',Arrows1);
            setappdata(hFig,'MeasureArrows2',Arrows2);
        end
    else
        setappdata(hFig,'RegionLinks',Links);
        if (IsDirectionalData)
            setappdata(hFig,'RegionArrows1',Arrows1);
            setappdata(hFig,'RegionArrows2',Arrows2);
        end
    end
    
end

function LinkButtonDownFcn(src, ~)
    disp('Entered LinkButtonDownFcn');
    global GlobalData;
    hFig = GlobalData.FigConnect.Figure;
    clickAction = getappdata(hFig, 'clickAction');
    AllNodes = getappdata(hFig, 'AllNodes');
    
    Index = src.UserData(1);
    IsDirectional = src.UserData(2);
    isMeasureLink = src.UserData(3);
    
    GlobalData.FigConnect.ClickedLinkIndex = src.UserData(1);
    GlobalData.FigConnect.ClickedNode1Index = src.UserData(4); 
    GlobalData.FigConnect.ClickedNode2Index = src.UserData(5); 
    
    % only works for left mouse clicks
    if (strcmpi(clickAction, 'SingleClick'))    
        % increase size on button down click
        current_size = src.LineWidth;
        set(src, 'LineWidth', 3.0*current_size);
        
        node1 = AllNodes(src.UserData(4));
        label1 = node1.TextLabel;
        node2 = AllNodes(src.UserData(5));
        label2 = node2.TextLabel;
        current_labelSize = label1.FontSize;
        set(label1, 'FontWeight', 'bold');
        set(label2, 'FontWeight', 'bold');
        set(label1, 'FontSize', current_labelSize + 2);
        set(label2, 'FontSize', current_labelSize + 2);
        
%         set(label1, 'EdgeColor', 'y');
%         set(label1, 'Margin', 1);
%         set(label2, 'EdgeColor', 'y');
%         set(label2, 'Margin', 1);
        
        if (IsDirectional)
            if (isMeasureLink)
                Arrows1 = getappdata(hFig,'MeasureArrows1');
                Arrows2 = getappdata(hFig,'MeasureArrows2');
            else
                Arrows1 = getappdata(hFig,'RegionArrows1');
                Arrows2 = getappdata(hFig,'RegionArrows2');
            end    
            arrow1 = Arrows1(Index);
            arrow2 = Arrows2(Index);
            arrow_size = arrow1.LineWidth;
            
            set(arrow1, 'LineWidth', 3.0*arrow_size);
            set(arrow2, 'LineWidth', 3.0*arrow_size);
        end
    end
end

function LinkClickEvent(hFig,LinkIndex,LinkType,IsDirectional,node1Index,node2Index)
   disp('Entered LinkClickEvent');
   
    % measure links
    if (LinkType)
        MeasureLinks = getappdata(hFig,'MeasureLinks');
        Link = MeasureLinks(LinkIndex);
        current_size = Link.LineWidth;
        set(Link, 'LineWidth', current_size/3.0);
        
        if (IsDirectional)
            Arrows1 = getappdata(hFig,'MeasureArrows1');
            Arrows2 = getappdata(hFig,'MeasureArrows2');   
        end    
        
    else % region links
        RegionLinks = getappdata(hFig,'RegionLinks');
        Link = RegionLinks(LinkIndex);
        current_size = Link.LineWidth;     
        set(Link, 'LineWidth', current_size/3.0);
        
        if (IsDirectional)
            Arrows1 = getappdata(hFig,'RegionArrows1');
            Arrows2 = getappdata(hFig,'RegionArrows2');   
        end  
    end   
    
    if (IsDirectional)
        arrow1 = Arrows1(LinkIndex);
        arrow2 = Arrows2(LinkIndex);
        arrow_size = arrow1.LineWidth;

        set(arrow1, 'LineWidth', arrow_size/3.0);
        set(arrow2, 'LineWidth', arrow_size/3.0);
    end
    
    AllNodes = getappdata(hFig, 'AllNodes');
    node1 = AllNodes(node1Index);
    node2 = AllNodes(node2Index);
    label1 = node1.TextLabel;
    label2 = node2.TextLabel;
    current_labelSize = label1.FontSize;
    
    set(label1, 'FontWeight', 'normal');
    set(label2, 'FontWeight', 'normal');
    set(label1, 'FontSize', current_labelSize - 2);
    set(label2, 'FontSize', current_labelSize - 2);
    
%     set(label1, 'EdgeColor', 'none');
%     set(label2, 'EdgeColor', 'none');
end

%% ARROWH   Draws a solid 2D arrow head in current plot.
%	 ARROWH(X,Y,COLOR,SIZE,LOCATION) draws a  solid arrow  head into
%	 the current plot to indicate a direction.  X and Y must contain
%	 a pair of x and y coordinates ([x1 x2],[y1 y2]) of two points:
%
%	 The first  point is only used to tell  (in conjunction with the
%	 second one)  the direction  and orientation of  the arrow -- it
%	 will point from the first towards the second.
%
%	 The head of the arrow  will be located in the second point.  An
%	 example of use is	plot([0 2],[0 4]); ARROWH([0 1],[0 2],'b')
%
%	 You may also give  two vectors of same length > 2.  The routine
%	 will then choose two consecutive points from "about" the middle
%	 of each vectors.  Useful if you  don't want to worry  each time
%	 about  where to  put the arrows on  a trajectory.  If x1 and x2
%	 are the vectors x1(t) and x2(t), simply put   ARROWH(x1,x2,'r')
%	 to have the right  direction indicated in your x2 = f(x1) phase
%	 plane.
%
%            (x2,y2)
%            --o
%            \ |
%	            \|
%
%
%		  o
%	  (x1,y1)
%
%	 Please note  that the following  optional arguments  need -- if
%	 you want  to use them -- to  be given in that exact order.  You
%	 may pass on empty vectors "[]" to skip arguments you don't want
%	 to set (if you want to access "later" arguments...).
%
%	 The COLOR argument is quite the same as for plots,  i.e. either
%  a string like  'r' or an RGB value vector like  [1 0 0]. If you
%  only want the outlines of the head  (in other words a non-solid
%  arrow head), prefix the color string by 'e' or the color vector
%  by 0, e.g. to get only a red outline use 'er' or [0 1 0 0].
%
%	 The SIZE argument allows you to tune the size of the arrows. If
%	 SIZE is a scalar, it scales the arrow proportionally.  SIZE can
%	 also be  a two element vector,  where the first element  is the
%	 overall  scale (in percent),  the second one controls the width
%	 of the arrow head (again, in percent).
%
%	 The LOCAITON argument can be used to tweak the position  of the
%  arrow head.  If a time series of x and y coordinates are given,
%  you can use this argument  to place the arrow head for instance
%  at 20% along the line.  It can be a vector, if you want to have
%  more than one arrow head drawn.
%
%	 Both SIZE and LOCATION arguments must also be given in percent,
%	 where 100 means standard size, 50 means half size, respectively
%	 100 means end of the vector, 0 beginning of it. Note that those
%	 "locations" correspond to the cardinal position "inside" the
%	 vector, in other words the "index-wise" position.
%
%	 This little tool is mainely intended  to be used for indicating
%	 "directions" on trajectories -- just give two consecutive times
%	 and the corresponding values of a flux and the proper direction
%	 of the trajectory will be shown on the plot.  You may also pass
%	 on two solution vectors, as described above.
%
%	 Note, that the arrow  heads only look good in the original axis
%	 settings (as in when the routine was actually started).  If you
%	 zoom in afterwards, the triangle will get distorted.
%
%  HANDLES = ARROWH(...)  will give you a vector with  the handles
%  to the patches created by this function  (if you want to modify
%  them later on, for instance).
%
%	 Examples of use:
% 	 x1 = [0:.2:2]; x2 = [0:.2:2]; plot(x1,x2); hold on;
% 	 arrowh(x1,x2,'r',[],20);            % passing entire vectors
% 	 arrowh([0 1],[0 1],'eb',[300,75]);  % passing 2 points
% 	 arrowh([0 1],[0 1],'eb',[300,75],25); % head closer to (x1,y1)
%	 Author:     Florian Knorn
%	 Email:      florian@knorn.org
%	 Version:    1.14
%	 Filedate:   Jun 18th, 2008
%
%	 History:    1.14 - LOCATION now also works with lines
%              1.13 - Allow for non-solid arrow heads
%              1.12 - Return handle(s) of created patches
%              1.11 - Possibility to change width
%	             1.10 - Buxfix
%	             1.09 - Possibility to chose *several* locations
%	             1.08 - Possibility to chose location
%	             1.07 - Choice of color
%	             1.06 - Bug fixes
%	             1.00 - Release
%
%	 ToDos:      - Keep proportions when zooming or resizing; has to
%	               be done with callback functions, I guess.
%
%	 Bugs:       None discovered yet, those discovered were fixed
%
%	 Thanks:     Thanks  also  to Oskar Vivero  for using  my humble
%	             little program in his great MIMO-Toolbox.
%
%	 If you have  suggestions for  this program,  if it doesn't work
%	 for your "situation" or if you change something in it -- please
%	 send me an email!  This is my very  first "public" program  and
%	 I'd  like to  improve it where  I can -- your  help is  kindely
%	 appreciated! Thank you!
function [handle, new_x, new_y] = arrowh(x,y,clr,ArSize,Where,Flag,Index,isMeasureLink,node1,node2)
%-- errors
if nargin < 2
	error('Please give enough coordinates !');
end
if (length(x) < 2) || (length(y) < 2),
	error('X and Y vectors must each have "length" >= 2 !');
end
if (x(1) == x(2)) && (y(1) == y(2)),
	error('Points superimposed - cannot determine direction !');
end
if nargin <= 2
	clr = 'b';
end
if nargin <= 3
	ArSize = [100,100];
end
handle1 = [];
handle2 = [];
%-- check if variables left empty, deal width ArSize and Color
if isempty(clr)
	clr = 'b'; nonsolid = false;
elseif ischar(clr)
	if strncmp('e',clr,1) % for non-solid arrow heads
		nonsolid = true; clr = clr(2);
	else
		nonsolid = false;
	end
elseif isvector(clr)
	if length(clr) == 4 && clr(1) == 0  % for non-solid arrow heads
		nonsolid = true;
		clr = clr(2:end);
	else
		nonsolid = false;
	end
else
	error('COLOR argument of wrong type (must be either char or vector)');
end
if nargin <= 4
	if (length(x) == length(y)) && (length(x) == 2)
		Where = 100;
	else
		Where = 50;
	end
end
if isempty(ArSize)
	ArSize = [100,100];
end
if length(ArSize) == 2
	ArWidth = 0.75*ArSize(2)/100; % .75 to make arrows it a bit slimmer
else
	ArWidth = 0.75;
end
ArSize = ArSize(1);
%-- determine and remember the hold status, toggle if necessary
if ishold,
	WasHold = 1;
else
	WasHold = 0;
	hold on;
end
%-- start for-loop in case several arrows are wanted
for Loop = 1:length(Where),
	%-- if vectors "longer" then 2 are given we're dealing with time series
	if (length(x) == length(y)) && (length(x) > 2),       
		j = floor(length(x)*Where(Loop)/100); %-- determine that location
		if j >= length(x), j = length(x) - 1; end
		if j == 0, j = 1; end        
		x1 = x(j); x2 = x(j+1); y1 = y(j); y2 = y(j+1);
	else %-- just two points given - take those
		x1 = x(1); x2 = (1-Where/100)*x(1)+Where/100*x(2);
		y1 = y(1); y2 = (1-Where/100)*y(1)+Where/100*y(2);
    end
    
	%-- get axe ranges and their norm
	OriginalAxis = axis;
	Xextend = abs(OriginalAxis(2)-OriginalAxis(1));
	Yextend = abs(OriginalAxis(4)-OriginalAxis(3));
	%-- determine angle for the rotation of the triangle
	if x2 == x1, %-- line vertical, no need to calculate slope
		if y2 > y1,
			p = pi/2;
		else
			p= -pi/2;
		end
	else %-- line not vertical, go ahead and calculate slope
		%-- using normed differences (looks better like that)
		m = ( (y2 - y1)/Yextend ) / ( (x2 - x1)/Xextend );
		if x2 > x1, %-- now calculate the resulting angle
			p = atan(m);
		else
			p = atan(m) + pi;
		end
	end
	%-- the arrow is made of a transformed "template triangle".
	%-- it will be created, rotated, moved, resized and shifted.
	%-- the template triangle (it points "east", centered in (0,0)):
	xt = [1	-sin(pi/6)	-sin(pi/6)];
	yt = ArWidth*[0	 cos(pi/6)	-cos(pi/6)];
	%-- rotate it by the angle determined above:
	xd = []; yd = [];
	for i=1:3
		xd(i) = cos(p)*xt(i) - sin(p)*yt(i);
		yd(i) = sin(p)*xt(i) + cos(p)*yt(i);
	end
	%-- move the triangle so that its "head" lays in (0,0):
	xd = xd - cos(p);
	yd = yd - sin(p);
	%-- stretch/deform the triangle to look good on the current axes:
	xd = xd*Xextend*ArSize/10000;
	yd = yd*Yextend*ArSize/10000;
	%-- move the triangle to the location where it's needed
	xd1 = xd + x2;
	yd1 = yd + y2;
    
    
    %%%% Added Feb 18: Visibility %%%%%
    
    % tip of the second arrow
    new_x = (xd1(2)+xd1(3))/2;
    new_y = (yd1(2)+yd1(3))/2;
    xd2 = xd + new_x;
	yd2 = yd + new_y;
    
    
	%-- draw the actual triangles
 	handle(Loop) = patch(xd1,...
                         yd1,...
                         clr,...
                         'EdgeColor',clr,...
                         'FaceColor',clr,...
                         'Visible', 'off',...
                         'PickableParts','visible',...
                         'UserData',[Flag Index isMeasureLink node1,node2],... % flag == 1 when it's the first arrow, and 0 for the second one
                         'ButtonDownFcn',@ArrowButtonDownFcn); 
    
	if nonsolid, set(handle(Loop),'facecolor','none'); end
end % Loops

%-- restore original axe ranges and hold status
axis(OriginalAxis);
if ~WasHold
	hold off;
end
%-- work done. good bye.
end

function ArrowButtonDownFcn(src, ~)
    disp('Entered ArrowButtonDownFcn');
    global GlobalData;
    hFig = GlobalData.FigConnect.Figure;
    clickAction = getappdata(hFig, 'clickAction');
    AllNodes = getappdata(hFig, 'AllNodes');
    
    ArrowType = src.UserData(1);
    Index = src.UserData(2);
    isMeasureLink = src.UserData(3);
    GlobalData.FigConnect.ClickedArrowIndex = src.UserData(2);
    GlobalData.FigConnect.ClickedNode1Index = src.UserData(4); 
    GlobalData.FigConnect.ClickedNode2Index = src.UserData(5);
    
    % only works for left mouse clicks
    if (strcmpi(clickAction, 'SingleClick'))    
        % increase size of the selected arrow
        current_size = src.LineWidth;
        set(src, 'LineWidth', 3.0*current_size);
        
        node1 = AllNodes(src.UserData(4));
        label1 = node1.TextLabel;
        node2 = AllNodes(src.UserData(5));
        label2 = node2.TextLabel;
        current_labelSize = label1.FontSize;
        set(label1, 'FontWeight', 'bold');
        set(label2, 'FontWeight', 'bold');
        set(label1, 'FontSize', current_labelSize + 2);
        set(label2, 'FontSize', current_labelSize + 2);

        if (isMeasureLink)
            if (ArrowType) % first
                Arrows = getappdata(hFig,'MeasureArrows2');
            else
                Arrows = getappdata(hFig,'MeasureArrows1');
            end
            otherArrow = Arrows(Index);
            arrow_size = otherArrow.LineWidth;            
            set(otherArrow, 'LineWidth', 3.0*arrow_size);
            
            AllLinks = getappdata(hFig,'MeasureLinks');
            Link = AllLinks(Index);
            link_size = Link.LineWidth;
            set(Link, 'LineWidth', 3.0*link_size);
        else
            if (ArrowType) % first
                Arrows = getappdata(hFig,'RegionArrows2');
            else
                Arrows = getappdata(hFig,'RegionArrows1');
            end
            otherArrow = Arrows(Index);
            arrow_size = otherArrow.LineWidth;            
            set(otherArrow, 'LineWidth', 3.0*arrow_size);
            
            AllLinks = getappdata(hFig,'RegionLinks');
            Link = AllLinks(Index);
            link_size = Link.LineWidth;
            set(Link, 'LineWidth', 3.0*link_size);
        end
    end
end

function ArrowClickEvent(hFig,ArrowIndex,LinkType,Node1Index,Node2Index)
   disp('Entered ArrowClickEvent');
   
    % measure links
    if (LinkType)
        MeasureLinks = getappdata(hFig,'MeasureLinks');
        Link = MeasureLinks(ArrowIndex);
        current_size = Link.LineWidth;
        set(Link, 'LineWidth', current_size/3.0);   
        
    else % region links
        RegionLinks = getappdata(hFig,'RegionLinks');
        Link = RegionLinks(ArrowIndex);
        current_size = Link.LineWidth;     
        set(Link, 'LineWidth', current_size/3.0);   
    end
    
    Arrows1 = getappdata(hFig,'MeasureArrows1');
    Arrows2 = getappdata(hFig,'MeasureArrows2');
    arrow1 = Arrows1(ArrowIndex);
    arrow2 = Arrows2(ArrowIndex);
    
    arrow_size = arrow1.LineWidth;
    set(arrow1, 'LineWidth', arrow_size/3.0);
    set(arrow2, 'LineWidth', arrow_size/3.0);
    
    AllNodes = getappdata(hFig, 'AllNodes');   
    node1 = AllNodes(Node1Index);
    label1 = node1.TextLabel;
    node2 = AllNodes(Node2Index);
    label2 = node2.TextLabel;
    current_labelSize = label1.FontSize;
    
    set(label1, 'FontWeight', 'normal');
    set(label2, 'FontWeight', 'normal');
    set(label1, 'FontSize', current_labelSize - 2);
    set(label2, 'FontSize', current_labelSize - 2);
end


%test callback function
function test(hFig)
   AllNodes = getappdata(hFig,'AllNodes');
   MeasureLinks = getappdata(hFig,'MeasureLinks');
   RegionLinks = getappdata(hFig,'RegionLinks');
   % Lobe Nodes have can have full label (e.g. 'Pre-Frontal') or abbr 'PF'
end
 
 
function NodeColors = BuildNodeColorList(RowNames, Atlas)
    % We assume RowNames and Scouts are in the same order
    if ~isempty(Atlas)
        NodeColors = reshape([Atlas.Scouts.Color], 3, length(Atlas.Scouts))';
    else
        % Default neutral color
        NodeColors = 0.5 * ones(length(RowNames),3);
    end
end
 
function sGroups = AssignGroupBasedOnCentroid(RowLocs, RowNames, sGroups, Surface)
    % Compute centroid
    Centroid = sum(Surface.Vertices,1) / size(Surface.Vertices,1);
    % Split in hemisphere first if necessary
    if isempty(sGroups)
        % 
        sGroups(1).Name = 'Left';
        sGroups(1).Region = 'LU';
        sGroups(2).Name = 'Right';
        sGroups(2).Region = 'RU';
        % 
        sGroups(1).RowNames = RowNames(RowLocs(:,2) >= Centroid(2));    
        sGroups(2).RowNames = RowNames(RowLocs(:,2) < Centroid(2));
    end
    % For each hemisphere
    for i=1:2
        OriginalGroupRows = ismember(RowNames, [sGroups(i).RowNames]);
        Posterior = RowLocs(:,1) >= Centroid(1) & OriginalGroupRows;
        Anterior = RowLocs(:,1) < Centroid(1) & OriginalGroupRows;
        % Posterior assignment
        sGroups(i).Name = [sGroups(i).Name ' Posterior'];
        sGroups(i).RowNames = RowNames(Posterior)';
        sGroups(i).Region = [sGroups(i).Region(1) 'P'];
        % Anterior assignment
        sGroups(i+2).Name = [sGroups(i).Name ' Anterior'];
        sGroups(i+2).RowNames = RowNames(Anterior)';
        sGroups(i+2).Region = [sGroups(i).Region(1) 'A'];
    end
end
 
%TODO: update to same logic as loadFigurePlot
function UpdateFigurePlot(hFig)
    disp('Entered UpdateFigurePlot');
    % Progress bar
    bst_progress('start', 'Functional Connectivity Display', 'Updating figures...');
    % Get selected rows
    selNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
    % Get OpenGL handle
   % OGL = getappdata(hFig, 'OpenGLDisplay');
    % Clear links
  %  OGL.clearLinks();
 
    % Get Rowlocs
    RowLocs = bst_figures('GetFigureHandleField', hFig, 'RowLocs');
    Options = getappdata(hFig, 'LoadingOptions');
    % Clean and Build Datapair
    DataPair = LoadConnectivityData(hFig, Options);
    % Update structure
    bst_figures('SetFigureHandleField', hFig, 'DataPair', DataPair);
        
    % Update measure distance
    MeasureDistance = [];
    if ~isempty(RowLocs)
        MeasureDistance = ComputeEuclideanMeasureDistance(hFig, DataPair, RowLocs);
    end
    % Update figure variable
    bst_figures('SetFigureHandleField', hFig, 'MeasureDistance', MeasureDistance);
    
    % Get computed vertices
    Vertices = bst_figures('GetFigureHandleField', hFig, 'Vertices');
    % Get computed vertices paths to center
    NodePaths = bst_figures('GetFigureHandleField', hFig, 'NodePaths');
    % Build Datapair path based on region
    MeasureLinks = BuildRegionPath(hFig, NodePaths, DataPair);
    % Compute spline for MeasureLinks based on Vertices position
    aSplines = ComputeSpline(hFig, MeasureLinks, Vertices);
    
    if ~isempty(aSplines)
        % Add on Java side @TODO
       % OGL.addPrecomputedMeasureLinks(aSplines);
        % Set link width
        SetLinkSize(hFig, getappdata(hFig, 'LinkSize'));
        % Set link transparency
        SetLinkTransparency(hFig, getappdata(hFig, 'LinkTransparency'));
    end
    
    %% ===== FILTERS =====
    Refresh = 0;
    
    % Init Filter variables
    bst_figures('SetFigureHandleField', hFig, 'MeasureDistanceMask', zeros(size(DataPair,1),1));
    bst_figures('SetFigureHandleField', hFig, 'MeasureThresholdMask', zeros(size(DataPair,1),1));
    bst_figures('SetFigureHandleField', hFig, 'MeasureAnatomicalMask', zeros(size(DataPair,1),1));
    bst_figures('SetFigureHandleField', hFig, 'MeasureDisplayMask', zeros(size(DataPair,1),1));
    
    % Threshold 
    if isempty(DataPair)
        ThresholdMinMax = [0 0];
    else
        ThresholdAbsoluteValue = getappdata(hFig, 'ThresholdAbsoluteValue');
        if isempty(ThresholdAbsoluteValue) || ~ThresholdAbsoluteValue
            ThresholdMinMax = [min(DataPair(:,3)), max(DataPair(:,3))];
        else
            ThresholdMinMax = [min(abs(DataPair(:,3))), max(abs(DataPair(:,3)))];
        end
    end
    bst_figures('SetFigureHandleField', hFig, 'ThresholdMinMax', ThresholdMinMax);
 
    % Reset filters using the same thresholds
    SetMeasureDisplayFilter(hFig, ones(size(DataPair,1),1), Refresh);
    SetMeasureDistanceFilter(hFig, bst_figures('GetFigureHandleField', hFig, 'MeasureMinDistanceFilter'), ...
        bst_figures('GetFigureHandleField', hFig, 'MeasureMaxDistanceFilter'), ...
        Refresh);
    SetMeasureAnatomicalFilterTo(hFig, bst_figures('GetFigureHandleField', hFig, 'MeasureAnatomicalFilter'), Refresh);
    SetMeasureThreshold(hFig, bst_figures('GetFigureHandleField', hFig, 'MeasureThreshold'), Refresh);
    
    % Update region datapair if possible
    RegionFunction = getappdata(hFig, 'RegionFunction');
    if isempty(RegionFunction)
        RegionFunction = getappdata(hFig, 'DefaultRegionFunction');
    end
    SetRegionFunction(hFig, RegionFunction);
 
    HierarchyNodeIsVisible = getappdata(hFig, 'HierarchyNodeIsVisible');
    SetHierarchyNodeIsVisible(hFig, HierarchyNodeIsVisible);
    
 %   RenderInQuad = getappdata(hFig, 'RenderInQuad');
 %   OGL.renderInQuad(RenderInQuad);
    
    RefreshTitle(hFig);
    
    % Set background color
    SetBackgroundColor(hFig, GetBackgroundColor(hFig));
    % Update colormap
%     UpdateColormap(hFig);
    % Redraw selected nodes
    SetSelectedNodes(hFig, selNodes, 1, 1);
    % Update panel
    panel_display('UpdatePanel', hFig);
    % 
    bst_progress('stop');
end
 
%TODO: update
function SetDisplayNodeFilter(hFig, NodeIndex, IsVisible)
    % Update variable
    if (IsVisible == 0)
        IsVisible = -1;
    end
    DisplayNode = bst_figures('GetFigureHandleField', hFig, 'DisplayNode');
    DisplayNode(NodeIndex) = DisplayNode(NodeIndex) + IsVisible;
    bst_figures('SetFigureHandleField', hFig, 'DisplayNode', DisplayNode);
    % Update java
    if (IsVisible <= 0)       
        Index = find(DisplayNode <= 0);
    else
        Index = find(DisplayNode > 0);
    end
    for i=1:size(Index,1)
      %  OGL.setNodeVisibility(Index(i) - 1, DisplayNode(Index(i)) > 0);
    end
end
 
% TODO: implement region max and mean links and functions
function HideLonelyRegionNode(hFig)
    %
    DisplayInRegion = getappdata(hFig, 'DisplayInRegion');
    if (DisplayInRegion)
        % Get Nodes
        AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
%        MeasureNodes = bst_figures('GetFigureHandleField', hFig, 'MeasureNodes');
        ChannelData = bst_figures('GetFigureHandleField', hFig, 'ChannelData');
        for i=1:size(AgregatingNodes,2)
            % Hide nodes with only one measure node
            Search = find(ChannelData(i,:) ~= 0, 1, 'first');
            if (~isempty(Search))
%             Sum = sum(ismember(ChannelData(MeasureNodes,Search), ChannelData(i,Search)));
%             if ~isempty(Sum)
%                 if (Sum <= 1)
%                     OGL.setNodeVisibility(i - 1, 0);
%                    % DisplayNode(i) = 0;
%                 end
%             end
                % Hide nodes with only one region node
                Member = ismember(ChannelData(AgregatingNodes,Search), ChannelData(i,Search));
                SameHemisphere = ismember(ChannelData(AgregatingNodes,3), ChannelData(i,3));
                Member = Member & SameHemisphere;
                Member(i) = 0;
                % If there's only one sub-region, hide it
                if (sum(Member)== 1)
                    SetDisplayNodeFilter(hFig, find(Member), 0);
                end
            end
        end
    end
end
 
 
%% ===== FILTERS =====
%@NOTE: inprogress
function SetMeasureDisplayFilter(hFig, NewMeasureDisplayMask, Refresh)
    % Refresh by default
    if (nargin < 3)
        Refresh = 1;
    end
    % Get selected rows
    selNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
    if (Refresh)
        % Remove previous links
        SetSelectedNodes(hFig, selNodes, 0, 0);
    end
    % Update variable
    bst_figures('SetFigureHandleField', hFig, 'MeasureDisplayMask', NewMeasureDisplayMask);
    if (Refresh)
        % Redraw selected nodes
        SetSelectedNodes(hFig, selNodes, 1, Refresh);
    end
end
 
function SetMeasureThreshold(hFig, NewMeasureThreshold, Refresh)
    % Refresh by default
    if (nargin < 3)
        Refresh = 1;
    end
    % Get selected rows
    selNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
    % Get Datapair
    DataPair = bst_figures('GetFigureHandleField', hFig, 'DataPair');
    % Get threshold option
    ThresholdAbsoluteValue = getappdata(hFig, 'ThresholdAbsoluteValue');
    if (ThresholdAbsoluteValue)
        DataPair(:,3) = abs(DataPair(:,3));
    end
    % Compute new mask
    MeasureThresholdMask = DataPair(:,3) >= NewMeasureThreshold;
    if (Refresh)
        % Remove previous links
        SetSelectedNodes(hFig, selNodes, 0, 0);
    end
    % Update variable
    bst_figures('SetFigureHandleField', hFig, 'MeasureThreshold', NewMeasureThreshold);
    bst_figures('SetFigureHandleField', hFig, 'MeasureThresholdMask', MeasureThresholdMask);
    if (Refresh)
        % Redraw selected nodes
        SetSelectedNodes(hFig, selNodes, 1, Refresh);
    end
end
 
function SetMeasureAnatomicalFilterTo(hFig, NewMeasureAnatomicalFilter, Refresh)
    % Refresh by default
    if (nargin < 3)
        Refresh = 1;
    end
    DataPair = bst_figures('GetFigureHandleField', hFig, 'DataPair');
    % Get selected rows
    selNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
    % Compute new mask
    NewMeasureAnatomicalMask = GetMeasureAnatomicalMask(hFig, DataPair, NewMeasureAnatomicalFilter);
    if (Refresh)
        % Remove previous links
        SetSelectedNodes(hFig, selNodes, 0, 0);
    end
    % Update variable
    bst_figures('SetFigureHandleField', hFig, 'MeasureAnatomicalFilter', NewMeasureAnatomicalFilter);
    bst_figures('SetFigureHandleField', hFig, 'MeasureAnatomicalMask', NewMeasureAnatomicalMask);
    if (Refresh)
        % Redraw selected nodes
        SetSelectedNodes(hFig, selNodes, 1, Refresh);
    end
end
 
function SetMeasureFiberFilterTo(hFig, NewMeasureFiberFilter, Refresh)
    % Refresh by default
    if (nargin < 3)
        Refresh = 1;
    end
    DataPair = bst_figures('GetFigureHandleField', hFig, 'DataPair');
    % Get selected rows
    selNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
    % Compute new mask
    NewMeasureFiberMask = GetMeasureFiberMask(hFig, DataPair, NewMeasureFiberFilter);
    if (Refresh)
        % Remove previous links
        SetSelectedNodes(hFig, selNodes, 0, 0);
    end
    % Update variable
    bst_figures('SetFigureHandleField', hFig, 'MeasureFiberFilter', NewMeasureFiberFilter);
    bst_figures('SetFigureHandleField', hFig, 'MeasureFiberMask', NewMeasureFiberMask);
    if (Refresh)
        % Redraw selected nodes
        SetSelectedNodes(hFig, selNodes, 1, Refresh);
    end
end
 
function MeasureAnatomicalMask = GetMeasureAnatomicalMask(hFig, DataPair, MeasureAnatomicalFilter)
    ChannelData = bst_figures('GetFigureHandleField', hFig, 'ChannelData');
    MeasureAnatomicalMask = zeros(size(DataPair,1),1);
    switch (MeasureAnatomicalFilter)
        case 0 % 0 - All
            MeasureAnatomicalMask(:) = 1;
        case 1 % 1 - Between Hemisphere
            MeasureAnatomicalMask = ChannelData(DataPair(:,1),3) ~= ChannelData(DataPair(:,2),3);
        case 2 % 2 - Between Lobe == Not Same Region
            MeasureAnatomicalMask = ChannelData(DataPair(:,1),1) ~= ChannelData(DataPair(:,2),1);
    end
end
 
%TODO: remove if not needed
function MeasureFiberMask = GetMeasureFiberMask(hFig, DataPair, MeasureFiberFilter)
    MeasureFiberMask = zeros(size(DataPair,1),1);
    MeasureFiberMask(:) = 1;
    return;
end
 
function SetMeasureDistanceFilter(hFig, NewMeasureMinDistanceFilter, NewMeasureMaxDistanceFilter, Refresh)
    % Refresh by default
    if (nargin < 4)
        Refresh = 1;
    end
    % Get selected rows
    selNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
    % Get distance measures
    MeasureDistance = bst_figures('GetFigureHandleField', hFig, 'MeasureDistance');
    if isempty(MeasureDistance)
        % Everything
        MeasureDistanceMask = ones(size(MeasureDistance));
    else
        % Compute intersection
        MeasureDistanceMask = (MeasureDistance <= NewMeasureMaxDistanceFilter) & (MeasureDistance(:) >= NewMeasureMinDistanceFilter);
    end
    if (Refresh)
        % Remove previous links
        SetSelectedNodes(hFig, selNodes, 0, 0);
    end
    % Update variable
    bst_figures('SetFigureHandleField', hFig, 'MeasureMinDistanceFilter', NewMeasureMinDistanceFilter);
    bst_figures('SetFigureHandleField', hFig, 'MeasureMaxDistanceFilter', NewMeasureMaxDistanceFilter);
    bst_figures('SetFigureHandleField', hFig, 'MeasureDistanceMask', MeasureDistanceMask);
    if (Refresh)
        % Redraw selected nodes
        SetSelectedNodes(hFig, selNodes, 1, Refresh);
    end
end
 
function mMeanDataPair = ComputeMeanMeasureMatrix(hFig, mDataPair)
    Levels = bst_figures('GetFigureHandleField', hFig, 'Levels');
    Regions = Levels{3};
    NumberOfNode = size(Regions,1);
    mMeanDataPair = zeros(NumberOfNode*NumberOfNode,3);
    %
    for i=1:NumberOfNode
        OutNode = getAgregatedNodesFrom(hFig, Regions(i));
        for y=1:NumberOfNode
            if (i ~= y)
                InNode = getAgregatedNodesFrom(hFig, Regions(y));
                Index = ismember(mDataPair(:,1),OutNode) & ismember(mDataPair(:,2),InNode);
                nValue = sum(Index);
                if (nValue > 0)
                    Mean = sum(mDataPair(Index,3)) / sum(Index);
                    mMeanDataPair(NumberOfNode * (i - 1) + y, :) = [Regions(i) Regions(y) Mean];
                end
            end
        end
    end
    mMeanDataPair(mMeanDataPair(:,3) == 0,:) = [];
end
 
function mMaxDataPair = ComputeMaxMeasureMatrix(hFig, mDataPair)
    Levels = bst_figures('GetFigureHandleField', hFig, 'Levels');
    Regions = Levels{3};
    NumberOfRegions = size(Regions,1);
    mMaxDataPair = zeros(NumberOfRegions*NumberOfRegions,3);
    
    % Precomputing this saves on processing time
    NodesFromRegions = cell(NumberOfRegions,1);
    for i=1:NumberOfRegions
        NodesFromRegions{i} = getAgregatedNodesFrom(hFig, Regions(i));
    end
    
    for i=1:NumberOfRegions
        for y=1:NumberOfRegions
            if (i ~= y)
                % Retrieve index
                Index = ismember(mDataPair(:,1),NodesFromRegions{i}) & ismember(mDataPair(:,2),NodesFromRegions{y});
                % If there is values
                if (sum(Index) > 0)
                    Max = max(mDataPair(Index,3));
                    mMaxDataPair(NumberOfRegions * (i - 1) + y, :) = [Regions(i) Regions(y) Max];
                end
            end
        end
    end
    % Eliminate empty data
    mMaxDataPair(mMaxDataPair(:,3) == 0,:) = [];
end
 
 
%@Note: ready, no changes needed
function MeasureDistance = ComputeEuclideanMeasureDistance(hFig, aDataPair, mLoc)
    % Correct offset
    nAgregatingNodes = size(bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes'),2);
    aDataPair(:,1:2) = aDataPair(:,1:2) - nAgregatingNodes;
    % Compute Euclidean distance
    Minus = bsxfun(@minus, mLoc(aDataPair(:,1),:), mLoc(aDataPair(:,2),:));
    MeasureDistance = sqrt(sum(Minus(:,:) .^ 2,2));
    % Convert measure according to factor
    MeasureDistanceFactor = getappdata(hFig, 'MeasureDistanceFactor');
    if isempty(MeasureDistanceFactor)
        MeasureDistanceFactor = 1;
    end
    MeasureDistance = MeasureDistance * MeasureDistanceFactor;
end
 
 
%% ===== GET DATA MASK =====
function [DataPair, DataMask] = GetPairs(hFig)
    % Get figure data
    DataPair = bst_figures('GetFigureHandleField', hFig, 'DataPair');
    % Thresholded list
    if (nargout >= 2)
        MeasureDisplayMask = bst_figures('GetFigureHandleField', hFig, 'MeasureDisplayMask');
        MeasureDistanceMask = bst_figures('GetFigureHandleField', hFig, 'MeasureDistanceMask');
        MeasureAnatomicalMask = bst_figures('GetFigureHandleField', hFig, 'MeasureAnatomicalMask');
        MeasureFiberMask = bst_figures('GetFigureHandleField', hFig, 'MeasureFiberMask');
        MeasureThresholdMask = bst_figures('GetFigureHandleField', hFig, 'MeasureThresholdMask');
        
        DataMask = ones(size(DataPair,1),1);
        % Display specific filter
        if ~isempty(MeasureDisplayMask) && isequal(size(DataMask), size(MeasureDisplayMask))
            DataMask =  DataMask == 1 & MeasureDisplayMask == 1;
        end
        % Distance filter
        if ~isempty(MeasureDistanceMask) && isequal(size(DataMask), size(MeasureDistanceMask))
            DataMask =  DataMask == 1 & MeasureDistanceMask == 1;
        end
        % Anatomical filter
        if ~isempty(MeasureAnatomicalMask) && isequal(size(DataMask), size(MeasureAnatomicalMask))
            DataMask =  DataMask == 1 & MeasureAnatomicalMask == 1;
        end
        % Fiber filter
        if ~isempty(MeasureFiberMask) && isequal(size(DataMask), size(MeasureFiberMask))
            DataMask = DataMask == 1 & MeasureFiberMask == 1;
        end
        % Intensity Threshold filter
        if ~isempty(MeasureThresholdMask) && isequal(size(DataMask), size(MeasureThresholdMask))
            DataMask =  DataMask == 1 & MeasureThresholdMask == 1;
        end
    end
end
 
function [RegionDataPair, RegionDataMask] = GetRegionPairs(hFig)
    % Get figure data
    RegionDataPair = bst_figures('GetFigureHandleField', hFig, 'RegionDataPair');
    RegionDataMask = ones(size(RegionDataPair,1),1);
    if (size(RegionDataPair,1) > 0)
        % Get colormap
        sColormap = bst_colormaps('GetColormap', hFig);
        % Get threshold option
        ThresholdAbsoluteValue = getappdata(hFig, 'ThresholdAbsoluteValue');
        if (ThresholdAbsoluteValue) || sColormap.isAbsoluteValues
            RegionDataPair(:,3) = abs(RegionDataPair(:,3));
        end
        % Get threshold
        MeasureThreshold = bst_figures('GetFigureHandleField', hFig, 'MeasureThreshold');
        if (~isempty(MeasureThreshold))
            % Compute new mask
            MeasureThresholdMask = RegionDataPair(:,3) >= MeasureThreshold;
            RegionDataMask = RegionDataMask & MeasureThresholdMask;
        end
        % Get anatomical filter
        MeasureAnatomicalFilter = bst_figures('GetFigureHandleField', hFig, 'MeasureAnatomicalFilter');
        if (~isempty(MeasureAnatomicalFilter))
            % Compute new mask
            NewMeasureAnatomicalMask = GetMeasureAnatomicalMask(hFig, RegionDataPair, MeasureAnatomicalFilter);
            RegionDataMask = RegionDataMask & NewMeasureAnatomicalMask;
        end
        % Get fiber filter
        MeasureFiberFilter = bst_figures('GetFigureHandleField', hFig, 'MeasureFiberFilter');
        if (~isempty(MeasureFiberFilter))
            % Compute new mask
            NewMeasureFiberFilterMask = GetMeasureFiberMask(hFig, RegionDataPair, MeasureFiberFilter);
            RegionDataMask = RegionDataMask & NewMeasureFiberFilterMask;
        end
    end
end
 
 
%% ===== UPDATE COLORMAP =====
    % This function alters the color display of links and due to updates in
    % colormap
    % NOTE: DONE DEC 2020
function UpdateColormap(hFig)
    disp('Entered UpdateColormap');
    
    MeasureLinksIsVisible = getappdata(hFig, 'MeasureLinksIsVisible');
    RegionLinksIsVisible = getappdata(hFig, 'RegionLinksIsVisible');
    IsBinaryData = getappdata(hFig, 'IsBinaryData');
    DisplayBidirectionalMeasure = getappdata(hFig, 'DisplayBidirectionalMeasure');

    % Get selected frequencies and rows
    TfInfo = getappdata(hFig, 'Timefreq');
    if isempty(TfInfo)
        return
    end
    % Get data description
    iDS = bst_memory('GetDataSetTimefreq', TfInfo.FileName);
    if isempty(iDS)
        return
    end
    % Get colormap
    sColormap = bst_colormaps('GetColormap', hFig);
    % Get DataPair
    [DataPair, DataMask] = GetPairs(hFig);    
    if sColormap.isAbsoluteValues
        DataPair(:,3) = abs(DataPair(:,3));
    end
    % Get figure method
    Method = getappdata(hFig, 'Method');
    % Get maximum values
    DataMinMax = bst_figures('GetFigureHandleField', hFig, 'DataMinMax');
    % Get threshold min/max values
    ThresholdMinMax = bst_figures('GetFigureHandleField', hFig, 'ThresholdMinMax');
    % === COLORMAP LIMITS ===
    % Units type
    if ismember(Method, {'granger', 'spgranger', 'plv', 'plvt', 'aec'})
        UnitsType = 'timefreq';
    else
        UnitsType = 'connect';
    end
    % Get colormap bounds
    if strcmpi(sColormap.MaxMode, 'custom')
        CLim = [sColormap.MinValue, sColormap.MaxValue];
    elseif ismember(Method, {'granger', 'spgranger', 'plv', 'plvt', 'aec', 'cohere', 'pte','henv'})
        CLim = [DataMinMax(1) DataMinMax(2)];
    elseif ismember(Method, {'corr'})
        if strcmpi(sColormap.MaxMode, 'local')
            CLim = DataMinMax;
            if sColormap.isAbsoluteValues
                CLim = [0, abs(CLim(2))];
            end
        else
            if sColormap.isAbsoluteValues
                CLim = [0, 1];
            else
                CLim = [-1, 1];
            end
        end
    end
    setappdata(hFig, 'CLim', CLim);
    
    % === SET COLORMAP ===
    % Update colorbar font size
    hColorbar = findobj(hFig, '-depth', 1, 'Tag', 'Colorbar');
    if ~isempty(hColorbar)
        set(hColorbar, 'FontSize', bst_get('FigFont'), 'FontUnits', 'points');
    end
    % Get figure colormap
    ColormapInfo = getappdata(hFig, 'Colormap');
    sColormap = bst_colormaps('GetColormap', ColormapInfo.Type);
    % Set figure colormap
    set(hFig, 'Colormap', sColormap.CMap);
    % Create/Delete colorbar
    bst_colormaps('SetColorbarVisible', hFig, sColormap.DisplayColorbar);
    % Display only one colorbar (preferentially the results colorbar)
    bst_colormaps('ConfigureColorbar', hFig, ColormapInfo.Type, UnitsType, ColormapInfo.DisplayUnits);
    
    % === UPDATE DISPLAY ===
    CMap = sColormap.CMap;
    
    % Added Dec 23: get the transparency
    LinkTransparency = getappdata(hFig, 'LinkTransparency');
    LinkIntensity = 1.00 - LinkTransparency;  
    IsDirectionalData = getappdata(hFig, 'IsDirectionalData');
    
    
    if (sum(DataMask) > 0)
        % Normalize DataPair for Offset
        Max = max(DataPair(:,3));
        Min = min(abs(DataPair(:,3)));
        Diff = (Max - Min);
        if (Diff == 0)
            Offset = DataPair(DataMask,3);
        else
            Offset = (abs(DataPair(DataMask,3)) - Min) ./ (Max - Min);
        end
        % Interpolate
        [StartColor, EndColor] = InterpolateColorMap(hFig, DataPair(DataMask,:), CMap, CLim);
        
        % added on Dec 20
        color_viz = StartColor(:,:) + Offset(:,:).*(EndColor(:,:) - StartColor(:,:));
        
        iData = find(DataMask == 1);
        MeasureLinks = getappdata(hFig, 'MeasureLinks');
        VisibleLinks = MeasureLinks(iData).';
        
        if (IsDirectionalData)
            MeasureArrows1 = getappdata(hFig, 'MeasureArrows1');
            MeasureArrows2 = getappdata(hFig, 'MeasureArrows2');
            VisibleArrows1 = MeasureArrows1(iData).';
            VisibleArrows2 = MeasureArrows2(iData).';
        end
        
        % set desired colors to each link (4th column is transparency)
        for i=1:size(VisibleLinks,1)
            if (IsDirectionalData)
                set(VisibleLinks(i), 'Color', color_viz(i,:));
                set(VisibleArrows1(i), 'EdgeColor', color_viz(i,:), 'FaceColor', color_viz(i,:));
                set(VisibleArrows2(i), 'EdgeColor', color_viz(i,:), 'FaceColor', color_viz(i,:));
            else 
                set(VisibleLinks(i), 'Color', [color_viz(i,:) LinkIntensity]);
            end 
        end
        % update visibility of arrowheads
        if (MeasureLinksIsVisible)
            if (IsDirectionalData)
                if (~isempty(IsBinaryData) && IsBinaryData == 1 && DisplayBidirectionalMeasure)
                    % Get Bidirectional data
                    Data_matrix = DataPair(DataMask,:);
                    OutIndex = ismember(DataPair(:,1:2),Data_matrix(:,2:-1:1),'rows').';
                    InIndex = ismember(DataPair(:,1:2),Data_matrix(:,2:-1:1),'rows').';
                    
                    % Second arrow is visible for bidirectional links;
                    iData_mask = DataMask.';
                    bidirectional = iData_mask & (OutIndex | InIndex);
                    set(MeasureArrows2(bidirectional), 'Visible', 'on')
                else
                    % make all second arrows invisible if user selected "In" or "Out"
                    set(MeasureArrows2(:), 'Visible', 'off');
                end
            end
        end
    end
    
    [RegionDataPair, RegionDataMask] = GetRegionPairs(hFig);
    if (sum(RegionDataMask) > 0)
        % Normalize DataPair for Offset
        Max = max(RegionDataPair(:,3));
        Min = min(RegionDataPair(:,3));
        Diff = (Max - Min);
        if (Diff == 0)
            Offset = RegionDataPair(RegionDataMask,3);
        else
            Offset = (abs(RegionDataPair(RegionDataMask,3)) - Min) ./ (Max - Min);
        end
        % Normalize within the colormap range 
        [StartColor, EndColor] = InterpolateColorMap(hFig, RegionDataPair(RegionDataMask,:), CMap, CLim);
        
        % added on Dec 20
        color_viz_region = StartColor(:,:) + Offset(:,:).*(EndColor(:,:) - StartColor(:,:));
        
        iData = find(RegionDataMask == 1);
        RegionLinks = getappdata(hFig,'RegionLinks');
        VisibleLinks_region = RegionLinks(iData).';
        
        if (IsDirectionalData)
            RegionArrows1 = getappdata(hFig, 'RegionArrows1');
            RegionArrows2 = getappdata(hFig, 'RegionArrows2');
            VisibleArrows1 = RegionArrows1(iData).';
            VisibleArrows2 = RegionArrows2(iData).';
        end
        
        % set desired colors to each link (4th column is transparency)
        for i=1:size(VisibleLinks_region,1)
            if (IsDirectionalData)
                set(VisibleLinks_region(i), 'Color', color_viz_region(i,:));
                set(VisibleArrows1(i), 'EdgeColor', color_viz_region(i,:), 'FaceColor', color_viz_region(i,:));
                set(VisibleArrows2(i), 'EdgeColor', color_viz_region(i,:), 'FaceColor', color_viz_region(i,:));
            else 
                set(VisibleLinks_region(i), 'Color', [color_viz_region(i,:) LinkIntensity]);
            end
        end  
        
        % update arrowheads
        if (RegionLinksIsVisible)
            if (IsDirectionalData)
                if (~isempty(IsBinaryData) && IsBinaryData == 1 && DisplayBidirectionalMeasure)
                    % Get Bidirectional data
                    Data_matrix = RegionDataPair(RegionDataMask,:);
                    OutIndex = ismember(RegionDataPair(:,1:2),Data_matrix(:,2:-1:1),'rows').';
                    InIndex = ismember(RegionDataPair(:,1:2),Data_matrix(:,2:-1:1),'rows').';
                    
                    % Second arrow is visible for bidirectional links;
                    iData_mask = RegionDataMask.';
                    bidirectional = iData_mask & (OutIndex | InIndex);
                    set(RegionArrows2(bidirectional), 'Visible', 'on')
                else
                    % make all second arrows invisible if user selected "In" or "Out"
                    set(RegionArrows2(:), 'Visible', 'off');
                end
            end
        end
    end

end
 
% Update Jan 09: Mapped links to colormap for ALL graphs (including
% directional ones)
function [StartColor EndColor] = InterpolateColorMap(hFig, DataPair, ColorMap, Limit)
    % Normalize and interpolate
    a = (DataPair(:,3)' - Limit(1)) / (Limit(2) - Limit(1));
    b = linspace(0,1,size(ColorMap,1));
    m = size(a,2);
    n = size(b,2);
    [tmp,p] = sort([a,b]);
    q = 1:m+n; q(p) = q;
    t = cumsum(p>m);
    r = 1:n; r(t(q(m+1:m+n))) = r;
    s = t(q(1:m));
    id = r(max(s,1));
    iu = r(min(s+1,n));
    [tmp,it] = min([abs(a-b(id));abs(b(iu)-a)]);
    StartColor = ColorMap(id+(it-1).*(iu-id),:);
    EndColor = ColorMap(id+(it-1).*(iu-id),:);
end

%% ======== RESET CAMERA DISPLAY ================
    % NOTE: DONE Oct 20 2020
    % Resets camera position, target and view angle of the figure
function DefaultCamera(hFig)
    disp('set DefaultCamera reached') %TODO: remove test
   % setappdata(hFig, 'CameraZoom', 6);  %TODO: remove
   %zoom angle default is 6deg
   % setappdata(hFig, 'CamPitch', 0.5 * 3.1415);
  %  setappdata(hFig, 'CamYaw', -0.5 * 3.1415);
  %  setappdata(hFig, 'CameraPosition', [0 0 36]);  %TODO: remove
   % setappdata(hFig, 'CameraTarget', [0 0 -0.5]);  %TODO: remove
    hFig.CurrentAxes.CameraViewAngle = 7;
    hFig.CurrentAxes.CameraPosition = [0 0 60];
    hFig.CurrentAxes.CameraTarget = [0 0 -2];
   
end
 
%% ======= ZOOM CAMERA =================
    % Note: Done Oct 20, 2020
    % Zoom in/out by changing CameraViewAngle of default z-axis
    % The greater the angle (0 to 180), the larger the field of view
    % ref: https://www.mathworks.com/help/matlab/ref/matlab.graphics.axis.axes-properties.html#budumk7-CameraViewAngle
function ZoomCamera(hFig, factor)
    angle = hFig.CurrentAxes.CameraViewAngle * factor;
    min = 3; max = 20;
    if (angle > max)
        angle = max;
    elseif (angle < min)
        angle = min;
    end
    hFig.CurrentAxes.CameraViewAngle = angle;
end
 
%% ====== MOVE CAMERA HORIZONTALLY/ VERTIVALLY ===============
    % NOTE: Oct 20, 2020. May need accuracy improvement.
    % Move camera horizontally/vertically (from SHIFT+MOUSEMOVE) 
    % by applying X and Y translation to the CameraPosition and CameraTarget
    % ref: https://www.mathworks.com/help/matlab/ref/matlab.graphics.axis.axes-properties.html#budumk7-CameraTarget
function MoveCamera(hFig, Translation)
    disp('MoveCamera reached') %TODO: remove test
  %  CameraPosition = getappdata(hFig, 'CameraPosition') + Translation;
   % CameraTarget = getappdata(hFig, 'CameraTarget') + Translation;
  %  setappdata(hFig, 'CameraPosition', CameraPosition);
  %  setappdata(hFig, 'CameraTarget', CameraTarget);
    
    %new 
    position = hFig.CurrentAxes.CameraPosition + Translation; %[0.01 0.01 0]; 
    target = hFig.CurrentAxes.CameraTarget + Translation; %[0.01 0.01 0];
    hFig.CurrentAxes.CameraPosition = position;
    hFig.CurrentAxes.CameraTarget = target;
end
 
%% ===========================================================================
%  ===== NODE DISPLAY AND SELECTION ==========================================
%  ===========================================================================
 
%% ===== SET SELECTED NODES =====
% TODO: implement/check isRedraw, otherwise DONE
% USAGE:  SetSelectedNodes(hFig, iNodes=[], isSelected=1, isRedraw=1) : Add or remove nodes from the current selection
%         If node selection is empty: select/unselect all the nodes
function SetSelectedNodes(hFig, iNodes, isSelected, isRedraw)
    disp('Entered SetSelectedNodes');
    
    % ==================== SETUP =========================
    % Parse inputs
    if (nargin < 2) || isempty(iNodes)
        % Get all the nodes
        NumberOfNodes = bst_figures('GetFigureHandleField', hFig, 'NumberOfNodes');
        iNodes = 1:NumberOfNodes;
    end
    if (nargin < 3) || isempty(isSelected)
        isSelected = 1;
    end
    if (nargin < 4) || isempty(isRedraw)
        isRedraw = 1;
    end
    % Get list of selected channels
    selNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
    % If nodes are not specified
    if (nargin < 3)
        iNodes = selNodes;
        isSelected = 1;
    end
    
    % Define node properties
    if isSelected
       % marker type now (x or O)
        selNodes = union(selNodes, iNodes);
    else
        selNodes = setdiff(selNodes, iNodes);
    end
    
    % Update list of selected channels
    bst_figures('SetFigureHandleField', hFig, 'SelectedNodes', selNodes);
    
    % =================== DISPLAY SELECTED NODES =========================
    AllNodes = getappdata(hFig,'AllNodes');
    
    % old code - Agregating nodes are not visually selected
   % AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
    %NoColorNodes = ismember(iNodes,AgregatingNodes);
    %if (sum(~NoColorNodes) > 0)
        %sets current visibility type and updates display marker
       % allIdx = iNodes(~NoColorNodes);  
       % for i = 1:length(allIdx)
 
         %  testNodes(allIdx(i)).Visible = true;
          % testNodes(allIdx(i)).isAgregatingNode = true;
       % end
  %  else
      %  for i = 1:length(allIdx)
          % testNodes(allIdx(i)).Visible = false;
      %  end
  %  end
  
    % REQUIRED: Display selected nodes ('ON' or 'OFF')
    for i = 1:length(iNodes)
        if isSelected
            SelectNode(hFig, AllNodes(iNodes(i)), true);
        else
            SelectNode(hFig, AllNodes(iNodes(i)), false);
        end
    end
         
    RefreshTextDisplay(hFig, isRedraw);
    
    % Get data
    MeasureLinksIsVisible = getappdata(hFig, 'MeasureLinksIsVisible');
    RegionLinksIsVisible = getappdata(hFig, 'RegionLinksIsVisible');
    
    if (MeasureLinksIsVisible)
        [DataToFilter, DataMask] = GetPairs(hFig);
    else
        [DataToFilter, DataMask] = GetRegionPairs(hFig);
    end
    
    % ===== Selection based data filtering of links =====
    % Direction mask
    IsDirectionalData = getappdata(hFig, 'IsDirectionalData');
    if (~isempty(IsDirectionalData) && IsDirectionalData == 1)
        NodeDirectionMask = zeros(size(DataMask,1),1);
        DisplayOutwardMeasure = getappdata(hFig, 'DisplayOutwardMeasure');
        DisplayInwardMeasure = getappdata(hFig, 'DisplayInwardMeasure');
        DisplayBidirectionalMeasure = getappdata(hFig, 'DisplayBidirectionalMeasure');
        
        if (DisplayOutwardMeasure)
            OutMask = ismember(DataToFilter(:,1), iNodes);
            NodeDirectionMask = NodeDirectionMask | OutMask;
        end
        if (DisplayInwardMeasure)
            InMask = ismember(DataToFilter(:,2), iNodes);
            NodeDirectionMask = NodeDirectionMask | InMask;
        end
        if (DisplayBidirectionalMeasure)
            % Selection
            SelectedNodeMask = ismember(DataToFilter(:,1), iNodes) ...
                             | ismember(DataToFilter(:,2), iNodes);
            VisibleIndex = find(DataMask == 1);
            % Get Bidirectional data
            BiIndex = ismember(DataToFilter(DataMask,1:2),DataToFilter(DataMask,2:-1:1),'rows');
            NodeDirectionMask(VisibleIndex(BiIndex)) = 1;
            NodeDirectionMask = NodeDirectionMask & SelectedNodeMask;
        end
        UserSpecifiedBinaryData = getappdata(hFig, 'UserSpecifiedBinaryData');
        if (isempty(UserSpecifiedBinaryData) || UserSpecifiedBinaryData == 0)
            % Update binary status
            RefreshBinaryStatus(hFig);                
        end
        DataMask = DataMask == 1 & NodeDirectionMask == 1;
    else
        % Selection filtering
        SelectedNodeMask = ismember(DataToFilter(:,1), iNodes) ...
                         | ismember(DataToFilter(:,2), iNodes);
        DataMask = DataMask & SelectedNodeMask;
    end
    
    %disp(NodeDirectionMask);
    
    % ==================== DISPLAY LINKS SELECTION ====================
    % Links are from valid node only
    ValidNode = find(bst_figures('GetFigureHandleField', hFig, 'ValidNode') > 0);
    ValidDataForDisplay = sum(ismember(DataToFilter(:,1:2), ValidNode),2);
    DataMask = DataMask == 1 & ValidDataForDisplay == 2;
 
    iData = find(DataMask == 1); % - 1;
 
    if (~isempty(iData))
        % Update link visibility
        if (MeasureLinksIsVisible)
            MeasureLinks = getappdata(hFig,'MeasureLinks');
            
            if (isSelected)
                
                %TODO: increase linewidth when selected
                set(MeasureLinks(iData), 'Visible', 'on');
                if (IsDirectionalData)
                    MeasureArrows1 = getappdata(hFig, 'MeasureArrows1');
                    set(MeasureArrows1(iData), 'Visible', 'on');
                end
            else
                set(MeasureLinks(iData), 'Visible', 'off');
                if (IsDirectionalData)
                    MeasureArrows1 = getappdata(hFig, 'MeasureArrows1');
                    MeasureArrows2 = getappdata(hFig, 'MeasureArrows2');
                    set(MeasureArrows1(iData), 'Visible', 'off');
                    set(MeasureArrows2(iData), 'Visible', 'off');
                end
            end
            
        else % display region links
            RegionLinks = getappdata(hFig,'RegionLinks');
            
            if (isSelected)
                set(RegionLinks(iData), 'Visible', 'on');
                if (IsDirectionalData)
                    RegionArrows1 = getappdata(hFig, 'RegionArrows1');
                    set(RegionArrows1(iData), 'Visible', 'on');
                end
            else
                set(RegionLinks(iData), 'Visible', 'off');
                if (IsDirectionalData)
                    RegionArrows1 = getappdata(hFig, 'RegionArrows1');
                    RegionArrows2 = getappdata(hFig, 'RegionArrows2');
                    set(RegionArrows1(iData), 'Visible', 'off');
                    set(RegionArrows2(iData), 'Visible', 'off');
                end
            end
        end
    end

    % Redraw OpenGL
    if isRedraw
      %  OGL.repaint();
    end
    
    % Propagate selection to other figures
    NodeNames = bst_figures('GetFigureHandleField', hFig, 'Names');
    if ~isempty(selNodes) && (length(selNodes) < length(NodeNames))
        % Select rows
        bst_figures('SetSelectedRows', NodeNames(selNodes));
        % Select scouts
        panel_scout('SetSelectedScoutLabels', NodeNames(selNodes));
    else
        bst_figures('SetSelectedRows', []);
        panel_scout('SetSelectedScoutLabels', []);
    end
end
 
 
%% SHOW/HIDE REGION NODES FROM DISPLAY
%TODO - allow hiding region nodes (lobes + hem nodes) from display
%TODO - hidden nodes should not be clickable
%TODO - hidden nodes should not have options to show/hide text labels
function SetHierarchyNodeIsVisible(hFig, isVisible)
    HierarchyNodeIsVisible = getappdata(hFig, 'HierarchyNodeIsVisible');
    if (HierarchyNodeIsVisible ~= isVisible)
        AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
        if (isVisible)
            %ValidNode = find(bst_figures('GetFigureHandleField', hFig, 'ValidNode'));
            %AgregatingNodes(ismember(AgregatingNodes,ValidNode)) = [];
        end
        SetDisplayNodeFilter(hFig, AgregatingNodes, isVisible);
        % Update variable
        setappdata(hFig, 'HierarchyNodeIsVisible', isVisible);
    end
    % Make sure they are invisible
    HideLonelyRegionNode(hFig);
end
 
 
%% Create Region Mean/Max Links
function RegionDataPair = SetRegionFunction(hFig, RegionFunction)
    disp('Entered SetRegionFunction');

    % Does data have regions to cluster ?
    DisplayInCircle = getappdata(hFig, 'DisplayInCircle');
    if (isempty(DisplayInCircle) || DisplayInCircle == 0)    
        % Get data
        DataPair = GetPairs(hFig);
        % Which function
        switch (RegionFunction)
            case 'mean'
                RegionDataPair = ComputeMeanMeasureMatrix(hFig, DataPair);
            case 'max'
                RegionDataPair = ComputeMaxMeasureMatrix(hFig, DataPair);
            otherwise
                disp('The region function specified is not yet supported. Default to mean.');
                RegionFunction = 'mean';
                RegionDataPair = ComputeMeanMeasureMatrix(hFig, M);
        end
       
        %New Feb 9: create region mean/max links from computed RegionDataPair
        BuildLinks(hFig, RegionDataPair, false); %Note: make sure to use isMeasureLink = false for this step
        
        % update size and transparency
        LinkSize = getappdata(hFig, 'LinkSize');
        SetLinkSize(hFig, LinkSize);
        if (isappdata(hFig,'LinkTransparency'))
            transparency = getappdata(hFig,'LinkTransparency');
        else
            transparency = 0;
        end
        SetLinkTransparency(hFig, transparency);

        % Update figure value
        bst_figures('SetFigureHandleField', hFig, 'RegionDataPair', RegionDataPair);
        setappdata(hFig, 'RegionFunction', RegionFunction);
        
        % Added Jan. 31: update visibility of region links
        % Get selected node
        selNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
        % Erase selected node
        SetSelectedNodes(hFig, selNodes, 0, 1);
        % Redraw selected nodes
        SetSelectedNodes(hFig, selNodes, 1, 1);
        
        % Update color map
        UpdateColormap(hFig);
    end
end
 
% Note: RegionLinksIsVisible == 1 when the user selects it in the popup
% menu
function ToggleMeasureToRegionDisplay(hFig)
    DisplayInRegion = getappdata(hFig, 'DisplayInRegion');
    if (DisplayInRegion)
        % Toggle visibility
        MeasureLinksIsVisible = getappdata(hFig, 'MeasureLinksIsVisible');
        if (MeasureLinksIsVisible)
            MeasureLinksIsVisible = 0;
            RegionLinksIsVisible = 1;
        else
            MeasureLinksIsVisible = 1;
            RegionLinksIsVisible = 0;
        end
        % Get selected node
        selNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
        % Erase selected node
        SetSelectedNodes(hFig, selNodes, 0, 1);
        % Update visibility variable
        setappdata(hFig, 'MeasureLinksIsVisible', MeasureLinksIsVisible);
        setappdata(hFig, 'RegionLinksIsVisible', RegionLinksIsVisible);
        % Redraw selected nodes
        SetSelectedNodes(hFig, selNodes, 1, 1);
    else
        disp('Current data does not support region display.');
    end
end
 
 
%% ===== DISPLAY MODE =====
    % NOTE: done Oct 2020
function SetTextDisplayMode(hFig, DisplayMode)
    % Get current display
    TextDisplayMode = getappdata(hFig, 'TextDisplayMode');
    % If not already set
    Index = ismember(TextDisplayMode, DisplayMode);
    if (sum(Index) == 0)
        % 'Selection' mode and the others are mutually exclusive
        if (DisplayMode == 3)
            TextDisplayMode = DisplayMode;
        else
            TextDisplayMode = [TextDisplayMode DisplayMode];
            % Remove 'Selection' mode if necessary
            SelectionModeIndex = ismember(TextDisplayMode,3);
            if (sum(SelectionModeIndex) >= 1)
                TextDisplayMode(SelectionModeIndex) = [];
            end
        end
    else
        TextDisplayMode(Index) = [];
    end
    % Add display mode
    setappdata(hFig, 'TextDisplayMode', TextDisplayMode);
    % Refresh
    RefreshTextDisplay(hFig);
end
 
%% == Toggle label displays for lobes === 
    % toggle order:
    % show measure node labels and FULL agg node labels
    % show measure node labels and ABBRV agg node labels
    % show measure node labels only
function ToggleTextDisplayMode(hFig)
    % Get display mode
    TextDisplayMode = getappdata(hFig, 'TextDisplayMode');
    LobeFullLabel = getappdata(hFig, 'LobeFullLabel');
    
    if (isequal(TextDisplayMode,[1 2]) && LobeFullLabel)
        ToggleLobeLabels(hFig);
    elseif (isequal(TextDisplayMode,[1 2]))
        TextDisplayMode = 1;
        ToggleLobeLabels(hFig);
    else
        TextDisplayMode = [1 2];
    end
    % Add display mode
    setappdata(hFig, 'TextDisplayMode', TextDisplayMode);
    % Refresh
    RefreshTextDisplay(hFig);
end

function ToggleLobeLabels(hFig) 
    AllNodes = getappdata(hFig, 'AllNodes');
    if (getappdata(hFig, 'LobeFullLabel'))
        % toggle to abbr form and hor angle
        for i = 1:length(AllNodes)
            if (AllNodes(i).isAgregatingNode)
                AllNodes(i).TextLabel.String = AllNodes(i).Label;
                AllNodes(i).TextLabel.Rotation = 0;
            end
        end
         
        %update appdata
        setappdata(hFig, 'LobeFullLabel', 0);
    else
        % toggle to full form and radial angle
        for i = 1:length(AllNodes)
            if (AllNodes(i).isAgregatingNode)
                AllNodes(i).TextLabel.String = LobeTagToFullTag(AllNodes(i).Label);
                t = atan2(AllNodes(i).Position(2),AllNodes(i).Position(1));
                if abs(t) > pi/2
                    AllNodes(i).TextLabel.Rotation = 180*(t/pi + 1);
                else
                    AllNodes(i).TextLabel.Rotation = t*180/pi;
                end
            end
        end
        %update appdata
        setappdata(hFig, 'LobeFullLabel', 1);
    end
end
%% ===== NODE & LABEL SIZE IN SIGNLE FUNCTION =====
function SetNodeLabelSize(hFig, NodeSize, LabelSize)
     if isempty(NodeSize)
        NodeSize = 5; % default for 'on' is 5, default for off is '6'
    end
    if isempty(LabelSize)
        LabelSize = 7; % set to default -3
    end

    AllNodes = getappdata(hFig,'AllNodes');
    
    for i = 1:size(AllNodes,2)
        node = AllNodes(i);
        set(node.NodeMarker, 'MarkerSize', NodeSize);
        set(node.TextLabel, 'FontSize', LabelSize);
    end     
    
    setappdata(hFig, 'NodeSize', NodeSize);
    setappdata(hFig, 'LabelSize', LabelSize);
end

%% ===== NODE SIZE =====
     % NOTE: JAN 2020
function NodeSize = GetNodeSize(hFig)
    NodeSize = getappdata(hFig, 'NodeSize');
    if isempty(NodeSize)
        NodeSize = 5; % default for 'on' is 5, default for off is '6'
    end
end
 
function SetNodeSize(hFig, NodeSize)
    disp('Entered SetNodeSize');
    if isempty(NodeSize)
        NodeSize = 5; % default for 'on' is 5, default for off is '6'
    end

    AllNodes = getappdata(hFig,'AllNodes');
    
    for i = 1:size(AllNodes,2)
        node = AllNodes(i);
        set(node.NodeMarker, 'MarkerSize', NodeSize);
    end    
    setappdata(hFig, 'NodeSize', NodeSize);
end

%% ===== LABEL SIZE =====
     % NOTE: JAN 2020
function LabelSize = GetLabelSize(hFig)
    LabelSize = getappdata(hFig, 'LabelSize');
    if isempty(LabelSize)
        LabelSize = 7; % set to default -3
    end
end
 
function SetLabelSize(hFig, LabelSize)
    disp('Entered SetLabelSize');
    if isempty(LabelSize)
        LabelSize = 7; % set to default -3
    end
    
    AllNodes = getappdata(hFig,'AllNodes');
    
    for i = 1:size(AllNodes,2)
        node = AllNodes(i);
        set(node.TextLabel, 'FontSize', LabelSize);
    end    
    setappdata(hFig, 'LabelSize', LabelSize);
end
    
%% ===== LINK SIZE =====
     % NOTE: DONE DEC 2020
function LinkSize = GetLinkSize(hFig)
    LinkSize = getappdata(hFig, 'LinkSize');
    if isempty(LinkSize)
        LinkSize = 1.5; % default
    end
end
 
function SetLinkSize(hFig, LinkSize)
    disp('Entered SetLinkSize');
    if isempty(LinkSize)
        LinkSize = 1.5; % default
    end

    MeasureLinks = getappdata(hFig,'MeasureLinks');
    MeasureArrows1 = getappdata(hFig,'MeasureArrows1');
    MeasureArrows2 = getappdata(hFig,'MeasureArrows2');
    
    RegionLinks = getappdata(hFig,'RegionLinks');
    RegionArrows1 = getappdata(hFig,'RegionArrows1');
    RegionArrows2 = getappdata(hFig,'RegionArrows2');
    
    MeasureLinksIsVisible = getappdata(hFig, 'MeasureLinksIsVisible');
    RegionLinksIsVisible = getappdata(hFig, 'RegionLinksIsVisible');
    
    if (MeasureLinksIsVisible)
        set(MeasureLinks, 'LineWidth', LinkSize);
        set(MeasureArrows1, 'LineWidth', LinkSize);
        set(MeasureArrows2, 'LineWidth', LinkSize);
    else
        set(RegionLinks, 'LineWidth', LinkSize);
        set(RegionArrows1, 'LineWidth', LinkSize);
        set(RegionArrows2, 'LineWidth', LinkSize);
    end
    
    setappdata(hFig, 'LinkSize', LinkSize);
end
 
%% ===== LINK TRANSPARENCY =====
    % NOTE: DONE DEC 2020
function SetLinkTransparency(hFig, LinkTransparency)
    disp('Entered SetLinkTransparency');
    
    MeasureLinksIsVisible = getappdata(hFig, 'MeasureLinksIsVisible');
    RegionLinksIsVisible = getappdata(hFig, 'RegionLinksIsVisible');
    IsDirectionalData = getappdata(hFig, 'IsDirectionalData');
    
    if (MeasureLinksIsVisible)
        MeasureLinks = getappdata(hFig,'MeasureLinks');
        [DataPair, DataMask] = GetPairs(hFig); 
        iData = find(DataMask == 1); % - 1;
 
        if (~isempty(iData))
            VisibleLinks = MeasureLinks(iData).';
            
            if (IsDirectionalData)
                MeasureArrows1 = getappdata(hFig,'MeasureArrows1');
                MeasureArrows2 = getappdata(hFig,'MeasureArrows2');
                VisibleArrows1 = MeasureArrows1(iData).';
                VisibleArrows2 = MeasureArrows2(iData).';
            end
    
            % set desired colors to each link
            for i=1:length(VisibleLinks)
                current_color = VisibleLinks(i).Color;
                current_color(4) = 1.00 - LinkTransparency;
                set(VisibleLinks(i), 'Color', current_color);
                
                if (IsDirectionalData)
                    set(VisibleArrows1(i), 'EdgeAlpha', current_color(4), 'FaceAlpha', current_color(4));
                    set(VisibleArrows2(i), 'EdgeAlpha', current_color(4), 'FaceAlpha', current_color(4));
                end
            end
        end
    % region links
    else
        RegionLinks = getappdata(hFig,'RegionLinks'); 
        [DataToFilter, DataMask] = GetRegionPairs(hFig);
        iData = find(DataMask == 1); % - 1;
 
        if (~isempty(iData))
            VisibleLinks_region = RegionLinks(iData).';
            
            if (IsDirectionalData)
                RegionArrows1 = getappdata(hFig,'RegionArrows1');
                RegionArrows2 = getappdata(hFig,'RegionArrows2');
                VisibleArrows1 = RegionArrows1(iData).';
                VisibleArrows2 = RegionArrows2(iData).';
            end
        
            for i=1:length(VisibleLinks_region)
                current_color = VisibleLinks_region(i).Color;
                current_color(4) = 1.00 - LinkTransparency;              
                set(VisibleLinks_region(i), 'Color', current_color);
                
                if (IsDirectionalData)
                    set(VisibleArrows1(i), 'EdgeAlpha', current_color(4), 'FaceAlpha', current_color(4));
                    set(VisibleArrows2(i), 'EdgeAlpha', current_color(4), 'FaceAlpha', current_color(4));
                end
            end
        end
    end
    setappdata(hFig, 'LinkTransparency', LinkTransparency);
end
 
%% ===== BACKGROUND COLOR =====
% @TODO: Agregating node text (region node - lobe label)
function SetBackgroundColor(hFig, BackgroundColor, TextColor)
    % Negate text color if necessary
    if nargin < 3
        TextColor = ~BackgroundColor;
    end
 
    % Update Matlab background color
    set(hFig, 'Color', BackgroundColor)
    
    % === UPDATE TEXT COLOR ===
    FigureHasText = getappdata(hFig, 'FigureHasText');
    if FigureHasText
        if isappdata(hFig, 'AllNodes')
            AllNodes = getappdata(hFig, 'AllNodes');
            for i = 1:length(AllNodes)
                % only update text color for selected nodes (keep rest as
                % grey)
                if (AllNodes(i).TextLabel.Color ~= [0.5 0.5 0.5])
                    set(AllNodes(i).TextLabel,'Color', TextColor);
                end
            end
        end
    end
    
    setappdata(hFig, 'BgColor', BackgroundColor); %set app data for toggle
    UpdateContainer(hFig);
end
 
% NOTE: DONE OCT 2020
function ToggleBackground(hFig)
    BackgroundColor = getappdata(hFig, 'BgColor');
    if all(BackgroundColor == [1 1 1])
        BackgroundColor = [0 0 0];
    else
        BackgroundColor = [1 1 1];
    end
    TextColor = ~BackgroundColor;
    SetBackgroundColor(hFig, BackgroundColor, TextColor)
end
 
%% Binary Data
function SetIsBinaryData(hFig, IsBinaryData)
    % Update variable
    setappdata(hFig, 'IsBinaryData', IsBinaryData);
    setappdata(hFig, 'UserSpecifiedBinaryData', 1);
    % Update colormap
    UpdateColormap(hFig);
end
 
function setDisplayMeasureMode(hFig, DisplayOutwardMeasure, DisplayInwardMeasure, DisplayBidirectionalMeasure, Refresh)
    if (nargin < 5)
        Refresh = 1;
    end
    % Get selected rows
    selNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
    if (Refresh)
        % Remove previous links
        SetSelectedNodes(hFig, selNodes, 0, 0);
    end
    % Update display mode
    setappdata(hFig, 'DisplayOutwardMeasure', DisplayOutwardMeasure);
    setappdata(hFig, 'DisplayInwardMeasure', DisplayInwardMeasure);
    setappdata(hFig, 'DisplayBidirectionalMeasure', DisplayBidirectionalMeasure);
    % ----- User convenience code -----
    RefreshBinaryStatus(hFig);
    if (Refresh)
        % Redraw selected nodes
        SetSelectedNodes(hFig, selNodes, 1, 1);
    end
end
 
function RefreshBinaryStatus(hFig)
    IsBinaryData = getappdata(hFig, 'IsBinaryData');
    DisplayOutwardMeasure = getappdata(hFig, 'DisplayOutwardMeasure');
    DisplayInwardMeasure = getappdata(hFig, 'DisplayInwardMeasure');
    DisplayBidirectionalMeasure = getappdata(hFig, 'DisplayBidirectionalMeasure');
    if (DisplayInwardMeasure && DisplayOutwardMeasure)
        IsBinaryData = 1;
    elseif (DisplayInwardMeasure || DisplayOutwardMeasure)
        IsBinaryData = 0;
        selNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
        Nodes = bst_figures('GetFigureHandleField', hFig, 'MeasureNodes');
        nSelectedMeasureNodes = sum(ismember(Nodes, selNodes));
        if (length(Nodes) == nSelectedMeasureNodes);
            IsBinaryData = 1;
        end
    elseif (DisplayBidirectionalMeasure)
        IsBinaryData = 1;
    end
    curBinaryData = getappdata(hFig, 'IsBinaryData');
    if (IsBinaryData ~= curBinaryData)
        setappdata(hFig, 'IsBinaryData', IsBinaryData);
        % Update colormap
        UpdateColormap(hFig);
    end
    setappdata(hFig, 'UserSpecifiedBinaryData', 0);
end
 
%% ===== REFRESH TEXT VISIBILITY =====
%TODO: Check text display modes 1,2,3
%todo: isRedraw
function RefreshTextDisplay(hFig, isRedraw)
    FigureHasText = getappdata(hFig, 'FigureHasText');
    if FigureHasText

        if nargin < 2
            isRedraw = 1;
        end

        AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
        MeasureNodes = bst_figures('GetFigureHandleField', hFig, 'MeasureNodes');
        ValidNode = bst_figures('GetFigureHandleField', hFig, 'ValidNode');

        nVertices = size(AgregatingNodes,2) + size(MeasureNodes,2);
        VisibleText = zeros(nVertices,1);

        TextDisplayMode = getappdata(hFig, 'TextDisplayMode');
        if ismember(1,TextDisplayMode)
            VisibleText(MeasureNodes) = ValidNode(MeasureNodes);
        end
        if ismember(2,TextDisplayMode)
            VisibleText(AgregatingNodes) = ValidNode(AgregatingNodes);
        end
        if ismember(3,TextDisplayMode)
            selNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
            VisibleText(selNodes) = ValidNode(selNodes);
        end
        
        % Update text visibility
        AllNodes = getappdata(hFig,'AllNodes');
        for i=1:length(VisibleText)
            if (VisibleText(i) == 1)
                AllNodes(i).TextLabel.Visible = 'on';
            else
               AllNodes(i).TextLabel.Visible = 'off';
            end
        end
 
    end
end
 
 
%% ===== SET DATA THRESHOLD =====
function SetDataThreshold(hFig, DataThreshold) %#ok<DEFNU>
    % Get selected rows
    selNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
    % Remove previous links
    SetSelectedNodes(hFig, selNodes, 0, 0);
    % Update threshold
    setappdata(hFig, 'DataThreshold', DataThreshold);
    % Redraw selected nodes
    SetSelectedNodes(hFig, selNodes, 1, 1);
end
 
 
%% ===== UTILITY FUNCTIONS =====
function NodeIndex = getAgregatedNodesFrom(hFig, AgregatingNodeIndex)
    NodeIndex = [];
    AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
    if ismember(AgregatingNodeIndex,AgregatingNodes)
        NodePaths = bst_figures('GetFigureHandleField', hFig, 'NodePaths');
        member = cellfun(@(x) ismember(AgregatingNodeIndex,x), NodePaths);
        NodeIndex = find(member == 1);
    end
end
 
 
%% ===== COMPUTING LINK PATH =====
% @note: ready, no changes needed
function MeasureLinks = BuildRegionPath(hFig, mPaths, mDataPair)
    % Init return variable
    MeasureLinks = [];
    if isempty(mDataPair)
        return;
    end
    % 
    nPairs = size(mDataPair,1);
    if (nPairs > 0)
        % Define path to center as defined by the hierarchy
        ToCenter = mPaths(mDataPair(:,1));
        ToDestination = cellfun(@(x) x(end-1:-1:1), mPaths(mDataPair(:,2)), 'UniformOutput', 0);
        % Concat 
        MeasureLinks = cellfun(@(x,y) cat(2, x, y), ToCenter, ToDestination, 'UniformOutput', 0);
        % Level specific display
        NumberOfLevels = bst_figures('GetFigureHandleField', hFig, 'NumberOfLevels');
        if (NumberOfLevels > 2)
            % Retrieve channel hierarchy
            ChannelData = bst_figures('GetFigureHandleField', hFig, 'ChannelData');
            % 
            if (~isempty(ChannelData))
                SameRegion = ChannelData(mDataPair(1:end,1),1) == ChannelData(mDataPair(1:end,2),1);
                MeasureLinks(SameRegion) = cellfun(@(x,y) cat(2, x(1:2), y(end)), ToCenter(SameRegion), ToDestination(SameRegion), 'UniformOutput', 0);
                % 
                if (NumberOfLevels > 3)
                    % 
                    SameHemisphere = ChannelData(mDataPair(1:end,1),3) == ChannelData(mDataPair(1:end,2),3);
                    SameLobe = ChannelData(mDataPair(1:end,1),2) == ChannelData(mDataPair(1:end,2),2);
                    % Remove hierarchy based duplicate
                    SameLobe = SameLobe == 1 & SameRegion == 0 & SameHemisphere == 1;
                    SameHemisphere = SameHemisphere == 1 & SameRegion == 0 & SameLobe == 0;
                    %
                    MeasureLinks(SameLobe) = cellfun(@(x,y) cat(2, x(1:2), y(end-1:end)), ToCenter(SameLobe), ToDestination(SameLobe), 'UniformOutput', 0);
                    MeasureLinks(SameHemisphere) = cellfun(@(x,y) cat(2, x(1:3), y(end-2:end)), ToCenter(SameHemisphere), ToDestination(SameHemisphere), 'UniformOutput', 0);
                end
            end
        end
    end
end
 
% @TODO: remove once not needed anymore
function [aSplines] = ComputeSpline(hFig, MeasureLinks, Vertices)
    %
    aSplines = [];
    nMeasureLinks = size(MeasureLinks,1);
    if (nMeasureLinks > 0)
        % Define Spline Implementation details
        Order = [3 4 5 6 7 8 9 10];
        Weights = [
 {
    [ 1.0000  0.8975  0.8006  0.7091  0.6233  0.5429  0.4681  0.3989  0.3352  0.2770  0.2244  0.1773  0.1357  0.0997  0.0693  0.0443  0.0249  0.0111  0.0028  0.0000 ;
      0.0000  0.0997  0.1884  0.2659  0.3324  0.3878  0.4321  0.4654  0.4875  0.4986  0.4986  0.4875  0.4654  0.4321  0.3878  0.3324  0.2659  0.1884  0.0997  0.0000  ;
      0.0000  0.0028  0.0111  0.0249  0.0443  0.0693  0.0997  0.1357  0.1773  0.2244  0.2770  0.3352  0.3989  0.4681  0.5429  0.6233  0.7091  0.8006  0.8975  1.0000 ]'
}
 {
    [ 1.0000  0.8503  0.7163  0.5972  0.4921  0.4001  0.3203  0.2519  0.1941  0.1458  0.1063  0.0746  0.0500  0.0315  0.0182  0.0093  0.0039  0.0012  0.0001  0.0000 ;
      0.0000  0.1417  0.2528  0.3359  0.3936  0.4286  0.4435  0.4409  0.4234  0.3936  0.3543  0.3079  0.2572  0.2047  0.1531  0.1050  0.0630  0.0297  0.0079  0.0000 ;
      0.0000  0.0079  0.0297  0.0630  0.1050  0.1531  0.2047  0.2572  0.3079  0.3543  0.3936  0.4234  0.4409  0.4435  0.4286  0.3936  0.3359  0.2528  0.1417  0.0000 ;
      0.0000  0.0001  0.0012  0.0039  0.0093  0.0182  0.0315  0.0500  0.0746  0.1063  0.1458  0.1941  0.2519  0.3203  0.4001  0.4921  0.5972  0.7163  0.8503  1.0000 ]'
}
 {
    [ 1.0000  0.8055  0.6409  0.5029  0.3885  0.2948  0.2192  0.1591  0.1123  0.0767  0.0503  0.0314  0.0184  0.0099  0.0048  0.0020  0.0006  0.0001  0.0000  0.0000 ;
      0.0000  0.1790  0.3016  0.3772  0.4144  0.4211  0.4046  0.3713  0.3268  0.2762  0.2238  0.1729  0.1263  0.0862  0.0537  0.0295  0.0133  0.0042  0.0006  0.0000 ;
      0.0000  0.0149  0.0532  0.1061  0.1657  0.2256  0.2801  0.3249  0.3565  0.3729  0.3729  0.3565  0.3249  0.2801  0.2256  0.1657  0.1061  0.0532  0.0149  0.0000 ;
      0.0000  0.0006  0.0042  0.0133  0.0295  0.0537  0.0862  0.1263  0.1729  0.2238  0.2762  0.3268  0.3713  0.4046  0.4211  0.4144  0.3772  0.3016  0.1790  0.0000 ;
      0.0000  0.0000  0.0001  0.0006  0.0020  0.0048  0.0099  0.0184  0.0314  0.0503  0.0767  0.1123  0.1591  0.2192  0.2948  0.3885  0.5029  0.6409  0.8055  1.0000 ]'
}
 {
    [ 1.0000  0.7631  0.5734  0.4235  0.3067  0.2172  0.1500  0.1005  0.0650  0.0404  0.0238  0.0132  0.0068  0.0031  0.0013  0.0004  0.0001  0.0000  0.0000  0.0000 ;
      0.0000  0.2120  0.3373  0.3970  0.4089  0.3879  0.3460  0.2931  0.2365  0.1817  0.1325  0.0910  0.0582  0.0340  0.0177  0.0078  0.0026  0.0005  0.0000  0.0000 ;
      0.0000  0.0236  0.0794  0.1489  0.2181  0.2770  0.3194  0.3420  0.3440  0.3271  0.2944  0.2502  0.1995  0.1474  0.0989  0.0582  0.0279  0.0093  0.0013  0.0000 ;
      0.0000  0.0013  0.0093  0.0279  0.0582  0.0989  0.1474  0.1995  0.2502  0.2944  0.3271  0.3440  0.3420  0.3194  0.2770  0.2181  0.1489  0.0794  0.0236  0.0000 ;
      0.0000  0.0000  0.0005  0.0026  0.0078  0.0177  0.0340  0.0582  0.0910  0.1325  0.1817  0.2365  0.2931  0.3460  0.3879  0.4089  0.3970  0.3373  0.2120  0.0000 ;
      0.0000  0.0000  0.0000  0.0001  0.0004  0.0013  0.0031  0.0068  0.0132  0.0238  0.0404  0.0650  0.1005  0.1500  0.2172  0.3067  0.4235  0.5734  0.7631  1.0000 ]'
}
 {
    [ 1.0000  0.7230  0.5131  0.3566  0.2421  0.1600  0.1026  0.0635  0.0377  0.0213  0.0113  0.0056  0.0025  0.0010  0.0003  0.0001  0.0000  0.0000  0.0000  0.0000 ;
      0.0000  0.2410  0.3622  0.4012  0.3874  0.3430  0.2841  0.2221  0.1643  0.1148  0.0753  0.0460  0.0257  0.0129  0.0056  0.0020  0.0005  0.0001  0.0000  0.0000 ;
      0.0000  0.0335  0.1065  0.1881  0.2583  0.3062  0.3278  0.3240  0.2988  0.2583  0.2092  0.1580  0.1102  0.0698  0.0391  0.0184  0.0066  0.0015  0.0001  0.0000 ;
      0.0000  0.0025  0.0167  0.0470  0.0918  0.1458  0.2017  0.2520  0.2897  0.3099  0.3099  0.2897  0.2520  0.2017  0.1458  0.0918  0.0470  0.0167  0.0025  0.0000 ;
      0.0000  0.0001  0.0015  0.0066  0.0184  0.0391  0.0698  0.1102  0.1580  0.2092  0.2583  0.2988  0.3240  0.3278  0.3062  0.2583  0.1881  0.1065  0.0335  0.0000 ;
      0.0000  0.0000  0.0001  0.0005  0.0020  0.0056  0.0129  0.0257  0.0460  0.0753  0.1148  0.1643  0.2221  0.2841  0.3430  0.3874  0.4012  0.3622  0.2410  0.0000 ;
      0.0000  0.0000  0.0000  0.0000  0.0001  0.0003  0.0010  0.0025  0.0056  0.0113  0.0213  0.0377  0.0635  0.1026  0.1600  0.2421  0.3566  0.5131  0.7230  1.0000 ]'
}
 {
    [ 1.0000  0.6849  0.4591  0.3003  0.1911  0.1179  0.0702  0.0401  0.0218  0.0112  0.0054  0.0023  0.0009  0.0003  0.0001  0.0000  0.0000  0.0000  0.0000  0.0000 ;
      0.0000  0.2664  0.3780  0.3942  0.3568  0.2948  0.2268  0.1637  0.1110  0.0705  0.0416  0.0226  0.0111  0.0047  0.0017  0.0005  0.0001  0.0000  0.0000  0.0000 ;
      0.0000  0.0444  0.1334  0.2217  0.2854  0.3159  0.3140  0.2864  0.2422  0.1903  0.1387  0.0931  0.0569  0.0309  0.0144  0.0054  0.0015  0.0002  0.0000  0.0000 ;
      0.0000  0.0041  0.0262  0.0693  0.1269  0.1880  0.2416  0.2785  0.2935  0.2854  0.2569  0.2135  0.1625  0.1115  0.0672  0.0338  0.0130  0.0031  0.0002  0.0000 ;
      0.0000  0.0002  0.0031  0.0130  0.0338  0.0672  0.1115  0.1625  0.2135  0.2569  0.2854  0.2935  0.2785  0.2416  0.1880  0.1269  0.0693  0.0262  0.0041  0.0000 ;
      0.0000  0.0000  0.0002  0.0015  0.0054  0.0144  0.0309  0.0569  0.0931  0.1387  0.1903  0.2422  0.2864  0.3140  0.3159  0.2854  0.2217  0.1334  0.0444  0.0000 ;
      0.0000  0.0000  0.0000  0.0001  0.0005  0.0017  0.0047  0.0111  0.0226  0.0416  0.0705  0.1110  0.1637  0.2268  0.2948  0.3568  0.3942  0.3780  0.2664  0.0000 ;
      0.0000  0.0000  0.0000  0.0000  0.0000  0.0001  0.0003  0.0009  0.0023  0.0054  0.0112  0.0218  0.0401  0.0702  0.1179  0.1911  0.3003  0.4591  0.6849  1.0000 ]'
}
 {
    [ 1.0000  0.6489  0.4107  0.2529  0.1509  0.0869  0.0480  0.0253  0.0126  0.0059  0.0025  0.0010  0.0003  0.0001  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000 ;
      0.0000  0.2884  0.3866  0.3793  0.3219  0.2483  0.1773  0.1181  0.0734  0.0424  0.0225  0.0109  0.0047  0.0017  0.0005  0.0001  0.0000  0.0000  0.0000  0.0000 ;
      0.0000  0.0561  0.1592  0.2489  0.3005  0.3103  0.2865  0.2412  0.1869  0.1335  0.0876  0.0523  0.0279  0.0130  0.0050  0.0015  0.0003  0.0000  0.0000  0.0000 ;
      0.0000  0.0062  0.0375  0.0934  0.1602  0.2217  0.2644  0.2814  0.2719  0.2404  0.1947  0.1438  0.0958  0.0563  0.0283  0.0114  0.0033  0.0005  0.0000  0.0000 ;
      0.0000  0.0004  0.0055  0.0219  0.0534  0.0990  0.1526  0.2052  0.2472  0.2704  0.2704  0.2472  0.2052  0.1526  0.0990  0.0534  0.0219  0.0055  0.0004  0.0000 ;
      0.0000  0.0000  0.0005  0.0033  0.0114  0.0283  0.0563  0.0958  0.1438  0.1947  0.2404  0.2719  0.2814  0.2644  0.2217  0.1602  0.0934  0.0375  0.0062  0.0000 ;
      0.0000  0.0000  0.0000  0.0003  0.0015  0.0050  0.0130  0.0279  0.0523  0.0876  0.1335  0.1869  0.2412  0.2865  0.3103  0.3005  0.2489  0.1592  0.0561  0.0000 ;
      0.0000  0.0000  0.0000  0.0000  0.0001  0.0005  0.0017  0.0047  0.0109  0.0225  0.0424  0.0734  0.1181  0.1773  0.2483  0.3219  0.3793  0.3866  0.2884  0.0000 ;
      0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0001  0.0003  0.0010  0.0025  0.0059  0.0126  0.0253  0.0480  0.0869  0.1509  0.2529  0.4107  0.6489  1.0000 ]'
}
 {
    [ 1.0000  0.6147  0.3675  0.2130  0.1191  0.0640  0.0329  0.0160  0.0073  0.0031  0.0012  0.0004  0.0001  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000 ;
      0.0000  0.3074  0.3891  0.3594  0.2859  0.2058  0.1365  0.0839  0.0478  0.0251  0.0120  0.0051  0.0019  0.0006  0.0002  0.0000  0.0000  0.0000  0.0000  0.0000 ;
      0.0000  0.0683  0.1831  0.2695  0.3050  0.2940  0.2520  0.1959  0.1391  0.0904  0.0534  0.0283  0.0132  0.0053  0.0017  0.0004  0.0001  0.0000  0.0000  0.0000 ;
      0.0000  0.0089  0.0503  0.1179  0.1898  0.2450  0.2714  0.2666  0.2361  0.1898  0.1383  0.0908  0.0529  0.0267  0.0112  0.0036  0.0008  0.0001  0.0000  0.0000 ;
      0.0000  0.0007  0.0089  0.0332  0.0759  0.1313  0.1879  0.2333  0.2576  0.2562  0.2306  0.1873  0.1361  0.0867  0.0469  0.0202  0.0062  0.0010  0.0000  0.0000 ;
      0.0000  0.0000  0.0010  0.0062  0.0202  0.0469  0.0867  0.1361  0.1873  0.2306  0.2562  0.2576  0.2333  0.1879  0.1313  0.0759  0.0332  0.0089  0.0007  0.0000 ;
      0.0000  0.0000  0.0001  0.0008  0.0036  0.0112  0.0267  0.0529  0.0908  0.1383  0.1898  0.2361  0.2666  0.2714  0.2450  0.1898  0.1179  0.0503  0.0089  0.0000 ;
      0.0000  0.0000  0.0000  0.0001  0.0004  0.0017  0.0053  0.0132  0.0283  0.0534  0.0904  0.1391  0.1959  0.2520  0.2940  0.3050  0.2695  0.1831  0.0683  0.0000 ;
      0.0000  0.0000  0.0000  0.0000  0.0000  0.0002  0.0006  0.0019  0.0051  0.0120  0.0251  0.0478  0.0839  0.1365  0.2058  0.2859  0.3594  0.3891  0.3074  0.0000 ;
      0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0000  0.0001  0.0004  0.0012  0.0031  0.0073  0.0160  0.0329  0.0640  0.1191  0.2130  0.3675  0.6147  1.0000 ]'
}
];
        LinkDetail = 20;
        Spread = linspace(0,1,LinkDetail);
        % Bundling factor
        Bundling = 0.9;
        
        
        % Compute spline for each MeasureLinks
        MaxDist = max(max(Vertices(:,:))) * 2;
        aSplines = zeros(nMeasureLinks * 8 * 10 * 3,1);
        
        Index = 1;
        for i=1:nMeasureLinks
            % Link
            Link = MeasureLinks{i};
            % Number of control points (CP)
            nFrames = size(Link,2);
            % Get the positions of CP
            Frames = Vertices(Link(:),:);
            % Last minute display candy
            if (nFrames == 3)
                % We assume that 3 frames are nodes near each others
                % and force an arc between the nodes
                Dist = sqrt(sum(abs(Frames(end,:) - Frames(1,:)).^2));
                Dist = abs(0.9 - Dist / MaxDist);
                Middle = (Frames(1,:) + Frames(end,:)) / 2;
                Frames(2,:) = Middle * Dist;
            end
            % 
            if (nFrames == 2)
                aSplines(Index) = 2;
                aSplines(Index+1:Index + 2 * 3) = reshape(Frames(1:2,:)',[],1);
                Index = Index + 2 * 3 + 1;
            else
                % Bundling property (Higher beta very bundled)
                % Beta = 0.7 + 0.2 * sin(0:pi/(nFrames-1):pi);
                Beta = Bundling * ones(1,nFrames);
                
                % Prototype: Corpus Callosum influence
                % N = nFrames;
                % t = 0:1/(N-1):1;
                % Beta = Bundling + 0.1 * cos((2 * pi) / (N / 2) * (t * N));
                
                for y=2:nFrames-1
                    Frames(y,:) = Beta(y) * Frames(y,:) + (1 - Beta(y)) * (Frames(1,:) + y / (nFrames - 1) * (Frames(end,:) - Frames(1,:)));
                end
                %
                W = Weights{Order == nFrames};
                % 
                Spline = W * Frames;
                % Specifiy link length for Java
                aSplines(Index) = LinkDetail;
                % Assign spline vertices in a one dimension structure
                aSplines(Index+1:Index + (LinkDetail) * 3) = reshape(Spline',[],1);
                % Update index
                Index = Index + (LinkDetail) * 3 + 1;
            end
        end
        % Truncate unused data
        aSplines = aSplines(1:Index-1);
    end
end
 
%% ===== CREATE AND ADD NODES TO DISPLAY =====
%@TODO: figurehastext default on/off
% TODO: fix for 1 x N graphs
function ClearAndAddNodes(hFig, V, Names)
    disp('Entered ClearAndAddNodes');
    
    % get calculated nodes
    MeasureNodes = bst_figures('GetFigureHandleField', hFig, 'MeasureNodes');
    AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
    DisplayedNodes = find(bst_figures('GetFigureHandleField', hFig, 'ValidNode'));
    DisplayedMeasureNodes = MeasureNodes(ismember(MeasureNodes,DisplayedNodes));
    
    NumberOfMeasureNode = length(DisplayedMeasureNodes);
    nAgregatingNodes = length(AgregatingNodes);
    nVertices = size(V,1);
    
    % --- Clear any previous nodes or links ---- %
    if (isappdata(hFig,'AllNodes')) 
        deleteAllNodes(hFig);
        rmappdata(hFig,'AllNodes');
    end
    
    if (isappdata(hFig,'MeasureLinks'))
        delete(getappdata(hFig,'MeasureLinks'));
        rmappdata(hFig,'MeasureLinks');
    end
    
    if (isappdata(hFig,'RegionLinks'))
        delete(getappdata(hFig,'RegionLinks'));
        rmappdata(hFig,'RegionLinks');
    end
    
    if (isappdata(hFig,'MeasureArrows1'))
        delete(getappdata(hFig,'MeasureArrows1'));
        rmappdata(hFig,'MeasureArrows1');
    end
    
    if (isappdata(hFig,'MeasureArrows2'))
        delete(getappdata(hFig,'MeasureArrows2'));
        rmappdata(hFig,'MeasureArrows2');
    end
    
    if (isappdata(hFig,'RegionArrows1'))
        delete(getappdata(hFig,'RegionArrows1'));
        rmappdata(hFig,'RegionArrows1');
    end
    
    if (isappdata(hFig,'RegionArrows2'))
        delete(getappdata(hFig,'RegionArrows2'));
        rmappdata(hFig,'RegionArrows2');
    end
    
    % --- CREATE AND ADD NODES TO DISPLAY ---- %
   
    % Create nodes as an array of struct nodes
    for i=1:nVertices
        isAgregatingNode = false;
        if (i<=nAgregatingNodes)
            isAgregatingNode = true; 
        end
        
        if (isempty(Names(i)) || isempty(Names{i}))
            Names{i} = ''; % Blank name if none is assigned
        end

        % createNode(xpos, ypos, index, label, isAggregatingNode) 
        AllNodes(i) = CreateNode(hFig,V(i,1),V(i,2),i,Names(i),isAgregatingNode);
    end 
    
    % Measure Nodes are color coded to their Scout counterpart
    RowColors = bst_figures('GetFigureHandleField', hFig, 'RowColors');
    if ~isempty(RowColors)
        for i=1:length(RowColors)
            AllNodes(nAgregatingNodes+i).Color = RowColors(i,:);
            AllNodes(nAgregatingNodes+i).NodeMarker.Color = RowColors(i,:);
            AllNodes(nAgregatingNodes+i).NodeMarker.MarkerFaceColor = RowColors(i,:); % set marker fill color
        end 
    end
        
    setappdata(hFig, 'AllNodes', AllNodes); % Very important!
    
    % hide all level 2 nodes (previous region nodes for region links)
    Levels = bst_figures('GetFigureHandleField', hFig, 'Levels');
    Regions = Levels{2};
    for i=1:length(Regions)
        AllNodes(Regions(i)).NodeMarker.Visible = 'off';
        AllNodes(Regions(i)).TextLabel.Visible = 'off';
    end
    
    % refresh display extent
    axis image; %fit display to all objects in image
    ax = hFig.CurrentAxes; %z-axis on default
    ax.Visible = 'off';
 
    % @TODO: default node size (user adjustable)
    %setappdata(hFig, 'NodeSize', NodeSize);
    
    % @TODO: If the number of node is greater than a certain number, we do not display text due to too many nodes
    FigureHasText = NumberOfMeasureNode <= 500;
    setappdata(hFig, 'FigureHasText', FigureHasText);
    if (FigureHasText)
%         OGL.setTextSize(0:(nVertices-1), TextSize);
%         OGL.setTextSize(AgregatingNodes - 1, RegionTextSize);
%         OGL.setTextPosition(0:(nVertices-1), Pos(:,1), Pos(:,2), Pos(:,3));
%         OGL.setTextTransparency(0:(nVertices-1), 0.0);
%         OGL.setTextColor(0:(nVertices-1), 0.1, 0.1, 0.1);
%         OGL.setTextVisible(0:(nVertices-1), 1.0);
%         OGL.setTextVisible(AgregatingNodes - 1, 0);
    end
    
end
 
%% Create A New Node with NodeMarker and TextLabel graphics objs
% Note: done feb 2 2021, removal of node.m usage
% Note: each node is a struct with the following fields:
%   node.Position           - [x,y] coordinates
%   node.isAgregatingNode   - true/false (if this node is a grouped node)
%   node.Color              - colour of the ROI/associated scout, or grey on default
%   node.NodeMarker         - Line Object reprenting the node on the figure
%   node.TextLabel          - Text Object representing the node label on the figure
%
%   NOTE: node.NodeMarker.Userdata = [{[index]} {label} ] to store useful node data
%   so that we can ID the nodes when clicked! Can also retrieve xpos/ypos
%   from the NodeMarker line obj using node.NodeMarker.XData/YData
function node = CreateNode(hFig, xpos, ypos, index, label, isAgregatingNode)
    node.Position = [xpos,ypos];
    node.isAgregatingNode = isAgregatingNode;
    node.Color = [0.5 0.5 0.5];
    node.Label = label;

    % Mark the node as a Matlab Line graphic object
    node.NodeMarker = line(...
        node.Position(1),...
        node.Position(2),...
        -2,...                              #z coordinate 
        'Color',node.Color,...
        'Marker','o',...                    # Marker symbol when the node is selected 'on'
        'MarkerFaceColor', node.Color,...   # Marker is default node color when 'on', grey when 'off'
        'MarkerSize', 5,...                 # default (6) is too big
        'LineStyle','none',...
        'Visible','on',...
        'PickableParts','all',...
        'ButtonDownFcn',@NodeButtonDownFcn,...
        'UserData',[index node.Label xpos ypos]); %NOTE: store useful node data about in node.NodeMarker.UserData so that we can ID the nodes when clicked!
    
    % Create label as Matlab Text obj 
    % display with '_', default colour white, callback to allow clicked labels
    % also store useful node data about in TextLabel.UserData so that we can ID the nodes when label is clicked!
    node.TextLabel = text(0,0,node.Label, 'Interpreter', 'none', 'Color', [1 1 1],'ButtonDownFcn',@LabelButtonDownFcn, 'UserData',[index node.Label xpos ypos]); 
    node.TextLabel.Position = 1.05*node.Position; %need offset factor so label doesn't overlap
    node.TextLabel.FontSize = node.TextLabel.FontSize-3; % this gives size of 7 (default 10 is too big)
    node.TextLabel.FontWeight = 'normal'; % not bold by default

    % default full labels for lobes (user can toggle with 'l' shortcut and
    % popup menu)
    if (isAgregatingNode)
        node.TextLabel.String = LobeTagToFullTag(node.Label);
    end
    
    %rotate and align labels
    t = atan2(node.Position(2),node.Position(1));
    if abs(t) > pi/2
        node.TextLabel.Rotation = 180*(t/pi + 1);
        node.TextLabel.HorizontalAlignment = 'right';
    else
        node.TextLabel.Rotation = t*180/pi;
    end
    
    % show node as 'selected' as default
    SelectNode(hFig, node, true);
   
end

% To visually change the appearance of sel/unsel nodes
function SelectNode(hFig,node,isSelected)
    %disp('Entered SelectNode');
    
    % added March 2021: user can now adjust node size as desired
    nodeSize = getappdata(hFig, 'NodeSize');
    if (isempty(nodeSize))
        nodeSize = 5;
    end
    
    if isSelected % node is SELECTED ("ON")
        % return to original node colour, shape, and size
        node.NodeMarker.Marker = 'o';
        node.NodeMarker.Color = node.NodeMarker.MarkerFaceColor;
        node.NodeMarker.MarkerSize = nodeSize;
        node.TextLabel.Color =  ~GetBackgroundColor(hFig);
    else % node is NOT selected ("OFF")
        % display as a grey 'X' (slightly bigger/bolded to allow for easier clicking shape)
        % node labels also greyed out
        node.NodeMarker.Marker = 'x';
        node.NodeMarker.Color =  [0.5 0.5 0.5]; % grey marker
        node.NodeMarker.MarkerSize = nodeSize + 1;
        node.TextLabel.Color = [0.5 0.5 0.5]; % grey label
    end
end

% Callback Fn for clicked NodeMarker on figure
% NOTE: we use functions within NodeClickedEvent(), SetSelectedNodes(), and SelectNode() 
    % to set actual node and link selection display.      
    % All we need to do here is make sure that the correct index
    % of the clicked node is stored for access 
function NodeButtonDownFcn(src,~)
    global GlobalData;
    GlobalData.FigConnect.ClickedNodeIndex = src.UserData{1};
    
    disp("Node with label '" + src.UserData{2} + "' was clicked");
    disp("Node index: " + src.UserData{1});
    disp("Node position: " + src.UserData{3} + " " + src.UserData{4});
end

% Callback Fn for clicked node label on figure
% NOTE: we use functions within NodeClickedEvent(), SetSelectedNodes(), and SelectNode() 
    % to set actual node and link selection display.      
    % All we need to do here is make sure that the correct index
    % of the clicked nodelabel is stored for access 
function LabelButtonDownFcn(src,~)
    global GlobalData;
    GlobalData.FigConnect.ClickedNodeIndex = src.UserData{1};
    
    disp("Node with label '" + src.UserData{2} + "' was clicked");
    disp("Node index: " + src.UserData{1});
    disp("Node position: " + src.UserData{3} + " " + src.UserData{4});
end


% Delete all node structs and associated graphics objs if exist
function deleteAllNodes(hFig)
    AllNodes = getappdata(hFig,'AllNodes');

    % delete TextLabel Text Objects
    if isfield(AllNodes,'TextLabel')
        for i=1:length(AllNodes)
            delete(AllNodes(i).TextLabel);
        end
    end

    % delete NodeMarker Line Objects
    if isfield(AllNodes,'NodeMarker')
        for i=1:length(AllNodes)
            delete(AllNodes(i).NodeMarker);
        end
    end
end
        
%%
function Index = HemisphereTagToIndex(Region)
    Tag = Region(1);
    Index = 4; % Unknown
    switch (Tag)
        case 'L' % Left
            Index = 1;
        case 'R' % Right
            Index = 2;
        case 'C' % Cerebellum
            Index = 3;
    end
end
 
function Index = LobeTagToIndex(Region)
    Tag = Region(2);
    Index = 7; % Unknown
    switch (Tag)
        case 'F' %Frontal
            Index = 2;
        case 'C' %Central
            Index = 3;
        case 'T' %Temporal
            Index = 4;
        case 'P' %Parietal
            Index = 5;
            if (size(Region,2) >= 3)
                if (strcmp(Region(3), 'F'))
                    Index = 1;
                end
            end
        case 'O' %Occipital
            Index = 6;
    end
end
 
function Tag = ExtractSubRegion(Region)
    Index = LobeTagToIndex(Region);
    if (Index == 1)
        Tag = Region(4:end);
    else
        Tag = Region(3:end);
    end
end
 
function Tag = LobeIndexToTag(Index)
    Tag = 'U';
    switch (Index)
        case 1
            Tag = 'PF';
        case 2
            Tag = 'F';
        case 3
            Tag = 'C';            
        case 4
            Tag = 'T';
        case 5
            Tag = 'P';
        case 6
            Tag = 'O';
    end
end
 
function FullTag = LobeTagToFullTag(Tag)
    if strcmp(Tag,'PF')
        FullTag = 'Pre-Frontal';
    elseif strcmp(Tag,'F')
        FullTag = 'Frontal';
    elseif strcmp(Tag,'C')
        FullTag = 'Cerebral';       
    elseif strcmp(Tag,'T')
        FullTag = 'Temporal';
    elseif strcmp(Tag,'P')
        FullTag = 'Parietal';
    elseif strcmp(Tag,'O')
        FullTag = 'Occipital';
    elseif strcmp(Tag, 'U')
        FullTag = 'Unknown';
    else
        FullTag = Tag;
    end
end
 
function PathNames = VerticeToFullName(hFig, Index)
    if (Index == 1)
        return
    end
    PathNames{1} = 'All';
    ChannelData = bst_figures('GetFigureHandleField', hFig, 'ChannelData');
    if (ChannelData(Index,3) ~= 0)
        switch (ChannelData(Index,3))
            case 1
                PathNames{2} = ' > Left hemisphere';
            case 2
                PathNames{2} = ' > Right hemisphere';
            case 3
                PathNames{2} = ' > Cerebellum';
            case 4
                PathNames{2} = ' > Unknown';
        end
    end
    
    if (ChannelData(Index,2) ~= 0)
        switch (ChannelData(Index,2))
            case 1
                PathNames{3} = ' > Pre-Frontal';
            case 2
                PathNames{3} = ' > Frontal';
            case 3
                PathNames{3} = ' > Central';
            case 4
                PathNames{3} = ' > Temporal';
            case 5
                PathNames{3} = ' > Parietal';
            case 6
                PathNames{3} = ' > Occipital';
            otherwise
                PathNames{3} = ' > Unknown';
        end
    end
    
    if (ChannelData(Index,1) ~= 0)
        Names = bst_figures('GetFigureHandleField', hFig, 'Names');
        if isempty(Names{Index})
            PathNames{4} = ' > Sub-region';
        else
            PathNames{4} = [' > ' Names{Index}];
        end
    end 
end
 
 
function [sGroups] = GroupScouts(Atlas)
    % 
    NumberOfGroups = 0;
    sGroups = repmat(struct('Name', [], 'RowNames', [], 'Region', {}), 0);
    NumberOfScouts = size(Atlas.Scouts,2);
    for i=1:NumberOfScouts
        Region = Atlas.Scouts(i).Region;
        GroupID = strmatch(Region, {sGroups.Region}, 'exact');
        if isempty(GroupID)
            % New group
            NumberOfGroups = NumberOfGroups + 1;
            sGroups(NumberOfGroups).Name = ['Group ' num2str(NumberOfGroups)];
            sGroups(NumberOfGroups).RowNames = {Atlas.Scouts(i).Label};
            sGroups(NumberOfGroups).Region = Region;
        else
            sGroups(GroupID).RowNames = [sGroups(GroupID).RowNames {Atlas.Scouts(i).Label}];
        end
    end
    
    if size(sGroups,2) == 1 && strcmp(sGroups(1).Region, 'UU') == 1
        sGroups = [];
        return;
    end
    
    % Sort by Hemisphere and Lobe
    for i=2:NumberOfGroups
        j = i;
        sTemp = sGroups(i);
        currentHemisphere = HemisphereTagToIndex(sGroups(i).Region);
        currentLobe = LobeTagToIndex(sGroups(i).Region);
        while ((j > 1))
            current = currentHemisphere;
            next = HemisphereTagToIndex(sGroups(j-1).Region);
            if (current == next)
                current = currentLobe;
                next = LobeTagToIndex(sGroups(j-1).Region);
            end
            if (next <= current)
                break;
            end
            sGroups(j) = sGroups(j-1);
            j = j - 1;
        end
        sGroups(j) = sTemp;
    end
end
 
 
% @NOTE: ready, no changed needed
function [Vertices Paths Names] = OrganiseNodesWithConstantLobe(hFig, aNames, sGroups, RowLocs, UpdateStructureStatistics)
    % Display options
    MeasureLevel = 4;
    RegionLevel = 3.5;         % currently invisible anyway (unused/hidden region nodes)
    LobeLevel = 2.75;          % moved lobe nodes outward (previously 2.5) 
    HemisphereLevel = 1.5;      % moved hem nodes outward (previously 1.0) 
    setappdata(hFig, 'MeasureLevelDistance', MeasureLevel);
    setappdata(hFig, 'RegionLevelDistance', LobeLevel);
    
    % Some values are Hardcoded for Display consistency
    NumberOfMeasureNodes = size(aNames,1);
    NumberOfGroups = size(sGroups,2);
    NumberOfLobes = 7;
    NumberOfHemispheres = 2;
    NumberOfLevels = 5;
        
    % Extract only the first region letter of each group
    HemisphereRegions = cellfun(@(x) {x(1)}, {sGroups.Region})';
    LobeRegions = cellfun(@(x) {LobeIndexToTag(LobeTagToIndex(x))}, {sGroups.Region})';
    
    LeftGroupsIndex = strcmp('L',HemisphereRegions) == 1;
    RightGroupsIndex = strcmp('R',HemisphereRegions) == 1;
    CerebellumGroupsIndex = strcmp('C',HemisphereRegions) == 1;
    UnknownGroupsIndex = strcmp('U',HemisphereRegions) == 1;
    
    % Angle allowed for each hemisphere
    AngleAllowed = [0 180];
    nCerebellum = sum(CerebellumGroupsIndex);
    if (nCerebellum > 0)
        % Constant size of 15% of circle allowed to Cerebellum
        AngleAllowed(2) = 180 - 15;
        NumberOfHemispheres = NumberOfHemispheres + 1;
    end
    
    nUnkown = sum(UnknownGroupsIndex);
    if (nUnkown > 0)
        % Constant size of 15% of circle allowed to Unknown
        AngleAllowed(1) = 15;
    end
    
    % NumberOfLevel = Self + Middle + EverythingInBetween
    Levels = cell(NumberOfLevels,1);
    Levels{5} = 1;
    Levels{4} = (2:(NumberOfHemispheres+1))';
    
    Lobes = [];
    NumberOfNodesPerLobe = zeros(NumberOfLobes * 2,1);
    for i=1:NumberOfLobes
        Tag = LobeIndexToTag(i);
        RegionsIndex = strcmp(Tag,LobeRegions) == 1;
        NodesInLeft = [sGroups(LeftGroupsIndex & RegionsIndex).RowNames];
        NodesInRight = [sGroups(RightGroupsIndex & RegionsIndex).RowNames];
        NumberOfNodesPerLobe(i) = length(NodesInLeft);
        NumberOfNodesPerLobe(NumberOfLobes + i) = length(NodesInRight);
        if (size(NodesInLeft,2) > 0 || size(NodesInRight,2) > 0)
            Lobes = [Lobes i];
        end
    end
    
    % Actual number of lobes with data
    NumberOfLobes = size(Lobes,2);
    
    % Start and end angle for each lobe section
    % We use a constant separation for each lobe
    AngleStep = (AngleAllowed(2) - AngleAllowed(1))/ NumberOfLobes;
    LobeSections = zeros(NumberOfLobes,2);
    LobeSections(:,1) = 0:NumberOfLobes-1;
    LobeSections(:,2) = 1:NumberOfLobes;
    LobeSections(:,:) = AngleAllowed(1) + LobeSections(:,:) * AngleStep;
    
    NumberOfAgregatingNodes = 1 + NumberOfHemispheres + NumberOfLobes * 2 + NumberOfGroups;
    NumberOfVertices = NumberOfMeasureNodes + NumberOfAgregatingNodes;
    Vertices = zeros(NumberOfVertices,3);
    Names = cell(NumberOfVertices,1);
    Paths = cell(NumberOfVertices,1);
    ChannelData = zeros(NumberOfVertices,3);
    
    % Static Nodes
    Vertices(1,:) = [0 0 0];                    % Corpus Callosum
    Vertices(2,:) = [-HemisphereLevel 0 0];     % Left Hemisphere
    Vertices(3,:) = [ HemisphereLevel 0 0];     % Right Hemisphere
    if (nCerebellum > 0)
        Vertices(4,:) = [ 0 -HemisphereLevel 0];    % Cerebellum
        Names(4) = {''};
        Paths{4} = [4 1];
        ChannelData(4,:) = [0 0 3];
    end
    Names(1) = {''};
    Names(2) = {'Left'};
    Names(3) = {'Right'};
    Paths{1} = 1;
    Paths{2} = [2 1];
    Paths{3} = [3 1];
    ChannelData(2,:) = [0 0 1];
    ChannelData(3,:) = [0 0 2];
    
    % The lobes are determined by the mean of the regions nodes
    % The regions nodes are determined by the mean of their nodes
    % Organise Left Hemisphere
    RegionIndex = 1 + NumberOfHemispheres + NumberOfLobes * 2 + 1;
    for i=1:NumberOfLobes
        Lobe = i;
        LobeIndex = Lobe + NumberOfHemispheres + 1;
        Levels{3} = [Levels{3}; LobeIndex];
        Angle = 90 + LobeSections(Lobe,1);
        LobeTag = LobeIndexToTag(Lobes(i));
        RegionMask = strcmp(LobeTag,LobeRegions) == 1 & strcmp('L',HemisphereRegions) == 1;
        RegionNodeIndex = find(RegionMask == 1);
        NumberOfRegionInLobe = sum(RegionMask);
        for y=1:NumberOfRegionInLobe
            Levels{2} = [Levels{2}; RegionIndex];
            Group = sGroups(RegionNodeIndex(y));
            Region = [Group.Region];
            NumberOfNodesInGroup = length([Group.RowNames]);
            if (NumberOfNodesInGroup > 0)
                % Figure out how much space per node
                AllowedPercent = NumberOfNodesInGroup / NumberOfNodesPerLobe(Lobes(i));
                LobeSpace = LobeSections(Lobe,2) - LobeSections(Lobe,1);
                AllowedSpace = AllowedPercent * LobeSpace;
                % +2 is for the offset at borders so regions don't touch        
                LocalTheta = linspace((pi/180) * (Angle), (pi/180) * (Angle + AllowedSpace), NumberOfNodesInGroup + 2);
                % Retrieve cartesian coordinate
                [posX,posY] = pol2cart(LocalTheta(2:(end-1)),1);
                % Assign
                ChannelsOfThisGroup = ismember(aNames, Group.RowNames);
                % Compensate for agregating nodes
                Index = find(ChannelsOfThisGroup) + NumberOfAgregatingNodes;
                % Update node information
                Order = 1:size(Index,1);
                if ~isempty(RowLocs)
                    [tmp, Order] = sort(RowLocs(ChannelsOfThisGroup,1), 'descend');
                end
                Vertices(Index(Order), 1:2) = [posX' posY'] * MeasureLevel;
                Names(Index) = aNames(ChannelsOfThisGroup);
                Paths(Index) = mat2cell([Index repmat([RegionIndex LobeIndex 2 1], size(Index))], ones(1,size(Index,1)), 5);
                ChannelData(Index,:) = repmat([RegionIndex Lobes(Lobe) 1], size(Index));
                Levels{1} = [Levels{1}; Index(Order)];
                % Update agregating node
                if (NumberOfNodesInGroup == 1)
                    Mean = [posX posY];
                else
                    Mean = mean([posX' posY']);
                end
                Mean = Mean / norm(Mean);
                Vertices(RegionIndex, 1:2) = Mean * RegionLevel;
                Names(RegionIndex) = {ExtractSubRegion(Region)};
                Paths(RegionIndex) = {[RegionIndex LobeIndex 2 1]};
                ChannelData(RegionIndex,:) = [RegionIndex Lobes(Lobe) 1];
                % Update current angle
                Angle = Angle + AllowedSpace;
            end
            RegionIndex = RegionIndex + 1;
        end
        
        Pos = 90 + (LobeSections(Lobe,2) + LobeSections(Lobe,1)) / 2;
        [posX,posY] = pol2cart((pi/180) * (Pos),1);
        Vertices(LobeIndex, 1:2) = [posX,posY] * LobeLevel;
        Names(LobeIndex) = {LobeTag};
        Paths(LobeIndex) = {[LobeIndex 2 1]};
        ChannelData(LobeIndex,:) = [0 Lobes(Lobe) 1];
    end
    
    % Organise Right Hemisphere
    for i=1:NumberOfLobes
        Lobe = i;
        LobeIndex = Lobe + NumberOfLobes + NumberOfHemispheres + 1;
        Levels{3} = [Levels{3}; LobeIndex];
        Angle = 90 - LobeSections(Lobe,1);
        LobeTag = LobeIndexToTag(Lobes(i));
        RegionMask = strcmp(LobeTag,LobeRegions) == 1 & strcmp('R',HemisphereRegions) == 1;
        RegionNodeIndex = find(RegionMask == 1);
        NumberOfRegionInLobe = sum(RegionMask);
        for y=1:NumberOfRegionInLobe
            Levels{2} = [Levels{2}; RegionIndex];
            Group = sGroups(RegionNodeIndex(y));
            Region = [Group.Region];
            NumberOfNodesInGroup = length([Group.RowNames]);
            if (NumberOfNodesInGroup > 0)
                % Figure out how much space per node
                AllowedPercent = NumberOfNodesInGroup / NumberOfNodesPerLobe(Lobes(i) + 7);
                LobeSpace = LobeSections(Lobe,2) - LobeSections(Lobe,1);
                AllowedSpace = AllowedPercent * LobeSpace;
                % +2 is for the offset at borders so regions don't touch        
                LocalTheta = linspace((pi/180) * (Angle), (pi/180) * (Angle - AllowedSpace), NumberOfNodesInGroup + 2);
                % Retrieve cartesian coordinate
                [posX,posY] = pol2cart(LocalTheta(2:(end-1)),1);
                % Assign
                ChannelsOfThisGroup = ismember(aNames, Group.RowNames);
                % Compensate for agregating nodes
                Index = find(ChannelsOfThisGroup) + NumberOfAgregatingNodes;
                % Update node information
                Order = 1:size(Index,1);
                if ~isempty(RowLocs)
                    [tmp, Order] = sort(RowLocs(ChannelsOfThisGroup,1), 'descend');
                end
                Vertices(Index(Order), 1:2) = [posX' posY'] * MeasureLevel;
                Names(Index) = aNames(ChannelsOfThisGroup);
                Paths(Index) = mat2cell([Index repmat([RegionIndex LobeIndex 3 1], size(Index))], ones(1,size(Index,1)), 5);
                ChannelData(Index,:) = repmat([RegionIndex Lobes(Lobe) 2], size(Index));
                Levels{1} = [Levels{1}; Index(Order)];
                % Update agregating node
                if (NumberOfNodesInGroup == 1)
                    Mean = [posX posY];
                else
                    Mean = mean([posX' posY']);
                end
                Mean = Mean / norm(Mean);
                Vertices(RegionIndex, 1:2) = Mean * RegionLevel;
                Names(RegionIndex) = {ExtractSubRegion(Region)};
                Paths(RegionIndex) = {[RegionIndex LobeIndex 3 1]};
                ChannelData(RegionIndex,:) = [RegionIndex Lobes(Lobe) 2];
                % Update current angle
                Angle = Angle - AllowedSpace;
            end
            RegionIndex = RegionIndex + 1;
        end
        
        Pos = 90 - (LobeSections(Lobe,2) + LobeSections(Lobe,1)) / 2;
        [posX,posY] = pol2cart((pi/180) * (Pos),1);
        Vertices(LobeIndex, 1:2) = [posX,posY] * LobeLevel;
        Names(LobeIndex) = {LobeTag};
        Paths(LobeIndex) = {[LobeIndex 3 1]};
        ChannelData(LobeIndex,:) = [0 Lobes(Lobe) 2];
    end
    
    % Organise Cerebellum
    if (nCerebellum > 0)
        Angle = 270 - 15;
        NodesInCerebellum = [sGroups(CerebellumGroupsIndex).RowNames];
        NumberOfNodesInCerebellum = size(NodesInCerebellum,2);
        RegionMask = strcmp('C',HemisphereRegions) == 1;
        RegionNodeIndex = find(RegionMask == 1);
        NumberOfRegionInCerebellum = sum(RegionMask);
        for y=1:NumberOfRegionInCerebellum
            Levels{2} = [Levels{2}; RegionIndex];
            Group = sGroups(RegionNodeIndex(y));
            Region = [Group.Region];
            NumberOfNodesInGroup = length([Group.RowNames]);
            if (NumberOfNodesInGroup > 0)
                % Figure out how much space per node
                AllowedPercent = NumberOfNodesInGroup / NumberOfNodesInCerebellum;
                % Static for Cerebellum
                LobeSpace = 30;
                AllowedSpace = AllowedPercent * LobeSpace;
                % +2 is for the offset at borders so regions don't touch        
                LocalTheta = linspace((pi/180) * (Angle), (pi/180) * (Angle + AllowedSpace), NumberOfNodesInGroup + 2);
                % Retrieve cartesian coordinate
                [posX,posY] = pol2cart(LocalTheta(2:(end-1)),1);
                % Assign
                ChannelsOfThisGroup = ismember(aNames, Group.RowNames);
                % Compensate for agregating nodes
                Index = find(ChannelsOfThisGroup) + NumberOfAgregatingNodes;
                Order = 1:size(Index,1);
                if ~isempty(RowLocs)
                    [tmp, Order] = sort(RowLocs(ChannelsOfThisGroup,1), 'descend');
                end
                Vertices(Index(Order), 1:2) = [posX' posY'] * MeasureLevel;
                Names(Index) = aNames(ChannelsOfThisGroup);
                Paths(Index) = mat2cell([Index repmat([RegionIndex 4 1 1], size(Index))], ones(1,size(Index,1)), 5);
                ChannelData(Index,:) = repmat([RegionIndex 0 0], size(Index));
                Levels{1} = [Levels{1}; Index];
                % Update agregating node
                if (NumberOfNodesInGroup == 1)
                    Mean = [posX posY];
                else
                    Mean = mean([posX' posY']);
                end
                Mean = Mean / norm(Mean);
                Vertices(RegionIndex, 1:2) = Mean * RegionLevel;
                Names(RegionIndex) = {ExtractSubRegion(Region)};
                Paths(RegionIndex) = {[RegionIndex 4 1 1]};
                ChannelData(RegionIndex,:) = [RegionIndex 0 0];
                % Update current angle
                Angle = Angle + AllowedSpace;
            end
            RegionIndex = RegionIndex + 1;
        end
    end
    
    % Organise Unknown...
    if (nUnkown > 0)
        Angle = 90 - 15;
        NodesInUnknown = [sGroups(UnknownGroupsIndex).RowNames];
        NumberOfNodesInUnknown = size(NodesInUnknown,2);
        RegionMask = strcmp('U',HemisphereRegions) == 1;
        RegionNodeIndex = find(RegionMask == 1);
        NumberOfRegionInUnknown = sum(RegionMask);
        for y=1:NumberOfRegionInUnknown
            Levels{2} = [Levels{2}; RegionIndex];
            Group = sGroups(RegionNodeIndex(y));
            Region = [Group.Region];
            NumberOfNodesInGroup = size([Group.RowNames],2);
            if (NumberOfNodesInGroup > 0)
                % Figure out how much space per node
                AllowedPercent = NumberOfNodesInGroup / NumberOfNodesInUnknown;
                % Static for Cerebellum
                LobeSpace = 30;
                AllowedSpace = AllowedPercent * LobeSpace;
                % +2 is for the offset at borders so regions don't touch        
                LocalTheta = linspace((pi/180) * (Angle), (pi/180) * (Angle + AllowedSpace), NumberOfNodesInGroup + 2);
                % Retrieve cartesian coordinate
                [posX,posY] = pol2cart(LocalTheta(2:(end-1)),1);
                % Assign
                ChannelsOfThisGroup = ismember(aNames, Group.RowNames);
                % Compensate for agregating nodes
                Index = find(ChannelsOfThisGroup) + NumberOfAgregatingNodes;
                Order = 1:size(Index,1);
                if ~isempty(RowLocs)
                    [tmp, Order] = sort(RowLocs(ChannelsOfThisGroup,1), 'descend');
                end
                Vertices(Index(Order), 1:2) = [posX' posY'] * MeasureLevel;
                Names(Index) = aNames(ChannelsOfThisGroup);
                Paths(Index) = mat2cell([Index repmat([RegionIndex 1 1 1], size(Index))], ones(1,size(Index,1)), 5);
                ChannelData(Index,:) = repmat([RegionIndex 0 0], size(Index));
                Levels{1} = [Levels{1}; Index];
                % Update agregating node
                if (NumberOfNodesInGroup == 1)
                    Mean = [posX posY];
                else
                    Mean = mean([posX' posY']);
                end
                Mean = Mean / norm(Mean);
                Vertices(RegionIndex, 1:2) = Mean * RegionLevel;
                Names(RegionIndex) = {ExtractSubRegion(Region)};
                Paths(RegionIndex) = {[RegionIndex 1 1 1]};
                ChannelData(RegionIndex,:) = [RegionIndex 0 0];
                % Update current angle
                Angle = Angle + AllowedSpace;
            end
            RegionIndex = RegionIndex + 1;
        end
    end
    
    if (~isempty(UpdateStructureStatistics) && UpdateStructureStatistics == 1)
        % Keep Structures Statistics
        bst_figures('SetFigureHandleField', hFig, 'AgregatingNodes', 1:NumberOfAgregatingNodes);
        bst_figures('SetFigureHandleField', hFig, 'MeasureNodes', (NumberOfAgregatingNodes + 1):(NumberOfAgregatingNodes + NumberOfMeasureNodes));
        % Levels information
        bst_figures('SetFigureHandleField', hFig, 'NumberOfLevels', NumberOfLevels);
        bst_figures('SetFigureHandleField', hFig, 'Levels', Levels);
        % Node hierarchy data
        bst_figures('SetFigureHandleField', hFig, 'ChannelData', ChannelData);
    end
end
 
 
function [Vertices Paths Names] = OrganiseNodeInCircle(hFig, aNames, sGroups)
    % Display options
    MeasureLevel = 4;
    RegionLevel = 2;
    setappdata(hFig, 'MeasureLevelDistance', MeasureLevel);
    setappdata(hFig, 'RegionLevelDistance', RegionLevel);
    
    NumberOfMeasureNodes = size(aNames,1);
    NumberOfGroups = size(sGroups,2);
    NumberOfAgregatingNodes = 1;
        
    NumberOfLevels = 2;
    if (NumberOfGroups > 1)
        NumberOfLevels = 3;
        NumberOfAgregatingNodes = NumberOfAgregatingNodes + NumberOfGroups;
    end
    % NumberOfLevel = Self + Middle + EverythingInBetween
    Levels = cell(NumberOfLevels,1);
    Levels{end} = 1;
    
    NumberOfVertices = NumberOfMeasureNodes + NumberOfAgregatingNodes;
    
    % Structure for vertices
    Vertices = zeros(NumberOfVertices,3);
    Names = cell(NumberOfVertices,1);
    Paths = cell(NumberOfVertices,1);
    
    % Static node
    Vertices(1,1:2) = [0 0];
    Names{1} = ' ';
    Paths{1} = 1;
    
    NumberOfNodesInGroup = zeros(NumberOfGroups,1);
    GroupsTheta = zeros(NumberOfGroups,1);
    GroupsTheta(1,1) = (pi * 0.5);
    for i=1:NumberOfGroups
        if (i ~= 1)
            GroupsTheta(i,1) = GroupsTheta(i-1,2);
        end
        NumberOfNodesInGroup(i) = 1;
        if (iscellstr(sGroups(i).RowNames))
            NumberOfNodesInGroup(i) = size(sGroups(i).RowNames,2);
        end
        Theta = (NumberOfNodesInGroup(i) / NumberOfMeasureNodes * (2 * pi));
        GroupsTheta(i,2) = GroupsTheta(i,1) + Theta;
    end
        
    for i=1:NumberOfGroups
        LocalTheta = linspace(GroupsTheta(i,1), GroupsTheta(i,2), NumberOfNodesInGroup(i) + 1);
        ChannelsOfThisGroup = ismember(aNames, sGroups(i).RowNames);
        Index = find(ChannelsOfThisGroup) + NumberOfAgregatingNodes;
        [posX,posY] = pol2cart(LocalTheta(2:end),1);
        Vertices(Index,1:2) = [posX' posY'] * MeasureLevel;
        Names(Index) = sGroups(i).RowNames;
        Paths(Index) = mat2cell([Index repmat(1, size(Index))], ones(1,size(Index,1)), 2);
        Levels{1} = [Levels{1}; Index];
        
        if (NumberOfLevels > 2)
            RegionIndex = i + 1;
            Paths(Index) = mat2cell([Index repmat([RegionIndex 1], size(Index))], ones(1,size(Index,1)), 3);
            
            % Update agregating node
            if (NumberOfNodesInGroup(i) == 1)
                Mean = [posX posY];
            else
                Mean = mean([posX' posY']);
            end
            Mean = Mean / norm(Mean);
            Vertices(RegionIndex,1:2) = Mean * RegionLevel;
            Names(RegionIndex) = {['Region ' num2str(i)]};
            Paths(RegionIndex) = {[RegionIndex 1]};
            Levels{2} = [Levels{2}; RegionIndex];
        end
    end
    
    % Keep Structures Statistics
    AgregatingNodes = 1:NumberOfAgregatingNodes;
    MeasureNodes = NumberOfAgregatingNodes+1:NumberOfAgregatingNodes+NumberOfMeasureNodes;    
    bst_figures('SetFigureHandleField', hFig, 'AgregatingNodes', AgregatingNodes);
    bst_figures('SetFigureHandleField', hFig, 'MeasureNodes', MeasureNodes);
    % 
    bst_figures('SetFigureHandleField', hFig, 'NumberOfLevels', NumberOfLevels);
    %
    bst_figures('SetFigureHandleField', hFig, 'Levels', Levels);
end 