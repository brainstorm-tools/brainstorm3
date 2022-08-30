% Copyright (C) 1996-2017 John W. Eaton
%
% This program is free software: you can redistribute it and/or
% modify it under the terms of the GNU General Public License as
% published by the Free Software Foundation, either version 3 of the
% License, or (at your option) any later version.
%
% This program is distributed in the hope that it will be useful, but
% WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
% General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; see the file COPYING.  If not, see
% <http://www.gnu.org/licenses/>.

% -*- texinfo -*-
% @deftypefn  {} {} corr (@var{x})
% @deftypefnx {} {} corr (@var{x}, @var{y})
% Compute matrix of correlation coefficients.
%
% If each row of @var{x} and @var{y} is an observation and each column is
% a variable, then the @w{(@var{i}, @var{j})-th} entry of
% @code{corr (@var{x}, @var{y})} is the correlation between the
% @var{i}-th variable in @var{x} and the @var{j}-th variable in @var{y}.
% @tex
% $$
% {\rm corr}(x,y) = {{\rm cov}(x,y) \over {\rm std}(x) \, {\rm std}(y)}
% $$
% @end tex
% @ifnottex
%
% @example
% corr (@var{x},@var{y}) = cov (@var{x},@var{y}) / (std (@var{x}) * std (@var{y}))
% @end example
%
% @end ifnottex
% If called with one argument, compute @code{corr (@var{x}, @var{x})},
% the correlation between the columns of @var{x}.
% @seealso{cov}
% @end deftypefn

% Author: Kurt Hornik <hornik@wu-wien.ac.at>
% Created: March 1993
% Adapted-By: jwe

function retval = corr (x, y)

if (nargin < 2)
    y = [];
end
if (nargin < 1 || nargin > 2)
    error('Usage: corr (x, y = [])');
end

% Special case, scalar is always 100% correlated with itself
if (isscalar (x))
    if (isa (x, 'single'))
        retval = single (1);
    else
        retval = 1;
    end
    return;
end

% No check for division by zero error, which happens only when
% there is a constant vector and should be rare.
if (nargin == 2)
    c = oc_cov (x, y);
    s = std (x)' * std (y);
    retval = c ./ s;
else
    c = oc_cov (x);
    s = sqrt (diag (c));
    retval = c ./ (s * s');
end

end

