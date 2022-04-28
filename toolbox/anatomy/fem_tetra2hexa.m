function HexaFile = fem_tetra2hexa(TetraFile)
% FEM_TETRA2HEXA: Converts tetrahedral mesh to hexahedral mesh
%
% USAGE: HexaFile = fem_tetra2hexa(TetraFile)

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
% Authors: Takfarinas Medani, Francois Tadel, 2020

% Load file
bst_progress('start', 'Convert FEM mesh', ['Loading file "' TetraFile '"...']);
TetraFile = file_fullpath(TetraFile);
FemMat = load(TetraFile);   
% Already hexahedral
if (size(FemMat.Elements,2) == 8)
    disp(['BST> Warning: Mesh is already hexahedral: ' TetraFile])
    HexaFile = TetraFile;
    return;
end

% Subdividing the hexahedral element
bst_progress('text', 'Converting to hexahedral...');
[Es,Vs] = tet2hex(double(FemMat.Elements), double(FemMat.Vertices));
hexaLabel = repmat(FemMat.Tissue,1,4); hexaLabel = hexaLabel';
hexaLabel = hexaLabel(:);
% Update output structure
FemMat.Vertices = Vs;
FemMat.Tissue = hexaLabel;
FemMat.Elements = Es;
FemMat.Comment = sprintf('FEM %dV (tetra2hexa, %d layers)', length(FemMat.Vertices), length(FemMat.TissueLabels));
% Add history
FemMat = bst_history('add', FemMat, 'fem_tetra2hexa', 'Converted to hexahedral');

% Output filename
[fPath, fBase, fExt] = bst_fileparts(TetraFile);
HexaFile = file_unique(bst_fullfile(fPath, [fBase, '_hexa', fExt]));
% Get subject
[sSubject, iSubject] = bst_get('SurfaceFile', TetraFile);
% Save new surface in Brainstorm format
bst_progress('text', 'Saving hexa mesh...');    
bst_save(HexaFile, FemMat, 'v7');
db_add_surface(iSubject, HexaFile, FemMat.Comment);

% Close progress bar
bst_progress('stop');

