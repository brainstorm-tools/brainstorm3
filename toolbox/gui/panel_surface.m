function varargout = panel_surface(varargin)
% PANEL_SURFACE: Panel to load and plot surfaces.
% 
% USAGE:  bstPanel = panel_surface('CreatePanel')
%                    panel_surface('UpdatePanel')
%                    panel_surface('CurrentFigureChanged_Callback')
%       nbSurfaces = panel_surface('CreateSurfaceList',      jToolbar, hFig)
%                    panel_surface('UpdateSurfaceProperties')
%         iSurface = panel_surface('AddSurface',             hFig, surfaceFile)
%                    panel_surface('RemoveSurface',          hFig, iSurface)
%                    panel_surface('SetSurfaceTransparency', hFig, iSurf, alpha)
%                    panel_surface('SetSurfaceColor',        hFig, iSurf, colorCortex, colorSulci)
%                    panel_surface('ApplyDefaultDisplay')
%           [isOk] = panel_surface('SetSurfaceData',        hFig, iTess, dataType, dataFile, isStat)
%           [isOk] = panel_surface('UpdateSurfaceData',     hFig, iSurfaces)
%                    panel_surface('UpdateSurfaceColormap', hFig, iSurfaces)
%                    panel_surface('UpdateOverlayCube',     hFig, iTess)

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
% Authors: Francois Tadel, 2008-2022
%          Martin Cousineau, 2019

eval(macro_method);
end


%% ===== CREATE PANEL =====
function bstPanelNew = CreatePanel() %#ok<DEFNU>
    panelName = 'Surface';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.icon.*;
    % Create tools panel
    jPanelNew = gui_component('Panel');
    jPanelTop = gui_component('Panel');
    jPanelNew.add(jPanelTop, BorderLayout.NORTH);
    % Constants
    TB_DIM = java_scaled('dimension', 25, 25);
    LABEL_WIDTH    = java_scaled('value', 30);
    BUTTON_WIDTH   = java_scaled('value', 50);
    SLIDER_WIDTH   = java_scaled('value', 20);
    DEFAULT_HEIGHT = java_scaled('value', 22);

    % ===== TOOLBAR =====
    jMenuBar = gui_component('MenuBar', jPanelTop, BorderLayout.NORTH);
        jToolbar = gui_component('Toolbar', jMenuBar);
        jToolbar.setPreferredSize(TB_DIM);
        jToolbar.setOpaque(0);
        % Title
        gui_component('Label', jToolbar, [], '    ');
        % Separation panel
        jToolbar.add(Box.createHorizontalGlue());
        jToolbar.addSeparator(Dimension(10, TB_DIM.getHeight()));
        % Add/Remove button
        jButtonSurfAdd = gui_component('ToolbarButton', jToolbar, [], [], {IconLoader.ICON_SURFACE_ADD, TB_DIM},    'Add a surface',              @(h,ev)ButtonAddSurfaceCallback);
        jButtonSurfDel = gui_component('ToolbarButton', jToolbar, [], [], {IconLoader.ICON_SURFACE_REMOVE, TB_DIM}, 'Remove surface from figure', @(h,ev)ButtonRemoveSurfaceCallback);
        
    % ==== OPTION PANELS =====
    jPanelOptions = gui_component('Panel');
    jPanelOptions.setLayout(BoxLayout(jPanelOptions, BoxLayout.Y_AXIS));
    jPanelOptions.setBorder(BorderFactory.createEmptyBorder(7,7,0,7));
        % ===== SURFACE OPTIONS =====
        jPanelSurfaceOptions = gui_river([1,1], [1,8,1,4], 'Surface options');
            % Alpha title 
            jLabelAlphaTitle = gui_component('label', jPanelSurfaceOptions, 'br', 'Transp.:');
            % Alpha slider
            jSliderSurfAlpha = JSlider(0, 100, 0);
            jSliderSurfAlpha.setPreferredSize(Dimension(SLIDER_WIDTH, DEFAULT_HEIGHT));
            java_setcb(jSliderSurfAlpha, 'MouseReleasedCallback', @(h,ev)SliderCallback(h, ev, 'SurfAlpha'), ...
                                         'KeyPressedCallback',    @(h,ev)SliderCallback(h, ev, 'SurfAlpha'));
            jPanelSurfaceOptions.add('tab hfill', jSliderSurfAlpha);
            % Alpha label
            jLabelSurfAlpha = gui_component('label', jPanelSurfaceOptions, [], '   0%', {JLabel.RIGHT, Dimension(LABEL_WIDTH, DEFAULT_HEIGHT)});
            % Quick preview
            java_setcb(jSliderSurfAlpha, 'StateChangedCallback',  @(h,ev)SliderQuickPreview(jSliderSurfAlpha, jLabelSurfAlpha, 1));

            % Smooth title
            gui_component('label', jPanelSurfaceOptions, 'br', 'Smooth:');
            % Smooth slider 
            jSliderSurfSmoothValue = JSlider(0, 100, 0);
            jSliderSurfSmoothValue.setPreferredSize(Dimension(SLIDER_WIDTH, DEFAULT_HEIGHT));
            jSliderSurfSmoothValue.setToolTipText('Smooth surface');
            java_setcb(jSliderSurfSmoothValue, 'MouseReleasedCallback', @(h,ev)SliderCallback(h, ev, 'SurfSmoothValue'), ...
                                               'KeyPressedCallback',    @(h,ev)SliderCallback(h, ev, 'SurfSmoothValue'));
            jPanelSurfaceOptions.add('tab hfill', jSliderSurfSmoothValue);
            % Smooth ALPHA label
            jLabelSurfSmoothValue = gui_component('label', jPanelSurfaceOptions, [], '   0%', {JLabel.RIGHT, Dimension(LABEL_WIDTH, DEFAULT_HEIGHT)});
            % Quick preview
            java_setcb(jSliderSurfSmoothValue, 'StateChangedCallback',  @(h,ev)SliderQuickPreview(jSliderSurfSmoothValue, jLabelSurfSmoothValue, 1));

            % Buttons
            jButtonSurfColor = gui_component('button', jPanelSurfaceOptions, 'br center', 'Color', {Dimension(BUTTON_WIDTH, DEFAULT_HEIGHT), Insets(0,0,0,0)}, 'Set surface color', @ButtonSurfColorCallback);
            jButtonSurfSulci = gui_component('toggle', jPanelSurfaceOptions, '',          'Sulci', {Dimension(BUTTON_WIDTH, DEFAULT_HEIGHT), Insets(0,0,0,0)}, 'Show/hide sulci map', @ButtonShowSulciCallback);
            jButtonSurfEdge  = gui_component('toggle', jPanelSurfaceOptions, '',          'Edge',  {Dimension(BUTTON_WIDTH, DEFAULT_HEIGHT), Insets(0,0,0,0)}, 'Show/hide surface triangles', @ButtonShowEdgesCallback);
        jPanelOptions.add(jPanelSurfaceOptions);
    
        % ===== DATA OPTIONS =====
        jPanelDataOptions = gui_river([1,1], [1,8,1,4], 'Data options');
            % Threshold title
            jLabelThreshTitle = gui_component('label', jPanelDataOptions, [], 'Amplitude:');
            % Threshold slider
            jSliderDataThresh = JSlider(0, 100, 50);
            jSliderDataThresh.setPreferredSize(Dimension(SLIDER_WIDTH, DEFAULT_HEIGHT));
            java_setcb(jSliderDataThresh, 'MouseReleasedCallback', @(h,ev)SliderCallback(h, ev, 'DataThreshold'), ...
                                          'KeyPressedCallback',    @(h,ev)SliderCallback(h, ev, 'DataThreshold'));
            jPanelDataOptions.add('tab hfill', jSliderDataThresh);
            % Threshold label
            jLabelDataThresh = gui_component('label', jPanelDataOptions, [], '   0%', {JLabel.RIGHT, Dimension(LABEL_WIDTH, DEFAULT_HEIGHT)});
            % Quick preview
            java_setcb(jSliderDataThresh, 'StateChangedCallback',  @(h,ev)SliderQuickPreview(jSliderDataThresh, jLabelDataThresh, 1));
            
            % Min size title
            jLabelSizeTitle = gui_component('label', jPanelDataOptions, 'br', 'Min size:');
            % Min size slider
            jSliderSize = JSlider(1, length(GetSliderSizeVector(15000)), 1);
            jSliderSize.setPreferredSize(Dimension(SLIDER_WIDTH, DEFAULT_HEIGHT));
            java_setcb(jSliderSize, 'MouseReleasedCallback', @(h,ev)SliderCallback(h, ev, 'SizeThreshold'), ...
                                    'KeyPressedCallback',    @(h,ev)SliderCallback(h, ev, 'SizeThreshold'));
            jPanelDataOptions.add('tab hfill', jSliderSize);
            % Min size label
            jLabelSize = gui_component('label', jPanelDataOptions, [], '   1', {JLabel.RIGHT, Dimension(LABEL_WIDTH, DEFAULT_HEIGHT)});
            % Quick preview
            java_setcb(jSliderSize, 'StateChangedCallback',  @(h,ev)SliderQuickPreview(jSliderSize, jLabelSize, 0));
            
            % Alpha title and slider
            jLabelDataAlphaTitle = gui_component('label', jPanelDataOptions, 'br', 'Transp:');           
            jSliderDataAlpha = JSlider(0, 100, 0);
            jSliderDataAlpha.setPreferredSize(Dimension(SLIDER_WIDTH, DEFAULT_HEIGHT));
            java_setcb(jSliderDataAlpha, 'MouseReleasedCallback', @(h,ev)SliderCallback(h, ev, 'DataAlpha'), ...
                                         'KeyPressedCallback',    @(h,ev)SliderCallback(h, ev, 'DataAlpha'));
            jPanelDataOptions.add('tab hfill', jSliderDataAlpha);
            % Data alpha label
            jLabelDataAlpha = gui_component('label', jPanelDataOptions, [], '   0%', {JLabel.RIGHT, Dimension(LABEL_WIDTH, DEFAULT_HEIGHT)});
            % Quick preview
            java_setcb(jSliderDataAlpha, 'StateChangedCallback',  @(h,ev)SliderQuickPreview(jSliderDataAlpha, jLabelDataAlpha, 1));
        jPanelOptions.add(jPanelDataOptions);
        
        % ===== RESECT =====
        jPanelSurfaceResect = gui_river([0,4], [1,8,8,0], 'Resect [X,Y,Z]');
            % === RESECT SLIDERS ===
            % Sub panel
            panelResect = java_create('javax.swing.JPanel');
            panelResect.setLayout(BoxLayout(panelResect, BoxLayout.LINE_AXIS));
                % Resect X : Slider 
                jSliderResectX = JSlider(-100, 100, 0);
                jSliderResectX.setPreferredSize(Dimension(SLIDER_WIDTH, DEFAULT_HEIGHT));
                jSliderResectX.setToolTipText('Keyboard shortcut: [X] / [SHIFT]+[X]');
                java_setcb(jSliderResectX, 'MouseReleasedCallback', @(h,ev)SliderResectCallback(h, ev, 'ResectX'), ...
                                           'KeyPressedCallback',    @(h,ev)SliderResectCallback(h, ev, 'ResectX'));
                panelResect.add('hfill', jSliderResectX);
                % Resect Y : Title and Slider 
                jSliderResectY = JSlider(-100, 100, 0);
                jSliderResectY.setPreferredSize(Dimension(SLIDER_WIDTH, DEFAULT_HEIGHT));
                jSliderResectY.setToolTipText('Keyboard shortcut: [Y] / [SHIFT]+[Y]');
                java_setcb(jSliderResectY, 'MouseReleasedCallback', @(h,ev)SliderResectCallback(h, ev, 'ResectY'), ...
                                           'KeyPressedCallback',    @(h,ev)SliderResectCallback(h, ev, 'ResectY'));
                panelResect.add('hfill', jSliderResectY);     
                % Resect Z : Title and Slider 
                jSliderResectZ = JSlider(-100, 100, 0);
                jSliderResectZ.setPreferredSize(Dimension(SLIDER_WIDTH, DEFAULT_HEIGHT));
                jSliderResectZ.setToolTipText('Keyboard shortcut: [Z] / [SHIFT]+[Z]');
                java_setcb(jSliderResectZ, 'MouseReleasedCallback', @(h,ev)SliderResectCallback(h, ev, 'ResectZ'), ...
                                           'KeyPressedCallback',    @(h,ev)SliderResectCallback(h, ev, 'ResectZ'));
                panelResect.add('hfill', jSliderResectZ);   
            jPanelSurfaceResect.add('hfill', panelResect);
            
            % === HEMISPHERES SELECTION ===
            jToggleResectLeft   = gui_component('toggle', jPanelSurfaceResect, 'br center', 'Left',   {Insets(0,0,0,0), Dimension(BUTTON_WIDTH-3, DEFAULT_HEIGHT)}, '', @ButtonResectLeftToggle_Callback);           
            jToggleResectRight  = gui_component('toggle', jPanelSurfaceResect, '',          'Right',  {Insets(0,0,0,0), Dimension(BUTTON_WIDTH-3, DEFAULT_HEIGHT)}, '', @ButtonResectRightToggle_Callback);           
            jToggleResectStruct = gui_component('toggle', jPanelSurfaceResect, '',          'Struct', {Insets(0,0,0,0), Dimension(BUTTON_WIDTH-3, DEFAULT_HEIGHT)}, '', @ButtonResectStruct_Callback);           
            jButtonResectReset  = gui_component('button', jPanelSurfaceResect, '',          'Reset', {Insets(0,0,0,0), Dimension(BUTTON_WIDTH-3, DEFAULT_HEIGHT)}, '', @ButtonResectResetCallback);
        jPanelOptions.add(jPanelSurfaceResect);
 
        % ===== SURFACE LABELS =====
        jPanelLabels = gui_river([0,4]);
            gui_component('label', jPanelLabels, [], '    Vertices: ');
            jLabelNbVertices = gui_component('label', jPanelLabels, [], '0');
            gui_component('label', jPanelLabels, [], '    Faces: ');
            jLabelNbFaces = gui_component('label', jPanelLabels, [], '0');
        jPanelOptions.add(jPanelLabels);
    jPanelTop.add(jPanelOptions, BorderLayout.CENTER);
    
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jToolbar',               jToolbar, ...
                                  'jButtonSurfAdd',         jButtonSurfAdd, ...
                                  'jButtonSurfDel',         jButtonSurfDel, ...
                                  'jPanelOptions',          jPanelOptions, ...                    
                                  'jLabelNbVertices',       jLabelNbVertices, ...
                                  'jLabelNbFaces',          jLabelNbFaces, ...
                                  'jSliderSurfAlpha',       jSliderSurfAlpha, ...
                                  'jLabelSurfAlpha',        jLabelSurfAlpha, ...
                                  'jButtonSurfColor',       jButtonSurfColor, ...
                                  'jLabelSurfSmoothValue',  jLabelSurfSmoothValue, ...
                                  'jSliderSurfSmoothValue', jSliderSurfSmoothValue, ...
                                  'jButtonSurfSulci',       jButtonSurfSulci, ...
                                  'jButtonSurfEdge',        jButtonSurfEdge, ...
                                  'jSliderResectX',         jSliderResectX, ...
                                  'jSliderResectY',         jSliderResectY, ...
                                  'jSliderResectZ',         jSliderResectZ, ...
                                  'jToggleResectLeft',      jToggleResectLeft, ...
                                  'jToggleResectRight',     jToggleResectRight, ...
                                  'jToggleResectStruct',    jToggleResectStruct, ...
                                  'jButtonResectReset',     jButtonResectReset, ...
                                  'jLabelAlphaTitle',       jLabelAlphaTitle, ...
                                  'jLabelDataAlphaTitle',   jLabelDataAlphaTitle, ...
                                  'jSliderDataAlpha',       jSliderDataAlpha, ...
                                  'jLabelDataAlpha',        jLabelDataAlpha, ...
                                  'jLabelSizeTitle',        jLabelSizeTitle, ...
                                  'jLabelSize',             jLabelSize, ...
                                  'jSliderSize',            jSliderSize, ...
                                  'jLabelThreshTitle',      jLabelThreshTitle, ...
                                  'jSliderDataThresh',      jSliderDataThresh, ...
                                  'jLabelDataThresh',       jLabelDataThresh));


    %% ===== SLIDER QUICK PREVIEW =====
    function SliderQuickPreview(jSlider, jText, isPercent)
        if (jSlider == jSliderSize)
            nVertices = str2num(char(jLabelNbVertices.getText()));
            sliderSizeVector = GetSliderSizeVector(nVertices);
            jText.setText(sprintf('%d', sliderSizeVector(double(jSlider.getValue()))));
        elseif isPercent
            jText.setText(sprintf('%d%%', double(jSlider.getValue())));
        else
            jText.setText(sprintf('%d', double(jSlider.getValue())));
        end
    end
                            
    %% ===== RESECT SLIDER =====
    function SliderResectCallback(hObject, event, target)
        % Call the slider callback
        SliderCallback(hObject, event, target);
%         % Redraw all the scouts
%         hFig = bst_figures('GetCurrentFigure', '3D');
%         if ~isempty(hFig)
%             panel_scout('ReloadScouts', hFig);
%         end
    end

    %% ===== RESET RESECT CALLBACK =====
    function ButtonResectResetCallback(varargin)
        import java.awt.event.MouseEvent;
        % Reset initial resect sliders positions
        jSliderResectX.setValue(0);
        jSliderResectY.setValue(0);
        jSliderResectZ.setValue(0);
        
        % Get handle to current 3DViz figure
        hFig = bst_figures('GetCurrentFigure', '3D');
        if isempty(hFig)
            return
        end
        % Get current surface
        iSurf = getappdata(hFig, 'iSurface');
        TessInfo = getappdata(hFig, 'Surface');
        if isempty(iSurf) || isempty(TessInfo)
            return;
        end
        % MRI: Redraw 3 orientations
        if strcmpi(TessInfo(iSurf).Name, 'Anatomy')
            SliderCallback([], MouseEvent(jSliderResectX, 0, 0, 0, 0, 0, 1, 0), 'ResectX');
            SliderCallback([], MouseEvent(jSliderResectY, 0, 0, 0, 0, 0, 1, 0), 'ResectY');
            SliderCallback([], MouseEvent(jSliderResectZ, 0, 0, 0, 0, 0, 1, 0), 'ResectZ');
        % Surface: Call the update function only once
        else
            % If updating FEM mesh, update all layers
            if strcmpi(TessInfo(iSurf).Name, 'FEM')
                iSurf = find(strcmpi({TessInfo.Name}, 'FEM'));
            end
            [TessInfo(iSurf).Resect] = deal('none');
            setappdata(hFig, 'Surface', TessInfo);
            SliderCallback([], MouseEvent(jSliderResectX, 0, 0, 0, 0, 0, 1, 0), 'ResectX');
        end
        % Redraw all the scouts (for surfaces only)
        % panel_scout('ReloadScouts', hFig);
    end

    %% ===== RESECT LEFT TOGGLE CALLBACK =====
    function ButtonResectLeftToggle_Callback(varargin)
        if jToggleResectLeft.isSelected()
            jToggleResectRight.setSelected(0);
            jToggleResectStruct.setSelected(0);
            SelectHemispheres('left');
        else
            SelectHemispheres('none');
        end
    end

    %% ===== RESECT RIGHT TOGGLE CALLBACK =====
    function ButtonResectRightToggle_Callback(varargin)
        if jToggleResectRight.isSelected()
            jToggleResectLeft.setSelected(0);
            jToggleResectStruct.setSelected(0);
            SelectHemispheres('right');
        else
            SelectHemispheres('none');
        end
    end

    %% ===== RESECT STRUCT CALLBACK =====
    function ButtonResectStruct_Callback(varargin)
        if jToggleResectStruct.isSelected()
            jToggleResectLeft.setSelected(0);
            jToggleResectRight.setSelected(0);
            SelectHemispheres('struct');
        else
            SelectHemispheres('none');
        end
    end
end


%% =================================================================================
%  === CONTROLS CALLBACKS  =========================================================
%  =================================================================================
%% ===== SLIDERS CALLBACKS =====
function SliderCallback(hObject, event, target)
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Surface');
    if isempty(ctrl)
        return;
    end
    % Get slider pointer
    jSlider = event.getSource();
    % If slider is not enabled : do nothing
    if ~jSlider.isEnabled()
        return
    end

    % Get handle to current 3DViz figure
    hFig = bst_figures('GetCurrentFigure', '3D');
    if isempty(hFig)
        return
    end
    % Get current surface index (in the current figure)
    iSurface = getappdata(hFig, 'iSurface');
    % If surface data is not accessible
    if isempty(hFig) || isempty(iSurface)
        return;
    end
    % Get figure AppData (figure's surfaces configuration)
    TessInfo = getappdata(hFig, 'Surface');
    if (iSurface > length(TessInfo))
        return;
    end
    % Is selected surface a MRI/slices surface
    isAnatomy = strcmpi(TessInfo(iSurface).Name, 'Anatomy');
    
    % Get slider value and update surface value
    switch (target)
        case 'SurfAlpha'
            % Update value in Surface array
            TessInfo(iSurface).SurfAlpha = jSlider.getValue() / 100;
            % Display value in the label associated with the slider
            ctrl.jLabelSurfAlpha.setText(sprintf('%d%%', round(TessInfo(iSurface).SurfAlpha * 100)));
            % Update current surface
            setappdata(hFig, 'Surface', TessInfo);
            % For MRI: redraw all slices
            if isAnatomy
                figure_callback(hFig, 'UpdateMriDisplay', hFig, [], TessInfo, iSurface);
            % Else: Update color display on the surface
            else
                figure_callback(hFig, 'UpdateSurfaceAlpha', hFig, iSurface);
            end
    
        case 'SurfSmoothValue'
            SurfSmoothValue = jSlider.getValue() / 100;
            SetSurfaceSmooth(hFig, iSurface, SurfSmoothValue, 1);

        case 'DataAlpha'
            % Update value in Surface array
            TessInfo(iSurface).DataAlpha = jSlider.getValue() / 100;
            ctrl.jLabelDataAlpha.setText(sprintf('%d%%', round(TessInfo(iSurface).DataAlpha * 100)));
            % Update current surface
            setappdata(hFig, 'Surface', TessInfo);
            % Update color display on the surface
            figure_callback(hFig, 'UpdateSurfaceColor', hFig, iSurface);
            % Set the new value as he default value (NOT FOR MRI)
            DefaultSurfaceDisplay = bst_get('DefaultSurfaceDisplay');
            DefaultSurfaceDisplay.DataAlpha = TessInfo(iSurface).DataAlpha;
            bst_set('DefaultSurfaceDisplay', DefaultSurfaceDisplay); 
            
        case 'DataThreshold'
            % Update value in Surface array
            TessInfo(iSurface).DataThreshold = jSlider.getValue() / 100;
            ctrl.jLabelDataThresh.setText(sprintf('%d%%', round(TessInfo(iSurface).DataThreshold * 100)));
            % Update current surface
            setappdata(hFig, 'Surface', TessInfo);
            % Update color display on the surface
            figure_callback(hFig, 'UpdateSurfaceColor', hFig, iSurface);
            % Set the new value as the default value (NOT FOR MRI)
            DefaultSurfaceDisplay = bst_get('DefaultSurfaceDisplay');
            DefaultSurfaceDisplay.DataThreshold = TessInfo(iSurface).DataThreshold;
            bst_set('DefaultSurfaceDisplay', DefaultSurfaceDisplay); 
            
        case 'SizeThreshold'
            % Update value in Surface array
            sliderSizeVector = GetSliderSizeVector(TessInfo(iSurface).nVertices);
            TessInfo(iSurface).SizeThreshold = sliderSizeVector(jSlider.getValue());
            ctrl.jLabelSize.setText(sprintf('%d', TessInfo(iSurface).SizeThreshold));
            % Update current surface
            setappdata(hFig, 'Surface', TessInfo);
            % Update color display on the surface
            figure_callback(hFig, 'UpdateSurfaceColor', hFig, iSurface);
            % Set the new value as the default value (NOT FOR MRI)
            if ~isAnatomy
                DefaultSurfaceDisplay = bst_get('DefaultSurfaceDisplay');
                DefaultSurfaceDisplay.SizeThreshold = TessInfo(iSurface).SizeThreshold;
                bst_set('DefaultSurfaceDisplay', DefaultSurfaceDisplay); 
            end
        case {'ResectX', 'ResectY', 'ResectZ'}
            % Get target axis
            dim = find(strcmpi(target, {'ResectX', 'ResectY', 'ResectZ'}));
            % JSliderResect values : [-100,100]
            if isAnatomy
                % Get MRI size
                sMri = bst_memory('GetMri', TessInfo(iSurface).SurfaceFile);
                cubeSize = size(sMri.Cube(:,:,:,1));
                % Change slice position
                newPos = round((jSlider.getValue()+100) / 200 * cubeSize(dim));
                newPos = bst_saturate(newPos, [1, cubeSize(dim)]);
                TessInfo(iSurface).CutsPosition(dim) = newPos;
                % Update MRI display
                figure_callback(hFig, 'UpdateMriDisplay', hFig, dim, TessInfo, iSurface);
            else
                ResectSurface(hFig, iSurface, dim, jSlider.getValue() / 100);
                if ~isempty(hFig)
                    panel_scout('ReloadScouts', hFig);
                end
            end

        otherwise
            error('Unknow slider');
    end
end

%% ===== GET SLIDER SIZE VECTOR =====
function sliderSizeVector = GetSliderSizeVector(nVertices)
    f = (nVertices / 15000);
    if (f < 2)
        sliderSizeVector = [1:19, 20:2:58, 60:5:125, 130:10:200];
    elseif (f < 4)
        sliderSizeVector = [1:19, 20:5:115, 120:10:250, 260:20:400];
    elseif (f <= 7)
        sliderSizeVector = [1:19, 20:10:175, 200:25:650, 700:50:1000];
    else
        sliderSizeVector = [1:19, 20:10:150, 200:50:1050, 1100:100:2000];
    end
end


%% ===== SCROLL MRI CUTS =====
function ScrollMriCuts(hFig, direction, value) %#ok<DEFNU>
    % Get Mri and figure Handles
    [sMri, TessInfo, iTess, iMri] = panel_surface('GetSurfaceMri', hFig);
    Handles = bst_figures('GetFigureHandles', hFig);
    % Get dimension
    switch (direction)
        case 'x',  dim = 1;
        case 'y',  dim = 2;
        case 'z',  dim = 3;
    end
    % Change position of slices
    TessInfo(iTess).CutsPosition(dim) = TessInfo(iTess).CutsPosition(dim) + value;
    % Update interface (Surface tab and MRI figure)
    figure_mri('SetLocation', 'voxel', sMri, Handles, TessInfo(iTess).CutsPosition);
end


%% ===== BUTTON SURFACE COLOR CALLBACK =====
function ButtonSurfColorCallback(varargin)
    % Get handle to current 3DViz figure
    hFig = bst_figures('GetCurrentFigure', '3D');
    if isempty(hFig)
        return
    end
    % Get figure AppData (figure's surfaces configuration)
    TessInfo = getappdata(hFig, 'Surface');
    % Get current surface index (in the current figure)
    iSurface = getappdata(hFig, 'iSurface');
    % Ignore MRI slices
    if strcmpi(TessInfo(iSurface).Name, 'Anatomy')
        return
    end
    % Ask user to select a color
    % colorCortex = uisetcolor(TessInfo(iSurface).AnatomyColor(2,:), 'Select surface color');
    colorCortex = java_dialog('color');
    if (length(colorCortex) ~= 3)
        return
    end
    % Change surface color
    SetSurfaceColor(hFig, iSurface, colorCortex);
end
             

%% ===== BUTTON "SULCI" CALLBACK =====
function ButtonShowSulciCallback(hObject, event)
    % Get handle to current 3DViz figure
    hFig = bst_figures('GetCurrentFigure', '3D');
    if isempty(hFig)
        return
    end
    % Get current surface index (in the current figure)
    iSurface = getappdata(hFig, 'iSurface');
    % Get handle to "View" button
    jButtonSurfSulci = event.getSource();
    % Show/hide sulci map in figure display
    SetShowSulci(hFig, iSurface, jButtonSurfSulci.isSelected());
    % Set the new value as the default value
    DefaultSurfaceDisplay = bst_get('DefaultSurfaceDisplay');
    DefaultSurfaceDisplay.SurfShowSulci = jButtonSurfSulci.isSelected();
    bst_set('DefaultSurfaceDisplay', DefaultSurfaceDisplay);
end

%% ===== SET SHOW SULCI =====
% Usage : SetShowSulci(hFig, iSurfaces, status)
% Parameters : 
%     - hFig : handle to a 3DViz figure
%     - iSurfaces : can be a single indice or an array of indices
%     - status    : 1=display, 0=hide
function SetShowSulci(hFig, iSurfaces, status)
    % Get surfaces list 
    TessInfo = getappdata(hFig, 'Surface');
    % If FEM tetrahedral mesh: always skip this call
    if any(strcmpi({TessInfo(iSurfaces).Name}, 'FEM'))
        return;
    end
    % Process all surfaces
    for i = 1:length(iSurfaces)
        iSurf = iSurfaces(i);
        % Set status : show/hide
        TessInfo(iSurf).SurfShowSulci = status;
    end
    % Update figure's AppData (surfaces configuration)
    setappdata(hFig, 'Surface', TessInfo);
    % Update panel controls
    UpdateSurfaceProperties();
    % Update surface display
    figure_callback(hFig, 'UpdateSurfaceColor', hFig, iSurf);
end


%% ===== SHOW SURFACE EDGES =====
function ButtonShowEdgesCallback(varargin)
    % Get handle to current 3DViz figure
    hFig = bst_figures('GetCurrentFigure', '3D');
    if isempty(hFig)
        return
    end
    % Get current surface (in the current figure)
    TessInfo = getappdata(hFig, 'Surface');
    iSurf    = getappdata(hFig, 'iSurface');
    % If FEM tetrahedral mesh: link all the layers
    if strcmpi(TessInfo(iSurf).Name, 'FEM')
        iSurf = find(strcmpi({TessInfo.Name}, 'FEM'));
    end
    % Set edges display on/off
    for i = 1:length(iSurf)
        TessInfo(iSurf(i)).SurfShowEdges = ~TessInfo(iSurf(i)).SurfShowEdges;
    end
    setappdata(hFig, 'Surface', TessInfo);
    % Update display
    for i = 1:length(iSurf)
        figure_callback(hFig, 'UpdateSurfaceColor', hFig, iSurf(i));
    end
end




%% ===== HEMISPHERE SELECTION RADIO CALLBACKS =====
function SelectHemispheres(name)
    % Get panel handles
    ctrl = bst_get('PanelControls', 'Surface');
    if isempty(ctrl)
        return;
    end
    % Get handle to current 3DViz figure
    hFig = bst_figures('GetCurrentFigure', '3D');
    if isempty(hFig)
        return
    end
    % Get surface properties
    TessInfo = getappdata(hFig, 'Surface');
    iSurf    = getappdata(hFig, 'iSurface');
    % Ignore MRI
    if strcmpi(TessInfo(iSurf).Name, 'Anatomy')
        return;
    end
    % If updating FEM mesh, update all layers
    if strcmpi(TessInfo(iSurf).Name, 'FEM')
        iSurf = find(strcmpi({TessInfo.Name}, 'FEM'));
    end
    % Update surface Resect field
    for i = 1:length(iSurf)
        TessInfo(iSurf(i)).Resect = name;
    end
    setappdata(hFig, 'Surface', TessInfo);
    % Reset all the resect sliders
    ctrl.jSliderResectX.setValue(0);
    ctrl.jSliderResectY.setValue(0);
    ctrl.jSliderResectZ.setValue(0);
    % Display progress bar
    bst_progress('start', 'Select hemisphere', 'Selecting hemisphere...');
    % Update surface display
    for i = 1:length(iSurf)
        figure_callback(hFig, 'UpdateSurfaceAlpha', hFig, iSurf(i));
    end
    % Redraw all the scouts
    panel_scout('ReloadScouts', hFig)
    % Display progress bar
    bst_progress('stop');
end


%% ===== RESECT SURFACE =====
function ResectSurface(hFig, iSurf, resectDim, resectValue)
    % Get surfaces description
    TessInfo = getappdata(hFig, 'Surface');
    % If updating FEM mesh, update all layers
    if strcmpi(TessInfo(iSurf).Name, 'FEM')
        iSurf = find(strcmpi({TessInfo.Name}, 'FEM'));
        bst_progress('start', 'Resect surface', 'Resecting...', 0, length(iSurf)+1);
        isProgress = 1;
    else
        isProgress = 0;
    end
    % Update all selected surfaces
    for i = 1:length(iSurf)
        % If previously using "Select hemispheres"
        if ischar(TessInfo(iSurf(i)).Resect)
            % Reset "Resect" field
            TessInfo(iSurf(i)).Resect = [0 0 0];
        end
        % Update value in Surface array
        TessInfo(iSurf(i)).Resect(resectDim) = resectValue;
    end
    % Update surface
    setappdata(hFig, 'Surface', TessInfo);
    % Hide trimmed part of the surface
    for i = 1:length(iSurf)
        if isProgress
            bst_progress('text', ['Resecting: ', TessInfo(iSurf(i)).SurfaceFile, '...']);
            bst_progress('inc', 1);
        end
        figure_callback(hFig, 'UpdateSurfaceAlpha', hFig, iSurf(i));
    end
    % Update slice of tensors
    if strcmpi(TessInfo(1).Name, 'FEM')
        FigureId = getappdata(hFig, 'FigureId');
        if isequal(FigureId.SubType, 'TensorsFem')
            figure_callback(hFig, 'PlotTensorCut', hFig, resectValue, resectDim, 1);
        end
    end
    % Deselect both Left and Right buttons
    ctrl = bst_get('PanelControls', 'Surface');
    ctrl.jToggleResectLeft.setSelected(0);
    ctrl.jToggleResectRight.setSelected(0);
    ctrl.jToggleResectStruct.setSelected(0);
    % Close progress bar
    if isProgress
        bst_progress('text', 'Updating figure...');
        bst_progress('inc', 1);
        drawnow
        bst_progress('stop');
    end
end


%% ===== ADD SURFACE CALLBACK =====
function ButtonAddSurfaceCallback(surfaceType)
    % Get target figure handle
    hFig = bst_figures('GetCurrentFigure', '3D');
    if isempty(hFig)
        return
    end
    % Get displayed surfaces
    TessInfo = getappdata(hFig, 'Surface');
    % Get current subject
    SubjectFile = getappdata(hFig, 'SubjectFile');
    if isempty(SubjectFile)
        return
    end
    sSubject = bst_get('Subject', SubjectFile);
    if isempty(sSubject)
        return
    end
    % List of available surfaces types
    if (nargin < 1) || isempty(surfaceType)
        typesList = {};
        if ~isempty(sSubject.iScalp)
            typesList{end+1} = 'Scalp';
        end
        if ~isempty(sSubject.iOuterSkull)
            typesList{end+1} = 'OuterSkull';
        end
        if ~isempty(sSubject.iInnerSkull)
            typesList{end+1} = 'InnerSkull';
        end
        if ~isempty(sSubject.iCortex)
            typesList{end+1} = 'Cortex';
        end
        if ~isempty(sSubject.iFibers)
            typesList{end+1} = 'Fibers';
        end
        if ~isempty(sSubject.iFEM)
            typesList{end+1} = 'FEM';
        end
        
        % Get low resolution white surface
        iWhite = find(~cellfun(@(c)isempty(strfind(lower(c),'white')), {sSubject.Surface.Comment}));
        % If there are multiple surfaces with "white" in the comment, try to get the one with the lowest resolution
        if ~isempty(iWhite)
            if (length(iWhite) > 1)
                nVert = Inf * ones(1, length(iWhite));
                for i = 1:length(iWhite)
                    strN = sSubject.Surface(iWhite(i)).Comment(ismember(sSubject.Surface(iWhite(i)).Comment, '1234567890'));
                    if ~isempty(strN)
                        nVert(i) = str2num(strN);
                    end
                end
                [vMin,iMin] = min(nVert);
                if ~isinf(vMin)
                    iWhite = iWhite(iMin);
                else
                    iWhite = iWhite(1);
                end
            end
            typesList{end+1} = 'White';
        end
        if ~isempty(sSubject.iAnatomy)
            typesList{end+1} = 'Anatomy';
        end
        
        % Subcortical atlas
        iSubCortical = find(~cellfun(@(c)isempty(strfind(lower(c),'subcortical')), {sSubject.Surface.Comment}), 1);
        if isempty(iSubCortical)
            iSubCortical = find(~cellfun(@(c)isempty(strfind(lower(c),'aseg')), {sSubject.Surface.Comment}), 1);
        end
        if ~isempty(iSubCortical)
            typesList{end+1} = 'Subcortical';
        end
        % Remove surfaces that are already displayed
        if ~isempty(TessInfo)
            typesList = setdiff(typesList, {TessInfo.Name});
        end
        % Nothing more
        if isempty(typesList)
            bst_error('There are no additional anatomy files that you can add to this figure.', 'Add surface', 0);
            return;
        end
        % Add "other", to allow importing all the other surfaces
        typesList{end+1} = 'Other';
        % Ask user which kind of surface he wants to add to the figure 3DViz
        surfaceType = java_dialog('question', 'What kind of surface would you like to display ?', 'Add surface', [], typesList, typesList{1});
    end
    if isempty(surfaceType)
        return;
    end
    % Switch between surfaces types
    switch (surfaceType)
        case 'Anatomy'
            SurfaceFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
        case 'Cortex'
            SurfaceFile = sSubject.Surface(sSubject.iCortex(1)).FileName;
        case 'Scalp'
            SurfaceFile = sSubject.Surface(sSubject.iScalp(1)).FileName;
        case 'InnerSkull'
            SurfaceFile = sSubject.Surface(sSubject.iInnerSkull(1)).FileName;
        case 'OuterSkull'
            SurfaceFile = sSubject.Surface(sSubject.iOuterSkull(1)).FileName;
        case 'Fibers'
            SurfaceFile = sSubject.Surface(sSubject.iFibers).FileName;
        case 'FEM'
            SurfaceFile = sSubject.Surface(sSubject.iFEM).FileName;
        case 'Subcortical'
            SurfaceFile = sSubject.Surface(iSubCortical).FileName;
        case 'White'
            SurfaceFile = sSubject.Surface(iWhite).FileName;
        case 'Other'
            % Offer all the other surfaces
            Comment = java_dialog('combo', '<HTML>Select the surface to add:<BR><BR>', 'Select surface', [], {sSubject.Surface.Comment});
            if isempty(Comment)
                return;
            end
            iSurface = find(strcmp({sSubject.Surface.Comment}, Comment), 1);
            SurfaceFile = sSubject.Surface(iSurface).FileName;
        otherwise
            return;
    end
    % Add surface to the figure
    iTess = AddSurface(hFig, SurfaceFile);
    % 3D MRI: Update Colormap
    if strcmpi(surfaceType, 'Anatomy')
        % Get figure
        [hFig,iFig,iDS] = bst_figures('GetFigure', hFig);
        % Update colormap
        figure_3d('ColormapChangedCallback', iDS, iFig);
    end
    % Reload scouts (only if new surface was added)
    if (iTess > length(TessInfo))
        panel_scout('ReloadScouts', hFig);
    end
end


%% ===== REMOVE SURFACE CALLBACK =====
function ButtonRemoveSurfaceCallback(varargin)
    % Get target figure handle
    hFig = bst_figures('GetCurrentFigure', '3D');
    if isempty(hFig)
        return
    end
    % Get current surface index
    iSurface = getappdata(hFig, 'iSurface');
    if isempty(iSurface)
        return
    end
    % Remove surface
    RemoveSurface(hFig, iSurface);
    % Update "Surfaces" panel
    UpdatePanel();
end


%% ===== SURFACE BUTTON CLICKED CALLBACK =====
function ButtonSurfaceClickedCallback(hObject, event, varargin)
    % Get current 3DViz figure
    hFig = bst_figures('GetCurrentFigure', '3D');
    if isempty(hFig)
        return
    end
    % Get index of the surface associated to this button
    iSurface = str2num(event.getSource.getName());
    % Store current surface index 
    setappdata(hFig, 'iSurface', iSurface);
    % Update surface properties
    UpdateSurfaceProperties();
    % Reload scouts
    panel_scout('ReloadScouts', hFig);
end



%% =================================================================================
%  === EXTERNAL CALLBACKS  =========================================================
%  =================================================================================
%% ===== UPDATE PANEL =====
function UpdatePanel(varargin)
    global GlobalData;
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Surface');
    if isempty(ctrl)
        return
    end
    % If no current 3D figure defined
    [hFig, iFig, iDS] = bst_figures('GetCurrentFigure', '3D');
    if isempty(hFig)
        % Remove surface buttons
        CreateSurfaceList(ctrl.jToolbar, 0);
        % Disable all panel controls
        gui_enable([ctrl.jToolbar, ctrl.jPanelOptions], 0);  
    else
        % Enable Surfaces selection panel
        gui_enable(ctrl.jToolbar, 1);
        % Update surfaces list
        nbSurfaces = CreateSurfaceList(ctrl.jToolbar, hFig);
        % If no surface is available
        if (nbSurfaces <= 0)
            % Disable "Display" and "Options" panel
            gui_enable(ctrl.jPanelOptions, 0);
            % Else : one or more surfaces are available
        else
            % Enable "Display" and "Options" panel
            gui_enable(ctrl.jPanelOptions, 1);
            % Update surface properties
            UpdateSurfaceProperties();
        end
        % Disable the add/remove surface buttons for MRI viewer
        isMriViewer = strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.Type, 'MriViewer');
        gui_enable([ctrl.jButtonSurfAdd, ctrl.jButtonSurfDel], ~isMriViewer);
    end
end

%% ===== CURRENT FREQ CHANGED CALLBACK =====
function CurrentFreqChangedCallback(iDS, iFig) %#ok<DEFNU>
    global GlobalData;
    % Get figure appdata
    hFig = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
    TfInfo = getappdata(hFig, 'Timefreq');
    % If no frequencies in this figure
    if getappdata(hFig, 'isStaticFreq')
        return;
    end
    % If there are some time-frequency recordings in this
    if ~isempty(TfInfo)
        % Update frequency to display
        TfInfo.iFreqs = GlobalData.UserFrequencies.iCurrentFreq;
        setappdata(hFig, 'Timefreq', TfInfo);
        % Update display
        UpdateSurfaceData(hFig);
    end
end


%% ===== DISPATCH FIGURE CALLBACKS =====
function figure_callback(hFig, CallbackName, varargin)
    % Get figure type
    FigureId = getappdata(hFig, 'FigureId');
    % Different figure types
    switch (FigureId.Type)
        case 'MriViewer'
            figure_mri(CallbackName, varargin{:});
        case {'3DViz', 'Topography'}
            figure_3d(CallbackName, varargin{:});
    end
end


%% ===== CURRENT FIGURE CHANGED =====
function CurrentFigureChanged_Callback() %#ok<DEFNU>
    UpdatePanel();
end


%% ===== CREATE SURFACES LIST =====
function nbSurfaces = CreateSurfaceList(jToolbar, hFig)
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.icon.*;

    nbSurfaces = 0;
    % Remove all toolbar surface buttons
    for iComp = 1:jToolbar.getComponentCount()-5
        jToolbar.remove(1);
    end
    % If no figure is specified : return
    if isempty(hFig) || ~ishandle(hFig) || (hFig == 0)
        return;
    end
    % Create a button group for Surfaces and "Add" button
    jButtonGroup = ButtonGroup();
    % Get interface scaling
    InterfaceScaling = bst_get('InterfaceScaling');
    
    % If a figure is defined 
    if ishandle(hFig)
        % Get selected surface index
        iSurface = getappdata(hFig, 'iSurface');
        % Loop on all the available surfaces for this figure
        TessInfo = getappdata(hFig, 'Surface');
        for iSurf = 1:length(TessInfo)
            % Select only one button
            isSelected = (iSurf == iSurface);
            % Get button icon (depends on surface name)
            switch lower(TessInfo(iSurf).Name)
                case 'cortex'
                    iconButton = IconLoader.ICON_SURFACE_CORTEX;
                case 'scalp'
                    iconButton = IconLoader.ICON_SURFACE_SCALP;
                case 'innerskull'
                    iconButton = IconLoader.ICON_SURFACE_INNERSKULL;
                case 'outerskull'
                    iconButton = IconLoader.ICON_SURFACE_OUTERSKULL;
                case 'fibers'
                    iconButton = IconLoader.ICON_FIBERS;
                case 'fem'
                    iconButton = IconLoader.ICON_FEM;
                case 'other'
                    iconButton = IconLoader.ICON_SURFACE;
                case 'anatomy'
                    iconButton = IconLoader.ICON_ANATOMY;
            end
            % Scale icon if needed
            if (InterfaceScaling ~= 100)
                iconButton = IconLoader.scaleIcon(iconButton, InterfaceScaling / 100);
            end
            % Create surface button 
            jButtonSurf = JToggleButton(iconButton, isSelected);
            jButtonSurf.setMaximumSize(java_scaled('dimension', 24,24));
            jButtonSurf.setPreferredSize(java_scaled('dimension', 24,24));
            jButtonSurf.setToolTipText(TessInfo(iSurf).SurfaceFile);
            % Store the surface index as the button Name
            jButtonSurf.setName(sprintf('%d', iSurf));
            % Attach a click callback
            java_setcb(jButtonSurf, 'ActionPerformedCallback', @ButtonSurfaceClickedCallback);
            % Add button to button group
            jButtonGroup.add(jButtonSurf);
            % Add button to toolbar, at the end of the surfaces list
            iButton = jToolbar.getComponentCount() - 4;
            jToolbar.add(jButtonSurf, iButton);
        end
        % Return number of surfaces added
        nbSurfaces = length(TessInfo);
    else
        % No surface available for current figure
        nbSurfaces = 0;
    end
   
    % Update graphical composition of panel
    jToolbar.updateUI();
end


%% ===== UPDATE SURFACE PROPERTIES =====
function UpdateSurfaceProperties()
    % Headless mode: Cancel call
    if (bst_get('GuiLevel') == -1)
        return
    end
    % Get current figure handle
    hFig = bst_figures('GetCurrentFigure', '3D');
    if isempty(hFig)
        return
    end
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Surface');
    if isempty(ctrl)
        return
    end
    % Get selected surface properties
    TessInfo = getappdata(hFig, 'Surface');
    if isempty(TessInfo)
        return;
    end
    % Get selected surface index
    iSurface = getappdata(hFig, 'iSurface');
    if isempty(iSurface) || (iSurface > length(TessInfo))
        return;
    end
    % If surface is sliced MRI
    isAnatomy = strcmpi(TessInfo(iSurface).Name, 'Anatomy');

    % ==== Surface properties ====
    % Number of vertices
    ctrl.jLabelNbVertices.setText(sprintf('%d', TessInfo(iSurface).nVertices));
    % Number of faces
    ctrl.jLabelNbFaces.setText(sprintf('%d', TessInfo(iSurface).nFaces));
    % Surface alpha
    ctrl.jSliderSurfAlpha.setValue(100 * TessInfo(iSurface).SurfAlpha);
    ctrl.jLabelSurfAlpha.setText(sprintf('%d%%', round(100 * TessInfo(iSurface).SurfAlpha)));
    % Surface color
    surfColor = TessInfo(iSurface).AnatomyColor(2, :);
    ctrl.jButtonSurfColor.setBackground(java.awt.Color(surfColor(1),surfColor(2),surfColor(3)));
    % Surface smoothing ALPHA
    ctrl.jSliderSurfSmoothValue.setValue(100 * TessInfo(iSurface).SurfSmoothValue);
    ctrl.jLabelSurfSmoothValue.setText(sprintf('%d%%', round(100 * TessInfo(iSurface).SurfSmoothValue)));
    % Show sulci button
    ctrl.jButtonSurfSulci.setSelected(TessInfo(iSurface).SurfShowSulci);
    % Show surface edges button
    ctrl.jButtonSurfEdge.setSelected(TessInfo(iSurface).SurfShowEdges);
    
    % ==== Resect properties ====
    % Ignore for MRI slices
    if isAnatomy
        sMri = bst_memory('GetMri', TessInfo(iSurface).SurfaceFile);
        if ~isempty(sMri)
            mriSize = size(sMri.Cube(:,:,:,1));
            ResectXYZ = double(TessInfo(iSurface).CutsPosition) ./ mriSize * 200 - 100;
        else
            ResectXYZ = [0,0,0];
        end
        radioSelected = 'none';
    elseif ischar(TessInfo(iSurface).Resect)
        ResectXYZ = [0,0,0];
        radioSelected = TessInfo(iSurface).Resect;
    else
        ResectXYZ = 100 * TessInfo(iSurface).Resect;
        radioSelected = 'none';
    end
    % X, Y, Z
    ctrl.jSliderResectX.setValue(ResectXYZ(1));
    ctrl.jSliderResectY.setValue(ResectXYZ(2));
    ctrl.jSliderResectZ.setValue(ResectXYZ(3));
    
    % Select one radio button
    switch (radioSelected)
        case 'left'
            ctrl.jToggleResectLeft.setSelected(1);
            ctrl.jToggleResectRight.setSelected(0);
            ctrl.jToggleResectStruct.setSelected(0);
        case 'right'
            ctrl.jToggleResectRight.setSelected(1);
            ctrl.jToggleResectLeft.setSelected(0);
            ctrl.jToggleResectStruct.setSelected(0);
        case 'struct'
            ctrl.jToggleResectRight.setSelected(0);
            ctrl.jToggleResectLeft.setSelected(0);
            ctrl.jToggleResectStruct.setSelected(1);
        case 'none'
            ctrl.jToggleResectLeft.setSelected(0);
            ctrl.jToggleResectRight.setSelected(0);
            ctrl.jToggleResectStruct.setSelected(0);
    end
    
    % ==== Data properties ====
    % Enable/disable controls
    isOverlay = ~isempty(TessInfo(iSurface).DataSource.FileName);
    isOverlayStat = isOverlay && ismember(file_gettype(TessInfo(iSurface).DataSource.FileName), {'presults', 'pdata', 'ptimefreq'});
    isOverlayLabel = isOverlay && TessInfo(iSurface).isOverlayAtlas;
    gui_enable([ctrl.jLabelDataAlphaTitle, ctrl.jSliderDataAlpha, ctrl.jLabelDataAlpha], isOverlay, 0);
    gui_enable([ctrl.jLabelSizeTitle, ctrl.jLabelSize, ctrl.jSliderSize], isOverlay && ~isOverlayLabel, 0);
    gui_enable([ctrl.jLabelThreshTitle, ctrl.jSliderDataThresh, ctrl.jLabelDataThresh], isOverlay && ~isOverlayStat && ~isOverlayLabel, 0);
    % Data threshold
    ctrl.jSliderDataThresh.setValue(100 * TessInfo(iSurface).DataThreshold);
    ctrl.jLabelDataThresh.setText(sprintf('%d%%', round(100 * TessInfo(iSurface).DataThreshold)));
    % Size threshold
    sliderSizeVector = GetSliderSizeVector(TessInfo(iSurface).nVertices);
    iSlider = bst_closest(sliderSizeVector, TessInfo(iSurface).SizeThreshold);
    ctrl.jSliderSize.setValue(iSlider);
    ctrl.jLabelSize.setText(sprintf('%d', TessInfo(iSurface).SizeThreshold));
    % Data alpha
    ctrl.jSliderDataAlpha.setValue(100 * TessInfo(iSurface).DataAlpha);
    ctrl.jLabelDataAlpha.setText(sprintf('%d%%', round(100 * TessInfo(iSurface).DataAlpha)));
end


%% ===== ADD A SURFACE =====
% Add a surface to a given 3DViz figure
% USAGE : [iTess, TessInfo] = panel_surface('AddSurface', hFig, surfaceFile)
% OUTPUT: Indice of the surface in the figure's surface array
function [iTess, TessInfo] = AddSurface(hFig, surfaceFile)
    % ===== CHECK EXISTENCE =====
    % Check whether filename is an absolute or relative path
    surfaceFile = file_short(surfaceFile);
    % Get figure appdata (surfaces configuration)
    TessInfo = getappdata(hFig, 'Surface');
    % Check that this surface is not already displayed in 3DViz figure
    iTess = find(file_compare({TessInfo.SurfaceFile}, surfaceFile));
    if ~isempty(iTess)
        disp('BST> This surface is already displayed. Ignoring...');
        return
    end
    % Get figure type
    FigureId = getappdata(hFig, 'FigureId');
    % Progress bar
    isNewProgressBar = ~bst_progress('isVisible');
    bst_progress('start', 'Add surface', 'Updating display...');
    
    % ===== BUILD STRUCTURE =====
    % Add a new surface at the end of the figure's surfaces list
    iTess = length(TessInfo) + 1;
    TessInfo(iTess) = db_template('TessInfo');                       
    % Set the surface properties
    TessInfo(iTess).SurfaceFile = surfaceFile;
    TessInfo(iTess).DataSource.Type     = '';
    TessInfo(iTess).DataSource.FileName = '';

    % ===== PLOT OBJECT =====
    % Get file type (tessalation or MRI)
    fileType = file_gettype(surfaceFile);
    % === TESSELATION ===
    if any(strcmpi(fileType, {'cortex','scalp','innerskull','outerskull','tess'}))
        % === LOAD SURFACE ===
        % Load surface file
        sSurface = bst_memory('LoadSurface', surfaceFile);
        if isempty(sSurface)
            iTess = [];
            return;
        end
        % Get some properties
        TessInfo(iTess).Name      = sSurface.Name;
        TessInfo(iTess).nVertices = size(sSurface.Vertices, 1);
        TessInfo(iTess).nFaces    = size(sSurface.Faces, 1);

        % === PLOT SURFACE ===
        switch (FigureId.Type)
            case 'MriViewer'
                % Nothing to do: surface will be displayed as an overlay slice in figure_mri.m
            case {'3DViz', 'Topography'}
                % Create and display surface patch
                [hFig, TessInfo(iTess).hPatch] = figure_3d('PlotSurface', hFig, ...
                                         sSurface.Faces, ...
                                         sSurface.Vertices, ...
                                         TessInfo(iTess).AnatomyColor(2,:), ...
                                         TessInfo(iTess).SurfAlpha);
        end
        % Update figure's surfaces list and current surface pointer
        setappdata(hFig, 'Surface',  TessInfo);
        % Update surface alpha (for structure atlases only)
        if ismember(sSurface.Atlas(sSurface.iAtlas).Name, {'Structures', 'Source model'})
            figure_3d('UpdateSurfaceAlpha', hFig, iTess);
        end
        % Show sulci map if needed 
        if TessInfo(iTess).SurfShowSulci
            SetShowSulci(hFig, iTess, 1);
        end
        % If displaying the first surface, and it is a cortex: unzoom a bit
        if (iTess == 1)
            if strcmpi(sSurface.Name, 'Cortex')
                zoom(hFig, 0.87);
                zoom reset;
            elseif strcmpi(sSurface.Name, 'Scalp')
                zoom(hFig, 1.1);
                zoom reset;
            end
        end
        
    % === MRI ===
    elseif strcmpi(fileType, 'subjectimage')
        % === LOAD MRI ===
        sMri = bst_memory('LoadMri', surfaceFile);
        if isempty(sMri)
            iTess = [];
            return
        end
        TessInfo(iTess).Name = 'Anatomy';
        % Multiple volumes: set as data source
        if (size(sMri.Cube,4) > 1)
            TessInfo(iTess).DataSource.Type = 'MriTime';
            % TessInfo(iTess).DataSource.FileName = surfaceFile;
            setappdata(hFig, 'isStatic', 0);
        end
        % Initial position of the cuts:
        mriSize = size(sMri.Cube(:,:,:,1));
        % If there is a MNI transformation available: use coordinates (0,0,0)
        mriOrigin = cs_convert(sMri, 'mni', 'voxel', [0 0 0]);
        if ~isempty(mriOrigin) && (any(mriOrigin < 0.25*mriSize) || any(mriOrigin > 0.75*mriSize))
            mriOrigin = [];
        end
        % If there is a vox2ras transformation available: use coordinates (0,0,0)
        if isempty(mriOrigin)
            mriOrigin = cs_convert(sMri, 'world', 'voxel', [0 0 0]);
            if ~isempty(mriOrigin) && (any(mriOrigin < 0.25*mriSize) || any(mriOrigin > 0.75*mriSize))
                mriOrigin = [];
            end
        end
        % Otherwise, if there is a SCS transformation available: use coordinates corresponding to world=(0,0,0) in ICBM152
        if isempty(mriOrigin)
            mriOrigin = cs_convert(sMri, 'scs', 'voxel', [.026, 0, .045]);
            if ~isempty(mriOrigin) && (any(mriOrigin < 0.25*mriSize) || any(mriOrigin > 0.75*mriSize))
                mriOrigin = [];
            end
        end
        % Otherwise, use the middle slice in each direction
        if isempty(mriOrigin)
            mriOrigin = mriSize ./ 2;
        end
        TessInfo(iTess).CutsPosition = round(mriOrigin);
        TessInfo(iTess).SurfSmoothValue = .3;
        % Colormap: depends on the range of values
        TessInfo(iTess).ColormapType = 'anatomy';
        bst_colormaps('AddColormapToFigure', hFig, TessInfo(iTess).ColormapType);
        % Update figure's surfaces list and current surface pointer
        setappdata(hFig, 'Surface',  TessInfo);

        % === PLOT MRI ===
        switch (FigureId.Type)
            case 'MriViewer'             
                % Configure MRIViewer
                figure_mri('SetupMri', hFig);
            case '3DViz'
                % Camera basic orientation: TOP
                figure_3d('SetStandardView', hFig, 'top');
        end
        % Plot MRI
        PlotMri(hFig);
        
    % === FIBERS ===
    elseif strcmpi(fileType, 'fibers')
        % Load fibers
        FibMat = bst_memory('LoadFibers', surfaceFile);
        % Update surface definition
        TessInfo(iTess).Name = 'Fibers';
        TessInfo(iTess).AnatomyColor(:) = 0;   % Special color of 0 for colormap following fiber curvature
        % Update figure's surfaces list and current surface pointer
        setappdata(hFig, 'Surface',  TessInfo);
        % Plot fibers
        isEmptyFigure = getappdata(hFig, 'EmptyFigure');
        if isempty(isEmptyFigure) || ~isEmptyFigure
            switch (FigureId.Type)
                case 'MriViewer'
                    % Nothing to do: surface will be displayed as an overlay slice in figure_mri.m
                case {'3DViz', 'Topography'}
                    % Create and display surface patch
                    [hFig, TessInfo(iTess).hPatch] = figure_3d('PlotFibers', hFig, FibMat.Points, FibMat.Colors);
            end
            % Update figure's surfaces list and current surface pointer
            setappdata(hFig, 'Surface',  TessInfo);
        end
        
    % === FEM ===
    else % TODO: Check for FEM fileType explicitly
        view_surface_fem(surfaceFile, [], [], [], hFig);
    end
    % Update default surface
    setappdata(hFig, 'iSurface', iTess);
    % Automatically set transparencies (to view different layers at the same time)
    SetAutoTransparency(hFig);
    % Close progress bar
    drawnow;
    if isNewProgressBar
        bst_progress('stop');
    end
    % Update panel
    UpdatePanel();
end
   


%% ===== SET DATA SOURCE FOR A SURFACE =====
%Associate a data/results matrix to a surface.
% Usage : SetSurfaceData(hFig, iTess, dataType, dataFile, isStat)
% Parameters : 
%     - hFig : handle to a 3DViz figure
%     - iTess        : indice of the surface to update (in hFig appdata)
%     - dataType     : type of data to overlay on the surface {'Source', 'Data', ...}
%     - dataFile     : filename of the data to display over the surface
%     - isStat       : 1, if results is a statistical result; 0, else
function [isOk, TessInfo] = SetSurfaceData(hFig, iTess, dataType, dataFile, isStat) %#ok<DEFNU>
    global GlobalData;
    % Get figure index in DataSet figures list
    [tmp__, iFig, iDS] = bst_figures('GetFigure', hFig);
    if isempty(iDS)
        error('No DataSet acessible for this 3D figure');
    end
    % Get surfaces list for this figure
    TessInfo = getappdata(hFig, 'Surface');
    isAnatomy = strcmpi(TessInfo(iTess).Name, 'Anatomy');
    
    % === GET DATA THRESHOLD ===
    % Get defaults for surface display
    DefaultSurfaceDisplay = bst_get('DefaultSurfaceDisplay');
    % Cortex
    if ~isStat
        % Data/size threshold
        dataThreshold = DefaultSurfaceDisplay.DataThreshold;
        if isAnatomy
            sizeThreshold = 1;
        else
            sizeThreshold = DefaultSurfaceDisplay.SizeThreshold;
        end
    % Anatomy or Statistics : 0%
    elseif isAnatomy || isStat
        dataThreshold = 0;
        sizeThreshold = 1;
    % Else: normal data on scalp
    else
        dataThreshold = 0.5;
        sizeThreshold = 1;
    end
    % Static figure
    setappdata(hFig, 'isStatic', isempty(GlobalData.DataSet(iDS).Measures.NumberOfSamples) || (GlobalData.DataSet(iDS).Measures.NumberOfSamples <= 2));
    
    % === PREPARE SURFACE ===
    TessInfo(iTess).DataSource.Type     = dataType;
    TessInfo(iTess).DataSource.FileName = dataFile;
    TessInfo(iTess).DataThreshold       = dataThreshold;
    TessInfo(iTess).SizeThreshold       = sizeThreshold;
    TessInfo(iTess).DataAlpha           = DefaultSurfaceDisplay.DataAlpha;
    % Type of data displayed on the surface: sources/recordings/nothing
    switch (dataType)
        case 'Data'
            % Get loaded data
            iDS = bst_memory('GetDataSetData', dataFile);
            % Select appropriate colormap
            if ~isempty(GlobalData.DataSet(iDS).Measures.ColormapType)
                ColormapType = GlobalData.DataSet(iDS).Measures.Colormap;
            elseif isStat
                ColormapType = 'stat2';
            else
                ColormapType = 'eeg';
            end
            setappdata(hFig, 'DataFile', dataFile);
            % Display units
            DisplayUnits = GlobalData.DataSet(iDS).Measures.DisplayUnits;
            
        case 'Source'
            % Get loaded results
            [iDS, iRes] = bst_memory('GetDataSetResult', dataFile);
            % Select appropriate colormap
            if ~isempty(GlobalData.DataSet(iDS).Results(iRes).ColormapType)
                ColormapType = GlobalData.DataSet(iDS).Results(iRes).ColormapType;
            elseif isStat
                ColormapType = 'stat1';
            else
                ColormapType = 'source';
            end
            % Copy the surface atlas
            TessInfo(iTess).DataSource.Atlas     = GlobalData.DataSet(iDS).Results(iRes).Atlas;
            TessInfo(iTess).DataSource.GridAtlas = GlobalData.DataSet(iDS).Results(iRes).GridAtlas;
            TessInfo(iTess).DataSource.GridLoc   = GlobalData.DataSet(iDS).Results(iRes).GridLoc;
            setappdata(hFig, 'ResultsFile', dataFile);
            % Display units
            DisplayUnits = GlobalData.DataSet(iDS).Results(iRes).DisplayUnits;
            
        case 'Dipoles'
            ColormapType = 'source';
            panel_dipoles('AddDipoles', hFig, dataFile, 0);
            DisplayUnits = [];
            
        case 'Timefreq'
            % Get study
            [sStudy, iStudy, iTf, DataType, sTimefreq] = bst_get('AnyFile', dataFile);
            if isempty(sStudy)
                error('File is not registered in database.');
            end
            % Get loaded time-freq structure
            [iDS, iTimefreq] = bst_memory('LoadTimefreqFile', sTimefreq.FileName);
             % Set "Static" status for this figure
            setappdata(hFig, 'isStatic', (GlobalData.DataSet(iDS).Timefreq(iTimefreq).NumberOfSamples <= 2));
            isStaticFreq = (size(GlobalData.DataSet(iDS).Timefreq(iTimefreq).TF,3) <= 1);
            setappdata(hFig, 'isStaticFreq', isStaticFreq);

            % Create options structure
            TfInfo = db_template('TfInfo');
            TfInfo.FileName = sTimefreq.FileName;
            TfInfo.Comment  = sTimefreq.Comment;
            % Select channels
            if strcmpi(GlobalData.DataSet(iDS).Timefreq(iTimefreq).DataType, 'data')
                % Get all the channels allowed in the current figure
                TfInfo.RowName = {GlobalData.DataSet(iDS).Channel(GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels).Name};
                % Remove the channels for which the TF was not computed
                iMissing = find(~ismember(TfInfo.RowName, GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames));
                if ~isempty(iMissing)
                    TfInfo.RowName(iMissing) = [];
                    GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels(iMissing) = [];
                end
            else
                TfInfo.RowName = [];
            end
            % Selected frequencies
            if isStaticFreq
                TfInfo.iFreqs = [];
            elseif ~isempty(GlobalData.UserFrequencies.iCurrentFreq)
                TfInfo.iFreqs = GlobalData.UserFrequencies.iCurrentFreq;
            else
                TfInfo.iFreqs = 1;
            end
            % Data type
            [TfInfo.Function, ColormapType] = process_tf_measure('GetDefaultFunction', GlobalData.DataSet(iDS).Timefreq(iTimefreq));
            % If displaying an editable function: try to use the one already selected in the interface
            if ismember(TfInfo.Function, {'power', 'magnitude'})
                % Try to get the current display options
                sOptions = panel_display('GetDisplayOptions');
                % If there is already something loaded and selected: use it
                if ~isempty(sOptions) && ~isempty(sOptions.Function) && ~strcmpi(sOptions.Function, TfInfo.Function)
                    TfInfo.Function = sOptions.Function;
                end
            end
            % Display units
            DisplayUnits = GlobalData.DataSet(iDS).Timefreq(iTimefreq).DisplayUnits;
            % Set figure data
            setappdata(hFig, 'Timefreq', TfInfo);
            % Display options panel
            isDisplayTab = ~strcmpi(TfInfo.Function, 'other');
            if isDisplayTab
                gui_brainstorm('ShowToolTab', 'Display');
            end
            % Get atlas if it is a source file
            if strcmpi(GlobalData.DataSet(iDS).Timefreq(iTimefreq).DataType, 'results') && ~isempty(GlobalData.DataSet(iDS).Timefreq(iTimefreq).DataFile)
                % Get results index
                iResult = bst_memory('GetResultInDataSet', iDS, GlobalData.DataSet(iDS).Timefreq(iTimefreq).DataFile);
                % Get atlas
                if ~isempty(iResult)
                    TessInfo(iTess).DataSource.Atlas = GlobalData.DataSet(iDS).Results(iResult).Atlas;
                end
            end
            % Get grids 
            TessInfo(iTess).DataSource.GridAtlas = GlobalData.DataSet(iDS).Timefreq(iTimefreq).GridAtlas;
            TessInfo(iTess).DataSource.GridLoc   = GlobalData.DataSet(iDS).Timefreq(iTimefreq).GridLoc;
            TessInfo(iTess).DataSource.Atlas     = GlobalData.DataSet(iDS).Timefreq(iTimefreq).Atlas;

        case 'Surface'
            ColormapType = 'overlay';
            DisplayUnits = [];
            
        case 'Anatomy'
            % Load overlay volume, just to get the type of file (labels vs. intensity)
            sMriOverlay = bst_memory('LoadMri', TessInfo(iTess).DataSource.FileName);
            % Labels
            if ~isempty(sMriOverlay.Labels) && (size(sMriOverlay.Labels,2) >= 3)
                ColormapType = '';
                DisplayUnits = [];
            % Intensity
            else
                ColormapType = 'source';
                DisplayUnits = [];
            end

        case 'HeadModel'
            setappdata(hFig, 'HeadModelFile', dataFile);
            ColormapType = 'source';
            DisplayUnits = [];
            TessInfo(iTess).Data = [];
            TessInfo(iTess).DataWmat = [];

        otherwise
            ColormapType = '';
            DisplayUnits = [];
            TessInfo(iTess).Data = [];
            TessInfo(iTess).DataWmat = [];
    end
    % Grid smoothing: enable by default, except for time units
    if isAnatomy
        TessInfo(iTess).DataSource.GridSmooth = isempty(DisplayUnits) || ~ismember(DisplayUnits, {'s','ms','t'});
    end
    % Add colormap of the surface to the figure
    if ~isempty(ColormapType)
        TessInfo(iTess).ColormapType = ColormapType;
        bst_colormaps('AddColormapToFigure', hFig, ColormapType, DisplayUnits);
    end
    % If the display units are in time: do not threshold the surface by default
    if isequal(DisplayUnits, 's')
        TessInfo(iTess).DataThreshold = 0;
    end
    % Update figure appdata
    setappdata(hFig, 'Surface', TessInfo);
    % Plot surface
    if strcmpi(dataType, 'HeadModel')
        isOk = 1;
    else
        [isOk, TessInfo] = UpdateSurfaceData(hFig, iTess);
    end
    % Update  panel
    UpdatePanel();
end


%% ===== REMOVE DATA SOURCE FOR A SURFACE =====
function TessInfo = RemoveSurfaceData(hFig, iTess)
    % Get surfaces list for this figure
    TessInfo = getappdata(hFig, 'Surface');
    % Remove overlay
    TessInfo(iTess).DataSource.Type     = [];
    TessInfo(iTess).DataSource.FileName = [];
    TessInfo(iTess).Data        = [];
    TessInfo(iTess).DataMinMax  = [];
    TessInfo(iTess).DataWmat    = [];
    TessInfo(iTess).OverlayCube = [];
    % Update figure appdata
    setappdata(hFig, 'Surface', TessInfo);
    % Update colormap
    UpdateSurfaceColormap(hFig, iTess);
end


%% ===== UPDATE SURFACE DATA =====
% Update the 'Data' field for given surfaces :
%    - Load data/results matrix (F, ImageGridAmp, ...) if it is not loaded yet
%    - Store global minimum/maximum of data
%    - Interpolate data matrix over the target surface if number of vertices does not match
%    - And update color display (ColormapChangedCallback)
%
% Usage:  UpdateSurfaceData(hFig, iSurfaces)
%         UpdateSurfaceData(hFig)
function [isOk, TessInfo] = UpdateSurfaceData(hFig, iSurfaces)
    global GlobalData;
    isOk = 1;
    % Get surfaces list 
    TessInfo = getappdata(hFig, 'Surface');
    % If the aim is to update all the surfaces 
    if (nargin < 2) || isempty(iSurfaces)
        iSurfaces = find(~cellfun(@(c)isempty(c.Type), {TessInfo.DataSource}));
        if isempty(iSurfaces)
            return
        end
    end
        
    % Get figure index (in DataSet structure)
    [tmp__, iFig, iDS] = bst_figures('GetFigure', hFig);
    % Find the DataSet indice that corresponds to the current figure
    if isempty(iDS)
        error('No DataSet acessible for this 3D figure');
    end
    
    % For each surface
    for i = 1:length(iSurfaces)
        iTess = iSurfaces(i);
        % If surface patch object doesn't exist => error
        if isempty(TessInfo(iTess).hPatch)
            error('Patch is not displayed');
        end
        
        % ===== GET SURFACE DATA =====
        % Switch between different data types to display on the surface
        switch (TessInfo(iTess).DataSource.Type)
            case 'Data'
                % Get TimeVector and current time indice
                [TimeVector, CurrentTimeIndex] = bst_memory('GetTimeVector', iDS);
                % Get selected channels indices and location
                selChan = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels;
                % Set data for current time frame
                TessInfo(iTess).Data = GlobalData.DataSet(iDS).Measures.F(selChan, CurrentTimeIndex);
                % Overlay on MRI: Reset Overlay cube
                if strcmpi(TessInfo(iTess).Name, 'Anatomy')
                    TessInfo(iTess).OverlayCube = [];
                    % Compute min-max, if not calculated yet for the figure
                    if isempty(TessInfo(iTess).DataMinMax)
                        TessInfo(iTess).DataMinMax = [min(GlobalData.DataSet(iDS).Measures.F(:)), max(GlobalData.DataSet(iDS).Measures.F(:))];
                    end
                % Compute interpolation sensors => surface vertices
                else
                    TessInfo(iTess) = ComputeScalpInterpolation(iDS, iFig, TessInfo(iTess));
                end
                % Update "Static" status for this figure
                setappdata(hFig, 'isStatic', isempty(GlobalData.DataSet(iDS).Measures.NumberOfSamples) || (GlobalData.DataSet(iDS).Measures.NumberOfSamples <= 2));

            case 'Source'
                % === LOAD RESULTS VALUES ===
                % Get results index
                iResult = bst_memory('GetResultInDataSet', iDS, TessInfo(iTess).DataSource.FileName);
                % If Results file is not found in GlobalData structure
                if isempty(iResult)
                    % Check whether the figure is showing a leadfield
                    if strcmp(file_gettype(TessInfo(iTess).DataSource.FileName), 'headmodel')
                        UpdateCallback = getappdata(hFig, 'UpdateCallback');
                        if ~isempty(UpdateCallback)
                            UpdateCallback();
                        end
                    else
                        isOk = 0;
                    end
                    return
                end
                % If data matrix is not loaded for this file
                if isempty(GlobalData.DataSet(iDS).Results(iResult).ImageGridAmp) && isempty(GlobalData.DataSet(iDS).Results(iResult).ImagingKernel)
                    bst_memory('LoadResultsMatrix', iDS, iResult);
                end
                
                % === GET CURRENT VALUES ===
                % Get results values
                TessInfo(iTess).Data = bst_memory('GetResultsValues', iDS, iResult, [], 'CurrentTimeIndex');
                if isempty(TessInfo(iTess).Data)
                    isOk = 0;
                    return;
                end
                
                % === STAT CLUSTERS ===
                % Show stat clusters
                if strcmpi(file_gettype(TessInfo(iTess).DataSource.FileName), 'presults')
                    % Get TimeVector and current time indice
                    [TimeVector, iTime] = bst_memory('GetTimeVector', iDS);
                    % Get displayed clusters
                    sClusters = panel_stat('GetDisplayedClusters', hFig);
                    % Replace values with clusters
                    if ~isempty(sClusters)
                        mask = 0 * TessInfo(iTess).Data;
                        % Plot each cluster
                        for iClust = 1:length(sClusters)
                            mask = mask | sClusters(iClust).mask(:, iTime, :);
                        end
                        TessInfo(iTess).Data(~mask) = 0;
                    end
                    
                    % Add Stat threshold if available
                    if isfield(GlobalData.DataSet(iDS).Results(iResult), 'StatThreshOver')
                        TessInfo(iTess).StatThreshOver = GlobalData.DataSet(iDS).Results(iResult).StatThreshOver;
                        TessInfo(iTess).StatThreshUnder = GlobalData.DataSet(iDS).Results(iResult).StatThreshUnder;
                    end
                end

                % === CHECKS ===
                % If min/max values for this file were not computed yet
                if isempty(TessInfo(iTess).DataMinMax)
                    if isequal(GlobalData.DataSet(iDS).Results(iResult).ColormapType, 'time')
                        TessInfo(iTess).DataMinMax = GlobalData.DataSet(iDS).Results(iResult).Time;
                    else
                        TessInfo(iTess).DataMinMax = bst_memory('GetResultsMaximum', iDS, iResult);
                    end
                end
                % Reset Overlay cube
                TessInfo(iTess).OverlayCube = [];
                % Check the consistency between the number of results points (number of sources)
                % and the number of vertices of the target surface patch (IGNORE TEST FOR MRI)
                if strcmpi(TessInfo(iTess).Name, 'Anatomy')
                    % Nothing to check right now
                elseif ~isempty(TessInfo(iTess).DataSource.Atlas) && ~isempty(TessInfo(iTess).DataSource.Atlas.Scouts)
                    if (size(TessInfo(iTess).Data, 1) ~= length(TessInfo(iTess).DataSource.Atlas.Scouts))
                        bst_error(sprintf(['Number of sources (%d) is different from number of scouts (%d).\n\n' ...
                                  'Please compute the sources again.'], size(TessInfo(iTess).Data, 1), TessInfo(iTess).DataSource.Atlas.Scouts), 'Data mismatch', 0);
                        isOk = 0;
                        return;
                    end
                elseif strcmpi(GlobalData.DataSet(iDS).Results(iResult).HeadModelType, 'surface') && (size(TessInfo(iTess).Data, 1) ~= TessInfo(iTess).nVertices)
                    bst_error(sprintf(['Number of sources (%d) is different from number of vertices (%d).\n\n' ...
                              'Please compute the sources again.'], size(TessInfo(iTess).Data, 1), TessInfo(iTess).nVertices), 'Data mismatch', 0);
                    isOk = 0;
                    return;
                end
                % Update "Static" status for this figure
                setappdata(hFig, 'isStatic', (GlobalData.DataSet(iDS).Results(iResult).NumberOfSamples <= 2));
                
                % === OPTICAL FLOW ===
                if ~isempty(GlobalData.DataSet(iDS).Results(iResult).OpticalFlow)
                    sSurf = bst_memory('LoadSurface', TessInfo(iTess).SurfaceFile);
                    panel_opticalflow('PlotOpticalFlow', hFig, GlobalData.DataSet(iDS).Results(iResult).OpticalFlow, ...
                                      GlobalData.UserTimeWindow.CurrentTime, sSurf); 
                end

            case 'Timefreq'
                % === LOAD TIMEFRQ VALUES ===
                % Get results index
                iTimefreq = bst_memory('GetTimefreqInDataSet', iDS, TessInfo(iTess).DataSource.FileName);
                % If Results file is not found in GlobalData structure
                if isempty(iTimefreq)
                    isOk = 0;
                    return
                end
                
                % === GET CURRENT VALUES ===
                % Get figure properties
                TfInfo = getappdata(hFig, 'Timefreq');
                if isequal(TfInfo.FOOOFDisp,'overlay') || isequal(TfInfo.FOOOFDisp,'spectrum')
                    FooofDisp = 'spectrum';
                else 
                    FooofDisp = TfInfo.FOOOFDisp;
                end
                % Get results values
                TessInfo(iTess).Data = bst_memory('GetTimefreqValues', iDS, iTimefreq, TfInfo.RowName, TfInfo.iFreqs, 'CurrentTimeIndex', TfInfo.Function, TfInfo.RefRowName, FooofDisp);
                % Get only the first time point
                if size(TessInfo(iTess).Data,2) > 1
                    TessInfo(iTess).Data = TessInfo(iTess).Data(:,1);
                end
                % If min/max values for this file were not computed yet
                if isempty(TessInfo(iTess).DataMinMax)
                    TessInfo(iTess).DataMinMax = bst_memory('GetTimefreqMaximum', iDS, iTimefreq, TfInfo.Function);
                end
                % Reset Overlay cube
                TessInfo(iTess).OverlayCube = [];
                % Get associated results
                switch (GlobalData.DataSet(iDS).Timefreq(iTimefreq).DataType)
                    case 'data'
                        % Overlay on MRI: Reset Overlay cube
                        if strcmpi(TessInfo(iTess).Name, 'Anatomy')
                            TessInfo(iTess).OverlayCube = [];
                        % Compute interpolation sensors => surface vertices
                        else
                            TessInfo(iTess) = ComputeScalpInterpolation(iDS, iFig, TessInfo(iTess));
                        end
                        nVertices = TessInfo(iTess).nVertices;
                    case 'results'
                        nVertices = max(numel(GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames), numel(GlobalData.DataSet(iDS).Timefreq(iTimefreq).RefRowNames));
                    otherwise
                        nVertices = TessInfo(iTess).nVertices;
                end

                % === STAT CLUSTERS ===
                % Show stat clusters
                if strcmpi(file_gettype(TessInfo(iTess).DataSource.FileName), 'ptimefreq')
                    % Get TimeVector and current time indice
                    [TimeVector, iTime] = bst_memory('GetTimeVector', iDS);
                    % Get displayed clusters
                    sClusters = panel_stat('GetDisplayedClusters', hFig);
                    % Replace values with clusters
                    if ~isempty(sClusters)
                        mask = 0 * TessInfo(iTess).Data;
                        % If displaying the second of a replicated time point, which is not available in the clusters mask: ignore the time information
                        if (length(iTime) == 1) && (iTime == 2) && (size(sClusters(1).mask,2) == 1)
                            iTime = 1;
                        end
                        % Plot each cluster
                        for iClust = 1:length(sClusters)
                            mask = mask | sClusters(iClust).mask(:, iTime, GlobalData.UserFrequencies.iCurrentFreq);
                        end
                        TessInfo(iTess).Data(~mask) = 0;
                    end
                end
                
                % === CHECKS ===
                % Check the consistency between the number of results points (number of sources)
                % and the number of vertices of the target surface patch (IGNORE TEST FOR MRI)
                if strcmpi(TessInfo(iTess).Name, 'Anatomy')
                    % Nothing to check right now
                elseif ~isempty(TessInfo(iTess).DataSource.Atlas) && ~isempty(TessInfo(iTess).DataSource.Atlas.Scouts)
                    if (size(TessInfo(iTess).Data, 1) ~= length(TessInfo(iTess).DataSource.Atlas.Scouts))
                        bst_error(sprintf(['Number of sources (%d) is different from number of scouts (%d).\n\n' ...
                                  'Please compute the sources again.'], size(TessInfo(iTess).Data, 1), length(TessInfo(iTess).DataSource.Atlas.Scouts)), 'Data mismatch', 0);
                        isOk = 0;
                        return;
                    end
                elseif (size(TessInfo(iTess).Data, 1) ~= nVertices) && ~strcmpi(TessInfo(iTess).Name, 'Anatomy')
                    bst_error(sprintf(['Number of sources (%d) is different from number of vertices (%d).\n\n' ...
                              'Please compute the sources again.'], size(TessInfo(iTess).Data, 1), nVertices), 'Data mismatch', 0);
                    isOk = 0;
                    return;
                end
                % Update "Static" status for this figure
                setappdata(hFig, 'isStatic',     (GlobalData.DataSet(iDS).Timefreq(iTimefreq).NumberOfSamples <= 2));
                setappdata(hFig, 'isStaticFreq', (size(GlobalData.DataSet(iDS).Timefreq(iTimefreq).TF,3) <= 1));
                
            case 'Dipoles'
                % === LOAD DIPOLES VALUES ===
                % Get results index
                iDipoles = bst_memory('GetDipolesInDataSet', iDS, TessInfo(iTess).DataSource.FileName);
                % If Results file is not found in GlobalData structure
                if isempty(iDipoles)
                    % Load Results file
                    [iDS, iDipoles] = bst_memory('LoadDipolesFile', TessInfo(iTess).DataSource.FileName);
                    if isempty(iDipoles)
                        return
                    end
                end
                % === GET CURRENT VALUES ===
                % Get results values
                % TessInfo(iTess).Data = bst_memory('GetDipolesValues', iDS, iDipoles, 'CurrentTimeIndex');
                % If min/max values for this file were not computed yet
                if isempty(TessInfo(iTess).DataMinMax)
                    TessInfo(iTess).DataMinMax = [0 100];
                end
                % Reset Overlay cube
                TessInfo(iTess).OverlayCube = [];
                % Update "Static" status for this figure
                setappdata(hFig, 'isStatic', (GlobalData.DataSet(iDS).Dipoles(iDipoles).NumberOfSamples <= 2));
                
            case 'Surface'
                % Get loaded surface
                SurfaceFile = TessInfo(iTess).DataSource.FileName;
                sSurf = bst_memory('LoadSurface', SurfaceFile);
                % Build uniform data vector
                TessInfo(iTess).Data = ones(length(sSurf.Vertices),1);
                TessInfo(iTess).DataMinMax = [.5 .5];
                setappdata(hFig, 'isStatic', 1);
                
            case 'Anatomy'
                % Get overlay MRI
                MriFile = TessInfo(iTess).DataSource.FileName;
                sMriOverlay = bst_memory('LoadMri', MriFile);
                % Get base MRI
                sMri = bst_memory('GetMri', TessInfo(iTess).SurfaceFile);
                % Check the MRI dimensions
                if ~isequal(size(sMriOverlay.Cube(:,:,:,1)), size(sMri.Cube(:,:,:,1)))
                    bst_error('The dimensions of the two volumes do not match.', 'Data mismatch', 0);
                    isOk = 0;
                    return;
                elseif all(abs(sMriOverlay.Voxsize - sMri.Voxsize) > 0.1)
                    bst_error('The resolution of the two volumes do not match. Resample the overlay first.', 'Data mismatch', 0);
                    isOk = 0;
                    return;
                end
                % Get index for 4th dimension ("time")
                if ~isempty(GlobalData.UserTimeWindow.NumberOfSamples) && (size(sMriOverlay.Cube, 4) == GlobalData.UserTimeWindow.NumberOfSamples) && (GlobalData.UserTimeWindow.CurrentTime == round(GlobalData.UserTimeWindow.CurrentTime))
                    i4 = GlobalData.UserTimeWindow.CurrentTime;
                    sMriOverlay.Cube = sMriOverlay.Cube(:,:,:,i4);
                    % Update "Static" status for this figure
                    setappdata(hFig, 'isStatic', 0);
                end
                % If labels are available: convert volume to an RGB cube (0-255)
                if ~isempty(sMriOverlay.Labels) && (size(sMriOverlay.Labels,2) >= 3)
                    % Labels = {value,name,color}
                    labelInd = cat(1, sMriOverlay.Labels{:,1});
                    labelRGB = cat(1, sMriOverlay.Labels{:,3});
                    % Saturate volume values above the size of the labels table
                    sMriOverlay.Cube(sMriOverlay.Cube > max(labelInd)) = 0;
                    % Build a colormap with all the labels
                    colormapLabels = zeros(max(labelInd) + 1, 3);     % Starting from 1 instead of zero
                    colormapLabels(labelInd + 1,:) = labelRGB;
                    % Assemble RGB volume
                    TessInfo(iTess).OverlayCube = uint8(cat(4, ...
                        reshape(colormapLabels(sMriOverlay.Cube + 1, 1), size(sMriOverlay.Cube)), ...
                        reshape(colormapLabels(sMriOverlay.Cube + 1, 2), size(sMriOverlay.Cube)), ...
                        reshape(colormapLabels(sMriOverlay.Cube + 1, 3), size(sMriOverlay.Cube))));
                    % Save label information
                    TessInfo(iTess).OverlayCubeLabels = sMriOverlay.Cube;
                    TessInfo(iTess).OverlayLabels = sMriOverlay.Labels;
                    TessInfo(iTess).isOverlayAtlas = 1;
                    TessInfo(iTess).DataMinMax = [0,255];
                % Otherwise: the volume contains intensity values, that will be displayed using a colormap
                else
                    TessInfo(iTess).DataMinMax = double([min(sMriOverlay.Cube(:)), max(sMriOverlay.Cube(:))]);
                    TessInfo(iTess).OverlayCube = double(sMriOverlay.Cube);
                end
                
            case 'MriTime'
                % Update MRI volume
                figure_callback(hFig, 'UpdateSurfaceColor', hFig, iTess);
                % Get updated surface definition
                TessInfo = getappdata(hFig, 'Surface');
            otherwise
                % Nothing to do
        end
        % Error if all data values are null
        if (max(abs(TessInfo(iTess).DataMinMax)) == 0)
            disp('BST> All values are null. Please check your input file.');
        end
    end
    % Update surface definition
    setappdata(hFig, 'Surface', TessInfo);
    % Update colormap
    UpdateSurfaceColormap(hFig, iSurfaces);
end


%% ===== COMPUTE SCALP INTERPOLATION =====
function TessInfo = ComputeScalpInterpolation(iDS, iFig, TessInfo)
    global GlobalData;
    % If surface is not displayed: exit
    if isempty(TessInfo.hPatch) || ~ishandle(TessInfo.hPatch)
        return;
    end
    % Get vertices of surface
    Vertices = get(TessInfo.hPatch, 'Vertices');
    % Get selected channels indices and location
    selChan = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels;
    % Get sensors positions
    chan_loc = figure_3d('GetChannelPositions', iDS, selChan);
    % Interpolate data on scalp surface (only if Matrix is not computed yet, or channels changed)
    if isempty(TessInfo.DataWmat) || ...
            (size(TessInfo.DataWmat,2) ~= length(selChan)) || ...
            (size(TessInfo.DataWmat,1) ~= length(Vertices))
        % EEG: Use smoothed display, as in 2D/3D topography
        if strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.Modality, 'EEG')
            TopoInfo.UseSmoothing = 1;
            TopoInfo.Modality = GlobalData.DataSet(iDS).Figure(iFig).Id.Modality;
            Faces = get(TessInfo.hPatch, 'Faces');
            [bfs_center, bfs_radius] = bst_bfs(Vertices);
            TessInfo.DataWmat = figure_topo('GetInterpolation', iDS, iFig, TopoInfo, Vertices, Faces, bfs_center, bfs_radius, chan_loc);
        else
            switch (GlobalData.DataSet(iDS).Figure(iFig).Id.Modality)
                case 'EEG',       excludeParam = bst_get('ElecInterpDist', 'EEG');   % Should never reach this statement, already taken care of above
                case 'ECOG',      excludeParam = -bst_get('ElecInterpDist', 'ECOG');
                case 'SEEG',      excludeParam = -bst_get('ElecInterpDist', 'SEEG');
                case 'ECOG+SEEG', excludeParam = -bst_get('ElecInterpDist', 'ECOG+SEEG');
                case 'MEG',       excludeParam = bst_get('ElecInterpDist', 'MEG');
                otherwise,        excludeParam = 0;
            end
            nbNeigh = 4;
            TessInfo.DataWmat = bst_shepards(Vertices, chan_loc, nbNeigh, excludeParam);
        end
    end
    % Set data for current time frame
    TessInfo.Data = TessInfo.DataWmat * TessInfo.Data;
    % Store minimum and maximum of displayed data
    TessInfo.DataMinMax = [min(TessInfo.Data(:)),  max(TessInfo.Data(:))];
end


%% ===== UPDATE SURFACE COLORMAP =====
function UpdateSurfaceColormap(hFig, iSurfaces)
    % Get surfaces list 
    TessInfo = getappdata(hFig, 'Surface');
    if isempty(TessInfo)
        return
    end
    % If the aim is to update all the surfaces 
    if (nargin < 2) || isempty(iSurfaces)
        iSurfaces = 1:length(TessInfo);
    end
    
    % Get default colormap to use for this figure
    ColormapInfo = getappdata(hFig, 'Colormap');
    % Get figure axes
    hAxes = [findobj(hFig, '-depth', 1, 'Tag', 'Axes3D'), ...
             findobj(hFig, '-depth', 1, 'Tag', 'axc'), ...
             findobj(hFig, '-depth', 1, 'Tag', 'axa'), ...
             findobj(hFig, '-depth', 1, 'Tag', 'axs')];
    
    % Get figure index (in DataSet structure)
    [tmp__, iFig, iDS] = bst_figures('GetFigure', hFig);
    % Find the DataSet indice that corresponds to the current figure
    if isempty(iDS)
        error('No DataSet acessible for this 3D figure');
    end
    DataType = [];
    
    % ===== CREATE COLORBAR =====
    if ~isempty(ColormapInfo.Type)
        % Get figure colormap
        sColormap = bst_colormaps('GetColormap', ColormapInfo.Type);
        % Set figure colormap
        set(hFig, 'Colormap', sColormap.CMap);
        % Create/Delete colorbar
        bst_colormaps('SetColorbarVisible', hFig, sColormap.DisplayColorbar);
    % No colorbar should be displayed in this figure
    else
        % Delete colorbar
        bst_colormaps('SetColorbarVisible', hFig, 0);
    end
    
    % ===== UPDATE SURFACES =====
    for i = 1:length(iSurfaces)
        iTess = iSurfaces(i);
        % If surface has no colormapped data to update, skip
        if strcmpi(TessInfo(iTess).DataSource.Type, 'HeadModel')
            continue;
        end
        % === COLORMAPPING ===
        % Get colormap
        sColormap = bst_colormaps('GetColormap', TessInfo(iTess).ColormapType);
        % Dipoles density: only percentage
        if strcmpi(TessInfo(iTess).DataSource.Type, 'Dipoles')
            TessInfo(iTess).DataLimitValue = [0 100];
        % Regular values: use the definition of maximum for the colormap
        else
            TessInfo(iTess).DataLimitValue = bst_colormaps('GetMinMax', sColormap, TessInfo(iTess).Data, TessInfo(iTess).DataMinMax);
        end
        % Apply absolute value
        if sColormap.isAbsoluteValues
            TessInfo(iTess).Data = abs(TessInfo(iTess).Data);
        end
        % If current colormap is the default colormap for this figure (for colorbar)
        if strcmpi(ColormapInfo.Type, TessInfo(iTess).ColormapType) && ~isempty(TessInfo(iTess).DataSource.FileName)
            if all(~isnan(TessInfo(iTess).DataLimitValue)) && (TessInfo(iTess).DataLimitValue(1) < TessInfo(iTess).DataLimitValue(2))
                set(hAxes, 'CLim', TessInfo(iTess).DataLimitValue);
            else
                set(hAxes, 'CLim', [0 1e-30]);
            end
            DataType = TessInfo(iTess).DataSource.Type;
            % For Data: use the modality instead
            if strcmpi(DataType, 'Data') && ~isempty(ColormapInfo.Type) && ismember(ColormapInfo.Type, {'eeg', 'meg', 'nirs'})
                DataType = upper(ColormapInfo.Type);
            % sLORETA: Do not use regular source scaling (pAm)
            elseif strcmpi(DataType, 'Source') && ~isempty(strfind(lower(TessInfo(iTess).DataSource.FileName), 'sloreta'))
                DataType = 'sLORETA';
            end
        end     
        % === DISPLAY ON MRI ===
        if strcmpi(TessInfo(iTess).Name, 'Anatomy') && ~isempty(TessInfo(iTess).DataSource.Type) && ~strcmpi(TessInfo(iTess).DataSource.Type, 'MriTime') && isempty(TessInfo(iTess).OverlayCube)
            % Progress bar
            isProgressBar = bst_progress('isVisible');
            bst_progress('start', 'Display MRI', 'Updating values...');
            % Update figure's appdata (surface list)
            setappdata(hFig, 'Surface', TessInfo);
            % Update OverlayCube
            TessInfo = UpdateOverlayCube(hFig, iTess);
            % Hide progress bar
            if ~isProgressBar
                bst_progress('stop');
            end
        else
            % Update figure's appdata (surface list)
            setappdata(hFig, 'Surface', TessInfo);
            % Update surface color
            figure_callback(hFig, 'UpdateSurfaceColor', hFig, iTess);
        end
    end
    
    % ===== CONFIGURE COLORBAR =====
    % Display only one colorbar (preferentially the results colorbar)
    if ~isempty(ColormapInfo.Type)
        bst_colormaps('ConfigureColorbar', hFig, ColormapInfo.Type, DataType, ColormapInfo.DisplayUnits);
    end
end


%% ===== GET SURFACE =====
% Find a surface in a given 3DViz figure
% Usage:  [iTess, TessInfo, hFig, sSurf] = GetSurface(hFig, SurfaceFile)
%         [iTess, TessInfo, hFig, sSurf] = GetSurface(hFig, [], SurfaceType)
function [iTess, TessInfo, hFig, sSurf] = GetSurface(hFig, SurfaceFile, SurfaceType)
    iTess = [];
    sSurf = [];
    % Get figure appdata (surfaces configuration)
    TessInfo = getappdata(hFig, 'Surface');
    if nargin < 3 || (isempty(SurfaceType) && isempty(SurfaceFile))
        return;
    end
    if isempty(SurfaceFile)
        % Search by type.
        iTess = find(strcmpi({TessInfo.Name}, SurfaceType));
        if isempty(iTess)
            return;
        elseif numel(iTess) > 1
            % See if selected is one of them, otherwise return last.
            iTessSel = getappdata(hFig, 'iSurface');
            if ismember(iTessSel, iTess)
                iTess = iTessSel;
            else
                iTess = iTess(end);
            end
        end
    else
        % Check whether filename is an absolute or relative path
        SurfaceFile = file_short(SurfaceFile);
        % Find the surface in the 3DViz figure
        iTess = find(file_compare({TessInfo.SurfaceFile}, SurfaceFile));
    end
    if (nargout >= 4) && ~isempty(TessInfo) && ~isempty(iTess)
        sSurf = bst_memory('GetSurface', TessInfo(iTess).SurfaceFile);
    end
end


%% ===== GET SELECTED SURFACE =====
% Usage:  [iTess, TessInfo, hFig, sSurf] = GetSelectedSurface()
%         [iTess, TessInfo, hFig, sSurf] = GetSelectedSurface(hFig)
function [iTess, TessInfo, hFig, sSurf] = GetSelectedSurface(hFig) %#ok<DEFNU>
    % If target figure is not defined: use the current 3D figure
    if ((nargin < 1) || isempty(hFig))
        % Get current 3d figure
        hFig = bst_figures('GetCurrentFigure', '3D');
        % No current 3D figure: error
        if isempty(hFig)
            return
        end
    end
    % Get surface descriptions
    TessInfo = getappdata(hFig, 'Surface');
    iTess    = getappdata(hFig, 'iSurface');
    % Get the loaded structure in memory
    sSurf = [];
    if (nargout >= 4) && ~isempty(TessInfo) && ~isempty(iTess)
        sSurf = bst_memory('GetSurface', TessInfo(iTess).SurfaceFile);
    end
end


%% ===== GET SURFACE: ANATOMY =====
function [sMri,TessInfo,iTess,iMri] = GetSurfaceMri(hFig)
    sMri  = [];
    iTess = [];
    iMri  = [];
	% Get list of surfaces for the figure
    TessInfo = getappdata(hFig, 'Surface');
    if isempty(TessInfo)
        return
    end
    % Find "Anatomy"
    iTess = find(strcmpi({TessInfo.Name}, 'Anatomy'));
    if isempty(iTess)
        return
    elseif (length(iTess) > 1)
        iTess = iTess(1);
    end
    % Get Mri filename
    MriFile = TessInfo(iTess).SurfaceFile;
    % Get loaded MRI
    [sMri,iMri] = bst_memory('GetMri', MriFile);
end


%% ===== GET SURFACE VERTICES =====
function [Vertices, Faces, VertexNormals, iVisibleVert] = GetSurfaceVertices(hPatch, isStructAtlas) %#ok<DEFNU>
    Faces    = get(hPatch, 'Faces');
    Vertices = get(hPatch, 'Vertices');
    VertexNormals = double(get(hPatch, 'VertexNormals'));
    % If we cannot get the normals without redrawing the figure: try again after refresh
    if isempty(VertexNormals)
        drawnow
        VertexNormals = double(get(hPatch, 'VertexNormals'));
    end
    % Normalize normals length
    VertexNormals = bst_bsxfun(@rdivide, VertexNormals, sqrt(sum(VertexNormals.^2,2)));
    % Get visible vertices
    if isStructAtlas
        iVisibleVert = 1:size(Vertices,1);
    else
        FaceAlpha = get(hPatch, 'FaceAlpha');
        if isequal(FaceAlpha, 'flat')
            FaceVertexAlphaData = get(hPatch, 'FaceVertexAlphaData');
            iVisibleVert = unique(Faces(FaceVertexAlphaData ~= 0,:));
        elseif (FaceAlpha == 0)
            iVisibleVert = [];
        else
            iVisibleVert = 1:length(Vertices);
        end
    end
end


%% ===== REMOVE A SURFACE =====
function RemoveSurface(hFig, iSurface)
    % Get figure appdata (surfaces configuration)
    TessInfo = getappdata(hFig, 'Surface');
    if (iSurface < 0) || (iSurface > length(TessInfo))
        return;
    end
    % Remove associated patch
    iRemPatch = ishandle(TessInfo(iSurface).hPatch);
    delete(TessInfo(iSurface).hPatch(iRemPatch));
    % Remove surface from the figure's surfaces list
    TessInfo(iSurface) = [];
    % Update figure's surfaces list
    setappdata(hFig, 'Surface', TessInfo);
    % Set another figure as current figure
    if isempty(TessInfo)
        setappdata(hFig, 'iSurface', []);
    elseif (iSurface <= length(TessInfo))
        setappdata(hFig, 'iSurface', iSurface);
    else
        setappdata(hFig, 'iSurface', iSurface - 1);
    end
    % Reload scouts
    panel_scout('ReloadScouts', hFig);
end
       


%% ===== PLOT MRI =====
% Usage:  hs = panel_surface('PlotMri', hFig, posXYZ=[current], isFast=0) : Set the position of cuts and plot MRI
function hs = PlotMri(hFig, posXYZ, isFast)
    % Parse inputs
    if (nargin < 3) || isempty(isFast)
        isFast = 0;
    end
    % Get MRI
    [sMri,TessInfo,iTess,iMri] = GetSurfaceMri(hFig);
    % Set positions or use default
    if (nargin < 2) || isempty(posXYZ)
        posXYZ = TessInfo(iTess).CutsPosition;
        iDimPlot = ~isnan(posXYZ);
    else
        iDimPlot = ~isnan(posXYZ);
        TessInfo(iTess).CutsPosition(iDimPlot) = posXYZ(iDimPlot);
    end
    % Get initial threshold value
    threshold = TessInfo(iTess).SurfSmoothValue * 2 * double(sMri.Histogram.bgLevel);
    % Get colormaps
    sColormapData = bst_colormaps('GetColormap', TessInfo(iTess).ColormapType);
    sColormapMri  = bst_colormaps('GetColormap', 'anatomy');
    MriOptions = bst_get('MriOptions');
    % Define OPTIONS structure
    OPTIONS.sMri             = sMri;
    OPTIONS.iMri             = iMri;
    OPTIONS.cutsCoords       = posXYZ;                         % [x,y,z] location of the cuts in the volume
    OPTIONS.MriThreshold     = threshold;                      % MRI threshold (if value<threshold : background)
    OPTIONS.MriAlpha         = TessInfo(iTess).SurfAlpha;      % MRI alpha value (ie. opacity)
    OPTIONS.MriColormap      = sColormapMri.CMap;              % MRI Colormap
    OPTIONS.MriIndexed       = ~isempty(strfind(sColormapMri.Name, 'atlas_')) || isequal(sColormapMri.Name, 'cmap_atlas'); % If 1, the input image will be considered as indexed
    OPTIONS.OverlayCube      = TessInfo(iTess).OverlayCube;    % Overlay values
    OPTIONS.OverlayThreshold = TessInfo(iTess).DataThreshold;  % Overlay threshold
    OPTIONS.OverlaySizeThreshold = TessInfo(iTess).SizeThreshold;  % Overlay size threshold
    OPTIONS.OverlayAlpha     = TessInfo(iTess).DataAlpha;      % Overlay transparency
    OPTIONS.OverlayColormap  = sColormapData.CMap;             % Overlay colormap
    OPTIONS.OverlayIndexed   = ~isempty(strfind(sColormapData.Name, 'atlas_')) || isequal(sColormapData.Name, 'cmap_atlas'); % If 1, the input image will be considered as indexed
    OPTIONS.OverlayBounds    = TessInfo(iTess).DataLimitValue; % Overlay colormap amplitude, [minValue,maxValue]
    OPTIONS.OverlayAbsolute  = sColormapData.isAbsoluteValues;
    OPTIONS.isMipAnatomy     = MriOptions.isMipAnatomy;
    OPTIONS.isMipFunctional  = MriOptions.isMipFunctional;
    OPTIONS.UpsampleImage    = MriOptions.UpsampleImage;
    OPTIONS.MipAnatomy       = TessInfo(iTess).MipAnatomy;
    OPTIONS.MipFunctional    = TessInfo(iTess).MipFunctional;
    % Plot cuts
    [hs, OutputOptions] = mri_draw_cuts(hFig, OPTIONS);

    TessInfo(iTess).hPatch(iDimPlot) = hs(iDimPlot);
    % Save maximum in each direction in TessInfo structure
    if OPTIONS.isMipAnatomy
        iUpdateSlice = ~cellfun(@isempty, OutputOptions.MipAnatomy);
        TessInfo(iTess).MipAnatomy(iUpdateSlice) = OutputOptions.MipAnatomy(iUpdateSlice);
    end
    if OPTIONS.isMipFunctional
        iUpdateSlice = ~cellfun(@isempty, OutputOptions.MipFunctional);
        TessInfo(iTess).MipFunctional(iUpdateSlice) = OutputOptions.MipFunctional(iUpdateSlice);
    end
    % Save TessInfo
    setappdata(hFig, 'Surface', TessInfo);
    
    % Plot threshold markers
    if ~isempty(TessInfo(iTess).Data) 
        if ~sColormapData.isAbsoluteValues && (OPTIONS.OverlayBounds(1) == -OPTIONS.OverlayBounds(2))
            ThreshBar = OPTIONS.OverlayThreshold * max(abs(OPTIONS.OverlayBounds)) * [-1,1];
        elseif (OPTIONS.OverlayBounds(2) <= 0)
            ThreshBar = OPTIONS.OverlayBounds(2);
        else
            ThreshBar = OPTIONS.OverlayBounds(1) + (OPTIONS.OverlayBounds(2)-OPTIONS.OverlayBounds(1)) * OPTIONS.OverlayThreshold;
        end
        figure_3d('AddThresholdMarker', hFig, OPTIONS.OverlayBounds, ThreshBar);
    end
    
    % Plot tensors on MRI slices
    FigureId = getappdata(hFig, 'FigureId');
    if isequal(FigureId.SubType, 'TensorsMri') && ~isFast
        isProgress = bst_progress('isVisible');
        if ~isProgress
            bst_progress('start', 'MRI display', 'Updating tensors...');
        end
        if (nnz(iDimPlot) > 1)
            iDimTensor = 3;
        else
            iDimTensor = find(iDimPlot);
        end
        figure_3d('PlotTensorCut', hFig, OPTIONS.cutsCoords(iDimTensor), iDimTensor, 0);
        if ~isProgress
            drawnow;
            bst_progress('stop');
        end
    end
end


%% ===== UPDATE OVERLAY MASKS =====
function UpdateOverlayCubes(hFig) %#ok<DEFNU>
    for i = 1:length(hFig)
        [sMri, TessInfo, iTess] = GetSurfaceMri(hFig(i));
        if ~isempty(iTess) && ~isempty(TessInfo(iTess).Data)
            UpdateOverlayCube(hFig(i), iTess);
        end
    end
end


%% ===== UPDATE OVERLAY MASK =====
% Usage:  TessInfo = UpdateOverlayCube(hFig, iTess)
function TessInfo = UpdateOverlayCube(hFig, iTess)
    global GlobalData;
    % Get MRI
    TessInfo = getappdata(hFig, 'Surface');
    sMri = bst_memory('GetMri', TessInfo(iTess).SurfaceFile);
    if isempty(sMri) || isempty(sMri.Cube) || (isempty(TessInfo(iTess).Data) && ~strcmpi(TessInfo(iTess).DataSource.Type, 'Dipoles'))
       return 
    end
    isProgressBar = 0;
    SurfaceFile = [];
    OverlayCube = [];
    isVolumeGrid = 0;
    % Process depend on overlay data file
    switch (TessInfo(iTess).DataSource.Type)
        case 'Data'
            % Get figure index (in DataSet structure)
            [tmp__, iFig, iDS] = bst_figures('GetFigure', hFig);
            % Get selected channels indices and location
            selChan = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels;
            % Set data for current time frame
            GridLoc = [GlobalData.DataSet(iDS).Channel(selChan).Loc]';
            % Compute interpolation
            if isempty(TessInfo(iTess).DataWmat) || (size(TessInfo(iTess).DataWmat,2) ~= size(GridLoc,1))
                % TessInfo(iTess).DataWmat = grid_interp_mri(GridLoc, sMri, [], 1, 1, 3);
                TessInfo(iTess).DataWmat = grid_interp_mri_seeg(GridLoc, sMri);
            end
            % Build interpolated cube
            MriInterp = TessInfo(iTess).DataWmat;
            OverlayCube = tess_interp_mri_data(MriInterp, size(sMri.Cube(:,:,:,1)), TessInfo(iTess).Data, isVolumeGrid);
        case 'Source'
            % Get loaded results file
            [iDS, iResult] = bst_memory('GetDataSetResult', TessInfo(iTess).DataSource.FileName);
            if isempty(iDS)
                return
            end         
            % Get cortex surface
            SurfaceFile = GlobalData.DataSet(iDS).Results(iResult).SurfaceFile;
            % Check source grid type
            isVolumeGrid = ismember(GlobalData.DataSet(iDS).Results(iResult).HeadModelType, {'volume', 'mixed'});
        case 'Timefreq'
            % Get loaded timefreq file
            [iDS, iTf] = bst_memory('GetDataSetTimefreq', TessInfo(iTess).DataSource.FileName);
            if isempty(iDS)
                return
            end
            % Get cortex surface
            SurfaceFile = GlobalData.DataSet(iDS).Timefreq(iTf).SurfaceFile;
            % If timefreq on sources
            switch (GlobalData.DataSet(iDS).Timefreq(iTf).DataType)
                case 'data'
                    % Get figure index (in DataSet structure)
                    [tmp__, iFig, iDS] = bst_figures('GetFigure', hFig);
                    % Get selected channels indices and location
                    selChan = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels;
                    % Set data for current time frame
                    GridLoc = [GlobalData.DataSet(iDS).Channel(selChan).Loc]';
                    % Compute interpolation
                    if isempty(TessInfo(iTess).DataWmat) || (size(TessInfo(iTess).DataWmat,2) ~= size(GridLoc,1))
                        TessInfo(iTess).DataWmat = grid_interp_mri_seeg(GridLoc, sMri);
                    end
                    % Build interpolated cube
                    MriInterp = TessInfo(iTess).DataWmat;
                    OverlayCube = tess_interp_mri_data(MriInterp, size(sMri.Cube(:,:,:,1)), TessInfo(iTess).Data, isVolumeGrid);
                case 'results'
                    % Check source grid type
                    if ~isempty(GlobalData.DataSet(iDS).Timefreq(iTf).DataFile)
                        [iDS, iResult] = bst_memory('GetDataSetResult', GlobalData.DataSet(iDS).Timefreq(iTf).DataFile);
                        isVolumeGrid = ismember(GlobalData.DataSet(iDS).Results(iResult).HeadModelType, {'volume', 'mixed'});
                    else
                        isVolumeGrid = 0;
                    end
            end
        case 'Surface'
            % Get surface specified in DataSource.FileName
            SurfaceFile = TessInfo(iTess).DataSource.FileName;
        case 'Dipoles'
            sDipoles = panel_dipoles('GetSelectedDipoles', hFig);
            OverlayCube = panel_dipoles('ComputeDensity', sMri, sDipoles);
        case 'Anatomy'
            error('todo');
    end
    
    
    % ===== 3D OVERLAYS =====
    if ~isempty(OverlayCube)
        TessInfo(iTess).OverlayCube = OverlayCube;
    % ===== DISPLAY SURFACE/GRIDS =====
    else
        % Progress bar
        isProgressBar = bst_progress('isVisible');
        bst_progress('start', 'Display MRI', 'Updating values...');
        % === INTERPOLATION MRI<->GRID ===
        if isVolumeGrid
            % Compute interpolation
            MriInterp = bst_memory('GetGrid2MriInterp', iDS, iResult, TessInfo.DataSource.GridSmooth);
        % === INTERPOLATION MRI<->SURFACE ===
        else
            [sSurf, iSurf] = bst_memory('LoadSurface', SurfaceFile);
            tess2mri_interp = bst_memory('GetTess2MriInterp', iSurf);
            % If no interpolation tess<->mri accessible : exit
            if isempty(tess2mri_interp)
               return 
            end
            % Only surface interpolation is needed
            MriInterp = tess2mri_interp;
        end
        % === ATLAS SOURCES ===
        if ~isempty(TessInfo(iTess).DataSource.Atlas) && ~isempty(TessInfo(iTess).DataSource.Atlas.Scouts)
            % Initialize full cortical map
            DataScout = TessInfo(iTess).Data;
            DataSurf = zeros(size(MriInterp,2),1);
            % Duplicate the value of each scout to all the vertices
            sScouts = TessInfo(iTess).DataSource.Atlas.Scouts;
            for i = 1:length(sScouts)
                DataSurf(sScouts(i).Vertices,:) = DataScout(i,:);
            end
        else
            DataSurf = TessInfo(iTess).Data;
        end
        % === UPDATE MASK ===
        mriSize = size(sMri.Cube(:,:,:,1));
        % Build interpolated cube
        TessInfo(iTess).OverlayCube = tess_interp_mri_data(MriInterp, mriSize, DataSurf, isVolumeGrid);
    end
    
    % === UPDATE DISPLAY ===
    % Reset MIP functional fields
    TessInfo(iTess).MipFunctional = cell(3,1);    
    % Get surface description
    setappdata(hFig, 'Surface', TessInfo);
    % Redraw surface vertices color
    figure_callback(hFig, 'UpdateSurfaceColor', hFig, iTess);
    % Hide progress bar
    if ~isProgressBar
        bst_progress('stop');
    end
end


%% ===== SET SURFACE TRANSPARENCY =====
function SetSurfaceTransparency(hFig, iSurf, alpha)
    % Update surface transparency
    TessInfo = getappdata(hFig, 'Surface');
    TessInfo(iSurf).SurfAlpha = alpha;
    setappdata(hFig, 'Surface', TessInfo);
    % Update panel controls
    UpdateSurfaceProperties();
    % Update surface display
    figure_callback(hFig, 'UpdateSurfaceColor', hFig, iSurf);
    figure_callback(hFig, 'UpdateSurfaceAlpha', hFig, iSurf);
end


%% ===== SET DATA THRESHOLD =====
function SetDataThreshold(hFig, iSurf, value) %#ok<DEFNU>
    % Get surface info
    TessInfo = getappdata(hFig, 'Surface');
    % Get file in database
    if isempty(TessInfo(iSurf).DataSource) || isempty(TessInfo.DataSource(iSurf).FileName)
        return;
    end
    isStat = any(strcmpi(file_gettype(TessInfo.DataSource(iSurf).FileName), {'pdata', 'presults', 'ptimefreq'}));
    if isStat
        return;
    end
    % Update surface transparency
    TessInfo(iSurf).DataThreshold = value;
    setappdata(hFig, 'Surface', TessInfo);
    % Update panel controls
    UpdateSurfaceProperties();
    % Update color display on the surface
    figure_callback(hFig, 'UpdateSurfaceColor', hFig, iSurf);
end

%% ===== SET SIZE THRESHOLD =====
function SetSizeThreshold(hFig, iSurf, value) %#ok<DEFNU>
    % Update surface transparency
    TessInfo = getappdata(hFig, 'Surface');
    TessInfo(iSurf).SizeThreshold = value;
    setappdata(hFig, 'Surface', TessInfo);
    % Update panel controls
    UpdateSurfaceProperties();
    % Update color display on the surface
    figure_callback(hFig, 'UpdateSurfaceColor', hFig, iSurf);
end

%% ===== SET SURFACE SMOOTH =====
function SetSurfaceSmooth(hFig, iSurf, value, isSave)
    % Parse inputs
    if (nargin < 4) || isempty(isSave)
        isSave = 1;
    end
    % Get surface description
    TessInfo = getappdata(hFig, 'Surface');
    % If FEM tetrahedral mesh, ignore this call
    if strcmpi(TessInfo(iSurf).Name, 'FEM')
        return;
    end
    % Update surface transparency
    TessInfo(iSurf).SurfSmoothValue = value;
    setappdata(hFig, 'Surface', TessInfo);
    % Update panel controls
    UpdateSurfaceProperties();
    % For MRI display : Smooth slider changes threshold
    if strcmpi(TessInfo(iSurf).Name, 'Anatomy')
        figure_callback(hFig, 'UpdateMriDisplay', hFig, [], TessInfo, iSurf);
    % Else: Update color display on the surface
    else
        % Smooth surface
        figure_callback(hFig, 'UpdateSurfaceAlpha', hFig, iSurf);
        % Update scouts displayed on this surfce
        panel_scout('UpdateScoutsVertices', TessInfo(iSurf).SurfaceFile);
        % Set the new value as the default value
        if isSave
            DefaultSurfaceDisplay = bst_get('DefaultSurfaceDisplay');
            DefaultSurfaceDisplay.SurfSmoothValue = TessInfo(iSurf).SurfSmoothValue;
            bst_set('DefaultSurfaceDisplay', DefaultSurfaceDisplay);
        end
    end
end


%% ===== SET AUTO TRANSPARENCY =====
function SetAutoTransparency(hFig)
    % Get surfaces definitions
    TessInfo = getappdata(hFig, 'Surface');
    % Look for different surfaces types
    iOrder = [find(ismember({TessInfo.Name}, {'Cortex','Anatomy'})), ...
              find(strcmpi({TessInfo.Name}, 'InnerSkull')), ...
              find(strcmpi({TessInfo.Name}, 'OuterSkull')), ...
              find(strcmpi({TessInfo.Name}, 'Scalp'))];
    % Set other surfaces transparency if cortex at the same time
    for i = 2:length(iOrder)
        SetSurfaceTransparency(hFig, iOrder(i), 0.7);
    end
end
    

%% ===== SET SURFACE COLOR =====
function SetSurfaceColor(hFig, iSurf, colorCortex, colorSulci)
    % Compute the color used to display sulci
    if (nargin < 4) || isempty(colorSulci)
        colorSulci = .73 .* colorCortex;
    end
    % Get description of surfaces
    TessInfo = getappdata(hFig, 'Surface');
    % Update surface description (figure's appdata)
    TessInfo(iSurf).AnatomyColor(1,:) = colorSulci;
    TessInfo(iSurf).AnatomyColor(2,:) = colorCortex;
    % Update Surface appdata structure
    setappdata(hFig, 'Surface', TessInfo);
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Surface');
    % Change button color (if not in headless mode)
    if (bst_get('GuiLevel') >= 0)
        ctrl.jButtonSurfColor.setBackground(java.awt.Color(colorCortex(1), colorCortex(2), colorCortex(3)));
    end
    % Update panel controls
    UpdateSurfaceProperties();
    % Update color display on the surface
    figure_callback(hFig, 'UpdateSurfaceColor', hFig, iSurf);
end


%% ===== DISPLAY SURFACE EDGES =====
function SetSurfaceEdges(hFig, iSurf, SurfShowEdges) %#ok<DEFNU>
    % Get description of surfaces
    TessInfo = getappdata(hFig, 'Surface');
    % Update surface description (figure's appdata)
    TessInfo(iSurf).SurfShowEdges = SurfShowEdges;
    % Update Surface appdata structure
    setappdata(hFig, 'Surface', TessInfo);
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Surface');
    % Change button color (if not in headless mode)
    if (bst_get('GuiLevel') >= 0)
        ctrl.jButtonSurfEdge.setSelected(SurfShowEdges)
    end
    % Update panel controls
    UpdateSurfaceProperties();
    % Update color display on the surface
    figure_callback(hFig, 'UpdateSurfaceColor', hFig, iSurf);
end


%% ===== APPLY DEFAULT DISPLAY TO SURFACE =====
function ApplyDefaultDisplay() %#ok<DEFNU>
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Surface');
    if isempty(ctrl)
        return
    end
    % Get defaults for surface display
    DefaultSurfaceDisplay = bst_get('DefaultSurfaceDisplay');
    % Surface smooth
    if (ctrl.jSliderSurfSmoothValue.getValue() ~= DefaultSurfaceDisplay.SurfSmoothValue * 100)
        ctrl.jSliderSurfSmoothValue.setValue(DefaultSurfaceDisplay.SurfSmoothValue * 100);
        event = java.awt.event.MouseEvent(ctrl.jSliderSurfSmoothValue, 0, 0, 0, 0, 0, 1, 0, 0);
        SliderCallback([], event, 'SurfSmoothValue');
    end
    % Surface edges
    if DefaultSurfaceDisplay.SurfShowSulci && ~ctrl.jButtonSurfSulci.isSelected()
        ctrl.jButtonSurfSulci.doClick();
    end
end

