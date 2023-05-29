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

    PcaOptions = sProcess.options.pcaedit.Value;
    nInputs = numel(sInputs);
    % Progress bar
    bst_progress('start', 'Read recordings information', 'Analysing input files...', 0, nInputs);
%     isAllLink = true;
%     isAllCov = true;
    TimeWindow = [NaN, NaN];
    SamplingPeriod = [];
%     CovOptions = [];
%     CovLabelText = '';
    for iInput = 1:nInputs
%         % Check if inputs are all kernel links and a data covariance is available.
%         if isAllLink
%             if ~strcmpi(file_gettype(sInputs(iInput).FileName), 'link')
%                 isAllLink = false;
%                 isAllCov = false;
%             elseif isAllCov
%                 sStudy = bst_get('Study', sInputs(iInput).iStudy);
%                 if numel(sStudy.NoiseCov) < 2
%                     isAllCov = false;
%                     CovOptions = [];
%                     CovLabelText = 'Data covariance not found.';
%                 end
%             end
%         end
        % Get min and max times over all inputs.
        ResultsMat = in_bst_results(sInputs(iInput).FileName, 0, 'Time');
        TimeWindow = [min(TimeWindow(1), ResultsMat.Time(1)), max(TimeWindow(2), ResultsMat.Time(end))];
        % Get sampling rate for default baseline, and check consistency.
        if isempty(SamplingPeriod)
            SamplingPeriod = ResultsMat.Time(2) - ResultsMat.Time(1);
        elseif SamplingPeriod ~= (ResultsMat.Time(2) - ResultsMat.Time(1))
            bst_report('Warning', sProcess, sInputs, 'Selected files have different sampling rates.');
        end
%         % Check consistency of covariance options. 
%         if isAllCov
%             if isempty(CovOptions)
%                 CovOptions = GetCovOptions(sStudy);
%             else
%                 CovOptionsCompare = GetCovOptions(sStudy);
%                 % We allow different time windows if it's the whole file.
%                 if ~strcmp(CovOptions.RemoveDcOffset, CovOptionsCompare.RemoveDcOffset) || ...
%                         (~isequal(CovOptions.Baseline, CovOptionsCompare.Baseline) && ~isequal(CovOptions.Baseline, ResultsMat.Time([1,end]))) || ...
%                         (~isequal(CovOptions.DataTimeWindow, CovOptionsCompare.DataTimeWindow) && ~isequal(CovOptions.DataTimeWindow, ResultsMat.Time([1,end])))
%                     isAllCov = false;
%                     CovOptions = [];
%                     CovLabelText = 'Selected studies have different covariance settings.';
%                     bst_report('Warning', sProcess, sInputs, CovLabelText);
%                 else
%                     % Extend if it's whole files, so it's consistent with displayed TimeWindow.
%                     CovOptions.Baseline = [min(CovOptions.Baseline(1), CovOptionsCompare.Baseline(1)), max(CovOptions.Baseline(2), CovOptionsCompare.Baseline(2))];
%                     CovOptions.DataTimeWindow = [min(CovOptions.DataTimeWindow(1), CovOptionsCompare.DataTimeWindow(1)), max(CovOptions.DataTimeWindow(2), CovOptionsCompare.DataTimeWindow(2))];
%                 end
%             end
%         end
        bst_progress('inc', 1);
    end
    % Get data covariance settings from history. (Would be simpler to save NoiseCovMat.Options.)
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
        gui_component('label', jPanelOptions, '', 'Compute one principal component (combination of signals)...');
        jButtonGroupMethod = ButtonGroup();
        % Across epochs
        jRadioPcaa = gui_component('radio', jPanelOptions, 'br', ...
            'across all epochs/files', [], [], @RadioPca_Callback);
        jButtonGroupMethod.add(jRadioPcaa);
        % Per epoch, with sign consistency
        jRadioPcai = gui_component('radio', jPanelOptions, 'br', ...
            'per individual epoch/file, with consistent sign', [], [], @RadioPca_Callback);
        jButtonGroupMethod.add(jRadioPcai);
        % Per epoch, without sign consistency
        jRadioPca = gui_component('radio', jPanelOptions, 'br', ...
            '<HTML><FONT color="#777777">per individual epoch/file, arbitrary signs (not recommended, pre 2023)</FONT>', [], [], @RadioPca_Callback);
        jButtonGroupMethod.add(jRadioPca);
        switch lower(PcaOptions.Method)
            case 'pca'
                jRadioPca.setSelected(1);
            case 'pcai'
                jRadioPcai.setSelected(1);
            otherwise % 'pcaa' as default
                jRadioPcaa.setSelected(1);
        end
    jPanelNew.add('hfill', jPanelOptions);
        
    jPanelCov = gui_river([5,2], [0,10,15,0], 'Data covariance options');
        % This is how it is and used to be (also for covariance computation), but maybe not that
        % logical... It would make more sense to do the desired baseline/offset removal on the data
        % directly, even before the inverse model, like we'd do for filtering, and keep it
        % consistent (no more offset removal options) everywhere after.  Then only the data time
        % window would be relevant here.
        % gui_component('label', jPanelCov, 'p', ['<HTML>These options affect the principal component coefficients only,<BR>' ...
        %     'which is then applied to the unmodified data (without offset removal).']);
%         % Use pre-computed data covariance?
%         if isAllCov
%             jCheckUseDataCov = gui_component('checkbox', jPanelCov, 'p', ['<HTML>Use pre-computed data covariance (requires kernel link source files)<BR>' ...
%                 '<FONT color="#777777"><I>When selected, the settings used to compute the covariance are shown below.</I></FONT>'], [], [], @CheckUseDataCov_Callback);
%             jCheckUseDataCov.setSelected(1);
%         else
%             jCheckUseDataCov = gui_component('label', jPanelCov, 'p', ['<HTML><I>' CovLabelText ' Specify settings below.</I>']);
%         end
        % Time window
        gui_component('label', jPanelCov, 'p', 'Input files time window: ');
        gui_component('label', jPanelCov, 'tab', strTime);

        % DATA TIME WINDOW
        jCovLabels = {};
        % Time range
        jCovLabels{end+1} = gui_component('label', jPanelCov, 'br', 'PCA time window: ');
        jDataTimeStart = gui_component('texttime', jPanelCov, 'tab', ' ', TEXT_DIM);
        jCovLabels{end+1} = gui_component('label', jPanelCov, [], ' - ');
        jDataTimeStop = gui_component('texttime', jPanelCov, [], ' ', TEXT_DIM);
        % Callbacks
        DataTimeUnit = gui_validate_text(jDataTimeStart, [], jDataTimeStop, ResultsMat.Time, 'time', [], PcaOptions.DataTimeWindow(1), []);
        DataTimeUnit = gui_validate_text(jDataTimeStop, jDataTimeStart, [], ResultsMat.Time, 'time', [], PcaOptions.DataTimeWindow(2), []);
        % Units
        jCovLabels{end+1} = gui_component('label', jPanelCov, [], DataTimeUnit);
        % All file box
        jCovLabels{end+1} = gui_component('label', jPanelCov, [], '<HTML>&nbsp;&nbsp;&nbsp;&nbsp;');
        jDataTimeAll = gui_component('checkbox', jPanelCov, '', 'All file', [], [], @DataTimeAll_Callback);

        % BASELINE 
        % Remove DC offset (limited to per-file for now)
        jRemoveDcFile = gui_component('checkbox', jPanelCov, 'p', 'Remove DC offset (subtract baseline average) per epoch/file', [], [], @RemoveDc_Callback);
        if ismember(PcaOptions.RemoveDcOffset, {'file', 'all'})
            jRemoveDcFile.setSelected(1);
        end
        % Time range
        jCovLabels{end+1} = gui_component('label', jPanelCov, 'p', 'Baseline: ');
        jBaselineTimeStart = gui_component('texttime', jPanelCov, 'tab', ' ', TEXT_DIM);
        jCovLabels{end+1} = gui_component('label', jPanelCov, [], ' - ');
        jBaselineTimeStop = gui_component('texttime', jPanelCov, [], ' ', TEXT_DIM);
        % Callbacks
        BaselineTimeUnit = gui_validate_text(jBaselineTimeStart, [], jBaselineTimeStop, ResultsMat.Time, 'time', [], PcaOptions.Baseline(1), []);
        BaselineTimeUnit = gui_validate_text(jBaselineTimeStop, jBaselineTimeStart, [], ResultsMat.Time, 'time', [], PcaOptions.Baseline(2), []);
        % Units
        jCovLabels{end+1} = gui_component('label', jPanelCov, [], BaselineTimeUnit);
        % All file box
        jCovLabels{end+1} = gui_component('label', jPanelCov, [], '<HTML>&nbsp;&nbsp;&nbsp;&nbsp;');
        jBaselineTimeAll = gui_component('checkbox', jPanelCov, '', 'All file', [], [], @BaselineTimeAll_Callback);

    jPanelNew.add('br hfill', jPanelCov);
        
    % ===== VALIDATION BUTTONS =====
    % Help
    gui_component('button', jPanelNew, 'br left',  'Online tutorial', [], [], @ButtonHelp_Callback);
    gui_component('label',  jPanelNew, 'hfill', '  ');
    % Cancel
    gui_component('button', jPanelNew, 'right', 'Cancel', [], [], @ButtonCancel_Callback);
    % Run
    gui_component('button', jPanelNew, '', 'OK', [], [], @ButtonOk_Callback);

    % ===== PANEL CREATION =====
    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    
    % Controls list
    ctrl = struct('jRadioPcaa',         jRadioPcaa, ...
                  'jRadioPcai',         jRadioPcai, ...
                  'jRadioPca',          jRadioPca, ...
                  'jDataTimeStart',     jDataTimeStart, ...
                  'jDataTimeStop',      jDataTimeStop, ...
                  'DataTimeUnit',       DataTimeUnit, ...
                  'jDataTimeAll',       jDataTimeAll, ...
                  'jBaselineTimeStart', jBaselineTimeStart, ...
                  'jBaselineTimeStop',  jBaselineTimeStop, ...
                  'BaselineTimeUnit',   BaselineTimeUnit, ...
                  'jBaselineTimeAll',   jBaselineTimeAll, ...
                  'jRemoveDcFile',      jRemoveDcFile);
%                   'jCheckUseDataCov',   jCheckUseDataCov, ...
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

%% ===== BUTTON: HELP =====
    function ButtonHelp_Callback(varargin)
        HelpUrl = 'https://neuroimage.usc.edu/brainstorm/Tutorials/PCA';
        % Display web page
        status = web(HelpUrl, '-browser');
        if (status ~= 0)
            web(HelpUrl);
        end
    end

%% ===== Use pre-computed covariance checkbox =====
%     function CheckUseDataCov_Callback(varargin)
%         % If use, load covariance settings and disable changing them
%         if isAllCov && jCheckUseDataCov.isSelected()
%             SetValue(jBaselineTimeStart, CovOptions.Baseline(1), BaselineTimeUnit);
%             SetValue(jBaselineTimeStop, CovOptions.Baseline(2), BaselineTimeUnit);
%             SetValue(jDataTimeStart, CovOptions.DataTimeWindow(1), DataTimeUnit);
%             SetValue(jDataTimeStop, CovOptions.DataTimeWindow(2), DataTimeUnit);
%             if ismember(CovOptions.RemoveDcOffset, {'file', 'all'})
%                 jRemoveDcFile.setSelected(1);
%             else
%                 jRemoveDcFile.setSelected(0);
%             end
%             jBaselineTimeStart.setEnabled(0);
%             jBaselineTimeStop.setEnabled(0);
%             jDataTimeStart.setEnabled(0);
%             jDataTimeStop.setEnabled(0);
%             jRemoveDcFile.setEnabled(0);
%             for i = 1:numel(jCovLabels)
%                 jCovLabels{i}.setEnabled(0);
%             end
%         else
%             % Otherwise, load default settings and enable controls
%             SetValue(jBaselineTimeStart, PcaOptions.Baseline(1), BaselineTimeUnit);
%             SetValue(jBaselineTimeStop, PcaOptions.Baseline(2), BaselineTimeUnit);
%             SetValue(jDataTimeStart, PcaOptions.DataTimeWindow(1), DataTimeUnit);
%             SetValue(jDataTimeStop, PcaOptions.DataTimeWindow(2), DataTimeUnit);
%             if ismember(PcaOptions.RemoveDcOffset, {'file', 'all'})
%                 jRemoveDcFile.setSelected(1);
%             else
%                 jRemoveDcFile.setSelected(0);
%             end
%             jBaselineTimeStart.setEnabled(1);
%             jBaselineTimeStop.setEnabled(1);
%             jDataTimeStart.setEnabled(1);
%             jDataTimeStop.setEnabled(1);
%             jRemoveDcFile.setEnabled(1);
%             for i = 1:numel(jCovLabels)
%                 jCovLabels{i}.setEnabled(1);
%             end
%         end
%     end

%% ===== PCA method choice =====
    function RadioPca_Callback(varargin)
        % For legacy pca, enforce full time windows and offset removal as it used to be done.
        if jRadioPca.isSelected()
%             if isAllCov 
%                 jCheckUseDataCov.setSelected(0);
%             end
%             jCheckUseDataCov.setEnabled(0);
            jDataTimeAll.setSelected(1);
            DataTimeAll_Callback;
            jDataTimeAll.setEnabled(0);
            jRemoveDcFile.setSelected(1);
            jRemoveDcFile.setEnabled(0);
            jBaselineTimeAll.setSelected(1);
            BaselineTimeAll_Callback;
            jBaselineTimeAll.setEnabled(0);
            for i = 1:numel(jCovLabels)
                jCovLabels{i}.setEnabled(0);
            end
        else
%             % Use of pre-computed data covariance is available for pcaa/pcai.
%             jCheckUseDataCov.setEnabled(1);
%             if isAllCov
%                 % Automatically select after changing method.
%                 jCheckUseDataCov.setSelected(1);
%             end
%             % Update covariance options
%             CheckUseDataCov_Callback();
            % Otherwise, load default settings and enable controls
            % Would be nicer to only change it if previous selection was legacy pca.
            jDataTimeAll.setEnabled(1);
            jDataTimeAll.setSelected(0);
            DataTimeAll_Callback;
            jRemoveDcFile.setEnabled(1);
            if ismember(PcaOptions.RemoveDcOffset, {'file', 'all'})
                jRemoveDcFile.setSelected(1);
            else
                jRemoveDcFile.setSelected(0);
            end
            jBaselineTimeAll.setSelected(0);
            RemoveDc_Callback;
            for i = 1:numel(jCovLabels)
                jCovLabels{i}.setEnabled(1);
            end
        end
    end

%% ===== PCA time window - ALL FILE =====
    function DataTimeAll_Callback(varargin)
        if jDataTimeAll.isSelected()
            SetValue(jDataTimeStart, TimeWindow(1), DataTimeUnit);
            SetValue(jDataTimeStop, TimeWindow(2), DataTimeUnit);
            jDataTimeStart.setEnabled(0);
            jDataTimeStop.setEnabled(0);
        else
            % Otherwise, load default settings and enable controls
            jDataTimeStart.setEnabled(1);
            jDataTimeStop.setEnabled(1);
            SetValue(jDataTimeStart, PcaOptions.DataTimeWindow(1), DataTimeUnit);
            SetValue(jDataTimeStop, PcaOptions.DataTimeWindow(2), DataTimeUnit);
        end
    end

%% ===== Baseline time window - ALL FILE =====
    function BaselineTimeAll_Callback(varargin)
        if jBaselineTimeAll.isSelected()
            SetValue(jBaselineTimeStart, TimeWindow(1), BaselineTimeUnit);
            SetValue(jBaselineTimeStop, TimeWindow(2), BaselineTimeUnit);
            jBaselineTimeStart.setEnabled(0);
            jBaselineTimeStop.setEnabled(0);
        else
            % Otherwise, load default settings and enable controls
            jBaselineTimeStart.setEnabled(1);
            jBaselineTimeStop.setEnabled(1);
            SetValue(jBaselineTimeStart, PcaOptions.Baseline(1), BaselineTimeUnit);
            SetValue(jBaselineTimeStop, PcaOptions.Baseline(2), BaselineTimeUnit);
        end
    end

%% ===== Remove DC =====
    function RemoveDc_Callback(varargin)
        if ~jRemoveDcFile.isSelected()
            SetValue(jBaselineTimeStart, [], BaselineTimeUnit);
            SetValue(jBaselineTimeStop, [], BaselineTimeUnit);
            jBaselineTimeStart.setEnabled(0);
            jBaselineTimeStop.setEnabled(0);
            jBaselineTimeAll.setSelected(0);
            jBaselineTimeAll.setEnabled(0);
        else %if ~jRadioPca.isSelected() 
            % Otherwise, load default settings and enable controls
            jBaselineTimeAll.setEnabled(1);
            BaselineTimeAll_Callback;
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

%% ===== Read settings used to compute covariance, from history =====
% function CovOptions = GetCovOptions(sStudy)
%     DataCov = load(file_fullpath(sStudy.NoiseCov(2).FileName));
%     % Data=[%1.3f, %1.3f]s, Baseline=[%1.3f, %1.3f]s
%     iHistCov = find(strcmpi(DataCov.History(:,2), 'compute'), 1);
%     if isempty(iHistCov)
%         error('Missing history information in data covariance file.');
%     end
%     TimeUnit = regexp(DataCov.History{iHistCov,3}, '(?<=Baseline=[\[\]0-9-,. ]*)[ms]*', 'match', 'once');
%     CovOptions.Baseline = str2num(regexp(DataCov.History{iHistCov,3}, '(?<=Baseline=)[\[0-9-,. ]*]', 'match', 'once'));
%     if strcmp(TimeUnit, 'ms')
%         % convert to s
%         CovOptions.Baseline = CovOptions.Baseline / 1000;
%     end
%     TimeUnit = regexp(DataCov.History{iHistCov,3}, '(?<=Data=[\[\]0-9-,. ]*)[ms]*', 'match', 'once');
%     CovOptions.DataTimeWindow = str2num(regexp(DataCov.History{iHistCov,3}, '(?<=Data=)[\[0-9-,. ]*]', 'match', 'once')); %#ok<*ST2NM>
%     if strcmp(TimeUnit, 'ms')
%         % convert to s
%         CovOptions.DataTimeWindow = CovOptions.DataTimeWindow / 1000;
%     end
%     CovOptions.RemoveDcOffset = lower(strtrim(DataCov.History{iHistCov,3}(end-3:end)));
% end

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
%     % Get pre-computed covariance option
%     if isa(ctrl.jCheckUseDataCov, 'javax.swing.JCheckBox')
%         s.UseDataCov = ctrl.jCheckUseDataCov.isSelected();
%     else % it's a label "Data cov not found"
%         s.UseDataCov = false;
%     end
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
    % Save panel preferences.
    bst_set('PcaOptions', s);
end



