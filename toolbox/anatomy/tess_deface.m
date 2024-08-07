function [head_surface_deface] = tess_deface(head_surface)
% TESS_DEFACE: Removing non-essential vertices (bottom half of the subject's face in mesh) to deface the 3D mesh
%
% USAGE:  [head_surface_deface] = tess_deface(head_surface);
%
% INPUT:
%     - head_surface:  Brainstorm tesselation structure with fields:
%         |- Vertices : {[nVertices x 3] double}, in millimeters
%         |- Faces    : {[nFaces x 3] double}
%         |- Color    : {[nColors x 3] double}, normalized between 0-1 (optional)
%
% OUTPUT:
%     - head_surface_deface:  Brainstorm tesselation structure with fields:
%         |- Vertices : {[nVertices x 3] double}, in millimeters
%         |- Faces    : {[nFaces x 3] double}
%         |- Color    : {[nColors x 3] double}, normalized between 0-1 (optional)
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
% Authors: Yash Shashank Vakilna, 2024
%          Chinmay Chinara, 2024

% Identify vertices to remove from the surface mesh
% Spherical coordinates
[TH,PHI,R] = cart2sph(head_surface.Vertices(:,1), head_surface.Vertices(:,2), head_surface.Vertices(:,3));
% Flat projection
R = 1 - PHI ./ pi*2;
t = (R > 1.1);

% Remove the identified vertices from the surface mesh
remove = (1:length(t));
remove = remove(t);
if ~isempty(remove)
    [head_surface_deface.Vertices, head_surface_deface.Faces] = tess_remove_vert(head_surface.Vertices, head_surface.Faces, remove);
    if isfield(head_surface, 'Color')
        head_surface.Color(remove, :) = [];
    end
else
    head_surface_deface.Vertices = head_surface.Vertices;
    head_surface_deface.Faces = head_surface.Faces;
end
if isfield(head_surface, 'Color')
    head_surface_deface.Color = head_surface.Color;
end

end