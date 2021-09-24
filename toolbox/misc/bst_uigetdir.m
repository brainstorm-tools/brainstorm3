function selectedPath = bst_uigetdir(currentPath, title)
% BST_UIGETDIR: Custom implementation of uigetdir to support headless mode
%
% USAGE: selectedPath = bst_uigetdir(currentPath) : Without a custom title
%        selectedPath = bst_uigetdir(currentPath, title) : With a title

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
% Authors: Martin Cousineau, 2018

if nargin < 2
    title = [];
end

% If the GUI is available, use builtin function
if bst_get('GuiLevel') >= 0
    selectedPath = uigetdir(currentPath, title);
% Headless dialog displayed in command line
else
    if ~isempty(title)
        disp(title);
    end
    
    isStop = 0;
    while ~isStop
        selectedPath = input('Please enter the directory: ', 's');
        if isempty(selectedPath) || exist(selectedPath, 'dir') == 7
            isStop = 1;
        else
            disp('Please enter a valid directory.');
        end
    end
end
