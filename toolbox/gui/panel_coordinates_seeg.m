function varargout = panel_coordinates_seeg(varargin)
% PANEL_COORDINATES_SEEG: Create a panel to manually add/remove/edit seeg contacts in a given isosureface (3DViz) figure.
% 
% USAGE:  bstPanelNew = panel_coordinates_seeg('CreatePanel')
%
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
% Authors: Chinmay Chinara, 2023-2024

eval(macro_method);
end

%% ===== CREATE PANEL =====
function bstPanelNew = CreatePanel() %#ok<DEFNU>
    panelName = 'CoordinatesSeeg';

    % global variables initialization
    % to be used for plotting line
    global linePlotLocX;
    global linePlotLocY;
    global linePlotLocZ;
    linePlotLocX = [];
    linePlotLocY = [];
    linePlotLocZ = [];

    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.icon.*;

    % CONSTANTS 
    % TEXT_HEIGHT = java_scaled('value', 20);
    % TEXT_WIDTH  = java_scaled('value', 40);
    % jFontText = bst_get('Font', 11);

    % Create tools panel
    jPanelNew = gui_component('Panel');

    % Create list for keeping track of the selected contact points
    listModel = javax.swing.DefaultListModel(); % can use java_create('javax.swing.DefaultListModel');

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
        % gui_component('ToolbarButton', jToolbar, [], 'View/MRI', IconLoader.ICON_VIEW_SCOUT_IN_MRI, 'View point in MRI Viewer', @ViewInMriViewer);
        % Button "Remove selection"
        gui_component('ToolbarButton', jToolbar, [], 'Del', IconLoader.ICON_DELETE, 'Remove point selection', @RemoveSelection);
        % Button "Remove selection"
        gui_component('ToolbarButton', jToolbar, [], 'DelAll', IconLoader.ICON_DELETE, 'Remove all the point selection', @RemoveSelectionAll);
        % Button "Draw Line"
        % gui_component('ToolbarButton', jToolbar, [], 'L', IconLoader.ICON_SCOUT_NEW, 'Draw line', @DrawLine);
        % Button "Save all to database"
        gui_component('ToolbarButton', jToolbar, [], 'Save', IconLoader.ICON_SAVE, 'Save all to database', @SaveAll);
                  
    % ===== Main panel =====
    jPanelMain = gui_component('Panel');
    jPanelMain.setBorder(BorderFactory.createEmptyBorder(7,7,7,7));   

        jPanelFirstPart = gui_component('Panel');
            % ===== ELECTRODES LIST =====
            jPanelElecList = gui_component('Panel');
                jBorder = java_scaled('titledborder', 'sEEG contact localization');
                jPanelElecList.setBorder(jBorder);
                % Electrodes list
                jListElec = java_create('org.brainstorm.list.BstClusterList');
                jListElec.setBackground(Color(.9,.9,.9));
                java_setcb(jListElec, ...
                    'MouseClickedCallback', @(h,ev)bst_call(@ElecListClick_Callback,h,ev));
                %     'ValueChangedCallback', @(h,ev)bst_call(@ElecListValueChanged_Callback,h,ev), ...
                %     'KeyTypedCallback',     @(h,ev)bst_call(@ElecListKeyTyped_Callback,h,ev), ...
                %     'MouseClickedCallback', @(h,ev)bst_call(@ElecListClick_Callback,h,ev));
                jPanelScrollList = JScrollPane();
                jPanelScrollList.getLayout.getViewport.setView(jListElec);
                jPanelScrollList.setHorizontalScrollBarPolicy(jPanelScrollList.HORIZONTAL_SCROLLBAR_ALWAYS);
                jPanelScrollList.setVerticalScrollBarPolicy(jPanelScrollList.VERTICAL_SCROLLBAR_ALWAYS);
                jPanelScrollList.setBorder([]);
                jPanelElecList.add(jPanelScrollList);
            jPanelFirstPart.add(jPanelElecList, BorderLayout.CENTER);
        jPanelMain.add(jPanelFirstPart);

        % ===== Coordinates =====
        jPanelCoordinates = gui_river('');            
            jTextNcontacts = gui_component('label', jPanelCoordinates, 'tab', res{1}, [], [], [], 0);
            jTextLabel = gui_component('label', jPanelCoordinates, 'tab', res{2}, [], [], [], 0);
        jPanelMain.add(jPanelCoordinates, BorderLayout.SOUTH);
    jPanelNew.add(jPanelMain, BorderLayout.CENTER);
    
    % Store electrode selection
    jLabelSelectElec = JLabel('');

    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jButtonSelect',     jButtonSelect, ...
                                  'jTextNcontacts',    jTextNcontacts, ...
                                  'jTextLabel',        jTextLabel, ...
                                  'jPanelCoordinates', jPanelCoordinates, ...
                                  'jListElec',         jListElec, ...
                                  'jPanelElecList',    jPanelElecList, ...
                                  'listModel',         listModel, ...
                                  'jLabelSelectElec',  jLabelSelectElec));

    %% ============================================================================
    %  === INTERNAL PANEL CALLBACKS  ==============================================
    %  ============================================================================

    %% ===== LIST CLICK CALLBACK =====
    function ElecListClick_Callback(h, ev)
        % If DOUBLE CLICK
        if (ev.getClickCount() == 1)
            % Rename selection
            % disp(1);
        end

        if (ev.getClickCount() == 2)
            % Rename selection
            ctrl = bst_get('PanelControls', 'CoordinatesSeeg'); 
            iPoint = uint16(ctrl.jListElec.getSelectedIndices())' + 1;
            isDelete = java_dialog('confirm', ...
            '<HTML><BR>Do you want to delete the label?<BR><BR>', ...
            'Delete label');  
            if isDelete
                RemoveAtLocation(iPoint);
            end
        end
    end                     
end
                   
            
%% =================================================================================
%  === EXTERNAL PANEL CALLBACKS  ===================================================
%  =================================================================================

%% ===== UPDATE CALLBACK =====
function UpdatePanel()
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
        ctrl.listModel.addElement(sprintf('%s   %3.2f   %3.2f   %3.2f', label_name + num2str(num_contacts), CoordinatesSelector.World .* 1000));
        % Set this list
        ctrl.jListElec.setModel(ctrl.listModel);
        ctrl.jListElec.repaint();
        drawnow;
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
    global linePlotLocX;
    global linePlotLocY;
    global linePlotLocZ;
    
    ctrl = bst_get('PanelControls', 'CoordinatesSeeg');

    switch (keyEvent.Key)
        case {'l'}
            % label contacts
            res = java_dialog('input', {'Number of contacts', 'Label Name'}, ...
                                'Enter Number of contacts', ...
                                [], ...
                                {num2str(10), 'A'});
            SetSelectionState(1);
            ctrl.jTextNcontacts.setText(res{1});
            ctrl.jTextLabel.setText(res{2});
            linePlotLocX = [];
            linePlotLocY = [];
            linePlotLocZ = [];
        
        case {'escape'}
            % exit the selection state to stop plotting contacts
            SetSelectionState(0);
        
        case {'r'}
            % resume the selection state to continue plotting contacts
            % from where it was last stopped

            num_contacts = round(str2double(ctrl.jTextNcontacts.getText()));
            label_name = string(ctrl.jTextLabel.getText());
            if num_contacts==0
                % relabel contacts
                res = java_dialog('input', {'Number of contacts', 'Label Name'}, ...
                                    'Enter Number of contacts', ...
                                    [], ...
                                    {num2str(10), 'A'});
                SetSelectionState(1);
                ctrl.jTextNcontacts.setText(res{1});
                ctrl.jTextLabel.setText(res{2});
                linePlotLocX = [];
                linePlotLocY = [];
                linePlotLocZ = [];
            else
                isResumePlot = java_dialog('confirm', [...
                '<HTML><B>Do you want to resume labelling?</B><BR><BR>' ...
                'Selecting "Yes" will resume from label ' + label_name + num2str(num_contacts)], ...
                'Resume labelling'); 
                if isResumePlot
                    SetSelectionState(1);
                else
                    SetSelectionState(0);
                end
            end
            
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
    global linePlotLocX;
    global linePlotLocY;
    global linePlotLocZ;

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
        'Tag', 'txtCoordinates');

    linePlotLocX = [linePlotLocX, plotLoc(1)];
    linePlotLocY = [linePlotLocY, plotLoc(2)];
    linePlotLocZ = [linePlotLocZ, plotLoc(3) * 0.995];
    
    % Update "Coordinates" panel
    UpdatePanel();
    ViewInMriViewer();
end

%% ===== DRAW LINE =====
function DrawLine(varargin)
    global linePlotLocX;
    global linePlotLocY;
    global linePlotLocZ;
    
    % Get axes handle
    hFig = bst_figures('GetCurrentFigure', '3D');
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');

    line(linePlotLocX, linePlotLocY, linePlotLocZ , ...
         'Color', [1 1 0], ...
         'LineWidth',       2, ...
         'Parent', hAxes, ...
         'Tag', 'lineCoordinates');
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

%% ===== REMOVE AT A LOCATION (DELETE SPECIFIC POINT) =====
function RemoveAtLocation(Loc)
    % Unselect selection button 
    % SetSelectionState(0);
    
    ctrl = bst_get('PanelControls', 'CoordinatesSeeg');
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
    if ~isempty(hCoord)
        delete(hCoord(length(hCoord)-Loc+1));
        % num_contacts = round(str2double(ctrl.jTextNcontacts.getText()));
        % ctrl.jTextNcontacts.setText(sprintf("%d", num_contacts+1));
        ctrl.listModel.remove(Loc-1);
    end

    % Find all selected points text
    hText = findobj(0, 'Tag', 'txtCoordinates'); 
    % Remove coordinates from the figures
    for i = 1:length(hText)
        hFig = get(get(hText(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete selected points text
    if ~isempty(hText)
        delete(hText(length(hText)-Loc+1));
    end
    
    % Find all selected points Coordinates1 in MRI space
    mriCoord1 = findobj(0, 'Tag', 'PointMarker1'); 
    % Remove coordinates from the figures
    for i = 1:length(mriCoord1)
        hFig = get(get(mriCoord1(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete selected points in MRI space
    if ~isempty(hCoord)
        delete(mriCoord1(length(hCoord)-Loc+1));
    end

    % Find all selected points Text1 in MRI space
    mriText1 = findobj(0, 'Tag', 'TextMarker1'); 
    % Remove coordinates from the figures
    for i = 1:length(mriText1)
        hFig = get(get(mriText1(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete selected points text in MRI space
    if ~isempty(hCoord)
        delete(mriText1(length(hCoord)-Loc+1));
    end
    
    % Find all selected points Coordinates2 in MRI space
    mriCoord2 = findobj(0, 'Tag', 'PointMarker2'); 
    % Remove coordinates from the figures
    for i = 1:length(mriCoord2)
        hFig = get(get(mriCoord2(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete selected points in MRI space
    if ~isempty(hCoord)
        delete(mriCoord2(length(hCoord)-Loc+1));
    end

    % Find all selected points Text2 in MRI space
    mriText2 = findobj(0, 'Tag', 'TextMarker2'); 
    % Remove coordinates from the figures
    for i = 1:length(mriText2)
        hFig = get(get(mriText2(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete selected points text in MRI space
    if ~isempty(hCoord)
        delete(mriText2(length(hCoord)-Loc+1));
    end

    % Find all selected points Coordinates3 in MRI space
    mriCoord3 = findobj(0, 'Tag', 'PointMarker3'); 
    % Remove coordinates from the figures
    for i = 1:length(mriCoord3)
        hFig = get(get(mriCoord3(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete selected points in MRI space
    if ~isempty(hCoord)
        delete(mriCoord3(length(hCoord)-Loc+1));
    end

    % Find all selected points Text3 in MRI space
    mriText3 = findobj(0, 'Tag', 'TextMarker3'); 
    % Remove coordinates from the figures
    for i = 1:length(mriText3)
        hFig = get(get(mriText3(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete selected points text in MRI space
    if ~isempty(hCoord)
        delete(mriText3(length(hCoord)-Loc+1));
    end

    % delete text from panel
    
    % Update displayed coordinates
    UpdatePanel();
end

%% ===== REMOVE SELECTION (LAST POINT) =====
function RemoveSelection(varargin)
    % Unselect selection button 
    % SetSelectionState(0);
    
    ctrl = bst_get('PanelControls', 'CoordinatesSeeg');
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
    if ~isempty(hCoord)
        delete(hCoord(1));
        num_contacts = round(str2double(ctrl.jTextNcontacts.getText()));
        ctrl.jTextNcontacts.setText(sprintf("%d", num_contacts+1));
        ctrl.listModel.remove(length(hCoord)-1);
    end

    % Find all selected points text
    hText = findobj(0, 'Tag', 'txtCoordinates'); 
    % Remove coordinates from the figures
    for i = 1:length(hText)
        hFig = get(get(hText(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete selected points text
    if ~isempty(hText)
        delete(hText(1));
    end
    
    % Find all selected points Coordinates1 in MRI space
    mriCoord1 = findobj(0, 'Tag', 'PointMarker1'); 
    % Remove coordinates from the figures
    for i = 1:length(mriCoord1)
        hFig = get(get(mriCoord1(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete selected points in MRI space
    if ~isempty(hCoord)
        delete(mriCoord1(1));
    end

    % Find all selected points Text1 in MRI space
    mriText1 = findobj(0, 'Tag', 'TextMarker1'); 
    % Remove coordinates from the figures
    for i = 1:length(mriText1)
        hFig = get(get(mriText1(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete selected points text in MRI space
    if ~isempty(hCoord)
        delete(mriText1(1));
    end
    
    % Find all selected points Coordinates2 in MRI space
    mriCoord2 = findobj(0, 'Tag', 'PointMarker2'); 
    % Remove coordinates from the figures
    for i = 1:length(mriCoord2)
        hFig = get(get(mriCoord2(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete selected points in MRI space
    if ~isempty(hCoord)
        delete(mriCoord2(1));
    end

    % Find all selected points Text2 in MRI space
    mriText2 = findobj(0, 'Tag', 'TextMarker2'); 
    % Remove coordinates from the figures
    for i = 1:length(mriText2)
        hFig = get(get(mriText2(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete selected points text in MRI space
    if ~isempty(hCoord)
        delete(mriText2(1));
    end

    % Find all selected points Coordinates3 in MRI space
    mriCoord3 = findobj(0, 'Tag', 'PointMarker3'); 
    % Remove coordinates from the figures
    for i = 1:length(mriCoord3)
        hFig = get(get(mriCoord3(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete selected points in MRI space
    if ~isempty(hCoord)
        delete(mriCoord3(1));
    end

    % Find all selected points Text3 in MRI space
    mriText3 = findobj(0, 'Tag', 'TextMarker3'); 
    % Remove coordinates from the figures
    for i = 1:length(mriText3)
        hFig = get(get(mriText3(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete selected points text in MRI space
    if ~isempty(hCoord)
        delete(mriText3(1));
    end

    % delete text from panel
    
    % Update displayed coordinates
    UpdatePanel();
end

%% ===== REMOVE SELECTION (ALL) =====
function RemoveSelectionAll(varargin)
    % Unselect selection button 
    SetSelectionState(0);
    
    ctrl = bst_get('PanelControls', 'CoordinatesSeeg');
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
    if ~isempty(hCoord)
        delete(hCoord);
        % num_contacts = round(str2double(ctrl.jTextNcontacts.getText()));
        % ctrl.jTextNcontacts.setText(sprintf("%d", 10));
        ctrl.listModel.removeAllElements();
    end

    % Find all selected points text
    hText = findobj(0, 'Tag', 'txtCoordinates'); 
    % Remove coordinates from the figures
    for i = 1:length(hText)
        hFig = get(get(hText(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete selected points text
    if ~isempty(hText)
        delete(hText);
    end
    
    % Find all selected points Coordinates1 in MRI space
    mriCoord1 = findobj(0, 'Tag', 'PointMarker1'); 
    % Remove coordinates from the figures
    for i = 1:length(mriCoord1)
        hFig = get(get(mriCoord1(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete selected points in MRI space
    if ~isempty(hCoord)
        for i=1:length(hCoord)
            delete(mriCoord1(i));
        end
    end

    % Find all selected points Text1 in MRI space
    mriText1 = findobj(0, 'Tag', 'TextMarker1'); 
    % Remove coordinates from the figures
    for i = 1:length(mriText1)
        hFig = get(get(mriText1(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete selected points text in MRI space
    if ~isempty(hCoord)
        for i=1:length(hCoord)
            delete(mriText1(i));
        end
    end
    
    % Find all selected points Coordinates2 in MRI space
    mriCoord2 = findobj(0, 'Tag', 'PointMarker2'); 
    % Remove coordinates from the figures
    for i = 1:length(mriCoord2)
        hFig = get(get(mriCoord2(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete selected points in MRI space
    if ~isempty(hCoord)
        for i=1:length(hCoord)
            delete(mriCoord2(i));
        end
    end

    % Find all selected points Text2 in MRI space
    mriText2 = findobj(0, 'Tag', 'TextMarker2'); 
    % Remove coordinates from the figures
    for i = 1:length(mriText2)
        hFig = get(get(mriText2(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete selected points text in MRI space
    if ~isempty(hCoord)
        for i=1:length(hCoord)
            delete(mriText2(i));
        end
    end

    % Find all selected points Coordinates3 in MRI space
    mriCoord3 = findobj(0, 'Tag', 'PointMarker3'); 
    % Remove coordinates from the figures
    for i = 1:length(mriCoord3)
        hFig = get(get(mriCoord3(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete selected points in MRI space
    if ~isempty(hCoord)
        for i=1:length(hCoord)
            delete(mriCoord3(i));
        end
    end

    % Find all selected points Text3 in MRI space
    mriText3 = findobj(0, 'Tag', 'TextMarker3'); 
    % Remove coordinates from the figures
    for i = 1:length(mriText3)
        hFig = get(get(mriText3(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete selected points text in MRI space
    if ~isempty(hCoord)
        for i=1:length(hCoord)
            delete(mriText3(i));
        end
    end

    % delete text from panel
    
    % Update displayed coordinates
    UpdatePanel();
end

%% ===== VIEW IN MRI VIEWER =====
function ViewInMriViewer(varargin)
    global GlobalData;

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
    

    % Select the required point
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

        if num_contacts==1
            % Unselect selection button 
            SetSelectionState(0);
        end
    end

    figure_mri('UpdateVisibleLandmarks', sMri, Handles);
    
end

%% ===== SAVE ALL TO DATABASE =====
function SaveAll(varargin)
    disp('Save all to database');
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