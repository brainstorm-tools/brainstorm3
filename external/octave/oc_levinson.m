% Copyright (C) 1999 Paul Kienzle <pkienzle@users.sf.net>
% Copyright (C) 2006 Peter V. Lanspeary, <peter.lanspeary@.adelaide.edu.au>
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
% @deftypefn  {Function File} {[@var{a}, @var{v}, @var{ref}] =} levinson (@var{acf})
% @deftypefnx {Function File} {[@dots{}] =} levinson (@var{acf}, @var{p})
%
% Use the Durbin-Levinson algorithm to solve:
%    toeplitz(acf(1:p)) * x = -acf(2:p+1).
% The solution [1, x'] is the denominator of an all pole filter
% approximation to the signal x which generated the autocorrelation
% function acf.
%
% acf is the autocorrelation function for lags 0 to p.
% p defaults to length(acf)-1.
% Returns
%   a=[1, x'] the denominator filter coefficients.
%   v= variance of the white noise = square of the numerator constant
%   ref = reflection coefficients = coefficients of the lattice
%         implementation of the filter
% Use freqz(sqrt(v),a) to plot the power spectrum.
%
% REFERENCE
% [1] Steven M. Kay and Stanley Lawrence Marple Jr.:
%   "Spectrum analysis -- a modern perspective",
%   Proceedings of the IEEE, Vol 69, pp 1380-1419, Nov., 1981
% @end deftypefn

% Based on:
%    yulewalker.m
%    Copyright (C) 1995 Friedrich Leisch <Friedrich.Leisch@ci.tuwien.ac.at>
%    GPL license

% FIXME: Matlab doesn't return reflection coefficients and
%        errors in addition to the polynomial a.
% FIXME: What is the difference between aryule, levinson,
%        ac2poly, ac2ar, lpc, etc.?

function [a, v, ref] = oc_levinson (acf, p)

if ( nargin<1 )
    print_usage;
elseif( ~isvector(acf) || length(acf)<2 )
    error( 'levinson: arg 1 (acf) must be vector of length >1\n');
elseif ( nargin>1 && ( ~isscalar(p) || fix(p)~=p ) )
    error( 'levinson: arg 2 (p) must be integer >0\n');
else
    if ((nargin == 1)||(p>=length(acf))) 
        p = length(acf) - 1; 
    end
    if( size(acf,2)>1 ) 
        acf=acf(:); 
    end      % force a column vector
    
    if nargout < 3 && p < 100
        % direct solution [O(p^3), but no loops so slightly faster for small p]
        %   Kay & Marple Eqn (2.39)
        R = toeplitz(acf(1:p), conj(acf(1:p)));
        a = R \ -acf(2:p+1);
        a = [ 1, a.' ];
        v = real( a*conj(acf(1:p+1)) );
    else
        % durbin-levinson [O(p^2), so significantly faster for large p]
        %   Kay & Marple Eqns (2.42-2.46)
        ref = zeros(p,1);
        g = -acf(2)/acf(1);
        a = g;
        v = real( ( 1 - g*conj(g)) * acf(1) );
        ref(1) = g;
        for t = 2 : p
            g = -(acf(t+1) + a * acf(t:-1:2)) / v;
            a = [ a+g*conj(a(t-1:-1:1)), g ];
            v = v * ( 1 - real(g*conj(g)) ) ;
            ref(t) = g;
        end
        a = [1, a];
    end
end

end
