function varargout = panel_ieeg_implantation(varargin)
% PANEL_IEEG_IMPLANTATION: Figures to be used during SEEG/ECOG implantation
%
% USAGE: [bstPanelNew, panelName] = panel_ieeg_implantation('CreatePanel', isMri, isCt, isIso)
%
% impFigs = gui_show_dialog('SEEG/ECOG implantation', @panel_ieeg_implantation, 1, [], isMri, isCt, isIso)
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
% Authors: Raymundo Cassani, 2025

eval(macro_method);
end

%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(isMri, isCt, isIso)
    panelName = 'panel_ieeg_implantation';
    import java.awt.*
    import javax.swing.*

    % === MAIN LAYOUT ===
    jPanelMain = gui_river([5, 5], [0, 10, 10, 10]);
    % === PANEL FIGURES ===
    jPanelFigures = gui_river([2, 2], [0, 10, 10, 10], 'Figures');
    % Options
    jCheckMri    = gui_component('checkbox', jPanelFigures, 'br', 'MRI (MRI viewer)');
    jCheckCt     = gui_component('checkbox', jPanelFigures, 'br', 'CT  (MRI viewer)');
    jCheckMriCt  = gui_component('checkbox', jPanelFigures, 'br', 'CT overlaid on MRI (MRI viewer)');
    jCheckMriIso = gui_component('checkbox', jPanelFigures, 'br', 'IsoSurface and MRI slices (3D view)');
    jCheckCtIso  = gui_component('checkbox', jPanelFigures, 'br', 'IsoSurface and CT slices (3D view)');
    % Enable and dissable options
    jCheckMri.setEnabled(isMri);
    jCheckCt.setEnabled(isCt);
    jCheckMriCt.setEnabled(isMri & isCt);
    jCheckMriIso.setEnabled(isMri & isIso);
    jCheckCtIso.setEnabled(isCt & isIso);
    % Selected options
    jCheckMri.setSelected(isMri && ~isCt);
    jCheckCt.setSelected(~isMri && isCt);
    jCheckMriCt.setSelected(isMri && isCt);
    jCheckMriIso.setSelected(isMri && isIso);
    jCheckCtIso.setSelected(isCt && isIso && ~isMri);
    % Add panel to main layout
    jPanelMain.add('br', jPanelFigures);

    % === BUTTONS ===
    jPanelButtons = gui_river([2 2], [0 10 10 10]);
    gui_component('button', jPanelButtons, '', 'Cancel',   [], [], @ButtonCancel_Callback);
    gui_component('button', jPanelButtons, '', 'Continue', [], [], @ButtonContinue_Callback);
    jPanelMain.add('br right', jPanelButtons);
    % === Create mutex ===
    bst_mutex('create', panelName);
    % === Return panel object ===
    bstPanelNew = BstPanel(panelName, jPanelMain, ...
        struct('jCheckMri',    jCheckMri, ...
               'jCheckCt',     jCheckCt, ...
               'jCheckMriCt',  jCheckMriCt, ...
               'jCheckMriIso', jCheckMriIso, ...
               'jCheckCtIso',  jCheckCtIso));

%% =================================================================================
%  === INTERNAL CALLBACKS ==========================================================
%  =================================================================================
%% ===== CANCEL BUTTON =====
    function ButtonCancel_Callback(~, ~)
        gui_hide(panelName);
    end

%% ===== IMPORT BUTTON =====
    function ButtonContinue_Callback(~, ~)
        bst_mutex('release', panelName);  % Triggers gui_show_dialog to call GetPanelContents
    end
end

%% =================================================================================
%  === EXTERNAL CALLBACKS ==========================================================
%  =================================================================================
%% ===== GET DEFAULT FIGURES =====
function impFigs = GetDefaultFigures()
    impFigs = struct('Mri', 0, 'Ct', 0, 'MriCt', 0, 'MriIso', 0, 'CtIso', 0);
end

%% ===== GET PANEL CONTENTS =====
function impFigs = GetPanelContents()
    % Get panel controls
    ctrl = bst_get('PanelControls', 'panel_ieeg_implantation');
    % Get figure selection
    impFigs = GetDefaultFigures();
    impFigs.Mri    = ctrl.jCheckMri.isSelected();
    impFigs.Ct     = ctrl.jCheckCt.isSelected();
    impFigs.MriCt  = ctrl.jCheckMriCt.isSelected();
    impFigs.MriIso = ctrl.jCheckMriIso.isSelected();
    impFigs.CtIso  = ctrl.jCheckCtIso.isSelected();
end
