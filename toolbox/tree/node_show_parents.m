function isShown = node_show_parents(iSearch)
% NODE_SHOW_PARENTS: Checks whether parent nodes are to be shown in the database tree
%
% INPUT: 
%    - iSearch: ID of the search to apply, or root of a search structure
%
% OUTPUT: 
%    - isShown: Whether the parent nodes are to be shown (1) or not (0)

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
% Authors: Martin Cousineau, 2020

if isnumeric(iSearch)
    % If no filter applied, show the parent nodes
    if iSearch == 0
        isShown = 1;
        return;
    end
    % Get the active search
    searchRoot = panel_protocols('ActiveSearch', 'get', iSearch);
    if isempty(searchRoot)
        error(sprintf('Could not find active search #%d', iSearch));
    end
else
    % Search structure provided in arguments
    searchRoot = iSearch;
end

if searchRoot.Type == 3 && ~isempty(searchRoot.Value) && searchRoot.Value == 1
    isShown = 0;
else
    isShown = 1;
end
    