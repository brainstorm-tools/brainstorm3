function [FaceArea, VertArea] = tess_area(Vertices, Faces)
% TESS_AREA: Compute the surface area associated with each face and each vertex.

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
% Authors: Francois Tadel, 2012-2016

% Compute the area of all the faces
r12 = Vertices(Faces(:,1),:);        % temporary holding
r13 = Vertices(Faces(:,3),:) - r12;  % negative of r31
r12 = Vertices(Faces(:,2),:) - r12;  % from 1 to 2
FaceArea = sqrt(sum(bst_cross(r12,r13,2).^2, 2)) / 2;

% Compute the triangle area only if needed
if (nargout >= 2)
    % Build vertex-face connectivity matrix, with the area information
    nFaces = size(Faces,1);
    rowno = double([Faces(:,1); Faces(:,2); Faces(:,3)]);
    colno = [1:nFaces, 1:nFaces, 1:nFaces]';
    data  = [FaceArea; FaceArea; FaceArea];
    VertFacesArea = sparse(rowno,colno,data);

    % Compute the vertex area: 1/3 of each triangle involving this vertex
    VertArea = 1/3 * full(sum(VertFacesArea,2));
end
    
    