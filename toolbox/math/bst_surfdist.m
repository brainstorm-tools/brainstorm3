function Dist = bst_surfdist(Points, Vertices, Faces)
% BST_SURFDIST: Compute the distances between points and a surface.
%
% USAGE:  Dist = bst_surfdist(Points, Vertices, Faces)
%
% DESCRIPTION:
%     Exact distance computation, which checks all 3 sets of distances: points
%     to vertices, points to edges, and points to faces, keeping the smallest
%     for each point.
%
% INPUTS:
%    - Points   : [Qx3] double matrix, points to compare to the mesh defined by Vertices/Faces
%    - Vertices : [Mx3] double matrix
%    - Faces    : [Nx3] double matrix
%
% OUTPUTS:
%    - Dist     : [Qx1] final distance between points and mesh

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
% Authors: Marc Lalancette, 2022

% TODO: A bit slow, look for alternatives
% This seems similar: https://www.mathworks.com/matlabcentral/fileexchange/52882-point2trimesh-distance-between-point-and-triangulated-surface
Epsilon = 1e-9; % nanometer
nP = size(Points, 1);
nF = size(Faces, 1);

% Prepare surface quantities, independent of points
% (In bst_meshfit, this can be done only once before iterative fitting.)
% Edges as indices
Edges = unique(sort([Faces(:,[1,2]); Faces(:,[2,3]); Faces(:,[3,1])], 2), 'rows');
% Edge direction "doubly normalized" so that later projection should be between 0 and 1.
EdgeDir = Vertices(Edges(:,2),:) - Vertices(Edges(:,1),:);
EdgeL = sqrt(sum(EdgeDir.^2, 2));
EdgeDir = bsxfun(@rdivide, EdgeDir, EdgeL);
% Edges as vectors
EdgesV = zeros(nF, 3, 3);
EdgesV(:,:,1) = Vertices(Faces(:,2),:) - Vertices(Faces(:,1),:);
EdgesV(:,:,2) = Vertices(Faces(:,3),:) - Vertices(Faces(:,2),:);
EdgesV(:,:,3) = Vertices(Faces(:,1),:) - Vertices(Faces(:,3),:);
% First edge to second edge: counter clockwise = up
FaceNormals = cross(EdgesV(:,:,1), EdgesV(:,:,2));
%FaceArea = sqrt(sum(FaceNormals.^2, 2));
FaceNormals = bsxfun(@rdivide, FaceNormals, sqrt(sum(FaceNormals.^2, 2)));
% Perpendicular vectors to edges, pointing inside triangular face.
for e = 3:-1:1
    EdgeTriNormals(:,:,e) = cross(FaceNormals, EdgesV(:,:,e));
end
FaceVertices = zeros(nF, 3, 3);
FaceVertices(:,:,1) = Vertices(Faces(:,1),:);
FaceVertices(:,:,2) = Vertices(Faces(:,2),:);
FaceVertices(:,:,3) = Vertices(Faces(:,3),:);


% Check distance to vertices
if license('test','statistics_toolbox')
    DistVert = pdist2(Vertices, Points, 'euclidean', 'Smallest', 1)';
else
    DistVert = zeros(nP, 1);
    for iP = 1:nP
        % Find closest surface vertex.
        DistVert(iP) = sqrt(min(sum(bsxfun(@minus, Points(iP, :), Vertices).^2, 2)));
    end
end
% Check distance to faces
DistFace = inf(nP, 1);
for iP = 1:nP
    % Considered Möller and Trumbore 1997, Ray-Triangle Intersection (https://stackoverflow.com/questions/42740765/intersection-between-line-and-triangle-in-3d), but this is simpler still.
    % Vectors from triangle vertices to point.
    Pyramid = bsxfun(@minus, Points(iP, :), FaceVertices);
    % Does the point project inside each face?
    InFace = all(sum(Pyramid .* EdgeTriNormals, 2) > -Epsilon, 3);
    if any(InFace)
        DistFace(iP) = min(abs(sum(Pyramid(InFace,:,1) .* FaceNormals(InFace,:), 2)));
    end
end
% Check distance to edges
DistEdge = inf(nP, 1);
for iP = 1:nP
    % Vector from first edge vertex to point.
    Pyramid = bsxfun(@minus, Points(iP, :), Vertices(Edges(:, 1), :));
    Projection = sum(Pyramid .* EdgeDir, 2);
    InEdge = Projection > -Epsilon & Projection < (EdgeL + Epsilon);
    if any(InEdge)
        DistEdge(iP) = sqrt(min(sum((Pyramid(InEdge,:) - bsxfun(@times, Projection(InEdge), EdgeDir(InEdge,:))).^2, 2)));
    end
end

Dist = min([DistVert, DistEdge, DistFace], [], 2);
end

