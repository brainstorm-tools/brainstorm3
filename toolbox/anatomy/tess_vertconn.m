function VertConn = tess_vertconn(Vertices, Faces)
% TESS_VERTCONN: Computes vertices connectivity.
% 
% INPUT:
%     - Vertices   : Mx3 double matrix
%     - Faces      : Nx3 double matrix
% OUTPUT:
%    - VertConn: Connectivity sparse matrix with dimension nVertices x nVertices. 
%                It has 1 at (i,j) when vertices i and j are connected.

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
% Authors: Anand Joshi, Dimitrios Pantazis, November 2007
%          Francois Tadel, 2008-2010

% Check matrices orientation
if (size(Vertices, 2) ~= 3) || (size(Faces, 2) ~= 3)
    error('Faces and Vertices must have 3 columns (X,Y,Z).');
end

% Disable the stupid warnings in old Matlab versions
warning('off', 'MATLAB:conversionToLogical');

% Build connectivity matric
rowno = double([Faces(:,1); Faces(:,1); Faces(:,2); Faces(:,2); Faces(:,3); Faces(:,3)]);
colno = double([Faces(:,2); Faces(:,3); Faces(:,1); Faces(:,3); Faces(:,1); Faces(:,2)]);
data = ones(size(rowno));
n = size(Vertices,1);
VertConn = logical(sparse(rowno, colno, data, n, n));



