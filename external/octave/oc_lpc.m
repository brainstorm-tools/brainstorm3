% Copyright (C) 2013 Leonardo Araujo
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; If not, see <http://www.gnu.org/licenses/>.

% -*- texinfo -*-
% @deftypefn {Function File} {[@var{a}, @var{e}] = } lpc (@var{x}, @var{p})
% @deftypefnx {Function File} {@var{a} = } lpc (@var{x}, @var{p})
%
% Determines the forward linear predictor by minimizing the prediction error
% in the least squares sense. Use the Durbin-Levinson algorithm to solve
% the Yule-Walker equations obtained by the autocorrelation of the input signal.
%
% @table @var
% @item x
% data vector used to estimate the model
% @item p
% the order of the linear prediction polynomial
% @item a
% predictor coefficientes
% @item e
% prediction error
% @end table
% @end deftypefn
% @seealso{aryule,levinson}

function [a,e] = oc_lpc(x,p)

if ( nargin~=2 )
    print_usage;
elseif ( ~isvector(x) || length(x)<2 )
    error( 'lpc: arg 1 (x) must be vector of length >1' );
elseif ( ~isscalar(p) || fix(p)~=p || p > length(x)-1 || p < 1)
    error( 'lpc: arg 2 (p) must be an integer >0 and <length(x)' );
end

x = x(:);
L = length(x);
r = xcorr(x', p+1, 'unbiased');
r(1:p+1) = [];       % remove negative autocorrelation lags
r(1) = real(r(1));   % levinson/toeplitz requires exactly real r(1),  r(1)==conj(r(1))
a = -oc_levinson(r, p); % Use the Durbin-Levinson algorithm to solve:
%       toeplitz(acf(1:p)) * x = -acf(2:p+1).
e = [];
for i = p+1 : L
    e(i-p) = x(i) - fliplr(a(2:end)) * x(i-p:i-1);
end

end

