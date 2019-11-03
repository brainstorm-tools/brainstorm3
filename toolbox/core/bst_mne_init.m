function varargout = bst_mne_init(varargin)
% BST_MNE_INIT: Check the MNE-Python installation.
%
% USAGE:                   isOk = bst_mne_init('Initialize', isInteractive)
%           [PythonPath, QtDir] = bst_mne_init('GetPythonPath', PythonExe)
% 
% Reference documentation: 
% https://neuroimage.usc.edu/brainstorm/MnePython

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
% Authors: Francois Tadel, 2019

eval(macro_method);
end


%% ===== INITIALIZE =====
% USAGE:  isOk = bst_mne_init('Initialize', isInteractive)
function isOk = Initialize(isInteractive)
    % Default behavior
    if (nargin < 1) || isempty(isInteractive)
        isInteractive = 0;
    end
    % Brainstorm must be running
    if ~brainstorm('status')
        error('Brainstorm must be started before executing this function.');
    end

    % ===== ACCESS PYTHON EXE =====
    % Get user preferences
    PythonConfig = bst_get('PythonConfig');
    % Check the Python installation
    [pyVer, PythonExe, isLoaded] = pyversion();
    % If the wrong version of Python is running
    if ~isempty(PythonExe) && ~isempty(PythonConfig.PythonExe) && ~file_compare(PythonExe, PythonConfig.PythonExe)
        % If Python is already loaded: Matlab must be restarted first
        if isLoaded
            error('Python is already loaded. You must Restart Matlab before running the Python initialization again.');
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
                [pyVer, PythonExe, isLoaded] = pyversion(PythonConfig.PythonExe);
            catch
                disp(['MNE> Error: Invalid Python executable: ' PythonConfig.PythonExe]);
            end
            if isempty(pyVer)
                PythonConfig.PythonExe = [];
            end
        end
        % If Python is still not running
        if isempty(pyVer)
            % If no interactivity
            if ~isInteractive
                disp('MNE> Error: Python is not set up.');
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
                    'Before using MNE-Python functions in Brainstorm, you need to install ' 10 ...
                    'a Python environment on your computer. For installation instrations:' 10 ...
                    'https://neuroimage.usc.edu/brainstorm/MnePython'], 'Python installation');
                % Open web browser with tutorial
                web('https://neuroimage.usc.edu/brainstorm/MnePython', '-browser');
                return;
            end
            % Set Python exe in Matlab
            [pyVer, PythonExe, isLoaded] = pyversion(PythonExe);
            % Save user preferences
            PythonConfig.PythonExe = PythonExe;
            bst_set('PythonConfig', PythonConfig);
        end
    end
    disp(['MNE> Python executable: ' PythonExe]);
    % Check Python version
    if isempty(pyVer)
        disp('MNE> Could not load Python in Matlab.');
        return;
    elseif (str2num(pyVer) < 3.5)
        disp(['MNE> Minimum version of Python required by MNE: 3.5' 10 ...
              'MNE> Version of Python currently selected: ' str2num(pyVer)]);
    end

    % ===== CONFIGURE PATH =====
    % Add additional python paths to system path
    if ~isempty(PythonConfig.PythonPath)
        panel_options('SystemPathAdd', PythonConfig.PythonPath);
    end
    % Set QT plugin environment variable
    if ~isempty(PythonConfig.QtDir)
        setenv('QT_PLUGIN_PATH', bst_fileparts(PythonConfig.QtDir));
        disp(['MNE> Setting environment variable: QT_PLUGIN_PATH=' bst_fileparts(PythonConfig.QtDir)]);
        setenv('QT_QPA_PLATFORM_PLUGIN_PATH', PythonConfig.QtDir);
        disp(['MNE> Setting environment variable: QT_QPA_PLATFORM_PLUGIN_PATH=' PythonConfig.QtDir]);
    end        

    % Set locale
    py.locale.setlocale(py.locale.LC_ALL, 'en_US');
    
    isOk = 1;
end


%% ===== GET PYTHON PATH =====
% USAGE:  [PythonPath, QtDir] = bst_mne_init('GetPythonPath', PythonExe)
function [PythonPath, QtDir] = GetPythonPath(PythonExe)
    % Initial list of extra paths
    PythonPath = '';
    QtDir = '';
    % On Windows, if this is a CONDA environment: we must add some extra paths
    if ispc && ~isempty(strfind(lower(PythonExe), 'anaconda')) && ~isempty(strfind(lower(PythonExe), 'envs'))
        % Guess Anaconda folder architecture
        CondaEnvPath = bst_fileparts(PythonExe);
        CondaDir = bst_fileparts(bst_fileparts(CondaEnvPath));
        % Possibly interesting subfolders
        PythonPath = CondaEnvPath;
        tryPath = {...
            bst_fullfile(CondaEnvPath, 'mingw-w64', 'bin'), ...
            bst_fullfile(CondaEnvPath, 'Library', 'usr', 'bin'), ...
            bst_fullfile(CondaEnvPath, 'Library', 'bin'), ...
            bst_fullfile(CondaEnvPath, 'Library', 'bin'), ...
            bst_fullfile(CondaEnvPath, 'Library', 'Scripts'), ...
            bst_fullfile(CondaEnvPath, 'bin'), ...
            bst_fullfile(CondaDir, 'condabin')};
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


