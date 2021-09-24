function sSurfNew = tess_downsize_labels( sSurf, Labels )
% TESS_DOWNSIZE_LABELS: Group vertices using a list of labels.
% 
% INPUT: 
%    - sSurf  : Brainstorm surface structure with at least the fields Vertices, Faces and VertConn
%    - Labels : Array of Nvertices values that form a full parcellation of the input surface

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
% Authors: Francois Tadel, 2014

% New surface template
sSurfNew = db_template('surfacemat');
sSurfNew.Comment = [sSurf.Comment ' | labels'];

% Get unique labels
[uniqueLabels,I,Jlabels] = unique(Labels);
% Create a matrix for grouping vertices in labels
Nv = size(sSurf.Vertices, 1);
Nl = length(uniqueLabels);
rowno = Jlabels;
colno = 1:Nv;
Vert2Labels = sparse(rowno, colno, ones(size(rowno)), Nl, Nv);

% Average the vertices positions
avgVert = bst_bsxfun(@rdivide, Vert2Labels, sum(Vert2Labels,2));
sSurfNew.Vertices = [avgVert * sSurf.Vertices(:,1), ...
                     avgVert * sSurf.Vertices(:,2), ...
                     avgVert * sSurf.Vertices(:,3)];
% Average other fields
sSurfNew.VertNormals = [avgVert * sSurf.VertNormals(:,1), ...
                        avgVert * sSurf.VertNormals(:,2), ...
                        avgVert * sSurf.VertNormals(:,3)];
sSurfNew.Curvature = avgVert * double(sSurf.Curvature);
sSurfNew.SulciMap  = (avgVert * sSurf.SulciMap) > 1;

% Group the faces together
FacesAll = Jlabels(sSurf.Faces);
iRemove = (FacesAll(:,1) == FacesAll(:,2)) | (FacesAll(:,1) == FacesAll(:,3)) | (FacesAll(:,2) == FacesAll(:,3));
FacesAll(iRemove,:) = [];
% Removing duplicate faces
FacesAll = unique(FacesAll, 'rows');
sSurfNew.Faces = FacesAll;

% Re-calculate VertConn
sSurfNew.VertConn = tess_vertconn(sSurfNew.Vertices, sSurfNew.Faces);

