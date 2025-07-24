function [R, T, newP, distFinal] = bst_meshfit(Vertices, Faces, P, Outliers)
% BST_MESHFIT: Find the best possible rotation-translation to fit a point cloud on a mesh.
%
% USAGE:  [R, T, newP, distFinal] = bst_meshfit(Vertices, Faces, P)
%
% DESCRIPTION:
%     A Gauss-Newton method is used for the optimization of the distance points/mesh.
%     The Gauss-Newton algorithm used here was initially implemented by
%     Qianqian Fang (fangq at nmr.mgh.harvard.edu) and distributed under a GPL license
%     as part of the Metch toolbox (http://iso2mesh.sf.net, regpt2m).
%
% INPUTS:
%    - Vertices : [Mx3] double matrix
%    - Faces    : [Nx3] double matrix
%    - P        : [Qx3] double matrix, points to fit on the mesh defined by Vertices/Faces
%    - Outliers : proportion of outlier points to ignore (between 0 and 1)
%
% OUTPUTS:
%    - R         : [3x3] rotation matrix from the original P to the fitted positions.
%    - T         : [3x1] translation vector from the original P to the fitted positions.
%    - newP      : [Mx3] fitted positions of the points in input matrix P.
%    - distFinal : [Mx1] final distance between points and mesh

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
% Authors: Qianqian Fang, 2008
%          Francois Tadel, 2013-2021
%          Marc Lalancette, 2022

% Coordinates are in m.
PenalizeInside = true;
SquareDistCost = false;
if nargin < 4 || isempty(Outliers)
    Outliers = 0;
end

% nV = size(Vertices, 1);
nF = size(Faces, 1);
nP = size(P, 1);
Outliers = ceil(Outliers * nP);

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
FaceNormals = bsxfun(@rdivide, FaceNormals, sqrt(sum(FaceNormals.^2, 2))); % normr
%FaceArea = sqrt(sum(FaceNormals.^2, 2));
% Perpendicular vectors to edges, pointing inside triangular face.
for e = 3:-1:1
    EdgeTriNormals(:,:,e) = cross(FaceNormals, EdgesV(:,:,e));
end
FaceVertices = zeros(nF, 3, 3);
FaceVertices(:,:,1) = Vertices(Faces(:,1),:);
FaceVertices(:,:,2) = Vertices(Faces(:,2),:);
FaceVertices(:,:,3) = Vertices(Faces(:,3),:);

% Calculate the initial error
InitParams = zeros(6,1);
errInit = CostFunction(InitParams);

% Fit points
% [R,T,newP] = fit_points(Vertices, VertNorm, P, dt);
% Do optimization
% Stop at 0.1 mm total distance, or 0.02 mm displacement.
OptimOptions = optimoptions(@fminunc, 'MaxFunctionEvaluations', 1000, 'MaxIterations', 200, ...
    'FiniteDifferenceStepSize', 1e-3, ...
    'FunctionTolerance', 1e-4, 'StepTolerance', 2e-2, 'Display', 'none'); % 'OptimalityTolerance', 1e-15,  'final-detailed'

BestParams = fminunc(@CostFunction, InitParams, OptimOptions);
[R,T,newP] = Transform(BestParams, P);
T = T';
distFinal = PointSurfDistance(newP);

% Calculate the final error
errFinal = CostFunction(BestParams);
% If the error is larger than at the beginning: cancel the modifications
% Should no longer occur.
if (errFinal > errInit)
    disp('BST> The optimization failed finding a better fit');
    R = [];
    T = [];
    newP = P;
end

% Better cost function for points fitting: higher cost for points inside the
% head > 1mm, (better distance calculation).
    function [Cost, Dist] = CostFunction(Params)
        [~,~,Points] = Transform(Params, P);
        Dist = PointSurfDistance(Points);
        if PenalizeInside
            isInside = inpolyhedron(Faces, Vertices, Points, 'FaceNormals', FaceNormals, 'FlipNormals', true);
            %patch('Faces',Faces,'Vertices',Vertices); hold on; light; axis equal;
            %quiver3(FaceVertices(:,1,1), FaceVertices(:,2,1), FaceVertices(:,3,1), FaceNormals(:,1,1), FaceNormals(:,2,1), FaceNormals(:,3,1));
            %scatter3(Points(1,1),Points(1,2),Points(1,3));
            iSquare = isInside & Dist > 0.001;
            Dist(iSquare) = Dist(iSquare).^2 *1e3; % factor for "squaring in mm units"
            iOutside = find(~isInside);
        end
        if SquareDistCost
            Cost = sum(Dist.^2);
        else
            Cost = sum(Dist);
        end
        for iP = 1:Outliers
            if PenalizeInside 
                % Only remove outside points.
                [MaxD, iMaxD] = max(Dist(~isInside));
                Dist(iOutside(iMaxD)) = 0;
            else
                [MaxD, iMaxD] = max(Dist);
                Dist(iMaxD) = 0;
            end
            if SquareDistCost
                Cost = Cost - MaxD.^2;
            else
                Cost = Cost - MaxD;
            end
        end
    end

%% TODO Slow, look for alternatives.  
% This seems similar: https://www.mathworks.com/matlabcentral/fileexchange/52882-point2trimesh-distance-between-point-and-triangulated-surface
% ===== COMPUTE POINTS/MESH DISTANCE =====
% For exact distance computation, we need to check all 3: vertices, edges and faces.  
    function Dist = PointSurfDistance(Points)
        Epsilon = 1e-9; % nanometer
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


% % Approximates the distance to the mesh by the projection on the norm vector of the nearest neighbor
% function [dist,dt] = get_distance(Vertices, VertNorm, P, dt)
%     % Find the nearest neighbor
%     [iNearest, dist_pt, dt] = bst_nearest(Vertices, P, 1, 0, dt);
%     % Distance = projection of the distance between the point and its nearest
%     % neighbor in the surface on the vertex normal
%     % As the head surface is supposed to be very smooth, it should be a good approximation
%     % of the distance from the point to the surface.
%     dist = abs(sum(VertNorm(iNearest,:) .* (P - Vertices(iNearest,:)),2));
% end

% ===== GET TRANSFORMATION =====
    function [R,T,Points] = Transform(Params, Points)
        % Translation in mm (to use default TypicalX of 1)
        T = Params(1:3)'/1e3;
        % Rotation in degrees (again for expected order of magnitude of 1)
        x = Params(4)*pi/180; y = Params(5)*pi/180; z = Params(6)*pi/180; % Rotation parameters
        Rx = [1 0 0 ; 0 cos(x) sin(x) ; 0 -sin(x) cos(x)]; % Rotation over x
        Ry = [cos(y) 0 -sin(y); 0 1 0; sin(y) 0 cos(y)]; % Rotation over y
        Rz = [cos(z) sin(z) 0; -sin(z) cos(z) 0; 0 0 1]; % Rotation over z
        R = Rx*Ry*Rz;
        % Apply to points
        Points = bsxfun(@plus, Points * R', T);
    end

end


