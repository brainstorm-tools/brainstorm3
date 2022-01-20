function [VertConn, distance] = grid_vertconn(GridLoc)
% GRID_VERTCONN: Compute a vertex adjacency matrix for a grid volume using Delaunay triangulations
%
% USAGE:  VertConn = grid_vertconn(GridLoc)
%
% INPUT: 
%    - GridLoc  : [Nx3] list of reference 3D points for the grid
% OUTPUT:
%    - VertConn : [NxN] vertex-vertex connectivity matrix (sparse)
%    - distance : Distance for each pair of vertices in the vertconn matrix

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
% Authors: Arnaud Gloaguen, Francois Tadel, 2015

% Maximum distance between two possible neighbors (in meters)
distance_max = 0.020;

% Get the nearest neighbors with Delaunay's triangulation (all the possible Matlab versions)
if exist('delaunayTriangulation', 'file')
    Tri = delaunayTriangulation(GridLoc);
elseif exist('DelaunayTri', 'file')
    Tri = DelaunayTri(GridLoc);
else
    Tri = delaunayn(GridLoc);
end

% Get all the connections in the triangulation
I = [Tri(:,1); Tri(:,1); Tri(:,1); ...
     Tri(:,2); Tri(:,2); ...
     Tri(:, 3)];
J = [Tri(:,2); Tri(:,3); Tri(:,4); ...
     Tri(:,3); Tri(:,4); ...
     Tri(:, 4)];     
% Create list of couple of points that are neighbours (2 directions)
connexion = unique([I,J], 'rows');
connexion = unique([connexion; connexion(:, [2,1])], 'rows');

% Compute distance for each of those neighbours
distance = sqrt((GridLoc(connexion(:,1), 1) - GridLoc(connexion(:,2), 1)).^2 + ...
                (GridLoc(connexion(:,1), 2) - GridLoc(connexion(:,2), 2)).^2 + ...
                (GridLoc(connexion(:,1), 3) - GridLoc(connexion(:,2), 3)).^2 );
% Delete connections between points that are too far apart
isDistOk = (distance <= distance_max);
connexion = connexion(isDistOk, :);
if (nargout >= 2)
    distance = distance(isDistOk, :);
end

% Compute connectivity matrix in sparse mode
VertConn = sparse(connexion(:, 1), connexion(:, 2), ones(size(connexion(:,1))), size(GridLoc, 1), size(GridLoc, 1));
% Check if points without neighbours
if ~all(any(VertConn, 2))
    disp(sprintf('BST> ERROR: Some grid points do not have neighbors at a distance inferior to %1.1fcm. Check the grid of dipoles.', distance_max*100));
end


    
