function varargout = panel_process_pet(varargin)
% PANEL_PROCESS_PET: GUI for PET volume rescaling/masking using an anatomical atlas.
%
% USAGE: [bstPanelNew, panelName] = panel_process_pet('CreatePanel')
%
% This panel allows the user to:
%   1. Select an anatomical atlas
%   2. Select a parcellations from such atlas
%   3. (Optionally) rescale or mask a PET volume using the selected parcellation
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
function [bstPanelNew, panelName] = CreatePanel(PetFile, varargin)
    panelName = 'panel_process_pet';
    import java.awt.*
    import javax.swing.*

    % Get Subject for PET file
    [sSubject, iSubject] = bst_get('MriFile', PetFile);

    % === MAIN LAYOUT ===
    jPanelMain = gui_river([5, 5], [0, 10, 10, 10]);
    jPanelMain.setLayout(GridBagLayout());
    jPanelMain.setBorder(BorderFactory.createEmptyBorder(12,12,12,12));
    % Default constrains
    c = GridBagConstraints();
    c.fill    = GridBagConstraints.HORIZONTAL;
    c.weightx = 1;
    c.weighty = 0;

    % === RESCALE PANEL ===
    jPanelRescale = gui_river([2, 2], [0, 10, 10, 10], 'SUVR');
    gui_component('label', jPanelRescale, 'br', ...
        sprintf('<HTML><FONT color="#777777">%s</FONT><BR><BR></HTML>', '(Standardized uptake value ratio)'));
    % Atlases
    sAtlases = sSubject.Anatomy(~cellfun(@isempty, strfind({sSubject.Anatomy.FileName}, '_volatlas')));
    atlasNames = {sAtlases.Comment};
    if isempty(atlasNames)
        atlasNames = {'(No atlas found)'};
    end
    % ROIs in Atlas
    if ~isempty(atlasNames) && ~strcmp(atlasNames{1}, '(No atlas found)')
        roiList = mri_mask(PetFile, sAtlases(1).FileName);
    else
        roiList = {'(No ROI found)'};
    end
    % --- Atlas dropdown ---
    gui_component('label', jPanelRescale, 'br', 'Atlas:');
    jComboAtlas = gui_component('combobox', jPanelRescale, 'tab', [], {atlasNames});
    % --- ROI dropdown ---
    gui_component('label', jPanelRescale, 'br', 'Rescale to:');
    jComboROI = gui_component('combobox', jPanelRescale, 'tab', [], {roiList});
    % Set "Cerebellum" as default if it exists
    idxCerebellum = find(strcmpi(roiList, 'Cerebellum'), 1);
    if ~isempty(idxCerebellum)
        jComboROI.setSelectedIndex(idxCerebellum - 1); % Java indices start at 0
    end

    % ==== MASK PANEL ====
    jPanelMask = gui_river([2, 2], [0, 10, 10, 10], 'Volume masking');   
    jCheckMask = gui_component('checkbox', jPanelMask, 'br', 'Apply mask');
    jLabelROIMask = gui_component('label', jPanelMask, 'br', 'Mask:');
    jComboROIMask = gui_component('combobox', jPanelMask, 'tab', [], {roiList});
    jCheckMask.setSelected(false);           % Unchecked by default
    jComboROIMask.setEnabled(false);         % Disabled by default
    jLabelROIMask.setEnabled(false);         % Disabled by default
    java_setcb(jCheckMask, 'ActionPerformedCallback', @(h, ev)SetSelectedAndEnabled(jComboROIMask, jLabelROIMask, jCheckMask.isSelected()));

    % --- Callback: When atlas changes, update ROI list ---
    java_setcb(jComboAtlas, 'ActionPerformedCallback', @(h, ev)AtlasChanged_Callback(jComboAtlas, jComboROI, jComboROIMask, PetFile, sAtlases));

    % ==== PROJECT TO SURFACE PANEL ====
    jPanelProject = gui_river([1, 1], [0, 10, 10, 10], 'Surface projection');
    jCheckProject = gui_component('checkbox', jPanelProject, 'br', 'Project to surface');
    jCheckProject.setSelected(false);

    % --- Buttons ---
    jPanelButtons = gui_river([2 0], [0 5 0 5]);
    gui_component('button', jPanelButtons, 'br right', 'Cancel', [], [], @(h, ev)ButtonCancel_Callback(panelName));
    gui_component('button', jPanelButtons, '', 'OK', [], [], @(h, ev)ButtonOK_Callback(panelName));

    % --- Add panels to main layout ---
    c.gridy = 1;
    jPanelMain.add(jPanelRescale, c);
    c.gridy = 2;
    jPanelMain.add(jPanelMask, c);
    c.gridy = 3;
    jPanelMain.add(jPanelProject, c);
    c.gridy = 4;
    jPanelMain.add(jPanelButtons, c);

    % --- Panel Layout ---
    jPanelRescale.doLayout();

    % --- Create mutex ---
    bst_mutex('create', panelName);

    % --- Return panel object ---
    bstPanelNew = BstPanel(panelName, ...
        jPanelMain, ...
        struct('jComboAtlas',   jComboAtlas, ...
               'jComboROI',     jComboROI, ...
               'jComboROIMask', jComboROIMask, ...
               'jCheckMask',    jCheckMask, ...
               'jCheckProject', jCheckProject, ...
               'PetFile',       PetFile));
end

%% ===== CALLBACK: Atlas changed =====
function AtlasChanged_Callback(jComboAtlas, jComboROI, jComboROIMask, PetFile, sAtlases)
    selectedAtlas = char(jComboAtlas.getSelectedItem());
    if isempty(selectedAtlas) || strcmp(selectedAtlas, '(No atlas found)')
        roiList = {'(No ROI found)'};
    else
        iAtlas = find(strcmpi({sAtlases.Comment}, selectedAtlas), 1);
        roiList = mri_mask(PetFile, sAtlases(iAtlas).FileName);
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
    atlas         = char(ctrl.jComboAtlas.getSelectedItem());
    roi           = char(ctrl.jComboROI.getSelectedItem());
    maskROI       = char(ctrl.jComboROIMask.getSelectedItem());
    PetFile       = ctrl.PetFile;
    isMaskChecked = ctrl.jCheckMask.isSelected();
    doProject     = ctrl.jCheckProject.isSelected();

    bst_progress('start', 'PET Processing', 'Processing PET volume...');
    gui_hide(panelName);

    if ~isempty(PetFile)
        % Prepare options for pet_process
        if isempty(roi) || strcmp(roi, '(No ROI found)')
            roi = '';
        end
        if isempty(maskROI) || strcmp(maskROI, '(No ROI found)')
            maskROI = '';
        end

        % Call pet_process pipeline with projection option
        [MriFileOut, errMsg, SurfaceFileOut] = pet_process(PetFile, atlas, roi, maskROI, isMaskChecked, doProject);

        if ~isempty(errMsg)
            bst_error(errMsg, 'PET Processing');
        else
            disp(['Processed PET saved as: ' file_short(MriFileOut)]);
            if doProject && ~isempty(SurfaceFileOut)
                disp(['Projected surface file: ' file_short(SurfaceFileOut)]);
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