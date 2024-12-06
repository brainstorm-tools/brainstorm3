function TessMat = in_tess_besa(srfFile)
% IN_TESS_BESA: Reads a surface SRF file from BESA Research/MRI

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
% Authors: Raymundo Cassani, 2024

% Read using readBESAsrf() located at BESA-MATLAB-Scripts/BESA2MATLAB
% https://github.com/BESA-GmbH/BESA-MATLAB-Scripts
srf = readBESAsrf(srfFile);

% Remove center offset from mesh (center ofset at anterior commissure)
srf.CoordsVertices = bsxfun(@minus, srf.CoordsVertices, srf.MeshCenterCoord');
% From BrainVoyage (RIP) to Brainstorm (ALS): Permute [3,1,2], Reverse All Axes
vertices = -srf.CoordsVertices(:, [3,1,2]);
% Add back center offset to mesh
vertices = bsxfun(@plus, vertices, srf.MeshCenterCoord');
% Indices for vertices in faces start at 0
faces = srf.Triangles+1;
% Base filename
[~, base] = bst_fileparts(srfFile);
TessMat = struct('Faces',    faces,    ...
                 'Vertices', vertices, ...
                 'Comment',  base);
