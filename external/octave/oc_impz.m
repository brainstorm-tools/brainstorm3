% Copyright (C) 1999 Paul Kienzle <pkienzle@users.sf.net>
%
% This program is free software; you can redistribute it and/or modify it under
% the terms of the GNU General Public License as published by the Free Software
% Foundation; either version 3 of the License, or (at your option) any later
% version.
%
% This program is distributed in the hope that it will be useful, but WITHOUT
% ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
% FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
% details.
%
% You should have received a copy of the GNU General Public License along with
% this program; if not, see <http://www.gnu.org/licenses/>.

% -*- texinfo -*-
% @deftypefn  {Function File} {[@var{x}, @var{t}] =} impz (@var{b})
% @deftypefnx {Function File} {[@var{x}, @var{t}] =} impz (@var{b}, @var{a})
% @deftypefnx {Function File} {[@var{x}, @var{t}] =} impz (@var{b}, @var{a}, @var{n})
% @deftypefnx {Function File} {[@var{x}, @var{t}] =} impz (@var{b}, @var{a}, @var{n}, @var{fs})
% @deftypefnx {Function File} {} impz (@dots{})
%
% Generate impulse-response characteristics of the filter. The filter
% coefficients correspond to the the z-plane rational function with
% numerator b and denominator a.  If a is not specified, it defaults to
% 1. If n is not specified, or specified as [], it will be chosen such
% that the signal has a chance to die down to -120dB, or to not explode
% beyond 120dB, or to show five periods if there is no significant
% damping. If no return arguments are requested, plot the results.
%
% @seealso{freqz, zplane}
% @end deftypefn

% FIXME: Call equivalent function from control toolbox since it is
%        probably more sophisticated than this one, and since it
%        is silly to maintain two different versions of essentially
%        the same thing.

function [x_r, t_r] = impz(b, a, n, fs)

  if (nargin < 2) || isempty(a)
      a = 1;
  end
  if (nargin < 3) || isempty(n)
      n = [];
  end
  if (nargin < 4) || isempty(fs)
      fs = 1;
  end
  if nargin == 0 || nargin > 4
    print_usage;
  end

  if isempty(n) && length(a) > 1
    precision = 1e-6;
    r = roots(a);
    maxpole = max(abs(r));
    if (maxpole > 1+precision)     % unstable -- cutoff at 120 dB
      n = floor(6/log10(maxpole));
    elseif (maxpole < 1-precision) % stable -- cutoff at -120 dB
      n = floor(-6/log10(maxpole));
    else                           % periodic -- cutoff after 5 cycles
      n = 30;

      % find longest period less than infinity
      % cutoff after 5 cycles (w=10*pi)
      rperiodic = r(find(abs(r)>=1-precision & abs(arg(r))>0));
      if ~isempty(rperiodic)
        n_periodic = ceil(10*pi./min(abs(arg(rperiodic))));
        if (n_periodic > n)
          n = n_periodic;
        end
      end

      % find most damped pole
      % cutoff at -60 dB
      rdamped = r(find(abs(r)<1-precision));
      if ~isempty(rdamped)
        n_damped = floor(-3/log10(max(abs(rdamped))));
        if (n_damped > n)
          n = n_damped;
        end
      end
    end
    n = n + length(b);
  elseif isempty(n)
    n = length(b);
  end

  if length(a) == 1
    x = oc_fftfilt(b/a, [1, zeros(1,n-1)]);
  else
    x = filter(b, a, [1, zeros(1,n-1)]);
  end
  t = [0:n-1]/fs;

  if nargout >= 1 x_r = x; end
  if nargout >= 2 t_r = t; end
  if nargout == 0
    unwind_protect
      title 'Impulse Response';
      if (fs > 1000)
        t = t * 1000;
        xlabel('Time (msec)');
      else
        xlabel('Time (sec)');
      end
      plot(t, x, '^r;;');
    unwind_protect_cleanup
      title ('')
      xlabel ('')
    end_unwind_protect
  end

end
