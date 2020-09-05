function bst_reset()
% BST_RESET: Reset Brainstorm installation (Delete database, restore default options)
%
% USAGE:  bst_reset()

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
% Authors: Francois Tadel, 2008

% Close Brainstorm
if ~isempty(bst_mutex('get', 'Brainstorm'))
    bst_exit();
end
% Remove database file
BrainstormDbFile = bst_get('BrainstormDbFile');
if ~isempty(BrainstormDbFile) && exist(BrainstormDbFile, 'file')
    delete(BrainstormDbFile);
end
% Clear variables
clear

disp('Brainstorm environment reset.');
disp(' ');

