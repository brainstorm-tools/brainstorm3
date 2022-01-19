function varargout = mri_editMask(varargin)
% MRI_EDITMASK: Edit a 3D binary mask for a MRI.
%
% USAGE:  finalMask = mri_editMask(Mri)
%         finalMask = mri_editMask(Mri, Voxsize)
%         finalMask = mri_editMask(Mri, Voxsize, InitialMask)
%         finalMask = mri_editMask(Mri, Voxsize, InitialMask, InitialPos)
%         finalMask = mri_editMask(Mri, Voxsize, InitialMask, InitialPos, ColormapName)
%
% INPUT:
%    - Mri         : Full 3D matrix
%    - Voxsize     : Voxel size of the Mri volume (x,y,z)
%    - InitialMask : Full 3D matrix representing the initial mask
%                    (optional, if not specified, use an empty volume)
%    - InitialPos  : (dim, sliceIndex), slice to display when opening the window
%    - ColormapName: colormap name to display the anatomy
%
% OUTPUT:
%    - finalMask = final binary 3D mask
%
% A global variable is used to store application MRI and Masks : gEditMaskData
% Structure with following fields :
%    |- mri           : MRI that is currently processed
%    |- voxsize       : size of each mri voxel (x,y,z)
%    |- mask          : currently edited mask (for brain or grey matter)
%    |- isClicked     : structure that handles the mouse clicks and movements
%    |     |- source              : name of the object clicked by the user
%    |     |- clickPositionAxes   : click position in figure coordinates
%    |     |- clickPositionFigure : click position in axis coordinates
%    |- sliderValue   : [1,3] with the index of the current slice in each
%    |                  orientation for preview image (x,y,z)
%    |- orientation   : current orientation of preview slice (x,y,z)
%    |- intensityMax  : maximum intensity in image
%    |- colormap
%    |- colormapMax   : value above which all intensity are displayed as white

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
% Authors: Francois Tadel, 2006-2010


%% ===== CHECK INPUT =====
global gEditMaskData;
% === EXTERNAL CALL ===
if (nargin >= 1) && isnumeric(varargin{1})
    % === PARSE INPUTS ===
    % Argument #1: MRI
    gEditMaskData.mri = varargin{1};
    % Argument #2: VOXEL SIZE
    if (nargin < 2) || isempty(varargin{2})
        gEditMaskData.voxsize = [1 1 1];
    else
        gEditMaskData.voxsize = varargin{2};
    end
    % Argument #3: MASK
    if (nargin < 3) || isempty(varargin{3})
        gEditMaskData.mask = false(size(gEditMaskData.mri));
    elseif any(size(varargin{3}) ~= size(gEditMaskData.mri))
        error('MRI and mask must have the same dimensions.');
    else
        gEditMaskData.mask = logical(varargin{3});
    end
    % Argument #4: INITIAL POSITION
    if (nargin < 4) || isempty(varargin{4})
        InitialPos = [];
    else
        InitialPos = varargin{4};
    end
    % Argument #5: COLORMAP
    if (nargin < 5) || isempty(varargin{5})
        gEditMaskData.colormap = 'gray';
    else
        gEditMaskData.colormap = varargin{5};
    end
    
    % === START MASK EDITOR ===
    % Progress bar
    bst_progress('start', 'Edit mask', 'Initialization...');
    % Call again function, to initialize GUI
    hFig = mri_editMask();
    % Define Mouse wheel callback separately (not supported by old versions of Matlab)
    if isprop(hFig, 'WindowScrollWheelFcn')
        set(hFig, 'WindowScrollWheelFcn',  @FigureMouseWheelCallback);
    end
    % Set initial orientation and position
    if ~isempty(InitialPos)
        SetOrientation(InitialPos(1));
        SetSliceLocation(InitialPos(2));
    end
    % Close progress bar
    bst_progress('stop');
    
    % === WAIT AND RETURN ===
    % Wait for end of edition
    waitfor(hFig);
    % Return edited mask
    if (nargout >= 1)
        varargout{1} = gEditMaskData.mask;
    end
    % Empty global variable
    gEditMaskData = [];
    
% === INTERNAL CALL : CREATE GUI ===
elseif (nargin == 0)
    % Begin initialization code - DO NOT EDIT
    gui_Singleton = 1;
    gui_State = struct('gui_Name',       mfilename, ...
                       'gui_Singleton',  gui_Singleton, ...
                       'gui_OpeningFcn', @figureEditMask_OpeningFcn, ...
                       'gui_OutputFcn',  @figureEditMask_OutputFcn, ...
                       'gui_LayoutFcn',  [] , ...
                       'gui_Callback',   []);
    if nargout
        [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
    else
        gui_mainfcn(gui_State, varargin{:});
    end
    % Update figures layout
    gui_layout('Update');
    
% === CALLBACKS ===
else
    if (nargout)
        [varargout{1:nargout}] = bst_call(str2func(varargin{1}), varargin{2:end});
    else
        bst_call(str2func(varargin{1}), varargin{2:end});
    end
end


%% ===== OUTPUT FUNCTION =====
function varargout = figureEditMask_OutputFcn(hObject, eventdata, handles) 
    % Get default command line output from handles structure
    varargout{1} = hObject;


%% ===== OPENING FUNCTION =====
function figureEditMask_OpeningFcn(hObject, eventdata, handles, varargin)
    global gEditMaskData;
    % Check that MRI and MASK where defined
    if ~isfield(gEditMaskData, 'mri') || isempty(gEditMaskData.mri) || ~isfield(gEditMaskData, 'mask') || isempty(gEditMaskData.mask)
        error('Usage: mri_editMask(volume,mask);');
    end
    drawnow
    
    % === Replace Matlab slider by Java slider ===
    % Disable the Java-related warnings after 2019b
    if (bst_get('MatlabVersion') >= 907)
        warning('off', 'MATLAB:ui:javacomponent:FunctionToBeRemoved');
    end
%     sliderPos = get(handles.sliderPreview, 'Position');
%     hParent = get(handles.sliderPreview, 'Parent');
    delete(handles.sliderPreview);
    [handles.jSliderPreview, handles.sliderPreview] = javacomponent(javax.swing.JSlider(0,10,0), [0 0 1 1], hObject);
%     set(handles.sliderPreview, 'Units', 'Pixels', 'Position', sliderPos);
    java_setcb(handles.jSliderPreview, 'MouseReleasedCallback', @(h,ev)SetSliceLocation(ev.getSource().getValue()), ...
                                       'KeyPressedCallback',    @(h,ev)SetSliceLocation(ev.getSource().getValue()));

    % === REFRESH DISPLAY ===
    set(handles.mri_editMask, 'WindowStyle', 'normal');
    
    % ===== ICONS =====
    set(handles.toggleLassoMinus,   'CData', java_geticon('ICON_LASSO_MINUS'));
    set(handles.toggleLassoPlus,    'CData', java_geticon('ICON_LASSO_PLUS'));
    set(handles.toggleCurveMinus,   'CData', java_geticon('ICON_CURVE_MINUS'));
    set(handles.toggleCurvePlus,    'CData', java_geticon('ICON_CURVE_PLUS'));
    set(handles.buttonContrastDown, 'CData', java_geticon('ICON_BRIGHTNESS_MINUS'));
    set(handles.buttonContrastUp,   'CData', java_geticon('ICON_BRIGHTNESS_PLUS'));

    % Store handles in global variable
    handles.output = hObject;
    gEditMaskData.Handles = handles;
    % Keyboard shortcuts
    set([handles.mri_editMask, handles.buttonContrastDown, handles.buttonContrastUp, ...
         handles.buttonOk, handles.buttonCancel, ...
         handles.buttonAxial, handles.buttonCoronal, handles.buttonSagittal, ...
         handles.toggleLassoMinus, handles.toggleLassoPlus, handles.toggleCurveMinus, handles.toggleCurvePlus], ...
        'KeyPressFcn', @figureKeyPress_Callback);
    % Initial preview axes settings
    mriSize = size(gEditMaskData.mri);
    gEditMaskData.sliderValue = [round(mriSize(1)/2), round(mriSize(2)/2), round(mriSize(3)/2)];
    gEditMaskData.orientation = 3; % 1=x, 2=y, 3=z
    gEditMaskData.overlayColor = [1 1 0];
    gEditMaskData.overlayAlpha = .6;
    % Initial action: lasso
    SetAction('lasso+');
    % Mouse clicks and motion management 
    gEditMaskData.isClicked.source = '';
    gEditMaskData.isClicked.clickPositionAxes = [];
    gEditMaskData.isClicked.clickPositionFigure = [];
    gEditMaskData.isClicked.roiPolygon = [];
%     % Initial action
%     set(handles.buttongroupAction, 'SelectedObject', handles.toggleLassoPlus);
%     % Update icons
%     gui_update_toggle([handles.toggleLassoPlus, handles.toggleLassoMinus, handles.toggleCurvePlus, handles.toggleCurveMinus]);
    % Initial contrast
    gEditMaskData.colormapMax = 256;
    gEditMaskData.intensityMax = max(gEditMaskData.mri(:));
    % Initialize axes
    SetOrientation(gEditMaskData.orientation);
    % Draw first slice
    UpdateSlice();   

    
%% ===== RESIZE CALLBACK =====
function mri_editMask_ResizeFcn(varargin) %#ok<DEFNU>
    global gEditMaskData;
    if ~isfield(gEditMaskData, 'Handles') || ~ishandle(gEditMaskData.Handles.mri_editMask)
        return
    end
    handles = gEditMaskData.Handles;
    % Get figure and panels position and size
    figPos    = get(handles.mri_editMask,  'Position');
    rightPos  = get(handles.panelRight,    'Position');
    % Set right panel position
    set(handles.panelRight, 'Position', [0, ...
                                         figPos(4) - rightPos(4), ...
                                         rightPos(3), ...
                                         rightPos(4)]);
    % Set "MRI" panel position
    margin = 5;
    set(handles.panelMri, 'Position', [rightPos(3), ...
                                       margin, ...
                                       figPos(3) - rightPos(3) - margin, ...
                                       figPos(4) - 2 * margin]);
    % Set slider position
    set(handles.sliderPreview, 'Position', [11, figPos(4)-290, 140, 24]);

    
%% =================================================================================================
%  ===== DISPLAY MRI ===============================================================================
%  =================================================================================================
%% ===== SET ORIENTATION =====
function SetOrientation(orientation)
    global gEditMaskData;
    handles = gEditMaskData.Handles;
    % Save new orientation
    gEditMaskData.orientation = orientation;
    % Select right orientation button
    hButtons = [handles.buttonSagittal, handles.buttonCoronal, handles.buttonAxial];
    set(hButtons(orientation), 'Value', 1);
    
    % === PREPARE DISPLAY ===
    cubeSize = size(gEditMaskData.mri);
    FOV = cubeSize .* gEditMaskData.voxsize;
    % Empty axes
    cla(handles.axesPreview);
    % Set colormap
    colormap(handles.axesPreview, gEditMaskData.colormap);

    % === CREATE IMAGES ===
    % Get image size
    imgSize = cubeSize;
    imgSize(orientation) = [];
    FOV(orientation) = [];
    % MRI image
    handles.img_mri = image('XData',        [1, FOV(1)], ...
                            'YData',        [1, FOV(2)], ...
                            'CData',        zeros(imgSize(2), imgSize(1)), ...
                            'CDataMapping', 'direct', ...
                            'Parent',       gEditMaskData.Handles.axesPreview);
    % Overlay image
    handles.img_overlay = image('XData',     [1, FOV(1)], ...
                                'YData',     [1, FOV(2)], ...
                                'CData',     zeros([imgSize(2), imgSize(2), 3]), ...
                                'AlphaData', 0, ... 
                                'Parent',    gEditMaskData.Handles.axesPreview);
    % Axes
    axis(handles.axesPreview, 'image', 'off');
    % Set mouse callbacks
    set([handles.axesPreview, handles.img_mri, handles.img_overlay], 'ButtonDownFcn', @previewMouseClick_Callback);
    % Save handles structure
    gEditMaskData.Handles = handles;
    
    % === ORIENTATION MARKERS ===
    if (orientation == 2)
        strOrient = 'PA';
    else
        strOrient = 'LR';
    end
    % Coronal
    V = axis(handles.axesPreview);
    fontSize = bst_get('FigFont');
    text(       6, 15, strOrient(1), 'verticalalignment', 'top', 'FontSize', fontSize, 'FontUnits', 'points', 'color','w', 'Parent', gEditMaskData.Handles.axesPreview);
    text(.95*V(2), 15, strOrient(2), 'verticalalignment', 'top', 'FontSize', fontSize, 'FontUnits', 'points', 'color','w', 'Parent', gEditMaskData.Handles.axesPreview);

    % === SLIDER ===
    % Slider bounds
    handles.jSliderPreview.setMinimum(1);
    handles.jSliderPreview.setMaximum(cubeSize(orientation));
    % Set slice location
    SetSliceLocation(gEditMaskData.sliderValue(orientation));
    
    % === COLORMAP ===
    UpdateColormap();
    
    
%% ===== SET SLICE LOCATION =====
function SetSliceLocation(sliceLoc)
    global gEditMaskData;
    handles = gEditMaskData.Handles;
    % Force location inside the MRI volume
    sliceLoc = bst_saturate(sliceLoc, [1, size(gEditMaskData.mri, gEditMaskData.orientation)]);
    % Save new position
    gEditMaskData.sliderValue(gEditMaskData.orientation) = sliceLoc;
    % Update slider position
    handles.jSliderPreview.setValue(sliceLoc);
    % Reset points selection 
    gEditMaskData.isClicked.roiPolygon = [];
    delete(findobj(handles.axesPreview, 'Tag', 'ptCurve'));
    % Update text
    set(handles.textValue, 'String', sprintf('%d', sliceLoc));
    strOrient = {'x=','y=','z='};
    set(handles.textTitleValue, 'String', strOrient{gEditMaskData.orientation});
    % Update location axes
    UpdateLocationAxes();
    % Redraw slice
    UpdateSlice();

%% ===== UPDATE SLICE =====
function UpdateSlice()
    global gEditMaskData;
    % Get slice location
    sliceLoc = gEditMaskData.sliderValue(gEditMaskData.orientation);
    % Update MRI slice
    sliceMRI = mri_getslice(gEditMaskData.mri, sliceLoc, gEditMaskData.orientation)';
    set(gEditMaskData.Handles.img_mri, 'CData', double(sliceMRI) ./ double(gEditMaskData.intensityMax) .* 256);
    % Update overlay slice
    if ~isempty(gEditMaskData.mask)
        sliceOverlay = mri_getslice(gEditMaskData.mask, sliceLoc, gEditMaskData.orientation)';
        sliceAlpha   = .6 * double(sliceOverlay);
        sliceOverlay = cat(3, sliceOverlay * gEditMaskData.overlayColor(1), ...
                              sliceOverlay * gEditMaskData.overlayColor(2), ...
                              sliceOverlay * gEditMaskData.overlayColor(3));
        set(gEditMaskData.Handles.img_overlay, 'CData', double(sliceOverlay), ...
                                               'AlphaData', sliceAlpha);
    end
    % Update location line
    DrawLocationLine();
    drawnow();


    
    
%% =================================================================================================
%  ===== LOCATION FUNCTIONS ========================================================================
%  =================================================================================================
%% ===== UPDATE LOCATION AXES =====
function UpdateLocationAxes()
    global gEditMaskData;
    % Get a centered slice, orthogonal to the direction of the preview slice
    switch (gEditMaskData.orientation)
        case 1 % Coronal preview => extract a sagittal slice
            locOrient = 3;
            lineOrient = 1;
        case 2 % Axial preview => extract a sagittal slice
            locOrient = 3;
            lineOrient = 2;
        case 3 % Sagittal preview => extract an axial slice
            locOrient = 2;
            lineOrient = 2;
    end
    % Get slice at the middle of the volume
    cubeSize = size(gEditMaskData.mri);
    locPosition = round(cubeSize(locOrient)/2);
    locSlice = mri_getslice(gEditMaskData.mri, locPosition, locOrient);
    % Get pixel size
    FOV = cubeSize .* gEditMaskData.voxsize;
    FOV(locOrient) = [];
    
    % Empty axes
    cla(gEditMaskData.Handles.axesLocation);
    % Display slice on location axes
    gEditMaskData.img_location = image('XData',         [1, FOV(1)], ...
                                       'YData',         [1, FOV(2)], ...
                                       'CData',         double(locSlice)' ./ double(gEditMaskData.intensityMax) .* 256, ...
                                       'CDataMapping',  'scaled', ...
                                       'Parent',        gEditMaskData.Handles.axesLocation, ...
                                       'ButtonDownFcn', @locationMouseClick_Callback);                                                                         
    % Configure axes
    axis(gEditMaskData.Handles.axesLocation, 'image', 'off');
    set(gEditMaskData.Handles.axesLocation, 'UserData', lineOrient);
    
    
%% ===== DRAW LOCATION LINE =====
function DrawLocationLine()
    global gEditMaskData;
    % Get line orientation (UserData of the location Axes)
    lineOrient = get(gEditMaskData.Handles.axesLocation, 'UserData');
    % Get values from interface controls
    n = gEditMaskData.sliderValue(gEditMaskData.orientation) * gEditMaskData.voxsize(gEditMaskData.orientation);
    XLim = get(gEditMaskData.Handles.axesLocation, 'XLim');
    YLim = get(gEditMaskData.Handles.axesLocation, 'YLim');
    % Display a line that represent the location of the slice
    delete(findobj(gEditMaskData.Handles.axesLocation, 'Tag', 'locationLine'));
    switch(lineOrient)
        case 1 % Vertical line
            line([n,n]+.5, YLim+.5, [1,1], 'Color', [1 .2 .2], ...
                 'Parent', gEditMaskData.Handles.axesLocation, 'Tag', 'locationLine');
        case 2 % Horizontal line
            line(XLim+.5, [n,n], [1,1], 'Color', [1 .2 .2], ...
                 'Parent', gEditMaskData.Handles.axesLocation, 'Tag', 'locationLine');
    end
    drawnow;

%% ===== LOCATION AXES CALLBACK =====
function locationMouseClick_Callback(varargin)
    global gEditMaskData;
    % Get application handles
    handles = gEditMaskData.Handles;
    % Get line orientation (UserData of the location Axes)
    lineOrient = get(handles.axesLocation, 'UserData');
    % Mouse location on the axis
    temp = get(handles.axesLocation, 'CurrentPoint');
    curptAxes = temp(1,1:2);
    % Update slice location
    switch(lineOrient)
        case 1 % Vertical line
            n = round(curptAxes(1) * gEditMaskData.voxsize(1) - .5);
        case 2 % Horizontal line
            n = round(curptAxes(2) * gEditMaskData.voxsize(2) - .5);
    end
    SetSliceLocation(n);
    
    
    
%% =================================================================================================
%  ===== AXES CALLBACKS ============================================================================
%  =================================================================================================
%% ===== KEYBOARD CALLBACK =====
function figureKeyPress_Callback(hObject, eventdata, varargin)
    global gEditMaskData;
    % Get GUI handles
    handles = gEditMaskData.Handles;
    % If the focus is on the slider, set the focus on the axes, to avoid conflits between uicontrol
    % automatic keyboard handling and, and this manual handling
    if (get(handles.mri_editMask, 'CurrentObject') == handles.sliderPreview)
        uicontrol(handles.buttonAxial);
    end
    % Get current slice location
    sliceLoc = handles.jSliderPreview.getValue();
    % Switch between keys
    switch (eventdata.Key)
        % PAGE UP : increase slice indice (10)
        case 'pageup'
            SetSliceLocation(sliceLoc + 10);
        % PAGE DOWN : decrease slice indice (10)
        case 'pagedown'
            SetSliceLocation(sliceLoc - 10);
        % RIGHT ARROW : increase slice indice (1)
        case 'rightarrow'
            SetSliceLocation(sliceLoc + 1);
        % LEFT ARROW : decrease slice indice
        case 'leftarrow'
            SetSliceLocation(sliceLoc - 1);
    end

    
%% ===== MOUSE CLICK =====
function previewMouseClick_Callback(varargin)
    global gEditMaskData;
    % Get figure handles
    hFig  = gEditMaskData.Handles.mri_editMask;
    hAxes = gEditMaskData.Handles.axesPreview;
    % Mouse location on the figure
    gEditMaskData.isClicked.source = 'preview';
    temp = get(hFig, 'CurrentPoint');
    gEditMaskData.isClicked.clickPositionFigure = temp(1,1:2);
    % Mouse location on the axis
    temp = get(hAxes, 'CurrentPoint');
    curptAxes= temp(1,1:2);
    % Apply changes
    switch(gEditMaskData.action)
        case {'lasso+', 'lasso-'}
            % Reset selection
            gEditMaskData.isClicked.roiPolygon = [];
            % Add first point to the ROI polygon
            gEditMaskData.isClicked.roiPolygon(1,1:2) = curptAxes;
    end
        
    
%% ===== MOUSE MOVE =====
function figureMouseMove_Callback(varargin) %#ok<DEFNU>
    global gEditMaskData;
    if ~isfield(gEditMaskData, 'Handles')
        return;
    end
    handles = gEditMaskData.Handles;
    % Mouse location on the figure
    temp = get(handles.mri_editMask, 'CurrentPoint');
    curptFigure = temp(1,1:2);
    % Mouse location on the axis
    temp = get(handles.axesPreview, 'CurrentPoint');
    curptAxes= temp(1,1:2);
    
    switch(gEditMaskData.isClicked.source)
        case 'preview'
            % Mouse motion
            mouseMotionFigure = gEditMaskData.isClicked.clickPositionFigure - curptFigure;
            gEditMaskData.isClicked.clickPositionFigure = curptFigure;
            % Mouse selection type ?
            switch(lower(get(handles.mri_editMask, 'SelectionType')))
                % Normal left click : Currently selected action
                case 'normal'
                    switch(gEditMaskData.action)                           
                        case {'lasso-', 'lasso+'}
                            % Add current point to the ROI polygon
                            n_1 = size(gEditMaskData.isClicked.roiPolygon,1);
                            gEditMaskData.isClicked.roiPolygon(n_1+1,1:2) = curptAxes;
                            % Draw line between current polygon vertex and last polygon vertex
                            line('XData',[gEditMaskData.isClicked.roiPolygon(n_1,1), gEditMaskData.isClicked.roiPolygon(n_1+1,1)], ...
                                 'YData',[gEditMaskData.isClicked.roiPolygon(n_1,2), gEditMaskData.isClicked.roiPolygon(n_1+1,2)], ...
                                 'ZData',[.1 .1], 'Color', [1 .2 .2], ...
                                 'Parent', handles.axesPreview, ...
                                 'Tag', 'ptCurve', ...
                                 'ButtonDownFcn', @previewMouseClick_Callback);
                    end
                    
                % (Control + Left click) or right click : Change color scale
                case 'alt' 
                    % Increase/decrease image contrast
                    delete(findobj(handles.axesPreview, 'Tag', 'selectionArea'));
                    gEditMaskData.colormapMax = max(8, min(505, gEditMaskData.colormapMax + mouseMotionFigure(2)));
                    UpdateColormap();
            end
    end 
    drawnow
    
        
%% ===== MOUSE UP =====
function figureMouseUp_Callback(varargin) %#ok<DEFNU>
    global gEditMaskData;
    handles = gEditMaskData.Handles;
    gEditMaskData.isClicked.source = '';    
    % Mouse location on the axes
    temp = get(handles.axesPreview, 'CurrentPoint');
    curptAxes= temp(1,1:2);
    % Add or remove new mask
    isAddNewMask = ~isempty(strfind(gEditMaskData.action, '+'));
    % If the mouse pointer is on the preview axes
    switch(gEditMaskData.action)           
        case {'lasso+', 'lasso-'}
            % Close the polygon and display the polygon mask
            n = size(gEditMaskData.isClicked.roiPolygon,1);
            if (n > 1)                 
                gEditMaskData.isClicked.roiPolygon(n+1,1:2) = gEditMaskData.isClicked.roiPolygon(1,1:2); 
                % Extract the binary mask from the polygon
                roiMask = getMask(gEditMaskData.isClicked.roiPolygon);
                % Update mask volume
                AddMaskSlice(roiMask, isAddNewMask);
                % Display mask border
                delete(findobj(handles.axesPreview, 'Tag', 'ptCurve'));
            end
            
        case {'curve+', 'curve-'}
            % Left button : add point
            % Right button : add point and end curve
            % Get new point
            newPt = curptAxes;
            % Add it to list of points
            n = size(gEditMaskData.isClicked.roiPolygon,1);
            gEditMaskData.isClicked.roiPolygon(n+1,1:2) = newPt;
            % Plot point
            hold on
            plot3(handles.axesPreview, newPt(1), newPt(2), 0.2, 'r.', 'Tag', 'ptCurve');
            % Only for right button
            if strcmpi(get(handles.mri_editMask, 'SelectionType'), 'alt') && (n > 1)
                % Add first point to close spline
                gEditMaskData.isClicked.roiPolygon(n+2,1:2) = gEditMaskData.isClicked.roiPolygon(1,1:2);
                % Interpolate with a spline curve and finer spacing.
                t = 1:n+2;
                ts = 1:0.1:n+2;
                splineRoi = spline(t, gEditMaskData.isClicked.roiPolygon', ts);
                % Delete all curve points
                delete(findobj(handles.axesPreview, 'Tag', 'ptCurve'));
                % Plot the interpolated closed curve
                line(splineRoi(1,:), splineRoi(2,:), ones(1,size(splineRoi,2)) * 0.2, ...
                     'Color',     [1 0 0], ...
                     'LineStyle', '-', ...
                     'Tag',       'ptCurve', ...
                     'Parent',    handles.axesPreview);   
                % Extract the binary mask from the polygon
                roiMask = getMask(splineRoi');
                % Update mask volume
                AddMaskSlice(roiMask, isAddNewMask);
                % Reset polygon selection
                gEditMaskData.isClicked.roiPolygon = [];
            end
    end
    
    
%% ===== MOUSE WHEEL =====
% Move slices
function FigureMouseWheelCallback(hObject, event, varargin)
    global gEditMaskData;
    % Get new slice index
    iSlice = gEditMaskData.sliderValue(gEditMaskData.orientation) - double(event.VerticalScrollCount);
    % Go to new slice
    SetSliceLocation(iSlice);
    

%% ===== ACTION BUTTONS CALLBACKS =====
function buttongroupAction_SelectionChangeFcn(varargin) %#ok<DEFNU>
    global gEditMaskData;
    handles = gEditMaskData.Handles;
    % Get selected tool button
    selButton = get(handles.buttongroupAction, 'SelectedObject');
    % If no button is selected, for selection of "Lasso+"
    if isempty(selButton)
        selButton = handles.toggleLassoPlus;
        set(handles.buttongroupAction, 'SelectedObject', selButton);
    end
    % Associate an action name with each button
    switch (selButton)
        case handles.toggleLassoMinus
            action = 'lasso-';
        case handles.toggleLassoPlus
            action = 'lasso+';
        case handles.toggleCurveMinus
            action = 'curve-';
        case handles.toggleCurvePlus
            action = 'curve+';  
    end
    SetAction(action);
    
    
%% ===== SET ACTION =====
function SetAction(action)
    global gEditMaskData;
    handles = gEditMaskData.Handles;
    % Set action
    switch lower(action)
        case 'lasso+'
            set(handles.toggleLassoPlus, 'Value', 1);
        case 'lasso-'
            set(handles.toggleLassoMinus, 'Value', 1);
        case 'curve+'
            set(handles.toggleCurvePlus, 'Value', 1);
        case 'curve-'
            set(handles.toggleCurveMinus, 'Value', 1);
    end
    gEditMaskData.action = action;
    % Update icons
    gui_update_toggle([handles.toggleLassoPlus, handles.toggleLassoMinus, handles.toggleCurvePlus, handles.toggleCurveMinus]);
    % Reset polygon selection
    gEditMaskData.isClicked.roiPolygon = [];
    delete(findobj(handles.axesPreview, 'Tag', 'ptCurve'));
    
    
%% ===== GET POLYGON =====
function roiMask = getMask(roiPolygon)
    global gEditMaskData;
    % Get slice size
    sliceSize = size(gEditMaskData.mri);
    sliceSize(gEditMaskData.orientation) = [];
    % Get pixel size
    pixSize = gEditMaskData.voxsize;
    pixSize(gEditMaskData.orientation) = [];
    % Build full coordinates of each pixel
    sliceX = meshgrid(1:sliceSize(1),1:sliceSize(2));
    sliceX = sliceX(:);
    sliceY = meshgrid(1:sliceSize(2),1:sliceSize(1))';
    sliceY = sliceY(:);
    % Test which pixels are inside the polygon
    iInsidePixels = inpolygon(sliceX(:), sliceY, roiPolygon(:,1) / pixSize(1), roiPolygon(:,2) / pixSize(2));
    iInsidePixels = sub2ind(sliceSize, round(sliceX(iInsidePixels)), round(sliceY(iInsidePixels)));
    % Build mask
    roiMask = false(sliceSize);
    roiMask(iInsidePixels) = 1;
    
    
%% ===== ADD MASK SLICE =====
function AddMaskSlice(sliceMask, isAddNewMask)
    % Update volume
    global gEditMaskData;
    n = gEditMaskData.sliderValue(gEditMaskData.orientation);    
    % Get previous slice from mask
    initSlice = mri_getslice(gEditMaskData.mask, n, gEditMaskData.orientation);
    % Add or remove
    if isAddNewMask
        sliceMask = (initSlice | sliceMask);
    else
        sliceMask = (initSlice & ~sliceMask);
    end
    % Depends on orientation
    switch (gEditMaskData.orientation)
        case 1
            gEditMaskData.mask(n,:,:) = sliceMask;
        case 2
            gEditMaskData.mask(:,n,:) = sliceMask;
        case 3
            gEditMaskData.mask(:,:,n) = sliceMask;
    end
    % Update display
    UpdateSlice();
    
    
%% =================================================================================================
%  ===== COLORMAP AND CONTRAST =====================================================================
%  =================================================================================================
%% ===== INCREASE CONTRAST =====
function buttonContrastUp_Callback(varargin) %#ok<DEFNU>
    global gEditMaskData;
    gEditMaskData.colormapMax = max(8, gEditMaskData.colormapMax - 20);
    UpdateColormap();
    
%% ===== DECREASE CONTRAST =====
function buttonContrastDown_Callback(varargin) %#ok<DEFNU>
    global gEditMaskData;
    gEditMaskData.colormapMax = min(505, gEditMaskData.colormapMax + 20);
    UpdateColormap();
    
%% ===== UPDATE COLORMAP =====
function UpdateColormap()
    global gEditMaskData;
    mapName = gEditMaskData.colormap;
    % Between 0 and 256 : fill the map with the top color of the colormap (bright)
    if (gEditMaskData.colormapMax <= 256)
        map = eval(sprintf('%s(%d)', lower(mapName), gEditMaskData.colormapMax));
        nmap = repmat(map(gEditMaskData.colormapMax,:),256,1);
        nmap(1:gEditMaskData.colormapMax, :) = map;
    % Between 256 and 512 : fill the map with the bottom color of the colormap (dark)
    else 
        map = eval(sprintf('%s(%d)', lower(mapName), 256 - mod(gEditMaskData.colormapMax, 256)));
        nmap = repmat(map(1,:),256,1);
        nmap(257-length(map):256, :) = map;
    end
    set(gEditMaskData.Handles.mri_editMask, 'Colormap', nmap);
    

    
%% =================================================================================================
%  ===== VALIDATION BUTTONS ========================================================================
%  =================================================================================================
%% ===== CANCEL BUTTON =====
function buttonCancel_Callback(varargin) %#ok<DEFNU>
    global gEditMaskData;
    % Return an empty mask
    gEditMaskData.mask = [];
    % Delete window
    delete(gEditMaskData.Handles.mri_editMask);
    drawnow;

%% ===== OK BUTTON =====
function buttonOk_Callback(varargin)  %#ok<DEFNU>
    global gEditMaskData;
    % Delete window
    delete(gEditMaskData.Handles.mri_editMask);
    drawnow;
    



