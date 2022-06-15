function bst_which(filename, exploreMode)
% BST_WHICH:  Locates a file on disk, using available system tools
% 
% USAGE:  bst_which(filename, 'explorer')
%         bst_which(filename, 'terminal')

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
% Authors: Francois Tadel, 2010-2013

% Parse inputs
isTerminal = strcmpi(exploreMode, 'terminal');

% Check file type
fileType = file_gettype(filename);
switch (fileType)
    case 'link'
        filename = file_resolve_link(filename);
    case 'data'
        isRaw = (length(filename) > 9) && ~isempty(strfind(filename, 'data_0raw'));
        if isRaw
            FileMat = in_bst_data(filename, 'F');
            filename = FileMat.F.filename;
        end
end
% Folder / file
if isdir(filename)
    filepath = filename;
else
    filepath = bst_fileparts(filename);
end

% === WINDOWS ===
if strncmp(computer,'PC',2)
    % Open Windows CMD
    if isTerminal
        dos(['cmd.exe /k cd ' filepath]);
    % Open Windows Explorer
    else
        dos(['explorer /e,/select,' filename]);
    end
    
% === MAC OS ===
elseif strncmp(computer,'MAC',3)
    % Open Terminal
    if isTerminal
        system(['open -a Terminal.app']);
    % Open Finder
    else
        system(['open -a Finder.app "' filepath '"']);
    end
    
% === OTHER SYSTEMS ===
else
    % === TERMINAL ===
    if isTerminal
        xdg_deskptop = getenv('XDG_CURRENT_DESKTOP');
        % KDE default terminal
        if strcmp('KDE', xdg_deskptop) && (system('which konsole > /dev/null') == 0)
            [status, cmdout] = system(['export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu && konsole --workdir "' filepath '" &']);
            if status == 0, return; end
        end
        % MATE default terminal
        if strcmp('MATE', xdg_deskptop) && (system('which mate-terminal > /dev/null') == 0)
            [status, cmdout] = system(['mate-terminal --working-directory="' filepath '" &']);
            if status == 0, return; end
        end
        % GNOME terminal
        if system('which gnome-terminal > /dev/null') == 0
            [status, cmdout] = system(['gnome-terminal --working-directory="' filepath '" &']);
            if status == 0, return; end
        end
        % XTERM
        if system('which xterm > /dev/null')
            [status, cmdout] = system(['xterm -e ''cd "' filepath '" && /bin/bash'' &']);
            if status == 0, return; end
        end
        % Error
        disp(cmdout);
        error('No terminal emulator found for your operating system.');
        
    % === FILE EXPLORERS ===
    else
        % Any X Desktop Group (XDG) compliant
        ixXdg = system('which xdg-open > /dev/null');
        if (ixXdg == 0)          
            [status, cmdout] = system(['xdg-open "' filepath '"']);
            if status == 0, return; end
        end
        % DOLPHIN (KDE)
        isKde = system('which dolphin > /dev/null');
        if (isKde == 0)
            [status, cmdout] = system(['export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu && dolphin "' filepath '" &']);
            if status == 0, return; end
        end
        % NAUTILUS (GNOME)
        isGnome = system('which nautilus > /dev/null');
        if (isGnome == 0)
            [status, cmdout] = system(['nautilus "' filepath '" &']);
            if status == 0, return; end
        end
        % Error
        disp(cmdout);
        error('No file manager found for your operating system.');
    end
end



