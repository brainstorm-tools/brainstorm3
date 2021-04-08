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

 
eval(macro_method);
end
 
%% ===== CREATE FIGURE =====
function hFig = CreateFigure(FigureId) %#ok<DEFNU>
    % Create new figure
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
    setappdata(hFig, 'HierarchyNodeIsVisible', 1);
    setappdata(hFig, 'MeasureLinksIsVisible', 1);
    setappdata(hFig, 'RegionLinksIsVisible', 0);
    setappdata(hFig, 'RegionFunction', 'mean');
    setappdata(hFig, 'LinkTransparency',  0);
        
    % Default Camera variables
    setappdata(hFig, 'CamPitch', 0.5 * 3.1415);
    setappdata(hFig, 'CamYaw', -0.5 * 3.1415);
    
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
function Dispose(hFig) %#ok<DEFNU>
    %NOTE: do not need to delete gcf (curr figure) because this is done in
    %bst_figures(DeleteFigure)
    
    %====Delete Graphics Objects and Clear Variables====
    if (isappdata(hFig,'AllNodes')) 
        DeleteAllNodes(hFig);
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
function ResetDisplay(hFig)
    % Default values
    setappdata(hFig, 'DisplayOutwardMeasure', 1);
    setappdata(hFig, 'DisplayInwardMeasure', 0);
    setappdata(hFig, 'DisplayBidirectionalMeasure', 0);
    setappdata(hFig, 'DataThreshold', 0.5);
    setappdata(hFig, 'DistanceThreshold', 0);
    setappdata(hFig, 'TextDisplayMode', [1 2]);
    setappdata(hFig, 'LobeFullLabel', 1); % 1 for displaying full label (e.g. 'Pre-Frontal') 0 for abbr tag ('PF')
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

function ResetDisplayOptions(hFig)
    % full lobe labels (not abbreviated)
    if (~getappdata(hFig, 'LobeFullLabel'))
        ToggleLobeLabels(hFig);
    end
    
    % show scout and region labels
    if (~isequal(getappdata(hFig, 'TextDisplayMode'),[1 2]))
        setappdata(hFig, 'TextDisplayMode', [1 2]);
        RefreshTextDisplay(hFig);
        HideExtraLobeNode(hFig);
    end
  
    % reset node+label size
    if (GetNodeSize(hFig)~= 5 || ~isappdata(hFig, 'LabelSize') || getappdata(hFig, 'LabelSize')~= 7)
        SetNodeLabelSize(hFig, 5, 7);
    end
    
    % reset link size
    if (getappdata(hFig, 'LinkSize') ~= 1.5)
        SetLinkSize(hFig, 1.5);
    end
    
    % reset link transparency
    if (getappdata(hFig, 'LinkTransparency') ~= 0)
        SetLinkTransparency(hFig, 0);
    end
    
    % reset to black background
    if (~isequal(getappdata(hFig, 'BgColor'),[0 0 0]))
        SetBackgroundColor(hFig, [0 0 0], [1 1 1])
    end
    
    % ensure region nodes (hem and lobes) NOT hidden
    if (~getappdata(hFig, 'HierarchyNodeIsVisible'))
    	SetHierarchyNodeIsVisible(hFig, 1)
    end
    
    % reset camera
    DefaultCamera(hFig);
end

function IsDefault = CheckDisplayOptions(hFig)
    IsDefault = true;

    % check full lobe labels (not abbreviated)
    if (~getappdata(hFig, 'LobeFullLabel'))
        IsDefault = false;
    % check showing scout and region labels   
    elseif(~isequal(getappdata(hFig, 'TextDisplayMode'),[1 2]))
        IsDefault = false;
    % check node+label size
    elseif (GetNodeSize(hFig)~= 5 || ~isappdata(hFig, 'LabelSize') || getappdata(hFig, 'LabelSize')~= 7)
        IsDefault = false;
    % check link size
    elseif (getappdata(hFig, 'LinkSize') ~= 1.5)
        IsDefault = false;
    % check link transparency
    elseif (getappdata(hFig, 'LinkTransparency') ~= 0)
        IsDefault = false;
    % check black background
    elseif (~isequal(getappdata(hFig, 'BgColor'),[0 0 0]))
        IsDefault = false;
    % check region nodes (hem and lobes) NOT hidden
    elseif (~getappdata(hFig, 'HierarchyNodeIsVisible'))
    	IsDefault = false;
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
        for i = 1:size(hTitle,2)
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

%% ===== FIGURE MOUSE CLICK CALLBACK =====
    % See https://www.mathworks.com/help/matlab/ref/matlab.ui.figure-properties.html#buiwuyk-1-SelectionType
    % for details on possible mouseclick types
function FigureMouseDownCallback(hFig, ev)
    % Note: Actual triggered events are applied at MouseUp or other points
    % (e.g. during mousedrag). This function gets information about the
    % click event to classify it

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
            
            % store figure being clicked when clicking on a link
            global GlobalData;
            GlobalData.FigConnect.Figure = hFig;
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

    curPos = get(hFig, 'CurrentPoint');
    
    % Motion from the previous event
    motionFigure = 0.3 * (curPos - getappdata(hFig, 'clickPositionFigure'));
    % Update click point location
    setappdata(hFig, 'clickPositionFigure', curPos);
    % Update the motion flag
    setappdata(hFig, 'hasMoved', 1);
    % Switch between different actions
    switch(clickAction)              
        case 'colorbar'
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
    % Get index of potentially clicked node, link or arrowhead
    % NOTE: Node index stored whenever the node is clicked (any type)
    global GlobalData;
    NodeIndex = GlobalData.FigConnect.ClickedNodeIndex; 
    GlobalData.FigConnect.ClickedNodeIndex = 0; % clear stored index
    
    % clicked link
    LinkIndex = GlobalData.FigConnect.ClickedLinkIndex; 
    GlobalData.FigConnect.ClickedLinkIndex = 0; 
    ArrowIndex = GlobalData.FigConnect.ClickedArrowIndex; 
    GlobalData.FigConnect.ClickedArrowIndex = 0; 
    
    node1 = GlobalData.FigConnect.ClickedNode1Index;
    GlobalData.FigConnect.ClickedNode1Index = 0;
    node2 = GlobalData.FigConnect.ClickedNode2Index;
    GlobalData.FigConnect.ClickedNode2Index = 0;
    
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
                    LinkClickEvent(hFig,LinkIndex,LinkType,IsDirectional,node1,node2);
                end
                if (ArrowIndex>0)
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
function FigureKeyPressedCallback(hFig, keyEvent)
    % Convert to Matlab key event
    [keyEvent, isControl, ~] = gui_brainstorm('ConvertKeyEvent', keyEvent);
    if isempty(keyEvent.Key)
        return;
    end
    
    % Process event
    switch (keyEvent.Key)
        % Test key (for debugging purposes only)
        case 't' 
             Test(hFig);
             
        % ---NODE SELECTIONS---
        case 'a'            % Select All Nodes
            SetSelectedNodes(hFig, [], 1, 1);
            UpdateColormap(hFig);
        case 'leftarrow'    % Select Previous Region
            ToggleRegionSelection(hFig, 1);
        case 'rightarrow'   % Select Next Region
            ToggleRegionSelection(hFig, -1);
        
        % ---NODE LABELS DISPLAY---  
        case 'l'            % Toggle Lobe Labels and abbr type
            if (getappdata(hFig, 'HierarchyNodeIsVisible'))
                ToggleTextDisplayMode(hFig); 
            end
        % ---TOGGLE BACKGROUND---  
        case 'b'            % Toggle Background
            ToggleBackground(hFig);
        
        % ---ZOOM CAMERA---
        case 'uparrow'      % Zoom in
            ZoomCamera(hFig, 0.95 );
        case 'downarrow'    % Zoom in
            ZoomCamera(hFig, 1.05);
        
        % ---SHIFT---
        case 'shift'        % SHIFT+MOVE to move camera, SHIFT+CLICK to select multi-nodes  
            setappdata(hFig, 'ShiftPressed', 1);
            
        % ---SNAPSHOT---
        case 'i'            % CTRL+I Save as image
            if isControl
                out_figure_image(hFig);
            end
        case 'j'            % CTRL+J Open as image
            if isControl
                out_figure_image(hFig, 'Viewer');
            end
        
        % ---OTHER---        
        case 'h' % Toggle visibility of hierarchy/region nodes
            HierarchyNodeIsVisible = getappdata(hFig, 'HierarchyNodeIsVisible');
            HierarchyNodeIsVisible = 1 - HierarchyNodeIsVisible;
            SetHierarchyNodeIsVisible(hFig, HierarchyNodeIsVisible);
        case 'm' % Toggle Region Links
            if (getappdata(hFig, 'HierarchyNodeIsVisible'))
                ToggleMeasureToRegionDisplay(hFig);
            end
        case 'r' % Reset display options to default
            ResetDisplayOptions(hFig);
            
    end
end
 
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
 
function NextNode = GetNextCircularRegion(hFig, Node, Inc)
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
            skip = [1 3]; % skip Levels{1} and Levels{3} if in region links mode, 
        else
            skip = 3; % skip Levels{3} if in measure links mode
        end 
    end
    
    for i = 1:size(Levels,1) 
        if (~ismember(i,skip))
            CircularIndex = [CircularIndex; Levels{i}];
        end
    end
    
  %  CircularIndex(~ismember(CircularIndex,DisplayNode)) = []; % comment
  %  out to allow toggling when region nodes are hidden
    
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

function SelectAllNodes(hFig)
    SetSelectedNodes(hFig, [], 1, 1);
    UpdateColormap(hFig);
end

function ToggleRegionSelection(hFig, Inc)
    % Get selected nodes
    selNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
    % Get number of AgregatingNode
    AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
    % 
    if (isempty(selNodes))
        % Get first node
        NextNode = GetNextCircularRegion(hFig, [], Inc);
    else
        % Remove previous links
        SetSelectedNodes(hFig, selNodes, 0, 1); 
        % Remove agregating node from selection
        SelectedNode = selNodes(1);
        %
        NextNode = GetNextCircularRegion(hFig, SelectedNode, Inc);
        UpdateColormap(hFig);
    end

    % Is the next node an agregating node?
    isAgregatingNode = ismember(NextNode, AgregatingNodes);
    if (isAgregatingNode)
        % Get agregated nodes
        AgregatedNodeIndices = GetAgregatedNodesFrom(hFig, NextNode); 
        if (~isempty(AgregatedNodeIndices))
            % Select all nodes associated to NextNode
            SetSelectedNodes(hFig, AgregatedNodeIndices, 1, 1);
            UpdateColormap(hFig);
        end    
    else
        % Select next node
        SetSelectedNodes(hFig, NextNode, 1, 1);
        UpdateColormap(hFig);
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
                UpdateColormap(hFig); % required for directional graphs with arrowheads!!

            % If it's the only already selected node then select
            % all and return
            elseif (length(selNodes) == 1)
                SetSelectedNodes(hFig, [], 1); 
                UpdateColormap(hFig);
                return;
            end

            % Aggregative nodes: select blocks of nodes
            if isAgregatingNode
                % Get agregated nodes
                AgregatedNodeIndex = GetAgregatedNodesFrom(hFig, NodeIndex);
                % How many are already selected
                NodeAlreadySelected = ismember(AgregatedNodeIndex, selNodes);

                % If the agregating node and this measure node are
                % the only selected nodes, then select all and
                % return
                if (sum(NodeAlreadySelected) == size(selNodes,1))
                    SetSelectedNodes(hFig, [], 1);
                    UpdateColormap(hFig);
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
            UpdateColormap(hFig);
        end

        % 4. APPLY DE/SELECTIONS
        if (isAgregatingNode)
            SelectNodeIndex = GetAgregatedNodesFrom(hFig, NodeIndex);
            SetSelectedNodes(hFig, [SelectNodeIndex(:); NodeIndex], Select); %set the selection
            % Go up the hierarchy
            UpdateHierarchySelection(hFig, NodeIndex, Select);
            UpdateColormap(hFig);
        else
            SetSelectedNodes(hFig, NodeIndex, Select);
            UpdateColormap(hFig);
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
    AgregatedNodesIndex = GetAgregatedNodesFrom(hFig, AgregatingNode);
    % Is everything selected ?
    if (size(AgregatedNodesIndex,1) == sum(ismember(AgregatedNodesIndex, selNodes)))
        SetSelectedNodes(hFig, AgregatingNode, Select);
        UpdateHierarchySelection(hFig, AgregatingNode, Select);
    end
end
 
%% =====  ZOOM CALLBACK USING MOUSEWHEEL =========
function FigureMouseWheelCallback(hFig, ev)
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
        
            % === TOGGLE LABELS ===
            % Lobe label abbreviations
            if (DisplayInRegion)
                jItem = gui_component('CheckBoxMenuItem', jDisplayMenu, [], 'Abbreviate lobe labels', [], [], @(h, ev)ToggleLobeLabels(hFig));
                jItem.setSelected(~getappdata(hFig,'LobeFullLabel'));
                jItem.setEnabled(getappdata(hFig, 'HierarchyNodeIsVisible'));
            end
            TextDisplayMode = getappdata(hFig, 'TextDisplayMode');
            % Measure (outer) node labels
            jItem = gui_component('CheckBoxMenuItem', jDisplayMenu, [], 'Show scout labels', [], [], @(h, ev)SetTextDisplayMode(hFig, 1));
            jItem.setSelected(ismember(1,TextDisplayMode));
            % Region (lobe/hemisphere) node labels
            if (DisplayInRegion)
                jItem = gui_component('CheckBoxMenuItem', jDisplayMenu, [], 'Show region labels', [], [], @(h, ev)SetTextDisplayMode(hFig, 2));
                jItem.setSelected(ismember(2,TextDisplayMode));
                jItem.setEnabled(getappdata(hFig, 'HierarchyNodeIsVisible'));
            end
            % Selected Nodes' labels only
            jItem = gui_component('CheckBoxMenuItem', jDisplayMenu, [], 'Show labels for selection only', [], [], @(h, ev)SetTextDisplayMode(hFig, 3));
            jItem.setSelected(ismember(3,TextDisplayMode));
        
        jDisplayMenu.addSeparator();
        
        % == LINK DISPLAY OPTIONS ==
        if (bst_get('MatlabVersion') >= 705) % Check Matlab version: Works only for R2007b and newer
            
            % === MODIFY NODE AND LINK SIZE (Mar 2021)===
            jPanelModifiers = gui_river([0 0], [0, 29, 0, 0]);
            % uses node size to update text and slider
            NodeSize = GetNodeSize(hFig);
            % Label
            gui_component('label', jPanelModifiers, '', 'Node & label size');
            % Slider
            jSliderContrast = JSlider(5,25); % uses factor of 2 for node sizes 2.5 to 12.5 with increments of 0.5 in actuality
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
            java_setcb(jSliderContrast.getModel(), 'StateChangedCallback', @(h,ev)NodeLabelSizeSliderCallback(hFig, ev, jLabelContrast));
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
            jSliderContrast = JSlider(1,20); % uses factor of 2 for link sizes 0.5 to 10.0 with increments of 0.5 in actuality
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
            java_setcb(jSliderContrast.getModel(), 'StateChangedCallback', @(h,ev)LinkSizeSliderCallback(hFig, ev, jLabelContrast));
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
            java_setcb(jSliderContrast.getModel(), 'StateChangedCallback', @(h,ev)TransparencySliderCallback(hFig, ev, jLabelContrast));
            jDisplayMenu.add(jPanelModifiers);
        end
        
        % === BACKGROUND OPTIONS ===
        jDisplayMenu.addSeparator();
        BackgroundColor = getappdata(hFig, 'BgColor');
        isWhite = all(BackgroundColor == [1 1 1]);
        jItem = gui_component('CheckBoxMenuItem', jDisplayMenu, [], 'White background', [], [], @(h, ev)ToggleBackground(hFig));
        jItem.setSelected(isWhite);
        
        % === DEFAULT/RESET ===
        jDisplayMenu.addSeparator();
        jItem = gui_component('MenuItem', jDisplayMenu, [], 'Reset display options', [], [], @(h, ev)ResetDisplayOptions(hFig));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_R, 0));
        jItem.setEnabled(~CheckDisplayOptions(hFig));
  
 
    % ==== GRAPH OPTIONS ====
    % 'Graph Options' are directly shown in main pop-up menu
        jPopup.addSeparator();
        % === SELECT ALL THE NODES ===
        jItem = gui_component('MenuItem', jPopup, [], 'Select all', [], [], @(h, n, s, r)SelectAllNodes(hFig));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_A, 0));
        % === SELECT NEXT REGION ===
        jItem = gui_component('MenuItem', jPopup, [], 'Select next region', [], [], @(h, ev)ToggleRegionSelection(hFig, -1));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_RIGHT, 0));
        % === SELECT PREVIOUS REGION===
        jItem = gui_component('MenuItem', jPopup, [], 'Select previous region', [], [], @(h, ev)ToggleRegionSelection(hFig, 1));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_LEFT, 0));
        jPopup.addSeparator();

        if (DisplayInRegion)
            % === TOGGLE HIERARCHY/REGION NODE VISIBILITY ===
            HierarchyNodeIsVisible = getappdata(hFig, 'HierarchyNodeIsVisible');
            jItem = gui_component('CheckBoxMenuItem', jPopup, [], 'Hide region nodes', [], [], @(h, ev)SetHierarchyNodeIsVisible(hFig, 1 - HierarchyNodeIsVisible));
            jItem.setSelected(~HierarchyNodeIsVisible);
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_H, 0));
            jPopup.addSeparator();
        end
        
        if (DisplayInRegion)
            % === TOGGLE DISPLAY REGION LINKS ===
            RegionLinksIsVisible = getappdata(hFig, 'RegionLinksIsVisible');
            RegionFunction = getappdata(hFig, 'RegionFunction');
            jItem = gui_component('CheckBoxMenuItem', jPopup, [], ['Display region ' RegionFunction], [], [], @(h, ev)ToggleMeasureToRegionDisplay(hFig));
            jItem.setSelected(RegionLinksIsVisible);
            jItem.setEnabled(getappdata(hFig, 'HierarchyNodeIsVisible'));
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_M, 0));

            % === TOGGLE REGION FUNCTIONS===
            IsMean = strcmp(RegionFunction, 'mean');
            jLabelMenu = gui_component('Menu', jPopup, [], 'Choose region function');
            jLabelMenu.setEnabled(getappdata(hFig, 'HierarchyNodeIsVisible'));
                jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Mean', [], [], @(h, ev)SetRegionFunction(hFig, 'mean'));
                jItem.setSelected(IsMean);
                jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Max', [], [], @(h, ev)SetRegionFunction(hFig, 'max'));
                jItem.setSelected(~IsMean);
        end
    
    % Display Popup menu
    gui_popup(jPopup, hFig);
end

% Node AND label size slider
function NodeLabelSizeSliderCallback(hFig, ev, jLabel)
    % Update Modifier value
    NodeValue = ev.getSource().getValue() / 2;
    LabelValue = NodeValue * 1.4;
    % Update text value
    jLabel.setText(sprintf('%.0f', NodeValue * 2));
    SetNodeLabelSize(hFig, NodeValue, LabelValue);
end

% Link transparency slider
function TransparencySliderCallback(hFig, ev, jLabel)
    % Update Modifier value
    newValue = double(ev.getSource().getValue()) / 100;
    % Update text value
    jLabel.setText(sprintf('%.0f %%', newValue * 100));
    SetLinkTransparency(hFig, newValue);
end
 
% Link size slider
function LinkSizeSliderCallback(hFig, ev, jLabel)
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
    [~, ~, ~, M, ~, ~, ~, ~] = GetFigureData(hFig);
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
                [~,~,s] = find(M(Valid == 1));
                B = sort(s, 'descend');
                if length(B) > MaximumNumberOfData
                    t = B(MaximumNumberOfData);
                    Valid = Valid & (M >= t);
                end
            else
                [~,~,s] = find(M(Valid == 1));
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
    %% === Initialize data ===
    
    % Necessary for data initialization
    ResetDisplay(hFig);
    % Get figure description
    [hFig, ~, iDS] = bst_figures('GetFigure', hFig);
    % Get connectivity matrix
    [~, ~, TfInfo] = GetFigureData(hFig);
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
    
    %% === ASSIGN GROUPS: CRUCIAL STEP ===
    % display in circle
    if isempty(sGroups)
        % No data to arrange in groups
        if isempty(RowLocs) || isempty(SurfaceMat)
            DisplayInCircle = 1;
            % Create a group for each node
            sGroups = repmat(struct('Name', [], 'RowNames', [], 'Region', []), 0);
            for i = 1:length(RowNames)
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
    
    %% ===== ORGANISE VERTICES =====    
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
        SetDisplayMeasureMode(hFig, 1, 1, 1, Refresh);
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
    HideExtraLobeNode(hFig);
    % Position camera
    DefaultCamera(hFig);
    % display final figure on top
    %shg
end
 
%% ======== Create all links as Matlab Lines =====
function BuildLinks(hFig, DataPair, isMeasureLink)
    % get pre-created nodes
    AllNodes = getappdata(hFig, 'AllNodes');
    IsDirectionalData = getappdata(hFig, 'IsDirectionalData');
    
    % clear any previous links
    % and get scaling distance from nodes to unit circle
    if (isMeasureLink)
        levelScale = getappdata(hFig, 'MeasureLevelDistance');
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
    
    if (IsDirectionalData)
        % for arrowheads
        %-- get axe ranges and their norm
        %-- determine and remember the hold status, toggle if necessary
        if ishold
            WasHold = 1;
        else
            WasHold = 0;
            hold on;
        end
        OriginalAxis = axis;
        Xextend = abs(OriginalAxis(2)-OriginalAxis(1));
        Yextend = abs(OriginalAxis(4)-OriginalAxis(3));
    end
    
    % Note: DataPair computation already removed diagonal and capped at max 5000
    % pairs 
    for i = length(DataPair):-1:1 %for each link (loop backwards to pre-allocate links)
        overlap = false;
        
        % node positions (rescaled to *unit* circle)
        node1 = DataPair(i,1);
        node2 = DataPair(i,2);
        u  = [AllNodes(node1).Position(1);AllNodes(node1).Position(2)]/levelScale;
        v  = [AllNodes(node2).Position(1);AllNodes(node2).Position(2)]/levelScale;
    
        % draw elliptical arc if an overlap is found
        % check if 2 bidirectional links overlap
        All_u(i,:) = u.';
        All_v(i,:) = v.';
        
        % check if this line has a bidirectional equivalent that would
        % overlap
        for j = 1:length(All_u)-1
            if (v(1) == All_u(j,1) && v(2) == All_u(j,2) && u(1) == All_v(j,1) && u(2) == All_v(j,2))
                
                overlap = true;
                
                p = [(AllNodes(node1).Position(1)-AllNodes(node2).Position(1)) (AllNodes(node1).Position(2)-AllNodes(node2).Position(2))];          % horde vector
                H = norm(p);                                % horde length
                R = 0.63*H;                                  % arc radius
                v = [-p(2) p(1)]/H;                         % perpendicular vector
                L = sqrt(R*R-H*H/4);						% distance to circle (from horde)
                p = [(AllNodes(node1).Position(1)+AllNodes(node2).Position(1)) (AllNodes(node1).Position(2)+AllNodes(node2).Position(2))];          % vector center horde
                p0(1,:) = p/2 + v*L;                        % circle center 1
                p0(2,:) = p/2 - v*L;                        % circle center 2
                d = sqrt(sum(p0.^2,2));                     % distance to circle center
                [~,ix] = max( d );                          % get max (circle outside)
                p0 = p0(ix,:);
                
                % generate arc points
                vx = linspace(AllNodes(node1).Position(1),AllNodes(node2).Position(1),100);				% horde points
                vy = linspace(AllNodes(node1).Position(2),AllNodes(node2).Position(2),100);
                vx = vx - p0(1);
                vy = vy - p0(2);
                v = sqrt(vx.^2+vy.^2);
                x = p0(1) + vx./v*R;
                y = p0(2) + vy./v*R;
            end
        end
        
        % if no overlaps were found
        if (~overlap)
            % diametric points: draw a straight line
            % can adjust the error margin (currently 0.2)
            if (abs(u(1)+v(1))<0.2 && abs(u(2)+v(2))<0.2)
                x = linspace(levelScale*u(1),levelScale*v(1),100);
                y = linspace(levelScale*u(2),levelScale*v(2),100);  
                
            else % draw an arc
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
                    % ensure correct direction: from thetaLim(1) to thetaLim(2)
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
            end
        end
        
        % draw actual line
        l = line(...
                x,...
                y,...
                'LineWidth', 1.5,...
                'Color', [AllNodes(node1).Color 0.00],...
                'PickableParts','visible',...
                'Visible','off',...
                'UserData',[i IsDirectionalData isMeasureLink node1 node2],... % i is the index
                'ButtonDownFcn',@LinkButtonDownFcn); % not visible as default;
        
        % add link to list
        Links(i) = l; 

        % arrows for directional links
        if (IsDirectionalData)
            [arrow1, arrow2] = Arrowhead(x, y, AllNodes(node1).Color, 100, 50, i, isMeasureLink, node1, node2, Xextend, Yextend);
            % store arrows
            Arrows1(i) = arrow1;
            Arrows2(i) = arrow2;
        end
    end
    
    % Store Links into figure  
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

    if (IsDirectionalData)
        %-- restore original axe ranges and hold status
        axis(OriginalAxis);
        if ~WasHold
            hold off;
        end
    end
end

% when user clicks on a link
function LinkButtonDownFcn(src, ~)
    global GlobalData;
    hFig = GlobalData.FigConnect.Figure;
    clickAction = getappdata(hFig, 'clickAction');
    AllNodes = getappdata(hFig, 'AllNodes');

    % UserData(1) is the link index
    % UserData(2) is IsDirectional (1 if directional)
    % UserData(3) is isMeasureLink (1 if measure, 0 if region)
    % UserData(4) is index of starting node
    % UserData(5) is index of ending node
    Index = src.UserData(1);
    IsDirectional = src.UserData(2);
    isMeasureLink = src.UserData(3);
    
    % these need to be stored globally so that they can be accessed when
    % mouse click is released
    GlobalData.FigConnect.ClickedLinkIndex = src.UserData(1);
    GlobalData.FigConnect.ClickedNode1Index = src.UserData(4); 
    GlobalData.FigConnect.ClickedNode2Index = src.UserData(5); 
    
    % only works for left mouse clicks
    if (strcmpi(clickAction, 'SingleClick'))    
        % increase size on button down click
        current_size = src.LineWidth;
        set(src, 'LineWidth', 2.0*current_size);
        
        % make node labels larger and bold
        % node indices are stored in UserData
        node1 = AllNodes(src.UserData(4));
        label1 = node1.TextLabel;
        node2 = AllNodes(src.UserData(5));
        label2 = node2.TextLabel;
        current_labelSize = label1.FontSize;
        set(label1, 'FontWeight', 'bold');
        set(label2, 'FontWeight', 'bold');
        set(label1, 'FontSize', current_labelSize + 2);
        set(label2, 'FontSize', current_labelSize + 2);
        
        % also increase size of arrowheads 
        if (IsDirectional)
            if (isMeasureLink)
                Arrows1 = getappdata(hFig,'MeasureArrows1');
                Arrows2 = getappdata(hFig,'MeasureArrows2');
                scale = 2.0;
            else
                Arrows1 = getappdata(hFig,'RegionArrows1');
                Arrows2 = getappdata(hFig,'RegionArrows2');
                scale = 2.0;
            end    
            arrow1 = Arrows1(Index);
            arrow2 = Arrows2(Index);
            arrow_size = arrow1.LineWidth;
            
            set(arrow1, 'LineWidth', scale*arrow_size);
            set(arrow2, 'LineWidth', scale*arrow_size);
        end
    end
end

% return size to original size after releasing mouse click
function LinkClickEvent(hFig,LinkIndex,LinkType,IsDirectional,node1Index,node2Index)
    % measure links
    if (LinkType)
        MeasureLinks = getappdata(hFig,'MeasureLinks');
        Link = MeasureLinks(LinkIndex);
        current_size = Link.LineWidth;
        set(Link, 'LineWidth', current_size/2.0);
        
        if (IsDirectional)
            Arrows1 = getappdata(hFig,'MeasureArrows1');
            Arrows2 = getappdata(hFig,'MeasureArrows2');
            scale = 2.0;
        end    
        
    else % region links
        RegionLinks = getappdata(hFig,'RegionLinks');
        Link = RegionLinks(LinkIndex);
        current_size = Link.LineWidth;     
        set(Link, 'LineWidth', current_size/2.0);
        
        if (IsDirectional)
            Arrows1 = getappdata(hFig,'RegionArrows1');
            Arrows2 = getappdata(hFig,'RegionArrows2'); 
            scale = 2.0;
        end  
    end   
    
    % arrowheads
    if (IsDirectional)
        arrow1 = Arrows1(LinkIndex);
        arrow2 = Arrows2(LinkIndex);
        arrow_size = arrow1.LineWidth;

        set(arrow1, 'LineWidth', arrow_size/scale);
        set(arrow2, 'LineWidth', arrow_size/scale);
    end
    
    % labels
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
    
end

% Draws 2 solid arrowheads for each link
% based on: https://www.mathworks.com/matlabcentral/fileexchange/4538-arrowhead
function [handle1, handle2] = Arrowhead(x,y,clr,ArSize,Where,Index,isMeasureLink,node1,node2,Xextend,Yextend)
    ArWidth = 0.75;
    j = floor(length(x)*Where/100); %-- determine that location
    
    if j >= length(x), j = length(x) - 1; end
    x1 = x(j); x2 = x(j+1); y1 = y(j); y2 = y(j+1);

    %-- determine angle for the rotation of the triangle
    if x2 == x1 %-- line vertical, no need to calculate slope
        if y2 > y1
            p = pi/2;
        else
            p= -pi/2;
        end
    else %-- line not vertical, go ahead and calculate slope
        %-- using normed differences (looks better like that)
        m = ( (y2 - y1)/Yextend ) / ( (x2 - x1)/Xextend );
        if x2 > x1 %-- now calculate the resulting angle
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
    for i = 3:-1:1 % loop backwards to pre-allocate
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
    
    % tip of the second arrow
    new_x = (xd1(2)+xd1(3))/2;
    new_y = (yd1(2)+yd1(3))/2;
    
    %-- draw the first triangle
    handle1 = patch(xd1,...
        yd1,...
        clr,...
        'EdgeColor',clr,...
        'FaceColor',clr,...
        'Visible', 'off',...
        'PickableParts','visible',...
        'UserData',[1 Index isMeasureLink node1,node2],... % flag == 1 when it's the first arrow, and 0 for the second one
        'ButtonDownFcn',@ArrowButtonDownFcn);
    
    % return point on the line closest to the desired location of
    % the second arrowhead (tip of second arrowhead should be at
    % the base of the first one)
    pts_line = [x(:), y(:)];
    dist2 = sum((pts_line - [new_x new_y]) .^ 2, 2);
    [~, index] = min(dist2);
    
    % if more than one index is found, return the one closest to 70
    if (size(index) > 1)
        index = min(60 - index);
    end
    
    % draw second arrow at tip of second half of the link
    x = pts_line(1:index,1);
    y = pts_line(1:index,2);
    
    if (size(x) < 2)
        x = pts_line(1:index+1,1);
    end
    if (size(y) < 2)
        y = pts_line(1:index+1,2);
    end
    
    Where = 100;
    
    % create second arrowhead
    j = floor(length(x)*Where/100); %-- determine that location
    if j >= length(x), j = length(x) - 1; end
    if j == 0, j = 1; end
    x1 = x(j); x2 = x(j+1); y1 = y(j); y2 = y(j+1);
    
    % determine angle for the rotation of the triangle
    if x2 == x1 %line vertical, no need to calculate slope
        if y2 > y1
            p = pi/2;
        else
            p= -pi/2;
        end
    else %-- line not vertical, go ahead and calculate slope
        %-- using normed differences (looks better like that)
        m = ( (y2 - y1)/Yextend ) / ( (x2 - x1)/Xextend );
        if x2 > x1 %-- now calculate the resulting angle
            p = atan(m);
        else
            p = atan(m) + pi;
        end
    end
    
    % 	%-- the arrow is made of a transformed "template triangle".
    % 	%-- it will be created, rotated, moved, resized and shifted.
    %-- rotate it by the angle determined above:
    xd = []; yd = [];
    for i = 3:-1:1 % loop backwards to pre-allocate
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
    
    %-- draw the second triangle
    handle2 = patch(xd1,...
        yd1,...
        clr,...
        'EdgeColor',clr,...
        'FaceColor',clr,...
        'Visible', 'off',...
        'PickableParts','visible',...
        'UserData',[0 Index isMeasureLink node1,node2],... % flag == 1 when it's the first arrow, and 0 for the second one
        'ButtonDownFcn',@ArrowButtonDownFcn);
end

% When user clicks on an arrow
function ArrowButtonDownFcn(src, ~)
    global GlobalData;
    hFig = GlobalData.FigConnect.Figure;
    clickAction = getappdata(hFig, 'clickAction');
    AllNodes = getappdata(hFig, 'AllNodes');
    
    % UserData(1) is 1 for first arrowhead, and 0 for second arrowhead
    % UserData(2) is the index of the arrowhead
    % UserData(3) is isMeasureLink (1 for measure links, 0 for region)
    % UserData(4) is the index of the starting node of the link on which the
    % arrowhead lies
    % UserData(5) is the index of the ending node    
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
        
        % increase size of the node labels and make them bold
        node1 = AllNodes(src.UserData(4));
        label1 = node1.TextLabel;
        node2 = AllNodes(src.UserData(5));
        label2 = node2.TextLabel;
        current_labelSize = label1.FontSize;
        set(label1, 'FontWeight', 'bold');
        set(label2, 'FontWeight', 'bold');
        set(label1, 'FontSize', current_labelSize + 2);
        set(label2, 'FontSize', current_labelSize + 2);
        
        % need to modify size of the second arrowhead too
        if (isMeasureLink)
            if (ArrowType) % first
                Arrows = getappdata(hFig,'MeasureArrows2');
            else
                Arrows = getappdata(hFig,'MeasureArrows1');
            end
            otherArrow = Arrows(Index);
            arrow_size = otherArrow.LineWidth;
            scale = 2.0;
            
            AllLinks = getappdata(hFig,'MeasureLinks');
            Link = AllLinks(Index);
            link_size = Link.LineWidth;
            set(Link, 'LineWidth', 2.0*link_size);
        else
            if (ArrowType) % first
                Arrows = getappdata(hFig,'RegionArrows2');
            else
                Arrows = getappdata(hFig,'RegionArrows1');
            end
            otherArrow = Arrows(Index);
            arrow_size = otherArrow.LineWidth;  
            scale = 2.0;
            
            AllLinks = getappdata(hFig,'RegionLinks');
            Link = AllLinks(Index);
            link_size = Link.LineWidth;
            set(Link, 'LineWidth', 2.0*link_size);
        end
        
        set(src, 'LineWidth', scale*current_size);
        set(otherArrow, 'LineWidth', scale*arrow_size);       
    end
end

% return size back to original one after release mouse click
function ArrowClickEvent(hFig,ArrowIndex,LinkType,Node1Index,Node2Index)
    % measure links
    if (LinkType)
        MeasureLinks = getappdata(hFig,'MeasureLinks');
        Link = MeasureLinks(ArrowIndex);
        current_size = Link.LineWidth;
        set(Link, 'LineWidth', current_size/2.0);
        
        Arrows1 = getappdata(hFig,'MeasureArrows1');
        Arrows2 = getappdata(hFig,'MeasureArrows2');
        scale = 2.0;
        
    else % region links
        RegionLinks = getappdata(hFig,'RegionLinks');
        Link = RegionLinks(ArrowIndex);
        current_size = Link.LineWidth;     
        set(Link, 'LineWidth', current_size/2.0);  
        
        Arrows1 = getappdata(hFig,'RegionArrows1');
        Arrows2 = getappdata(hFig,'RegionArrows2');
        scale = 2.0;
    end
    
    arrow1 = Arrows1(ArrowIndex);
    arrow2 = Arrows2(ArrowIndex);
    
    arrow_size = arrow1.LineWidth;
    set(arrow1, 'LineWidth', arrow_size/scale);
    set(arrow2, 'LineWidth', arrow_size/scale);
    
    % put labels back to original font size 
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

%test callback function (for debugging purposes)
function Test(hFig)
	AllNodes = getappdata(hFig,'AllNodes');
	MeasureLinks = getappdata(hFig,'MeasureLinks');
	RegionLinks = getappdata(hFig,'RegionLinks');
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
    for i =1:2
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
 
function UpdateFigurePlot(hFig)
    % Progress bar
    bst_progress('start', 'Functional Connectivity Display', 'Updating figures...');
    % Get selected rows
    selNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
 
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

    %% ==== Re-Create and Display Links =======
    
    % Create new links from computed DataPair
    BuildLinks(hFig, DataPair, true);
    LinkSize = getappdata(hFig, 'LinkSize');
    SetLinkSize(hFig, LinkSize);
    SetLinkTransparency(hFig, 0.00);
    
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
    
    RefreshTitle(hFig);
    
    % Set background color
    SetBackgroundColor(hFig, GetBackgroundColor(hFig));
    % Update colormap
    UpdateColormap(hFig);
    % Redraw selected nodes
    SetSelectedNodes(hFig, selNodes, 1, 1);
    % Update panel
    panel_display('UpdatePanel', hFig);
    % 
    bst_progress('stop');
end

function SetDisplayNodeFilter(hFig, NodeIndex, IsVisible)
    % Update variable
    if (IsVisible == 0)
        IsVisible = -1;
    end
    DisplayNode = bst_figures('GetFigureHandleField', hFig, 'DisplayNode');
    DisplayNode(NodeIndex) = DisplayNode(NodeIndex) + IsVisible;
    bst_figures('SetFigureHandleField', hFig, 'DisplayNode', DisplayNode);
    % Update Visibility
    AllNodes = getappdata(hFig,'AllNodes');
    if (IsVisible <= 0)       
        Index = find(DisplayNode <= 0);
    else
        Index = find(DisplayNode > 0);
    end
    for i = 1:size(Index,1)
        if DisplayNode(Index(i))
            AllNodes(Index(i)).NodeMarker.Visible = 'on';
            AllNodes(Index(i)).TextLabel.Visible = 'on';
        else
            AllNodes(Index(i)).NodeMarker.Visible = 'off';
            AllNodes(Index(i)).TextLabel.Visible = 'off';
        end
    end
end
 
% Hides the extra lobe nodes at Level 3
function HideExtraLobeNode(hFig)
    DisplayInRegion = getappdata(hFig, 'DisplayInRegion');
    
    % hide all level 3 nodes (previous lobe nodes are in Level 2 already)
    if (DisplayInRegion)
        AllNodes = getappdata(hFig, 'AllNodes');
        Levels = bst_figures('GetFigureHandleField', hFig, 'Levels');
        Regions = Levels{3};
        for i = 1:length(Regions)
            AllNodes(Regions(i)).NodeMarker.Visible = 'off';
            AllNodes(Regions(i)).TextLabel.Visible = 'off';
        end
    end
end
 
%% ===== FILTERS =====
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
 
function mFunctionDataPair = ComputeRegionFunction(hFig, mDataPair, RegionFunction)
    Levels = bst_figures('GetFigureHandleField', hFig, 'Levels');
    Regions = Levels{2};
    NumberOfRegions = size(Regions,1);
    
    % Precomputing this saves on processing time
    NodesFromRegions = cell(NumberOfRegions,1);
    for i = 1:NumberOfRegions
        NodesFromRegions{i} = GetAgregatedNodesFrom(hFig, Regions(i));
    end   
    
    % Bidirectional data ?
    DisplayBidirectionalMeasure = getappdata(hFig, 'DisplayBidirectionalMeasure'); 
    if DisplayBidirectionalMeasure
        nPairs = NumberOfRegions*NumberOfRegions-NumberOfRegions;
    else
        nPairs = (NumberOfRegions*NumberOfRegions-NumberOfRegions) / 2;   
    end
    
    mFunctionDataPair = zeros(nPairs,3);   
    iFunction = 1;
    for i = 1:NumberOfRegions
        if DisplayBidirectionalMeasure
            yRange = 1 : NumberOfRegions;
            yRange(i) = []; % skip i == y
        else
            yRange = i + 1 : NumberOfRegions;
        end
        for y=yRange
            % Retrieve index
            if DisplayBidirectionalMeasure
                Index = ismember(mDataPair(:,1),NodesFromRegions{i}) & ismember(mDataPair(:,2),NodesFromRegions{y});
            else
                IndexItoY = ismember(mDataPair(:,1),NodesFromRegions{i}) & ismember(mDataPair(:,2),NodesFromRegions{y});
                IndexYtoI = ismember(mDataPair(:,1),NodesFromRegions{y}) & ismember(mDataPair(:,2),NodesFromRegions{i});
                Index = IndexItoY | IndexYtoI;
            end
            % If there is values
            if (sum(Index) > 0)
                switch(RegionFunction)
                    case 'max' 
                        Value = max(mDataPair(Index,3));
                    case 'mean'
                        Value = mean(mDataPair(Index,3));
                end
                mFunctionDataPair(iFunction, :) = [Regions(i) Regions(y) Value];
                iFunction = iFunction + 1;
            end
        end
    end
    % Eliminate empty data
    mFunctionDataPair(mFunctionDataPair(:,3) == 0,:) = [];
end
 
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
function UpdateColormap(hFig)
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
        % Linear interpolation
        [StartColor, EndColor] = InterpolateColorMap(hFig, DataPair(DataMask,:), CMap, CLim);
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
        if (IsDirectionalData)
            for i = 1:length(VisibleLinks)
                set(VisibleLinks(i), 'Color', [color_viz(i,:) LinkIntensity]); %link color and transparency
                set(VisibleArrows1(i), 'EdgeColor',color_viz(i,:), 'FaceColor', color_viz(i,:)); %arrow color
                set(VisibleArrows2(i), 'EdgeColor', color_viz(i,:), 'FaceColor', color_viz(i,:));
            end 
            %also set arrow transparency all at once
            set(VisibleArrows1, 'EdgeAlpha', LinkIntensity, 'FaceAlpha', LinkIntensity);
            set(VisibleArrows2, 'EdgeAlpha', LinkIntensity, 'FaceAlpha', LinkIntensity);
        else
            for i = 1:length(VisibleLinks)
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
                    set(MeasureArrows2(~bidirectional), 'Visible', 'off')
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
        if (IsDirectionalData)
            for i = 1:length(VisibleLinks_region)
                set(VisibleLinks_region(i), 'Color', [color_viz_region(i,:) LinkIntensity]); %link color and transparency
                set(VisibleArrows1(i), 'EdgeColor',color_viz_region(i,:), 'FaceColor', color_viz_region(i,:)); %arrow color
                set(VisibleArrows2(i), 'EdgeColor', color_viz_region(i,:), 'FaceColor', color_viz_region(i,:));
            end 
            %also set arrow transparency all at once
            set(VisibleArrows1, 'EdgeAlpha', LinkIntensity, 'FaceAlpha', LinkIntensity);
            set(VisibleArrows2, 'EdgeAlpha', LinkIntensity, 'FaceAlpha', LinkIntensity);
        else
            for i = 1:length(VisibleLinks_region)
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
 

function [StartColor EndColor] = InterpolateColorMap(hFig, DataPair, ColorMap, Limit)
    % Normalize and interpolate
    a = (DataPair(:,3)' - Limit(1)) / (Limit(2) - Limit(1));
    b = linspace(0,1,size(ColorMap,1));
    m = size(a,2);
    n = size(b,2);
    [~,p] = sort([a,b]);
    q = 1:m+n; q(p) = q;
    t = cumsum(p>m);
    r = 1:n; r(t(q(m+1:m+n))) = r;
    s = t(q(1:m));
    id = r(max(s,1));
    iu = r(min(s+1,n));
    [~,it] = min([abs(a-b(id));abs(b(iu)-a)]);
    StartColor = ColorMap(id+(it-1).*(iu-id),:);
    EndColor = ColorMap(id+(it-1).*(iu-id),:);
end

%% ======== RESET CAMERA DISPLAY ================
    % Resets camera position, target and view angle of the figure
function DefaultCamera(hFig)
    hFig.CurrentAxes.CameraViewAngle = 7;
    hFig.CurrentAxes.CameraPosition = [0 0 60];
    hFig.CurrentAxes.CameraTarget = [0 0 -2];
end
 
%% ======= ZOOM CAMERA =================
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
    % Move camera horizontally/vertically (from SHIFT+MOUSEMOVE) 
    % by applying X and Y translation to the CameraPosition and CameraTarget
    % ref: https://www.mathworks.com/help/matlab/ref/matlab.graphics.axis.axes-properties.html#budumk7-CameraTarget
function MoveCamera(hFig, Translation)
    hFig.CurrentAxes.CameraPosition = hFig.CurrentAxes.CameraPosition + Translation; 
    hFig.CurrentAxes.CameraTarget = hFig.CurrentAxes.CameraTarget + Translation;
end
 
%% ===========================================================================
%  ===== NODE DISPLAY AND SELECTION ==========================================
%  ===========================================================================
 
%% ===== SET SELECTED NODES =====
% USAGE:  SetSelectedNodes(hFig, iNodes=[], isSelected=1, isRedraw=1) : Add or remove nodes from the current selection
%         If node selection is empty: select/unselect all the nodes
function SetSelectedNodes(hFig, iNodes, isSelected, isRedraw)
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
   
    % REQUIRED: Display selected nodes ('ON' or 'OFF')
    for i = 1:length(iNodes)
        if isSelected
            SelectNode(hFig, AllNodes(iNodes(i)), true);
        else
            SelectNode(hFig, AllNodes(iNodes(i)), false);
        end
    end
    
    % Get data
    MeasureLinksIsVisible = getappdata(hFig, 'MeasureLinksIsVisible');
    
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
    
    % ==================== DISPLAY LINKS SELECTION ====================
    % Links are from valid node only
    ValidNode = find(bst_figures('GetFigureHandleField', hFig, 'ValidNode') > 0);
    ValidDataForDisplay = sum(ismember(DataToFilter(:,1:2), ValidNode),2);
    DataMask = DataMask == 1 & ValidDataForDisplay == 2;
 
    iData = find(DataMask == 1); % - 1;
 
    if (~isempty(iData))
        % Update link visibility
        % update arrow visibility (directional graph only)
        if (MeasureLinksIsVisible)
            MeasureLinks = getappdata(hFig,'MeasureLinks');
            
            if (isSelected)
                set(MeasureLinks(iData), 'Visible', 'on');
                if (IsDirectionalData)
                    MeasureArrows1 = getappdata(hFig, 'MeasureArrows1');
                    MeasureArrows2 = getappdata(hFig, 'MeasureArrows2');
                    set(MeasureArrows1(iData), 'Visible', 'on');
                    set(MeasureArrows2(iData), 'Visible', 'on');
                end
            else % make everything else invisible
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
                    RegionArrows2 = getappdata(hFig, 'RegionArrows2');
                    set(RegionArrows1(iData), 'Visible', 'on');
                    set(RegionArrows2(iData), 'Visible', 'off');
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
%show/hide region nodes (lobes + hem nodes) from display
%hidden nodes should not be clickable
%hidden nodes result in disabled options to show/hide text region labels 
%hidden nodes do not have region max/min options
function SetHierarchyNodeIsVisible(hFig, isVisible)
    HierarchyNodeIsVisible = getappdata(hFig, 'HierarchyNodeIsVisible');
    if (HierarchyNodeIsVisible ~= isVisible)
        % show/hide region nodes (lobes + hem nodes) from display
        AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
        SetDisplayNodeFilter(hFig, AgregatingNodes, isVisible);
        % rehide extra lobe nodes (level 3)
        HideExtraLobeNode(hFig);
        % Update variable
        setappdata(hFig, 'HierarchyNodeIsVisible', isVisible);
        %hidden nodes do not have region max/min options
        if(~isVisible && ~getappdata(hFig, 'MeasureLinksIsVisible'))
            ToggleMeasureToRegionDisplay(hFig);
        end           
    end
end
 
 
%% Create Region Mean/Max Links
function RegionDataPair = SetRegionFunction(hFig, RegionFunction)
    % Does data have regions to cluster ?
    DisplayInCircle = getappdata(hFig, 'DisplayInCircle');
    if (isempty(DisplayInCircle) || DisplayInCircle == 0)    
        % Get data
        DataPair = GetPairs(hFig);
        
        % Computes function across node pairs in region
        RegionDataPair = ComputeRegionFunction(hFig, DataPair, RegionFunction);
       
        % create region mean/max links from computed RegionDataPair
        BuildLinks(hFig, RegionDataPair, false); %Note: make sure to use isMeasureLink = false for this step

        % Update figure value
        bst_figures('SetFigureHandleField', hFig, 'RegionDataPair', RegionDataPair);
        setappdata(hFig, 'RegionFunction', RegionFunction);
        
        % Get selected node
        selNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
        % Erase selected node
        SetSelectedNodes(hFig, selNodes, 0, 1);
        % Redraw selected nodes
        SetSelectedNodes(hFig, selNodes, 1, 1);
        
        % Update color map
        UpdateColormap(hFig);
        
        % update size and transparency
        LinkSize = getappdata(hFig, 'LinkSize');
        SetLinkSize(hFig, LinkSize);
        if (isappdata(hFig,'LinkTransparency'))
            transparency = getappdata(hFig,'LinkTransparency');
        else
            transparency = 0;
        end
        SetLinkTransparency(hFig, transparency);
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
function SetTextDisplayMode(hFig, DisplayMode)
    disp("SetTextDisplayMode");
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
    HideExtraLobeNode(hFig);
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
    HideExtraLobeNode(hFig);
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

function NodeSize = GetNodeSize(hFig)
    NodeSize = getappdata(hFig, 'NodeSize');
    if isempty(NodeSize)
        NodeSize = 5; % default for 'on' is 5, default for off is '6'
    end
end
    
%% ===== LINK SIZE =====
function LinkSize = GetLinkSize(hFig)
    LinkSize = getappdata(hFig, 'LinkSize');
    if isempty(LinkSize)
        LinkSize = 1.5; % default
    end
end
 
function SetLinkSize(hFig, LinkSize)
    if isempty(LinkSize)
        LinkSize = 1.5; % default
    end

    if (isappdata(hFig,'MeasureLinks'))
        MeasureLinks = getappdata(hFig,'MeasureLinks');
        set(MeasureLinks, 'LineWidth', LinkSize);
    end
    
    if (isappdata(hFig,'MeasureArrows1'))
        MeasureArrows1 = getappdata(hFig,'MeasureArrows1');
        set(MeasureArrows1, 'LineWidth', LinkSize);
    end
    
    if (isappdata(hFig,'MeasureArrows2'))
        MeasureArrows2 = getappdata(hFig,'MeasureArrows2');
        set(MeasureArrows2, 'LineWidth', LinkSize);
    end
    
    if (isappdata(hFig,'RegionLinks'))
        RegionLinks = getappdata(hFig,'RegionLinks');
        set(RegionLinks, 'LineWidth', LinkSize);
    end
    
    if (isappdata(hFig,'RegionArrows1'))
        RegionArrows1 = getappdata(hFig,'RegionArrows1');
        set(RegionArrows1, 'LineWidth', LinkSize);
    end
    
    if (isappdata(hFig,'RegionArrows2'))
        RegionArrows2 = getappdata(hFig,'RegionArrows2');
        set(RegionArrows2, 'LineWidth', LinkSize);
    end
    % set new size
    setappdata(hFig, 'LinkSize', LinkSize);
end
 
%% ===== LINK TRANSPARENCY ===== 
function SetLinkTransparency(hFig, LinkTransparency)
    % Note: only need to update for "visible" links on graph (under the
    % thresholds selected) because when filters change, color +
    % transparency are updated in UpdateColormap
    
    % Note: update transparency for both measure and region links that are
    % "visible" because displayed links should reflect updated transparency if user toggles link type 
   
    if isempty(LinkTransparency)
        LinkTransparency = 0; % default
    end
    IsDirectionalData = getappdata(hFig, 'IsDirectionalData');
    
    % MeasureLinks
    if (isappdata(hFig,'MeasureLinks'))
        MeasureLinks = getappdata(hFig,'MeasureLinks');
            
        [~, DataMask] = GetPairs(hFig); 
        iData = find(DataMask == 1); % - 1;
    
        % set desired transparency to each link
        if (~isempty(iData))
            VisibleLinks = MeasureLinks(iData).';
            
            for i = 1:length(VisibleLinks)
                VisibleLinks(i).Color(4) = 1.00 - LinkTransparency;
            end
                
            if (IsDirectionalData)
                MeasureArrows1 = getappdata(hFig,'MeasureArrows1');
                MeasureArrows2 = getappdata(hFig,'MeasureArrows2');
                VisibleArrows1 = MeasureArrows1(iData).';
                VisibleArrows2 = MeasureArrows2(iData).';
                
                % Want line to be transparent when LinkTransparency = 100%,
                % but MALTAB object is transparent when FaceAlpha = 0
                % so do 1 - LinkTransparency
                set(VisibleArrows1, 'EdgeAlpha', 1.00 - LinkTransparency, 'FaceAlpha', 1.00 - LinkTransparency);
                set(VisibleArrows2, 'EdgeAlpha', 1.00 - LinkTransparency, 'FaceAlpha', 1.00 - LinkTransparency);
            end
        end
    end
    
    % RegionLinks
    if (isappdata(hFig,'RegionLinks'))
        RegionLinks = getappdata(hFig,'RegionLinks'); 
        [~, DataMask] = GetRegionPairs(hFig);
        iData = find(DataMask == 1);
        
        % set desired transparency to each link
        if (~isempty(iData))
            VisibleLinks = RegionLinks(iData).';
            
            for i = 1:length(VisibleLinks)
                VisibleLinks(i).Color(4) = 1.00 - LinkTransparency;
            end
                
            if (IsDirectionalData)
                RegionArrows1 = getappdata(hFig,'RegionArrows1');
                RegionArrows2 = getappdata(hFig,'RegionArrows2');
                VisibleArrows1 = RegionArrows1(iData).';
                VisibleArrows2 = RegionArrows2(iData).';
                
                set(VisibleArrows1, 'EdgeAlpha', 1.00 - LinkTransparency, 'FaceAlpha', 1.00 - LinkTransparency);
                set(VisibleArrows2, 'EdgeAlpha', 1.00 - LinkTransparency, 'FaceAlpha', 1.00 - LinkTransparency);
            end
        end
    end
    
    setappdata(hFig, 'LinkTransparency', LinkTransparency);
end
 
%% ===== BACKGROUND COLOR =====
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
                if ~isequal(AllNodes(i).TextLabel.Color,[0.5 0.5 0.5])
                    set(AllNodes(i).TextLabel,'Color', TextColor);
                end
            end
        end
    end
    
    setappdata(hFig, 'BgColor', BackgroundColor); %set app data for toggle
    UpdateContainer(hFig);
end
 
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
 
function SetDisplayMeasureMode(hFig, DisplayOutwardMeasure, DisplayInwardMeasure, DisplayBidirectionalMeasure, Refresh)
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
        if (length(Nodes) == nSelectedMeasureNodes)
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
        for i = 1:length(VisibleText)
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
function NodeIndex = GetAgregatedNodesFrom(hFig, AgregatingNodeIndex)
    NodeIndex = [];
    AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
    if ismember(AgregatingNodeIndex,AgregatingNodes)
        NodePaths = bst_figures('GetFigureHandleField', hFig, 'NodePaths');
        member = cellfun(@(x) ismember(AgregatingNodeIndex,x), NodePaths);
        NodeIndex = find(member == 1);
    end
end
 
 
%% ===== COMPUTING LINK PATH =====
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
 
%% ===== CREATE AND ADD NODES TO DISPLAY =====
function ClearAndAddNodes(hFig, V, Names)
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
        DeleteAllNodes(hFig);
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
   
    % Create nodes as an array of struct nodes (loop backwards to
    % pre-allocate nodes)
    for i = nVertices:-1:1
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
        for i = 1:length(RowColors)
            AllNodes(nAgregatingNodes+i).Color = RowColors(i,:);
            AllNodes(nAgregatingNodes+i).NodeMarker.Color = RowColors(i,:);
            AllNodes(nAgregatingNodes+i).NodeMarker.MarkerFaceColor = RowColors(i,:); % set marker fill color
        end 
    end
        
    setappdata(hFig, 'AllNodes', AllNodes); % Very important!
    
    % refresh display extent
    axis image; %fit display to all objects in image
    ax = hFig.CurrentAxes; %z-axis on default
    ax.Visible = 'off';
    
    % not currently used as user can adjust node size via slider
    FigureHasText = NumberOfMeasureNode <= 500;
    setappdata(hFig, 'FigureHasText', FigureHasText);    
end
 
%% Create A New Node with NodeMarker and TextLabel graphics objs
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
    % user adjust node size as desired
    nodeSize = GetNodeSize(hFig);    
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
end

% Callback Fn for clicked node label on figure
% NOTE: we use functions within NodeClickedEvent(), SetSelectedNodes(), and SelectNode() 
    % to set actual node and link selection display.      
    % All we need to do here is make sure that the correct index
    % of the clicked nodelabel is stored for access 
function LabelButtonDownFcn(src,~)
    global GlobalData;
    GlobalData.FigConnect.ClickedNodeIndex = src.UserData{1};
end

% Delete all node structs and associated graphics objs if exist
function DeleteAllNodes(hFig)
    AllNodes = getappdata(hFig,'AllNodes');
    
    % delete TextLabel Text Objects
    if isfield(AllNodes,'TextLabel')
        for i = 1:length(AllNodes)
            delete(AllNodes(i).TextLabel);
        end
    end

    % delete NodeMarker Line Objects
    if isfield(AllNodes,'NodeMarker')
        for i = 1:length(AllNodes)
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
 
%TODO: remove if unnecessary
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
    NumberOfGroups = 0;
    sGroups = repmat(struct('Name', [], 'RowNames', [], 'Region', {}), 0);
    NumberOfScouts = size(Atlas.Scouts,2);
    for i = 1:NumberOfScouts
        Region = Atlas.Scouts(i).Region;
        GroupID = find(strcmp({sGroups.Region},Region));
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
    for i = 2:NumberOfGroups
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
 
function [Vertices Paths Names] = OrganiseNodesWithConstantLobe(hFig, aNames, sGroups, RowLocs, UpdateStructureStatistics)
    % Display options
    MeasureLevel = 4;
    RegionLevel = 2.75;         % currently used as lobe nodes with region links
    LobeLevel = 2;              % hidden/invisible
    HemisphereLevel = 1.5;      % moved hem nodes outward (previously 1.0) 
    setappdata(hFig, 'MeasureLevelDistance', MeasureLevel);
    setappdata(hFig, 'RegionLevelDistance', RegionLevel);
    
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
    for i = 1:NumberOfLobes
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
    for i = 1:NumberOfLobes
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
                Names(RegionIndex) = {LobeTag}; % previously = {ExtractSubRegion(Region)};
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
    for i = 1:NumberOfLobes
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
                    [~, Order] = sort(RowLocs(ChannelsOfThisGroup,1), 'descend');
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
                Names(RegionIndex) = {LobeTag}; % previously = {ExtractSubRegion(Region)};
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
                    [~, Order] = sort(RowLocs(ChannelsOfThisGroup,1), 'descend');
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
                    [~, Order] = sort(RowLocs(ChannelsOfThisGroup,1), 'descend');
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
    for i = 1:NumberOfGroups
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
        
    for i = 1:NumberOfGroups
        LocalTheta = linspace(GroupsTheta(i,1), GroupsTheta(i,2), NumberOfNodesInGroup(i) + 1);
        ChannelsOfThisGroup = ismember(aNames, sGroups(i).RowNames);
        Index = find(ChannelsOfThisGroup) + NumberOfAgregatingNodes;
        [posX,posY] = pol2cart(LocalTheta(2:end),1);
        Vertices(Index,1:2) = [posX' posY'] * MeasureLevel;
        Names(Index) = sGroups(i).RowNames;
        Paths(Index) = mat2cell([Index ones(size(Index))], ones(1,size(Index,1)), 2);
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