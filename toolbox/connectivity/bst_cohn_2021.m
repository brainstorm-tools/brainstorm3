function [Cxy, pValues, freq, nWin, nFFT, Messages] = bst_cohn_2021(Xs, Ys, Fs, WinLen, Overlap, CohMeasure, isSymmetric, ImagingKernel, waitMax)
% BST_COHN_2021: Updated version of bst_cohn.m 
%
% USAGE:  [Gxy, freq, pValues, nWin, nFFT, Messages] = bst_cohn(X, Y, Fs, MaxFreqRes=1, Overlap=0.5, CohMeasure='mscohere', isSymmetric=0, ImagingKernel=[], waitMax=100)
%
% INPUTS:
%    - Xs      : Cell array of signals {[Nsignals1, Ntimes1], [Nsignals2, Ntimes2], ...}
%    - Ys      : Cell array of signals {[Nsignals1, Ntimes1], [Nsignals2, Ntimes2], ...}
%    - Fs      : Sampling frequency of X and Y (in Hz)
%    - nFFT    : Length of the window used to estimate the coherence (must be a power of 2 for the efficiency of the FFT)
%    - Overlap       : [0-1], percentage of time overlap between two consecutive estimation windows
%    - CohMeasure    : {'mscohere', 'icohere' , 'icohere2019', 'lcohere2019'}
%    - isSymmetric   : If 1, use an optimized method for symmetrical matrices
%    - ImagingKernel : If not empty, calculate the coherence at the source level
%    - waitMax       : Increase of the progress bar during the execution of this function
%
% CohMeasure (Definitions):
%     In Late 2019, the fft-based coherence functions were updated. The
%     lagged and Imaginary coherence have different definitions among two
%     versions. The recent changes are set as default. Please consider this
%     if you want to reproduce your former analyses. 
%     
%     Gxy:  cross-spectral density between x and y
%     Gxx:  autospectral density of x
%     Gyy:  autospectral density of y
%     Coherence function (C)            : Gxy/sqrt(Gxx*Gyy)
%     Magnitude-squared Coherence (MSC) : |C|^2 = |Gxy|^2/(Gxx*Gyy) = Gxy*conj(Gxy)/(Gxx*Gyy) 
%   
%     ============ 'icohere2019', 'lcohere2019' =============
%     Imaginary Coherence (IC)          : abs(imag(C))               
%     Lagged Coherence (LC)             : abs(imag(C))/sqrt(1-real(C)^2)
%
%     ========= 'icohere' (before 2019) =========
%     Imaginary Coherence (IC)          : imag(C)^2 / (1-real(C)^2)
%
% Parametric significance estimation:  
%     When overlap=0%   [Syed Ashrafulla]
%        Kuramaswamy's CDF using using Goodman's formula from [1], simplified by the null hypothesis as in [2]
%        => pValues = (1 - MSC) .^ floor(signalLength / windowLength)
%     
%     When overlap=50%   [Ester Florin]
%        dof = 2.8 * nSamples * (1.28/(nFFT+1));   % According to Welch 1976
%        pValues = (1 - MSC) .^ ((dof-2)/2);       % Schelter [3] and Bloomfield [4]
%        While Matlab defines the coherence as the square of the cross sepctra divided by the product of the spectra, Bokil (2007)
%        and Schelter (2006) work with the square root within the correction and significance determination
%
% References:
%   [1] Carter GC (1987), Coherence and time delay estimation
%       Proc IEEE, 75(2):236-255, doi:10.1109/PROC.1987.13723
%   [2] Amjad AM, Halliday DM, Rosenberg JR, Conway BA (1997)
%       An extended difference of coherence test for comparing and combining several independent coherence estimates: 
%       theory and application to the study of motor units and physiological tremor.
%       J Neuro Methods, 73(1):69-79
%   [3] Schelter B, Winterhalder M, Eichler M, Peifer M, Hellwig B, Guschlbauer B, Luecking CH, Dahlhaus R, Timmer J (2006)
%       Testing for directed influences among neural signals using partial directed coherence
%       J Neuro Methods, 152(1-2):201-219
%   [4] Bloomfield P, Fourier Analysis of Time Series: An Introduction
%       John Wiley & Sons, New York, 1976.

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
% Authors: Raymundo Cassani 2021, Hossein Shahabi, 2019
% Sergul Aydore, Syed Ashrafulla, Francois Tadel, Guiomar Niso, 2013-2014

%% ===== INITIALIZATIONS =====



%% ===== INITIALIZATIONS =====
% Default options
if (nargin < 9) || isempty(waitMax)
    waitMax = 100;
end
if (nargin < 8) || isempty(ImagingKernel)
    ImagingKernel = [];
end
if (nargin < 7) || isempty(isSymmetric)
    isSymmetric = 0;
end
if (nargin < 6) || isempty(CohMeasure)
    CohMeasure = 'mscohere';
end
if (nargin < 5) || isempty(Overlap)
    Overlap = 0.5;
end
if (nargin < 4)
    error('Invalid call.');
end
Cxy = [];
pValues = [];
freq = [];
Messages = [];
nWin = [];

% Get current progress bar position
% waitStart = bst_progress('get');

%% ===== Total number of windows =====
% Number of Signals 
nX = length(Xs);
nY = length(Ys);

% Window length and Overlap in samples
nWinLen  = floor(WinLen * Fs);
nOverlap = floor(nWinLen * Overlap); 

% Minimum number of windows for signals in X and signals in Y
minnWinLenX = min(cellfun('size', Xs, 2));
minnWinLenY = min(cellfun('size', Ys, 2));
minWinX = floor( (minnWinLenX - nOverlap) / (nWinLen - nOverlap));
minWinY = floor( (minnWinLenY - nOverlap) / (nWinLen - nOverlap));
minWin  = min(nX * minWinX, nY * minWinY);

% Error and Warning
minWinError = 2;
minWinWarning = 5;
% ERROR: Not enough time points
if minWin < minWinError
    nMinMessage = nWinLen * (1 - nOverlap) * (minWinError - 1);
    Messages = sprintf(['Input signals are too few (%d files) or too short (%d samples) for the requested window length (%1.2f s).\n' ...
                        'Provide 2 or more files with a duration >= %1.2f s; or 1 file with a duration >= %1.2f s.'], ...
                        min(nX, nY), min(minnWinLenX, minnWinLenY), WinLen, WinLen, nMinMessage/Fs);
    return;
% WARNING: Maybe not enough time points
elseif minWin < minWinWarning
    nMinMessage = nWinLen * (1 - nOverlap) * (minWinWarning - 1);
    Messages = sprintf(['Input signals may be too few (%d files) or too short (%d samples) for the requested window length (%1.2f s).\n' ...
                        'Recommendation: Provide 5 or more files with a duration >= %1.2f s; or 1 file with a duration >= %1.2f s.'], ...
                        min(nX, nY), min(minnWinLenX, minnWinLenY), WinLen, WinLen, nMinMessage/Fs);
end

%% ===== COMPUTE Sxx, Syy, Sxy ======
% Window
win  = transpose(bst_window('hamming', nWinLen));
nFFT = 2 ^ nextpow2(nWinLen * 2);
% Keep only positive frequencies of the spectra
nKeep = (nFFT / 2) + 1;
freq = (0: nKeep-1) * (Fs / nFFT);

%% ===== Case NxN =====
if isequal(Xs, Ys)
    nSignalsX = size(Xs{1}, 1);
    % Accumulators
    Sxx = zeros(nSignalsX, length(freq));
    Sxy = zeros(nSignalsX, nSignalsX, length(freq)); % complex
    nEpochsX = 0;
    
    for iX = 1 : nX
        % time series x [nSignals, nSamples]
        x = Xs{iX};    
        % Epoching 
        epx = bst_epoching(x, nWinLen, nOverlap);
        nEpochsX = nEpochsX + size(epx, 3);
        % Apply window
        epx = bst_bsxfun(@times, epx, win);
        % Zero padding, FFT, keep positive 
        epX = fft(epx, nFFT, 2);
        epX = epX(:, 1:nKeep, :);
        % Sum across epochs
        Sxx = Sxx + sum(epX .* conj(epX), 3);
        for ix = 1 : nSignalsX
            for iy = 1 : nSignalsX
                tmp = sum(epX(ix, :, :) .* conj(epX(iy, :, :)), 3);
                Sxy(ix, iy, :) = squeeze(Sxy(ix, iy, :)) + tmp(:);
            end
        end
    end
% Xs == Ys 
epY = epX;
nEpochsY = nEpochsX;
Sxx = permute(Sxx, [1, 3, 2]);
Syy = permute(Sxx, [2, 1, 3]);

%% ===== Case 1xX =====
else
    disp('1xN')
end

%% ===== Coherence types =====
switch CohMeasure
    % Magnitude-squared Coherence 
    case 'mscohere'
        % Coherence = |C|^2 = |Sxy|^2/(Sxx*Syy) = Sxy.*conj(Sxy)/(Sxx.*Syy)
        Sxy = abs(Sxy) .^ 2;
        Sxy = bst_bsxfun(@rdivide, Sxy, Sxx);
        Sxy = bst_bsxfun(@rdivide, Sxy, Syy);
end

% Make sure that there are no residual imaginary parts due to numerical errors
if ~isreal(Sxy)
    Sxy = abs(Sxy);
end
Cxy = Sxy;
end


