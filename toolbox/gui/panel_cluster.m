function varargout = panel_cluster(varargin)
% PANEL_CLUSTER: Create a panel to add/remove/edit clusters of sensors attached to a given 3DViz figure.
% 
% USAGE:  bstPanelNew = panel_cluster('CreatePanel')
%                       panel_cluster('UpdatePanel')
%                       panel_cluster('CurrentFigureChanged_Callback')
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
% Authors: Francois Tadel, 2009-2023

eval(macro_method);
end


%% ===== CREATE PANEL =====
function bstPanelNew = CreatePanel() %#ok<DEFNU>
    panelName = 'Cluster';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.icon.*;
    % Create tools panel
    jPanelNew = gui_component('Panel');
    TB_DIM = java_scaled('dimension',25,25);
    % Font size for the lists
    fontSize = round(11 * bst_get('InterfaceScaling') / 100);
    
    % ===== TOOLBAR =====
    jMenuBar = gui_component('MenuBar', jPanelNew, BorderLayout.NORTH);
        jToolbar = gui_component('Toolbar', jMenuBar);
        jToolbar.setPreferredSize(TB_DIM);
        jToolbar.setOpaque(0);
        % First buttons
        gui_component('ToolbarButton', jToolbar,[],[], IconLoader.ICON_NEW_SEL, '<HTML><B>Create new cluster: mouse selection.</B><BR>Use sensors selected in any time series or topography figure.', @(h,ev)CreateNewCluster('Selection'));
        gui_component('ToolbarButton', jToolbar,[],[], IconLoader.ICON_NEW_IND, '<HTML><B>Create new cluster: list of indices/names.</B><BR>Type the list of sensors indices, names or types you want in the new cluster.', @(h,ev)CreateNewCluster('Indices'));
        gui_component('ToolbarButton', jToolbar,[],[], IconLoader.ICON_TS_DISPLAY, '<HTML><B>Display cluster time series</B>&nbsp;&nbsp;&nbsp;&nbsp;[ENTER]</HTML>', @(h,ev)view_clusters());

        % === MENU EDIT ===
        jMenu = gui_component('Menu', jMenuBar, [], 'Edit', IconLoader.ICON_MENU, [], [], 11);
        jMenu.setBorder(BorderFactory.createEmptyBorder(0,2,0,2));
            % Set color
            gui_component('MenuItem', jMenu, [], 'Set color', IconLoader.ICON_COLOR_SELECTION, [], @(h,ev)bst_call(@EditClusterColor));
            % Menu: Set cluster function
            jMenuTs = gui_component('Menu', jMenu, [], 'Set function', IconLoader.ICON_PROPERTIES, [], []);
                gui_component('MenuItem', jMenuTs, [], 'Mean',    [], [], @(h,ev)SetClusterFunction('Mean'));
                gui_component('MenuItem', jMenuTs, [], 'Mean+Std',    [], [], @(h,ev)SetClusterFunction('Mean+Std'));
                gui_component('MenuItem', jMenuTs, [], 'Mean+StdErr',    [], [], @(h,ev)SetClusterFunction('Mean+StdErr'));
                gui_component('MenuItem', jMenuTs, [], 'PCA',     [], [], @(h,ev)SetClusterFunction('PCA'));
                gui_component('MenuItem', jMenuTs, [], 'FastPCA', [], [], @(h,ev)SetClusterFunction('FastPCA'));
                gui_component('MenuItem', jMenuTs, [], 'Max',     [], [], @(h,ev)SetClusterFunction('Max'));
                gui_component('MenuItem', jMenuTs, [], 'Power',   [], [], @(h,ev)SetClusterFunction('Power'));
                gui_component('MenuItem', jMenuTs, [], 'All',     [], [], @(h,ev)SetClusterFunction('All'));
            jMenu.addSeparator();
            gui_component('MenuItem', jMenu, [], 'Rename   [Double-click]', IconLoader.ICON_EDIT,    [], @(h,ev)EditClusterLabel);
            gui_component('MenuItem', jMenu, [], 'Remove   [DEL]',          IconLoader.ICON_DELETE,  [], @(h,ev)RemoveClusters);
            gui_component('MenuItem', jMenu, [], 'Deselect all  [ESC]',     IconLoader.ICON_RELOAD,  [], @(h,ev)SetSelectedClusters(0));
            jMenu.addSeparator();
            gui_component('MenuItem', jMenu, [], 'Export to Matlab', IconLoader.ICON_MATLAB_EXPORT, [], @(h,ev)bst_call(@ExportClustersToMatlab));
            gui_component('MenuItem', jMenu, [], 'Import from Matlab', IconLoader.ICON_MATLAB_IMPORT, [], @(h,ev)bst_call(@ImportClustersFromMatlab));
            jMenu.addSeparator();
            gui_component('MenuItem', jMenu, [], 'Copy to other folders', IconLoader.ICON_COPY,  [], @(h,ev)CopyClusters('AllConditions'));
            gui_component('MenuItem', jMenu, [], 'Copy to other subjects', IconLoader.ICON_COPY,  [], @(h,ev)CopyClusters('AllSubjects'));

    % ===== PANEL MAIN =====
    jPanelMain = java_create('javax.swing.JPanel');
    jPanelMain.setLayout(BoxLayout(jPanelMain, BoxLayout.Y_AXIS));
    jPanelMain.setBorder(BorderFactory.createEmptyBorder(7,7,7,7));
        % ===== FIRST PART =====
        jPanelFirstPart = gui_component('Panel');
        jPanelFirstPart.setPreferredSize(java_scaled('dimension', 100,180));
        jPanelFirstPart.setMaximumSize(java_scaled('dimension', 500,180));
            % ===== Vertical Toolbar =====
            jToolbar2 = gui_component('Toolbar', jPanelFirstPart, BorderLayout.EAST);
            jToolbar2.setOrientation(jToolbar2.VERTICAL);
                gui_component('ToolbarButton', jToolbar2,[],[], IconLoader.ICON_FOLDER_OPEN, 'Load clusters file', @LoadClusters);
                gui_component('ToolbarButton', jToolbar2,[],[], IconLoader.ICON_SAVE, 'Save clusters file', @SaveClusters);          
        
            % ===== Clusters list =====
             jPanelList = gui_component('Panel');
                jBorder = java_scaled('titledborder', 'Available clusters');
                jPanelList.setBorder(jBorder);
                
                jListClusters = java_create('org.brainstorm.list.BstClusterList');
                jListClusters.setCellRenderer(java_create('org.brainstorm.list.BstClusterListRenderer', 'I', fontSize));
                java_setcb(jListClusters, 'ValueChangedCallback', @ListValueChanged_Callback, ...
                                          'KeyTypedCallback',     @ListKeyTyped_Callback, ...
                                          'MouseClickedCallback', @ListClick_Callback);
                jPanelScrollList = java_create('javax.swing.JScrollPane');
                jPanelScrollList.getLayout.getViewport.setView(jListClusters);
                jPanelScrollList.setBorder([]);
                jPanelList.add(jPanelScrollList);
            jPanelFirstPart.add(jPanelList, BorderLayout.CENTER);
        jPanelMain.add(jPanelFirstPart);

        % ===== Clusters options panel =====
        jPanelOptions = gui_river([0,3], [0,5,10,3], 'Options');
            % Add extra space when not on a Mac
            if strncmp(computer,'MAC',3)
                strSpace = '';
            else
                strSpace = '   ';
            end
            % OPTIONS : Cluster size in number of sensors
            gui_component('Label', jPanelOptions, [], 'Number of sensors:');
            jLabelClusterSize = gui_component('Label', jPanelOptions, 'hfill', '');
            % OPTIONS : Overlay clusters/conditions
            gui_component('Label', jPanelOptions, 'br', ['Overlay:' strSpace]);
            jCheckOverlayClusters   = gui_component('CheckBox', jPanelOptions, [], 'Cluster', {Insets(0,0,0,0)});
            jCheckOverlayConditions = gui_component('CheckBox', jPanelOptions, [], 'Files',   {Insets(0,0,0,0)});
        panelPrefSize = jPanelOptions.getPreferredSize();
        jPanelOptions.setMaximumSize(Dimension(32000, panelPrefSize.getHeight()));
        jPanelMain.add(jPanelOptions);
        jPanelMain.add(Box.createVerticalGlue());
    jPanelNew.add(jPanelMain);
    
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jPanelList',       jPanelList, ...
                                  'jPanelOptions',    jPanelOptions, ...
                                  'jMenuBar',         jMenuBar, ...
                                  'jToolbar',         jToolbar, ...
                                  'jToolbar2',        jToolbar2, ...
                                  'jLabelClusterSize',       jLabelClusterSize, ...
                                  'jCheckOverlayClusters',   jCheckOverlayClusters, ...
                                  'jCheckOverlayConditions', jCheckOverlayConditions, ...
                                  'jListClusters',           jListClusters));
end
            

%% =================================================================================
%  === CONTROLS CALLBACKS  =========================================================
%  =================================================================================

%% ===== LIST SELECTION CHANGED CALLBACK =====
function ListValueChanged_Callback(h, ev)
    if ~ev.getValueIsAdjusting()
        % Update number of sensors
        UpdateProperties();
        % Update mouse selection in all the Datasets
        UpdateChannelSelection();
    end
end

%% ===== LIST KEY TYPED CALLBACK =====
function ListKeyTyped_Callback(h, ev)
    switch(uint8(ev.getKeyChar()))
        % DELETE
        case {ev.VK_DELETE, ev.VK_BACK_SPACE}
            RemoveClusters();
        case ev.VK_ENTER
            tree_view_clusters();
        case ev.VK_ESCAPE
            SetSelectedClusters([]);
    end
end

%% ===== LIST CLICK CALLBACK =====
function ListClick_Callback(h, ev)
    % If DOUBLE CLICK
    if (ev.getClickCount() == 2)
        % Rename selection
        EditClusterLabel();
    end
end


%% =================================================================================
%  === EXTERNAL PANEL CALLBACKS  ===================================================
%  =================================================================================
%% ===== CURRENT FIGURE CHANGED =====
function CurrentFigureChanged_Callback(hFig)
    % Update list of clusters in the panel
    UpdatePanel();
    % Update sensor selection
    UpdateChannelSelection();
end

%% ===== UPDATE CALLBACK =====
function UpdatePanel()
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Cluster');
    if isempty(ctrl)
        return;
    end
    % Update clusters JList
    UpdateClustersList();
end


%% ===== UPDATE CLUSTERS LIST =====
function UpdateClustersList()
    import org.brainstorm.list.*;
    % Get "Cluster" panel controls
    ctrl = bst_get('PanelControls', 'Cluster');
    if isempty(ctrl)
        return;
    end
    % Get clusters
    sClusters = GetClusters();

    % Remove temporarily the list callback
    callbackBak = java_getcb(ctrl.jListClusters, 'ValueChangedCallback');
    java_setcb(ctrl.jListClusters, 'ValueChangedCallback', []);
    % Get selected clusters
    SelNames = {};
    selValues = ctrl.jListClusters.getSelectedValues();
    for i = 1:length(selValues)
        SelNames{end+1} = char(selValues(i));
    end
    if ~isempty(SelNames) && ~isempty(sClusters)
        iSelected = find(ismember({sClusters.Label}, SelNames));
    else
        iSelected = [];
    end
    % Create a new empty list
    listModel = java_create('javax.swing.DefaultListModel');
    % Get font with which the list is rendered
    fontSize = round(11 * bst_get('InterfaceScaling') / 100);
    jFont = java.awt.Font('Dialog', java.awt.Font.PLAIN, fontSize);
    tk = java.awt.Toolkit.getDefaultToolkit();
    % Add an item in list for each cluster
    Wmax = 0;
    for i = 1:length(sClusters)
        itemType  = sClusters(i).Function;
        itemText  = sClusters(i).Label;
        itemColor = sClusters(i).Color;
        listModel.addElement(BstListItem(itemType, [], itemText, i, itemColor(1), itemColor(2), itemColor(3)));
        % Get longest string
        W = tk.getFontMetrics(jFont).stringWidth(sClusters(i).Label);
        if (W > Wmax)
            Wmax = W;
        end
    end
    % Update list model
    ctrl.jListClusters.setModel(listModel);
    % Update cell rederer based on longest channel name
    ctrl.jListClusters.setCellRenderer(java_create('org.brainstorm.list.BstClusterListRenderer', 'II', fontSize, Wmax + 28));
    % Select previously selected clusters
    if ~isempty(iSelected)
        ctrl.jListClusters.setSelectedIndices(iSelected - 1);
    end
    % Reset cluster comments
    ctrl.jLabelClusterSize.setText('');

    % Restore callback
    drawnow;
    java_setcb(ctrl.jListClusters, 'ValueChangedCallback', callbackBak);
end



%% ===== UPDATE CLUSTER PROPERTIES DISPLAY =====
function UpdateProperties()
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Cluster');
    if isempty(ctrl)
        return;
    end
    % Get selected clusters
    sClusters = GetSelectedClusters();
    % Add all the selected clusters to compute
    nbSensors = 0;
    for i = 1:length(sClusters)
        nbSensors = nbSensors + length(sClusters(i).Sensors);
    end
    % Format results
    if (nbSensors == 0)
        strSize = '';
    else
        strSize = sprintf(' [ %d ]', nbSensors);
    end
    % Update panel
    ctrl.jLabelClusterSize.setText(strSize);
end

%% ===== UPDATE CHANNEL SELECTION =====
function UpdateChannelSelection()
    % Get selected clusters
    [sClusters, iClusters] = GetSelectedClusters();
    if isempty(sClusters)
        return;
    end
    % Join all the clusters contents
    SensorsNames = unique([sClusters.Sensors]);
    % Update sensors list
    bst_figures('SetSelectedRows', SensorsNames, 0);
end


%% ===== GET CLUSTERS =====
% USAGE:  [sClusters, iDSall, iFigall, hFigall] = panel_cluster('GetClusters')
function [sClusters, iDSall, iFigall, hFigall] = GetClusters()
    global GlobalData;
    % Get current figure
    [hFigall,iFigall,iDSall] = bst_figures('GetCurrentFigure');
    % Check if there are electrodes defined for this file
    if isempty(hFigall) || isempty(GlobalData.DataSet(iDSall).Clusters) || isempty(GlobalData.DataSet(iDSall).Clusters)
        sClusters = [];
        return;
    end
    % Return all the available electrodes
    sClusters = GlobalData.DataSet(iDSall).Clusters;
    ChannelFile = GlobalData.DataSet(iDSall).ChannelFile;
    % Get all the figures that share this channel file
    for iDS = 1:length(GlobalData.DataSet)
        % Skip if not the correct channel file
        if ~file_compare(GlobalData.DataSet(iDS).ChannelFile, ChannelFile)
            continue;
        end
        % Get all the figures
        for iFig = 1:length(GlobalData.DataSet(iDS).Figure)
            if ((iDS ~= iDSall(1)) || (iFig ~= iFigall(1))) && ismember(GlobalData.DataSet(iDS).Figure(iFig).Id.Type, {'DataTimeSeries', '3DViz', 'Topography'})
                iDSall(end+1) = iDS;
                iFigall(end+1) = iFig;
                hFigall(end+1) = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
            end
        end
    end
end


%% ===== SET CLUSTER =====
% USAGE:  iClusters = SetClusters(iClusters=[], sClusters)
%         iClusters = SetClusters('Add', sClusters)
function iClusters = SetClusters(iClusters, sClusters)
    global GlobalData;
    % Parse input
    isAdd = ~isempty(iClusters) && ischar(iClusters) && strcmpi(iClusters, 'Add');
    % Get dataset
    [sClustersOld, iDSall] = GetClusters();
    % If there is no selected dataset
    if isempty(iDSall)
        return;
    end
    % Perform operations only once per dataset
    iDSall = unique(iDSall);
    for iDS = iDSall
        % Reset clusters list
        if isempty(sClusters)
            GlobalData.DataSet(iDS).Clusters(iClusters) = [];
        % Set clusters
        else
            % Add new clusters
            if isAdd
                iClusters = length(GlobalData.DataSet(iDS).Clusters) + (1:length(sClusters));
                % Add clusters
                for i = 1:length(sClusters)
                    % Default cluster name
                    if isempty(sClusters(i).Label)
                        sClusters(i).Label = sprintf('c%d', iClusters(i));
                    end
                    % Make new cluster names unique
                    if ~isempty(GlobalData.DataSet(iDS).Clusters)
                        sClusters(i).Label = file_unique(sClusters(i).Label, {GlobalData.DataSet(iDS).Clusters.Label, sClusters(1:i-1).Label});
                    end
                end
            end
            % Set clusters in global structure
            if isempty(GlobalData.DataSet(iDS).Clusters)
                GlobalData.DataSet(iDS).Clusters = sClusters;
            else
                GlobalData.DataSet(iDS).Clusters(iClusters) = sClusters;
            end
        end
        % Add color if not defined yet
        for i = 1:length(GlobalData.DataSet(iDS).Clusters)
            if isempty(GlobalData.DataSet(iDS).Clusters(i).Color)
                ColorTable = panel_scout('GetScoutsColorTable');
                iColor = mod(i-1, length(ColorTable)) + 1;
                GlobalData.DataSet(iDS).Clusters(i).Color = ColorTable(iColor,:);
            end
        end
    end
    % Mark channel file as modified (only in first dataset)
    GlobalData.DataSet(iDSall(1)).isChannelModified = 1;
end


%% ===== GET SELECTED CLUSTERS =====
% NB: Returned indices are indices in Clusters array
function [sSelClusters, iSelClusters] = GetSelectedClusters()
    sSelClusters = [];
    iSelClusters = [];
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Cluster');
    if isempty(ctrl)
        return;
    end
    % Get current clusters
    sClusters = GetClusters();
    if isempty(sClusters)
        return
    end
    % Get JList selected indices
    iSelClusters = uint16(ctrl.jListClusters.getSelectedIndices())' + 1;
    if isempty(iSelClusters)
        return
    end
    sSelClusters = sClusters(iSelClusters);
end


%% ===== SET SELECTED CLUSTERS =====
% WARNING: Input indices are references in the Clusters array, not in the JList
function SetSelectedClusters(iSelClusters, isUpdateMouseSel)
    if (nargin < 2) || isempty(isUpdateMouseSel)
        isUpdateMouseSel = 1;
    end
    % === CHECK FOR MODIFICATIONS ===
    iSelClusters = iSelClusters - 1;
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Cluster');
    if isempty(ctrl)
        return;
    end
    % Get previous selection
    iPrevItems = ctrl.jListClusters.getSelectedIndices();
    % If selection did not change: exit
    if isequal(iPrevItems, iSelClusters) || (isempty(iPrevItems) && isequal(iSelClusters, -1))
        return
    end
    
    % === UPDATE SELECTION ===  
    % Temporality disables JList selection callback
    jListCallback_bak = java_getcb(ctrl.jListClusters, 'ValueChangedCallback');
    java_setcb(ctrl.jListClusters, 'ValueChangedCallback', []);
    % Select items in JList
    if isempty(iSelClusters)
        ctrl.jListClusters.setSelectedIndices(-1);
    else
        ctrl.jListClusters.setSelectedIndices(iSelClusters);
    end
    % Restore JList callback
    java_setcb(ctrl.jListClusters, 'ValueChangedCallback', jListCallback_bak);
    % Update panel "Clusters" fields
    UpdateProperties();
    if isUpdateMouseSel
        % Update selected channels for all figures
        UpdateChannelSelection();
    end
end


%% ===== GET CLUSTER DISPLAY TYPE =====
% ClustersOptions:
%    |- overlayClusters   : {0, 1}
%    |- overlayConditions : {0, 1}
function ClustersOptions = GetClusterOptions() %#ok<DEFNU>
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Cluster');
    if isempty(ctrl)
        ClustersOptions = [];
        return;
    end
    % Get current clusters
    sClusters = GetClusters();
    % If at least one of the cluster functions is "All", ignore the overlay checkboxes
    if any(strcmpi({sClusters.Function}, 'All'))
        ClustersOptions.overlayClusters   = 0;
        ClustersOptions.overlayConditions = 0;
    else
        % Overlay
        ClustersOptions.overlayClusters   = ctrl.jCheckOverlayClusters.isSelected();
        ClustersOptions.overlayConditions = ctrl.jCheckOverlayConditions.isSelected();
    end
end


%% ===== SET CLUSTER DISPLAY TYPE =====
function SetClusterOptions(overlayClusters, overlayConditions) %#ok<DEFNU>
    % Overlay
    if ~isempty(overlayClusters)
        ctrl.jCheckOverlayClusters.setSelected(overlayClusters);
    end
    if ~isempty(overlayConditions)
        ctrl.jCheckOverlayConditions.setSelected(overlayConditions);
    end
end


%% ===== SET CLUSTER FUNCTION =====
% USAGE:  SetClusterFunction(Function)
function SetClusterFunction(Function)
    % Get select clusters
    [sClusters, iClusters] = GetSelectedClusters();
    if isempty(iClusters)
        return
    end
    % Set function
    [sClusters.Function] = deal(Function);
    % Save clusters
    SetClusters(iClusters, sClusters);
    % Update JList
    UpdateClustersList();
    % Select edited clusters (selection was lost during update)
    SetSelectedClusters(iClusters);
end


%% ===== GET CHANNELS IN CLUSTER =====
function [iChannel, Modality] = GetChannelsInCluster(sCluster, Channel, ChannelFlag)
    % Get channels
    iChannel = zeros(1, length(sCluster.Sensors));
    for ic = 1:length(iChannel)
        tmp = find(strcmpi(sCluster.Sensors{ic}, {Channel.Name}));
        if isempty(tmp)
            iChannel = [];
            bst_error(['Sensor "' sCluster.Sensors{ic} '" does not exist.'], 'Clusters', 0);
            return;
        end
        iChannel(ic) = tmp;
    end
    % Check cluster homogeneity
    Modality = unique({Channel(iChannel).Type});
    if (length(Modality) > 1)
        iChannel = [];
        bst_error('Sensors in a cluster must be of the same type.', 'Clusters', 0);
        return;
    end
    Modality = Modality{1};
    % Remove channels that are "BAD"
    iBadChannels = find(ChannelFlag == -1);
    iChannel = setdiff(iChannel, iBadChannels);
    % Check if there are still some channels in the cluster
    if isempty(iChannel)
        iChannel = [];
        bst_error('All the channels in the cluster are BAD.', 'Clusters', 0);
        return;
    end
end

%% ===== CREATE NEW CLUSTER =====
% Usage:  [sCluster, iCluster] = CreateNewCluster(Sensors)      : Cell array of sensors names
%         [sCluster, iCluster] = CreateNewCluster('Selection')  : Get the current sensors selected by the user with his mouse
%         [sCluster, iCluster] = CreateNewCluster('Indices')    : Ask user to type the list of sensors indices
function [sCluster, iCluster] = CreateNewCluster(Sensors)
    global GlobalData;
    % Update current figure
    bst_figures('CheckCurrentFigure');
    
    % === GET SENSORS NAMES ===
    if ischar(Sensors) 
        % Get selected figure
        [hFig,iFig,iDS] = bst_figures('GetCurrentFigure');
        if isempty(hFig)
            bst_error('No figure available.', 'Create new cluster', 0);
            return
        end
        
        % SELECTION: Get mouse selected sensors
        if strcmpi(Sensors, 'Selection')
            % Get the mouse selected sensors (generic interface)
            [SelChan, iSelChan] = bst_figures('GetSelectedChannels', iDS);
            % Selected sensors = intersection(mouse selection, figure sensors)
            iSensors = intersect(iSelChan, GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels);
            % If no selection in current figure: error
            if isempty(iSensors)
                bst_error('Please select at least one sensor in the current figure.', 'Create new cluster', 0);
                return;
            end
        % INDICES: Ask user to give a list of sensors indices
        elseif strcmpi(Sensors, 'Indices')
            % Ask user to enter manually the indices of the sensors
            res = java_dialog('input', ['Enter the list of channels separated with commas.' 10 10 ...
                                        'Channels can be selected by:' 10 ...
                                        '     1) Types: "MEG, Misc"' 10 ...
                                        '     2) Names: "EEG021, EEG023"' 10 ...
                                        '     3) Indices: "5, 12, 13"' 10 10], 'Create cluster');
            if isempty(res)
                return;
            end
            % Get the channels indices
            iSensors = channel_find(GlobalData.DataSet(iDS).Channel, res);
            % If invalid sensors list
            if isempty(iSensors)
                bst_error('Invalid sensors selection.', 'Create new cluster', 0);
                return;
            end
            % Order sensors names and make unique
            iSensors = unique(iSensors);
        end
        % Check that the sensors are all of the same type
        uniqueType = unique({GlobalData.DataSet(iDS).Channel(iSensors).Type});
        if (length(uniqueType) > 1)
            java_dialog('warning', ['Warning: Sensors in a cluster must be of the same type.' 10 10 ...
                                    'Different types in this selection: ' uniqueType{1}, ', ' uniqueType{2}, 10 10], 'Create cluster');
            return
        end
        % Get the names of the mouse selected sensors
        Sensors = {GlobalData.DataSet(iDS).Channel(iSensors).Name};
    end

    % === NEW CLUSTER ===
    % New cluster structure
    sCluster = db_template('Cluster');
    % Store current cluster sensors list
    sCluster.Sensors = Sensors;
    % Add clusters
    iCluster = SetClusters('Add', sCluster);
    % Retrieve added cluster
    sClusters = GetClusters();
    sCluster  = sClusters(iCluster);
    % Update clusters list
    UpdateClustersList();
    % Select new cluster
    SetSelectedClusters(iCluster);
end


%% ===============================================================================
%  ====== CLUSTERS OPERATIONS ====================================================
%  ===============================================================================
%% ===== REMOVE CLUSTERS =====
% Usage : RemoveClusters()  : remove the clusters selected in the JList 
function RemoveClusters()
    global GlobalData;
    % Get dataset
    [sClusters, iDSall, iFigall] = GetClusters();
    if isempty(iDSall)
        return;
    end
    % Get selected clusters
    [sClusters, iClusters] = GetSelectedClusters();
    % Check whether a cluster is selected
    if isempty(sClusters)
        java_dialog('warning', 'No cluster selected.', 'Remove cluster');
        return
    end
    % Ask for confirmation
    if (length(sClusters) == 1)
        strConfirm = ['Delete cluster "' sClusters(1).Label '"?'];
    else
        strConfirm = ['Delete ' num2str(length(sClusters)) ' clusters?'];
    end
    if ~java_dialog('confirm', strConfirm)
        return;
    end
    % Remove clusters definitions from global data structure
    for iDS = unique(iDSall)
        GlobalData.DataSet(iDS).Clusters(iClusters) = [];
        GlobalData.DataSet(iDS).isChannelModified = 1;
    end
    % Update Clusters list
    UpdateClustersList();
    % Reset list of selected sensors
    bst_figures('SetSelectedRows', [], 0);
end


%% ===== EDIT CLUSTER LABEL =====
% Usage : EditClusterLabel()  : Interactive edition of cluster name
function EditClusterLabel()
    % Get all clusters
    sClustersAll = GetClusters();
    % Get selected clusters
    [sCluster, iCluster] = GetSelectedClusters();
    % Warning message if no cluster selected
    if isempty(sCluster)
        java_dialog('warning', 'No cluster selected.', 'Rename selected cluster');
        return;
    % If more than one cluster selected: keep only the first one
    elseif (length(sCluster) > 1)
        iCluster = iCluster(1);
        sCluster = sCluster(1);
        SetSelectedClusters(iCluster);
    end
    % Ask user for a new Cluster Label
    newLabel = java_dialog('input', sprintf('Please enter a new label for cluster "%s":', sCluster.Label), ...
                           'Rename selected cluster', [], sCluster.Label);
    if isempty(newLabel) || strcmpi(newLabel, sCluster.Label)
        return
    elseif ~isempty(sClustersAll) && any(strcmpi({sClustersAll.Label}, newLabel))
        java_dialog('warning', 'Cluster name already exists.', 'Rename selected cluster');
        return;
    end

    % Update cluster definition
    sCluster.Label = newLabel;
    SetClusters(iCluster, sCluster);
    % Update JList
    UpdateClustersList();
    % Select edited clusters (selection was lost during update)
    SetSelectedClusters(iCluster);
end


%% ===== EDIT CLUSTER COLOR =====
function EditClusterColor(newColor)
    % Get selected clusters
    [sSelClusters, iSelClusters] = GetSelectedClusters();
    if isempty(iSelClusters)
        java_dialog('warning', 'No cluster selected.', 'Edit cluster color');
        return
    end
    % If color is not specified in argument : ask it to user
    if (nargin < 1)
        newColor = java_dialog('color');
        if (length(newColor) ~= 3) || all(sSelClusters(1).Color(:) == newColor(:))
            return
        end
    end
    % Update cluster color
    for i = 1:length(sSelClusters)
        sSelClusters(i).Color = newColor;
    end
    % Save clusters
    SetClusters(iSelClusters, sSelClusters);
    % Update clusters list
    UpdateClustersList();
end


%% ===== SAVE CLUSTERS =====
function SaveClusters(varargin)
    % Get selected clusters
    sClusters = GetSelectedClusters();
    if isempty(sClusters)
        return
    end
    % Default folder name
    ClusterDir = GetDefaultClusterDir();
    % Build a default file name
    ClusterFile = bst_fullfile(ClusterDir, ['cluster', sprintf('_%s', sClusters.Label), '.mat']);
    % Get filename where to store the filename
    ClusterFile = java_getfile( 'save', 'Save selected clusters', ClusterFile, ... 
                                'single', 'files', ...
                                {{'_cluster'}, 'Brainstorm sensor clusters (*cluster*.mat)', 'BST'}, 1);
    if isempty(ClusterFile)
        return;
    end
    % Make sure that filename contains the 'cluster' tag
    if isempty(strfind(ClusterFile, '_cluster')) && isempty(strfind(ClusterFile, 'cluster_'))
        [filePath, fileBase, fileExt] = bst_fileparts(ClusterFile);
        ClusterFile = bst_fullfile(filePath, ['cluster_' fileBase fileExt]);
    end
    % Save file
    FileMat.Clusters = sClusters;
    bst_save(ClusterFile, FileMat, 'v7');
end


%% ===== GET DEFAULT CLUSTER DIR =====
function ClusterDir = GetDefaultClusterDir()
    global GlobalData;
    % Get subject of current figure 
    [hFig,iFig,iDS] = bst_figures('GetCurrentFigure');
    if ~isempty(iDS) && ~isempty(GlobalData.DataSet(iDS).SubjectFile)
        SubjectFile = GlobalData.DataSet(iDS).SubjectFile;
    % Get current subject in the database
    else
        sSubject = bst_get('Subject');
        if ~isempty(sSubject)
            SubjectFile = sSubject.FileName;
        else
            SubjectFile = [];
        end
    end
    % Get subject anatomy folder
    if ~isempty(SubjectFile)
        ClusterDir = bst_fileparts(file_fullpath(SubjectFile));
    else
        ClusterDir = '';
    end
end


%% ===== LOAD CLUSTER =====
function LoadClusters(varargin)
    % Get default cluster folder
    ClusterDir = GetDefaultClusterDir();
    % Ask user which are the files to be loaded
    [ClusterFiles, FileFormat] = java_getfile(...
        'open', 'Import clusters', ClusterDir, ... 
        'multiple', 'files', ...
        bst_get('FileFilters', 'clusterin'), 1);
    if isempty(ClusterFiles)
        return
    end
    
    % ==== CREATE AND DISPLAY ====
    iNewClusters = [];
    bst_progress('start', 'Load clusters', 'Load cluster file');
    % Load all files selected by user
    for iFile = 1:length(ClusterFiles)
        % Load clusters
        sClusters = in_clusters(ClusterFiles{iFile}, FileFormat);
        % Add to current clusters
        iNewClusters = [iNewClusters, SetClusters('Add', sClusters)];
    end
    % Update cluster list
    UpdateClustersList();
    % Select first cluster
    if isempty(iNewClusters)
        SetSelectedClusters(iNewClusters(1));
    end
    bst_progress('stop');
end


%% ===== COPY CLUSTERS =====
function CopyClusters(Target)
    global GlobalData;
    % Get loaded clusters
    [sClusters, iDSall] = GetSelectedClusters();
    if isempty(sClusters)
        bst_error('No clusters selected.', 'Copy clusters', 0);
        return
    end
    % Copy clusters
    db_set_clusters(GlobalData.DataSet(iDSall(1)).ChannelFile, Target, sClusters);
end


%% ===== EXPORT CLUSTERS TO MATLAB =====
function ExportClustersToMatlab()
    % Get selected clusters
    sClusters = GetSelectedClusters();
    % If nothing selected, take all clusters
    if isempty(sClusters)
        sClusters = GetClusters();
    end
    % If nothing: exit
    if isempty(sClusters)
        return;
    end
    % Export to the base workspace
    export_matlab(sClusters, []);
    % Display in the command window the selected clusters
    disp([10 'List of sensors for each cluster:']);
    for i = 1:length(sClusters)
        disp(['   ' sClusters(i).Label ': ' sprintf('%s ', sClusters(i).Sensors{:})]);
    end
    disp(' ');
end


%% ===== IMPORT CLUSTERS FROM MATLAB =====
function ImportClustersFromMatlab()
    % Export to the base workspace
    sClusters = in_matlab_var([], 'struct');
    if isempty(sClusters)
        return;
    end
    % Check structure
    sTemplate = db_template('cluster');
    if isempty(sClusters) || ~isequal(fieldnames(sClusters), fieldnames(sTemplate))
        bst_error('Invalid clusters structure.', 'Import from Matlab', 0);
        return;
    end
    % Save new cluster
    iNewCluster = SetClusters('Add', sClusters);
    % Update "Clusters Manager" panel
    UpdateClustersList();
    % Select last cluster in list (new cluster)
    SetSelectedClusters(iNewCluster);
end
