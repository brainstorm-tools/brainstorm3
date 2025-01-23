function [isOk, Info] = tess_check(Vertices, Faces, isVerbose, isOpenOk, isShow)
% TESS_CHECK: Check the integrity of a tesselation.
%
% USAGE:  [isOk, Details] = tess_check(Vertices, Faces, Verbose)
%
% DESCRIPTION:
%      Check if a surface mesh is simple, closed, non self-intersecting, well oriented, duplicate
%      vertices or faces, etc. There are some custom checks, and if available, use the Matlab Lidar
%      toolbox.  Could add meshcheckrepair from iso2mesh toolbox, and possibly others.
%
% INPUTS:
%    - Vertices : Mx3 double matrix
%    - Faces    : Nx3 double matrix
%    - isOpenOk : An open surface is considered ok, otherwise flag non-closed as an issue.
%    - isVerbose : Write details to command window if any unexpected features.
%    - isShow   : Display surface in new figure
% OUTPUTS:
%    - isOk     : All checks look good
%    - Details  : Structure with all check statuses

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
% Authors: Marc Lalancette, 2025

% Parse inputs
if nargin < 4 || isempty(isOpenOk)
    isOpenOk = false;
end
if nargin < 3 || isempty(isVerbose)
    isVerbose = true;
end
% Check matrices orientation
if (size(Vertices, 2) ~= 3) || (size(Faces, 2) ~= 3)
    error('Faces and Vertices must have 3 columns (X,Y,Z).');
end

isOk = true;
Info = [];

% Some custom checks first based on face edge connectivity.
% First check duplicate faces (based on vertex indices, not coordinates)
[~, FaceConn3] = tess_faceconn(Faces, 3); % 3 vertices in common = duplicate
nAdjFaces = sum(FaceConn3, 2) - 1;
Info.nDuplicate = sum(nAdjFaces > 0) / 2;
% Then check for other issues
[~, FaceConn] = tess_faceconn(Faces, 2);
nAdjFaces = sum(FaceConn, 2) - 1;
Info.nEdgeDisconnectedFaces = sum(nAdjFaces == 0);
Info.nEdgeOverConnectedFaces = sum(nAdjFaces > 3); % 5, 7, 9 found after reducepatch
% If there is an even number of adjacent faces > 3, there's something strange. An odd number could
% be two lobes of the same surface just touching on an edge or face, not necessarily intersecting.
Info.nEvenEdgeOverConnectedFaces = sum(nAdjFaces > 3 & ~mod(nAdjFaces,2));
Info.nBoundaryFaces = sum(nAdjFaces == 1) + sum(nAdjFaces == 2);

if Info.nDuplicate > 0
    isOk = false;
    if isVerbose
        fprintf('BST>Surface has %d duplicate faces.\n', Info.nDuplicate);
    end
end
if Info.nEdgeDisconnectedFaces > 0 % yes many after reducepatch
    isOk = false;
    if isVerbose
        fprintf('BST>Surface has  %d disconnected faces (no shared edges, but possibly one shared vertex).\n', Info.nEdgeDisconnectedFaces);
    end
end
if Info.nEdgeOverConnectedFaces > 0
    isOk = false;
    if isVerbose
        fprintf('BST>Surface intersects or has touching/duplicate edges or faces (%d).\n', Info.nEdgeOverConnectedFaces);
        if Info.nEvenEdgeOverConnectedFaces > 0
            fprintf('BST>Surface has edges shared by 3,5,7,... faces, indicating strange topology (%d).\n', Info.nEvenEdgeOverConnectedFaces);
        end
    end
end
% Note openness if ok so far
if isOk
    if Info.nBoundaryFaces > 0
        Info.isOpen = true;
    else
        Info.isOpen = false;
    end
else % don't bother defining if surface is weird
    Info.isOpen = [];
end
% Check for boundary faces either way if we want closed
if Info.nBoundaryFaces > 0 && ~isOpenOk
    isOk = false;
    if isVerbose
        fprintf('BST>Surface has %d boundary edges.\n', Info.nBoundaryFaces);
    end
end

% Check orientation if ok so far; so we should have each edge shared by 2 faces, or 1 if open.
Info.isOriented = [];
if isOk
    Edges = [Faces(:), [Faces(:, 2); Faces(:, 3); Faces(:, 1)]];
    isEdgeFlip = Edges(:, 1) > Edges(:, 2);
    [~, ~, iE] = unique(sort(Edges, 2), 'rows');
    % Look for boundaries of open surface.
    isBoundE = false(size(Edges, 1), 1);
    [iE, iSort] = sort(iE);
    % Add one more row for the loop to also evaluate the last real edge.
    iE(end+1,:) = 0;
    n = 1;
    for i = 2:numel(iE)
        if iE(i) ~= iE(i-1)
            % Evaluate previous edge
            if n == 1
                % Only one copy, boundary edge.
                isBoundE(iE(i-1)) = true;
            elseif n == 2
                % Two faces, were the orientations different?
                if sum(isEdgeFlip(iSort([i-1,i-2]))) ~= 1 % should be sum([0,1])
                    isOk = false;
                    if isVerbose
                        fprintf('BST>Surface not well oriented (face normals are mixed pointing in and out).\n');
                    end
                    break;
                end
                % Reset for new edge
                n = 1;
            else
                % Previously undetected issue with edge shared among more than 2 faces.
                isOk = false;
                if isVerbose
                    fprintf('BST>Surface has edge shared among more than 2 faces.\n');
                end
                break;
            end
        else
            n = n + 1;
        end
    end
end

if isShow
    hFig = figure_3d('CreateFigure', FigureId);
    figure_3d('PlotSurface', hFig, Faces, Vertices, [1,1,1], 0); % color, transparency required
    figure_3d('ViewAxis', hFig, true); % isVisible
    hFig.Visible = "on";
end


% -------------------------------------------
% Check if Lidar Toolbox is installed (requires image processing + computer vision)
isLidarToolbox = exist('surfaceMesh', 'file') == 2;
if ~isLidarToolbox
    fprintf('BST>tess_downsize method "simplify" requires Matlab''s Lidar Toolbox, which was not found.\n');
    return;
end
% Create mesh object
oMesh = surfaceMesh(Vertices, Faces);

% Check all mesh features Lidar Toolbox offers
Info.isVertexManifold = isVertexManifold(oMesh); % Check if surface mesh is vertex-manifold
Info.isEdgeManifold = isEdgeManifold(oMesh, true); % allow boundary edges
Info.isClosedManifold = isEdgeManifold(oMesh, false); % allow boundary edges
Info.isOrientable = isOrientable(oMesh); % Check if surface mesh is orientable
% Self-intersecting test is slow (not sure how long, didn't wait more than 15 minutes, uses one core only)
%Info.isSelfIntersecting = isSelfIntersecting(oMesh); % Check if surface mesh is self-intersecting
Info.isWatertight = isWatertight(oMesh); % Check if surface mesh is watertight
% removeDefects could be used in tess_clean

if isVerbose
    if (isOpenOk && ~Info.isEdgeManifold) || (~isOpenOk && ~Info.isClosedManifold)
        fprintf('BST>Surface not "edge manifold" (each edge has at most one face on each side)\n.');
    end
    if ~Info.isVertexManifold
        fprintf('BST>Surface not "vertex manifold" (like a "fan" at each vertex)\n.');
    end
    if ~Info.isOrientable
        fprintf('BST>Surface not well oriented (face normals are mixed pointing in and out).\n');
    end
    % if Info.isSelfIntersecting
    %     fprintf('BST>Surface self-intersects.\n');
    % end
end

end



