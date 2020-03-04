function varargout = figure_timefreq( varargin )
% FIGURE_TIMEFREQ: Creation and callbacks for time frequency figures.
%
% USAGE:  hFig = figure_timefreq('CreateFigure', FigureId)
%                figure_timefreq('CurrentTimeChangedCallback',  iDS, iFig)
%                figure_timefreq('SetTimefreqSelection',        hFig, newSelection)

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
% Authors: Francois Tadel, 2010-2020

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
                  'CloseRequestFcn',         @FigureClosedCallback, ...
                  'KeyPressFcn',             @FigureKeyPressedCallback, ...
                  'WindowButtonDownFcn',     @FigureMouseDownCallback, ...
                  'WindowButtonUpFcn',       @FigureMouseUpCallback, ...
                  bst_get('ResizeFunction'), @ResizeCallback);
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
                 'Tag',           'AxesTimefreq', ...
                 'Visible',       'off');
             
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
end


%% ===========================================================================
%  ===== FIGURE CALLBACKS ====================================================
%  ===========================================================================

%% ===== FIGURE CLOSED CALLBACK =====
function FigureClosedCallback(hFig, ev)
    global GlobalData;
    GlobalData.UserFrequencies.HideFreqPanel = 0;
    bst_figures('DeleteFigure', hFig, ev);
end

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
    % Check figure type (2DLayout: nothing to move)
    TfInfo = getappdata(hFig, 'Timefreq');
    if ismember(TfInfo.DisplayMode, {'2DLayout', '2DLayoutOpt', 'AllSensors'})
        return
    end
    % Get axes handles
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'AxesTimefreq');
    if ~isempty(hAxes)
        PlotTimefreqCursor(hAxes);
    end
end

%% ===== CURRENT FREQ CHANGED =====
function CurrentFreqChangedCallback(hFig)   %#ok<DEFNU>
    % If no frequencies in this figure
    if getappdata(hFig, 'isStaticFreq')
        return;
    end
    % Check figure type (2DLayout: nothing to move)
    TfInfo = getappdata(hFig, 'Timefreq');
    if ismember(TfInfo.DisplayMode, {'2DLayout', '2DLayoutOpt', 'AllSensors'})
        return
    end
    % Get axes handles
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'AxesTimefreq');
    if ~isempty(hAxes)
        PlotTimefreqCursor(hAxes);
    end
end


%% ===== RESIZE CALLBACK =====
function ResizeCallback(hFig, ev)
    global GlobalData;
    % Get colorbar and axes handles
    hColorbar = findobj(hFig, '-depth', 1, 'Tag', 'Colorbar');
    hAxes     = findobj(hFig, '-depth', 1, 'Tag', 'AxesTimefreq');
    if isempty(hAxes)
        return
    end
    hAxes = hAxes(1);
    % Do not resize unless there is a Time-freq display already
    if isempty(findobj(hAxes, '-depth', 1, 'tag', 'TimefreqSurf')) && isempty(findobj(hAxes, '-depth', 1, 'tag', 'TimefreqSurfSmall'))
        return
    end
    % Get display description
    TfInfo = getappdata(hFig, 'Timefreq');
    if isempty(TfInfo)
        return
    end
    % Get figure position and size in pixels
    figPos = get(hFig, 'Position');
    % Scale figure
    Scaling = bst_get('InterfaceScaling') / 100;
    % Define constants
    colorbarWidth = 15 .* Scaling;
    if ismember(lower(TfInfo.DisplayMode), {'2dlayout', '2dlayoutopt'})
        marginLeft   = 10 .* Scaling;
        marginTop    = 5 .* Scaling;
        marginBottom = 20 .* Scaling;
        marginRight  = 10 .* Scaling;
    else
        marginTop    = 25 .* Scaling;
        marginBottom = 35 .* Scaling;
        marginRight  = 30 .* Scaling;
        % Define the size of the left margin in function of the labels that have to be displayed
        if ~iscell(GlobalData.UserFrequencies.Freqs)
            if all(GlobalData.UserFrequencies.Freqs == round(GlobalData.UserFrequencies.Freqs))
                marginLeft = 40 .* Scaling;
            else
                marginLeft = 55 .* Scaling;
            end
        else
            % Get the largest frequency band string
            strMax = max(cellfun(@length, GlobalData.UserFrequencies.Freqs(:,1)));
            marginLeft = (20 + 5*strMax) .* Scaling;
        end
    end
    % If colorbar: Add a small label to hide the x10^exp on top of the colorbar
    hLabelHideExp = findobj(hFig, '-depth', 1, 'tag', 'labelMaskExp');
    % Reposition the colorbar
    if ~isempty(hColorbar)
        marginRight = 55 .* Scaling;
        % Position colorbar
        colorbarPos = [figPos(3) - marginRight + 10 .* Scaling, ...
                       marginBottom, ...
                       colorbarWidth, ...
                       max(1, figPos(4) - marginTop - marginBottom)];
                       %max(1, min(90, figPos(4) - marginTop - marginBottom))];
        set(hColorbar, 'Units', 'pixels', 'Position', colorbarPos);
        % Add mask for exponent
        maskPos = [colorbarPos(1), colorbarPos(2) + colorbarPos(4) + 5 .* Scaling, ...
                   figPos(3)-colorbarPos(1), figPos(4)-colorbarPos(2)-colorbarPos(4)];
        if isempty(hLabelHideExp)
            uicontrol(hFig,'style','text','units','pixels', 'pos', maskPos, 'tag', 'labelMaskExp', ...
                      'BackgroundColor', get(hFig, 'Color'));
        else
            set(hLabelHideExp, 'pos', maskPos);
        end
    else
        delete(hLabelHideExp);
    end
    % Reposition the axes
    set(hAxes, 'Units',    'pixels', ...
               'Position', [marginLeft, ...
                            marginBottom, ...
                            figPos(3) - marginLeft - marginRight, ...
                            figPos(4) - marginTop - marginBottom]);
    
    % Update axes ticks
    switch lower(TfInfo.DisplayMode)
        case 'singlesensor'
            UpdateAxesTicks(hAxes);
        case {'2dlayout', '2dlayoutopt'}
            set(hAxes, 'XTick', [], 'YTick', []);
    end
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
    TfInfo   = getappdata(hFig, 'Timefreq');
    isStatic = getappdata(hFig, 'isStatic');
    % Get axes
    switch (objType)
        case 'figure'
            hAxes = get(hFig, 'CurrentAxes');
        case 'axes'
            hAxes = hObj;
        case 'surface'
            % Click on small image to open a figure: ignore
            if strcmpi(get(hObj, 'Tag'), 'TimefreqSurfSmall')
                return;
            end
            hAxes = ancestor(hObj, 'Axes');
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
            % Initialize time selection
            if ~isStatic && ~ismember(TfInfo.DisplayMode, {'2DLayout', '2DLayoutOpt', 'AllSensors'})
                [Time,iFreq] = GetMousePosition(hFig, hAxes, 0);
                if ~isempty(Time) && ~isempty(iFreq)
                    setappdata(hFig, 'GraphSelection', [Time, Inf; iFreq, Inf]);
                end
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
    % Check figure type (2DLayout: nothing to move)
    TfInfo = getappdata(hFig, 'Timefreq');

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
            YLim_prev = YLim;
            YLim = YLim - (YLim(2) - YLim(1)) * motionFigure(2);
            YLim = bst_saturate(YLim, YLimInit, 1);
            set(hAxes, 'YLim', YLim);
            
        case 'selection'
            if ismember(TfInfo.DisplayMode, {'2DLayout', '2DLayoutOpt', 'AllSensors'})
                return
            end
            % Get previous time selection
            GraphSelection = getappdata(hFig, 'GraphSelection');
            if isempty(GraphSelection)
                return
            end
            % Update time selection
            [Time,iFreq] = GetMousePosition(hFig, hAxes, 1);
            if ~isempty(Time) && ~isempty(iFreq)
                GraphSelection(1,2) = Time;
                GraphSelection(2,2) = iFreq;
                setappdata(hFig, 'GraphSelection', GraphSelection);
                % Redraw time selection
                PlotTimefreqSelection(hFig);
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
            % 2DLayout: cannot move anything
            TfInfo = getappdata(hFig, 'Timefreq');
            if ~ismember(TfInfo.DisplayMode, {'2DLayout', '2DLayoutOpt', 'AllSensors'}) && ~strcmpi(clickAction, 'colorbar')
                % Get new time and frequency
                [Time, iFreq] = GetMousePosition(hFig, hAxes, 0);
                % Update the current time and freq in the whole application      
                if ~isempty(Time)
                    panel_time('SetCurrentTime', Time);
                end
                if ~isempty(iFreq)
                    panel_freq('SetCurrentFreq', iFreq);
                end
                % Remove previous time selection patch
                setappdata(hFig, 'GraphSelection', []);
                PlotTimefreqSelection(hFig);
            end
        elseif strcmpi(MouseStatus, 'alt')
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
function [Time, iFreq] = GetMousePosition(hFig, hAxes, isAcceptOutside)
    % Parse inputs
    if (nargin < 3) || isempty(isAcceptOutside)
        isAcceptOutside = 1;
    end
    % Get current point in axes
    CurPoint = get(hAxes, 'CurrentPoint');
    XLim = get(hAxes, 'XLim');
    YLim = get(hAxes, 'YLim');
    YLim(2) = YLim(2) - 1;
    Time = CurPoint(1,1);
    iFreq = floor(CurPoint(1,2));
    
    % Check whether cursor is out of display time bounds
    if ~isAcceptOutside && ((Time < XLim(1)) || (Time > XLim(2)) || (iFreq < YLim(1)) || (iFreq > YLim(2)))
        Time = [];
        iFreq = [];
    else
        Time = bst_saturate(Time, XLim);
        iFreq = bst_saturate(iFreq, YLim);
        % Get the time vector.
        [TimeVector, FreqVector] = GetFigureData(hFig);
        % Select the closest point in time vector
        if ~isempty(TimeVector)
            if ~iscell(TimeVector)
                Time = TimeVector(bst_closest(Time,TimeVector));
            else
                error('This is not supposed to happen.');
            end
        end
    end
end

%% ===== PLOT TIME-FREQ SELECTION =====
function PlotTimefreqSelection(hFig)
    % Get axes (can have more than one)
    hAxesList = findobj(hFig, '-depth', 1, 'Tag', 'AxesTimefreq');
    % Get time-freq selection
    GraphSelection = getappdata(hFig, 'GraphSelection');
    % Process all the axes
    for i = 1:length(hAxesList)
        hAxes = hAxesList(i);
        % Draw new time selection patch
        if ~isempty(GraphSelection) && ~any(isinf(GraphSelection(:)))
            % Get the limits to show
            TimeSel = GraphSelection(1,:);
            FreqSel = sort(GraphSelection(2,:));
            FreqSel(2) = FreqSel(2) + 1;
            % Get previous patch
            hSelPatch = findobj(hAxes, '-depth', 1, 'Tag', 'SelectionPatch');
            % If patch do not exist yet: create it
            if isempty(hSelPatch)
                % Draw patch
                hSelPatch = patch('XData', [TimeSel(1), TimeSel(2), TimeSel(2), TimeSel(1)], ...
                                  'YData', [FreqSel(1), FreqSel(1), FreqSel(2), FreqSel(2)], ...
                                  'ZData', [3 3 3 3], ...
                                  'LineWidth', 1, ...
                                  'FaceColor', [1 1 1], ...
                                  'FaceAlpha', 0.3, ...
                                  'EdgeColor', [.8 .8 .8], ...
                                  'EdgeAlpha', 1, ...
                                  'Tag',       'SelectionPatch', ...
                                  'BackfaceLighting', 'lit', ...
                                  'Parent',    hAxes);
            % Else, patch already exist: update it
            else
                % Change patch limits
                set(hSelPatch, 'XData', [TimeSel(1), TimeSel(2), TimeSel(2), TimeSel(1)], ...
                               'YData', [FreqSel(1), FreqSel(1), FreqSel(2), FreqSel(2)]);
            end
            % Update labels
            UpdateLabels(hAxes, GraphSelection);
        else
            % Remove previous selection patch
            delete(findobj(hAxes, '-depth', 1, 'Tag', 'SelectionPatch'));
        end
    end
end


%% ===== SET TIME-FREQ SELECTION =====
% Define manually the time selection for a given figure
function SetTimefreqSelection(hFig, newSelection)
    if (nargin < 2)
        newSelection = [];
    end
    % Get time-frequency definition
    [TimeVector, FreqVector] = GetFigureData(hFig);
    % Ask for a time window
    if isempty(newSelection)
        timeSel = panel_time('InputTimeWindow', TimeVector([1,end]), 'Set time selection');
        if isempty(timeSel)
            return
        end
    end
    % Ask for a frequency window
    if isempty(newSelection)
        freqSel = panel_freq('InputSelectionWindow', FreqVector([1,end]), 'Set frequency selection', 'Hz');
        if isempty(freqSel)
            return
        end
    end
    % Select the closest point in time vector
    if isempty(newSelection)
        newSelection = [TimeVector(bst_closest(timeSel,TimeVector)); ...
                        FreqVector(bst_closest(freqSel,FreqVector))];
    else
        newSelection = [TimeVector(bst_closest(newSelection(1,:),TimeVector)); ...
                        FreqVector(bst_closest(newSelection(2,:),FreqVector))];
    end
    % Draw new time selection
    setappdata(hFig, 'GraphSelection', newSelection);
    PlotTimefreqSelection(hFig);
end


%% ===== FIGURE MOUSE WHEEL =====
function FigureMouseWheelCallback(hFig, event)
    % Check figure type (2DLayout: nothing to move)
    TfInfo = getappdata(hFig, 'Timefreq');
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
    
    % Get zoom direction:
    % 2D Layout: zoom both directions
    if ismember(TfInfo.DisplayMode, {'2DLayout', '2DLayoutOpt', 'AllSensors'})
        direction = 'both';
    % CTRL key + scroll: zoom vertically
    elseif ismember('control', get(hFig,'CurrentModifier'))
        direction = 'vertical';
    else
        direction = 'horizontal';
    end
    % Apply zoom
    gui_zoom(hFig, direction, Factor);
    % Try to center view on mouse
    if ~ismember(TfInfo.DisplayMode, {'2DLayout', '2DLayoutOpt', 'AllSensors'})
        CenterViewOnCursor(hFig);
    end
end


%% ===== CENTER VIEW ON MOUSE =====
function CenterViewOnCursor(hFig)
    % Get axes
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'AxesTimefreq');
    % Process each axes
    for i = 1:length(hAxes)
        % === CENTER HORIZONTALLY ===
        % Get current time frame
        hTimeLine = findobj(hAxes(i), '-depth', 1, 'Tag', 'TimeLine');
        if isempty(hTimeLine)
            continue;
        end
        Xcurrent = get(hTimeLine, 'XData');
        Xcurrent = Xcurrent(1);
        % Get initial XLim 
        XLimInit = getappdata(hFig, 'XLimInit');
        % Get current limits
        XLim = get(hAxes(i), 'XLim');
        % Center view on time frame
        Xlength = XLim(2) - XLim(1);
        XLim = [Xcurrent - Xlength/2, Xcurrent + Xlength/2];
        XLim = bst_saturate(XLim, XLimInit, 1);
        
        % === CENTER VERTICALLY ===
        % Get current frequency
        hFreqLine = findobj(hAxes(i), '-depth', 1, 'Tag', 'FreqLine');
        Ycurrent = get(hFreqLine, 'YData');
        Ycurrent = Ycurrent(1);
        % Get initial YLim 
        YLimInit = getappdata(hFig, 'YLimInit');
        % Get current limits
        YLim = get(hAxes(i), 'YLim');
        % Center view on time frame
        Ylength = YLim(2) - YLim(1);
        YLim = [Ycurrent - Ylength/2, Ycurrent + Ylength/2];
        YLim = bst_saturate(YLim, YLimInit, 1);
        
        % Update position
        set(hAxes(i), 'XLim', XLim, 'YLim', YLim);
    end
end


%% ===== KEYBOARD CALLBACK =====
function FigureKeyPressedCallback(hFig, keyEvent)
    global GlobalData;
    % Prevent multiple executions
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'AxesTimefreq')';
    set([hFig hAxes], 'BusyAction', 'cancel');
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);

    % Process event
    switch (keyEvent.Key)
        % === LEFT, RIGHT, PAGEUP, PAGEDOWN : Processed by TimeWindow ===
        case {'leftarrow', 'rightarrow', 'pageup', 'pagedown', 'home', 'end'}
            panel_time('TimeKeyCallback', keyEvent);
        case {'uparrow', 'downarrow'}
            % CTRL + UP/DOWN: Process with timefreq panel
            if ismember('control', keyEvent.Modifier)
                panel_freq('FreqKeyCallback', keyEvent);
            % UP/DOWN: Change data row
            else
                panel_display('SetSelectedRowName', hFig, keyEvent.Key);
            end
        % === DATABASE NAVIGATOR ===
        case {'f1', 'f2', 'f3', 'f4', 'f6'}
            bst_figures('NavigatorKeyPress', hFig, keyEvent)
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
        % EQUAL: Synchronize other figures
        case {'=', 'equal'}
            SynchronizeFigures(hFig);
        % ENTER: Show selected sensor
        case 'return'
            ShowTimeSeries(hFig);
        % ESCAPE: RESET SELECTION
        case 'escape'
            setappdata(hFig, 'GraphSelection', []);
            PlotTimefreqSelection(hFig);
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
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    if isempty(iFig)
        return;
    end
    FigId = GlobalData.DataSet(iDS).Figure(iFig).Id;
    % Get study
    TfInfo = getappdata(hFig,'Timefreq');
    [sStudy,iStudy,iFile,FileType,sTimefreq] = bst_get('AnyFile', TfInfo.FileName);
    % Get initial data type
    if strcmpi(FileType, 'timefreq')
        DataType = sStudy.Timefreq(iFile).DataType;
    elseif strcmpi(FileType, 'ptimefreq')
        DataType = 'stat';
    end
    % Get axes handles
    hAxes = getappdata(hFig, 'clickSource');
    if isempty(hAxes)
        return
    end
    % Create popup menu
    jPopup = java_create('javax.swing.JPopupMenu');
    
    % ==== DISPLAY OTHER FIGURES ====
    % === View POWER SPECTRUM ===
    gui_component('MenuItem', jPopup, [], 'Power spectrum', IconLoader.ICON_SPECTRUM, [], @(h,ev)bst_call(@view_spectrum, TfInfo.FileName, 'Spectrum', TfInfo.RowName));
    % === View TIME SERIES ===
    gui_component('MenuItem', jPopup, [], 'Time series',    IconLoader.ICON_DATA,     [], @(h,ev)bst_call(@view_spectrum, TfInfo.FileName, 'TimeSeries', TfInfo.RowName));
    % === View TOPOGRAPHY ===
    if strcmpi(DataType, 'data')
        jItem = gui_component('MenuItem', jPopup, [], 'Topography', IconLoader.ICON_TOPOGRAPHY, [], @(h,ev)bst_figures('ViewTopography', hFig));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_T, KeyEvent.CTRL_MASK));
    end
    % === View RECORDINGS ===
    if ~isempty(sTimefreq.DataFile) && strcmpi(DataType, 'data')
        jPopup.addSeparator();
        jItem = gui_component('MenuItem', jPopup, [], 'Recordings', IconLoader.ICON_TS_DISPLAY, [], @(h,ev)view_timeseries(sTimefreq.DataFile));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_R, KeyEvent.CTRL_MASK));
    end
    % === View RECORDINGS (one sensor) ===
    if ~isempty(sTimefreq.DataFile) && strcmpi(DataType, 'data') && ~ismember(FigId.SubType, {'2DLayout', '2DLayoutOpt', 'AllSensors'})
        jItem = gui_component('MenuItem', jPopup, [], 'Recordings (one sensor)', IconLoader.ICON_TS_DISPLAY, [], @(h,ev)ShowTimeSeries(hFig));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_ENTER, 0));
    end
    jPopup.addSeparator();
    
    % ==== SYNCHRONIZE OTHER FIGURES ====
    if ~isempty(TfInfo.RowName)
        jItem = gui_component('MenuItem', jPopup, [], 'Synchronize other figures', IconLoader.ICON_TS_SYNCRO, [], @(h,ev)SynchronizeFigures(hFig));
        jItem.setAccelerator(KeyStroke.getKeyStroke('=', 0));
        jPopup.addSeparator();
    end
    
    % ==== MENU: COLORMAP =====
    bst_colormaps('CreateAllMenus', jPopup, hFig, 0);

    % ==== MENU: NAVIGATION ====
    jMenuNavigator = gui_component('Menu', jPopup, [], 'Navigator', IconLoader.ICON_NEXT_SUBJECT);
    bst_navigator('CreateNavigatorMenu', jMenuNavigator);
    
    % ==== MENU: SELECTION ====
    % Do not show for "Display all sensors" figures
    jMenuSelection = gui_component('Menu', [], [], 'Time-Freq selection', IconLoader.ICON_TS_SELECTION);
    if ~ismember(FigId.SubType, {'2DLayout', '2DLayoutOpt', 'AllSensors'})
        % Set selection
        if ~iscell(GlobalData.UserFrequencies.Freqs)
            gui_component('MenuItem', jMenuSelection, [], 'Set selection manually...', IconLoader.ICON_TS_SELECTION, [], @(h,ev)SetTimefreqSelection(hFig));
        end
        % Get current time selection
        GraphSelection = getappdata(hFig, 'GraphSelection');
        isSelection = ~isempty(GraphSelection) && ~any(isinf(GraphSelection(:)));
        if isSelection
            if ~iscell(GlobalData.UserFrequencies.Freqs)
                jMenuSelection.addSeparator();
            end
            % === EXPORT TO DATABASE ===
            gui_component('MenuItem', jMenuSelection, [], 'Export to database (time-freq)', IconLoader.ICON_TIMEFREQ, [], @(h,ev)bst_call(@out_figure_timefreq, hFig, 'Database', 'Selection'));
            gui_component('MenuItem', jMenuSelection, [], 'Export to database (matrix)', IconLoader.ICON_MATRIX, [], @(h,ev)bst_call(@out_figure_timefreq, hFig, 'Database', 'Selection', 'Matrix'));
            % === EXPORT TO FILE ===
            gui_component('MenuItem', jMenuSelection, [], 'Export to file', IconLoader.ICON_TS_EXPORT, [], @(h,ev)bst_call(@out_figure_timefreq, hFig, [], 'Selection'));
            % === EXPORT TO MATLAB ===
            gui_component('MenuItem', jMenuSelection, [], 'Export to Matlab', IconLoader.ICON_MATLAB_EXPORT, [], @(h,ev)bst_call(@out_figure_timefreq, hFig, 'Variable', 'Selection'));
        end
        if (jMenuSelection.getItemCount() > 0)
            jPopup.add(jMenuSelection);
        end
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
        jMenuSave.addSeparator();
        % === EXPORT TO DATABASE ===
        gui_component('MenuItem', jMenuSave, [], 'Export to database (time-freq)', IconLoader.ICON_TIMEFREQ, [], @(h,ev)bst_call(@out_figure_timefreq, hFig, 'Database'));
        gui_component('MenuItem', jMenuSave, [], 'Export to database (matrix)', IconLoader.ICON_MATRIX, [], @(h,ev)bst_call(@out_figure_timefreq, hFig, 'Database', 'Matrix'));
        % === EXPORT TO FILE ===
        gui_component('MenuItem', jMenuSave, [], 'Export to file', IconLoader.ICON_TS_EXPORT, [], @(h,ev)bst_call(@out_figure_timefreq, hFig, []));
        % === EXPORT TO MATLAB ===
        gui_component('MenuItem', jMenuSave, [], 'Export to Matlab', IconLoader.ICON_MATLAB_EXPORT, [], @(h,ev)bst_call(@out_figure_timefreq, hFig, 'Variable'));
        % === EXPORT TO PLOTLY ===
        gui_component('MenuItem', jMenuSave, [], 'Export to Plotly', IconLoader.ICON_PLOTLY, [], @(h,ev)bst_call(@out_figure_plotly, hFig));
        
    % ==== MENU: FIGURE ====    
    jMenuFigure = gui_component('Menu', jPopup, [], 'Figure', IconLoader.ICON_LAYOUT_SHOWALL);
        % Change background color
        gui_component('MenuItem', jMenuFigure, [], 'Change background color', IconLoader.ICON_COLOR_SELECTION, [], @(h,ev)bst_figures('SetBackgroundColor', hFig));
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
        % Clone figure
        jMenuFigure.addSeparator();
        gui_component('MenuItem', jMenuFigure, [], 'Clone figure', IconLoader.ICON_COPY, [], @(h,ev)bst_figures('CloneFigure', hFig));
    % Display Popup menu
    gui_popup(jPopup, hFig);
end


%% ===========================================================================
%  ===== DISPLAY FUNCTIONS ===================================================
%  ===========================================================================
%% ===== GET FIGURE DATA =====
function [Time, Freqs, TfInfo, TF, RowNames, FullTimeVector, DataType, LowFreq, iTimefreq] = GetFigureData(hFig, TimeDef)
    global GlobalData;
    % Parse inputs
    if (nargin < 2) || isempty(TimeDef)
        TimeDef = 'UserTimeWindow';
    end
    % Initialize returned variables
    TF      = [];
    Time    = [];
    Freqs   = [];
    LowFreq = [];
    % ===== GET INFORMATION =====
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
    [Time, iTime] = bst_memory('GetTimeVector', iDS, [], TimeDef);
    Time = Time(iTime);
    FullTimeVector = Time;
    % If it is a static figure: keep only the first and last times
    if getappdata(hFig, 'isStatic')
        Time = Time([1,end]);
    end
    
    % ===== GET FREQUENCIES =====
    % If it is static: no frquencies
    if getappdata(hFig, 'isStaticFreq') && ~iscell(GlobalData.DataSet(iDS).Timefreq(iTimefreq).Freqs)
        Freqs = [];
    else
        % Get all the freqencies
        if isempty(TfInfo.iFreqs)
            Freqs = GlobalData.DataSet(iDS).Timefreq(iTimefreq).Freqs;
        % Get a set of frequencies (continuous)
        elseif ~iscell(GlobalData.DataSet(iDS).Timefreq(iTimefreq).Freqs)
            Freqs = GlobalData.DataSet(iDS).Timefreq(iTimefreq).Freqs(TfInfo.iFreqs);
            if (size(Freqs,1) ~= 1)
                Freqs = Freqs';
            end
        % Get a set of frequencies (freq bands)
        else
            Freqs = GlobalData.DataSet(iDS).Timefreq(iTimefreq).Freqs(TfInfo.iFreqs, :);
        end
    end
    
    % ===== GET DATA =====
    % Only if requested
    if (nargout >= 4)
        % Override figure definition and get all rows
        FigRowName    = TfInfo.RowName;
        FigRefRowName = TfInfo.RefRowName;
        % Get data
        [TF, iTimeBands, iRow] = bst_memory('GetTimefreqValues', iDS, iTimefreq, FigRowName, TfInfo.iFreqs, iTime, TfInfo.Function, FigRefRowName);
        % Get specific RowNames
        if ~isempty(FigRefRowName)
            RowNames = GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames;
        elseif ~isempty(FigRowName)
            RowNames = FigRowName;
        % Else: get all the rows (regular timefreq file)
        else
            RowNames = GetRowNames(GlobalData.DataSet(iDS).Timefreq(iTimefreq).RefRowNames, GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames);
        end
        % Get time bands
        if ~isempty(iTimeBands)
            Time = GlobalData.DataSet(iDS).Timefreq(iTimefreq).TimeBands(iTimeBands,:);
        end
        % Data type
        DataType = GlobalData.DataSet(iDS).Timefreq(iTimefreq).DataType;
        
        % Show stat clusters
        if strcmpi(file_gettype(TfInfo.FileName), 'ptimefreq')
            % Get displayed clusters
            sClusters = panel_stat('GetDisplayedClusters', hFig);
            % Replace values with clusters
            if ~isempty(sClusters)
                mask = 0 * TF;
                % Plot each cluster
                for i = 1:length(sClusters)
                    if isempty(TfInfo.iFreqs)
                        mask = mask | sClusters(i).mask(iRow, iTime, :);
                    else
                        mask = mask | sClusters(i).mask(iRow, iTime, TfInfo.iFreqs);
                    end
                end
                TF(~mask) = 0;
            end
        end
    end
    
    % === GET LOW FREQS ===
    % Useful for Canolty maps and other PAC-based displays
    if (nargout >= 8)
        if isfield(GlobalData.DataSet(iDS).Timefreq(iTimefreq).Options, 'LowFreq') && ~isempty(GlobalData.DataSet(iDS).Timefreq(iTimefreq).Options.LowFreq)
            LowFreq = GlobalData.DataSet(iDS).Timefreq(iTimefreq).Options.LowFreq(iRow);
        end
    end
end


%% ===== GET ROW NAMES =====
function AllRows = GetRowNames(RefRowNames, RowNames)
    % Regular time-frequency file
    if isempty(RefRowNames) || (length(RefRowNames) == 1) || ~iscell(RowNames)
        AllRows = RowNames;
    % Connectivity matrix: [RefRowNames x RowNames]
    else
        AllRows = cell(length(RowNames) * length(RefRowNames), 1);
        ind = 1;
        for iB = 1:length(RowNames)
            for iA = 1:length(RefRowNames)
                AllRows{ind} = [RefRowNames{iA} ' x ' RowNames{iB}];
                ind = ind + 1;
            end
        end
    end
end


%% ===== UPDATE FIGURE PLOT =====
function UpdateFigurePlot(hFig, isForced)
    global GlobalData;
    if (nargin < 2) || isempty(isForced)
        isForced = 0;
    end
    % ===== GET GLOBAL MAXIMUM =====
    % Get data
    [Time, Freqs, TfInfo, TF, RowNames, FullTimeVector, DataType, LowFreq] = GetFigureData(hFig);
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    TopoHandles = GlobalData.DataSet(iDS).Figure(iFig).Handles;
    % Find timefreq structure
    iTf = find(file_compare({GlobalData.DataSet(iDS).Timefreq.FileName}, TfInfo.FileName), 1);
    % If maximum is not defined yet
    if isempty(TopoHandles.DataMinMax) || isForced
        % Get the maximum
        TopoHandles.DataMinMax = bst_memory('GetTimefreqMaximum', iDS, iTf, TfInfo.Function);
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
    MinMaxVal = bst_colormaps('GetMinMax', sColormap, TF, TopoHandles.DataMinMax);
    % Apply absolute values
    if sColormap.isAbsoluteValues
        TF = abs(TF);
    end
    % If all the values are the same
    if ~isempty(MinMaxVal) && (MinMaxVal(1) == MinMaxVal(2))
        if sColormap.isAbsoluteValues
            MinMaxVal(2) = MinMaxVal(2) + eps;
        else
            MinMaxVal = [MinMaxVal(1) - eps, MinMaxVal(2) + eps];
        end
    end
    
    % ===== HIDE EDGE EFFECTS =====
    TFmask = [];
    % If edge effects should be hidden
    if TfInfo.HideEdgeEffects
        % If the edge effects map is available from the time-frequency file
        if ~isempty(GlobalData.DataSet(iDS).Timefreq(iTf).TFmask)
            TFmask = GlobalData.DataSet(iDS).Timefreq(iTf).TFmask;
        % Else: If the options of the wavelets were saved in the file (not for stat files)
        elseif ~isempty(GlobalData.DataSet(iDS).Timefreq(iTf).Options) && ~strcmpi(file_gettype(TfInfo.FileName), 'ptimefreq')
            TFmask = process_timefreq('GetEdgeEffectMask', Time, Freqs, GlobalData.DataSet(iDS).Timefreq(iTf).Options);
        end
    end
       
    % ===== PLOT DATA =====
    switch lower(TfInfo.DisplayMode)
        case 'singlesensor'
            % Find axes
            hAxes = findobj(hFig, '-depth', 1, 'tag', 'AxesTimefreq');
            % Plot time-frequency map
            if (TfInfo.HighResolution)
                PlotTimefreqSurfHigh(hAxes, Time, Freqs, TF, TFmask);
            elseif TfInfo.DisplayAsDots
                PlotTimefreqAsDots(hAxes, Time, TF);
            else
                PlotTimefreqSurf(hAxes, Time, FullTimeVector, Freqs, TF, TFmask);
            end
            % Configure axes
            ConfigureAxes(hAxes, Time, FullTimeVector, Freqs, TfInfo, MinMaxVal, LowFreq);
            % Plot current time/frequency markers
            PlotTimefreqCursor(hAxes);
            % Store initial XLim and YLim
            setappdata(hFig, 'XLimInit', get(hAxes, 'XLim'));
            setappdata(hFig, 'YLimInit', get(hAxes, 'YLim'));
        case '2dlayout'
            PlotAllSensors(hFig, RowNames, TF, TFmask, MinMaxVal, 1);
        case '2dlayoutopt'
            PlotAllSensors(hFig, RowNames, TF, TFmask, MinMaxVal, 2);
        case 'allsensors'
            PlotAllSensors(hFig, RowNames, TF, TFmask, MinMaxVal, 0);
    end
    % Update figure handles
    GlobalData.DataSet(iDS).Figure(iFig).Handles = TopoHandles;
    
    % ===== Colorbar ticks and labels =====
    % Update colorbar font size
    hColorbar = findobj(hFig, '-depth', 1, 'Tag', 'Colorbar');
    if ~isempty(hColorbar)
        set(hColorbar, 'FontSize', bst_get('FigFont'), 'FontUnits', 'points');
    end
    % Do not display colorbar for single color dots
    if TfInfo.DisplayAsDots
        sColormap.DisplayColorbar = 0;
    end
%     % Get figure colormap
%     ColormapInfo = getappdata(hFig, 'Colormap');
%     sColormap = bst_colormaps('GetColormap', ColormapInfo.Type);
    % Set figure colormap
    set(hFig, 'Colormap', sColormap.CMap);
    % Create/Delete colorbar
    bst_colormaps('SetColorbarVisible', hFig, sColormap.DisplayColorbar);
    % Display only one colorbar (preferentially the results colorbar)
    bst_colormaps('ConfigureColorbar', hFig, ColormapInfo.Type, 'timefreq', ColormapInfo.DisplayUnits);
end


%% ===== PLOT TIME-FREQ SURFACE =====
function hSurf = PlotTimefreqSurf(hAxes, Time, FullTimeVector, Freqs, TF, TFmask)
    % Delete previous objects
    surfTag = 'TimefreqSurf';
    hOld = findobj(hAxes, '-depth', 1, 'tag', surfTag);
    delete(hOld);
    % TF input: remove the first dimension (row) => Convert to [freq x time]
    TF = reshape(TF(1,:,:), [size(TF,2), size(TF,3)])';
    % Prepare time coordinates
    if ~iscell(Time)
        TimeStep = Time(2) - Time(1);
        if (length(Time) == size(TF,2) + 1)
            X = Time;
        else
            X = [Time - TimeStep/2, Time(end) + TimeStep/2];
        end
        TF_local = TF;
        if ~isempty(TFmask)
            TFmask_local = TFmask;
        end
    else
        % Get time segments
        BandBounds = process_tf_bands('GetBounds', Time);
        % Display only the first time bands: the other will be displayed by copies
        smpPeriod = FullTimeVector(2) - FullTimeVector(1);
        X = [BandBounds(1,1), BandBounds(1,2) + smpPeriod];
        TF_local = TF(:,1);
        if ~isempty(TFmask)
            TFmask_local = TFmask(:,1);
        end
    end
    % Prepare frequency coordinates
    if ~iscell(Freqs)
        Y = 1:length(Freqs)+1;
    else
        Y = 1:size(Freqs,1)+1;
    end

    % Grid values
    [XData,YData] = meshgrid(X,Y);
    % Plot new surface  
    hSurf = surface('XData',     XData, ...
                    'YData',     YData, ...
                    'ZData',     0.001*ones(size(XData)), ...
                    'CData',     TF_local, ...
                    'FaceColor', 'flat', ...
                    'EdgeColor', 'none', ...
                    'AmbientStrength',  .5, ...
                    'DiffuseStrength',  .5, ...
                    'SpecularStrength', .6, ...
                    'Tag',              surfTag, ...
                    'Parent',           hAxes);
     % Mask edge effects
     if ~isempty(TFmask)
         set(hSurf, 'FaceAlpha', 'flat', ...
                    'AlphaData', double(TFmask_local));
     end
                        
     % Copy of this surface for the other time bands
     if (iscell(Time) && (size(Time,1) > 1))
         for i = 2:size(Time,1)
             hSurfCopy = copyobj(hSurf, hAxes);
             XData = [BandBounds(i,1), BandBounds(i,2) + smpPeriod];
             set(hSurfCopy, 'XData', XData, 'CData', TF(:,i));
             % Mask edge effects
             if ~isempty(TFmask)
                 set(hSurf, 'FaceAlpha', 'flat', ...
                            'AlphaData', double(TFmask(:,i)));
             end
         end
     end
end

%% ===== PLOT TIME-FREQ AS DOTS =====
function hSurf = PlotTimefreqAsDots(hAxes, Time, TF)
    % Delete previous objects
    surfTag = 'TimefreqSurf';
    hOld = findobj(hAxes, '-depth', 1, 'tag', surfTag);
    delete(hOld);
    % Extract coordinates
    [X,Y,Z] = find(squeeze(TF));
    % Convert X coordinates from samples to time
    X = X / size(TF,2) * (Time(end) - Time(1)) + Time(1);
    % Plot as dots
    hSurf = line(X, Y, Z, ...
       'Color', 'black', ...
       'LineStyle', 'none', ...
       'Marker', '.', ...
       'MarkerSize', 5, ...
       'Tag', surfTag, ...
       'Parent', hAxes);
end


%% ===== PLOT TIME-FREQ SURFACE (HIGH-RESOLUTION) =====
function PlotTimefreqSurfHigh(hAxes, Time, Freqs, TF, TFmask)
    % Delete previous objects
    surfTag = 'TimefreqSurf';
    hOld = findobj(hAxes, '-depth', 1, 'tag', surfTag);
    delete(hOld);
    % TF input: remove the first dimension (row) => Convert to [freq x time]
    TF = reshape(TF(1,:,:), [size(TF,2), size(TF,3)])';
    % Prepare time coordinates
    if ~iscell(Time)
        TimeStep = Time(2) - Time(1);
        TimeBounds = [Time(1) - TimeStep/2, Time(end) + TimeStep/2];
    else
        % Get time segments
        BandBounds = process_tf_bands('GetBounds', Time);
        % Build time axis
        Time = mean(BandBounds,2)';
        TimeBounds = [BandBounds(1,1), BandBounds(end,2)];
    end
    % Prepare frequency coordinates
    if ~iscell(Freqs)
        Y = 1:length(Freqs)+1;
    else
        Y = 1:size(Freqs,1)+1;
    end

    % Interpolated surface size
    res = [300, 300];
    % Create index grids
    d = 0.5/length(Y);
    [X1,Y1] = meshgrid(Time, linspace(d, 1-d, length(Y)-1));
    [X2,Y2] = meshgrid(linspace(TimeBounds(1), TimeBounds(2), res(1)), linspace(0, 1, res(2)));
    % Re-interpolate for high-resolution display: one value per pixel
    TFhi = interp2(X1, Y1, TF, X2, Y2, 'linear');
    
    % If there are lots of strictly 0 values (thresholded stat): Enforce the zero values
    zeroMask = (TF == 0);
    if (nnz(zeroMask) > 0.10*numel(TF)) && (nnz(zeroMask) < numel(TF))
        zeroMaskHi = interp2(X1, Y1, double(zeroMask), X2, Y2, 'linear');
        TFhi(zeroMaskHi > 0.8) = 0;
    end
    
    % Support X/Y vectors in high resolution
    Xhi = linspace(TimeBounds(1), TimeBounds(2), res(1));
    Yhi = linspace(Y(1), Y(end), res(2));
    % Grid values
    [XData,YData] = meshgrid(Xhi,Yhi);
    % Plot new surface  
    hSurf = surface('XData',     XData, ...
                    'YData',     YData, ...
                    'ZData',     0.001*ones(size(XData)), ...
                    'CData',     TFhi, ...
                    'FaceColor', 'interp', ...
                    'EdgeColor', 'none', ...
                    'AmbientStrength',  .5, ...
                    'DiffuseStrength',  .5, ...
                    'SpecularStrength', .6, ...
                    'Tag',              surfTag, ...
                    'Parent',           hAxes);
     % Mask edge effects
     if ~isempty(TFmask)
         % Re-interpolate for high-resolution display: one value per pixel
         TFmaskhi = interp2(X1, Y1, double(TFmask), X2, Y2, 'linear');
         % Set transparency
         set(hSurf, 'FaceAlpha', 'interp', ...
                    'AlphaData', double(abs(TFmaskhi) > 0.9));
     end
end


%% ===== CONFIGURE AXES =====
function ConfigureAxes(hAxes, Time, FullTimeVector, Freqs, TfInfo, MinMaxVal, LowFreq)
    % Parse inputs
    if (nargin < 7) || isempty(LowFreq)
        LowFreq = [];
    end
    % XLim: Linear scale
    if ~iscell(Time)
        XLim = [Time(1), Time(end)];
    % XLim: Time bands
    else
        XLim = [FullTimeVector(1), FullTimeVector(end)];
    end
    % YLim: Linear scale
    if ~iscell(Freqs)
        YLim = [1, length(Freqs)+1];
    % YLim: Frequency bands
    else
        YLim = [1, size(Freqs,1)+1];
    end
    % Set properties
    set(hAxes, 'YGrid',      'off', ... 
               'XGrid',      'off', 'XMinorGrid', 'off', ...
               'XLim',       XLim, ...
               'YLim',       YLim, ...
               'Box',        'on', ...
               'FontName',   'Default', ...
               'FontUnits',  'Points', ...
               'FontWeight', 'Normal',...
               'FontSize',   bst_get('FigFont'), ...
               'Color',      [.9 .9 .9], ...
               'XColor',     [0 0 0], ...
               'YColor',     [0 0 0], ...
               'Visible',    'on');
    % Update axes ticks
    UpdateAxesTicks(hAxes);
    % Labels
    if ~isempty(strfind(lower(TfInfo.FileName), 'spike_field_coherence'))
        xlabel(hAxes, 'Frequency (Hz)');
        ylabel(hAxes, 'Electrodes');
    elseif ~isempty(strfind(lower(TfInfo.FileName), 'noise_correlation'))
        xlabel(hAxes, 'Neurons');
        ylabel(hAxes, 'Neurons');
    elseif ~isempty(strfind(lower(TfInfo.FileName), 'rasterplot'))
        xlabel(hAxes, 'Time (s)');
        ylabel(hAxes, 'Trials');
    else
        xlabel(hAxes, 'Time (s)');
        ylabel(hAxes, 'Frequency (Hz)');
    end
    % Axes title
    if ischar(TfInfo.RowName)
        axesTitle = [TfInfo.Comment, ': ', TfInfo.RowName];
    else
        axesTitle = [TfInfo.Comment, ': Source #', num2str(TfInfo.RowName)];
    end
    % If there is a low-freq to display (Canolty maps)
    if ~isempty(LowFreq) && (length(LowFreq) == 1)
        axesTitle = [axesTitle, sprintf('    (low freq = %1.2f Hz)', LowFreq)];
    end
    % Set title
    hTitle = title(hAxes, axesTitle, 'Interpreter', 'none');
    % On MacOS: Force the title to be displayed in normal font weigth, if not the last character disappears
    if strncmp(computer,'MAC',3) && (bst_get('MatlabVersion') >= 804)
        set(hTitle, 'FontWeight', 'normal');
    end
    % Colormap limits
    set(hAxes, 'CLim', MinMaxVal);
end


%% ===== UPDATE AXES TICKS =====
function UpdateAxesTicks(hAxes)
    global GlobalData;
    % Get frequencies
    Freqs = GlobalData.UserFrequencies.Freqs;
    % Linear scale
    if ~iscell(Freqs)
        set(hAxes, 'YTickMode', 'auto');
        iFreq = get(hAxes, 'YTick');
        if ~isempty(iFreq)
            for i = 1:length(iFreq)
                if (iFreq(i) == round(iFreq(i))) && (iFreq(i) > 0) && (iFreq(i) <= length(Freqs))
                    strFreqs{i} = num2str(round(Freqs(iFreq(i)) .* 100) ./ 100);
                else
                    strFreqs{i} = '';
                end
            end
            set(hAxes, 'YTickMode',  'manual', ...
                       'YTick',      iFreq, ...
                       'Yticklabel', strFreqs);
        end
    % Frequency bands
    else
        set(hAxes, 'YTickMode',  'manual', ...
                   'YTick',      (1:size(Freqs,1)) + .5, ...
                   'Yticklabel', Freqs(:,1));
    end
end


%% ===== PLOT TIME/FREQ CURSOR =====
function PlotTimefreqCursor(hAxes)
    global GlobalData;
    % Get current time and freq
    CurrentTime = GlobalData.UserTimeWindow.CurrentTime;
    iCurrentFreq = GlobalData.UserFrequencies.iCurrentFreq;
    % Get existing time and cursor
    hTimeLine = findobj(hAxes, '-depth', 1, 'tag', 'TimeLine');
    hFreqLine = findobj(hAxes, '-depth', 1, 'tag', 'FreqLine');
    
    % ===== TIME CURESOR =====
    % If it already exists, just move it
    if ~isempty(hTimeLine)
        set(hTimeLine, 'XData', [CurrentTime, CurrentTime, CurrentTime, CurrentTime]);
    % Else: Create time cursor
    else
        % Plot vertical line at t=CurrentTime
        YData = get(hAxes, 'YLim');
        hTimeLine = patch('XData', [CurrentTime, CurrentTime, CurrentTime, CurrentTime], ...
                          'YData', [YData(1), YData(1), YData(2), YData(2)], ...
                          'ZData', [3 3 3 3], ...
                          'Tag',   'TimeLine', ...
                          'BackfaceLighting', 'lit', ...
                          'Parent', hAxes);
    end
    
    % ===== FREQ CURSOR =====
    % If it already exists, just move it
    if ~isempty(hFreqLine)
        set(hFreqLine, 'YData', [iCurrentFreq, iCurrentFreq, iCurrentFreq, iCurrentFreq] + .5);
    % Else: Create time cursor
    else
        % Plot vertical line at t=CurrentTime
        XData = get(hAxes, 'XLim');
        hFreqLine = patch('XData',  [XData(1), XData(1), XData(2), XData(2)], ...
                          'YData',  [iCurrentFreq, iCurrentFreq, iCurrentFreq, iCurrentFreq] + .5, ...
                          'ZData',  [3 3 3 3], ...
                          'Tag',    'FreqLine', ...
                          'BackfaceLighting', 'lit', ...
                          'Parent', hAxes);
    end
    
    % Configure both lines
    set([hTimeLine, hFreqLine], ...
        'LineWidth', 1, ...
        'EdgeColor', [1 0 0], ...
        'EdgeAlpha', .4);
    % Update labels
    UpdateLabels(hAxes, [CurrentTime; iCurrentFreq]);                           
end


%% ===== UPDATE LABELS =====
function UpdateLabels(hAxes, GraphSelection)
    global GlobalData;
    hFig = get(hAxes, 'parent');
    TfInfo = getappdata(hFig, 'Timefreq');
    
    % Electrophysiology figures have different labels
    if ~isempty(strfind(lower(TfInfo.FileName), 'spike_field_coherence'))
        if numel(GraphSelection) > 0
            strFreq = sprintf('Frequency: %d Hz',  round(GraphSelection(1)));
        else
            strFreq = 'Frequency (Hz)';
        end
        if numel(GraphSelection) == 2
            [tmp, tmp, iDS] = bst_figures('GetFigure', hFig);
            channel = GlobalData.DataSet(iDS).Channel(GraphSelection(2)).Name;
            strElec = ['Electrodes: ' channel];
        else
            strElec = 'Electrodes';
        end
        xlabel(hAxes, strFreq);
        ylabel(hAxes, strElec);
    elseif ~isempty(strfind(lower(TfInfo.FileName), 'noise_correlation'))
        if numel(GraphSelection) > 0
            strNeur1 = ['Neuron: ' TfInfo.NeuronNames{GraphSelection(1)}];
        else
            strNeur1 = 'Neurons';
        end
        if numel(GraphSelection) > 1
            strNeur2 = ['Neuron: ' TfInfo.NeuronNames{GraphSelection(2)}];
        else
            strNeur2 = 'Neurons';
        end
        xlabel(hAxes, strNeur1);
        ylabel(hAxes, strNeur2);
    elseif ~isempty(strfind(lower(TfInfo.FileName), 'rasterplot'))
        if numel(GraphSelection) > 0
            % Get current time units
            timeUnit = panel_time('GetTimeUnit');
            switch (timeUnit)
                case 'ms',  strTime = sprintf('Time: %.2f ms', GraphSelection(1) * 1000);
                case 's',   strTime = sprintf('Time: %.3f s',  GraphSelection(1));
            end
        else
            strTime = 'Time (s)';
        end
        if numel(GraphSelection) > 1
            strTrial = ['Trial: #' num2str(GraphSelection(2))];
        else
            strTrial= 'Trials';
        end
        xlabel(hAxes, strTime);
        ylabel(hAxes, strTrial);
    else
        % Get current time units
        timeUnit = panel_time('GetTimeUnit');
        % No time definition at all
        if isempty(GraphSelection) || (numel(GraphSelection) < 2)
            strTime = 'Time (s)';
            strFreq = 'Frequency (Hz)';
        % Current time/freq
        elseif (numel(GraphSelection) == 2)
            switch (timeUnit)
                case 'ms',  strTime = sprintf('Time: %.2f ms', GraphSelection(1) * 1000);
                case 's',   strTime = sprintf('Time: %.3f s',  GraphSelection(1));
            end
            % Get current frequency value/description
            if ~iscell(GlobalData.UserFrequencies.Freqs)
                strFreq = ['Frequency: ' num2str(GlobalData.UserFrequencies.Freqs(GraphSelection(2))), ' Hz'];
            else
                strFreq = ['Frequency: ' GlobalData.UserFrequencies.Freqs{GraphSelection(2),1}];
            end
        % Time-frequency selection
        else
            switch (timeUnit)
                case 'ms',  strTime = sprintf('Selection: [%.2f ms - %.2f ms]', min(GraphSelection(1,:)) * 1000, max(GraphSelection(1,:)) * 1000);
                case 's',   strTime = sprintf('Selection: [%.2f s - %.2f s]', min(GraphSelection(1,:)), max(GraphSelection(1,:)));
            end
            % Get current frequency value/description
            if ~iscell(GlobalData.UserFrequencies.Freqs)
                selFreq = sort(GlobalData.UserFrequencies.Freqs(GraphSelection(2,:)));
                strFreq = ['Selection: [' num2str(selFreq(1)) ' Hz - ' num2str(max(selFreq(2))) ' Hz]'];
            else
                selBands = sort(GraphSelection(2,:));
                strFreq = ['Frequency: ' GlobalData.UserFrequencies.Freqs{selBands(1),1} ' - ' GlobalData.UserFrequencies.Freqs{selBands(2),1}];
            end
        end
        xlabel(hAxes, strTime);
        ylabel(hAxes, strFreq);
    end
end


%% ===== PLOT ALL SENSORS =====
function PlotAllSensors(hFig, RowNames, TF, TFmask, MinMaxVal, is2DLayout)
    % Find axes
    hAxes = findobj(hFig, '-depth', 1, 'tag', 'AxesTimefreq');
    cla(hAxes);
    hold(hAxes, 'on');
    TfInfo = getappdata(hFig, 'Timefreq');
    fontSize = bst_get('FigFont');
    % Get positions of the centers of the time-frequency plots
    [X, Y, axesSize] = GetLayoutPositions(hFig, RowNames, is2DLayout);
    % Get maximum axes dimensions in pixels
    ScreenDef = bst_get('ScreenDef');
    maxPlotDim = round(axesSize .* ScreenDef(1).matlabPos(1,3:4));
    % Ratios for downsampling image
    nTime = size(TF,2);
    nFreq = size(TF,3);
    xRatio = max(1, round(nTime / maxPlotDim(1)));
    yRatio = max(1, round(nFreq / maxPlotDim(2)));
    % Downsample mask
    TFmask = TFmask(1:yRatio:end, 1:xRatio:end);
    % Loop to create the plots
    for iRow = 1:length(RowNames)
        % Get TF map for this sensor (downsampled version)
        iTime = 1:xRatio:size(TF,2);
        iFreq = 1:yRatio:size(TF,3);
        TF_sensor = reshape(TF(iRow, iTime, iFreq), length(iTime), length(iFreq))';
        % Define position of the image in the figure
        XData = X(iRow) + [-.5,.5] * axesSize(1);
        YData = Y(iRow) + [-.5,.5] * axesSize(2);
        %
        if TfInfo.DisplayAsDots
            % Extract coordinates
            [Xd,Yd,Zd] = find(TF_sensor);
            % Reshape coordinates for small figure
            Xd = Xd / size(TF_sensor,1) * (XData(2) - XData(1)) + XData(1);
            Yd = Yd / size(TF_sensor,2) * (YData(2) - YData(1)) + YData(1);
            % Create white background
            rectangle('Position', [XData(1), YData(1), XData(2) - XData(1), YData(2) - YData(1)], ...
                'FaceColor', 'white', ...
                'EdgeColor', 'white', ...
                'Parent',    hAxes, ...
                'ButtonDownFcn', @(h,ev)ImageClicked_Callback(hFig, TfInfo.FileName, RowNames{iRow}));
            % Create dots
            line(Xd, Yd, Zd, ...
                 'Color', 'black', ...
                 'LineStyle', 'none', ...
                 'Marker', '.', ...
                 'MarkerSize', 3, ...
                 'Parent',    hAxes, ...
                 'Tag', 'TimefreqSurfSmall', ...
                 'ButtonDownFcn', @(h,ev)ImageClicked_Callback(hFig, TfInfo.FileName, RowNames{iRow}));
        else
            [Xgrid, Ygrid] = meshgrid(linspace(XData(1), XData(2), size(TF_sensor,2) + 1), ...
                                      linspace(YData(1), YData(2), size(TF_sensor,1) + 1));
            % Create surface to show images
            hSurf = surf('Parent',    hAxes, ...
                         'XData',     Xgrid, ...
                         'YData',     Ygrid, ...
                         'ZData',     ones(size(Xgrid)), ...
                         'CData',     TF_sensor, ...
                         'EdgeColor', 'none', ...
                         'tag',       'TimefreqSurfSmall', ...
                         'ButtonDownFcn', @(h,ev)ImageClicked_Callback(hFig, TfInfo.FileName, RowNames{iRow}));
            % Mask edge effects
            if ~isempty(TFmask)
                set(hSurf, 'FaceAlpha', 'flat', ...
                           'AlphaData', double(TFmask));
            end
        end
        % Add text legend
        text(X(iRow), Y(iRow)-.51*axesSize(2), 2, RowNames{iRow}, ...
             'FontSize',            fontSize, ...
             'FontUnits',           'points', ...
             'Interpreter',         'none', ...
             'HorizontalAlignment', 'center', ...
             'VerticalAlignment',   'top', ...
             'Parent',              hAxes, ...
             'ButtonDownFcn', @(h,ev)ImageClicked_Callback(hFig, TfInfo.FileName, RowNames{iRow}));
    end
%     % For recordings, display orientation indications: left, right, front, back
%     if is2DLayout
%         text(-.02, .5, 'Left',  'Rotation', 90,  'Color', [0,.6,0], 'FontSize', fontSize, 'FontUnits', 'points', 'HorizontalAlignment', 'center', 'Parent',  hAxes);
%         text(1.01, .5, 'Right', 'Rotation', -90, 'Color', [0,.6,0], 'FontSize', fontSize, 'FontUnits', 'points', 'HorizontalAlignment', 'center', 'Parent',  hAxes);
%         text(.5, -.04, 'Back',  'Color', [0,.6,0], 'FontSize', fontSize, 'FontUnits', 'points', 'HorizontalAlignment', 'center', 'Parent',  hAxes);
%         text(.5, 1.02, 'Front', 'Color', [0,.6,0], 'FontSize', fontSize, 'FontUnits', 'points', 'HorizontalAlignment', 'center', 'Parent',  hAxes);
%     end
    % Configure axes
    set(hAxes, 'XLim', [0,1], ...
               'YLim', [0,1], ...
               'CLim', MinMaxVal);
    % Store initial XLim and YLim
    setappdata(hFig, 'XLimInit', [0,1]);
    setappdata(hFig, 'YLimInit', [0,1]);
end


%% ===== IMAGE CLICKED CALLBACK =====
% Clicked on a TF image in a "TF (All sensors)" figure
function ImageClicked_Callback(hFig, FileName, RowName)
    % SHIFT+CLICK: Display time series of the sensor
    if ismember('shift', get(hFig,'CurrentModifier'))
        ShowTimeSeries(hFig, RowName);
    % CLICK: Display TF decomposition of the sensor
    else
        % Get current function
        TfInfo = getappdata(hFig, 'Timefreq');
        if ismember(TfInfo.Function, {'power','magnitude','log'})
            Function = TfInfo.Function;
        else
            Function = [];
        end
        % View separate sensor
        hFigNew = view_timefreq(FileName, 'SingleSensor', RowName, [], Function);
        % Set smooth display
        if TfInfo.HighResolution
            panel_display('SetSmoothDisplay', TfInfo.HighResolution, hFigNew);
        end
    end
end


%% ===== SHOW TIME SERIES =====
function ShowTimeSeries(hFig, RowName)
    global GlobalData;
    % Get data type
    TfInfo = getappdata(hFig,'Timefreq');
    [sStudy,iStudy,iTf] = bst_get('TimefreqFile', TfInfo.FileName);
    DataType = sStudy.Timefreq(iTf).DataType;
    
    % Get RowName if not provided
    if (nargin < 2) || isempty(RowName)
        RowName = TfInfo.RowName;
    end
    % Only for RECORDINGS
    if strcmpi(DataType, 'data')
        % Get figure description
        [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
        if isempty(iDS)
            return
        end
        % Get selected sensors
        iChannel = find(strcmpi({GlobalData.DataSet(iDS).Channel.Name}, RowName));
        if isempty(iChannel)
            return
        end
        Modality = GlobalData.DataSet(iDS).Channel(iChannel).Type;
        % Display selected sensor
        figure_timeseries('DisplayDataSelectedChannels', iDS, RowName, Modality);
    end
end


%% ===== GET LAYOUT POSITIONS =====
function [X,Y,axesSize] = GetLayoutPositions(hFig, RowNames, is2DLayout)
    global GlobalData;
    if is2DLayout
        % Get figure description
        [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
        % Define list of selected channels
        selChan = [];
        for i = 1:length(GlobalData.DataSet(iDS).Channel)
            if ismember(GlobalData.DataSet(iDS).Channel(i).Name, RowNames)
                selChan(end+1) = i;
            else
                break;
            end
        end
        if (length(selChan) == length(GlobalData.DataSet(iDS).Channel))
            GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels = selChan;
        end
        
        % Get selected channels
        selChan = zeros(1, length(RowNames));
        for i = 1:length(RowNames)
            iChan = channel_find(GlobalData.DataSet(iDS).Channel, RowNames{i});
            if isempty(iChan)
                error(['Channel "' RowNames{i} '" was not found in the current channel file.']);
            elseif (length(iChan) > 1)
                error(['The current channel file contains more than one channel "' RowNames{i} '". Please fix this error.']);
            else
                selChan(i) = iChan;
            end
        end
        % Get markers positions (to represent graphically the sensors)
        [tmp, markers_loc] = figure_3d('GetChannelPositions', iDS, selChan);
        
        % 2D Projection
        if all(markers_loc(:,3) < 0.0001)
            Y = markers_loc(:,1);
            X = markers_loc(:,2);
        else
            [Y,X] = bst_project_2d(markers_loc(:,1), markers_loc(:,2), markers_loc(:,3), '2dlayout');
        end
        X = -X;
        % Normalize positions
        if (length(RowNames) > 1)
            % Default size for each TF plot
            if (length(RowNames) < 60)
                axesSize = [.05,.05] .* sqrt(120 ./ length(RowNames));
            else
                axesSize = [.05,.05];
            end
            % Position of each TF Plot
            X = (X - min(X)) ./ (max(X) - min(X)) * (1 - axesSize(1)) + axesSize(1)/2;
            Y = (Y - min(Y)) ./ (max(Y) - min(Y)) * (1 - axesSize(2)) + axesSize(2)/2;
            % Optimize to avoid overlapping
            if (is2DLayout > 1)
                [X, Y, axesSize] = OptimizeLayout(X, Y);
            end
        else
            axesSize = [.95,.95];
            X = .5;
            Y = .5;
        end
    else
        % Create squared display
        nPlots = length(RowNames);
        nCols = ceil(sqrt(nPlots));
        nRows = ceil(nPlots / nCols);
        % Create coordinates
        X = repmat((0.5 + (0:nCols-1))  ./ nCols, [nRows,1])';
        Y = repmat((0.5 + (nRows-1:-1:0))' ./ nRows, [1,nCols])';
        X = X(1:nPlots);
        Y = Y(1:nPlots);
        % Axes size
        axesSize = [.91 / nCols, .92 / nRows];
    end
end

%% ===== OPTIMIZE LAYOUT FOR 2DLAYOUT =====
function [X, Y, axesSize] = OptimizeLayout(X, Y)
    Mdim = 50;
    M = zeros(Mdim, Mdim);
    % Indices for matrix M
    [allY, allX] = meshgrid(1:Mdim, 1:Mdim);
    % Initialize axes size
    axesSize = [1 1] ./ (.7 * sqrt(length(X)));
    % Normalized display
    X = X ./ axesSize(1) + round(Mdim/2);
    Y = Y ./ axesSize(2) + round(Mdim/2);
    % Compute the center
    c = [mean(X), mean(Y)];
    % Compute the distance to teh center of each point
    dist = sqrt((X - c(1)).^2 + (Y - c(2)).^2);
    [dist, iSort] = sort(dist);
    % Loop on the points to place on the grid
    for iDist = 1:length(dist)
        % Get index in the list of points
        i = iSort(iDist);
        % Local M matrix
        Mlocal = M;
        % Distance to the center must be >= to the current point
        %if (dist(iDist) > 0.3)
            % Constrain by distance
            Mlocal(sqrt((allX - c(1)).^2 + (allY - c(2)).^2) <= dist(iDist) - 1) = 1;
            % Contrain by angle
            ux = (allX - c(1));
            uy = (allY - c(2));
            vx = (X(i) - c(1));
            vy = (Y(i) - c(2));
            ang = acos( (ux.*vx + uy.*vy) ./ sqrt(ux.^2+uy.^2) ./ sqrt(vx.^2+vy.^2));
            Mlocal(ang > pi/24) = 1;
        %end
        % Get the available slots in M
        [Mx,My] = find(~Mlocal);
        % Compute distance between current point and available slot in M
        distM = sqrt((Mx - X(i)).^2 - (My - Y(i)).^2);
        % Find minimum distance
        [tmp, iMinM] = min(distM);
        % Set this slot as taken
        M(Mx(iMinM), My(iMinM)) = i;
    end
    % Initialize mask of lonely blocks to ignore
    lonelyOk = zeros(size(M));
    % Find holes in M, fill them
    for i = 1:100
        % Detect holes
        holes1 = conv2(double(M > 0), [1 -1 1], 'same');
        holes2 = conv2(double(M > 0), [1; -1; 1], 'same');
        holes = ((holes1 == 2) | (holes2 == 2));
        % Pick the first hole in the list
        [ih,jh] = find(holes, 1);
        % Fix hole
        if ~isempty(ih)
            % Distance to the edges of the figure: [-x,+x,-y,+y]
            indMi = find(M(:,jh));
            if ~isempty(indMi)
                distEdge(1:2) = [ih - min(indMi), -ih + max(indMi)];
            else
                distEdge(1:2) = [100, 100];
            end
            indMj = find(M(ih,:));
            if ~isempty(indMj)
                distEdge(3:4) = [jh - min(indMj), -jh + max(indMj)];
            else
                distEdge(3:4) = [100, 100];
            end
            % Ignore the directions for which the hole connects to the background
            distEdge(distEdge < 0) = 100;
            % Find the direction of the displacement
            [tmp, iOrient] = min(distEdge);
            % Fill the gap by moving the column/line
            switch (iOrient(1))
                case 1,   M(2:ih,jh) = M(1:ih-1,jh);
                case 2,   M(ih:end-1,jh) = M(ih+1:end,jh);
                case 3,   M(ih,2:jh) = M(ih,1:jh-1);
                case 4,   M(ih,jh:end-1) = M(ih,jh+1:end);
            end
        % Isolated blocks
        else
            % Find isolated blocks (equal or less than two neighbors)
            lonely = conv2(double(M > 0), [1 1 1; 1 20 1; 1 1 1], 'same') + lonelyOk;
            [in,jn] = find((lonely == 20), 1);
            if isempty(in)
                [in,jn] = find((lonely == 21), 1);
                if isempty(in)
                    [in,jn] = find((lonely == 22), 1);
                    if isempty(in)
                        break;
                    end
                end
            end
            % Get the possible slots nearby
            Mlone = (M(in-1:in+1, jn-1:jn+1) == 0) & (lonely(in-1:in+1, jn-1:jn+1) > lonely(in,jn)-20);
            [in2, jn2] = find(Mlone);
            if isempty(in2)
                lonelyOk(in,jn) = -100;
                break;
            end
            in2 = in + in2 - 2;
            jn2 = jn + jn2 - 2;
            % If there is more than one option, get the ones that produces the most compact image
            if (length(in2) > 1)
                dens = [];
                % For each option, look for the one that would produce the higher number of elements per line and column
                for k = 1:length(in2)
                    dens(k) = sum(M(in2(k),:)>0) + sum(M(:,jn2(k))>0);
                    % Strong penalty for the positions that have a single element on the line
                    if (sum(M(in2(k),:)>0) <= 2) || (sum(M(:,jn2(k))>0) <= 2)
                        dens(k) = dens(k) - 5;
                    end
                end
                [tmp,iMaxDens] = max(dens);
                in2 = in2(iMaxDens(1));
                jn2 = jn2(iMaxDens(1));
            end
            % Move the current point to its new slot
            M(in2,jn2) = M(in,jn);
            M(in,jn) = 0;
        end
        % figure; imagesc(M > 0);
        % holes = double(holes);
        % holes(ih,jh) = 10;
        % figure; imagesc(holes);
    end
    % Rebuild X and Y matrices
    for i = 1:Mdim
        for j = 1:Mdim
            if (M(i,j) > 0)
                X(M(i,j)) = i;
                Y(M(i,j)) = j;
            end
        end
    end
    % Normalize axes size
    nX = max(X) - min(X) + 1;
    nY = max(Y) - min(Y) + 1;
    axesSize = [.98 / nX, 1 / nY];
    % Restore initial coordinates
    X = (X - min(X) + 0.5) .* axesSize(1);
    Y = (Y - min(Y) + 0.5) .* axesSize(2);
    % Add a margin to separate the blocks from each other
    axesSize = axesSize - [0.002, 0.007];
end


%% ===== SYNCHRONIZE FIGURES =====
function SynchronizeFigures(hFig)
    global GlobalData;
    % Get figure configuration
    TfInfo = getappdata(hFig, 'Timefreq');
    if isempty(TfInfo) || isempty(TfInfo.RowName)
        return
    end
    % Find other similar figures that could be updated
    hFigOthers = bst_figures('GetFiguresByType', 'Timefreq');
    hFigOthers = setdiff(hFigOthers, hFig);
    for i = 1:length(hFigOthers)
        % Get figure configuration
        TfInfoOther = getappdata(hFigOthers(i), 'Timefreq');
        % Check that the figure has a different selecte RowName
        if isempty(TfInfoOther) || isempty(TfInfoOther.RowName) || isequal(TfInfoOther.RowName, TfInfo.RowName)
            continue;
        end
        % Get loaded timefreq file
        [iDS, iTimefreq] = bst_memory('GetDataSetTimefreq', TfInfoOther.FileName);
        if isempty(iDS)
            continue;
        end
        % If the new destination RowName also exists in this file: Update figure
        if ismember(TfInfo.RowName, GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames)
            % Update figure description
            TfInfoOther.RowName = TfInfo.RowName;
            setappdata(hFigOthers(i), 'Timefreq', TfInfoOther);
            % Redraw this figure
            figure_timefreq('UpdateFigurePlot', hFigOthers(i), 1);
        end
    end
end



