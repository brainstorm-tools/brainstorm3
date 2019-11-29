function varargout = panel_nodelist( varargin )
% PANEL_NODELIST: Creation and management of tree that contains a list of files.
%
% USAGE:          bstPanelNew = panel_nodelist('CreatePanel', panelName, panelTitle)
%       [nodelist, iNodelist] = panel_nodelist('GetNodelist', nodelistName)             : Return specified nodelist
%       [nodelist, iNodelist] = panel_nodelist('GetNodelist')                           : Return all nodelists
%                               panel_nodelist('SetNodelist', iNodelist, nodelist)      : Update existing nodelist
%                               panel_nodelist('SetNodelist', [], nodelist)             : Add new nodelist
%                               panel_nodelist('SetListEnabled', isEnabled)             : Enables/disables the list
%                               panel_nodelist('UpdatePanel', nodelistNames, isReset)   : Update the specified nodelist
%                               panel_nodelist('UpdatePanel', nodelistNames)            : isReset = 1
%                               panel_nodelist('UpdatePanel')                           : Update all the nodelists
%                      nFiles = panel_nodelist('AddFiles', TreeName, Filenames, isTreeUpdate)
%                      nFiles = panel_nodelist('AddFiles', TreeName, Filenames)              : isTreeUpdate = 1
%                               panel_nodelist('AddNodes', nodelistName, bstNodes)
%                               panel_nodelist('SetSelectedPanel', panelName)

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
% Authors: Francois Tadel, 2010-2017; Martin Cousineau, 2017-2019

eval(macro_method);
end

%% ===== CREATE PANEL =====
function nodelist = CreatePanel(nodelistName, nodelistComment, listType) %#ok<DEFNU>
    import java.awt.BorderLayout;
    import javax.swing.BorderFactory;
    
    % CHECK NODELIST UNICITY
    nodeList = GetNodelist(nodelistName);
    if ~isempty(nodeList)
        error(['Nodelist "' nodelistName '" already exists.']);
    end
    % Get scaling factor
    InterfaceScaling = bst_get('InterfaceScaling');
    % Get standard font
    stdFont = bst_get('Font');
            
    % Create panel
    jPanel = gui_component('Panel');
    % Create list (tree or treetable)
    switch(listType)
        case 'tree'
            % Create border
            jBorder = java_scaled('titledborder', nodelistComment);
            jPanel.setBorder(jBorder);
            % Create tree
            jTree = java_create('org.brainstorm.tree.BstTree', 'F', InterfaceScaling / 100, stdFont.getSize(), stdFont.getFontName());
            jTree.setBorder(BorderFactory.createEmptyBorder(5,5,5,0));
            jTree.setEditable(0);
            jTree.setRowHeight(round(20 * InterfaceScaling / 100));
            % Configure selection model
            jTreeSelModel = jTree.getSelectionModel();
            jTreeSelModel.setSelectionMode(jTreeSelModel.DISCONTIGUOUS_TREE_SELECTION);
            % Enable drag'n'drop
            jTree.setDragEnabled(1);
            jTree.setTransferHandler(java_create('org.brainstorm.dnd.TreeDropTransferHandler'));
            % Scroll panel
            jScroll = java_create('javax.swing.JScrollPane', 'Ljava.awt.Component;', jTree);
            jPanel.add(jScroll, BorderLayout.CENTER);
            % Callbacks
            java_setcb(jTree, 'MouseClickedCallback', @TreeClicked_Callback, ...
                       'KeyPressedCallback',   @TreeKeyboard_Callback, ...
                       'FocusLostCallback',    @(h,ev)jTree.getSelectionModel().setSelectionPath([]));
            java_setcb(jTree.getModel(), 'TreeStructureChangedCallback', @(h,ev)TreeStructureChanged_Callback(nodelistName));
        case 'table'
            % Create table
            jTree = java_create('org.brainstorm.tree.BstTreeTable', stdFont.getSize(), stdFont.getFontName());
            jPanel.add(jTree.getContainer(), BorderLayout.CENTER);
            % Initialize other undefined variables
            jBorder = [];
            % Callbacks
            java_setcb(jTree, 'MouseClickedCallback', @TreeClicked_Callback, ...
                       'KeyPressedCallback',   @TreeKeyboard_Callback, ...
                       'FocusLostCallback',    @(h,ev)jTree.getSelectionModel().setSelectionInterval(-1,-1));
            java_setcb(jTree.getModel(), 'TableChangedCallback', @(h,ev)UpdatePanel(nodelistName));
    end
    
    % === TAG LIST ===
    jPanelTag = java_create('javax.swing.JPanel');
    jPanelTag.setLayout(javax.swing.BoxLayout(jPanelTag, javax.swing.BoxLayout.Y_AXIS));
    jPanelTag.add(javax.swing.JLabel(' Tags: '));
    jPanelTag.setVisible(0);
    jPanel.add(jPanelTag, BorderLayout.EAST);
    
    % === REGISTER NODE LIST ===
    % Create new nodelist
    nodelist = db_template('nodelist');
    nodelist.name      = nodelistName;
    nodelist.comment   = nodelistComment;
    nodelist.type      = listType;
    nodelist.jPanel    = jPanel;
    nodelist.jBorder   = jBorder;
    nodelist.jTree     = jTree;
    nodelist.jPanelTag = jPanelTag;
    % Add it to the existing list
    SetNodelist([], nodelist);

    
%% =========================================================================
%  ===== LOCAL CALLBACKS ===================================================
%  =========================================================================
    %% ===== TREE: CLICKED CALLBACK =====
    function TreeClicked_Callback(h,ev)
        import org.brainstorm.icon.*;
        % Process right click
        if (ev.getButton() == ev.BUTTON3) && ev.getSource().isEnabled()
            % Create popup menu
            jPopup = java_create('javax.swing.JPopupMenu');
            % Menu "Copy file list"
            gui_component('MenuItem', jPopup, [], 'Copy list to clipboard', IconLoader.ICON_COPY, [], @(h,ev)CopyPathList());
            % Menu "Paste file list"
            gui_component('MenuItem', jPopup, [], 'Paste list from clipboard', IconLoader.ICON_PASTE, [], @(h,ev)PastePathList());
            jPopup.addSeparator();
            % Menu "Remove from list"
            gui_component('MenuItem', jPopup, [], 'Clear list', IconLoader.ICON_DELETE, [], @(h,ev)ResetAllLists());
            % Show popup menu
            jPopup.pack();
            jPopup.show(jTree, ev.getPoint.getX(), ev.getPoint.getY());
        end
    end

    %% ===== TREE: KEYBOARD CALLBACK =====
    function TreeKeyboard_Callback(h, ev)
        % Switch between keys
        switch (ev.getKeyCode())
            % Delete selected nodes
            case {ev.VK_DELETE, ev.VK_BACK_SPACE}
                jTree.removeSelectedNodes();
        end
    end

    %% ===== TREE: STRUCTURE CHANGED =====
    function TreeStructureChanged_Callback(nodelistName)
        % Get nodelist
        [nodelist, iNodelist] = GetNodelist(nodelistName);
        if isempty(nodelist)
            return;
        end
        % Get nodes in target tree
        jTree = nodelist.jTree;
        bstNodes = jTree.getNodes();
        % If no nodes: just update the panel and return
        if isempty(bstNodes) 
            UpdatePanel(nodelistName);
            return;
        end
        % Get comment and type of the first node
        nodeType = char(bstNodes(1).getType());
        nodeComment = char(bstNodes(1).getComment());
        DataType = [];
        % Progress bar
        isProgress = ~bst_progress('isVisible');
        if isProgress
            bst_progress('start', 'File selection', 'Updating file count...');
        end
        % If first node is not counted yet, change file type to this node
        % DO NOT REMOVE THE TEST FOR ']' => It prevents from updating for the files already added in the list
        if (nodeComment(end) ~= ']')
            switch(nodeType)
                case {'data','datalist','rawdata','pdata'}
                    DataType = 'data';
                case {'results','link','presults'}
                    DataType = 'results';
                case {'timefreq','spectrum','ptimefreq','pspectrum'}
                    DataType = 'timefreq';
                case {'matrix', 'matrixlist', 'pmatrix'}
                    DataType = 'matrix';
            end
        end
        % Get current file type to process
        curDataType = gui_brainstorm('GetProcessFileType', nodelistName);
        % If we have to change the file type
        if ~isempty(DataType) && ~strcmpi(DataType, curDataType)
            gui_brainstorm('SetProcessFileType', DataType, nodelistName);
        else
            UpdatePanel(nodelistName);
        end
        % Close progress bar
        if isProgress
            bst_progress('stop');
        end
    end
end         


%% =========================================================================
%  ===== EXTERNAL FUNCTIONS ================================================
%  =========================================================================
%% ===== GET NODELIST =====
% USAGE:  [nodelist, iNodelist] = GetNodelist(nodelistName)  : Return specified nodelist
%         [nodelist, iNodelist] = GetNodelist()              : Return all nodelists
function [nodelist, iNodelist] = GetNodelist(nodelistName)
    global GlobalData;
    nodelist = [];
    iNodelist = [];
    % If no existing nodelists
    if isempty(GlobalData) || isempty(GlobalData.Program.GUI.nodelists)
        return
    end
    % Look for existing nodelist
    if (nargin < 1) || isempty(nodelistName)
        nodelist = GlobalData.Program.GUI.nodelists;
        iNodelist = 1:length(nodelist);
    else
        iNodelist = find(strcmpi({GlobalData.Program.GUI.nodelists.name}, nodelistName));
        if isempty(iNodelist)
            return
        end
        nodelist = GlobalData.Program.GUI.nodelists(iNodelist);
    end
end


%% ===== SET NODELIST =====
% USAGE:  SetNodelist(iNodelist, nodelist) : Update existing nodelist
%         SetNodelist([], nodelist)        : Add new nodelist
function SetNodelist(iNodelist, nodelist)
    global GlobalData;
    % Add node list
    if isempty(GlobalData.Program.GUI.nodelists)
        GlobalData.Program.GUI.nodelists = nodelist;
    else
        if isempty(iNodelist)
            iNodelist = length(GlobalData.Program.GUI.nodelists) + 1;
        end
        GlobalData.Program.GUI.nodelists(iNodelist) = nodelist;
    end
end


%% ===== RESET ALL LISTS =====
function ResetAllLists()
    global GlobalData;
    % Process all panel lists
    for i = 1:length(GlobalData.Program.GUI.nodelists)
        GlobalData.Program.GUI.nodelists(i).jTree.removeAllNodes();
    end
end


%% ===== COPY PATH LIST TO CLIPBOARD  =====
function CopyPathList()
     % Get selected process panel
    jTabProcess = bst_get('PanelContainer', 'process');
    selPanel = char(jTabProcess.getTitleAt(jTabProcess.getSelectedIndex()));
    if strcmpi(selPanel, 'Process1')
        % Get files
        sFiles = panel_nodelist('GetFiles', selPanel);
        % Concatenate file paths in one multiline string
        str = panel_process_select('WriteFileNames', sFiles, 'sFiles', 1);
    else
        % Get files
        sFilesA = panel_nodelist('GetFiles', [selPanel 'A']);
        sFilesB = panel_nodelist('GetFiles', [selPanel 'B']);
        strA = panel_process_select('WriteFileNames', sFilesA, 'sFiles', 1);
        strB = panel_process_select('WriteFileNames', sFilesB, 'sFiles2', 1);
        str = [strA 10 strB];
    end
    % Copy to clipboard
    clipboard('copy', str);
end

%% ===== PASTE PATH LIST FROM CLIPBOARD  =====
function PastePathList()
    % Get clipboard data
    str = strtrim(clipboard('paste'));
    if isempty(str)
        return;
    end
    
    % Get selected process panel
    jTabProcess = bst_get('PanelContainer', 'process');
    selPanel = char(jTabProcess.getTitleAt(jTabProcess.getSelectedIndex()));
    isProcess1 = strcmpi(selPanel, 'Process1');
    
    % Parse clipboard data
    try
        % If there is an equal sign, this is a Matlab-formatted list
        if length(strfind(str, '=')) >= 1
            eval(str);
            numEmptyVars = 0;
            if exist('sFiles', 'var') ~= 1
                if exist('sFiles1', 'var') ~= 1
                    if isProcess1
                        error('No files.');
                    end
                    sFiles = [];
                    numEmptyVars = numEmptyVars + 1;
                else
                    sFiles = sFiles1;
                end
            end
            if exist('sFiles2', 'var') ~= 1
                sFiles2 = [];
                numEmptyVars = numEmptyVars + 1;
            end
            assert(numEmptyVars < 2);
        
        % Otherwise, treat this as an unknown list with either commas (,;)
        % or white spaces/tabs/line breaks as delimiters
        else
            sFiles2 = []; % Only a single list is supported here
            
            nChars = length(str);
            sFiles = {};
            nFiles = 0;
            isReading = 0;
            foundDelimiter = 0;
            current = [];

            for iChar = 1:nChars
                c = str(iChar);
                saveCurrent = 0;

                % Quotes signal beginning or end of a single file path
                if ismember(c, {'''', '"'})
                    if isReading
                        saveCurrent = 1;
                        isReading = 0;
                    else
                        current = [];
                        isReading = 1;
                    end
                % Delimiter signal next file
                elseif ismember(c, {',', ';'}) && ~isReading
                    foundDelimiter = 1;
                    saveCurrent = 1;
                % White spaces are either skipped or delimiters
                elseif ismember(c, {' ', char(9), char(10)}) && ~isReading
                    if foundDelimiter
                        % skip
                    else
                        saveCurrent = 1;
                    end
                % Read character
                else
                    current = [current c];
                end

                if saveCurrent && ~isempty(current)
                    sFiles{end + 1} = current;
                    nFiles = nFiles + 1;
                    current = [];
                end
            end

            if ~isempty(current) && length(current) > 2
                sFiles{end + 1} = current;
            end
        end
    catch
        java_dialog('error', ['Could not properly parse your list of files.' 10 ...
            'Try to copy some files to see the proper format.']);
        return;
    end
    
    % Check whether we're overwriting files
    if isProcess1
        sPrevFiles = panel_nodelist('GetFiles', selPanel);
        overwrite = ~isempty(sPrevFiles);
    else
        sPrevFilesA = panel_nodelist('GetFiles', [selPanel 'A']);
        sPrevFilesB = panel_nodelist('GetFiles', [selPanel 'B']);
        overwrite = ~isempty(sPrevFilesA) || ~isempty(sPrevFilesB);
    end
    
    % Warn user if we're overwriting files
    if overwrite
        [res, isCancel] = java_dialog('question', ...
            ['This will overwrite the files you currently have' 10 ...
             'in the process box. Do you want to continue?']);
        if isCancel || ~strcmpi(res, 'Yes')
            return;
        end
    end
    
    % Clear process box
    ResetAllLists();
    
    % Add new files
    if isProcess1
        AddFiles('Process1', sFiles);
    else
        AddFiles('Process2A', sFiles);
        AddFiles('Process2B', sFiles2);
    end
end


%% ===== UPDATE PANEL =====
% USAGE:  UpdatePanel(nodelistNames, isReset=0)  : Update the specified nodelist
%         UpdatePanel()                          : Update all the nodelists
function UpdatePanel(nodelistNames, isReset)
    % Parse inputs
    if (nargin < 1) || isempty(nodelistNames)
        nodelists = GetNodelist();
        nodelistNames = {nodelists.name};
    elseif ischar(nodelistNames)
        nodelistNames = {nodelistNames};
    end
    if (nargin < 2) || isempty(isReset)
        isReset = 0;
    end
    % Update all nodelists
    for i = 1:length(nodelistNames)
        % Update file count
        UpdateFileCount(nodelistNames{i}, isReset);
    end
end


%% ===== UPDATE FILE COUNT =====
% USAGE:  UpdateFileCount(nodelistName, isReset)  : Count files for specified nodelist
%         UpdateFileCount(nodelistName)           : isReset = 1
% INPUTS:
%     - nodelistName : Name of the nodelist to update
%     - isReset      : If 0, do not update the nodes that are already counted (faster when adding new nodes)
%                      If 1, recount all the nodes (necessary when changing the type of processed files)
function UpdateFileCount(nodelistName, isReset)
    % Parse inputs
    if (nargin < 2) || isempty(isReset)
        isReset = 0;
    end
    % Get nodelist
    [nodelist, iNodelist] = GetNodelist(nodelistName);
    % Get file type to process
    DataType = gui_brainstorm('GetProcessFileType', nodelistName);
    % Get filter options
    NodelistOptions = bst_get('NodelistOptions');
    % Nodelist not using stat by default
    nodelist.isStat = 0;
    
    % Get nodes in target tree
    jTree = nodelist.jTree;
    bstNodes = jTree.getNodes();
    % Initialize lists of files
    iStudies = [];
    iItems   = [];

    % === GET DEPENDENT FILES ===
    % For each node: update item count in comment
    for iNode = 1:length(bstNodes)
        % Get number of dependent items
        [iDepStudies, iDepItems, DataType] = tree_dependencies(bstNodes(iNode), DataType, NodelistOptions, 0);
        % If an error occurred when looking for the for the files in the database: Empty all samples lists
        if isequal(iDepStudies, -10)
            ResetAllLists();
            return;
        end
        % If nothing found so far: try getting stat results
        if isempty(iStudies) && isempty(iDepStudies) && ismember(DataType, {'data','results','timefreq','matrix'})
            [iDepStudies, iDepItems, pDataType] = tree_dependencies(bstNodes(iNode), ['p' DataType], NodelistOptions, 0);
            % Tag the list to be using stat files
            if ~isempty(iDepStudies)
                nodelist.isStat = 1;
                DataType = pDataType;
            end
        end
        % Add found files to current list
        iStudies = [iStudies, iDepStudies];
        iItems   = [iItems,   iDepItems];
        % Ignore nodes that were already processed
        nodeComment = char(bstNodes(iNode).getComment());
        if (nodeComment(end) == ']') && ~isReset
            continue;
        end
        % Remove previous items count
        nodeComment = str_remove_parenth(nodeComment, '[');
        % Add items count
        nodeComment = sprintf('%s [%d]', nodeComment, length(iDepItems));
        % Update node comment
        bstNodes(iNode).setComment(nodeComment);
    end
    % Save the sample filenames (to be able to check for database modifications later)
    nodelist.contents = GetContents(iStudies, iItems, DataType);
    % Save modifications to nodelist
    SetNodelist(iNodelist, nodelist);
    
    % === UPDATE GUI ===
    % Update title comment
    if (DataType(1) == 'p')
        DataType = DataType(2:end);
        DataType(1) = upper(DataType(1));
        strTitle = sprintf('%s: Stat/%s [%d]', nodelist.comment, DataType, length(iItems));
    else
        DataType(1) = upper(DataType(1));
        strTitle = sprintf('%s: %s [%d]', nodelist.comment, DataType, length(iItems));
    end
    switch (nodelist.type)
        case 'tree'
            nodelist.jBorder.setTitle(strTitle);
            nodelist.jPanel.updateUI();
        case 'table'
            nodelist.jTree.getColumnModel().getColumn(0).setHeaderValue(strTitle);
            nodelist.jPanel.updateUI();
    end
    % Update tree
    jTree.updateUI();
end


%% ===== ADD FILES =====
% For scripting purpose only: add files in the processes/stat list using their filenames or comments
%
% USAGE:  nFiles = panel_nodelist('AddFiles', TreeName, Filenames, isTreeUpdate)
%         nFiles = panel_nodelist('AddFiles', TreeName, Filenames)     % isTreeUpdate = 1
% 
% INPUTS:
%    - nodelistName : {'Process1', 'Process2A', 'Process2B'}
%    - Filenames    : List of filenames or node names (strings without .mat will be considered as node names)
%    - isTreeUpdate : If set to 0, do not redraw the tree before processing
function AddFiles(nodelistName, Filenames, isTreeUpdate) %#ok<DEFNU>
    % Parse inputs
    if (nargin < 3) || isempty(isTreeUpdate)
        isTreeUpdate = 1;
    end
    if ischar(Filenames)
        Filenames = {Filenames};
    end
    nFiles = 0;
    
    % ===== GET EXPLORER TREE =====
    if isTreeUpdate
        % Select "Functional data (subject)" display mode for database
        panel_protocols('SetExplorationMode', 'StudiesSubj');
    end
    % Get explorer root node
    nodeRootExp = panel_protocols('GetRootNode');
    drawnow
    
    % ===== GET DESTINATION TREE =====
    % Find nodelist
    nodelist = GetNodelist(nodelistName);
    if isempty(nodelist)
        error(['Node list "' nodelistName '" does not exist.']);
    end
    % Get root node
    jTree = nodelist.jTree;
    nodeRootDest = jTree.getModel().getRoot();
    
    % ===== COPY NODES TO DESTINATION TREE =====
    % Loop on the files to add
    for i = 1:length(Filenames)
        % Add file by name
        if ~isempty(strfind(Filenames{i}, '.mat'))
            % Get file in database
            [sStudy, iStudy, iItem, fileType] = bst_get('AnyFile', Filenames{i});                     
            % If file was not found
            if isempty(iStudy)
                bst_error(['File not found in database: ' 10 Filenames{i}], 'Add files', 0);
                continue;
            end
            % Get study node
            nodeStudy = [nodeRootExp.findChild('condition', iStudy, -1, 1), ...
                         nodeRootExp.findChild('rawcondition', iStudy, -1, 1), ...
                         nodeRootExp.findChild('studysubject', iStudy, -1, 1), ...
                         nodeRootExp.findChild('study', iStudy, -1, 1), ...
                         nodeRootExp.findChild('defaultstudy', iStudy, -1, 1)];
            if isempty(nodeStudy)
                bst_error(['File is not displayed in database explorer: ' 10 Filenames{i}], 'Add files', 0);
                continue;
            else
                nodeStudy = nodeStudy(1);
            end
            % Create study node
            panel_protocols('CreateStudyNode', nodeStudy(1));
            % Convert file type to node type
            if strcmpi(fileType, 'data') && strcmpi(sStudy.Data(iItem).DataType, 'raw')
                nodeType = 'rawdata';
            elseif ismember(fileType, {'brainstormstudy', 'brainstormsubject'})
                error('Cannot add a subject/study file: add the name of the subject or the name of the condition instead.');
            elseif strcmpi(fileType, 'timefreq') && (~isempty(strfind(Filenames{i}, '_psd')) || ~isempty(strfind(Filenames{i}, '_fft')))
                nodeType = 'spectrum';
            else
                nodeType = lower(fileType);
            end
            % Get node in tree
            nodeFound = nodeStudy.findChild(nodeType, iStudy, iItem, 1);
        % Add file by comment
        else
            nodeFound = nodeRootExp.findChild(Filenames{i}, 1);
        end
        % If node was not found
        if isempty(nodeFound)
            bst_error(['File was not found in this protocol: ' 10 Filenames{i}], 'Add files', 0);
            continue;
        end
        % Copy node in the protocols list
        nodeRootDest.add(nodeFound.clone());
        nFiles = nFiles + 1;
    end
    % Update destination tree
    jTree.refresh();
end


%% ===== ADD NODES =====
% USAGE:  AddNodes(nodelistName, bstNodes)
function AddNodes(nodelistName, bstNodes) %#ok<DEFNU>
    % Find nodelist
    nodelist = GetNodelist(nodelistName);
    if isempty(nodelist)
        error(['Node list "' nodelistName '" does not exist.']);
    end
    % Get root node
    jTree = nodelist.jTree;
    nodeRootDest = jTree.getModel().getRoot();
    
    % Copy all nodes from the protocols list
    for i = 1:length(bstNodes)
        nodeRootDest.add(bstNodes(i).clone());
    end
    % Update destination tree
    jTree.refresh();
end


%% ===== GET FILES =====
function sFiles = GetFiles(nodelistName)      %#ok<DEFNU>
    % Progressbar
    isProgress = ~bst_progress('isVisible');
    if isProgress
        bst_progress('start', 'Process', 'Reading list of input files...');
    end
    % === GET FILES ===
    % Check contents of the panel
    [ProcessType, iStudies, iItems] = CheckContents(nodelistName);
    % Display error message
    if isempty(ProcessType)
        bst_progress('stop');
        bst_error(['Database contents changed.' 10 ...
                   'Please select again the files you want to process.'], 'Processes', 0);
        sFiles = -1;
        return
    end
    % Empty list
    if isempty(iStudies)
        if isProgress
            bst_progress('stop');
        end
        sFiles = [];
        return
    end
    isFirstWarning = 1;

    % === GET DESCRIPTION ===
    % Prepare Samples structure
    sFiles = repmat(db_template('processfile'), [1, length(iStudies)]);
    % Get unique list of studies
    iUniqueStudies = unique(iStudies);
    for is = 1:length(iUniqueStudies)
        iStudy = iUniqueStudies(is);
        % Get study/subject
        sStudy = bst_get('Study', iStudy);
        sSubject = bst_get('Subject', sStudy.BrainStormSubject);
        % Get channel file
        sChannel = bst_get('ChannelForStudy', iStudy);
        % Get list of samples in this study
        iFiles = find(iStudies == iStudy);
        % Loop on samples
        for ind = 1:length(iFiles)
            i = iFiles(ind);
            sFiles(i).iStudy      = iStudy;
            sFiles(i).iItem       = iItems(i);
            sFiles(i).SubjectFile = file_win2unix(sStudy.BrainStormSubject);
            sFiles(i).SubjectName = sSubject.Name;
            sFiles(i).FileType    = ProcessType;
            % Channel file
            if ~isempty(sChannel)
                sFiles(i).ChannelFile  = file_win2unix(sChannel.FileName);
                sFiles(i).ChannelTypes = sChannel.Modalities;
            else
                sFiles(i).ChannelFile  = [];
                sFiles(i).ChannelTypes = [];
            end
            % Data or results
            switch (ProcessType)
                case 'data'
                    sFiles(i).FileName = file_win2unix(sStudy.Data(iItems(i)).FileName);
                    sFiles(i).Comment  = sStudy.Data(iItems(i)).Comment;
                    if strcmpi(sStudy.Data(iItems(i)).DataType, 'raw')
                        sFiles(i).FileType = 'raw';
                    end
                case 'results'
                    sFiles(i).FileName = file_win2unix(sStudy.Result(iItems(i)).FileName);
                    sFiles(i).Comment  = sStudy.Result(iItems(i)).Comment;
                    sFiles(i).DataFile = file_win2unix(sStudy.Result(iItems(i)).DataFile);
                case 'timefreq'
                    % Do not accept TF/sources, because it's impossible to get the full matrix [nSources x nTime x nFrequencies]
                    if isFirstWarning && strcmpi(sStudy.Timefreq(iItems(i)).DataType, 'results') && ~isempty(strfind(sStudy.Timefreq(iItems(i)).FileName, '_KERNEL_'))
                        isFirstWarning = 0;
                        java_dialog('warning', ...
                            ['You are about to process a source file saved in an optimized way.' 10 ...
                             'For now, the decomposition was performed only at the sensor level, and' 10 ...
                             'then projected in source space when needed using the inverse operator.' 10 ...
                             'The current file size is [Nsensors x Ntime x Nfrequencies].' 10 10 ...
                             'Processing this file will project the entire file to the source domain, ' 10 ...
                             'generating a much bigger file [Nsources x Ntime x Nfrequencies].' 10 10 ...
                             'If you are experimenting "Out of memory" errors, try to find another' 10 ...
                             'way to process your data, using scouts instead of the full brain.'], ...
                             'Processing time-frequency files');
                    end
                    sFiles(i).FileName = file_win2unix(sStudy.Timefreq(iItems(i)).FileName);
                    sFiles(i).Comment  = sStudy.Timefreq(iItems(i)).Comment;
                    sFiles(i).DataFile = file_win2unix(sStudy.Timefreq(iItems(i)).DataFile);
                case 'matrix'
                    sFiles(i).FileName = file_win2unix(sStudy.Matrix(iItems(i)).FileName);
                    sFiles(i).Comment  = sStudy.Matrix(iItems(i)).Comment;
                case {'pdata','presults','ptimefreq','pmatrix'}
                    sFiles(i).FileName = file_win2unix(sStudy.Stat(iItems(i)).FileName);
                    sFiles(i).Comment  = sStudy.Stat(iItems(i)).Comment;
                otherwise
                    error('???');
            end
            % Condition
            if ~isempty(sStudy.Condition)
                sFiles(i).Condition = sStudy.Condition{1};
            else
                sFiles(i).Condition = sStudy.Name;
            end
        end
    end
    % Close progressbar
    if isProgress
        bst_progress('stop');
    end
end


%% ===== CHECK FILES =====
function [ProcessType, iStudies, iItems] = CheckContents(nodelistName)
    % Get data type
    ProcessType = gui_brainstorm('GetProcessFileType', nodelistName);
    % Initialized other values returned
    iStudies = [];
    iItems   = [];
    % Find nodelist
    nodelist = GetNodelist(nodelistName);
    % Get tree nodes
    bstNodes = nodelist.jTree.getNodes();
    if isempty(bstNodes)
        return
    end
    % Get filter options
    NodelistOptions = bst_get('NodelistOptions');
    % For each node: get dependencies
    if nodelist.isStat
         ProcessType = ['p' ProcessType];
    end
    [iStudies, iItems, ProcessType] = tree_dependencies(bstNodes, ProcessType, NodelistOptions, 0);
    % If an error occurred when looking for the for the files in the database
    if isequal(iStudies, -10)
        % Empty all samples lists
        ResetAllLists();
        % Return an error
        ProcessType = [];
        return;
    end
    % Check for changes: Get the list of filenames
    curContents = GetContents(iStudies, iItems, ProcessType);
    % Compare with the filenames saved in the nodelist
    if ~isequal(curContents, nodelist.contents)
        % Empty all samples lists
        ResetAllLists();
        % Return an error
        ProcessType = [];
        return;
    end
end

%% ===== GET CONTENTS =====
function curContents = GetContents(iStudies, iItems, ProcessType)
    % Get all filenames
    curFilenames = bst_get('GetFilenames', iStudies, iItems, ProcessType);
    % Create lists
    curContents = [curFilenames{:}, num2str(iStudies), num2str(iItems)];
end

%% ===== SET ENABLED =====
function SetListEnabled(isEnabled) %#ok<DEFNU>
    % Get the lists
    nodelist = GetNodelist();
    % Process each list
    for iList = 1:length(nodelist)
        gui_enable(nodelist(iList).jPanel, isEnabled, 1);
        nodelist(iList).jTree.setDragEnabled(isEnabled);
        if ~isEnabled
            nodelist(iList).jTree.setTransferHandler([]);
        else
            nodelist(iList).jTree.setTransferHandler(java_create('org.brainstorm.dnd.TreeDropTransferHandler'));
        end
    end
    % Get selection buttons
    sControls = bst_get('BstControls');
    sControls.jButtonRecordingsA.setEnabled(isEnabled);
    sControls.jButtonSourcesA.setEnabled(isEnabled);
    sControls.jButtonTimefreqA.setEnabled(isEnabled);
    sControls.jButtonMatrixA.setEnabled(isEnabled);
    sControls.jButtonRecordingsB.setEnabled(isEnabled);
    sControls.jButtonSourcesB.setEnabled(isEnabled);
    sControls.jButtonTimefreqB.setEnabled(isEnabled);
    sControls.jButtonMatrixB.setEnabled(isEnabled);
    sControls.jButtonReload.setEnabled(isEnabled);
end


%% ===== SELECT PANEL =====
function SetSelectedPanel(tabTitle)
    % Get the 'process' tabbed panel 
    jTabContainer = bst_get('PanelContainer', 'process');
    if isempty(jTabContainer)
        return;
    end
    % Select the desired panel
    for i = 0:jTabContainer.getTabCount()-1
        if strcmpi(char(jTabContainer.getTitleAt(i)), tabTitle)
            jTabContainer.setSelectedIndex(i);
        end
    end
end


