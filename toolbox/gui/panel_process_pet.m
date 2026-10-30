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
    % --- Reference estimator ---
    gui_component('label', jPanelRescale, 'br', 'Reference:');
    jComboRef = gui_component('combobox', jPanelRescale, 'tab', [], ...
        {{'Robust (1-voxel erosion, 10% trimmed mean)', 'Plain mean (as in previous versions)'}});

    % ==== PVC PANEL ====
    jPanelPvc = gui_river([2, 2], [0, 10, 10, 10], 'Partial volume correction');
    jCheckPvc = gui_component('checkbox', jPanelPvc, 'br', 'Apply PVC');
    jCheckPvc.setSelected(false);
    % Method: GTM (default, no plugin) or Muller-Gartner (SPM12 + PETPVE12)
    jLabelMethod = gui_component('label', jPanelPvc, 'br', 'Method:');
    jComboMethod = gui_component('combobox', jPanelPvc, 'tab', [], ...
        {{'GTM (regional, Desikan-Killiany)', 'Muller-Gartner (requires SPM12 + PETPVE12)'}});
    jLabelMethod.setEnabled(false);
    jComboMethod.setEnabled(false);
    % PSF FWHM: scanner resolution found at import from the PET metadata, shown with its source
    PET = [];
    warning('off', 'MATLAB:load:variableNotFound');
    w = load(file_fullpath(PetFile), 'PET');
    warning('on', 'MATLAB:load:variableNotFound');
    if isfield(w, 'PET') && isstruct(w.PET)
        PET = w.PET;
        PET.SmoothFwhm = [];   % Scanner only: the recorded smoothing is added by pet_pvc
    end
    [scanFwhm, scanSrc, isFwhmKnown] = pet_helper('PsfFwhm', PET);
    jLabelFwhm = gui_component('label', jPanelPvc, 'br', 'Scanner PSF FWHM (mm):');
    jTextFwhm = gui_component('text', jPanelPvc, 'tab', num2str(scanFwhm));
    jTextFwhm.setPreferredSize(java.awt.Dimension(50, 22));
    jTextFwhm.setToolTipText('<HTML>Resolution of the scanner and reconstruction.<BR>Smoothing recorded in the history is added in quadrature.');
    if isFwhmKnown
        strFwhm = ['<HTML><FONT color="#777777">Scanner: ' scanSrc '</FONT>'];
    else
        strFwhm = ['<HTML><FONT color="#C00000"><B>Scanner not identified:</B> ' sprintf('%g', scanFwhm) ...
                   ' mm is a generic default.<BR>Enter the PSF FWHM of your scanner.</FONT>'];
    end
    gui_component('label', jPanelPvc, 'br', strFwhm);
    jLabelFwhm.setEnabled(false);
    jTextFwhm.setEnabled(false);
    % CSF zeroing
    jCheckCsfZero = gui_component('checkbox', jPanelPvc, 'br', 'Assume CSF signal = 0');
    jCheckCsfZero.setSelected(true);
    jCheckCsfZero.setEnabled(false);
    % Advanced toggle
    jCheckAdvanced = gui_component('checkbox', jPanelPvc, 'br', 'Advanced options');
    jCheckAdvanced.setSelected(false);
    jCheckAdvanced.setEnabled(false);
    % Advanced panel (hidden by default)
    jPanelAdvanced = gui_river([0, 0], [0, 15, 0, 0]);
    % GM threshold
    jLabelGmThresh = gui_component('label', jPanelAdvanced, 'br', 'GM threshold:');
    jTextGmThresh = gui_component('text', jPanelAdvanced, 'tab', '0.5');
    jTextGmThresh.setPreferredSize(java.awt.Dimension(50, 22));
    % WM/CSF method
    jLabelWmMethod = gui_component('label', jPanelAdvanced, 'br', 'WM/CSF method:');
    jComboWmMethod = gui_component('combobox', jPanelAdvanced, 'tab', [], {{'Threshold', 'Erode'}});
    % WM/CSF threshold
    jLabelWmThresh = gui_component('label', jPanelAdvanced, 'br', 'WM/CSF threshold:');
    jTextWmThresh = gui_component('text', jPanelAdvanced, 'tab', '0.5');
    jTextWmThresh.setPreferredSize(java.awt.Dimension(50, 22));
    % Initially hide advanced panel
    jPanelAdvanced.setVisible(false);
    jPanelPvc.add('br', jPanelAdvanced);
    % Callbacks: PVC checkbox enables/disables all PVC controls
    java_setcb(jCheckPvc, 'ActionPerformedCallback', @(h, ev)PvcCheckChanged_Callback( ...
        jCheckPvc, jLabelMethod, jComboMethod, jLabelFwhm, jTextFwhm, jCheckCsfZero, jCheckAdvanced, jPanelAdvanced, ...
        jLabelGmThresh, jTextGmThresh, jLabelWmMethod, jComboWmMethod, jLabelWmThresh, jTextWmThresh));
    java_setcb(jComboMethod, 'ActionPerformedCallback', @(h, ev)PvcCheckChanged_Callback( ...
        jCheckPvc, jLabelMethod, jComboMethod, jLabelFwhm, jTextFwhm, jCheckCsfZero, jCheckAdvanced, jPanelAdvanced, ...
        jLabelGmThresh, jTextGmThresh, jLabelWmMethod, jComboWmMethod, jLabelWmThresh, jTextWmThresh));
    % Callback: Advanced toggle shows/hides advanced panel
    java_setcb(jCheckAdvanced, 'ActionPerformedCallback', @(h, ev)jPanelAdvanced.setVisible(jCheckAdvanced.isSelected()));

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
    jPanelMain.add(jPanelPvc, c);
    c.gridy = 3;
    jPanelMain.add(jPanelMask, c);
    c.gridy = 4;
    jPanelMain.add(jPanelProject, c);
    c.gridy = 5;
    jPanelMain.add(jPanelButtons, c);

    % --- Panel Layout ---
    jPanelRescale.doLayout();

    % --- Create mutex ---
    bst_mutex('create', panelName);

    % --- Return panel object ---
    bstPanelNew = BstPanel(panelName, ...
        jPanelMain, ...
        struct('jComboAtlas',    jComboAtlas, ...
               'jComboROI',      jComboROI, ...
               'jComboROIMask',  jComboROIMask, ...
               'jCheckMask',     jCheckMask, ...
               'jCheckProject',  jCheckProject, ...
               'jComboRef',      jComboRef, ...
               'jCheckPvc',      jCheckPvc, ...
               'jComboMethod',   jComboMethod, ...
               'jTextFwhm',      jTextFwhm, ...
               'jCheckCsfZero',  jCheckCsfZero, ...
               'jCheckAdvanced', jCheckAdvanced, ...
               'jTextGmThresh',  jTextGmThresh, ...
               'jComboWmMethod', jComboWmMethod, ...
               'jTextWmThresh',  jTextWmThresh, ...
               'PetFile',        PetFile, ...
               'ScanFwhm',       scanFwhm, ...
               'IsFwhmKnown',    isFwhmKnown));
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
    doPvc         = ctrl.jCheckPvc.isSelected();

    % Gather PVC options
    pvcOpts = struct('method', 'none');
    if (ctrl.jComboRef.getSelectedIndex() == 1)
        pvcOpts.SuvrOpts = struct('Reference', 'plain');
    else
        pvcOpts.SuvrOpts = struct('Reference', 'robust');
    end
    if doPvc
        if (ctrl.jComboMethod.getSelectedIndex() == 1)
            pvcOpts.method = 'mg';
        else
            pvcOpts.method = 'gtm';
        end
        fwhmStr = strtrim(char(ctrl.jTextFwhm.getText()));
        pvcOpts.fwhm = str2double(fwhmStr);
        if strcmpi(fwhmStr, 'auto') || (pvcOpts.fwhm == ctrl.ScanFwhm)
            pvcOpts.fwhm = [];   % Value from the metadata: keep its source in the history
            % Scanner not identified: the generic default must be confirmed
            if ~ctrl.IsFwhmKnown && ~java_dialog('confirm', ['The PET scanner was not identified from the metadata.' 10 10 ...
                    sprintf('Use the generic default PSF FWHM of %g mm?', ctrl.ScanFwhm) 10 ...
                    'A PSF larger than the true resolution over-corrects (negative regional values).'], 'Partial volume correction')
                return;
            end
        elseif isnan(pvcOpts.fwhm) || (pvcOpts.fwhm <= 0)
            bst_error('PSF FWHM must be a positive number.', 'PET Processing');
            return;
        end
        pvcOpts.csfZeroing  = ctrl.jCheckCsfZero.isSelected();
        pvcOpts.gmThresh    = str2double(char(ctrl.jTextGmThresh.getText()));
        pvcOpts.wmcsfMethod = lower(char(ctrl.jComboWmMethod.getSelectedItem()));
        pvcOpts.wmcsfThresh = str2double(char(ctrl.jTextWmThresh.getText()));
    end

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

        % Call pet_process pipeline with PVC and projection options
        [MriFileOut, errMsg, SurfaceFileOut] = pet_process(PetFile, atlas, roi, maskROI, isMaskChecked, doProject, pvcOpts);

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
    gui_release_dialog(panelName);
    bst_progress('stop');
end

%% ===== CALLBACK: PVC checkbox changed =====
function PvcCheckChanged_Callback(jCheckPvc, jLabelMethod, jComboMethod, jLabelFwhm, jTextFwhm, jCheckCsfZero, ...
        jCheckAdvanced, jPanelAdvanced, jLabelGmThresh, jTextGmThresh, ...
        jLabelWmMethod, jComboWmMethod, jLabelWmThresh, jTextWmThresh)
    isPvc = jCheckPvc.isSelected();
    jLabelMethod.setEnabled(isPvc);
    jComboMethod.setEnabled(isPvc);
    jLabelFwhm.setEnabled(isPvc);
    jTextFwhm.setEnabled(isPvc);
    % Muller-Gartner options: only for the Muller-Gartner method
    isEnabled = isPvc && (jComboMethod.getSelectedIndex() == 1);
    jCheckCsfZero.setEnabled(isEnabled);
    jCheckAdvanced.setEnabled(isEnabled);
    if ~isEnabled
        jPanelAdvanced.setVisible(false);
        jCheckAdvanced.setSelected(false);
    end
    jLabelGmThresh.setEnabled(isEnabled);
    jTextGmThresh.setEnabled(isEnabled);
    jLabelWmMethod.setEnabled(isEnabled);
    jComboWmMethod.setEnabled(isEnabled);
    jLabelWmThresh.setEnabled(isEnabled);
    jTextWmThresh.setEnabled(isEnabled);
end

%% ===== HELPER: Enable/disable ROI mask controls =====
function SetSelectedAndEnabled(jCombo, jLabel, isEnabled)
    jCombo.setEnabled(isEnabled);
    jLabel.setEnabled(isEnabled);
end