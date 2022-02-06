function [Faces, iFacesRemove] = tess_threshold(Vertices, Faces, threshArea, threshRatio, threshAngle, threshEdge)
% TESS_THRESHOLD: Detect pathological triangles in a surface mesh.
%
% INPUTS:
%    - Vertices    : [Nvert x 3] surface vertices
%    - Faces       : [Nfaces x 3] surface triangles
%    - threshArea  : Detect large triangles (area > thresh * std)
%    - threshRatio : Detect asymetric triangles (ratio perimeter/area > thresh * std)
%    - threshAngle : Detect triangles with angles that are too open (angle in degrees > thresh)

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
% Authors: Francois Tadel, 2012-2016

% ===== PARSE INPUTS =====
if (nargin < 6) || isempty(threshEdge)
    threshEdge = [];
end
if (nargin < 5) || isempty(threshAngle)
    threshAngle = [];
end
if (nargin < 4) || isempty(threshRatio)
    threshRatio = [];
end
if (nargin < 3)
    threshArea = [];
end
iFacesRemoveArea  = [];
iFacesRemoveRatio = [];
iFacesRemoveAngle = [];
iFacesRemoveEdge  = [];

% ===== COMPUTE SURFACE STATISTICS =====
% Triangles area
triArea = tess_area(Vertices, Faces);
% Compute the vector of each edge
v1 = Vertices(Faces(:,1),:) - Vertices(Faces(:,2),:);
v2 = Vertices(Faces(:,1),:) - Vertices(Faces(:,3),:);
v3 = Vertices(Faces(:,2),:) - Vertices(Faces(:,3),:);

% ===== THRESHOLD: AREA =====
% Detect the faces that have an area above the threshold
if ~isempty(threshArea) && (threshArea > 0)
    iFacesRemoveArea = find(triArea - mean(triArea) > threshArea * std(triArea));
end

% ===== THRESHOLD: PERIMETER/AREA =====
if ~isempty(threshRatio) && (threshRatio > 0)
    % Compute perimeter again
    triPerimeter = tess_perimeter(Vertices, Faces);
    % Ratio perimeter / area
    ratio = (triPerimeter ./ triArea);
    % Detect the Faces that have an area above the threshold
    iFacesRemoveRatio = find(ratio - mean(ratio) > threshRatio * std(ratio));
end

% ===== THRESHOLD: ANGLE =====
if ~isempty(threshAngle) && (threshAngle > 0)
    % Compute the angle between all the vectors
    maxAngle = zeros(size(Vertices,1),1);
    for i = 1:size(v1,1)
        maxAngle(i) = max([atan2(norm(cross(v1(i,:),v2(i,:))), dot(v1(i,:),v2(i,:))), ...
                        atan2(norm(cross(v1(i,:),v3(i,:))), dot(v1(i,:),v3(i,:))), ...
                        atan2(norm(cross(v2(i,:),v3(i,:))), dot(v2(i,:),v3(i,:)))]);
    end
    % Convert to degrees
    maxAngle = maxAngle / 2 / pi * 360;
    % Detect the Faces that have an area above the threshold
    iFacesRemoveAngle = find(maxAngle > threshAngle);
end

% ===== THRESHOLD: EDGE LENGTH =====
if ~isempty(threshEdge) && (threshEdge > 0)
    % Compute the length of all the edges
    edgeLength = sqrt(v1.^2 + v2.^2 + v3.^2);
    % Split long edges
    iFacesRemoveEdge = find(edgeLength - mean(edgeLength) > threshEdge * std(edgeLength));
end

% List of faces to remove
iFacesRemove = [iFacesRemoveArea(:); iFacesRemoveRatio(:); iFacesRemoveAngle(:)];
% Keep only the good faces
if ~isempty(iFacesRemove)
     Faces(iFacesRemove,:) = [];
end

   
    



