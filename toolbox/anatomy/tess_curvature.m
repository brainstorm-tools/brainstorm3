function [c, cs] = tess_curvature(Vertices, VertConn, VertNormals, sigmoid_const, show_sigmoid)
% TESS_CURVATURE: Calculate an approximation of the mean curvature of a surface. 
%
% USAGE: [c, cs] = tess_curvature(Vertices, VertConn, VertNormals, sigmoid_const, show_sigmoid)
%        [c, cs] = tess_curvature(Vertices, VertConn, VertNormals, sigmoid_const)
%
% DESCRIPTION:
%     It calculates the mean angle between the surface normal of a vertex and 
%     the edges formed by the vertex and the neighbouring ones.
%
% INPUT:
%    - Vertices      : Mx3 double matrix
%    - VertConn      : Connectivity matrix
%    - VertNormals   : Vertex normals
%    - sigmoid_const : sigmoid constant (scalar 0-inf). The curvature 'cs' is weighted by a sigmoid 
%                      to make a sudden transition from convex to concave regions. Use small values
%                      for linear transitions, and large (eg. 50) for sudden transitions
%    - show_sigmoid  : 1 to display the sigmoid function, 0 otherwise
%
% OUTPUT:
%    - cs : curvature of the surface, weighted by the sigmoid
%    - c  : curvature of the surface

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
% Authors: Dimitrios Pantazis, Anand Joshi, November 2007
%          Francois Tadel, 2008-2010

% Parse inputs
if (nargin < 5)
    show_sigmoid = 0;
end
% Check matrices orientation
if (size(Vertices, 2) ~= 3) || (size(VertNormals, 2) ~= 3)
    error('Vertices and VertNormals must have 3 columns (X,Y,Z).');
end
nv = size(Vertices,1);
Vertices = double(Vertices);

%get the edges for each vertex------------------------------------

%sparse matrix with the vertex coordinates in the diagonal
Dx = spdiags(Vertices(:,1),0,nv,nv);
Dy = spdiags(Vertices(:,2),0,nv,nv);
Dz = spdiags(Vertices(:,3),0,nv,nv);

%for each neighbor of the vertex, set the neighbor coordinates on the rows of Cx
Cx = VertConn * Dx;
Cy = VertConn * Dy;
Cz = VertConn * Dz;

%for each neighbor of the vertex, set the vertex coordinates on the rows of Cx1. However, this is redundant, because it is the transpose of the above!
%Cx1=Dx*VertConn; %transpose of Cx!
%Cy1=Dy*VertConn;
%Cz1=Dz*VertConn;

%get the edges, which is the neighbor coordinates minus the central vertex coordinates
Ex = Cx - Cx';
Ey = Cy - Cy';
Ez = Cz - Cz';

%make edges unit norm
En = sqrt(Ex.^2 + Ey.^2 + Ez.^2);
Eninv = spfun(@(x) 1./x , En); 
Ex = Ex .* Eninv;
Ey = Ey .* Eninv;
Ez = Ez .* Eninv;

% Get inner product of normals with edges, which would be the cosine of an angle 0-180 degrees
Ip = spdiags(VertNormals(:,1), 0, nv, nv) * Ex ...
   + spdiags(VertNormals(:,2), 0, nv, nv) * Ey...
   + spdiags(VertNormals(:,3), 0, nv, nv) * Ez;

%get angle and normalize it to -90 to 90 degrees
Ipacos = spfun(@(x) acos(x) , Ip);
c = sum(Ipacos,2) ./ sum(VertConn,2) -pi/2;
% Fix vertices with no connections
c(isnan(c)) = 0;

if (show_sigmoid)
    %get sigmoid weighted curvature (for rough transitions from sulci to gyri)
    cs = 1 ./ (1+exp(-c.*sigmoid_const)) - 0.5;
    %show sigmoid weighting function in required
    x = -pi/2:0.01:pi/2;
    y = 1 ./ (1+exp(-x*sigmoid_const)) - 0.5;
    figure;
    plot(x,y)
    grid on;
    title('Transition between negative and positive curvature');
end

