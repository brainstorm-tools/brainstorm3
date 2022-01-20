%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Copyright (C) 1995-2020 The Octave Project Developers
%
% See the file COPYRIGHT.md in the top-level directory of this
% distribution or <https://octave.org/copyright/>.
%
% This file is part of Octave.
%
% Octave is free software: you can redistribute it and/or modify it
% under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% Octave is distributed in the hope that it will be useful, but
% WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with Octave; see the file COPYING.  If not, see
% <https://www.gnu.org/licenses/>.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% -*- texinfo -*-
% @deftypefn  {} {} cov (@var{x})
% @deftypefnx {} {} cov (@var{x}, @var{opt})
% @deftypefnx {} {} cov (@var{x}, @var{y})
% @deftypefnx {} {} cov (@var{x}, @var{y}, @var{opt})
% Compute the covariance matrix.
%
% If each row of @var{x} and @var{y} is an observation, and each column is
% a variable, then the @w{(@var{i}, @var{j})-th} entry of
% @code{cov (@var{x}, @var{y})} is the covariance between the @var{i}-th
% variable in @var{x} and the @var{j}-th variable in @var{y}.
% @tex
% $$
% \sigma_{ij} = {1 \over N-1} \sum_{i=1}^N (x_i - \bar{x})(y_i - \bar{y})
% $$
% where $\bar{x}$ and $\bar{y}$ are the mean values of @var{x} and @var{y}.
% @end tex
% @ifnottex
%
% @example
% cov (@var{x}) = 1/(N-1) * SUM_i (@var{x}(i) - mean(@var{x})) * (@var{y}(i) - mean(@var{y}))
% @end example
%
% @noindent
% where @math{N} is the length of the @var{x} and @var{y} vectors.
%
% @end ifnottex
%
% If called with one argument, compute @code{cov (@var{x}, @var{x})}, the
% covariance between the columns of @var{x}.
%
% The argument @var{opt} determines the type of normalization to use.
% Valid values are
%
% @table @asis
% @item 0:
%   normalize with @math{N-1}, provides the best unbiased estimator of the
% covariance [default]
%
% @item 1:
%   normalize with @math{N}, this provides the second moment around the mean
% @end table
%
% Compatibility Note:: Octave always treats rows of @var{x} and @var{y}
% as multivariate random variables.
% For two inputs, however, @sc{matlab} treats @var{x} and @var{y} as two
% univariate distributions regardless of their shapes, and will calculate
% @code{cov ([@var{x}(:), @var{y}(:)])} whenever the number of elements in
% @var{x} and @var{y} are equal.  This will result in a 2x2 matrix.
% Code relying on @sc{matlab}'s definition will need to be changed when
% running in Octave.
% @seealso{corr}
% @end deftypefn

function c = cov (x, y, opt)

if (nargin < 2)
    y = [];
end
if (nargin < 3)
    opt = 0;
end
if (nargin < 1 || nargin > 3)
    error('Usage: c = cov (x, y = [], opt = 0)');
end

if (~(isnumeric (x) || islogical (x)) || ~(isnumeric (y) || islogical (y)))
    error ('cov: X and Y must be numeric matrices or vectors');
end

if (ndims (x) ~= 2 || ndims (y) ~= 2)
    error ('cov: X and Y must be 2-D matrices or vectors');
end

if (nargin == 2 && isscalar (y))
    opt = y;
end

if (opt ~= 0 && opt ~= 1)
    error ('cov: normalization OPT must be 0 or 1');
end

% Special case, scalar has zero covariance
if (isscalar (x))
    if (isa (x, 'single'))
        c = single (0);
    else
        c = 0;
    end
    return;
end

if (isrow (x))
    x = x.';
end
n = size(x,1);

if (nargin == 1 || isscalar (y))
    %x = center (x, 1);
    x = bsxfun(@minus, x, mean (x, 1));
    c = x' * x / (n - 1 + opt);
else
    if (isrow (y))
        y = y.';
    end
    if (size(y,1) ~= n)
        error ('cov: X and Y must have the same number of observations');
    end
    %x = center (x, 1);
    %y = center (y, 1);
    x = bsxfun(@minus, x, mean (x, 1));
    y = bsxfun(@minus, y, mean (y, 1));
    c = x' * y / (n - 1 + opt);
end

end
