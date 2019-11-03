function varargout = panel_options(varargin)
% PANEL_OPTIONS:  Set general Brainstorm configuration.
%
% USAGE:  [bstPanelNew, panelName] = panel_options('CreatePanel')
%                                    panel_options('SystemPathRemove', rmPath)          % Update system path
%                             PATH = panel_options('SystemPathRemove', rmPath, PATH)    % Update user defined path (do not change system path)

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
% Authors: Francois Tadel, 2009-2019

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel() %#ok<DEFNU>
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    global GlobalData;
    % Constants
    panelName = 'Preferences';
    isCompiled = exist('isdeployed', 'builtin') && isdeployed;
    
    % Create main main panel
    jPanelNew = gui_river();
    
    % ===== LEFT =====
    jPanelLeft = gui_river();
    jPanelNew.add('vtop', jPanelLeft);
    % ===== LEFT: SYSTEM =====
    jPanelSystem = gui_river([5 2], [0 15 8 15], 'System');
        jCheckUpdates    = gui_component('CheckBox', jPanelSystem, 'br', 'Automatic updates', [], [], []);
        if (bst_get('MatlabVersion') >= 804)
            jCheckSmooth = gui_component('CheckBox', jPanelSystem, 'br', 'Use smooth Matlab graphics', [], [], []);
        else
            jCheckSmooth = [];
        end
        jCheckDownsample = gui_component('CheckBox', jPanelSystem, 'br', 'Downsample recordings for faster display', [], [], []);
        jCheckGfp        = gui_component('CheckBox', jPanelSystem, 'br', 'Display GFP over time series', [], [], []);
        jCheckForceComp  = gui_component('CheckBox', jPanelSystem, 'br', 'Force mat-files compression (slower)', [], [], []);
        jCheckIgnoreMem  = gui_component('CheckBox', jPanelSystem, 'br', 'Ignore memory warnings', [], [], []);
        if ~ispc
            jCheckSystemCopy  = gui_component('CheckBox', jPanelSystem, 'br', 'Use system calls to copy/move files', [], [], []);
        else
            jCheckSystemCopy = [];
        end
    jPanelLeft.add('hfill', jPanelSystem);
    % ===== LEFT: OPEN GL =====
    jPanelOpengl = gui_river([5 2], [0 15 8 15], 'OpenGL rendering');
        jRadioOpenNone = gui_component('Radio', jPanelOpengl, '',   'OpenGL: Disabled (no transparency)', [], [], []);
        jRadioOpenSoft = gui_component('Radio', jPanelOpengl, 'br', 'OpenGL: Software (slow)', [], [], []);
        jRadioOpenHard = gui_component('Radio', jPanelOpengl, 'br', 'OpenGL: Hardware (accelerated)', [], [], []);
        % Group buttons
        jButtonGroup = ButtonGroup();
        jButtonGroup.add(jRadioOpenNone);
        jButtonGroup.add(jRadioOpenSoft);
        jButtonGroup.add(jRadioOpenHard);
        % On mac systems: opengl software is not supported
        if strncmp(computer,'MAC',3)
            jRadioOpenSoft.setEnabled(0);
        end
    jPanelLeft.add('br hfill', jPanelOpengl);
    % ===== LEFT: INTERFACE SCALING =====
    jPanelScaling = gui_river([5 2], [0 0 5 0], 'Interface scaling (%)');
        % Slider labels
        labelTable = java.util.Hashtable();
        labelTable.put(uint32(1), gui_component('label',[],'','100'));
        labelTable.put(uint32(2), gui_component('label',[],'','125'));
        labelTable.put(uint32(3), gui_component('label',[],'','150'));
        labelTable.put(uint32(4), gui_component('label',[],'','200'));
        labelTable.put(uint32(5), gui_component('label',[],'','250'));
        labelTable.put(uint32(6), gui_component('label',[],'','300'));
        labelTable.put(uint32(7), gui_component('label',[],'','400'));
        % Slider config
        jSliderScaling = JSlider(1,7,1);
        jSliderScaling.setLabelTable(labelTable);
        jSliderScaling.setPaintTicks(1);
        jSliderScaling.setMajorTickSpacing(1);
        jSliderScaling.setPaintLabels(1);
        jPanelScaling.add('hfill', jSliderScaling);
    jPanelLeft.add('br hfill', jPanelScaling);
    
    % ===== LEFT: RESET =====
    if (GlobalData.Program.GuiLevel == 1)
        jPanelReset = gui_river([5 5], [0 15 15 15], 'Reset Brainstorm');
            gui_component('Label',  jPanelReset, [], 'Reset database and options to defaults: ', [], [], []);
            gui_component('Button', jPanelReset, [], 'Reset', [], [], @ButtonReset_Callback);
        jPanelLeft.add('br hfill', jPanelReset);
    end
    
    
    % ===== RIGHT =====
    jPanelRight = gui_river();
    jPanelNew.add(jPanelRight);
    % ===== RIGHT: FOLDERS =====
    jPanelImport = gui_river([5 5], [0 15 15 15], 'Folders');
        % Temporary directory
        gui_component('Label', jPanelImport, '', 'Temporary directory: ', [], [], []);
        jTextTempDir   = gui_component('Text', jPanelImport, 'br hfill', '', [], [], []);
        jButtonTempDir = gui_component('Button', jPanelImport, [], '...', [], [], @TempDirectory_Callback);
        jButtonTempDir.setMargin(Insets(2,2,2,2));
        jButtonTempDir.setFocusable(0);
        % External toolboxes (only in non-compiled mode)
        if ~isCompiled
            % FieldTrip folder
            gui_component('Label', jPanelImport, 'br', 'FieldTrip toolbox: ', [], [], []);
            jTextFtDir   = gui_component('Text', jPanelImport, 'br hfill', '', [], [], []);
            jButtonFtDir = gui_component('Button', jPanelImport, [], '...', [], [], @FtDirectory_Callback);
            jButtonFtDir.setMargin(Insets(2,2,2,2));
            jButtonFtDir.setFocusable(0);
            % SPM folder
            gui_component('Label', jPanelImport, 'br', 'SPM toolbox: ', [], [], []);
            jTextSpmDir   = gui_component('Text', jPanelImport, 'br hfill', '', [], [], []);
            jButtonSpmDir = gui_component('Button', jPanelImport, [], '...', [], [], @SpmDirectory_Callback);
            jButtonSpmDir.setMargin(Insets(2,2,2,2));
            jButtonSpmDir.setFocusable(0);
        else
            jTextFtDir = [];
            jTextSpmDir = [];
        end
    jPanelRight.add('br hfill', jPanelImport);
    
    % ===== RIGHT: MNE-PYTHON =====
    jPanelMne = gui_river([5 5], [0 15 15 15], 'MNE-Python');
        % Python executable
        gui_component('Label', jPanelMne, '', 'Python executable: ', [], [], []);
        jTextPythonExe   = gui_component('Text', jPanelMne, 'br hfill', '', [], [], []);
        jButtonPythonExe = gui_component('Button', jPanelMne, [], '...', [], [], @PythonExe_Callback);
        jButtonPythonExe.setMargin(Insets(2,2,2,2));
        jButtonPythonExe.setFocusable(0);
        % System path
        gui_component('Label', jPanelMne, 'br', 'System PATH for Python (separated with semi-colon): ', [], [], []);
        jTextPythonPath = gui_component('Text', jPanelMne, 'br hfill', '', [], [], []);
        jButtonAddPath = gui_component('Button', jPanelMne, [], ' + ', [], [], @AddPath_Callback);
        jButtonAddPath.setMargin(Insets(2,2,2,2));
        jButtonAddPath.setFocusable(0);
        % Qt path
        gui_component('Label', jPanelMne, 'br', 'Qt platform plugin (QT_QPA_PLATFORM_PLUGIN_PATH): ', [], [], []);
        jTextQtDir   = gui_component('Text', jPanelMne, 'br hfill', '', [], [], []);
        jButtonQtDir = gui_component('Button', jPanelMne, [], '...', [], [], @QtDirectory_Callback);
        jButtonQtDir.setMargin(Insets(2,2,2,2));
        jButtonQtDir.setFocusable(0);
    jPanelRight.add('br hfill', jPanelMne);
    
    % ===== RIGHT: SIGNAL PROCESSING =====
    jPanelProc = gui_river([5 5], [0 15 15 15], 'Processing');
        jCheckUseSigProc = gui_component('CheckBox', jPanelProc, 'br', 'Use Signal Processing Toolbox (Matlab)',    [], '<HTML>If selected, some processes will use the Matlab''s Signal Processing Toolbox functions.<BR>Else, use only the basic Matlab function.', []);
        jBlockSizeLabel = gui_component('Label',  jPanelProc, 'br', 'Memory block size in Mb (default: 100Mb): ', [], [], []);
        blockSizeTooltip = '<HTML>Maximum size of data blocks to be read in memory, in megabytes.<BR>Ensure this does not exceed the available RAM in your computer.';
        jBlockSize = gui_component('Text',  jPanelProc, [], '', [], [], []);
        jBlockSizeLabel.setToolTipText(blockSizeTooltip);
        jBlockSize.setToolTipText(blockSizeTooltip);
    jPanelRight.add('br hfill', jPanelProc);
    
    % ===== BOTTOM =====
    jPanelBottom = gui_river();
    jPanelNew.add('br hfill', jPanelBottom);
    % MEMORY
    [MaxVar, TotalMem] = bst_get('SystemMemory');
    if ~isempty(MaxVar) && ~isempty(TotalMem)
        % Display memory info
        jPanelMem = gui_river([0 0], [0 15 8 15]);
        labelBottom = sprintf('Max variable size: %d Mb       Memory available: %d Mb', MaxVar, TotalMem);
        jPanelLeft.add('br hfill', jPanelMem);
    else
        labelBottom = '';
    end
    
    % ===== VALIDATION BUTTONS =====
    gui_component('Label', jPanelBottom, '', labelBottom, [], [], []);
    gui_component('Label', jPanelBottom, 'hfill', ' ');
    gui_component('Button', jPanelBottom, 'right', 'Cancel', [], [], @ButtonCancel_Callback);
    gui_component('Button', jPanelBottom, [], 'Save', [], [], @ButtonSave_Callback);

    % ===== LOAD OPTIONS =====
    LoadOptions();
    
    % ===== CREATE PANEL =====   
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct());
                              

%% =================================================================================
%  === CONTROLS CALLBACKS  =========================================================
%  =================================================================================
%% ===== LOAD OPTIONS =====
    function LoadOptions()
        % GUI
        jCheckForceComp.setSelected(bst_get('ForceMatCompression'));
        jCheckUpdates.setSelected(bst_get('AutoUpdates'));
        jCheckGfp.setSelected(bst_get('DisplayGFP'));
        jCheckDownsample.setSelected(bst_get('DownsampleTimeSeries') > 0);
        jCheckIgnoreMem.setSelected(bst_get('IgnoreMemoryWarnings'));
        if ~isempty(jCheckSmooth)
            jCheckSmooth.setSelected(bst_get('GraphicsSmoothing') > 0);
        end
        if ~isempty(jCheckSystemCopy)
            jCheckSystemCopy.setSelected(bst_get('SystemCopy'));
        end
        switch bst_get('DisableOpenGL')
            case 0
                jRadioOpenHard.setSelected(1);
            case 1
                jRadioOpenNone.setSelected(1);
            case 2
                if strncmp(computer,'MAC',3)
                    jRadioOpenHard.setSelected(1);
                else
                    jRadioOpenSoft.setSelected(1);
                end
        end
        % Interface scaling
        switch (bst_get('InterfaceScaling'))
            case 100,       jSliderScaling.setValue(1);
            case 125,       jSliderScaling.setValue(2);
            case 150,       jSliderScaling.setValue(3);
            case {175,200}, jSliderScaling.setValue(4);
            case 250,       jSliderScaling.setValue(5);
            case 300,       jSliderScaling.setValue(6);
            case 400,       jSliderScaling.setValue(7);
        end    
        % Directory
        jTextTempDir.setText(bst_get('BrainstormTmpDir'));
        if ~isempty(jTextFtDir)
            jTextFtDir.setText(bst_get('FieldTripDir'));
        end
        if ~isempty(jTextSpmDir)
            jTextSpmDir.setText(bst_get('SpmDir'));
        end
        % MNE-Python config
        PythonConfig = bst_get('PythonConfig');
        jTextPythonExe.setText(PythonConfig.PythonExe);
        jTextPythonPath.setText(PythonConfig.PythonPath);
        jTextQtDir.setText(PythonConfig.QtDir);
        % Use signal processing toolbox
        isToolboxInstalled = (exist('fir2', 'file') > 0);
        jCheckUseSigProc.setEnabled(isToolboxInstalled);
        jCheckUseSigProc.setSelected(bst_get('UseSigProcToolbox'));
        processOptions = bst_get('ProcessOptions');
        jBlockSize.setText(num2str(processOptions.MaxBlockSize * 8 / 1024 / 1024));
    end


%% ===== SAVE OPTIONS =====
    function SaveOptions()
        bst_progress('start', 'Brainstorm preferences', 'Applying preferences...');
        % ===== GUI =====
        bst_set('ForceMatCompression', jCheckForceComp.isSelected());
        bst_set('AutoUpdates', jCheckUpdates.isSelected());
        bst_set('DisplayGFP',  jCheckGfp.isSelected());
        bst_set('IgnoreMemoryWarnings',  jCheckIgnoreMem.isSelected());
        if jCheckDownsample.isSelected()
            bst_set('DownsampleTimeSeries', 5);
        else
            bst_set('DownsampleTimeSeries', 0);
        end
        if ~isempty(jCheckSystemCopy)
            bst_set('SystemCopy', jCheckSystemCopy.isSelected());
        end
        if ~isempty(jCheckSmooth)
            % Update value
            isSmoothing = jCheckSmooth.isSelected();
            isChangedSmoothing = (bst_get('GraphicsSmoothing') ~= isSmoothing);
            bst_set('GraphicsSmoothing', isSmoothing);
            % Update open figures
            if isChangedSmoothing
                % Get all figures
                hFigAll = bst_figures('GetFiguresByType', {'DataTimeSeries', 'ResultsTimeSeries', '3DViz', 'Topography', 'MriViewer', 'Timefreq', 'Spectrum', 'Pac', 'Image'});
                % Set figurs properties
                if ~isempty(hFigAll)
                    if isSmoothing
                        set(hFigAll, 'GraphicsSmoothing', 'on');
                    else
                        set(hFigAll, 'GraphicsSmoothing', 'off');
                    end
                end
            end
        end
        
        % === OPENGL ===
        % Get selected status
        if jRadioOpenHard.isSelected()
            DisableOpenGL = 0;
        elseif jRadioOpenNone.isSelected()
            DisableOpenGL = 1;
        else
            DisableOpenGL = 2;
        end
        % Apply changes
        if (DisableOpenGL ~= bst_get('DisableOpenGL'))
            bst_set('DisableOpenGL', DisableOpenGL);
            StartOpenGL();
        end
        
        % ===== INTERFACE SCALING =====
        previousScaling = bst_get('InterfaceScaling');
        switch (jSliderScaling.getValue())
            case 1,  InterfaceScaling = 100;
            case 2,  InterfaceScaling = 125;
            case 3,  InterfaceScaling = 150;
            case 4,  InterfaceScaling = 200;
            case 5,  InterfaceScaling = 250;
            case 6,  InterfaceScaling = 300;
            case 7,  InterfaceScaling = 400;
        end
        bst_set('InterfaceScaling', InterfaceScaling);
        
        % ===== DATA IMPORT =====
        % Temporary directory
        oldTmpDir = bst_get('BrainstormTmpDir');
        newTmpDir = char(jTextTempDir.getText());
        if ~file_compare(oldTmpDir, newTmpDir)
            % Make sure it is different from and does not contain the database directory
            dbDir = bst_get('BrainstormDbDir');
            if file_compare(newTmpDir, dbDir)
                java_dialog('warning', 'Your temporary and database directories must be different.');
            elseif dir_contains(newTmpDir, dbDir)
                java_dialog('warning', 'Your temporary directory cannot contain your database directory.');
            else
                % If temp directory changed: create directory if it doesn't exist
                if file_exist(newTmpDir) || mkdir(newTmpDir)
                    bst_set('BrainstormTmpDir', newTmpDir);
                else
                    java_dialog('warning', 'Could not create temporary directory.');
                end
            end
        end
        % FieldTrip directory
        if ~isempty(jTextFtDir)
            oldFtDir = bst_get('FieldTripDir');
            newFtDir = char(jTextFtDir.getText());
            if ~file_compare(oldFtDir, newFtDir)
                % Folder doesn't exist
                if ~isempty(newFtDir) && ~file_exist(newFtDir)
                    java_dialog('warning', 'Selected FieldTrip folder doesn''t exist. Ignoring...');
                elseif ~isempty(newFtDir) && ~file_exist(bst_fullfile(newFtDir, 'ft_defaults.m'))
                    java_dialog('warning', 'Selected folder does not contain a valid FieldTrip install. Ignoring...');
                else
                    bst_set('FieldTripDir', newFtDir);
                end
            end
        end
        % SPM directory
        if ~isempty(jTextSpmDir)
            oldSpmDir = bst_get('SpmDir');
            newSpmDir = char(jTextSpmDir.getText());
            if ~file_compare(oldSpmDir, newSpmDir)
                % Folder doesn't exist
                if ~isempty(newSpmDir) && ~file_exist(newSpmDir)
                    java_dialog('warning', 'Selected SPM folder doesn''t exist. Ignoring...');
                elseif ~isempty(newSpmDir) && ~file_exist(bst_fullfile(newSpmDir, 'spm.m'))
                    java_dialog('warning', 'Selected folder does not contain a valid SPM install. Ignoring...');
                else
                    bst_set('SpmDir', newSpmDir);
                end
            end
        end
        
        % ===== MNE-PYTHON =====
        % Get saved configuration
        PythonConfig = bst_get('PythonConfig');
        % Get new configuration
        newPythonExe = char(jTextPythonExe.getText());
        newPythonPath = char(jTextPythonPath.getText());
        newQtDir = char(jTextQtDir.getText());
        % If something changed
        isPythonExeChanged = ~isequal(newPythonExe, PythonConfig.PythonExe);
        isPythonPathChanged = ~isequal(newPythonPath, PythonConfig.PythonPath);
        isQtDirChanged = ~isequal(newQtDir, PythonConfig.QtDir);
        if isPythonExeChanged || isPythonPathChanged || isQtDirChanged
            % If the path changed: remove the old path for system path
            if isPythonPathChanged
                if ~isempty(PythonConfig.PythonPath)
                    SystemPathRemove(PythonConfig.PythonPath);
                end
                if ~isempty(newPythonPath)
                    SystemPathAdd(newPythonPath);
                end
            end
            % Save new values in user preferences
            PythonConfig.PythonPath = newPythonPath;
            PythonConfig.PythonExe = newPythonExe;
            PythonConfig.QtDir = newQtDir;
            bst_set('PythonConfig', PythonConfig);
            % If the Qt dir changed: update environement variables
            if isQtDirChanged
                setenv('QT_PLUGIN_PATH', bst_fileparts(PythonConfig.QtDir));
                disp(['MNE> Setting environment variable: QT_PLUGIN_PATH=' bst_fileparts(PythonConfig.QtDir)]);
                setenv('QT_QPA_PLATFORM_PLUGIN_PATH', PythonConfig.QtDir);
                disp(['MNE> Setting environment variable: QT_QPA_PLATFORM_PLUGIN_PATH=' PythonConfig.QtDir]);
            end
            % If something changed: try to load python
            if isPythonExeChanged
                % Is python already loaded?
                [pyVer, pyExe, isLoaded] = pyversion();
                % Initialized MNE-Python if possible
                if ~isLoaded
                    bst_mne_init('Initialize', 1);
                else
                    bst_error('You must close and restart Matlab for this change to take effect.', 'Python exectutable', 0);
                end
            end
        end
        
        % ===== PROCESSING OPTIONS =====
        % Use signal processing toolbox
        bst_set('UseSigProcToolbox', jCheckUseSigProc.isSelected());
        % Memory block size (Valid values: between 1MB and 1TB)
        blockSize = str2num(jBlockSize.getText());
        if ~isempty(blockSize) && blockSize >= 1 && blockSize <= 1e6
            processOptions = bst_get('ProcessOptions');
            processOptions.MaxBlockSize = blockSize * 1024 * 1024 / 8; % Mb to bytes
            bst_set('ProcessOptions', processOptions);
        end
        bst_progress('stop');
        
        % If the scaling was changed: Restart brainstorm
        if (previousScaling ~= InterfaceScaling)
            brainstorm stop;
            brainstorm;
        end
    end


%% ===== SAVE OPTIONS =====
    function ButtonSave_Callback(varargin)
        % Save options
        SaveOptions()
        % Hide panel
        gui_hide(panelName);
    end

%% ===== CANCEL BUTTON =====
    function ButtonCancel_Callback(varargin)
        % Hide panel
        gui_hide(panelName);
    end


%% ===== TEMP DIRECTORY SELECTION =====
    % Callback for '...' button
    function TempDirectory_Callback(varargin)
        % Get the initial path
        initDir = bst_get('BrainstormTmpDir', 1);
        % Open 'Select directory' dialog
        tempDir = uigetdir(initDir, 'Select temporary directory.');
        % If no directory was selected : return without doing anything
        if (isempty(tempDir) || (tempDir(1) == 0))
            return
        end
        % Else : update control text
        jTextTempDir.setText(tempDir);
        % Focus main brainstorm figure
        jBstFrame = bst_get('BstFrame');
        jBstFrame.setVisible(1);
    end


%% ===== FIELDTRIP DIRECTORY SELECTION =====
    % Callback for '...' button
    function FtDirectory_Callback(varargin)
        % Get the initial path
        initDir = bst_get('FieldTripDir', 1);
        % Open 'Select directory' dialog
        ftDir = uigetdir(initDir, 'Select FieldTrip directory.');
        % If no directory was selected : return without doing anything
        if (isempty(ftDir) || (ftDir(1) == 0) || (~isempty(initDir) && file_compare(initDir, ftDir)))
            return;
        % Directory is not avalid FieldTrip folder
        elseif ~file_exist(bst_fullfile(ftDir, 'ft_defaults.m'))
            java_dialog('warning', 'Selected folder does not contain a valid FieldTrip install.');
            return;
        end
        % Else : update control text
        jTextFtDir.setText(ftDir);
        % Focus main brainstorm figure
        jBstFrame = bst_get('BstFrame');
        jBstFrame.setVisible(1);
        % Remove all the previous FieldTrip folders from the path
        if ~isempty(initDir) && isdir(initDir)
            warning('off', 'MATLAB:rmpath:DirNotFound');
            allFtPath = genpath(initDir);
            rmpath(allFtPath);
            warning('on', 'MATLAB:rmpath:DirNotFound');
        end
    end

%% ===== SPM DIRECTORY SELECTION =====
    % Callback for '...' button
    function SpmDirectory_Callback(varargin)
        % Get the initial path
        initDir = bst_get('SpmDir', 1);
        % Open 'Select directory' dialog
        spmDir = uigetdir(initDir, 'Select SPM directory.');
        % If no directory was selected : return without doing anything
        if (isempty(spmDir) || (spmDir(1) == 0) || (~isempty(initDir) && file_compare(initDir, spmDir)))
            return;
        % Directory is not avalid SPM folder
        elseif ~file_exist(bst_fullfile(spmDir, 'spm.m'))
            java_dialog('warning', 'Selected folder does not contain a valid SPM install.');
            return;
        end
        % Else : update control text
        jTextSpmDir.setText(spmDir);
        % Focus main brainstorm figure
        jBstFrame = bst_get('BstFrame');
        jBstFrame.setVisible(1);
        % Remove all the previous SPM folders from the path
        if ~isempty(initDir) && isdir(initDir)
            warning('off', 'MATLAB:rmpath:DirNotFound');
            allSpmPath = genpath(initDir);
            rmpath(allSpmPath);
            warning('on', 'MATLAB:rmpath:DirNotFound');
        end
    end


%% ===== PYTHON EXECUTABLE =====
    % Callback for '...' button
    function PythonExe_Callback(varargin)
        % Get the initial path
        PythonConfig = bst_get('PythonConfig', 1);
        initExe = PythonConfig.PythonExe;
        % Ask for python path
        exePath = java_getfile( 'open', ...
            'Select Python executable', ...  % Window title
            bst_fileparts(initExe), 'single', 'files', ...     % Default directory, Selection mode
            {{'*'}, 'Python executable (version 3.5 or higher)', 'Python'}, 'Python');
        if isempty(exePath) || isequal(initExe, exePath)
            return;
        end
        % Else : update control text
        jTextPythonExe.setText(exePath);
        % Get additional folders to add to path
        [PythonPath, QtDir] = bst_mne_init('GetPythonPath', exePath);
        if ~isempty(PythonPath)
            jTextPythonPath.setText(PythonPath);
        end
        if ~isempty(QtDir)
            jTextQtDir.setText(QtDir);
        end
        % Focus main brainstorm figure
        jBstFrame = bst_get('BstFrame');
        jBstFrame.setVisible(1);
    end


%% ===== QT DIRECTORY SELECTION =====
    % Callback for '...' button
    function QtDirectory_Callback(varargin)
        % Get the initial path
        PythonConfig = bst_get('PythonConfig', 1);
        initDir = PythonConfig.QtDir;
        % Open 'Select directory' dialog
        qtDir = uigetdir(initDir, 'Select Qt plugin directory.');
        % If no directory was selected : return without doing anything
        if (isempty(qtDir) || (qtDir(1) == 0) || (~isempty(initDir) && file_compare(initDir, qtDir)))
            return;
        % Directory is not avalid Qt folder (test on windows only)
        elseif ispc && ~file_exist(bst_fullfile(qtDir, 'qwindows.dll'))
            java_dialog('warning', 'Selected folder does not contain a valid Qt plugin install (qwindows.dll missing).');
            return;
        end
        % Else : update control text
        jTextQtDir.setText(qtDir);
        % Focus main brainstorm figure
        jBstFrame = bst_get('BstFrame');
        jBstFrame.setVisible(1);
    end

%% ===== ADD PYTHON PATH =====
    % Callback for '+' button
    function AddPath_Callback(varargin)
        % Get the initial path
        PythonConfig = bst_get('PythonConfig', 1);
        if ~isempty(PythonConfig.PythonPath)
            initPath = str_split(PythonConfig.PythonPath);
            initDir = initPath{1};
        else
            initPath = {};
            initDir = [];
        end
        % Open 'Select directory' dialog
        addDir = uigetdir(initDir, 'Add folder to system path');
        % If no directory was selected : return without doing anything
        if (isempty(addDir) || (addDir(1) == 0) || ismember(addDir, initPath))
            return;
        end
        % New python path
        if ~isempty(PythonConfig.PythonPath)
            newPath = [PythonConfig.PythonPath ';' addDir];
        else
            newPath = addDir;
        end
        % Else : update control text
        jTextPythonPath.setText(newPath);
        % Focus main brainstorm figure
        jBstFrame = bst_get('BstFrame');
        jBstFrame.setVisible(1);
    end
end


%% ===== START OPENGL =====
function [isOpenGL, DisableOpenGL] = StartOpenGL()
    global GlobalOpenGLStatus;
    % Get configuration 
    DisableOpenGL = bst_get('DisableOpenGL');
    isOpenGL = 1;
    isUnixWarning = 0;
    
    % ===== MATLAB < 2014b =====
    if (bst_get('MatlabVersion') < 804)
        % Define OpenGL options
        switch DisableOpenGL
            case 0
                if strncmp(computer,'MAC',3)
                    OpenGLMode = 'autoselect';
                elseif isunix && ~isempty(GlobalOpenGLStatus)
                    OpenGLMode = 'autoselect';
                    disp('BST> Warning: You have to restart Matlab to switch between software and hardware OpenGL.');
                else
                    OpenGLMode = 'hardware';
                end
                FigureRenderer = 'opengl';
            case 1
                OpenGLMode = 'neverselect';
                FigureRenderer = 'zbuffer';
            case 2
                if strncmp(computer,'MAC',3)
                    OpenGLMode = 'autoselect';
                elseif isunix && ~isempty(GlobalOpenGLStatus)
                    OpenGLMode = 'autoselect';
                    disp('BST> Warning: You have to restart Matlab to switch between software and hardware OpenGL.');
                else
                    OpenGLMode = 'software';
                end
                FigureRenderer = 'opengl';
        end
        % Configure OpenGL
        try
            opengl(OpenGLMode);
        catch
            isOpenGL = 0;
        end
        % Check that OpenGL is running
        s = opengl('data');
        if isempty(s) || isempty(s.Version)
            isOpenGL = 0;
        end
        % Figure types for which the OpenGL renderer is used
        figTypes = {'3DViz', 'Topography', 'MriViewer', 'Timefreq', 'Pac', 'Image'};
        
    % ===== MATLAB >= 2014b =====
    else
        % Start OpenGL
        s = opengl('data');
        if isempty(s) || isempty(s.Version)
            isOpenGL = 0;
        end
        % Linux: Cannot change the OpenGL mode at runtime
        if isunix
            if ~isOpenGL
                DisableOpenGL = 1;
            % If the requested configuration is not the current OpenGL status: Error
            elseif (DisableOpenGL == 0) && (s.Software == 1) 
                isUnixWarning = 1;
                DisableOpenGL = 2;
                bst_set('DisableOpenGL', DisableOpenGL);
            elseif (DisableOpenGL == 2) && (s.Software == 0)
                isUnixWarning = 1;
                DisableOpenGL = 0;
                bst_set('DisableOpenGL', DisableOpenGL);
            end
        % MacOSX: No software OpenGL
        elseif strncmp(computer,'MAC',3)
            % Nothing to do
        % Windows: Try to change the current status hardware/software
        else
            try
                if (DisableOpenGL == 0)
                    opengl('hardware');
                elseif (DisableOpenGL == 2)
                    opengl('software');
                end
                s = opengl('data');
            catch
                isOpenGL = 0;
            end
        end
        % Configure OpenGL
        switch DisableOpenGL
            case 0,  FigureRenderer = 'opengl';
            case 1,  FigureRenderer = 'painters';
            case 2,  FigureRenderer = 'opengl';
        end
        % Figure types for which the OpenGL renderer is used
        figTypes = {'DataTimeSeries', 'ResultsTimeSeries', 'Spectrum', '3DViz', 'Topography', 'MriViewer', 'Timefreq', 'Pac', 'Image'};
    end
    
    % Add comment if not running Brainstorm
    if isappdata(0, 'BrainstormRunning')
        fprintf(1, 'BST> OpenGL status: ');
    end
    % If OpenGL is running: save status
    if isOpenGL
        GlobalOpenGLStatus = DisableOpenGL;
        if (DisableOpenGL == 1)
            disp('disabled');
        elseif s.Software
            disp('software');
        else
            disp('hardware');
        end
    else
        GlobalOpenGLStatus = -1;
        FigureRenderer = 'painters';
        disp('failed');
    end
        
    % Display warning
    if isUnixWarning
        disp('BST> Warning: Switching between hardware and software at runtime is not possible on Linux systems.');
        disp('BST> To force Matlab to use the software OpenGL: matlab -softwareopengl');
        disp('BST> To force Matlab to use the hardware OpenGL: matlab -nosoftwareopengl');
    end
    
    % ===== UPDATE FIGURES =====
    % Get all figures
    hFigAll = bst_figures('GetFiguresByType', figTypes);
    % Set figures renderers
    if ~isempty(hFigAll)
        bst_progress('start', 'OpenGL configuration', 'Updating figures...');
        set(hFigAll, 'Renderer', FigureRenderer);
        drawnow;
        bst_progress('stop');
    end
end


%% ===== BUTTON: RESET =====
function ButtonReset_Callback(varargin)
    % Ask user confirmation
    isConfirm = java_dialog('confirm', ...
        ['You are about to reinitialize your Brainstorm installation, this will:' 10 10 ...
         ' - Detach all the protocols from the database (without deleting any file)' 10 ...
         ' - Reset all the Brainstorm and processes preferences' 10 ...
         ' - Restart Brainstorm as if it was the first time on this computer' 10 10 ...
         'Reset Brainstorm now?' 10 10], ...
        'Reset Brainstorm');
    if ~isConfirm
        return;
    end
    % Close panel
    gui_hide('Preferences');
    % Reset and restart brainstorm
    brainstorm stop;
    brainstorm reset;
    brainstorm;
end


%% ===== SYSTEM PATH: REMOVE DIR =====
% USAGE:         panel_options('SystemPathRemove', rmPath)          % Update system path
%         PATH = panel_options('SystemPathRemove', rmPath, PATH)    % Update user defined path (do not change system path)
function PATH = SystemPathRemove(rmPath, PATH)
    % Parse inputs
    if (nargin < 2)
        PATH = getenv('PATH');
        isSystemPath = 1;
    else
        isSystemPath = 0;
    end
    % Get system path
    PATH = getenv('PATH');
    PATH_split = str_split(PATH, ';');
    % Find elements to remove
    rm_split = str_split(rmPath, ';');
    iRm = find(ismember(PATH_split, rm_split));
    if isempty(iRm)
        return;
    end
    % Display removed path
    for i = 1:length(iRm)
        disp(['BST> Removed from system path:  ' PATH_split{iRm(i)}]);
    end
    % Remove elements from path string
    PATH_split(iRm) = [];
    PATH = '';
    for i = 1:length(PATH_split)
        if (i == 1)
            PATH = PATH_split{i};
        else
            PATH = [PATH, ';', PATH_split{i}];
        end
    end
    % Update system path
    if isSystemPath
        setenv('PATH', PATH);
    end
end


%% ===== SYSTEM PATH: ADD DIR =====
% USAGE:         panel_options('SystemPathAdd', rmPath)          % Update system path
%         PATH = panel_options('SystemPathAdd', rmPath, PATH)    % Update user defined path (do not change system path)
function PATH = SystemPathAdd(addPath, PATH)
    % Parse inputs
    if (nargin < 2)
        PATH = getenv('PATH');
        isSystemPath = 1;
    else
        isSystemPath = 0;
    end
    % Get system path
    PATH_split = str_split(PATH, ';');
    % Check which folders are not yet in the system path
    add_split = str_split(addPath, ';');
    for iPath = 1:length(add_split)
        if isdir(add_split{iPath}) && ~ismember(add_split{iPath}, PATH_split)
            PATH = [PATH ';' add_split{iPath}];
            disp(['BST> Added to system path: ' add_split{iPath}]);
        end
    end
    % Update system path
    if isSystemPath
        setenv('PATH', PATH);
    end
end


