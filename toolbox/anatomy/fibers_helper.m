function varargout = fibers_helper(varargin)
% FIBERS_HELPER: Helper function for fibers objects
% 
% USAGE: 
%    - sFib = fibers_helper('Concatenate', sFibList) :
%        Concatenates in a single file a list of fibers
%    - sFib = fibers_helper('ComputeColor', sFib) :
%        Computes the color of each fiber point based on local curvature
%    - sFib = fibers_helper('AssignToScouts', sFib, ConnectFile, ScoutCentroids) :
%        Assigns each fiber to a pair of scout based on fiber endpoints
%    - [mat2d, shape3d] = fibers_helper('Conv3Dto2D', mat3d, iDimToKeep) :
%        Converts a 3D shape to a 2D shape in a reversible way
%    - mat3d = fibers_helper('Conv2Dto3D', mat2d, shape3d) :
%        Converts back to 3D a 2D shape converted with Conv3Dto2D()
%    - sFib = fibers_helper('ApplyMriTransfToFib', MriTransf, sFib) :
%        Apply MRI transformation to fiber points
%    - sSurf = fibers_helper('ApplyMriTransfToSurf', MriTransf, sSurf) :
%        Apply MRI transformation to surface vertices
%

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
% Authors: Martin Cousineau, 2019

eval(macro_method);
end

%% ===== CONCATENATE FIBERS FILES =====
function NewFibers = Concatenate(Fibers)
    for iFib = 1:length(Fibers)
        if iFib == 1
            NewFibers = Fibers(iFib);
            continue;
        else
            nFibers = size(Fibers(iFib).Points, 2);
            NewFibers.Points(end+1:end+nFibers, :, :) = Fibers(iFib).Points;
            NewFibers.Colors(end+1:end+nFibers, :, :) = Fibers(iFib).Colors;
        end
    end
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

%% ===== CONVERT 3D MATRICES TO 2D IN A REVERSIBLE WAY =====
function [mat2d, shape3d] = Conv3Dto2D(mat3d, iDimToKeep)
    shape3d = size(mat3d);
    nDims = length(shape3d);
    
    if nargin < 2 || isempty(iDimToKeep)
        iDimToKeep = nDims;
    end
    
    iMergeDims = 1:nDims ~= iDimToKeep;
    mat2d = reshape(mat3d, [prod(shape3d(iMergeDims)), shape3d(iDimToKeep)]);
end


%% ===== CONVERT 2D MATRICES BACK TO 3D =====
function mat3d = Conv2Dto3D(mat2d, shape3d)
    mat3d = reshape(mat2d, shape3d);
end

%% ===== APPLY MRI ORIENTATION =====
function FibMat = ApplyMriTransfToFib(MriTransf, FibMat)
    % Convert points matrix to 2D for transformation.
    [pts, shape3d] = Conv3Dto2D(FibMat.Points);
    % Apply transformation to points
    pts = ApplyMriTransfToPts(MriTransf, pts);
    % Report changes in structure
    FibMat.Points = Conv2Dto3D(pts, shape3d);
end
function sSurf = ApplyMriTransfToSurf(MriTransf, sSurf)
    % Apply transformation to vertices
    pts = ApplyMriTransfToPts(MriTransf, sSurf.Vertices);
    % Report changes in structure
    sSurf.Vertices = pts;
    % Update faces order: If the surfaces were flipped an odd number of times, invert faces orientation
    if (mod(nnz(strcmpi(MriTransf(:,1), 'flipdim')), 2) == 1)
        sSurf.Faces = sSurf.Faces(:,[1 3 2]);
    end
end
function pts = ApplyMriTransfToPts(MriTransf, pts)
    % Apply step by step all the transformations that have been applied to the MRI
    for i = 1:size(MriTransf,1)
        ttype = MriTransf{i,1};
        val   = MriTransf{i,2};
        switch (ttype)
            case 'flipdim'
                % Detect the dimensions that have constantly negative coordinates
                iDimNeg = find(sum(sign(pts) == -1) == size(pts,1));
                if ~isempty(iDimNeg)
                    pts(:,iDimNeg) = -pts(:,iDimNeg);
                end
                % Flip dimension
                pts(:,val(1)) = val(2)/1000 - pts(:,val(1));
                % Restore initial negative values
                if ~isempty(iDimNeg)
                    pts(:,iDimNeg) = -pts(:,iDimNeg);
                end
            case 'permute'
                pts = pts(:,val);
            case 'vox2ras'
                % Do nothing, applied earlier
        end
    end
end
