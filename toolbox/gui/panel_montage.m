function varargout = panel_montage(varargin)
% PANEL_MONTAGE: Edit sensor montages.
%
% USAGE:            panel_montage('ShowEditor');
%        [S,D,WL] = panel_montage('ParseNirsChannelNames', ChannelNames);

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
% Authors: Francois Tadel, 2009-2023

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel() %#ok<DEFNU>
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.icon.*;
    panelName = 'EditMontages';
    % Constants
    global GlobalData;
    OldMontages = GlobalData.ChannelMontages;
    
    % Create main panel
    jPanelNew = gui_component('Panel');
    jPanelNew.setBorder(BorderFactory.createEmptyBorder(10, 10, 10, 10));
    
    % PANEL: left panel (list of available montages)
    jPanelMontages = gui_component('Panel');
    jPanelMontages.setBorder(BorderFactory.createCompoundBorder(...
                             java_scaled('titledborder', 'Montages'), ...
                             BorderFactory.createEmptyBorder(3, 10, 10, 10)));
        % ===== TOOLBAR =====
        jToolbar = gui_component('Toolbar', jPanelMontages, BorderLayout.NORTH);
        jToolbar.setPreferredSize(java_scaled('dimension', 200,25));
            TB_SIZE = java_scaled('dimension', 25,25);
            jButtonNew      = gui_component('ToolbarButton', jToolbar, [], [], {IconLoader.ICON_MONTAGE_MENU, java_scaled('dimension', 35,25)}, 'New montage');
            jButtonLoadFile = gui_component('ToolbarButton', jToolbar, [], [], {IconLoader.ICON_FOLDER_OPEN, TB_SIZE}, 'Load montage');
            jButtonSaveFile = gui_component('ToolbarButton', jToolbar, [], [], {IconLoader.ICON_SAVE, TB_SIZE}, 'Save montage');
            jToolbar.addSeparator();
            jButtonAll = gui_component('ToolbarToggle', jToolbar, [], [], {IconLoader.ICON_SCOUT_ALL, TB_SIZE}, 'Display all the montages');
            jButtonShortcut = gui_component('ToolbarButton', jToolbar, [], [], {IconLoader.ICON_KEYBOARD, TB_SIZE}, 'Add custom keyboard shortcut');
        % LIST: Create list
        jListMontages = JList();
            jListMontages.setFont(bst_get('Font'));
            jListMontages.setSelectionMode(ListSelectionModel.MULTIPLE_INTERVAL_SELECTION);
            fontSize1 = round(11 * bst_get('InterfaceScaling') / 100);
            fontSize2 = round(8 * bst_get('InterfaceScaling') / 100);
            jListMontages.setCellRenderer(java_create('org.brainstorm.list.BstHotkeyListRenderer', 'I', fontSize1, fontSize2));
            java_setcb(jListMontages, 'ValueChangedCallback', [], ...
                                      'KeyTypedCallback',     [], ...
                                      'MouseClickedCallback', []);
            % Create scroll panel
            jScrollPanelSel = JScrollPane(jListMontages);
            jScrollPanelSel.setPreferredSize(java_scaled('dimension', 150,200));
        jPanelMontages.add(jScrollPanelSel, BorderLayout.CENTER);
    jPanelNew.add(jPanelMontages, BorderLayout.WEST);
    
    % PANEL: right panel (sensors list OR text editor)
    jPanelRight = gui_component('Panel');
        % === SENSOR SELECTION ===
        jPanelSelection = gui_component('Panel');
        jPanelSelection.setBorder(BorderFactory.createCompoundBorder(...
                                  java_scaled('titledborder', 'Channel selection'), ...
                                  BorderFactory.createEmptyBorder(10, 10, 10, 10)));
        % LABEL: Title
        jPanelSelection.add(JLabel('<HTML><DIV style="height:15px;">Available sensors:</DIV>'), BorderLayout.NORTH);
        % LIST: Create list (display labels of all clusters)
        jListSensors = JList({'Sensor #1', 'Sensor #2', 'Sensor #3','Sensor #4', 'Sensor #5', 'Sensor #6','Sensor #7', 'Sensor #8', 'Sensor #9','Sensor #10', 'Sensor #11', 'Sensor #12'});
            jListSensors.setFont(bst_get('Font'));
            jListSensors.setLayoutOrientation(jListSensors.VERTICAL_WRAP);
            jListSensors.setVisibleRowCount(-1);
            jListSensors.setSelectionMode(ListSelectionModel.MULTIPLE_INTERVAL_SELECTION);
            % Create scroll panel
            jScrollPanel = JScrollPane(jListSensors);
        jPanelSelection.add(jScrollPanel, BorderLayout.CENTER);
        
        % === TEXT VIEWER ===
        jPanelViewer = gui_component('Panel');
        jPanelViewer.setBorder(BorderFactory.createCompoundBorder(...
                             java_scaled('titledborder', 'Channel selection [Read-only]'), ...
                             BorderFactory.createEmptyBorder(10, 10, 10, 10)));
        jTextViewer = JTextArea(6, 12);
        jTextViewer.setEditable(0);
        % Get font size
        fontSize = round(11 * bst_get('InterfaceScaling') / 100);
        jTextViewer.setFont(Font('Monospaced', Font.PLAIN, fontSize));
        % Create scroll panel
        jScrollPanel = JScrollPane(jTextViewer);
        jPanelViewer.add(jScrollPanel, BorderLayout.CENTER);
                
        % === TEXT EDITOR ===
        jPanelText = gui_component('Panel');
        jPanelText.setBorder(BorderFactory.createCompoundBorder(...
                             java_scaled('titledborder', 'Custom montage'), ...
                             BorderFactory.createEmptyBorder(10, 10, 10, 10)));
        % LABEL: Title
        strHelp = ['Examples:<BR>' ...
            '  Cz-C4 : Cz,-C4          % Difference Cz-C4<BR>' ...
            '  MC    : 0.5*M1, 0.5*M2  % Average of M1 and M2<BR>' ...
            '  EOG|00FF00 : EOG        % Show EOG in green (RGB hexa)<BR>' ...
            '  Pz-alpha|8-12Hz : Pz    % Filter Pz signal at 8-12 Hz'];
        gui_component('label', jPanelText, BorderLayout.NORTH, ['<HTML><PRE>' strHelp '</PRE>']);
        % TEXT: Create text editor
        jTextMontage = JTextArea(6, 12);
        jTextMontage.setFont(Font('Monospaced', Font.PLAIN, fontSize));
        % Create scroll panel
        jScrollPanel = JScrollPane(jTextMontage);
        jPanelText.add(jScrollPanel, BorderLayout.CENTER);

        % === MATRIX EDITOR ===
        jPanelMatrix = gui_component('Panel');
        jPanelMatrix.setBorder(BorderFactory.createCompoundBorder(...
                             java_scaled('titledborder', 'Matrix viewer'), ...
                             BorderFactory.createEmptyBorder(10, 10, 10, 10)));
        % Create JTable
        jTableMatrix = JTable();
        jTableMatrix.setFont(bst_get('Font'));
        %jTableMatrix.setRowHeight(22);
        jTableMatrix.setEnabled(0);
        jTableMatrix.setAutoResizeMode( JTable.AUTO_RESIZE_OFF );
        jTableMatrix.getTableHeader.setReorderingAllowed(0);
        jTableMatrix.setPreferredScrollableViewportSize(java_scaled('dimension', 5,5));
        % Create scroll panel
        jScrollPanel = JScrollPane(jTableMatrix);
        jScrollPanel.setBorder([]);
        jPanelMatrix.add(jScrollPanel, BorderLayout.CENTER);          
        
    jPanelRight.setPreferredSize(java_scaled('dimension', 400,550));
    % PANEL: Selections buttons
    jPanelBottom = gui_component('Panel');
    jPanelBottomLeft = gui_river([10 0], [10 10 0 10]);
    jPanelBottomRight = gui_river([10 0], [10 10 0 10]);
        gui_component('button', jPanelBottomLeft, [], 'Help', [], [],  @(h,ev)web('https://neuroimage.usc.edu/brainstorm/Tutorials/MontageEditor', '-browser'));
        jButtonValidate = gui_component('button', jPanelBottomLeft,  [], 'Validate');
        jButtonValidate.setVisible(0);
        gui_component('button', jPanelBottomRight, [], 'Cancel', [], [], @(h,ev)ButtonCancel_Callback());
        jButtonSave = gui_component('button', jPanelBottomRight, [], 'Save');
    jPanelBottom.add(jPanelBottomLeft, BorderLayout.WEST);
    jPanelBottom.add(jPanelBottomRight, BorderLayout.EAST);
    jPanelRight.add(jPanelBottom, BorderLayout.SOUTH);
    jPanelNew.add(jPanelRight, BorderLayout.CENTER);
    % Create object to track modifications to the selected montage
    MontageModified = java.util.Vector();
    MontageModified.add('');
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jButtonAll',       jButtonAll, ...
                                  'jPanelRight',      jPanelRight, ...
                                  'jPanelSelection',  jPanelSelection, ...
                                  'jPanelText',       jPanelText, ...
                                  'jPanelMatrix',     jPanelMatrix, ...
                                  'jPanelViewer',     jPanelViewer, ...
                                  'jListMontages',    jListMontages, ...
                                  'jTextMontage',     jTextMontage, ...
                                  'jTableMatrix',     jTableMatrix, ...
                                  'jTextViewer',      jTextViewer, ...
                                  'jButtonNew',       jButtonNew, ...
                                  'jButtonLoadFile',  jButtonLoadFile, ...
                                  'jButtonSaveFile',  jButtonSaveFile, ...
                                  'jListSensors',     jListSensors, ...
                                  'jButtonValidate',  jButtonValidate, ...
                                  'jButtonSave',      jButtonSave, ...
                                  'jButtonShortcut',  jButtonShortcut, ...
                                  'MontageModified',  MontageModified));
              
                               

%% =================================================================================
%  === CONTROLS CALLBACKS  =========================================================
%  =================================================================================
%% ===== CANCEL BUTTONS =====
    function ButtonCancel_Callback(varargin)
        % Revert changes
        GlobalData.ChannelMontages = OldMontages;
        % Close panel without saving
        gui_hide(panelName);
    end
end

%% ===== SAVE BUTTON =====
function ButtonSave_Callback(hFig)
    % Save last modifications
    SaveModifications(hFig);
    % If a figure is selected
    if ~isempty(hFig)
        % Get panel controls handles
        ctrl = bst_get('PanelControls', 'EditMontages');
        if isempty(ctrl)
            return;
        end
        % Get last montage selected
        jMontage = ctrl.jListMontages.getSelectedValue();
        % Update changes (re-select the current montage)
        if ~isempty(jMontage)
            % Get selected montage in the interface
            MontageName = char(jMontage.getName());
            % Get figure montages
            sFigMontages = GetMontagesForFigure(hFig);
            % If the selected montage is a valid montage for the figure: set it as the current montage
            if any(strcmpi(MontageName, {sFigMontages.Name}))
                SetCurrentMontage(hFig, MontageName);
            end
        end
    end
    % Close panel
    gui_hide('EditMontages');
end


%% ===== JLIST: MONTAGE SELECTION CHANGE =====
function MontageChanged_Callback(ev, hFig)
    if ~ev.getValueIsAdjusting() && (length(ev.getSource().getSelectedValues()) <= 1)
        % Save previous modifications
        SaveModifications(hFig);
        % Update editor for new selected montage
        UpdateEditor(hFig);
    end
end

%% ===== JLIST: MOUSE CLICK =====
function MontageClick_Callback(ev, hFig)
    % If DOUBLE CLICK
    if (ev.getClickCount() == 2)
        % Rename selected montage
        ButtonRename_Callback(hFig);
    end
end

%% ===== JLIST: KEY TYPE =====
function MontageKeyTyped_Callback(ev, hFig)
    switch(uint8(ev.getKeyChar()))
        % DELETE
        case {ev.VK_DELETE, ev.VK_BACK_SPACE}
            ButtonDelete_Callback(hFig);
    end
end

%% ===== CHANNELS SELECTION CHANGED =====
function ChannelsChanged_Callback(hObj, ev)
    if ~ev.getValueIsAdjusting()
        % Get panel controls handles
        ctrl = bst_get('PanelControls', 'EditMontages');
        if isempty(ctrl)
            return;
        end
        % Cancel if there are multiple montages selected
        if (length(ctrl.jListMontages.getSelectedValues()) > 1)
            return;
        end
        % Get selected montage
        jMontage = ctrl.jListMontages.getSelectedValue();
        % Set as modified
        if ~isempty(jMontage)
            % Update changes (re-select the current montage)
            ctrl.MontageModified.set(0, jMontage.getName());
        else
            ctrl.MontageModified.set(0, '');
        end
    end
end
    
%% ===== EDITOR KEY TYPED =====
function EditorKeyTyped_Callback(hObj, ev)
    % Get panel controls handles
    ctrl = bst_get('PanelControls', 'EditMontages');
    if isempty(ctrl)
        return;
    end
    % Cancel if there are multiple montages selected
    if (length(ctrl.jListMontages.getSelectedValues()) > 1)
        return;
    end
    % Get selected montage
    jMontage = ctrl.jListMontages.getSelectedValue();
    % Set as modified
    if ~isempty(jMontage)
        % Update changes (re-select the current montage)
        ctrl.MontageModified.set(0, jMontage.getName());
    else
        ctrl.MontageModified.set(0, '');
    end
end



%% =================================================================================
%  === PANEL FUNCTIONS =============================================================
%  =================================================================================
    
%% ===== BUTTON: DELETE =====
function ButtonDelete_Callback(hFig)
	% Get selected montage
    sMontages = GetSelectedMontages(hFig);
    if isempty(sMontages)
        return
    end
    % Loop on all the selected montages
    for i = 1:length(sMontages)
        % Remove montage
        DeleteMontage(sMontages(i).Name);
    end
    % Update montages list
    UpdateMontagesList(hFig);
    % Update montage editor
    UpdateEditor(hFig);
end
    
%% ===== BUTTON: RENAME =====
function ButtonRename_Callback(hFig)
	% Get selected montage
    sMontage = GetSelectedMontage(hFig);
    if isempty(sMontage)
        return
    end
	% Rename montage
    newName = RenameMontage(sMontage.Name);
    % Update panel
    if ~isempty(newName)
        % Update montage list
        UpdateMontagesList(hFig, newName);
        % Update montage editor
        UpdateEditor(hFig);
    end
end
    
%% ===== BUTTON: DUPLICATE =====
function ButtonDuplicate_Callback(hFig)
	% Get selected montage
    sMontage = GetSelectedMontage(hFig);
    if isempty(sMontage)
        return
    end
	% Add again the same montage
    MontageName = SetMontage(sMontage.Name, sMontage, 0);
    % If a figure is passed in argument
    if ~isempty(MontageName)
        % Update montage list
        UpdateMontagesList(hFig, MontageName);
        % Update montage editor
        UpdateEditor(hFig);
    end
end

%% ===== BUTTON: LOAD FILE =====
function ButtonLoadFile_Callback(hFig)
	% Load file
    sNewMontage = LoadMontageFiles();
    % Update panel
    if ~isempty(sNewMontage)
        % If the montage is not part of this figure: switch to ALL
        if ~isempty(hFig)
            % Get figure montages
            sFigMontages = GetMontagesForFigure(hFig);
            % If last montage loaded is not part of the figure
            if ~any(strcmpi(sNewMontage(end).Name, {sFigMontages.Name}))
                % Get panel controls handles
                ctrl = bst_get('PanelControls', 'EditMontages');
                % Select ALL button
                if ~isempty(ctrl)
                    ctrl.jButtonAll.setSelected(1);
                end
            end
        end
        % Update montage list
        UpdateMontagesList(hFig, sNewMontage(end).Name);
        % Update montage editor
        UpdateEditor(hFig);
    end
end

%% ===== BUTTON: SAVE FILE =====
function ButtonSaveFile_Callback()
    % Get current montage
    sMontage = GetSelectedMontage();
    % Save file
    SaveMontageFile(sMontage);
end

%% ===== BUTTON: ALL =====
function ButtonAll_Callback(hFig)
    % Update montage list
    UpdateMontagesList(hFig);
    % Update montage editor
    UpdateEditor(hFig);
end

%% ===== BUTTON: SHORTCUT =====
function ButtonShortcut_Callback(hFig)
    % Get current montage
    sMontage = GetSelectedMontage();
    % Open up hotkey dialog
    [key, isCancel] = java_dialog('hotkey', []);
    % If a valid key was selected, update montage shortcut options
    if ~isCancel
        montageName = CleanMontageName(sMontage.Name);
        MontageOptions = bst_get('MontageOptions');
        for iShortcut = 1:25
            if strcmpi(montageName, MontageOptions.Shortcuts{iShortcut,2})
                MontageOptions.Shortcuts{iShortcut,2} = [];
            end
        end
        MontageOptions.Shortcuts{uint8(key) - uint8('a'), 2} = montageName;
        bst_set('MontageOptions', MontageOptions);
        % Update montage list
        UpdateMontagesList(hFig, sMontage.Name);
    end
end


%% ===== LOAD FIGURE =====
function LoadFigure(hFig)
    import org.brainstorm.list.*;
    global GlobalData;
    % Get panel controls handles
    ctrl = bst_get('PanelControls', 'EditMontages');
    % Find figure info
    [hFig,iFig,iDS] = bst_figures('GetFigure', hFig);
    % Update montage list
    UpdateMontagesList(hFig);
    % Remove JList callbacks
    java_setcb(ctrl.jListSensors, 'ValueChangedCallback', []);
    java_setcb(ctrl.jTextMontage, 'KeyTypedCallback', []);
    % Get channels displayed in this figure
    iChannels = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels;
    Channels = {GlobalData.DataSet(iDS).Channel(iChannels).Name};
    % Create a list with all the available selections
    listModel = javax.swing.DefaultListModel();
    for i = 1:length(Channels)
        listModel.addElement(BstListItem('', '', [Channels{i} '       '], i));
    end
    ctrl.jListSensors.setModel(listModel);
    % Update channel selection fot the first time
    UpdateEditor(hFig);
    % Set callbacks
    java_setcb(ctrl.jButtonAll,      'ActionPerformedCallback', @(h,ev)ButtonAll_Callback(hFig));
    java_setcb(ctrl.jListSensors,    'ValueChangedCallback',    @ChannelsChanged_Callback);
    java_setcb(ctrl.jTextMontage,    'KeyTypedCallback',        @EditorKeyTyped_Callback)
    java_setcb(ctrl.jButtonNew,      'ActionPerformedCallback', @(h,ev)CreateMontageMenu(ev.getSource(), hFig));
    java_setcb(ctrl.jButtonLoadFile, 'ActionPerformedCallback', @(h,ev)ButtonLoadFile_Callback(hFig));
    java_setcb(ctrl.jButtonSaveFile, 'ActionPerformedCallback', @(h,ev)ButtonSaveFile_Callback());
    java_setcb(ctrl.jButtonValidate, 'ActionPerformedCallback', @(h,ev)ValidateEditor(hFig));
    java_setcb(ctrl.jButtonSave,     'ActionPerformedCallback', @(h,ev)ButtonSave_Callback(hFig));
    java_setcb(ctrl.jButtonShortcut, 'ActionPerformedCallback', @(h,ev)ButtonShortcut_Callback(hFig));
end


%% ===== UPDATE MONTAGES LIST =====
function [sFigMontages, iFigMontages] = UpdateMontagesList(hFig, SelMontageName)
    import org.brainstorm.list.*;
    % Parse inputs
    if (nargin < 2) || isempty(SelMontageName)
        SelMontageName = [];
    end
    % Get panel controls handles
    ctrl = bst_get('PanelControls', 'EditMontages');
    % Remove JList callbacks
    java_setcb(ctrl.jListMontages, 'ValueChangedCallback', []);
    % Get available montages
    [sAllMontages, iAllMontages] = GetMontage([], hFig);
    if ~isempty(hFig)
        [sFigMontages, iFigMontages] = GetMontagesForFigure(hFig);
    else
        sFigMontages = sAllMontages;
        iFigMontages = iAllMontages;
    end
    % Displayed montages depend on the "ALL" button
    isAll = ctrl.jButtonAll.isSelected();
    if isAll
        iDispMontages = iAllMontages;
    else
        iDispMontages = iFigMontages;
    end
    % If the selected montage was not passed in argument: Get previously selected montage
    if isempty(SelMontageName)
        prevSel = ctrl.jListMontages.getSelectedValue();
        if ~isempty(prevSel) && ~ischar(prevSel)          
            SelMontageName = prevSel.getType();
        end
    end
    % No previously selected montage: Get the selected montage from the current figure
    if isempty(SelMontageName)
        sMontage = GetCurrentMontage(hFig);
        if ~isempty(sMontage)
            SelMontageName = sMontage.Name;
        end
    end
    % Create a list with all the available montages
    listModel = javax.swing.DefaultListModel();
    MontageOptions = bst_get('MontageOptions');
    for i = 1:length(iDispMontages)
        iMontage = iDispMontages(i);
        if ~isAll || ismember(iMontage, iFigMontages)
            strMontage = sAllMontages(iMontage).Name;
        else
            strMontage = ['[' sAllMontages(iMontage).Name ']'];
        end
        % Look for shortcut
        shortcut = [];
        for iShortcut = 1:25
            if strcmpi(CleanMontageName(sAllMontages(iMontage).Name), MontageOptions.Shortcuts{iShortcut,2})
                shortcut = ['Shift+' upper(MontageOptions.Shortcuts{iShortcut,1})];
                break;
            end
        end
        listModel.addElement(BstListItem(shortcut, '', strMontage, iMontage));
    end
    ctrl.jListMontages.setModel(listModel);
    % Look for selected montage index in the list of displayed montages
    if isempty(sFigMontages)
        iCurSel = 0;
    elseif ~isempty(SelMontageName)
        if isAll
            iCurSel = find(strcmpi({sAllMontages.Name}, SelMontageName));
        else
            iCurSel = find(strcmpi({sFigMontages.Name}, SelMontageName));
        end
        if isempty(iCurSel)
            iCurSel = 1;
        end
    else
        iCurSel = 1;
    end
    % Select one item
    ctrl.jListMontages.setSelectedIndex(iCurSel - 1);
    % Scroll to see the selected scout in the list
    if ~isequal(iCurSel, 0)
        selRect = ctrl.jListMontages.getCellBounds(iCurSel-1, iCurSel-1);
        ctrl.jListMontages.scrollRectToVisible(selRect);
        ctrl.jListMontages.repaint();
    end
    % Set callbacks
    java_setcb(ctrl.jListMontages, 'ValueChangedCallback', @(h,ev)MontageChanged_Callback(ev,hFig), ...
                                   'KeyTypedCallback',     @(h,ev)MontageKeyTyped_Callback(ev,hFig), ...
                                   'MouseClickedCallback', @(h,ev)MontageClick_Callback(ev,hFig));
end


%% ===== GET SELECTED MONTAGE =====
function [sMontage, iMontage] = GetSelectedMontage(hFig)
    % Parse inputs
    if (nargin < 1) || isempty(hFig)
        hFig = [];
    end
    % Get panel controls handles
    ctrl = bst_get('PanelControls', 'EditMontages');
    % Get all montages
    sMontages = GetMontage([], hFig);
    % Get the index of the montage
    jMontage = ctrl.jListMontages.getSelectedValue();
    % Get the target montage
    if ~isempty(jMontage)
        iMontage = jMontage.getUserData();
        sMontage = sMontages(iMontage);
    else
        sMontage = [];
        iMontage = [];
    end
end


%% ===== GET SELECTED MONTAGES (MULTIPLE SELECTION ALLOWED) =====
function [sMontages, iMontages] = GetSelectedMontages(hFig)
    % Parse inputs
    if (nargin < 1) || isempty(hFig)
        hFig = [];
    end
    % Get panel controls handles
    ctrl = bst_get('PanelControls', 'EditMontages');
    % Get all montages
    sAllMontages = GetMontage([], hFig);
    % Get the index of the montage
    jMontages = ctrl.jListMontages.getSelectedValues();
    % Get the target montage
    if ~isempty(jMontages)
        for i = 1:length(jMontages)
            iMontages(i) = jMontages(i).getUserData();
            sMontages(i) = sAllMontages(iMontages(i));
        end
    else
        sMontages = [];
        iMontages = [];
    end
end


%% ===== UPDATE MONTAGE =====
function UpdateEditor(hFig)
    global GlobalData;
    % Get panel controls handles
    ctrl = bst_get('PanelControls', 'EditMontages');
    % Get montages for this figure
    [sMontage, iMontage] = GetSelectedMontage(hFig);
    % If nothing selected: unselect all channels and return
    if isempty(sMontage)
        ctrl.jListSensors.setSelectedIndex(-1);
        return;
    end
    % Progress bar
    bst_progress('start', 'Montage editor', 'Loading selected montage...');
    % Get the montages for the current figure
    if ~isempty(hFig)
        [sFigMontages, iFigMontages] = GetMontagesForFigure(hFig);
        isFigMontage = ismember(iMontage, iFigMontages);
    else
        [sFigMontages, iFigMontages] = GetMontage([], hFig);
        isFigMontage = 0;
    end
    % Remove all the previous panels
    ctrl.jPanelRight.remove(ctrl.jPanelSelection);
    ctrl.jPanelRight.remove(ctrl.jPanelText);
    ctrl.jPanelRight.remove(ctrl.jPanelMatrix);
    ctrl.jPanelRight.remove(ctrl.jPanelViewer);
    
    % === TEXT VIEWER: CHANNEL LISTS ===
    if strcmpi(sMontage.Name, 'Bad channels') || (strcmpi(sMontage.Type, 'selection') && ~isFigMontage)
        % Make selection panel visible
        ctrl.jButtonValidate.setVisible(0);
        ctrl.jPanelRight.add(ctrl.jPanelViewer, java.awt.BorderLayout.CENTER);
        % Build a string to represent the channels list
        strChan = '';
        for iChan = 1:length(sMontage.ChanNames)
            if (mod(iChan-1,5) == 0) && (iChan ~= 1)
                strChan = [strChan, 10];
            end
            strChan = [strChan, ' ' sMontage.ChanNames{iChan}];
            if (iChan ~= length(sMontage.ChanNames))
                strChan = [strChan, ','];
            end
        end
        ctrl.jTextViewer.setText(strChan);
        
    % === SELECTION EDITOR ===
    elseif strcmpi(sMontage.Type, 'selection')
        % Make selection panel visible
        ctrl.jButtonValidate.setVisible(0);
        ctrl.jPanelRight.add(ctrl.jPanelSelection, java.awt.BorderLayout.CENTER);
        % Remove JList callbacks
        java_setcb(ctrl.jListSensors, 'ValueChangedCallback', []);
        % Find figure info
        [hFig,iFig,iDS] = bst_figures('GetFigure', hFig);
        % Get channels displayed in this figure
        iChannels = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels;
        Channels = {GlobalData.DataSet(iDS).Channel(iChannels).Name};
        % Remove all the spaces in channels names
        Channels     = cellfun(@(c)c(c~=' '), Channels, 'UniformOutput', 0);
        MontageNames = cellfun(@(c)c(c~=' '), sMontage.ChanNames, 'UniformOutput', 0);
        % Build the list of elements to select in sensors list
        iSelChan = [];
        for i = 1:length(MontageNames)
            iTmp = find(strcmpi(Channels, MontageNames{i}));
            if ~isempty(iTmp)
                iSelChan = [iSelChan, iTmp];
            end
        end
        % Select channels
        if isempty(iSelChan)
            iSelChan = 0;
        end
        ctrl.jListSensors.setSelectedIndices(iSelChan - 1);
        % Restore JList callbacks
        java_setcb(ctrl.jListSensors, 'ValueChangedCallback', @ChannelsChanged_Callback);
        
    % === TEXT EDITOR ===
    elseif strcmpi(sMontage.Type, 'text')
        % Make editor panel visible
        ctrl.jButtonValidate.setVisible(1);
        ctrl.jPanelRight.add(ctrl.jPanelText, java.awt.BorderLayout.CENTER);
        % Set the text corresponding to the montage
        strEdit = out_montage_mon([], sMontage);
        iFirstCr = find(strEdit == 10, 1);
        ctrl.jTextMontage.setText(strEdit(iFirstCr+1:end));
        
    % === MATRIX VIEWER ===
    elseif ismember(sMontage.Type, {'custom', 'matrix'}) && ~isempty(sMontage.Matrix)
        % Make editor panel visible
        ctrl.jButtonValidate.setVisible(0);
        ctrl.jPanelRight.add(ctrl.jPanelMatrix, java.awt.BorderLayout.CENTER);
        % Create table model
        model = javax.swing.table.DefaultTableModel(size(sMontage.Matrix,1)+1, size(sMontage.Matrix,2)+1);
        for iDisp = 1:size(sMontage.Matrix,1)
            row = cell(1, size(sMontage.Matrix,2)+1);
            row{1} = sMontage.DispNames{iDisp};
            for iChan = 1:size(sMontage.Matrix,2)
                % row{iChan+1} = num2str(sMontage.Matrix(iDisp,iChan));
                if (sMontage.Matrix(iDisp,iChan) == 0)
                    row{iChan+1} = '0';
                elseif (sMontage.Matrix(iDisp,iChan) == 1)
                    row{iChan+1} = '1';
                else
                    row{iChan+1} = sprintf('%1.3f', sMontage.Matrix(iDisp,iChan));
                end
            end
            model.insertRow(iDisp-1, row);
        end
        ctrl.jTableMatrix.setModel(model);
        % Resize all the columns
        for iCol = 0:size(sMontage.Matrix,2)
            ctrl.jTableMatrix.getColumnModel().getColumn(iCol).setPreferredWidth(50);
            if (iCol > 0)
                ctrl.jTableMatrix.getColumnModel().getColumn(iCol).setHeaderValue(sMontage.ChanNames{iCol});
            else
                ctrl.jTableMatrix.getColumnModel().getColumn(iCol).setHeaderValue(' ');
            end
        end
        
    % === ERROR ===
    else
        % Make selection panel visible
        ctrl.jButtonValidate.setVisible(0);
        ctrl.jPanelRight.add(ctrl.jPanelViewer, java.awt.BorderLayout.CENTER);
        % Display error message
        ctrl.jTextViewer.setText('This montage cannot be loaded for this dataset.');
    end
    % Force update of the display
    ctrl.jPanelRight.revalidate();
    ctrl.jPanelRight.repaint();
    % Close progress bar
    bst_progress('stop');
end

%% ===== VALIDATE EDITOR CONTENTS =====
function ValidateEditor(hFig)
    % Get panel controls handles
    ctrl = bst_get('PanelControls', 'EditMontages');
    % Convert text in editor to montage structure
    strText = char(ctrl.jTextMontage.getText());
    strText = ['Validate', 10, strText];
    [sMontage, errMsg] = in_montage_mon(strText);
    % Set the text corresponding to the montage
    strEdit = out_montage_mon([], sMontage);
    iFirstCr = find(strEdit == 10, 1);
    ctrl.jTextMontage.setText(strEdit(iFirstCr+1:end));
    % Display error messages
    if ~isempty(errMsg)
        bst_error(errMsg, 'Validate montage', 0);
    end
    % Change figure selection: save modifications
    if ~isempty(hFig)
        SaveModifications(hFig);
    end
end


%% ===== SAVE MODIFICATIONS =====
function SaveModifications(hFig)
    % Parse inputs
    if (nargin < 1) || isempty(hFig)
        hFig = [];
    end
    % Get panel controls handles
    ctrl = bst_get('PanelControls', 'EditMontages');
    % Check if there were modifications
    MontageName = ctrl.MontageModified.get(0);
    if isempty(MontageName)
        return;
    end
    % Remove the possible "[]" if the user is editing a hidden montage
    if ((MontageName(1) == '[') && (MontageName(end) == ']'))
        MontageName = MontageName(2:end-1);
    end
    % Reset the modification
    ctrl.MontageModified.set(0, '');
    % Get montage structure
    sMontage = GetMontage(MontageName, hFig);
    % Channel selection
    if strcmpi(sMontage.Type, 'selection')
        % Get selected channels
        selChans = ctrl.jListSensors.getSelectedValues();
        % Build list of channels for updated setup
        ChanNames = cell(1,length(selChans));
        for i = 1:length(selChans)
            % Get directly the name of the channel (and remove the trailing spaces added for display)
            chName = char(selChans(i).getName());
            ChanNames{i} = chName(1:end-7);
        end
        % Update montage
        sMontage.ChanNames = ChanNames;
        sMontage.DispNames = ChanNames;
        sMontage.Matrix = eye(length(ChanNames));
    % Text editor
    elseif strcmpi(sMontage.Type, 'text')
        % Get text from the editor
        strText = char(ctrl.jTextMontage.getText());
        % Add montage name
        strText = [sMontage.Name, 10, strText];
        % Convert to montage structure
        sMontage = in_montage_mon(strText);
    end
    % Save updated montage
    SetMontage(MontageName, sMontage);
end


%% ===== EDIT SELECTIONS =====
% USAGE:  EditMontages(hFig)
%         EditMontages()
function EditMontages(hFig)
    % No specific figure
    if (nargin < 1)
        hFig = [];
    end
    % Display edition panel
    gui_show('panel_montage', 'JavaWindow', 'Montage editor', [], 0, 1, 0);
    % Load montages for figure
    LoadFigure(hFig);
end

%% ===== NEW MONTAGE =====
function newName = NewMontage(MontageType, ChanNames, hFig)
    global GlobalData;
    % Parse inputs
    if (nargin < 3) || isempty(hFig)
        hFig = [];
    end
    % Display warning: Use projector to reference the recordings
    if strcmpi(MontageType, 'ref') || strcmpi(MontageType, 'linkref')
        java_dialog('warning', ['Re-referencing the EEG with a montage will only affect the display ' 10 ...
                                'of the signals but will not be considered when processing them.' 10 10 ...
                                'To change the reference permanently, consider using a projector instead:' 10 ...
                                ' - In the Record tab, menu "Artifacts > Re-reference EEG"' 10 ...
                                ' - Process "Standardize > Re-reference EEG"'], 'Re-referencing montage');
    end
    % Ask user the name for the new montage
    newName = java_dialog('input', 'New montage name:', 'New montage');
    if isempty(newName)
        return;
    elseif ~isempty(GetMontage(newName, hFig))
        bst_error('This montage name already exists.', 'New montage', 0);
        newName = [];
        return
    end
    % Make sure Channels is a cell list of strings
    if isempty(ChanNames) || ~iscell(ChanNames)
        ChanNames = {};
    end
    % Re-referecing montage
    if strcmpi(MontageType, 'ref') || strcmpi(MontageType, 'linkref')
        % Find figure info
        [hFig,iFig,iDS] = bst_figures('GetFigure', hFig);
        % Get channels displayed in this figure
        iChannels = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels;
        ChanNames = {GlobalData.DataSet(iDS).Channel.Name};
        % Remove all the spaces in channels names
        ChanNames = cellfun(@(c)c(c~=' '), ChanNames, 'UniformOutput', 0);
        % Ask the user what channel to use as a reference
        refChan1 = java_dialog('combo', '<HTML>Select the reference channel:<BR><BR>', 'New re-referencing montage', [], ChanNames);
        if isempty(refChan1)
            return
        end
        % Ask the user a second/linked reference
        if strcmpi(MontageType, 'linkref')
            refChan2 = java_dialog('combo', '<HTML>Select the linked reference channel:<BR><BR>', 'New re-referencing montage', [], ChanNames);
            if isempty(refChan2)
                return
            end
        else
            refChan2 = '';
        end
        % Get channel index
        iRef = find(strcmpi(refChan1, ChanNames) | strcmpi(refChan2, ChanNames));
        iChannelsDisp = setdiff(iChannels, iRef);
        iChannelsRef  = unique([iChannels, iRef]);
        % Create a bi-polar montage: 1 on the diagonal and -1 for the reference
        MontageMatrix = eye(length(ChanNames), length(ChanNames));
        MontageMatrix(:,iRef) = -1 ./ length(iRef);
        % Remove all the unecessary rows/columns
        iAll = 1:length(ChanNames);
        MontageMatrix(setdiff(iAll,iChannelsDisp), :) = [];
        MontageMatrix(:, setdiff(iAll,iChannelsRef)) = [];
        % Channel names
        DispNames = ChanNames(iChannelsDisp);
        ChanNames = ChanNames(iChannelsRef);
        % Real montage type: text
        MontageType = 'text';
    else
        % Identity matrix
        MontageMatrix = eye(length(ChanNames));
        DispNames = ChanNames;
    end
    % Create new montage structure
    sMontage = db_template('Montage');
    sMontage.Name      = newName;
    sMontage.Type      = MontageType;
    sMontage.ChanNames = ChanNames;
    sMontage.DispNames = DispNames;
    sMontage.Matrix    = MontageMatrix;
    % Save new montage
    SetMontage(newName, sMontage);
    % Update panel
    if ~isempty(hFig)
        % Get panel controls handles
        ctrl = bst_get('PanelControls', 'EditMontages');
        % If the panel is available: update it
        if ~isempty(ctrl)
            % Update montages list
            UpdateMontagesList(hFig);
            % Select last element in list
            iNewInd = ctrl.jListMontages.getModel().getSize() - 1;
            ctrl.jListMontages.setSelectedIndex(iNewInd);
            % Update channels selection
            UpdateEditor(hFig);
        end
        % Reset selection
        bst_figures('SetSelectedRows', []);
    end
end


%% =================================================================================
%  === CORE FUNCTIONS ==============================================================
%  =================================================================================

%% ===== LOAD DEFAULT MONTAGES ======
function LoadDefaultMontages() %#ok<DEFNU>
    % Set average reference montage
    sMontage = db_template('Montage');
    sMontage.Name = 'Average reference';
    sMontage.Type = 'matrix';
    SetMontage(sMontage.Name, sMontage);
    % Set average reference montage (sorted Left>Right)
    sMontage = db_template('Montage');
    sMontage.Name = 'Average reference (L -> R)';
    sMontage.Type = 'matrix';
    SetMontage(sMontage.Name, sMontage);
    % Set scalp current density montage
    sMontage = db_template('Montage');
    sMontage.Name = 'Scalp current density';
    sMontage.Type = 'matrix';
    SetMontage(sMontage.Name, sMontage);
    % Set scalp current density montage (sorted Left>Right)
    sMontage = db_template('Montage');
    sMontage.Name = 'Scalp current density (L -> R)';
    sMontage.Type = 'matrix';
    SetMontage(sMontage.Name, sMontage);
    % Set HLU distance montage
    sMontage = db_template('Montage');
    sMontage.Name = 'Head distance';
    sMontage.Type = 'custom';
    SetMontage(sMontage.Name, sMontage);
    % Set bad channels montage
    sMontage = db_template('Montage');
    sMontage.Name = 'Bad channels';
    sMontage.Type = 'selection';
    SetMontage(sMontage.Name, sMontage);
    % Get the path to the default .sel/.mon files
    MontagePath = bst_fullfile(bst_fileparts(which('panel_channel_editor')), 'private');    
    % Load MNE selection files
    MontageFiles = dir(bst_fullfile(MontagePath, '*.sel'));
    for i = 1:length(MontageFiles)
        LoadMontageFiles(bst_fullfile(MontagePath, MontageFiles(i).name), 'MNE', 1);
    end
    % Load Brainstorm EEG montage files
    MontageFiles = dir(bst_fullfile(MontagePath, '*.mon'));
    for i = 1:length(MontageFiles)
        LoadMontageFiles(bst_fullfile(MontagePath, MontageFiles(i).name), 'MON', 1);
    end
end
   

%% ===== GET MONTAGE ======
function [sMontage, iMontage] = GetMontage(MontageName, hFig)
    global GlobalData;
    % Parse inputs
    if (nargin < 2) || isempty(hFig)
        hFig = [];
    end
    % If no montage defined
    if isempty(GlobalData.ChannelMontages.Montages)
        sMontage = [];
        iMontage = [];
    % Else: Look for required montage in loaded list
    else
        % Find montage in valid list of montages
        if ~isempty(MontageName)
            iMontage = find(strcmpi({GlobalData.ChannelMontages.Montages.Name}, MontageName));
        else
            iMontage = 1:length(GlobalData.ChannelMontages.Montages);
        end
        % If montage is found
        if ~isempty(iMontage)
            sMontage = GlobalData.ChannelMontages.Montages(iMontage);
            % Find average reference montage
            iAvgRef = find(strcmpi({sMontage.Name}, 'Average reference'));
            if ~isempty(iAvgRef) && ~isempty(hFig)
                sTmp = GetMontageAvgRef(sMontage(iAvgRef), hFig, [], 0);    % Global average reference 
                if ~isempty(sTmp)
                    sMontage(iAvgRef) = sTmp;
                end
            end
            iAvgRef = find(strcmpi({sMontage.Name}, 'Average reference (L -> R)'));
            if ~isempty(iAvgRef) && ~isempty(hFig)
                sTmp = GetMontageAvgRef(sMontage(iAvgRef), hFig, [], 0);  % Global average reference sorted L -> R
                if ~isempty(sTmp)
                    sMontage(iAvgRef) = sTmp;
                end
            end
            % Find Scalp current density montage
            iScd = find(strcmpi({sMontage.Name}, 'Scalp current density'));
            if ~isempty(iScd) && ~isempty(hFig)
                sTmp = GetMontageScd(sMontage(iScd), hFig, []);
                if ~isempty(sTmp)
                    sMontage(iScd) = sTmp;
                end
            end
            iScd = find(strcmpi({sMontage.Name}, 'Scalp current density (L -> R)'));  % Sorted L -> R
            if ~isempty(iScd) && ~isempty(hFig)
                sTmp = GetMontageScd(sMontage(iScd), hFig, []);
                if ~isempty(sTmp)
                    sMontage(iScd) = sTmp;
                end
            end
            % Find head motion distance montage
            iHeadDist = find(strcmpi({sMontage.Name}, 'Head distance'));
            if ~isempty(iHeadDist) && ~isempty(hFig)
                sTmp = GetMontageHeadDistance(sMontage(iHeadDist), hFig, []);  % Head motion distance
                if ~isempty(sTmp)
                    sMontage(iHeadDist) = sTmp;
                end
            end
            % Find local average reference montages
            iLocalAvgRef = find(~cellfun(@(c)isempty(strfind(c, '(local average ref)')), {sMontage.Name}));
            if ~isempty(iLocalAvgRef) && ~isempty(hFig)
                for i = 1:length(iLocalAvgRef)
                    sTmp = GetMontageAvgRef(sMontage(iLocalAvgRef(i)), hFig, [], 1);    % Local average reference 
                    if ~isempty(sTmp)
                        sMontage(iLocalAvgRef(i)) = sTmp;
                    end
                end
            end
            % Find average reference montage
            iBadChan = find(strcmpi({sMontage.Name}, 'Bad channels'));
            if ~isempty(iBadChan) && ~isempty(hFig)
                sTmp = GetMontageBadChan(hFig);
                if ~isempty(sTmp)
                    sMontage(iBadChan) = sTmp;
                end
            end
        else
            sMontage = [];
        end
    end
end

%% ===== SET MONTAGE ======
% USAGE:  SetMontage(MontageName, ChanNames, isOverwrite=1)
%         SetMontage(MontageName, sMontage, isOverwrite=1)
function MontageName = SetMontage(MontageName, sMontage, isOverwrite)
    global GlobalData;
    % Parse inputs
    if (nargin < 3) || isempty(isOverwrite)
        isOverwrite = 1;
    end
    % Input is a list of channel names
    if iscell(sMontage)
        ChanNames = sMontage;
        % Remove all the spaces in channels names
        ChanNames = cellfun(@(c)c(c~=' '), ChanNames, 'UniformOutput', 0);
        % Create new structure
        sMontage = db_template('Montage');
        sMontage.Name      = MontageName;
        sMontage.Type      = 'selection';
        sMontage.ChanNames = ChanNames;
        sMontage.DispNames = ChanNames;
        sMontage.Matrix    = eye(length(ChanNames));
    end
    % If list of montages is still empty
    if isempty(GlobalData.ChannelMontages.Montages)
        GlobalData.ChannelMontages.Montages = sMontage;
    else
        % Try to get an existing montage
        [tmp__, iMontage] = GetMontage(MontageName);
        % If montage already exists, but we don't want to overwrite it: create a unique name
        if ~isempty(iMontage) && ~isOverwrite
            MontageName = file_unique(MontageName, {GlobalData.ChannelMontages.Montages.Name});
            sMontage.Name = MontageName;
            iMontage = [];
        end
        % If no existing montage, append new montage at the end of the list
        if isempty(iMontage)
            iMontage = length(GlobalData.ChannelMontages.Montages) + 1;
        end
        % Save montage
        GlobalData.ChannelMontages.Montages(iMontage) = sMontage;
    end
end

%% ===== GET CURRENT MONTAGE ======
% USAGE:  sMontage = GetCurrentMontage(hFig)
%         sMontage = GetCurrentMontage(Modality)
function sMontage = GetCurrentMontage(hFig)
    global GlobalData;
    sMontage = [];
    % Get modality
    if (nargin < 1) || isempty(hFig)
        disp('BST> Error: Invalid call to GetCurrentMontage()');
        return;
    elseif ischar(hFig)
        Modality = hFig;
        hFig = [];
    else
        % Get modality
        TsInfo = getappdata(hFig, 'TsInfo');
        if isempty(TsInfo) || isempty(TsInfo.Modality)
            disp('BST> Error: Invalid figure for GetCurrentMontage()');
            return;
        end
        Modality = TsInfo.Modality;
        % Topo: different category
        TopoInfo = getappdata(hFig, 'TopoInfo');
        if ~isempty(TopoInfo)
            Modality = ['topo_' Modality];
        end
    end
    % Storage field 
    FieldName = ['mod_' lower(file_standardize(Modality))];
    % Check that this category exists
    if ~isfield(GlobalData.ChannelMontages.CurrentMontage, FieldName)
        % disp(['BST> Error: Invalid modality "' Modality '"']);
        return;
    end
    % Get current montage name
    MontageName = GlobalData.ChannelMontages.CurrentMontage.(FieldName);
    % Get current montage definition
    if ~isempty(MontageName)
        sMontage = GetMontage(MontageName, hFig);
    end
end

%% ===== DELETE MONTAGE =====
function DeleteMontage(MontageName)
    global GlobalData;
    % Get montage index
    [sMontage, iMontage] = GetMontage(MontageName);
    if isempty(sMontage)
        disp(['BST> Error: Montage "' MontageName '" was not found.']);
        return;
    elseif (length(sMontage) >= 2)
        disp(['BST> Error: Mulitple montages "' MontageName '" were found. Deleting only the first one.']);
        sMontage = sMontage(1);
        iMontage = iMontage(1);
    end
    % If this is a non-editable montage: error
    if ismember(sMontage.Name, {'Bad channels', 'Average reference', 'Average reference (L -> R)', 'Scalp current density', 'Scalp current density (L -> R)', 'Head distance'})
        return;
    end    
    % Remove montage if it exists
    if ~isempty(iMontage)
        GlobalData.ChannelMontages.Montages(iMontage) = [];
    end
    % Check if is the current montage
    for structField = fieldnames(GlobalData.ChannelMontages.CurrentMontage)'
        if strcmpi(GlobalData.ChannelMontages.CurrentMontage.(structField{1}), sMontage.Name)
            GlobalData.ChannelMontages.CurrentMontage.(structField{1}) = sMontage.Name;
        end
    end
end

%% ===== GET MONTAGES FOR FIGURE =====
function [sMontage, iMontage] = GetMontagesForFigure(hFig)
    global GlobalData;
    sMontage = [];
    iMontage = [];
    % If no available montages: return
    if isempty(GlobalData.ChannelMontages.Montages)
        return
    end
    % If menu is designed to fit a specific figure: get only the ones that fits to this figure
    if ~isempty(hFig)
        % Get figure description
        [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
        % Check that this figure can handle montages
        if isempty(GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels) || isempty(GlobalData.DataSet(iDS).Channel) || isempty(GlobalData.DataSet(iDS).Measures.ChannelFlag)
            return;
        end
        % Get channels displayed in this figure
        iFigChannels = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels;
        FigChannels = {GlobalData.DataSet(iDS).Channel(iFigChannels).Name};
        AllChannels = {GlobalData.DataSet(iDS).Channel.Name};
        FigId = GlobalData.DataSet(iDS).Figure(iFig).Id;
        isStat = strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'stat');
        % Remove all the spaces
        FigChannels = cellfun(@(c)c(c~=' '), FigChannels, 'UniformOutput', 0);
        AllChannels = cellfun(@(c)c(c~=' '), AllChannels, 'UniformOutput', 0);
        % Get the predefined montages that match this list of channels
        iMontage = [];
        for i = 1:length(GlobalData.ChannelMontages.Montages)
            % Topography figures
            if strcmpi(FigId.Type, 'Topography')
                % 2DLayout: Accept all types of montages
                if isequal(FigId.SubType, '2DLayout')
                    % Accept
                % Skip "selection" montage types (except for NIRS)
                elseif strcmpi(GlobalData.ChannelMontages.Montages(i).Type, 'selection') && ~isequal(FigId.Modality, 'NIRS')
                    continue;
                % Skip "overlay NIRS" montage for topography
                elseif ismember(GlobalData.ChannelMontages.Montages(i).Name, {'NIRS overlay[tmp]', 'Bad channels'})
                    continue;
                % Selection: Skip if not defining a re-referencial montage (avg ref for instance)
                elseif strcmpi(GlobalData.ChannelMontages.Montages(i).Type, 'text') && ...
                        (~all(sum(GlobalData.ChannelMontages.Montages(i).Matrix,2) == 0) || ~all(ismember(FigChannels, GlobalData.ChannelMontages.Montages(i).DispNames)))
                    continue;
                end
            end
            % Stat figures: Skip "text" and "matrix" montage types
            if isStat && ~strcmpi(GlobalData.ChannelMontages.Montages(i).Type, 'selection')
                continue;
            end
            % Not EEG: Skip average reference
            if strcmpi(GlobalData.ChannelMontages.Montages(i).Name, 'Average reference') && ~isempty(FigId.Modality) && ~ismember(FigId.Modality, {'EEG','SEEG','ECOG','ECOG+SEEG'})
                continue;
            end
            % Not 10-20 EEG: Skip average reference L -> R (only available for recordings figures)
            if ismember(GlobalData.ChannelMontages.Montages(i).Name, {'Average reference (L -> R)', 'Scalp current density (L -> R)'}) && (~strcmpi(FigId.Type, 'DataTimeSeries') || (~isempty(FigId.Modality) && ~ismember(FigId.Modality, {'EEG','SEEG','ECOG','ECOG+SEEG'})) || ~Is1020Setup(FigChannels))
                continue;
            end
            % Not EEG or no 3D positions: Skip scalp current density
            if ismember(GlobalData.ChannelMontages.Montages(i).Name, {'Scalp current density', 'Scalp current density (L -> R)'}) && ~isempty(FigId.Modality) && (~ismember(FigId.Modality, {'EEG'}) || any(cellfun(@isempty, {GlobalData.DataSet(iDS).Channel(iFigChannels).Loc})))
                continue;
            end
            % Not CTF-MEG: Skip head motion distance
            if strcmpi(GlobalData.ChannelMontages.Montages(i).Name, 'Head distance') && ((~isempty(FigId.Modality) && ~ismember(FigId.Modality, {'MEG', 'HLU'})) ...
                    || ((isfield(GlobalData.DataSet(iDS).Measures.sFile, 'device') && ~strcmpi(GlobalData.DataSet(iDS).Measures.sFile.device, 'CTF')) ...
                    && isempty(strfind(GlobalData.DataSet(iDS).ChannelFile, 'channel_ctf'))))
                continue;
            end
            % Local average reference: Only available for current modality
            if ~isempty(strfind(GlobalData.ChannelMontages.Montages(i).Name, 'SEEG (local average ref)')) && ~ismember(FigId.Modality, {'SEEG','ECOG+SEEG'})
                continue;
            elseif ~isempty(strfind(GlobalData.ChannelMontages.Montages(i).Name, 'ECOG (local average ref)')) && ~ismember(FigId.Modality, {'ECOG','ECOG+SEEG'})
                continue;
            end
            % No bad channels: Skip the bad channels montage
            isBadMontage = strcmpi(GlobalData.ChannelMontages.Montages(i).Name, 'Bad channels');
            if isBadMontage && ~any(GlobalData.DataSet(iDS).Measures.ChannelFlag == -1)
                continue;
            end
            % Skip montages that have no common channels with the current figure (remove all the white spaces in the channel names)
            curSelChannels = GlobalData.ChannelMontages.Montages(i).ChanNames;
            curSelChannels = cellfun(@(c)c(c~=' '), curSelChannels, 'UniformOutput', 0);
            if ~isBadMontage && ~isempty(curSelChannels) && (length(intersect(curSelChannels, AllChannels)) < 0.3 * length(curSelChannels))    % We need at least 30% of the montage channels
                continue;
            end
            % Remove the re-referencing montages when the reference is not available
            if ~isBadMontage && strcmpi(GlobalData.ChannelMontages.Montages(i).Type, 'text')
                iRef = find(sum(GlobalData.ChannelMontages.Montages(i).Matrix ~= 0) > 0.7 * length(GlobalData.ChannelMontages.Montages(i).DispNames));
                % Check across all channels if the references can be found
                if ~all(ismember(curSelChannels(iRef), {GlobalData.DataSet(iDS).Channel.Name}))
                    continue;
                end
            end
            % Add montage
            iMontage(end+1) = i;
        end
    % Else: get all the montages
    else
        iMontage = 1:length(GlobalData.ChannelMontages.Montages);
    end
    % Return montages
    sMontage = GlobalData.ChannelMontages.Montages(iMontage);
end

%% ===== GET MONTAGE CHANNELS =====
% Find a list of channels in a target montage
% USAGE:  [iChannels, iMatrixChan, iMatrixDisp] = GetMontageChannels(sMontage, ChanNames, ChannelFlag=[])
function [iChannels, iMatrixChan, iMatrixDisp] = GetMontageChannels(sMontage, ChanNames, ChannelFlag) %#ok<DEFNU>
    % Initialize returned variables
    iChannels = [];
    iMatrixChan = [];
    iMatrixDisp = [];
    % Channel flags not provided
    if (nargin < 3) || isempty(ChannelFlag)
        ChannelFlag = [];
    end
    % No montage: no selection
    if isempty(sMontage)
        return;
    end
    % Get target channels in this montage
    if ~isempty(sMontage) && ~isempty(sMontage.ChanNames)
        % Remove all the spaces
        sMontage.ChanNames = cellfun(@(c)c(c~=' '), sMontage.ChanNames, 'UniformOutput', 0);
        ChanNames          = cellfun(@(c)c(c~=' '), ChanNames,          'UniformOutput', 0);
        % Look for each of these selected channels in the list of loaded channels
        for i = 1:length(sMontage.ChanNames)
            % Skip empty channel name
            if isempty(sMontage.ChanNames{i})
                continue;
            end
            % Look for for the montage channel names in the channel file
            iTmp = find(strcmpi(sMontage.ChanNames{i}, ChanNames));
            % We may have some duplicates here, if there are both "C 4" and "c4" in the same file: use only the first one
            if (length(iTmp) > 1)
                iTmp = iTmp(1);
            % If channel was not found: skip
            elseif isempty(iTmp)
                continue;
            end
            % Skip bad channel
            if ~isempty(ChannelFlag) && (ChannelFlag(iTmp) == -1) && ~isequal(sMontage.Name, 'Bad channels')
                continue;
            end
            % Good channel was found: Add it to the display list
            iChannels(end+1) = iTmp;
            iMatrixChan(end+1) = i;
        end
        % Get the display rows that we can display with these input channels
        if ~isempty(iChannels)
            sumDisp = sum(sMontage.Matrix(:,iMatrixChan) ~= 0, 2);
            sumTotal = sum(sMontage.Matrix ~= 0,2);
            iMatrixDisp = find((sumDisp == sumTotal) | (sumDisp >= 4));
        end
    end
end

%% ===== GET AVERAGE REF MONTAGE =====
% USAGE:  sMontage = GetMontageAvgRef(sMontage, hFig)
%         sMontage = GetMontageAvgRef(sMontage, Channels, ChannelFlag, isSubGroups=0)
function sMontage = GetMontageAvgRef(sMontage, Channels, ChannelFlag, isSubGroups)
    global GlobalData;
    % Split the electrodes in subgroups or group them all
    if (nargin < 4) || isempty(isSubGroups)
        isSubGroups = 0;
    end
    % Get info from figure
    if (nargin < 3) || isempty(ChannelFlag)
        hFig = Channels;
        % Create EEG average reference menus
        TsInfo = getappdata(hFig,'TsInfo');
        if isempty(TsInfo.Modality) || ~ismember(TsInfo.Modality, {'EEG','SEEG','ECOG','ECOG+SEEG'})
            sMontage = [];
            return;
        end
        % Get figure description
        [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
        % Check that this figure can handle montages
        if isempty(GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels) || isempty(GlobalData.DataSet(iDS).Channel) || isempty(GlobalData.DataSet(iDS).Measures.ChannelFlag)
            sMontage = [];
            return;
        end
        % Get selected channels
        iChannels = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels;
        Channels = GlobalData.DataSet(iDS).Channel(iChannels);
        ChannelFlag = GlobalData.DataSet(iDS).Measures.ChannelFlag(iChannels);
    else
        iChannels = 1:length(Channels);
    end
    % Apply limitation from montage name (for subgroups only)
    if isSubGroups && ~isempty(sMontage)
        TargetName = CleanMontageName(sMontage.Name);
        % SEEG/ECOG: Keep only selected modality
        if strcmpi(TargetName, 'ECOG_SEEG')
            iSel = find(ismember({Channels.Type}, {'SEEG', 'ECOG'}));
        elseif ismember(TargetName, {'SEEG', 'ECOG'})
            iSel = find(strcmpi({Channels.Type}, TargetName));
        else
            iSel = find(strcmpi({Channels.Group}, TargetName));
        end
        % Nothing selected: return
        if isempty(iSel)
            disp(['BST> Error: No channels correspond to montage "' sMontage.Name '".']);
            sMontage = [];
            return;
        end
        % Apply sub-selection
        iChannels = iChannels(iSel);
        Channels = Channels(iSel);
        ChannelFlag = ChannelFlag(iSel);
    end
    % If no montage in input: get the global average ref
    if isempty(sMontage)
        iMontage = find(strcmpi({GlobalData.ChannelMontages.Montages.Name}, 'Average reference'), 1);
        if isempty(iMontage)
            return;
        end
        sMontage = GlobalData.ChannelMontages.Montages(iMontage(1));
    end
    % Update montage
    numChannels = length(iChannels);
    sMontage.DispNames = {Channels.Name};
    sMontage.ChanNames = {Channels.Name};
    sMontage.Matrix    = eye(numChannels);
    % Get EEG groups
    [iEEG, GroupNames] = GetEegGroups(Channels, ChannelFlag, isSubGroups);
    % Computation
    for i = 1:length(iEEG)
        nChan = length(iEEG{i});
        if (nChan >= 2)
            sMontage.Matrix(iEEG{i},iEEG{i}) = eye(nChan) - ones(nChan) ./ nChan;
        end
    end
    % Sort electrodes per hemisphere if required
    if ~isempty(sMontage) && strcmpi(sMontage.Name, 'Average reference (L -> R)')
        sMontage = SortLeftRight(sMontage);
    end
end


%% ===== SORT MONTAGE LEFT-RIGHT =====
% Sort standard 10-20 montages Left-Right
function sMontage = SortLeftRight(sMontage)
    left  = [];
    mid   = [];
    right = [];
    other = [];
    % Sort channels by position
    for iChannel = 1:length(sMontage.ChanNames)
        % Extract position from channel name
        [tmp, eegNum] = GetEeg1020ChannelParts(sMontage.ChanNames{iChannel});
        if ~isempty(eegNum) && eegNum == 'z'
            mid(end + 1) = iChannel;
        elseif ~isempty(eegNum) && mod(eegNum, 2) == 1
            left(end + 1) = iChannel;
        elseif ~isempty(eegNum) && mod(eegNum, 2) == 0
            right(end + 1) = iChannel;
        else
            other(end + 1) = iChannel;
        end
    end
    iOrder = [left mid right other];
    % Apply new order
    sMontage.DispNames = sMontage.DispNames(iOrder);
    sMontage.ChanNames = sMontage.ChanNames(iOrder);
    sMontage.Matrix = sMontage.Matrix(iOrder, iOrder);
end

%% ===== GET SCALP CURRENT DENSITY MONTAGE =====
% USAGE:  sMontage = GetMontageScd(sMontage, hFig)
%         sMontage = GetMontageScd(sMontage, Channels, ChannelFlag)
function sMontage = GetMontageScd(sMontage, Channels, ChannelFlag)
    global GlobalData;
    % Get info from figure
    if (nargin < 3) || isempty(ChannelFlag)
        hFig = Channels;
        TsInfo = getappdata(hFig, 'TsInfo');
        if isempty(TsInfo.Modality) || ~ismember(TsInfo.Modality, {'EEG'})
            sMontage = [];
            return;
        end
        % Get figure description
        [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
        % Check that this figure can handle montages
        if isempty(GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels) || isempty(GlobalData.DataSet(iDS).Channel) || isempty(GlobalData.DataSet(iDS).Measures.ChannelFlag)
            sMontage = [];
            return;
        end
        % Get channels
        Channels = GlobalData.DataSet(iDS).Channel;
    end
    % Select EEG channels only
    iChannels = find(strcmp({Channels.Type}, 'EEG'));
    % Check that there are non-zero positions available for all the channels
    if isempty(iChannels) || any(cellfun(@isempty, {Channels.Loc})) || ~any(cellfun(@any, {Channels.Loc}))
        sMontage = [];
        return;
    end
    Channels = Channels(iChannels);
    
    % Get surface of electrodes
    pnt = [Channels.Loc]';
    tri = channel_tesselate(pnt);
    % Compute the SCP (surface Laplacian) with FieldTrip function lapcal
    Lscp = lapcal(pnt, tri);
    % Normalize matrix to obtain something that keeps the same range of values
    % (no justification for this, but since these are arbitrary units, let's have less disruptive displays)
    Lscp = Lscp ./ mean(sqrt(sum(Lscp.^2, 2)));
    % If no montage in input: get the SCD montage
    if isempty(sMontage)
        iMontage = find(strcmpi({GlobalData.ChannelMontages.Montages.Name}, 'Scalp current density'), 1);
        if isempty(iMontage)
            return;
        end
        sMontage = GlobalData.ChannelMontages.Montages(iMontage(1));
    end
    % Update montage
    sMontage.DispNames = {Channels.Name};
    sMontage.ChanNames = {Channels.Name};
    sMontage.Matrix    = Lscp;
    % Sort electrodes per hemisphere if required
    if ~isempty(sMontage) && strcmpi(sMontage.Name, 'Scalp current density (L -> R)')
        sMontage = SortLeftRight(sMontage);
    end
end


%% ===== GET HEAD MOTION MONTAGE =====
% USAGE:  sMontage = GetMontageHeadDistance(sMontage, hFig)
%         sMontage = GetMontageHeadDistance(sMontage, Channels, ChannelFlag)
function sMontage = GetMontageHeadDistance(sMontage, Channels, ChannelFlag)
    global GlobalData;
    % Get info from figure
    if (nargin < 3) || isempty(ChannelFlag)
        hFig = Channels;
        TsInfo = getappdata(hFig,'TsInfo');
        if isempty(TsInfo.Modality) || ~ismember(TsInfo.Modality, {'MEG', 'HLU'})
            sMontage = [];
            return;
        end
        % Get figure description
        [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
        % Check that this figure can handle montages
        if isempty(GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels) || isempty(GlobalData.DataSet(iDS).Channel) || isempty(GlobalData.DataSet(iDS).Measures.ChannelFlag)
            sMontage = [];
            return;
        end
        % Get channels
        Channels = GlobalData.DataSet(iDS).Channel;
    end
    % Select HLU channels only
    iChannels = find(strcmp({Channels.Type}, 'HLU'));
    if isempty(iChannels)
        sMontage = [];
        return;
    end
    Channels = Channels(iChannels);
    % If no montage in input: get the head distance montage
    if isempty(sMontage)
        iMontage = find(strcmpi({GlobalData.ChannelMontages.Montages.Name}, 'Head distance'), 1);
        if isempty(iMontage)
            return;
        end
        sMontage = GlobalData.ChannelMontages.Montages(iMontage(1));
    end
    % Computation done with custom montage, use identity matrix.
    % Update montage
    numChannels = length(iChannels);
    sMontage.DispNames = {'Dist'}; %{Channels.Name};
    sMontage.ChanNames = {Channels.Name};
    sMontage.Matrix    = ones(1, numChannels); %eye(numChannels);
end


%% ===== GET BAD CHANNELS MONTAGE =====
% USAGE:  [sMontage, iMontage] = GetMontageBadChan(hFig)
%         [sMontage, iMontage] = GetMontageBadChan(Channels, ChannelFlag)
function [sMontage, iMontage] = GetMontageBadChan(Channels, ChannelFlag)
    global GlobalData;
    sMontage = [];
    iMontage = [];
    % Get info from figure
    if (nargin == 1)
        hFig = Channels;
        % Create EEG average reference menus
        TsInfo = getappdata(hFig,'TsInfo');
        if isempty(TsInfo.Modality)
            return;
        end
        % Get figure description
        [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
        % Get selected channels
        Channels = GlobalData.DataSet(iDS).Channel;
        ChannelFlag = GlobalData.DataSet(iDS).Measures.ChannelFlag;
    end
    % Get bad channels
    iChannels = find(ChannelFlag == -1);
    % Set montage structure
    iMontage = find(strcmpi({GlobalData.ChannelMontages.Montages.Name}, 'Bad channels'), 1);
    if ~isempty(iMontage)
        sMontage = GlobalData.ChannelMontages.Montages(iMontage);
        sMontage.DispNames = {Channels(iChannels).Name};
        sMontage.ChanNames = {Channels(iChannels).Name};
        sMontage.Matrix    = eye(length(iChannels));
    end
end


%% ===== SET CURRENT MONTAGE ======
% USAGE:  SetCurrentMontage(Modality, MontageName)
%         SetCurrentMontage(hFig,     MontageName)
function SetCurrentMontage(Modality, MontageName)
    global GlobalData;
    % Get modality
    if (nargin < 2) || isempty(Modality)
        disp('BST> Error: Invalid call to SetCurrentMontage()');
        return;
    elseif ~ischar(Modality)
        % Get figure modality
        hFig = Modality;
        TsInfo = getappdata(hFig, 'TsInfo');
        if isempty(TsInfo) || isempty(TsInfo.Modality)
            disp('BST> Error: Invalid figure for SetCurrentMontage()');
            return;
        end
        Modality = TsInfo.Modality;
        % Topo: different category
        TopoInfo = getappdata(hFig, 'TopoInfo');
        if ~isempty(TopoInfo)
            Modality = ['topo_' Modality];
        end
    else
        hFig = [];
    end
    % Storage field 
    FieldName = ['mod_' lower(file_standardize(Modality))];
    % Update default montage
    if ~isequal(MontageName, 'Bad channels')
        GlobalData.ChannelMontages.CurrentMontage.(FieldName) = MontageName;
    end
    % Update figure
    if ~isempty(hFig)
        bst_progress('start', 'Montage selection', 'Updating figures...');
        % Update config structure
        TsInfo = getappdata(hFig, 'TsInfo');
        TsInfo.MontageName = MontageName;
        setappdata(hFig, 'TsInfo', TsInfo);
        % Update panel Recorf
        panel_record('UpdateDisplayOptions', hFig);
        % Update figure plot
        bst_figures('ReloadFigures', hFig, 0);
        % Close progress bar
        bst_progress('stop');
    end
end

%% ===== CREATE POPUP MENU ======
function CreateFigurePopupMenu(jMenu, hFig) %#ok<DEFNU>
    import java.awt.event.*;
    import javax.swing.*;
    import java.awt.*;

    % Remove all previous menus
    jMenu.removeAll();
    % Get montages
    sFigMontages = GetMontagesForFigure(hFig);
    % Get current montage
    TsInfo = getappdata(hFig, 'TsInfo');
    MontageOptions = bst_get('MontageOptions');
    % Get selected sensors
    if ~isempty(TsInfo) && (strcmpi(TsInfo.DisplayMode, 'column') || strcmpi(TsInfo.DisplayMode, 'butterfly'))
        SelChannels = figure_timeseries('GetFigSelectedRows', hFig);
    elseif ~isempty(TsInfo) && strcmpi(TsInfo.DisplayMode, 'topography')
        SelChannels = figure_3d('GetFigSelectedRows', hFig);
    else
        SelChannels = [];
    end
    
    % MENU: Edit montages
    gui_component('MenuItem', jMenu, [], 'Edit montages...', [], [], @(h,ev)EditMontages(hFig));
    % MENU: Create from mouse selection
    if ~isempty(hFig) && ~isempty(SelChannels)
        gui_component('MenuItem', jMenu, [], 'Create from selection', [], [], @(h,ev)NewMontage('selection', SelChannels, hFig));
    end
    jMenu.addSeparator();

    % MENU: All channels
    if ~(isequal(TsInfo.Modality, 'NIRS') && strcmpi(TsInfo.DisplayMode, 'topography'))
        jItem = gui_component('CheckBoxMenuItem', jMenu, [], 'All channels', [], [], @(h,ev)SetCurrentMontage(hFig, []));
        jItem.setSelected(isempty(TsInfo.MontageName));
        jItem.setAccelerator(KeyStroke.getKeyStroke(int32(KeyEvent.VK_A), KeyEvent.SHIFT_MASK));
    end
    % MENUS: List of available montages
    if ~isempty(sFigMontages)
        subMenus = struct;
        GroupNames = cellfun(@(c)strtrim(str_remove_parenth(strrep(c, '[tmp]', ''))), {sFigMontages.Name}, 'UniformOutput', 0);
        for i = 1:length(sFigMontages)
            % Is it the selected one
            if ~isempty(TsInfo.MontageName)
                isSelected = strcmpi(sFigMontages(i).Name, TsInfo.MontageName);
            else
                isSelected = 0;
            end
            % Special test for average reference
            if ~isempty(strfind(sFigMontages(i).Name, 'Average reference'))
                DisplayName = sFigMontages(i).Name;
                jSubMenu = jMenu;
            % Temporary montages:  Remove the [tmp] tag or display
            elseif ~isempty(strfind(sFigMontages(i).Name, '[tmp]'))
                MontageName = strrep(sFigMontages(i).Name, '[tmp]', '');
                DisplayName = ['<HTML><I>' MontageName '</I>'];
                % Parse name for sub menus
                stdName = ['m', file_standardize(GroupNames{i}, 0, '_', 1)];
                stdName((stdName == '.') | (stdName == '-') | (stdName == '@')) = '_';
                if (nnz(strcmpi(GroupNames{i}, GroupNames)) == 1)
                    % Only element in its group
                    jSubMenu = jMenu;
                elseif isfield(subMenus, stdName)
                    jSubMenu = subMenus.(stdName);
                else
                    jSubMenu = gui_component('Menu', jMenu, [], ['<HTML><I>' GroupNames{i} '</I>']);
                    subMenus.(stdName) = jSubMenu;
                end
            else
                DisplayName = sFigMontages(i).Name;
                jSubMenu = jMenu;
            end
            % Create menu
            jItem = gui_component('CheckBoxMenuItem', jSubMenu, [], DisplayName, [], [], @(h,ev)SetCurrentMontage(hFig, sFigMontages(i).Name));
            jItem.setSelected(isSelected);
            shortcut = [];
            for iShortcut = 1:25
                if strcmpi(CleanMontageName(sFigMontages(i).Name), MontageOptions.Shortcuts{iShortcut,2})
                    shortcut = MontageOptions.Shortcuts{iShortcut,1};
                    break;
                end
            end
            if ~isempty(shortcut)
                jItem.setAccelerator(KeyStroke.getKeyStroke(int32(KeyEvent.VK_A + shortcut - 'a'), KeyEvent.SHIFT_MASK));
            end
        end
    end
    drawnow;
    jMenu.repaint();
end

%% ===== CREATE MONTAGE MENU =====
function CreateMontageMenu(jButton, hFig)
    import org.brainstorm.icon.*;
    % Create popup menu
    jPopup = java_create('javax.swing.JPopupMenu');
    % Get figure info
    if ~isempty(hFig)
        TsInfo = getappdata(hFig, 'TsInfo');
    end
    % Create new montages
    if isempty(hFig) || ~strcmpi(TsInfo.DisplayMode, 'topography')
        gui_component('MenuItem', jPopup, [], 'New channel selection', IconLoader.ICON_EEG_NEW, [], @(h,ev)NewMontage('selection', [], hFig));
    end
    if ~isempty(hFig) 
        gui_component('MenuItem', jPopup, [], 'New re-referencing montage (single ref)', IconLoader.ICON_EEG_NEW, [], @(h,ev)NewMontage('ref', [], hFig));
        gui_component('MenuItem', jPopup, [], 'New re-referencing montage (linked ref)', IconLoader.ICON_EEG_NEW, [], @(h,ev)NewMontage('linkref', [], hFig));
    end
    gui_component('MenuItem', jPopup, [], 'New custom montage',  IconLoader.ICON_EEG_NEW, [], @(h,ev)NewMontage('text', [], hFig));
    jPopup.addSeparator();
    gui_component('MenuItem', jPopup, [], 'Duplicate montage', IconLoader.ICON_COPY, [], @(h,ev)ButtonDuplicate_Callback(hFig));
    gui_component('MenuItem', jPopup, [], 'Rename montage', IconLoader.ICON_EDIT, [], @(h,ev)ButtonRename_Callback(hFig));
    gui_component('MenuItem', jPopup, [], 'Delete montage', IconLoader.ICON_DELETE, [], @(h,ev)ButtonDelete_Callback(hFig));
    % Show popup menu
    jPopup.show(jButton, 0, jButton.getHeight());
end

%% ===== RENAME MONTAGE =====
function newName = RenameMontage(oldName, newName)
    global GlobalData;
    % Look for existing montage
    [sMontage, iMontage] = GetMontage(oldName);
    % If montage does not exist
    if isempty(sMontage)
        error('Condition does not exist.');
    end
    % If this is a non-editable montage: error
    if ismember(sMontage.Name, {'Bad channels', 'Average reference', 'Average reference (L -> R)', 'Scalp current density', 'Scalp current density (L -> R)', 'Head distance'})
        newName = [];
        return;
    end
    % If new name was not provided: Ask the user
    if (nargin < 2) || isempty(newName)
        newName = java_dialog('input', 'Enter a new name for this montage:', 'Rename montage', [], oldName);
        if isempty(newName)
            return;
        elseif ~isempty(GetMontage(newName))
            bst_error('This montage name already exists.', 'Rename montage', 0);
            newName = [];
            return
        end
    end
    % Rename montage
    GlobalData.ChannelMontages.Montages(iMontage).Name = newName;
end


%% ===== PROCESS KEYPRESS =====
function isProcessed = ProcessKeyPress(hFig, Key) %#ok<DEFNU>
    isProcessed = 0;
    % Get montages for the figure
    MontageOptions = bst_get('MontageOptions');
    sMontages = GetMontagesForFigure(hFig);
    if isempty(sMontages)
        return
    end
    % Accept only alphabetical chars
    Key = uint8(lower(Key));
    if (length(Key) ~= 1) || (Key < uint8('a')) || (Key > uint8('z'))
        return
    end
    % Get the selection indicated by the key
    iSel = Key - uint8('a');
    if (iSel == 0)
        newName = [];
    else
        found = 0;
        if ~isempty(MontageOptions.Shortcuts{iSel,2})
            for iMontage = 1:length(sMontages)
                if strcmpi(MontageOptions.Shortcuts{iSel,2}, CleanMontageName(sMontages(iMontage).Name))
                    newName = sMontages(iMontage).Name;
                    found = 1;
                    break;
                end
            end
        end
        if ~found
            % Count key press as processed even if no montage attached to avoid
            % triggering other unwanted events.
            isProcessed = 1;
            return;
        end
    end
    % Process key pressed: switch to new montage
    SetCurrentMontage(hFig, newName);
    isProcessed = 1;
end


%% ===== LOAD MONTAGE FILE =====
% USAGE:  LoadMontageFiles(FileNames, FileFormat, isOverwrite=0)
%         LoadMontageFiles()   : Ask user the file to load
function sMontages = LoadMontageFiles(FileNames, FileFormat, isOverwrite)
    sMontages = [];
    % Parse inputs
    if (nargin < 3) || isempty(isOverwrite)
        isOverwrite = 0;
    end
    % Ask filename to user
    if (nargin < 2) || isempty(FileNames) || isempty(FileFormat)
        % Get default import directory
        LastUsedDirs = bst_get('LastUsedDirs');
        if isempty(LastUsedDirs.ImportMontage)
            LastUsedDirs.ImportMontage = bst_fullfile(bst_get('BrainstormHomeDir'), 'toolbox', 'sensors', 'private');
        end
        % Get default file format
        DefaultFormats = bst_get('DefaultFormats');
        if isempty(DefaultFormats.MontageIn)
            DefaultFormats.MontageIn = 'MON';
        end
        
       
        % Select file
        [FileNames, FileFormat] = java_getfile( 'open', 'Import montages', ...
            LastUsedDirs.ImportMontage, 'multiple', 'files', ...
            bst_get('FileFilters', 'montagein'), ...
            DefaultFormats.MontageIn);
        if isempty(FileNames)
            return
        end
        % Save default import directory
        LastUsedDirs.ImportMontage = bst_fileparts(FileNames{1});
        bst_set('LastUsedDirs', LastUsedDirs);
        % Save default export format
        DefaultFormats.MontageIn = FileFormat;
        bst_set('DefaultFormats',  DefaultFormats);
    elseif ~iscell(FileNames)
        FileNames = {FileNames};
    end
    % Progress bar
    bst_progress('start', 'Import montage', 'Loading montage files...');
    % Load files
    sMontages = repmat(db_template('Montage'), 0);
    for iFile = 1:length(FileNames)
        % Read file
        switch (FileFormat)
            case 'MNE'
                sMon = in_montage_mne(FileNames{iFile});
            case 'MON'
                sMon = in_montage_mon(FileNames{iFile});
            case 'BST'
                DataMat = load(FileNames{iFile});
                sMon = DataMat.Montages;
            case 'CSV'
                sMon = in_montage_csv(FileNames{iFile});
        end
        % Concatenate with the list of loaded montages
        sMontages = cat(2, sMontages, sMon);
    end
    % Close progress bar
    bst_progress('stop');
    % If file was not read: return
    if isempty(sMontages) || ~isequal(fieldnames(sMontages), fieldnames(db_template('Montage')))
        return
    end
    % Loop to add all montages 
    for i = 1:length(sMontages)
        sMontages(i).Name = SetMontage(sMontages(i).Name, sMontages(i), isOverwrite);
    end
end


%% ===== SAVE MONTAGE FILE =====
% USAGE:  SaveMontageFile(sMontages, FileName, FileFormat)
%         SaveMontageFile(sMontages)           : Ask user the file to be loaded
function SaveMontageFile(sMontages, FileName, FileFormat)
    % Ask filename to user
    if (nargin < 3) || isempty(FileName)
        % Get default file
        LastUsedDirs = bst_get('LastUsedDirs');
        DefaultFormats = bst_get('DefaultFormats');
        if isempty(DefaultFormats.MontageOut)
            DefaultFormats.MontageOut = 'MON';
        end
        switch (DefaultFormats.MontageOut)
            case 'MNE',  DefaultExt = '.sel';
            case 'MON',  DefaultExt = '.mon';
            case 'BST',  DefaultExt = '.mat';    
        end
        DefaultFile = bst_fullfile(LastUsedDirs.ExportMontage, [file_standardize(sMontages(1).Name), DefaultExt]);
        % Select file
        [FileName, FileFormat] = java_getfile( 'save', 'Export montages', ...
            DefaultFile, 'single', 'files', ...
            bst_get('FileFilters', 'montageout'), ...
            DefaultFormats.MontageOut);
        if isempty(FileName)
            return
        end
        % Save default export directory
        LastUsedDirs.ExportMontage = bst_fileparts(FileName);
        bst_set('LastUsedDirs', LastUsedDirs);
        % Save default export format
        DefaultFormats.MontageOut = FileFormat;
        bst_set('DefaultFormats',  DefaultFormats);
    end
    % Save file
    switch (FileFormat)
        case 'MNE'
            out_montage_mne(FileName, sMontages);
        case 'MON'
            if (length(sMontages) > 1)
                error('Cannot save more than one montage per file.');
            end
            out_montage_mon(FileName, sMontages);
        case 'BST'
            DataMat.Montages = sMontages;
            bst_save(FileName, DataMat, 'v6');
    end    
end


%% ===== GET EEG GROUPS =====
function [iEEG, GroupNames, DisplayNames] = GetEegGroups(Channel, ChannelFlag, isSubGroups)
    GroupNames   = {};
    iEEG         = {};
    % Parse inputs
    if (nargin < 3) || isempty(isSubGroups)
        isSubGroups = 0;
    end
    if (nargin < 2) || isempty(ChannelFlag)
        ChannelFlag = [];
    end
    % Default display name: actual channel name
    DisplayNames = {Channel.Name};
    % SEEG/ECOG: Try to split group/index  with the Comment field
    for Modality = {'EEG', 'SEEG', 'ECOG'}
        % Get channels for modality
        iMod = good_channel(Channel, ChannelFlag, Modality{1});
        if isempty(iMod)
            continue;
        end
        % Use subgroups (not for EEG)
        if isSubGroups && ~strcmpi(Modality{1}, 'EEG')
            % Parse sensor names
            [AllGroups, AllTags, AllInd, isNoInd] = ParseSensorNames(Channel(iMod));
            % If the group name is empty, replace with "Unknown"
            AllGroups(cellfun(@isempty, AllGroups)) = {'Unknown'};
            uniqueGroups = unique(AllGroups);
            % If the sensors are not separated in groups using the comments fields
            if isempty(uniqueGroups) % || (length(uniqueGroups) == 1)
                % All the channels = one block
                iEEG{end+1}  = iMod;
                GroupNames{end+1} = Modality{1};
            % Else: split in groups
            else
                for iGroup = 1:length(uniqueGroups)
                    % Look for all the sensors belonging to this group
                    iTmp = find(strcmp({Channel(iMod).Group}, uniqueGroups{iGroup}));
                    % If the sensors can be split using the tag/index logic
                    if ~any(isNoInd)
                        % Sort the sensors indices
                        [tmp_, I] = sort(AllInd(iTmp));
                        iTmp = iTmp(I);
                        % Display name: full name for the first and last sensor of the group, indice for the others
                        for i = 2:(length(iTmp)-1)
                            strInd = DisplayNames{iMod(iTmp(i))}(ismember(DisplayNames{iMod(iTmp(i))}, '0123456789'));
                            if ~isempty(strInd)
                                DisplayNames{iMod(iTmp(i))} = strInd;
                            else
                                DisplayNames{iMod(iTmp(i))} = num2str(i);
                            end
                        end
                    end
                    iEEG{end+1} = iMod(iTmp);
                    GroupNames{end+1} = uniqueGroups{iGroup};
                end
            end
        % Put all the electrodes in the same group
        else
            iEEG{end+1}  = iMod;
            GroupNames{end+1} = Modality{1};
        end
    end
end


%% ===== PARSE SENSOR NAMES =====
function [AllGroups, AllTags, AllInd, isNoInd] = ParseSensorNames(Channels)
    % Only one type of sensors per call
    Modality = Channels(1).Type;
    % Get all groups
    AllGroups = {Channels.Group};
    % Get all names: remove special characters
    AllNames = {Channels.Name};
    if strcmpi(Modality, 'ECOG')
        % ECOG grids in Freiburg: G_A1, G_A2, ... , G_A8, G_B1, G_B2, ..., G_B8, G_C1, ...
        AllNames = strrep(AllNames, 'G_A', 'G0');
        AllNames = strrep(AllNames, 'G_B', 'G1');
        AllNames = strrep(AllNames, 'G_C', 'G2');
        AllNames = strrep(AllNames, 'G_D', 'G3');
        AllNames = strrep(AllNames, 'G_E', 'G4');
        AllNames = strrep(AllNames, 'G_F', 'G5');
        AllNames = strrep(AllNames, 'G_G', 'G6');
        AllNames = strrep(AllNames, 'G_H', 'G7');
        AllNames = strrep(AllNames, 'G_I', 'G8');
        AllNames = strrep(AllNames, 'G_K', 'G9');
        AllNames = strrep(AllNames, 'G_L', 'G10');
    end
    AllNames = str_remove_spec_chars(AllNames);
    AllTags  = cell(size(AllNames));
    AllInd   = cell(size(AllNames));
    isNoInd  = zeros(size(AllNames));
    % Separate characters and numbers in the names
    for i = 1:length(AllNames)
        % Find the last letter in the name
        iLastLetter = find(~ismember(AllNames{i}, '0123456789'), 1, 'last');
        AllTags{i} = AllNames{i}(1:iLastLetter);
        % If there are digits at the end of the name: use them as the index of the contact
        if (iLastLetter < length(AllNames{i}))
            AllInd{i} = AllNames{i}(iLastLetter+1:end);
        else
            isNoInd(i) = 1;
            AllInd{i} = '0';
        end
    end
    % If some indices are defined: check if the first digits shouldn't be part of the channel name
    iInd = find(~isNoInd);
    if ~isempty(iInd)
        % Get unique tags
        uniqueTags = unique(AllTags(iInd));
        % Check for each of them: if all the indices start with the same digit, include the first digit in the group name
        for iTag = 1:length(uniqueTags)
            iChTag = find(strcmpi(AllTags(iInd), uniqueTags{iTag}));
            chInd = cellfun(@str2num, AllInd(iInd(iChTag)));
            if (length(chInd) > 4) && ...
               (all(((chInd >= 11) & (chInd <= 19)) | ((chInd >= 100) & (chInd <= 199))) || ...
                all(((chInd >= 21) & (chInd <= 29)) | ((chInd >= 200) & (chInd <= 299))) || ...
                all(((chInd >= 31) & (chInd <= 39)) | ((chInd >= 300) & (chInd <= 399))) || ...
                all(((chInd >= 41) & (chInd <= 49)) | ((chInd >= 400) & (chInd <= 499))) || ...
                all(((chInd >= 51) & (chInd <= 59)) | ((chInd >= 500) & (chInd <= 599))) || ...
                all(((chInd >= 61) & (chInd <= 69)) | ((chInd >= 600) & (chInd <= 699))) || ...
                all(((chInd >= 71) & (chInd <= 79)) | ((chInd >= 700) & (chInd <= 799))) || ...
                all(((chInd >= 81) & (chInd <= 89)) | ((chInd >= 800) & (chInd <= 899))) || ...
                all(((chInd >= 91) & (chInd <= 99)) | ((chInd >= 900) & (chInd <= 999))))
                for i = iInd(iChTag)
                    AllTags{i} = [AllTags{i}, AllInd{i}(1)];
                    AllInd{i}  = AllInd{i}(2:end);
                end
            end
        end
    end
    % Convert indices to double values
    AllInd = cellfun(@str2num, AllInd);
end


%% ===== SHOW EDITOR =====
function ShowEditor() %#ok<DEFNU>
    gui_show('panel_montage', 'JavaWindow', 'Montage editor', [], 0, 1, 0);
    UpdateMontagesList([]);
end


%% ===== ADD AUTO MONTAGES: EEG =====
function AddAutoMontagesSeeg(Comment, ChannelMat) %#ok<DEFNU>
    % Get groups of electrodes
    [iEeg, GroupNames] = GetEegGroups(ChannelMat.Channel, [], 1);
    % Get all the modalities available: Only SEEG and ECOG accepted
    AllModalities = intersect(unique(upper({ChannelMat.Channel([iEeg{:}]).Type})), {'SEEG','ECOG'});
    if isempty(AllModalities) || isempty(iEeg) 
        return;
    end
    % Add ECOG+SEEG
    if all(ismember({'SEEG','ECOG'}, AllModalities))
        AllModalities = cat(2, 'ECOG_SEEG', AllModalities);
        isEcogSeeg = 1;
    else
        isEcogSeeg = 0;
    end

    % === MONTAGES: ALL ===
    for iMod = 1:length(AllModalities)
        Mod = AllModalities{iMod};
        % All (orig)
        sMontageAllOrig.(Mod) = db_template('Montage');
        sMontageAllOrig.(Mod).Name   = [Comment ': ' Mod ' (orig)[tmp]'];
        sMontageAllOrig.(Mod).Type   = 'selection';
        % SetMontage(sMontageAllOrig.(Mod).Name, sMontageAllOrig.(Mod));
        % All (bipolar 1)
        sMontageAllBip1.(Mod) = db_template('Montage');
        sMontageAllBip1.(Mod).Name   = [Comment ': ' Mod ' (bipolar 1)[tmp]'];
        sMontageAllBip1.(Mod).Type   = 'text';
        % SetMontage(sMontageAllBip1.(Mod).Name, sMontageAllBip1.(Mod));
        % All (bipolar 2)
        sMontageAllBip2.(Mod) = db_template('Montage');
        sMontageAllBip2.(Mod).Name   = [Comment ': ' Mod ' (bipolar 2)[tmp]'];
        sMontageAllBip2.(Mod).Type   = 'text';
        % SetMontage(sMontageAllBip2.(Mod).Name, sMontageAllBip2.(Mod));
        % All (local average reference)
        sMontageLocalAvgRef.(Mod) = db_template('Montage');
        sMontageLocalAvgRef.(Mod).Name   = [Comment ': ' Mod ' (local average ref)[tmp]'];
        sMontageLocalAvgRef.(Mod).Type   = 'matrix';
        % SetMontage(sMontageLocalAvgRef.(Mod).Name, sMontageLocalAvgRef.(Mod));
        % Initialize counter of montages per modality
        nMontages.(Mod) = 0;
    end

    % For each group
    for iGroup = 1:length(iEeg)
        % Get the electrodes for this group
        iChan = iEeg{iGroup};
        if isempty(iChan) || (length(iChan) < 2)
            continue;
        end
        ChanNames = {ChannelMat.Channel(iChan).Name};
        Mod = upper(ChannelMat.Channel(iChan(1)).Type);
        % Skip EEG
        if strcmpi(Mod, 'EEG')
            continue;
        end
        % Get indices
        [AllGroups, AllTags, AllInd] = ParseSensorNames(ChannelMat.Channel(iChan));
        % Count montages
        nMontages.(Mod) = nMontages.(Mod) + 1;
        if isEcogSeeg && any(ismember({'SEEG','ECOG'}, AllModalities))
            nMontages.ECOG_SEEG = nMontages.ECOG_SEEG + 1;
        end

        % === MONTAGE: ORIG ===
        % Create montage
        sMontage = db_template('Montage');
        sMontage.Name      = [Comment ': ' GroupNames{iGroup} ' (orig)[tmp]'];
        sMontage.Type      = 'selection';
        sMontage.ChanNames = ChanNames;
        sMontage.DispNames = ChanNames;
        sMontage.Matrix    = eye(length(iChan));
        % Add montage
        SetMontage(sMontage.Name, sMontage);
        % Add to ALL-orig montage
        sMontageAllOrig.(Mod).ChanNames = cat(2, sMontageAllOrig.(Mod).ChanNames, sMontage.ChanNames);
        sMontageAllOrig.(Mod).DispNames = cat(2, sMontageAllOrig.(Mod).DispNames, sMontage.DispNames);
        sMontageAllOrig.(Mod).Matrix(size(sMontageAllOrig.(Mod).Matrix,1)+(1:size(sMontage.Matrix,1)), size(sMontageAllOrig.(Mod).Matrix,2)+(1:size(sMontage.Matrix,2))) = sMontage.Matrix;
        % Add to ECOG+SEEG montage
        if isEcogSeeg && any(ismember({'SEEG','ECOG'}, AllModalities))
            sMontageAllOrig.ECOG_SEEG.ChanNames = cat(2, sMontageAllOrig.ECOG_SEEG.ChanNames, sMontage.ChanNames);
            sMontageAllOrig.ECOG_SEEG.DispNames = cat(2, sMontageAllOrig.ECOG_SEEG.DispNames, sMontage.DispNames);
            sMontageAllOrig.ECOG_SEEG.Matrix(size(sMontageAllOrig.ECOG_SEEG.Matrix,1)+(1:size(sMontage.Matrix,1)), size(sMontageAllOrig.ECOG_SEEG.Matrix,2)+(1:size(sMontage.Matrix,2))) = sMontage.Matrix;
        end
        
        % Skip bipolar montages if there is only one channel
        if (length(iChan) < 2)
            continue;
        end

        % === MONTAGE: BIPOLAR 1 ===
        % Example: A1-A2, A3-A4, ...
        % Create montage
        sMontage = db_template('Montage');
        sMontage.Name      = [Comment ': ' GroupNames{iGroup} ' (bipolar 1)[tmp]'];
        sMontage.Type      = 'text';
        sMontage.ChanNames = ChanNames;
        sMontage.Matrix    = zeros(0, length(iChan));
        iDisp = 1;
        for i = 1:2:length(ChanNames)
            % Last pair is not complete: A1-A2, A3-A4, A4-A5
            if (i == length(ChanNames))
                i1 = i-1;
                i2 = i;
            % Last pair is complete: A1-A2, A3-A4, A5-A6
            else
                i1 = i;
                i2 = i+1;
            end
            % SEEG: Skip if the two channels are not consecutive
            if ismember(Mod, {'SEEG','ECOG'}) && ~ismember(AllInd(i1) - AllInd(i2), [1,-1])
                continue;
            end
            % Create entry
            sMontage.DispNames{iDisp} = [ChanNames{i1} '-' ChanNames{i2}];
            sMontage.Matrix(iDisp, i1) =  1;
            sMontage.Matrix(iDisp, i2) = -1;
            iDisp = iDisp + 1;
        end
        % Add montage: orig
        SetMontage(sMontage.Name, sMontage);
        % Add to ALL-dip1 montage
        sMontageAllBip1.(Mod).ChanNames = cat(2, sMontageAllBip1.(Mod).ChanNames, sMontage.ChanNames);
        sMontageAllBip1.(Mod).DispNames = cat(2, sMontageAllBip1.(Mod).DispNames, sMontage.DispNames);
        sMontageAllBip1.(Mod).Matrix(size(sMontageAllBip1.(Mod).Matrix,1)+(1:size(sMontage.Matrix,1)), size(sMontageAllBip1.(Mod).Matrix,2)+(1:size(sMontage.Matrix,2))) = sMontage.Matrix;
        % Add to ECOG+SEEG montage
        if isEcogSeeg && any(ismember({'SEEG','ECOG'}, AllModalities))
            sMontageAllBip1.ECOG_SEEG.ChanNames = cat(2, sMontageAllBip1.ECOG_SEEG.ChanNames, sMontage.ChanNames);
            sMontageAllBip1.ECOG_SEEG.DispNames = cat(2, sMontageAllBip1.ECOG_SEEG.DispNames, sMontage.DispNames);
            sMontageAllBip1.ECOG_SEEG.Matrix(size(sMontageAllBip1.ECOG_SEEG.Matrix,1)+(1:size(sMontage.Matrix,1)), size(sMontageAllBip1.ECOG_SEEG.Matrix,2)+(1:size(sMontage.Matrix,2))) = sMontage.Matrix;
        end
        
        % === MONTAGE: BIPOLAR 2 ===
        % Example: A1-A2, A2-A3, ...
        % Create montage
        sMontage = db_template('Montage');
        sMontage.Name      = [Comment ': ' GroupNames{iGroup} ' (bipolar 2)[tmp]'];
        sMontage.Type      = 'text';
        sMontage.ChanNames = ChanNames;
        sMontage.Matrix    = zeros(0, length(iChan));
        iDisp = 1;
        for i = 1:length(ChanNames)-1
            % SEEG: Skip if the two channels are not consecutive
            if ismember(Mod, {'SEEG','ECOG'}) && ~ismember(AllInd(i) - AllInd(i+1), [1,-1])
                continue;
            end
            % Create entry
            sMontage.DispNames{iDisp} = [ChanNames{i} '-' ChanNames{i+1}];
            sMontage.Matrix(iDisp, i)   =  1;
            sMontage.Matrix(iDisp, i+1) = -1;
            iDisp = iDisp + 1;
        end
        % Add montage: orig
        SetMontage(sMontage.Name, sMontage);
        % Add to ALL-dip2 montage
        sMontageAllBip2.(Mod).ChanNames = cat(2, sMontageAllBip2.(Mod).ChanNames, sMontage.ChanNames);
        sMontageAllBip2.(Mod).DispNames = cat(2, sMontageAllBip2.(Mod).DispNames, sMontage.DispNames);
        sMontageAllBip2.(Mod).Matrix(size(sMontageAllBip2.(Mod).Matrix,1)+(1:size(sMontage.Matrix,1)), size(sMontageAllBip2.(Mod).Matrix,2)+(1:size(sMontage.Matrix,2))) = sMontage.Matrix;
        % Add to ECOG+SEEG montage
        if isEcogSeeg && any(ismember({'SEEG','ECOG'}, AllModalities))
            sMontageAllBip2.ECOG_SEEG.ChanNames = cat(2, sMontageAllBip2.ECOG_SEEG.ChanNames, sMontage.ChanNames);
            sMontageAllBip2.ECOG_SEEG.DispNames = cat(2, sMontageAllBip2.ECOG_SEEG.DispNames, sMontage.DispNames);
            sMontageAllBip2.ECOG_SEEG.Matrix(size(sMontageAllBip2.ECOG_SEEG.Matrix,1)+(1:size(sMontage.Matrix,1)), size(sMontageAllBip2.ECOG_SEEG.Matrix,2)+(1:size(sMontage.Matrix,2))) = sMontage.Matrix;
        end
        
        % === MONTAGE: LOCAL AVG REF ===
        % Create montage
        sMontage = db_template('Montage');
        sMontage.Name      = [Comment ': ' GroupNames{iGroup} ' (local average ref)[tmp]'];
        sMontage.Type      = 'matrix';
        % Add montage
        SetMontage(sMontage.Name, sMontage);
    end 

    % Update the ALL montages
    for iMod = 1:length(AllModalities)
        Mod = AllModalities{iMod};
        % Skip modalities that only have one montage
        if (nMontages.(Mod) <= 1)
            continue;
        end
        % Add all modality montages
        SetMontage(sMontageAllOrig.(Mod).Name, sMontageAllOrig.(Mod));
        SetMontage(sMontageAllBip1.(Mod).Name, sMontageAllBip1.(Mod));
        SetMontage(sMontageAllBip2.(Mod).Name, sMontageAllBip2.(Mod));
        SetMontage(sMontageLocalAvgRef.(Mod).Name, sMontageLocalAvgRef.(Mod));
    end
end



%% ===== ADD AUTO MONTAGES: NIRS =====
function AddAutoMontagesNirs(ChannelMat)
    % Get NIRS sensors
    iNirs = channel_find(ChannelMat.Channel, 'NIRS');
    
    % === GET COLORS ===
    % Get all the groups
    [uniqueGroups,I,J] = unique({ChannelMat.Channel(iNirs).Group});
    % Get color map
    ColorTable = panel_scout('GetScoutsColorTable');
    % Standard color for HbO
    iHbO = find(strcmpi(uniqueGroups, 'hbo'));
    if ~isempty(iHbO)
        ColorTable(iHbO,:) = [1,0,0];
    end
    % Standard color for HbR
    iHbR = find(strcmpi(uniqueGroups, 'hbr'));
    if ~isempty(iHbR)
        ColorTable(iHbR,:) = [0,0,1];
    end
    % Standard color for HbT
    iHbT = find(strcmpi(uniqueGroups, 'hbt'));
    if ~isempty(iHbT)
        ColorTable(iHbT,:) = [0,1,0];
    end
    
    % === OVERLAY MONTAGE ===
    % Add one montage to superimpose all the channels for each pair source/detector
    sMontage = db_template('Montage');
    sMontage.Name      = 'NIRS overlay[tmp]';
    sMontage.Type      = 'text';    
    sMontage.ChanNames = {ChannelMat.Channel(iNirs).Name};
    sMontage.Matrix    = eye(length(iNirs), length(iNirs));
    % For each channel
    for i = 1:length(iNirs)
        % Parse channel name
        [S,D,WL] = ParseNirsChannelNames({ChannelMat.Channel(iNirs(i)).Name});
        % Get group color
        iGroup = find(strcmpi(uniqueGroups, ChannelMat.Channel(iNirs(i)).Group));
        dispColor = dec2hex(round(ColorTable(iGroup,:) .* 255),2)';
        dispColor = dispColor(:)';
        % Display name: NAME|COLOR
        sMontage.DispNames{i} = sprintf('S%dD%d|%s', S, D, dispColor);
    end
    % Add HbT sum, if not present
    if ~isempty(iHbO) && ~isempty(iHbR) && isempty(iHbT)
        % Get the HbO/HbR channels
        iHbO = find(strcmpi({ChannelMat.Channel(iNirs).Group}, 'hbo'));
        iHbR = find(strcmpi({ChannelMat.Channel(iNirs).Group}, 'hbr'));
        % Add one HbT channel for each HbO channel
        for i = 1:length(iHbO)
            % Parse channel name
            [S,D,WL] = ParseNirsChannelNames({ChannelMat.Channel(iHbO(i)).Name});
            % Display in green
            sMontage.DispNames{length(iNirs) + i} = sprintf('S%dD%d|%s', S, D, '00FF00');
            % Sum the two values HbO and HbR
            sMontage.Matrix(length(iNirs) + i, [iHbO(i), iHbR(i)]) = 1;
        end
    end
    % Add montage: overlay
    SetMontage(sMontage.Name, sMontage);
    
    % === GROUPS MONTAGES ===
    % Create one montage per group (wavelength or concentration)
    for i = 1:length(uniqueGroups)
        % Get all the sensors in this group
        iGroup = find(J == i);
        % Create montage
        sMontage = db_template('Montage');
        sMontage.Name      = [uniqueGroups{i}, '[tmp]'];
        sMontage.Type      = 'selection';
        sMontage.ChanNames = {ChannelMat.Channel(iNirs(iGroup)).Name};
        sMontage.DispNames = sMontage.ChanNames;
        sMontage.Matrix    = eye(length(iGroup));
        % Add montage
        SetMontage(sMontage.Name, sMontage);
    end
end


%% ===== ADD AUTO MONTAGES: PROJECTORS =====
% USAGE:  panel_montage('AddAutoMontagesProj', ChannelMat)
%         panel_montage('AddAutoMontagesProj')              % Loads montage for currently selected file
function AddAutoMontagesProj(ChannelMat, isInteractive)
    global GlobalData;
    % Non-interactive mode by default
    if (nargin < 2) || isempty(isInteractive)
        isInteractive = 0;
    end
    % Get current channels
    if (nargin < 1) || isempty(ChannelMat)
        iDS = panel_record('GetCurrentDataset');
        if isempty(iDS)
            return;
        end
        ChannelMat = in_bst_channel(GlobalData.DataSet(iDS).ChannelFile);
    end
    % Loop on all the projectors available
    nNewMontages = 0;
    for iProj = 1:length(ChannelMat.Projector)
        % Get selected channels
        sCat = ChannelMat.Projector(iProj);
        iChannels = any(sCat.Components,2);
        % Skip referencing montages
        if (length(sCat.Comment) < 3) || strcmpi(sCat.Comment(1:3), 'EEG')
            continue;
        end
        % ICA
        if isequal(sCat.SingVal, 'ICA')
            % Field Components stores the mixing matrix W
            W = sCat.Components(iChannels, :)';
            % Display name
            strDisplay = 'IC';
        % SSP
        else
            % Field Components stores the spatial components U
            U = sCat.Components(iChannels, :);
            % SSP/PCA results
            if ~isempty(sCat.SingVal) 
                Singular = sCat.SingVal ./ sum(sCat.SingVal);
            % SSP/Mean results
            else
                Singular = eye(size(U,2));
            end
            % Rebuild mixing matrix
            W = diag(sqrt(Singular)) * pinv(U);
            % Display name
            strDisplay = 'SSP';
        end
        % Create line labels
        LinesLabels = cell(size(W,1), 1);
        for iComp = 1:length(LinesLabels)
            LinesLabels{iComp} = sprintf('%s%d', strDisplay, iComp);
        end
        % Create new montage on the fly
        sMontage = db_template('Montage');
        sMontage.Name      = [sCat.Comment, '[tmp]'];
        sMontage.Type      = 'matrix';
        sMontage.ChanNames = {ChannelMat.Channel(iChannels).Name};
        sMontage.DispNames = LinesLabels;
        sMontage.Matrix    = W;
        % Add montage: orig
        panel_montage('SetMontage', sMontage.Name, sMontage);
        nNewMontages = nNewMontages + 1;
    end
    % Display report
    if isInteractive
        if (nNewMontages > 0)
            strMsg = sprintf('%d ICA/SSP projectors now available as montages.', nNewMontages);
        else
            strMsg = 'No ICA/SSP projectors found for these recordings.';
        end
        java_dialog('msgbox', strMsg, 'Load projectors as montages.');
    end
end


%% ===== UNLOAD AUTO MONTAGES =====
function UnloadAutoMontages() %#ok<DEFNU>
    global GlobalData;
    % Exist in no montages loaded
    if isempty(GlobalData) || isempty(GlobalData.ChannelMontages) || isempty(GlobalData.ChannelMontages.Montages)
        return;
    end
    % Look for temporary montages
    iTmp = find(~cellfun(@(c)isempty(strfind(c, '[tmp]')), {GlobalData.ChannelMontages.Montages.Name}));
    if isempty(iTmp)
        return;
    end
    % Delete temporary montages
    GlobalData.ChannelMontages.Montages(iTmp) = [];
end


%% ===== PARSE NIRS CHANNEL NAMES =====
%USAGE: [S,D,WL] = panel_montage('ParseNirsChannelNames', ChannelNames);
function [S,D,WL] = ParseNirsChannelNames(ChannelNames)
    % Parse inputs
    if ischar(ChannelNames)
        ChannelNames = {ChannelNames};
    end
    % Initialize returned variables
    N = length(ChannelNames);
    S  = zeros(1,N);
    D  = zeros(1,N);
    WL = zeros(1,N);
    % Loop on all the channel names
    for i = 1:length(ChannelNames)
        % Parse channel name
        val = sscanf(ChannelNames{i}, 'S%dD%dWL%d');
        % If three values were read: use them
        if (length(val) >= 2)
            S(i)  = val(1);
            D(i)  = val(2);
        end
        if (length(val) == 3)
            WL(i) = val(3);
        end
    end
end



%% ===== PARSE LINE LABELS =====
function [LinesLabels, LinesColor, LinesFilter] = ParseMontageLabels(LinesLabels, DefaultColor)
    % Number of lines
    nLines = length(LinesLabels);
    % If some channels use the extended "NAME|COLOR" or "NAME|FREQBAND"
    if any(cellfun(@(c)any(c == '|'), LinesLabels))
        LinesColor = repmat(DefaultColor, nLines, 1);
        LinesFilter = zeros(nLines, 2);
        for iLine = 1:length(LinesLabels)
            splitLabel = str_split(LinesLabels{iLine}, '|');
            % Channel name
            LinesLabels{iLine} = splitLabel{1};
            % Other options
            for iOpt = 2:length(splitLabel)
                % Channel color
                if (length(splitLabel{iOpt}) == 6) && all(ismember(splitLabel{iOpt}, '0123456789ABCDEF'))
                    color = [hex2dec(splitLabel{iOpt}(1:2)), hex2dec(splitLabel{iOpt}(3:4)), hex2dec(splitLabel{iOpt}(5:6))];
                    if (length(color) == 3)
                        LinesColor(iLine,:) = color ./ 255;
                    else
                        disp(['BST> Montage: Invalid color string "' splitLabel{iOpt} '"']);
                    end
                elseif (length(splitLabel{iOpt}) >= 5) && strcmpi(splitLabel{iOpt}(end-1:end), 'Hz')
                    freqband = sscanf(lower(splitLabel{iOpt}), '%f-%fhz');
                    if (length(freqband) == 2) && ((freqband(1) < freqband(2)) || (freqband(2) == 0)) && all(freqband >= 0)
                        LinesFilter(iLine,:) = freqband(:)';
                    else
                        disp(['BST> Montage: Invalid frequency band "' splitLabel{iOpt} '"']);
                    end
                else
                    disp(['BST> Montage: Invalid option "' splitLabel{iOpt} '"']);
                end
            end
        end
    else
        LinesColor = [];
        LinesFilter = [];
    end
end


%% ===== GET RELATED NIRS CHANNELS =====
function AllChannels = GetRelatedNirsChannels(Channels, ChannelName)
    % Parse all the NIRS channel names
    iNirs = channel_find(Channels, 'NIRS');
    [S,D,WL] = ParseNirsChannelNames({Channels(iNirs).Name});
    % Parse target
    [St, Dt, WLt] = ParseNirsChannelNames(ChannelName);
    % Get corresponding channels
    iSelChan = find((S == St) & (D == Dt));
    % Get channel names
    AllChannels = unique({Channels(iSelChan).Name, sprintf('S%dD%d', St, Dt), ChannelName});
end

%% ===== CLEAN MONTAGE NAME =====
function montageName = CleanMontageName(montageName)
    % Remove subject name
    iColon = strfind(montageName, ': ');
    if ~isempty(iColon) && (iColon + 2 < length(montageName))
        montageName = montageName(iColon(1)+2:end);
    end
    % Remove other tags
    montageName = strrep(montageName, '(local average ref)', '');
    montageName = strrep(montageName, '[tmp]', '');
    montageName = strtrim(montageName);
end

%% ===== EXTRACT LETTERS & NUMBER FROM 10-20 EEG CHANNELS =====
function [letters, number] = GetEeg1020ChannelParts(channelName)
    letters = [];
    number = [];
    
    % If we have multiple channels at once, just return the first one
    split = strfind(channelName, '/');
    if ~isempty(split)
        channelName = channelName(1:split - 1);
    end

    % Break down of regexp:
    %  ^\s*          : Skip begginning spaces if any
    %  ([A-Zp]{1,3}) : Extract 1 to 3 letters (all uppercase except 'p')
    %  (z|[1-9]|10)  : Extract 1-10 number or 'z' for zero
    %  h?            : The 10-5 extension adds an 'h' to some channels, ignore
    %  ?\s*$         : Skip ending spaces if any
    % Example: AFF6h -> AFF, 6
    match = regexp(channelName, '^\s*([A-Zp]{1,3})(z|[1-9]|10)h?\s*$', 'tokens');
    if ~isempty(match)
        letters = match{1}{1};
        number = match{1}{2};
        n = str2num(number);
        if ~isempty(n)
            number = n;
        end
    end
end

%% ===== CHECK IF CHANNEL SETUP IS EEG 10-10/20 =====
function is1020Setup = Is1020Setup(channelNames)
    % Lists the 10-10 setup channel names (includes 10-20 channels)
    bstDefaults = bst_get('EegDefaults');
    chans1020 = [];
    for iDir = 1:length(bstDefaults)
        fList = bstDefaults(iDir).contents;
        for iFile = 1:length(fList)
            if strcmpi(fList(iFile).name, '10-10 65')
                ChannelFile = fList(iFile).fullpath;
                ChannelMat = in_bst_channel(ChannelFile);
                chans1020 = {ChannelMat.Channel.Name};
                break;
            end
        end
    end
    if isempty(chans1020)
        disp('ERROR: Could not find EEG default 10-10 channels.');
        is1020Setup = 0;
        return;
    end

    % Go through active channels and look for 10-10 names
    numChannels = length(channelNames);
    num1020Channels = 0;
    for iChannel = 1:numChannels
        if ismember(channelNames{iChannel}, chans1020)
            num1020Channels = num1020Channels + 1;
        end
    end
    
    % If over half of the channels fit, it is the proper setup
    is1020Setup = (num1020Channels / numChannels) > 0.5;
end

%% ===== COMPUTE CUSTOM MONTAGE =====
function F = ApplyMontage(sMontage, F, DataFile, iMatrixDisp, iMatrixChan)
    if strcmp(sMontage.Type, 'custom')
        if strcmpi(sMontage.Name, 'Head distance')
            % DC corrected distances don't make much sense, warn user
            DataMat = in_bst_data(DataFile, 'DataType');
            if strcmpi(DataMat.DataType, 'raw')
                RawViewerOptions = bst_get('RawViewerOptions');
                if ~isempty(RawViewerOptions) && isfield(RawViewerOptions, 'RemoveBaseline') && ~strcmpi(RawViewerOptions.RemoveBaseline, 'no')
                    java_dialog('warning', ['This montage requires DC offset correction to be off.' 10 ...
                        'Make sure to turn it off before interpreting the results.']);
                end
            end
            % Prepare inputs
            ChannelFile = bst_get('ChannelFileForStudy', DataFile);
            F = process_evt_head_motion('HeadMotionDistance', F, ChannelFile);
        else
            error('Unsupported custom montage.');
        end
    else % matrix, selection, text
        F = sMontage.Matrix(iMatrixDisp, iMatrixChan) * F;
    end
end
