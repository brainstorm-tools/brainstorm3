function varargout = panel_import_pet(varargin)
% PANEL_IMPORT_PET: User options for pre-processing dynamic PET volumes.
%
% USAGE: [bstPanelNew, panelName] = panel_import_pet('CreatePanel', nFrames, dispRegistration)
%
% petopts = gui_show_dialog('PET Pre-processing options', @panel_import_pet, 1, [], nFrames, dispRegistration)
%
% This panel is typically displayed using gui_show_dialog() to collect user inputs:
%   - Align PET frames (realignment)
%   - Smooth the volume using a specified FWHM kernel
%   - Aggregate aligned frames into a static volume
%   If dispRegistration == 1, the options below are also shown:
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
function [bstPanelNew, panelName] = CreatePanel(nFrames, dispRegistration)
    panelName = 'panel_import_pet';
    import java.awt.*
    import javax.swing.*
    % Handle number of frames
    isMultiFrame = nFrames > 1;
    strFrames = sprintf('%d frame', nFrames);
    if isMultiFrame
        strFrames = [strFrames 's'];
    end

    % === MAIN LAYOUT (2 PANELS) ===
    jPanelMain = gui_river([5, 5], [0, 10, 10, 10]);
    % === FRAME ALIGNMENT PANEL (1/2) ===
    jPanelAlign = gui_river([2, 2], [0, 10, 10, 10], 'Frame alignment');
    % Alignment
    gui_component('label', jPanelAlign, 'br', ...
        sprintf('<HTML><EM>Imported volume contains %s.</EM><BR></HTML>', strFrames));
    jCheckAlign = gui_component('checkbox', jPanelAlign, 'br', 'Align frames');
    jCheckAlign.setSelected(isMultiFrame);
    % Smooth
    jPanelSmooth = gui_river([0, 0], [2, 0, 0, 0]);
    jCheckSmooth = gui_component('checkbox', jPanelSmooth, 'br', 'Apply smoothing');
    jCheckSmooth.setSelected(isMultiFrame);
    jCheckSmooth.setEnabled(isMultiFrame);
    jPanelFwhm = gui_river([0, 0], [0, 15, 0, 0]);
    jLabelFwhm = gui_component('label', jPanelFwhm, 'br', 'FWHM (mm): ');
    jTextFwhm = gui_component('text', jPanelFwhm, 'tab', '8');
    jTextFwhm.setMaximumSize(java.awt.Dimension(50, 20));
    SetEnabled([jTextFwhm, jLabelFwhm], jCheckSmooth.isSelected());
    java_setcb(jCheckSmooth, 'ActionPerformedCallback', @(h, ev)SetEnabled([jTextFwhm, jLabelFwhm], jCheckSmooth.isSelected()));
    java_setcb(jCheckAlign, 'ActionPerformedCallback', @(h, ev)SetSelectedAndEnabled(jCheckSmooth, jCheckSmooth.isSelected() && jCheckAlign.isSelected(), jCheckAlign.isSelected));
    jPanelSmooth.add('br', jPanelFwhm);
    jPanelAlign.add('br', jPanelSmooth);
    % Aggregate
    jPanelAggregate = gui_river([0, 0], [2, 0, 0, 0]);
    jCheckAggregate = gui_component('checkbox', jPanelAggregate, 'br', 'Aggregate frames: ');
    jCheckAggregate.setSelected(isMultiFrame);
    jComboboxAggregate = gui_component('combobox', jPanelAggregate, 'tab', [], {{'Mean', 'Sum', 'Median', 'Max', 'Min', 'First', 'Last', 'Z-score'}});
    jComboboxAggregate.setEnabled(isMultiFrame);
    java_setcb(jCheckAggregate, 'ActionPerformedCallback', @(h, ev)jComboboxAggregate.setEnabled(jCheckAggregate.isSelected()));
    jPanelAlign.add('br', jPanelAggregate);
    % Disable entries if single frame
    if ~isMultiFrame
        SetEnabled([jPanelAlign, jCheckAlign, jPanelSmooth, jCheckSmooth, jPanelAggregate, jCheckAggregate], 0);
    end
    % === REGISTRATION PANEL (2/2) ===
    jPanelReg = gui_river('Registration');
    jCheckRegister = gui_component('checkbox', jPanelReg, 'br', 'Register to MRI using:');
    jCheckRegister.setSelected(true);
    jComboboxRegister = gui_component('combobox', jPanelReg, 'tab', [], {{'SPM', 'MNI'}});
    java_setcb(jCheckRegister, 'ActionPerformedCallback', @(h, ev)jComboboxRegister.setEnabled(jCheckRegister.isSelected()));
    jCheckReslice = gui_component('checkbox', jPanelReg, 'br', 'Reslice volume on import');
    jCheckReslice.setSelected(true);
    if ~dispRegistration
        jPanelReg.setVisible(0);
        jCheckRegister.setSelected(0);
        jCheckReslice.setSelected(0);
    end
    % Add panels to main layout
    jPanelMain.add('br', jPanelAlign);
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
        struct('jCheckAlign',        jCheckAlign, ...
               'jCheckAggregate',    jCheckAggregate, ...
               'jComboBoxAggregate', jComboboxAggregate, ...
               'jCheckSmooth',       jCheckSmooth, ...
               'jTextFwhm',          jTextFwhm, ...
               'jCheckRegister',     jCheckRegister, ...
               'jComboboxRegister',  jComboboxRegister, ...
               'jCheckReslice',      jCheckReslice));

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
    if ctrl.jCheckAlign.isSelected()
        s.align = 'spm_realign';
    else
        s.align = '';
    end
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

%% ===== SET ENABLED FOR COMPONENTS =====
function SetEnabled(components, status)
    for iComponent = 1 : length(components)
        components(iComponent).setEnabled(status);
    end
end

%% ===== SET SELECTED AND ENABLED FOR CHECK COMPONENTS =====
function SetSelectedAndEnabled(component, isSelected, isEnabled)
    % If value changed, doClick, it triggers ActionPerformedCallback
    if component.isSelected ~= isSelected
        component.doClick;
    end
    component.setEnabled(isEnabled);
end
