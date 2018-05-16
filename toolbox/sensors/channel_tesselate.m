function Faces = channel_tesselate( Vertices, isPerimThresh )
% CHANNEL_TESSELATE: Tesselate a set of EEG or MEG sensors, for display purpose only.
%
% USAGE:  Faces = channel_tesselate( Vertices, isPerimThresh=1 )
%
% INPUT:  
%    - Vertices      : [Nx3], set of 3D points (MEG or EEG sensors)
%    - isPerimThresh : If 1, remove the Faces that are too big
% OUTPUT:
%    - Faces    : [Mx3], result of the tesselation

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2009-2012

% Parse inputs
if (nargin < 2) || isempty(isPerimThresh)
    isPerimThresh = 1;
end

% === TESSELATE ===
% 2D Projection
[X,Y] = bst_project_2d(Vertices(:,1), Vertices(:,2), Vertices(:,3), '2dcap');
% Compute best fitting sphere
bfs_center = bst_bfs(Vertices)';
% Center Vertices on BFS center
coordC = bst_bsxfun(@minus, Vertices, bfs_center);
% Normalize coordinates
coordC = bst_bsxfun(@rdivide, coordC, sqrt(sum(coordC.^2,2)));
coordC = bst_bsxfun(@rdivide, coordC, sqrt(sum(coordC.^2,2)));
% Tesselation of the sensor array
Faces = convhulln(coordC);


% === REMOVE UNNECESSARY TRIANGLES ===
% For instance: the holes for the ears on high-density EEG caps
if isPerimThresh
    % Get border of the representation
    border = convhull(X,Y);
    % Keep Faces inside the border
    iInside = find(~(ismember(Faces(:,1),border) & ismember(Faces(:,2),border)& ismember(Faces(:,3),border)));
    %Faces   = Faces(iInside, :);

    % Compute perimeter
    triPerimeter = tess_perimeter(Vertices, Faces);
    % Threshold values
    thresholdPerim = mean(triPerimeter(iInside)) + 6 * std(triPerimeter(iInside));
    % Apply threshold
    iFacesOk = intersect(find(triPerimeter <= thresholdPerim), iInside);
    % Find Vertices that are not in the Faces matrix
    iVertNotInFaces = setdiff(1:length(Vertices), unique(Faces(:)));
    if ~isempty(iVertNotInFaces)
        disp(['CHANNEL_TESSELATE> WARNING: Some sensors are not in the Faces list: ' sprintf('%d ', iVertNotInFaces)]);
    end
    % Loop until all the Vertices are visible
    isMissing = 1;
    while isMissing
        % List all the Vertices ignored by the reduced mesh
        iVertOk = unique(reshape(Faces(iFacesOk,:),[],1));
        iVertMissing = setdiff(1:length(Vertices), iVertOk);
        iVertMissing = setdiff(iVertMissing, iVertNotInFaces);
        % If all the Vertices are included, next step
        if isempty(iVertMissing)
            isMissing = 0;
        else
            % Find Faces connected to the first missing vertex
            iFacesAdd = find(any(Faces == iVertMissing(1), 2));
            % From the potential candidate Faces, keep the one that has the smaller perimeter
            [minP, iMinP] = min(triPerimeter(iFacesAdd));
            % Add the smallest face to the list of Faces we keep
            iFacesOk(end+1) = iFacesAdd(iMinP);
        end
    end
    % Remove the Faces
    Faces = Faces(sort(iFacesOk),:);
end


    
    