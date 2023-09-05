function hFig = gui_edit_bfs( SurfaceFile, bfsList)
% GUI_EDIT_BFS: Align Best Fittin Sphere (BFS) on a surface.
% 
% USAGE:  gui_edit_bfs( SurfaceFile, bfsList )
%
% INPUT:
%     - SurfaceFile : full path to a scalp surface
%     - bfsList     : Array of structures that describes the possible estimations of the BFS
%          |- HeadCenter: [x,y,z] coordinates of the center, in millimeters
%          |- Radius    : Radius of the sphere
%          |- Name      : Name of the estimation. Possible values = {Scalp, Cortex, InnerSkull, EEG, MEG, Head points}
%
% NOTE: All the other parameters are passed through the global variable GlobalVariable.HeadModeler

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
% Authors: Francois Tadel, 2008-2010

global GlobalData;
GUI = GlobalData.HeadModeler.GUI;

%% ===== CREATE FIGURE =====
% Display reference surface in a new figure
hFig = view_surface(SurfaceFile, .3, [], 'NewFigure');
if isempty(hFig)
    return
end
% Configure new figure
set(hFig, 'Name',    'Edit best fitting sphere', ...
          'Visible', 'on', ...
          'Tag',     'SphereVisuFigure');
% View XYZ axis
figure_3d('ViewAxis', hFig, 1);


%% ===== HACK NORMAL 3D CALLBACKS =====
GUI.hFig = hFig;
% Save figure callback functions
GUI.Figure3DButtonDown_Bak   = get(hFig, 'WindowButtonDownFcn');
GUI.Figure3DButtonMotion_Bak = get(hFig, 'WindowButtonMotionFcn');
GUI.Figure3DButtonUp_Bak     = get(hFig, 'WindowButtonUpFcn');
GUI.Figure3DCloseRequest_Bak = get(hFig, 'CloseRequestFcn');
% Set new callbacks
set(hFig, 'WindowButtonDownFcn',   @AlignButtonDown_Callback);
set(hFig, 'WindowButtonMotionFcn', @AlignButtonMotion_Callback);
set(hFig, 'WindowButtonUpFcn',     @AlignButtonUp_Callback);
set(hFig, 'CloseRequestFcn',       @AlignClose_Callback);
% Initializations
GUI.selectedButton = '';
GUI.mouseClicked = 0;
GUI.isClosing = 0;


%% ===== TOOLBAR =====
% Add toolbar to window
hToolbar = uitoolbar(hFig, 'Tag', 'AlignToolbar');
% Use last sphere
GUI.hButtonUseLas = uipushtool(hToolbar, 'CData', java_geticon( 'ICON_DOWNSAMPLE'), 'TooltipString', 'Use the sphere from the last computation', 'ClickedCallback', @UseLastSphere_Callback, 'separator', 'on');
GUI.hButtonEstim = [];
% List all the estimations
for i = 1:length(bfsList)
    % Get icon name for the target estimator
    switch (bfsList(i).Name)
        case 'Scalp',         iconName = 'ICON_SURFACE_SCALP';
        case 'Cortex',        iconName = 'ICON_SURFACE_CORTEX';
        case 'InnerSkull',    iconName = 'ICON_SURFACE_INNERSKULL';
        case 'EEG',           iconName = 'ICON_CHANNEL';
        case 'MEG',           iconName = 'ICON_CHANNEL';
        case 'Head points',   iconName = 'ICON_ALIGN_CHANNELS';
        otherwise,            error('Invalid estimator name.');
    end
    % Create button
    GUI.hButtonEstim(i) = uitoggletool(hToolbar, 'CData', java_geticon(iconName), ...
                                                 'TooltipString', ['Sphere estimation based on: ' bfsList(i).Name], ...
                                                 'ClickedCallback', @(h,ev)SetEstimBfs(bfsList(i), i));
end
% Rotation/Translation buttons
GUI.hButtonTransX = uitoggletool(hToolbar, 'CData', java_geticon( 'ICON_TRANSLATION_X'), 'TooltipString', 'Translation/X: Press right button and move mouse up/down', 'ClickedCallback', @SelectOperation, 'separator', 'on');
GUI.hButtonTransY = uitoggletool(hToolbar, 'CData', java_geticon( 'ICON_TRANSLATION_Y'), 'TooltipString', 'Translation/Y: Press right button and move mouse up/down', 'ClickedCallback', @SelectOperation);
GUI.hButtonTransZ = uitoggletool(hToolbar, 'CData', java_geticon( 'ICON_TRANSLATION_Z'), 'TooltipString', 'Translation/Z: Press right button and move mouse up/down', 'ClickedCallback', @SelectOperation);
GUI.hButtonResize = uitoggletool(hToolbar, 'CData', java_geticon( 'ICON_RESIZE'),        'TooltipString', 'Resize: Press right button and move mouse up/down',        'ClickedCallback', @SelectOperation);
% Configuration buttons
GUI.hButtonEditBfs = uipushtool(hToolbar, 'CData', java_geticon( 'ICON_EDIT'), 'TooltipString', 'Edit sphere properties', 'ClickedCallback', @EditBfsProperties_Callback, 'separator', 'on');
% Configuration buttons
GUI.hButtonEditBfs = uipushtool(hToolbar, 'CData', java_geticon( 'ICON_OK'), 'TooltipString', 'Validate sphere and start head model computation', 'ClickedCallback', @ButtonOk_Callback, 'separator', 'on');

% Is there a previous sphere ?
if isfield(GlobalData.HeadModeler.BFS, 'oldHeadCenter') && ~isempty(GlobalData.HeadModeler.BFS.oldHeadCenter)
    set(GUI.hButtonUseLas, 'Enable', 'on');
else
    set(GUI.hButtonUseLas, 'Enable', 'off');
end


%% ===== CUSTOMIZE FIGURE =====
% Create legend: center and radius of the sphere
GUI.hLegend = uicontrol('Style',               'text', ...
                        'String',              '', ...
                        'Units',               'Pixels', ...
                        'Position',            [0 0 165 36], ...
                        'HorizontalAlignment', 'left', ...
                        'FontUnits',           'points', ...
                        'FontSize',            bst_get('FigFont'), ...
                        'ForegroundColor',     [.3 1 .3], ...
                        'BackgroundColor',     [0 0 0], ...
                        'Parent',              hFig);
% Update figure localization
gui_layout('Update');
% Update GUI structure
GlobalData.HeadModeler.GUI = GUI;             
               

%% ===== DISPLAY SPHERES =====
% Use the first estimator in list as the current BFS
SetEstimBfs(bfsList(1), 1);
% Draw spheres
PlotSpheres();
drawnow

end



%% ===== MOUSE CALLBACKS =====  
% ===== MOUSE DOWN =====
function AlignButtonDown_Callback(hObject, ev)
    global GlobalData;
    GUI = GlobalData.HeadModeler.GUI;
    % Catch only the clicks with the right button
    if strcmpi(get(GUI.hFig, 'SelectionType'), 'alt') && ~isempty(GUI.selectedButton)
        GUI.mouseClicked = 1;
        % Record click position
        setappdata(GUI.hFig, 'clickPositionFigure', get(GUI.hFig, 'CurrentPoint'));
    elseif ~isempty(GUI.Figure3DButtonDown_Bak)
        % Call the default mouse down handle
        GUI.Figure3DButtonDown_Bak(hObject, ev);
    end
    % Update GUI structure
    GlobalData.HeadModeler.GUI = GUI;
end

% ===== MOUSE MOVE =====
function AlignButtonMotion_Callback(hObject, ev)
    global GlobalData;
    GUI = GlobalData.HeadModeler.GUI;
    BFS = GlobalData.HeadModeler.BFS;
    % If an action is being processed
    if GUI.mouseClicked
        % Get current mouse location
        curptFigure = get(GUI.hFig, 'CurrentPoint');
        motionFigure = (curptFigure - getappdata(GUI.hFig, 'clickPositionFigure')) / 1000;
        % Update click point location
        setappdata(GUI.hFig, 'clickPositionFigure', curptFigure);
        % Selected button
        switch (GUI.selectedButton)
            case GUI.hButtonTransX
                BFS.HeadCenter(1) = BFS.HeadCenter(1) + motionFigure(2) / 5;
            case GUI.hButtonTransY
                BFS.HeadCenter(2) = BFS.HeadCenter(2) + motionFigure(2) / 5;
            case GUI.hButtonTransZ
                BFS.HeadCenter(3) = BFS.HeadCenter(3) + motionFigure(2) / 5;
            case GUI.hButtonResize
                BFS.Radius     = BFS.Radius * (1 + motionFigure(2));
            otherwise 
                return;
        end
        % Update GUI structure
        GlobalData.HeadModeler.BFS = BFS;
        % Update spheres display
        PlotSpheres();
        % Unselect all the estimators buttons
        SelectEstimatorButton([]);
    elseif ~isempty(GUI.Figure3DButtonMotion_Bak)
        % Call the default mouse motion handle
        GUI.Figure3DButtonMotion_Bak(hObject, ev);
    end
end

% ===== MOUSE UP =====
function AlignButtonUp_Callback(hObject, ev)
    global GlobalData;
    GUI = GlobalData.HeadModeler.GUI;
    % Catch only the events if the motion is currently processed
    if GUI.mouseClicked
        GUI.mouseClicked = 0;
    elseif ~isempty(GUI.Figure3DButtonUp_Bak)
        % Call the default mouse up handle
        GUI.Figure3DButtonUp_Bak(hObject, ev);
    end
    % Update GUI structure
    GlobalData.HeadModeler.GUI = GUI;
end

%% ===== FIGURE CLOSE REQUESTED =====
function AlignClose_Callback(varargin)
    global GlobalData;
    GUI = GlobalData.HeadModeler.GUI;
    if GUI.isClosing
        return
    else
        % Ask user what to do
        isExit = java_dialog('confirm', ['Warning: you did not validate the sphere.' 10 10 ...
                                         'Stop headmodel computation ?' 10 10], 'Warning');
        % Select the default option "Use one channel file per subject"
        if ~isExit
            return;
        end
        GlobalData.HeadModeler.BFS.HeadCenter = [];
        GlobalData.HeadModeler.BFS.Radius = [];
        GlobalData.HeadModeler.GUI.isClosing = 1;
    end
    % Only close figure
    if ~isempty(GUI.Figure3DCloseRequest_Bak)
        GUI.Figure3DCloseRequest_Bak(varargin{:});    
    end
end

%% ===== OK BUTTON =====
function ButtonOk_Callback(hObject, varargin)
    global GlobalData;
    % Save current BFS for next calls
    GlobalData.HeadModeler.BFS.oldHeadCenter = GlobalData.HeadModeler.BFS.HeadCenter;
    GlobalData.HeadModeler.BFS.oldRadius     = GlobalData.HeadModeler.BFS.Radius;
    % Close figure
    if ~isempty(GlobalData.HeadModeler.GUI.Figure3DCloseRequest_Bak)
        GlobalData.HeadModeler.GUI.Figure3DCloseRequest_Bak(GlobalData.HeadModeler.GUI.hFig, varargin{:});    
    end
end


%% ===== SELECT MOUSE OPERATION =====
function SelectOperation(hObject, ev)
    global GlobalData;
    GUI = GlobalData.HeadModeler.GUI;
    % Update button color
    gui_update_toggle(hObject);
    % If button was unselected: nothing to do
    if strcmpi(get(hObject, 'State'), 'off')
        GlobalData.HeadModeler.GUI.selectedButton = [];
        return
    else
        GUI.selectedButton = hObject;
    end
    % Unselect all buttons excepted the selected one
    hButtonsUnsel = setdiff([GUI.hButtonTransX, GUI.hButtonTransY, GUI.hButtonTransZ, GUI.hButtonResize], hObject);
    hButtonsUnsel = hButtonsUnsel(strcmpi(get(hButtonsUnsel, 'State'), 'on'));
    if ~isempty(hButtonsUnsel)
        set(hButtonsUnsel, 'State', 'off');
        gui_update_toggle(hButtonsUnsel(1));
    end
    % Update GUI structure
    GlobalData.HeadModeler.GUI = GUI;
end


%% ===== UPDATE VALUES =====
function UpdateValues()
    global GlobalData;
    % Update controls
    set(GlobalData.HeadModeler.GUI.hLegend, ...
        'String', sprintf('     Center: [%4.2f, %4.2f, %4.2f]\n     Radius: %4.2f', ...
        1000 * GlobalData.HeadModeler.BFS.HeadCenter, ...
        1000 * GlobalData.HeadModeler.BFS.Radius));
end

%% ===== PLOT SPHERES =====
function PlotSpheres()
    global GlobalData;
    % Get BFS values
    HeadCenter     = GlobalData.HeadModeler.BFS.HeadCenter;
    Radius         = GlobalData.HeadModeler.BFS.Radius;
    BFSProperties  = bst_get('BFSProperties');
    Radii          = Radius .* [BFSProperties(4:5) 1];   
    
    % Get axes handles
    hAxes = findobj(GlobalData.HeadModeler.GUI.hFig, '-depth', 1, 'Tag', 'Axes3D');
    % Delete previous spheres
    delete(findobj(hAxes, '-depth', 1, 'Tag', 'Sphere'));
    % Create new spheres
    [X,Y,Z] = sphere(20);
    [TH,PHI,R] = cart2sph(X,Y,Z);
    [X,Y,Z] = sph2cart(TH, PHI, R * Radii(end));
    hSphere = patch(surf2patch(X + HeadCenter(1),...
                               Y + HeadCenter(2),...
                               Z + HeadCenter(3),...
                               Z + HeadCenter(3))); 
    set(hSphere, 'Parent',    hAxes, ...
                 'Facecolor', 'none', ...
                 'EdgeColor', [.8 .8 .8], ...
                 'LineWidth', 1, ...
                 'Tag',       'Sphere');
    % Update information
    UpdateValues();
end

%% ===== EDIT BFS PROPERTIES =====
function EditBfsProperties_Callback(varargin)
    global GlobalData;
    % Edit only the center and radius of sphere
    if (GlobalData.HeadModeler.nbSpheres == 1)
        % Get current sphere and current properties
        bfsProp = [1000 * GlobalData.HeadModeler.BFS.HeadCenter', ...
                   1000 * GlobalData.HeadModeler.BFS.Radius];
        % Ask user to modify these values
        res = java_dialog('input', {'Center [X,Y,Z]', 'Radius'}, 'Best fitting sphere', [], ...
                          {sprintf('[%3.2f, %3.2f, %3.2f]', bfsProp(1:3)), num2str(bfsProp(4),'%3.2f')});
        % If user cancelled: return
        if isempty(res)
            return
        end
        % Get new values
        newProp = [str2num(res{1}), str2num(res{2})];
        % Check if all values are valid
        if (length(newProp) ~= 4) || (newProp(4) <= 0)
            bst_error('Invalid property values.', 'Edit sphere', 0);
        % If user changed the values, update them
        elseif any(abs(newProp - bfsProp) > 1e-2)
            % Save new sphere center/radius
            GlobalData.HeadModeler.BFS.HeadCenter = newProp(1:3)' / 1000;
            GlobalData.HeadModeler.BFS.Radius     = newProp(4) / 1000;
            % Redraw spheres
            PlotSpheres();
            % Unselect all the estimators buttons
            SelectEstimatorButton([]);
        end
        
    % Edit BFS + multiple sphere properties (EEG ONLY)
    else
        % Get current sphere and current properties
        bfsProp = [1000 * GlobalData.HeadModeler.BFS.HeadCenter', ...
                   1000 * GlobalData.HeadModeler.BFS.Radius, ...
                   bst_get('BFSProperties')];   
        % Ask user to modify these values
        res = java_dialog('input', ...
                          {'Center [X,Y,Z]', ...
                           'Radius', ...
                           '<HTML>Conductivities for: [Brain, Skull, Scalp]<BR>(default: [0.33, 0.0042, 0.33])</HTML>', ...
                           '<HTML>Inner spheres radii: [Brain, Skull]<BR>Values are relative to the scalp sphere radius.<BR>(default: [0.88, 0.93])</HTML>'}, ...
                          'Best fitting sphere', [], ...
                          {sprintf('[%3.2f, %3.2f, %3.2f]', bfsProp(1:3)), ...
                           num2str(bfsProp(4),'%3.2f'), ...
                           sprintf('[%3.2f, %3.4f, %3.2f]', bfsProp(5:7)), ...
                           sprintf('[%3.2f, %3.2f]', bfsProp(8:9))});
        % If user cancelled: return
        if isempty(res)
            return
        end
        % Get new values
        newProp = [str2num(res{1}), str2num(res{2}), str2num(res{3}), str2num(res{4})];
        % Check if all values are valid
        if (length(newProp) ~= 9) || any(newProp(4:9) <= 0) || any(newProp(5:9) >= 1)
            bst_error('Invalid property values.', 'Edit sphere', 0);
        % If user changed the values, update them
        elseif any(abs(newProp - bfsProp) > 1e-4)
            % Save new sphere center/radius
            GlobalData.HeadModeler.BFS.HeadCenter = newProp(1:3)' / 1000;
            GlobalData.HeadModeler.BFS.Radius     = newProp(4) / 1000;
            % Update new spheres properties
            bst_set('BFSProperties', newProp(5:9));
            % Redraw spheres
            PlotSpheres();
            % If sphere changed
            if any(abs(newProp(1:4) - bfsProp(1:4)) > 1e-2)
                % Unselect all the estimators buttons
                SelectEstimatorButton([]);
            end
        end
    end
end


%% ===== USE LAST SPHERE =====
function UseLastSphere_Callback(varargin)
    global GlobalData;
    % Re-use previous values, if available
    if isfield(GlobalData.HeadModeler.BFS, 'oldHeadCenter') && ~isempty(GlobalData.HeadModeler.BFS.oldHeadCenter)
        GlobalData.HeadModeler.BFS.HeadCenter = GlobalData.HeadModeler.BFS.oldHeadCenter;
        GlobalData.HeadModeler.BFS.Radius     = GlobalData.HeadModeler.BFS.oldRadius;
        % Redraw spheres
        PlotSpheres();
        % Unselect all the estimators buttons
        SelectEstimatorButton([]);
    end
end

%% ===== SET BFS ESTIMATION =====
function SetEstimBfs(bfsEstim, iEstim)
    global GlobalData;
    % Select estimator button
    SelectEstimatorButton(iEstim);
    % Update current sphere with predefined values
    GlobalData.HeadModeler.BFS.HeadCenter = bfsEstim.HeadCenter;
    GlobalData.HeadModeler.BFS.Radius     = bfsEstim.Radius;
    % Redraw spheres
    PlotSpheres();
end

%% ====== UNSELECT ESTIMATORS BUTTON =====
function SelectEstimatorButton(iEstim)
    global GlobalData;
    GUI = GlobalData.HeadModeler.GUI;
    nButtons = length(GUI.hButtonEstim);
    % Get current state for all buttons
    currState = get(GUI.hButtonEstim, 'State');
    % Get selected and unselected buttons
    iOn = iEstim;
    iOff = setdiff(1:nButtons, iEstim);
    destState = repmat({'on'}, nButtons, 1);
    destState(iOff) = {'off'};
    % Get buttons to update
    iUpdate = [find(~strcmpi(destState, currState)), iEstim];
    % If nothing changed: exit
    if isempty(iUpdate)
        return
    end
    % Select estimator button
    set(GUI.hButtonEstim(iOn),  'State', 'on');
    set(GUI.hButtonEstim(iOff), 'State', 'off');
    % Update buttons background color
    gui_update_toggle(GUI.hButtonEstim(iUpdate));
    drawnow();
end

