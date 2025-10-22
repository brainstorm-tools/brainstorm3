function M = bst_multiply_cellmat(X, fromLeft)
% BST_MULTIPLY_CELLMAT: Multiply all the matrices in cell array
%
% USAGE: M = bst_multiply_cellmat(X, fromLeft=[])
%
% INPUT:
%    - X        : 1D cell array of 2D matrices to be multiplied
%    - fromLeft : If empty (default), guess direction from matrix sizes (left if both directions are valid)
%                 If 1, multiply from left to right
%                 If 0, multiply from right to left
%
% OUTPUT:
%    - M : Result of chain matrix multiplication
%          M = X{1} * X{2} * ... * X{N},   if fromLeft = 1
%          M = X{N} * X{N-1} * ... * X{1}, if fromLeft = 0

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
% Authors: Edouard Delaire, 2025
%          Raymundo Cassani, 2025

% Default direction
if nargin < 2
    fromLeft = [];
end

% Do nothing
if ~iscell(X) || ~isvector(X)
    M = X;
    return
end

nMat = length(X);
% One matrix
if nMat == 1
    M = X{1};
    return
end
% Check sizes
matSizes = cellfun(@size, X, 'UniformOutput', 0);
if ~all(cellfun(@(x) length(x)==2, matSizes))
    error('All matrices in cell array must be 2D')
end

% Guess direction
if isempty(fromLeft)
    % Concatenate sizes
    dimDiffL = diff([matSizes{1 : +1 : nMat}]);
    dimDiffR = diff([matSizes{nMat : -1 : 1}]);
    % Inner dimension diffs
    isOkL = all(dimDiffL(2:2:nMat) == 0);
    isOkR = all(dimDiffR(2:2:nMat) == 0);
    % Choose direction
    if isOkL
        fromLeft = 1;
    elseif isOkR
        fromLeft = 0;
    else
        error('Matrices cannot be multiplied in any direction')
    end
end

% Indices for multiplication
ixs = [1:nMat];
if ~fromLeft
    ixs = fliplr(ixs);
end
% Multiply following ixs order
M = X{ixs(1)};
for im = 2 : nMat
    M = M * X{ixs(im)};
end
M = full(M);
end

