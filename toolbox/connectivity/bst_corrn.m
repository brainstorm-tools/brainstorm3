function [R, pValues] = bst_corrn(X, Y, RemoveMean)
% BST_CORRN: Calculates the same correlation coefficients as Matlab function corrcoef (+/- rounding errors), but in a vectorized way
%            Equivalent to bst_correlation with nDelay=1 and maxDelay=0 
%
% INPUTS:
%    - X: [Nx,Nt], Nx signals varying in time
%    - Y: [Ny,Nt], Ny signals varying in time
%    - RemoveMean: If 1, removes the average of the signal before calculating the correlation
%                  If 0, computes a scalar product instead of a correlation
%
% NOTE: The rounding errors
%    Corrcoef computes the correlation coefficients based on the variance values computed with cov(),
%    instead of a direct sum of the squared values (sum(Xc.^2,2)).
%    Hence it uses a corrected algorithm for the computation of the variance, that is not sensible to
%    the rounding errors for large number of time samples. We do not divide the values by the number 
%    of samples here, so if the two signals are the same range of dynamics, those rounding errors
%    should not be a problem, even for a very large number of time samples.

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
% Authors: Francois Tadel, 2012-2014

% Parse inputs
if (nargin < 3) || isempty(RemoveMean)
    RemoveMean = 1;
end
% Compute the centered values for X and Y
if RemoveMean
    Xc = bst_bsxfun(@minus, X, mean(X,2));
    Yc = bst_bsxfun(@minus, Y, mean(Y,2));
else
    Xc = X;
    Yc = Y;
end
% Normalize the rows of all the signals 
% (to avoid rounding errors in case of values with radically different values)
Xc = normr(Xc);
Yc = normr(Yc);
% Correlation coefficients
R = Xc * Yc';
% % Set the diagonal to zero
% if isequal(X,Y)
%     R = R - diag(diag(R));
% end

% Use t-test and standard Gaussian
nTimes = size(X,2);
pValues = zeros(size(R));
ip = (abs(R) < 1-eps);
tmp = abs(R(ip)) ./ sqrt(1 - abs(R(ip)).^2) * sqrt(nTimes - 2);
pValues(ip) = 1 - (1/2 * erfc(-1 * tmp / sqrt(2)));     % 1 - normcdf(., 0, 1);

end

function x = normr(x)
    n = sqrt(sum(x.^2,2));
    x(n~=0,:) = bst_bsxfun(@rdivide, x(n~=0,:), n(n~=0));
    x(n==0,:) = 1 ./ sqrt(size(x,2));
end


