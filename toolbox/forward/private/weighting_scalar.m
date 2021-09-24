function sc = weighting_scalar(Loc,Orient,Weight,Vertices,VertNormals)
% WEIGHTING_SCALAR: For use with Overlapping Sphere.
%
% USAGE:  sc = weighting_scalar(Loc,Orient,Weight,Vertices,VertNormals);
%
% INPUT: (Unchecked for speed)
%    - Loc      : 3 x n
%    - Orient   : 3 x n or null
%    - Weight   : length n
%    - Vertices     : N x 3
%    - VertNormals  : N x 3
%
% DESCRIPTION:
% Given a single location and optional orientation, calculate the weighting function
%  to each vertex, using it's corresponding normal.
% Let d = Loc - Vertex, d3 = abs(d)^3, calculate for each vertex in Vertices.
% Let n be the normal pointing vector at each vertex
% If orientation is given, assume MEG case, then replace n with Orient cross n.
% Then
%  sc = n dot d/d3.
% Repeat for each location in Loc, summing by the corresponding scalar in Weight

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
% Authors: John C. Mosher, 1999
%          Francois Tadel, 2010

%MIN_DIST = 10/1000; % minimum acceptable distance. Too close causes trouble
% KND increased the threshold
MIN_DIST = 50/1000; % minimum acceptable distance. Too close causes trouble

n = size(Loc,2); % number of sensors
N = size(Vertices,1); % number of vertices
ZeroN = zeros(1,N); % preallocate
sc = zeros(1,N); % preallocate the answer

% Switch convention for the vertices
VertNormals = VertNormals';
Vertices = Vertices';

% for each sensor location
for iS = 1:n,
    if(~isempty(Orient))
        % user gave an orientation, cross it with all normals
        n = cross(Orient(:,ZeroN+iS),VertNormals);
    else
        % EEG case, just use the normal
        n = VertNormals;
    end
    
    d = Loc(:,ZeroN+iS) - Vertices; % distance vector
    d3 = sqrt(sum(d.^2)).^3; % cubed distance
    ndx = find(d3 >= (MIN_DIST^3));
    temp = sum(n(:,ndx) .* d(:,ndx)) ./ d3(ndx);
    
    sc(ndx) = sc(ndx) + temp * (Weight(iS)/Weight(1)); % always scale relative to first
end

% Return column vector
sc = sc';




