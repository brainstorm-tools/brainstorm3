function [VertFacesConn, FaceConn] = tess_faceconn(Faces)
% TESS_FACECONN: Computes faces connectivity.
%
% USAGE:  [VertFacesConn, FaceConn] = tess_faceconn(Faces);
% 
% INPUT:
%     - Faces    : Nx3 double matrix
% OUTPUT:
%     - FacesConn : sparse matrix [nVertices x nFaces]

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
    FaceConn = (VertFacesConn' * VertFacesConn) > 0;
end


