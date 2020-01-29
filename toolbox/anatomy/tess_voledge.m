function Faces = tess_voledge(Vertices, Elements, Resect)
% TESS_VOLEDGE: Extracts external surface from a volume mesh
%
% USAGE:  Faces = tess_voledge(Vertices, Elements, Resect=[])
% 
% INPUT: 
%    - Elements : [Nelem x 4] integers for tetrahedral meshes
%                 [Nelem x 8] integers for hexahedral meshes (1-based indices in the Vertices matrix)
%    - Resect   : [x y z] Relative coordinates of the resection planes

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

% Parse inputs
if (nargin < 3) || isempty(Resect)
    Resect = [];
end

% Resect
if ~isempty(Resect) && ~isequal(Resect, [0 0 0])
    % Compute elements centers
    ec = reshape(Vertices(Elements(:,1:size(Elements,2))',:)', [size(Vertices,2) size(Elements,2) size(Elements,1)]);
    centers = squeeze(mean(ec,2))';
    % Compute mean and max of the coordinates
    meanVertx = mean(Vertices, 1);
    maxVertx  = max(abs(Vertices), [], 1);
    % Limit values
    resectVal = Resect .* maxVertx + meanVertx;
    % Get elements that are removed in one of the 3 cuts
    iRemove = repmat({false(size(centers(1),1))}, 1, 3);
    for iCoord = 1:3
        if Resect(iCoord) > 0
            iRemove{iCoord} = (centers(:,iCoord) > resectVal(iCoord));
        elseif Resect(iCoord) < 0
            iRemove{iCoord} = (centers(:,iCoord) < resectVal(iCoord));
        end
    end
    % Remove elements that are not selected for display
    Elements(iRemove{1} | iRemove{2} | iRemove{3},:) = [];
end

% List of all triangles
Faces = [...
    Elements(:, [2,1,3]);
    Elements(:, [1,2,4]);
    Elements(:, [3,1,4]);
    Elements(:, [2,3,4])];
% Find external faces (that are not shared between multiple elements)
edgesort = sort(Faces, 2);
[tmp,I,J] = unique(edgesort,'rows');
nShared = histc(J,1:max(I));
iExt = find(nShared == 1);
Faces = Faces(I(iExt),:);

    
    