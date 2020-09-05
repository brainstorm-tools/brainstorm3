function [R, T, newP] = bst_meshfit(Vertices, Faces, P)
% BST_MESHFIT: Find the best possible rotation-translation to fit a point cloud on a mesh.
%
% USAGE:  [R, T, newP] = bst_meshfit(Vertices, Faces, P)
%
% DESCRIPTION: 
%     A Gauss-Newton method is used for the optimization of the distance points/mesh.
%     The Gauss-Newton algorithm used here was initially implemented by 
%     Qianqian Fang (fangq at nmr.mgh.harvard.edu) and distributed under a GPL license
%     as part of the Metch toolbox (http://iso2mesh.sf.net, regpt2surf.m).
%
% INPUTS:
%    - Vertices : [Mx3] double matrix
%    - Faces    : [Nx3] double matrix
%    - P        : [Qx3] double matrix, points to fit on the mesh defined by Vertices/Faces
%
% OUTPUTS:
%   R    : [3x3] rotation matrix from the original P to the fitted positions.
%   T    : [3x1] translation vector from the original P to the fitted positions.
%   newP : [Mx3] fitted positions of the points in input matrix P.

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
% Authors: Qianqian Fang, 2008
%          Francois Tadel, 2013

% Calculate norms
VertNorm = tess_normals(Vertices, Faces);
% Calculate the initial error
[distInit, dt] = get_distance(Vertices, VertNorm, P, []);
errInit = sum(abs(distInit));

% Fit points
[R,T,newP] = fit_points(Vertices, VertNorm, P, dt);

% Calculate the final error
distFinal = get_distance(Vertices, VertNorm, newP, dt);
errFinal = sum(abs(distFinal));
% If the error is larger than at the beginning: cancel the modifications
if (errFinal > errInit)
    disp('BST> The optimization failed finding a better fit');
    R = [];
    T = [];
    newP = P;
end

end


% ===== COMPUTE POINTS/MESH DISTANCE =====
% Approximates the distance to the mesh by the projection on the norm vector of the nearest neighbor
function [dist,dt] = get_distance(Vertices, VertNorm, P, dt)
    % Find the nearest neighbor
    [iNearest, dist_pt, dt] = bst_nearest(Vertices, P, 1, 0, dt);
    % Distance = projection of the distance between the point and its nearest 
    % neighbor in the surface on the vertex normal 
    % As the head surface is supposed to be very smooth, it should be a good approximation 
    % of the distance from the point to the surface.
    dist = abs(sum(VertNorm(iNearest,:) .* (P - Vertices(iNearest,:)),2));
end

% ===== COMPUTE TRANSFORMATION =====
% Gauss-Newton optimization algorithm
% Based on work from Qianqian Fang, 2008
function [R,T,newP] = fit_points(Vertices, VertNorm, P, dt)
    % Initial parameters: no rotation, no translation
    C = zeros(6,1);
    newP = P;
    % Sensitivity
    delta = 1e-4;
    % Maximum number of iterations
    maxiter = 20;
    % Initialize error at the previous iteration
    errPrev = Inf;
    % Start Gauss-Newton iterations
    for iter = 1:maxiter
        % Calculate the current residual: the sum of distances to the surface
        dist0 = get_distance(Vertices, VertNorm, newP, dt);
        err = sum(abs(dist0));
        % If global error is going up: stop
        if (err > errPrev)
            break;
        end
        errPrev = err;
        % fprintf('iter=%d error=%f\n', iter, err);
        % Build the Jacobian (sensitivity) matrix
        J = zeros(length(dist0),length(C));
        for i = 1:length(C)
            dC = C;
            if (C(i))
                dC(i) = C(i) * (1+delta);
            else
                dC(i) = C(i) + delta;
            end
            % Apply this new transformation to the points
            [tmpR,tmpT,tmpP] = get_transform(dC, P);
            % Calculate the distance for this new transformation
            dist = get_distance(Vertices, VertNorm, tmpP, dt);
            % J=dL/dC
            J(:,i) = (dist-dist0) / (dC(i)-C(i));
        end
        % Weight the matrix (normalization)
        wj = sqrt(sum(J.*J));
        J = J ./ repmat(wj,length(dist0),1);
        % Calculate the update: J*dC=dL
        dC = (J\dist0) ./ wj';
        C = C - 0.5*dC;
        % Get the updated positions with the calculated A and b
        [R,T,newP] = get_transform(C, P);
    end
end

% ===== GET TRANSFORMATION =====
function [R,T,P] = get_transform(params, P)
    % Get values
    mx = params(1); my = params(2); mz = params(3); % Translation parameters
    x = params(4); y = params(5); z = params(6); % Rotation parameters
    % Rotation
    Rx = [1 0 0 ; 0 cos(x) sin(x) ; 0 -sin(x) cos(x)]; % Rotation over x
    Ry = [cos(y) 0 -sin(y); 0 1 0; sin(y) 0 cos(y)]; % Rotation over y
    Rz = [cos(z) sin(z) 0; -sin(z) cos(z) 0; 0 0 1]; % Rotation over z
    R = Rx*Ry*Rz; 
    % Translation
    T = [mx; my; mz];
    % Apply to points
    if (nargin >= 2)
        P = (R * P' + T * ones(1,size(P,1)))';
    end
end


