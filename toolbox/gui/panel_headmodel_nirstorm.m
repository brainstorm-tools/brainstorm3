function varargout = panel_headmodel_nirstorm(varargin)
% panel_headmodel_nirstorm: Options for the construction of nirs headmodel (GUI).
% 
% USAGE:  bstPanelNew = panel_headmodel_nirstorm('CreatePanel')
%                   s = panel_headmodel_nirstorm('GetPanelContents')

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
% Authors: Edouard Delaire, 2025
%          Raymundo Cassani, 2025

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(sProcess, sFiles)  %#ok<DEFNU>  
    panelName = 'HeadModelNirsOptions';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    % Create main main panel
    jPanelNew = gui_river();
    % Default  options
    if nargin >= 1 && isfield(sProcess,'options') && ~isempty(sProcess.options) && isfield(sProcess.options, 'nirstorm') && ~isempty(sProcess.options.nirstorm)
        OPTIONS = sProcess.options.nirstorm.Value;
    else
        OPTIONS = GetDefaultOption();
    end
    % Fluence data source panel
    jPanelSource = gui_river([4,4], [3,15,10,10], 'Fluence data source');
    jButtonGroupSrc = ButtonGroup();
    jRadioUrl = gui_component('radio', jPanelSource, 'br', 'URL', jButtonGroupSrc, [], @(h,ev)UpdatePanel(), []);
    jRadioDir = gui_component('radio', jPanelSource, [], 'Path', jButtonGroupSrc, [], @(h,ev)UpdatePanel(), []);
    % Panel to hold URL or Dir panels
    jPanelInput = java_create('javax.swing.JPanel');
    jPanelInput.setLayout(GridBagLayout());
    c = GridBagConstraints();
    c.fill    = GridBagConstraints.HORIZONTAL;
    c.weightx = 1;
    c.weighty = 0;
    c.gridx   = 0;
    c.gridy   = 0;
    % URL panel
    jPanelUrl = gui_river([4,4], [5,5,5,5], '');
    jTextUrl = gui_component('text', [], '', 'https://neuroimage.usc.edu/resources/nst_data/fluence/MRI__Colin27_4NIRS/', [], [], [], []);
    jPanelUrl.add('hfill', jTextUrl);
    % Dir panel
    LastUsedDirs = bst_get('LastUsedDirs');
    jPanelDir = gui_river([4,4], [5,5,5,5], '');
    jTextDir = gui_component('text', [], '', LastUsedDirs.ImportData, [], [], [], []);
    jPanelDir.add('hfill', jTextDir);
    gui_component('button', jPanelDir, '', '...', [],[], @(h,ev)PickDir_Callback());
    % Add in same place, but URL panel (default) is added at the last, so it is shown on top of Dir panel
    jPanelInput.add(jPanelDir, c);
    jPanelInput.add(jPanelUrl, c);
    jPanelSource.add('br hfill', jPanelInput);
    jPanelNew.add('br hfill', jPanelSource);
    % Default: URL
    jRadioUrl.setSelected(1);
    jPanelDir.setVisible(0);
    % Smoothing panel
    % method
    jPanelSmooth = gui_river([4,4], [3,15,10,10], 'Spatial smoothing');
    jGroupRadio = ButtonGroup();
    jRadioGeodesic = gui_component('radio', jPanelSmooth, 'br', '<HTML>Geodesic (recommended)</HTML>', jGroupRadio, [], [], []);
    jRadioGeodesic.setSelected(strcmp(OPTIONS.smoothing_method, 'geodesic_dist'))
    jRadioSurfstat = gui_component('radio', jPanelSmooth, 'br', '<HTML><FONT color="#777777">Before 2023 (not recommended)</FONT></HTML>', jGroupRadio, [], [], []);
    jRadioSurfstat.setSelected(strcmp(OPTIONS.smoothing_method, 'surfstat_before_2023'))
    gui_component('label', jPanelSmooth, 'br');
    gui_component('label', jPanelSmooth, 'br');
    % fwhm
    gui_component('label', jPanelSmooth, '', 'FWHM: ', [], [], [], []);
    jSmoothingFwhm = gui_component('text', jPanelSmooth, 'tab', num2str(OPTIONS.smoothing_fwhm), [], [], [], []);
    gui_component('label', jPanelSmooth, '', 'mm', [], [], [], []);
    jPanelNew.add('br hfill', jPanelSmooth);

    % ===== VALIDATION BUTTONS =====
    gui_component('button', jPanelNew, 'br right', 'Cancel', [], [], @ButtonCancel_Callback, []);
    gui_component('button', jPanelNew, [], 'OK', [], [], @ButtonOk_Callback, []);

    % ===== PANEL CREATION =====
    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    ctrl = struct('jRadioUrl',      jRadioUrl, ...
                  'jRadioDir',      jRadioDir, ...
                  'jTextUrl',       jTextUrl, ...
                  'jTextDir',       jTextDir, ...
                  'jSmoothingFwhm', jSmoothingFwhm, ...
                  'jRadioGeodesic', jRadioGeodesic, ...
                  'jRadioSurfstat', jRadioSurfstat );
    bstPanelNew = BstPanel(panelName, jPanelNew, ctrl);

   
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
        % Fluence data source
        if jRadioUrl.isSelected()
            jPanelDir.setVisible(0);
            jPanelUrl.setVisible(1);
        elseif jRadioDir.isSelected()
            jPanelUrl.setVisible(0);
            jPanelDir.setVisible(1);
        end
    end

%% ====== PICK DIR =====
    function PickDir_Callback()
        LastUsedDirs = bst_get('LastUsedDirs');
        strFluenceDir = java_getfile('open', 'Select fluence directory', LastUsedDirs.ImportData, 'single', 'dirs', {{'*'}, 'Fluence directory', 'directory'}, 0);
        if ~isempty(strFluenceDir)
            jTextDir.setText(strFluenceDir);
            LastUsedDirs.ImportData = strFluenceDir;
            bst_set('LastUsedDirs', LastUsedDirs);
        end
    end
end



%% =================================================================================
%  === EXTERNAL CALLBACKS ==========================================================
%  =================================================================================   
%% ===== GET DEFAULT OPTIONS =====
function s = GetDefaultOption()
    % Use defined options
    s = struct();
    s.FluenceFolder    = 'https://neuroimage.usc.edu/resources/nst_data/fluence/';
    s.smoothing_method = 'geodesic_dist';
    s.smoothing_fwhm   = 10;
end


%% ===== GET PANEL CONTENTS =====
function s = GetPanelContents() %#ok<DEFNU>
    % Get panel controls
    ctrl = bst_get('PanelControls', 'HeadModelNirsOptions');
    s = GetDefaultOption();
    % Fluence data source
    if ctrl.jRadioUrl.isSelected()
        s.FluenceFolder = char(ctrl.jTextUrl.getText());
    elseif ctrl.jRadioDir.isSelected()
        s.FluenceFolder = char(ctrl.jTextDir.getText());
    else
        error('You must select a source for fluence data');
    end
    % Smoothing method
    if ctrl.jRadioGeodesic.isSelected()
        s.smoothing_method = 'geodesic_dist';
    elseif ctrl.jRadioSurfstat.isSelected()
        s.smoothing_method = 'surfstat_before_2023';
    else
        error('You must select a smoothing method');
    end
    % Spatial smoothing
    s.smoothing_fwhm = str2double(ctrl.jSmoothingFwhm.getText());
end

