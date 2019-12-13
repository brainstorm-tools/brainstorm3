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
    jLabel = gui_component('Label', [], [], 'Not '); % NOT checkbox
    c.gridx = 2;
    jPanelSearch1.add(jLabel, c);
    % Add extra spaces here to enforce a minimum size for this column
    jLabel = gui_component('Label', [], [], 'Search for:                    ');
    c.gridx = 3;
    jPanelSearch1.add(jLabel, c);
    jLabel = gui_component('Label', [], [], ''); % Remove button
    c.gridx = 4;
    jPanelSearch1.add(jLabel, c);
    jLabel = gui_component('Label', [], [], ''); % AND button
    c.gridx = 5;
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
    % Dynamically adds a search row to the GUI
    %
    % Params:
    %  - orGroup: int > 0, ID of "OR" group
    %       Groups are grouped by a OR operation
    %  - nextRow: int > 0, ID of "AND" row in current "OR" group
    %  - addRemoveButton: whether the "Remove row" button should be enabled
    %       The First row of the first "OR" group cannot be removed
    %
    % Returns: nothing
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
        jSearchBy = gui_component('ComboBox', [], [], [], {{'Name', 'File type', 'File path', 'Parent name'}}, [], @(h, ev)SearchByChanged_Callback(orGroup, nextRow, h, ev));
        java_setcb(jSearchBy, 'KeyTypedCallback', @PanelSearch_KeyTypedCallback);
        c.gridx = 0;
        jPanelSearch1.add(jSearchBy, c);
        % Equality
        jEquality = gui_component('ComboBox', [], [], [], {{'Contains', 'Contains (case)', 'Equals', 'Equals (case)'}});
        java_setcb(jEquality, 'KeyTypedCallback', @PanelSearch_KeyTypedCallback);
        c.gridx = 1;
        jPanelSearch1.add(jEquality, c);
        % NOT
        jNot = gui_component('CheckBox');
        c.gridx = 2;
        jPanelSearch1.add(jNot, c);
        % Search keyword
        jSearchFor = gui_component('Text', [], 'hfill');
        java_setcb(jSearchFor, 'KeyTypedCallback', @PanelSearch_KeyTypedCallback);
        c.weightx = 1;
        c.gridx = 3;
        jPanelSearch1.add(jSearchFor, c);
        c.weightx = 0;
        % Remove button
        jRemove = gui_component('Button', [], [], 'Remove', [], [], @(h,ev)ButtonRemove_Callback(orGroup, nextRow));
        if ~addRemoveButton
            jRemove.setEnabled(0);
        end
        c.gridx = 4;
        jPanelSearch1.add(jRemove, c);
        % Boolean
        jBoolean = gui_component('Button', [], [], '+ and', [], [], @(h,ev)AddSearchRow(orGroup, nextRow + 1));
        c.gridx = 5;
        jPanelSearch1.add(jBoolean, c);
        
        if addRemoveButton
            % Refresh the dialog if this is not the first row so that it is
            % automatically resized to include new content
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
        % Repack the dialog container to automatically resize it
        bstPanel = bst_get('Panel', panelName);
        panelContainer = get(bstPanel, 'container');
        panelContainer.handle{1}.pack();
    end

    % Callback when the "Search by" dropdown is changed since "File type"
    % search type has dropdown values rather than free text
    %
    % Params:
    %  - orGroup: int > 0, ID of "OR" group
    %       Groups are grouped by a OR operation
    %  - nextRow: int > 0, ID of "AND" row in current "OR" group
    %  - h, ev: Java callback objects
    %
    % Returns: nothing
    function SearchByChanged_Callback(orGroup, andRow, h, ev)
        % Ensure this is called only once
        if ev.getStateChange() ~= 1
            return
        end
        % Replace "Search for" field by appropriate type
        panel = GetOrGroup(orGroup);
        layout = panel.getLayout();
        jSearchBy = GetSearchElement(panel, orGroup, andRow, 1);
        jSearchEqual = GetSearchElement(panel, orGroup, andRow, 2);
        jSearchFor = GetSearchElement(panel, orGroup, andRow, 4);
        c = layout.getConstraints(jSearchFor);
        % Get curent value
        if isa(jSearchFor, 'javax.swing.JTextField')
            searchForVal = jSearchFor.getText();
        else
            searchForVal = [];
        end
        panel.remove(jSearchFor);

        % If "File type" is selected, create a dropdown of possible values
        if jSearchBy.getSelectedIndex() == 1
            jSearchFor = gui_component('ComboBox', [], [], [], {...
                {'Channel', 'Data', 'Dipoles', 'Fibers', 'Folder', ...
                'Head model', 'Kernel', 'MRI', 'Matrix', 'Noise covariance', ...
                'Power spectrum', 'Raw data', 'Source', 'Statistics', ...
                'Subject', 'Surface', 'Time-frequency', 'Video'}});
            jSearchFor.setSelectedIndex(1);
            jSearchEqual.setSelectedIndex(2);
        % Otherwise, free-form text
        else
            jSearchFor = gui_component('Text', [], 'hfill', searchForVal);
            jSearchEqual.setSelectedIndex(0);
        end
        java_setcb(jSearchFor, 'KeyTypedCallback', @PanelSearch_KeyTypedCallback);

        panel.add(jSearchFor, c);
        RefreshDialog();
    end

    % Callback when the "Remove" row button is pressed
    %
    % Params:
    %  - orGroup: int > 0, ID of "OR" group
    %       Groups are grouped by a OR operation
    %  - nextRow: int > 0, ID of "AND" row in current "OR" group
    %
    % Returns: nothing
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
        
        % If the "OR" group is now empty, remove it as well
        if orPanel.getComponentCount() == 0
            % In order to get to the last "OR" group component, we also
            % need to remove components of the dialog after it. They are
            % added again after.
            
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

    % Returns the panel containing the "OR" group of specified ID
    function panel = GetOrGroup(orGroup)
        panel = jPanelSearch.getComponent(6 * orGroup - 6);
    end

    % Creates the "+ or" button that creates a new "OR" group
    %
    % Params:
    %  - lastOrGroup: ID of the last (most recent / bottom) "OR" group
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

    % Creates a new "OR" group and its first search row
    %
    % Params:
    %  - lastOrGroup: ID of the last (most recent / bottom) "OR" group
    function AddOrSearchRow(lastOrGroup)
        import java.awt.Dimension;
        import javax.swing.Box;
        
        % Replace "+ or" button by label
        nComponents = jPanelSearch.getComponentCount();
        jPanelSearch.remove(jPanelSearch.getComponent(nComponents - 1)); % Last rigid
        jPanelSearch.remove(jPanelSearch.getComponent(nComponents - 2)); % Button
        jBtnOr2 = gui_component('Label', [], [], 'or');
        jBtnOr2.setAlignmentX(jPanelSearch.CENTER_ALIGNMENT);
        jPanelSearch.add(jBtnOr2);
        jPanelSearch.add(Box.createRigidArea(Dimension(0,3)));
        
        % Create new "OR" group and its first row
        jPanelSearch2 = java_create('javax.swing.JPanel');
        jPanelSearch2.setLayout(java_create('java.awt.GridBagLayout'));
        jPanelSearch.add(jPanelSearch2);
        AddSearchRow(lastOrGroup + 1, 1, 1);
        
        % Add "+ or" button again
        AddOrButton(lastOrGroup + 1);
        RefreshDialog();       
    end
end

% Returns the root of a recursive search node structure created from the
% panel content. See db_template('searchnode')
function panelContents = GetPanelContents()
    ctrl = bst_get('PanelControls', 'SearchDatabase');
    if isempty(ctrl)
        panelContents = [];
        return;
    end
    
    % Create root search node
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
        
        % Add parent "OR" node
        orPanel = ctrl.jPanelSearch.getComponent(iOrComp);
        orNode = db_template('searchnode');
        orNode.Type = 3; % Nested block
        
        % Iterate through AND rows
        nAndComponents = orPanel.getComponentCount();
        andRow = 0;
        iAndChild = 1;
        while 1
            % Get components of search row
            andRow = andRow + 1;            
            jSearchBy  = GetSearchElement(orPanel, orGroup, andRow, 1);
            jEquality  = GetSearchElement(orPanel, orGroup, andRow, 2);
            jNot       = GetSearchElement(orPanel, orGroup, andRow, 3);
            jSearchFor = GetSearchElement(orPanel, orGroup, andRow, 4);
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
            
            % Add NOT node
            if jNot.isSelected()
                andNode = db_template('searchnode');
                andNode.Type = 2; % Boolean
                andNode.Value = 3; % NOT
                if iAndChild == 1
                    orNode.Children = andNode;
                else
                    orNode.Children(iAndChild) = andNode;
                end
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
        
        % Remove unnecessary nested blocks, if applicable
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
    
    % Check for empty searches
    if iOrChild > 1
        panelContents = root;
        disp(SearchToString(root));
    else
        panelContents = [];
    end
end

% Returns the search type ID from a search by string
function searchType = GetSearchType(searchBy)
    switch lower(searchBy)
        case {'name', 'comment'}
            searchType = 1;
        case {'file type', 'type'}
            searchType = 2;
        case {'file path', 'path', 'filename'}
            searchType = 3;
        case {'parent name', 'parent'}
            searchType = 4;
        otherwise
            error('Unsupported search type');
    end
end

% Returns the search by string from the search type ID
function searchStr = GetSearchTypeString(searchType)
    switch searchType
        case 1
            searchStr = 'name';
        case 2
            searchStr = 'type';
        case 3
            searchStr = 'path';
        case 4
            searchStr = 'parent';
        otherwise
            error('Unsupported search type');
    end
end

% Returns the equality ID and case sensitive bool from the equality string
function [equalityType, caseSensitive] = GetEqualityType(equality)
    switch lower(equality)
        case 'contains'
            equalityType = 1;
            caseSensitive = 0;
        case {'contains (case)', 'contains_case'}
            equalityType = 1;
            caseSensitive = 1;
        case 'equals'
            equalityType = 2;
            caseSensitive = 0;
        case {'equals (case)', 'equals_case'}
            equalityType = 2;
            caseSensitive = 1;
        otherwise
            error('Unsupported equality type');
    end
end

% Returns the equality string from the equality ID and case sensitive bool
function equalityStr = GetEqualityString(equalityType, caseSensitive)
    switch equalityType
        case 1
            equalityStr = 'CONTAINS';
        case 2
            equalityStr = 'EQUALS';
        otherwise
            error('Unsupported equality type');
    end
    
    if caseSensitive
        equalityStr = [equalityStr '_CASE'];
    end
end

% Returns the file type(s) from the chosen search type dropdown
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

% Returns the boolean string from the selected boolean ID
function boolStr = GetBoolString(boolValue)
    switch boolValue
        case 1
            boolStr = 'AND';
        case 2
            boolStr = 'OR';
        case 3
            boolStr = 'NOT';
        otherwise
            error('Unsupported boolean type');
    end
end

% Returns the boolean ID from the selected boolean string
function boolVal = GetBoolValue(boolStr)
    switch lower(boolStr)
        case 'and'
            boolVal = 1;
        case 'or'
            boolVal = 2;
        case 'not'
            boolVal = 3;
        otherwise
            error('Unsupported boolean type');
    end
end

% Returns the value of the first search node we can find (depth-first)
% Also returns whether we found a NOT operator before said value
function [val, foundNot] = GetFirstValueNode(root, foundNot)
    if nargin < 2
        foundNot = 0;
    end
    % If we have a search param node, return
    if root.Type == 1
        val = root.Value;
        return;
    % Save if we found a NOT operator before the first value node
    elseif root.Type == 2 && root.Value == 3
        foundNot = 1;
    end
    
    % Apply function recursively on children and stop at first found value
    val = [];
    for iChild = 1:length(root.Children)
        [val, foundNot2] = GetFirstValueNode(root.Children(iChild), foundNot);
        % Propagate if we found a NOT operator
        foundNot = foundNot | foundNot2;
        if ~isempty(val)
            return;
        end
    end
end

% Gets a specific component of the search dialog
%
% Params:
%  - orPanel: panel container of the desired "OR" group
%  - orGroup: ID of desired "OR" group
%  - andRow: ID of the desired "AND" row in "orGroup"
%  - iElem: ID of the desired element in the "AND" row
%
% Returns: Java component at desired position
function elem = GetSearchElement(orPanel, orGroup, andRow, iElem)
    % Get the X and Y grid coordinates of desired component
    layout = orPanel.getLayout();
    nComponents = orPanel.getComponentCount();
    y = (orGroup == 1) + andRow - 1;
    x = iElem - 1;
    % Loop through each component and find the one with the desired X and Y
    % coordinates
    for iComp = 1:nComponents
        comp = orPanel.getComponent(iComp - 1);
        c = layout.getConstraints(comp);
        if c.gridx == x && c.gridy == y
            elem = comp;
            return
        end
    end
    % Return empty if not found
    elem = [];
end

% Converts a search node structure to a string
%
% Param  : search structure, see db_template('searchnode')
% Returns: search string, e.g. '([name CONTAINS "test"])'
function str = SearchToString(searchRoot)
    str = [];
    
    switch searchRoot.Type
        % Search parameter structure, see db_template('searchparam')
        case 1
            type = GetSearchTypeString(searchRoot.Value.SearchType);
            equality = GetEqualityString(searchRoot.Value.EqualityType, ...
                searchRoot.Value.CaseSensitive);
            val = searchRoot.Value.Value;
            % Convert cells to string
            if iscell(val)
                valStr = '';
                for iVal = 1:length(val)
                    if iVal > 1
                        valStr = [valStr ', '];
                    end
                    valStr = [valStr '"' val{iVal} '"'];
                end
                val = ['{' valStr '}'];
            else
                val = ['"' val '"'];
            end
            str = [str '[' type ' ' equality ' ' val ']'];
            
        % Boolean
        case 2
            % Do not add prefix space to NOT operator
            if searchRoot.Value < 3
                str = [str ' '];
            end
            str = [str GetBoolString(searchRoot.Value) ' '];
            
        % Parent node (apply recursively to children)
        case 3
            childStr = [];
            for iChild = 1:length(searchRoot.Children)
                childStr = [childStr SearchToString(searchRoot.Children(iChild))];
            end
            str = [str '(' childStr ')'];
            
        otherwise
            error('Invalid search node type');
    end
end

% Converts a search string to a search node structure
%
% Params:
%  - searchStr: Search string, e.g. '([name CONTAINS "test"])'
%  - searchType: Default search type when parameter block shortened
%     - This is optional. Int values, see db_template('searchparam')
%     - E.g. ('"test"', 1) = '([name CONTAINS "test"])'
% Returns: search structure, see db_template('searchnode')
function searchRoot = StringToSearch(searchStr, searchType)
    % Parse inputs
    if nargin < 2
        searchType = [];
    elseif ischar(searchType)
        searchType = GetSearchType(searchType);
    end
    % Remove unnecessary parentheses
    if searchStr(1) == '(' && searchStr(end) == ')'
        searchStr = searchStr(2:end-1);
    end
    
    % State machine
    STATE_PARAM_START = 1;
    STATE_PARAM_NOT   = 2;
    STATE_BOOL_BLOCK  = 3;
    STATE_TYPE        = 4;
    STATE_EQUAL       = 5;
    STATE_VALUE       = 6;
    STATE_VALUE_ELEM  = 7;
    STATE_VALUE_DEL   = 8;
    STATE_PARAM_END   = 9;
    STATE_SHORT_ELEM  = 10;
    STATE_SHORT_DEL   = 11;
    
    % Initialize state machine
    searchRoot = db_template('searchnode');
    searchRoot.Type = 3;
    state = STATE_PARAM_START;
    nBlocksOpen = 0;
    curPath = [];
    iChild = 1;
    word = [];
    quoted = 0;
    wasQuoted = 0;
    iChar = 0;
    nChars = length(searchStr);

    % Extract words
    while iChar < nChars
        iChar = iChar + 1;
        c = searchStr(iChar);
        foundWord = 0;

        if c == '"'
            if quoted
                wasQuoted = 1;
                quoted = 0;
                if iChar == nChars
                    foundWord = 1;
                end
            else
                quoted = 1;
            end
        elseif (isspace(c) && ~quoted)
            if ~isempty(word)
                foundWord = 1;
            end
        % Special characters
        elseif ~quoted && ismember(c, {'(', ')', '[', ']', '{', '}', ',', '&', '|'})
            if isempty(word)
                word = c;
            else
                % Lets finish current word first
                iChar = iChar - 1;
            end
            foundWord = 1;
        else
            word = [word c];
            if iChar == nChars
                foundWord = 1;
            end
        end

        if ~foundWord
            continue;
        end
        
        % Reserved words/characters (only apply action if not in quotes)
        if ~wasQuoted
            reservedWord = 1;
            switch lower(word)
                case '('
                    if state ~= STATE_PARAM_START && state ~= STATE_PARAM_NOT
                        error('Cannot open block bracket at position %d.', iChar);
                    end
                    node = db_template('searchnode');
                    node.Type = 3; % Nested block
                    AddNode(node, curPath, iChild);
                    curPath(end + 1) = iChild;
                    nBlocksOpen = nBlocksOpen + 1;
                    iChild = 1;

                case ')'
                    if state ~= STATE_BOOL_BLOCK || isempty(curPath)
                        error('Cannot close block bracket at position %d.', iChar);
                    end
                    iChild = curPath(end) + 1;
                    curPath = curPath(1:length(curPath)-1);
                    nBlocksOpen = nBlocksOpen - 1;

                case '['
                    if state ~= STATE_PARAM_START && state ~= STATE_PARAM_NOT
                        error('Cannot open search bracket at position %d.', iChar);
                    end
                    param = db_template('searchparam');
                    state = STATE_TYPE;

                case ']'
                    if state ~= STATE_PARAM_END
                        error('Cannot close search bracket at position %d.', iChar);
                    end
                    node = db_template('searchnode');
                    node.Type = 1; % Search node
                    node.Value = param;
                    AddNode(node, curPath, iChild);
                    iChild = iChild + 1;
                    state = STATE_BOOL_BLOCK;

                case {'and', '&', '&&'}
                    if state ~= STATE_BOOL_BLOCK
                        error('AND operator cannot be at position %d.', iChar-length(word));
                    end
                    node = db_template('searchnode');
                    node.Type = 2; % Boolean
                    node.Value = 1; % AND
                    AddNode(node, curPath, iChild);
                    iChild = iChild + 1;
                    state = STATE_PARAM_START;

                case {'or', '|', '||'}
                    if state ~= STATE_BOOL_BLOCK
                        error('OR operator cannot be at position %d.', iChar-length(word));
                    end
                    node = db_template('searchnode');
                    node.Type = 2; % Boolean
                    node.Value = 2; % OR
                    AddNode(node, curPath, iChild);
                    iChild = iChild + 1;
                    state = STATE_PARAM_START;

                case 'not'
                    if state ~= STATE_PARAM_START
                        error('NOT operator cannot be at position %d.', iChar-length(word));
                    end
                    node = db_template('searchnode');
                    node.Type = 2; % Boolean
                    node.Value = 3; % NOT
                    AddNode(node, curPath, iChild);
                    iChild = iChild + 1;
                    state = STATE_PARAM_NOT;

                case {'equals', 'equals_case', 'contains', 'contains_case'}
                    if state ~= STATE_EQUAL
                        error('Equality operator cannot be at position %d.', iChar-length(word));
                    end
                    [param.EqualityType, param.CaseSensitive] = GetEqualityType(word);
                    state = STATE_VALUE;
                    
                case '{'
                    if state == STATE_VALUE
                        param.Value = {};
                        state = STATE_VALUE_ELEM;
                    elseif (state == STATE_PARAM_START || state == STATE_PARAM_NOT) && ~isempty(searchType)
                        % Special shortened syntax, assume default searchType
                        param = db_template('searchparam');
                        param.SearchType = searchType;
                        state = STATE_SHORT_ELEM;
                    else
                        error('Cannot open array bracket at position %d.', iChar);
                    end
                    
                case '}'
                    if state == STATE_VALUE_DEL
                        state = STATE_PARAM_END;
                    elseif state == STATE_SHORT_DEL
                        % For shortened syntax, block finished
                        node = db_template('searchnode');
                        node.Type = 1; % Search node
                        node.Value = param;
                        AddNode(node, curPath, iChild);
                        iChild = iChild + 1;
                        state = STATE_BOOL_BLOCK;
                    else
                        error('Cannot close array bracket at position %d.', iChar);
                    end
                    
                case ','
                    if state == STATE_VALUE_DEL
                        state = STATE_VALUE_ELEM;
                    elseif state == STATE_SHORT_DEL
                        state = STATE_SHORT_ELEM;
                    else
                        error('Unexpected array delimiter at position %d.', iChar);
                    end
                    
                otherwise
                    reservedWord = 0;
            end
        else
            reservedWord = 0;
        end

        % Process non-reserved words
        if ~reservedWord
            switch state
                case STATE_TYPE
                    try
                        param.SearchType = GetSearchType(word);
                    catch
                        error('Unsupported type %s at position %d.', word, iChar-length(word)-wasQuoted*2);
                    end
                    state = STATE_EQUAL;
                    
                case STATE_VALUE
                    param.Value = word;
                    state = STATE_PARAM_END;
                    
                case STATE_VALUE_ELEM
                    param.Value{end + 1} = word;
                    state = STATE_VALUE_DEL;
                    
                case STATE_SHORT_ELEM
                    param.Value{end + 1} = word;
                    state = STATE_SHORT_DEL;
                    
                case {STATE_PARAM_START, STATE_PARAM_NOT}
                    % Special shortened syntax
                    % Add node directly with default values
                    if ~isempty(searchType)
                        param = db_template('searchparam');
                        param.SearchType = searchType;
                        param.Value = word;
                        node = db_template('searchnode');
                        node.Type = 1; % Search node
                        node.Value = param;
                        AddNode(node, curPath, iChild);
                        iChild = iChild + 1;
                        state = STATE_BOOL_BLOCK;
                    else
                        error('Unexpected word %s at position %d.', word, iChar-length(word)-wasQuoted*2);
                    end
                    
                otherwise
                    error('Unexpected word %s at position %d.', word, iChar-length(word)-wasQuoted*2);
            end
        end
        
        word = [];
        wasQuoted = 0;
    end
    
    % Ensure we closed every block
    if nBlocksOpen > 0
        error('Missing closing bracket(s).');
    end
    
    % Adds a search node at a specific position. This function uses eval
    % such that you can do a dynamic number of ".Children" calls from the
    % root node.
    %
    % Params:
    %  - node: db_template('searchnode') to add
    %  - curPath: list of int, path to active node from root
    %  - iChild: child position where to add "node" to active node
    %
    % Returns: nothing
    function AddNode(node, curPath, iChild)
        str = 'searchRoot';
        for iPath = 1:length(curPath)
            str = [str '.Children(' num2str(curPath(iPath)) ')'];
        end
        str = [str '.Children'];
        if isempty(eval(str))
            if iChild ~= 1
                error('Invalid child position');
            end
        else
            str = [str '(' num2str(iChild) ')'];
        end
        eval([str ' = node;']);
    end
end

% Concatenates two search structures together
% e.g. ConcatenateSearches(A, B, 'AND') = (A AND B)
%
% Params:
%  - search1: First search structure, see db_template('searchnode')
%  - search2: Second search structure
%  - boolOp : Boolean operator between the two searches (AND or OR)
%  - not2   : Whether to add a NOT operator before second search
%
% Returns: A single concatenated search structure
function searchRoot = ConcatenateSearches(search1, search2, boolOp, not2)
    % Parse inputs
    if nargin < 4 || isempty(not2)
        not2 = 0;
    end
    if nargin < 3 || isempty(boolOp)
        boolOp = 'AND';
    end
    
    % Remove unnecessary root branch nodes from input searches
    while search1.Type == 3 && length(search1.Children) == 1
        search1 = search1.Children(1);
    end
    while search2.Type == 3 && length(search2.Children) == 1
        search2 = search2.Children(1);
    end
    
    % Create new search node with first search
    searchRoot = db_template('searchnode');
    searchRoot.Type = 3; % Parent node
    searchRoot.Children = search1;
    
    % Add bool
    node = db_template('searchnode');
    node.Type = 2; % Bool
    node.Value = GetBoolValue(boolOp);
    searchRoot.Children(end + 1) = node;
    
    % Add NOT operator if required
    if not2
        node = db_template('searchnode');
        node.Type = 2; % Bool
        node.Value = 3; % NOT
        searchRoot.Children(end + 1) = node;
    end
    
    % Add second search
    searchRoot.Children(end + 1) = search2;
end
