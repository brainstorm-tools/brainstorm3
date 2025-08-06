function [VertFacesConn, FaceConn] = tess_faceconn(Faces, nVert)
% TESS_FACECONN: Computes faces connectivity.
%
% USAGE:  [VertFacesConn, FaceConn] = tess_faceconn(Faces, nVert=1);
% 
% INPUT:
%     - Faces    : Nx3 double matrix
%     - nVert    : Number of vertices that a pair of faces need to share to be considered connected.
%                  nVert=1 by default, but for finding only edge-adjacent faces, use 2.
% OUTPUT:
%     - VertFacesConn : sparse matrix [nVertices x nFaces]
%     - FacesConn     : sparse matrix [nFaces x nFaces]

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
% Authors: Anand Joshi, Dimitrios Pantazis, November 2007
%          Francois Tadel, 2008-2010
%          Marc Lalancette, 2025

if nargin < 2 || isempty(nVert)
    nVert = 1;
end

% Check matrices orientation
if (size(Faces, 2) ~= 3)
    error('Faces must have 3 columns (X,Y,Z).');
end

% Build VertFacesConn
nFaces = size(Faces,1);
rowno = double([Faces(:,1); Faces(:,2); Faces(:,3)]);
colno = [1:nFaces, 1:nFaces, 1:nFaces]';
data  = ones(3*nFaces, 1);
VertFacesConn = sparse(rowno,colno,data);

% Build FacesConn
if (nargout > 1)
    FaceConn = (VertFacesConn' * VertFacesConn) >= nVert;
end


