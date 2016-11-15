function varargout = figure_mri(varargin)
% FIGURE_MRI: Application M-file for figure_mri.fig
%
% USAGE: hFig = figure_mri('CreateFigure',            FigureId)
%               figure_mri('SetFigureStatus',         hFig, isEditFiducials, isEditVolume, isOverlay, iEeg, isUpdateLandmarks)
%               figure_mri('ColormapChangedCallback', iDS, iFig)
%               figure_mri('DisplayFigurePopup',      hFig)
%[sMri,handl] = figure_mri('SetupMri',                hFig)
%[sMri,handl] = figure_mri('LoadLandmarks',           sMri, Handles)
%[sMri,handl] = figure_mri('LoadFiducial',            sMri, Handles, FidCategory, FidName, FidColor, hButton, hTitle, PtHandleName)
%               figure_mri('SaveMri',                 hFig)
%[hI,hCH,hCV] = figure_mri('SetupView',               hAxes, xySize, imgSize, orientLabels)
%         XYZ = figure_mri('GetLocation',             cs, sMri, Handles)
%               figure_mri('SetLocation',             cs, sMri, Handles, XYZ)
%               figure_mri('MriTransform',            hButton, Transf, iDim)
%               figure_mri('UpdateMriDisplay',        hFig, dims)
%               figure_mri('UpdateSurfaceColor',      hFig)
%               figure_mri('UpdateCrosshairPosition', sMri, Handles)
%               figure_mri('UpdateCoordinates',       sMri, Handles)
%         hPt = figure_mri('PlotPoint',               sMri, Handles, ptLoc, ptColor)
%               figure_mri('UpdateVisibleLandmarks',  sMri, Handles, slicesToUpdate)
%               figure_mri('SetFiducial',             hFig, FidCategory, FidName)
%               figure_mri('ViewFiducial',            hFig, FidCategory, FiducialName)
%               figure_mri('FiducialsValidation',     MriFile)
%               figure_mri('callback_name', ...) : Invoke the named callback.

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2016 University of Southern California & McGill University
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
% Authors: Sylvain Baillet, 2004
%          Francois Tadel, 2008-2016

eval(macro_method);
end


%% ===== CREATE FIGURE =====
function [hFig, Handles] = CreateFigure(FigureId) %#ok<DEFNU>
    import org.brainstorm.icon.*;
    import java.awt.*;
    import javax.swing.*;
    
    % Get renderer name
    if (bst_get('MatlabVersion') <= 803)   % zbuffer was removed in Matlab 2014b
        rendererName = 'zbuffer';
    elseif (bst_get('DisableOpenGL') == 1)
        rendererName = 'painters';
    else
        rendererName = 'opengl';
    end
    
    % ===== FIGURE =====
    hFig = figure(...
        'Visible',       'off', ...
        'NumberTitle',   'off', ...
        'IntegerHandle', 'off', ...
        'MenuBar',       'none', ...
        'Toolbar',       'none', ...
        'DockControls',  'off', ...
        'Units',         'pixels', ...
        'Color',         [0 0 0], ...
        'Tag',           FigureId.Type, ...
        'Renderer',      rendererName, ...
        'BusyAction',    'cancel', ...
        'Interruptible', 'off', ...
        'CloseRequestFcn',         @(h,ev)bst_figures('DeleteFigure',h,ev), ...
        'KeyPressFcn',             @FigureKeyPress_Callback, ...
        'WindowButtonDownFcn',     [], ...
        'WindowButtonMotionFcn',   [], ...
        'WindowButtonUpFcn',       [], ...
        bst_get('ResizeFunction'), @ResizeCallback);
    % Set appdata
    setappdata(hFig, 'Surface', repmat(db_template('TessInfo'), 0));
    setappdata(hFig, 'iSurface',    []);
    setappdata(hFig, 'StudyFile',   []);   
    setappdata(hFig, 'SubjectFile', []);      
    setappdata(hFig, 'DataFile',    []); 
    setappdata(hFig, 'ResultsFile', []);
    setappdata(hFig, 'isStatic',    1);
    setappdata(hFig, 'isStaticFreq',1);
    setappdata(hFig, 'Colormap',    db_template('ColormapInfo'));
    
    % ===== AXES =====
    % Sagittal
    Handles.axs = axes(...
        'Parent',        hFig, ...
        'Units',         'pixels', ...
        'Color',         [1 0 0],...
        'Tag',           'axs', ...
        'BusyAction',    'cancel', ...
        'Interruptible', 'off');
    % Axial
    Handles.axa = axes(...
        'Parent',        hFig, ...
        'Units',         'pixels', ...
        'Color',         [1 0 0],...
        'Tag',           'axa', ...
        'BusyAction',    'cancel', ...
        'Interruptible', 'off');
    % Coronal
    Handles.axc = axes(...
        'Parent',        hFig, ...
        'Units',         'pixels', ...
        'Color',         [1 0 0],...
        'Tag',           'axc', ...
        'BusyAction',    'cancel', ...
        'Interruptible', 'off');
    % Configure axes
    axis([Handles.axs, Handles.axa, Handles.axc], 'image', 'off');

    % ===== SLIDERS =====
    [Handles.jSliderSagittal, Handles.sliderSagittal] = javacomponent(javax.swing.JSlider(0,10,0), [0 0 1 1], hFig);
    [Handles.jSliderAxial,    Handles.sliderAxial]    = javacomponent(javax.swing.JSlider(0,10,0), [0 0 1 1], hFig);
    [Handles.jSliderCoronal,  Handles.sliderCoronal]  = javacomponent(javax.swing.JSlider(0,10,0), [0 0 1 1], hFig);
    Handles.jSliderSagittal.setBackground(java.awt.Color(0,0,0));
    Handles.jSliderAxial.setBackground(java.awt.Color(0,0,0));
    Handles.jSliderCoronal.setBackground(java.awt.Color(0,0,0));
    % When clicking on a slider: select the corresponding axis
    java_setcb(Handles.jSliderSagittal, 'MouseClickedCallback', @(h,ev)set(hFig, 'CurrentAxes', Handles.axs));
    java_setcb(Handles.jSliderAxial,    'MouseClickedCallback', @(h,ev)set(hFig, 'CurrentAxes', Handles.axa));
    java_setcb(Handles.jSliderCoronal,  'MouseClickedCallback', @(h,ev)set(hFig, 'CurrentAxes', Handles.axc));
    
    % ===== TITLE BARS =====
    % Title: Panels
    jPanelTitleSagittal = gui_river([0 0], [5 10 0 0]);
    jPanelTitleAxial    = gui_river([0 0], [5 10 0 0]);
    jPanelTitleCoronal  = gui_river([0 0], [5 10 0 0]);
    jPanelTitleSagittal.setBackground(Color(0,0,0));
    jPanelTitleAxial.setBackground(Color(0,0,0));
    jPanelTitleCoronal.setBackground(Color(0,0,0));
    % Title: Buttons
    Handles.jButtonRotateS  = gui_component('button', jPanelTitleSagittal, [], '', IconLoader.ICON_MRI_ROTATE,  'Rotate MRI: 90° clockwise around axis X', @(h,ev)MriTransform(hFig, 'Rotate', 1), []);
    Handles.jButtonRotateA  = gui_component('button', jPanelTitleAxial,    [], '', IconLoader.ICON_MRI_ROTATE,  'Rotate MRI: 90° clockwise around axis Z', @(h,ev)MriTransform(hFig, 'Rotate', 3), []);
    Handles.jButtonRotateC  = gui_component('button', jPanelTitleCoronal,  [], '', IconLoader.ICON_MRI_ROTATE,  'Rotate MRI: 90° clockwise around axis Y', @(h,ev)MriTransform(hFig, 'Rotate', 2), []);
    Handles.jButtonFlipS    = gui_component('button', jPanelTitleSagittal, [], '', IconLoader.ICON_MRI_FLIP,    'Flip MRI anterior-posterior', @(h,ev)MriTransform(hFig, 'Flip', 2), []);
    Handles.jButtonFlipA    = gui_component('button', jPanelTitleAxial,    [], '', IconLoader.ICON_MRI_FLIP,    'Flip MRI left-right',         @(h,ev)MriTransform(hFig, 'Flip', 1), []);
    Handles.jButtonFlipC    = gui_component('button', jPanelTitleCoronal,  [], '', IconLoader.ICON_MRI_FLIP,    'Flip MRI left-right',         @(h,ev)MriTransform(hFig, 'Flip', 1), []);
    Handles.jButtonPermuteS = gui_component('button', jPanelTitleSagittal, [], '', IconLoader.ICON_MRI_PERMUTE, 'Permute MRI dimensions', @(h,ev)MriTransform(hFig, 'Permute', 1), []);
    Handles.jButtonPermuteA = gui_component('button', jPanelTitleAxial,    [], '', IconLoader.ICON_MRI_PERMUTE, 'Permute MRI dimensions', @(h,ev)MriTransform(hFig, 'Permute', 3), []);
    Handles.jButtonPermuteC = gui_component('button', jPanelTitleCoronal,  [], '', IconLoader.ICON_MRI_PERMUTE, 'Permute MRI dimensions', @(h,ev)MriTransform(hFig, 'Permute', 2), []);
    % Set buttons size
    jButtons = [Handles.jButtonRotateS, Handles.jButtonRotateA, Handles.jButtonRotateC, Handles.jButtonFlipS, Handles.jButtonFlipA, Handles.jButtonFlipC, Handles.jButtonPermuteS, Handles.jButtonPermuteA, Handles.jButtonPermuteC];
    for i = 1:length(jButtons)
        jButtons(i).setPreferredSize(Dimension(20,20));
    end
    % Title: Labels
    Handles.jLabelTitleS = gui_component('label',  jPanelTitleSagittal, [], '<HTML>&nbsp;&nbsp;&nbsp;<B>Sagittal</B>', [], [], @(h,ev)set(hFig,'CurrentAxes',Handles.axs), []);
    Handles.jLabelTitleA = gui_component('label',  jPanelTitleAxial,    [], '<HTML>&nbsp;&nbsp;&nbsp;<B>Axial</B>',    [], [], @(h,ev)set(hFig,'CurrentAxes',Handles.axa), []);
    Handles.jLabelTitleC = gui_component('label',  jPanelTitleCoronal,  [], '<HTML>&nbsp;&nbsp;&nbsp;<B>Coronal</B>',  [], [], @(h,ev)set(hFig,'CurrentAxes',Handles.axc), []);
    % Title: Value
    Handles.jLabelValue = gui_component('label',  jPanelTitleSagittal, 'hfill', 'Value', [], [], @(h,ev)set(hFig,'CurrentAxes',Handles.axs), []);
    Handles.jLabelValue.setHorizontalAlignment(Handles.jLabelValue.RIGHT);
    % Add panels to the figure
    [Handles.jPanelSagittal, Handles.panelTitleSagittal] = javacomponent(jPanelTitleSagittal, [0 0 1 1], hFig);
    [Handles.jPanelAxial,    Handles.panelTitleAxial]    = javacomponent(jPanelTitleAxial,    [0 0 1 1], hFig);
    [Handles.jPanelCoronal,  Handles.panelTitleCoronal]  = javacomponent(jPanelTitleCoronal,  [0 0 1 1], hFig);
    
    
    % ===== OPTION PANELS =====
    jPanelOptions = java_create('javax.swing.JPanel');
    jPanelOptions.setLayout(java_create('java.awt.GridBagLayout'));
    jPanelOptions.setBorder(BorderFactory.createEmptyBorder(5, 10, 5, 10));
    jPanelOptions.setBackground(Color(0,0,0));
    [Handles.jPanelOptions, Handles.panelOptions] = javacomponent(jPanelOptions, [0 0 1 1], hFig);
    % GridBag default constraints
    c = GridBagConstraints();
    c.gridx   = 1;
    c.weightx = 1;
    c.fill    = GridBagConstraints.BOTH;
    c.insets  = Insets(0,0,0,0);
    % Panel: Fiducials
    c.gridy = 1;    c.weighty = 0.8;
    Handles.jPanelCS = gui_component('Panel', jPanelOptions, c);
    Handles.jPanelCS.setLayout(java_create('java.awt.GridBagLayout'));
    jBorder = BorderFactory.createTitledBorder('Fiducials');
    jBorder.setTitleFont(bst_get('Font', 11));
    jBorder.setTitleColor(Color(.9,.9,.9));
    Handles.jPanelCS.setBorder(jBorder);
    Handles.jPanelCS.setOpaque(0);
    % Additional place holder when the panel is hidden
    Handles.jPanelCSHidden = gui_component('Panel', jPanelOptions, c);
    Handles.jPanelCSHidden.setOpaque(0);
    Handles.jPanelCSHidden.setVisible(0);
    % Panel: Display options
    c.gridy = 2;    c.weighty = 0.5;
    Handles.jPanelDisplayOptions = gui_component('Panel', jPanelOptions, c);
    Handles.jPanelDisplayOptions.setLayout(java_create('java.awt.GridBagLayout'));
    jBorder = BorderFactory.createTitledBorder('Display options');
    jBorder.setTitleFont(bst_get('Font', 11));
    jBorder.setTitleColor(Color(.9,.9,.9));
    Handles.jPanelDisplayOptions.setBorder(jBorder);
    Handles.jPanelDisplayOptions.setOpaque(0);
    % Panel: Coordinates
    c.gridy = 3;    c.weighty = 0.7;
    Handles.jPanelCoordinates = gui_component('Panel', jPanelOptions, c);
    Handles.jPanelCoordinates.setLayout(java_create('java.awt.GridBagLayout'));
    jBorder = BorderFactory.createTitledBorder('Coordinates (milimeters)');
    jBorder.setTitleFont(bst_get('Font', 11));
    jBorder.setTitleColor(Color(.9,.9,.9));
    Handles.jPanelCoordinates.setBorder(jBorder);
    Handles.jPanelCoordinates.setOpaque(0);
    % Panel: Validation
    c.gridy = 4;    c.weighty = 0.2;
    Handles.jPanelValidate = gui_component('Panel', jPanelOptions, c);
    Handles.jPanelValidate.setLayout(java_create('java.awt.GridBagLayout'));
    Handles.jPanelValidate.setBorder(BorderFactory.createEmptyBorder(3,3,3,3));
    Handles.jPanelValidate.setOpaque(0);

    % ===== FIDUCIALS =====
    % Default constrains
    c = GridBagConstraints();
    c.fill    = GridBagConstraints.BOTH;
    c.weightx = 1;
    c.weighty = 1;
    % Titles and buttons
    c.insets  = Insets(0,0,0,0);
    c.gridx = 1;  c.gridy = 1;  Handles.jTitleNAS      = gui_component('label',  Handles.jPanelCS, c, 'NAS: ', [], '', [], []);
    c.gridx = 1;  c.gridy = 2;  Handles.jTitleLPA      = gui_component('label',  Handles.jPanelCS, c, 'LPA: ', [], '', [], []);
    c.gridx = 1;  c.gridy = 3;  Handles.jTitleRPA      = gui_component('label',  Handles.jPanelCS, c, 'RPA: ', [], '', [], []);
    c.gridx = 4;  c.gridy = 1;  Handles.jTitleAC       = gui_component('label',  Handles.jPanelCS, c, 'AC: ',  [], '', [], []);
    c.gridx = 4;  c.gridy = 2;  Handles.jTitlePC       = gui_component('label',  Handles.jPanelCS, c, 'PC: ',  [], '', [], []);
    c.gridx = 4;  c.gridy = 3;  Handles.jTitleIH       = gui_component('label',  Handles.jPanelCS, c, 'IH: ',  [], '', [], []);
    c.insets  = Insets(2,2,2,2);
    c.gridx = 2;  c.gridy = 1;  Handles.jButtonNasSet  = gui_component('button', Handles.jPanelCS, c, 'Set',  [], '', @(h,ev)SetFiducial(hFig, 'SCS', 'NAS'), []);
    c.gridx = 2;  c.gridy = 2;  Handles.jButtonLpaSet  = gui_component('button', Handles.jPanelCS, c, 'Set',  [], '', @(h,ev)SetFiducial(hFig, 'SCS', 'LPA'), []);
    c.gridx = 2;  c.gridy = 3;  Handles.jButtonRpaSet  = gui_component('button', Handles.jPanelCS, c, 'Set',  [], '', @(h,ev)SetFiducial(hFig, 'SCS', 'RPA'), []);
    c.gridx = 3;  c.gridy = 1;  Handles.jButtonNasView = gui_component('button', Handles.jPanelCS, c, 'View', [], '', @(h,ev)ViewFiducial(hFig, 'SCS', 'NAS'), []);
    c.gridx = 3;  c.gridy = 2;  Handles.jButtonLpaView = gui_component('button', Handles.jPanelCS, c, 'View', [], '', @(h,ev)ViewFiducial(hFig, 'SCS', 'LPA'), []);
    c.gridx = 3;  c.gridy = 3;  Handles.jButtonRpaView = gui_component('button', Handles.jPanelCS, c, 'View', [], '', @(h,ev)ViewFiducial(hFig, 'SCS', 'RPA'), []);
    c.gridx = 5;  c.gridy = 1;  Handles.jButtonAcSet   = gui_component('button', Handles.jPanelCS, c, 'Set',  [], '', @(h,ev)SetFiducial(hFig, 'NCS', 'AC'), []);
    c.gridx = 5;  c.gridy = 2;  Handles.jButtonPcSet   = gui_component('button', Handles.jPanelCS, c, 'Set',  [], '', @(h,ev)SetFiducial(hFig, 'NCS', 'PC'), []);
    c.gridx = 5;  c.gridy = 3;  Handles.jButtonIhSet   = gui_component('button', Handles.jPanelCS, c, 'Set',  [], '', @(h,ev)SetFiducial(hFig, 'NCS', 'IH'), []);
    c.gridx = 6;  c.gridy = 1;  Handles.jButtonAcView  = gui_component('button', Handles.jPanelCS, c, 'View', [], '', @(h,ev)ViewFiducial(hFig, 'NCS', 'AC'), []);
    c.gridx = 6;  c.gridy = 2;  Handles.jButtonPcView  = gui_component('button', Handles.jPanelCS, c, 'View', [], '', @(h,ev)ViewFiducial(hFig, 'NCS', 'PC'), []);
    c.gridx = 6;  c.gridy = 3;  Handles.jButtonIhView  = gui_component('button', Handles.jPanelCS, c, 'View', [], '', @(h,ev)ViewFiducial(hFig, 'NCS', 'IH'), []);

    % ===== DISPLAY OPTIONS =====
    % Default constrains
    c = GridBagConstraints();
    c.fill    = GridBagConstraints.BOTH;
    c.weightx = 1;
    c.weighty = 1;
    c.insets  = Insets(0,0,0,0);
    % Group for radio buttons
    groupOrient = ButtonGroup();
    % Titles and checkboxes
    c.gridx = 1;  c.gridy = 1;  Handles.jTitleView          = gui_component('label',    Handles.jPanelDisplayOptions, c, ' ', [], '', [], []);
    c.gridx = 2;  c.gridy = 1;  Handles.jCheckMipAnatomy    = gui_component('checkbox', Handles.jPanelDisplayOptions, c, 'MIP: Anatomy',      [], '', @(h,ev)checkMip_Callback(hFig,ev), []);
    c.gridx = 2;  c.gridy = 2;  Handles.jCheckMipFunctional = gui_component('checkbox', Handles.jPanelDisplayOptions, c, 'MIP: Functional',   [], '', @(h,ev)checkMip_Callback(hFig,ev), []);
    c.gridx = 3;  c.gridy = 1;  Handles.jCheckViewCrosshair = gui_component('checkbox', Handles.jPanelDisplayOptions, c, 'Crosshairs',   [], '', @(h,ev)checkCrosshair_Callback(hFig,ev), []);
    c.gridx = 3;  c.gridy = 2;  Handles.jCheckViewSliders   = gui_component('checkbox', Handles.jPanelDisplayOptions, c, 'Controls',     [], '', @(h,ev)checkViewControls_Callback(hFig,ev), []);
    c.gridx = 4;  c.gridy = 1;  Handles.jRadioNeurological  = gui_component('radio',    Handles.jPanelDisplayOptions, c, 'Neurological', groupOrient, '', @(h,ev)orientation_Callback(hFig,ev), []);
    c.gridx = 4;  c.gridy = 2;  Handles.jRadioRadiological  = gui_component('radio',    Handles.jPanelDisplayOptions, c, 'Radiological', groupOrient, '', @(h,ev)orientation_Callback(hFig,ev), []);
    % Pptions selected by default
    Handles.jCheckViewCrosshair.setSelected(1);
    Handles.jCheckViewSliders.setSelected(1);
    
    % ===== COORDINATES =====
    % Default constrains
    c = GridBagConstraints();
    c.fill    = GridBagConstraints.BOTH;
    c.weighty = 0.1;
    c.insets  = Insets(0,0,0,0);
    % Titles and labels
    c.weightx = 0.1;
    c.gridx = 1;  c.gridy = 1;  Handles.jTitleMRI      = gui_component('label', Handles.jPanelCoordinates, c, 'MRI:', [], '', [], []);
    c.gridx = 1;  c.gridy = 2;  Handles.jTitleSCS      = gui_component('label', Handles.jPanelCoordinates, c, 'SCS:', [], '', [], []);
    c.gridx = 1;  c.gridy = 3;  Handles.jTitleMNI      = gui_component('label', Handles.jPanelCoordinates, c, 'MNI:', [], '', [], []);
    c.weightx = 0.2;
    c.gridx = 2;  c.gridy = 1;  Handles.jTextCoordMriX = gui_component('label', Handles.jPanelCoordinates, c, '...',  [], '', [], []);
    c.gridx = 3;  c.gridy = 1;  Handles.jTextCoordMriY = gui_component('label', Handles.jPanelCoordinates, c, '...',  [], '', [], []);
    c.gridx = 4;  c.gridy = 1;  Handles.jTextCoordMriZ = gui_component('label', Handles.jPanelCoordinates, c, '...',  [], '', [], []);
    c.gridx = 2;  c.gridy = 2;  Handles.jTextCoordScsX = gui_component('label', Handles.jPanelCoordinates, c, '...',  [], '', [], []);
    c.gridx = 3;  c.gridy = 2;  Handles.jTextCoordScsY = gui_component('label', Handles.jPanelCoordinates, c, '...',  [], '', [], []);
    c.gridx = 4;  c.gridy = 2;  Handles.jTextCoordScsZ = gui_component('label', Handles.jPanelCoordinates, c, '...',  [], '', [], []);
    c.gridx = 2;  c.gridy = 3;  Handles.jTextCoordMniX = gui_component('label', Handles.jPanelCoordinates, c, '...',  [], '', [], []);
    c.gridx = 3;  c.gridy = 3;  Handles.jTextCoordMniY = gui_component('label', Handles.jPanelCoordinates, c, '...',  [], '', [], []);
    c.gridx = 4;  c.gridy = 3;  Handles.jTextCoordMniZ = gui_component('label', Handles.jPanelCoordinates, c, '...',  [], '', [], []);
    c.gridx = 2;  c.gridy = 3;  c.gridwidth = 3;  
    Handles.jTextNoMni = gui_component('label', Handles.jPanelCoordinates, c, '<HTML>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<FONT color="#505050"><U>Click here to compute MNI transformation</U></FONT>',  [], '', @(h,ev)ComputeMniCoordinates(hFig), []);
    
    % ===== VALIDATION BAR =====
    % Default constrains
    c = GridBagConstraints();
    c.gridy   = 1; 
    c.weighty = 1;
    c.fill    = GridBagConstraints.BOTH;
    c.insets  = Insets(2,4,2,4);
    % Buttons: Zoom-, Zoom+, Cancel, Save
    c.gridx = 1;  c.weightx = 0.1;  Handles.jButtonZoomMinus = gui_component('button', Handles.jPanelValidate, c, '', IconLoader.ICON_ZOOM_MINUS, '<HTML><B>Zoom out   [-]</B><BR><BR>Double-click to reset view', @(h,ev)ButtonZoom_Callback(hFig, '-'), []);
    c.gridx = 2;  c.weightx = 0.1;  Handles.jButtonZoomPlus  = gui_component('button', Handles.jPanelValidate, c, '', IconLoader.ICON_ZOOM_PLUS,  '<HTML><B>Zoom in   [+]</B><BR><BR>Double-click to reset view',  @(h,ev)ButtonZoom_Callback(hFig, '+'), []);
    c.gridx = 3;  c.weightx = 0.1;  Handles.jButtonSetCoord  = gui_component('button', Handles.jPanelValidate, c, '', IconLoader.ICON_VIEW_SCOUT_IN_MRI,  'Set the current coordinates',  @(h,ev)ButtonSetCoordinates_Callback(hFig), []);
    c.gridx = 4;  c.weightx = 0.7;  gui_component('label', Handles.jPanelValidate, c, '');
    c.gridx = 5;  c.weightx = 0.4;  Handles.jButtonCancel = gui_component('button', Handles.jPanelValidate, c, 'Cancel', [], '', @(h,ev)ButtonCancel_Callback(hFig), []);
    c.gridx = 6;  c.weightx = 0.4;  Handles.jButtonSave   = gui_component('button', Handles.jPanelValidate, c, 'Save',   [], '', @(h,ev)ButtonSave_Callback(hFig), []);
    
    % ===== CONFIGURE OBJECTS =====
    % Set labels in white
    jLabels = [Handles.jLabelTitleS, Handles.jLabelTitleA, Handles.jLabelTitleC, Handles.jLabelValue, Handles.jTitleNAS, Handles.jTitleLPA, Handles.jTitleRPA, ...
               Handles.jTitleAC, Handles.jTitlePC, Handles.jTitleIH, Handles.jCheckViewCrosshair, ...
               Handles.jCheckViewSliders, Handles.jCheckMipAnatomy, Handles.jCheckMipFunctional, Handles.jRadioNeurological, Handles.jRadioRadiological, ...
               Handles.jTitleMRI, Handles.jTitleSCS, Handles.jTitleMNI, Handles.jTextCoordMriX, Handles.jTextCoordMriY, Handles.jTextCoordMriZ, ...
               Handles.jTextCoordScsX, Handles.jTextCoordScsY, Handles.jTextCoordScsZ, Handles.jTextCoordMniX, Handles.jTextCoordMniY, Handles.jTextCoordMniZ];
    for i = 1:length(jLabels)
        jLabels(i).setFont(bst_get('Font', 11));
        jLabels(i).setForeground(Color(.9,.9,.9));
        jLabels(i).setOpaque(0);
    end
    Handles.jLabelValue.setForeground(Color(.4,.4,.4));
    % Set text alignment to right
    jLabels = [Handles.jTitleNAS, Handles.jTitleLPA, Handles.jTitleRPA, Handles.jTitleAC, Handles.jTitlePC, Handles.jTitleIH, ...
               Handles.jTitleMRI, Handles.jTitleSCS, Handles.jTitleMNI];
    for i = 1:length(jLabels)
        jLabels(i).setHorizontalAlignment(JTextField.RIGHT);
    end
    % Set text alignment to center
    jLabels = [Handles.jTextCoordMriX, Handles.jTextCoordMriY, Handles.jTextCoordMriZ, ...
               Handles.jTextCoordScsX, Handles.jTextCoordScsY, Handles.jTextCoordScsZ, Handles.jTextCoordMniX, Handles.jTextCoordMniY, Handles.jTextCoordMniZ];
    for i = 1:length(jLabels)
        jLabels(i).setHorizontalAlignment(JTextField.CENTER);
    end
    % Set size for fiducial buttons (too big on MacOS)
    jButtonsFid = [Handles.jButtonNasView, Handles.jButtonLpaView, Handles.jButtonRpaView, Handles.jButtonNasSet, Handles.jButtonLpaSet, Handles.jButtonRpaSet, ...
                   Handles.jButtonAcView, Handles.jButtonPcView, Handles.jButtonIhView, Handles.jButtonAcSet, Handles.jButtonPcSet, Handles.jButtonIhSet];
    for i = 1:length(jButtonsFid)
        jButtonsFid(i).setPreferredSize(Dimension(30,20));
        jButtonsFid(i).setMinimumSize(Dimension(15,10));
        jButtonsFid(i).setMaximumSize(Dimension(500,25));
    end
    % Remove margins for buttons
    jButtonsAll = [jButtonsFid, Handles.jButtonSave, Handles.jButtonCancel];
    for i = 1:length(jButtonsAll)
        jButtonsAll(i).setMargin(java.awt.Insets(0,0,0,0));
    end
    
    % ===== PREVIOUS CONFIGURATION =====
    % Get saved configuration
    MriOptions = bst_get('MriOptions');
    % Set MIP anat/functional status
    Handles.jCheckMipAnatomy.setSelected(MriOptions.isMipAnatomy);
    Handles.jCheckMipFunctional.setSelected(MriOptions.isMipFunctional);
    % Load orientation
    if MriOptions.isRadioOrient
        Handles.jRadioRadiological.setSelected(1);
    	set([Handles.axs,Handles.axc,Handles.axa], 'XDir', 'reverse');
    else
        Handles.jRadioNeurological.setSelected(1);
        set([Handles.axs,Handles.axc,Handles.axa], 'XDir', 'normal');
    end
    
    % ===== OTHER FIGURE HANDLES =====
    % Initialize other handles
    Handles.hFig       = hFig;
    Handles.hPointNAS  = [];
    Handles.hPointLPA  = [];
    Handles.hPointRPA  = [];
    Handles.hPointAC   = [];
    Handles.hPointPC   = [];
    Handles.hPointIH   = [];
    Handles.hPointEEG  = [];
    Handles.hTextEEG   = [];
    Handles.LocEEG     = [];
    Handles.isEditFiducials = 1;
    Handles.isEditVolume    = 1;
    Handles.isOverlay       = 1;
    Handles.isEeg           = 0;
    Handles.isEegLabels   = 1;
    Handles.isModifiedMri = 0;
    Handles.isModifiedEeg = 0;
    Handles.ChannelFile   = [];
    Handles.ChannelMat    = [];
    Handles.iChannels     = [];
end




%% =======================================================================================
%  ===== FIGURE CALLBACKS ================================================================
%  =======================================================================================

%% ===== RESIZE CALLBACK =====
function ResizeCallback(hFig, varargin)
    % Get figure position and size in pixels
    figPos = get(hFig, 'Position');
    % Get figure Handles
    Handles = bst_figures('GetFigureHandles', hFig);
    % Configuration
    if ~Handles.jCheckViewSliders.isSelected()
        sliderH = 0;
        titleH  = 0;
    else
        sliderH = 20;
        titleH  = 25;
    end
    % Get colorbar
    hColorbar = findobj(hFig, '-depth', 1, 'Tag', 'Colorbar');
    % Reserve space for the colorbar
    if ~isempty(hColorbar)
        colorbarMargin = 45;
    else
        colorbarMargin = 0;
    end
    
    % Positioning of the 4 quadrants of the figure:
    %   [ Coronal | Sagittal ]
    %   [  Axial  | Options  ]
    blockSize = [floor((figPos(3) - colorbarMargin)/2), floor(figPos(4)/2)];
    posS = [blockSize(1)+1, blockSize(2)+1, blockSize(1), blockSize(2)];
    posA = [             1,              1, blockSize(1), blockSize(2)];
    posC = [             1, blockSize(2)+1, blockSize(1), blockSize(2)];
    posO = [blockSize(1)+1,              1, blockSize(1), blockSize(2)];
    % Position all the basic blocks
    set(Handles.axs, 'Position', max([1 1 1 1], posS + [0, sliderH, 0, -(sliderH + titleH)]));
    set(Handles.axa, 'Position', max([1 1 1 1], posA + [0, sliderH, 0, -(sliderH + titleH)]));
    set(Handles.axc, 'Position', max([1 1 1 1], posC + [0, sliderH, 0, -(sliderH + titleH)]));
    set(Handles.panelOptions, 'Position', max([1 1 1 1], posO + [0, 0, colorbarMargin, 0]));
    set(Handles.panelTitleSagittal, 'Position', max([1 1 1 1], [posS(1), posS(2)+posS(4)-titleH, posS(3), titleH]));
    set(Handles.panelTitleAxial,    'Position', max([1 1 1 1], [posA(1), posA(2)+posA(4)-titleH, posA(3), titleH]));
    set(Handles.panelTitleCoronal,  'Position', max([1 1 1 1], [posC(1), posC(2)+posC(4)-titleH, posC(3), titleH]));
    set(Handles.sliderSagittal, 'Position', max([1 1 1 1], [posS(1), posS(2), posS(3), sliderH]));
    set(Handles.sliderAxial,    'Position', max([1 1 1 1], [posA(1), posA(2), posA(3), sliderH]));
    set(Handles.sliderCoronal,  'Position', max([1 1 1 1], [posC(1), posC(2), posC(3), sliderH]));

    % Resize colorbar
    if ~isempty(hColorbar)
        colorbarWidth = 15;
        posColor = [...
            figPos(3) - colorbarMargin, ...
            posS(2) + sliderH + 15, ...
            colorbarWidth, ...
            posS(4) - sliderH - titleH - 15];
        % Reposition the colorbar
        set(hColorbar, 'Units', 'pixels', 'Position', max([1 1 1 1], posColor));
    end
end



%% ===== SET FIGURE STATUS =====
function SetFigureStatus(hFig, isEditFiducials, isEditVolume, isOverlay, isEeg, updateLandmarks)
    % Parse inputs
    if (nargin < 6) || isempty(updateLandmarks)
        updateLandmarks = 0;
    end
    if (nargin < 5) || isempty(isEeg)
        isEeg = [];
    end
    if (nargin < 4) || isempty(isOverlay)
        isOverlay = [];
    end
    if (nargin < 3) || isempty(isEditVolume)
        isEditVolume = [];
    end
    % Get figure handles
    Handles = bst_figures('GetFigureHandles', hFig);
    % Check for modifications
    isChanged = 0;
    if ~isempty(isEditFiducials) && (isEditFiducials ~= Handles.isEditFiducials)
        Handles.isEditFiducials = isEditFiducials;
        isChanged = 1;
    end
    if ~isempty(isEditVolume) && (isEditVolume ~= Handles.isEditVolume)
        Handles.isEditVolume = isEditVolume;
        isChanged = 1;
    end
    if ~isempty(isOverlay) && (isOverlay ~= Handles.isOverlay)
        Handles.isOverlay = isOverlay;
        isChanged = 1;
    end
    if ~isempty(isEeg) && (isEeg ~= Handles.isEeg)
        Handles.isEeg = isEeg;
        isChanged = 1;
    end
    % If no modification was made: return
    if ~isChanged
        return;
    end
    % Update figure handles
    bst_figures('SetFigureHandles', hFig, Handles);
    
    % Update controls: Fiducials
    Handles.jPanelCS.setVisible(Handles.isEditFiducials);
    Handles.jPanelCSHidden.setVisible(~Handles.isEditFiducials);
    % Update controls: Edit volume
    Handles.jButtonRotateS.setVisible(Handles.isEditVolume);
    Handles.jButtonRotateA.setVisible(Handles.isEditVolume);
    Handles.jButtonRotateC.setVisible(Handles.isEditVolume);
    Handles.jButtonFlipS.setVisible(Handles.isEditVolume);
    Handles.jButtonFlipA.setVisible(Handles.isEditVolume);
    Handles.jButtonFlipC.setVisible(Handles.isEditVolume);
    Handles.jButtonPermuteS.setVisible(Handles.isEditVolume);
    Handles.jButtonPermuteA.setVisible(Handles.isEditVolume);
    Handles.jButtonPermuteC.setVisible(Handles.isEditVolume);
    % Update controls: Validation buttons
    isValid = (Handles.isEditFiducials || Handles.isEditVolume || Handles.isEeg);
    Handles.jButtonCancel.setVisible(isValid)
    Handles.jButtonSave.setVisible(isValid);
    % Update controls: Overlay
    Handles.jCheckMipFunctional.setVisible(Handles.isOverlay || Handles.isEeg);

    % Update fiducials/other landmarks
    if updateLandmarks
        sMri = panel_surface('GetSurfaceMri', hFig);
        UpdateVisibleLandmarks(sMri, Handles);
    end
end


%% ===== KEYBOAD CALLBACK =====
function FigureKeyPress_Callback(hFig, keyEvent)   
    global TimeSliderMutex;
    % ===== PROCESS BY CHARACTERS =====
    switch (keyEvent.Character)
        % === SCOUTS : GROW/SHRINK ===
        case '+'
            ButtonZoom_Callback(hFig, '+');
        case '-'
            ButtonZoom_Callback(hFig, '-');
        case {'=', 'equal'}
            ApplyCoordsToAllFigures(hFig, 'mni');
        case '*'
            ApplyCoordsToAllFigures(hFig, 'scs');
            
        otherwise
            % ===== PROCESS BY KEYS =====
            switch (keyEvent.Key)
                % === LEFT, RIGHT, PAGEUP, PAGEDOWN ===
                case {'leftarrow', 'rightarrow', 'pageup', 'pagedown', 'home', 'end'}
                    if isempty(TimeSliderMutex) || ~TimeSliderMutex
                        panel_time('TimeKeyCallback', keyEvent);
                    end
                % === UP/DOWN: SCROLL SLIDES ===
                case 'uparrow'
                    MouseWheel_Callback(hFig, [], [], 1);
                case 'downarrow'
                    MouseWheel_Callback(hFig, [], [], -1);
                % === DATABASE NAVIGATOR ===
                case {'f1', 'f2', 'f3', 'f4'}
                    bst_figures('NavigatorKeyPress', hFig, keyEvent);
                % CTRL+D : Dock figure
                case 'd'
                    if ismember('control', keyEvent.Modifier)
                        isDocked = strcmpi(get(hFig, 'WindowStyle'), 'docked');
                        bst_figures('DockFigure', hFig, ~isDocked);
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
                % CTRL+S : Set electrode position
                case 's'
                    if ismember('control', keyEvent.Modifier)
                        SetElectrodePosition(hFig);
                    end
                % CTRL+E : Set electrode labels visible
                case 'e'
                    if ismember('control', keyEvent.Modifier)
                        SetLabelVisible(hFig, []);
                    end
            end
    end
end

    
%% ===== SLIDER CALLBACK =====
function sliderClicked_Callback(hFig, iSlider, ev)
    if ~ev.getSource.getModel.getValueIsAdjusting
        % Update MRI display
        UpdateMriDisplay(hFig, iSlider);
    end
end


%% ===== CHECKBOX: MIP ANATOMY/FUNCTIONAL =====
function checkMip_Callback(hFig, varargin)
    % Get figure Handles
    Handles = bst_figures('GetFigureHandles', hFig);
    % Get values for MIP
    MriOptions = bst_get('MriOptions');
    MriOptions.isMipAnatomy    = Handles.jCheckMipAnatomy.isSelected();
    MriOptions.isMipFunctional = Handles.jCheckMipFunctional.isSelected();
    bst_set('MriOptions', MriOptions);
    % Update slices display
    UpdateMriDisplay(hFig);
end

%% ===== CHECKBOX: VIEW CROSSHAIR =====
function checkCrosshair_Callback(hFig, varargin)
    % Get figure Handles
    Handles = bst_figures('GetFigureHandles', hFig);
    % Get all the crosshairs in the figure
    hCrosshairs = [Handles.crosshairCoronalH, Handles.crosshairCoronalV, Handles.crosshairSagittalH, Handles.crosshairSagittalV, Handles.crosshairAxialH, Handles.crosshairAxialV];
    % Update crosshairs visibility
    if Handles.jCheckViewCrosshair.isSelected()
        set(hCrosshairs, 'Visible', 'on');
    else
        set(hCrosshairs, 'Visible', 'off');
    end
end

%% ===== CHECKBOX: VIEW SLIDERS =====
function checkViewControls_Callback(hFig, varargin)
    % Get figure Handles
    Handles = bst_figures('GetFigureHandles', hFig);
    % Hide/Show sliders and title bars
    hControls = [Handles.sliderAxial, Handles.sliderSagittal, Handles.sliderCoronal, Handles.panelTitleAxial, Handles.panelTitleSagittal, Handles.panelTitleCoronal];
    if Handles.jCheckViewSliders.isSelected()
        set(hControls, 'Visible', 'on');
    else
        set(hControls, 'Visible', 'off');
    end
    % Call resize callback
    ResizeCallback(hFig);
end

%% ===== ORIENT: NEURO/RADIO =====
function orientation_Callback(hFig, varargin)
    % Get figure Handles
    Handles = bst_figures('GetFigureHandles', hFig);
    % Get values
    isRadio = Handles.jRadioRadiological.isSelected();
    % Save value in user preferences
    MriOptions = bst_get('MriOptions');
    MriOptions.isRadioOrient = isRadio;
    bst_set('MriOptions', MriOptions);
    % If is radio
    if isRadio
    	set([Handles.axs,Handles.axc,Handles.axa],'XDir', 'reverse');
    else
        set([Handles.axs,Handles.axc,Handles.axa],'XDir', 'normal');
    end
    drawnow;
end


%% ===== BUTTON ZOOM =====
function ButtonZoom_Callback(hFig, action)
    % Get figure Handles
    sMri = panel_surface('GetSurfaceMri', hFig);
    Handles = bst_figures('GetFigureHandles', hFig);
    % Get current axis position
    mmCoord = GetLocation('mri', sMri, Handles) .* 1000;
    % Zoom factor
    switch (action)
        case '+',     Factor = 1 ./ 1.5;
        case '-',     Factor = 1.5;
        case 'reset', Factor = 0;
    end
    % Prepare list to process
    hAxesList = [Handles.axs, Handles.axc, Handles.axa];
    axesCoord = [mmCoord([2 3]); mmCoord([1 3]); mmCoord([1 2])];
    % Loop on axes
    for i = 1:length(hAxesList)
        hAxes = hAxesList(i);
        % Get initial axis limits
        XLimInit = getappdata(hAxes, 'XLimInit');
        YLimInit = getappdata(hAxes, 'YLimInit');
        % Get current axis limits
        XLim = get(hAxes, 'XLim');
        YLim = get(hAxes, 'YLim');
        % Get new window length
        XLim = axesCoord(i,1) + (XLim(2)-XLim(1)) * Factor * [-.5, .5];
        YLim = axesCoord(i,2) + (YLim(2)-YLim(1)) * Factor * [-.5, .5];
        Len = [XLim(2)-XLim(1), YLim(2)-YLim(1)];
        % Get orientation labels
        hLabelOrientL = findobj(hAxes, '-depth', 1, 'Tag', 'LabelOrientL');
        hLabelOrientR = findobj(hAxes, '-depth', 1, 'Tag', 'LabelOrientR');
        % If window length is larger that initial: restore initial
        if any(Len == 0) || ((Len(1) >= XLimInit(2)-XLimInit(1)) || (Len(2) >= YLimInit(2)-YLimInit(1))) || (abs(Len(1) - (XLimInit(2)-XLimInit(1))) < 1e-2) || (abs(Len(2) - YLimInit(2)-YLimInit(1)) < 1e-2)
            XLim = XLimInit;
            YLim = YLimInit;
            % Restore orientation labels
            %set(hLabelOrient, 'Visible', 'on');
        else
            % Move view to have a full image (X)
            if (XLim(1) < XLimInit(1))
                XLim = XLimInit(1) + [0, Len(1)];
            elseif (XLim(2) > XLimInit(2))
                XLim = XLimInit(2) + [-Len(1), 0];
            end
            % Move view to have a full image (Y)
            if (YLim(1) < YLimInit(1))
                YLim = YLimInit(1) + [0, Len(2)];
            elseif (YLim(2) > YLimInit(2))
                YLim = YLimInit(2) + [-Len(2), 0];
            end
            % Hide orientation labels
            %set(hLabelOrient, 'Visible', 'off');
        end
        % Update zoom factor
        set(hAxes, 'XLim', XLim, 'YLim', YLim);
        % Move orientation labels
        set(hLabelOrientL, 'Position', [XLim(1) + .05*(XLim(2)-XLim(1)), YLim(1) + .05*(YLim(2)-YLim(1)), 1]);
        set(hLabelOrientR, 'Position', [XLim(1) + .95*(XLim(2)-XLim(1)), YLim(1) + .05*(YLim(2)-YLim(1)), 1]);
    end
end

%% ===== BUTTON SET COORDINATES =====
function ButtonSetCoordinates_Callback(hFig)
    % Get coordinates from the user
    res = java_dialog('input', {'<HTML>Enter the [x,y,z] coordinates in only one <BR>of the coordinate systems below.<BR><BR>MRI coordinates (millimeters):', 'SCS coordinates (millimeters)', 'MNI coordinates (millimeters)'}, 'Set coordinates', [], {'', '', ''});
    % If user cancelled: return
    if isempty(res) || (length(res) < 3)
        return
    end
    % Get new values
    MRI = str2num(res{1}) / 1000;
    SCS = str2num(res{2}) / 1000;
    MNI = str2num(res{3}) / 1000;
    
    % Get Mri and figure Handles
    sMri = panel_surface('GetSurfaceMri', hFig);
    Handles = bst_figures('GetFigureHandles', hFig);
    % MRI coordinates
    if (length(MRI) == 3)
        % Keep MRI values unchanged
    % SCS coordinates
    elseif (length(SCS) == 3)
        MRI = cs_convert(sMri, 'scs', 'mri', SCS);
    % MNI coordinates
    elseif (length(MNI) == 3)
        MRI = cs_convert(sMri, 'mni', 'mri', MNI);
    else
        return;
    end
    % Error message
    if isempty(MRI)
        bst_error('The requested coordinates system is not available.', 'Coordinates conversions', 0);
        return;
    end
    % Move the slices
    SetLocation('mri', sMri, Handles, MRI);
end


%% =======================================================================================
%  ===== EXTERNAL CALLBACKS ==============================================================
%  =======================================================================================
%% ===== COLORMAP CHANGED =====
% Usage:  ColormapChangedCallback(iDS, iFig) 
function ColormapChangedCallback(iDS, iFig) %#ok<DEFNU>
    global GlobalData;
    panel_surface('UpdateSurfaceColormap', GlobalData.DataSet(iDS).Figure(iFig).hFigure);
end


%% ===== POPUP MENU =====
% Show a popup dialog
function DisplayFigurePopup(hFig)
    import java.awt.event.KeyEvent;
    import javax.swing.KeyStroke;
    import org.brainstorm.icon.*;
    
    % Create popup menu
    jPopup = java_create('javax.swing.JPopupMenu');
    % Get figure options
    ColormapInfo = getappdata(hFig, 'Colormap');
    isOverlay = any(ismember({'source','stat1','stat2','timefreq'}, ColormapInfo.AllTypes));
    Handles = bst_figures('GetFigureHandles', hFig);
        
    % ==== Menu colormaps ====
    % Create the colormaps menus
    bst_colormaps('CreateAllMenus', jPopup, hFig, 0);
    
    % === MRI Options ===
    % Smooth factor
    if isOverlay 
        jMenuMri = gui_component('Menu', jPopup, [], 'Smooth sources', IconLoader.ICON_ANATOMY, [], [], []);
        MriOptions = bst_get('MriOptions');
        jItem0 = gui_component('radiomenuitem', jMenuMri, [], 'None', [], [], @(h,ev)figure_3d('SetMriSmooth', hFig, 0), []);
        jItem1 = gui_component('radiomenuitem', jMenuMri, [], '1',    [], [], @(h,ev)figure_3d('SetMriSmooth', hFig, 1), []);
        jItem2 = gui_component('radiomenuitem', jMenuMri, [], '2',    [], [], @(h,ev)figure_3d('SetMriSmooth', hFig, 2), []);
        jItem3 = gui_component('radiomenuitem', jMenuMri, [], '3',    [], [], @(h,ev)figure_3d('SetMriSmooth', hFig, 3), []);
        jItem4 = gui_component('radiomenuitem', jMenuMri, [], '4',    [], [], @(h,ev)figure_3d('SetMriSmooth', hFig, 4), []);
        jItem5 = gui_component('radiomenuitem', jMenuMri, [], '5',    [], [], @(h,ev)figure_3d('SetMriSmooth', hFig, 5), []);
        jItem0.setSelected(MriOptions.OverlaySmooth == 0);
        jItem1.setSelected(MriOptions.OverlaySmooth == 1);
        jItem2.setSelected(MriOptions.OverlaySmooth == 2);
        jItem3.setSelected(MriOptions.OverlaySmooth == 3);
        jItem4.setSelected(MriOptions.OverlaySmooth == 4);
        jItem5.setSelected(MriOptions.OverlaySmooth == 5);
    end
    jPopup.addSeparator();
    % Set fiducials
    if Handles.isEditFiducials
        gui_component('MenuItem', jPopup, [], 'Edit fiducial positions', IconLoader.ICON_EDIT, [], @(h,ev)EditFiducials(hFig), []);
        gui_component('MenuItem', jPopup, [], 'Save fiducial file', IconLoader.ICON_EDIT, [], @(h,ev)SaveFiducialsFile(hFig), []);
        jPopup.addSeparator();
    end

    % ==== MENU ELECTRODES ====
    if Handles.isEeg
        jMenu = gui_component('Menu', jPopup, [], 'Electrodes', IconLoader.ICON_CHANNEL, [], [], []);
        % Set position
        jItem = gui_component('MenuItem', jMenu, [], 'Set electrode position',  IconLoader.ICON_CHANNEL, [], @(h,ev)SetElectrodePosition(hFig), []);      
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_S, KeyEvent.CTRL_MASK));
        jPopup.addSeparator();
        % Align SEEG electrodes
        Modality = Handles.ChannelMat.Channel(Handles.iChannels(1)).Type;
        if strcmpi(Modality, 'SEEG')
            jMenu.addSeparator();
            jItem = gui_component('MenuItem', jMenu, [], 'Align all contacts in a group',  IconLoader.ICON_CHANNEL, [], @(h,ev)AlignElectrodes_Callback(hFig, 'all'), []);
            jItem = gui_component('MenuItem', jMenu, [], 'Define group with first and second contacts',  IconLoader.ICON_CHANNEL, [], @(h,ev)AlignElectrodes_Callback(hFig, 'first_second'), []);
            jItem = gui_component('MenuItem', jMenu, [], 'Define group with first and last contacts',  IconLoader.ICON_CHANNEL, [], @(h,ev)AlignElectrodes_Callback(hFig, 'first_last'), []);
        elseif strcmpi(Modality, 'ECOG')
            jMenu.addSeparator();
            jItem = gui_component('MenuItem', jMenu, [], 'Define strip: First and last contacts',  IconLoader.ICON_CHANNEL, [], @(h,ev)AlignElectrodes_Callback(hFig, 1), []);
            jItem = gui_component('MenuItem', jMenu, [], 'Define grid: First and last contacts',   IconLoader.ICON_CHANNEL, [], @(h,ev)AlignElectrodes_Callback(hFig, 2), []);
            jItem = gui_component('MenuItem', jMenu, [], 'Define grid: 4 corner contacts',         IconLoader.ICON_CHANNEL, [], @(h,ev)AlignElectrodes_Callback(hFig, 4), []);
        end
        % Display labels
        jMenu.addSeparator();
        jItem = gui_component('CheckBoxMenuItem', jMenu, [], 'Display labels',  IconLoader.ICON_CHANNEL_LABEL, [], @(h,ev)SetLabelVisible(hFig, ~Handles.isEegLabels), []);
        jItem.setSelected(Handles.isEegLabels);
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_E, KeyEvent.CTRL_MASK)); 
    end
    
    jMenuView = gui_component('Menu', jPopup, [], 'Views', IconLoader.ICON_AXES, [], [], []);
        jItem = gui_component('MenuItem', jMenuView, [], 'Apply MNI coordinates to all figures', [], [], @(h,ev)ApplyCoordsToAllFigures(hFig, 'mni'), []);
        jItem.setAccelerator(KeyStroke.getKeyStroke('=', 0));
        jItem = gui_component('MenuItem', jMenuView, [], 'Apply SCS coordinates to all figures', [], [], @(h,ev)ApplyCoordsToAllFigures(hFig, 'scs'), []);
        jItem.setAccelerator(KeyStroke.getKeyStroke('*', 0));
    
    % ==== Menu SNAPSHOT ====
    jMenuSave = gui_component('Menu', jPopup, [], 'Snapshot', IconLoader.ICON_SNAPSHOT, [], [], []);
        % Default output dir
        LastUsedDirs = bst_get('LastUsedDirs');
        DefaultOutputDir = LastUsedDirs.ExportImage;
        % === SAVE AS IMAGE ===
        jItem = gui_component('MenuItem', jMenuSave, [], 'Save as image', IconLoader.ICON_SAVE, [], @(h,ev)out_figure_image(hFig), []);
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_I, KeyEvent.CTRL_MASK));
        % === OPEN AS IMAGE ===
        jItem = gui_component('MenuItem', jMenuSave, [], 'Open as image', IconLoader.ICON_IMAGE, [], @(h,ev)out_figure_image(hFig, 'Viewer'), []);
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_J, KeyEvent.CTRL_MASK));
        % === CONTACT SHEETS ===
        if ~getappdata(hFig, 'isStatic')
            % Separator
            jMenuSave.addSeparator();
            gui_component('MenuItem', jMenuSave, [], 'Movie (time): Selected figure', IconLoader.ICON_MOVIE, [], @(h,ev)out_figure_movie(hFig, DefaultOutputDir, 'time'), []);
            gui_component('MenuItem', jMenuSave, [], 'Movie (time): All figures',     IconLoader.ICON_MOVIE, [], @(h,ev)out_figure_movie(hFig, DefaultOutputDir, 'allfig'), []);
            jMenuSave.addSeparator();
            gui_component('MenuItem', jMenuSave, [], 'Time contact sheet: Coronal',  IconLoader.ICON_CONTACTSHEET, [], @(h,ev)view_contactsheet(hFig, 'time', 'y', DefaultOutputDir), []);
            gui_component('MenuItem', jMenuSave, [], 'Time contact sheet: Sagittal', IconLoader.ICON_CONTACTSHEET, [], @(h,ev)view_contactsheet(hFig, 'time', 'x', DefaultOutputDir), []);
            gui_component('MenuItem', jMenuSave, [], 'Time contact sheet: Axial',    IconLoader.ICON_CONTACTSHEET, [], @(h,ev)view_contactsheet(hFig, 'time', 'z', DefaultOutputDir), []);
        end
        jMenuSave.addSeparator();
        gui_component('MenuItem', jMenuSave, [], 'Volume contact sheet: Coronal',  IconLoader.ICON_CONTACTSHEET, [], @(h,ev)view_contactsheet(hFig, 'volume', 'y', DefaultOutputDir), []);
        gui_component('MenuItem', jMenuSave, [], 'Volume contact sheet: Sagittal', IconLoader.ICON_CONTACTSHEET, [], @(h,ev)view_contactsheet(hFig, 'volume', 'x', DefaultOutputDir), []);
        gui_component('MenuItem', jMenuSave, [], 'Volume contact sheet: Axial',    IconLoader.ICON_CONTACTSHEET, [], @(h,ev)view_contactsheet(hFig, 'volume', 'z', DefaultOutputDir), []);
        % === SAVE OVERLAY ===
        if isOverlay
            jMenuSave.addSeparator();
            gui_component('MenuItem', jMenuSave, [], 'Save overlay as MRI',  IconLoader.ICON_SAVE, [], @(h,ev)ExportOverlay(hFig), []);
        end       
        
    % ==== MENU FIGURE ====
    jMenuFigure = gui_component('Menu', jPopup, [], 'Figure', IconLoader.ICON_LAYOUT_SHOWALL, [], [], []);
        % Edit fiducials
        jItem = gui_component('CheckBoxMenuItem', jMenuFigure, [], 'Edit fiducials', IconLoader.ICON_ANATOMY, [], @(h,ev)SetFigureStatus(hFig, ~Handles.isEditFiducials, [], [], [], 1), []);
        jItem.setSelected(Handles.isEditFiducials);
        % Edit volume
        jItem = gui_component('CheckBoxMenuItem', jMenuFigure, [], 'Edit volume', IconLoader.ICON_ANATOMY, [], @(h,ev)SetFigureStatus(hFig, [], ~Handles.isEditVolume, [], [], 1), []);
        jItem.setSelected(Handles.isEditVolume);
    % ==== Display menu ====
    gui_popup(jPopup, hFig);
end

%% =======================================================================================
%  ===== MRI FUNCTIONS ===================================================================
%  =======================================================================================    
%% ===== SETUP MRI =====
function [sMri, Handles] = SetupMri(hFig)
    global GlobalData;
    % Get Mri and figure Handles
    [sMri, TessInfo, iTess, iMri] = panel_surface('GetSurfaceMri', hFig);
    Handles = bst_figures('GetFigureHandles', hFig);
    
    % ===== PREPARE DISPLAY =====
    cubeSize = size(sMri.Cube);
    FOV      = cubeSize .* sMri.Voxsize;
    % Empty axes
    cla(Handles.axs);
    cla(Handles.axc);
    cla(Handles.axa);
    % Sagittal
    [Handles.imgs_mri, Handles.crosshairSagittalH, Handles.crosshairSagittalV] = ...
        SetupView(Handles.axs, [FOV(2),FOV(3)], [cubeSize(3),cubeSize(2)], {'P','A'});
    % Coronal
    [Handles.imgc_mri, Handles.crosshairCoronalH, Handles.crosshairCoronalV] = ...
        SetupView(Handles.axc, [FOV(1),FOV(3)], [cubeSize(3),cubeSize(1)], {'L','R'});
    % Axial 
    [Handles.imga_mri, Handles.crosshairAxialH, Handles.crosshairAxialV] = ...
        SetupView(Handles.axa, [FOV(1),FOV(2)], [cubeSize(2),cubeSize(1)], {'L','R'});
    % Save Handles
    bst_figures('SetFigureHandles', hFig, Handles);
    % Save slices Handles in the surface
    TessInfo(iTess).hPatch = [Handles.imgs_mri, Handles.imgc_mri, Handles.imga_mri];
    setappdata(hFig, 'Surface', TessInfo);

    % === SET MOUSE CALLBACKS ===
    set(hFig, 'ButtonDownFcn', @(h,ev)MouseButtonDownAxes_Callback(hFig,[],sMri,Handles));
    set([Handles.axa, Handles.imga_mri, Handles.crosshairAxialH,    Handles.crosshairAxialV],    'ButtonDownFcn', @(h,ev)MouseButtonDownAxes_Callback(hFig,Handles.axa, sMri, Handles));
    set([Handles.axs, Handles.imgs_mri, Handles.crosshairSagittalH, Handles.crosshairSagittalV], 'ButtonDownFcn', @(h,ev)MouseButtonDownAxes_Callback(hFig,Handles.axs, sMri, Handles));
    set([Handles.axc, Handles.imgc_mri, Handles.crosshairCoronalH,  Handles.crosshairCoronalV],  'ButtonDownFcn', @(h,ev)MouseButtonDownAxes_Callback(hFig,Handles.axc, sMri, Handles));
    % Register MouseMoved and MouseButtonUp callbacks for current figure
    set(hFig, 'WindowButtonDownFcn',   @(h,ev)MouseButtonDownFigure_Callback(hFig, sMri, Handles), ...
              'WindowButtonMotionFcn', @(h,ev)MouseMove_Callback(hFig, sMri, Handles), ...
              'WindowButtonUpFcn',     @(h,ev)MouseButtonUp_Callback(hFig, sMri, Handles) );
    % Define Mouse wheel callback (not supported by old versions of Matlab)
    if isprop(hFig, 'WindowScrollWheelFcn')
        set(hFig, 'WindowScrollWheelFcn', @(h,ev)MouseWheel_Callback(hFig, sMri, Handles, ev));
    end
    
    % === LOAD LANDMARKS ===
    % Load landmarks/fiducials
    [sMri, Handles] = LoadLandmarks(sMri, Handles);
    % Save mri and Handles
    GlobalData.Mri(iMri) = sMri;
    bst_figures('SetFigureHandles', hFig, Handles);
    
    % === CONFIGURE SLIDERS ===
    jSliders = [Handles.jSliderSagittal, Handles.jSliderCoronal, Handles.jSliderAxial];
    % Reset sliders callbacks
    java_setcb(jSliders, 'StateChangedCallback', []);
    % Configure each slider
    for i = 1:3
        % Set min and max bounds
        jSliders(i).setMinimum(1);
        jSliders(i).setMaximum(cubeSize(i));
    end
    % Set default location to middle of the volume
    SetLocation('voxel', sMri, Handles, TessInfo(iTess).CutsPosition);
    % Set sliders callback
    for i = 1:3
        java_setcb(jSliders(i), 'StateChangedCallback', @(h,ev)sliderClicked_Callback(hFig,i,ev));
    end
end


%% ===== SETUP A VIEW =====
function [hImgMri, hCrossH, hCrossV] = SetupView(hAxes, xySize, imgSize, orientLabels)
    % MRI image
    hImgMri = image('XData',        [1, xySize(1)], ...
                    'YData',        [1, xySize(2)], ...
                    'CData',        zeros(imgSize(1), imgSize(2)), ...
                    'CDataMapping', 'scaled', ...
                    'Parent',       hAxes);
    % Define axes limits
    XLim = [0 xySize(1)] + 0.5;
    YLim = [0 xySize(2)] + 0.5;
    set(hAxes, 'XLim', XLim, 'YLim', YLim);
    % Crosshair
    hCrossH = line(XLim, [1 1], [2, 2], 'Color', [.8 .8 .8], 'Parent', hAxes);
    hCrossV = line([1,1], YLim, [2, 2], 'Color', [.8 .8 .8], 'Parent', hAxes);
    % Orientation markers
    fontSize = bst_get('FigFont');
    text(XLim(1) + .05*(XLim(2)-XLim(1)), YLim(1) + .05*(YLim(2)-YLim(1)), orientLabels{1}, 'verticalalignment', 'top', 'FontSize', fontSize, 'FontUnits', 'points', 'color','w', 'Parent', hAxes, 'Tag', 'LabelOrientL');
    text(XLim(1) + .95*(XLim(2)-XLim(1)), YLim(1) + .05*(YLim(2)-YLim(1)), orientLabels{2}, 'verticalalignment', 'top', 'FontSize', fontSize, 'FontUnits', 'points', 'color','w', 'Parent', hAxes, 'Tag', 'LabelOrientR');
    % Save initial axis limits
    setappdata(hAxes, 'XLimInit', XLim);
    setappdata(hAxes, 'YLimInit', YLim);
end



%% ===== SLICES LOCATION =====
% GET: MRI COORDINATES
function XYZ = GetLocation(cs, sMri, Handles)
    % Get MRI coordinates of current point in volume
    XYZ(1) = Handles.jSliderSagittal.getValue();
    XYZ(2) = Handles.jSliderCoronal.getValue();
    XYZ(3) = Handles.jSliderAxial.getValue();
    % Convert if necessary
    if ~strcmpi(cs, 'voxel')
        XYZ = cs_convert(sMri, 'voxel', cs, XYZ);
    end
end

% SET: MRI COORDINATES
% Usage:  SetLocation(cs, sMri, Handles, XYZ)
%         SetLocation(cs, hFig,      [], XYZ)
function SetLocation(cs, sMri, Handles, XYZ)
    % If inputs are not defined
    if ~isstruct(sMri)
        hFig = sMri;
        sMri = panel_surface('GetSurfaceMri', hFig);
        Handles = bst_figures('GetFigureHandles', hFig);
    end
    % Convert if necessary
    if ~strcmpi(cs, 'voxel')
        XYZ = cs_convert(sMri, cs, 'voxel', XYZ);
    end
    % Get that values are inside volume bounds
    XYZ(1) = bst_saturate(XYZ(1), [1, size(sMri.Cube,1)]);
    XYZ(2) = bst_saturate(XYZ(2), [1, size(sMri.Cube,2)]);
    XYZ(3) = bst_saturate(XYZ(3), [1, size(sMri.Cube,3)]);
    % Round coordinates
    XYZ = round(XYZ);
    % Set sliders values
    Handles.jSliderSagittal.setValue(XYZ(1));
    Handles.jSliderCoronal.setValue(XYZ(2));
    Handles.jSliderAxial.setValue(XYZ(3));
end


%% ===== MRI ORIENTATION =====
% ===== ROTATION =====
function MriTransform(hButton, Transf, iDim)
    global GlobalData;
    if (nargin < 3)
        iDim = [];
    end
    % Progress bar
    bst_progress('start', 'MRI Viewer', 'Updating MRI...');
    % Get figure
    hFig = ancestor(hButton,'figure');
    % Get Mri and figure Handles
    [sMri, TessInfo, iTess, iMri] = panel_surface('GetSurfaceMri', hFig);
    % Prepare the history of transformations
    if isempty(sMri.InitTransf)
        sMri.InitTransf = cell(0,2);
    end
    % Type of transformation
    switch(Transf)
        case 'Rotate'
            switch iDim
                case 1
                    % Permutation of dimensions Y/Z
                    sMri.Cube = permute(sMri.Cube, [1 3 2]);
                    sMri.InitTransf(end+1,[1 2]) = {'permute', [1 3 2]};
                    % Flip / Z
                    sMri.Cube = bst_flip(sMri.Cube, 3);
                    sMri.InitTransf(end+1,[1 2]) = {'flipdim', [3 size(sMri.Cube,3)]};
                    % Update voxel size
                    sMri.Voxsize = sMri.Voxsize([1 3 2]);
                case 2
                    % Permutation of dimensions X/Z
                    sMri.Cube = permute(sMri.Cube, [3 2 1]);
                    sMri.InitTransf(end+1,[1 2]) = {'permute', [3 2 1]};
                    % Flip / Z
                    sMri.Cube = bst_flip(sMri.Cube, 3);
                    sMri.InitTransf(end+1,[1 2]) = {'flipdim', [3 size(sMri.Cube,3)]};
                    % Update voxel size
                    sMri.Voxsize = sMri.Voxsize([3 2 1]);
                case 3
                    % Permutation of dimensions X/Y
                    sMri.Cube = permute(sMri.Cube, [2 1 3]);
                    sMri.InitTransf(end+1,[1 2]) = {'permute', [2 1 3]};
                    % Flip / Y
                    sMri.Cube = bst_flip(sMri.Cube, 2);
                    sMri.InitTransf(end+1,[1 2]) = {'flipdim', [2 size(sMri.Cube,2)]};
                    % Update voxel size
                    sMri.Voxsize = sMri.Voxsize([2 1 3]);
            end
        case 'Flip'
            % Flip MRI cube
            sMri.Cube = bst_flip(sMri.Cube, iDim);
            sMri.InitTransf(end+1,[1 2]) = {'flipdim', [iDim size(sMri.Cube,iDim)]};
        case 'Permute'
            % Permute MRI dimensions
            sMri.Cube = permute(sMri.Cube, [3 1 2]);
            sMri.InitTransf(end+1,[1 2]) = {'permute', [3 1 2]};
            % Update voxel size
            sMri.Voxsize = sMri.Voxsize([3 1 2]);
    end
    % Update MRI
    GlobalData.Mri(iMri) = sMri;
    % Redraw slices
    [sMri, Handles] = SetupMri(hFig);
    [sMri, Handles] = LoadLandmarks(sMri, Handles);
    % History: add operation
    if ~isempty(iDim)
        historyComment = [Transf ': dimension ' num2str(iDim)];
    else
        historyComment = Transf;
    end
    sMri = bst_history('add', sMri, 'edit', historyComment);
    % Mark MRI as modified
    Handles.isModifiedMri = 1;
    bst_figures('SetFigureHandles', hFig, Handles);
    GlobalData.Mri(iMri) = sMri;
    % Redraw MRI slices
    UpdateMriDisplay(hFig);
    bst_progress('stop');
end


%% =======================================================================================
%  ===== DISPLAY FUNCTIONS ===============================================================
%  =======================================================================================
%% ===== UPDATE MRI DISPLAY =====
% Usage:  UpdateMriDisplay(hFig, dims)
%         UpdateMriDisplay(hFig)
function Handles = UpdateMriDisplay(hFig, dims, varargin)
    % Parse inputs
    if (nargin < 2) || isempty(dims)
        dims = [1 2 3];
    end
    % Get MRI and Handles
    sMri = panel_surface('GetSurfaceMri', hFig);
    Handles = bst_figures('GetFigureHandles', hFig);
    % Get slices locations
    voxXYZ = GetLocation('voxel', sMri, Handles);
    newPos = [NaN,NaN,NaN];
    newPos(dims) = voxXYZ(dims);
    % Redraw slices
    panel_surface('PlotMri', hFig, newPos);
    
    % Display crosshair
    UpdateCrosshairPosition(sMri, Handles);
    % Display fiducials/other landmarks (Not if read only MRI)
    if Handles.isEditFiducials || Handles.isEeg
        UpdateVisibleLandmarks(sMri, Handles, dims);
    end
    % Update coordinates display
    UpdateCoordinates(sMri, Handles);
end

%% ===== UPDATE SURFACE COLOR =====
function UpdateSurfaceColor(hFig, varargin) %#ok<DEFNU>
    UpdateMriDisplay(hFig);
end

%% ===== DISPLAY CROSSHAIR =====
function UpdateCrosshairPosition(sMri, Handles)
    mmCoord = GetLocation('mri', sMri, Handles) .* 1000;
    if isempty(Handles.crosshairSagittalH) || ~ishandle(Handles.crosshairSagittalH)
        return
    end
    % Sagittal
    set(Handles.crosshairSagittalH, 'YData', mmCoord(3) .* [1 1]);
    set(Handles.crosshairSagittalV, 'XData', mmCoord(2) .* [1 1]);
    % Coronal
    set(Handles.crosshairCoronalH, 'YData', mmCoord(3) .* [1 1]);
    set(Handles.crosshairCoronalV, 'XData', mmCoord(1) .* [1 1]);
    % Axial
    set(Handles.crosshairAxialH, 'YData', mmCoord(2) .* [1 1]);
    set(Handles.crosshairAxialV, 'XData', mmCoord(1) .* [1 1]);
end
    

%% ===== DISPLAY COORDINATES =====
function UpdateCoordinates(sMri, Handles)
    % Millimeters (MRI cube coordinates)
    voxXYZ = GetLocation('voxel', sMri, Handles);
    mriXYZ = cs_convert(sMri, 'voxel', 'mri', voxXYZ);
    scsXYZ = cs_convert(sMri, 'voxel', 'scs', voxXYZ);
    mniXYZ = cs_convert(sMri, 'voxel', 'mni', voxXYZ);
    % Update title of images
    Handles.jLabelTitleS.setText(sprintf('<HTML>&nbsp;&nbsp;&nbsp;<B>Sagittal</B>:&nbsp;&nbsp;&nbsp;x=%d', voxXYZ(1)));
    Handles.jLabelTitleA.setText(sprintf('<HTML>&nbsp;&nbsp;&nbsp;<B>Axial</B>:&nbsp;&nbsp;&nbsp;z=%d', voxXYZ(3)));
    Handles.jLabelTitleC.setText(sprintf('<HTML>&nbsp;&nbsp;&nbsp;<B>Coronal</B>:&nbsp;&nbsp;&nbsp;y=%d', voxXYZ(2)));
    % Display value of the selected voxel
    if (all(voxXYZ >= 1) && all(voxXYZ <= size(sMri.Cube)))
        % Try to get the values from the overlay mask
        TessInfo = getappdata(Handles.hFig, 'Surface');
        if ~isempty(TessInfo) && ~isempty(TessInfo.OverlayCube) && all(size(TessInfo.OverlayCube) == size(sMri.Cube))
            value = TessInfo.OverlayCube(voxXYZ(1), voxXYZ(2), voxXYZ(3));
        else
            value = sMri.Cube(voxXYZ(1), voxXYZ(2), voxXYZ(3));
        end
        strValue = sprintf('value=%g', value);
    else
        strValue = '';
    end
    Handles.jLabelValue.setText(strValue);
    % === MRI (millimeters) ===
    Handles.jTextCoordMriX.setText(sprintf('x: %3.1f', mriXYZ(1) * 1000));
    Handles.jTextCoordMriY.setText(sprintf('y: %3.1f', mriXYZ(2) * 1000));
    Handles.jTextCoordMriZ.setText(sprintf('z: %3.1f', mriXYZ(3) * 1000));
    % === SCS/CTF (millimeters) ===
    if ~isempty(scsXYZ)
        Handles.jTextCoordScsX.setText(sprintf('x: %3.1f', scsXYZ(1) * 1000));
        Handles.jTextCoordScsY.setText(sprintf('y: %3.1f', scsXYZ(2) * 1000));
        Handles.jTextCoordScsZ.setText(sprintf('z: %3.1f', scsXYZ(3) * 1000));
    end
    % === MNI coordinates system ===
    if ~isempty(mniXYZ)
        Handles.jTextCoordMniX.setText(sprintf('x: %3.1f', mniXYZ(1) * 1000));
        Handles.jTextCoordMniY.setText(sprintf('y: %3.1f', mniXYZ(2) * 1000));
        Handles.jTextCoordMniZ.setText(sprintf('z: %3.1f', mniXYZ(3) * 1000));
        isMni = 1;
    else
        isMni = 0;
    end
    % Update labels visibility
    Handles.jTextNoMni.setVisible(~isMni);
    Handles.jTextCoordMniX.setVisible(isMni);
    Handles.jTextCoordMniY.setVisible(isMni);
    Handles.jTextCoordMniZ.setVisible(isMni);
end
   
    
    
%% =======================================================================================
%  ===== MOUSE CALLBACKS =================================================================
%  =======================================================================================
%% ===== MOUSE CLICK: AXES =====       
function MouseButtonDownAxes_Callback(hFig, hAxes, sMri, Handles)
    % Double-click: Reset view
    if strcmpi(get(hFig, 'SelectionType'), 'open')
        ButtonZoom_Callback(hFig, 'reset');
        setappdata(hFig,'clickAction','MouseDownOk');
        return;
    end
    % Check if MouseUp was executed before MouseDown
    if isappdata(hFig, 'clickAction') && strcmpi(getappdata(hFig,'clickAction'), 'MouseDownNotConsumed')
        % Should ignore this MouseDown event
        setappdata(hFig,'clickAction','MouseDownOk');
        return;
    end
    % Switch between different types of mouse actions
    clickAction = '';
    switch(get(hFig, 'SelectionType'))
        % Left click
        case 'normal'
            clickAction = 'LeftClick';
            % Move crosshair according to mouse position
            if ~isempty(hAxes)
                MouseMoveCrosshair(hAxes, sMri, Handles);
            end
        % CTRL+Mouse, or Mouse right
        case 'alt'
            clickAction = 'RightClick';
        % SHIFT+Mouse
        case 'extend'
            clickAction = 'ShiftClick';
    end
    % If no action was defined : nothing to do more
    if isempty(clickAction)
        return
    end
    
    % Reset the motion flag
    setappdata(hFig, 'hasMoved', 0);
    % Record mouse location in the figure coordinates system
    setappdata(hFig, 'clickAction', clickAction);
    setappdata(hFig, 'clickSource', hAxes);
    setappdata(hFig, 'clickPositionFigure', get(hFig, 'CurrentPoint'));
end


%% ===== MOUSE CLICK: FIGURE =====
function MouseButtonDownFigure_Callback(hFig, varargin)
    setappdata(hFig, 'clickPositionFigure', get(hFig, 'CurrentPoint'));
end

    
%% ===== MOUSE MOVE =====
function MouseMove_Callback(hFig, sMri, Handles) 
    % Get mouse actions
    clickSource = getappdata(hFig, 'clickSource');
    clickAction = getappdata(hFig, 'clickAction');
    if isempty(clickAction)
        return
    end
    % If MouseUp was executed before MouseDown
    if strcmpi(clickAction, 'MouseDownNotConsumed') || isempty(getappdata(hFig, 'clickPositionFigure'))
        % Ignore Move event
        return
    end
    % Set that mouse has moved
    setappdata(hFig, 'hasMoved', 1);
    % Get current mouse location in figure
    curptFigure = get(hFig, 'CurrentPoint');
    motionFigure = 0.3 * (curptFigure - getappdata(hFig, 'clickPositionFigure'));
    % Update click point location
    setappdata(hFig, 'clickPositionFigure', curptFigure);
    switch (clickAction)
        case 'LeftClick'
            if isempty(clickSource)
                return
            end
            hAxes = clickSource;
            % Move slices according to mouse position
            MouseMoveCrosshair(hAxes, sMri, Handles);
        case 'RightClick'
            % Define contrast/brightness transform
            modifContrast   = motionFigure(2)  .* .7 ./ 100;
            modifBrightness = -motionFigure(2) ./ 100;
            % Changes contrast
            sColormap = bst_colormaps('ColormapChangeModifiers', 'Anatomy', [modifContrast, modifBrightness], 0);
            set(hFig, 'Colormap', sColormap.CMap);
            % Display immediately changes if no results displayed
            ResultsFile = getappdata(hFig, 'ResultsFile');
            if isempty(ResultsFile)
                bst_colormaps('FireColormapChanged', 'Anatomy');
            end
        case 'colorbar'
            % Changes contrast
            ColormapInfo = getappdata(hFig, 'Colormap');
            sColormap = bst_colormaps('ColormapChangeModifiers', ColormapInfo.Type, [motionFigure(1), motionFigure(2)] ./ 100, 0);
            set(hFig, 'Colormap', sColormap.CMap);
    end
end

%% ===== MOUSE BUTTON UP =====       
function MouseButtonUp_Callback(hFig, varargin) 
    hasMoved = getappdata(hFig, 'hasMoved');
    clickAction = getappdata(hFig, 'clickAction');
    
    % Mouse was not moved during click
    if ~isempty(clickAction)
        if ~hasMoved
            switch (clickAction)
                case 'RightClick'
                    DisplayFigurePopup(hFig);
            end
        % Mouse was moved
        else
            switch (clickAction)
                case {'colorbar', 'RightClick'}
                    % Apply new colormap to all figures
                    ColormapInfo = getappdata(hFig, 'Colormap');
                    bst_colormaps('FireColormapChanged', ColormapInfo.Type);
            end
        end
    end
    % Set figure as current figure
    bst_figures('SetCurrentFigure', hFig, '3D');
    if isappdata(hFig, 'Timefreq') && ~isempty(getappdata(hFig, 'Timefreq'))
        bst_figures('SetCurrentFigure', hFig, 'TF');
    end
    
    % Remove mouse callbacks appdata
    if isappdata(hFig, 'clickPositionFigure')
        rmappdata(hFig, 'clickPositionFigure');
    end
    if isappdata(hFig, 'clickSource')
        rmappdata(hFig, 'clickSource');
    end
    if isappdata(hFig, 'clickAction')
        rmappdata(hFig, 'clickAction');
    else
        setappdata(hFig, 'clickAction', 'MouseDownNotConsumed');
    end
    setappdata(hFig, 'hasMoved', 0);
end


%% ===== FIGURE MOUSE WHEEL =====
function MouseWheel_Callback(hFig, sMri, Handles, event) 
    % Get amount of scroll
    if isempty(event)
        return;
    elseif isnumeric(event)
        scrollCout = event;
    else
        scrollCout = event.VerticalScrollCount;
    end
    % Get which axis is selected
    hAxes = get(hFig, 'CurrentAxes');
    if isempty(hAxes)
        return
    end
    % Get handles and MRI
    if isempty(sMri)
        sMri = panel_surface('GetSurfaceMri', hFig);
    end
    if isempty(Handles)
        Handles = bst_figures('GetFigureHandles', hFig);
    end
    % Get dimension corresponding to this axes
    switch (hAxes)
        case Handles.axs,  dim = 1;
        case Handles.axc,  dim = 2;  
        case Handles.axa,  dim = 3; 
        otherwise,         return;
    end
    % Get current position
    XYZ = GetLocation('voxel', sMri, Handles);
    % Update location
    XYZ(dim) = XYZ(dim) - double(scrollCout);
    SetLocation('voxel', sMri, Handles, XYZ);
end
    
%% ===== MOVE CROSSHAIR =====
function MouseMoveCrosshair(hAxes, sMri, Handles)
    % Get mouse 2D position
    mouse2DPos = get(hAxes, 'CurrentPoint');
    mouse2DPos = [mouse2DPos(1,1), mouse2DPos(1,2)] ./ 1000;
    % Get current slices
    slicesXYZ = GetLocation('mri', sMri, Handles);
    % Get 3D mouse position 
    mouse3DPos = [0 0 0];
    switch hAxes
        case Handles.axs
            mouse3DPos(1) = slicesXYZ(1);
            mouse3DPos(2) = mouse2DPos(1);
            mouse3DPos(3) = mouse2DPos(2);
        case Handles.axc
            mouse3DPos(2) = slicesXYZ(2);
            mouse3DPos(1) = mouse2DPos(1);
            mouse3DPos(3) = mouse2DPos(2);
        case Handles.axa
            mouse3DPos(3) = slicesXYZ(3);
            mouse3DPos(1) = mouse2DPos(1);
            mouse3DPos(2) = mouse2DPos(2);
    end
    % Convert to voxels
    voxPos = cs_convert(sMri, 'mri', 'voxel', mouse3DPos);
    % Limit values to MRI cube
    mriSize = size(sMri.Cube);
    voxPos(1) = min(max(voxPos(1), 1), mriSize(1));
    voxPos(2) = min(max(voxPos(2), 1), mriSize(2));
    voxPos(3) = min(max(voxPos(3), 1), mriSize(3));
    % Set new slices location
    SetLocation('voxel', sMri, Handles, voxPos);
end

    
%% =======================================================================================
%  ===== LANDMARKS SELECTION =============================================================
%  =======================================================================================
%% ===== LOAD LANDMARKS =====
function [sMri, Handles] = LoadLandmarks(sMri, Handles)
    PtsColors = [0 .5 0;   0 .8 0;   .4 1 .4;   1 0 0;   1 .5 0;   1 1 0;   .8 0 .8];
    % Nasion
    [sMri,Handles] = LoadFiducial(sMri, Handles, 'SCS', 'NAS', PtsColors(1,:), Handles.jButtonNasView, Handles.jTitleNAS, 'hPointNAS');
    [sMri,Handles] = LoadFiducial(sMri, Handles, 'SCS', 'LPA', PtsColors(2,:), Handles.jButtonLpaView, Handles.jTitleLPA, 'hPointLPA');
    [sMri,Handles] = LoadFiducial(sMri, Handles, 'SCS', 'RPA', PtsColors(3,:), Handles.jButtonRpaView, Handles.jTitleRPA, 'hPointRPA');
    [sMri,Handles] = LoadFiducial(sMri, Handles, 'NCS', 'AC',  PtsColors(4,:), Handles.jButtonAcView,  Handles.jTitleAC,  'hPointAC');
    [sMri,Handles] = LoadFiducial(sMri, Handles, 'NCS', 'PC',  PtsColors(5,:), Handles.jButtonPcView,  Handles.jTitlePC,  'hPointPC');
    [sMri,Handles] = LoadFiducial(sMri, Handles, 'NCS', 'IH',  PtsColors(6,:), Handles.jButtonIhView,  Handles.jTitleIH,  'hPointIH');

    % ===== SCS transformation =====
    if ~isempty(sMri.SCS.NAS) && ~isempty(sMri.SCS.LPA) && ~isempty(sMri.SCS.RPA)
        % Compute transformation
        scsTransf = cs_compute(sMri, 'scs');
        % Copy to MRI structure
        if ~isempty(scsTransf)            
            sMri.SCS.R      = scsTransf.R;
            sMri.SCS.T      = scsTransf.T;
            sMri.SCS.Origin = scsTransf.Origin;
        else
            bst_error('Impossible to identify the SCS coordinate system with the specified coordinates.', 'MRI Viewer', 0);
        end
    end
    % Update landmarks display
    if Handles.isEditFiducials || Handles.isEeg
        UpdateVisibleLandmarks(sMri, Handles);
    end
    % Update coordinates displayed in the bottom-right panel
    UpdateCoordinates(sMri, Handles);
end


%% ===== LOAD FIDUCIAL =====
function [sMri,Handles] = LoadFiducial(sMri, Handles, FidCategory, FidName, FidColor, jButton, jTitle, PtHandleName)
    % If point is not selected yet
    if ~isfield(sMri.(FidCategory), FidName) || isempty(sMri.(FidCategory).(FidName))
        % Mark that point is not selected yet
        sMri.(FidCategory).(FidName) = [];
        jButton.setEnabled(0);
        jButton.setBackground(java.awt.Color(0, 0, 0));
        jTitle.setForeground(java.awt.Color(.9, 0, 0));
    else
        % Mark that point was selected
        jButton.setEnabled(1);
        jButton.setBackground(java.awt.Color(FidColor(1), FidColor(2), FidColor(3)));
        jTitle.setForeground(java.awt.Color(.94, .94, .94));
        % If point already exist : delete it
        if ~isempty(Handles.(PtHandleName))
            delete(Handles.(PtHandleName)(ishandle(Handles.(PtHandleName))));
        end
        % Create a marker object for this point
        Handles.(PtHandleName) = PlotPoint(sMri, Handles, sMri.(FidCategory).(FidName), FidColor, 7);
    end
end


%% ===== LOAD ELECTRODES =====
function LoadElectrodes(hFig, ChannelFile, Modality) %#ok<DEFNU>
    % Get figure handles
    Handles = bst_figures('GetFigureHandles', hFig);
    % Load the channel file
    ChannelMat = in_bst_channel(ChannelFile);
    iChannels = channel_find(ChannelMat.Channel, Modality);
    if isempty(iChannels)
        disp(['BST> Error: No "' Modality '" channels to display.']);
        return;
    end
    % Channel file
    Handles.ChannelFile = ChannelFile;
    Handles.ChannelMat  = ChannelMat;
    Handles.iChannels   = iChannels;
    % Plot electrodes
    Handles = PlotElectrodes(hFig, Handles);
    % Update figure Handles
    bst_figures('SetFigureHandles', hFig, Handles);
    % Set EEG flag
    SetFigureStatus(hFig, [], [], [], 1, 1);
end


%% ===== PLOT ELECTRODES =====
function Handles = PlotElectrodes(hFig, Handles, isReset)
    % Parse input
    if (nargin < 3) || isempty(isReset)
        isReset = 0;
    end
    % Get Mri and figure Handles
    sMri = panel_surface('GetSurfaceMri', hFig);
    % Delete existing points
    if isReset
        delete(Handles.hPointEEG(ishandle(Handles.hPointEEG)));
        delete(Handles.hTextEEG(ishandle(Handles.hTextEEG)));
        Handles.hPointEEG = [];
        Handles.hTextEEG = [];
    end
    % SEEG/ECOG: Get the sensor groups available and simplify the names of the sensors
    if ismember(upper(Handles.ChannelMat.Channel(Handles.iChannels(1)).Type), {'SEEG', 'ECOG'})
        [iGroupEeg, GroupNames, sensorNames] = panel_montage('GetEegGroups', Handles.ChannelMat.Channel(Handles.iChannels), [], 1);
    else
        sensorNames = {Handles.ChannelMat.Channel(Handles.iChannels).Name}';
    end
    % Loop on all the channels to create the graphic objects
    for i = 1:length(Handles.iChannels)
        % Get electrode position
        Handles.LocEEG(i,:) = cs_convert(sMri, 'scs', 'mri', Handles.ChannelMat.Channel(Handles.iChannels(i)).Loc(:,1)')' .* 1000;
        % Plot electrode
        if (i <= size(Handles.hPointEEG,1)) && all(ishandle(Handles.hPointEEG(i,:))) && (i <= size(Handles.hTextEEG,1)) && all(ishandle(Handles.hTextEEG(i,:)))
            set(Handles.hPointEEG(i,1), 'XData', Handles.LocEEG(i,2), 'YData', Handles.LocEEG(i,3));
            set(Handles.hPointEEG(i,2), 'XData', Handles.LocEEG(i,1), 'YData', Handles.LocEEG(i,3));
            set(Handles.hPointEEG(i,3), 'XData', Handles.LocEEG(i,1), 'YData', Handles.LocEEG(i,2));
            set(Handles.hTextEEG(i,1), 'Position', [Handles.LocEEG(i,2), Handles.LocEEG(i,3), 1.5]);
            set(Handles.hTextEEG(i,2), 'Position', [Handles.LocEEG(i,1), Handles.LocEEG(i,3), 1.5]);
            set(Handles.hTextEEG(i,3), 'Position', [Handles.LocEEG(i,1), Handles.LocEEG(i,2), 1.5]);
        else
            markerColor = [1 1 0];
            textColor = [.4,1,.4];
            Handles.hPointEEG(i,:) = PlotPoint(sMri, Handles, Handles.LocEEG(i,:), markerColor, 4);
            Handles.hTextEEG(i,:)  = PlotText(sMri, Handles, Handles.LocEEG(i,:), textColor, sensorNames{i});
        end
    end
end



%% ===== PLOT POINT =====
function hPt = PlotPoint(sMri, Handles, ptLocVox, ptColor, ptSize)
    % Small dots: selects them
    if (ptSize <= 4)
        clickFcnS = @(h,ev)SetLocation('mri', Handles.hFig, [], ptLocVox ./ 1000);
        clickFcnC = @(h,ev)SetLocation('mri', Handles.hFig, [], ptLocVox ./ 1000);
        clickFcnA = @(h,ev)SetLocation('mri', Handles.hFig, [], ptLocVox ./ 1000);
    % Large dots: like it was not clicked
    else
        clickFcnS = @(h,ev)MouseButtonDownAxes_Callback(Handles.hFig, Handles.axs, sMri, Handles);
        clickFcnC = @(h,ev)MouseButtonDownAxes_Callback(Handles.hFig, Handles.axc, sMri, Handles);
        clickFcnA = @(h,ev)MouseButtonDownAxes_Callback(Handles.hFig, Handles.axa, sMri, Handles);
    end
    % Plot point in three views: sagittal, coronal, axial
    hPt(1,1) = line(ptLocVox(2), ptLocVox(3), 1.5, ...
                  'MarkerFaceColor', ptColor, ...
                  'Marker',          'o', ...
                  'MarkerEdgeColor', [.4 .4 .4], ...
                  'MarkerSize',      ptSize, ...
                  'Parent',          Handles.axs, ...
                  'ButtonDownFcn',   clickFcnS, ...
                  'Visible',         'off', ...
                  'Tag',             'PointMarker');
    hPt(1,2) = line(ptLocVox(1), ptLocVox(3), 1.5, ...
                  'MarkerFaceColor', ptColor, ...
                  'Marker',          'o', ...
                  'MarkerEdgeColor', [.4 .4 .4], ...
                  'MarkerSize',      ptSize, ...
                  'Parent',          Handles.axc, ...
                  'ButtonDownFcn',   clickFcnC, ...
                  'Visible',         'off', ...
                  'Tag',             'PointMarker');
    hPt(1,3) = line(ptLocVox(1), ptLocVox(2), 1.5, ...
                  'MarkerFaceColor', ptColor, ...
                  'Marker',          'o', ...
                  'MarkerEdgeColor', [.4 .4 .4], ...
                  'MarkerSize',      ptSize, ...
                  'Parent',          Handles.axa, ...
                  'ButtonDownFcn',   clickFcnA, ...
                  'Visible',         'off', ...
                  'Tag',             'PointMarker');
end

%% ===== PLOT TEXT =====
function hPt = PlotText(sMri, Handles, ptLocVox, ptColor, ptLabel)
    fontSize = bst_get('FigFont');
    hPt(1,1) = text(ptLocVox(2), ptLocVox(3), 1.5, ptLabel, ...
                  'VerticalAlignment',   'bottom', ...
                  'HorizontalAlignment', 'center', ...
                  'Interpreter',         'none', ...
                  'FontSize',            fontSize, ...
                  'FontUnits',           'points', ...
                  'color',               ptColor, ...
                  'Tag',                 'LabelEEG', ...
                  'Parent',              Handles.axs, ...
                  'ButtonDownFcn',       @(h,ev)MouseButtonDownAxes_Callback(Handles.hFig, Handles.axs, sMri, Handles), ...
                  'Visible',             'off', ...
                  'Tag',                 'TextMarker');
    hPt(1,2) = text(ptLocVox(1), ptLocVox(3), 1.5, ptLabel, ...
                  'VerticalAlignment',   'bottom', ...
                  'HorizontalAlignment', 'center', ...
                  'Interpreter',         'none', ...
                  'FontSize',            fontSize, ...
                  'FontUnits',           'points', ...
                  'color',               ptColor, ...
                  'Tag',                 'LabelEEG', ...
                  'Parent',              Handles.axc, ...
                  'ButtonDownFcn',       @(h,ev)MouseButtonDownAxes_Callback(Handles.hFig, Handles.axc, sMri, Handles), ...
                  'Visible',             'off', ...
                  'Tag',                 'TextMarker');
    hPt(1,3) = text(ptLocVox(1), ptLocVox(2), 1.5, ptLabel, ...
                  'VerticalAlignment',   'bottom', ...
                  'HorizontalAlignment', 'center', ...
                  'Interpreter',         'none', ...
                  'FontSize',            fontSize, ...
                  'FontUnits',           'points', ...
                  'Color',               ptColor, ...
                  'Tag',                 'LabelEEG', ...
                  'Parent',              Handles.axa, ...
                  'ButtonDownFcn',       @(h,ev)MouseButtonDownAxes_Callback(Handles.hFig, Handles.axa, sMri, Handles), ...
                  'Visible',             'off', ...
                  'Tag',                 'TextMarker');
end

    
%% ===== UPDATE VISIBLE LANDMARKS =====
% For each point, if it is located close to a slice, display it; else hide it 
function UpdateVisibleLandmarks(sMri, Handles, slicesToUpdate)
    % Slices indices to update (direct indicing)
    if (nargin < 3)
        slicesToUpdate = [1 1 1];
    else
        slicesToUpdate = ismember([1 2 3], slicesToUpdate);
    end
    slicesLoc = GetLocation('mri', sMri, Handles) .* 1000;
    % Tolerance to display a point in a slice (in voxels)
    nTol = 1;
    
    function showPt(hPoint, locPoint)
        if ~isempty(locPoint) && ~isempty(hPoint) && all(ishandle(hPoint))
            isVisible    = slicesToUpdate & (abs(locPoint - slicesLoc) <= nTol);
            isNotVisible = slicesToUpdate & ~isVisible;
            set(hPoint(isVisible),    'Visible', 'on');
            set(hPoint(isNotVisible), 'Visible', 'off');
        end
    end
    
    % Show all fiducial points
    if Handles.isEditFiducials
        showPt(Handles.hPointNAS, sMri.SCS.NAS);
        showPt(Handles.hPointLPA, sMri.SCS.LPA);
        showPt(Handles.hPointRPA, sMri.SCS.RPA);
        showPt(Handles.hPointAC,  sMri.NCS.AC);
        showPt(Handles.hPointPC,  sMri.NCS.PC);
        showPt(Handles.hPointIH,  sMri.NCS.IH);
    else
        set([Handles.hPointNAS, Handles.hPointLPA, Handles.hPointRPA, Handles.hPointAC, Handles.hPointPC, Handles.hPointIH], 'Visible', 'off');
    end
    
    % Get display properties
    MriOptions = bst_get('MriOptions');
    % Show electrodes
    if Handles.isEeg
        % If MIP:Functional is on, then display all the electrodes
        if MriOptions.isMipFunctional
            set(Handles.hPointEEG(:), 'Visible', 'on');
        else
            for i = 1:size(Handles.hPointEEG,1)
                showPt(Handles.hPointEEG(i,:), Handles.LocEEG(i,:));
            end
        end
    else
        set(Handles.hPointEEG, 'Visible', 'off');
    end
    
    % Show electrodes labels
    if Handles.isEeg && Handles.isEegLabels
        % If MIP:Functional is on, then display all the electrodes
        if MriOptions.isMipFunctional
            set(Handles.hTextEEG(:),  'Visible', 'on');
        else
            for i = 1:size(Handles.hTextEEG,1)
                showPt(Handles.hTextEEG(i,:), Handles.LocEEG(i,:));
            end
        end
    else
        set(Handles.hTextEEG, 'Visible', 'off');
    end
end

    
%% ===== SET FIDUCIALS ======
function SetFiducial(hFig, FidCategory, FidName)
    global GlobalData;
    % Get MRI
    [sMri,TessInfo,iTess,iMri] = panel_surface('GetSurfaceMri', hFig);
    % Get the file in the database
    [sSubject, iSubject, iAnatomy] = bst_get('MriFile', sMri.FileName);
    % If it is not the first MRI: can't edit the fiducuials
    if (iAnatomy > 1)
        bst_error('The fiducials should be edited only in the first MRI file.', 'Set fiducials', 0);
    end
    % Get Handles
    Handles = bst_figures('GetFigureHandles', hFig);
    % Get current position
    XYZ = GetLocation('mri', sMri, Handles) .* 1000;
    % Save fiducial position
    sMri.(FidCategory).(FidName) = XYZ;
    % Reload fiducials
    [sMri, Handles] = LoadLandmarks(sMri, Handles);
    % Mark MRI as modified
    Handles.isModifiedMri = 1;
    bst_figures('SetFigureHandles', hFig, Handles);
    GlobalData.Mri(iMri) = sMri;
end


%% ===== VIEW FIDUCIALS =====
function ViewFiducial(hFig, FidCategory, FiducialName)
    % Reset zoom
    ButtonZoom_Callback(hFig, 'reset');
    % Get MRI
    sMri = panel_surface('GetSurfaceMri', hFig);
    % Get Handles
    Handles = bst_figures('GetFigureHandles', hFig);
    % Get fiducial position
    switch (FiducialName)
        case {'NAS','LPA','RPA'}
            XYZ = sMri.(FidCategory).(FiducialName);
        case {'AC','PC','IH'}
            XYZ = sMri.(FidCategory).(FiducialName);
    end
    % Change slices positions
    SetLocation('mri', sMri, Handles, XYZ ./ 1000);
end



%% =======================================================================================
%  ===== VALIDATION BUTTONS ==============================================================
%  =======================================================================================
%% ===== BUTTON CANCEL =====
function ButtonCancel_Callback(hFig, varargin)
    global GlobalData;
    % Get figure Handles
    [hFig,iFig,iDS] = bst_figures('GetFigure', hFig);
    % Mark that nothing changed
    GlobalData.DataSet(iDS).Figure(iFig).Handles.isModifiedMri = 0;
    GlobalData.DataSet(iDS).Figure(iFig).Handles.isModifiedEeg = 0;
    % Unload all datasets that used this MRI
    sMri = panel_surface('GetSurfaceMri', hFig);
    bst_memory('UnloadMri', sMri.FileName);
    % Close figure
    if ishandle(hFig)
        close(hFig);
    end
end

%% ===== BUTTON SAVE =====
function ButtonSave_Callback(hFig, varargin)
    global GlobalData;
    % Get figure Handles
    [hFig,iFig,iDS] = bst_figures('GetFigure', hFig);
    % If something was changed in the MRI
    if GlobalData.DataSet(iDS).Figure(iFig).Handles.isModifiedMri || GlobalData.DataSet(iDS).Figure(iFig).Handles.isModifiedEeg
        % Save MRI
        if GlobalData.DataSet(iDS).Figure(iFig).Handles.isModifiedMri
            % Save modifications
            isCloseAccepted = SaveMri(hFig);
            % If closing the window was not accepted: Cancel button click
            if ~isCloseAccepted
                return
            end
            % Mark that nothing was changed
            GlobalData.DataSet(iDS).Figure(iFig).Handles.isModifiedMri = 0;
        end
        % Save EEG
        if GlobalData.DataSet(iDS).Figure(iFig).Handles.isModifiedEeg
            % Save modifications
            SaveEeg(hFig);
            % Mark that nothing was changed
            GlobalData.DataSet(iDS).Figure(iFig).Handles.isModifiedEeg = 0;
        end
        % % Unload all datasets that used this MRI
        % bst_memory('UnloadMri', MriFile);
        % Unload all datasets
        bst_memory('UnloadAll', 'Forced');
    else
        % Close figure
        close(hFig);
    end
end


%% ===== SAVE MRI =====
function [isCloseAccepted, MriFile] = SaveMri(hFig)
    ProtocolInfo = bst_get('ProtocolInfo');
    % Get MRI
    sMri = panel_surface('GetSurfaceMri', hFig);
    MriFile = sMri.FileName;
    MriFileFull = bst_fullfile(ProtocolInfo.SUBJECTS, MriFile);
    % Do not accept "Save" if user did not select all the fiducials
    if isempty(sMri.SCS.NAS) || isempty(sMri.SCS.LPA) || isempty(sMri.SCS.RPA)
        bst_error(sprintf('You must select all the fiducials:\nNAS, LPA, RPA, AC, PC and IH.'), 'MRIViewer', 0);
        isCloseAccepted = 0;
        return;
    end
    isCloseAccepted = 1;

    % ==== GET REFERENCIAL CHANGES ====
    % Get subject in database, with subject directory
    [sSubject, iSubject, iAnatomy] = bst_get('MriFile', sMri.FileName);
    % Load the previous MRI fiducials
    warning('off', 'MATLAB:load:variableNotFound');
    sMriOld = load(MriFileFull, 'SCS');
    warning('on', 'MATLAB:load:variableNotFound');
    % If the fiducials were modified
    if isfield(sMriOld, 'SCS') && all(isfield(sMriOld.SCS,{'NAS','LPA','RPA'})) ...
            && ~isempty(sMriOld.SCS.NAS) && ~isempty(sMriOld.SCS.LPA) && ~isempty(sMriOld.SCS.RPA) ...
            && ((max(sMri.SCS.NAS - sMriOld.SCS.NAS) > 1e-3) || ...
                (max(sMri.SCS.LPA - sMriOld.SCS.LPA) > 1e-3) || ...
                (max(sMri.SCS.RPA - sMriOld.SCS.RPA) > 1e-3))
        % Nothing to do...
    else
        sMriOld = [];
    end
    
    % === HISTORY ===
    % History: Edited the fiducials
    if ~isfield(sMriOld, 'SCS') || ~isequal(sMriOld.SCS, sMri.SCS) || ~isfield(sMriOld, 'NCS') || ~isequal(sMriOld.NCS, sMri.NCS)
        sMri = bst_history('add', sMri, 'edit', 'User edited the fiducials');
    end
    
    % ==== SAVE MRI ====
    bst_progress('start', 'MRI Viewer', 'Saving MRI...');
    % Remove filename from the structure
    MriMat = rmfield(sMri, 'FileName');
    % Save file
    try
        bst_save(MriFileFull, MriMat, 'v7');
    catch
        bst_error(['Cannot save MRI in file "' sMri.FileName '"'], 'MRI Viewer');
        return;
    end
    bst_progress('stop');
 
    % ==== UPDATE OTHER MRI FILES ====
    if ~isempty(sMriOld) && (length(sSubject.Anatomy) > 1)
        % New fiducials
        s.SCS = sMri.SCS;
        s.NCS = sMri.NCS;
        % Update each MRI file
        for iAnat = 1:length(sSubject.Anatomy)
            % Skip the current one
            if (iAnat == iAnatomy)
                continue;
            end
            % Save NCS and SCS structures
            updateMriFile = file_fullpath(sSubject.Anatomy(iAnat).FileName);
            bst_save(updateMriFile, s, 'v7', 1);
        end
    end
    
    % ==== REALIGN SURFACES ====
    if ~isempty(sMriOld)
        UpdateSurfaceCS({sSubject.Surface.FileName}, sMriOld, sMri);
    end
end


%% ===== SAVE EEG =====
function SaveEeg(hFig)
    % Get figure handles
    Handles = bst_figures('GetFigureHandles', hFig);
    % Get full file name
    ChannelFile = file_fullpath(Handles.ChannelFile);
    % Save new channel file
    bst_save(ChannelFile, Handles.ChannelMat, 'v7');
    % Reload channel study
    [sStudy, iStudy] = bst_get('ChannelFile', Handles.ChannelFile);
    db_reload_studies(iStudy);
end


%% ===== UPDATE SURFACE CS =====
function UpdateSurfaceCS(SurfaceFiles, sMriOld, sMriNew)
    % Progress bar
    bst_progress('start', 'MRI Viewer', 'Updating surfaces...', 0, length(SurfaceFiles));
    % Process all surfaces
    for i = 1:length(SurfaceFiles)
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% WARNING: DELETE THE SCS FIELD FROM THE SURFACE
        %%%%          Losing the conversion: surface file CS => SCS
        %%%%          => Impossible to import new surfaces after that
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Load surface
        sSurf = in_tess_bst(SurfaceFiles{i});
        % Create new surface
        sSurfNew = db_template('surfacemat');
        sSurfNew.Vertices = sSurf.Vertices;
        sSurfNew.Faces    = sSurf.Faces;
        sSurfNew.Comment  = sSurf.Comment;
        if isfield(sSurf, 'History')
            sSurfNew.History  = sSurf.History;
        end
        if isfield(sSurf, 'Atlas') && isfield(sSurf, 'iAtlas')
            sSurfNew.Atlas  = sSurf.Atlas;
            sSurfNew.iAtlas  = sSurf.iAtlas;
        end
        if isfield(sSurf, 'Reg') && ~isempty(sSurf.Reg)
            sSurfNew.Reg = sSurf.Reg;
        end
        % Realiagn vertices in new coordinates system
        sSurfNew.Vertices = cs_convert(sMriOld, 'scs', 'mri', sSurfNew.Vertices);
        sSurfNew.Vertices = cs_convert(sMriNew, 'mri', 'scs', sSurfNew.Vertices);
        % Add history record
        sSurfNew = bst_history('add', sSurfNew, 're-orient', 'User edited the fiducials.');
        % Increment progress bar
        bst_progress('inc', 1);
        % Save surface
        bst_save(file_fullpath(SurfaceFiles{i}), sSurfNew, 'v7');
    end
    bst_progress('stop');
end


%% ===== SET FIDUCIALS FOR SUBJECT =====
% WARNING: Inputs are in millimeters
function SetSubjectFiducials(iSubject, NAS, LPA, RPA, AC, PC, IH) %#ok<DEFNU>
    % Get the updated subject structure
    sSubject = bst_get('Subject', iSubject);
    if isempty(sSubject.iAnatomy)
        error('No MRI defined for this subject');
    end
    % Build full MRI file
    BstMriFile = file_fullpath(sSubject.Anatomy(sSubject.iAnatomy).FileName);
    % Load MRI structure
    sMri = in_mri_bst(BstMriFile);
    % Set fiducials
    if ~isempty(NAS)
        sMri.SCS.NAS = NAS(:)'; % Nasion (in MRI coordinates)
    end
    if ~isempty(LPA)
        sMri.SCS.LPA = LPA(:)'; % Left ear
    end
    if ~isempty(RPA)
        sMri.SCS.RPA = RPA(:)'; % Right ear
    end
    if ~isempty(AC)
        sMri.NCS.AC  = AC(:)';  % Anterior commissure
    end
    if ~isempty(PC)
        sMri.NCS.PC  = PC(:)';  % Posterior commissure
    end
    if ~isempty(IH)
        sMri.NCS.IH  = IH(:)';  % Inter-hemispherical point
    end
    % Compute MRI -> SCS transformation
    if ~isempty(NAS) && ~isempty(LPA) && ~isempty(RPA)
        scsTransf = cs_compute(sMri, 'scs');
        if ~isempty(scsTransf)
            sMri.SCS.R      = scsTransf.R;
            sMri.SCS.T      = scsTransf.T;
            sMri.SCS.Origin = scsTransf.Origin;
        end
    end
    % Save MRI structure (with fiducials)
    bst_save(BstMriFile, sMri, 'v7');
end


%% ===== CHECK FIDUCIALS VALIDATION =====
function isChecked = FiducialsValidation(MriFile) %#ok<DEFNU>
    isChecked = 0;
    % Get subject
    [sSubject, iSubject] = bst_get('MriFile', MriFile);
    % Check that it is the default anatomy
    if (iSubject ~= 0)
        return
    end
    % Read the history field of the MRI file
    MriFileFull = file_fullpath(MriFile);
    MriMat = load(MriFileFull, 'History');
    % If fiducials haven't been validated yet
    if ~isfield(MriMat, 'History') || isempty(MriMat.History) || ~any(strcmpi(MriMat.History(:,2), 'validate'))
        % Add a "validate" entry for the default anatomy
        MriMat = bst_history('add', MriMat, 'validate', 'User validated the fiducials');
        bst_save(MriFileFull, MriMat, 'v7', 1);
        % MRI viewer
        hFig = view_mri(MriFile, 'EditFiducials');
        drawnow;
        % Ask user to check/fix the fiducials
        java_dialog('msgbox', ['You have imported a standard anatomy, with standard fiducials positions (ears, nasion),' 10 ...
                               'but during the acquisition of your recordings, you may have used different positions.' 10 ...
                               'If you do not fix this now, the source localizations might be very unprecise.' 10 10 ...
                               'Please check and fix now the following points:' 10 ...
                               '   - NAS (Nasion)' 10 ...
                               '   - LPA (Left pre-auricular)' 10 ...
                               '   - RPA (Right pre-auricular)'], 'Default anatomy');
        % The check was performed
        isChecked = 1;
        % Wait for the MRI viewer to be closed
        waitfor(hFig);
    end
end


%% ===== EDIT FIDUCIALS =====
function EditFiducials(hFig)
    global GlobalData;
    % Get MRI
    [sMri,TessInfo,iTess,iMri] = panel_surface('GetSurfaceMri', hFig);
    % Get Handles
    Handles = bst_figures('GetFigureHandles', hFig);
    % Add basic structures
    if ~isfield(sMri, 'SCS') || isempty(sMri.SCS)
        SCS.NAS = [];
        SCS.LPA = [];
        SCS.RPA = [];
        SCS.R = [];
        SCS.T = [];
    else
        SCS = sMri.SCS;
    end
    if ~isfield(sMri, 'NCS') || isempty(sMri.NCS)
        NCS.AC = [];
        NCS.PC = [];
        NCS.IH = [];
    else
        NCS = sMri.NCS;
    end
    strMsg = '';
    % Edit all the positions at once
    res = java_dialog('input', {...
        '<HTML>MRI coordinates [x,y,z], in millimeters:<BR><BR>Nasion (NAS):', ...
        'Left (LPA):', 'Right (RPA):', ...
        'Anterior commissure (AC):', 'Posterior commissure (PC):', 'Inter-hemispheric (IH):'}, ...
        'Edit fiducials', [], ...
        {num2str(SCS.NAS), num2str(SCS.LPA), num2str(SCS.RPA), ...
         num2str(NCS.AC),  num2str(NCS.PC),  num2str(NCS.IH)});
    % User cancelled
    if isempty(res) || ~iscell(res) || (length(res) ~= 6)
        return;
    end
    % Save new values: SCS
    fidNames = {'NAS','LPA','RPA'};
    for i = 1:length(fidNames)
        if ~isempty(res{i})
            fidPos = str2num(res{i});
            if (length(fidPos) == 3)
                SCS.(fidNames{i}) = fidPos;
            else
                strMsg = [strMsg, 'Invalid coordinates: ' fidNames{i} 10];
            end
        end
    end
    % Save new values: NCS
    fidNames = {'AC','PC','IH'};
    for i = 1:length(fidNames)
        if ~isempty(res{3+i})
            fidPos = str2num(res{3+i});
            if (length(fidPos) == 3)
                NCS.(fidNames{i}) = fidPos;
            else
                strMsg = [strMsg, 'Invalid coordinates: ' fidNames{i} 10];
            end
        end
    end
    % Display warning message
    if ~isempty(strMsg)
        java_dialog('error', strMsg, 'Edit fiducials');
    end
    % If no modifications with the original points
    if isequal(sMri.SCS, SCS) && isequal(sMri.NCS, NCS)
        return;
    end
    % Save modifications
    sMri.SCS = SCS;
    sMri.NCS = NCS;
    % Reload fiducials
    [sMri, Handles] = LoadLandmarks(sMri, Handles);
    % Mark MRI as modified
    Handles.isModifiedMri = 1;
    bst_figures('SetFigureHandles', hFig, Handles);
    GlobalData.Mri(iMri) = sMri;
end


%% ===== SAVE FIDUCIALS FILE =====
% USAGE:  SaveFiducialsFile(hFig, FidFile=[ask], isComputeMni=[])
%         SaveFiducialsFile(sMri, FidFile=[ask], isComputeMni=[])
function FidFile = SaveFiducialsFile(sMri, FidFile, isComputeMni)
    % Parse inputs
    if (nargin < 3) || isempty(isComputeMni)
        isComputeMni = [];
    end
    if (nargin < 2) || isempty(FidFile)
        FidFile = [];
    end
    % Get MRI from figure
    if ~isstruct(sMri) && ishandle(sMri)
        hFig = sMri;
        [sMri,TessInfo,iTess,iMri] = panel_surface('GetSurfaceMri', hFig);
    end

    % Ask filename
    if isempty(FidFile)
        % Default filename
        LastUsedDirs = bst_get('LastUsedDirs');
        FidFile = bst_fullfile(LastUsedDirs.ImportAnat, 'fiducials.m');
        % Select file
        FidFile = java_getfile('save', 'Select anatomy folder...', FidFile, 'single', 'file', ...
                               {{'*'}, 'Text file (*.*)', 'ASCII'}, 1);
        % If no file was selected: exit
        if isempty(FidFile)
            return
        end
    end
    
    % File contents
    strFid = [];
    if isfield(sMri, 'SCS') && isfield(sMri.SCS, 'NAS') && ~isempty(sMri.SCS.NAS)
        strFid = [strFid, sprintf('NAS = [%1.2f, %1.2f, %1.2f];\n', sMri.SCS.NAS)];
    end
    if isfield(sMri, 'SCS') && isfield(sMri.SCS, 'LPA') && ~isempty(sMri.SCS.LPA)
        strFid = [strFid, sprintf('LPA = [%1.2f, %1.2f, %1.2f];\n', sMri.SCS.LPA)];
    end
    if isfield(sMri, 'SCS') && isfield(sMri.SCS, 'RPA') && ~isempty(sMri.SCS.RPA)
        strFid = [strFid, sprintf('RPA = [%1.2f, %1.2f, %1.2f];\n', sMri.SCS.RPA)];
    end
    if isfield(sMri, 'NCS') && isfield(sMri.NCS, 'AC') && ~isempty(sMri.NCS.AC)
        strFid = [strFid, sprintf('AC = [%1.2f, %1.2f, %1.2f];\n', sMri.NCS.AC)];
    end
    if isfield(sMri, 'NCS') && isfield(sMri.NCS, 'PC') && ~isempty(sMri.NCS.PC)
        strFid = [strFid, sprintf('PC = [%1.2f, %1.2f, %1.2f];\n', sMri.NCS.PC)];
    end
    if isfield(sMri, 'NCS') && isfield(sMri.NCS, 'IH') && ~isempty(sMri.NCS.IH)
        strFid = [strFid, sprintf('IH = [%1.2f, %1.2f, %1.2f];\n', sMri.NCS.IH)];
    end
    % If no fiducials are set yet
    if isempty(strFid)
        error('Fiducials are not set.');
    end
    % Compute MNI transform: FreeSurfer only
    if isComputeMni
        strFid = [strFid, 'isComputeMni = 1;', 10];
    end
    % Open file for writing
    fid = fopen(FidFile, 'wt');
    if (fid == 0)
        error(['Could not write file: ' FidFile]);
    end
    % Write file
    fwrite(fid, strFid);
    % Close file
    fclose(fid);
    % End message
    disp(['Fiducials saved in: ' FidFile]);
end


%% ===== SET ELECTRODE POSITION =====
function SetElectrodePosition(hFig)
    % Get MRI and figure handles
    sMri = panel_surface('GetSurfaceMri', hFig);
    Handles = bst_figures('GetFigureHandles', hFig);
    % If there is no EEG: cancel
    if ~Handles.isEeg
        return;
    end
    % Channel name
    AllNames = {Handles.ChannelMat.Channel(Handles.iChannels).Name};
    ChannelName = java_dialog('combo', 'Select the electrode:', 'Set electrode position', [], AllNames);
    if isempty(ChannelName)
        return
    end
    % Get channel index
    iChan = channel_find(Handles.ChannelMat.Channel(Handles.iChannels), ChannelName);
    if (length(iChan) ~= 1)
        bst_error(['Channel "' ChannelName '" does not exist.'], 'Set electrode position', 0);
        return;
    end
    % Get current position (MRI)
    scsXYZ = GetLocation('scs', sMri, Handles);
    % Update electrode position
    Handles.ChannelMat.Channel(Handles.iChannels(iChan)).Loc = scsXYZ(:);
    % Plot electrodes again
    Handles = PlotElectrodes(hFig, Handles);
    % Update display
    UpdateVisibleLandmarks(sMri, Handles);
    % Mark MRI as modified
    Handles.isModifiedEeg = 1;
    bst_figures('SetFigureHandles', hFig, Handles);
end


%% ===== ALIGN ELECTRODES =====
% SEEG:  AlignElectrodes_Callback(hFig, Method)     : Method={first_last, first_second, all}
% ECOG:  AlignElectrodes_Callback(hFig, nCorners)   : nCorners={1,2,4}
function AlignElectrodes_Callback(hFig, Method)
    % Parse inputs
    if (nargin < 2) || isempty(Method)
        error('Invalid call.');
    end
    % Get MRI and figure handles
    sMri = panel_surface('GetSurfaceMri', hFig);
    Handles = bst_figures('GetFigureHandles', hFig);
    % If there is no EEG: cancel
    if ~Handles.isEeg
        return;
    end
    % Progress bar
    bst_progress('start', 'Align electrode contacts', 'Updating electrode positions...');
    % Get current channels
    Channels = Handles.ChannelMat.Channel(Handles.iChannels);
    % Call the function to align electodes
    Modality = Channels(1).Type;
    switch (Modality)
        case 'SEEG'
            Channels = AlignSeegElectrodes(Channels, Method);
        case 'ECOG'
            sSubject = bst_get('Subject', getappdata(hFig, 'SubjectFile'));
            Channels = AlignEcogElectrodes(Channels, sSubject, Method);
        otherwise
            error('Unsupported modality.');
    end
    if isempty(Channels)
        bst_progress('stop');
        return;
    end
    % Update electrode position
    Handles.ChannelMat.Channel(Handles.iChannels) = Channels;
    % Plot electrodes again
    Handles = PlotElectrodes(hFig, Handles);
    % Update display
    UpdateVisibleLandmarks(sMri, Handles);
    % Mark MRI as modified
    Handles.isModifiedEeg = 1;
    bst_figures('SetFigureHandles', hFig, Handles);
    % Progress bar
    bst_progress('stop');
end


%% ===== ALIGN SEEG ELECTRODES =====
function Channels = AlignSeegElectrodes(Channels, Method)
    % Get groups of electrodes
    [iGroupEeg, GroupNames] = panel_montage('GetEegGroups', Channels, [], 1);
    if isempty(iGroupEeg)
        error('No groups of contacts are defined. Please edit the channel file and set the Name or Comment fields of the SEEG electrodes.');
    end
    % Select groups of electrodes to align
    isSelected = java_dialog('checkbox', 'Select the groups of contacts to align:', 'Align electrode contacts', [], GroupNames, ones(size(GroupNames)));
    if isempty(isSelected) || ~any(isSelected)
        Channels = [];
        return;
    end
    iGroupEeg = iGroupEeg(isSelected == 1);
    % Ask the distance between contacts
    if isequal(Method, 'first_second')
        res = java_dialog('input', 'Distance between two contacts (in millimeters):', 'Align electrode contacts', [], '4.2');
        % If user cancelled: return
        if isempty(res)
            return
        end
        % Get new values
        DistContact = str2num(res) / 1000;
        if isempty(DistContact) || (DistContact < 0)
            bst_error('Invalid parameter.', 'Align electrode contacts', 0);
            return
        end
    end
    % Process each selected group separately
    for iGroup = 1:length(iGroupEeg)
        iChan = iGroupEeg{iGroup};
        switch (Method)
            % Use first and last contacts: Calculate the positions for the middle electrodes
            case 'first_last'
                EdgeLoc = [Channels(iChan(1)).Loc, Channels(iChan(end)).Loc];
                for i = 2:(length(iChan)-1)
                    Channels(iChan(i)).Loc(:,1) = ((length(iChan)-i)*EdgeLoc(:,1) + (i-1)*EdgeLoc(:,2)) / (length(iChan) - 1);
                end
            % Use first and second contacts + inter-contact distance: Calculate the positions for all the other electrodes
            case 'first_second'
                % Get the direction of the electrode
                direction = Channels(iChan(2)).Loc - Channels(iChan(1)).Loc;
                direction = direction ./ sqrt(sum(direction.^2));
                % Complete the electrode with distance+orientation
                for i = 2:length(iChan)
                    Channels(iChan(i)).Loc(:,1) = Channels(iChan(1)).Loc(:,1) + (i-1) * direction * DistContact;
                end
            % Use Get the principal orientation for all the electrodes
            case 'all'
                [ChanOrient, StripOrient, StripStart, ChanLocFix] = figure_3d('GetSeegStrips', Channels, [], {iChan});
                for i = iChan
                    Channels(i).Loc(:,1) = ChanLocFix(i,:)';
                end
        end
    end
end


%% ===== ALIGN ECOG ELECTRODES =====
% Two different representations for the same grid (U=rows, V=cols)
%                             |              V ->
%    Q ___________ S          |        P ___________ T
%     |__|__|__|__|           |         |__|__|__|__| 
%     |__|__|__|__|   ^       |     U   |__|__|__|__| 
%     |__|__|__|__|   U       |     |   |__|__|__|__| 
%     |__|__|__|__|           |         |__|__|__|__| 
%    T             P          |        S             Q
%         <- V                |
%
function Channels = AlignEcogElectrodes(Channels, sSubject, nCorners)
    % Parse inputs
    if (nargin < 3) || isempty(nCorners)
        nCorners = 2;
    end
    % This can be performed only with the inner skull
    if isempty(sSubject.iInnerSkull) || (sSubject.iInnerSkull > length(sSubject.Surface))
        bst_error('You need to define the inner skull surface of the subject before using this function.', 'Align electrode contacts', 0);
        Channels = [];
        return;
    end
    % Get groups of electrodes
    [iGroupEeg, GroupNames] = panel_montage('GetEegGroups', Channels, [], 1);
    if isempty(iGroupEeg)
        bst_error(['No groups of electrodes are defined. ' 10 'Please edit the channel file and set the Name or Comment fields of the ECOG electrodes.'], 'Align electrode contacts', 0);
        Channels = [];
        return;
    end
    % Select groups of electrodes to align
    SelGroup = java_dialog('combo', 'Select the group of contacts to align:', 'Align electrode contacts', [], GroupNames);
    if isempty(SelGroup)
        Channels = [];
        return;
    end
    % Get electrodes in the selected group
    iSelGroup = find(strcmpi(SelGroup, GroupNames));
    iChan = iGroupEeg{iSelGroup};
    % Default dimensions
    nElec = length(iChan);
    % ECOG strip
    if (nCorners == 1)
        nRows = 1;
        nCols = nElec;
    % ECOG grid
    else
        switch(nElec)
            case 4,    nRows = 1;   nCols = 4;
            case 6,    nRows = 1;   nCols = 6;
            case 8,    nRows = 1;   nCols = 8;
            case 12,   nRows = 2;   nCols = 6;
            case 16,   nRows = 2;   nCols = 8;
            case 32,   nRows = 4;   nCols = 8;
            case 64,   nRows = 8;   nCols = 8;
            otherwise, nRows = 1;   nCols = nElec;
        end
    end
    
    % Ask for number of rows and colums of the grid
    switch (nCorners)
        % Strips: two edges
        case 1
            orient = 0;
        % Grids: two corners
        case 2
            % Get default width for the grid (isotropic scaling)
            P = Channels(iChan(1)).Loc';
            Q = Channels(iChan(end)).Loc';
            PQ = sqrt(sum((Q-P).^2, 2));
            unitX = PQ / sqrt((nCols-1).^2 + (nRows-1).^2);
            % Ask user the confirmation
            res = java_dialog('input', ...
                {['<HTML>Number of contacts in this group: <B>', num2str(nElec), '</B><BR><BR>'...
                  'Number of rows:'], ...
                  'Number of columns:', ...
                  'Space between two rows (mm):', ...
                  '<HTML>Orientation of the grid:<BR>0=Rows first, 1=Columns first'}, 'Define ECOG grid', [], ...
                 {num2str(nRows), num2str(nCols), num2str(unitX * 1000), '0'});
            if isempty(res) || (length(res) < 4) || isnan(str2double(res{1})) || isempty(str2double(res{1})) || isnan(str2double(res{2})) || isempty(str2double(res{2})) || isnan(str2double(res{3})) || isempty(str2double(res{3})) || isnan(str2double(res{4})) || isempty(str2double(res{4}))
                return
            end
            nRows = str2double(res{1});
            nCols = str2double(res{2});
            unitX = str2double(res{3}) / 1000;
            orient = str2double(res{4});
        % Grids: four corners
        case 4
            res = java_dialog('input', ...
                {['<HTML>Number of contacts in this group: <B>', num2str(nElec), '</B><BR><BR>'...
                  'Number of rows:'], 'Number of columns:'}, 'Define ECOG grid', [], ...
                 {num2str(nRows), num2str(nCols)});
            if isempty(res) || (length(res) < 2) || isnan(str2double(res{1})) || isempty(str2double(res{1})) || isnan(str2double(res{2})) || isempty(str2double(res{2}))
                return
            end
            nRows = str2double(res{1});
            nCols = str2double(res{2});
            orient = 0;
    end
    % Check dimensions
    if (nCols*nRows ~= nElec)
        bst_error('The number of contacts of the grid does not match the group defined in the channel file.', 'Align electrode contacts', 0);
        Channels = [];
        return;
    elseif (nCols < 2) || (nRows < 2)
        nCorners = 1;
    end

    % Get the coordinates of the four corners
    P = Channels(iChan(1)).Loc';
    S = Channels(iChan(nRows)).Loc';
    T = Channels(iChan(end-nRows+1)).Loc';
    Q = Channels(iChan(end)).Loc';
    % Project those points on the inner skull
    [EdgeOrient, EdgeLoc] = figure_3d('GetChannelNormal', sSubject, [P;S;T;Q]);
    % Retreive coordinates
    P = EdgeLoc(1,:); 
    S = EdgeLoc(2,:); 
    T = EdgeLoc(3,:); 
    Q = EdgeLoc(4,:); 
    
    % Define all the electrodes
    NewLoc = zeros(nElec, 3);
    % Get the electrodes indices
    [I,J] = meshgrid(1:nRows, 1:nCols);
    % Get list of indices, for the approriate orientation
    switch (orient)
        case 0,    I = I'; J = J'; 
        case 1,    I = I(:);   J = J(:);
        otherwise, error('Unsupported orientation');
    end
    I = I(:);
    J = J(:);

    % Reconstruct grid from different number of points
    switch (nCorners)
        % Strip: two edges
        case 1
            I = (1:nElec)';
            NewLoc = ((nElec-I) * P + (I-1) * Q) ./ (nElec - 1);
            
        % Grids: two corners
        case 2
            % Get the average normal
            GridNormal = (EdgeOrient(1,:) + EdgeOrient(4,:)) ./ 2;
            % Get the distances between P/S   (S = third corner)
            PS = (nRows-1) * unitX;
            % Alpha = angle between PQ and PS
            alpha = acos(PS/PQ);
            % S1=projection of S on PQ;   S2=projection of S on w
            S1 = cos(alpha) * PS;
            S2 = sin(alpha) * PS;
            % Calculate w1/w2, a base of vectors for the grid
            w1 = Q - P;
            w1 = w1 ./ sqrt(sum(w1.^2,2));
            w2 = cross(w1, GridNormal);
            w2 = w2 ./ sqrt(sum(w2.^2,2));
            % Position of the third corner (S)
            S = P + S1 * w1 + S2 * w2;
            % Base U and V of vectors to define the grid
            U = S-P;
            N = cross(U, Q-P);
            V = - cross(U, N);
            % Normalize base vectors to the unit of the grid
            unitY = sqrt(sum((Q-S).^2,2)) ./ (nCols - 1);
            U = U ./ sqrt(sum(U.^2,2)) .* unitX;   % Rows
            V = V ./ sqrt(sum(V.^2,2)) .* unitY;   % Cols
            % Position of the realigned electrodes
            NewLoc = bst_bsxfun(@plus, P, (I-1) * U + (J-1)*V);
            
        % Grids: four corners
        case 4
            % Get 4 possible coordinates for the point, from the four corners
            Xp = bst_bsxfun(@plus, P,     (I-1)/(nRows-1)*(S-P) +     (J-1)/(nCols-1)*(T-P));
            Xt = bst_bsxfun(@plus, T,     (I-1)/(nRows-1)*(Q-T) + (nCols-J)/(nCols-1)*(P-T));
            Xs = bst_bsxfun(@plus, S, (nRows-I)/(nRows-1)*(P-S) +     (J-1)/(nCols-1)*(Q-S));
            Xq = bst_bsxfun(@plus, Q, (nRows-I)/(nRows-1)*(T-Q) + (nCols-J)/(nCols-1)*(S-Q));
            % Weight the four options based on their norm to the point, in grid spacing
            m = (nRows-1)^2 + (nCols-1)^2;
            wp = m - (    (I-1).^2 +     (J-1).^2);
            wt = m - (    (I-1).^2 + (nCols-J).^2);
            ws = m - ((nRows-I).^2 +     (J-1).^2);
            wq = m - ((nRows-I).^2 + (nCols-J).^2);
            NewLoc = (bst_bsxfun(@times, wp, Xp) + ...
                      bst_bsxfun(@times, wt, Xt) + ...
                      bst_bsxfun(@times, ws, Xs) + ...
                      bst_bsxfun(@times, wq, Xq));
            NewLoc = bst_bsxfun(@rdivide, NewLoc, wp + wt + ws + wq);                    
    end
    % Project on the inner skull
    [NewOrient, NewLoc] = figure_3d('GetChannelNormal', sSubject, NewLoc);
    % Replace original channel positions
    for i = 1:nElec
        Channels(iChan(i)).Loc(:,1) = NewLoc(i,:)';
    end
end


%% ===== SET LABELS VISIBLE =====
function SetLabelVisible(hFig, isEegLabels)
    % Get MRI and figure handles
    sMri = panel_surface('GetSurfaceMri', hFig);
    Handles = bst_figures('GetFigureHandles', hFig);
    % If there is no EEG: cancel
    if ~Handles.isEeg
        return;
    end
    % Update figure handles
    if (nargin < 2) || isempty(isEegLabels)
        Handles.isEegLabels = ~Handles.isEegLabels;
    else
        Handles.isEegLabels = isEegLabels;
    end
    % Save figure handles
    bst_figures('SetFigureHandles', hFig, Handles);
    % Update display
    UpdateVisibleLandmarks(sMri, Handles);
end


%% ===== EXPORT OVERLAY =====
function ExportOverlay(hFig)
    % Get surfaces list 
    TessInfo = getappdata(hFig, 'Surface');
    % Find the first one with an overlay
    iTess = find(~cellfun(@isempty, {TessInfo.OverlayCube}));
    if isempty(iTess)
        bst_error('No MRI overlay available in this figure.', 'Export overlay', 0);
    end
    % Get loaded MRI
    MriFile = TessInfo(iTess).SurfaceFile;
    sMriOverlay = bst_memory('LoadMri', MriFile);
    % Replace the values with the current overlay
    sMriOverlay.Cube = double(TessInfo.OverlayCube);
    % Normalize the values to fit in int16
    sMriOverlay.Cube = (sMriOverlay.Cube - min(sMriOverlay.Cube(:))) / max(sMriOverlay.Cube(:)) * double(intmax('int16'));
    % Convert volume to int16
    sMriOverlay.Cube = int16(sMriOverlay.Cube);
    % Enforce the original zero values
    sMriOverlay.Cube(sMriOverlay.Cube == 0) = 0;
    % Save volume
    export_mri(sMriOverlay);
end


%% ===== COMPUTE MNI COORDINATES =====
function ComputeMniCoordinates(hFig)
    % Ask for confirmation
    isConfirm = java_dialog('confirm', [...
        'Displaying MNI coordinates requires the download of additional atlases' 10 ...
        'and may take a lot of time or crash on some computers.' 10 10 ...
        'Compute normalized coordinates now?'], 'Normalize anatomy');
    if ~isConfirm
        return;
    end
    % Get figure handles
    Handles = bst_figures('GetFigureHandles', hFig);
    % Get MRI and figure handles
    sMri = panel_surface('GetSurfaceMri', hFig);
    % Compute normalization
    [sMri, errMsg] = bst_normalize_mni(sMri.FileName);
    % Error handling
    if ~isempty(errMsg)
        bst_error(errMsg, 'Compute MNI transformation', 0);
        return;
    end
    % Update coordinates display
    [sMri, Handles] = LoadLandmarks(sMri, Handles);
    % Update figure handles
    bst_figures('SetFigureHandles', hFig, Handles);
end


%% ===== APPLY COORDINATES TO ALL FIGURES =====
function ApplyCoordsToAllFigures(hSrcFig, cs)
    % Get all figures
    hAllFig = bst_figures('GetFiguresByType', {'MriViewer'});
    hAllFig = setdiff(hAllFig, hSrcFig);
    % Get MRI and Handles
    srcMri = panel_surface('GetSurfaceMri', hSrcFig);
    srcHandles = bst_figures('GetFigureHandles', hSrcFig);
    % Get slices locations
    XYZ = GetLocation(cs, srcMri, srcHandles);
    % Go through all figures, set new location
    for ii = 1:length(hAllFig)
        destMri = panel_surface('GetSurfaceMri', hAllFig(ii));
        destHandles = bst_figures('GetFigureHandles', hAllFig(ii));
        SetLocation(cs, destMri, destHandles, XYZ);
    end
end
