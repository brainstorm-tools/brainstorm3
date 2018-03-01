function varargout = panel_raw_shortcuts(varargin)
% PANEL_RAW_SHORTCUTS: Edit keyboard shortcuts for the RAW Viewer.

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2012

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel() %#ok<DEFNU>
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    panelName = 'EditShortcuts';
    % Get current shortcuts
    RawViewerOptions = bst_get('RawViewerOptions');
    
    % Create main panel
    jPanelNew = gui_component('Panel');
    jPanelNew.setBorder(BorderFactory.createEmptyBorder(10, 10, 10, 10));
    % PANEL: left panel (list of available categories)
    jPanelShort = gui_river([8,8], [0,10,15,10], 'Keyboard shortcuts');
    % Create 9 text boxes
    jText = javaArray('javax.swing.JTextField', 9);
    for i = 1:9
        gui_component('label', jPanelShort, 'br', sprintf('Shortcut %d: ', i));
        jText(i) = gui_component('text', jPanelShort, 'tab hfill', RawViewerOptions.Shortcuts{i,2}, {java_scaled('dimension', 120,22)});
    end
    jPanelNew.add(jPanelShort, BorderLayout.CENTER);
    
    % PANEL: Selections buttons
    jPanelValidation = gui_river([10 0], [10 10 0 10]);
        % Cancel
        gui_component('button', jPanelValidation, 'br right', 'Cancel', [], [], @ButtonCancel_Callback);
        % Save
        gui_component('button', jPanelValidation, '', 'Save', [], [], @ButtonSave_Callback);
    jPanelNew.add(jPanelValidation, BorderLayout.SOUTH);

    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jText', jText));

                              
%% =================================================================================
%  === CONTROLS CALLBACKS  =========================================================
%  =================================================================================
    %% ===== VALIDATION BUTTONS =====
    function ButtonCancel_Callback(varargin)
        % Close panel without saving
        gui_hide(panelName);
    end
    function ButtonSave_Callback(varargin)
        % Save changes
        SaveShortcuts()
        % Close panel
        gui_hide(panelName);
    end
end


%% =================================================================================
%  === INTERFACE CALLBACKS =========================================================
%  =================================================================================
%% ===== SAVE SHORTCUTS =====
function SaveShortcuts()
    % Get current shortcuts
    RawViewerOptions = bst_get('RawViewerOptions');
    % Get panel controls handles
    ctrl = bst_get('PanelControls', 'EditShortcuts');
    % Get all the shortcuts
    for i = 1:9
        RawViewerOptions.Shortcuts{i,2} = strtrim(char(ctrl.jText(i).getText()));
    end
    % Save shortcuts
    bst_set('RawViewerOptions', RawViewerOptions);
end






