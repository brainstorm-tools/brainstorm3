function varargout = figure_pac( varargin )
% FIGURE_PAC: Creation and callbacks for phase-amplitude coupling results.
%
% USAGE:  hFig = figure_pac('CreateFigure', FigureId)

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
% Authors: Francois Tadel, 2013-2014

eval(macro_method);
end


%% ===== CREATE FIGURE =====
function hFig = CreateFigure(FigureId) %#ok<DEFNU>
    % Get renderer name
    if (bst_get('DisableOpenGL') ~= 1)
        rendererName = 'opengl';
    elseif (bst_get('MatlabVersion') <= 803)   % zbuffer was removed in Matlab 2014b
        rendererName = 'zbuffer';
    else
        rendererName = 'painters';
    end
    % Create new figure
    hFig = figure('Visible',       'off', ...
                  'NumberTitle',   'off', ...
                  'IntegerHandle', 'off', ...
                  'MenuBar',       'none', ...
                  'Toolbar',       'none', ...
                  'DockControls',  'on', ...
                  'Units',         'pixels', ...
                  'Interruptible', 'off', ...
                  'BusyAction',    'queue', ...
                  'Tag',           FigureId.Type, ...
                  'Renderer',      rendererName, ...
                  'Color',         [.8 .8 .8], ...
                  'Pointer',       'arrow', ...
                  'CloseRequestFcn',          @(h,ev)bst_figures('DeleteFigure',h,ev), ...
                  'KeyPressFcn',              @FigureKeyPressedCallback, ...
                  'WindowButtonDownFcn',      @FigureMouseDownCallback, ...
                  'WindowButtonUpFcn',        @FigureMouseUpCallback, ...
                  bst_get('ResizeFunction'),  @ResizeCallback);
    % Define Mouse wheel callback separately (not supported by old versions of Matlab)
    if isprop(hFig, 'WindowScrollWheelFcn')
        set(hFig, 'WindowScrollWheelFcn',  @FigureMouseWheelCallback);
    end
    % Create axes
    hAxes = axes('Units',         'normalized', ...
                 'Interruptible', 'off', ...
                 'BusyAction',    'queue', ...
                 'Parent',        hFig, ...
                 'Tag',           'AxesPac', ...
                 'Visible',       'off');
             
    % Prepare figure appdata
    setappdata(hFig, 'FigureId', FigureId);
    setappdata(hFig, 'hasMoved', 0);
    setappdata(hFig, 'isPlotEditToolbar', 0);
    setappdata(hFig, 'isStatic', 1);
    setappdata(hFig, 'isStaticFreq', 0);
    setappdata(hFig, 'Colormap', db_template('ColormapInfo'));
    % Time-freq specific appdata
    setappdata(hFig, 'Timefreq', db_template('TfInfo'));
end


%% ===========================================================================
%  ===== FIGURE CALLBACKS ====================================================
%  ===========================================================================
%% ===== COLORMAP CHANGED CALLBACK =====
function ColormapChangedCallback(hFig) %#ok<DEFNU>
    % Update colormap
    ColormapInfo = getappdata(hFig, 'Colormap');
    sColormap = bst_colormaps('GetColormap', ColormapInfo.Type);
    set(hFig, 'Colormap', sColormap.CMap);
    % Redraw figure
    UpdateFigurePlot(hFig);
end


%% ===== CURRENT TIME CHANGED =====
function CurrentTimeChangedCallback(hFig)   %#ok<DEFNU>
    % If no time in this figure
    if getappdata(hFig, 'isStatic')
        return;
    end
    % No time for now
end


%% ===== RESIZE CALLBACK =====
function ResizeCallback(hFig, ev)
    % Get colorbar and axes handles
    hColorbar = findobj(hFig, '-depth', 1, 'Tag', 'Colorbar');
    hAxes     = findobj(hFig, '-depth', 1, 'Tag', 'AxesPac');
    if isempty(hAxes)
        return
    end
    hAxes = hAxes(1);
    % Do not resize unless there is a display already
    if isempty(findobj(hAxes, '-depth', 1, 'tag', 'PacSurf'))
        return
    end
    % Get display description
    TfInfo = getappdata(hFig, 'Timefreq');
    if isempty(TfInfo)
        return
    end
    % Get figure position and size in pixels
    figPos = get(hFig, 'Position');
    % Define constants
    colorbarWidth = 15;
    marginTop     = 25;
    marginBottom  = 35;
    marginLeft    = 50;

    % If colorbar: Add a small label to hide the x10^exp on top of the colorbar
    hLabelHideExp = findobj(hFig, '-depth', 1, 'tag', 'labelMaskExp');
    % Reposition the colorbar
    if ~isempty(hColorbar)
        marginRight = 55;
        % Position colorbar
        colorbarPos = [figPos(3) - marginRight + 10, ...
                       marginBottom, ...
                       colorbarWidth, ...
                       figPos(4) - marginTop - marginBottom];
        set(hColorbar, 'Units', 'pixels', 'Position', colorbarPos);
        % Add mask for exponent
        maskPos = [colorbarPos(1), colorbarPos(2) + colorbarPos(4) + 5, ...
                   figPos(3)-colorbarPos(1), figPos(4)-colorbarPos(2)-colorbarPos(4)];
        if isempty(hLabelHideExp)
            uicontrol(hFig,'style','text','units','pixels', 'pos', maskPos, 'tag', 'labelMaskExp', ...
                      'BackgroundColor', get(hFig, 'Color'));
        else
            set(hLabelHideExp, 'pos', maskPos);
        end
    else
        delete(hLabelHideExp);
        marginRight = 30;
    end
    % Reposition the axes
    set(hAxes, 'Units',    'pixels', ...
               'Position', [marginLeft, ...
                            marginBottom, ...
                            figPos(3) - marginLeft - marginRight, ...
                            figPos(4) - marginTop - marginBottom]);
end


%% ===========================================================================
%  ===== KEYBOARD AND MOUSE CALLBACKS =============================================
%  ===========================================================================
%% ===== FIGURE MOUSE DOWN =====
function FigureMouseDownCallback(hFig, ev)
    % Get selected object in this figure
    hObj = get(hFig,'CurrentObject');
    if isempty(hObj)
        return;
    end
    objType = get(hObj, 'Type');
    % Get figure properties
    MouseStatus = get(hFig, 'SelectionType');
    % Get axes
    switch (objType)
        case 'figure'
            hAxes = get(hFig, 'CurrentAxes');
        case 'axes'
            hAxes = hObj;
        otherwise
            hAxes = ancestor(hObj, 'Axes');
    end
    % If axes are a colormap: ignore call
    if strcmpi(get(hAxes, 'Tag'), 'Colorbar')
        MouseStatus = 'colorbar';
    end
    
    % Start an action (Move time cursor, pan)
    switch(MouseStatus)
        % Left click
        case 'normal'
            clickAction = 'selection'; 
            % Get new time and frequency
            [X,Y,iX,iY] = GetMousePosition(hFig, hAxes);
            % Set selected point in the image
            if ~isempty(iX)
                SetSelectedPoint(hFig, iX, iY, 0);
            end
        % CTRL+Mouse, or Mouse right
        case 'alt'
            clickAction = 'pan';
        % SHIFT+Mouse
        case 'extend'
            clickAction = 'pan';
        % DOUBLE CLICK
        case 'open'
            ResetView(hFig);
            return;
        % COLORBAR
        case 'colorbar'
            clickAction = 'colorbar';
        % OTHER : nothing to do
        otherwise
            return
    end

    % Reset the motion flag
    setappdata(hFig, 'hasMoved', 0);
    % Record mouse location in the figure coordinates system
    setappdata(hFig, 'clickPositionFigure', get(hFig, 'CurrentPoint'));
    % Record action to perform when the mouse is moved
    setappdata(hFig, 'clickAction', clickAction);
    % Record axes ibject that was clicked (usefull when more than one axes object in figure)
    setappdata(hFig, 'clickSource', hAxes);
    % Register MouseMoved callbacks for current figure
    set(hFig, 'WindowButtonMotionFcn', @FigureMouseMoveCallback);
end


%% ===== FIGURE MOUSE MOVE =====
function FigureMouseMoveCallback(hFig, event)  
    % Get current mouse action
    clickAction = getappdata(hFig, 'clickAction');
    hAxes = getappdata(hFig, 'clickSource');
    if isempty(clickAction) || isempty(hAxes)
        return
    end
    % Set the motion flag
    setappdata(hFig, 'hasMoved', 1);
    % Get current mouse location
    curptFigure = get(hFig, 'CurrentPoint');
    motionFigure = (curptFigure - getappdata(hFig, 'clickPositionFigure')) / 100;
    % Update click point location
    setappdata(hFig, 'clickPositionFigure', curptFigure);

    % Switch between different actions (Pan, Rotate, Contrast)
    switch(clickAction)                          
        case 'pan'
            % Get initial XLim and YLim
            XLimInit = getappdata(hFig, 'XLimInit');
            YLimInit = getappdata(hFig, 'YLimInit');
            % Move view along X axis
            XLim = get(hAxes, 'XLim');
            XLim = XLim - (XLim(2) - XLim(1)) * motionFigure(1);
            XLim = bst_saturate(XLim, XLimInit, 1);
            set(hAxes, 'XLim', XLim);
            % Move view along Y axis
            YLim = get(hAxes, 'YLim');
            YLim = YLim - (YLim(2) - YLim(1)) * motionFigure(2);
            YLim = bst_saturate(YLim, YLimInit, 1);
            set(hAxes, 'YLim', YLim);
            
        case 'selection'
            % Get new time and frequency
            [X,Y,iX,iY] = GetMousePosition(hFig, hAxes);
            % Set selected point in the image
            SetSelectedPoint(hFig, iX, iY, 0);
            
        case 'colorbar'
            % Get colormap name
            ColormapInfo = getappdata(hFig, 'Colormap');
            % Changes contrast
            sColormap = bst_colormaps('ColormapChangeModifiers', ColormapInfo.Type, [motionFigure(1) / 5, motionFigure(2) ./ 2], 0);
            set(hFig, 'Colormap', sColormap.CMap);
    end
end
            

%% ===== FIGURE MOUSE UP =====        
function FigureMouseUpCallback(hFig, event)   
    % Get mouse state
    hasMoved    = getappdata(hFig, 'hasMoved');
    MouseStatus = get(hFig, 'SelectionType');
    % Get axes handles
    clickAction = getappdata(hFig, 'clickAction');
    hAxes = getappdata(hFig, 'clickSource');
    if isempty(clickAction) || isempty(hAxes)
        return
    end
    % Reset figure mouse fields
    setappdata(hFig, 'clickAction', '');
    setappdata(hFig, 'hasMoved', 0);

    % If mouse has not moved: popup or time change
    if ~hasMoved && ~isempty(MouseStatus)
        if strcmpi(MouseStatus, 'normal')
            % Already processed
        else 
            % Popup
            DisplayFigurePopup(hFig);
        end
    else
        % COLORMAP HAS CHANGED
        if strcmpi(clickAction, 'colorbar')
            % Apply new colormap to all figures
            ColormapInfo = getappdata(hFig, 'Colormap');
            bst_colormaps('FireColormapChanged', ColormapInfo.Type);
        end
    end
    
    % Reset MouseMove callbacks for current figure
    set(hFig, 'WindowButtonMotionFcn', []);
    % Remove mouse callbacks appdata
    setappdata(hFig, 'clickSource', []);
    setappdata(hFig, 'clickAction', []);
    % Update figure selection
    bst_figures('SetCurrentFigure', hFig, 'TF');
end


%% ===== GET MOUSE POSITION =====
function [X,Y,iX,iY] = GetMousePosition(hFig, hAxes)
    % Get current point in axes
    CurPoint = get(hAxes, 'CurrentPoint');
    X = CurPoint(1,1);
    Y = CurPoint(1,2);
    iX = [];
    iY = [];
    % If not in the bounds: ignore
    XLim = get(hAxes, 'XLim');
    YLim = get(hAxes, 'YLim');
    if (X < XLim(1)) || (X > XLim(2)) || (Y < YLim(1)) || (Y > YLim(2))
        X = [];
        Y = [];
        return;
    end
    % Get figure data
    [ValPAC, sPAC] = GetFigureData(hFig);
    if isempty(sPAC)
        return;
    end
    % Get corresponding frequencies
    HF = sPAC.HighFreqs + [0, diff(sPAC.HighFreqs) / 2] - (sPAC.HighFreqs(2)-sPAC.HighFreqs(1)) / 2;
    iX = bst_closest(X, sPAC.LowFreqs);
    iY = bst_closest(Y, HF);
end


%% ===== FIGURE MOUSE WHEEL =====
function FigureMouseWheelCallback(hFig, event)
    % Get scale
    if isempty(event)
        return;
    elseif (event.VerticalScrollCount < 0)
        % ZOOM IN
        Factor = 1 - double(event.VerticalScrollCount) ./ 10;
    elseif (event.VerticalScrollCount > 0)
        % ZOOM OUT
        Factor = 1./(1 + double(event.VerticalScrollCount) ./ 10);
    else
        Factor = 1;
    end
    % CTRL key + scroll: zoom vertically
    if ismember('control', get(hFig,'CurrentModifier'))
        direction = 'vertical';
    % Else: zoom horizontally
    else
        direction = 'horizontal';
    end
    % Apply zoom
    gui_zoom(hFig, direction, Factor);
    % Try to center view on mouse
    CenterViewOnCursor(hFig);
end


%% ===== CENTER VIEW ON MOUSE =====
function CenterViewOnCursor(hFig)
    % Get axes
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'AxesPac');
    % Get current or maximum marker
    hMarker = findobj(hAxes, '-depth', 1, 'Tag', 'SelectionMarker');
    if isempty(hMarker)
        hMarker = findobj(hAxes, '-depth', 1, 'Tag', 'PermanentMarker');
    end
    if isempty(hMarker)
        return;
    end
    % === CENTER HORIZONTALLY ===
    % Get marker X position
    Xcurrent = get(hMarker, 'XData');
    Xcurrent = Xcurrent(1);
    % Get initial XLim 
    XLimInit = getappdata(hFig, 'XLimInit');
    % Get current limits
    XLim = get(hAxes, 'XLim');
    % Center view on time frame
    Xlength = XLim(2) - XLim(1);
    XLim = [Xcurrent - Xlength/2, Xcurrent + Xlength/2];
    XLim = bst_saturate(XLim, XLimInit, 1);
    
    % === CENTER VERTICALLY ===
    % Get marker Y position
    Ycurrent = get(hMarker, 'YData');
    Ycurrent = Ycurrent(1);
    % Get initial YLim 
    YLimInit = getappdata(hFig, 'YLimInit');
    % Get current limits
    YLim = get(hAxes, 'YLim');
    % Center view on time frame
    Ylength = YLim(2) - YLim(1);
    YLim = [Ycurrent - Ylength/2, Ycurrent + Ylength/2];
    YLim = bst_saturate(YLim, YLimInit, 1);
    
    % Update position
    set(hAxes, 'XLim', XLim, 'YLim', YLim);
end


%% ===== KEYBOARD CALLBACK =====
function FigureKeyPressedCallback(hFig, keyEvent)
    global GlobalData;
    % Prevent multiple executions
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'AxesPac')';
    set([hFig hAxes], 'BusyAction', 'cancel');
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);

    % Process event
    switch (keyEvent.Key)
        % === LEFT, RIGHT, PAGEUP, PAGEDOWN : Processed by TimeWindow ===
        case {'leftarrow', 'rightarrow', 'pageup', 'pagedown', 'home', 'end'}
            panel_time('TimeKeyCallback', keyEvent);
        % === UP, DOWN : Processed by Display panel ===
        case {'uparrow', 'downarrow'}
            panel_display('SetSelectedRowName', hFig, keyEvent.Key);
            
        % === DATA FILES : OTHER VIEWS ===
        % CTRL+D : Dock figure
        case 'd'
            if ismember('control', keyEvent.Modifier)
                isDocked = strcmpi(get(hFig, 'WindowStyle'), 'docked');
                bst_figures('DockFigure', hFig, ~isDocked);
            end
        % CTRL+R : Recordings
        case 'r'
            if ismember('control', keyEvent.Modifier)
                % Get figure description
                [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
                % If there is an associated an available DataFile
                if ~isempty(GlobalData.DataSet(iDS).DataFile)
                    view_timeseries(GlobalData.DataSet(iDS).DataFile, GlobalData.DataSet(iDS).Figure(iFig).Id.Modality);
                end
            end
        % CTRL+T : Default topography
        case 't'
            if ismember('control', keyEvent.Modifier)
                bst_figures('ViewTopography', hFig);
            end
        % CTRL+I : Save as image
        case 'i'
            if ismember('control', keyEvent.Modifier)
                out_figure_image(hFig);
            end
        % CTRL+J : Open as image
        case 'j'
            if ismember('control', keyEvent.Modifier)
                out_figure_image(hFig, 'Viewer');
            end
        % CTRL+F : Open as figure
        case 'f'
            if ismember('control', keyEvent.Modifier)
                out_figure_image(hFig, 'Figure');
            end
        % ESCAPE: RESET SELECTION
        case 'escape'
            SetSelectedPoint(hFig, []);
    end
    % Restore events
    set([hFig hAxes], 'BusyAction', 'queue');
end


%% ===== RESET VIEW =====
function ResetView(hFig)
    zoom out
end


%% ===== POPUP MENU =====
function DisplayFigurePopup(hFig)
    import java.awt.event.KeyEvent;
    import javax.swing.KeyStroke;
    import org.brainstorm.icon.*;
    % Get study
    TfInfo = getappdata(hFig,'Timefreq');
    [sStudy,iStudy,iTf] = bst_get('TimefreqFile', TfInfo.FileName);
    % Get axes handles
    hAxes = getappdata(hFig, 'clickSource');
    if isempty(hAxes)
        return
    end
    % Create popup menu
    jPopup = java_create('javax.swing.JPopupMenu');
    
    % ==== DISPLAY OTHER FIGURES ====
    % === View TOPOGRAPHY ===
    if strcmpi(sStudy.Timefreq(iTf).DataType, 'data')
        jItem = gui_component('MenuItem', jPopup, [], 'Topography', IconLoader.ICON_TOPOGRAPHY, [], @(h,ev)bst_figures('ViewTopography', hFig));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_T, KeyEvent.CTRL_MASK));
    end
    % === View RECORDINGS ===
    if ~isempty(sStudy.Timefreq(iTf).DataFile) && strcmpi(sStudy.Timefreq(iTf).DataType, 'data')
        jItem = gui_component('MenuItem', jPopup, [], 'Recordings', IconLoader.ICON_TS_DISPLAY, [], @(h,ev)view_timeseries(sStudy.Timefreq(iTf).DataFile));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_R, KeyEvent.CTRL_MASK));
    end
    if (jPopup.getComponentCount() > 0)
        jPopup.addSeparator();
    end
    
    % ==== MENU: COLORMAP =====
    bst_colormaps('CreateAllMenus', jPopup, hFig, 0);

    % ==== MENU: SNAPSHOT ====
    jPopup.addSeparator();
    jMenuSave = gui_component('Menu', jPopup, [], 'Snapshots', IconLoader.ICON_SNAPSHOT);
        % === SAVE AS IMAGE ===
        jItem = gui_component('MenuItem', jMenuSave, [], 'Save as image', IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@out_figure_image, hFig));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_I, KeyEvent.CTRL_MASK));
        % === OPEN AS IMAGE ===
        jItem = gui_component('MenuItem', jMenuSave, [], 'Open as image', IconLoader.ICON_IMAGE, [], @(h,ev)bst_call(@out_figure_image, hFig, 'Viewer'));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_J, KeyEvent.CTRL_MASK));
        jItem = gui_component('MenuItem', jMenuSave, [], 'Open as figure', IconLoader.ICON_IMAGE, [], @(h,ev)bst_call(@out_figure_image, hFig, 'Figure'));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_F, KeyEvent.CTRL_MASK));
        jMenuSave.addSeparator();
        % === EXPORT TO DATABASE ===
        gui_component('MenuItem', jMenuSave, [], 'Export to database', IconLoader.ICON_TIMEFREQ, [], @(h,ev)bst_call(@out_figure_timefreq, hFig, 'Database'));
        % === EXPORT TO FILE ===
        gui_component('MenuItem', jMenuSave, [], 'Export to file', IconLoader.ICON_TS_EXPORT, [], @(h,ev)bst_call(@out_figure_timefreq, hFig, []));
        % === EXPORT TO MATLAB ===
        gui_component('MenuItem', jMenuSave, [], 'Export to Matlab', IconLoader.ICON_MATLAB_EXPORT, [], @(h,ev)bst_call(@out_figure_timefreq, hFig, 'Variable'));

    % ==== MENU: FIGURE ====
    jMenuFigure = gui_component('Menu', jPopup, [], 'Figure', IconLoader.ICON_LAYOUT_SHOWALL, [], []);
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
           
    % Display Popup menu
    gui_popup(jPopup, hFig);
end


%% ===========================================================================
%  ===== DISPLAY FUNCTIONS ===================================================
%  ===========================================================================
%% ===== GET FIGURE DATA =====
function [ValPAC, sPAC, DataType, TfInfo] = GetFigureData(hFig)
    global GlobalData;
    % Initialize returned variables
    ValPAC   = [];
    sPAC     = [];
    DataType = [];
    % ===== GET INFORMATION =====
    % Get selected row
    TfInfo = getappdata(hFig, 'Timefreq');
    if isempty(TfInfo)
        return
    end
    % Get data description
    [iDS, iTimefreq] = bst_memory('GetDataSetTimefreq', TfInfo.FileName);
    if isempty(iDS)
        return
    end
    % ===== GET DATA =====
    % Get data
    [ValPAC, sPAC] = bst_memory('GetPacValues', iDS, iTimefreq, TfInfo.RowName);
    % Data type
    DataType = GlobalData.DataSet(iDS).Timefreq(iTimefreq).DataType;
end


%% ===== UPDATE FIGURE PLOT =====
function UpdateFigurePlot(hFig, isForced)
    global GlobalData;
    if (nargin < 2) || isempty(isForced)
        isForced = 0;
    end
    
    % ===== GET GLOBAL MAXIMUM =====
    % Get data
    [ValPAC, sPAC, DataType, TfInfo] = GetFigureData(hFig);
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    TopoHandles = GlobalData.DataSet(iDS).Figure(iFig).Handles;
    % If maximum is not defined yet
    if isempty(TopoHandles.DataMinMax) || isForced
        TopoHandles.DataMinMax = [min(sPAC.DirectPAC(:)), max(sPAC.DirectPAC(:))];
    end

    % ===== GET COLORMAP =====    
    % Get figure colormap
    ColormapInfo = getappdata(hFig, 'Colormap');
    sColormap = bst_colormaps('GetColormap', ColormapInfo.Type);
    % Displaying LOG values: always use the "RealMin" display
    if strcmpi(TfInfo.Function, 'log')
        sColormap.isRealMin = 1;
    end
    % Get figure maximum
    MinMaxVal = bst_colormaps('GetMinMax', sColormap, sPAC.DirectPAC, TopoHandles.DataMinMax);
    % Absolute values
    if sColormap.isAbsoluteValues
        sPAC.DirectPAC = abs(sPAC.DirectPAC);
    end
    % If all the values are the same
    if ~isempty(MinMaxVal) && (MinMaxVal(1) == MinMaxVal(2))
        MinMaxVal(2) = MinMaxVal(2) + eps;
    end
    
    % ===== PLOT DATA =====
    % Find axes
    hAxes = findobj(hFig, '-depth', 1, 'tag', 'AxesPac');
    % Delete previous objects
    delete(findobj(hAxes, '-depth', 1, 'tag', 'PacSurf'));
    delete(findobj(hAxes, '-depth', 1, 'tag', 'PermanentMarker'));
    % Remove the first dimensions (row,time)
    Data = reshape(sPAC.DirectPAC(1,1,:,:), [size(sPAC.DirectPAC,3), size(sPAC.DirectPAC,4)])';

    % Interpolation for high resolution
    if (TfInfo.HighResolution)
        % Interpolated surface size
        res = [300, 300];
        % Create index grids
        X = sPAC.LowFreqs;
        Y = sPAC.HighFreqs;
        Xbounds = [sPAC.LowFreqs(1), sPAC.LowFreqs(end)]   + [-.5, .5] .* (sPAC.LowFreqs(2) - sPAC.LowFreqs(1));
        Ybounds = [sPAC.HighFreqs(1), sPAC.HighFreqs(end)] + [-.5, .5] .* (sPAC.HighFreqs(2) - sPAC.HighFreqs(1));
        [X1,Y1] = meshgrid(X, Y);
        [X2,Y2] = meshgrid(linspace(Xbounds(1), Xbounds(2), res(1)),  linspace(Ybounds(1), Ybounds(2), res(2)));
        % Re-interpolate for high-resolution display: one value per pixel
        Data = interp2(X1, Y1, Data, X2, Y2, 'spline');
        % Plot new surface  
        surface('XData',     X2, ...
                'YData',     Y2, ...
                'ZData',     0.001*ones(size(X2)), ...
                'CData',     Data, ...
                'FaceColor', 'interp', ...
                'EdgeColor', 'none', ...
                'AmbientStrength',  .5, ...
                'DiffuseStrength',  .5, ...
                'SpecularStrength', .6, ...
                'Tag',              'PacSurf', ...
                'Parent',           hAxes);
    else
        % Prepare frequency coordinates
        X = [sPAC.LowFreqs,  2*sPAC.LowFreqs(end)  - sPAC.LowFreqs(end-1)]  - (sPAC.LowFreqs(2) -sPAC.LowFreqs(1))  / 2;
        Y = [sPAC.HighFreqs, 2*sPAC.HighFreqs(end) - sPAC.HighFreqs(end-1)] - (sPAC.HighFreqs(2)-sPAC.HighFreqs(1)) / 2;
        Xbounds = [X(1), X(end)];
        Ybounds = [Y(1), Y(end)];
        % Grid values
        [XData,YData] = meshgrid(X,Y);
        % Plot new surface  
        surface('XData',     XData, ...
                'YData',     YData, ...
                'ZData',     0.001*ones(size(XData)), ...
                'CData',     Data, ...
                'FaceColor', 'flat', ...
                'EdgeColor', 'none', ...
                'AmbientStrength',  .5, ...
                'DiffuseStrength',  .5, ...
                'SpecularStrength', .6, ...
                'Tag',              'PacSurf', ...
                'Parent',           hAxes);
    end
    % Add marker around the maximum value
    iX = bst_closest(sPAC.NestingFreq, sPAC.LowFreqs);
    iY = bst_closest(sPAC.NestedFreq, sPAC.HighFreqs);
    SetSelectedPoint(hFig, iX, iY, 1);
    % Update figure handles
    GlobalData.DataSet(iDS).Figure(iFig).Handles = TopoHandles;
    
    % ===== CONFIGURE AXES =====
    % Set properties
    set(hAxes, 'YGrid',      'off', ... 
               'XGrid',      'off', 'XMinorGrid', 'off', ...
               'XLim',       Xbounds, ...
               'YLim',       Ybounds, ...
               'CLim',       MinMaxVal, ...
               'Box',        'on', ...
               'FontName',   'Default', ...
               'FontUnits',  'Points', ...
               'FontWeight', 'Normal',...
               'FontSize',   bst_get('FigFont'), ...
               'Color',      [.9 .9 .9], ...
               'XColor',     [0 0 0], ...
               'YColor',     [0 0 0], ...
               'Visible',    'on');
    % Labels
    xlabel(hAxes, 'Frequency for Phase (Hz)');
    ylabel(hAxes, 'Frequency for Amplitude (Hz)');
    % Axes title
    axesTitle = sprintf('MaxPAC = %1.2e      flow = %3.2f Hz      fhigh = %3.2f Hz', ValPAC, sPAC.NestingFreq, sPAC.NestedFreq);
    if ischar(TfInfo.RowName) && all(TfInfo.RowName ~= ' ')
        axesTitle = [TfInfo.RowName, ': ' axesTitle];
    elseif isnumeric(TfInfo.RowName)
        axesTitle = ['Source #', num2str(TfInfo.RowName), ': ' axesTitle];
    end
    title(hAxes, axesTitle, 'Interpreter', 'none');
    % Store initial XLim and YLim
    setappdata(hFig, 'XLimInit', get(hAxes, 'XLim'));
    setappdata(hFig, 'YLimInit', get(hAxes, 'YLim'));

    % ===== COLORBAR =====
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
    bst_colormaps('ConfigureColorbar', hFig, ColormapInfo.Type, DataType, ColormapInfo.DisplayUnits);
end


%% ===== SET SELECTED POINT =====
function SetSelectedPoint(hFig, iX, iY, isPermanent)
    % Get data
    [ValPAC, sPAC] = GetFigureData(hFig);
    % Find axes
    hAxes = findobj(hFig, '-depth', 1, 'tag', 'AxesPac');
    % Delete previous markers
    hMarker = findobj(hAxes, '-depth', 1, 'tag', 'SelectionMarker');
    delete(hMarker);
    % Reset display
    if (nargin < 2) || isempty(iX)
        xlabel(hAxes, 'Frequency for Phase (Hz)');
    % Set marker
    else
        % Permanent marker: white, not destroyed
        if isPermanent
            markerTag = 'PermanentMarker';
            markerColor = [1 1 1];
        else
            markerTag = 'SelectionMarker';
            markerColor = [1 0 0];
        end
        % Get a correct cursor position in Y direction
        Y = [sPAC.HighFreqs, 2*sPAC.HighFreqs(end) - sPAC.HighFreqs(end-1)] - (sPAC.HighFreqs(2)-sPAC.HighFreqs(1)) / 2;
        Ypos = (Y(iY) + Y(iY+1)) ./ 2;
        % Add marker around the selected value
        line(sPAC.LowFreqs(iX), Ypos, 0.002, ...
            'Parent',          hAxes, ...
            'LineWidth',       2, ...
            'LineStyle',       'none', ...
            'MarkerFaceColor', 'none', ...
            'MarkerEdgeColor', markerColor, ...
            'MarkerSize',      7, ...
            'Marker',          'o', ...
            'Tag',             markerTag);
        % Get selected value
        Value = sPAC.DirectPAC(1,1,iX,iY);
        % Set the x label
        xlabel(hAxes, sprintf('Selection:   PAC = %1.2e    flow = %3.2f Hz    fhigh = %3.2f Hz', Value, sPAC.LowFreqs(iX), sPAC.HighFreqs(iY)));
    end
end



