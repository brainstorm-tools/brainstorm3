function varargout = panel_import_ascii(varargin)
% PANEL_IMPORT_ASCII: Import raw EEG (GUI).
% USAGE:  [bstPanelNew, panelName] = panel_import_ascii('CreatePanel', FileFormat)

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
% Authors: Francois Tadel, 2008-2016

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(FileFormat) %#ok<DEFNU>
    % Java initializations
    import java.awt.*;
    import javax.swing.*;   
    % Constants
    panelName = 'ImportEegRawOptions';
    DEFAULT_HEIGHT = 20;
    TEXT_WIDTH     = 55;
    
    % ===== GET OPTIONS =====
    % Get options
    OPTIONS = bst_get('ImportEegRawOptions');
    % Override reading parameters with default
    switch (FileFormat)
        case 'EEG-BRAINVISION'
            OPTIONS.MatrixOrientation = 'timeXchannel';
            OPTIONS.VoltageUnits      = '\muV';
            OPTIONS.SkipLines         = 1;
        case 'EEG-CARTOOL'
            OPTIONS.MatrixOrientation = 'timeXchannel';
            OPTIONS.VoltageUnits      = '\muV';
            OPTIONS.SkipLines         = 0;
    end
    
    % ===== BUILD INTERFACE =====
    % Create main main panel
    jPanelNew = gui_river();
    jPanelOptions = gui_river([5 5], [0 15 15 15], 'EEG Options');
    % Matrix orientation
    jPanelOptions.add(JLabel('Matrix orientation:'));
    jButtonGroup = ButtonGroup();
    % [Channel x Time]
    jRadioChannelTime = JRadioButton('[Channel x Time]');
    jButtonGroup.add(jRadioChannelTime);
    jPanelOptions.add('tab', jRadioChannelTime);
    % [Time x Channel]
    jRadioTimeChannel = JRadioButton('[Time x Channel]');
    jButtonGroup.add(jRadioTimeChannel);  
    jPanelOptions.add('br tab', jRadioTimeChannel);

    % Number of lines to skip at the beginning of the file
    jPanelOptions.add('br', JLabel('Skip header lines: '));
    jTextSkipLines = JTextField('0');
    jTextSkipLines.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
    jTextSkipLines.setHorizontalAlignment(JTextField.RIGHT);
    jPanelOptions.add('tab', jTextSkipLines);
    % Sample duration
    jPanelOptions.add('br', JLabel('Sampling frequency: '));
    jTextSamplingRate = JTextField('');
    jTextSamplingRate.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
    jTextSamplingRate.setHorizontalAlignment(JTextField.RIGHT);
    jPanelOptions.add('tab', jTextSamplingRate);
    jPanelOptions.add(JLabel('Hz'));
    % Baseline duration
    jPanelOptions.add('br', JLabel('Baseline duration: '));
    jTextBaselineDuration = JTextField('');
    jTextBaselineDuration.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
    jTextBaselineDuration.setHorizontalAlignment(JTextField.RIGHT);
    jPanelOptions.add('tab', jTextBaselineDuration);
    jPanelOptions.add(JLabel('ms'));
    % Number of averages
    jPanelOptions.add('br', JLabel('Number of trials averaged: '));
    jTextNavg = JTextField('1');
    jTextNavg.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
    jTextNavg.setHorizontalAlignment(JTextField.RIGHT);
    jPanelOptions.add('tab', jTextNavg);
    
    % Amplitude units
    jPanelOptions.add('br', JLabel('Amplitude units: '));
    jButtonGroupUnits = ButtonGroup();
    % microV
    jRadioUnitsMicroV = JRadioButton('<HTML>&micro;V</HTML>');
    jPanelOptions.add('tab', jRadioUnitsMicroV);
    jButtonGroupUnits.add(jRadioUnitsMicroV);
    % mV
    jRadioUnitsMiliV = JRadioButton('mV');
    jPanelOptions.add('tab', jRadioUnitsMiliV);
    jButtonGroupUnits.add(jRadioUnitsMiliV);
    % V
    jRadioUnitsV = JRadioButton('V');
    jPanelOptions.add('tab', jRadioUnitsV);
    jButtonGroupUnits.add(jRadioUnitsV);
    % None
    jRadioUnitsNone = JRadioButton('None');
    jPanelOptions.add('tab', jRadioUnitsNone);
    jButtonGroupUnits.add(jRadioUnitsNone);
    jPanelNew.add(jPanelOptions);
    
    % ===== VALIDATION BUTTONS =====
    % Cancel
    jButtonCancel = JButton('Cancel');
    java_setcb(jButtonCancel, 'ActionPerformedCallback', @ButtonCancel_Callback);
    jPanelNew.add('br right', jButtonCancel);
    % Save
    jButtonSave = JButton('Import');
    java_setcb(jButtonSave, 'ActionPerformedCallback', @ButtonSave_Callback);
    jPanelNew.add(jButtonSave);

    % ===== APPLY SAVED OPTIONS =====
    % Matrix orientation
    switch(OPTIONS.MatrixOrientation)
        case 'channelXtime'
            jRadioChannelTime.setSelected(1);
        case 'timeXchannel'
            jRadioTimeChannel.setSelected(1);
    end
    % Check if SamplingRate is a frequency
    if (OPTIONS.SamplingRate < 100)
        % Guess that the User entered sampling *interval* (in milliseconds)
        warning('Brainstorm:ImportAsciiOptions', 'Unusually low sampling rate/frequency assumed to be a sampling interval.');
        OPTIONS.SamplingRate = 1000./OPTIONS.SamplingRate;
    end
    % Header size
    jTextSkipLines.setText(sprintf('%d', OPTIONS.SkipLines));
    % Sampling rate and baseline
    jTextSamplingRate.setText(sprintf('%1.0f', OPTIONS.SamplingRate));
    jTextBaselineDuration.setText(sprintf('%1.2f', OPTIONS.BaselineDuration * 1000));
    % Units
    if ~isfield(OPTIONS, 'VoltageUnits')
        OPTIONS.VoltageUnits = 'V';
    end
    switch (OPTIONS.VoltageUnits)
        case '\muV'
            jRadioUnitsMicroV.setSelected(1);
        case 'mV'
            jRadioUnitsMiliV.setSelected(1);
        case 'V'
            jRadioUnitsV.setSelected(1);
        otherwise
            jRadioUnitsNone.setSelected(1);
    end
    % ===== CREATE PANEL =====
    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    % Set option isCanceled 
    OPTIONS.isCanceled = 1;
    bst_set('ImportEegRawOptions', OPTIONS);
    
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct());
                              

%% =================================================================================
%  === CONTROLS CALLBACKS  =========================================================
%  =================================================================================
%% ===== SAVE OPTIONS =====
    function ButtonSave_Callback(varargin)
        % Load saved options
        OPTIONS = bst_get('ImportEegRawOptions');
        % Update values
        % Matrix orientation
        if jRadioChannelTime.isSelected()
            OPTIONS.MatrixOrientation = 'channelXtime';
        elseif jRadioTimeChannel.isSelected()
            OPTIONS.MatrixOrientation = 'timeXchannel';
        end
        % Baseline
        baselineDuration = str2num(char(jTextBaselineDuration.getText()));
        if ~isempty(baselineDuration)
            OPTIONS.BaselineDuration = abs(baselineDuration) / 1000;
        else
            bst_error('Invalid baseline value.', 'Import EEG RAW data', 0);
            return
        end
        % Sample duration
        sampleDuration = str2num(char(jTextSamplingRate.getText()));
        if ~isempty(sampleDuration) && (sampleDuration > 0)
            OPTIONS.SamplingRate = sampleDuration;
        else
            bst_error('Invalid sampling rate.', 'Import EEG RAW data', 0);
            return
        end
        % Voltage units
        if jRadioUnitsMicroV.isSelected()
            OPTIONS.VoltageUnits = '\muV';
        elseif jRadioUnitsMiliV.isSelected()
            OPTIONS.VoltageUnits = 'mV';
        elseif jRadioUnitsV.isSelected()
            OPTIONS.VoltageUnits = 'V';
        else
            OPTIONS.VoltageUnits = 'None';
        end
        % Number of lines to skip
        nbLines = str2num(char(jTextSkipLines.getText()));
        if ~isempty(nbLines) && (nbLines >= 0)
            OPTIONS.SkipLines = nbLines;
        else
            bst_error('Invalid number of lines to skip.', 'Import EEG RAW data', 0);
            return
        end
        % Number of trials averaged
        OPTIONS.nAvg = str2num(char(jTextNavg.getText()));
            
        % Reset option isCanceled 
        OPTIONS.isCanceled = 0;
        % Update options
        bst_set('ImportEegRawOptions', OPTIONS);
        % Hide panel
        gui_hide(panelName);
    end

%% ===== CANCEL BUTTON =====
    function ButtonCancel_Callback(varargin)
        % Hide panel
        gui_hide(panelName);
    end
end

