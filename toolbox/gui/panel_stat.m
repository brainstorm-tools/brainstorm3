function varargout = panel_stat(varargin)
% PANEL_STAT: Create a panel for online statistical thresholding.
% 
% USAGE:  bstPanelNew = panel_stat('CreatePanel')
%                       panel_stat('UpdatePanel')

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2010-2019

eval(macro_method);
end


%% ===== CREATE PANEL =====
function bstPanelNew = CreatePanel() %#ok<DEFNU>
    panelName = 'Stat';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.icon.*;
    TB_DIM = java_scaled('dimension', 25,25);
    % Font size for the lists
    fontSize = round(11 * bst_get('InterfaceScaling') / 100);
    
    % Create tools panel
    jPanelNew = gui_component('Panel');
    jPanelNew.setBorder(BorderFactory.createEmptyBorder(7,0,7,0));
    % Top part (does not rescale)
    jPanelTop = gui_river();
    jPanelNew.add(jPanelTop, BorderLayout.NORTH)
    
    % ===== THRESHOLDING =====
    jPanelThresh = gui_river([4,1], [2,8,4,0], 'Thresholding');
        % Threshold p-value: Title
        jLabelThresh = gui_component('Label', jPanelThresh, [], '<HTML>Significance level &alpha;: ');
        % Threshold p-value: Value
        jTextPThresh = gui_component('Text', jPanelThresh, 'tab', '');
        jTextPThresh.setHorizontalAlignment(JLabel.RIGHT);
        jTextPThresh.setPreferredSize(java_scaled('dimension', 60,23));
        java_setcb(jTextPThresh, 'ActionPerformedCallback', @(h,ev)SaveOptions(), ...
                                 'FocusLostCallback',       @(h,ev)ev.getSource().getParent().grabFocus());                               
        % Threshold duration: Title
        gui_component('Label', jPanelThresh, 'br', 'Minimum duration: ');
        % Threshold duration: Value
        jTextDurThresh = gui_component('Text', jPanelThresh, 'tab', '');
        jTextDurThresh.setHorizontalAlignment(JLabel.RIGHT);
        jTextDurThresh.setPreferredSize(java_scaled('dimension', 60,23));
        java_setcb(jTextDurThresh, 'ActionPerformedCallback', @(h,ev)SaveOptions(), ...
                                   'FocusLostCallback',       @(h,ev)ev.getSource().getParent().grabFocus());
        gui_component('Label', jPanelThresh, '', 'ms');
        
    jPanelTop.add('hfill', jPanelThresh);
        
    % ===== MULTIPLE COMPARISONS =====
    jPanelOptions = gui_river([4,2], [2,8,4,0], 'Multiple comparisons');
        jLabelType         = gui_component('Label',    jPanelOptions, 'br',  'Correction type:');
        jLabelControl      = gui_component('Label',    jPanelOptions, 'tab', 'Control over dims: ');
        jRadioCorrNo       = gui_component('radio',    jPanelOptions, 'br',  'Uncorrected',  [], [], @(h,ev)SaveOptions());
        jRadioControlSpace = gui_component('checkbox', jPanelOptions, 'tab', '1: Signals',   [], [], @(h,ev)SaveOptions());
        jRadioCorrBonf     = gui_component('radio',    jPanelOptions, 'br',  'Bonferroni',   [], [], @(h,ev)SaveOptions());
        jRadioControlTime  = gui_component('checkbox', jPanelOptions, 'tab', '2: Time',      [], [], @(h,ev)SaveOptions());
        jRadioCorrFdr      = gui_component('radio',    jPanelOptions, 'br',  'FDR',          [], [], @(h,ev)SaveOptions());
        jRadioControlFreq  = gui_component('checkbox', jPanelOptions, 'tab', '3: Frequency', [], [], @(h,ev)SaveOptions());
        % Create button group
        jButtonGroup = ButtonGroup();
        jButtonGroup.add(jRadioCorrNo);
        jButtonGroup.add(jRadioCorrBonf);
        jButtonGroup.add(jRadioCorrFdr);
    jPanelTop.add('br hfill', jPanelOptions);

    % ===== CLUSTER LIST =====
    jPanelClusterList = gui_component('Panel');
    jPanelClusterList.setVisible(0);
        jBorder = java_scaled('titledborder', 'Clusters');
        jPanelClusterList.setBorder(BorderFactory.createCompoundBorder(BorderFactory.createEmptyBorder(0,9,0,9),jBorder));
        % Toolbar
        jMenuBar = gui_component('MenuBar', jPanelClusterList, BorderLayout.NORTH);
            % Toolbar
            jToolbar = gui_component('Toolbar', jMenuBar);
            jToolbar.setPreferredSize(TB_DIM);
            jToolbar.setOpaque(0);
            %  Toolbar buttons
            jRadioShowAll = gui_component('ToolbarToggle', jToolbar, [], [], {IconLoader.ICON_SCOUT_ALL, TB_DIM}, 'Display all clusters in figures', @ButtonShow_Callback);
            jRadioShowSel = gui_component('ToolbarToggle', jToolbar, [], [], {IconLoader.ICON_SCOUT_SEL, TB_DIM}, 'Display only selected clusters in figures', @ButtonShow_Callback);
            jRadioShowAll.setSelected(1);
            gui_component('ToolbarButton', jToolbar, [], [], {IconLoader.ICON_COLOR_SELECTION, TB_DIM}, 'Set clusters colormap', @ButtonColormap_Callback);
            gui_component('ToolbarButton', jToolbar, [], [], {IconLoader.ICON_RELOAD, TB_DIM}, 'Reset display options', @(h,ev)ResetOptions);
            % Menu: Jump to...
            jMenuJump = gui_component('Menu', jMenuBar, [], 'Jump to', IconLoader.ICON_MENU, [], [], 11);
            jMenuJump.setBorder(BorderFactory.createEmptyBorder(0,2,0,2));
        % Clusters list
        jListClusters = java_create('org.brainstorm.list.BstClusterList');
        jListClusters.setCellRenderer(java_create('org.brainstorm.list.BstClusterListRenderer', 'I', fontSize));
        jListClusters.setBackground(Color(1,1,1));
        java_setcb(jListClusters, ...
            'ValueChangedCallback', @ClustersListValueChanged_Callback, ...
            'KeyTypedCallback',     @ClustersListKeyTyped_Callback, ...
            'MouseClickedCallback', @ClustersListClick_Callback);
        jPanelScrollList = JScrollPane();
        jPanelScrollList.getLayout.getViewport.setView(jListClusters);
        %jPanelScrollList.setBorder(BorderFactory.createEmptyBorder(7,9,7,7));
        jPanelClusterList.add(jPanelScrollList, BorderLayout.CENTER);
    jPanelNew.add(jPanelClusterList, BorderLayout.CENTER);
    
    % Controls list
    ctrl = struct('jLabelThresh',       jLabelThresh, ...
                  'jTextPThresh',       jTextPThresh, ...
                  'jTextDurThresh',     jTextDurThresh, ...
                  'jPanelOptions',      jPanelOptions, ...
                  'jRadioCorrNo',       jRadioCorrNo, ...
                  'jRadioCorrBonf',     jRadioCorrBonf, ...
                  'jRadioCorrFdr',      jRadioCorrFdr, ...
                  'jRadioControlSpace', jRadioControlSpace, ...
                  'jRadioControlTime',  jRadioControlTime, ...
                  'jRadioControlFreq',  jRadioControlFreq, ...
                  'jPanelClusterList',  jPanelClusterList, ...
                  'jListClusters',      jListClusters, ...
                  'jMenuJump',          jMenuJump, ...
                  'jRadioShowAll',      jRadioShowAll, ...
                  'jRadioShowSel',      jRadioShowSel);
    % Set current options
    UpdatePanel(ctrl);
    % Create the BstPanel object that is returned by the function
    bstPanelNew = BstPanel(panelName, jPanelNew, ctrl);


%% =================================================================================
%  === CONTROLS CALLBACKS  =========================================================
%  =================================================================================        
    %% ===== BUTTON: CLUSTER SHOW =====
    function ButtonShow_Callback(hObj, ev)
        % If the other button is selected: unselect it
        if jRadioShowSel.isSelected() && jRadioShowAll.isSelected()
            if (ev.getSource() == jRadioShowSel)
                jRadioShowAll.setSelected(0);
            else
                jRadioShowSel.setSelected(0);
            end
        end
        % Update all figures
        UpdateClustersDisplay();
    end

    %% ===== BUTTON: SET COLORMAP =====
    function ButtonColormap_Callback(h,ev)
        % Edit current colormap
        isModified = bst_colormaps('NewCustomColormap', 'cluster', 'custom_userclust', 64);
        if ~isModified
            return;
        end
        % Get figure clusters
        StatClusters = GetFigureClusters();
        % Update cluster list
        UpdateClustersList(StatClusters, 1);
        % Update figures
        UpdateClustersDisplay();
    end

    %% ===== RESET DISPLAY OPTIONS =====
    function ResetOptions()
        % Display all clusters
        jRadioShowAll.setSelected(1);
        jRadioShowSel.setSelected(0);
        % Reset the colormap
        bst_colormaps('RestoreDefaults', 'cluster');
        % Get figure clusters
        StatClusters = GetFigureClusters();
        % Update cluster list
        UpdateClustersList(StatClusters, 1);
        % Update figures
        UpdateClustersDisplay();
    end

    %% ===== LIST SELECTION CHANGED CALLBACK =====
    function ClustersListValueChanged_Callback(h, ev)
        if ~ev.getValueIsAdjusting()
            % Get display options
            ClustersOptions = GetClustersOptions();
            if isempty(ClustersOptions)
                return;
            end
            % Display/hide scouts
            if strcmpi(ClustersOptions.showSelection, 'select')
                % Update structure alpha (display only selected Structures)
                UpdateClustersDisplay();
            end
        end
    end

    %% ===== LIST KEY TYPED CALLBACK =====
    function ClustersListKeyTyped_Callback(h, ev)
%         switch(uint8(ev.getKeyChar()))
%             % DELETE
%             case {ev.VK_DELETE, ev.VK_BACK_SPACE}
%                 RemoveScouts();
%             case ev.VK_ENTER
%                 view_scouts();
%             case uint8('+')
%                 EditScoutsSize('Grow1');
%             case uint8('-')
%                 EditScoutsSize('Shrink1');
%             case ev.VK_ESCAPE
%                 SetSelectedScouts(0);
%         end
    end

    %% ===== LIST CLICK CALLBACK =====
    function ClustersListClick_Callback(h, ev)
%         % If DOUBLE CLICK
%         if (ev.getClickCount() == 2)
%             % Rename selection
%             EditScoutLabel();
%         end
    end
end



%% =================================================================================
%  === EXTERNAL PANEL CALLBACKS  ===================================================
%  =================================================================================
%% ===== GET DISPLAY OPTIONS =====
function ClustersOptions = GetClustersOptions()
    % Default values
    ClustersOptions.showSelection = 'all';
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Stat');
    if isempty(ctrl)
        return;
    end
    % Show selection
    if ~ctrl.jRadioShowSel.isSelected() && ~ctrl.jRadioShowAll.isSelected()
        ClustersOptions.showSelection = 'none';
    elseif ctrl.jRadioShowSel.isSelected()
        ClustersOptions.showSelection = 'select';
    else
        ClustersOptions.showSelection = 'all';
    end
end


%% ===== UPDATE PANEL =====
function UpdatePanel(ctrl)
    % Get panel controls
    if (nargin == 0) || isempty(ctrl)
        ctrl = bst_get('PanelControls', 'Stat');
    end
    % Get current options
    StatThreshOptions = bst_get('StatThreshOptions');
    % p-threshold
    ctrl.jTextPThresh.setText(num2str(StatThreshOptions.pThreshold, '%g'));
    % duration threshold
    ctrl.jTextDurThresh.setText(num2str(round(StatThreshOptions.durThreshold * 1000), '%d'));
    % Multiple comparisons
    switch (StatThreshOptions.Correction)
        case 'no'
            ctrl.jRadioCorrNo.setSelected(1);
        case 'bonferroni'
            ctrl.jRadioCorrBonf.setSelected(1);
        case 'fdr'
            ctrl.jRadioCorrFdr.setSelected(1);
    end
    % Control
    if ismember(1, StatThreshOptions.Control)
        ctrl.jRadioControlSpace.setSelected(1);
    end
    if ismember(2, StatThreshOptions.Control)
        ctrl.jRadioControlTime.setSelected(1);
    end
    if ismember(3, StatThreshOptions.Control)
        ctrl.jRadioControlFreq.setSelected(1);
    end
end


%% ===== CURRENT FIGURE CHANGED =====
function CurrentFigureChanged_Callback(hFig) %#ok<DEFNU>
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Stat');
    if isempty(ctrl)
        return;
    end
    % Get figure clusters
    StatClusters = GetFigureClusters(hFig);
    % Disable multiple comparisons panel if results are alredy corrected
    isEnableCorrect = isempty(StatClusters) || ~isfield(StatClusters, 'Correction') || isempty(StatClusters.Correction) || ismember(StatClusters.Correction, {'no','none'});
    gui_enable(ctrl.jPanelOptions, isEnableCorrect, 1);
    % Progress bar
    isVisible = bst_progress('isVisible');
    if ~isVisible
        bst_progress('start', 'Clusters', 'Updating clusters list...');
    end
    % Update cluster list
    UpdateClustersList(StatClusters);
    % Update cluster menus
    UpdateClusterMenus(hFig);
    % Close progress bar
    if ~isVisible
        bst_progress('stop');
    end
end


%% ===== GET FIGURE CLUSTERS =====
function [StatClusters,StatFile,iFig,iDS] = GetFigureClusters(hFig)
    global GlobalData;
    % Default current figure
    if (nargin < 1) || isempty(hFig)
        hFig = bst_figures('GetCurrentFigure');
    end
    % Get figure
    [hFig,iFig,iDS] = bst_figures('GetFigure', hFig); 
    % Get loaded clusters
    StatFile = [];
    StatClusters = [];
    switch GlobalData.DataSet(iDS).Figure(iFig).Id.Type
        case 'DataTimeSeries'
            TsInfo = getappdata(hFig, 'TsInfo');
            if ~isempty(TsInfo) && ~isempty(TsInfo.FileName)
                StatFile = TsInfo.FileName;
            end
        case 'ResultsTimeSeries'
            TsInfo = getappdata(hFig, 'TsInfo');
            if ~isempty(TsInfo) && ~isempty(TsInfo.FileName)
                StatFile = TsInfo.FileName;
            end
        case {'3DViz', 'MriViewer'}
            TessInfo = getappdata(hFig, 'Surface');
            for iTess = 1:length(TessInfo)
                if ~isempty(TessInfo(iTess).DataSource) && ~isempty(TessInfo(iTess).DataSource.FileName)
                    StatFile = TessInfo(iTess).DataSource.FileName;
                    break;
                end
            end
        case 'Topography'
            TopoInfo = getappdata(hFig, 'TopoInfo');
            if ~isempty(TopoInfo) && ~isempty(TopoInfo.FileName)
                StatFile = TopoInfo.FileName;
            end
        case {'Timefreq', 'Spectrum'}
            TfInfo = getappdata(hFig, 'Timefreq');
            if ~isempty(TfInfo) && ~isempty(TfInfo.FileName)
                StatFile = TfInfo.FileName;
            end
        case 'Image'
            StatInfo = getappdata(hFig, 'StatInfo');
            if ~isempty(StatInfo) && ~isempty(StatInfo.StatFile)
                StatFile = StatInfo.StatFile;
            end
    end
    % No stat file found: exit
    if isempty(StatFile)
        return;
    end
    % Get info from loaded structures
    switch (file_gettype(StatFile))
        case 'pdata'
            StatClusters = GlobalData.DataSet(iDS).Measures.StatClusters;
        case 'presults'
            iRes = bst_memory('GetResultInDataSet', iDS, StatFile);
            if ~isempty(iRes)
                StatClusters = GlobalData.DataSet(iDS).Results(iRes).StatClusters;
            end
        case 'ptimefreq'
            iTf = bst_memory('GetTimefreqInDataSet', iDS, StatFile);
            if ~isempty(iTf)
                StatClusters = GlobalData.DataSet(iDS).Timefreq(iTf).StatClusters;
            end
        case 'pmatrix'
            iMatrix = bst_memory('GetMatrixInDataSet', iDS, StatFile);
            if ~isempty(iMatrix)
                StatClusters = GlobalData.DataSet(iDS).Matrix(iMatrix).StatClusters;
            end
    end
    % Tag figure as containing stat clusters
    if ~isempty(StatClusters)
        setappdata(hFig, 'isStatClusters', 1);
    else
        setappdata(hFig, 'isStatClusters', 0);
    end
end


%% ===== SAVE OPTIONS =====
function SaveOptions()
    % Get panel
    ctrl = bst_get('PanelControls', 'Stat');
    if isempty(ctrl)
        return;
    end
    % Get options structure
    StatThreshOptions = bst_get('StatThreshOptions');
    oldOptions = StatThreshOptions;
    % p-value
    pThresh = str2double(char(ctrl.jTextPThresh.getText()));
    if isnan(pThresh) || (pThresh <= 0) || (pThresh > 1)
        pThresh = StatThreshOptions.pThreshold;
    else
        StatThreshOptions.pThreshold = pThresh;
    end
    ctrl.jTextPThresh.setText(num2str(StatThreshOptions.pThreshold, '%g'));
    % Duration threshold
    durThresh = str2double(char(ctrl.jTextDurThresh.getText()));
    if ~isnan(durThresh) && (durThresh >= 0)
        StatThreshOptions.durThreshold = round(durThresh) / 1000;
    end
    ctrl.jTextDurThresh.setText(num2str(round(StatThreshOptions.durThreshold * 1000), '%d'));
    % Multiple comparisons
    if ctrl.jRadioCorrBonf.isSelected()
        StatThreshOptions.Correction = 'bonferroni';
    elseif ctrl.jRadioCorrFdr.isSelected()
        StatThreshOptions.Correction = 'fdr';
    else
        StatThreshOptions.Correction = 'no';
    end
    % Control
    StatThreshOptions.Control = [];
    if ctrl.jRadioControlSpace.isSelected()
        StatThreshOptions.Control(end+1) = 1;
    end
    if ctrl.jRadioControlTime.isSelected()
        StatThreshOptions.Control(end+1) = 2;
    end
    if ctrl.jRadioControlFreq.isSelected()
        StatThreshOptions.Control(end+1) = 3;
    end
    % No modifications: exit
    if isequal(StatThreshOptions, oldOptions)
        return;
    end
    % Set options structure
    bst_set('StatThreshOptions', StatThreshOptions);
    % Update cluster list
    if (StatThreshOptions.pThreshold ~= oldOptions.pThreshold)
        % Get figure clusters
        StatClusters = GetFigureClusters();
        % Update cluster list
        UpdateClustersList(StatClusters);
    end
    % Update figures
    UpdateFigures();
end


% ===== BUTTON UPDATE CALLBACK =====
function UpdateFigures(varargin)
    % Display progress bar
    bst_progress('start', 'Statistic thresholding', 'Apply new options...');
    % Reload all the datasets, to apply the new filters
    bst_memory('ReloadStatDataSets');
    % Notify all the figures that they should be redrawn
    bst_figures('ReloadFigures', 'Stat');
    % Hide progress bar
    bst_progress('stop');
end


%% ===== GET ACTIVE CLUSTERS =====
function [sClusters, PosClust, NegClust] = GetSignificantClusters(StatClusters)
    % Get options structure
    StatThreshOptions = bst_get('StatThreshOptions');
    PosClust = [];
    NegClust = [];
    % Get clusters colormap
    sColormap = bst_colormaps('GetColormap', 'cluster');
    nColors = size(sColormap.CMap,1);
    % Positive clusters: Get the clusters under the current stat threshold
    if isfield(StatClusters, 'posclusters') && ~isempty(StatClusters.posclusters) && isfield(StatClusters.posclusters, 'prob')
        iPosClust = find([StatClusters.posclusters.prob] <= min(StatThreshOptions.pThreshold, 0.999));
        if ~isempty(iPosClust)
            PosClust = StatClusters.posclusters(iPosClust);
        end
    end
    % Positive clusters: compute some more metrics
    for i = 1:length(PosClust)
        iColor = round(nColors/2 + (1-(i-1)/length(PosClust)) * nColors/2);
        PosClust(i).color     = sColormap.CMap(iColor,:);
        PosClust(i).clustsize = nnz(StatClusters.posclusterslabelmat == iPosClust(i));
        PosClust(i).ind       = iPosClust(i);
        PosClust(i).type      = '+';
        PosClust(i).mask      = (StatClusters.posclusterslabelmat == iPosClust(i));
    end
    % Negative clusters: Get the clusters under the current stat threshold
    if isfield(StatClusters, 'negclusters') && ~isempty(StatClusters.negclusters) && isfield(StatClusters.negclusters, 'prob')
        iNegClust = find([StatClusters.negclusters.prob] <= min(StatThreshOptions.pThreshold, 0.999));
        if ~isempty(iNegClust)
            NegClust = StatClusters.negclusters(iNegClust);
        end
    end
    % Negative clusters: compute some more metrics
    for i = 1:length(NegClust)
        iColor = round((i-1) / length(NegClust) * nColors/2 + 1);
        NegClust(i).color     = sColormap.CMap(iColor,:);
        NegClust(i).clustsize = nnz(StatClusters.negclusterslabelmat == iNegClust(i));
        NegClust(i).ind       = iNegClust(i);
        NegClust(i).type      = '-';
        NegClust(i).mask      = (StatClusters.negclusterslabelmat == iNegClust(i));
    end
    % Group two cluster groups
    sClusters = [PosClust, NegClust];
end


%% ===== GET DISPLAYED CLUSTERS =====
function [sClusters, iClusters] = GetDisplayedClusters(hFig)
    sClusters = [];
    % Get panel
    ctrl = bst_get('PanelControls', 'Stat');
    if isempty(ctrl)
        return;
    end
    % Get figure clusters
    StatClusters = GetFigureClusters(hFig);
    if isempty(StatClusters)
        return;
    end
    % Get significant clusters
    sClusters = GetSignificantClusters(StatClusters);
    if isempty(sClusters)
        return;
    end
    % Get the display options
    ClustersOptions = GetClustersOptions();
    % Get selected clusters in the Stat panel
    switch ClustersOptions.showSelection
        case 'none'
            % Do not select anything
            iClusters = [];
            sClusters = [];
        case 'select'
            % Check that the number of clusters is correct
            % Possible error: if there are multiple files with different clusters displayed together, 
            % the selection may apply improperly to inappropriate files
            if (length(sClusters) == ctrl.jListClusters.getModel().getSize())
                % Get the clusters that are selected in the JList
                iClusters = ctrl.jListClusters.getSelectedIndices() + 1;
                sClusters = sClusters(iClusters);
            else
                iClusters = [];
                sClusters = [];
            end
        case 'all'
            % Keep all the significant clusters
            iClusters = 1:length(sClusters);
    end
end


%% ===== UPDATE CLUSTERS LIST =====
function UpdateClustersList(StatClusters, isForced)
    import org.brainstorm.list.*;
    % Parse inputs
    if (nargin < 2) || isempty(isForced)
        isForced = 0;
    end
    % Get panel
    ctrl = bst_get('PanelControls', 'Stat');
    if isempty(ctrl)
        return;
    end
    % Show/hide controls
    if isempty(StatClusters) || (~isfield(StatClusters, 'posclusters') && ~isfield(StatClusters, 'negclusters'))
        ctrl.jPanelClusterList.setVisible(0);
        return;
    else
        ctrl.jPanelClusterList.setVisible(1);
    end
    % Get active clusters
    sClusters = GetSignificantClusters(StatClusters);
    % Create a new empty list
    listModel = java_create('javax.swing.DefaultListModel');
    % Add an item in list for each cluster 
    for i = 1:length(sClusters)
        clustLabel = sprintf('p=%1.5f, c=%d, s=%d', sClusters(i).prob, round(sClusters(i).clusterstat), sClusters(i).clustsize);
        listModel.addElement(BstListItem(sClusters(i).type, [], clustLabel, i, sClusters(i).color(1), sClusters(i).color(2), sClusters(i).color(3)));
    end
    % If the cluster list didn't change: do not update
    if ~isForced && strcmpi(char(listModel.toString()), char(ctrl.jListClusters.getModel()))
        return;
    end
    % Update list model
    ctrl.jListClusters.setModel(listModel);
end


%% ===== UPDATE CLUSTERS DISPLAY =====
function UpdateClustersDisplay()
    global GlobalData;
    % Process all the loaded datasets
    for iDS = 1:length(GlobalData.DataSet)
        % Process all the figures
        for iFig = 1:length(GlobalData.DataSet(iDS).Figure)
            hFig = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
            % Check if there were clusters identified for this figure
            isStatClusters = getappdata(hFig, 'isStatClusters');
            if isempty(isStatClusters) || (isStatClusters == 0)
                continue;
            end
            % Call low-level plot function
            switch GlobalData.DataSet(iDS).Figure(iFig).Id.Type
                case {'DataTimeSeries', 'ResultsTimeSeries'}
                    figure_timeseries('ViewStatClusters', hFig);
                case '3DViz'
                    panel_surface('UpdateSurfaceData', hFig);
                case 'Topography'
                    figure_topo('ViewStatClusters', hFig);
                case 'Timefreq'
                    figure_timefreq('UpdateFigurePlot', hFig, 1);
                case 'Image'
                    figure_image('UpdateFigurePlot', hFig, 1);
                case 'Spectrum'
                    figure_spectrum('ViewStatClusters', hFig);
                case 'MriViewer'
                    % Ignore this type of figure
            end
        end
    end
end


%% ===== UPDATE CLUSTER MENUS =====
function UpdateClusterMenus(hFig)
    import org.brainstorm.icon.*;
    % Get panel
    ctrl = bst_get('PanelControls', 'Stat');
    if isempty(ctrl)
        return;
    end
    % Remove all previous menus
    jMenu = ctrl.jMenuJump;
    jMenu.removeAll();
    % Add menus
    gui_component('MenuItem', jMenu, [], 'Largest spatial extent', IconLoader.ICON_ARROW_RIGHT, [], @(h,ev)FindLargestCluster(hFig), []);
end


%% ===== FIND LARGEST CLUSTER ======
function FindLargestCluster(hFig)
    % Get displayed clusters
    [sClusters, iClusters] = GetDisplayedClusters(hFig);
    if isempty(sClusters)
        return;
    end
    % Get figure
    [hFig,iFig,iDS] = bst_figures('GetFigure', hFig);
    % Loop on clusters to find the largest one
    maxSize = 0;
    iTime = [];
    for i = 1:length(sClusters)
        [maxSizeTmp, iTimeTmp] = max(sum(double(sClusters(i).mask), 1));
        if (maxSizeTmp > maxSize)
            maxSize = maxSizeTmp;
            iTime = iTimeTmp;
        end
    end
    % Go to max time point
    TimeVector = bst_memory('GetTimeVector', iDS);
    if ~isempty(iTime) && (iTime <= length(TimeVector))
        panel_time('SetCurrentTime', TimeVector(iTime));
    end
end

