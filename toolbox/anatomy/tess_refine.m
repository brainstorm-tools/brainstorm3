function [Vertices, Faces] = tess_refine(Vertices, Faces, threshArea, threshEdge, isThresh )
% TESS_REFINE: Refine a surface mesh.
% 
% USAGE:  [Vertices, Faces] = tess_refine(Vertices, Faces, threshArea=[], threshEdge=[], isThresh=0);
%
% INPUT:
%     - Vertices   : Mx3 double matrix
%     - Faces      : Nx3 double matrix
%     - threshArea : Only split the faces that have an area above a certain threshold (edge > thresh * std)
%     - threshEdge : Only split the edges that have a length above the threshold (edge > thresh * std)
%     - isThresh   : If 1, call channel_tesselate with a isThresh = 1 (remove big triangles)
%
% DESCRIPTION: Each triangle is subdivided in 4 triangles.
%     
%             /\1           
%            /  \           
%           /    \          
%          /      \        
%        4/--------\5       
%        /  \    /  \      
%       /    \6 /    \     
%     2'--------------'3   

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
% Authors: François Tadel, 2009-2016

% Parse inputs
if (nargin < 5) || isempty(isThresh)
    isThresh = 0;
end
if (nargin < 4) || isempty(threshEdge)
    threshEdge = [];
end
if (nargin < 3) || isempty(threshArea)
    threshArea = [];
end
% Check matrices orientation
if (size(Vertices, 2) ~= 3) || (size(Faces, 2) ~= 3)
    error('Faces and Vertices must have 3 columns (X,Y,Z).');
end

% ===== SPLIT EDGES =====
% Get all the edges of the surface
i1 = [Faces(:,1); Faces(:,1); Faces(:,2)];
i2 = [Faces(:,2); Faces(:,3); Faces(:,3)];
% List of edges to split in half
iSplit = [];
% Split long edges
if ~isempty(threshEdge) && (threshEdge > 0)
    % Compute the length of all the edges
    edgeLength = sqrt((Vertices(i1,1)-Vertices(i2,1)).^2 + (Vertices(i1,2)-Vertices(i2,2)).^2 + (Vertices(i1,3)-Vertices(i2,3)).^2);
    % Split long edges
    iSplit = [iSplit; find(edgeLength - mean(edgeLength) > threshEdge * std(edgeLength))];
end
% Split large faces
if ~isempty(threshArea) && (threshArea > 0)
    % Detect the faces that have an area above the threshold
    [tmp, iFacesSplit] = tess_threshold(Vertices, Faces, threshArea);
    % Split all the edges of the large surfaces
    iSplit = [iFacesSplit(:); iFacesSplit(:) + size(Faces,1); iFacesSplit(:) + 2*size(Faces,1)];
end
% Split all faces (if there are no other constraints)
if isempty(threshArea) && isempty(threshEdge)
    iSplit = (1:length(i1))';
end
% Nothing to split: return
if isempty(iSplit)
    return;
end

% ===== REFINE MESH =====
% New vertices
newVertices = unique((Vertices(i1(iSplit),:) + Vertices(i2(iSplit),:)) ./ 2, 'rows');
% Add to the existing vertices
Vertices = [Vertices; newVertices];

% ===== TESSELATE NEW SURFACE =====
% If 3D surface, use channel_tesselate.m
if ~all(Vertices(:,3) == Vertices(1,3))
    Faces = channel_tesselate(Vertices, isThresh);
% Else: flat surface, use delaunay.m
else
    Faces = delaunay(Vertices(:,1), Vertices(:,2));
end





