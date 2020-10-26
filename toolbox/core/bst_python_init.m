function varargout = bst_python_init(varargin)
% BST_PYTHON_INIT: Prepare the access to a Python environment from Brainstorm.
%
% USAGE:      [isOk, errorMsg, pyVer] = bst_python_init('Initialize', isInteractive)  % Initialize the Python environment in Matlab
%                 [PythonPath, QtDir] = bst_python_init('GetPythonPath', PythonExe)   % Get Python paths
% 
% Reference documentation: 
% https://neuroimage.usc.edu/brainstorm/MnePython

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
% Authors: Francois Tadel, 2019-2020

eval(macro_method);
end


%% ===== INITIALIZE =====
% USAGE:  [isOk, errorMsg, pyVer] = bst_python_init('Initialize', isInteractive)
function [isOk, errorMsg, pyVer] = Initialize(isInteractive)
    isOk = 0;
    errorMsg = [];
    pyVer = [];
    % Default behavior
    if (nargin < 1) || isempty(isInteractive)
        isInteractive = 0;
    end
    % Brainstorm must be running
    if ~brainstorm('status')
        errorMsg = 'Brainstorm must be started before executing this function.';
        return;
    end

    % ===== ACCESS PYTHON EXE =====
    % Get user preferences
    PythonConfig = bst_get('PythonConfig');
    % Check the Python installation
    [pyVer, PythonExe, isLoaded] = bst_python_ver();
    % If the wrong version of Python is running
    if ~isempty(PythonExe) && ~isempty(PythonConfig.PythonExe) && ~strcmpi(PythonExe, PythonConfig.PythonExe)
        % If Python is already loaded: Matlab must be restarted first
        if isLoaded
            errorMsg = 'Python is already loaded. You must Restart Matlab before running the Python initialization again.';
            return;
        else
            pyVer = [];
            PythonExe = [];
        end
    end
    % If Python is not set up
    if isempty(pyVer)
        % If Python path was already set in the user preferences: try to use it
        if ~isempty(PythonConfig.PythonExe)
            try
                [pyVer, PythonExe, isLoaded] = bst_python_ver(PythonConfig.PythonExe);
            catch
                errorMsg = ['BST> Error: Invalid Python executable: ' PythonConfig.PythonExe];
                return;
            end
            if isempty(pyVer)
                PythonConfig.PythonExe = [];
            end
        else
            % Try to find Python at typical installation locations
            if ispc
                userDir = bst_get('UserDir');
                % Typical Anaconda path on Windows
                anacondaFolders = GetFoldersFromPrefix(userDir, 'anaconda');
                [pyVer, PythonExe, isLoaded] = TryPythonFolders(anacondaFolders, 'python.exe');
                if isempty(pyVer)
                    % Typical Python path on Windows
                    appdataPythonPath = bst_fullfile(userDir, 'AppData', 'Local', 'Programs', 'Python');
                    appdataFolders = GetFoldersFromPrefix(appdataPythonPath, 'python');
                    [pyVer, PythonExe, isLoaded] = TryPythonFolders(appdataFolders, 'python.exe');
                end
                if ~isempty(pyVer)
                    % Extract System PATH
                    [PythonPath, QtDir] = GetPythonPath(PythonExe);
                    % Save user preferences
                    PythonConfig.PythonExe = PythonExe;
                    PythonConfig.PythonPath = PythonPath;
                    PythonConfig.QtDir = QtDir;
                    bst_set('PythonConfig', PythonConfig);
                end
            %TODO: Try Mac/Linux default paths
            end
        end
        % If Python is still not running
        if isempty(pyVer)
            % If no interactivity
            if ~isInteractive
                errorMsg = 'BST> Error: Python is not set up.';
                return;
            end
            % Ask for Python installation
            isInstalled = java_dialog('confirm', ...
                ['Matlab could not detect your Python installation.' 10 10 ...
                 'Is Python installed on your computer?'], 'Python installation');
            if isInstalled
                % Ask for python path
                PythonExe = java_getfile( 'open', ...
                    'Select Python executable', ...  % Window title
                    '', 'single', 'files', ...     % Default directory, Selection mode
                    {{'*'}, 'Python executable (version 3.5 or higher)', 'Python'}, 'Python');
                if isempty(PythonExe)
                    return;
                end
            else
                % Display error message with installation instructions
                java_dialog('error', [...
                    'Before using Python functions in Brainstorm, you need to install ' 10 ...
                    'a Python environment on your computer. For installation instructions:' 10 ...
                    'https://neuroimage.usc.edu/brainstorm/MnePython'], 'Python installation');
                % Open web browser with tutorial
                web('https://neuroimage.usc.edu/brainstorm/MnePython', '-browser');
                return;
            end
            % Set Python exe in Matlab
            [pyVer, PythonExe, isLoaded] = bst_python_ver(PythonExe);
            % Save user preferences
            PythonConfig.PythonExe = PythonExe;
            bst_set('PythonConfig', PythonConfig);
        end
    end
    disp(['BST> Python ' pyVer ' executable: ' PythonExe]);


    % ===== CONFIGURE PATH =====
    % Add additional python paths to system path
    if ~isempty(PythonConfig.PythonPath)
        panel_options('SystemPathAdd', PythonConfig.PythonPath);
    end
    % Set QT plugin environment variable
    if ~isempty(PythonConfig.QtDir)
        setenv('QT_PLUGIN_PATH', bst_fileparts(PythonConfig.QtDir));
        disp(['BST> Setting environment variable: QT_PLUGIN_PATH=' bst_fileparts(PythonConfig.QtDir)]);
        setenv('QT_QPA_PLATFORM_PLUGIN_PATH', PythonConfig.QtDir);
        disp(['BST> Setting environment variable: QT_QPA_PLATFORM_PLUGIN_PATH=' PythonConfig.QtDir]);
    end        

    % Set locale
    py.locale.setlocale(py.locale.LC_ALL, 'en_US');
    
    isOk = 1;
end


%% ===== GET PYTHON PATH =====
% USAGE:  [PythonPath, QtDir] = bst_python_init('GetPythonPath', PythonExe)
function [PythonPath, QtDir] = GetPythonPath(PythonExe)
    % Initial list of extra paths
    PythonPath = '';
    QtDir = '';
    % On Windows, if this is a CONDA environment: we must add some extra paths
    if ispc && ~isempty(strfind(lower(PythonExe), 'anaconda'))
        % Guess Anaconda folder architecture
        CondaEnvPath = bst_fileparts(PythonExe);
        if ~isempty(strfind(lower(PythonExe), 'envs'))
            CondaDir = bst_fileparts(bst_fileparts(CondaEnvPath));
        else
            CondaDir = CondaEnvPath;
        end
        % Possibly interesting subfolders
        PythonPath = CondaEnvPath;
        tryPath = {...
            bst_fullfile(CondaEnvPath, 'mingw-w64', 'bin'), ...
            bst_fullfile(CondaEnvPath, 'Library', 'mingw-w64', 'bin'), ...
            bst_fullfile(CondaEnvPath, 'Library', 'usr', 'bin'), ...
            bst_fullfile(CondaEnvPath, 'Library', 'bin'), ...
            bst_fullfile(CondaEnvPath, 'Library', 'Scripts'), ...
            bst_fullfile(CondaEnvPath, 'bin'), ...
            bst_fullfile(CondaDir, 'condabin'), ...
            bst_fullfile(CondaDir, 'Scripts')};
        % Add all the folders only if they exist
        for i = 1:length(tryPath)
            if isdir(tryPath{i})
                PythonPath = [PythonPath, ';', tryPath{i}];
            end
        end
        % Qt platform plugin
        QtDir = bst_fullfile(CondaEnvPath, 'Library', 'plugins', 'platforms');
        if ~isdir(QtDir)
            QtDir = [];
        end
    end
end

% Extracts folders starting with 'folderPrefix' inside 'parentPath'
% Example: GetFoldersFromPrefix(bst_get('UserDir'), 'anaconda')
%   -> Returns {'Anaconda3'} if 'C:\Users\martin\Anaconda3' exists
function folders = GetFoldersFromPrefix(parentPath, folderPrefix)
    nChars = length(folderPrefix);
    files = dir(parentPath);
    folders = {};
    for iFile = 1:length(files)
        if files(iFile).isdir && strncmpi(files(iFile).name, folderPrefix, nChars)
            folders{end + 1} = bst_fullfile(parentPath, files(iFile).name);
        end
    end
end

% Tries possible Python folders until it finds a python executable
function [pyVer, PythonExe, isLoaded] = TryPythonFolders(pythonFolders, pythonExe)
    pyVer = [];
    PythonExe = [];
    isLoaded = 0;
    for iFolder = 1:length(pythonFolders)
        pythonPath = bst_fullfile(pythonFolders{iFolder}, pythonExe);
        if exist(pythonPath, 'file') == 2
            try
                [pyVer, PythonExe, isLoaded] = bst_python_ver(pythonPath);
            catch
            end
            % Stop if it worked
            if ~isempty(pyVer)
                return;
            end
        end
    end
end

% Lists all DLLs loaded in the Python environment (for debugging)
function loadedDlls = GetLoadedDlls(verbose)
    if nargin < 1 || isempty(verbose)
        verbose = 1;
    end

    curProcess = py.psutil.Process(py.os.getpid());
    dlls = curProcess.memory_maps();
    nDlls = length(dlls);
    loadedDlls = cell(1, nDlls);
    for iDll = 1:nDlls
        dll = dlls(iDll);
        loadedDlls{iDll} = char(dll{1}.path);
        if verbose
            disp(loadedDlls{iDll});
        end
    end
end

