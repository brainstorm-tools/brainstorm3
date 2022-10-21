function varargout = panel_pca(varargin)
% PANEL_PCA: Options for PCA dimension reduction on scouts, or xyz orientations.
% 
% USAGE:  bstPanelNew = panel_pca('CreatePanel')
%                   s = panel_pca('GetPanelContents')

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
    panelName = 'PcaOptions';
    bstPanelNew = [];

    PcaOptions = sProcess.options.edit.Value;
    %% TODO: Load user preferences.
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
    % Get data covariance settings from history. (Would be simpler to save NoiseCovMat.Options.)
    if isAllLink && isAllCov
        DataCov = load(file_fullpath(sStudy.NoiseCov(2).FileName));
        % Data=[%1.3f, %1.3f]s, Baseline=[%1.3f, %1.3f]s
        iHistCov = find(strcmpi(DataCov.History(:,2), 'compute'), 1);
        if isempty(iHistCov)
            error('Missing history information in data covariance file.');
        end
        TimeUnit = regexp(DataCov.History{iHistCov,3}, '(?<=Baseline=[\[\]0-9-,. ]*)[ms]*', 'match', 'once');
        CovOptions.Baseline = str2num(regexp(DataCov.History{iHistCov,3}, '(?<=Baseline=)[\[0-9-,. ]*]', 'match', 'once'));
        if strcmp(TimeUnit, 'ms')
            % convert to s
            CovOptions.Baseline = CovOptions.Baseline / 1000; 
        end
        TimeUnit = regexp(DataCov.History{iHistCov,3}, '(?<=Data=[\[\]0-9-,. ]*)[ms]*', 'match', 'once');
        CovOptions.DataTimeWindow = str2num(regexp(DataCov.History{iHistCov,3}, '(?<=Data=)[\[0-9-,. ]*]', 'match', 'once')); %#ok<*ST2NM> 
        if strcmp(TimeUnit, 'ms')
            % convert to s
            CovOptions.DataTimeWindow = CovOptions.DataTimeWindow / 1000; 
        end
        CovOptions.RemoveDcOffset = lower(strtrim(DataCov.History{iHistCov,3}(end-3:end)));
    else
        CovOptions = [];
    end
    bst_progress('stop');

    % Time window string
    if (max(abs(TimeWindow)) > 2)
        strTime = sprintf('[%1.4f, %1.4f] s', TimeWindow);
    else
        strTime = sprintf('[%1.2f, %1.2f] ms', TimeWindow .* 1000);
    end

    % Default settings for time windows and DC offset removal
    % These get overwritten by existing covariance settings, when used.
    % Use saved preferences, if it overlaps with time window.
    if PcaOptions.Baseline(1) < TimeWindow(2) && PcaOptions.Baseline(2) > TimeWindow(1)
        PcaOptions.Baseline = [max(TimeWindow(1), PcaOptions.Baseline(1)), min(TimeWindow(2), PcaOptions.Baseline(2))];
    elseif (TimeWindow(1) < 0) && (TimeWindow(2) > 0)
        PcaOptions.Baseline = [TimeWindow(1), -SamplingPeriod];
    else
        PcaOptions.Baseline = TimeWindow;
    end
    if PcaOptions.DataTimeWindow(1) < TimeWindow(2) && PcaOptions.DataTimeWindow(2) > TimeWindow(1)
        PcaOptions.DataTimeWindow = [max(TimeWindow(1), PcaOptions.DataTimeWindow(1)), min(TimeWindow(2), PcaOptions.DataTimeWindow(2))];
    elseif (TimeWindow(1) < 0) && (TimeWindow(2) > 0)
        PcaOptions.DataTimeWindow = [0, TimeWindow(2)];
    else
        PcaOptions.DataTimeWindow = TimeWindow;
    end
    
    % ===== CREATE GUI =====
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    % Constants
    TEXT_DIM = java_scaled('dimension', 70, 20);
    % Create main main panel
    jPanelNew = gui_river();
    
    % OPTIONS PANEL
    jPanelOptions = gui_river([5,2], [0,10,15,0], 'PCA method');
        % PCA TYPE
        %gui_component('label', jPanelOptions, 'p', 'PCA method:');
        jButtonGroupMethod = ButtonGroup();
        % Across epochs
        gui_component('label', jPanelOptions, 'br', '    ');
        jRadioPcaa = gui_component('radio', jPanelOptions, '', ...
            ['<HTML><B>Across epochs/files</B>: Generally recommended, especially for within subject comparisons.<BR>' ...
            'Much faster on kernel link source files and using pre-computed data covariance. Can save shared kernels.'], [], [], @RadioPca_Callback);
        jRadioPcaa.setSelected(1);
        jButtonGroupMethod.add(jRadioPcaa);
        % Per epoch, with sign consistency
        gui_component('label', jPanelOptions, 'br', '    ');
        jRadioPcai = gui_component('radio', jPanelOptions, '', ...
            ['<HTML><B>Per individual epoch/file, with consistent sign</B>: Useful for single-trial analysis,<BR>' ...
            'while still allowing combining epochs. Sign selected using PCA across epochs as reference.<BR>' ...
            'Slow. Saves individual files.'], [], [], @RadioPca_Callback);
        jButtonGroupMethod.add(jRadioPcai);
        % Per epoch, without sign consistency
        gui_component('label', jPanelOptions, 'br', '    ');
        jRadioPca = gui_component('radio', jPanelOptions, '', ...
            ['<HTML><FONT color="#777777"><B>Per individual epoch/file, arbitrary signs</B>: Can be used for single files.<BR>' ...
            'Method used prior to Nov 2022, no longer recommended due to sign inconsistency.<BR>' ...
            '<I>The covariance options below cannot be modified.</I></FONT>'], [], [], @RadioPca_Callback);
        jButtonGroupMethod.add(jRadioPca);
    jPanelNew.add('hfill', jPanelOptions);
        
    jPanelCov = gui_river([5,2], [0,10,15,0], 'Data covariance options');
        % This is how it is and used to be (also for covariance computation), but maybe not that
        % logical... It would make more sense to do the desired baseline/offset removal on the data
        % directly, even before the inverse model, like we'd do for filtering, and keep it
        % consistent (no more offset removal options) everywhere after.  Then only the data time
        % window would be relevant here.
        gui_component('label', jPanelCov, 'p', ['<HTML>These options affect the PCA component computation only,<BR>' ...
            'which is then applied to the unmodified data (without offset removal).']);
        % Use pre-computed data covariance?
        if ~isempty(CovOptions) 
            jCheckUseDataCov = gui_component('checkbox', jPanelCov, 'p', ['<HTML>Use pre-computed data covariance (only applicable to kernel link source files)<BR>' ...
                '<FONT color="#777777"><I>When selected, the settings used to compute the covariance are shown below.</I></FONT>'], [], [], @CheckUseDataCov_Callback);
            jCheckUseDataCov.setSelected(1);
        else
            jCheckUseDataCov = gui_component('label', jPanelCov, 'p', '<HTML><I>Data covariance not found. Using settings below.</I>');
        end
        % Time window
        gui_component('label', jPanelCov, 'p', 'Input files time window: ');
        gui_component('label', jPanelCov, 'tab', strTime);

        % BASELINE 
        % Time range
        jCovLabels = {};
        jCovLabels{end+1} = gui_component('label', jPanelCov, 'p', 'Baseline: ');
        jBaselineTimeStart = gui_component('texttime', jPanelCov, 'tab', ' ', TEXT_DIM);
        jCovLabels{end+1} = gui_component('label', jPanelCov, [], ' - ');
        jBaselineTimeStop = gui_component('texttime', jPanelCov, [], ' ', TEXT_DIM);
        % Callbacks
        BaselineTimeUnit = gui_validate_text(jBaselineTimeStart, [], jBaselineTimeStop, ResultsMat.Time, 'time', [], PcaOptions.Baseline(1), []);
        BaselineTimeUnit = gui_validate_text(jBaselineTimeStop, jBaselineTimeStart, [], ResultsMat.Time, 'time', [], PcaOptions.Baseline(2), []);
        % Units
        jCovLabels{end+1} = gui_component('label', jPanelCov, [], BaselineTimeUnit);

        % DATA TIME WINDOW
        % Time range
        jCovLabels{end+1} = gui_component('label', jPanelCov, 'br', 'Data: ');
        jDataTimeStart = gui_component('texttime', jPanelCov, 'tab', ' ', TEXT_DIM);
        jCovLabels{end+1} = gui_component('label', jPanelCov, [], ' - ');
        jDataTimeStop = gui_component('texttime', jPanelCov, [], ' ', TEXT_DIM);
        % Callbacks
        DataTimeUnit = gui_validate_text(jDataTimeStart, [], jDataTimeStop, ResultsMat.Time, 'time', [], PcaOptions.DataTimeWindow(1), []);
        DataTimeUnit = gui_validate_text(jDataTimeStop, jDataTimeStart, [], ResultsMat.Time, 'time', [], PcaOptions.DataTimeWindow(2), []);
        % Units
        jCovLabels{end+1} = gui_component('label', jPanelCov, [], DataTimeUnit);
        
        % Remove DC offset (limited to per-file for now)
        jRemoveDcFile = gui_component('checkbox', jPanelCov, 'p', 'Remove DC offset (subtract baseline average) per epoch/file');
        if ismember(PcaOptions.RemoveDcOffset, {'file', 'all'})
            jRemoveDcFile.setSelected(1);
        end
    jPanelNew.add('br hfill', jPanelCov);
        
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
    
    RadioPca_Callback();
    
    
%% =================================================================================
%  === INTERNAL CALLBACKS ==========================================================
%  =================================================================================
%% ===== CANCEL BUTTON =====
    function ButtonCancel_Callback(hObject, event) %#ok<INUSD> 
        % Close panel without saving (release mutex automatically)
        gui_hide(panelName);
    end

%% ===== OK BUTTON =====
    function ButtonOk_Callback(varargin)
        % Release mutex and keep the panel opened
        bst_mutex('release', panelName);
    end

%% ===== Use pre-computed covariance checkbox =====
    function CheckUseDataCov_Callback(varargin)
        % If use, load covariance settings and disable changing them
        if ~isempty(CovOptions) && jCheckUseDataCov.isSelected()
            SetValue(jBaselineTimeStart, CovOptions.Baseline(1), BaselineTimeUnit);
            SetValue(jBaselineTimeStop, CovOptions.Baseline(2), BaselineTimeUnit);
            SetValue(jDataTimeStart, CovOptions.DataTimeWindow(1), DataTimeUnit);
            SetValue(jDataTimeStop, CovOptions.DataTimeWindow(2), DataTimeUnit);
            if ismember(CovOptions.RemoveDcOffset, {'file', 'all'})
                jRemoveDcFile.setSelected(1);
            else
                jRemoveDcFile.setSelected(0);
            end
            jBaselineTimeStart.setEnabled(0);
            jBaselineTimeStop.setEnabled(0);
            jDataTimeStart.setEnabled(0);
            jDataTimeStop.setEnabled(0);
            jRemoveDcFile.setEnabled(0);
            for i = 1:numel(jCovLabels)
                jCovLabels{i}.setEnabled(0);
            end
        else
            % Otherwise, load default settings and enable controls
            SetValue(jBaselineTimeStart, PcaOptions.Baseline(1), BaselineTimeUnit);
            SetValue(jBaselineTimeStop, PcaOptions.Baseline(2), BaselineTimeUnit);
            SetValue(jDataTimeStart, PcaOptions.DataTimeWindow(1), DataTimeUnit);
            SetValue(jDataTimeStop, PcaOptions.DataTimeWindow(2), DataTimeUnit);
            if ismember(PcaOptions.RemoveDcOffset, {'file', 'all'})
                jRemoveDcFile.setSelected(1);
            else
                jRemoveDcFile.setSelected(0);
            end
            jBaselineTimeStart.setEnabled(1);
            jBaselineTimeStop.setEnabled(1);
            jDataTimeStart.setEnabled(1);
            jDataTimeStop.setEnabled(1);
            jRemoveDcFile.setEnabled(1);
            for i = 1:numel(jCovLabels)
                jCovLabels{i}.setEnabled(1);
            end
        end
    end

%% ===== PCA method choice =====
    function RadioPca_Callback(varargin)
        % For legacy pca, enforce full time windows and offset removal as it used to be done.
        if jRadioPca.isSelected()
            if ~isempty(CovOptions) 
                jCheckUseDataCov.setSelected(0);
            end
            jCheckUseDataCov.setEnabled(0);
            SetValue(jBaselineTimeStart, TimeWindow(1), BaselineTimeUnit);
            SetValue(jBaselineTimeStop, TimeWindow(2), BaselineTimeUnit);
            SetValue(jDataTimeStart, TimeWindow(1), DataTimeUnit);
            SetValue(jDataTimeStop, TimeWindow(2), DataTimeUnit);
            jRemoveDcFile.setSelected(1);
            jBaselineTimeStart.setEnabled(0);
            jBaselineTimeStop.setEnabled(0);
            jDataTimeStart.setEnabled(0);
            jDataTimeStop.setEnabled(0);
            jRemoveDcFile.setEnabled(0);
            for i = 1:numel(jCovLabels)
                jCovLabels{i}.setEnabled(0);
            end
        else
            % Use of pre-computed data covariance is available for pcaa/pcai.
            jCheckUseDataCov.setEnabled(1);
            if ~isempty(CovOptions)
                % Automatically select after changing method.
                jCheckUseDataCov.setSelected(1);
            end
            % Update covariance options
            CheckUseDataCov_Callback();
        end
    end

%% ===== Change value of a time text box =====
    function SetValue(jText, Value, TimeUnit)
        if strcmpi(TimeUnit, 'ms')
            Precision = 1;
        else
            Precision = 4;
        end
        strVal = panel_time('FormatValue', Value, TimeUnit, Precision);
        jText.setText(strVal);
    end

end

%% =================================================================================
%  === EXTERNAL CALLBACKS ==========================================================
%  =================================================================================   
%% ===== GET PANEL CONTENTS =====
function s = GetPanelContents()
    % Get panel controls
    ctrl = bst_get('PanelControls', 'PcaOptions');
    % Default options
    s = bst_get('PcaOptions');
    % Get PCA method
    if ctrl.jRadioPcaa.isSelected()
        s.Method = 'pcaa';
    elseif ctrl.jRadioPcai.isSelected()
        s.Method = 'pcai';
    elseif ctrl.jRadioPca.isSelected()
        s.Method = 'pca';
    end
    % Get pre-computed covariance option
    if isa(ctrl.jCheckUseDataCov, 'javax.swing.JCheckBox')
        s.UseDataCov = ctrl.jCheckUseDataCov.isSelected();
    else % it's a label "Data cov not found"
        s.UseDataCov = false;
    end
    % Get baseline time window
    s.Baseline = [str2double(char(ctrl.jBaselineTimeStart.getText())), ...
                  str2double(char(ctrl.jBaselineTimeStop.getText()))];
    % Convert time values in seconds
    if strcmpi(ctrl.BaselineTimeUnit, 'ms')
        s.Baseline = s.Baseline ./ 1000;
    end
    % Data time window
    s.DataTimeWindow = [str2double(char(ctrl.jDataTimeStart.getText())), ...
        str2double(char(ctrl.jDataTimeStop.getText()))];
    % Convert time values in seconds
    if strcmpi(ctrl.DataTimeUnit, 'ms')
        s.DataTimeWindow = s.DataTimeWindow ./ 1000;
    end
    % Get average computation mode
    if ctrl.jRemoveDcFile.isSelected()
        s.RemoveDcOffset = 'file';
    else
        s.RemoveDcOffset = 'none';
    end
end



