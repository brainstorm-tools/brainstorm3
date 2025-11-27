function varargout = panel_femselect(varargin)
% PANEL_FEMSELECT Select tissues (layers) from a FEM mesh file
%
% USAGE:  bstPanel = panel_femselect('CreatePanel', FemFile)           : Call from the interactive interface
%         bstPanel = panel_femselect('CreatePanel', sProcess, sFiles)  : Call from the process editor
%                s = panel_femselect('GetPanelContents')

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
% Authors: Takfarinas Medani, 2025
%          Raymundo Cassani, 2025

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(sProcess, sFiles) %#ok<DEFNU>
    panelName = 'FemRefineOptions';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;

    % GUI CALL:  panel_femselect('CreatePanel', FemFile)
    if (nargin == 1)
        FemFile = sProcess;
    % PROCESS CALL:  panel_femselect('CreatePanel', sProcess, sFiles)
    else
        % Get FEM file
        sSubject = bst_get('Subject', sProcess.options.subjectname.Value);
        if isempty(sSubject.iFEM)
            error('No available FEM mesh file for this subject.');
        end
        FemFile = sSubject.Surface(sSubject.iFEM).FileName;
    end

    % ==== GET MESH INFO ====
    % Load tissue labels
    FemMat = load(file_fullpath(FemFile), 'TissueLabels');
    LayerNames = FemMat.TissueLabels;

    % ==== FRAME STRUCTURE ====
    jPanelNew = java_create('javax.swing.JPanel');
    jPanelNew.setLayout(BoxLayout(jPanelNew, BoxLayout.PAGE_AXIS));
    jPanelNew.setBorder(BorderFactory.createEmptyBorder(12,12,12,12));

    % ===== FEM LAYERS =====
    jPanelLayers = gui_river([6,6], [-5,6,15,6], 'Select FEM tissue(s)');
        nLayers = length(LayerNames);
        jCheckLayerSelect = javaArray('javax.swing.JCheckBox', nLayers);
        % Loop on each layer
        for i = 1:nLayers
            gui_component('label', jPanelLayers, 'br', [LayerNames{i} ':'], [], [], [], []);
            jCheckLayerSelect(i) = gui_component('checkbox', jPanelLayers, 'tab', '');
            jCheckLayerSelect(i).setSelected(1);
        end
    jPanelNew.add(jPanelLayers);

    % ===== VALIDATION BUTTONS =====
    jPanelValidation = gui_river([10 0], [6 10 0 10]);
        gui_component('Button', jPanelValidation, 'br right', 'Cancel', [], [], @ButtonCancel_Callback, []);
        gui_component('Button', jPanelValidation, [], 'OK', [], [], @ButtonOk_Callback, []);
    jPanelNew.add(jPanelValidation);

    % ===== PANEL CREATION =====
    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    % Create the BstPanel object that is returned by the function
    ctrl = struct('jCheckLayerSelect', jCheckLayerSelect);
    ctrl.LayerNames = LayerNames;
    ctrl.FemFile    = FemFile;

    % Create the BstPanel object that is returned by the function
    bstPanelNew = BstPanel(panelName, jPanelNew, ctrl);


%% =================================================================================
%  === LOCAL CALLBACKS  ============================================================
%  =================================================================================
    %% ===== BUTTON: CANCEL =====
    function ButtonCancel_Callback(varargin)
        % Close panel
        gui_hide(panelName);
    end

    %% ===== BUTTON: OK =====
    function ButtonOk_Callback(varargin)
        % Release mutex and keep the panel opened
        bst_mutex('release', panelName);
    end
end


%% =================================================================================
%  === EXTERNAL CALLBACKS  =========================================================
%  =================================================================================
%% ===== GET PANEL CONTENTS =====
function s = GetPanelContents() %#ok<DEFNU>
    % Get panel controls handles
    ctrl = bst_get('PanelControls', 'FemRefineOptions');
    if isempty(ctrl)
        s = [];
        return;
    end
    % FEM selected layers
    for i = 1:length(ctrl.jCheckLayerSelect)
        s.LayerSelect(i) = ctrl.jCheckLayerSelect(i).isSelected();
    end
    s.LayerNames = ctrl.LayerNames;
    s.FemFile    = ctrl.FemFile;
end
