function varargout = panel_import_data(varargin)
% PANEL_IMPORT_DATA: Import recordings in database (GUI).
%
% USAGE: [bstPanelNew, panelName] = panel_import_data('CreatePanel', sFile, ChannelMat)
%                   panelContents = panel_import_data('GetPanelContents')
% INPUT:
%   - sFile: Brainstorm structure that describes an open file, created by in_fopen.m 
%            See db_template.m for a description of the fields

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
function [bstPanelNew, panelName] = CreatePanel(sFile, ChannelMat) %#ok<DEFNU>
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.icon.*;
    panelName = 'ImportDataOptions';
    % Constants
    DEFAULT_HEIGHT = 20;
    TEXT_WIDTH     = 55;
    TIME_WIDTH     = 65;
    jFontText = bst_get('Font', 10);
    
    % Create main panel
    jPanelNew = gui_component('Panel');
    % Create pre-processing panel
    jPanelProcess = gui_river(); 
    jPanelNew.add(jPanelProcess, BorderLayout.EAST);
    % Events or markers selection ?
    isEvents = ~isempty(sFile.events);
    isEpochs = ~isempty(sFile.epochs) && (length(sFile.epochs) > 1);
    % Get number of time samples
    nSamples = round((sFile.prop.times(2) - sFile.prop.times(1)) .* sFile.prop.sfreq) + 1;
    % Propose to split the file the number of samples is big enough
    isSplitPanel = ~isEpochs && (nSamples > 100);
    % If several panels on both sides (time and pre-processing): Display in separate panels
    if isEvents || isEpochs || isSplitPanel
        jPanelData = gui_river(); 
        jPanelNew.add(jPanelData, BorderLayout.CENTER);
    % Else: put everything in the same panel
    else
        jPanelData = jPanelProcess;
    end
    % Get saved import options
    ImportDataOptions = bst_get('ImportDataOptions');

    % Initialize controls that might not be defined
    jLabelEventsInfo = [];
    jCheckSplit      = [];
    jCheckUseEvents  = [];
    jTextTimeStart   = [];
    jTextTimeStop    = [];
    jCheckSplit      = [];
    jTextBlockLength = [];
    jListEpochs      = [];
    jCheckAllEpochs  = [];
    jListEvents      = [];
    TimeUnit = 'ms';
    tic
    
    % ===== TIME SELECTION PANEL =====
    % Get global time values
    TimeVector = panel_time('GetRawTimeVector', sFile);
    SelTimeBounds = [TimeVector(1), TimeVector(end)];
    % RAW FILES (no epochs)
    if ~isEpochs
        % === RAW TIME WINDOW ===
        % Time selection panel
        jPanelTime = gui_river([2 0], [0 10 10 10], 'Time selection');
            % Time range : start
            jPanelTime.add('br', JLabel('Time window: '));
            jTextTimeStart = JTextField('');
            jTextTimeStart.setPreferredSize(java_scaled('dimension', TIME_WIDTH, DEFAULT_HEIGHT));
            jTextTimeStart.setHorizontalAlignment(JTextField.RIGHT);
            jTextTimeStart.setFont(jFontText);
            jPanelTime.add(jTextTimeStart);
            % Time range : stop
            jPanelTime.add(JLabel('-'));
            jTextTimeStop = JTextField('');
            jTextTimeStop.setPreferredSize(java_scaled('dimension', TIME_WIDTH, DEFAULT_HEIGHT));
            jTextTimeStop.setHorizontalAlignment(JTextField.RIGHT);
            jTextTimeStop.setFont(jFontText);
            jPanelTime.add('tab', jTextTimeStop);
            % Set time controls callbacks
            TimeUnit = gui_validate_text(jTextTimeStart, [], jTextTimeStop, TimeVector, 'time', [], SelTimeBounds(1), @UpdateTimeSelection);
            TimeUnit = gui_validate_text(jTextTimeStop, jTextTimeStart, [], TimeVector, 'time', [], SelTimeBounds(2), @UpdateTimeSelection);
            % Add unit label
            jPanelTime.add(JLabel([' ' TimeUnit]));
        jPanelData.add('br hfill', jPanelTime);

        % === SPLIT IN SMALL BLOCKS ===
        % Only if more than 2000 samples 
        if isSplitPanel
            jPanelTimeSplit = gui_river([2 0], [0 10 10 10], 'Split');
            % Split checkbox
            jCheckSplit = JCheckBox('Split in time blocks of: ');
            java_setcb(jCheckSplit, 'ActionPerformedCallback', @RawSplit_Callback);
            jPanelTimeSplit.add(jCheckSplit);
            % Split block length
            jTextBlockLength = JTextField('4');
            jTextBlockLength.setPreferredSize(java_scaled('dimension', TIME_WIDTH, DEFAULT_HEIGHT));
            jTextBlockLength.setHorizontalAlignment(JTextField.RIGHT);
            jTextBlockLength.setFont(jFontText);
            java_setcb(jTextBlockLength, 'ActionPerformedCallback', @TimeValidationSplit_Callback, ...
                                  'FocusLostCallback',       @TimeValidationSplit_Callback);
            jPanelTimeSplit.add('tab', jTextBlockLength);
            % "Seconds" label
            jLabelSeconds = JLabel(' s');
            jPanelTimeSplit.add(jLabelSeconds);
            % "Number of blocks" label
            jLabelNbBlocksTitle = JLabel('       Number of blocks:');
            jPanelTimeSplit.add('br', jLabelNbBlocksTitle);
            % Nb samples / block
            jLabelNbBlocks = JLabel('5');
            jLabelNbBlocks.setPreferredSize(java_scaled('dimension', 35, DEFAULT_HEIGHT));
            jLabelNbBlocks.setHorizontalAlignment(JTextField.LEFT);
            jPanelTimeSplit.add('tab hfill', jLabelNbBlocks);
            jPanelData.add('br hfill', jPanelTimeSplit);
        end
    end
    
    % ===== EPOCHS SELECTION =====
    % Only if EVOKED file
    if isEpochs
        nbEpochs = length(sFile.epochs);
        jPanelEpochs = gui_river([2 3], [0 10 -10 10], 'Epochs');
        % Checckbox all epochs
        jCheckAllEpochs = JCheckBox('Get all epochs              ');
        java_setcb(jCheckAllEpochs, 'ActionPerformedCallback', @GetAllEpochs_Callback);
        jPanelEpochs.add(jCheckAllEpochs);
        % List Epochs
        jListEpochs = JList({'LIST OF AVAILABLE EPOCHS', '1', '2', '3', '4', '5', '6', '7', '8', '9'});
        jListEpochs.setToolTipText('Select the epochs to be extracted.');
        
        jScrollListEpochs = JScrollPane(jListEpochs);
        jPanelEpochs.add('br hfill vfill', jScrollListEpochs);
        % Extend vertically only if no events
        if isEvents
            jPanelData.add('br hfill', jPanelEpochs);
        else
            jPanelData.add('br hfill vfill', jPanelEpochs);
        end
    end
   
    % ===== EVENTS PANEL =====
    % ONLY RAW, WITH EVENTS
    if ~isempty(sFile.events)
        % Selection panel
        jPanelEvents = gui_river([2 3], [0 10 -10 10], 'Events selection');
            % === EVENTS SELECTION PANEL ===
            % "Use event" checkbox
            jCheckUseEvents = JCheckBox('Use events');
            java_setcb(jCheckUseEvents, 'ActionPerformedCallback', @UseEvents_Callback);
            jPanelEvents.add(jCheckUseEvents);
            % Line separator
            jPanelEvents.add('hfill', JLabel(' '));
            % Load events file button
            jButtonLoadEvents = JButton(IconLoader.ICON_FOLDER_OPEN);
            jButtonLoadEvents.setPreferredSize(java_scaled('dimension', 23,23));
            jButtonLoadEvents.setEnabled(0);
            jPanelEvents.add(jButtonLoadEvents);
            % Save events file button
            jButtonSaveEvents = JButton(IconLoader.ICON_SAVE);
            jButtonSaveEvents.setPreferredSize(java_scaled('dimension', 23,23));
            jButtonSaveEvents.setEnabled(0);
            jPanelEvents.add(jButtonSaveEvents);
            % List events
            jListEvents = JList({'LIST OF AVAILABLE EVENTS', '1', '2', '3', '4', '5', '6', '7', '8', '9','10','11'});  
            jScrollListEvents = JScrollPane(jListEvents);           
            jPanelEvents.add('br hfill vfill', jScrollListEvents);
            
            % Time range : start
            jLabelEpoch = JLabel('Epoch time: ');
            jPanelEvents.add('br', jLabelEpoch);
            jTextEventsTimeStart = JTextField('');
            jTextEventsTimeStart.setToolTipText('Imported time window around the event (0 represents the event).');
            jTextEventsTimeStart.setPreferredSize(java_scaled('dimension', TEXT_WIDTH, DEFAULT_HEIGHT));
            jTextEventsTimeStart.setHorizontalAlignment(JTextField.RIGHT);
            jTextEventsTimeStart.setFont(jFontText);
            jPanelEvents.add(jTextEventsTimeStart);
            % Time range : stop
            jPanelEvents.add(JLabel(' - '));
            jTextEventsTimeStop = JTextField('');
            jTextEventsTimeStop.setToolTipText('Imported time window around the event (0 represents the event).');
            jTextEventsTimeStop.setPreferredSize(java_scaled('dimension', TEXT_WIDTH, DEFAULT_HEIGHT));
            jTextEventsTimeStop.setHorizontalAlignment(JTextField.RIGHT);
            jTextEventsTimeStop.setFont(jFontText);
            jPanelEvents.add(jTextEventsTimeStop);
            % Set callbacks
            TimeBoundsEvents = {-500, 500, sFile.prop.sfreq};
            gui_validate_text(jTextEventsTimeStart, [], jTextEventsTimeStop, TimeBoundsEvents, 'ms', [], ImportDataOptions.EventsTimeRange(1), @UpdateBaselineDefault);
            gui_validate_text(jTextEventsTimeStop, jTextEventsTimeStart, [], TimeBoundsEvents, 'ms', [], ImportDataOptions.EventsTimeRange(2), @UpdateBaselineDefault);
            TimeUnitBl = [];
            % Display units: ms
            jLabelTimeUnitsEvents = JLabel(' ms');
            jPanelEvents.add(jLabelTimeUnitsEvents);

            % Get all reaction times
            reactTimes = [sFile.events.reactTimes];
            % Label for extra information on reaction times
            if ~isempty(reactTimes) && any(reactTimes ~= 0)
                jLabelEventsInfo = JLabel('');
                jPanelEvents.add('br', jLabelEventsInfo);
            end
        if isEvents
            jPanelData.add('br hfill vfill', jPanelEvents);
        end
    end

    % ===== SENSORS DEFINITION =====
    jPanelSensors = gui_river([0 3], [0 13 10 0], 'Artifact cleaning');
        % Get all sensor types
        if isfield(ChannelMat, 'Channel') && ~isempty(ChannelMat.Channel) && isfield(ChannelMat.Channel, 'Type')
            AllTypes = {ChannelMat.Channel.Type};
            AllTypes(cellfun(@isempty,AllTypes)) = [];
            isMeg = ~isempty(AllTypes) && any(ismember(AllTypes, {'MEG','MEG GRAD','MEG MAG'}));
        else
            isMeg = 0;
        end
        % === WARNING ===
        isCtfCompCheck  = isfield(ChannelMat, 'MegRefCoef') && ~isempty(ChannelMat.MegRefCoef) && ~isempty(sFile.prop.currCtfComp) && (sFile.prop.currCtfComp == 0);
        isSspCheck      = isfield(ChannelMat, 'Projector') && ~isempty(ChannelMat.Projector);
        isCtfRecordings = isMeg && ~isempty(sFile.prop.currCtfComp);
        % If it is CTF recordings: display current compensation level
        if isCtfRecordings
            jPanelSensors.add(JLabel(sprintf('Current CTF compensation: %d', sFile.prop.currCtfComp)));
        end
        % === CTF COMPENSATORS ===
        % CTF compensators checkbox
        if isCtfCompCheck
            jCheckCtfComp = JCheckBox('Use CTF compensation');
            jPanelSensors.add('br', jCheckCtfComp);    
        else
            jCheckCtfComp = [];
        end
        % === SSP PROJECTIONS ===
        % SSP Checkbox
        if isSspCheck
            % Count active / inactive projectors
            nApplied = 0;
            nActive = 0;
            nTotal = 0;
            for iProj = 1:length(ChannelMat.Projector)
                if (ChannelMat.Projector(iProj).Status == 2)
                    nApplied = nApplied + 1;
                elseif (ChannelMat.Projector(iProj).Status == 1)
                    nActive = nActive + 1;
                end
                if (ChannelMat.Projector(iProj).Status >= 1)
                    if ~isempty(ChannelMat.Projector(iProj).CompMask)
                        nTotal = nTotal + nnz(ChannelMat.Projector(iProj).CompMask);
                    else
                        nTotal = nTotal + 1;
                    end
                end
            end
            nInactive = length(ChannelMat.Projector) - nActive - nApplied;
            % Create labels to report the active/inactive projectors
            if (nActive > 0)
                jCheckSsp = gui_component('checkbox', jPanelSensors, 'br', 'Apply SSP/ICA projectors', [], [], @UseSspCheckBox_Callback, []);
                jLabelSspTotal = gui_component('label', jPanelSensors, [], sprintf('<HTML>Total projectors: <B>%d</B>', nTotal), [], [], [], []);
                jLabelSspTotal.setBorder(BorderFactory.createEmptyBorder(0,35,0,0));
                jLabelSspDetail = gui_component('label', jPanelSensors, 'br', sprintf('Projector categories: %d active / %d inactive / %d applied', nActive, nInactive, nApplied), [], [], [], []);
                jLabelSspDetail.setBorder(BorderFactory.createEmptyBorder(0,20,0,0));
            else
                jCheckSsp = [];
                gui_component('label', jPanelSensors, 'br', sprintf('<HTML>SSP categories: %d active / %d inactive / %d applied', nActive, nInactive, nApplied), [], [], [], []);
                gui_component('label', jPanelSensors, 'br', sprintf('<HTML>Total SSP projectors: <B>%d</B>', nTotal), [], [], [], []);

            end
        else
            jCheckSsp = [];
        end
    if isCtfCompCheck || isSspCheck || isCtfRecordings
        jPanelProcess.add('br hfill', jPanelSensors);
    end

    
    % ===== PRE PROCESSING =====
    jPanelPreprocess = gui_river([0 3], [0 13 10 0], 'Pre-processing');
        % === REMOVE DC OFFSET ===
        % DC Offset checkbox
        jCheckBaseline = JCheckBox('Remove DC offset: select baseline definition', 0);
        java_setcb(jCheckBaseline, 'ActionPerformedCallback', @BaselineCheckBox_Callback);
        jPanelPreprocess.add('br', jCheckBaseline);
        % Baseline radiobuttons
        buttonGroupBaseline = ButtonGroup();
        % All the recordings
        jPanelPreprocess.add('br', JLabel('     '));
        jRadioBaselineAll  = JRadioButton('All recordings: Baseline computed for each output file', 1);
        java_setcb(jRadioBaselineAll, 'ActionPerformedCallback', @BaselineCheckBox_Callback);
        buttonGroupBaseline.add(jRadioBaselineAll);
        jPanelPreprocess.add(jRadioBaselineAll);
        
        % === REMOVE TIME RANGE ===
        jPanelPreprocess.add('br', JLabel('     '));
        % Radio button
        jRadioBaselineTime = JRadioButton('Time range: ');
        java_setcb(jRadioBaselineTime, 'ActionPerformedCallback', @BaselineCheckBox_Callback);
        buttonGroupBaseline.add(jRadioBaselineTime);
        jPanelPreprocess.add(jRadioBaselineTime);
        % Noise Normalization : Baseline START
        jTextBlTimeStart = JTextField('');
        jTextBlTimeStart.setPreferredSize(java_scaled('dimension', TIME_WIDTH, DEFAULT_HEIGHT));
        jTextBlTimeStart.setHorizontalAlignment(JTextField.RIGHT);
        jTextBlTimeStart.setFont(jFontText);
        jPanelPreprocess.add('tab', jTextBlTimeStart);
        % Noise Normalization : Baseline STOP
        jPanelPreprocess.add(JLabel(' - '));
        jTextBlTimeStop = JTextField('');
        jTextBlTimeStop.setPreferredSize(java_scaled('dimension', TIME_WIDTH, DEFAULT_HEIGHT));
        jTextBlTimeStop.setHorizontalAlignment(JTextField.RIGHT);
        jTextBlTimeStop.setFont(jFontText);
        jPanelPreprocess.add(jTextBlTimeStop);
        % Add unit
        jLabelBlUnit = JLabel();
        jPanelPreprocess.add(jLabelBlUnit);

        % === RESAMPLE ===
        % Resample checkbox
        jCheckResample = JCheckBox('Resample recordings:', 0);
        java_setcb(jCheckResample, 'ActionPerformedCallback', @ResampleCheckBox_Callback);
        jPanelPreprocess.add('p', jCheckResample);
        % New sampling rate 
        jTextSampleRate = JTextField('1000');
        jTextSampleRate.setPreferredSize(java_scaled('dimension', TEXT_WIDTH, DEFAULT_HEIGHT));
        jTextSampleRate.setHorizontalAlignment(JTextField.RIGHT);
        jTextSampleRate.setFont(jFontText);
        java_setcb(jTextSampleRate, 'ActionPerformedCallback', @SampleRateValidation_Callback, ...
                                    'FocusLostCallback',       @SampleRateValidation_Callback);
        jPanelPreprocess.add(jTextSampleRate);
        % Label "Hz"
        jLabelHz = JLabel(' Hz');
        jPanelPreprocess.add(jLabelHz);
        % Sampling frequency
        jLabelResample = JLabel(['<HTML><FONT COLOR="#B0B0B0"> Sampling: ' num2str(sFile.prop.sfreq) ' Hz&nbsp;&nbsp;</FONT>']);
        jLabelResample.setHorizontalAlignment(jLabelResample.RIGHT);
        jPanelPreprocess.add('hfill', jLabelResample);
    jPanelProcess.add('br hfill', jPanelPreprocess);
    
    % ===== DATABASE =====
    jPanelDatabase = gui_river([0 0], [0 13 5 0], 'Database');       
        % === CREATE CONDITIONS ===
        jCheckCreateCond = JCheckBox('Create a separate folder for each event type', 1);
        jPanelDatabase.add('br', jCheckCreateCond);
    jPanelProcess.add('br hfill', jPanelDatabase);
    
    % ===== VALIDATION BUTTONS =====
    % Separator
    jPanelSep = java_create('javax.swing.JPanel');
    jPanelSep.add(JLabel(' '));
    jPanelProcess.add('br hfill vfill', jPanelSep);
    % Cancel
    jButtonCancel = JButton('Cancel');
    java_setcb(jButtonCancel, 'ActionPerformedCallback', @ButtonCancel_Callback);
    jPanelProcess.add('br right', jButtonCancel);
    % Reset
    jButtonReset = JButton('Reset');
    java_setcb(jButtonReset, 'ActionPerformedCallback', @ButtonReset_Callback);
    jPanelProcess.add(jButtonReset);
    % Save
    jButtonSave = JButton('Import');
    java_setcb(jButtonSave, 'ActionPerformedCallback', @ButtonImport_Callback);
    jPanelProcess.add(jButtonSave);

    % Load inputs and saved options
    LoadFile();
    LoadOptions();
    drawnow;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % NEED TO SET THE JLIST CALLBACKS AFTER LOADING
    % IF NOT: IN CASE OF NEUROSCAN .EEG: FIRES TONS OF EVENTS......
    if ~isempty(jListEpochs)
        java_setcb(jListEpochs, 'ValueChangedCallback', @EpochsSelectionChanged_Callback);
    end
    if ~isempty(jListEvents)
        java_setcb(jListEvents, 'ValueChangedCallback', @EventsSelectionChanged_Callback);
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jListEpochs',      jListEpochs, ...
                                  'jCheckAllEpochs',  jCheckAllEpochs, ...
                                  'jListEvents',      jListEvents, ...
                                  'jCheckSplit',      jCheckSplit, ...
                                  'jCheckUseEvents',  jCheckUseEvents, ...
                                  'jTextTimeStart',   jTextTimeStart, ...
                                  'jTextTimeStop',    jTextTimeStop, ...
                                  'jTextBlockLength', jTextBlockLength, ...
                                  'jCheckBaseline',   jCheckBaseline, ...
                                  'jTextBlTimeStart', jTextBlTimeStart, ...
                                  'jTextBlTimeStop',  jTextBlTimeStop, ...
                                  'jLabelBlUnit',     jLabelBlUnit, ...
                                  'jCheckResample',   jCheckResample, ...
                                  'jTextSampleRate',  jTextSampleRate, ...
                                  'jCheckCtfComp',    jCheckCtfComp, ...
                                  'jCheckCreateCond', jCheckCreateCond, ...
                                  'jCheckSsp',        jCheckSsp, ...
                                  'TimeUnit',         TimeUnit, ...
                                  'TimeUnitBl',       TimeUnitBl, ...
                                  'sFile',            sFile));
              
                               

%% =================================================================================
%  === CONTROLS CALLBACKS  =========================================================
%  =================================================================================

%% ===== UPDATE TIME SELECTION =====
    function UpdateTimeSelection(varargin)
        % If should not be called: ignore
        if isempty(jTextTimeStart)
            return
        end
        % Save old value
        oldTimeBounds = SelTimeBounds;
        % Get new values
        SelTimeBounds = [str2double(char(jTextTimeStart.getText())), ...
                         str2double(char(jTextTimeStop.getText()))];
        % Convert to ms
        if strcmpi(TimeUnit, 'ms')
            SelTimeBounds = SelTimeBounds ./ 1000;
        end
        % If it changed: update panel
        if ~isequal(oldTimeBounds, SelTimeBounds)
            UpdateSamplesPerBlock();
            UpdateEventsList();
            UpdateBaselineDefault();
        end
    end

%% ===== TIME VALIDATION: SPLIT =====
    function TimeValidationSplit_Callback(varargin)
        % Get and check value
        value = str2double(char(jTextBlockLength.getText()));
        isValidated = ~isnan(value) && ~isempty(value);
        % Convert to seconds and saturate, or define default values
        if isValidated
            if (value < 0.1)
                value = 0.1;
            end
        else
            value = 4;
        end
        % Set focus to panel container panel
        jTextBlockLength.getParent().grabFocus();
        % Update control text
        jTextBlockLength.setText(sprintf('%1.4f', value));
        % Update number of samples per block
        UpdateSamplesPerBlock();
    end


%% ===== VALIDATION: SAMPLE RATE =====
    function SampleRateValidation_Callback(varargin)
        % Get and check value
        value = str2double(char(jTextSampleRate.getText()));
        if isnan(value) || isempty(value) || (value <= 0)
            value = sFile.prop.sfreq;
        end
        % Set focus to panel container panel
        jTextSampleRate.getParent().grabFocus();
        % Update control text
        jTextSampleRate.setText(sprintf('%1.2f', value));
    end


%% ===== UPDATE SAMPLES PER BLOCK =====
    function UpdateSamplesPerBlock()
        if ~isempty(jTextBlockLength)
            % Get block length
            blockLength = str2double(char(jTextBlockLength.getText()));
            if isempty(blockLength) || isnan(blockLength)
                return
            end
            % Compute number of blocks
            TimeInterval = SelTimeBounds(2) - SelTimeBounds(1);
            if strcmpi(TimeUnit, 'ms')
                TimeInterval = TimeInterval / 1000;
            end
            nbBlocks = ceil(TimeInterval / blockLength);
            % Update controls 
            jLabelNbBlocks.setText(sprintf('%d', nbBlocks));
        end
    end

%% ===== CHECKBOX: SPLIT =====
    function RawSplit_Callback(varargin)
        if ~isempty(jCheckSplit)
            isSplit = jCheckSplit.isSelected();
            % Enable/disable split controls
            gui_enable([jTextBlockLength, jLabelSeconds, jLabelNbBlocksTitle, jLabelNbBlocks], isSplit, 0);
            % Unselect USE EVENTS option
            if isSplit && ~isempty(jCheckUseEvents) && jCheckUseEvents.isSelected()
                jCheckUseEvents.setSelected(0);
                UseEvents_Callback();
            end
        end
    end

%% ===== CHECKBOX: USE EVENTS =====
    function UseEvents_Callback(varargin)
        isEventsSel = ~isempty(jCheckUseEvents) && jCheckUseEvents.isSelected();
        % Enable/disable events selection
        gui_enable([jListEvents, jLabelEpoch, jTextEventsTimeStart, jTextEventsTimeStop, jLabelTimeUnitsEvents], isEventsSel, 0);
        % Unselect Split option
        if isEventsSel && ~isempty(jCheckSplit) && jCheckSplit.isSelected()
            jCheckSplit.setSelected(0);
            RawSplit_Callback();
        end
        % === Update events list ===
        UpdateEventsList();
        UpdateBaselineDefault();
        % UpdateDefaultCreateCond();
    end

%% ===== CHECKBOX: USE ALL EPOCHS ======
    function GetAllEpochs_Callback(varargin)
        isAllEpochs = jCheckAllEpochs.isSelected();
        % Enable/disable epochs list
        gui_enable(jListEpochs, ~isAllEpochs, 0);
        % Selection
        cb = java_getcb(jListEpochs, 'ValueChangedCallback');
        drawnow
        if isAllEpochs
            jListEpochs.setSelectedIndices(-1);
        else
            iSelEpoch = find([sFile.epochs.select]);
            jListEpochs.setSelectedIndices(iSelEpoch - 1);
        end
        drawnow
        java_setcb(jListEpochs, 'ValueChangedCallback', cb);
        
        UpdateBaselineDefault();
    end

%% ===== CHECKBOX: RESAMPLE =====
    function ResampleCheckBox_Callback(varargin)
        isResample = jCheckResample.isSelected();
        isBaseline = jCheckBaseline.isSelected();
        % Enable/disable time selection
        gui_enable([jTextSampleRate, jLabelHz], isResample, 0);
        % Select also baseline removal if not selected yet
        if isResample && ~isBaseline
            jCheckBaseline.setSelected(1);
            BaselineCheckBox_Callback();
        end
    end

%% ===== CHECKBOX: REMOVE BASELINE =====
    function BaselineCheckBox_Callback(varargin)
        isResample = jCheckResample.isSelected();
        isBaseline = jCheckBaseline.isSelected();
        isBaselineTime = isBaseline && jRadioBaselineTime.isSelected();
        % Display warning if trying to uncheck Baseline if Resample is checked
        if isResample && ~isBaseline
            res = java_dialog('confirm', ['Warning: Baseline removal is recommended before resampling.' 10 10 ...
                                          'Matlab function "resample" creates important artifacts in ' 10 ...
                                          'the recordings if the average of each channel is not zero.' 10 10 ...
                                          'Are you sure you want to disable this option ?' 10 10], ...
                                          'Remove DC offset');
            if ~res
                jCheckBaseline.setSelected(1);
                return
            end
        end
        % Enable/disable all controls
        gui_enable([jRadioBaselineAll, jRadioBaselineTime], isBaseline, 0);
        gui_enable([jTextBlTimeStart, jTextBlTimeStop],   isBaselineTime, 0);
    end


%% ===== CHECKBOX: USE SSP =====
    function UseSspCheckBox_Callback(varargin)
        isSSP = jCheckSsp.isSelected();
        gui_enable([jLabelSspTotal, jLabelSspDetail], isSSP, 0);
    end


%% ===== JLIST: EPOCH SELECTION =====
    function EpochsSelectionChanged_Callback(hObj, ev)
        if ~ev.getValueIsAdjusting()
            drawnow
            t = toc;
            if (t > 0.1)
                tic;
            else
                % disp('******* REJECTED ********');
                return
            end
            % Update events list
            UpdateEventsList();
            % Update baseline default selection
            UpdateBaselineDefault();
        end
    end



%% ===== JLIST: EVENTS SELECTION CHANGED =====
    function EventsSelectionChanged_Callback(hObj, ev)
        drawnow
        % If it is a valid call
        if ~ev.getValueIsAdjusting() && jCheckUseEvents.isSelected()
            % Get selected events
            [iSelEvents, isExtended] = GetSelectedEvents();

            % ===== EVENTS TYPE =====
            % If event types are mixed: error message
            isMixedTypes = ~isempty(isExtended) && any(isExtended) && any(~isExtended);
            if isMixedTypes
                % Display error message
                bst_error('You cannot select at the same time different types of events (simple and extended).', 'Import recordings based on events', 0);
                % Unselect all the events
                jListEvents.setSelectedIndices(-1);
            end
            % Enable/disable events time window depending on the event type (extended or simple)
            isDisableTime = ~isempty(isExtended) && (isMixedTypes || any(~isExtended));
            gui_enable([jLabelEpoch, jTextEventsTimeStart, jTextEventsTimeStop, jLabelTimeUnitsEvents], isDisableTime, 0);
            
            % ===== REACTION TIMES =====
            if ~isempty(jLabelEventsInfo)
                txtReact = '';
                % Get reaction times
                reactTimes = [sFile.events(iSelEvents).reactTimes];
                % Compute average and deviation
                avgReact = mean(reactTimes);
                stdReact = std(reactTimes);
                % Show all the reaction times
                if (avgReact ~= 0)
                    txtReact = sprintf('<HTML>Reaction time (%d events):<BR>Avg = %.3f s<BR>Std = %.3f s', length(reactTimes), avgReact, stdReact);
                end
                jLabelEventsInfo.setText(txtReact);
            end

        % Reset reaction time field
        elseif ~isempty(jLabelEventsInfo)
            jLabelEventsInfo.setText('');
        end
    end

%% ===== VALIDATION BUTTONS =====
    function ButtonReset_Callback(varargin)
        % Reset to defaults
        bst_set('ImportDataOptions', []);
        % Reload panel
        LoadFile();
        LoadOptions();
    end

    function ButtonCancel_Callback(varargin)
        % Close panel without saving (removes mutex automatically)
        gui_hide(panelName);
    end
    
    function ButtonImport_Callback(varargin)
        % Make sure that something is selected
        if ~isempty(jCheckUseEvents) && jCheckUseEvents.isSelected() && isempty(jListEvents.getSelectedIndices())
            bst_error('No event selected.', 'Import data using events', 0);
            return
        end
        % Save permanent options
        SaveOptions();
        % Release mutex and keep the panel opened
        bst_mutex('release', panelName);
    end

    
%% =================================================================================
%  === HELPER FUNCTIONS ============================================================
%  =================================================================================
%% ===== UPDATE EVENTS LIST =====
    function UpdateEventsList()
        import org.brainstorm.list.*;
        % If no events loaded
        if isempty(sFile.events)
            return
        end
        % Get the current bounds (in samples)
        selSamples = round(SelTimeBounds * sFile.prop.sfreq);
        % Create a new events list
        listModel = java_create('javax.swing.DefaultListModel');
        nbEvents = length(sFile.events);
        isExtended = false(1,nbEvents);
        for i = 1:nbEvents
            % Extended/simple event
            isExtended(i) = (size(sFile.events(i).times, 1) == 2);
            % If selection by epoch
            if isEpochs
                % Get selected epochs
                if jCheckAllEpochs.isSelected()
                    iSelEpo = 1:length(sFile.epochs); 
                else
                    iSelEpo = jListEpochs.getSelectedIndices() + 1; 
                end
                % Find all the samples for all the selected epochs
                iSelSmp = find(ismember([sFile.events(i).epochs], iSelEpo));
            % Else: selection by time windows
            else
                % Get all the occurrences of this event
                iSamples = round(sFile.events(i).times .* sFile.prop.sfreq);
                % Keep only the occurrences within the time bounds
                if isempty(iSamples)
                    iSelSmp = [];
                elseif isExtended(i)
                    iSelSmp = find((iSamples(1,:) >= selSamples(1) & (iSamples(1,:) <= selSamples(2))) & ...
                                   (iSamples(2,:) >= selSamples(1) & (iSamples(2,:) <= selSamples(2))));
                else
                    iSelSmp = find((iSamples >= selSamples(1) & (iSamples <= selSamples(2))));
                end
            end
            % Create list item
            if ~isempty(iSelSmp)
                lab = sFile.events(i).label;
                % Check the type of event: extended or simple
                if isExtended(i)
                    % Any event that has "bad" in its name is considered as a bad segment
                    if panel_record('IsEventBad', lab)
                        strTag = '[bad]';
                    else
                        strTag = '[ext]';
                    end
                	listModel.addElement(BstListItem(sprintf('%d', i), 'extended', sprintf('%s (x%d)  %s', lab, length(iSelSmp), strTag), iSelSmp));
                else
                    listModel.addElement(BstListItem(sprintf('%d', i), 'simple', sprintf('%s (x%d)', lab, length(iSelSmp)), iSelSmp));
                end
            end
        end
        jListEvents.setModel(listModel);
        % Select the epochs with select=1, but without mixing simple and extended events
        iSelEvents = find([sFile.events.select]);
        isMixedTypes = any(isExtended) && any(~isExtended);
        if ~isempty(iSelEvents) && jListEvents.isEnabled() && ~isMixedTypes
            jListEvents.setSelectedIndices(iSelEvents - 1);
        end
        % Enable/disable the events time window
        isEnableEventTime = jListEvents.isEnabled() && any(~isExtended);
        gui_enable([jLabelEpoch, jTextEventsTimeStart, jTextEventsTimeStop, jLabelTimeUnitsEvents], isEnableEventTime, 0);
    end


%% ===== UPDATE BASELINE DEFAULT =====
    function UpdateBaselineDefault(varargin)
        BlTimeBounds = [];
        % Get time bounds
        if isEvents && jCheckUseEvents.isSelected()
            % Get events time range
            EventsTimeRange = [str2double(char(jTextEventsTimeStart.getText())), ...
                               str2double(char(jTextEventsTimeStop.getText()))];
            % Convert to ms
            EventsTimeRange = EventsTimeRange ./ 1000;
            if all(~isnan(EventsTimeRange)) && (length(EventsTimeRange) == 2)
                BlTimeBounds = EventsTimeRange;
            end
            TimeUnitBl = 'ms';
        elseif isEpochs
            % Get selected epochs
            if jCheckAllEpochs.isSelected()
                iSelEpochs = 1:length(sFile.epochs); 
            else
                iSelEpochs = jListEpochs.getSelectedIndices() + 1; 
            end
            % Get min and max times
            if ~isempty(iSelEpochs)
                BlTimeBounds = [min([sFile.epochs(iSelEpochs).times]), max([sFile.epochs(iSelEpochs).times])];
            end
            TimeUnitBl = TimeUnit;
        else
            % Get all times
            BlTimeBounds = SelTimeBounds;
            TimeUnitBl = TimeUnit;
        end
        % Nothing available: exit
        if isempty(BlTimeBounds)
            return;
        end
        % If possible take only negative values
        if (BlTimeBounds(1) < 0) && (BlTimeBounds(2) > 0)
            %BlTimeBoundsInit = [BlTimeBounds(1), 0];
            BlTimeBoundsInit = [BlTimeBounds(1), -1./sFile.prop.sfreq];
        else
            BlTimeBoundsInit = BlTimeBounds;
        end
        % Add the frequency to the definition
        BlTimeBoundsCell = {BlTimeBounds(1), BlTimeBounds(2), sFile.prop.sfreq};
        % Set time controls callbacks
        gui_validate_text(jTextBlTimeStart, [], jTextBlTimeStop, BlTimeBoundsCell, TimeUnitBl, [], BlTimeBoundsInit(1), []);
        gui_validate_text(jTextBlTimeStop, jTextBlTimeStart, [], BlTimeBoundsCell, TimeUnitBl, [], BlTimeBoundsInit(2), []);
        % Set time unit: ms
        jLabelBlUnit.setText([' ' TimeUnitBl]);
    end


%% ===== LOAD DATA DESCRIPTION =====
    function LoadFile()
        import org.brainstorm.list.*;
        % ===== EVENTS SELECTION =====
        if isEvents
            UpdateEventsList();
        end
        % ===== EPOCHS SELECTION =====
        if isEpochs
            % Create a list with all the available epochs
            listModel = javax.swing.DefaultListModel();
            for i = 1:nbEpochs
                if isempty(sFile.epochs(i).label)
                    listModel.addElement(BstListItem('', '', sprintf('Epoch #%03d', i), i));
                else
                    listModel.addElement(BstListItem('', '', sFile.epochs(i).label, i));
                end
            end
            jListEpochs.setModel(listModel);
            % Select the epochs with select=1
            iSelEpoch = find([sFile.epochs.select]);
            jListEpochs.setSelectedIndices(iSelEpoch - 1);
        end
        % Update panel
        UpdateBaselineDefault();
    end


%% ===== LOAD OPTIONS =====
    function LoadOptions()
        % Get saved Import FIF Options
        ImportDataOptions = bst_get('ImportDataOptions');
        % === SELECTION BY TIME ===
        if ~isEpochs
            if ~isempty(jCheckSplit)
                % Split RAW
                jCheckSplit.setSelected(ImportDataOptions.SplitRaw && strcmpi(TimeUnit, 's'));
                jTextBlockLength.setText(sprintf('%1.4f', ImportDataOptions.SplitLength));
                RawSplit_Callback();
                % Update blocks description
                UpdateSamplesPerBlock();
            end
        % === SELECTION BY EPOCHS ===
        else
            % Get all epochs
            jCheckAllEpochs.setSelected(ImportDataOptions.GetAllEpochs);
            GetAllEpochs_Callback();
        end
        % === EVENTS ===
        % Use events
        if isEvents
            if ImportDataOptions.UseEvents
                jCheckUseEvents.setSelected(1);
            end
            % Update baseline time range
            UseEvents_Callback();
        end
        % === REMOVE BASELINE ===
        switch(ImportDataOptions.RemoveBaseline)
            case 'all'
                jCheckBaseline.setSelected(1);
                jRadioBaselineAll.setSelected(1);
            case 'time'
                jCheckBaseline.setSelected(1);
                jRadioBaselineTime.setSelected(1);
            otherwise
                jCheckBaseline.setSelected(ImportDataOptions.Resample);
        end
        BaselineCheckBox_Callback();
        % === RESAMPLE ===
        jCheckResample.setSelected(ImportDataOptions.Resample);
        ResampleCheckBox_Callback();
        if (ImportDataOptions.ResampleFreq > 0)
            resampleFreq = ImportDataOptions.ResampleFreq;
        else
            resampleFreq = sFile.prop.sfreq;
        end
        jTextSampleRate.setText(sprintf('%1.2f', resampleFreq));
        % === CTF COMPENSATORS ===
        if ~isempty(jCheckCtfComp)
            % jCheckCtfComp.setSelected(ImportDataOptions.UseCtfComp);
            jCheckCtfComp.setSelected(1);
        end
        % === SSP ===
        if ~isempty(jCheckSsp)
            % jCheckSsp.setSelected(ImportDataOptions.UseSsp);
            jCheckSsp.setSelected(1);
        end
        % === CREATE CONDITIONS ===
        % UpdateDefaultCreateCond();
        jCheckCreateCond.setSelected(ImportDataOptions.CreateConditions);
    end


%% ===== SAVE OPTIONS =====
    function SaveOptions()
        % Get saved Import FIF Options
        ImportDataOptions = bst_get('ImportDataOptions');
        % === RAW FILES ===
        if ~isEpochs
            % Split RAW
            if ~isempty(jCheckSplit) && jCheckSplit.isEnabled()
                % Use split
                ImportDataOptions.SplitRaw = jCheckSplit.isSelected();
                % Time blocks length
                if ImportDataOptions.SplitRaw
                    % Get block length
                    blockLength = str2double(char(jTextBlockLength.getText()));
                    if ~isempty(blockLength) && ~isnan(blockLength)
                        ImportDataOptions.SplitLength = blockLength;
                    end
                end
            end
        % === EVOKED FILES ===
        else
            % Get all epochs
            ImportDataOptions.GetAllEpochs = jCheckAllEpochs.isSelected();
        end
        
        % === EVENTS ===
        % Use events
        if isEvents
            % Checkbox
            ImportDataOptions.UseEvents = jCheckUseEvents.isSelected();
            % Events time range
            EventsTimeRange = [str2double(char(jTextEventsTimeStart.getText())), ...
                               str2double(char(jTextEventsTimeStop.getText()))];
            % Conver to ms
            EventsTimeRange = EventsTimeRange / 1000;
            if all(~isnan(EventsTimeRange)) && (length(EventsTimeRange) == 2)
                ImportDataOptions.EventsTimeRange = EventsTimeRange;
            end
        end
        
        % === REMOVE BASELINE ===
        if ~jCheckBaseline.isSelected()
            ImportDataOptions.RemoveBaseline = 'no';
        elseif jRadioBaselineAll.isSelected()
            ImportDataOptions.RemoveBaseline = 'all';
        elseif jRadioBaselineTime.isSelected()
            ImportDataOptions.RemoveBaseline = 'time';
        end
        % === OTHER DEFAULTS ===
        if jCheckResample.isEnabled()
            ImportDataOptions.Resample = jCheckResample.isSelected();
            if ImportDataOptions.Resample
                ImportDataOptions.ResampleFreq = str2double(char(jTextSampleRate.getText()));
            end
        end
        if ~isempty(jCheckCtfComp)
            ImportDataOptions.UseCtfComp = jCheckCtfComp.isSelected();
        end       
        if ~isempty(jCheckSsp)
            ImportDataOptions.UseSsp = jCheckSsp.isSelected();
        end
        ImportDataOptions.CreateConditions = jCheckCreateCond.isSelected();
        % Update options
        bst_set('ImportDataOptions', ImportDataOptions);
    end
end



%% =================================================================================
%  === EXTERNAL CALLS ==============================================================
%  =================================================================================

%% ===== GET SELECTED EVENTS =====
% Return the list of events selected events, indice is relative to the list of all the events (no only the displayed events)
% isExtended: flag for each event, to identify the type of event (simple or extended)
% iOccur: list of occurrences of each event that are selected
function [iSelEvt, isExtended, iOccur] = GetSelectedEvents()
    % Get panel controls handles
    ctrl = bst_get('PanelControls', 'ImportDataOptions');
    % Get selected events
    selObj = ctrl.jListEvents.getSelectedValues();
    % Get their properties
    iSelEvt    = [];
    isExtended = [];
    iOccur     = {};
    for iObj = 1:length(selObj)
        iSelEvt(iObj)    = str2num(selObj(iObj).getType());
        isExtended(iObj) = (size(ctrl.sFile.events(iSelEvt(iObj)).times, 1) == 2);
        iOccur{iObj}     = selObj(iObj).getUserData()';
    end
end
    
%% ===== GET PANEL CONTENTS =====
function s = GetPanelContents() %#ok<DEFNU>
    % Get panel controls handles
    ctrl = bst_get('PanelControls', 'ImportDataOptions');
    if isempty(ctrl)
        s = [];
        return
    end
    % Get permanent options
    s = bst_get('ImportDataOptions');
    % Get import type
    isEvents = ~isempty(ctrl.sFile.events);
    isEpochs = ~isempty(ctrl.sFile.epochs) && (length(ctrl.sFile.epochs) > 1);
    
    % === RAW FILES ===
    if ~isEpochs
        % Import mode
        s.ImportMode = 'Time';
        % Time selection
        s.TimeRange = [];
        % Get time range
        TimeRange = [str2double(char(ctrl.jTextTimeStart.getText())), ...
                     str2double(char(ctrl.jTextTimeStop.getText()))];
        if all(~isnan(TimeRange)) && (length(TimeRange) == 2)
            if strcmpi(ctrl.TimeUnit, 'ms')
                s.TimeRange = TimeRange / 1000;
            else
                s.TimeRange = TimeRange;
            end
        end
        % Split block length, in samples
        s.SplitRaw = ~isempty(ctrl.jCheckSplit) && ctrl.jCheckSplit.isEnabled() && ctrl.jCheckSplit.isSelected();
        if s.SplitRaw
            s.SplitLength = str2double(char(ctrl.jTextBlockLength.getText()));
        else
            s.SplitLength = []; 
        end
    % === EVOKED FILES ===
    else
        % Get selected epoch indices
        if ctrl.jCheckAllEpochs.isSelected()
            s.iEpochs = 1:ctrl.jListEpochs.getModel().getSize();
        else
            s.iEpochs = ctrl.jListEpochs.getSelectedIndices() + 1;            
        end
        % Import mode
        s.ImportMode = 'Epoch';
    end
    
    % === EVENTS ===
    % Get events
    if isEvents && ctrl.jCheckUseEvents.isSelected()
        % Get selected events
        [iSelEvents, isExtended, iSelSmp] = GetSelectedEvents();
        % Get events list (Keep only selected events)
        s.events = ctrl.sFile.events(iSelEvents);
        % Keep only the occurrences selected by the user
        for iEvent = 1:length(s.events)
            s.events(iEvent).epochs   = s.events(iEvent).epochs(iSelSmp{iEvent});
            s.events(iEvent).times    = s.events(iEvent).times(:, iSelSmp{iEvent});
            s.events(iEvent).channels = s.events(iEvent).channels(iSelSmp{iEvent});
            s.events(iEvent).notes    = s.events(iEvent).notes(iSelSmp{iEvent});
        end
        % Import mode
        s.ImportMode = 'Event';
    else
        s.events = [];
    end

    % === BASELINE ===
    switch(s.RemoveBaseline)
        case {'all','no'}
            % Nothing more to read
        case 'time'
            % Get baseline time range
            BlTimeRange = [str2double(char(ctrl.jTextBlTimeStart.getText())), ...
                           str2double(char(ctrl.jTextBlTimeStop.getText()))];
            if all(~isnan(BlTimeRange)) && (length(BlTimeRange) == 2)
                if strcmpi(char(ctrl.jLabelBlUnit.getText()), ' ms')
                    s.BaselineRange = BlTimeRange / 1000;
                else
                    s.BaselineRange = BlTimeRange;
                end
            end
    end
    % === RESAMPLE ===
    s.Resample = ctrl.jCheckResample.isSelected();
    if s.Resample
        s.ResampleFreq = str2double(char(ctrl.jTextSampleRate.getText()));
    else
        s.ResampleFreq = [];
    end
    % === CTF COMPENSATORS ===
    s.UseCtfComp = isempty(ctrl.jCheckCtfComp) || ctrl.jCheckCtfComp.isSelected();
    % === SSP ===
    s.UseSsp = ~isempty(ctrl.jCheckSsp) && ctrl.jCheckSsp.isSelected();
    % === CREATE CONDITIONS ===
    s.CreateConditions = ctrl.jCheckCreateCond.isSelected();
end






