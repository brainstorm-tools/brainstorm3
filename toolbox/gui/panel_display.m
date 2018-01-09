function varargout = panel_display(varargin)
% PANEL_DISPLAY: Create a panel edit the time-frequency displays.
% 
% USAGE:  bstPanelNew = panel_display('CreatePanel')
%                       panel_display('UpdatePanel')
%                       panel_display('CurrentFigureChanged_Callback', hFig)
%                       panel_display('SetSelectedRowName', hFig, 'uparrow')   : Switch to previous data row
%                       panel_display('SetSelectedRowName', hFig, 'downarrow') : Switch to next data row
%                       panel_display('SetSelectedRowName', hFig, RowName)

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2010-2016; Martin Cousineau, 2017

eval(macro_method);
end


%% ===== CREATE PANEL =====
function bstPanelNew = CreatePanel() %#ok<DEFNU>
    panelName = 'Display';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;

    % Create tools panel
    jPanelNew = java_create('javax.swing.JPanel');
    jPanelNew.setLayout(BoxLayout(jPanelNew, BoxLayout.PAGE_AXIS));
    jPanelNew.setBorder(BorderFactory.createEmptyBorder(10,10,0,10));
    
    % ===== TF: SELECTED DATA =====
    jPanelSelect = gui_river([0,1], [2,4,4,0], 'Selected data');
    jPanelSelect.setVisible(0);
        % Combobox: list of the available rows of data
        jComboRows = JComboBox();
        jComboRows.setFont(bst_get('Font'));
        java_setcb(jComboRows, 'ItemStateChangedCallback', @ComboRowsStateChange_Callback);
        jPanelSelect.add('hfill', jComboRows);
        % Checkbox: Hide edge effects / Resolution
        jCheckHideEdge = gui_component('Checkbox', jPanelSelect, 'br', 'Hide edge effects', [], '', @DisplayOptions_Callback);
        jCheckHighRes  = gui_component('Checkbox', jPanelSelect, 'br', 'Smooth display', [], '', @DisplayOptions_Callback);
    jPanelNew.add(jPanelSelect);   

    % ===== TF: MEASURE =====
    jPanelFunction = gui_river([0,1], [2,4,4,0], 'Measure');
    jPanelFunction.setVisible(0);
        % Radio: Select function to apply on top of the TF values
        jButtonGroup = ButtonGroup();
        jRadioFunPower = gui_component('Radio', jPanelFunction, 'br', 'Power',      jButtonGroup, '', @DisplayOptions_Callback);
        jRadioFunMag   = gui_component('Radio', jPanelFunction, 'br', 'Magnitude',  jButtonGroup, '', @DisplayOptions_Callback);
        jRadioFunLog   = gui_component('Radio', jPanelFunction, 'br', 'Log(power)', jButtonGroup, '', @DisplayOptions_Callback);
        jRadioFunPhase = gui_component('Radio', jPanelFunction, 'br', 'Phase',      jButtonGroup, '', @DisplayOptions_Callback);
    jPanelNew.add(jPanelFunction);
    
    % ===== PAC: PAC/FLOW/FHIGH =====
    jPanelPac = gui_river([0,1], [2,4,4,0], 'PAC value');
    jPanelPac.setVisible(0);
        % Radio: Select function to apply on top of the TF values
        jButtonGroup = ButtonGroup();
        jRadioPacMax   = gui_component('Radio', jPanelPac, 'br', 'MaxPAC',    jButtonGroup, '', @DisplayOptions_Callback);
        jRadioPacFlow  = gui_component('Radio', jPanelPac, 'br', 'Freq low',  jButtonGroup, '', @DisplayOptions_Callback);
        jRadioPacFhigh = gui_component('Radio', jPanelPac, 'br', 'Freq high', jButtonGroup, '', @DisplayOptions_Callback);
    jPanelNew.add(jPanelPac);
    
    
    %% ===== CONNECT: DATA THRESHOLD =====
    jPanelThreshold = gui_river([1,1], [2,2,2,2], 'Intensity Thresh. (0 - 0)');
        % Connectivity slider
        jSliderThreshold = JSlider(0, 100, 0);
        java_setcb(jSliderThreshold, 'MouseReleasedCallback', @SliderConnect_Callback, ...
                                     'KeyPressedCallback',    @SliderConnect_Callback);
        jSliderThreshold.setPreferredSize(java_scaled('dimension', 130, 22));
        jPanelThreshold.add('hfill', jSliderThreshold);
        % Threshold label
        jLabelConnectThresh = gui_component('label', jPanelThreshold, [], '0.00 ', {JLabel.LEFT, java_scaled('dimension', 40, 22)});
        % Quick preview
        % java_setcb(jSliderThreshold, 'StateChangedCallback',  @(h,ev)jLabelConnectThresh.setText(sprintf('%1.2d', double(ev.getSource().getValue()))));
    jPanelNew.add(jPanelThreshold);
        
    %% ===== CONNECT: DISTANCE THRESHOLD =====
    jPanelDistance = gui_river([0,0], [2,2,2,2], 'Distance Filtering (0 - 150 mm)');
        % Minimum Distance title
        jLabelMinimumDistance = gui_component('label', [], [], 'Min.', {JLabel.LEFT, java_scaled('dimension', 25, 22)});
        jPanelDistance.add('br', jLabelMinimumDistance);
        % Distance slider
        jSliderMinimumDistance = JSlider(0, 150, 0);
        java_setcb(jSliderMinimumDistance,  'MouseReleasedCallback', @SliderConnect_Callback, ...
                                            'KeyPressedCallback',    @SliderConnect_Callback);
        jSliderMinimumDistance.setPreferredSize(java_scaled('dimension', 100, 22));
        jPanelDistance.add('', jSliderMinimumDistance);
        % Distance Threshold label
        jLabelConnectMinimumDistance = gui_component('label', [], [], '0 mm', {JLabel.RIGHT, java_scaled('dimension', 40, 22)});
        jPanelDistance.add('', jLabelConnectMinimumDistance);
        % Quick preview
        java_setcb(jSliderMinimumDistance, 'StateChangedCallback',  @(h,ev)jLabelConnectMinimumDistance.setText(sprintf('%d mm', double(ev.getSource().getValue()))));
    jPanelNew.add(jPanelDistance);
    
    %% ===== CONNECT: LINKS =====
    % Direction
    jPanelLinks = gui_river([1,1], [2,2,2,2], 'Direction');
        % gui_component('label', jPanelLinks, [], 'Direction: ');
        jToggleOut   = gui_component('radio', [], [], 'Out',  [], [], @CheckDisplay_Callback);
        jToggleIn    = gui_component('radio', [], [], 'In',   [], [], @CheckDisplay_Callback);
        jToggleBiDir = gui_component('radio', [], [], 'Bi', [], [], @CheckDisplay_Callback);
        jToggleBoth  = gui_component('radio', [], [], 'All', [], [], @CheckDisplay_Callback);
        jPanelLinks.add('', jToggleOut);
        jPanelLinks.add('', jToggleIn);
        jPanelLinks.add('', jToggleBiDir);
        jPanelLinks.add('', jToggleBoth);
    jPanelNew.add(jPanelLinks);
    % Anatomical filtering
    jPanelAnatomical = gui_river([1,1], [2,2,2,2], 'Anatomy');
        % gui_component('label', jPanelAnatomical, 'br', 'Anatomy: ');
        jToggleAll  = gui_component('radio', [], [], 'All',   [], [], @ToggleAnatomicalFiltering_Callback);
        jToggleHemi = gui_component('radio', [], [], 'Between Hemisphere',  [], [], @ToggleAnatomicalFiltering_Callback);
        jToggleLobe = gui_component('radio', [], [], 'Between Lobes', [], [], @ToggleAnatomicalFiltering_Callback);
        jPanelAnatomical.add('', jToggleAll);
        jPanelAnatomical.add('br', jToggleHemi);
        jPanelAnatomical.add('br', jToggleLobe);
    jPanelNew.add(jPanelAnatomical);
    
    % Set max panel sizes
    drawnow;
    jPanelFunction.setMaximumSize(java.awt.Dimension(jPanelFunction.getMaximumSize().getWidth(), jPanelFunction.getPreferredSize().getHeight()));
    jPanelPac.setMaximumSize(java.awt.Dimension(jPanelPac.getMaximumSize().getWidth(), jPanelPac.getPreferredSize().getHeight()));
    jPanelSelect.setMaximumSize(java.awt.Dimension(jPanelSelect.getMaximumSize().getWidth(), jPanelSelect.getPreferredSize().getHeight()));
    jPanelThreshold.setMaximumSize(java.awt.Dimension(jPanelThreshold.getMaximumSize().getWidth(), jPanelThreshold.getPreferredSize().getHeight()));
    jPanelDistance.setMaximumSize(java.awt.Dimension(jPanelDistance.getMaximumSize().getWidth(), jPanelDistance.getPreferredSize().getHeight()));
    jPanelLinks.setMaximumSize(java.awt.Dimension(jPanelLinks.getMaximumSize().getWidth(), jPanelLinks.getPreferredSize().getHeight()));
    jPanelAnatomical.setMaximumSize(java.awt.Dimension(jPanelAnatomical.getMaximumSize().getWidth(), jPanelAnatomical.getPreferredSize().getHeight()));
    
    % Add an extra glue at the end, so that panel stay small
    jPanelNew.add(Box.createVerticalGlue());
    % Disable everything
    jComboRows.setEnabled(0);
    jRadioFunPower.setEnabled(0);
    jRadioFunMag.setEnabled(0);
    jRadioFunLog.setEnabled(0);
    jRadioFunPhase.setEnabled(0);
    jCheckHideEdge.setEnabled(0);
    jCheckHighRes.setEnabled(0);
    
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jPanelSelect',           jPanelSelect, ...
                                  'jPanelFunction',         jPanelFunction, ...
                                  'jPanelPac',              jPanelPac, ...
                                  'jPanelThreshold',        jPanelThreshold, ...
                                  'jPanelDistance',         jPanelDistance, ...
                                  'jPanelLinks',            jPanelLinks, ...
                                  'jPanelAnatomical',       jPanelAnatomical, ...
                                  'jComboRows',             jComboRows, ...
                                  'jRadioFunPower',         jRadioFunPower, ...
                                  'jRadioFunMag',           jRadioFunMag, ...
                                  'jRadioFunLog',           jRadioFunLog, ...
                                  'jRadioFunPhase',         jRadioFunPhase, ...
                                  'jRadioPacMax',           jRadioPacMax, ...
                                  'jRadioPacFlow',          jRadioPacFlow, ...
                                  'jRadioPacFhigh',         jRadioPacFhigh, ...
                                  'jCheckHideEdge',         jCheckHideEdge, ...
                                  'jCheckHighRes',          jCheckHighRes, ...
                                  'jSliderThreshold',       jSliderThreshold, ...
                                  'jLabelConnectThresh',    jLabelConnectThresh, ...
                                  'jSliderMinimumDistance', jSliderMinimumDistance, ...
                                  'jToggleOut',             jToggleOut, ...
                                  'jToggleIn',              jToggleIn, ...
                                  'jToggleBoth',            jToggleBoth, ...
                                  'jToggleBiDir',           jToggleBiDir, ...
                                  'jToggleAll',             jToggleAll, ...
                                  'jToggleHemi',            jToggleHemi, ...
                                  'jToggleLobe',            jToggleLobe));

    
%% =================================================================================
%  === CONTROLS CALLBACKS  =========================================================
%  =================================================================================            
    %% ===== RADIO BUTTON: CHANGE FUNCTIONS =====
    function DisplayOptions_Callback(varargin)
        % Update display options
        SetDisplayOptions();
    end

    %% ===== SLIDER CONNECTIVITY CALLBACK =====
    function SliderConnect_Callback(varargin)
        % Process slider callbacks only if it has focus
        if jSliderThreshold.hasFocus()
            SetThresholdOptions();
        elseif jSliderMinimumDistance.hasFocus()
            SetDistanceOptions();
        end
    end

    %% ===== CONNECTIVITY DISPLAY CHECKBOX CALLBACK =====
    function CheckDisplay_Callback(varargin)
        if (jToggleOut.hasFocus())
            SetConnectivityDisplayOptions([], 0);
        elseif (jToggleIn.hasFocus())
            SetConnectivityDisplayOptions([], 1);
        elseif (jToggleBoth.hasFocus())
            SetConnectivityDisplayOptions([], 2);
        elseif (jToggleBiDir.hasFocus())
            SetConnectivityDisplayOptions([], 3);
        end
    end

    function ToggleAnatomicalFiltering_Callback(varargin)
        AnatomicalFilter = 0;
        if (jToggleAll.hasFocus())
            AnatomicalFilter = 0;
        elseif (jToggleHemi.hasFocus())
            AnatomicalFilter = 1;
        elseif (jToggleLobe.hasFocus())
            AnatomicalFilter = 2;
        end
        SetAnatomicalFilteringOptions([], AnatomicalFilter);
    end
end

%% =================================================================================
%  === EXTERNAL PANEL CALLBACKS  ===================================================
%  =================================================================================
%% ===== COMBOBOX ROW SELECTION =====
function ComboRowsStateChange_Callback(h,ev)
    if (ev.getStateChange() == ev.SELECTED)
        % Update options
        SetDisplayOptions();
    end
end

%% ===== CURRENT FIGURE CHANGED =====
function CurrentFigureChanged_Callback(hFig) %#ok<DEFNU>
    % Select display options (time checkbox...)
    UpdatePanel(hFig);
end
    

%% =================================================================================
%  === TIME-FREQ FUNCTIONS =========================================================
%  =================================================================================

%% ===== UPDATE PANEL =====
function UpdatePanel(hFig)
    global GlobalData;
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Display');
    if isempty(ctrl)
        return;
    end
    % Get figure configuration
    if ~isempty(hFig)
        TfInfo = getappdata(hFig, 'Timefreq');
        TsInfo = getappdata(hFig, 'TsInfo');
    else
        % Try to find another figure with TF info
        TfInfo = [];
        TsInfo = [];
    end
    if (isempty(TfInfo) || isempty(TfInfo.FileName)) && (isempty(TsInfo) || isempty(TsInfo.FileName) || ~isequal(TsInfo.DisplayMode, 'image'))
        ctrl.jComboRows.setEnabled(0);
        ctrl.jRadioFunPower.setEnabled(0);
        ctrl.jRadioFunMag.setEnabled(0);
        ctrl.jRadioFunLog.setEnabled(0);
        ctrl.jRadioFunPhase.setEnabled(0);
        ctrl.jCheckHideEdge.setEnabled(0);
        ctrl.jCheckHighRes.setEnabled(0);
        ctrl.jPanelSelect.setVisible(0);
        ctrl.jPanelFunction.setVisible(0);
        ctrl.jPanelPac.setVisible(0);
        ctrl.jPanelThreshold.setVisible(0);
        ctrl.jPanelDistance.setVisible(0);
        ctrl.jPanelAnatomical.setVisible(0);
        ctrl.jPanelLinks.setVisible(0);
        return
    end
    % Get figure ID
    FigureId = getappdata(hFig, 'FigureId');
    
    % ===== UPDATE IMAGE =====
    if strcmpi(FigureId.Type, 'Image')
        % Get figure handles
        [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
        % If there is a page to select for this figure
        AllLabels = GlobalData.DataSet(iDS).Figure(iFig).Handles.Labels;
        if ~isempty(AllLabels{4}) && (length(AllLabels{4}) >= 2)
            isEnabledRow = UpdateRowList(AllLabels{4}, GlobalData.DataSet(iDS).Figure(iFig).Handles.PageName);
        else
            isEnabledRow = UpdateRowList({}, []);
            %isEnabledRow = 0;
        end
        % Enable row selection controls
        ctrl.jComboRows.setEnabled(isEnabledRow);
        ctrl.jPanelSelect.setVisible(isEnabledRow);
        % Disable the rest of the panel
        ctrl.jRadioFunPower.setEnabled(0);
        ctrl.jRadioFunMag.setEnabled(0);
        ctrl.jRadioFunLog.setEnabled(0);
        ctrl.jRadioFunPhase.setEnabled(0);
        ctrl.jCheckHideEdge.setEnabled(0);
        ctrl.jCheckHighRes.setEnabled(0);
        ctrl.jPanelFunction.setVisible(0);
        ctrl.jPanelPac.setVisible(0);
        ctrl.jPanelThreshold.setVisible(0);
        ctrl.jPanelDistance.setVisible(0);
        ctrl.jPanelAnatomical.setVisible(0);
        ctrl.jPanelLinks.setVisible(0);
        
    % ===== UPDATE FREQUENCY =====
    else
        % Get data description
        [iDS, iTimefreq] = bst_memory('GetDataSetTimefreq', TfInfo.FileName);
        % === MEASURE ===
        % Select function
        switch lower(TfInfo.Function)
            case 'power',      ctrl.jRadioFunPower.setSelected(1);
            case 'magnitude',  ctrl.jRadioFunMag.setSelected(1);
            case 'log',        ctrl.jRadioFunLog.setSelected(1);
            case 'phase',      ctrl.jRadioFunPhase.setSelected(1);
        end
        % Enable available functions
        switch lower(GlobalData.DataSet(iDS).Timefreq(iTimefreq).Measure)
            case 'none'
                if ismember(GlobalData.DataSet(iDS).Timefreq(iTimefreq).Method, {'plv', 'plvt'})
                    ctrl.jRadioFunPower.setEnabled(0);
                    ctrl.jRadioFunLog.setEnabled(0);
                else
                    ctrl.jRadioFunPower.setEnabled(1);
                    ctrl.jRadioFunLog.setEnabled(1);
                end
                ctrl.jRadioFunMag.setEnabled(1);
                ctrl.jRadioFunPhase.setEnabled(1);
            case {'power', 'magnitude', 'log'}
                ctrl.jRadioFunPower.setEnabled(1);
                ctrl.jRadioFunMag.setEnabled(1);
                ctrl.jRadioFunLog.setEnabled(1);
                ctrl.jRadioFunPhase.setEnabled(0);
            case 'phase'
                ctrl.jRadioFunPower.setEnabled(0);
                ctrl.jRadioFunMag.setEnabled(0);
                ctrl.jRadioFunLog.setEnabled(0);
                ctrl.jRadioFunPhase.setEnabled(1);            
        end
        % Entire panel
        if ~ismember(GlobalData.DataSet(iDS).Timefreq(iTimefreq).Measure, {'none', 'power', 'magnitude', 'log', 'phase'})
            ctrl.jPanelFunction.setVisible(0);
        else
            ctrl.jPanelFunction.setVisible(1);
        end

        % === PAC PANEL ===
        % Select function
        switch lower(TfInfo.Function)
            case 'maxpac',    ctrl.jRadioPacMax.setSelected(1);
            case 'pacflow',   ctrl.jRadioPacFlow.setSelected(1);
            case 'pacfhigh',  ctrl.jRadioPacFhigh.setSelected(1);
        end
        % Entire panel
        if ~ismember(lower(TfInfo.Function), {'maxpac', 'pacflow', 'pacfhigh'}) || ~isequal(GlobalData.DataSet(iDS).Timefreq(iTimefreq).Freqs, 0)
            ctrl.jPanelPac.setVisible(0);
        else
            ctrl.jPanelPac.setVisible(1);
        end

        % === SELECTED DATA ===
        % Hide edge effects
        if strcmpi(FigureId.Type, 'Timefreq') && isempty(GlobalData.DataSet(iDS).Timefreq(iTimefreq).TimeBands) % && ~iscell(GlobalData.DataSet(iDS).Timefreq(iTimefreq).Freqs)
            isEnabledEdge = 1;
            ctrl.jCheckHideEdge.setSelected(TfInfo.HideEdgeEffects);
        else
            isEnabledEdge = 0;
        end
        ctrl.jCheckHideEdge.setEnabled(isEnabledEdge);
        % Resolution
        ctrl.jCheckHighRes.setEnabled(strcmpi(FigureId.Type, 'Timefreq') || strcmpi(FigureId.Type, 'Pac'));
        ctrl.jCheckHighRes.setSelected(TfInfo.HighResolution);
        % Get all row names available
        AllRows = figure_timefreq('GetRowNames', GlobalData.DataSet(iDS).Timefreq(iTimefreq).RefRowNames, GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames);
        % Update row list
        if ~isempty(TfInfo.RefRowName)
            isEnabledRow = UpdateRowList(GlobalData.DataSet(iDS).Timefreq(iTimefreq).RefRowNames, TfInfo.RefRowName);
        elseif ismember(TfInfo.DisplayMode, {'AllSensors', '2DLayout', '2DLayoutOpt'}) || isempty(TfInfo.RowName) || (iscell(TfInfo.RowName) && (length(TfInfo.RowName) > 1))
            isEnabledRow = UpdateRowList({}, []);
        elseif iscell(AllRows)
            isEnabledRow = UpdateRowList(AllRows, TfInfo.RowName);
        else
            isEnabledRow = UpdateRowList('Sources', []);
        end
        % Entire panel
        ctrl.jPanelSelect.setVisible(isEnabledEdge || isEnabledRow);

        % === CONNECTIVITY ===
        % Connectivity options
        isConnect = strcmpi(FigureId.Type, 'Connect');
        if isConnect
            ctrl.jPanelThreshold.setVisible(1);
            % Get Threshold Min/Max
            ThresholdMinMax = getappdata(hFig, 'ThresholdMinMax');
            if isempty(ThresholdMinMax)
                ThresholdMinMax = getappdata(hFig, 'DataMinMax');
            end
            Diff = ThresholdMinMax(2) - ThresholdMinMax(1);
            % Threshold filter
            Threshold = getappdata(hFig, 'MeasureThreshold');
            SliderValue = (Threshold - ThresholdMinMax(1)) / Diff * 100;
            ctrl.jSliderThreshold.setValue(SliderValue);
            ctrl.jLabelConnectThresh.setText(num2str(Threshold,3));
            % Distance filter
            MinimumDistanceThresh = getappdata(hFig, 'MeasureMinDistanceFilter');
            ctrl.jSliderMinimumDistance.setValue(MinimumDistanceThresh);
            % Direction filter
            DisplayOutwardMeasure = getappdata(hFig, 'DisplayOutwardMeasure');
            DisplayInwardMeasure = getappdata(hFig, 'DisplayInwardMeasure');
            DisplayBidirectionalMeasure = getappdata(hFig, 'DisplayBidirectionalMeasure');
            ctrl.jToggleOut.setSelected(DisplayOutwardMeasure && ~DisplayInwardMeasure);
            ctrl.jToggleIn.setSelected(DisplayInwardMeasure && ~DisplayOutwardMeasure);
            ctrl.jToggleBoth.setSelected(DisplayOutwardMeasure && DisplayInwardMeasure);
            ctrl.jToggleBiDir.setSelected(~DisplayOutwardMeasure && ~DisplayInwardMeasure && DisplayBidirectionalMeasure);
            % Update Anatomical filtering      
            MeasureAnatomicalFilter = getappdata(hFig, 'MeasureAnatomicalFilter');
            ctrl.jToggleAll.setSelected(MeasureAnatomicalFilter == 0);
            ctrl.jToggleHemi.setSelected(MeasureAnatomicalFilter == 1);
            ctrl.jToggleLobe.setSelected(MeasureAnatomicalFilter == 2);
            % Update filtering title
            MinIntensity = sprintf('%1.3f',ThresholdMinMax(1));
            MaxIntensity = sprintf('%1.3f',ThresholdMinMax(2));
            ctrl.jPanelThreshold.get('Border').setTitle(['Intensity Thresh. (' MinIntensity ' - ' MaxIntensity ')']);
            MinDistance = num2str(0);
            MaxDistance = num2str(150);
            ctrl.jPanelDistance.get('Border').setTitle(['Distance Filtering (' MinDistance ' - ' MaxDistance 'mm)']);

            % Filter Distance Panel
            HasLocationsData = getappdata(hFig, 'HasLocationsData');
            if isempty(HasLocationsData)
                HasLocationsData = 0;
            end
            ctrl.jPanelDistance.setVisible(HasLocationsData);

            % Display Direction Panel
            IsDirectionalData = getappdata(hFig, 'IsDirectionalData');
            if isempty(IsDirectionalData)
                IsDirectionalData = 0;
            end
            ctrl.jPanelLinks.setVisible(IsDirectionalData);
            % Filter Anatomical Panel
            DisplayInRegion = getappdata(hFig, 'DisplayInRegion');
            if isempty(DisplayInRegion)
                DisplayInRegion = 0;
            end
            ctrl.jPanelAnatomical.setVisible(DisplayInRegion);

        else
            ctrl.jPanelThreshold.setVisible(0);
            ctrl.jPanelDistance.setVisible(0);
            ctrl.jPanelLinks.setVisible(0);
            ctrl.jPanelAnatomical.setVisible(0);
        end
    end
    % Repaint just in case
    ctrl.jPanelThreshold.getParent().revalidate();
    ctrl.jPanelThreshold.getParent().repaint();
end


%% ===== GET DISPLAY OPTIONS =====
function sOptions = GetDisplayOptions()
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Display');
    if isempty(ctrl)
        sOptions = [];
        return
    end
    % Get current panel figure
    [hFig,iFig,iDS] = GetPanelFigure();
    if isempty(hFig)
        sOptions = [];
        return
    end
    % Get current row
    sOptions.RowName = ctrl.jComboRows.getSelectedItem();
    if ~isempty(sOptions.RowName) && strcmpi(sOptions.RowName, 'Sources')
        sOptions.RowName = [];
    end
    % Get display function
    if ctrl.jRadioFunPower.isSelected()
        sOptions.Function = 'power';
    elseif ctrl.jRadioFunMag.isSelected()
        sOptions.Function = 'magnitude';
    elseif ctrl.jRadioFunLog.isSelected()
        sOptions.Function = 'log';
    elseif ctrl.jRadioFunPhase.isSelected()
        sOptions.Function = 'phase';
    elseif ctrl.jRadioPacMax.isSelected()
        sOptions.Function = 'maxpac';
    elseif ctrl.jRadioPacFlow.isSelected()
        sOptions.Function = 'pacflow';
    elseif ctrl.jRadioPacFhigh.isSelected()
        sOptions.Function = 'pacfhigh';
    else
        sOptions.Function = 'other';
    end
    % Hide edge effects / Resolution
    sOptions.HideEdgeEffects = ctrl.jCheckHideEdge.isSelected();
    sOptions.HighResolution = ctrl.jCheckHighRes.isSelected();
    
    % ===== CONNECTIVITY FIGURES =====
    % Get connectivity threshold
    sOptions.DataThreshold = ctrl.jSliderThreshold.getValue() / 100;
    % Get distance threshold
    sOptions.MinDistanceThreshold = ctrl.jSliderMinimumDistance.getValue();
    % Get display connectivity
    sOptions.DisplayOutwardMeasure = ctrl.jToggleOut.isSelected();
    sOptions.DisplayInwardMeasure = ctrl.jToggleIn.isSelected();
    sOptions.DisplayBothMeasure = ctrl.jToggleBoth.isSelected();
    sOptions.DisplayBidirectionalMeasure = ctrl.jToggleBiDir.isSelected();
    % Get Anatomical filtering
    if (ctrl.jToggleHemi.isSelected())
        sOptions.MeasureAnatomicalFilter = 1;
    elseif (ctrl.jToggleLobe.isSelected())
        sOptions.MeasureAnatomicalFilter = 2;
    else
        sOptions.MeasureAnatomicalFilter = 0;
    end
end
    

%% ===== SET DISPLAY OPTIONS =====
function SetDisplayOptions(sOptions)
    global GlobalData;
    % Get current display options
    if (nargin < 1) || isempty(sOptions)
        sOptions = GetDisplayOptions();
    end
    % Get current panel figure
    [hFig,iFig,iDS] = GetPanelFigure();
    if isempty(hFig)
        return
    end
    
    % ===== FIGURE: IMAGE =====
    if strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.Type, 'Image')
        % Get page info
        Labels = GlobalData.DataSet(iDS).Figure(iFig).Handles.Labels{4};
        % No changes
        if isequal(GlobalData.DataSet(iDS).Figure(iFig).Handles.PageName, sOptions.RowName) || (length(Labels) < 2)
            return;
        end
        % If there is a page to select for this figure
        GlobalData.DataSet(iDS).Figure(iFig).Handles.PageName = sOptions.RowName;
    
    % ===== FIGURE: TIME-FREQUENCY =====
    else
        % Get figure configuration
        TfInfo = getappdata(hFig, 'Timefreq');
        if isempty(TfInfo)
            return
        end
        % If nothing changed or RowUpdate for 2DLayout: return
        if isequal(TfInfo.Function, sOptions.Function) && ...
           isequal(TfInfo.HideEdgeEffects, sOptions.HideEdgeEffects) && ...
           isequal(TfInfo.HighResolution, sOptions.HighResolution) && ...
           (isequal(TfInfo.RowName, sOptions.RowName) || ismember(TfInfo.DisplayMode, {'2DLayout', '2DLayoutOpt', 'AllSensors'}))
            return
        end
        % Save new values
        if ~isempty(sOptions.RowName)
            if ~isempty(TfInfo.RefRowName)
                prevRowName = TfInfo.RefRowName;
                TfInfo.RefRowName = sOptions.RowName;
            else
                prevRowName = TfInfo.RowName;
                TfInfo.RowName = sOptions.RowName;
            end
        end
        if ~strcmpi(TfInfo.Function, 'other')
            TfInfo.Function = sOptions.Function;
            
            % Remember option for spectrum figures.
            if strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.Type, 'Spectrum')
                bst_set('LastPsdDisplayFunction', sOptions.Function);
            end
        end
        TfInfo.HideEdgeEffects = sOptions.HideEdgeEffects;
        TfInfo.HighResolution  = sOptions.HighResolution;
        % Update figure handles
        setappdata(hFig, 'Timefreq', TfInfo);
    end
    
    % ===== UPDATE GUI =====
    % Update display
    bst_progress('start', 'Time-frequency tab', 'Updating figures...');
    switch (GlobalData.DataSet(iDS).Figure(iFig).Id.Type)
        case 'Topography', figure_topo('UpdateTopoPlot', iDS, iFig);
        case 'Spectrum',   figure_spectrum('DisplayOptionsChangedCallback', hFig);           
        case '3DViz',      panel_surface('UpdateSurfaceData', hFig);
        case 'MriViewer',  panel_surface('UpdateSurfaceData', hFig);
        case 'Connect',    figure_connect('UpdateFigurePlot', hFig);
        case 'Pac'   
            % Update this figure
            figure_pac('UpdateFigurePlot', hFig);
            % If there is a selected RowName and if it was updated: Try updating other figures   (Skip update for RefRowName change)
            if ~isempty(sOptions.RowName) && ~isequal(sOptions.RowName, prevRowName) && isempty(TfInfo.RefRowName)
                % Find other similar figures that could be updated
                hFigOthers = bst_figures('GetFiguresByType', 'Pac');
                hFigOthers = setdiff(hFigOthers, hFig);
                for i = 1:length(hFigOthers)
                    % Get figure configuration
                    TfInfoOther = getappdata(hFigOthers(i), 'Timefreq');
                    % Check that the figure had the same initial RowName selection
                    if isempty(TfInfoOther) || ~isequal(TfInfoOther.RowName, prevRowName)
                        continue;
                    end
                    % Get loaded timefreq file
                    [iDS, iTimefreq] = bst_memory('GetDataSetTimefreq', TfInfoOther.FileName);
                    if isempty(iDS)
                        continue;
                    end
                    % If the new destination RowName also exists in this file: Update figure
                    if ismember(sOptions.RowName, GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames)
                        % Update figure description
                        TfInfoOther.RowName = sOptions.RowName;
                        setappdata(hFigOthers(i), 'Timefreq', TfInfoOther);
                        % Redraw this figure
                        figure_pac('UpdateFigurePlot', hFigOthers(i), 1);
                    end
                end
            end
        case 'Timefreq'
            % Update this figure
            figure_timefreq('UpdateFigurePlot', hFig, 1);
            % If there is a selected RowName and if it was updated: Try updating other figures   (Skip update for RefRowName change)
            if ~isempty(sOptions.RowName) && ~isequal(sOptions.RowName, prevRowName) && isempty(TfInfo.RefRowName)
                % Find other similar figures that could be updated
                hFigOthers = bst_figures('GetFiguresByType', 'Timefreq');
                hFigOthers = setdiff(hFigOthers, hFig);
                for i = 1:length(hFigOthers)
                    % Get figure configuration
                    TfInfoOther = getappdata(hFigOthers(i), 'Timefreq');
                    % Check that the figure had the same initial RowName selection
                    % (and skip the figures showing the same file, to allow the change of row for a cloned figure)
                    if isempty(TfInfoOther) || ~isequal(TfInfoOther.RowName, prevRowName) || isequal(TfInfo.FileName, TfInfoOther.FileName)
                        continue;
                    end
                    % Get loaded timefreq file
                    [iDS, iTimefreq] = bst_memory('GetDataSetTimefreq', TfInfoOther.FileName);
                    if isempty(iDS)
                        continue;
                    end
                    % If the new destination RowName also exists in this file: Update figure
                    if ismember(sOptions.RowName, GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames)
                        % Update figure description
                        TfInfoOther.RowName = sOptions.RowName;
                        setappdata(hFigOthers(i), 'Timefreq', TfInfoOther);
                        % Redraw this figure
                        figure_timefreq('UpdateFigurePlot', hFigOthers(i), 1);
                    end
                end
            end
        case 'Image'
            %bst_figures('ReloadFigures', hFig);
            figure_image('UpdateFigurePlot', hFig, 1);
    end
    drawnow;
    bst_progress('stop');
end


%% ===== SET SMOOTH DISPLAY =====
function SetSmoothDisplay(HighResolution, hFigs) %#ok<DEFNU>
    % Get figures
    if (nargin < 2) || isempty(hFigs)
        [hFigs,iFig,iDS] = bst_figures('GetFiguresByType', 'timefreq');
    end
    % Update the display of all figures
    for i = 1:length(hFigs)
        % Update the figure configuration
        TfInfo = getappdata(hFigs(i), 'Timefreq');
        TfInfo.HighResolution = HighResolution;
        setappdata(hFigs(i), 'Timefreq', TfInfo);
        % Update display
        figure_timefreq('UpdateFigurePlot', hFigs(i));
    end
    % Update panel
    UpdatePanel(hFigs(end));
end


%% ===== GET PANEL FIGURE =====
function [hFig,iFig,iDS] = GetPanelFigure()
    % Get current figure (ANY)
    [hFig,iFig,iDS] = bst_figures('GetCurrentFigure');
    if isempty(hFig)
        return
    end
    % Get figure configuration
    TfInfo = getappdata(hFig, 'Timefreq');
    TsInfo = getappdata(hFig, 'TsInfo');
    % If figure is not valid: try to get specifically the last TF figure
    if (isempty(TfInfo) || isempty(TfInfo.FileName)) && (isempty(TsInfo) || isempty(TsInfo.FileName) || ~isequal(TsInfo.DisplayMode, 'image'))
        % Get current figure (TF)
        [hFig,iFig,iDS] = bst_figures('GetCurrentFigure', 'TF');
        if isempty(hFig)
            return
        end
        % Get figure configuration
        TfInfo = getappdata(hFig, 'Timefreq');
        TsInfo = getappdata(hFig, 'TsInfo');
        % If figure is not valid: Exit
        if (isempty(TfInfo) || isempty(TfInfo.FileName)) && (isempty(TsInfo) || isempty(TsInfo.FileName) || ~isequal(TsInfo.DisplayMode, 'image'))
            return;
        end 
    end
end


%% ===== UPDATE ROW LIST =====
function isEnabled = UpdateRowList(RowNames, selRow)
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Display');
    if isempty(ctrl)
        isEnabled = 0;
        return;
    end
    % Get list of items in combo box
    comboItems = cell(1, ctrl.jComboRows.getItemCount());
    for i = 1:length(comboItems)
        comboItems{i} = ctrl.jComboRows.getItemAt(i-1);
    end
    % Combobox: update list of data rows
    if isempty(RowNames)
        jModel = javax.swing.DefaultComboBoxModel();
    elseif ~isequal(comboItems, RowNames)
        jModel = javax.swing.DefaultComboBoxModel(RowNames);
    else
        jModel = [];
    end
    % Combobox: Select current row
    if ischar(selRow) || (iscell(selRow) && (length(selRow) == 1))
        iSel = find(strcmpi(selRow, RowNames), 1) - 1;
    else
        iSel = [];
    end
    % Enable / disable list
    isEnabled = ~isempty(RowNames) && ((iscell(RowNames) && ~strcmpi(RowNames{1}, 'Sources')) || ~strcmpi(RowNames, 'Sources'));
    ctrl.jComboRows.setEnabled(isEnabled);

    % Update combobox selection
    if ~isempty(jModel) || ~isempty(iSel)
        % Combobox: Disable callback
        java_setcb(ctrl.jComboRows, 'ItemStateChangedCallback', []);
        % Update list
        if ~isempty(jModel)
            ctrl.jComboRows.setModel(jModel);
        end
        % Update selection
        if ~isempty(iSel)
            ctrl.jComboRows.setSelectedIndex(iSel);
        end
        % Redraw combobox
        ctrl.jComboRows.repaint();
        drawnow
        % Restore callback
        java_setcb(ctrl.jComboRows, 'ItemStateChangedCallback', @ComboRowsStateChange_Callback);
    end
end


%% ===== SET SELECTED ROW NAME (TF) =====
% USAGE:  SetSelectedRowName(hFig, 'uparrow')   : Switch to previous data row
%         SetSelectedRowName(hFig, 'downarrow') : Switch to next data row
%         SetSelectedRowName(hFig, RowName)
function SetSelectedRowName(hFig, newRowName) %#ok<DEFNU>
    global GlobalData;
    % Get figure configuration
    TfInfo = getappdata(hFig, 'Timefreq');
    if isempty(TfInfo) || isempty(TfInfo.FileName)
        return
    end
    oldRowName = TfInfo.RowName;
    % Get data description
    [iDS, iTimefreq] = bst_memory('GetDataSetTimefreq', TfInfo.FileName);
    RowNames = GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames;
    % Get current row
    if iscell(TfInfo.RowName) && (length(TfInfo.RowName) ~= 1)
        % More than one row: not selectable
        return;
    elseif ischar(TfInfo.RowName) || iscell(TfInfo.RowName)
        iCurRow = find(strcmpi(RowNames, TfInfo.RowName));
    else
        iCurRow = TfInfo.RowName;
    end
    % Get new row
    if strcmpi(newRowName, 'downarrow')
        iNewRow = min(iCurRow + 1, length(RowNames));
    elseif strcmpi(newRowName, 'uparrow')
        iNewRow = max(iCurRow - 1, 1);
    else
        iNewRow = find(strcmpi(RowNames, newRowName));
    end
    % Update figure structure
    if ~isempty(iNewRow)
        if iscell(RowNames)
            TfInfo.RowName = RowNames{iNewRow(1)};
        else
            TfInfo.RowName = RowNames(iNewRow(1));
        end
        setappdata(hFig, 'Timefreq', TfInfo);
    end
    % If row selection was modified: Update figure
    if ~strcmpi(oldRowName, TfInfo.RowName)
        FigureId = getappdata(hFig, 'FigureId');
        % Redraw figure
        switch (FigureId.Type)
            case 'Timefreq'
                figure_timefreq('UpdateFigurePlot', hFig);
            case 'Spectrum'
                figure_spectrum('UpdateFigurePlot', hFig, 1);
            case 'Pac'
                figure_pac('UpdateFigurePlot', hFig);
            case 'Connect'
                warning('todo');
        end
        % Update panel
        UpdatePanel(hFig);
    end
end


%% ===== SET SELECTED PAGE (IMAGE) =====
% USAGE:  SetSelectedPage(hFig, 'uparrow')   : Switch to previous data row
%         SetSelectedPage(hFig, 'downarrow') : Switch to next data row
%         SetSelectedPage(hFig, PageName)
function SetSelectedPage(hFig, newPageName) %#ok<DEFNU>
    global GlobalData
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    % Get current page
    curPageName = GlobalData.DataSet(iDS).Figure(iFig).Handles.PageName;
    Labels = GlobalData.DataSet(iDS).Figure(iFig).Handles.Labels{4};
    if isempty(Labels) || (length(Labels) < 2) || isequal(newPageName, curPageName)
        return
    end
    % Get current page index
    iCurPage = find(strcmpi(Labels, curPageName));
    % Get page index
    if strcmpi(newPageName, 'downarrow')
        iNewPage = min(iCurPage + 1, length(Labels));
    elseif strcmpi(newPageName, 'uparrow')
        iNewPage = max(iCurPage - 1, 1);
    else
        iNewPage = find(strcmpi(Labels, newPageName));
    end
    % Nothing to udpate
    if isempty(iNewPage) || isequal(iCurPage, iNewPage)
        return;
    end
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Display');
    if isempty(ctrl)
        return;
    end
    % Update selected row (use the callback to update the figure)
    ctrl.jComboRows.setSelectedIndex(iNewPage - 1);
    % Repaint
    ctrl.jComboRows.getParent().revalidate();
    ctrl.jComboRows.getParent().repaint();
    drawnow;
end



%% =================================================================================
%  === CONNECTIVITY FUNCTIONS ======================================================
%  =================================================================================

%% ===== SET CONNECTIVITY OPTIONS =====
function SetThresholdOptions(sOptions)
    global ConnectSliderMutex;
    % Get current display options
    if (nargin < 1) || isempty(sOptions)
        sOptions = GetDisplayOptions();
    end
    % Get current figure
    [hFig,iFig,iDS] = bst_figures('GetCurrentFigure', 'TF');
    if isempty(hFig)
        return
    end
    % Set a mutex to prevent to enter twice at the same time in the routine
    if (isempty(ConnectSliderMutex))
        tic
        % Set mutex
        ConnectSliderMutex = 0.005;
        % Get figure ID
        FigureId = getappdata(hFig, 'FigureId');
        isConnect = strcmpi(FigureId.Type, 'Connect');
        if isConnect
            % Threshold min/max
            ThresholdMinMax = getappdata(hFig, 'ThresholdMinMax');
            if isempty(ThresholdMinMax)
                ThresholdMinMax = getappdata(hFig, 'DataMinMax');
            end
            Diff = ThresholdMinMax(2) - ThresholdMinMax(1);
            sOptions.DataThreshold = sOptions.DataThreshold * Diff + ThresholdMinMax(1);

            % Get current threshold
            curDataThreshold = getappdata(hFig, 'MeasureThreshold');
            if isempty(curDataThreshold)
                return;
            end
            % Nothing changed
            if (sOptions.DataThreshold == curDataThreshold)
                return;
            end
            % Refresh figure with new threshold
            figure_connect('SetMeasureThreshold', hFig, sOptions.DataThreshold);
            figure_connect('UpdateColormap', hFig);
            % Update panel
            UpdatePanel(hFig);
        end
        % Release mutex
        ConnectSliderMutex = [];
    else
        % Release mutex if last keypress was processed more than one 2s ago
        t = toc;
        if (t > ConnectSliderMutex)
            ConnectSliderMutex = [];
        end
    end
end

function SetDistanceOptions(sOptions)
    global ConnectSliderMutex;
    % Get current display options
    if (nargin < 1) || isempty(sOptions)
        sOptions = GetDisplayOptions();
    end
    % Get current figure
    [hFig,iFig,iDS] = bst_figures('GetCurrentFigure', 'TF');
    if isempty(hFig)
        return
    end
    % Set a mutex to prevent to enter twice at the same time in the routine
    if (isempty(ConnectSliderMutex))
        tic
        % Set mutex
        ConnectSliderMutex = 0.05;
        % Get figure ID
        FigureId = getappdata(hFig, 'FigureId');
        isConnect = strcmpi(FigureId.Type, 'Connect');
        if isConnect
            % Get current threshold
            curMinDistanceThreshold = getappdata(hFig, 'MeasureMinDistanceFilter');
            if isempty(curMinDistanceThreshold)
                return;
            end
            % Nothing changed
            if (sOptions.MinDistanceThreshold == curMinDistanceThreshold)
                return;
            end
            % Refresh figure with new threshold
            figure_connect('SetMeasureDistanceFilter', hFig, sOptions.MinDistanceThreshold, 150);
            figure_connect('UpdateColormap', hFig);
        end
        % Release mutex
        ConnectSliderMutex = [];
    else
        % Release mutex if last keypress was processed more than one 2s ago
        t = toc;
        if (t > ConnectSliderMutex)
            ConnectSliderMutex = [];
        end
    end
end

function SetConnectivityDisplayOptions(sOptions, DisplayButton)
    % Get current display options
    if (nargin < 1) || isempty(sOptions)
        sOptions = GetDisplayOptions();
    end
    % Get current figure
    [hFig,iFig,iDS] = bst_figures('GetCurrentFigure', 'TF');
    if isempty(hFig)
        return
    end
    % Get current threshold
    curDisplayOutwardMeasure = getappdata(hFig, 'DisplayOutwardMeasure');
    curDisplayInwardMeasure = getappdata(hFig, 'DisplayInwardMeasure');
    curDisplayBidirectionalMeasure = getappdata(hFig, 'DisplayBidirectionalMeasure');
    % 
    DisplayBidirectionalMeasure = 0;
    switch DisplayButton
        case 0 
            DisplayOutwardMeasure = 1;
            DisplayInwardMeasure = 0;
        case 1 
            DisplayOutwardMeasure = 0;
            DisplayInwardMeasure = 1;
        case 2 
            DisplayOutwardMeasure = 1;
            DisplayInwardMeasure = 1;
            DisplayBidirectionalMeasure = 1;
        case 3
            DisplayOutwardMeasure = 0;
            DisplayInwardMeasure = 0;
            DisplayBidirectionalMeasure = 1;
    end
    % 
    if (curDisplayOutwardMeasure ~= DisplayOutwardMeasure || ...
        curDisplayInwardMeasure ~= DisplayInwardMeasure || ...
        curDisplayBidirectionalMeasure ~= DisplayBidirectionalMeasure)
        % Refresh figure with new threshold
        figure_connect('setDisplayMeasureMode', hFig, DisplayOutwardMeasure, DisplayInwardMeasure, DisplayBidirectionalMeasure);
        figure_connect('UpdateColormap', hFig);
    end
    UpdatePanel(hFig);
end

function SetAnatomicalFilteringOptions(sOptions, AnatomicalFilter)
    % Get current display options
    if (nargin < 1) || isempty(sOptions)
        %sOptions = GetDisplayOptions();
    end
    % Get current figure
    hFig = bst_figures('GetCurrentFigure', 'TF');
    if isempty(hFig)
        return
    end
    % Get current figure option
    curMeasureAnatomicalFilter = getappdata(hFig, 'MeasureAnatomicalFilter');
    % Get display option
    MeasureAnatomicalFilter = AnatomicalFilter;
    % Nothing changed
    if (MeasureAnatomicalFilter == curMeasureAnatomicalFilter)
        MeasureAnatomicalFilter = 0;
    end
    % Update figure
    figure_connect('SetMeasureAnatomicalFilterTo', hFig, MeasureAnatomicalFilter);
    figure_connect('UpdateColormap', hFig);
    % Update panel
    UpdatePanel(hFig);
end


%% ===== THRESHOLD SLIDER KEYBOARD ACTION =====
function ConnectKeyCallback(ev)     %#ok<DEFNU>
    global ConnectSliderMutex;
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Display');
    if isempty(ctrl)
        return;
    end
    % Set a mutex to prevent to enter twice at the same time in the routine
    if (isempty(ConnectSliderMutex))
        tic
        % Set mutex
        ConnectSliderMutex = 1;
        % === CONVERT KEY EVENT TO MATLAB ===
        [keyEvent, isControl, isShift] = gui_brainstorm('ConvertKeyEvent', ev);
        if isempty(keyEvent.Key)
            ConnectSliderMutex = [];
            return
        end
        % === PROCESS KEY ===
        % Get current threshold
        curThresh = ctrl.jSliderThreshold.getValue();
        % Switch between different keys
        switch (keyEvent.Key)
            case {'+','add'},      curThresh = curThresh + 1;
            case {'-','subtract'}, curThresh = curThresh - 1;
            otherwise,  curThresh = [];
        end
        % Change current threshold
        if ~isempty(curThresh) && (curThresh >= 0) && (curThresh <= 100)
            ctrl.jSliderThreshold.setValue(curThresh);
            SetThresholdOptions();
        end
        drawnow;
        % Release mutex
        ConnectSliderMutex = [];
    else
        % Release mutex if last keypress was processed more than one 2s ago
        % (restore keyboard after a bug...)
        t = toc;
        if (t > 2)
            ConnectSliderMutex = [];
        end
    end
end
