function varargout = panel_ieeg_anatomical(varargin)
% PANEL_IEEG_ANATOMICAL: Create a panel to manually add/remove/edit seeg contacts on an isosurface generated from thresholding CT.
% 
% USAGE:  bstPanelNew = panel_ieeg_anatomical('CreatePanel')
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
    panelName = 'ContactLabelIeeg';
    
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.icon.*;

    % Create tools panel
    jPanelNew = gui_component('Panel');
    jPanelNew.setPreferredSize(java_scaled('dimension', 320,500));

    % Create list for keeping track of the selected contact points
    listModel = javax.swing.DefaultListModel(); % can use java_create('javax.swing.DefaultListModel');

    % Hack keyboard callback
    hFig = bst_figures('GetCurrentFigure', '3D');
    KeyPressFcn_bak = get(hFig, 'KeyPressFcn');
    set(hFig, 'KeyPressFcn', @KeyPress_Callback);

    % ===== CREATE TOOLBAR =====
    jToolbar = gui_component('Toolbar', jPanelNew, BorderLayout.NORTH);
    jToolbar.setPreferredSize(java_scaled('dimension', 100,25));
        % Button "Draw Line"
        jButtonDrawLine = gui_component('ToolbarButton', jToolbar, [], 'RefLine', IconLoader.ICON_SCOUT_NEW, 'Draw line', @DrawLine);
        % Button "Setting reference contacts based on tip and entry"
        jButtonInitGuess = gui_component('ToolbarButton', jToolbar, [], 'RefCont', IconLoader.ICON_SCOUT_NEW, 'Reference contacts for an electrode', @ReferenceContacts);
        % Button "Show/Hide reference"
        gui_component('ToolbarButton', jToolbar, [], 'DispRef', IconLoader.ICON_SCOUT_NEW, 'Show/Hide reference contacts for an electrode', @ShowHideReference);
        % Button "Remove selection"
        jButtonRemoveSelected = gui_component('ToolbarButton', jToolbar, [], 'DelSel', IconLoader.ICON_DELETE, 'Remove selected contact', @(h,ev)bst_call(@RemoveContactAtLocation_Callback,h,ev));
        % Button "Remove selection"
        jButtonRemoveLast = gui_component('ToolbarButton', jToolbar, [], 'DelLast', IconLoader.ICON_DELETE, 'Remove last contact', @RemoveLastContact);
        % Button "Remove selection"
        jButtonRemoveAll = gui_component('ToolbarButton', jToolbar, [], 'DelAll', IconLoader.ICON_DELETE, 'Remove all the contacts', @RemoveAllContacts);
        % Button "Save all to database"
        jButtonSaveAll = gui_component('ToolbarButton', jToolbar, [], 'Save', IconLoader.ICON_SAVE, 'Save all to database', @SaveAll);
                  
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
                    'MouseClickedCallback', @(h,ev)bst_call(@ElecListClick_Callback,h,ev), ...
                    'KeyTypedCallback',     @(h,ev)bst_call(@ElecListKeyTyped_Callback,h,ev));
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
            jTextNcontacts = gui_component('label', jPanelCoordinates, 'tab', '', [], [], [], 0);
            jTextLabel = gui_component('label', jPanelCoordinates, 'tab', '', [], [], [], 0);
            jTextContactSpacing = gui_component('label', jPanelCoordinates, 'tab', '', [], [], [], 0);
        jPanelMain.add(jPanelCoordinates, BorderLayout.SOUTH);
    jPanelNew.add(jPanelMain, BorderLayout.CENTER);

    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jTextNcontacts',         jTextNcontacts, ...
                                  'jTextLabel',             jTextLabel, ...
                                  'jTextContactSpacing',    jTextContactSpacing, ...
                                  'jPanelCoordinates',      jPanelCoordinates, ...
                                  'jListElec',              jListElec, ...
                                  'jPanelElecList',         jPanelElecList, ...
                                  'listModel',              listModel, ...
                                  'jButtonInitGuess',       jButtonInitGuess, ...
                                  'jButtonRemoveSelected',  jButtonRemoveSelected, ...
                                  'jButtonRemoveLast',      jButtonRemoveLast, ...
                                  'jButtonRemoveAll',       jButtonRemoveAll, ...
                                  'jButtonDrawLine',        jButtonDrawLine, ...
                                  'jButtonSaveAll',         jButtonSaveAll));
                                  

    %% ============================================================================
    %  ========= INTERNAL PANEL CALLBACKS  (WHEN USER IS USING THE PANEL) =========
    %  ============================================================================

    %% ===== LIST CLICK CALLBACK =====
    function ElecListClick_Callback(h, ev)
        % IF SINGLE CLICK
        if (ev.getClickCount() == 1)
            % Set cursor location on MRI
            ctrl = bst_get('PanelControls', 'ContactLabelIeeg'); 
            iIndex = uint16(ctrl.jListElec.getSelectedIndices())' + 1;
            if isempty(iIndex)
                return;
            end
            SetLocationMri(iIndex);
        end
        
        % IF DOUBLE CLICK
        if (ev.getClickCount() == 2)
            
        end
    end   
    
    %% ===== LIST KEYTYPED CALLBACK =====
    function ElecListKeyTyped_Callback(h, ev)
        switch(uint8(ev.getKeyChar()))
            case {ev.VK_DELETE}
                % Delete contact a location
                RemoveContactAtLocation_Callback(h, ev);
            case {ev.VK_ESCAPE}
                % exit the selection state to stop plotting contacts
                SetSelectionState(0);
        end
    end
    
    %% ===== REMOVE AT A LOCATION (DELETE SPECIFIC CONTACT) =====
    function RemoveContactAtLocation_Callback(h, ev)
        % Delete selection
        ctrl = bst_get('PanelControls', 'ContactLabelIeeg'); 
        iPoint = uint16(ctrl.jListElec.getSelectedIndices())' + 1;
        if isempty(iPoint)
            return;
        end
        isDelete = java_dialog('confirm', ...
        '<HTML><BR>Do you want to delete the label?<BR><BR>', ...
        'Delete label');  
        if isDelete
            RemoveContactAtLocation(iPoint);
        end
    end
end
           
%% =================================================================================
%  === EXTERNAL PANEL CALLBACKS  ===================================================
%  =================================================================================

%% ===== REFERENCE CONTACTS FOR AN ELECTRODE =====
function ReferenceContacts(varargin)
    global CoordFileMat;

    % Get panel controls
    ctrl = bst_get('PanelControls', 'ContactLabelIeeg');
    if isempty(ctrl)
        return
    end
    
    contact_spacing = str2double(ctrl.jTextContactSpacing.getText());
    num_contacts = str2double(ctrl.jTextNContacts.getText()) + 2;    

    hFig = bst_figures('GetFiguresByType', '3DViz');
    SubjectFile = getappdata(hFig, 'SubjectFile');
    if ~isempty(SubjectFile)
        sSubject = bst_get('Subject', SubjectFile);
        MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
    end
    sMri = bst_memory('LoadMri', MriFile);
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');

    % Get electrode orientation
    elecTipMri = cs_convert(sMri, 'world', 'mri', CoordFileMat.Channel(1).Loc./1000);
    entryMri = cs_convert(sMri, 'world', 'mri', CoordFileMat.Channel(2).Loc./1000);
    orient = entryMri - elecTipMri;
    orient = orient ./ sqrt(sum(orient .^ 2));

    for i = 1:num_contacts
        % Compute the default position of the contact
        posMri = elecTipMri + (i - 1) * (contact_spacing/1000) * orient;
        pos = cs_convert(sMri, 'mri', 'scs', posMri);

        line(pos(1), pos(2), pos(3), ...
             'MarkerFaceColor', [1 0 1], ...
             'MarkerEdgeColor', [1 0 1], ...
             'Marker',          'o',  ...
             'MarkerSize',      10, ...
             'LineWidth',       2, ...
             'Parent',          hAxes, ...
             'Tag',             'ptCoordinates1');
    end
    
    ctrl.jButtonInitGuess.setEnabled(0);
    
    UpdatePanel();
end

%% ===== LOAD DATA =====
function LoadOnStart()
    global CoordFileMat;
    global linePlotLoc;
    global isRefVisible;
    
    CoordFileMat = [];
    linePlotLoc = [];
    isRefVisible = 1;

    % Get panel controls
    ctrl = bst_get('PanelControls', 'ContactLabelIeeg');
    if isempty(ctrl)
        return
    end

    hFig = bst_figures('GetCurrentFigure', '3D');
    SubjectFile = getappdata(hFig, 'SubjectFile');
    if ~isempty(SubjectFile)
        sSubject = bst_get('Subject', SubjectFile);
        MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
    end
    ProtocolInfo = bst_get('ProtocolInfo');
    CoordDir   = bst_fullfile(ProtocolInfo.SUBJECTS, bst_fileparts(MriFile));
    CoordFile  = bst_fullfile(CoordDir, 'channel_seeg.mat');
    
    
    % if file exists for the subject
    if isfile(CoordFile)
        CoordFileMat = load(CoordFile);
        
        % SurfaceFile = sSubject.Surface(sSubject.iScalp).FileName;
        % hFig1 = view_mri(sSubject.Anatomy(sSubject.iAnatomy).FileName, SurfaceFile);
        hFig1 = view_mri(sSubject.Anatomy(sSubject.iAnatomy).FileName);
        
        isProgress = bst_progress('isVisible');
        if ~isProgress
            bst_progress('start', 'Loading sEEG contacts', 'Loading sEEG contact');
        end

        % reset the list for fresh data
        ctrl.listModel.removeAllElements();

        for i=1:length(CoordFileMat.Channel)
            bst_progress('text', sprintf('Loading sEEG contact [%d/%d]', i, length(CoordFileMat.Channel)));
            
            % STEP-1: update the Panel with laoded data
            sMri = bst_memory('LoadMri', MriFile);
            str = string(CoordFileMat.Channel(i).Name);
            label_name = regexp(str, '[A-Za-z'']', 'match'); % A-Z, a-z, '
            num_contacts = regexp(str, '\d*', 'match');
            
            ctrl.jTextLabel.setText(strjoin(label_name, ''));
            ctrl.jTextNcontacts.setText(num_contacts);

            ctrl.listModel.addElement(sprintf('%s   %3.2f   %3.2f   %3.2f', strjoin(label_name, '') + num_contacts, CoordFileMat.Channel(i).Loc));
            plotLocWorld = CoordFileMat.Channel(i).Loc ./ 1000;
            plotLocScs = cs_convert(sMri, 'world', 'scs', plotLocWorld); 

            % STEP-2: update the 3D points on the surface with loaded data
            % ===== PLOT MARKER =====
            % Mark new point
            hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
            line(plotLocScs(1), plotLocScs(2), plotLocScs(3), ...
                 'MarkerFaceColor', [1 1 0], ...
                 'MarkerEdgeColor', [1 1 0], ...
                 'Marker',          'o',  ...
                 'MarkerSize',      10, ...
                 'LineWidth',       2, ...
                 'Parent',          hAxes, ...
                 'Tag',             'ptCoordinates');

            text(plotLocScs(1), plotLocScs(2), plotLocScs(3), ...
                '         ' + string(strjoin(label_name, '') + num_contacts), ...
                'HorizontalAlignment','center', ...
                'FontSize', 10, ...
                'Color',  [1 1 0], ...
                'Parent', hAxes, ...
                'Tag', 'txtCoordinates');
            
            linePlotLoc = [linePlotLoc, plotLocScs'];

            % STEP-3: update the MriViewer with points from the loaded data
            Handles = bst_figures('GetFigureHandles', hFig1);
            
            % Select the required point
            plotLocMri = cs_convert(sMri, 'scs', 'mri', plotLocScs);
            Handles.LocEEG(1,:) = plotLocMri .* 1000;
            Channels(1).Name = string(ctrl.jTextLabel.getText()) + string(ctrl.jTextNcontacts.getText());
            Handles.hPointEEG(1,:) = figure_mri('PlotPoint', sMri, Handles, Handles.LocEEG(1,:), [1 1 0], 5, Channels(1).Name);
            Handles.hTextEEG(1,:)  = figure_mri('PlotText', sMri, Handles, Handles.LocEEG(1,:), [1 1 0], Channels(1).Name, Channels(1).Name);
        
            num_contacts = round(str2double(ctrl.jTextNcontacts.getText()));
            ctrl.jTextNcontacts.setText(sprintf("%d", num_contacts-1));
    
            if num_contacts==1
                % Unselect selection button 
                SetSelectionState(0);
            end
        
            figure_mri('UpdateVisibleLandmarks', sMri, Handles);
        end
        SetSelectionState(0);
    
    % if file does not exist for the subject
    else
        CoordFileMat = db_template('channelmat'); 
        
        res = java_dialog('input', {'Number of contacts', 'Label Name', 'Contact Spacing (mm)'}, ...
                                'Enter electrode details', ...
                                [], ...
                                {num2str(10), 'A', num2str(2)});
        if isempty(res)
            return;
        end
        SetSelectionState(1);
        ctrl.jTextNcontacts.setText(res{1});
        ctrl.jTextLabel.setText(res{2});
        ctrl.jTextContactSpacing.setText(res{3});
    end
    
    % panel_scout('CreateAtlasCluster', 1);

    UpdatePanel();
    bst_progress('stop');
end

%% ===== SET CROSS-HAIR POSITION ON MRI =====
function SetLocationMri(iIndex)
    global CoordFileMat;

    % Get current 3D figure
    hFig = bst_figures('GetFiguresByType', {'MriViewer'});
    if isempty(hFig)
        return
    end    
    SubjectFile = getappdata(hFig, 'SubjectFile');
    if ~isempty(SubjectFile)
        sSubject = bst_get('Subject', SubjectFile);
        MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
    end
    sMri = bst_memory('LoadMri', MriFile);

    % Select the required point
    plotLocWorld = CoordFileMat.Channel(iIndex).Loc ./ 1000;
    plotLocScs = cs_convert(sMri, 'world', 'scs', plotLocWorld); 
    plotLocMri = cs_convert(sMri, 'scs', 'mri', plotLocScs);

    figure_mri('SetLocation', 'mri', hFig, [], plotLocMri);    
end

%% ===== UPDATE CALLBACK =====
function UpdatePanel()
    global CoordFileMat;

    % Get panel controls
    ctrl = bst_get('PanelControls', 'ContactLabelIeeg');
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
        
        % add new contact to the list
        CoordData = db_template('channeldesc');
        CoordData.Name = char(label_name + num2str(num_contacts));
        CoordData.Comment = 'World Coordinate System';
        CoordData.Type = 'EEG';
        CoordData.Loc = CoordinatesSelector.World' .* 1000;
        CoordData.Weight = 1;
        
        CoordFileMat.Channel = [CoordFileMat.Channel, CoordData];
        CoordFileMat.HeadPoints.Loc(:,end+1) = CoordData.Loc;
        CoordFileMat.HeadPoints.Label = [CoordFileMat.HeadPoints.Label, {CoordData.Name}];
        CoordFileMat.HeadPoints.Type = [CoordFileMat.HeadPoints.Type, {'EXTRA'}];

        if isempty(CoordFileMat.IntraElectrodes)
            IntraElecData = db_template('intraelectrode');
            IntraElecData.Name = char(ctrl.jTextLabel.getText());
            IntraElecData.Type = 'SEEG';
            IntraElecData.Color = [0 0.8 0];
            IntraElecData.ContactSpacing = str2double(ctrl.jTextContactSpacing.getText()) / 1000;
            IntraElecData.Visible = 1;

            CoordFileMat.IntraElectrodes = [CoordFileMat.IntraElectrodes, IntraElecData];
        
        else
            isPresent = 0;
            for i=1:length(CoordFileMat.IntraElectrodes)
                if strcmpi(CoordFileMat.IntraElectrodes(i).Name, char(ctrl.jTextLabel.getText()))
                    isPresent = 1;
                end
            end

            if ~isPresent
                IntraElecData = db_template('intraelectrode');
                IntraElecData.Name = char(ctrl.jTextLabel.getText());
                IntraElecData.Type = 'SEEG';
                IntraElecData.Color = [0 0.8 0];
                IntraElecData.ContactSpacing = str2double(ctrl.jTextContactSpacing.getText()) / 1000;
                IntraElecData.Visible = 1;
    
                CoordFileMat.IntraElectrodes = [CoordFileMat.IntraElectrodes, IntraElecData];
            end
        end
    end

    % Set this list
    ctrl.jListElec.setModel(ctrl.listModel);
    ctrl.jListElec.repaint();
    drawnow;
end

%% ===== FOCUS CHANGED ======
function FocusChangedCallback(isFocused) %#ok<DEFNU>
    if ~isFocused
        RemoveAllContacts();
    end
end

%% ===== CURRENT FIGURE CHANGED =====
function CurrentFigureChanged_Callback() %#ok<DEFNU>
    UpdatePanel();
end

%% ===== KEYBOARD CALLBACK =====
function KeyPress_Callback(hFig, keyEvent)
    global linePlotLoc;
    
    ctrl = bst_get('PanelControls', 'ContactLabelIeeg');

    switch (keyEvent.Key)
        case {'l'}
            % label contacts
            res = java_dialog('input', {'Number of contacts', 'Label Name', 'Contact Spacing (mm)'}, ...
                                'Enter electrode details', ...
                                [], ...
                                {num2str(10), 'A', num2str(2)});
            if isempty(res)
                return;
            end
            SetSelectionState(1);
            ctrl.jTextNcontacts.setText(res{1});
            ctrl.jTextLabel.setText(res{2});
            ctrl.jTextContactSpacing.setText(res{3});
            ctrl.jButtonInitGuess.setEnabled(1);
            linePlotLoc = [];
        
        case {'escape'}
            % exit the selection state to stop plotting contacts
            SetSelectionState(0);
        
        case {'r'}
            % resume the selection state to continue plotting contacts
            % from where it was last stopped

            num_contacts = round(str2double(ctrl.jTextNcontacts.getText()));
            label_name = string(ctrl.jTextLabel.getText());
            if num_contacts==0
                % label contacts
                res = java_dialog('input', {'Number of contacts', 'Label Name', 'Contact Spacing (mm)'}, ...
                                'Enter electrode details', ...
                                [], ...
                                {num2str(10), 'A', num2str(2)});
                if isempty(res)
                    return;
                end
                SetSelectionState(1);
                ctrl.jTextNcontacts.setText(res{1});
                ctrl.jTextLabel.setText(res{2});
                ctrl.jTextContactSpacing.setText(res{3});
                ctrl.jButtonInitGuess.setEnabled(1);
                linePlotLoc = [];
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
            % KeyPressFcn_bak(hFig, keyEvent); 
            return;
    end
end

%% ===== POINT SELECTION : start/stop =====
% Manual selection of a surface point : start(1), or stop(0)
function SetSelectionState(isSelected)
    % Get panel controls
    ctrl = bst_get('PanelControls', 'ContactLabelIeeg');
    if isempty(ctrl)
        return
    end
    % Get list of all figures
    hFigures = bst_figures('GetAllFigures');
    if isempty(hFigures)
        % ctrl.jButtonSelect.setSelected(0);
        return
    end
    % Start selection
    if isSelected
        % Push toolbar "Select" button 
        % ctrl.jButtonSelect.setSelected(1);        
        % Set 3DViz figures in 'SelectingCorticalSpot' mode
        for hFig = hFigures
            % Keep only figures with surfaces
            TessInfo = getappdata(hFig, 'Surface');
            if ~isempty(TessInfo)
                setappdata(hFig, 'isSelectingContactLabelIeeg', 1);
                set(hFig, 'Pointer', 'cross');
            end
        end
    % Stop selection
    else
        % Release toolbar "Select" button 
        % ctrl.jButtonSelect.setSelected(0);
        % Exit 3DViz figures from SelectingCorticalSpot mode
        for hFig = hFigures
            set(hFig, 'Pointer', 'arrow');
            setappdata(hFig, 'isSelectingContactLabelIeeg', 0);      
        end
    end
end

%% ===== SELECT POINT =====
% Usage : SelectPoint(hFig) : Point location = user click in figure hFIg
function vi = SelectPoint(hFig, AcceptMri) %#ok<DEFNU>
    global linePlotLoc;

    % parse arguments
    if (nargin < 2) || isempty(AcceptMri)
        AcceptMri = 1;
    end

    % Get panel controls
    ctrl = bst_get('PanelControls', 'ContactLabelIeeg');

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
    CoordinatesSelector.SCS     = plotLoc;
    CoordinatesSelector.MRI     = cs_convert(sMri, 'scs', 'mri', plotLoc);
    CoordinatesSelector.MNI     = cs_convert(sMri, 'scs', 'mni', plotLoc);
    CoordinatesSelector.World   = cs_convert(sMri, 'scs', 'world', plotLoc);
    CoordinatesSelector.iVertex = iVertex;
    CoordinatesSelector.Value   = Value;
    CoordinatesSelector.hPatch  = hPatch;
    setappdata(hFig, 'CoordinatesSelector', CoordinatesSelector);
    
    % ===== PLOT MARKER =====
    % Remove previous mark
    % delete(findobj(hAxes, '-depth', 1, 'Tag', 'ptCoordinates'));
    % Mark new point
    line(plotLoc(1), plotLoc(2), plotLoc(3), ...
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
    
    linePlotLoc = [linePlotLoc, plotLoc'];
    
    % Update "Coordinates" panel
    UpdatePanel();
    ViewInMriViewer();
end

%% ===== POINT SELECTION: Surface detection =====
function [TessInfo, iTess, pout, vout, vi, hPatch] = ClickPointInSurface(hFig, SurfacesType)
    % set global variable to track the vetices in around a selected point on surface
    global VertexList;
    VertexList = [];
    
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
    
    [iTess, TessInfo, hFig, sSurf] = panel_surface('GetSelectedSurface', hFig);
    % Labels = tess_cluster(sSurf.VertConn, 30, 1);

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
        [pout{i}, vout{i}, vi{i}, facevout{i}, fi{i}] = select3d(hPatch(i));
        
        if ~isempty(pout{i})
            patchDist(i) = norm(pout{i}' - CameraPosition);
        else
            patchDist(i) = Inf;
        end

        FindCentroid(sSurf, find(sSurf.VertConn(vi{i},:)), 1, 6);
        vout{i} = mean(sSurf.Vertices(VertexList(:), :));
        VertexList = [];
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

%% ===== FIND CENTROID OF A CONTACT =====
function FindCentroid(sSurf, listCoord, cnt, cntThresh)
    global VertexList;

    if cnt == cntThresh
        return;
    else
        for i=1:length(listCoord)
            if ~any(VertexList(:) == listCoord(i))
                VertexList = [VertexList, listCoord(i)];
                listCoord1 = find(sSurf.VertConn(listCoord(i),:));
                FindCentroid(sSurf, listCoord1, cnt, cntThresh);
                cnt = cnt + 1;
            end
        end
    end
end

%% ===== DRAW LINE =====
% this function renders a line between the 1st two initial points of the electrode
% - the tip point and the entry point - that gives the orientation of the electrode
% which serves as a reference for the user  
function DrawLine(varargin)
    global linePlotLoc;
    
    % Get axes handle
    hFig = bst_figures('GetFiguresByType', '3DViz');
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    line(linePlotLoc(1,:), linePlotLoc(2,:), linePlotLoc(3,:), ...
         'Color', [1 1 0], ...
         'LineWidth',       2, ...
         'Parent', hAxes, ...
         'Tag', 'lineCoordinates');
end

%% ===== SHOW/HIDE REFERENCE POINTS AND LINES =====
function ShowHideReference(varargin)
    global isRefVisible;

    refCoord = findobj(0, 'Tag', 'ptCoordinates1');
    lineCoord = findobj(0, 'Tag', 'lineCoordinates');
    
    if isRefVisible
        set(refCoord, 'Visible', 'off');
        set(lineCoord, 'Visible', 'off');
        isRefVisible = 0;
    else
        set(refCoord, 'Visible', 'on');
        set(lineCoord, 'Visible', 'on');
        isRefVisible = 1;
    end
end

%% ===== REMOVE AT A LOCATION (DELETE SPECIFIC CONTACT) =====
function RemoveContactAtLocation(Loc)
    % Unselect selection button 
    % SetSelectionState(0);
    
    global CoordFileMat;

    ctrl = bst_get('PanelControls', 'ContactLabelIeeg');
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
        ctrl.listModel.remove(Loc-1);

        % delete from mat
        CoordFileMat.Channel(Loc) = [];
        
        % make sure the Channel sturture field is cleared when no contacts
        % are marked
        if length(hCoord) == 1
            CoordFileMat.Channel = [];
        end

        CoordFileMat.HeadPoints.Loc(:, Loc) = [];
        CoordFileMat.HeadPoints.Label(Loc) = [];
        CoordFileMat.HeadPoints.Type(Loc) = [];
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

    % Update displayed coordinates
    UpdatePanel();
end

%% ===== REMOVE LAST CONTACT =====
function RemoveLastContact(varargin)
    % Unselect selection button 
    % SetSelectionState(0);
    
    global CoordFileMat;

    ctrl = bst_get('PanelControls', 'ContactLabelIeeg');
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
        num_contacts = round(str2double(ctrl.jTextNcontacts.getText()));
        label_name = string(ctrl.jTextLabel.getText());

        delete(hCoord(1));
      
        ctrl.jTextNcontacts.setText(sprintf("%d", num_contacts+1));
        ctrl.jTextLabel.setText(label_name);
        ctrl.listModel.remove(length(hCoord)-1);
        CoordFileMat.Channel(length(hCoord)) = [];
        CoordFileMat.HeadPoints.Loc(:, length(hCoord)) = [];
        CoordFileMat.HeadPoints.Label(length(hCoord)) = [];
        CoordFileMat.HeadPoints.Type(length(hCoord)) = [];

        % make sure the Channel sturture field is cleared when no contacts
        % are marked
        if length(hCoord) == 1
            CoordFileMat.Channel = [];
        end
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
    
    % Update displayed coordinates
    UpdatePanel();
end

%% ===== REMOVE ALL CONTACTS =====
function RemoveAllContacts(varargin)
    global CoordFileMat;

    % Unselect selection button 
    SetSelectionState(0);
    
    ctrl = bst_get('PanelControls', 'ContactLabelIeeg');
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
        ctrl.jTextNcontacts.setText(sprintf("%d", 0));
        CoordFileMat.Channel = [];
        CoordFileMat.HeadPoints.Loc = [];
        CoordFileMat.HeadPoints.Label = [];
        CoordFileMat.HeadPoints.Type = [];
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

    % Update displayed coordinates
    UpdatePanel();
end

%% ===== VIEW IN MRI VIEWER =====
function ViewInMriViewer(varargin)
    global GlobalData;

    % Get panel controls
    ctrl = bst_get('PanelControls', 'ContactLabelIeeg');

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
    % SurfaceFile = sSubject.Surface(sSubject.iScalp).FileName;
    % hFig = view_mri(sSubject.Anatomy(sSubject.iAnatomy).FileName, SurfaceFile);
    hFig = view_mri(sSubject.Anatomy(sSubject.iAnatomy).FileName);
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
    global CoordFileMat;

    % Get panel controls
    ctrl = bst_get('PanelControls', 'ContactLabelIeeg');
    if isempty(ctrl)
        return
    end

    hFig = bst_figures('GetCurrentFigure', '3D');
    SubjectFile = getappdata(hFig, 'SubjectFile');
    if ~isempty(SubjectFile)
        sSubject = bst_get('Subject', SubjectFile);
        MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
    end

    bst_progress('start', 'Saving sEEG contacts', 'Saving new file...');

    % Create output filenames
    ProtocolInfo = bst_get('ProtocolInfo');
    CoordDir   = bst_fullfile(ProtocolInfo.SUBJECTS, bst_fileparts(MriFile));
    % CoordFile  = file_unique(bst_fullfile(CoordDir, 'isomesh_ct_coordinates_seeg.mat'));
    CoordFile  = bst_fullfile(CoordDir, 'channel_seeg.mat');
    
    % Save coordinates to file
    CoordFileMat.Comment = sprintf('EEG coordinates');
    CoordFileMat = bst_history('add', CoordFileMat, 'test', 'saved coordinates');
    bst_save(CoordFile, CoordFileMat, 'v7');
    
    bst_progress('stop');
end