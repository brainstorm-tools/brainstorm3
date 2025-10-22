function M = bst_multiply_cellmat(X)
% BST_MULTIPLY_CELLMAT: Multiply all the matrices in cell array
%
% USAGE: M = bst_multiply_cellmat(X)
%
% INPUT:
%    - X        : 1D cell array of 2D matrices to be multiplied
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

dimDiffL = diff([matSizes{1 : +1 : nMat}]);
isOkL = all(dimDiffL(2:2:nMat) == 0);
if ~isOkL
    error('Matrices cannot be multiplied')
end


% Guess direction of multiplication
fromRight = size(X{end}, 2) < size(X{1}, 1);

% Keep useful indices for inner dimensions
if fromRight
    for im = nMat : -1 : 2
        usefulInnerIx       = any(X{im}, 2);
        X{im}   = X{im}(usefulInnerIx, :);
        X{im-1} = X{im-1}(:, usefulInnerIx);
    end
else
    for im = 1 : nMat - 1
        usefulInnerIx       = any(X{im}, 1);
        X{im}   = X{im}(:, usefulInnerIx);
        X{im+1} = X{im+1}(usefulInnerIx, :);
    end

end

% Multiply matrices 
if fromRight
    M = X{end};
    for iDecomposition = (nMat - 1) : -1 : 1
        M = X{iDecomposition} * M;
    end
else
    M = X{1};
    for iDecomposition = 2 : nMat
        M = M * X{iDecomposition};
    end
end

% Ensure results are full matrices
M = full(M);
end

