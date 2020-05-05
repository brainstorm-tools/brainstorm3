function P = morlet_transform(x, t, f, fc, FWHM_tc, squared)
% MORLET_TRANSFORM: 
%     Applies complex Morlet wavelet transform to the timeseries stored in the 
%     matrix x with size (ntimeseries x ntimes). It returns a wavelet coefficient map 
%     (by default squared)
%
% INPUTS:
%    - x       : (ntimeseries x ntimes) a vector of the timeseries
%    - t       : (1 x ntimes) a vector of times (in secs)
%    - f       : (1 x nfreqs) a vector of frequencies in which to estimate the
%                wavelet transform (in Hz). Default is 1:60Hz
%    - fc      : (default is 1) central frequency of complex Morlet wavelet in Hz
%    - FWHM_tc : (default is 3) FWHM of complex Morlet wavelet in
%                time. Also see morlet_design.m. 
%    - squared : 'y' (default) or 'n'. Flag that decided whether the function returns the
%                squared coefficients (y) or not (n). Squaring represents neural power in
%                the corresponding frequency.
%
% OUTPUT:
%    - P: (ntimeseries x nfreqs x ntimes), or
%    - P: (nFreqs x nTimes), if ntimeseries = 1
%         A matrix of wavelet coefficients (by default squared)
%
% EXAMPLE:
%    t = 0:.01:1;
%    f = 5:20;
%    P = morlet_transform(sin(2*pi*10*t),t,f);
%    Coefs = morlet_transform(sin(2*pi*10*t),t,f,[],[],'n');

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
% Authors: Dimitrios Pantazis, 2010

% Parse inputs
if (nargin == 0)
    help morlet_transform
    return
end
if (nargin < 6) || isempty(squared)
    squared = 'y';
end
if (nargin < 5) || isempty(FWHM_tc)
    FWHM_tc = 3; 
end
if (nargin < 4) || isempty(fc)
    fc = 1; 
end
if (nargin < 3) || isempty(f)
    f = 1:60;
end
% Transpose data vector if needed
if (size(x,2) == 1)
    x = x';
end

% Signal parameters
Ts = t(2) - t(1); % sampling period of signal
Fs = 1 / Ts;      % sampling frequency of signal

% Complex morlet wavelet parameters
scales = f ./ fc; % Scales for wavelet
sigma_tc = FWHM_tc / sqrt(8*log(2));
sigma_t = sigma_tc ./ scales;
nscales = length(scales);

% Compute wavelet kernels for each scale
precision = 3;     % ANDREW: precision = 4 ?
W = cell(nscales, 1);
for s = 1:nscales
    xval = -precision*sigma_t(s) : 1/Fs : precision*sigma_t(s);
    W{s} = sqrt(scales(s)) * morlet_wavelet(scales(s)*xval, fc, sigma_tc);
end
    
% Compute wavelet coefficients
nx = size(x,1);     % Number of timeseries
ntimes = size(x,2); % Number of timepoints
P = zeros(nx,nscales,ntimes);
for s = 1:nscales
    % progress(s,1,nscales,1,'scales');
    %Convolution flips W{s}. So, I need to unflip it to become inner product.
    %Convolution does not conjugate, but wavelet transform does: <f,w> = f*conj(w)
    %So, in the convolution I need to use conj(fliplr(w)) instead of w
    %But for the complex Morlet wavelet they are equal!
    for ch = 1:size(x,1) %it is slower to use directly  P(:,s,:) = conv2(x,W{s},'same') * Ts; 
        P(ch,s,:) = conv2(x(ch,:), W{s}, 'same') * Ts; 
    end
end

% %if only one timeseries, compress first dimension
% if size(P,1)==1
%     P = squeeze(P);
% end

%if return squared coefficients
if strcmp(squared, 'y')
    P = abs(P) .^ 2; % Return neural power
end

% Convert dimensions in the format we want:
% [nTimeseries x nFreqs x nTimes] => [nTimeseries x nTimes x nFreqs]
P = permute(P, [1,3,2]);


