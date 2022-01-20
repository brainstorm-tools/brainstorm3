function W = tess_smooth_sources(Vertices, Faces, VertConn, FWHM, Method)
% TESS_SMOOTH_SOURCES: Gaussian smoothing matrix over a mesh.
%
% USAGE:  W = tess_smooth_sources(Vertices, Faces, VertConn=[], FWHM=0.010, Method='average')
%
% INPUT:
%    - Vertices : Vertices positions ([X(:) Y(:) Z(:)])
%    - Faces    : Triangles matrix
%    - VertConn : Vertices connectivity, logical sparse matrix [Nvert,Nvert]
%    - FWHM     : Full width at half maximum, in meters (default=0.010)
%    - Method   : {'euclidian', 'path', 'average', 'surface'}
% OUPUT:
%    - W: smoothing matrix (sparse)
%
% DESCRIPTION: 
%    - The distance between two points is an average of:
%        - the direct euclidian between the two points and
%        - the number of edges between the two points * the average length of an edge
%    - Gaussian smoothing function on the euclidian distance:
%      f(r) = 1 / sqrt(2*pi*sigma^2) * exp(-(r.^2/(2*sigma^2)))
%    - Full Width at Half Maximum (FWHM) is related to sigma by:
%      FWHM = 2 * sqrt(2*log2(2)) * sigma

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
% Authors: Francois Tadel, 2010-2013


% ===== PARSE INPUTS =====
if (nargin < 5) || isempty(Method)
    Method = 'average';
end
if (nargin < 4) || isempty(FWHM)
    FWHM = 0.010;
end
if (nargin < 3) || isempty(VertConn)
    VertConn = tess_vertconn(Vertices, Faces);
end
if ~islogical(VertConn)
    error('Invalid vertices connectivity matrix.');
end
nv = size(Vertices,1);


% ===== ANALYZE INPUT =====
% Calculate Gaussian kernel properties
Sigma = FWHM / (2 * sqrt(2*log2(2)));
% FWTM = 2 * sqrt(2*log2(10)) * Sigma;
% Get the average edge length
[vi,vj] = find(VertConn);
meanDist = mean(sqrt((Vertices(vi,1) - Vertices(vj,1)).^2 + (Vertices(vi,2) - Vertices(vj,2)).^2 + (Vertices(vi,3) - Vertices(vj,3)).^2));
% Guess the number of iterations
nIter = min(10, ceil(FWHM / meanDist));

% ===== COMPUTE DISTANCE =====
switch lower(Method)
    % === METHOD 1: USE EUCLIDIAN DISTANCE ===
    case 'euclidian'
        % Get the neighborhood around each vertex
        VertConn = mpower(VertConn, nIter);
        [vi,vj] = find(VertConn);
        % Use Euclidean distance 
        d = sqrt((Vertices(vi,1) - Vertices(vj,1)).^2 + (Vertices(vi,2) - Vertices(vj,2)).^2 + (Vertices(vi,3) - Vertices(vj,3)).^2);
        Dist = sparse(vi, vj, d, nv, nv);

    % === METHOD 2: USE NUMBER OF CONNECTIONS =====
    % === METHOD 3: AVERAGE METHOD 1+2 ===
    case {'path', 'average'}
        % Initialize loop variables
        VertConnGrow = speye(nv);
        VertIter = sparse(nv,nv);
        vall = [];

        % Grow and keep track of the layers
        for iter = 1:nIter
            disp(sprintf('SMOOTH> Iteration %d/%d', iter, nIter));
            % Grow selection of vertices
            VertConnPrev = VertConnGrow;
            VertConnGrow = double(VertConnGrow * VertConn > 0);
            % Find all the new connections
            vind = find(VertConnGrow - VertConnPrev > 0);
            [vi,vj] = ind2sub([nv,nv], vind);
            VertIter = VertIter + iter * sparse(vi, vj, ones(size(vi)), nv, nv);
        end

        % Use distance in number of connections
        Dist = VertIter * meanDist;
        Dist(1:nv+1:nv*nv) = 0;
        
        % == AVERAGE WITH METHOD 1 ==
        if strcmpi(Method, 'average')
            % Calculate Euclidean distance 
            [vi,vj] = find(VertConnGrow);
            d = sqrt((Vertices(vi,1) - Vertices(vj,1)).^2 + (Vertices(vi,2) - Vertices(vj,2)).^2 + (Vertices(vi,3) - Vertices(vj,3)).^2);
            % Average with results of method #2
            Dist = (0.5 .* Dist + 0.5 .* sparse(vi, vj, d, nv, nv));
        end
        
    % ===== METHOD 4: CALCULATE SURFACE DISTANCE =====
    % WARNING: NOT FINISHED!!!!
    case 'surface'
        % Initialize loop variables
        VertConnGrow = speye(nv);
        Dist = sparse([], [], [], nv, nv, 3*nnz(VertConn));
        vall = [];
        nIter = 2;
        % Grow until we reach an accepteable distance
        for iter = 1:nIter
            disp(sprintf('Iteration %d', iter));
            % Get neighbors
            VertConnGrow = VertConnGrow * VertConn;
            % Get all the existing edges in the surface
            vind = find(VertConnGrow);
            % Remove all the previously processed connections
            vind = setdiff(vind, vall);
            [vi,vj] = ind2sub([nv,nv], vind);
            % Remove diagonal
            iDel = (vi == vj);
            vi(iDel) = [];
            vj(iDel) = [];
            % Calculate the distance to the neighbor nodes
            if (iter == 1)
                % Calculate all the distances for all the pairs of edges
                d = sqrt((Vertices(vi,1) - Vertices(vj,1)).^2 + (Vertices(vi,2) - Vertices(vj,2)).^2 + (Vertices(vi,3) - Vertices(vj,3)).^2);
            else
                % Initialize d matrix
                d = zeros(size(vi));
                % Process each new connection separately
                for i = 1:length(vi)
                    % Find nodes that are connected to both nodes
                    iMid = find((Dist(vi(i),:) & VertConn(vj(i),:)) | (VertConn(vi(i),:) & Dist(vj(i),:)));
                    % Find nodes for which we know one connection at least
                    iMid0 = (Dist(vi(i),iMid) & Dist(vj(i),iMid));
                    iMid1 = (Dist(vi(i),iMid) & ~iMid0);
                    iMid2 = (Dist(vj(i),iMid) & ~iMid0);
                    % Compute distances
                    dMid = 0*iMid;
                    dMid(iMid0) = Dist(vi(i),iMid0) + Dist(vj(i),iMid0);
                    dMid(iMid1) = Dist(vi(i),iMid1) + sqrt((Vertices(vj(i),1) - Vertices(iMid1,1)).^2 + (Vertices(vj(i),2) - Vertices(iMid1,2)).^2 + (Vertices(vj(i),3) - Vertices(iMid1,3)).^2)';
                    dMid(iMid2) = Dist(vj(i),iMid2) + sqrt((Vertices(vi(i),1) - Vertices(iMid2,1)).^2 + (Vertices(vi(i),2) - Vertices(iMid2,2)).^2 + (Vertices(vi(i),3) - Vertices(iMid2,3)).^2)';
                    dMid(dMid == 0) = Inf;
                    % Find the shortest path
                    d(i) = min(dMid);
                    if isinf(d(i))
                        error('???');
                    end
                end
            end
            % Add to processed vertices
            vall = union(vind, vall);
            % Create a sparse distance matrix
            Dist = Dist + sparse(vi, vj, d, nv, nv);
        end
end


% ===== APPLY GAUSSIAN FUNCTION =====
% Gaussian function
fun = inline('1 / sqrt(2*pi*sigma2) * exp(-(x.^2/(2*sigma2)))', 'x', 'sigma2');
% Calculate interpolation as a function of distance
[vi,vj] = find(Dist>0);
vind = sub2ind([nv,nv], vi, vj);
w = fun(Dist(vind), Sigma^2);
% Build final symmetric matrix
%W = sparse([vi;vj], [vj;vi], [w;w], nv, nv);
W = sparse(vi, vj, w, nv, nv);
% Add the diagonal
W = W + fun(0,Sigma^2) * speye(nv);
% Normalize columns
W = bst_bsxfun(@rdivide, W, sum(W,1));
% Remove insignificant values
[vi,vj] = find(W>0.005);
vind = sub2ind([nv,nv], vi, vj);
W = sparse(vi, vj, W(vind), nv, nv);


% ===== FIX BAD TRIANGLES =====
% Only for methods including neighbor distance
if ismember(lower(Method), {'path', 'average'})
    % Configurations to detect: 
    %    - One face divided in 3 with a point in the middle of the face
    %    - Square divided into 4 triangles with one point in the middle
    % Calculate face-vertex connectivity
    VertFacesConn = tess_faceconn(Faces);
    % Find vertices connected to three or four faces
    sumVert  = sum(VertConn,2);
    sumFaces = sum(VertFacesConn,2);
    % Three/Four vertices: average the values of their neighbors
    iVert = find(((sumVert == 3) & (sumFaces == 3)) | ((sumVert == 4) & (sumFaces == 4)));
    AvgConn = bst_bsxfun(@rdivide, W * VertConn(:,iVert), sumVert(iVert)');
    W(iVert,:) = AvgConn';
    W(:,iVert) = AvgConn;
end



