function varargout = bst_python_init(varargin)
% BST_PYTHON_INIT: Prepare the access to a Python environment from Brainstorm.
%
% USAGE:  [isOk, errorMsg, pyVer] = bst_python_init('Initialize', isInteractive)  % Initialize the Python environment in Matlab
% 
% Reference documentation: 
% https://neuroimage.usc.edu/brainstorm/MnePython

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
    PythonExeBst = bst_get('PythonExe');
    % Check the Python installation
    [pyVer, PythonExeMatlab, isLoaded] = bst_python_ver();
    % If Python not set up: Error
    if isempty(PythonExeMatlab) && isempty(PythonExeBst)
        errorMsg = 'Python is not configured: Define the python executable from the Brainstorm preferences or with the pyenv/pyversion functions.';
        return;
    % If the wrong version of Python is running in Brainstorm
    elseif ~isempty(PythonExeMatlab) && ~isempty(PythonExeBst) && ~strcmpi(PythonExeBst, PythonExeMatlab)
        % If Python is already loaded: Matlab must be restarted first
        if isLoaded
            errorMsg = 'You must restart Matlab before changing the Python version.';
            return;
        else
            pyVer = [];
            PythonExeMatlab = '';
        end
    end
    % If Python is not set up
    if isempty(pyVer)
        % If Python path was already set in the user preferences: try to use it
        if ~isempty(PythonExeBst)
            try
                [pyVer, PythonExeMatlab, isLoaded] = bst_python_ver(PythonExeBst);
            catch
                errorMsg = ['Invalid Python executable: ' PythonExeBst];
                return;
            end
            if isempty(pyVer)
                PythonExeBst = '';
            end
        end
        % If Python is still not running
        if isempty(pyVer)
            % If no interactivity
            if ~isInteractive
                errorMsg = 'Python is not set up.';
                return;
            end
            % Ask for Python installation
            isInstalled = java_dialog('confirm', ...
                ['Matlab could not detect your Python installation.' 10 10 ...
                 'Is Python installed on your computer?'], 'Python installation');
            if isInstalled
                % Ask for python path
                PythonExeBst = java_getfile( 'open', ...
                    'Select Python executable', ...  % Window title
                    '', 'single', 'files', ...     % Default directory, Selection mode
                    {{'*'}, 'Python executable (version 3.6 or higher)', 'Python'}, 'Python');
                if isempty(PythonExeBst)
                    errorMsg = 'Aborted by user.';
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
                errorMsg = 'Python is not set up.';
                return;
            end
            % Set Python exe in Matlab
            try
                [pyVer, PythonExeMatlab, isLoaded] = bst_python_ver(PythonExeBst);
                if isempty(PythonExeMatlab)
                    errorMsg = 'BST> Could not configure Python, Matlab is maybe too old.';
                    return;
                end
            catch
                errorMsg = ['BST> Error: Invalid Python executable: ' PythonExeBst];
                return;
            end
            % Save user preferences
            bst_set('PythonExe', PythonExeBst);
        end
    end
    disp(['BST> Python ' pyVer ' executable: ' PythonExeMatlab]);
    % Set locale (use eval to avoid the parser to load the python environment)
    eval('py.locale.setlocale(py.locale.LC_ALL, ''en_US.UTF-8'');');
    % Return success
    isOk = 1;
end


% %% ===== GET PYTHON PATH =====
% % USAGE:  [PythonPath, QtDir] = bst_python_init('GetAnacondaPath', PythonExe)
% function [PythonPath, QtDir] = GetAnacondaPath(PythonExe)
%     % Initial list of extra paths
%     PythonPath = '';
%     QtDir = '';
%     % On Windows, if this is a CONDA environment: we must add some extra paths
%     if ispc && ~isempty(strfind(lower(PythonExe), 'anaconda'))
%         % Guess Anaconda folder architecture
%         CondaEnvPath = bst_fileparts(PythonExe);
%         if ~isempty(strfind(lower(PythonExe), 'envs'))
%             CondaDir = bst_fileparts(bst_fileparts(CondaEnvPath));
%         else
%             CondaDir = CondaEnvPath;
%         end
%         % Possibly interesting subfolders
%         PythonPath = CondaEnvPath;
%         tryPath = {...
%             bst_fullfile(CondaEnvPath), ...
%             bst_fullfile(CondaEnvPath, 'mingw-w64', 'bin'), ...
%             bst_fullfile(CondaEnvPath, 'Library', 'mingw-w64', 'bin'), ...
%             bst_fullfile(CondaEnvPath, 'Library', 'usr', 'bin'), ...
%             bst_fullfile(CondaEnvPath, 'Library', 'bin'), ...
%             bst_fullfile(CondaEnvPath, 'Library', 'Scripts'), ...
%             bst_fullfile(CondaEnvPath, 'bin'), ...
%             bst_fullfile(CondaEnvPath, 'Scripts'), ...
%             bst_fullfile(CondaDir, 'condabin'), ...
%             bst_fullfile(CondaDir, 'Scripts')};
%         % Add all the folders only if they exist
%         for i = 1:length(tryPath)
%             if isdir(tryPath{i})
%                 PythonPath = [PythonPath, ';', tryPath{i}];
%             end
%         end
%         % Qt platform plugin
%         QtDir = bst_fullfile(CondaEnvPath, 'Library', 'plugins', 'platforms');
%         if ~isdir(QtDir)
%             QtDir = [];
%         end
%     end
% end

% % Lists all DLLs loaded in the Python environment (for debugging)
% function loadedDlls = GetLoadedDlls(verbose)
%     if nargin < 1 || isempty(verbose)
%         verbose = 1;
%     end
%     curProcess = py.psutil.Process(py.os.getpid());
%     dlls = curProcess.memory_maps();
%     nDlls = length(dlls);
%     loadedDlls = cell(1, nDlls);
%     for iDll = 1:nDlls
%         dll = dlls(iDll);
%         loadedDlls{iDll} = char(dll{1}.path);
%         if verbose
%             disp(loadedDlls{iDll});
%         end
%     end
% end

