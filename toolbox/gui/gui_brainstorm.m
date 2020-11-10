function varargout = gui_brainstorm( varargin )
% GUI_BRAINSTORM: Main Brainstorm window.
%
% USAGE:      GUI = gui_brainstorm('CreateWindow');
%                   gui_brainstorm('SetSelectedTab', TabName, isAutoSelect=1)
%                   gui_brainstorm('ShowToolTab',    TabName)
%       iProtocol = gui_brainstorm('CreateProtocol', ProtocolName, UseDefaultAnat, UseDefaultChannel)
%                   gui_brainstorm('DeleteProtocol', ProtocolName)
%                   gui_brainstorm('SetExplorationMode', ExplorationMode)    % ExplorationMode = {'Subjects','StudiesSubj','StudiesCond'}
% BrainstormDbDir = gui_brainstorm('SetDatabaseFolder')
%  [keyEvent,...] = gui_brainstorm('ConvertKeyEvent', ev)

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
% Authors: Francois Tadel, 2008-2019

eval(macro_method);
end


%% ===== CREATE WINDOW =====
function GUI = CreateWindow() %#ok<DEFNU>
    % Java initializations
    import org.brainstorm.icon.*;
    import java.awt.Dimension;
    import java.awt.Rectangle;
    import javax.swing.BorderFactory;
    import javax.swing.UIManager;
    global GlobalData;
    
    % ===== NO GUI =====
    % In headless mode: do not create any Java object
    if (GlobalData.Program.GuiLevel == -1)
        GUI.mainWindow.jBstFrame = [];
        GUI.mainWindow.jComboBoxProtocols = [];
        GUI.mainWindow.jComboBoxProtocols = [];
        GUI.panelContainers = [];
        GUI.panels = [];
        GUI.nodelists = [];
        return;
    end
    
    % ===== CREATE GLOBAL MUTEX =====
    % Clone control
    if isequal(GlobalData.Program.CloneLock, 1)
        bst_splash('hide');
        % GlobalData.Program.CloneLock = ~org.brainstorm.dialogs.CloneControl.probe(bst_get('BrainstormHomeDir'));
        GlobalData.Program.CloneLock = ~CloneProble(bst_get('BrainstormHomeDir'));
        if isequal(GlobalData.Program.CloneLock, 1)
            GUI = [];
            return;
        end
    end
    % In order to catch when Matlab is closed with Brainstorm still running
    bst_mutex('create', 'Brainstorm');
    bst_mutex('setReleaseCallback', 'Brainstorm', @closeWindow_Callback);
    
    % ===== CREATE JFRAME =====
    % Get interface scaling
    InterfaceScaling = bst_get('InterfaceScaling') / 100;
    % Create main Brainstorm window (JFrame)
    jBstFrame = java_create('javax.swing.JFrame');
    % Set window icon
    jBstFrame.setIconImage(IconLoader.ICON_APP.getImage());
    % Set closing callback
    jBstFrame.setDefaultCloseOperation(jBstFrame.DO_NOTHING_ON_CLOSE);
    java_setcb(jBstFrame, 'WindowClosingCallback', @closeWindow_Callback);

    % Get main frame panel
    jFramePanel = jBstFrame.getContentPane();
    % Constants
    TB_HEIGHT = 25 * InterfaceScaling;
    TB_BUTTON_WIDTH  = 25 * InterfaceScaling;
    TB_BUTTON_HEIGHT = 25 * InterfaceScaling;
    TB_DIM = Dimension(TB_BUTTON_WIDTH, TB_BUTTON_HEIGHT);
    TB_MENU_DIM = Dimension(32 * InterfaceScaling, TB_BUTTON_HEIGHT);
    % Fonts
    if strncmp(computer,'MAC',3)
        fontSize = 12;
    else
        fontSize = 11.5;
    end
    
    % ===== MENU BAR =====
    jMenuBar = java_create('javax.swing.JMenuBar');
    jMenuBar.setBorder([]);
    
    % ===== Menu: FILE =====
    if (GlobalData.Program.GuiLevel == 1)
        jMenuFile = gui_component('Menu', jMenuBar, [], ' File ', [], [], [], fontSize);
        
        % === PROTOCOL ===
        gui_component('MenuItem', jMenuFile, [], 'New protocol', IconLoader.ICON_FOLDER_NEW, [], @(h,ev)bst_call(@gui_edit_protocol, 'create'), fontSize);
        jSubMenu = gui_component('Menu', jMenuFile, [], 'Load protocol', IconLoader.ICON_FOLDER_OPEN,[],[], fontSize);
            gui_component('MenuItem', jSubMenu, [], 'Load from folder',   IconLoader.ICON_FOLDER_OPEN, [], @(h,ev)bst_call(@gui_edit_protocol, 'load'), fontSize);
            gui_component('MenuItem', jSubMenu, [], 'Load from zip file', IconLoader.ICON_FOLDER_OPEN, [], @(h,ev)bst_call(@import_protocol), fontSize);
            gui_component('MenuItem', jSubMenu, [], 'Import subject from zip', IconLoader.ICON_SUBJECT_NEW, [], @(h,ev)bst_call(@import_subject), fontSize);
            jSubMenu.addSeparator();
            gui_component('MenuItem', jSubMenu, [], 'Import BIDS dataset', IconLoader.ICON_FOLDER_OPEN, [], @(h,ev)panel_process_select('ShowPanel', {}, 'process_import_bids'), fontSize);
            jSubMenu.addSeparator();
            gui_component('MenuItem', jSubMenu, [], 'Change database folder', IconLoader.ICON_EXPLORER,    [], @(h,ev)bst_call(@ChangeDatabaseFolder), fontSize);
        jSubMenu = gui_component('Menu', jMenuFile, [], 'Export protocol', IconLoader.ICON_SAVE,[],[], fontSize);
            gui_component('MenuItem', jSubMenu, [], 'Copy raw files to database', IconLoader.ICON_RAW_DATA, [], @(h,ev)bst_call(@MakeProtocolPortable), fontSize);
            gui_component('MenuItem', jSubMenu, [], 'Export as zip file', IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@export_protocol), fontSize);
        gui_component('MenuItem', jMenuFile, [], 'Rename protocol', IconLoader.ICON_EDIT, [], @(h,ev)bst_call(@db_rename_protocol), fontSize);
        jSubMenu = gui_component('Menu', jMenuFile, [], 'Delete protocol', IconLoader.ICON_DELETE, [],[], fontSize);
            gui_component('MenuItem', jSubMenu, [], 'Remove all files', IconLoader.ICON_DELETE, [], @(h,ev)bst_call(@db_delete_protocol, 1, 1), fontSize);
            gui_component('MenuItem', jSubMenu, [], 'Only detach from database', IconLoader.ICON_DELETE, [], @(h,ev)bst_call(@db_delete_protocol, 1, 0), fontSize);
        jMenuFile.addSeparator();
        % === NEW SUBJECT ===
        gui_component('MenuItem', jMenuFile, [], 'New subject', IconLoader.ICON_SUBJECT_NEW, [], @(h,ev)bst_call(@db_edit_subject), fontSize);
        jMenuFile.addSeparator();
%         % === DATABASE ===
%         gui_component('MenuItem', jMenuFile, [], 'Import database',     IconLoader.ICON_FOLDER_OPEN, [], @(h,ev)bst_call(@db_import), []);
%         gui_component('MenuItem', jMenuFile, [], 'Reload database',     IconLoader.ICON_RELOAD,      [], @(h,ev)bst_call(@db_reload_database), []);
%         gui_component('MenuItem', jMenuFile, [], 'Set database folder', IconLoader.ICON_EXPLORER,    [], @(h,ev)bst_call(@SetDatabaseFolder), []);
%         jMenuFile.addSeparator();
        % === PROCESSES ===
        gui_component('MenuItem', jMenuFile, [], 'Report viewer',        IconLoader.ICON_PROCESS,    [], @(h,ev)bst_call(@bst_report, 'Open', 'current'), fontSize);
        gui_component('MenuItem', jMenuFile, [], 'Reload last pipeline', IconLoader.ICON_RELOAD, [], @(h,ev)bst_call(@bst_report, 'Recall', 'current'), fontSize);
        % === SET PREFERENCES ===
        gui_component('MenuItem', jMenuFile, [], 'Edit preferences', IconLoader.ICON_PROPERTIES, [], @(h,ev)bst_call(@gui_show, 'panel_options', 'JavaWindow', 'Brainstorm preferences', [], 1, 0, 0), fontSize);
        jMenuFile.addSeparator();
        % === EXECUTE SCRIPTS IN COMPILED VERSION ===
        if exist('isdeployed', 'builtin') && isdeployed
            gui_component('MenuItem', jMenuFile, [], 'Command window', IconLoader.ICON_TERMINAL, [], @(h,ev)gui_show('panel_command', 'JavaWindow', 'MATLAB command window', [], 0, 1, 0), fontSize);
            gui_component('MenuItem', jMenuFile, [], 'Execute script', IconLoader.ICON_PROCESS, [], @(h,ev)bst_call(@panel_command, 'ExecuteScript'), fontSize);
            jMenuFile.addSeparator();
        end
        % === DIGITIZE ===  
        gui_component('MenuItem', jMenuFile, [], 'Digitize', IconLoader.ICON_CHANNEL, [], @(h,ev)bst_call(@panel_digitize, 'Start'), fontSize);
        gui_component('MenuItem', jMenuFile, [], 'Batch MRI fiducials', IconLoader.ICON_LOBE, [], @(h,ev)bst_call(@bst_batch_fiducials), fontSize);
        jMenuFile.addSeparator();
        % === QUIT ===
        gui_component('MenuItem', jMenuFile, [], 'Quit', IconLoader.ICON_RESET, [], @closeWindow_Callback, fontSize);
    end
    
    % ==== Menu COLORMAPS ====
    jMenuColormaps = gui_component('Menu', jMenuBar, [], 'Colormaps', [], [], [], fontSize);
        bst_colormaps('CreateAllMenus', jMenuColormaps, [], 1);

    % ==== Menu UPDATE ====
    jMenuUpdate = gui_component('Menu', jMenuBar, [], ' Update ', [], [], [], fontSize);
        % UPDATE BRAINSTORM
        if ~(exist('isdeployed', 'builtin') && isdeployed)
            gui_component('MenuItem', jMenuUpdate, [], 'Update Brainstorm', IconLoader.ICON_RELOAD, [], @(h,ev)bst_update(1), fontSize);
        end
        % UPDATE OPENMEEG
        if (GlobalData.Program.GuiLevel == 1)
            jMenuOpenmeeg = gui_component('Menu', jMenuUpdate, [], 'Update OpenMEEG', IconLoader.ICON_RELOAD, [], [], fontSize);
            gui_component('MenuItem', jMenuOpenmeeg, [], 'Download', [], [], @(h,ev)bst_call(@DownloadOpenmeeg), fontSize);
            gui_component('MenuItem', jMenuOpenmeeg, [], 'Install', [], [], @(h,ev)bst_call(@bst_openmeeg, 'update'), fontSize);
            if strcmpi(bst_get('OsType',0), 'win64')
                jMenuOpenmeeg.addSeparator();
                gui_component('MenuItem', jMenuOpenmeeg, [], 'Download Visual C++', [], [], @(h,ev)web('http://www.microsoft.com/en-us/download/details.aspx?id=14632', '-browser'), fontSize);
            end
            jMenuOpenmeeg.addSeparator();
            gui_component('MenuItem', jMenuOpenmeeg, [], 'OpenMEEG help', [], [], @(h,ev)web('https://neuroimage.usc.edu/brainstorm/Tutorials/TutBem', '-browser'), fontSize);
        end
        if (GlobalData.Program.GuiLevel == 1)
            jMenuNirsorm = gui_component('Menu', jMenuUpdate, [], 'Update NIRSTORM', IconLoader.ICON_RELOAD, [], [], fontSize);
            if nst_setup('status')
                gui_component('MenuItem', jMenuNirsorm, [], 'Update', [], [], @(h,ev)nst_setup('install',[],1), fontSize);
                gui_component('MenuItem', jMenuNirsorm, [], 'Uninstall', [], [], @(h,ev)nst_setup('uninstall',[],1), fontSize);
            else
                gui_component('MenuItem', jMenuNirsorm, [], 'Download', [], [], @(h,ev)nst_setup('install',[],1), fontSize);
            end    
            
            gui_component('MenuItem', jMenuNirsorm, [], 'NIRSTORM help', [], [], @(h,ev)web('https://github.com/Nirstorm/nirstorm/wiki', '-browser'), fontSize);

        end       
        
    % ==== Menu HELP ====
    jMenuSupport = gui_component('Menu', jMenuBar, [], ' Help ', [], [], [], fontSize);
        % BUG REPORTS
        % gui_component('MenuItem', jMenuSupport, [], 'Bug reporting...', [], [], @(h,ev)gui_show('panel_bug', 'JavaWindow', 'Bug reporting', [], 1, 0), []);
        % WEBSITE
        gui_component('MenuItem', jMenuSupport, [], 'Brainstorm website', IconLoader.ICON_EXPLORER, [], @(h,ev)web('https://neuroimage.usc.edu/brainstorm/', '-browser'), fontSize);
        gui_component('MenuItem', jMenuSupport, [], 'Brainstorm forum', IconLoader.ICON_EXPLORER, [], @(h,ev)web('https://neuroimage.usc.edu/forums/', '-browser'), fontSize);
        jMenuSupport.addSeparator();
        % USAGE STATS
        gui_component('MenuItem', jMenuSupport, [], 'Usage statistics', IconLoader.ICON_TS_DISPLAY, [], @(h,ev)bst_userstat, fontSize);
        jMenuSupport.addSeparator();
        % LICENSE
        gui_component('MenuItem', jMenuSupport, [], 'License',       IconLoader.ICON_EDIT, [], @(h,ev)bst_license(), fontSize);
        % RELEASE NOTES
        updatesfile = bst_fullfile(bst_get('BrainstormDocDir'), 'updates.txt');
        gui_component('MenuItem', jMenuSupport, [], 'Release notes', IconLoader.ICON_EDIT, [], @(h,ev)view_text(updatesfile, 'Release notes', 1), fontSize);
        jMenuSupport.addSeparator();
        % Prepare workshop
        gui_component('MenuItem', jMenuSupport, [], 'Workshop preparation', IconLoader.ICON_SCREEN1, [], @(h,ev)brainstorm('workshop'), fontSize);
        jMenuSupport.addSeparator();
        % Guidelines
        jMenuGuidelines = gui_component('Menu', jMenuSupport, [], 'Guidelines', IconLoader.ICON_FOLDER_OPEN, [], [], fontSize);
        gui_component('MenuItem', jMenuGuidelines, [], 'Epileptogenicity maps', IconLoader.ICON_EDIT, [], @(h,ev)ShowGuidelines('epileptogenicity'), fontSize);
        jMenuGuidelines.addSeparator();
        gui_component('MenuItem', jMenuGuidelines, [], 'Close panel', IconLoader.ICON_EDIT, [], @(h,ev)gui_hide('Guidelines'), fontSize);
        
    % ===== TOOLBAR =====
    jToolbar = gui_component('Toolbar', jMenuBar);
        jToolbar.setPreferredSize(Dimension(100,TB_HEIGHT));
        % Add separator : to get the other buttons on the right
        jSepPanel = gui_component('Panel', jToolbar);
        jSepPanel.setOpaque(0);
        % Button "Edit preferences"
        gui_component('ToolbarButton', jToolbar, [], [], {IconLoader.ICON_PROPERTIES, TB_DIM}, 'Edit preferences', @(h,ev)gui_show('panel_options', 'JavaWindow', 'Brainstorm preferences', [], 1, 0, 0), []);
        % Button "Layout"
        gui_component('ToolbarButton', jToolbar, [], [], {IconLoader.ICON_LAYOUT_SELECT, TB_MENU_DIM}, 'Window layout options', @(h,ev)ShowLayoutMenu(ev.getSource()), []);
        % Button: "Unload all"
        if (GlobalData.Program.GuiLevel == 1)
            gui_component('ToolbarButton', jToolbar, [], [], {IconLoader.ICON_DELETE, TB_DIM}, 'Close all figures and clear memory', @(h,ev)GuiUnloadAll());
        end
    % Set colors and backgrounds
    jToolbar.setOpaque(0);
    
    % Add MenuBar to main frame
    jFramePanel.add(jMenuBar, java.awt.BorderLayout.NORTH);


    %% ===== MAIN WINDOW STRUCTURE =====
    % ==== EXPLORER Panel container ====
    jPanelExplorer = gui_component('Panel');
    jPanelExplorer.setBorder(BorderFactory.createTitledBorder(''));
        jPanelExplorerTop = gui_component('Panel');
        % Protocol list
        if (GlobalData.Program.GuiLevel == 1)
            % Combo box to select the current protocol
            jComboBoxProtocols = gui_component('ComboBox', jPanelExplorerTop, java.awt.BorderLayout.NORTH, [], [], [], [], []);
            jComboBoxProtocols.setMaximumSize(java_scaled('dimension', 160, 21));
            jComboBoxProtocols.setPreferredSize(java_scaled('dimension', 160, 21));
            jComboBoxProtocols.setMaximumRowCount(25);
            jComboBoxProtocols.setFocusable(0);
            % ComboBox change selection callback
            jModel = jComboBoxProtocols.getModel();
            java_setcb(jModel, 'ContentsChangedCallback', @protocolComboBoxChanged_Callback);
        else
            jComboBoxProtocols = [];
        end

        % ==== Exploration mode toolbar ====
        jToolbarExpMode = gui_component('Toolbar', jPanelExplorerTop, [], [], {TB_DIM});
        % Coonfigure toolbar
        jToolbarExpMode.setPreferredSize(Dimension(100,TB_HEIGHT));
        jButtonGroup = java_create('javax.swing.ButtonGroup');
        % Create buttons
        jToolButtonSubject     = gui_component('ToolbarToggle', jToolbarExpMode, [], [], {IconLoader.ICON_SUBJECTDB,    TB_DIM, jButtonGroup}, '<HTML><B>Anatomy</B>:<BR>MRI, surfaces</HTML>', [], []);
        jToolButtonStudiesSubj = gui_component('ToolbarToggle', jToolbarExpMode, [], [], {IconLoader.ICON_STUDYDB_SUBJ, TB_DIM, jButtonGroup}, '<HTML><B>Functional data</B> (sorted by subjects):<BR>channels, head models, recordings, results</HTML>', [], []);
        jToolButtonStudiesCond = gui_component('ToolbarToggle', jToolbarExpMode, [], [], {IconLoader.ICON_STUDYDB_COND, TB_DIM, jButtonGroup}, '<HTML><B>Functional data</B> (sorted by conditions):<BR>channels, head models, recordings, results</HTML>', [], []);
        % Search button
        jToolbarSearch      = gui_component('Toolbar', jPanelExplorerTop, java.awt.BorderLayout.EAST, []);
        jToolSearchDatabase = gui_component('ToolbarButton', jToolbarSearch, [], [], {IconLoader.ICON_ZOOM, TB_DIM, jButtonGroup}, 'Search Database', @(h,ev)panel_protocols('MainPopupMenu', ev.getSource()), []);
    jPanelExplorer.add(jPanelExplorerTop, java.awt.BorderLayout.NORTH);

    % ==== TOOLS CONTAINER ====
    jPanelTools = gui_component('Panel');
        UIManager.put('TabbedPane.tabInsets', java.awt.Insets(2, 5, 1, 1));
        jTabpaneTools = java_create('javax.swing.JTabbedPane', 'II', javax.swing.JTabbedPane.TOP, javax.swing.JTabbedPane.WRAP_TAB_LAYOUT); 
        jTabpaneTools.setFont(bst_get('Font', 11));
        jTabpaneTools.setFocusable(0);
        jTabpaneTools.setMinimumSize(java_scaled('dimension', 100, 200));
        java_setcb(jTabpaneTools, 'StateChangedCallback', @ToolsPanelChanged_Callback);
        % Add the "+" button
        jButtonPlus = gui_component('Label', [], [], '<HTML><B>+ </B>');
        jButtonPlus.setOpaque(0);
        jButtonPlus.setPreferredSize(java_scaled('dimension', 12, 10));
        jPanelPlus = gui_component('Panel');
        jTabpaneTools.addTab(' ', [], jPanelPlus);
        if (bst_get('JavaVersion') >= 1.6)
            jTabpaneTools.setTabComponentAt(0, jButtonPlus);
        end
        % Additional "Add tabs" button
        gui_component('Button', jPanelPlus, java.awt.BorderLayout.NORTH, 'Add/remove tabs', [], [], @(h,ev)ShowTabMenu);
        curTab = '';
    jPanelTools.add(jTabpaneTools, java.awt.BorderLayout.CENTER);

    % ==== PROCESS CONTAINER ====   
    jPanelProcess = gui_component('Panel');
    jPanelProcess.setMinimumSize(java_scaled('dimension', 100, 30));
    jPanelProcess.setPreferredSize(java_scaled('dimension', 250, 140));
    % Selection toolbar
    jToolbarA = gui_component('Toolbar', jPanelProcess);
    jToolbarA.setOrientation(javax.swing.JToolBar.VERTICAL);
        TB_SIZE = Dimension(28*InterfaceScaling, 26*InterfaceScaling);
        jButtonGroupType = java_create('javax.swing.ButtonGroup');
        % Buttons
        jButtonRecordingsA = gui_component('toolbartoggle', jToolbarA, [], '', {IconLoader.ICON_DATA_LIST,     TB_SIZE, jButtonGroupType}, 'Process recordings',  @(h,ev)bst_call(@ProcessDataType_Callback, 'data', 'A', ev));
        jButtonSourcesA    = gui_component('toolbartoggle', jToolbarA, [], '', {IconLoader.ICON_RESULTS_LIST,  TB_SIZE, jButtonGroupType}, 'Process sources',     @(h,ev)bst_call(@ProcessDataType_Callback, 'results', 'A', ev));
        jButtonTimefreqA   = gui_component('toolbartoggle', jToolbarA, [], '', {IconLoader.ICON_TIMEFREQ_LIST, TB_SIZE, jButtonGroupType}, 'Process time-freq',   @(h,ev)bst_call(@ProcessDataType_Callback, 'timefreq', 'A', ev));
        jButtonMatrixA     = gui_component('toolbartoggle', jToolbarA, [], '', {IconLoader.ICON_MATRIX_LIST,   TB_SIZE, jButtonGroupType}, 'Process user matrix', @(h,ev)bst_call(@ProcessDataType_Callback ,'matrix', 'A', ev));
        jButtonRecordingsA.setSelected(1);
        jToolbarA.addSeparator();
        % Button "RUN"
        gui_component('toolbarbutton', jToolbarA, [], '', {IconLoader.ICON_RUN, TB_SIZE}, 'Start', @(h,ev)bst_call(@ProcessRun_Callback));
        jToolbarA.addSeparator();
        jButtonReload = gui_component('toolbarbutton', jToolbarA, [], '', {IconLoader.ICON_RELOAD, TB_SIZE}, 'Reload last pipeline', @(h,ev)bst_call(@bst_report, 'Recall', 'current'));
    jPanelProcess.add(jToolbarA, java.awt.BorderLayout.WEST);
       
    % Toolbar B
    jToolbarB = gui_component('Toolbar', jPanelProcess);
    jToolbarB.setOrientation(javax.swing.JToolBar.VERTICAL);
        jButtonGroupType = java_create('javax.swing.ButtonGroup');
        % Buttons
        jButtonRecordingsB = gui_component('toolbartoggle', jToolbarB, [], '', {IconLoader.ICON_DATA_LIST,     TB_SIZE, jButtonGroupType}, 'Process recordings',  @(h,ev)bst_call(@ProcessDataType_Callback, 'data', 'B', ev));
        jButtonSourcesB    = gui_component('toolbartoggle', jToolbarB, [], '', {IconLoader.ICON_RESULTS_LIST,  TB_SIZE, jButtonGroupType}, 'Process sources',     @(h,ev)bst_call(@ProcessDataType_Callback, 'results', 'B', ev));
        jButtonTimefreqB   = gui_component('toolbartoggle', jToolbarB, [], '', {IconLoader.ICON_TIMEFREQ_LIST, TB_SIZE, jButtonGroupType}, 'Process time-freq',   @(h,ev)bst_call(@ProcessDataType_Callback, 'timefreq', 'B', ev));
        jButtonMatrixB     = gui_component('toolbartoggle', jToolbarB, [], '', {IconLoader.ICON_MATRIX_LIST,   TB_SIZE, jButtonGroupType}, 'Process user matrix', @(h,ev)bst_call(@ProcessDataType_Callback, 'matrix', 'B', ev));
        jButtonRecordingsB.setSelected(1);
    jPanelProcess.add(jToolbarB, java.awt.BorderLayout.EAST);
    
    % Tab panel
    jTabpaneProcess = java_create('javax.swing.JTabbedPane', 'I', javax.swing.JTabbedPane.BOTTOM);
    jTabpaneProcess.setFont(bst_get('Font', 11));
    java_setcb(jTabpaneProcess, 'StateChangedCallback', @ProcessPanelChanged_Callback);
    jPanelProcess.add(jTabpaneProcess, java.awt.BorderLayout.CENTER);
    
    % ==== SEARCH PANEL ====
    jPanelSearchTop = gui_component('Panel');
    jPanelSearchTop.setOpaque(0);
        % Toolbar
        jToolbarFilter = gui_component('Toolbar', jPanelSearchTop, java.awt.BorderLayout.EAST);
        jToolbarFilter.setOpaque(0);
        jToolbarFilter.setBackground(java.awt.Color(0,0,0,0));
        jToolbarFilter.setBorder(BorderFactory.createEmptyBorder(3,2,3,2));
        % Create popup menu
        jPopupFilter = CreateFilterMenu();
        % Label 
        jTextFilter = gui_component('Text', jToolbarFilter, [], '', [], [], [], 11);
        if strncmp(computer,'MAC',3)
            jSize = java_scaled('dimension', 90, 22);
        else
            jSize = java.awt.Dimension(jPopupFilter.getPreferredSize().getWidth(), 22 * InterfaceScaling);
        end
        jTextFilter.setPreferredSize(jSize);
        jTextFilter.setMinimumSize(jSize);
        jTextFilter.setMaximumSize(jSize);
        jTextFilter.setHorizontalAlignment(jTextFilter.RIGHT);
        jTextFilter.setOpaque(0);
        jTextFilter.setBackground(java.awt.Color(0,0,0,0));
        jTextFilter.setBorder([]);
        java_setcb(jTextFilter, 'ActionPerformedCallback', @(h,ev)ValidateTextFilter(), ...
                                'FocusLostCallback',       @(h,ev)ValidateTextFilter());
        % Separator
        gui_component('Label', jToolbarFilter, [], ' ', [], [], [], 11);
        % Filter options
        gui_component('ToolbarButton', jToolbarFilter, [], 'Filter', {IconLoader.ICON_MENU_LEFT, java_scaled('dimension', 50, 26)}, 'Edit the filter properties', @(h,ev)ShowFilterMenu());
        
    % ==== LAYERED PROCESS PANEL ====
    jLayeredProcess = java_create('javax.swing.JLayeredPane');
    jLayeredProcess.add(jPanelProcess, javax.swing.JLayeredPane.DEFAULT_LAYER);
    jLayeredProcess.add(jPanelSearchTop, javax.swing.JLayeredPane.PALETTE_LAYER);
    java_setcb(jLayeredProcess, 'ComponentResizedCallback', @ResizeLayeredPanel);

    % ==== TIMEWINDOW Panel container ====
    jPanelTimeWindow = gui_component('Panel');
    jPanelTimeWindow.setBorder(BorderFactory.createTitledBorder(''));
    % ===== FREQ Panel container =====
    jPanelFreq = gui_component('Panel');
    jPanelFreq.setBorder(BorderFactory.createTitledBorder(''));
    jPanelFreq.setVisible(0);

    % ==== GENERAL LAYOUT ====
    % TOP/RIGHT PANEL : border layout
    % Top : TIMEWINDOW/FREQ, Bottom : TOOLS
    jPanelTopRight = gui_component('Panel');
        jPanelTopRightTop = gui_component('Panel');
        jPanelTopRightTop.add( jPanelTimeWindow, java.awt.BorderLayout.NORTH );
        jPanelTopRightTop.add( jPanelFreq, java.awt.BorderLayout.SOUTH );
    jPanelTopRight.add(jPanelTopRightTop, java.awt.BorderLayout.NORTH);
    jPanelTopRight.add(jPanelTools, java.awt.BorderLayout.CENTER );
    
    % Vertical split panel
    jSplitV = java_create('javax.swing.JSplitPane', 'ILjava.awt.Component;Ljava.awt.Component;', javax.swing.JSplitPane.HORIZONTAL_SPLIT, jPanelExplorer, jPanelTopRight);
    jSplitV.setResizeWeight(1.0);
    jSplitV.setDividerSize(round(6*InterfaceScaling));
    jSplitV.setBorder([]);
    % Horizontal split panel 
    jSplitH = java_create('javax.swing.JSplitPane', 'ILjava.awt.Component;Ljava.awt.Component;', javax.swing.JSplitPane.VERTICAL_SPLIT, jSplitV, jLayeredProcess);
        
    % Regular interface
    if (GlobalData.Program.GuiLevel ~= 2)
        % Configure horizontal split pane
        jSplitH.setResizeWeight(1.0);
        jSplitH.setDividerSize(round(8*InterfaceScaling));
        jSplitH.setBorder([]);
        % Add panel to main frame
        jFramePanel.add(jSplitH, java.awt.BorderLayout.CENTER);
    % Auto-pilot: No process tabs at the bottom (ignore horizontal split pane)
    else
        jFramePanel.add(jSplitV, java.awt.BorderLayout.CENTER);
    end
    % Pack JFrame
    jBstFrame.pack();



    %% ===== RESTORE LAYOUT FROM PREVIOUS SESSION =====
    % Get maximum client area on screen
    ScreenDef = GlobalData.Program.ScreenDef;
    % Get position from previous session
    sLayout = bst_get('Layout');
    % If main window is visible
    if (GlobalData.Program.GuiLevel >= 1)
        % Detect on which screen was Brainstorm window at the previous session
        tol = 30;
        if (length(ScreenDef) > 1) && sLayout.DoubleScreen && ...
           (sLayout.MainWindowPos(1) >= ScreenDef(2).javaPos.getX() - tol) && (sLayout.MainWindowPos(1) <= ScreenDef(2).javaPos.getX() + ScreenDef(2).javaPos.getWidth() + tol) && ...
           (sLayout.MainWindowPos(2) >= ScreenDef(2).javaPos.getY() - tol) && (sLayout.MainWindowPos(2) <= ScreenDef(2).javaPos.getY() + ScreenDef(2).javaPos.getHeight() + tol)
            javaMax = ScreenDef(2).javaPos;
        else
            javaMax = ScreenDef(1).javaPos;
        end
        % Minimum, maximum and default location/size of brainstorm window
        minPos = [javaMax.getX(), ...
                  javaMax.getY(), ...
                  380 * InterfaceScaling, ...
                  700 * InterfaceScaling];
        maxPos = [javaMax.getX() + javaMax.getWidth() - minPos(3), ...
                  javaMax.getY() + javaMax.getHeight() - minPos(4), ...
                  javaMax.getWidth() * .6, ...
                  javaMax.getHeight()];
        defPos = [minPos(1), ...
                  minPos(2), ...
                  450 * InterfaceScaling, ...
                  maxPos(4) * .9];
        % Check values of previous session
        if all(sLayout.MainWindowPos >= minPos) && all(sLayout.MainWindowPos <= maxPos)
            defPos = sLayout.MainWindowPos;
        end
        % Set window size and location
        jBstFrame.setLocation(defPos(1), defPos(2));
        jBstFrame.setSize(defPos(3), defPos(4));
% ===== SECTION MOVED TO GUI_LAYOUT =====
%         % Max size for window: half size of the screen for one screen, no limit for two screens
%         jBstFrame.setMaximumSize(Dimension(javaMax.getWidth() / 2, javaMax.getHeight()));
%         jBstFrame.setMaximizedBounds(Rectangle(0,0,javaMax.getWidth() / 2, javaMax.getHeight()));
% =======================================
        % Set Split panels divider location
        jSplitH.setDividerLocation(uint32(round(defPos(4) - 240 * InterfaceScaling)));
        jSplitV.setDividerLocation(uint32(round(defPos(3) - 260 * InterfaceScaling)));
    end
    
    % ===== EXPLORATION MODE =====
    switch sLayout.ExplorationMode
        case 'Subjects',    jToolButtonSubject.setSelected(1);
        case 'StudiesSubj', jToolButtonStudiesSubj.setSelected(1);
        case 'StudiesCond', jToolButtonStudiesCond.setSelected(1);
    end

    % ===== EXPLORATION MODE BUTTONS CALLBACKS ===== 
    % (MUST BE DONE AFTER THE PART THAT SELECTS A BUTTON)
    java_setcb(jToolButtonSubject,     'ItemStateChangedCallback', @(h,ev)bst_call(@protocolDisplayModeChanged_Callback, h, ev));
    java_setcb(jToolButtonStudiesSubj, 'ItemStateChangedCallback', @(h,ev)bst_call(@protocolDisplayModeChanged_Callback, h, ev));
    java_setcb(jToolButtonStudiesCond, 'ItemStateChangedCallback', @(h,ev)bst_call(@protocolDisplayModeChanged_Callback, h, ev));

    % Populate Brainstorm handles structure
    GUI = struct(... % ==== Attributes ====
         'mainWindow', struct(...
             'jBstFrame',              jBstFrame, ...
             'jSplitH',                jSplitH, ...
             'jSplitV',                jSplitV, ...
             'jToolButtonSubject',     jToolButtonSubject, ...
             'jToolButtonStudiesSubj', jToolButtonStudiesSubj, ...
             'jToolButtonStudiesCond', jToolButtonStudiesCond, ...
             'jToolSearchDatabase',    jToolSearchDatabase, ...
             'jComboBoxProtocols',     jComboBoxProtocols, ...
             'jButtonRecordingsA',      jButtonRecordingsA, ...
             'jButtonSourcesA',         jButtonSourcesA, ...
             'jButtonTimefreqA',        jButtonTimefreqA, ...
             'jButtonMatrixA',          jButtonMatrixA, ...
             'jToolbarB',               jToolbarB, ...
             'jButtonRecordingsB',      jButtonRecordingsB, ...
             'jButtonSourcesB',         jButtonSourcesB, ...
             'jButtonTimefreqB',        jButtonTimefreqB, ...
             'jButtonMatrixB',          jButtonMatrixB, ...
             'jButtonReload',           jButtonReload, ...
             'jTextFilter',             jTextFilter),... 
         'panelContainers', [...
               struct('name', 'explorer', ...
                      'jHandle', jPanelExplorer), ...
               struct('name', 'process', ...
                      'jHandle', jTabpaneProcess), ...
               struct('name', 'timewindow', ...
                      'jHandle', jPanelTimeWindow), ...
               struct('name', 'freq', ...
                      'jHandle', jPanelFreq), ...
               struct('name', 'tools', ...
                      'jHandle', jTabpaneTools)], ...
         'panels',  BstPanel(), ...  % [0x0] array of BstPanel objects
         'nodelists', repmat(db_template('nodelist'), 0));


%% =================================================================================
%  === LOCAL CALLBACKS  ============================================================
%  =================================================================================
%% ===== CLOSE WINDOW =====
    function closeWindow_Callback(varargin)
        % Check that global variables are still accessible
        if ~exist('GlobalData', 'var') || isempty(GlobalData) || ~isfield(GlobalData, 'Program') || ~isfield(GlobalData.Program, 'GuiLevel') || isempty(GlobalData.Program.GuiLevel)
            disp('BST> Error: Brainstorm global variables were cleared.');
            disp('BST> Never call "clear" in your scripts while Brainstorm is running.');
            % Force deleting the window
            jBstFrame.dispose();
            return;
        end
        % If GUI was displayed: save current position
        if (GlobalData.Program.GuiLevel >= 1)
            % Update main window size and position
            MainWindowPos = [jBstFrame.getLocation.getX(), ...
                             jBstFrame.getLocation.getY(), ...
                             jBstFrame.getWidth(), ...
                             jBstFrame.getHeight()];
            % Update the Layout structure in Matlab preferences
            % bst_set('Layout', 'MainWindowPos', MainWindowPos);
            GlobalData.Preferences.Layout.MainWindowPos = MainWindowPos;
        end
        % Try to exit via bst_exit function
        if (~bst_exit())
            % If window is not registered as a current Brainstorm process : just kill it
            jBstFrame.dispose();
        end
    end


%% ===== RESIZE PROCESS PANEL =====
    function ResizeLayeredPanel(h, ev)
        % Resize tabbed panel with Process1 and Process2
        jPanelProcess.setSize(jLayeredProcess.getSize());
        % Resize the search panel
        jPanelSearchTop.setLocation(0, jLayeredProcess.getSize().getHeight() - jPanelSearchTop.getSize().getHeight());
        jPanelSearchTop.setSize(jLayeredProcess.getSize().getWidth(), 24);
        jLayeredProcess.revalidate();
    end

%% ===== DISPLAY MODE CHANGED =====
    function protocolDisplayModeChanged_Callback( hObject, event, varargin ) %#ok<INUSL>
        % Only cahnges exploration mode if the button is clicked
        if event.getSource.isSelected()
            % Save selected mode
            if (jToolButtonSubject.isSelected())
                ExplorationMode = 'Subjects';
            elseif (jToolButtonStudiesSubj.isSelected())
                ExplorationMode = 'StudiesSubj';
            elseif (jToolButtonStudiesCond.isSelected())
                ExplorationMode = 'StudiesCond';
            end
            % Update the Layout structure
            bst_set('Layout', 'ExplorationMode', ExplorationMode);
            % Update tree display
            panel_protocols('UpdateTree', 0);
        end
        % Empty clipboard
        bst_set('Clipboard', []);
    end


%% ===== PROTOCOL CHANGED =====
    function protocolComboBoxChanged_Callback( varargin )
        % Get selected item in the combo box
        jItem = jComboBoxProtocols.getSelectedItem();
        if isempty(jItem)
            return
        end
        % Select protocol
        SetCurrentProtocol(jItem.getUserData());
    end

    %% ===== LAYOUT: CREATE POPUP MENU =====
    function ShowLayoutMenu(jButton)
        import org.brainstorm.icon.*;
        % Create popup menu
        jPopup = java_create('javax.swing.JPopupMenu');
        % Possible layout managers
        groupLayout = javax.swing.ButtonGroup();
        jRadioTile   = gui_component('RadioMenuItem', jPopup, [], 'Tiled',       {IconLoader.ICON_LAYOUT_TILE, groupLayout},       [], @(h,ev)bst_set('Layout', 'WindowManager', 'TileWindows'), fontSize);
        jRadioWeight = gui_component('RadioMenuItem', jPopup, [], 'Weighted',    {IconLoader.ICON_LAYOUT_WEIGHT, groupLayout},     [], @(h,ev)bst_set('Layout', 'WindowManager', 'WeightWindows'), fontSize);
        jRadioFullA  = gui_component('RadioMenuItem', jPopup, [], 'Full area',   {IconLoader.ICON_LAYOUT_FULLAREA, groupLayout},   [], @(h,ev)bst_set('Layout', 'WindowManager', 'FullArea'), fontSize);
        jRadioNone   = gui_component('RadioMenuItem', jPopup, [], 'None',        {IconLoader.ICON_LAYOUT_NONE, groupLayout},       [], @(h,ev)bst_set('Layout', 'WindowManager', 'None'), fontSize);
        % One or two screens
        jPopup.addSeparator();
        groupScreen = javax.swing.ButtonGroup();
        jRadioOne  = gui_component('RadioMenuItem', jPopup, [], 'One screen',  {IconLoader.ICON_SCREEN1, groupScreen}, [], @(h,ev)bst_set('Layout', 'DoubleScreen', 0), fontSize);
        jRadioTwo  = gui_component('RadioMenuItem', jPopup, [], 'Two screens', {IconLoader.ICON_SCREEN2, groupScreen}, [], @(h,ev)bst_set('Layout', 'DoubleScreen', 1), fontSize);
        jCheckFull = gui_component('CheckboxMenuItem', jPopup, [], 'Full screen', IconLoader.ICON_RESIZE, [],   @(h,ev)bst_set('Layout', 'FullScreen', ev.getSource().isSelected()), fontSize);
        % Select current options
        switch bst_get('Layout', 'WindowManager')
            case 'TileWindows',    jRadioTile.setSelected(1);
            case 'WeightWindows',  jRadioWeight.setSelected(1);
            case 'FullArea',       jRadioFullA.setSelected(1);
            case 'FullScreen',     jRadioFullS.setSelected(1);
            otherwise,             jRadioNone.setSelected(1);
        end
        if bst_get('Layout', 'DoubleScreen')
            jRadioTwo.setSelected(1);
        else
            jRadioOne.setSelected(1);
        end
        jCheckFull.setSelected(bst_get('Layout', 'FullScreen'));
        % User setups
        jPopup.addSeparator();
        jMenu = gui_component('Menu', jPopup, [], 'User setups', IconLoader.ICON_LAYOUT_CASCADE, [], [], fontSize);
        gui_layout('SetupMenu', jMenu);
        % Show all figures
        gui_component('MenuItem', jPopup, [], 'Show all figures', IconLoader.ICON_LAYOUT_SHOWALL, [], @(h,ev)gui_layout('ShowAllWindows'), fontSize);
        % Show popup menu
        ShowPopup(jPopup, jButton);
    end

    %% ===== FILTER: CREATE POPUP MENU =====
    function jPopup = CreateFilterMenu()
        import org.brainstorm.icon.*;
        % Create popup menu
        jPopup = java_create('javax.swing.JPopupMenu');
        % What field to search for: {'FileName', 'Comment'}
        groupTarget = java_create('javax.swing.ButtonGroup');
        jRadioFilename = gui_component('RadioMenuItem', jPopup, [], 'Search file paths', groupTarget, [], @(h,ev)SetFilterOption('Target', 'FileName'), fontSize);
        jRadioComment  = gui_component('RadioMenuItem', jPopup, [], 'Search names',   groupTarget, [], @(h,ev)SetFilterOption('Target', 'Comment'), fontSize);
        jRadioParent   = gui_component('RadioMenuItem', jPopup, [], 'Search parent names',   groupTarget, [], @(h,ev)SetFilterOption('Target', 'Parent'), fontSize);
        jPopup.addSeparator();
        % What to do with the filtered files: {'Select', 'Exclude'}
        groupAction = java_create('javax.swing.ButtonGroup');
        jRadioSelect  = gui_component('RadioMenuItem', jPopup, [], 'Select files',  groupAction, [], @(h,ev)SetFilterOption('Action', 'Select'), fontSize);
        jRadioExclude = gui_component('RadioMenuItem', jPopup, [], 'Exclude files', groupAction, [], @(h,ev)SetFilterOption('Action', 'Exclude'), fontSize);
        % Reset filters
        jPopup.addSeparator();
        gui_component('MenuItem', jPopup, [], 'Reset filters', IconLoader.ICON_RESET, [], @(h,ev)ButtonFilterReset_Callback(), fontSize);
        % Select current options
        NodelistOptions = bst_get('NodelistOptions');
        switch (NodelistOptions.Target)
            case 'FileName', jRadioFilename.setSelected(1);
            case 'Comment',  jRadioComment.setSelected(1);
            case 'Parent',   jRadioParent.setSelected(1);
        end
        switch (NodelistOptions.Action)
            case 'Select',  jRadioSelect.setSelected(1);
            case 'Exclude', jRadioExclude.setSelected(1);
        end
        % Pack popup menu
        jPopup.pack();
        % When hiding: hide the border of the search box
        java_setcb(jPopup, 'PopupMenuWillBecomeInvisibleCallback', @(h,ev)HideFilterMenu);
    end

    %% ===== FILTER: SHOW POPUP MENU =====
    function ShowFilterMenu()
        % Show popup
        ShowPopup(jPopupFilter, jTextFilter, 0, -jPopupFilter.getPreferredSize().getHeight()-1);
        % Set search border visible
        jTextFilter.setBorder(javax.swing.BorderFactory.createLineBorder(java.awt.Color(0.5,0.5,0.5)));
        jTextFilter.grabFocus();
    end

    %% ===== TABS: SHOW POPUP MENU =====
    function ShowTabMenu()
        % Create popup
        jPopupTab = java_create('javax.swing.JPopupMenu');
        % List possible tabs
        panelList = {'Record', 'Filter', 'Surface', 'Scout', 'Cluster', 'Coordinates', 'Dipinfo', 'iEEG', 'Command', 'Spikes'};
        panelRemove = {};
        % List missing tabs
        for iPanel = 1:length(GlobalData.Program.GUI.panels)
            iFound = find(strcmpi(panelList, get(GlobalData.Program.GUI.panels(iPanel), 'name')));
            if ~isempty(iFound)
                panelRemove{end+1} = panelList{iFound};
                panelList(iFound) = [];
            end
        end
        % Create the list of possible new tabs
        for iPanel = 1:length(panelList)
            gui_component('MenuItem', jPopupTab, [], ['Add: ' panelList{iPanel}], [], [], @(h,ev)ShowToolTab(panelList{iPanel}));
        end
        if ~isempty(panelList) && ~isempty(panelRemove)
            jPopupTab.addSeparator();
        end
        % Create the list of tabs to remove
        for iPanel = 1:length(panelRemove)
            gui_component('MenuItem', jPopupTab, [], ['Close: ' panelRemove{iPanel}], [], [], @(h,ev)gui_hide(panelRemove{iPanel}));
        end
        % Show popup
        if (bst_get('JavaVersion') >= 1.6)
            ShowPopup(jPopupTab, jButtonPlus);
        else
            gui_popup(jPopupTab);
        end
    end

    %% ===== FILTER: HIDE POPUP MENU =====
    function HideFilterMenu()
        jTextFilter.setBorder([]);
    end

    %% ===== FILTER: RESET CALLBACK =====
    function ButtonFilterReset_Callback()
        SetFilterOption('Reset');
        jPopupFilter = CreateFilterMenu();
    end

    %% ===== FILTER: VALIDATE TEXT =====
    function ValidateTextFilter()
        % Validate modifications
        SetFilterOption('String', char(jTextFilter.getText()));
    end

%% ===== GUI UNLOAD ALL =====
    function GuiUnloadAll()
       bst_memory('UnloadAll', 'Forced');
       bst_progress('stop');
    end

%% ===== TOOLS PANEL CHANGED =====
    function ToolsPanelChanged_Callback(hObject, ev)
        % Get selected panel
        iSelPanel = jTabpaneTools.getSelectedIndex();
        if isempty(iSelPanel) || (iSelPanel < 0)
            return
        end
        % If it is the last panel (+)
        if (iSelPanel == jTabpaneTools.getTabCount()-1)
            SetSelectedTab(curTab, 0);
            drawnow;
            ShowTabMenu();
        else
            % Get panel title
            panelTitle = jTabpaneTools.getTitleAt(iSelPanel);
            % Notify all the "tools" panel from this change
            panel_scout('FocusChangedCallback', strcmpi(panelTitle, 'Scout'));
            panel_filter('FocusChangedCallback', strcmpi(panelTitle, 'Filter'));
            curTab = panelTitle;
        end
    end

%% ===== PROCESS PANEL CHANGED =====
    function ProcessPanelChanged_Callback(hObject, ev)
        % Get selected panel
        iSelPanel = jTabpaneProcess.getSelectedIndex();
        if isempty(iSelPanel) || (iSelPanel < 0)
            return
        end
        % Get panel title
        panelTitle = jTabpaneProcess.getTitleAt(iSelPanel);
        % Hide the tooloars when not wanted
        jToolbarB.setVisible(strcmpi(panelTitle, 'Process2'));
        jToolbarA.setVisible(~strcmpi(panelTitle, 'Guidelines'));
        jToolbarFilter.setVisible(~strcmpi(panelTitle, 'Guidelines'));
    end

%% ===== PROCESS: DATA TYPE CHANGED =====
    function ProcessDataType_Callback(DataType, listName, ev)
        % Update items counts in all trees
        bst_progress('start', 'File selection', 'Updating file count...');
        if strcmpi(listName, 'A')
            panel_nodelist('UpdatePanel', {'Process1', 'Process2A'}, 1);
        elseif strcmpi(listName, 'B')
            panel_nodelist('UpdatePanel', 'Process2B', 1);
        end
        bst_progress('stop');
    end

%% ===== PROCESS RUN =====
    function ProcessRun_Callback(h,ev)
        % Save scouts
        panel_scout('SaveModifications');
        % Validate modifications of the filters
        ValidateTextFilter();
        % Get selected process panel
        jTabProcess = bst_get('PanelContainer', 'process');
        selPanel = char(jTabProcess.getTitleAt(jTabProcess.getSelectedIndex()));
        % Call the appropriate function
        panel_fcn = str2func(['panel_' lower(selPanel)]);
        panel_fcn('RunProcess');
    end
end


%% ===== SHOW POPUP =====
function ShowPopup(jPopup, jControl, x, y)
    % If parent figure is not visible: do not display popup
    if isempty(jControl) || ~jControl.getTopLevelAncestor().isVisible()
        return;
    end
    % Get default x and y
    if (nargin < 4)
        x = 0;
        y = jControl.getHeight();
    end
    % Show popup menu
    try
        jPopup.show(jControl, x, y);
    catch
        % Try again to call the same function
        pause(0.1);
        disp('Call failed: calling again...');
        ShowPopup(jPopup, jControl);
    end
end
    
%% ===== PROCESS: SET FILE TYPE =====
function SetProcessFileType(fileType, nodelistName) %#ok<DEFNU>
    global GlobalData;
    GUI = GlobalData.Program.GUI.mainWindow;
    % Select button
    if (nargin < 2) || any(strcmpi(nodelistName, {'Process1', 'Process2A'}))
        switch lower(fileType)
            case {'data',     'pdata'},      GUI.jButtonRecordingsA.setSelected(1);
            case {'results',  'presults'},   GUI.jButtonSourcesA.setSelected(1);
            case {'timefreq', 'ptimefreq'},  GUI.jButtonTimefreqA.setSelected(1);
            case {'matrix',   'pmatrix'},    GUI.jButtonMatrixA.setSelected(1);
        end
    elseif strcmpi(nodelistName, 'Process2B')
        switch lower(fileType)
            case {'data',     'pdata'},      GUI.jButtonRecordingsB.setSelected(1);
            case {'results',  'presults'},   GUI.jButtonSourcesB.setSelected(1);
            case {'timefreq', 'ptimefreq'},  GUI.jButtonTimefreqB.setSelected(1);
            case {'matrix',   'pmatrix'},    GUI.jButtonMatrixB.setSelected(1);
        end
    end
    % Update file count (to update data type)
    panel_nodelist('UpdatePanel', [], 1);
end

%% ===== PROCESS: GET DATA TYPE =====
function DataType = GetProcessFileType(nodelistName) %#ok<DEFNU>
    global GlobalData;
    GUI = GlobalData.Program.GUI.mainWindow;
    % Get DataTypeA
    if any(strcmpi(nodelistName, {'Process1', 'Process2A'}))
        if GUI.jButtonRecordingsA.isSelected()
            DataType = 'data';
        elseif GUI.jButtonSourcesA.isSelected()
            DataType = 'results';
        elseif GUI.jButtonTimefreqA.isSelected()
            DataType = 'timefreq';
        elseif GUI.jButtonMatrixA.isSelected()
            DataType = 'matrix';
        end
    % Get DataTypeB
    elseif strcmpi(nodelistName, 'Process2B')
        if GUI.jButtonRecordingsB.isSelected()
            DataType = 'data';
        elseif GUI.jButtonSourcesB.isSelected()
            DataType = 'results';
        elseif GUI.jButtonTimefreqB.isSelected()
            DataType = 'timefreq';
        elseif GUI.jButtonMatrixB.isSelected()
            DataType = 'matrix';
        end
    else
        error('Invalid nodelist name.');
    end
end

%% ===== UPDATE PROTOCOLS LIST =====
% USAGE:  gui_brainstorm('UpdateProtocolsList');
function UpdateProtocolsList()
    import org.brainstorm.list.*;
    global GlobalData;
    % Sort protocols by name (alphabetic order)
    [tmp__, indProtocols] = sort(lower({GlobalData.DataBase.ProtocolInfo.Comment}));
    % Get the ComboBox java handle
    ctrl = bst_get('BstControls');
    % No protocol list
    if isempty(ctrl.jComboBoxProtocols)
        return;
    end
    % Save combobox callback
    jModel = ctrl.jComboBoxProtocols.getModel();
    bakCallback = java_getcb(jModel, 'ContentsChangedCallback');
    java_setcb(jModel, 'ContentsChangedCallback', []);
    % Empty the ComboBox
    ctrl.jComboBoxProtocols.removeAllItems();
    % Add all the database entries in the list of the combo box
    for i = 1:length(indProtocols)
        ctrl.jComboBoxProtocols.addItem(BstListItem('protocol', '', GlobalData.DataBase.ProtocolInfo(indProtocols(i)).Comment, indProtocols(i)))
    end
    % Set current protocol
    iProtocol = GlobalData.DataBase.iProtocol;
    if ~isempty(iProtocol) && isnumeric(iProtocol) && (iProtocol > 0) && (iProtocol < length(GlobalData.DataBase.ProtocolInfo))
        iSel = find(indProtocols == iProtocol);
        ctrl.jComboBoxProtocols.setSelectedIndex(iSel-1);
    end
    % Restore callback
    java_setcb(jModel, 'ContentsChangedCallback', bakCallback);
end


%% ===== SET CURRENT PROTOCOL =====
% USAGE:  gui_brainstorm('SetCurrentProtocol', iProtocol)
function SetCurrentProtocol(iProtocol)
    % Parse inputs
    if (nargin < 1) || isempty(iProtocol)
        iProtocol = bst_get('iProtocol');
    end
    if isempty(iProtocol)
        iProtocol = 0;
    end
    % Open progress bar
    isProgress = bst_progress('isVisible');
    if ~isProgress
        bst_progress('start', 'Set current protocol', 'Loading protocol...');
    end
    % Get GUI controls
    ctrl = bst_get('BstControls');
    jComboBoxProtocols = ctrl.jComboBoxProtocols;
    % Unload all the datasets of the previous protocol (also close all the windows)
    bst_memory('UnloadAll', 'Forced');
    % Was the protocol changed
    isProtocolChanged = ~isequal(bst_get('iProtocol'), iProtocol);
    % Save database only if protocol was changed
    if isProtocolChanged
        % Save the new current protocol
        bst_set('iProtocol', iProtocol);
        % Force modifications now
        db_save();
    end
    
    % If the protocol list is available
    if ~isempty(jComboBoxProtocols)
        % Look for the indice of the protocol in the combo box
        iItem = [];
        if isnumeric(iProtocol) && (iProtocol ~= 0)
            for i = 1:jComboBoxProtocols.getItemCount()
                iItemProt = jComboBoxProtocols.getItemAt(i-1).getUserData();
                if ~isempty(iItemProt) && (iItemProt == iProtocol)
                    iItem = i;
                    break;
                end
            end
        else
            iItem = 0;
        end
        % Save combobox callback
        jModel = jComboBoxProtocols.getModel();
        bakCallback = java_getcb(jModel, 'ContentsChangedCallback');
        % Make sure that the right item is selected in the protocols combox box
        if ~isempty(iItem) && (iItem-1 ~= jComboBoxProtocols.getSelectedIndex())
            java_setcb(jModel, 'ContentsChangedCallback', []);
            % Update list selection
            jComboBoxProtocols.setSelectedIndex(iItem-1);
            % Restore callback
            java_setcb(jModel, 'ContentsChangedCallback', bakCallback);
        end
        % Repaint box
        jComboBoxProtocols.invalidate();
        jComboBoxProtocols.repaint();
    end
    % ===== UPDATE GUI =====
    % Close any active searches
    panel_protocols('CloseAllDatabaseTabs');
    % Update tree model
    panel_protocols('UpdateTree');
    % Update "Time Window" 
    panel_time('UpdatePanel');
    % Reset processes and stat panels
    panel_nodelist('ResetAllLists');
    % Empty the clipboard
    bst_set('Clipboard', []);
    % Close guidelines panel
    gui_hide('Guidelines');
    
    % ===== CHECK FOLDERS =====
    % Check protocol folders
    ProtocolInfo = bst_get('ProtocolInfo');
    isRetry = ~isempty(ProtocolInfo);
    while isRetry
        if ~file_exist(ProtocolInfo.SUBJECTS) 
            folderError = bst_fileparts(ProtocolInfo.SUBJECTS, 1);
        elseif ~file_exist(ProtocolInfo.STUDIES)
            folderError = bst_fileparts(ProtocolInfo.STUDIES, 1);
        else
            folderError = [];
        end
        % If at least one folder is not available: ask the user what to do
        if ~isempty(folderError)
            % Make sure that the Splash screen is closed
            bst_splash('hide');
            % File does not exist: ask the user what to do
            res = java_dialog('question', [...
                'The following folder has been moved, deleted, or is on a drive that is currently', 10, ...
                'not connected to your computer. The protocol is currently inaccessible.' 10 ...
                'If the protocol can be found at another location, click on "Pick folder".' 10 10 ...
                folderError 10 10], ...
                'Load protocol', [], {'Pick folder...', 'Retry', 'Cancel'}, 'Cancel');
            % Cancel
            if isempty(res) || strcmpi(res, 'Cancel')
                bst_progress('stop');
                return;
            end
            % Retry
            if strcmpi(res, 'Retry')
                continue;
            % Pick folder
            else
                % Get protocol folder
                [subjectDir, studyDir, protocolName] = panel_protocol_editor('SelectProtocolDir');
                % Nothing selected: loop
                if isempty(subjectDir)
                    continue;
                end
                % When something is selected: update protocol
                ProtocolInfo.SUBJECTS = subjectDir;
                ProtocolInfo.STUDIES  = studyDir;
                ProtocolInfo.Comment  = protocolName;
                % Update protocol
                bst_set('ProtocolInfo', ProtocolInfo);
                % Redrawing tree
%                 UpdateProtocolsList();
                panel_protocols('UpdateTree');
%                 %%%%% DONT'T KNOW WHY WE HAVE TO RESTORE CALLBACK ON LINUX SYSTEMS ??? 
%                 if ~ispc
%                     java_setcb(jModel, 'ContentsChangedCallback', bakCallback);
%                 end
            end
        else
            isRetry = 0;
        end
    end
    
    % ===== CHECK READ-ONLY =====
    if ~isempty(ProtocolInfo)
        ProtocolFile = bst_fullfile(ProtocolInfo.STUDIES, 'protocol.mat');
        if (file_exist(ProtocolFile) && ~file_attrib(ProtocolFile, 'w')) || ~file_attrib(ProtocolInfo.STUDIES, 'w')
            % Set read-only interface
            bst_set('ReadOnly', 1);
            % If working in interactive mode: display a warning for read-only mode
            if bst_get('isGUI')
                % Make sure that the Splash screen is closed
                bst_splash('hide');
                % Display warning
                java_dialog('warning', ['You do not have the right to write in this folder:' 10 ...
                                        ProtocolInfo.STUDIES, 10 10, ...
                                        'Opening protocol in read-only mode.'], ...
                                       'Load protocol');
            else
                disp(['BST> Error: Insufficient rights to write the protocol file "' ProtocolFile '". Opening read-only.']);
            end
        else
            bst_set('ReadOnly', 0);
        end
    end
    
    % ===== LOAD PROTOCOL =====
    if ~bst_get('isProtocolLoaded')
        db_load_protocol(iProtocol);
    end
    % Close progress bar
    if ~isProgress
        bst_progress('stop');
    end
end


%% ===== CREATE PROTOCOL =====
function iProtocol = CreateProtocol(ProtocolName, UseDefaultAnat, UseDefaultChannel, DbDir) %#ok<DEFNU>
    % Get Brainstorm directory
    if (nargin < 4) || isempty(DbDir)
        DbDir = bst_get('BrainstormDbDir');
        if isempty(DbDir)
            error('Please set the database folder before calling this function.');
        end
    end
    % Standardize protocol name
    ProtocolName = file_standardize(ProtocolName);
    % Create protocol structure
    sProtocol = db_template('ProtocolInfo');
    sProtocol.Comment           = ProtocolName;
    sProtocol.SUBJECTS          = fullfile(DbDir, ProtocolName, 'anat');
    sProtocol.STUDIES           = fullfile(DbDir, ProtocolName, 'data');
    sProtocol.UseDefaultAnat    = UseDefaultAnat;
    sProtocol.UseDefaultChannel = UseDefaultChannel;
    % Add the protocol to Brainstorm database
    iProtocol = db_edit_protocol('create', sProtocol);
    % If an error occured in protocol creation (protocol already exists, impossible to create folders...)
    if (iProtocol <= 0)
        error('Could not create protocol.');
    end
    % Set new protocol as current protocol
    SetCurrentProtocol(iProtocol);
    % Set default anatomy: ICBM152
    sTemplate = bst_get('AnatomyDefaults', 'ICBM152');
    db_set_template(0, sTemplate(1), 0);
end


%% ===== DELETE PROTOCOL =====
function DeleteProtocol(ProtocolName) %#ok<DEFNU>
    % Get protocol
    iProtocol = bst_get('Protocol', ProtocolName);
    % If protocol exists
    if ~isempty(iProtocol)
        % Set as current protocol
        SetCurrentProtocol(iProtocol);
        % Delete protocol
        db_delete_protocol(0, 1);
        % Display message
        % disp(['BST> Protocol "' ProtocolName '" deleted.']);
    else
        % disp(['BST> Protocol "' ProtocolName '" does not exist.']);
    end
end


%% ===== SET SELECTED TAB =====
function SetSelectedTab(tabTitle, isAutoSelect, containerName)
    % Parse inputs
    if (nargin < 3) || isempty(containerName)
        containerName = 'Tools';
    end
    if (nargin < 2) || isempty(isAutoSelect)
        isAutoSelect = 1;
    end
    % Get Tools panel container
    jTabpaneTools = bst_get('PanelContainer', containerName);
    if isempty(jTabpaneTools)
        return;
    end
    % Check if the requirements are met to allow auto-select
    if isAutoSelect
        % If there are more than one figure: do not allow
        if (length(bst_figures('GetAllFigures')) > 1)
            return;
        end
        % Get name of currently selected tab
        tabPrev = char(jTabpaneTools.getTitleAt(jTabpaneTools.getSelectedIndex));
        % Do not switch between Surface and Scout
        if (strcmpi(tabPrev,'Scout') && strcmpi(tabTitle,'Surface')) || (strcmpi(tabTitle,'Scout') && strcmpi(tabPrev,'Surface'))
            return;
        end
    end
    % Look for panel in Tools tabbed panel
    for i = 0:jTabpaneTools.getTabCount()-1
        if strcmpi(char(jTabpaneTools.getTitleAt(i)), tabTitle)
            jTabpaneTools.setSelectedIndex(i);
        end
    end
end

%% ===== SET TOOL TAB COLOR =====
function SetToolTabColor(tabTitle, color) %#ok<DEFNU>
    % Get Tools panel container
    jTabpaneTools = bst_get('PanelContainer', 'Tools');
    if isempty(jTabpaneTools)
        return;
    end
    % Look for panel in Tools tabbed panel
    for i = 0:jTabpaneTools.getTabCount()-1
        if strcmpi(char(jTabpaneTools.getTitleAt(i)), tabTitle)
            jTabpaneTools.setForegroundAt(i, java.awt.Color(color(1),color(2),color(3)));
        end
    end
end


%% ===== SHOW TOOL TAB =====
function ShowToolTab(tabTitle)
    % Headless mode: return
    if (bst_get('GuiLevel') == -1)
        return;
    end
    % Specific case: Frequency
    if strcmpi(tabTitle, 'FreqPanel')
        jPanelFreq = bst_get('PanelContainer', 'freq');
        if ~isempty(jPanelFreq)
            jPanelFreq.setVisible(1);
        end
        return;
    end
    % Get function
    fcnName = ['panel_' lower(tabTitle)];
    if ~exist(fcnName, 'file')
        error(['Unknown tab: ' tabTitle]);
    end
    % Create tab if not displayed yet
    if ~isTabVisible(tabTitle)
        gui_show(fcnName, 'BrainstormTab', 'tools');
    end
    % Initialize tabs
    switch (tabTitle)
        case 'Record'
            panel_record('InitializePanel');
            panel_record('UpdatePanel');
        case 'Scout'
            panel_scout('UpdatePanel');
        case 'Surface'
            panel_surface('UpdatePanel');
        case 'iEEG'
            panel_ieeg('UpdatePanel');
    end
    % Select tab
    SetSelectedTab(tabTitle, 0);
end

%% ===== CHECK IF TAB IS VISIBLE =====
function isVisible = isTabVisible(tabTitle)
    isVisible = ~isempty(bst_get('Panel', tabTitle));
end


%% ===== CONVERT KEYBOARD EVENTS =====
% Convert any key event to Matlab structure
function [keyEvent, isControl, isShift] = ConvertKeyEvent(ev) %#ok<DEFNU>
    import java.awt.event.KeyEvent;
    keyEvent.Key = [];
    keyEvent.Modifier = {};
    keyEvent.Character = '';
    switch class(ev)
        case 'char'
            keyEvent.Key = ev;
        case 'struct'
            keyEvent = ev;
        case 'matlab.ui.eventdata.KeyData'   % Added with Matlab 2014b
            keyEvent.Key       = ev.Key;
            keyEvent.Modifier  = ev.Modifier;
            keyEvent.Character = ev.Character;
        case 'java.awt.event.KeyEvent'
            switch (ev.getKeyCode())
                % LETTERS
                case KeyEvent.VK_A,          keyEvent.Key = 'a';
                case KeyEvent.VK_B,          keyEvent.Key = 'b';
                case KeyEvent.VK_C,          keyEvent.Key = 'c';
                case KeyEvent.VK_D,          keyEvent.Key = 'd';
                case KeyEvent.VK_E,          keyEvent.Key = 'e';
                case KeyEvent.VK_F,          keyEvent.Key = 'f';
                case KeyEvent.VK_G,          keyEvent.Key = 'g';
                case KeyEvent.VK_H,          keyEvent.Key = 'h';
                case KeyEvent.VK_I,          keyEvent.Key = 'i';
                case KeyEvent.VK_J,          keyEvent.Key = 'j';
                case KeyEvent.VK_K,          keyEvent.Key = 'k';
                case KeyEvent.VK_L,          keyEvent.Key = 'l';
                case KeyEvent.VK_M,          keyEvent.Key = 'm';
                case KeyEvent.VK_N,          keyEvent.Key = 'n';
                case KeyEvent.VK_O,          keyEvent.Key = 'o';
                case KeyEvent.VK_P,          keyEvent.Key = 'p';
                case KeyEvent.VK_Q,          keyEvent.Key = 'q';
                case KeyEvent.VK_R,          keyEvent.Key = 'r';
                case KeyEvent.VK_S,          keyEvent.Key = 's';
                case KeyEvent.VK_T,          keyEvent.Key = 't';
                case KeyEvent.VK_U,          keyEvent.Key = 'u';
                case KeyEvent.VK_V,          keyEvent.Key = 'v';
                case KeyEvent.VK_W,          keyEvent.Key = 'w';
                case KeyEvent.VK_X,          keyEvent.Key = 'x';
                case KeyEvent.VK_Y,          keyEvent.Key = 'y';
                case KeyEvent.VK_Z,          keyEvent.Key = 'z';
                % NUMBERS
                case {KeyEvent.VK_0, KeyEvent.VK_NUMPAD0},  keyEvent.Key = '0';
                case {KeyEvent.VK_1, KeyEvent.VK_NUMPAD1},  keyEvent.Key = '1';
                case {KeyEvent.VK_2, KeyEvent.VK_NUMPAD2},  keyEvent.Key = '2';
                case {KeyEvent.VK_3, KeyEvent.VK_NUMPAD3},  keyEvent.Key = '3';
                case {KeyEvent.VK_4, KeyEvent.VK_NUMPAD4},  keyEvent.Key = '4';
                case {KeyEvent.VK_5, KeyEvent.VK_NUMPAD5},  keyEvent.Key = '5';
                case {KeyEvent.VK_6, KeyEvent.VK_NUMPAD6},  keyEvent.Key = '6';
                case {KeyEvent.VK_7, KeyEvent.VK_NUMPAD7},  keyEvent.Key = '7';
                case {KeyEvent.VK_8, KeyEvent.VK_NUMPAD8},  keyEvent.Key = '8';
                case {KeyEvent.VK_9, KeyEvent.VK_NUMPAD9},  keyEvent.Key = '9';
                % SIGNS
                case {KeyEvent.VK_ADD,      KeyEvent.VK_PLUS},   keyEvent.Key = 'add';
                case {KeyEvent.VK_SUBTRACT, KeyEvent.VK_MINUS},  keyEvent.Key = 'subtract';
                case KeyEvent.VK_EQUALS,                         keyEvent.Key = 'equal';
                % F-KEYS
                case KeyEvent.VK_F1,         keyEvent.Key = 'f1';
                case KeyEvent.VK_F2,         keyEvent.Key = 'f2';
                case KeyEvent.VK_F3,         keyEvent.Key = 'f3';
                case KeyEvent.VK_F4,         keyEvent.Key = 'f4';
                case KeyEvent.VK_F5,         keyEvent.Key = 'f5';
                case KeyEvent.VK_F6,         keyEvent.Key = 'f6';
                case KeyEvent.VK_F7,         keyEvent.Key = 'f7';
                case KeyEvent.VK_F8,         keyEvent.Key = 'f8';
                case KeyEvent.VK_F9,         keyEvent.Key = 'f9';
                % ARROWS
                case KeyEvent.VK_LEFT,       keyEvent.Key = 'leftarrow';
                case KeyEvent.VK_DOWN,       keyEvent.Key = 'downarrow';
                case KeyEvent.VK_RIGHT,      keyEvent.Key = 'rightarrow';
                case KeyEvent.VK_UP,         keyEvent.Key = 'uparrow';
                case KeyEvent.VK_PAGE_DOWN,  keyEvent.Key = 'pagedown';
                case KeyEvent.VK_PAGE_UP,    keyEvent.Key = 'pageup';
                % CONTROLS
                case KeyEvent.VK_ESCAPE,     keyEvent.Key = 'escape';
                case KeyEvent.VK_ENTER,      keyEvent.Key = 'return';
                case KeyEvent.VK_DELETE,     keyEvent.Key = 'delete';
                case KeyEvent.VK_BACK_SPACE, keyEvent.Key = 'delete';
                case KeyEvent.VK_CONTROL,    keyEvent.Key = 'control';
                case KeyEvent.VK_SHIFT,      keyEvent.Key = 'shift';
                case KeyEvent.VK_ALT,        keyEvent.Key = 'alt';
                otherwise,                   disp('BST> Unhandle key event...');  
            end
            if ev.isShiftDown()
                keyEvent.Modifier{end+1} = 'shift';
            end
            if ev.isControlDown()
                keyEvent.Modifier{end+1} = 'control';
            end
            if ev.isAltDown()
                keyEvent.Modifier{end+1} = 'alt';
            end
        otherwise
            disp('BST> Unknown key event...');
    end
    isControl = ismember('control', keyEvent.Modifier);
    isShift   = ismember('shift',   keyEvent.Modifier);
end


%% ===== SET DATABASE FOLDER =====
function BrainstormDbDir = SetDatabaseFolder(varargin) %#ok<DEFNU>
    % Get current database folder
    BrainstormDbDir = bst_get('BrainstormDbDir');
    % Default directory
    if isempty(BrainstormDbDir)
        BrainstormDbDir = bst_get('UserDir');
    end
    % Loop until a correct folder was picked
    isStop = 0;
    while ~isStop
        % Open 'Select directory' dialog
        BrainstormDbDir = bst_uigetdir(BrainstormDbDir, ['Please select Brainstorm database directory.' 10 10 'This is where all the new protocols will be created.']);
        % Exit if not set
        if isempty(BrainstormDbDir) || ~ischar(BrainstormDbDir)
            BrainstormDbDir = [];
            return;
        elseif ~isempty(file_find(BrainstormDbDir, 'brainstormsubject*.mat', 3))
            bst_error(['The folder you selected is probably a protocol folder:' 10 BrainstormDbDir 10 10 ...
                'The database folder is designed to contain multiple protocol folders.' 10 ...
                'Please select a valid database folder.'], 'Database folder', 0);
        elseif file_compare(bst_get('BrainstormTmpDir'), BrainstormDbDir)
            bst_error('Your temporary and database directories must be different.', 'Database folder', 0);
        elseif dir_contains(bst_get('BrainstormTmpDir'), BrainstormDbDir)
            bst_error('Your temporary directory cannot contain your database directory.', 'Database folder', 0);
        elseif file_compare(bst_get('BrainstormHomeDir'), BrainstormDbDir)
            bst_error('Your application and database directories must be different.', 'Database folder', 0);
        elseif dir_contains(bst_get('BrainstormHomeDir'), BrainstormDbDir)
            bst_error('Your application directory cannot contain your database directory.', 'Database folder', 0);
        else
            isStop = 1;
        end
    end
    % Save brainstorm directory
    bst_set('BrainstormDbDir', BrainstormDbDir);
end


%% ===== CHANGE DATABASE FOLDER =====
% Unload all loaded protocols and load protocols from a different folder
function ChangeDatabaseFolder()
    global GlobalData;
    % Select new database folder
    BrainstormDbDir = SetDatabaseFolder();
    if isempty(BrainstormDbDir)
        return;
    end
    % Get the current protocol: if not empty, there are existing protocols to unload
    iProtocol = bst_get('iProtocol');
    if ~isempty(iProtocol) && (iProtocol >= 1)
        % Ask if user wants to unload all the existing protocols
        isUnload = java_dialog('confirm', 'Unload all the existing protocols ?', 'Change database folder');
        % Unload all protocols
        if isUnload
            % Reset all the structures
            GlobalData.DataBase.ProtocolInfo(:)     = [];
            GlobalData.DataBase.ProtocolSubjects(:) = [];
            GlobalData.DataBase.ProtocolStudies(:)  = [];
            GlobalData.DataBase.isProtocolLoaded    = [];
            GlobalData.DataBase.isProtocolModified  = [];
            % Select current protocol in combo list
            SetCurrentProtocol(0);
            % Update interface
            UpdateProtocolsList();
            panel_protocols('UpdateTree');
        end
    end
    % Import new database
    db_import(BrainstormDbDir);
end


%% ===== EMPTY TEMPORARY FOLDER =====
function isDeleted = EmptyTempFolder()
    % Get temporary directory
    tmpDir = bst_get('BrainstormTmpDir');
    % Make sure Matlab is not currently in a subfolder of the temp directory
    if ~isempty(strfind(pwd, tmpDir)) && ~file_compare(pwd, tmpDir)
        cd(tmpDir);
    end
    % If directory exists
    if isdir(tmpDir)
        disp('BST> Emptying temporary directory...');
        % Delete contents of directory
        tmpFiles = dir(bst_fullfile(tmpDir, '*'));
        tmpFiles = setdiff({tmpFiles.name}, {'.','..'});
        tmpFiles = cellfun(@(c)bst_fullfile(tmpDir,c), tmpFiles, 'UniformOutput', 0);
        isDeleted = file_delete(tmpFiles, 1, 3);
    else 
        isDeleted = 0;
    end
end


%% ===== SET FILTER OPTIONS =====
function SetFilterOption(FieldName, Value)
    global GlobalData;
    % If brainstorm is not running or currently closing
    if isempty(GlobalData)
        return;
    end
    % Reset file selection
    if strcmpi(FieldName, 'Reset')
        % Save modified values
        bst_set('NodelistOptions', []);
        % Empty text field
        GlobalData.Program.GUI.mainWindow.jTextFilter.setText('');
        % Take focus away 
        % GlobalData.Program.GUI.mainWindow.jComboBoxProtocols.grabFocus();
    else
        % Get previous options
        NodelistOptions = bst_get('NodelistOptions');
        % Check if current value is modified
        if isequal(NodelistOptions.(FieldName), Value)
            return;
        end
        % Update target field
        NodelistOptions.(FieldName) = Value;
        % Save modified values
        bst_set('NodelistOptions', NodelistOptions);
    end
    % Update file count
    bst_progress('start', 'File filters', 'Updating list...');
    panel_nodelist('UpdatePanel', [], 1);
    bst_progress('stop');
end


%% ===== SET EXPLORATION MODE =====
function SetExplorationMode(ExplorationMode) %#ok<DEFNU>
    global GlobalData;
    GUI = GlobalData.Program.GUI.mainWindow;
    % If the mode didn't change: don't do anything
    if strcmpi(ExplorationMode, bst_get('Layout', 'ExplorationMode'))
        return;
    end
    % Select appropriate button
    switch (ExplorationMode)
        case 'Subjects'
            GUI.jToolButtonSubject.setSelected(1);
        case 'StudiesSubj'
            GUI.jToolButtonStudiesSubj.setSelected(1);
        case 'StudiesCond'
            GUI.jToolButtonStudiesCond.setSelected(1);
        otherwise
            error('Invalid exploration mode.');
    end
    % Update the Layout structure
    bst_set('Layout', 'ExplorationMode', ExplorationMode);
    % Update tree display
    panel_protocols('UpdateTree');
end


%% ===== DOWNLOAD OPENMEEG =====
function DownloadOpenmeeg()
    % Display information message
    java_dialog('msgbox', [...
        'You will be directed to the OpenMEEG website:' 10 ...
        ' - Download an installer adapted to your operating system (.tar.gz only)' 10 ...
        ' - Click on the menu "Help > Update OpenMEEG > Install"' 10 ...
        ' - Select the downloaded .tar.gz file'], 'Download OpenMEEG');
    % Open web browser
    try
        web('http://openmeeg.gforge.inria.fr/download/', '-browser');
    catch
    end
end
%% ===== DOWNLOAD FILE =====
function errMsg = DownloadFile(srcUrl, destFile, wndTitle) %#ok<DEFNU>
    errMsg = [];
    % Parse inputs
    if (nargin < 3) || isempty(wndTitle)
        wndTitle = 'Download file';
    end
    % Headless mode: use Matlab base functions
    if (bst_get('GuiLevel') == -1)
        errMsg = bst_websave(destFile, srcUrl);
    % Github: Problem with our downloaded: use websave instead
    elseif (length(srcUrl) > 18) && strcmpi(srcUrl(1:18), 'https://github.com')
        % Open progress bar
        isProgress = bst_progress('isVisible');
        if ~isProgress
            bst_progress('start', wndTitle, ['Downloading: ' srcUrl]);
        else
            bst_progress('text', ['Downloading: ' srcUrl]);
        end
        % Create folder if needed
        if ~isdir(bst_fileparts(destFile))
            mkdir(bst_fileparts(destFile));
        end
        % Download file
        errMsg = bst_websave(destFile, srcUrl);
        % Close progress bar
        if ~isProgress
            bst_progress('stop');
        end
    else
        % Get system proxy definition, if available
        if exist('com.mathworks.mlwidgets.html.HTMLPrefs', 'class') && exist('com.mathworks.webproxy.WebproxyFactory', 'class') && ismethod('com.mathworks.webproxy.WebproxyFactory', 'findProxyForURL')
            com.mathworks.mlwidgets.html.HTMLPrefs.setProxySettings;
            proxy = com.mathworks.webproxy.WebproxyFactory.findProxyForURL(java.net.URL(srcUrl));
        else
            proxy = [];
        end
        % Start the download
        downloadManager = java_create('org.brainstorm.file.BstDownload', 'Ljava.lang.String;Ljava.lang.String;Ljava.lang.String;)', srcUrl, destFile, wndTitle);
        if ~isempty(proxy)
            downloadManager.download(proxy);
        else
            downloadManager.download();
        end
        % Wait for the termination of the thread
        while (downloadManager.getResult() == -1)
            pause(0.2);
        end
        % If file was not downloaded correctly
        if (downloadManager.getResult() ~= 1)
            errMsg = char(downloadManager.getMessage());
            % Delete partially downloaded file
            if file_exist(destFile)
                file_delete(destFile, 1);
            end
        end
    end
end


%% ===== MAKE PROTOCOL PORTABLE =====
function MakeProtocolPortable()
    % Progress bar
    bst_progress('start', 'Make protocol portable', 'Analyzing database');
    % Get all the protocol data structures
    ProtocolStudies = bst_get('ProtocolStudies');
    AllData = [ProtocolStudies.Study.Data];
    % Get all the raw data files in this protocol
    iDataRaw = find(strcmpi({AllData.DataType}, 'raw'));
    % Check if the files are already in the database or not
    isExternal = false(1,length(iDataRaw));
    for i = 1:length(iDataRaw)
        isExternal(i) = isempty(dir(bst_fullfile(bst_fileparts(file_fullpath(AllData(iDataRaw(i)).FileName)), '*.bst')));
    end
    iDataRaw(~isExternal) = [];
    % Close progress bar
    bst_progress('stop');
    % Nothing to process
    if isempty(iDataRaw)
        java_dialog('msgbox', 'There are no external raw files attached to this protocol.', 'Make protocol portable');
        return;
    end
    % Ask for confirmation
    if ~java_dialog('confirm', 'Copy all the external raw files in the protocol folder?', 'Make protocol portable')
        return;
    end
    % Import all the external raw files
    panel_record('CopyRawToDatabase', {AllData(iDataRaw).FileName});
end


%% ===== SHOW GUIDELINES =====
function ShowGuidelines(ScenarioName)
    % Close tab if it already exists
    panelName = 'Guidelines';
    if isTabVisible(panelName)
        gui_hide(panelName);
    end
    % Resize the bottom panel
    GUI = bst_get('BstControls');
    InterfaceScaling = bst_get('InterfaceScaling') / 100;
    Hmin = round(300 * InterfaceScaling);
    Hfig = GUI.jBstFrame.getHeight();
    if (Hfig - GUI.jSplitH.getDividerLocation() < Hmin)
        GUI.jSplitH.setDividerLocation(uint32(Hfig - Hmin));
    end
    % Create guidelines panel
    bstPanel = panel_guidelines('CreatePanel', ScenarioName);
    % Open tab new tab
    gui_show(bstPanel, 'BrainstormTab', 'process');

    % Initialize first tab
    panel_guidelines('SwitchPanel', 'next');
    % Select tab
    SetSelectedTab(panelName, 0, 'Process');
end


%% ===== CLONE PROBE =====
function status = CloneProble(bstDir)
    status = -1;
    % Check if there are any GIT files in the folder
    if ~file_exist(bst_fullfile(bstDir, 'LICENSE')) && ~file_exist(bst_fullfile(bstDir, 'README.md'))
        status = 1;
        return;
    end
    % If Matlab version too old: try using the older Java login
    if (bst_get('MatlabVersion') < 901)
        status = org.brainstorm.dialogs.CloneControl.probe(bst_get('BrainstormHomeDir'));
        return;
    end
    % Allow multiple trials
    while (status == -1)
        % Get username and password
        res = java_dialog('input', ...
            {['<HTML>You got this version of Brainstorm from GitHub.<BR><BR>' 10 10 ...
             'Please take a minute to register on our website before using the software:<BR>' 10 ...
             'https://neuroimage.usc.edu/brainstorm > Download > Create an account now<BR><BR><FONT color="#999999">' ... 
             'This project is supported by public grants. Keeping track of usage demographics <BR>' ...
             'is key to document the impact of Brainstorm and obtain continued support.<BR>' ...
             'Please take a moment to create a free account - thank you.</FONT><BR><BR>' ...
             'Email or username:'], 'Password:'}, 'Brainstorm login');
        % If user aborted
        if isempty(res) || (length(res) ~= 2)
            status = 0;
            return;
        end
        % Connect
        bst_progress('start', 'Brainstorm login', 'Contacting server');
        try
            % Send connect request
            header = matlab.net.http.field.ContentTypeField('application/x-www-form-urlencoded');
            options = matlab.net.http.HTTPOptions();
            request = matlab.net.http.RequestMessage(matlab.net.http.RequestMethod.POST, header, ['email=',res{1},'&mdp=',res{2}]);
            resp = send(request, 'https://neuroimage.usc.edu/bst/check_user.php', options);
            % Check server response
            if isempty(resp) || isempty(resp.Body) || ~isa(resp.Body, 'matlab.net.http.MessageBody')
                status = 0;
            elseif strcmp(resp.Body.Data, '1')
                status = 1;
            else
                bst_error('Invalid username or password.', 'Brainstorm login', 0);
            end
        catch
            status = 0;
        end
        bst_progress('stop');
    end
end
