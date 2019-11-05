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
    jPanelSearch.setLayout(java_create('javax.swing.BoxLayout', 'Ljavax.swing.JPanel;Z', jPanelSearch, BoxLayout.Y_AXIS));
    jPanelSearch1 = java_create('javax.swing.JPanel');
    jPanelSearch1.setLayout(java_create('java.awt.GridBagLayout'));
    jPanelSearch.add(jPanelSearch1);
    c = GridBagConstraints();
    c.fill = GridBagConstraints.HORIZONTAL;
    c.gridy = 0;
    c.weightx = 0;
    c.weighty = 0;
    c.insets = Insets(3,5,3,5);
    % Labels row
    jLabel = gui_component('Label', [], [], 'Search by:');
    c.gridx = 0;
    jPanelSearch1.add(jLabel, c);
    jLabel = gui_component('Label', [], [], 'Equality:');
    c.gridx = 1;
    jPanelSearch1.add(jLabel, c);
    % Add extra spaces here to enforce a minimum size for this column
    jLabel = gui_component('Label', [], [], 'Search for:                    ');
    c.gridx = 2;
    jPanelSearch1.add(jLabel, c);
    jLabel = gui_component('Label', [], [], ''); % Remove button
    c.gridx = 3;
    jPanelSearch1.add(jLabel, c);
    jLabel = gui_component('Label', [], [], ''); % AND button
    c.gridx = 4;
    jPanelSearch1.add(jLabel, c);
    jPanelMain.add(jPanelSearch, BorderLayout.CENTER);
    
    % OR button
    AddOrButton(1);
    
    % First dropdown
    AddSearchRow(1, 1, 0);
    
    % Buttons
    jPanelBtn = gui_river();
    fontSize = round(12 * bst_get('InterfaceScaling') / 100);
    
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
%% ===== CANCEL BUTTON =====
    function ButtonCancel_Callback(varargin)
        gui_hide(panelName); % Close panel
        bst_mutex('release', panelName); % Release the MUTEX
    end

%% ===== SEARCH BUTTON =====
    function ButtonSearch_Callback(varargin)
        bst_mutex('release', panelName); % Release the MUTEX
    end


%% ===== KEY TYPED =====
    function PanelSearch_KeyTypedCallback(h, ev)
        switch(uint8(ev.getKeyChar()))
            case ev.VK_ENTER
                % Enter Key = Pressing Search
                ButtonSearch_Callback();
        end
    end

%% ===== ADD SEARCH ROW =====
    function AddSearchRow(orGroup, nextRow, addRemoveButton)
        import org.brainstorm.icon.*;
        import java.awt.GridBagConstraints;
        import java.awt.Insets;
        if nargin < 3
            addRemoveButton = 1;
        end
        
        % Get last component
        jPanelSearch1 = GetOrGroup(orGroup);
        c = GridBagConstraints();
        c.fill = GridBagConstraints.HORIZONTAL;
        c.gridy = 0;
        c.weightx = 0;
        c.weighty = 0;
        c.insets = Insets(3,5,3,5);
        
        % Remove AND button of previous row
        if nextRow > 1
            andBtn = GetSearchElement(jPanelSearch1, orGroup, nextRow - 1, 5);
            andBtn.setVisible(0);
        end
        c.gridy = nextRow - (orGroup ~= 1);
        % Search by
        jSearchBy = gui_component('ComboBox', [], [], [], {{'Name', 'File type', 'File path'}}, [], @(h, ev)SearchByChanged_Callback(orGroup, nextRow, h, ev));
        java_setcb(jSearchBy, 'KeyTypedCallback', @PanelSearch_KeyTypedCallback);
        c.gridx = 0;
        jPanelSearch1.add(jSearchBy, c);
        % Equality
        jEquality = gui_component('ComboBox', [], [], [], {{'Contains', 'Contains (case)', 'Equals', 'Equals (case)'}});
        java_setcb(jEquality, 'KeyTypedCallback', @PanelSearch_KeyTypedCallback);
        c.gridx = 1;
        jPanelSearch1.add(jEquality, c);
        % Search keyword
        jSearchFor = gui_component('Text', [], 'hfill');
        java_setcb(jSearchFor, 'KeyTypedCallback', @PanelSearch_KeyTypedCallback);
        c.weightx = 1;
        c.gridx = 2;
        jPanelSearch1.add(jSearchFor, c);
        c.weightx = 0;
        % Remove button
        jRemove = gui_component('Button', [], [], 'Remove', [], [], @(h,ev)ButtonRemove_Callback(orGroup, nextRow));
        if ~addRemoveButton
            jRemove.setEnabled(0);
        end
        c.gridx = 3;
        jPanelSearch1.add(jRemove, c);
        % Boolean
        jBoolean = gui_component('Button', [], [], '+ and', [], [], @(h,ev)AddSearchRow(orGroup, nextRow + 1));
        c.gridx = 4;
        jPanelSearch1.add(jBoolean, c);
        
        if addRemoveButton
            RefreshDialog();
        else
            jPanelSearch1.revalidate();
            jPanelSearch1.repaint();
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

    function SearchByChanged_Callback(orGroup, andRow, h, ev)
        if ev.getStateChange() ~= 1
            return
        end
        % Replace search for field by appropriate type
        panel = GetOrGroup(orGroup);
        layout = panel.getLayout();
        jSearchBy = GetSearchElement(panel, orGroup, andRow, 1);
        jSearchEqual = GetSearchElement(panel, orGroup, andRow, 2);
        jSearchFor = GetSearchElement(panel, orGroup, andRow, 3);
        c = layout.getConstraints(jSearchFor);
        panel.remove(jSearchFor);

        if jSearchBy.getSelectedIndex() == 1
            jSearchFor = gui_component('ComboBox', [], [], [], {...
                {'Channel', 'Data', 'Dipoles', 'Fibers', 'Folder', ...
                'Head model', 'Kernel', 'MRI', 'Matrix', 'Noise covariance', ...
                'Power spectrum', 'Raw data', 'Source', 'Statistics', ...
                'Subject', 'Surface', 'Time-frequency', 'Video'}});
            jSearchFor.setSelectedIndex(1);
            jSearchEqual.setSelectedIndex(2);
        else
            jSearchFor = gui_component('Text', [], 'hfill');
            jSearchEqual.setSelectedIndex(0);
        end

        panel.add(jSearchFor, c);
        RefreshDialog();
    end

    function ButtonRemove_Callback(orGroup, andRow)
        % Remove all row elements
        orPanel = GetOrGroup(orGroup);
        layout = orPanel.getLayout();
        nComponents = orPanel.getComponentCount();
        y = (orGroup == 1) + andRow - 1;
        lastRow = -1;
        for iComp = nComponents:-1:1
            comp = orPanel.getComponent(iComp - 1);
            c = layout.getConstraints(comp);
            if c.gridy == y
                orPanel.remove(comp);
            end
            lastRow = max(c.gridy, lastRow);
        end
        if orPanel.getComponentCount() == 0
            % Remove whole OR Group
            nComponents = jPanelSearch.getComponentCount();
            jPanelSearch.remove(jPanelSearch.getComponent(nComponents - 1)); % Last rigid
            jPanelSearch.remove(jPanelSearch.getComponent(nComponents - 2)); % Button
            jPanelSearch.remove(jPanelSearch.getComponent(nComponents - 3)); % Mid rigid
            jPanelSearch.remove(jPanelSearch.getComponent(nComponents - 4)); % Separator
            jPanelSearch.remove(jPanelSearch.getComponent(nComponents - 5)); % First rigid
            jPanelSearch.remove(jPanelSearch.getComponent(nComponents - 6)); % OR group
            % Remove OR button label
            jPanelSearch.remove(jPanelSearch.getComponent(nComponents - 7)); % Last rigid
            jPanelSearch.remove(jPanelSearch.getComponent(nComponents - 8)); % OR label
            jPanelSearch.remove(jPanelSearch.getComponent(nComponents - 9)); % Mid rigid
            jPanelSearch.remove(jPanelSearch.getComponent(nComponents - 10)); % Separator
            jPanelSearch.remove(jPanelSearch.getComponent(nComponents - 11)); % First rigid
            % Add OR button back
            AddOrButton(orGroup - 1);
        else
            % Activate AND button of last row
            lastRow = lastRow - (orGroup == 1) + 1;
            if andRow == lastRow
                iRow = lastRow;
                andBtn = [];
                while isempty(andBtn) && iRow > 0
                    andBtn = GetSearchElement(orPanel, orGroup, iRow, 5);
                    iRow = iRow - 1;
                end
                andBtn.setVisible(1);
            end
        end
        RefreshDialog();
    end

    function panel = GetOrGroup(orGroup)
        panel = jPanelSearch.getComponent(6 * orGroup - 6);
    end

    function AddOrButton(lastOrGroup)
        import java.awt.Dimension;
        import javax.swing.Box;
        jPanelSearch.add(Box.createRigidArea(Dimension(0,3)));
        jSep = java_create('javax.swing.JSeparator');
        jPanelSearch.add(jSep);
        jPanelSearch.add(Box.createRigidArea(Dimension(0,3)));
        jBtnOr = gui_component('Button', [], 'br', '+ or', [], [], @(h,ev)AddOrSearchRow(lastOrGroup));
        jBtnOr.setAlignmentX(jPanelSearch.CENTER_ALIGNMENT);
        jPanelSearch.add(jBtnOr);
        jPanelSearch.add(Box.createRigidArea(Dimension(0,3)));
    end

    function AddOrSearchRow(lastOrGroup)
        import java.awt.Dimension;
        import javax.swing.Box;
        
        nComponents = jPanelSearch.getComponentCount();
        jPanelSearch.remove(jPanelSearch.getComponent(nComponents - 1)); % Last rigid
        jPanelSearch.remove(jPanelSearch.getComponent(nComponents - 2)); % Button
        jBtnOr2 = gui_component('Label', [], [], 'or');
        jBtnOr2.setAlignmentX(jPanelSearch.CENTER_ALIGNMENT);
        jPanelSearch.add(jBtnOr2);
        jPanelSearch.add(Box.createRigidArea(Dimension(0,3)));
        
        %TODO: Create new search field
        jPanelSearch2 = java_create('javax.swing.JPanel');
        jPanelSearch2.setLayout(java_create('java.awt.GridBagLayout'));
        jPanelSearch.add(jPanelSearch2);
        AddSearchRow(lastOrGroup + 1, 1, 1);
        
        AddOrButton(lastOrGroup + 1);
        RefreshDialog();       
    end
end

function panelContents = GetPanelContents()
    ctrl = bst_get('PanelControls', 'SearchDatabase');
    if isempty(ctrl)
        panelContents = [];
        return;
    end
    
    nOrComponents = ctrl.jPanelSearch.getComponentCount();
    root = db_template('searchnode');
    root.Type = 3; % Nested block
    orGroup = 0;
    iOrChild = 1;
    
    % Iterate through OR groups
    while 1
        orGroup = orGroup + 1;
        iOrComp = 6 * orGroup - 6;
        if iOrComp >= nOrComponents
            break;
        end
        
        % Add OR node
        if iOrChild > 1
            orNode = db_template('searchnode');
            orNode.Type = 2; % Boolean
            orNode.Value = 2; % OR
            root.Children(iOrChild) = orNode;
            iOrChild = iOrChild + 1;
        end
        
        orPanel = ctrl.jPanelSearch.getComponent(iOrComp);
        orNode = db_template('searchnode');
        orNode.Type = 3; % Nested block
        
        % Iterate through AND rows
        nAndComponents = orPanel.getComponentCount();
        andRow = 0;
        iAndChild = 1;
        while 1
            andRow = andRow + 1;            
            jSearchBy = GetSearchElement(orPanel, orGroup, andRow, 1);
            jEquality = GetSearchElement(orPanel, orGroup, andRow, 2);
            jSearchFor = GetSearchElement(orPanel, orGroup, andRow, 3);
            if isempty(jSearchFor)
                break;
            end
            
            % Add AND node
            if iAndChild > 1
                andNode = db_template('searchnode');
                andNode.Type = 2; % Boolean
                andNode.Value = 1; % AND
                orNode.Children(iAndChild) = andNode;
                iAndChild = iAndChild + 1;
            end
            
            % Add row node

            param = db_template('searchparam');
            param.SearchType = GetSearchType(char(jSearchBy.getSelectedItem()));
            [param.EqualityType, param.CaseSensitive] = GetEqualityType(char(jEquality.getSelectedItem()));
            if param.SearchType == 2 % File type: dropdown
                param.Value = GetFileType(char(jSearchFor.getSelectedItem()));
            else % Other types: text box
                param.Value = char(jSearchFor.getText());
            end
            andNode = db_template('searchnode');
            andNode.Type = 1; % Search param
            andNode.Value = param;
            if iAndChild == 1
                orNode.Children = andNode;
            else
                orNode.Children(iAndChild) = andNode;
            end
            iAndChild = iAndChild + 1;
        end
        
        % Remove unnecessary nested block
        if iAndChild == 2
            orNode = orNode.Children;
        end
        
        if iOrChild == 1
            root.Children = orNode;
        else
            root.Children(iOrChild) = orNode;
        end
        iOrChild = iOrChild + 1;
    end
    
    % Check for empty filters
    if iOrChild > 1
        panelContents = root;
    else
        panelContents = [];
    end
end

function searchType = GetSearchType(searchBy)
    switch searchBy
        case 'Name'
            searchType = 1;
        case 'File type'
            searchType = 2;
        case 'File path'
            searchType = 3;
        otherwise
            error('Unsupported search type');
    end
end

function [equalityType, caseSensitive] = GetEqualityType(equality)
    switch equality
        case 'Contains'
            equalityType = 1;
            caseSensitive = 0;
        case 'Contains (case)'
            equalityType = 1;
            caseSensitive = 1;
        case 'Equals'
            equalityType = 2;
            caseSensitive = 0;
        case 'Equals (case)'
            equalityType = 2;
            caseSensitive = 1;
        otherwise
            error('Unsupported equality type');
    end
end

function fileType = GetFileType(searchFor)
    switch searchFor
        case 'Folder'
            fileType = {'Condition', 'RawCondition'};
        case 'Head model'
            fileType = 'HeadModel';
        case 'MRI'
            fileType = 'Anatomy';
        case 'Noise covariance'
            fileType = 'NoiseCov';
        case 'Power spectrum'
            fileType = 'Spectrum';
        case 'Raw data'
            fileType = 'RawData';
        case 'Source'
            fileType = {'Results', 'Link'};
        case 'Surface'
            fileType = {'Cortex', 'Scalp', 'OuterSkull', 'InnerSkull', 'Other'};
        case 'Statistics'
            fileType = {'PData', 'PResults', 'PTimeFreq', 'PMatrix'};
        case 'Time-frequency'
            fileType = 'TimeFreq';
        case 'Video'
            fileType = {'Video', 'Image'};
        otherwise
            fileType = searchFor;
    end
end

function val = GetFirstValueNode(root)
    if root.Type == 1
        val = root.Value;
        return;
    end
    val = [];
    for iChild = 1:length(root.Children)
        val = GetFirstValueNode(root.Children(iChild));
        if ~isempty(val)
            return;
        end
    end
end

function elem = GetSearchElement(orPanel, orGroup, andRow, iElem)
    layout = orPanel.getLayout();
    nComponents = orPanel.getComponentCount();
    y = (orGroup == 1) + andRow - 1;
    x = iElem - 1;
    elem = [];
    for iComp = 1:nComponents
        comp = orPanel.getComponent(iComp - 1);
        c = layout.getConstraints(comp);
        if c.gridx == x && c.gridy == y
            elem = comp;
            return
        end
    end
end