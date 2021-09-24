function isInside = bst_intriangle(A, B, C, P)
% BST_INTRIANGLE: Test if the orthogonal projection of points P on a triangle (A,B,C) are inside the triangle.

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
% Authors: Francois Tadel, 2013

% Compute vectors 
v0 = repmat(C - A, size(P,1), 1);
v1 = repmat(B - A, size(P,1), 1);
v2 = bst_bsxfun(@minus, P, A);

% Compute dot products
dot00 = sum(v0.^2, 2);
dot01 = sum(v0.*v1, 2);
dot02 = sum(v0.*v2, 2);
dot11 = sum(v1.^2, 2);
dot12 = sum(v1.*v2, 2);

% Compute barycentric coordinates
invDenom = 1 ./ (dot00 .* dot11 - dot01 .* dot01);
u = (dot11 .* dot02 - dot01 .* dot12) .* invDenom;
v = (dot00 .* dot12 - dot01 .* dot02) .* invDenom;

% Check if point is in triangle
isInside = (u >= 0) & (v >= 0) & (u + v < 1);




