function varargout = panel_protocols(varargin)
% PANEL_PROTOCOLS: Create 'Protocols' panel of the main Brainstorm window.
% 
% USAGE:  bstPanel = panel_protocols('CreatePanel');
%                    panel_protocols('SetExplorationMode',  ExplorationMode)
%         nodeRoot = panel_protocols('GetRootNode')
%                    panel_protocols('UpdateTree')
%                    panel_protocols('UpdateNode',          'Subject', iSubjects)
%                    panel_protocols('UpdateNode',          'Study',   iStudies, isExpandTrials)
%                    panel_protocols('ReloadNode',          bstNode)
%                    panel_protocols('CollapseAncestor',    nodeType, bstNodes )
%                    panel_protocols('ExpandPath',          bstNode, isSelected )
%        nodeFound = panel_protocols('SelectNode',          nodeRoot, nodeType, iStudy, iFile )
%        nodeFound = panel_protocols('SelectNode',          nodeRoot, FileName )
%        nodeFound = panel_protocols('GetNode',             nodeType, iStudy, iFile )
%        nodeFound = panel_protocols('GetNode',             FileName )
%        nodeStudy = panel_protocols('SelectStudyNode',     nodeStudy )  % Select given 'study' tree node
%        nodeStudy = panel_protocols('SelectStudyNode',     iStudy )     % Find 'study' tree node with studyIndex = iStudy and select it
%                    panel_protocols('SelectSubject',       SubjectName) % Select and expand subject node
%                    panel_protocols('MarkUniqueNode',      bstNode)
%      OutputFiles = panel_protocols('TreeHeadModel',       bstNode)
%      OutputFiles = panel_protocols('TreeInverse',         bstNodes, Version)

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
% Authors: Francois Tadel, 2008-2017

eval(macro_method);
end


%% ===== CREATE PANEL =====
function bstPanelNew = CreatePanel() %#ok<DEFNU>
    panelName = 'Protocols';

    % Get scaling factor
    InterfaceScaling = bst_get('InterfaceScaling');
    % Get standard font
    stdFont = bst_get('Font');
    % Creation of the exploration tree
    jTreeProtocols = java_create('org.brainstorm.tree.BstTree', 'F', InterfaceScaling / 100, stdFont.getSize(), stdFont.getFontName());
    jTreeProtocols.setEditable(1);
    jTreeProtocols.setToggleClickCount(3);
    jTreeProtocols.setBorder(javax.swing.BorderFactory.createEmptyBorder(5,5,5,0));
    jTreeProtocols.setLoading(1);
    jTreeProtocols.setRowHeight(round(20 * InterfaceScaling / 100));
    % Configure selection model
    jTreeSelModel = jTreeProtocols.getSelectionModel();
    jTreeSelModel.setSelectionMode(jTreeSelModel.DISCONTIGUOUS_TREE_SELECTION);
    % Enable drag'n'drop
    jTreeProtocols.setDragEnabled(1);
    jTreeDragHandler = java_create('org.brainstorm.dnd.TreeDragTransferHandler');
    jTreeProtocols.setTransferHandler(jTreeDragHandler);
    
    % Add tree callbacks
    java_setcb(jTreeProtocols, 'MouseClickedCallback',   @protocolTreeClicked_Callback, ...
                               'KeyPressedCallback',     @protocolTreeKeyPressed_Callback, ...
                               'TreeWillExpandCallback', @protocolTreeExpand_Callback);
    java_setcb(jTreeProtocols.getCellEditor(), 'EditingStoppedCallback', @protocolTreeEditingStopped_Callback);
    java_setcb(jTreeSelModel, 'ValueChangedCallback', @protocolTreeSelectionChanged_Callback);
    java_setcb(jTreeProtocols.getModel(), 'TreeNodesChangedCallback', @protocolTreeDrop_Callback);

    % Add tree to a scroll panel
    jScrollPaneNew = java_create('javax.swing.JScrollPane', 'Ljava.awt.Component;', jTreeProtocols);
    jScrollPaneNew.setBorder(javax.swing.BorderFactory.createMatteBorder(1,1,0,1, java.awt.Color(.5,.5,.5)));
    
    % Export panel to Brainstorm environment
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jScrollPaneNew, ...
                           struct('jTreeProtocols', jTreeProtocols));


%% =================================================================================
%  === LOCAL CALLBACKS  ============================================================
%  =================================================================================
    %% ===== TREE CLICK CALLBACK ======
    function protocolTreeClicked_Callback( hObject, mouseEvent, varargin )
        % Get the path that was clicked
        pathClicked = jTreeProtocols.getPathForLocation(mouseEvent.getPoint.getX(), mouseEvent.getPoint.getY());
        % Return directly if no node were selected
        if isempty(pathClicked)
            return
        end
        % Get the button that was pressed
        switch (mouseEvent.getButton())
            % === LEFT CLICK ===
            case mouseEvent.BUTTON1
                % === DOUBLE LEFT CLICK ===
                if (mouseEvent.getClickCount() == 2)
                    % Process double click
                    bst_call(@tree_callbacks, pathClicked.getLastPathComponent, 'doubleclick');
                else
                    % Process click
                    bst_call(@tree_callbacks, pathClicked.getLastPathComponent, 'click');
                end

            % === MIDDLE CLICK ===
            case mouseEvent.BUTTON2
                % Nothing to do

            % === RIGHT CLICK ===
            % If clicked node is selected, display popup for all the selected nodes
            % Else select clicked node and display popup only for it
            case mouseEvent.BUTTON3
                % If path is selected
                if jTreeProtocols.isPathSelected(pathClicked)
                    % Get the list of all the selected nodes
                    selectedPaths = jTreeProtocols.getSelectionPaths();
                    targetNodes = javaArray('org.brainstorm.tree.BstNode', length(selectedPaths));
                    for iPath = 1:length(selectedPaths)
                        targetNodes(iPath) = selectedPaths(iPath).getLastPathComponent();
                    end
                % Else : clicked node is not selected
                else
                    % Select the path that was clicked
                    jTreeProtocols.setSelectionPath(pathClicked);
                    targetNodes = pathClicked.getLastPathComponent;
                end
                % Set mouse cursor to WAIT
                jTreeProtocols.setCursor(java_create('java.awt.Cursor', 'I', java.awt.Cursor.WAIT_CURSOR));
                % Create popup
                jPopup = bst_call(@tree_callbacks, targetNodes, 'popup');
                % Display popup menu
                if ~isempty(jPopup)
                    jPopup.pack();
                    jPopup.show(jTreeProtocols, mouseEvent.getPoint.getX(), mouseEvent.getPoint.getY());
                end
                % Restore default mouse cursor
                jTreeProtocols.setCursor([]);
        end
    end

    %% ===== TREE EXPAND =====
    function protocolTreeExpand_Callback( hObject, event, varargin )
        % Nothing selection: exit
        if isempty(event) || isempty(event.getSource())
            return;
        end
        % Get selected node
        nodeExpand = event.getPath().getLastPathComponent();
        nodeType = char(nodeExpand(1).getType());
        % If this is a study node, node created yet: create it
        if ismember(nodeType, {'condition', 'rawcondition', 'studysubject', 'study', 'defaultstudy'}) && (nodeExpand.getStudyIndex() ~= 0)
            panel_protocols('CreateStudyNode', nodeExpand);
        end
    end
        
    %% ===== TREE KEY PRESSED =====
    function protocolTreeKeyPressed_Callback( hObject, event, varargin )
        % Ignore CTRL press
        if (event.getKeyCode() == event.VK_CONTROL)
            return
        end
        % Get the list of all the selected nodes
        selectedPaths = jTreeProtocols.getSelectionPaths();
        if isempty(selectedPaths)
            return
        end
        targetNodes = javaArray('org.brainstorm.tree.BstNode', length(selectedPaths));
        if isempty(targetNodes)
            return
        end
        for iPath = 1:length(selectedPaths)
            targetNodes(iPath) = selectedPaths(iPath).getLastPathComponent();
        end
        % Switch between actions
        switch (event.getKeyCode())
            % ENTER/SPACE = MOUSE DOUBLECLICK
            case {event.VK_ENTER, event.VK_SPACE}
                bst_call(@tree_callbacks, targetNodes(1), 'doubleclick');
            % DELETE/BACKSPACE : DELETE NODE CALLBACK
            case {event.VK_DELETE, event.VK_BACK_SPACE}
                if ismember(char(targetNodes(1).getType()), {'subjectdb', 'studydbsubj', 'studydbcond'})
                    % Cancel action
                else
                    % Replace the "Link to raw file" nodes with their
                    % parent, except for spike-sorted raw files
                    if strcmpi(char(targetNodes(1).getType()), 'rawdata') ...
                            && strcmpi(char(targetNodes(1).getParent().getType()), 'rawcondition') ...
                            && isempty(strfind(targetNodes(1).getFileName(), '_0ephys'))
                        for iNode = 1:length(targetNodes)
                            targetNodes(iNode) = targetNodes(iNode).getParent();
                        end
                    end
                    % Delete nodes
                    bst_call(@node_delete, targetNodes);
                    %node_delete(targetNodes);
                end
            % F5 : REFRESH
            case event.VK_F5
                UpdateTree();
            % CTRL+C: COPY
            case event.VK_C
                if event.isControlDown()
                    CopyNode(targetNodes, 0);
                end
            % CTRL+X: CUT
            case event.VK_X
                if event.isControlDown()
                    CopyNode(targetNodes, 1);
                end
            % CTRL+V: PASTE
            case event.VK_V
                if event.isControlDown()
                    PasteNode(targetNodes);
                end
        end
    end


    %% ===== TREE SELECTION CALLBACK =====
    function protocolTreeSelectionChanged_Callback(hObject, event)
        % Get selected paths
        selectedPaths = event.getSource.getSelectionPaths();
        nbNodes = length(selectedPaths);
        % If less than two nodes selected : nothing to do
        if (nbNodes < 2)
            return
        end
        % If the last node added in the selection is not of the same type
        % or have not the same 'StudyIndex' field
        % than all the previous nodes : select only the new node
        nodeNew = selectedPaths(nbNodes).getLastPathComponent();
        resetSelection = 0;
        iNode = 1;
        while ~resetSelection && (iNode < nbNodes)
            nodePrevious = selectedPaths(iNode).getLastPathComponent();
            if ~strcmpi(getNodeType(nodeNew), getNodeType(nodePrevious))
                % Reset selection
                event.getSource.setSelectionPath(selectedPaths(nbNodes));
                resetSelection = 1;
            else
                iNode = iNode + 1;
            end
        end
        
        function t = getNodeType(bstNode)
            switch lower(char(bstNode.getType()))
                case {'cortex', 'scalp', 'innerskull', 'outerskull', 'other'}
                    t = 'surface';
                case {'results', 'link'}
                    t = 'results';
                otherwise
                    t = lower(char(bstNode.getType()));
            end
        end
    end


    %% ===== TREE CELL EDITION STOP CALLBACK =====
    function protocolTreeEditingStopped_Callback(hObject, ev)
        % Get node handle (old node value)
        bstNode = jTreeProtocols.getSelectionPath.getLastPathComponent();
        % Get new node value
        newComment = char(ev.getSource.getCellEditorValue());
        % If the Comment field changed => need to update the DataBase and the node
        % Node: Cannot rename nodes starting with '(' => Special nodes
        if ~isempty(newComment) && ~strcmp(bstNode.getComment(), newComment) && (newComment(1) ~= '(')
            % Rename node
            bst_call(@node_rename, bstNode, newComment);            
        end       
    end

    %% ===== TREE DROP =====
    function protocolTreeDrop_Callback(hObject, ev)
        % Get Brainstorm GUI structure
        if isempty(ev.getChildIndices())
            isCut = 1;
            if CopyNode(jTreeDragHandler.getSrcNodes(), isCut)
                PasteNode(jTreeDragHandler.getDestNode());
            end
        end
    end
end




%% =================================================================================
%  === TREE FUNCTIONS ==============================================================
%  =================================================================================
%% ===== TREE: SET EXPLORATION MODE =====
% USAGE:  panel_protocols('SetExplorationMode', 'Subjects')
%         panel_protocols('SetExplorationMode', 'StudiesSubj')
%         panel_protocols('SetExplorationMode', 'StudiesCond')
function SetExplorationMode(ExplorationMode) %#ok<DEFNU>
    % Check if display mode changed
    if strcmpi(ExplorationMode, bst_get('Layout', 'ExplorationMode'))
        return
    end
    % Get Brainstorm GUI structure
    ctrl = bst_get('BstControls');
    % Select display mode
    switch (ExplorationMode)
        case 'Subjects',    ctrl.jToolButtonSubject.setSelected(1);
        case 'StudiesSubj', ctrl.jToolButtonStudiesSubj.setSelected(1);
        case 'StudiesCond', ctrl.jToolButtonStudiesCond.setSelected(1);
    end
    % Empty the clipboard
    bst_set('Clipboard', []);
end


%% ===== TREE: GET ROOT NODE =====
function nodeRoot = GetRootNode()
    % Get tree handle
    ctrl = bst_get('PanelControls', 'protocols');
    if isempty(ctrl) || isempty(ctrl.jTreeProtocols)
        nodeRoot = [];
        return;
    end
    % Get root node
    treeModel = ctrl.jTreeProtocols.getModel();
    nodeRoot = treeModel.getRoot();
end


%% ===== TREE: REPAINT =====
function RepaintTree()
    % Get tree handle
    ctrl = bst_get('PanelControls', 'protocols');
    if isempty(ctrl) || isempty(ctrl.jTreeProtocols)
        return;
    end
    % Repaint
    ctrl.jTreeProtocols.repaint();
end


%% ===== TREE: UPDATE =====
% USAGE: panel_protocols('UpdateTree')
function UpdateTree()
    % Get tree handle
    ctrl = bst_get('PanelControls', 'protocols');
    if isempty(ctrl) || isempty(ctrl.jTreeProtocols)
        return;
    end
    % Set tree as loading (remove all nodes and add a "Loading..." node)
    ctrl.jTreeProtocols.setLoading(1);
    % Get root node
    nodeRoot = ctrl.jTreeProtocols.getModel.getRoot();
    % If protocol is not empty : fill the tree
    defNode = [];
    % Switch according to the mode button that is checked
    switch bst_get('Layout', 'ExplorationMode')
        case 'Subjects',     defNode = node_create_db_subjects(nodeRoot);
        case 'StudiesSubj',  defNode = node_create_db_studies(nodeRoot, 'subject');
        case 'StudiesCond',  defNode = node_create_db_studies(nodeRoot, 'condition');
    end
    % Remove "Loading..." node, validate changes and redraw tree
    ctrl.jTreeProtocols.setLoading(0);
    drawnow;
    % If a default node is defined : select and expand it
    if ~isempty(defNode)
        % Expand default node
        ExpandPath(defNode, 1);   
        % If default node is a study node
        if ismember(char(defNode.getType()), {'study', 'studysubject', 'condition', 'rawcondition'})
            % Select study node
            SelectStudyNode(defNode);
        end
    end
end


%% =================================================================================
%  === NODES FUNCTIONS =============================================================
%  =================================================================================
%% ===== NODE: CREATE STUDY NODE =====
function CreateStudyNode(nodeStudy) %#ok<DEFNU>
    % If node is already generated: return
    if isempty(nodeStudy.getUserObject())
        return;
    end
    % Remove existing nodes
    nodeStudy.removeAllChildren();
    % Get study and subject
    iStudy = nodeStudy.getStudyIndex();
    sStudy = bst_get('Study', iStudy);
    if isempty(sStudy)
        return;
    end
    % Get subject
    sSubject = bst_get('Subject', sStudy.BrainStormSubject);
    % Create node sub-tree
    UseDefaultChannel = ~isempty(sSubject) && (sSubject.UseDefaultChannel ~= 0);
    isExpandTrials = 1;
    node_create_study(nodeStudy, sStudy, iStudy, isExpandTrials, UseDefaultChannel);
    % Mark as updated
    nodeStudy.setUserObject([]);
    % Get tree handle
    ctrl = bst_get('PanelControls', 'protocols');
    if isempty(ctrl) || isempty(ctrl.jTreeProtocols)
        return;
    end
    ctrl.jTreeProtocols.getModel.reload(nodeStudy);
end


%% ===== NODE: UPDATE =====
% Update a set of tree nodes.
% USAGE:  panel_protocols('UpdateNode', 'Subject', iSubjects)
%         panel_protocols('UpdateNode', 'Study',   iStudies)
%         panel_protocols('UpdateNode', 'Study',   iStudies, isExpandTrials)
function UpdateNode(category, indices, isExpandTrials)
    % Parse inputs
    if (nargin < 2) || ~ischar(category) || ~isnumeric(indices) || isempty(indices)
        error('Invalid call to UpdateNode.');
    end
    if (nargin < 3) || isempty(isExpandTrials)
        isExpandTrials = 1;
    end
    % Get tree handle
    ctrl = bst_get('PanelControls', 'protocols');
    if isempty(ctrl) || isempty(ctrl.jTreeProtocols)
        return;
    end
    % Get root of the exploration tree 
    treeModel   = ctrl.jTreeProtocols.getModel();
    nodeRootTmp = treeModel.getRoot();
    if isempty(nodeRootTmp) || (nodeRootTmp.getChildCount() == 0)
        return
    end
    nodeRoot = nodeRootTmp.getChildAt(0);
    isUpdateWholeTree = 0;
    if isempty(nodeRoot)
        return
    end
    % Switch between nodes type to update
    switch lower(category)
        case 'subject'
            % Get Protocol information
            ProtocolSubjects = bst_get('ProtocolSubjects');
            for i = 1:length(indices)
                iSubject = indices(i);
                % Exploration mode
                switch bst_get('Layout', 'ExplorationMode')
                    case 'Subjects'
                        % Find the target subject node
                        nodeSubject = nodeRoot.findChild('subject', iSubject, -1, 0);
                        % If subject node already exists : refresh it
                        if ~isempty(nodeSubject)
                            % Remove all children from this node
                            nodeSubject.removeAllChildren();
                            % Create new subject node (default node / normal node)
                            if (iSubject == 0)
                                node_create_subject(nodeSubject, ProtocolSubjects.DefaultSubject, 0);
                            else
                                node_create_subject(nodeSubject, ProtocolSubjects.Subject(iSubject), iSubject);
                            end
                            % Refresh node display
                            treeModel.reload(nodeSubject);
                        % Else: reload the whole tree
                        else
                            UpdateTree();
                        end
                    case {'StudiesSubj', 'StudiesCond'}
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        %%%%%%%%%% INCORRECT : NEED TO PERFORM A SEARCH OF MULTIPLE NODES (ie. node.findChildren())
                        %%%%%%%%%% => THERE MIGHT BE MANY studysubject NODES FOR ONE GIVEN SUBJECT,
                        %%%%%%%%%%    (ONLY WHEN EXPLORATION MODE 'IS StudiesCond')
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        % Find the target study/subject node
                        nodeStudy = nodeRoot.findChild('studysubject', -1, iSubject, 1);
                        % Node is found: update node
                        if ~isempty(nodeStudy)
                            % Update node name
                            nodeStudy.setComment(ProtocolSubjects.Subject(iSubject).Name);
                            % Refresh node display
                            treeModel.reload(nodeStudy);
                        % Node was not found: update whole tree
                        else
                            UpdateTree();
                        end
                end
            end

        case 'study'
            % For each study
            for i = 1:length(indices)
                iStudy = indices(i);
                % Get study
                sStudy  = bst_get('Study', iStudy);
                % Exploration mode
                switch bst_get('Layout', 'ExplorationMode')
                    case 'Subjects'
                        % NOTHING TO DO
                    case {'StudiesSubj', 'StudiesCond'}
                        % Find the target study node (possible types: studysubject, condition, study)
                        nodeStudy = [nodeRoot.findChild('studysubject', iStudy, -1, 1), ...
                                     nodeRoot.findChild('condition',    iStudy, -1, 1), ...
                                     nodeRoot.findChild('rawcondition', iStudy, -1, 1), ...
                                     nodeRoot.findChild('study',        iStudy, -1, 1), ...
                                     nodeRoot.findChild('defaultstudy', iStudy, -1, 1)];
                        if ~isempty(nodeStudy)
                            nodeStudy = nodeStudy(1);                           
                            % Do not update nodes are haven't been created yet ("Loading...")
                            if (nodeStudy.getChildCount() == 1) && strcmpi(char(nodeStudy.getChildAt(0).getType()), 'loading')
                                continue;
                            end
                            % Remove all children from this node
                            nodeStudy.removeAllChildren();
                            % Get associated subject
                            sSubject = bst_get('Subject', sStudy.BrainStormSubject);
                            % Create new study node (default node / normal node)
                            UseDefaultChannel = ~isempty(sSubject) && (sSubject.UseDefaultChannel ~= 0);
                            node_create_study(nodeStudy, sStudy, iStudy, isExpandTrials, UseDefaultChannel);
                            % Refresh node display
                            ctrl.jTreeProtocols.getModel.reload(nodeStudy);
                            drawnow
                            
                        % Node was not found: update whole tree
                        else
                            isUpdateWholeTree = 1;
                        end
                end
            end
    end
    if isUpdateWholeTree
        UpdateTree();
    end
end


%% ===== NODE: RELOAD =====
% Reload a tree node (parse again the underlying files).
% USAGE: panel_protocols('ReloadNode', bstNode)
function ReloadNode(bstNode) %#ok<DEFNU>
    nodeType = lower(char(bstNode.getType()));
    nodeFileName = char(bstNode.getFileName());
    iStudy = bstNode.getStudyIndex();
    iItem  = bstNode.getItemIndex();

    switch nodeType
        case {'subjectdb', 'studydbsubj', 'studydbcond'}
            bst_memory('UnloadAll', 'Forced');
            isError = db_reload_database('current');
            if isError
                gui_brainstorm('SetCurrentProtocol');
            end

        case 'subject'
            bst_memory('UnloadAll', 'Forced');
            % Reload current subject only
            db_reload_subjects(iStudy);

        case 'study'
            % Reload current study only
            if (iStudy ~= 0)
                db_reload_studies(iStudy);
            end

        case 'defaultstudy'
            bst_memory('UnloadAll', 'Forced');
            % Reload current study only
            db_reload_studies(iStudy);
            % Update whole tree display
            UpdateTree();

        case 'studysubject'
            % If StudySubject node is a Study node (datasets displayed in it)
            if (iStudy ~= 0)
                % Reload only study
                db_reload_studies(iStudy);
            % Else node is a directory node (only contains conditions)
            else
                % Reload subject
                db_reload_subjects(iItem);
                % Reload all conditions for the subject
                iNewStudies = db_reload_conditions(iItem);
            end

        case {'condition', 'rawcondition'}
            % If Condition node is a Study node (datasets displayed in it)
            if (iStudy ~= 0)
                % Reload only study
                db_reload_studies(iStudy);
            % Else node is a directory node (contains conditions/studysubject nodes)
            else
                % Reload all the studies that have this condition
                [sSubjects, iStudies] = bst_get('StudyWithCondition', nodeFileName);
                db_reload_studies(iStudies);
            end
    end
end


%% ===== NODE: COLLAPSE ANCESTOR =====
% Collapse parents of given nodes.
% USAGE:  panel_protocols('CollapseAncestor', nodeType, bstNodes )
%         panel_protocols('CollapseAncestor', nodeType )
function CollapseAncestor( nodeCategory, bstNodes ) %#ok<DEFNU>
    % Get tree handle
    ctrl = bst_get('PanelControls', 'protocols');
    if isempty(ctrl) || isempty(ctrl.jTreeProtocols)
        return;
    end
    % If nodes list is not specified : get selected nodes
    if (nargin < 2) || isempty(bstNodes)
        % Get nodes selected in tree
        selectedPaths = ctrl.jTreeProtocols.getSelectionPaths();
        if isempty(selectedPaths)
            return
        end
        bstNodes = javaArray('org.brainstorm.tree.BstNode', length(selectedPaths));
        for iPath = 1:length(selectedPaths)
            bstNodes(iPath) = selectedPaths(iPath).getLastPathComponent();
        end
    end
    if isempty(bstNodes)
        return
    end

    % For each node : find ancestor of the right type
    for i=1:length(bstNodes)
        % Find node
        switch lower(nodeCategory)
            case 'subject'
                nodeFound = [bstNodes(i).findAncestor('subject', -1, -1), ...
                             bstNodes(i).findAncestor('studysubject', -1, -1)];
            case 'study'
                nodeFound = [bstNodes(i).findAncestor('study', -1, -1), ...
                             bstNodes(i).findAncestor('condition', -1, -1), ...
                             bstNodes(i).findAncestor('rawcondition', -1, -1), ...
                             bstNodes(i).findAncestor('studysubject', -1, -1)];
            case 'data'
                nodeFound = bstNodes(i).findAncestor('data', -1, -1);
            case 'rawdata'
                nodeFound = bstNodes(i).findAncestor('rawdata', -1, -1);
            otherwise
                return
        end     

        % Select node
        if ~isempty(nodeFound)
            % Get node path
            treeModel = ctrl.jTreeProtocols.getModel();
            nodes = treeModel.getPathToRoot(nodeFound(1));
            path_ = java_create('javax.swing.tree.TreePath', 'Ljava.lang.Object;', nodes);
            % Collapse tree
            ctrl.jTreeProtocols.collapsePath(path_);
        end
    end
end


%% ===== NODE: EXPAND PATH =====
% Expand a tree node, and optionally select it.
% USAGE:  panel_protocols('ExpandPath', bstNode, isSelected )
function ExpandPath(bstNode, isSelected)
    % Get tree handle
    ctrl = bst_get('PanelControls', 'protocols');
    if isempty(ctrl) || isempty(ctrl.jTreeProtocols)
        return;
    end
    % Get node path
    treeModel = ctrl.jTreeProtocols.getModel();
    nodes = treeModel.getPathToRoot(bstNode);
    % Create path
    jPath = java_create('javax.swing.tree.TreePath', 'Ljava.lang.Object;', nodes);
    % If node is not displayed: do nothing
    if (jPath.getPathCount() < 2)
        return
    end
    % Set path selected
    if isSelected
        ctrl.jTreeProtocols.setSelectionPath(jPath);
    end
    % Expand path
    ctrl.jTreeProtocols.expandPath(jPath);
    % Scroll to visible
    ctrl.jTreeProtocols.scrollPathToVisible(jPath);
end


%% ===== NODE: SELECT =====
% Find a node in the exploration tree and select it.
% USAGE:  nodeFound = panel_protocols('SelectNode', nodeRoot, nodeType, iStudy, iFile )
%         nodeFound = panel_protocols('SelectNode', nodeRoot, FileName )
% INPUT:
%    - nodeType   : {'subject', 'study', 'condition', 'data', 'channel', ...}, or '' to ignore node type from search
%    - iStudy : node's value of iStudy, or -1 to ignore this criteria
%    - iFile  : node's value of iFile, or -1 to ignore this criteria
function nodeFound = SelectNode(varargin)
    % Find node
    nodeFound = GetNode(varargin{:});
    % Select node
    if ~isempty(nodeFound)
        ExpandPath(nodeFound, 1);
    end
end


%% ===== NODE: SELECT STUDY =====
% Select and expand the input study in database tree.
% USAGE:   nodeStudy = panel_protocols('SelectStudyNode', nodeStudy ) % Select given 'study' tree node
%          nodeStudy = panel_protocols('SelectStudyNode', iStudy )    % Find 'study' tree node with studyIndex = iStudy and select it
function nodeStudy = SelectStudyNode( varargin )
    global TreeMarkedNode;
    % ===== PARSE INPUTS =====
    if isnumeric(varargin{1})
        iStudy = varargin{1};
        nodeStudy = SelectNode([], {'study','condition','rawcondition','studysubject'}, iStudy, -1);
    else
        nodeStudy = varargin{1};
    end
    if isempty(nodeStudy)
        return;
    else
        nodeStudy = nodeStudy(1);
    end
    % ===== UNMARK ALL OTHER NODES =====
    % Umark all marked nodes
    for i=1:length(TreeMarkedNode)
        if ishandle(TreeMarkedNode(i))
            TreeMarkedNode(i).setMarked(0);
        end
    end
    % ===== MARK SELECTED NODE =====
    % Mark current study node (parent node)
    nodeStudy.setMarked(1);
    TreeMarkedNode = nodeStudy;
    % Redraw tree
    RepaintTree();
    drawnow;
    % Update selected study in ProtocolInfo
    ProtocolInfo = bst_get('ProtocolInfo');
    ProtocolInfo.iStudy = nodeStudy.getStudyIndex();
    bst_set('ProtocolInfo', ProtocolInfo);
    % ===== UPDATE SCOUTS PANEL =====
    % Get parent Subject node
    nodeSubject = nodeStudy.findAncestor('subject', -1, -1);
    if isempty(nodeSubject)
        nodeSubject = nodeStudy.findAncestor('studysubject', -1, -1);
    end
    if isempty(nodeSubject)
        return
    end
    % Get subject structure
    sSubject = bst_get('Subject', char(nodeSubject.getFileName()));
    if isempty(sSubject)
        return
    end
end


%% ===== NODE: GET =====
% Find a node in the exploration tree.
% USAGE:  nodeFound = panel_protocols('GetNode', nodeRoot, nodeTypes, iStudy, iFile )
%         nodeFound = panel_protocols('GetNode', nodeRoot, FileName )
% INPUT:
%    - nodeType   : {'subject', 'study', 'condition', 'data', 'channel', ...}, or '' to ignore node type from search
%    - studyIndex : node's value of studyIndex, or -1 to ignore this criteria
%    - itemIndex  : node's value of itemIndex, or -1 to ignore this criteria
function nodeFound = GetNode( nodeRoot, nodeTypes, iStudy, iFile )
    nodeFound = [];
    % CALL: panel_protocols('GetNode', nodeRoot, FileName )
    if (nargin <= 2)
        % Find file in database
        FileName = nodeTypes;
        [sStudy, iStudy, iFile, nodeTypes] = bst_get('AnyFile', FileName);
        if isempty(sStudy)
            return
        end
        isExpand = 1;
    else
        isExpand = 0;
    end
    % Some files may have different types: make sure we are considering them all
    if ~iscell(nodeTypes)
        switch(nodeTypes)
            case 'data'
                nodeTypes = {'data','rawdata'};
            case 'results'
                nodeTypes = {'results','link','kernel'};
            case 'timefreq'
                nodeTypes = {'timefreq','spectrum','ptimefreq','pspectrum'};
            case 'ptimefreq'
                nodeTypes = {'ptimefreq','pspectrum'}; 
            case 'tess'
                nodeTypes = {'other'};
            otherwise
                nodeTypes = {nodeTypes};
        end
    end
    % Search node not specified, use tree root
    if isempty(nodeRoot)
        nodeRoot = GetRootNode();
        if isempty(nodeRoot)
            return;
        end
    end
    % Find node
    for i = 1:length(nodeTypes)
        nodeFound = nodeRoot.findChild(nodeTypes{i}, iStudy, iFile, 1);
        if ~isempty(nodeFound)
            return;
        end
    end
    % If nothing was found: expand the trials lists to look for the files
    if isExpand
        % Get study node
        nodeStudy = [nodeRoot.findChild('condition', iStudy, -1, 1), ...
                     nodeRoot.findChild('studysubject', iStudy, -1, 1), ...
                     nodeRoot.findChild('rawcondition', iStudy, -1, 1), ...
                     nodeRoot.findChild('study', iStudy, -1, 1), ...
                     nodeRoot.findChild('defaultstudy', iStudy, -1, 1)];
        if isempty(nodeStudy)
            return; 
        else
            nodeStudy = nodeStudy(1);
        end
        % If this node is not rendered yet: render it
        if (nodeStudy.getChildCount() == 1) && strcmpi(char(nodeStudy.getChildAt(0).getType()), 'loading')
            CreateStudyNode(nodeStudy);
            % Find node again
            for i = 1:length(nodeTypes)
                nodeFound = nodeStudy.findChild(nodeTypes{i}, iStudy, iFile, 1);
                if ~isempty(nodeFound)
                    return;
                end
            end
        end
        % Look for trial lists in this study: expand them
        for i = 1:nodeStudy.getChildCount()
            % Get child node
            nodeChild = nodeStudy.getChildAt(i-1);
            % If child node is a trial list: expand it and look again for data file
            if ismember(char(nodeChild.getType()), {'datalist', 'matrixlist'})
                UpdateNode('Study', iStudy, 1);
                nodeFound = GetNode( nodeRoot, nodeTypes, iStudy, iFile );
                return;
            end
        end
    end
end


%% ===== NODE: MARK UNIQUE =====
% Mark a given tree node, and unmark all the other nodes of the same type, in the same tree level.
% USAGE: panel_protocols('MarkUniqueNode', bstNode)
function MarkUniqueNode( bstNode ) %#ok<DEFNU>
    % Get parent node
    nodeParent = bstNode.getParent();
    % For each children node
    for iNode = 0:nodeParent.getChildCount()-1
        % If current node is target node : select it
        if (nodeParent.getChildAt(iNode) == bstNode)
            bstNode.setMarked(1);
        % If node type is target node type : unmark the node
        elseif nodeParent.getChildAt(iNode).getType.equalsIgnoreCase(bstNode.getType())
            nodeParent.getChildAt(iNode).setMarked(0);
        end
    end
end


%% ===== NODE: COPY =====
function isCopied = CopyNode( bstNodes, isCut )
    % Empty previous clipboard
    bst_set('Clipboard', []);
    isCopied = 0;
    % Get nodes types
    nodeType = {};
    for i = 1:length(bstNodes)
        nodeType{i} = lower(char(bstNodes(i).getType()));
    end
    % Cannot copy multiple unique nodes
    if ismember(nodeType{1}, {'channel', 'anatomy', 'noisecov', 'ndatacov'}) && (length(bstNodes) > 1)
        bst_error(['Cannot copy multiple ' nodeType{1} ' nodes.'], 'Clipboard', 0);
        return;
    % Can only copy data files
    elseif ismember(nodeType{1}, {'defaultanat', 'subjectdb', 'studydbsubj', 'studydbcond', 'study', 'studysubject', 'defaultstudy', 'condition', 'rawcondition', 'subject', 'image'})
        bst_error(['Folders cannot be copied or moved.' 10 'To duplicate a subject or a condition, use the popup menu File > Duplicate.'], 'Clipboard', 0);
        return;
    % No links
    elseif any(ismember(nodeType, {'link', 'rawdata'}))
        bst_error('Links cannot be copied or moved.', 'Clipboard', 0);
        return;
%     % No stat
%     elseif any(ismember(nodeType, {'pdata', 'presults', 'ptimefreq', 'pspectrum', 'pmatrix'}))
%         bst_error('This type of file cannot be copied or moved.', 'Clipboard', 0);
%         return;
    % No filename
    elseif isempty(bstNodes(1).getFileName())
        bst_error('No file copied.', 'Clipboard', 0);
        return;
    % No kernel-based time-freq
    elseif any(ismember(nodeType, {'timefreq', 'spectrum'})) && ~isempty(strfind(char(bstNodes(1).getFileName()), '_KERNEL_'))
        bst_error('This type of file cannot be copied or moved.', 'Clipboard', 0);
        return;
    % Datalist/Matrixlist: copy all the child nodes
    elseif ismember(nodeType, {'datalist', 'matrixlist'})
        listNodes = bstNodes;
        bstNodes = repmat(bstNodes, 0);
        for iList = 1:length(listNodes)
            for iChild = 1:listNodes(iList).getChildCount()
                bstNodes = [bstNodes, listNodes(iList).getChildAt(iChild-1)];
            end
        end
    end
    % Copy nodes to the clipboard
    bst_set('Clipboard', bstNodes, isCut);
    isCopied = 1;
end


%% ===== NODE: PASTE =====
function destFile = PasteNode( targetNode )
    destFile = {};
    % Get copied nodes
    [srcNodes, isCut] = bst_get('Clipboard');
    if isempty(srcNodes)
        return
    end
    firstSrcType = lower(char(srcNodes(1).getType()));
    isAnatomy = ismember(firstSrcType, {'anatomy','cortex','scalp','innerskull','outerskull','fibers','fem','other'});
    % Get all target studies/subjects
    iTarget = [];
    for i = 1:length(targetNode)
        iTarget(end+1) = targetNode(i).getStudyIndex();
    end
    % Can only copy towards one target
    iTarget = unique(iTarget);
    if (length(iTarget) > 1)
        bst_error('Cannot copy file towards multiple folders.', 'Clipboard', 0);
        return;
    end
    
    % Cannot copy anat files to a subject using default anatomy
    if isAnatomy
        sSubjectTarget = bst_get('Subject', iTarget);
        if sSubjectTarget.UseDefaultAnat
            bst_error('Destination subject uses the default anatomy.', 'Clipboard', 0);
            destFile = {};
            return;
        end
    % Non-anat files: requires a iStudy that is not zero
    elseif (iTarget == 0)
        destFile = {};
        return;
    else
        sStudyTarget = bst_get('Study', iTarget);
        [sSubjectTargetRaw, iSubjectTargetRaw] = bst_get('Subject', sStudyTarget.BrainStormSubject, 1);
    end
    % Channel/Headmodel/NoiseCov/Kernel: Make sure that target study is the right one
    if ismember(firstSrcType, {'channel', 'headmodel', 'noisecov', 'ndatacov', 'kernel'})
        % Get channel study for the target study
        [sChannel, iChanStudy] = bst_get('ChannelForStudy', iTarget);
        % If not the same: error
        if (iChanStudy ~= iTarget)
            bst_error('Invalid destination.', 'Clipboard', 0);
            destFile = {};
            return;
        end
    end
    
    % Progress bar
    if (length(srcNodes) > 1)
        bst_progress('start', 'Database explorer', 'Copying files...', 0, length(srcNodes));
    else
        bst_progress('start', 'Database explorer', 'Copying files...');
    end
    % Copy: Process file one by one
    for i = 1:length(srcNodes)
        % Get source filename
        srcFile = char(srcNodes(i).getFileName());
        srcType = lower(char(srcNodes(i).getType()));
        iSrcStudy = srcNodes(i).getStudyIndex();
        % Cannot copy (channel/noisecov/MRI) or move to the same folder
        if (isCut || ismember(srcType, {'channel', 'noisecov', 'ndatacov', 'anatomy'})) && (iSrcStudy == iTarget)
            bst_error('Source and destination folders are the same.', 'Clipboard', 0);
            destFile = {};
            return;
        end
        % Copy file
        destFile{i} = CopyFile(iTarget, srcFile, srcType, iSrcStudy);
        if isempty(destFile{i})
            bst_progress('stop');
            return;
        end
        % Increment progress bar
        if (length(srcNodes) > 1)
            bst_progress('inc', 1);
        end
    end
    % Reloading the target study
    if isAnatomy
        db_reload_subjects(iTarget);
    else
        db_reload_studies(iTarget);
    end
    % If moving files instead of copying    
    if isCut
        % Delete source file
        node_delete(srcNodes, 0);
        % Empty clipboard after moving
        bst_set('Clipboard', []);
    end
    % Select last copied file in the tree
    panel_protocols('SelectNode', [], destFile{end});
    % Close progress bar
    bst_progress('stop');
end


%% ===== COPY FILE =====
% USAGE:   destFile = CopyFile(iTarget, srcFile, srcType, iSrcStudy, sSubjectTargetRaw)
%          destFile = CopyFile(iTarget, srcFile)
function destFile = CopyFile(iTarget, srcFile, srcType, iSrcStudy, sSubjectTargetRaw)
    % File info is not passed in input
    if (nargin < 5)
        [sStudySrc, iSrcStudy, iSrcFile, srcType] = bst_get('AnyFile', srcFile);
        sStudyTarget = bst_get('Study', iTarget);
        [sSubjectTargetRaw, iSubjectTargetRaw] = bst_get('Subject', sStudyTarget.BrainStormSubject, 1);
    end
    isAnatomy = ismember(srcType, {'anatomy','cortex','scalp','innerskull','outerskull','fibers','fem','other'});
    % Get source subject
    if ~isAnatomy
        sStudySrc   = bst_get('Study', iSrcStudy);
        [sSubjectSrcRaw, iSubjectSrcRaw] = bst_get('Subject', sStudySrc.BrainStormSubject, 1);
        % Check if the subject changes
        UseDefaultAnatSrc    = (sSubjectSrcRaw.UseDefaultAnat == 1)    || (iSubjectSrcRaw == 0);
        UseDefaultAnatTarget = (sSubjectTargetRaw.UseDefaultAnat == 1) || (iSubjectTargetRaw == 0);
        isSameSubjAnat = file_compare(sSubjectTargetRaw.FileName, sSubjectSrcRaw.FileName) || (UseDefaultAnatSrc && UseDefaultAnatTarget);
        % Check if the channel study changes
        UseDefaultChannelSrc    = (sSubjectSrcRaw.UseDefaultChannel == 2)    || (iSubjectSrcRaw == 0);
        UseDefaultChannelTarget = (sSubjectTargetRaw.UseDefaultChannel == 2) || (iSubjectTargetRaw == 0);
        isSameSubjChan = file_compare(sSubjectTargetRaw.FileName, sSubjectSrcRaw.FileName) || (UseDefaultChannelSrc && UseDefaultChannelTarget);
    else
        isSameSubjAnat = (iSrcStudy == iTarget);
        isSameSubjChan = (iSrcStudy == iTarget);
    end
    % Noise covariance: copy using db_set_noisecov
    if strcmpi(srcType, 'noisecov')
        destFile = db_set_noisecov(iSrcStudy, iTarget, 0);
        if ~isempty(destFile)
            destFile = destFile{1};
        end
        return;
    elseif strcmpi(srcType, 'ndatacov')
        destFile = db_set_noisecov(iSrcStudy, iTarget, 1);
        if ~isempty(destFile)
            destFile = destFile{1};
        end
        return;
    end
    % If reading a kernel file: Read full results, and save them again
    if strcmpi(srcType, 'results') && ~isempty(strfind(srcFile, '_KERNEL_'))
        src = in_bst_results(srcFile, 1);
        % Remove all the links (if not in the same study)
        if (iSrcStudy ~= iTarget)
            src.DataFile = '';
            if ~isSameSubjAnat
                src.SurfaceFile = '';
            end
            if ~isSameSubjChan
                src.HeadModelFile = '';
            end
        else
            src.DataFile = file_short(src.DataFile);
            if (src.DataFile(1) == '/')
                src.DataFile(1) = [];
            end
        end
    % Reading other files with references: remove references
    elseif ismember(srcType, {'results', 'headmodel', 'timefreq', 'spectrum', 'presults', 'ptimefreq', 'pspectrum', 'dipoles'})
        src = load(file_fullpath(srcFile));
        if (iSrcStudy ~= iTarget)
            if isfield(src, 'DataFile')
                src.DataFile = '';
            end
            if isfield(src, 'HeadModelFile') && ~isSameSubjChan
                src.HeadModelFile = '';
            end
            if isfield(src, 'SurfaceFile') && ~isSameSubjAnat
                src.SurfaceFile = '';
            end
        end
    else
        src = srcFile;
    end
    % Copy file
    destFile = db_add(iTarget, src, 0);
    if isempty(destFile)
        return
    end
    % If reading a surface file: ignore all the intermediate computations
    if ismember(srcType, {'cortex','scalp','innerskull','outerskull','other'})
        [tmpTessMat, TessFile] = in_tess_bst(destFile, 0);
        TessMat.Vertices = tmpTessMat.Vertices;
        TessMat.Faces    = tmpTessMat.Faces;
        TessMat.Comment  = tmpTessMat.Comment;
        TessMat.Atlas    = tmpTessMat.Atlas;
        TessMat.iAtlas   = tmpTessMat.iAtlas;
        if isfield(tmpTessMat, 'Reg')
            TessMat.Reg = tmpTessMat.Reg;
        end
        bst_save(TessFile, TessMat, 'v7');
    end
end



%% =================================================================================
%  === OTHER FUNCTIONS =============================================================
%  =================================================================================

%% ===== NODE: HEAD MODEL =====
% Call head modeler GUI for the given tree nodes.
% USAGE:  panel_protocols('TreeHeadModel', bstNode)
function OutputFiles = TreeHeadModel( bstNodes ) %#ok<DEFNU>
    OutputFiles = {};
    % Get selected channel studies
    iChanStudies = tree_channel_studies( bstNodes, 'NoIntra' );
    % Nothing to process: return
    if isempty(iChanStudies)
        bst_error('Missing channel information.', 'Compute head model', 0);
        return
    end
    % Get first study 
    sStudy = bst_get('Study', iChanStudies(1));
    sSubject = bst_get('Subject', sStudy.BrainStormSubject);
    % DEFAULT ANAT: Check if the positions of the fiducials have been validated
    if ~isempty(sSubject.Anatomy)
        figure_mri('FiducialsValidation', sSubject.Anatomy(sSubject.iAnatomy).FileName);
    end
    % Check that the default cortex is not the high resolution one
    if ~isempty(sSubject.iCortex) && ~isempty(sSubject.Surface) && (sSubject.iCortex <= length(sSubject.Surface))
        nVertices = sscanf(sSubject.Surface(sSubject.iCortex).Comment, 'cortex_%dV');
        if (length(nVertices) == 1) && (nVertices > 100000) && ~java_dialog('confirm', sprintf([...
                    '<HTML>Warning: The selected cortex surface has <FONT COLOR="#FF0000">%d vertices</FONT>.\n' ...
                    'This resolution is very high and may cause memory issues in the source analysis.\n\n' ...
                    'To use a cortex surface with a lower resolution: Click "No", go to the anatomy view\n' ...
                    'and double-click on a surface with a lower resolution (eg. 15000V).\n\n' ...
                    'Proceed with the high-resolution cortex surface?'], nVertices), 'High-resolution cortex')
            return;
        end
    end
    % Call head modeler
    [OutputFiles, errMessage] = panel_headmodel('ComputeHeadModel', iChanStudies);
    % Error
    if isempty(OutputFiles) && ~isempty(errMessage)
        bst_error(errMessage, 'Compute head model', 0);
    elseif ~isempty(errMessage)
        java_dialog('warning', errMessage, 'Compute head model');
    end
end


%% ===== NODE: SOURCE GRID =====
% Just compute a source grid without the corresponding forward model.
% USAGE:  panel_protocols('TreeSourceGrid', bstNode)
function OutputFiles = TreeSourceGrid( bstNodes ) %#ok<DEFNU>
    % Get selected channel studies
    iChanStudies = tree_channel_studies( bstNodes, 'NoIntra' );
    iStudy = iChanStudies(1);
    % Get first study 
    sStudy = bst_get('Study', iStudy);
    sSubject = bst_get('Subject', sStudy.BrainStormSubject);
    % DEFAULT ANAT: Check if the positions of the fiducials have been validated
    if ~isempty(sSubject.Anatomy)
        figure_mri('FiducialsValidation', sSubject.Anatomy(sSubject.iAnatomy).FileName);
    end
    % Call head modeler
    OutputFiles = panel_headmodel('GenerateSourceGrid', iStudy);
end


%% ===== NODE: INVERSE MODEL =====
function OutputFiles = TreeInverse(bstNodes, Version) %#ok<DEFNU>
    OutputFiles = {};
    % Get node type
    nodeType = lower(char(bstNodes(1).getType()));
    % Data file: gets "data file" dependence, else get channel studies
    if ismember(nodeType, {'rawdata', 'data'})
        [iStudies, iDatas] = tree_dependencies(bstNodes, 'data');
    else
        iStudies = tree_channel_studies( bstNodes, 'NoIntra' );
        iDatas = [];
    end
    % If no studies selected
    if isempty(iStudies) 
        return;
    elseif isequal(iStudies, -10)
        bst_error('Error in file selection.', 'Compute sources', 0);
        return;
    end
    % Get studies structures
    sStudies = bst_get('Study', iStudies);
    % If all the studies have one and only one data file: switch to non-shared kernels
    if all(cellfun(@(c)isequal(length(c),1), {sStudies.Data}))
        % And if the files are not RAW
        sAllData = [sStudies.Data];
        if ~any(strcmpi({sAllData.DataType}, 'raw'))
            iDatas = ones(size(iStudies));
        end
    end
    % Call inverse function
    switch Version
        case '2009'
            [OutputFiles, errMessage] = process_inverse('Compute', iStudies, iDatas);
        case '2016'
            [OutputFiles, errMessage] = process_inverse_2016('Compute', iStudies, iDatas);
        case '2018'
            [OutputFiles, errMessage] = process_inverse_2018('Compute', iStudies, iDatas);
    end
    % Error
    if isempty(OutputFiles) && ~isempty(errMessage)
        bst_error(errMessage, 'Compute sources', 0);
    end
end


%% ===== SELECT SUBJECT =====
function SelectSubject(SubjectName) %#ok<DEFNU>
    % Check input subject name
    if ~ischar(SubjectName) || isempty(SubjectName)
        return;
    end
    % Get subject 
    [sSubject, iSubject] = bst_get('Subject', SubjectName);
    if isempty(sSubject)
        return;
    end
    % Get exploration mode
    ExplorationMode = bst_get('Layout', 'ExplorationMode');
    % Select different nodes depending on the exploration mode
    switch (ExplorationMode)
        case 'Subjects'
            % Select first MRI
            if ~isempty(sSubject.Anatomy)
                SelectNode([], 'anatomy', iSubject, 1);
            else
                SelectNode([], 'subject', iSubject, -1);
            end
        case {'StudiesCond', 'StudiesSubj'}
            % Get all the studies for this subject
            [sStudies, iStudies] = bst_get('StudyWithSubject', sSubject.FileName);
            % Select first study
            if ~isempty(iStudies)
                SelectStudyNode(iStudies(1));
            else
                SelectNode([], 'studysubject', -1, iSubject);
            end
    end
end


%% ===== EXPAND/COLLAPSE ALL =====
function ExpandAll(isExpand) %#ok<DEFNU>
    % Get tree handle
    ctrl = bst_get('PanelControls', 'protocols');
    if isempty(ctrl) || isempty(ctrl.jTreeProtocols)
        return;
    end
%     % Get node path
%     treeModel = ctrl.jTreeProtocols.getModel();
%     nodes = treeModel.getPathToRoot(bstNode);
%     % Create path
%     jPath = java_create('javax.swing.tree.TreePath', 'Ljava.lang.Object;', nodes);
    
    jPath = java_create('javax.swing.tree.TreePath', 'Ljava.lang.Object;', ctrl.jTreeProtocols.getModel().getRoot());
    ExpandAllRecursive(jPath);

    function ExpandAllRecursive(parent)
        % Traverse children
        node = parent.getLastPathComponent();
        e = node.children();
        if (node.getChildCount() >= 0)
            while (e.hasMoreElements())
                n = e.nextElement();
                ExpandAllRecursive(parent.pathByAddingChild(n));
            end
        end
        % Expansion or collapse must be done bottom-up
        if (isExpand)
            ctrl.jTreeProtocols.expandPath(parent);
        elseif ~ctrl.jTreeProtocols.isCollapsed(parent) && (parent.getPathCount() > 2)
            ctrl.jTreeProtocols.collapsePath(parent);
        end
    end
end

