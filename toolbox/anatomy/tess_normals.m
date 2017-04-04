function [VertNormals, FaceNormals] = tess_normals(Vertices, Faces, VertConn)
% TESS_NORMALS: Compute vertex and face normals for a tesselation
%
% USAGE:  [VertNormals, FaceNormals] = tess_normals(Vertices, Faces, VertConn)
%         [VertNormals, FaceNormals] = tess_normals(Vertices, Faces)
%
% INPUT:
%    - Vertices : Mx3 double matrix
%    - Faces    : Nx3 double matrix
%    - VertConn : Sparse matrix of vertex connectivity (used for correction of some normals)
% OUTPUT:
%    - VertNormals : Vertex normals returned by Matlab patch() function, with some adjustments
%    - FaceNormals : Face normals

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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

% If no VertConn matrix in input, no correction of points without normals
if (nargin < 3)
    VertConn = [];
end
% Check matrices orientation
if (size(Vertices, 2) ~= 3) || (size(Faces, 2) ~= 3)
    error('Faces and Vertices must have 3 columns (X,Y,Z).');
end

% Compute vertices normals by creating a Matlab patch
hFig = figure('Visible','off');
hPatch = patch('Faces', Faces, 'Vertices', Vertices);
% Matlab 2014b does not compute anymore the vertex normals without a light object
if (bst_get('MatlabVersion') >= 804)
    lighting gouraud;
    light('Position',[1 0 0],'Style','infinite');
    drawnow;
end
% Get patch vertices
VertNormals = double(get(hPatch,'VertexNormals')); 
close(hFig);

% Normalize normal vectors
nrm = sqrt(sum(VertNormals.^2, 2));
% Get points without normal vector
iBad = find((nrm < eps) | isnan(nrm));
% Normalizes the normal vectors
nrm(nrm == 0) = 1;
VertNormals = bst_bsxfun(@rdivide, VertNormals, nrm);

nBadWarning = 0;
% Fix GridOrient: in some case, get(...,'VertexNormals') returns some vectors that are [0 0 0] or NaN
if ~isempty(VertConn) && ~isempty(iBad)
    % For each vertex without a normal
    for i = 1:length(iBad)
        % Get the connected points
        iConnVert = find(VertConn(iBad(i),:));
        % Remove the connected points without normals
        iConnVert = setdiff(iConnVert, iBad);
        % If there are no valid points: skip
        if isempty(iConnVert)
            nBadWarning = nBadWarning + 1;
            continue; 
        end
        % Get all the average of the normals from all those vectors
        newNormal = mean(VertNormals(iConnVert,:),1);
        newNrm = sqrt(sum(newNormal .^2 ));
        % If average norm is not ok, use random normal
        if (newNrm < eps) || isnan(newNrm)
            VertNormals(iBad(i),:) = [1 0 0];
        % Else: Fix normal
        else
            VertNormals(iBad(i),:) = newNormal ./ sqrt(sum(newNrm.^2));
        end
    end
end
% Display warning
if (nBadWarning > 0)
    disp(sprintf('BST> Warning: Normals could not be calculated for %d vertices. Right-click on the surface and select "Clean surface" to remove these vertices.', nBadWarning));
end

% Computation of the face normals (only if requested)
if (nargout >= 2)
    % Sides of each triangle
    u = Vertices(Faces(:,2),:) - Vertices(Faces(:,1),:);
    w = Vertices(Faces(:,1),:) - Vertices(Faces(:,3),:);
    % Compute normals
    FaceNormals = -cross(w,u);
    FaceNormals = FaceNormals ./ repmat(sqrt(sum(FaceNormals.^2,2)),1,3);
    FaceNormals(isnan(FaceNormals)) = 0;
end

