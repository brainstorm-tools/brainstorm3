function triPerimeter = tess_perimeter(Vertices, Faces)
% TESS_PERIMETER: Computes the perimeter of each face of the tesselation

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
% Authors: Francois Tadel, 2009-2011


my_norm = @(v)sqrt(sum(v .^ 2, 2));
% Get coordinates of Vertices for each face
vertFacesX = reshape(Vertices(reshape(Faces,1,[]), 1), size(Faces));
vertFacesY = reshape(Vertices(reshape(Faces,1,[]), 2), size(Faces));
vertFacesZ = reshape(Vertices(reshape(Faces,1,[]), 3), size(Faces));
% For each face : compute triangle perimeter
triSides = [my_norm([vertFacesX(:,1)-vertFacesX(:,2), vertFacesY(:,1)-vertFacesY(:,2), vertFacesZ(:,1)-vertFacesZ(:,2)]), ...
            my_norm([vertFacesX(:,1)-vertFacesX(:,3), vertFacesY(:,1)-vertFacesY(:,3), vertFacesZ(:,1)-vertFacesZ(:,3)]), ...
            my_norm([vertFacesX(:,2)-vertFacesX(:,3), vertFacesY(:,2)-vertFacesY(:,3), vertFacesZ(:,2)-vertFacesZ(:,3)])];
triPerimeter = sum(triSides, 2);


