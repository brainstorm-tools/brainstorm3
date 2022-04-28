function grid2mri_interp = grid_interp_mri(GridLoc, MRI, SurfaceFile, isWait, nDownsample, DistanceThresh, GridSmooth)
% GRID_INTERP_MRI: Interpolate a grid of points into a MRI.
%
% USAGE:  grid2mri_interp = grid_interp_mri(GridLoc, MRI, SurfaceFile=[], isWait=1, nDownsample=3, DistanceThresh=2, GridSmooth=1)
%
% INPUT: 
%     - GridLoc        : [Nx3] matrix, 3D positions of the volume grid points
%     - MRI            : Brainstorm MRI structure
%     - SurfaceFile    : Surface to use for the interpolation
%     - isWait         : If 1, show a progress bar
%     - nDownsample    : Volume downsampling factor
%     - DistanceThresh : Maximum distance between a colored voxel and a grid point (in mm)
%     - GridSmooth     : If 1, performs a distance-weighted interpolation with 3 nearest neighbors
%                        If 0, performs a nearest neighbor lookup instead
% OUTPUT:
%     - grid2mri_interp : Sparse matrix [nVoxels, nGridLoc]

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
% Authors: Francois Tadel, 2006 (University of Geneva)
%          Francois Tadel, 2008-2020 (USC/McGill)

% Show progress bar
if (nargin < 7) || isempty(GridSmooth)
    GridSmooth = 1;
end
if (nargin < 6) || isempty(DistanceThresh)
    MriOptions = bst_get('MriOptions');
    DistanceThresh = MriOptions.DistanceThresh;
end
if (nargin < 5) || isempty(nDownsample)
    MriOptions = bst_get('MriOptions');
    nDownsample = MriOptions.InterpDownsample;
end
if (nargin < 4) || isempty(isWait)
    isWait = 1;
end
if (nargin < 3) || isempty(SurfaceFile)
    SurfaceFile = [];
end
if isWait
    isProgress = bst_progress('isVisible');
    bst_progress('start', 'Compute interpolation: MRI/source grid', 'Reading MRI and cortex surface...');
end

% ===== CHECK MRI =====
% Check that MRI SCS is well defined
if ~isfield(MRI,'SCS') || ~isfield(MRI.SCS,'R') || ~isfield(MRI.SCS,'T') || isempty(MRI.SCS.R) || isempty(MRI.SCS.T)
    error(['MRI SCS (Subject Coordinate System) was not defined or subjectimage file is from another version of Brainstorm.' 10 10,...
           'Please define the SCS fiducials on this MRI.']);
end
cubeSize = size(MRI.Cube(:,:,:,1));
% Convert coordinates
GridLoc = cs_convert(MRI, 'scs', 'voxel', GridLoc);


% ===== CHECK VERTICES LOCATION =====
% Get all the vertices that are outside the MRI volume
iOutsideVert = find((GridLoc(:,1) >= cubeSize(1)) | (GridLoc(:,1) < 2) | ...
                    (GridLoc(:,2) >= cubeSize(2)) | (GridLoc(:,2) < 2) | ...
                    (GridLoc(:,3) >= cubeSize(3)) | (GridLoc(:,3) < 2));
% Compute percentage of vertices outside the MRI
percentOutside = length(iOutsideVert) / length(GridLoc);
% If more than 95% vertices are outside the MRI volume : exit with ar error message
if (percentOutside > .95)
    grid2mri_interp = [];
    java_dialog('error', ['Surface is not registered with the MRI.' 10 'Please try to import all your surfaces again.'], 'Surface -> MRI');
    return;
% If more than 40% vertices are outside the MRI volume : display warning message
elseif (percentOutside > .4)
    java_dialog('warning', ['Surface does not seem to be registered with the MRI.', 10 10 ...
                'Please right-click on surface node and execute' 10 ' "Align>Align all surfaces...".'], ...
                'Surface -> MRI');
end

% === BRAIN MASK ===
% Get default surface is not in argument
if isempty(SurfaceFile)
    % Get subject
    sSubject = bst_get('MriFile', MRI.FileName);
    % If there is a inner skull or cortex surface available
    if ~isempty(sSubject.iInnerSkull)
        SurfaceFile = sSubject.Surface(sSubject.iInnerSkull).FileName;
    elseif ~isempty(sSubject.iCortex)
        SurfaceFile = sSubject.Surface(sSubject.iCortex).FileName;
    end
end
% Compute brain mask
if ~isempty(SurfaceFile)
    if isWait
        bst_progress('text', 'Computing brain mask...');
    end
    % Get brain mask
    mrimask = bst_memory('GetSurfaceMask', SurfaceFile);
else
    mrimask = (MRI.Cube(:,:,:,1) ~= 0);
end
% Number of neighbors to consider
if (GridSmooth == 0)
    nNeighbors = 1;
else
    nNeighbors = 3;
end


%% ===== COMPUTE INTERPOLATION =====
% Number of blocks along each dimension
nBlocks = 9;
% Tolerance around each block
distTol = .1;
% Progress bar
if isWait
    bst_progress('start', 'Compute interpolation: MRI/source grid', 'Computing interpolation...', 0, nBlocks+1);
end
% Divide by three in all the directions, to compute only one value every nine
GridLoc = double(GridLoc) ./ nDownsample;
% Get maximum cube size
sizeDiv = round(cubeSize / nDownsample);
% Get the MRI points inside the min/max box
xBounds = [max(floor(min(GridLoc(:,1))),1),   min(ceil(max(GridLoc(:,1))) + 4,    sizeDiv(1))];
yBounds = [max(floor(min(GridLoc(:,2))),1),   min(ceil(max(GridLoc(:,2))) + 4,    sizeDiv(2))];
zBounds = [max(floor(min(GridLoc(:,3))),1),   min(ceil(max(GridLoc(:,3))) + 4,    sizeDiv(3))];
xBlockSize = round((xBounds(2) - xBounds(1) + 1) / nBlocks);
yBlockSize = round((yBounds(2) - yBounds(1) + 1) / nBlocks);
zBlockSize = round((zBounds(2) - zBounds(1) + 1) / nBlocks);

% ===== INTERPOLATION: NEAREST NEIGHBOR =====
if (nNeighbors == 1)
    % Initialize accumulators
    iBrainFull = cell(nBlocks,1);
    iNearest   = cell(nBlocks,1);
    dist       = cell(nBlocks,1);
    % Build grid of coordinates of points
    [X,Y,Z] = meshgrid(xBounds(1):xBounds(2), ...
                       yBounds(1):yBounds(2), ...
                       zBounds(1):zBounds(2));
    % Do not process all the points at once, just to populate the progress bar
    nBlockSize = round(numel(X) / nBlocks);
    for i = 1:nBlocks
        if isWait
            bst_progress('inc', 1);
        end
        % Get the points indices in this block
        iPoints = (((i-1)*nBlockSize)+1 : min(i*nBlockSize, numel(X)))';
        % Get the MRI points inside the brain
        if ~isempty(mrimask)
            isBrain = mrimask(sub2ind(cubeSize, nDownsample*X(iPoints) - 1, nDownsample*Y(iPoints) - 1, nDownsample*Z(iPoints) - 1));
            if (nnz(isBrain) == 0)
                continue;
            end
        else
            % Brain mask is not defined: use all the brain
            isBrain = ones(size(X));
        end
        % Compute interpolation
        [iNearest{i}, dist{i}] = bst_nearest(GridLoc, [X(iPoints(isBrain)), Y(iPoints(isBrain)), Z(iPoints(isBrain))], 1, 0);
        % Get brain points coordinates in full MRI volume
        iBrainFull{i} = sub2ind(cubeSize, X(iPoints(isBrain))*nDownsample - 1, Y(iPoints(isBrain))*nDownsample - 1, Z(iPoints(isBrain))*nDownsample - 1);
    end
    % Concatenate all the accumulators
    dist       = cat(1,dist{:});
    iNearest   = cat(1,iNearest{:});
    iBrainFull = cat(1,iBrainFull{:});
    % Remove all the distances that are two large
    iRemove = find(min(dist,[],2) > DistanceThresh ./ nDownsample);
    iNearest(iRemove,:) = [];
    iBrainFull(iRemove) = [];
    % Interpolation weights: 1 everywhere 
    W = ones(size(iNearest));
    
% ===== INTERPOLATION: SHEPARD =====
else
    % Initialize accumulators
    iBrainFull = cell(nBlocks,nBlocks,nBlocks);
    iNearest   = cell(nBlocks,nBlocks,nBlocks);
    dist       = cell(nBlocks,nBlocks,nBlocks);
    % Loop on X axis
    for i = 1:nBlocks
        if isWait
            bst_progress('inc', 1);
        end
        xBlockBounds = xBounds(1) - 1 + [((i-1)*xBlockSize)+1, min(i*xBlockSize, xBounds(2)-xBounds(1)+1)];
        for j = 1:nBlocks
            yBlockBounds = yBounds(1) - 1 + [((j-1)*yBlockSize)+1, min(j*yBlockSize, yBounds(2)-yBounds(1)+1)];
            for k = 1:nBlocks
                zBlockBounds = zBounds(1) - 1 + [((k-1)*zBlockSize)+1, min(k*zBlockSize, zBounds(2)-zBounds(1)+1)];

                % Build grid of coordinates of points in this block
                [X,Y,Z] = meshgrid(xBlockBounds(1):xBlockBounds(2), ...
                                   yBlockBounds(1):yBlockBounds(2), ...
                                   zBlockBounds(1):zBlockBounds(2));
                % Force index matrices to be column vectors
                X = X(:);
                Y = Y(:);
                Z = Z(:);
                % Get sources in the block
                tol = distTol;
                iBlockVert = [];
                while (nnz(iBlockVert) < nNeighbors)
                    iBlockVert = find((GridLoc(:,1) > (1-tol)*xBlockBounds(1)) & (GridLoc(:,1) < (1+tol)*xBlockBounds(2)) & ...
                                      (GridLoc(:,2) > (1-tol)*yBlockBounds(1)) & (GridLoc(:,2) < (1+tol)*yBlockBounds(2)) & ...
                                      (GridLoc(:,3) > (1-tol)*zBlockBounds(1)) & (GridLoc(:,3) < (1+tol)*zBlockBounds(2)))';
                    tol = tol + .1;
                end
                % Get the MRI points inside the brain
                if ~isempty(mrimask)
                    isBrain = mrimask(sub2ind(cubeSize, nDownsample*X - 1, nDownsample*Y - 1, nDownsample*Z - 1));
                    if (nnz(isBrain) == 0)
                        continue;
                    end
                else
                    % Brain mask is not defined: use all the brain
                    isBrain = ones(size(X));
                end
                % Get brain points coordinates in full MRI volume
                iBrainFull{i,j,k} = sub2ind(cubeSize, X(isBrain)*nDownsample - 1, Y(isBrain)*nDownsample - 1, Z(isBrain)*nDownsample - 1);
                % Look for nearest neighbors
                [iNearest{i,j,k}, dist{i,j,k}] = bst_nearest(GridLoc(iBlockVert,:), [X(isBrain), Y(isBrain), Z(isBrain)], nNeighbors, 0);
                % Convert back in absolute vertices index
                iNearest{i,j,k} = iBlockVert(iNearest{i,j,k});
            end
        end
    end
    if isWait
        bst_progress('inc', 1);
    end
    % Concatenate all the accumulators
    dist       = cat(1,dist{:});
    iNearest   = cat(1,iNearest{:});
    iBrainFull = cat(1,iBrainFull{:});
    % Remove all the distances that are two large
    iRemove = find(min(dist,[],2) > DistanceThresh ./ nDownsample);
    dist(iRemove,:) = [];
    iNearest(iRemove,:) = [];
    iBrainFull(iRemove) = [];
    % Shepard interpolation: Normalize distances
    dist = dist .^ 2;
    W = bst_bsxfun(@rdivide, dist, sum(dist, 2));
end
   

%% ===== RETURN INTERPOLATION MATRIX =====
% List of points to interpolate
grid2mri_interp = sparse(repmat(iBrainFull, nNeighbors, 1), ...
                         iNearest(:), ...
                         W(:), ...
                         prod(cubeSize), length(GridLoc));

% Hide progress bar
if isWait && ~isProgress
    bst_progress('stop');
end




