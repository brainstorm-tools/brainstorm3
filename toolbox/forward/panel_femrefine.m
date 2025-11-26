function varargout = panel_femrefine(varargin)
% PANEL_REFINEFEM Edit FEM conductivity for a list of named layers (isotropic/anisotropic).
%
% USAGE:  bstPanel = panel_femrefine('CreatePanel', OPTIONS)           : Call from the interactive interface
%         bstPanel = panel_femrefine('CreatePanel', sProcess, sFiles)  : Call from the process editor
%                s = panel_femrefine('GetPanelContents')

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
% Authors: Takfarinas Medani, 2025, adapted from panel_femcond

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(sProcess, sFiles) %#ok<DEFNU>
    panelName = 'FemRefineOptions';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;

    % GUI CALL:  panel_femrefine('CreatePanel', OPTIONS)
    if (nargin == 1)
        OPTIONS = sProcess;
    % PROCESS CALL:  panel_femrefine('CreatePanel', sProcess, sFiles)
    else % I'm not sure about this=> check with Ray
        OPTIONS = sProcess.options.panel_femrefine.Value;
        % Get FEM files
        sSubject = bst_get('Subject', sProcess.options.subjectname.Value);
        if isempty(sSubject.iFEM)
            error('No available FEM mesh file for this subject.');
        end
        OPTIONS.FemFile = file_fullpath(sSubject.Surface(sSubject.iFEM).FileName);
    end
    
    % ==== GET MESH INFO ====
    % Load tissue labels
    FemMat = load(OPTIONS.FemFile, 'TissueLabels');
    % Get default conductivities
    OPTIONS.FemNames = FemMat.TissueLabels;
    % OPTIONS.FemCond = panel_duneuro('GetDefaultCondutivity', OPTIONS.FemNames);
    OPTIONS.MeshEdgeLength = ones(size(OPTIONS.FemNames));
    
    % ==== FRAME STRUCTURE ====
    jPanelNew = java_create('javax.swing.JPanel');
    jPanelNew.setLayout(BoxLayout(jPanelNew, BoxLayout.PAGE_AXIS));
    jPanelNew.setBorder(BorderFactory.createEmptyBorder(12,12,12,12));

    % ===== FEM LAYERS =====
    jPanelLayers = gui_river([6,6], [-5,6,15,6], 'FEM tissue(s) to refine');
        nLayers = length(OPTIONS.FemNames);
        jRadioLayerRefine = javaArray('javax.swing.JRadioButton', nLayers);
        jRadioLayerNoRefine = javaArray('javax.swing.JRadioButton', nLayers);
        %jTextEdgeSize = javaArray('javax.swing.JTextField', nLayers);
        % Loop on each layer
        for i = 1:nLayers
            gui_component('label', jPanelLayers, 'br', [OPTIONS.FemNames{i} ':'], [], [], [], []);
            %jTextEdgeSize(i) = gui_component('texttime', jPanelLayers, 'tab', '', [], [], [], []);
            %gui_validate_text(jTextEdgeSize(i), [], [], {0.0001,1000,10000}, 'mm', [], OPTIONS.MeshEdgeLength(i), []);
            %gui_component('label', jPanelLayers, 'tab', 'mm', [], [], [], []);
            jGroupRadio = ButtonGroup();
            jRadioLayerRefine(i) = gui_component('radio', jPanelLayers, 'tab', 'Refine', jGroupRadio, [], @(h,ev)UpdatePanel(), []);
            jRadioLayerNoRefine(i) = gui_component('radio', jPanelLayers, 'tab', 'No Refine', jGroupRadio, [], @(h,ev)UpdatePanel(), []);
            jRadioLayerRefine(i).setSelected(1);
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
    ctrl = struct(...'jTextEdgeSize',          jTextEdgeSize, ...
                  'jRadioLayerRefine',      jRadioLayerRefine, ...
                  'jRadioLayerNoRefine',    jRadioLayerNoRefine); 
    ctrl.FemNames = OPTIONS.FemNames;
    % Create the BstPanel object that is returned by the function
    bstPanelNew = BstPanel(panelName, jPanelNew, ctrl);    
    % Redraw panel
    UpdatePanel();


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

    %% ===== UPDATE PANEL ======
    function UpdatePanel()
        % FEM Layers
        isIsotropic = false(1, nLayers);
        for j = 1:nLayers
            isIsotropic(j) = jRadioLayerRefine(j).isSelected();
            % jTextEdgeSize(j).setEnabled(isIsotropic(j));
        end
        
        % Get panel
        [bstPanel iPanel] = bst_get('Panel', 'FemRefineOptions');
        container = get(bstPanel, 'container');
        % Re-pack frame
        if ~isempty(container)
            jFrame = container.handle{1};
            if ~isempty(jFrame)
                jFrame.pack();
            end
        end
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
    % FEM layers
    for i = 1:length(ctrl.jRadioLayerRefine)
        ... s.EdgeSize(i) = str2double(char(ctrl.jTextEdgeSize(i).getText()));
        s.LayerRefine(i) = ctrl.jRadioLayerRefine(i).isSelected();
        s.LayerName(i) = ctrl.FemNames(i);
    end
end




