function varargout = panel_dipoles(varargin)
% PANEL_DIPOLES: Create a panel to add/remove/edit scouts attached to a given 3DViz figure.
% 
% USAGE:  bstPanelNew = panel_dipoles('CreatePanel')
%                       panel_dipoles('UpdatePanel')
%                       panel_dipoles('CurrentFigureChanged_Callback')
%                       panel_dipoles('SetGoodness', Goodness)

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
% Authors: Elizabeth Bock, 2010-2017
%          Francois Tadel, 2010-2020

eval(macro_method);
end


%% ===== CREATE PANEL =====
function bstPanelNew = CreatePanel() %#ok<DEFNU>
    panelName = 'Dipoles';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.list.*;
    
    % The the better JList height
    LABEL_WIDTH      = java_scaled('value', 40);
    SLIDER_WIDTH     = java_scaled('value', 5);
    DEFAULT_HEIGHT   = java_scaled('value', 22);
    LABEL_FONT = java.awt.Font('Arial', java.awt.Font.PLAIN, 9);
    % Font size for the lists
    fontSize = round(11 * bst_get('InterfaceScaling') / 100);
    
    % Main panel container
    jPanelNew = java_create('javax.swing.JPanel');
    jPanelNew.setLayout(BoxLayout(jPanelNew, BoxLayout.PAGE_AXIS));
    jPanelNew.setBorder(BorderFactory.createEmptyBorder(10,10,0,10));

    % ===== PANEL: LOADED DIPOLES =====
    jPanelList = gui_component('Panel');
    jPanelList.setPreferredSize(java_scaled('dimension', 100, 150));
    jPanelList.setMaximumSize(java_scaled('dimension', 500, 150));    
        jBorder = java_scaled('titledborder', 'Loaded dipoles');
        jPanelList.setBorder(jBorder);
        % Groups
        jListDipoles = JList();
        jListDipoles.setCellRenderer(BstStringListRenderer(fontSize));
        java_setcb(jListDipoles, 'ValueChangedCallback', @DipolesListValueChanged_Callback, ...
                                 'KeyPressedCallback',   @DipolesListKeyTyped_Callback);
        jPanelScrollList = JScrollPane();
        jPanelScrollList.getLayout.getViewport.setView(jListDipoles);
        jPanelScrollList.setHorizontalScrollBarPolicy(jPanelScrollList.HORIZONTAL_SCROLLBAR_NEVER);
        jPanelScrollList.setBorder([]);
        % Subsets
        jListSubsets = JList();
        jListSubsets.setCellRenderer(BstStringListRenderer(fontSize));
        java_setcb(jListSubsets, 'ValueChangedCallback', @SubsetsListValueChanged_Callback, ...
                                 'MouseClickedCallback', @SubsetsListValueChanged_Callback, ...
                                 'KeyPressedCallback',   @DipolesListKeyTyped_Callback);

        jPanelScrollSubset = JScrollPane();
        jPanelScrollSubset.getLayout.getViewport.setView(jListSubsets);
        jPanelScrollSubset.setHorizontalScrollBarPolicy(jPanelScrollList.HORIZONTAL_SCROLLBAR_NEVER);
        jPanelScrollSubset.setBorder([]);

    jSplitDipoles = JSplitPane(JSplitPane.HORIZONTAL_SPLIT, jPanelScrollSubset, jPanelScrollList );
    jSplitDipoles.setResizeWeight(0.3);
    jSplitDipoles.setDividerSize(4);
    jSplitDipoles.setBorder([]);

    jPanelList.add(jSplitDipoles, BorderLayout.CENTER);
    jPanelList.setVisible(0);
    jPanelNew.add(jPanelList);

    % ===== PANEL: FILTER =====
    jPanelFilter = gui_river([0,1], [0,0,0,0], 'Filter dipoles');
        % Goodness title
        jTitleGoodness = gui_component('Label', jPanelFilter, 'br', 'Goodness:');
        % Goodness slider
        jSliderGoodness = JSlider(0, 100, 0);
        jSliderGoodness.setPreferredSize(Dimension(SLIDER_WIDTH, DEFAULT_HEIGHT));
        java_setcb(jSliderGoodness, 'MouseReleasedCallback', @SliderGoodness_Callback,  'KeyPressedCallback', @SliderGoodness_Callback);
        jPanelFilter.add('tab hfill', jSliderGoodness);
        % Goodness label
        jLabelGoodness = gui_component('Label', jPanelFilter, [], '     0%', {JLabel.RIGHT, Dimension(LABEL_WIDTH, DEFAULT_HEIGHT)});  
        jLabelGoodness.setFont(LABEL_FONT);
        
        % Confidence Volume title
        jTitleConfVol = gui_component('Label', jPanelFilter, 'br', 'ConfVol:');
        % Confidence volume slider
        jSliderConfVol = JSlider(0, 100, 100);
        jSliderConfVol.setPreferredSize(Dimension(SLIDER_WIDTH, DEFAULT_HEIGHT));
        jSliderConfVol.setInverted(1);
        java_setcb(jSliderConfVol, 'MouseReleasedCallback', @SliderConfVol_Callback, ...
                                   'KeyPressedCallback',    @SliderConfVol_Callback);
        jPanelFilter.add('tab hfill', jSliderConfVol);
        % Confidence volume label
        jLabelConfVol = gui_component('Label', jPanelFilter, [], '         ', {JLabel.RIGHT, Dimension(LABEL_WIDTH, DEFAULT_HEIGHT)});
        jLabelConfVol.setFont(LABEL_FONT);
        
        % Chi-square title
        jTitleKhi2 = gui_component('Label', jPanelFilter, 'br', 'Chi-sqr:');
        % Chi-square slider
        jSliderKhi2 = JSlider(0, 100, 100);
        jSliderKhi2.setPreferredSize(Dimension(SLIDER_WIDTH, DEFAULT_HEIGHT));
        jSliderKhi2.setInverted(1);
        java_setcb(jSliderKhi2, 'MouseReleasedCallback', @SliderKhi2_Callback, ...
                                'KeyPressedCallback',    @SliderKhi2_Callback);
        jPanelFilter.add('tab hfill', jSliderKhi2);
        % Chi-square label
        jLabelKhi2 = gui_component('Label', jPanelFilter, [], '         ', {JLabel.RIGHT, Dimension(LABEL_WIDTH, DEFAULT_HEIGHT)});
        jLabelKhi2.setFont(LABEL_FONT);
    jPanelNew.add(jPanelFilter);

    % ===== PANEL: DISPLAY OPTIONS =====
    jPanelOptions = gui_river([0,1], [2,4,4,0], 'Display filters');
        % Options
        jToggleMaxGoodness = gui_component('Checkbox', jPanelOptions, 'br', 'Show max goodness of fit', [], 'Show only the dipole with the maximal goodness of fit', @(h,ev)FireUpdateDisplayOptions);
        jToggleAllTimes    = gui_component('Checkbox', jPanelOptions, 'br', 'Show all time', [], 'Show all time points', @(h,ev)FireUpdateDisplayOptions);
        jToggleSelTimes    = gui_component('Checkbox', jPanelOptions, 'br', 'Show only preferred times', [], 'Show only the dipoles at custom selected times (default time=0)', @(h,ev)FireUpdateDisplayOptions); 
        jToggleAllTimes.setSelected(1);
        jButtonSetSel = gui_component('Button', jPanelOptions, '', 'Set', Insets(1,5,1,5), 'Set the current time as the preferred time for the loaded group(s)', @SetSelectedTime_Callback);
        jButtonSetSel.setFocusable(0);
    jPanelNew.add(jPanelOptions);
    
    % ===== PANEL: COLOR =====
    jPanelColor = gui_river([0,1], [2,4,4,0], 'Color dipoles according to:');
        colorButtonGroup = javax.swing.ButtonGroup();
        jToggleColorTime     = gui_component('Radio', jPanelColor, 'br', 'Time', colorButtonGroup, 'Set dipole colors according to the time instant', @CheckColor_Callback);
        jToggleColorGoodness = gui_component('Radio', jPanelColor, 'br', 'Goodness of fit', colorButtonGroup, 'Set dipole colors according to the goodness of fit', @CheckColor_Callback);
        jToggleColorGroup    = gui_component('Radio', jPanelColor, 'br', 'Group', colorButtonGroup, 'Set dipole colors according to the dipole group', @CheckColor_Callback);
        jToggleColorTime.setSelected(1);
        
        %dipole size
        jTitleDipSize = gui_component('Label', jPanelColor, 'br', 'Point display size:');
        jSliderDipSize = JSlider(5, 20, 8);
        jSliderDipSize.setPreferredSize(Dimension(SLIDER_WIDTH, DEFAULT_HEIGHT));
        java_setcb(jSliderDipSize, 'MouseReleasedCallback', @FireUpdateDisplayOptions, ...
                                   'KeyPressedCallback',    @FireUpdateDisplayOptions);
        jPanelColor.add('tab hfill', jSliderDipSize);
        %dipole tail size
        jTitleTailWidth = gui_component('Label', jPanelColor, 'br', 'Tail display width:');
        jSliderTailWidth = JSlider(4, 40, 8);
        jSliderTailWidth.setPreferredSize(Dimension(SLIDER_WIDTH, DEFAULT_HEIGHT));
        java_setcb(jSliderTailWidth, 'MouseReleasedCallback', @FireUpdateDisplayOptions, ...
                                   'KeyPressedCallback',    @FireUpdateDisplayOptions);
        jPanelColor.add('tab hfill', jSliderTailWidth);
    jPanelNew.add(jPanelColor);
    
    % Set max panel sizes
    drawnow;
    jPanelList.setMaximumSize(java.awt.Dimension(jPanelList.getMaximumSize().getWidth(), jPanelList.getPreferredSize().getHeight()));
    jPanelOptions.setMaximumSize(java.awt.Dimension(jPanelOptions.getMaximumSize().getWidth(), jPanelOptions.getPreferredSize().getHeight()));
    jPanelFilter.setMaximumSize(java.awt.Dimension(jPanelFilter.getMaximumSize().getWidth(), jPanelFilter.getPreferredSize().getHeight()));
    jPanelColor.setMaximumSize(java.awt.Dimension(jPanelColor.getMaximumSize().getWidth(), jPanelColor.getPreferredSize().getHeight()));
    % Add an extra glue at the end, so that panel stay small
    jPanelNew.add(Box.createVerticalGlue());
    
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jPanelList',            jPanelList, ...
                                  'jPanelOptions',         jPanelOptions, ...
                                  'jPanelFilter',          jPanelFilter, ...
                                  'jListDipoles',          jListDipoles, ...
                                  'jListSubsets',          jListSubsets, ...
                                  'jToggleAllTimes',       jToggleAllTimes, ...
                                  'jToggleColorGroup',     jToggleColorGroup, ...
                                  'jToggleColorTime',      jToggleColorTime, ...
                                  'jToggleColorGoodness',  jToggleColorGoodness, ...
                                  'jToggleMaxGoodness',    jToggleMaxGoodness, ...
                                  'jTitleGoodness',        jTitleGoodness, ...
                                  'jLabelGoodness',        jLabelGoodness, ...
                                  'jSliderGoodness',       jSliderGoodness, ...
                                  'jTitleKhi2',            jTitleKhi2, ...
                                  'jLabelKhi2',            jLabelKhi2, ...
                                  'jSliderKhi2',           jSliderKhi2, ...
                                  'jTitleConfVol',         jTitleConfVol, ...
                                  'jLabelConfVol',         jLabelConfVol, ...    
                                  'jSliderConfVol',        jSliderConfVol, ...
                                  'jToggleSelTimes',       jToggleSelTimes, ...
                                  'jButtonSetSel',         jButtonSetSel, ...
                                  'jTitleDipSize',         jTitleDipSize, ...
                                  'jSliderDipSize',        jSliderDipSize, ...
                                  'jTitleTailWidth',       jTitleTailWidth, ...
                                  'jSliderTailWidth',      jSliderTailWidth));
                              
    
%% ===== INTERNAL CALLBACKS =====   
    function SliderGoodness_Callback(varargin)
        % Update text field
        val = jSliderGoodness.getValue();
        jLabelGoodness.setText(sprintf('%d%%', val));
        % Update display options
        FireUpdateDisplayOptions();
    end

    function SliderKhi2_Callback(varargin)
        % Update display options
        FireUpdateDisplayOptions();
    end
    
    function SliderConfVol_Callback(varargin)
        % Update display options
        FireUpdateDisplayOptions();
    end
end

%% =================================================================================
%  === CONTROLS CALLBACKS  =========================================================
%  =================================================================================
%% ===== CHECKBOX: 3D COLOR =====
function CheckColor_Callback(varargin)
    % Get current figure
    hFig = bst_figures('GetCurrentFigure', '3D');
    if isempty(hFig)
        return
    end
    % Update display
    FireUpdateDisplayOptions();
    % Update colormap
    FireUpdateSurfaceColormap();
end

%% ===== LIST SELECTION CHANGED CALLBACK =====
function DipolesListValueChanged_Callback(h, ev)
    if ~ev.getValueIsAdjusting()
        FireUpdateDisplayOptions();
    end
end

%% ===== LIST KEY TYPED CALLBACK =====
function DipolesListKeyTyped_Callback(h, ev)
    import java.awt.event.KeyEvent;
    if ismember(ev.getKeyCode(), [KeyEvent.VK_LEFT, KeyEvent.VK_RIGHT])
        panel_time('TimeKeyCallback', ev);
    end
end

%% ===== SUBSET SELECTION CHANGED CALLBACK =====
function SubsetsListValueChanged_Callback(h, ev)
    % Get panel controls
    ctrl = bst_get('PanelControls','Dipoles');
    if isempty(ctrl)
        return;
    end
    % Get selected subset
    iSubset = double(ctrl.jListSubsets.getSelectedIndices())' + 1;
 
    % Remove JList callback
    bakCallback = java_getcb(ctrl.jListDipoles, 'ValueChangedCallback');
    java_setcb(ctrl.jListDipoles, 'ValueChangedCallback', []);
    
    hFig = bst_figures('GetCurrentFigure');
    DipolesInfo = GetDipolesForFigure(hFig);
    iNames = [];
    % Find all DipoleNames that contain the subset number
    for i=1:length(iSubset)
        strSubset = ['(' num2str(iSubset(i)) ')'];
        x=strfind([DipolesInfo.DipoleNames], strSubset);
        iNames = cat(2,iNames,find(~cellfun(@isempty,x))-1);
    end
    % Select the DipoleNames, or All, if no match...
    if isempty(iNames)
        iNames = 0:length(DipolesInfo.DipoleNames)-1;
    end
    ctrl.jListDipoles.setSelectedIndices(iNames);
    java_setcb(ctrl.jListDipoles, 'ValueChangedCallback', bakCallback);
    
    % Display/hide dipoles
    FireUpdateDisplayOptions()
end
%% ===== SET TIME SELECTION CALLBACK =====
function SetSelectedTime_Callback(h,ev)
    global GlobalData    
    hFig = bst_figures('GetCurrentFigure');    
    % Get the dipole info structure
    DipolesInfo = GetDipolesForFigure(hFig);
    % Get selected dipole(s)
    iSel = GetDisplayedDipoles(hFig);
    % Set the current time as the selected time for the displayed groups
    DipolesInfo.PreferredTimes(iSel) = GlobalData.UserTimeWindow.CurrentTime;
    
    % Save the times back to the dipole file
    DipolesFileInfo = getappdata(hFig, 'Dipoles');
    DipolesFile = file_fullpath(DipolesFileInfo.FileName);
    save(DipolesFile,'-struct','DipolesInfo','PreferredTimes','-append') 
    
    % Update the loaded dipoles
    [iDS, iDipoles] = bst_memory('LoadDipolesFile', DipolesFile);
    GlobalData.DataSet(iDS).Dipoles(iDipoles).PreferredTimes = DipolesInfo.PreferredTimes;
    
    % Display/hide dipoles
    FireUpdateDisplayOptions()
end
%% =================================================================================
%  === EXTERNAL PANEL CALLBACKS  ===================================================
%  =================================================================================
%% ===== UPDATE CALLBACK =====
function UpdatePanel() %#ok<DEFNU>
    hFig = bst_figures('GetCurrentFigure');
    UpdateDipolesList(hFig);
end

%% ===== CURRENT FIGURE CHANGED =====
function CurrentFigureChanged_Callback(hFig) %#ok<DEFNU>
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Dipoles');
    if isempty(ctrl)
        return;
    end
    % Remove JList callback
    bakCallback = java_getcb(ctrl.jListDipoles, 'ValueChangedCallback');
    java_setcb(ctrl.jListDipoles, 'ValueChangedCallback', []);
    % Update dipoles list
    UpdateDipolesList(hFig);
    % Restore callback
    java_setcb(ctrl.jListDipoles, 'ValueChangedCallback', bakCallback);
end

%% ===== CURRENT TIME CHANGED =====
function CurrentTimeChangedCallback(hFig) %#ok<DEFNU>
    PlotSelectedDipoles(hFig);
end

%% ===== LOAD DIPOLES =====
function AddDipoles(hFig, DipolesFile, isDisplay) %#ok<DEFNU>
    global GlobalData;
    if (nargin < 3)
        isDisplay = 1;
    end
    % Make file name relative
    DipolesFile = file_short(DipolesFile);
    % Get dipoles currently shown in figure
    DipolesInfo = getappdata(hFig, 'Dipoles');
    % If dipoles files already displayed: return
    if ~isempty(DipolesInfo) && any(file_compare({DipolesInfo.FileName}, DipolesFile))
        warning('This dipoles file is already displayed. Ignoring... ');
        return
    end
    % Load file
    [iDS, iDipoles] = bst_memory('LoadDipolesFile', DipolesFile);
    if isempty(iDS)
        return
    end
    % Add new dipole structure in DipolesInfo
    iNewDip = length(DipolesInfo) + 1;
    DipolesInfo(iNewDip).FileName = GlobalData.DataSet(iDS).Dipoles(iDipoles).FileName;
    DipolesInfo(iNewDip).Selected = [];
    % Set dipoles in figure application data
    setappdata(hFig, 'Dipoles',     DipolesInfo);
    setappdata(hFig, 'SubjectFile', GlobalData.DataSet(iDS).SubjectFile);
    setappdata(hFig, 'StudyFile',   GlobalData.DataSet(iDS).StudyFile);
    % Update dipoles list
    UpdateDipolesList(hFig, 1);
    % Select "dipoles" tab
    gui_brainstorm('SetSelectedTab', 'Dipoles');
    % Plot selected dipoles
    if isDisplay
        FireUpdateDisplayOptions();
        % Update colormap
        FireUpdateSurfaceColormap();
    end
end


%% ===== GET DIPOLES FOR FIGURE =====
function DipolesInfo = GetDipolesForFigure(hFig)
    global GlobalData;
    % Initialize returned structure
    DipolesInfo.DipoleNames = {};
    DipolesInfo.Dipole = [];
    DipolesInfo.Subset = [];
    DipolesInfo.PreferredTimes = [];
    DipolesInfo.DisplayColorType = 'time';
    DipolesInfo.DisplayAllTime = 0;
    DipolesInfo.DisplayMaxGoodness = 0;
    DipolesInfo.DisplaySelTimes = 0;
    
    % Get Dipoles description in figure
    DipolesApp = getappdata(hFig, 'Dipoles');
    if isempty(DipolesApp)
        return
    end
    % For each dipoles file displayed in this figure
    for i = 1:length(DipolesApp)
        % Get loaded dipoles
        [iDS, iDipoles] = bst_memory('GetDataSetDipoles', DipolesApp(i).FileName);
        % Add description to dipoles
        DipolesInfo.Dipole = [DipolesInfo.Dipole, GlobalData.DataSet(iDS).Dipoles(iDipoles).Dipole];
        DipolesInfo.DipoleNames = cat(2, DipolesInfo.DipoleNames, GlobalData.DataSet(iDS).Dipoles(iDipoles).DipoleNames);
        % Check for subsets
        DipolesInfo.Subset = cat(2, DipolesInfo.Subset, GlobalData.DataSet(iDS).Dipoles(iDipoles).Subset);
        DipolesInfo.PreferredTimes = cat(2, DipolesInfo.PreferredTimes, GlobalData.DataSet(iDS).Dipoles(iDipoles).PreferredTimes);
    end
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Dipoles');
    if isempty(ctrl)
        return;
    end
    % Goodness
    sScales = GetSliderScales('goodness',hFig);
    if isempty([sScales.min])
        ctrl.jLabelGoodness.setEnabled(0);
        ctrl.jTitleGoodness.setEnabled(0);
        ctrl.jSliderGoodness.setEnabled(0);
        ctrl.jToggleColorGoodness.setEnabled(0);
        ctrl.jToggleMaxGoodness.setEnabled(0);
    end
    % Khi2
    sScales = GetSliderScales('khi2',hFig);
    if isempty([sScales.min])
        ctrl.jLabelKhi2.setEnabled(0);
        ctrl.jTitleKhi2.setEnabled(0);
        ctrl.jSliderKhi2.setEnabled(0);
    end
    % ConfVol
    sScales = GetSliderScales('confvol',hFig);
    if isempty([sScales.min])
        ctrl.jTitleConfVol.setEnabled(0);
        ctrl.jLabelConfVol.setEnabled(0);
        ctrl.jSliderConfVol.setEnabled(0);
    end

    % Make the list visible if more than one set
    nDipoles = length(DipolesInfo.DipoleNames);
    nSubsets = length(DipolesInfo.Subset);
    if (nDipoles > 2) || (nSubsets > 2)
       ctrl.jPanelList.setVisible(1);
    end
    
    % Set the display color scheme
    if ctrl.jToggleColorTime.isSelected()
        DipolesInfo.DisplayColorType = 'time';
    elseif ctrl.jToggleColorGoodness.isSelected()
        DipolesInfo.DisplayColorType = 'goodness';
    elseif ctrl.jToggleColorGroup.isSelected()
        DipolesInfo.DisplayColorType = 'group';
    end
    
    % Determine if there is any display filters
    % Show preferred time only
    if ctrl.jToggleSelTimes.isSelected()
        DipolesInfo.DisplaySelTimes = 1;
        ctrl.jToggleMaxGoodness.setSelected(0);  
        ctrl.jToggleAllTimes.setSelected(0);
        % Do not allow setting preferred time when this filter is on
        ctrl.jButtonSetSel.setEnabled(0);
    else
        ctrl.jButtonSetSel.setEnabled(1);
    end
    % Show all time
    if ctrl.jToggleAllTimes.isSelected()
        DipolesInfo.DisplayAllTime = 1;
        % Do not allow setting preferred time when all time is displayed
        ctrl.jButtonSetSel.setEnabled(0);
    end
    % Show maximum goodness of selected dipoles
    if ctrl.jToggleMaxGoodness.isSelected()
        DipolesInfo.DisplayMaxGoodness = 1;
    end
end


%% ===== UPDATE DIPOLES LIST =====
function UpdateDipolesList(hFig, isSelectAll)
    % Parse inputs
    if (nargin < 2) || isempty(isSelectAll)
        isSelectAll = 0;
    end
    % Get Dipoles description in figure
    if ~isempty(hFig)
        DipolesInfo = GetDipolesForFigure(hFig);
        if isempty(DipolesInfo)
            return
        end
        nDipoles = length(DipolesInfo.DipoleNames);
        nSubsets = length(DipolesInfo.Subset);
    else
        nDipoles = 0;
        nSubsets = 0;
    end
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Dipoles');
    if isempty(ctrl)
        return;
    end
    % ==== Dipole List
    % Remove JList callback
    bakCallback = java_getcb(ctrl.jListDipoles, 'ValueChangedCallback');
    java_setcb(ctrl.jListDipoles, 'ValueChangedCallback', []);
    
    % Create a new empty list
    listModel = java_create('javax.swing.DefaultListModel');
    % Add an item in list for each scout found for target figure
    for i = 1:nDipoles
        listModel.addElement(DipolesInfo.DipoleNames{i});
    end
    % Update list model
    ctrl.jListDipoles.setModel(listModel);
    
    % ==== Subset List   
    % Remove JList callback
    sbakCallback = java_getcb(ctrl.jListSubsets, 'ValueChangedCallback');
    java_setcb(ctrl.jListSubsets, 'ValueChangedCallback', []);

    % Create a new empty list
    subsetModel = java_create('javax.swing.DefaultListModel'); 
    % Add an item in list for each subset
    for i = 1:nSubsets
        subsetModel.addElement(['Subset #' num2str(DipolesInfo.Subset(i))]);
    end
    
    % Update list model
    ctrl.jListSubsets.setModel(subsetModel);
    drawnow
    
    % Select all dipoles
    if isSelectAll && (nDipoles > 0)
        iSel = 1:nDipoles;
    % Get dipoles displayed in this figure
    else
        iSel = GetDisplayedDipoles(hFig);
    end
    % Change list selection
    if ~isempty(iSel)
        ctrl.jListDipoles.setSelectedIndices(iSel - 1);
    end
        
    % Restore callback
    drawnow
    java_setcb(ctrl.jListDipoles, 'ValueChangedCallback', bakCallback);
    java_setcb(ctrl.jListSubsets, 'ValueChangedCallback', sbakCallback);
    
    
end


%% ===== UPDATE DISPLAY OPTIONS ======
function FireUpdateDisplayOptions(varargin)
    % Progress bar
    isProgress = bst_progress('IsVisible');
    if ~isProgress
        bst_progress('start', 'Dipoles', 'Updating figure...');
    end
    % Update all figures with selected display options
    hFigs = bst_figures('GetAllFigures');
    for iFig = 1:length(hFigs)
        hFig = hFigs(iFig);
        FigureId = getappdata(hFig, 'FigureId');
        DipolesInfo = GetDipolesForFigure(hFig);
        % Redraw dipoles for current figure
        if ~isempty(FigureId) && ~isempty(DipolesInfo.Dipole)
            switch (FigureId.Type)
                case 'MriViewer'
                    % Nothing specific to update
                case '3DViz'
                    % === 3D: SPECIAL COLORMAPS ===
                    CmapInfo = getappdata(hFig, 'Colormap');
                    switch DipolesInfo.DisplayColorType
                        % Color = Time 
                        case 'time'
                            CmapInfo.Type = 'time';
                            CmapInfo.AllTypes{end+1} = 'time';
                            CmapInfo.AllTypes = unique(CmapInfo.AllTypes);
                        % Color = Goodness of fit
                        case 'goodness'
                            CmapInfo.Type = 'percent';
                            CmapInfo.AllTypes{end+1} = 'percent';
                            CmapInfo.AllTypes = unique(CmapInfo.AllTypes);
                        % Color = Group (no colormap)
                        case 'group'
                            CmapInfo.AllTypes = setdiff(CmapInfo.AllTypes, {'time', 'percent', 'stat1'});
                            if ~isempty(CmapInfo.AllTypes)
                                CmapInfo.Type = CmapInfo.AllTypes{1};
                            else
                                CmapInfo.Type = [];
                            end
                    end
                    % Update 3D figure configuration
                    setappdata(hFig, 'Colormap', CmapInfo);
            end
        end
        % Redraw dipoles for current figure
        RedrawDipoles(hFig);
    end
    % Close progress bar
    if ~isProgress
        bst_progress('stop');
    end
end
    
%% ===== UPDATE COLORMAP =====
function FireUpdateSurfaceColormap()
    [hFigs] = bst_figures('GetAllFigures');
    for iFig = 1:length(hFigs)
        hFig = hFigs(iFig);
        panel_surface('UpdateSurfaceColormap', hFig);
    end
end
%% ===== GET DISPLAYED DIPOLES =====
function iSel = GetDisplayedDipoles(hFig)
    iSel = [];
    if ~isempty(hFig) && ishandle(hFig)
        DipolesInfo = getappdata(hFig, 'Dipoles');
        if isfield(DipolesInfo, 'Selected')
            iSel = DipolesInfo.Selected;
        end
    end
end

%% ===== GET SELECTED DIPOLES =====
function [sDipoles, iDipoles] = GetSelectedDipoles(hFig)
    global GlobalData    
    sDipoles = [];
    iDipoles = [];
    % Get Dipoles description in figure
    DipolesInfo = GetDipolesForFigure(hFig);
    if isempty(DipolesInfo) || isempty(DipolesInfo.Dipole)
        return
    end
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Dipoles');
    if isempty(ctrl)
        return;
    end
    % Get the selected dipoles in JList
    iSelList = double(ctrl.jListDipoles.getSelectedIndices() + 1);
    % Save selection list in figure
    DipolesApp = getappdata(hFig, 'Dipoles');
    DipolesApp.Selected = iSelList;
    setappdata(hFig, 'Dipoles', DipolesApp);

    % Select time points
    if DipolesInfo.DisplayAllTime || DipolesInfo.DisplaySelTimes
        % Select all time points when this is asked for explicitly or when
        % using the custom selected times filter
        iSelTime = 1:length(DipolesInfo.Dipole);
    else        
        % Select only those time points that are closest to the current time 
        curTime = GlobalData.UserTimeWindow.CurrentTime;
        if isempty(curTime)
            iSelTime = find(abs([DipolesInfo.Dipole.Time] - [DipolesInfo.Dipole(1).Time]) < 1e-6);
        else
            iSelTime = find(abs([DipolesInfo.Dipole.Time] - curTime) < 1e-6);
        end
    end

    % Get dipoles that fit the selection
    if isempty(iSelTime)
        return
    end
    iDipoles = iSelTime(ismember([DipolesInfo.Dipole(iSelTime).Index], iSelList));

    % Show only the preferred time point dipoles
    if DipolesInfo.DisplaySelTimes && ~isempty(iDipoles)
        indexNums = [DipolesInfo.Dipole(iDipoles).Index];
        % Find unique index numbers (groups)
        nIndexNums = unique(indexNums);
        % Loop through groups to find the selected time of each group
        iGroupTime = zeros(1,length(nIndexNums));
        for n=1:length(nIndexNums)
            ind = find(indexNums == nIndexNums(n));
            groupTimes = [DipolesInfo.Dipole(ind).Time];
            t = DipolesInfo.PreferredTimes(nIndexNums(n));
            iGroupTime(n) = bst_closest(groupTimes,t) + ind(1) - 1;
        end
        % Get the indices of the maximums
        iDipoles = iDipoles(iGroupTime);
    end
    
    % Slider thresholds
  
    % Goodness
    sScales = GetSliderScales('goodness', hFig);
    if ~isempty([sScales.min]) 
        minGoodness = double(ctrl.jSliderGoodness.getValue()) ./ 100;
        iDipoles = iDipoles([DipolesInfo.Dipole(iDipoles).Goodness] >= minGoodness);
    end
    % Khi2
    sScales = GetSliderScales('khi2', hFig);
    if ~isempty([sScales.min])        
        val = double(ctrl.jSliderKhi2.getValue());    
        minKhi2 = val/100 * sScales.max;
        iDipoles = iDipoles([DipolesInfo.Dipole(iDipoles).Khi2] <= minKhi2);
        % Update text field
        ctrl.jLabelKhi2.setText(sprintf('%1.1e', minKhi2));
    end
    % ConfVol
    sScales = GetSliderScales('confvol', hFig);
    if ~isempty([sScales.min])       
        val = double(ctrl.jSliderConfVol.getValue());
        minConfVol = val/100 * sScales.max;  
        iDipoles = iDipoles([DipolesInfo.Dipole(iDipoles).ConfVol] <= minConfVol);
        % Update text field
        ctrl.jLabelConfVol.setText(sprintf('%1.1e', minConfVol));
    end

    % Show only maximum goodness of fit
    if DipolesInfo.DisplayMaxGoodness && ~isempty(iDipoles)
        indexNums = [DipolesInfo.Dipole(iDipoles).Index];
        % Find unique index numbers (groups)
        nIndexNums = unique(indexNums);
        goodVals = [DipolesInfo.Dipole(iDipoles).Goodness];
        % Loop through groups to find the max goodness of each group
        iMaxGoodness = zeros(1,length(nIndexNums));
        for n=1:length(nIndexNums)
            ind = find(indexNums == nIndexNums(n));
            z = zeros(1, length(goodVals));
            % Get the goodness values for the group
            z(ind) = goodVals(ind);
            % Get the maximum goodness for the group
            [maxGoodness, iMaxGoodness(n)] = max(z);
        end
        % Get the indices of the maximums
        iDipoles = iDipoles(iMaxGoodness);
    end
        
    % Get dipoles selected in time and index at the same time
    sDipoles = DipolesInfo.Dipole(iDipoles);
end


%% ===== REDRAW DIPOLES =====
function RedrawDipoles(hFig)
    % Get figure type
    FigureId = getappdata(hFig, 'FigureId');
    % Redraw dipoles for current figure
    if ~isempty(FigureId)
        switch (FigureId.Type)
            case 'MriViewer'
                panel_surface('UpdateSurfaceData', hFig)
            case '3DViz'
                PlotSelectedDipoles(hFig);
        end
    end
end

%% ===== PLOT DIPOLES =====
function PlotSelectedDipoles(hFig)
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Dipoles');
    if isempty(ctrl)
        return;
    end
    % Get axis
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    if isempty(hAxes)
        return
    end
    % Delete previous dipoles display
    hPoints = findobj(hAxes, '-depth', 1, 'Tag', 'DipolesLoc');
    hLines  = findobj(hAxes, '-depth', 1, 'Tag', 'DipolesOrient');
    if ~isempty(hPoints)
        delete([hPoints(:); hLines(:)]);
    end

    % Get all dipoles
    DipolesInfo = GetDipolesForFigure(hFig);
    % Get selected dipoles
    [sDipoles, iDipoles] = GetSelectedDipoles(hFig);
    if isempty(sDipoles)
        return
    end
    
    % ===== GROUP DIPOLES =====
    % If color-coded time => group dipoles by time
    ColormapInfo = getappdata(hFig, 'Colormap');
    switch DipolesInfo.DisplayColorType
        case 'time'
            % Get all times for all dipoles
            allTimes = [DipolesInfo.Dipole.Time];
            % Get times for selected dipoles
            selTimes = [sDipoles.Time];
            dipGroupTag = 1:length(sDipoles);
            % Get time colormap
            sColormap = bst_colormaps('GetColormap', ColormapInfo.Type);

            if length(allTimes) < 2
                % Get time limits for this figure
                hAxes = [findobj(hFig, '-depth', 1, 'Tag', 'Axes3D'), ...
                         findobj(hFig, '-depth', 1, 'Tag', 'axc'), ...
                         findobj(hFig, '-depth', 1, 'Tag', 'axa'), ...
                         findobj(hFig, '-depth', 1, 'Tag', 'axs')];
                CLim = get(hAxes(1), 'CLim');
            else
                % Get time limits for the selected group(s)
                CLim = [min(allTimes), max(allTimes)];
            end
            % If start = stop time: cannot create a colormap
            if (CLim(1) == CLim(2))
                CLim(2) = CLim(1) + 0.001;
            end
            % Get color table for dipoles
            if isequal(CLim, [0,1])
                iCol = 1;
            else
                iCol = round((selTimes - CLim(1)) / abs(CLim(2) - CLim(1)) * (length(sColormap.CMap) - 1)) + 1;
                iCol = bst_saturate(iCol, [1, length(sColormap.CMap)]);
            end
            ColorTable = sColormap.CMap(iCol, :);
    
        case 'goodness' 
            % Group tag is the Index
            dipGroupTag = 1:length(sDipoles);
            % Get color table for dipoles
            sColormap = bst_colormaps('GetColormap', ColormapInfo.Type);
            selGoodness = bst_saturate([sDipoles.Goodness] * 100, [0, 100]);
            CLim = [0, 100];
            % Get color table for dipoles
            iCol = round((selGoodness - CLim(1)) / abs(CLim(2) - CLim(1)) * (length(sColormap.CMap) - 1)) + 1;
            ColorTable = sColormap.CMap(iCol, :);

        case 'group'
            % Group tag is the Index
            dipGroupTag = [sDipoles.Index];
            % Get color table for dipoles
            ColorTable = GetDipolesColorTable();
    end
    % Group dipoles by index
    dipGroups = unique(dipGroupTag);
    % Get display properties
    pointSize = ctrl.jSliderDipSize.getValue;
    lineWidth = 1.5*(ctrl.jSliderTailWidth.getValue/10);

    % ===== DISPLAY GROUPS =====
    % Get number of different groups
    for iGroup = 1:length(dipGroups)
        % Get all the dipoles of this group
        iDipGroup = find(dipGroupTag == dipGroups(iGroup));
        % Get dipole locations
        Loc = [sDipoles(iDipGroup).Loc];
        % Compute dipole orientations (normalized amplitude)
        Orient = [sDipoles(iDipGroup).Amplitude];
        normAmp = sqrt(sum(Orient.^2,1));
        Orient = Orient ./ repmat(normAmp,3,1) .* 0.02;
        % Get color
        iColor = mod(dipGroups(iGroup)-1, length(ColorTable)) + 1;
        
        % Loop added to be able to track each dipole inpendently
        for i = 1:length(iDipGroup)
            % Plot point
            line(Loc(1,i), Loc(2,i), Loc(3,i), ...
                'LineStyle',       'none', ...
                'MarkerFaceColor', ColorTable(iColor,:), ...
                'Marker',          'o', ...
                'MarkerEdgeColor', [.4 .4 .4], ...
                'MarkerSize',      pointSize, ...
                'Tag',             'DipolesLoc', ...
                'UserData',        iDipoles(iDipGroup(i)), ...
                'Parent',          hAxes);
            % Plot orientation
            if lineWidth > 0.70
                line([Loc(1,i); Loc(1,i) + Orient(1,i)], ...
                     [Loc(2,i); Loc(2,i) + Orient(2,i)], ...
                     [Loc(3,i); Loc(3,i) + Orient(3,i)], ...
                    'Color',      ColorTable(iColor,:), ...
                    'LineStyle',  '-', ...
                    'LineWidth',   lineWidth, ...
                    'Tag',        'DipolesOrient', ...
                    'UserData',        iDipoles(iDipGroup(i)), ...
                    'Parent',     hAxes);
            end
        end
    end
    % Force updating this figure before upd
    drawnow
end


%% ===== GET DIPOLES COLOR TABLE =====
function ColorTable = GetDipolesColorTable()
    ColorTable = [0    1    0   ;
                  1    0    0   ; 
                  .4   .4   1   ;
                  1    .694 .392;
                  0    1    1   ;
                  1    0    1   ;
                  .4   0    0  ; 
                  0    .5   0];
end


%% ===== COMPUTE DENSITY VOLUMES =====
function Cube = ComputeDensity(sMri, sDipoles) %#ok<DEFNU>
    % Initialize cube
    sizeCube = size(sMri.Cube(:,:,:,1));
    Cube = zeros(sizeCube);
    
    % Gaussian kernel
    A = zeros(5,5,5);
    A(:,:,1) = [0 0 0 0 0;
                0 0 0 0 0;
                0 0 1 0 0;
                0 0 0 0 0;
                0 0 0 0 0];
            
    A(:,:,2) = [0 0 0 0 0;
                0 1 2 1 0;
                0 2 3 2 0;
                0 1 2 1 0;
                0 0 0 0 0];
            
    A(:,:,3) = [0 1 1 1 0;
                1 2 3 2 1;
                1 3 4 3 1;
                1 2 3 2 1;
                0 1 1 1 0];
    A(:,:,4) = A(:,:,2);
    A(:,:,5) = A(:,:,1);
    
    % Loop on each dipole
    for i = 1:length(sDipoles)
        % Vertices: SCS->Voxels
        mriLoc = round(cs_convert(sMri, 'scs', 'voxel', [sDipoles(i).Loc]'));
        % Get the valid indices in the kernel
        iX = [min(2, mriLoc(:,1) - 1),  min(2, sizeCube(1)-mriLoc(:,1))];
        iY = [min(2, mriLoc(:,2) - 1),  min(2, sizeCube(2)-mriLoc(:,2))];
        iZ = [min(2, mriLoc(:,3) - 1),  min(2, sizeCube(3)-mriLoc(:,3))];
        % Each dipole is displayed by a cube of 5*5*5 voxels (gaussian kernel)
        X = mriLoc(:,1) - iX(1) : mriLoc(:,1) + iX(2);
        Y = mriLoc(:,2) - iY(1) : mriLoc(:,2) + iY(2);
        Z = mriLoc(:,3) - iZ(1) : mriLoc(:,3) + iZ(2);
        Cube(X,Y,Z) = Cube(X,Y,Z) + A(3-iX(1):3+iX(2), 3-iY(1):3+iY(2), 3-iZ(1):3+iZ(2));
    end
    % Convert in percentage
    maxCube = max(Cube(:));
    if (maxCube > 0)
        Cube = Cube ./ maxCube .* 100;
    end
end

%% ===== SLIDER SCALES =====
function sScales = GetSliderScales(varargin)
    global GlobalData;
    
    if size(varargin,2) < 2
        scale = varargin{1};
        hFig = bst_figures('GetCurrentFigure');
    else
        scale = varargin{1};
        hFig = varargin{2};
    end
        
    % Initialize returned structures
    sScales.label = {};
    sScales.min = [];
    sScales.max = [];
    DipolesInfo.Dipole = [];

    % Get Dipoles description in figure
    DipolesApp = getappdata(hFig, 'Dipoles');
    if isempty(DipolesApp)
        return
    end
    % For each dipoles file displayed in this figure
    for i = 1:length(DipolesApp)
        % Get loaded dipoles
        [iDS, iDipoles] = bst_memory('GetDataSetDipoles', DipolesApp(i).FileName);
        % Add description to dipoles
        DipolesInfo.Dipole = [DipolesInfo.Dipole, GlobalData.DataSet(iDS).Dipoles(iDipoles).Dipole];
    end
    
    switch scale
        case 'goodness'
            % find scale of goodness
            sScales.label = {'goodness'};
            sScales.min = min([DipolesInfo.Dipole.Goodness]);
            sScales.max = max([DipolesInfo.Dipole.Goodness]);
        case 'khi2'
            % find scale of khi2 value
            sScales.label = {'khi2'};
            sScales.min = min([DipolesInfo.Dipole.Khi2]);
            sScales.max = max([DipolesInfo.Dipole.Khi2]);
        case 'rkhi2'
            % find scale of Reduced khi2 value
            sScales.label = {'rkhi2'};
            sScales.min = min([DipolesInfo.Dipole.DOF]);
            sScales.max = max([DipolesInfo.Dipole.DOF]);
        case 'confvol'
            % find scale of confidence volume values
            sScales.label = {'confvol'};
            sScales.min = min([DipolesInfo.Dipole.ConfVol]);
            sScales.max = max([DipolesInfo.Dipole.ConfVol]);
    end
end


%% ===== SET GOODNESS THRESHOLD =====
function SetGoodness(Goodness) %#ok<DEFNU>
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Dipoles');
    if isempty(ctrl)
        return;
    end
    % Round goodness of fit
    Goodness = round(Goodness * 100);
    % Set the goodness of fit
    if isfield(ctrl, 'jSliderGoodness') && ctrl.jSliderGoodness.isEnabled() && (Goodness >= 0) && (Goodness < 100)
        % Set slider
        ctrl.jSliderGoodness.setValue(Goodness);
        ctrl.jLabelGoodness.setText(sprintf('%d%%', Goodness));
        % Update figures
        FireUpdateDisplayOptions();
    end
end



