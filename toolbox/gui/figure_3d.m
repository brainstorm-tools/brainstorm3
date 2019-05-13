function varargout = figure_3d( varargin )
% FIGURE_3d: Creation and callbacks for 3D visualization figures.
%
% USAGE: 
%        [hFig] = figure_3d('CreateFigure',               FigureId)
%                 figure_3d('ColormapChangedCallback',    iDS, iFig)    
%                 figure_3d('FigureClickCallback',        hFig, event)  
%                 figure_3d('FigureMouseMoveCallback',    hFig, event)  
%                 figure_3d('FigureMouseUpCallback',      hFig, event)  
%                 figure_3d('FigureMouseWheelCallback',   hFig, event)  
%                 figure_3d('FigureKeyPressedCallback',   hFig, keyEvent)   
%                 figure_3d('ResetView',                  hFig)
%                 figure_3d('SetStandardView',            hFig, viewNames)
%                 figure_3d('DisplayFigurePopup',         hFig)
%                 figure_3d('UpdateSurfaceColor',    hFig, iTess)
%                 figure_3d('ViewSensors',           hFig, isMarkers, isLabels, isMesh=1, Modality=[])
%                 figure_3d('ViewAxis',              hFig, isVisible)
%                 figure_3d('PlotFibers',            hFig, FibPoints, Colors)
%                 figure_3d('ColorFibers',           fibLines, Color)
%                 figure_3d('SelectFiberScouts',     hFigConn, iScouts, Color, ColorOnly)
%     [hFig,hs] = figure_3d('PlotSurface',           hFig, faces, verts, cdata, dataCMap, transparency)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2019; Martin Cousineau, 2019

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

    % === CREATE FIGURE ===
    hFig = figure('Visible',       'off', ...
                  'NumberTitle',   'off', ...
                  'IntegerHandle', 'off', ...
                  'MenuBar',       'none', ...
                  'Toolbar',       'none', ...
                  'DockControls',  'on', ...
                  'Units',         'pixels', ...
                  'Color',         [0 0 0], ...
                  'Tag',           FigureId.Type, ...
                  'Renderer',      rendererName, ...
                  'CloseRequestFcn',         @(h,ev)bst_figures('DeleteFigure',h,ev), ...
                  'KeyPressFcn',             @(h,ev)bst_call(@FigureKeyPressedCallback,h,ev), ...
                  'WindowButtonDownFcn',     @(h,ev)bst_call(@FigureClickCallback,h,ev), ...
                  'WindowButtonMotionFcn',   @(h,ev)bst_call(@FigureMouseMoveCallback,h,ev), ...
                  'WindowButtonUpFcn',       @(h,ev)bst_call(@FigureMouseUpCallback,h,ev), ...
                  bst_get('ResizeFunction'), @(h,ev)bst_call(@ResizeCallback,h,ev), ...
                  'BusyAction',    'queue', ...
                  'Interruptible', 'off');   
    % Define Mouse wheel callback separately (not supported by old versions of Matlab)
    if isprop(hFig, 'WindowScrollWheelFcn')
        set(hFig, 'WindowScrollWheelFcn',  @FigureMouseWheelCallback);
    end
    % Disable automatic legends (after 2017a)
    if (MatlabVersion >= 902) 
        set(hFig, 'defaultLegendAutoUpdate', 'off')
    end
    
    % === CREATE AXES ===
    hAxes = axes('Parent',        hFig, ...
                 'Units',         'normalized', ...
                 'Position',      [.05 .05 .9 .9], ...
                 'Tag',           'Axes3D', ...
                 'Visible',       'off', ...
                 'BusyAction',    'queue', ...
                 'Interruptible', 'off');
    % Constraints depend on the figure type
    if isequal(FigureId.SubType, '2DLayout')
        axis off
        % Recent versions of Matlab: set zoom behavior
        if (MatlabVersion >= 900)
            z = zoom(hFig);
            setAxes3DPanAndZoomStyle(z,hAxes,'camera');
        end
    else
        axis vis3d
        axis equal 
        axis off
        % Recent versions of Matlab: set zoom behavior
        if (MatlabVersion >= 900)
            z = zoom(hFig);
            setAxes3DPanAndZoomStyle(z,hAxes,'camera');
        end
    end
    
    % === APPDATA STRUCTURE ===
    setappdata(hFig, 'Surface',     repmat(db_template('TessInfo'), 0));
    setappdata(hFig, 'iSurface',    []);
    setappdata(hFig, 'StudyFile',   []);   
    setappdata(hFig, 'SubjectFile', []);      
    setappdata(hFig, 'DataFile',    []); 
    setappdata(hFig, 'ResultsFile', []);
    setappdata(hFig, 'isSelectingCorticalSpot', 0);
    setappdata(hFig, 'isSelectingCoordinates',  0);
    setappdata(hFig, 'hasMoved',    0);
    setappdata(hFig, 'isPlotEditToolbar',   0);
    setappdata(hFig, 'AllChannelsDisplayed', 0);
    setappdata(hFig, 'ChannelsToSelect', []);
    setappdata(hFig, 'FigureId', FigureId);
    setappdata(hFig, 'isStatic', 0);
    setappdata(hFig, 'isStaticFreq', 1);
    setappdata(hFig, 'Colormap', db_template('ColormapInfo'));
    setappdata(hFig, 'ElectrodeDisplay', struct('DisplayMode', 'depth'));

    % === LIGHTING ===
    hl = [];
    % Fixed lights
    hl(1) = camlight(  0,  40, 'infinite');
    hl(2) = camlight(180,  40, 'infinite');
    hl(3) = camlight(  0, -90, 'infinite');
    hl(4) = camlight( 90,   0, 'infinite');
    hl(5) = camlight(-90,   0, 'infinite');
    % Moving camlight
    hl(6) = light('Tag', 'FrontLight', 'Color', [1 1 1], 'Style', 'infinite', 'Parent', hAxes);
    camlight(hl(6), 'headlight');
    % Mute the intensity of the lights
    for i = 1:length(hl)
        set(hl(i), 'color', .4*[1 1 1]);
    end
    % Camera basic orientation
    SetStandardView(hFig, 'top');
end


%% =========================================================================================
%  ===== FIGURE CALLBACKS ==================================================================
%  =========================================================================================  
%% ===== COLORMAP CHANGED =====
% Usage:  ColormapChangedCallback(iDS, iFig)
function ColormapChangedCallback(iDS, iFig) %#ok<DEFNU>
    global GlobalData;
    hFig = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
    % Update surfaces
    panel_surface('UpdateSurfaceColormap', hFig);
    % Update dipoles
    if ~isempty(getappdata(hFig, 'Dipoles')) && gui_brainstorm('isTabVisible', 'Dipoles')
        panel_dipoles('PlotSelectedDipoles', hFig);
    end
end


%% ===== RESIZE CALLBACK =====
function ResizeCallback(hFig, ev)
    % Get colorbar and axes handles
    hColorbar = findobj(hFig, '-depth', 1, 'Tag', 'Colorbar');
    hAxes     = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    if isempty(hAxes)
        return
    end
    hAxes = hAxes(1);
    % Get figure position and size in pixels
    figPos = get(hFig, 'Position');
    % Define constants
    colorbarWidth = 15;
    marginHeight  = 25;
    marginWidth   = 45;
    
    % If there is a colorbar 
    if ~isempty(hColorbar)
        % Reposition the colorbar
        set(hColorbar, 'Units',    'pixels', ...
                       'Position', [figPos(3) - marginWidth, ...
                                    marginHeight, ...
                                    colorbarWidth, ...
                                    max(1, min(90, figPos(4) - marginHeight - 3))]);
        % Reposition the axes
        marginAxes = 10;
        set(hAxes, 'Units',    'pixels', ...
                   'Position', [marginAxes, ...
                                marginAxes, ...
                                figPos(3) - colorbarWidth - marginWidth - 2, ... % figPos(3) - colorbarWidth - marginWidth - marginAxes, ...
                                max(1, figPos(4) - 2*marginAxes)]);
    % No colorbar : data axes can take all the figure space
    else
        % Reposition the axes
        set(hAxes, 'Units',    'normalized', ...
                   'Position', [.05, .05, .9, .9]);
    end
    
    % ===== 2DLAYOUT: REPOSITION SCALE CONTROLS =====
    FigureId = getappdata(hFig, 'FigureId');
    if isequal(FigureId.SubType, '2DLayout')
        % Get buttons
        hButtonGainMinus = findobj(hFig, '-depth', 1, 'Tag', 'ButtonGainMinus');
        hButtonGainPlus  = findobj(hFig, '-depth', 1, 'Tag', 'ButtonGainPlus');
        hButtonSetTimeWindow = findobj(hFig, '-depth', 1, 'Tag', 'ButtonSetTimeWindow');
        hButtonZoomTimePlus  = findobj(hFig, '-depth', 1, 'Tag', 'ButtonZoomTimePlus');
        hButtonZoomTimeMinus = findobj(hFig, '-depth', 1, 'Tag', 'ButtonZoomTimeMinus');
        % Reposition buttons
        butSize = 22;
        if ~isempty(hButtonZoomTimePlus)
            set(hButtonZoomTimePlus,   'Position', [figPos(3) - 3*(butSize+3) + 1, 3, butSize, butSize]);
            set(hButtonZoomTimeMinus,  'Position', [figPos(3) - 2*(butSize+3) + 1, 3, butSize, butSize]);
        end
        if ~isempty(hButtonSetTimeWindow)
            set(hButtonSetTimeWindow, 'Position', [figPos(3) - butSize - 1, 3, butSize, butSize]);
        end
        if ~isempty(hButtonGainMinus)
            set(hButtonGainMinus, 'Position', [figPos(3)-butSize-1, 3 + (butSize+3), butSize, butSize]);
            set(hButtonGainPlus,  'Position', [figPos(3)-butSize-1, 3 + 2*(butSize+3), butSize, butSize]);
        end
    end
end
    
%% =========================================================================================
%  ===== KEYBOARD AND MOUSE CALLBACKS ======================================================
%  =========================================================================================
% Complete mouse and keyboard management over the main axes
% Supports : - Customized 3D-Rotation (LEFT click)
%            - Pan (SHIFT+LEFT click, OR MIDDLE click
%            - Zoom (CTRL+LEFT click, OR RIGHT click, OR WHEEL)
%            - Colorbar contrast/brightness
%            - Restore original view configuration (DOUBLE click)

%% ===== FIGURE CLICK CALLBACK =====
function FigureClickCallback(hFig, varargin)
    % Get selected object in this figure
    hObj = get(hFig,'CurrentObject');
    % Find axes
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    if isempty(hAxes)
        warning('Brainstorm:NoAxes', 'Axes could not be found');
        return;
    end
    % Get figure type
    FigureId = getappdata(hFig, 'FigureId');
    % Double click: reset view           
    if strcmpi(get(hFig, 'SelectionType'), 'open')
        ResetView(hFig);
    end
    % Check if MouseUp was executed before MouseDown
    if isappdata(hFig, 'clickAction') && strcmpi(getappdata(hFig,'clickAction'), 'MouseDownNotConsumed')
        return;
    end
   
    % Start an action (pan, zoom, rotate, contrast, luminosity)
    % Action depends on : 
    %    - the mouse button that was pressed (LEFT/RIGHT/MIDDLE), 
    %    - the keys that the user presses simultaneously (SHIFT/CTRL)
    clickAction = '';
    switch(get(hFig, 'SelectionType'))
        % Left click
        case 'normal'
            % 2DLayout: pan
            if ismember(FigureId.SubType, {'2DLayout', '2DElectrodes'})
                clickAction = 'pan';
            % 2D: nothing
            elseif ismember(FigureId.SubType, {'2DDisc', '2DSensorCap'})
                % Nothing to do
            % Else (3D): rotate
            else
                clickAction = 'rotate';
            end
        % CTRL+Mouse, or Mouse right
        case 'alt'
            clickAction = 'popup';
        % SHIFT+Mouse, or Mouse middle
        case 'extend'
            clickAction = 'pan';
    end
    
    % Record action to perform when the mouse is moved
    setappdata(hFig, 'clickAction', clickAction);
    setappdata(hFig, 'clickSource', hFig);
    setappdata(hFig, 'clickObject', hObj);
    % Reset the motion flag
    setappdata(hFig, 'hasMoved', 0);
    % Record mouse location in the figure coordinates system
    setappdata(hFig, 'clickPositionFigure', get(hFig, 'CurrentPoint'));
    % Record mouse location in the axes coordinates system
    setappdata(hFig, 'clickPositionAxes', get(hAxes, 'CurrentPoint'));
end

    
%% ===== FIGURE MOVE =====
function FigureMouseMoveCallback(hFig, varargin)  
    % Get axes handle
    hAxes = findobj(hFig, '-depth', 1, 'tag', 'Axes3D');
    % Get current mouse action
    clickAction = getappdata(hFig, 'clickAction');   
    clickSource = getappdata(hFig, 'clickSource');   
    % If no action is currently performed
    if isempty(clickAction)
        return
    end
    % If MouseUp was executed before MouseDown
    if strcmpi(clickAction, 'MouseDownNotConsumed') || isempty(getappdata(hFig, 'clickPositionFigure'))
        % Ignore Move event
        return
    end
    % If source is not the same as the current figure: fire mouse up event
    if (clickSource ~= hFig)
        FigureMouseUpCallback(hFig);
        FigureMouseUpCallback(clickSource);
        return
    end

    % Set the motion flag
    setappdata(hFig, 'hasMoved', 1);
    % Get current mouse location in figure
    curptFigure = get(hFig, 'CurrentPoint');
    motionFigure = 0.3 * (curptFigure - getappdata(hFig, 'clickPositionFigure'));
    % Get current mouse location in axes
    curptAxes = get(hAxes, 'CurrentPoint');
    oldptAxes = getappdata(hFig, 'clickPositionAxes');
    if isempty(oldptAxes)
        return
    end
    motionAxes = curptAxes - oldptAxes;
    % Update click point location
    setappdata(hFig, 'clickPositionFigure', curptFigure);
    setappdata(hFig, 'clickPositionAxes',   curptAxes);
    % Get figure size
    figPos = get(hFig, 'Position');
       
    % Switch between different actions (Pan, Rotate, Zoom, Contrast)
    switch(clickAction)              
        case 'rotate'
            % Else : ROTATION
            % Rotation functions : 5 different areas in the figure window
            %     ,---------------------------.
            %     |             2             |
            % .75 |---------------------------| 
            %     |   3  |      5      |  4   |   
            %     |      |             |      | 
            % .25 |---------------------------| 
            %     |             1             |
            %     '---------------------------'
            %           .25           .75
            %
            % ----- AREA 1 -----
            if (curptFigure(2) < .25 * figPos(4))
                camroll(hAxes, motionFigure(1));
                camorbit(hAxes, 0,-motionFigure(2), 'camera');
            % ----- AREA 2 -----
            elseif (curptFigure(2) > .75 * figPos(4))
                camroll(hAxes, -motionFigure(1));
                camorbit(hAxes, 0,-motionFigure(2), 'camera');
            % ----- AREA 3 -----
            elseif (curptFigure(1) < .25 * figPos(3))
                camroll(hAxes, -motionFigure(2));
                camorbit(hAxes, -motionFigure(1),0, 'camera');
            % ----- AREA 4 -----
            elseif (curptFigure(1) > .75 * figPos(3))
                camroll(hAxes, motionFigure(2));
                camorbit(hAxes, -motionFigure(1),0, 'camera');
            % ----- AREA 5 -----
            else
                camorbit(hAxes, -motionFigure(1),-motionFigure(2), 'camera');
            end
            camlight(findobj(hAxes, '-depth', 1, 'Tag', 'FrontLight'), 'headlight');

        case 'pan'
            % Get camera textProperties
            pos    = get(hAxes, 'CameraPosition');
            up     = get(hAxes, 'CameraUpVector');
            target = get(hAxes, 'CameraTarget');
            % Calculate a normalised right vector
            right = cross(up, target - pos);
            up    = up ./ realsqrt(sum(up.^2));
            right = right ./ realsqrt(sum(right.^2));
            % Calculate new camera position and camera target
            panFactor = 0.001;
            pos    = pos    + panFactor .* (motionFigure(1).*right - motionFigure(2).*up);
            target = target + panFactor .* (motionFigure(1).*right - motionFigure(2).*up);
            set(hAxes, 'CameraPosition', pos, 'CameraTarget', target);

        case 'zoom'
            if (motionFigure(2) == 0)
                return;
            elseif (motionFigure(2) < 0)
                % ZOOM IN
                Factor = 1-motionFigure(2)./100;
            elseif (motionFigure(2) > 0)
                % ZOOM OUT
                Factor = 1./(1+motionFigure(2)./100);
            end
            zoom(hFig, Factor);
            
        case {'moveSlices', 'popup'}
            FigureId = getappdata(hFig, 'FigureId');
            % TOPO: Select channels
            if strcmpi(FigureId.Type, 'Topography') && ismember(FigureId.SubType, {'2DLayout', '2DDisc', '2DSensorCap', '2DElectrodes'})
                % Get current point
                curPt = curptAxes(1,:);
                % Limit selection to current display
                curPt(1) = bst_saturate(curPt(1), get(hAxes, 'XLim'));
                curPt(2) = bst_saturate(curPt(2), get(hAxes, 'YLim'));
                if ~isappdata(hFig, 'patchSelection')
                    % Set starting position
                    setappdata(hFig, 'patchSelection', curPt);
                    % Draw patch
                    hSelPatch = patch('XData', curptAxes(1) * [1 1 1 1], ...
                                      'YData', curptAxes(2) * [1 1 1 1], ...
                                      'ZData', .0001 * [1 1 1 1], ...
                                      'LineWidth', 1, ...
                                      'FaceColor', [1 0 0], ...
                                      'FaceAlpha', 0.3, ...
                                      'EdgeColor', [1 0 0], ...
                                      'EdgeAlpha', 1, ...
                                      'BackfaceLighting', 'lit', ...
                                      'Tag',       'TopoSelectionPatch', ...
                                      'Parent',    hAxes);
                else
                    % Get starting position
                    startPt = getappdata(hFig, 'patchSelection');
                    % Update patch position
                    hSelPatch = findobj(hAxes, '-depth', 1, 'Tag', 'TopoSelectionPatch');
                    % Set new patch position
                    set(hSelPatch, 'XData', [startPt(1), curPt(1),   curPt(1), startPt(1)], ...
                                   'YData', [startPt(2), startPt(2), curPt(2), curPt(2)]);
                end
            % MRI: Move slices
            else
                % Get MRI
                [sMri,TessInfo,iTess] = panel_surface('GetSurfaceMri', hFig);
                if isempty(iTess)
                    return
                end

                % === DETECT ACTION ===
                % Is moving axis and direction are not detected yet : do it
                if (~isappdata(hFig, 'moveAxis') || ~isappdata(hFig, 'moveDirection'))
                    % Guess which cut the user is trying to change
                    % Sometimes some problem occurs, leading to values > 800
                    % for a 1-pixel movement => ignoring
                    if (max(motionAxes(1,:)) > 20)
                        return;
                    end
                    % Convert MRI-CS -> SCS
                    motionAxes = motionAxes * sMri.SCS.R;
                    % Get the maximum deplacement as the direction
                    [value, moveAxis] = max(abs(motionAxes(1,:)));
                    moveAxis = moveAxis(1);
                    % Get the directions of the mouse deplacement that will
                    % increase or decrease the value of the slice
                    [value, moveDirection] = max(abs(motionFigure));                   
                    moveDirection = sign(motionFigure(moveDirection(1))) .* ...
                                    sign(motionAxes(1,moveAxis)) .* ...
                                    moveDirection(1);
                    % Save the detected movement direction and orientation
                    if ismember(moveDirection, [1 2 3])
                        setappdata(hFig, 'moveAxis',      moveAxis);
                        setappdata(hFig, 'moveDirection', moveDirection);
                    end
                    
                % === MOVE SLICE ===
                else                
                    % Get saved information about current motion
                    moveAxis      = getappdata(hFig, 'moveAxis');
                    moveDirection = getappdata(hFig, 'moveDirection');
                    % If a valid direction is available
                    if ~isempty(moveDirection) && ~isequal(moveDirection, 0)
                        % Get the motion value
                        val = sign(moveDirection) .* motionFigure(abs(moveDirection));
                        % Get the new position of the slice
                        oldPos = TessInfo(iTess).CutsPosition(moveAxis);
                        newPos = round(bst_saturate(oldPos + val, [1 size(sMri.Cube, moveAxis)]));

                        % Plot a patch that indicates the location of the cut
                        PlotSquareCut(hFig, TessInfo(iTess), moveAxis, newPos);

                        % Draw a new X-cut according to the mouse motion
                        posXYZ = [NaN, NaN, NaN];
                        posXYZ(moveAxis) = newPos;
                        panel_surface('PlotMri', hFig, posXYZ);
                    end
                end
            end
    
        case 'colorbar'
            % Delete legend
            % delete(findobj(hFig, 'Tag', 'ColorbarHelpMsg'));
            % Get colormap type
            ColormapInfo = getappdata(hFig, 'Colormap');
            % Changes contrast
            sColormap = bst_colormaps('ColormapChangeModifiers', ColormapInfo.Type, [motionFigure(1), motionFigure(2)] ./ 100, 0);
            if ~isempty(sColormap)
                set(hFig, 'Colormap', sColormap.CMap);
            end
    end
end

                
%% ===== FIGURE MOUSE UP =====        
function FigureMouseUpCallback(hFig, varargin)
    global GlobalData gChanAlign;
    % === 3DViz specific commands ===
    % Get application data (current user/mouse actions)
    clickAction = getappdata(hFig, 'clickAction');
    clickObject = getappdata(hFig, 'clickObject');
    hasMoved    = getappdata(hFig, 'hasMoved');
    hAxes       = findobj(hFig, '-depth', 1, 'tag', 'Axes3D');
    isSelectingCorticalSpot = getappdata(hFig, 'isSelectingCorticalSpot');
    isSelectingCoordinates  = getappdata(hFig, 'isSelectingCoordinates');
    TfInfo = getappdata(hFig, 'Timefreq');
    
    % Remove mouse appdata (to stop movements first)
    setappdata(hFig, 'hasMoved', 0);
    if isappdata(hFig, 'clickPositionFigure')
        rmappdata(hFig, 'clickPositionFigure');
    end
    if isappdata(hFig, 'clickPositionAxes')
        rmappdata(hFig, 'clickPositionAxes');
    end
    if isappdata(hFig, 'clickAction')
        rmappdata(hFig, 'clickAction');
    else
        setappdata(hFig, 'clickAction', 'MouseDownNotConsumed');
    end
    if isappdata(hFig, 'moveAxis')
        rmappdata(hFig, 'moveAxis');
    end
    if isappdata(hFig, 'moveDirection')
        rmappdata(hFig, 'moveDirection');
    end
    if isappdata(hFig, 'patchSelection')
        rmappdata(hFig, 'patchSelection');
    end
    % Remove SquareCut objects
    PlotSquareCut(hFig);
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    if isempty(iDS)
        return
    end
    Figure = GlobalData.DataSet(iDS).Figure(iFig);
    % Update figure selection
    if strcmpi(Figure.Id.Type, '3DViz')
        bst_figures('SetCurrentFigure', hFig, '3D');
    elseif ismember(Figure.Id.SubType, {'3DSensorCap', '3DElectrodes'})
        bst_figures('SetCurrentFigure', hFig, '3D');
        bst_figures('SetCurrentFigure', hFig, '2D');
    else
        bst_figures('SetCurrentFigure', hFig, '2D');
    end
    if isappdata(hFig, 'Timefreq') && ~isempty(getappdata(hFig, 'Timefreq'))
        bst_figures('SetCurrentFigure', hFig, 'TF');
    end
    
    % ===== SIMPLE CLICK ===== 
    % If user did not move the mouse since the click
    if ~hasMoved
        % === POPUP ===
        if strcmpi(clickAction, 'popup')
            DisplayFigurePopup(hFig);
            
        % === SELECTING CORTICAL SCOUTS ===
        elseif isSelectingCorticalSpot
            panel_scout('CreateScoutMouse', hFig);
            
        % === SELECTING POINT (COORDINATES PANEL) ===
        elseif isSelectingCoordinates
            if gui_brainstorm('isTabVisible', 'Coordinates')
                panel_coordinates('SelectPoint', hFig);
            end
            
        % === TIME-FREQ CORTICAL POINT ===
        % SHIFT + CLICK: Display time-frequency map for the selected dipole
        elseif ~isempty(TfInfo) && ~isempty(TfInfo.FileName) && strcmpi(Figure.Id.Type, '3DViz') && strcmpi(get(hFig, 'SelectionType'), 'extend')
            % Get selected vertex
            iVertex = panel_coordinates('SelectPoint', hFig, 0);
            % Show time-frequency decomposition for this source
            if ~isempty(iVertex)
                if ~isempty(strfind(TfInfo.FileName, '_psd')) || ~isempty(strfind(TfInfo.FileName, '_fft')) || ~isempty(strfind(TfInfo.FileName, '_cohere')) || ~isempty(strfind(TfInfo.FileName, '_spgranger'))
                    view_spectrum(TfInfo.FileName, 'Spectrum', iVertex, 1);
                elseif ~isempty(strfind(TfInfo.FileName, '_pac_fullmaps'))
                    view_pac(TfInfo.FileName, iVertex, 'PAC', [], 1);
                elseif ~isempty(strfind(TfInfo.FileName, '_pac'))
                    % Nothing
                else
                    view_timefreq(TfInfo.FileName, 'SingleSensor', iVertex, 1);
                end
            end
            
        % === SELECTING SCOUT ===
        elseif ~isempty(clickObject) && ismember(get(clickObject,'Tag'), {'ScoutPatch', 'ScoutContour', 'ScoutMarker'})
            % Get scouts display options
            ScoutsOptions = panel_scout('GetScoutsOptions');
            % Display/hide scouts
            if strcmpi(ScoutsOptions.showSelection, 'all')
                % Find the selected scout
                [sScout, iScout] = panel_scout('GetScoutWithHandle', clickObject);
                % If a scout was found: select it in the list
                if ~isempty(iScout)
                    % If the SHIFT key is pressed, add/remove scout in extisting selection
                    if strcmpi(get(hFig, 'SelectionType'), 'extend')
                        [sPrevScouts, iPrevScouts] = panel_scout('GetSelectedScouts');
                        % Already selected: remove from selection
                        if ismember(iScout, iPrevScouts)
                            iPrevScouts(iPrevScouts == iScout) = [];
                            iScout = iPrevScouts;
                        % Not selected yet: Add to selection
                        else
                            iScout = [iPrevScouts, iScout];
                        end
                    end
                    % Set selection
                    panel_scout('SetSelectedScouts', iScout);
                end
            end
            
        % === SELECTING DIPOLE ===
        elseif ~isempty(clickObject) && ismember(get(clickObject,'Tag'), {'DipolesLoc', 'DipolesOrient'})
            % Get the index of the selected dipole
            iDipole = get(clickObject, 'UserData');
            % Select dipole
            if ~isempty(iDipole)
                panel_dipinfo('SelectDipole', hFig, iDipole);
            end
            
        % === SELECTING NIRS PAIR ===
        elseif ~isempty(clickObject) && strcmpi(get(clickObject,'Tag'), 'NirsCapLine')
            % Get selected pair
            PairSD = get(clickObject, 'UserData');
            % Get all related data channels
            SelChan = panel_montage('GetRelatedNirsChannels', GlobalData.DataSet(iDS).Channel, sprintf('S%dD%d',PairSD));
            % Select only the last sensor
            bst_figures('ToggleSelectedRow', SelChan);
            
        % === SELECTING DEPTH ELECTRODE ===
        elseif ~isempty(clickObject) && ismember(get(clickObject,'Tag'), {'ElectrodeDepth', 'ElectrodeLabel'})
            % Get electrode name
            elecName = get(clickObject, 'UserData');
            % Select it in panel iEEG
            panel_ieeg('SetSelectedElectrodes', elecName);
            
        % === SELECTING SENSORS ===
        else
            iSelChan = [];
            % Check if sensors are displayed in this figure (as a patch)
            hSensorsPatch   = findobj(hAxes, '-depth', 1, 'Tag', 'SensorsPatch');
            hSensorsMarkers = findobj(hAxes, '-depth', 1, 'Tag', 'SensorsMarkers');
            hElectrodeGrid  = findobj(hAxes, '-depth', 1, 'Tag', 'ElectrodeGrid');
            hNirsCapPatch   = findobj(hAxes, '-depth', 1, 'Tag', 'NirsCapPatch');
            % Selecting from 3DElectrodes patch
            if ~isempty(hElectrodeGrid)
                % Select the nearest sensor from the mouse
                [p, v, vi] = select3d(hElectrodeGrid(1));
                % Get the correspondance electrodes/vertex
                UserData = get(hElectrodeGrid(1), 'UserData');
                % If sensor index is not valid
                if isempty(vi) || (vi > length(UserData)) || (vi <= 0)
                    return
                end
                % Get the channel index from the vertex index
                vi = UserData(vi);
            % Selecting from NIRS cap
            elseif ~isempty(hNirsCapPatch)
                % Select the nearest sensor from the mouse
                [p, v, vi] = select3d(hNirsCapPatch);
                % Get the correspondance electrodes/vertex
                UserData = get(hNirsCapPatch, 'UserData');
                % If sensor index is not valid
                if isempty(vi) || (vi > length(UserData)) || (vi <= 0)
                    return
                end
                % Get the sphere name (source or detector)
                sphName = UserData{vi};
                sphInd = str2num(sphName(2:end));
                % Parse the NIRS channel names
                iNirs = intersect(channel_find(GlobalData.DataSet(iDS).Channel, 'NIRS'), Figure.SelectedChannels);
                [S,D,WL] = panel_montage('ParseNirsChannelNames', {GlobalData.DataSet(iDS).Channel(iNirs).Name});
                % Find the corresponding channels of data
                if (sphName(1) == 'S')
                    vi = find(S == sphInd);
                elseif (sphName(1) == 'D')
                    vi = find(D == sphInd);
                end
            % Selecting from sensor text
            elseif strcmpi(get(clickObject,'Tag'), 'SensorsLabels')
                vi = get(clickObject, 'UserData');
            % Selecting from sensors patch
            elseif (length(hSensorsPatch) == 1)
                % Select the nearest sensor from the mouse
                [p, v, vi] = select3d(hSensorsPatch);
                % If sensor index is not valid
                if isempty(vi) || (vi > length(Figure.SelectedChannels)) || (vi <= 0)
                    return
                end
                % If clicked point is too far away (5mm) from the closest sensor
                % (Do not test Topography figures)
                if ~strcmpi(Figure.Id.Type, 'Topography') && ~isempty(p)
                    if (norm(p - v) > 0.005)
                        return
                    end
                end
            % Check if sensors are displayed in this figure (as a line object)
            elseif ~isempty(hSensorsMarkers) && ismember(clickObject, hSensorsMarkers)
                % Get the vertex index
                vi = get(clickObject, 'UserData');
            else
                vi = [];
            end
            
            % Convert to real channel indices
            if ~isempty(vi)
                % Is figure used only to display channels
                AllChannelsDisplayed = getappdata(hFig, 'AllChannelsDisplayed');
                % If not all the channels are displayed: need to convert the selected sensor indice
                if ~AllChannelsDisplayed
                    % Get channel indice (in Channel array)
                    if (vi <= length(Figure.SelectedChannels))
                        iSelChan = Figure.SelectedChannels(vi);
                    end
                else
                    AllModalityChannels = good_channel(GlobalData.DataSet(iDS).Channel, [], Figure.Id.Modality);
                    iSelChan = AllModalityChannels(vi);
                end
            end
            
            % Check if sensors where marked to be selected somewhere else in the code
            if isempty(iSelChan)
                iSelChan = getappdata(hFig, 'ChannelsToSelect');
            end
            % Reset this field
            setappdata(hFig, 'ChannelsToSelect', []);
            
            % Select sensor
            if ~isempty(iSelChan)
                % Get channel names
                SelChan = {GlobalData.DataSet(iDS).Channel(iSelChan).Name};
                % SHIFT + CLICK: Display time-frequency map for the sensor
                if strcmpi(get(hFig, 'SelectionType'), 'extend')
                    % Select only the last sensor
                    bst_figures('SetSelectedRows', SelChan);
                    % Time-freq: view a the sensor in a separate figure
                    if ~isempty(TfInfo) && ~isempty(TfInfo.FileName)
                        if ~isempty(strfind(TfInfo.FileName, '_pac_fullmaps'))
                            view_pac(TfInfo.FileName, SelChan);
                        elseif ~isempty(strfind(TfInfo.FileName, '_pac'))
                            % Nothing
                        elseif ~isempty(strfind(TfInfo.FileName, '_psd')) || ~isempty(strfind(TfInfo.FileName, '_fft'))
                            view_spectrum(TfInfo.FileName, 'Spectrum', SelChan, 1);
                        else
                            view_timefreq(TfInfo.FileName, 'SingleSensor', SelChan{1}, 0);
                        end
                    end
                % CLICK: Normally select/unselect sensor
                else
                    % If user is editing/moving sensors: select only the new sensor
                    if ~isempty(gChanAlign) && ~gChanAlign.isMeg && isequal(gChanAlign.selectedButton, gChanAlign.hButtonMoveChan)
                        bst_figures('SetSelectedRows', SelChan);
                    else
                        bst_figures('ToggleSelectedRow', SelChan);
                    end
                    % If there are intra electrodes defined, and if the channels are SEEG/ECOG: try to select the electrode in panel_ieeg
                    if ~isempty(GlobalData.DataSet(iDS).IntraElectrodes) && all(~cellfun(@isempty, {GlobalData.DataSet(iDS).Channel(iSelChan).Group}))
                        selGroup = unique({GlobalData.DataSet(iDS).Channel(iSelChan).Group});
                        panel_ieeg('SetSelectedElectrodes', selGroup);
                    end
                end
            end
        end
    % ===== MOUSE HAS MOVED ===== 
    else
        % === COLORMAP HAS CHANGED ===
        if strcmpi(clickAction, 'colorbar')
            % Apply new colormap to all figures
            ColormapInfo = getappdata(hFig, 'Colormap');
            bst_colormaps('FireColormapChanged', ColormapInfo.Type);
            
        % === RIGHT-CLICK + MOVE ===
        elseif strcmpi(clickAction, 'popup')
            % === TOPO: Select channels ===
            if strcmpi(Figure.Id.Type, 'Topography') && ismember(Figure.Id.SubType, {'2DLayout', '2DDisc', '2DSensorCap', '2DElectrodes'})
                % Get selection patch
                hSelPatch = findobj(hAxes, '-depth', 1, 'Tag', 'TopoSelectionPatch');
                if isempty(hSelPatch)
                    return
                elseif (length(hSelPatch) > 1)
                    delete(hSelPatch);
                    return
                end
                % Get selection rectangle
                XBounds = get(hSelPatch, 'XData');
                YBounds = get(hSelPatch, 'YData');
                XBounds = [min(XBounds), max(XBounds)];
                YBounds = [min(YBounds), max(YBounds)];
                % Delete selection patch
                delete(hSelPatch);
                % Find all the sensors that are in that selection rectangle
                if strcmpi(Figure.Id.SubType, '2DLayout')
                    channelLoc = GlobalData.DataSet(iDS).Figure(iFig).Handles.BoxesCenters;
                else
                    channelLoc = GlobalData.DataSet(iDS).Figure(iFig).Handles.MarkersLocs;
                end
                iChannels = find((channelLoc(:,1) >= XBounds(1)) & (channelLoc(:,1) <= XBounds(2)) & ...
                                 (channelLoc(:,2) >= YBounds(1)) & (channelLoc(:,2) <= YBounds(2)));
                % Convert to real channel indices
                if strcmpi(Figure.Id.SubType, '2DLayout')
                    iChannels = GlobalData.DataSet(iDS).Figure(iFig).Handles.SelChanGlobal(iChannels);
                else
                    iChannels = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels(iChannels);
                end
                ChannelNames = {GlobalData.DataSet(iDS).Channel(iChannels).Name};
                % Select those channels
                bst_figures('SetSelectedRows', ChannelNames);
                
            % === SLICES WERE MOVED ===
            else
                % Update "Surfaces" panel
                panel_surface('UpdateSurfaceProperties');
            end
        end
    end 
end


%% ===== FIGURE MOUSE WHEEL =====
function FigureMouseWheelCallback(hFig, event, target)  
    % Parse inputs
    if (nargin < 3) || isempty(target)
        target = [];
    end
    % ONLY FOR 3D AND 2DLayout
    if isempty(event)
        return;
    elseif (event.VerticalScrollCount < 0)
        % ZOOM IN
        Factor = 1 - double(event.VerticalScrollCount) ./ 20;
    elseif (event.VerticalScrollCount > 0)
        % ZOOM OUT
        Factor = 1./(1 + double(event.VerticalScrollCount) ./ 20);
    else
        Factor = 1;
    end
    % Get figure type
    FigureId = getappdata(hFig, 'FigureId');
    % Get axes
    hAxes = findobj(hFig, 'Tag', 'Axes3D');
    % 2D Layout
    if strcmpi(FigureId.SubType, '2DLayout') 
        % Default behavior
        if isempty(target)
            % SHIFT + Wheel: Change the channel gain
            if ismember('shift', get(hFig,'CurrentModifier'))
                target = 'amplitude';
            % CONTROL + Wheel: Change the time window
            elseif ismember('control', get(hFig,'CurrentModifier'))
                target = 'time';
            % Wheel: Just zoom (like in regular figures)
            else
                target = 'camera';
            end
        end
        % Apply zoom factor
        switch (target)
            case 'amplitude'
                figure_topo('UpdateTimeSeriesFactor', hFig, Factor);
            case 'time'
                figure_topo('UpdateTopoTimeWindow', hFig, Factor);
            case 'camera'
                zoom(hAxes, Factor);
        end
    % Else: zoom
    else
        zoom(hAxes, Factor);
    end
end


%% ===== KEYBOARD CALLBACK =====
function FigureKeyPressedCallback(hFig, keyEvent)   
    global GlobalData TimeSliderMutex;
    % Prevent multiple executions
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    set([hFig hAxes], 'BusyAction', 'cancel');
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    if isempty(hFig)
        return
    end
    FigureId = GlobalData.DataSet(iDS).Figure(iFig).Id;
    % ===== GET SELECTED CHANNELS =====
    % Get selected channels
    [SelChan, iSelChan] = GetFigSelectedRows(hFig);
    % Get if figure should contain all the modality sensors (display channel net)
    AllChannelsDisplayed = getappdata(hFig, 'AllChannelsDisplayed');
    % Check if it is a realignment figure
    isAlignFig = ~isempty(findobj(hFig, '-depth', 1, 'Tag', 'AlignToolbar'));
    % If figure is 2D
    is2D = ~strcmpi(FigureId.Type, '3DViz') && ~ismember(FigureId.SubType, {'3DSensorCap', '3DElectrodes', '3DOptodes'});
    isRaw = strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'raw');
        
    % ===== PROCESS BY CHARACTERS =====
    switch (keyEvent.Character)
        % === NUMBERS : VIEW SHORTCUTS ===
        case '0'
            if ~isAlignFig && ~is2D
                SetStandardView(hFig, {'left', 'right', 'top'});
            end
        case '1'
            if ~is2D
                SetStandardView(hFig, 'left');
            end
        case '2'
            if ~is2D
                SetStandardView(hFig, 'bottom');
            end
        case '3'
            if ~is2D
                SetStandardView(hFig, 'right');
            end
        case '4'
            if ~is2D
                SetStandardView(hFig, 'front');
            end
        case '5'
            if ~is2D
                SetStandardView(hFig, 'top');
            end
        case '6'
            if ~is2D
                SetStandardView(hFig, 'back');
            end
        case '7'
            if ~isAlignFig && ~is2D
                SetStandardView(hFig, {'left', 'right'});
            end
        case '8'
            if ~isAlignFig && ~is2D
                SetStandardView(hFig, {'bottom', 'top'});
            end
        case '9'
            if ~isAlignFig && ~is2D
                SetStandardView(hFig, {'front', 'back'});      
            end
        case '.'
            if ~isAlignFig && ~is2D
                SetStandardView(hFig, {'left', 'right', 'top', 'left_intern', 'right_intern', 'bottom'});
            end
        case {'=', 'equal'}
            if ~isAlignFig && ~is2D
                ApplyViewToAllFigures(hFig, 1, 1);
            end
        case '*'
            if ~isAlignFig && ~is2D
                ApplyViewToAllFigures(hFig, 0, 1);
            end
        % === ZOOM ===
        case '+'
            %panel_scout('EditScoutsSize', 'Grow1');
            event.VerticalScrollCount = -2;
            FigureMouseWheelCallback(hFig, event, 'amplitude');
        case '-'
            %panel_scout('EditScoutsSize', 'Shrink1');
            event.VerticalScrollCount = 2;
            FigureMouseWheelCallback(hFig, event, 'amplitude');
            
        otherwise
            % ===== PROCESS BY KEYS =====
            switch (keyEvent.Key)
                % === LEFT, RIGHT, PAGEUP, PAGEDOWN  ===
                case {'leftarrow', 'rightarrow', 'pageup', 'pagedown', 'home', 'end'}
                    if isempty(TimeSliderMutex) || ~TimeSliderMutex
                        panel_time('TimeKeyCallback', keyEvent);
                    end
                    
                % === UP DOWN : Processed by Freq panel ===
                case {'uparrow', 'downarrow'}
                    panel_freq('FreqKeyCallback', keyEvent);
                % === DATABASE NAVIGATOR ===
                case {'f1', 'f2', 'f3', 'f4', 'f6'}
                    if ~isAlignFig 
                        if isRaw
                            panel_time('TimeKeyCallback', keyEvent);
                        else
                            bst_figures('NavigatorKeyPress', hFig, keyEvent);
                        end
                    end
                % === DATA FILES ===
                % CTRL+A : View axis
                case 'a'
                    if ismember('control', keyEvent.Modifier)
                    	ViewAxis(hFig);
                    end 
                % CTRL+D : Dock figure
                case 'd'
                    if ismember('control', keyEvent.Modifier)
                        isDocked = strcmpi(get(hFig, 'WindowStyle'), 'docked');
                        bst_figures('DockFigure', hFig, ~isDocked);
                    end
                % CTRL+E : Sensors and labels
                case 'e'
                    if ~isAlignFig && ismember('control', keyEvent.Modifier) && ~isempty(GlobalData.DataSet(iDS).ChannelFile)
                        hLabels = findobj(hAxes, '-depth', 1, 'Tag', 'SensorsLabels');
                        hElectrodeGrid = findobj(hAxes, 'Tag', 'ElectrodeGrid');
                        isMarkers = ~isempty(findobj(hAxes, '-depth', 1, 'Tag', 'SensorsPatch')) || ~isempty(findobj(hAxes, '-depth', 1, 'Tag', 'SensorsMarkers'));
                        isLabels  = ~isempty(hLabels);
                        % All figures, except "2DLayout"
                        if ~strcmpi(FigureId.SubType, '2DLayout')
                            % Cycle between two modes : Nothing, Labels
                            if ~isempty(hElectrodeGrid)
                                ViewSensors(hFig, 0, ~isLabels);
                            % Cycle between three modes : Nothing, Sensors, Sensors+labels
                            else
                                % SEEG/ECOG: Display 3D Electrodes
                                if ~isempty(FigureId.Modality) && ismember(FigureId.Modality, {'SEEG','ECOG'})
                                    view_channels(GlobalData.DataSet(iDS).ChannelFile, FigureId.Modality, 1, 0, hFig, 1);
                                elseif isMarkers && isLabels
                                    ViewSensors(hFig, 0, 0);
                                elseif isMarkers
                                    ViewSensors(hFig, 1, 1);
                                else
                                    ViewSensors(hFig, 1, 0);
                                end
                            end
                        % "2DLayout"
                        else
                            isLabelsVisible = strcmpi(get(hLabels(1), 'Visible'), 'on');
                            if isLabelsVisible
                                set(hLabels, 'Visible', 'off');
                            else
                                set(hLabels, 'Visible', 'on');
                            end
                        end
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
                % M : Jump to maximum
                case 'm'
                    JumpMaximum(hFig);
                % CTRL+R : Recordings time series
                case 'r'
                    if ismember('control', keyEvent.Modifier) && ~isempty(GlobalData.DataSet(iDS).DataFile) && ~strcmpi(FigureId.Modality, 'MEG GRADNORM')
                        view_timeseries(GlobalData.DataSet(iDS).DataFile, FigureId.Modality);
                    end
                % CTRL+S : Sources (first results file)
                case 's'
                    if ismember('control', keyEvent.Modifier)
                        bst_figures('ViewResults', hFig); 
                    end
                % CTRL+T : Default topography
                case 't'
                    if ismember('control', keyEvent.Modifier) 
                        bst_figures('ViewTopography', hFig); 
                    end
                    
                % === SCROLL MRI CUTS ===
                case {'x','y','z'}
                    % Amount to scroll: +1 (no modifier) or -1 (shift key)
                    if ismember('shift', keyEvent.Modifier)
                        value = -1;
                    else
                        value = 1;
                    end
                    % Get dimension
                    switch (keyEvent.Key)
                        case 'x',  dim = 1;
                        case 'y',  dim = 2;
                        case 'z',  dim = 3;
                    end
                    % Get Mri and figure Handles
                    [sMri, TessInfo, iTess, iMri] = panel_surface('GetSurfaceMri', hFig);
                    % If there are anatomical slices in the figure
                    if ~isempty(iTess)
                        % Draw a new X-cut according to the mouse motion
                        posXYZ = [NaN, NaN, NaN];
                        posXYZ(dim) = TessInfo(iTess).CutsPosition(dim) + value;
                        panel_surface('PlotMri', hFig, posXYZ);
                        % Update interface (Surface tab and MRI figure)
                        panel_surface('UpdateSurfaceProperties');
                    end
                    
                % === CHANNELS ===
                % RETURN: VIEW SELECTED CHANNELS
                case 'return'
                    if ~isAlignFig && ~isempty(SelChan) && ~AllChannelsDisplayed
                        TfInfo = getappdata(hFig, 'Timefreq');
                        % Show time series for selected sensors
                        if isempty(TfInfo)
                            figure_timeseries('DisplayDataSelectedChannels', iDS, SelChan, FigureId.Modality);
                        % Show time-frequency map for selected sensors
                        elseif ~isempty(TfInfo.FileName)
                            view_timefreq(TfInfo.FileName, 'SingleSensor', SelChan{1});
                        end
                    end
                % DELETE: SET CHANNELS AS BAD
                case {'delete', 'backspace'}
                    isMulti2dLayout = (isfield(GlobalData.DataSet(iDS).Figure(iFig).Handles, 'hLines') && (length(GlobalData.DataSet(iDS).Figure(iFig).Handles.hLines) >= 2));
                    if ~isAlignFig && ~isempty(SelChan) && ~AllChannelsDisplayed && ~isempty(GlobalData.DataSet(iDS).DataFile) && ...
                            (length(GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels) ~= length(iSelChan)) && ~isMulti2dLayout
                        % Shift+Delete: Mark non-selected as bad
                        newChannelFlag = GlobalData.DataSet(iDS).Measures.ChannelFlag;
                        if ismember('shift', keyEvent.Modifier)
                            newChannelFlag(GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels) = -1;
                            newChannelFlag(iSelChan) = 1;
                        % Delete: Mark selected channels as bad
                        else
                            newChannelFlag(iSelChan) = -1;
                        end
                        % Update channel flag
                        panel_channel_editor('UpdateChannelFlag', GlobalData.DataSet(iDS).DataFile, newChannelFlag);
                        % Reset selection
                        bst_figures('SetSelectedRows', []);
                    end
                % ESCAPE: RESET SELECTION
                case 'escape'
                    % Remove selection cross
                    delete(findobj(hAxes, '-depth', 1, 'tag', 'ptCoordinates'));
                    % Channel selection
                    if ~isAlignFig 
                        % Mark all channels as good
                        if ismember('shift', keyEvent.Modifier)
                            ChannelFlagGood = ones(size(GlobalData.DataSet(iDS).Measures.ChannelFlag));
                            panel_channel_editor('UpdateChannelFlag', GlobalData.DataSet(iDS).DataFile, ChannelFlagGood);
                        % Reset channel selection
                        else
                            bst_figures('SetSelectedRows', []);
                        end
                    end
            end
    end
    % Restore events
    if ~isempty(hFig) && ishandle(hFig) && ~isempty(hAxes) && ishandle(hAxes)
        set([hFig hAxes], 'BusyAction', 'queue');
    end
end


%% ===== RESET VIEW =====
% Restore initial camera position and orientation
function ResetView(hFig)
    global GlobalData;
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    if isempty(hFig)
        return
    end
    % Get axes
    hAxes = findobj(hFig, 'Tag', 'Axes3D');
    % Reset zoom
    zoom(hAxes, 'out');    
    % 2D LAYOUT: separate function
    if strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.SubType, '2DLayout')
        GlobalData.DataSet(iDS).Figure(iFig).Handles.DisplayFactor = 1;
        GlobalData.Preferences.TopoLayoutOptions.TimeWindow = abs(GlobalData.UserTimeWindow.Time(2) - GlobalData.UserTimeWindow.Time(1)) .* [-1, 1];
        figure_topo('UpdateTopo2dLayout', iDS, iFig);
        return
    % 3D figures
    else
        % Get Axes handle
        hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
        set(hFig, 'CurrentAxes', hAxes);
        % Camera basic orientation
        SetStandardView(hFig, 'top');
        % Try to find a light source. If found, align it with the camera
        camlight(findobj(hAxes, '-depth', 1, 'Tag', 'FrontLight'), 'headlight');
    end
end


%% ===== SET STANDARD VIEW =====
function SetStandardView(hFig, viewNames)
    % Make sure that viewNames is a cell array
    if ischar(viewNames)
        viewNames = {viewNames};
    end
    % Get Axes handle
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    % Get the data types displayed in this figure
    ColormapInfo = getappdata(hFig, 'Colormap');
    % Get surface information
    TessInfo = getappdata(hFig, 'Surface');

    % ===== ANATOMY ORIENTATION =====
    % If MRI displayed in the figure, use the orientation of the slices, instead of the orientation of the axes
    R = eye(3);
    % Get the mri surface
    Ranat = [];
    if ismember('anatomy', ColormapInfo.AllTypes)
        iTess = find(strcmpi({TessInfo.Name}, 'Anatomy'));
        if ~isempty(iTess)
            % Get the subject MRI structure in memory
            sMri = bst_memory('GetMri', TessInfo(iTess).SurfaceFile);
            % Calculate transformation: SCS => MRI  (inverse MRI => SCS)
            Ranat = pinv(sMri.SCS.R);
        end
    end
    % Displaying a surface: Load the SCS field from the MRI
    if isempty(Ranat) && ~isempty(TessInfo) && ~isempty(TessInfo(1).SurfaceFile)
        % Get subject
        sSubject = bst_get('SurfaceFile', TessInfo(1).SurfaceFile);
        % If there is an MRI associated with it
        if ~isempty(sSubject) && ~isempty(sSubject.Anatomy) && ~isempty(sSubject.Anatomy(sSubject.iAnatomy).FileName)
            % Load the SCS+MNI transformation from this file
            sMri = load(file_fullpath(sSubject.Anatomy(sSubject.iAnatomy).FileName), 'NCS', 'SCS', 'Comment');
            if isfield(sMri, 'NCS') && isfield(sMri.NCS, 'R') && ~isempty(sMri.NCS.R) && isfield(sMri, 'SCS') && isfield(sMri.SCS, 'R') && ~isempty(sMri.SCS.R)
                % Calculate the SCS => MNI rotation   (inverse(MRI=>SCS) * MRI=>MNI)
                Ranat = sMri.NCS.R * pinv(sMri.SCS.R);
            end
        end
    end
    % Get the rotation to change orientation
    if ~isempty(Ranat)
        R = [0 1 0;-1 0 0; 0 0 1] * Ranat;
    end    
    
    % ===== MOVE CAMERA =====
    % Apply the first orientation to the target figure
    switch lower(viewNames{1})
        case {'left', 'right_intern'}
            newView = [0,1,0];
            newCamup = [0 0 1];
        case {'right', 'left_intern'}
            newView = [0,-1,0];
            newCamup = [0 0 1];
        case 'back'
            newView = [-1,0,0];
            newCamup = [0 0 1];
        case 'front'
            newView = [1,0,0];
            newCamup = [0 0 1];
        case 'bottom'
            newView = [0,0,-1];
            newCamup = [1 0 0];
        case 'top'
            newView = [0,0,1];
            newCamup = [1 0 0];
    end
    % Update camera position
    view(hAxes, newView * R);
    camup(hAxes, double(newCamup * R));
    % Update head light position
    camlight(findobj(hAxes, '-depth', 1, 'Tag', 'FrontLight'), 'headlight');
    % Select only one hemisphere
    if any(ismember(viewNames, {'right_intern', 'left_intern'}))
        bst_figures('SetCurrentFigure', hFig, '3D');
        drawnow;
        if strcmpi(viewNames{1}, 'right_intern')
            panel_surface('SelectHemispheres', 'right');
        elseif strcmpi(viewNames{1}, 'left_intern')
            panel_surface('SelectHemispheres', 'left');
        else
            panel_surface('SelectHemispheres', 'none');
        end
    end
    
    % ===== OTHER FIGURES =====
    % If there are other view to represent
    if (length(viewNames) > 1)
        hClones = bst_figures('GetClones', hFig);
        % Process the other required views
        for i = 2:length(viewNames)
            if ~isempty(hClones)
                % Use an already cloned figure
                hNewFig = hClones(1);
                hClones(1) = [];
            else
                % Clone figure
                hNewFig = bst_figures('CloneFigure', hFig);
            end
            % Set orientation
            SetStandardView(hNewFig, viewNames(i));
        end
        % If there are some cloned figures left : close them
        if ~isempty(hClones)
            close(hClones);
            % Update figures layout
            gui_layout('Update');
        end
    end
end


%% ===== GET COORDINATES =====
function GetCoordinates(varargin)
    % Show Coordinates panel
    gui_show('panel_coordinates', 'JavaWindow', 'Get coordinates', [], 0, 1, 0);
    % Start point selection
    panel_coordinates('SetSelectionState', 1);
end


%% ===== APPLY VIEW TO ALL FIGURES =====
function ApplyViewToAllFigures(hSrcFig, isView, isSurfProp)
    % Get Axes handle
    hSrcAxes = findobj(hSrcFig, '-depth', 1, 'Tag', 'Axes3D');
    % Get surface descriptions
    SrcTessInfo = getappdata(hSrcFig, 'Surface');
    % Get all figures
    hAllFig = bst_figures('GetFiguresByType', {'3DViz', 'Topography', 'MriViewer'});
    hAllFig = setdiff(hAllFig, hSrcFig);
    % Process all figures
    for i = 1:length(hAllFig)
        % Get Axes handle
        hDestFig = hAllFig(i);
        hDestAxes = findobj(hDestFig, '-depth', 1, 'Tag', 'Axes3D');
        is3D = ~isempty(hDestAxes);
        % Check figure type
        FigureId = getappdata(hDestFig, 'FigureId');
        if isempty(FigureId) || (strcmpi(FigureId.Type, 'Topography') && ~ismember(FigureId.SubType, {'3DElectrodes', '3DSensorCap', '3DOptodes'}))
            continue;
        end
        
        % === COPY CAMERA ===
        if isView && is3D
            % Copy view angle
            [az,el] = view(hSrcAxes);
            view(hDestAxes, az, el);
            % Copy cam position
            pos = campos(hSrcAxes);
            campos(hDestAxes, pos);
            % Copy cam target
            tar = camtarget(hSrcAxes);
            camtarget(hDestAxes, tar);
            % Copy cam up vector
            up = camup(hSrcAxes);
            camup(hDestAxes, up);
            % Copy zoom factor
            camva = get(hSrcAxes, 'CameraViewAngle');
            set(hDestAxes, 'CameraViewAngle', camva);

            % Update head light position
            camlight(findobj(hDestAxes, '-depth', 1, 'Tag', 'FrontLight'), 'headlight');
        end
        
        % === COPY SURFACES PROPERTIES ===
        if isSurfProp
            DestTessInfo = getappdata(hDestFig, 'Surface');
            % Process each surface of the figure
            for iTess = 1:length(DestTessInfo)
                % Find surface name in source figure
                if (length(DestTessInfo) > 1)
                    iTessInSrc = find(strcmpi(DestTessInfo(iTess).Name, {SrcTessInfo.Name}));
                else
                    iTessInSrc = 1;
                end
                % If surface is also available in source figure
                if ~isempty(iTessInSrc)
                    % Copy surf properties
                    iTessInSrc = iTessInSrc(1);
                    DestTessInfo(iTess).SurfAlpha        = SrcTessInfo(iTessInSrc).SurfAlpha;
                    DestTessInfo(iTess).DataAlpha        = SrcTessInfo(iTessInSrc).DataAlpha;
                    DestTessInfo(iTess).SizeThreshold    = SrcTessInfo(iTessInSrc).SizeThreshold;
                    % Copy only if surfaces have the same type                    
                    if strcmpi(DestTessInfo(iTess).Name, SrcTessInfo(iTessInSrc).Name)
                        DestTessInfo(iTess).SurfShowSulci    = SrcTessInfo(iTessInSrc).SurfShowSulci;
                        DestTessInfo(iTess).SurfShowEdges    = SrcTessInfo(iTessInSrc).SurfShowEdges;
                        DestTessInfo(iTess).AnatomyColor     = SrcTessInfo(iTessInSrc).AnatomyColor;
                        DestTessInfo(iTess).SurfSmoothValue  = SrcTessInfo(iTessInSrc).SurfSmoothValue;
                        DestTessInfo(iTess).CutsPosition     = SrcTessInfo(iTessInSrc).CutsPosition;
                        DestTessInfo(iTess).Resect           = SrcTessInfo(iTessInSrc).Resect;
                    end
                    % Do not update data threshold for stat surfaces (has to remain 0)
                    if ~isempty(DestTessInfo(iTess).DataSource.FileName) && ~ismember(file_gettype(DestTessInfo(iTess).DataSource.FileName), {'pdata','presults','ptimfreq','pmatrix'})
                        DestTessInfo(iTess).DataThreshold    = SrcTessInfo(iTessInSrc).DataThreshold;
                    end
                    % Update surfaces structure
                    setappdata(hDestFig, 'Surface', DestTessInfo);
                    % Update display
                    if strcmpi(DestTessInfo(iTess).Name, 'Anatomy')
                        if strcmpi(FigureId.Type, 'MriViewer')
                            figure_mri('UpdateMriDisplay', hDestFig, [], DestTessInfo, iTess);
                        else
                            UpdateMriDisplay(hDestFig, [], DestTessInfo, iTess);
                        end
                    else
                        UpdateSurfaceAlpha(hDestFig, iTess);
                        UpdateSurfaceColor(hDestFig, iTess);
                    end
                    % Update scouts displayed on this surfce
                    panel_scout('UpdateScoutsVertices', DestTessInfo(iTess).SurfaceFile);
                end
            end
        end
    end
end


%% ===== POPUP MENU =====
% Show a popup dialog about the target 3DViz figure
function DisplayFigurePopup(hFig)
    import java.awt.event.KeyEvent;
    import javax.swing.KeyStroke;
    import org.brainstorm.icon.*;
    
    global GlobalData;
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    if isempty(iDS)
        return
    end
    % Get DataFile associated with this figure
    DataFile    = GlobalData.DataSet(iDS).DataFile;
    ResultsFile = getappdata(hFig, 'ResultsFile');
    Dipoles     = getappdata(hFig, 'Dipoles');
    % Get surfaces information
    TessInfo = getappdata(hFig, 'Surface');
    TsInfo   = getappdata(hFig, 'TsInfo');
    % Get time freq information
    TfInfo = getappdata(hFig, 'Timefreq');
    if ~isempty(TfInfo)
        TfFile = TfInfo.FileName;
    else
        TfFile = [];
    end

    % Create popup menu
    jPopup = java_create('javax.swing.JPopupMenu');
    
    % Get selected channels
    [SelChan, iSelChan] = GetFigSelectedRows(hFig);   
    % Menu title: Selected sensors
    if (length(iSelChan) == 1)
        menuTitle = sprintf('Channel #%d: %s', iSelChan, SelChan{1});
        jTitle = gui_component('Label', jPopup, [], ['<HTML><B>' menuTitle '</B>']);
        jTitle.setBorder(javax.swing.BorderFactory.createEmptyBorder(5,35,0,0));
        jPopup.addSeparator();
    end

    % ==== DISPLAY OTHER FIGURES ====
    if ~isempty(TfFile)
        % Check the type of data: recordings or sources
        [sStudyTf, iStudyTf, iTf] = bst_get('TimefreqFile', TfFile);
        % Display source menus only for sources
        if ~isempty(sStudyTf) && strcmpi(sStudyTf.Timefreq(iTf).DataType, 'results')
            % Get selected vertex
            iVertex = panel_coordinates('SelectPoint', hFig, 0);
            % Menu for selected vertex
            if ~isempty(iVertex)
                if isempty(strfind(TfFile, '_psd')) && isempty(strfind(TfFile, '_fft')) && isempty(strfind(TfFile, '_pac'))
                    jItem = gui_component('MenuItem', jPopup, [], 'Source: Time-frequency', IconLoader.ICON_TIMEFREQ, [], @(h,ev)bst_call(@view_timefreq, TfFile, 'SingleSensor', iVertex, 1));
                    jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_SHIFT, 0));
                    gui_component('MenuItem', jPopup, [], 'Source: Time series',    IconLoader.ICON_DATA,     [], @(h,ev)bst_call(@view_spectrum, TfFile, 'TimeSeries', iVertex, 1));
                end
                if isempty(strfind(TfFile, '_pac'))
                    gui_component('MenuItem', jPopup, [], 'Source: Power spectrum', IconLoader.ICON_SPECTRUM, [], @(h,ev)bst_call(@view_spectrum, TfFile, 'Spectrum', iVertex, 1));
                end
                if ~isempty(strfind(TfFile, '_pac_fullmaps'))
                    jItem = gui_component('MenuItem', jPopup, [], 'Sensor PAC map', IconLoader.ICON_PAC, [], @(h,ev)view_pac(TfFile, iVertex, 'DynamicPAC', [], 1));
                    jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_SHIFT, 0));
                end
                if (jPopup.getComponentCount() > 0)
                    jPopup.addSeparator();
                end
            end
        end
    end
    % Only for MEG and EEG time series
    Modality = GlobalData.DataSet(iDS).Figure(iFig).Id.Modality;  
    FigureType = GlobalData.DataSet(iDS).Figure(iFig).Id.Type;  
    if ~isempty(DataFile) && ~ismember(Modality, {'MEG GRADNORM', 'MEG GRAD2', 'MEG GRAD3'})
        % Get study
        sStudy = bst_get('AnyFile', DataFile);
        % === View RECORDINGS ===
        jItem = gui_component('MenuItem', jPopup, [], [Modality ' Recordings'], IconLoader.ICON_TS_DISPLAY, [], @(h,ev)view_timeseries(DataFile, Modality));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_R, KeyEvent.CTRL_MASK));
        % === View TOPOGRAPHY ===
        if isempty(TfFile) && ~strcmpi(FigureType, 'Topography')
            jItem = gui_component('MenuItem', jPopup, [], [Modality ' Topography'], IconLoader.ICON_TOPOGRAPHY, [], @(h,ev)bst_figures('ViewTopography',hFig));
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_T, KeyEvent.CTRL_MASK));
        end
        % === View SOURCES ===
        if isempty(TfFile) && isempty(ResultsFile) && ~isempty(sStudy.Result)
            jItem = gui_component('MenuItem', jPopup, [], 'View sources', IconLoader.ICON_RESULTS, [], @(h,ev)bst_figures('ViewResults',hFig));
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_S, KeyEvent.CTRL_MASK));
        end
        % === VIEW PAC/TIME-FREQ ===
        if strcmpi(FigureType, 'Topography') && ~isempty(SelChan) && ~isempty(Modality) && (Modality(1) ~= '$')
            if ~isempty(strfind(TfFile, '_pac_fullmaps'))
                jItem = gui_component('MenuItem', jPopup, [], 'Sensor PAC map', IconLoader.ICON_PAC, [], @(h,ev)view_pac(TfFile, SelChan{1}));
                jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_SHIFT, 0));
            elseif ~isempty(strfind(TfFile, '_pac'))
                % Nothing
            elseif ~isempty(strfind(TfFile, '_psd')) || ~isempty(strfind(TfFile, '_fft'))
                jItem = gui_component('MenuItem', jPopup, [], 'Sensor spectrum', IconLoader.ICON_SPECTRUM, [], @(h,ev)view_spectrum(TfFile, 'Spectrum', SelChan{1}, 1));
                jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_SHIFT, 0));
            elseif ~isempty(TfFile) && (~isfield(TfInfo, 'RefRowName') || isempty(TfInfo.RefRowName))
                jItem = gui_component('MenuItem', jPopup, [], 'Sensor time-freq map', IconLoader.ICON_TIMEFREQ, [], @(h,ev)view_timefreq(TfFile, 'SingleSensor', SelChan{1}, 0));
                jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_SHIFT, 0));
            end
        end
        jPopup.addSeparator();
    end

    % ==== MENU: 2DLAYOUT ====
    if strcmpi(FigureType, 'Topography') && strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.SubType, '2DLayout')
        % Get current options
        TopoLayoutOptions = bst_get('TopoLayoutOptions');
        % Create menu
        jMenu = gui_component('Menu', jPopup, [], '2DLayout options', IconLoader.ICON_2DLAYOUT);
        gui_component('MenuItem', jMenu, [], 'Set time window...', [], [], @(h,ev)figure_topo('SetTopoLayoutOptions', 'TimeWindow'));
        jItem = gui_component('CheckBoxMenuItem', jMenu, [], 'White background', [], [], @(h,ev)figure_topo('SetTopoLayoutOptions', 'WhiteBackground', ~TopoLayoutOptions.WhiteBackground));
        jItem.setSelected(TopoLayoutOptions.WhiteBackground);
        jItem = gui_component('CheckBoxMenuItem', jMenu, [], 'Show reference lines', [], [], @(h,ev)figure_topo('SetTopoLayoutOptions', 'ShowRefLines', ~TopoLayoutOptions.ShowRefLines));
        jItem.setSelected(TopoLayoutOptions.ShowRefLines);
        jItem = gui_component('CheckBoxMenuItem', jMenu, [], 'Show legend', [], [], @(h,ev)figure_topo('SetTopoLayoutOptions', 'ShowLegend', ~TopoLayoutOptions.ShowLegend));
        jItem.setSelected(TopoLayoutOptions.ShowLegend);
        jPopup.addSeparator();
    end
    
    % ==== MENU CONTOUR LINES =====
    if strcmpi(FigureType, 'Topography') && ismember(GlobalData.DataSet(iDS).Figure(iFig).Id.SubType, {'2DSensorCap', '2DDisc'})
        % Get current options
        TopoLayoutOptions = bst_get('TopoLayoutOptions');
        % Create menu
        jMenu = gui_component('Menu', jPopup, [], 'Contour lines', IconLoader.ICON_TOPOGRAPHY);
        jItem = gui_component('CheckBoxMenuItem', jMenu, [], 'No contour lines', [], [], @(h,ev)figure_topo('SetTopoLayoutOptions', 'ContourLines', 0));
        jItem.setSelected(TopoLayoutOptions.ContourLines == 0);
        jItem = gui_component('CheckBoxMenuItem', jMenu, [], '5 lines', [], [], @(h,ev)figure_topo('SetTopoLayoutOptions', 'ContourLines', 5));
        jItem.setSelected(TopoLayoutOptions.ContourLines == 5);
        jItem = gui_component('CheckBoxMenuItem', jMenu, [], '10 lines', [], [], @(h,ev)figure_topo('SetTopoLayoutOptions', 'ContourLines', 10));
        jItem.setSelected(TopoLayoutOptions.ContourLines == 10);
        jItem = gui_component('CheckBoxMenuItem', jMenu, [], '15 lines', [], [], @(h,ev)figure_topo('SetTopoLayoutOptions', 'ContourLines', 15));
        jItem.setSelected(TopoLayoutOptions.ContourLines == 15);
        jItem = gui_component('CheckBoxMenuItem', jMenu, [], '20 lines', [], [], @(h,ev)figure_topo('SetTopoLayoutOptions', 'ContourLines', 20));
        jItem.setSelected(TopoLayoutOptions.ContourLines == 20);
        jPopup.addSeparator();
    end
    
    % ==== MENU: CHANNELS =====
    % Check if it is a realignment figure
    isAlignFig = ~isempty(findobj(hFig, '-depth', 1, 'Tag', 'AlignToolbar'));
    % Are there multiple 2DLayout overlays in this figure
    isMulti2dLayout = (isfield(GlobalData.DataSet(iDS).Figure(iFig).Handles, 'hLines') && (length(GlobalData.DataSet(iDS).Figure(iFig).Handles.hLines) >= 2));
    % Not for align figures
    if ~isAlignFig && ~isempty(GlobalData.DataSet(iDS).ChannelFile)
        jMenuChannels = gui_component('Menu', jPopup, [], 'Channels', IconLoader.ICON_CHANNEL);
        % ==== Selected channels submenu ====
        isMarkers = ~isempty(GlobalData.DataSet(iDS).Figure(iFig).Handles.hSensorMarkers) || ...
                    ismember(GlobalData.DataSet(iDS).Figure(iFig).Id.SubType, {'2DLayout', '3DElectrodes', '3DOptodes', '2DElectrodes'});
        % Time-frequency: Show selected sensor
        if ~isempty(TfFile) && isMarkers && ~isempty(SelChan)
            jItem = gui_component('MenuItem', jMenuChannels, [], 'View selected', IconLoader.ICON_TIMEFREQ, [], @(h,ev)view_timefreq(TfFile, 'SingleSensor', SelChan{1}));
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_ENTER, 0)); % ENTER
        end
        % Excludes figures without selection and display-only figures (modality name starts with '$')
        if ~isempty(DataFile) && isMarkers && ~isempty(SelChan) && ~isempty(Modality) && (Modality(1) ~= '$') 
            % === VIEW TIME SERIES ===
            jItem = gui_component('MenuItem', jMenuChannels, [], 'View selected', IconLoader.ICON_TS_DISPLAY, [], @(h,ev)figure_timeseries('DisplayDataSelectedChannels', iDS, SelChan, Modality));
            if isempty(TfFile)
                jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_ENTER, 0)); % ENTER
            end
            % Not for multiple 2DLayout
            if ~isMulti2dLayout
                % === SET SELECTED AS BAD CHANNELS ===
                newChannelFlag = GlobalData.DataSet(iDS).Measures.ChannelFlag;
                newChannelFlag(iSelChan) = -1;
                jItem = gui_component('MenuItem', jMenuChannels, [], 'Mark selected as bad', IconLoader.ICON_BAD, [], @(h,ev)panel_channel_editor('UpdateChannelFlag', DataFile, newChannelFlag));
                jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_DELETE, 0)); % DEL
                % === SET NON-SELECTED AS BAD CHANNELS ===
                newChannelFlag = GlobalData.DataSet(iDS).Measures.ChannelFlag;
                newChannelFlag(GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels) = -1;
                newChannelFlag(iSelChan) = 1;
                jItem = gui_component('MenuItem', jMenuChannels, [], 'Mark non-selected as bad', IconLoader.ICON_BAD, [], @(h,ev)panel_channel_editor('UpdateChannelFlag', DataFile, newChannelFlag));
                jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_DELETE, KeyEvent.SHIFT_MASK));
            end
            % === RESET SELECTION ===
            jItem = gui_component('MenuItem', jMenuChannels, [], 'Reset selection', IconLoader.ICON_SURFACE, [], @(h,ev)bst_figures('SetSelectedRows', []));
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_ESCAPE, 0)); % ESCAPE
        end
        % Separator if previous items
        if (jMenuChannels.getItemCount() > 0)
            jMenuChannels.addSeparator();
        end
        
        % ==== CHANNEL FLAG =====
        if ~isempty(DataFile) && isMarkers && ~isMulti2dLayout
            % ==== MARK ALL CHANNELS AS GOOD ====
            ChannelFlagGood = ones(size(GlobalData.DataSet(iDS).Measures.ChannelFlag));
            jItem = gui_component('MenuItem', jMenuChannels, [], 'Mark all channels as good', IconLoader.ICON_GOOD, [], @(h, ev)panel_channel_editor('UpdateChannelFlag', GlobalData.DataSet(iDS).DataFile, ChannelFlagGood));
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_ESCAPE, KeyEvent.SHIFT_MASK));
            % ==== EDIT CHANNEL FLAG ====
            gui_component('MenuItem', jMenuChannels, [], 'Edit good/bad channels...', IconLoader.ICON_GOODBAD, [], @(h,ev)gui_edit_channelflag(DataFile));
            % Separator if previous items
            if (jMenuChannels.getItemCount() > 0)
                jMenuChannels.addSeparator();
            end
        end
        
        % ==== View Sensors ====
        % Check if there are already 3DElectrodes displayed
        hElectrodeGrid = findobj(hFig, 'Tag', 'ElectrodeGrid');
        % 2DLayout
        if strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.SubType, '2DLayout')
            % Menu "View sensor labels"
            isLabels = ~isempty(GlobalData.DataSet(iDS).Figure(iFig).Handles.hSensorLabels);
            if isLabels
                % Get current state
                isLabelsVisible = strcmpi(get(GlobalData.DataSet(iDS).Figure(iFig).Handles.hSensorLabels(1), 'Visible'), 'on');
                if isLabelsVisible
                    targetVisible = 'off';
                else
                    targetVisible = 'on';
                end
                % Create menu
                jItem = gui_component('CheckBoxMenuItem', jMenuChannels, [], 'Display labels', IconLoader.ICON_CHANNEL_LABEL, [], @(h,ev)set(GlobalData.DataSet(iDS).Figure(iFig).Handles.hSensorLabels, 'Visible', targetVisible));
                jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_E, KeyEvent.CTRL_MASK));
                jItem.setSelected(isLabelsVisible);
            end
        % 3DElectrodes
        elseif ~isempty(hElectrodeGrid)
            % Menu "View sensor labels"
            isLabels = ~isempty(GlobalData.DataSet(iDS).Figure(iFig).Handles.hSensorLabels);
            jItem = gui_component('CheckBoxMenuItem', jMenuChannels, [], 'Display labels', IconLoader.ICON_CHANNEL_LABEL, [], @(h,ev)ViewSensors(hFig, [], ~isLabels));
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_E, KeyEvent.CTRL_MASK));
            jItem.setSelected(isLabels);
            % Configure 3D electrode display
            jMenuChannels.addSeparator();
            gui_component('MenuItem', jMenuChannels, [], 'Configure display', IconLoader.ICON_CHANNEL, [], @(h,ev)SetElectrodesConfig(hFig));
        % Other figures
        else
            % Menu "View sensors"
            jItem = gui_component('CheckBoxMenuItem', jMenuChannels, [], 'Display sensors', IconLoader.ICON_CHANNEL, [], @(h,ev)ViewSensors(hFig, ~isMarkers, []));
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_E, KeyEvent.CTRL_MASK));
            jItem.setSelected(isMarkers);
            % Menu "View sensor labels"
            isLabels = ~isempty(GlobalData.DataSet(iDS).Figure(iFig).Handles.hSensorLabels);
            jItem = gui_component('CheckBoxMenuItem', jMenuChannels, [], 'Display labels', IconLoader.ICON_CHANNEL_LABEL, [], @(h,ev)ViewSensors(hFig, [], ~isLabels));
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_E, KeyEvent.CTRL_MASK));
            jItem.setSelected(isLabels);
            % View ECOG/SEEG
            AllTypes = unique({GlobalData.DataSet(iDS).Channel.Type});
            if ~isempty(AllTypes) && ismember('ECOG', AllTypes)
                ChannelFile = GlobalData.DataSet(iDS).ChannelFile;
                gui_component('MenuItem', jMenuChannels, [], 'ECOG contacts', IconLoader.ICON_CHANNEL, [], @(h,ev)view_channels(ChannelFile, 'ECOG', 1, 0, hFig, 1));
            end
            if ~isempty(AllTypes) && ismember('SEEG', AllTypes)
                ChannelFile = GlobalData.DataSet(iDS).ChannelFile;
                gui_component('MenuItem', jMenuChannels, [], 'SEEG contacts', IconLoader.ICON_CHANNEL, [], @(h,ev)view_channels(ChannelFile, 'SEEG', 1, 0, hFig, 1));
            end
        end
    end
    
    % ==== MENU: MONTAGE ====
    if strcmpi(FigureType, 'Topography') && ~isempty(Modality) && (Modality(1) ~= '$') && (isempty(TsInfo) || isempty(TsInfo.RowNames))
        jMenuMontage = gui_component('Menu', jPopup, [], 'Montage', IconLoader.ICON_TS_DISPLAY_MODE);
        panel_montage('CreateFigurePopupMenu', jMenuMontage, hFig);
    end
    
    % ==== MENU: COLORMAPS ====
    % Create the colormaps menus
    bst_colormaps('CreateAllMenus', jPopup, hFig, 0);
    
    % ==== MENU: MRI DISPLAY ====
    ColormapInfo = getappdata(hFig, 'Colormap');
    if ismember('anatomy', ColormapInfo.AllTypes)
        jMenuMri = gui_component('Menu', jPopup, [], 'MRI display', IconLoader.ICON_ANATOMY);
        MriOptions = bst_get('MriOptions');
        % MIP: Anatomy
        jItem = gui_component('CheckBoxMenuItem', jMenuMri, [], 'MIP: Anatomy', [], [], @(h,ev)MipAnatomy_Callback(hFig,ev));
        jItem.setSelected(MriOptions.isMipAnatomy);
        % MIP: Functional
        isOverlay = any(ismember({'source','stat1','stat2','timefreq','eeg','meg'}, ColormapInfo.AllTypes));
        if isOverlay
            jItem = gui_component('checkboxmenuitem', jMenuMri, [], 'MIP: Functional', [], [], @(h,ev)MipFunctional_Callback(hFig,ev));
            jItem.setSelected(MriOptions.isMipFunctional);
        end
        % Smooth factor
        if isOverlay
            jMenuMri.addSeparator();
            jItem0 = gui_component('radiomenuitem', jMenuMri, [], 'Smooth: None', [], [], @(h,ev)SetMriSmooth(hFig, 0));
            jItem1 = gui_component('radiomenuitem', jMenuMri, [], 'Smooth: 1',    [], [], @(h,ev)SetMriSmooth(hFig, 1));
            jItem2 = gui_component('radiomenuitem', jMenuMri, [], 'Smooth: 2',    [], [], @(h,ev)SetMriSmooth(hFig, 2));
            jItem3 = gui_component('radiomenuitem', jMenuMri, [], 'Smooth: 3',    [], [], @(h,ev)SetMriSmooth(hFig, 3));
            jItem4 = gui_component('radiomenuitem', jMenuMri, [], 'Smooth: 4',    [], [], @(h,ev)SetMriSmooth(hFig, 4));
            jItem5 = gui_component('radiomenuitem', jMenuMri, [], 'Smooth: 5',    [], [], @(h,ev)SetMriSmooth(hFig, 5));
            jItem0.setSelected(MriOptions.OverlaySmooth == 0);
            jItem1.setSelected(MriOptions.OverlaySmooth == 1);
            jItem2.setSelected(MriOptions.OverlaySmooth == 2);
            jItem3.setSelected(MriOptions.OverlaySmooth == 3);
            jItem4.setSelected(MriOptions.OverlaySmooth == 4);
            jItem5.setSelected(MriOptions.OverlaySmooth == 5);
            jMenuMri.addSeparator();
            % MENU: Interpolation MRI/sources
            % Interpolate values
            jMenuInterp = gui_component('Menu', jMenuMri, [], 'Interpolation sources>MRI', IconLoader.ICON_ANATOMY);
            jCheck = gui_component('checkboxmenuitem', jMenuInterp, [], 'Grid interpolation', [], [], @(h,ev)SetGridSmooth(hFig, ~TessInfo(1).DataSource.GridSmooth));
            jCheck.setSelected(TessInfo(1).DataSource.GridSmooth);
            % Distance threshold
            jMenuInterp.addSeparator();
            jItem1 = gui_component('radiomenuitem', jMenuInterp, [], 'Distance threshold: 2mm', [], [], @(h,ev)SetDistanceThresh(hFig, 2));
            jItem2 = gui_component('radiomenuitem', jMenuInterp, [], 'Distance threshold: 4mm', [], [], @(h,ev)SetDistanceThresh(hFig, 4));
            jItem3 = gui_component('radiomenuitem', jMenuInterp, [], 'Distance threshold: 6mm', [], [], @(h,ev)SetDistanceThresh(hFig, 6));
            jItem4 = gui_component('radiomenuitem', jMenuInterp, [], 'Distance threshold: 9mm', [], [], @(h,ev)SetDistanceThresh(hFig, 9));
            jItem1.setSelected(MriOptions.DistanceThresh == 2);
            jItem2.setSelected(MriOptions.DistanceThresh == 4);
            jItem3.setSelected(MriOptions.DistanceThresh == 6);
            jItem4.setSelected(MriOptions.DistanceThresh == 9);
%             jMenuMri = gui_component('Menu', jPopup, [], 'Sources resolution', IconLoader.ICON_ANATOMY);
%             jItem1 = gui_component('radiomenuitem', jMenuMri, [], '1mm',    [], [], @(h,ev)SetMriResolution(hFig, 1));
%             jItem2 = gui_component('radiomenuitem', jMenuMri, [], '2mm',    [], [], @(h,ev)SetMriResolution(hFig, 2));
%             jItem3 = gui_component('radiomenuitem', jMenuMri, [], '3mm',    [], [], @(h,ev)SetMriResolution(hFig, 3));
%             jItem1.setSelected(MriOptions.InterpDownsample == 1);
%             jItem2.setSelected(MriOptions.InterpDownsample == 2);
%             jItem3.setSelected(MriOptions.InterpDownsample == 3);
        end
        jMenuMri.addSeparator();
        % Upsample image
        jItem0 = gui_component('radiomenuitem', jMenuMri, [], 'Upsample: No', [], [], @(h,ev)SetMriUpsample(hFig, 0));
        jItem1 = gui_component('radiomenuitem', jMenuMri, [], 'Upsample: 4x', [], [], @(h,ev)SetMriUpsample(hFig, 4));
        jItem2 = gui_component('radiomenuitem', jMenuMri, [], 'Upsample: 8x', [], [], @(h,ev)SetMriUpsample(hFig, 8));
        jItem0.setSelected(MriOptions.UpsampleImage == 0);
        jItem1.setSelected(MriOptions.UpsampleImage == 4);
        jItem2.setSelected(MriOptions.UpsampleImage == 8);
    end
    
    % ==== MENU: NAVIGATOR ====
    if ~isempty(DataFile) && ~strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'raw')
        jMenuNavigator = gui_component('Menu', jPopup, [], 'Navigator', IconLoader.ICON_NEXT_SUBJECT);
        bst_navigator('CreateNavigatorMenu', jMenuNavigator);
        jPopup.addSeparator();        
    end
    
    % ==== MENU: GET COORDINATES ====
    if ~strcmpi(FigureType, 'Topography')
        gui_component('MenuItem', jPopup, [], 'Get coordinates...', IconLoader.ICON_SCOUT_NEW, [], @GetCoordinates);
    end
    
    % ==== MENU: SNAPSHOT ====
    jMenuSave = gui_component('Menu', jPopup, [], 'Snapshot', IconLoader.ICON_SNAPSHOT);
        % Default output dir
        LastUsedDirs = bst_get('LastUsedDirs');
        DefaultOutputDir = LastUsedDirs.ExportImage;
        % Is there a time window defined
        isTime = ~isempty(GlobalData) && ~isempty(GlobalData.UserTimeWindow.CurrentTime) && ~isempty(GlobalData.UserTimeWindow.Time) ...
                 && (~isempty(DataFile) || ~isempty(ResultsFile) || ~isempty(Dipoles) || ~isempty(TfFile));
        isFreq = ~isempty(GlobalData) && ~isempty(GlobalData.UserFrequencies.iCurrentFreq) && ~isempty(TfFile);
        % === SAVE AS IMAGE ===
        jItem = gui_component('MenuItem', jMenuSave, [], 'Save as image', IconLoader.ICON_SAVE, [], @(h,ev)out_figure_image(hFig));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_I, KeyEvent.CTRL_MASK));
        % === OPEN AS IMAGE ===
        jItem = gui_component('MenuItem', jMenuSave, [], 'Open as image', IconLoader.ICON_IMAGE, [], @(h,ev)out_figure_image(hFig, 'Viewer'));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_J, KeyEvent.CTRL_MASK));
        jItem = gui_component('MenuItem', jMenuSave, [], 'Open as figure', IconLoader.ICON_IMAGE, [], @(h,ev)out_figure_image(hFig, 'Figure'));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_F, KeyEvent.CTRL_MASK));
        % === SAVE AS SSP ===
        if strcmpi(FigureType, 'Topography')
            jMenuSave.addSeparator();
            % Raw file: use it directly
            if strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'raw')
                gui_component('MenuItem', jMenuSave, [], 'Use as SSP projector', IconLoader.ICON_TOPOGRAPHY, [], @(h,ev)panel_ssp_selection('SaveFigureAsSsp', hFig, 1));
            end
            gui_component('MenuItem', jMenuSave, [], 'Save as SSP projector', IconLoader.ICON_TOPOGRAPHY, [], @(h,ev)panel_ssp_selection('SaveFigureAsSsp', hFig, 0));
        end
        % === SAVE SURFACE ===
        if ~isempty(TessInfo)
            if ~isempty([TessInfo.hPatch]) && any([TessInfo.nVertices] > 5)
                jMenuSave.addSeparator();
            end
            % Loop on all the surfaces
            for it = 1:length(TessInfo)
                if ~isempty(TessInfo(it).SurfaceFile) && ~isempty(TessInfo(it).hPatch) && (TessInfo(it).nVertices > 5)
                    jItem = gui_component('MenuItem', jMenuSave, [], ['Save surface: ' TessInfo(it).Name], IconLoader.ICON_SAVE, [], @(h,ev)SaveSurface(TessInfo(it)));
                end
            end
        end
        % === MOVIES ===
        % WARNING: Windows ONLY (for the moment)
        % And NOT for 2DLayout figures
        if (exist('avifile', 'file') || exist('VideoWriter', 'file')) && ~strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.SubType, '2DLayout')
            % Separator
            jMenuSave.addSeparator();
            % === MOVIE (TIME) ===
            if isTime
                gui_component('MenuItem', jMenuSave, [], 'Movie (time): Selected figure', IconLoader.ICON_MOVIE, [], @(h,ev)out_figure_movie(hFig, DefaultOutputDir, 'time'));
                gui_component('MenuItem', jMenuSave, [], 'Movie (time): All figures',     IconLoader.ICON_MOVIE, [], @(h,ev)out_figure_movie(hFig, DefaultOutputDir, 'allfig'));
            end
            % If not topography
            if ~strcmpi(FigureType, 'Topography')
                if isTime
                    jMenuSave.addSeparator();
                end
                % === MOVIE (HORIZONTAL) ===
                gui_component('MenuItem', jMenuSave, [], 'Movie (horizontal)', IconLoader.ICON_MOVIE, [], @(h,ev)out_figure_movie(hFig, DefaultOutputDir, 'horizontal'));
                % === MOVIE (VERTICAL) ===
                gui_component('MenuItem', jMenuSave, [], 'Movie (vertical)', IconLoader.ICON_MOVIE, [], @(h,ev)out_figure_movie(hFig, DefaultOutputDir, 'vertical'));
            end
        end
        % === CONTACT SHEETS ===
        % If time, and if not 2DLayout
        if isTime && ~strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.SubType, '2DLayout')
            jMenuSave.addSeparator();
            gui_component('MenuItem', jMenuSave, [], 'Time contact sheet: Figure', IconLoader.ICON_CONTACTSHEET, [], @(h,ev)view_contactsheet(hFig, 'time', 'fig', DefaultOutputDir));
        end
        % If frequency
        if isFreq && ~strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.SubType, '2DLayout')
            gui_component('MenuItem', jMenuSave, [], 'Frequency contact sheet: Figure', IconLoader.ICON_CONTACTSHEET, [], @(h,ev)view_contactsheet(hFig, 'freq', 'fig', DefaultOutputDir));
        end
        % === CONTACT SHEET / SLICES ===
        if ismember('anatomy', ColormapInfo.AllTypes)
            if isTime
                jMenuSave.addSeparator();
                gui_component('MenuItem', jMenuSave, [], 'Time contact sheet: Coronal',  IconLoader.ICON_CONTACTSHEET, [], @(h,ev)view_contactsheet(hFig, 'time', 'y', DefaultOutputDir));
                gui_component('MenuItem', jMenuSave, [], 'Time contact sheet: Sagittal', IconLoader.ICON_CONTACTSHEET, [], @(h,ev)view_contactsheet(hFig, 'time', 'x', DefaultOutputDir));
                gui_component('MenuItem', jMenuSave, [], 'Time contact sheet: Axial',    IconLoader.ICON_CONTACTSHEET, [], @(h,ev)view_contactsheet(hFig, 'time', 'z', DefaultOutputDir));
            end
            jMenuSave.addSeparator();
            gui_component('MenuItem', jMenuSave, [], 'Volume contact sheet: Coronal',  IconLoader.ICON_CONTACTSHEET, [], @(h,ev)view_contactsheet(hFig, 'volume', 'y', DefaultOutputDir));
            gui_component('MenuItem', jMenuSave, [], 'Volume contact sheet: Sagittal', IconLoader.ICON_CONTACTSHEET, [], @(h,ev)view_contactsheet(hFig, 'volume', 'x', DefaultOutputDir));
            gui_component('MenuItem', jMenuSave, [], 'Volume contact sheet: Axial',    IconLoader.ICON_CONTACTSHEET, [], @(h,ev)view_contactsheet(hFig, 'volume', 'z', DefaultOutputDir));
            % === SAVE OVERLAY ===
            if isOverlay
                jMenuSave.addSeparator();
                gui_component('MenuItem', jMenuSave, [], 'Save overlay as MRI',  IconLoader.ICON_SAVE, [], @(h,ev)figure_mri('ExportOverlay', hFig));
            end
        end
    
    % ==== MENU: FIGURE ====
    jMenuFigure = gui_component('Menu', jPopup, [], 'Figure', IconLoader.ICON_LAYOUT_SHOWALL);
        % Show axes
        isAxis = ~isempty(findobj(hFig, 'Tag', 'AxisXYZ'));
        jItem = gui_component('CheckBoxMenuItem', jMenuFigure, [], 'View axis', IconLoader.ICON_AXES, [], @(h,ev)ViewAxis(hFig, ~isAxis));
        jItem.setSelected(isAxis);
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_A, KeyEvent.CTRL_MASK)); 
        % Show Head points
        isHeadPoints = ~isempty(GlobalData.DataSet(iDS).HeadPoints) && ~isempty(GlobalData.DataSet(iDS).HeadPoints.Loc);
        if isHeadPoints && ~strcmpi(FigureType, 'Topography')
            % Are head points visible
            hHeadPointsMarkers = findobj(GlobalData.DataSet(iDS).Figure(iFig).hFigure, 'Tag', 'HeadPointsMarkers');
            isVisible = ~isempty(hHeadPointsMarkers) && strcmpi(get(hHeadPointsMarkers, 'Visible'), 'on');
            jItem = gui_component('CheckBoxMenuItem', jMenuFigure, [], 'View head points', IconLoader.ICON_CHANNEL, [], @(h,ev)ViewHeadPoints(hFig, ~isVisible));
            jItem.setSelected(isVisible);
        end
        jMenuFigure.addSeparator();
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

    % ==== MENU: VIEWS ====    
    % Not for Topography
    if ~strcmpi(FigureType, 'Topography')
        jMenuView = gui_component('Menu', jPopup, [], 'Views', IconLoader.ICON_AXES);
        % Check if it is a realignment figure
        isAlignFigure = ~isempty(findobj(hFig, 'Tag', 'AlignToolbar'));
        % STANDARD VIEWS
        jItemViewLeft   = gui_component('MenuItem', jMenuView, [], 'Left',   [], [], @(h,ev)SetStandardView(hFig, {'left'}));
        jItemViewBottom = gui_component('MenuItem', jMenuView, [], 'Bottom', [], [], @(h,ev)SetStandardView(hFig, {'bottom'}));
        jItemViewRight  = gui_component('MenuItem', jMenuView, [], 'Right',  [], [], @(h,ev)SetStandardView(hFig, {'right'}));
        jItemViewFront  = gui_component('MenuItem', jMenuView, [], 'Front',  [], [], @(h,ev)SetStandardView(hFig, {'front'}));
        jItemViewTop    = gui_component('MenuItem', jMenuView, [], 'Top',    [], [], @(h,ev)SetStandardView(hFig, {'top'}));
        jItemViewBack   = gui_component('MenuItem', jMenuView, [], 'Back',   [], [], @(h,ev)SetStandardView(hFig, {'back'}));
        % Keyboard shortcuts
        jItemViewLeft.setAccelerator(  KeyStroke.getKeyStroke('1', 0)); 
        jItemViewBottom.setAccelerator(KeyStroke.getKeyStroke('2', 0)); 
        jItemViewRight.setAccelerator( KeyStroke.getKeyStroke('3', 0));
        jItemViewFront.setAccelerator( KeyStroke.getKeyStroke('4', 0));
        jItemViewTop.setAccelerator(   KeyStroke.getKeyStroke('5', 0));
        jItemViewBack.setAccelerator(  KeyStroke.getKeyStroke('6', 0));
        % MULTIPLE VIEWS
        if ~isAlignFigure
            jItemViewLR     = gui_component('MenuItem', jMenuView, [], '[Left, Right]',              [], [], @(h,ev)SetStandardView(hFig, {'left', 'right'}));
            jItemViewTB     = gui_component('MenuItem', jMenuView, [], '[Top, Bottom]',              [], [], @(h,ev)SetStandardView(hFig, {'top', 'bottom'}));
            jItemViewFB     = gui_component('MenuItem', jMenuView, [], '[Front, Back]',              [], [], @(h,ev)SetStandardView(hFig, {'front','back'}));
            jItemViewLTR    = gui_component('MenuItem', jMenuView, [], '[Left, Top, Right]',         [], [], @(h,ev)SetStandardView(hFig, {'left', 'top', 'right'}));
            jItemViewLRIETB = gui_component('MenuItem', jMenuView, [], '[L/R, Int/Extern, Top/Bot]', [], [], @(h,ev)SetStandardView(hFig, {'left', 'right', 'top', 'left_intern', 'right_intern', 'bottom'}));
            % Keyboard shortcuts
            jItemViewLR.setAccelerator(    KeyStroke.getKeyStroke('7', 0));
            jItemViewTB.setAccelerator(    KeyStroke.getKeyStroke('8', 0));
            jItemViewFB.setAccelerator(    KeyStroke.getKeyStroke('9', 0));
            jItemViewLTR.setAccelerator(   KeyStroke.getKeyStroke('0', 0));
            jItemViewLRIETB.setAccelerator(KeyStroke.getKeyStroke('.', 0));
            % APPLY THRESHOLD TO ALL FIGURES
            jMenuView.addSeparator();
            if ismember('source', ColormapInfo.AllTypes)
                jItem = gui_component('MenuItem', jMenuView, [], 'Apply threshold to all figures', [], [], @(h,ev)ApplyViewToAllFigures(hFig, 0, 1));
                jItem.setAccelerator(KeyStroke.getKeyStroke('*', 0));
            end
            % SET SAME VIEW FOR ALL FIGURES
            jItem = gui_component('MenuItem', jMenuView, [], 'Apply this view to all figures', [], [], @(h,ev)ApplyViewToAllFigures(hFig, 1, 1));
            jItem.setAccelerator(KeyStroke.getKeyStroke('=', 0));
            % JUMP TO MAXIMUM
            if ismember('anatomy', ColormapInfo.AllTypes) && isOverlay
                jItem = gui_component('MenuItem', jMenuView, [], 'Find maximum', [], [], @(h,ev)JumpMaximum(hFig));
                jItem.setAccelerator(KeyStroke.getKeyStroke('m', 0));
            end
            % CLONE FIGURE
            jMenuView.addSeparator();
            gui_component('MenuItem', jMenuView, [], 'Clone figure', [], [], @(h,ev)bst_figures('CloneFigure', hFig));
        end
    end
    % CLONE FIGURE
    jMenuFigure.addSeparator();
    gui_component('MenuItem', jMenuFigure, [], 'Clone figure', [], [], @(h,ev)bst_figures('CloneFigure', hFig));

    % ==== Display menu ====
    gui_popup(jPopup, hFig);
end


%% ===== FIGURE CONFIGURATION FUNCTIONS =====
% CHECKBOX: MIP ANATOMY
function MipAnatomy_Callback(hFig, ev)
    MriOptions = bst_get('MriOptions');
    MriOptions.isMipAnatomy = ev.getSource().isSelected();
    bst_set('MriOptions', MriOptions);
    % bst_figures('FireCurrentTimeChanged', 1);
    UpdateMriDisplay(hFig);
end
% CHECKBOX: MIP FUNCTIONAL
function MipFunctional_Callback(hFig, ev)
    MriOptions = bst_get('MriOptions');
    MriOptions.isMipFunctional = ev.getSource().isSelected();
    bst_set('MriOptions', MriOptions);
    bst_figures('FireCurrentTimeChanged', 1);
end
% RADIO: MRI SMOOTH
function SetMriSmooth(hFig, OverlaySmooth)
    MriOptions = bst_get('MriOptions');
    MriOptions.OverlaySmooth = OverlaySmooth;
    bst_set('MriOptions', MriOptions);
    bst_figures('FireCurrentTimeChanged', 1);
end
% RADIO: MRI UPSAMPLE
function SetMriUpsample(hFig, UpsampleImage)
    MriOptions = bst_get('MriOptions');
    MriOptions.UpsampleImage = UpsampleImage;
    bst_set('MriOptions', MriOptions);
    UpdateMriDisplay(hFig);
end
% RADIO: DISTANCE THRESHOLD
function SetDistanceThresh(hFig, DistanceThresh)
    global GlobalData;
    % Update MRI display options
    MriOptions = bst_get('MriOptions');
    MriOptions.DistanceThresh = DistanceThresh;
    bst_set('MriOptions', MriOptions);
    % Update display
    TessInfo = getappdata(hFig, 'Surface');
    if ~isempty(TessInfo(1).DataSource.FileName)
        [iDS, iResult] = bst_memory('GetDataSetResult', TessInfo(1).DataSource.FileName);
        if ~isempty(iDS)
            GlobalData.DataSet(iDS).Results(iResult).grid2mri_interp = [];
            bst_figures('FireCurrentTimeChanged', 1);
        end
    end
end
% RADIO: MRI RESOLUTION
function SetMriResolution(hFig, InterpDownsample)
    global GlobalData;
    % Update MRI display options
    MriOptions = bst_get('MriOptions');
    MriOptions.InterpDownsample = InterpDownsample;
    bst_set('MriOptions', MriOptions);
    % Update display
    TessInfo = getappdata(hFig, 'Surface');
    if ~isempty(TessInfo(1).DataSource.FileName)
        [iDS, iResult] = bst_memory('GetDataSetResult', TessInfo(1).DataSource.FileName);
        if ~isempty(iDS)
            GlobalData.DataSet(iDS).Results(iResult).grid2mri_interp = [];
            bst_figures('FireCurrentTimeChanged', 1);
        end
    end
end
% CHECKBOX: GRID SMOOTH
function SetGridSmooth(hFig, GridSmooth)
    global GlobalData;
    % Get figure configuration
    TessInfo = getappdata(hFig, 'Surface');
    if isempty(TessInfo(1).DataSource.FileName)
        return;
    end
    % Update figure configuration 
    TessInfo(1).DataSource.GridSmooth = GridSmooth;
    setappdata(hFig, 'Surface', TessInfo);
    % Update display
    if ~isempty(TessInfo(1).DataSource.FileName)
        [iDS, iResult] = bst_memory('GetDataSetResult', TessInfo(1).DataSource.FileName);
        if ~isempty(iDS)
            GlobalData.DataSet(iDS).Results(iResult).grid2mri_interp = [];
            bst_figures('FireCurrentTimeChanged', 1);
        end
    end
end


%% ==============================================================================================
%  ====== SURFACES ==============================================================================
%  ==============================================================================================           
%% ===== GET SELECTED ROWS =====
% USAGE:   [SelRows, iRows] = GetFigSelectedRows(hFig);
%           SelRows         = GetFigSelectedRows(hFig);
function [SelRows, iRows] = GetFigSelectedRows(hFig)
    global GlobalData;
    % Initialize retuned values
    SelRows = [];
    iRows = [];
    % Find figure
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    % Get indices of the channels displayed in this figure
    iDispRows = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels;
    if isempty(iDispRows) || isempty(GlobalData.DataViewer.SelectedRows)
        return;
    end
    % Get all the sensors displayed in the figure
    DispRows = {GlobalData.DataSet(iDS).Channel(iDispRows).Name};
    % Get the general list of selected rows
    SelRows = intersect(GlobalData.DataViewer.SelectedRows, DispRows);
    % If required: get the indices
    if (nargout >= 2) && ~isempty(SelRows)
        % Find row indices in the full list
        for i = 1:length(SelRows)
            iRows = [iRows, iDispRows(strcmpi(SelRows{i}, DispRows))];
        end
    end
end
    
    
%% ===== GET SELECTED ROWS =====
% USAGE:   UpdateFigSelectedRows(iDS, iFig);
function UpdateFigSelectedRows(iDS, iFig)
    global GlobalData;
    % Get figure handles
    sHandles = GlobalData.DataSet(iDS).Figure(iFig).Handles;
    % If no sensor information: return
    iDispChan = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels;
    if isempty(iDispChan)
        return;
    end
    % Get all the sensors displayed in the figure
    DispChan = {GlobalData.DataSet(iDS).Channel(iDispChan).Name};
    % Remove spaces in channel names
    DispChan = cellfun(@(c)strrep(c,' ',''), DispChan, 'UniformOutput', 0);
    % Get the general list of selected rows
    SelChan = intersect(GlobalData.DataViewer.SelectedRows, DispChan);
    % Find row indices in the full list
    iSelChan = [];
    for i = 1:length(SelChan)
        iSelChan = [iSelChan, find(strcmpi(SelChan{i}, DispChan))];
    end
    % Compute the unselected channels
    iUnselChan = setdiff(1:length(iDispChan), iSelChan);
    % Get electrodes patch
    hFig = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
    hElectrodeGrid = findobj(hFig, 'Tag', 'ElectrodeGrid');
        
    % For 2DLayout figures only
    if strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.SubType, '2DLayout')
        % Check that there is something displayed in the figure
        if ~isfield(sHandles, 'SelChanGlobal') || isempty(sHandles.SelChanGlobal)
            return;
        end
        % Get selected lines
        iSelLines = find(ismember(sHandles.SelChanGlobal, iDispChan(iSelChan)));
        % Selected channels : Paint lines in red
        if ~isempty(iSelLines)
            set(sHandles.hLines{1}(iSelLines), 'Color', 'r');
            set(sHandles.hSensorLabels(iSelLines), ...
                'Color',      [.2 1 .4], ...
                'FontUnits', 'points', ...
                'FontSize',   bst_get('FigFont') + 1, ...
                'FontWeight', 'bold');
        end
        % Get deselected lines
        iUnselLines = find(ismember(sHandles.SelChanGlobal, iDispChan(iUnselChan)));
        % Deselected channels : Restore initial color
        if ~isempty(iUnselLines)
            for i = 1:length(iUnselLines)
                set(sHandles.hLines{1}(iUnselLines(i)), 'Color', sHandles.LinesColor{1}(iUnselLines(i),:));
            end
            set(sHandles.hSensorLabels(iUnselLines), ...
                'Color',      .8*[1 1 1], ...
                'FontUnits', 'points', ...
                'FontSize',   bst_get('FigFont'), ...
                'FontWeight', 'normal');
        end
    % For 3DElectrodes figures only
    elseif ~isempty(hElectrodeGrid)
        % Get vertices
        sphVertices = get(hElectrodeGrid, 'Vertices');
        sphUserData = get(hElectrodeGrid, 'UserData');
        % Get copy of spheres patch
        hElectrodeSelect = findobj(hFig, 'Tag', 'ElectrodeSelect');
        % If the selection doesn't exist yet: copy initial patch
        if isempty(hElectrodeSelect) && ~isempty(iSelChan)
            % Extend the size of all the electrodes
            iAllChan = unique(sphUserData);
            for i = 1:length(iAllChan)
                % Get the center of the electrode
                iVert = find(sphUserData == iAllChan(i));
                chanCenter = mean(sphVertices(iVert,:),1);
                % Increase size from the center of the electrode
                sphVertices(iVert,:) = bst_bsxfun(@minus, sphVertices(iVert,:), chanCenter);
                sphVertices(iVert,:) = 1.3 * sphVertices(iVert,:);
                sphVertices(iVert,:) = bst_bsxfun(@plus, sphVertices(iVert,:), chanCenter);
            end
            % Make initial object copy
            hElectrodeSelect = copyobj(hElectrodeGrid, get(hElectrodeGrid, 'Parent'));
            % Selected color depends on the figure colormap
            sColormap = bst_colormaps('GetColormap', hFig);
            if ~isempty(sColormap) && ismember(sColormap.Name, {'cmap_rbw'})
                selColor = [0 1 0];
            else
                selColor = [1 0 0];
            end
            
            % Change properties
            set(hElectrodeSelect, ...
                'FaceColor', selColor, ...
                'EdgeColor', 'none', ...
                'FaceAlpha', 'flat', ...
                'FaceVertexAlphaData', zeros(size(sphVertices,1),1), ...
                'Vertices', sphVertices, ...
                'Tag',      'ElectrodeSelect');
        end
        % If there is something to update
        if ~isempty(hElectrodeSelect)
            % Get current list of visible vertices
            AlphaData = get(hElectrodeSelect, 'FaceVertexAlphaData');
            % Selected channels: Make visible
            for i = 1:length(iSelChan)
                AlphaData(sphUserData == iSelChan(i)) = 0.7;
            end
            % Deselected channels: Hide them
            for i = 1:length(iUnselChan)
                AlphaData(sphUserData == iUnselChan(i)) = 0;
            end
            % Hide completely the object
            if all(AlphaData == 0)
                Visible = 'off';
            else
                Visible = 'on';
            end
            % Update Alpha vector
            set(hElectrodeSelect, 'FaceVertexAlphaData', AlphaData, ...
                                  'Visible', Visible);
        end
        
    % All other 2D/3D figures
    else
        % If valid sensor markers exist 
        hMarkers = sHandles.hSensorMarkers;
        if ~isempty(hMarkers) && all(ishandle(hMarkers))
            if strcmpi(get(hMarkers(1), 'Type'), 'patch')
                % Get the color of all the vertices
                VerticesColors = get(hMarkers, 'FaceVertexCData');
                % Update the vertices that changed
                if ~isempty(iSelChan)
                    VerticesColors(iSelChan, :) = repmat([1 0.3 0], [length(iSelChan), 1]);
                end
                if ~isempty(iUnselChan)
                    VerticesColors(iUnselChan, :) = repmat([1 1 1], [length(iUnselChan), 1]);
                end
                % Update patch object
                set(hMarkers, 'FaceVertexCData', VerticesColors);
                
            elseif strcmpi(get(hMarkers(1), 'Type'), 'line')
                % Get the vertex indices
                UserData = get(hMarkers, 'UserData');
                if iscell(UserData)
                    iVertices = [UserData{:}];
                else
                    iVertices = UserData;
                end
                % Update the vertices that changed
                for i = 1:length(iSelChan)
                    set(hMarkers(iSelChan(i) == iVertices), 'MarkerFaceColor', [1 0.3 0]);
                end
                for i = 1:length(iUnselChan)
                    set(hMarkers(iUnselChan(i) == iVertices), 'MarkerFaceColor', [1 1 1]);
                end
            end
        end
    end
end


%% ===== PLOT SURFACE =====
% Convenient function to consistently plot surfaces.
% USAGE : [hFig,hs] = PlotSurface(hFig, faces, verts, cdata, dataCMap, transparency)
% Parameters :
%     - hFig         : figure handle to use
%     - faces        : the triangle listing (array)
%     - verts        : the corresponding vertices (array)
%     - surfaceColor : color data used to display the surface itself (FaceVertexCData for each vertex, or a unique color for all vertices)
%     - dataColormap : colormap used to display the data on the surface
%     - transparency : surface transparency ([0,1])
% Returns :
%     - hFig : figure handle used
%     - hs   : handle to the surface
function varargout = PlotSurface( hFig, faces, verts, surfaceColor, transparency) %#ok<DEFNU>
    % Check inputs
    if (nargin ~= 5)
        error('Invalid call to PlotSurface');
    end
    % If vertices are assumed transposed (if the assumption is wrong, will crash below anyway)
    if (size(verts,2) > 3)
        verts = verts';
    end
    % If vertices are assumed transposed (if the assumption is wrong, will crash below anyway)
    if (size(faces,2) > 3)
        faces = faces';  
    end
    % Surface color
    if (length(surfaceColor) == 3)
        FaceVertexCData = [];
        FaceColor = surfaceColor;
        EdgeColor = 'none';
    elseif (length(surfaceColor) == length(verts))
        FaceVertexCData = surfaceColor;
        FaceColor = 'interp';
        EdgeColor = 'interp';
    else
        error('Invalid surface color.');
    end
    % Set figure as current
    set(0, 'CurrentFigure', hFig);
    
    % Create patch
    hs = patch(...
        'Faces',            faces, ...
        'Vertices',         verts,...
        'FaceVertexCData',  FaceVertexCData, ...
        'FaceColor',        FaceColor, ...
        'FaceAlpha',        1 - transparency, ...
        'AlphaDataMapping', 'none', ...
        'EdgeColor',        EdgeColor, ...
        'BackfaceLighting', 'lit', ...
        'AmbientStrength',  0.5, ...
        'DiffuseStrength',  0.5, ...
        'SpecularStrength', 0.2, ...
        'SpecularExponent', 1, ...
        'SpecularColorReflectance', 0.5, ...
        'FaceLighting',     'gouraud', ...
        'EdgeLighting',     'gouraud', ...
        'Tag',              'AnatSurface');
    
    % Set output variables
    if(nargout>0),
        varargout{1} = hFig;
        varargout{2} = hs;
    end
end

%% ===== PLOT FIBERS =====
function varargout = PlotFibers(hFig, FibPoints, Colors)
    dims = size(Colors);
    if length(dims) < 3
        Colors = permute(repmat(Colors, 1, 1, size(FibPoints, 2)), [1,3,2]);
    end

    % Set figure as current
    set(0, 'CurrentFigure', hFig);
    
    % If we are displaying too many fibers, warn user...
    numMaxFibers = 5000;
    numFibers = size(FibPoints,1);
    if numFibers > numMaxFibers
        questionOptions = {'Display a subset for now', 'Display all anyway'};
        [res, isCancel] = java_dialog('question', ...
            ['You are trying to display ', num2str(numFibers), ...
            ' fibers. Displaying this' 10 'amount of fibers at the same time ', ...
            'can be challenging for the' 10 'average computer. We recommend ', ...
            'you downsample them first.'], 'Display fibers', [], questionOptions);
        if isCancel || strcmp(res, questionOptions{1})
            iFibers = sort(randsample(numFibers, numMaxFibers));
        else
            iFibers = 1:numFibers;
        end
    else
        iFibers = 1:numFibers;
    end
    
    numFibers = length(iFibers);
    
    % Plot fibers
    for iFib = 1:numFibers
        lines(iFib) = surface([FibPoints(iFibers(iFib),:,1); FibPoints(iFibers(iFib),:,1)], ...
            [FibPoints(iFibers(iFib),:,2); FibPoints(iFibers(iFib),:,2)], ...
            [FibPoints(iFibers(iFib),:,3); FibPoints(iFibers(iFib),:,3)], ...
            [Colors(iFibers(iFib),:,1:3); Colors(iFibers(iFib),:,1:3)], ...
            'FaceColor','none',...
            'EdgeColor','flat');
    end
    if numFibers == 0
        lines = [];
    end
    
    % Set output variables
    if nargout > 0
        varargout{1} = hFig;
        varargout{2} = lines;
    end
end

function lines = ColorFibers(lines, Color)
    if isempty(Color) || isempty(lines)
        return;
    end
    
    bst_progress('start', 'Fiber viewer', 'Coloring fibers...');
    
    dims = size(Color);
    nFibers = length(lines);
    
    % Create a full Color matrix if required
    if length(dims) < 3
        nPoints = size(lines(1).XData, 2);
        if dims(1) == 1
            % One color value for all fibers and points
            Color = permute(repmat(Color, nFibers, 1, nPoints), [1,3,2]);
        else
            % One color value per fiber
            Color = permute(repmat(Color, 1, 1, nPoints), [1,3,2]);
        end
    end
    
    % Set color
    for iFib = 1:length(lines)
        lines(iFib).CData = [Color(iFib,:,:); Color(iFib,:,:)];
    end
    
    drawnow;
    bst_progress('stop');
end

%% ===== PLOT SQUARE/CUT =====
% USAGE:  PlotSquareCut(hFig, TessInfo, dim, pos)
%         PlotSquareCut(hFig)  : Remove all square cuts displayed
function PlotSquareCut(hFig, TessInfo, dim, pos)
    % Get figure description and MRI
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    % Delete the previous patch
    delete(findobj(hFig, 'Tag', 'squareCut'));
    if (nargin < 4)
        return
    end
    hAxes  = findobj(hFig, '-depth', 1, 'tag', 'Axes3D');
    % Get maximum dimensions (MRI size)
    sMri = bst_memory('GetMri', TessInfo.SurfaceFile);
    mriSize = size(sMri.Cube);

    % Get locations of the slice
    nbPts = 50;
    baseVect = linspace(-.01, 1.01, nbPts);
    switch(dim)
        case 1
            voxX = ones(nbPts)         .* (pos + 2); 
            voxY = meshgrid(baseVect)  .* mriSize(2);   
            voxZ = meshgrid(baseVect)' .* mriSize(3); 
            surfColor = [1 .5 .5];
        case 2
            voxX = meshgrid(baseVect)  .* mriSize(1); 
            voxY = ones(nbPts)         .* (pos + 2) + .1;    
            voxZ = meshgrid(baseVect)' .* mriSize(3); 
            surfColor = [.5 1 .5];
        case 3
            voxX = meshgrid(baseVect)  .* mriSize(1); 
            voxY = meshgrid(baseVect)' .* mriSize(2); 
            voxZ = ones(nbPts)         .* (pos + 2) + .1;        
            surfColor = [.5 .5 1];
    end

    % === Switch coordinates from MRI-CS to SCS ===
    % Apply Rotation/Translation
    voxXYZ = [voxX(:), voxY(:), voxZ(:)];
    scsXYZ = cs_convert(sMri, 'voxel', 'scs', voxXYZ);

    % === PLOT SURFACE ===
    % Plot new surface  
    hCut = surface('XData',     reshape(scsXYZ(:,1),nbPts,nbPts), ...
                   'YData',     reshape(scsXYZ(:,2),nbPts,nbPts), ...
                   'ZData',     reshape(scsXYZ(:,3),nbPts,nbPts), ...
                   'CData',     ones(nbPts), ...
                   'FaceColor',        surfColor, ...
                   'FaceAlpha',        .3, ...
                   'EdgeColor',        'none', ...
                   'AmbientStrength',  .5, ...
                   'DiffuseStrength',  .9, ...
                   'SpecularStrength', .1, ...
                   'Tag',    'squareCut', ...
                   'Parent', hAxes);
end


%% ===== UPDATE MRI DISPLAY =====
% USAGE:  UpdateMriDisplay(hFig, dims, TessInfo, iTess)
%         UpdateMriDisplay(hFig, dims)
%         UpdateMriDisplay(hFig)
function UpdateMriDisplay(hFig, dims, TessInfo, iTess)
    % Parse inputs
    if (nargin < 4)
        [sMri,TessInfo,iTess] = panel_surface('GetSurfaceMri', hFig);
    end
    if (nargin < 2) || isempty(dims)
        dims = [1 2 3];
    end
    % Get the slices that need to be redrawn
    newPos = [NaN, NaN, NaN];
    newPos(dims) = TessInfo(iTess).CutsPosition(dims);
    % Redraw the three slices
    panel_surface('PlotMri', hFig, newPos);
end



%% ===== UPDATE SURFACE COLOR =====
% Compute color RGB values for each vertex of the surface, taking in account : 
%     - the surface color,
%     - the sulci map
%     - the data matrix displayed over the surface (and the data threshold),
%     - the data colormap : RGB values, normalized?, absolute values?, limits
%     - the data transparency
% Parameters : 
%     - hFig : handle to a 3DViz figure
%     - iTess     : indice of the surface to update
function UpdateSurfaceColor(hFig, iTess)
    % Get surfaces list 
    TessInfo = getappdata(hFig, 'Surface');
    % Ignore empty surfaces and MRI slices
    if isempty(TessInfo(iTess).hPatch) || ~any(ishandle(TessInfo(iTess).hPatch))
        return 
    end
    
    % === ColorMap ===
    % Get best colormap to display data
    sColormap = bst_colormaps('GetColormap', TessInfo(iTess).ColormapType);
    if sColormap.UseStatThreshold && (~isempty(TessInfo(iTess).StatThreshUnder) || ~isempty(TessInfo(iTess).StatThreshOver))
        % Extend the color of null value to non-significant values and put all the color dynamics for significant values
        sColormap.CMap = bst_colormaps('StatThreshold', sColormap.CMap, TessInfo(iTess).DataLimitValue(1), TessInfo(iTess).DataLimitValue(2), ...
                                       sColormap.isAbsoluteValues, TessInfo(iTess).StatThreshUnder, TessInfo(iTess).StatThreshOver, ...
                                       [0.7 0.7 0.7]);
        
        % Update figure colorbar accordingly
        set(hFig, 'Colormap', sColormap.CMap);
        % Create/Delete colorbar
        bst_colormaps('SetColorbarVisible', hFig, sColormap.DisplayColorbar);
    end
    
    % Initialize list of independent vertices to plot
    GridLoc    = zeros(0,3);
    GridValues = zeros(0,1);
    GridInd    = zeros(1,0);
    
    % === MRI ===
    if strcmpi(TessInfo(iTess).Name, 'Anatomy')
        % Update display
        UpdateMriDisplay(hFig, [], TessInfo, iTess);
        
    % === FIBERS ===
    elseif strcmpi(TessInfo(iTess).Name, 'Fibers')
        % Set line color
        TessInfo(iTess).hPatch = ColorFibers(TessInfo(iTess).hPatch, TessInfo(iTess).AnatomyColor(1,1:3));
        
    % === SURFACE ===
    else
        % === BUILD VALUES ===
        % If there is no data overlay
        if isempty(TessInfo(iTess).Data)
            DataSurf = [];
        else
            % Apply absolute value
            DataSurf = TessInfo(iTess).Data;
            if sColormap.isAbsoluteValues
                DataSurf = abs(DataSurf);
            end
            % Apply data threshold
            [DataSurf, ThreshBar] = ThresholdSurfaceData(DataSurf, TessInfo(iTess).DataLimitValue, TessInfo(iTess).DataThreshold, sColormap);
            % If there is an atlas defined for this surface: replicate the values for each patch
            if ~isempty(TessInfo(iTess).DataSource.Atlas) && ~isempty(TessInfo(iTess).DataSource.Atlas.Scouts)
                % Initialize full cortical map
                DataScout = DataSurf;
                DataSurf = zeros(TessInfo(iTess).nVertices,1);
                % Duplicate the value of each scout to all the vertices
                sScouts = TessInfo(iTess).DataSource.Atlas.Scouts;
                for i = 1:length(sScouts)
                    DataSurf(sScouts(i).Vertices,:) = DataScout(i,:);
                end
            % Regular surface values
            else
                % Get the cortex surface (for the vertices connectivity)
                sSurf = bst_memory('GetSurface', TessInfo(iTess).SurfaceFile);
                % Mixed source models: keep only the surface values
                if ~isempty(TessInfo(iTess).DataSource.GridAtlas) && ~isempty(TessInfo(iTess).DataSource.GridLoc)
%                     % Find the source model atlas in the cortex surface
%                     iAtlas = find(strcmpi('Source model', {sSurf.Atlas.Name}));
%                     if isempty(iAtlas)
%                         error('Atlas "Source model" cannot be found in the cortex surface.');
%                     end
                    % Extract the vertex indices that correspond to a surface value
                    iSurfVert = [];
                    iGridVert = [];
                    sGridScouts = TessInfo(iTess).DataSource.GridAtlas.Scouts;
                    for i = 1:length(sGridScouts)
                        switch (sGridScouts(i).Region(2))
                            case 'V'
                                % Add to the list of independent vertices to plot
                                GridLoc    = [GridLoc;    TessInfo(iTess).DataSource.GridLoc(sGridScouts(i).GridRows,:)];
                                GridInd    = [GridInd,    sGridScouts(i).GridRows];
                                GridValues = [GridValues; DataSurf(sGridScouts(i).GridRows,:)];
                            case 'S'
                                % Add to the list of matching vertices
                                iSurfVert = [iSurfVert, sGridScouts(i).Vertices];
                                iGridVert = [iGridVert, sGridScouts(i).GridRows];
                        end
                    end
                    % Remap the values of the sources with the correct order
                    DataSurfGrid = DataSurf;
                    DataSurf = zeros(TessInfo(iTess).nVertices, 1);
                    DataSurf(iSurfVert) = DataSurfGrid(iGridVert);
                end
                % Apply size threshold (surface only)
                if (TessInfo(iTess).SizeThreshold > 1)
                    % Get clusters that are above the threshold
                    iVertOk = bst_cluster_threshold(abs(DataSurf), TessInfo(iTess).SizeThreshold, sSurf.VertConn);
                    DataSurf(~iVertOk) = 0;
                end
            end
            % Add threshold markers to colorbar
            AddThresholdMarker(hFig, TessInfo(iTess).DataLimitValue, ThreshBar);
        end
   
        % SHOW SULCI MAP
        if TessInfo(iTess).SurfShowSulci
            % Get surface
            sSurf = bst_memory('GetSurface', TessInfo(iTess).SurfaceFile);
            SulciMap = sSurf.SulciMap;
        % DO NOT SHOW SULCI MAP
        else
            SulciMap = zeros(TessInfo(iTess).nVertices, 1);
        end
        % Compute RGB values
        FaceVertexCdata = BlendAnatomyData(SulciMap, ...                                  % Anatomy: Sulci map
                                           TessInfo(iTess).AnatomyColor([1,end], :), ...  % Anatomy: color
                                           DataSurf, ...                                  % Data: values map
                                           TessInfo(iTess).DataLimitValue, ...            % Data: limit value
                                           TessInfo(iTess).DataAlpha,...                  % Data: transparency
                                           sColormap);                                    % Colormap
        % Edge display : on/off
        if ~TessInfo(iTess).SurfShowEdges
            EdgeColor = 'none';
        else
            EdgeColor = TessInfo(iTess).AnatomyColor(1, :);
        end
        % Set surface colors
        set(TessInfo(iTess).hPatch, 'FaceVertexCdata', FaceVertexCdata, ...
                                    'FaceColor',       'interp', ...
                                    'EdgeColor',       EdgeColor);
        % Plot independent vertices as spheres
        if ~isempty(GridLoc)
            PlotGrid(hFig, GridLoc, GridValues, GridInd, TessInfo(iTess).DataAlpha, TessInfo(iTess).DataLimitValue, sColormap);
        end
    end
end


%% ===== PLOT GRID =====
% Display a volume grid or set of electrodes
function hGrid = PlotGrid(hFig, GridLoc, GridValues, GridInd, DataAlpha, DataLimit, sColormap)
    % Number of points
    N = 12;
    % Grid transparency
    FaceAlpha = repmat(1-DataAlpha, size(GridLoc,1) * N, 1);
    % If data values are passed to the function
    if ~isempty(DataLimit)
        % Replicate the grid data to match the number of vertices per sphere
        GridValues = repmat(GridValues', N, 1);
        GridValues = GridValues(:);
        % Get color values
        if ~isempty(GridValues) && (length(DataLimit) == 2) && (DataLimit(2) ~= DataLimit(1)) && ~any(isnan(DataLimit)) && ~any(isinf(DataLimit))
            iDataCmap = round( ((size(sColormap.CMap,1)-1)/(DataLimit(2)-DataLimit(1))) * (GridValues - DataLimit(1))) + 1;
            iDataCmap(iDataCmap <= 0) = 1;
            iDataCmap(iDataCmap > size(sColormap.CMap,1)) = size(sColormap.CMap,1);
            dataRGB = sColormap.CMap(iDataCmap, :);
        else
            % return;
            dataRGB = repmat([.6 .6 .6], size(GridLoc,1) * N, 1);
        end
        % Spheres transparency: Hide values that are strictly zero
        FaceAlpha(GridValues == 0) = min(1-DataAlpha, 0.05);
    else
        dataRGB = repmat([.9,.9,0], size(GridLoc,1) * N, 1);
    end
    % Find previously create grid
    GridTag = 'GridSpheres';
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    hGrid = findobj(hAxes, 'Tag', GridTag);
    % Create a set of spheres
    if isempty(hGrid)
        % Create one sphere
        SpheresSize = 0.0016;
        [sphVertex, sphFace] = tess_sphere(N);
        sphVertex = sphVertex .* SpheresSize ./ 2;
        % Multiply this sphere
        Vertex = zeros(0,3);
        Faces  = zeros(0,3);
        for i = 1:size(GridLoc,1)
            tmpVertex = bst_bsxfun(@plus, GridLoc(i,:), sphVertex);
            Vertex = [Vertex; tmpVertex];
            Faces  = [Faces;  sphFace + N*(i-1)];
        end
        % Set the GridLoc index in the UserData to get a match with the surface vertex 
        if ~isempty(GridInd)
            UserData = reshape(repmat(GridInd, N, 1), [], 1);
        else
            UserData = [];
        end
        % Create patch
        hGrid = patch(...
            'Faces',               Faces, ...
            'Vertices',            Vertex,...
            'FaceVertexCData',     dataRGB, ...
            'FaceColor',           'interp', ...
            'FaceAlpha',           'flat', ...
            'FaceVertexAlphaData', FaceAlpha, ...
            'AlphaDataMapping',    'none', ...
            'EdgeColor',           'none', ...
            'LineWidth',           1, ...
            'BackfaceLighting',    'unlit', ...
            'AmbientStrength',     1, ...
            'DiffuseStrength',     0, ...
            'SpecularStrength',    0, ...
            'SpecularExponent',    1, ...
            'SpecularColorReflectance', 0, ...
            'FaceLighting',        'flat', ...
            'EdgeLighting',        'flat', ...
            'Tag',                 GridTag, ...
            'UserData',            UserData, ...
            'Parent',              hAxes);
    else
        set(hGrid, ...
            'FaceVertexCData',     dataRGB, ...
            'FaceVertexAlphaData', FaceAlpha);
    end
end


%% ===== PLOT 3D ELECTRODES =====
function [hElectrodeGrid, ChanLoc] = PlotSensors3D(iDS, iFig, Channel, ChanLoc, TopoType) %#ok<DEFNU>
    global GlobalData;
    % Initialize returned variable
    hElectrodeGrid = [];
    % Get current electrodes positions
    if (nargin < 4) || isempty(TopoType)
        TopoType = '3DElectrodes';
    end
    if (nargin < 3) || isempty(Channel) || isempty(ChanLoc)
        selChan = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels;
        Channel = GlobalData.DataSet(iDS).Channel(selChan);
        [AllLoc, ChanLoc] = GetChannelPositions(iDS, selChan);
    end
    % Get axes
    hFig = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    % Get font size
    fontSize = bst_get('FigFont') + 2;
    % Delete previously created electrodes
    delete(findobj(hFig, 'Tag', 'ElectrodeGrid'));
    delete(findobj(hFig, 'Tag', 'ElectrodeSelect'));
    delete(findobj(hFig, 'Tag', 'ElectrodeDepth'));
    delete(findobj(hFig, 'Tag', 'ElectrodeWire'));
    delete(findobj(hFig, 'Tag', 'ElectrodeLabel'));
    % Get electrodes definitions
    sElectrodes = GlobalData.DataSet(iDS).IntraElectrodes;
    % Get SEEG and ECOG devices
    iSeeg = [];
    iEcog = [];
    if ~isempty(sElectrodes)
        iSeeg = find(strcmpi({sElectrodes.Type}, 'SEEG'));
        iEcog = find(strcmpi({sElectrodes.Type}, 'ECOG') | strcmpi({sElectrodes.Type}, 'ECOG-mid'));
        % Remove all SEEG if no SEEG channels are available (same for ECOG)
        if ~isempty(iSeeg) && ~any(strcmpi({Channel.Type}, 'SEEG'))
            sElectrodes(iSeeg) = [];
        end
        if ~isempty(iEcog) && ~any(strcmpi({Channel.Type}, 'ECOG') | strcmpi({Channel.Type}, 'ECOG-mid'))
            sElectrodes(iEcog) = [];
        end
        if ~isempty(sElectrodes)
            iSeeg = find(strcmpi({sElectrodes.Type}, 'SEEG'));
            iEcog = find(strcmpi({sElectrodes.Type}, 'ECOG') | strcmpi({sElectrodes.Type}, 'ECOG-mid'));
        end
    end
    
    
    % === 2D ELECTRODES ===
    % If using a 2D plot: use standard positions for electrodes and contacts
    if strcmpi(TopoType, '2DElectrodes')
        % Extract SEEG global properties
        maxContactNumberSeeg = max([sElectrodes(iSeeg).ContactNumber]);
        maxLengthSeeg = max([sElectrodes(iSeeg).ElecLength]);
        % Extract ECOG global properties
        maxContactsEcog = max(cellfun(@(c)c(1), {sElectrodes(iEcog).ContactNumber}));
        X = 0;
        % Display electrodes in successive rows
        for iElec = length(sElectrodes):-1:1
            % Define default electrode properties just for display
            switch (sElectrodes(iElec).Type)
                case 'SEEG'
                    if isempty(sElectrodes(iElec).ElecLength)
                        sElectrodes(iElec).ElecLength = 0.070;
                    end
                    if isempty(maxLengthSeeg)
                        maxLengthSeeg = sElectrodes(iElec).ElecLength;
                    end
                    if isempty(sElectrodes(iElec).ContactSpacing) || (sElectrodes(iElec).ContactSpacing == 0) || (sElectrodes(iElec).ContactSpacing * sElectrodes(iElec).ContactNumber > sElectrodes(iElec).ElecLength)
                        sElectrodes(iElec).ContactSpacing = sElectrodes(iElec).ElecLength / maxContactNumberSeeg;
                    end
                    if isempty(sElectrodes(iElec).ElecDiameter)
                        sElectrodes(iElec).ElecDiameter = 0.0008;
                    end
                    X = X + 6 * sElectrodes(iElec).ElecDiameter + 0.0001;
                    Y = [maxLengthSeeg - sElectrodes(iElec).ElecLength, maxLengthSeeg];
                    sElectrodes(iElec).Loc = [X, X; Y; 0, 0];
                case {'ECOG', 'ECOG-mid'}
                    % Force to be ECOG-mid to prevent any projection on the cortex
                    maxDiameterEcog = 0.004;
                    sElectrodes(iElec).Type = 'ECOG';
                    sElectrodes(iElec).ElecDiameter = 0.004;
                    sElectrodes(iElec).ContactDiameter = maxDiameterEcog;
                    % ECOG strip
                    if (length(sElectrodes(iElec).ContactNumber) == 1)
                        X = X + 1.5 * maxDiameterEcog + 0.0001;
                        Y = 1.5 * maxDiameterEcog * [maxContactsEcog, maxContactsEcog - sElectrodes(iElec).ContactNumber(1) + 1];
                        sElectrodes(iElec).Loc = [X, X; Y; 0, 0];
                    % ECOG grid
                    else
                        nRowsElec = sElectrodes(iElec).ContactNumber(2);
                        Xgrid = X + 1.5 * maxDiameterEcog * [1, nRowsElec];
                        X = X + 1.5 * maxDiameterEcog * nRowsElec;
                        Y = 1.5 * maxDiameterEcog * [maxContactsEcog, maxContactsEcog - sElectrodes(iElec).ContactNumber(1) + 1];
                        sElectrodes(iElec).Loc = [Xgrid(2), Xgrid(2), Xgrid(1), Xgrid(1); Y(1), Y(2), Y(2), Y(1); 0, 0, 0, 0];
                    end
            end
        end
        % Set corresponding contact positions
        Channel = panel_ieeg('AlignContacts', iDS, iFig, 'default', sElectrodes, Channel, 0, 0);
        if isempty(Channel)
            return;
        end
        ChanLoc = [Channel.Loc]';
        isProjectEcog = 0;
    else
        isProjectEcog = 1;
    end
    
    % Create objects geometry
    [ElectrodeDepth, ElectrodeLabel, ElectrodeWire, ElectrodeGrid] = panel_ieeg('CreateGeometry3DElectrode', iDS, iFig, Channel, ChanLoc, sElectrodes, isProjectEcog);
    % Plot depth electrodes
    for iElec = 1:length(ElectrodeDepth)
        if strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.Type, 'Topography')
            faceColor = [.5 .5 .5];
        else
            faceColor = ElectrodeDepth(iElec).FaceColor;
        end
        hElectrodeDepth = patch(...
            'Faces',     ElectrodeDepth(iElec).Faces, ...
            'Vertices',  ElectrodeDepth(iElec).Vertices,...
            'FaceColor', faceColor, ...
            'FaceAlpha', ElectrodeDepth(iElec).FaceAlpha, ...
            'Parent',    hAxes, ...
            ElectrodeDepth(iElec).Options{:});
    end
    % 2DElectrodes: Add ECOG labels (or recompute them)
    if strcmpi(TopoType, '2DElectrodes') && ~isempty(iEcog)
        for i = 1:length(iEcog)
            % Find existing label
            if ~isempty(ElectrodeLabel)
                iLabel = find(strcmpi({ElectrodeLabel.Name}, sElectrodes(iEcog(i)).Name));
            end
            % Otherwise add new label
            if isempty(iLabel)
                iLabel = length(ElectrodeLabel) + 1;
            end
            ElectrodeLabel(iLabel).Loc   = sElectrodes(iEcog(i)).Loc(:,1) + [0; 2*sElectrodes(iEcog(i)).ContactDiameter; 0];
            ElectrodeLabel(iLabel).Name  = sElectrodes(iEcog(i)).Name;
            ElectrodeLabel(iLabel).Color = sElectrodes(iEcog(i)).Color;
            ElectrodeLabel(iLabel).Options = {...
                'FontUnits',   'points', ...
                'Tag',         'ElectrodeLabel', ...
                'Interpreter', 'none', ...
                'UserData',    sElectrodes(iEcog(i)).Name};
        end
    end
    % Plot electrode labels
    for iElec = 1:length(ElectrodeLabel)
        hElectrodeLabel = text(...
            ElectrodeLabel(iElec).Loc(1), ElectrodeLabel(iElec).Loc(2), ElectrodeLabel(iElec).Loc(3), ...
            ElectrodeLabel(iElec).Name, ...
            'Parent',              hAxes, ...
            'HorizontalAlignment', 'center', ...
            'FontSize',            fontSize, ...
            'FontWeight',          'bold', ...
            'Color',               ElectrodeLabel(iElec).Color, ...
            ElectrodeLabel(iElec).Options{:});
    end
    % Plot ECOG wires
    for iElec = 1:length(ElectrodeWire)
        hElectrodeWire = line(...
            ElectrodeWire(iElec).Loc(:,1), ElectrodeWire(iElec).Loc(:,2), ElectrodeWire(iElec).Loc(:,3), ...           
            'LineWidth',  ElectrodeWire(iElec).LineWidth, ...
            'Color',      ElectrodeWire(iElec).Color, ...
            'Parent',     hAxes, ...
            ElectrodeWire(iElec).Options{:});
    end
    % Plot grid of contacts
    if ~isempty(ElectrodeGrid)
        hElectrodeGrid = patch(...
            'Faces',               ElectrodeGrid.Faces, ...
            'Vertices',            ElectrodeGrid.Vertices,...
            'FaceVertexCData',     ElectrodeGrid.FaceVertexCData, ...
            'FaceVertexAlphaData', ElectrodeGrid.FaceVertexAlphaData, ...
            'FaceColor',           'flat', ...
            'FaceAlpha',           'flat', ...
            'AlphaDataMapping',    'none', ...
            'Parent',              hAxes, ...
            ElectrodeGrid.Options{:});
    end
    % Repaint selected sensors for this figure
    UpdateFigSelectedRows(iDS, iFig);
end


%% ===== SET ELECTRODES CONFIGURATION =====
function SetElectrodesConfig(hFig)
    global GlobalData;
    % Get figure description
    [hFig,iFig,iDS] = bst_figures('GetFigure', hFig);
    % Get modality
    Modality = GlobalData.DataSet(iDS).Figure(iFig).Id.Modality;
    % Get saved user properties
    ElectrodeConfig = bst_get('ElectrodeConfig', Modality);

    % Fields to edit in the saved displayed properties
    addFields = struct();
    % Configuration for SEEG electrodes
    if strcmpi(ElectrodeConfig.Type, 'seeg')
        res = java_dialog('input', {'Contact diameter (mm):', 'Contact length (mm):', 'Depth electrode diameter (mm):', 'Depth electrode length (mm):'}, 'Electrode display', [], ...
                              {num2str(1000 * ElectrodeConfig.ContactDiameter), num2str(1000 * ElectrodeConfig.ContactLength), num2str(1000 * ElectrodeConfig.ElecDiameter), num2str(1000 * ElectrodeConfig.ElecLength)});
        if isempty(res) || (length(res) < 2)
            return
        end
        if ~isnan(str2double(res{1})) && ~isempty(str2double(res{1})) && (str2double(res{1}) >= 0)
            addFields.ContactDiameter = str2double(res{1}) / 1000;
        end
        if ~isnan(str2double(res{2})) && ~isempty(str2double(res{2})) && (str2double(res{2}) >= 0)
            addFields.ContactLength = str2double(res{2}) / 1000;
        end
        if ~isnan(str2double(res{3})) && ~isempty(str2double(res{3})) && (str2double(res{3}) >= 0)
            addFields.ElecDiameter = str2double(res{3}) / 1000;
        end
        if ~isnan(str2double(res{4})) && ~isempty(str2double(res{4})) && (str2double(res{4}) >= 0)
            addFields.ElecLength = str2double(res{4}) / 1000;
        end
        Modality = 'SEEG';
    % Configuration for ECOG electrodes
    elseif strcmpi(ElectrodeConfig.Type, 'ecog')
        res = java_dialog('input', {'Contact diameter (mm):', 'Contact height (mm):', 'Width of the wires:'}, 'Electrode display', [], ...
                              {num2str(1000 * ElectrodeConfig.ContactDiameter), num2str(1000 * ElectrodeConfig.ContactLength), num2str(ElectrodeConfig.ElecDiameter)});
        if isempty(res) || (length(res) < 3)
            return
        end
        if ~isnan(str2double(res{1})) && ~isempty(str2double(res{1})) && (str2double(res{1}) >= 0)
            addFields.ContactDiameter = str2double(res{1}) / 1000;
        end
        if ~isnan(str2double(res{2})) && ~isempty(str2double(res{2})) && (str2double(res{2}) >= 0)
            addFields.ContactLength = str2double(res{2}) / 1000;
        end
        if ~isnan(str2double(res{3})) && ~isempty(str2double(res{3})) && (str2double(res{3}) >= 0)
            addFields.ElecDiameter = str2double(res{3});
        end
        Modality = 'ECOG';
    % Configuration for other types of electrodes electrodes
    else
        res = java_dialog('input', {'Contact diameter (mm):', 'Contact height (mm):'}, 'Electrode display', [], ...
                              {num2str(1000 * ElectrodeConfig.ContactDiameter), num2str(1000 * ElectrodeConfig.ContactLength)});
        if isempty(res) || (length(res) < 2)
            return
        end
        if ~isnan(str2double(res{1})) && ~isempty(str2double(res{1})) && (str2double(res{1}) >= 0)
            addFields.ContactDiameter = str2double(res{1}) / 1000;
        end
        if ~isnan(str2double(res{2})) && ~isempty(str2double(res{2})) && (str2double(res{2}) >= 0)
            addFields.ContactLength = str2double(res{2}) / 1000;
        end
        Modality = 'EEG';
    end
    % Save new values in user properties
    if ~isempty(fieldnames(addFields))
        % Get saved user properties
        ElectrodeConfig = bst_get('ElectrodeConfig', Modality);
        % Update fields
        ElectrodeConfig = struct_copy_fields(ElectrodeConfig, addFields, 1);
        % Save modifications
        bst_set('ElectrodeConfig', Modality, ElectrodeConfig);
        % Update the current figure as well
        ElectrodeConfig = struct_copy_fields(ElectrodeConfig, addFields, 1);
    end
    % Update the electrodes configuration
    bst_set('ElectrodeConfig', Modality, ElectrodeConfig);
    % Redraw figure
    panel_ieeg('UpdateFigures');
end



%% ===== THRESHOLD DATA =====
function [Data, ThreshBar] = ThresholdSurfaceData(Data, DataLimit, DataThreshold, sColormap)
    if ~sColormap.isAbsoluteValues && (DataLimit(1) == -DataLimit(2))
        ThreshBar = DataThreshold * max(abs(DataLimit)) * [-1,1];
        Data(abs(Data) < ThreshBar(2)) = 0;
    elseif (DataLimit(2) <= 0)
        ThreshBar = DataLimit(2);
        Data((Data < DataLimit(1) + (DataLimit(2)-DataLimit(1)) * DataThreshold)) = DataLimit(1);
        Data(Data > DataLimit(2)) = 0;
    else
        ThreshBar = DataLimit(1) + (DataLimit(2)-DataLimit(1)) * DataThreshold;
        Data((Data < ThreshBar)) = 0;
        Data(Data > DataLimit(2)) = DataLimit(2);
    end
end


%% ===== ADD THRESHOLD MARKER =====
function AddThresholdMarker(hFig, DataLimit, ThreshBar)
    hColorbar = findobj(hFig, '-depth', 1, 'Tag', 'Colorbar');
    if ~isempty(hColorbar)
        % Delete existing threshold bars
        hThreshBar = findobj(hColorbar, 'Tag', 'ThreshBar');
        delete(hThreshBar);
        % Draw all the threshold bars
        if ((length(ThreshBar) == 1) || (ThreshBar(2) ~= ThreshBar(1)))
            for i = 1:length(ThreshBar)
                yval = (ThreshBar(i) - DataLimit(1)) / (DataLimit(2) - DataLimit(1)) * 256;
                line([0 1], yval.*[1 1], [1 1], 'Color', [1 1 1], 'Parent', hColorbar, 'Tag', 'ThreshBar');
            end
        end
    end
end


%% ===== BLEND ANATOMY DATA =====
% Compute the RGB color values for each vertex of an enveloppe.
% INPUT:
%    - SulciMap     : [nVertices] vector with 0 or 1 values (0=gyri, 1=sulci)
%    - Data         : [nVertices] vector 
%    - DataLimit    : [absMaxVal] or [minVal, maxVal], or []
%    - DataAlpha    : Transparency value for the data (if alpha=0, we only see the anatomy color)
%    - AnatomyColor : [2x3] colors for anatomy (sulci / gyri)
%    - sColormap    : Colormap for the data
% OUTPUT:
%    - mixedRGB     : [nVertices x 3] RGB color value for each vertex
function mixedRGB = BlendAnatomyData(SulciMap, AnatomyColor, Data, DataLimit, DataAlpha, sColormap)
    % Create a background: light 1st color for gyri, 2nd color for sulci
    anatRGB = AnatomyColor(2-SulciMap, :);
    % === OVERLAY: DATA MAP ===
    if ~isempty(Data) && (length(DataLimit) == 2) && (DataLimit(2) ~= DataLimit(1)) && ~any(isnan(DataLimit)) && ~any(isinf(DataLimit))
        Data(isnan(Data)) = 0;
        iDataCmap = round( ((size(sColormap.CMap,1)-1)/(DataLimit(2)-DataLimit(1))) * (Data - DataLimit(1))) + 1;
        iDataCmap(iDataCmap <= 0) = 1;
        iDataCmap(iDataCmap > size(sColormap.CMap,1)) = size(sColormap.CMap,1);
        dataRGB = sColormap.CMap(iDataCmap, :);
    else
        dataRGB = [];
    end
    % === MIX ANATOMY/DATA RGB ===
    mixedRGB = anatRGB;
    if ~isempty(dataRGB)
        toBlend = find(Data ~= 0); % Find vertex indices holding non-zero activation (after thresholding)
        mixedRGB(toBlend,:) = DataAlpha * anatRGB(toBlend,:) + (1-DataAlpha) * dataRGB(toBlend,:);
    end
end

%% ===== SMOOTH SURFACE CALLBACK =====
function SmoothSurface(hFig, iTess, smoothValue)
    % Get surfaces list 
    TessInfo = getappdata(hFig, 'Surface');
    % Ignore MRI slices
    if strcmpi(TessInfo(iTess).Name, 'Anatomy')
        return
    end
    % Get surfaces vertices
    sSurf = bst_memory('GetSurface', TessInfo(iTess).SurfaceFile);
    if (length(sSurf) > 1)
        sSurf = sSurf(1);
    end
    % If smoothValue is null: restore initial vertices
    if (smoothValue == 0)
        set(TessInfo(iTess).hPatch, 'Vertices', sSurf.Vertices);
        return
    end

    % ===== SMOOTH SURFACE =====
    % Get only the cortex vertices
    iVertices = [];
    iAtlasStruct = find(strcmpi('Structures', {sSurf.Atlas.Name}));
    if ~isempty(iAtlasStruct)
        iScouts = find(ismember({sSurf.Atlas(iAtlasStruct).Scouts.Label}, {'lh', '01_Lhemi L', 'Cortex L', 'rh', '01_Rhemi R', 'Cortex R', 'Cortex', 'Cerebellum L','LCer','Cerebellum R','RCer', 'Cerebellum'}));
        if ~isempty(iScouts)
            iVertices = [sSurf.Atlas(iAtlasStruct).Scouts(iScouts).Vertices];
        end
    end
    if isempty(iVertices)
        iVertices = 1:length(sSurf.Vertices);
    end
    % Smoothing factor
    SurfSmoothIterations = ceil(300 * smoothValue * length(iVertices) / 100000);
    % Calculate smoothed vertices locations
    Vertices_sm = sSurf.Vertices;
    Vertices_sm(iVertices,:) = tess_smooth(sSurf.Vertices(iVertices,:), smoothValue, SurfSmoothIterations, sSurf.VertConn(iVertices,iVertices), 1);
    % Apply smoothed locations
    set(TessInfo(iTess).hPatch, 'Vertices',  Vertices_sm);
end


%% ===== SET STRUCTURES LAYOUT =====
function SetStructLayout(hFig, iTess)
    % Get surfaces list 
    TessInfo = getappdata(hFig, 'Surface');
    % Ignore MRI slices
    if strcmpi(TessInfo(iTess).Name, 'Anatomy')
        return
    end
    % Get surfaces vertices
    sSurf = bst_memory('GetSurface', TessInfo(iTess).SurfaceFile);
    if (length(sSurf) > 1)
        sSurf = sSurf(1);
    end

    % ===== SEPARATE STRUCTURES =====
    % Get the Structures atlas
    iAtlasStruct = find(strcmpi('Structures', {sSurf.Atlas.Name}));
    % If there is none: nothing to do here
    if isempty(iAtlasStruct)
        return;
    end
    sScouts = sSurf.Atlas(iAtlasStruct).Scouts;
    % Get surface bounding box
    Vertices = get(TessInfo(iTess).hPatch, 'Vertices');
    dx = max(Vertices(:,1)) - min(Vertices(:,1));
    dy = max(Vertices(:,2)) - min(Vertices(:,2));
    dz = max(Vertices(:,3)) - min(Vertices(:,3));
    % Region by region
    for i = 1:length(sScouts)
        % Define the structure offset
        switch (sScouts(i).Label)
            % Cortex + cerebellum
            case {'lh', '01_Lhemi L', 'Cortex L'},   offSet = [0,  0.6*dy, 0];
            case {'rh', '01_Rhemi R', 'Cortex R'},   offSet = [0, -0.6*dy, 0];
            case {'Cerebellum L', 'LCer'},           offSet = [0,  0.6*dy, -0.6*dz];
            case {'Cerebellum R', 'RCer'},           offSet = [0, -0.6*dy, -0.6*dz];
            case 'Brainstem',                        offSet = [-.2*dx, 0, -0.4*dz];
            % Midbrain
            case {'Accumbens L', 'LAcc'},            offSet = [ .4*dx,  0.3*dy, 0];
            case {'Accumbens R', 'RAcc'},            offSet = [ .4*dx, -0.3*dy, 0];
            case {'Amygdala L','LAmy','LAmy L'},     offSet = [ .2*dx,  0.3*dy, -0.2*dz];
            case {'Amygdala R','RAmy','RAmy R'},     offSet = [ .2*dx, -0.3*dy, -0.2*dz];
            case {'Pallidum L','LEgp', 'LIgp'},      offSet = [0,  0.2*dy, 0.2*dz];
            case{ 'Pallidum R','REgp', 'RIgp'},      offSet = [0, -0.2*dy, 0.2*dz];
            case {'Putamen L','LPut'},               offSet = [0,  0.3*dy, 0];
            case {'Putamen R','RPut'},               offSet = [0, -0.3*dy, 0];
            case {'Caudate L','LCau'},               offSet = [0,  0.3*dy, 0.4*dz];
            case {'Caudate R','RCau'},               offSet = [0, -0.3*dy, 0.4*dz];
            case {'Hippocampus L','LHip','LHip L'},  offSet = [ .1*dx,  0.3*dy, -0.4*dz];
            case {'Hippocampus R','RHip','RHip R'},  offSet = [ .1*dx, -0.3*dy, -0.4*dz];
            case {'Thalamus L','LTha'},              offSet = [-.3*dx,  0.2*dy, -0.3*dz];
            case {'Thalamus R','RTha'},              offSet = [-.3*dx, -0.2*dy, -0.3*dz];
            otherwise,                               offSet = [];
        end
        % Apply offset to this region
        if ~isempty(offSet)
            iVert = sScouts(i).Vertices;
            Vertices(iVert,:) = bst_bsxfun(@plus, Vertices(iVert,:), offSet);
        end
    end
    % Apply modified locations
    set(TessInfo(iTess).hPatch, 'Vertices',  Vertices);
end



%% ===== UPDATE SURFACE ALPHA =====
% Update Alpha values for the given surface.
% Fields that are used from TessInfo:
%    - SurfAlpha : Transparency of the surface patch
%    - Resect    : [x,y,z] doubles : Resect surfaces at these coordinates
%                  or string {'left', 'right', 'all'} : Display only selected part of the surface
function UpdateSurfaceAlpha(hFig, iTess)
    % Get surfaces list 
    TessInfo = getappdata(hFig, 'Surface');
    Surface = TessInfo(iTess);
       
    % Ignore empty surfaces and MRI slices
    if strcmpi(Surface.Name, 'Anatomy') || isempty(Surface.hPatch) || all(~ishandle(Surface.hPatch))
        return 
    end
    % Fibers
    if strcmpi(Surface.Name, 'Fibers')
        lineAlpha = 1 - Surface.SurfAlpha;
        lineWidth = 0.5 + 2.5 * Surface.SurfSmoothValue;
        for iFib = 1:length(Surface.hPatch)
            % Transparency
            Surface.hPatch(iFib).EdgeAlpha = lineAlpha;
            % Smoothing
            Surface.hPatch(iFib).LineWidth = lineWidth;
        end
        return;
    end
    % Apply current smoothing
    SmoothSurface(hFig, iTess, Surface.SurfSmoothValue);
    % Apply structures selection
    if isequal(Surface.Resect, 'struct')
        SetStructLayout(hFig, iTess);
    end
    % Get surfaces vertices
    Vertices = get(Surface.hPatch, 'Vertices');
    nbVertices = length(Vertices);
    % Get vertex connectivity
    sSurf = bst_memory('GetSurface', TessInfo(iTess).SurfaceFile);
    VertConn = sSurf.VertConn;
    if (length(sSurf) > 1)
        sSurf = sSurf(1);
    end
    % Create Alpha data
    FaceVertexAlphaData = ones(length(sSurf.Faces),1) * (1-Surface.SurfAlpha);
    
    % ===== HEMISPHERE SELECTION (CHAR) =====
    if ischar(Surface.Resect)
        % Detect hemispheres
        [rH, lH, isConnected] = tess_hemisplit(sSurf);
        % If there is no separation between  left and right: use the numeric split
        if isConnected
            iHideVert = [];
            switch (Surface.Resect)
                case 'right', Surface.Resect = [0  0.0000001 0];
                case 'left',  Surface.Resect = [0 -0.0000001 0];
            end
        % If there is a structural separation between left and right: usr
        else
            switch (Surface.Resect)
                case 'right', iHideVert = lH;
                case 'left',  iHideVert = rH;
                otherwise,    iHideVert = [];
            end
        end
        % Update Alpha data
        if ~isempty(iHideVert)
            isHideFaces = any(ismember(sSurf.Faces, iHideVert), 2);
            FaceVertexAlphaData(isHideFaces) = 0;
        end
    end
        
    % ===== RESECT (DOUBLE) =====
    if isnumeric(Surface.Resect) && (length(Surface.Resect) == 3) && ~all(Surface.Resect == 0)
        iNoModif = [];
        % Compute mean and max of the coordinates
        meanVertx = mean(Vertices, 1);
        maxVertx  = max(abs(Vertices), [], 1);
        % Limit values
        resectVal = Surface.Resect .* maxVertx + meanVertx;
        % Get vertices that are kept in all the cuts
        for iCoord = 1:3
            if Surface.Resect(iCoord) > 0
                iNoModif = union(iNoModif, find(Vertices(:,iCoord) < resectVal(iCoord)));
            elseif Surface.Resect(iCoord) < 0
                iNoModif = union(iNoModif, find(Vertices(:,iCoord) > resectVal(iCoord)));
            end
        end
        % Get all the faces that are partially visible
        ShowVert = zeros(nbVertices,1);
        ShowVert(iNoModif) = 1;
        facesStatus = sum(ShowVert(sSurf.Faces), 2);
        isFacesVisible = (facesStatus > 0);

        % Get the vertices of the faces that are partially visible
        iVerticesVisible = sSurf.Faces(isFacesVisible,:);
        iVerticesVisible = unique(iVerticesVisible(:))';
        % Hide some vertices
        FaceVertexAlphaData(~isFacesVisible) = 0;
        
        % Get vertices to project
        iVerticesToProject = [iVerticesVisible, tess_scout_swell(iVerticesVisible, VertConn)];
        iVerticesToProject = setdiff(iVerticesToProject, iNoModif);
        % If there are some vertices to project
        if ~isempty(iVerticesToProject)
            % === FIRST PROJECTION ===
            % For the projected vertices: get the distance from each cut
            distToCut = abs(Vertices(iVerticesToProject, :) - repmat(resectVal, [length(iVerticesToProject), 1]));
            % Set the distance to the cuts that are not required to infinite
            distToCut(:,(Surface.Resect == 0)) = Inf;
            % Get the closest cut
            [minDist, closestCut] = min(distToCut, [], 2);

            % Project each vertex       
            Vertices(sub2ind(size(Vertices), iVerticesToProject, closestCut')) = resectVal(closestCut);

            % === SECOND PROJECTION ===            
            % In the faces that have visible and invisible vertices: project the invisible vertices on the visible vertices
            % Get the mixed faces (partially visible)
            ShowVert = zeros(nbVertices,1);
            ShowVert(iVerticesVisible) = 1;
            facesStatus = sum(ShowVert(sSurf.Faces), 2);
            iFacesMixed = find((facesStatus > 0) & (facesStatus < 3));
            % Project vertices
            projectList = logical(ShowVert(sSurf.Faces(iFacesMixed,:)));
            for iFace = 1:length(iFacesMixed)
                iVertVis = sSurf.Faces(iFacesMixed(iFace), projectList(iFace,:));
                iVertHid = sSurf.Faces(iFacesMixed(iFace), ~projectList(iFace,:));
                % Project hidden vertices on first visible vertex
                Vertices(iVertHid, :) = repmat(Vertices(iVertVis(1), :), length(iVertHid), 1);
            end
            % Update patch
            set(Surface.hPatch, 'Vertices', Vertices);
        end
    end
    
    % ===== HIDE NON-SELECTED STRUCTURES =====
    % Hide non-selected Structures scouts
    if ~isempty(sSurf.Atlas) && ismember(sSurf.Atlas(sSurf.iAtlas).Name, {'Structures', 'Source model'})
        % Get scouts display options
        ScoutsOptions = panel_scout('GetScoutsOptions');
        % Get selected scouts
        sScouts = panel_scout('GetSelectedScouts');
        % Get all the selected vertices
%         if ~isempty(sScouts) && strcmpi(ScoutsOptions.showSelection, 'select')
%             % Get the list of hidden vertices
%             iSelVert = unique([sScouts.Vertices]);
%             isSelVert = zeros(length(sSurf.Vertices),1);
%             isSelVert(iSelVert) = 1;
%             % Get the list of hidden faces 
%             isSelFaces = any(isSelVert(sSurf.Faces), 2);
%             % Add hidden faces to current mask
%             FaceVertexAlphaData(~isSelFaces) = 0;
%         end
        FaceVertexAlphaData = 0*FaceVertexAlphaData;
    end
   
    % Update surface
    if all(FaceVertexAlphaData)
        set(Surface.hPatch, 'FaceAlpha', 1-Surface.SurfAlpha);
    else
        set(Surface.hPatch, 'FaceVertexAlphaData', FaceVertexAlphaData, ...
                            'FaceAlpha',           'flat');
    end
end


%% ===== GET CHANNELS POSITIONS =====
% USAGE:  [chan_loc, markers_loc, vertices] = GetChannelPositions(iDS, selChan)
%         [chan_loc, markers_loc, vertices] = GetChannelPositions(iDS, Modality)
%         [chan_loc, markers_loc, vertices] = GetChannelPositions(ChannelMat, ...)
function [chan_loc, markers_loc, vertices] = GetChannelPositions(iDS, selChan)
    global GlobalData;
    % Initialize returned variables
    chan_loc    = zeros(3,0);
    markers_loc = zeros(3,0);
    vertices    = zeros(3,0);
    % Get device type
    if isstruct(iDS)
        ChannelMat = iDS;
        [tag, Device] = channel_detect_device(ChannelMat);
        Channel = ChannelMat.Channel;
    else
        Device = bst_get('ChannelDevice', GlobalData.DataSet(iDS).ChannelFile);
        Channel = GlobalData.DataSet(iDS).Channel;
    end
    % Get selected channels
    if ischar(selChan)
        Modality = selChan;
        selChan = good_channel(Channel, [], Modality);
    end
    Channel = Channel(selChan);
    % Find magnetometers
    if strcmpi(Device, 'Vectorview306')
        iMag = good_channel(Channel, [], 'MEG MAG');
    end
    % Loop on all the sensors
    for i = 1:length(Channel)
        % If position is not defined
        if isempty(Channel(i).Loc)
            Channel(i).Loc = [0;0;0];
        end
        % Get number of integration points or coils
        nIntegPoints = size(Channel(i).Loc, 2);
        % Switch depending on the device
        switch (Device)
            case {'CTF', '4D', 'KIT', 'RICOH'}
                if (nIntegPoints >= 4)
                    chan_loc    = [chan_loc,    mean(Channel(i).Loc(:,1:4),2)];
                    markers_loc = [markers_loc, mean(Channel(i).Loc(:,1:4),2)];
                    vertices    = [vertices,    Channel(i).Loc(:,1:4)];
                else
                    chan_loc    = [chan_loc,    mean(Channel(i).Loc,2)];
                    markers_loc = [markers_loc, mean(Channel(i).Loc,2)];
                    vertices    = [vertices,    Channel(i).Loc];
                end
            case 'KRISS'
                if (nIntegPoints >= 4)
                    chan_loc    = [chan_loc,    mean(Channel(i).Loc(:,1:4),2)];
                    markers_loc = [markers_loc, mean(Channel(i).Loc(:,1:4),2)];
                    vertices    = [vertices,    Channel(i).Loc(:,1:4)];
                else
                    chan_loc    = [chan_loc,    Channel(i).Loc(:,1)];
                    markers_loc = [markers_loc, Channel(i).Loc(:,1)];
                    vertices    = [vertices,    Channel(i).Loc(:,1)];
                end
            case 'Vectorview306'
                chan_loc    = [chan_loc,    mean(Channel(i).Loc, 2)];
                markers_loc = [markers_loc, Channel(i).Loc(:,1)];
                if isempty(iMag) || ismember(i, iMag)
                    vertices = [vertices, Channel(i).Loc];
                end
            case 'BabySQUID'
                chan_loc    = [chan_loc,    Channel(i).Loc(:,1)];
                markers_loc = [markers_loc, Channel(i).Loc(:,1)];
                vertices    = [vertices,    Channel(i).Loc(:,1)];
            case 'BabyMEG'
                chan_loc    = [chan_loc,    mean(Channel(i).Loc,2)];
                markers_loc = [markers_loc, Channel(i).Loc(:,1)];
                vertices    = [vertices,    Channel(i).Loc];
            case {'NIRS-BRS', 'NIRS'}
%                 % Parse channel name
%                 [S,D,WL] = panel_montage('ParseNirsChannelNames', Channel(i).Name);
%                 if (WL == 0)
%                     Factor = 1;
%                 else
%                     Factor = 1 + WL / 100000;
%                 end
                Factor = 1;
                % Position of the channel: mid-way between source and detector, organized in layers by wavelength
                chan_loc    = [chan_loc,    mean(Channel(i).Loc,2) .* Factor];
                markers_loc = [markers_loc, mean(Channel(i).Loc,2) .* Factor];
                vertices    = [vertices,    mean(Channel(i).Loc,2) .* Factor];
            otherwise
                chan_loc    = [chan_loc,    mean(Channel(i).Loc,2)];
                markers_loc = [markers_loc, Channel(i).Loc(:,1)];
                vertices    = [vertices,    Channel(i).Loc];
        end
    end
    chan_loc    = double(chan_loc');
    markers_loc = double(markers_loc');
    vertices    = double(vertices');
end


%% ===== VIEW SENSORS =====
%Display sensors markers and labels in a 3DViz figure.
% Usage:   ViewSensors(hFig, isMarkers, isLabels)           : Display selected channels of figure hFig
%          ViewSensors(hFig, isMarkers, isLabels, Modality) : Display channels of target Modality in figure hFig
% Parameters :
%     - hFig      : target '3DViz' figure
%     - isMarkers : Sensors markers status : {0 (hide), 1 (show), [] (ignore)}
%     - isLabels  : Sensors labels status  : {0 (hide), 1 (show), [] (ignore)}
%     - isMesh    : If 1, display a mesh; if 0, display only the markers
%     - Modality  : Sensor type to display
function ViewSensors(hFig, isMarkers, isLabels, isMesh, Modality)
    global GlobalData;
    % Parse inputs
    if (nargin < 5) || isempty(Modality)
        Modality = '';
    end
    if (nargin < 4) || isempty(isMesh)
        isMesh = 1;
    end
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    if isempty(iDS)
        return
    end
    % Check if there is a channel file associated with this figure
    if isempty(GlobalData.DataSet(iDS).Channel)
        return
    end
    Figure = GlobalData.DataSet(iDS).Figure(iFig);
    PlotHandles = Figure.Handles;
    isTopography = strcmpi(Figure.Id.Type, 'Topography') && ~ismember(Figure.Id.SubType, {'3DElectrodes', '3DOptodes'});
    is2D = 0;
    
    % ===== MARKERS LOCATIONS =====
    % === TOPOGRAPHY ===
    if isTopography
        % Markers locations where stored in the Handles structure while creating topography patch
        if isempty(PlotHandles.MarkersLocs)
            return
        end
        % Get a location to display the Markers
        markersLocs = PlotHandles.MarkersLocs;
        % Flag=1 if 2D display
        is2D = ismember(Figure.Id.SubType, {'2DDisc','2DSensorCap'});
        % Get selected channels
        selChan = Figure.SelectedChannels;
        markersOrient = [];
        
    % === 3DVIZ ===
    else
        Channel = GlobalData.DataSet(iDS).Channel;
        % Find sensors of the target modality, select and display them
        if isempty(Modality)
            selChan = Figure.SelectedChannels;
        else
            selChan = good_channel(Channel, [], Modality);
        end
        % If no channels for this modality
        if isempty(selChan)
            bst_error(['No "' Modality '" sensors in channel file: "' GlobalData.DataSet(iDS).ChannelFile '".'], 'View sensors', 0);
            return
        end
        % Get sensors positions
        [tmp, markersLocs] = GetChannelPositions(iDS, selChan);
        % Markers orientations: only for MEG
        if ismember(Modality, {'MEG', 'MEG GRAD', 'MEG MAG', 'Vectorview306', 'CTF', '4D', 'KIT', 'KRISS', 'BabyMEG', 'RICOH'})
            markersOrient = cell2mat(cellfun(@(c)c(:,1), {Channel(selChan).Orient}, 'UniformOutput', 0))';
        else
            markersOrient = [];
        end
    end
    % Make sure that electrodes locations are in double precision
    markersLocs = double(markersLocs);
    markersOrient = double(markersOrient);
    
    % ===== DISPLAY MARKERS OBJECTS =====
    % Put focus on target figure
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    % === SENSORS ===
    if ~isempty(isMarkers)
        % Delete sensor markers
        if ~isempty(PlotHandles.hSensorMarkers) && all(ishandle(PlotHandles.hSensorMarkers))
            delete(PlotHandles.hSensorMarkers);
            delete(PlotHandles.hSensorOrient);
            PlotHandles.hSensorMarkers = [];
            PlotHandles.hSensorOrient = [];
        end
        
        % Display sensors markers
        if isMarkers
            % Is display of a flat 2D topography map
            if is2D
                PlotHandles.hSensorMarkers = PlotSensors2D(hAxes, markersLocs);
            % If more than one patch : transparent sensor cap
            elseif ~isempty(findobj(hAxes, 'type', 'patch')) || ~isempty(findobj(hAxes, 'type', 'surface'))
                [PlotHandles.hSensorMarkers, PlotHandles.hSensorOrient] = PlotSensorsNet(hAxes, markersLocs, 0, isMesh, markersOrient);
            % Else, sensor cap is the only patch => display its faces
            else
                [PlotHandles.hSensorMarkers, PlotHandles.hSensorOrient] = PlotSensorsNet(hAxes, markersLocs, 1, isMesh, markersOrient);
            end
        end
    end
    
    % === LABELS ===
    if ~isempty(isLabels)
        % Delete sensor labels
        if ~isempty(PlotHandles.hSensorLabels)
            delete(PlotHandles.hSensorLabels(ishandle(PlotHandles.hSensorLabels)));
            PlotHandles.hSensorLabels = [];
        end
        % Display sensor labels
        if isLabels && ~isempty(selChan)
            % Check if the channels are ECOG/SEEG
            isIntraEEG = ismember(upper(GlobalData.DataSet(iDS).Channel(selChan(1)).Type), {'SEEG', 'ECOG'});
            % 3DElectrodes: Bright green for higher readability
            hElectrodeObjects = [findobj(Figure.hFigure, 'Tag', 'ElectrodeGrid'); findobj(Figure.hFigure, 'Tag', 'ElectrodeDepth'); findobj(Figure.hFigure, 'Tag', 'ElectrodeWire')];
            if ~isempty(hElectrodeObjects)
                markerColor = [.4,1,.4];
            % Default color for sensors text: bright yellow
            else
                markerColor = [1,1,.2];
            end
            % Get sensor names
            sensorNames = {GlobalData.DataSet(iDS).Channel(selChan).Name}';
            % SEEG/ECOG: Special display
            if isIntraEEG
                % Get the sensor groups available and simplify the names of the sensors
                [iGroupEeg, GroupNames, displayNames] = panel_montage('GetEegGroups', GlobalData.DataSet(iDS).Channel(selChan), [], 1);
            else
                displayNames = sensorNames;
            end
            % Add a small offset to the marker location to display the label
            if strcmpi(Figure.Id.Type, 'Topography') && strcmpi(Figure.Id.SubType, '2DElectrodes')
                X = markersLocs(:,1) + 0.0025;
                Y = markersLocs(:,2);
                Z = markersLocs(:,3) + 0.010;
            else
                X = 1.05*markersLocs(:,1);
                Y = 1.05*markersLocs(:,2);
                Z = 1.03*markersLocs(:,3);
            end
            % Plot the sensors
            PlotHandles.hSensorLabels = text(X, Y, Z, ...
                displayNames, ...
                'Parent',              hAxes, ...
                'HorizontalAlignment', 'center', ...
                'FontSize',            bst_get('FigFont') + 2, ...
                'FontUnits',           'points', ...
                'FontWeight',          'normal', ...
                'Tag',                 'SensorsLabels', ...
                'Color',               markerColor, ...
                'Interpreter',         'none');
            % Get the 3DElectrodes object
            hElectrodeGrid = findobj(hFig, 'Tag', 'ElectrodeGrid');
            % For ECOG/SEEG: Check which sensors are currently visible
            isLabelVisible = [];
            if isIntraEEG && ~isempty(hElectrodeGrid)
                isLabelVisible = ones(1, length(PlotHandles.hSensorLabels));
                GridUserData = get(hElectrodeGrid, 'UserData');
                GridFaceVertexAlphaData = get(hElectrodeGrid, 'FaceVertexAlphaData');
                % For each one, check if they are visible
                for iGroup = 1:length(iGroupEeg)
                    if ~isempty(iGroupEeg{iGroup})
                        isVisible = any(GridFaceVertexAlphaData(GridUserData == iGroupEeg{iGroup}(1)) > 0);
                        isLabelVisible(iGroupEeg{iGroup}) = isVisible;
                    end
                end
            end
            % Add user data to save the channel indices
            for i = 1:length(PlotHandles.hSensorLabels) 
                set(PlotHandles.hSensorLabels(i), 'UserData', i);
                if ~isempty(isLabelVisible) && ~isLabelVisible(i)
                    set(PlotHandles.hSensorLabels(i), 'Visible', 'off');
                end
            end
        end
    end
    GlobalData.DataSet(iDS).Figure(iFig).Handles = PlotHandles;
    % Repaint selected sensors for this figure
    UpdateFigSelectedRows(iDS, iFig);
end


%% ===== VIEW HEAD POINTS =====
function ViewHeadPoints(hFig, isVisible)
    global GlobalData;
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    if isempty(iDS)
        return
    end
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    % If no head points are available: exit
    if isempty(GlobalData.DataSet(iDS).HeadPoints) || ~isfield(GlobalData.DataSet(iDS).HeadPoints, 'Loc') || isempty(GlobalData.DataSet(iDS).HeadPoints.Loc)
        return
    end
    HeadPoints = GlobalData.DataSet(iDS).HeadPoints;
    
    % Get existing sensor patches: do not display points where there are already EEG markers
    hSensorsPatch = findobj(hAxes, '-depth', 1, 'Tag', 'SensorsPatch');
    if ~isempty(hSensorsPatch) && strcmpi(get(hSensorsPatch,'Visible'), 'on')
        % Get sensors markers
        pts = get(hSensorsPatch, 'Vertices');
        % Compute full distance matrix sensors/headpoints
        nhp = length(HeadPoints.Type);
        ns = length(pts);
        dist = sqrt((pts(:,1)*ones(1,nhp) - ones(ns,1)*HeadPoints.Loc(1,:)).^2 + (pts(:,2)*ones(1,nhp) - ones(ns,1)*HeadPoints.Loc(2,:)).^2 + (pts(:,3)*ones(1,nhp) - ones(ns,1)*HeadPoints.Loc(3,:)).^2);
        % Duplicates: head points that are less than .1 millimeter away from a sensor
        iDupli = find(min(dist) < 0.0001);
        % If any duplicates: move them slightly inside so they are not completely overlapping with the electrodes
        [th,phi,r] = cart2sph(HeadPoints.Loc(1,iDupli), HeadPoints.Loc(2,iDupli), HeadPoints.Loc(3,iDupli));
        [HeadPoints.Loc(1,iDupli), HeadPoints.Loc(2,iDupli), HeadPoints.Loc(3,iDupli)] = sph2cart(th, phi, r - 0.0001);
    end
    
    % Else, get previous head points
    hHeadPointsMarkers = findobj(hAxes, 'Tag', 'HeadPointsMarkers');
    hHeadPointsLabels  = findobj(hAxes, 'Tag', 'HeadPointsLabels');
    % If head points graphic objects already exist: set the "Visible" property
    if ~isempty(hHeadPointsMarkers)
        if isVisible
            set([hHeadPointsMarkers hHeadPointsLabels], 'Visible', 'on');
        else
            set([hHeadPointsMarkers hHeadPointsLabels], 'Visible', 'off');
        end
    % If head points objects were not created yet: create them
    elseif isVisible
        % Get digitized points locations
        digLoc = double(HeadPoints.Loc)';
        % Prepare display names
        digNames = cell(size(HeadPoints.Label));
        for i = 1:length(HeadPoints.Label)
            switch upper(HeadPoints.Type{i})
                case 'CARDINAL'
                    digNames{i} = HeadPoints.Label{i};
                case 'EXTRA'
                    digNames{i} = HeadPoints.Label{i};
                case 'HPI'
                    if isnumeric(HeadPoints.Label{i})
                        digNames{i} = [HeadPoints.Type{i}, '-', num2str(HeadPoints.Label{i})];
                    else
                        digNames{i} = HeadPoints.Label{i};
                        if isempty(strfind(digNames{i}, 'HPI-')) && isempty(strfind(digNames{i}, 'HLC-'))
                            digNames{i} = ['HPI-', digNames{i}];
                        end
                    end
                otherwise
                    if isnumeric(HeadPoints.Label{i})
                        digNames{i} = [HeadPoints.Type{i}, '-', num2str(HeadPoints.Label{i})];
                    else
                        digNames{i} = [HeadPoints.Type{i}, '-', HeadPoints.Label{i}];
                    end
            end
        end
        % Get the different types of points
        iFid   = {find(strcmpi(HeadPoints.Type, 'CARDINAL')), find(strcmpi(HeadPoints.Type, 'HPI'))};
        iExtra = find(strcmpi(HeadPoints.Type, 'EXTRA') | strcmpi(HeadPoints.Type, 'EEG'));
        % Plot fiducials
        for k = 1:2
            if ~isempty(iFid{k})
                if (k == 1)
                    markerFaceColor = [1 1 .3];
                    objTag = 'HeadPointsFid';
                else
                    markerFaceColor = [.9 .6 .2];
                    objTag = 'HeadPointsHpi';
                end
                % Display markers
                line(digLoc(iFid{k},1), digLoc(iFid{k},2), digLoc(iFid{k},3), ...
                    'Parent',          hAxes, ...
                    'LineWidth',       2, ...
                    'LineStyle',       'none', ...
                    'MarkerFaceColor', markerFaceColor, ...
                    'MarkerEdgeColor', [1 .4 .4], ...
                    'MarkerSize',      7, ...
                    'Marker',          'o', ...
                    'UserData',        iFid{k}, ...
                    'Tag',             objTag);
                % Group by similar names
                [uniqueNames, iUnique] = unique(digNames(iFid{k}));
                % Display labels
                txtLoc = digLoc(iFid{k}(iUnique),:);
                txtLocSph = [];
                % Bring the labels further away from the head to make them readable
                [txtLocSph(:,1), txtLocSph(:,2), txtLocSph(:,3)] = cart2sph(txtLoc(:,1), txtLoc(:,2), txtLoc(:,3));
                [txtLoc(:,1), txtLoc(:,2), txtLoc(:,3)] = sph2cart(txtLocSph(:,1), txtLocSph(:,2), txtLocSph(:,3) + 0.03);
                % Display text
                text(txtLoc(:,1), txtLoc(:,2), txtLoc(:,3), ...
                    uniqueNames', ...
                    'Parent',              hAxes, ...
                    'HorizontalAlignment', 'center', ...
                    'Fontsize',            bst_get('FigFont') + 2, ...
                    'FontUnits',           'points', ...
                    'FontWeight',          'normal', ...
                    'Tag',                 'HeadPointsLabels', ...
                    'Color',               [1,1,.2], ...
                    'Interpreter',         'none');
            end
        end
        % Plot extra head points
        if ~isempty(iExtra)
            % Display markers
            line(digLoc(iExtra,1), digLoc(iExtra,2), digLoc(iExtra,3), ...
                'Parent',          hAxes, ...
                'LineWidth',       2, ...
                'LineStyle',       'none', ...
                'MarkerFaceColor', [.3 1 .3], ...
                'MarkerEdgeColor', [.4 .7 .4], ...
                'MarkerSize',      6, ...
                'Marker',          'o', ...
                'UserData',        iExtra, ...
                'Tag',             'HeadPointsMarkers');
        end
    end
end


%% ===== VIEW AXIS =====
function ViewAxis(hFig, isVisible)
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    if (nargin < 2)
        isVisible = isempty(findobj(hAxes, 'Tag', 'AxisXYZ'));
    end
    if isVisible
        line([0 0.15], [0 0], [0 0], 'Color', [1 0 0], 'Marker', '>', 'Parent', hAxes, 'Tag', 'AxisXYZ');
        line([0 0], [0 0.15], [0 0], 'Color', [0 1 0], 'Marker', '>', 'Parent', hAxes, 'Tag', 'AxisXYZ');
        line([0 0], [0 0], [0 0.15], 'Color', [0 0 1], 'Marker', '>', 'Parent', hAxes, 'Tag', 'AxisXYZ');
        text(0.151, 0, 0, 'X', 'Color', [1 0 0], 'Parent', hAxes, 'Tag', 'AxisXYZ');
        text(0, 0.151, 0, 'Y', 'Color', [0 1 0], 'Parent', hAxes, 'Tag', 'AxisXYZ');
        text(0, 0, 0.151, 'Z', 'Color', [0 0 1], 'Parent', hAxes, 'Tag', 'AxisXYZ');
    else
        hAxisXYZ = findobj(hAxes, 'Tag', 'AxisXYZ');
        if ~isempty(hAxisXYZ)
            delete(hAxisXYZ);
        end
    end
end


%% ===== PLOT SENSORS: 2D =====
% Plot the sensors projected in 2D in a 3D figure.
% USAGE:  hNet = gui_plotSensors2D( hAxes, vertices )
% INPUT:  - hAxes        : handle to axes in which you need to display the sensors patch
%         - vertices     : [NbVert * NbIntergationPoints, 3] double, (x,y,z) location of each sensor
function [hNet, hOrient] = PlotSensors2D( hAxes, vertices )
    hOrient = [];
    % Try to plot markers with PATCH function
    try
        % === PREPARE PATCH ===
        % Convex hull of the set of points
        faces = delaunay(vertices(:,2), vertices(:,1));
        vertices(:,3) = 0.05;

        % === DISPLAY PATCH ===
        % Create sensors patch
        hNet = patch('Vertices',        vertices, ...
                     'Faces',           faces, ...
                     'FaceVertexCData', repmat([1 1 1], [length(vertices), 1]), ...
                     'Parent',          hAxes, ...
                     'Marker',          'o', ...
                     'FaceColor',       'none', ...
                     'EdgeColor',       'none', ...
                     'LineWidth',       2, ...
                     'MarkerEdgeColor', [.4 .4 .3], ...
                     'MarkerFaceColor', 'flat', ...
                     'MarkerSize',      6, ...
                     'BackfaceLighting', 'lit', ...
                     'Tag',             'SensorsPatch');

    % If convhull or patch crashed : try LINE function
    catch
        warning('Brainstorm:PatchError', 'patch() function returned an error. Trying to display sensors with line() function...');
        hNet = line(vertices(:,1), vertices(:,2), vertices(:,3), ...
                    'Parent',          hAxes, ...
                    'LineWidth',       2, ...
                    'LineStyle',       'none', ...
                    'MarkerFaceColor', [1 1 1], ...
                    'MarkerEdgeColor', [.4 .4 .4], ...
                    'MarkerSize',      6, ...
                    'Marker',          'o', ...
                    'Tag',             'SensorsMarkers');
    end
end


%% ===== PLOT COILS =====
function PlotCoils(hFig, Modality, isDetails)
    global GlobalData;
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    if isempty(iDS)
        return
    end
    % Check if there is a channel file associated with this figure
    if isempty(GlobalData.DataSet(iDS).Channel)
        return
    end
    % Get channels
    Channels = GlobalData.DataSet(iDS).Channel;
    % Get axes
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    if isempty(hAxes)
        return;
    end
    % Rendering options
    patchOpt = {...
        'Faces',            [1 2 3 4 1], ...
        'Parent',           hAxes, ...
        'Marker',           'none', ...
        'LineWidth',        1, ...
        'FaceAlpha',        1, ...
        'EdgeAlpha',        1, ...
        'EdgeColor',        [.4 .4 .3], ...
        'BackfaceLighting', 'unlit', ...
        'AmbientStrength',  0.5, ...
        'DiffuseStrength',  0.5, ...
        'SpecularStrength', 0.2, ...
        'SpecularExponent', 1, ...
        'SpecularColorReflectance', 0.5, ...
        'FaceLighting',     'gouraud', ...
        'EdgeLighting',     'gouraud', ...
        'Tag',              'CoilsPatch'};
    textOpt = {...
        'Parent',              hAxes, ...
        'HorizontalAlignment', 'center', ...
        'FontSize',            bst_get('FigFont') + 2, ...
        'FontUnits',           'points', ...
        'FontWeight',          'normal', ...
        'Tag',                 'SensorsLabelsRef', ...
        'Interpreter',         'none'};
    oriOpt = {...
        'LineWidth',  1, ...
        'Marker',     'none', ...
        'MarkerSize', 3, ...
        'Parent',     hAxes, ...
        'Tag',        'LineOrient'};

    % Loop on all sensors
    for i = 1:length(Channels)
        % Get number of integration points representing the sensor
        nPoints = size(Channels(i).Loc, 2);
        % Plot different systems in different ways
        switch lower(Modality)
            % ===== CTF =====
            case {'ctf', 'kit', 'kriss', '4d', 'babymeg', 'ricoh'}
                % === CTF: MEG AXIAL GRADIOMETER ===
                if (nPoints == 8) && ~strcmpi(Channels(i).Type, 'MEG REF')
                    oriLength = 0.007;
                    % Coil close to the head
                    patch(...
                        'Vertices',  Channels(i).Loc(:,1:4)', ...
                        'FaceColor', [1 1 0], ...
                        patchOpt{:});
                    % Detailed plot
                    if isDetails
                        % Coil far from the head (optional)
                        patch(...
                            'Vertices',  Channels(i).Loc(:,5:8)', ...
                            'FaceColor', [.2 .2 1], ...
                            patchOpt{:});
                        % Channel label
                        % txtLoc = .8 * mean(Channels(i).Loc(:,1:4)') + .2 * mean(Channels(i).Loc(:,5:8)');
                        % text(txtLoc(1), txtLoc(2), txtLoc(3), Channels(i).Name, 'Color', [.4,1,.4], textOpt{:});
                        % Orientations (close)
                        oriLoc = mean(Channels(i).Loc(:,1:4)');
                        oriDir = mean(Channels(i).Orient(:,1:4)');
                        oriLin = [oriLoc; oriLoc + oriDir ./ norm(oriDir) .* oriLength];
                        line(oriLin(:,1), oriLin(:,2), oriLin(:,3), 'Color', [1 0 0], oriOpt{:});
                        % Orientations (far)
                        oriLoc = mean(Channels(i).Loc(:,5:8)');
                        oriDir = mean(Channels(i).Orient(:,5:8)');
                        oriLin = [oriLoc; oriLoc + oriDir ./ norm(oriDir) .* oriLength];
                        line(oriLin(:,1), oriLin(:,2), oriLin(:,3), 'Color', [1 0 0], oriOpt{:});
                    end

                % === CTF: MEG REF ===
                elseif isDetails && strcmpi(Channels(i).Type, 'MEG REF')
                    % Accurate representation (4 points per coil)
                    if (nPoints >= 4)
                        % REF Magnetometers:   WHITE
                        if (nPoints == 4)
                            Color = [1 1 1];
                            oriLength = 0.015;
                        % REF Gradiometers (offdiag):   GREEN
                        elseif (nPoints == 8) && ~isempty(Channels(i).Comment) && ~isempty(strfind(Channels(i).Comment, 'offdiag'))
                            Color = [.1 1 .1];
                            oriLength = 0.025;
                        % REF Gradiometers (diag):   ORANGE
                        elseif (nPoints == 8)
                            Color = [1 .5 .1];
                            oriLength = 0.025;
                        else
                            warning(['Unknown type of coil: ' Channels(i).Name]);
                            continue;
                        end
                        % Plot first coil
                        patch(...
                            'Vertices',   Channels(i).Loc(:,1:4)', ...
                            'FaceColor',  Color, ...
                            patchOpt{:});
                        % Orientation of the coil
                        oriLoc = mean(Channels(i).Loc(:,1:4)');
                        oriDir = mean(Channels(i).Orient(:,1:4)');
                        oriLin = [oriLoc; oriLoc + oriDir ./ norm(oriDir) .* oriLength];
                        line(oriLin(:,1), oriLin(:,2), oriLin(:,3), 'Color', [1 0 0], oriOpt{:});
                        % Coil label
                        txtLoc = oriLoc + 1.5 * oriLength * oriDir ./ norm(oriDir);
                        text(txtLoc(1), txtLoc(2), txtLoc(3), [Channels(i).Name '-1'], 'Color', Color, textOpt{:});

                        % Plot second coil
                        if (nPoints == 8)
                            patch(...
                                'Vertices',   Channels(i).Loc(:,5:8)', ...
                                'FaceColor',  Color, ...
                                patchOpt{:});
                            % Orientation of the coil
                            oriLoc = mean(Channels(i).Loc(:,5:8)');
                            oriDir = mean(Channels(i).Orient(:,5:8)');
                            oriLin = [oriLoc; oriLoc + oriDir ./ norm(oriDir) .* oriLength];
                            line(oriLin(:,1), oriLin(:,2), oriLin(:,3), 'Color', [1 0 0], oriOpt{:});
                            % Coil label
                            txtLoc = oriLoc + 1.5 * oriLength * oriDir ./ norm(oriDir);
                            text(txtLoc(1), txtLoc(2), txtLoc(3), [Channels(i).Name '-2'], 'Color', Color, textOpt{:});
                        end

                    % Simple definition (no integration points)
                    elseif (nPoints < 4) && (~strcmpi(Channels(i).Type, 'MEG REF') || isDetails)
                        oriLength = 0.030;
                        % REF Magnetometers:   WHITE
                        if (nPoints == 1)
                            Color = [1 1 1];
                        % REF Gradiometers (offdiag):   GREEN
                        elseif (nPoints == 2) && ~isempty(Channels(i).Comment) && ~isempty(strfind(Channels(i).Comment, 'offdiag'))
                            Color = [.1 1 .1];
                        % REF Gradiometers (diag):   ORANGE
                        elseif (nPoints == 2)
                            Color = [1 .5 .1];
                        else
                            warning(['Unknown type of coil: ' Channels(i).Name]);
                            continue;
                        end

                        % Plot first coil
                        coilLoc = Channels(i).Loc(:,1)';
                        line(coilLoc(1), coilLoc(2), coilLoc(3), ...
                            'Parent',          hAxes, ...
                            'LineStyle',       'none', ...
                            'MarkerFaceColor', Color, ...
                            'MarkerEdgeColor', [.4 .4 .4], ...
                            'MarkerSize',      8, ...
                            'Marker',          'o', ...
                            'Tag',             'SensorsMarkersRef');
                        % Orientation of the coil
                        oriDir = Channels(i).Orient(:,1)';
                        oriLin = [coilLoc; coilLoc + oriDir ./ norm(oriDir) .* oriLength];
                        line(oriLin(:,1), oriLin(:,2), oriLin(:,3), 'Color', Color, oriOpt{:});
                        % Coil label
                        txtLoc = coilLoc + 1.5 * oriLength * oriDir ./ norm(oriDir);
                        text(txtLoc(1), txtLoc(2), txtLoc(3), [Channels(i).Name '-1'], 'Color', Color, textOpt{:});
                        
                        % Plot second coil
                        if (nPoints == 2)
                            % Plot first coil
                            coilLoc = Channels(i).Loc(:,2)';
                            line(coilLoc(1), coilLoc(2), coilLoc(3), ...
                                'Parent',          hAxes, ...
                                'LineStyle',       'none', ...
                                'MarkerFaceColor', Color, ...
                                'MarkerEdgeColor', [.4 .4 .4], ...
                                'MarkerSize',      8, ...
                                'Marker',          'o', ...
                                'Tag',             'SensorsMarkersRef');
                            % Orientation of the coil
                            oriDir = Channels(i).Orient(:,2)';
                            oriLin = [coilLoc; coilLoc + oriDir ./ norm(oriDir) .* oriLength];
                            line(oriLin(:,1), oriLin(:,2), oriLin(:,3), 'Color', Color, oriOpt{:});
                            % Coil label
                            txtLoc = coilLoc + 1.5 * oriLength * oriDir ./ norm(oriDir);
                            text(txtLoc(1), txtLoc(2), txtLoc(3), [Channels(i).Name '-2'], 'Color', Color, textOpt{:});
                        end
                    end
                    
                % === OTHER: MAGNETOMETER ===
                elseif (nPoints == 4) && (~strcmpi(Channels(i).Type, 'MEG REF') || isDetails)
                    oriLength = 0.007;
                    % Plot coil
                    patch(...
                        'Vertices',  Channels(i).Loc(:,1:4)', ...
                        'FaceColor', [1 1 0], ...
                        patchOpt{:});
                    % Additional details
                    if isDetails
                        % Orientation of the coil
                        oriLoc = mean(Channels(i).Loc(:,1:4)');
                        oriDir = mean(Channels(i).Orient(:,1:4)');
                        oriLin = [oriLoc; oriLoc + oriDir ./ norm(oriDir) .* oriLength];
                        line(oriLin(:,1), oriLin(:,2), oriLin(:,3), 'Color', [.8 .8 0], oriOpt{:});
                        % Channel label
                        % txtLoc = oriLoc + 1.5 * oriLength * oriDir ./ norm(oriDir);
                        % text(txtLoc(1), txtLoc(2), txtLoc(3), Channels(i).Name, 'Color', [.8 .8 0], textOpt{:});
                    end
                end
                
                
            % ===== ELEKTA-NEUROMAG =====
            case 'vectorview306'
                
                % === ELEKTA: MAGNETOMETER ===
                % Plot only the magnetometer because they are all on the same chip
                if strcmpi(Channels(i).Type, 'MEG MAG') && (nPoints == 4)
                    oriLength = 0.015;
                    chLoc = Channels(i).Loc(:,[1 2 4 3])' .* 1.00;
                    % Coil patch
                    patch('Vertices', chLoc, 'FaceColor', [1 1 0], patchOpt{:});
                    % Additional details
                    if isDetails
                        % Orientation of the coil
                        oriLoc = mean(chLoc);
                        oriDir = mean(Channels(i).Orient(:,1:4)');
                        oriLin = [oriLoc; oriLoc + oriDir ./ norm(oriDir) .* oriLength];
                        line(oriLin(:,1), oriLin(:,2), oriLin(:,3), 'Color', [.8 .8 0], oriOpt{:});
                        % Channel label
                        txtLoc = oriLoc + 1.5 * oriLength * oriDir ./ norm(oriDir);
                        text(txtLoc(1), txtLoc(2), txtLoc(3), Channels(i).Name, 'Color', [.8 .8 0], textOpt{:});
                    end
                    
                % === ELEKTA: PLANAR GRADIOMETER ===
                elseif isDetails && strcmpi(Channels(i).Type, 'MEG GRAD') && (nPoints == 4)
                    oriLength = 0.010;
                    % Planar gradiometer #2 or #3
                    if (Channels(i).Name(end) == '2')
                        chLoc = Channels(i).Loc(:,[1 2 4 3])' .* 1.01;
                        Color = [1 0 0];
                    elseif (Channels(i).Name(end) == '3')
                        chLoc = Channels(i).Loc(:,[1 2 4 3])' .* 1.02;
                        Color = [.2 1 .2];
                    end
                    % Split in two coils
                    Vertices1 = [chLoc([1,2],:); .6 .* chLoc([2,1],:) + .4 .* chLoc([3,4],:)];
                    Vertices2 = [.4 .* chLoc([1,2],:) + .6 .* chLoc([4,3],:); chLoc([3,4],:)];
                    % Coil patches
                    patch('Vertices', Vertices1, 'FaceColor', Color, patchOpt{:});
                    patch('Vertices', Vertices2, 'FaceColor', Color, patchOpt{:});
                    % Orientation of the coil #2
                    oriLoc = mean(Vertices1);
                    oriDir = mean(Channels(i).Orient(:,1:2)') .* sign(Channels(i).Weight(1));
                    oriLin = [oriLoc; oriLoc + oriDir ./ norm(oriDir) .* oriLength];
                    line(oriLin(:,1), oriLin(:,2), oriLin(:,3), 'Color', 0.8 .* Color, oriOpt{:});
                    % Channel label
                    txtLoc = oriLoc + 1.5 * oriLength * oriDir ./ norm(oriDir);
                    text(txtLoc(1), txtLoc(2), txtLoc(3), Channels(i).Name, 'Color', 0.8 .* Color, textOpt{:});
                    % Orientation of the coil #3
                    oriLoc = mean(Vertices2);
                    oriDir = mean(Channels(i).Orient(:,3:4)') .* sign(Channels(i).Weight(3));
                    oriLin = [oriLoc; oriLoc + oriDir ./ norm(oriDir) .* oriLength];
                    line(oriLin(:,1), oriLin(:,2), oriLin(:,3), 'Color', 0.8 .* Color, oriOpt{:});
                end
        end
    end
end


%% ===== PLOT NIRS CAP =====
function hPairs = PlotNirsCap(hFig, isDetails)
    global GlobalData;
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    if isempty(iDS) || isempty(GlobalData.DataSet(iDS).Channel)
        return
    end
    % Get axes
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    if isempty(hAxes)
        return;
    end
    % Get channels for topography figures
    if strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.Type, 'Topography')
        [tmp,tmp,iChannels] = figure_topo('GetFigureData', iDS, iFig, 1);
    % Get channels for other 3D figures
    else
        iChannels = channel_find(GlobalData.DataSet(iDS).Channel, 'NIRS');
    end
    Channels = GlobalData.DataSet(iDS).Channel(iChannels);
    % Check for errors in the channel definition: Loc needs 2 set of positions (source, detector)
    if any(cellfun(@(c)size(c,2), {Channels.Loc}) ~= 2)
        error('NIRS sensors need to be defined by two positions: the source and and the detector.');
    end
    
    % Get all sources: Get unique positions for first location
    locSrc = cellfun(@(c)c(:,1)', {Channels.Loc}, 'UniformOutput', 0);
    locSrc = cat(1, locSrc{:});
    [locSrc, iChanSrc] = unique(locSrc, 'rows');
    % Sort sources
    [iChanSrc,iSort] = sort(iChanSrc);
    locSrc = locSrc(iSort,:);

    % Get all detectors: Get unique positions for second location
    locDet = cellfun(@(c)c(:,2)', {Channels.Loc}, 'UniformOutput', 0);
    locDet = cat(1, locDet{:});
    [locDet, iChanDet] = unique(locDet, 'rows');
    % Sort detectors
    [iChanDet,iSort] = sort(iChanDet);
    locDet = locDet(iSort,:);
    
    % Get all the spheres locations
    sphLoc = [locSrc; locDet];
    
    % Parse indices from the channel name
    [S,D,WL] = panel_montage('ParseNirsChannelNames', {Channels.Name});
    % Build source/detector names 
    Snames = cell(1, length(iChanSrc));
    for i = 1:length(Snames)
        Snames{i} = sprintf('S%d', S(iChanSrc(i)));
    end
    Dnames = cell(1, length(iChanDet));
    for i = 1:length(Dnames)
        Dnames{i} = sprintf('D%d', D(iChanDet(i)));
    end
    
    % Delete previously created electrodes
    delete(findobj(hAxes, 'Tag', 'NirsCapPatch'));
    delete(findobj(hAxes, 'Tag', 'NirsCapLine'));
    delete(findobj(hAxes, 'Tag', 'NirsCapText'));

    % ===== DISPLAY SPHERES =====
    % Define optode geometry
    nVert = 42;
    [sphVertex, sphFace] = tess_sphere(nVert);
    % Apply optode size
    sphSize = 0.004;
    sphVertex = bst_bsxfun(@times, sphVertex, sphSize);
    % Duplicate this sphere
    nSph   = size(sphLoc,1);
    nFace  = size(sphFace,1);
    Vertex = zeros(nSph*nVert, 3);
    Faces  = zeros(nSph*nFace, 3);
    for iSph = 1:nSph
        % Set electrode position
        chanVertex = bst_bsxfun(@plus, sphLoc(iSph,:), sphVertex);
        % Report in final patch
        iVert  = (iSph-1) * nVert + (1:nVert);
        iFace = (iSph-1) * nFace + (1:nFace);
        Vertex(iVert,:) = chanVertex;
        Faces(iFace,:)  = sphFace + nVert*(iSph-1);
    end
    % Default color: yellow, no transparency    
    VertexRGB = [repmat([.9,0,0], size(locSrc,1) * nVert, 1); ...  % Source:   RED
                 repmat([0,.9,0], size(locDet,1) * nVert, 1)];     % Detector: GREEN
    % Save the name of the sphere in the UserData (detector or source)
    UserData = [reshape(repmat(Snames, nVert, 1), [], 1); ...
                reshape(repmat(Dnames, nVert, 1), [], 1)];
    % Create patch for all the spheres
    patch(...
        'Faces',               Faces, ...
        'Vertices',            Vertex,...
        'FaceColor',           'interp', ...
        'FaceVertexCData',     VertexRGB, ...
        'FaceAlpha',           1, ...
        'EdgeColor',           'none', ...
        'BackfaceLighting',    'unlit', ...
        'AmbientStrength',     0.5, ...
        'DiffuseStrength',     0.6, ...
        'SpecularStrength',    0.4, ...
        'FaceLighting',        'gouraud', ...
        'EdgeLighting',        'gouraud', ...
        'Tag',                 'NirsCapPatch', ...
        'UserData',            UserData, ...
        'Parent',              hAxes);

    % Detailed display
    if isDetails
        % ===== DISPLAY CONNECTIONS =====
        % Find all pairs of connections
        [uniquePairs, iChanPairs] = unique([S',D'], 'rows');
        % Sort the pairs
        [iChanPairs,I] = sort(iChanPairs);
        uniquePairs = uniquePairs(I,:);
        % Pair locations: sources
        locPairSrc = cellfun(@(c)c(:,1)', {Channels(iChanPairs).Loc}, 'UniformOutput', 0);
        locPairSrc = cat(1, locPairSrc{:});
        % Pair locations: detectors
        locPairDet = cellfun(@(c)c(:,2)', {Channels(iChanPairs).Loc}, 'UniformOutput', 0);
        locPairDet = cat(1, locPairDet{:});

        % Make the position of the links more superficial, so they can be outside of the head and selected with the mouse
        normSrc = sqrt(sum(locPairSrc .^ 2, 2));
        normDet = sqrt(sum(locPairDet .^ 2, 2));
        locPairSrc = bst_bsxfun(@times, locPairSrc, (normSrc + 0.0035) ./ normSrc);
        locPairDet = bst_bsxfun(@times, locPairDet, (normDet + 0.0035) ./ normDet);
        
        % Display connections as lines
        hPairs = line(...
            [locPairSrc(:,1)'; locPairDet(:,1)'], ...
            [locPairSrc(:,2)'; locPairDet(:,2)'], ...
            [locPairSrc(:,3)'; locPairDet(:,3)'], ...
            'Color',      [.3 .3 1], ...
            'LineWidth',  3, ...
            'Marker',     'none', ...
            'Parent',     hAxes, ...
            'Tag',        'NirsCapLine');
        % Add channel index in the UserData field
        for i = 1:length(hPairs)
            %set(hPairs(i), 'UserData', iChannels(iChanPairs(i)));
            set(hPairs(i), 'UserData', uniquePairs(i,:));
        end

        % ===== DISPLAY TEXT =====
        % Text display properties
        textOpt = {...
            'Parent',              hAxes, ...
            'HorizontalAlignment', 'center', ...
            'FontSize',            bst_get('FigFont') + 2, ...
            'FontUnits',           'points', ...
            'FontWeight',          'normal', ...
            'Tag',                 'NirsCapText', ...
            'Interpreter',         'none'};
        % Display text for sources
        for i = 1:size(locSrc,1)
            txtLoc = locSrc(i,:) .* 1.08;
            text(txtLoc(1), txtLoc(2), txtLoc(3), Snames{i}, 'Color', [1,.8,0], textOpt{:});
        end
        % Display text for detectors
        for i = 1:size(locDet,1)
            txtLoc = locDet(i,:) .* 1.08;
            text(txtLoc(1), txtLoc(2), txtLoc(3), Dnames{i}, 'Color', [.8,1,0], textOpt{:});
        end
    else
        hPairs = [];
    end
end



%% ===== PLOT SENSORS: NET 3D =====
% Plot the sensors patch in a 3D figure.
% USAGE:  [hNet, hOrient] = PlotSensorsNet( hAxes, vertices, isFaces, isMesh, orient )
%         [hNet, hOrient] = PlotSensorsNet( hAxes, vertices, isFaces )
% INPUT:  
%    - hAxes     : handle to axes in which you need to display the sensors patch
%    - vertices  : [NbVert * NbIntergationPoints, 3] double, (x,y,z) location of each sensor
%    - isFaces   : {0,1} - If 0, the faces are not displayed (alpha = 0)
%    - isMesh    : {0,1} - If 0, Do not create the mesh
%    - orient    : [NbVert * NbIntergationPoints, 3] double, orientation of the coil
%                     => Orientation displayed only if Faces are displayed
% OUTPUT:
%    - hNet : handle to the sensors patch
function [hNet, hOrient] = PlotSensorsNet( hAxes, vertices, isFaces, isMesh, orient )
    % Parse inputs
    if (nargin < 3) || isempty(isFaces)
        isFaces = 1;
    end
    if (nargin < 4) || isempty(isMesh)
        isMesh = 1;
    end
    if (nargin < 5) || isempty(orient)
        orient = [];
    end
    % Nothing to display
    hNet = [];
    hOrient = [];
    if isempty(vertices)
        return
    end

    % ===== SENSORS PATCH =====
    % Try to plot markers with PATCH function
    if isMesh && (size(vertices,1) > 3)
        try
            % === TESSELATE SENSORS NET ===
            faces = channel_tesselate( vertices );

            % === DISPLAY PATCH ===
            % Display faces / edges / vertices
            if isFaces
                FaceColor = [.7 .7 .5];
                EdgeColor = [.4 .4 .3];
                LineWidth = 1;
            % Else, display only vertices markers
            else
                FaceColor = 'none';
                EdgeColor = 'none';
                LineWidth = 2;
            end
            % Create sensors patch
            hNet = patch(...
                'Vertices',         vertices, ...
                'Faces',            faces, ...
                'FaceVertexCData',  repmat([1 1 1], [length(vertices), 1]), ...
                'Parent',           hAxes, ...
                'Marker',           'o', ...
                'LineWidth',        LineWidth, ...
                'FaceColor',        FaceColor, ...
                'FaceAlpha',        1, ...
                'EdgeColor',        EdgeColor, ...
                'EdgeAlpha',        1, ...
                'MarkerEdgeColor',  [.4 .4 .3], ...
                'MarkerFaceColor',  'flat', ...
                'MarkerSize',       6, ...
                'BackfaceLighting', 'lit', ...
                'AmbientStrength',  0.5, ...
                'DiffuseStrength',  0.5, ...
                'SpecularStrength', 0.2, ...
                'SpecularExponent', 1, ...
                'SpecularColorReflectance', 0.5, ...
                'FaceLighting',     'gouraud', ...
                'EdgeLighting',     'gouraud', ...
                'Tag',              'SensorsPatch');           
        % If convhull or patch crashed : try next option
        catch
            disp('BST> Warning: patch() function returned an error. Trying to display sensors with line() function...');
            hNet = [];
        end 
    end
    % If nothing is displayed yet (crash, or specific request of not having a mesh): plot only the sensor markers
    if isempty(hNet)
        for i = 1:size(vertices,1)
            hNet(i) = line(vertices(i,1), vertices(i,2), vertices(i,3), ...
                        'Parent',          hAxes, ...
                        'LineWidth',       2, ...
                        'LineStyle',       'none', ...
                        'MarkerFaceColor', [1 1 1], ...
                        'MarkerEdgeColor', [.4 .4 .4], ...
                        'MarkerSize',      6, ...
                        'Marker',          'o', ...
                        'UserData',        i, ...
                        'Tag',             'SensorsMarkers');
        end
    end

%     % ===== ORIENTATIONS =====
%     if ~isempty(orient)
%         hOrient = zeros(1,length(orient));
%         for i = 1:length(orient)
%             curOrient = orient(i,:);
%             % Scale orientation vector for display
%             scaleFactor = 0.0173;
%             curOrient = curOrient ./ norm(curOrient) .* scaleFactor;
%             % Define line to be displayed from the center of the chip
%             lineOrient = [vertices(i,:); vertices(i,:) + curOrient];
%             % Plot line to represent the orientation
%             hOrient(i) = line(lineOrient(:,1), lineOrient(:,2), lineOrient(:,3), ...
%                              'Color',      [1 0 0], ...
%                              'LineWidth',  1, ...
%                              'Marker',     '>', ...
%                              'MarkerSize', 3, ...
%                              'Parent',     hAxes, ...
%                              'Tag',        'LineOrient');
%         end
%     else
%         hOrient = [];
%     end
end


%% ===== SAVE SURFACE =====
function SaveSurface(TessInfo)
    % Progress bar
    bst_progress('start', 'Save surface', 'Saving new surface...');
    % Get subject
    [sSubject, iSubject] = bst_get('SurfaceFile', TessInfo.SurfaceFile);
    % Load initial file
    FullFileName = file_fullpath(TessInfo.SurfaceFile);
    sSurfInit = load(FullFileName, 'Comment');
    % Create surface file
    sSurf.Vertices = get(TessInfo.hPatch, 'Vertices');
    sSurf.Faces    = get(TessInfo.hPatch, 'Faces');
    sSurf.Comment  = [sSurfInit.Comment, ' fig'];
    % Get hidden faces
    iFaceHide = find(get(TessInfo.hPatch, 'FaceVertexAlphaData') == 0);
    % If there are some, get the hidden vertices (vertices that are not in any visible face)
    if ~isempty(iFaceHide)
        % Get the hidden vertices
        FacesShow = sSurf.Faces;
        FacesShow(iFaceHide,:) = [];
        iVertHide = setdiff(1:length(sSurf.Vertices), unique(FacesShow(:)'));
        % If there are some hidden vertices: remove them from the surface
        if ~isempty(iVertHide)
            [sSurf.Vertices, sSurf.Faces] = tess_remove_vert(sSurf.Vertices, sSurf.Faces, iVertHide);
        end
    end
    % Create output filename
    OutputFile = strrep(FullFileName, '.mat', '_fig.mat');
    OutputFile = file_unique(OutputFile);
    % Save file
    bst_save(OutputFile, sSurf, 'v7');
    % Update database
    db_add_surface( iSubject, OutputFile, sSurf.Comment );
    bst_progress('stop');
end



%% ===== JUMP TO MAXIMUM =====
function JumpMaximum(hFig)
    % Get figure data
    [sMri, TessInfo, iAnatomy] = panel_surface('GetSurfaceMri', hFig);
    if isempty(TessInfo) || isempty(iAnatomy) || ~isfield(TessInfo(iAnatomy), 'OverlayCube') || isempty(TessInfo(iAnatomy).OverlayCube)
        return;
    end
    % Find maximum
    [valMax, iMax] = max(TessInfo(iAnatomy).OverlayCube(:));
    if isempty(iMax)
        return;
    end
    % Convert index to voxel indices
    [XYZ(1), XYZ(2), XYZ(3)] = ind2sub(size(TessInfo(iAnatomy).OverlayCube), iMax(1));
    % Set new position
    TessInfo(iAnatomy).CutsPosition = XYZ;
    UpdateMriDisplay(hFig, [1 2 3], TessInfo, iAnatomy);
end

%% ===== SELECT FIBER SCOUTS =====
function hFigFib = SelectFiberScouts(hFigConn, iScouts, Color, ColorOnly)
    global GlobalData;
    % Parse arguments
    if nargin < 4
        ColorOnly = 0;
    end
    %% Get fibers information
    hFigFib = bst_figures('GetFigureHandleField', hFigConn, 'hFigFib');
    % If the fiber figure is closed, propagate to connectivity figure
    if ~ishandle(hFigFib)
        setappdata(hFigConn, 'plotFibers', 0);
        return;
    end
    TfInfo = getappdata(hFigConn, 'Timefreq');
    TessInfo = getappdata(hFigFib, 'Surface');
    iTess = find(ismember({TessInfo.Name}, 'Fibers'));
    [FibMat, iFib] = bst_memory('LoadFibers', TessInfo(iTess).SurfaceFile);
    
    
    %% If fibers not yet assigned to atlas, do so now
    if isempty(FibMat.Scouts(1).ConnectFile) || ~ismember(TfInfo.FileName, {FibMat.Scouts.ConnectFile})
        ScoutNames     = bst_figures('GetFigureHandleField', hFigConn, 'RowNames');
        ScoutCentroids = bst_figures('GetFigureHandleField', hFigConn, 'RowLocs');
        FibMat = fibers_helper('AssignToScouts', FibMat, TfInfo.FileName, ScoutCentroids);
        % Save in memory to avoid recomputing
        GlobalData.Fibers(iFib) = FibMat;
    end
    
    bst_progress('start', 'Fibers Connectivity', 'Selecting appropriate fibers...');
    
    % Get scout assignment
    iFile = find(ismember(TfInfo.FileName, {FibMat.Scouts.ConnectFile}));
    assign = FibMat.Scouts(iFile).Assignment;
    
    %% Find pair of scouts in list fiber assignments
    % Reshape iScouts to use bsxfun
    iScoutsBsx = reshape(iScouts', [1 size(iScouts')]);
    % Get the matches for the pairs and for the flipped pairs
    indices =  all(bsxfun(@eq, assign, iScoutsBsx), 2) | all( bsxfun(@eq, assign, flip(iScoutsBsx,2)), 2);
    % Find the indices of the rows with a match
    iFibers = find(any(indices,3));
    [iFoundFibers,iFoundScouts] = find(indices(iFibers,:,:));
    [tmp, iFoundFibers] = sort(iFoundFibers);
    iFoundScouts = iFoundScouts(iFoundFibers);
    
    %% Plot selected fibers
    if ~ColorOnly
        % Remove old fibers
        delete(TessInfo(iTess).hPatch);
        % Plot fibers
        [hFigFib, TessInfo(iTess).hPatch] = PlotFibers(hFigFib, FibMat.Points(iFibers,:,:), Color(iFoundScouts,:));
    else
        TessInfo(iTess).hPatch = ColorFibers(TessInfo(iTess).hPatch, Color(iFoundScouts,:));
    end

    % Update figure's surfaces list and current surface pointer
    setappdata(hFigFib, 'Surface',  TessInfo);
    bst_progress('stop');
end
