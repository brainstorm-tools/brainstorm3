function FemMat = fem_remove_elem(FemMat, iRemoveElem)
% FEM_REMOVE_ELEM: Remove some elements from a 3D mesh

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
% Authors: Francois Tadel, 2020

% Remove elements
FemMat.Elements(iRemoveElem, :) = [];
FemMat.Tissue(iRemoveElem) = [];
if isfield(FemMat, 'Tensors') && ~isempty(FemMat.Tensors)
    FemMat.Tensors(iRemoveElem, :) = [];
end

% Find vertices to remove
nVert = size(FemMat.Vertices, 1);
iVertCut = setdiff(1:nVert, unique(FemMat.Elements(:)));
% Re-numbering matrix
iVertKept = setdiff(1:nVert, iVertCut);
iVertMap = zeros(1, nVert);
iVertMap(iVertKept) = 1:length(iVertKept);
% Remove vertices
FemMat.Vertices(iVertCut,:) = [];
% Renumber vertices in elements list
FemMat.Elements = iVertMap(FemMat.Elements);


