function [intersect,indx,t,u,v] = tess_ray_intersect(Vertices, Faces, r, d, cull, isOrient)
% TESS_RAY_INTERSECT: find intersection of a ray with a set of faces.
%
% USAGE:  [intersect,indx,t,u,v] = tess_ray_intersect(Vertices, Faces, r, d, cull, isOrient=0)
%
% INPUT:
%     - Vertices : Mx3 double matrix
%     - Faces    : Nx3 double matrix
%     - r        : Observation point
%     - d        : Unit directional vector (from point r)
%                  (will be automatically scaled to unity in the program)
%     - cull     : One of 'i', 'o', or 'b', for inside (backside), outside (frontside), or both sides.
%     - isOrient : If 1, returns only the interections in the direction FROM r TO d
%
% OUTPUT:
%    - indx  : index such that Faces(INDX,:) gives the triangles intersected.
%    - t,u,v : gives distance t to the point(s) of intersection, with point(s) of intersection given by
%              INTERSECT = (1-U-V) .* Vertices(Faces(indx,1),:) + ...
%                          U .* Vertices(Faces(indx,2),:) + V .* Vertices(Faces(indx,3),:);
%              where U is repmat(u,1,3) and similarly V.
%
% NOTES:
%    - To use in the calculation. Only first letter of CULL is
%      considered, so 'inside', 'outside', or 'both' are acceptable.
%    - For example, 'i' means the ray passes from the observation r in the
%      direction d through the backside and out the frontside of the triangle.
%    - In other words, the observation is inside a closed surface.
%    - Note that the program assumes right-handedness in the faces description,
%      such that V0 to V1 to V2 points "out" or "front."

% ====================================================================
% Uses Tomas Moeller and Ben Trumbore's "Fast, Minimum Storage
%  Ray/Triangle Intersection" 1997approach. Given a line defined by
%  L(t) = R + t * D and a triangle vertex V0 and edges E1 and E2
%  emanating from VO. Then the point of intersection between the
%  ray and the plane defined by the triangle is
%  [-D, E1, E2] [t;u;v] = R - V0;
% If u and v are both 0 <= u,v <= 1, then the intersection
%  is in the bounds of the triangle. The point on the triangle
%  is given by T(u,v) = (1 - u - v)*V0 + u*V1 + v*V2, where
%  E1 = V1 - V0, and E2 = V2 - V0. {u,v} are the barycentric
%  coordinates of the triangle.
% The solution is simply Cramer's rule,
%      [t]   =  {T,E1,E2}   /
%      [u]   =  {-D,T,E2}  /   {-D,E1,E2}.
%      [v]   =  {-D,E1,T} /
%  where T is the translation R - V0, and {a,b,c} is the
%  triple scalar product.
% Moeller and Trumbore's trick is to first cull the set of triangles
%  looking for determinants in the correct direction. In this reduced
%  subset, they look for triangles whose u is properly bounded. In the
%  greatly reduced subset, the look for triangles whose v is properly
%  bounded. The finally apply the division to get the units correct.
%
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
% Authors: John C. Mosher, 2001
%          Francois Tadel, 2008-2023

% Parse inputs
if (nargin < 6) || isempty(isOrient)
    isOrient = 0;
end
if (nargin < 5) || isempty(cull)
    cull = 'o'; % outside
else
    cull = lower(cull(1));
end
% Check matrices orientation
if (size(Vertices, 2) ~= 3) || (size(Faces, 2) ~= 3)
    error('Faces and Vertices must have 3 columns (X,Y,Z).');
end

% Tolerance for parallel triangles, will be scaled below to maximum triangle length
tol = 1e-6; 
% Tolerance in the barycentric coordinates
EPS = 1e-6; 
% Force to column unity
d = d(:)/norm(d(:));
% Force to column
r = r(:);
% Number of triangles
mfaces = size(Faces, 1); 

% Edge from vertext 0 to vertex 1 first. then vertex 2
e1 = (Vertices(Faces(:,2),:) - Vertices(Faces(:,1),:))'; % 3 x m
e2 = (Vertices(Faces(:,3),:) - Vertices(Faces(:,1),:))'; % 3 x m

% want to economically set the tolerance to something relative to the scale of the
%  triangles. Calculating the area would require expensive cross product
%  area = e1 x e2 / 2. Just use side one as good enough
tol = max(sqrt(sum(e1.^2, 1))) * tol;

% partial calculation using Moeller's "p" and "q"
% p is the d x e2
p = cross(d(:,ones(1,mfaces)),e2);

% e1 dot d cross e2 is the determinant of each triangle
% (note determinant is twice the area of the triangle).
Det = sum(e1 .* p); % determinant of each triangle

% if the determinant is (almost) zero, then the
%  ray is passing (almost) parallel to the surface of the
%  triangle. So there is (almost) no intersection.

% The ray has a direction. If the direction of the ray hits
%  the backside of the triangle, then the ray and the triangle
%  are both pointing in the same direction, and we say that
%  the triangle is passing from the inside to the outside or
%  backside to frontside.
% If the ray is pointing in the opposite direction, then
%  the ray is passing from the outside to the inside (frontside
%  to backside).

%  If the determinant is negative, then we are passing through
%  the backside of the triangle. If positive, then the
%  frontside.

switch cull
	case 'b' % both sides are considered
		ndx = find(Det < -tol | Det > tol);
	case 'i' % only those for which we are passing from inside to outside
		ndx = find(Det < -tol);
	case 'o' % passing from outside to inside
		ndx = find(Det > tol);
end

% so ndx gives us a subset of triangles for further processing

% calculate distance from V0 to the observation for each triangle
T = r(:,ones(1,length(ndx))) - Vertices(Faces(ndx,1),:)';

% now solve for the first barycentric coordinate, unscaled
u = sum(T .* p(:,ndx)); % dot product

u = u ./ Det(ndx); % handles negative cases

% find properly bounded u
ndx2 = find(u >= -EPS & u <= 1+EPS);

if(isempty(ndx2)),
	intersect = [];
	indx = [];
	t = [];
	u = [];
	v = [];
	return
end

% ndx2 is double referenced, such that ndx(ndx2) refers
%  to the original triangle numbering. Should be a greatly
%  reduced set of indices

% the other Moeller variable is "q", q = T x E1
%  form only for valid u
q = cross(T(:,ndx2),e1(:,ndx(ndx2)));

% form the other barycentric coordinate
v = sum(d(:,ones(1,size(q,2))) .* q); % dot product

v = v ./ Det(ndx(ndx2));

% lookfor valid v
ndx3 = find(v >= -EPS & (u(ndx2) + v) <= 1+EPS);

% ndx3 may be null or singleton
if(isempty(ndx3)),
	intersect = [];
	indx = [];
	t = [];
	u = [];
	v = [];
	return
else
	indx = ndx(ndx2(ndx3)); % relative indexing
end

% indx gives us the original absolution indexing

% scale each solution by the determinant
t = sum(e2(:,indx) .* q(:,ndx3))' ./ Det(indx)'; % dot product
u = u(ndx2(ndx3))';
v = v(ndx3)';
U = repmat(u,1,3);
V = repmat(v,1,3);
intersect = (1-U-V) .* Vertices(Faces(indx,1),:) + ...
	              U .* Vertices(Faces(indx,2),:) + ...
                  V .* Vertices(Faces(indx,3),:);

intersect = intersect'; % one intersection per column

% If orientation is important
if isOrient
    % Compute the scalar product to make sure the interestion is on the same side as the target 
    scalProd = sum(bst_bsxfun(@times, bst_bsxfun(@minus, intersect, r(:)), d(:)), 1);
    % Remove the intersection points on the incorrect side
    iRemove = find(scalProd < 0);
    if ~isempty(iRemove)
        intersect(:,iRemove) = [];
        indx(iRemove) = [];
        t(iRemove) = [];
        u(iRemove) = [];
        v(iRemove) = [];
    end
end
