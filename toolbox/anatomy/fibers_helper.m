function varargout = fibers_helper(varargin)
% FIBERS_HELPER: Helper function for fibers objects
% 
% USAGE: 
%    - sFib = fibers_helper('ComputeColor', sFib) :
%        Computes the color of each fiber point based on local curvature
%    - sFib = fibers_helper('AssignToScouts', sFib, ConnectFile, ScoutCentroids) :
%        Assigns each fiber to a pair of scout based on fiber endpoints

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
% Authors: Martin Cousineau, 2019

eval(macro_method);
end


%% ===== COMPUTE COLOR BASED ON CURVATURE =====
function FibMat = ComputeColor(FibMat)
    nFibers = size(FibMat.Points, 1);
    nPoints = size(FibMat.Points, 2);
    FibMat.Colors = zeros(nFibers, nPoints, 3, 'uint8');
    
    % Compute RGB based on current and next point
    for iPt = 1:nPoints - 1
        r = abs(FibMat.Points(:, iPt, 1) - FibMat.Points(:, iPt+1, 1));
        g = abs(FibMat.Points(:, iPt, 2) - FibMat.Points(:, iPt+1, 2));
        b = abs(FibMat.Points(:, iPt, 3) - FibMat.Points(:, iPt+1, 3));

        norm = sqrt(r .* r + g .* g + b .* b);

        FibMat.Colors(:, iPt, 1) = 255.0 .* r ./ norm;
        FibMat.Colors(:, iPt, 2) = 255.0 .* g ./ norm;
        FibMat.Colors(:, iPt, 3) = 255.0 .* b ./ norm;
    end
    
    % Apply same color to last point
    FibMat.Colors(:, nPoints, 1) = FibMat.Colors(:, nPoints-1, 1);
    FibMat.Colors(:, nPoints, 2) = FibMat.Colors(:, nPoints-1, 2);
    FibMat.Colors(:, nPoints, 3) = FibMat.Colors(:, nPoints-1, 3);
end


%% ===== ASSIGN FIBERS TO VERTICES =====
function FibMat = AssignToScouts(FibMat, ConnectFile, ScoutCentroids)
    %TODO: nargin < 3, load ScoutCentroids from ConnectFile

    endPoints = FibMat.Points(:, [1,end], :);
    numPoints = size(FibMat.Points, 1);
    closestPts = zeros(numPoints, 2);
    
    bst_progress('start', 'Fibers Connectivity', 'Assigning fibers to scouts of atlas...');
    
    for iPt = 1:numPoints
        for iPos = 1:2
            % Compute Euclidean distances:
            distances = sqrt(sum(bst_bsxfun(@minus, squeeze(endPoints(iPt, iPos, :))', ScoutCentroids).^2, 2));
            % Assign points to the vertex with the smallest distance
            [minVal, iMin] = min(distances);
            closestPts(iPt, iPos) = iMin;
        end
        bst_progress('inc', 1);
    end
    
    numSurfaces = length(FibMat.Scouts);
    if numSurfaces <= 1 && isempty(FibMat.Scouts(1).ConnectFile)
        numSurfaces = 0;
    end
    
    FibMat.Scouts(numSurfaces + 1).ConnectFile = ConnectFile;
    FibMat.Scouts(numSurfaces + 1).Assignment = closestPts;
    bst_progress('stop');
end








