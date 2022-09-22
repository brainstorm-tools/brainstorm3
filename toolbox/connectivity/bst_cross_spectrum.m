function [S, Freq, Messages] = bst_cross_spectrum(X, Y, Fs, WinLen, Overlap, MaxFreq, ImagingKernel)
% BST_CROSS_SPECTRUM : Compute auto-spectra Sxx and Syy and cross-spectrum Sxy
%                      used to to further compute coherence metrics
%
% USAGE:  [S, freq, nFFT, Messages] = bst_cross_spectrum(Xs, Ys, Fs, WinLen, Overlap=0.5, MaxFreq=[], ImagingKernel=[])
%
% INPUTS:
%    - X      : Signals X [nSignalsX, nTimeX] or optionally empty if X=Y
%    - Y      : Signals Y [nSignalsY, nTimeY]
%    - Fs     : Sampling frequency of X and Y (in Hz)
%    - WinLen        : Length of the window used to estimate the auto- and cross-spectra
%    - Overlap       : [0-1], percentage of time overlap between two consecutive estimation windows
%    - MaxFreq       : Highest frequency of interest
%    - ImagingKernel : If not empty, calculate Syy at the source level, but not Sxy (more efficient to do it after averaging epochs).
%
% OUTPUTS:
%    - S      : Structure containing Sxx, Syy [nSignals, nFreq] and Sxy [nSignalsX, nSignalsY, nFreq].
%    - Freq   : Frequency vector of length nFreq.

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
% Authors: Sergul Aydore, Syed Ashrafulla, Guiomar Niso, 2013-2014
%          Francois Tadel, 2013-2019
%          Hossein Shahabi, 2019
%          Raymundo Cassani, 2021
%          Marc Lalancette, 2022


%% ===== INITIALIZATIONS =====
% Default options
if (nargin < 7) || isempty(ImagingKernel)
    ImagingKernel = [];
end
if (nargin < 6) || isempty(MaxFreq) || MaxFreq == 0
    MaxFreq = [];
end
if (nargin < 5) || isempty(Overlap)
    Overlap = 0.5;
end
if (nargin < 4)
    error('Invalid call.');
end
S.Sxx = [];
S.Syy = [];
S.Sxy = [];
S.nWin = [];
Freq = [];
Messages = [];

isNxN = isempty(X) || isequal(X, Y);
%% ===== Total number of windows =====
% Window length and Overlap in samples
nWinLen  = round(WinLen * Fs);
nOverlap = round(nWinLen * Overlap);
% Signals X and Y must have same nTime
if ~isNxN && ~isequal(size(X, 2), size(Y, 2))
    Messages = 'File A and File B must have the same number of samples.';
    return;
end

%% ===== COMPUTE Sxx, Syy, Sxy ======

% Elements for FFT
nFFT = 2 ^ nextpow2(nWinLen * 2);
% Window
win  = transpose(bst_window('hamming', nWinLen));
% Keep only positive frequencies of the spectra
nKeep = (nFFT / 2) + 1;
Freq = (0: nKeep-1) * (Fs / nFFT);
% Keep only upto MaxFreq
if ~isempty(MaxFreq)
    freqLim = find(Freq <= MaxFreq, 1, 'last');
    if ~isempty(freqLim)
        nKeep = freqLim;
        Freq = Freq(1:nKeep);
    end
end

% Initialize accumulators
nSignalsY = size(Y, 1);
if isNxN 
    nSignalsX = nSignalsY;
else
    nSignalsX = size(X, 1);
    S.Sxx = zeros(nSignalsX, length(Freq));
end
S.Syy = zeros(nSignalsY, length(Freq));
S.Sxy = complex(zeros(nSignalsX, nSignalsY, length(Freq)));

% Epoch into windows
[epy, S.nWin] = epoching(Y, nWinLen, nOverlap);
epy = bst_bsxfun(@times, epy, win);
% Zero padding, FFT, keep only positive frequencies
epY = fft(epy, nFFT, 2);
epY = epY(:, 1:nKeep, :);
clear Y epy;

% === NxN ===
if isNxN
    % Cross-spectrum of y (still called Sxy)
    for y1 = 1 : nSignalsY
        for y2 = y1 : nSignalsY
            %tmp = sum(epY(y1, :, :) .* conj(epY(y2, :, :)), 3);
            S.Sxy(y1, y2, :) = sum(epY(y1, :, :) .* conj(epY(y2, :, :)), 3);
            S.Sxy(y2, y1, :) = conj(S.Sxy(y1, y2, :));
        end
    end
    % (vectorized?)
    %S.Sxy = sum(bsxfun(@times, permute(epY, [1,4,2,3]), conj(permute(epY, [4,1,2,3]))), 4);

    % Auto-spectrum (PSD) of y
    for iFreq = 1:length(Freq)
        S.Syy(:, iFreq) = abs(diag(S.Sxy(:,:,iFreq)));
    end
    %S.Sxx = S.Syy;

% === 1xN ===
else
    if isempty(ImagingKernel)
        % Auto-spectrum (PSD) of y
        S.Syy = sum(epY .* conj(epY), 3);
    else
        % Auto-spectrum (PSD) of y (sources)
        epYSource = pagemtimes(ImagingKernel, epY);
        S.Syy = sum(epYSource .* conj(epYSource), 3);
    end

    % Auto-spectrum (PSD) of x
    epx = epoching(X, nWinLen, nOverlap);
    epx = bst_bsxfun(@times, epx, win);
    % Zero padding, FFT, keep only positive frequencies
    epX = fft(epx, nFFT, 2);
    epX = epX(:, 1:nKeep, :);
    clear X epx
    % Sum across epochs
    S.Sxx = sum(epX .* conj(epX), 3);

    % Compute Sxy (with loop)
    %     for ix = 1 : nSignalsX
    %         for iy = 1 : nSignalsY
    %             %tmp = sum(epX(ix, :, :) .* conj(epY(iy, :, :)), 3);
    %             S.Sxy(ix, iy, :) = sum(epX(ix, :, :) .* conj(epY(iy, :, :)), 3);
    %         end
    %     end
    % Compute Sxy (vectorized)
    S.Sxy = sum(bsxfun(@times, permute(epX, [1,4,2,3]), conj(permute(epY, [4,1,2,3]))), 4);
end

% %% ===== Project in source space =====
% if ~isempty(ImagingKernel)
%     nSourcesY = size(ImagingKernel,1);
%     bst_progress('text', sprintf('Projecting to source domain [%d>%d]...', nSignalsY, nSourcesY));
%
%     %% ===== Case 1xN =====
%     if ~isNxN
%         % Initialize Sxy in source space
%         Sxy_sources = complex(zeros(nSignalsX, nSourcesY, length(freq)));
%         % Projection for each frequency
%         for iFreq = 1:length(freq)
%             Sxy_sources(:,:,iFreq) = Sxy(:,:,iFreq) * ImagingKernel';
%         end
%         % Sxy in source space
%         Sxy = Sxy_sources;
%
%     %% ===== Case NxN =====
%     else
%         % Initialize Sxy and Syy in source space
%         Sxy_sources = complex(zeros(nSourcesY, nSourcesY, length(freq)));
%         Syy_sources = zeros(nSourcesY, length(freq));
%         % Projection for each frequency
%         for iFreq = 1:length(freq)
%             Sxy_sources(:,:,iFreq) = ImagingKernel * Sxy(:,:,iFreq) * ImagingKernel';
%             Syy_sources(:, iFreq)  = abs(diag(Sxy_sources(:,:,iFreq)));
%         end
%         % Sxy, Syy and Sxx in source space
%         Sxy = Sxy_sources;
%         Syy = Syy_sources;
%         Sxx = Syy;
%     end
%
%     clear Sxy_sources Syy_sources
% end

% Averages across number of windows
S.Sxx  = S.Sxx / S.nWin;
S.Syy  = S.Syy / S.nWin;
S.Sxy  = S.Sxy / S.nWin;
%S.ImagingKernel = ImagingKernel;
S.isNxN = isNxN;
end

function [epx, nEpochs] = epoching(x, nEpochLen, nOverlap)
% Divides the `X` provided as [nSignals, nTime] into epochs with a
% epoch length of `nEpochLen` indicated in samples, and
% an overlap of `nOverlap` samples between consecutive epochs.

% Obtain parameters of the data
[nSignals, nTime] = size(x);
% Number of epochs
nEpochs = floor( (nTime - nOverlap) / (nEpochLen - nOverlap) );
% If not enough data
if nEpochs == 0
    epx = [];
    return
end
% `markers` indicates where the epochs start
markers = ((0 : (nEpochs-1)) * (nEpochLen - nOverlap)) + 1;
epx = zeros(nSignals, nEpochLen, nEpochs, class(x));
% Divide data in epochs
for iEpoch = 1 : nEpochs
    epx(:,:,iEpoch) = x(:, markers(iEpoch) : markers(iEpoch) + nEpochLen - 1);
end
end


