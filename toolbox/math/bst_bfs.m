function [ HeadCenter, Radius ] = bst_bfs( Vertices )
% BST_BFS: Compute best fitting sphere (BFS) for a set of points.
%
% USAGE:  [ HeadCenter, Radius ] = bst_bfs( Vertices )
%
% INPUT:
%     - Vertices  : [Nv,3] double, (x,y,z) coordinates of the points
% OUTPUT:
%     - HeadCenter: (x,y,z) coordinates of the BFS
%     - Radius    : Radius of the BFS

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
% Authors: Francois Tadel, 2008-2011

% Check matrices orientation
if (size(Vertices, 2) ~= 3)
    error('Vertices must have 3 columns (X,Y,Z).');
end
% Convert vertices into double
Vertices = double(Vertices);
% 500 points is more than enough to compute scalp's best fitting sphere
nscalp = size(Vertices,1);
if (nscalp > 500)
    Vertices = Vertices(unique(round(linspace(1,nscalp,500))),:);
end

% Center of mass of the scalp vertex locations
mass = mean(Vertices);
% Average distance between the center of mass and the scalp points
diffvert = bst_bsxfun(@minus, Vertices, mass);
R0 = mean(sqrt(sum(diffvert.^2, 2)));

% Optimization
vec0 = [mass,R0];
minn = fminsearch(@dist_sph, vec0, [], Vertices);

% Results : Center
HeadCenter = minn(1:end-1)'; % 3x1
% Largest radius (largest sphere radius)
Radius = minn(end);

end


%% ===== FMINS FUNCTION =====
% FMINS distance function used to minimize the fit to a sphere.
% Given center and list of sensor points, find the average distance from the center to these points
function d = dist_sph(vec,sensloc)
    R = vec(end);
    center = vec(1:end-1);
    % Average distance between the center if mass and the electrodes
    diffvert = bst_bsxfun(@minus, sensloc, center);
    d = mean(abs(sqrt(sum(diffvert.^2,2)) - R));
end


