function varargout = panel_search_database(varargin)
% PANEL_SEARCH_DATABASE: Popup to search Brainstorm's database
% 
% USAGE:  bstPanelNew = panel_search_database('CreatePanel')

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
% Authors: Martin Cousineau, 2019

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel()  %#ok<DEFNU>  
    panelName = 'SearchDatabase';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.icon.*;
    
    % Create main panel
    jPanelMain = gui_component('Panel');
    jPanelMain.setMinimumSize(Dimension(1500,100));

    % Title
    %fontSize = round(12 * bst_get('InterfaceScaling') / 100);
    %jLabel = gui_component('Label', [], [], 'Search database', [], [], [], fontSize);
    %jPanelMain.add(jLabel, BorderLayout.NORTH);
    
    %% Search options
    jPanelSearch = java_create('javax.swing.JPanel');
    jPanelSearch.setLayout(java_create('java.awt.GridBagLayout'));
    c = GridBagConstraints();
    c.fill = GridBagConstraints.HORIZONTAL;
    c.gridy = 0;
    c.weightx = 0;
    c.weighty = 0;
    c.insets = Insets(3,5,3,5);
    % Labels row
    jLabel = gui_component('Label', [], [], 'Search by:');
    c.gridx = 0;
    jPanelSearch.add(jLabel, c);
    jLabel = gui_component('Label', [], [], 'Equality:');
    c.gridx = 1;
    jPanelSearch.add(jLabel, c);
    % Add extra spaces here to enforce a minimum size for this column
    jLabel = gui_component('Label', [], [], 'Search for:                    ');
    c.gridx = 2;
    jPanelSearch.add(jLabel, c);
    jLabel = gui_component('Label', [], [], 'Boolean:');
    c.gridx = 3;
    jPanelSearch.add(jLabel, c);
    jLabel = gui_component('Label', [], [], ''); % Remove button
    c.gridx = 4;
    jPanelSearch.add(jLabel, c);
    % First dropdown
    AddSearchRow(0);
    jPanelMain.add(jPanelSearch, BorderLayout.CENTER);
    
    % Buttons
    jPanelBtn = gui_river();
    fontSize = round(12 * bst_get('InterfaceScaling') / 100);
    gui_component('Button', jPanelBtn, [], 'Add search criteria', IconLoader.ICON_PLUS, [], @(h,ev)AddSearchRow());
    gui_component('Button', jPanelBtn, 'br right', 'Search', [], [], @ButtonSearch_Callback);
    gui_component('Button', jPanelBtn, [], 'Cancel', [], [], @ButtonCancel_Callback);
    jPanelMain.add(jPanelBtn, BorderLayout.SOUTH);
    
    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    % Create the BstPanel object that is returned by the function
    bstPanelNew = BstPanel(panelName, ...
                           jPanelMain, ...
                           struct('jPanelSearch', jPanelSearch));
    
%% =================================================================================
%  === INTERNAL CALLBACKS ==========================================================
%  =================================================================================
%% ===== OK BUTTON =====
    function ButtonOk_Callback(varargin)
        [optionFile, skipLines, skipValidate] = GetSpikeSorterOptionFile(spikeSorter);
        textOptions = char(jTextOptions.getText());
        
        % Validate
        if skipValidate || ValidateOptions(textOptions)
            % Load header if applicable
            if skipLines > 0
                fid = fopen(optionFile,'rt');
                idx = 1;
                while ~feof(fid) && idx <= skipLines
                    line = fgetl(fid);
                    header{idx,1} = line;
                    idx = idx + 1;
                end
                fclose(fid);
                header = [char(join(header, newline)) newline];
            else
                header = '';
            end
            
            % Write to file
            fid = fopen(optionFile,'w');
            fwrite(fid, header);
            fwrite(fid, textOptions);
            fclose(fid);
        
            % Release mutex and keep the panel opened
            bst_mutex('release', panelName);
        end
    end

%% ===== CANCEL BUTTON =====
    function ButtonCancel_Callback(varargin)
        gui_hide(panelName); % Close panel
        bst_mutex('release', panelName); % Release the MUTEX
    end

%% ===== SEARCH BUTTON =====
    function ButtonSearch_Callback(varargin)
        bst_mutex('release', panelName); % Release the MUTEX
    end

%% ===== ADD SEARCH ROW =====
    function AddSearchRow(addRemoveButton)
        if nargin < 1
            addRemoveButton = 1;
        end
        
        % Get last component
        lastComponent = jPanelSearch.getComponent(jPanelSearch.getComponentCount() - 1);
        layout = jPanelSearch.getLayout();
        c = layout.getConstraints(lastComponent);
        c.gridy = c.gridy + 1;
        % Search by
        jSearchBy = gui_component('ComboBox', [], [], [], {{'File name', 'File type'}}, [], @SearchByChanged_Callback);
        c.gridx = 0;
        jPanelSearch.add(jSearchBy, c);
        % Equality
        jEquality = gui_component('ComboBox', [], [], [], {{'Contains', 'Contains (case)', 'Equals', 'Equals (case)'}});
        c.gridx = 1;
        jPanelSearch.add(jEquality, c);
        % Search keyword
        jSearchFor = gui_component('Text', [], 'hfill');
        c.weightx = 1;
        c.gridx = 2;
        jPanelSearch.add(jSearchFor, c);
        c.weightx = 0;
        % Boolean
        jBoolean = gui_component('ComboBox', [], [], [], {{'And', 'Or'}}, [], @BooleanChanged_Callback);
        c.gridx = 3;
        jPanelSearch.add(jBoolean, c);
        % Remove button
        if addRemoveButton
            jRemove = gui_component('Button', [], [], 'Remove', [], [], @ButtonRemove_Callback);
        else
            jRemove = gui_component('Label', [], [], '');
        end
        c.gridx = 4;
        jPanelSearch.add(jRemove, c);
        
        if addRemoveButton
            RefreshDialog();
        else
            jPanelSearch.revalidate();
            jPanelSearch.repaint();
        end
        
        function SearchByChanged_Callback(varargin)
            % Replace search for field by appropriate type
            layout = jPanelSearch.getLayout();
            c = layout.getConstraints(jSearchFor);
            jPanelSearch.remove(jSearchFor);
            
            switch (jSearchBy.getSelectedIndex())
                case 0
                    jSearchFor = gui_component('Text', [], 'hfill');
                case 1
                    jSearchFor = gui_component('ComboBox', [], [], [], {...
                        {'Channel', 'Data', 'Dipoles', 'Fibers', 'Folder', ...
                        'Head model', 'Kernel', 'MRI', 'Matrix', 'Noise covariance', ...
                        'Power spectrum', 'Raw data', 'Source', 'Statistics', ...
                        'Subject', 'Surface', 'Time-frequency', 'Video'}});
                    jSearchFor.setSelectedIndex(1);
            end
            
            jPanelSearch.add(jSearchFor, c);
            RefreshDialog();
        end
        
        function ButtonRemove_Callback(varargin)
            % Remove all row elements
            jPanelSearch.remove(jSearchBy);
            jPanelSearch.remove(jEquality);
            jPanelSearch.remove(jSearchFor);
            jPanelSearch.remove(jBoolean);
            jPanelSearch.remove(jRemove);
            RefreshDialog();
        end
        
        function BooleanChanged_Callback(varargin)
            % If boolean value change, apply it to all boolean dropdowns
            newValue = jBoolean.getSelectedIndex();
            numComponents = jPanelSearch.getComponentCount();
            iComp = 8;
            while iComp < numComponents
                jBool = jPanelSearch.getComponent(iComp);
                jBool.setSelectedIndex(newValue);
                iComp = iComp + 5;
            end
        end
    end

    function RefreshDialog()
        % Refresh search panel
        jPanelSearch.revalidate();
        jPanelSearch.repaint();
        % Refresh dialog
        bstPanel = bst_get('Panel', panelName);
        panelContainer = get(bstPanel, 'container');
        panelContainer.handle{1}.pack();
    end
end

function panelContents = GetPanelContents()
    ctrl = bst_get('PanelControls', 'SearchDatabase');
    if isempty(ctrl)
        panelContents = [];
        return;
    end
    
    numComponents = ctrl.jPanelSearch.getComponentCount();
    layout = ctrl.jPanelSearch.getLayout();
    panelContents = {};
    foundData = 0;
    
    for iComp = 0:numComponents-1
        comp = ctrl.jPanelSearch.getComponent(iComp);
        c = layout.getConstraints(comp);
        
        if c.gridx < 4 && c.gridy > 0
            if strcmpi(comp.getClass().getName(), 'javax.swing.JComboBox')
                val = char(comp.getSelectedItem());
            else
                val = strtrim(char(comp.getText()));
            end
            if c.gridx == 2 && ~isempty(val)
                foundData = 1;
            end
            panelContents{c.gridy, c.gridx + 1} = val;
        end
    end
    
    % Check for empty filters
    if ~foundData
        panelContents = {};
    end
end

