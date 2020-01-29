function MeshMat = in_tess_simnibs(MeshFile)
% IN_TESS_SIMNIBS: Reads a 3D mesh from a gmsh4 file generated with SimNIBS

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
% Authors: Takfarinas Medani, Francois Tadel, 2020

% Read mesh
m = mesh_load_gmsh4(MeshFile);

% Get file name
[fPath, fBase, fExt] = bst_fileparts(MeshFile);

% Convert to bst format
MeshMat = db_template('femmat');
MeshMat.Comment  = fBase;
MeshMat.Vertices = m.nodes(:,1:3);
MeshMat.Elements = m.tetrahedra(:,1:4);
MeshMat.Tissue   = m.tetrahedron_regions;

% Replace the eyes with scalp (not used for now)
MeshMat.Tissue(MeshMat.Tissue==6) = 5;
            
% Swap tetrahedrons orientation
MeshMat.Elements = MeshMat.Elements(:, [2 1 3 4]);

% Default tissue labels
switch length(unique(MeshMat.Tissue))
    case 3
        MeshMat.TissueLabels = {'brain', 'skull', 'scalp'};
    case 4
        MeshMat.TissueLabels = {'brain', 'csf', 'skull', 'scalp'};
    case 5
        MeshMat.TissueLabels = {'white', 'gray', 'csf', 'skull', 'scalp'};
    otherwise
        uniqueLabels = unique(MeshMat.Tissue);
        for i = 1:length(uniqueLabels)
             MeshMat.TissueLabels{i} = num2str(uniqueLabels(i));
        end
end


