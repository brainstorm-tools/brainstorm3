% Copyright (C) 2000 Paul Kienzle  <pkienzle@users.sf.net>
% Copyright (C) 2007 Peter L. Soendergaard
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
% @deftypefn {Function File} {@var{h} =} hilbert (@var{f}, @var{N}, @var{dim})
% Analytic extension of real valued signal.
%
% @code{@var{h} = hilbert (@var{f})} computes the extension of the real
% valued signal @var{f} to an analytic signal. If @var{f} is a matrix,
% the transformation is applied to each column. For N-D arrays,
% the transformation is applied to the first non-singleton dimension.
%
% @code{real (@var{h})} contains the original signal @var{f}.
% @code{imag (@var{h})} contains the Hilbert transform of @var{f}.
%
% @code{hilbert (@var{f}, @var{N})} does the same using a length @var{N}
% Hilbert transform. The result will also have length @var{N}.
%
% @code{hilbert (@var{f}, [], @var{dim})} or
% @code{hilbert (@var{f}, @var{N}, @var{dim})} does the same along
% dimension @var{dim}.
% @end deftypefn

function f = oc_hilbert(f, N, dim)

% ------ PRE: initialization and dimension shifting ---------

if (nargin<1 || nargin>3)
    error('Invalid call');
end
if (nargin < 3)
    dim = [];
end
if (nargin < 2)
    N = [];
end

if ~isreal(f)
    warning ('HILBERT: ignoring imaginary part of signal');
    f = real (f);
end

D=ndims(f);

% Dummy assignment.
order=1;

if isempty(dim)
    dim=1;
    
    if sum(size(f)>1)==1
        % We have a vector, find the dimension where it lives.
        dim=find(size(f)>1);
    end
    
else
    if (numel(dim)~=1 || ~isnumeric(dim))
        error('HILBERT: dim must be a scalar.');
    end
    if rem(dim,1)~=0
        error('HILBERT: dim must be an integer.');
    end
    if (dim<1) || (dim>D)
        error('HILBERT: dim must be in the range from 1 to %d.',D);
    end
    
end

if (numel(N)>1 || ~isnumeric(N))
    error('N must be a scalar.');
elseif (~isempty(N) && rem(N,1)~=0)
    error('N must be an integer.');
end

if dim>1
    order=[dim, 1:dim-1,dim+1:D];
    
    % Put the desired dimension first.
    f=permute(f,order);
    
end

Ls=size(f,1);

% If N is empty it is set to be the length of the transform.
if isempty(N)
    N=Ls;
end

% Remember the exact size for later and modify it for the new length
permutedsize=size(f);
permutedsize(1)=N;

% Reshape f to a matrix.
f=reshape(f,size(f,1),numel(f)/size(f,1));
W=size(f,2);

if ~isempty(N)
    f = oc_postpad(f,N);
end

% ------- actual computation -----------------
if N>2
    f=fft(f);
    
    if rem(N,2)==0
        f=[f(1,:);
            2*f(2:N/2,:);
            f(N/2+1,:);
            zeros(N/2-1,W)];
    else
        f=[f(1,:);
            2*f(2:(N+1)/2,:);
            zeros((N-1)/2,W)];
    end
    
    f=ifft(f);
end

% ------- POST: Restoration of dimensions ------------

% Restore the original, permuted shape.
f=reshape(f,permutedsize);

if dim>1
    % Undo the permutation.
    f=ipermute(f,order);
end

end

%!demo
%! % notice that the imaginary signal is phase-shifted 90 degrees
%! t=linspace(0,10,256);
%! z = hilbert(sin(2*pi*0.5*t));
%! grid on; plot(t,real(z),';real;',t,imag(z),';imag;');

%!demo
%! % the magnitude of the hilbert transform eliminates the carrier
%! t=linspace(0,10,1024);
%! x=5*cos(0.2*t).*sin(100*t);
%! grid on; plot(t,x,'g;z;',t,abs(hilbert(x)),'b;|hilbert(z)|;');
