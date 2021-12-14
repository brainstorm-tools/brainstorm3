function varargout = figure_timeseries( varargin )
% FIGURE_TIMESERIES: Creation and callbacks for time series figures.
%
% USAGE:  hFig = figure_timeseries('CreateFigure', FigureId)
%                figure_timeseries('CurrentTimeChangedCallback',  iDS, iFig)
%                figure_timeseries('UniformizeTimeSeriesScales',  isUniform)
%                figure_timeseries('FigureMouseDownCallback',     hFig, event)
%                figure_timeseries('FigureMouseMoveCallback',     hFig, event)  
%                figure_timeseries('FigureMouseUpCallback',       hFig, event)
%                figure_timeseries('FigureMouseWheelCallback',    hFig, event)
%                figure_timeseries('FigureKeyPressedCallback',    hFig, keyEvent)
%                figure_timeseries('LineClickedCallback',         hLine, ev)
%                figure_timeseries('DisplayDataSelectedChannels', iDS, SelecteRows, Modality)
%                figure_timeseries('ToggleAxesProperty',          hAxes, propName)
%                figure_timeseries('ResetView',                   hFig)
%                figure_timeseries('ResetViewLinked',             hFig)
%                figure_timeseries('DisplayFigurePopup',          hFig, menuTitle=[], curTime=[])

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
% Authors: Francois Tadel, 2008-2021
%          Martin Cousineau, 2017
%          Marc Lalancette, 2020

eval(macro_method);
end


%% ===== CREATE FIGURE =====
function hFig = CreateFigure(FigureId)
    import org.brainstorm.icon.*;
    MatlabVersion = bst_get('MatlabVersion');
    % Get renderer name
    if (MatlabVersion <= 803)   % zbuffer was removed in Matlab 2014b
        rendererName = 'zbuffer';
    elseif (bst_get('DisableOpenGL') == 1)
        rendererName = 'painters';
    else
        rendererName = 'opengl';
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
                  'KeyPressFcn',              @(h,ev)bst_call(@FigureKeyPressedCallback, h, ev), ...
                  'WindowButtonDownFcn',      @FigureMouseDownCallback, ...
                  'WindowButtonUpFcn',        @FigureMouseUpCallback, ...
                  bst_get('ResizeFunction'),  @ResizeCallback);
    % Define some mouse callbacks separately (not supported by old versions of Matlab)
    if isprop(hFig, 'WindowScrollWheelFcn')
        set(hFig, 'WindowScrollWheelFcn',  @FigureMouseWheelCallback);
    end
    if isprop(hFig, 'WindowKeyPressFcn') && isprop(hFig, 'WindowKeyReleaseFcn')
        set(hFig, 'WindowKeyPressFcn',    @WindowKeyPressedCallback, ...
                  'WindowKeyReleaseFcn',  @WindowKeyReleaseCallback);
    end
    % Disable automatic legends (after 2017a)
    if (MatlabVersion >= 902) 
        set(hFig, 'defaultLegendAutoUpdate', 'off');
    end
    % Prepare figure appdata
    setappdata(hFig, 'FigureId', FigureId);
    setappdata(hFig, 'hasMoved', 0);
    setappdata(hFig, 'isPlotEditToolbar', 0);
    setappdata(hFig, 'isSensorsOnly', 0);
    setappdata(hFig, 'GraphSelection', []);
    setappdata(hFig, 'isStatic', 0);
    setappdata(hFig, 'isStaticFreq', 1);
    setappdata(hFig, 'Colormap', db_template('ColormapInfo'));
    setappdata(hFig, 'MovingTimeBar', 0);
    setappdata(hFig, 'MovingTimeBarAction', []);
end


%% ===========================================================================
%  ===== FIGURE CALLBACKS ====================================================
%  ===========================================================================
%% ===== CURRENT TIME CHANGED =====
% Usage: CurrentTimeChangedCallback(iDS, iFig)
%
% Operations: - Move time cursor (vertical line at current time)
%             - Move text cursor (text field representing the current time frame)
function CurrentTimeChangedCallback(iDS, iFig)
    global GlobalData;
    % Get current display structure
    DisplayHandles = GlobalData.DataSet(iDS).Figure(iFig).Handles;
    % Get current time frame
    CurrentTime = GlobalData.UserTimeWindow.CurrentTime;
    % Time cursor
    if ~isempty([DisplayHandles.hCursor]) && all(ishandle([DisplayHandles.hCursor]))
        % Move time cursor to current time frame
        set([DisplayHandles.hCursor], 'Xdata', [CurrentTime CurrentTime]);
    end
    % Text time cursor
    if ~isempty(DisplayHandles(1).hTextCursor) && ishandle(DisplayHandles(1).hTextCursor)
        % Format current time
        [timeUnit, isRaw, precision] = panel_time('GetTimeUnit');
        textCursor = panel_time('FormatValue', CurrentTime, timeUnit, precision);
        textCursor = [textCursor ' ' timeUnit];
        % Move text cursor to current time frame
        set(DisplayHandles(1).hTextCursor, 'String', textCursor);
    end
end


%% ===== SELECTED ROW CHANGED =====
function SelectedRowChangedCallback(iDS, iFig)
    global GlobalData;
    % Ignore figures with multiple axes
    if (length(GlobalData.DataSet(iDS).Figure(iFig).Handles) ~= 1)
        return;
    end
    % Get figure appdata
    hFig = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
    % Get current selection for the figure
    curSelRows = GetFigSelectedRows(hFig);
    % Get current figure rows
    allFigRows  = GlobalData.DataSet(iDS).Figure(iFig).Handles.LinesLabels;
    prevSelRows = GlobalData.DataViewer.SelectedRows;
    % Remove spaces
    if iscell(curSelRows) && (length(curSelRows) >= 1) && ischar(curSelRows{1})
        curSelRows = cellfun(@(c)strrep(c,' ',''), curSelRows, 'UniformOutput', 0);
    end
    if iscell(allFigRows) && (length(allFigRows) >= 1) && ischar(allFigRows{1})
        allFigRows = cellfun(@(c)strrep(c,' ',''), allFigRows, 'UniformOutput', 0);
    end
    if iscell(prevSelRows) && (length(prevSelRows) >= 1) && ischar(prevSelRows{1})
        prevSelRows = cellfun(@(c)strrep(c,' ',''), prevSelRows, 'UniformOutput', 0);
    end
    % Get new selection that the figure should show (keep only the ones available for this figure)
    newSelRows = intersect(prevSelRows, allFigRows);
    % Sensors to select
    rowsToSel = setdiff(newSelRows, curSelRows);
    if ~isempty(rowsToSel)
        SetFigSelectedRows(hFig, rowsToSel, 1);
    end
    % Sensors to unselect
    rowsToUnsel = setdiff(curSelRows, newSelRows);
    if ~isempty(rowsToUnsel)
        SetFigSelectedRows(hFig, rowsToUnsel, 0);
    end
end


%% ===== UNIFORMIZE SCALES =====
% Uniformize or not all the TimeSeries scales
%
% Usage:  UniformizeTimeSeriesScales(isUniform)
%         UniformizeTimeSeriesScales()
function UniformizeTimeSeriesScales(isUniform)
    global GlobalData;
    % Parse inputs
    if (nargin < 1)
        isUniform = bst_get('UniformizeTimeSeriesScales');
    end
    % === UNIFORMIZE ===
    if (isUniform)
        % FigureList : {EEG[iDS,iFig], MEG[iDS,iFig], OTHER[iDS,iFig], SOURCES_AM[iDS,iFig], Val>0.01[iDS,iFig]}
        FigureList       = repmat({[]}, 1, 11);
        % CurDataMinMax : {EEG[min,max], MEG[min,max], OTHER[min,max], SOURCES_AM[min,max], Val>0.01[min,max]}
        FigureDataMinMax = repmat({[0,0]}, 1, 11);
        % Process all the TimeSeries figures, and set the YLim to the maximum one
        for iDS = 1:length(GlobalData.DataSet)
            % Process all figures
            for iFig = 1:length(GlobalData.DataSet(iDS).Figure)
                Handles = GlobalData.DataSet(iDS).Figure(iFig).Handles;
                TsInfo = getappdata(GlobalData.DataSet(iDS).Figure(iFig).hFigure, 'TsInfo');
                % If time series displayed in column for this figure: ignore it
                if ~ismember(GlobalData.DataSet(iDS).Figure(iFig).Id.Type, {'DataTimeSeries', 'ResultsTimeSeries'}) || strcmpi(TsInfo.DisplayMode, 'column')
                    continue
                end
                % Process each graph separately
                for iAxes = 1:length(Handles)
                    % Get figure data minimum and maximum
                    CurDataMinMax = Handles(iAxes).DataMinMax;
                    % Process only if DataMinMax is a valid field
                    if isempty(CurDataMinMax) || (CurDataMinMax(1) >= CurDataMinMax(2))
                        continue;
                    end
                    % Uniformization depends on the DataType displayed in the figure
                    switch (GlobalData.DataSet(iDS).Figure(iFig).Id.Type)
                        % Recordings time series : uniformize modality by modality
                        case 'DataTimeSeries'
                            % LARGE VALUES
                            switch(GlobalData.DataSet(iDS).Figure(iFig).Id.Modality)
                                case {'EEG', '$EEG'}
                                    if (CurDataMinMax(2) > 0.01)
                                        iType = 1;
                                    else
                                        iType = 2;
                                    end
                                case {'ECOG', 'SEEG', '$ECOG', '$SEEG', 'ECOG+SEEG', '$ECOG+SEEG'}
                                    if (CurDataMinMax(2) > 0.01)
                                        iType = 3;
                                    else
                                        iType = 4;
                                    end
                                case {'MEG', 'MEG GRAD', 'MEG MAG', '$MEG', '$MEG GRAD', '$MEG MAG'}
                                    if (CurDataMinMax(2) > 0.01)
                                        iType = 5;
                                    else
                                        iType = 6;
                                    end
                                case 'Cluster'
                                    iType = 7;
                                case 'NIRS'
                                    iType = 8;
                                otherwise
                                    iType = 9;
                            end
                        % Recordings time series : uniformize all the windows together
                        case 'ResultsTimeSeries'
                            fmax = max(abs(CurDataMinMax));
                            % Results in Amper.meter (display in picoAmper.meter)
                            if (fmax > 0) && (fmax < 1e-4)
                                iType = 10;
                            % Stat on Results
                            elseif (fmax > 0)
                                iType = 11;
                            end
                    end
                    FigureList{iType} = [FigureList{iType}; iDS, iFig];
                    FigureDataMinMax{iType} = [min(FigureDataMinMax{iType}(1), CurDataMinMax(1)), ...
                                               max(FigureDataMinMax{iType}(2), CurDataMinMax(2))];
                end
            end
        end

        % Unformize TimeSeries figures
        for iMod = 1:length(FigureList)
            for i = 1:size(FigureList{iMod}, 1)
                if (FigureDataMinMax{iMod}(1) >= FigureDataMinMax{iMod}(2))
                    continue;
                end
                % Get figure and axes handles
                sFigure = GlobalData.DataSet(FigureList{iMod}(i,1)).Figure(FigureList{iMod}(i,2));
                hFig  = sFigure.hFigure;
                % Process each graph separately
                for iPlot = 1:length(sFigure.Handles)
                    hAxes = sFigure.Handles(iPlot).hAxes;
                    % Get maximal value
                    fmax = max(abs(FigureDataMinMax{iMod})) * sFigure.Handles(iPlot).DisplayFactor;
                    % If displaying positive and negative values
                    if (FigureDataMinMax{iMod}(1) < -eps) || ((FigureDataMinMax{iMod}(1) < 0) && (FigureDataMinMax{iMod}(2) <= eps))
                        ylim = 1.05 .* [-fmax, fmax];
                    % Else: displaying absolute values (only positive values)
                    else
                        ylim = 1.05 .* [0, fmax];
                    end    
                    % Update figure Y-axis limits
                    set(hAxes, 'YLim', ylim);
                    setappdata(hAxes, 'YLimInit', ylim);
                    % Update TimeCursor position
                    hCursor = findobj(hAxes, '-depth', 1, 'Tag', 'Cursor');
                    set(hCursor, 'YData', ylim);
                end
            end
        end
       
    % === UN-UNIFORMIZE ===
    else
        % Process all the TimeSeries figures, and set the YLim to the maximum one
        for iDS = 1:length(GlobalData.DataSet)
            for iFig = 1:length(GlobalData.DataSet(iDS).Figure)
                % Get figure handles
                Handles = GlobalData.DataSet(iDS).Figure(iFig).Handles;
                TsInfo = getappdata(GlobalData.DataSet(iDS).Figure(iFig).hFigure, 'TsInfo');
                % Skip the unmananged types of figures
                if ~ismember(GlobalData.DataSet(iDS).Figure(iFig).Id.Type, {'DataTimeSeries', 'ResultsTimeSeries'}) || strcmpi(TsInfo.DisplayMode, 'column')
                    continue;
                end
                % Loop on figure axes
                for iAxes = 1:length(Handles)
                    % Process only if DataMinMax is a valid field
                    CurDataMinMax = Handles(iAxes).DataMinMax;
                    if isempty(CurDataMinMax) || (CurDataMinMax(1) >= CurDataMinMax(2))
                        continue;
                    end
                    % Get figure and axes handles
                    hFig = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
                    hAxes = Handles(iAxes).hAxes;
                    % Get maximal value
                    fmax = max(abs(CurDataMinMax)) * Handles(iAxes).DisplayFactor;
                    % If displaying absolute values (only positive values)
                    if (CurDataMinMax(1) >= 0)
                        ylim = 1.05 .* [0, fmax];
                    % Else : displaying positive and negative values
                    else
                        ylim = 1.05 .* [-fmax, fmax];
                    end    
                    % Update figure Y-axis limits
                    set(hAxes, 'YLim', ylim);
                    setappdata(hAxes, 'YLimInit', ylim);
                    % Update TimeCursor position
                    hCursor = findobj(hAxes, '-depth', 1, 'Tag', 'Cursor');
                    set(hCursor, 'YData', ylim);
                end
            end
        end
    end
end



%% ===========================================================================
%  ===== KEYBOARD AND MOUSE CALLBACKS ========================================
%  ===========================================================================
%% ===== FIGURE MOUSE DOWN =====
function FigureMouseDownCallback(hFig, ev)
    global GlobalData;
    % Get selected object in this figure
    hObj = get(hFig,'CurrentObject');
    if isempty(hObj)
        return;
    end
    % Get object tag
    objTag = get(hObj, 'Tag');
    % Re-select main axes
    drawnow;
    hAxes = findobj(hFig, '-depth', 1, 'tag', 'AxesGraph');
    % If more than one axes object: select one using "gca"
    if (length(hAxes) > 1)
        if any(hAxes == gca)
            hAxes = gca;
        else
            hAxes = hAxes(1);
        end
    elseif isempty(hAxes)
        return;
    end
    % Set axes as current object
    set(hFig,'CurrentObject', hAxes(1), 'CurrentAxes', hAxes(1));
    % Get figure properties
    MouseStatus = get(hFig, 'SelectionType');
    isStatic = getappdata(hFig, 'isStatic');
    % If shift button pressed: ignore click on lines
    if strcmpi(MouseStatus, 'extend') && strcmpi(objTag, 'DataLine')
        % Replace with a click on the axes
        objTag = 'AxesGraph';
        hObj = get(hObj, 'Parent');
    end
    noMoveAction = [];
    % If simple click in a continuous event marker, the user could be trying to do a double click on it
    % But after this click, the cursor will be under the mouse, making it impossible to click the event
    % => Keep track of this object
    if strcmp(MouseStatus, 'normal') && ismember(objTag, {'EventPatches', 'EventPatchesChannel'})
        setappdata(hFig, 'clickPrevObj', objTag);
    else
        if strcmpi(MouseStatus, 'open') && ~isempty(getappdata(hFig, 'clickPrevObj'))
            panel_record('EventEditNotes');
            setappdata(hFig, 'clickPrevObj', []);
            return;
        else
            setappdata(hFig, 'clickPrevObj', []);
        end
    end

    % Switch between available graphic objects
    switch (objTag)
        case {'DataTimeSeries', 'ResultsTimeSeries'}
            % Figure: Keep the main axes as clicked object
            hAxes = hAxes(1);
        case 'AxesGraph'
            % Axes: selectec axes = the one that was clicked
            hAxes = hObj;
        case 'DataLine'
            % Time series lines: select
            if ((~strcmpi(MouseStatus, 'alt') || 1) || (get(hObj, 'LineWidth') > 1))
                noMoveAction = @()LineClickedCallback(hObj);
            end
        case 'AxesRawTimeBar'   % Raw time bar: change time window
            timePos = get(hObj, 'CurrentPoint');
            timePos = timePos(1,1) - (GlobalData.UserTimeWindow.Time(2)-GlobalData.UserTimeWindow.Time(1)) / 2;
            panel_record('SetStartTime', timePos);
            return;
        case 'UserTime'   % Raw time marker patch: start moving or resizing
            % Get time
            hAxes = get(hObj, 'Parent');
            timePos = get(hAxes, 'CurrentPoint');
            rawTime = GlobalData.FullTimeWindow.Epochs(GlobalData.FullTimeWindow.CurrentEpoch).Time([1, end]);
            % If click is close to beginning of current page
            if (abs(timePos(1) - GlobalData.UserTimeWindow.Time(1)) / (rawTime(2)-rawTime(1))) < 0.002
                set(hFig, 'Pointer', 'left');
                setappdata(hFig, 'MovingTimeBarAction', 'start');
            elseif (abs(timePos(1) - GlobalData.UserTimeWindow.Time(2)) / (rawTime(2)-rawTime(1))) < 0.002
                set(hFig, 'Pointer', 'right');
                setappdata(hFig, 'MovingTimeBarAction', 'stop');
            else
                set(hFig, 'Pointer', 'fleur');
                setappdata(hFig, 'MovingTimeBarAction', 'move');
            end
            setappdata(hFig, 'MovingTimeBar', hObj);
        case 'TimeSelectionPatch'
            % Shift+click: zoom into selection (otherwise, regular click)
            if strcmpi(MouseStatus, 'extend')
                ZoomSelection(hFig);
            else
                hAxes = get(hObj, 'Parent');
            end
        case {'TimeZeroLine', 'Cursor', 'TextCursor', 'GFP', 'GFPTitle'}
            hAxes = get(hObj, 'Parent');
        case 'legend'
            legendButtonDownFcn = get(hObj, 'ButtonDownFcn');
            if ~isempty(legendButtonDownFcn)
                if iscell(legendButtonDownFcn)
                    legendButtonDownFcn{1}(hObj, ev, legendButtonDownFcn{2});
                else
                    % After Matlab 2014b.... 
                end
            end
            return
        case {'EventBarDots', 'EventDots', 'EventDotsExt', 'EventLabels', 'EventNotes', 'EventLines', 'EventPatches', 'EventDotsExtChannel', 'EventDotsChannel', 'EventLinesChannel', 'EventPatchesChannel'}
            % Force updating the figure selection before the mouse release, because if no the events are not the ones we need
            bst_figures('SetCurrentFigure', hFig, '2D');
            % Get events
            events = panel_record('GetEvents');
            % Get event type
            iEvt = get(hObj, 'UserData');
            % Get raw bar (time or events)
            hRawBar = get(hObj, 'Parent');
            % Get mouse time
            timePos = get(hRawBar, 'CurrentPoint');
            % Get the closest event
            evtTimes = events(iEvt).times;
            if (size(evtTimes, 1) == 1)
                iOccur = bst_closest(timePos(1), evtTimes);
            else
                iOccur = bst_closest(timePos(1), evtTimes(:));
                iOccur = ceil(iOccur / 2);
            end
            % Select event in panel "Raw"
            panel_record('SetSelectedEvent', iEvt, iOccur);
            % Move to this specific time (only for simple events)
            if strcmpi(MouseStatus, 'open')
                panel_record('EventEditNotes');
                return;
            elseif ~ismember(objTag, {'EventPatches', 'EventPatchesChannel', 'EventDotsExt', 'EventDotsExtChannel'})
                panel_record('JumpToEvent', iEvt, iOccur);
                % If right-click, keep going to display popup
                if ~strcmp(MouseStatus, 'alt')
                    return;
                end
            else
                % Let the time be changed by the clicking (or force it when right-click)
                if strcmp(MouseStatus, 'alt')
                    MoveTimeToMouse(hFig, hAxes);
                end
            end
        otherwise
            % Any other object: consider as a click on the main axes
    end

    % ===== PROCESS CLICKS ON MAIN TS AXES =====
    % If Shift+Move: Do not consider it is an EXTEND event
    if ismember('shift', get(hFig,'CurrentModifier')) && strcmpi(MouseStatus, 'extend')
        MouseStatus = 'normal';
    end 
    % Start an action (Move time cursor, pan)
    switch(MouseStatus)
        % Left click
        case 'normal'
            clickAction = 'selection'; 
            % Initialize time selection
            if ~isStatic
                X = GetMouseTime(hFig, hAxes);
                GraphSelection = [X, Inf];
            else
                GraphSelection = [];
            end
            SetTimeSelectionLinked(hFig, GraphSelection);
            % set(hFig, 'Pointer', 'ibeam');
        % CTRL+Mouse, or Mouse right
        case 'alt'
            clickAction = 'gzoom';
            set(hFig, 'Pointer', 'top');
        % SHIFT+Mouse
        case 'extend'
            clickAction = 'pan';
            set(hFig, 'Pointer', 'fleur');
        % DOUBLE CLICK
        case 'open'
            ResetViewLinked(hFig);
            return;
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
    % Record the action to perform if mouse was not moved
    setappdata(hFig, 'noMoveAction', noMoveAction);
    % Register MouseMoved callbacks for current figure
    set(hFig, 'WindowButtonMotionFcn', @FigureMouseMoveCallback);
end


%% ===== FIGURE MOUSE MOVE =====
function FigureMouseMoveCallback(hFig, event)  
    global GlobalData;
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
            FigurePan(hFig, motionFigure);
            
        case 'selection'
            % Get time selection
            MovingTimeBar = getappdata(hFig, 'MovingTimeBar');
            GraphSelection = getappdata(hFig, 'GraphSelection');
            % Time selection
            if isequal(MovingTimeBar, 0) && ~isempty(GraphSelection)
                % Update time selection
                GraphSelection(2) = GetMouseTime(hFig, hAxes);
                SetTimeSelectionLinked(hFig, GraphSelection);
            % Move time bar
            elseif ~isequal(MovingTimeBar, 0)
                % Get time bar patch
                xBar = get(MovingTimeBar, 'XData');
                % Get current mouse time position
                xMouse = get(hAxes, 'CurrentPoint');
                xMouse = xMouse(1);
                % Get axes limits
                XLim = GlobalData.FullTimeWindow.Epochs(GlobalData.FullTimeWindow.CurrentEpoch).Time([1, end]);
                minLen = 50 .* GlobalData.UserTimeWindow.SamplingRate;
                % Modification  depends on the action to perform
                switch getappdata(hFig, 'MovingTimeBarAction')
                    case 'move'
                        startBar = xMouse - (GraphSelection(1) - GlobalData.UserTimeWindow.Time(1));
                        xBar = startBar + [0, 1, 1, 0] * (xBar(2)-xBar(1));
                        % Block in the XLim bounds
                        if (min(xBar) < XLim(1))
                            xBar = xBar - min(xBar) + XLim(1);
                        elseif (max(xBar) > XLim(2))
                            xBar = xBar - max(xBar) + XLim(2);
                        end
                    case 'start'
                        xBar([1,4]) = max(XLim(1), xMouse);
                        xBar([1,4]) = min(xBar(2)-minLen, xBar([1,4]));
                    case 'stop'
                        xBar([2,3]) = min(XLim(2), xMouse);
                        xBar([2,3]) = max(xBar(1)+minLen, xBar([2,3]));
                end
                % Update bar
                set(MovingTimeBar, 'XData', xBar);
            end
            
        case 'gzoom'
            % Gain zoom
            ScrollCount = -motionFigure(2) * 10;
            FigureScroll(hFig, ScrollCount, 'gzoom');
    end
end
            

%% ===== FIGURE MOUSE UP =====        
function FigureMouseUpCallback(hFig, event)
    % Get mouse state
    clickAction = getappdata(hFig, 'clickAction');
    hasMoved    = getappdata(hFig, 'hasMoved');
    MouseStatus = get(hFig, 'SelectionType');
    MovingTimeBar = getappdata(hFig, 'MovingTimeBar');
    MovingTimeBarAction = getappdata(hFig, 'MovingTimeBarAction');
    noMoveAction = getappdata(hFig, 'noMoveAction');
    % Reset figure mouse fields
    setappdata(hFig, 'clickAction', '');
    setappdata(hFig, 'hasMoved', 0);
    setappdata(hFig, 'MovingTimeBar', 0);
    setappdata(hFig, 'MovingTimeBarAction', []);
    % Restore mouse pointer
    set(hFig, 'Pointer', 'arrow');
    drawnow;
    % Get axes handles
    hAxes = getappdata(hFig, 'clickSource');
    if isempty(hAxes) || ~ishandle(hAxes)
        return
    end
    
    % If mouse has not moved and there is a specific action to perform
    if ~hasMoved && ~isempty(noMoveAction)
        noMoveAction();
    % If mouse has not moved: popup or time change
    elseif ~hasMoved && ~isempty(MouseStatus)
        % Change time
        switch (MouseStatus)
            % LEFT CLICK  /  SHIFT+Mouse
            case {'normal', 'extend'}
                MoveTimeToMouse(hFig, hAxes);
            % CTRL+Mouse, or Mouse right
            case 'alt'
                X = GetMouseTime(hFig, hAxes);
                DisplayFigurePopup(hFig, [], X);
        end
    % If time bar was moved: update time
    elseif hasMoved && ~isequal(MovingTimeBar, 0)
        % Get time bar patch
        xBar = get(MovingTimeBar, 'XData');
        % Update current page
        switch (MovingTimeBarAction)
            case 'move'
                panel_record('SetStartTime', xBar(1));
            case {'start', 'stop'}
                panel_record('SetStartTime', xBar(1), [], 0);
                panel_record('SetTimeLength', xBar(2)-xBar(1), 1);
        end
    % If amplitude scaling was changed
    elseif hasMoved && strcmpi(clickAction, 'gzoom')
        hEventObj = [...
            findobj(hAxes, '-depth', 1, 'Tag', 'EventDotsChannel'); ...
            findobj(hAxes, '-depth', 1, 'Tag', 'EventDotsExtChannel'); ...
            findobj(hAxes, '-depth', 1, 'Tag', 'EventLinesChannel'); ...
            findobj(hAxes, '-depth', 1, 'Tag', 'EventPatchesChannel')];
        if ~isempty(hEventObj)
            bst_figures('ReloadFigures', hFig);
        end
    % If time selection was defined: check if its length is non-zero
    elseif hasMoved
        GraphSelection = getappdata(hFig, 'GraphSelection');
        if (length(GraphSelection) == 2) && (GraphSelection(1) == GraphSelection(2))
            SetTimeSelectionLinked(hFig, []);
        end
    end
    
    % Reset MouseMove callbacks for current figure
    set(hFig, 'WindowButtonMotionFcn', []); 
    % Remove mouse callbacks appdata
    setappdata(hFig, 'clickSource', []);
    setappdata(hFig, 'clickAction', []);
    setappdata(hFig, 'noMoveAction', []);
    % Update figure selection
    bst_figures('SetCurrentFigure', hFig, '2D');
end


%% ===== GET MOUSE TIME =====
function X = GetMouseTime(hFig, hAxes)
    % Get current point in axes
    X = get(hAxes, 'CurrentPoint');
    XLim = get(hAxes, 'XLim');
    % Check whether cursor is out of display time bounds
    X = bst_saturate(X(1,1), XLim);
    % Get the time vector
    TimeVector = getappdata(hFig, 'TimeVector');
    % Select the closest point in time vector
    if ~isempty(TimeVector)
        X = TimeVector(bst_closest(X,TimeVector));
    end
end

%% ===== SET TIME SELECTION: LINKED =====
% Apply the same time selection to similar figures
function SetTimeSelectionLinked(hFig, GraphSelection)
    % Get all the time-series figures
    hAllFigs = bst_figures('GetFiguresByType', {'DataTimeSeries', 'ResultsTimeSeries'});
    % Place the input figure in first
    hAllFigs(hAllFigs == hFig) = [];
    hAllFigs = [hFig, hAllFigs];
    % Loop over all the figures found
    for i = 1:length(hAllFigs)
        % Set figure configuration
        setappdata(hAllFigs(i), 'GraphSelection', GraphSelection);
        % Redraw time selection
        DrawTimeSelection(hAllFigs(i));
    end
end


%% ===== MOVE TIME TO WHERE THE MOUSE IS =====
function MoveTimeToMouse(hFig, hAxes)
    % Get new time
    X = GetMouseTime(hFig, hAxes);
    % Move time cursor to new time
    hCursor = findobj(hAxes, '-depth', 1, 'Tag', 'Cursor');
    set(hCursor, 'XData', [X,X]);
    drawnow;
    % Update the current time in the whole application      
    panel_time('SetCurrentTime', X);
    % Remove previous time selection patch
    SetTimeSelectionLinked(hFig, []);
end


%% ===== SET TIME SELECTION: MANUAL INPUT =====
% Define manually the time selection for a given TimeSeries figure
% USAGE:  SetTimeSelectionManual(hFig, newSelection)
%         SetTimeSelectionManual(hFig)
function SetTimeSelectionManual(hFig, newSelection)
    global GlobalData;
    % If raw viewer: allow redimensioning of current page
    if ~isempty(GlobalData.FullTimeWindow) && ~isempty(GlobalData.FullTimeWindow.Epochs) && ~isempty(GlobalData.FullTimeWindow.CurrentEpoch)
        rawTimeWindow = GlobalData.FullTimeWindow.Epochs(GlobalData.FullTimeWindow.CurrentEpoch).Time([1, end]);
    else
        rawTimeWindow = [];
    end
    % Get the time vector for this figure
    TimeVector = getappdata(hFig, 'TimeVector');
    % Ask for a time window
    if (nargin < 2) || isempty(newSelection)
        [newSelection, isUpdatedTime] = panel_time('InputTimeWindow', TimeVector([1,end]), 'Set time selection', [], [], rawTimeWindow);
        if isempty(newSelection)
            return
        end
        % Get the updated time vector
        if isUpdatedTime
            TimeVector = getappdata(hFig, 'TimeVector');
        end
    end
    % Select the closest point in time vector
    newSelection = TimeVector(bst_closest(newSelection,TimeVector));
    % Draw new time selection
    SetTimeSelectionLinked(hFig, newSelection);
end


%% ===== DRAW TIME SELECTION =====
function DrawTimeSelection(hFig)
    global GlobalData;
    % Get axes (can have more than one)
    hAxesList = findobj(hFig, '-depth', 1, 'Tag', 'AxesGraph');
    % Get time selection
    GraphSelection = getappdata(hFig, 'GraphSelection');

    % Get the data to compute the maximum: Only if there is one axes only 
    if (length(hAxesList) == 1) && ~isempty(GraphSelection)
        % Get figure description
        [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
        Handles = GlobalData.DataSet(iDS).Figure(iFig).Handles(1);
        TsInfo = getappdata(hFig, 'TsInfo');
        % Get selected channels (if available)
        [SelRows, iLines] = intersect(Handles.LinesLabels, GetFigSelectedRows(hFig));
        % If no channels selected: use all the available
        if isempty(iLines)
            iLines = 1:length(Handles.hLines);
        end
        % Get all the values
        YData = get(Handles.hLines(iLines), 'YData');
        if iscell(YData)
            YData = cat(1, YData{:});
        end
        % Get the selected time points
        XData = get(Handles.hLines(iLines(1)), 'XData');
        iTime = find((XData >= min(GraphSelection)) & (XData <= max(GraphSelection)));
        YData = YData(:,iTime);
        % Replace NaN with zeros
        YData(isnan(YData)) = 0;
        % Apply figure units
        switch (TsInfo.DisplayMode)
            case 'butterfly'
                YUnits = Handles.DisplayUnits;
            case 'column'
                % Scale to the original values
                YData = bst_bsxfun(@minus, YData, Handles.ChannelOffsets(iLines(:)));
                YData = YData ./ Handles.DisplayFactor;
                % Get units
                Fmax = max(abs(Handles.DataMinMax));
                [tmp, Yfactor, YUnits] = bst_getunits( Fmax, GlobalData.DataSet(iDS).Figure(iFig).Id.Modality, TsInfo.FileName );
                % Apply the display units
                YData = YData .* Yfactor;
        end
        % Reformat the units
        YUnits = strrep(YUnits, '\mu', 'u');
        YUnits = strrep(YUnits, '10^{', 'e');
        YUnits = strrep(YUnits, '}', '');
        % Get the min/max of the selected data
        [minY, iMin] = min(YData(:));
        [maxY, iMax] = max(YData(:));
        % Convert the indices back to 
        [iMinLine, iMinTime] = ind2sub(size(YData), iMin);
        [iMaxLine, iMaxTime] = ind2sub(size(YData), iMax);
        % Assemble string with min/max
        strMinMax = sprintf('      Min: [%1.2f %s, %s]      Max: [%1.2f %s, %s]', minY, YUnits, Handles.LinesLabels{iLines(iMinLine)}, maxY, YUnits, Handles.LinesLabels{iLines(iMaxLine)});
    else
        strMinMax = [];
    end
    
    % Process all the axes
    for i = 1:length(hAxesList)
        hAxes = hAxesList(i);
        % Draw new time selection patch
        if ~isempty(GraphSelection) && ~isinf(GraphSelection(2))
            % Get axes limits 
            YLim = get(hAxes, 'YLim');
            % Get previous patch
            hTimePatch = findobj(hAxes, '-depth', 1, 'Tag', 'TimeSelectionPatch');
            % Position of the square patch
            XData = [GraphSelection(1), GraphSelection(2), GraphSelection(2), GraphSelection(1)];
            YData = [YLim(1), YLim(1), YLim(2), YLim(2)];
            ZData = [0.01 0.01 0.01 0.01];
            % If patch do not exist yet: create it
            if isempty(hTimePatch)
                % EraseMode: Only for Matlab <= 2014a
                if (bst_get('MatlabVersion') <= 803)
                    optErase = {'EraseMode', 'xor'};   % INCOMPATIBLE WITH OPENGL RENDERER (BUG), REMOVED IN MATLAB 2014b
                    patchColor = [.3 .3 1];
                else
                    optErase = {};
                    patchColor = [.7 .7 1];
                end
                % BUG WITH PATCH + ERASEMODE
                % Draw patch
                hTimePatch = patch('XData', XData, ...
                                   'YData', YData, ...
                                   'ZData', ZData, ...
                                   'LineWidth', 1, ...
                                   optErase{:}, ...
                                   'FaceColor', patchColor, ...
                                   'FaceAlpha', 1, ...
                                   'EdgeColor', patchColor, ...
                                   'EdgeAlpha', 1, ...
                                   'Tag',       'TimeSelectionPatch', ...
                                   'Parent',    hAxes);
            % Else, patch already exist: update it
            else
                % Change patch limits
                set(hTimePatch, ...
                    'XData', XData, ...
                    'YData', YData, ...
                    'ZData', ZData, ...
                    'Visible', 'on');
            end
            
            % Get current time units
            [timeUnit, isRaw, precision] = panel_time('GetTimeUnit');
            % Get selection label
            hTextTimeSel = findobj(hFig, '-depth', 1, 'Tag', 'TextTimeSel');
            if ~isempty(hTextTimeSel)
                % Format string: Selection
                strMin = panel_time('FormatValue', min(GraphSelection), timeUnit, precision);
                strMax = panel_time('FormatValue', max(GraphSelection), timeUnit, precision);
                strSelection = ['Selection: [' strMin ' ' timeUnit ', ' strMax ' ' timeUnit ']'];
                % Format string: Duration
                strDur = panel_time('FormatValue', max(abs(GraphSelection(2) - GraphSelection(1))), timeUnit, precision);
                strLength = sprintf('      Duration: [%s %s]', strDur, timeUnit);
                % Update label
                set(hTextTimeSel, 'Visible', 'on', 'String', [strSelection, strLength, strMinMax]);
            end
            
        else
            % Remove previous selection patch            
            set(findobj(hAxes, '-depth', 1, 'Tag', 'TimeSelectionPatch'), 'Visible', 'off');
            set(findobj(hFig, '-depth', 1, 'Tag', 'TextTimeSel'), 'Visible', 'off');
        end
    end
end


%% ===== ZOOM INTO SELECTION =====
function ZoomSelection(hFig)
    % Get time selection
	GraphSelection = getappdata(hFig, 'GraphSelection');
    if isempty(GraphSelection) || isinf(GraphSelection(2))
        return;
    end
    % Set axes bounds to selection
    hAxesList = findobj(hFig, '-depth', 1, 'Tag', 'AxesGraph');
    set(hAxesList, 'XLim', [min(GraphSelection), max(GraphSelection)]);
    % Delete selection
    SetTimeSelectionLinked(hFig, []);
end


%% ===== FIGURE MOUSE WHEEL =====
function FigureMouseWheelCallback(hFig, event)
    if isempty(event)
        return;
    end
    % SHIFT + Scroll
    if ismember('shift', get(hFig,'CurrentModifier'))
        FigureScroll(hFig, event.VerticalScrollCount, 'gzoom');
    % CTRL + Scroll
    elseif ismember('control', get(hFig,'CurrentModifier'))
        FigureScroll(hFig, event.VerticalScrollCount, 'vertical');
    % Regular scroll
    else
        FigureScroll(hFig, event.VerticalScrollCount, 'horizontal');
    end
end


%% ===== FIGURE SCROLL =====
function FigureScroll(hFig, ScrollCount, target)
    % Convert scroll count to zoom factor
    if (ScrollCount < 0)
        Factor = 1 - ScrollCount ./ 10;   % ZOOM IN
    elseif (ScrollCount > 0)
        Factor = 1./(1 + double(ScrollCount) ./ 10);   % ZOOM OUT
    else
        Factor = 1;
    end
    % Apply this factor to a target
    switch (target)
        case 'gzoom'
            UpdateTimeSeriesFactor(hFig, Factor);
        case 'vertical'
            FigureZoom(hFig, 'vertical', Factor);
        case 'horizontal'
            FigureZoomLinked(hFig, 'horizontal', Factor);
    end
end


%% ===== FIGURE ZOOM: LINKED =====
% Apply the same zoom operations to similar figures
function FigureZoomLinked(hFig, direction, Factor)
    % Get figure type
    FigureId = getappdata(hFig, 'FigureId');
    % Get all the time-series figures
    switch (FigureId.Type)
        case {'DataTimeSeries', 'ResultsTimeSeries'}
            hAllFigs = bst_figures('GetFiguresByType', {'DataTimeSeries', 'ResultsTimeSeries'});
        case 'Spectrum'
            hAllFigs = bst_figures('GetFiguresByType', 'Spectrum');
    end
    % Place the input figure in first
    hAllFigs(hAllFigs == hFig) = [];
    hAllFigs = [hFig, hAllFigs];
    % Loop over all the figures found
    for i = 1:length(hAllFigs)
        % Apply zoom factor
        FigureZoom(hAllFigs(i), direction, Factor);
    end
end


%% ===== FIGURE ZOOM =====
function FigureZoom(hFig, direction, Factor, center)
    global GlobalData;
    % Parse inputs
    if (nargin < 4)
        center = [];
    end
    % Get list of axes in this figure
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'AxesGraph');
    % Possible directions
    switch lower(direction)
        case 'vertical'
            % Get figure info
            TsInfo = getappdata(hFig, 'TsInfo');
            % Process axes individually
            for i = 1:length(hAxes)
                % Get current zoom factor
                XLim = get(hAxes(i), 'XLim');
                YLim = get(hAxes(i), 'YLim');
                isYLog = strcmpi(get(hAxes(i), 'YScale'), 'log');
                if isYLog
                    YLim = log10(YLim);
                end
                Ylength = YLim(2) - YLim(1);
                % Butterfly plot
                if strcmpi(TsInfo.DisplayMode, 'butterfly')
                    % In case everything is positive: zoom from the bottom, except log spectrum.
                    if (YLim(1) >= 0) && ~isYLog
                        YLim = [YLim(1), YLim(1) + Ylength/Factor];
                    % Else: zoom from the middle
                    else
                        Ycenter = (YLim(2) + YLim(1)) / 2;
                        YLim = [Ycenter - Ylength/Factor/2, Ycenter + Ylength/Factor/2];
                    end
                % Column plot
                elseif strcmpi(TsInfo.DisplayMode, 'column')
                    % Get current point 
                    curPt = get(hAxes(i), 'CurrentPoint');
                    % If the cursor is in the image: Zoom from the cursor
                    if ~isempty(center) || (curPt(1,1) >= XLim(1)) && (curPt(1,1) <= XLim(2)) && (curPt(1,2) >= YLim(1)) && (curPt(1,2) <= YLim(2))
                        if ~isempty(center)
                            Ycenter = center;
                        else
                            Ycenter = curPt(1,2);
                        end
                        if isYLog
                            Ycenter = log10(Ycenter);
                        end
                        Yratio = (Ycenter - YLim(1)) ./ Ylength;
                        if (Ycenter - Ylength/Factor/2 < 0)
                            YLim = [0, Ylength/Factor];
                        elseif (Ycenter + Ylength/Factor/2 > 1)
                            YLim = [1 - Ylength/Factor, 1];
                        else
                            YLim = [Ycenter - Ylength/Factor*Yratio, Ycenter + Ylength/Factor*(1-Yratio)];
                        end
                    % Otherwise: zoom from the bottom
                    else
                        YLim = [YLim(1), YLim(1) + Ylength/Factor];
                    end
                    % Restrict zoom
                    if isYLog
                        YLim(2) = min(YLim(2), 0);
                    else
                        YLim(1) = max(YLim(1), 0);
                        YLim(2) = min(YLim(2), 1);
                    end
                end
                if isYLog
                    YLim = 10.^YLim;
                end                
                % Update zoom factor
                set(hAxes(i), 'YLim', YLim);
                % Set the time cursor height to the maximum of the display
                hCursor = findobj(hAxes(i), '-depth', 1, 'Tag', 'Cursor');
                set(hCursor, 'YData', YLim);
                % Set the selection rectangle dimensions to the maximum of the display
                hTimeSelectionPatch = findobj(hAxes(i), '-depth', 1, 'Tag', 'TimeSelectionPatch');
                if ~isempty(hTimeSelectionPatch)
                    set(hTimeSelectionPatch, 'YData', [YLim(1), YLim(1), YLim(2), YLim(2)]);
                else % Check for spectrum selection patch
                    hSelectionPatch = findobj(hAxes(i), '-depth', 1, 'Tag', 'SelectionPatch');
                    if ~isempty(hSelectionPatch)
                        set(hSelectionPatch, 'YData', [YLim(1), YLim(1), YLim(2), YLim(2)]);
                    end
                end
                % Update amplitude bar (columns mode only)
                if strcmpi(TsInfo.DisplayMode, 'column')
                    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
                    if ~strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.Type, 'Spectrum') 
                        UpdateScaleBar(iDS, iFig, TsInfo);
                    end
                end
            end
        case 'horizontal'
            % Start by displaying the full resolution if necessary
            [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
            if (GlobalData.DataSet(iDS).Figure(iFig).Handles(1).DownsampleFactor > 1)
                if ~isempty(GlobalData.DataSet(iDS).DataFile)
                    set(hFig, 'Pointer', 'watch');
                    drawnow;
                    GlobalData.DataSet(iDS).Figure(iFig).Handles(1).DownsampleFactor = 1;
                    figure_timeseries('PlotFigure', iDS, iFig, [], [], 1);
                    set(hFig, 'Pointer', 'arrow');
                else
                    disp('BST> Warning: Cannot reload file with full resolution.');
                end
            end
            % Get current time frame
            hCursor = findobj(hAxes(1), '-depth', 1, 'Tag', 'Cursor');
            Xcurrent = get(hCursor, 'XData');
            % No time window (averaged time): skip
            if isempty(Xcurrent)
                return;
            end
            Xcurrent = Xcurrent(1);
            % Get initial XLim 
            XLimInit = getappdata(hAxes(1), 'XLimInit');
            % Get current limits
            XLim = get(hAxes(1), 'XLim');
            isXLog = strcmpi(get(hAxes(1), 'XScale'), 'log');
            if isXLog
                % Even in log mode, XLim(1) can be 0. This fixes it.
                if XLim(1) == 0
                    YLim = get(hAxes(1), 'YLim');
                    axis(hAxes(1), 'tight')
                    set(hAxes(1), 'YLim', YLim);
                    XLim = get(hAxes(1), 'XLim');
                    % Also adjust XLimInit and save
                    if XLimInit(1) == 0
                        XLimInit(1) = XLim(1);
                        setappdata(hAxes(1), 'XLimInit', XLimInit);
                    end
                end
                % Avoid errors when Xcurrent was 0 in log scale.
                if Xcurrent < XLimInit(1)
                    Xcurrent = XLimInit(1);
                end
                XLim = log10(XLim);
                XLimInit = log10(XLimInit);
                Xcurrent = log10(Xcurrent);
            end
            % Apply zoom factor
            Xlength = XLim(2) - XLim(1);
            XLim = [Xcurrent - Xlength/Factor/2, Xcurrent + Xlength/Factor/2];
            XLim = bst_saturate(XLim, XLimInit, 1);
            if isXLog
                XLim = 10.^XLim;
            end
            % Apply to ALL Axes in the figure
            set(hAxes, 'XLim', XLim);
            % RAW: Set the time limits of the events bar
            UpdateRawXlim(hFig, XLim);
    end
end


%% ===== FIGURE PAN =====
function FigurePan(hFig, motion)
    % Flip Y motion for flipped axis
    TsInfo = getappdata(hFig, 'TsInfo');
    if ~isempty(TsInfo) && isfield(TsInfo, 'FlipYAxis') && isequal(TsInfo.FlipYAxis, 1)
        motion(2) = -motion(2);
    end
    % Get list of axes in this figure
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'AxesGraph');
    % Displacement in X
    if (motion(1) ~= 0)
        % Get initial and current XLim
        XLimInit = getappdata(hAxes(1), 'XLimInit');
        XLim = get(hAxes(1), 'XLim');
        XLog = strcmpi(get(hAxes, 'XScale'), 'log');
        if XLog
            XLim = log10(XLim);
            XLimInit = log10(XLimInit);
        end
        % Move view along X axis
        XLim = XLim - (XLim(2) - XLim(1)) * motion(1);
        XLim = bst_saturate(XLim, XLimInit, 1);
        if XLog
            XLim = 10.^XLim;
        end
        set(hAxes, 'XLim', XLim);
        % Update raw events bar xlim
        UpdateRawXlim(hFig, XLim);
    end
    % Displacement in Y
    if (motion(2) ~= 0)
        % Get initial and current YLim
        YLimInit = getappdata(hAxes(1), 'YLimInit');
        YLim = get(hAxes(1), 'YLim');
        isYLog = strcmpi(get(hAxes, 'YScale'), 'log');
        if isYLog
            YLim = log10(YLim);
            YLimInit = log10(YLimInit);
        end
        % Move view along Y axis
        YLim = YLim - (YLim(2) - YLim(1)) * motion(2);
        YLim = bst_saturate(YLim, YLimInit, 1);
        if isYLog
            YLim = 10.^YLim;
        end
        set(hAxes, 'YLim', YLim);
        % Set the time cursor height to the maximum of the display
        hCursor = findobj(hAxes, '-depth', 1, 'Tag', 'Cursor');
        set(hCursor, 'YData', YLim)
        % Set the selection rectangle dimensions to the maximum of the display
        hTimeSelectionPatch = findobj(hAxes, '-depth', 1, 'Tag', 'TimeSelectionPatch');
        if ~isempty(hTimeSelectionPatch)
            set(hTimeSelectionPatch, 'YData', [YLim(1), YLim(1), YLim(2), YLim(2)]);
        end
    end
end


%% ===== RESET VIEW: LINKED =====
function ResetViewLinked(hFig)
    % Get all the time-series figures
    hAllFigs = bst_figures('GetFiguresByType', {'DataTimeSeries', 'ResultsTimeSeries'});
    % Place the input figure in first
    hAllFigs(hAllFigs == hFig) = [];
    hAllFigs = [hFig, hAllFigs];
    % Loop over all the figures found
    for i = 1:length(hAllFigs)
        ResetView(hAllFigs(i));
    end
end

%% ===== RESET VIEW =====
function ResetView(hFig)
    global GlobalData;
    % Get list of axes in this figure
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'AxesGraph');
    % Loop the different axes
    for i = 1:length(hAxes)
        % Restore initial X and Y zooms
        XLim = getappdata(hAxes(i), 'XLimInit');
        YLim = getappdata(hAxes(i), 'YLimInit');
        set(hAxes(i), 'XLim', XLim);
        set(hAxes(i), 'YLim', YLim);
        % Set the time cursor height to the maximum of the display
        hCursor = findobj(hAxes(i), '-depth', 1, 'Tag', 'Cursor');
        set(hCursor, 'YData', YLim);
    end
    % Update raw events bar xlim
    UpdateRawXlim(hFig);
    % Get figure handles
    TsInfo = getappdata(hFig, 'TsInfo');
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    % Update scale bar (not for spectrum figures)
    if ~strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.Type, 'Spectrum') && strcmpi(TsInfo.DisplayMode, 'column')
        UpdateScaleBar(iDS, iFig, TsInfo);
    end
end


%% ===== RESIZE FUNCTION =====
function ResizeCallback(hFig, ev)
    % Get figure size
    figPos = get(hFig, 'Position');
    % Get all the axes in the figure
    hAxes = findobj(hFig, '-depth', 1, 'tag', 'AxesGraph');
    nAxes = length(hAxes);
    % Is time bar display or hidden (for RAW viewer)
    TsInfo = getappdata(hFig, 'TsInfo');
    % Scale figure
    Scaling = bst_get('InterfaceScaling') / 100;
    
    % ===== LEFT MARGIN =====
    % Default left margin
    marginLeft = 58 * Scaling;
    % Get current montage
    if ~isempty(TsInfo) && ~isempty(TsInfo.MontageName)
        % Get selected montage
        sMontage = panel_montage('GetMontage', TsInfo.MontageName, hFig);
        % Adapt the margin if the legends are too long
        if ~isempty(sMontage) && ~isempty(sMontage.DispNames) && strcmpi(sMontage.Type, 'text') && (length(sMontage.DispNames) < length(sMontage.ChanNames))
            % Get the longest display name for a channel
            strMax = max(cellfun(@length, sMontage.DispNames));
            marginLeft = (20 + 6*strMax) * Scaling;
        end
    end
    
    % ===== REPOSITION AXES =====
    % With or without time bars
    if isempty(TsInfo) || TsInfo.ShowEvents
        axesPos = [marginLeft, 40*Scaling,  figPos(3)-marginLeft-5-22*Scaling,  figPos(4)-60*Scaling];
    else
        axesPos = [marginLeft,  1,  figPos(3)-marginLeft-5-22*Scaling,  figPos(4)];
    end
    % Reposition axes
    if (nAxes == 1)
        set(hAxes, 'Position', max(axesPos,1));
    elseif (nAxes > 1)
        % Re-order axes in the original order
        iOrder = get(hAxes, 'UserData');
        hAxes([iOrder{:}]) = hAxes;
        % Get number of rows and columns
        nRows = floor(sqrt(nAxes));
        nCols = ceil(nAxes / nRows);
        margins = [marginLeft, 40*Scaling, 5+22*Scaling, 20*Scaling];
        axesSize = [(figPos(3)-margins(3)) / nCols, ...
                    (figPos(4)-margins(4)) / nRows];
        % Resize all the axes independently
        for iAxes = 1:nAxes
            % Get position of this axes in the figure
            iRow = ceil(iAxes / nCols);
            iCol = iAxes - (iRow-1)*nCols;
            % Calculate axes position
            plotPos = [(iCol-1)*axesSize(1) + margins(1), (nRows-iRow)*axesSize(2) + margins(2), axesSize(1)-margins(1), axesSize(2)-margins(2)];
            % Update axes positions
            set(hAxes(iAxes), 'Position', max(plotPos,1));
        end
    end

    % ===== REPOSITION TIME BAR =====
    hRawTimeBar = findobj(hFig, '-depth', 1, 'Tag', 'AxesRawTimeBar');
    if ~isempty(hRawTimeBar)
        hButtonForward   = findobj(hFig, '-depth', 1, 'Tag', 'ButtonForward');
        hButtonBackward  = findobj(hFig, '-depth', 1, 'Tag', 'ButtonBackward');
        hButtonBackward2 = findobj(hFig, '-depth', 1, 'Tag', 'ButtonBackward2');
        % Update time bar position
        barPos = [5 + 30*Scaling, 3, axesPos(1) + axesPos(3) - 70*Scaling - 5, 16*Scaling];
        set(hRawTimeBar, 'Units', 'pixels', 'Position', barPos);
        % Update buttons position
        set(hButtonForward,  'Position',  [barPos(1) + barPos(3) + 3 + 30*Scaling, 3, 30*Scaling, 16*Scaling]);
        set(hButtonBackward, 'Position',  [barPos(1) + barPos(3) + 3, 3, 30*Scaling, 16*Scaling]);
        set(hButtonBackward2, 'Position', [barPos(1) - 30*Scaling, 3, 30*Scaling, 16*Scaling]);
    end
    
    % ===== REPOSITION EVENTS BAR =====
    hEventsBar = findobj(hFig, '-depth', 1, 'Tag', 'AxesEventsBar');
    % Update events bar position
    if ~isempty(hEventsBar)
        eventPos = [axesPos(1), axesPos(2) + axesPos(4) + 1, axesPos(3), figPos(4) - axesPos(2) - axesPos(4) - 1];
        eventPos(eventPos < 1) = 1;
        set(hEventsBar, 'Units', 'pixels', 'Position', eventPos);
    end
    
    % ===== REPOSITION TIME LABEL =====
    hTextCursor = findobj(hFig, '-depth', 1, 'Tag', 'TextCursor');
    % Update events bar position
    if ~isempty(hTextCursor)
        eventPos = [3*Scaling, axesPos(2) + axesPos(4) + 1, axesPos(1) - 2, figPos(4) - axesPos(2) - axesPos(4) - 5*Scaling];
        eventPos(eventPos < 1) = 1;
        set(hTextCursor, 'Units', 'pixels', 'Position', eventPos);
    end
    
    % ===== REPOSITION TIME SELECTION LABEL =====
    hTextTimeSel = findobj(hFig, '-depth', 1, 'Tag', 'TextTimeSel');
    if ~isempty(hTextTimeSel)
        % Update time bar position
        barPos = [axesPos(1), 3*Scaling, axesPos(3) - 40*Scaling, 16*Scaling];
        barPos(barPos < 1) = 1;
        set(hTextTimeSel, 'Units', 'pixels', 'Position', barPos);
    end
    
    % ===== REPOSITION SCALE CONTROLS =====
    hButtonZoomTimeMinus = findobj(hFig, '-depth', 1, 'Tag', 'ButtonZoomTimeMinus');
    hButtonZoomTimePlus  = findobj(hFig, '-depth', 1, 'Tag', 'ButtonZoomTimePlus');
    hButtonGainMinus     = findobj(hFig, '-depth', 1, 'Tag', 'ButtonGainMinus');
    hButtonGainPlus      = findobj(hFig, '-depth', 1, 'Tag', 'ButtonGainPlus');
    hButtonAutoScale     = findobj(hFig, '-depth', 1, 'Tag', 'ButtonAutoScale');
    hButtonMenu          = findobj(hFig, '-depth', 1, 'Tag', 'ButtonMenu');
    hButtonZoomDown      = findobj(hFig, '-depth', 1, 'Tag', 'ButtonZoomDown');
    hButtonZoomMinus     = findobj(hFig, '-depth', 1, 'Tag', 'ButtonZoomMinus');
    hButtonZoomPlus      = findobj(hFig, '-depth', 1, 'Tag', 'ButtonZoomPlus');
    hButtonZoomUp        = findobj(hFig, '-depth', 1, 'Tag', 'ButtonZoomUp');
    % Update positions
    butSize = 22 * Scaling;
    if ~isempty(hButtonZoomTimePlus)
        set(hButtonZoomTimeMinus,  'Position', [figPos(3) - 3*butSize, 3, butSize, butSize]);
        set(hButtonZoomTimePlus,   'Position', [figPos(3) - 2*butSize, 3, butSize, butSize]);
    end
    if ~isempty(hButtonGainMinus)
        set(hButtonGainMinus, 'Position', [figPos(3)-butSize-1, 2*butSize, butSize, butSize]);
        set(hButtonGainPlus,  'Position', [figPos(3)-butSize-1, 3*butSize, butSize, butSize]);
    end
    if ~isempty(hButtonAutoScale)
        set(hButtonAutoScale, 'Position', [figPos(3)-butSize-1, 5*butSize, butSize, butSize]);
    end
    if ~isempty(hButtonMenu)
        set(hButtonMenu, 'Position', [figPos(3)-butSize-1, 6*butSize, butSize, butSize]);
    end
    if ~isempty(hButtonZoomUp)
        set(hButtonZoomDown,  'Position', [figPos(3)-butSize-1, 8*butSize, butSize, butSize]);
        set(hButtonZoomPlus,  'Position', [figPos(3)-butSize-1, 9*butSize, butSize, butSize]);
        set(hButtonZoomMinus, 'Position', [figPos(3)-butSize-1, 10*butSize, butSize, butSize]);
        set(hButtonZoomUp,    'Position', [figPos(3)-butSize-1, 11*butSize, butSize, butSize]);
    end
    
    % ===== REPOSITION SCALE BAR =====
    hColumnScale = findobj(hFig, '-depth', 1, 'Tag', 'AxesColumnScale');
    if ~isempty(hColumnScale)
        % Update scale bar position
        xBar = axesPos(1) + axesPos(3) + 2;
        barPos = [xBar, axesPos(2), figPos(3)-xBar, axesPos(4)];
        barPos = max(barPos, [1 1 1 1]);
        set(hColumnScale, 'Units', 'pixels', 'Position', barPos);
    end
end


%% ===== KEYBOARD CALLBACK =====
function FigureKeyPressedCallback(hFig, ev)
    global GlobalData;
    % Convert event to Matlab (in case it's coming from a java callback)
    [keyEvent, isControl, isShift] = gui_brainstorm('ConvertKeyEvent', ev);
    if isempty(keyEvent.Key)
        return
    end
    % Prevent multiple executions
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'AxesGraph')';
    set([hFig hAxes], 'BusyAction', 'cancel');
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    % Get figure data
    TsInfo = getappdata(hFig, 'TsInfo');
    % ===== GET SELECTED CHANNELS =====
    Modality = GlobalData.DataSet(iDS).Figure(iFig).Id.Modality;
    isMenuSelectedChannels = 0;
    if ~isempty(iDS) && ~isempty(GlobalData.DataSet(iDS).Channel)
        % Get channel selection
        [SelectedRows, iSelectedRows] = GetFigSelectedRows(hFig, {GlobalData.DataSet(iDS).Channel.Name});
        if ~isempty(iSelectedRows) && ~isempty(Modality) && (Modality(1) ~= '$') ...
                && (all(ismember(iSelectedRows, GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels)) || isequal(TsInfo.MontageName, 'Bad channels'))
            isMenuSelectedChannels = 1;
        end
    else
        SelectedRows = [];
        iSelectedRows = [];
    end
    % Check if it is a full data file or not
    isFullDataFile = ~isempty(Modality) && (Modality(1) ~= '$') && ~ismember(Modality, {'results', 'sloreta', 'timefreq', 'stat', 'none'});
    isRaw = strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'raw');
    
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
        % === LEFT, RIGHT, PAGEUP, PAGEDOWN ===
        case {'leftarrow', 'rightarrow', 'uparrow', 'downarrow', 'pageup', 'pagedown', 'home', 'end'}
            panel_time('TimeKeyCallback', keyEvent);
            
        % === DATABASE NAVIGATOR ===
        case {'f1', 'f2', 'f3', 'f4', 'f6'}
            if isRaw
                panel_time('TimeKeyCallback', keyEvent);
            elseif isequal(keyEvent.Key, 'f3') && ~isempty(TsInfo) && ~isempty(TsInfo.FileName) && strcmpi(file_gettype(TsInfo.FileName), 'matrix')
                SwitchMatrixFile(hFig, keyEvent);
            else
                bst_figures('NavigatorKeyPress', hFig, keyEvent);
            end
        % === DATA FILES ===
        % B : Accept/reject trial or time segment
        case 'b'
            if isFullDataFile
                switch lower(GlobalData.DataSet(iDS).Measures.DataType)
                    case 'recordings'
                        % Get data file
                        DataFile = GlobalData.DataSet(iDS).DataFile;
                        if isempty(DataFile)
                            return
                        end
                        % Get study
                        [sStudy, iStudy, iData] = bst_get('DataFile', DataFile);
                        % Change status
                        SetTrialStatus(hFig, DataFile, ~sStudy.Data(iData).BadTrial);
                    case 'raw'
                        panel_record('RejectTimeSegment');
                end
            end
        % CTRL+D : Dock figure
        case 'd'
            if isControl
                isDocked = strcmpi(get(hFig, 'WindowStyle'), 'docked');
                bst_figures('DockFigure', hFig, ~isDocked);
            end
        % E/CTRL+E : Add/delete event
        case 'e'
            if ~isempty(GlobalData.DataSet(iDS).Measures.sFile) % && isFullDataFile
                if isControl && ~isempty(SelectedRows)
                    panel_record('ToggleEvent', [], SelectedRows);
                else
                    panel_record('ToggleEvent');
                end
            end
        % CTRL+F : Open as figure
        case 'f'
            if isControl
                out_figure_image(hFig, 'Figure');
            end
        % CTRL+G : Default topography (no interpolation)
        case 'g'           
            if isControl && isFullDataFile
                bst_figures('ViewTopography', hFig, 0);
            end
        % H : Hide selected event
        case 'h'
            panel_record('EventTypeToggleVisible');
        % CTRL+I : Save as image
        case 'i'
            if isControl
                out_figure_image(hFig);
            end
        % CTRL+J : Open as image
        case 'j'
            if isControl
                out_figure_image(hFig, 'Viewer');
            end
        % CTRL+L : Change display of events
        case 'l'
            if isControl
                switch (TsInfo.ShowEventsMode)
                    case 'dot',   newMode = 'line';
                    case 'line',  newMode = 'none';
                    case 'none',  newMode = 'dot';
                end
                SetProperty(hFig, 'ShowEventsMode', newMode);
            end
        % CTRL+O : Set resolution
        case 'o'
            if isControl
                SetResolution(iDS, iFig);
            end
        % CTRL+S : Sources (first results file)
        case 's'
            if isControl && isFullDataFile
                bst_figures('ViewResults', hFig);
            end
        % CTRL+T : Default topography
        case 't'        
            if isControl && isFullDataFile
                bst_figures('ViewTopography', hFig, 1);
            end
        % CTRL+V : Set video time
        case 'v'           
            if isControl && isFullDataFile
                panel_record('JumpToVideoTime', hFig);
            end
        % Y : Scale to fit Y axis
        case 'y'
            if strcmpi(TsInfo.DisplayMode, 'butterfly')
                ScaleToFitY(hFig, ev);
            end
        % RETURN: VIEW SELECTED CHANNELS
        case 'return'
            if isMenuSelectedChannels && isFullDataFile               
                DisplayDataSelectedChannels(iDS, SelectedRows, GlobalData.DataSet(iDS).Figure(iFig).Id.Modality);
            end
        % DELETE: SET AS BAD
        case {'delete', 'backspace'}
            if isMenuSelectedChannels && isFullDataFile && (length(GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels) ~= length(iSelectedRows))
                % Get figure montage
                TsInfo = getappdata(hFig, 'TsInfo');
                % Get channels selected in the figure (relative to Channel structure)
                if isequal(TsInfo.MontageName, 'Bad channels')
                    newValue = 1;
                else
                    newValue = -1;
                end
                % SHIFT+DELETE: Set all channels as bad but the selected one
                if isShift
                    newChannelFlag = GlobalData.DataSet(iDS).Measures.ChannelFlag;
                    newChannelFlag(GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels) = newValue;
                    newChannelFlag(iSelectedRows) = 1;
                % DELETE
                elseif isMenuSelectedChannels && isFullDataFile
                    newChannelFlag = GlobalData.DataSet(iDS).Measures.ChannelFlag;
                    newChannelFlag(iSelectedRows) = newValue;
                    % Display warning for bipolar SEEG montages
                    if ~isempty(TsInfo.MontageName) && ~isempty(strfind(TsInfo.MontageName, 'bipolar'))
                        if ~java_dialog('confirm', [...
                                'Marking one bad signal with a bipolar montage will mark two channels as bad.' 10 ...
                                'This may cause more than one signal to disappear from this display.' 10 ...
                                'To mark the bad channels individually, select the montage "All channels" first.' 10 10 ...
                                'Mark ' num2str(length(iSelectedRows)) ' channels as bad?' 10 ...
                                sprintf('%s ', GlobalData.DataSet(iDS).Channel(iSelectedRows).Name)], 'Bad channels')
                            return;
                        end
                    end
                end
                % Save new channel flag
                panel_channel_editor('UpdateChannelFlag', GlobalData.DataSet(iDS).DataFile, newChannelFlag);
                % Reset selected channels
                bst_figures('SetSelectedRows', []);
            end
            
        % ESCAPE: CLEAR
        case 'escape'
            % SHIFT+ESCAPE: Set all channels as good
            if isShift && isFullDataFile
                ChannelFlagGood = ones(size(GlobalData.DataSet(iDS).Measures.ChannelFlag));
                panel_channel_editor('UpdateChannelFlag', GlobalData.DataSet(iDS).DataFile, ChannelFlagGood)
            % ESCAPE: Reset selections
            else
                % Reset channel selection
                bst_figures('SetSelectedRows', []);
                % Reset time selection
                SetTimeSelectionLinked(hFig, []);
            end
        otherwise
            % Not found: test based on the character that was generated
            if isfield(keyEvent, 'Character') && ~isempty(keyEvent.Character)
                switch (keyEvent.Character)
                    % PLUS/MINUS: GAIN CONTROL
                    case {'+', '-'}
                        if strcmp(keyEvent.Character, '+')
                            zoomFactor = 1.1;
                        else
                            zoomFactor = .9091;
                        end
                        % Update factor
                        UpdateTimeSeriesFactor(hFig, zoomFactor);
                        % Update channels events
                        hEventObj = [...
                            findobj(hAxes, '-depth', 1, 'Tag', 'EventDotsChannel'); ...
                            findobj(hAxes, '-depth', 1, 'Tag', 'EventDotsExtChannel'); ...
                            findobj(hAxes, '-depth', 1, 'Tag', 'EventLinesChannel'); ...
                            findobj(hAxes, '-depth', 1, 'Tag', 'EventPatchesChannel')];
                        if ~isempty(hEventObj)
                            bst_figures('ReloadFigures', hFig);
                        end
                    % COPY VIEW OPTIONS
                    case '='
                        if isFullDataFile
                            CopyDisplayOptions(hFig, 1, 1);
                        end
                    case '*'
                        if isFullDataFile
                            CopyDisplayOptions(hFig, 1, 0);
                        end
                    % RAW VIEWER: Configurable shortcuts
                    case {'1','2','3','4','5','6','7','8','9'}
                        if ~isempty(GlobalData.DataSet(iDS).Measures.sFile)
                            % Get current configuration
                            RawViewerOptions = bst_get('RawViewerOptions');
                            % If the key that was pressed is in the shortcuts list
                            iShortcut = find(strcmpi(RawViewerOptions.Shortcuts(:,1), keyEvent.Character));
                            % If shortcut was found: call the corresponding function
                            isFullPage = 0;
                            if ~isempty(iShortcut) && ~isempty(RawViewerOptions.Shortcuts{iShortcut,2})
                                % Set selected time for extended events
                                switch (RawViewerOptions.Shortcuts{iShortcut,3})
                                    case 'simple'
                                        selTime = [];
                                    case 'page'
                                        selTime = GlobalData.UserTimeWindow.Time;
                                        isFullPage = 1;
                                    case 'extended'
                                        % If there is already a time window selected: keep it
                                        GraphSelection = getappdata(hFig, 'GraphSelection');
                                        if ~isempty(GraphSelection) && ~isinf(GraphSelection(2))
                                            selTime = [];
                                        % Otherwise, select a time window around the time cursor
                                        else
                                            selTime = GlobalData.UserTimeWindow.CurrentTime + RawViewerOptions.Shortcuts{iShortcut,4};
                                        end
                                end
                                if ~isempty(selTime)
                                    SetTimeSelectionLinked(hFig, selTime);
                                end
                                % Toggle event
                                if isControl && ~isempty(SelectedRows)
                                    panel_record('ToggleEvent', RawViewerOptions.Shortcuts{iShortcut,2}, SelectedRows, isFullPage);
                                else
                                    panel_record('ToggleEvent', RawViewerOptions.Shortcuts{iShortcut,2}, [], isFullPage);
                                end
                                % Reset time selection
                                if ~isempty(selTime)
                                    SetTimeSelectionLinked(hFig, []);
                                end
                                % For full page marking: move to the next non-marked page automatically
                                if isRaw && strcmpi(RawViewerOptions.Shortcuts{iShortcut,3}, 'page')
                                    % Get all the shortcuts of the type "page"
                                    pageEventNames = RawViewerOptions.Shortcuts(strcmpi(RawViewerOptions.Shortcuts(:,3), 'page'), 2);
                                    pageEnd = GlobalData.UserTimeWindow.Time(end);
                                    iLastEvent = [];
                                    iLastOccur = [];
                                    % Look for last page event marked (after the current one)
                                    for i = 1:length(pageEventNames)
                                        [sEvent, iEvent] = panel_record('GetEvents', pageEventNames{i});
                                        if ~isempty(sEvent) && ~isempty(sEvent.times) && (size(sEvent.times,2) == 2) && (pageEnd < sEvent.times(2,end))
                                            pageEnd = sEvent.times(2,end);
                                            iLastEvent = iEvent;
                                            iLastOccur = size(sEvent.times, 2);
                                        end
                                    end
                                    % If nothing marked further and not at the end of the file: jump to next page
                                    if isempty(iLastEvent) || (pageEnd + diff(GlobalData.UserTimeWindow.Time) >= GlobalData.FullTimeWindow.Epochs(GlobalData.FullTimeWindow.CurrentEpoch).Time(end))
                                        keyEvent.Key = 'nooverlap+';
                                        panel_record('RawKeyCallback', keyEvent);
                                    % Otherwise, jump back to the last marked page
                                    else
                                        panel_record('JumpToEvent', iLastEvent, iLastOccur);
                                    end
                                end
                            end
                        end
                end
            end
    end
    % Restore events
    if ~isempty(hFig) && ishandle(hFig)
        hAxes = findobj(hFig, '-depth', 1, 'Tag', 'AxesGraph')';
        set([hFig hAxes], 'BusyAction', 'queue');
    end
end

%% ===== CHANGE CURSOR WITH MODIFIERS =====
function WindowKeyPressedCallback(hFig, ev)
    switch (ev.Key)
        case 'shift'
            set(hFig, 'Pointer', 'ibeam');
        case 'control'
            set(hFig, 'Pointer', 'top');
    end
end
function WindowKeyReleaseCallback(hFig, ev)
    set(hFig, 'Pointer', 'arrow');
end


%% ===== UPDATE TIME SERIES FACTOR =====
function UpdateTimeSeriesFactor(hFig, changeFactor, isSave)
    global GlobalData;
    if (nargin < 3) || isempty(isSave)
        isSave = 1;
    end
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    Handles = GlobalData.DataSet(iDS).Figure(iFig).Handles;
    TsInfo = getappdata(hFig, 'TsInfo');
    % If figure is not in Column display mode: nothing to do
    isColumn = strcmpi(TsInfo.DisplayMode, 'column');
    % Update all axes
    for iAxes = 1:length(Handles)
        % Column plot: update the gain of the lines plotted
        if isColumn
            % Update figure lines
            for iLine = 1:length(Handles(iAxes).hLines)
                % Skip the channels that are not visible
                if (Handles(iAxes).ChannelOffsets(iLine) < 0)
                    continue;
                end
                % Get values
                YData = get(Handles(iAxes).hLines(iLine), 'YData');
                % Re-center them on zero, and change the factor
                YData = (YData - Handles(iAxes).ChannelOffsets(iLine)) * changeFactor + Handles(iAxes).ChannelOffsets(iLine);
                % Update value
                set(Handles(iAxes).hLines(iLine), 'YData', YData);
                % Do the same for the Std halo
                if ~isempty(Handles(iAxes).hLinePatches) && (iLine <= length(Handles(iAxes).hLinePatches))
                    % Get values
                    YData = get(Handles(iAxes).hLinePatches(iLine), 'YData');
                    % Re-center them on zero, and change the factor
                    YData = (YData - Handles(iAxes).ChannelOffsets(iLine)) * changeFactor + Handles(iAxes).ChannelOffsets(iLine);
                    % Update value
                    set(Handles(iAxes).hLinePatches(iLine), 'YData', YData);
                end
            end
            % Update factor value
            GlobalData.DataSet(iDS).Figure(iFig).Handles(iAxes).DisplayFactor = Handles(iAxes).DisplayFactor * changeFactor;
        % Butterfly: Zoom/unzoom vertically in the graph
        else
            FigureZoom(hFig, 'vertical', changeFactor);
            % If auto-scale is disabled: Update DataMinMax to keep it when scrolling
            if ~TsInfo.AutoScaleY
                GlobalData.DataSet(iDS).Figure(iFig).Handles(iAxes).DataMinMax = GlobalData.DataSet(iDS).Figure(iFig).Handles(iAxes).DataMinMax ./ changeFactor;
            end
        end
    end
    % Update default factor in the figure
    TsInfo.DefaultFactor = TsInfo.DefaultFactor * changeFactor;
    setappdata(hFig, 'TsInfo', TsInfo);
    % Save current change factor
    if isSave && isColumn
        SetDefaultFactor(iDS, iFig, changeFactor);
    end
    % Update scale bar (not for spectrum figures)
    if ~strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.Type, 'Spectrum') && isColumn
        UpdateScaleBar(iDS, iFig, TsInfo);
    end
end


%% ===== SET DEFAULT DISPLAY FACTOR =====
function SetDefaultFactor(iDS, iFig, changeFactor)
    global GlobalData;
    % Get modality
    Modality = GlobalData.DataSet(iDS).Figure(iFig).Id.Modality;
    % Default factors list is still empty
    if isempty(GlobalData.DataViewer.DefaultFactor)
        GlobalData.DataViewer.DefaultFactor = {Modality, changeFactor};
    else
        iMod = find(cellfun(@(c)isequal(c,Modality), GlobalData.DataViewer.DefaultFactor(:,1)));
        if isempty(iMod)
            iMod = size(GlobalData.DataViewer.DefaultFactor, 1) + 1;
            GlobalData.DataViewer.DefaultFactor(iMod, :) = {Modality, changeFactor};
        else
            GlobalData.DataViewer.DefaultFactor{iMod,2} = changeFactor * GlobalData.DataViewer.DefaultFactor{iMod,2};
        end
    end
end


%% ===== GET DEFAULT FACTOR =====
function defaultFactor = GetDefaultFactor(Modality)
    global GlobalData
    if isempty(GlobalData.DataViewer.DefaultFactor)
        defaultFactor = 1;
    else
        iMod = find(cellfun(@(c)isequal(c,Modality), GlobalData.DataViewer.DefaultFactor(:,1)));
        if isempty(iMod)
            defaultFactor = 1;
        else
            defaultFactor = GlobalData.DataViewer.DefaultFactor{iMod,2};
        end
    end
end


%% ===== LINE CLICKED =====
function LineClickedCallback(hLine, ev)
    global GlobalData;
    % Get figure handle
    hFig = get(hLine, 'Parent');
    while ~strcmpi(get(hFig, 'Type'), 'figure') || isempty(hFig)
        hFig = get(hFig, 'Parent');
    end
    if isempty(hFig) 
        return;
    end
    hAxes = get(hLine, 'Parent');
    setappdata(hFig, 'clickSource', []);
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    if isempty(iFig)
        return;
    end
    % Ignore figures with multiple graphs
    if (length(GlobalData.DataSet(iDS).Figure(iFig).Handles) > 1)
        return;
    end
    % Get channel indice (relative to montage display rows)
    iClickChan = find(GlobalData.DataSet(iDS).Figure(iFig).Handles(1).hLines == hLine);
    if isempty(iClickChan)
        return
    end
    % Get channel name
    [ChannelName, ChannelLabel] = GetChannelName(iDS, iFig, iClickChan);
    % Get click type
    isRightClick = strcmpi(get(hFig, 'SelectionType'), 'alt');
    % Right click : display popup menu
    if isRightClick
        % Display popup menu (with the channel name as a title)
        setappdata(hFig, 'clickSource', hAxes);
        DisplayFigurePopup(hFig, ChannelLabel, [], {ChannelName});   
        setappdata(hFig, 'clickSource', []);
    % Left click: Select/unselect line
    else
        bst_figures('ToggleSelectedRow', ChannelName);
    end             
    % Update figure selection
    bst_figures('SetCurrentFigure', hFig, '2D');
end


%% ===== GET CHANNEL NAME =====
function [ChannelName, ChannelLabel] = GetChannelName(iDS, iFig, iLine)
    global GlobalData;
    % Get figure handles
    sFig = GlobalData.DataSet(iDS).Figure(iFig);
    % Accept channel mouse selection for DataTimeSeries AND real recordings
    if strcmpi(sFig.Id.Type, 'DataTimeSeries') && ~isempty(sFig.Id.Modality)
        % Get figure montage
        TsInfo = getappdata(sFig.hFigure, 'TsInfo');
        % Get channels selected in the figure (relative to Channel structure)
        if isequal(TsInfo.MontageName, 'Bad channels')
            iFigChannels = find(GlobalData.DataSet(iDS).Measures.ChannelFlag == -1);
        elseif ~isempty(sFig.SelectedChannels)
            iFigChannels = sFig.SelectedChannels;
        else
            iFigChannels = 1:length(GlobalData.DataSet(iDS).Channel);
        end
        % If there is a montage selected
        if ~isempty(TsInfo.MontageName)
            % Get selected montage
            sMontage = panel_montage('GetMontage', TsInfo.MontageName, sFig.hFigure);
            if isempty(sMontage)
                disp(['BST> Error: Invalid montage name "' TsInfo.MontageName '".']);
                return;
            end
            % Get the list of bad channels
            ChannelFlag = GlobalData.DataSet(iDS).Measures.ChannelFlag;
            % Invert the ChannelFlag if looking at bad channels
            if strcmpi(TsInfo.MontageName, 'Bad channels')
                iGood = (ChannelFlag == 1);
                iBad = (ChannelFlag == -1);
                ChannelFlag(iGood) = -1;
                ChannelFlag(iBad) = 1;
            end
            % Get montage indices
            [iMontageChannels, iMatrixChan, iMatrixDisp] = panel_montage('GetMontageChannels', sMontage, {GlobalData.DataSet(iDS).Channel.Name}, ChannelFlag);
            % Get the entry corresponding to the clicked channel in the montage
            ChannelName = sMontage.DispNames{iMatrixDisp(iLine)};
            % Remove possible color tag "NAME|COLOR"
            iTag = find(ChannelName == '|');
            if ~isempty(iTag) && (iTag > 1)
                ChannelName = ChannelName(1:iTag-1);
            end
            ChannelLabel = ['Channel: ' ChannelName];
        elseif strcmpi(sFig.Id.Modality, 'HLUDist')
            ChannelName = 'Distance';
            ChannelLabel = ['Channel: ' ChannelName];
        else
            iChannel = iFigChannels(iLine);
            ChannelName = char(GlobalData.DataSet(iDS).Channel(iChannel).Name);
            ChannelLabel = sprintf('Channel #%d: %s', iChannel, ChannelName);
        end
        % NIRS sensors: Add related channel names
        if strcmpi(sFig.Id.Modality, 'NIRS')
            % Get all related channel names
            ChannelName = panel_montage('GetRelatedNirsChannels', GlobalData.DataSet(iDS).Channel, ChannelName);
        end
    else
        if (iLine <= length(sFig.Handles(1).LinesLabels))
            ChannelName = sFig.Handles(1).LinesLabels{iLine};
        else
            ChannelName = 'noname';
        end
        ChannelLabel = ['Channel: ' ChannelName];
    end
end


%% ===== GET SELECTED ROWS =====
% USAGE:   [RowNames, iRows] = GetFigSelectedRows(hFig, AllRows);
%           RowNames         = GetFigSelectedRows(hFig);
function [RowNames, iRows] = GetFigSelectedRows(hFig, AllRows)
    global GlobalData;
    % Initialize retuned values
    RowNames = [];
    iRows = [];
    % Find figure
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    sHandles = GlobalData.DataSet(iDS).Figure(iFig).Handles(1);
    % Get lines widths
    iValidLines = find(ishandle(sHandles.hLines));
    LineWidth = get(sHandles.hLines(iValidLines), 'LineWidth');
    % Find selected lines
    if iscell(LineWidth)
        iRowsFig = find([LineWidth{:}] > 1.5);
    else
        iRowsFig = find(LineWidth > 1.5);
    end
    % Nothing found
    if isempty(iRowsFig)
        return;
    end
    iRowsFig = iValidLines(iRowsFig);
    % Return row names
    RowNames = unique(sHandles.LinesLabels(iRowsFig));
    % Remove spaces
    RowNamesNoSpace = cellfun(@(c)strrep(c,' ',''), RowNames, 'UniformOutput', 0);
    % If required: get the indices
    if (nargout >= 2) && (nargin >=2) && ~isempty(AllRows)
        % Remove spaces in the other variable as well
        AllRowsNoSpace = cellfun(@(c)strrep(c,' ',''), AllRows, 'UniformOutput', 0);
        % NIRS recordings with overlay montage: select all the corresponding pairs
        if isequal(GlobalData.DataSet(iDS).Figure(iFig).Id.Modality, 'NIRS')
            TsInfo = getappdata(hFig, 'TsInfo');
            if isequal(TsInfo.MontageName, 'NIRS overlay[tmp]')
                % Parse channel names
                [Sall,Dall,WLall] = panel_montage('ParseNirsChannelNames', AllRowsNoSpace); 
                [Ssel,Dsel,WLsel] = panel_montage('ParseNirsChannelNames', RowNamesNoSpace);
                % Find overlap
                for i = 1:length(RowNamesNoSpace)
                    iRows = [iRows, find((Ssel(i) == Sall) & (Dsel(i) == Dall))];
                end
                % Replace row names 
                if ~isempty(iRows)
                    RowNames = AllRows(iRows);
                end
            end
        end
        % Find row indices in the full list
        if isempty(iRows)
            for i = 1:length(RowNamesNoSpace)
                iRows = [iRows, find(strcmpi(RowNamesNoSpace{i}, AllRowsNoSpace))];
            end
        end
        % If the sensors where not found: try to use the current montage
        if isempty(iRows)
            TsInfo = getappdata(hFig, 'TsInfo');
            if ~isempty(TsInfo.MontageName)
                % Get montage
                sMontage = panel_montage('GetMontage', TsInfo.MontageName);
                % Find rows in montage
                iMontageChan = [];
                for i = 1:length(RowNamesNoSpace)
                    iMontageDisp = find(strcmpi(RowNamesNoSpace{i}, sMontage.DispNames));
                    if ~isempty(iMontageDisp) && (nnz(sMontage.Matrix(iMontageDisp,:)) <= 3)
                        iMontageChan = union(iMontageChan, find(sMontage.Matrix(iMontageDisp,:)));
                    end
                end
                % Find montage channels in current dataset
                for i = 1:length(iMontageChan)
                    iRows = [iRows, find(strcmpi(sMontage.ChanNames{iMontageChan(i)}, AllRowsNoSpace))];
                end
            end
        end
    end
end


%% ===== SET SELECTED ROWS =====
% USAGE: 
function SetFigSelectedRows(hFig, RowNames, isSelect)
    global GlobalData;
    % Find figure
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    sHandles = GlobalData.DataSet(iDS).Figure(iFig).Handles;
    % Remove spaces
    RowNames       = cellfun(@(c)strrep(c,' ',''), RowNames, 'UniformOutput', 0);
    allLinesLabels = cellfun(@(c)strrep(c,' ',''), sHandles.LinesLabels, 'UniformOutput', 0);
    % Get lines indices
    if ~isempty(RowNames)
        iLines = [];
        for i = 1:length(RowNames)
            iLines = [iLines, find(strcmpi(RowNames{i}, allLinesLabels))];
        end
    else
        iLines  = 1:length(sHandles.hLines);
    end
    % Process each line
    for i = 1:length(iLines)
        % Get line handle
        hLine = sHandles.hLines(iLines(i));
        % If not a valid handle: skip
        if ~ishandle(hLine)
            continue;
        end
        % Newly selected channels : Paint lines in thick red
        if isSelect
            ZData     = 3 + 0.*get(hLine, 'ZData');
            LineWidth = 2;
            Color     = 'r';
        % Deselected channels : Restore initial color and width
        else
            ZData     = 1.5 + 0.*get(hLine, 'ZData');
            LineWidth = .5;
            Color     = sHandles.LinesColor(iLines(i),:);
        end
        set(hLine, 'LineWidth', LineWidth, 'Color', Color, 'ZData', ZData);
    end
end


%% ===== DISPLAY SELECTED CHANNELS =====
% Usage : DisplayDataSelectedChannels(iDS, SelectedRows, Modality)
function DisplayDataSelectedChannels(iDS, SelectedRows, Modality)
    global GlobalData;
    % Reset selection
    bst_figures('SetSelectedRows', []);
    % Get selected sensors
    DataFile = GlobalData.DataSet(iDS).DataFile;
    % No data file available: exit quietly
    if isempty(DataFile)
        return;
    end
    % Plot selected sensors
    view_timeseries(DataFile, Modality, SelectedRows);
end

%% ===== SET PROPERTY =====
% USAGE:  SetProperty(hFig, propName)            % Toggle 0/1 property
%         SetProperty(hFig, propName, propVal)   % Set property value
function SetProperty(hFig, propName, propVal)
    % Get TsInfo description
    TsInfo = getappdata(hFig, 'TsInfo');
    % Toggle existing value
    if (nargin < 3)
        TsInfo.(propName) = ~TsInfo.(propName);
    % Set value
    else
        TsInfo.(propName) = propVal;
    end
    % Update TsInfo 
    setappdata(hFig, 'TsInfo', TsInfo);
    % Correspondance for graphic property
    if isequal(TsInfo.(propName), 0)
        propGraph = 'off';
    else
        propGraph = 'on';
    end
    % Get axes handles
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'AxesGraph');
    % Update figure
    switch propName
        case 'ShowXGrid'
            set(hAxes, 'XGrid',      propGraph);
            set(hAxes, 'XMinorGrid', propGraph);
        case 'ShowYGrid'
            set(hAxes, 'YGrid',      propGraph);
            set(hAxes, 'YMinorGrid', propGraph);
        case 'FlipYAxis'
            ResetViewLinked(hFig);
            YLimInit = getappdata(hAxes, 'YLimInit');
            if (length(YLimInit) == 2)
                setappdata(hAxes, 'YLimInit', [YLimInit(2), YLimInit(1)]);
            end
            bst_figures('ReloadFigures', hFig, 0);
        case {'ShowZeroLines', 'ShowEventsMode'}
            bst_figures('ReloadFigures', hFig, 0);
        otherwise
            error('Invalid property name.');
    end
    % Save in user preferences
    bst_set(propName, TsInfo.(propName));
end


%% ===== HIDE/SHOW LEGENDS =====
function SetShowLegend(iDS, iFig, ShowLegend)
    global GlobalData;
    % Update TsInfo field
    hFig = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
    TsInfo = getappdata(hFig, 'TsInfo');
    TsInfo.ShowLegend = ShowLegend;
    setappdata(hFig, 'TsInfo', TsInfo);
    % Redraw figure
    switch (GlobalData.DataSet(iDS).Figure(iFig).Id.Type)
        case 'DataTimeSeries'
            isOk = PlotFigure(iDS, iFig, [], [], 0);
            if ~isOk 
                close(hFig);
            end
        case 'ResultsTimeSeries'
            bst_figures('ReloadFigures', hFig, 0);
    end    
end


%% ===== POPUP MENU =====
function DisplayFigurePopup(hFig, menuTitle, curTime, selChan)
    import java.awt.event.KeyEvent;
    import javax.swing.KeyStroke;
    import org.brainstorm.icon.*;
    global GlobalData;
    if isempty(GlobalData) || isempty(GlobalData.DataSet)
        return;
    end
    % Parse inputs
    if (nargin < 4)
        selChan = [];
    end
    if (nargin < 3)
        curTime = [];
    end
    if (nargin < 2)
        menuTitle = '';
    end
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    FigId = GlobalData.DataSet(iDS).Figure(iFig).Id;
    TsInfo = getappdata(hFig, 'TsInfo');
    % Get axes handles
    hAxes = getappdata(hFig, 'clickSource');
    if isempty(hAxes)
        return
    end
    % Get study
    DataFile = GlobalData.DataSet(iDS).DataFile;
    if ~isempty(DataFile)
        [sStudy, iStudy, iData] = bst_get('AnyFile', DataFile);
    end
    isRaw = strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'raw');
    % Get selected channels
    [SelectedRows, iSelectedRows] = GetFigSelectedRows(hFig, {GlobalData.DataSet(iDS).Channel.Name});
    % Get selected events
    [iEvent, iOccur] = panel_record('GetSelectedEvents');
    
    % ===== TITLE =====
    % Create popup menu
    jPopup = java_create('javax.swing.JPopupMenu');
    % Add wall clock time for continuous EDF files in the title of the popup
    dateTitle = '';
    if strcmpi(FigId.Type, 'DataTimeSeries') && ~isempty(FigId.Modality) && isequal(GlobalData.DataSet(iDS).Measures.DataType, 'raw') && ~isempty(GlobalData.DataSet(iDS).Measures.sFile)
        sFile = GlobalData.DataSet(iDS).Measures.sFile;
        % EDF: Wall-clock time
        if strcmpi(sFile.format, 'EEG-EDF') && isfield(sFile.header, 'startdate') && isfield(sFile.header, 'starttime') && ~isempty(sFile.header.startdate) && ~isempty(sFile.header.starttime)
            % Read time and date from the fields in the header
            recdate = sFile.header.startdate;
            rectime = sFile.header.starttime;
            recdate(~ismember(sFile.header.startdate, '1234567890')) = ' ';
            rectime(~ismember(sFile.header.starttime, '1234567890')) = ' ';
            recdate = str2num(recdate);
            rectime = str2num(rectime);
            % Valid times where found
            if (length(recdate) == 3) && (length(rectime) == 3) && ~isequal(recdate, [1 1 1]) && ~isequal(recdate, [0 0 0])
                dstart = datenum(2000 + recdate(3), recdate(2), recdate(1), rectime(1), rectime(2), rectime(3));
                dcur   = datenum(0, 0, 0, 0, 0, floor(GlobalData.UserTimeWindow.CurrentTime));
                dateTitle = [datestr(dstart + dcur, 'dd-mmm-yyyy HH:MM:SS'), '.', num2str(floor(1000 * (GlobalData.UserTimeWindow.CurrentTime - floor(GlobalData.UserTimeWindow.CurrentTime))), '%03d')];
            end
        % Nihon Kohden: Wall clock time
        elseif strcmpi(sFile.format, 'EEG-NK') && isfield(sFile.header, 'startdate') && ~isempty(sFile.header.startdate)
            % Read date from the fields in the header
            recdate = sFile.header.startdate;
            recdate(~ismember(sFile.header.startdate, '1234567890')) = ' ';
            recdate = str2num(recdate);
            % Get timestamp of the current data block
            iEpoch = GlobalData.FullTimeWindow.CurrentEpoch;
            ts = sFile.header.ctl(1).data(iEpoch).timestamp;
            rectime(3) = rem(ts, 60);
            rectime(2) = rem(ts - rectime(3), 3600) / 60;
            rectime(1) = (ts - rectime(2)*60 - rectime(3)) / 3600;
            % Valid times where found
            if (length(recdate) == 3) && (length(rectime) == 3) && ~isequal(recdate, [1 1 1]) && ~isequal(recdate, [0 0 0])
                dstart = datenum(recdate(3), recdate(2), recdate(1), rectime(1), rectime(2), rectime(3));
                dcur   = datenum(0, 0, 0, 0, 0, floor(GlobalData.UserTimeWindow.CurrentTime));
                dateTitle = [datestr(dstart + dcur, 'dd-mmm-yyyy HH:MM:SS'), '.', num2str(floor(1000 * (GlobalData.UserTimeWindow.CurrentTime - floor(GlobalData.UserTimeWindow.CurrentTime))), '%03d')];
            end
        % Spike2 SMR: Wall clock time
        elseif strcmpi(sFile.format, 'EEG-SMRX') && isfield(sFile.header, 'timedate')
            t = sFile.header.timedate;
            dateTitle = [datestr(datenum(t(7), t(6), t(5), t(4), t(3), t(2)), 'dd-mmm-yyyy HH:MM:SS'), '.', num2str(floor(1000 * (GlobalData.UserTimeWindow.CurrentTime - floor(GlobalData.UserTimeWindow.CurrentTime))), '%03d')];
        % Micromed TRC: Wall clock time
        elseif strcmpi(sFile.format, 'EEG-MICROMED') && isfield(sFile.header, 'acquisition') && isfield(sFile.header.acquisition, 'sec')
            acq = sFile.header.acquisition;
            dstart = datenum(acq.year, acq.month, acq.day, acq.hour, acq.min, acq.sec);
            dcur   = datenum(0, 0, 0, 0, 0, floor(GlobalData.UserTimeWindow.CurrentTime));
            dateTitle = [datestr(dstart + dcur, 'dd-mmm-yyyy HH:MM:SS'), '.', num2str(floor(1000 * (GlobalData.UserTimeWindow.CurrentTime - floor(GlobalData.UserTimeWindow.CurrentTime))), '%03d')];
        end
    end
    % Menu title
    if ~isempty(menuTitle) || ~isempty(dateTitle)
        if ~isempty(menuTitle) && ~isempty(dateTitle)
            jTitle = gui_component('Label', jPopup, [], ['<HTML><B>' menuTitle '</B></HTML>']);
        elseif ~isempty(menuTitle)
            jTitle = gui_component('Label', jPopup, [], ['<HTML><B>' menuTitle '</B></HTML>']);
        else
            jTitle = gui_component('Label', jPopup, [], ['<HTML><FONT COLOR="#707070">' dateTitle '</HTML>']);
        end
        jTitle.setBorder(javax.swing.BorderFactory.createEmptyBorder(5,35,0,0));
        jPopup.addSeparator();
    end

    % ==== VIDEO TIME ====
    % Get channel with Video time
    iVideo = find(strcmpi({GlobalData.DataSet(iDS).Channel.Type}, 'Video'), 1);
    % If there is a video sync
    if strcmpi(FigId.Type, 'DataTimeSeries') && ~isempty(FigId.Modality) && ~isempty(iVideo)
        % Get current value for this channel
        VideoTime = bst_memory('GetRecordingsValues', iDS, iVideo, 'CurrentTimeIndex');
        % If there is something to report: "hhmmssff"  (ff=frame)
        if (VideoTime ~= 0)
            % Format video time
            hh = floor(VideoTime / 1e6);
            mm = floor((VideoTime - hh * 1e6) / 1e4);
            ss = floor((VideoTime - hh * 1e6 - mm * 1e4) / 1e2);
            ff = VideoTime - hh * 1e6 - mm * 1e4 - ss * 1e2;
            strVideo = sprintf('%02d:%02d:%02d(%02d)', hh, mm, ss, ff);
            % Show/set video time
            jItem = gui_component('MenuItem', jPopup, [], ['<HTML>Video time &nbsp;&nbsp;&nbsp;<FONT color=#7F7F7F>[' strVideo ']</FONT>'], IconLoader.ICON_ARROW_RIGHT, [], @(h,ev)panel_record('JumpToVideoTime', hFig, VideoTime));
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_V, KeyEvent.CTRL_MASK));
            jPopup.addSeparator();
        end
    end
    
    % ==== EVENTS ====
    % If an event structure is defined
    if ~isempty(GlobalData.DataSet(iDS).Measures.sFile)
        % Add / delete event (global)
        jItem = gui_component('MenuItem', jPopup, [], 'Add / delete event', IconLoader.ICON_EVT_OCCUR_ADD, [], @(h,ev)panel_record('ToggleEvent'));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_E, 0));
        % Add / delete channel event
        if ~isempty(SelectedRows)
            jItem = gui_component('MenuItem', jPopup, [], 'Add / delete channel event', IconLoader.ICON_EVT_OCCUR_ADD, [], @(h,ev)panel_record('ToggleEvent', [], SelectedRows));
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_E, KeyEvent.CTRL_MASK));
        elseif ~isempty(selChan)
            jItem = gui_component('MenuItem', jPopup, [], 'Add / delete channel event', IconLoader.ICON_EVT_OCCUR_ADD, [], @(h,ev)panel_record('ToggleEvent', [], selChan));
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_E, KeyEvent.CTRL_MASK));
        end
        % Edit event notes
        if ~isempty(iOccur)
            jItem = gui_component('MenuItem', jPopup, [], 'Edit notes    (double-click)', IconLoader.ICON_EDIT, [], @(h,ev)panel_record('EventEditNotes'));
        end
        % Only for RAW files
        if isRaw
            % Reject time segment
            jItem = gui_component('MenuItem', jPopup, [], 'Reject time segment', IconLoader.ICON_BAD, [], @(h,ev)panel_record('RejectTimeSegment'));
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_B, 0));
            jPopup.addSeparator();
            % Previous / next event
            jItem = gui_component('MenuItem', jPopup, [], 'Jump to previous event', IconLoader.ICON_ARROW_LEFT, [], @(h,ev)panel_record('JumpToEvent', 'leftarrow'));
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_LEFT, KeyEvent.SHIFT_MASK));
            jItem = gui_component('MenuItem', jPopup, [], 'Jump to next event', IconLoader.ICON_ARROW_RIGHT, [], @(h,ev)panel_record('JumpToEvent', 'rightarrow'));
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_RIGHT, KeyEvent.SHIFT_MASK));
        end
        jPopup.addSeparator();
    end
    
    % ==== DISPLAY OTHER FIGURES ====
    % Only for MEG and EEG time series
    Modality = GlobalData.DataSet(iDS).Figure(iFig).Id.Modality;   
    isSource = ismember(Modality, {'results', 'sloreta', 'timefreq', 'stat', 'none'});
    if ~isempty(Modality) && ismember(Modality, {'EEG', 'MEG', 'MEG MAG', 'MEG GRAD', 'ECOG', 'SEEG', 'ECOG+SEEG', 'NIRS'}) && ~isSource
        % === View TOPOGRAPHY ===
        jItem = gui_component('MenuItem', jPopup, [], 'View topography', IconLoader.ICON_TOPOGRAPHY, [], @(h,ev)bst_figures('ViewTopography', hFig, 1));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_T, KeyEvent.CTRL_MASK));
        if strcmpi(Modality, 'EEG')
            jItem = gui_component('MenuItem', jPopup, [], 'View topography (no smoothing)', IconLoader.ICON_TOPOGRAPHY, [], @(h,ev)bst_figures('ViewTopography', hFig, 0));
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_G, KeyEvent.CTRL_MASK));
        end
        % === View SOURCES ===
        if ~isempty(sStudy.Result)
            jItem = gui_component('MenuItem', jPopup, [], 'View sources', IconLoader.ICON_RESULTS, [], @(h,ev)bst_figures('ViewResults', hFig));
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_S, KeyEvent.CTRL_MASK));
        end
        jPopup.addSeparator();
    end
    
    % ==== MENU: CHANNELS ====
    if ~isempty(iDS) && ~isempty(Modality) && (Modality(1) ~= '$') && ~isSource && ~isempty(DataFile)
        % === SET TRIAL GOOD/BAD ===
        if strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'recordings')
            if (sStudy.Data(iData).BadTrial == 0)
                jItem = gui_component('MenuItem', jPopup, [], 'Reject trial', IconLoader.ICON_BAD, [], @(h,ev)SetTrialStatus(hFig, DataFile, 1));
            else
                jItem = gui_component('MenuItem', jPopup, [], 'Accept trial', IconLoader.ICON_GOOD, [], @(h,ev)SetTrialStatus(hFig, DataFile, 0));
            end
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_B, KeyEvent.CTRL_MASK));
        end    

        % Create figures menu
        jMenuSelected = gui_component('Menu', jPopup, [], 'Channels', IconLoader.ICON_CHANNEL);
        % Excludes figures without selection and display-only figures (modality name starts with '$')
        if ~isempty(iSelectedRows) && ~isempty(GlobalData.DataSet(iDS).Figure(iFig).Id.Modality) ...
                                   && (GlobalData.DataSet(iDS).Figure(iFig).Id.Modality(1) ~= '$')
            % If displaying bad channels
            if isequal(TsInfo.MontageName, 'Bad channels')
                % === SET SELECTED AS GOOD CHANNELS ===
                newChannelFlag = GlobalData.DataSet(iDS).Measures.ChannelFlag;
                newChannelFlag(iSelectedRows) = 1;
                jItem = gui_component('MenuItem', jMenuSelected, [], 'Mark selected as good', IconLoader.ICON_GOOD, [], @(h, ev)panel_channel_editor('UpdateChannelFlag', DataFile, newChannelFlag));
                jItem.setAccelerator(KeyStroke.getKeyStroke(int32(KeyEvent.VK_DELETE), 0)); % DEL
            % If displaying good channels
            elseif all(ismember(iSelectedRows, GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels))
                % === VIEW TIME SERIES ===
                jItem = gui_component('MenuItem', jMenuSelected, [], 'View selected', IconLoader.ICON_TS_DISPLAY, [], @(h, ev)DisplayDataSelectedChannels(iDS, SelectedRows, GlobalData.DataSet(iDS).Figure(iFig).Id.Modality));
                jItem.setAccelerator(KeyStroke.getKeyStroke(int32(KeyEvent.VK_ENTER), 0)); % ENTER
                % === SET SELECTED AS BAD CHANNELS ===
                newChannelFlag = GlobalData.DataSet(iDS).Measures.ChannelFlag;
                newChannelFlag(iSelectedRows) = -1;
                jItem = gui_component('MenuItem', jMenuSelected, [], 'Mark selected as bad', IconLoader.ICON_BAD, [], @(h, ev)panel_channel_editor('UpdateChannelFlag', DataFile, newChannelFlag));
                jItem.setAccelerator(KeyStroke.getKeyStroke(int32(KeyEvent.VK_DELETE), 0)); % DEL
                % === SET NON-SELECTED AS BAD CHANNELS ===
                newChannelFlag = GlobalData.DataSet(iDS).Measures.ChannelFlag;
                newChannelFlag(GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels) = -1;
                newChannelFlag(iSelectedRows) = 1;
                jItem = gui_component('MenuItem', jMenuSelected, [], 'Mark non-selected as bad', IconLoader.ICON_BAD, [], @(h, ev)panel_channel_editor('UpdateChannelFlag', DataFile, newChannelFlag));
                jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_DELETE, KeyEvent.SHIFT_MASK));
            end
            % === RESET SELECTION ===
            jItem = gui_component('MenuItem', jMenuSelected, [], 'Reset selection', IconLoader.ICON_SURFACE, [], @(h, ev)bst_figures('SetSelectedRows',[]));
            jItem.setAccelerator(KeyStroke.getKeyStroke(int32(KeyEvent.VK_ESCAPE), 0)); % ESCAPE
        end
        % Separator if previous items
        if (jMenuSelected.getItemCount() > 0)
            jMenuSelected.addSeparator();
        end

        % ==== MARK ALL CHANNELS AS GOOD ====
        ChannelFlagGood = ones(size(GlobalData.DataSet(iDS).Measures.ChannelFlag));
        jItem = gui_component('MenuItem', jMenuSelected, [], 'Mark all channels as good', IconLoader.ICON_GOOD, [], @(h, ev)panel_channel_editor('UpdateChannelFlag', DataFile, ChannelFlagGood));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_ESCAPE, KeyEvent.SHIFT_MASK));
        % ==== EDIT CHANNEL FLAG =====
        gui_component('MenuItem', jMenuSelected, [], 'Edit good/bad channels...', IconLoader.ICON_GOODBAD, [], @(h,ev)gui_edit_channelflag(DataFile));
    end
    
    % ==== MENU: MONTAGE ====
    if ~isSource && ~isempty(Modality) && (Modality(1) ~= '$') && (isempty(TsInfo) || isempty(TsInfo.RowNames))
        jMenuMontage = gui_component('Menu', jPopup, [], 'Montage', IconLoader.ICON_TS_DISPLAY_MODE);
        panel_montage('CreateFigurePopupMenu', jMenuMontage, hFig);
    end
    
    % ==== MENU: NAVIGATION ====
    if ~isSource && ~isRaw && ~isempty(DataFile)
        jMenuNavigator = gui_component('Menu', jPopup, [], 'Navigator', IconLoader.ICON_NEXT_SUBJECT);
        bst_navigator('CreateNavigatorMenu', jMenuNavigator);
    end
    
    % ==== MENU: SELECTION ====
    jMenuSelection = gui_component('Menu', jPopup, [], 'Time selection', IconLoader.ICON_TS_SELECTION);
    % Move time sursor
    if ~isempty(curTime)
        gui_component('MenuItem', jMenuSelection, [], 'Set current time   [Shift+Click]', [], [], @(h,ev)panel_time('SetCurrentTime', curTime));
        jMenuSelection.addSeparator();
    end
    % Set selection
    gui_component('MenuItem', jMenuSelection, [], 'Set selection manually...', IconLoader.ICON_TS_SELECTION, [], @(h,ev)SetTimeSelectionManual(hFig));
    % Get current time selection
    GraphSelection = getappdata(hFig, 'GraphSelection');
    isTimeSelection = ~isempty(GraphSelection) && ~isinf(GraphSelection(2));
    if isTimeSelection
        gui_component('MenuItem', jMenuSelection, [], 'Zoom into selection (Shift+click)', IconLoader.ICON_ZOOM_PLUS, [], @(h,ev)ZoomSelection(hFig));
        jMenuSelection.addSeparator();
        % ONLY FOR ORIGINAL DATA FILES
        if strcmpi(FigId.Type, 'DataTimeSeries') && ~isempty(FigId.Modality) && (FigId.Modality(1) ~= '$') && ~isempty(DataFile)
            % === SAVE MEAN AS NEW FILE ===
            gui_component('MenuItem', jMenuSelection, [], 'Average time', IconLoader.ICON_TS_NEW, [], @(h,ev)bst_call(@out_figure_timeseries, hFig, 'Database', 'SelectedChannels', 'SelectedTime', 'TimeAverage'));
            % === REJECT TIME SEGMENT ===
            if isRaw
                jItem = gui_component('MenuItem', jMenuSelection, [], 'Reject time segment', IconLoader.ICON_BAD, [], @(h,ev)panel_record('RejectTimeSegment'));
                jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_B, KeyEvent.CTRL_MASK));
            end
            % === EXPORT TO DATABASE ===
            jMenuSelection.addSeparator();
            gui_component('MenuItem', jMenuSelection, [], 'Export to database', IconLoader.ICON_DATA, [], @(h,ev)bst_call(@out_figure_timeseries, hFig, 'Database', 'SelectedChannels', 'SelectedTime'));
        end

        % === EXPORT TO FILE ===
        gui_component('MenuItem', jMenuSelection, [], 'Export to file', IconLoader.ICON_TS_EXPORT, [], @(h,ev)bst_call(@out_figure_timeseries, hFig, [], 'SelectedChannels', 'SelectedTime'));
        % === EXPORT TO MATLAB ===
        gui_component('MenuItem', jMenuSelection, [], 'Export to Matlab', IconLoader.ICON_MATLAB_EXPORT, [], @(h,ev)bst_call(@out_figure_timeseries, hFig, 'Variable', 'SelectedChannels', 'SelectedTime'));
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
        
        % === CONTACT SHEET ===
        % Default output dir
        LastUsedDirs = bst_get('LastUsedDirs');
        DefaultOutputDir = LastUsedDirs.ExportImage;
        % Output menu
        gui_component('MenuItem', jMenuSave, [], 'Contact sheet', IconLoader.ICON_CONTACTSHEET, [], @(h,ev)view_contactsheet(hFig, 'time', 'fig', DefaultOutputDir));
        jMenuSave.addSeparator();
        
        % === EXPORT TO DATABASE ===
        if strcmpi(FigId.Type, 'DataTimeSeries') && ~isempty(FigId.Modality) && (FigId.Modality(1) ~= '$') && ~isempty(DataFile)
            gui_component('MenuItem', jMenuSave, [], 'Export to database', IconLoader.ICON_DATA, [], @(h,ev)bst_call(@out_figure_timeseries, hFig, 'Database', 'SelectedChannels'));
        end
        % === EXPORT TO FILE ===
        gui_component('MenuItem', jMenuSave, [], 'Export to file', IconLoader.ICON_TS_EXPORT, [], @(h,ev)bst_call(@out_figure_timeseries, hFig, [], 'SelectedChannels'));
        % === EXPORT TO MATLAB ===
        gui_component('MenuItem', jMenuSave, [], 'Export to Matlab', IconLoader.ICON_MATLAB_EXPORT, [], @(h,ev)bst_call(@out_figure_timeseries, hFig, 'Variable', 'SelectedChannels'));
        % === EXPORT TO PLOTLY ===
        gui_component('MenuItem', jMenuSave, [], 'Export to Plotly', IconLoader.ICON_PLOTLY, [], @(h,ev)bst_call(@out_figure_plotly, hFig));
        
    % ==== MENU: DISPLAY CONFIG =====
    jMenuConfig = gui_component('Menu', jPopup, [], 'Display options', IconLoader.ICON_PROPERTIES);
    DisplayConfigMenu(hFig, jMenuConfig);
        
    % ==== MENU: FIGURE ====    
    jMenuFigure = gui_component('Menu', jPopup, [], 'Figure', IconLoader.ICON_LAYOUT_SHOWALL);
        % === FIGURE CONFIG ===
        % Change background color
        gui_component('MenuItem', jMenuFigure, [], 'Change background color', IconLoader.ICON_COLOR_SELECTION, [], @(h,ev)bst_figures('SetBackgroundColor', hFig));
        
        % === MATLAB CONTROLS ===
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
        % Recordings
        if strcmpi(FigId.Type, 'DataTimeSeries') && ~isempty(FigId.Modality) && (FigId.Modality(1) ~= '$') && ~isempty(DataFile)
            jMenuFigure.addSeparator();
            % Copy figure properties
            jItem = gui_component('MenuItem', jMenuFigure, [], 'Apply view to all figures', IconLoader.ICON_TS_SYNCRO, [], @(h,ev)CopyDisplayOptions(hFig, 1, 1));
            jItem.setAccelerator(KeyStroke.getKeyStroke('=', 0));
            jItem = gui_component('MenuItem', jMenuFigure, [], 'Apply montage to all figures', IconLoader.ICON_TS_SYNCRO, [], @(h,ev)CopyDisplayOptions(hFig, 1, 0));
            jItem.setAccelerator(KeyStroke.getKeyStroke('*', 0));
        end
        % Clone figure
        jMenuFigure.addSeparator();
        gui_component('MenuItem', jMenuFigure, [], 'Clone figure', IconLoader.ICON_COPY, [], @(h,ev)bst_figures('CloneFigure', hFig));
    % Display Popup menu
    gui_popup(jPopup, hFig);
end



%% ===== DISPLAY CONFIG MENU =====
% USAGE:  DisplayConfigMenu(hFig, jButton)  % Creates menu and show it next to a JButton
%         DisplayConfigMenu(hFig, jMenu)    % Creates menu and include in a parent JMenu
function DisplayConfigMenu(hFig, jParent)
    import org.brainstorm.icon.*;
    import java.awt.*;
    import javax.swing.*;
    import java.awt.event.KeyEvent;
    global GlobalData;
    % Find figure
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    if isempty(iDS)
        return;
    end
    % Get figure config
    TsInfo = getappdata(hFig, 'TsInfo');
    FigureId = GlobalData.DataSet(iDS).Figure(iFig).Id;
    isRaw = strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'raw');
    isSource = ~isempty(FigureId.Modality) && ismember(FigureId.Modality, {'results', 'sloreta', 'timefreq', 'stat', 'none'});
    % Get all other figures
    hFigAll = bst_figures('GetFiguresByType', FigureId.Type);
    
    % Get calling object
    if isa(jParent, 'matlab.ui.eventdata.ActionData')
        jParent = jParent.Source;
    elseif isa(jParent, 'java.awt.event.ActionEvent')
        jParent = jParent.getSource();
    end
    % Create popup
    if isa(jParent, 'javax.swing.JMenu')
        jPopup = jParent;
        isPopup = 0;
    else
        jPopup = java_create('javax.swing.JPopupMenu');
        isPopup = 1;
    end
    % Get current mouse position if needed to display popup menu later (new Matlab versions)
    if isPopup && ~isjava(jParent)
        javaMouse = java.awt.MouseInfo.getPointerInfo().getLocation();
        matlabMouse = get(0,'PointerLocation');
    end
    
    % === DISPLAY MODE ===
    jMenu = gui_component('Menu', jPopup, [], 'Display mode', IconLoader.ICON_TS_DISPLAY_MODE);
        jModeButterfly = gui_component('RadioMenuItem', jMenu, [], 'Butterfly', [], [], @(h,ev)SetDisplayMode(hFig, 'butterfly'));
        jModeColumn = gui_component('RadioMenuItem', jMenu, [], 'Column', [], [], @(h,ev)SetDisplayMode(hFig, 'column'));
        jButtonGroup = ButtonGroup();
        jButtonGroup.add(jModeButterfly);
        jButtonGroup.add(jModeColumn);
        switch (TsInfo.DisplayMode)
            case 'butterfly',   jModeButterfly.setSelected(1);
            case 'column',      jModeColumn.setSelected(1);
        end

    % === X-AXIS ===
    if isRaw || strcmpi(FigureId.Type, 'Spectrum')
        % Menu name
        if strcmpi(FigureId.Type, 'Spectrum')
            strX = 'Frequency';
        else
            strX = 'Time';
        end
        jMenu = gui_component('Menu', jPopup, [], strX, IconLoader.ICON_X);
        % Axis resolution
        if strcmpi(FigureId.Type, 'DataTimeSeries')
            jItem = gui_component('CheckBoxMenuItem', jMenu, [], 'Set axes resolution...', IconLoader.ICON_MATRIX, [], @(h,ev)SetResolution(iDS, iFig));
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_O, KeyEvent.CTRL_MASK)); 
        end
        % Log scale
        if strcmpi(FigureId.Type, 'Spectrum')
            switch (TsInfo.XScale)
                case 'log'
                    newMode = 'linear';
                    isSel = 1;
                case 'linear'
                    newMode = 'log';
                    isSel = 0;
            end
            jItem = gui_component('CheckBoxMenuItem', jMenu, [], 'Log scale', [], [], @(h,ev)SetScaleModeX(hFig, newMode));
            jItem.setSelected(isSel);
        end
    end
    
    % === Y: AMPLITUDE ===
    jMenu = gui_component('Menu', jPopup, [], 'Amplitude', IconLoader.ICON_Y);
        % Auto-scale amplitude
        if ~isempty(TsInfo) && ~isempty(TsInfo.FileName) && ismember(file_gettype(TsInfo.FileName), {'data','matrix'}) && ~strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'stat')
            jAutoScale = gui_component('CheckboxMenuItem', jMenu, [], 'Auto-scale amplitude', [], [], @(h,ev)SetAutoScale(hFig, ev.getSource().isSelected()));
            jAutoScale.setSelected(TsInfo.AutoScaleY);
        end
        % Set scale
        if strcmpi(FigureId.Type, 'DataTimeSeries')
            % Flip Y axis
            jFlipY = gui_component('CheckboxMenuItem', jMenu, [], 'Flip Y axis', [], [], @(h,ev)SetProperty(hFig, 'FlipYAxis'));  % IconLoader.ICON_FLIPY
            jFlipY.setSelected(TsInfo.FlipYAxis);
            % Separator
            jMenu.addSeparator();
            % Set amplitude scale
            if strcmpi(FigureId.Type, 'DataTimeSeries') && ~strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'stat')
                gui_component('MenuItem', jMenu, [], 'Set amplitude scale...',  IconLoader.ICON_FIND_MAX, [], @(h,ev)SetScaleY(iDS, iFig));
            end
            % Set fixed resolution
            if isRaw
                jItem = gui_component('CheckBoxMenuItem', jMenu, [], 'Set axes resolution...', IconLoader.ICON_MATRIX, [], @(h,ev)SetResolution(iDS, iFig));
                jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_O, KeyEvent.CTRL_MASK)); 
            end
            % Uniform amplitude scales
            if ~isRaw && (length(hFigAll) > 1)
                jItem = gui_component('CheckBoxMenuItem', jMenu, [], 'Uniform amplitude scales', [], [], @(h,ev)panel_record('UniformTimeSeries_Callback',h,ev));
                jItem.setSelected(bst_get('UniformizeTimeSeriesScales'));
            end
        end
        % Standardize data
        if strcmpi(FigureId.Type, 'DataTimeSeries')
            jMenu.addSeparator();
            % Remove DC offset
            if isRaw
                RawViewerOptions = bst_get('RawViewerOptions');
                switch RawViewerOptions.RemoveBaseline
                    case 'all',  isRemove = 1;
                    case 'no',   isRemove = 0;
                end
                jItem = gui_component('CheckBoxMenuItem', jMenu, [], 'Remove DC offset', [], [], @(h,ev)panel_record('SetRawViewerOptions', 'RemoveBaseline', ~isRemove));
                jItem.setSelected(isRemove);
            end
            % Normalize amplitudes
            jItem = gui_component('CheckBoxMenuItem', jMenu, [], 'Normalize signals', [], [], @(h,ev)SetNormalizeAmp(iDS, iFig, ~TsInfo.NormalizeAmp));
            jItem.setSelected(TsInfo.NormalizeAmp);
        end
        % Spectrum: power/magnitude/log
        if strcmpi(FigureId.Type, 'Spectrum')
            TfInfo = getappdata(hFig, 'Timefreq');
            sOptions = panel_display('GetDisplayOptions');
            if ismember(TfInfo.Function, {'power', 'magnitude'})
                jScalePow = gui_component('RadioMenuItem', jMenu, [], 'Power', [], [], @(h,ev)panel_display('SetDisplayFunction', 'power'));
                jScaleMag = gui_component('RadioMenuItem', jMenu, [], 'Magnitude', [], [], @(h,ev)panel_display('SetDisplayFunction', 'magnitude'));
                jScaleLog = gui_component('RadioMenuItem', jMenu, [], 'Log(power)', [], [], @(h,ev)panel_display('SetDisplayFunction', 'log'));
                jButtonGroup = ButtonGroup();
                jButtonGroup.add(jScalePow);
                jButtonGroup.add(jScaleMag);
                jButtonGroup.add(jScaleLog);
                switch (sOptions.Function)
                    case 'power',      jScalePow.setSelected(1);
                    case 'magnitude',  jScaleMag.setSelected(1);
                    case 'log',        jScaleLog.setSelected(1);
                end
                jMenu.addSeparator();
            end
            % Log scale
            if strcmpi(TsInfo.DisplayMode, 'butterfly')
                switch (TsInfo.YScale)
                    case 'log'
                        newMode = 'linear';
                        isSel = 1;
                    case 'linear'
                        newMode = 'log';
                        isSel = 0;
                end
                jItem = gui_component('CheckBoxMenuItem', jMenu, [], 'Log scale', [], [], @(h,ev)SetScaleModeY(hFig, newMode));
                jItem.setSelected(isSel);
            end
        end
        % Scale to fit Y
        if strcmpi(TsInfo.DisplayMode, 'butterfly')
            jMenu.addSeparator();
            jItem = gui_component('MenuItem', jMenu, [], 'Scale to fit screen', IconLoader.ICON_Y, [], @(h,ev)ScaleToFitY(hFig, ev));
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_Y, 0));
        end
        
    % === LINES ===
    jMenu = gui_component('Menu', jPopup, [], 'Lines', IconLoader.ICON_MATRIX);
        % XGrid
        jItem = gui_component('CheckBoxMenuItem', jMenu, [], 'Show XGrid', IconLoader.ICON_GRID_X, [], @(h,ev)SetProperty(hFig, 'ShowXGrid'));
        jItem.setSelected(TsInfo.ShowXGrid);
        % YGrid
        if strcmpi(TsInfo.DisplayMode, 'butterfly')
            jItem = gui_component('CheckBoxMenuItem', jMenu, [], 'Show YGrid', IconLoader.ICON_GRID_Y, [], @(h,ev)SetProperty(hFig, 'ShowYGrid'));
            jItem.setSelected(TsInfo.ShowYGrid);
        end
        % Zero lines
        if strcmpi(TsInfo.DisplayMode, 'column')
            jItem = gui_component('CheckBoxMenuItem', jMenu, [], 'Show zero lines', IconLoader.ICON_GRID_Y, [], @(h,ev)SetProperty(hFig, 'ShowZeroLines'));
            jItem.setSelected(TsInfo.ShowZeroLines);
        end
        
    % === EVENTS ===
    if ~strcmpi(FigureId.Type, 'Spectrum')
        jMenu = gui_component('Menu', jPopup, [], 'Events', IconLoader.ICON_EVT_TYPE);
        % Events display mode
        jModeDot = gui_component('RadioMenuItem', jMenu, [], 'Dots', [], [], @(h,ev)SetProperty(hFig, 'ShowEventsMode', 'dot'));
        jModeLine = gui_component('RadioMenuItem', jMenu, [], 'Lines', [], [], @(h,ev)SetProperty(hFig, 'ShowEventsMode', 'line'));
        jModeNone = gui_component('RadioMenuItem', jMenu, [], 'None', [], [], @(h,ev)SetProperty(hFig, 'ShowEventsMode', 'none'));
        jButtonGroup = ButtonGroup();
        jButtonGroup.add(jModeDot);
        jButtonGroup.add(jModeLine);
        jButtonGroup.add(jModeNone);
        jModeDot.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_L, KeyEvent.CTRL_MASK)); 
        jModeLine.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_L, KeyEvent.CTRL_MASK)); 
        jModeNone.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_L, KeyEvent.CTRL_MASK)); 
        switch (TsInfo.ShowEventsMode)
            case 'dot',    jModeDot.setSelected(1);
            case 'line',   jModeLine.setSelected(1);
            case 'none',   jModeNone.setSelected(1);
        end
    end
    
    % === EXTRA ===
    jMenu = gui_component('Menu', jPopup, [], 'Extra', IconLoader.ICON_PLOTEDIT);
        % Legend
        if ~strcmpi(FigureId.Type, 'Spectrum')
            jItem = gui_component('CheckBoxMenuItem', jMenu, [], 'Show legend', IconLoader.ICON_LABELS, [], @(h,ev)SetShowLegend(iDS, iFig, ~TsInfo.ShowLegend));
            jItem.setSelected(TsInfo.ShowLegend);
        end
        % GFP
        if strcmpi(TsInfo.DisplayMode, 'butterfly') && strcmpi(FigureId.Type, 'DataTimeSeries')
            DisplayGFP = bst_get('DisplayGFP');
            jItem = gui_component('CheckBoxMenuItem', jMenu, [], 'Show GFP', [], [], @(h,ev)SetDisplayGFP(hFig, ~DisplayGFP));
            jItem.setSelected(DisplayGFP);
        end
        % Separator
        if ~strcmpi(FigureId.Type, 'Spectrum') && (strcmpi(FigureId.Type, 'DataTimeSeries') || strcmpi(TsInfo.DisplayMode, 'butterfly'))
            jMenu.addSeparator();
        end
        % Change background color
        gui_component('MenuItem', jMenu, [], 'Change background color', IconLoader.ICON_COLOR_SELECTION, [], @(h,ev)bst_figures('SetBackgroundColor', hFig));
        jMenu.addSeparator();
        % Show Matlab controls
        isMatlabCtrl = ~strcmpi(get(hFig, 'MenuBar'), 'none') && ~strcmpi(get(hFig, 'ToolBar'), 'none');
        jItem = gui_component('CheckBoxMenuItem', jMenu, [], 'Matlab controls', IconLoader.ICON_MATLAB_CONTROLS, [], @(h,ev)bst_figures('ShowMatlabControls', hFig, ~isMatlabCtrl));
        jItem.setSelected(isMatlabCtrl);
        % Show plot edit toolbar
        isPlotEditToolbar = getappdata(hFig, 'isPlotEditToolbar');
        jItem = gui_component('CheckBoxMenuItem', jMenu, [], 'Plot edit toolbar', IconLoader.ICON_PLOTEDIT, [], @(h,ev)bst_figures('TogglePlotEditToolbar', hFig));
        jItem.setSelected(isPlotEditToolbar);
        
    % === MONTAGE ===
    if isPopup && strcmpi(FigureId.Type, 'DataTimeSeries') && ~isSource && ~isempty(FigureId.Modality) && (FigureId.Modality(1) ~= '$') && (isempty(TsInfo) || isempty(TsInfo.RowNames))
        jMenuMontage = gui_component('Menu', jPopup, [], 'Montage', IconLoader.ICON_TS_DISPLAY_MODE);
        panel_montage('CreateFigurePopupMenu', jMenuMontage, hFig);
    end
    
    % Show popup
    if isPopup
        if isjava(jParent)
            gui_brainstorm('ShowPopup', jPopup, jParent);
            jPopup.show(jParent, -jPopup.getWidth(), 0);
        else
            % Show initial popup
            gui_popup(jPopup);
            % Get offset from the corner of the button that was clicked
            matlabFig = get(hFig, 'Position');
            matlabButton = get(jParent, 'Position');
            matlabOffset = [matlabMouse(1) - matlabFig(1) - matlabButton(1) + 1, ...
                            matlabMouse(2) - matlabFig(2) - matlabButton(2) - matlabButton(4) + 1];
            % Move popup accordingly
            ScreenDef = bst_get('ScreenDef');
            jPopup.setLocation(java.awt.Point(...
                javaMouse.getX() - matlabOffset(1).*ScreenDef.zoomFactor - jPopup.getWidth(), ...
                javaMouse.getY() + matlabOffset(2).*ScreenDef.zoomFactor));
        end
    end
end



%% ===========================================================================
%  ===== PLOT FUNCTIONS ======================================================
%  ===========================================================================
%% ===== GET FIGURE DATA =====
function [F, TsInfo, Std] = GetFigureData(iDS, iFig)
    global GlobalData;
    % Initizalize returned values
    F = [];
    Std = [];
    % ===== GET INFORMATION =====
    hFig = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
    TsInfo = getappdata(hFig, 'TsInfo');
    if isempty(TsInfo)
        return
    end
    % Get bad channels
    ChannelFlag = GlobalData.DataSet(iDS).Measures.ChannelFlag;
    % Get selected channels for figure
    if isequal(TsInfo.MontageName, 'Bad channels')
        selChan = find(ChannelFlag == -1);
        ChannelFlag = ones(size(ChannelFlag));
    else
        selChan = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels;
    end
    % Get values
    isGradMagScale = 1;
    [Fall, StdAll] = bst_memory('GetRecordingsValues', iDS, [], [], isGradMagScale);
    if isempty(Fall)
        return;
    end
    % Check for NaN: Remove them and display warning
    if (nnz(isnan(Fall)) > 0)
        disp('BST> Error: Matrix F contains NaN values, replacing them with zeros. Please check your data files.');
        Fall(isnan(Fall)) = 0;
    end
    
    % ===== APPLY MONTAGE =====
    % Get channel names 
    ChanNames = {GlobalData.DataSet(iDS).Channel.Name};
    iChannels = [];
    % Get montage selected in this figure
    if ~isempty(TsInfo.MontageName)
        % Get montage
        sMontage = panel_montage('GetMontage', TsInfo.MontageName, hFig);
        % Get channel indices in the figure montage
        if ~isempty(sMontage)
            [iChannels, iMatrixChan, iMatrixDisp] = panel_montage('GetMontageChannels', sMontage, ChanNames, ChannelFlag);
            % No signal to display
            if isempty(iMatrixDisp) && ~isempty(sMontage.ChanNames)
                % bst_error(['Montage "' TsInfo.MontageName '" must be edited before being applied to this dataset.' 10 'Select "Edit montages" and check the name of the electrodes.'], 'Invalid montage', 0);
                iChannels = [];
            end
        end
    end
    % Apply montage
    if ~isempty(iChannels)
        F = panel_montage('ApplyMontage', sMontage, Fall(iChannels,:), GlobalData.DataSet(iDS).DataFile, iMatrixDisp, iMatrixChan);
        if ~isempty(StdAll) && (isequal(sMontage.Type, 'selection') || (isequal(sMontage.Type, 'text') && all(ismember(sMontage.Matrix(:), [0 1])) && all(sum(abs(sMontage.Matrix),2) == 1)))
            Std = panel_montage('ApplyMontage', sMontage, StdAll(iChannels,:,:,:), GlobalData.DataSet(iDS).DataFile, iMatrixDisp, iMatrixChan);
        end
        % Modify channel names
        TsInfo.LinesLabels = sMontage.DispNames(iMatrixDisp)';
    % No montage to apply: Keep only the figure data
    else
        % Keep only the selected sensors
        F = Fall(selChan,:);
        if ~isempty(StdAll)
            Std = StdAll(selChan,:,:,:);
        end
        % Lines names=channel names
        TsInfo.LinesLabels = ChanNames(selChan)';
        % Force: no montage on this figure
        TsInfo.MontageName = [];
    end
    % Convert to cell
    F = {F};
    if ~isempty(Std)
        Std = {Std};
    end
    % Update figure structure
    setappdata(hFig, 'TsInfo', TsInfo);
end


%% ===== PLOT FIGURE =====
% USAGE:  isOk = PlotFigure(iDS, iFig, F, TimeVector, isFastUpdate=[], Std=[])
%         isOk = PlotFigure(iDS, iFig)
function isOk = PlotFigure(iDS, iFig, F, TimeVector, isFastUpdate, Std)
    global GlobalData;
    isOk = 0;
    % Parse inputs
    if (nargin < 3)
        F = [];
    end
    if (nargin < 4)
        TimeVector = [];
    end
    if (nargin < 5) || isempty(isFastUpdate)
        isFastUpdate = [];
    end
    if (nargin < 6) || isempty(Std)
        Std = [];
    end
    hFig = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
    isForceResize = 0;

    % ===== GET DATA =====
    % Get data to display
    if isempty(F)
        [F, TsInfo, Std] = GetFigureData(iDS, iFig);
        % No data
        if isempty(F) || (iscell(F) && isempty(F{1}))
            disp('BST> Error: no data could be found for this figure...');
            return
        end
    else
        hFig = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
        TsInfo = getappdata(hFig, 'TsInfo');
    end
    % Std halo to display: disable fast updates
    if ~isempty(Std)
        isFastUpdate = 0;
        % Make sure we are using the OpenGL renderer (the default before Matlab 2014 is 'zbuffer')
        if (bst_get('MatlabVersion') <= 803)
            set(hFig, 'Renderer', 'opengl');
        end
    end
    % Make sure that F is a cell array
    nAxes = length(F);
    % Get time window indices
    if isempty(TimeVector)
        [TimeVector, iTime] = bst_memory('GetTimeVector', iDS, [], 'UserTimeWindow');
        TimeVector = TimeVector(iTime);
    end
    % Store the time vector
    setappdata(hFig, 'TimeVector', TimeVector);
    % Get display options
    [iDSRaw, isRaw] = panel_record('GetCurrentDataset', hFig);    
    % Normalize channels?
    if TsInfo.NormalizeAmp
        for ic = 1:length(F)
            maxF = max(abs(F{ic}),[],2);
            F{ic} = bst_bsxfun(@rdivide, F{ic}, maxF);
            if ~isempty(Std)
                Std{ic} = bst_bsxfun(@rdivide, Std{ic}, maxF);
            end
        end
    end
    
    % ===== DISPLAY =====
    % Full or fast update?
    if isempty(isFastUpdate)
        isFastUpdate = (nAxes == 1) ...
                       && strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.Type, 'DataTimeSeries')...
                       && (length(GlobalData.DataSet(iDS).Figure(iFig).Handles) == 1) ...
                       && (size(F{1},1) == length(GlobalData.DataSet(iDS).Figure(iFig).Handles(1).hLines)) ...
                       && all(ishandle(GlobalData.DataSet(iDS).Figure(iFig).Handles(1).hLines));
    end
    % Fast update: keep all the existing graphic objects
    if isFastUpdate
        % Get existing handles structure
        PlotHandles = GlobalData.DataSet(iDS).Figure(iFig).Handles;
    % Full update: Clear current figure
    else
        % Clear figure
        clf(hFig);
        % Initialize graphic handles
        PlotHandles = repmat(db_template('DisplayHandlesTimeSeries'), 1, nAxes);
    end
    % Loop on each axes to plot
    for iAxes = 1:nAxes
        % === CREATE AXES ===
        % Make sure that we are drawing in the right figure
        set(0, 'CurrentFigure', hFig);
        % Create axes
        if isFastUpdate
            hAxes(iAxes) = PlotHandles(iAxes).hAxes;
        else
            % Create axes object
            %hAxes(iAxes) = subplot('Position', [10*iAxes, 10, 10 10]);
            hAxes(iAxes) = axes;
            set(hAxes(iAxes), ...
                'Units',      'pixels', ...
                'UserData',   iAxes, ...
                'YGrid',      'off', ...
                'YMinorGrid', 'off', ...
                'XGrid',      'off', ...
                'XMinorGrid', 'off');
            % Initialize axes object structure
            PlotHandles(iAxes).hAxes = hAxes(iAxes);
        end
        
        % === GET DATA MAXIMUM ===
        % Displaying normalized data
        if TsInfo.NormalizeAmp
            PlotHandles(iAxes).DataMinMax = [-1, 1];
        % If existing MinMax, use it
        elseif ~TsInfo.AutoScaleY && isfield(GlobalData.DataSet(iDS).Figure(iFig).Handles, 'DataMinMax') && ...
                (iAxes <= length(GlobalData.DataSet(iDS).Figure(iFig).Handles)) && ~isempty(GlobalData.DataSet(iDS).Figure(iFig).Handles(iAxes).DataMinMax) && ...
                (GlobalData.DataSet(iDS).Figure(iFig).Handles(iAxes).DataMinMax(2) ~= GlobalData.DataSet(iDS).Figure(iFig).Handles(iAxes).DataMinMax(1))
            PlotHandles(iAxes).DataMinMax = GlobalData.DataSet(iDS).Figure(iFig).Handles(iAxes).DataMinMax;
        % Calculate minimum/maximum values
        else
            PlotHandles(iAxes).DataMinMax = [min(F{iAxes}(:)), max(F{iAxes}(:))];
            % With Std
            if ~isempty(Std) && ~isempty(Std{iAxes}) && ContainsDims(F{iAxes}, Std{iAxes})
                % Check whether Std is an interval or a single value centered on the data
                if ndims(Std{iAxes}) >= 4
                    Faxes = [Std{iAxes}(:,:,:,2), Std{iAxes}(:,:,:,1)];
                else
                    Faxes = [F{iAxes} + Std{iAxes}, F{iAxes} - Std{iAxes}];
                end
                tmpMinMax = [min(Faxes(:)), max(Faxes(:))];
                % Make sure that we are not going below zero just because of the Std
                if (PlotHandles(iAxes).DataMinMax(1) > 0) && (tmpMinMax(1) < 0)
                    PlotHandles(iAxes).DataMinMax = [0, tmpMinMax(2)];
                else
                    PlotHandles(iAxes).DataMinMax = tmpMinMax;
                end
            end
        end
        
        % === PLOT AXES ===
        % Lines labels
        if ~isempty(TsInfo.LinesLabels) 
            if (size(TsInfo.LinesLabels, 2) == nAxes)
                LinesLabels = TsInfo.LinesLabels(:,iAxes);
                % Make sure that only the correct number of entries are taken (to fix case of multiple graphs with different numbers of signals)
                if (length(LinesLabels) > size(F{iAxes},1))
                    LinesLabels = LinesLabels(1:size(F{iAxes},1),:);
                end
            else
                LinesLabels = TsInfo.LinesLabels;
            end
        else
            LinesLabels = {};
        end
        % Lines colors
        if ~isempty(TsInfo.LinesColor) 
            if (size(TsInfo.LinesColor, 2) == nAxes)
                LinesColor = cat(1, TsInfo.LinesColor{:,iAxes});
            else
                LinesColor = cat(1, TsInfo.LinesColor{:});
            end
        else
            LinesColor = [];
        end
        % If displaying static averages in time: use the beginning and the end of the time vector
        if (size(F{iAxes},2) == 2) && (length(TimeVector) > 2)
            TimeVector_axes = TimeVector([1, end]);
        else
            TimeVector_axes = TimeVector;
        end
        % Auto-detect if legend should be displayed
        if isempty(TsInfo.ShowLegend)
            TsInfo.ShowLegend = (size(F{iAxes},1) <= 15) && (~isempty(TsInfo.RowNames) || ~ismember(TsInfo.Modality, {'EEG','MEG','MEG MAG','MEG GRAD','SEEG','ECOG','ECOG+SEEG'}));
            setappdata(hFig, 'TsInfo', TsInfo);
        end
        % If there is Std data available
        if ~isempty(Std)
            Std_i = Std{iAxes};
        else
            Std_i = [];
        end
        % Plot data in the axes
        PlotHandles(iAxes) = PlotAxes(iDS, hAxes(iAxes), PlotHandles(iAxes), TimeVector_axes, F{iAxes}, TsInfo, LinesLabels, LinesColor, isFastUpdate, Std_i);
        % Legends and titles
        if ~isFastUpdate
            % X Axis legend
            if isRaw || (nAxes > 1)
                xlabel(hAxes(iAxes), ' ');
            else
                xlabel(hAxes(iAxes), 'Time (s)', ...
                    'FontSize',    bst_get('FigFont'), ...
                    'FontUnits',   'points', ...
                    'Interpreter', 'none');
            end
            % Title
            if ~isempty(TsInfo.AxesLabels)
                title(hAxes(iAxes), TsInfo.AxesLabels{iAxes}, ...
                    'FontSize',    bst_get('FigFont') + 1, ...
                    'FontUnits',   'points', ...
                    'Interpreter', 'none');
            end
        end
        % Store initial XLim and YLim
        setappdata(hAxes(iAxes), 'XLimInit', get(hAxes(iAxes), 'XLim'));
        % When updating the figure: Keep the same zoom factor
        if ~isFastUpdate
            setappdata(hAxes(iAxes), 'YLimInit', get(hAxes(iAxes), 'YLim'));
        end
    end
    % Resize here FOR MAC ONLY (don't now why, if not the display flickers)
    if strncmp(computer,'MAC',3)
        %ResizeCallback(hFig, []);
        isForceResize = 1;
    end
    % Link axes together for zooming/panning
    if (nAxes > 1)
        linkaxes(hAxes, 'x');
    end
    % Update figure list of handles
    GlobalData.DataSet(iDS).Figure(iFig).Handles = PlotHandles;
        
    % ===== EVENT BAR =====
    % Get figure type
    Modality = GlobalData.DataSet(iDS).Figure(iFig).Id.Modality;
    % If event bar should be displayed
    if (nAxes == 1) && TsInfo.ShowEvents
        % Update axes
        if isFastUpdate
            hEventsBar = findobj(hFig, 'Tag', 'AxesEventsBar');
            set(hEventsBar, 'XLim', get(hAxes, 'XLim'));
        % Create axes
        else
            hEventsBar = axes('Position', [0, 0, .01, .01]);
            set(hEventsBar, ...
                 'Interruptible', 'off', ...
                 'BusyAction',    'queue', ...
                 'Tag',           'AxesEventsBar', ...
                 'YGrid',      'off', ...
                 'XGrid',      'off', ...
                 'XMinorGrid', 'off', ...
                 'XTick',      [], ...
                 'YTick',      [], ...
                 'TickLength', [0,0], ...
                 'Color',      'none', ...
                 'XLim',       get(hAxes, 'XLim'), ...
                 'YLim',       [0 1], ...
                 'Box',        'off');
        end
        % Update events markers+labels in the events bar
        if ~isRaw
            % Plot events dots
            PlotEventsDots_EventsBar(hFig);
        end
    else
        hEventsBar = [];
    end
    
    % ===== TIME TEXT LABEL =====
    % Get background color
    bgcolor = get(hFig, 'Color');
    % Plot time text (for non-static datasets)
    if (GlobalData.DataSet(iDS).Measures.NumberOfSamples > 2) && (TsInfo.ShowEvents || (nAxes > 1))
        % Format current time
        [timeUnit, isRaw, precision] = panel_time('GetTimeUnit');
        textCursor = panel_time('FormatValue', GlobalData.UserTimeWindow.CurrentTime, timeUnit, precision);
        textCursor = [textCursor ' ' timeUnit];
        % Update text object
        if isFastUpdate && ~isempty(PlotHandles(1).hTextCursor) && ishandle(PlotHandles(1).hTextCursor)
            set(PlotHandles(1).hTextCursor, 'String', textCursor);
        % Create text object
        else
            PlotHandles(1).hTextCursor = uicontrol(...
                'Style',               'text', ...
                'String',              textCursor, ...
                'Units',               'Pixels', ...
                'HorizontalAlignment', 'left', ...
                'FontUnits',           'points', ...
                'FontSize',            bst_get('FigFont'), ...
                'FontWeight',          'bold', ...
                'ForegroundColor',     [0 0 0], ...
                'BackgroundColor',     bgcolor, ...
                'Parent',              hFig, ...
                'Tag',                 'TextCursor');
            % Update figure list of handles
            GlobalData.DataSet(iDS).Figure(iFig).Handles = PlotHandles;
        end
    end
    
    % ===== SELECTION TEXT =====
    if ~isFastUpdate && (GlobalData.DataSet(iDS).Measures.NumberOfSamples > 2) && (~isempty(hEventsBar) || (nAxes > 1))
        hTextTimeSel = uicontrol(...
            'Style',               'text', ...
            'String',              'Selection', ...
            'Units',               'Pixels', ...
            'HorizontalAlignment', 'center', ...
            'FontUnits',           'points', ...
            'FontSize',            bst_get('FigFont') + 0.5, ...
            'FontWeight',          'normal', ...
            'ForegroundColor',     [0 0 0], ...
            'BackgroundColor',     bgcolor, ...
            'Parent',              hFig, ...
            'Tag',                 'TextTimeSel', ...
            'Visible',             'off');
    end
    
    % ===== RAW TIME SLIDER =====
    % If the previous figures are also raw time series views: do not plot again the time bar
    if isRaw && ~isempty(Modality) && TsInfo.ShowEvents
        % Fast update: Update raw time position
        if isFastUpdate
            UpdateRawTime(hFig);
        % Full update: Create time bar
        else
            PlotRawTimeBar(iDS, iFig);
        end
    end
    % ===== SCALE BAR =====
    % For column displays: add a scale display
    if ~TsInfo.NormalizeAmp && strcmpi(TsInfo.DisplayMode, 'column') && (nAxes == 1)
        % Show axes
        if isFastUpdate && ~isempty(PlotHandles(1).hColumnScale) && ishandle(PlotHandles(1).hColumnScale)
            set(PlotHandles(1).hColumnScale, 'Visible', 'on');
        % Create axes
        else
            PlotHandles(1).hColumnScale = axes('Position', [0, 0, .01, .01]);
            set(PlotHandles(1).hColumnScale, ...
                'Interruptible', 'off', ...
                'BusyAction',    'queue', ...
                'Tag',           'AxesColumnScale', ...
                'YGrid',      'off', ...
                'XGrid',      'off', ...
                'XMinorGrid', 'off', ...
                'XTick',      [], ...
                'YTick',      [], ...
                'TickLength', [0,0], ...
                'Color',      'none', ...
                'XLim',       [0 1], ...
                'YLim',       get(hAxes, 'YLim'), ...
                'Box',        'off');
            % Update figure list of handles
            GlobalData.DataSet(iDS).Figure(iFig).Handles = PlotHandles;
            % Force resize of the figure to update the size of the column scale
            isForceResize = 1;
        end
        % Update scale bar
        UpdateScaleBar(iDS, iFig, TsInfo);
    elseif ~isempty(PlotHandles(1).hColumnScale) && ishandle(PlotHandles(1).hColumnScale)
        set(PlotHandles(1).hColumnScale, 'Visible', 'off');
        cla(PlotHandles(1).hColumnScale);
    end
    if ~isfield(TsInfo, 'XScale')
        TsInfo.XScale = 'linear';
        setappdata(hFig, 'TsInfo', TsInfo);
    else
        set(hAxes, 'XScale', TsInfo.XScale);
    end
    % Create scale buttons
    if ~isFastUpdate && isempty(findobj(hFig, 'Tag', 'ButtonGainPlus'))
        CreateScaleButtons(iDS, iFig);
    else
        hButtonZoom = [findobj(hFig, '-depth', 1, 'Tag', 'ButtonZoomUp'), ...
                       findobj(hFig, '-depth', 1, 'Tag', 'ButtonZoomPlus'), ...
                       findobj(hFig, '-depth', 1, 'Tag', 'ButtonZoomMinus'), ...
                       findobj(hFig, '-depth', 1, 'Tag', 'ButtonZoomDown')];
        if ~isempty(hButtonZoom) && strcmpi(TsInfo.DisplayMode, 'column') && strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.Type, 'DataTimeSeries')
            set(hButtonZoom, 'Visible', 'on');
        else
            set(hButtonZoom, 'Visible', 'off');
        end
    end
    % Update sensor selection
    SelectedRowChangedCallback(iDS, iFig)
    % Resize callback if only one axes
    if ~isFastUpdate || isForceResize
        ResizeCallback(hFig, []);
    end
    % Update stat clusters
    if ~isFastUpdate && ~isempty(TsInfo) && ~isempty(TsInfo.FileName) && ismember(file_gettype(TsInfo.FileName), {'pdata','pmatrix','presult'}) && ~isequal(Modality, 'Clusters')
        ViewStatClusters(hFig);
    end
    % Set current object/axes
    if ishandle(hAxes(1))
        set(hFig, 'CurrentAxes', hAxes(1), 'CurrentObject', hAxes(1));
    end
    isOk = 1;
end


%% ===== SHOW TIME CURSOR =====
function SetTimeVisible(hFig, isVisible) %#ok<*DEFNU>
    hTextCursor = findobj(hFig, '-depth', 1, 'Tag', 'TextCursor');
    if ~isempty(hTextCursor)
        if isVisible
            set(hTextCursor, 'Visible', 'on');
        else
            set(hTextCursor, 'Visible', 'off');
        end
    end
end


%% ===== PLOT AXES =====
function PlotHandles = PlotAxes(iDS, hAxes, PlotHandles, TimeVector, F, TsInfo, LinesLabels, LinesColor, isFastUpdate, Std)
    global GlobalData;
    hold on;
    % Set color table for lines
    nLines = size(F,1);
    DefaultColor = [.2 .2 .2];
    if (TsInfo.ShowLegend)
        if isempty(LinesColor)
            ColorOrder = panel_scout('GetScoutsColorTable');
        else
            ColorOrder = [];
        end
    else
        ColorOrder = DefaultColor;
        LinesColor = [];
    end
    % Update color order
    if ~isFastUpdate && ~isempty(ColorOrder)
        set(hAxes, 'ColorOrder', ColorOrder);
    end
    % Replicate inputs when ScoutFunction='All'
    if ~isempty(LinesColor) && (size(LinesColor,1) == 1) && (nLines > 1)
        LinesColor = repmat(LinesColor, nLines, 1);
    end
    if ~isempty(LinesLabels) && (size(LinesLabels,1) == 1) && (size(LinesLabels,2) == nLines) && (nLines > 1)
        LinesLabels = LinesLabels';
    elseif ~isempty(LinesLabels) && (length(LinesLabels) == 1) && (nLines > 1)
        LinesLabels = repmat(LinesLabels, nLines, 1);
    end

    % ===== PARSE LINE LABELS =====
    % Get colors from montage (not for scouts, only for recordings)
    LinesFilter = [];
    if ~strcmpi(TsInfo.Modality, 'results') && ~strcmpi(TsInfo.Modality, 'sloreta') && ~strcmpi(TsInfo.Modality, 'timefreq') && (~isempty(TsInfo.Modality) && (TsInfo.Modality(1) ~= '$')) && ~isempty(LinesLabels)
        % Parse montage labels
        [LinesLabels, MontageColors, LinesFilter] = panel_montage('ParseMontageLabels', LinesLabels, DefaultColor);
        % Replace plot colors if available
        if ~isempty(MontageColors) && isempty(LinesColor)
            LinesColor = MontageColors;
        end
    end
    
    % ===== MONTAGE FREQUENCY FILTERS =====
    if ~isempty(LinesFilter) && (size(LinesFilter,1) == size(F,1)) && ~all(LinesFilter(:) == 0)
        % Filter each signal independently
        for iLine = 1:size(F,1)
            if ~all(LinesFilter(iLine,:) == 0)
                sfreq = 1./GlobalData.DataSet(iDS).Measures.SamplingRate;
                isMirror = 0;
                isRelax = 1;
                [F(iLine,:), FiltSpec, Messages] = process_bandpass('Compute', F(iLine,:), sfreq, LinesFilter(iLine,1), LinesFilter(iLine,2), 'bst-hfilter-2019', isMirror, isRelax);
                % if ~isempty(Messages)
                %     disp(['BST> Montage warning for line "'  LinesLabels{iLine} '": ' Messages(1:end-1)]);
                % end
            end
        end
    end

    % ===== DOWNSAMPLE TIME SERIES =====
    % If optimization is disabled
    DownsampleTimeSeries = bst_get('DownsampleTimeSeries');
    if (DownsampleTimeSeries == 0)
        PlotHandles.DownsampleFactor = 1;
    % Detect optimal downsample factor
    elseif ~isFastUpdate || isempty(PlotHandles.DownsampleFactor)
        % Get number of pixels in the axes
        % figPos = get(get(hAxes,'Parent'), 'Position');
        % nPixels = figPos(3) -50;
        % Keep 5 values per pixel, and consider axes of 2000 pixels
        nPixels = 2000;
        PlotHandles.DownsampleFactor = max(1, floor(length(TimeVector) / nPixels / DownsampleTimeSeries));
    end
    % Downsample time series
    if (PlotHandles.DownsampleFactor > 1) && ~isempty(GlobalData.DataSet(iDS).DataFile)
        TimeVector = TimeVector(1:PlotHandles.DownsampleFactor:end);
        F = F(:,1:PlotHandles.DownsampleFactor:end);
        if ~isempty(Std)
            Std = Std(:,1:PlotHandles.DownsampleFactor:end,:,:);
        end
        disp(['BST> Warning: Downsampling signals for display (keeping 1 value every ' num2str(PlotHandles.DownsampleFactor) ')']);
    end

    % ===== SWITCH DISPLAY MODE =====
    switch (lower(TsInfo.DisplayMode))
        case 'butterfly'
            PlotHandles = PlotAxesButterfly(iDS, hAxes, PlotHandles, TsInfo, TimeVector, F, isFastUpdate, Std);
        case 'column'
            PlotHandles = PlotAxesColumn(hAxes, PlotHandles, TsInfo, TimeVector, F, LinesLabels, isFastUpdate, Std);
        otherwise
            error('Invalid display mode.');
    end
    % Set specific line colors
    if ~isempty(LinesColor)
        for i = 1:nLines
            set(PlotHandles.hLines(i), 'Color', LinesColor(i,:));
            if ~isempty(PlotHandles.hLinePatches) && (i <= length(PlotHandles.hLinePatches))
                set(PlotHandles.hLinePatches(i), 'FaceColor', LinesColor(i,:));
            end
        end
    % Fast update: Restore initial line color and width
    elseif isFastUpdate && ~isempty(PlotHandles.LinesColor)
        LinesColor = PlotHandles.LinesColor;
        for i = 1:nLines
            set(PlotHandles.hLines(i), 'Color', PlotHandles.LinesColor(i,:), 'LineWidth', 0.5);
        end
    % Else: Get selected lines colors
    else
        LinesColor = get(PlotHandles.hLines, 'Color');
        if iscell(LinesColor)
            LinesColor = cat(1, LinesColor{:});
        end
    end
    % Get lines initial colors/labels
    PlotHandles.LinesColor = LinesColor;
    PlotHandles.LinesLabels = LinesLabels;

    % ===== LINES LEGENDS =====
    % Plotting the colors of the NIRS overlay montage
    if ~isFastUpdate && isequal(TsInfo.MontageName, 'NIRS overlay[tmp]') && (length(LinesLabels) > 2)
        % Get all lines that have the same label as the first one
        iLinesGroup = find(strcmpi(LinesLabels{1}, LinesLabels));
        % Get montage
        sMontage = panel_montage('GetMontage', TsInfo.MontageName);
        % Get groups in which each sensor belongs, to map group and color
        GroupNames = {};
        for i = 1:length(iLinesGroup)
            ChanName = sMontage.ChanNames{find(sMontage.Matrix(iLinesGroup(i),:), 1)};
            GroupNames{i} = GlobalData.DataSet(iDS).Channel(strcmpi(ChanName, {GlobalData.DataSet(iDS).Channel.Name})).Group;
        end
        % Create legend
        [hLegend, hLegendObjects] = legend(PlotHandles.hLines(iLinesGroup), strrep(GroupNames, '_', '-'));
    % Plotting the names of the channels
    elseif strcmpi(TsInfo.DisplayMode, 'butterfly') && ~isFastUpdate && ~isempty(LinesLabels) && TsInfo.ShowLegend && ((length(LinesLabels) > 1) || ~isempty(LinesLabels{1}))
        if (length(LinesLabels) == 1) && (length(PlotHandles.hLines) > 1)
            [hLegend, hLegendObjects] = legend(PlotHandles.hLines(1), strrep(LinesLabels{1}, '_', '-'));
        elseif (length(PlotHandles.hLines) == length(LinesLabels))
            [hLegend, hLegendObjects] = legend(PlotHandles.hLines, strrep(LinesLabels(:), '_', '-'));
        else
            disp('BST> Error: Number of legend entries do not match the number of lines. Ignoring...');
        end
    end
    
    % ===== TIME CURSOR =====
    % Plot time cursor (for non-static datasets)
    if (GlobalData.DataSet(iDS).Measures.NumberOfSamples > 2)
        ZData = 0.5;
        % Get current time
        curTime = GlobalData.UserTimeWindow.CurrentTime;
        YLim = get(hAxes, 'YLim');
        % Update cursor object
        if isFastUpdate && ~isempty(PlotHandles.hCursor) && ishandle(PlotHandles.hCursor)
            set(PlotHandles.hCursor, 'XData', [curTime, curTime], 'YData', YLim);
        % Create cursor object
        else
            % EraseMode: Only for Matlab <= 2014a 
            if (bst_get('MatlabVersion') <= 803)
                optErase = {'EraseMode', 'xor'};   % INCOMPATIBLE WITH OPENGL RENDERER (BUG), REMOVED IN MATLAB 2014b
            else
                %optErase = {'AlignVertexCenters', 'on'};
                optErase = {};
            end
            % Vertical line at t=CurrentTime
            PlotHandles.hCursor = line(...
                [curTime curTime], YLim, [ZData ZData], ...
                'LineWidth', 1, ...
                optErase{:}, ...
                'Color',     'r', ...
                'Tag',       'Cursor', ...
                'Parent',    hAxes);
        end
    end
    
    % ===== TIME LINES =====
    % Time-zero line
    if ~isFastUpdate && ((TimeVector(1) <= 0) && (TimeVector(end) >= 0))
        ZData = 1.1;
        Ymax = max(abs(get(hAxes,'YLim')));
        YData = [-1000, +1000] * Ymax; 
        hTimeZeroLine = line([0 0], YData, [ZData ZData], ...
                             'LineWidth', 1, ...
                             'LineStyle', '--', ...
                             'Color',     .8*[1 1 1], ...
                             'Tag',       'TimeZeroLine', ...
                             'Parent',    hAxes);
    end

    % ===== AXES GRIDS =====
    if TsInfo.ShowXGrid
        set(hAxes, 'XGrid',      'on', ...
                   'XMinorGrid', 'on');
    end
    if TsInfo.ShowYGrid && ~strcmpi(TsInfo.DisplayMode, 'column')
        set(hAxes, 'YGrid',      'on', ...
                   'YMinorGrid', 'on');
    end
    
    % ===== SHOW AXES =====
    set(hAxes, 'Interruptible', 'off', ...
               'BusyAction',    'queue', ...
               'Tag',           'AxesGraph', ...
               'XLim',       [TimeVector(1), TimeVector(end)], ...
               'Box',        'on', ...
               'FontName',   'Default', ...
               'FontUnits',  'Points', ...
               'FontWeight', 'Normal',...
               'FontSize',   bst_get('FigFont'), ...
               'Units',      'pixels', ...
               'Visible',    'on');
    % Remove the Tex interpreter
    if isprop(hAxes, 'TickLabelInterpreter')
        set(hAxes, 'TickLabelInterpreter', 'none');
    end
    % Set the axes label mode for the tick labels (never use exponential notation for time)
    if (bst_get('MatlabVersion') >= 806)
        hAxes.XAxis.Exponent = 0;
    end
end


%% ===== PLOT AXES BUTTERFLY =====
function PlotHandles = PlotAxesButterfly(iDS, hAxes, PlotHandles, TsInfo, TimeVector, F, isFastUpdate, Std)
    global GlobalData;
    ZData = 1.5;
  
    % ===== YLIM =====
    % Get data units
    Fmax = max(abs(PlotHandles.DataMinMax));
    [fScaled, fFactor, fUnits] = bst_getunits( Fmax, TsInfo.Modality, TsInfo.FileName);

    % Plot factor has changed
    isFactorChanged = ~isequal(fFactor, PlotHandles.DisplayFactor);
    if isFactorChanged
        GlobalData.DataSet(iDS).Measures.DisplayUnits = fUnits;
    end
    % Set display Factor
    PlotHandles.DisplayFactor = fFactor;
    PlotHandles.DisplayUnits  = fUnits;
    % Get automatic YLim
    if (Fmax ~= 0)
        % If data to plot are relative values
        if (PlotHandles.DataMinMax(1) < -eps) || ((PlotHandles.DataMinMax(1) < 0) && (PlotHandles.DataMinMax(2) <= eps))
            YLim = 1.05 * PlotHandles.DisplayFactor * [-Fmax, Fmax];
        % Otherwise: absolute values
        else
            YLim = 1.05 * PlotHandles.DisplayFactor * [0, Fmax];
        end
    else
        YLim = [-1, 1];
    end
    
    % ===== PLOT TIME SERIES =====
    % Plot lines
    if isFastUpdate
        for iLine = 1:length(PlotHandles.hLines)
            set(PlotHandles.hLines(iLine), ...
                'XData', TimeVector, ...
                'YData', F(iLine,:) * fFactor, ...
                'ZData', ZData * ones(size(TimeVector)));
        end
    % Update lines
    else
        PlotHandles.hLines = line(TimeVector, ...
                              F' * fFactor, ...
                              ZData * ones(size(F)), ...
                              'Parent', hAxes);
        set(PlotHandles.hLines, 'Tag', 'DataLine');
        PlotHandles.ChannelOffsets = zeros(size(F,1), 1);
        
        % ===== STD HALO =====
        % Plot Std as a transparent halo
        if ~isempty(Std) && ContainsDims(F, Std)
            % Check whether Std is an interval or a single value centered on the data
            stdIsInterval = ndims(Std) >= 4;
            % Get the colors of all the lines
            C = get(PlotHandles.hLines, 'Color');
            if ~iscell(C)
                C = {C};
            end
            % If all the colors are the same: plot only one big halo around the data
            if (length(C) > 5) || (length(C) > 1) && all(cellfun(@(c)isequal(C{1},c), C))
                % Upper and lower lines
                if stdIsInterval
                    Lhi  = max(Std(:,:,:,2), [], 1) .* fFactor;
                    Llow = min(Std(:,:,:,1), [], 1) .* fFactor;
                else
                    Lhi  = max(F + Std, [], 1) .* fFactor;
                    Llow = min(F - Std, [], 1) .* fFactor;
                end
                PlotHandles.hLinePatches = PlotHaloPatch(hAxes, TimeVector, Lhi, Llow, ZData - 0.001, C{1});
            else
                % Plot separately each patch
                for i = 1:size(Std,1)
                    % Upper and lower lines
                    if stdIsInterval
                        Lhi  = Std(i,:,:,2) .* fFactor;
                        Llow = Std(i,:,:,1) .* fFactor;
                    else
                        Lhi  = (F(i,:) + Std(i,:)) .* fFactor;
                        Llow = (F(i,:) - Std(i,:)) .* fFactor;
                    end
                    % Plot patch
                    PlotHandles.hLinePatches(i) = PlotHaloPatch(hAxes, TimeVector, Lhi, Llow, ZData - i*0.001, C{i});
                end
            end
        end
    end

    % ===== SET UP AXIS =====
    % Set axes legend for Y axis
    if ~isFastUpdate || isFactorChanged
        if ~isempty(GlobalData.DataSet(iDS).Measures.DisplayUnits)
            strAmp = GlobalData.DataSet(iDS).Measures.DisplayUnits;
            % Make it more readable
            if isequal(strAmp, 't')
                strAmp = 't-values';
            end
        elseif ~isempty(TsInfo.YLabel)
            strAmp = TsInfo.YLabel;
        elseif ~isempty(fUnits)
            strAmp = ['Amplitude (' fUnits ')'];
        else
            strAmp = 'Amplitude';
        end
        ylabel(hAxes, strAmp, ...
            'FontSize',    bst_get('FigFont'), ...
            'FontUnits',   'points', ...
            'Interpreter', 'tex');
    end
    % Set Y ticks in auto mode
    set(hAxes, 'YLim',           YLim, ...
               'YTickMode',      'auto', ...
               'YTickLabelMode', 'auto');
    % Set axis orientation
    if TsInfo.FlipYAxis
        set(hAxes, 'YDir', 'reverse');
    else
        set(hAxes, 'YDir', 'normal');
    end
    
%     % ===== LINES LEGENDS =====
%     THIS SECTION WAS MOVED TO BE AFTER THE CHANGE OF COLOR OF THE LINES 
%     (IF NOT MATLAB 2016a WAS NOT SETTING THE PROPERTIES PROPERLY)
%     % Only if less than a certain amount of lines
%     if ~isFastUpdate && ~isempty(LinesLabels) && TsInfo.ShowLegend && ((length(LinesLabels) > 1) || ~isempty(LinesLabels{1}))
%         if (length(LinesLabels) == 1) && (length(PlotHandles.hLines) > 1)
%             [hLegend, hLegendObjects] = legend(PlotHandles.hLines(1), LinesLabels{1});
%         elseif (length(PlotHandles.hLines) == length(LinesLabels))
%             [hLegend, hLegendObjects] = legend(PlotHandles.hLines, LinesLabels{:});
%         else
%             disp('BST> Error: Number of legend entries do not match the number of lines. Ignoring...');
%             hLegend = [];
%             hLegendObjects = [];
%         end
%         if ~isempty(hLegend)
%             set(findobj(hLegendObjects, 'Type', 'Text'), ...
%                 'FontSize',  bst_get('FigFont'), ...
%                 'FontUnits', 'points', ...
%                 'Interpreter', 'none');
%             set(hLegend, 'Tag', 'legend', 'Interpreter', 'none');
%         end
%     end
           
    % ===== EXTRA LINES =====
    % Y=0 Line
    if isFastUpdate && (length(PlotHandles.hLinesZeroY) == 1) && ishandle(PlotHandles.hLinesZeroY)
        set(PlotHandles.hLinesZeroY, 'XData', [TimeVector(1), TimeVector(end)]);
    else
        % Delete existing zero-lines (left from a previous 'Column' display)
        if ~isempty(PlotHandles.hLinesZeroY) && all(ishandle(PlotHandles.hLinesZeroY))
            delete(PlotHandles.hLinesZeroY);
            PlotHandles.hLinesZeroY = [];
        end
        % Create new lines
        if (YLim(1) == 0)
            color0 = [0 0 0];
        else
            color0 = .8*[1 1 1];
        end
        PlotHandles.hLinesZeroY = line([TimeVector(1), TimeVector(end)], [0 0], [0.5 0.5], 'Color', color0, 'Parent', hAxes);
    end
    
    % Decoding: Y=50%
    if ~isempty(strfind(TsInfo.FileName, 'matrix_decoding_')) && (all(F(:) >= 0) && all(F(:) <= 100))
        if isFastUpdate && (length(PlotHandles.hLineDecodingY) == 1) && ishandle(PlotHandles.hLineDecodingY)
            set(PlotHandles.hLineDecodingY, 'XData', [TimeVector(1), TimeVector(end)]);
        else
            % Delete existing Y=50 (left from a previous 'Column' display)
            if ~isempty(PlotHandles.hLineDecodingY) && all(ishandle(PlotHandles.hLineDecodingY))
                delete(PlotHandles.hLineDecodingY);
                PlotHandles.hLineDecodingY = [];
            end
            % Create new lines
            PlotHandles.hLineDecodingY = line([TimeVector(1), TimeVector(end)], [50 50], [0.5 0.5], ...
                'LineWidth', 1, ...
                'LineStyle', '--', ...
                'Color',     .8*[1 1 1], ...
                'Parent',    hAxes, ...
                'Tag',       'LineDecoding50');
        end
    end
    
    % ===== DISPLAY GFP =====
    % If there are more than 5 channel
    if bst_get('DisplayGFP') && ~strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'stat') ...
                             && (GlobalData.DataSet(iDS).Measures.NumberOfSamples > 2) && (size(F,1) > 5) ...
                             && ~isempty(TsInfo.Modality) && ismember(TsInfo.Modality, {'EEG','MEG','EEG','SEEG'})
        GFP = sqrt(sum((F * fFactor).^2, 1));
        PlotGFP(hAxes, TimeVector, GFP, TsInfo.FlipYAxis, isFastUpdate);
    end
end


%% ===== PLOT AXES: COLUMN =====
function PlotHandles = PlotAxesColumn(hAxes, PlotHandles, TsInfo, TimeVector, F, LinesLabels, isFastUpdate, Std)
    ZData = 1.5;
    nLines = size(F,1);
    iRowMap = (1:nLines)';
    nRows = nLines;
    
    % ===== GROUP CHANNELS BY NAME (NIRS OVERLAY) =====
    if ~strcmpi(TsInfo.Modality, 'results') && ~strcmpi(TsInfo.Modality, 'sloreta')
        % Find all the separators
        iSep = find(cellfun(@(c)isempty(strtrim(c)), LinesLabels));
        % Replace separator names with unique names, so that they are not overlayed in the same line
        if ~isempty(iSep)
            for i = 1:length(iSep)
                LinesLabels{iSep(i)} = sprintf('###%d', i);
            end
        end
        % Get unique line labels (keep the original order)
        [uniqueLabels,I] = unique(LinesLabels);
        I = sort(I);
        uniqueLabels = LinesLabels(I);
        nRows = length(uniqueLabels);
        % If there are duplicate names: overlay them on top on each other (for NIRS)
        if (nLines ~= nRows)
            for i = 1:nRows
                iRowMap(strcmpi(uniqueLabels{i}, LinesLabels)) = i;
            end
            % Use only one row per group of overlayed channels
            LinesLabels = uniqueLabels;
        end
        % Remove the separator temporary labels
        if ~isempty(iSep)
            iSep = find(~cellfun(@(c)isempty(strfind(c,'###')), LinesLabels));
            [LinesLabels{iSep}] = deal(' ');
        end
    end

    % ===== SPLIT IN BLOCKS =====
    % Normalized range of Y values
    YLim = [0, 1];
    % Data maximum
    Fmax = max(abs(PlotHandles.DataMinMax));
    % Subdivide Y-range in nDispChan blocks
    blockY = (YLim(2) - YLim(1)) / (nRows + 2);
    % Build an offset list for all channels 
    rowOffsets = blockY * (nRows:-1:1)' + blockY / 2;
    PlotHandles.ChannelOffsets = rowOffsets(iRowMap);
    % Normalize all channels to fit in one block only, and add previous display factor
    PlotHandles.DisplayFactor = blockY ./ Fmax .* TsInfo.DefaultFactor;
    % Apply final factor to recordings + Keep only the displayed lines
    F = F .* PlotHandles.DisplayFactor;
    if ~isempty(Std)
        Std = Std .* PlotHandles.DisplayFactor;
    end
    % Flip Y axis
    if TsInfo.FlipYAxis
        F = -F;
    end
    % Find channels that are only zeros
    isNullLines = ~any(F, 2);
    
    % ===== PLOT TIME SERIES =====
    % Add offset to each channel
    F = bst_bsxfun(@plus, F, PlotHandles.ChannelOffsets);
    % Update lines  (std: Force full update)
    if isFastUpdate && (length(PlotHandles.hLines) == nLines) && all(ishandle(PlotHandles.hLines))
        for iLine = 1:length(PlotHandles.hLines)
            set(PlotHandles.hLines(iLine), ...
                'XData', TimeVector, ...
                'YData', F(iLine,:), ...
                'ZData', ZData * ones(size(TimeVector)));
        end
    % Create lines
    else
        PlotHandles.hLines = line(TimeVector, F', ZData*ones(size(F)), 'Parent', hAxes);
        set(PlotHandles.hLines, 'Tag', 'DataLine');
        
        % ===== STD HALO =====
        % Plot Std as a transparent halo
        if ~isempty(Std) && (length(PlotHandles.hLines) < 50)
            % Check whether Std is an interval or a single value centered on the data
            stdIsInterval = ndims(Std) >= 4;
            if stdIsInterval
                % Add offset to each channel
                Std = bst_bsxfun(@plus, Std, PlotHandles.ChannelOffsets);
            end
            % Get the colors of all the lines
            C = get(PlotHandles.hLines, 'Color');
            if ~iscell(C)
                C = {C};
            end
            % Plot separately each patch
            for i = 1:size(Std,1)
                % Upper and lower lines
                if stdIsInterval
                    Lhi  = Std(i,:,:,2);
                    Llow = Std(i,:,:,1);
                else
                    Lhi  = (F(i,:) + Std(i,:));
                    Llow = (F(i,:) - Std(i,:));
                end
                % Plot patch
                PlotHandles.hLinePatches(i) = PlotHaloPatch(hAxes, TimeVector, Lhi, Llow, ZData - i*0.001, C{i});
            end
        end
    end
    % Hide the lines that are all zeros
    if any(isNullLines)
        set(PlotHandles.hLines(isNullLines), 'Visible', 'off');       
    end
    % Show all the other lines
    set(PlotHandles.hLines(~isNullLines), 'Visible', 'on');
    
    % ===== PLOT ZERO-LINES =====
    if TsInfo.ShowZeroLines
        % Lines coordinates
        Xzeros = repmat([TimeVector(1), TimeVector(end)], [nLines, 1]);
        Yzeros = [PlotHandles.ChannelOffsets, PlotHandles.ChannelOffsets];
        Zzeros = repmat(.5 * [1 1], [nLines, 1]);
        % Update lines
        if isFastUpdate && (length(PlotHandles.hLinesZeroY) == nLines) && all(ishandle(PlotHandles.hLinesZeroY))
            for iLine = 1:length(PlotHandles.hLinesZeroY)
                set(PlotHandles.hLinesZeroY(iLine), ...
                    'XData', Xzeros(iLine,:), ...
                    'YData', Yzeros(iLine,:), ...
                    'ZData', Zzeros(iLine,:));
            end
        else
            % Delete existing zero-line (left from a previous 'Butterfly' display)
            if ~isempty(PlotHandles.hLinesZeroY) && all(ishandle(PlotHandles.hLinesZeroY))
                delete(PlotHandles.hLinesZeroY);
                PlotHandles.hLinesZeroY = [];
            end
            % Create new line
            PlotHandles.hLinesZeroY = line(...
                Xzeros', Yzeros', Zzeros', ...
                'Color',  .9*[1 1 1], ...
                'Parent', hAxes);
        end
    end
    
    % ===== CHANNELS LABELS ======
    if ~isempty(LinesLabels)        
        % Special case: If scout function is "All" 
        if (length(nLines) > 1) && (length(LinesLabels) == 1)
            YtickLabel = [];
        else
            % Remove all the common parts of the labels
            YtickLabel = str_remove_common(LinesLabels);
            if ~isempty(YtickLabel)
                YtickLabel = LinesLabels;
            end
            % Scouts time series: remove everything after the @
            for iLabel = 1:numel(YtickLabel)
                iAt = find(YtickLabel{iLabel} == '@', 1);
                if ~isempty(iAt)
                    YtickLabel{iLabel} = strtrim(YtickLabel{iLabel}(1:iAt-1));
                end
            end
            % Limit the size of the comments to 15 characters
            YtickLabel = cellfun(@(c)c(max(1,length(c)-14):end), YtickLabel, 'UniformOutput', 0);
        end
        % Set Y Legend
        set(hAxes, 'YTickMode',      'manual', ...
                   'YTickLabelMode', 'manual', ...
                   'YTick',          bst_flip(rowOffsets,1), ...
                   'Yticklabel',     bst_flip(YtickLabel,1));
    end
    
    % Set Y axis scale (updating: keeping the zoom factor)
    if ~isFastUpdate
        set(hAxes, 'YLim', YLim);
    end
    % Set axis orientation
    set(hAxes, 'YDir', 'normal');
    % Remove axes legend for Y axis
    ylabel('');
end


%% ===== PLOT HALO PATCH =====
function hPatch = PlotHaloPatch(hAxes, Time, Yhi, Ylow, Z, C)
    % Create a closed polygon
    Time = [Time, bst_flip(Time,2)];
    Y    = [Yhi, bst_flip(Ylow,2)];
    Z    = Z * ones(size(Time));
    % Plot patch
    hPatch = patch(Time, Y, Z, C, ...
        'FaceAlpha', 0.1, ...
        'EdgeColor', 'none', ...
        'Parent',    hAxes, ...
        'Tag',       'StdPatch');
end


%% ===== PLOT GFP =====
function PlotGFP(hAxes, TimeVector, GFP, isFlipY, isFastUpdate)
    % Maximum of GFP
    maxGFP = max(GFP);
    if (maxGFP <= 0)
        return
    end
    % Get axes limits
    YLim = get(hAxes, 'YLim');
    % Make GFP displayable a the bottom of these axes
    GFP = GFP ./ maxGFP .* (YLim(2) - YLim(1)) .* 0.08 + YLim(1)*.95;
    maxGFP = double(max(GFP));
    % Flip if needed
    if isFlipY
        GFP = YLim(2) - GFP + YLim(1);
        maxGFP = YLim(2) - maxGFP + YLim(1);
    end
    % Coordinates
    XData = double(0.01*TimeVector(end) + .99*TimeVector(1));
    YData = maxGFP;
    ZData = 2;
    % Get existing objects
    hGFP = findobj(hAxes, 'Tag', 'GFP');
    hGFPTitle = findobj(hAxes, 'Tag', 'GFPTitle');
    % Update objects
    if isFastUpdate && ~isempty(hGFP) && ~isempty(hGFPTitle)
        set(hGFP, ...
            'XData', TimeVector, ...
            'YData', GFP', ...
            'ZData', ZData*ones(size(TimeVector)));
        set(hGFPTitle, 'Position', [XData, YData, ZData]);
    % Create objects
    else
        % Plot GFP line
        line(TimeVector, GFP', ZData*ones(size(TimeVector)), ...
            'Color',  [0 1 0], ...
            'Parent', hAxes, ...
            'Tag',    'GFP');
        % Display GFP text legend
        text(XData, YData, ZData, 'GFP',...
            'Horizontalalignment', 'left', ...
            'Color',        [0 1 0], ...
            'FontSize',     bst_get('FigFont') + 1, ...
            'FontWeight',   'bold', ...
            'FontUnits',    'points', ...
            'Tag',          'GFPTitle', ...
            'Interpreter',  'none', ...
            'Parent',       hAxes);
    end
end


%% ===== UPDATE SCALE BAR =====
function UpdateScaleBar(iDS, iFig, TsInfo)
    global GlobalData;
    % Get figure data
    PlotHandles = GlobalData.DataSet(iDS).Figure(iFig).Handles(1);
    Modality    = GlobalData.DataSet(iDS).Figure(iFig).Id.Modality;
    % Get scale bar
    if isempty(PlotHandles.hColumnScale)
        return
    end
    % Get axes zoom factor
    YLim = get(PlotHandles.hAxes, 'YLim');
    zoomFactor = YLim(2) - YLim(1);  % /(1-0)
    % Get data units
    Fmax = max(abs(PlotHandles.DataMinMax));
    [fScaled, fFactor, fUnits] = bst_getunits( Fmax, Modality, TsInfo.FileName );
    barMeasure = fScaled / TsInfo.DefaultFactor;
    % Get position where to plot the legend
    nChan = length(PlotHandles.hLines);
    centerOffset = PlotHandles.ChannelOffsets(min(2,nChan)) + 1/(nChan+2)/2;
    % Plot bar for the maximum amplitude
    xBar = .3;
    yBar = centerOffset + 1/(nChan+2) * [-0.5, 0.5] / zoomFactor;
    if (yBar(2) > 1)
        yBar = yBar - yBar(2) + 1;
    end
    lineX = [xBar,xBar; xBar-.1,xBar+.1; xBar-.1,xBar+.1]';
    lineY = [yBar(1),yBar(2); yBar(1),yBar(1); yBar(2),yBar(2)]';
    if ~isempty(PlotHandles.hColumnScaleBar) && all(ishandle(PlotHandles.hColumnScaleBar))
        delete(PlotHandles.hColumnScaleBar);
    end
    PlotHandles.hColumnScaleBar = line(lineX, lineY, ...
         'Color',   'k', ... 
         'Tag',     'ColumnScaleBar', ...
         'Parent',  PlotHandles.hColumnScale);
    % Plot data units
    if barMeasure < 10
      txtAmp = sprintf('%1.1f %s', barMeasure, fUnits);
    else
      txtAmp = sprintf('%d %s', round(barMeasure), fUnits);
    end
    if ~isempty(PlotHandles.hColumnScaleText) && ishandle(PlotHandles.hColumnScaleText)
        set(PlotHandles.hColumnScaleText, 'String', txtAmp);
    else
        % Scale text
        PlotHandles.hColumnScaleText = text(...
             .7, centerOffset, txtAmp, ...
             'FontSize',    bst_get('FigFont'), ...
             'FontUnits',   'points', ...
             'Color',       'k', ... 
             'Interpreter', 'tex', ...
             'HorizontalAlignment', 'center', ...
             'Rotation',    90, ...
             'Tag',         'ColumnScaleText', ...
             'Parent',      PlotHandles.hColumnScale);
    end
    % Update handles
    GlobalData.DataSet(iDS).Figure(iFig).Handles(1) = PlotHandles;
end


%% ===== CREATE SCALE BUTTON =====
function CreateScaleButtons(iDS, iFig)
    import org.brainstorm.icon.*;
    global GlobalData;
    % Get figure
    hFig  = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
    isRaw = strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'raw');
    TsInfo = getappdata(hFig, 'TsInfo');
    % Create buttons
    h1  = bst_javacomponent(hFig, 'button', [], [], IconLoader.ICON_SCROLL_LEFT, ...
        '<HTML><TABLE><TR><TD>Horizontal zoom out</TD></TR><TR><TD>Shortcut: [MOUSE WHEEL]</TD></TR></TABLE>', ...
        @(h,ev)FigureZoomLinked(hFig, 'horizontal', .9091), 'ButtonZoomTimeMinus');
    h2  = bst_javacomponent(hFig, 'button', [], [], IconLoader.ICON_SCROLL_RIGHT, ...
        '<HTML><TABLE><TR><TD>Horizontal zoom in</TD></TR><TR><TD>Shortcut: [MOUSE WHEEL]</TD></TR></TABLE>', ...
        @(h,ev)FigureZoomLinked(hFig, 'horizontal', 1.1), 'ButtonZoomTimePlus');
    h3  = bst_javacomponent(hFig, 'button', [], [], IconLoader.ICON_MINUS, ...
        '<HTML><TABLE><TR><TD>Decrease gain</TD></TR><TR><TD>Shortcuts:<BR><B> &nbsp; [-]<BR> &nbsp; [Right-click + Mouse down]</B></TD></TR></TABLE>', ...
        @(h,ev)UpdateTimeSeriesFactor(hFig, .9091), 'ButtonGainMinus');
    h4  = bst_javacomponent(hFig, 'button', [], [], IconLoader.ICON_PLUS, ...
        '<HTML><TABLE><TR><TD>Increase gain</TD></TR><TR><TD>Shortcuts:<BR><B> &nbsp; [+]<BR> &nbsp; [Right-click + Mouse up]</B></TD></TR></TABLE>', ...
        @(h,ev)UpdateTimeSeriesFactor(hFig, 1.1), 'ButtonGainPlus');
    h5  = bst_javacomponent(hFig, 'toggle', [], 'AS', [], ...
        'Auto-scale amplitude when changing page', ...
        @(h,ev)SetAutoScale(hFig, ev), 'ButtonAutoScale', TsInfo.AutoScaleY);
    h6  = bst_javacomponent(hFig, 'button', [], [], IconLoader.ICON_MENU_LEFT_TS, ...
        'Display configuration', @(h,ev)DisplayConfigMenu(hFig, ev), 'ButtonMenu');
    h7  = bst_javacomponent(hFig, 'button', [], [], IconLoader.ICON_SCROLL_UP, ...
        '<HTML><TABLE><TR><TD>Scroll up</TD></TR><TR><TD><B> &nbsp; [Right+left click + Mouse up]<BR> &nbsp; [Middle click + Mouse up]</B></TD></TR></TABLE>', ...
        @(h,ev)FigurePan(hFig, [0, -.9]), 'ButtonZoomUp');
    h8  = bst_javacomponent(hFig, 'button', [], [], IconLoader.ICON_ZOOM_PLUS, ...
        '<HTML><TABLE><TR><TD>Vertical zoom in</TD></TR><TR><TD><B> &nbsp; [CTRL + MOUSE WHEEL]</B></TD></TR></TABLE>', ...
        @(h,ev)FigureZoom(hFig, 'vertical', 1.3, 0), 'ButtonZoomPlus');
    h9  = bst_javacomponent(hFig, 'button', [], [], IconLoader.ICON_ZOOM_MINUS, ...
        '<HTML><TABLE><TR><TD>Vertical zoom out</TD></TR><TR><TD><B> &nbsp; [CTRL + MOUSE WHEEL]</B></TD></TR></TABLE>', ...
        @(h,ev)FigureZoom(hFig, 'vertical', .7692, 0), 'ButtonZoomMinus');
    h10 = bst_javacomponent(hFig, 'button', [], [], IconLoader.ICON_SCROLL_DOWN, ...
        '<HTML><TABLE><TR><TD>Scroll down</TD></TR><TR><TD><B> &nbsp; [Right+left click + Mouse down]<BR> &nbsp; [Middle click + Mouse down]</B></TD></TR></TABLE>', ...
        @(h,ev)FigurePan(hFig, [0, .9]), 'ButtonZoomDown');
    % Visible / not visible
    if isRaw
        set([h1 h2], 'Visible', 'off');
    end
    if (isempty(TsInfo) || isempty(TsInfo.FileName) || ~ismember(file_gettype(TsInfo.FileName), {'data','matrix'}) || strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'stat'))
        set(h5, 'Visible', 'off');
    end
    if isempty(TsInfo) || ~strcmpi(TsInfo.DisplayMode, 'column') || ~strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.Type, 'DataTimeSeries')
        set([h7 h8 h9 h10], 'Visible', 'off');
    end
end


%% ===== SET SCALE ====
% Change manually the scale of the data
% USAGE: SetScaleY(iDS, iFig, newScale)
%        SetScaleY(iDS, iFig)            : New scale is asked to the user
function SetScaleY(iDS, iFig, newScale)
    global GlobalData;
    % Parse input
    if (nargin < 3) || isempty(newScale)
        newScale = [];
    end
    % Get figure handles
    PlotHandles = GlobalData.DataSet(iDS).Figure(iFig).Handles(1);
    Modality    = GlobalData.DataSet(iDS).Figure(iFig).Id.Modality;
    hFig        = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
    TsInfo      = getappdata(hFig, 'TsInfo');
    % Check the auto-scale property
    if TsInfo.AutoScaleY && strcmpi(TsInfo.DisplayMode, 'butterfly')
        % Disable the auto-scale button
        SetAutoScale(hFig, 0);
    end
    % Get maximum
    bst_progress('start', 'Display mode', 'Getting maximum value...');
    drawnow;
    % Get units
    Fmax = max(abs(PlotHandles.DataMinMax));
    [fScaled, fFactor, fUnits] = bst_getunits( Fmax, Modality, TsInfo.FileName );
    strUnits = strrep(fUnits, '\mu', '&mu;');
    
    % Columns
    if strcmpi(TsInfo.DisplayMode, 'column')
        % Get current scale
        oldScale = round(fScaled / TsInfo.DefaultFactor);
        % If new scale not provided: ask the user
        if isempty(newScale)
            newScale = java_dialog('input', ['<HTML>Enter the amplitude scale (' strUnits '):'], 'Set scale', [], num2str(oldScale));
            if isempty(newScale)
                bst_progress('stop');
                return
            end
            newScale = str2num(newScale);
            if isempty(newScale) || (newScale <= 0)
                bst_error('Invalid value', 'Set scale', 0);
                bst_progress('stop');
                return;
            end
        end
        % If no changes: exit
        if (newScale == oldScale)
            bst_progress('stop');
            return
        end
        % Update figure with new display factor
        UpdateTimeSeriesFactor(hFig, oldScale / newScale);
    % Butterfly
    else
        % Get current scale
        hAxes = findobj(hFig, 'tag', 'AxesGraph');
        YLim = get(hAxes(1), 'YLim');
        % If new scale not provided: ask the user
        if isempty(newScale)
            newScale = java_dialog('input', ['<HTML>Enter the maximum (' strUnits '):'], 'Set maximum', [], num2str(max(YLim)));
            if isempty(newScale)
                bst_progress('stop');
                return
            end
            newScale = str2num(newScale);
            if isempty(newScale) || (newScale <= 0)
                bst_error('Invalid value', 'Set maximum', 0);
                bst_progress('stop');
                return;
            end
        end
        % Update scale
        if (newScale ~= max(YLim)) && (newScale ~= 0)
            if (YLim(1) == 0)
                newYLim = [0, newScale];
            else
                newYLim = [-newScale, newScale];
            end
            %set(hAxes, 'YLim', newYLim);
            newMinMax = newYLim / fFactor;
            [GlobalData.DataSet(iDS).Figure(iFig).Handles.DataMinMax] = deal(newMinMax / 1.05);
            % Update figure
            PlotFigure(iDS, iFig);
        end
    end
    % Save imposed scale value (raw files only)
    if ~isempty(Modality) && ~isempty(newScale) && strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'raw')
        bst_set('FixedScaleY', [Modality, TsInfo.DisplayMode], newScale);
    end
    % Close progress bar
    drawnow;
    bst_progress('stop');
end


%% ===== SET X-SCALE MODE =====
function SetScaleModeX(hFig, newMode)
    TsInfo = getappdata(hFig, 'TsInfo');
    TsInfo.XScale = newMode;
    hAxes = findobj(hFig, '-depth', 1, 'tag', 'AxesGraph');
    set(hAxes, 'XScale', newMode);
    setappdata(hFig, 'TsInfo', TsInfo);
    % Update preferred value
    bst_set('XScale', newMode);
end

%% ===== SET Y-SCALE MODE =====
function SetScaleModeY(hFig, newMode)
    [Handles, iFig, iDS] = bst_figures('GetFigureHandles', hFig);
    % Prevent log scale for data that's already log (dB), or negative.
    if ~isempty(Handles) && Handles.DataMinMax(1) < 0
        newMode = 'linear';
    else
        % Update preferred value
        bst_set('YScale', newMode);
    end
    hAxes = findobj(hFig, '-depth', 1, 'tag', 'AxesGraph');
    set(hAxes, 'YScale', newMode);
    TsInfo = getappdata(hFig, 'TsInfo');
    TsInfo.YScale = newMode;
    setappdata(hFig, 'TsInfo', TsInfo);
    % Readjust y scale limits.
    ScaleToFitY(hFig);
end


%% ===== SET NORMALIZE AMPLITUDE =====
function SetNormalizeAmp(iDS, iFig, NormalizeAmp)
    global GlobalData;
    % Update value
    hFig = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
    TsInfo = getappdata(hFig, 'TsInfo');
    TsInfo.NormalizeAmp = NormalizeAmp;
    setappdata(hFig, 'TsInfo', TsInfo);
    % Reset maximum values
    GlobalData.DataSet(iDS).Figure(iFig).Handles(1).DataMinMax = [];
    % Re-plot figure
    PlotFigure(iDS, iFig);
end


%% ===== SET NORMALIZE AMPLITUDE =====
function SetDisplayGFP(hFig, DisplayGFP)
    % Update value
    bst_set('DisplayGFP', DisplayGFP);
    % Re-plot figure
    bst_figures('ReloadFigures', hFig, 0);
end


%% ===== SET FIXED RESOLUTION =====
function SetResolution(iDS, iFig, newResX, newResY)
    global GlobalData;
    % Parse inputs
    if (nargin < 4)
        newResX = [];
        newResY = [];
    end
    % Get current figure structure
    Figure = GlobalData.DataSet(iDS).Figure(iFig);
    hFig = Figure.hFigure;
    TsInfo = getappdata(hFig, 'TsInfo');
    hAxes = findobj(hFig, 'Tag', 'AxesGraph');
    Position = get(hAxes, 'Position');
    isRaw = strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'raw');
     % Get units
    Fmax = max(abs(Figure.Handles.DataMinMax));
    [fScaled, fFactor, fUnits] = bst_getunits( Fmax, Figure.Id.Modality, TsInfo.FileName );
    strUnits = strrep(fUnits, '\mu', '&mu;');
    % Get current time resolution
    XLim = get(hAxes, 'XLim');
    curResX = Position(3) / (XLim(2)-XLim(1));
    % Get current amplitude resolution
    if strcmpi(TsInfo.DisplayMode, 'butterfly')
        YLim = get(hAxes, 'YLim');
        curResY = (YLim(2)-YLim(1)) / Position(4);
    else
        nChan = length(Figure.Handles.hLines);
        interLines = fScaled / Fmax / Figure.Handles.DisplayFactor / 4 * (nChan+2);  % Distance between two lines * number of inter-lines, in units
        curResY = interLines / Position(4);
    end
    % Get default resolution values
    oldResolution = bst_get('Resolution');
    Resolution = oldResolution;
    % Default values
    if (TsInfo.Resolution(1) ~= 0)
        defResX = num2str(TsInfo.Resolution(1));
    elseif (Resolution(1) ~= 0)
        defResX = num2str(Resolution(1));
    else
        defResX = '';
    end
    if (TsInfo.Resolution(2) ~= 0)
        defResY = num2str(TsInfo.Resolution(2));
    elseif (Resolution(2) ~= 0)
        defResY = num2str(Resolution(2));
    else
        defResY = '';
    end
    % Ask the new resolutions
    if isempty(newResX) && isempty(newResY)
        res = java_dialog('input', {['<HTML>Time resolution in pixels/second:     [current=' num2str(round(curResX)) ']<BR><FONT color="#555555">   1mm/s ~ 3px/s'], ...
                                    ['<HTML>Amplitude resolution in ' strUnits '/pixel:     [current=' num2str(curResY, '%1.2f') ']<BR><FONT color="#555555">   1' strUnits '/mm ~ 0.33' strUnits '/px']}, ...
                                    'Set axes resolution', [], ...
                                    {defResX, defResY});
        if isempty(res) || (length(res) ~= 2)
            return
        end
        newResX = str2num(res{1});
        newResY = str2num(res{2});
    end
    % Changing the time resolution of the figure
    if (length(newResX) == 1) && (newResX ~= TsInfo.Resolution(1)) && (newResX > 0)
        % Raw viewer: try to change the displayed time segment
        if isRaw
            % Change time length
            timeLength = Position(3) / newResX;
            panel_record('SetTimeLength', timeLength);
            % Update XLim after update of the figure
            hAxes = findobj(hFig, 'Tag', 'AxesGraph');
            XLim = get(hAxes, 'XLim');
            curResX = Position(3) / (XLim(2)-XLim(1));
        end
        % If there is more than a certain error between requested and current resolutions: Resize figure
        if (abs(curResX - newResX) / newResX > 0.02)
            % Get figure position and the difference between the size of the axes and the size of the figure
            PosFig = get(hFig, 'Position');
            Xdiff = PosFig(3) - Position(3);
            % Change figure size
            PosFig(3) = round((XLim(2)-XLim(1)) * newResX) + Xdiff;
            set(hFig, 'Position', PosFig);
        end
        % Save resolution modification
        Resolution(1) = newResX;
    else
        Resolution(1) = 0;
    end
    % Changing the amplitude resolution
    if (length(newResY) == 1) && (newResY ~= TsInfo.Resolution(2)) && (newResY > 0)
        % Butterfly: Update DataMinMax
        if strcmpi(TsInfo.DisplayMode, 'butterfly')
            newLength = Position(4) * newResY;
            if (YLim(1) == 0)
                newMinMax = [0, newLength] / fFactor;
            else
                newMinMax = [-newLength, newLength] / 2 / fFactor;
            end
            [GlobalData.DataSet(iDS).Figure(iFig).Handles.DataMinMax] = deal(newMinMax / 1.05);
            % Disable AutoScaleY
            if TsInfo.AutoScaleY
                TsInfo.AutoScaleY = 0;
                setappdata(hFig, 'TsInfo', TsInfo);
            end
            % Update figure
            PlotFigure(iDS, iFig);
        % Column: Update DisplayFactor
        else
            changeFactor = curResY / newResY;
            UpdateTimeSeriesFactor(hFig, changeFactor);
        end
        % Save resolution modification
        Resolution(2) = newResY;
    else
        Resolution(2) = 0;
    end
    % Save modifications in user preferences
    if ~isequal(Resolution, oldResolution)
        bst_set('Resolution', Resolution);
    end
end


%% ===== SET AUTO SCALE =====
function SetAutoScale(hFig, isAutoScale)
    % If passed event structure (callback function): get calling object status
    if isa(isAutoScale, 'matlab.ui.eventdata.ActionData')
        isAutoScale = get(isAutoScale.Source, 'Value');
    elseif isa(isAutoScale, 'java.awt.event.ActionEvent')
        isAutoScale = isAutoScale.getSource().isSelected();
    end
    % Update status of figure button 
    hButtonAutoScale = findobj(hFig, 'Tag', 'ButtonAutoScale');
    if ~isempty(hButtonAutoScale)
        if isa(hButtonAutoScale, 'matlab.ui.control.UIControl')
            set(hButtonAutoScale, 'Value', isAutoScale);
        else
            jButton = get(hButtonAutoScale, 'JavaPeer');
            jButton.setSelected(isAutoScale);
        end
    end
    % Save preference
    bst_set('AutoScaleY', isAutoScale);
    bst_set('FixedScaleY', []);
    % Display progress bar
    bst_progress('start', 'Display mode', 'Updating figures...');
    % Update figure structure
    TsInfo = getappdata(hFig, 'TsInfo');
    TsInfo.AutoScaleY = isAutoScale;
    setappdata(hFig, 'TsInfo', TsInfo);
    % Re-plot figure
    bst_figures('ReloadFigures', hFig);
    % Hide progress bar
    bst_progress('stop');
end

%% ===== RESCALE SPECTRUM AMPLITUDE =====
function ScaleToFitY(hFig, ev)
    TsInfo = getappdata(hFig, 'TsInfo');
    % Only for butterfly display mode
    if isempty(TsInfo) || ~strcmpi(TsInfo.DisplayMode, 'butterfly')
        return;
    end
    % Get figure data
    FigureId = getappdata(hFig, 'FigureId');
    isSpectrum = strcmpi(FigureId.Type, 'spectrum');
    [PlotHandles, iFig, iDS] = bst_figures('GetFigureHandles', hFig);
    hAxes = PlotHandles.hAxes;
    % Get initial YLim
    YLimInit = getappdata(hAxes(1), 'YLimInit');

    % ===== GET DATA =====
    if isSpectrum
        isBands = false;
        % Get data to plot
        switch lower(FigureId.SubType)
            case 'timeseries'
                [XVector, Freq, TfInfo, TF] = figure_timefreq('GetFigureData', hFig);
            otherwise %case 'spectrum'
                [Time, XVector, TfInfo, TF] = figure_timefreq('GetFigureData', hFig, 'CurrentTimeIndex');
                % Frequency bands (cell array of named bands): Compute center of each band
                if iscell(XVector)
                    isBands = true;
                    % Multiple frequency bands
                    if (size(XVector,1) > 1)
                        XVector = mean(process_tf_bands('GetBounds', XVector), 2)';
                    % One frequency band: replicate data on both ends of the band
                    else
                        XVector = XVector{2};
                        TF = cat(3, TF, TF);
                    end
                % Remove the first frequency bin (0)
                elseif (size(TF,3)>2)
                    iZero = find(XVector == 0);
                    if ~isempty(iZero)
                        XVector(iZero) = [];
                        TF(:,:,iZero) = [];
                    end
                end
                % Redimension TF according to what we want to display
                TF = reshape(TF(:,1,:), [size(TF,1), size(TF,3)]);
        end
    else
        TF = GetFigureData(iDS, iFig);
        TF = TF{1};
        [XVector, iTime] = bst_memory('GetTimeVector', iDS, [], 'UserTimeWindow');
        XVector = XVector(iTime);
    end
    
    % Get limits of currently plotted data
    XLim = get(hAxes, 'XLim');    
    % For linear y axis spectrum, ignore very low frequencies with high amplitudes. Use the first local maximum
    if isSpectrum && ~isequal(lower(FigureId.SubType), 'timeseries') && ~isBands && ...
            any(strcmpi(TfInfo.Function, {'power', 'magnitude'})) && strcmpi(TsInfo.YScale, 'linear') && all(TF(:)>=0)
        TFmax = max(TF,[],1);
        iStartMin = find(diff(TFmax)>0,1);
        if isempty(iStartMin)
            iStartMin = 1;
        end
    else
        iStartMin = 1;
    end
    [val, iStart] = min(abs(XVector - XLim(1)));
    iStart = max(iStartMin, iStart);
    [val, iEnd] = min(abs(XVector - XLim(2)));
    curTF = TF(:, iStart:iEnd);
    isYLog = strcmpi(TsInfo.YScale, 'log');
    if isYLog
        YLim = [min(curTF(:)), max(curTF(:))] * PlotHandles.DisplayFactor;
        if YLim(1) <= 0
            YLim(1) = min(curTF(curTF(:)>0)) * PlotHandles.DisplayFactor;
        end
        YLim = log10(YLim);
    else
        YLim = [min(curTF(:)), max(curTF(:))] * PlotHandles.DisplayFactor;
    end
    % Add 5% margin above and below
    YSpan = YLim(2) - YLim(1);
    YLim(1) = YLim(1) - YSpan * 0.05;
    YLim(2) = YLim(2) + YSpan * 0.05;
    if isYLog
        YLim = 10.^YLim;
    end
    % Respect data limits
    if isSpectrum 
        if ~isempty(YLimInit) && YLimInit(1) ~= YLimInit (2)
            YLim(1) = max(YLim(1), YLimInit(1));
            YLim(2) = min(YLim(2), YLimInit(2));
        elseif PlotHandles.DataMinMax(1) ~= PlotHandles.DataMinMax(2)
            YLim(1) = max(YLim(1), PlotHandles.DataMinMax(1) * PlotHandles.DisplayFactor);
            YLim(2) = min(YLim(2), PlotHandles.DataMinMax(2) * PlotHandles.DisplayFactor);
        end
    end
    % Catch exceptions
    if YLim(1) == YLim (2)
        if ~isempty(YLimInit) && YLimInit(1) ~= YLimInit (2)
            YLim = YLimInit;
        elseif PlotHandles.DataMinMax(1) ~= PlotHandles.DataMinMax(2)
            YLim = PlotHandles.DataMinMax;
        else
            YLim = [-1, 1];
        end
    end
    
    % Rescale axis
    set(hAxes, 'YLim', YLim);
    % Update TimeCursor position
    hCursor = findobj(hAxes, '-depth', 1, 'Tag', 'Cursor');
    set(hCursor, 'YData', YLim);
    % Update selection patches
    hTimeSelectionPatch = findobj(hAxes, '-depth', 1, 'Tag', 'TimeSelectionPatch');
    if ~isempty(hTimeSelectionPatch)
        set(hTimeSelectionPatch, 'YData', [YLim(1), YLim(1), YLim(2), YLim(2)]);
    else % Check for spectrum selection patch
        hSelectionPatch = findobj(hAxes, '-depth', 1, 'Tag', 'SelectionPatch');
        if ~isempty(hSelectionPatch)
            set(hSelectionPatch, 'YData', [YLim(1), YLim(1), YLim(2), YLim(2)]);
        end
    end
    
end


%% ===== SET DISPLAY MODE =====
function SetDisplayMode(hFig, newMode)
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Record'); 
    if isempty(ctrl)
        return;
    end
    % Select button accordingly
    switch (newMode)
        case 'butterfly',   ctrl.jButtonDispMode.setSelected(0);
        case 'column',      ctrl.jButtonDispMode.setSelected(1);
    end
    % Update figure
    panel_record('SetDisplayMode', hFig, newMode);
end


%% ===== COPY DISPLAY OPTIONS =====
function CopyDisplayOptions(hFig, isMontage, isOptions)
    % Progress bar
    bst_progress('start', 'Copy display options', 'Updating figures...');
    % Get figure info
    TsInfoSrc = getappdata(hFig, 'TsInfo');
    % Get all figures
    hAllFigs = bst_figures('GetFiguresByType', {'DataTimeSeries', 'ResultsTimeSeries'});
    hAllFigs = setdiff(hAllFigs, hFig);
    % Process all figures
    for i = 1:length(hAllFigs)
        isModified = 0;
        % Get target figure info
        TsInfoDest = getappdata(hAllFigs(i), 'TsInfo');
        % Set montage
        if isMontage && ~isequal(TsInfoSrc.MontageName, TsInfoDest.MontageName)
            TsInfoDest.MontageName = TsInfoSrc.MontageName;
            isModified = 1;
        end
        % Set other options
        if isOptions && (~isequal(TsInfoSrc.DisplayMode, TsInfoDest.DisplayMode) || ~isequal(TsInfoSrc.FlipYAxis, TsInfoDest.FlipYAxis) || ~isequal(TsInfoSrc.NormalizeAmp, TsInfoDest.NormalizeAmp))
            TsInfoDest.DisplayMode  = TsInfoSrc.DisplayMode;
            TsInfoDest.FlipYAxis    = TsInfoSrc.FlipYAxis;
            TsInfoDest.NormalizeAmp = TsInfoSrc.NormalizeAmp;
            isModified = 1;
        end
        % Reload figure
        if isModified
            setappdata(hAllFigs(i), 'TsInfo', TsInfoDest);
            bst_figures('ReloadFigures', hAllFigs(i), 0);
        end
    end
    bst_progress('stop');
end


%% ===========================================================================
%  ===== RAW VIEWER FUNCTIONS ================================================
%  ===========================================================================
%% ===== PLOT RAW TIME BAR =====
function PlotRawTimeBar(iDS, iFig)
    global GlobalData;
    % Get the full time window
    iEpoch = GlobalData.FullTimeWindow.CurrentEpoch;
    if isempty(iEpoch)
        return
    end
    FullTime = GlobalData.FullTimeWindow.Epochs(iEpoch).Time([1, end]);
    TimeBar = FullTime + [-1, +1].*GlobalData.DataSet(iDS).Measures.SamplingRate;
    % Get figure handles
    hFig        = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
    hRawTimeBar = findobj(hFig, '-depth', 1, 'Tag', 'AxesRawTimeBar');
    % If time bar not create yet
    if isempty(hRawTimeBar)
        %figure(hFig);
        set(0, 'CurrentFigure', hFig);
        % Get figure background color
        bgColor = get(hFig, 'Color');
        % Time bar: Create axes
        hRawTimeBar = axes('Position', [0, 0, .01, .01]);
        set(hRawTimeBar, ...
             'Interruptible', 'off', ...
             'BusyAction',    'queue', ...
             'Tag',           'AxesRawTimeBar', ...
             'YGrid',      'off', ...
             'XGrid',      'off', ...
             'XMinorGrid', 'off', ...
             'XTick',      [], ...
             'YTick',      [], ...
             'TickLength', [0,0], ...
             'Color',      [.9 .9 .9], ...
             'XLim',       TimeBar, ...
             'YLim',       [0 1], ...
             'Box',        'off');
        % Check if buttons already exist
        if isempty(findobj(hFig, 'Tag', 'ButtonForward'))
            % Callbacks: If full epoch is shown, and there are epochs => Next epoch
            if (length(GlobalData.FullTimeWindow.Epochs) > 1) && isequal(GlobalData.UserTimeWindow.Time, FullTime)
                keyNext = 'epoch+';
                keyPrev = 'epoch-';
            % Else: go to next page
            else
                keyNext.Key = 'rightarrow';
                keyNext.Modifier = {'control'};
                keyPrev.Key = 'leftarrow';
                keyPrev.Modifier = {'control'};
            end
            % Tooltips: Different shortcuts on MacOS
            if strncmp(computer,'MAC',3)
                tooltipNext = '<HTML><TABLE><TR><TD>Next page</TD></TR><TR><TD>Related shortcuts:<BR><B> - [CTRL+SHIFT+ARROW RIGHT]<BR> - [SHIFT+ARROW UP]<BR> - [Fn+F3]</B></TD></TR> <TR><TD>Slower data scrolling:<BR><B> - [Fn+F4]</B> : Half page</TD></TR></TABLE>';
                tooltipPrev = '<HTML><TABLE><TR><TD>Previous page</TD></TR><TR><TD>Related shortcuts:<BR><B> - [CTRL+SHIFT+ARROW LEFT]<BR> - [SHIFT+ARROW DOWN]<BR> - [SHIFT+Fn+F3]</B></TD></TR> <TR><TD>Slower data scrolling:<BR><B> - [SHIFT+Fn+F4]</B> : Half page</TD></TR></TABLE>';
            else
                tooltipNext = '<HTML><TABLE><TR><TD>Next page</TD></TR> <TR><TD>Related shortcuts:<BR><B> - [CTRL+ARROW RIGHT]<BR> - [SHIFT+ARROW UP]<BR> - [F3]</B></TD></TR> <TR><TD>Other scrolling options:<BR><B> - [F4]</B> : Half page<BR><B> - [F6]</B> : Full page with no overlap<BR><B> - [CTRL+PAGE UP]</B>: +10 pages</TD></TR></TABLE>';
                tooltipPrev = '<HTML><TABLE><TR><TD>Previous page</TD></TR> <TR><TD>Related shortcuts:<BR><B> - [CTRL+ARROW LEFT]<BR> - [SHIFT+ARROW DOWN]<BR> - [SHIFT+F3]</B></TD></TR> <TR><TD>Other scrolling options:<BR><B> - [SHIFT+F4]</B> : Half page<BR><B> - [SHIFT+F6]</B> : Full page with no overlap<BR><B> - [CTRL+PAGE DOWN]</B>: -10 pages</TD></TR></TABLE>'; 
            end
            % Create buttons
            bst_javacomponent(hFig, 'button', [], '>>>', [], tooltipNext, ...
                @(h,ev)panel_time('TimeKeyCallback', keyNext), 'ButtonForward');
            bst_javacomponent(hFig, 'button', [], '<<<', [], tooltipPrev, ...
                @(h,ev)panel_time('TimeKeyCallback', keyPrev), 'ButtonBackward');
            bst_javacomponent(hFig, 'button', [], '<<<', [], tooltipPrev, ...
                @(h,ev)panel_time('TimeKeyCallback', keyPrev), 'ButtonBackward2');
        end
        % Plot events dots on the raw time bar
        PlotEventsDots_TimeBar(hFig);
    end
    % Update raw time position
    UpdateRawTime(hFig);
end    
        

%% ===== UPDATE RAW EVENTS XLIM =====
function UpdateRawXlim(hFig, XLim)
    % Parse inputs
    if (nargin < 2) || isempty(XLim)
        hAxes = findobj(hFig, '-depth', 1, 'Tag', 'AxesGraph');
        XLim = get(hAxes(1), 'XLim');
    end
    % RAW: Set the time limits of the events bar
    hEventsBar = findobj(hFig, '-depth', 1, 'Tag', 'AxesEventsBar');
    if ~isempty(hEventsBar)
        set(hEventsBar, 'XLim', XLim);
    end
end


%% ===== UPDATE RAW TIME POSITION =====
function UpdateRawTime(hFig)
    global GlobalData;
    % Get raw time bar handle
    hRawTimeBar = findobj(hFig, '-depth', 1, 'Tag', 'AxesRawTimeBar');
    hEventsBar  = findobj(hFig, '-depth', 1, 'Tag', 'AxesEventsBar');
    if isempty(hRawTimeBar) || isempty(hEventsBar)
        return
    end
    % Get user time window
    Time = GlobalData.UserTimeWindow.Time;
    % Get user time band
    hUserTime = findobj(hRawTimeBar, '-depth', 1, 'tag', 'UserTime');
    % If not create yet: create it
    if isempty(hUserTime)
        % EraseMode: Only for Matlab <= 2014a
        if (bst_get('MatlabVersion') <= 803)
            optErase = {'EraseMode',  'xor', ...   % INCOMPATIBLE WITH OPENGL RENDERER (BUG), REMOVED IN MATLAB 2014b
                        'EdgeColor', 'None'};
        else
            optErase = {'EdgeColor',  [.8 0 0]};
        end
        % Create selection patch
        hUserTime = patch('XData', [Time(1), Time(2), Time(2), Time(1)], ...
                          'YData', [.01 .01 .99 .99], ...
                          'ZData', 1.1 * [1 1 1 1], ...
                          'LineWidth', 0.5, ...
                          optErase{:}, ...
                          'FaceColor', [1 .3 .3], ...
                          'FaceAlpha', 1, ...
                          'EdgeAlpha', 1, ...
                          'Tag',       'UserTime', ...
                          'Parent',    hRawTimeBar);
    % Else just edit the position of the bar
    else
        set(hUserTime, 'XData', [Time(1), Time(2), Time(2), Time(1)]);
    end
    % Set the time limits of the events bar
    set(hEventsBar, 'XLim', Time);
    % Update events markers+labels in the events bar
    PlotEventsDots_EventsBar(hFig);
end


%% ===== PLOT EVENTS DOTS: TIME BAR =====
function PlotEventsDots_TimeBar(hFig)
    % Get raw time bar
    hRawTimeBar = findobj(hFig, '-depth', 1, 'Tag', 'AxesRawTimeBar');
    if isempty(hRawTimeBar)
        return
    end
    % Clear axes from previous objects
    cla(hRawTimeBar);
    % Get the raw events and time axes
    events = panel_record('GetEvents');
    % Loop on all the events types
    for iEvt = 1:length(events)
        % If event is hidden
        if isequal(events(iEvt).select, 0)
            continue;
        end
        % No occurrences: nothing to draw
        nOccur = size(events(iEvt).times, 2);
        if (nOccur == 0)
            continue;
        end
        % Get event color
        if panel_record('IsEventBad', events(iEvt).label)
            color = [1 0 0];
        elseif isfield(events(iEvt), 'color') && ~isempty(events(iEvt).color)
            color = events(iEvt).color;
        else
            color = [0 1 0];
        end
        % Each event corresponds to one "line" of dots in the bar
        XData = events(iEvt).times;
        YData = repmat(.1 + .9*(iEvt-1)/length(events) * ones(1,nOccur), size(events(iEvt).times, 1), 1);
        ZData = 1 * ones(size(XData));
        % Simple events
        if (size(events(iEvt).times, 1) == 1)
            LineStyle = 'none';
            Marker = '.';
        % Extended events
        elseif (size(events(iEvt).times, 1) == 2)
            LineStyle = '-';
            Marker = 'none';
        end
        % Time bar: Plot all occurrences in the same line object
        hEvtTime = line(XData, YData, ZData, ...
            'LineStyle',       LineStyle, ...
            'LineWidth',       1.5, ...
            'Color',           color, ...
            'MarkerFaceColor', color, ...
            'MarkerEdgeColor', color, ...
            'MarkerSize',      6, ...
            'Marker',          Marker, ...
            'Tag',             'EventBarDots', ...
            'UserData',        iEvt, ...
            'Parent',          hRawTimeBar);
    end
end



%% ===== PLOT EVENTS DOTS: EVENTS BAR =====
function PlotEventsDots_EventsBar(hFig)
    global GlobalData;
    % Get events bar
    hEventsBar = findobj(hFig, '-depth', 1, 'Tag', 'AxesEventsBar');
    if isempty(hEventsBar)
        return
    end
    % Clear axes from previous objects
    cla(hEventsBar);
    
    % Get time series axes
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'AxesGraph');
    YLim = get(hAxes, 'YLim');
    % Get previous event markers
    hEventObj = [findobj(hAxes, '-depth', 1, 'Tag', 'EventDots'); ...
                 findobj(hAxes, '-depth', 1, 'Tag', 'EventDotsExt'); ...
                 findobj(hAxes, '-depth', 1, 'Tag', 'EventLines'); ...
                 findobj(hAxes, '-depth', 1, 'Tag', 'EventPatches');
                 findobj(hAxes, '-depth', 1, 'Tag', 'EventDotsChannel'); ...
                 findobj(hAxes, '-depth', 1, 'Tag', 'EventDotsExtChannel'); ...
                 findobj(hAxes, '-depth', 1, 'Tag', 'EventLinesChannel'); ...
                 findobj(hAxes, '-depth', 1, 'Tag', 'EventPatchesChannel'); ...
                 findobj(hAxes, '-depth', 1, 'Tag', 'EventLabels'); ...
                 findobj(hAxes, '-depth', 1, 'Tag', 'EventNotes')];
    if ~isempty(hEventObj)
        delete(hEventObj);
    end
    % Get figure handles
    [hFig,iFig,iDS] = bst_figures('GetFigure', hFig);
    Handles = GlobalData.DataSet(iDS).Figure(iFig).Handles;
    % Get selected montage
    TsInfo = getappdata(hFig, 'TsInfo');
    if ~isempty(TsInfo.MontageName)
        sMontage = panel_montage('GetMontage', TsInfo.MontageName, hFig);
    else
        sMontage = [];
    end

    % Get the raw events and time axes
    events = panel_record('GetEventsInTimeWindow', hFig);
    % Loop on all the events types
    for iEvt = 1:length(events)
        % If event is hidden
        if isequal(events(iEvt).select, 0)
            continue;
        end
        % Get event color
        if panel_record('IsEventBad', events(iEvt).label)
            color = [1 0 0];
        elseif isfield(events(iEvt), 'color') && ~isempty(events(iEvt).color)
            color = events(iEvt).color;
        else
            color = [0 1 0];
        end
        % Event bar: Plot same line object
        nOccur = size(events(iEvt).times, 2);
        if (nOccur == 0)
            continue;
        end
        % Simple/Extended events
        isExtended = (size(events(iEvt).times, 1) == 2);
            
        % === CHANNEL ATTRIBUTION ===
        iLines = cell(1,nOccur);
        % No individual channel events in butterfly mode
        if strcmpi(TsInfo.DisplayMode, 'butterfly')
            % Nothing to do
        % Use channels field
        elseif ~isempty(events(iEvt).channels) && any(~cellfun(@isempty, events(iEvt).channels))
            % Process each event occurrence individually
            for iOcc = 1:nOccur
                iLines{iOcc} = [];
                for i = 1:length(events(iEvt).channels{iOcc})
                    chName = events(iEvt).channels{iOcc}{i};
                    % Look for channel name in the labels of the data lines
                    iChanLine = find(strcmpi(chName, Handles.LinesLabels));
                    iLines{iOcc} = [iLines{iOcc}, iChanLine];
                    % If not found and there is a montage, try to look in the montage display names
                    if isempty(iChanLine) && ~isempty(sMontage)
                        iChan = find(strcmpi(chName, sMontage.ChanNames));
                        if ~isempty(iChan)
                            iDispName = find(sMontage.Matrix(:,iChan));
                            for iDisp = 1:length(iDispName)
                                iLines{iOcc} = [iLines{iOcc}, find(strcmpi(sMontage.DispNames{iDispName(iDisp)}, Handles.LinesLabels))];
                            end
                        end
                    end
                end
            end
        % Try to match events and channels by name
        else
            % Look for event name in the labels of the data lines
            iLineChName = find(strcmpi(events(iEvt).label, Handles.LinesLabels));
            % If not found and there is a montage, try to look in the montage display names
            if isempty(iLineChName) && ~isempty(sMontage)
                iChan = find(strcmpi(events(iEvt).label, sMontage.ChanNames));
                if ~isempty(iChan)
                    iDispName = find(sMontage.Matrix(:,iChan));
                    for iDisp = 1:length(iDispName)
                        iLineChName = [iLineChName, find(strcmpi(sMontage.DispNames{iDispName(iDisp)}, Handles.LinesLabels))];
                    end
                end
            end
            % Use the same line selection for all the occurrences
            if ~isempty(iLineChName)
                iLines = repmat({iLineChName}, 1, nOccur);
            end
        end
        iOccChannels = find(~cellfun(@isempty, iLines));
        iOccGlobal = find(cellfun(@isempty, iLines) & cellfun(@isempty, events(iEvt).channels));
               
        % === CHANNEL EVENTS ===
        % Where to display the notes and events labels by default
        Ytext = .2 * ones(nOccur, 1);
        Ynotes = zeros(nOccur, 1);
        YnotesAlign = repmat({'Bottom'}, nOccur, 1);
        % Plot as many markers as needed
        for iOcc = iOccChannels
            for i = 1:length(iLines{iOcc})
                % Get line positions
                XData = get(Handles.hLines(iLines{iOcc}(i)), 'XData');
                YData = get(Handles.hLines(iLines{iOcc}(i)), 'YData');
                % Get the closest time samples
                iTime = bst_closest(events(iEvt).times(:,iOcc)', XData);
                XData = XData(iTime(1):iTime(end));
                YData = YData(iTime(1):iTime(end));
                % Define a segment of Y values that contains all the signals
                YChan = [min(YData), max(YData)];
                if ~isExtended
                    YChan = YChan + 0.4 ./ (length(Handles.LinesLabels) + 1) .* [-1, 1];
                else
                    YChan = YChan + (YChan(2) - YChan(1)) .* 0.05 .* [-1, 1];
                end
                Ynotes(iOcc) = max(Ynotes(iOcc), YChan(2));

                % === CHANNEL: DOTS ===
                if strcmpi(TsInfo.ShowEventsMode, 'dot')
                    ZData = 2;
                    % Simple events
                    if ~isExtended
                        % Plot markers on top of the lines
                        hEvtChan = line(...
                            XData, ...         % X
                            YData, ...         % Y
                            ZData, ...         % Z
                            'LineStyle',       'none', ...
                            'MarkerFaceColor', color, ...
                            'MarkerEdgeColor', color .* .8, ...
                            'MarkerSize',      5, ...
                            'Marker',          'o', ...
                            'Tag',             'EventDotsChannel', ...
                            'UserData',        iEvt, ...
                            'Parent',          hAxes);

                    % Exented events
                    else
                        hEvtChan = line(...
                            [XData(1); XData(end)], ...      % X
                            YChan(2) .* ones(2,1), ...        % Y
                            ZData .* ones(2,1), ...            % Z
                            'Color',           color, ...
                            'MarkerFaceColor', color, ...
                            'MarkerEdgeColor', color .* .8, ...
                            'MarkerSize',      5, ...
                            'Marker',          'o', ...
                            'Tag',             'EventDotsExtChannel', ...
                            'UserData',        iEvt, ...
                            'Parent',          hAxes);
                    end
                % === CHANNEL: VERTICAL LINES ===
                elseif strcmpi(TsInfo.ShowEventsMode, 'line')
                    % Simple events
                    if ~isExtended
                        ZData = 2;
                        hEvtChan = line(...
                            [XData; XData], ...     % X
                            YChan', ...              % Y
                            ZData .* ones(2,1), ... % Z
                            'LineStyle',  '-', ...
                            'LineWidth',  1, ...
                            'Color',      color, ...
                            'Marker',     'none', ...
                            'Tag',        'EventLinesChannel', ...
                            'UserData',   iEvt, ...
                            'Parent',     hAxes);
                    % Exented events
                    else
                        ZData = 0.005;
                        patchColor = min(color + .4, 1);
                        hEvtChan = patch(...
                            'XData',      [XData(1); XData(end); XData(end); XData(1)], ...
                            'YData',      [YChan(1); YChan(1); YChan(2); YChan(2)], ...
                            'ZData',      ZData * ones(4, 1), ...
                            'LineWidth',  0.5, ...
                            'FaceColor',  patchColor, ...
                            'FaceAlpha',  1, ...
                            'EdgeColor',  color, ...
                            'EdgeAlpha',  1, ...
                            'Tag',       'EventPatchesChannel', ...
                            'UserData',   iEvt, ...
                            'Parent',     hAxes);
                    end
                end
            end
        end

        % === GLOBAL EVENTS ===
        if ~isempty(iOccGlobal)
            nGlobal = length(iOccGlobal);
            Ynotes(iOccGlobal) = YLim(2);
            YnotesAlign(iOccGlobal) = repmat({'Top'}, nGlobal, 1);
            
            % === GLOBAL: DOTS ===
            if strcmpi(TsInfo.ShowEventsMode, 'dot')
                Ytext(iOccGlobal) = .35;
                % Simple events
                if ~isExtended
                    hEvtBar = line(...
                        events(iEvt).times(1,iOccGlobal), ... % X
                        .2 * ones(1,nGlobal), ...             % Y
                        1 * ones(1,nGlobal), ...              % Z
                        'LineStyle',       'none', ...
                        'MarkerFaceColor', color, ...
                        'MarkerEdgeColor', color .* .6, ...
                        'MarkerSize',      6, ...
                        'Marker',          'o', ...
                        'Tag',             'EventDots', ...
                        'UserData',        iEvt, ...
                        'Parent',          hEventsBar);
                % Exented events
                else
                    hEvtBar = line(...
                        events(iEvt).times(:,iOccGlobal), ... % X
                        .2 * ones(2,nGlobal), ...             % Y
                        1 * ones(2,nGlobal), ...              % Z
                        'Color',           color, ...
                        'MarkerFaceColor', color, ...
                        'MarkerEdgeColor', color .* .6, ...
                        'MarkerSize',      6, ...
                        'Marker',          'o', ...
                        'Tag',             'EventDotsExt', ...
                        'UserData',        iEvt, ...
                        'Parent',          hEventsBar);
                end
            % === GLOBAL: VERTICAL LINES ===
            elseif strcmpi(TsInfo.ShowEventsMode, 'line')
                % Y values: long bar that spans much more than the current view
                YData = 100*(YLim(2) - YLim(1)) .* [-1, 1] + YLim; 
                Ytext(iOccGlobal) = .2;
                % Simple events
                if ~isExtended
                    ZData = 2;
                    hEvtBar = line(...
                        repmat(events(iEvt).times(1,iOccGlobal), 2, 1), ...  % X
                        repmat(YData', 1, nGlobal), ...                      % Y
                        ZData * ones(2, nGlobal), ...                        % Z
                        'LineStyle',  '-', ...
                        'LineWidth',  0.5, ...
                        'Color',      color, ...
                        'Marker',     'none', ...
                        'Tag',        'EventLines', ...
                        'UserData',   iEvt, ...
                        'Parent',     hAxes);
                % Exented events
                else
                    ZData = 0.005;
                    patchColor = min(color + .4, 1);
                    hEvtBar = patch(...
                        'XData',      [events(iEvt).times(1,iOccGlobal); events(iEvt).times(2,iOccGlobal); events(iEvt).times(2,iOccGlobal); events(iEvt).times(1,iOccGlobal)], ...
                        'YData',      repmat([YData(1); YData(1); YData(2); YData(2)], 1, nGlobal), ...
                        'ZData',      ZData * ones(4, nGlobal), ...
                        'LineWidth',  0.5, ...
                        'FaceColor',  patchColor, ...
                        'FaceAlpha',  1, ...
                        'EdgeColor',  color, ...
                        'EdgeAlpha',  1, ...
                        'Tag',       'EventPatches', ...
                        'UserData',   iEvt, ...
                        'Parent',     hAxes);
                end
            else
                Ytext = [];
            end
        end
        
        % === EVENT LABEL ===
        if (length(events(iEvt).times) < 30) && ~isempty(Ytext) && ~strcmpi(TsInfo.ShowEventsMode, 'none')
            hEvtLabel = text(...
                mean(events(iEvt).times,1), ...  % X
                Ytext, ...                       % Y
                repmat({events(iEvt).label}, 1, size(events(iEvt).times,2)), ...
                'Color',               color, ...
                'FontSize',            bst_get('FigFont'), ...
                'FontUnits',           'points', ...
                'VerticalAlignment',   'bottom', ...
                'HorizontalAlignment', 'center', ...
                'Interpreter',         'none', ...
                'Tag',                 'EventLabels', ...
                'UserData',            iEvt, ...
                'Parent',              hEventsBar);
        end
        
        % === EVENT NOTES ===
        if ~strcmpi(TsInfo.ShowEventsMode, 'none')
            for iOcc = 1:nOccur
                % No notes attached to this event, skip
                if isempty(events(iEvt).notes{iOcc})
                    continue;
                end
                % Plot text
                ZData = 2.5;
                hEvtNotes = text(...
                    mean(events(iEvt).times(:,iOcc),1), ...  % X
                    Ynotes(iOcc), ...                        % Y
                    ZData, ...                               % Z
                    events(iEvt).notes{iOcc}, ...
                    'Color',               color, ...
                    'FontSize',            bst_get('FigFont'), ...
                    'FontUnits',           'points', ...
                    'VerticalAlignment',   YnotesAlign{iOcc}, ...
                    'HorizontalAlignment', 'center', ...
                    'Interpreter',         'none', ...
                    'Tag',                 'EventNotes', ...
                    'UserData',            iEvt, ...
                    'Parent',              hAxes);
            end
        end
    end
end


%% ===== VIEW STAT CLUSTERS =====
function ViewStatClusters(hFig)
    global GlobalData;
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    if isempty(iDS)
        return
    end
    % Get axes
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'AxesGraph');
    YLim = get(hAxes, 'YLim');
    % Get figure type
    selChan = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels;
    % Delete existing markers
    hClusterMarkers = findobj(hAxes, '-depth', 1, 'Tag', 'ClusterMarkers');
    if ~isempty(hClusterMarkers)
        delete(hClusterMarkers);
    end
    
    % Get active clusters
    sClusters = panel_stat('GetDisplayedClusters', hFig);
    if isempty(sClusters)
        return;
    end
    % Get TimeVector
    TimeVector = bst_memory('GetTimeVector', iDS);
    yOffset = 0.99;
    % Plot each cluster separately
    for iClust = 1:length(sClusters)
        % Get the time points for which the cluster is significative
        if ~isempty(selChan)
            iSelTime = find(any(sClusters(iClust).mask(selChan,:), 1));
        else
            iSelTime = find(any(sClusters(iClust).mask, 1));
        end
        if ~isempty(iSelTime)
            % Get the coordinates of the cluster markers
            if (length(iSelTime) > 1)
                X = [TimeVector(iSelTime(1)), TimeVector(iSelTime(end))];
            else
                X = TimeVector(iSelTime(1)) + [0, 0.01] * (TimeVector(end)-TimeVector(1));
            end
            Y = yOffset * YLim(2) * [1 1];
            Z = [4 4];
            % Plot a line at the top of the figure
            line(X, Y, Z, ...
                'Parent',     hAxes, ...
                'LineWidth',  3, ...
                'LineStyle',  '-', ...
                'Color',      sClusters(iClust).color, ...
                'Tag',        'ClusterMarkers');
            % Print each cluster lower in the figure
            yOffset = yOffset - 0.02;
        end
    end
end


%% ===== RELOAD RAW TIME BARS =====
function ReloadRawTimeBars()
    % Get all the raw time bars
    hRawTimeBar = findobj(0, 'Tag', 'AxesRawTimeBar');
    % Loop on them
    for i = 1:length(hRawTimeBar)
        % Get parent figure
        hFig = get(hRawTimeBar(i), 'Parent');
        % Delete time bar
        delete(hRawTimeBar);
        % Find figure
        [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
        % Redraw raw time bar
        PlotRawTimeBar(iDS, iFig);
        % Resize
        ResizeCallback(hFig);
    end
end


%% ===== SET TRIAL STATUS =====
function SetTrialStatus(hFig, DataFile, isBad)
    % Save modified markers (only when switching to good)
    if ~isBad
        panel_record('SaveModifications');
    end
    % Change trial status
    process_detectbad('SetTrialStatus', DataFile, isBad);
    % Update modified markers (only when switching to good)
    if ~isBad
        % Reload file
        bst_memory('LoadDataFile', DataFile, 1);
        % Reload figure
        bst_figures('ReloadFigures', hFig, 1);
        % Update record panel
        panel_record('UpdatePanel', hFig);
    end
end


%% ===== SWITCH MATRIX FILE =====
function SwitchMatrixFile(hFig, keyEvent)
    % Get figure data
    TsInfo = getappdata(hFig, 'TsInfo');
    % Reject bad requests
    if isempty(keyEvent) || ~isequal(keyEvent.Key, 'f3') || isempty(TsInfo) || isempty(TsInfo.FileName)
        return;
    end
    % Get file in database
    [sStudy, iStudy, iMatrix] = bst_get('MatrixFile', TsInfo.FileName);
    % Try to get to previous/next matrix file
    if ismember('shift', get(hFig,'CurrentModifier'))
        iMatrix = iMatrix - 1;
    else
        iMatrix = iMatrix + 1;
    end
    % If invalid matrix index: exit
    if (iMatrix < 1) || (iMatrix > length(sStudy.Matrix))
        return;
    end
    NewMatrixFile = sStudy.Matrix(iMatrix).FileName;
    % Save modified markers
    panel_record('SaveModifications');
    % Get loaded matrix
    [iDS, iLoadedMatrix] = bst_memory('GetDataSetMatrix', TsInfo.FileName);
    % Force matrix to be reloaded
    bst_memory('LoadMatrixFile', NewMatrixFile, iDS, iLoadedMatrix);
    % Replace matrix file in the figure
    TsInfo.FileName = NewMatrixFile;
    setappdata(hFig, 'TsInfo', TsInfo);
    % Reload figure
    bst_figures('ReloadFigures', hFig, 1);
    % Update record panel
    panel_record('UpdatePanel', hFig);
    % Select new file in the database explorer
    panel_protocols('SelectNode', [], TsInfo.FileName);
end

% Returns whether matrix A dimensions are contained inside matrix B,
% starting from the first dimension of B
% I.e. A = 2 x 3 and B = 2 x 3 x 4; A is contained in B.
%      A = 2 x 3 and B = 4 x 2 x 3; A is not contained in B
function res = ContainsDims(MatA, MatB)
    if isempty(MatB)
        res = isempty(MatA);
        return;
    end
    
    sizeA  = size(MatA);
    sizeB  = size(MatB);
    nDimsA = length(sizeA);
    nDimsB = length(sizeB);
    res = nDimsB >= nDimsA && all(sizeB(1:nDimsA) == sizeA);
end

