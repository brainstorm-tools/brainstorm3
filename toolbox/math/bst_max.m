function [Fmax, iMax] = bst_max(F, dim)
% BST_MAX: Get the maximum in magnitude, but with the original sign (or complex value).
% 
% USAGE:  [Fmax, iMax] = bst_max(F, dim=1)

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
% Authors: Francois Tadel, 2014

% Parse inputs
if (nargin < 2) || isempty(dim)
    dim = [];
end

% Get the sign of each maximum
if isempty(dim)
    [~, iMax] = max(abs(F(:)));
    % Works for signed real or complex values.
    Fmax = F(iMax);
elseif (dim <= 5)
    % Permute with first dimension
    if (dim > 1)
        permdim = [dim, 2:ndims(F)];
        permdim(dim) = 1;
        F = permute(F, permdim);
    end
    % Reshape to ensure that the matrix has 2 dimensions
    nd = ndims(F);
    if (nd > 2)
        oldSize = [size(F,1), size(F,2), size(F,3), size(F,4), size(F,5)];
        F = reshape(F, size(F,1), []);
    end
    % Get maximum absolute values
    [~, iMax] = max(abs(F), [], 1);
    % Build indices of the values to read
    iF = sub2ind(size(F), iMax, 1:size(F,2));
    Fmax = F(iF);
    % Restore initial shape
    if (nd > 2)
        Fmax = reshape(Fmax, 1, oldSize(2), oldSize(3), oldSize(4), oldSize(5));
        iMax = reshape(iMax, 1, oldSize(2), oldSize(3), oldSize(4), oldSize(5));
    end
    % Restore initial dimensions
    if (dim > 1)
        Fmax = permute(Fmax, permdim);
        iMax = permute(iMax, permdim);
    end
else
    error('Not supported yet.');
end
            

