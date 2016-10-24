function newverts = tess_scout_swell(iverts, vconn)
% TESS_SCOUT_SWELL: Enlarge a patch by appending the next set of adjacent vertices.
%
% USAGE:  newverts = tess_scout_swell(iverts, vconn);
%
% INPUT:
%     - iverts : index list of vertex numbers
%     - vconn  : sparse matrix of vertex connectivity
% OUTPUT:
%     - newverts: row vec list of NEW vertex numbers adjacent the patch

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2016 University of Southern California & McGill University
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
% Authors: ?

if (size(iverts,1) ~= 1)
  iverts = iverts(:)'; % ensure row vector
end

%%%%%%% BUG WORKAROUND FOR MATLAB R2009a: 7.8.0 %%%%%%
% Get version name
vername = version;
% If bugged version: need to convert matrice to a FULL one
if strcmpi(vername(1:5), '7.8.0')
    % Concatenate all vertex connections for all verts
    newverts = find(max(full(vconn(iverts, :)), [], 1));
else
    % Concatenate all vertex connections for all verts
    newverts = find(max(vconn(iverts, :), [], 1));
end

% Extract unique set of indices, remove existing vertices
newverts = setdiff(newverts, iverts);



