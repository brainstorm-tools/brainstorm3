function [Vertices, Faces, iRemoveVert] = tess_remove_small(Vertices, Faces, VertConn, isEdgeConn)
% TESS_REMOVE_SMALL: Remove small components from a surface
%
% USAGE:  [Vertices, Faces, iRemoveVert] = tess_remove_small(Vertices, Faces, VertConn, isEdgeConn)
%         [Vertices, Faces, iRemoveVert] = tess_remove_small(Vertices, Faces)
%
% If isEdgeConn is true, small components that are only connected through a single vertex will also
% be removed, keeping edge connections only.

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
% Authors: Francois Tadel, Marc Lalancette, 2012 - 2026

% Compute vertex connectivity if not specified
if nargin < 4 || isempty(isEdgeConn)
    isEdgeConn = false;
end
if ~isEdgeConn
    if (nargin < 3 || isempty(VertConn))
        VertConn = tess_vertconn(Vertices, Faces);
    end
    % Vertices to classify
    iVertLeft = 1:length(Vertices);
    iRemoveVert = [];
    while ~isempty(iVertLeft)
        % Start scout with the first vertex in the list
        iScout = iVertLeft(1);
        iNewVert = iScout;
        % Grow region until it's not growing anymore
        while ~isempty(iNewVert)
            iScout = union(iScout, iNewVert);
            iNewVert = tess_scout_swell(iScout, VertConn);
        end
        % If there are more than 50% of the vertices: it's the head, remove all the rest
        if (length(iScout) > .5 * length(Vertices))
            iRemoveVert = setdiff(1:length(Vertices), iScout);
            break;
        else
            iVertLeft = setdiff(iVertLeft, iScout);
        end
    end
    % Remove vertices from the surface
    if ~isempty(iRemoveVert)
        [Vertices, Faces] = tess_remove_vert(Vertices, Faces, iRemoveVert);
    end

else
    % Generate matlab triangulation object.
    TR = triangulation(Faces, Vertices);
    % Find connected
    N = neighbors(TR);

    nTri = size(Faces,1);
    i = repmat((1:nTri)', 3, 1);
    j = N(:);

    valid = ~isnan(j);
    G = graph(i(valid), j(valid));

    component = conncomp(G);
    componentSize = accumarray(component(:), 1);

    % Keep only the largest component.
    [~, largest] = max(componentSize);
    keep = component == largest;
    Faces = Faces(keep,:);

    % Keep only the used vertices, and renumber their indices in Faces.
    [usedVertices,~,Faces] = unique(Faces);
    Faces = reshape(Faces, [], 3);
    if nargout > 2
        iRemoveVert = setdiff(1:size(Vertices, 1), usedVertices);
    end
    Vertices = Vertices(usedVertices,:);
end


