function [Vertices_sm, A] = tess_smooth(Vertices, a, nIterations, VertConn, isKeepSize, Faces)
% TESS_SMOOTH: Smooths a surface.
% 
% USAGE:  [Vertices_sm, A] = tess_smooth(Vertices, a, nIterations, VertConn, isKeepSize)
%         [Vertices_sm, A] = tess_smooth(Vertices, a, nIterations, VertConn)
%  
% INPUT:
%    - Vertices    : [N,3] vertices of matrix to smooth
%    - a           : scalar smooth weighting parameter (0-1 less-more smoothing)
%    - nIterations : number of times to apply the smoothing
%    - VertConn    : Vertex connectivity sparse matrix
%    - isKeepSize  : If 1, the final surface is scaled so that the convex envelope
%                    has the same bounding box as the initial surface
% OUTPUT:
%    - Vertices_sm : vertices list of smoothed surface
%    - A           : smoothing matrix

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
% Authors: Francois Tadel, 2012-2013

% Parse inputs
if (nargin < 5) || isempty(isKeepSize)
    isKeepSize = 1;
end
% Check matrices orientation
if (size(Vertices, 2) ~= 3)
    error('Vertices must have 3 columns (X,Y,Z).');
end

% Get initial bounding box
if isKeepSize
    initBounds = [min(Vertices); max(Vertices)];
end
% Calculate smoothing matrix
A = spones(VertConn); 
sumA = sum(A); 
sumA(sumA==0) = eps;
A = spdiags((a./sumA)', 0, size(A,1), size(A,2)) * A;
A = A + spdiags((1-a) * ones(size(A,1), 1), 0, size(A,1), size(A,2));

% Smooth vertices matrix
Vertices_sm = double(Vertices);
for i = 1:nIterations
    Vertices_sm = A * Vertices_sm;
end

% Scale final surface
if isKeepSize
    % Compute scale
    finalBounds = [min(Vertices_sm); max(Vertices_sm)];
    initBounds = initBounds - repmat(mean(Vertices),2,1);
    scale = diff(initBounds,[],1) ./ diff(finalBounds,[],1);
    % Center and apply scale
    center = mean(Vertices_sm);
    Vertices_sm = bst_bsxfun(@minus, Vertices_sm, center);
    Vertices_sm = bst_bsxfun(@times, Vertices_sm, scale);
    Vertices_sm = bst_bsxfun(@plus,  Vertices_sm, center);
    
%     % Compute normals
%     VertNormals = tess_normals(Vertices_sm, Faces, VertConn);
%     Vertices_sm = Vertices_sm + 0.00001 * nIterations * VertNormals;
end


