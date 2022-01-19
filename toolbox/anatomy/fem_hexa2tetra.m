function TetraFile = fem_hexa2tetra(HexaFile)
% FEM_HEXA2TETRA: Converts hexahedral mesh to tetrahedral mesh
%
% USAGE: TetraFile = fem_hexa2tetra(HexaFile)

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
bst_progress('start', 'Convert FEM mesh', ['Loading file "' HexaFile '"...']);
HexaFile = file_fullpath(HexaFile);
FemMat = load(HexaFile);   
% Already tetrahedral
if (size(FemMat.Elements,2) == 4)
    disp(['BST> Warning: Mesh is already tetrahedral: ' HexaFile])
    TetraFile = HexaFile;
    return;
end

% Convert to tetrahedral
bst_progress('text', 'Converting to tetrahedral...');
[tetraElem, tetraNode, tetraLabel] = hex2tet(FemMat.Elements, FemMat.Vertices, FemMat.Tissue, 4);
% Update output structure
FemMat.Vertices = tetraNode;
FemMat.Elements = tetraElem(:, [2 1 3 4]);
FemMat.Tissue = tetraLabel;
FemMat.Comment = sprintf('FEM %dV (hexa2tetra, %d layers)', length(FemMat.Vertices), length(FemMat.TissueLabels));
% Add history
FemMat = bst_history('add', FemMat, 'fem_hexa2tetra', 'Converted to tetrahedral');

% Output filename
[fPath, fBase, fExt] = bst_fileparts(HexaFile);
TetraFile = file_unique(bst_fullfile(fPath, [fBase, '_hexa', fExt]));
% Get subject
[sSubject, iSubject] = bst_get('SurfaceFile', HexaFile);
% Save new surface in Brainstorm format
bst_progress('text', 'Saving tetra mesh...');    
bst_save(TetraFile, FemMat, 'v7');
db_add_surface(iSubject, TetraFile, FemMat.Comment);

% Close progress bar
bst_progress('stop');


