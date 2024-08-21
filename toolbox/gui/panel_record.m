function varargout = panel_record(varargin)
% PANEL_RECORD: Create a panel to explore raw recordings files and edit time markers.
% 
% USAGE:  bstPanelNew = panel_record('CreatePanel')
%                       panel_record('UpdatePanel')
%                       panel_record('CurrentFigureChanged_Callback')
%                       panel_record('CopyRawToDatabase', DataFiles)
%                       panel_record('SetAcquisitionDate', DataFile, strDate)

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
% Authors: Francois Tadel, 2010-2021

eval(macro_method);
end


%% ===== CREATE PANEL =====
function bstPanelNew = CreatePanel() %#ok<DEFNU>
    panelName = 'Record';
    % Java initializations
    import java.awt.*;
    import java.awt.event.*;
    import javax.swing.*;
    import org.brainstorm.icon.*;
    import org.brainstorm.list.*;
    global GlobalData;
    % Create tools panel
    jPanelNew = gui_component('Panel');
    jPanelTop = gui_component('Panel');
    jPanelNew.add(jPanelTop, BorderLayout.NORTH);
    TB_DIM = java_scaled('dimension', 25, 25);
    % Font size for the lists
    fontSize = round(11 * bst_get('InterfaceScaling') / 100);

    % ===== TOOLBAR =====
    jMenuBar = gui_component('MenuBar', jPanelTop, BorderLayout.NORTH);
        jToolbar = gui_component('Toolbar', jMenuBar);
        jToolbar.setPreferredSize(TB_DIM);
        jToolbar.setOpaque(0);
        % BUTTON: TS DISPLAY MODE
        jButtonDispMode = gui_component('ToolbarToggle', jToolbar, [], [], {IconLoader.ICON_TS_DISPLAY_MODE, TB_DIM}, ...
              ['<HTML><B>Display mode for time series</B>:<BR><BR>' ...
               'If selected, the channels are displayed in columns, else they are superimposed<BR>'], ...
              @TSDisplayMode_Callback);
        % Select "COLUMN DISPLAY"
        isColumnDisplay = strcmpi(bst_get('TSDisplayMode'), 'column');
        jButtonDispMode.setSelected(isColumnDisplay);
        
        % BUTTON: UNIFORMIZE SCALES
        if (GlobalData.Program.GuiLevel ~= 2)
            jButtonUniform = gui_component('ToolbarToggle', jToolbar, [], [], {IconLoader.ICON_TS_SYNCRO, TB_DIM}, ...
                  ['<HTML><B>Uniform amplitude scales</B>:<BR><BR>' ...
                   'Uncheck this button if you don''t want to display the time series <BR>' ...
                   'figures with the same y-axis scale.'], ...
                  @UniformTimeSeries_Callback);
            % Select "Uniformize TS button"
            isUniform = bst_get('UniformizeTimeSeriesScales');
            jButtonUniform.setSelected(isUniform);
        else
            jButtonUniform = [];
        end
        
        % MENU: MONTAGE
        jMenuMontage = gui_component('ToolbarButton', jToolbar, [], 'All', IconLoader.ICON_MENU, [], @(h,ev)ShowMontageMenu(ev.getSource()), 11);
        jMenuMontage.setMinimumSize(java_scaled('dimension', 25, 25));
        jMenuMontage.setMaximumSize(java_scaled('dimension', 200, 25));
        jMenuMontage.setMargin(Insets(0,4,0,4));
        % BUTTONS: RAW VIEWER
        jButtonBaseline = gui_component('ToolbarToggle', jToolbar, [], 'DC',  TB_DIM, 'Remove DC offset',      @(h,ev)bst_call(@SetRawViewerOptions, 'RemoveBaseline', ev.getSource().isSelected()), 10);
        jButtonCtf      = gui_component('ToolbarToggle', jToolbar, [], 'CTF', TB_DIM, 'Apply CTF compensation', @(h,ev)bst_call(@SetRawViewerOptions, 'UseCtfComp', ev.getSource().isSelected()), 10);
        jButtonBaseline.setMargin(Insets(0,0,0,0));
        jButtonCtf.setMargin(Insets(0,0,0,0));
        jButtonBaseline.setVisible(0);
        jButtonCtf.setVisible(0);
        % Default options
        RawViewerOptions = bst_get('RawViewerOptions');
        jButtonBaseline.setSelected(strcmpi(RawViewerOptions.RemoveBaseline, 'all'));
        jButtonCtf.setSelected(RawViewerOptions.UseCtfComp);
        % Filler
        jToolbar.add(Box.createHorizontalGlue());
        
    % ===== PANEL: TIME WINDOW =====
    jPanelTime = gui_river([4,5], [2,5,12,0]);
    jBorder = java_scaled('titledborder', 'Page settings');
    jPanelTime.setBorder(BorderFactory.createCompoundBorder(BorderFactory.createEmptyBorder(7,7,0,7), jBorder));
        % Titles
        jLabelEpoch = gui_component('Label',   jPanelTime, '', 'Epoch:');
        gui_component('Label', jPanelTime, 'tab', 'Start:');
        gui_component('Label', jPanelTime, 'tab', 'Duration:');
        % Spinner
        jSpinnerEpoch = gui_component('Spinner', jPanelTime, 'br');
        java_setcb(jSpinnerEpoch, 'StateChangedCallback',  @EpochChanged_Callback);
        % Time start
        jSliderStart = JSlider(0, 100, 0);
        jTextStart = gui_component('texttime', jPanelTime, 'tab', '0');
        java_setcb(jTextStart, 'FocusLostCallback',       @TextValidationStart_Callback, ...
                               'ActionPerformedCallback', @(h,ev)ev.getSource().getParent().grabFocus());
        % Time stop
        jTextLength = gui_component('texttime', jPanelTime, 'tab', '0');
        java_setcb(jTextLength, 'FocusLostCallback',       @TextValidationLength_Callback, ...
                                'ActionPerformedCallback', @(h,ev)ev.getSource().getParent().grabFocus());
        gui_component('Label', jPanelTime, [], 's');

    panelPrefSize = jPanelTime.getPreferredSize();
    jPanelTime.setMaximumSize(Dimension(32000, panelPrefSize.getHeight()));
    jPanelTop.add(jPanelTime, BorderLayout.CENTER);

    % ===== PANEL: EVENTS =====
    jPanelEvent = gui_component('Panel');
    jBorder = java_scaled('titledborder', 'Events');
    jPanelEvent.setBorder(BorderFactory.createCompoundBorder(BorderFactory.createEmptyBorder(0,7,7,7), jBorder));
        % === MENU BAR ===
        jMenuBar = gui_component('MenuBar', jPanelEvent, BorderLayout.NORTH);
        jMenuBar.setPreferredSize(java_scaled('dimension', 20, 20));
        % FILE
        jMenu = gui_component('Menu', jMenuBar, [], 'File', IconLoader.ICON_MENU, [], [], 11);
        if (GlobalData.Program.GuiLevel ~= 2)
            gui_component('MenuItem', jMenu, [], 'Import in database...', IconLoader.ICON_EEG_NEW, [], @(h,ev)bst_call(@ImportInDatabase));
            jMenu.addSeparator();
            gui_component('MenuItem', jMenu, [], 'Save modifications',     IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@SaveModifications));
            jMenu.addSeparator();
        end
        gui_component('MenuItem', jMenu, [], 'Add events from file...',     IconLoader.ICON_EVT_TYPE_ADD, [], @(h,ev)bst_call(@ImportEvents));
        gui_component('MenuItem', jMenu, [], 'Read events from channel...', IconLoader.ICON_EVT_TYPE_ADD, [], @(h,ev)CallProcessOnRaw('process_evt_read'));
        gui_component('MenuItem', jMenu, [], 'Detect analog triggers...',   IconLoader.ICON_EVT_TYPE_ADD, [], @(h,ev)CallProcessOnRaw('process_evt_detect_analog'));
        jMenu.addSeparator();
        gui_component('MenuItem', jMenu, [], 'Export all events',      IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@export_events));
        gui_component('MenuItem', jMenu, [], 'Export selected events', IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@ExportSelectedEvents));

        % EVENT TYPES
        jMenu = gui_component('Menu', jMenuBar, [], 'Events', IconLoader.ICON_MENU, [], [], 11);
        gui_component('MenuItem', jMenu, [], 'Add group',    IconLoader.ICON_EVT_TYPE_ADD, [], @(h,ev)bst_call(@EventTypeAdd));
        gui_component('MenuItem', jMenu, [], 'Delete group', IconLoader.ICON_EVT_TYPE_DEL, [], @(h,ev)bst_call(@EventTypeDel));
        gui_component('MenuItem', jMenu, [], 'Rename group', IconLoader.ICON_EDIT, [], @(h,ev)bst_call(@EventTypeRename));
        gui_component('MenuItem', jMenu, [], 'Set color', IconLoader.ICON_COLOR_SELECTION, [], @(h,ev)bst_call(@EventTypeSetColor));
        jItem = gui_component('MenuItem', jMenu, [], 'Show/hide group', IconLoader.ICON_DISPLAY, [], @(h,ev)CallWithAccelerator(@EventTypeToggleVisible));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_H, 0));
        gui_component('MenuItem', jMenu, [], 'Mark group as bad/good', IconLoader.ICON_GOODBAD, [], @(h,ev)bst_call(@EventTypeToggleBad));
        jMenu.addSeparator();
        jMenuSort = gui_component('Menu', jMenu, [], 'Sort groups', IconLoader.ICON_EVT_TYPE, [], []);
            gui_component('MenuItem', jMenuSort, [], 'By name', IconLoader.ICON_EVT_TYPE, [], @(h,ev)bst_call(@(h,ev)EventTypesSort('name')));
            gui_component('MenuItem', jMenuSort, [], 'By time', IconLoader.ICON_EVT_TYPE, [], @(h,ev)bst_call(@(h,ev)EventTypesSort('time')));
        gui_component('MenuItem', jMenu, [], 'Merge groups', IconLoader.ICON_FUSION, [], @(h,ev)bst_call(@EventTypesMerge));
        gui_component('MenuItem', jMenu, [], 'Duplicate groups', IconLoader.ICON_COPY, [], @(h,ev)bst_call(@EventTypesDuplicate));
        gui_component('MenuItem', jMenu, [], 'Convert to simple event', [], [], @(h,ev)bst_call(@EventConvertToSimple));
        gui_component('MenuItem', jMenu, [], 'Convert to extended event', [], [], @(h,ev)bst_call(@EventConvertToExtended));
        jMenu.addSeparator();
        gui_component('MenuItem', jMenu, [], 'Combine stim/response', IconLoader.ICON_FUSION, [], @(h,ev)CallProcessOnRaw('process_evt_combine'));
        gui_component('MenuItem', jMenu, [], 'Detect multiple responses', IconLoader.ICON_FUSION, [], @(h,ev)CallProcessOnRaw('process_evt_multiresp'));
        gui_component('MenuItem', jMenu, [], 'Group by name', IconLoader.ICON_FUSION, [], @(h,ev)CallProcessOnRaw('process_evt_groupname'));
        gui_component('MenuItem', jMenu, [], 'Group by time', IconLoader.ICON_FUSION, [], @(h,ev)CallProcessOnRaw('process_evt_grouptime'));
        gui_component('MenuItem', jMenu, [], 'Add time offset', IconLoader.ICON_ARROW_RIGHT, [], @(h,ev)CallProcessOnRaw('process_evt_timeoffset'));
        jMenu.addSeparator();
        gui_component('MenuItem', jMenu, [], 'Edit keyboard shortcuts', IconLoader.ICON_KEYBOARD, [], @(h,ev)gui_show('panel_raw_shortcuts', 'JavaWindow', 'Event keyboard shortcuts', [], 1, 0, 0));
        jMenu.addSeparator();
        jItem = gui_component('MenuItem', jMenu, [], 'Add / delete event', IconLoader.ICON_EVT_OCCUR_ADD, [], @(h,ev)CallWithAccelerator(@ToggleEvent));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_E, 0));
        jItem = gui_component('MenuItem', jMenu, [], '<HTML>Edit notes&nbsp;&nbsp;&nbsp;<FONT color="#A0A0A"><I>Double-click</I></FONT>', IconLoader.ICON_EDIT, [], @(h,ev)bst_call(@EventEditNotes));
        jItem = gui_component('MenuItem', jMenu, [], 'Reject time segment', IconLoader.ICON_BAD, [], @(h,ev)CallWithAccelerator(@RejectTimeSegment));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_B, 0));
        jMenu.addSeparator();
        jItem = gui_component('MenuItem', jMenu, [], 'Jump to previous event', IconLoader.ICON_ARROW_LEFT, [], @(h,ev)CallWithAccelerator(@JumpToEvent, 'leftarrow'));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_LEFT, KeyEvent.SHIFT_MASK));
        jItem = gui_component('MenuItem', jMenu, [], 'Jump to next event', IconLoader.ICON_ARROW_RIGHT, [], @(h,ev)CallWithAccelerator(@JumpToEvent, 'rightarrow'));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_RIGHT, KeyEvent.SHIFT_MASK));
        % Artifacts
        jMenu = gui_component('Menu', jMenuBar, [], 'Artifacts', IconLoader.ICON_MENU, [], [], 11);
        jItemEegref  = gui_component('MenuItem', jMenu, [], 'Re-reference EEG', IconLoader.ICON_EMPTY, [], @(h,ev)CallProcessOnRaw('process_eegref'));
        jMenu.addSeparator();
        gui_component('MenuItem', jMenu, [], 'Detect heartbeats',      IconLoader.ICON_EMPTY, [], @(h,ev)CallProcessOnRaw('process_evt_detect_ecg'));
        gui_component('MenuItem', jMenu, [], 'Detect eye blinks',      IconLoader.ICON_EMPTY, [], @(h,ev)CallProcessOnRaw('process_evt_detect_eog'));
        gui_component('MenuItem', jMenu, [], 'Detect custom events',   IconLoader.ICON_EMPTY, [], @(h,ev)CallProcessOnRaw('process_evt_detect'));
        gui_component('MenuItem', jMenu, [], 'Detect other artifacts', IconLoader.ICON_EMPTY, [], @(h,ev)CallProcessOnRaw('process_evt_detect_badsegment'));
        jMenu.addSeparator();
        gui_component('MenuItem', jMenu, [], 'Remove simultaneous', IconLoader.ICON_EMPTY, [], @(h,ev)CallProcessOnRaw('process_evt_remove_simult'));
        jMenu.addSeparator();
        jItemSspEcg  = gui_component('MenuItem', jMenu, [], 'SSP: Heartbeats', IconLoader.ICON_EMPTY, [], @(h,ev)CallProcessOnRaw('process_ssp_ecg'));
        jItemSspEog  = gui_component('MenuItem', jMenu, [], 'SSP: Eye blinks', IconLoader.ICON_EMPTY, [], @(h,ev)CallProcessOnRaw('process_ssp_eog'));
        jItemSsp     = gui_component('MenuItem', jMenu, [], 'SSP: Generic',    IconLoader.ICON_EMPTY, [], @(h,ev)CallProcessOnRaw('process_ssp'));
        jItemIca     = gui_component('MenuItem', jMenu, [], 'ICA components',  IconLoader.ICON_EMPTY, [], @(h,ev)CallProcessOnRaw('process_ica'));
        jMenu.addSeparator();
        jItemSspSel  = gui_component('MenuItem', jMenu, [], 'Select active projectors', IconLoader.ICON_EMPTY, [], @(h,ev)panel_ssp_selection('OpenRaw'));
        jItemSspMontage  = gui_component('MenuItem', jMenu, [], 'Load projectors as montages', IconLoader.ICON_EMPTY, [], @(h,ev)panel_montage('AddAutoMontagesProj', [], 1));
        
        % === EVENTS TYPES ===
        jListEvtType = JList();
        jListEvtType.setCellRenderer(BstColorListRenderer(fontSize));

        java_setcb(jListEvtType, 'ValueChangedCallback', @ListType_ValueChangedCallback, ...
                                 'KeyPressedCallback',   @ListType_KeyPressedCallback, ...
                                 'MouseClickedCallback', @ListType_ClickCallback);
        jPanelScrollList = JScrollPane();
        jPanelScrollList.getLayout.getViewport.setView(jListEvtType);
        jPanelScrollList.setHorizontalScrollBarPolicy(jPanelScrollList.HORIZONTAL_SCROLLBAR_NEVER);
        jPanelScrollList.setBorder([]);
        
        % === EVENTS OCCURRENCES ===
        jListEvtOccur = JList();
        jListEvtOccur.setCellRenderer(BstStringListRenderer(fontSize));
        java_setcb(jListEvtOccur, 'KeyTypedCallback',     @ListOccur_KeyTypedCallback, ...
                                  'KeyPressedCallback',   @ListChangeTime_Callback, ...
                                  'MouseClickedCallback', @ListOccur_ClickCallback);
        jPanelScrollEvt = JScrollPane();
        jPanelScrollEvt.getLayout.getViewport.setView(jListEvtOccur);
        jPanelScrollEvt.setHorizontalScrollBarPolicy(jPanelScrollEvt.HORIZONTAL_SCROLLBAR_NEVER);
        jPanelScrollEvt.setBorder([]);

    jSplitEvt = JSplitPane(JSplitPane.HORIZONTAL_SPLIT, jPanelScrollList, jPanelScrollEvt);
    jSplitEvt.setResizeWeight(0.6);
    jSplitEvt.setDividerSize(4);
    jSplitEvt.setBorder([]);
    jPanelEvent.add(jSplitEvt, BorderLayout.CENTER);
    jPanelNew.add(jPanelEvent, BorderLayout.CENTER);
    
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jMenuBar',        jMenuBar, ...
                                  'jToolbar',        jToolbar, ...
                                  'jMenuMontage',    jMenuMontage, ...
                                  'jButtonDispMode', jButtonDispMode, ...
                                  'jButtonUniform',  jButtonUniform, ...
                                  'jButtonBaseline', jButtonBaseline, ...
                                  'jButtonCtf',      jButtonCtf, ...
                                  'jItemEegref',     jItemEegref, ...
                                  'jItemSspEog',     jItemSspEog, ...
                                  'jItemSspEcg',     jItemSspEcg, ...
                                  'jItemSsp',        jItemSsp, ...
                                  'jItemIca',        jItemIca, ...
                                  'jItemSspSel',     jItemSspSel, ...
                                  'jItemSspMontage', jItemSspMontage, ...
                                  'jPanelTime',      jPanelTime, ...
                                  'jPanelEvent',     jPanelEvent, ...
                                  'jLabelEpoch',     jLabelEpoch, ...
                                  'jSpinnerEpoch',   jSpinnerEpoch, ...
                                  'jSliderStart',    jSliderStart, ...
                                  'jTextStart',      jTextStart, ...
                                  'jTextLength',     jTextLength, ...
                                  'jListEvtType',    jListEvtType, ...
                                  'jListEvtOccur',   jListEvtOccur));
                              
    
%% ===== INTERNAL CALLBACKS =====
    %% ===== START: TEXT VALIDATION =====
    function TextValidationStart_Callback(h, event)
        % Get and check value
        value = str2double(char(jTextStart.getText()));
        if isnan(value) || isempty(value)
            ValidateTimeWindow();
            return
        end
        % Set focus to panel container panel
        event.getSource().getParent().grabFocus();
        % Switch between sliders
        iEpoch = GlobalData.FullTimeWindow.CurrentEpoch;
        if ~isempty(iEpoch)
            iStartNew = bst_closest(value, GlobalData.FullTimeWindow.Epochs(iEpoch).Time);
            jSliderStart.setValue(iStartNew);
            ValidateTimeWindow();
        end
    end


    %% ===== DURATION: TEXT VALIDATION =====
    function TextValidationLength_Callback(h, event)
        % Skip if unloading
        if isempty(GlobalData.FullTimeWindow.Epochs)
            return
        end
        % Get and check value
        value = str2double(char(jTextLength.getText()));
        if isnan(value) || isempty(value)
            ValidateTimeWindow();
            return
        end
        % Set focus to panel container panel
        %event.getSource().getParent().grabFocus();
        % Switch between sliders
        iEpoch = GlobalData.FullTimeWindow.CurrentEpoch;
        % Round length with the sampling frequency
        sfreq = diff(GlobalData.FullTimeWindow.Epochs(iEpoch).Time([1 2]));
        value = max(round(value / sfreq), 20) * sfreq;
        % Set the updated time
        jTextLength.setText(sprintf('%1.4f', value));
        % Validate changes
        ValidateTimeWindow();
    end

    %% ===== EPOCHED CHANGED =====
    function EpochChanged_Callback(h,ev)
        % Update time window
        UpdateTime();
        % Replot raw time bars
        figure_timeseries('ReloadRawTimeBars');
    end

    %% ===== LIST TYPE: SELECTION CHANGED CALLBACK =====
    function ListType_ValueChangedCallback(h, ev)
        if ~ev.getValueIsAdjusting()
            % Update events occurrences
            UpdateEventsOccur();
        end
    end

    %% ===== LIST TYPE: KEY TYPED CALLBACK =====
    function ListType_KeyPressedCallback(h, ev)
        switch (ev.getKeyCode())
            case {ev.VK_DELETE, ev.VK_BACK_SPACE}
                EventTypeDel();
%             case ev.VK_H
%                 EventTypeToggleVisible();
            case {ev.VK_LEFT, ev.VK_PAGE_DOWN}
                JumpToEvent('leftarrow');
            case {ev.VK_RIGHT, ev.VK_PAGE_UP}
                JumpToEvent('rightarrow');
        end
    end

    %% ===== LIST TYPE: CLICK CALLBACK =====
    function ListType_ClickCallback(h, ev)
        % If DOUBLE CLICK
        if (ev.getClickCount() == 2)
            % Rename selection
            EventTypeRename();
        end
    end

    %% ===== LIST OCCUR: KEY TYPED CALLBACK =====
    function ListOccur_KeyTypedCallback(h, ev)
        switch(uint8(ev.getKeyChar()))
            % DELETE
            case {ev.VK_DELETE, ev.VK_BACK_SPACE}
                EventOccurDel();
        end
    end

    function ListChangeTime_Callback(h, ev)
        switch (ev.getKeyCode())
            case {ev.VK_LEFT, ev.VK_PAGE_DOWN, ev.VK_UP}
                JumpToEvent('leftarrow');
            case {ev.VK_RIGHT, ev.VK_PAGE_UP, ev.VK_DOWN}
                JumpToEvent('rightarrow');
        end
    end

    %% ===== LIST OCCUR: CLICK CALLBACK =====
    function ListOccur_ClickCallback(h, ev)
        if ev.getSource().isEnabled()
            % Double-click: edit notes
            if (ev.getClickCount() == 2)
                EventEditNotes();
            % Single clikc: Jump to the selected event
            else
                JumpToEvent();
            end
        end
    end

    %% ===== CALL WITH ACCELERATORS =====
    function CallWithAccelerator(varargin)
        % Make sure tree items are not being renamed
        ctrl = bst_get('PanelControls', 'protocols');
        if isempty(ctrl) || isempty(ctrl.jTreeProtocols) || ctrl.jTreeProtocols.isEditing()
            return;
        end
        % Make sure the item search box is not active
        ctrl = bst_get('BstControls');
        if isempty(ctrl) || isempty(ctrl.jTextFilter) || ctrl.jTextFilter.hasFocus()
            disp('cancel')
            return;
        end
        % Transfer call to bst_call
        bst_call(varargin{:});
    end
end


%% =================================================================================
%  === CONTROLS CALLBACKS  =========================================================
%  =================================================================================
%% ===== OPTIONS: TIME SERIES DISPLAY MODE =====
function TSDisplayMode_Callback(hObject, ev)
    % Save preference
    isSel = ev.getSource.isSelected();
    if isSel 
        newMode = 'column';
    else
        newMode = 'butterfly';
    end
    % Get current figure
    hFig = bst_figures('GetCurrentFigure', '2D');
    if isempty(hFig)
        return;
    end
    % Set display mode
    SetDisplayMode(hFig, newMode);
end


%% ===== SET DISPLAY MODE =====
function SetDisplayMode(hFig, newMode)
    % Display progress bar
    bst_progress('start', 'Time series display mode', 'Reloading recordings...');
    % Update figure structure
    TsInfo = getappdata(hFig, 'TsInfo');
    TsInfo.DisplayMode = newMode;
    setappdata(hFig, 'TsInfo', TsInfo);
    % Re-plot figure
    bst_figures('ReloadFigures', hFig, 0);
    % Keep default mode for future use
    bst_set('TSDisplayMode', newMode);
    % Hide progress bar
    bst_progress('stop');
end


%% ===== OPTIONS: UNIFORMIZE SCALES =====
function UniformTimeSeries_Callback(hObject, ev)
    % Get button
    jButton = ev.getSource();
    isSel = jButton.isSelected();
    % Apply selection
    bst_set('UniformizeTimeSeriesScales', isSel);
    figure_timeseries('UniformizeTimeSeriesScales', isSel);
    % Force update of the "Record" panel button
    ctrl = bst_get('PanelControls', 'Record');
    if isempty(ctrl)
        return;
    end
    if ~isempty(ctrl.jButtonUniform) && (jButton ~= ctrl.jButtonUniform)
        ctrl.jButtonUniform.setSelected(isSel);
    end
end

%% ===== CREATE MONTAGE MENU =====
function ShowMontageMenu(jButton)
    % Get the current figure
    hFig = bst_figures('GetCurrentFigure', '2D');
    if isempty(hFig)
        return;
    end
    % Create popup
    jPopup = java_create('javax.swing.JPopupMenu');
    % Create menu
    panel_montage('CreateFigurePopupMenu', jPopup, hFig);
    % Show popup
    gui_brainstorm('ShowPopup', jPopup, jButton, 0);
end


%% ===== SLIDER: MOUSE CALLBACK =====
function UpdateTime(varargin)
    % Set a mutex to prevent to enter twice at the same time in the routine
    global RawTimeSliderMutex;
    if (isempty(RawTimeSliderMutex))
        tic
        % Set mutex
        RawTimeSliderMutex = 1;
        % Validate time window
        ValidateTimeWindow();
        % Release mutex
        RawTimeSliderMutex = [];
    else
        % Release mutex if last keypress was processed more than one 2s ago (restore keyboard after a bug...)
        t = toc;
        if (t > 2)
            RawTimeSliderMutex = [];
        end
    end
end


%% ===== SLIDER: KEYBOARD CALLBACK =====
function RawKeyCallback(keyEvent) %#ok<DEFNU>
    global GlobalData;
    if isempty(GlobalData.UserTimeWindow.Time) || isempty(GlobalData.FullTimeWindow.CurrentEpoch)
        return;
    end
    % Set a mutex to prevent to enter twice at the same time in the routine
    global RawTimeSliderMutex;
    if (isempty(RawTimeSliderMutex))
        % Set mutex
        RawTimeSliderMutex = tic;
        % Get panel controls
        ctrl = bst_get('PanelControls', 'Record');
        if isempty(ctrl)
            return;
        end
        % Get current time window
        iEpoch = GlobalData.FullTimeWindow.CurrentEpoch;
        iStart = ctrl.jSliderStart.getValue();
        smpLength = GlobalData.UserTimeWindow.NumberOfSamples;
        % Initializations
        iEpochNew = iEpoch;
        iStartNew = iStart;
        % Switch between different keys and sliders
        switch (keyEvent.Key)
            case {'leftarrow',  'downarrow', 'epoch-'},  iStartNew = iStart - round(.9 .* smpLength);  
            case {'rightarrow', 'uparrow',   'epoch+'},  iStartNew = iStart + round(.9 .* smpLength);     
            case {'pageup',     'epoch++'}, iStartNew = iStart + 10 * smpLength;
            case {'pagedown',   'epoch--'}, iStartNew = iStart - 10 * smpLength;
            case 'halfpage-',   iStartNew = iStart - round(.5 .* smpLength);
            case 'halfpage+',   iStartNew = iStart + round(.5 .* smpLength);
            case 'nooverlap-',  iStartNew = iStart - smpLength;
            case 'nooverlap+',  iStartNew = iStart + smpLength;
        end
        iEpoch = GlobalData.FullTimeWindow.CurrentEpoch;
        iStartNew = bst_saturate(iStartNew, [1, length(GlobalData.FullTimeWindow.Epochs(iEpoch).Time)]);
        % Update time window
        if (iEpochNew ~= iEpoch)
            ctrl.jSpinnerEpoch.setValue(iEpochNew);
            ValidateTimeWindow(0);
        elseif (iStartNew ~= iStart)
            ctrl.jSliderStart.setValue(iStartNew);
            ValidateTimeWindow(0);
        end
        drawnow;
        % Release mutex
        RawTimeSliderMutex = [];
    else
        % Release mutex if last keypress was processed more than one 2s ago
        % (restore keyboard after a bug...)
        t = toc(RawTimeSliderMutex);
        if (t > 2)
            RawTimeSliderMutex = [];
        end
    end
end


%% ===== SET START TIME =====
function SetStartTime(startTime, iEpochNew, isValidate)
    global GlobalData;
    if (nargin < 3) || isempty(isValidate)
        isValidate = 1;
    end
    if (nargin < 2) || isempty(iEpochNew)
        iEpochNew = GlobalData.FullTimeWindow.CurrentEpoch;
    end
    if isempty(GlobalData.UserTimeWindow.Time) || isempty(GlobalData.FullTimeWindow.CurrentEpoch)
        return;
    end
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Record');
    if isempty(ctrl)
        return;
    end
    % Find new start index
    iEpoch = GlobalData.FullTimeWindow.CurrentEpoch;
    iStartNew = bst_closest(startTime, GlobalData.FullTimeWindow.Epochs(iEpoch).Time);
    % Update start time
    if (iStartNew ~= double(ctrl.jSliderStart.getValue())) || (iEpochNew ~= iEpoch)
        ctrl.jSliderStart.setValue(iStartNew);
        ctrl.jSpinnerEpoch.setValue(iEpoch);
        if isValidate
            ValidateTimeWindow();
        end
    end
end


%% ===== SET TIME LENGTH =====
function SetTimeLength(timeLength, isValidate) %#ok<DEFNU>
    if (nargin < 2) || isempty(isValidate)
        isValidate = 1;
    end
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Record');
    if isempty(ctrl)
        return;
    end
    % Update control
    ctrl.jTextLength.setText(sprintf('%1.4f', timeLength));
    % Validate modification
    if isValidate
        ValidateTimeWindow();
    end
end


%% ===== VALIDATE TIME WINDOW =====
function ValidateTimeWindow(isProgress)
    global GlobalData;
    % Parse inputs
    if (nargin < 1) || isempty(isProgress)
        isProgress = 1;
    end
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Record');
    if isempty(ctrl)
        return;
    end
    % Get epoch time definition
    iEpoch = ctrl.jSpinnerEpoch.getValue();
    Time = GlobalData.FullTimeWindow.Epochs(iEpoch).Time;
    % Get current time window
    iStart     = ctrl.jSliderStart.getValue();
    timeLength = str2double(char(ctrl.jTextLength.getText()));
    % Convert time to number of samples
    sfreq = 1 / (Time(2) - Time(1));
    smpLength = round(timeLength * sfreq);
    % Update start text field
    if (iStart <= length(Time))
        ctrl.jTextStart.setText(sprintf('%1.4f', Time(iStart)));
    end
    % Save length in user preferences
    RawViewerOptions = bst_get('RawViewerOptions');
    RawViewerOptions.PageDuration = smpLength / sfreq;
    bst_set('RawViewerOptions', RawViewerOptions);
    % Progress bar
    if isProgress
        bst_progress('start', 'Update display', 'Loading recordings...');
    end
    % Reload recordings
    ReloadRecordings();
    % Close progress bar
    if isProgress
        bst_progress('stop');
    end
end


%% ===== SET RAW VIEWER OPTIONS
function SetRawViewerOptions(propName, propVal)
    % Get current options
    RawViewerOptions = bst_get('RawViewerOptions');
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Record');
    if isempty(ctrl)
        return;
    end
    % Set the new property value
    switch (propName)
        case 'RemoveBaseline'
            if propVal
                RawViewerOptions.RemoveBaseline = 'all';
            else
                RawViewerOptions.RemoveBaseline = 'no';
            end
            isReload = 1;
        case 'UseCtfComp'
            RawViewerOptions.UseCtfComp = propVal;
            isReload = 1;
    end
    % Save properties
    bst_set('RawViewerOptions', RawViewerOptions);
    % Update display
    if isReload
        ReloadRecordings(1);
    end
end


%% ===== UDPATE DISPLAY OPTIONS =====
function UpdateDisplayOptions(hFig)
    % Parse inputs
    if (nargin < 1) || isempty(hFig)
        hFig = [];
    end
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Record'); 
    if isempty(ctrl)
        return;
    end
    % Get current figure
    if isempty(hFig)
        hFig = bst_figures('GetCurrentFigure', '2D');
    end
    if isempty(hFig)
        return;
    end
    % Get figure configuration
    TsInfo = getappdata(hFig, 'TsInfo');
    % Set recordings controls
    if isempty(TsInfo)
        ctrl.jButtonDispMode.setEnabled(0);
        ctrl.jMenuMontage.setEnabled(0);
        return;
    end
    isTopo = strcmpi(TsInfo.DisplayMode, 'topography') || strcmpi(TsInfo.DisplayMode, 'image');
    isNoModality = isempty(TsInfo.Modality);
    ctrl.jButtonDispMode.setEnabled(~isTopo);
    if ~isempty(ctrl.jButtonUniform)
        ctrl.jButtonUniform.setEnabled(~isTopo);
    end
    ctrl.jMenuMontage.setEnabled(~isNoModality);
    % Update montage name
    if ismember(TsInfo.Modality, {'results', 'sloreta', 'timefreq', 'stat', 'none'}) || ~isempty(TsInfo.RowNames)
        ctrl.jMenuMontage.setVisible(0);
    else
        ctrl.jMenuMontage.setVisible(1);
        % All the sensors
        if isempty(TsInfo.MontageName)
            DispName = 'All';
        % Average reference
        elseif strcmpi(TsInfo.MontageName, 'Average reference')
            DispName = 'Avg Ref';
        elseif strcmpi(TsInfo.MontageName, 'Average reference (L -> R)')
            DispName = 'Avg Ref LR';
        % Scalp current density
        elseif strcmpi(TsInfo.MontageName, 'Scalp current density')
            DispName = 'SCD';
        elseif strcmpi(TsInfo.MontageName, 'Scalp current density (L -> R)')
            DispName = 'SCD LR';
        % Head distance
        elseif strcmpi(TsInfo.MontageName, 'Head distance')
            DispName = 'Head';
        % Regular montages
        else
            DispName = TsInfo.MontageName;
            % Local average ref: simplify name
            DispName = strrep(DispName, '(local average ref)', '(local avg)');
            % Remove subject name
            iColon = strfind(DispName, ': ');
            if ~isempty(iColon) && (iColon + 2 < length(DispName))
                DispName = DispName(iColon(1)+2:end);
            end
            % Temporary montages:  Remove the [tmp] tag or display
            if ~isempty(strfind(TsInfo.MontageName, '[tmp]'))
                DispName = ['<HTML><I>' strrep(DispName, '[tmp]', '') '</I>'];
            end
        end
        % Set label of the drop-down menu
        ctrl.jMenuMontage.setText(DispName);
    end
    % Update display mode
    isColumn = strcmpi(TsInfo.DisplayMode, 'column');
    ctrl.jButtonDispMode.setSelected(isColumn);
end


%% =================================================================================
%  === EXTERNAL PANEL CALLBACKS  ===================================================
%  =================================================================================
%% ===== CLOSING CALLBACK =====
function isValidated = PanelHidingCallback(varargin) %#ok<DEFNU>
    isValidated = 1;
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Record');
    if isempty(ctrl)
        return;
    end
    % Remove callbacks
    java_setcb(ctrl.jListEvtType,  'ValueChangedCallback',  [], 'KeyTypedCallback',   [], 'MouseClickedCallback', []);
    java_setcb(ctrl.jListEvtOccur, 'ValueChangedCallback',  [], 'KeyTypedCallback',   [], 'MouseClickedCallback', []);
    java_setcb(ctrl.jSpinnerEpoch, 'StateChangedCallback', []);
    java_setcb(ctrl.jSliderStart,  'MouseReleasedCallback', [], 'KeyPressedCallback', [], 'StateChangedCallback', []);       
    java_setcb(ctrl.jTextStart,    'FocusLostCallback',    [], 'ActionPerformedCallback', []);
    java_setcb(ctrl.jTextLength,   'FocusLostCallback',    [], 'ActionPerformedCallback', []);
end


%% ===== FIGURE CHANGED CALLBACK =====
function CurrentFigureChanged_Callback(hFig) %#ok<DEFNU>
    UpdatePanel(hFig);
end


%% ===== GET CURRENT DS =====
function [iDS, isRaw, iFig] = GetCurrentDataset(hFig)
    global GlobalData;
    iDS = [];
    iFig = [];
    isRaw = 0;
    % Parse inputs
    if (nargin < 1) || isempty(hFig)
        hFig = [];
    end
    % Nothing loaded
    if isempty(GlobalData.DataSet)
        return;
    end
    % If figure input is provided: use this information
    if ~isempty(hFig)
        [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
        if ~isempty(iDS)
            isRaw = strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'raw');
            return;
        end
    end
    % Try to get a RAW dataset
    iDS = bst_memory('GetRawDataSet');
    if ~isempty(iDS)
        isRaw = 1;
        return;
    end
    % Get current TS figure
    [hFig,iFig,iDS] = bst_figures('GetCurrentFigure', '2D');
    if ~isempty(iDS)
        return;
    end 
    % Else: return the first dataset with recordings available
    for i = 1:length(GlobalData.DataSet)
        if ~isempty(GlobalData.DataSet(i).Measures)
            iDS = i;
        end
    end
end


%% ===== INITIALIZE PANEL =====
function InitializePanel() %#ok<DEFNU>
    global GlobalData;
    % Initialize full time windows
    for iDS = 1:length(GlobalData.DataSet)
        sFile = GlobalData.DataSet(iDS).Measures.sFile;
        if strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'raw') && ~isempty(sFile)
            % Intialize FullTimeWindow structure
            GlobalData.FullTimeWindow.CurrentEpoch = 1;
            % Epochs in the file
            if ~isempty(sFile.epochs)
                for iEpoch = 1:length(sFile.epochs)
                    % Compute full time vector
                    Samples = round([sFile.epochs(iEpoch).times(1), sFile.epochs(iEpoch).times(2)] .* sFile.prop.sfreq);
                    % Save this values
                    GlobalData.FullTimeWindow.Epochs(iEpoch).Time            = (Samples(1):Samples(2)) ./ sFile.prop.sfreq;
                    GlobalData.FullTimeWindow.Epochs(iEpoch).NumberOfSamples = Samples(2) - Samples(1) + 1;
                end
            else
                % Compute full time vector
                Samples = round([sFile.prop.times(1), sFile.prop.times(2)] .* sFile.prop.sfreq);
                % Save this values
                GlobalData.FullTimeWindow.Epochs(1).Time            = (Samples(1):Samples(2)) ./ sFile.prop.sfreq;
                GlobalData.FullTimeWindow.Epochs(1).NumberOfSamples = Samples(2) - Samples(1) + 1;
            end
            break;
        end
    end
end


%% ===== UPDATE CALLBACK =====
function UpdatePanel(hFig)
    global GlobalData;
    % Parse inputs
    if (nargin < 1) || isempty(hFig)
        hFig = [];
    end
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Record'); 
    if isempty(ctrl)
        return;
    end
    % If the current figure was passed in input
    if ~isempty(hFig)
        % Get current dataset
        [iDS, isRaw, iFig] = GetCurrentDataset(hFig);
    % If no figure was specified: try to look for one
    else
        % Get the current 2D figure
        [hFig,iFig,iDS] = bst_figures('GetCurrentFigure', '2D');
        % Else: Get the current figure (any type)
        if isempty(hFig)
            [hFig,iFig,iDS] = bst_figures('GetCurrentFigure');
        end
        % Else: Get raw dataset
        if isempty(hFig)
            [iDS, isRaw] = GetCurrentDataset();
            % Pick the first figure in this dataset
            if ~isempty(iDS) && ~isempty(GlobalData.DataSet(iDS).Figure)
                hFig = GlobalData.DataSet(iDS).Figure(1).hFigure;
                iFig = 1;
            else
                hFig = [];
                iFig = [];
            end
        else
            isRaw = isequal(GlobalData.DataSet(iDS).Measures.DataType, 'raw');
        end
    end
    % No raw time or no events structure: exit
    if isempty(iDS)
        gui_enable([ctrl.jPanelTime, ctrl.jPanelEvent, ctrl.jListEvtType, ctrl.jListEvtOccur, ctrl.jToolbar, ctrl.jMenuBar, ctrl.jMenuMontage], 0, 1);
        return
    end
    % Are we looking at recordings?
    isData = 0;
    if ~isempty(iFig)
        switch (GlobalData.DataSet(iDS).Figure(iFig).Id.Type)
            case 'DataTimeSeries'
                isData = 1;
            case 'ResultsTimeSeries'
                TsInfo = getappdata(hFig, 'TsInfo');
                if isfield(TsInfo, 'FileName') && ~isempty(TsInfo.FileName) && ~isempty(TsInfo.FileName) && strcmpi(file_gettype(TsInfo.FileName), 'matrix')
                    isData = 1;
                end
            case 'Topography'
                TsInfo = getappdata(hFig, 'TsInfo');
                if isfield(TsInfo, 'FileName') && ~isempty(TsInfo.FileName) && strcmpi(file_gettype(TsInfo.FileName), 'data')
                    isData = 1;
                end
            case 'Image'
                TsInfo = getappdata(hFig, 'TsInfo');
                if isfield(TsInfo, 'FileName') && ~isempty(TsInfo.FileName) && strcmpi(file_gettype(TsInfo.FileName), 'data')
                    isData = 1;
                end
        end
    end
    % Enable/disable the entire time panel
    gui_enable(ctrl.jPanelTime, isRaw, 1);
    gui_enable([ctrl.jPanelEvent, ctrl.jListEvtType, ctrl.jListEvtOccur, ctrl.jToolbar, ctrl.jMenuBar, ctrl.jMenuMontage], isData, 1);

    % ===== RAW RECORDINGS =====
    if isRaw
        % Get current start point and length
        iEpoch = GlobalData.FullTimeWindow.CurrentEpoch;
        FullTime = GlobalData.FullTimeWindow.Epochs(iEpoch).Time;
        iStart = bst_closest(GlobalData.UserTimeWindow.Time(1), FullTime);

        % === SET TIME SLIDERS ===
        smpLength = GlobalData.UserTimeWindow.NumberOfSamples;
        % Epoch: slider
        ctrl.jSpinnerEpoch.setModel(javax.swing.SpinnerNumberModel(...
                iEpoch, ...                                    % Value
                1, ...                                         % Minimum
                length(GlobalData.FullTimeWindow.Epochs), ...  % Maximum
                1));                                           % Step
        % Disable if there are no epochs
        isEpoch = (length(GlobalData.FullTimeWindow.Epochs) > 1);
        ctrl.jSpinnerEpoch.setEnabled(isEpoch);
        ctrl.jLabelEpoch.setEnabled(isEpoch);
        % Set callbacks
        SetSpinnerCallbacks(ctrl.jSpinnerEpoch);

        % Start: slider
        ctrl.jSliderStart.setMinimum(1);
        ctrl.jSliderStart.setMaximum(length(FullTime));
        ctrl.jSliderStart.setValue(iStart);
        ctrl.jSliderStart.setMinorTickSpacing(round(.8 * smpLength));
        ctrl.jSliderStart.setMajorTickSpacing(round(10 * smpLength));
        % Start: text
        ctrl.jTextStart.setText(sprintf('%1.4f', GlobalData.FullTimeWindow.Epochs(iEpoch).Time(iStart)));
        % Length: text
        sfreq = 1 / (FullTime(2) - FullTime(1));
        ctrl.jTextLength.setText(sprintf('%1.4f', smpLength / sfreq));

        % === ENABLE/DISABLE MENUS ===
        % Get file descriptor
        sFile = GlobalData.DataSet(iDS).Measures.sFile;
        MegRefCoef = GlobalData.DataSet(iDS).MegRefCoef;
        % CTF Compensations
        isCtfCompCheck = ~isempty(MegRefCoef) && ~isempty(sFile.prop.currCtfComp) && (sFile.prop.currCtfComp == 0);
        ctrl.jButtonCtf.setVisible(isCtfCompCheck);
    else
        ctrl.jButtonCtf.setVisible(0);
    end
    % Check if data is EEG
    isEeg = ~isempty(iFig) && ~isempty(GlobalData.DataSet(iDS).Figure(iFig).Id.Modality) && ismember(GlobalData.DataSet(iDS).Figure(iFig).Id.Modality, {'EEG','SEEG','ECOG','ECOG+SEEG'});
    % Show/Hide the entire "Display" menu
    ctrl.jButtonBaseline.setVisible(isRaw);
    % Enable/disable Artifacts menus
    gui_enable([ctrl.jItemSspEog, ctrl.jItemSspEcg, ctrl.jItemSsp, ctrl.jItemIca, ctrl.jItemSspSel], isRaw);
    % gui_enable(ctrl.jItemSspMontage, ~isRaw);
    gui_enable(ctrl.jItemEegref, isRaw && isEeg);
    % Update display options
    UpdateDisplayOptions(hFig);
    % Update events list
    UpdateEventsList();
    UpdateEventsOccur();
end


%% ===== SET SPINNER CALLBACKS =====
function SetSpinnerCallbacks(jSpinner)
    % Get the subcontainers
    compList = [jSpinner.getComponents(), jSpinner.getEditor().getComponents()] ;
    for i = 1:length(compList)
        switch (class(compList(i)))
            case 'javax.swing.plaf.basic.BasicArrowButton'
                if (compList(i).getDirection() == compList(i).TOP)
                    java_setcb(compList(i), 'MouseReleasedCallback', @(h,ev)SpinnerButtonUp());
                else
                    java_setcb(compList(i), 'MouseReleasedCallback', @(h,ev)SpinnerButtonDown());
                end
            case 'javax.swing.JFormattedTextField'
                java_setcb(compList(i), 'KeyReleasedCallback', @(h,ev)TextKeyReleased(jSpinner, ev));
        end
    end
end

%% ===== SPINNER BUTTON UP =====
function SpinnerButtonUp()
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Record');
    if isempty(ctrl)
        return;
    end
    % Update spinner value
    val = double(ctrl.jSpinnerEpoch.getValue());
    valMax = double(ctrl.jSpinnerEpoch.getModel().getMaximum());
    step = double(ctrl.jSpinnerEpoch.getModel().getStepSize());
    if (val + step > valMax)
        ctrl.jSpinnerEpoch.setValue(valMax);
    elseif ~isempty(ctrl)
        ctrl.jSpinnerEpoch.setValue(val + step);
    end
    % Call update callback
    UpdateTime();
end

%% ===== SPINNER BUTTON DOWN =====
function SpinnerButtonDown()
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Record');
    if isempty(ctrl)
        return;
    end
    % Update spinner value
    val = double(ctrl.jSpinnerEpoch.getValue());
    valMin = double(ctrl.jSpinnerEpoch.getModel().getMinimum());
    step = double(ctrl.jSpinnerEpoch.getModel().getStepSize());
    if (val - step < valMin)
        ctrl.jSpinnerEpoch.setValue(valMin);
    elseif ~isempty(ctrl)
        ctrl.jSpinnerEpoch.setValue(val - step);
    end
    % Call update callback
    UpdateTime();
end

%% ===== TEXT VALIDATION ======
function TextKeyReleased(jSpinner,ev)
    % Switch between different keys
    switch (ev.getKeyCode())
        case {ev.VK_LEFT, ev.VK_DOWN, ev.VK_PAGE_DOWN}
            %SpinnerButtonDown();
        case {ev.VK_RIGHT, ev.VK_UP, ev.VK_PAGE_UP}
            %SpinnerButtonUp();
        case ev.VK_ENTER
            % Get control values
            newVal = str2num(char(ev.getSource().getText()));
            oldVal = double(jSpinner.getValue());
            valMin = double(jSpinner.getModel().getMinimum());
            valMax = double(jSpinner.getModel().getMaximum());
            % Check if invalid value
            if (length(newVal) ~= 1)
                newVal = oldVal;
            elseif (newVal < valMin)
                newVal = valMin;
            elseif (newVal > valMax)
                newVal = valMax;
            end
            % Reset text field
            ev.getSource().setText(num2str(newVal));
            jSpinner.setValue(newVal);
            % Update interface
            UpdateTime();
    end
end


%% ===== RELOAD RECORDINGS =====
function ReloadRecordings(isForced)
    global GlobalData;
    % Parse inputs
    if (nargin < 1) || isempty(isForced)
        isForced = 0;
    end
    % Update dataset time definition
    [iDS, isRaw] = GetCurrentDataset();
    % RAW file: update time window
    if isRaw
        % Get panel controls
        ctrl = bst_get('PanelControls', 'Record');
        if isempty(ctrl)
            return;
        end
        % Get epoch indice
        iEpoch = ctrl.jSpinnerEpoch.getValue();
        Time = GlobalData.FullTimeWindow.Epochs(iEpoch).Time;
        % Get new time window
        iStart = double(ctrl.jSliderStart.getValue());
        timeLength = str2double(char(ctrl.jTextLength.getText()));
        % Convert time to number of samples
        sfreq = 1 / (Time(2) - Time(1));
        smpLength = min(round(timeLength * sfreq), length(Time));
        if (iStart + smpLength > length(Time))
            iStart = length(Time) - smpLength + 1;
        end
        iStop = iStart + smpLength - 1;
        newTimeWindow = Time([iStart, iStop]);
        % If time window did not change: stop update
        isTimeWindowChanged = ~isequal(GlobalData.UserTimeWindow.Time, newTimeWindow);
        isEpochChanged = (iEpoch ~= GlobalData.FullTimeWindow.CurrentEpoch);
        if ~isForced && ~isTimeWindowChanged && ~isEpochChanged
            return
        end
        % Get the current time indice in UserTimeWindow
        iCurrent = round((GlobalData.UserTimeWindow.CurrentTime - GlobalData.UserTimeWindow.Time(1)) ./ GlobalData.UserTimeWindow.SamplingRate);
        CurrentTimeNew = bst_saturate(Time(iStart + iCurrent), newTimeWindow);
        % Update UserTimeWindow
        GlobalData.UserTimeWindow.Time = newTimeWindow;
        GlobalData.UserTimeWindow.NumberOfSamples = smpLength;
        GlobalData.UserTimeWindow.CurrentTime = CurrentTimeNew;
        % Update current epoch index
        GlobalData.FullTimeWindow.CurrentEpoch = iEpoch;
        % Update dataset time definition
        GlobalData.DataSet(iDS).Measures.Time = newTimeWindow;
        GlobalData.DataSet(iDS).Measures.NumberOfSamples = smpLength;
        % Update linked result files
        for iRes = 1:length(GlobalData.DataSet(iDS).Results)
            if strcmpi(file_gettype(GlobalData.DataSet(iDS).Results(iRes).FileName), 'link') || ~isempty(strfind(GlobalData.DataSet(iDS).Results(iRes).FileName, '_KERNEL_'))
                GlobalData.DataSet(iDS).Results(iRes).Time = newTimeWindow;
                GlobalData.DataSet(iDS).Results(iRes).NumberOfSamples = smpLength;
            end
        end
    % Regular data file
    else
        if ~isForced
            return
        end
        isEpochChanged = 0;
    end
    % Progress bar
    % bst_progress('start', 'Update display', 'Loading recordings...');
    set(gcf, 'Pointer', 'watch');
    drawnow;
    % Epoch changed: Update events list
    if isEpochChanged
        % Get selected events group
        iSelEvt = GetSelectedEvents();
        % Update panel
        UpdatePanel();
        % Update lists
        UpdateEventsOccur();
        % Set selected events group
        if ~isempty(iSelEvt)
            SetSelectedEvent(iSelEvt(1));
        end
    end
    % Refresh time panel
    panel_time('UpdatePanel');
    % Reload recordings matrix from raw file
    bst_memory('LoadRecordingsMatrix', iDS);
    % Replot all figures
    bst_figures('ReloadFigures', [], 1, 1);
    % Flushes the display updates
    drawnow;
    % Close progress bar
    % bst_progress('stop');
    set(gcf, 'Pointer', 'arrow');
end


%% ===== REPLOT EVENTS =====
function ReplotEvents()
    global GlobalData;
    % Get raw dataset
    iDS = GetCurrentDataset();
    if isempty(iDS)
        return
    end
    % Loop on all figures
    for iFig = 1:length(GlobalData.DataSet(iDS).Figure)
        Figure = GlobalData.DataSet(iDS).Figure(iFig);
        % Process only RAW viewer figures
        if ~ismember(Figure.Id.Type, {'DataTimeSeries', 'ResultsTimeSeries'}) % || isempty(Figure.Id.Modality) || (Figure.Id.Modality(1) == '$')
            continue;
        end
        % Plot events dots on the raw time bar
        figure_timeseries('PlotEventsDots_TimeBar', Figure.hFigure);
        % Update events markers+labels in the events bar
        figure_timeseries('PlotEventsDots_EventsBar', Figure.hFigure);
    end
end


%% ===== READ RAW BLOCK =====
function [F, TimeVector, smpBlock] = ReadRawBlock(sFile, ChannelMat, iEpoch, TimeRange, DisplayMessages, UseCtfComp, RemoveBaseline, UseSsp, iChannels) %#ok<DEFNU>
    % Optional inputs
    if (nargin < 9) || isempty(iChannels)
        iChannels = [];
    end
    % Define reading options
    ImportOptions = db_template('ImportOptions');
    ImportOptions.ImportMode      = 'Time';
    ImportOptions.Resample        = 0;
    ImportOptions.UseCtfComp      = UseCtfComp;
    ImportOptions.UseSsp          = UseSsp;
    ImportOptions.RemoveBaseline  = RemoveBaseline;
    ImportOptions.DisplayMessages = DisplayMessages;
    % Get block size in samples
    blockSmpLength = round((TimeRange(2) - TimeRange(1)) * sFile.prop.sfreq) + 1;
    startSmp = round(TimeRange(1) * sFile.prop.sfreq);
    smpBlock = startSmp + [0, blockSmpLength - 1];
    % Read a block from the raw file
    [F, TimeVector] = in_fread(sFile, ChannelMat, iEpoch, smpBlock, iChannels, ImportOptions);
end


%% ===== GET TIME SELECTION =====
function [TimeSel, hFig] = GetTimeSelection()
    TimeSel = [];
    % Get raw time series figure
    [hFig,iFig,iDS] = bst_figures('GetCurrentFigure', '2D');
    if isempty(hFig)
        return
    end
    % Get the time selection from that figure
    GraphSelection = getappdata(hFig, 'GraphSelection');
    if ~isempty(GraphSelection) && ~isinf(GraphSelection(2))
        TimeSel = [min(GraphSelection), max(GraphSelection)];
    end
end


%% ===== UPDATE EVENTS TYPES =====
function UpdateEventsList()
    import org.brainstorm.list.*;
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Record');
    if isempty(ctrl)
        return;
    end
    % Invalidate list callback
    bakCallback = java_getcb(ctrl.jListEvtType, 'ValueChangedCallback');
    java_setcb(ctrl.jListEvtType, 'ValueChangedCallback', []);

    % Get events
    events = GetEvents();
    % Create list of events names
    listModel = javax.swing.DefaultListModel();
    for iEvent = 1:length(events)
        newItem = BstListItem('','',sprintf(' %s  (x%d)', events(iEvent).label, size(events(iEvent).times, 2)));
        if isequal(events(iEvent).select, 0)
            newItem.setName(['(' char(newItem.getName())]);
            newItem.setColor(java.awt.Color(0.7,0.7,0.7));
        elseif IsEventBad(events(iEvent).label)
            newItem.setColor(java.awt.Color(1,0,0));
        elseif isfield(events(iEvent), 'color') && ~isempty(events(iEvent).color)
            newItem.setColor(java.awt.Color(events(iEvent).color(1), events(iEvent).color(2), events(iEvent).color(3)));
        end
        listModel.addElement(newItem);
    end
    % Set this list
    ctrl.jListEvtType.setModel(listModel);
    ctrl.jListEvtType.repaint();
    
    % Restore list callback
    java_setcb(ctrl.jListEvtType, 'ValueChangedCallback', bakCallback);
end


%% ===== UPDATE EVENTS OCCURRENCES =====
function UpdateEventsOccur()
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Record');
    if isempty(ctrl)
        return;
    end
    % Get selected events types
    iSelEvt = GetSelectedEvents();
    % Get occurrences times
    if (length(iSelEvt) ~= 1)
        evtTimes = [];
    else
        event = GetEvents(iSelEvt);
        if isempty(event)
            evtTimes = [];
        else
            evtTimes = event.times;
        end
    end
    % Create list of events names
    listModel = java_create('javax.swing.DefaultListModel');
    for i = 1:size(evtTimes,2)
        % Simple events
        if (size(evtTimes, 1) == 1)
            strOcc = sprintf(' %1.3f', evtTimes(i));
        % Extended events
        else
            strOcc = sprintf(' %1.3f-%1.3f', evtTimes(1,i), evtTimes(2,i));
        end
        % Add list of channels
        if ~isempty(event.channels) && (i <= length(event.channels)) && ~isempty(event.channels{i})
            strOcc = [strOcc, '  ' sprintf(' %s', event.channels{i}{:})];
        end
        listModel.addElement(strOcc);
    end
    % Set this list
    ctrl.jListEvtOccur.setModel(listModel);
    ctrl.jListEvtOccur.repaint();
end


%% =================================================================================
%  === EVENTS MANAGEMENT ===========================================================
%  =================================================================================
%% ===== GET SELECTED EVENT =====
% Do not accept multiple selections
function [iEvent, iOccur] = GetSelectedEvent()
    % Get selected events
    [iEvent, iOccur] = GetSelectedEvents();
    % Keep only valid and unique selections
    if (length(iEvent) ~= 1) || (length(iOccur) ~= 1)
        iEvent = [];
        iOccur = [];
    end
end

%% ===== GET SELECTED EVENTS =====
% Accept multiple selections
function [iEvent, iOccur, isExtended] = GetSelectedEvents()
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Record');
    if isempty(ctrl)
        iEvent = [];
        iOccur = [];
        isExtended = [];
        return;
    end
    % Get selected event type
    iEvent = double(ctrl.jListEvtType.getSelectedIndices())' + 1;
    % Get selected event occurrence
    iOccur = double(ctrl.jListEvtOccur.getSelectedIndices())' + 1;
    % For each event type, returns if it's a simple or extended event
    if (nargout >= 3)
        events = GetEvents(iEvent);
        isExtended = false(1, length(iEvent));
        for i = 1:length(iEvent)
            isExtended(i) = (size(events(i).times, 1) == 2);
        end
    end
end


%% ===== SET SELECTED EVENT =====
% USAGE:  SetSelectedEvent(iEvent, iOccur)
%         SetSelectedEvent(iEvent)
function SetSelectedEvent(iEvent, iOccur)
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Record');
    if isempty(ctrl)
        return;
    end
    % Invalidate list callback
    bakCallback = java_getcb(ctrl.jListEvtType, 'ValueChangedCallback');
    java_setcb(ctrl.jListEvtType, 'ValueChangedCallback', []);
    
    % === SELECT EVENT TYPE ===
    if (length(iEvent) > 1)  || (~isempty(iEvent) && (iEvent ~= double(ctrl.jListEvtType.getSelectedIndex()) + 1))
        % Select event type
        if (length(iEvent) > 1)
            ctrl.jListEvtType.setSelectedIndices(iEvent - 1);
        else
            ctrl.jListEvtType.setSelectedIndex(iEvent - 1);
        end
        % Scroll to selection
        selRect = ctrl.jListEvtType.getCellBounds(iEvent(end)-1, iEvent(end)-1);
        if ~isempty(selRect)
            ctrl.jListEvtType.scrollRectToVisible(selRect);
        end
        ctrl.jListEvtType.repaint();
        % Update events occurrences
        UpdateEventsOccur();
    end
    
    % === SELECT EVENT OCCUR ===
    if (nargin >= 2)
        if ~isempty(iOccur)
            % Select occurrence
            ctrl.jListEvtOccur.setSelectedIndex(iOccur - 1);
            % Event occurrence: Scroll to selection
            selRect = ctrl.jListEvtOccur.getCellBounds(iOccur-1, iOccur-1);
            if ~isempty(selRect)
                ctrl.jListEvtOccur.scrollRectToVisible(selRect);
            end
        else
            % Unselect all the events
            nItems = ctrl.jListEvtOccur.getModel().getSize();
            ctrl.jListEvtOccur.removeSelectionInterval(0, nItems - 1);
        end
        
        ctrl.jListEvtOccur.repaint();
    end
    
    % Restore list callback
    java_setcb(ctrl.jListEvtType, 'ValueChangedCallback', bakCallback);
end


%% ===== GET CURRENT EVENT =====
% Get the event of the selected type at the current time point
function [iEvent, iOccur] = GetCurrentEvent()
    global GlobalData;
    % Get selected event type
    iEvent = GetSelectedEvents();
    iOccur = [];
    if (length(iEvent) == 1)
        % Get event occurrences
        sEvent = GetEvents(iEvent);
        if isempty(sEvent) || isempty(sEvent.times)
            return;
        end
        % Find if there is one that matches the current time
        epsilon = 1e-7;
        % Simple events
        if (size(sEvent.times,1) == 1)
            iOccur = find(abs(sEvent.times(1,:) - GlobalData.UserTimeWindow.CurrentTime) < epsilon);
        % Extended events
        else
            % Get time selection
            TimeSel = GetTimeSelection();
            % No time selection: pick the first event that is available at the current time
            if isempty(TimeSel)
                % Get teh current time
                CurrentTime = GlobalData.UserTimeWindow.CurrentTime;
                % Find an extended event that contains the current time
                iOccur = find((CurrentTime >= sEvent.times(1,:) - epsilon) & ...
                              (CurrentTime <= sEvent.times(2,:) + epsilon));
            % If a time selection is defined
            else
                % Select event if it includes or is included in the time selection
                iOccur = find(((TimeSel(1) >= sEvent.times(1,:)) & (TimeSel(2) <= sEvent.times(2,:))) | ...
                              ((TimeSel(1) <= sEvent.times(1,:)) & (TimeSel(2) >= sEvent.times(2,:))));
            end
            % Extended events
            if ~isempty(iOccur)
                iOccur = iOccur(1);
            end
        end
    else
        iEvent = [];
    end
end


%% ===== GET EVENTS IN TIME WINDOW =====
function events = GetEventsInTimeWindow(hFig) %#ok<DEFNU>
    global GlobalData;
    Time = GlobalData.UserTimeWindow.Time;
    % Parse inputs
    if (nargin < 1) || isempty(hFig)
        hFig = [];
    end
    % Get events for current epoch
    events = GetEvents([], [], hFig);
    % If there is no time window defined (averaged time)
    if isempty(Time)
        events = repmat(events,0);
        return; 
    end
    % Loop on all the events types
    for iEvt = 1:length(events)
        % If there are no occurrences: skip to next event type
        if isempty(events(iEvt).times)
            continue;
        end
        % Simple events
        if (size(events(iEvt).times, 1) == 1)
            iOccur = find((events(iEvt).times >= Time(1)) & (events(iEvt).times <= Time(2)));
        % Extended events
        else
            % Get all the events that are not either completely before or after the time window
            eTime = events(iEvt).times;
            iOccur = find((eTime(2,:) > Time(1)) & (eTime(1,:) < Time(2)));
        end
        % Else keep only the occurrences in time window
        events(iEvt).times    = events(iEvt).times(:,iOccur);
        events(iEvt).epochs   = events(iEvt).epochs(iOccur);
        if ~isempty(events(iEvt).channels)
            events(iEvt).channels = events(iEvt).channels(iOccur);
        end
        if ~isempty(events(iEvt).notes)
            events(iEvt).notes    = events(iEvt).notes(iOccur);
        end
        if ~isempty(events(iEvt).reactTimes)
            events(iEvt).reactTimes = events(iEvt).reactTimes(iOccur);
        end
    end
end

%% ===== JUMP TO EVENT =====
% USAGE:  JumpToEvent(iEvent, iOccur)
%         JumpToEvent(action)
%         JumpToEvent()
function JumpToEvent(iEvent, iOccur)
    global GlobalData;
    % Get events
    events = GetEvents();
    % === PARSE INPUTS ===
    if (nargin == 0)
        % Get selected event type and occurrence
        [iEvent, iOccur] = GetSelectedEvent();
        if isempty(iOccur)
            return
        end
    elseif (nargin == 1)
        action = iEvent;
        % Get selected event type
        iEvent = GetSelectedEvents();
        if (length(iEvent) ~= 1) || isempty(events(iEvent).times)
            return
        end
        % Get current time
        CurrentTime = GlobalData.UserTimeWindow.CurrentTime;
        % Distance to events times
        distTime = mean(events(iEvent).times, 1) - CurrentTime;
        % Action: next/previous events
        switch(action)
            case {'leftarrow', 'pagedown', 'epoch-', 'epoch--'}
                % Find previous event
                iOccur = find(distTime < -1e-3, 1, 'last');
            case {'rightarrow', 'pageup', 'epoch+', 'epoch++'}
                % Find next event
                iOccur = find(distTime > 1e-3, 1, 'first');
        end
        % No event found: return
        if isempty(iOccur)
            return
        end
        % Select event in the list
        SetSelectedEvent(iEvent, iOccur);
    end
    
    % === SET NEW TIME ===
    % Get event time
    evtEpoch = events(iEvent).epochs(iOccur);
    evtTime  = mean(events(iEvent).times(:,iOccur),1);
    evtChannel = [];
    if ~isempty(events(iEvent).channels)
        evtChannel = events(iEvent).channels{iOccur};
    end
    % Check if event is a "full page" shortcut
    RawViewerOptions = bst_get('RawViewerOptions');
    iShortcut = find(strcmpi(RawViewerOptions.Shortcuts(:,2), events(iEvent).label));
    isFullPage = ~isempty(iShortcut) && any(strcmpi(RawViewerOptions.Shortcuts(iShortcut,3), 'page')) && (size(events(iEvent).times,1) == 2);
    % If event is outside of the current user time window
    UserTime = GlobalData.UserTimeWindow.Time;
    if (evtTime < UserTime(1)) || (evtTime > UserTime(2))
        % Full page: start at the beginning of the event
        if isFullPage
            startTime = events(iEvent).times(1,iOccur);
        % Try to position the selected event at 30% of the time window
        else
            startTime = evtTime - .3 * (UserTime(2) - UserTime(1));
        end
        % Get raw viewer window
        SetStartTime(startTime, evtEpoch);
    end
    % Select the event time
    panel_time('SetCurrentTime', evtTime);
    % Select channels if any
    bst_figures('SetSelectedRows', evtChannel);
end


%% ===== GET EVENTS =====
% USAGE:  GetEvents(iEvents)   : Get events by indices
%         GetEvents(eventName) : Get event by name
%         GetEvents()          : Get all the events
%         GetEvents(..., isIgnoreEpoch)
function [events, iEvent] = GetEvents(target, isIgnoreEpoch, hFig)
    global GlobalData;
    % Parse inputs
    if (nargin < 3) || isempty(hFig)
        hFig = [];
    end
    if (nargin < 2) || isempty(isIgnoreEpoch)
        isIgnoreEpoch = 0;
    end
    if (nargin < 1) || isempty(target)
        target = [];
    end    
    events = [];
    iEvent = [];
    % Get raw dataset
    [iDS, isRaw] = GetCurrentDataset(hFig);
    if isempty(iDS)
        return
    end
    % If no events are registered
    if isempty(GlobalData.DataSet(iDS).Measures.sFile) || isempty(GlobalData.DataSet(iDS).Measures.sFile.events)
        return
    end
    % Parse inputs
    if isempty(target)
        iEvent = [];
    elseif ischar(target)
        iEvent = find(strcmpi(target, {GlobalData.DataSet(iDS).Measures.sFile.events.label}));
        if isempty(iEvent)
            return
        end
    elseif isnumeric(target)
        iEvent = target;
    else
        error('Invalid call.');
    end
    % Get events
    if isempty(iEvent) 
        events = GlobalData.DataSet(iDS).Measures.sFile.events;
    elseif all((iEvent >= 1) & (iEvent <= length(GlobalData.DataSet(iDS).Measures.sFile.events)))
        events = GlobalData.DataSet(iDS).Measures.sFile.events(iEvent);
    else
        error('Invalid event indice.');
    end
    % If there are epochs in this file: sub-selection to current epoch
    if isRaw && ~isIgnoreEpoch && isfield(GlobalData.DataSet(iDS).Measures.sFile, 'epochs') && (length(GlobalData.DataSet(iDS).Measures.sFile.epochs) > 1)
        for i = 1:length(events)
            iOkEpochs = (events(i).epochs == GlobalData.FullTimeWindow.CurrentEpoch);
            events(i).times    = events(i).times(:,iOkEpochs);
            events(i).epochs   = events(i).epochs(iOkEpochs);
            if ~isempty(events(i).channels)
                events(i).channels = events(i).channels(iOkEpochs);
            end
            if ~isempty(events(i).reactTimes)
                events(i).notes    = events(i).notes(iOkEpochs);
            end
            if ~isempty(events(i).reactTimes)
                events(i).reactTimes = events(i).reactTimes(iOkEpochs);
            end
        end
    end
end

%% ===== SET EVENTS =====
% USAGE:  SetEvents(sEvent, iEvent) : Update target event
%         SetEvents(sEvents)        : Update the whole events structure
function SetEvents(sEvent, iEvent)
    global GlobalData;
    % Get raw dataset
    [iDS, isRaw] = GetCurrentDataset();
    if isempty(iDS)
        return
    end
    % If there is no event structure defined, nothing to do
    if isempty(GlobalData.DataSet(iDS).Measures.sFile)
        return
    end
    % Parse inputs
    if (nargin < 2)
        iEvent = [];
    elseif isempty(iEvent) || (iEvent <= 0) || (iEvent > length(GlobalData.DataSet(iDS).Measures.sFile.events) + 1)
        error('Invalid event indice.');
    end
    % Update events
    if ~isempty(iEvent) && ~isempty(GlobalData.DataSet(iDS).Measures.sFile.events)
        GlobalData.DataSet(iDS).Measures.sFile.events(iEvent) = sEvent;
    else
        GlobalData.DataSet(iDS).Measures.sFile.events = sEvent;
    end
    % Mark dataset as modified
    GlobalData.DataSet(iDS).Measures.isModified = 1;
end

%% ===== GET EVENT COLOR TABLE =====
function ColorTable = GetEventColorTable()
    ColorTable = [0     1    0   
                 .4    .4    1   
                  1    .6    0
                  0     1    1  
                 .56   .01  .91
                  0    .5    0 
                 .4     0    0   
                  1     0    1  
                 .02   .02   1
                 .5    .5   .5];
end

%% ===== GET NEW EVENT COLOR =====
function newColor = GetNewEventColor(iEvt, AllEvents)
    % Get events color table
    ColorTable = GetEventColorTable();
    % Attribute the first color that of the colortable that is not in the existing events
    for iColor = 1:length(ColorTable)
        if isempty(AllEvents) || ~isstruct(AllEvents) || ~any(cellfun(@(c)isequal(c, ColorTable(iColor,:)), {AllEvents.color}))
            break;
        end
    end
    % If all the colors of the color table are taken: attribute colors cyclically
    if (iColor == length(ColorTable))
        iColor = mod(iEvt-1, length(ColorTable)) + 1;
    end
    newColor = ColorTable(iColor,:);
end


%% ===== EVENT TYPE: ADD =====
% USAGE:  EventTypeAdd(sEvent)    : Add a fully defined event
%         EventTypeAdd(eventName) : Add an event name
%         EventTypeAdd()          : Ask user the event name
function iEvent = EventTypeAdd(sEvent)
    % Get ALL events (ignore current epoch)
    events = GetEvents([], 1);
    
    % ===== DEFINE EVENT =====
    % Event strcture in argument
    if (nargin == 1) && isstruct(sEvent)
        % Just keep it
    else
        % Get new type label
        if (nargin == 0)
            newLabel = java_dialog('input', 'Enter a name for the new event group:', 'Create event');
            if isempty(newLabel)
                return;
            end
        else
            newLabel = sEvent;
        end
        % New event indice
        iEvent = length(events) + 1;
        % Set color of the event.
        % If the event name contains the word "bad", it is displayed in red
        if IsEventBad(newLabel)
            newColor = [1 0 0];
        % Else: Get default new color
        else
            newColor = GetNewEventColor(iEvent, events);
        end
        % Initialize new event
        sEvent = db_template('event');
        sEvent.label = newLabel;
        sEvent.color = newColor;
    end
    
    % ===== ADD EVENT =====
    % Check if a event type with that name already exists
    if ~isempty(events)
        iEvtType = find(strcmpi(sEvent.label, {events.label}));
        if ~isempty(iEvtType)
            iEvent = iEvtType;
            SetSelectedEvent(iEvtType);
            return
        end
    end
    % Add event to loaded
    SetEvents(sEvent, iEvent);
    % Update events list
    UpdateEventsList();
    UpdateEventsOccur();
    % Select it in the list
    SetSelectedEvent(iEvent);
end


%% ===== EVENT TYPE: DELETE =====
% USAGE:  EventTypeDel(iEvents,    isForced=0) : Delete by indices
%         EventTypeDel(eventLabel, isForced=0) : Delete by name
%         EventTypeDel()                       : Delete selected event type
function EventTypeDel(target, isForced)
    % Parse inputs
    if (nargin < 2) || isempty(isForced)
        isForced = 0;
    end
    % Get ALL events (ignore current epoch)
    events = GetEvents([], 1);
    if isempty(events)
        return;
    end
    % Parse inputs
    if (nargin == 0)
        % Get selected events
        iEvents = GetSelectedEvents();
    else
        [tmp__, iEvents] = GetEvents(target);
    end
    % No event selected
    if isempty(iEvents)
        bst_error('No event selected.', 'Delete events', 0);
    end
    % Count all the events occurrences
    nEvents = 0;
    for i = 1:length(iEvents)
        nEvents = nEvents + size(events(iEvents(i)).times,2);
    end
    % If some events are going to be deleted: Ask user confirmation
    if (nEvents > 0) && ~isForced
        if ~java_dialog('confirm', sprintf('Delete %d events ?', nEvents), 'Delete events')
            return
        end
    end
    % Remove event
    events(iEvents) = [];
    % Update dataset
    SetEvents(events);
    % Update events list
    UpdateEventsList();
    UpdateEventsOccur();
    % Update figures
    %if (nEvents > 0)
        %ReplotFigures();
        ReplotEvents();
    %end
end

%% ===== EVENT TYPE: RENAME =====
function EventTypeRename()
    % Get selected events
    iEvent = GetSelectedEvents();
    if (length(iEvent) ~= 1)
        return;
    end
    % Get event (ignore current epoch)
    sEvent = GetEvents(iEvent, 1);
    if isempty(sEvent)
        return;
    end
    % Ask new label to the user
    newLabel = java_dialog('input', 'Enter new label:', 'Rename event', [], sEvent.label);
    if isempty(newLabel) || isequal(newLabel, sEvent.label)
        return
    end
    % Check if event label already exists (allow changing case)
    if ~isempty(GetEvents(newLabel)) && ~strcmpi(newLabel, sEvent.label)
        bst_error('This event label already exists.', 'Create event', 0);
        return
    end
    % Update label
    sEvent.label = newLabel;
    % Update dataset
    SetEvents(sEvent, iEvent);
    % Update events list
    UpdateEventsList();
    % Update figures
    %ReplotFigures();
    ReplotEvents();
end

%% ===== EVENT TYPE: SET COLOR =====
function EventTypeSetColor()
    % Get selected events
    iEvent = GetSelectedEvents();
    if (length(iEvent) ~= 1)
        return;
    end
    % Get event (ignore current epoch)
    sEvent = GetEvents(iEvent, 1);
    % Ask new color to the user
    % newColor = uisetcolor(sEvent.color, 'Select event color');
    newColor = java_dialog('color');
    % If no color was selected: exit
    if (length(newColor) ~= 3) || all(sEvent.color == newColor)
        return
    end
    % Update label
    sEvent.color = newColor;
    % Update dataset
    SetEvents(sEvent, iEvent);
    % Update events list
    UpdateEventsList();
    % Update figures
    %ReplotFigures();
    ReplotEvents();
end


%% ===== EVENT TYPE: TOGGLE VISIBLE =====
function EventTypeToggleVisible()
    % Get selected events
    iSelEvents = GetSelectedEvents();
    if isempty(iSelEvents)
        return;
    end
    % Loop on selected events
    for i = 1:length(iSelEvents)
        iEvent = iSelEvents(i);
        % Get event (ignore current epoch)
        sEvent = GetEvents(iEvent, 1);
        % Toogle selected
        if isempty(sEvent.select)
            sEvent.select = 0;
        else
            sEvent.select = ~sEvent.select;
        end
        % Update dataset
        SetEvents(sEvent, iEvent);
    end
    % Update events list
    UpdateEventsList();
    % Select again events in list
    SetSelectedEvent(iSelEvents);
    % Update figures
    ReplotEvents();
end


%% ===== EVENT TYPE: TOGGLE BAD =====
function EventTypeToggleBad()
    % Get selected events
    iEvents = GetSelectedEvents();
    if isempty(iEvents)
        return;
    end
    % Get event (ignore current epoch)
    sEvents = GetEvents(iEvents, 1);
    % Get all events
    sEventsAll = GetEvents();
    % Update all the groups
    isModified = 0;
    for i = 1:length(sEvents)
        % Switch from bad to good
        if IsEventBad(sEvents(i).label)
            sEvents(i) = SetEventGood(sEvents(i), sEventsAll);
        % Switch from good to bad
        else
            sEvents(i).label = file_unique(['bad_' sEvents(i).label], {sEventsAll.label});
        end
        % Update dataset
        SetEvents(sEvents(i), iEvents(i));
        % Mark events list as modified
        isModified = 1;
    end
    % No modifications: return
    if ~isModified
        return;
    end
    % Update events list
    UpdateEventsList();
    % Update figures
    ReplotEvents();
end


%% ===== SET EVENT GOOD ====
function [sEvent, isModified] = SetEventGood(sEvent, sEventsAll)
    isModified = 0;
    % Switch "BAD" to good
    if strcmpi(sEvent.label, 'bad')
        newLabel = 'undefined';
        isModified = 1;
    % Switch other bad events to good
    elseif IsEventBad(sEvent.label)
        newLabel = strrep(sEvent.label, 'bad ', '');
        newLabel = strrep(newLabel, 'bad_', '');
        newLabel = strrep(newLabel, ' bad', '');
        newLabel = strrep(newLabel, '_bad', '');
        isModified = 1;
    end
    % Event was modified
    if isModified
        % Make new label unique
        sEvent.label = file_unique(newLabel, {sEventsAll.label});
        % Change the color from red to orange
        if isequal(sEvent.color, [1 0 0])
            sEvent.color = [1 0.65 0];
        end
    end
end


%% ===== MERGE EVENT TYPES =====
function EventTypesMerge()
    % Get selected events
    [iEvents, tmp__, isExtended] = GetSelectedEvents();
    if (length(iEvents) < 2)
        bst_error('You have to select at least two groups of events to merge.', 'Merge event groups', 0);
        return;
    end
    % Check if mixed types of events
    if any(isExtended) && any(~isExtended)
        bst_error('You cannot merge simple and extended events together.', 'Merge event groups', 0);
        return;
    end
    % Ask new label to the user
    newLabel = java_dialog('input', 'Enter new label:', 'Merge event groups', [], 'NewGroup');
    if isempty(newLabel)
        return
    end
    % Get ALL events (ignore current epoch)
    events = GetEvents([], 1);
    
    % Inialize new event group
    newEvent = events(iEvents(1));
    newEvent.label    = newLabel;
    newEvent.times    = [events(iEvents).times];
    newEvent.epochs   = [events(iEvents).epochs];
    % Reaction time, notes, channels: only if all the events have them
    if all(~cellfun(@isempty, {events(iEvents).channels}))
        newEvent.channels = [events(iEvents).channels];
    else
        newEvent.channels = [];
    end
    if all(~cellfun(@isempty, {events(iEvents).notes}))
        newEvent.notes = [events(iEvents).notes];
    else
        newEvent.notes = [];
    end
    if all(~cellfun(@isempty, {events(iEvents).reactTimes}))
        newEvent.reactTimes = [events(iEvents).reactTimes];
    else
        newEvent.reactTimes = [];
    end
    % Sort by samples indices, and remove redundant values
    [tmp__, iSort] = unique(bst_round(newEvent.times(1,:), 9));
    newEvent.times    = newEvent.times(:,iSort);
    newEvent.epochs   = newEvent.epochs(iSort);
    if ~isempty(newEvent.channels)
        newEvent.channels = newEvent.channels(iSort);
    end
    if ~isempty(newEvent.notes)
        newEvent.notes = newEvent.notes(iSort);
    end
    if ~isempty(newEvent.reactTimes)
        newEvent.reactTimes = newEvent.reactTimes(iSort);
    end
    
    % Remove merged events
    events(iEvents) = [];
    % Add new event
    events(end + 1) = newEvent;
    % Update dataset
    SetEvents(events);
    % Update events list
    UpdateEventsList();
    UpdateEventsOccur();
    % Update figures
    ReplotEvents();
end


%% ===== DUPLICATE EVENTS =====
function EventTypesDuplicate()
    % Get selected events
    iEvents = GetSelectedEvents();
    if isempty(iEvents)
        bst_error('No event groups selected.', 'Merge event groups', 0);
        return;
    end
    % Get ALL events (ignore current epoch)
    events = GetEvents([], 1);
    % Copy each group
    for i = 1:length(iEvents)
        % Get new indice
        iCopy(i) = length(events) + 1;
        events(iCopy(i)) = events(iEvents(i));
        % Add "copy" tag
        events(iCopy(i)).label = file_unique(events(iCopy(i)).label, {events.label});
        % Set new color
        events(iCopy(i)).color = GetNewEventColor(iCopy(i), events);
    end
    % Update dataset
    SetEvents(events);
    % Update events list
    UpdateEventsList();
    UpdateEventsOccur();
    % Select new events
    SetSelectedEvent(iCopy);
    % Update figures
    ReplotEvents();
end


%% ===== CONVERT TO SIMPLE EVENTS =====
function EventConvertToSimple()
    global GlobalData;
    % Get selected events
    [iEvents, tmp__, isExtended] = GetSelectedEvents();
    if isempty(iEvents)
        return;
    end
    % Check if all events are extended
    if ~all(isExtended)
        bst_error('You can convert to simple events only the extended events.', 'Convert event type', 0);
        return;
    end
    % Get events (ignore current epoch)
    sEvents = GetEvents(iEvents, 1);
    % Ask if we should keep only the first or the last sample of the extended event
    res = java_dialog('question', ...
        'What part of the extended events do you want to keep?', ...
        'Convert event type', [], {'Start', 'Middle', 'End', 'Every sample', 'Cancel'}, 'Middle');
    % User canceled operation
    if isempty(res) || strcmpi(res, 'Cancel')
        return
    end
    % Get current dataset
    [iDS, ~] = GetCurrentDataset();
    % Get sampling rate
    sfreq = 1 / GlobalData.DataSet(iDS).Measures.SamplingRate;
    % Apply modificiation to each event type
    Method = strrep(lower(res), ' ', '_');
    sEvents = process_evt_simple('Compute', sEvents, Method, sfreq);
    for i = 1:length(sEvents)
        % Update event
        SetEvents(sEvents(i), iEvents(i));
    end
    % Update events list
    UpdateEventsList();
    UpdateEventsOccur();
    % Update figures
    ReplotEvents();
end


%% ===== CONVERT TO EXTENDED EVENTS =====
function EventConvertToExtended()
    global GlobalData;
    % Get selected events
    [iEvents, tmp__, isExtended] = GetSelectedEvents();
    if isempty(iEvents)
        return;
    end
    % Check if all events are extended
    if any(isExtended)
        bst_error('You can convert to extended events only the simple events.', 'Convert event type', 0);
        return;
    end
    % Get events (ignore current epoch)
    sEvents = GetEvents(iEvents, 1);
    % Ask if we should keep only the first or the last sample of the extended event
    res = java_dialog('input', ...
        {'Time to include before the event (milliseconds):', 'Time to include after the event (milliseconds):'}, ...
        'Convert to extended event', [], {'200', '200'});
    % User canceled operation
    if isempty(res) || isempty(res{1}) || isempty(res{2}) || isempty(str2num(res{1})) || isempty(str2num(res{2}))
        return
    end
    % Get current dataset
    [iDS, isRaw] = GetCurrentDataset();
    % Get sampling rate
    sfreq = 1 / GlobalData.DataSet(iDS).Measures.SamplingRate;
    % Get time window in seconds
    evtWindow = [-abs(str2num(res{1})), str2num(res{2})] ./ 1000;
    % Apply modificiation to each event type
    if isempty(GlobalData.FullTimeWindow) || isempty(GlobalData.FullTimeWindow.CurrentEpoch)
        FullTimeWindow = GlobalData.DataSet(iDS).Measures.Time;
    else
        FullTimeWindow = GlobalData.FullTimeWindow.Epochs(GlobalData.FullTimeWindow.CurrentEpoch).Time([1, end]);
    end
    sEvents = process_evt_extended('Compute', sEvents, evtWindow, FullTimeWindow, sfreq);
    for i = 1:length(sEvents)
        % Update event
        SetEvents(sEvents(i), iEvents(i));
    end
    % Update events list
    UpdateEventsList();
    UpdateEventsOccur();
    % Update figures
    ReplotEvents();
end


%% ===== EVENT TYPE: SORT =====
function EventTypesSort(SortMode)
    % Get ALL events (ignore current epoch)
    events = GetEvents([], 1);
    % Nothing to sort: return
    if (length(events) < 2)
        return;
    end 
    % Orber by...
    switch lower(SortMode)
        case 'name'
            [tmp,iOrder] = sort({events.label});
        case 'time'
            firstTime = zeros(1,length(events));
            for iEvt = 1:length(events)
                if isempty(events(iEvt).times)
                    firstTime(iEvt) = Inf;
                else
                    firstTime(iEvt) = events(iEvt).times(1);
                end
            end
            [tmp,iOrder] = sort(firstTime);
    end
    % Apply sorting 
    events = events(iOrder);
    % Update dataset
    SetEvents(events);
    % Update events list
    UpdateEventsList();
    UpdateEventsOccur();
end


%% ===== EVENT OCCUR: ADD =====
% USAGE: [sEvent, iOccur] = EventOccurAdd(iEvent=[selected], channelNames=[])
function [sEvent, iOccur] = EventOccurAdd(iEvent, channelNames)
    global GlobalData;
    % Initialize returned variables
    sEvent = [];
    iOccur = [];
    % Parse inputs
    if (nargin < 2) || isempty(channelNames) || ~iscell(channelNames)
        channelNames = [];
    end
    if (nargin < 1) || isempty(iEvent)
        % Get selected events
        iEvent = GetSelectedEvents();
    end    
    if (length(iEvent) ~= 1)
        bst_error('You have to select an event group before adding an event.', 'Add event', 0);
        return;
    end
    % Get current dataset
    [iDS, isRaw] = GetCurrentDataset();
    % Get events (ignore current epoch)
    sEvent = GetEvents(iEvent, 1);
    % Get current time
    if isRaw
        iEpoch = GlobalData.FullTimeWindow.CurrentEpoch;
    else
        iEpoch = 1;
    end
    % Get time selection
    [TimeSel, hFig] = GetTimeSelection();
    % Get selected montage
    TsInfo = getappdata(hFig, 'TsInfo');
    if ~isempty(TsInfo.MontageName)
        sMontage = panel_montage('GetMontage', TsInfo.MontageName, hFig);
    else
        sMontage = [];
    end
    
    % Detect if it is a simple or extended event
    if ~isempty(sEvent.times)
        isExtended = (size(sEvent.times,1) == 2);
    else
        isExtended = ~isempty(TimeSel);
    end
    % Do not accept simple events for "BAD"
    if ~isExtended && strcmpi(sEvent.label, 'BAD')
        bst_error('No time selection.', 'Add event', 0);
        return;
    end

    % SIMPLE EVENT
    if ~isExtended
        newTime = GlobalData.UserTimeWindow.CurrentTime;
        % Check there is not already an event at this time
        if ~isempty(sEvent.times) && any((sEvent.times == newTime) & (sEvent.epochs == iEpoch))
            bst_error('Event is already marked.', 'Add event', 0);
            return
        end
    % EXTENDED EVENT
    else
        % If no time selection: get current time
        if isempty(TimeSel)
            %TimeSel = [GlobalData.UserTimeWindow.CurrentTime, GlobalData.UserTimeWindow.CurrentTime];
            bst_error('No time selection.', 'Add event', 0);
            return;
        end
        % Check there is not already an event at this time
        newTime = TimeSel;
        isEpochOk = (sEvent.epochs == iEpoch);
        if ~isempty(sEvent.times) && (any((sEvent.times(1,:) <= newTime(1)) & (sEvent.times(2,:) >= newTime(2)) & isEpochOk) || ...
                                      any((sEvent.times(1,:) >= newTime(1)) & (sEvent.times(2,:) <= newTime(2)) & isEpochOk))
            bst_error('Event is already marked.', 'Add event', 0);
            return
        end
        % Reset time selection when plotting with lines/patches
        if strcmpi(TsInfo.ShowEventsMode, 'line')
            figure_timeseries('SetTimeSelectionLinked', hFig, []);
        end
    end
    

    % Channel names in the case of referencing montages
    if ~isempty(sMontage)
        chanMontage = {};
        for i = 1:length(channelNames)
            % If the channel is found in the channel file, add as is
            if any(strcmpi({GlobalData.DataSet(iDS).Channel.Name}, channelNames{i}))
                chanMontage = [chanMontage, channelNames(i)];
            % Else: Look for channel name in the labels of the montage
            else
                iDispName = find(strcmpi(sMontage.DispNames, channelNames{i}));
                if ~isempty(iDispName)
                    iChan = find(sMontage.Matrix(iDispName,:));
                    chanMontage = [chanMontage, sMontage.ChanNames(iChan)];
                else
                    chanMontage = [chanMontage, channelNames{i}];
                end
            end
        end
        channelNames = unique(chanMontage);
    end
    % Add event: time
    sEvent.epochs = [sEvent.epochs, iEpoch];
    sEvent.times  = [sEvent.times, newTime'];
    % Sort based on the beginning of each event
    [tmp__, indSort] = sortrows([sEvent.epochs; sEvent.times(1,:)]');
    sEvent.times    = sEvent.times(:,indSort);
    sEvent.epochs   = sEvent.epochs(indSort);
    % Add list of channels (if already defined, or if adding channel-defined event)
    if ~isempty(sEvent.channels) || ~isempty(channelNames)
        if isempty(sEvent.channels) 
            sEvent.channels = cell(1, size(sEvent.times,2) - 1);
        end
        sEvent.channels = [sEvent.channels, {channelNames(:)'}];
        sEvent.channels = sEvent.channels(indSort);
    end
    % Add event: notes, reactTime (only if there are already defined)
    if ~isempty(sEvent.notes)
        sEvent.notes = [sEvent.notes, {[]}];
        sEvent.notes = sEvent.notes(indSort);
    end
    if ~isempty(sEvent.reactTimes)
        sEvent.reactTimes = [sEvent.reactTimes, 0];
        sEvent.reactTimes = sEvent.reactTimes(indSort);
    end
    
    % Update dataset
    SetEvents(sEvent, iEvent);
    % Update events list
    UpdateEventsList();
    UpdateEventsOccur();
    % Get the occurrence indice of the added event (in current epoch only)
    iOkEpoch = (sEvent.epochs == iEpoch);
    iOccur = find(sum(sEvent.times(:,iOkEpoch) == newTime(1), 1) >= 1);
    % Select event
    SetSelectedEvent(iEvent, iOccur);
    % Update figures
    ReplotEvents();
end


%% ===== EVENT OCCUR: DELETE =====
function EventOccurDel(iEvent, iOccursEpoch)
    global GlobalData;
    % Parse inputs
    if (nargin < 2) || isempty(iEvent) || isempty(iOccursEpoch)
        % Get selected events
        [iEvent, iOccursEpoch] = GetSelectedEvents();
    end
    if (length(iEvent) ~= 1) || isempty(iOccursEpoch)
        bst_error('No event selected.', 'Delete events', 0);
        return;
    end
    % More than one event deleted: Ask user confirmation
    if (length(iOccursEpoch) > 1)
        if ~java_dialog('confirm', sprintf('Delete %d events ?', length(iOccursEpoch)), 'Delete events')
            return
        end
    end
    
    % Get event type (ignore current epoch)
    sEvent = GetEvents(iEvent, 1);
    % Get list of occurrences for this epoch
    if (length(GlobalData.FullTimeWindow.Epochs) > 1)
        indEpoch = find(sEvent.epochs == GlobalData.FullTimeWindow.CurrentEpoch);
        iOccurs = indEpoch(iOccursEpoch);
    else
        iOccurs = iOccursEpoch;
    end
    
    % Remove event occurrences
    sEvent.times(:,iOccurs)  = [];
    sEvent.epochs(iOccurs)   = [];
    if ~isempty(sEvent.channels)
        sEvent.channels(iOccurs) = [];
    end
    if ~isempty(sEvent.notes)
        sEvent.notes(iOccurs) = [];
    end
    if ~isempty(sEvent.reactTimes)
        sEvent.reactTimes(iOccurs) = [];
    end
    % Update dataset
    SetEvents(sEvent, iEvent);
    % Update events list
    UpdateEventsList();
    UpdateEventsOccur();
    % Select event
    SetSelectedEvent(iEvent);
    % Update figures
    %ReplotFigures();
    ReplotEvents();
end


%% ===== EVENT OCCUR: EDIT NOTES =====
function EventEditNotes()
    % Get selected events
    [iEvent, iOccur] = GetSelectedEvents();
    if (length(iEvent) ~= 1) || isempty(iOccur)
        return;
    end
    % Get event (ignore current epoch)
    sEvent = GetEvents(iEvent, 1);
    % Add notes structure
    if isempty(sEvent.notes)
        sEvent.notes = cell(1, size(sEvent.times,2));
    end
    % Format event name
    if (size(sEvent.times, 1) == 1)
        strOcc = sprintf('"%s" (%1.3fs)', sEvent.label, sEvent.times(1, iOccur));
    else
        strOcc = sprintf('"%s" (%1.3f-%1.3fs)', sEvent.label, sEvent.times(1,iOccur), sEvent.times(2,iOccur));
    end
    % Ask new label to user
    if ~isempty(sEvent.notes{iOccur})
        prevNote = sEvent.notes{iOccur};
    else
        prevNote = '';
    end
    [newNote, isCancel] = java_dialog('input', ['Edit event ' strOcc ':'], 'Edit event notes', [], prevNote);
    % If cancelled, or not not changed
    if isCancel || isequal(prevNote, newNote)
        return
    end
    newNote = strtrim(newNote);
    % Update label
    sEvent.notes{iOccur} = newNote;
    % Update dataset
    SetEvents(sEvent, iEvent);
    % Update figures;
    ReplotEvents();
end


%% ===== REJECT TIME SEGMENT =====
function RejectTimeSegment()
    ToggleEvent('BAD');
end


%% ===== TOGGLE EVENT AT CURRENT TIME =====
% USAGE:  ToggleEvent(eventName=[ask], channelNames=[], isFullPage=0)
%         ToggleEvent()
%
% INPUTS:
%    - eventName    : Name of the event to add/delete
%    - channelNames : Cell-array of strings, names of the channels associated with the new event
%    - isFullPage   : If 0, regular behavior, if an event exists it is removed, otherwise an event is created
%                     If 1, sleep-scoring mode, existing event is not deleted but similar events in other groups are removed
function ToggleEvent(eventName, channelNames, isFullPage)
    % Parse inputs
    if (nargin < 3) || isempty(isFullPage)
        isFullPage = 0;
    end
    if (nargin < 2) || isempty(channelNames)
        channelNames = [];
    end
    % Get event at current time
    [iEvent, iOccur] = GetCurrentEvent();
    % Set current event if specified
    if (nargin >= 1) && ~isempty(eventName)
        % Get target event
        [events, iEventTarget] = GetEvents(eventName);
        % If target does not exist: create
        if isempty(iEventTarget)
            iEventTarget = EventTypeAdd(eventName);
        % If current event is not the selected one: change selection
        elseif ~isequal(iEventTarget, iEvent)
            SetSelectedEvent(iEventTarget);
        end
        % Get again selected event
        [iEvent, iOccur] = GetCurrentEvent();
    end
    
    % In full page mode: attribute the page to only one event type
    if isFullPage
        % There is no event at selected time: Add an event
        if isempty(iOccur)
            [sEvent, iOccur] = EventOccurAdd(iEvent, channelNames);
        else
            sEvent = GetEvents(iEvent);
        end
        % If this is really an extended event: Look for other events at the same time
        if (size(sEvent.times,1) == 2)
            sAllEvents = GetEvents();
            for i = setdiff(1:length(sAllEvents), iEvent)
                if ~isempty(sAllEvents(i).times) && (size(sAllEvents(i).times,1) == 2)
                    % Find overlapping event
                    iDel = find((abs(sAllEvents(i).times(1,:) - sEvent.times(1,iOccur)) < 1e-3) & ...
                                (abs(sAllEvents(i).times(2,:) - sEvent.times(2,iOccur)) < 1e-3));
                    % Remove event
                    if ~isempty(iDel)
                        EventOccurDel(i, iDel);
                    end
                end
            end
        end
    % In regular mode: toggle on/off
    else
        % There is no event at selected time: Add an event
        if isempty(iOccur)
            [sEventNew, iOccurNew] = EventOccurAdd(iEvent, channelNames);
        % There is an event at selected time: Delete it
        elseif ~isempty(iOccur)
            EventOccurDel(iEvent, iOccur);
        end
    end
end


%% ===== IMPORT IN DATABASE =====
function ImportInDatabase()
    global GlobalData;
    % Get raw dataset
    iDS = GetCurrentDataset();
    if isempty(iDS)
        return;
    end
    % Save current modifications
    if GlobalData.DataSet(iDS).Measures.isModified
        bst_progress('start', 'Import raw file', 'Saving modifications...');
        SaveModifications(iDS);
        bst_progress('stop');
    end
    % Import files into database
    NewFiles = import_raw_to_db(GlobalData.DataSet(iDS).DataFile);
    if isempty(NewFiles)
        return;
    end
    % Close all figures
    bst_memory('UnloadAll', 'Forced');
end


%% ===== EXPORT SELECTED EVENTS =====
function ExportSelectedEvents()
    global GlobalData;
    % Get raw file viewer dataset
    iDS = GetCurrentDataset();
    if isempty(iDS)
        error('No events are currently loaded.');
    end
    % Get sFile structure
    sFile = GlobalData.DataSet(iDS).Measures.sFile;
    % Get channel file
    ChannelMat = in_bst_channel(GlobalData.DataSet(iDS).ChannelFile);
    % Get selected events
    [iEvt, iOcc] = GetSelectedEvents();
    if isempty(iEvt)
        bst_error('No events currently selected.', 'Export events', 0);
        return
    end
    % Creating a temporary sFile structure just to save the events
    sFileTmp = sFile;
    % Export a few occurrences of a given event type
    if (length(iEvt) == 1) && ~isempty(iOcc)
        sFileTmp.events = sFileTmp.events(iEvt);
        sFileTmp.events.times    = sFileTmp.events.times(:,iOcc);
        sFileTmp.events.epochs   = sFileTmp.events.epochs(:,iOcc);
        if ~isempty(sFileTmp.events.channels)
            sFileTmp.events.channels = sFileTmp.events.channels(iOcc);
        end
        if ~isempty(sFileTmp.events.notes)
            sFileTmp.events.notes = sFileTmp.events.notes(iOcc);
        end
        if ~isempty(sFileTmp.events.reactTimes)
            sFileTmp.events.reactTimes = sFileTmp.events.reactTimes(iOcc);
        end
    else
        sFileTmp.events = sFileTmp.events(iEvt);
    end
    % Export events
    export_events(sFileTmp, ChannelMat);
end


%% ===== IMPORT EVENTS =====
function ImportEvents(varargin)
    global GlobalData;
    % Get raw file viewer dataset
    [iDS, isRaw] = GetCurrentDataset();
    if isempty(iDS) || isempty(GlobalData.DataSet(iDS).Measures.sFile)
        error('No events are currently loaded.');
    end
    % Load channel file
    ChannelMat = in_bst_channel(GlobalData.DataSet(iDS).ChannelFile); 
    % Import new file
    if isRaw
        [GlobalData.DataSet(iDS).Measures.sFile, newEvents] = import_events(GlobalData.DataSet(iDS).Measures.sFile, ChannelMat);
    else
        % Generate a sFile structure for an imported file
        sFile = in_fopen(GlobalData.DataSet(iDS).DataFile, 'BST-DATA');
        sFile.events = GlobalData.DataSet(iDS).Measures.sFile.events;
        % Import new file
        [sFile, newEvents] = import_events(sFile, ChannelMat);
        GlobalData.DataSet(iDS).Measures.sFile.events = sFile.events;
    end
    % Update events lists
    if ~isempty(newEvents)
        UpdateEventsList();
        UpdateEventsOccur();
        % Mark dataset as modified
        GlobalData.DataSet(iDS).Measures.isModified = 1;
        % Replot all the markers
        ReplotEvents();
    end
end


%% ===== SAVE MODIFICATIONS =====
% Save modifications performed on an open RAW file
function SaveModifications(iDS)
    global GlobalData;
    % Parse inputs
    if (nargin < 1)
        [iDS, isRaw] = GetCurrentDataset();
    else
        isRaw = strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'raw');
    end
    % If there is no events structure, there is nothing to save
    if isempty(GlobalData.DataSet(iDS).Measures.sFile)
        return; 
    end
    % Progress bar
    bst_progress('start', 'Raw file', 'Saving modifications...');
    % Update link to raw file
    if isRaw
        % Save bad channels
        GlobalData.DataSet(iDS).Measures.sFile.channelflag = GlobalData.DataSet(iDS).Measures.ChannelFlag;
        % Update sFile structure in file
        DataMat.F = GlobalData.DataSet(iDS).Measures.sFile;
    else
        % Update Events structure in file
        DataMat.Events = GlobalData.DataSet(iDS).Measures.sFile.events;
    end
    % Save modified fields
    if ~isempty(GlobalData.DataSet(iDS).DataFile)
        DataFile = file_fullpath(GlobalData.DataSet(iDS).DataFile);
        bst_save(DataFile, DataMat, 'v6', 1);
    else
        % Look for open figures
        for iMat = 1:length(GlobalData.DataSet(iDS).Matrix)
            DataFile = file_fullpath(GlobalData.DataSet(iDS).Matrix(iMat).FileName);
            bst_save(DataFile, DataMat, 'v6', 1);
        end
    end
    % Mark file as saved
    GlobalData.DataSet(iDS).Measures.isModified = 0;
    % Close progress bar
    bst_progress('stop');
end


%% ===== GET BAD SEGMENTS =====
% Returns all the bad segments in the file, in the format: 
%    [bad_start_1, bad_start_2, ...
%     bad_stop_1,  bad_stop_2, ...]
% This array contains the sample indices of all the bad segments in the file
function [badSeg, badEpochs, badTimes, badChan] = GetBadSegments(sFile, isChannelEvtBad) %#ok<DEFNU>
    % Parse inputs
    if (nargin < 2) || isempty(isChannelEvtBad)
        isChannelEvtBad = 1;
    end
    % Initialize empty list
    badSeg = [];
    badEpochs = [];
    badTimes = [];
    badChan = {};
    % Get all the events
    events = sFile.events;
    if isempty(events)
        return;
    end
    % Loop on all events
    for iEvt = 1:length(events)
        % Consider only the non-empty events that have the "bad" string in them
        if IsEventBad(events(iEvt).label) && ~isempty(events(iEvt).times)
            % Exclude all the channel-specific events
            if ~isChannelEvtBad && ~isempty(events(iEvt).channels)
                iOccBad = find(cellfun(@isempty, events(iEvt).channels));
                if isempty(iOccBad)
                    continue;
                end
            else
                iOccBad = 1:size(events(iEvt).times,2);
            end
            % If extended event
            if (size(events(iEvt).times,1) == 2)
                badTimes = [badTimes, events(iEvt).times(:,iOccBad)];
            % Else: single event
            else
                badTimes = [badTimes, repmat(events(iEvt).times(:,iOccBad), 2, 1)];
            end
            badEpochs = [badEpochs, events(iEvt).epochs(iOccBad)];
            % Get channel events
            if ~isempty(events(iEvt).channels)
                badChan = [badChan, events(iEvt).channels(iOccBad)];
            else
                badChan = [badChan, cell(1, length(iOccBad))];
            end
        end
    end
    badSeg = round(badTimes .* sFile.prop.sfreq);
end


%% ===== DETECT EVENTS =====
function CallProcessOnRaw(ProcessName)
    global GlobalData EditSspPanel;
    % Get raw dataset
    [iDS, isRaw] = GetCurrentDataset();
    if isempty(iDS)
        return;
    end
    % Check for read-only
    if bst_get('ReadOnly')
        java_dialog('warning', ['Read-only protocol:' 10 'Cannot run any process.'], 'Read-only');
        return;
    end
    % Save current modifications
    SaveModifications(iDS);
    % Get filename
    DataFile = GlobalData.DataSet(iDS).DataFile;
    % File time
    if isRaw
        FileTimeVector = GlobalData.FullTimeWindow.Epochs(GlobalData.FullTimeWindow.CurrentEpoch).Time;
    else
        FileTimeVector = bst_memory('GetTimeVector', iDS);
    end
    
    % === PRE-SELECT EVENT NAME ===
    % Only for SSP processes
    if ismember(ProcessName, {'ssp'})
        % Get selected event
        iEvent = GetSelectedEvents();
        % If one event selected: set it as the default for the process
        if (length(iEvent) == 1)
            % Get event (ignore current epoch)
            sEvent = GetEvents(iEvent, 1);
            % Get processing options
            ProcessOptions = bst_get('ProcessOptions');
            % Set the currently selected event as the default value for the selected process
            ProcessOptions.SavedParam.([ProcessName '__eventname']) = sEvent.label;
            % Save processing options
            bst_set('ProcessOptions', ProcessOptions);
        end
    end
    
    % === RUN PROCESS ===
    % Open process selection window
    [sOutputs, sProcesses] = panel_process_select('ShowPanel', DataFile, ProcessName, FileTimeVector);
    % Progress bar
    bst_progress('start', 'Detect events', 'Updating display...');
    % If there was an error: stop
    if isempty(sOutputs)
        bst_progress('stop');
        disp('BST> Process did not complete: not updating the display...');
        return;
    end
    
    % === UPDATE ===
    % Update loaded structure
    if isRaw
        % Update raw link (events and other information)
        DataMat = in_bst_data(DataFile, 'F');
        GlobalData.DataSet(iDS).Measures.sFile = DataMat.F;
        % Update channel mat
        ChannelMat = in_bst_channel(GlobalData.DataSet(iDS).ChannelFile);
        GlobalData.DataSet(iDS).Channel         = ChannelMat.Channel;
        GlobalData.DataSet(iDS).MegRefCoef      = ChannelMat.MegRefCoef;
        GlobalData.DataSet(iDS).Projector       = ChannelMat.Projector;
        GlobalData.DataSet(iDS).Clusters        = ChannelMat.Clusters;
        GlobalData.DataSet(iDS).IntraElectrodes = ChannelMat.IntraElectrodes;
    else
        DataMat = in_bst_data(DataFile, 'Events');
        GlobalData.DataSet(iDS).Measures.sFile.events = DataMat.Events;
    end
    % Update panel
    UpdatePanel();
    ReloadRecordings(1);
    ReplotEvents();

    % Only for SSP processes
    if ismember(ProcessName, {'process_ssp', 'process_ssp_eog', 'process_ssp_ecg', 'process_ica', 'process_eegref'})
        % Update SSP Selection interface
        if ~isempty(EditSspPanel)
            EditSspPanel.InitProjector = GlobalData.DataSet(iDS).Projector;
            EditSspPanel.Projector     = EditSspPanel.InitProjector;
            panel_ssp_selection('UpdateCat');
            panel_ssp_selection('UpdateComp');
        % If it is not open yet: Open SSP selection interface
        else 
            panel_ssp_selection('OpenRaw');
        end
        % Find the event type that was processed
        if ~isempty(sProcesses) && isfield(sProcesses(1).options, 'eventname') && ~isempty(sProcesses(1).options.eventname.Value)
            % Get all the events
            sEvents = GetEvents();
            % Find processed event
            iEvent = find(strcmpi({sEvents.label}, sProcesses(1).options.eventname.Value));
        else
            iEvent = [];
        end
    elseif ismember(ProcessName, {'process_evt_detect_ecg', 'process_evt_detect_eog', 'process_evt_detect'})
        % Select the last event type, that was supposedly just added
        sEvents = GetEvents();
        iEvent = length(sEvents);
    else
        iEvent = [];
    end
    % Select the event type that was processed
    if (length(iEvent) == 1)
        SetSelectedEvent(iEvent);
    end
    % Track changes for auto-pilot
    if (GlobalData.Program.GuiLevel == 2)
        global BstAutoPilot;
        BstAutoPilot.isDataModified = 1;
    end
    bst_progress('stop');
end


%% ===== FIX FILE LINK =====
% USAGE:  sFile = FixFileLink(DataFile)
%         sFile = FixFileLink(DataFile, sFile)
function sFile = FixFileLink(DataFile, sFile) %#ok<DEFNU>
    % Load sFile if not provided
    if (nargin < 2)
        MeasuresMat = in_bst_data(DataFile, 'F');
        sFile = MeasuresMat.F;
    end
    % File name
    [fPath, fBase, fExt] = bst_fileparts(sFile.filename);
    BaseName = [fBase, fExt];
    % Select new file
    NewFileName = java_getfile( 'open', 'Select continuous file', sFile.filename, 'single', 'files', ...
                            {{BaseName}, ['Current file: ' BaseName], 'CURRENT'; ...
                            {'*'},       'All files (*.*)',           'ALL'}, 1);
    % Empty selection
    if isempty(NewFileName)
        sFile = [];
        return;
    end
    % Update the main link
    sFile.filename = NewFileName;
    fNewPath = bst_fileparts(NewFileName);
    % Update the list of MEG4 files, in case of CTF recordings
    if strcmpi(sFile.format, 'CTF') || strcmpi(sFile.format, 'CTF-CONTINUOUS')
        for i = 1:length(sFile.header.meg4_files)
            [fPath, fBase, fExt] = bst_fileparts(sFile.header.meg4_files{i});
            sFile.header.meg4_files{i} = bst_fullfile(fNewPath, [fBase, fExt]);
        end
    end
    % Save modifications in file
    DataMat.F = sFile;
    bst_save(file_fullpath(DataFile), DataMat, 'v6', 1);
end


%% ===== DELETE RAW FILE =====
function DeleteRawFile(DataFile, isForce) %#ok<DEFNU>
    % Parse inputs
    if (nargin < 2) || isempty(isForce)
        isForce = 0;
    end
    % Get study
    [sStudy, iStudy] = bst_get('DataFile', DataFile);
    % Get native file
    DataMat = in_bst_data(DataFile, 'F');
    sFile = DataMat.F;
    % Get the files to delete
    if (strcmpi(sFile.format, 'CTF') || strcmpi(sFile.format, 'CTF-CONTINUOUS'))
        DsDir = bst_fileparts(sFile.filename);
        if strcmpi(DsDir(end-2:end), '.ds')
            RawFile = DsDir;
        else
            RawFile = sFile.filename;
        end
    else
        RawFile = sFile.filename;
    end
    % Delete the native file, with user confirmation
    if (file_delete(RawFile, isForce, 1) == 1)
        % Delete condition if there are no other data files in there
        if (length(sStudy.Data) == 1)
            % Delete study
            db_delete_studies(iStudy);
            % Update whole tree
            panel_protocols('UpdateTree');
        % Else: delete data file
        else
            % Delete link file
            file_delete(file_fullpath(DataFile), 1);
            % Reload 
            db_reload_studies(iStudy);
        end
    end
end


%% ===== COPY RAW TO DATABASE =====
% USAGE:  panel_record('CopyRawToDatabase', DataFiles)
function CopyRawToDatabase(DataFiles) %#ok<DEFNU>
    % Parse inputs
    if ischar(DataFiles)
        DataFiles = {DataFiles};
    end
    % Progress bar
    bst_progress('start', 'Copy to database', 'Load input files...', 0, 100 * length(DataFiles));
    % Loop on the input files
    for iFile = 1:length(DataFiles)
        % === READ INPUT ===
        % Progress bar
        bst_progress('set', 100 * (iFile-1));
        if (length(DataFiles) > 1)
            bst_progress('text', sprintf('Copying file [%d/%d]...', iFile, length(DataFiles)));
        else
            bst_progress('text', 'Copying...');
        end
        % Get study 
        [sStudy, iStudy, iData] = bst_get('DataFile', DataFiles{iFile});
        % Load Channel files
        ChannelFile = bst_get('ChannelFileForStudy', DataFiles{iFile});
        ChannelMat = in_bst_channel(ChannelFile);
        % Load sFile
        MeasuresMat = in_bst_data(DataFiles{iFile}, 'F', 'Comment');
        sFileIn = MeasuresMat.F;
        % Error management
        DataFileFull = file_fullpath(DataFiles{iFile});
        if ~isstruct(MeasuresMat.F) || file_compare(bst_fileparts(DataFileFull), bst_fileparts(sFileIn.filename))
            error('This function can be called only on external raw files.');
        end
        % Convert to CTF-CONTINUOUS if necessary
        if strcmpi(sFileIn.format, 'CTF') && (length(sFileIn.epochs) >= 2)
            sFileIn = process_ctf_convert('Compute', sFileIn, 'continuous');
        end
        % Prepare import options (do not apply any modifier)
        ImportOptions = db_template('ImportOptions');
        ImportOptions.ImportMode      = 'Time';
        ImportOptions.DisplayMessages = 0;
        ImportOptions.UseCtfComp      = 0;
        ImportOptions.UseSsp          = 0;
        ImportOptions.RemoveBaseline  = 'no';
        iEpoch = 1;

        % === CREATE OUTPUT FILE ===
        % Output file name derives from the folder name
        rawPath = bst_fileparts(DataFileFull);
        [tmp, rawBase] = bst_fileparts(rawPath);
        RawFileOut = bst_fullfile(rawPath, [strrep(rawBase, '@raw', ''), '.bst']);
        % Create an empty Brainstorm-binary file  
        [sFileOut, errMsg] = out_fopen(RawFileOut, 'BST-BIN', sFileIn, ChannelMat);
        % Error management
        if isempty(sFileOut) && ~isempty(errMsg)
            error(errMsg);
        elseif ~isempty(errMsg)
            disp(['BST> Warning: ' errMsg]);
        end

        % === COPY FILE CONTENTS ===
        % Get maximum size of a data block
        ProcessOptions = bst_get('ProcessOptions');
        MaxSize = ProcessOptions.MaxBlockSize;
        % Split in time blocks
        nChannels = length(ChannelMat.Channel);
        nTime     = round((sFileOut.prop.times(2) - sFileOut.prop.times(1)) .* sFileOut.prop.sfreq) + 1;
        BlockSize = max(floor(MaxSize / nChannels), 1);
        nBlocks   = ceil(nTime / BlockSize);
        % Loop on blocks
        for iBlock = 1:nBlocks
            bst_progress('set', 100*(iFile-1) + round(100*iBlock/nBlocks));
            % Indices of columns to process
            SamplesBounds = round(sFileIn.prop.times(1) * sFileOut.prop.sfreq) + [(iBlock-1)*BlockSize, min(iBlock * BlockSize - 1, nTime - 1)];
            % Read one channel
            F = in_fread(sFileIn, ChannelMat, iEpoch, SamplesBounds, [], ImportOptions);
            % Write block
            sFileOut = out_fwrite(sFileOut, ChannelMat, iEpoch, SamplesBounds, [], F);
        end

        % === UPDATE DATABASE ===
        % Save modifications in file structure
        newMat.F = sFileOut;
        newMat.Comment = [MeasuresMat.Comment ' | copy'];
        bst_save(DataFileFull, newMat, 'v6', 1);
        % Update database
        sStudy.Data(iData).Comment = newMat.Comment;
        bst_set('Study', iStudy, sStudy);
        % Update tree display
        panel_protocols('UpdateNode', 'Study', iStudy);
    end
    % Close progress bar
    bst_progress('stop');
end


%% ===== SET ACQUISITION DATE =====
function SetAcquisitionDate(iStudy, newDate) %#ok<DEFNU>
    % Parse inputs
    if (nargin < 2) || isempty(newDate)
        newDate = [];
    end
    % Get data info
    sStudy = bst_get('Study', iStudy);
    if isempty(sStudy)
        return;
    end
    % Parse existing string
    oldDate = [1900, 1, 1];
    if ~isempty(sStudy.DateOfStudy)
        try
            oldDate = datevec(sStudy.DateOfStudy);
        catch
        end
    end
    % If new date is not given in argument: ask user
    if isempty(newDate)
        % Ask for new date
        res = java_dialog('input', {'Day:', 'Month:', 'Year:'}, 'Set date', [], {num2str(oldDate(3)), num2str(oldDate(2)), num2str(oldDate(1))});
        if isempty(res) || (length(res) < 3)
            return;
        end
        vecDate = [str2num(res{1}), str2num(res{2}), str2num(res{3})];
        try
            if (length(vecDate) < 3) || (vecDate(3) < 1700)
                error('Invalid year');
            end
            % Get a new date string
            newDate = datetime(sprintf('%02d%02d%04d', vecDate), 'InputFormat', 'ddMMyyyy');
        catch
            bst_error('Invalid date.', 'Set date', 0);
            return;
        end
    else
        % Fix data format
        newDate = str_date(newDate);
        if isempty(newDate)
            error('Invalid date format. Input must be ''DD-MMM-YYYY''.');
        end
    end
    % If the date didn't change: exit
    if strcmpi(newDate, sStudy.DateOfStudy)
        return;
    end
    % Save acquisition data in study file
    StudyFile = file_fullpath(sStudy.FileName);
    StudyMat = load(StudyFile);
    StudyMat.DateOfStudy = newDate;
    bst_save(StudyFile, StudyMat, 'v7');
    % Update database representation
    sStudy.DateOfStudy = newDate;
    bst_set('Study', iStudy, sStudy);
    % Update raw links if applicable
    if ~isempty(strfind(sStudy.FileName, '@raw')) && ~isempty(sStudy.Data) && strcmpi(sStudy.Data(1).DataType, 'raw')
        % Read link
        DataMat = in_bst_data(sStudy.Data(1).FileName, 'F');
        DataMat.F.acq_date = newDate;
        % Save modified link
        bst_save(file_fullpath(sStudy.Data(1).FileName), DataMat, 'v6', 1);
    end
    % Refresh tree
    panel_protocols('UpdateTree');
    panel_protocols('SelectNode', [], sStudy.FileName);
end


%% ===== CHANGE TIME VECTOR =====
function events = ChangeTimeVector(events, OldFreq, NewTime) %#ok<DEFNU>
    % Get new sampling frequency
    NewFreq = 1 ./ (NewTime(2) - NewTime(1));
    % Process each event
    iRmEvents = [];
    for iEvt = 1:length(events)
        % Find the events outside the selected time window
        if (size(events(iEvt).times,1) == 2) 
            % Extended events
            iOut = find((events(iEvt).times(2,:) < NewTime(1)) | (events(iEvt).times(1,:) > NewTime(end)));
        else
            % Simple events
            iOut = find((events(iEvt).times < NewTime(1)) | (events(iEvt).times > NewTime(end)));
        end
        % Remove those outsiders
        if ~isempty(iOut)
            events(iEvt).times(:,iOut)  = [];
            events(iEvt).epochs(iOut)   = [];
            if ~isempty(events(iEvt).channels)
                events(iEvt).channels(iOut) = [];
            end
            if ~isempty(events(iEvt).notes)
                events(iEvt).notes(iOut) = [];
            end
            if ~isempty(events(iEvt).reactTimes)
                events(iEvt).reactTimes(iOut) = [];
            end
        end
        % Ignore empty events
        if isempty(events(iEvt).times)
            iRmEvents(end+1) = iEvt;
            continue;
        end
        % If the frequency was changed: update the events times
        if (abs(OldFreq - NewFreq) > 0.05)
            events(iEvt).times = round(events(iEvt).times * NewFreq) / NewFreq;
        end
    end
    % Delete empty events
    if ~isempty(iRmEvents)
        events(iRmEvents) = [];
    end
end


%% ===== IS EVENT BAD =====
function isBad = IsEventBad(evtLabel)
    evtLabel = lower(evtLabel);
    isBad = strcmpi(evtLabel, 'bad') || ...
            ~isempty(strfind(evtLabel, 'bad ')) || ...
            ~isempty(strfind(evtLabel, 'bad_')) || ...
            ~isempty(strfind(evtLabel, '_bad')) || ...
            ~isempty(strfind(evtLabel, ' bad'));
end


%% ===== JUMP TO VIDEO TIME =====
% USAGE:  JumpToVideoTime(hFig, oldVideoTime=[], newVideoTime=[ask])
function JumpToVideoTime(hFig, oldVideoTime, newVideoTime)
    global GlobalData;
    if isempty(GlobalData) || isempty(GlobalData.DataSet)
        return;
    end
    % Parse inputs
    if (nargin < 2) || isempty(oldVideoTime)
        oldVideoTime = [];
    end
    % Ask what time to set 
    if (nargin < 3) || isempty(newVideoTime)
        % Do not ask for the frame
        strVideo = java_dialog('input', 'Jump to video time (HHMMSSFF):', 'Video time', [], sprintf('%08d', floor(oldVideoTime)));
        if isempty(strVideo) || isempty(str2num(strVideo))
            return;
        end
        % Add the frame index (HHMMSSFF)
        newVideoTime = str2num(strVideo);
    end

    % Progress bar
    bst_progress('start', 'Video time', 'Reading video channel');
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    % Get file descriptor
    sFile = GlobalData.DataSet(iDS).Measures.sFile;
    % Get the video channel
    iVideo = find(strcmpi({GlobalData.DataSet(iDS).Channel.Type}, 'Video'), 1);
    % Load channel file
    ChannelMat = in_bst_channel(GlobalData.DataSet(iDS).ChannelFile);
    % Read all the values for this channel
    [F, TimeVector] = in_fread(sFile, ChannelMat, 1, [], iVideo);
    % Remove all the zero values
    iZero = find(F == 0);
    F(iZero) = [];
    TimeVector(iZero) = [];
    % Find the closest available video time
    iTime = bst_closest(newVideoTime, F);
    % Select the event time
    panel_time('SetCurrentTime', TimeVector(iTime));
    % Close progress bar
    bst_progress('stop');
end
