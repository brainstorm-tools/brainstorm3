% Copyright (C) 2014-2015 Nir Krakauer
% Copyright (C) 2000-2015 Paul Kienzle
% Copyright (C) 2009 VZLU Prague
%
% This file is part of Octave.
%
% Octave is free software; you can redistribute it and/or modify it
% under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 3 of the License, or (at
% your option) any later version.
%
% Octave is distributed in the hope that it will be useful, but
% WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
% General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with Octave; see the file COPYING.  If not, see
% <http://www.gnu.org/licenses/>.

% -*- texinfo -*-
% @deftypefn  {Function File} {@var{yi} =} interp1 (@var{x}, @var{y}, @var{xi})
% @deftypefnx {Function File} {@var{yi} =} interp1 (@var{y}, @var{xi})
% @deftypefnx {Function File} {@var{yi} =} interp1 (@dots{}, @var{method})
% @deftypefnx {Function File} {@var{yi} =} interp1 (@dots{}, @var{extrap})
% @deftypefnx {Function File} {@var{yi} =} interp1 (@dots{}, "left")
% @deftypefnx {Function File} {@var{yi} =} interp1 (@dots{}, "right")
% @deftypefnx {Function File} {@var{pp} =} interp1 (@dots{}, "pp")
%
% One-dimensional interpolation.
%
% Interpolate input data to determine the value of @var{yi} at the points
% @var{xi}.  If not specified, @var{x} is taken to be the indices of @var{y}
% (@code{1:length (@var{y})}).  If @var{y} is a matrix or an N-dimensional
% array, the interpolation is performed on each column of @var{y}.
%
% The interpolation @var{method} is one of:
%
% @table @asis
% @item @qcode{"nearest"}
% Return the nearest neighbor.
%
% @item @qcode{"previous"}
% Return the previous neighbor.
%
% @item @qcode{"next"}
% Return the next neighbor.
%
% @item @qcode{"linear"} (default)
% Linear interpolation from nearest neighbors.
%
% @item @qcode{"pchip"}
% Piecewise cubic Hermite interpolating polynomial---shape-preserving
% interpolation with smooth first derivative.
%
% @item @qcode{"cubic"}
% Cubic interpolation (same as @qcode{"pchip"}).
%
% @item @qcode{"spline"}
% Cubic spline interpolation---smooth first and second derivatives
% throughout the curve.
% @end table
%
% Adding '*' to the start of any method above forces @code{interp1}
% to assume that @var{x} is uniformly spaced, and only @code{@var{x}(1)}
% and @code{@var{x}(2)} are referenced.  This is usually faster,
% and is never slower.  The default method is @qcode{"linear"}.
%
% If @var{extrap} is the string @qcode{"extrap"}, then extrapolate values
% beyond the endpoints using the current @var{method}.  If @var{extrap} is a
% number, then replace values beyond the endpoints with that number.  When
% unspecified, @var{extrap} defaults to @code{NA}.
%
% If the string argument @qcode{"pp"} is specified, then @var{xi} should not
% be supplied and @code{interp1} returns a piecewise polynomial object.  This
% object can later be used with @code{ppval} to evaluate the interpolation.
% There is an equivalence, such that @code{ppval (interp1 (@var{x},
% @var{y}, @var{method}, @qcode{"pp"}), @var{xi}) == interp1 (@var{x}, @var{y},
% @var{xi}, @var{method}, @qcode{"extrap"})}.
%
% Duplicate points in @var{x} specify a discontinuous interpolant.  There
% may be at most 2 consecutive points with the same value.
% If @var{x} is increasing, the default discontinuous interpolant is
% right-continuous.  If @var{x} is decreasing, the default discontinuous
% interpolant is left-continuous.
% The continuity condition of the interpolant may be specified by using
% the options @qcode{"left"} or @qcode{"right"} to select a left-continuous
% or right-continuous interpolant, respectively.
% Discontinuous interpolation is only allowed for @qcode{"nearest"} and
% @qcode{"linear"} methods; in all other cases, the @var{x}-values must be
% unique.
%
% An example of the use of @code{interp1} is
%
% @example
% @group
% xf = [0:0.05:10];
% yf = sin (2*pi*xf/5);
% xp = [0:10];
% yp = sin (2*pi*xp/5);
% lin = interp1 (xp, yp, xf);
% near = interp1 (xp, yp, xf, "nearest");
% pch = interp1 (xp, yp, xf, "pchip");
% spl = interp1 (xp, yp, xf, "spline");
% plot (xf,yf,"r", xf,near,"g", xf,lin,"b", xf,pch,"c", xf,spl,"m",
%       xp,yp,"r*");
% legend ("original", "nearest", "linear", "pchip", "spline");
% @end group
% @end example
%
% @seealso{pchip, spline, interpft, interp2, interp3, interpn}
% @end deftypefn

% Author: Paul Kienzle
% Date: 2000-03-25
%    added 'nearest' as suggested by Kai Habel
% 2000-07-17 Paul Kienzle
%    added '*' methods and matrix y
%    check for proper table lengths
% 2002-01-23 Paul Kienzle
%    fixed extrapolation

function yi = oc_interp1 (x, y, varargin)

  if (nargin < 2 || nargin > 6)
    print_usage ();
  end

  method = 'linear';
  extrap = [];
  xi = [];
  ispp = false;
  firstnumeric = true;
  rightcontinuous = NaN;

  if (nargin > 2)
    for i = 1:length (varargin)
      arg = varargin{i};
      if (ischar (arg))
        arg = tolower (arg);
        switch (arg)
          case 'extrap'
            extrap = 'extrap';
          case 'pp'
            ispp = true;
          case {'right', '-right'}
            rightcontinuous = true;
          case {'left', '-left'}
            rightcontinuous = false;
          otherwise
            method = arg;
        end
      else
        if (firstnumeric)
          xi = arg;
          firstnumeric = false;
        else
          extrap = arg;
        end
      end
    end
  end

  if (isempty (xi) && firstnumeric && ~ispp)
    xi = y;
    y = x;
    if (isvector (y))
      x = 1:numel (y);
    else
      x = 1:size(y,1);
    end
  end

  % reshape matrices for convenience
  x = x(:);
  nx = size(x,1);
  szx = size (xi);
  if (isvector (y))
    y = y(:);
  end

  szy = size (y);
  y = y(:,:);
  [ny, nc] = size (y);
  xi = xi(:);

  % determine sizes
  if (nx < 2 || ny < 2)
    error ('interp1: minimum of 2 points required in each dimension');
  end

  % check whether x is sorted; sort if not.
  if (~issorted (x))
    [x, p] = sort (x);
    y = y(p,:);
  end

  if (any (strcmp (method, {'previous', '*previous', 'next', '*next'})))
    rightcontinuous = NaN; % needed for these methods to work
  end

  if (isnan (rightcontinuous))
    % If not specified, set the continuity condition
    if (x(end) < x(1))
      rightcontinuous = false;
    else
      rightcontinuous = true;
    end
  elseif ((rightcontinuous && (x(end) < x(1))) || (~rightcontinuous && (x(end) > x(1))))
    % Switch between left-continuous and right-continuous
    x = flipud (x);
    y = flipud (y);
  end

  % Because of the way mkpp works, it's easiest to implement 'next'
  % by running 'previous' with vectors flipped.
  if (strcmp (method, 'next'))
    x = flipud (x);
    y = flipud (y);
    method = 'previous';
  elseif (strcmp (method, '*next'))
    x = flipud (x);
    y = flipud (y);
    method = '*previous';
  end

  starmethod = method(1) == '*';

  if (starmethod)
    dx = x(2) - x(1);
  else
    jumps = x(1:end-1) == x(2:end);
    have_jumps = any (jumps);
    if (have_jumps)
      if (strcmp (method, 'linear') || strcmp (method, ('nearest')))
        if (any (jumps(1:nx-2) & jumps(2:nx-1)))
          warning ('interp1: multiple discontinuities at the same X value');
        end
      else
        error ('interp1: discontinuities not supported for method "%s"', method);
      end
    end
  end

  % Proceed with interpolating by all methods.
  switch (method)

    case 'nearest'
      pp = mkpp ([x(1); (x(1:nx-1)+x(2:nx))/2; x(nx)],  shiftdim (y, 1), szy(2:end));
      pp.orient = 'first';

      if (ispp)
        yi = pp;
      else
        yi = ppval (pp, reshape (xi, szx));
      end

    case '*nearest'
      pp = mkpp ([x(1), x(1)+[0.5:(nx-1)]*dx, x(nx)],  shiftdim (y, 1), szy(2:end));
      pp.orient = 'first';

      if (ispp)
        yi = pp;
      else
        yi = ppval (pp, reshape (xi, szx));
      end

    case 'previous'
      pp = mkpp ([x(1:nx); 2*x(nx)-x(nx-1)],  shiftdim (y, 1), szy(2:end));
      pp.orient = 'first';

      if (ispp)
        yi = pp;
      else
        yi = ppval (pp, reshape (xi, szx));
      end

    case '*previous'
      pp = mkpp (x(1)+[0:nx]*dx,  shiftdim (y, 1), szy(2:end));
      pp.orient = 'first';

      if (ispp)
        yi = pp;
      else
        yi = ppval (pp, reshape (xi, szx));
      end

    case 'linear'

      xx = x;
      nxx = nx;
      yy = y;
      dy = diff (yy);
      if (have_jumps)
        % Omit zero-size intervals.
        xx(jumps) = [];
        nxx = size(xx,1);
        yy(jumps, :) = [];
        dy(jumps, :) = [];
      end

      dx = diff (xx);
      szdy = size(dy);
      dx = repmat (dx, [1 szdy(2:end)]);

      coefs = [(dy./dx).', yy(1:nxx-1, :).'];

      pp = mkpp (xx, coefs, szy(2:end));
      pp.orient = 'first';

      if (ispp)
        yi = pp;
      else
        yi = ppval (pp, reshape (xi, szx));
      end

    case '*linear'
      dy = diff (y);
      coefs = [reshape((dy/dx).',[],1), reshape(y(1:nx-1, :).',[],1)];
      pp = mkpp (x, coefs, szy(2:end));
      pp.orient = 'first';

      if (ispp)
        yi = pp;
      else
        yi = ppval (pp, reshape (xi, szx));
      end

    case {'pchip', '*pchip', 'cubic', '*cubic'}
      if (nx == 2 || starmethod)
        x = linspace (x(1), x(nx), ny);
      end

      if (ispp)
        y = shiftdim (reshape (y, szy), 1);
        yi = pchip (x, y);
        yi.orient = 'first';
      else
        y = shiftdim (y, 1);
        yi = pchip (x, y, reshape (xi, szx));
        if (~isvector (y))
          yi = shiftdim (yi, 1);
        end
      end

    case {'spline', '*spline'}
      if (nx == 2 || starmethod)
        x = linspace (x(1), x(nx), ny);
      end

      if (ispp)
        y = shiftdim (reshape (y, szy), 1);
        yi = spline (x, y);
        yi.orient = 'first';
      else
        y = shiftdim (y, 1);
        yi = spline (x, y, reshape (xi, szx));
        if (~isvector (y))
          yi = shiftdim (yi, 1);
        end
      end

    otherwise
      error ('interp1: invalid method "%s"', method);

  end

  if (~ispp && isnumeric (extrap))
    % determine which values are out of range and set them to extrap,
    % unless extrap == 'extrap'.
    minx = min (x(1), x(nx));
    maxx = max (x(1), x(nx));

    xi = reshape (xi, szx);
    outliers = xi < minx | ~(xi <= maxx); % this even catches NaNs
    if (all(size(outliers) == size(yi)))
      yi(outliers) = extrap;
      yi = reshape (yi, szx);
    elseif (~isvector (yi))
      yi(outliers, :) = extrap;
    else
      yi(outliers.') = extrap;
    end

  end

end
