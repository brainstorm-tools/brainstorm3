function xf = ImaGIN_bandpass(x,Fs,Fp1,Fp2)
% Bandpass filter for the signal x.  An acausal fft 
% algorithm is applied (i.e. no phase shift). The filter functions is         
% constructed from a Hamming window (default window used in "fir2" Matlab function). 
% to avoid ripples in the frequency reponse (windowing is a smoothing in frequency domain)
%
% Fs : sampling frequency
%
% The passbands (Fp1 Fp2) frequencies are defined in Hz as
%                  ----------                      
%                /|         | \
%               / |         |  \
%              /  |         |   \
%             /   |         |    \
%   ----------    |         |     ----------------- 
%                 |         |
%           Fs1  Fp1       Fp2   Fs2            
%
% DEFAULTS values
% Fs1 = Fp1 - 0.5 in Hz
% Fs2 = Fp2 + 0.5 in Hz
%
%
% If NO OUTPUTS arguments are assigned the filter function H(f) and
% impulse response are plotted. 
%
% NOTE: for long data traces the filter is very slow.
%
% EXEMPLE 
%    x= sin(2*pi*12*[0:1/200:10])+sin(2*pi*30*[0:1/200:10])
%    y=bandpassFilter(x,200,5,20);    bandpass filter between 5 and 20 Hz
%------------------------------------------------------------------------
% Originally produced by the Helsinki University of Technology,
% Adapted by Mariecito SCHMUCKEN 2001
%------------------------------------------------------------------------

%Default values in Hz
Fs1 = Fp1 - 0.5; 
Fs2 = Fp2 + 0.5;

if size(x,1) == 1
    x = x';
end
% Make x EVEN
Norig = size(x,1); 
if rem(Norig,2)
    x = [x' zeros(size(x,2),1)]';                
end

% Normalize frequencies  
Ns1 = Fs1/(Fs/2);
Ns2 = Fs2/(Fs/2);
Np1 = Fp1/(Fs/2);
Np2 = Fp2/(Fs/2);

% Construct the filter function H(f)
N = size(x,1);
Nh = N/2;

B = fir2(N-1,[0 Ns1 Np1 Np2 Ns2 1],[0 0 1 1 0 0]); 
% Make zero-phase filter function
H = abs(fft(B));  
IPR = real(ifft(H));

if size(x,2) > 1
    for k=1:size(x,2)
        xf(:,k) = real(ifft(fft(x(:,k)) .* H'));
    end
    xf = xf(1:Norig,:);
else
    xf = real(ifft(fft(x') .* H));
    xf = xf(1:Norig);
end
x=x(1:Norig); 

% if NO OUTPUT argument then plots
if nargout == 0 
    f = Fs*(0:Nh-1)/(N);
    freqz(IPR,1,f,Fs);    
    figure, subplot(2,1,1)
    plot(f,H(1:Nh));
    xlim([0 2*Fs2])
    title('Filter function H(f)')
    xlabel('Frequency (Hz)')
    subplot(2,1,2)
    plot((1:Nh)/Fs,IPR(1:Nh))
    xlim([0 2/Fp1])
    xlabel('Time (sec)')
    ylim([min(IPR) max(IPR)])
    title('Impulse response')
    figure, subplot(211),
    periodogram(x,hamming(Norig),1024,200);
    subplot(212), periodogram(xf,hamming(Norig),1024,200);
end

end




% Copyright (C) 2000 Paul Kienzle
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
% along with this program; if not, write to the Free Software
% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

% usage: b = fir2(n, f, m [, grid_n [, ramp_n]] [, window])
%
% Produce an FIR filter of order n with arbitrary frequency response, 
% returning the n+1 filter coefficients in b.  
%
% n: order of the filter (1 less than the length of the filter)
% f: frequency at band edges
%    f is a vector of nondecreasing elements in [0,1]
%    the first element must be 0 and the last element must be 1
%    if elements are identical, it indicates a jump in freq. response
% m: magnitude at band edges
%    m is a vector of length(f)
% grid_n: length of ideal frequency response function
%    defaults to 512, should be a power of 2 bigger than n
% ramp_n: transition width for jumps in filter response
%    defaults to grid_n/20; a wider ramp gives wider transitions
%    but has better stopband characteristics.
% window: smoothing window
%    defaults to hamming(n+1) row vector
%    returned filter is the same shape as the smoothing window
%
% To apply the filter, use the return vector b:
%       y=filter(b,1,x);
% Note that plot(f,m) shows target response.
%
% Example:
%   f=[0, 0.3, 0.3, 0.6, 0.6, 1]; m=[0, 0, 1, 1/2, 0, 0];
%   [h, w] = freqz(fir2(100,f,m));
%   plot(f,m,';target response;',w/pi,abs(h),';filter response;');

% Feb 27, 2000 PAK
%     use ramping on any transition less than ramp_n units
%     use 2^nextpow2(n+1) for expanded grid size if grid is too small
% 2001-01-30 PAK
%     set default ramp length to grid_n/20 (i.e., pi/20 radians)
%     use interp1 to interpolate the grid points
%     better(?) handling of 0 and pi frequency points.
%     added some demos

function b = fir2(n, f, m, grid_n, ramp_n, window)
    if nargin < 3 || nargin > 6
        disp('b = fir2(n, f, m [, grid_n [, ramp_n]] [, window])');
        return
    end

    % verify frequency and magnitude vectors are reasonable
    t = length(f);
    if t<2 || f(1)~=0 || f(t)~=1 || any(diff(f)<0)
        disp('frequency must be nondecreasing starting from 0 and ending at 1');
        return
    end
    if t ~= length(m)
        disp('frequency and magnitude vectors must be the same length');
        return
    end

    % find the grid spacing and ramp width
    if (nargin>4 && length(grid_n)>1) || (nargin>5 && (length(grid_n)>1 || length(ramp_n)>1))
        disp('grid_n and ramp_n must be integers');
        return
    end
    if nargin < 4, grid_n=512; end
    if nargin < 5, ramp_n=grid_n/20; end

    % find the window parameter, or default to hamming
    w=[];
    if length(grid_n)>1, w=grid_n; grid_n=512; end
    if length(ramp_n)>1, w=ramp_n; ramp_n=grid_n/20; end
    if nargin < 6, window=w; end
    if isempty(window), window=hamming(n+1); end
    if ~isreal(window), window=feval(window, n+1); end
    if length(window) ~= n+1, disp('window must be of length n+1'); return;end

    % make sure grid is big enough for the window
    if 2*grid_n < n+1, grid_n = 2^nextpow2(n+1); end

    % Apply ramps to discontinuities
    if (ramp_n > 0)
        % remember original frequency points prior to applying ramps
        basef = f; basem = m;

        % separate identical frequencies
        idx = find (diff(f) == 0);
        f(idx) = f(idx) - ramp_n/grid_n/2;
        f(idx+1) = f(idx+1) + ramp_n/grid_n/2;

        % make sure the grid points stay monotonic
        idx = find (diff(f) < 0);
        f(idx) = (basef(idx) + basef(idx+1))/2;
        f(idx+1) = (basef(idx) + basef(idx+1))/2;

        % preserve window shape even though f may have changed
        m = interp1(basef, basem, f);

        % plot(f,m,';ramped;',basef,basem,';original;'); pause;
    end

    % interpolate between grid points
    grid = interp1(f,m,linspace(0,1,grid_n+1)');

    % Transform frequency response into time response and
    % center the response about n/2, truncating the excess
    b = ifft([grid ; grid(grid_n:-1:2)]);
    mid = (n+1)/2;
    b = real ([ b((2*grid_n-floor(mid)+1) : (2*grid_n)) ; b(1:ceil(mid)) ]);

    % Multiplication in the time domain is convolution in frequency,
    % so multiply by our window now to smooth the frequency response.
    if size(window,1) > 1
        b = b .* window;
    else
        b = b' .* window;
    end
    b=b';
end



% Copyright (C) 1995, 1996, 1997  Andreas Weingessel
%
% This file is part of Octave.
%
% Octave is free software; you can redistribute it and/or modify it
% under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2, or (at your option)
% any later version.
%
% Octave is distributed in the hope that it will be useful, but
% WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
% General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with Octave; see the file COPYING.  If not, write to the Free
% Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
% 02110-1301, USA.

% -*- texinfo -*-
% @deftypefn {Function File} {} hamming (@var{m})
% Return the filter coefficients of a Hamming window of length @var{m}.
%
% For a definition of the Hamming window, see e.g. A. V. Oppenheim &
% R. W. Schafer, "Discrete-Time Signal Processing".
% @end deftypefn

% Author: AW <Andreas.Weingessel@ci.tuwien.ac.at>
% Description: Coefficients of the Hamming window

function c = hamming (m)
    if (nargin ~= 1)
        disp ('hamming (m)');
        return
    end

    if (~ (length(m)==1 && (m == round(m)) && (m > 0)))
        error ('hamming: m has to be an integer > 0');
    end

    if (m == 1)
        c = 1;
    else
        m = m - 1;
        c = 0.54 - 0.46 * cos (2 * pi * (0:m)' / m);
    end
end
