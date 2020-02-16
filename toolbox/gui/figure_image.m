function varargout = figure_image( varargin )
% FIGURE_IMAGE: Creation and callbacks for diplaying images.
%
% USAGE:  hFig = figure_image('CreateFigure', FigureId)

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
% Authors: Francois Tadel, 2014-2017

eval(macro_method);
end


%% ===== CREATE FIGURE =====
function hFig = CreateFigure(FigureId) %#ok<DEFNU>
    MatlabVersion = bst_get('MatlabVersion');
    % Get renderer name
    if (bst_get('DisableOpenGL') ~= 1)
        rendererName = 'opengl';
    elseif (MatlabVersion <= 803)   % zbuffer was removed in Matlab 2014b
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
    % Disable automatic legends (after 2017a)
    if (MatlabVersion >= 902) 
        set(hFig, 'defaultLegendAutoUpdate', 'off');
    end
    % Create axes
    hAxes = axes('Units',         'normalized', ...
                 'Interruptible', 'off', ...
                 'BusyAction',    'queue', ...
                 'Parent',        hFig, ...
                 'Tag',           'AxesImage', ...
                 'YDir',          'reverse', ...
                 'Visible',       'off');
    %axis image;
    % Prepare figure appdata
    setappdata(hFig, 'FigureId', FigureId);
    setappdata(hFig, 'hasMoved', 0);
    setappdata(hFig, 'isPlotEditToolbar', 0);
    setappdata(hFig, 'isStatic', 1);
    setappdata(hFig, 'isStaticFreq', 0);
    setappdata(hFig, 'Colormap', db_template('ColormapInfo'));
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
    % Redraw figure
    UpdateFigurePlot(hFig);
end

%% ===== CURRENT FREQUENCY CHANGED =====
function CurrentFreqChangedCallback(hFig)   %#ok<DEFNU>
    % If no time in this figure
    if getappdata(hFig, 'isStaticFreq')
        return;
    end
    % Redraw figure
    UpdateFigurePlot(hFig);
end


%% ===== RESIZE CALLBACK =====
function ResizeCallback(hFig, ev)
    % Get colorbar and axes handles
    hColorbar = findobj(hFig, '-depth', 1, 'Tag', 'Colorbar');
    hAxes     = findobj(hFig, '-depth', 1, 'Tag', 'AxesImage');
    if isempty(hAxes)
        return
    end
    hAxes = hAxes(1);
    % Do not resize unless there is a display already
    if isempty(findobj(hAxes, '-depth', 1, 'tag', 'ImageSurf'))
        return
    end
    % Get figure position and size in pixels
    figPos = get(hFig, 'Position');
    % Define constants
    colorbarWidth = 15;
    marginTop     = 10;
    
    % Define the size of the bottom margin, function of the labels that have to be displayed
    XTickLabel = get(hAxes, 'XTickLabel');
    if isempty(XTickLabel)
        marginBottom = 25;
    elseif iscell(XTickLabel) && ~isempty(XTickLabel{1}) && isempty(num2str(XTickLabel{1}))
        % Get the largest frequency band string
        strMax = max(cellfun(@length, XTickLabel));
        marginBottom = 35 + 5 * min(15, strMax);
    else
        marginBottom = 40;
    end
    
    % Define the size of the left margin in function of the labels that have to be displayed
    YTickLabel = get(hAxes, 'YTickLabel');
    if isempty(YTickLabel) || ~iscell(YTickLabel) || isempty(YTickLabel{1}) || ~ischar(YTickLabel{1})
        marginLeft = 25;
    else
        % Get the largest frequency band string
        strMax = max(cellfun(@length, YTickLabel));
        marginLeft = 40 + 5 * min(15, strMax);
    end

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
    global GlobalData;
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
            [iA,iB,Value,LabelA,LabelB,DimLabels] = GetMousePosition(hFig, hAxes);
            % Propagate selection to other figures
            if ~isempty(LabelA) && ~isempty(LabelB)
                % Get figure description
                [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
                % Get selected dimensions
                iDims = GlobalData.DataSet(iDS).Figure(iFig).Handles.iDims;
                % === CHANNELS/ROWS ===
                % Dimension #1 and #2 are data rows
                if ismember(iDims(1), [1 2]) && ismember(iDims(2), [1 2])
                    selRows   = {LabelA, LabelB, [LabelA ' x ' LabelB]};
                    selScouts = {LabelA, LabelB};
                % Dimension #1 is data row
                elseif ismember(iDims(1), [1 2])
                    selRows   = {LabelA};
                    selScouts = {LabelA};
                % Dimension #2 is data row
                elseif ismember(iDims(2), [1 2])
                    selRows   = {LabelB};
                    selScouts = {LabelB};
                else
                    selRows   = [];
                    selScouts = [];
                end
                % === TIME ===
                % Dimension #1 is time
                if (iDims(1) == 3)
                    selTime = str2num(LabelA);
                % Dimension #2 is time
                elseif (iDims(2) == 3)
                    selTime = str2num(LabelB);
                else
                    selTime = [];
                end
                % Select time
                if ~isempty(selTime)
                    panel_time('SetCurrentTime', selTime);
                end
                % Select scouts
                if ~isempty(selScouts)
                    panel_scout('SetSelectedScoutLabels', {LabelA, LabelB});
                end
                % Select rows
                if ~isempty(selRows)
                    bst_figures('SetSelectedRows', {LabelA, LabelB, [LabelA ' x ' LabelB]});
                end
            end
            % Set selected point in the image
            if ~isempty(iA)
                SetSelectedPoint(hFig, iA, iB, Value, LabelA, LabelB, DimLabels);
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
            YLim = YLim - (YLim(1) - YLim(2)) * motionFigure(2);
            YLim = bst_saturate(YLim, YLimInit, 1);
            set(hAxes, 'YLim', YLim);
            
        case 'selection'
            % Get new time and frequency
            [iA,iB,Value,LabelA,LabelB,DimLabels] = GetMousePosition(hFig, hAxes);
            % Set selected point in the image
            if ~isempty(iA)
                SetSelectedPoint(hFig, iA, iB, Value, LabelA, LabelB, DimLabels);
            end
            
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
    global GlobalData;
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
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    if isequal(GlobalData.DataSet(iDS).Figure(iFig).Handles.PageName, '$freq')
        bst_figures('SetCurrentFigure', hFig, 'TF');
    else
        bst_figures('SetCurrentFigure', hFig, '2D');
    end
end


%% ===== GET MOUSE POSITION =====
function [iA, iB, Value, LabelA, LabelB, DimLabels, Labels] = GetMousePosition(hFig, hAxes)
    % Initialize returned variables
    iA = [];
    iB = [];
    Value = [];
    LabelA = [];
    LabelB = [];
    % Get current point in axes
    CurPoint = get(hAxes, 'CurrentPoint');
    X = CurPoint(1,1);
    Y = CurPoint(1,2);
    % Get figure data
    [Data, Labels, DimLabels] = GetFigureData(hFig);
    if isempty(Data)
        return;
    end
    % If not in the bounds: ignore
    XLim = get(hAxes, 'XLim');
    YLim = get(hAxes, 'YLim');
    if (X < XLim(1)) || (X > XLim(2)) || (Y < YLim(1)) || (Y > YLim(2))
        return;
    end
    % Get corresponding frequencies
    iB = floor(X);
    iA = floor(Y);
    % Get selected value
    Value = Data(iA,iB,1,1);
    % Label A
    if isempty(Labels{1})
        LabelA = 'None';
    elseif (length(Labels{1}) == 1) || (iA > length(Labels{1}))
        LabelA = Labels{1};
    else
        LabelA = Labels{1}(iA);
    end
    if iscell(LabelA)
        LabelA = LabelA{1};
    end
    if isnumeric(LabelA)
        LabelA = num2str(LabelA);
    end
    % Label B
    if isempty(Labels{2})
        LabelB = 'None';
    elseif (length(Labels{2}) == 1) || (iB > length(Labels{2}))
        LabelB = Labels{2};
    else
        LabelB = Labels{2}(iB);
    end
    if iscell(LabelB)
        LabelB = LabelB{1};
    end
    if isnumeric(LabelB)
        LabelB = num2str(LabelB);
    end
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
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'AxesImage');
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
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'AxesImage')';
    set([hFig hAxes], 'BusyAction', 'cancel');
    
    % If Shift key is pressed: montage selection 
    if ismember('shift', get(hFig,'CurrentModifier'))
        % Other key: process it 
        isProcessed = panel_montage('ProcessKeyPress', hFig, keyEvent.Key);
        if isProcessed
            return
        end
    end
    
    % Process event
    switch (keyEvent.Key)
        % === LEFT, RIGHT, PAGEUP, PAGEDOWN : Processed by TimeWindow ===
        case {'leftarrow', 'rightarrow', 'pageup', 'pagedown', 'home', 'end'}
            panel_time('TimeKeyCallback', keyEvent);
        % === UP, DOWN : Processed by Display panel ===
        case {'uparrow', 'downarrow'}
            % Get figure description
            [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
            % Change frequency 
            if isequal(GlobalData.DataSet(iDS).Figure(iFig).Handles.PageName, '$freq')
                panel_freq('FreqKeyCallback', keyEvent);
            % Change selected page
            else
                panel_display('SetSelectedPage', hFig, keyEvent.Key);
            end

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
            % Get figure description
            [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
            % Reset selection
            SetSelectedPoint(hFig, [], [], [], [], [], GlobalData.DataSet(iDS).Figure(iFig).Handles.DimLabels);
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
    global GlobalData;
    % Get axes handles
    hAxes = getappdata(hFig, 'clickSource');
    if isempty(hAxes)
        return
    end
    % Create popup menu
    jPopup = java_create('javax.swing.JPopupMenu');
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    FigId = GlobalData.DataSet(iDS).Figure(iFig).Id;
    
    % ==== MENU: COLORMAP =====
    bst_colormaps('CreateAllMenus', jPopup, hFig, 0);
    % ==== MENU: MONTAGE ====
    if isequal(FigId.SubType, 'erpimage')
        jMenuMontage = gui_component('Menu', jPopup, [], 'Montage', IconLoader.ICON_TS_DISPLAY_MODE);
        panel_montage('CreateFigurePopupMenu', jMenuMontage, hFig);
    end
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
    % ==== MENU: FIGURE ====
    jMenuFigure = gui_component('Menu', jPopup, [], 'Figure', IconLoader.ICON_LAYOUT_SHOWALL);
        % Legend
        ShowLabels = GlobalData.DataSet(iDS).Figure(iFig).Handles.ShowLabels;
        jItem = gui_component('CheckBoxMenuItem', jMenuFigure, [], 'Show labels', IconLoader.ICON_LABELS, [], @(h,ev)SetShowLabels(iDS, iFig, ~ShowLabels));
        jItem.setSelected(ShowLabels);
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
           
    % Display Popup menu
    gui_popup(jPopup, hFig);
end


%% ===========================================================================
%  ===== DISPLAY FUNCTIONS ===================================================
%  ===========================================================================
%% ===== GET FIGURE DATA =====
function [Data, Labels, DimLabels, DataMinMax, ShowLabels, PageName] = GetFigureData(hFig, isResetMax)
    global GlobalData;
    % Parse inputs
    if (nargin < 2) || isempty(isResetMax)
        isResetMax = 0;
    end
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    if isempty(iFig)
        Data = [];
        Labels = [];
        DimLabels = [];
        DataMinMax = [];
        ShowLabels = [];
        return;
    end
    AllLabels  = GlobalData.DataSet(iDS).Figure(iFig).Handles.Labels;
    iDims      = GlobalData.DataSet(iDS).Figure(iFig).Handles.iDims;
    DimLabels  = GlobalData.DataSet(iDS).Figure(iFig).Handles.DimLabels;
    ShowLabels = GlobalData.DataSet(iDS).Figure(iFig).Handles.ShowLabels;
    PageName   = GlobalData.DataSet(iDS).Figure(iFig).Handles.PageName;
    % Get indices for 1st dimension
    if ismember(1, iDims)
        ind{1} = 1:size(GlobalData.DataSet(iDS).Figure(iFig).Handles.Data, 1);
    else
        ind{1} = 1;
    end
    % Get indices for 2nd dimension
    if ismember(2, iDims)
        ind{2} = 1:size(GlobalData.DataSet(iDS).Figure(iFig).Handles.Data, 2);
    else
        ind{2} = 1;
    end
    % Get current time
    if ismember(3, iDims)
        ind{3} = 1:size(GlobalData.DataSet(iDS).Figure(iFig).Handles.Data, 3);
    elseif ~getappdata(hFig, 'isStatic')
        [TimeVector, ind{3}] = bst_memory('GetTimeVector', iDS, [], 'CurrentTimeIndex');
    else
        ind{3} = 1;
    end
    % Get current frequency
    if ismember(4, iDims)
        ind{4} = 1:size(GlobalData.DataSet(iDS).Figure(iFig).Handles.Data, 4);
    elseif strcmpi(PageName, '$freq')
        if ~getappdata(hFig, 'isStaticFreq')
            ind{4} = GlobalData.UserFrequencies.iCurrentFreq;
        else
            ind{4} = 1;
        end
    elseif ~isempty(PageName) && ~isempty(AllLabels{4})
        iPage = find(strcmpi(PageName, AllLabels{4}));
        if ~isempty(iPage)
            ind{4} = iPage;
        else
            ind{4} = 1;
        end
    else
        ind{4} = 1;
    end
    % Get current data
    Data = GlobalData.DataSet(iDS).Figure(iFig).Handles.Data(ind{1}, ind{2}, ind{3}, ind{4});
    % Permute to get the two dimensions of interest as the first ones
    iPerm = [iDims, setdiff([1 2 3 4], iDims)];
    Data = permute(Data, iPerm);
    % Get rid of the unused dimensions
    Data = Data(:,:,1,1);
    % Get labels: dimension 1
    Labels{1} = AllLabels{iDims(1)};
    if ~isempty(Labels{1}) && (max(ind{iDims(1)}) < length(Labels{1}))
        Labels{1} = Labels{1}(ind{iDims(1)});
    end
    % Get labels: dimension 1
    Labels{2} = AllLabels{iDims(2)};
    if ~isempty(Labels{2}) && (max(ind{iDims(2)}) < length(Labels{2}))
        Labels{2} = Labels{2}(ind{iDims(2)});
    end
    % If maximum is not defined yet: Update figure handles
    if isResetMax || isempty(GlobalData.DataSet(iDS).Figure(iFig).Handles.DataMinMax)
        GlobalData.DataSet(iDS).Figure(iFig).Handles.DataMinMax = [min(Data(:)), max(Data(:))];
    end
    DataMinMax = GlobalData.DataSet(iDS).Figure(iFig).Handles.DataMinMax;
end


%% ===== UPDATE FIGURE PLOT =====
function UpdateFigurePlot(hFig, isResetMax)
    % Parse inputs
    if (nargin < 2) || isempty(isResetMax)
        isResetMax = 0;
    end

    % ===== GET DATA AND COLORMAP =====
    % If forced refresh: reset previous min/max
    % Get figure data
    [FigData, Labels, DimLabels, DataMinMax, ShowLabels, PageName] = GetFigureData(hFig, isResetMax);
    % Get figure colormap
    ColormapInfo = getappdata(hFig, 'Colormap');
    sColormap = bst_colormaps('GetColormap', ColormapInfo.Type);
    % Get figure maximum
    MinMaxVal = bst_colormaps('GetMinMax', sColormap, FigData, DataMinMax);
    % Absolute values
    if sColormap.isAbsoluteValues
        FigData = abs(FigData);
    end
    % If all the values are the same
    if any(isnan(MinMaxVal))
        MinMaxVal = [0 1];
    elseif ~isempty(MinMaxVal) && (MinMaxVal(1) == MinMaxVal(2))
        MinMaxVal(2) = MinMaxVal(2) + eps;
    end
    
    % ===== PLOT DATA =====
    % Find axes
    hAxes = findobj(hFig, '-depth', 1, 'tag', 'AxesImage');
    % Delete previous objects
    delete(findobj(hAxes, '-depth', 1, 'tag', 'ImageSurf'));
    delete(findobj(hAxes, '-depth', 1, 'tag', 'PermanentMarker'));
    delete(findobj(hAxes, '-depth', 1, 'tag', 'SelectionMarker'));
    % Prepare frequency coordinates
    X = 1:size(FigData,2)+1;
    Y = 1:size(FigData,1)+1;
    % Grid values
    [XData,YData] = meshgrid(X,Y);
    % Plot new surface  
    surface('XData',     XData, ...
            'YData',     YData, ...
            'ZData',     0.001*ones(size(XData)), ...
            'CData',     FigData, ...
            'FaceColor', 'flat', ...
            'EdgeColor', 'none', ...
            'AmbientStrength',  .5, ...
            'DiffuseStrength',  .5, ...
            'SpecularStrength', .6, ...
            'Tag',              'ImageSurf', ...
            'Parent',           hAxes);
    
    % ===== CONFIGURE AXES =====
    % Set properties
    set(hAxes, 'YGrid',      'off', ... 
               'XGrid',      'off', 'XMinorGrid', 'off', ...
               'XLim',       [X(1), X(end)], ...
               'YLim',       [Y(1), Y(end)], ...
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
    % No interpreter in the labels
    if isprop(hAxes, 'TickLabelInterpreter')
        set(hAxes, 'TickLabelInterpreter', 'none');
    end
    % X Label
    xlabel(hAxes, DimLabels{2});
    % Y Label
    strLabelY = DimLabels{1};
    % X Ticks
    if ShowLabels && ~isempty(strfind(DimLabels{2}, 'Time')) && isnumeric(Labels{2})
        % Get limits (time values and axes limits)
        TimeWindow = [Labels{2}(1), Labels{2}(end)];
        XLim = get(hAxes, 'XLim');
        % Get reasonable ticks spacing
        [XTick, XTickLabel] = bst_colormaps('GetTicks', TimeWindow, XLim, 1);
        % Set the axes ticks
        set(hAxes, 'XTickMode',      'manual', ...
                   'XTickLabelMode', 'manual', ...
                   'XTick',          XTick, ...
                   'XTickLabel',     XTickLabel);
    elseif ShowLabels && iscell(Labels{2}) && ~isempty(Labels{2}) && ischar(Labels{2}{1})
        % Remove all the common parts of the labels
        tmpLabels = str_remove_common(Labels{2});
        if ~isempty(tmpLabels)
            Labels{2} = tmpLabels;
        end
        % Limit the size of the comments to 15 characters
        Labels{2} = cellfun(@(c)c(max(1,length(c)-14):end), Labels{2}, 'UniformOutput', 0);
        % Show the names of each row
        set(hAxes, 'XTickMode',      'manual', ...
                   'XTickLabelMode', 'manual', ...
                   'XTick',          (1:size(FigData,1)) + 0.5, ...
                   'XTickLabel',     Labels{2});
        % New versions of Matlab only (Matlab >= 2014b)
        if (bst_get('MatlabVersion') >= 804)
            set(hAxes, 'XTickLabelRotation', 45)
        end
    else
        set(hAxes, 'XTick',      [], ...
                   'XTickLabel', []);
    end
    % Y Ticks
    if ShowLabels && ~isempty(Labels) && ~isempty(strfind(DimLabels{1}, 'Time')) && isnumeric(Labels{1})
        % Get limits (time values and axes limits)
        TimeWindow = [Labels{1}(1), Labels{1}(end)];
        YLim = get(hAxes, 'YLim');
        % Get reasonable ticks spacing
        [YTick, YTickLabel] = bst_colormaps('GetTicks', TimeWindow, YLim, 1);
        % Set the axes ticks
        set(hAxes, 'YTickMode',      'manual', ...
                   'YTickLabelMode', 'manual', ...
                   'YTick',          YTick, ...
                   'YTickLabel',     cellstr(YTickLabel));
    elseif ShowLabels && ~isempty(Labels)
        if iscellstr(Labels{1})
            % Remove all the common parts of the labels
            tmpLabels = str_remove_common(Labels{1});
            if ~isempty(tmpLabels)
                Labels{1} = tmpLabels;
            end
            % Limit the size of the comments to 15 characters
            Labels{1} = cellfun(@(c)c(max(1,length(c)-14):end), Labels{1}, 'UniformOutput', 0);
        end
        % Show the names of each row
        set(hAxes, 'YTickMode',      'manual', ...
                   'YTickLabelMode', 'manual', ...
                   'YTick',          (1:size(FigData,1)) + 0.5, ...
                   'YTickLabel',     Labels{1});
        if ~isempty(PageName) && ~isequal(PageName, '$freq')
            strLabelY = [strLabelY '    (' PageName ')'];
        end
    else
        set(hAxes, 'YTick',      [], ...
                   'YTickLabel', []);
    end
    % Set Y Legend
    ylabel(hAxes, strLabelY);
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
    bst_colormaps('ConfigureColorbar', hFig, ColormapInfo.Type, 'image', ColormapInfo.DisplayUnits);
end


%% ===== SET SELECTED POINT =====
function SetSelectedPoint(hFig, iA, iB, Value, LabelA, LabelB, DimLabels, isPermanent)
    % Default values
    if (nargin < 8) || isempty(isPermanent)
        isPermanent = 0;
    end
    % Find axes
    hAxes = findobj(hFig, '-depth', 1, 'tag', 'AxesImage');
    % Delete previous markers
    hMarker = findobj(hAxes, '-depth', 1, 'tag', 'SelectionMarker');
    delete(hMarker);
    % Get the X and Y vectors
    hSurf = findobj(hAxes, '-depth', 1, 'tag', 'ImageSurf');
    XData = get(hSurf, 'XData');
    YData = get(hSurf, 'YData');
    XData = XData(1,:);
    YData = YData(:,1)';
    % Reset display
    if (nargin < 2) || isempty(iA)
        xlabel(hAxes, DimLabels{2});
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
        % Place marker point at the middle of the bin
        Xdisp = (XData(iB) + XData(iB+1)) / 2;
        Ydisp = (YData(iA) + YData(iA+1)) / 2;
        % Add marker around the selected value
        line(Xdisp, Ydisp, 0.002, ...
            'Parent',          hAxes, ...
            'LineWidth',       2, ...
            'LineStyle',       'none', ...
            'MarkerFaceColor', 'none', ...
            'MarkerEdgeColor', markerColor, ...
            'MarkerSize',      7, ...
            'Marker',          'o', ...
            'Tag',             markerTag);
        % Set the x label
        if (length(LabelA) > 40)
            LabelA = [LabelA(1:40), '...'];
        end
        if (length(LabelB) > 40)
            LabelB = [LabelB(1:40), '...'];
        end
        xlabel(hAxes, sprintf('(%d,%d)    =    [%s x %s]    =    %s', iA, iB, LabelA, LabelB, num2str(Value)), 'Interpreter', 'none');
    end
end


%% ===== SHOW/HIDE LABELS =====
function SetShowLabels(iDS, iFig, ShowLabels)
    global GlobalData;
    % Save new value
    GlobalData.DataSet(iDS).Figure(iFig).Handles.ShowLabels = ShowLabels;
    % Update figure
    UpdateFigurePlot(GlobalData.DataSet(iDS).Figure(iFig).hFigure, 1);
    % Resize to update the size of the margins
    ResizeCallback(GlobalData.DataSet(iDS).Figure(iFig).hFigure);
end


