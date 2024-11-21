function [head_surface] = tess_deface(head_surface)
% TESS_DEFACE: Removing non-essential vertices (bottom half of the subject's face in mesh) to deface the 3D mesh
%
% USAGE:  [head_surface] = tess_deface(head_surface);
%
% INPUT:
%     - head_surface:  Brainstorm tesselation structure with fields:
%         |- Vertices : {[nVertices x 3] double}, in millimeters
%         |- Faces    : {[nFaces x 3] double}
%         |- Color    : {[nColors x 3] double}, normalized between 0-1 (optional)
%
% OUTPUT:
%     - head_surface:  Brainstorm tesselation structure with fields:
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

% Remove the identified vertices from the surface mesh
iRemoveVert = find(R > 1.1);
if ~isempty(iRemoveVert)
    [head_surface.Vertices, head_surface.Faces] = tess_remove_vert(head_surface.Vertices, head_surface.Faces, iRemoveVert);
    if isfield(head_surface, 'Color')
        head_surface.Color(iRemoveVert, :) = [];
    end
end

head_surface.VertConn = tess_vertconn(head_surface.Vertices, head_surface.Faces);
head_surface.VertNormals = tess_normals(head_surface.Vertices, head_surface.Faces, head_surface.VertConn);
head_surface.Curvature = tess_curvature(head_surface.Vertices, head_surface.VertConn, head_surface.VertNormals, .1);
[~, head_surface.VertArea] = tess_area(head_surface.Vertices, head_surface.Faces);
head_surface.SulciMap = tess_sulcimap(head_surface);
head_surface.Comment = [head_surface.Comment '_defaced'];
head_surface = bst_history('add', head_surface, 'deface_mesh', 'mesh defaced');

end