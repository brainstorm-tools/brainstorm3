function varargout = panel_femcond(varargin)
% PANEL_FEMCOND Edit FEM conductivity for a list of named layers (isotropic/anisotropic).
%
% USAGE:  bstPanel = panel_femcond('CreatePanel', OPTIONS)           : Call from the interactive interface
%         bstPanel = panel_femcond('CreatePanel', sProcess, sFiles)  : Call from the process editor
%                s = panel_femcond('GetPanelContents')

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
% Authors: Francois Tadel, 2020

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(sProcess, sFiles) %#ok<DEFNU>
    panelName = 'FemCondOptions';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;

    % GUI CALL:  panel_femcond('CreatePanel', OPTIONS)
    if (nargin == 1)
        OPTIONS = sProcess;
    % PROCESS CALL:  panel_femcond('CreatePanel', sProcess, sFiles)
    else
        OPTIONS = sProcess.options.femcond.Value;
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
    OPTIONS.FemCond = panel_duneuro('GetDefaultCondutivity', OPTIONS.FemNames);
    
    % ==== FRAME STRUCTURE ====
    jPanelNew = java_create('javax.swing.JPanel');
    jPanelNew.setLayout(BoxLayout(jPanelNew, BoxLayout.PAGE_AXIS));
    jPanelNew.setBorder(BorderFactory.createEmptyBorder(12,12,12,12));

    % ===== FEM LAYERS =====
    jPanelLayers = gui_river([6,6], [-5,6,15,6], 'FEM conductivities');
        nLayers = length(OPTIONS.FemNames);
        jRadioLayerIso = javaArray('javax.swing.JRadioButton', nLayers);
        jRadioLayerAniso = javaArray('javax.swing.JRadioButton', nLayers);
        jTextCond = javaArray('javax.swing.JTextField', nLayers);
        % Loop on each layer
        for i = 1:nLayers
            gui_component('label', jPanelLayers, 'br', [OPTIONS.FemNames{i} ':'], [], [], [], []);
            jTextCond(i) = gui_component('texttime', jPanelLayers, 'tab', '', [], [], [], []);
            gui_validate_text(jTextCond(i), [], [], {0.0001,1000,10000}, 'S/m', [], OPTIONS.FemCond(i), []);
            gui_component('label', jPanelLayers, 'tab', 'S/m     ', [], [], [], []);
            jGroupRadio = ButtonGroup();
            jRadioLayerIso(i) = gui_component('radio', jPanelLayers, 'tab', 'Isotropic', jGroupRadio, [], @(h,ev)UpdatePanel(), []);
            jRadioLayerAniso(i) = gui_component('radio', jPanelLayers, 'tab', 'Anisotropic', jGroupRadio, [], @(h,ev)UpdatePanel(), []);
            jRadioLayerIso(i).setSelected(1);
        end
    jPanelNew.add(jPanelLayers);

    % ===== ANISOTROPY OPTIONS =====
    jPanelAniso = gui_river([2,2], [6,6,6,6], 'Anisotropy method');
        jGroupAniso = ButtonGroup();
        jRadioMethodEma = gui_component('radio', jPanelAniso, '', '<HTML><B>EMA</B>: Effective Medium Approach (k=0.736) <FONT color="#777777"><I>(DTI)<BR>[Rullmann et al., 2009, Tuch et al., 1999, Haueisen et al., 2002]</I></FONT>', jGroupAniso, [], @(h,ev)UpdatePanel(), []);
        jRadioMethodEmaVc = gui_component('radio', jPanelAniso, 'br', '<HTML><B>EMA+VC</B>: EMA with volume constraint <FONT color="#777777"><I>(DTI)<BR>[Rullmann et al., 2009, Vorwerk et al., 2014]</I></FONT>', jGroupAniso, [], @(h,ev)UpdatePanel(), []);
        jRadioMethodSim = gui_component('radio', jPanelAniso, 'br', '<HTML><B>Simulated</B>: Artificial anisotropy <FONT color="#777777"><I>(no DTI)</I></FONT>', jGroupAniso, [], @(h,ev)UpdatePanel(), []);
        jRadioMethodEma.setSelected(1);
    jPanelNew.add(jPanelAniso);
    
    % ===== SIMULATED OPTIONS =====
    jPanelSim = gui_river([2,2], [6,6,6,6], 'Simulated anisotropy');
        % Ratio
        jLabelRatio = gui_component('label', jPanelSim, '', 'Ratio longitudinal/transversal: ', [], [], [], []);
        SimRatio = 10;
        jTextSimRatio = gui_component('texttime', jPanelSim, '', '', [], [], [], []);
        gui_validate_text(jTextSimRatio, [], [], {0.0001,100,100}, '', 2, SimRatio, []);
        % Constraint
        jGroupConstr = ButtonGroup();
        jRadioConstrWang = gui_component('radio', jPanelSim, 'br', '<HTML><B>Wang</B>''s constraint (Wolters, 2003):<BR><FONT color="#777777">[sig_r*sig_t = sig_iso^2]</FONT>', jGroupConstr, [], [], []);
        jRadioConstrWolters = gui_component('radio', jPanelSim, 'br', '<HTML><B>Volume</B>''s constraint (Wolters, 2003):<BR><FONT color="#777777">[(4/3)*pi*(sig_r*sig_t^2) = (4/3)*pi*(sig_iso^3)]</FONT>', jGroupConstr, [], [], []);
        jRadioConstrWolters.setSelected(1);
    jPanelNew.add(jPanelSim);
    
    % ===== VALIDATION BUTTONS =====
    jPanelValidation = gui_river([10 0], [6 10 0 10]);
        gui_component('Button', jPanelValidation, 'br right', 'Cancel', [], [], @ButtonCancel_Callback, []);
        gui_component('Button', jPanelValidation, [], 'OK', [], [], @ButtonOk_Callback, []);
    jPanelNew.add(jPanelValidation);

    % ===== PANEL CREATION =====
    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    % Create the BstPanel object that is returned by the function
    ctrl = struct('jTextCond',           jTextCond, ...
                  'jRadioLayerIso',      jRadioLayerIso, ...
                  'jRadioLayerAniso',    jRadioLayerAniso, ...
                  'jPanelAniso',         jPanelAniso, ...
                  'jRadioMethodEma',     jRadioMethodEma, ...
                  'jRadioMethodEmaVc',   jRadioMethodEmaVc, ...
                  'jRadioMethodSim',     jRadioMethodSim, ...
                  'jPanelSim',           jPanelSim, ...
                  'jRadioConstrWang',    jRadioConstrWang, ...
                  'jRadioConstrWolters', jRadioConstrWolters, ...
                  'jLabelRatio',         jLabelRatio, ...
                  'jTextSimRatio',       jTextSimRatio);
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
            isIsotropic(j) = jRadioLayerIso(j).isSelected();
            % jTextCond(j).setEnabled(isIsotropic(j));
        end
        % All isotropic: disable anisotropy options
        isAllIso = all(isIsotropic);
        jPanelAniso.setVisible(~isAllIso);
        % Simulated
        isSim = ~isAllIso && jRadioMethodSim.isSelected();
        jPanelSim.setVisible(isSim);
        
        % Get panel
        [bstPanel iPanel] = bst_get('Panel', 'FemCondOptions');
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
    ctrl = bst_get('PanelControls', 'FemCondOptions');
    if isempty(ctrl)
        s = [];
        return; 
    end
    % FEM layers
    for i = 1:length(ctrl.jTextCond)
        s.FemCond(i) = str2double(char(ctrl.jTextCond(i).getText()));
        s.isIsotropic(i) = ctrl.jRadioLayerIso(i).isSelected();
    end
    % Anisotropy options
    if ctrl.jRadioMethodEma.isSelected()
        s.AnisoMethod = 'ema';
    elseif ctrl.jRadioMethodEmaVc.isSelected()
        s.AnisoMethod = 'ema+vc';
    elseif ctrl.jRadioMethodSim.isSelected()
        s.AnisoMethod = 'simulated';
    end
    % Simulated: Ratio
    s.SimRatio = str2double(char(ctrl.jTextSimRatio.getText()));
    % Simulated: Constraint method
    if ctrl.jRadioConstrWang.isSelected()
        s.SimConstrMethod = 'wang';
    elseif ctrl.jRadioConstrWolters.isSelected()
        s.SimConstrMethod = 'wolters';
    end
end




