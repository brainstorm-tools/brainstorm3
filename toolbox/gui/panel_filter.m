function varargout = panel_filter(varargin)
% PANEL_FILTER: Apply a frequency filter to the data time series displayed in brainstorm figures.
% 
% USAGE:  bstPanel = panel_filter('CreatePanel')
%                    panel_filter('SetFilters', LowPassEnabled=[], LowPassValue=[], HighPassEnable=[], HighPassValue=[], SinRemovalEnabled=[], SinRemovalValue=[], MirrorEnabled=[], FullSourcesEnabled=[])

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
% Authors: Francois Tadel, 2008-2019

eval(macro_method);
end


%% ===== CREATE PANEL =====
function bstPanelNew = CreatePanel() %#ok<DEFNU>
    panelName = 'Filter';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    % Create tools panel
    jPanelNew = gui_component('Panel');
    jPanelTop = gui_component('Panel');
    jPanelNew.add(jPanelTop, BorderLayout.NORTH);
    TB_DIM = java_scaled('dimension', 25, 25);
        
    % ===== TOOLBAR =====
    jMenuBar = gui_component('MenuBar', jPanelTop, BorderLayout.NORTH);
        jToolbar = gui_component('Toolbar', jMenuBar);
        jToolbar.setPreferredSize(TB_DIM);
        jToolbar.setOpaque(0);
        % Label
        jLabelWarning = gui_component('label', jToolbar, [], '    Warning:  For visualization only');
        jLabelWarning.setForeground(Color(.7, 0, 0));
        jToolbar.add(Box.createHorizontalGlue());
        % Help button
        jButtonHelp = gui_component('ToolbarButton', jToolbar, [], 'Help', [], [], @(h,ev)bst_help('PanelFilter.html'));
        jButtonHelp.setForeground(Color(.7, 0, 0));
        gui_component('label', jToolbar, [], '    ');

    % ===== FREQUENCY FILTERING =====
    jPanelFilter = gui_river([0 6], [4 1 15 1]);
    jBorder = java_scaled('titledborder', 'Frequency filtering');
    jPanelFilter.setBorder(BorderFactory.createCompoundBorder(BorderFactory.createEmptyBorder(7,7,7,7), jBorder));
        % === HIGH-PASS ===
        jCheckHighpass = gui_component('checkbox', jPanelFilter, [], 'High-pass:', [], [], @CheckHighPass_Callback);
        jTextHighpass  = gui_component('texttime', jPanelFilter, 'tab', '');
        jTextHighpass.setEnabled(0);
        jLabelHighpass = gui_component('label', jPanelFilter, [], ' Hz');
        % === LOW-PASS ===
        jCheckLowpass = gui_component('checkbox', jPanelFilter, 'br', 'Low-pass:', [], [], @CheckLowPass_Callback);
        jTextLowpass  = gui_component('texttime', jPanelFilter, 'tab', '');
        jTextLowpass.setEnabled(0);
        jLabelLowpass = gui_component('label', jPanelFilter, [], ' Hz');
        % === SIN REMOVAL ===
        jCheckSinRem = gui_component('checkbox', jPanelFilter, 'br', 'Notch:', [], [], @CheckSinRemoval_Callback);
        jTextSinRem  = gui_component('text', jPanelFilter, 'tab hfill', '', [], [], []);
        jTextSinRem.setEnabled(0);
        jLabelSinRem = gui_component('label', jPanelFilter, [], ' Hz');
        % === MIRROR ===
        % jCheckMirror = gui_component('checkbox', jPanelFilter, 'br', 'Mirror signal before filtering', [], [], @CheckMirror_Callback);
        % === FILTER SOURCES ===
        jCheckFullSources = gui_component('checkbox', jPanelFilter, 'br', 'Filter all results', [], [], @CheckFullSources_Callback);
    jPanelTop.add(jPanelFilter, BorderLayout.CENTER);
           
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jCheckHighpass',  jCheckHighpass, ...
                                  'jTextHighpass',   jTextHighpass, ...
                                  'jLabelHighpass',  jLabelHighpass, ... 
                                  'jCheckLowpass',   jCheckLowpass, ...
                                  'jTextLowpass',    jTextLowpass, ...
                                  'jLabelLowpass',   jLabelLowpass, ... 
                                  'jCheckSinRem',    jCheckSinRem, ...
                                  'jTextSinRem',     jTextSinRem, ...
                                  'jLabelSinRem',    jLabelSinRem, ...
                                  ... 'jCheckMirror',    jCheckMirror, ...
                                  'jCheckFullSources', jCheckFullSources));
                                                            

%% =================================================================================
%  === INTERNAL PANEL CALLBACKS  ===================================================
%  =================================================================================
    % ===== HIGH-PASS CHECK BOX =====
    function CheckHighPass_Callback(varargin)
        global GlobalData;
        GlobalData.VisualizationFilters.HighPassEnabled = jCheckHighpass.isSelected();
        UpdatePanel();
        ApplyFilters();
    end
    % ===== LOW-PASS CHECK BOX =====
    function CheckLowPass_Callback(varargin)
        global GlobalData;
        GlobalData.VisualizationFilters.LowPassEnabled = jCheckLowpass.isSelected();
        UpdatePanel();
        ApplyFilters();
    end
    % ===== SIN REMOVAL CHECK BOX =====
    function CheckSinRemoval_Callback(varargin)
        global GlobalData;
        GlobalData.VisualizationFilters.SinRemovalEnabled = jCheckSinRem.isSelected();
        UpdatePanel();
        ApplyFilters();
    end
%     % ===== MIRROR CHECK BOX =====
%     function CheckMirror_Callback(varargin)
%         global GlobalData;
%         GlobalData.VisualizationFilters.MirrorEnabled = jCheckMirror.isSelected();
%         if GlobalData.VisualizationFilters.SinRemovalEnabled || GlobalData.VisualizationFilters.LowPassEnabled || GlobalData.VisualizationFilters.HighPassEnabled
%             ApplyFilters();
%         end
%     end
    % ===== FULL SOURCES CHECKBOX =====
    function CheckFullSources_Callback(varargin)
        global GlobalData;
        GlobalData.VisualizationFilters.FullSourcesEnabled = jCheckFullSources.isSelected();
        if GlobalData.VisualizationFilters.SinRemovalEnabled || GlobalData.VisualizationFilters.LowPassEnabled || GlobalData.VisualizationFilters.HighPassEnabled
            ApplyFilters();
        end
    end
end

%% =================================================================================
%  === EXTERNAL PANEL CALLBACKS  ===================================================
%  =================================================================================
%% ===== TIME WINDOWS CHANGED CALLBACK =====
function TimeWindowChangedCallback() %#ok<DEFNU>
    global GlobalData;
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Filter');
    if isempty(ctrl)
        return;
    end
    % Nothing interesting to update
    if (GlobalData.UserTimeWindow.NumberOfSamples <= 2)
        return;
    end
    % Enables the controls
    ctrl.jTextHighpass.setEnabled(1);
    ctrl.jTextLowpass.setEnabled(1);
    ctrl.jTextSinRem.setEnabled(1);
    % Compute min and max frequency cut for this time window
    fBounds = {0, round(1/3 * 1/GlobalData.UserTimeWindow.SamplingRate), 100};
    % Bound current filters values
    GlobalData.VisualizationFilters.HighPassValue = bst_saturate(GlobalData.VisualizationFilters.HighPassValue, [fBounds{1}, fBounds{2}]);
    GlobalData.VisualizationFilters.LowPassValue  = bst_saturate(GlobalData.VisualizationFilters.LowPassValue,  [fBounds{1}, fBounds{2}]);
    % Set validating functions
    gui_validate_text(ctrl.jTextHighpass, [], [], fBounds, 'Hz',     [], GlobalData.VisualizationFilters.HighPassValue,   @(h,ev)ValidateFilters('highpass'));
    gui_validate_text(ctrl.jTextLowpass,  [], [], fBounds, 'Hz',     [], GlobalData.VisualizationFilters.LowPassValue,    @(h,ev)ValidateFilters('lowpass'));
    gui_validate_text(ctrl.jTextSinRem,   [], [], fBounds, 'Hzlist', [], GlobalData.VisualizationFilters.SinRemovalValue, @(h,ev)ValidateFilters('sinrem'));
    % Update panel
    UpdatePanel();
end


%% ===== VALIDATE FILTERS =====
function ValidateFilters(src)
    global GlobalData;
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Filter');
    if isempty(ctrl)
        return
    end
    % Get new values from controls
    HighPass = str2double(char(ctrl.jTextHighpass.getText()));
    LowPass  = str2double(char(ctrl.jTextLowpass.getText()));
    SinRem   = str2num(char(ctrl.jTextSinRem.getText()));
    if isnan(HighPass) || isnan(LowPass)
        return
    end
    SinRem = setdiff(unique(SinRem), 0);
    isUpdate = 0;
    % Fix invalid band pass properties
    if (LowPass - HighPass < 1)
        if strcmpi(src, 'highpass')
            LowPass = HighPass + 1;
            ctrl.jTextLowpass.setText(sprintf('%1.2f', LowPass));
        else
            HighPass = LowPass - 1;
            ctrl.jTextHighpass.setText(sprintf('%1.2f', HighPass));
        end
        isUpdate = 1;
    end
    % Save new values of the filters + update figures
    if ~isequal(GlobalData.VisualizationFilters.HighPassValue, HighPass) 
        GlobalData.VisualizationFilters.HighPassValue = HighPass;
        isUpdate = isUpdate || GlobalData.VisualizationFilters.HighPassEnabled;
    end
    if ~isequal(GlobalData.VisualizationFilters.LowPassValue, LowPass) 
        GlobalData.VisualizationFilters.LowPassValue = LowPass;
        isUpdate = isUpdate || GlobalData.VisualizationFilters.LowPassEnabled;
    end
    if ~isequal(GlobalData.VisualizationFilters.SinRemovalValue, SinRem) 
        GlobalData.VisualizationFilters.SinRemovalValue = SinRem;
        isUpdate = isUpdate || GlobalData.VisualizationFilters.SinRemovalEnabled;
    end
    if isUpdate
        ApplyFilters();
    end
end

%% ===== UPDATE CALLBACK =====
function UpdatePanel()
    global GlobalData;
    % Get filters configuration
    Filters = GlobalData.VisualizationFilters;
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Filter');
    if isempty(ctrl)
        return
    end
    % Set current values
    ctrl.jCheckHighpass.setSelected(Filters.HighPassEnabled);
    ctrl.jCheckLowpass.setSelected(Filters.LowPassEnabled);
    ctrl.jCheckSinRem.setSelected(Filters.SinRemovalEnabled);
    % ctrl.jCheckMirror.setSelected(Filters.MirrorEnabled);
    ctrl.jCheckFullSources.setSelected(Filters.FullSourcesEnabled);
    % Change tab color
    if (Filters.HighPassEnabled || Filters.LowPassEnabled || (Filters.SinRemovalEnabled && ~isempty(Filters.SinRemovalValue)))
        color = [.7 0 0];
    else
        color = [0 0 0];
    end
    gui_brainstorm('SetToolTabColor', 'Filter', color);
end


%% ===== FOCUS CHANGED ======
function FocusChangedCallback(isFocused) %#ok<DEFNU>
    UpdatePanel();
end


%% ===== APPLY FILTERS =====
function ApplyFilters(varargin)
    % Display progress bar
    bst_progress('start', 'Visualization filters', 'Applying filters...');
    % Reload all the datasets, to apply the new filters
    bst_memory('ReloadAllDataSets');
    % Notify all the figures that they should be redrawn
    % bst_figures('ReloadFigures', [], 0);
    bst_figures('ReloadFigures');
    drawnow;
    % Hide progress bar
    bst_progress('stop');
end


%% ===== SET FILTERS =====
% USAGE: SetFilters(LowPassEnabled=[], LowPassValue=[], HighPassEnable=[], HighPassValue=[], SinRemovalEnabled=[], SinRemovalValue=[], MirrorEnabled=[], FullSourcesEnabled=[])
function SetFilters(LowPassEnabled, LowPassValue, HighPassEnabled, HighPassValue, SinRemovalEnabled, SinRemovalValue, MirrorEnabled, FullSourcesEnabled)
    global GlobalData;
    if (nargin >= 1) && ~isempty(LowPassEnabled)
        GlobalData.VisualizationFilters.LowPassEnabled = LowPassEnabled;
    end
    if (nargin >= 2) && ~isempty(LowPassValue)
        GlobalData.VisualizationFilters.LowPassValue = LowPassValue;
    end
    if (nargin >= 3) && ~isempty(HighPassEnabled)
        GlobalData.VisualizationFilters.HighPassEnabled = HighPassEnabled;
    end
    if (nargin >= 4) && ~isempty(HighPassValue)
        GlobalData.VisualizationFilters.HighPassValue = HighPassValue;
    end
    if (nargin >= 5) && ~isempty(SinRemovalEnabled)
        GlobalData.VisualizationFilters.SinRemovalEnabled = SinRemovalEnabled;
    end
    if (nargin >= 6) && ~isempty(SinRemovalValue)
        GlobalData.VisualizationFilters.SinRemovalValue = SinRemovalValue;
    end
    if (nargin >= 7) && ~isempty(MirrorEnabled)
        GlobalData.VisualizationFilters.MirrorEnabled = MirrorEnabled;
    end
    if (nargin >= 8) && ~isempty(FullSourcesEnabled)
        GlobalData.VisualizationFilters.FullSourcesEnabled = FullSourcesEnabled;
    end
    UpdatePanel();
    ApplyFilters();
end



