function [vert, faces] = tess_sphere(nvert, DEBUG)
% TESS_SPHERE: Create an apolar sphere based on the refinment of an icosahedron
%
% USAGE:  [vert, faces] = tess_sphere(nvert);
%
% INPUTS:
%    - nvert : Number of points in the output sphere ()

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
% Authors: Francois Tadel, 2011

% Parse inputs
if (nargin < 2) || isempty(DEBUG)
    DEBUG = 0;
end
if (nargin < 1) || isempty(nvert)
    nvert = 1922;
else
    % Get the closest possible number of points
    values = [12 32 42 92 122 162 273 362 482 642 812 1082 1442 1922 2432 2562 3242 4322 5762 7682 7292 9722 10242 12962 40962];
    nvert = values(bst_closest(nvert, values));
end
% Create icosahedron (fieldtrip function)
[vert, faces] = icosahedron();

% Define refining method
switch(nvert)
    case 12,     n1 = 0;  n2 = 0;
    case 32,     n1 = 1;  n2 = 0;
    case 42,     n1 = 0;  n2 = 1;
    case 92,     n1 = 2;  n2 = 0;
    case 122,    n1 = 1;  n2 = 1;
    case 162,    n1 = 0;  n2 = 2;
    case 273,    n1 = 3;  n2 = 0;
    case 362,    n1 = 2;  n2 = 1;
    case 482,    n1 = 1;  n2 = 2;
    case 642,    n1 = 0;  n2 = 3;
    case 812,    n1 = 4;  n2 = 0;    
    case 1082,   n1 = 3;  n2 = 1;
    case 1442,   n1 = 2;  n2 = 2;
    case 1922,   n1 = 1;  n2 = 3;
    case 2432,   n1 = 5;  n2 = 0;
    case 2562,   n1 = 0;  n2 = 4;
    case 3242,   n1 = 4;  n2 = 1;
    case 4322,   n1 = 3;  n2 = 2;
    case 5762,   n1 = 2;  n2 = 3;
    case 7682,   n1 = 1;  n2 = 4;
    case 10242,  n1 = 0;  n2 = 5;
    case 7292,   n1 = 6;  n2 = 0;
    case 9722,   n1 = 5;  n2 = 1;
    case 12962,  n1 = 4;  n2 = 2;
    case 40962,  n1 = 0;  n2 = 6;
end

% Refine sphere
for i = 1:n2
    % Adds 3 vertices for each face (middle of the edges)
    [vert, faces] = tess_refine(vert, faces);
end
for i = 1:n1
    % Adds 1 vertex for each face (center of the face)
    [vert, faces] = refine_sphere(vert, faces);
end

% Force radius to be one
if (n1 == 0)
    [th,phi,r] = cart2sph(vert(:,1),vert(:,2),vert(:,3));
    [vert(:,1),vert(:,2),vert(:,3)] = sph2cart(th, phi, ones(size(th)));
    % Tesselate final sphere
    faces = convhulln(vert);
end

% Plot surface
if DEBUG
    [hFig, iDS, iFig, hPatch] = view_surface_matrix(vert, faces, .7, [1 0 0]);
    set(hPatch, 'EdgeColor', [1 0 0]);
end
end 


%% ===== REFINE SPHERE =====
function [vert, faces] = refine_sphere(vert, faces)
    % Add the center of each face as a new vertex
    for i = 1:length(faces)
        f = faces(i,:);
        vert = [vert; mean([vert(f',1), vert(f',2), vert(f',3)])];
    end
    % Force radius to be one
    [th,phi,r] = cart2sph(vert(:,1),vert(:,2),vert(:,3));
    [vert(:,1),vert(:,2),vert(:,3)] = sph2cart(th, phi, ones(size(th)));
    % Tesselate final sphere
    faces = convhulln(vert);
end


