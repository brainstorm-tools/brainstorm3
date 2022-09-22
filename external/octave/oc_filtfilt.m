% Copyright (C) 1999 Paul Kienzle <pkienzle@users.sf.net>
% Copyright (C) 2007 Francesco Potortì <pot@gnu.org>
% Copyright (C) 2008 Luca Citi <lciti@essex.ac.uk>
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; see the file COPYING. If not, see
% <https://www.gnu.org/licenses/>.

% -*- texinfo -*-
% @deftypefn {Function File} {@var{y} =} filtfilt (@var{b}, @var{a}, @var{x})
%
% Forward and reverse filter the signal. This corrects for phase
% distortion introduced by a one-pass filter, though it does square the
% magnitude response in the process. That's the theory at least.  In
% practice the phase correction is not perfect, and magnitude response
% is distorted, particularly in the stop band.
%
% Example
% @example
% @group
% [b, a]=butter(3, 0.1);                  % 5 Hz low-pass filter
% t = 0:0.01:1.0;                         % 1 second sample
% x=sin(2*pi*t*2.3)+0.25*randn(size(t));  % 2.3 Hz sinusoid+noise
% y = filtfilt(b,a,x); z = filter(b,a,x); % apply filter
% plot(t,x,';data;',t,y,';filtfilt;',t,z,';filter;')
% @end group
% @end example
% @end deftypefn

% FIXME: My version seems to have similar quality to matlab,
%        but both are pretty bad.  They do remove gross lag errors, though.

function y = oc_filtfilt(b, a, x)

if (nargin ~= 3)
    print_usage;
end
rotate = (size(x,1)==1);
if rotate                     % a row vector
    x = x(:);                   % make it a column vector
end

lx = size(x,1);
a = a(:).';
b = b(:).';
lb = length(b);
la = length(a);
n = max(lb, la);
lrefl = 3 * (n - 1);
if la < n, a(n) = 0; end
if lb < n, b(n) = 0; end

if (size(x,1) <= lrefl)
    error ("filtfilt: X must be a vector or matrix with length greater than %d", ...
        lrefl);
end

% Compute a the initial state taking inspiration from
% Likhterov & Kopeika, 2003. "Hardware-efficient technique for
%     minimizing startup transients in Direct Form II digital filters"
kdc = sum(b) / sum(a);
if (abs(kdc) < inf) % neither NaN nor +/- Inf
    si = fliplr(cumsum(fliplr(b - kdc * a)));
else
    si = zeros(size(a)); % fall back to zero initialization
end
si(1) = [];

for c = 1:size(x,2) % filter all columns, one by one
    v = [2*x(1,c)-x((lrefl+1):-1:2,c); x(:,c);
        2*x(end,c)-x((end-1):-1:end-lrefl,c)]; % a column vector

    % Do forward and reverse filtering
    v = filter(b,a,v,si*v(1));                   % forward filter
    v = flipud(filter(b,a,flipud(v),si*v(end))); % reverse filter
    y(:,c) = v((lrefl+1):(lx+lrefl));
end

if (rotate)                   % x was a row vector
    y = rot90(y);               % rotate it back
end
