function varargout = panel_coordinates_seeg(varargin)
% PANEL_COORDINATES: Create a panel to add/remove/edit scouts attached to a given 3DViz figure.
% 
% USAGE:  bstPanelNew = panel_coordinates('CreatePanel')

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
% Authors: Francois Tadel, 2008-2020
%          Chinmay Chinara, 2023-2024

eval(macro_method);
end


%% ===== CREATE PANEL =====
function bstPanelNew = CreatePanel() %#ok<DEFNU>
    panelName = 'CoordinatesSeeg';

    % global
    global xxx;
    global yyy;
    global zzz;
    global HandlesIdx;
    HandlesIdx = 1;

    xxx = [];
    yyy = [];
    zzz = [];

    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.icon.*;
    % CONSTANTS 
    TEXT_HEIGHT = java_scaled('value', 20);
    TEXT_WIDTH  = java_scaled('value', 40);
    jFontText = bst_get('Font', 11);
    % Create tools panel
    jPanelNew = gui_component('Panel');
    
    res = java_dialog('input', {'Number of contacts', 'Label Name'}, ...
                                'Enter Number of contacts', ...
                                [], ...
                                {num2str(10), 'A'});

    % Hack keyboard callback
    hFig = bst_figures('GetCurrentFigure', '3D');
    KeyPressFcn_bak = get(hFig, 'KeyPressFcn');
    set(hFig, 'KeyPressFcn', @KeyPress_Callback);

    % ===== CREATE TOOLBAR =====
    jToolbar = gui_component('Toolbar', jPanelNew, BorderLayout.NORTH);
    jToolbar.setPreferredSize(java_scaled('dimension', 100,25));
        % Button "Select vertex"
        jButtonSelect = gui_component('ToolbarToggle', jToolbar, [], 'Select', IconLoader.ICON_SCOUT_NEW, 'Select surface point', @(h,ev)SetSelectionState(ev.getSource.isSelected()));
        % Button "View in MRI Viewer"
        gui_component('ToolbarButton', jToolbar, [], 'View/MRI', IconLoader.ICON_VIEW_SCOUT_IN_MRI, 'View point in MRI Viewer', @ViewInMriViewer);
        % Button "Remove selection"
        gui_component('ToolbarButton', jToolbar, [], 'Del', IconLoader.ICON_DELETE, 'Remove point selection', @RemoveSelection);
        % Button "Remove selection"
        gui_component('ToolbarButton', jToolbar, [], 'L', IconLoader.ICON_SCOUT_NEW, 'Draw line', @DrawLine);
                  
    % ===== Main panel =====
    jPanelMain = gui_river('');   
        % ===== Coordinates =====
        jPanelCoordinates = gui_river('sEEG contact localization');
            % % Dropdown box for Model of electrodes
            % gui_component('label', jPanelCoordinates, '', 'Model: ');
            % % Combo box
            % jComboModel = gui_component('combobox', jPanelCoordinates, 'hfill', [], [], [], []);
            % jComboModel.setFocusable(0);
            % jComboModel.setMaximumRowCount(15);
            % jComboModel.setPreferredSize(java_scaled('dimension',30,20));
            
            % Number of contacts and label name
            % jPanelCoordinates.add('br', gui_component('label', jPanelCoordinates, 'br', 'Number of contacts: '));
            jTextNcontacts = gui_component('label', jPanelCoordinates, 'tab', res{1}, [], [], [], 0);
            % jTextNcontacts.setHorizontalAlignment(jTextNcontacts.LEFT);
            % jPanelCoordinates.add('br', gui_component('label', jPanelCoordinates, 'br', 'Label Name: '));
            jTextLabel = gui_component('label', jPanelCoordinates, 'tab', res{2}, [], [], [], 0);
            % jTextLabel.setHorizontalAlignment(jTextLabel.LEFT);

            % Uncomment for text type box
            % jTextNcontacts = gui_component('text', jPanelCoordinates, 'tab', res{1});
            % jTextNcontacts.setHorizontalAlignment(jTextNcontacts.LEFT);
            
            % jModel = jComboModel.getModel();
            % java_setcb(jModel, 'ContentsChangedCallback', @(h,ev)bst_call(@ComboModelChanged_Callback,h,ev));

            % Coordinates
            jPanelCoordinates.add('br', gui_component('label', jPanelCoordinates, 'tab', 'Contact_Label'));
            jLabelX = gui_component('label', jPanelCoordinates, 'tab', '   X');
            jLabelY = gui_component('label', jPanelCoordinates, 'tab', '   Y');
            jLabelZ = gui_component('label', jPanelCoordinates, 'tab', '   Z');
            jLabelX.setHorizontalAlignment(javax.swing.JLabel.CENTER);
            jLabelY.setHorizontalAlignment(javax.swing.JLabel.CENTER);
            jLabelZ.setHorizontalAlignment(javax.swing.JLabel.CENTER);
            jLabelX.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            jLabelY.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            jLabelZ.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            jLabelX.setFont(jFontText);
            jLabelY.setFont(jFontText);
            jLabelZ.setFont(jFontText);

            % === MRI ===
            % jPanelCoordinates.add('br', gui_component('label', jPanelCoordinates, 'tab', 'MRI: '));
            % jLabelCoordMriX = JLabel('-');
            % jLabelCoordMriY = JLabel('-');
            % jLabelCoordMriZ = JLabel('-');
            % jLabelCoordMriX.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            % jLabelCoordMriY.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            % jLabelCoordMriZ.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            % jLabelCoordMriX.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            % jLabelCoordMriY.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            % jLabelCoordMriZ.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            % jLabelCoordMriX.setFont(jFontText);
            % jLabelCoordMriY.setFont(jFontText);
            % jLabelCoordMriZ.setFont(jFontText);
            % jPanelCoordinates.add('tab', jLabelCoordMriX);
            % jPanelCoordinates.add('tab', jLabelCoordMriY);
            % jPanelCoordinates.add('tab', jLabelCoordMriZ);
        jPanelMain.add('hfill', jPanelCoordinates);
    jPanelNew.add(jPanelMain, BorderLayout.CENTER);
       
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jButtonSelect',     jButtonSelect, ...
                                  'jTextNcontacts',    jTextNcontacts, ...
                                  'jTextLabel',        jTextLabel, ...
                                  'jPanelCoordinates', jPanelCoordinates));
                                  % 'jComboModel',       jComboModel, ...
                                  % 'jLabelCoordMriX',   jLabelCoordMriX, ...
                                  % 'jLabelCoordMriY',   jLabelCoordMriY, ...
                                  % 'jLabelCoordMriZ',   jLabelCoordMriZ));
                                                            
end
                   
            
%% =================================================================================
%  === EXTERNAL PANEL CALLBACKS  ===================================================
%  =================================================================================
%% ===== UPDATE CALLBACK =====
function UpdatePanel()
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.icon.*;
    % CONSTANTS 
    TEXT_HEIGHT = java_scaled('value', 20);
    TEXT_WIDTH  = java_scaled('value', 40);
    jFontText = bst_get('Font', 11);

    % Get panel controls
    ctrl = bst_get('PanelControls', 'CoordinatesSeeg');
    if isempty(ctrl)
        return
    end
    % Get current figure
    hFig = bst_figures('GetCurrentFigure', '3D');

    % If a figure is available: get if a point select 
    if ~isempty(hFig) && ishandle(hFig)
        CoordinatesSelector = getappdata(hFig, 'CoordinatesSelector');
    else
        CoordinatesSelector = [];
    end
    
    if ~isempty(CoordinatesSelector) && ~isempty(CoordinatesSelector.MRI)
        num_contacts = round(str2double(ctrl.jTextNcontacts.getText()));
        label_name = string(ctrl.jTextLabel.getText());
        ctrl.jPanelCoordinates.add('br', gui_component('label', ctrl.jPanelCoordinates, 'tab', label_name + num2str(num_contacts) + ': '));
    end

    jLabelCoordMriX = JLabel('-');
    jLabelCoordMriY = JLabel('-');
    jLabelCoordMriZ = JLabel('-');
    jLabelCoordMriX.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
    jLabelCoordMriY.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
    jLabelCoordMriZ.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
    jLabelCoordMriX.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
    jLabelCoordMriY.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
    jLabelCoordMriZ.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
    jLabelCoordMriX.setFont(jFontText);
    jLabelCoordMriY.setFont(jFontText);
    jLabelCoordMriZ.setFont(jFontText);
    ctrl.jPanelCoordinates.add('tab', jLabelCoordMriX);
    ctrl.jPanelCoordinates.add('tab', jLabelCoordMriY);
    ctrl.jPanelCoordinates.add('tab', jLabelCoordMriZ);

    % Update coordinates (text fields)
    % MRI
    if ~isempty(CoordinatesSelector) && ~isempty(CoordinatesSelector.MRI)
        jLabelCoordMriX.setText(sprintf('%3.2f', 1000 * CoordinatesSelector.World(1)));
        jLabelCoordMriY.setText(sprintf('%3.2f', 1000 * CoordinatesSelector.World(2)));
        jLabelCoordMriZ.setText(sprintf('%3.2f', 1000 * CoordinatesSelector.World(3)));
    else
        jLabelCoordMriX.setText('-');
        jLabelCoordMriY.setText('-');
        jLabelCoordMriZ.setText('-');
    end
end


%% ===== FOCUS CHANGED ======
function FocusChangedCallback(isFocused) %#ok<DEFNU>
    if ~isFocused
        RemoveSelection();
    end
end


%% ===== CURRENT FIGURE CHANGED =====
function CurrentFigureChanged_Callback() %#ok<DEFNU>
    UpdatePanel();
end

%% ===== KEYBOARD CALLBACK =====
function KeyPress_Callback(hFig, keyEvent)
    global xxx;
    global yyy;
    global zzz;

    switch (keyEvent.Key)
        case {'l'}
            % label contacts
            res = java_dialog('input', {'Number of contacts', 'Label Name'}, ...
                                'Enter Number of contacts', ...
                                [], ...
                                {num2str(10), 'A'});
            ctrl = bst_get('PanelControls', 'CoordinatesSeeg');
            SetSelectionState(1);
            ctrl.jTextNcontacts.setText(res{1});
            ctrl.jTextLabel.setText(res{2});
            xxx = [];
            yyy = [];
            zzz = [];
        
        case {'escape'}
            % exit the selection state to stop plotting contacts
            SetSelectionState(0);
        
        case {'r'}
            % resume the selection state to continue plotting contacts
            % from where it was last stopped
            SetSelectionState(1);

        otherwise
            KeyPressFcn_bak(hFig, keyEvent); 
            return;
    end
end

%% ===============================================================================
%  ====== POINTS SELECTION =======================================================
%  ===============================================================================
%% ===== POINT SELECTION : start/stop =====
% Manual selection of a surface point : start(1), or stop(0)
function SetSelectionState(isSelected)
    % Get panel controls
    ctrl = bst_get('PanelControls', 'CoordinatesSeeg');
    if isempty(ctrl)
        return
    end
    % Get list of all figures
    hFigures = bst_figures('GetAllFigures');
    if isempty(hFigures)
        ctrl.jButtonSelect.setSelected(0);
        return
    end
    % Start selection
    if isSelected
        % Push toolbar "Select" button 
        ctrl.jButtonSelect.setSelected(1);        
        % Set 3DViz figures in 'SelectingCorticalSpot' mode
        for hFig = hFigures
            % Keep only figures with surfaces
            TessInfo = getappdata(hFig, 'Surface');
            if ~isempty(TessInfo)
                setappdata(hFig, 'isSelectingCoordinatesSeeg', 1);
                set(hFig, 'Pointer', 'cross');
            end
        end
    % Stop selection
    else
        % Release toolbar "Select" button 
        ctrl.jButtonSelect.setSelected(0);
        % Exit 3DViz figures from SelectingCorticalSpot mode
        for hFig = hFigures
            set(hFig, 'Pointer', 'arrow');
            setappdata(hFig, 'isSelectingCoordinatesSeeg', 0);      
        end
    end
end


%% ===== SELECT POINT =====
% Usage : SelectPoint(hFig) : Point location = user click in figure hFIg
function vi = SelectPoint(hFig, AcceptMri) %#ok<DEFNU>
    if (nargin < 2) || isempty(AcceptMri)
        AcceptMri = 1;
    end

    % Get panel controls
    ctrl = bst_get('PanelControls', 'CoordinatesSeeg');

    % create global to save values
    global xxx;
    global yyy;
    global zzz;

    % Get axes handle
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    % Find the closest surface point that was selected
    [TessInfo, iTess, pout, vout, vi, hPatch] = ClickPointInSurface(hFig);
    if isempty(TessInfo)
        return
    end
    Value = [];
    
    % Get real location of the selected point (in SCS coord, millimeters)
    switch (TessInfo(iTess).Name)
        case 'Anatomy'
            % If MRI is not accepted
            if ~AcceptMri
                vi = [];
                return
            end
            scsLoc  = pout';
            plotLoc = scsLoc;
            iVertex = [];
            
            % Get MRI
            sMri = bst_memory('GetMri', TessInfo(iTess).SurfaceFile);
            
        case {'Scalp', 'InnerSkull', 'OuterSkull', 'Cortex', 'Other', 'FEM'}
            sSurf = bst_memory('GetSurface', TessInfo(iTess).SurfaceFile);
            scsLoc = sSurf.Vertices(vi,:);
            % disp(sSurf);
            plotLoc = vout;
            iVertex = vi;
            % Get value
            if ~isempty(TessInfo(iTess).Data)
                if ~isempty(TessInfo(iTess).DataSource.GridAtlas)
                    Value = [];
                elseif isempty(TessInfo(iTess).DataSource.Atlas)
                    Value = TessInfo(iTess).Data(vi);
                else
                    % Look for the selected point in one of the scouts
                    iRow = panel_scout('GetScoutForVertex', TessInfo(iTess).DataSource.Atlas, vi);
                    % Return value
                    Value = TessInfo(iTess).Data(iRow(1));
                end
            end
            % Get subject
            SubjectFile = getappdata(hFig, 'SubjectFile');
            if ~isempty(SubjectFile)
                sSubject = bst_get('Subject', SubjectFile);
                % == GET MRI ==
                % If subject has a MRI defined
                if ~isempty(sSubject.iAnatomy)
                    % Load MRI
                    MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
                    sMri = bst_memory('LoadMri', MriFile);
                else
                    sMri = [];
                end
            else
                sMri = [];
            end
        otherwise
            scsLoc = vout;
            plotLoc = scsLoc;
            iVertex = [];
            sMri = [];
    end
    
    % ===== CONVERT TO ALL COORDINATES SYSTEMS =====
    % Save selected point
    CoordinatesSelector.SCS     = scsLoc;
    CoordinatesSelector.MRI     = cs_convert(sMri, 'scs', 'mri', scsLoc);
    CoordinatesSelector.MNI     = cs_convert(sMri, 'scs', 'mni', scsLoc);
    CoordinatesSelector.World   = cs_convert(sMri, 'scs', 'world', scsLoc);
    CoordinatesSelector.iVertex = iVertex;
    CoordinatesSelector.Value   = Value;
    CoordinatesSelector.hPatch  = hPatch;
    setappdata(hFig, 'CoordinatesSelector', CoordinatesSelector);
    
    % ===== PLOT MARKER =====
    % Remove previous mark
    % delete(findobj(hAxes, '-depth', 1, 'Tag', 'ptCoordinates'));
    % Mark new point
    line(plotLoc(1), plotLoc(2), plotLoc(3) * 0.995, ...
         'MarkerFaceColor', [1 1 0], ...
         'MarkerEdgeColor', [1 1 0], ...
         'Marker',          'o',  ...
         'MarkerSize',      10, ...
         'LineWidth',       2, ...
         'Parent',          hAxes, ...
         'Tag',             'ptCoordinates');

    text(plotLoc(1), plotLoc(2), plotLoc(3), ...
        '         ' + string(ctrl.jTextLabel.getText()) + string(ctrl.jTextNcontacts.getText()), ...
        'HorizontalAlignment','center', ...
        'FontSize', 10, ...
        'Color',  [1 1 0], ...
        'Parent', hAxes, ...
        'Tag', 'ptCoordinates');

    xxx = [xxx, plotLoc(1)];
    yyy = [yyy, plotLoc(2)];
    zzz = [zzz, plotLoc(3) * 0.995];
    
    % Update "Coordinates" panel
    UpdatePanel();
    ViewInMriViewer();
end

%% ===== DRAW LINE =====
function DrawLine(varargin)
    global xxx;
    global yyy;
    global zzz;
    
    % Get axes handle
    hFig = bst_figures('GetCurrentFigure', '3D');
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');

    line(xxx, yyy, zzz , ...
         'Color', [1 1 0], ...
         'LineWidth',       2, ...
         'Parent', hAxes, ...
         'Tag', 'ptCoordinates');
end

%% ===== POINT SELECTION: Surface detection =====
function [TessInfo, iTess, pout, vout, vi, hPatch] = ClickPointInSurface(hFig, SurfacesType)
    % Parse inputs
    if (nargin < 2)
        SurfacesType = [];
    end
    iTess = [];
    pout = {};
    vout = {};
    vi = {};
    hPatch = [];
    
    % === GET SURFACES INFORMATION ===
    % Get axes handle
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    % Get camera position
    CameraPosition = get(hAxes, 'CameraPosition');
    % Get all the surfaces in the figure
    TessInfo = getappdata(hFig, 'Surface');
    if isempty(TessInfo)
        return
    end

    % === CHECK SURFACE TYPE ===
    % Keep only surfaces that are of the required type
    if ~isempty(SurfacesType)
        iAcceptableTess = find(strcmpi({TessInfo.Name}, SurfacesType));
    else
        iAcceptableTess = 1:length(TessInfo);
    end
    
    % ===== GET SELECTION ON THE CLOSEST SURFACE =====
    % Get the closest point for all the surfaces and patches
    hPatch = [TessInfo(iAcceptableTess).hPatch];
    hPatch = hPatch(ishandle(hPatch));
    patchDist = zeros(1,length(hPatch));
    for i = 1:length(hPatch)
        [pout{i}, vout{i}, vi{i}] = select3d(hPatch(i));
        if ~isempty(pout{i})
            patchDist(i) = norm(pout{i}' - CameraPosition);
        else
            patchDist(i) = Inf;
        end
    end
    if all(isinf(patchDist))
        TessInfo = [];
        pout = [];
        vout = [];
        vi = [];
        return
    end
    % Find closest surface from the camera
    [minDist, iClosestPatch] = min(patchDist);
    % Keep only the point from the closest surface
    hPatch = hPatch(iClosestPatch);
    pout   = pout{iClosestPatch};
    % disp(pout);
    vout   = vout{iClosestPatch};
    % disp(vout);
    vi     = vi{iClosestPatch};

    % Find to which surface this tesselation belongs
    for i = 1:length(TessInfo)
        if any(TessInfo(i).hPatch == hPatch);
            iTess = i;
            break;
        end
    end
end


%% ===== REMOVE SELECTION =====
function RemoveSelection(varargin)
    % Unselect selection button 
    SetSelectionState(0);
    % Find all selected points
    hCoord = findobj(0, 'Tag', 'ptCoordinates'); 
    % Remove coordinates from the figures
    for i = 1:length(hCoord)
        hFig = get(get(hCoord(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete selected points
    delete(hCoord);
    % Update displayed coordinates
    UpdatePanel();
end


%% ===== VIEW IN MRI VIEWER =====
function ViewInMriViewer(varargin)
    global GlobalData;
    global HandlesIdx;

    % Get panel controls
    ctrl = bst_get('PanelControls', 'CoordinatesSeeg');

    % Get current 3D figure
    [hFig,iFig,iDS] = bst_figures('GetCurrentFigure', '3D');
    if isempty(hFig)
        return
    end
    % Get current selected point
    CoordinatesSelector = getappdata(hFig, 'CoordinatesSelector');
    if isempty(CoordinatesSelector) || isempty(CoordinatesSelector.MRI)
        return
    end
    % Get subject and subject's MRI
    sSubject = bst_get('Subject', GlobalData.DataSet(iDS).SubjectFile);
    if isempty(sSubject) || isempty(sSubject.iAnatomy)
        return 
    end
    % Display subject's anatomy in MRI Viewer
    SurfaceFile = sSubject.Surface(sSubject.iScalp).FileName;
    hFig = view_mri(sSubject.Anatomy(sSubject.iAnatomy).FileName, SurfaceFile);
    sMri = panel_surface('GetSurfaceMri', hFig);
    Handles = bst_figures('GetFigureHandles', hFig);
    % disp(Handles);
    

    % Select the required point
    % Handles.isEeg = 1;
    figure_mri('SetLocation', 'mri', hFig, [], CoordinatesSelector.MRI);
    Handles.LocEEG(1,:) = CoordinatesSelector.MRI .* 1000;
    Channels(1).Name = string(ctrl.jTextLabel.getText()) + string(ctrl.jTextNcontacts.getText());
    Handles.hPointEEG(1,:) = figure_mri('PlotPoint', sMri, Handles, Handles.LocEEG(1,:), [1 1 0], 5, Channels(1).Name);
    Handles.hTextEEG(1,:)  = figure_mri('PlotText', sMri, Handles, Handles.LocEEG(1,:), [1 1 0], Channels(1).Name, Channels(1).Name);
    
    % Get slices locations
    % voxXYZ = figure_mri('GetLocation', 'voxel', sMri, Handles);
    % disp(voxXYZ);

    if ~isempty(CoordinatesSelector) && ~isempty(CoordinatesSelector.MRI)
        num_contacts = round(str2double(ctrl.jTextNcontacts.getText()));
        ctrl.jTextNcontacts.setText(sprintf("%d", num_contacts-1));
    end

    % disp(sMri);
    % disp(Handles);
    % disp(Handles.axs);
    figure_mri('UpdateVisibleLandmarks', sMri, Handles);
    % HandlesIdx = HandlesIdx+1;
end

%% ===== MODEL SELECTION =====
function ComboModelChanged_Callback(varargin)
    % Get selected model
    GetSelectedModel();
end

%% ===== GET SELECTED MODEL =====
function [iModel, sModels] = GetSelectedModel()
    % Get figure controls
    ctrl = bst_get('PanelControls', 'CoordinatesSeeg');
    if isempty(ctrl) %|| isempty(ctrl.jListElec)
        return
    end
    % Get the available electrode models
    sModels = GetElectrodeModels();
    % Get selected model
    ModelName = char(ctrl.jComboModel.getSelectedItem());
    if isempty(ModelName)
        iModel = [];
    else
        iModel = find(strcmpi({sModels.Model}, ModelName));
    end
end

%% ===== GET ELECTRODE MODELS =====
function sModels = GetElectrodeModels()
    global GlobalData;
    % Get existing preferences
    if isfield(GlobalData, 'Preferences') && isfield(GlobalData.Preferences, 'IntraElectrodeModels') && ~isempty(GlobalData.Preferences.IntraElectrodeModels) ...
            && (length(GlobalData.Preferences.IntraElectrodeModels) > 18)
        sModels = GlobalData.Preferences.IntraElectrodeModels;
    % Get default list of known electrodes
    else
        sModels = repmat(db_template('intraelectrode'), 1, 0);
        
        % === DIXI D08 ===
        % Common values
        sTemplate = db_template('intraelectrode');
        sTemplate.Type = 'SEEG';
        sTemplate.ContactSpacing  = 0.0035;
        sTemplate.ContactDiameter = 0.0008;
        sTemplate.ContactLength   = 0.002;
        sTemplate.ElecDiameter    = 0.0007;
        sTemplate.ElecLength      = 0.070;
        % All models
        sMod = repmat(sTemplate, 1, 6);
        sMod(1).Model         = 'DIXI D08-05AM Microdeep';
        sMod(1).ContactNumber = 5;
        sMod(2).Model         = 'DIXI D08-08AM Microdeep';
        sMod(2).ContactNumber = 8;
        sMod(3).Model         = 'DIXI D08-10AM Microdeep';
        sMod(3).ContactNumber = 10;
        sMod(4).Model         = 'DIXI D08-12AM Microdeep';
        sMod(4).ContactNumber = 12;
        sMod(5).Model         = 'DIXI D08-15AM Microdeep';
        sMod(5).ContactNumber = 15;
        sMod(6).Model         = 'DIXI D08-18AM Microdeep';
        sMod(6).ContactNumber = 18;
        sModels = [sModels, sMod];
        
        % === AD TECH RD10R ===
        % Common values
        sTemplate = db_template('intraelectrode');
        sTemplate.Type = 'SEEG';
        sTemplate.ContactNumber   = 10;
        sTemplate.ContactDiameter = 0.0009;
        sTemplate.ContactLength   = 0.0023;
        sTemplate.ElecDiameter    = 0.0008;
        sTemplate.ElecLength      = 0.080;
        % All models
        sMod = repmat(sTemplate, 1, 5);
        sMod(1).Model          = 'AdTech RD10R-SP04X';
        sMod(1).ContactSpacing = 0.004;
        sMod(2).Model          = 'AdTech RD10R-SP05X';
        sMod(2).ContactSpacing = 0.005;
        sMod(3).Model          = 'AdTech RD10R-SP06X';
        sMod(3).ContactSpacing = 0.006;
        sMod(4).Model          = 'AdTech RD10R-SP07X';
        sMod(4).ContactSpacing = 0.007;
        sMod(5).Model          = 'AdTech RD10R-SP08X';
        sMod(5).ContactSpacing = 0.008;
        sModels = [sModels, sMod];
        
        % === AD TECH RD10R ===
        % Common values
        sTemplate = db_template('intraelectrode');
        sTemplate.Type = 'SEEG';
        sTemplate.ContactSpacing  = 0.005;
        sTemplate.ContactDiameter = 0.0014;
        sTemplate.ContactLength   = 0.0020;
        sTemplate.ElecDiameter    = 0.0013;
        sTemplate.ElecLength      = 0.080;
        % All models
        sMod = repmat(sTemplate, 1, 2);
        sMod(1).Model          = 'AdTech MM16C-SP05X';
        sMod(1).ContactNumber   = 6;
        sMod(2).Model          = 'AdTech MM16D-SP05X';
        sMod(2).ContactNumber   = 8;
        sModels = [sModels, sMod];
        
        % === Huake-Hengsheng ===
        % Common values
        sTemplate = db_template('intraelectrode');
        sTemplate.Type = 'SEEG';
        sTemplate.ContactSpacing  = 0.0035;
        sTemplate.ContactDiameter = 0.0008;
        sTemplate.ContactLength   = 0.002;
        sTemplate.ElecDiameter    = 0.00079;
        % All models
        sMod = repmat(sTemplate, 1, 5);
        sMod(1).Model          = 'Huake-Hengsheng SDE-08-S08';
        sMod(1).ContactNumber  = 8;
        sMod(1).ElecLength     = 0.0265;
        sMod(2).Model          = 'Huake-Hengsheng SDE-08-S10';
        sMod(2).ContactNumber  = 8;
        sMod(2).ElecLength     = 0.0335;
        sMod(3).Model          = 'Huake-Hengsheng SDE-08-S12';
        sMod(3).ContactNumber  = 8;
        sMod(3).ElecLength     = 0.0405;
        sMod(4).Model          = 'Huake-Hengsheng SDE-08-S14';
        sMod(4).ContactNumber  = 8;
        sMod(4).ElecLength     = 0.0475;
        sMod(5).Model          = 'Huake-Hengsheng SDE-08-S16';
        sMod(5).ContactNumber  = 8;
        sMod(5).ElecLength     = 0.0545;
        sModels = [sModels, sMod];
    end
end