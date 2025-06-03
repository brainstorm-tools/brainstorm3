function varargout = panel_process_pet(varargin)
% PANEL_PROCESS_PET: GUI for PET volume rescaling/masking using atlas ROIs.
%
% USAGE: [bstPanelNew, panelName] = panel_process_pet('CreatePanel')
%
% This panel allows the user to:
%   1. Select an atlas (dropdown, populated by bst_get('AtlasFile'))
%   2. Select an ROI (dropdown, populated by mri_mask([], AtlasName))
%   3. Optionally rescale or mask a PET volume using the selected ROI
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

eval(macro_method);
end

%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(sSubject, PetFile, varargin)
    panelName = 'panel_process_pet';
    import java.awt.*
    import javax.swing.*

    % === MAIN LAYOUT ===
    jPanelMain = gui_river([5, 5], [0, 10, 10, 10]);
    gui_component('label', jPanelMain, 'br', ...
        sprintf('<HTML><EM>%s</EM><BR></HTML>', sSubject.Name));
    % === RESCALE PANEL ===
    jPanelRescale = gui_river([2, 2], [0, 10, 10, 10], 'SUVR');

    % --- Atlas dropdown ---
    sAtlas = bst_get('AtlasFile', sSubject);
    atlasNames = {sAtlas.Comment};
    if isempty(atlasNames)
        atlasNames = {'(No atlas found)'};
    end

    % --- ROI dropdown ---
    if ~isempty(atlasNames) && ~strcmp(atlasNames{1}, '(No atlas found)')
        roiList = mri_mask(PetFile, atlasNames{1});
    else
        roiList = {'(No ROI found)'};
    end
    jLabelROI = gui_component('label', jPanelRescale, 'br', 'Rescale to:');
    jComboROI = gui_component('combobox', jPanelRescale, 'tab', [], {roiList});
    % Set "Cerebellum" as default if it exists
    idxCerebellum = find(strcmpi(roiList, 'Cerebellum'), 1);
    if ~isempty(idxCerebellum)
        jComboROI.setSelectedIndex(idxCerebellum - 1); % Java indices start at 0
    end

    jLabelAtlas = gui_component('label', jPanelRescale, 'br', 'Atlas:');
    jComboAtlas = gui_component('combobox', jPanelRescale, 'tab', [], {atlasNames});
    % --- Callback: When atlas changes, update ROI list ---
    java_setcb(jComboAtlas, 'ActionPerformedCallback', @(h, ev)AtlasChanged_Callback(jComboAtlas, jComboROI, jComboROIMask, sSubject, PetFile));

    % ==== MASK PANEL ====
    jPanelMask = gui_river([2, 2], [0, 10, 10, 10], 'Volume masking');   
    jCheckMask = gui_component('checkbox', jPanelMask, 'br', 'Apply mask');
    jLabelROIMask = gui_component('label', jPanelMask, 'br', 'Mask:');
    jComboROIMask = gui_component('combobox', jPanelMask, 'tab', [], {roiList});
    jCheckMask.setSelected(false);           % Unchecked by default
    jComboROIMask.setEnabled(false);         % Disabled by default
    jLabelROIMask.setEnabled(false);         % Disabled by default
    java_setcb(jCheckMask, 'ActionPerformedCallback', @(h, ev)SetSelectedAndEnabled(jComboROIMask, jLabelROIMask, jCheckMask.isSelected()));

   
    java_setcb(jComboAtlas, 'ActionPerformedCallback', @(h, ev)AtlasChanged_Callback(jComboAtlas, jComboROI, jComboROIMask, sSubject, PetFile));

    % ==== PROJECT TO SURFACE PANEL ====
    jPanelProject = gui_river([1, 1], [0, 10, 10, 10], 'Surface projection');
    jCheckProject = gui_component('checkbox', jPanelProject, 'br', 'Project to surface');
    jCheckProject.setSelected(false);

    % --- Add panels to main layout ---
    jPanelMain.add('br', jPanelRescale);
    jPanelMain.add('br', jPanelMask);
    jPanelMain.add('br', jPanelProject);

    % --- Buttons ---
    jPanelButtons = gui_river([2 0], [0 5 0 5]);
    gui_component('button', jPanelButtons, 'br right', 'Cancel', [], [], @(h, ev)ButtonCancel_Callback(panelName));
    gui_component('button', jPanelButtons, '', 'OK', [], [], @(h, ev)ButtonOK_Callback(panelName));
    jPanelMain.add('br right', jPanelButtons);

    % --- Panel Layout ---
    jPanelRescale.doLayout();

    % --- Create mutex ---
    bst_mutex('create', panelName);

    % --- Return panel object ---
    bstPanelNew = BstPanel(panelName, ...
        jPanelMain, ...
        struct('jComboAtlas', jComboAtlas, ...
               'jComboROI', jComboROI, ...
               'jComboROIMask', jComboROIMask, ...
               'jCheckMask', jCheckMask, ...
               'jCheckProject', jCheckProject, ...
               'sSubject', sSubject, ...
               'PetFile', PetFile));
end
%% ===== CALLBACK: Atlas changed =====
function AtlasChanged_Callback(jComboAtlas, jComboROI, jComboROIMask, sSubject, PetFile)
    selectedAtlas = char(jComboAtlas.getSelectedItem());
    if isempty(selectedAtlas) || strcmp(selectedAtlas, '(No atlas found)')
        roiList = {'(No ROI found)'};
    else
        roiList = mri_mask(PetFile, selectedAtlas);
        if isempty(roiList)
            roiList = {'(No ROI found)'};
        end
    end
    jComboROI.removeAllItems();
    jComboROIMask.removeAllItems();
    for i = 1:numel(roiList)
        jComboROI.addItem(roiList{i});
        jComboROIMask.addItem(roiList{i});
    end
end

%% ===== CANCEL BUTTON =====
function ButtonCancel_Callback(panelName)
    gui_hide(panelName);
end

%% ===== OK BUTTON =====
function ButtonOK_Callback(panelName)
    ctrl = bst_get('PanelControls', panelName);
    atlas    = char(ctrl.jComboAtlas.getSelectedItem());
    roi      = char(ctrl.jComboROI.getSelectedItem());
    maskROI  = char(ctrl.jComboROIMask.getSelectedItem());
    sSubject = ctrl.sSubject;
    PetFile = ctrl.PetFile;
    isMaskChecked = ctrl.jCheckMask.isSelected();
    doProject = ctrl.jCheckProject.isSelected();

    bst_progress('start', 'PET Processing', 'Processing PET volume...');
    gui_hide(panelName);

    if ~isempty(sSubject) && ~isempty(PetFile)
        % Prepare options for process_pet
        if isempty(roi) || strcmp(roi, '(No ROI found)')
            roi = '';
        end
        if isempty(maskROI) || strcmp(maskROI, '(No ROI found)')
            maskROI = '';
        end

        % Call process_pet pipeline with projection option
        [MriFileOut, errMsg, SurfaceFileOut] = process_pet(PetFile, sSubject, atlas, roi, maskROI, isMaskChecked, doProject);

        if ~isempty(errMsg)
            bst_error(errMsg, 'PET Processing');
        else
            disp(['Processed MRI saved as: ' MriFileOut]);
            if doProject && ~isempty(SurfaceFileOut)
                disp(['Projected surface file: ' SurfaceFileOut]);
            end
        end
    end

    bst_mutex('release', panelName);
    bst_progress('stop');
end

%% ===== HELPER: Enable/disable ROI mask controls =====
function SetSelectedAndEnabled(jCombo, jLabel, isEnabled)
    jCombo.setEnabled(isEnabled);
    jLabel.setEnabled(isEnabled);
end