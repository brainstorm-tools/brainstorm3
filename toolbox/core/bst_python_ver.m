function [pyVer, PythonExe, isLoaded] = bst_python_ver(PythonExe)
% BST_PYTHON_VER: Get/set the Python executable
%
% USAGE: [pyVer, PythonExe, isLoaded] = bst_python_ver()              % Get Python executable
%        [pyVer, PythonExe, isLoaded] = bst_python_ver(PythonExe)     % Set Python executable

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
% Authors: Francois Tadel, 2020

if (nargin < 1) || isempty(PythonExe)
    PythonExe = [];
end

% PYENV: Matlab >= 2019b
if exist('pyenv', 'builtin')
    if isempty(PythonExe)
        pyEnv = pyenv();
    else
        pyEnv = pyenv('Version', PythonExe);
    end
    pyVer = char(pyEnv.Version);
    PythonExe = char(pyEnv.Executable);
    isLoaded = strcmpi(pyEnv.Status, 'Loaded');
    
% PYVERSION: Matlab >= R2014b
elseif exist('pyversion', 'builtin')
    if isempty(PythonExe)
        [pyVer, PythonExe, isLoaded] = pyversion();
    else
        [pyVer, PythonExe, isLoaded] = pyversion(PythonExe);
    end
    
% Older versions of Matlab
else
    pyVer = [];
    PythonExe = [];
    isLoaded = 0;
end

