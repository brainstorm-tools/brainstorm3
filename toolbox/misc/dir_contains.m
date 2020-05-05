function doesContain = dir_contains(parent_dir, sub_dir)
% DIR_CONTAINS: Checks whether directory "parent_dir" contains "sub_dir"
% under one of its sub-directories (recursive).

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
% Authors: Martin Cousineau, 2019

last_parent = [];
current_parent = bst_fileparts(sub_dir);

% Continue until we reach the highest directory
while ~isempty(current_parent) && ~strcmp(current_parent, last_parent)
    % Check whether current directory is the one we're looking for
    if file_compare(current_parent, parent_dir)
        doesContain = 1;
        return;
    end
    
    % Continue with parent
    last_parent = current_parent;
    current_parent = bst_fileparts(current_parent);
end

doesContain = 0;
