function varargout = panel_bem(varargin)
% PANEL_BEM: Options for the construction of BEM layers (GUI).
% 
% USAGE:  bstPanelNew = panel_bem('CreatePanel')
%                   s = panel_bem('GetPanelContents')

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2011

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel()  %#ok<DEFNU>  
    panelName = 'BemOptions';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    % Create main main panel
    jPanelNew = gui_river();
    % Default OpenMeeg options
    BemOptions.nvert = [1922, 1922, 1922];
    BemOptions.thickness = [7 4 3];  % outer-skin, inner-outer, brain-inner
    VertList = {'162', '273', '362', '482', '642', '812', '1082', '1442', '1922', '2432', '2562', '3242', '4322', '5762', '7682', '7292', '9722', '10242', '12962'};
    
    % ===== BEM LAYERS =====
    jPanelVert = gui_river([4,4], [3,15,10,10], 'Number of vertices per layer');
        gui_component('label', jPanelVert, '', '<HTML>Best results are obtained with:<BR>outer skull=inner skull<BR><BR>', [], [], [], []);
        % Scalp
        gui_component('label', jPanelVert, 'br', 'Scalp: ', [], [], [], []);
        jComboVertScalp = gui_component('combobox', jPanelVert, 'tab', [], {VertList}, [], [], []);
        jComboVertScalp.setSelectedIndex(8);
        % Outer skull
        gui_component('label', jPanelVert, 'br', 'Outer skull: ', [], [], [], []);
        jComboVertOuter = gui_component('combobox', jPanelVert, 'tab', [], {VertList}, [], [], []);
        jComboVertOuter.setSelectedIndex(8);
        % Inner skull
        gui_component('label', jPanelVert, 'br', 'Inner skull: ', [], [], [], []);
        jComboVertInner = gui_component('combobox', jPanelVert, 'tab', [], {VertList}, [], [], []);
        jComboVertInner.setSelectedIndex(8);    
    jPanelNew.add('br hfill', jPanelVert);

    % ===== BEM THICKNESS =====
    jPanelThick = gui_river([4,4], [0,15,12,10], 'Thickness of the layers');
%         gui_component('label', jPanelThick, '', '<HTML>Relative values, scaled for each subject<BR>by the distance between brain and skin.<BR><BR>', [], [], [], []);
%         % Scalp-Outer
%         gui_component('label', jPanelThick, 'br', 'Scalp / outer skull: ', [], [], [], []);
%         jTextThickScalp = gui_component('texttime', jPanelThick, 'tab', num2str(BemOptions.thickness(1), '%d'), [], [], [], []);
%         % Outer-Inner
%         gui_component('label', jPanelThick, 'br', 'Outer skull / inner skull: ', [], [], [], []);
%         jTextThickOuter = gui_component('texttime', jPanelThick, 'tab', num2str(BemOptions.thickness(2), '%d'), [], [], [], []);
%         % Inner-Brain
%         gui_component('label', jPanelThick, 'br', 'Inner skull / brain: ', [], [], [], []);
%         jTextThickInner = gui_component('texttime', jPanelThick, 'tab', num2str(BemOptions.thickness(3), '%d'), [], [], [], []);
        gui_component('label', jPanelThick, 'br', 'Skull (mm): ', [], [], [], []);
        jTextThickOuter = gui_component('texttime', jPanelThick, 'tab', num2str(BemOptions.thickness(2), '%d'), [], [], [], []);
    jPanelNew.add('br hfill', jPanelThick);    
    
    % ===== VALIDATION BUTTONS =====
    gui_component('button', jPanelNew, 'br right', 'Cancel', [], [], @ButtonCancel_Callback, []);
    gui_component('button', jPanelNew, [], 'OK', [], [], @ButtonOk_Callback, []);

    % ===== PANEL CREATION =====
    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    % Controls list
    ctrl = struct('BemOptions',       BemOptions, ...
                  'jComboVertScalp',  jComboVertScalp, ...
                  'jComboVertOuter',  jComboVertOuter, ...
                  'jComboVertInner',  jComboVertInner, ...
                  'jTextThickOuter',  jTextThickOuter);
%                   'jTextThickScalp',  jTextThickScalp, ...
%                   'jTextThickOuter',  jTextThickOuter, ...
%                   'jTextThickInner',  jTextThickInner);
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, jPanelNew, ctrl);
    % Update panel
    UpdatePanel();
    

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

    end
end



%% =================================================================================
%  === EXTERNAL CALLBACKS ==========================================================
%  =================================================================================   
%% ===== GET PANEL CONTENTS =====
function s = GetPanelContents() %#ok<DEFNU>
    % Get panel controls
    ctrl = bst_get('PanelControls', 'BemOptions');
    % Bem layers
    nvert1 = str2double(char(ctrl.jComboVertScalp.getSelectedItem()));
    nvert2 = str2double(char(ctrl.jComboVertOuter.getSelectedItem()));
    nvert3 = str2double(char(ctrl.jComboVertInner.getSelectedItem()));
    %thick1 = str2double(char(ctrl.jTextThickScalp.getText()));
    thick2 = str2double(char(ctrl.jTextThickOuter.getText()));
    %thick3 = str2double(char(ctrl.jTextThickInner.getText()));
    % Check for errors
    if isnan(nvert1) || isnan(nvert2) || isnan(nvert3) || isnan(thick2)
        error('Invalid values.');
    end
    s.nvert = [nvert1 nvert2 nvert3];
    s.thickness = [ctrl.BemOptions.thickness(1) thick2 ctrl.BemOptions.thickness(3)];
end





