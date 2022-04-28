function SulciMap = tess_sulcimap(sSurf)
% TESS_SULCIMAP: Compute a sulci map based on curvature and connectivity.

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
% Authors: Francois Tadel, 2012

% ===== SMOOTH SURFACE =====
% Smooth surface
SmoothValue = .3;
SmoothIterations = ceil(300 * SmoothValue * length(sSurf.Vertices) / 100000);
sSurf.Vertices = tess_smooth(sSurf.Vertices, SmoothValue, SmoothIterations, sSurf.VertConn, 0);
% Re-calculate normals and curvature on smoothed surface
VertNormals = tess_normals(sSurf.Vertices, sSurf.Faces, sSurf.VertConn);
Curvature   = tess_curvature(sSurf.Vertices, sSurf.VertConn, VertNormals, .1);
% Re-calculate vertices area
[FaceArea, VertArea] = tess_area(sSurf.Vertices, sSurf.Faces);


% ===== BUILD MAP =====
ratioArea = 0;
curvThresh = 0;
% Loop to find the optimal number of vertices used
while (ratioArea < .38)
    % Get points with negative curvature
    iSulci = find(Curvature < curvThresh);
    nVert = length(Curvature);

    % Remove isolated points
    MIN_CLUSTER_SIZE = 3;
    iAlone = find(sum(sSurf.VertConn(iSulci,iSulci),2) < MIN_CLUSTER_SIZE);
    iSulci(iAlone) = [];
    %disp(sprintf('Remove isolated points: removed %d', length(iAlone)));

    % Connect close blocks
    CONN_EXPAND = 2;
    iNonSulci = setdiff(1:length(Curvature), iSulci);
    iConn = iNonSulci(sum(sSurf.VertConn(iNonSulci,iSulci),2) >= CONN_EXPAND);
    % If we added too many points, expand again but in a more restrictive way
    if ((length(iSulci) + length(iConn)) / nVert > .50)
        CONN_EXPAND = 3;
        iNonSulci = setdiff(1:length(Curvature), iSulci);
        iConn = iNonSulci(sum(sSurf.VertConn(iNonSulci,iSulci),2) >= CONN_EXPAND);
    end
    iSulci = union(iSulci, iConn);
    %disp(sprintf('Connect close blocks: added %d', length(iConn)));

    % Fill holes
    for i = 1:4
        %CONN_EXPAND = 4;
        iNonSulci = setdiff(1:nVert, iSulci);
        nConnNonSulci = sum(sSurf.VertConn(iNonSulci,:),2);
        iConn = iNonSulci(sum(sSurf.VertConn(iNonSulci,iSulci),2) >= nConnNonSulci - 1);
        iSulci = union(iSulci, iConn);
        %disp(sprintf('Fill holes: added %d', length(iConn)));
    end

    % Remove isolated points
    MIN_CLUSTER_SIZE = 0;
    iAlone = find(sum(sSurf.VertConn(iSulci,iSulci),2) <= MIN_CLUSTER_SIZE);
    iSulci(iAlone) = [];
    %disp(sprintf('Remove isolated points: removed %d', length(iAlone)));

    % Calculate the area ratio for the sulci map
    ratioArea = sum(VertArea(iSulci)) / sum(VertArea);
    % Increase curvature threshold (take more initial vertices)
    curvThresh = curvThresh + 0.01;
end

% disp(sprintf('\nCurvature threshold: %f', curvThresh - 0.01)); 
% disp(sprintf('Sulci vertices: %d%%', round(100 * length(iSulci) / length(sSurf.Vertices))));
% disp(sprintf('Sulci area: %d%%', round(100 * ratioArea)));

% Create final sulci map
SulciMap = 0 * Curvature;
SulciMap(iSulci) = 1;


