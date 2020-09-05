function SUCCESS = file_copy(SOURCE, DESTINATION)
% FILE_COPY: Copy file SOURCE to path DESTINATION
%
% DESCRIPTION:
%     Replacement for the Matlab builtin call copyfile() that may return errors when the
%     access rights of the source file cannot be applied to the destination file.
%     This may occurr in the context of Windows shares mounted on a Linux system
%     as SMB or CIFS file systems.
%    
%     By default this function simply calls the function copyfile(), unless the option
%     "Use system calls to copy/move files" is selected in the Brainstorm preferences,
%     in which case it uses a system call to the system's "cp".
%
%     This only applies to Linux and MacOS systems, on Windows this function always
%     call Matlab's copyfile.

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
% Author: Francois Tadel, 2019


% Windows: Regular copy, no error capture
if ispc 
    SUCCESS = copyfile(SOURCE, DESTINATION, 'f');
    
% System copy: use system cp instead of copyfile
elseif bst_get('SystemCopy')
    % System call using cp
    sysCall = ['cp -rf "' SOURCE '" "' DESTINATION '"'];
    % Capture possible errors
    try
        status = system(sysCall);
        if (status == 0)
            SUCCESS = 1;
        else
            SUCCESS = 0;
        end
    catch
        SUCCESS = 0;
    end
    % Display error report
    if ~SUCCESS
        error([...
            'ERROR: File could not be copied using system''s cp.' 10 lasterr 10 ...
            'System call: ' sysCall 10 ...
            'Try NOT selecting the option "Use system calls to copy/move files" in the Brainstorm preferences.' 10]);
    end
            
% Regular copy: Use Matlab builtin copyfile()
else
    try
        SUCCESS = copyfile(SOURCE, DESTINATION, 'f');
    catch
        error([...
            'ERROR: File could not be copied using copyfile().' 10 lasterr 10 ...
            'When using network filesystems mounted as NFS, SMB or CIFS file systems, Matlab' 10 ...
            'function copyfile() may crash if the destination file rights cannot be set properly.' 10 ...
            'Try selecting the option "Use system calls to copy/move files" in the Brainstorm preferences.' 10]);
    end
end


