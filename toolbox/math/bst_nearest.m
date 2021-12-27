function [I, dist, dt] = bst_nearest(refVert, testVert, K, isProgress, dt)
% BST_NEAREST: K-Nearest neighbor search
%
% USAGE:  I = bst_nearest(refVert, testVert, K=1, isProgress=1, dt=[])
%
% INPUT: 
%    - refVert    : [Nx3] list of reference 3D points 
%    - testVert   : [Mx3] list of 3D points for which we want the nearest vertex in refVert
%    - K          : Number of nearest neighbors we want, default=1
%                   -1, force the use of the full algorithm for K=1
%    - isProgress : If 1, show a progress bar
%    - dt         : Delaunay triangulation returned by previous call
% OUTPUT:
%    - I : [MxK] search matrix
%    - d : [MxK] distance matrix

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
% Authors: Francois Tadel, 2013

% Parse inputs
if (nargin < 5) || isempty(dt)
    dt = [];
end
if (nargin < 4) || isempty(isProgress)
    isProgress = 1;
end
if (nargin < 3) || isempty(K)
    K = 1;
end
% Do we want the distance?
isDist = (nargout >= 2);
% Do we use the parallel processing toolbox
% isParallel = (exist('matlabpool', 'file') ~= 0);
isParallel = 0;
% Open progress bar
if isProgress
    isPreviousBar = bst_progress('isVisible');
    if isPreviousBar
        initPos = bst_progress('get');
        bst_progress('text', 'Nearest neighbor search...');
    else
        bst_progress('start', 'Nearest neighbor', 'Nearest neighbor search...');
    end
end
% Force full algorithm
if (K == -1)
    isForceFull = 1;
    K = 1;
else
    isForceFull = 0;
end

% ===== K>1 =====
if (K > 1) || isForceFull
    % Intialize matrices
    nTest = size(testVert,1);
    I = zeros(nTest, K);
    dist = I;
    % ===== METHOD 1: FULL LOOP =====
    % Faster for up to 50000 vertices
    if ~isParallel || (nTest < 60000)
        if isProgress
            bst_progress('start', 'Nearest neighbor', 'Nearest neighbor search...', 1, 100);
        end
        pos = 1;
        % Full for loop on the vertices for which we want the nearest neighbor in the reference list
        for i = 1:nTest
            % Progress bar
            if isProgress && (i/nTest*100 > pos)
                pos = ceil(i/nTest*100);
                bst_progress('set', pos);
            end
            % Distance in 2D
            if size(refVert,2)==2 && size(testVert,2)==2
                d = (refVert(:,1)-testVert(i,1)) .^ 2 + (refVert(:,2)-testVert(i,2)) .^ 2; 
            % Distance in 3D
            else
                d = (refVert(:,1)-testVert(i,1)) .^ 2 + (refVert(:,2)-testVert(i,2)) .^ 2 + (refVert(:,3)-testVert(i,3)) .^ 2;
            end
            [s,t] = sort(d);
            I(i,:) = t(1:K);
            dist(i,:) = s(1:K);
        end
        if isProgress && isPreviousBar
            bst_progress('set', initPos);
        end
    % ===== METHOD 2: FULL PARFOR LOOP =====
    % Faster for more than 30000 vertices
    else
        % Start parallel pool
        if (bst_get('MatlabVersion') >= 802)
            hPool = parpool;
        else
            matlabpool open;
        end
        % Parallel loop
        parfor i = 1:nTest
            % Distance in 2D
            if size(refVert,2)==2 && size(testVert,2)==2
                d = (refVert(:,1)-testVert(i,1)) .^ 2 + (refVert(:,2)-testVert(i,2)) .^ 2;
            % Distance in 3D
            else
                d = (refVert(:,1)-testVert(i,1)) .^ 2 + (refVert(:,2)-testVert(i,2)) .^ 2 + (refVert(:,3)-testVert(i,3)) .^ 2;
            end

            [s,t] = sort(d);
            I(i,:) = t(1:K);
            dist(i,:) = s(1:K);
        end
        % Close pool
        if (bst_get('MatlabVersion') >= 802)
            delete(hPool);
        else
            matlabpool close;
        end
    end
    
%     % ===== METHOD 3: BY BLOCKS =====
%     % Slower in all cases
%     blockSize = 100;
%     nBlocks = ceil(nTest / blockSize);
%     for iBlock = 1:nBlocks
%         iVert = ((iBlock-1)*blockSize+1) : min(iBlock*blockSize, nTest);
%         d = bst_bsxfun(@minus, testVert(iVert,1), ones(length(iVert),1) * refVert(:,1)') .^ 2 + ...
%             bst_bsxfun(@minus, testVert(iVert,2), ones(length(iVert),1) * refVert(:,2)') .^ 2 + ...
%             bst_bsxfun(@minus, testVert(iVert,3), ones(length(iVert),1) * refVert(:,3)') .^ 2;
%         [s,t] = sort(d,2);
%         I(iVert,:) = t(:,1:K);
%         dist(iVert,:) = s(:,1:K);
%     end
    
    % The loop calculates the square of the distance: fix
    if isDist
        dist = sqrt(dist);
    end
    dt = [];
    
% ===== K=1 =====
else
    % Get the nearest neighbors
    if exist('delaunayTriangulation', 'file')
        if isempty(dt)
            dt = delaunayTriangulation(refVert);
            % Cannot compute triangulation: run the full algo
            if isempty(dt.ConnectivityList)
                [I, dist, dt] = bst_nearest(refVert, testVert, -1, isProgress);
                return;
            end
        end
        if isDist
            [I,dist] = dt.nearestNeighbor(testVert);
        else
            I = dt.nearestNeighbor(testVert);
        end
    elseif exist('DelaunayTri', 'file')
        if isempty(dt)
            dt = DelaunayTri(refVert);
        end
        if ismethod(dt, 'nearestNeighbor')
            if isDist
                try
                    [I,dist] = dt.nearestNeighbor(testVert);
                catch
                    I = dt.nearestNeighbor(testVert);
                    dist = sqrt(sum((testVert - refVert(I,:)).^2,2));
                end
            else
                I = dt.nearestNeighbor(testVert);
            end
        else
            if isDist
                [I,dist] = dsearchn(refVert, dt.Triangulation, testVert);
            else
                I = dsearchn(refVert, dt.Triangulation, testVert);
            end
        end
    % For older versions of Matlab that do not have DelaunayTri
    else
        if isempty(dt)
            dt = delaunayn(refVert);
        end
        if isDist
            [I,dist] = dsearchn(refVert, dt, testVert);
        else
            I = dsearchn(refVert, dt, testVert);
        end
    end
end

% Close progress bar
if isProgress && ~isPreviousBar
    bst_progress('stop');
end
