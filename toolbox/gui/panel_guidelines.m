function varargout = panel_guidelines( varargin )
% PANEL_GUIDELINES: Load a scenario in the guidelines tab.
%
% USAGE:  [bstPanel] = panel_guidelines('CreatePanel', ScenarioName)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2017

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(ScenarioName) %#ok<DEFNU>
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    panelName = 'Guidelines';

    % Load all the panels from the target scenario
    switch lower(ScenarioName)
        case 'epileptogenicity'
            ctrl = scenario_epilepto('CreatePanels');
        otherwise
            error(['Unknow scenario: ' ScenarioName]);
    end
    % Create main panel
    ctrl.jPanelContainer = gui_component('Panel');
    ctrl.ScenarioName = ScenarioName;
    
    % Create control panel
    jPanelControl = gui_river([1,1], [1,3,1,3], ' ');
    ctrl.jPanelContainer.add(jPanelControl, BorderLayout.EAST);
    % Add buttons
    buttonFormat = {Insets(0,0,0,0), Dimension(java_scaled('value', 47), java_scaled('value', 22))};
    ctrl.jButtonReset = gui_component('button', jPanelControl, 'br', '<HTML><FONT COLOR="#808080"><I>Reset</I></FONT>', buttonFormat, [], @(h,ev)ResetPanel());
    gui_component('label', jPanelControl, 'br', ' ');
    ctrl.jButtonPrev = gui_component('button', jPanelControl, 'br', '<<', buttonFormat, [], @(h,ev)SwitchPanel('prev'));
    ctrl.jButtonNext = gui_component('button', jPanelControl, 'br', '>>', buttonFormat, [], @(h,ev)SwitchPanel('next'));
    ctrl.jLabelStep  = gui_component('label', jPanelControl, 'br hfill', sprintf('0 / %d', length(ctrl.jPanels)));
    ctrl.jLabelStep.setHorizontalAlignment(JTextField.CENTER);
    gui_component('label', jPanelControl, 'br', ' ');
    ctrl.jButtonSkip = gui_component('button', jPanelControl, 'br', '<HTML><FONT COLOR="#808080"><I>Skip</I></FONT>', buttonFormat, [], @(h,ev)SwitchPanel('skip'));
    
    % Create the BstPanel object that is returned by the function
    bstPanelNew = BstPanel(panelName, ...
                           ctrl.jPanelContainer, ...
                           ctrl);                       
end



%% =================================================================================
%  === EXTERNAL CALLBACKS  =========================================================
%  =================================================================================
%% ===== GET PANEL CONTENTS =====
% GET Panel contents in a structure
function s = GetPanelContents() %#ok<DEFNU>
    s = [];
end

%% ===== CLOSE PANEL =====
function ClosePanel(varargin) %#ok<DEFNU>
    panelName = 'Guidelines';
    % Hide panel
    gui_hide(panelName);
    % Release mutex
    bst_mutex('release', panelName);
end


%% ===== GET CURRENT PANEL =====
function iPanel = GetCurrentPanel()
    % Get panel controls handles
    ctrl = bst_get('PanelControls', 'Guidelines');
    if isempty(ctrl)
        iPanel = 0;
        return; 
    end
    % Read panel index
    strIndex = char(ctrl.jLabelStep.getText());
    iPanel = str2num(strIndex(1:2));
end

%% ===== SWITCH PANEL =====
function SwitchPanel(command)
    import java.awt.*;
    % Get panel controls handles
    ctrl = bst_get('PanelControls', 'Guidelines');
    if isempty(ctrl)
        return; 
    end
    % Get current panel
    iPanel = GetCurrentPanel();
    
    % === VALIDATE CURRENT PANEL ===
    % If there is a validation callback for this panel
    if (iPanel >= 1) && ~isempty(ctrl.fcnValidate{iPanel}) && strcmpi(command, 'next')
        [isValidated, errMsg] = ctrl.fcnValidate{iPanel}();
        if ~isempty(errMsg)
            bst_error(errMsg, sprintf('Step #%d', iPanel), 0);
            return;
        end
    end
    % If this is the last panel and moving forward: stop
    if (iPanel == length(ctrl.jPanels)) && strcmpi(command, 'next')
        return;
    end
    
    % === MOVE TO NEXT PANEL ===
    % Remove existing panel
    if (iPanel >= 1) && (iPanel <= length(ctrl.jPanels))
        ctrl.jPanelContainer.remove(ctrl.jPanels(iPanel));
    end
    % Switch according to command
    switch (command)
        case 'next',  iPanel = iPanel + 1;
        case 'skip',  iPanel = iPanel + 1;
        case 'prev',  iPanel = iPanel - 1;
    end
    % If invalid panel: stop
    if (iPanel < 1) || (iPanel > length(ctrl.jPanels))
        return;
    end
    % Add new panel
    ctrl.jPanelContainer.add(ctrl.jPanels(iPanel), BorderLayout.CENTER);
    % Update step number
    ctrl.jLabelStep.setText(sprintf('%d / %d', iPanel, length(ctrl.jPanels)));
    % Repaint
    ctrl.jPanelContainer.invalidate();
    ctrl.jPanelContainer.repaint();
    % First panel: Disable previous button
    if (iPanel == 1)
        ctrl.jButtonPrev.setEnabled(0);
    else
        ctrl.jButtonPrev.setEnabled(1);
    end
    % Show/Hide Skip button
    ctrl.jButtonSkip.setVisible(ctrl.isSkip(iPanel));
%     % Last panel: Disable next button
%     if (iPanel == length(ctrl.jPanels))
%         ctrl.jButtonNext.setEnabled(0);
%     else
%         ctrl.jButtonNext.setEnabled(1);
%     end
    
    % === UPDATE NEW PANEL ===
    % If there is an update callback for this panel
    if (iPanel >= 1) && ~isempty(ctrl.fcnUpdate{iPanel})
        ctrl.fcnUpdate{iPanel}();
    end
end


%% ===== RESET PANEL =====
function ResetPanel()
    % Get panel controls handles
    ctrl = bst_get('PanelControls', 'Guidelines');
    if isempty(ctrl)
        return; 
    end
    % Get current panel
    iPanel = GetCurrentPanel();
    if (iPanel >= 1) && ~isempty(ctrl.fcnReset{iPanel})
        ctrl.fcnReset{iPanel}();
    end
end


%% ===== OPTIONS: PICK FILE CALLBACK =====
function [OutputFiles, FileFormat] = PickFile(jControl, DefaultDir, SelectionMode, FilesOrDir, Filters, DefaultFormat) %#ok<DEFNU>
    % Parse inputs
    if (nargin < 6) || isempty(DefaultFormat)
        DefaultFormat = [];
    end
    % Get default import directory and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    DefaultFormats = bst_get('DefaultFormats');
    % Default dir type
    DefaultFile = LastUsedDirs.(DefaultDir);
    % Default filter
    if ~isempty(DefaultFormat) && isfield(DefaultFormats, DefaultFormat)
        defaultFilter = DefaultFormats.(DefaultFormat);
    else
        defaultFilter = [];
        DefaultFormat = [];
    end
    % Pick a file
    [OutputFiles, FileFormat, FileFilter] = java_getfile('open', 'Select file', DefaultFile, SelectionMode, FilesOrDir, Filters, defaultFilter);
    % If nothing selected
    if isempty(OutputFiles)
        return
    end
    % If only one file selected
    if ~iscell(OutputFiles)
        OutputFiles = {OutputFiles};
    end
    % Get the files
    OutputFiles = file_expand_selection(FileFilter, OutputFiles);
    if isempty(OutputFiles)
        error(['No ' FileFormat ' file in the selected directories.']);
    end
    % Save default import directory
    if ischar(OutputFiles)
        newDir = OutputFiles;
    elseif iscell(OutputFiles)
        newDir = OutputFiles{1};
    end
    % Get parent folder if needed
    if ~isdir(newDir)
        newDir = bst_fileparts(newDir);
    end
    LastUsedDirs.(DefaultDir) = newDir;
    bst_set('LastUsedDirs', LastUsedDirs);
    % Save default import format
    if ~isempty(DefaultFormat)
        DefaultFormats.(DefaultFormat) = FileFormat;
        bst_set('DefaultFormats',  DefaultFormats);
    end
    
    % Get file descriptions (one/many)
    if ischar(OutputFiles)
        strFiles = OutputFiles;
    else
        if (length(OutputFiles) == 1)
            strFiles = OutputFiles{1};
        elseif isa(jControl, 'javax.swing.JLabel')
            strFiles = sprintf('%s<BR>', OutputFiles{:});
        else
            strFiles = sprintf('[%d files]', length(OutputFiles));
        end
    end

    % Update the attached control
    if isempty(jControl)
        %disp(strFiles);
    elseif isa(jControl, 'javax.swing.JTextField')
        jControl.setText(strFiles);
    elseif isa(jControl, 'javax.swing.JLabel')
        jControl.setText(['<HTML>' strFiles]);
    end
end



