function varargout = panel_raw_shortcuts(varargin)
% PANEL_RAW_SHORTCUTS: Edit keyboard shortcuts for the RAW Viewer.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2012-2019

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
    % Font size for the options
    TEXT_DIM = java_scaled('dimension', 50, 20);
    % Create 9 text boxes
    jText = javaArray('javax.swing.JTextField', 9);
    jRadioSimple = javaArray('javax.swing.JRadioButton', 9);
    jRadioExt = javaArray('javax.swing.JRadioButton', 9);
    jRadioPage = javaArray('javax.swing.JRadioButton', 9);
    jTextMin = javaArray('javax.swing.JTextField', 9);
    jTextMax = javaArray('javax.swing.JTextField', 9);
    jLabelSep = javaArray('javax.swing.JLabel', 9);
    jLabelUnits = javaArray('javax.swing.JLabel', 9);
    for i = 1:9
        % Event name
        gui_component('label', jPanelShort, 'br', sprintf('Shortcut %d: ', i));
        jText(i) = gui_component('text', jPanelShort, 'tab hfill', RawViewerOptions.Shortcuts{i,2}, {java_scaled('dimension', 120,22)});
        % Event type
        jRadioSimple(i) = gui_component('radio', jPanelShort, 'tab hfill', 'Simple', [], [], @UpdatePanel);
        jRadioPage(i) = gui_component('radio', jPanelShort, 'tab hfill', 'Full page', [], [], @UpdatePanel);
        jRadioExt(i) = gui_component('radio', jPanelShort, 'tab hfill', 'Extended', [], [], @UpdatePanel);
        jButtonGroup = ButtonGroup();
        jButtonGroup.add(jRadioSimple(i));
        jButtonGroup.add(jRadioPage(i));
        jButtonGroup.add(jRadioExt(i));
        switch (RawViewerOptions.Shortcuts{i,3})
            case 'simple',    jRadioSimple(i).setSelected(1);
            case 'page',      jRadioPage(i).setSelected(1);
            case 'extended',  jRadioExt(i).setSelected(1);
        end
        % Default epoch time
        if (length(RawViewerOptions.Shortcuts{i,4}) < 2)
            RawViewerOptions.Shortcuts{i,4} = [-0.1, 0.1];
        end
        % Epoch time
        jTextMin(i) = gui_component('texttime', jPanelShort, [], ' ', TEXT_DIM,[],[]);
        jLabelSep(i) = gui_component('label',    jPanelShort, [], '-');
        jTextMax(i) = gui_component('texttime', jPanelShort, [], ' ', TEXT_DIM,[],[]);
        jLabelUnits(i) = gui_component('label', jPanelShort, [], 'ms');
        gui_validate_text(jTextMin(i), [], jTextMax(i), {-100000, 100000, 100}, 'ms', 0, RawViewerOptions.Shortcuts{i,4}(1), []);
        gui_validate_text(jTextMax(i), jTextMin(i), [], {-100000, 100000, 100}, 'ms', 0, RawViewerOptions.Shortcuts{i,4}(2), []);
    end
    jPanelNew.add(jPanelShort, BorderLayout.CENTER);
    % Update selected options
    UpdatePanel();
    
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
                           struct('jText',        jText, ...
                                  'jRadioSimple', jRadioSimple, ...
                                  'jRadioPage',   jRadioPage, ...
                                  'jRadioExt',    jRadioExt, ...
                                  'jTextMin',     jTextMin, ...
                                  'jTextMax',     jTextMax));

                              
%% =================================================================================
%  === CONTROLS CALLBACKS  =========================================================
%  =================================================================================
    %% ===== UPDATE PANEL =====
    function UpdatePanel(varargin)
        for k = 1:9
            isExt = jRadioExt(k).isSelected();
            jTextMin(k).setEnabled(isExt);
            jTextMax(k).setEnabled(isExt);
            jLabelSep(k).setEnabled(isExt);
            jLabelUnits(k).setEnabled(isExt);
        end
    end

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
        if ctrl.jRadioSimple(i).isSelected()
            RawViewerOptions.Shortcuts{i,3} = 'simple';
        elseif ctrl.jRadioPage(i).isSelected()
            RawViewerOptions.Shortcuts{i,3} = 'page';
        elseif ctrl.jRadioExt(i).isSelected()
            RawViewerOptions.Shortcuts{i,3} = 'extended';
            RawViewerOptions.Shortcuts{i,4} = [str2double(ctrl.jTextMin(i).getText()), str2double(ctrl.jTextMax(i).getText())] ./ 1000;
        end
    end
    % Save shortcuts
    bst_set('RawViewerOptions', RawViewerOptions);
end






