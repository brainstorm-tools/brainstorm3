function varargout = figure_connect( varargin )
% FIGURE_CONNECT: Creation and callbacks for connectivity figures.
%
% USAGE:  hFig = figure_connect('CreateFigure', FigureId)
 
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
% Authors: Sebastien Dery, 2013           (initial JOGL rendering)
%          Francois Tadel, 2013-2022
%          Martin Cousineau, 2019-2021
%          Helen Lin & Yaqi Li, 2020-2021 (new Matlab rendering)

eval(macro_method);
end
 
%% ===== CREATE FIGURE =====
function hFig = CreateFigure(FigureId) %#ok<DEFNU>
    hFig = figure('Visible',               'off', ...
                  'NumberTitle',           'off', ...
                  'IntegerHandle',         'off', ...
                  'MenuBar',               'none', ...
                  'Toolbar',               'none', ...
                  'DockControls',          'off', ...
                  'Units',                 'pixels', ...
                  'Color',                 [0 0 0], ...
                  'Pointer',               'arrow', ...
                  'BusyAction',            'queue', ...
                  'Interruptible',         'off', ...
                  'HitTest',               'on', ...
                  'Tag',                   FigureId.Type, ...
                  'CloseRequestFcn',       @(h, ev)bst_figures('DeleteFigure', h, ev), ...
                  'KeyPressFcn',           @(h, ev)bst_call(@FigureKeyPressedCallback, h, ev), ...
                  'KeyReleaseFcn',         @(h, ev)bst_call(@FigureKeyReleasedCallback, h, ev), ...
                  'WindowButtonDownFcn',   @FigureMouseDownCallback, ...
                  'WindowButtonMotionFcn', @FigureMouseMoveCallback, ...
                  'WindowButtonUpFcn',     @FigureMouseUpCallback, ...
                  'WindowScrollWheelFcn',  @(h, ev)FigureMouseWheelCallback(h, ev), ...
                  bst_get('ResizeFunction'), @(h, ev)ResizeCallback(h, ev));
    
    % === CREATE AXES ===
    hAxes = axes('Parent',        hFig, ...
                 'Units',         'normalized', ...
                 'Position',      [.1 .1 .8 .8], ...
                 'Tag',           'AxesConnect', ...
                 'Visible',       'off', ...
                 'BusyAction',    'queue', ...
                 'Interruptible', 'off');

    % === APPDATA STRUCTURE ===
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
    setappdata(hFig, 'MeasureLinksIsVisible', 1);
    setappdata(hFig, 'RegionLinksIsVisible', 0);
    setappdata(hFig, 'RegionFunction', 'mean');    
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

%% ===== RESET DISPLAY =====
function ResetDisplay(hFig)
    % Default values
    setappdata(hFig, 'DisplayOutwardMeasure', 1);
    setappdata(hFig, 'DisplayInwardMeasure', 0);
    setappdata(hFig, 'DisplayBidirectionalMeasure', 0);
    setappdata(hFig, 'DataThreshold', 0.5);
    setappdata(hFig, 'DistanceThreshold', 0);
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
    if (~isequal(getappdata(hFig, 'TextDisplayMode'), [1 2]))
        setappdata(hFig, 'TextDisplayMode', [1 2]);
        RefreshTextDisplay(hFig);
    end
    % reset node+label size
    if (getappdata(hFig, 'NodeSize') ~= 5 || getappdata(hFig, 'LabelSize') ~= 7)
        SetNodeLabelSize(hFig, 5, 7);
    end
    % reset link size
    if (getappdata(hFig, 'LinkSize') ~= 1.5)
        SetLinkSize(hFig, 1.5);
    end
    % reset to black background
    if (~isequal(getappdata(hFig, 'BgColor'), [0 0 0]))
        SetBackgroundColor(hFig, [0 0 0]);
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
    elseif(~isequal(getappdata(hFig, 'TextDisplayMode'), [1 2]))
        IsDefault = false;
    % check node+label size
    elseif (getappdata(hFig, 'NodeSize') ~= 5 || getappdata(hFig, 'LabelSize') ~= 7) 
        IsDefault = false;
    % check link size
    elseif (getappdata(hFig, 'LinkSize') ~= 1.5)
        IsDefault = false;
    % check black background
    elseif (~isequal(getappdata(hFig, 'BgColor'), [0 0 0]))
        IsDefault = false;
    % check region nodes (hem and lobes) NOT hidden
    elseif (~getappdata(hFig, 'HierarchyNodeIsVisible'))
    	IsDefault = false;
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
    colorbarWidth = bsxfun(@times, 15, Scaling); % replaced .* with bsxfun for back compatibility
    marginTop     = bsxfun(@times, 10, Scaling);
    marginRight   = bsxfun(@times, 55, Scaling);
    marginBottom  = bsxfun(@times, 40, Scaling);
    % Reposition the colorbar
    if ~isempty(hColorbar)
        % Reposition the colorbar
        set(hColorbar, 'Units',    'pixels', ...
                       'Position', [figPos(3) - marginRight, ...
                                    marginBottom, ...
                                    colorbarWidth, ...
                                    max(1, figPos(4) - marginTop - marginBottom)]);
        uistack(hColorbar, 'top', 1);
    end
end
 
function HasTitle = RefreshTitle(hFig)
    Title = [];
    DisplayInRegion = getappdata(hFig, 'DisplayInRegion');
    if (DisplayInRegion)
        % Label 
        hTitle = getappdata(hFig, 'TitlesHandle');
        % If data are hierarchicaly organised and we are not already at the whole cortical view
        for i = 1:size(hTitle, 2)
            delete(hTitle(i));
        end
        hTitle = [];       
        setappdata(hFig, 'TitlesHandle', hTitle);
        UpdateContainer(hFig);
    end    
    HasTitle = size(Title, 2) > 0;
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
    if isappdata(hFig, 'clickAction') && strcmpi(getappdata(hFig, 'clickAction'), 'MouseDownNotConsumed')
        return;
    end   
    % click from Matlab figure
    if ~isempty(ev)
        if strcmpi(get(hFig, 'SelectionType'), 'alt') % right-click or CTRL+Click
            clickAction = 'popup';
        elseif strcmpi(get(hFig, 'SelectionType'), 'open') % double-click
            clickAction = 'ResetCamera';
        elseif strcmpi(get(hFig, 'SelectionType'), 'extend') % SHIFT or middle button is held
            if (getappdata(hFig, 'ShiftPressed'))
                clickAction = 'ShiftClick'; % POTENTIAL node click or mousemovecamera
            else
                clickAction = 'pan';
            end
        else % normal click
            clickAction = 'SingleClick'; % POTENTIAL node/link click
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
        case 'pan'
            motion = -motionFigure * 0.05;
            MoveCamera(hFig, [motion(1) motion(2) 0]);
    end
end
 
%% ===== FIGURE MOUSE UP CALLBACK =====
% This function applies certain triggered events from mouse clicks/movements
    % Left click on a node: select/deselect nodes
    % Right click: popup menu
    % Double click: reset camera
function FigureMouseUpCallback(hFig, varargin)

    % Get index of potentially clicked node, link or arrowhead
    global GlobalData;
    NodeIndex = GlobalData.FigConnect.ClickedNodeIndex; 
    LinkIndex = GlobalData.FigConnect.ClickedLinkIndex; 
    ArrowIndex = GlobalData.FigConnect.ClickedArrowIndex; 
    Node1 = GlobalData.FigConnect.ClickedNode1Index;
    Node2 = GlobalData.FigConnect.ClickedNode2Index;
    % clear stored IDs
    GlobalData.FigConnect.ClickedNodeIndex = 0; 
    GlobalData.FigConnect.ClickedLinkIndex = 0; 
    GlobalData.FigConnect.ClickedArrowIndex = 0; 
    GlobalData.FigConnect.ClickedNode1Index = 0;    
    GlobalData.FigConnect.ClickedNode2Index = 0;
    
    % Get application data + current user/mouse actions
    LinkType = getappdata(hFig, 'MeasureLinksIsVisible');
    IsDirectional = getappdata(hFig, 'IsDirectionalData');
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
            if (NodeIndex > 0)
                NodeClickEvent(hFig, NodeIndex);
            end
            
            % left mouse click on a link
            if (strcmpi(clickAction, 'SingleClick'))        
                if (LinkIndex > 0)
                    LinkClickEvent(hFig, LinkIndex, LinkType, IsDirectional, Node1, Node2);
                end
                if (ArrowIndex > 0)
                    ArrowClickEvent(hFig, ArrowIndex, LinkType, Node1, Node2);
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
            if (LinkIndex > 0)
                LinkClickEvent(hFig, LinkIndex, LinkType, IsDirectional, Node1, Node2);
            end
            if (ArrowIndex > 0)
                ArrowClickEvent(hFig, ArrowIndex, LinkType, Node1, Node2);
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
        % ---NODE SELECTIONS---
        case 'a'            % Select All Nodes
            bst_progress('start', 'Functional Connectivity Display', 'Updating figures...');
            SetSelectedNodes(hFig, [], 1);
            UpdateColormap(hFig);
            RefreshTextDisplay(hFig);
            bst_progress('stop');
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
        case 'b'            
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
            SetHierarchyNodeIsVisible(hFig, ~getappdata(hFig, 'HierarchyNodeIsVisible'));
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
    % DisplayNode = find(bst_figures('GetFigureHandleField', hFig, 'DisplayNode'));
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
    
    for i = 1:size(Levels, 1) 
        if (~ismember(i, skip))
            CircularIndex = [CircularIndex; Levels{i}];
        end
    end
    
    % comment out to allow toggling even when region nodes are hidden
    % CircularIndex(~ismember(CircularIndex, DisplayNode)) = []; 
    
    if isempty(Node)
        NextIndex = 1;
    else
        % Find index
        NextIndex = find(CircularIndex(:) == Node) + Inc;
        nIndex = size(CircularIndex, 1);
        if (NextIndex > nIndex)
            NextIndex = 1;
        elseif (NextIndex < 1)
            NextIndex = nIndex;
        end
    end
    NextNode = CircularIndex(NextIndex);
end

function SelectAllNodes(hFig)
    bst_progress('start', 'Functional Connectivity Display', 'Updating figures...');
    SetSelectedNodes(hFig, [], 1);
    UpdateColormap(hFig);
    bst_progress('stop');
end

function ToggleRegionSelection(hFig, Inc)
    bst_progress('start', 'Functional Connectivity Display', 'Updating figures...');
    % Get selected nodes
    SelNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
    % Get number of AgregatingNode
    AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
    
    if (isempty(SelNodes))
        % Get first node
        NextNode = GetNextCircularRegion(hFig, [], Inc);
    else
        % Remove previous links
        SetSelectedNodes(hFig, SelNodes, 0); 
        % Remove agregating node from selection
        SelectedNode = SelNodes(1);
       
        NextNode = GetNextCircularRegion(hFig, SelectedNode, Inc);
        UpdateColormap(hFig);
    end

    % Is the next node an agregating node?
    IsAgregatingNode = ismember(NextNode, AgregatingNodes);
    if (IsAgregatingNode)
        % Get agregated nodes
        AgregatedNodeIndices = GetAgregatedNodesFrom(hFig, NextNode); 
        if (~isempty(AgregatedNodeIndices))
            % Select all nodes associated to NextNode
            SetSelectedNodes(hFig, AgregatedNodeIndices, 1);
            UpdateColormap(hFig);
        end    
    else
        % Select next node
        SetSelectedNodes(hFig, NextNode, 1);
        UpdateColormap(hFig);
    end
    RefreshTextDisplay(hFig);
    bst_progress('stop');
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
    
    bst_progress('start', 'Functional Connectivity Display', 'Updating figures...');
    
    DisplayNode = bst_figures('GetFigureHandleField', hFig, 'DisplayNode');
    if (DisplayNode(NodeIndex) == 1)
        % 1. GET NODE SETS AND PROPERTIES
        SelNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
        MeasureNodes    = bst_figures('GetFigureHandleField', hFig, 'MeasureNodes');
        AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
        % Is the node already selected ?
        AlreadySelected = any(SelNodes == NodeIndex);
        % Is the node an agregating node ?
        IsAgregatingNode = any(AgregatingNodes == NodeIndex);

        % 2. IF NODE IS ALREADY SELECTED, TOGGLE IT
        if AlreadySelected
            % If all nodes are already selected
            if all(ismember(MeasureNodes, SelNodes))  
                % then we want to select only this new one
                SetSelectedNodes(hFig, [], 0); % first unselect all nodes
                AlreadySelected = 0;
                UpdateColormap(hFig); % required for directional graphs with arrowheads!!

            % If it's the only already selected node, select all and return
            elseif (length(SelNodes) == 1)
                SetSelectedNodes(hFig, [], 1); 
                UpdateColormap(hFig);
                RefreshTextDisplay(hFig);
                bst_progress('stop');
                return;
            end

            % Agregative nodes: select blocks of nodes
            if IsAgregatingNode
                % Get agregated nodes
                AgregatedNodeIndex = GetAgregatedNodesFrom(hFig, NodeIndex);
                % How many are already selected
                NodeAlreadySelected = ismember(AgregatedNodeIndex, SelNodes);

                % If the agregating node and this measure node are
                % the only selected nodes, then select all and return
                if (sum(NodeAlreadySelected) == size(SelNodes, 1))
                    SetSelectedNodes(hFig, [], 1);
                    UpdateColormap(hFig);
                    RefreshTextDisplay(hFig);
                    bst_progress('stop');
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
        IsShift = getappdata(hFig, 'ShiftPressed');
        if (isempty(IsShift) || ~IsShift)
            SetSelectedNodes(hFig, SelNodes, 0); % Deselect all
            Select = 1; % Select picked node
            UpdateColormap(hFig);
        end

        % 4. APPLY DE/SELECTIONS
        if (IsAgregatingNode)
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
    
    RefreshTextDisplay(hFig);
    bst_progress('stop');
end

%%
function UpdateHierarchySelection(hFig, NodeIndex, Select)
    % Incorrect data
    if (size(NodeIndex, 1) > 1 || isempty(NodeIndex ))
        return
    end
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
    if (size(AgregatedNodesIndex, 1) == sum(ismember(AgregatedNodesIndex, selNodes)))
        SetSelectedNodes(hFig, AgregatingNode, Select);
        UpdateHierarchySelection(hFig, AgregatingNode, Select);
    end
end
 
%% =====  ZOOM CALLBACK USING MOUSEWHEEL =========
function FigureMouseWheelCallback(hFig, ev)
    if isempty(ev)
        return;
    elseif (ev.VerticalScrollCount < 0) % ZOOM OUT
        Factor = 1./(1 - double(ev.VerticalScrollCount) ./ 20);
    elseif (ev.VerticalScrollCount > 0) % ZOOM IN
         Factor = 1 + double(ev.VerticalScrollCount) ./ 20;
    else
        Factor = 1;
    end
    ZoomCamera(hFig, Factor);
end
  
%% ===== POPUP MENU V1: Display Options menu with no sub-menus=====
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
    % Get current properties
    DisplayInRegion = getappdata(hFig, 'DisplayInRegion');
    TextDisplayMode = getappdata(hFig, 'TextDisplayMode');
    % Create popup menu
    jPopup = java_create('javax.swing.JPopupMenu');
    
    % ==== MENU: COLORMAP =====
    bst_colormaps('CreateAllMenus', jPopup, hFig, 0);
    
    % ==== GRAPH OPTIONS ====
    jPopup.addSeparator();
    jGraphMenu = gui_component('Menu', jPopup, [], 'Graph options', IconLoader.ICON_CONNECTN);
        % === SELECT ALL THE NODES ===
        jItem = gui_component('MenuItem', jGraphMenu, [], 'Select all', [], [], @(h, n, s, r)SelectAllNodes(hFig));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_A, 0));
        % === SELECT NEXT REGION ===
        jItem = gui_component('MenuItem', jGraphMenu, [], 'Select next region', [], [], @(h, ev)ToggleRegionSelection(hFig, -1));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_RIGHT, 0));
        % === SELECT PREVIOUS REGION===
        jItem = gui_component('MenuItem', jGraphMenu, [], 'Select previous region', [], [], @(h, ev)ToggleRegionSelection(hFig, 1));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_LEFT, 0));
        jGraphMenu.addSeparator();
        
        % === TOGGLE LABELS ===
        % Measure (outer) node labels
        jItem = gui_component('CheckBoxMenuItem', jGraphMenu, [], 'Show labels', [], [], @(h, ev)SetTextDisplayMode(hFig, 1));
        jItem.setSelected(ismember(1, TextDisplayMode));
        % Selected Nodes' labels only
        jItem = gui_component('CheckBoxMenuItem', jGraphMenu, [], 'Show labels for selection', [], [], @(h, ev)SetTextDisplayMode(hFig, 3));
        jItem.setSelected(ismember(3, TextDisplayMode));
        jGraphMenu.addSeparator();
        
        % === SLIDERS ===
        if (bst_get('MatlabVersion') >= 705) % Check Matlab version: Works only for R2007b and newer
            % === MODIFY NODE AND LINK SIZE ===
            jPanelModifiers = gui_river([0 0], [0, 31, 0, 0]);
            NodeSize = getappdata(hFig, 'NodeSize');
            % Label
            gui_component('label', jPanelModifiers, '', 'Label size:');
            % Slider
            jSliderContrast = JSlider(5, 25); % uses factor of 2 for node sizes 2.5 to 12.5 with increments of 0.5 in actuality
            jSliderContrast.setValue(round(NodeSize * 2));
            jSliderContrast.setPreferredSize(java_scaled('dimension', 100, 23));
            jSliderContrast.setFocusable(0);
            jSliderContrast.setOpaque(0);
            jPanelModifiers.add('tab hfill', jSliderContrast);
            % Value (text)
            jLabelContrast = gui_component('label', jPanelModifiers, '', sprintf('%.0f', round(NodeSize * 2)));
            jLabelContrast.setPreferredSize(java_scaled('dimension', 50, 23));
            jLabelContrast.setHorizontalAlignment(JLabel.LEFT);
            jPanelModifiers.add(jLabelContrast);
            % Slider callbacks
            java_setcb(jSliderContrast.getModel(), 'StateChangedCallback', @(h, ev)NodeLabelSizeSliderCallback(hFig, ev, jLabelContrast));

            % == MODIFY LINK SIZE ==
            LinkSize = getappdata(hFig, 'LinkSize');
            % Label
            gui_component('label', jPanelModifiers, 'br', 'Link size:');
            % Slider
            jSliderContrast = JSlider(1, 20); % uses factor of 2 for link sizes 0.5 to 10.0 with increments of 0.5 in actuality
            jSliderContrast.setValue(round(LinkSize * 2));
            jSliderContrast.setPreferredSize(java_scaled('dimension', 100, 23));
            jSliderContrast.setFocusable(0);
            jSliderContrast.setOpaque(0);
            jPanelModifiers.add('tab hfill', jSliderContrast);
            % Value (text)
            jLabelContrast = gui_component('label', jPanelModifiers, '', sprintf('%.0f', round(LinkSize * 2)));
            jLabelContrast.setPreferredSize(java_scaled('dimension', 50, 23));
            jLabelContrast.setHorizontalAlignment(JLabel.LEFT);
            jPanelModifiers.add(jLabelContrast);
            % Slider callbacks
            java_setcb(jSliderContrast.getModel(), 'StateChangedCallback', @(h, ev)LinkSizeSliderCallback(hFig, ev, jLabelContrast));
            jGraphMenu.add(jPanelModifiers);
            jGraphMenu.addSeparator();
        end
        
        % === REGIONS ===
        if (DisplayInRegion)
            jMenuRegion = gui_component('Menu', jGraphMenu, [], 'Regions / lobes');
            % Show region nodes
            HierarchyNodeIsVisible = getappdata(hFig, 'HierarchyNodeIsVisible');
            jItem = gui_component('CheckBoxMenuItem', jMenuRegion, [], 'Show regions', [], [], @(h, ev)SetHierarchyNodeIsVisible(hFig, ~HierarchyNodeIsVisible));
            jItem.setSelected(HierarchyNodeIsVisible);
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_H, 0));
            % Show region labels
            jItem = gui_component('CheckBoxMenuItem', jMenuRegion, [], 'Show region labels', [], [], @(h, ev)SetTextDisplayMode(hFig, 2));
            isShowRegionLabel = ismember(2, TextDisplayMode);
            jItem.setSelected(isShowRegionLabel);
            jItem.setEnabled(getappdata(hFig, 'HierarchyNodeIsVisible'));
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_L,0));
            % Label abbreviations
            jItem = gui_component('CheckBoxMenuItem', jMenuRegion, [], 'Abbreviate region labels', [], [], @(h, ev)ToggleLobeLabels(hFig));
            jItem.setSelected(~getappdata(hFig, 'LobeFullLabel'));
            jItem.setEnabled(getappdata(hFig, 'HierarchyNodeIsVisible') && isShowRegionLabel);
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_L,0));
            jMenuRegion.addSeparator();
            % Display region mean/max
            RegionLinksIsVisible = getappdata(hFig, 'RegionLinksIsVisible');
            RegionFunction = getappdata(hFig, 'RegionFunction');
            jItem = gui_component('CheckBoxMenuItem', jMenuRegion, [], ['Display region ' RegionFunction], [], [], @(h, ev)ToggleMeasureToRegionDisplay(hFig));
            jItem.setSelected(RegionLinksIsVisible);
            jItem.setEnabled(HierarchyNodeIsVisible);
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_M, 0));
            % Set region function
            IsMean = strcmp(RegionFunction, 'mean');
            jLabelMenu = gui_component('Menu', jMenuRegion, [], 'Choose region function');
            jLabelMenu.setEnabled(HierarchyNodeIsVisible);
                jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Mean', [], [], @(h, ev)SetRegionFunction(hFig, 'mean'));
                jItem.setSelected(IsMean);
                jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Max', [], [], @(h, ev)SetRegionFunction(hFig, 'max'));
                jItem.setSelected(~IsMean);
            jGraphMenu.addSeparator();
        end
        % === DEFAULT/RESET ===
        jItem = gui_component('MenuItem', jGraphMenu, [], 'Reset display options', [], [], @(h, ev)ResetDisplayOptions(hFig));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_R, 0));
        jItem.setEnabled(~CheckDisplayOptions(hFig));
    
    % ==== MENU: SNAPSHOT ====
    jPopup.addSeparator();
    jMenuSave = gui_component('Menu', jPopup, [], 'Snapshot', IconLoader.ICON_SNAPSHOT);
        % === SAVE AS IMAGE ===
        jItem = gui_component('MenuItem', jMenuSave, [], 'Save as image', IconLoader.ICON_SAVE, [], @(h, ev)bst_call(@out_figure_image, hFig));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_I, KeyEvent.CTRL_MASK));
        % === OPEN AS IMAGE ===
        jItem = gui_component('MenuItem', jMenuSave, [], 'Open as image', IconLoader.ICON_IMAGE, [], @(h, ev)bst_call(@out_figure_image, hFig, 'Viewer'));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_J, KeyEvent.CTRL_MASK));       
    jPopup.add(jMenuSave);
    
    % ==== MENU: FIGURE (copied from figure_3D.m ====
    jMenuFigure = gui_component('Menu', jPopup, [], 'Figure', IconLoader.ICON_LAYOUT_SHOWALL);
        % Change background color
        BackgroundColor = getappdata(hFig, 'BgColor');
        IsWhite = all(BackgroundColor == [1 1 1]);
        jItem = gui_component('CheckBoxMenuItem', jMenuFigure, [], 'White background', [], [], @(h, ev)ToggleBackground(hFig));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_B, 0));
        jItem.setSelected(IsWhite);
        jMenuFigure.addSeparator();
        % Show Matlab controls
        isMatlabCtrl = ~strcmpi(get(hFig, 'MenuBar'), 'none') && ~strcmpi(get(hFig, 'ToolBar'), 'none');
        jItem = gui_component('CheckBoxMenuItem', jMenuFigure, [], 'Matlab controls', IconLoader.ICON_MATLAB_CONTROLS, [], @(h,ev)bst_figures('ShowMatlabControls', hFig, ~isMatlabCtrl));
        jItem.setSelected(isMatlabCtrl);
        % Show plot edit toolbar
        isPlotEditToolbar = getappdata(hFig, 'isPlotEditToolbar');
        jItem = gui_component('CheckBoxMenuItem', jMenuFigure, [], 'Plot edit toolbar', IconLoader.ICON_PLOTEDIT, [], @(h,ev)bst_figures('TogglePlotEditToolbar', hFig));
        jItem.setSelected(isPlotEditToolbar);
        % Dock figure
        isDocked = strcmpi(get(hFig, 'WindowStyle'), 'docked');
        jItem = gui_component('CheckBoxMenuItem', jMenuFigure, [], 'Dock figure', IconLoader.ICON_DOCK, [], @(h,ev)bst_figures('DockFigure', hFig, ~isDocked));
        jItem.setSelected(isDocked);
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_D, KeyEvent.CTRL_MASK)); 
        % CLONE FIGURE
        jMenuFigure.addSeparator();
        gui_component('MenuItem', jMenuFigure, [], 'Clone figure', [], [], @(h,ev)bst_figures('CloneFigure', hFig));


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
 
% Link size slider
function LinkSizeSliderCallback(hFig, ev, jLabel)
    % Update Modifier value
    LinkSize = ev.getSource().getValue() / 2;
    % Update text value
    jLabel.setText(sprintf('%.0f', LinkSize * 2));
    SetLinkSize(hFig, LinkSize);
end

%% ===========================================================================
%  ===== PLOT FUNCTIONS ======================================================
%  ===========================================================================
 
%% ===== GET FIGURE DATA =====
function [Time, Freqs, TfInfo, TF, RowNames, DataType, Method, FullTimeVector, isStat] = GetFigureData(hFig)
    global GlobalData;
    % Initialize returned variables
    Time = [];
    Freqs = [];
    TfInfo = [];
    TF = [];
    RowNames = [];
    DataType = [];
    Method = [];
    FullTimeVector = [];
    isStat = [];


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
    % Stat results?
    isStat = strcmpi(file_gettype(TfInfo.FileName), 'ptimefreq');
    
    % ===== GET TIME =====
    [Time, iTime] = bst_memory('GetTimeVector', iDS, [], 'CurrentTimeIndex');
    Time = Time(iTime);
    FullTimeVector = Time;
    % If it is a static figure: keep only the first and last times
    if getappdata(hFig, 'isStatic')
        Time = Time([1, end]);
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
           if (size(Freqs, 1) ~= 1)
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
            Time = GlobalData.DataSet(iDS).Timefreq(iTimefreq).TimeBands(iTimeBands, :);
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
 
function [DataPair, isStat] = LoadConnectivityData(hFig, Options)
    % Parse input
    if (nargin < 2)
        Options = struct();
    end
    % Maximum number of data allowed
    MaximumNumberOfData = 5000;
   
    % === GET DATA ===
    [~, ~, ~, M, ~, ~, ~, ~, isStat] = GetFigureData(hFig);

    % Compute values for all percentiles (for thresholding by percentile)
    ThresholdAbsoluteValue = getappdata(hFig, 'ThresholdAbsoluteValue');
    if ThresholdAbsoluteValue
        Percentiles = bst_prctile(abs(M(:)), 0.1:0.1:99.9);
    else
        Percentiles = bst_prctile(M(:), 0.1:0.1:99.9);
    end

    % Zero-out the diagonal because its useless
    M = M - diag(diag(M));
    
    % If the matrix is symetric and Not directional
    if (isequal(M, M') && ~IsDirectionalData(hFig))
        % We don't need the upper half
        for i = 1:size(M, 1)
            M(i, i:end) = 0;
        end
    end
    
    % === THRESHOLD ===
    if ~isStat && ((size(M, 1) * size(M, 2)) > MaximumNumberOfData)
        % Validity mask
        Valid = ones(size(M));
        Valid(M == 0) = 0;
        Valid(diag(ones(size(M)))) = 0;
        
        % === ZERO-OUT LOWEST VALUES ===
        if isfield(Options, 'Highest') && Options.Highest
            % Retrieve min/max
            DataMinMax = [min(M(:)), max(M(:))];
            % Keep highest values only
            if (DataMinMax(1) >= 0)
                [~, ~, s] = find(M(Valid == 1));
                B = sort(s, 'descend');
                if length(B) > MaximumNumberOfData
                    t = B(MaximumNumberOfData);
                    Valid = Valid & (M >= t);
                end
            else
                [~, ~, s] = find(M(Valid == 1));
                B = sort(abs(s), 'descend');
                if length(B) > MaximumNumberOfData
                    t = B(MaximumNumberOfData);
                    Valid = Valid & ((M <= -t) | (M >= t));
                end
            end
        end
        M(~Valid) = 0;
    end
 
    % Convert matrix to data pair 
    DataPair = MatrixToDataPair(hFig, M);
    fprintf('%.0f Connectivity measure loaded\n', size(DataPair, 1));
 
    % ===== MATRIX STATISTICS ===== 
    DataMinMax = [min(DataPair(:, 3)), max(DataPair(:, 3))];
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
    bst_figures('SetFigureHandleField', hFig, 'DataPair', DataPair);
    bst_figures('SetFigureHandleField', hFig, 'Percentiles', Percentiles);
    % Clear memory
    clear M;
end
 
function aDataPair = MatrixToDataPair(hFig, mMatrix)
    % Reshape
    [i, j, s] = find(mMatrix);
    i = i';
    j = j';
    mMatrix = reshape([i;j], 1, []);
    % Convert to datapair structure
    aDataPair = zeros(size(mMatrix, 2)/2, 3);
    aDataPair(1:size(mMatrix, 2)/2, 1) = mMatrix(1:2:size(mMatrix, 2));
    aDataPair(1:size(mMatrix, 2)/2, 2) = mMatrix(2:2:size(mMatrix, 2));
    aDataPair(1:size(mMatrix, 2)/2, 3) = s(:);
    % Add offset
    nAgregatingNode = size(bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes'), 2);
    aDataPair(:, 1:2) = aDataPair(:, 1:2) + nAgregatingNode;
end
 
%% ===== UPDATE FIGURE PLOT =====
% Creates and loads base figure including nodes, links and default params
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
            SelChan = zeros(1, length(RowNames));
            for iRow = 1:length(RowNames)
                % Get indice in the 
                SelChan(iRow) = find(strcmpi({GlobalData.DataSet(iDS).Channel.Name}, RowNames{iRow}));
            end
            RowLocs = figure_3d('GetChannelPositions', iDS, SelChan);
 
        case {'results', 'matrix'}
            % Get the file information file
            SurfaceFile = GlobalData.DataSet(iDS).Timefreq(iTimefreq).SurfaceFile;
            Atlas       = GlobalData.DataSet(iDS).Timefreq(iTimefreq).Atlas;
            if ~isempty(Atlas)
                isVolumeAtlas = panel_scout('ParseVolumeAtlas', Atlas.Name);
            else
                isVolumeAtlas = 0;
            end
            % Load surface
            if ~isempty(SurfaceFile) && ischar(SurfaceFile)
                SurfaceMat = in_tess_bst(SurfaceFile);
                if ~isVolumeAtlas
                    Vertices = SurfaceMat.Vertices;
                else
                    Vertices = GlobalData.DataSet(iDS).Timefreq(iTimefreq).GridLoc;
                end
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
        RowNames = cellstr(num2str((1:size(Vertices, 1))'));
    end
    % Ensure proper alignment
    if (size(RowNames, 2) > size(RowNames, 1))
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
    bst_figures('SetFigureHandleField', hFig, 'NumberOfNodes', size(Vertices, 1));
    bst_figures('SetFigureHandleField', hFig, 'Vertices', Vertices);
    bst_figures('SetFigureHandleField', hFig, 'NodePaths', Paths);
    bst_figures('SetFigureHandleField', hFig, 'Names', Names);
    bst_figures('SetFigureHandleField', hFig, 'DisplayNode', ones(size(Vertices, 1), 1));
    bst_figures('SetFigureHandleField', hFig, 'ValidNode', ones(size(Vertices, 1), 1));
    
    %% ===== User Display Preferences =====
    % Get saved preferences
    DispOptions = bst_get('ConnectGraphOptions');
    setappdata(hFig, 'LobeFullLabel', DispOptions.LobeFullLabel);
    setappdata(hFig, 'TextDisplayMode', DispOptions.TextDisplayMode);
    setappdata(hFig, 'NodeSize', DispOptions.NodeSize);
    setappdata(hFig, 'LabelSize', DispOptions.LabelSize);
    setappdata(hFig, 'LinkSize', DispOptions.LinkSize);
    setappdata(hFig, 'BgColor', DispOptions.BgColor);
    setappdata(hFig, 'HierarchyNodeIsVisible', 1); % note: set as 1 to match default, updated to saved user pref later
    
    %% ===== Create Nodes =====
    %  This also defines some data-based display parameters
    ClearAndAddNodes(hFig, Vertices, Names);
    GlobalData.FigConnect.ClickedNodeIndex = 0;  %set initial clicked node to 0 (none)
    GlobalData.FigConnect.ClickedLinkIndex = 0; 
    GlobalData.FigConnect.ClickedArrowIndex = 0;
    GlobalData.FigConnect.ClickedNode1Index = 0;
    GlobalData.FigConnect.ClickedNode2Index = 0;
   
    %% ===== Compute Links =====
    % Data cleaning options
    Options.Neighbours = 0;
    Options.Distance = 0;
    Options.Highest = 1;
    setappdata(hFig, 'LoadingOptions', Options);
    % Clean and compute Datapair
    [DataPair, isStat] = LoadConnectivityData(hFig, Options);    

    % Compute distance between regions
    MeasureDistance = [];
    if ~isempty(RowLocs)
        MeasureDistance = ComputeEuclideanMeasureDistance(hFig, DataPair, RowLocs);
    end
    bst_figures('SetFigureHandleField', hFig, 'MeasureDistance', MeasureDistance);
    
    
    %% ==== Create and Display Links =======
    % Create links from computed DataPair
    BuildLinks(hFig, DataPair, true);
    SetLinkSize(hFig, DispOptions.LinkSize);
        
    %% ===== Init Filters =====
    % Default intensity threshold
    if isStat
        MinThreshold = 0;
    else
        MinThreshold = 0.9;
    end
    % Don't refresh display for each filter at loading time
    Refresh = 0;
    
    % Clear filter masks
    bst_figures('SetFigureHandleField', hFig, 'MeasureDistanceMask', zeros(size(DataPair, 1), 1));
    bst_figures('SetFigureHandleField', hFig, 'MeasureThresholdMask', zeros(size(DataPair, 1), 1));
    bst_figures('SetFigureHandleField', hFig, 'MeasureAnatomicalMask', zeros(size(DataPair, 1), 1));
    bst_figures('SetFigureHandleField', hFig, 'MeasureDisplayMask', zeros(size(DataPair, 1), 1));
    
    % Application specific display filter
    SetMeasureDisplayFilter(hFig, ones(size(DataPair, 1), Refresh));
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
            ThresholdMinMax = [min(DataPair(:, 3)), max(DataPair(:, 3))];
        else
            ThresholdMinMax = [min(abs(DataPair(:, 3))), max(abs(DataPair(:, 3)))];
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
    % Update colormap
    UpdateColormap(hFig);
    SetBackgroundColor(hFig, DispOptions.BgColor);
    % TextDisplayMode saved user prefs retrieved already, needs refresh
    RefreshTextDisplay(hFig);
    % Display region and hem lobes?
    SetHierarchyNodeIsVisible(hFig, DispOptions.HierarchyNodeIsVisible);
    % Position camera
    DefaultCamera(hFig);
end
 
%% ======== Create all links as Matlab Lines =====
function BuildLinks(hFig, DataPair, IsMeasureLink)
    % get pre-created nodes
    AllNodes = getappdata(hFig, 'AllNodes');
    IsDirectionalData = getappdata(hFig, 'IsDirectionalData');
    % Get figure axes
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'AxesConnect');
    
    % clear any previous links and get scaling distance from nodes to unit circle
    if (IsMeasureLink)
        LevelScale = getappdata(hFig, 'MeasureLevelDistance');
        if (isappdata(hFig, 'MeasureLinks'))
            delete(getappdata(hFig, 'MeasureLinks'));
            rmappdata(hFig, 'MeasureLinks');
        end
        if (isappdata(hFig, 'MeasureArrows'))
            delete(getappdata(hFig, 'MeasureArrows'));
            rmappdata(hFig, 'MeasureArrows');
        end
    else
        LevelScale = getappdata(hFig, 'RegionLevelDistance');
        if (isappdata(hFig, 'RegionLinks'))
            delete(getappdata(hFig, 'RegionLinks'));
            rmappdata(hFig, 'RegionLinks');
        end
        if (isappdata(hFig, 'RegionArrows'))
            delete(getappdata(hFig, 'RegionArrows'));
            rmappdata(hFig, 'RegionArrows');
        end
    end
    
    % for arrowheads get axis ranges and hold status, toggle if necessary
    if (IsDirectionalData)
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
    
    % if we are building measurelinks, we use their distance to compute the
    % radius (see math below)
    MeasureDistance = [];
    if (IsMeasureLink)
        RowLocs = bst_figures('GetFigureHandleField', hFig, 'RowLocs');
        if ~isempty(RowLocs)
            MeasureDistance = ComputeEuclideanMeasureDistance(hFig, DataPair, RowLocs);
        end
    end
    
    % Note: DataPair computation already removed diagonal and capped at max 5000 pairs 
    
    
    link0  = line(0,0);
    arrow0 = patch(0,0,'k');
    Links  = repmat(link0, 1, size(DataPair,1));
    Arrows = repmat(arrow0, 1, size(DataPair,1));
    %for each link
    for i = 1:size(DataPair,1)
        overlap = false;
        % node positions (rescaled to *unit* circle)
        Node1 = DataPair(i, 1); Node2 = DataPair(i, 2);
        u  = [AllNodes(Node1).Position(1); AllNodes(Node1).Position(2)]/LevelScale;
        v  = [AllNodes(Node2).Position(1); AllNodes(Node2).Position(2)]/LevelScale;
    
        % draw elliptical arc if 2 bidirectional links overlap
        All_u(i, :) = u.'; All_v(i, :) = v.';
        for j = 1:length(All_u)-1
            if (v(1) == All_u(j, 1) && v(2) == All_u(j, 2) && u(1) == All_v(j, 1) && u(2) == All_v(j, 2))
                overlap = true;
                
                p = [(AllNodes(Node1).Position(1) - AllNodes(Node2).Position(1)) (AllNodes(Node1).Position(2) - AllNodes(Node2).Position(2))]; % horde vector
                H = norm(p);            % horde length
                
                % For measure links, we have some rare cases where the
                % radius of the arc needs to be adapted for links that
                % are long. In these cases, the arc radius depends on
                % distance between the nodes. 
                if (~isempty(MeasureDistance) && IsMeasureLink && MeasureDistance(i) >= 80.0)
                    R = 0.75*H;
                else
                    R = 0.63*H;             
                end

                v = [-p(2) p(1)]/H;     % perpendicular vector
                L = sqrt(R*R-H*H/4);	% distance to circle (from horde)
                p = [(AllNodes(Node1).Position(1) + AllNodes(Node2).Position(1)) (AllNodes(Node1).Position(2) + AllNodes(Node2).Position(2))];% vector center horde
                p0(1, :) = p/2 + v*L;	% circle center 1
                p0(2, :) = p/2 - v*L;	% circle center 2
                d = sqrt(sum(p0.^2, 2)); % distance to circle center
                [~, ix] = max( d );      % get max (circle outside)
                p0 = p0(ix, :);
                
                % generate arc points
                vx = linspace(AllNodes(Node1).Position(1), AllNodes(Node2).Position(1), 100) - p0(1);
                vy = linspace(AllNodes(Node1).Position(2), AllNodes(Node2).Position(2), 100) - p0(2);
                v = sqrt(vx.^2 + vy.^2);
                x = p0(1) + vx./v*R;
                y = p0(2) + vy./v*R;
            end
        end
        
        % Otherwise, follow Poincare Hyperbolic Disk model 
        if (~overlap)
            % diametric points (w error margin): draw a straight line 
            if (abs(u(1) + v(1)) < 0.2 && abs(u(2) + v(2)) < 0.2)
                x = linspace(LevelScale*u(1), LevelScale*v(1), 100);
                y = linspace(LevelScale*u(2), LevelScale*v(2), 100);    
            % otherwise, draw an arc
            else 
                x0 = -(u(2) - v(2))/(u(1)*v(2) - u(2)*v(1));
                y0 =  (u(1) - v(1))/(u(1)*v(2) - u(2)*v( 1));
                r  = sqrt(x0^2 + y0^2 - 1);
                
                thetaLim(1) = atan2(u(2) - y0, u(1) - x0);
                thetaLim(2) = atan2(v(2) - y0, v(1) - x0);
                
                % ensure arcs on right-hand side are drawn within the graph
                if (u(1) >= 0 && v(1) >= 0)
                    first = abs(pi - max(thetaLim));
                    second = abs(-pi - min(thetaLim));
                    fraction = floor((first/(first + second))*100);
                    remaining = 100 - fraction;
                    
                    % ensure arc is within the unit disk
                    % ensure correct direction: from thetaLim(1) to thetaLim(2)
                    if (max(thetaLim) == thetaLim(1))
                        theta = [linspace(max(thetaLim), pi, fraction), ...
                            linspace(-pi, min(thetaLim), remaining)].';
                    else
                        theta = [linspace(min(thetaLim), -pi, remaining), ...
                            linspace(pi, max(thetaLim), fraction)].';
                    end
                else
                    theta = linspace(thetaLim(1), thetaLim(2)).';
                end
                
                % rescale onto our graph circle
                x = LevelScale*r*cos(theta) + LevelScale*x0;
                y = LevelScale*r*sin(theta) + LevelScale*y0;
            end
        end
        
        % create line graphics object
        Links(i) = line(...
                x, ...
                y, ...
                'LineWidth', 1.5, ...
                'Color', [AllNodes(Node1).Color 0.00], ...
                'PickableParts', 'visible', ...
                'Visible', 'off', ...                                             % not visible as default;
                'UserData', [i IsDirectionalData IsMeasureLink Node1 Node2], ...  % i is the link index
                'ButtonDownFcn', @LinkButtonDownFcn, ...
                'Parent', hAxes); 

        % create arrows for directional links
        if (IsDirectionalData)
            Arrows(i) = Arrowhead(hAxes, x, y, AllNodes(Node1).Color, 100, 50, i, IsMeasureLink, Node1, Node2, Xextend, Yextend);
        end
    end
    
    % Store new links and arrows into figure  
    if (IsMeasureLink)
        setappdata(hFig, 'MeasureLinks', Links);
        if (IsDirectionalData)
            setappdata(hFig, 'MeasureArrows', Arrows);
        end
    else
        setappdata(hFig, 'RegionLinks', Links);
        if (IsDirectionalData)
            setappdata(hFig, 'RegionArrows', Arrows);
        end
    end
    
    if (IsDirectionalData) % restore original axe ranges and hold status
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

    Index = src.UserData(1);
    IsDirectional = src.UserData(2);
    IsMeasureLink = src.UserData(3);    
    % Store globally for access when mouse click is released
    GlobalData.FigConnect.ClickedLinkIndex = src.UserData(1);
    GlobalData.FigConnect.ClickedNode1Index = src.UserData(4); 
    GlobalData.FigConnect.ClickedNode2Index = src.UserData(5); 

    if (strcmpi(clickAction, 'SingleClick'))    
        % increase size on button down click
        CurSize = src.LineWidth;
        set(src, 'LineWidth', 2.0*CurSize);
        
        % make node labels larger and bold
        % node indices are stored in UserData
        Node1 = AllNodes(src.UserData(4));
        Label1 = Node1.TextLabel;
        Node2 = AllNodes(src.UserData(5));
        Label2 = Node2.TextLabel;
        CurLabelSize = Label1.FontSize;
        set(Label1, 'FontWeight', 'bold');
        set(Label2, 'FontWeight', 'bold');
        set(Label1, 'FontSize', CurLabelSize + 2);
        set(Label2, 'FontSize', CurLabelSize + 2);
        
        % also increase size of arrowheads 
        if (IsDirectional)
            if (IsMeasureLink)
                Arrows = getappdata(hFig, 'MeasureArrows');
                Scale = 2.0;
            else
                Arrows = getappdata(hFig, 'RegionArrows');
                Scale = 2.0;
            end
            Arrow = Arrows(Index);
            ArrowSize = Arrow.LineWidth;
            
            set(Arrow, 'LineWidth', Scale*ArrowSize);
        end
    end
end

% return size to original size after releasing mouse click
function LinkClickEvent(hFig, LinkIndex, LinkType, IsDirectional, Node1Index, Node2Index)
    % measure links
    if (LinkType)
        MeasureLinks = getappdata(hFig, 'MeasureLinks');
        Link = MeasureLinks(LinkIndex);
        CurSize = Link.LineWidth;
        set(Link, 'LineWidth', CurSize/2.0);
        
        if (IsDirectional)
            Arrows = getappdata(hFig, 'MeasureArrows');
            Scale = 2.0;
        end          
    else % region links
        RegionLinks = getappdata(hFig, 'RegionLinks');
        Link = RegionLinks(LinkIndex);
        CurSize = Link.LineWidth;     
        set(Link, 'LineWidth', CurSize/2.0);
        
        if (IsDirectional)
            Arrows = getappdata(hFig, 'RegionArrows');
            Scale = 2.0;
        end  
    end   
    
    % arrowheads
    if (IsDirectional)
        Arrow = Arrows(LinkIndex);
        ArrowSize = Arrow.LineWidth;
        set(Arrow, 'LineWidth', ArrowSize/Scale);
    end
    
    % labels
    AllNodes = getappdata(hFig, 'AllNodes');
    Node1 = AllNodes(Node1Index);
    Node2 = AllNodes(Node2Index);
    Label1 = Node1.TextLabel;
    Label2 = Node2.TextLabel;
    CurLabelSize = Label1.FontSize;
    
    set(Label1, 'FontWeight', 'normal');
    set(Label2, 'FontWeight', 'normal');
    set(Label1, 'FontSize', CurLabelSize - 2);
    set(Label2, 'FontSize', CurLabelSize - 2);
end

% Draws 2 solid arrowheads for each link
% based on: https://www.mathworks.com/matlabcentral/fileexchange/4538-arrowhead
function [handle] = Arrowhead(hAxes, x, y, clr, ArSize, Where, Index, IsMeasureLink, Node1, Node2, xExtend, yExtend)
    % determine location of first arrowhead
    ArWidth = 0.75;
    j = floor(length(x)*Where/100); 
    
    if j >= length(x)
        j = length(x) - 1;
    end
    x1 = x(j); x2 = x(j+1); y1 = y(j); y2 = y(j+1);

    % the arrow is made of a transformed "template triangle"
    
    % determine rotation angle for the triangle
    if x2 == x1 % line vertical, no need to calculate slope
        if y2 > y1
            p = pi/2;
        else
            p= -pi/2;
        end
    else % line not vertical, calculate slope using normed differences
        m = ( (y2 - y1)/yExtend ) / ( (x2 - x1)/xExtend );
        if x2 > x1
            p = atan(m);
        else
            p = atan(m) + pi;
        end
    end

    % template triangle (points "east", centered in (0, 0)):
    xt = [1	-sin(pi/6)	-sin(pi/6)];
    yt = ArWidth*[0	 cos(pi/6)	-cos(pi/6)]; 
    % rotate by angle determined above
    xd = []; yd = [];
    for i = 3:-1:1 % loop backwards to pre-allocate
        xd(i) = cos(p)*xt(i) - sin(p)*yt(i);
        yd(i) = sin(p)*xt(i) + cos(p)*yt(i);
    end  
    % move the triangle so that its "head" lays in (0, 0):
    xd = xd - cos(p);
    yd = yd - sin(p);   
    % stretch/deform to look good on the current axes:
    xd = xd*xExtend*ArSize/10000;
    yd = yd*yExtend*ArSize/10000; 
    % move to the location desired
    xd1 = xd + x2;
    yd1 = yd + y2;
    % tip of the second arrow
    new_x = (xd1(2)+xd1(3))/2;
    new_y = (yd1(2)+yd1(3))/2;    
    
%%%%% second arrowhead %%%%%%
    
    % find point on the line closest to the desired location of
    % the second arrowhead (tip of second at base of the first)
    pts_line = [x(:), y(:)];
    difference = bsxfun(@minus, pts_line, [new_x new_y]);
    dist2 = sum(difference.^2, 2);
    [~, index] = min(dist2);    
    % if more than one index is found, return the one closest to 70
    if (size(index) > 1)
        index = min(60 - index);
    end    
    % draw second arrow at tip of second half of the link
    x = pts_line(1:index, 1);
    y = pts_line(1:index, 2);
    if (size(x) < 2)
        x = pts_line(1:index+1, 1);
    end
    if (size(y) < 2)
        y = pts_line(1:index+1, 2);
    end
    % determine location of the second arrowhead
    Where = 100;
    j = floor(length(x)*Where/100);
    if j >= length(x)
        j = length(x) - 1;
    end
    if j == 0
        j = 1;
    end
    x1 = x(j); x2 = x(j+1); y1 = y(j); y2 = y(j+1);    
    % determine rotation angle
    if x2 == x1 %line vertical, no need to calculate slope
        if y2 > y1
            p = pi/2;
        else
            p= -pi/2;
        end
    else %-- line not vertical, calculate slope using normed differences
        m = ( (y2 - y1)/yExtend ) / ( (x2 - x1)/xExtend );
        if x2 > x1
            p = atan(m);
        else
            p = atan(m) + pi;
        end
    end   
    % rotation
    xd = []; yd = [];
    for i = 3:-1:1
        xd(i) = cos(p)*xt(i) - sin(p)*yt(i);
        yd(i) = sin(p)*xt(i) + cos(p)*yt(i);
    end
    % move the triangle so that its "head" lays in (0, 0):
    xd = xd - cos(p);
    yd = yd - sin(p);
    % stretch/deform
    xd = xd*xExtend*ArSize/10000;
    yd = yd*yExtend*ArSize/10000;
    % move to desired location
    xd2 = xd + x2;
    yd2 = yd + y2; 
    
    xd_all = [xd1 xd2];
    yd_all = [yd1 yd2];
    
    % first face = first arrow with vertices 1-2-3
    % second face = second arrow with vertices 4-5-6
    Vertices = [xd_all.', yd_all.'];
    Faces = [1 2 3; 4 5 6]; 

    %%%% draw both arrowheads as 2 faces of a single patch object %%%%
    handle = patch('Vertices', Vertices, ...
        'Faces', Faces, ...
        'EdgeColor', 'flat', ...
        'FaceColor', 'flat', ...
        'FaceAlpha', 'flat', ...
        'AlphaDataMapping', 'none', ...
        'FaceVertexCData', NaN(6, 1), ... % no defined color at start
        'FaceVertexAlphaData', [0; 0], ...
        'Visible', 'off', ...
        'PickableParts', 'visible', ...
        'UserData', [Index IsMeasureLink Node1, Node2], ... % flag == 1 for first arrow
        'ButtonDownFcn', @ArrowButtonDownFcn, ...
        'Parent', hAxes);
end

% When user clicks on an arrow
function ArrowButtonDownFcn(src, ~)

    global GlobalData;
    hFig = GlobalData.FigConnect.Figure;
    clickAction = getappdata(hFig, 'clickAction');
    AllNodes = getappdata(hFig, 'AllNodes');
    
    Index = src.UserData(1);
    IsMeasureLink = src.UserData(2);
    GlobalData.FigConnect.ClickedArrowIndex = src.UserData(1);
    GlobalData.FigConnect.ClickedNode1Index = src.UserData(3); 
    GlobalData.FigConnect.ClickedNode2Index = src.UserData(4);
    
    if (strcmpi(clickAction, 'SingleClick')) 
        
        % size of the selected arrow
        CurSize = src.LineWidth;  
        
        % increase size of the node labels and make them bold
        Node1 = AllNodes(src.UserData(3));
        Label1 = Node1.TextLabel;
        Node2 = AllNodes(src.UserData(4));
        Label2 = Node2.TextLabel;
        CurLabelSize = Label1.FontSize;
        set(Label1, 'FontWeight', 'bold');
        set(Label2, 'FontWeight', 'bold');
        set(Label1, 'FontSize', CurLabelSize + 2);
        set(Label2, 'FontSize', CurLabelSize + 2);   
        
        % increase link size depending on the type of graph
        if (IsMeasureLink)
            Scale = 2.0;

            AllLinks = getappdata(hFig, 'MeasureLinks');
            Link = AllLinks(Index);
            LinkSize = Link.LineWidth;
            set(Link, 'LineWidth', Scale*LinkSize);
        else
            Scale = 2.0;
            
            AllLinks = getappdata(hFig, 'RegionLinks');
            Link = AllLinks(Index);
            LinkSize = Link.LineWidth;
            set(Link, 'LineWidth', Scale*LinkSize);
        end
        % increase size of the selected arrow
        set(src, 'LineWidth', Scale*CurSize);
    end
end

% return size back to original one after release mouse click
function ArrowClickEvent(hFig, ArrowIndex, LinkType, Node1Index, Node2Index)
    % measure links
    if (LinkType)
        MeasureLinks = getappdata(hFig, 'MeasureLinks');
        Link = MeasureLinks(ArrowIndex);
        CurSize = Link.LineWidth;
        set(Link, 'LineWidth', CurSize/2.0);
        
        Arrows = getappdata(hFig, 'MeasureArrows');
        Scale = 2.0;       
        
    else % region links
        RegionLinks = getappdata(hFig, 'RegionLinks');
        Link = RegionLinks(ArrowIndex);
        CurSize = Link.LineWidth;     
        set(Link, 'LineWidth', CurSize/2.0);  
        
        Arrows = getappdata(hFig, 'RegionArrows');
        Scale = 2.0;
    end
    
    % return arrow size back to initial size
    Arrow = Arrows(ArrowIndex);
    ArrowSize = Arrow.LineWidth;
    set(Arrow, 'LineWidth', ArrowSize/Scale);
    
    % put labels back to original font size 
    AllNodes = getappdata(hFig, 'AllNodes');   
    Node1 = AllNodes(Node1Index);
    Label1 = Node1.TextLabel;
    Node2 = AllNodes(Node2Index);
    Label2 = Node2.TextLabel;
    CurLabelSize = Label1.FontSize;
    
    set(Label1, 'FontWeight', 'normal');
    set(Label2, 'FontWeight', 'normal');
    set(Label1, 'FontSize', CurLabelSize - 2);
    set(Label2, 'FontSize', CurLabelSize - 2);
end
 
function NodeColors = BuildNodeColorList(RowNames, Atlas)
    % We assume RowNames and Scouts are in the same order
    if ~isempty(Atlas)
        NodeColors = reshape([Atlas.Scouts.Color], 3, length(Atlas.Scouts))';
    else % Default neutral color
        NodeColors = 0.5 * ones(length(RowNames), 3);
    end
end
 
function sGroups = AssignGroupBasedOnCentroid(RowLocs, RowNames, sGroups, Surface)
    % Compute centroid
    Centroid = sum(Surface.Vertices, 1) / size(Surface.Vertices, 1);
    % Split in hemisphere first if necessary
    if isempty(sGroups)
        sGroups(1).Name = 'Left';
        sGroups(1).Region = 'LU';
        sGroups(2).Name = 'Right';
        sGroups(2).Region = 'RU';
        sGroups(1).RowNames = RowNames(RowLocs(:, 2) >= Centroid(2));    
        sGroups(2).RowNames = RowNames(RowLocs(:, 2) < Centroid(2));
    end
    % For each hemisphere
    for i =1:2
        OriginalGroupRows = ismember(RowNames, [sGroups(i).RowNames]);
        Posterior = RowLocs(:, 1) >= Centroid(1) & OriginalGroupRows;
        Anterior = RowLocs(:, 1) < Centroid(1) & OriginalGroupRows;
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
    SelNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
    % Get Rowlocs
    RowLocs = bst_figures('GetFigureHandleField', hFig, 'RowLocs');
    Options = getappdata(hFig, 'LoadingOptions');
    % Clean and Build Datapair
    DataPair = LoadConnectivityData(hFig, Options);
        
    % Update measure distance
    MeasureDistance = [];
    if ~isempty(RowLocs)
        MeasureDistance = ComputeEuclideanMeasureDistance(hFig, DataPair, RowLocs);
    end
    % Update figure variable
    bst_figures('SetFigureHandleField', hFig, 'MeasureDistance', MeasureDistance);

    %% ==== Re-Create and Display Links =======
    % Create new links from computed DataPair
    BuildLinks(hFig, DataPair, true);
    SetLinkSize(hFig, getappdata(hFig, 'LinkSize'));
    
    %% ===== FILTERS =====
    Refresh = 0;
    
    % Init Filter variables
    bst_figures('SetFigureHandleField', hFig, 'MeasureDistanceMask', zeros(size(DataPair, 1), 1));
    bst_figures('SetFigureHandleField', hFig, 'MeasureThresholdMask', zeros(size(DataPair, 1), 1));
    bst_figures('SetFigureHandleField', hFig, 'MeasureAnatomicalMask', zeros(size(DataPair, 1), 1));
    bst_figures('SetFigureHandleField', hFig, 'MeasureDisplayMask', zeros(size(DataPair, 1), 1));
    
    % Threshold 
    if isempty(DataPair)
        ThresholdMinMax = [0 0];
    else
        ThresholdAbsoluteValue = getappdata(hFig, 'ThresholdAbsoluteValue');
        if isempty(ThresholdAbsoluteValue) || ~ThresholdAbsoluteValue
            ThresholdMinMax = [min(DataPair(:, 3)), max(DataPair(:, 3))];
        else
            ThresholdMinMax = [min(abs(DataPair(:, 3))), max(abs(DataPair(:, 3)))];
        end
    end
    bst_figures('SetFigureHandleField', hFig, 'ThresholdMinMax', ThresholdMinMax);
 
    % Reset filters using the same thresholds
    SetMeasureDisplayFilter(hFig, ones(size(DataPair, 1), 1), Refresh);
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
    SetHierarchyNodeIsVisible(hFig, getappdata(hFig, 'HierarchyNodeIsVisible'));
    
    RefreshTitle(hFig);    
    % Set background color
    SetBackgroundColor(hFig, getappdata(hFig, 'BgColor'));
    % Update colormap
    UpdateColormap(hFig);
    % Redraw selected nodes
    SetSelectedNodes(hFig, SelNodes, 1);
    % Update panel
    panel_display('UpdatePanel', hFig);
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
    AllNodes = getappdata(hFig, 'AllNodes');
    if (IsVisible <= 0)       
        Index = find(DisplayNode <= 0);
    else
        Index = find(DisplayNode > 0);
    end
    for i = 1:size(Index, 1)
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
    SelNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
    if (Refresh)
        % Remove previous links
        SetSelectedNodes(hFig, SelNodes, 0);
    end
    % Update variable
    bst_figures('SetFigureHandleField', hFig, 'MeasureDisplayMask', NewMeasureDisplayMask);
    if (Refresh)
        % Redraw selected nodes
        SetSelectedNodes(hFig, SelNodes, 1);
    end
end
 
function SetMeasureThreshold(hFig, NewMeasureThreshold, Refresh)
    % Refresh by default
    if (nargin < 3)
        Refresh = 1;
    end
    % Get selected rows
    SelNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
    % Get Datapair
    DataPair = bst_figures('GetFigureHandleField', hFig, 'DataPair');
    % Get threshold option
    ThresholdAbsoluteValue = getappdata(hFig, 'ThresholdAbsoluteValue');
    if (ThresholdAbsoluteValue)
        DataPair(:, 3) = abs(DataPair(:, 3));
    end
    % Compute new mask
    MeasureThresholdMask = DataPair(:, 3) >= NewMeasureThreshold;
    if (Refresh)
        % Remove previous links
        SetSelectedNodes(hFig, SelNodes, 0);
    end
    % Update variable
    bst_figures('SetFigureHandleField', hFig, 'MeasureThreshold', NewMeasureThreshold);
    bst_figures('SetFigureHandleField', hFig, 'MeasureThresholdMask', MeasureThresholdMask);
    if (Refresh)
        % Redraw selected nodes
        SetSelectedNodes(hFig, SelNodes, 1);
    end
end
 
function SetMeasureAnatomicalFilterTo(hFig, NewMeasureAnatomicalFilter, Refresh)
    % Refresh by default
    if (nargin < 3)
        Refresh = 1;
    end
    DataPair = bst_figures('GetFigureHandleField', hFig, 'DataPair');
    % Get selected rows
    SelNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
    % Compute new mask
    NewMeasureAnatomicalMask = GetMeasureAnatomicalMask(hFig, DataPair, NewMeasureAnatomicalFilter);
    if (Refresh)
        % Remove previous links
        SetSelectedNodes(hFig, SelNodes, 0);
    end
    % Update variable
    bst_figures('SetFigureHandleField', hFig, 'MeasureAnatomicalFilter', NewMeasureAnatomicalFilter);
    bst_figures('SetFigureHandleField', hFig, 'MeasureAnatomicalMask', NewMeasureAnatomicalMask);
    if (Refresh)
        % Redraw selected nodes
        SetSelectedNodes(hFig, SelNodes, 1);
    end
end
 
function SetMeasureFiberFilterTo(hFig, NewMeasureFiberFilter, Refresh)
    % Refresh by default
    if (nargin < 3)
        Refresh = 1;
    end
    DataPair = bst_figures('GetFigureHandleField', hFig, 'DataPair');
    % Get selected rows
    SelNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
    % Compute new mask
    NewMeasureFiberMask = GetMeasureFiberMask(hFig, DataPair, NewMeasureFiberFilter);
    if (Refresh)
        % Remove previous links
        SetSelectedNodes(hFig, SelNodes, 0);
    end
    % Update variable
    bst_figures('SetFigureHandleField', hFig, 'MeasureFiberFilter', NewMeasureFiberFilter);
    bst_figures('SetFigureHandleField', hFig, 'MeasureFiberMask', NewMeasureFiberMask);
    if (Refresh)
        % Redraw selected nodes
        SetSelectedNodes(hFig, SelNodes, 1);
    end
end
 
function MeasureAnatomicalMask = GetMeasureAnatomicalMask(hFig, DataPair, MeasureAnatomicalFilter)
    ChannelData = bst_figures('GetFigureHandleField', hFig, 'ChannelData');
    MeasureAnatomicalMask = zeros(size(DataPair, 1), 1);
    switch (MeasureAnatomicalFilter)
        case 0 % 0 - All
            MeasureAnatomicalMask(:) = 1;
        case 1 % 1 - Between Hemisphere
            MeasureAnatomicalMask = ChannelData(DataPair(:, 1), 3) ~= ChannelData(DataPair(:, 2), 3);
        case 2 % 2 - Between Lobe == Not Same Region
            MeasureAnatomicalMask = ChannelData(DataPair(:, 1), 1) ~= ChannelData(DataPair(:, 2), 1);
    end
end
 
function MeasureFiberMask = GetMeasureFiberMask(hFig, DataPair, MeasureFiberFilter)
    global GlobalData;
    MeasureFiberMask = zeros(size(DataPair,1),1);
    
    % Only filter if there are fibers shown
    plotFibers = getappdata(hFig, 'plotFibers');
    hFigFib = bst_figures('GetFigureHandleField', hFig, 'hFigFib');
    if MeasureFiberFilter == 0 || isempty(plotFibers) || ~plotFibers || ~ishandle(hFigFib)
        MeasureFiberMask(:) = 1;
        return;
    end
    
    %% Get fibers information
    TfInfo = getappdata(hFig, 'Timefreq');
    TessInfo = getappdata(hFigFib, 'Surface');
    iTess = find(ismember({TessInfo.Name}, 'Fibers'));
    [FibMat, iFib] = bst_memory('LoadFibers', TessInfo(iTess).SurfaceFile);
    
    %% If fibers not yet assigned to atlas, do so now
    if isempty(FibMat.Scouts(1).ConnectFile) || ~ismember(TfInfo.FileName, {FibMat.Scouts.ConnectFile})
        %ScoutNames     = bst_figures('GetFigureHandleField', hFig, 'RowNames');
        ScoutCentroids = bst_figures('GetFigureHandleField', hFig, 'RowLocs');
        FibMat = fibers_helper('AssignToScouts', FibMat, TfInfo.FileName, ScoutCentroids);
        % Save in memory to avoid recomputing
        GlobalData.Fibers(iFib) = FibMat;
    end
    
    % Get scout assignment
    iFile = find(ismember(TfInfo.FileName, {FibMat.Scouts.ConnectFile}));
    assign = FibMat.Scouts(iFile).Assignment;
    AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
    DataPair = DataPair(:,1:2) - size(AgregatingNodes, 2);
    
    %% Find nodes that have fiber assignments
    assignBsx = reshape(assign', [1 size(assign')]);
    % Get the matches for the pairs and for the flipped pairs
    indices =  all(bsxfun(@eq, DataPair, assignBsx), 2) | all( bsxfun(@eq, DataPair, flip(assignBsx,2)), 2);
    % Find the indices of the rows with a match
    MeasureFiberMask = any(indices,3);
        
    if MeasureFiberFilter == 2 % Anatomically inaccurate
        MeasureFiberMask = ~MeasureFiberMask;
    end
end
 
function SetMeasureDistanceFilter(hFig, NewMeasureMinDistanceFilter, NewMeasureMaxDistanceFilter, Refresh)
    % Refresh by default
    if (nargin < 4)
        Refresh = 1;
    end
    % Get selected rows
    SelNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
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
        SetSelectedNodes(hFig, SelNodes, 0);
    end
    % Update variable
    bst_figures('SetFigureHandleField', hFig, 'MeasureMinDistanceFilter', NewMeasureMinDistanceFilter);
    bst_figures('SetFigureHandleField', hFig, 'MeasureMaxDistanceFilter', NewMeasureMaxDistanceFilter);
    bst_figures('SetFigureHandleField', hFig, 'MeasureDistanceMask', MeasureDistanceMask);
    if (Refresh)
        % Redraw selected nodes
        SetSelectedNodes(hFig, SelNodes, 1);
    end
end
 
function mFunctionDataPair = ComputeRegionFunction(hFig, mDataPair, RegionFunction)
    Levels = bst_figures('GetFigureHandleField', hFig, 'Levels');
    Regions = Levels{2};
    NumberOfRegions = size(Regions, 1);
    
    % Precomputing this saves on processing time
    NodesFromRegions = cell(NumberOfRegions, 1);
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
    
    mFunctionDataPair = zeros(nPairs, 3);   
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
                Index = ismember(mDataPair(:, 1), NodesFromRegions{i}) & ismember(mDataPair(:, 2), NodesFromRegions{y});
            else
                IndexItoY = ismember(mDataPair(:, 1), NodesFromRegions{i}) & ismember(mDataPair(:, 2), NodesFromRegions{y});
                IndexYtoI = ismember(mDataPair(:, 1), NodesFromRegions{y}) & ismember(mDataPair(:, 2), NodesFromRegions{i});
                Index = IndexItoY | IndexYtoI;
            end
            % If there is values
            if (sum(Index) > 0)
                switch(RegionFunction)
                    case 'max' 
                        Value = max(mDataPair(Index, 3));
                    case 'mean'
                        Value = mean(mDataPair(Index, 3));
                end
                mFunctionDataPair(iFunction, :) = [Regions(i) Regions(y) Value];
                iFunction = iFunction + 1;
            end
        end
    end
    % Eliminate empty data
    mFunctionDataPair(mFunctionDataPair(:, 3) == 0, :) = [];
end
 
function MeasureDistance = ComputeEuclideanMeasureDistance(hFig, aDataPair, mLoc)
    % Correct offset
    nAgregatingNodes = size(bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes'), 2);
    aDataPair(:, 1:2) = aDataPair(:, 1:2) - nAgregatingNodes;
    % Compute Euclidean distance
    Minus = bsxfun(@minus, mLoc(aDataPair(:, 1), :), mLoc(aDataPair(:, 2), :));
    MeasureDistance = sqrt(sum(Minus(:, :) .^ 2, 2));
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
        
        DataMask = ones(size(DataPair, 1), 1);
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
    RegionDataMask = ones(size(RegionDataPair, 1), 1);
    if (size(RegionDataPair, 1) > 0)
        % Get colormap
        sColormap = bst_colormaps('GetColormap', hFig);
        % Get threshold option
        ThresholdAbsoluteValue = getappdata(hFig, 'ThresholdAbsoluteValue');
        if (ThresholdAbsoluteValue) || sColormap.isAbsoluteValues
            RegionDataPair(:, 3) = abs(RegionDataPair(:, 3));
        end
        % Get threshold
        MeasureThreshold = bst_figures('GetFigureHandleField', hFig, 'MeasureThreshold');
        if (~isempty(MeasureThreshold))
            % Compute new mask
            MeasureThresholdMask = RegionDataPair(:, 3) >= MeasureThreshold;
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
        DataPair(:, 3) = abs(DataPair(:, 3));
    end
    % Get figure method
    Method = getappdata(hFig, 'Method');
    % Get maximum values
    DataMinMax = bst_figures('GetFigureHandleField', hFig, 'DataMinMax');
    % Get threshold min/max values
    % ThresholdMinMax = bst_figures('GetFigureHandleField', hFig, 'ThresholdMinMax');
    % === COLORMAP LIMITS ===
    % Units type
    if ismember(Method, {'granger', 'spgranger', 'plv', 'plvt', 'ciplv', 'ciplvt', 'wpli', 'wplit', 'aec'})
        UnitsType = 'timefreq';
    else
        UnitsType = 'connect';
    end
    % Get colormap bounds
    if strcmpi(sColormap.MaxMode, 'custom')
        CLim = [sColormap.MinValue, sColormap.MaxValue];
    elseif ismember(Method, {'granger', 'spgranger', 'plv', 'plvt', 'ciplv', 'ciplvt', 'wpli', 'wplit', 'aec', 'cohere', 'pte', 'henv'})
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
    ColormapInfo.DisplayUnits = TfInfo.DisplayUnits;
    sColormap = bst_colormaps('GetColormap', ColormapInfo.Type);
    % Set figure colormap
    set(hFig, 'Colormap', sColormap.CMap);
    % Create/Delete colorbar
    bst_colormaps('SetColorbarVisible', hFig, sColormap.DisplayColorbar);
    % Display only one colorbar (preferentially the results colorbar)
    bst_colormaps('ConfigureColorbar', hFig, ColormapInfo.Type, UnitsType, ColormapInfo.DisplayUnits);
    
    % === UPDATE DISPLAY ===
    CMap = sColormap.CMap;
      
    IsDirectionalData = getappdata(hFig, 'IsDirectionalData');
      
    if (sum(DataMask) > 0)
        % Normalize DataPair for Offset
        Max = max(DataPair(:, 3));
        Min = min(abs(DataPair(:, 3)));
        Diff = (Max - Min);
        if (Diff == 0)
            Offset = DataPair(DataMask, 3);
        else
            Offset = (abs(DataPair(DataMask, 3)) - Min) ./ (Max - Min);
        end
        % Linear interpolation
        [StartColor, EndColor] = InterpolateColorMap(hFig, DataPair(DataMask, :), CMap, CLim);
        ColorViz = bsxfun(@plus, StartColor, bsxfun(@times, Offset, bsxfun(@minus, EndColor, StartColor)));  % replaced .* with bsxfun for back compatibility
        iData = find(DataMask == 1);
        MeasureLinks = getappdata(hFig, 'MeasureLinks');
        VisibleLinks = MeasureLinks(iData).';
        
        if (IsDirectionalData)
            MeasureArrows = getappdata(hFig, 'MeasureArrows');
            VisibleArrows = MeasureArrows(iData).';
        end
        
        % set desired colors to each link (4th column is transparency)
        if (IsDirectionalData)
            for i = 1:length(VisibleLinks)
                set(VisibleLinks(i), 'Color', ColorViz(i, :));
                set(VisibleArrows(i), 'FaceVertexCData', repmat(ColorViz(i, :), 6, 1)); 
            end 
        else
            for i = 1:length(VisibleLinks)
                set(VisibleLinks(i), 'Color', ColorViz(i, :));
            end
        end
        
        % update visibility of arrowheads
        if (MeasureLinksIsVisible)
            if (IsDirectionalData)
                if (~isempty(IsBinaryData) && IsBinaryData == 1 && DisplayBidirectionalMeasure)
                    % Get Bidirectional data
                    DataMatrix = DataPair(DataMask, :);
                    OutIndex = ismember(DataPair(:, 1:2), DataMatrix(:, 2:-1:1), 'rows').';
                    InIndex = ismember(DataPair(:, 1:2), DataMatrix(:, 2:-1:1), 'rows').';
                    
                    % Second arrow is visible for bidirectional links only
                    iData_mask = DataMask.';
                    bidirectional = iData_mask & (OutIndex | InIndex);
                    non_bidirectional = MeasureArrows(~bidirectional);
                    
                    % for non-bidirectional links change visibility of second arrow while preserving
                    % that of the first arrow
                    for i = 1:length(non_bidirectional) 
                        current_arrow = non_bidirectional(i);
                        current_arrow.FaceVertexAlphaData(2) = 0;
                        current_arrow.FaceVertexCData(4:6,:) = NaN;
                    end
                    
                else
                    % make all second arrows invisible if user selected "In" or "Out"
                    for i = 1:length(MeasureArrows) 
                        current_arrow = MeasureArrows(i);
                        current_arrow.FaceVertexAlphaData(2) = 0;
                        current_arrow.FaceVertexCData(4:6,:) = NaN;
                    end  
               end
            end
        end
        
        % === UPDATE FIBER COLORS ===
        plotFibers = getappdata(hFig, 'plotFibers');
        if plotFibers
            % Get scout information
            SelNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
            SelectedNodeMask = ismember(DataPair(:, 1), SelNodes) ...
                         | ismember(DataPair(:, 2), SelNodes);
            AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
            iScouts = DataPair(DataMask & SelectedNodeMask, 1:2) - size(AgregatingNodes, 2);
            figure_3d('SelectFiberScouts', hFig, iScouts, StartColor, 1);
        end
    end
    
    [RegionDataPair, RegionDataMask] = GetRegionPairs(hFig);
    if (sum(RegionDataMask) > 0)
        % Normalize DataPair for Offset
        Max = max(RegionDataPair(:, 3));
        Min = min(RegionDataPair(:, 3));
        Diff = (Max - Min);
        if (Diff == 0)
            Offset = RegionDataPair(RegionDataMask, 3);
        else
            Offset = (abs(RegionDataPair(RegionDataMask, 3)) - Min) ./ (Max - Min);
        end
        % Normalize within the colormap range 
        [StartColor, EndColor] = InterpolateColorMap(hFig, RegionDataPair(RegionDataMask, :), CMap, CLim); 
        ColorVizRegion = bsxfun(@plus, StartColor, bsxfun(@times, Offset, bsxfun(@minus, EndColor, StartColor)));
        iData = find(RegionDataMask == 1);
        RegionLinks = getappdata(hFig, 'RegionLinks');
        VisibleLinksRegion = RegionLinks(iData).';
        
        if (IsDirectionalData)
            RegionArrows = getappdata(hFig, 'RegionArrows');
            VisibleArrows = RegionArrows(iData).';
        end

        % set desired colors to each link (4th column is transparency)
        if (IsDirectionalData)
            for i = 1:length(VisibleLinksRegion)
                set(VisibleLinksRegion(i), 'Color', ColorVizRegion(i, :));
                set(VisibleArrows(i), 'FaceVertexCData', repmat(ColorVizRegion(i, :), 6, 1)); %arrow color
            end 
        else
            for i = 1:length(VisibleLinksRegion)
                set(VisibleLinksRegion(i), 'Color', ColorVizRegion(i, :));
            end
        end        
        
        % update arrowheads
        if (RegionLinksIsVisible)
            if (IsDirectionalData)
                if (~isempty(IsBinaryData) && IsBinaryData == 1 && DisplayBidirectionalMeasure)
                    % Get Bidirectional data
                    DataMatrix = RegionDataPair(RegionDataMask, :);
                    OutIndex = ismember(RegionDataPair(:, 1:2), DataMatrix(:, 2:-1:1), 'rows').';
                    InIndex = ismember(RegionDataPair(:, 1:2), DataMatrix(:, 2:-1:1), 'rows').';
                    
                    % Second arrow is visible for bidirectional links;
                    iData_mask = RegionDataMask.';
                    bidirectional = iData_mask & (OutIndex | InIndex);
                    non_bidirectional = RegionArrows(~bidirectional);                    
                    
                    for i = 1:length(non_bidirectional)
                        current_arrow = non_bidirectional(i);
                        current_arrow.FaceVertexAlphaData(2) = 0;
                        current_arrow.FaceVertexCData(4:6,:) = NaN;
                    end
                    
                else
                    % make all second arrows invisible if user selected "In" or "Out"
                    for i = 1:length(RegionArrows)
                        current_arrow = MeasureArrows(i);
                        current_arrow.FaceVertexAlphaData(2) = 0;
                        current_arrow.FaceVertexCData(4:6,:) = NaN;
                    end
                end
            end
        end
    end
end

function [StartColor EndColor] = InterpolateColorMap(hFig, DataPair, ColorMap, Limit)
    % Normalize and interpolate
    a = (DataPair(:, 3)' - Limit(1)) / (Limit(2) - Limit(1));
    b = linspace(0, 1, size(ColorMap, 1));
    m = size(a, 2);
    n = size(b, 2);
    [~, p] = sort([a, b]);
    q = 1:m+n; q(p) = q;
    t = cumsum(p > m);
    r = 1:n; r(t(q(m+1:m+n))) = r;
    s = t(q(1:m));
    id = r(max(s, 1));
    iu = r(min(s+1, n));
    [~, it] = min([abs(a-b(id));abs(b(iu)-a)]);
    StartColor = ColorMap(id + bsxfun(@times, it-1, iu-id), :);  % replaced .* with bsxfun for back compatibility
    EndColor = ColorMap(id + bsxfun(@times, it-1, iu-id), :);
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
function ZoomCamera(hFig, Factor)
    angle = hFig.CurrentAxes.CameraViewAngle * Factor;
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
% USAGE:  SetSelectedNodes(hFig, iNodes=[], IsSelected=1) : Add or remove nodes from the current selection
%         If node selection is empty: select/unselect all the nodes
function SetSelectedNodes(hFig, iNodes, IsSelected)
    % ==================== SETUP =========================
    % Parse inputs
    if (nargin < 2) || isempty(iNodes)
        % Get all the nodes
        NumberOfNodes = bst_figures('GetFigureHandleField', hFig, 'NumberOfNodes');
        iNodes = 1:NumberOfNodes;
    end
    if (nargin < 3) || isempty(IsSelected)
        IsSelected = 1;
    end

    % Get list of selected channels
    SelNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
    % If nodes are not specified
    if (nargin < 3)
        iNodes = SelNodes;
        IsSelected = 1;
    end    
    % Define node properties
    if IsSelected
       % marker type now (x or O)
        SelNodes = union(SelNodes, iNodes);
    else
        SelNodes = setdiff(SelNodes, iNodes);
    end   
    % Update list of selected channels
    bst_figures('SetFigureHandleField', hFig, 'SelectedNodes', SelNodes);
    
    % =================== DISPLAY SELECTED NODES =========================
    AllNodes = getappdata(hFig, 'AllNodes');
    % REQUIRED: Display selected nodes ('ON' or 'OFF')
    for i = 1:length(iNodes)
        if IsSelected
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
        NodeDirectionMask = zeros(size(DataMask, 1), 1);
        DisplayOutwardMeasure = getappdata(hFig, 'DisplayOutwardMeasure');
        DisplayInwardMeasure = getappdata(hFig, 'DisplayInwardMeasure');
        DisplayBidirectionalMeasure = getappdata(hFig, 'DisplayBidirectionalMeasure');
        
        if (DisplayOutwardMeasure)
            OutMask = ismember(DataToFilter(:, 1), iNodes);
            NodeDirectionMask = NodeDirectionMask | OutMask;
        end
        if (DisplayInwardMeasure)
            InMask = ismember(DataToFilter(:, 2), iNodes);
            NodeDirectionMask = NodeDirectionMask | InMask;
        end
        if (DisplayBidirectionalMeasure)
            % Selection
            SelectedNodeMask = ismember(DataToFilter(:, 1), iNodes) ...
                             | ismember(DataToFilter(:, 2), iNodes);
            VisibleIndex = find(DataMask == 1);
            % Get Bidirectional data
            BiIndex = ismember(DataToFilter(DataMask, 1:2), DataToFilter(DataMask, 2:-1:1), 'rows');
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
        SelectedNodeMask = ismember(DataToFilter(:, 1), iNodes) ...
                         | ismember(DataToFilter(:, 2), iNodes);
        DataMask = DataMask & SelectedNodeMask;
    end
    
    % ==================== DISPLAY LINKS SELECTION ====================
    % Links are from valid node only
    ValidNode = find(bst_figures('GetFigureHandleField', hFig, 'ValidNode') > 0);
    ValidDataForDisplay = sum(ismember(DataToFilter(:, 1:2), ValidNode), 2);
    DataMask = DataMask == 1 & ValidDataForDisplay == 2;
 
    iData = find(DataMask == 1); % - 1;
 
    if (~isempty(iData))
        % Update link visibility
        % update arrow visibility (directional graph only)
        if (MeasureLinksIsVisible)
            MeasureLinks = getappdata(hFig, 'MeasureLinks');
            
            if (IsSelected)
                set(MeasureLinks(iData), 'Visible', 'on');
                
                % make both arrowheads visible when selected
                if (IsDirectionalData)
                    MeasureArrows = getappdata(hFig, 'MeasureArrows');
                    set(MeasureArrows(iData), 'Visible', 'on');
                    set(MeasureArrows(iData), 'FaceVertexAlphaData', [1; 1]);
                end
                
            else % make everything else invisible
                set(MeasureLinks(iData), 'Visible', 'off');
                if (IsDirectionalData)
                    MeasureArrows = getappdata(hFig, 'MeasureArrows');
                    set(MeasureArrows(iData), 'Visible', 'off');
                end
            end
            
        else % display region links
            RegionLinks = getappdata(hFig, 'RegionLinks');
            
            if (IsSelected)
                set(RegionLinks(iData), 'Visible', 'on');
                if (IsDirectionalData)
                    RegionArrows = getappdata(hFig, 'RegionArrows');
                    set(RegionArrows(iData), 'Visible', 'on');
                    set(RegionArrows(iData), 'FaceVertexAlphaData', [1; 1]);
                end
            else
                set(RegionLinks(iData), 'Visible', 'off');
                if (IsDirectionalData)
                    RegionArrows = getappdata(hFig, 'RegionArrows');
                    set(RegionArrows(iData), 'Visible', 'off');
                end
            end
        end
    end
    
    % Propagate selection to other figures
    NodeNames = bst_figures('GetFigureHandleField', hFig, 'Names');
    if ~isempty(SelNodes) && (length(SelNodes) < length(NodeNames))
        % Select rows
        bst_figures('SetSelectedRows', NodeNames(SelNodes));
        % Select scouts
        panel_scout('SetSelectedScoutLabels', NodeNames(SelNodes));
    else
        bst_figures('SetSelectedRows', []);
        panel_scout('SetSelectedScoutLabels', []);
    end
    
    % If we're plotting fibers, send pairs of scouts that are to be displayed
    plotFibers = getappdata(hFig, 'plotFibers');
    if plotFibers
        % Get scout information
        SelectedNodeMask = ismember(DataToFilter(:, 1), SelNodes) ...
                         | ismember(DataToFilter(:, 2), SelNodes);
        AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
        iScouts = DataToFilter(DataMask & SelectedNodeMask, 1:2) - size(AgregatingNodes, 2);
        
        % Get color information
        CMap = get(hFig, 'Colormap');
        CLim = getappdata(hFig, 'CLim');
        if isempty(CLim)
            CLim = [0, 1];
        end
        Color = InterpolateColorMap(hFig, abs(DataToFilter(DataMask,:)), CMap, CLim);

        % Send to 3D fibers
        figure_3d('SelectFiberScouts', hFig, iScouts, Color);
    end
end
 
%% SHOW/HIDE REGION NODES FROM DISPLAY
%show/hide region nodes (lobes + hem nodes) from display
%hidden nodes should not be clickable
%hidden nodes result in disabled options to show/hide text region labels 
%hidden nodes do not have region max/min options
function SetHierarchyNodeIsVisible(hFig, IsVisible)
    if (IsVisible ~= getappdata(hFig, 'HierarchyNodeIsVisible'))
        % show/hide region nodes (lobes + hem nodes) from display
        AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
        SetDisplayNodeFilter(hFig, AgregatingNodes, IsVisible);
        % rehide extra lobe nodes (level 3)
        HideExtraLobeNode(hFig);
        %hidden nodes do not have region max/min options
        if(~IsVisible && ~getappdata(hFig, 'MeasureLinksIsVisible'))
            ToggleMeasureToRegionDisplay(hFig);
        end          
        setappdata(hFig, 'HierarchyNodeIsVisible', IsVisible);
    end
end
 
 
%% Create Region Mean/Max Links
function RegionDataPair = SetRegionFunction(hFig, RegionFunction)
    % Does data have regions to cluster ?
    DisplayInCircle = getappdata(hFig, 'DisplayInCircle');
    if (isempty(DisplayInCircle) || DisplayInCircle == 0)    
        bst_progress('start', 'Functional Connectivity Display', 'Updating figures...');
        % Get data
        DataPair = GetPairs(hFig);        
        % Computes function across node pairs in region
        RegionDataPair = ComputeRegionFunction(hFig, DataPair, RegionFunction);     
        % create region mean/max links from computed RegionDataPair
        BuildLinks(hFig, RegionDataPair, false); %Note: make sure to use IsMeasureLink = false for this step
        % Update figure value
        bst_figures('SetFigureHandleField', hFig, 'RegionDataPair', RegionDataPair);
        setappdata(hFig, 'RegionFunction', RegionFunction);        
        % Get selected node
        selNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
        % Erase selected node
        SetSelectedNodes(hFig, selNodes, 0);
        % Redraw selected nodes
        SetSelectedNodes(hFig, selNodes, 1);        
        % Update color map
        UpdateColormap(hFig);
        % Update size and transparency
        SetLinkSize(hFig, getappdata(hFig, 'LinkSize'));
        bst_progress('stop');
    end
end
 
% Note: RegionLinksIsVisible == 1 when the user selects it in the popup
% menu
function ToggleMeasureToRegionDisplay(hFig)
    DisplayInRegion = getappdata(hFig, 'DisplayInRegion');
    if (DisplayInRegion)
        bst_progress('start', 'Functional Connectivity Display', 'Updating figures...');
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
        SetSelectedNodes(hFig, selNodes, 0);
        % Update visibility variable
        setappdata(hFig, 'MeasureLinksIsVisible', MeasureLinksIsVisible);
        setappdata(hFig, 'RegionLinksIsVisible', RegionLinksIsVisible);
        % Redraw selected nodes
        SetSelectedNodes(hFig, selNodes, 1);
        UpdateColormap(hFig); % necessary for arrowheads visibility
        bst_progress('stop');
    else
        disp('Current data does not support region display.');
    end
end
 
 
%% ===== DISPLAY MODE =====
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
            SelectionModeIndex = ismember(TextDisplayMode, 3);
            if (sum(SelectionModeIndex) >= 1)
                TextDisplayMode(SelectionModeIndex) = [];
            end
        end        
    else
        % automatically show all labels when uselecting "Show labels for selection"
        if (DisplayMode == 3)
            TextDisplayMode = [1 2];   
        else
            TextDisplayMode(Index) = [];
        end
    end
    % Add display mode
    setappdata(hFig, 'TextDisplayMode', TextDisplayMode);
    % Refresh
    RefreshTextDisplay(hFig);
end
 
%% == Toggle label displays for lobes === 
% toggle order:
% show measure node labels and FULL agregating node labels
% show measure node labels and ABBRV agregating node labels
% show measure node labels only
function ToggleTextDisplayMode(hFig)
    % Get display mode
    TextDisplayMode = getappdata(hFig, 'TextDisplayMode');
    LobeFullLabel = getappdata(hFig, 'LobeFullLabel');
    
    if (isequal(TextDisplayMode, [1 2]) && LobeFullLabel)
        ToggleLobeLabels(hFig);
    elseif (isequal(TextDisplayMode, [1 2]))
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
            if (AllNodes(i).IsAgregatingNode)
                AllNodes(i).TextLabel.String = AllNodes(i).Label;
                AllNodes(i).TextLabel.Rotation = 0;
            end
        end
        setappdata(hFig, 'LobeFullLabel', 0);
    else
        % toggle to full form and radial angle
        for i = 1:length(AllNodes)
            if (AllNodes(i).IsAgregatingNode)
                AllNodes(i).TextLabel.String = LobeTagToFullTag(AllNodes(i).Label);
                t = atan2(AllNodes(i).Position(2), AllNodes(i).Position(1));
                if abs(t) > pi/2
                    AllNodes(i).TextLabel.Rotation = 180*(t/pi + 1);
                else
                    AllNodes(i).TextLabel.Rotation = t*180/pi;
                end
            end
        end
        setappdata(hFig, 'LobeFullLabel', 1);
    end
end

%% ===== NODE & LABEL SIZE IN SIGNLE FUNCTION =====
function SetNodeLabelSize(hFig, NodeSize, LabelSize)
    AllNodes = getappdata(hFig, 'AllNodes');
    for i = 1:size(AllNodes, 2)
        Node = AllNodes(i);
        set(Node.NodeMarker, 'MarkerSize', NodeSize);
        set(Node.TextLabel, 'FontSize', LabelSize);
    end     
    setappdata(hFig, 'NodeSize', NodeSize);
    setappdata(hFig, 'LabelSize', LabelSize);
    % Save options permanently
    DispOptions = bst_get('ConnectGraphOptions');
    DispOptions.NodeSize = NodeSize;
    DispOptions.LabelSize = LabelSize;
    bst_set('ConnectGraphOptions', DispOptions);
end
    
%% ===== LINK SIZE =====
function SetLinkSize(hFig, LinkSize)
    if (isappdata(hFig, 'MeasureLinks'))
        MeasureLinks = getappdata(hFig, 'MeasureLinks');
        set(MeasureLinks, 'LineWidth', LinkSize);
    end
    if (isappdata(hFig, 'MeasureArrows'))
        MeasureArrows = getappdata(hFig, 'MeasureArrows');
        set(MeasureArrows, 'LineWidth', LinkSize);
    end
    if (isappdata(hFig, 'RegionLinks'))
        RegionLinks = getappdata(hFig, 'RegionLinks');
        set(RegionLinks, 'LineWidth', LinkSize);
    end
    if (isappdata(hFig, 'RegionArrows'))
        RegionArrows = getappdata(hFig, 'RegionArrows');
        set(RegionArrows, 'LineWidth', LinkSize);
    end
    % set new size
    setappdata(hFig, 'LinkSize', LinkSize);
    % Save options permanently
    DispOptions = bst_get('ConnectGraphOptions');
    DispOptions.LinkSize = LinkSize;
    bst_set('ConnectGraphOptions', DispOptions);
end
 
%% ===== LINK TRANSPARENCY ===== 
% Removed in new visualization tool, as color blending is not supported
% with MATLAB graphics

 
%% ===== BACKGROUND COLOR =====
function SetBackgroundColor(hFig, BackgroundColor)
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
                if ~isequal(AllNodes(i).TextLabel.Color, [0.5 0.5 0.5])
                    set(AllNodes(i).TextLabel, 'Color', ~BackgroundColor);
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
    SetBackgroundColor(hFig, BackgroundColor)
end
 
function SetDisplayMeasureMode(hFig, DisplayOutwardMeasure, DisplayInwardMeasure, DisplayBidirectionalMeasure, Refresh)
    if (nargin < 5)
        bst_progress('start', 'Functional Connectivity Display', 'Updating figures...');
        Refresh = 1;
    end
    % Get selected rows
    selNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
    if (Refresh)
        % Remove previous links
        SetSelectedNodes(hFig, selNodes, 0);
    end
    % Update display mode
    setappdata(hFig, 'DisplayOutwardMeasure', DisplayOutwardMeasure);
    setappdata(hFig, 'DisplayInwardMeasure', DisplayInwardMeasure);
    setappdata(hFig, 'DisplayBidirectionalMeasure', DisplayBidirectionalMeasure);
    % ----- User convenience code -----
    RefreshBinaryStatus(hFig);
    if (Refresh)
        % Redraw selected nodes
        SetSelectedNodes(hFig, selNodes, 1);
        bst_progress('stop');
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
function RefreshTextDisplay(hFig)
    FigureHasText = getappdata(hFig, 'FigureHasText');
    if FigureHasText
        AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
        MeasureNodes = bst_figures('GetFigureHandleField', hFig, 'MeasureNodes');
        ValidNode = bst_figures('GetFigureHandleField', hFig, 'ValidNode');

        nVertices = size(AgregatingNodes, 2) + size(MeasureNodes, 2);
        VisibleText = zeros(nVertices, 1);

        TextDisplayMode = getappdata(hFig, 'TextDisplayMode');
        if ismember(1, TextDisplayMode)
            VisibleText(MeasureNodes) = ValidNode(MeasureNodes);
        end
        if (ismember(2, TextDisplayMode) &&  getappdata(hFig, 'HierarchyNodeIsVisible'))
            VisibleText(AgregatingNodes) = ValidNode(AgregatingNodes);
        end
        if ismember(3, TextDisplayMode) 
            selNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
            VisibleText(selNodes) = ValidNode(selNodes);
        end
        
        % Update text visibility
        AllNodes = getappdata(hFig, 'AllNodes');
        for i = 1:length(VisibleText)
            if (VisibleText(i) == 1)
                AllNodes(i).TextLabel.Visible = 'on';
            else
               AllNodes(i).TextLabel.Visible = 'off';
            end
        end
        
        HideExtraLobeNode(hFig);
    end
end
 
%% ===== SET DATA THRESHOLD =====
function SetDataThreshold(hFig, DataThreshold) %#ok<DEFNU>
    % Get selected rows
    SelNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
    % Remove previous links
    SetSelectedNodes(hFig, SelNodes, 0);
    % Update threshold
    setappdata(hFig, 'DataThreshold', DataThreshold);
    % Redraw selected nodes
    SetSelectedNodes(hFig, SelNodes, 1);
end
 
%% ===== UTILITY FUNCTIONS =====
function NodeIndex = GetAgregatedNodesFrom(hFig, AgregatingNodeIndex)
    NodeIndex = [];
    AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
    if ismember(AgregatingNodeIndex, AgregatingNodes)
        NodePaths = bst_figures('GetFigureHandleField', hFig, 'NodePaths');
        member = cellfun(@(x) ismember(AgregatingNodeIndex, x), NodePaths);
        NodeIndex = find(member == 1);
    end
end
 
%% ===== CREATE AND ADD NODES TO DISPLAY =====
function ClearAndAddNodes(hFig, V, Names)
    % get calculated nodes
    MeasureNodes = bst_figures('GetFigureHandleField', hFig, 'MeasureNodes');
    AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
    DisplayedNodes = find(bst_figures('GetFigureHandleField', hFig, 'ValidNode'));
    DisplayedMeasureNodes = MeasureNodes(ismember(MeasureNodes, DisplayedNodes));
    
    NumberOfMeasureNode = length(DisplayedMeasureNodes);
    nAgregatingNodes = length(AgregatingNodes);
    nVertices = size(V, 1);
    
    % --- Clear any previous nodes or links ---- %
    if (isappdata(hFig, 'AllNodes')) 
        DeleteAllNodes(hFig);
        rmappdata(hFig, 'AllNodes');
    end
    if (isappdata(hFig, 'MeasureLinks'))
        delete(getappdata(hFig, 'MeasureLinks'));
        rmappdata(hFig, 'MeasureLinks');
    end
    if (isappdata(hFig, 'RegionLinks'))
        delete(getappdata(hFig, 'RegionLinks'));
        rmappdata(hFig, 'RegionLinks');
    end
    if (isappdata(hFig, 'MeasureArrows'))
        delete(getappdata(hFig, 'MeasureArrows'));
        rmappdata(hFig, 'MeasureArrows');
    end
    if (isappdata(hFig, 'RegionArrows'))
        delete(getappdata(hFig, 'RegionArrows'));
        rmappdata(hFig, 'RegionArrows');
    end
    
    % --- CREATE AND ADD NODES TO DISPLAY ---- %
    % Create nodes as array of node structs (loop backwards to pre-allocate)
    NodeSize = getappdata(hFig, 'NodeSize');
    LabelSize = getappdata(hFig, 'LabelSize'); 
    for i = nVertices:-1:1
        IsAgregatingNode = false;
        if (i <= nAgregatingNodes)
            IsAgregatingNode = true; 
        end
        if (isempty(Names(i)) || isempty(Names{i}))
            Names{i} = ''; % Blank name if none is assigned
        end
        AllNodes(i) = CreateNode(hFig, V(i, 1), V(i, 2), i, Names(i), IsAgregatingNode, NodeSize, LabelSize);
    end 
    
    % Measure Nodes are color coded to their Scout counterpart
    RowColors = bst_figures('GetFigureHandleField', hFig, 'RowColors');
    if ~isempty(RowColors)
        for i = 1:size(RowColors,1)
            AllNodes(nAgregatingNodes+i).Color = RowColors(i, :);
            AllNodes(nAgregatingNodes+i).NodeMarker.Color = RowColors(i, :);
            AllNodes(nAgregatingNodes+i).NodeMarker.MarkerFaceColor = RowColors(i, :); % set marker fill color
        end 
    end
    
    % check if saved user pref wants abbr. lobe labels
    if (~getappdata(hFig, 'LobeFullLabel'))
        % display abbr form and horizontal angle
        for i = 1:length(AllNodes)
            if (AllNodes(i).IsAgregatingNode)
                AllNodes(i).TextLabel.String = AllNodes(i).Label;
                AllNodes(i).TextLabel.Rotation = 0;
            end
        end
    end
    setappdata(hFig, 'AllNodes', AllNodes); % Very important!
    
    % refresh display extent
    axis image; %fit display to all objects in image
    ax = hFig.CurrentAxes; %z-axis on default
    ax.Visible = 'off';
    
    FigureHasText = NumberOfMeasureNode <= 500;
    setappdata(hFig, 'FigureHasText', FigureHasText);    
end
 
%% Create A New Node with NodeMarker and TextLabel graphics objs
% Note: each node is a struct with the following fields:
%   Node.Position           - [x, y] coordinates
%   Node.IsAgregatingNode   - true/false (if this node is a grouped node)
%   Node.Color              - colour of the ROI/associated scout, or grey on default
%   Node.NodeMarker         - Line Object reprenting the node on the figure
%   Node.TextLabel          - Text Object representing the node label on the figure
%   NOTE: Node.NodeMarker.Userdata to store useful node data for node ID
%   when clicking
function Node = CreateNode(hFig, xPos, yPos, Index, Label, IsAgregatingNode, NodeSize, LabelSize)
    Node = struct();
    Node.Position = [xPos, yPos];
    Node.IsAgregatingNode = IsAgregatingNode;
    Node.Color = [0.5 0.5 0.5];
    Node.Label = Label;

    % Get figure axes
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'AxesConnect');
    
    % Mark the node as a Matlab Line graphic object
    set(0, 'CurrentFigure', hFig);
    Node.NodeMarker = line(...
        Node.Position(1), ...
        Node.Position(2), ...
        1, ...                              #z coordinate higher to allow for node click on top of links
        'Color', Node.Color, ...
        'Marker', 'o', ...                    # Marker symbol when the node is selected 'on'
        'MarkerFaceColor', Node.Color, ...   # Marker is default node color when 'on', grey when 'off'
        'MarkerSize', NodeSize, ...                 
        'LineStyle', 'none', ...
        'Visible', 'on', ...
        'PickableParts', 'all', ...
        'ButtonDownFcn', @NodeButtonDownFcn, ...
        'UserData', Index, ... % store node index so that we can ID the nodes when clicked
        'Parent', hAxes);
    
    % Create label as Matlab Text obj 
    Node.TextLabel = text(0, 0, Node.Label, 'Interpreter', 'none', 'Color', [1 1 1], 'ButtonDownFcn', @LabelButtonDownFcn, 'UserData', Index); 
    Node.TextLabel.Position = 1.05*Node.Position; %need offset factor so label doesn't overlap
    Node.TextLabel.FontSize = LabelSize;
    Node.TextLabel.FontWeight = 'normal'; % not bold by default
    
    % default full labels for lobes (user toggle with 'l' or popup menu)
    if (IsAgregatingNode)
        Node.TextLabel.String = LobeTagToFullTag(Node.Label);
    end    
    
    %rotate and align labels
    t = atan2(Node.Position(2), Node.Position(1));
    if abs(t) > pi/2
        Node.TextLabel.Rotation = 180*(t/pi + 1);
        Node.TextLabel.HorizontalAlignment = 'right';
    else
        Node.TextLabel.Rotation = t*180/pi;
    end    
    
    % show node as 'selected' as default
    SelectNode(hFig, Node, true);
end

% To visually change the appearance of sel/unsel nodes
function SelectNode(hFig, Node, IsSelected)
    % user adjust node size as desired
    NodeSize = getappdata(hFig, 'NodeSize');
    if IsSelected % node is SELECTED ("ON")
        % return to original node colour, shape, and size
        Node.NodeMarker.Marker = 'o';
        Node.NodeMarker.Color = Node.NodeMarker.MarkerFaceColor;
        Node.NodeMarker.MarkerSize = NodeSize;
        Node.TextLabel.Color =  ~getappdata(hFig, 'BgColor');
    else % node is NOT selected ("OFF")
        % display as a grey 'X' (slightly bigger/bolded to allow for easier clicking shape)
        % node labels also greyed out
        Node.NodeMarker.Marker = 'x';
        Node.NodeMarker.Color =  [0.5 0.5 0.5]; % grey marker
        Node.NodeMarker.MarkerSize = NodeSize + 1;
        Node.TextLabel.Color = [0.5 0.5 0.5]; % grey label
    end
end

%% Callbacks for clicked NodeMarker or Label on figure
% NOTE: we use functions within NodeClickedEvent(), SetSelectedNodes(), and
% SelectNode() to set actual node and link selection display. All we need 
% to do here is store the index of the clicked node
function NodeButtonDownFcn(src, ~)
    global GlobalData;
    GlobalData.FigConnect.ClickedNodeIndex = src.UserData;
end

function LabelButtonDownFcn(src, ~)
    global GlobalData;
    GlobalData.FigConnect.ClickedNodeIndex = src.UserData;
end

%% Delete all node structs and associated graphics objs if exist
function DeleteAllNodes(hFig)
    AllNodes = getappdata(hFig, 'AllNodes');    
    % delete TextLabel Text Objects
    if isfield(AllNodes, 'TextLabel')
        for i = 1:length(AllNodes)
            delete(AllNodes(i).TextLabel);
        end
    end
    % delete NodeMarker Line Objects
    if isfield(AllNodes, 'NodeMarker')
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
            if (size(Region, 2) >= 3)
                if (strcmp(Region(3), 'F'))
                    Index = 1;
                end
            end
        case 'O' %Occipital
            Index = 6;
        case 'L' %Limbic
            Index = 7;
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
        case 7
            Tag = 'L';
    end
end
 
function FullTag = LobeTagToFullTag(Tag)
    if strcmp(Tag, 'PF')
        FullTag = 'Pre-Frontal';
    elseif strcmp(Tag, 'F')
        FullTag = 'Frontal';
    elseif strcmp(Tag, 'C')
        FullTag = 'Central';       
    elseif strcmp(Tag, 'T')
        FullTag = 'Temporal';
    elseif strcmp(Tag, 'P')
        FullTag = 'Parietal';
    elseif strcmp(Tag, 'O')
        FullTag = 'Occipital';
    elseif strcmp(Tag, 'L')
        FullTag = 'Limbic';
    elseif strcmp(Tag, 'U')
        FullTag = 'Unknown';
    else
        FullTag = Tag;
    end
end
 
function [sGroups] = GroupScouts(Atlas)
    NumberOfGroups = 0;
    sGroups = repmat(struct('Name', [], 'RowNames', [], 'Region', {}), 0);
    NumberOfScouts = size(Atlas.Scouts, 2);
    for i = 1:NumberOfScouts
        Region = Atlas.Scouts(i).Region;
        GroupID = find(strcmp({sGroups.Region}, Region));
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
    
    if size(sGroups, 2) == 1 && strcmp(sGroups(1).Region, 'UU') == 1
        sGroups = [];
        return;
    end
    
    % Sort by Hemisphere and Lobe
    for i = 2:NumberOfGroups
        j = i;
        sTemp = sGroups(i);
        CurHem = HemisphereTagToIndex(sGroups(i).Region);
        CurLobe = LobeTagToIndex(sGroups(i).Region);
        while ((j > 1))
            Current = CurHem;
            Next = HemisphereTagToIndex(sGroups(j-1).Region);
            if (Current == Next)
                Current = CurLobe;
                Next = LobeTagToIndex(sGroups(j-1).Region);
            end
            if (Next <= Current)
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
    NumberOfMeasureNodes = size(aNames, 1);
    NumberOfGroups = size(sGroups, 2);
    NumberOfLobes = 7;
    NumberOfHemispheres = 2;
    NumberOfLevels = 5;
        
    % Extract only the first region letter of each group
    HemisphereRegions = cellfun(@(x) {x(1)}, {sGroups.Region})';
    LobeRegions = cellfun(@(x) {LobeIndexToTag(LobeTagToIndex(x))}, {sGroups.Region})';
    
    LeftGroupsIndex = strcmp('L', HemisphereRegions) == 1;
    RightGroupsIndex = strcmp('R', HemisphereRegions) == 1;
    CerebellumGroupsIndex = strcmp('C', HemisphereRegions) == 1;
    UnknownGroupsIndex = strcmp('U', HemisphereRegions) == 1;
    
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
    Levels = cell(NumberOfLevels, 1);
    Levels{5} = 1;
    Levels{4} = (2:(NumberOfHemispheres+1))';
    
    Lobes = [];
    NumberOfNodesPerLobe = zeros(NumberOfLobes * 2, 1);
    for i = 1:NumberOfLobes
        Tag = LobeIndexToTag(i);
        RegionsIndex = strcmp(Tag, LobeRegions) == 1;
        NodesInLeft = [sGroups(LeftGroupsIndex & RegionsIndex).RowNames];
        NodesInRight = [sGroups(RightGroupsIndex & RegionsIndex).RowNames];
        NumberOfNodesPerLobe(i) = length(NodesInLeft);
        NumberOfNodesPerLobe(NumberOfLobes + i) = length(NodesInRight);
        if (size(NodesInLeft, 2) > 0 || size(NodesInRight, 2) > 0)
            Lobes = [Lobes i];
        end
    end
    
    % Actual number of lobes with data
    NumberOfLobes = size(Lobes, 2);
    
    % Start and end angle for each lobe section
    % We use a constant separation for each lobe
    AngleStep = (AngleAllowed(2) - AngleAllowed(1))/ NumberOfLobes;
    LobeSections = zeros(NumberOfLobes, 2);
    LobeSections(:, 1) = 0:NumberOfLobes-1;
    LobeSections(:, 2) = 1:NumberOfLobes;
    LobeSections(:, :) = AngleAllowed(1) + LobeSections(:, :) * AngleStep;
    
    NumberOfAgregatingNodes = 1 + NumberOfHemispheres + NumberOfLobes * 2 + NumberOfGroups;
    NumberOfVertices = NumberOfMeasureNodes + NumberOfAgregatingNodes;
    Vertices = zeros(NumberOfVertices, 3);
    Names = cell(NumberOfVertices, 1);
    Paths = cell(NumberOfVertices, 1);
    ChannelData = zeros(NumberOfVertices, 3);
    
    % Static Nodes
    Vertices(1, :) = [0 0 0];                    % Corpus Callosum
    Vertices(2, :) = [-HemisphereLevel 0 0];     % Left Hemisphere
    Vertices(3, :) = [ HemisphereLevel 0 0];     % Right Hemisphere
    if (nCerebellum > 0)
        Vertices(4, :) = [ 0 -HemisphereLevel 0];    % Cerebellum
        Names(4) = {''};
        Paths{4} = [4 1];
        ChannelData(4, :) = [0 0 3];
    end
    Names(1) = {''};
    Names(2) = {'Left'};
    Names(3) = {'Right'};
    Paths{1} = 1;
    Paths{2} = [2 1];
    Paths{3} = [3 1];
    ChannelData(2, :) = [0 0 1];
    ChannelData(3, :) = [0 0 2];
    
    % The lobes are determined by the mean of the regions nodes
    % The regions nodes are determined by the mean of their nodes
    % Organise Left Hemisphere
    RegionIndex = 1 + NumberOfHemispheres + NumberOfLobes * 2 + 1;
    for i = 1:NumberOfLobes
        Lobe = i;
        LobeIndex = Lobe + NumberOfHemispheres + 1;
        Levels{3} = [Levels{3}; LobeIndex];
        Angle = 90 + LobeSections(Lobe, 1);
        LobeTag = LobeIndexToTag(Lobes(i));
        RegionMask = strcmp(LobeTag, LobeRegions) == 1 & strcmp('L', HemisphereRegions) == 1;
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
                LobeSpace = LobeSections(Lobe, 2) - LobeSections(Lobe, 1);
                AllowedSpace = AllowedPercent * LobeSpace;
                % +2 is for the offset at borders so regions don't touch        
                LocalTheta = linspace((pi/180) * (Angle), (pi/180) * (Angle + AllowedSpace), NumberOfNodesInGroup + 2);
                % Retrieve cartesian coordinate
                [posX, posY] = pol2cart(LocalTheta(2:(end-1)), 1);
                % Assign
                ChannelsOfThisGroup = ismember(aNames, Group.RowNames);
                % Compensate for agregating nodes
                Index = find(ChannelsOfThisGroup) + NumberOfAgregatingNodes;
                % Update node information
                Order = 1:size(Index, 1);
                if ~isempty(RowLocs)
                    [tmp, Order] = sort(RowLocs(ChannelsOfThisGroup, 1), 'descend');
                end
                Vertices(Index(Order), 1:2) = [posX' posY'] * MeasureLevel;
                Names(Index) = aNames(ChannelsOfThisGroup);
                Paths(Index) = mat2cell([Index repmat([RegionIndex LobeIndex 2 1], size(Index))], ones(1, size(Index, 1)), 5);
                ChannelData(Index, :) = repmat([RegionIndex Lobes(Lobe) 1], size(Index));
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
                ChannelData(RegionIndex, :) = [RegionIndex Lobes(Lobe) 1];
                % Update current angle
                Angle = Angle + AllowedSpace;
            end
            RegionIndex = RegionIndex + 1;
        end
        
        Pos = 90 + (LobeSections(Lobe, 2) + LobeSections(Lobe, 1)) / 2;
        [posX, posY] = pol2cart((pi/180) * (Pos), 1);
        Vertices(LobeIndex, 1:2) = [posX, posY] * LobeLevel;
        Names(LobeIndex) = {LobeTag};
        Paths(LobeIndex) = {[LobeIndex 2 1]};
        ChannelData(LobeIndex, :) = [0 Lobes(Lobe) 1];
    end
    
    % Organise Right Hemisphere
    for i = 1:NumberOfLobes
        Lobe = i;
        LobeIndex = Lobe + NumberOfLobes + NumberOfHemispheres + 1;
        Levels{3} = [Levels{3}; LobeIndex];
        Angle = 90 - LobeSections(Lobe, 1);
        LobeTag = LobeIndexToTag(Lobes(i));
        RegionMask = strcmp(LobeTag, LobeRegions) == 1 & strcmp('R', HemisphereRegions) == 1;
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
                LobeSpace = LobeSections(Lobe, 2) - LobeSections(Lobe, 1);
                AllowedSpace = AllowedPercent * LobeSpace;
                % +2 is for the offset at borders so regions don't touch        
                LocalTheta = linspace((pi/180) * (Angle), (pi/180) * (Angle - AllowedSpace), NumberOfNodesInGroup + 2);
                % Retrieve cartesian coordinate
                [posX, posY] = pol2cart(LocalTheta(2:(end-1)), 1);
                % Assign
                ChannelsOfThisGroup = ismember(aNames, Group.RowNames);
                % Compensate for agregating nodes
                Index = find(ChannelsOfThisGroup) + NumberOfAgregatingNodes;
                % Update node information
                Order = 1:size(Index, 1);
                if ~isempty(RowLocs)
                    [~, Order] = sort(RowLocs(ChannelsOfThisGroup, 1), 'descend');
                end
                Vertices(Index(Order), 1:2) = [posX' posY'] * MeasureLevel;
                Names(Index) = aNames(ChannelsOfThisGroup);
                Paths(Index) = mat2cell([Index repmat([RegionIndex LobeIndex 3 1], size(Index))], ones(1, size(Index, 1)), 5);
                ChannelData(Index, :) = repmat([RegionIndex Lobes(Lobe) 2], size(Index));
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
                ChannelData(RegionIndex, :) = [RegionIndex Lobes(Lobe) 2];
                % Update current angle
                Angle = Angle - AllowedSpace;
            end
            RegionIndex = RegionIndex + 1;
        end
        
        Pos = 90 - (LobeSections(Lobe, 2) + LobeSections(Lobe, 1)) / 2;
        [posX, posY] = pol2cart((pi/180) * (Pos), 1);
        Vertices(LobeIndex, 1:2) = [posX, posY] * LobeLevel;
        Names(LobeIndex) = {LobeTag};
        Paths(LobeIndex) = {[LobeIndex 3 1]};
        ChannelData(LobeIndex, :) = [0 Lobes(Lobe) 2];
    end
    
    % Organise Cerebellum
    if (nCerebellum > 0)
        Angle = 270 - 15;
        NodesInCerebellum = [sGroups(CerebellumGroupsIndex).RowNames];
        NumberOfNodesInCerebellum = size(NodesInCerebellum, 2);
        RegionMask = strcmp('C', HemisphereRegions) == 1;
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
                [posX, posY] = pol2cart(LocalTheta(2:(end-1)), 1);
                % Assign
                ChannelsOfThisGroup = ismember(aNames, Group.RowNames);
                % Compensate for agregating nodes
                Index = find(ChannelsOfThisGroup) + NumberOfAgregatingNodes;
                Order = 1:size(Index, 1);
                if ~isempty(RowLocs)
                    [~, Order] = sort(RowLocs(ChannelsOfThisGroup, 1), 'descend');
                end
                Vertices(Index(Order), 1:2) = [posX' posY'] * MeasureLevel;
                Names(Index) = aNames(ChannelsOfThisGroup);
                Paths(Index) = mat2cell([Index repmat([RegionIndex 4 1 1], size(Index))], ones(1, size(Index, 1)), 5);
                ChannelData(Index, :) = repmat([RegionIndex 0 0], size(Index));
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
                ChannelData(RegionIndex, :) = [RegionIndex 0 0];
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
        NumberOfNodesInUnknown = size(NodesInUnknown, 2);
        RegionMask = strcmp('U', HemisphereRegions) == 1;
        RegionNodeIndex = find(RegionMask == 1);
        NumberOfRegionInUnknown = sum(RegionMask);
        for y=1:NumberOfRegionInUnknown
            Levels{2} = [Levels{2}; RegionIndex];
            Group = sGroups(RegionNodeIndex(y));
            Region = [Group.Region];
            NumberOfNodesInGroup = size([Group.RowNames], 2);
            if (NumberOfNodesInGroup > 0)
                % Figure out how much space per node
                AllowedPercent = NumberOfNodesInGroup / NumberOfNodesInUnknown;
                % Static for Cerebellum
                LobeSpace = 30;
                AllowedSpace = AllowedPercent * LobeSpace;
                % +2 is for the offset at borders so regions don't touch        
                LocalTheta = linspace((pi/180) * (Angle), (pi/180) * (Angle + AllowedSpace), NumberOfNodesInGroup + 2);
                % Retrieve cartesian coordinate
                [posX, posY] = pol2cart(LocalTheta(2:(end-1)), 1);
                % Assign
                ChannelsOfThisGroup = ismember(aNames, Group.RowNames);
                % Compensate for agregating nodes
                Index = find(ChannelsOfThisGroup) + NumberOfAgregatingNodes;
                Order = 1:size(Index, 1);
                if ~isempty(RowLocs)
                    [~, Order] = sort(RowLocs(ChannelsOfThisGroup, 1), 'descend');
                end
                Vertices(Index(Order), 1:2) = [posX' posY'] * MeasureLevel;
                Names(Index) = aNames(ChannelsOfThisGroup);
                Paths(Index) = mat2cell([Index repmat([RegionIndex 1 1 1], size(Index))], ones(1, size(Index, 1)), 5);
                ChannelData(Index, :) = repmat([RegionIndex 0 0], size(Index));
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
                ChannelData(RegionIndex, :) = [RegionIndex 0 0];
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
    
    NumberOfMeasureNodes = size(aNames, 1);
    NumberOfGroups = size(sGroups, 2);
    NumberOfAgregatingNodes = 1;
        
    NumberOfLevels = 2;
    if (NumberOfGroups > 1)
        NumberOfLevels = 3;
        NumberOfAgregatingNodes = NumberOfAgregatingNodes + NumberOfGroups;
    end
    % NumberOfLevel = Self + Middle + EverythingInBetween
    Levels = cell(NumberOfLevels, 1);
    Levels{end} = 1;
    
    NumberOfVertices = NumberOfMeasureNodes + NumberOfAgregatingNodes;
    
    % Structure for vertices
    Vertices = zeros(NumberOfVertices, 3);
    Names = cell(NumberOfVertices, 1);
    Paths = cell(NumberOfVertices, 1);
    
    % Static node
    Vertices(1, 1:2) = [0 0];
    Names{1} = ' ';
    Paths{1} = 1;
    
    NumberOfNodesInGroup = zeros(NumberOfGroups, 1);
    GroupsTheta = zeros(NumberOfGroups, 1);
    GroupsTheta(1, 1) = (pi * 0.5);
    for i = 1:NumberOfGroups
        if (i ~= 1)
            GroupsTheta(i, 1) = GroupsTheta(i-1, 2);
        end
        NumberOfNodesInGroup(i) = 1;
        if (iscellstr(sGroups(i).RowNames))
            NumberOfNodesInGroup(i) = size(sGroups(i).RowNames, 2);
        end
        Theta = (NumberOfNodesInGroup(i) / NumberOfMeasureNodes * (2 * pi));
        GroupsTheta(i, 2) = GroupsTheta(i, 1) + Theta;
    end
        
    for i = 1:NumberOfGroups
        LocalTheta = linspace(GroupsTheta(i, 1), GroupsTheta(i, 2), NumberOfNodesInGroup(i) + 1);
        ChannelsOfThisGroup = ismember(aNames, sGroups(i).RowNames);
        Index = find(ChannelsOfThisGroup) + NumberOfAgregatingNodes;
        [posX, posY] = pol2cart(LocalTheta(2:end), 1);
        Vertices(Index, 1:2) = [posX' posY'] * MeasureLevel;
        Names(Index) = sGroups(i).RowNames;
        Paths(Index) = mat2cell([Index ones(size(Index))], ones(1, size(Index, 1)), 2);
        Levels{1} = [Levels{1}; Index];
        
        if (NumberOfLevels > 2)
            RegionIndex = i + 1;
            Paths(Index) = mat2cell([Index repmat([RegionIndex 1], size(Index))], ones(1, size(Index, 1)), 3);
            
            % Update agregating node
            if (NumberOfNodesInGroup(i) == 1)
                Mean = [posX posY];
            else
                Mean = mean([posX' posY']);
            end
            Mean = Mean / norm(Mean);
            Vertices(RegionIndex, 1:2) = Mean * RegionLevel;
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