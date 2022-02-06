function [Vertices, Faces, remove_vertices, remove_faces, Atlas] = tess_clean(Vertices, Faces, Atlas)
% TESS_CLEAN: Check the integrity of a tesselation.
%
% USAGE:  [Vertices, Faces, remove_vertices, Atlas] = tess_clean(Vertices, Faces, Atlas)
%
% DESCRIPTION:
%      Check in a tesselation if there are some identical faces with opposite 
%      orientations and remove the bad_oriented one. Moreover it removes
%      isolated triangles and some other pathological configurations.
%
% INPUTS:
%    - Vertices : Mx3 double matrix
%    - Faces    : Nx3 double matrix
%    - tol      : takes into account the fact that redundant faces can have 
%                 coordinates very near but slightly different. (default 10^-10)
% OUTPUTS:
%    - Vertices : Corrected vertices structure
%    - Faces    : Corrected faces structure

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
% Authors: Julien Lefevre, 2007
%          Francois Tadel, 2008-2014

% Parse inputs
if (nargin < 3) || isempty(Atlas)
    Atlas = [];
end
% Check matrices orientation
if (size(Vertices, 2) ~= 3) || (size(Faces, 2) ~= 3)
    error('Faces and Vertices must have 3 columns (X,Y,Z).');
end
% Default tolerance
tol = 1e-10;

TessArea = tess_area(Vertices, Faces);
[tmp, FaceNormals] = tess_normals(Vertices, Faces);

sort_crossprod = sortrows(abs([FaceNormals,(1:size(FaceNormals,1))']));
diff_sort_crossprod = diff(sort_crossprod);
indices = find((diff_sort_crossprod(:,1) < tol) & ...
               (diff_sort_crossprod(:,2) < tol) & ...
               (diff_sort_crossprod(:,3) < tol));
% Indices of redundant triangles (same coordinates, two different orientations)
indices_tri1 = sort_crossprod(indices,4); 
indices_tri2 = sort_crossprod(indices+1,4);

[VertFacesConn, FaceConn] = tess_faceconn(Faces);

% For each suspected face we compute the mean of normals of neighbouring faces
scal=zeros(length(indices_tri1),2);
remove_faces=[];
remove_vertices=[];

% We remove faces whose normal is not in the same direction as their neighbouring faces
for i=1:length(indices_tri1)
    neighbours = find(FaceConn(indices_tri1(i),:));
    neighbours = setdiff(neighbours, indices_tri2(i));
    % Isolated faces
    if isempty(neighbours) 
        remove_faces    = [remove_faces,    indices_tri1(i), indices_tri2(i)];
        remove_vertices = [remove_vertices, Faces(indices_tri1(i),:)];
    else
        normal_mean = mean(FaceNormals(neighbours,:) .* repmat(TessArea(neighbours),1,3),1);
        norm_i = FaceNormals(indices_tri1(i),:);
        scal(i,1) = normal_mean*norm_i'/(norm(normal_mean));

        if scal(i,1)>0
            remove_faces = [remove_faces,indices_tri2(i)];
            scal(i,2) = indices_tri2(i);
        else
            if scal(i,1)<0
                remove_faces = [remove_faces,indices_tri1(i)];
                scal(i,2) = indices_tri1(i);
            else
                remove_faces = [remove_faces,indices_tri1(i),indices_tri2(i)];
                remove_vertices = [remove_vertices, Faces(indices_tri1(i),:)];
            end
        end
    end
end

% Find all the isolated faces
FaceConn(remove_faces, :) = 0;
FaceConn(:, remove_faces) = 0;
iIsolatedFaces = find(sum(FaceConn) <= 1);
remove_faces = union(remove_faces', iIsolatedFaces);
% Remove faces
Faces(remove_faces, :) = [];

% Find the vertices that are not used in any face
VertConn = tess_vertconn(Vertices, Faces);
iIsolatedVert = find(sum(VertConn) <= 1);
remove_vertices = union(remove_vertices, iIsolatedVert);
% Remove vertices
[Vertices, Faces, Atlas] = tess_remove_vert(Vertices, Faces, remove_vertices, Atlas);



