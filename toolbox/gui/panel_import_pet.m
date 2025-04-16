function varargout = panel_import_pet(varargin)
% PANEL_IMPORT_PET: User options for pre-processing dynamic PET volumes.
%
% USAGE: [bstPanelNew, panelName] = panel_import_pet('CreatePanel', nFrames)
%
% petopts = gui_show_dialog('PET Pre-processing Options', @panel_import_pet, 1, [], nFrames)
% This panel is typically displayed using gui_show_dialog() to collect user inputs:
%   - Align PET frames (realignment)
%   - Smooth the volume using a specified FWHM kernel
%   - Aggregate aligned frames into a static volume
%   - Register the PET volume to the default MRI
%   - Choose whether to reslice the volume on import
%
% The panel contents are returned as a structure using GetPanelContents
%

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
% Authors: Diellor Basha, 2025
%          Raymundo Cassani, 2025

eval(macro_method);
end

%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(nFrames)
panelName = 'panel_import_pet';
import java.awt.*
import javax.swing.*
% === Main layout ===
jPanelMain = gui_river([5, 5], [0, 10, 10, 10]);
% === FRAME ALIGNMENT & SMOOTHING ===
if nFrames > 1
    jPanelAlign = gui_river([2, 2], [0, 10, 10, 10], 'Frame Alignment');
    gui_component('label', jPanelAlign, 'br', ...
        sprintf('<HTML><EM>Imported volume contains %d frames.</EM><BR></HTML>', nFrames));
    jCheckAlign = gui_component('checkbox', jPanelAlign, 'br', 'Align frames');
    jCheckAlign.setSelected(true);

    jPanelAggregate = gui_river([0, 0], [2, 0, 0, 0]);
    jCheckAggregate = gui_component('checkbox', jPanelAggregate, 'br', 'Aggregate frames: ');
    jCheckAggregate.setSelected(true);
    jComboboxAggregate = gui_component('combobox', jPanelAggregate, 'tab', [], {{'Mean', 'Sum', 'Median', 'Max', 'Min', 'First', 'Last', 'Z-score'}});
    set(handle(jCheckAggregate, 'CallbackProperties'), 'ActionPerformedCallback', ...
        @(src, evt) jComboboxAggregate.setEnabled(jCheckAggregate.isSelected()));

    jPanelSmooth = gui_river([0, 0], [2, 0, 0, 0]);
    jCheckSmooth = gui_component('checkbox', jPanelSmooth, 'br', 'Apply smoothing');
    jCheckSmooth.setSelected(false);
    set(handle(jCheckAlign, 'CallbackProperties'), 'ActionPerformedCallback', ...
        @(src, evt) jCheckSmooth.setEnabled(jCheckAlign.isSelected()));
    jPanelFwhm = gui_river([0, 0], [0, 15, 0, 0]);
    gui_component('label', jPanelFwhm, 'br', 'FWHM (mm): ');
    jTextFwhm = gui_component('text', jPanelFwhm, 'tab', '8');
    jTextFwhm.setMaximumSize(java.awt.Dimension(50, 20));
    jTextFwhm.setEnabled(false);
    set(handle(jCheckSmooth, 'CallbackProperties'), 'ActionPerformedCallback', ...
        @(src, evt) jTextFwhm.setEnabled(jCheckSmooth.isSelected()));
    jPanelSmooth.add('br', jPanelFwhm);
    jPanelAlign.add('br', jPanelSmooth);
    jPanelAlign.add('br', jPanelAggregate);
    jPanelMain.add('br', jPanelAlign);
else
    jCheckAlign = [];
    jCheckAggregate = [];
    jCheckSmooth = [];
    jTextFwhm = [];
end
% === REGISTRATION PANEL ===
jPanelReg = gui_river('Registration');
jCheckRegister = gui_component('checkbox', jPanelReg, 'br', 'Register to MRI using:');
jCheckRegister.setSelected(true);
jComboboxRegister = gui_component('combobox', jPanelReg, 'tab', [], {{'SPM', 'MNI'}});
    set(handle(jCheckRegister, 'CallbackProperties'), 'ActionPerformedCallback', ...
        @(src, evt) jComboboxRegister.setEnabled(jCheckRegister.isSelected()));
jCheckReslice = gui_component('checkbox', jPanelReg, 'br', 'Reslice volume on import');
jCheckReslice.setSelected(true);
jPanelMain.add('br', jPanelReg);
% === BUTTONS ===
jPanelButtons = gui_river([2 0], [0 5 0 5]);
gui_component('button', jPanelButtons, 'br right', 'Cancel', [], [], @ButtonCancel_Callback);
gui_component('button', jPanelButtons, '', 'Import', [], [], @ButtonImport_Callback);
jPanelMain.add('br right', jPanelButtons);
% === Panel Layout  ===
if ~isempty(jCheckAlign)
    jPanelAlign.doLayout();
    jPanelReg.doLayout();
    maxWidth = max([jPanelAlign.getPreferredSize().width, jPanelReg.getPreferredSize().width]);
    jPanelAlign.setPreferredSize(java.awt.Dimension(maxWidth, jPanelAlign.getPreferredSize().height));
    jPanelReg.setPreferredSize(java.awt.Dimension(maxWidth, jPanelReg.getPreferredSize().height));
end
% === Create mutex ===
bst_mutex('create', panelName);
% === Return panel object ===
bstPanelNew = BstPanel(panelName, ...
    jPanelMain, ...
    struct('jCheckAlign', jCheckAlign, ...
    'jCheckAggregate', jCheckAggregate, ...
    'jComboBoxAggregate', jComboboxAggregate, ...
    'jCheckSmooth', jCheckSmooth, ...
    'jTextFwhm', jTextFwhm, ...
    'jCheckRegister', jCheckRegister, ...
    'jComboboxRegister', jComboboxRegister, ...
    'jCheckReslice', jCheckReslice));

%% =================================================================================
%  === INTERNAL CALLBACKS ==========================================================
%  =================================================================================
%% ===== CANCEL BUTTON =====
    function ButtonCancel_Callback(~, ~)
        gui_hide(panelName);
    end

%% ===== IMPORT BUTTON =====
    function ButtonImport_Callback(~, ~)
        bst_mutex('release', panelName);  % Triggers gui_show_dialog to call GetPanelContents
    end
end

%% =================================================================================
%  === EXTERNAL CALLBACKS ==========================================================
%  =================================================================================
%% ===== GET PANEL CONTENTS =====
function s = GetPanelContents()
   % Get panel controls
    ctrl = bst_get('PanelControls', 'panel_import_pet');
    % Get import PET options
    s.align    = ctrl.jCheckAlign.isSelected();
    s.fwhm     = ctrl.jCheckSmooth.isSelected() * str2double(char(ctrl.jTextFwhm.getText()));
    if ctrl.jCheckAggregate.isSelected()
    s.aggregate = lower(char(ctrl.jComboBoxAggregate.getSelectedItem()));
    else
    s.aggregate = 'ignore';
    end
    if ctrl.jCheckRegister.isSelected()
    s.register = lower(char(ctrl.jComboboxRegister.getSelectedItem()));
    else
    s.register = 'ignore';
    end
    s.reslice  = ctrl.jCheckReslice.isSelected();
end
