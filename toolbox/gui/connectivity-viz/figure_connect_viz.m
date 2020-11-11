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
% Cousineau, 2019; Helen Lin & Yaqi Li, 2020

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
	
     % OGL SECTION -- TODO: REPLACE/REMOVE
	% Create rendering panel
   % [OGL, container] = javacomponent(java_create('org.brainstorm.connect.GraphicsFramework'), [0, 0, 500, 400], hFig);
    
    % Resize callback
   % set(hFig, bst_get('ResizeFunction'), @(h,ev)ResizeCallback(hFig, container));
    
    % Other figure (previously Java) callbacks
%     set(OGL, 'MouseClickedCallback',    @(h,ev)JavaClickCallback(hFig,ev));
%     set(OGL, 'MousePressedCallback',    @(h,ev)FigureMouseDownCallback(hFig,ev));
%     set(OGL, 'MouseDraggedCallback',    @(h,ev)FigureMouseMoveCallback(hFig,ev));
%     set(OGL, 'MouseReleasedCallback',   @(h,ev)FigureMouseUpCallback(hFig,ev));
%     set(OGL, 'KeyPressedCallback',      @(h,ev)FigureKeyPressedCallback(hFig,ev));
%     set(OGL, 'KeyReleasedCallback',     @(h,ev)FigureKeyReleasedCallback(hFig,ev));
    
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
    
    % J3D Container
   % setappdata(hFig, 'OpenGLDisplay', OGL);
   % setappdata(hFig, 'OpenGLContainer', container);
    setappdata(hFig, 'TextDisplayMode', 1);
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
% NOTE: updated remove ogl
function Dispose(hFig) %#ok<DEFNU>
    %NOTE: do not need to delete gcf (curr figure) because this is done in
    %bst_figures(DeleteFigure)
    
    %====NEW====
    c = hFig.UserData;
    if (~isempty(c))
        for i = 1:length(c.Nodes)
            delete(c.Nodes(i));
        end
        for i = 1:length(c.testNodes)
            delete(c.testNodes(i));
        end
    end

    
    %===old===
    SetBackgroundColor(hFig, [1 1 1]); %[1 1 1]= white [0 0 0]= black
    
%     OGL = getappdata(hFig, 'OpenGLDisplay');
%     set(OGL, 'MouseClickedCallback',    []);
%     set(OGL, 'MousePressedCallback',    []);
%     set(OGL, 'MouseDraggedCallback',    []);
%     set(OGL, 'MouseReleasedCallback',   []);
%     set(OGL, 'KeyReleasedCallback',     []);
%     set(OGL, 'KeyPressedCallback',      []);
%     set(OGL, 'MouseWheelMovedCallback', []);
%     OGL.resetDisplay();
%     delete(OGL);
%     setappdata(hFig, 'OpenGLDisplay', []);
end


%% ===== RESET DISPLAY =====
% NOTE: ready, updated remove ogl
function ResetDisplay(hFig)
    % Reset display
%     OGL = getappdata(hFig, 'OpenGLDisplay');
%     OGL.resetDisplay();
    
    % Default values
    setappdata(hFig, 'DisplayOutwardMeasure', 1);
    setappdata(hFig, 'DisplayInwardMeasure', 0);
    setappdata(hFig, 'DisplayBidirectionalMeasure', 0);
    setappdata(hFig, 'DataThreshold', 0.5);
    setappdata(hFig, 'DistanceThreshold', 0);
    setappdata(hFig, 'TextDisplayMode', 1);
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

%% ===== RESIZE CALLBACK =====
function ResizeCallback(hFig, container)
    % Update Title     
    RefreshTitle(hFig);
    % Update OpenGL container size
    UpdateContainer(hFig, container);
end

%TODO: remove jogl container
function UpdateContainer(hFig, container)
    % Get figure position
    figPos = get(hFig, 'Position');
    % Get colorbar handle
    hColorbar = findobj(hFig, '-depth', 1, 'Tag', 'Colorbar');
    % Get title handle
    TitlesHandle = getappdata(hFig, 'TitlesHandle');
    titleHeight = 0;
    if (~isempty(TitlesHandle))
        titlePos = get(TitlesHandle(1), 'Position'); 
        titleHeight = titlePos(4);
    end
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
        % Reposition the container
        marginAxes = 0;
        if ~isempty(container)
            
%             set(container, 'Units',    'pixels', ...
%                            'Position', [marginAxes, ...
%                                         marginAxes, ...
%                                         max(1, figPos(3) - colorbarWidth - marginWidth - marginAxes), ... 
%                                         max(1, figPos(4) - 2*marginAxes - titleHeight)]);
        end
        uistack(hColorbar,'top',1);
    else
        if ~isempty(container)
            % Java container can take all the figure space
%             set(container, 'Units',    'normalized', ...
%                            'Position', [.05, .05, .9, .9]);
        end
    end
end

function HasTitle = RefreshTitle(hFig)
    Title = [];
    DisplayInRegion = getappdata(hFig, 'DisplayInRegion');
    if (DisplayInRegion)
        % Organisation level
        OrganiseNode = bst_figures('GetFigureHandleField', hFig, 'OrganiseNode');
        % Label 
        hTitle = getappdata(hFig, 'TitlesHandle');
        % If data are hierarchicaly organised and we are not
        % already at the whole cortical view
        if (~isempty(OrganiseNode) && OrganiseNode ~= 1)
            % Get where we are textually
            PathNames = VerticeToFullName(hFig, OrganiseNode);
            Recreate = 0;
            nLevel = size(PathNames,2);
            if (nLevel ~= size(hTitle,2) || size(hTitle,2) == 0)
                Recreate = 1;
                for i=1:size(hTitle,2)
                    delete(hTitle(i));
                end
                hTitle = [];
            end
            backgroundColor = GetBackgroundColor(hFig);
            figPos = get(hFig, 'Position');
            Width = 1;
            Height = 25;
            X = 10;
            Y = figPos(4) - Height;
            for i=1:nLevel
                Title = PathNames{i};
                if (Recreate)
                    hTitle(i) = uicontrol( ...
                                       'Style',               'pushbutton', ...
                                       'Enable',              'inactive', ...
                                       'String',              Title, ...
                                       'Units',               'Pixels', ...
                                       'Position',            [0 0 1 1], ...
                                       'HorizontalAlignment', 'center', ...
                                       'FontUnits',           'points', ...
                                       'FontSize',            bst_get('FigFont'), ...
                                       'ForegroundColor',     [0 0 0], ...
                                       'BackgroundColor',     backgroundColor, ...
                                       'HitTest',             'on', ...
                                       'Parent',              hFig, ...
                                       'Callback', @(h,ev)bst_call(@SetExplorationLevelTo,hFig,nLevel-i));
                    set(hTitle(i), 'ButtonDownFcn', @(h,ev)bst_call(@SetExplorationLevelTo,hFig,nLevel-i), ...
                                   'BackgroundColor',     backgroundColor);
                end
                X = X + Width;
                Size = get(hTitle(i), 'extent');
                Width = Size(3) + 10;
                % Minimum width so all buttons look the same
                if (Width < 50)
                    Width = 50;
                end
                set(hTitle(i), 'String',            Title, ...
                               'Position',          [X Y Width Height], ...
                               'BackgroundColor',   backgroundColor);
            end
        else
            for i=1:size(hTitle,2)
                delete(hTitle(i));
            end
            hTitle = [];
        end
        setappdata(hFig, 'TitlesHandle', hTitle);
        UpdateContainer(hFig, getappdata(hFig, 'OpenGLContainer'));
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
    % TODO: remove java canvas once prototype complete
    % Mouse click callbacks include:
        % Right-click for popup menu (NOTE: DONE)
        % Double click to reset display (NOTE: DONE)
        % SHIFT+CLICK to move/pan camera (NOTE: DONE)
        % CLICK colorbar to change colormap, double-click colorbar to reset
        % (NOTE: DONE)
function FigureMouseDownCallback(hFig, ev)   
    % Check if MouseUp was executed before MouseDown: Should ignore this MouseDown event
    if isappdata(hFig, 'clickAction') && strcmpi(getappdata(hFig,'clickAction'), 'MouseDownNotConsumed')
        return;
    end
    
    % TODO: remove java canvas, use key events in MATLAB
    if ~isempty(ev) 
        if isjava(ev) % Click on the Java canvas
            if ((ev.getButton() == ev.BUTTON3) || (ev.getButton() == ev.BUTTON2))
                clickAction = 'popup'; % pop-up menu on right-click
            else
                clickAction = 'MouseMoveCamera';
            end
            clickPos = [ev.getX() ev.getY()];
        else % click from Matlab figure
            if strcmpi(get(hFig, 'SelectionType'), 'alt')
                clickAction = 'popup';
            elseif strcmpi(get(hFig, 'SelectionType'), 'open')
                %double-click to reset display
                clickAction = 'ResetCamera';
            else
                clickAction = 'MouseMoveCamera';
            end
            clickPos = get(hFig, 'CurrentPoint');
        end
    % Click on the Matlab colorbar
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
        case 'MouseMoveCamera'
            %check SHIFT+MOUSEMOVE
             MouseMoveCamera = getappdata(hFig, 'MouseMoveCamera');
             if isempty(MouseMoveCamera)
                 MouseMoveCamera = 0;
             end
             if (MouseMoveCamera)
                 motion = -motionFigure * 0.05;
                 MoveCamera(hFig, [motion(1) motion(2) 0]);
             else
                 % ENABLE THE CODE BELOW TO ENABLE THE ROTATION
                 %motion = -motionFigure * 0.01;
                 %RotateCameraAlongAxis(hFig, -motion(2), motion(1));
             end
    end
end


%% ===== FIGURE MOUSE UP CALLBACK =====
function FigureMouseUpCallback(hFig, varargin)
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
        end
    % ===== MOUSE HAS MOVED =====
    else
        if strcmpi(clickAction, 'colorbar')
            % Apply new colormap to all figures
            ColormapInfo = getappdata(hFig, 'Colormap');
            bst_colormaps('FireColormapChanged', ColormapInfo.Type);
        end
    end
end


%% ===== FIGURE KEY PRESSED CALLBACK =====
function FigureKeyPressedCallback(hFig, keyEvent)
    global ConnectKeyboardMutex;
    % Convert to Matlab key event
    [keyEvent, tmp, tmp] = gui_brainstorm('ConvertKeyEvent', keyEvent);
    if isempty(keyEvent.Key)
        return;
    end
    % Set a mutex to prevent to enter twice at the same time in the routine
    if (isempty(ConnectKeyboardMutex))
        tic;
        % Set mutex
        ConnectKeyboardMutex = 0.1;
        % Process event
        switch (keyEvent.Key)
            case 't'                            %TODO: remove test
                 test(hFig);
            case 'a'
                SetSelectedNodes(hFig, [], 1, 1);   %TODO
            case 'b'
                ToggleBlendingMode(hFig);           %TODO
            case 'l'
                ToggleTextDisplayMode(hFig);         % DONE
            case 'h'                            %TODO
                HierarchyNodeIsVisible = getappdata(hFig, 'HierarchyNodeIsVisible');
                HierarchyNodeIsVisible = 1 - HierarchyNodeIsVisible;
                SetHierarchyNodeIsVisible(hFig, HierarchyNodeIsVisible);
            case 'd'                    %TODO
                ToggleDisplayMode(hFig);
            case 'm'                    %TODO
                ToggleMeasureToRegionDisplay(hFig)
            case 'q'                    %TODO
                RenderInQuad = 1 - getappdata(hFig, 'RenderInQuad');
                setappdata(hFig, 'RenderInQuad', RenderInQuad)
                OGL = getappdata(hFig, 'OpenGLDisplay');
                OGL.renderInQuad(RenderInQuad)
                OGL.repaint();
            case {'+', 'add'}             %TODO
                panel_display('ConnectKeyCallback', keyEvent);
            case {'-', 'subtract'}              %TODO
                panel_display('ConnectKeyCallback', keyEvent);
            case 'leftarrow'                    %TODO
                ToggleRegionSelection(hFig, 1);
            case 'rightarrow'                    %TODO
                ToggleRegionSelection(hFig, -1);
            case 'uparrow'          %DONE - oct 20 2020
                % zoom in
                ZoomCamera(hFig, 0.95 ); % zoom in
            case 'downarrow'        %DONE - oct 20 2020
                % zoom out
                ZoomCamera(hFig, 1.05); % zoom out
            case 'escape'           %TODO
                SetExplorationLevelTo(hFig, 1);
            case 'shift'            %DONE - oct 20 2020
                % SHIFT+CLICK to move camera horizontally/vertically
                setappdata(hFig, 'MouseMoveCamera', 1);
        end
        %ConnectKeyboardMutex = [];
    else
        % Release mutex if last keypress was processed more than one 2s ago
        t = toc;
        if (t > ConnectKeyboardMutex)
            ConnectKeyboardMutex = [];
        end
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
        case 'shift'  % no longer panning/hor. translation
            setappdata(hFig, 'MouseMoveCamera', 0);
    end
end

function SetExplorationLevelTo(hFig, Level)
    % Last reorganisation
    OrganiseNode = bst_figures('GetFigureHandleField', hFig, 'OrganiseNode');
    if (isempty(OrganiseNode) || OrganiseNode == 1)
        return;
    end
    Paths = bst_figures('GetFigureHandleField', hFig, 'NodePaths');
    Path = Paths{OrganiseNode};
    NextAgregatingNode = Path(find(Path == OrganiseNode) + Level);
    if (NextAgregatingNode ~= OrganiseNode)
        bst_figures('SetFigureHandleField', hFig, 'OrganiseNode', NextAgregatingNode);
        UpdateFigurePlot(hFig);
    end
end

function NextNode = getNextCircularRegion(hFig, Node, Inc)
    % Construct Spiral Index
    Levels = bst_figures('GetFigureHandleField', hFig, 'Levels');
    DisplayNode = find(bst_figures('GetFigureHandleField', hFig, 'DisplayNode'));
    CircularIndex = [];
    for i=1:size(Levels,1)
        CircularIndex = [CircularIndex; Levels{i}];
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
    % Is node an agregating node
    IsAgregatingNode = ismember(NextNode, AgregatingNodes);
    if (IsAgregatingNode)
        % Get agregated nodes
        AgregatedNodeIndex = getAgregatedNodesFrom(hFig, NextNode); 
        if (~isempty(AgregatedNodeIndex))
            % Select agregated node
            SetSelectedNodes(hFig, AgregatedNodeIndex, 1, 1);
        end    
    end
    % Select node
    SetSelectedNodes(hFig, NextNode, 1, 1);
end


%% ===== JAVA MOUSE CLICK CALLBACK =====
% TODO: convert to matlab callbacks
function JavaClickCallback(hFig, ev)
    % Retrieve button
    ButtonClicked = ev.get('Button');
    ClickCount = ev.get('ClickCount');
    if (ButtonClicked == 1)
        % OpenGL handle
        OGL = getappdata(hFig,'OpenGLDisplay');
        % Minimum distance. 1 is difference between level order of distance
        minimumDistanceThreshold = 0.2;
        % '+1' is to account for the different indexing in Java and Matlab
        nodeIndex = OGL.raypickNearestNode(ev.getX(), ev.getY(), minimumDistanceThreshold) + 1;
        % If a visible node is clicked on
        if (nodeIndex > 0)
            DisplayNode = bst_figures('GetFigureHandleField', hFig, 'DisplayNode');
            if (DisplayNode(nodeIndex) == 1)
                % Get selected nodes
                selNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
                % Get agregating nodes
                MeasureNodes    = bst_figures('GetFigureHandleField', hFig, 'MeasureNodes');
                AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
                % Is the node already selected ?
                AlreadySelected = any(selNodes == nodeIndex);
                % Is the node an agregating node ?
                IsAgregatingNode = any(AgregatingNodes == nodeIndex);

                if (ClickCount == 1)
                    % If node is already select
                    if AlreadySelected
                        % If all the nodes are selected, then select only this one
                        if all(ismember(MeasureNodes, selNodes))
                            SetSelectedNodes(hFig, [], 0);
                            AlreadySelected = 0;
                        % If it's the only selected node, then select all
                        elseif (length(selNodes) == 1)
                            SetSelectedNodes(hFig, [], 1);
                            return;
                        end
                        % Aggragtive nodes: select blocks of nodes
                        if IsAgregatingNode
                            % Get agregated nodes
                            AgregatedNodeIndex = getAgregatedNodesFrom(hFig, nodeIndex);
                            % How many are already selected
                            NodeAlreadySelected = ismember(AgregatedNodeIndex, selNodes);
                            % Get selected agregated nodes
%                             AgregatingNodeAlreadySelected = ismember(AgregatingNodes, selNodes);
                            % If the agregating node and his measure node are the only selected nodes, then select all
                            if (sum(NodeAlreadySelected) == size(selNodes,1))
                                SetSelectedNodes(hFig, [], 1);
                                return;
                            end
                        end
                    end
                    
                    % Select picked node
                    Select = 1;
                    if (AlreadySelected)
                        % Deselect picked node
                        Select = 0;
                    end

                    % If shift is not pressed, deselect all node
                    isShiftDown = ev.get('ShiftDown');
                    if (strcmp(isShiftDown,'off'))
                        % Deselect
                        SetSelectedNodes(hFig, selNodes, 0, 1);
                        % Deselect picked node
                        Select = 1;
                    end
                
                    if (IsAgregatingNode)
                        % Get agregated nodes
                        SelectNodeIndex = getAgregatedNodesFrom(hFig, nodeIndex);
                        % Select
                        SetSelectedNodes(hFig, [SelectNodeIndex(:); nodeIndex], Select);
                        % Go up the hierarchy
                        UpdateHierarchySelection(hFig, nodeIndex, Select);
                    else
                        SetSelectedNodes(hFig, nodeIndex, Select);
                    end
                else
                    disp('BST> Zoom into a region: Feature disabled until fixed.');
                    return;
                    
                    if (IsAgregatingNode)
                        OrganiseNode = bst_figures('GetFigureHandleField', hFig, 'OrganiseNode');
                        if isempty(OrganiseNode)
                            OrganiseNode = 1;
                        end
                        % If it's the same, don't reload for nothing..
                        if (OrganiseNode == nodeIndex)
                            return;
                        end
                        % If there's only one node, useless update
                        AgregatedNodeIndex = getAgregatedNodesFrom(hFig, nodeIndex);
                        Invalid = ismember(AgregatedNodeIndex, AgregatingNodes);
                        Invalid = Invalid | ismember(AgregatedNodeIndex, OrganiseNode);
                        if (size(AgregatedNodeIndex(~Invalid),1) == 1)
                            return;
                        end
                        % There's no exploration in 3D
                        bst_figures('SetFigureHandleField', hFig, 'OrganiseNode', nodeIndex);
                        UpdateFigurePlot(hFig);
                    end
                end
            end
        else
            if (ClickCount == 2)
                % double click resets display
                DefaultCamera(hFig);
            end
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


%% ===== POPUP MENU =====
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
%     jMenuSave = gui_component('Menu', jPopup, [], 'Snapshots', IconLoader.ICON_SNAPSHOT);
%         % === SAVE AS IMAGE ===
%         jItem = gui_component('MenuItem', jMenuSave, [], 'Save as image', IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@out_figure_image, hFig));
%         jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_I, KeyEvent.CTRL_MASK));
%         % === OPEN AS IMAGE ===
%         jItem = gui_component('MenuItem', jMenuSave, [], 'Open as image', IconLoader.ICON_IMAGE, [], @(h,ev)bst_call(@out_figure_image, hFig, 'Viewer'));
%         jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_J, KeyEvent.CTRL_MASK));       
%     jPopup.add(jMenuSave);
    
    % ==== MENU: 2D LAYOUT ====
    jGraphMenu = gui_component('Menu', jPopup, [], 'Display options', IconLoader.ICON_CONNECTN);
        % Check Matlab version: Works only for R2007b and newer
        if (bst_get('MatlabVersion') >= 705)
            
            % == MODIFY LINK TRANSPARENCY ==
            jPanelModifiers = gui_river([0 0], [3, 18, 3, 2]);
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
            % java_setcb(jSliderContrast, 'MouseReleasedCallback', @(h,ev)SliderModifiersValidate_Callback(h, ev, ColormapType, 'Contrast', jLabelContrast));
            java_setcb(jSliderContrast.getModel(), 'StateChangedCallback', @(h,ev)TransparencySliderModifiersModifying_Callback(hFig, ev, jLabelContrast));
            jGraphMenu.add(jPanelModifiers);

            % == MODIFY LINK SIZE ==
            jPanelModifiers = gui_river([0 0], [3, 18, 3, 2]);
            LinkSize = GetLinkSize(hFig);
            % Label
            gui_component('label', jPanelModifiers, '', 'Link size');
            % Slider
            jSliderContrast = JSlider(0,5,5);
            jSliderContrast.setValue(LinkSize);
            jSliderContrast.setPreferredSize(java_scaled('dimension',100,23));
            %jSliderContrast.setToolTipText(tooltipSliders);
            jSliderContrast.setFocusable(0);
            jSliderContrast.setOpaque(0);
            jPanelModifiers.add('tab hfill', jSliderContrast);
            % Value (text)
            jLabelContrast = gui_component('label', jPanelModifiers, '', sprintf('%.0f', round(LinkSize)));
            jLabelContrast.setPreferredSize(java_scaled('dimension',50,23));
            jLabelContrast.setHorizontalAlignment(JLabel.LEFT);
            jPanelModifiers.add(jLabelContrast);
            % Slider callbacks
            % java_setcb(jSliderContrast, 'MouseReleasedCallback', @(h,ev)SliderModifiersValidate_Callback(h, ev, ColormapType, 'Contrast', jLabelContrast));
            java_setcb(jSliderContrast.getModel(), 'StateChangedCallback', @(h,ev)SizeSliderModifiersModifying_Callback(hFig, ev, jLabelContrast));
            jGraphMenu.add(jPanelModifiers);
        end
        
        % === TOGGLE BACKGROUND WHITE/BLACK ===
        % @NOTE: done
        jGraphMenu.addSeparator();
        BackgroundColor = getappdata(hFig, 'BgColor');
        isWhite = all(BackgroundColor == [1 1 1]);
        jItem = gui_component('CheckBoxMenuItem', jGraphMenu, [], 'White background', [], [], @(h, ev)ToggleBackground(hFig));
        jItem.setSelected(isWhite);
        
        % === TOGGLE BLENDING OPTIONS ===
        BlendingEnabled = getappdata(hFig, 'BlendingEnabled');
        jItem = gui_component('CheckBoxMenuItem', jGraphMenu, [], 'Color blending', [], [], @(h, ev)ToggleBlendingMode(hFig));
        jItem.setSelected(BlendingEnabled);
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_B, 0));
        jGraphMenu.addSeparator();
        
        % === TOGGLE BLENDING OPTIONS ===
        TextDisplayMode = getappdata(hFig, 'TextDisplayMode');
        jLabelMenu = gui_component('Menu', jGraphMenu, [], 'Labels Display');
            jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Measure Nodes', [], [], @(h, ev)SetTextDisplayMode(hFig, 1));
            jItem.setSelected(ismember(1,TextDisplayMode));
            if (DisplayInRegion)
                jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Region Nodes', [], [], @(h, ev)SetTextDisplayMode(hFig, 2));
                jItem.setSelected(ismember(2,TextDisplayMode));
            end
            jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Selection only', [], [], @(h, ev)SetTextDisplayMode(hFig, 3));
            jItem.setSelected(ismember(3,TextDisplayMode));

        % === TOGGLE HIERARCHY NODE VISIBILITY ===
        if (DisplayInRegion)
            HierarchyNodeIsVisible = getappdata(hFig, 'HierarchyNodeIsVisible');
            jItem = gui_component('CheckBoxMenuItem', jGraphMenu, [], 'Hide region nodes', [], [], @(h, ev)SetHierarchyNodeIsVisible(hFig, 1 - HierarchyNodeIsVisible));
            jItem.setSelected(~HierarchyNodeIsVisible);
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_H, 0));
        end
        
        % === TOGGLE BINARY LINK STATUS ===
        Method = getappdata(hFig, 'Method');
        if ismember(Method, {'granger'}) || ismember(Method, {'spgranger'})
            IsBinaryData = getappdata(hFig, 'IsBinaryData');
            jItem = gui_component('CheckBoxMenuItem', jGraphMenu, [], 'Binary Link Display', IconLoader.ICON_CHANNEL_LABEL, [], @(h, ev)SetIsBinaryData(hFig, 1 - IsBinaryData));
            jItem.setSelected(IsBinaryData);
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_M, 0));
        end

    % ==== MENU: GRAPH DISPLAY ====
    jGraphMenu = gui_component('Menu', jPopup, [], 'Graph options', IconLoader.ICON_CONNECTN);
        % === SELECT ALL THE NODES ===
        jItem = gui_component('MenuItem', jGraphMenu, [], 'Select all the nodes', [], [], @(h, n, s, r)SetSelectedNodes(hFig, [], 1, 1));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_A, 0));
        % === SELECT NEXT REGION ===
        jItem = gui_component('MenuItem', jGraphMenu, [], 'Select next region', [], [], @(h, ev)ToggleRegionSelection(hFig, 1));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_RIGHT, 0));
        % === SELECT PREVIOUS REGION===
        jItem = gui_component('MenuItem', jGraphMenu, [], 'Select previous region', [], [], @(h, ev)ToggleRegionSelection(hFig, -1));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_LEFT, 0));
        jGraphMenu.addSeparator();

        if (DisplayInRegion)
%             % === UP ONE LEVEL IN HIERARCHY ===
%             jItem = gui_component('MenuItem', jGraphMenu, [], 'One Level Up', [], [], @(h, ev)SetExplorationLevelTo(hFig, 1), []);
%             jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_ESCAPE, 0));
%             jGraphMenu.addSeparator();
%             
            % === TOGGLE DISPLAY REGION MEAN ===
            RegionLinksIsVisible = getappdata(hFig, 'RegionLinksIsVisible');
            RegionFunction = getappdata(hFig, 'RegionFunction');
            jItem = gui_component('CheckBoxMenuItem', jGraphMenu, [], ['Display region ' RegionFunction], [], [], @(h, ev)ToggleMeasureToRegionDisplay(hFig));
            jItem.setSelected(RegionLinksIsVisible);
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_M, 0));
            
            % === TOGGLE REGION FUNCTIONS===
            IsMean = strcmp(RegionFunction, 'mean');
            jLabelMenu = gui_component('Menu', jGraphMenu, [], 'Region function');
                jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Mean', [], [], @(h, ev)SetRegionFunction(hFig, 'mean'));
                jItem.setSelected(IsMean);
                jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Max', [], [], @(h, ev)SetRegionFunction(hFig, 'max'));
                jItem.setSelected(~IsMean);
        end
    
    % Display Popup menu
    gui_popup(jPopup, hFig);
end

% Cortex transparency slider
function CortexTransparencySliderModifying_Callback(hFig, ev, jLabel)
    % Update Modifier value
    newValue = double(ev.getSource().getValue()) / 1000;
    % Setting newValue to 0 will automatically disable Blending
    if (newValue < eps)
        newValue = eps;
    end
    % Update text value
    jLabel.setText(sprintf('%0.2f', newValue));
    %
    SetCortexTransparency(hFig, newValue);
end

% Link transparency slider
function TransparencySliderModifiersModifying_Callback(hFig, ev, jLabel)
    % Update Modifier value
    newValue = double(ev.getSource().getValue()) / 100;
    % Update text value
    jLabel.setText(sprintf('%.0f %%', newValue * 100));
    %
    SetLinkTransparency(hFig, newValue);
end

% Link size slider
function SizeSliderModifiersModifying_Callback(hFig, ev, jLabel)
    % Update Modifier value
    newValue = ev.getSource().getValue();
    % Update text value
    jLabel.setText(sprintf('%.0f', round(newValue)));
    %
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
function LoadFigurePlot(hFig) %#ok<DEFNU>

% Currently using a "test" plot with defined threshold
% for testing purposes only
    testPlot(hFig)
    
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
                    if ~isempty(groupRows)
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
    
    % Add nodes
    %   This also defines some data-based display parameters
    ClearAndAddNodes(hFig, Vertices, Names);
    
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
    
    % Build path based on region %todo:remove
    MeasureLinks = BuildRegionPath(hFig, Paths, DataPair);
    
    % Compute spline based on MeasureLinks @todo:remove
    aSplines = ComputeSpline(hFig, MeasureLinks, Vertices);
    if ~isempty(aSplines)
        %OGL.addPrecomputedMeasureLinks(aSplines);
        % Get link size (type double)
        LinkSize = getappdata(hFig, 'LinkSize');
        % Set link width
        SetLinkSize(hFig, LinkSize);
        % Set link transparency (if 3DDisplay, set to 0.75)
        SetLinkTransparency(hFig, 0.00);
    end
    
    %NEW Nov 10: create links from computed DataPair
    BuildLinks(hFig, DataPair);
        
    %% ===== Init Filters =====
    % 
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
    % Select all
    SetSelectedNodes(hFig, [], 1);
    % Blending
    SetBlendingMode(hFig, 0);
    
    % OpenGL Constant
    % GL_LIGHTING = 2896
    % GL_COLOR_MATERIAL 2903
    % GL_DEPTH_TEST = 2929
    
    % These options are necessary for proper display
   % OGL.OpenGLDisable(2896);
  %  OGL.OpenGLDisable(2903);
    SetHierarchyNodeIsVisible(hFig, 1);
    RenderInQuad = 1;
    
    % 
   % OGL.renderInQuad(RenderInQuad);
    setappdata(hFig, 'RenderInQuad', RenderInQuad);
    
    % Update colormap
    UpdateColormap(hFig);
    % 
    RefreshTextDisplay(hFig);
    % Last minute hiding
    HideLonelyRegionNode(hFig);
    % Position camera
    DefaultCamera(hFig);
    % display final figure on top
    shg
    
    
    
end

% calls circularGraph in MATLAB
function testPlot(hFig)
    test_thresh = 0.75; % temporary value used for now
    
    [Time, Freqs, TfInfo, M, RowNames, DataType, Method, FullTimeVector] = GetFigureData(hFig);
    M(M<test_thresh) = 0;
    circularGraph(M, 'Label', RowNames);
    
    
    %hide test nodes
    delete(hFig.UserData.Nodes);
    
    %test display
   % shg %force show current figure
end

%% ======== Create all links as Matlab Lines =====
    %@todo: color for strength (current TEMP color is using the
     %node's scout color)
    % TODO: directional arcs
function BuildLinks(hFig, DataPair)
    testNodes = hFig.UserData.testNodes;
    
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
    for i = 1:length(DataPair) %for each link
        
        % node positions (rescaled to *unit* circle)
        node1 = DataPair(i,1);
        node2 = DataPair(i,2);
        u  = [testNodes(node1).Position(1);testNodes(node1).Position(2)]/0.6/4;
        v  = [testNodes(node2).Position(1);testNodes(node2).Position(2)]/0.6/4;

        % poincare hyperbolic disc
        x0 = -(u(2)-v(2))/(u(1)*v(2)-u(2)*v(1));
        y0 =  (u(1)-v(1))/(u(1)*v(2)-u(2)*v(1));
        r  = sqrt(x0^2 + y0^2 - 1);
        thetaLim(1) = atan2(u(2)-y0,u(1)-x0);
        thetaLim(2) = atan2(v(2)-y0,v(1)-x0);

        if (u(1) >= 0 && v(1) >= 0)
            % ensure the arc is within the unit disk
            theta = [linspace(max(thetaLim),pi,50),...
                linspace(-pi,min(thetaLim),50)].';
        else
            theta = linspace(thetaLim(1),thetaLim(2)).';
        end
                
        % rescale onto our graph circle
        x = 4*0.6*r*cos(theta)+4*0.6*x0;
        y = 4*0.6*r*sin(theta)+4*0.6*y0;
        
        % add as link to node1
        
        % use thresh as ABS value
        l = line(...
            x,...
            y,...
            'LineWidth', 2,...
            'Color', testNodes(node1).Color,...
            'PickableParts','none',...
            'Visible','off'); %not visible as default;
        testNodes(node1).Links(end+1) = l;
        if(i==1)
            hFig.UserData.AllLinks = l;
        else
            hFig.UserData.AllLinks(end+1) = l;
        end
        
    end
end
%test callback function
function test(hFig)
   testNodes = hFig.UserData.testNodes;
   
   DataPair = bst_figures('GetFigureHandleField', hFig, 'DataPair');
%            
%         
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
    % Progress bar
    bst_progress('start', 'Functional Connectivity Display', 'Updating figures...');
    % Get selected rows
    selNodes = bst_figures('GetFigureHandleField', hFig, 'SelectedNodes');
    % Get OpenGL handle
    OGL = getappdata(hFig, 'OpenGLDisplay');
    % Clear links
    OGL.clearLinks();

    % Get Rowlocs
    RowLocs = bst_figures('GetFigureHandleField', hFig, 'RowLocs');

    OrganiseNode = bst_figures('GetFigureHandleField', hFig, 'OrganiseNode');
    if ~isempty(OrganiseNode)
        % Reset display
        OGL.resetDisplay();
        % Back to Default camera
        DefaultCamera(hFig);
        % Which hierarchy level are we ?
        NodeLevel = 1;
        Levels = bst_figures('GetFigureHandleField', hFig, 'Levels');
        for i=1:size(Levels,1)
            if ismember(OrganiseNode,Levels{i})
                NodeLevel = i;
            end
        end
        % 
        Groups = bst_figures('GetFigureHandleField', hFig, 'Groups');
        RowNames = bst_figures('GetFigureHandleField', hFig, 'RowNames');
        nAgregatingNodes = size(bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes'),2);
        % 
        Nodes = getAgregatedNodesFrom(hFig, OrganiseNode);
        % 
        Channels = ismember(RowNames, [Groups.RowNames]);
        Index = find(Channels) + nAgregatingNodes;
        InGroups = Index(ismember(Index,Nodes)) - nAgregatingNodes;
        NamesOfNodes = RowNames(InGroups);
        
        GroupsIWant = [];
        for i=1:size(Groups,2)
            if (sum(ismember(Groups(i).RowNames, NamesOfNodes)) > 0)
                GroupsIWant = [GroupsIWant i];
            end
        end
        
        if (OrganiseNode == 1)
            % Return to first display
            DisplayInCircle = getappdata(hFig, 'DisplayInCircle');
            if (~isempty(DisplayInCircle) && DisplayInCircle == 1)
                Vertices = OrganiseNodeInCircle(hFig, RowNames, Groups);
            else
                Vertices = OrganiseNodesWithConstantLobe(hFig, RowNames, Groups, RowLocs, 1);
            end
        else
            % 
            Vertices = ReorganiseNodeAroundInCircle(hFig, Groups(GroupsIWant), RowNames, NodeLevel);
        end
        % 
        bst_figures('SetFigureHandleField', hFig, 'Vertices', Vertices);
        % 
        nVertices = size(Vertices,1);
        Visible = sum(Vertices(:,1:3) ~= repmat([0 0 -5], nVertices,1),2) >= 1;
        % 
        DisplayNode = zeros(nVertices,1);
        DisplayNode(OrganiseNode) = 1;
        DisplayNode(Visible) = 1;
        % 
        bst_figures('SetFigureHandleField', hFig, 'DisplayNode', DisplayNode);
        bst_figures('SetFigureHandleField', hFig, 'ValidNode', DisplayNode);
        % Add the nodes
        ClearAndAddNodes(hFig, Vertices, bst_figures('GetFigureHandleField', hFig, 'Names'));
    else
        % We assume that if 3D display, we did not unload the polygons
        % so we simply need to load new data
    end
    
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
        OGL.addPrecomputedMeasureLinks(aSplines);
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
    
    RenderInQuad = getappdata(hFig, 'RenderInQuad');
    OGL.renderInQuad(RenderInQuad);
    
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

%TODO: update OGL
function SetDisplayNodeFilter(hFig, NodeIndex, IsVisible)
    % Get OpenGL handle
%	OGL = getappdata(hFig, 'OpenGLDisplay');
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
    % Redraw
    %OGL.repaint();
end

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
    Regions = Levels{2};
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
    Regions = Levels{2};
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
%TODO: update ogl
function UpdateColormap(hFig)
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
            CLim = ThresholdMinMax;
            if sColormap.isAbsoluteValues
                CLim = abs(CLim);            
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
    OGL = getappdata(hFig, 'OpenGLDisplay');
    
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
       
        %TODO: update colour of link
        % Update color
%         OGL.setMeasureLinkColorGradient( ...
%             find(DataMask) - 1, ...
%             StartColor(:,1), StartColor(:,2), StartColor(:,3), ...
%             EndColor(:,1), EndColor(:,2), EndColor(:,3));

        % TODO: Offset is always in absolute
        % OGL.setMeasureLinkOffset(find(DataMask) - 1, Offset(:).^2 * 2);
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
        
        % TODO: Update display
%         OGL.setRegionLinkColorGradient( ...
%             find(RegionDataMask) - 1, ...
%             StartColor(:,1), StartColor(:,2), StartColor(:,3), ...
%             EndColor(:,1), EndColor(:,2), EndColor(:,3));
       
        % TODO: Offset is always in absolute
%       OGL.setRegionLinkOffset(find(RegionDataMask) - 1, Offset(:).^2 * 2);

    end
    
%     OGL.repaint();
end


function [StartColor EndColor] = InterpolateColorMap(hFig, DataPair, ColorMap, Limit)
    IsBinaryData = getappdata(hFig, 'IsBinaryData');
    if (~isempty(IsBinaryData) && IsBinaryData == 1)
        % Retrieve ColorMap extremeties
        nDataPair = size(DataPair,1);
        % 
        StartColor(:,:) = repmat(ColorMap(1,:), nDataPair, 1);
        EndColor(:,:) = repmat(ColorMap(end,:), nDataPair, 1);
        % Bidirectional data ?
        DisplayBidirectionalMeasure = getappdata(hFig, 'DisplayBidirectionalMeasure');
        if (DisplayBidirectionalMeasure)
            % Get Bidirectional data
            OutIndex = ismember(DataPair(:,1:2),DataPair(:,2:-1:1),'rows');
            InIndex = ismember(DataPair(:,1:2),DataPair(:,2:-1:1),'rows');
            % Bidirectional links in total Green
            StartColor(OutIndex | InIndex,1) = 0;
            StartColor(OutIndex | InIndex,2) = 0.7;
            StartColor(OutIndex | InIndex,3) = 0;
            EndColor(OutIndex | InIndex,:) = StartColor(OutIndex | InIndex,:);
        end
    else
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
  %   RotateCameraAlongAxis(hFig, 0, 0);
    hFig.CurrentAxes.CameraViewAngle = 7;
    hFig.CurrentAxes.CameraPosition = [0 0 36];
    hFig.CurrentAxes.CameraTarget = [0 0 -0.5];
   
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
    % NOTE: Oct 20, 2020. Needs accuracy improvement.
    % Move camera horizontally/vertically (from SHIFT+MOUSEMOVE) 
    % by applying X and Y translation to the CameraPosition and CameraTarget
    % ref: https://www.mathworks.com/help/matlab/ref/matlab.graphics.axis.axes-properties.html#budumk7-CameraTarget
function MoveCamera(hFig, Translation)
    disp('MoveCamera reached') %TODO: remove test
  %  CameraPosition = getappdata(hFig, 'CameraPosition') + Translation;
   % CameraTarget = getappdata(hFig, 'CameraTarget') + Translation;
  %  setappdata(hFig, 'CameraPosition', CameraPosition);
  %  setappdata(hFig, 'CameraTarget', CameraTarget);
  %  UpdateCamera(hFig);
    
    %new 
    position = hFig.CurrentAxes.CameraPosition + Translation; %[0.01 0.01 0]; 
    target = hFig.CurrentAxes.CameraTarget + Translation; %[0.01 0.01 0];
    hFig.CurrentAxes.CameraPosition = position;
    hFig.CurrentAxes.CameraTarget = target;
end

%% ===== UPDATE CAMERA =====
% TODO: REMOVE
function UpdateCamera(hFig)
   % disp('UpdateCamera reached') %TODO: remove test
   % Pos = getappdata(hFig, 'CameraPosition');
   % CameraTarget = getappdata(hFig, 'CameraTarget');
  %  Zoom = getappdata(hFig, 'CameraZoom');
   % OGL = getappdata(hFig, 'OpenGLDisplay');
   % OGL.zoom(Zoom);
   % OGL.lookAt(Pos(1), Pos(2), Pos(3), CameraTarget(1), CameraTarget(2), CameraTarget(3), 0, 1, 0);
  %  OGL.repaint();
end

%% ===== ROTATE CAMERA =====
% TODO: REMOVE
function RotateCameraAlongAxis(hFig, theta, phi)
%     disp('RotateCamera reached') %TODO: remove test
% 	Pos = getappdata(hFig, 'CameraPosition');
%     Target = getappdata(hFig, 'CameraTarget');
%     Zoom = getappdata(hFig, 'CameraZoom');
%     Pitch = getappdata(hFig, 'CamPitch');
%     Yaw = getappdata(hFig, 'CamYaw');
%     
%     Pitch = Pitch + theta;
%     Yaw = Yaw + phi;
%     if (Pitch > (0.5 * 3.1415))
%         Pitch = (0.5 * 3.1415);
%     elseif (Pitch < -(0.5 * 3.1415))
%         Pitch = -(0.5 * 3.1415);
%     end
%     
%     % Projection 
%     Pos(1) = cos(Yaw) * cos(Pitch);
% 	Pos(2) = sin(Yaw) * cos(Pitch);
%     Pos(3) = sin(Pitch);
%     Pos = Target + Zoom * Pos;
%     
%     setappdata(hFig, 'CamPitch', Pitch);
%     setappdata(hFig, 'CamYaw', Yaw);
%     setappdata(hFig, 'CameraPosition', Pos);
% 
% 	UpdateCamera(hFig);
end



%% ===========================================================================
%  ===== NODE DISPLAY AND SELECTION ==========================================
%  ===========================================================================

%% ===== SET SELECTED NODES =====
% USAGE:  SetSelectedNodes(hFig, iNodes=[], isSelected=1, isRedraw=1) : Add or remove nodes from the current selection
%         If node selection is empty: select/unselect all the nodes
function SetSelectedNodes(hFig, iNodes, isSelected, isRedraw)
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
       % SelectedNodeColor = [0.95, 0.0, 0.0]; %selection is indicated by
       % marker type now (x or O)
        selNodes = union(selNodes, iNodes);
    else
        %SelectedNodeColor = getappdata(hFig, 'BgColor');
        selNodes = setdiff(selNodes, iNodes);
    end
    % Update list of selected channels
    bst_figures('SetFigureHandleField', hFig, 'SelectedNodes', selNodes);
    
    %get nodes from figure
    testNodes = hFig.UserData.testNodes;
    
    % Agregating nodes are not visually selected
    AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
    NoColorNodes = ismember(iNodes,AgregatingNodes);
    
    for i = 1:length(iNodes)
        if isSelected
            testNodes(iNodes(i)).Visible = true;
        else
            testNodes(iNodes(i)).Visible = false;
        end
    end
         
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
    RefreshTextDisplay(hFig, isRedraw);
    
    % Get data
    MeasureLinksIsVisible = getappdata(hFig, 'MeasureLinksIsVisible');
    if (MeasureLinksIsVisible)
        [DataToFilter, DataMask] = GetPairs(hFig);
    else
        [DataToFilter, DataMask] = GetRegionPairs(hFig);
    end
    
    % ===== Selection based data filtering =====
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
    
    % Links are from valid node only
    ValidNode = find(bst_figures('GetFigureHandleField', hFig, 'ValidNode') > 0);
    ValidDataForDisplay = sum(ismember(DataToFilter(:,1:2), ValidNode),2);
    DataMask = DataMask == 1 & ValidDataForDisplay == 2;

    iData = find(DataMask == 1); % - 1;

    if (~isempty(iData))
        % Update link visibility
        if (MeasureLinksIsVisible)
            if (isSelected)
                set(hFig.UserData.AllLinks(iData), 'Visible', 'on');
            else
                set(hFig.UserData.AllLinks(iData), 'Visible', 'off');
            end

         %   OGL.setMeasureLinkVisibility(iData, isSelected);
        else
          %  OGL.setRegionLinkVisibility(iData, isSelected);
        end
    end
    
    % These functions sets global Boolean value in Java that allows
    % or disallows the drawing of these measures, which makes it
    % really fast to switch between the two mode
  %  OGL.setMeasureIsVisible(MeasureLinksIsVisible);
 %   OGL.setRegionIsVisible(~MeasureLinksIsVisible);
    
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


%%
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


%% 
%TODO: update no ogl
function RegionDataPair = SetRegionFunction(hFig, RegionFunction)
    % Does data has regions to cluster ?
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
        %
       % OGL = getappdata(hFig, 'OpenGLDisplay');
        % Clear
       % OGL.clearRegionLinks();
        %
        Paths = bst_figures('GetFigureHandleField', hFig, 'NodePaths');
        Vertices = bst_figures('GetFigureHandleField', hFig, 'Vertices');
        % Build path for new datapair
        MeasureLinks = BuildRegionPath(hFig, Paths, RegionDataPair);
        % Compute spline
        aSplines = ComputeSpline(hFig, MeasureLinks, Vertices);
        if (~isempty(aSplines))
            % Add on Java side
           % OGL.addPrecomputedHierarchyLink(aSplines); 
            % Get link size
            LinkSize = 6;
            % Width
           % OGL.setRegionLinkWidth(0:(size(RegionDataPair,1) - 1), LinkSize);
        end
        % Update figure value
        bst_figures('SetFigureHandleField', hFig, 'RegionDataPair', RegionDataPair);
        setappdata(hFig, 'RegionFunction', RegionFunction);
        % Update color map
        UpdateColormap(hFig);
    end
end


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
function ToggleTextDisplayMode(hFig)
    % Get display mode
    TextDisplayMode = getappdata(hFig, 'TextDisplayMode');
    if (TextDisplayMode == 1)
        TextDisplayMode = [TextDisplayMode 2];
    else
        TextDisplayMode = 1;
    end
    % Add display mode
    setappdata(hFig, 'TextDisplayMode', TextDisplayMode);
    % Refresh
    RefreshTextDisplay(hFig);
end

%% ===== BLENDING =====
% Blending functions has defined by OpenGL
% GL_SRC_COLOR = 768;
% GL_ONE_MINUS_SRC_COLOR = 769;
% GL_SRC_ALPHA = 770;
% GL_ONE_MINUS_SRC_ALPHA = 771;
% GL_ONE_MINUS_DST_COLOR = 775;
% GL_ONE = 1;
% GL_ZERO = 0;

%TODO: update ogl
function SetBlendingMode(hFig, BlendingEnabled)
    % Update figure variable
    setappdata(hFig, 'BlendingEnabled', BlendingEnabled);
    % Update display
    %OGL = getappdata(hFig,'OpenGLDisplay');
    % 
    if BlendingEnabled
        % Good looking additive blending
        %OGL.setMeasureLinkBlendingFunction(770,1);
        % Blending only works nicely on black background
        SetBackgroundColor(hFig, [0 0 0], [1 1 1]);
        % AND with a minimum amount of transparency
        LinkTransparency = getappdata(hFig, 'LinkTransparency');
        if (LinkTransparency == 0)
            SetLinkTransparency(hFig, 0.02);
        end
    else
        % Translucent blending only
      %  OGL.setMeasureLinkBlendingFunction(770,771);
    end
    % Request redraw
   % OGL.repaint();
end

function ToggleBlendingMode(hFig)
    BlendingEnabled = getappdata(hFig, 'BlendingEnabled');
    if isempty(BlendingEnabled)
        BlendingEnabled = 0;
    end
    SetBlendingMode(hFig, 1 - BlendingEnabled);
end

%% ===== LINK SIZE =====
function LinkSize = GetLinkSize(hFig)
    LinkSize = getappdata(hFig, 'LinkSize');
    if isempty(LinkSize)
        LinkSize = 1;
    end
end

% TODO: set link size (line size)
function SetLinkSize(hFig, LinkSize)
    % Get display
   % OGL = getappdata(hFig,'OpenGLDisplay');
    % Get # of data to update (test # 4513 links)
    nLinks = size(bst_figures('GetFigureHandleField', hFig, 'DataPair'), 1);
    % Update size
  %  OGL.setMeasureLinkWidth(0:(nLinks - 1), LinkSize);
  %  OGL.repaint();
    % 
    setappdata(hFig, 'LinkSize', LinkSize);
end

%% ===== LINK TRANSPARENCY =====
% TODO: set link / line transparency
function SetLinkTransparency(hFig, LinkTransparency)
    % Get display
   % OGL = getappdata(hFig,'OpenGLDisplay');
    % 
    nLinks = size(bst_figures('GetFigureHandleField', hFig, 'DataPair'),1);
    % 
    %OGL.setMeasureLinkTransparency(0:(nLinks - 1), LinkTransparency);
    %OGL.repaint();
    % 
    setappdata(hFig, 'LinkTransparency', LinkTransparency);
end

%% ===== CORTEX TRANSPARENCY =====
% TODO: was this only for 3d link?
function CortexTransparency = GetCortexTransparency(hFig)
    CortexTransparency = getappdata(hFig, 'CortexTransparency');
    if isempty(CortexTransparency)
        CortexTransparency = 0.025;
    end
end

function SetCortexTransparency(hFig, CortexTransparency)
    %only for 3d display
    setappdata(hFig, 'CortexTransparency', CortexTransparency);
end

%% ===== BACKGROUND COLOR =====
% @TODO: BLENDING
% @TODO: Agregating node text (region node - lobe label)
function SetBackgroundColor(hFig, BackgroundColor, TextColor)
    % Negate text color if necessary
    if nargin < 3
        TextColor = ~BackgroundColor;
    end

    % Update Matlab background color
    set(hFig, 'Color', BackgroundColor)
    
    % === @TODO: BLENDING ===
    % Ensures that if background is white no blending is on.
    % Blending is additive and therefore won't be visible.
    if all(BackgroundColor == [1 1 1])
        SetBlendingMode(hFig, 0);
    end
    
    % === UPDATE TEXT COLOR ===
    FigureHasText = getappdata(hFig, 'FigureHasText');
    if FigureHasText
        % TODO: Agregating node text (region node - lobe label)
        AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
        if ~isempty(AgregatingNodes)
           % OGL.setTextColor(AgregatingNodes - 1, TextColor(1), TextColor(2), TextColor(3));
        end
        
        % Measure node text @NOTE: done
        MeasureNodes = bst_figures('GetFigureHandleField', hFig, 'MeasureNodes');
        if ~isempty(MeasureNodes)
            nodes = hFig.UserData.Nodes;
            if isvalid(nodes) %check in case no nodes (deleted handle)
                for i = 1:length(nodes)
                    nodes(i).LabelColor = TextColor;
                end
            end
            
            %@TODO: remove testing nodes
            testNodes = hFig.UserData.testNodes;
            if isvalid(testNodes)
                for i = 1:length(testNodes)
                    testNodes(i).LabelColor = TextColor;
                end
            end
        end
    end
    
    setappdata(hFig, 'BgColor', BackgroundColor); %set app data for toggle
    UpdateContainer(hFig, []);
end

% @NOTE: DONE
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

%%
function SetIsBinaryData(hFig, IsBinaryData)
    % Update variable
    setappdata(hFig, 'IsBinaryData', IsBinaryData);
    setappdata(hFig, 'UserSpecifiedBinaryData', 1);
    % Update colormap
    UpdateColormap(hFig);
end

function ToggleDisplayMode(hFig)
    % Get display mode
    DisplayOutwardMeasure = getappdata(hFig, 'DisplayOutwardMeasure');
    DisplayInwardMeasure = getappdata(hFig, 'DisplayInwardMeasure');
    % Toggle value
    if (DisplayInwardMeasure == 0 && DisplayOutwardMeasure == 0)
        DisplayOutwardMeasure = 1;
        DisplayInwardMeasure = 1;
        DisplayBidirectionalMeasure = 0;
    elseif (DisplayInwardMeasure == 0 && DisplayOutwardMeasure == 1)
        DisplayOutwardMeasure = 0;
        DisplayInwardMeasure = 1;
        DisplayBidirectionalMeasure = 0;
    elseif (DisplayInwardMeasure == 1 && DisplayOutwardMeasure == 0)
        DisplayOutwardMeasure = 1;
        DisplayInwardMeasure = 1;
        DisplayBidirectionalMeasure = 1;
    else
        DisplayOutwardMeasure = 0;
        DisplayInwardMeasure = 0;
        DisplayBidirectionalMeasure = 1;
    end
    % Update display
    setDisplayMeasureMode(DisplayOutwardMeasure, DisplayInwardMeasure, DisplayBidirectionalMeasure);
    % UI refresh candy
    RefreshBinaryStatus(hFig);
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

% ===== REFRESH TEXT VISIBILITY =====
%TODO: Check text display modes 1,2,3
function RefreshTextDisplay(hFig, isRedraw)
    % 
    FigureHasText = getappdata(hFig, 'FigureHasText');
    if FigureHasText
        % 
        if nargin < 2
            isRedraw = 1;
        end
        % 
        AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
        MeasureNodes = bst_figures('GetFigureHandleField', hFig, 'MeasureNodes');
        ValidNode = bst_figures('GetFigureHandleField', hFig, 'ValidNode');
        %
        nVertices = size(AgregatingNodes,2) + size(MeasureNodes,2);
        VisibleText = zeros(nVertices,1);
        %
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
        % OpenGL Handle
       % OGL = getappdata(hFig, 'OpenGLDisplay');
       
        % Update text visibility
        testNodes = hFig.UserData.testNodes;
        for i=1:length(VisibleText)
            if (VisibleText(i) == 1)
                testNodes(i).LabelVisible = true;
            else
                testNodes(i).LabelVisible = false;
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

function [B,x] = bspline_basismatrix(n,t,x)
    if nargin > 2
        B = zeros(numel(x),numel(t)-n);
        for j = 0 : numel(t)-n-1
            B(:,j+1) = bspline_basis(j,n,t,x);
        end
    else
        [b,x] = bspline_basis(0,n,t);
        B = zeros(numel(x),numel(t)-n);
        B(:,1) = b;
        for j = 1 : numel(t)-n-1
            B(:,j+1) = bspline_basis(j,n,t,x);
        end
    end
end


%% ===== ADD NODES TO DISPLAY =====
%@Note: new display prototype (working)
%@TODO: default link and node size (user adjustable)
%@TODO: figurehastext default on/off
function ClearAndAddNodes(hFig, V, Names)
    
    % get calculated nodes
    MeasureNodes = bst_figures('GetFigureHandleField', hFig, 'MeasureNodes');
    AgregatingNodes = bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes');
    DisplayedNodes = find(bst_figures('GetFigureHandleField', hFig, 'ValidNode'));
    DisplayedMeasureNodes = MeasureNodes(ismember(MeasureNodes,DisplayedNodes));
    
    NumberOfMeasureNode = length(DisplayedMeasureNodes);
    nAgregatingNodes = length(AgregatingNodes);
    nVertices = size(V,1);
    
    % --- CREATE AND ADD NODES TO DISPLAY ---- %
    UserData = hFig.UserData; 
    delete(UserData.testNodes);
    
    scaleFactor = 0.6; %new scale factor for x,y position of nodes
    for i = 1: nVertices
        UserData.testNodes(i) = node(scaleFactor*V(i,1),scaleFactor*V(i,2)); %create node
        if (i<=nAgregatingNodes)
            %this alters display/rotation of lobe node text
            UserData.testNodes(i).isAgregatingNode = true; 
        end
        
        % add label to node
        if (isempty(Names(i)) || isempty(Names{i}))
            Names{i} = ''; % Blank name if none is assigned
        end
        UserData.testNodes(i).Label = Names(i);
        
        % OGL.setNodeTransparency(i - 1, 0.01); %TODO: check needed
    end 
    
    % Measure Nodes are color coded to their Scout counterpart
    RowColors = bst_figures('GetFigureHandleField', hFig, 'RowColors');
    if ~isempty(RowColors)
        for i=1:length(RowColors)
            UserData.testNodes(nAgregatingNodes+i).Color = RowColors(i,:);
        end 
    end
    
    % refresh display extent
    axis image; %fit display to all objects in image
    ax = hFig.CurrentAxes; %z-axis on default
%     extent = 0;
%     for i = 1: nVertices
%         if (UserData.testNodes(i).Extent > extent)
%             extent = UserData.testNodes(i).Extent;
%         end
%     end
%     
%     ax.XLim = ax.XLim + extent*[-1 1];
%     displayFactor = 1.5;
%     ax.YLim = ax.YLim + displayFactor*extent*[-1 1];
    ax.Visible = 'off';
 %   ax.SortMethod = 'depth'; % this sorts (displays) the ax.Children  by their z-coordinate.
    
    
    % @TODO: default link and node size (user adjustable)
    %setappdata(hFig, 'NodeSize', NodeSize);
    %setappdata(hFig, 'LinkSize', LinkSize);
    
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

function Tag = HemisphereIndexToTag(Index)
    Tag = 'U';
    switch (Index)
        case 1
            Tag = 'L';
        case 2
            Tag = 'R';
        case 3
            Tag = 'C';
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
    RegionLevel = 3.5;
    LobeLevel = 2.5;
    HemisphereLevel = 1.0;
    setappdata(hFig, 'MeasureLevelDistance', MeasureLevel);

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


function Vertices = ReorganiseNodeAroundInCircle(hFig, sGroups, aNames, Level)

    Paths = bst_figures('GetFigureHandleField', hFig, 'NodePaths');
    nVertices = size(bst_figures('GetFigureHandleField', hFig, 'Vertices'), 1);
    Vertices = zeros(nVertices,3);
    Vertices(:,3) = -5;
    
    DisplayLevel = 4:-(4/(Level-1)):0;
    
    NumberOfMeasureNodes = length([sGroups.RowNames]);
    NumberOfGroups = length(sGroups);
    
    NumberOfAgregatingNodes = length(bst_figures('GetFigureHandleField', hFig, 'AgregatingNodes'));
    
    NumberOfNodesInGroup = zeros(NumberOfGroups,1);
    GroupsTheta = zeros(NumberOfGroups,1);
    GroupsTheta(1,1) = (pi * 0.5);
    for i=1:NumberOfGroups
        if (i ~= 1)
            GroupsTheta(i,1) = GroupsTheta(i-1,2);
        end
        NumberOfNodesInGroup(i) = 1;
        if (iscellstr(sGroups(i).RowNames))
            NumberOfNodesInGroup(i) = length(sGroups(i).RowNames);
        end
        Theta = (NumberOfNodesInGroup(i) / NumberOfMeasureNodes * (2 * pi));
        GroupsTheta(i,2) = GroupsTheta(i,1) + Theta;
    end
    
    for i=1:NumberOfGroups
        LocalTheta = linspace(GroupsTheta(i,1), GroupsTheta(i,2), NumberOfNodesInGroup(i) + 2);
        ChannelsOfThisGroup = ismember(aNames, sGroups(i).RowNames);
        Index = find(ChannelsOfThisGroup) + NumberOfAgregatingNodes;
        [posX,posY] = pol2cart(LocalTheta(2:end-1),1);
        Vertices(Index,1:2) = [posX' posY'] * DisplayLevel(1);
        Vertices(Index,3) = 0;
        
        for y=2:Level
            Path = Paths{Index(1)};
            RegionIndex = Path(y);
            if (NumberOfNodesInGroup(i) == 1)
                Mean = [posX posY];
            else
                Mean = mean([posX' posY']);
            end
            Mean = Mean / norm(Mean);
            Vertices(RegionIndex,1:2) = Mean * DisplayLevel(y);
            Vertices(RegionIndex,3) = 0;
        end
    end
end
