function varargout = panel_ieeg(varargin)
% PANEL_IEEG: Create a panel to edit SEEG/ECOG contact positions.
% 
% USAGE:  bstPanelNew = panel_ieeg('CreatePanel')
%                       panel_ieeg('UpdatePanel')
%                       panel_ieeg('UpdateElecList')
%                       panel_ieeg('UpdateElecProperties')
%                       panel_ieeg('CurrentFigureChanged_Callback')

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
% Authors: Francois Tadel, 2017-2022
%          Chinmay Chinara, 2024

eval(macro_method);
end


%% ===== CREATE PANEL =====
function bstPanelNew = CreatePanel() %#ok<DEFNU>
    panelName = 'iEEG';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.icon.*;
    % Create tools panel
    jPanelNew = gui_component('Panel');
    jPanelTop = gui_component('Panel');
    jPanelNew.add(jPanelTop, BorderLayout.NORTH);
    TB_DIM = java_scaled('dimension',25,25);
    
    % ===== TOOLBAR =====
    jMenuBar = gui_component('MenuBar', jPanelTop, BorderLayout.NORTH);
        jToolbar = gui_component('Toolbar', jMenuBar);
        jToolbar.setPreferredSize(TB_DIM);
        jToolbar.setOpaque(0);
        % Add/remove
        gui_component('ToolbarButton', jToolbar,[],[], {IconLoader.ICON_PLUS, TB_DIM}, 'Add new electrode', @(h,ev)bst_call(@AddElectrode));
        gui_component('ToolbarButton', jToolbar,[],[], {IconLoader.ICON_MINUS, TB_DIM}, 'Remove selected electrodes', @(h,ev)bst_call(@RemoveElectrode));
        % Button "Select vertex"
        jButtonSelect = gui_component('ToolbarToggle', jToolbar, [], '', IconLoader.ICON_SCOUT_NEW, 'Select surface point', @(h,ev)panel_coordinates('SetSelectionState', ev.getSource.isSelected()));
        % Set color
        jToolbar.addSeparator();
        gui_component('ToolbarButton', jToolbar,[],[], {IconLoader.ICON_COLOR_SELECTION, TB_DIM}, 'Select color for selected electrodes', @(h,ev)bst_call(@EditElectrodeColor));
        % Show/Hide
        jButtonShow = gui_component('ToolbarToggle', jToolbar, [], [], {IconLoader.ICON_DISPLAY, TB_DIM}, 'Show/hide selected electrodes', @(h,ev)bst_call(@SetElectrodeVisible, ev.getSource().isSelected()));
        jButtonShow.setSelected(1);
        % Set display mode
        jToolbar.addSeparator();
        jButtonGroup = ButtonGroup();
        jRadioDispDepth  = gui_component('ToolbarToggle', jToolbar, [], [], {IconLoader.ICON_SEEG_DEPTH,  jButtonGroup, TB_DIM}, 'Display contacts as SEEG electrodes/ECOG strips', @(h,ev)bst_call(@SetDisplayMode, 'depth'));
        jRadioDispSphere = gui_component('ToolbarToggle', jToolbar, [], [], {IconLoader.ICON_SEEG_SPHERE, jButtonGroup, TB_DIM}, 'Display contacts as spheres', @(h,ev)bst_call(@SetDisplayMode, 'sphere'));
        % Menu: Contacts
        jToolbar.addSeparator();
        jMenuContacts = gui_component('ToolbarButton', jToolbar, [], 'Contacts', IconLoader.ICON_MENU, '', @(h,ev)ShowContactsMenu(ev.getSource()), []);

    % ===== PANEL MAIN =====
    jPanelMain = gui_component('Panel');
    jPanelMain.setBorder(BorderFactory.createEmptyBorder(7,7,7,7));

        % ===== FIRST PART =====
        jPanelFirstPart = gui_component('Panel');
            % ===== ELECTRODES LIST =====
            jPanelElecList = gui_component('Panel');
                jBorder = java_scaled('titledborder', 'Electrodes & Contacts');
                jPanelElecList.setBorder(jBorder);
                % Coodinate radio buttons
                jPanelModelCoord = gui_river([2,2], [0,0,0,0]);
                gui_component('label', jPanelModelCoord, '', ' Coordinates (millimeters): ');
                jButtonGroupCoord = ButtonGroup();
                jRadioScs   = gui_component('radio', jPanelModelCoord, 'br', 'SCS ', jButtonGroupCoord, '', @(h,ev)UpdateContactList('SCS'));
                jRadioScs.setSelected(1);
                jRadioMri   = gui_component('radio', jPanelModelCoord, '',   'MRI ', jButtonGroupCoord, '', @(h,ev)UpdateContactList('MRI'));
                jRadioWorld = gui_component('radio', jPanelModelCoord, '', 'World ', jButtonGroupCoord, '', @(h,ev)UpdateContactList('World'));
                jRadioMni   = gui_component('radio', jPanelModelCoord, '',   'MNI ', jButtonGroupCoord, '', @(h,ev)UpdateContactList('MNI'));
                jPanelElecList.add(jPanelModelCoord, BorderLayout.NORTH);
                % Electrodes list
                jListElec = java_create('org.brainstorm.list.BstClusterList');
                jListElec.setBackground(Color(.9,.9,.9));
                jListElec.setLayoutOrientation(jListElec.VERTICAL_WRAP);
                jListElec.setVisibleRowCount(-1);
                java_setcb(jListElec, ...
                    'ValueChangedCallback', @(h,ev)bst_call(@ElecListValueChanged_Callback,h,ev), ...
                    'KeyTypedCallback',     @(h,ev)bst_call(@ElecListKeyTyped_Callback,h,ev), ...
                    'MouseClickedCallback', @(h,ev)bst_call(@ElecListClick_Callback,h,ev));
                jPanelScrollElecList = JScrollPane();
                jPanelScrollElecList.getLayout.getViewport.setView(jListElec);
                jPanelScrollElecList.setBorder([]);

                % Contacts list
                jListCont = java_create('org.brainstorm.list.BstClusterList');
                jListCont.setBackground(Color(.9,.9,.9));
                jListCont.setLayoutOrientation(jListCont.HORIZONTAL_WRAP);
                jListCont.setVisibleRowCount(-1);
                java_setcb(jListCont, ...
                    'ValueChangedCallback', @(h,ev)bst_call(@ContListChanged_Callback,h,ev));
                jPanelScrollContList = JScrollPane();
                jPanelScrollContList.getLayout.getViewport.setView(jListCont);
                jPanelScrollContList.setBorder([]);

                jSplitEvt = JSplitPane(JSplitPane.HORIZONTAL_SPLIT, jPanelScrollElecList, jPanelScrollContList);
                jSplitEvt.setResizeWeight(0.2);
                jSplitEvt.setDividerSize(4);
                jSplitEvt.setBorder([]);
                jPanelElecList.add(jSplitEvt, BorderLayout.CENTER);
            jPanelFirstPart.add(jPanelElecList, BorderLayout.CENTER);
        jPanelMain.add(jPanelFirstPart);

        jPanelBottom = gui_river([0,0], [0,0,0,0]);
            % ===== ELECTRODE OPTIONS =====
            jPanelElecOptions = gui_river([0,3], [0,5,10,3], 'Electrode configuration');
                % Electrode type
                gui_component('label', jPanelElecOptions, '', 'Type: ');
                jButtonGroup = ButtonGroup();
                jRadioSeeg = gui_component('radio', jPanelElecOptions, '', 'SEEG', jButtonGroup, '', @(h,ev)ValidateOptions('Type', ev.getSource()));
                jRadioEcog = gui_component('radio', jPanelElecOptions, '', 'ECOG', jButtonGroup, '', @(h,ev)ValidateOptions('Type', ev.getSource()));
                jRadioEcogMid = gui_component('radio', jPanelElecOptions, '', 'ECOG-mid', jButtonGroup, '', @(h,ev)ValidateOptions('Type', ev.getSource()));
                jRadioSeeg.setMargin(java.awt.Insets(0,0,0,0));
                jRadioEcog.setMargin(java.awt.Insets(0,0,0,0));
                jRadioEcogMid.setMargin(java.awt.Insets(0,0,0,0));
                % Electrode model
                jPanelModel = gui_river([0,0], [0,0,0,0]);
                    % Title
                    gui_component('label', jPanelModel, '', 'Model: ');
                    % Combo box
                    jComboModel = gui_component('combobox', jPanelModel, 'hfill', [], [], [], []);
                    jComboModel.setFocusable(0);
                    jComboModel.setMaximumRowCount(15);
                    jComboModel.setPreferredSize(java_scaled('dimension',30,20));
                    % ComboBox change selection callback
                    jModel = jComboModel.getModel();
                    java_setcb(jModel, 'ContentsChangedCallback', @(h,ev)bst_call(@ComboModelChanged_Callback,h,ev));
                    % Actions
                    gui_component('label',  jPanelModel, 'br', 'Actions: ');
                    % Add/remove models
                    gui_component('button', jPanelModel, [],[], {IconLoader.ICON_PLUS, TB_DIM}, 'Add new electrode model', @(h,ev)bst_call(@AddElectrodeModel));
                    gui_component('button', jPanelModel,[],[], {IconLoader.ICON_MINUS, TB_DIM}, 'Remove electrode model', @(h,ev)bst_call(@RemoveElectrodeModel));
                    % Save/load models
                    gui_component('button', jPanelModel, [],[], {IconLoader.ICON_SAVE, TB_DIM}, 'Save electrode model to file', @(h,ev)bst_call(@SaveElectrodeModel));
                    gui_component('button', jPanelModel,[],[], {IconLoader.ICON_FOLDER_OPEN, TB_DIM}, 'Load electrode model from file', @(h,ev)bst_call(@LoadElectrodeModel));
                    % Export/import models
                    gui_component('button', jPanelModel, [],[], {IconLoader.ICON_MATLAB_EXPORT, TB_DIM}, 'Export electrode model to Matlab', @(h,ev)bst_call(@ExportElectrodeModel));
                    gui_component('button', jPanelModel,[],[], {IconLoader.ICON_MATLAB_IMPORT, TB_DIM}, 'Import electrode model from Matlab', @(h,ev)bst_call(@ImportElectrodeModel));
                jPanelElecOptions.add('br hfill', jPanelModel);

                % Number of contacts
                gui_component('label', jPanelElecOptions, 'br', 'Number of contacts: ');
                jTextNcontacts = gui_component('text', jPanelElecOptions, 'tab', '');
                jTextNcontacts.setHorizontalAlignment(jTextNcontacts.RIGHT);
                % Contacts spacing
                gui_component('label', jPanelElecOptions, 'br', 'Contact spacing: ');
                jTextSpacing = gui_component('text', jPanelElecOptions, 'tab', '');
                jTextSpacing.setHorizontalAlignment(jTextNcontacts.RIGHT);
                gui_component('label', jPanelElecOptions, '', ' mm');
                % Contacts length
                jLabelContactLength = gui_component('label', jPanelElecOptions, 'br', 'Contact length: ');
                jTextContactLength  = gui_component('texttime', jPanelElecOptions, 'tab', '');
                gui_component('label', jPanelElecOptions, '', ' mm');
                % Contacts diameter
                gui_component('label', jPanelElecOptions, 'br', 'Contact diameter: ');
                jTextContactDiam = gui_component('texttime', jPanelElecOptions, 'tab', '');
                gui_component('label', jPanelElecOptions, '', ' mm');
                % Electrode diameter
                jLabelElecDiameter = gui_component('label', jPanelElecOptions, 'br', 'Electrode diameter: ');
                jTextElecDiameter  = gui_component('texttime', jPanelElecOptions, 'tab', '');
                jLabelElecDiamUnits = gui_component('label', jPanelElecOptions, '', ' mm');
                % Electrode length
                jLabelElecLength = gui_component('label', jPanelElecOptions, 'br', 'Electrode length: ');
                jTextElecLength  = gui_component('texttime', jPanelElecOptions, 'tab', '');
                jLabelElecLengthUnits = gui_component('label', jPanelElecOptions, '', ' mm');
                % Set electrode position
                jPanelButtons = gui_component('panel');
                    jCardLayout = java.awt.CardLayout;
                    jPanelButtons.setLayout(jCardLayout);
                    jPanelButtons.add(gui_component('panel'), 'none');
                    jPanelButtonsSeeg = gui_river([0,0], [0,0,0,0]);
                        jButtonSeegSet1 = gui_component('button', jPanelButtonsSeeg, 'center', 'Set tip',   [], '<HTML>Set electrode tip: contact #1<BR>(MRI Viewer must be open)', @(h,ev)bst_call(@SetElectrodeLoc, 1, ev.getSource()));
                        jButtonSeegSet2 = gui_component('button', jPanelButtonsSeeg, 'center', 'Set skull entry', [], '<HTML>Set entry point in the skull (does not match the position of a contact)<BR>(MRI Viewer must be open)', @(h,ev)bst_call(@SetElectrodeLoc, 2, ev.getSource()));
                    jPanelButtons.add(jPanelButtonsSeeg, 'seeg');
                    jPanelButtonsEcog = gui_river([0,0], [0,0,0,0]);
                        jButtonEcogSet1 = gui_component('button', jPanelButtonsEcog, 'center', '#1', [], '<HTML>Set contact #1 of the ECOG grid/strip<BR>(MRI Viewer must be open)', @(h,ev)bst_call(@SetElectrodeLoc, 1, ev.getSource()));
                        jButtonEcogSet2 = gui_component('button', jPanelButtonsEcog, 'center', '#2', [], '<HTML>ECOG strip: Set the last contact of the strip.<BR>ECOG grid: Set the second corner in the list of contacts.<BR>(MRI Viewer must be open)', @(h,ev)bst_call(@SetElectrodeLoc, 2, ev.getSource()));
                        jButtonEcogSet3 = gui_component('button', jPanelButtonsEcog, 'center', '#3', [], '<HTML>ECOG strip: N/A.<BR>ECOG grid: Set third corner of the grid (last contact, opposite to contact #1).<BR>(MRI Viewer must be open)', @(h,ev)bst_call(@SetElectrodeLoc, 3, ev.getSource()));
                        jButtonEcogSet4 = gui_component('button', jPanelButtonsEcog, 'center', '#4', [], '<HTML>ECOG strip: N/A.<BR>ECOG grid: Set third corner of the grid (opposite to contact #2).<BR>(MRI Viewer must be open)', @(h,ev)bst_call(@SetElectrodeLoc, 4, ev.getSource()));
                    jPanelButtons.add(jPanelButtonsEcog, 'ecog');
                    jCardLayout.show(jPanelButtons, 'seeg');
                jPanelElecOptions.add('br hfill', jPanelButtons);
                jPanelBottom.add('hfill', jPanelElecOptions);
                jPanelMain.add(jPanelBottom, BorderLayout.SOUTH)
    jPanelNew.add(jPanelMain, BorderLayout.CENTER);
    
    % Store electrode and contacts selection
    jLabelSelectElec = JLabel('');
    % Create the BstPanel object that is returned by the function
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jPanelMain',          jPanelMain, ...
                                  'jPanelElecList',      jPanelElecList, ...
                                  'jToolbar',            jToolbar, ...
                                  'jPanelElecOptions',   jPanelElecOptions, ...
                                  'jButtonSelect',       jButtonSelect, ...
                                  'jButtonShow',         jButtonShow, ...
                                  'jRadioDispDepth',     jRadioDispDepth, ...
                                  'jRadioDispSphere',    jRadioDispSphere, ...
                                  'jMenuContacts',       jMenuContacts, ...
                                  'jListElec',           jListElec, ...
                                  'jListCont',           jListCont, ...
                                  'jRadioMri',           jRadioMri, ...
                                  'jRadioScs',           jRadioScs, ...
                                  'jRadioWorld',         jRadioWorld, ...
                                  'jRadioMni',           jRadioMni, ...
                                  'jComboModel',         jComboModel, ...
                                  'jRadioSeeg',          jRadioSeeg, ...
                                  'jRadioEcog',          jRadioEcog, ...
                                  'jRadioEcogMid',       jRadioEcogMid, ...
                                  'jTextNcontacts',      jTextNcontacts, ...
                                  'jTextSpacing',        jTextSpacing, ...
                                  'jTextContactDiam',    jTextContactDiam, ...
                                  'jLabelContactLength', jLabelContactLength, ...
                                  'jTextContactLength',  jTextContactLength, ...
                                  'jLabelElecLength',    jLabelElecLength, ...
                                  'jTextElecLength',     jTextElecLength, ...
                                  'jLabelElecLengthUnits',jLabelElecLengthUnits, ...
                                  'jLabelElecDiameter',  jLabelElecDiameter, ...
                                  'jTextElecDiameter',   jTextElecDiameter, ...
                                  'jLabelElecDiamUnits', jLabelElecDiamUnits, ...
                                  'jLabelSelectElec',    jLabelSelectElec, ...
                                  'jPanelButtonsSeeg',   jPanelButtonsSeeg, ...
                                  'jPanelButtonsEcog',   jPanelButtonsEcog, ...
                                  'jPanelButtons',       jPanelButtons, ...
                                  'jCardLayout',         jCardLayout, ...
                                  'jButtonSeegSet1',     jButtonSeegSet1, ...
                                  'jButtonSeegSet2',     jButtonSeegSet2, ...
                                  'jButtonEcogSet1',     jButtonEcogSet1, ...
                                  'jButtonEcogSet2',     jButtonEcogSet2, ...
                                  'jButtonEcogSet3',     jButtonEcogSet3, ...
                                  'jButtonEcogSet4',     jButtonEcogSet4));
                              
    
                              
%% =================================================================================
%  === INTERNAL CALLBACKS  =========================================================
%  =================================================================================
        
    %% ===== MODEL SELECTION =====
    function ComboModelChanged_Callback(varargin)
        % Get selected model
        [iModel, sModels] = GetSelectedModel();
        % Get the selected electrode
        [sSelElec, iSelElec] = GetSelectedElectrodes();
        % Reset Model field
        if isempty(iModel)
            [sSelElec.Model] = deal([]);
        % Copy model values to electrodes
        else
            for i = 1:length(sSelElec)
                sSelElec(i).Model = sModels(iModel).Model;
                if ~isempty(sModels(iModel).ContactNumber)
                    sSelElec(i).ContactNumber = sModels(iModel).ContactNumber;
                end
                if ~isempty(sModels(iModel).ContactSpacing)
                    sSelElec(i).ContactSpacing = sModels(iModel).ContactSpacing;
                end
                if ~isempty(sModels(iModel).ContactDiameter)
                    sSelElec(i).ContactDiameter = sModels(iModel).ContactDiameter;
                end
                if ~isempty(sModels(iModel).ContactLength)
                    sSelElec(i).ContactLength = sModels(iModel).ContactLength;
                end
                if ~isempty(sModels(iModel).ElecDiameter)
                    sSelElec(i).ElecDiameter = sModels(iModel).ElecDiameter;
                end
                if ~isempty(sModels(iModel).ContactNumber)
                    sSelElec(i).ElecLength = sModels(iModel).ElecLength;
                end
            end
        end
        % Update electrode properties
        SetElectrodes(iSelElec, sSelElec);
        % Update display
        UpdateElecProperties(0);
        % Update figures
        UpdateFigures();
    end

    %% ===== ELECTRODE LIST SELECTION CHANGED CALLBACK =====
    function ElecListValueChanged_Callback(h, ev)
        if ~ev.getValueIsAdjusting()
            UpdateElecProperties();
            % Get the selected electrode
            [sSelElec, iSelElec] = GetSelectedElectrodes();
            % Center MRI view on electrode tip
            if (length(sSelElec) == 1)
                CenterMriOnElectrode(sSelElec);
            end
            % Unselect all contacts in list
            SetSelectedContacts(0);
            % Update contact list
            UpdateContactList();
        end
    end

    %% ===== ELECTRODE LIST KEY TYPED CALLBACK =====
    function ElecListKeyTyped_Callback(h, ev)
        switch(uint8(ev.getKeyChar()))
            % DELETE
            case {ev.VK_DELETE, ev.VK_BACK_SPACE}
                RemoveElectrode();
            case ev.VK_ESCAPE
                SetSelectedElectrodes(0);
        end
    end

    %% ===== ELECTRODE LIST CLICK CALLBACK =====
    function ElecListClick_Callback(h, ev)
        % If DOUBLE CLICK
        if (ev.getClickCount() == 2)
            % Rename selection
            EditElectrodeLabel();
        end
    end

    %% ===== CONTACT LIST CHANGED CALLBACK =====
    function ContListChanged_Callback(h, ev)
        ctrl = bst_get('PanelControls', 'iEEG');
        sContacts = GetSelectedContacts();
        bst_figures('SetSelectedRows', {sContacts.Name});
        SetMriCrosshair(sContacts);
    end
end
                   


%% =================================================================================
%  === EXTERNAL PANEL CALLBACKS  ===================================================
%  =================================================================================
%% ===== CURRENT FIGURE CHANGED =====
function CurrentFigureChanged_Callback(hFig) %#ok<DEFNU>
    UpdatePanel();
end

%% ===== UPDATE CALLBACK =====
function UpdatePanel()
    % Get panel controls
    ctrl = bst_get('PanelControls', 'iEEG');
    if isempty(ctrl)
        return;
    end
    % Get current figure
    hFig = bst_figures('GetCurrentFigure');
    % If a surface is available for current figure
    if ~isempty(hFig)
        gui_enable([ctrl.jPanelElecList, ctrl.jToolbar], 1);
        ctrl.jListElec.setBackground(java.awt.Color(1,1,1));
        ctrl.jListCont.setBackground(java.awt.Color(1,1,1));
    % Else: no figure associated with the panel : disable all controls
    else
        gui_enable([ctrl.jPanelElecList, ctrl.jToolbar], 0);
        ctrl.jListElec.setBackground(java.awt.Color(.9,.9,.9));
    end
    % Select appropriate display mode button
    if ~isempty(hFig)
        ElectrodeDisplay = getappdata(hFig(1), 'ElectrodeDisplay');
        if strcmpi(ElectrodeDisplay.DisplayMode, 'depth')
            ctrl.jRadioDispDepth.setSelected(1);
        else
            ctrl.jRadioDispSphere.setSelected(1);
        end
    end
%     % Disable options panel until an electrode is selected
%     gui_enable(ctrl.jPanelElecOptions, 0);
    % Update JList
    UpdateElecList();
    UpdateContactList('SCS');
end


%% ===== UPDATE ELECTRODE LIST =====
function UpdateElecList()
    import org.brainstorm.list.*;
    % Get current electrodes
    sElectrodes = GetElectrodes();
    % Get panel controls
    ctrl = bst_get('PanelControls', 'iEEG');
    if isempty(ctrl)
        return;
    end
    % Remove temporarily the list callback
    callbackBak = java_getcb(ctrl.jListElec, 'ValueChangedCallback');
    java_setcb(ctrl.jListElec, 'ValueChangedCallback', []);
    % Get selected electrodes
    iSelElec = ctrl.jListElec.getSelectedIndex() + 1;
    SelName = char(ctrl.jListElec.getSelectedValue());
    if (iSelElec == 0) || (iSelElec > length(sElectrodes)) || ~strcmpi(sElectrodes(iSelElec).Name, SelName)
        SelName = [];
    end
    % Create a new empty list
    listModel = java_create('javax.swing.DefaultListModel');
    % Get font with which the list is rendered
    fontSize = round(11 * bst_get('InterfaceScaling') / 100);
    jFont = java.awt.Font('Dialog', java.awt.Font.PLAIN, fontSize);
    tk = java.awt.Toolkit.getDefaultToolkit();
    % Add an item in list for each electrode
    Wmax = 0;
    iSelElecNew = [];
    for i = 1:length(sElectrodes)
        % itemType  = num2str(sElectrodes(i).ContactNumber);
        itemType  = '';
        if sElectrodes(i).Visible
            itemText  = sElectrodes(i).Name;
            itemColor = sElectrodes(i).Color;
        else
            itemText  = ['<HTML><FONT color="#a0a0a0">' sElectrodes(i).Name '</FONT>'];
            itemColor = [.63 .63 .63];
        end
        listModel.addElement(BstListItem(itemType, [], itemText, i, itemColor(1), itemColor(2), itemColor(3)));
        % Get longest string
        W = tk.getFontMetrics(jFont).stringWidth(sElectrodes(i).Name);
        if (W > Wmax)
            Wmax = W;
        end
        % Check if selected
        if ~isempty(SelName) && strcmpi(sElectrodes(i).Name, SelName)
            iSelElecNew = i;
        end
    end
    % Update list model
    ctrl.jListElec.setModel(listModel);
    % Update cell rederer based on longest channel name
    ctrl.jListElec.setCellRenderer(java_create('org.brainstorm.list.BstClusterListRenderer', 'II', fontSize, Wmax + 28));
    % Select previously selected electrodes
    if ~isempty(iSelElecNew)
        ctrl.jListElec.setSelectedIndex(iSelElecNew - 1);
    end
    % Update electrode properties
    UpdateElecProperties(0);
    % Restore callback
    drawnow;
    java_setcb(ctrl.jListElec, 'ValueChangedCallback', callbackBak);
end

%% ===== UPDATE CONTACT LIST =====
function UpdateContactList(varargin)
    import org.brainstorm.list.*;
    global GlobalData
    % Get panel controls
    ctrl = bst_get('PanelControls', 'iEEG');
    if isempty(ctrl)
        return;
    end
    % Get coordinate space from ctrls
    if nargin < 1 || isempty(varargin{1})
        CoordSpace = 'scs';
        if ctrl.jRadioMni.isSelected()
            CoordSpace = 'mni';
        elseif ctrl.jRadioMri.isSelected()
            CoordSpace = 'mri';
        elseif ctrl.jRadioWorld.isSelected()
            CoordSpace = 'world';
        end
    else
        CoordSpace = varargin{1};
    end

    % Get selected electrodes
    [sSelElec, ~, iDS] = GetSelectedElectrodes();
    if isempty(sSelElec)
        SelName = [];
        sSelContacts = [];
    else
        SelName = sSelElec(end).Name;
        % Get selected contacts
        sSelContacts = GetSelectedContacts();
    end

    % Create a new empty list
    listModel = java_create('javax.swing.DefaultListModel');
    % Get font with which the list is rendered
    fontSize = round(11 * bst_get('InterfaceScaling') / 100);
    jFont = java.awt.Font('Dialog', java.awt.Font.PLAIN, fontSize);
    tk = java.awt.Toolkit.getDefaultToolkit();
    % Add an item in list for each electrode
    Wmax = 0;

    % Get the contacts for selected electrodes
    sContacts = GetContacts(SelName);
    if isempty(sContacts)
        ctrl.jListCont.setModel(listModel);
        return;
    end
    % Convert contact coodinates
    if ~strcmpi('scs', CoordSpace)
        listModel.addElement(BstListItem('', [], 'Updating', 1));
        ctrl.jListCont.setModel(listModel);
        sSubject = bst_get('Subject', GlobalData.DataSet(iDS(1)).SubjectFile);
        MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
        sMri = bst_memory('LoadMri', MriFile);
        contacLocsMm = cs_convert(sMri, 'scs', lower(CoordSpace), [sContacts.Loc]') * 1000;
        switch lower(CoordSpace)
            case 'mni',   ctrl.jRadioMni.setSelected(1);
            case 'mri',   ctrl.jRadioMri.setSelected(1);
            case 'world', ctrl.jRadioWorld.setSelected(1);
        end
        listModel.clear();
        ctrl.jListCont.setModel(listModel);
    else
        contacLocsMm = [sContacts.Loc]' * 1000;
        ctrl.jRadioScs.setSelected(1);
    end
    % Udpate list content
    if isempty(contacLocsMm)
        % Requested coordinates system is not available
        itemText = 'Not available';
        listModel.addElement(BstListItem('', [], itemText, 1));
        Wmax = tk.getFontMetrics(jFont).stringWidth(itemText);
    else
        for i = 1:length(sContacts)
            itemText = sprintf('%s   %3.2f   %3.2f   %3.2f', sContacts(i).Name, contacLocsMm(i,:));
            listModel.addElement(BstListItem('', [], itemText, i));
            % Get longest string
            W = tk.getFontMetrics(jFont).stringWidth(itemText);
            if (W > Wmax)
                Wmax = W;
            end
        end
    end

    ctrl.jListCont.setModel(listModel);
    % Update cell rederer based on longest channel name
    ctrl.jListCont.setCellRenderer(java_create('org.brainstorm.list.BstClusterListRenderer', 'II', fontSize, Wmax + 28));
    ctrl.jListCont.repaint();
    drawnow;
    % Seletect previously selected contacts
    if ~isempty(sSelContacts)
        SetSelectedContacts({sSelContacts.Name});
    end
end

%% ===== UPDATE MODEL LIST =====
function UpdateModelList(elecType)
    import org.brainstorm.list.*;
    % Get panel controls
    ctrl = bst_get('PanelControls', 'iEEG');
    if isempty(ctrl)
        return;
    end
    % Get the available electrode models
    sModels = GetElectrodeModels();
    % Show only the models from the selected modality
    if ~isempty(elecType)
        switch (elecType)
            case 'SEEG'
                iMod = find(strcmpi({sModels.Type}, 'SEEG'));
            case {'ECOG', 'ECOG-mid'}
                iMod = find(strcmpi({sModels.Type}, 'ECOG'));
        end
        sModels = sModels(iMod);
    end
    % Sort names alphabetically
    elecModels = sort({sModels.Model});
    % Save combobox callback
    jModel = ctrl.jComboModel.getModel();
    bakCallback = java_getcb(jModel, 'ContentsChangedCallback');
    java_setcb(jModel, 'ContentsChangedCallback', []);
    % Empty the ComboBox
    ctrl.jComboModel.removeAllItems();
    % Add all entries in the combo box
    ctrl.jComboModel.addItem(BstListItem('', '', '', 0));
    for i = 1:length(elecModels)
        ctrl.jComboModel.addItem(BstListItem('', '', elecModels{i}, i));
    end
    % Restore callback
    java_setcb(jModel, 'ContentsChangedCallback', bakCallback);
end


%% ===== UPDATE ELECTRODE PROPERTIES =====
function UpdateElecProperties(isUpdateModelList)
    % Parse inputs
    if (nargin < 1) || isempty(isUpdateModelList)
        isUpdateModelList = 1;
    end
    % Get panel controls
    ctrl = bst_get('PanelControls', 'iEEG');
    if isempty(ctrl)
        return;
    end
    % Get selected electrodes
    [sSelElec, iSelElec] = GetSelectedElectrodes();
    % Enable panel if something is selected
    gui_enable(ctrl.jPanelElecOptions, ~isempty(sSelElec));
    
    % Select ECOG/SEEG
    if (length(sSelElec) == 1) || ((length(sSelElec) > 1) && all(cellfun(@(c)isequal(c,sSelElec(1).Type), {sSelElec.Type})))
        if strcmpi(sSelElec(1).Type, 'SEEG')
            ctrl.jRadioSeeg.setSelected(1);
            elecType = 'SEEG';
        elseif strcmpi(sSelElec(1).Type, 'ECOG')
            ctrl.jRadioEcog.setSelected(1);
            elecType = 'ECOG';
        elseif strcmpi(sSelElec(1).Type, 'ECOG-mid')
            ctrl.jRadioEcogMid.setSelected(1);
            elecType = 'ECOG-mid';
        else
            elecType = [];
        end
    else
        ctrl.jRadioSeeg.setSelected(0);
        ctrl.jRadioEcog.setSelected(0);
        ctrl.jRadioEcogMid.setSelected(0);
        elecType = [];
    end
    % Update list of models
    if isUpdateModelList
        % Update list of electrode models
        UpdateModelList(elecType);
        % Select electrode model
        if (length(sSelElec) == 1) || ((length(sSelElec) > 1) && all(cellfun(@(c)isequal(c,sSelElec(1).Model), {sSelElec.Model})))
            SetSelectedModel(sSelElec(1).Model);
        else
            SetSelectedModel([]);
        end
    end
    
    % Update control labels
    if ~isempty(sSelElec) && strcmpi(sSelElec(1).Type, 'SEEG')
        ctrl.jLabelContactLength.setText('Contact length: ');
        ctrl.jLabelElecLength.setVisible(1);
        ctrl.jTextElecLength.setVisible(1);
        ctrl.jLabelElecLengthUnits.setVisible(1);
        ctrl.jLabelElecDiameter.setText('Electrode diameter: ');
        ctrl.jLabelElecDiamUnits.setText(' mm');
    else
        ctrl.jLabelContactLength.setText('Contact height: ');
        ctrl.jLabelElecLength.setVisible(0);
        ctrl.jTextElecLength.setVisible(0);
        ctrl.jLabelElecLengthUnits.setVisible(0);
        ctrl.jLabelElecDiameter.setText('Wire width: ');
        ctrl.jLabelElecDiamUnits.setText(' points');
    end
    % Number of contacts
    if (length(sSelElec) == 1) || ((length(sSelElec) > 1) && all(cellfun(@(c)isequal(c,sSelElec(1).ContactNumber), {sSelElec.ContactNumber})))
        valContacts = sSelElec(1).ContactNumber;
    else
        valContacts = [];
    end
    % Contact spacing
    if (length(sSelElec) == 1) || ((length(sSelElec) > 1) && all(cellfun(@(c)isequal(c,sSelElec(1).ContactSpacing), {sSelElec.ContactSpacing})))
        valSpacing = sSelElec(1).ContactSpacing * 1000;
    else
        valSpacing = [];
    end
    % Contact length
    if (length(sSelElec) == 1) || ((length(sSelElec) > 1) && all(cellfun(@(c)isequal(c,sSelElec(1).ContactLength), {sSelElec.ContactLength})))
        valContactLength = sSelElec(1).ContactLength * 1000;
    else
        valContactLength = [];
    end
    % Contact diameter
    if (length(sSelElec) == 1) || ((length(sSelElec) > 1) && all(cellfun(@(c)isequal(c,sSelElec(1).ContactDiameter), {sSelElec.ContactDiameter})))
        valContactDiam = sSelElec(1).ContactDiameter * 1000;
    else
        valContactDiam = [];
    end
    % Electrode diameter
    if (length(sSelElec) == 1) || ((length(sSelElec) > 1) && all(cellfun(@(c)isequal(c,sSelElec(1).ElecDiameter), {sSelElec.ElecDiameter})))
        valElecDiameter = sSelElec(1).ElecDiameter * 1000;
    else
        valElecDiameter = [];
    end
    % Electrode length
    if (length(sSelElec) == 1) || ((length(sSelElec) > 1) && all(cellfun(@(c)isequal(c,sSelElec(1).ElecLength), {sSelElec.ElecLength})))
        valElecLength = sSelElec(1).ElecLength * 1000;
    else
        valElecLength = [];
    end
    % Update panel
    gui_validate_text(ctrl.jTextNcontacts,     [], [], {1,1024,1}, 'list',     0, valContacts,      @(h,ev)ValidateOptions('ContactNumber', ctrl.jTextNcontacts));
    gui_validate_text(ctrl.jTextSpacing,       [], [], {0,100,100}, 'optional', 2, valSpacing,       @(h,ev)ValidateOptions('ContactSpacing', ctrl.jTextSpacing));
    gui_validate_text(ctrl.jTextContactLength, [], [], {0,30,100},  'optional', 2, valContactLength, @(h,ev)ValidateOptions('ContactLength', ctrl.jTextContactLength));
    gui_validate_text(ctrl.jTextContactDiam,   [], [], {0,20,100},  'optional', 2, valContactDiam,   @(h,ev)ValidateOptions('ContactDiameter', ctrl.jTextContactDiam));
    gui_validate_text(ctrl.jTextElecDiameter,  [], [], {0,20,100},  'optional', 2, valElecDiameter,  @(h,ev)ValidateOptions('ElecDiameter', ctrl.jTextElecDiameter));
    gui_validate_text(ctrl.jTextElecLength,    [], [], {0,200,100}, 'optional', 2, valElecLength,    @(h,ev)ValidateOptions('ElecLength', ctrl.jTextElecLength));
    % Update button list
    if (length(sSelElec) == 1)
        colorOn  = java.awt.Color(0, 0.8, 0);
        colorOff = java.awt.Color(0, 0, 0);
        colorNone= java.awt.Color(.4, .4, .4);
        if strcmpi(sSelElec(1).Type, 'SEEG')
            ctrl.jCardLayout.show(ctrl.jPanelButtons, 'seeg');
            if (size(sSelElec.Loc,2) >= 1)
                ctrl.jButtonSeegSet1.setForeground(colorOn);
            else
                ctrl.jButtonSeegSet1.setForeground(colorOff);
            end
            if (size(sSelElec.Loc,2) >= 2)
                ctrl.jButtonSeegSet2.setForeground(colorOn);
            else
                ctrl.jButtonSeegSet2.setForeground(colorOff);
            end
        else
            ctrl.jCardLayout.show(ctrl.jPanelButtons, 'ecog');
            if (size(sSelElec.Loc,2) >= 1)
                ctrl.jButtonEcogSet1.setForeground(colorOn);
            else
                ctrl.jButtonEcogSet1.setForeground(colorOff);
            end
            if (size(sSelElec.Loc,2) >= 2)
                ctrl.jButtonEcogSet2.setForeground(colorOn);
            else
                ctrl.jButtonEcogSet2.setForeground(colorOff);
            end
            if (length(valContacts) >= 2)
                ctrl.jButtonEcogSet3.setEnabled(1);
                ctrl.jButtonEcogSet4.setEnabled(1);
                if (size(sSelElec.Loc,2) >= 3)
                    ctrl.jButtonEcogSet3.setForeground(colorOn);
                else
                    ctrl.jButtonEcogSet3.setForeground(colorOff);
                end
                if (size(sSelElec.Loc,2) >= 4)
                    ctrl.jButtonEcogSet4.setForeground(colorOn);
                else
                    ctrl.jButtonEcogSet4.setForeground(colorOff);
                end
            else
                ctrl.jButtonEcogSet3.setEnabled(0);
                ctrl.jButtonEcogSet4.setEnabled(0);
                ctrl.jButtonEcogSet3.setForeground(colorNone);
                ctrl.jButtonEcogSet4.setForeground(colorNone);
            end
        end
    else
        ctrl.jCardLayout.show(ctrl.jPanelButtons, 'none');
    end
    % Select show button
    isSelected = ~isempty(sSelElec) && all([sSelElec.Visible] == 1);
    ctrl.jButtonShow.setSelected(isSelected);
    % Save selected electrodes
    ctrl.jLabelSelectElec.setText(num2str(iSelElec));
end

%% ===== SET CROSSHAIR POSITION ON MRI =====
function SetMriCrosshair(sSelContacts) %#ok<DEFNU>
    % Get the handles
    hFig = bst_figures('GetFiguresByType', {'MriViewer'});
    if isempty(hFig) || isempty(sSelContacts)
        return
    end
    % Update the cross-hair position on the MRI
    figure_mri('SetLocation', 'scs', hFig, [], [sSelContacts(end).Loc]);
end

%% ===== GET SELECTED ELECTRODES =====
function [sSelElec, iSelElec, iDS, iFig, hFig] = GetSelectedElectrodes()
    sSelElec = repmat(db_template('intraelectrode'), 0);
    iSelElec = [];
    iDS = [];
    iFig = [];
    hFig = [];
    % Get panel handles
    ctrl = bst_get('PanelControls', 'iEEG');
    if isempty(ctrl)
        return;
    end
    % Get all electrodes
    [sElectrodes, iDS, iFig, hFig] = GetElectrodes();
    if isempty(sElectrodes)
        return
    end
    % Get JList selected indices
    iSelElec = uint16(ctrl.jListElec.getSelectedIndices())' + 1;
    sSelElec = sElectrodes(iSelElec);
end

%% ===== GET SELECTED CONTACTS =====
function sSelContacts = GetSelectedContacts()
    sSelContacts = repmat(db_template('intracontact'), 0);
    % Get panel handles
    ctrl = bst_get('PanelControls', 'iEEG');
    if isempty(ctrl)
        return;
    end
    % Get all contacts
    sSelElec  = GetSelectedElectrodes();
    sContacts = GetContacts(sSelElec(end).Name);
    if isempty(sContacts)
        return
    end
    % Get JList selected indices
    iSelCont = uint16(ctrl.jListCont.getSelectedIndices())' + 1;
    sSelContacts = sContacts(iSelCont);
end


%% ===== SET SELECTED ELECTRODES =====
% USAGE:  SetSelectedElectrodes(iSelElec)      % array of indices
%         SetSelectedElectrodes(SelElecNames)  % cell array of names
function SetSelectedElectrodes(iSelElec)
    % === GET ELECTRODE INDICES ===
    % Get figure controls
    ctrl = bst_get('PanelControls', 'iEEG');
    if isempty(ctrl) || isempty(ctrl.jListElec)
        return
    end
    % No selection
    if isempty(iSelElec) || (isnumeric(iSelElec) && any(iSelElec == 0))
        iSelItem = -1;
    % Select by name
    elseif iscell(iSelElec) || ischar(iSelElec)
        % Get list of electrode names
        if iscell(iSelElec)
            SelElecNames = iSelElec;
        else
            SelElecNames = {iSelElec};
        end
        % Find the requested channels in the JList
        listModel = ctrl.jListElec.getModel();
        iSelItem = [];
        for i = 1:listModel.getSize()
            if ismember(char(listModel.getElementAt(i-1)), SelElecNames)
                iSelItem(end+1) = i - 1;
            end
        end
        if isempty(iSelItem)
            iSelItem = -1;
        end
    % Find the selected electrode in the JList
    else
        iSelItem = iSelElec - 1;
    end
    % === CHECK FOR MODIFICATIONS ===
    % Get previous selection
    iPrevItems = ctrl.jListElec.getSelectedIndices();
    % If selection did not change: exit
    if isequal(iPrevItems, iSelItem) || (isempty(iPrevItems) && isequal(iSelItem, -1))
        return
    end
    % === UPDATE SELECTION ===
    % Temporality disables JList selection callback
    jListCallback_bak = java_getcb(ctrl.jListElec, 'ValueChangedCallback');
    java_setcb(ctrl.jListElec, 'ValueChangedCallback', []);
    % Select items in JList
    ctrl.jListElec.setSelectedIndices(iSelItem);
    % Scroll to see the last selected electrode in the list
    if (length(iSelItem) >= 1) && ~isequal(iSelItem, -1)
        selRect = ctrl.jListElec.getCellBounds(iSelItem(end), iSelItem(end));
        ctrl.jListElec.scrollRectToVisible(selRect);
        ctrl.jListElec.repaint();
    end
    % Restore JList callback
    java_setcb(ctrl.jListElec, 'ValueChangedCallback', jListCallback_bak);
    % Update panel fields
    UpdateElecProperties();
    UpdateContactList();
end

%% ===== SET SELECTED CONTACT =====
% USAGE:  SetSelectedContacts(iSelElec)      % array index
%         SetSelectedContacts(SelElecNames)  % cell array of name
% Limitation: perform operation on one contact not multiple
function SetSelectedContacts(iSelCont)
    % === GET CONTACT INDICES ===
    % Get figure controls
    ctrl = bst_get('PanelControls', 'iEEG');
    if isempty(ctrl) || isempty(ctrl.jListCont)
        return
    end
    % No selection
    if isempty(iSelCont) || (isnumeric(iSelCont) && any(iSelCont == 0))
        iSelItem = -1;
    % Select by name
    elseif iscell(iSelCont) || ischar(iSelCont)
        % Get list of electrode names
        if iscell(iSelCont)
            SelContNames = iSelCont;
        else
            SelContNames = {iSelCont};
        end
        % Find the requested channels in the JList
        listModel = ctrl.jListCont.getModel();
        iSelItem = [];
        for i = 1:listModel.getSize()
            itemNameParts = str_split(char(listModel.getElementAt(i-1)), ' ');
            if ismember(itemNameParts{1}, SelContNames)
                iSelItem(end+1) = i - 1;
            end
        end
        if isempty(iSelItem)
            iSelItem = -1;
        end
    % Find the selected electrode in the JList
    else
        iSelItem = iSelCont - 1;
    end
    % === CHECK FOR MODIFICATIONS ===
    % Get previous selection
    iPrevItems = ctrl.jListCont.getSelectedIndices();
    % If selection did not change: exit
    if isequal(iPrevItems, iSelItem) || (isempty(iPrevItems) && isequal(iSelItem, -1))
        return
    end

    % === UPDATE SELECTION ===
    % Select items in JList
    ctrl.jListCont.setSelectedIndices(iSelItem);
    % Scroll to see the last selected electrode in the list
    if (length(iSelItem) >= 1) && ~isequal(iSelItem, -1)
        selRect = ctrl.jListCont.getCellBounds(iSelItem(end), iSelItem(end));
        ctrl.jListCont.scrollRectToVisible(selRect);
        ctrl.jListCont.repaint();
    end
    sContacts = GetSelectedContacts();
    SetMriCrosshair(sContacts);
end

%% ===== SHOW CONTACTS MENU =====
function ShowContactsMenu(jButton)
    import org.brainstorm.icon.*;
    % Create popup menu
    jMenu = java_create('javax.swing.JPopupMenu');
    % Get selected electrode
    [sSelElec, iSelElec, iDS, iFig] = GetSelectedElectrodes();
    if isempty(iSelElec)
        java_dialog('warning', 'No electrode selected.', 'Align contacts');
        return
    end
    % Menu: Default positions
    gui_component('MenuItem', jMenu, [], 'Use default positions', IconLoader.ICON_SEEG_DEPTH, [], @(h,ev)bst_call(@AlignContacts, iDS, iFig, 'default'));
    % Menu: Export select atlas
    if strcmpi(sSelElec(1).Type, 'ECOG')
        gui_component('MenuItem', jMenu, [], 'Project on inner skull', IconLoader.ICON_SEEG_DEPTH, [], @(h,ev)bst_call(@ProjectContacts, iDS(1), iFig(1), 'innerskull'));
        gui_component('MenuItem', jMenu, [], 'Project on cortex',      IconLoader.ICON_SEEG_DEPTH, [], @(h,ev)bst_call(@ProjectContacts, iDS(1), iFig(1), 'cortexmask'));
    elseif strcmpi(sSelElec(1).Type, 'SEEG')
        gui_component('MenuItem', jMenu, [], 'Project on electrode', IconLoader.ICON_SEEG_DEPTH, [], @(h,ev)bst_call(@AlignContacts, iDS, iFig, 'project'));
        gui_component('MenuItem', jMenu, [], 'Show/Hide line fit through contacts', IconLoader.ICON_SEEG_DEPTH, [], @(h,ev)bst_call(@AlignContacts, iDS, iFig, 'lineFit'));
    end
    % Menu: Save modifications
    jMenu.addSeparator();
    gui_component('MenuItem', jMenu, [], 'Save modifications', IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@bst_memory, 'SaveChannelFile', iDS(1)));
    % Menu: Export positions
    jMenu.addSeparator();
    gui_component('MenuItem', jMenu, [], 'Export contacts positions', IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@ExportChannelFile, 0));
    gui_component('MenuItem', jMenu, [], 'Compute atlas labels', IconLoader.ICON_VOLATLAS, [], @(h,ev)bst_call(@ExportChannelFile, 1));
    % Show popup menu
    gui_brainstorm('ShowPopup', jMenu, jButton);
end



%% ===== GET COLOR TABLE =====
function ColorTable = GetElectrodeColorTable()
    ColorTable = [0    .8    0   ;
                  1    0     0   ; 
                  .4   .4    1   ;
                  1    .694  .392;
                  0    1     1   ;
                  1    0     1   ;
                  .4   0     0   ; 
                  0    .4    0   ;
                  1    .843  0   ];
end


%% ===== EDIT ELECTRODE LABEL =====
% Rename one selected electrode
function EditElectrodeLabel(varargin)
    global GlobalData;
    % Get selected electrodes
    [sSelElec, iSelElec, iDS, iFig] = GetSelectedElectrodes();
    % Get all electrodes
    sAllElec = GetElectrodes();
    % Warning message if no electrode selected
    if isempty(sAllElec)
        java_dialog('warning', 'No electrodes selected.', 'Rename selected electrodes');
        return;
    % If more than one electrode selected: keep only the first one
    elseif (length(sSelElec) > 1)
        iSelElec = iSelElec(1);
        sSelElec = sSelElec(1);
        SetSelectedElectrodes(iSelElec);
    end
    % Ask user for a new label
    newLabel = java_dialog('input', sprintf('Enter a new label for electrode "%s":', sSelElec.Name), ...
                             'Rename selected electrode', [], sSelElec.Name);
    if isempty(newLabel) || strcmpi(newLabel, sSelElec.Name)
        return
    end
    % Check if if already exists
    if any(strcmpi({sAllElec.Name}, newLabel))
        java_dialog('warning', ['Electrode "' newLabel '" already exists.'], 'Rename selected electrode');
        return;
    % Check that name do not include a digit
    elseif any(ismember(newLabel, '0123456789:;*=?!<>"`&%$()[]{}/\_@ ·¡‡¿‚¬‰ƒ„√Â≈Ê∆Á«È…Ë»Í ÎÀÌÕÏÃÓŒÔœÒ—Û”Ú“Ù‘ˆ÷ı’¯ÿúåﬂ˙⁄˘Ÿ˚€¸‹'))
        java_dialog('warning', 'New electrode name should not include digits, spaces or special characters.', 'Rename selected electrode');
        return;
    end
    % Update electrode definition
    oldLabel = sSelElec.Name;
    sSelElec.Name = newLabel;
    % Save modifications
    SetElectrodes(iSelElec, sSelElec);
    % Update JList
    UpdateElecList();
    % Select again electrode
    SetSelectedElectrodes(iSelElec);
    
    % Get the channel names to update
    iDSchan = iDS(1);
    iChan = find(strcmp({GlobalData.DataSet(iDSchan).Channel.Group}, oldLabel));
    % Rename all the corresponding data channels
    for i = 1:length(iChan)
        % Check that the channel has really the old name in its label
        chName = GlobalData.DataSet(iDSchan).Channel(iChan(i)).Name;
        if (length(chName) <= length(oldLabel)) || ~strcmp(chName(1:length(oldLabel)), oldLabel)
            disp(['BST> Channel "' chName '" does not match the name of the group "' oldLabel '": Not reaming to "' newName '"...']);
            continue;
        end
        % Check that new channel name does not exist yet
        newName = [newLabel, chName(length(oldLabel)+1:end)];
        if any(strcmpi(newName, {GlobalData.DataSet(iDSchan).Channel.Name}))
            disp(['BST> Channel "' chName '" cannot be renamed: a channel named "' newName '" already exists.']);
            continue;
        end
        % Update channel group
        GlobalData.DataSet(iDSchan).Channel(iChan(i)).Group = newLabel;
        % Update channel name
        GlobalData.DataSet(iDSchan).Channel(iChan(i)).Name = newName;
    end
    % Update figures
    UpdateFigures();
end


%% ===== EDIT ELECTRODE COLOR =====
function EditElectrodeColor(newColor)
    % Get selected electrode
    [sSelElec, iSelElec] = GetSelectedElectrodes();
    if isempty(iSelElec)
        java_dialog('warning', 'No electrode selected.', 'Edit electrode color');
        return
    end
    % If color is not specified in argument : ask it to user
    if (nargin < 1)
        % Use previous electrode color
        % newColor = uisetcolor(sSelElec(1).Color, 'Select electrode color');
        newColor = java_dialog('color');
        % If no color was selected: exit
        if (length(newColor) ~= 3) || all(sSelElec(1).Color == newColor)
            return
        end
    end
    % Update electrode color
    for i = 1:length(sSelElec)
        sSelElec(i).Color = newColor;
    end
    % Save electrodes
    SetElectrodes(iSelElec, sSelElec);
    % Update electrodes list
    UpdateElecList();
    % Select again electrode
    SetSelectedElectrodes(iSelElec);
    % Update figures
    UpdateFigures();
end


%% ===== VALIDATE OPTIONS =====
function ValidateOptions(optName, jControl)
    global GlobalData;
    % Get figure controls
    ctrl = bst_get('PanelControls', 'iEEG');
    if isempty(ctrl) || isempty(ctrl.jListElec)
        return
    end
    % Get all electrodes
    [sElectrodes, iDSall, iFigall] = GetElectrodes();
    if isempty(sElectrodes)
        return
    end
    % Get the previously selected electrodes (otherwise it updates the newly selected electrode)
    iSelElec = str2num(ctrl.jLabelSelectElec.getText());
    if isempty(iSelElec)
        return;
    end
    sSelElec = sElectrodes(iSelElec);
    isModified = 0;
    isChannelModified = 0;
    % Get new value
    if strcmpi(optName, 'Type')
        val = char(jControl.getText());
        
    elseif strcmpi(optName, 'ContactNumber')
        val = round(str2num(jControl.getText()));
        % SEEG electrode can have only one dimension, others two dimensions max
        if (length(val) >= 2) && strcmpi(sElectrodes(iSelElec).Type, 'SEEG')
            val = val(1);
            jControl.setText(sprintf('%d', val));
        elseif (length(val) >= 3)
            val = val(1:2);
            jControl.setText(sprintf('%d ', val));
        end
    else
        val = str2num(jControl.getText()) / 1000;
    end
    % If setting multiple contacts: do not accept [] as a valid entry
    if isempty(val) && (length(sSelElec) > 1)
        return;
    end
    % Update field for all the selected electrodes
    for iElec = 1:length(sSelElec)
        if ~isequal(sSelElec(iElec).(optName), val)
            % Update electrode definition
            sSelElec(iElec).(optName) = val;
            isModified = 1;
            % If changing electrode type: update all channel types
            if strcmpi(optName, 'Type')
                % Loop on datasets
                for iDS = unique(iDSall)
                    % Get contacts for this electrode
                    iChan = find(strcmpi({GlobalData.DataSet(iDS).Channel.Group}, sSelElec(iElec).Name));
                    if isempty(iChan)
                        continue;
                    end
                    % Update the channels types
                    switch (val)
                        case 'SEEG'
                            [GlobalData.DataSet(iDS).Channel(iChan).Type] = deal('SEEG');
                        case {'ECOG', 'ECOG-mid'}
                            [GlobalData.DataSet(iDS).Channel(iChan).Type] = deal('ECOG');
                    end
                end
                isChannelModified = 1;
            end
        end
    end
    % Save electrodes
    if isModified
        SetElectrodes(iSelElec, sSelElec);
        % Update iEEG panel if needed
        if ismember(optName, {'Type', 'ContactNumber'})
            UpdateElecProperties(1);
        end
        % Mark channel file as modified (only the first one)
        if isChannelModified
            GlobalData.DataSet(iDSall(1)).isChannelModified = 1;
        end
        % Update figures
        UpdateFigures();
        % Update figure modalities
        for i = 1:length(iDSall)
            UpdateFigureModality(iDSall(i), iFigall(i));
        end
    end
end
    

%% ===== SHOW/HIDE ELECTRODE =====
function SetElectrodeVisible(isVisible)
    % Get selected electrode
    [sSelElec, iSelElec] = GetSelectedElectrodes();
    if isempty(iSelElec)
        java_dialog('warning', 'No electrode selected.', 'Show/hide electrode');
        return
    end
    % Update electrode color
    for i = 1:length(sSelElec)
        sSelElec(i).Visible = isVisible;
        % show/hide any line fitting
        hCoord = findobj(0, 'Tag', sSelElec(i).Name); 
        if ~isempty(hCoord)
            if isVisible
                set(hCoord, 'Visible', 'on');
            else
                set(hCoord, 'Visible', 'off');
            end
        end
    end
    % Save electrodes
    SetElectrodes(iSelElec, sSelElec);
    % Update electrodes list
    UpdateElecList();
    % Select again electrode
    SetSelectedElectrodes(iSelElec);
    % Update figures
    UpdateFigures();
end
    

%% ===== GET ELECTRODES =====
function [sElectrodes, iDSall, iFigall, hFigall] = GetElectrodes()
    global GlobalData;
    % Get current figure
    [hFigall,iFigall,iDSall] = bst_figures('GetCurrentFigure');

    % Check if there are electrodes defined for this file
    if isempty(hFigall) || isempty(hFigall(end)) || isempty(GlobalData.DataSet(iDSall(end)).IntraElectrodes) || isempty(GlobalData.DataSet(iDSall(end)).ChannelFile)
        sElectrodes = [];
        return
    end
    % Return all the available electrodes
    sElectrodes = GlobalData.DataSet(iDSall).IntraElectrodes;
    ChannelFile = GlobalData.DataSet(iDSall).ChannelFile;
    % Get all the figures that share this channel file
    for iDS = 1:length(GlobalData.DataSet)
        % Skip if not the correct channel file
        if ~file_compare(GlobalData.DataSet(iDS).ChannelFile, ChannelFile)
            continue;
        end
        % Get all the figures
        for iFig = 1:length(GlobalData.DataSet(iDS).Figure)
            if ((iDS ~= iDSall(1)) || (iFig ~= iFigall(1))) && ismember(GlobalData.DataSet(iDS).Figure(iFig).Id.Type, {'MriViewer', '3DViz', 'Topography'})
                iDSall(end+1) = iDS;
                iFigall(end+1) = iFig;
                hFigall(end+1) = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
            end
        end
    end
end

%% ===== GET CONTACTS FOR AN ELECTRODE ===== %%
function sContacts = GetContacts(selectedElecName)
    global GlobalData;

    sContacts = repmat(db_template('intracontact'), 0);
    % Get current figure
    [hFigall,iFigall,iDSall] = bst_figures('GetCurrentFigure');
    % Check if there are electrodes defined for this file
    if isempty(hFigall) || isempty(GlobalData.DataSet(iDSall).IntraElectrodes) || isempty(GlobalData.DataSet(iDSall).ChannelFile) || isempty(selectedElecName)
        return;
    end
    % Get the channel data
    ChannelData = GlobalData.DataSet(iDSall).Channel;
    % Replace empty Group with ''
    [ChannelData(cellfun('isempty', {ChannelData.Group})).Group] = deal('');
    % Get the contacts for the electrode
    iChannels = find(ismember({ChannelData.Group}, selectedElecName));
    for i = 1:length(iChannels)
        sContacts(i).Name = ChannelData(iChannels(i)).Name;
        sContacts(i).Loc  = ChannelData(iChannels(i)).Loc;
    end
end


%% ===== SET ELECTRODES =====
% USAGE:  iElec = SetElectrodes(iElec=[], sElect)
%         iElec = SetElectrodes('Add', sElect)
function iElec = SetElectrodes(iElec, sElect)
    global GlobalData;
    % Parse input
    isAdd = ~isempty(iElec) && ischar(iElec) && strcmpi(iElec, 'Add');
    % Get dataset
    [sElecOld, iDSall] = GetElectrodes();
    % If there is no selected dataset
    if isempty(iDSall)
        bst_error('Make sure the MRI Viewer is open with the CT loaded', 'Add Electrode', 0);
        return;
    end
    % Perform operations only once per dataset
    iDSall = unique(iDSall);
    for iDS = iDSall
        % Replace all the electrodes
        if isempty(iElec) || isempty(GlobalData.DataSet(iDS).IntraElectrodes)
            GlobalData.DataSet(iDS).IntraElectrodes = sElect;
            iElec = 1:length(sElect);
        % Set specific electrodes
        else
            % Add new electrode
            if isAdd
                iElec = length(GlobalData.DataSet(iDS).IntraElectrodes) + (1:length(sElect));
                % Make new electrode names unique
                if ~isempty(GlobalData.DataSet(iDS).IntraElectrodes)
                    for i = 1:length(sElect)
                        sElect(i).Name = file_unique(sElect(i).Name, {GlobalData.DataSet(iDS).IntraElectrodes.Name, sElect(1:i-1).Name});
                    end
                end
            end
            % Set electrode in global structure
            if isempty(sElect)
                GlobalData.DataSet(iDS).IntraElectrodes(iElec) = [];
            else
                GlobalData.DataSet(iDS).IntraElectrodes(iElec) = sElect;
            end
        end
        % Add color if not defined yet
        for i = 1:length(GlobalData.DataSet(iDS).IntraElectrodes)
            if isempty(GlobalData.DataSet(iDS).IntraElectrodes(i).Color)
                ColorTable = GetElectrodeColorTable();
                iColor = mod(i-1, length(ColorTable)) + 1;
                GlobalData.DataSet(iDS).IntraElectrodes(i).Color = ColorTable(iColor,:);
            end
        end
    end
    % Mark channel file as modified (only in first dataset)
    GlobalData.DataSet(iDSall(1)).isChannelModified = 1;
end


%% ===== ADD ELECTRODE =====
function AddElectrode()
    global GlobalData;
    % Get available electrodes
    [sAllElec, iDS, iFig] = GetElectrodes();
    % Get modality
    if ~isempty(iFig) && ~isempty(GlobalData.DataSet(iDS(1)).Figure(iFig(1)).Id.Modality)
        Modality = GlobalData.DataSet(iDS(1)).Figure(iFig(1)).Id.Modality;
    else
        Modality = 'SEEG';
    end
    % Ask user for a new label
    newLabel = java_dialog('input', 'Electrode label:', 'Add electrode', [], '');
    if isempty(newLabel)
        return;
    end
    % Check if label already exists
    if ~isempty(sAllElec) && any(strcmpi({sAllElec.Name}, newLabel))
        java_dialog('warning', ['Electrode "' newLabel '" already exists.'], 'New electrode');
        return;
    % Check if labels include invalid characters
    elseif any(ismember(newLabel, '0123456789:;*=?!<>"`&%$()[]{}/\_@ ·¡‡¿‚¬‰ƒ„√Â≈Ê∆Á«È…Ë»Í ÎÀÌÕÏÃÓŒÔœÒ—Û”Ú“Ù‘ˆ÷ı’¯ÿúåﬂ˙⁄˘Ÿ˚€¸‹'))
        java_dialog('warning', 'New electrode name should not include digits, spaces or special characters.', 'New electrode');
        return;
    end
    % Create new electrode structure
    sElect = db_template('intraelectrode');
    sElect.Name = newLabel;
    switch (Modality)
        case 'SEEG'
            sElect.Type = 'SEEG';
        case 'ECOG'
            sElect.Type = 'ECOG';
        otherwise
            sElect.Type = 'SEEG';
    end
    % Default model: model of the first electrode, or first model in the list
    if ~isempty(sAllElec)
        sModel = sAllElec(end);
    else
        % Get the available electrode models
        sAllModels = GetElectrodeModels();
        % Get the first model in the list
        sModel = sAllModels(1);
    end
    % Copy model to new electrode
    if ~isempty(sModel)
        for f = {'Model', 'ContactNumber', 'ContactSpacing', 'ContactDiameter', 'ContactLength', 'ElecDiameter', 'ElecLength'}
            if ~isempty(sModel.(f{1}))
                sElect.(f{1}) = sModel.(f{1});
            end
        end
    end
    % Add new electrode
    iElec = SetElectrodes('Add', sElect);
    % Update JList
    UpdateElecList();
    % Select again electrode
    SetSelectedElectrodes(iElec);
end

%% ===== REMOVE ELECTRODE =====
function RemoveElectrode()
    global GlobalData;
    % Get dataset
    [sElecOld, iDSall, iFigall] = GetElectrodes();
    if isempty(iDSall)
        return;
    end
    % Check if this is an new implantation folder
    ChannelFile = GlobalData.DataSet(iDSall(1)).ChannelFile;
    [fPath, folderName] = bst_fileparts(bst_fileparts(ChannelFile));
    isImplantation = ~isempty(strfind(folderName, 'Implantation'));
    % Get selected electrode
    [sSelElec, iSelElec] = GetSelectedElectrodes();
    if isempty(iSelElec)
        java_dialog('warning', 'No electrode selected.', 'Remove color');
        return
    end
    % Ask for confirmation
    if (length(sSelElec) == 1)
        strConfirm = ['Delete electrode "' sSelElec.Name '"?'];
    else
        strConfirm = ['Delete ' num2str(length(sSelElec)) ' electrodes?'];
    end
    if ~java_dialog('confirm', strConfirm)
        return;
    end
    % Loop on datasets
    for iDS = unique(iDSall)
        % Loop on electrodes to delete
        for iElec = 1:length(sSelElec)
            % If new implantation scheme: delete all the contacts for this electrode
            if isImplantation
                % Get contacts for this electrode
                iChan = find(strcmpi({GlobalData.DataSet(iDS).Channel.Group}, sSelElec(iElec).Name));
                if isempty(iChan)
                    continue;
                end
                % Loop on figures for this dataset
                for iFig = iFigall(iDSall == iDS)
                    % If incorrect figure type
                    if ~ismember(GlobalData.DataSet(iDS).Figure(iFig).Id.Type, {'MriViewer', '3DViz', 'Topography'})
                        continue;
                    end
                    % Get indices in the figure handles
                    [tmp, iHandles] = intersect(GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels, iChan);
                    % Delete graphic handles
                    if ~isempty(iHandles) && isfield(GlobalData.DataSet(iDS).Figure(iFig).Handles, 'hPointEEG') && (max(iHandles) <= size(GlobalData.DataSet(iDS).Figure(iFig).Handles.hPointEEG,1))
                        delete(GlobalData.DataSet(iDS).Figure(iFig).Handles.hPointEEG(iHandles,:));
                        GlobalData.DataSet(iDS).Figure(iFig).Handles.hPointEEG(iHandles,:) = [];
                    end
                    if ~isempty(iHandles) && isfield(GlobalData.DataSet(iDS).Figure(iFig).Handles, 'hTextEEG') && (max(iHandles) <= size(GlobalData.DataSet(iDS).Figure(iFig).Handles.hTextEEG,1))
                        delete(GlobalData.DataSet(iDS).Figure(iFig).Handles.hTextEEG(iHandles,:));
                        GlobalData.DataSet(iDS).Figure(iFig).Handles.hTextEEG(iHandles,:) = [];
                    end
                    if ~isempty(iHandles) && isfield(GlobalData.DataSet(iDS).Figure(iFig).Handles, 'LocEEG') && (max(iHandles) <= size(GlobalData.DataSet(iDS).Figure(iFig).Handles.LocEEG,1))
                        GlobalData.DataSet(iDS).Figure(iFig).Handles.LocEEG(iHandles,:) = [];
                    end
                    % Delete all previously created objects
                    hFig = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
                    delete(findobj(hFig, 'Tag', 'ElectrodeGrid'));
                    delete(findobj(hFig, 'Tag', 'ElectrodeSelect'));
                    delete(findobj(hFig, 'Tag', 'ElectrodeDepth'));
                    delete(findobj(hFig, 'Tag', 'ElectrodeWire'));
                    delete(findobj(hFig, 'Tag', 'ElectrodeLabel'));
                    % Update list of displayed channels
                    iSelChan = setdiff(GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels, iChan);
                    remChan = {GlobalData.DataSet(iDS).Channel(setdiff(1:length(GlobalData.DataSet(iDS).Channel), iChan)).Name};
                    selChan = {GlobalData.DataSet(iDS).Channel(iSelChan).Name};
                    [tmp, I, J] = intersect(remChan, selChan);
                    GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels = I(:)';
                end
                % Update figure modality
                UpdateFigureModality(iDS, iFig);
                % Remove channels
                GlobalData.DataSet(iDS).Channel(iChan) = [];
            end
        end
        % Delete selected electrodes
        GlobalData.DataSet(iDS).IntraElectrodes(iSelElec) = [];
    end
    % Mark channel file as modified (only the first one)
    GlobalData.DataSet(iDSall(1)).isChannelModified = 1;
    % remove any line fitting
    hCoord = findobj(0, 'Tag', sSelElec.Name); 
    if ~isempty(hCoord)
        delete(hCoord);
    end
    % Update list of electrodes
    UpdateElecList();
    % Update figure
    UpdateFigures();
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
        sTemplate.ElecLength      = 0.100;
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
        
        % === AD TECH MM16 SERIES ===
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

        % === PMT SEEG DEPTHALON ELECTRODES ===
        % Common values
        sTemplate = db_template('intraelectrode');
        sTemplate.Type = 'SEEG';
        sTemplate.ContactDiameter = 0.0008;
        sTemplate.ContactLength   = 0.002;
        sTemplate.ElecDiameter    = 0.0007;
        % All models
        sMod = repmat(sTemplate, 1, 7);
        sMod(1).Model         = 'PMT 2102-08-091/2102-08-101';
        sMod(1).ContactNumber = 8;
        sMod(1).ContactSpacing  = 0.0035;
        sMod(1).ElecLength      = 0.0265;
        sMod(2).Model         = 'PMT 2102-10-091/2102-10-101';
        sMod(2).ContactNumber = 10;
        sMod(2).ContactSpacing  = 0.0035;
        sMod(2).ElecLength      = 0.0335;
        sMod(3).Model         = 'PMT 2102-12-091/2102-12-101';
        sMod(3).ContactNumber = 12;
        sMod(3).ContactSpacing  = 0.0035;
        sMod(3).ElecLength      = 0.0405;
        sMod(4).Model         = 'PMT 2102-14-091/2102-14-101';
        sMod(4).ContactNumber = 14;
        sMod(4).ContactSpacing  = 0.0035;
        sMod(4).ElecLength      = 0.0475;
        sMod(5).Model         = 'PMT 2102-16-091/2102-16-101';
        sMod(5).ContactNumber = 16;
        sMod(5).ContactSpacing  = 0.0035;
        sMod(5).ElecLength      = 0.0545;
        sMod(6).Model         = 'PMT 2102-16-092/2102-16-102';
        sMod(6).ContactNumber = 16;
        sMod(6).ContactSpacing  = 0.00397;
        sMod(6).ElecLength      = 0.0615;
        sMod(7).Model         = 'PMT 2102-16-093/2102-16-103';
        sMod(7).ContactNumber = 16;
        sMod(7).ContactSpacing  = 0.00443;
        sMod(7).ElecLength      = 0.0685;
        sModels = [sModels, sMod];
    end
end


%% ===== GET SELECTED MODEL =====
function [iModel, sModels] = GetSelectedModel()
    % Get figure controls
    ctrl = bst_get('PanelControls', 'iEEG');
    if isempty(ctrl) || isempty(ctrl.jListElec)
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


%% ===== SET SELECTED MODEL =====
function SetSelectedModel(selModel)
    % Get figure controls
    ctrl = bst_get('PanelControls', 'iEEG');
    if isempty(ctrl) || isempty(ctrl.jListElec)
        return
    end
    % Find model list in the combo box
    iModel = 0;
    for i = 1:ctrl.jComboModel.getItemCount()
        if strcmpi(selModel, ctrl.jComboModel.getItemAt(i))
            iModel = i;
            break;
        end
    end
    % Save combobox callback
    jModel = ctrl.jComboModel.getModel();
    bakCallback = java_getcb(jModel, 'ContentsChangedCallback');
    java_setcb(jModel, 'ContentsChangedCallback', []);
    % Select model
    ctrl.jComboModel.setSelectedIndex(iModel);
    % Restore callback
    java_setcb(jModel, 'ContentsChangedCallback', bakCallback);
end

%% ===== ADD ELECTRODE MODEL =====
function AddElectrodeModel(sNewModel)
    global GlobalData;
    % Get figure controls
    ctrl = bst_get('PanelControls', 'iEEG');
    if isempty(ctrl) || isempty(ctrl.jListElec)
        return
    end
    % If sNewModel is not provided, ask the user
    if (nargin < 1) || isempty(sNewModel)
        % === ECOG ===
        if ctrl.jRadioEcog.isSelected() || ctrl.jRadioEcogMid.isSelected()
            % Ask for all the electrode options
            res = java_dialog('input', {...
                'Manufacturer and model (ECOG):', ...
                'Number of contacts:', ...
                'Contact spacing (mm):', ...
                'Contact height (mm):', ...
                'Contact diameter (mm):', ...
                'Wire width (points):'}, 'Add new model', [], ...
                {'', '', '3.5', '0.8', '2', '0.5'});
            if isempty(res) || isempty(res{1})
                return;
            end
            % Get all the values
            sNew = db_template('intraelectrode');
    %         if ctrl.jRadioEcog.isSelected()
    %             sNew.Type = 'ECOG';
    %         elseif ctrl.jRadioEcogMid.isSelected()
    %             sNew.Type = 'ECOG-mid';
    %         end
            sNew.Type            = 'ECOG';
            sNew.Model           = res{1};
            sNew.ContactNumber   = str2num(res{2});
            sNew.ContactSpacing  = str2num(res{3}) ./ 1000;
            sNew.ContactLength   = str2num(res{4}) ./ 1000;
            sNew.ContactDiameter = str2num(res{5}) ./ 1000;
            sNew.ElecDiameter    = str2num(res{6}) ./ 1000;
            sNew.ElecLength      = 0;
        % === SEEG ===
        else
            % Ask for all the electrode options
            res = java_dialog('input', {...
                'Manufacturer and model (SEEG):', ...
                'Number of contacts:', ...
                'Contact spacing (mm):', ...
                'Contact length (mm):', ...
                'Contact diameter (mm):', ...
                'Electrode diameter (mm):', ...
                'Electrode length (mm):'}, 'Add new model', [], ...
                {'', '', '3.5', '2', '0.8', '0.7', '70'});
            if isempty(res) || isempty(res{1})
                return;
            end
            % Get all the values
            sNew = db_template('intraelectrode');
            sNew.Model           = res{1};
            sNew.Type            = 'SEEG';
            sNew.ContactNumber   = str2num(res{2});
            sNew.ContactSpacing  = str2num(res{3}) ./ 1000;
            sNew.ContactLength   = str2num(res{4}) ./ 1000;
            sNew.ContactDiameter = str2num(res{5}) ./ 1000;
            sNew.ElecDiameter    = str2num(res{6}) ./ 1000;
            sNew.ElecLength      = str2num(res{7}) ./ 1000;
        end
    else
        sNew = sNewModel;
    end
    % Get available models
    sModels = GetElectrodeModels();
    % Check that the electrode model is unique
    if any(strcmpi({sModels.Model}, sNew.Model))
        bst_error(['Electrode model "' sNew.Model '" is already defined.'], 'Add new model', 0);
        return;
    % Check that all the values are set
    elseif isempty(sNew.ContactNumber) || isempty(sNew.ContactSpacing) || isempty(sNew.ContactDiameter) || isempty(sNew.ContactLength) || isempty(sNew.ElecDiameter) || isempty(sNew.ElecLength)
        bst_error('Invalid values.', 'Add new model', 0);
        return;
    end
    % Add new electrode
    sModels(end+1) = sNew;
    GlobalData.Preferences.IntraElectrodeModels = sModels;
    % Update list of models
    UpdateElecProperties();
end


%% ===== REMOVE ELECTRODE MODEL =====
function RemoveElectrodeModel()
    global GlobalData;
    % Get panel controls
    ctrl = bst_get('PanelControls', 'iEEG');
    if isempty(ctrl) || isempty(ctrl.jListElec)
        return
    end
    % Get selected model
    [iModel, sModels] = GetSelectedModel();
    if isempty(iModel)            
        return;
    end
    % Ask for confirmation
    if ~java_dialog('confirm', ['Delete model "' sModels(iModel).Model '"?'])
        return;
    end
    % Delete model
    sModels(iModel) = [];
    GlobalData.Preferences.IntraElectrodeModels = sModels;
    % Update list of models
    UpdateElecProperties();
end


%% ===== SAVE ELECTRODE MODEL =====
function SaveElectrodeModel()
    % Get panel controls
    ctrl = bst_get('PanelControls', 'iEEG');
    if isempty(ctrl) || isempty(ctrl.jListElec)
        return
    end
    % Get selected model
    [iModel, sModels] = GetSelectedModel();
    if isempty(iModel)
        return;
    end
    % Build a default file name
    LastUsedDirs = bst_get('LastUsedDirs');
    ModelFile = bst_fullfile(LastUsedDirs.ExportChannel, ['intraelectrode_', file_standardize(sModels(iModel).Model), '.mat']);
    % Get filename where to store the filename
    [ModelFile, FileFormat] = java_getfile('save', 'Save selected electrode model', ModelFile, ...
                             'single', 'files', ...
                             {{'_model'}, 'Brainstorm intracranial electrode model (*intraelectrode*.mat)', 'BST'}, 1);
    if isempty(ModelFile)
        return;
    end
    % Save last used folder
    LastUsedDirs.ExportChannel = bst_fileparts(ModelFile);
    bst_set('LastUsedDirs',  LastUsedDirs);
    % Switch file format
    switch (FileFormat)
        case 'BST'
            % Make sure that filename contains the 'intraelectrode' tag
            if isempty(strfind(ModelFile, '_intraelectrode')) && isempty(strfind(ModelFile, 'intraelectrode_'))
                [filePath, fileBase, fileExt] = bst_fileparts(ModelFile);
                ModelFile = bst_fullfile(filePath, ['intraelectrode_' fileBase fileExt]);
            end
            % Save file
            bst_save(ModelFile, sModels(iModel), 'v7');
    end
end


%% ===== LOAD ELECTRODE MODEL =====
function LoadElectrodeModel()
    % Get panel controls
    ctrl = bst_get('PanelControls', 'iEEG');
    if isempty(ctrl) || isempty(ctrl.jListElec)
        return
    end
    % Get last used folder
    LastUsedDirs = bst_get('LastUsedDirs');
    % Get label files
    [ModelFiles, FileFormat] = java_getfile( 'open', ...
       'Import intracranial electrode models...', ...  % Window title
       LastUsedDirs.ImportChannel, ...                 % Default directory
       'multiple', 'files', ...                        % Selection mode
       {{'_intraelectrode'}, 'Brainstorm intracranial electrode model (*intraelectrode*.mat)', 'BST'}, ...
       'BST');
    % If no file was selected: exit
    if isempty(ModelFiles)
        return
    end
    % Save last used dir
    LastUsedDirs.ImportChannel = bst_fileparts(ModelFiles{1});
    bst_set('LastUsedDirs',  LastUsedDirs);
    for iFile = 1 : length(ModelFiles)
        switch FileFormat
            case 'BST'
                % Load file
                sModel = load(ModelFiles{iFile});
                % Add electrode model
                AddElectrodeModel(sModel);
                fprintf(1, 'Intracranial electrode model "%s" was loaded\n', sModel.Model);
        end
    end
end


%% ===== EXPORT ELECTRODE MODEL =====
function ExportElectrodeModel()
    % Get panel controls
    ctrl = bst_get('PanelControls', 'iEEG');
    if isempty(ctrl) || isempty(ctrl.jListElec)
        return
    end
    % Get selected model
    [iModel, sModels] = GetSelectedModel();
    if isempty(iModel)
        return;
    end
    % Export to the base workspace
    export_matlab(sModels(iModel), []);
end


%% ===== IMPORT ELECTRODE MODEL =====
function ImportElectrodeModel()
    % Import from base workspace
    sModel = in_matlab_var([], 'struct');
    if isempty(sModel)
        return;
    end
    % Check structure
    sTemplate = db_template('intraelectrode');
    if ~isequal(fieldnames(sModel), fieldnames(sTemplate))
        bst_error('Invalid intracranial electrode model structure.', 'Import from Matlab', 0);
        return;
    end
    % Add electrode model
    AddElectrodeModel(sModel);
    fprintf(1, 'Intracranial electrode model "%s" was imported\n', sModel.Model);
end


%% ===== UPDATE FIGURE TYPE =====
function UpdateFigureModality(iDS, iFig)
    global GlobalData;
    % Update figure modalities and title
    if ismember(GlobalData.DataSet(iDS).Figure(iFig).Id.Type, {'MriViewer', '3DViz', 'Topography'})
        Modality = GlobalData.DataSet(iDS).Figure(iFig).Id.Modality;
        % Get channel types in the figure
        SelChan = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels;
        if ~isempty(SelChan)
            AllTypes = unique({GlobalData.DataSet(iDS).Channel(SelChan).Type});
        % If there are not channels (yet), check if there are intracranial electrodes that can define the type
        elseif ~isempty(GlobalData.DataSet(iDS).IntraElectrodes)
            AllTypes = unique({GlobalData.DataSet(iDS).IntraElectrodes.Type});
            if ismember('ECOG-mid', AllTypes)
                AllTypes = union(setdiff(AllTypes, 'ECOG-mid'), {'ECOG'});
            end
        else
            AllTypes = [];
        end
        % If there are possible type condidates
        if ~isempty(AllTypes)
            % If the modality was modified
            if all(ismember({'ECOG','SEEG'}, AllTypes)) && (strcmpi(Modality, 'ECOG') || strcmpi(Modality, 'SEEG'))
                Modality = 'ECOG+SEEG';
            elseif ~ismember('ECOG', AllTypes) && ismember('SEEG', AllTypes) && ismember(Modality, {'ECOG+SEEG','ECOG'})
                Modality = 'SEEG';
            elseif ~ismember('SEEG', AllTypes) && ismember('ECOG', AllTypes) && ismember(Modality, {'ECOG+SEEG','SEEG'})
                Modality = 'ECOG';
            end
            % Update figure
            if ~strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.Modality, Modality)
                GlobalData.DataSet(iDS).Figure(iFig).Id.Modality = Modality;
                bst_figures('UpdateFigureName', GlobalData.DataSet(iDS).Figure(iFig).hFigure);
            end
        end
    end
end


%% ===== UPDATE FIGURES =====
function UpdateFigures(hFigTarget)
    global GlobalData;
    % Parse inputs
    if (nargin < 1) || isempty(hFigTarget)
        hFigTarget = [];
    end
    % Get loaded dataset
    [sElectrodes, iDSall, iFigall, hFigall] = GetElectrodes();
    if isempty(iDSall)
        return;
    end
    % Progress bar
    isProgress = bst_progress('isVisible');
    if ~isProgress
        bst_progress('start', 'iEEG', 'Updating display...');
    end
    % Update all the figures that share this channel file
    for i = 1:length(iDSall)
        iDS = iDSall(i);
        iFig = iFigall(i);
        hFig = hFigall(i);
        Modality = GlobalData.DataSet(iDS).Figure(iFig).Id.Modality;
        % If there is one target figure to update only:
        if ~isempty(hFigTarget) && ~isequal(hFigTarget, hFig)
            continue;
        end
        % Update figure
        switch (GlobalData.DataSet(iDS).Figure(iFig).Id.Type)
            case 'Topography'
                bst_figures('ReloadFigures', hFig, 0);
            case '3DViz'
                hElectrodeObjects = [findobj(hFig, 'Tag', 'ElectrodeGrid'); findobj(hFig, 'Tag', 'ElectrodeDepth'); findobj(hFig, 'Tag', 'ElectrodeWire')];
                if ~isempty(hElectrodeObjects) || ismember(Modality, {'ECOG','SEEG','ECOG+SEEG'})
                    % figure_3d('PlotSensors3D', iDS, iFig);
                    isLabels = isfield(GlobalData.DataSet(iDS).Figure(iFig).Handles, 'hSensorLabels') && ~isempty(GlobalData.DataSet(iDS).Figure(iFig).Handles.hSensorLabels);
                    view_channels(GlobalData.DataSet(iDS).ChannelFile, Modality, 1, isLabels, hFig, 1);
                end
            case 'MriViewer'
                hElectrodeObjects = [findobj(hFig, 'Tag', 'ElectrodeGrid'); findobj(hFig, 'Tag', 'ElectrodeDepth'); findobj(hFig, 'Tag', 'ElectrodeWire')];
                if ~isempty(hElectrodeObjects) || ismember(Modality, {'ECOG','SEEG','ECOG+SEEG'})
                    figure_mri('PlotSensors3D', iDS, iFig);
                    GlobalData.DataSet(iDS).Figure(iFig).Handles = figure_mri('PlotElectrodes', iDS, iFig, GlobalData.DataSet(iDS).Figure(iFig).Handles, 1);
                    figure_mri('UpdateVisibleSensors3D', hFig);
                    figure_mri('UpdateVisibleLandmarks', hFig);
                end
        end
    end
    % Close progress bar
    if ~isProgress
        bst_progress('stop');
    end
end


%% ===== SET DISPLAY MODE =====
function SetDisplayMode(DisplayMode)
    % Get current figure
    hFig = bst_figures('GetCurrentFigure');
    if isempty(hFig)
        return;
    end
    % Update display mode
    getappdata(hFig(1), 'ElectrodeDisplay');
    ElectrodeDisplay.DisplayMode = DisplayMode;
    setappdata(hFig(1), 'ElectrodeDisplay', ElectrodeDisplay);
    % Update figures
    UpdateFigures(hFig(1));
end


%% ===== DETECT ELECTRODES =====
function [ChannelMat, ChanOrient, ChanLocFix] = DetectElectrodes(ChannelMat, Modality, AllInd, isUpdate) %#ok<DEFNU>
    % Parse inputs
    if (nargin < 4) || isempty(isUpdate)
        isUpdate = 0;
    end
    % Get channels for modality
    iMod = good_channel(ChannelMat.Channel, [], Modality);
    if isempty(iMod)
        ChanOrient = [];
        ChanLocFix = [];
        return;
    end
    % Returned variables
    ChanOrient = zeros(length(ChannelMat.Channel),3);
    ChanLocFix = zeros(length(ChannelMat.Channel),3);
    % Contact indices missing, detecting them
    if (nargin < 3) || isempty(AllInd)
        [AllGroups, AllTags, AllInd, isNoInd] = panel_montage('ParseSensorNames', ChannelMat.Channel(iMod));
    end
    % Add IntraElectrodes field if not present
    if ~isfield(ChannelMat, 'IntraElectrodes') || isempty(ChannelMat.IntraElectrodes)
        ChannelMat.IntraElectrodes = repmat(db_template('intraelectrode'), 0);
    end
    % Get color table
    ColorTable = GetElectrodeColorTable();
    % Get all groups
    allGroups = {ChannelMat.Channel(iMod).Group};
    uniqueGroups = unique(allGroups(~cellfun(@isempty, allGroups)));
    for iGroup = 1:length(uniqueGroups)
        % If electrode already exists (or no group)
        if any(strcmpi({ChannelMat.IntraElectrodes.Name}, uniqueGroups{iGroup})) || isempty(uniqueGroups{iGroup})
            % Force updating existing electrode
            if isUpdate
                iNewElec = find(strcmpi({ChannelMat.IntraElectrodes.Name}, uniqueGroups{iGroup}));
                newElec = ChannelMat.IntraElectrodes(iNewElec);
            % Do not modify existing electrodes
            else
                continue;
            end
        % Create new electrode
        else
            iNewElec = length(ChannelMat.IntraElectrodes) + 1;
            % Create electrode structure
            newElec = db_template('intraelectrode');
            newElec.Name          = uniqueGroups{iGroup};
            newElec.Type          = Modality;
            newElec.Model         = '';
            newElec.Visible       = 1;
            % Default display options
            ElectrodeConfig = bst_get('ElectrodeConfig', Modality);
            newElec.ContactDiameter = ElectrodeConfig.ContactDiameter;
            newElec.ContactLength   = ElectrodeConfig.ContactLength;
            newElec.ElecDiameter    = ElectrodeConfig.ElecDiameter;
            newElec.ElecLength      = ElectrodeConfig.ElecLength;
        end
        % Get electrodes in group
        iGroupChan = find(strcmpi({ChannelMat.Channel(iMod).Group}, uniqueGroups{iGroup}));
        % Sort electrodes by index number
        [IndMod, I] = sort(AllInd(iGroupChan));
        iGroupChan = iGroupChan(I);
        % Default color
        iColor = mod(iGroup-1, length(ColorTable)) + 1;
        newElec.Color = ColorTable(iColor,:);
        % Try to get positions of the electrode: 2 contacts minimum with positions
        if strcmpi(Modality, 'SEEG') && (length(iGroupChan) >= 2) && all(cellfun(@(c)and(size(c,2) == 1, ~isequal(c,[0;0;0])), {ChannelMat.Channel(iMod(iGroupChan)).Loc}))
            % Number of contacts: maximum contact index found in the file
            newElec.ContactNumber = max(AllInd(iGroupChan));
            % Get all channels locations for this electrode
            ElecLoc = [ChannelMat.Channel(iMod(iGroupChan)).Loc]';
            % Get distance between available contacts (in number of contacts)
            nDist = diff(AllInd(iGroupChan));
            % Detect average spacing between adjacent contacts (precision: 0.000001)
            newElec.ContactSpacing = mean(sqrt(sum((ElecLoc(1:end-1,:) - ElecLoc(2:end,:)) .^ 2, 2)) ./ nDist(:), 1);
            newElec.ContactSpacing = bst_round(newElec.ContactSpacing, 6);
            
            % Center of the electrodes
            M = mean(ElecLoc);
            % Get the principal orientation between all the vertices
            W = bst_bsxfun(@minus, ElecLoc, M);
            [U,D,V] = svd(W' * W);
            orient = U(:,1)';
            % Orient the direction vector in the correct direction (from the tip to the handle of the strip)
            if (sum(orient .* (M - ElecLoc(1,:))) < 0)
                orient = -orient;
            end
            % Project the electrodes on the line passing through M with orientation "orient"
            ElecLocFix = sum(bst_bsxfun(@times, W, orient), 2);
            ElecLocFix = bst_bsxfun(@times, ElecLocFix, orient);
            ElecLocFix = bst_bsxfun(@plus, ElecLocFix, M);

            % Set tip: Compute the position of the first contact
            newElec.Loc(:,1) = (ElecLocFix(1,:) - (AllInd(1) - 1) * newElec.ContactSpacing * orient)';
            % Set entry point: last contact is good enough
            newElec.Loc(:,2) = ElecLocFix(end,:)';

            % Duplicate to set orientation and fixed position for all the channels of the strip
            ChanOrient(iMod(iGroupChan),:) = repmat(orient, length(iGroupChan), 1);
            ChanLocFix(iMod(iGroupChan),:) = ElecLocFix;
        % SEEG with no locations
        elseif strcmpi(Modality, 'SEEG')
            % Number of contacts: maximum contact index found in the file
            newElec.ContactNumber = max(AllInd(iGroupChan));
        elseif strcmpi(Modality, 'ECOG')
            % Guess format of the ECOG device
            switch (length(iGroupChan))
                case 12,   newElec.ContactNumber = [6, 2];
                case 16,   newElec.ContactNumber = [8, 2];
                case 32,   newElec.ContactNumber = [8, 4];
                case 64,   newElec.ContactNumber = [8, 8];
                otherwise, newElec.ContactNumber = length(iGroupChan);
            end
        end
        % Add to existing list of electrodes
        ChannelMat.IntraElectrodes(iNewElec) = newElec;
    end
end

    
                              
%% =================================================================================
%  === DISPLAY ELECTRODES  =========================================================
%  =================================================================================

%% ===== CREATE 3D ELECTRODE GEOMETRY =====
function [ElectrodeDepth, ElectrodeLabel, ElectrodeWire, ElectrodeGrid, HiddenChannels] = CreateGeometry3DElectrode(iDS, iFig, Channel, ChanLoc, sElectrodes, isProjectEcog) %#ok<DEFNU>
    global GlobalData;
    % Initialize returned values
    ElectrodeDepth = [];
    ElectrodeLabel = [];
    ElectrodeWire  = [];
    ElectrodeGrid  = [];
    HiddenChannels = [];
    % Get subject
    sSubject = bst_get('Subject', GlobalData.DataSet(iDS).SubjectFile);
    isSurface = ~isempty(sSubject) && (~isempty(sSubject.iInnerSkull) || ~isempty(sSubject.iScalp) || ~isempty(sSubject.iCortex));
    % Get figure and modality
    hFig = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
    Modality = GlobalData.DataSet(iDS).Figure(iFig).Id.Modality;

    % ===== CONTACTS GEOMETRY =====
    % SEEG contact cylinder
    nVert = 34;
    [seegVertex, seegFaces] = tess_cylinder(nVert, 0.5);
    % ECOG contact cylinder: Define electrode geometry (double-layer for Matlab < 2014b)
    if (bst_get('MatlabVersion') < 804)
        nVert = 66;
        [ecogVertex, ecogFaces] = tess_cylinder(nVert, 0.8, [], [], 1);
    else
        nVert = 34;
        [ecogVertex, ecogFaces] = tess_cylinder(nVert, 0.8, [], [], 0);
    end
    % Define electrode geometry
    nVert = 32;
    [sphereVertex, sphereFaces] = tess_sphere(nVert);
    % Get display configuration from iEEG tab
    ElectrodeDisplay = getappdata(hFig, 'ElectrodeDisplay');
    % Optimal lighting depends on Matlab version
    if (bst_get('MatlabVersion') < 804)
        FaceLighting = 'gouraud';
    else
        FaceLighting = 'flat';
    end
    % Compute contact normals: ECOG and EEG
    if isSurface && (ismember(Modality, {'ECOG','EEG'}) || (~isempty(sElectrodes) && any(strcmpi({sElectrodes.Type}, 'ECOG'))))
        if isProjectEcog
            ChanNormal = GetChannelNormal(sSubject, ChanLoc, Modality, 0);
        else
            ChanNormal = repmat([0 0 1], size(ChanLoc,1), 1); 
        end
    else
        ChanNormal = [];
    end
    
    % ===== DISPLAY SEEG/ECOG ELECTRODES =====
    iChanProcessed = [];
    UserData    = [];
    Vertex      = [];
    Faces       = [];
    VertexAlpha = [];
    VertexRGB   = [];
    % Get electrode configuration
    if ~isempty(sElectrodes)
        % Get electrode groups
        [iEeg, GroupNames] = panel_montage('GetEegGroups', Channel, [], 1);
        % Display the electrodes one by one
        for iElec = 1:length(sElectrodes)
            sElec = sElectrodes(iElec);
            % Get contacts for this electrode
            iGroup = find(strcmpi(sElec.Name, GroupNames));
            % If there are contacts to plot
            if ~isempty(iGroup)
                iElecChan = iEeg{iGroup};
            else
                iElecChan = [];
            end
            % Hide/show
            if sElec.Visible
                elecAlpha = 1;
            else
                elecAlpha = 0;
                HiddenChannels = [HiddenChannels, iElecChan];
            end
            % Do we have valid locations for this channel
            isValidLoc = ~any(all(ChanLoc(iElecChan,:)==0,2),1);
            ctVertex = [];
            
            % === SPHERE ===
            if (strcmpi(ElectrodeDisplay.DisplayMode, 'sphere') || (strcmpi(sElec.Type, 'ECOG') && ~isSurface) || strcmpi(sElec.Type, 'ECOG-mid')) && ~isempty(sElec.ContactDiameter) && (sElec.ContactDiameter > 0) && ~isempty(sElec.ContactLength) && (sElec.ContactLength > 0) && isValidLoc
                % Contact size and orientation
                % Define radius of the sphere; Using ctSize of half the length, makes the sphere to have the same diameters as the contact length, thus spacing between spheres is the same as the space between contacts
                if strcmpi(sElec.Type, 'SEEG')
                    ctSize = [1 1 1] .* sElec.ContactLength ./ 2;
                else
                    ctSize = [1 1 1] .* sElec.ContactDiameter ./ 2;
                end
                ctOrient = [];
                ctColor  = sElec.Color;
                % Create contacts geometry
                [ctVertex, ctFaces] = Plot3DContacts(sphereVertex, sphereFaces, ctSize, ChanLoc(iElecChan,:), ctOrient);
                % Force Gouraud lighting
                FaceLighting = 'gouraud';
                
            % === SEEG ===
            elseif strcmpi(sElec.Type, 'SEEG')
                % If no location available: cannot display
                if (size(sElec.Loc,2) < 2)
                    continue;
                end
                % Electrode orientation
                elecOrient = sElec.Loc(:,end)' - sElec.Loc(:,1)';
                elecOrient = elecOrient ./ sqrt(sum((elecOrient).^2));
                % Plot depth electrode
                if sElec.Visible && ~isempty(sElec.ElecDiameter) && (sElec.ElecDiameter > 0) && ~isempty(sElec.ElecLength) && (sElec.ElecLength > 0) && ~isempty(sElec.Color)
                    % Create cylinder
                    elecSize   = [sElec.ElecDiameter ./ 2, sElec.ElecDiameter ./ 2, sElec.ElecLength];
                    elecSize   = elecSize - 0.00002;  % Make it slightly smaller than the contacts, so it doesn't cover them when they are the same size
                    elecStart  = sElec.Loc(:,1)';
                    nVert      = 24;
                    [elecVertex, elecFaces] = tess_cylinder(nVert, 1, elecSize, elecOrient);
                    % Set electrode actual position
                    elecVertex = bst_bsxfun(@plus, elecVertex, elecStart);
                    % Electrode object
                    iElec = length(ElectrodeDepth) + 1;
                    ElectrodeDepth(iElec).Faces     = elecFaces;
                    ElectrodeDepth(iElec).Vertices  = elecVertex;
                    ElectrodeDepth(iElec).FaceColor = sElec.Color;
                    ElectrodeDepth(iElec).FaceAlpha = elecAlpha;
                    ElectrodeDepth(iElec).Options = {...
                        'EdgeColor',        'none', ...
                        'BackfaceLighting', 'unlit', ...
                        'AmbientStrength',  0.5, ...
                        'DiffuseStrength',  0.5, ...
                        'SpecularStrength', 0.2, ...
                        'SpecularExponent', 1, ...
                        'SpecularColorReflectance', 0, ...
                        'FaceLighting',     'gouraud', ...
                        'EdgeLighting',     'gouraud', ...
                        'Tag',              'ElectrodeDepth', ...
                        'UserData',         sElec.Name};
                    % Add text at the tip of the electrode
                    locLabel = sElec.Loc(:,1)' + elecOrient * (sElec.ElecLength + 0.005);
                    ElectrodeLabel(iElec).Type    = 'SEEG';
                    ElectrodeLabel(iElec).Loc     = locLabel;
                    ElectrodeLabel(iElec).Name    = sElec.Name;
                    ElectrodeLabel(iElec).Color   = sElec.Color;
                    ElectrodeLabel(iElec).Options = {...
                        'FontUnits',   'points', ...
                        'Tag',         'ElectrodeLabel', ...
                        'Interpreter', 'none', ...
                        'UserData',    sElec.Name};
                end
                % Plot contacts
                if ~isempty(iElecChan) && ~isempty(sElec.ContactDiameter) && (sElec.ContactDiameter > 0) && ~isempty(sElec.ContactLength) && (sElec.ContactLength > 0) && ~any(all(ChanLoc(iElecChan,:)==0,2),1) && isValidLoc
                    % Contact size and orientation
                    ctSize   = [sElec.ContactDiameter ./ 2, sElec.ContactDiameter ./ 2, sElec.ContactLength];
                    ctOrient = repmat(elecOrient, length(iElecChan), 1);
                    ctColor  = [.9,.9,0];
                    % Create contacts geometry
                    [ctVertex, ctFaces] = Plot3DContacts(seegVertex, seegFaces, ctSize, ChanLoc(iElecChan,:), ctOrient);
                end
                
            % === ECOG ===
            elseif strcmpi(sElec.Type, 'ECOG') && ~isempty(ChanNormal)
                % Display ECOG label
                if sElec.Visible && (length(iElecChan) >= 2) && ~isempty(sElec.ElecDiameter) && (sElec.ElecDiameter > 0)
                    % Add text on top of the 1st contact
                    locLabel = 1.1 * ChanLoc(iElecChan(1),:);
                    iElec = length(ElectrodeLabel) + 1;
                    ElectrodeLabel(iElec).Type    = 'ECOG';
                    ElectrodeLabel(iElec).Loc     = locLabel;
                    ElectrodeLabel(iElec).Name    = sElec.Name;
                    ElectrodeLabel(iElec).Color   = sElec.Color;
                    ElectrodeLabel(iElec).Options = {...
                        'FontUnits',   'points', ...
                        'Tag',         'ElectrodeLabel', ...
                        'Interpreter', 'none', ...
                        'UserData',    sElec.Name};
                end
                % Plot contacts
                if ~isempty(iElecChan) && ~isempty(sElec.ContactDiameter) && (sElec.ContactDiameter > 0) && ~isempty(sElec.ContactLength) && (sElec.ContactLength > 0) && isValidLoc
                    % Contact size and orientation
                    ctSize   = [sElec.ContactDiameter ./ 2, sElec.ContactDiameter ./ 2, sElec.ContactLength];
                    ctOrient = ChanNormal(iElecChan,:);
                    %ctColor  = [.9,.9,0]; YELLOW
                    ctColor  = sElec.Color;
                    % Create contacts geometry
                    [ctVertex, ctFaces] = Plot3DContacts(ecogVertex, ecogFaces, ctSize, ChanLoc(iElecChan,:), ctOrient);
                end
            end
            % If there are contacts to render
            if ~isempty(iElecChan) && ~isempty(ctVertex)
                % Add to global patch
                offsetVert  = size(Vertex,1);
                Vertex      = [Vertex;      ctVertex];
                Faces       = [Faces;       ctFaces + offsetVert];
                VertexAlpha = [VertexAlpha; repmat(elecAlpha, size(ctVertex,1), 1)];
                VertexRGB   = [VertexRGB;   repmat(ctColor,   size(ctVertex,1), 1)];
                % Save the channel index in the UserData
                UserData    = [UserData;    reshape(repmat(iElecChan, size(ctVertex,1)./length(iElecChan), 1), [], 1)];
                % Add to the list of processed channels
                iChanProcessed = [iChanProcessed, iElecChan];
            end
            
            % ===== ECOG WIRE =====
            % Display ECOG wires
            if ismember(sElec.Type, {'ECOG', 'ECOG-mid'}) && sElec.Visible && (length(iElecChan) >= 2) && ~isempty(sElec.ElecDiameter) && (sElec.ElecDiameter > 0)
                % Check if all the contacts are aligned
                isAligned = 1;
                for i = 2:(length(iElecChan)-1)
                    % Calculate dot product of vectors (i-1,i) and (i,i+1)
                    d = sum((ChanLoc(iElecChan(i),:) - ChanLoc(iElecChan(i-1),:)) .* (ChanLoc(iElecChan(i+1),:) - ChanLoc(iElecChan(i),:)));
                    % If negative skip this group
                    if (d < 0)
                        isAligned = 0;
                        break;
                    end
                end
                % Plot wire
                if isAligned
                    iElec = length(ElectrodeWire) + 1;
                    ElectrodeWire(iElec).Loc = ChanLoc(iElecChan,:);
                    ElectrodeWire(iElec).LineWidth = sElec.ElecDiameter * 1000;
                    ElectrodeWire(iElec).Color     = sElec.Color;
                    ElectrodeWire(iElec).Options = {...
                        'LineStyle', '-', ...
                        'Tag',       'ElectrodeWire', ...
                        'UserData',  sElec.Name};
                end
            end
        end
    end
    
    % ===== ADD SPHERE CONTACTS ======
    % Get the sensors that haven't been displayed yet
    iChanOther = setdiff(1:length(Channel), iChanProcessed);
    isValidLoc = ~any(all(ChanLoc(iChanOther,:)==0,2),1);
    % Display spheres
    if ~isempty(iChanOther) && isValidLoc
        % Get the saved display defaults for this modality
        ElectrodeConfig = bst_get('ElectrodeConfig', Modality);
        % SEEG: Sphere
        if strcmpi(Modality, 'SEEG')
            ctSize    = [1 1 1] .* ElectrodeConfig.ContactLength ./ 2;
            tmpVertex = sphereVertex;
            tmpFaces  = sphereFaces;
            ctOrient  = [];
            % Force Gouraud lighting
            FaceLighting = 'gouraud';
        % ECOG/EEG: Cylinder (if normals are available)
        elseif ~isempty(ChanNormal)
            ctSize   = [ElectrodeConfig.ContactDiameter ./ 2, ElectrodeConfig.ContactDiameter ./ 2, ElectrodeConfig.ContactLength];
            ctOrient = ChanNormal(iChanOther,:);
            tmpVertex = ecogVertex;
            tmpFaces  = ecogFaces;
        % ECOG/EEG: Sphere (if normals are not available)
        else
            ctSize    = [1 1 1] .* ElectrodeConfig.ContactDiameter ./ 2;
            tmpVertex = sphereVertex;
            tmpFaces  = sphereFaces;
            ctOrient  = [];
            % Force Gouraud lighting
            FaceLighting = 'gouraud';
        end
        [ctVertex, ctFaces] = Plot3DContacts(tmpVertex, tmpFaces, ctSize, ChanLoc(iChanOther,:), ctOrient);
        % Display properties
        ctColor   = [.9,.9,0];  % YELLOW
        elecAlpha = 1;
        % Add to global patch
        offsetVert  = size(Vertex,1);
        Vertex      = [Vertex;      ctVertex];
        Faces       = [Faces;       ctFaces + offsetVert];
        VertexAlpha = [VertexAlpha; repmat(elecAlpha, size(ctVertex,1), 1)];
        VertexRGB   = [VertexRGB;   repmat(ctColor,   size(ctVertex,1), 1)];
        % Save the channel index in the UserData
        UserData    = [UserData;    reshape(repmat(iChanOther, size(ctVertex,1)./length(iChanOther), 1), [], 1)];
    end
    % Create patch
    if ~isempty(Vertex)
        ElectrodeGrid.Faces               = Faces;
        ElectrodeGrid.Vertices            = Vertex;
        ElectrodeGrid.FaceVertexCData     = VertexRGB;
        ElectrodeGrid.FaceVertexAlphaData = VertexAlpha;
        ElectrodeGrid.Options = {...
            'EdgeColor',        'none', ...
            'BackfaceLighting', 'unlit', ...
            'AmbientStrength',  0.5, ...
            'DiffuseStrength',  0.6, ...
            'SpecularStrength', 0, ...
            'FaceLighting',     FaceLighting, ...
            'Tag',              'ElectrodeGrid', ...
            'UserData',         UserData};
    end
end

%% ===== PLOT 3D CONTACTS =====
function [Vertex, Faces] = Plot3DContacts(ctVertex, ctFaces, ctSize, ChanLoc, ChanOrient)
    % Apply contact size
    ctVertex = bst_bsxfun(@times, ctVertex, ctSize);
    % Duplicate this contact
    nChan  = size(ChanLoc,1);
    nVert  = size(ctVertex,1);
    nFace  = size(ctFaces,1);
    Vertex = zeros(nChan*nVert, 3);
    Faces  = zeros(nChan*nFace, 3);
    for iChan = 1:nChan
        % Apply orientation
        if ~isempty(ChanOrient) && ~isequal(ChanOrient(iChan,:), [0 0 1])
            v1 = [0;0;1];
            v2 = ChanOrient(iChan,:)';
            % Rotation matrix (Rodrigues formula)
            angle = acos(v1'*v2);
            axis  = cross(v1,v2) / norm(cross(v1,v2));
            axis_skewed = [ 0 -axis(3) axis(2) ; axis(3) 0 -axis(1) ; -axis(2) axis(1) 0];
            R = eye(3) + sin(angle)*axis_skewed + (1-cos(angle))*axis_skewed*axis_skewed;
            % Apply rotation to the vertices of the electrode
            ctVertexOrient = ctVertex * R';
        else
            ctVertexOrient = ctVertex;
        end
        % Set electrode position
        ctVertexOrient = bst_bsxfun(@plus, ChanLoc(iChan,:), ctVertexOrient);
        % Report in final patch
        iVert  = (iChan-1) * nVert + (1:nVert);
        iFace = (iChan-1) * nFace + (1:nFace);
        Vertex(iVert,:) = ctVertexOrient;
        Faces(iFace,:)  = ctFaces + nVert*(iChan-1);
    end
end


%% ===== GET CHANNEL NORMALS =====
% USAGE: GetChannelNormal(sSubject, ChanLoc, Modality)
%        GetChannelNormal(sSubject, ChanLoc, SurfaceType)   % SurfaceType={'scalp','innerskull','cortex','cortexhull','cortexmask'}
function [ChanOrient, ChanLocProj] = GetChannelNormal(sSubject, ChanLoc, SurfaceType, isInteractive)
    % Initialize returned variables
    ChanOrient = [];
    ChanLocProj = ChanLoc;
    % CALL: GetChannelNormal(sSubject, ChanLoc, Modality)
    if ismember(SurfaceType, {'EEG','NIRS'})
        SurfaceType = 'scalp';
    elseif ismember(SurfaceType, {'SEEG','ECOG','ECOG+SEEG'})
        if ~isempty(sSubject.iInnerSkull)
            SurfaceType = 'innerskull';
        elseif ~isempty(sSubject.iCortex)
            SurfaceType = 'cortexmask';
        elseif ~isempty(sSubject.iScalp)
            SurfaceType = 'scalp';
        else
            SurfaceType = 'cortexmask';
        end
    end
    % Get surface
    isConvhull = 0;
    isMask = 0;
    if strcmpi(SurfaceType, 'innerskull')
        if ~isempty(sSubject.iInnerSkull)
            SurfaceFile = sSubject.Surface(sSubject.iInnerSkull).FileName;
        else
            if isInteractive
                bst_error(['No inner skull surface for this subject.' 10 'Compute BEM surfaces first.'], 'Compute contact normals', 0);
            end
            return;
        end
    elseif strcmpi(SurfaceType, 'scalp')
        if ~isempty(sSubject.iScalp)
            SurfaceFile = sSubject.Surface(sSubject.iScalp).FileName;
        else
            if isInteractive
                bst_error(['No head surface for this subject.' 10 'Compute head surface first.'], 'Compute contact normals', 0);
            end
            return;
        end
    elseif ismember(SurfaceType, {'cortex','cortexhull','cortexmask'})
        if ~isempty(sSubject.iCortex)
            SurfaceFile = sSubject.Surface(sSubject.iCortex).FileName;
            if strcmpi(SurfaceType, 'cortexhull')
            	isConvhull = 1;
            elseif strcmpi(SurfaceType, 'cortexmask')
                isMask = 1;
            end
        else
            if isInteractive
                bst_error(['No cortex surface for this subject.' 10 'Import full segmented anatomy or compute SPM canonical surfaces.'], 'Compute contact normals', 0);
            end
            return;
        end
    end
    % Load surface (or get from memory)
    if isMask
        % Compute surface based on MRI mask
        % [sSurf, sOrig] = tess_envelope(SurfaceFile, 'mask_cortex', 5000);
        sSurf = bst_memory('GetSurfaceEnvelope', SurfaceFile, 5000, 0, 1); 
        Vertices    = sSurf.Vertices;
        VertNormals = tess_normals(sSurf.Vertices, sSurf.Faces);
    else
        % Load surface
        sSurf = bst_memory('LoadSurface', SurfaceFile);
        Vertices    = sSurf.Vertices;
        VertNormals = sSurf.VertNormals;
        % Get convex hull
        if isConvhull
            Faces = convhulln(Vertices);
            iVertices = unique(Faces(:));
            Vertices    = Vertices(iVertices, :);
            VertNormals = VertNormals(iVertices, :);
        end
    end
    
    % Project electrodes on the surface 
    ChanLocProj = channel_project_scalp(Vertices, ChanLoc);
    % Get the closest vertex for each channel
    iChanVert = bst_nearest(Vertices, ChanLocProj);
    % Get the normals at those points
    ChanOrient = VertNormals(iChanVert, :);
% view_surface_matrix(Vertices, sSurf.Faces);

% OTHER OPTIONS WITH SPHERICAL HARMONICS, A BIT FASTER, NOT WORKING WELL
%     % Compute spherical harmonics
%     fvh = hsdig2fv(Vertices, 20, 5/1000, 40*pi/180, 0);
%     VertNormals = tess_normals(fvh.vertices, fvh.faces);
%     % Get the closest vertex for each channel
%     iChanVert = bst_nearest(fvh.vertices, ChanLoc);
%     % Get the normals at those points
%     ChanOrient = VertNormals(iChanVert, :);
%     % Project electrodes on the surface 
%     ChanLocProj = channel_project_scalp(fvh.vertices, ChanLoc);

end


%% ===== ALIGN CONTACTS =====
function Channels = AlignContacts(iDS, iFig, Method, sElectrodes, Channels, isUpdate, isProjectEcog)
    global GlobalData;
    % Default values
    if (nargin < 7) || isempty(isProjectEcog)
        isProjectEcog = 1;
    end
    if (nargin < 6) || isempty(isUpdate)
        isUpdate = 1;
    end
    % If using electrodes in input
    if (nargin >= 5) && ~isempty(sElectrodes) && ~isempty(Channels)
        isImplantation = 0;
        isUpdateDS = 0;
    else
        % Get selected electrode
        sElectrodes = GetSelectedElectrodes();
        if isempty(sElectrodes)
            java_dialog('warning', 'No electrode selected.', 'Align contacts');
            Channels = [];
            return
        end
        % Check if this is an new implantation folder
        [fPath, folderName] = bst_fileparts(bst_fileparts(GlobalData.DataSet(iDS(1)).ChannelFile));
        isImplantation = ~isempty(strfind(folderName, 'Implantation'));
        % Check if there are channels available
        Channels = GlobalData.DataSet(iDS(1)).Channel;
        if isempty(GlobalData.DataSet(iDS(1)).IntraElectrodes)
            return;
        end
        isUpdateDS = 1;
    end
    % Get subject description
    sSubject = bst_get('Subject', GlobalData.DataSet(iDS(1)).SubjectFile);
    % Process all the electrodes
    for iElec = 1:length(sElectrodes)
        % Number of landmarks that have been set
        nPoints = size(sElectrodes(iElec).Loc,2);
        % Check all the electrodes properties are defined
        if isempty(sElectrodes(iElec).ContactNumber)
            disp(['BST> Warning: Number of contacts is not defined for electrode "' sElectrodes(iElec).Name '".']);
            continue;
        end
        % Get contacts for this electrode
        iChan = find(strcmpi({Channels.Group}, sElectrodes(iElec).Name));
        if isempty(iChan)
            % Add new channels
            if isImplantation
                sChannel = db_template('channeldesc');
                switch (sElectrodes(iElec).Type)
                    case 'SEEG'
                        sChannel.Type = 'SEEG';
                    case {'ECOG','ECOG-mid'}
                        sChannel.Type = 'ECOG';
                end
                sChannel.Group = sElectrodes(iElec).Name;
                for i = 1:prod(sElectrodes(iElec).ContactNumber)
                    sChannel.Name = sprintf('%s%d', sElectrodes(iElec).Name, i);
                    Channels(end+1) = sChannel;
                    iChan(end+1) = length(Channels);
                end
                for i = 1:length(iDS)
                    GlobalData.DataSet(iDS(i)).Channel = Channels;
                    GlobalData.DataSet(iDS(i)).Figure(iFig(i)).SelectedChannels = [GlobalData.DataSet(iDS(i)).Figure(iFig(i)).SelectedChannels, iChan];
                end
            else
                disp(['BST> Warning: No contact for electrode "' sElectrodes(iElec).Name '".']);
                continue;
            end
        end
        % Parse sensor names
        [AllGroups, AllTags, AllInd, isNoInd] = panel_montage('ParseSensorNames', Channels(iChan));
        % Call the function to align electodes
        Modality = Channels(iChan(1)).Type;
        % Remove dimension "1" if any
        if (length(sElectrodes(iElec).ContactNumber) > 1)
            sElectrodes(iElec).ContactNumber(sElectrodes(iElec).ContactNumber == 1) = [];
        end
        
        % === SEEG ===
        if strcmpi(Modality, 'SEEG')
            % Check number of available points
            if (nPoints < 2)
                disp(['BST> Warning: Positions are not defined for electrode "' sElectrodes(iElec).Name '".']);
                continue;
            % Contact spacing must be available for default positions
            elseif strcmpi(Method, 'default') && isempty(sElectrodes(iElec).ContactSpacing)
                disp(['BST> Warning: Contact spacing is not defined for electrode "' sElectrodes(iElec).Name '".']);
                continue;
            end
            % Get electrode orientation
            elecTip = sElectrodes(iElec).Loc(:,1);
            orient = (sElectrodes(iElec).Loc(:,2) - elecTip);
            orient = orient ./ sqrt(sum(orient .^ 2));
            % for line fitting
            linePlot.X = [];
            linePlot.Y = [];
            linePlot.Z = [];
            % Process each contact
            for i = 1:length(iChan)
                switch (Method)
                    case 'default'
                        % Compute the default position of the contact
                        Channels(iChan(i)).Loc = elecTip + (AllInd(i) - 1) * sElectrodes(iElec).ContactSpacing * orient;
                    case 'project'
                        % Project the existing contact on the depth electrode
                        Channels(iChan(i)).Loc = elecTip + sum(orient .* (Channels(iChan(i)).Loc - elecTip)) .* orient;
                    case 'lineFit'
                        linePlot.X = [linePlot.X, Channels(iChan(i)).Loc(1)];
                        linePlot.Y = [linePlot.Y, Channels(iChan(i)).Loc(2)];
                        linePlot.Z = [linePlot.Z, Channels(iChan(i)).Loc(3)];
                end
            end

            if strcmpi(Method, 'lineFit')
                LineFit(linePlot, Channels(iChan(1)).Group);
            end
         
        % === ECOG STRIPS ===
        elseif (ismember(Modality, {'ECOG','ECOG-mid'}) && (length(sElectrodes(iElec).ContactNumber) == 1))
            % Check number of available points
            if (nPoints < 2)
                disp(['BST> Warning: Positions are not defined for ECOG strip "' sElectrodes(iElec).Name '".']);
                continue;
            end
            % Compute contacts positions
            w1 = sElectrodes(iElec).ContactNumber-1:-1:0;
            w2 = 0:sElectrodes(iElec).ContactNumber-1;
            NewLoc = bst_bsxfun(@rdivide, sElectrodes(iElec).Loc(:,1) * w1 + sElectrodes(iElec).Loc(:,2) * w2, w1 + w2)';

            % === PROJECT FOLLOWING THE SHAPE OF THE CORTEX ===
            % ECOG only (no ECOG-mid)
            if strcmpi(sElectrodes(iElec).Type, 'ECOG') && isProjectEcog
                % Project all points on the surface
                [ProjOrient, ProjLoc] = GetChannelNormal(sSubject, NewLoc, 'ECOG', 1);
                % Do not go further if it's impossible to project the electrodes on a surface
                if ~isempty(ProjOrient)
                    [tmp, ProjElecLoc] = GetChannelNormal(sSubject, sElectrodes(iElec).Loc', 'ECOG', 1);
                    % Compute the distance between the original points and the projection 
                    dChan = sqrt(sum((ProjLoc - NewLoc) .^2, 2));
                    dElec = sqrt(sum((sElectrodes(iElec).Loc' - ProjElecLoc) .^2, 2));
                    % Get distance associated with each corner
                    d1 = dElec(1,:);
                    d2 = dElec(2,:);
                    % Compute the distance to the surface we want for each contact
                    dChanTarget = ((w1*d1 + w2*d2) ./ (w1 + w2))';
                    % Project the channels in the direction of the cortex, so that they are at the expected distance
                    % Normalization with bsxfun, equivalent to: NewLoc = NewLoc + (ProjLoc - NewLoc) ./ dChan .* (dChan - dChanTarget);
                    proj = ProjLoc - NewLoc;
                    proj = bst_bsxfun(@rdivide, proj, dChan);
                    proj = bst_bsxfun(@times, proj, dChan - dChanTarget);
                    NewLoc = NewLoc + proj;
                end
            end
            % Get the list of channels in the channel file
            if (all(AllInd <= sElectrodes(iElec).ContactNumber)) && (length(unique(AllInd)) == length(AllInd))
                iChanList = AllInd;
            else
                iChanList = 1:length(iChan);
            end
            % Copy channel positions
            for i = 1:length(iChanList)
                Channels(iChan(i)).Loc = NewLoc(iChanList(i),:)';
            end

        % === ECOG GRIDS ===
        elseif ismember(Modality, {'ECOG','ECOG-mid'})
            % Two different representations for the same grid (U=rows, V=cols)
            %                             |              V ->
            %    Q ___________ S          |        P ___________ T
            %     |__|__|__|__|           |         |__|__|__|__| 
            %     |__|__|__|__|   ^       |     U   |__|__|__|__| 
            %     |__|__|__|__|   U       |     |   |__|__|__|__| 
            %     |__|__|__|__|           |         |__|__|__|__| 
            %    T             P          |        S             Q
            %         <- V                |
            
            % Check number of available points
            if (nPoints < 4)
                disp(['BST> Warning: Positions are not defined for electrode "' sElectrodes(iElec).Name '".']);
                continue;
            end
            % Get grid dimensions
            nRows = sElectrodes(iElec).ContactNumber(1);
            nCols = sElectrodes(iElec).ContactNumber(2);
            % Get the electrodes indices
            [I,J] = meshgrid(1:nRows, 1:nCols);
            % Get list of indices, for the approriate orientation
            orient = 0;
            switch (orient)
                case 0,    I = I';     J = J'; 
                case 1,    I = I(:);   J = J(:);
                otherwise, error('Unsupported orientation');
            end
            I = I(:);
            J = J(:);
            
            % Get four corners of the grid
            P = sElectrodes(iElec).Loc(:,1)';
            S = sElectrodes(iElec).Loc(:,2)';
            Q = sElectrodes(iElec).Loc(:,3)';
            T = sElectrodes(iElec).Loc(:,4)';
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

            % === PROJECT FOLLOWING THE SHAPE OF THE CORTEX ===
            % ECOG only (no ECOG-mid)
            if strcmpi(sElectrodes(iElec).Type, 'ECOG') && isProjectEcog
                % Project all points on the surface
                [ProjOrient, ProjLoc] = GetChannelNormal(sSubject, NewLoc, 'ECOG', 1);
                % Do not go further if it's impossible to project the electrodes on a surface
                if ~isempty(ProjOrient)
                    [tmp, ProjElecLoc] = GetChannelNormal(sSubject, sElectrodes(iElec).Loc', 'ECOG', 1);
                    % Compute the distance between the original points and the projection 
                    dChan = sqrt(sum((ProjLoc - NewLoc) .^2, 2));
                    dElec = sqrt(sum((sElectrodes(iElec).Loc' - ProjElecLoc) .^2, 2));
                    % Get distance associated with each corner
                    dp = dElec(1,:);
                    dt = dElec(2,:);
                    ds = dElec(3,:);
                    dq = dElec(4,:);
                    % Compute the distance to the surface we want for each contact
                    dChanTarget = (wp*dp + wt*dt + ws*ds + wq*dq) ./ (wp + wt + ws + wq);
                    % Project the channels in the direction of the cortex, so that they are at the expected distance
                    % Normalization with bsxfun, equivalent to: NewLoc = NewLoc + (ProjLoc - NewLoc) ./ dChan .* (dChan - dChanTarget);
                    proj = ProjLoc - NewLoc;
                    proj = bst_bsxfun(@rdivide, proj, dChan);
                    proj = bst_bsxfun(@times, proj, dChan - dChanTarget);
                    NewLoc = NewLoc + proj;
                end
            end
            
            % === MATCH GRID POINTS AND DATA CHANNELS ===
            % If all the electrodes are defined: direct mapping
            if (nCols*nRows == length(iChan))
                for i = 1:length(iChan)
                    Channels(iChan(i)).Loc = NewLoc(i,:)';
                end
            % Else: Match contact names with indices
            else
                for i = 1:length(iChan)
                    Channels(iChan(i)).Loc = NewLoc(AllInd(i),:)';
                end
            end
        end

%         % === PROJECT ON CORTEX SURFACE ===
%         % Only possible if surface is available
%         if strcmpi(Modality, 'ECOG') && (~isempty(sSubject.iCortex) || ~isempty(sSubject.iInnerSkull) || ~isempty(sSubject.iScalp))
%             % Project on the surface
%             [NewOrient, NewLoc] = GetChannelNormal(sSubject, [Channels(iChan).Loc]', 'ECOG', 1);
%             % Replace original channel positions
%             for i = 1:length(iChan)
%                 Channels(iChan(i)).Loc = NewLoc(i,:)';
%             end
%         elseif strcmpi(Modality, 'ECOG')
%             disp('Warning: No inner skull surface available for this subject, cannot project the contacts on the skull.');
%         end
        % Mark channel file as modified
        if isUpdate && isUpdateDS
            GlobalData.DataSet(iDS(1)).isChannelModified = 1;
        end
    end
    % If loaded datasets should be updated
    if isUpdate && isUpdateDS
        % Update electrode position
        for i = 1:length(iDS)
            GlobalData.DataSet(iDS(i)).Channel = Channels;
        end
        % Update figures
        UpdateFigures();
    end
end


%% ===== PROJECT CONTACTS ON SURFACE =====
function ProjectContacts(iDS, iFig, SurfaceType)
    global GlobalData;
    % Check if there are channels available
    Channels = GlobalData.DataSet(iDS).Channel;
    if isempty(Channels) || isempty(GlobalData.DataSet(iDS).IntraElectrodes)
        return;
    end
    % Get selected electrode
    [sSelElec, iSelElec] = GetSelectedElectrodes();
    if isempty(iSelElec)
        java_dialog('warning', 'No electrode selected.', 'Align contacts');
        return
    end
    % Get subject description
    sSubject = bst_get('Subject', GlobalData.DataSet(iDS).SubjectFile);
    % Check that the appropriate surfaces are available
    if strcmpi(SurfaceType, 'innerskull') && (isempty(sSubject.iInnerSkull) || (sSubject.iInnerSkull > length(sSubject.Surface)))
        bst_error('No inner skull surface available for this subject.', 'Project contacts', 0);
    elseif ismember(SurfaceType, {'cortex','cortexhull','cortexmask'}) && (isempty(sSubject.iCortex) || (sSubject.iCortex > length(sSubject.Surface)))
        bst_error('No cortex available for this subject.', 'Project contacts', 0);
    end
    % Process all the electrodes
    for iElec = 1:length(sSelElec)
        % Skip non-ECOG entries
        if ~strcmpi(sSelElec(iElec).Type, 'ECOG')
            disp(['Electrode "' sSelElec(iElec).Name '" is not set as ECOG. Skipping...']);
            continue;
        end
        % Get contacts for this electrode
        iChan = find(strcmpi({Channels.Group}, sSelElec(iElec).Name));
        if isempty(iChan)
            disp(['BST> Warning: No contact for electrode "' sSelElec(iElec).Name '".']);
            continue;
        end
        % Project on the target surface
        [NewOrient, NewLoc] = GetChannelNormal(sSubject, [Channels(iChan).Loc]', SurfaceType, 1);
        % Replace original channel positions
        if ~isempty(NewOrient)
            for i = 1:length(iChan)
                Channels(iChan(i)).Loc = NewLoc(i,:)';
            end
        end
    end
    % Update electrode position
    GlobalData.DataSet(iDS).Channel = Channels;
    GlobalData.DataSet(iDS).isChannelModified = 1;
    % Update figures
    UpdateFigures();
end

%% ===== DRAW REFERENCE ELECTRODE =====
% perform line fitting between contacts
function LineFit(plotLoc, Tag)
    % Get axes handle
    hFig = bst_figures('GetFiguresByType', '3DViz');
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    hCoord = findobj(hAxes, '-depth', 1, 'Tag', Tag);
    if ~isempty(hCoord)
        delete(hCoord);
    else
        % plot the reference line between tip and entry
        line(plotLoc.X, plotLoc.Y, plotLoc.Z, ...
             'Color', [1 1 0], ...
             'LineWidth',       2, ...
             'Parent', hAxes, ...
             'Tag', Tag);
    end
end

%% ===== SET ELECTRODE LOCATION =====
function SetElectrodeLoc(iLoc, jButton)
    global GlobalData;

    % Get selected electrodes
    [sSelElec, iSelElec, iDS, iFig, hFig] = GetSelectedElectrodes();
    MriIdx = 1;

    if isempty(sSelElec)
    	bst_error('No electrode seleced.', 'Set electrode position', 0);
        return;
    elseif (length(sSelElec) > 1)
        bst_error('Multiple electrodes selected.', 'Set electrode position', 0);
        return;
    elseif ~strcmpi(GlobalData.DataSet(iDS(MriIdx)).Figure(iFig(MriIdx)).Id.Type, 'MriViewer')
        if length(hFig) == 1
            bst_error('MRI viewer must be open', 'Set electrode position', 0);
            return;
        end
        MriIdx = 2;
    elseif (size(sSelElec.Loc, 2) < iLoc-1)
        bst_error('Set the previous reference point (the tip) first.', 'Set electrode position', 0);
        return;
    end
    
    
    sMri = panel_surface('GetSurfaceMri', hFig(MriIdx));
    XYZ = figure_mri('GetLocation', 'scs', sMri, GlobalData.DataSet(iDS(MriIdx)).Figure(iFig(MriIdx)).Handles);

    % If SCS coordinates are not available
    if isempty(XYZ)
        % Ask to compute MNI transformation
        isComputeMni = java_dialog('confirm', [...
            'You need to define the NAS/LPA/RPA fiducial points before.' 10 ...
            'Computing the MNI normalization would also define default fiducials.' 10 10 ...
            'Compute the MNI normalization now?'], 'Set electrode position');
        % Run computation
        if isComputeMni
            figure_mri('ComputeMniCoordinates', hFig);
        end
        return;
    end
    % Make sure the points of the electrode are more than 1cm apart
    iOther = setdiff(1:size(sSelElec.Loc,2), iLoc);
    if (~isempty(sSelElec.Loc) && ~isempty(iOther) && any(sqrt(sum(bst_bsxfun(@minus, sSelElec.Loc(:,iOther), XYZ(:)).^2)) < 0.002))
        bst_error('The two points you selected are less than 2mm away.', 'Set electrode position', 0);
        return;
    end
    % Set electrode position
    sSelElec.Loc(:,iLoc) = XYZ(:);
    % Save electrode modification
    SetElectrodes(iSelElec, sSelElec);
    % Paint the button in green
    jButton.setForeground(java.awt.Color(0, 0.8, 0));
    % Get the contact for this electrode
    iChan = find(strcmpi({GlobalData.DataSet(iDS(1)).Channel.Group}, sSelElec.Name));
    % Check if this is an new implantation folder
    [fPath, folderName] = bst_fileparts(bst_fileparts(GlobalData.DataSet(iDS(1)).ChannelFile));
    isImplantation = ~isempty(strfind(folderName, 'Implantation'));
    % Update contact positions
%     if (~isempty(iChan) || isImplantation) && ...
    if ((strcmpi(sSelElec.Type, 'SEEG') && (size(sSelElec.Loc,2) >= 2)) || ...
        (ismember(sSelElec.Type, {'ECOG','ECOG-mid'}) && (length(sSelElec.ContactNumber) == 1) && (size(sSelElec.Loc,2) >= 2)) || ...
        (ismember(sSelElec.Type, {'ECOG','ECOG-mid'}) && (size(sSelElec.Loc,2) >= 4)))
        % Warnings and checks
        if strcmpi(sSelElec.Type, 'SEEG') && isempty(sSelElec.ContactSpacing)
            bst_error(['Contact spacing is not defined for electrode "' sSelElec.Name '".'], 'Set electrode position', 0);
            return;
        end
        % If the positions are not set, set positions automatically
        if isempty(iChan) || any(cellfun(@(c)or(isempty(c), isequal(c,[0;0;0])), {GlobalData.DataSet(iDS(1)).Channel(iChan).Loc}))
            isAlign = 1;
        % Otherwise, ask for confirmation to the user
        elseif (~isempty(iChan) || isImplantation)
            isAlign = java_dialog('confirm', 'Update the positions of the contacts?', 'Set electrode position');
        else
            isAlign = 0;
        end
        % Align contacts
        if isAlign
            % Set default contacts positions
            AlignContacts(iDS, iFig, 'default');
        else
            % Update display
            UpdateFigures();
        end
        % Update figure modalities
        for i = 1:length(iDS)
            UpdateFigureModality(iDS(i), iFig(i));
        end
    end
end


%% ===== CENTER MRI ON ELECTRODE =====
function CenterMriOnElectrode(sElec, hFigTarget)
    global GlobalData;
    % Parse inputs
    if (nargin < 2) || isempty(hFigTarget)
        hFigTarget = [];
    end
    % If tip of electrode not defined: return
    if isempty(sElec) || isempty(sElec.Loc) || isequal(sElec.Loc(:,1), [0;0;0])
        return;
    end
    % Get loaded dataset
    [sElectrodes, iDSall, iFigall, hFigall] = GetElectrodes();
    if isempty(iDSall)
        return;
    end
    % By default: jump to the tip of the electrode
    xyzScs = sElec.Loc(:,1);
    % Try to get the position of the first contact of the electrode, as it might be a bit different
    iChan = find(strcmpi({GlobalData.DataSet(iDSall(1)).Channel.Group}, sElec.Name));
    if ~isempty(iChan)
        [~,I] = sort_nat({GlobalData.DataSet(iDSall(1)).Channel(iChan).Name});
        xyzChan = GlobalData.DataSet(iDSall(1)).Channel(iChan(I(1))).Loc;
        if ~isempty(xyzChan) && all(size(xyzChan) == size(xyzScs)) && (sqrt(sum(xyzChan - xyzScs).^2) < 5)
            xyzScs = xyzChan;
        end
    end    
    % Update all the figures that share this channel file
    for i = 1:length(iDSall)
        % If there is one target figure to update only:
        if ~isempty(hFigTarget) && ~isequal(hFigTarget, hFigall(i))
            continue;
        end
        % Set slice positions
        switch (GlobalData.DataSet(iDSall(i)).Figure(iFigall(i)).Id.Type)
            case 'MriViewer'
                % Get anatomy surface
                [sMri, TessInfo, iAnatomy] = panel_surface('GetSurfaceMri', hFigall(i));
                % Get new slices coordinates
                xyzVox = cs_convert(sMri, 'scs', 'voxel', xyzScs');
                % Update figure
                figure_mri('SetLocation', 'voxel', hFigall(i), [], xyzVox);
        end
    end
end


%% ===== CREATE IMPLANTATION =====
% USAGE: CreateImplantation(MriFile)   % Implantation on given Volume file
%        CreateImplantation(sSubject)  % Ask user for Volume and Surface files for implantation
function CreateImplantation(MriFile) %#ok<DEFNU>
    % Parse input
    if isstruct(MriFile)
        sSubject = MriFile;
        MriFiles = [];
    else
        sSubject = bst_get('MriFile', MriFile);
        MriFiles = {MriFile};
    end
    % Get study for the new channel file
    switch (sSubject.UseDefaultChannel)
        case 0
            % Get folder "Implantation"
            conditionName = 'Implantation';
            [sStudy, iStudy] = bst_get('StudyWithCondition', bst_fullfile(sSubject.Name, conditionName));
            if ~isempty(sStudy)
                [res, isCancel] = java_dialog('question', ['Warning: there is already an "Implantation" folder for this Subject.' 10 10 ...
                                                           'What do you want to do with the existing implantation?'], ...
                                                           'SEEG/ECOG implantation', [], {'Continue', 'Replace', 'Cancel'}, 'Continue');
                if strcmpi(res, 'cancel') || isCancel
                    return
                elseif strcmpi(res, 'continue')
                    newCondition = 0;
                elseif strcmpi(res, 'replace')
                    % Delete existing Implantation study
                    db_delete_studies(iStudy);
                    newCondition = 1;
                end
            else
                newCondition = 1;
            end
            % Create new folder if needed
            if newCondition
                iStudy = db_add_condition(sSubject.Name, conditionName, 1);
            end
            % Get Implantation study
            sStudy = bst_get('Study', iStudy);
        case 1
            % Use default channel file
            [sStudy, iStudy] = bst_get('AnalysisIntraStudy', sSubject.Name);
            % The @intra study must not contain an existing channel file
            if ~isempty(sStudy.Channel) && ~isempty(sStudy.Channel(1).FileName)
                error(['There is already a channel file for this subject:' 10 sStudy.Channel(1).FileName]);
            end
        case 2
            error('The subject uses a shared channel file, it should not be edited in this way.');
    end

    % Ask user about implantation volume and surface files
    iVol1 = [];
    iVol2 = [];
    iSrf  = [];
    if isempty(MriFiles)
        if isempty(sSubject.Anatomy)
            return
        end
        iMriVol = sSubject.iAnatomy;
        iCtVol  = find(cellfun(@(x) ~isempty(regexp(x, '_volct', 'match')), {sSubject.Anatomy.FileName}));
        iIsoSrf = find(cellfun(@(x) ~isempty(regexp(x, '_isosurface', 'match')), {sSubject.Surface.FileName}));
        iMriVol = setdiff(iMriVol, iCtVol);
        impOptions = {};
        if ~isempty(iMriVol)
            impOptions = [impOptions, {'MRI'}];
        end
        if ~isempty(iCtVol)
            impOptions = [impOptions, {'CT'}];
        end
        if ~isempty(iMriVol) && ~isempty(iCtVol)
            impOptions = [impOptions, {'MRI+CT'}];
        end
        if ~isempty(iCtVol) && ~isempty(iIsoSrf)
            tmpOption = 'CT+IsoSurf';
            if ~isempty(iMriVol)
                tmpOption = ['MRI+' tmpOption];
            end
            impOptions = [impOptions, {tmpOption}];
        end
        impOptions = [impOptions, {'Cancel'}];
        % User dialog
        [res, isCancel] = java_dialog('question', ['There are multiple volumes for this Subject.' 10 10 ...
                                                   'How do you want to continue with the existing implantation?'], ...
                                                   'SEEG/ECOG implantation', [], impOptions, 'Cancel');
        if strcmpi(res, 'cancel') || isCancel
            return
        end
        switch lower(res)
            case 'mri'
                iVol1 = iMriVol;
            case 'ct'
                iVol1 = iCtVol;
            case 'mri+ct'
                iVol1 = iMriVol;
                iVol2 = iCtVol;
            case 'mri+ct+isosurf'
                iVol1 = iMriVol;
                iVol2 = iCtVol;
                iSrf  = iIsoSrf;
            case 'ct+isosurf'
                iVol1 = iCtVol;
                iVol2 = [];
                iSrf  = iIsoSrf;
        end
        % Get CT from IsoSurf  % TODO do not assume there is only one IsoSurf
        if ~isempty(iSrf)
            sSurf = load(file_fullpath(sSubject.Surface(iSrf).FileName), 'History');
            if isfield(sSurf, 'History') && ~isempty(sSurf.History)
                % Search for CT threshold in history
                ctEntry = regexp(sSurf.History{:, 3}, '^Thresholded CT:\s(.*)\sthreshold.*$', 'tokens', 'once');
                % Return intersection of the found and then update iCtVol
                if ~isempty(ctEntry)
                    [~, iCtIso] = ismember(ctEntry{1}, {sSubject.Anatomy.FileName});
                    if iCtIso
                        iCtVol = intersect(iCtIso, iCtVol);
                    else
                        bst_error(sprintf(['The CT that was used to create the IsoSurface cannot be found. ' 10 ...
                                           'CT file : %s'], ctEntry{1}), 'Loading CT for IsoSurface');
                        return
                    end
                end
            end
        end
        if ~strcmpi(res, 'mri') && length(iCtVol) > 1
            % Prompt for the CT file selection
            ctComment = java_dialog('combo', '<HTML>Select the CT file:<BR><BR>', 'Choose CT file', [], {sSubject.Anatomy(iCtVol).Comment});
            if isempty(ctComment)
                return
            end
            [~, ix] = ismember(ctComment, {sSubject.Anatomy(iCtVol).Comment});
            iCtVol = iCtVol(ix);
        end
        % Update vol1 or vol2 to have single CT
        switch lower(res)
            case {'mri+ct', 'mri+ct+isosurf'}
                iVol2 = iCtVol;
            case {'ct', 'ct+isosurf'}
                iVol1 = iCtVol;
        end
        % Get Volume filenames
        if ~isempty(iVol1)
            MriFiles{1} = sSubject.Anatomy(iVol1).FileName;
        end
        if ~isempty(iVol2)
            MriFiles{2} = sSubject.Anatomy(iVol2).FileName;
        end
    end

    % Progress bar
    bst_progress('start', 'Implantation', 'Updating display...');
    % Channel file
    if isempty(sStudy.Channel) || isempty(sStudy.Channel(1).FileName)
        % Create empty channel file structure
        ChannelMat = db_template('channelmat');
        ChannelMat.Comment = 'SEEG/ECOG';
        ChannelMat.Channel = repmat(db_template('channeldesc'), 1, 0);
        % Save new channel in the database
        ChannelFile = db_set_channel(iStudy, ChannelMat, 0, 0);
    else
        % Get channel file from existent study
        ChannelFile = sStudy.Channel(1).FileName;
    end
    % Switch to functional data
    gui_brainstorm('SetExplorationMode', 'StudiesSubj');
    % Select new file
    panel_protocols('SelectNode', [], ChannelFile);
    % Display channels on MRI viewer
    DisplayChannelsMri(ChannelFile, 'SEEG', MriFiles, 0);
    if ~isempty(iSrf)
        % Display isosurface
        DisplayIsosurface(sSubject, iSrf, [], ChannelFile, 'SEEG');
    end
    % Close progress bar
    bst_progress('stop');
end


%% ===== LOAD ELECTRODES =====
function LoadElectrodes(hFig, ChannelFile, Modality) %#ok<DEFNU>
    global GlobalData;
    % Get figure and dataset
    [hFig,iFig,iDS] = bst_figures('GetFigure', hFig);
    if isempty(iDS)
        return;
    end
    % Check that the channel is not already defined
    if ~isempty(GlobalData.DataSet(iDS).ChannelFile) && ~file_compare(GlobalData.DataSet(iDS).ChannelFile, ChannelFile)
        error('There is already another channel file loaded for this MRI. Close the existing figures.');
    end
    % Load channel file in the dataset
    bst_memory('LoadChannelFile', iDS, ChannelFile);
    % If iEEG channels: load both SEEG and ECOG
    if ismember(Modality, {'SEEG', 'ECOG', 'ECOG+SEEG'})
        iChannels = channel_find(GlobalData.DataSet(iDS).Channel, 'SEEG, ECOG');
    else
        iChannels = channel_find(GlobalData.DataSet(iDS).Channel, Modality);
    end
    % Set the list of selected sensors
    GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels = iChannels;
    GlobalData.DataSet(iDS).Figure(iFig).Id.Modality      = Modality;
    % Plot electrodes
    if ~isempty(iChannels)
        switch(GlobalData.DataSet(iDS).Figure(iFig).Id.Type)
            case 'MriViewer'
                GlobalData.DataSet(iDS).Figure(iFig).Handles = figure_mri('PlotElectrodes', iDS, iFig, GlobalData.DataSet(iDS).Figure(iFig).Handles);
                figure_mri('PlotSensors3D', iDS, iFig);
            case '3DViz'
                figure_3d('PlotSensors3D', iDS, iFig);
        end
    end

    % Set EEG flag for MRI Viewer
    if strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.Type, 'MriViewer')
        figure_mri('SetFigureStatus', hFig, [], [], [], 1, 1);
    end
    % Update figure name
    bst_figures('UpdateFigureName', hFig);
end


%% ===== DISPLAY CHANNELS (MRI VIEWER) =====
% USAGE:  [hFig, iDS, iFig] = DisplayChannelsMri(ChannelFile, Modality, iAnatomy, isEdit=0)
%         [hFig, iDS, iFig] = DisplayChannelsMri(ChannelFile, Modality, MriFile, isEdit=0)
%         [hFig, iDS, iFig] = DisplayChannelsMri(ChannelFile, Modality, {MriFiles}, isEdit=0)
function [hFig, iDS, iFig] = DisplayChannelsMri(ChannelFile, Modality, iAnatomy, isEdit)
    % Parse inputs
    if (nargin < 4) || isempty(isEdit)
        isEdit = 0;
    end

    % Get MRI files
    if iscell(iAnatomy)
        MriFiles = iAnatomy;
    elseif ischar(iAnatomy)
        MriFiles = {iAnatomy};
    else
        % Get study
        sStudy = bst_get('ChannelFile', ChannelFile);
        % Get subject
        sSubject = bst_get('Subject', sStudy.BrainStormSubject);
        if isempty(sSubject) || isempty(sSubject.Anatomy)
            bst_error('No MRI available for this subject.', 'Display electrodes', 0);
        end
        % MRI volumes
        MriFiles = {sSubject.Anatomy(iAnatomy).FileName};
    end

    % If MRI Viewer is open don't open another one
    hFig = bst_figures('GetFiguresByType', 'MriViewer');
    if ~isempty(hFig)
        return
    end

    % == DISPLAY THE MRI VIEWER
    if length(MriFiles) == 1
        [hFig, iDS, iFig] = view_mri(MriFiles{1}, [], [], 2);
    else
        [hFig, iDS, iFig] = view_mri(MriFiles{1}, MriFiles{2}, [], 2);
    end
    if isempty(hFig)
        return;
    end
    % Add channels to the figure
    LoadElectrodes(hFig, ChannelFile, Modality);
    % SEEG and ECOG: Open tab "iEEG"
    if ismember(Modality, {'SEEG', 'ECOG', 'ECOG+SEEG'})
        gui_brainstorm('ShowToolTab', 'iEEG');
    end
    % Make electrodes editable
    if isEdit
        figure_mri('SetEditChannels', hFig, isEdit);
    end
end

%% ===== DISPLAY ISOSURFACE =====
function [hFig, iDS, iFig] = DisplayIsosurface(sSubject, iSurface, hFig, ChannelFile, Modality)
    % Parse inputs
    if (nargin < 3) || isempty(hFig)
        hFig = [];
    end 
    if isempty(hFig)
        hFig = view_mri_3d(sSubject.Anatomy(1).FileName, [], 0.3, []);
    end
    [hFig, iDS, iFig] = view_surface(sSubject.Surface(iSurface).FileName, 0.6, [], hFig, []);
    % Add channels to the figure
    LoadElectrodes(hFig, ChannelFile, Modality);
    % SEEG and ECOG: Open tab "iEEG"
    if ismember(Modality, {'SEEG', 'ECOG', 'ECOG+SEEG'})
        gui_brainstorm('ShowToolTab', 'iEEG'); 
    end
end

%% ===== EXPORT CONTACT POSITIONS =====
function ExportChannelFile(isAtlas)
    global GlobalData;
    % Get electrodes to save
    [sElec, iElec, iDS] = GetSelectedElectrodes();
    % If there are no electrodes to export
    if isempty(sElec)
        bst_error('No electrodes to export.', 'Export contacts', 0);
        return;
    end
    % Get the channels corresponding to these contacts
    iChannels = find(cellfun(@(c)any(strcmpi(c,{sElec.Name})), {GlobalData.DataSet(iDS(1)).Channel.Group}));
    if isempty(iChannels)
        bst_error('No contact positions to export.', 'Export contacts', 0);
        return;
    end
    % Force saving the modifications
    bst_memory('SaveChannelFile', iDS(1));
    % Export the file
    if isAtlas
        export_channel_atlas(GlobalData.DataSet(iDS(1)).ChannelFile, iChannels);
    else
        export_channel(GlobalData.DataSet(iDS(1)).ChannelFile);
    end
end

