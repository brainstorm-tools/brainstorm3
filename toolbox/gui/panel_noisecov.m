function varargout = panel_noisecov(varargin)
% PANEL_NOISECOV: Options for noise covariance computation.
% 
% USAGE:  bstPanelNew = panel_noisecov('CreatePanel')
%                   s = panel_noisecov('GetPanelContents')

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2016 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2009-2016

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(OPTIONS)  %#ok<DEFNU>  
    % ===== PARSE INPUTS =====
    % OPTIONS:
    %    - nFiles       : Number of files to compute the covariance matrix
    %    - nBlocks      : Number of blocks of data to process
    %    - timeWindow   : Maximum time window over all the files
    %    - freq         : Sampling frequency for all the files (NaN if differs between files) 
    %    - isDataCov    : If 1, data covariance, if 0 noise covariance
    %    - ChannelTypes : Cell array with the list of available channel types
    % Time window string
    timeWindow = [min(OPTIONS.timeSamples), max(OPTIONS.timeSamples)];
    if (max(abs(timeWindow)) > 2)
        strTime = sprintf('[%1.4f, %1.4f] s', timeWindow(1), timeWindow(2));
    else
        strTime = sprintf('[%1.2f, %1.2f] ms', timeWindow(1) .* 1000, timeWindow(2) .* 1000);
    end
    % Frequency string
    if isnan(OPTIONS.freq)
        strFreq = 'Different values';
    else
        strFreq = sprintf('%d Hz', round(OPTIONS.freq));
    end
    % Default baseline
    if (timeWindow(1) < 0) && (timeWindow(2) > 0)
        defBaseline = [timeWindow(1), -1/OPTIONS.freq];
        defData     = [0, timeWindow(2)];
    else
        defBaseline = timeWindow;
        defData     = timeWindow;
    end
    
    % ===== CREATE GUI =====
    panelName = 'NoiseCovOptions';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    % Constants
    TEXT_DIM = java.awt.Dimension(70, 20);
    FONT_SIZE = [];
    % Create main main panel
    jPanelNew = gui_river();
    
    % FILES PANEL
    jPanelFiles = gui_river([5,5], [0,10,15,0], 'Files');
        % Number of files
        jPanelFiles.add(JLabel('Number of files :   '));
        jPanelFiles.add('tab', JLabel(sprintf('%d', OPTIONS.nFiles)));
        % Time window
        jPanelFiles.add('br',  JLabel('Time window : '));
        jPanelFiles.add('tab', JLabel(strTime));
        % Frequency
        jPanelFiles.add('br',  JLabel('Frequency : '));
        jPanelFiles.add('tab', JLabel(strFreq));
        % Number of baseline samples
        jPanelFiles.add('br',  JLabel('Baseline samples : '));
        jLabelBaselineSamples = JLabel('0');
        jPanelFiles.add('tab', jLabelBaselineSamples);
        % Number of data samples
        if OPTIONS.isDataCov
            jPanelFiles.add('br',  JLabel('Data samples : '));
            jLabelDataSamples = JLabel('0');
            jPanelFiles.add('tab', jLabelDataSamples);
        end
    jPanelNew.add('hfill', jPanelFiles);

    % OPTIONS PANEL
    jPanelOptions = gui_river([5,2], [0,10,15,0], 'Options');
        % BASELINE 
        % Time range
        gui_component('label', jPanelOptions, [], 'Baseline: ', [],[],[],FONT_SIZE);
        jBaselineTimeStart = gui_component('texttime', jPanelOptions, 'tab', ' ', TEXT_DIM,[],[],FONT_SIZE);
        gui_component('label', jPanelOptions, [], ' - ', [],[],[],FONT_SIZE);
        jBaselineTimeStop = gui_component('texttime', jPanelOptions, [], ' ', TEXT_DIM,[],[],FONT_SIZE);
        % Callbacks
        BaselineTimeUnit = gui_validate_text(jBaselineTimeStart, [], jBaselineTimeStop, unique(OPTIONS.timeSamples), 'time', [], defBaseline(1), @UpdatePanel);
        BaselineTimeUnit = gui_validate_text(jBaselineTimeStop, jBaselineTimeStart, [], unique(OPTIONS.timeSamples), 'time', [], defBaseline(2), @UpdatePanel);
        % Units
        gui_component('label', jPanelOptions, [], BaselineTimeUnit, [],[],[],FONT_SIZE);

        % DATA TIME WINDOW 
        if OPTIONS.isDataCov
            % Time range
            gui_component('label', jPanelOptions, 'br', 'Data: ', [],[],[],FONT_SIZE);
            jDataTimeStart = gui_component('texttime', jPanelOptions, 'tab', ' ', TEXT_DIM,[],[],FONT_SIZE);
            gui_component('label', jPanelOptions, [], ' - ', [],[],[],FONT_SIZE);
            jDataTimeStop = gui_component('texttime', jPanelOptions, [], ' ', TEXT_DIM,[],[],FONT_SIZE);
            % Callbacks
            DataTimeUnit = gui_validate_text(jDataTimeStart, [], jDataTimeStop, unique(OPTIONS.timeSamples), 'time', [], defData(1), @UpdatePanel);
            DataTimeUnit = gui_validate_text(jDataTimeStop, jDataTimeStart, [], unique(OPTIONS.timeSamples), 'time', [], defData(2), @UpdatePanel);
            % Units
            gui_component('label', jPanelOptions, [], DataTimeUnit, [],[],[],FONT_SIZE);
        else
            jDataTimeStart = [];
            jDataTimeStop = [];
            DataTimeUnit = [];
        end

        % Channel types
        if (length(OPTIONS.ChannelTypes) > 1)
            jPanelOptions.add('br', JLabel('Sensors: '));
            jCheckTypes = javaArray('javax.swing.JCheckBox', length(OPTIONS.ChannelTypes));
            for i = 1:length(OPTIONS.ChannelTypes)
                jCheckTypes(i) = gui_component('checkbox', jPanelOptions, '', OPTIONS.ChannelTypes{i}, [], '', [], []);
                jCheckTypes(i).setSelected(1);
            end
        else
            jCheckTypes = [];
        end
        jPanelOptions.add('br', JLabel('    '));
        
        % Remove DC offset
        jLabelRemoveDc = JLabel('<HTML>Remove DC offset: &nbsp;&nbsp;&nbsp; <FONT color="#777777"><I>(subtract average computed over the baseline)</I></FONT>');
        jPanelOptions.add('p', jLabelRemoveDc);
        jButtonGroupRemove = ButtonGroup();
        % Output type: Full matrix
        jPanelOptions.add('br', JLabel('    '));
        jRadioRemoveDcFile = JRadioButton('Block by block, to avoid effects of slow shifts in data', 1);
        jButtonGroupRemove.add(jRadioRemoveDcFile);
        jPanelOptions.add(jRadioRemoveDcFile);
        % Output type: Diagonal matrix
        jPanelOptions.add('br', JLabel('    '));
        jRadioRemoveDcAll = JRadioButton('Compute global average and remove it to from all the blocks');
        jButtonGroupRemove.add(jRadioRemoveDcAll);
        jPanelOptions.add(jRadioRemoveDcAll);
        % Disable these controls if only one file
        if (OPTIONS.nBlocks == 1)
            jRadioRemoveDcAll.setEnabled(0);
        end
    jPanelNew.add('br hfill', jPanelOptions);
        
    % ===== VALIDATION BUTTONS =====
    % Cancel
    jButtonCancel = JButton('Cancel');
    java_setcb(jButtonCancel, 'ActionPerformedCallback', @ButtonCancel_Callback);
    jPanelNew.add('br right', jButtonCancel);
    % Run
    jButtonRun = JButton('OK');    
    java_setcb(jButtonRun, 'ActionPerformedCallback', @ButtonOk_Callback);
    jPanelNew.add(jButtonRun);

    % ===== PANEL CREATION =====
    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    
    % Controls list
    ctrl = struct('jBaselineTimeStart', jBaselineTimeStart, ...
                  'jBaselineTimeStop',  jBaselineTimeStop, ...
                  'BaselineTimeUnit',   BaselineTimeUnit, ...
                  'jDataTimeStart',     jDataTimeStart, ...
                  'jDataTimeStop',      jDataTimeStop, ...
                  'DataTimeUnit',       DataTimeUnit, ...
                  'jRadioRemoveDcFile', jRadioRemoveDcFile, ...
                  'jRadioRemoveDcAll',  jRadioRemoveDcAll, ...
                  'jCheckTypes',        jCheckTypes);
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, jPanelNew, ctrl);
    
    UpdatePanel();
    
    
%% =================================================================================
%  === INTERNAL CALLBACKS ==========================================================
%  =================================================================================
%% ===== CANCEL BUTTON =====
    function ButtonCancel_Callback(hObject, event)
        % Close panel without saving (release mutex automatically)
        gui_hide(panelName);
    end

%% ===== OK BUTTON =====
    function ButtonOk_Callback(varargin)
        % Release mutex and keep the panel opened
        bst_mutex('release', panelName);
    end

%% ===== UPDATE PANEL =====
    function UpdatePanel(varargin)
        % === BASELINE ===
        % Get baseline
        start = str2num(char(jBaselineTimeStart.getText()));
        stop = str2num(char(jBaselineTimeStop.getText()));
        % Apply time units
        if strcmpi(BaselineTimeUnit, 'ms')
            start = start / 1000;
            stop = stop / 1000;
        end
        % Compute number of samples for all the baselines grouped
        iTime = panel_time('GetTimeIndices', OPTIONS.timeSamples, [start, stop]);
        % Add the multiple times at the beginning and end
        iTime = union(iTime, find(OPTIONS.timeSamples(iTime(1)) == OPTIONS.timeSamples));
        iTime = union(iTime, find(OPTIONS.timeSamples(iTime(end)) == OPTIONS.timeSamples));
        % Update number of samples in GUI
        jLabelBaselineSamples.setText(sprintf('%d', length(iTime)));
        
        % === DATA ===
        if OPTIONS.isDataCov
            % Get time window
            start = str2num(char(jDataTimeStart.getText()));
            stop = str2num(char(jDataTimeStop.getText()));
            % Apply time units
            if strcmpi(DataTimeUnit, 'ms')
                start = start / 1000;
                stop = stop / 1000;
            end
            % Compute number of samples for all the baselines grouped
            iTime = panel_time('GetTimeIndices', OPTIONS.timeSamples, [start, stop]);
            % Add the multiple times at the beginning and end
            iTime = union(iTime, find(OPTIONS.timeSamples(iTime(1)) == OPTIONS.timeSamples));
            iTime = union(iTime, find(OPTIONS.timeSamples(iTime(end)) == OPTIONS.timeSamples));
            % Update number of samples in GUI
            jLabelDataSamples.setText(sprintf('%d', length(iTime)));
        end
    end
end


%% =================================================================================
%  === EXTERNAL CALLBACKS ==========================================================
%  =================================================================================   
%% ===== GET PANEL CONTENTS =====
function s = GetPanelContents() %#ok<DEFNU>
    % Get panel controls
    ctrl = bst_get('PanelControls', 'NoiseCovOptions');
    % Default options
    s = bst_noisecov();
    % Channel types
    if ~isempty(ctrl.jCheckTypes)
        s.ChannelTypes = {};
        for i = 1:length(ctrl.jCheckTypes)
            if ctrl.jCheckTypes(i).isSelected()
                s.ChannelTypes{end+1} = char(ctrl.jCheckTypes(i).getText());
            end
        end
    else
        s.ChannelTypes = [];
    end
    % Get baseline time window
    s.Baseline = [str2double(char(ctrl.jBaselineTimeStart.getText())), ...
                  str2double(char(ctrl.jBaselineTimeStop.getText()))];
    % Convert time values in seconds
    if strcmpi(ctrl.BaselineTimeUnit, 'ms')
        s.Baseline = s.Baseline ./ 1000;
    end
    % Data time window
    if ~isempty(ctrl.jDataTimeStart)
        % Get data time window
        s.DataTimeWindow = [str2double(char(ctrl.jDataTimeStart.getText())), ...
                            str2double(char(ctrl.jDataTimeStop.getText()))];
        % Convert time values in seconds
        if strcmpi(ctrl.DataTimeUnit, 'ms')
            s.DataTimeWindow = s.DataTimeWindow ./ 1000;
        end
    else
        s.DataTimeWindow = [];
    end
    % Get average computation mode
    if ctrl.jRadioRemoveDcFile.isSelected()
        s.RemoveDcOffset = 'File';
    elseif ctrl.jRadioRemoveDcAll.isSelected()
        s.RemoveDcOffset = 'All';
    end
end



