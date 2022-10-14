function varargout = panel_pca(varargin)
% PANEL_PCA: Options for PCA dimension reduction on scouts, or xyz orientations.
% 
% USAGE:  bstPanelNew = panel_noisecov('CreatePanel')
%                   s = panel_noisecov('GetPanelContents')

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
% Authors: Francois Tadel, Marc Lalancette, 2009-2022

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(sProcess, sInputs) 
    % ===== PARSE INPUTS =====
    % OPTIONS:
    %    - timeSamples  : Maximum time window over all the files
    %    - freq         : Sampling frequency for all the files (NaN if differs between files) 
    %    - isAllLink    : Whether all input files are kernel link source files
    %    - Cov          : If data cov available, options used to compute it (Baseline, DataTimeWindow, RemoveDcOffset)

    PcaOptions = sProcess.options.edit.Value;
    nInputs = numel(sInputs);
    % Progress bar
    bst_progress('start', 'Read recordings information', 'Analysing input files...', 0, nInputs);
    isAllLink = true;
    isAllCov = true;
    TimeWindow = [NaN, NaN];
    SamplingPeriod = [];
    for iInput = 1:nInputs
        % Check if inputs are all kernel links and a data covariance is available.
        if isAllLink
            if ~strcmpi(file_gettype(sInputs(iInput).FileName), 'link')
                isAllLink = false;
            elseif isAllCov
                sStudy = bst_get('Study', sInputs(iInput).iStudy);
                if numel(sStudy.NoiseCov) < 2
                    isAllCov = false;
                end
            end
        end
        % Get min and max times over all inputs.
        ResultsMat = in_bst_results(sInputs(iInput).FileName, 0, 'Time');
        TimeWindow = [min(TimeWindow(1), ResultsMat.Time(1)), max(TimeWindow(2), ResultsMat.Time(end))];
        % Get sampling rate for default baseline, and check consistency.
        if isempty(SamplingPeriod)
            SamplingPeriod = ResultsMat.Time(2) - ResultsMat.Time(1);
        elseif SamplingPeriod ~= (ResultsMat.Time(2) - ResultsMat.Time(1))
            bst_report('Warning', sProcess, sInputs, 'Selected files have different sampling rates.');
        end
        bst_progress('inc', 1);
    end
    % Get data covariance settings. (They're not saved!)
    %if isAllLink && isAllCov
    %    DataCov = load(file_fullpath(sStudy.NoiseCov(2).FileName));
    %end
    bst_progress('stop');

    % Time window string
    if (max(abs(TimeWindow)) > 2)
        strTime = sprintf('[%1.4f, %1.4f] s', TimeWindow);
    else
        strTime = sprintf('[%1.2f, %1.2f] ms', TimeWindow .* 1000);
    end
    % Default baseline and data time windows
    % Take into account saved preferences, if it overlaps with time window.
    if PcaOptions.Baseline(1) < TimeWindow(2) && PcaOptions.Baseline(2) > TimeWindow(1)
        defBaseline = [max(TimeWindow(1), PcaOptions.Baseline(1)), min(TimeWindow(2), PcaOptions.Baseline(2))];
    elseif (TimeWindow(1) < 0) && (TimeWindow(2) > 0)
        defBaseline = [TimeWindow(1), -SamplingPeriod];
    else
        defBaseline = TimeWindow;
    end
    if PcaOptions.DataTimeWindow(1) < TimeWindow(2) && PcaOptions.DataTimeWindow(2) > TimeWindow(1)
        defData = [max(TimeWindow(1), PcaOptions.DataTimeWindow(1)), min(TimeWindow(2), PcaOptions.DataTimeWindow(2))];
    elseif (TimeWindow(1) < 0) && (TimeWindow(2) > 0)
        defData     = [0, TimeWindow(2)];
    else
        defData     = TimeWindow;
    end
    
    % ===== CREATE GUI =====
    panelName = 'PcaOptions';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    % Constants
    TEXT_DIM = java_scaled('dimension', 70, 20);
    % Create main main panel
    jPanelNew = gui_river();
    
    % OPTIONS PANEL
    jPanelOptions = gui_river([5,2], [0,10,15,0], 'Options');
        % PCA TYPE
        gui_component('label', jPanelOptions, 'p', 'PCA computation:');
        jButtonGroupMethod = ButtonGroup();
        % Across epochs
        gui_component('label', jPanelOptions, 'br', '    ');
        jRadioPcaa = gui_component('radio', jPanelOptions, '', ...
            ['<B>Across epochs/files</B>: Generally recommended, especially for within subject comparisons.<BR>' ...
            'Much faster on kernel link source files and using pre-computed data covariance. Can save shared kernels.'], [], [], @UpdatePanel);
        jRadioPcaa.setSelected(1);
        jButtonGroupMethod.add(jRadioPcaa);
        % Per epoch, with sign consistency
        gui_component('label', jPanelOptions, 'br', '    ');
        jRadioPcai = gui_component('radio', jPanelOptions, '', ...
            ['<B>Per individual epoch/file, with consistent sign</B>: Useful for single-trial analysis,<BR>' ...
            'while still allowing combining epochs. Sign selected using PCA across epochs as reference.<BR>' ...
            'Slow. Saves individual files.'], [], [], @UpdatePanel);
        jButtonGroupMethod.add(jRadioPcai);
        % Per epoch, without sign consistency
        gui_component('label', jPanelOptions, 'br', '    ');
        jRadioPca = gui_component('radio', jPanelOptions, '', ...
            ['<B>Per individual epoch/file, arbitrary signs</B>: Can be used for single files.<BR>' ...
            'Method used prior to Nov 2022, no longer recommended due to sign inconsistency.'], [], [], @UpdatePanel);
        jButtonGroupMethod.add(jRadioPca);
        jPanelOptions.add('br', JLabel('    '));
        
        % Use pre-computed data covariance?
        if Options.isAllLink 
            jCheckUseDataCov = gui_component('checkbox', jPanelOptions, '', 'Use pre-computed data covariance (only applicable to kernel link source files)', [], [], @UpdatePanel);
        else
            jCheckUseDataCov = [];
        end
        % Time window
        gui_component('label', jPanelOptions, 'br', 'Time window : ');
        gui_component('label', jPanelOptions, 'tab', strTime);

        if Options.isAllLink && ~isempty(Options.Cov) && isstruct(Options.Cov)
            %% Set Baseline, DataTime and DC offset same as data cov
        end
        % BASELINE 
        % Time range
        gui_component('label', jPanelOptions, [], 'Baseline: ');
        jBaselineTimeStart = gui_component('texttime', jPanelOptions, 'tab', ' ', TEXT_DIM);
        gui_component('label', jPanelOptions, [], ' - ');
        jBaselineTimeStop = gui_component('texttime', jPanelOptions, [], ' ', TEXT_DIM);
        % Callbacks
        BaselineTimeUnit = gui_validate_text(jBaselineTimeStart, [], jBaselineTimeStop, unique(Options.timeSamples), 'time', [], defBaseline(1));
        BaselineTimeUnit = gui_validate_text(jBaselineTimeStop, jBaselineTimeStart, [], unique(Options.timeSamples), 'time', [], defBaseline(2));
        % Units
        gui_component('label', jPanelOptions, [], BaselineTimeUnit);

        % DATA TIME WINDOW
        % Time range
        gui_component('label', jPanelOptions, 'br', 'Data: ');
        jDataTimeStart = gui_component('texttime', jPanelOptions, 'tab', ' ', TEXT_DIM);
        gui_component('label', jPanelOptions, [], ' - ');
        jDataTimeStop = gui_component('texttime', jPanelOptions, [], ' ', TEXT_DIM);
        % Callbacks
        DataTimeUnit = gui_validate_text(jDataTimeStart, [], jDataTimeStop, unique(Options.timeSamples), 'time', [], defData(1));
        DataTimeUnit = gui_validate_text(jDataTimeStop, jDataTimeStart, [], unique(Options.timeSamples), 'time', [], defData(2));
        % Units
        gui_component('label', jPanelOptions, [], DataTimeUnit);

        jPanelOptions.add('br', JLabel('    '));
        
        % Remove DC offset
        jRemoveDcFile = gui_component('checkbox', jPanelOptions, '', '<HTML>Remove DC offset per epoch/file: &nbsp;&nbsp;&nbsp; <FONT color="#777777"><I>(subtract average computed over the baseline)</I></FONT>');
        jRemoveDcFile.setSelected(1);
    jPanelNew.add('br hfill', jPanelOptions);
        
    % ===== VALIDATION BUTTONS =====
    % Cancel
    gui_component('button', jPanelNew, 'br right', 'Cancel', [], [], @ButtonCancel_Callback);
    % Run
    gui_component('button', jPanelNew, '', 'OK', [], [], @ButtonOk_Callback);

    % ===== PANEL CREATION =====
    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    
    % Controls list
    ctrl = struct('jRadioPcaa',         jRadioPcaa, ...
                  'jRadioPcai',         jRadioPcai, ...
                  'jRadioPca',          jRadioPca, ...
                  'jCheckUseDataCov',   jCheckUseDataCov, ...
                  'jBaselineTimeStart', jBaselineTimeStart, ...
                  'jBaselineTimeStop',  jBaselineTimeStop, ...
                  'BaselineTimeUnit',   BaselineTimeUnit, ...
                  'jDataTimeStart',     jDataTimeStart, ...
                  'jDataTimeStop',      jDataTimeStop, ...
                  'DataTimeUnit',       DataTimeUnit, ...
                  'jRemoveDcFile',      jRemoveDcFile);
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
        % Get baseline
        start = str2num(char(jBaselineTimeStart.getText()));
        stop = str2num(char(jBaselineTimeStop.getText()));
        % Apply time units
        if strcmpi(BaselineTimeUnit, 'ms')
            start = start / 1000;
            stop = stop / 1000;
        end
        
        % Get data time window
        start = str2num(char(jDataTimeStart.getText()));
        stop = str2num(char(jDataTimeStop.getText()));
        % Apply time units
        if strcmpi(DataTimeUnit, 'ms')
            start = start / 1000;
            stop = stop / 1000;
        end
    end
end


%% =================================================================================
%  === EXTERNAL CALLBACKS ==========================================================
%  =================================================================================   
%% ===== GET PANEL CONTENTS =====
function s = GetPanelContents()
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



