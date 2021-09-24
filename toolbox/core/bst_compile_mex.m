function isOk = bst_compile_mex(fcn_name, isInteractive)
% BST_COMPILE_MEX: Compiles a MEX-file before using it.

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
% Authors: Francois Tadel, 2011-2013

% Parse inputs
if (nargin < 2) || isempty(isInteractive)
    isInteractive = 1;
end
% Get system directories
BrainstormHomeDir = bst_get('BrainstormHomeDir');
userMexDir        = bst_get('UserMexDir');
% Remember current directory
previousDir = pwd;
isOk = 0;

% Got to mex file directory
cFile   = bst_fullfile(BrainstormHomeDir, [fcn_name '.c']);
mexFile = bst_fullfile(BrainstormHomeDir, [fcn_name '.' mexext]);
mexFileUser = bst_fullfile(userMexDir, [strrep(fcn_name, fileparts(fcn_name), ''), '.' mexext]);
[mexPath, mexName] = fileparts(fcn_name);
cd(bst_fullfile(BrainstormHomeDir, mexPath));

% Check if mex-file is already accessible
if file_exist(mexFile)
    % Check file size: if file is empty, delete it
    dirFile = dir(mexFile);
    if ~isempty(dirFile) && (dirFile.bytes == 0)
        file_delete(mexFile, 1);
    end
end

% Check if mex-file is not accessible: need to compile file
if ~file_exist(mexFile) && ~file_exist(mexFileUser)
    % === CHECK FILE RIGHTS ===
    % Check if user can write in this directory
    % If it is not possible, copy everything to user's mex directory and compile file there
    if ~file_attrib(mexFile, 'w')
        % Copy file to user's mex directory 
        userMexDir = bst_get('UserMexDir');
        % Copy current C-file and m-file to this directory
        file_copy(cFile, userMexDir);
        % Move to this user's mex directory
        cd(userMexDir);
        mexFile = strrep(mexFile, fileparts(mexFile), userMexDir);
        cFile   = strrep(cFile,   fileparts(cFile),   userMexDir);
        % Check again if we can access this file there
        if ~file_attrib(mexFile, 'w')
            if isInteractive
                bst_error(['Cannot compile MEX file "' fcn_name '":' 10 ...
                           'You are not allowed to write files in this directory.' 10 10 ...
                           'Please, try one of the following solutions:' 10 ...
                           '    1) Change access rights for files and directories.' 10 ...
                           '    2) Run Brainstorm as an administrator on this computer.' 10 ...
                           '    3) Report your problem on the Brainstorm forum.'], 'MEX compilation error', 0);
                
            else
                disp(['BST> Cannot compile MEX file "' fcn_name '": You are not allowed to write files in this directory.']);
            end
            cd(previousDir);
            return
        end
    end

    % === COMPILE MEX ===
    try
        fprintf(1, ['BST> Compiling: ', mexName, '... ']);
        mex('-v', cFile);
        fprintf(1, 'ok\n');
    catch
        % === PROCESS ERROR ===
        fprintf(1, 'failed\n');
        errMsg = ['Cannot compile MEX file "' fcn_name '": MEX compiler error.' 10 lasterr];
        if isInteractive
            bst_error(errMsg, 'MEX compilation error', 0);
            bst_help('MexError.html', 0);
        else
            disp([10 errMsg]);
        end
        cd(previousDir);
        return

    end
end

% Reset initial folder
cd(previousDir);
% Return success
isOk = 1;
% Update function cache
rehash path;



