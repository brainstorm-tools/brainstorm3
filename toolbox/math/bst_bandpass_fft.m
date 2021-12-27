function x = bst_bandpass_fft(x, Fs, HighPass, LowPass, isFir2, isMirror, stopBand)
% BST_BANDPASS_FFT: Bandpass filter for the signal x, FFT-based (used by default until Nov 2014). 
%
% USAGE:  x = bst_bandpass_fft(x, Fs, HighPass, LowPass, isFir2=1, isMirror=1)
%
% INPUT: 
%    - x         : [nChannels,nTime] signal to process
%    - Fs        : Sampling frequency
%    - HighPass  : Frequency below this value are filtered (set to 0 for lowpass filter only)
%    - LowPass   : Frequency above this value are filtered (set to 0 for highpass filter only)
%    - isFir2    : If 1, use function fir2 to build the filter (Signal Processing Toolbox)
%                  If 0, use roughly cut the unwanted frequency bins (FFT binary mask)
%    - isMirror  : Mirror the signal, before and after, to avoid edge effects
%    - stopBand  : [low,high] bounds for the stop band filter
%
% DESCRIPTION: 
%    A causal fft algorithm is applied (i.e. no phase shift).
%    The filter function is constructed from a Hamming window.
%    Low-stop filter:  LowStop  = LowPass  + min(20, LowPass * 0.2)
%    High-stop filter: HighStop = HighPass - min(5, HighPass / 2);
%    
% WARNING: 
%    - THIS FUNCTION APPLIES A LOW-PASS FILTER (Fs/3) IF WE TRY TO APPLY A HIGH-PASS FILTER ONLY
%    - Possible issue: FFT without padding, might lead to long execution times for certain data lengths
%    - Possible issue: FFT uses a circular convolution here (instead of linear)
%
% NOTE: Requires Signal Processing Toolbox for the fir2 function
%       If not present: use oc_fir2 function from Octave

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
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
% Authors: Helsinki University of Technology, Adapted by Mariecito SCHMUCKEN (2001)
%          Sylvain Baillet, Francois Tadel, 2010-2012

% ===== PREPARE SIGNAL =====
% Parse inputs
if (nargin < 7)
    stopBand = [];
end
if (nargin < 6) || isempty(isMirror)
    isMirror = 1;
end
if (nargin < 5) || isempty(isFir2)
    isFir2 = 1;
end
% Mirroring + Make x even
Norig = size(x,2);
% Nmirror = round(.1 * Norig);
if isMirror
    Nmirror = Norig;
    if rem(Norig,2)
        if (Nmirror == Norig)
            x = [x(:,Nmirror:-1:1), x, x(:,end:-1:end-Nmirror+2)];
        else
            x = [x(:,Nmirror:-1:1), x, x(:,end:-1:end-Nmirror)];
        end
    else
        x = [x(:,Nmirror:-1:1), x, x(:,end:-1:end-Nmirror+1)];
    end
end

% ===== BUILD FILTER =====
% High-pass filter: apply anti-aliasing low-pass frequency cut
if isempty(LowPass) || (LowPass == 0)
    LowPass = Fs / 3;
end
% Band-stop frequencies
if isempty(stopBand)
    % Default
    HighStop = HighPass - min(2, HighPass / 2);
    LowStop = LowPass + min(10, LowPass * 0.2);
else
    % Manual
    HighStop = max(.1, HighPass - stopBand(1));
    LowStop = LowPass + stopBand(2);
end

% Construct the filter function H(f)
N = size(x,2);
Fnorm = Fs/2;
% Check filter freq vs. sampling freq
if any([LowStop, LowPass, HighStop, HighPass] > Fnorm)
    error('Cutoff frequencies are too high with respect to the sampling frequency.');
end

% Use fir2 to build the filter (Signal Processing Toolbox required)
if isFir2
    % Use the appropriate fir2 function
    if bst_get('UseSigProcToolbox')
        fir2fcn = @fir2;
    else
        fir2fcn = @oc_fir2;
    end
    % Low-pass
    if isempty(HighPass) || (HighPass == 0)
        H = fir2fcn(N-1, [0 LowPass LowStop Fnorm] ./ Fnorm, [1 1 0 0]);
%     % High-pass
%     elseif isempty(LowPass) || (LowPass == 0)
%         H = fir2fcn(N-1, [0 HighStop HighPass Fnorm] ./ Fnorm, [0 0 1 0]);
    % Band-pass
    else
        H = fir2fcn(N-1, [0 HighStop HighPass LowPass LowStop Fnorm] ./ Fnorm, [0 0 1 1 0 0]);
    end
    % Make zero-phase filter function
    H = abs(fft(H));
    % If there is a High-pass filter: remove completely the lowest frequency bin (ie. remove the average)
    if ~isempty(HighPass) && (HighPass ~= 0)
        H(1) = 0;
        H(end) = 0;
    end
% Else: cut unwanted frequencies (FFT mask)
else
    % Half size
    if (mod(N,2) == 0)
        N_2 = N/2;
    else
        % WARNING: THIS CASE IS NOT HANDLED PROPERLY
        N_2 = (N+1)/2;
    end
    % Half of the frequencies
    H = ones(1, N_2);
    if ~isempty(HighPass) && (HighPass ~= 0)
        iHighStop = max(1, round(HighStop / Fs * N));
        iHighPass = max(1, round(HighPass / Fs * N));
        H(1:iHighStop) = 0;
        if (iHighStop ~= iHighPass)
            H(iHighStop:iHighPass) = linspace(0,1,iHighPass-iHighStop+1);
        end
    end
    if ~isempty(LowPass) && (LowPass ~= 0)
        iLowStop = min(round(LowStop / Fs * N), N_2);
        iLowPass = min(round(LowPass / Fs * N), N_2);
        H(iLowStop:end) = 0;
        if (iLowStop ~= iLowPass)
            H(iLowPass:iLowStop) = linspace(1,0,iLowStop-iLowPass+1);
        end
    end
    % Symetric
    if (mod(N,2) == 0)
        H = [H, fliplr(H)];
    else
        H = [H, fliplr(H(1:end-1))];
    end
end
    
% ===== FILTER SIGNALS =====
% Filter: multiply fft of the signal by H (fft of the filter)
x = real(ifft(bst_bsxfun(@times, fft(x,[],2), H),[],2));

% Keep only the initial part
if isMirror
    x = x(:,Nmirror + (1:Norig));
end
