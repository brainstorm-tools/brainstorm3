function varargout = panel_cluster(varargin)
% PANEL_CLUSTER: Create a panel to add/remove/edit clusters of sensors attached to a given 3DViz figure.
% 
% USAGE:  bstPanelNew = panel_cluster('CreatePanel')
%                       panel_cluster('UpdatePanel')
%                       
% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2009-2017

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
        gui_component('ToolbarButton', jToolbar,[],[], IconLoader.ICON_TS_DISPLAY, '<HTML><B>Display cluster time series</B>&nbsp;&nbsp;&nbsp;&nbsp;[ENTER]</HTML>', @DisplayClusters);
        
%         % === MENU NEW ===
%         jMenu = gui_component('Menu', jMenuBar, [], 'New', IconLoader.ICON_MENU, [], [], 11);
%         jMenu.setBorder(BorderFactory.createEmptyBorder(0,2,0,2));
%             gui_component('MenuItem', jMenu, [], 'New cluster: Use selected sensors', IconLoader.ICON_NEW_SEL, [], @(h,ev)CreateNewCluster('Selection'));
%             gui_component('MenuItem', jMenu, [], 'New cluster: List of indices or names', IconLoader.ICON_NEW_IND, [], @(h,ev)CreateNewCluster('Indices'));

        % === MENU EDIT ===
        jMenu = gui_component('Menu', jMenuBar, [], 'Edit', IconLoader.ICON_MENU, [], [], 11);
        jMenu.setBorder(BorderFactory.createEmptyBorder(0,2,0,2));
            % Menu: Set cluster function
            jMenuTs = gui_component('Menu', jMenu, [], 'Set cluster function', IconLoader.ICON_PROPERTIES, [], []);
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

%         % === MENU VIEW ===
%         jMenu = gui_component('Menu', jMenuBar, [], 'View', IconLoader.ICON_MENU, [], [], 11);
%         jMenu.setBorder(BorderFactory.createEmptyBorder(0,2,0,2));
%             gui_component('MenuItem', jMenu, [], 'View time series', IconLoader.ICON_TS_DISPLAY, [], @DisplayClusters);

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
            view_clusters();
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
%% ===== UPDATE CALLBACK =====
function UpdatePanel() %#ok<DEFNU>
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Cluster');
    if isempty(ctrl)
        return;
    end
%     % No raw time or no events structure: exit
%     if isempty(GlobalData.DataSet)
%         gui_enable([ctrl.jPanelList, ctrl.jPanelOptions, ctrl.jMenuBar, ctrl.jToolbar, ctrl.jToolbar2], 0, 1);
%         return
%     else
%         gui_enable([ctrl.jPanelList, ctrl.jPanelOptions, ctrl.jMenuBar, ctrl.jToolbar, ctrl.jToolbar2], 1, 1);
%     end
    % Get current clusters
    sClusters = GetClusters();
%     % If some clusters are available
%     isEnable = ~isempty(sClusters);
%     gui_enable([ctrl.jPanelList, ctrl.jPanelOptions, ctrl.jToolbar2], isEnable, 1);
    % Update clusters JList
    UpdateClustersList(sClusters);
end


%% ===== UPDATE CLUSTERS LIST =====
function UpdateClustersList(sClusters)
    import org.brainstorm.list.*;
    % Get "Cluster" panel controls
    ctrl = bst_get('PanelControls', 'Cluster');
    if isempty(ctrl)
        return;
    end
    % If clusters list was not defined : get it
    if (nargin < 1)
        sClusters = GetClusters();
    end
    % Create a new empty list
    listModel = java_create('javax.swing.DefaultListModel');
    % Add an item in list for each cluster found for target figure
    for iCluster = 1:length(sClusters)
        listModel.addElement(BstListItem(sClusters(iCluster).Function, '', sClusters(iCluster).Label, iCluster));
    end
    % Update list model
    ctrl.jListClusters.setModel(listModel);
    % Reset cluster comments
    ctrl.jLabelClusterSize.setText('');
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


%% ===== GET ALL CLUSTERS =====
% USAGE:  panel_cluster('GetClusters', iClusters)
%         panel_cluster('GetClusters', labels)
function [sClusters, iClusters] = GetClusters(iClusters)
    global GlobalData;
    if (nargin < 1)
        iClusters = 1:length(GlobalData.Clusters);
    elseif ischar(iClusters) || iscell(iClusters)
        if ischar(iClusters)
            labels = {iClusters};
        else
            labels = iClusters;
        end
        iClusters = [];
        for i = 1:length(labels)
            ind = find(strcmpi({GlobalData.Clusters.Label}, labels{i}));
            iClusters = [iClusters, ind];
        end
    end
    sClusters = GlobalData.Clusters(iClusters);
end


%% ===== GET SELECTED CLUSTERS =====
% NB: Returned indices are indices in GlobalData.Clusters array
function [sSelClusters, iSelClusters] = GetSelectedClusters()
    sSelClusters = [];
    iSelClusters = [];
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Cluster');
    if isempty(ctrl)
        return;
    end
    % Get current clusters
    [sClusters, iClusters] = GetClusters();
    if isempty(sClusters)
        return
    end
    % Get JList selected indices
    iSelClusters = uint16(ctrl.jListClusters.getSelectedIndices())' + 1;
    if isempty(iClusters)
        return
    end
    sSelClusters = sClusters(iSelClusters);
    iSelClusters = iClusters(iSelClusters);
end


%% ===== SET SELECTED CLUSTERS =====
% WARNING: Input indices are references in the GlobalData.Clusters array, not in the JList
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
    % Get current scouts
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
% USAGE:  SetClusterFunction(Function, iClusters)
%         SetClusterFunction(Function)            : Set the function for the selected clusters
function SetClusterFunction(Function, iClusters)
    global GlobalData;
    % Get clusters
    if (nargin < 2) || isempty(iClusters)
        [sClusters, iClusters] = GetSelectedClusters();
        if isempty(iClusters)
            return
        end
    else
        sClusters = GetClusters(iClusters);
    end
    % Set function
    [sClusters.Function] = deal(Function);
    % Save clusters
    GlobalData.Clusters(iClusters) = sClusters;
    % Update JList
    UpdateClustersList();
    % Select edited clusters (selection was lost during update)
    SetSelectedClusters(iClusters);
end


%% ===== GET CHANNELS IN CLUSTER =====
function [iChannel, Modality] = GetChannelsInCluster(sCluster, Channel, ChannelFlag) %#ok<DEFNU>
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
    sCluster  = db_template('Cluster');
    iCluster = length(GlobalData.Clusters) + 1;
    % Store current cluster sensors list
    sCluster.Sensors = Sensors;
    
    % === CLUSTER LABEL ===
    % Get other clusters with same surface file
    sOtherClusters = GetClusters();
    % Define clusters labels (Label=index)
    iDisplayIndice = length(sOtherClusters) + 1;
    clusterLabel = ['c', int2str(iDisplayIndice)];
    % Check that the cluster name does not exist yet (else, add a ')
    sCluster.Label = UniqueClusterLabel(clusterLabel);
    
    % === CHECK CLUSTER UNICITY ===
    for i = 1:length(sOtherClusters)
        if isequal(sort(Sensors), sort(sOtherClusters(i).Sensors))
            bst_error('Cluster already exists.', 'Create new cluster', 0);
            sCluster = sOtherClusters(i);
            iCluster = i;
            return
        end
    end
    
    % === Register new cluster ===
    GlobalData.Clusters(iCluster) = sCluster;
    % Update clusters list
    UpdateClustersList();
    % Select new cluster
    SetSelectedClusters(iCluster);
end


%% ===== UNIQUE CLUSTER LABEL =====
function label = UniqueClusterLabel(label)
    % Get other clusters with same surface file
    sOtherClusters = GetClusters();
    % Check that the scout name does not exist yet (else, add a ')
    if ~isempty(sOtherClusters)
        while ismember(label, {sOtherClusters.Label})
            label = [label, ''''];
        end
    end
end


%% ===== VIEW CLUSTERS =====
function DisplayClusters(varargin)
    % Display clusters
    view_clusters();
end

%% ===============================================================================
%  ====== CLUSTERS OPERATIONS ====================================================
%  ===============================================================================
%% ===== REMOVE CLUSTERS =====
% Usage : RemoveClusters(iClusters) : remove a list of clusters
%         RemoveClusters()          : remove the clusters selected in the JList 
function RemoveClusters(varargin)
    global GlobalData;
    % If clusters list is not defined
    if (nargin == 0)
        % Get selected clusters
        [sClusters, iClusters] = GetSelectedClusters();
        % Check whether a cluster is selected
        if isempty(sClusters)
            java_dialog('warning', 'No cluster selected.', 'Remove cluster');
            return
        end
    elseif (nargin == 1)
        iClusters = varargin{1};
        sClusters = GlobalData.Clusters(iClusters);
    else
        bst_error('Invalid call to RemoveClusters.', 'Clusters', 0);
        return
    end

    % Remove clusters definitions from global data structure
    GlobalData.Clusters(iClusters) = [];
    % Update Clusters list
    UpdateClustersList();
end

%% ===== REMOVE ALL CLUSTERS =====
function RemoveAllClusters()
    global GlobalData;
    if ~isempty(GlobalData.Clusters)
        RemoveClusters(1:length(GlobalData.Clusters));
    end
end


%% ===== EDIT CLUSTER LABEL =====
% Rename one and only one selected cluster
function EditClusterLabel()
    global GlobalData;
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
    end
    % Check if if already exists
    if any(strcmpi({GlobalData.Clusters.Label}, newLabel))
        java_dialog('warning', 'Cluster name already exists.', 'Rename selected cluster');
        return;
    end
    % Update cluster definition
    GlobalData.Clusters(iCluster).Label = newLabel;
    % Update JList
    UpdateClustersList();
    % Select edited clusters (selection was lost during update)
    SetSelectedClusters(iCluster);
end



%% ===== SAVE CLUSTERS =====
function SaveClusters(varargin)
    global GlobalData;
    % Get protocol description
    ProtocolInfo = bst_get('ProtocolInfo');
    % Get selected clusters
    sClusters = GetSelectedClusters();
    if isempty(sClusters)
        return
    end
    % Build a default file name
    ClusterFile = bst_fullfile(ProtocolInfo.SUBJECTS, bst_fileparts(GlobalData.CurrentScoutsSurface), ...
                         ['cluster', sprintf('_%s', sClusters.Label), '.mat']);
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


%% ===== LOAD CLUSTER =====
function LoadClusters(varargin)
    global GlobalData;
    % === SELECT FILES TO LOAD ===
    % Get protocol description
    ProtocolInfo = bst_get('ProtocolInfo');
    % Get current subject directory
    sSubject = bst_get('Subject');
    % If no current subject (no recordings were loaded yet)
    curFig = bst_figures('GetCurrentFigure');
    if isempty(sSubject) && ~isempty(curFig)
        % Get subject of current figure 
        curFig = bst_figures('GetCurrentFigure');
        SubjectFile = getappdata(curFig, 'SubjectFile');
        if ~isempty(SubjectFile)
            sSubject = bst_get('Subject', SubjectFile);
        end
    end
    if isempty(sSubject)
        return;
    end
    clusterSubDir = bst_fullfile(ProtocolInfo.SUBJECTS, bst_fileparts(sSubject.FileName));

    % Ask user which are the files to be loaded
    ClusterFiles = java_getfile('open', 'Import clusters', clusterSubDir, ... 
                                'multiple', 'files', ...
                                {{'_cluster'},      'Sensor clusters (*cluster*.mat)', 'BST'}, 1);
    if isempty(ClusterFiles)
        return
    end
    
    % ==== CREATE AND DISPLAY ====
    iNewClustersList = [];
    bst_progress('start', 'Load clusters', 'Load cluster file');
    % Load all files selected by user
    for iFile = 1:length(ClusterFiles)
        % Try to load cluster file
        ClusterMat = load(ClusterFiles{iFile});
        % Loop on all the new clusters
        for i = 1:length(ClusterMat.Clusters)
            % Make all clusters names unique
            ClusterMat.Clusters(i).Label = UniqueClusterLabel(ClusterMat.Clusters(i).Label);
            % Add "Function" field if is doesnt exist
            if ~isfield(ClusterMat.Clusters, 'Function')
                defCluster = db_template('cluster');
                ClusterMat.Clusters(i).Function   = defCluster.Function;
            end
        end
        % Add to current clusters
        iNewClustersList = [iNewClustersList, (1:length(ClusterMat.Clusters))+length(GlobalData.Clusters)];
        GlobalData.Clusters = [GlobalData.Clusters, ClusterMat.Clusters];
    end
    % Update cluster list
    UpdateClustersList();
    % Select first cluster
    SetSelectedClusters(iNewClustersList(1));
    bst_progress('stop');
end







