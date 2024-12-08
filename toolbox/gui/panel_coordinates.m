function varargout = panel_coordinates(varargin)
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
%          Chinmay Chinara, 2024

eval(macro_method);
end


%% ===== CREATE PANEL =====
function bstPanelNew = CreatePanel() %#ok<DEFNU>
    panelName = 'Coordinates';
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

    % ===== CREATE TOOLBAR =====
    jToolbar = gui_component('Toolbar', jPanelNew, BorderLayout.NORTH);
    jToolbar.setPreferredSize(java_scaled('dimension', 100,25));
        % Button "Select vertex"
        jButtonSelect = gui_component('ToolbarToggle', jToolbar, [], 'Select', IconLoader.ICON_SCOUT_NEW, 'Select surface point', @(h,ev)SetSelectionState(ev.getSource.isSelected()));
        % Button "View in MRI Viewer"
        gui_component('ToolbarButton', jToolbar, [], 'View/MRI', IconLoader.ICON_VIEW_SCOUT_IN_MRI, 'View point in MRI Viewer', @ViewInMriViewer);
        % Button "Remove selection"
        gui_component('ToolbarButton', jToolbar, [], 'Del', IconLoader.ICON_DELETE, 'Remove point selection', @RemoveSelection);
                  
    % ===== Main panel =====
    jPanelMain = gui_river();   
        % ===== Coordinates =====
        jPanelCoordinates = gui_river('Coordinates (millimeters)');
            % Coordinates
            jPanelCoordinates.add('br', gui_component('label', jPanelCoordinates, 'tab', ' '));
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
            jPanelCoordinates.add('br', gui_component('label', jPanelCoordinates, 'tab', 'MRI: '));
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
            jPanelCoordinates.add('tab', jLabelCoordMriX);
            jPanelCoordinates.add('tab', jLabelCoordMriY);
            jPanelCoordinates.add('tab', jLabelCoordMriZ);
            % === SCS ===
            jPanelCoordinates.add('br', gui_component('label', jPanelCoordinates, 'tab', 'SCS: '));
            jLabelCoordScsX = JLabel('-');
            jLabelCoordScsY = JLabel('-');
            jLabelCoordScsZ = JLabel('-');
            jLabelCoordScsX.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jLabelCoordScsY.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jLabelCoordScsZ.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jLabelCoordScsX.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            jLabelCoordScsY.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            jLabelCoordScsZ.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            jLabelCoordScsX.setFont(jFontText);
            jLabelCoordScsY.setFont(jFontText);
            jLabelCoordScsZ.setFont(jFontText);
            jPanelCoordinates.add('tab', jLabelCoordScsX);
            jPanelCoordinates.add('tab', jLabelCoordScsY);
            jPanelCoordinates.add('tab', jLabelCoordScsZ);
            % === WORLD ===
            jPanelCoordinates.add('br', gui_component('label', jPanelCoordinates, 'tab', 'World: '));
            jLabelCoordWrlX = JLabel('-');
            jLabelCoordWrlY = JLabel('-');
            jLabelCoordWrlZ = JLabel('-');
            jLabelCoordWrlX.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jLabelCoordWrlY.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jLabelCoordWrlZ.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jLabelCoordWrlX.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            jLabelCoordWrlY.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            jLabelCoordWrlZ.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            jLabelCoordWrlX.setFont(jFontText);
            jLabelCoordWrlY.setFont(jFontText);
            jLabelCoordWrlZ.setFont(jFontText);
            jPanelCoordinates.add('tab', jLabelCoordWrlX);
            jPanelCoordinates.add('tab', jLabelCoordWrlY);
            jPanelCoordinates.add('tab', jLabelCoordWrlZ);
            % === MNI ===
            jPanelCoordinates.add('br', gui_component('label', jPanelCoordinates, 'tab', 'MNI: '));
            jLabelCoordMniX = JLabel('-');
            jLabelCoordMniY = JLabel('-');
            jLabelCoordMniZ = JLabel('-');
            jLabelCoordMniX.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jLabelCoordMniY.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jLabelCoordMniZ.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
            jLabelCoordMniX.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            jLabelCoordMniY.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            jLabelCoordMniZ.setPreferredSize(Dimension(TEXT_WIDTH, TEXT_HEIGHT));
            jLabelCoordMniX.setFont(jFontText);
            jLabelCoordMniY.setFont(jFontText);
            jLabelCoordMniZ.setFont(jFontText);
            jPanelCoordinates.add('tab', jLabelCoordMniX);
            jPanelCoordinates.add('tab', jLabelCoordMniY);
            jPanelCoordinates.add('tab', jLabelCoordMniZ);
            % === VERTEX INDICE ===
            jLabelVertexInd = JLabel('No vertex selected');
            jLabelVertexInd.setFont(jFontText);
            jPanelCoordinates.add('br', jLabelVertexInd);

        jPanelMain.add('hfill', jPanelCoordinates);
    jPanelNew.add(jPanelMain, BorderLayout.CENTER);
       
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jButtonSelect',     jButtonSelect, ...
                                  'jPanelCoordinates', jPanelCoordinates, ...
                                  'jLabelCoordMriX',   jLabelCoordMriX, ...
                                  'jLabelCoordMriY',   jLabelCoordMriY, ...
                                  'jLabelCoordMriZ',   jLabelCoordMriZ, ...
                                  'jLabelCoordScsX',   jLabelCoordScsX, ...
                                  'jLabelCoordScsY',   jLabelCoordScsY, ...
                                  'jLabelCoordScsZ',   jLabelCoordScsZ, ...
                                  'jLabelCoordWrlX',   jLabelCoordWrlX, ...
                                  'jLabelCoordWrlY',   jLabelCoordWrlY, ...
                                  'jLabelCoordWrlZ',   jLabelCoordWrlZ, ...
                                  'jLabelCoordMniX',   jLabelCoordMniX, ...
                                  'jLabelCoordMniY',   jLabelCoordMniY, ...
                                  'jLabelCoordMniZ',   jLabelCoordMniZ, ...
                                  'jLabelVertexInd',   jLabelVertexInd));
                                                            
end
                   
            
%% =================================================================================
%  === EXTERNAL PANEL CALLBACKS  ===================================================
%  =================================================================================
%% ===== UPDATE CALLBACK =====
function UpdatePanel()
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Coordinates');
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
    % Update coordinates (text fields)
    % MRI
    if ~isempty(CoordinatesSelector) && ~isempty(CoordinatesSelector.MRI)
        ctrl.jLabelCoordMriX.setText(sprintf('%3.1f', 1000 * CoordinatesSelector.MRI(1)));
        ctrl.jLabelCoordMriY.setText(sprintf('%3.1f', 1000 * CoordinatesSelector.MRI(2)));
        ctrl.jLabelCoordMriZ.setText(sprintf('%3.1f', 1000 * CoordinatesSelector.MRI(3)));
    else
        ctrl.jLabelCoordMriX.setText('-');
        ctrl.jLabelCoordMriY.setText('-');
        ctrl.jLabelCoordMriZ.setText('-');
    end
    % SCS
    if ~isempty(CoordinatesSelector) && ~isempty(CoordinatesSelector.SCS)
        ctrl.jLabelCoordScsX.setText(sprintf('%3.1f', 1000 * CoordinatesSelector.SCS(1)));
        ctrl.jLabelCoordScsY.setText(sprintf('%3.1f', 1000 * CoordinatesSelector.SCS(2)));
        ctrl.jLabelCoordScsZ.setText(sprintf('%3.1f', 1000 * CoordinatesSelector.SCS(3)));
    else
        ctrl.jLabelCoordScsX.setText('-');
        ctrl.jLabelCoordScsY.setText('-');
        ctrl.jLabelCoordScsZ.setText('-');
    end
    % World
    if ~isempty(CoordinatesSelector) && ~isempty(CoordinatesSelector.World)
        ctrl.jLabelCoordWrlX.setText(sprintf('%3.1f', 1000 * CoordinatesSelector.World(1)));
        ctrl.jLabelCoordWrlY.setText(sprintf('%3.1f', 1000 * CoordinatesSelector.World(2)));
        ctrl.jLabelCoordWrlZ.setText(sprintf('%3.1f', 1000 * CoordinatesSelector.World(3)));
    else
        ctrl.jLabelCoordWrlX.setText('-');
        ctrl.jLabelCoordWrlY.setText('-');
        ctrl.jLabelCoordWrlZ.setText('-');
    end
    % MNI
    if ~isempty(CoordinatesSelector) && ~isempty(CoordinatesSelector.MNI)
        ctrl.jLabelCoordMniX.setText(sprintf('%3.1f', 1000 * CoordinatesSelector.MNI(1)));
        ctrl.jLabelCoordMniY.setText(sprintf('%3.1f', 1000 * CoordinatesSelector.MNI(2)));
        ctrl.jLabelCoordMniZ.setText(sprintf('%3.1f', 1000 * CoordinatesSelector.MNI(3)));
    else
        ctrl.jLabelCoordMniX.setText('-');
        ctrl.jLabelCoordMniY.setText('-');
        ctrl.jLabelCoordMniZ.setText('-');
    end
    % Vertex indice
    if ~isempty(CoordinatesSelector) && ~isempty(CoordinatesSelector.iVertex)
        if ~isempty(CoordinatesSelector.Value)
            strValue = ['&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Value: ' num2str(CoordinatesSelector.Value)];
        else
            strValue = '';
        end
        ctrl.jLabelVertexInd.setText(sprintf('<HTML>Vertex #%d %s', CoordinatesSelector.iVertex, strValue));
    else
        ctrl.jLabelVertexInd.setText('No vertex selected');
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


%% ===============================================================================
%  ====== POINTS SELECTION =======================================================
%  ===============================================================================
%% ===== POINT SELECTION : start/stop =====
% Manual selection of a surface point : start(1), or stop(0)
function SetSelectionState(isSelected)
    % Get panel controls
    ctrl1 = bst_get('PanelControls', 'Coordinates');
    ctrl2 = bst_get('PanelControls', 'iEEG');
    ctrls = {ctrl1, ctrl2};
    ctrls = ctrls(~cellfun(@isempty, ctrls));

    if isempty(ctrls)
        return
    end
    % Get list of all figures
    hFigures = bst_figures('GetAllFigures');
    if isempty(hFigures)
        for ic = 1 : length(ctrls)
            ctrls{ic}.jButtonSelect.setSelected(0);
        end
        return
    end
    % Start selection
    if isSelected
        % Push toolbar "Select" button 
        for ic = 1 : length(ctrls)
            ctrls{ic}.jButtonSelect.setSelected(1);
        end
        % Set 3DViz figures in 'SelectingCorticalSpot' mode
        for hFig = hFigures
            % Keep only figures with surfaces
            TessInfo = getappdata(hFig, 'Surface');
            if ~isempty(TessInfo)
                setappdata(hFig, 'isSelectingCoordinates', 1);
                set(hFig, 'Pointer', 'cross');
            end
        end
    % Stop selection
    else
        % Release toolbar "Select" button
        for ic = 1 : length(ctrls)
            ctrls{ic}.jButtonSelect.setSelected(0);
        end
        % Exit 3DViz figures from SelectingCorticalSpot mode
        for hFig = hFigures
            set(hFig, 'Pointer', 'arrow');
            setappdata(hFig, 'isSelectingCoordinates', 0);      
        end
    end
end


%% ===== GET SELECTION STATE =====
function isSelected = GetSelectionState()
    % Get "Coordinates" panel controls
    ctrl = bst_get('PanelControls', 'Coordinates');
    if isempty(ctrl)
        isSelected = 0;
        return
    end
    % Return status
    isSelected = ctrl.jButtonSelect.isSelected();
end


%% ===== SELECT POINT =====
% Usage : SelectPoint(hFig) : Point location = user click in figure hFIg
function vi = SelectPoint(hFig, AcceptMri, isCentroid) %#ok<DEFNU>
    if (nargin < 3) || isempty(isCentroid)
        isCentroid = 0;
    end
    if (nargin < 2) || isempty(AcceptMri)
        AcceptMri = 1;
        isCentroid = 0;
    end
    % Get axes handle
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    % Find the closest surface point that was selected
    [TessInfo, iTess, pout, vout, vi, hPatch] = ClickPointInSurface(hFig, [], isCentroid);
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
            if ~isCentroid
                scsLoc = sSurf.Vertices(vi,:);
            else
                scsLoc = vout';
            end
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
    CoordinatesSelector.Voxel   = cs_convert(sMri, 'scs', 'voxel', scsLoc);
    CoordinatesSelector.iVertex = iVertex;
    CoordinatesSelector.Value   = Value;
    CoordinatesSelector.hPatch  = hPatch;
    setappdata(hFig, 'CoordinatesSelector', CoordinatesSelector);
    
    % ===== PLOT MARKER =====
    % Remove previous mark
    delete(findobj(hAxes, '-depth', 1, 'Tag', 'ptCoordinates'));
    % Mark new point
    if ~isCentroid
        plotLoc = plotLoc.*1.005;
    end
    line(plotLoc(1), plotLoc(2), plotLoc(3), ...
         'MarkerFaceColor', [1 1 0], ...
         'MarkerEdgeColor', [1 1 0], ...
         'Marker',          '+',  ...
         'MarkerSize',      12, ...
         'LineWidth',       2, ...
         'Parent',          hAxes, ...
         'Tag',             'ptCoordinates');
    % Update "Coordinates" panel
    UpdatePanel();
    % Open MRI viewer for SEEG
    if isCentroid
        ViewInMriViewer();
    end
end


%% ===== POINT SELECTION: Surface detection =====
function [TessInfo, iTess, pout, vout, vi, hPatch] = ClickPointInSurface(hFig, SurfacesType, isCentroid)     
    % Parse inputs
    if (nargin < 3)
        isCentroid = 0;
    end
    if (nargin < 2)
        SurfacesType = [];
        isCentroid = 0;
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
    [iTess, TessInfo, hFig, sSurf] = panel_surface('GetSelectedSurface', hFig);
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
            % Find centroid the blob mesh that contains the vertex 'vi'
            if isCentroid
                VertexList = FindCentroid(sSurf, find(sSurf.VertConn(vi{i},:)), [], 1, 6);
                vout{i} = mean(sSurf.Vertices(VertexList(:), :)); % SCS of the centroid
                vi{i} = []; % No surface vertex associated to centroid
            end
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
    vout   = vout{iClosestPatch};
    vi     = vi{iClosestPatch};

    % Find to which surface this tesselation belongs
    for i = 1:length(TessInfo)
        if any(TessInfo(i).hPatch == hPatch);
            iTess = i;
            break;
        end
    end
end

%% ===== FIND CENTROID OF A MESH BLOB =====
% Find the centroid of the selected contact blob from the isosurface using flood-fill alogrithm
% NOTE: currently used mainly for SEEG contact localization from thresholded isosurface
function VertexList = FindCentroid(Surface, VertConnList, VertexList, cnt, cntThresh)
    if cnt == cntThresh
        return;
    end
    for i=1:length(VertConnList)
        if ~any(VertexList(:) == VertConnList(i))
            VertexList = [VertexList, VertConnList(i)];
            VertConnListTemp = find(Surface.VertConn(VertConnList(i),:));
            VertexList = FindCentroid(Surface, VertConnListTemp, VertexList, cnt, cntThresh);
            cnt = cnt + 1;
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
    hFig = bst_figures('GetFiguresByType', 'MriViewer');
    if isempty(hFig)
        hFig = view_mri(sSubject.Anatomy(sSubject.iAnatomy).FileName);
    end
    % Select the required point
    figure_mri('SetLocation', 'mri', hFig, [], CoordinatesSelector.MRI);
end




