function varargout = panel_process_select(varargin)
% PANEL_PROCESS_SELECT: Creation and management of list of files to apply some batch proccess.
%
% USAGE:             bstPanelNew = panel_process_select('CreatePanel')
%         [sOutputs, sProcesses] = panel_process_select('ShowPanel', FileNames, ProcessNames, FileTimeVector)
%         [sOutputs, sProcesses] = panel_process_select('ShowPanel', FileNames, ProcessNames)
%                                  panel_process_select('ParseProcessFolder')
%                       sProcess = panel_process_select('LoadExternalProcess', FunctionName)
%                       sProcess = panel_process_select('GetCurrentProcess')       : Return the process currently being edited in the Pipeline Editor


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
% Authors: Francois Tadel, 2010-2023

eval(macro_method);
end

%% ===== CREATE PANEL ===== 
function [bstPanel, panelName] = CreatePanel(sFiles, sFiles2, FileTimeVector)
    panelName = 'ProcessOne';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.list.*;
    import org.brainstorm.icon.*;
    % Global variable used by this panel
    global GlobalData;
    GlobalData.Processes.Current = [];

    % Parse inputs
    if (nargin < 3) || isempty(FileTimeVector)
        FileTimeVector = [];
    end
    if (nargin < 2) || isempty(sFiles2)
        nInputsInit = 1;
        nFiles = length(sFiles);
        sFiles2 = [];
    else
        nInputsInit = 2;
        nFiles = [length(sFiles), length(sFiles2)];
    end
    % No inputs: skip
    if isempty(sFiles)
        return;
    end
    % Get initial type and subject
    InitialDataType = sFiles(1).FileType;
    InitialSubjectName = sFiles(1).SubjectName;
    if ~isempty(sFiles2) && isstruct(sFiles2)
        InitialDataType2 = sFiles2(1).FileType;
    else
        InitialDataType2 = [];
    end
    
    % Progress bar
    bst_progress('start', 'Process', 'Initialization...');
    % Get time vector for the first file of the list
    if (sFiles(1).FileName)
        FileTimeVector = in_bst(sFiles(1).FileName, 'Time');
    elseif isempty(FileTimeVector)
        FileTimeVector = -500:0.001:500;
    end
    % Get channel names and types
    if ~isempty(sFiles(1).ChannelFile)
        ChannelMat = load(file_fullpath(sFiles(1).ChannelFile), 'Channel');
        ChannelNames = {ChannelMat.Channel.Name};
        ChannelNames(cellfun(@isempty, ChannelNames)) = [];
    else
        ChannelNames = {'No channel info'};
    end
    % Get all the subjects names
    ProtocolSubjects = bst_get('ProtocolSubjects');
    ProtocolInfo     = bst_get('ProtocolInfo');
    SubjectNames = {};
    iSelSubject = [];
    if ~isempty(ProtocolSubjects)
        SubjectNames = {ProtocolSubjects.Subject.Name};
        if ~isempty(ProtocolInfo.iStudy)
            sSelStudy = bst_get('Study', ProtocolInfo.iStudy);
            [sSelSubject, iSelSubject] = bst_get('Subject', sSelStudy.BrainStormSubject);
        end
    end
    
    % Reload processes
    panel_process_select('ParseProcessFolder');
    % Initialize list of current processes
    sProcesses = repmat(GlobalData.Processes.All, 0);
    % Progress bar
    bst_progress('stop');
    
    % Other initializations
    WarningMsg = '';
    isUpdatingPipeline = 0;
    % Font size for the lists
    InterfaceScaling = bst_get('InterfaceScaling') / 100;
    fontSize = round(11 * InterfaceScaling);
    
    % Create main panel
    jPanelMain = java_create('javax.swing.JPanel');
    jPanelMain.setLayout(java_create('java.awt.GridBagLayout'));
    c = GridBagConstraints();
    c.fill = GridBagConstraints.BOTH;
    c.gridx = 1;
    c.weightx = 1;
    c.insets = Insets(3,5,3,5);
    
    % ===== PROCESS SELECTION =====
    jPanelProcess = gui_component('Panel');
    jPanelProcess.setBorder(java_scaled('titledborder', 'Process selection'));
    % Toolbar
    jToolbar = gui_component('Toolbar', jPanelProcess, BorderLayout.NORTH);
    jToolbar.setPreferredSize(java_scaled('dimension', 10, 25));
    jButtonAdd = gui_component('ToolbarButton', jToolbar, [], '', IconLoader.ICON_PROCESS_SELECT,    'Add process', @(h,ev)ShowProcessMenu('insert'));
    jToolbar.addSeparator();
    jButtonUp     = gui_component('ToolbarButton', jToolbar, [], '', IconLoader.ICON_ARROW_UP,       'Move process up', @(h,ev)MoveSelectedProcess('up'));
    jButtonDown   = gui_component('ToolbarButton', jToolbar, [], '', IconLoader.ICON_ARROW_DOWN,     'Move process down', @(h,ev)MoveSelectedProcess('down'));
    jButtonRemove = gui_component('ToolbarButton', jToolbar, [], '', IconLoader.ICON_DELETE,         'Delete process', @(h,ev)RemoveSelectedProcess());
    jToolbar.addSeparator();
    jButtonPipeline = gui_component('ToolbarButton', jToolbar, [], '', IconLoader.ICON_PIPELINE_LIST, 'Load/save processing pipeline', @(h,ev)ShowPipelineMenu(ev.getSource()));
    jButtonWarning  = gui_component('ToolbarButton', jToolbar, [], 'Error', [], 'There are errors in the process pipeline.', @(h,ev)ShowWarningMsg());
    % Set sizes
    dimLarge = java_scaled('dimension', 36,25);
    dimSmall = java_scaled('dimension', 25,25);
    %jButtonSelect.setMaximumSize(dimLarge);
    jButtonAdd.setMaximumSize(dimLarge);
    jButtonUp.setMaximumSize(dimSmall);
    jButtonDown.setMaximumSize(dimSmall);
    jButtonRemove.setMaximumSize(dimSmall);
    jButtonPipeline.setMaximumSize(dimLarge);
    jButtonWarning.setForeground(Color(.7, 0, 0));
    jButtonWarning.setVisible(0);
    % Process list
    jListProcess = java_create('javax.swing.JList');
    jListProcess.setSelectionMode(jListProcess.getSelectionModel().SINGLE_SELECTION);
    jListProcess.setCellRenderer(BstProcessListRenderer(fontSize, 28 * InterfaceScaling));
    java_setcb(jListProcess, 'ValueChangedCallback', @ListProcess_ValueChangedCallback, ...
                             'KeyTypedCallback',     @ListProcess_KeyTypedCallback);
    % Scroll panel
    jScrollProcess = JScrollPane(jListProcess);
    jScrollProcess.setBorder([]);
    jScrollProcess.setVisible(0);
    jPanelProcess.add(jScrollProcess);
    % Empty message
    jLabelEmpty = gui_component('label', [], '', '      [Please select a process]');
    jLabelEmpty.setOpaque(1);
    jLabelEmpty.setBackground(Color(1,1,1));
    jLabelEmpty.setForeground(Color(.7,.7,.7));
    jPanelProcess.add(jLabelEmpty, BorderLayout.WEST);
    
    % Set list size
    UpdateListSize();
    % Add panel
    c.gridy = 0;
    c.weighty = 1;
    jPanelMain.add(jPanelProcess, c);

    % ===== OPTIONS: INPUT =====
    jPanelInput = gui_component('Panel');
    jPanelInput.setLayout(BoxLayout(jPanelInput, BoxLayout.Y_AXIS));
    jPanelInput.setBorder(BorderFactory.createCompoundBorder(java_scaled('titledborder', 'Input options'), BorderFactory.createEmptyBorder(0,5,0,0)));
    jPanelInput.setVisible(0);
    % Add panel
    c.gridy = 2;
    c.weighty = 0;
    jPanelMain.add(jPanelInput, c);
    
    % ===== OPTIONS: PROCESS =====
    jPanelOptions = gui_component('Panel');
    jPanelOptions.setLayout(BoxLayout(jPanelOptions, BoxLayout.Y_AXIS));
    jPanelOptions.setBorder(BorderFactory.createCompoundBorder(java_scaled('titledborder', 'Process options'), BorderFactory.createEmptyBorder(0,5,0,0)));
    jPanelOptions.setVisible(0);
    % Add panel
    c.gridy = 3;
    c.weighty = 0;
    jPanelMain.add(jPanelOptions, c);
    
    % ===== OPTIONS: OUTPUT =====
    jPanelOutput = gui_component('Panel');
    jPanelOutput.setLayout(BoxLayout(jPanelOutput, BoxLayout.Y_AXIS));
    jPanelOutput.setBorder(BorderFactory.createCompoundBorder(java_scaled('titledborder', 'Output options'), BorderFactory.createEmptyBorder(0,5,0,0)));
    jPanelOutput.setVisible(0);
    % Add panel
    c.gridy = 4;
    c.weighty = 0;
    jPanelMain.add(jPanelOutput, c);
    
    % ===== VALIDATION BUTTONS =====
    jPanelOk = gui_river([6,0], [3,3,3,12]);
    jButtonHelp = gui_component('button', jPanelOk, 'left',  'Online tutorial', [], [], @ButtonHelp_Callback);
    jButtonHelp.setVisible(0);
    gui_component('label',  jPanelOk, 'hfill', '  ');
    gui_component('button', jPanelOk, 'right', 'Cancel', [], [], @ButtonCancel_Callback);
    gui_component('button', jPanelOk, [],      'Run',    [], [], @ButtonOk_Callback);
    % Add panel
    c.gridy = 5;
    c.weighty = 0;
    jPanelMain.add(jPanelOk, c);
    
    % Return a mutex to wait for panel close
    bst_mutex('release', panelName);
    bst_mutex('create', panelName);
    % GUI elements
    ctrl = struct(...
        'UpdatePipeline', @UpdatePipeline, ...
        'jListProcess',   jListProcess);
    % Make all the panel scrollable (otherwise, it can't be validated if it is taller than the screen
    jPanelScroll = java_create('javax.swing.JScrollPane');
    jPanelScroll.getLayout.getViewport.setView(jPanelMain);
    jPanelScroll.setBorder([]);
    jPanelScroll.setHorizontalScrollBarPolicy(jPanelScroll.HORIZONTAL_SCROLLBAR_NEVER);
    % Create the BstPanel object that is returned by the function
    bstPanel = BstPanel(panelName, jPanelScroll, ctrl);

                              
%% =========================================================================
%  ===== LOCAL CALLBACKS ===================================================
%  =========================================================================
    %% ===== BUTTON: CANCEL =====
    function ButtonCancel_Callback(hObject, event) %#ok<*INUSD>
        % Close panel without saving (release mutex automatically)
        gui_hide(panelName);
        % Empty global variable
        GlobalData.Processes.Current = [];
    end

    %% ===== BUTTON: OK =====
    function ButtonOk_Callback(varargin)
        % Check validity of pipeline
        if ~isempty(WarningMsg)
            ShowWarningMsg();
            return;
        end
        % Release mutex and keep the panel opened
        bst_mutex('release', panelName);
    end

    %% ===== BUTTON: HELP =====
    function ButtonHelp_Callback(varargin)
        % Get selected process
        iProcess = GetSelectedProcess();
        % No selected process or no help: return
        if isempty(iProcess) || isempty(GlobalData.Processes.Current(iProcess).Description)
            return;
        end
        % Display web page
        status = web(GlobalData.Processes.Current(iProcess).Description, '-browser');
        if (status ~= 0)
            web(GlobalData.Processes.Current(iProcess).Description);
        end
    end

    %% ===== LIST: VALUE CHANGED =====
    function ListProcess_ValueChangedCallback(h, ev)
        if ~ev.getValueIsAdjusting() && ~isUpdatingPipeline
            UpdateProcessOptions();
        end
    end

    %% ===== LIST: KEY TYPED =====
    function ListProcess_KeyTypedCallback(h, ev)
        switch(uint8(ev.getKeyChar()))
            case {ev.VK_DELETE, ev.VK_BACK_SPACE}
                RemoveSelectedProcess();
        end
    end

    
%% =========================================================================
%  ===== PROCESS LIST FUNCTIONS ============================================
%  =========================================================================
    %% ===== GET CURRENT DATA TYPE =====
    function [DataType, nInputs, SubjectName] = GetProcessDataType(iLastProc)
        if (nargin < 1) || isempty(iLastProc) || (iLastProc > length(GlobalData.Processes.Current))
            iLastProc = length(GlobalData.Processes.Current);
        end
        % Initial data type
        DataType = InitialDataType;
        SubjectName = InitialSubjectName;
        nInputs = nInputsInit;
        % Loop through all the processes to see what is the current data type at the end
        for iProc = 1:iLastProc
            sCurProcess = GlobalData.Processes.Current(iProc);
            % Get the correct input type for the process
            iType = find(strcmpi(sCurProcess.InputTypes, DataType));
            % If the input type of the process do not match the current data type: error
            if isempty(iType) || (iType > length(sCurProcess.OutputTypes))
                DataType = [];
                % Show warning button
                jButtonWarning.setVisible(1);
                % Define warning message
                WarningMsg = ['Error: Data type mismatch.' 10 10 ...
                              'Invalid inputs for process:' 10 '"' sCurProcess.Comment '"' 10];
                return
            end
            % Get the corresponding output type
            DataType = sCurProcess.OutputTypes{iType};
            % Get the number of output groups
            if isfield(sCurProcess, 'nOutputs') && ~isempty(sCurProcess.nOutputs)
                nInputs = sCurProcess.nOutputs;
            else
                nInputs = 1;
            end
            % Find an option with the type "subjectname"
            if (nargout >= 2) && ~isempty(sCurProcess.options) && isstruct(sCurProcess.options)
                optNames = fieldnames(sCurProcess.options);
                for iOpt = 1:length(optNames)
                    opt = sCurProcess.options.(optNames{iOpt});
                    if isfield(opt, 'Type') && ~isempty(opt.Type) && strcmpi(opt.Type, 'subjectname') && isfield(opt, 'Value') && ~isempty(opt.Value)
                        SubjectName = opt.Value;
                    end
                end
            end
        end
        % No error: hide warning button
        jButtonWarning.setVisible(0);
        WarningMsg = [];
    end


    %% ===== SHOW ERROR MESSAGE =====
    function ShowWarningMsg()
        bst_error(WarningMsg, 'Data type mismatch', 0);
    end

        
    %% ===== PROCESS: GET AVAILABLE =====
    function [sProcesses, iSelProc] = GetAvailableProcesses(DataType, procFiles, isFirstProc, nInputsCur)
        % Get all the processes
        iSelProc = [];
        sProcessesAll = GlobalData.Processes.All;
        sProcesses = repmat(sProcessesAll, 0);
        % Loop through the processes and look for the valid ones
        for iProc = 1:length(sProcessesAll)
            % === ADAPT PROCESS TO CURRENT INPUT ===
            % Absolute values of sources before process
            % ONLY FOR FILTER AND FILTER2 (not used in other categories)
            if isempty(DataType) || (strcmpi(DataType, 'results') && any(strcmpi(sProcessesAll(iProc).Category, {'Filter', 'Filter2'})) && ...
                                     ismember(sProcessesAll(iProc).isSourceAbsolute, [0,1]) && ~isfield(sProcessesAll(iProc).options, 'source_abs'))
                sProcessesAll(iProc).options.source_abs.Comment = ['<B>Use absolute values of source activations</B><BR>' ...
                                                                   'or the norm of the three orientations for unconstrained maps.'];
                sProcessesAll(iProc).options.source_abs.Type    = 'checkbox';
                sProcessesAll(iProc).options.source_abs.Value   = sProcessesAll(iProc).isSourceAbsolute;
                sProcessesAll(iProc).options.source_abs.Group   = 'input';
%                 % Unconstrained sources warning
%                 sProcessesAll(iProc).options.source_warning.Comment = ['<FONT color="#777777"><I>&nbsp;&nbsp;&nbsp;&nbsp;For unconstrained sources, this option takes the absolute<BR>' ...
%                                                                        '&nbsp;&nbsp;&nbsp;&nbsp;value of each orientation separately. You may need to run <BR>' ...
%                                                                        '&nbsp;&nbsp;&nbsp;&nbsp;first the process "Sources > Unconstrained to flat maps".</I></FONT><BR>'];
%                 sProcessesAll(iProc).options.source_warning.Type    = 'label';
%                 sProcessesAll(iProc).options.source_warning.Group   = 'input';
            end
            % Filter raw files: More options
            if strcmpi(DataType, 'raw') && any(strcmpi(sProcessesAll(iProc).Category, {'Filter', 'Filter2'})) && ismember(1, sProcessesAll(iProc).processDim)
                % Allow processing the entire file at once
                sProcessesAll(iProc).options.read_all.Comment = 'Process the entire file at once<BR><I>(select to process files with SSP, may require a lot of memory)</I>';
                sProcessesAll(iProc).options.read_all.Type    = 'checkbox';
                sProcessesAll(iProc).options.read_all.Value   = 0;
                sProcessesAll(iProc).options.read_all.Group   = 'input';
            end
            
            % === IS PROCESS CURRENTLY AVAILABLE ? ===
            % Check number of input sets
            if (sProcessesAll(iProc).nInputs ~= nInputsCur)
                continue;
            end
            % Process is "listed"
            sProcesses(end+1) = sProcessesAll(iProc);
            % Test data type and number of inputs
            if isempty(DataType) || ~ismember(DataType, sProcessesAll(iProc).InputTypes)
                continue;
            end
            % Test the number of input files (allow nMinFiles > 2 when there are already other selected processes)
            if (procFiles(1) < sProcessesAll(iProc).nMinFiles) && ~((sProcessesAll(iProc).nMinFiles == 2) && ~isFirstProc)
                continue;
            end
            % Two input variables: check if the number of inputs in each list must be the same
            if (nInputsCur == 2) && sProcessesAll(iProc).isPaired && (nFiles(1) ~= nFiles(2))
                continue;
            end           
            % Keep process
            iSelProc(end+1) = length(sProcesses);
        end
    end


    %% ===== PROCESS: SHOW POPUP MENU =====
    % AddMode: {'select', 'add', 'insert'}
    function ShowProcessMenu(AddMode)
        import java.awt.Insets;
        import java.awt.Color;
        % Set mouse cursor to WAIT
        jPanelMain.setCursor(java_create('java.awt.Cursor', 'I', java.awt.Cursor.WAIT_CURSOR));
        % Get the current data type and time vector (after the process pipeline)
        procTimeVector = FileTimeVector;
        procFiles = nFiles;
        switch (AddMode)
            case 'select'
                procDataType = InitialDataType;
                nInputsProc = nInputsInit;
            case 'add'
                [procDataType, nInputsProc] = GetProcessDataType();
                if ~isempty(GlobalData.Processes.Current)
                    [procTimeVector, procFiles] = GetProcessFileVector(GlobalData.Processes.Current, FileTimeVector, procFiles);
                end
            case 'insert'
                iSelProc = GetSelectedProcess();
                if ~isempty(iSelProc)
                    [procDataType, nInputsProc] = GetProcessDataType(iSelProc);
                    [procTimeVector, procFiles] = GetProcessFileVector(GlobalData.Processes.Current(1:iSelProc), FileTimeVector, procFiles);
                else
                    [procDataType, nInputsProc] = GetProcessDataType();
                    if ~isempty(GlobalData.Processes.Current)
                        [procTimeVector, procFiles] = GetProcessFileVector(GlobalData.Processes.Current, FileTimeVector, procFiles);
                    end
                end
        end
        % Number of currently selected processes
        isFirstProc = isempty(GlobalData.Processes.Current);
        % We don't care about more than two files in input
        if (procFiles(1) > 2)
            procFiles(1) = 2;
        end
        % Get processes for this specific case
        [sProcesses, iSelProc] = GetAvailableProcesses(procDataType, procFiles, isFirstProc, nInputsProc);
        % Set default values for the file-dependent options
        sProcesses = SetDefaultOptions(sProcesses, procTimeVector);
        
        % Create cache hash: list of selected processes
        strCache = sprintf('pro_%s_%d_%d_%d_%d', procDataType, length(iSelProc), procFiles(1), isFirstProc, nInputsProc);
        % If the enry is already cached, use it
        if isfield(GlobalData.Program.ProcessMenuCache, strCache)
            % Get the cached items
            jPopup    = GlobalData.Program.ProcessMenuCache.(strCache).jPopup;
            jMenusAll = GlobalData.Program.ProcessMenuCache.(strCache).jMenusAll;
            % Update the callbacks
            for iProc = 1:length(jMenusAll)
                if ~isempty(jMenusAll(iProc))
                    java_setcb(jMenusAll(iProc), 'ActionPerformedCallback',  @(h,ev)AddProcess(iProc, AddMode));
                end
            end
        % Else: Create full process menu
        else
            % Create popup menu
            jPopup = java_create('javax.swing.JPopupMenu');
            hashGroups = struct();
            % List of menus (for later update of the callbacks)
            jMenusAll = javaArray('javax.swing.JMenuItem', length(sProcesses));
            % Fill the combo box
            for iProc = 1:length(sProcesses)
                % Ignore if Index is set to 0
                if (sProcesses(iProc).Index == 0)
                    continue;
                end
                % If "Select", ignore non-available menus
                isSelected = ismember(iProc, iSelProc);
                if strcmpi(AddMode, 'select') && ~isSelected
                    continue;
                end
                % Get parent menu
                % If no sub group: parent menu is the popup menu
                if isempty(sProcesses(iProc).SubGroup)
                    jParent = jPopup;
                % Else: create a sub-menu for the sub-group
                else
                    % Create hash key
                    if iscell(sProcesses(iProc).SubGroup)
                        if (length(sProcesses(iProc).SubGroup) ~= 2)
                            error('When SubGroup is a cell array, it must have two entries (menu and submenu).');
                        end
                        hashKey = sprintf('%s_%s', sProcesses(iProc).SubGroup{1}, sProcesses(iProc).SubGroup{2});
                    else
                        hashKey = sProcesses(iProc).SubGroup;
                    end
                    hashKey = strrep(file_standardize(hashKey), '-', '_');
                    % Get existing menu
                    if isfield(hashGroups, hashKey)
                        jParent = hashGroups.(hashKey);
                        jParentTop = [];
                    % Menu not created yet: create it
                    else
                        % Menu+submenu
                        if iscell(sProcesses(iProc).SubGroup)
                            hashParent = strrep(file_standardize(sProcesses(iProc).SubGroup{1}), '-', '_');
                            if isfield(hashGroups, hashParent)
                                jParentTop = hashGroups.(hashParent);
                            else
                                jParentTop = gui_component('Menu', jPopup, [], sProcesses(iProc).SubGroup{1}, [], []);
                                jParentTop.setMargin(Insets(5,0,4,0));
%                                 jParentTop.setForeground(Color(.6,.6,.6));
                                jParentTop.setForeground(Color(0,0,0));
                                hashGroups.(hashParent) = jParentTop;
                            end
                            menuName = sProcesses(iProc).SubGroup{2};
                        % Simple menu
                        else
                            jParentTop = jPopup;
                            menuName = sProcesses(iProc).SubGroup;
                        end
                        % Create subgroup menu
                        jParent = gui_component('Menu', jParentTop, [], menuName, [], []);
                        jParent.setMargin(Insets(5,0,4,0));
                        jParent.setForeground(Color(.6,.6,.6));
                        hashGroups.(hashKey) = jParent;
                    end
                end
                % Create process menu
                jItem = gui_component('MenuItem', jParent, [], sProcesses(iProc).Comment, [], [], @(h,ev)AddProcess(iProc, AddMode));
                jItem.setMargin(Insets(5,0,4,0));
                % Change menu color for unavailable menus
                if ~isSelected
                    jItem.setForeground(Color(.6,.6,.6));
                else
                    jParent.setForeground(Color(0,0,0));
%                     % And two levels up if process with subcategories
%                     if iscell(sProcesses(iProc).SubGroup) && (length(sProcesses(iProc).SubGroup) >= 2) && ~isempty(jParentTop)
%                         jParentTop.setForeground(Color(0,0,0));
%                     end
                end
                % Add separator?
                if sProcesses(iProc).isSeparator
                    jParent.addSeparator();
                end
                % Add to the menu list
                jMenusAll(iProc) = jItem;
            end
            % Add to cache
            GlobalData.Program.ProcessMenuCache.(strCache).jPopup    = jPopup;
            GlobalData.Program.ProcessMenuCache.(strCache).jMenusAll = jMenusAll;
        end
        
        % Show popup menu
        try
            jPopup.show(jButtonAdd, 0, jButtonAdd.getHeight());
        catch
            % Clear menu cache
            GlobalData.Program.ProcessMenuCache = struct();
            % Try again to call the same function
            pause(0.1);
            disp('Call failed: calling again...');
            ShowProcessMenu(AddMode);
        end
        % Restore default mouse cursor
        jPanelMain.setCursor([]);
    end


    %% ===== PROCESS: ADD =====
    function AddProcess(iProcess, AddMode)
        % Get process data type for this process
        iSelProc = GetSelectedProcess();
        sCurProcesses = GlobalData.Processes.Current;
        % Select unique process
        if strcmpi(AddMode, 'select') || isempty(sCurProcesses)
            sCurProcesses = sProcesses(iProcess);
            % First of the list: no overwrite by default
            if strcmpi(sCurProcesses.Category, 'Filter') && isfield(sCurProcesses.options, 'overwrite')
                sCurProcesses.options.overwrite.Value = 0;
            end
            DataType = InitialDataType;
            iNewProc = 1;
        elseif strcmpi(AddMode, 'add') || isempty(iSelProc) || (iSelProc == length(sCurProcesses))
            DataType = GetProcessDataType();
            sCurProcesses(end+1) = sProcesses(iProcess);
            iNewProc = length(sCurProcesses);
        elseif strcmpi(AddMode, 'insert')
            DataType = GetProcessDataType(iSelProc);
            sCurProcesses = [sCurProcesses(1:iSelProc), sProcesses(iProcess), sCurProcesses(iSelProc+1:end)];
            iNewProc = iSelProc + 1;
        end
        % Check the options data type
        if ~isempty(sCurProcesses(iNewProc).options)
            % Get list of options
            optNames = fieldnames(sCurProcesses(iNewProc).options);
            % Remove the options that do not meet the current file type requirements
            for iOpt = 1:length(optNames)
                option = sCurProcesses(iNewProc).options.(optNames{iOpt});
                isTestA  = isfield(option, 'InputTypes') && iscell(option.InputTypes);
                isTestB  = isfield(option, 'InputTypesB') && iscell(option.InputTypesB);
                % Not a valid option for this type of data: remove
                if (isTestA && ~isTestB && ~any(strcmpi(DataType, option.InputTypes))) || ...
                   (isTestB && ~isTestA && ~any(strcmpi(InitialDataType2, option.InputTypesB))) || ...
                   (isTestA && isTestB && ~any(strcmpi(DataType, option.InputTypes)) && ~any(strcmpi(InitialDataType2, option.InputTypesB)))
                    sCurProcesses(iNewProc).options = rmfield(sCurProcesses(iNewProc).options, optNames{iOpt});
                end
            end
        end
        GlobalData.Processes.Current = sCurProcesses;
        % Update pipeline
        UpdatePipeline(iNewProc);
    end

    
    %% ===== GET SELECTED PROCESS =====
    function iSel = GetSelectedProcess()
        iSel = jListProcess.getSelectedIndex();
        if (iSel == -1)
            iSel = [];
        else
            iSel = iSel + 1;
        end        
    end


    %% ===== PROCESS: REMOVE SELECTED =====
    function RemoveSelectedProcess()
        % Get selected indice
        iSel = GetSelectedProcess();
        if isempty(iSel)
            return
        end
        drawnow;
        % Select the previous process
        if (iSel > 0)
            jListProcess.setSelectedIndex(iSel - 2);
        end
        % Remove process
        GlobalData.Processes.Current(iSel) = [];
        % Set size of the list
        UpdateListSize();
        % Update processes list
        UpdateProcessesList();
        drawnow;
        % Update options
        UpdateProcessOptions();
        % Update warning button
        GetProcessDataType();
    end

    %% ===== PROCESS: MOVE SELECTED =====
    function MoveSelectedProcess(action)
        % Get selected indice
        iSelProc = GetSelectedProcess();
        if isempty(iSelProc)
            return
        end
        % Action
        switch(action)
            case 'up'
                % Already first in the list
                if (iSelProc <= 1)
                    return
                end
                % Swap with previous process
                iTargetProc = iSelProc - 1;
            case 'down'
                % Already last in the list
                if (iSelProc >= length(GlobalData.Processes.Current))
                    return
                end
                % Swap with next process
                iTargetProc = iSelProc + 1;
        end
        % Swap processes
        tmp = GlobalData.Processes.Current(iTargetProc);
        GlobalData.Processes.Current(iTargetProc) = GlobalData.Processes.Current(iSelProc);
        GlobalData.Processes.Current(iSelProc) = tmp;
        % Update processes list
        UpdateProcessesList();
        % Select moved process
        jListProcess.setSelectedIndex(iTargetProc - 1);
        % Check if pipeline is valid
        GetProcessDataType();
    end


%% =========================================================================
%  ===== PANEL AND OPTIONS FUNCTIONS =======================================
%  =========================================================================
    %% ===== PANEL: UPDATE LIST SIZE =====
    function UpdateListSize()
        % Set size of the list
        listHeight = bst_saturate(length(GlobalData.Processes.Current), [1,10]) * 28;
        jScrollProcess.setPreferredSize(java_scaled('dimension', 350, listHeight));
        jLabelEmpty.setPreferredSize(java_scaled('dimension', 350, listHeight));
    end


    %% ===== PANEL: UPDATE PIPELINE =====
    function UpdatePipeline(iSelProc)
        if (nargin < 1) || isempty(iSelProc)
            iSelProc = length(GlobalData.Processes.Current);
        end
        % Set size of the list
        UpdateListSize();
        % Update processes list
        UpdateProcessesList();
        % Select last process added
        jListProcess.setSelectedIndex(iSelProc - 1);
        % Force update of options for "select" button (it does not change the selection in the JList)
        UpdateProcessOptions();
        % Check if pipeline is valid
        GetProcessDataType();
        % Scroll down to see the last process added
        if (iSelProc > 5)
            drawnow;
            selRect = jListProcess.getCellBounds(iSelProc-1, iSelProc-1);
            jListProcess.scrollRectToVisible(selRect);
            jListProcess.repaint();
            jListProcess.getParent().getParent().repaint();
            jPanelOptions.repaint();
            jPanelInput.repaint();
            jPanelOutput.repaint();
        end
    end
    

    %% ===== PANEL: UPDATE PROCESSES LIST =====
    function UpdateProcessesList()
        import org.brainstorm.list.*;
        % Get selected indice
        iSel = jListProcess.getSelectedIndex();
        % Remove JList callbacks
        java_setcb(jListProcess, 'ValueChangedCallback', []);
        % Create a list of all the current selected processes
        listModel = javax.swing.DefaultListModel();
        for iProc = 1:length(GlobalData.Processes.Current)
            sCurProcess = GlobalData.Processes.Current(iProc);
            % Get process comment
            try
                procComment = sCurProcess.Function('FormatComment', sCurProcess);
            catch
                procComment = sCurProcess.Comment;
            end
            % Add "overwrite" option
            if isfield(sCurProcess.options, 'overwrite') && sCurProcess.options.overwrite.Value
                itemType = 'overwrite';
            else
                itemType = '';
            end
            % Create list element
            listModel.addElement(BstListItem(itemType, '', procComment, iProc));
        end
        jListProcess.setModel(listModel);
        % Set selected indice
        jListProcess.setSelectedIndex(iSel);
        % Set callbacks
        java_setcb(jListProcess, 'ValueChangedCallback', @ListProcess_ValueChangedCallback);
        % Hide/show empty label indication
        jLabelEmpty.setVisible(isempty(GlobalData.Processes.Current));
        jScrollProcess.setVisible(~isempty(GlobalData.Processes.Current));
    end


    %% ===== PANEL: UPDATE PROCESS OPTIONS =====
    function UpdateProcessOptions()
        import java.awt.Dimension;
        import javax.swing.BoxLayout;
        import org.brainstorm.list.*;
        % Starting the update
        isUpdatingPipeline = 1;
        % Font size for the options
        TEXT_DIM = java_scaled('dimension', 70, 20);
        % Empty options panels
        jPanelInput.removeAll();
        jPanelOptions.removeAll();
        jPanelOutput.removeAll();
        % Get selected process
        iProcess = GetSelectedProcess();
        % Get process
        if isempty(iProcess)
            sProcess = [];
        else
            sProcess = GlobalData.Processes.Current(iProcess);
        end
        % Get options
        if isempty(sProcess) || isempty(sProcess.options)
            optNames = [];
            pathProcess = [];
        else
            % Get all the options
            optNames = fieldnames(sProcess.options);
            % Get function name
            strFunction = func2str(sProcess.Function);
            pathProcess = which(strFunction);
        end
        % Get data type for the selected process
        if (iProcess == 1)
            curDataType = InitialDataType;
            nInputsCur = nInputsInit;
            curTimeVector = FileTimeVector;
            curSubjectName = InitialSubjectName;
        else
            [curDataType, nInputsCur, curSubjectName] = GetProcessDataType(iProcess-1);
            curTimeVector = GetProcessFileVector(GlobalData.Processes.Current(1:iProcess-1), FileTimeVector, nFiles);
        end
        % Sampling frequency 
        if (length(curTimeVector) > 2)
            curSampleFreq = 1 / (curTimeVector(2) - curTimeVector(1));
        else
            curSampleFreq = 1000;
        end
        % Set list tooltip
        jListProcess.setToolTipText(pathProcess);
        % Initialize classes to be toggled off
        ClassesToToggleOff = {};
        
        % === PROTOCOL OPTIONS ===
        for iOpt = 1:length(optNames)
            % Get option
            option = sProcess.options.(optNames{iOpt});
            % Check the option integrity
            if ~isfield(option, 'Type')
                disp(['BST> ' strFunction ': Invalid option "' optNames{iOpt} '"']);
                continue;
            end
            % If option is hidden: skip
            if isfield(option, 'Hidden') && isequal(option.Hidden, 1)
                continue;
            end
            % Enclose option line in a River panel
            jPanelOpt = gui_river([2,2], [2,4,2,4]);
            % Add class name to panel
            if isfield(option, 'Class')
                jPanelOpt.setName(option.Class);
            end
            % Define to which panel it should be added
            if isfield(option, 'Group') && strcmpi(option.Group, 'input')
                jPanelInput.add(jPanelOpt);
            elseif isfield(option, 'Group') && strcmpi(option.Group, 'output')
                jPanelOutput.add(jPanelOpt);
            else
                jPanelOptions.add(jPanelOpt);
            end
            prefPanelSize = [];
            
            % Get timing/gridding information, for all the values related controls
            if ismember(option.Type, {'range', 'timewindow', 'baseline', 'poststim', 'value'})
                % Get units
                if (length(option.Value) >= 2) && ~isempty(option.Value{2})
                    valUnits = option.Value{2};
                else
                    valUnits = ' ';
                end
                % Get precision
                if (length(option.Value) >= 3) && ~isempty(option.Value{3})
                    precision = option.Value{3};
                else
                    precision = [];
                end
                % Frequency: file, or 100
                if ismember(valUnits, {'s', 'ms', 'time'})
                    valFreq = curSampleFreq;
                elseif ~isempty(precision)
                    valFreq = 10^(precision);
                else
                    valFreq = 100;
                end
                % Bounds
                if ismember(option.Type, {'timewindow', 'baseline', 'poststim'})   % || ismember(valUnits, {'s', 'ms', 'time'})
                    if (length(curTimeVector) == 2)
                        bounds = {curTimeVector(1), curTimeVector(2), 10000};
                    elseif (length(curTimeVector) == 1)
                        bounds = [0, 1];
                    else
                        bounds = curTimeVector;
                    end
                elseif strcmpi(option.Type, 'value') && ~isempty(valUnits) && strcmpi(valUnits, 'Hz')
                    bounds = {0, 100000, valFreq};
                else
                    bounds = {-1e30, 1e30, valFreq};
                end
            end
            
            % Create the appropriate controls
            switch (option.Type)
                % RANGE: {[start,stop], units, precision}
                case {'range', 'timewindow', 'baseline', 'poststim'}
                    % Time range
                    gui_component('label',    jPanelOpt, [], ['<HTML>', option.Comment]);
                    jTextMin = gui_component('texttime', jPanelOpt, [], ' ', TEXT_DIM,[],[]);
                    gui_component('label',    jPanelOpt, [], ' - ');
                    jTextMax = gui_component('texttime', jPanelOpt, [], ' ', TEXT_DIM,[],[]);
                    % Units
                    jLabelText = gui_component('label', jPanelOpt, [], '');
                    % Add a checkbox
                    if strcmpi(option.Type, 'timewindow') || strcmpi(option.Type, 'baseline')
                        gui_component('label', jPanelOpt, [], '<HTML>&nbsp;&nbsp;&nbsp;&nbsp;');
                        jCheck = gui_component('checkbox', jPanelOpt, '', 'All file', [], [], @(h,ev)OptionTimeRangeAll_Callback(iProcess, optNames{iOpt}, ev.getSource(), jTextMin, jTextMax));
                    else
                        jCheck = [];
                    end
                    % Set controls callbacks
                    if ~isempty(option.Value) && iscell(option.Value) && ~isempty(option.Value{1})
                        initStart = option.Value{1}(1);
                        initStop  = option.Value{1}(2);
                    elseif ~isempty(jCheck)
                        if iscell(bounds)
                            initStart = bounds{1};
                            initStop  = bounds{2};
                        else
                            initStart = bounds(1);
                            initStop  = bounds(end);
                        end
                        jCheck.setSelected(1);
                        jTextMin.setEnabled(0);
                        jTextMax.setEnabled(0);
                    else
                        initStart = [];
                        initStop  = [];
                    end
                    valUnits = gui_validate_text(jTextMin, [], jTextMax, bounds, valUnits, precision, initStart, @(h,ev)OptionRange_Callback(iProcess, optNames{iOpt}, jCheck, jTextMin, jTextMax));
                    valUnits = gui_validate_text(jTextMax, jTextMin, [], bounds, valUnits, precision, initStop,  @(h,ev)OptionRange_Callback(iProcess, optNames{iOpt}, jCheck, jTextMin, jTextMax));
                    % Set unit label
                    jLabelText.setText(['<HTML>' valUnits]);
                    % Save units
                    GlobalData.Processes.Current(iProcess).options.(optNames{iOpt}).Value{2} = valUnits;

                % FREQRANGE: {value, units, precision}
                case {'freqrange','freqrange_static'}
                    % Build list of frequencies
                    if strcmpi(sFiles(1).FileType, 'timefreq') && ~strcmpi(option.Type, 'freqrange_static')
                        % Load Freqs field from the input file
                        TfMat = in_bst_timefreq(sFiles(1).FileName, 0, 'Freqs');
                        if iscell(TfMat.Freqs)
                            BandBounds = process_tf_bands('GetBounds', TfMat.Freqs);
                            FreqList = unique(BandBounds(:));
                        else
                            FreqList = TfMat.Freqs;
                        end
                        % If this file has no frequencies available: do not show this option
                        if isempty(FreqList) || isequal(FreqList, 0)
                            % Remove default values
                            SetOptionValue(iProcess, optNames{iOpt}, []);
                            continue;
                        end
                        % If there is only one frequency: duplicate it
                        if (length(FreqList) == 1)
                            FreqList = [FreqList, FreqList];
                        end
                    else
                        FreqList = [];
                    end
                    
                    % Freq range
                    gui_component('label',    jPanelOpt, [], ['<HTML>', option.Comment]);
                    jTextMin = gui_component('texttime', jPanelOpt, [], ' ', TEXT_DIM,[],[]);
                    gui_component('label',    jPanelOpt, [], ' - ');
                    jTextMax = gui_component('texttime', jPanelOpt, [], ' ', TEXT_DIM,[],[]);
                    % Units
                    gui_component('label', jPanelOpt, [], 'Hz');
                    
                    % Get precision
                    if iscell(option.Value) && (length(option.Value) >= 3) && ~isempty(option.Value{3})
                        precision = option.Value{3};
                    else
                        precision = 3;
                    end
                    % Set controls callbacks
                    if isempty(FreqList)
                        bounds = {0, 10000, 1000};
                        if ~isempty(option.Value) && iscell(option.Value) && ~isempty(option.Value{1})
                            initStart = option.Value{1}(1);
                            initStop  = option.Value{1}(2);
                        else
                            initStart = 0;
                            initStop  = 100;
                            % Set these values as current default
                            SetOptionValue(iProcess, optNames{iOpt}, {[initStart, initStop], 'Hz', precision});
                        end
                        gui_validate_text(jTextMin, [], jTextMax, bounds, 'Hz', precision, initStart, @(h,ev)OptionRange_Callback(iProcess, optNames{iOpt}, [], jTextMin, jTextMax));
                        gui_validate_text(jTextMax, jTextMin, [], bounds, 'Hz', precision, initStop,  @(h,ev)OptionRange_Callback(iProcess, optNames{iOpt}, [], jTextMin, jTextMax));
                    else
                        gui_validate_text(jTextMin, [], jTextMax, FreqList, 'Hz', precision, FreqList(1),   @(h,ev)OptionRange_Callback(iProcess, optNames{iOpt}, [], jTextMin, jTextMax));
                        gui_validate_text(jTextMax, jTextMin, [], FreqList, 'Hz', precision, FreqList(end), @(h,ev)OptionRange_Callback(iProcess, optNames{iOpt}, [], jTextMin, jTextMax));
                        % Set these values as current default
                        SetOptionValue(iProcess, optNames{iOpt}, {[FreqList(1), FreqList(end)], 'Hz', precision});
                    end

                % VALUE: {value, units, precision}
                case 'value'
                    % Label title
                    gui_component('label', jPanelOpt, [], ['<HTML>', option.Comment]);
                    % Constrain depends on the units: list fill the space horizontally
                    if strcmpi(valUnits, 'list')
                        jText = gui_component('text', jPanelOpt, 'hfill', ' ');
                    else
                        jText = gui_component('texttime', jPanelOpt, [], ' ');
                    end
                    % Set controls callbacks
                    valUnits = gui_validate_text(jText, [], [], bounds, valUnits, precision, option.Value{1}, @(h,ev)OptionValue_Callback(iProcess, optNames{iOpt}, jText));
                    % Add unit label
                    if ~strcmpi(valUnits, 'list')
                        gui_component('label', jPanelOpt, [], [' ' valUnits]);
                    else
                        jText.setHorizontalAlignment(javax.swing.JLabel.LEFT);
                    end
                    % Save units
                    GlobalData.Processes.Current(iProcess).options.(optNames{iOpt}).Value{2} = valUnits;
                    
                case 'label'
                    gui_component('label', jPanelOpt, [], ['<HTML>', option.Comment]);
                case 'text'
                    gui_component('label', jPanelOpt, [], ['<HTML>', option.Comment]);
                    jText = gui_component('text', jPanelOpt, 'hfill', option.Value);
                    % Set validation callbacks
                    java_setcb(jText, 'ActionPerformedCallback', @(h,ev)SetOptionValue(iProcess, optNames{iOpt}, char(ev.getSource().getText())), ...
                                      'FocusLostCallback',       @(h,ev)SetOptionValue(iProcess, optNames{iOpt}, char(ev.getSource().getText())));
                case 'textarea'
                    gui_component('label', jPanelOpt, [], ['<HTML>', option.Comment]);
                    jText = gui_component('textfreq', jPanelOpt, 'br hfill', option.Value);
                    % Set validation callbacks
                    java_setcb(jText, 'FocusLostCallback', @(h,ev)SetOptionValue(iProcess, optNames{iOpt}, char(ev.getSource().getText())));
                case 'groupbands'
                    gui_component('label', jPanelOpt, [], option.Comment);
                    strBands = process_tf_bands('FormatBands', option.Value);
                    gui_component('textfreq', jPanelOpt, 'br hfill', strBands, [], [], @(h,ev)OptionBands_Callback(iProcess, optNames{iOpt}, ev.getSource()));

                case 'checkbox'
                    jCheck = gui_component('checkbox', jPanelOpt, [], ['<HTML>', option.Comment], [], [], @(h,ev)SetOptionValue(iProcess, optNames{iOpt}, double(ev.getSource().isSelected())));
                    isSelected = logical(option.Value);
                    jCheck.setSelected(isSelected);
                    % If class controller not selected, toggle off class
                    if ~isSelected && isfield(option, 'Controller') && ~isempty(option.Controller)
                        ClassesToToggleOff{end+1} = option.Controller;
                    end
                case 'radio'
                    jButtonGroup = javax.swing.ButtonGroup();
                    constr = [];
                    for iRadio = 1:length(option.Comment)
                        jCheck = gui_component('radio', jPanelOpt, constr, ['<HTML>', option.Comment{iRadio}], [], [], @(h,ev)OptionRadio_Callback(iProcess, optNames{iOpt}, iRadio, ev.getSource().isSelected()));
                        jCheck.setSelected(option.Value == iRadio);
                        jButtonGroup.add(jCheck);
                        constr = 'br';
                    end
                case 'radio_label'
                    jButtonGroup = javax.swing.ButtonGroup();
                    constr = [];
                    for iRadio = 1:size(option.Comment, 2)
                        jCheck = gui_component('radio', jPanelOpt, constr, ['<HTML>', option.Comment{1,iRadio}], [], [], @(h,ev)OptionRadio_Callback(iProcess, optNames{iOpt}, option.Comment{2,iRadio}, ev.getSource().isSelected()));
                        jCheck.setSelected(strcmpi(option.Value, option.Comment{2,iRadio}));
                        jButtonGroup.add(jCheck);
                        constr = 'br';
                    end
                    % If class controller not selected, toggle off class
                    if isfield(option, 'Controller') && ~isempty(option.Controller) && isstruct(option.Controller)
                        for f = fieldnames(option.Controller)'
                            if ~strcmpi(f{1}, option.Value) && ~isempty(option.Controller.(f{1})) && ~(isfield(option.Controller, option.Value) && isequal(option.Controller.(option.Value), option.Controller.(f{1})))
                                ClassesToToggleOff{end+1} = option.Controller.(f{1});
                            end
                        end
                    end
                case 'radio_line'
                    jButtonGroup = javax.swing.ButtonGroup();
                    if ~isempty(option.Comment{end})
                        gui_component('label', jPanelOpt, [], ['<HTML>', option.Comment{end}, '&nbsp;&nbsp;']);
                    end
                    for iRadio = 1:length(option.Comment)-1
                        jCheck = gui_component('radio', jPanelOpt, [], ['<HTML>', option.Comment{iRadio}], [], [], @(h,ev)OptionRadio_Callback(iProcess, optNames{iOpt}, iRadio, ev.getSource().isSelected()));
                        jCheck.setSelected(option.Value == iRadio);
                        jButtonGroup.add(jCheck);
                    end
                case 'radio_linelabel'
                    jButtonGroup = javax.swing.ButtonGroup();
                    if ~isempty(option.Comment{1,end})
                        gui_component('label', jPanelOpt, [], ['<HTML>', option.Comment{1,end}, '&nbsp;&nbsp;']);
                    end
                    for iRadio = 1:size(option.Comment, 2)-1
                        jCheck = gui_component('radio', jPanelOpt, [], ['<HTML>', option.Comment{1,iRadio}], [], [], @(h,ev)OptionRadio_Callback(iProcess, optNames{iOpt}, option.Comment{2,iRadio}, ev.getSource().isSelected()));
                        jCheck.setSelected(strcmpi(option.Value, option.Comment{2,iRadio}));
                        jButtonGroup.add(jCheck);
                    end
                    % If class controller not selected, toggle off class
                    if isfield(option, 'Controller') && ~isempty(option.Controller) && isstruct(option.Controller)
                        for f = fieldnames(option.Controller)'
                            if ~strcmpi(f{1}, option.Value) && ~isempty(option.Controller.(f{1})) && ~(isfield(option.Controller, option.Value) && isequal(option.Controller.(option.Value), option.Controller.(f{1})))
                                ClassesToToggleOff{end+1} = option.Controller.(f{1});
                            end
                        end
                    end
                case 'combobox'
                    gui_component('label', jPanelOpt, [], ['<HTML>', option.Comment, '&nbsp;&nbsp;']);
                    % Combo box
                    jCombo = gui_component('ComboBox', jPanelOpt, [], [], option.Value(2));
                    jCombo.setEditable(false);
                    jPanelOpt.add(jCombo);
                    % Select previously selected item
                    jCombo.setSelectedIndex(option.Value{1} - 1);
                    % Set validation callbacks
                    java_setcb(jCombo, 'ActionPerformedCallback', @(h,ev)SetOptionValue(iProcess, optNames{iOpt}, {ev.getSource().getSelectedIndex()+1, option.Value{2}}));
                case 'combobox_label'
                    gui_component('label', jPanelOpt, [], ['<HTML>', option.Comment, '&nbsp;&nbsp;']);
                    % Combo box
                    cellValues = option.Value{2};
                    jCombo = gui_component('ComboBox', jPanelOpt, [], [], {cellValues(1,:)});
                    jCombo.setEditable(false);
                    jPanelOpt.add(jCombo);
                    % Select previously selected item
                    iSel = find(strcmpi(option.Value{1}, cellValues(2,:)));
                    if ~isempty(iSel)
                        jCombo.setSelectedIndex(iSel-1);
                    end
                    % Set validation callbacks
                    java_setcb(jCombo, 'ActionPerformedCallback', @(h,ev)SetOptionValue(iProcess, optNames{iOpt}, {cellValues{2,ev.getSource().getSelectedIndex()+1}, option.Value{2}}));
                    
                case 'freqsel'
                    % Load Freq field from the input file
                    if strcmpi(sFiles(1).FileType, 'timefreq')
                        TfMat = in_bst_timefreq(sFiles(1).FileName, 0, 'Freqs');
                    else
                        TfMat.Freqs = [];
                    end
                    % Build list of frequencies
                    if isempty(TfMat.Freqs)
                        comboList = {'Not available'};
                        nList = 0;
                    elseif iscell(TfMat.Freqs)
                        comboList = TfMat.Freqs(:,1)';
                        nList = size(TfMat.Freqs,1);
                    else
                        for ifr = 1:length(TfMat.Freqs)
                            comboList{ifr} = num2str(TfMat.Freqs(ifr));
                        end
                        nList = length(TfMat.Freqs);
                    end
                    % Label
                    gui_component('label', jPanelOpt, [], ['<HTML>', option.Comment, '&nbsp;&nbsp;']);
                    % Combo box
                    jCombo = gui_component('ComboBox', jPanelOpt, [], [], {comboList});
                    jCombo.setEditable(false);
                    jPanelOpt.add(jCombo);
                    % Select previously selected item
                    if ~isempty(option.Value) && (option.Value <= nList)
                        jCombo.setSelectedIndex(option.Value - 1);
                    % Otherwise, reset to the first element of the list
                    else
                        jCombo.setSelectedIndex(0);
                        SetOptionValue(iProcess, optNames{iOpt}, 1);
                    end
                    % Set validation callbacks
                    java_setcb(jCombo, 'ActionPerformedCallback', @(h,ev)SetOptionValue(iProcess, optNames{iOpt}, ev.getSource().getSelectedIndex()+1));
                    
                case 'montage'
                    % Load channel file of first file in input
                    ChannelMat = in_bst_channel(sFiles(1).ChannelFile);
                    % Update automatic montages
                    panel_montage('UnloadAutoMontages');
                    if any(ismember({'ECOG', 'SEEG'}, {ChannelMat.Channel.Type}))
                        panel_montage('AddAutoMontagesSeeg', sFiles(1).SubjectName, ChannelMat);
                    end
                    if ismember('NIRS', {ChannelMat.Channel.Type})
                        panel_montage('AddAutoMontagesNirs', ChannelMat);
                    end
                    if ~isempty(ChannelMat.Projector)
                        panel_montage('AddAutoMontagesProj', ChannelMat);
                    end
                    % Get all the montage names
                    AllMontages = panel_montage('GetMontage',[]);
                    AllNames = {AllMontages.Name};
                    % Remove some montages
                    iRemove = find(ismember(AllNames, {'Bad channels', 'EOG', 'EMG', 'ExG', 'MISC'}));
                    AllNames(iRemove) = [];
                    % Label
                    gui_component('label', jPanelOpt, [], ['<HTML>', option.Comment, '&nbsp;&nbsp;']);
                    % Combo box
                    jCombo = gui_component('ComboBox', jPanelOpt, [], [], {AllNames});
                    jCombo.setEditable(false);
                    jPanelOpt.add(jCombo);
                    % Select previously selected montage
                    if ~isempty(option.Value) && ischar(option.Value)
                        iItem = find(strcmpi(AllNames, option.Value));
                        if ~isempty(iItem)
                            jCombo.setSelectedIndex(iItem - 1);
                        end
                    else
                        % If there were no previous options selected: use the first one as a default
                        SetOptionValue(iProcess, optNames{iOpt}, AllNames{1});
                    end
                    % Set validation callbacks
                    java_setcb(jCombo, 'ActionPerformedCallback', @(h,ev)SetOptionValue(iProcess, optNames{iOpt}, AllNames{ev.getSource().getSelectedIndex()+1}));
                    
                case {'cluster', 'cluster_confirm'}
                    % Get available and selected clusters
                    jList = GetClusterList(sProcess, optNames{iOpt});
                    % If no clusters
                    if isempty(jList)
                        gui_component('label', jPanelOpt, [], '<HTML>Error: No clusters available in channel file.');
                    else
                        % Confirm selection
                        if strcmpi(option.Type, 'cluster_confirm')
                            if ~isempty(option.Comment)
                                strCheck = option.Comment;
                            else
                                strCheck = 'Use cluster time series:';
                            end
                            jCheckCluster = gui_component('checkbox', jPanelOpt, [], strCheck);
                            java_setcb(jCheckCluster, 'ActionPerformedCallback', @(h,ev)Cluster_ValueChangedCallback(iProcess, optNames{iOpt}, jList, jCheckCluster, []));
                            jCheckCluster.setSelected(1)
                            jList.setEnabled(1);
                        else
                            jCheckCluster = [];
                            gui_component('label', jPanelOpt, [], ' Select cluster:');
                        end
                        % Set callbacks
                        java_setcb(jList, 'ValueChangedCallback', @(h,ev)Cluster_ValueChangedCallback(iProcess, optNames{iOpt}, jList, jCheckCluster, ev));
                        Cluster_ValueChangedCallback(iProcess, optNames{iOpt}, jList, jCheckCluster, []);
                        % Create scroll panel
                        jScroll = javax.swing.JScrollPane(jList);
                        jPanelOpt.add('br hfill vfill', jScroll);
                        % Set preferred size for the container
                        prefPanelSize = java_scaled('dimension', 250,120);
                    end
                    
                case {'scout', 'scout_confirm'}
                    % Get available and selected scouts
                    [AtlasList, iAtlasList] = GetAtlasList(sProcess, optNames{iOpt});
                    % If no scouts are available
                    if isempty(AtlasList)
                        gui_component('label', jPanelOpt, [], '<HTML>No scouts available.');
                    else
                        % Create list
                        jList = java_create('javax.swing.JList');
                        jList.setLayoutOrientation(jList.HORIZONTAL_WRAP);
                        jList.setVisibleRowCount(-1);
                        jList.setCellRenderer(BstStringListRenderer(fontSize));
                        % Confirm selection
                        if strcmpi(option.Type, 'scout_confirm')
                            if ~isempty(option.Comment)
                                strCheck = option.Comment;
                            else
                                strCheck = 'Use scouts';
                            end
                            jCheck = gui_component('checkbox', jPanelOpt, [], strCheck);
                            if ~isempty(option.Value)
                                jCheck.setSelected(1);
                                isListEnable = 1;
                            else
                                isListEnable = 0;
                            end
                        else
                            jCheck = [];
                            gui_component('label', jPanelOpt, [], 'Select scouts:');
                            isListEnable = 1;
                        end
                        % Horizontal glue
                        gui_component('label', jPanelOpt, 'hfill', ' ', [],[],[],[]);
                        % Atlas selection box
                        jCombo = gui_component('combobox', jPanelOpt, 'right', [], {AtlasList(:,1)}, [], []);
                        % Try to re-use previously defined atlas
                        if ~isempty(option.Value) && iscell(option.Value) && (size(option.Value,2) >= 2) && ischar(option.Value{1,1}) && ~isempty(AtlasList)
                            iPrev = find(strcmpi(option.Value{1,1}, AtlasList(:,1)));
                            if ~isempty(iPrev)
                                iAtlasList = iPrev;
                            end
                        end
                        % Select default atlas
                        if ~isempty(iAtlasList) && (iAtlasList >= 1) && (iAtlasList <= size(AtlasList,1))
                            jCombo.setSelectedIndex(iAtlasList - 1);
                        end
                        % Enable/disable controls
                        jList.setEnabled(isListEnable);
                        jCombo.setEnabled(isListEnable);

                        % Set current atlas
                        AtlasSelection_Callback(iProcess, optNames{iOpt}, AtlasList, jCombo, jList, []);
                        drawnow;
                        % Set callbacks
                        java_setcb(jCombo, 'ItemStateChangedCallback', @(h,ev)AtlasSelection_Callback(iProcess, optNames{iOpt}, AtlasList, jCombo, jList, ev));
                        java_setcb(jList,  'ValueChangedCallback', @(h,ev)ScoutSelection_Callback(iProcess, optNames{iOpt}, AtlasList, jCombo, jList, jCheck, ev));
                        if ~isempty(jCheck)
                            java_setcb(jCheck, 'ActionPerformedCallback', @(h,ev)ScoutSelection_Callback(iProcess, optNames{iOpt}, AtlasList, jCombo, jList, jCheck, []));
                        end
                        % Create scroll panel
                        jScroll = javax.swing.JScrollPane(jList);
                        jPanelOpt.add('br hfill vfill', jScroll);
                        % Set preferred size for the container
                        prefPanelSize = java_scaled('dimension', 250,180);
                    end
                    
                case 'channelname'
                    gui_component('label', jPanelOpt, [], ['<HTML>', option.Comment, '&nbsp;&nbsp;']);
                    % Combo box
                    jCombo = gui_component('ComboBox', jPanelOpt, [], [], {ChannelNames});
                    jCombo.setEditable(true);
                    % Select previously selected channel
                    jCombo.setSelectedItem(option.Value);
                    % Set validation callbacks
                    java_setcb(jCombo, 'ActionPerformedCallback', @(h,ev)SetOptionValue(iProcess, optNames{iOpt}, char(ev.getSource().getSelectedItem())));
                    
                case 'subjectname'
                    gui_component('label', jPanelOpt, [], ['<HTML>', option.Comment, '&nbsp;&nbsp;']);
                    % Default subject: current subject, or previous call
                    if ~isempty(curSubjectName)
                        defSubjectName = curSubjectName;
                    elseif ~isempty(option.Value)
                        defSubjectName = option.Value;
                    else
                        defSubjectName = [];
                    end
                    % Combo box: create list of subjects
                    listSubj = SubjectNames;
                    if ~isempty(defSubjectName) && ~ismember(defSubjectName, listSubj)
                        listSubj{end+1} = defSubjectName;
                    end
                    if isempty(listSubj)
                        listSubj = {'NewSubject'};
                    end
                    jCombo = gui_component('ComboBox', jPanelOpt, [], [], {listSubj});
                    jCombo.setEditable(true);
                    % Select previously selected subject
                    if ~isempty(defSubjectName)
                        iDefault = find(strcmp(listSubj, defSubjectName));
                    elseif ~isempty(iSelSubject)
                        iDefault = iSelSubject;
                    else
                        iDefault = 1;
                    end
                    % Select element in the combobox
                    jCombo.setSelectedIndex(iDefault - 1);
                    % Save the selected value
                    SetOptionValue(iProcess, optNames{iOpt}, listSubj{iDefault});
                    % Set validation callbacks
                    java_setcb(jCombo, 'ActionPerformedCallback', @(h,ev)SetOptionValue(iProcess, optNames{iOpt}, char(ev.getSource().getSelectedItem())));
                    
                case 'atlas'
                    gui_component('label', jPanelOpt, [], ['<HTML>', option.Comment, '&nbsp;&nbsp;']);
                    % Get available atlases for target subject
                    atlasNames = {''};
                    iAtlas = [];
                    if ~isempty(sFiles(1).SubjectFile) % && strcmpi(curDataType, 'results')
                        % Read the subject structure
                        sSubject = bst_get('Subject', sFiles(1).SubjectFile);
                        if ~isempty(sSubject) && ~isempty(sSubject.iCortex)
                            surfFile = file_fullpath(sSubject.Surface(sSubject.iCortex).FileName);
                            if ~isempty(surfFile) && file_exist(surfFile)
                                surfMat = load(surfFile, 'Atlas', 'iAtlas');
                                if isfield(surfMat, 'Atlas') && isfield(surfMat, 'iAtlas') && ~isempty(surfMat.Atlas) && ~isempty(surfMat.iAtlas)
                                    atlasNames = {surfMat.Atlas.Name};
                                    iAtlas = surfMat.iAtlas;
                                end
                            end
                        end
                    end
                    % Create combo box
                    jCombo = gui_component('ComboBox', jPanelOpt, [], [], {atlasNames});
                    jCombo.setEditable(true);
                    % Select previously selected subject
                    iDefault = [];
                    if ~isempty(option.Value) && ~isempty(atlasNames)
                        iDefault = find(strcmpi(option.Value, atlasNames));
                    end
                    if isempty(iDefault) && ~isempty(iAtlas)
                        iDefault = iAtlas;
                    end
                    if ~isempty(iDefault)
                        jCombo.setSelectedIndex(iDefault - 1);
                    else
                        SetOptionValue(iProcess, optNames{iOpt}, atlasNames{1});
                    end
                    % Set validation callbacks
                    java_setcb(jCombo, 'ActionPerformedCallback', @(h,ev)SetOptionValue(iProcess, optNames{iOpt}, char(ev.getSource().getSelectedItem())));

                case {'filename', 'datafile'}
                    % Get filename
                    FileNames = option.Value{1};
                    if isempty(FileNames)
                        strFiles = '';
                    elseif ischar(FileNames)
                        % [tmp,fBase,fExt] = bst_fileparts(FileNames);
                        % strFiles = [fBase,fExt];
                        strFiles = FileNames;
                    else
                        if (length(FileNames) == 1)
                            % [tmp,fBase,fExt] = bst_fileparts(FileNames{1});
                            % strFiles = [fBase,fExt];
                            strFiles = FileNames{1};
                        else
                            strFiles = sprintf('[%d files]', length(FileNames));
                        end
                    end
                    % Create controls
                    jLabel = gui_component('label', jPanelOpt, [], ['<HTML>', option.Comment, '&nbsp;&nbsp;']);
                    jText = gui_component('text', jPanelOpt, [], strFiles);
                    jText.setEditable(0);
                    jText.setPreferredSize(java_scaled('dimension', 210, 20));
                    isUpdateTime = strcmpi(option.Type, 'datafile');
                    if strcmp(strFunction, 'process_export_file')
                        if length(sFiles) > 1
                            % Export multiple files, suggest dir name to export files (filenames from Brainstorm DB)
                            jLabel.setText('Output dir');
                            GlobalData.Processes.Current(iProcess).options.(optNames{iOpt}).Value{7} = 'dirs';
                            LastUsedDirs = bst_get('LastUsedDirs');
                            GlobalData.Processes.Current(iProcess).options.(optNames{iOpt}).Value{1} = LastUsedDirs.ExportData;
                            jText.setText(LastUsedDirs.ExportData);
                        else
                            % Export one file, suggest filename for new file from Input file
                            jLabel.setText('Output file');
                            GlobalData.Processes.Current(iProcess).options.(optNames{iOpt}).Value{7} = 'files';
                            if isempty(GlobalData.Processes.Current(iProcess).options.(optNames{iOpt}).Value{1}) || strcmp(option.Value{7}, 'dirs')
                                % Used in SaveFile_Callback() to suggeste name of export file
                                GlobalData.Processes.Current(iProcess).options.(optNames{iOpt}).Value{1} = sFiles(1).FileName;
                            end
                            jText.setText(GlobalData.Processes.Current(iProcess).options.(optNames{iOpt}).Value{1});
                        end
                        gui_component('button', jPanelOpt, '', '...', [],[], @(h,ev)SaveFile_Callback(iProcess, optNames{iOpt}, jText));
                    else
                        % Pick file or dir (Open File or Select Dir to Save)
                        gui_component('button', jPanelOpt, '', '...', [],[], @(h,ev)PickFile_Callback(iProcess, optNames{iOpt}, jText, isUpdateTime));
                    end

                case 'editpref'
                    gui_component('label',  jPanelOpt, [], ['<HTML>', option.Comment{2}, '&nbsp;&nbsp;&nbsp;']);
                    gui_component('button', jPanelOpt, [], 'Edit...', [],[], @(h,ev)EditProperties_Callback(iProcess, optNames{iOpt}));
                    
                case 'button'
                    % Get code to execute when clicking on the button
                    strEval = option.Comment{1};
                    strEval = strrep(strEval, 'iProcess', num2str(iProcess));
                    strEval = strrep(strEval, 'sfreq',    sprintf('%0.3f', 1 ./ (curTimeVector(2)-curTimeVector(1))));
                    gui_component('label',  jPanelOpt, [], ['<HTML>', option.Comment{2}, '&nbsp;&nbsp;&nbsp;']);
                    gui_component('button', jPanelOpt, [], option.Comment{3}, [],[], @(h,ev)eval(strEval));
                    
                case 'separator'
                    gui_component('label', jPanelOpt, [], ' ');
                    jsep = gui_component('label', jPanelOpt, 'br hfill', ' ');
                    jsep.setBackground(java.awt.Color(.4,.4,.4));
                    jsep.setOpaque(1);
                    jsep.setPreferredSize(java_scaled('dimension', 1,1));
                    gui_component('label', jPanelOpt, 'br', ' ');
                
                case 'event_ordered'
                    if isfield(option, 'Spikes')
                        spikesOption = option.Spikes;
                    else
                        spikesOption = [];
                    end
                    
                    optionPanel = gui_component('Panel');
                    optionPanel.setLayout(BoxLayout(optionPanel, BoxLayout.Y_AXIS));
                    gui_component('label', optionPanel, [], ['<html><b><u>', option.Comment, '</u></b>&nbsp;&nbsp;&nbsp;']);
                    
                    subPanel = gui_component('Panel');
                    subPanel.setLayout(BoxLayout(subPanel, BoxLayout.Y_AXIS));
                    
                    %Get event list
                    eventList = gui_component('Panel');
                    eventList.setLayout(BoxLayout(eventList, BoxLayout.X_AXIS));
                    events = GetEventList(spikesOption);
                    
                    %%%%
                    % Create a list of the existing clusters/scouts
                    %%%%
                    listModel = javax.swing.DefaultListModel();
                    for iEvent = 1:length(events)
                        listModel.addElement(events{iEvent});
                    end

                    % Create list
                    jList = java_create('javax.swing.JList');
                    jList.setModel(listModel);
                    jList.setVisibleRowCount(-1);
                    jList.setCellRenderer(BstStringListRenderer(fontSize));
                    
                    % Create scroll panel
                    jScroll = javax.swing.JScrollPane(jList);
                    jScroll.setPreferredSize(java_scaled('dimension', 150,100));
                    eventList.add('br', jScroll);
                    
                    %%%
                    % Create a list of the selected clusters/scouts
                    %%%
                    selectedListModel = javax.swing.DefaultListModel();

                    % Create list
                    jSelectedList = java_create('javax.swing.JList');
                    jSelectedList.setModel(selectedListModel);
                    jSelectedList.setVisibleRowCount(-1);
                    jSelectedList.setCellRenderer(BstStringListRenderer(fontSize));
                    
                    % Create scroll panel
                    jSelectedScroll = javax.swing.JScrollPane(jSelectedList);
                    jSelectedScroll.setPreferredSize(java_scaled('dimension', 150,100));
                    eventList.add('br', jSelectedScroll);

                    
                    %% Buttons
                    eventButtons = gui_river([1,2]);
                    eventButtons.setLayout(BoxLayout(eventButtons, BoxLayout.X_AXIS));
                    gui_component('button', eventButtons, [], '<', [],[], @(h,ev)RemoveEvent_Callback(iProcess, optNames{iOpt}, jSelectedList, jList));
                    gui_component('button', eventButtons, [], '>', [],[], @(h,ev)AddEvent_Callback(iProcess, optNames{iOpt}, jSelectedList, jList));
                    
                    subPanel.add(eventButtons);
                    subPanel.add(eventList);
                    optionPanel.add(subPanel);
                    jPanelOpt.add(optionPanel);
                    
                case 'event'
                    if isfield(option, 'Spikes')
                        spikesOption = option.Spikes;
                    else
                        spikesOption = [];
                    end
                    
                    optionPanel = gui_component('Panel');
                    optionPanel.setLayout(BoxLayout(optionPanel, BoxLayout.Y_AXIS));
                    label = gui_component('label', optionPanel, [], ['<html><b><u>', option.Comment, '</u></b>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;']);
                    label.setHorizontalAlignment(javax.swing.JLabel.CENTER); % Sorry for the hack above. Wasn't being centered otherwise. Strangely, it works for any string length.
                    
                    %Get event list
                    eventList = gui_component('Panel');
                    eventList.setLayout(BoxLayout(eventList, BoxLayout.Y_AXIS));
                    events = GetEventList(spikesOption);

                    %%%%
                    % Create a list of the existing clusters/scouts
                    %%%%
                    listModel = javax.swing.DefaultListModel();
                    for iEvent = 1:length(events)
                        listModel.addElement(events{iEvent});
                    end

                    % Create list
                    jList = java_create('javax.swing.JList');
                    jList.setLayoutOrientation(jList.VERTICAL_WRAP);
                    jList.setModel(listModel);
                    jList.setVisibleRowCount(-1);
                    jList.setCellRenderer(BstStringListRenderer(fontSize));
                    java_setcb(jList, 'ValueChangedCallback', @(h,ev)EventSelection_Callback(iProcess, optNames{iOpt}, jList));
                    
                    % Create scroll panel
                    jScroll = javax.swing.JScrollPane(jList);
                    jScroll.setPreferredSize(java_scaled('dimension', 301,80));
                    eventList.add('br', jScroll);
                    optionPanel.add(eventList);
                    jPanelOpt.add(optionPanel);
            end
            jPanelOpt.setPreferredSize(prefPanelSize);
        end
        % Toggle off classes
        for iClass = 1:length(ClassesToToggleOff)
            ToggleClass(ClassesToToggleOff{iClass}, 0);
        end
        % If there are no components in the options panel: display "no options"
        isEmptyOptions = (jPanelOptions.getComponentCount() == 0);
        if isEmptyOptions
            if ~isempty(iProcess)
                strEmpty = '<HTML>&nbsp;&nbsp;&nbsp;&nbsp;<FONT color="#777777"> No options for this process</FONT><BR>';
            else
                strEmpty = '<HTML>&nbsp;&nbsp;&nbsp;&nbsp;<FONT color="#777777"> No process selected</FONT><BR>';
            end
            jPanelOpt = gui_river([2,2], [2,4,2,4]);
            gui_component('label', jPanelOpt, 'hfill', strEmpty);
            jPanelOptions.add(jPanelOpt);
        end
        % Hide/show other options panels
        jPanelInput.setVisible(jPanelInput.getComponentCount() > 0);
        jPanelOptions.setVisible(~isempty(GlobalData.Processes.Current));
        jPanelOutput.setVisible(jPanelOutput.getComponentCount() > 0);
        % Hide/Show help button
        jButtonHelp.setVisible(~isempty(sProcess) && ~isempty(sProcess.Description));
        % Update figure size
        jParent = jPanelMain.getTopLevelAncestor();
        if ~isempty(jParent)
            jParent.pack();
        end
        % Stopping the update
        isUpdatingPipeline = 0;
    end

    %% ===== OPTIONS: ADD EVENT CALLBACK =====
    function AddEvent_Callback(iProcess, optName, jSelectedList, jOtherList)
        selectedListModel = jSelectedList.getModel();
        otherListModel = jOtherList.getModel();
        iSels = jOtherList.getSelectedIndices();
        elems = {};
        
        % Get selected elements
        for iSel = 1:length(iSels)
            elems{end + 1} = otherListModel.getElementAt(iSels(iSel));
        end
        
        % Move from other to selected list
        for iElem = 1:length(elems)
            selectedListModel.addElement(elems{iElem});
            otherListModel.removeElement(elems{iElem});
        end
        
        % Update saved selected list
        elems = {};
        for iElem = 1:selectedListModel.getSize()
            elems{end + 1} = selectedListModel.elementAt(iElem - 1);
        end
        SetOptionValue(iProcess, optName, elems);
    end

    %% ===== OPTIONS: REMOVE EVENT CALLBACK =====
    function RemoveEvent_Callback(iProcess, optName, jSelectedList, jOtherList)
        selectedListModel = jSelectedList.getModel();
        otherListModel = jOtherList.getModel();
        iSels = jSelectedList.getSelectedIndices();
        elems = {};
        
        % Get selected elements
        for iSel = 1:length(iSels)
            elems{end + 1} = selectedListModel.getElementAt(iSels(iSel));
        end
        
        % Move from other to selected list
        for iElem = 1:length(elems)
            otherListModel.addElement(elems{iElem});
            selectedListModel.removeElement(elems{iElem});
        end
        
        % Update saved selected list
        elems = {};
        for iElem = 1:selectedListModel.getSize()
            elems{end + 1} = selectedListModel.elementAt(iElem - 1);
        end
        SetOptionValue(iProcess, optName, elems);
    end

    %% ===== OPTIONS: SELECT EVENT CALLBACK =====
    function EventSelection_Callback(iProcess, optName, jList)
        listModel = jList.getModel();
        iSels = jList.getSelectedIndices();
        elems = {};
        
        % Update saved selected list
        for iSel = 1:length(iSels)
            elems{end + 1} = listModel.elementAt(iSels(iSel));
        end
        SetOptionValue(iProcess, optName, elems);
    end

    %% ===== OPTIONS: FREQ BANDS CALLBACK =====
    function OptionBands_Callback(iProcess, optName, jText)
        % Get bands
        value = process_tf_bands('ParseBands', char(jText.getText()));
        % Update interface
        SetOptionValue(iProcess, optName, value);
    end

    %% ===== OPTIONS: RANGE CALLBACK =====
    function OptionRange_Callback(iProcess, optName, jCheck, jTextMin, jTextMax)
        % Get current options
        try
            value = GlobalData.Processes.Current(iProcess).options.(optName).Value;
            valUnits = value{2};
            % Use text boxes or use all the file
            if ~isempty(jCheck)
                isAll = jCheck.isSelected();
            else
                isAll = 0;
            end
            % Get new value
            if isAll
                value{1} = [];
            else
                value{1} = [GetValue(jTextMin, valUnits), GetValue(jTextMax, valUnits)];
            end
            % Update interface
            SetOptionValue(iProcess, optName, value);
        catch
        end
    end

    %% ===== OPTIONS: TIME RANGE ALL CHECKBOX =====
    function OptionTimeRangeAll_Callback(iProcess, optName, jCheck, jTextMin, jTextMax)
        % Get current options
        isAll = jCheck.isSelected();
        % Get new value
        jTextMin.setEnabled(~isAll);
        jTextMax.setEnabled(~isAll);
        % Update interface
        OptionRange_Callback(iProcess, optName, jCheck, jTextMin, jTextMax)
    end

    %% ===== OPTIONS: VALUE CALLBACK =====
    function OptionValue_Callback(iProcess, optName, jText)
        try
            % Get current options
            value = GlobalData.Processes.Current(iProcess).options.(optName).Value;
            valUnits = value{2};
            % Get new value
            value{1} = GetValue(jText, valUnits);
            % Update interface
            SetOptionValue(iProcess, optName, value);
        catch
        end
    end


    %% ===== OPTIONS: PICK FILE CALLBACK =====
    function PickFile_Callback(iProcess, optName, jText, isUpdateTime)
        % Get default import directory and formats
        LastUsedDirs = bst_get('LastUsedDirs');
        DefaultFormats = bst_get('DefaultFormats');
        % Get file selection options
        selectOptions = GlobalData.Processes.Current(iProcess).options.(optName).Value;
        if (length(selectOptions) == 9)
            DialogType    = selectOptions{3};
            WindowTitle   = selectOptions{4};
            DefaultDir    = selectOptions{5};
            SelectionMode = selectOptions{6};
            FilesOrDir    = selectOptions{7};
            Filters       = selectOptions{8};
            DefaultFormat = selectOptions{9};
            % Default dir type
            if isfield(LastUsedDirs, DefaultDir)
                DefaultFile = LastUsedDirs.(DefaultDir);
            else
                DefaultFile = DefaultDir;
                DefaultDir = [];
            end
            % Default filter
            if isfield(DefaultFormats, DefaultFormat)
                defaultFilter = DefaultFormats.(DefaultFormat);
            else
                defaultFilter = [];
                DefaultFormat = [];
            end
        else
            DialogType    = 'open';
            WindowTitle   = 'Open file';
            DefaultDir    = '';
            DefaultFile   = '';
            SelectionMode = 'single';
            FilesOrDir    = 'files_and_dirs';
            Filters       = {{'*'}, 'All files (*.*)', 'ALL'};
            DefaultFormat = [];
            defaultFilter = [];
        end
        
        % Pick a file
        [OutputFiles, FileFormat] = java_getfile(DialogType, WindowTitle, DefaultFile, SelectionMode, FilesOrDir, Filters, defaultFilter);
        % If nothing selected
        if isempty(OutputFiles)
            return
        end
        % Progress bar
        bst_progress('start', 'Import MEG/EEG recordings', 'Reading the file header...');
        % Save default import directory
        if ~isempty(DefaultDir)
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
        end
        % Save default import format
        if ~isempty(DefaultFormat)
            DefaultFormats.(DefaultFormat) = FileFormat;
            bst_set('DefaultFormats',  DefaultFormats);
        end
        % Get file descriptions (one/many)
        if ischar(OutputFiles)
            % [tmp,fBase,fExt] = bst_fileparts(OutputFiles);
            % strFiles = [fBase,fExt];
            strFiles = OutputFiles;
            FirstFile = OutputFiles;
        else
            if (length(OutputFiles) == 1)
                % [tmp,fBase,fExt] = bst_fileparts(OutputFiles{1});
                % strFiles = [fBase,fExt];
                strFiles = OutputFiles{1};
            else
                strFiles = sprintf('[%d files]', length(OutputFiles));
            end
            FirstFile = OutputFiles{1};
        end
        
        % === SUB-CATEGORIES IN FILE FORMAT ===
        if strcmpi(FileFormat, 'EEG-NEUROSCAN')
            [tmp, tmp, fileExt] = bst_fileparts(FirstFile);
            % Switch between different Neuroscan formats
            switch (lower(fileExt))
                case '.cnt',  FileFormat = 'EEG-NEUROSCAN-CNT';
                case '.eeg',  FileFormat = 'EEG-NEUROSCAN-EEG';
                case '.avg',  FileFormat = 'EEG-NEUROSCAN-AVG';
                case '.dat',  FileFormat = 'EEG-NEUROSCAN-DAT';
            end
        end

        % Update the values
        selectOptions{1} = OutputFiles;
        selectOptions{2} = FileFormat;
        % Save the new values
        SetOptionValue(iProcess, optName, selectOptions);
        % Update the text field
        jText.setText(strFiles);
        
        % Try to open the file and update the current time vector
        if isUpdateTime
            % Load RAW FileTimeVector
            TimeVector = LoadRawTime(FirstFile, FileFormat);
            if ~isempty(TimeVector)
                FileTimeVector = TimeVector;
                % Reload options
                GlobalData.Processes.Current = SetDefaultOptions(GlobalData.Processes.Current, FileTimeVector, 0);
                UpdateProcessOptions();
            else
                jText.setText(strFiles);
            end
        end
        % Close progress bar
        bst_progress('stop');
    end


    %% ===== OPTIONS: SAVE FILE CALLBACK =====
    function SaveFile_Callback(iProcess, optName, jText)
        % Get default import directory and formats
        LastUsedDirs = bst_get('LastUsedDirs');
        DefaultFormats = bst_get('DefaultFormats');
        % Get file selection options
        selectOptions = GlobalData.Processes.Current(iProcess).options.(optName).Value;
        if (length(selectOptions) == 9)
            DialogType      = selectOptions{3};
            WindowTitle     = selectOptions{4};
            DefaultOutFile  = selectOptions{5};
            SelectionMode   = selectOptions{6};
            FilesOrDir      = selectOptions{7};
            Filters         = selectOptions{8};
            DefaultFormat   = selectOptions{9};
            if isfield(DefaultFormats, DefaultFormat) && isempty(selectOptions{2})
                defaultFilter = DefaultFormats.(DefaultFormat);
            else
                defaultFilter = selectOptions{2};
            end
        else
            DialogType       = 'save';
            WindowTitle      = 'Export file';
            DefaultOutFile   = '';
            SelectionMode    = 'single';
            FilesOrDir       = 'files';
            Filters          = {{'*'}, 'All files (*.*)', 'ALL'};
            defaultFilter    = [];
        end

        % First input file
        inBstFile = selectOptions{1};
        % Filters and extension according to file type
        fileType = file_gettype(inBstFile);
        if strcmp(fileType, 'data') && ~isempty(strfind(inBstFile, '_0raw'))
            fileType = 'raw';
        end
        if isempty(Filters)
            Filters = bst_get('FileFilters', [fileType, 'out']);
        end
        % Select only Filter if not provided
        if isempty(defaultFilter)
            switch fileType
                case 'raw'
                    defaultFilter = 'BST-BIN';
                case {'data', 'results', 'timefreq', 'matrix'}
                    defaultFilter = 'BST';
            end
        end
        % Get extension for filter
        iFilter = find(ismember(Filters(:,3), defaultFilter), 1, 'first');
        if isempty(iFilter)
            iFilter = 1;
        end
        fExt = Filters{iFilter, 1}{1};
        % Verify that extension for BST format ends in '.ext' (no 'BST' format for raw data)
        if strcmp(defaultFilter, 'BST') && isempty(regexp('at', '\.\w*$', 'once')) && ~(strcmp(fileType, 'data') && isRaw)
            fExt = [fExt, '.mat'];
        end

        % Suggest filename or dir
        switch FilesOrDir
            % Suggest filename
            case 'files'
                switch(fileType)
                    case 'data'
                        [~, fBase] = bst_fileparts(inBstFile);
                        fBase = strrep(fBase, '_data', '');
                        fBase = strrep(fBase, 'data_', '');
                        fBase = strrep(fBase, '0raw_', '');
    
                    case {'results', 'link'}
                        if strcmp(fileType, 'link')
                            [kernelFile, dataFile] = file_resolve_link(inBstFile);
                            [~, kBase] = bst_fileparts(kernelFile);
                            [~, fBase] = bst_fileparts(dataFile);
                            fBase = [kBase, '_' ,fBase];
                        else
                            [~, fBase] = bst_fileparts(inBstFile);
                        end
                        fBase = strrep(fBase, '_results', '');
                        fBase = strrep(fBase, 'results_', '');
    
                    case 'timefreq'
                        [~, fBase] = bst_fileparts(inBstFile);
                        fBase = strrep(fBase, '_timefreq', '');
                        fBase = strrep(fBase, 'timefreq_', '');
    
                    case 'matrix'
                        [~, fBase] = bst_fileparts(inBstFile);
                        fBase = strrep(fBase, '_matrix', '');
                        fBase = strrep(fBase, 'matrix_', '');
    
                    otherwise
                        % e.g., user set outfile more than once
                        [~, fBase] = bst_fileparts(inBstFile);
    
                end                
                DefaultOutFile = bst_fullfile(LastUsedDirs.ExportData, [fBase, fExt]);

            % Suggest directory
            case 'dirs'
                DefaultOutFile = bst_fullfile(LastUsedDirs.ExportData);
        end

        % Pick a file
        [OutputFile, FileFormat] = java_getfile(DialogType, WindowTitle, DefaultOutFile, SelectionMode, FilesOrDir, Filters, defaultFilter);
        % If nothing selected
        if isempty(OutputFile)
            return
        end
        % Update ExportData path
        if strcmp(FilesOrDir, 'dirs')
            % Remove extension (introduced by the Filters)
            [fPath, fBase] = bst_fileparts(OutputFile);
            OutputFile = bst_fullfile(fPath, fBase);
            LastUsedDirs.ExportData = OutputFile;
        elseif strcmp(FilesOrDir, 'files')
            fPath = bst_fileparts(OutputFile);
            LastUsedDirs.ExportData = fPath;
        end
        bst_set('LastUsedDirs', LastUsedDirs);

        % Update the values
        selectOptions{1} = OutputFile;
        selectOptions{2} = FileFormat;
        % Save the new values
        SetOptionValue(iProcess, optName, selectOptions);
        % Update the text field
        jText.setText(OutputFile);
    end


    %% ===== OPTIONS: EDIT PROPERTIES CALLBACK =====
    function EditProperties_Callback(iProcess, optName)
        % Get current value: {@panel, sOptions}
        sCurProcess = GlobalData.Processes.Current(iProcess);
        fcnPanel = sCurProcess.options.(optName).Comment{1};
        % Hide pipeline editor
        jDialog = jPanelProcess.getTopLevelAncestor();
        jDialog.setAlwaysOnTop(0);
        jDialog.setVisible(0);
        drawnow;
        % Display options dialog window
        value = bst_call(@gui_show_dialog, sCurProcess.Comment, fcnPanel, 1, [], sCurProcess, sFiles);
        drawnow;
        % Restore pipeline editor
        jDialog.setVisible(1);
        jDialog.setAlwaysOnTop(1);
        drawnow;
        
        % Editing was cancelled
        if isempty(value)
            return
        end
        % Save the new values
        SetOptionValue(iProcess, optName, value);
    end

    %% ===== OPTIONS: RADIO CALLBACK =====
    function OptionRadio_Callback(iProcess, optName, iRadio, isSelected)
        if isSelected
            SetOptionValue(iProcess, optName, iRadio);
        end
    end

    %% ===== OPTIONS: GET CLUSTER LIST =====
    function jList = GetClusterList(sProcess, optName)
        import org.brainstorm.list.*;
        % Initialize returned values
        jList = [];

        % Get the current channel file
        if isfield(sProcess.options.(optName), 'InputTypesB') && ~isempty(sFiles2)
            ChannelFile = sFiles2(1).ChannelFile;
        else
            ChannelFile = sFiles(1).ChannelFile;
        end
        if isempty(ChannelFile)
            return;
        end
        % Load clusters from channel file
        ChannelMat = in_bst_channel(ChannelFile, 'Clusters');
        if isempty(ChannelMat.Clusters)
            return;
        end

        % Get all clusters labels
        allLabels = {ChannelMat.Clusters.Label};
        % Create a list mode of the existing clusters/scouts
        listModel = javax.swing.DefaultListModel();
        for iClust = 1:length(ChannelMat.Clusters)
            listModel.addElement(BstListItem(ChannelMat.Clusters(iClust).Label, '', [' ' allLabels{iClust} ' '], iClust));
        end

        % Create list
        jList = java_create('javax.swing.JList');
        jList.setModel(listModel);
        jList.setLayoutOrientation(jList.HORIZONTAL_WRAP);
        jList.setVisibleRowCount(-1);
        jList.setCellRenderer(BstStringListRenderer(fontSize));
    end


    %% ===== OPTIONS: CLUSTER CALLBACK =====
    function Cluster_ValueChangedCallback(iProcess, optName, jList, jCheck, ev)
        % Enable/disable jList
        if ~isempty(jCheck)
            isChecked = jCheck.isSelected();
        else
            isChecked = 1;
        end
        jList.setEnabled(isChecked);
        % If cluster/scout not selected
        if ~isChecked
            SetOptionValue(iProcess, optName, []);
        % If not currently editing
        elseif isempty(ev) || ~ev.getValueIsAdjusting()
            % Get selected clusters
            selObj = jList.getSelectedValues();
            if (length(selObj) == 0)
                strList = [];
            else
                strList = cell(1, length(selObj));
                for iObj = 1:length(selObj)
                    strList{iObj} = char(selObj(iObj).getType());
                end
            end
            % Set value
            SetOptionValue(iProcess, optName, strList);
        end
    end



    %% ===== OPTIONS: GET ATLAS LIST =====
    function [AtlasList, iAtlasList] = GetAtlasList(sProcess, optName)
        import org.brainstorm.list.*;
        % Initialize returned list
        AtlasList = {};
        iAtlasList = [];
        % Get the current file
        if isfield(sProcess.options.(optName), 'InputTypesB') && ~isempty(sFiles2)
            curFile = sFiles2(1);
        else
            curFile = sFiles(1);
        end
        if isempty(curFile)
            return;
        end
        % Get surface file and or atlas (if the file is the result to a "downsample to atlas" process)
        if strcmpi(curFile.FileType, 'results')
            ResultsMat = in_bst_results(curFile.FileName, 0, 'SurfaceFile', 'Atlas');
            SurfaceFile = ResultsMat.SurfaceFile;
            sAtlases = ResultsMat.Atlas;
        elseif strcmpi(curFile.FileType, 'timefreq')
            ResultsMat = in_bst_timefreq(curFile.FileName, 0, 'SurfaceFile', 'Atlas');
            SurfaceFile = ResultsMat.SurfaceFile;
            sAtlases = ResultsMat.Atlas;
        else
            SurfaceFile = [];
            sAtlases = [];
        end
        % If an atlas is not available in the input file, try in the surface
        if isempty(sAtlases)
            % If surface is not defined: Get default cortex for the subject
            if isempty(SurfaceFile)
                sSubject = bst_get('Subject', curFile.SubjectFile);
                if ~isempty(sSubject.iCortex) && (sSubject.iCortex <= length(sSubject.Surface))
                    SurfaceFile = sSubject.Surface(sSubject.iCortex).FileName;
                end
            end
            % If no surface defined: nothing to do
            if isempty(SurfaceFile)
                return;
            end
            % Read surface file
            SurfaceMat = load(file_fullpath(SurfaceFile), 'Atlas', 'iAtlas');
            if ~isfield(SurfaceMat, 'Atlas') || ~isfield(SurfaceMat, 'iAtlas') || isempty(SurfaceMat.Atlas) || isempty(SurfaceMat.iAtlas) || (SurfaceMat.iAtlas > length(SurfaceMat.Atlas))
                return;
            end
            % Get the available atlases
            sAtlases = SurfaceMat.Atlas;
            SelAtlasName = SurfaceMat.Atlas(SurfaceMat.iAtlas).Name;
        else
            SelAtlasName = [];
        end
        % No atlases available
        if isempty(sAtlases)
            return;
        end
        % Do not accept the atlas "Source model"
        iDelAtlas = find(strcmpi({sAtlases.Name}, 'Source model'));
        if ~isempty(iDelAtlas)
            sAtlases(iDelAtlas) = [];
        end
        if isempty(sAtlases)
            return;
        end
        % Return the names of all the scouts
        AtlasList = cell(length(sAtlases),2);
        for i = 1:length(sAtlases)
            AtlasList{i,1} = sAtlases(i).Name;
            if ~isempty(sAtlases(i).Scouts)
                AtlasList{i,2} = {sAtlases(i).Scouts.Label};
            else
                AtlasList{i,2} = [];
            end
        end
        % Selected atlas
        if ~isempty(SelAtlasName)
        	iAtlasList = find(strcmpi({sAtlases.Name}, SelAtlasName));
            if isempty(iAtlasList)
                iAtlasList = 1;
            elseif (length(iAtlasList) > 1)
                disp('BST> Error: Two atlases have the same name, you should rename one of them.');
                iAtlasList = iAtlasList(1);
            end
        else
            iAtlasList = 1;
        end
    end


    %% ===== OPTIONS: ATLAS SELECTION CALLBACK =====
    function AtlasSelection_Callback(iProcess, optName, AtlasList, jCombo, jList, ev)
        import org.brainstorm.list.*;
        % Skip deselected event
        if ~isempty(ev) && (ev.getStateChange() ~= ev.SELECTED)
            return;
        end
        % Get current process
        sCurProcess = GlobalData.Processes.Current(iProcess);
        % Get current atlas
        iAtlasList = jCombo.getSelectedIndex() + 1;
        if (iAtlasList <= 0)
            return;
        end
        % Get current scouts
        ScoutNames = AtlasList{iAtlasList,2};
        % Temporality disables JList selection callback
        jListCallback_bak = java_getcb(jList, 'ValueChangedCallback');
        java_setcb(jList, 'ValueChangedCallback', []);
        % Create a list of the existing scouts
        listModel = java_create('javax.swing.DefaultListModel');
        for iScout = 1:length(ScoutNames)
            listModel.addElement(BstListItem(ScoutNames{iScout}, '', [' ' ScoutNames{iScout} ' '], iScout));
        end
        jList.setModel(listModel);
        
        % If there are scouts in this model
        if ~isempty(ScoutNames)
            % If there were scouts selected previously: try to use this selection
            iSelScouts = [];
            prevList = sCurProcess.options.(optName).Value;
            if ~isempty(prevList) && iscell(prevList) && (size(prevList,2) >= 2) && ~isempty(prevList{1,2}) && iscell(prevList{1,2}) && ~isempty(ScoutNames)
                % Get names of the previously selected scouts
                prevNames = sCurProcess.options.(optName).Value{1,2};
                % If there are some names available, look for them in the current list
                for i = 1:length(prevNames)
                    iSelScouts = [iSelScouts, find(strcmpi(prevNames{i}, ScoutNames))];
                end
            end
            % If a previous scout selection was not found: select all the scouts
            if isempty(iSelScouts)
                iSelScouts = 1:length(ScoutNames);
            end
            % Select scouts in the list
            jList.setSelectedIndices(iSelScouts - 1);
            % Save the current selection of scouts (to have the correct list of scouts if the user does not change the selection)
            if jList.isEnabled()
                newList = {AtlasList{iAtlasList,1}, ScoutNames(iSelScouts)};
            else
                newList = {};
            end
            SetOptionValue(iProcess, optName, newList);
        end
        % Restore JList callback
        java_setcb(jList, 'ValueChangedCallback', jListCallback_bak);
    end


    %% ===== OPTIONS: SCOUT SELECTION CALLBACK =====
    function ScoutSelection_Callback(iProcess, optName, AtlasList, jCombo, jList, jCheck, ev)
        % Cancel temporary selection
        if ~isempty(ev) && ev.getValueIsAdjusting()
            return;
        end
        % Enable/disable jList and jCombo
        if ~isempty(jCheck)
            isChecked = jCheck.isSelected();
        else
            isChecked = 1;
        end
        jList.setEnabled(isChecked);
        jCombo.setEnabled(isChecked);
        % Get current atlas
        iAtlasList = jCombo.getSelectedIndex() + 1;
        if (iAtlasList <= 0)
            return;
        end
        % If cluster/scout not selected
        if ~isChecked
            SetOptionValue(iProcess, optName, []);
        % If not currently editing
        else
            % Get selected clusters
            iSel = jList.getSelectedIndices() + 1;
            % List of new selected scouts
            newList = AtlasList(iAtlasList,:);
            newList{1,2} = AtlasList{iAtlasList,2}(iSel);
            % Set value
            SetOptionValue(iProcess, optName, newList);
        end
    end


    %% ===== OPTIONS: GET EVENT LIST =====
    function EventList = GetEventList(varargin)
        excludeSpikes = 0;
        onlySpikes = 0;
        if nargin > 0
            if strcmpi(varargin{1}, 'only')
                onlySpikes = 1;
            elseif strcmpi(varargin{1}, 'exclude')
                excludeSpikes = 1;
            end
        end
        
        DataMat = in_bst_data(sFiles(1).FileName, 'F');
        DataEvents = DataMat.F.events;
        EventList = {};
        
        for iEvent = 1:length(DataEvents)
            label = DataEvents(iEvent).label;
            isSpikeEvent = panel_spikes('IsSpikeEvent', label);
            
            if (excludeSpikes && ~isSpikeEvent) || (onlySpikes && isSpikeEvent)
                EventList{end + 1} = label;
            end
        end
    end


    %% ===== OPTIONS: SET OPTION VALUE =====
    function SetOptionValue(iProcess, optName, value)
        % Check for weird effects of events processed in the wrong order
        if (iProcess > length(GlobalData.Processes.Current)) || ~isfield(GlobalData.Processes.Current(iProcess).options, optName)
            return;
        end
        % Update value
        GlobalData.Processes.Current(iProcess).options.(optName).Value = value;
        % Update list
        UpdateProcessesList();
        % Save option value for future uses
        optType = GlobalData.Processes.Current(iProcess).options.(optName).Type;
        if ismember(optType, {'value', 'range', 'freqrange', 'freqrange_static', 'checkbox', 'radio', 'radio_line', 'radio_label', 'radio_linelabel', 'combobox', 'combobox_label', 'text', 'textarea', 'channelname', 'subjectname', 'atlas', 'groupbands', 'montage', 'freqsel', 'scout', 'scout_confirm'}) ...
                || (strcmpi(optType, 'filename') && (length(value)>=7) && strcmpi(value{7},'dirs') && strcmpi(value{3},'save'))
            % Get processing options
            ProcessOptions = bst_get('ProcessOptions');
            % Save option value
            field = [func2str(GlobalData.Processes.Current(iProcess).Function), '__', optName];
            ProcessOptions.SavedParam.(field) = value;
            % Save processing options
            bst_set('ProcessOptions', ProcessOptions);
        end
        % If a class controller, toggle class
        if isfield(GlobalData.Processes.Current(iProcess).options.(optName), 'Controller')
            opt = GlobalData.Processes.Current(iProcess).options.(optName);
            if strcmp(optType, 'checkbox') && ~isempty(opt.Controller)
                ToggleClass(opt.Controller, value);
            elseif ismember(optType, {'radio_label', 'radio_linelabel'}) && ~isempty(opt.Controller) && isstruct(opt.Controller)
                for cl = fieldnames(opt.Controller)'
                    % Ignore a disabled class that is associated with 2 options, one selected and one not selected
                    if ~strcmp(cl{1}, value) && isfield(opt.Controller, value) && isequal(opt.Controller.(cl{1}), opt.Controller.(value))
                        continue
                    end
                    ToggleClass(opt.Controller.(cl{1}), strcmp(cl{1}, value));
                end
            end
        end
    end

    %% ===== TEXT: GET VALUE =====
    function val = GetValue(jText, valUnits)
        % Get and check value
        val = str2num(char(jText.getText()));
        if isempty(val)
            val = [];
        end
        % If units are defined and milliseconds: convert to ms
        if (nargin >= 2) && ~isempty(valUnits)
            if strcmpi(valUnits, 'ms')
                val = val / 1000;
            end
        end
    end


%% =========================================================================
%  ===== LOAD/SAVE FUNCTIONS ===============================================
%  =========================================================================
    %% ===== SAVE PIPELINE =====
    function SavePipeline(iPipe)
        % Create new pipeline
        if (nargin < 1) || isempty(iPipe)
            % Ask user the name for the new pipeline
            newName = java_dialog('input', 'Enter a name for the new pipeline:', 'Save pipeline');
            if isempty(newName)
                return;
            end
            % Check if pipeline already exists
            if ~isempty(GlobalData.Processes.Pipelines) && any(strcmpi({GlobalData.Processes.Pipelines.Name}, newName))
                bst_error('This pipeline name already exists.', 'Save pipeline', 0);
                return
            end
            % Create new structure
            newPipeline.Name = newName;
            newPipeline.Processes = GlobalData.Processes.Current;
            % Add to list
            if isempty(GlobalData.Processes.Pipelines)
                GlobalData.Processes.Pipelines = newPipeline;
            else
                GlobalData.Processes.Pipelines(end+1) = newPipeline;
            end
        % Update existing pipeline
        else
            % Ask for confirmation
            isConfirm = java_dialog('confirm', ['Overwrite pipeline "' GlobalData.Processes.Pipelines(iPipe).Name '"?'], 'Save pipeline');
            % Overwrite existing entry
            if isConfirm
                GlobalData.Processes.Pipelines(iPipe).Processes = GlobalData.Processes.Current;
            end
        end
    end


    %% ===== EXPORT PIPELINE =====
    function ExportPipeline()
        % USING FILE_SELECT BECAUSE OF WEIRD CRASHES WITH COMBINATION OF TF OPTIONS AND JAVA_GETFILE
        OutputFile = file_select('save', 'Save pipeline', 'pipeline_new.mat', {'*.mat', 'Brainstorm processing pipelines (pipeline*.mat)'});
        if isempty(OutputFile)
            return;
        end
        % Create new structure
        s.Processes = GlobalData.Processes.Current;
        % Save new pipeline
        bst_save(OutputFile, s, 'v7');
    end


    %% ===== SHOW PIPELINE LOAD MENU =====
    function ShowPipelineMenu(jButton)
        import org.brainstorm.icon.*;
        % Create popup menu
        jPopup = java_create('javax.swing.JPopupMenu');
        % === LOAD PIPELINE ===
        % Load pipeline
        jMenuLoad = gui_component('Menu', jPopup, [], 'Load', IconLoader.ICON_FOLDER_OPEN, [], []);
        % List all the pipelines
        for iPipe = 1:length(GlobalData.Processes.Pipelines)
            gui_component('MenuItem', jMenuLoad, [], GlobalData.Processes.Pipelines(iPipe).Name, IconLoader.ICON_CONDITION, [], @(h,ev)LoadPipeline(iPipe));
        end
        % Load from file
        gui_component('MenuItem', jPopup, [], 'Load from .mat file', IconLoader.ICON_FOLDER_OPEN, [], @(h,ev)LoadPipelineFromFile());
        jPopup.addSeparator();
        
        % === SAVE PIPELINE ===
        % If some processes are defined
        if ~isempty(GlobalData.Processes.Current)
            % Save pipeline
            jMenuSave = gui_component('Menu', jPopup, [], 'Save', IconLoader.ICON_SAVE, [], []);
            % List all the pipelines
            for iPipe = 1:length(GlobalData.Processes.Pipelines)
                gui_component('MenuItem', jMenuSave, [], GlobalData.Processes.Pipelines(iPipe).Name, IconLoader.ICON_SAVE, [], @(h,ev)SavePipeline(iPipe));
            end
            % Separator
            if ~isempty(GlobalData.Processes.Pipelines)
                jMenuSave.addSeparator();
            end
            % Save new
            gui_component('MenuItem', jMenuSave, [], 'New...', IconLoader.ICON_SAVE, [], @(h,ev)SavePipeline());
            % Save as
            gui_component('MenuItem', jPopup, [], 'Save as .mat file', IconLoader.ICON_MATLAB, [], @(h,ev)ExportPipeline());
            jPopup.addSeparator();
            % Generate script
            gui_component('MenuItem', jPopup, [], 'Generate .m script', IconLoader.ICON_MATLAB, [], @(h,ev)GenerateMatlabScript(1));
            jPopup.addSeparator();
        end
        
        % === DELETE PIPELINE ===
        jMenuDel = gui_component('Menu', jPopup, [], 'Delete', IconLoader.ICON_DELETE, [], []);
        % List all the pipelines
        for iPipe = 1:length(GlobalData.Processes.Pipelines)
            gui_component('MenuItem', jMenuDel, [], GlobalData.Processes.Pipelines(iPipe).Name, IconLoader.ICON_CONDITION, [], @(h,ev)DeletePipeline(iPipe));
        end
        
        % === RESET OPTIONS ===
        jPopup.addSeparator();
        gui_component('MenuItem', jPopup, [], 'Reset options', IconLoader.ICON_RELOAD, [], @(h,ev)ResetOptions);
        
        % Show popup menu
        jPopup.show(jButton, 0, jButton.getHeight());
    end


    %% ===== LOAD PIPELINE =====
    function LoadPipeline(iPipeline)
        bst_progress('start', 'Load pipeline', 'Loading...');
        % Select first item in the pipeline
        if ~isempty(GlobalData.Processes.Current)
            jListProcess.setSelectedIndex(0);
        end
        % Replace existing list with saved list
        GlobalData.Processes.Current = GlobalData.Processes.Pipelines(iPipeline).Processes;
        % Load file time is possible
        TimeVector = FindRawFileTime(GlobalData.Processes.Current);
        if ~isempty(TimeVector)
            FileTimeVector = TimeVector;
        end
        % Update pipeline
        UpdatePipeline();
        bst_progress('stop');
    end


    %% ===== DELETE PIPELINE =====
    function DeletePipeline(iPipeline)
        % Ask confirmation
        if ~java_dialog('confirm', ['Delete pipeline "' GlobalData.Processes.Pipelines(iPipeline).Name '"?'], 'Processing pipeline');
            return;
        end    
        % Select first item in the pipeline
        GlobalData.Processes.Pipelines(iPipeline) = [];
        % Replace existing list with saved list
        GlobalData.Processes.Current = [];
        % Update pipeline
        UpdatePipeline();
    end


    %% ===== LOAD PIPELINE FROM FILE =====
    function LoadPipelineFromFile()
        % USING FILE_SELECT BECAUSE OF WEIRD CRASHES WITH COMBINATION OF TF OPTIONS AND JAVA_GETFILE
        PipelineFile = file_select('open', 'Import processing pipeline', '', {'*.mat', 'Brainstorm processing pipelines (pipeline*.mat)'});
        if isempty(PipelineFile)
            return;
        end
        % Load pipeline file
        newMat = load(PipelineFile);
        if ~isfield(newMat, 'Processes') || isempty(newMat.Processes)
            error('Invalid pipeline file.');
        end
        % Ask user the name for the new pipeline
        newName = java_dialog('input', 'Enter a name for the new pipeline:', 'Save pipeline');
        if isempty(newName)
            return;
        end
        % Check if pipeline already exists
        if ~isempty(GlobalData.Processes.Pipelines) && any(strcmpi({GlobalData.Processes.Pipelines.Name}, newName))
            bst_error('This pipeline name already exists.', 'Save pipeline', 0);
            return
        end
        % Create new structure
        newPipeline.Name = newName;
        newPipeline.Processes = newMat.Processes;
        % Add to list
        if isempty(GlobalData.Processes.Pipelines)
            iPipeline = 1;
            GlobalData.Processes.Pipelines = newPipeline;
        else
            iPipeline = length(GlobalData.Processes.Pipelines) + 1;
            GlobalData.Processes.Pipelines(iPipeline) = newPipeline;
        end
        % Update pipeline
        LoadPipeline(iPipeline);
    end

    
    %% ===== GENERATE MATLAB SCRIPT =====
    function str = GenerateMatlabScript(isSave)
        str = [];
        % Write header
        bstVersion = bst_get('Version');
        str = [str '% Script generated by Brainstorm (' bstVersion.Date ')' 10 10];
        % Write comment
        str = [str '% Input files' 10];
        % Grab all the subject names
        [SubjNames, RawFiles] = GetSeparateInputs(GlobalData.Processes.Current);
        % Write input filenames
        str = [str, WriteFileNames(sFiles,     'sFiles',    1)];
        str = [str, WriteFileNames(sFiles2,    'sFiles2',   0)];
        str = [str, WriteFileNames(SubjNames,  'SubjectNames', 0)];
        str = [str, WriteFileNames(RawFiles,   'RawFiles',     0)];
        str = [str, 10];
        % Reporting
        str = [str '% Start a new report' 10];
        str = [str 'bst_report(''Start'', sFiles);' 10 10];

        % Optimize pipeline
        sExportProc = bst_process('OptimizePipeline', GlobalData.Processes.Current);
        % Loop on each process to apply
        for iProc = 1:length(sExportProc)
            % Get process info
            procComment = sExportProc(iProc).Function('FormatComment', sExportProc(iProc));
            procFunc    = func2str(sExportProc(iProc).Function);
            % Timefreq and Connectivity: make sure the advanced options were selected
            if (ismember(procFunc, {'process_timefreq', 'process_hilbert', 'process_psd'}) && ...
                                    (~isfield(sExportProc(iProc).options.edit, 'Value') || isempty(sExportProc(iProc).options.edit.Value))) || ... % check 'edit' field
               (ismember(procFunc, {'process_henv1', 'process_henv1n', 'process_henv2', ...
                                   'process_cohere1', 'process_cohere1n', 'process_cohere2', ...
                                   'process_plv1', 'process_plv1n', 'process_plv2'}) && ...
                                    (~isfield(sExportProc(iProc).options.tfedit, 'Value') || isempty(sExportProc(iProc).options.tfedit.Value)))    % check 'tfedit' field
                bst_error('Please check the advanced options of the process before generating the script.', 'Generate script', 0);
                return;
            end
            % Process comment
            str = [str '% Process: ' procComment 10];
            strIdent    = '    ';
            % Process call
            if (sExportProc(iProc).nOutputs == 2)
                str = [str '[sFiles, sFiles2] = bst_process(''CallProcess'', ''' procFunc ''', '];
            else
                str = [str 'sFiles = bst_process(''CallProcess'', ''' procFunc ''', '];
            end
            % Print filenames
            if ~isempty(sFiles2) && (sExportProc(iProc).nInputs == 2)
                str = [str 'sFiles, sFiles2'];
            else
                str = [str 'sFiles, []'];
            end
            strComment = '';
            % Options
            if isstruct(sExportProc(iProc).options)
                % Get the names of all the options for this process
                optNames = fieldnames(sExportProc(iProc).options);
                % Get the maximum length of the options names
                if ~isempty(optNames)
                    maxLength = max(cellfun(@length, optNames));
                else
                    maxLength = 0;
                end
                % Remove unused options structures for specific processes (optional, only to make the script more compact)
                if strcmp(procFunc, 'process_headmodel')
                    iDuneuro = find(strcmpi(optNames, 'duneuro'));
                    if ~isempty(iDuneuro) ...
                        && (~ismember('meg', optNames) || isempty(strfind(lower(sExportProc(iProc).options.meg.Value{2}{sExportProc(iProc).options.meg.Value{1}}), 'duneuro'))) ...
                        && (~ismember('eeg', optNames) || isempty(strfind(lower(sExportProc(iProc).options.eeg.Value{2}{sExportProc(iProc).options.eeg.Value{1}}), 'duneuro'))) ...
                        && (~ismember('seeg', optNames) || isempty(strfind(lower(sExportProc(iProc).options.seeg.Value{2}{sExportProc(iProc).options.seeg.Value{1}}), 'duneuro'))) ...
                        && (~ismember('ecog', optNames) || isempty(strfind(lower(sExportProc(iProc).options.ecog.Value{2}{sExportProc(iProc).options.ecog.Value{1}}), 'duneuro')))
                        optNames(iDuneuro) = [];
                    end
                    iOpenmeeg = find(strcmpi(optNames, 'openmeeg'));
                    if ~isempty(iOpenmeeg) ...
                        && (~ismember('meg', optNames) || isempty(strfind(lower(sExportProc(iProc).options.meg.Value{2}{sExportProc(iProc).options.meg.Value{1}}), 'openmeeg'))) ...
                        && (~ismember('eeg', optNames) || isempty(strfind(lower(sExportProc(iProc).options.eeg.Value{2}{sExportProc(iProc).options.eeg.Value{1}}), 'openmeeg'))) ...
                        && (~ismember('seeg', optNames) || isempty(strfind(lower(sExportProc(iProc).options.seeg.Value{2}{sExportProc(iProc).options.seeg.Value{1}}), 'openmeeg'))) ...
                        && (~ismember('ecog', optNames) || isempty(strfind(lower(sExportProc(iProc).options.ecog.Value{2}{sExportProc(iProc).options.ecog.Value{1}}), 'openmeeg')))
                        optNames(iOpenmeeg) = [];
                    end
                    iVolumegrid = find(strcmpi(optNames, 'volumegrid'));
                    if ~isempty(iVolumegrid) && ismember('sourcespace', optNames) && (sExportProc(iProc).options.sourcespace.Value ~= 2)
                        optNames(iVolumegrid) = [];
                    end
                end
                % Print each option on a separate line
                for iOpt = 1:length(optNames)
                    opt = sExportProc(iProc).options.(optNames{iOpt});
                    % Skip 'button' options
                    if isfield(opt, 'Type') && strcmpi(opt.Type, 'button')
                        continue;
                    end
                    % Writing a line for the option
                    if isfield(opt, 'Value')
                        % For some options types: write only the value, not the selection parameters
                        if isfield(opt, 'Type') && ismember(opt.Type, {'timewindow','baseline','poststim','value','range','freqrange','freqrange_static','combobox','combobox_label'}) && iscell(opt.Value)
                            optValue = opt.Value{1};
                        elseif isfield(opt, 'Type') && ismember(opt.Type, {'filename','datafile'}) && iscell(opt.Value)
                            optValue = opt.Value(1:2);
                        elseif isfield(opt, 'Type') && ismember(opt.Type, {'cluster', 'cluster_confirm', 'scout', 'scout_confirm'}) && isstruct(opt.Value) && isfield(opt.Value, 'Handles')
                            optValue = rmfield(opt.Value, 'Handles');
                        % Time-freq: If the additional options are not defined, get them
                        elseif isfield(opt, 'Type') && strcmpi(opt.Type, 'editpref') && isempty(opt.Value)
                            switch (procFunc)
                                case 'process_timefreq',    optValue = bst_get('TimefreqOptions_morlet');
                                case 'process_hilbert',     optValue = bst_get('TimefreqOptions_hilbert');
                                case 'process_psd',         optValue = bst_get('TimefreqOptions_psd');
                                case 'process_headmodel',   optValue = bst_get('GridOptions_headmodel');
                                case 'process_export_bids', optValue = bst_get('ExportBidsOptions');
                            end
                        else
                            optValue = opt.Value;
                        end
                        % For string, replace ' with ''
                        if ischar(optValue) && ~isempty(optValue)
                            optValue = strrep(optValue, '''', '''''');
                        end
                        % Pad with spaces after the option name so that all the values line up nicely
                        strPad = repmat(' ', 1, maxLength - length(optNames{iOpt}));
                        % Create final string
                        optStr = [', ...' strComment, 10 strIdent '''' optNames{iOpt} ''', ' strPad str_format(optValue, 1, 2)];
                        % Replace raw filenames and subject names
                        if isfield(opt, 'Type') && ismember(opt.Type, {'filename','datafile'}) && iscell(opt.Value) && ~isempty(RawFiles)
                            % List of files
                            if iscell(optValue{1})
                                for ic = 1:length(optValue{1})
                                    iFile = find(strcmpi(RawFiles, optValue{1}{ic}));
                                    optStr = strrep(optStr, ['''' optValue{1}{ic} ''''], ['RawFiles{' num2str(iFile) '}']);  
                                end
                            % Single file
                            else
                                iFile = find(strcmpi(RawFiles, optValue{1}));
                                if ~isempty(iFile)
                                    optStr = strrep(optStr, ['''' optValue{1} ''''], ['RawFiles{' num2str(iFile) '}']);
                                end
                            end
                        elseif isfield(opt, 'Type') && strcmpi(opt.Type, 'subjectname')
                            iFile = find(strcmpi(SubjNames, optValue));
                            if ~isempty(iFile)
                                optStr = strrep(optStr, ['''' optValue ''''], ['SubjectNames{' num2str(iFile) '}']);
                            end
                        end
                        % Add option to complete text
                        str = [str, optStr];
                        % Add comment for some options types
                        if isfield(opt, 'Type') && isfield(opt, 'Comment') && ismember(opt.Type, {'radio','radio_line'})
                            strComment = ['  % ' str_striptag(opt.Comment{1,opt.Value})];
                        elseif isfield(opt, 'Type') && isfield(opt, 'Comment') && ismember(opt.Type, {'radio_label','radio_linelabel'})
                            iVal = find(strcmpi(opt.Value, opt.Comment(2,:)));
                            if ~isempty(iVal)
                                strComment = ['  % ' str_striptag(opt.Comment{1,iVal})];
                            end
                        elseif isfield(opt, 'Type') && strcmpi(opt.Type, 'combobox')
                            strComment = ['  % ' str_striptag(opt.Value{2}{opt.Value{1}})];
                        elseif isfield(opt, 'Type') && strcmpi(opt.Type, 'combobox_label')
                            iCombo = find(strcmpi(opt.Value{1}, opt.Value{2}(2,:)));
                            if ~isempty(iCombo)
                                strComment = ['  % ' str_striptag(opt.Value{2}{1,iCombo})];
                            else
                                strComment = '';
                            end
                        else
                            strComment = '';
                        end
                    else
                        % strComment = '';
                    end
                end
            end
            str = [str ');' strComment 10 10];
        end
        % Show report
        str = [str '% Save and display report' 10];
        str = [str 'ReportFile = bst_report(''Save'', sFiles);' 10];
        str = [str 'bst_report(''Open'', ReportFile);' 10];
        str = [str '% bst_report(''Export'', ReportFile, ExportDir);' 10];
        str = [str '% bst_report(''Email'', ReportFile, username, to, subject, isFullReport);' 10 10];
        str = [str '% Delete temporary files' 10];
        str = [str '% gui_brainstorm(''EmptyTempFolder'');' 10 10];

        % Save script
        if isSave
            % Get default folders
            LastUsedDirs = bst_get('LastUsedDirs');
            if isempty(LastUsedDirs.ExportScript)
                LastUsedDirs.ExportScript = bst_get('UserDir');
            end
            DefaultOutputFile = bst_fullfile(LastUsedDirs.ExportScript, 'script_new.m');
            % Get file to create
            % USING FILE_SELECT BECAUSE OF WEIRD CRASHES WITH COMBINATION OF TF OPTIONS AND JAVA_GETFILE
            ScriptFile = file_select('save', 'Generate Matlab script', DefaultOutputFile, {'*.m', 'Matlab script (*.m)'});
            if isempty(ScriptFile)
                return;
            end
            
            % Save new default export path
            LastUsedDirs.ExportScript = bst_fileparts(ScriptFile);
            bst_set('LastUsedDirs', LastUsedDirs);
            % Open file
            fid = fopen(ScriptFile, 'wt');
            if (fid == -1)
                error('Cannot open file.');
            end
            % Write file
            fwrite(fid, str);
            % Close file
            fclose(fid);
            % Open in editor
            try
                edit(ScriptFile);
            catch
            end
        % View script
        else
            view_text(str, 'Generated Matlab script');
        end
    end


    %% ===== RESET OPTIONS =====
    function ResetOptions()
        % Reset all the saved options
        bst_set('ProcessOptions', []);
        % Empty list of selected processes
        GlobalData.Processes.Current = [];
        % Update pipeline
        UpdatePipeline();
    end

    %% ===== TOGGLE CLASS PANELS =====
    function ToggleClass(className, enable)
        options = [jPanelInput.getComponents(), jPanelOptions.getComponents(), jPanelOutput.getComponents()];
        for iOption = 1:length(options)
            optName = options(iOption).getName();
            if ~isempty(optName) && strcmpi(optName, className)
                ToggleJPanel(options(iOption), enable);
            end
        end
    end
end


%% =========================================================================
%  ===== EXTERNAL FUNCTION =================================================
%  =========================================================================
%% ===== GET PANEL CONTENTS =====
function sProcesses = GetPanelContents()
    % Get edited processes in global variable
    global GlobalData;
    sProcesses = GlobalData.Processes.Current;
    % Empty global variable
    GlobalData.Processes.Current = [];
    % Loop through the processes, and convert back some options
    for iProc = 1:length(sProcesses)
        % Absolute values of sources
        if isfield(sProcesses(iProc).options, 'source_abs')
            sProcesses(iProc).isSourceAbsolute = sProcesses(iProc).options.source_abs.Value;
        elseif (sProcesses(iProc).isSourceAbsolute < 0)
            sProcesses(iProc).isSourceAbsolute = 0;
        elseif (sProcesses(iProc).isSourceAbsolute > 1)
            sProcesses(iProc).isSourceAbsolute = 1;
        end
    end
end

%% ===== PARSE PROCESS FOLDER =====
function ParseProcessFolder(isForced) %#ok<DEFNU>
    global GlobalData;
    % Parse inputs
    if (nargin < 1) || isempty(isForced)
        isForced = 0;
    end
    
    % ===== LIST PROCESS FILES =====
    % Get the contents of sub-folder "functions"
    bstList = dir(bst_fullfile(bst_fileparts(mfilename('fullpath')), 'functions', 'process_*.m'));
    bstFunc = {bstList.name};
    
    % Get the contents of user's custom processes ($HOME/.brainstorm/process)
    usrList = dir(bst_fullfile(bst_get('UserProcessDir'), 'process_*.m'));
    usrFunc = {usrList.name};
    % Display warning for overridden processes
    override = intersect(usrFunc, bstFunc);
    for i = 1:length(override)
        disp(['BST> ' override{i} ' overridden by user (' bst_get('UserProcessDir') ')']);
    end
    % Add user processes to list of processes
    if ~isempty(usrFunc)
        bstFunc = union(usrFunc, bstFunc);
    end
    
    % Get processes from installed (a supported) plugins ($HOME/.brainstorm/plugins/*)
    plugFunc = {};
    plugList = [];
    PlugSupported = bst_plugin('GetSupported');
    PlugInstalled = bst_plugin('GetInstalled');
    [~, iPlug] = intersect({PlugInstalled.Name}, {PlugSupported.Name});
    PlugAll = PlugInstalled(iPlug);
    for iPlug = 1:length(PlugAll)
        if ~isempty(PlugAll(iPlug).Processes)
            % Keep only the processes with function names that are not already defined in Brainstorm
            iOk = [];
            for iProc = 1:length(PlugAll(iPlug).Processes)
                [tmp, procFileName, procExt] = bst_fileparts(PlugAll(iPlug).Processes{iProc});
                if ~ismember([procFileName, procExt], bstFunc)
                    iOk = [iOk, iProc];
                else
                    % disp(['BST> Plugin ' PlugAll(iPlug).Name ': ' procFileName procExt ' already defined in Brainstorm']);
                end
            end
            % Concatenate plugin path and process function (relative to plugin path)
            procFullPath = cellfun(@(c)bst_fullfile(PlugAll(iPlug).Path, c), PlugAll(iPlug).Processes(iOk), 'UniformOutput', 0);
            plugFunc = cat(2, plugFunc, procFullPath);
        end
    end
    % Add plugin processes to list of processes
    if ~isempty(plugFunc)
        iFunc    = cellfun(@(x)exist(x,'file') > 0 , plugFunc);
        plugList = cellfun(@dir, plugFunc(iFunc));
        bstFunc  = union(plugFunc, bstFunc);
    end

    % ===== CHECK FOR MODIFICATIONS =====
    % Build a signature for both folders
    sig = '';
    for i = 1:length(bstList)
        sig = [sig, bstList(i).name, bstList(i).date, num2str(bstList(i).bytes)];
    end
    for i = 1:length(usrList)
        sig = [sig, usrList(i).name, usrList(i).date, num2str(usrList(i).bytes)];
    end
    for i = 1:length(plugList)
        sig = [sig, plugList(i).name, plugList(i).date, num2str(plugList(i).bytes)];
    end
    % If signature is same as previously: do not reload all the files
    if ~isForced
        if isequal(sig, GlobalData.Processes.Signature)
            return;
        else
            disp('BST> Processes functions were modified: Reloading...'); 
        end
    end
    % Save current folder signature
    GlobalData.Processes.Signature = sig;
    
    % ===== GET PROCESSES DESCRIPTION =====
    % Returned variable
    defProcess = db_template('ProcessDesc');
    sProcesses = repmat(defProcess, 0);
    matlabPath = [];
    % Get description for each file
    for iFile = 1:length(bstFunc)
        % Skip python support functions
        if (length(bstFunc{iFile}) > 5) && strcmp(bstFunc{iFile}(end-4:end), '_py.m')
            continue;
        end
        % Split function names: regular process=only function name; plugin process=full path
        [fPath, fName, fExt] = bst_fileparts(bstFunc{iFile});
        % Switch folder if needed
        isChangeDir = 0;
        if ~isempty(fPath)
            if ~isdir(fPath)
                continue;
            end
            if isempty(matlabPath)
                matlabPath = str_split(path, pathsep);
            end
            if ~ismember(fPath, matlabPath)
                curDir = pwd;
                cd(fPath);
                isChangeDir = 1;
            end
        end
        % Get function handle
        Function = str2func(fName);
        % Restore previous dir
        if isChangeDir
            cd(curDir);
        end
        % Call description function
        try
            desc = Function('GetDescription');
        catch
            if ismember(bstFunc{iFile}, usrFunc)
                processType = 'User';
            elseif ismember(bstFunc{iFile}, {bstList.name})
                processType = 'Brainstorm';
            elseif ismember(bstFunc{iFile}, plugFunc)
                processType = 'Plug-in';
            else
                processType = char(8); % backspace
            end
            disp(['BST> Invalid ' processType ' function: "' bstFunc{iFile} '"']);
            continue;
        end
        % Copy fields to returned structure
        iProc = length(sProcesses) + 1;
        sProcesses(iProc) = defProcess;
        sProcesses(iProc) = struct_copy_fields(sProcesses(iProc), desc);
        sProcesses(iProc).Function = Function;
        
        % === ADD CATEGORY OPTIONS ===
        switch (sProcesses(iProc).Category)
            case 'Filter'
                if ~isfield(sProcesses(iProc).options, 'overwrite')
                    sProcesses(iProc).options.overwrite.Comment    = 'Overwrite input files';
                    sProcesses(iProc).options.overwrite.Type       = 'checkbox';
                    sProcesses(iProc).options.overwrite.Value      = 0;
                    sProcesses(iProc).options.overwrite.InputTypes = {'data', 'results', 'timefreq', 'matrix'};
                    sProcesses(iProc).options.overwrite.Group      = 'output';
                end
        end
    end
    % Order processes with the Index value
    [tmp__, iSort] = sort([sProcesses.Index]);
    sProcesses = sProcesses(iSort);
    % Save in global structure
    GlobalData.Processes.All = sProcesses;
    % Clear menu cache
    GlobalData.Program.ProcessMenuCache = struct();
end


%% ===== LOAD EXTERNAL PROCESS =====
function sProcess = LoadExternalProcess(FunctionName)
    sProcess = [];
    % Check that the function exists in path
    if ~exist(FunctionName, 'file')
        return;
    end
    % Get function handle
    Function = str2func(FunctionName);
    % Call description function
    try
        desc = Function('GetDescription');
    catch
        disp(['BST> Invalid plug-in function: "' FunctionName '"']);
        return;
    end
    % Returned process structure
    sProcess = db_template('ProcessDesc');
    sProcess = struct_copy_fields(sProcess, desc);
    sProcess.Function = Function;
end
    

%% ===== SET DEFAULT OPTIONS =====
function sProcesses = SetDefaultOptions(sProcesses, FileTimeVector, UseDefaults)
    % Parse inputs 
    if (nargin < 3) || isempty(UseDefaults)
        UseDefaults = 1;
    end
    if (nargin < 2) || isempty(FileTimeVector)
        FileTimeVector = [];
    end
    % Get processing options
    ProcessOptions = bst_get('ProcessOptions');
    % For each process
    for iProcess = 1:length(sProcesses)
        % No options: next process
        if isempty(sProcesses(iProcess).options)
            continue;
        end
        % Get all the options
        optNames = fieldnames(sProcesses(iProcess).options);
        % Add list of options
        for iOpt = 1:length(optNames)
            % Get option
            option = sProcesses(iProcess).options.(optNames{iOpt});
            % Do not add default values to Hidden options
            if isfield(option, 'Hidden') && isequal(option.Hidden, 1)
                continue;
            end
            % Check for option integrity
            if ~isfield(option, 'Type') || ~isfield(option, 'Comment') || ~isfield(option, 'Value')
                if ~isfield(option, 'Type') || (~strcmpi(option.Type, 'label') && ~strcmpi(option.Type, 'separator'))
                    disp(['BST> ' func2str(sProcesses(iProcess).Function) ': Invalid option "' optNames{iOpt} '"']);
                end
                continue;
            end
            % Option type
            switch (option.Type)
                case {'timewindow', 'baseline', 'poststim'}
                    if ~isempty(FileTimeVector)
                        % Define initial values
                        if strcmpi(option.Type, 'baseline') && (FileTimeVector(1) < 0) && (FileTimeVector(end) > 0)
                            iStart = 1;
                            iEnd = bst_closest(0, FileTimeVector);
                            if (iEnd > 1)
                                iEnd = iEnd - 1;
                            end
                        elseif strcmpi(option.Type, 'poststim') && (FileTimeVector(1) < 0) && (FileTimeVector(end) > 0)
                            iStart = bst_closest(0, FileTimeVector);
                            iEnd   = length(FileTimeVector);
                        elseif strcmpi(option.Type, 'timewindow') 
                            iStart = 1;
                            iEnd   = length(FileTimeVector);
                        else
                            iStart = 1;
                            iEnd   = length(FileTimeVector);
                        end
                        % Final option
                        option.Value = {[FileTimeVector(iStart), FileTimeVector(iEnd)], 'time', []};
                    end
                case 'freqrange'  % But do not reset 'freqrange_static'
                    if iscell(option.Value) && (length(option.Value) >= 3) && ~isempty(option.Value{3})
                        precision = option.Value{3};
                    else
                        precision = [];
                    end
                    option.Value = {[], 'Hz', precision};
            end
            % Override with previously defined values
            if UseDefaults
                % Define field name: process__option
                field = [func2str(sProcesses(iProcess).Function), '__', optNames{iOpt}];
                % If this field was saved in the user preferences, and if is of the correct type
                if isfield(ProcessOptions.SavedParam, field) && strcmpi(class(ProcessOptions.SavedParam.(field)), class(option.Value))
                    savedOpt = ProcessOptions.SavedParam.(field);
                    % Radio button: check the index of the selection
                    if ismember(option.Type, {'radio','radio_line'}) && (savedOpt > length(option.Comment))
                        % Error: ignoring previous option
                    elseif strcmpi(option.Type, 'radio_label') && ~ismember(savedOpt, option.Comment(2,:))
                        % Error: ignoring previous option
                    elseif strcmpi(option.Type, 'radio_linelabel') && ~ismember(savedOpt, option.Comment(2,1:end-1))
                        % Error: ignoring previous option
                    % Combobox: check the format
                    elseif strcmpi(option.Type, 'combobox_label') && ((length(savedOpt) ~= 2) || ~ischar(savedOpt{1}) || (size(savedOpt{2},1) ~= 2) || ~ismember(savedOpt{1}, option.Value{2}(2,:)))
                        % Error: ignoring previous option
                    % Value: restore the 'time' units, if it was updated
                    elseif strcmpi(option.Type, 'value') && iscell(option.Value) && strcmpi(option.Value{2}, 'time')
                        option.Value = savedOpt;
                        option.Value{2} = 'time';
                    % Else: use the saved option
                    else
                        option.Value = savedOpt;
                    end
                end
            end
            % Update option
            sProcesses(iProcess).options.(optNames{iOpt}) = option;
        end
    end
end


%% ===== GET PROCESS =====
% USAGE:  sProcesses = panel_process_select('GetProcess')
%           sProcess = panel_process_select('GetProcess', ProcessName)
function sProcess = GetProcess(ProcessName)
    global GlobalData;
    % Parse inputs
    if (nargin == 0)
        ProcessName = [];
    end
    % Brainstorm is not started
    if isempty(GlobalData) || isempty(GlobalData.Processes) || isempty(GlobalData.Processes.All)
        sProcess = [];
        return;
    end 
    % Get selected process
    if isempty(ProcessName)
        sProcess = GlobalData.Processes.All;
    else
        iProc = [];
        % Look for process name
        for i = 1:length(GlobalData.Processes.All)
            strFunc = func2str(GlobalData.Processes.All(i).Function);
            if strcmpi(strFunc, ProcessName)
                iProc = i;
                break;
            end
        end
        % Return process if found
        if ~isempty(iProc)
            sProcess = GlobalData.Processes.All(iProc);
        % Else: try to get its definition directly from the function (for deprecated processes)
        elseif exist(ProcessName, 'file')
            % Call description function
            try
                Function = str2func(ProcessName);
                sProcess = Function('GetDescription');
                sProcess = struct_copy_fields(db_template('processdesc'), sProcess, 1);
                sProcess.Function = Function;
            catch
                sProcess = [];
            end
        else
            sProcess = [];
        end
    end
end

%% ===== GET CURRENT PROCESS =====
% Return the structure of the process currently being edited in the Pipeline Editor
function sProcess = GetCurrentProcess()
    global GlobalData;
    % Initialize returned variable
    sProcess = [];
    % Get edited processes in global variable
    sProcesses = GlobalData.Processes.Current;
    if isempty(sProcesses)
        return;
    end
    % Get panel
    ctrl = bst_get('PanelControls', 'ProcessOne');
    if isempty(ctrl)
        return;
    end
    % Get selected process
    iSel = ctrl.jListProcess.getSelectedIndex();
    if (iSel == -1)
        return;
    end
    % Return selected process, currently edited in the pipeline editor
    sProcess = GlobalData.Processes.Current(iSel + 1);
end


%% ===== SELECT FILE AND OPEN PANEL =====
function [sOutputs, sProcesses] = ShowPanelForFile(FileNames, ProcessNames) %#ok<DEFNU>
    % Add files
    panel_nodelist('ResetAllLists');
    panel_nodelist('AddFiles', 'Process1', FileNames);
    % Load Time vector
    FileTimeVector = in_bst(FileNames{1}, 'Time');
    if (length(FileTimeVector) < 2)
        FileTimeVector = [0, 1];
    end
    % Load the processes in the pipeline editor
    [sOutputs, sProcesses] = panel_process_select('ShowPanel', FileNames, ProcessNames, FileTimeVector);
end

%% ===== OPEN PANEL =====
% Open the pipeline editor with one or more processes already selected
% USAGE:  [sOutputs, sProcesses] = ShowPanel(FileNames, ProcessNames, FileTimeVector=[])
%         [sOutputs, sProcesses] = ShowPanel(FileNames, sProcesses)
function [sOutputs, sProcesses] = ShowPanel(FileNames, ProcessNames, FileTimeVector) %#ok<DEFNU>
    global GlobalData;
    % Initialize returned variables
    sProcesses = [];
    sOutputs = [];
    % Parse inputs
    if (nargin < 3) || isempty(FileTimeVector)
        FileTimeVector = [];
    end
    % Get process list
    if isempty(ProcessNames)
        error('Invalid call');
    elseif isstruct(ProcessNames)
        sSelProcesses = ProcessNames;
    elseif ischar(ProcessNames)
        ProcessNames = {ProcessNames};
        sSelProcesses = [];
    end
    % Get list of files
    FileNames = bst_report('GetFilesList', FileNames, 0);
    % Split if there are two lists in input
    if ~isempty(FileNames) && iscell(FileNames) && iscell(FileNames{1})
        FileNames2 = FileNames{2};
        FileNames  = FileNames{1};
    else
        FileNames2 = {};
    end

    % Get files structures
    if ~isempty(FileNames)
        sInputs = bst_process('GetInputStruct', FileNames);
        if isempty(sInputs)
            return
        end
    else
        sInputs = db_template('importfile');
    end
    % Get files structures for second input list
    if ~isempty(FileNames2)
        sInputs2 = bst_process('GetInputStruct', FileNames2);
        if isempty(sInputs2)
            return
        end
    else
        sInputs2 = [];
    end
    
    % If providing the process name: get the structure
    if isempty(sSelProcesses)
        % Find processes indices
        for i = 1:length(ProcessNames)
            % Get process structure
            sProc = GetProcess(ProcessNames{i});
            if isempty(sProc)
                error(['Unknown process name: "' ProcessNames{i} '"']);
            end
            % Check the options data type
            if ~isempty(sProc.options)
                % Get list of options
                optNames = fieldnames(sProc.options);
                % Remove the options that do not meet the current file type requirements
                for iOpt = 1:length(optNames)
                    option = sProc.options.(optNames{iOpt});
                    % Test file lists A and B
                    if (isfield(option, 'InputTypes') && iscell(option.InputTypes) && ~any(strcmpi(sInputs(1).FileType, option.InputTypes))) || ...
                       (~isempty(sInputs2) && isfield(option, 'InputTypesB') && iscell(option.InputTypesB) && ~any(strcmpi(sInputsB(1).FileType, option.InputTypesB)))
                        % Not a valid option for this type of data: remove
                        sProc.options = rmfield(sProc.options, optNames{iOpt});
                    end
                end
            end
            % Add process to pipeline
            if isempty(sSelProcesses)
                sSelProcesses = sProc;
            else
                sSelProcesses = [sSelProcesses, sProc];
            end
        end
        % Set default values (previously used)
        sSelProcesses = SetDefaultOptions(sSelProcesses, FileTimeVector);
    end
    % Load file time is possible
    TimeVector = FindRawFileTime(sSelProcesses);
    % Expand optimized pipelines
    sSelProcesses = bst_process('OptimizePipelineRevert', sSelProcesses);
    % Open pipeline editor
    [bstPanel, panelName] = CreatePanel(sInputs, sInputs2, TimeVector);
    gui_show(bstPanel, 'JavaWindow', 'Pipeline editor', [], 0, 1, 0, [50 100]);
    sControls = get(bstPanel, 'sControls');

    % Add processes
    GlobalData.Processes.Current = sSelProcesses;
    sControls.UpdatePipeline();
    % Wait for the end of execution
    bst_mutex('waitfor', panelName);
    % Check if panel is still existing (if user did not abort the operation)
    if gui_brainstorm('isTabVisible', get(bstPanel,'name'))
        % Try to execute 'GetPanelContents'
        sProcesses = GetPanelContents();
        % Close panel
        gui_hide(bstPanel);
    else
        % User cancelled the operation
        return;
    end
    % Empty process list
    if isempty(sProcesses)
        return;
    end
    % Timefreq and Connectivity: make sure the advanced options were reviewed
    for iProc = 1 : length(sProcesses)
        procFunc = func2str(sProcesses(iProc).Function);
        if (ismember(procFunc, {'process_timefreq', 'process_hilbert', 'process_psd'}) && ...
                                (~isfield(sProcesses(iProc).options.edit, 'Value') || isempty(sProcesses(iProc).options.edit.Value))) || ... % check 'edit' field
           (ismember(procFunc, {'process_henv1', 'process_henv1n', 'process_henv2', ...
                               'process_cohere1', 'process_cohere1n', 'process_cohere2', ...
                               'process_plv1', 'process_plv1n', 'process_plv2'}) && ...
                                (~isfield(sProcesses(iProc).options.tfedit, 'Value') || isempty(sProcesses(iProc).options.tfedit.Value)))    % check 'tfedit' field
            bst_error(['Please check the advanced options of the process "', sProcesses(iProc).Comment, '" before running the pipeline.'], 'Pipeline editor', 0);
            return
        end
    end

    % Call process function
    sOutputs = bst_process('Run', sProcesses, sInputs, sInputs2, 1);
end

%% ===== FIND RAW FILE =====
function TimeVector = FindRawFileTime(sProcesses)
    TimeVector = [];
    for iProc = 1:length(sProcesses)
        if isfield(sProcesses(iProc).options, 'datafile') && ~isempty(sProcesses(iProc).options.datafile.Value) && ~isempty(sProcesses(iProc).options.datafile.Value{1})
            RawFile = sProcesses(iProc).options.datafile.Value{1};
            if iscell(RawFile)
                RawFile = RawFile{1};
            end
            FileFormat = sProcesses(iProc).options.datafile.Value{2};
            TimeVector = LoadRawTime(RawFile, FileFormat);
            break;
        end
    end
end

%% ===== LOAD RAW TIME =====
function TimeVector = LoadRawTime(RawFile, FileFormat)
    TimeVector = [];
    % Open file, just to get the new file vector
    ImportOptions = db_template('ImportOptions');
    ImportOptions.EventsMode      = 'ignore';
    ImportOptions.EventsTrackMode = 'value';
    ImportOptions.ChannelAlign    = 0;
    ImportOptions.DisplayMessages = 0;
    try
        sFile = in_fopen(RawFile, FileFormat, ImportOptions);
        if isempty(sFile)
            return
        end
    catch
        bst_error(['Could not open the following file as "' FileFormat '":' 10 RawFile 10 10 'Please try again selecting another file format or import mode.'], 'Import MEG/EEG recordings', 0);
        return;
    end
    % Update time vector
    TimeVector = panel_time('GetRawTimeVector', sFile);
end
    

%% ===== GET PROCESS TIME VECTOR =====
function [procTimeVector, nFiles] = GetProcessFileVector(sProcesses, FileTimeVector, nFiles)
    % Default value
    procTimeVector = FileTimeVector;
    if isempty(sProcesses) || (length(procTimeVector) < 2)
        return;
    end
    % Look for an epoching process that changes the time vector of the files
    for iProc = 1:length(sProcesses)
        % Recalculate the frequency at this process
        procSampleFreq = 1 ./ (procTimeVector(2) - procTimeVector(1));
        % Processes names
        switch func2str(sProcesses(iProc).Function) 
            case 'process_import_data_event'
                % Get the epoch time range
                EventsTimeRange = sProcesses(iProc).options.epochtime.Value{1};
                % Build the epoch time vector
                EventsSampleRange = round(EventsTimeRange * procSampleFreq);
                procTimeVector = (EventsSampleRange(1):EventsSampleRange(2)) / procSampleFreq;
                % Increase the number of available files
                nFiles = 10 + zeros(size(nFiles));
            case {'process_import_data_epoch', 'process_import_data_time'}
                % Increase the number of available files
                nFiles = 10 + zeros(size(nFiles));
            case 'process_resample'
                newFreq = sProcesses(iProc).options.freq.Value{1};
                procTimeVector = linspace(procTimeVector(1), procTimeVector(end), round(newFreq / procSampleFreq * length(procTimeVector)));
            case 'process_timeoffset'
                procTimeVector = procTimeVector + sProcesses(iProc).options.offset.Value{1};
            case 'process_average_time'
                procTimeVector = [procTimeVector(1), procTimeVector(end)];
            case 'process_extract_time'
                optVal = sProcesses(iProc).options.timewindow.Value;
                if ~isempty(optVal) && iscell(optVal)
                    iTime = panel_time('GetTimeIndices', procTimeVector, optVal{1});
                    procTimeVector = procTimeVector(iTime);
                end
        end
    end
end


%% ===== SCRIPT: GET SEPARATE INPUT =====
function [SubjNames, RawFiles] = GetSeparateInputs(sProcesses)
    % Initialize returned variables
    SubjNames = {};
    RawFiles = {};
    % Loop on each process
    for iProc = 1:length(sProcesses)
        % No options: skip
        if ~isstruct(sProcesses(iProc).options) || isempty(sProcesses(iProc).options)
            continue;
        end
        % Loop on options
        optNames = fieldnames(sProcesses(iProc).options);
        for iOpt = 1:length(optNames)
            % Get option
            opt = sProcesses(iProc).options.(optNames{iOpt});
            % If the options is not complete: skip
            if ~isfield(opt, 'Value') || isempty(opt.Value) || ~isfield(opt, 'Type') || isempty(opt.Type)
                continue;
            end
            % Subject name
            if strcmpi(opt.Type, 'subjectname')
                iFile = find(strcmpi(SubjNames, opt.Value));
                if isempty(iFile)
                    SubjNames{end+1} = opt.Value;
                end
            % Raw files
            elseif ismember(opt.Type, {'datafile', 'filename'}) && iscell(opt.Value)
                % Multiple files
                if iscell(opt.Value{1})
                    for ic = 1:length(opt.Value{1})
                        iFile = find(strcmpi(RawFiles, opt.Value{1}{ic}));
                        if isempty(iFile) && ~isempty(opt.Value{1}{ic})
                            RawFiles{end+1} = opt.Value{1}{ic};
                        end
                    end
                else
                    iFile = find(strcmpi(RawFiles, opt.Value{1}));
                    if isempty(iFile) && ~isempty(opt.Value{1})
                        RawFiles{end+1} = opt.Value{1};
                    end
                end
            end
        end
    end
end


%% ===== SCRIPT: WRITE FILENAMES =====
%  USAGE:  str = WriteFileNames(FileNames, VarName, isDefault)
%          str = WriteFileNames(sFiles,    VarName, isDefault)
function str = WriteFileNames(FileNames, VarName, isDefault)
    % Initialize output
    str = [];
    % Parse inputs
    if isstruct(FileNames)
        FileNames = {FileNames.FileName};
    end
    % Empty entry
    if isempty(FileNames) || ((length(FileNames) == 1) && isempty(FileNames{1}))
        % Display only if it is really needed (default variable)
        if isDefault
            str = [str VarName ' = [];' 10];
        end
    % Write file list
    else
        str = [str VarName ' = {...' 10];
        for i = 1:length(FileNames)
            str = [str '    ''' FileNames{i} ''''];
            if (i ~= length(FileNames))
                str = [str ', ...' 10];
            else
                str = [str '};' 10];
            end
        end
    end
end

%% ===== RECURSIVELY TOGGLE A JPANEL =====
function ToggleJPanel(panel, enable)
    panel.setEnabled(enable);
    try
        components = panel.getComponents();
    catch
        components = [];
    end
    for iComp = 1:length(components)
        ToggleJPanel(components(iComp), enable);
    end
end
