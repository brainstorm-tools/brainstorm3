function [Cxy, pValues, freq, nWin, nFFT, Messages] = bst_cohn_2021(Xs, Ys, Fs, WinLen, Overlap, CohMeasure, isSymmetric, ImagingKernel, waitMax)
% BST_COHN_2021: Updated version of bst_cohn.m 
%
% USAGE:  [Cxy, freq, pValues, nWin, nFFT, Messages] = bst_cohn_2021(Xs, Ys, Fs, WinLen, Overlap=0.5, CohMeasure='mscohere', isSymmetric=0, ImagingKernel=[], waitMax=100)
%
% INPUTS:
%    - Xs      : Cell array of signals {[nSignals1, nSamples1], [nSignals2, nSamples2], ...}
%    - Ys      : Cell array of signals {[nSignals1, nSamples1], [nSignals2, nSamples2], ...}
%    - Fs      : Sampling frequency of X and Y (in Hz)
%    - WinLen        : Length of the window used to estimate the coherence
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
%     Cxy:  cross-spectral density between x and y
%     Cxx:  autospectral density of x
%     Cyy:  autospectral density of y
%     Coherence function (C)            : Cxy/sqrt(Cxx*Cyy)
%     Magnitude-squared Coherence (MSC) : |C|^2 = |Cxy|^2/(Cxx*Cyy) 
%                                               = Cxy*conj(Cxy)/(Cxx*Cyy) 
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
% Authors: Sergul Aydore, Syed Ashrafulla, Guiomar Niso, 2013-2014
%          Francois Tadel, 2013-2019
%          Hossein Shahabi, 2019
%          Raymundo Cassani, 2021


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
nWin = 0;
nFFT = [];
Messages = [];

% Get current progress bar position
waitStart = bst_progress('get');

%% ===== Total number of windows =====
% Number of Files
nFiles = length(Xs);
% Window length and Overlap in samples
nWinLen  = round(WinLen * Fs);
nOverlap = round(nWinLen * Overlap);
% Pair files in Xs and Ys must have same nSamples  
nSamplesXs = cellfun('size', Xs, 2);
nSamplesYs = cellfun('size', Ys, 2);
if ~isequal(nSamplesXs, nSamplesYs)
    Messages = 'Pairs of Files A and Files B must have the same number of samples.';
    return;
end
% Minimum number of windows for signals in X and signals in Y
minWin = nFiles * floor( (min(nSamplesXs) - nOverlap) / (nWinLen - nOverlap));

% Error and Warning
minWinError = 2;
minWinWarning = 5;
% ERROR: Not enough time points
if minWin < minWinError
    nMinMessage = nWinLen + (nWinLen - nOverlap) * (minWinError - 1);
    Messages = sprintf(['Input signals are too few (%d files) or too short (%d samples) for the requested window length (%1.2f s).\n' ...
                        'Provide 2 or more files with a duration >= %1.2f s; or 1 file with a duration >= %1.2f s.'], ...
                        nFiles, min(nSamplesXs), WinLen, WinLen, nMinMessage/Fs);
    return;
% WARNING: Maybe not enough time points
elseif minWin < minWinWarning
    nMinMessage = nWinLen + (nWinLen - nOverlap) * (minWinWarning - 1);
    Messages = sprintf(['Input signals may be too few (%d files) or too short (%d samples) for the requested window length (%1.2f s).\n' ...
                        'Recommendation: Provide 5 or more files with a duration >= %1.2f s; or 1 file with a duration >= %1.2f s.'], ...
                        nFiles, min(nSamplesXs), WinLen, WinLen, nMinMessage/Fs);
end

%% ===== COMPUTE Sxx, Syy, Sxy ======
% [NxN] or [1xN]
isNxN = isequal(Xs, Ys);

% Elements for FFT
nFFT = 2 ^ nextpow2(nWinLen * 2);
% Window
win  = transpose(bst_window('hamming', nWinLen)); 
% Keep only positive frequencies of the spectra
nKeep = (nFFT / 2) + 1;
freq = (0: nKeep-1) * (Fs / nFFT);

% Accumulators
nSignalsX = size(Xs{1}, 1);
nSignalsY = size(Ys{1}, 1);
Sxx = zeros(nSignalsX, length(freq));
if ~isNxN  
    if isempty(ImagingKernel)
        Syy = zeros(nSignalsY, length(freq));
    else
        Syy = zeros(size(ImagingKernel,1), length(freq));
    end
end
Sxy = complex(zeros(nSignalsX, nSignalsY, length(freq)));
nWin = 0;

for iFile = 1 : nFiles
    bst_progress('set', round(waitStart + iFile/nFiles * 0.80 * waitMax));
    %% ===== Compute Syy =====
    y = Ys{iFile};    
    epy = epoching(y, nWinLen, nOverlap);
    epy = bst_bsxfun(@times, epy, win);
    % Zero padding, FFT, keep only positive frequencies
    epY = fft(epy, nFFT, 2);
    epY = epY(:, 1:nKeep, :);
    clear y epy;
    if ~isNxN
        if isempty(ImagingKernel)
            % Auto-spectrum (PSD) of y
            Syy = Syy + sum(epY .* conj(epY), 3);
        else
            % Auto-spectrum (PSD) of y (sources)
            epYSource = pagemtimes(ImagingKernel, epY);
            Syy = Syy + sum(epYSource .* conj(epYSource), 3);
        end   
    else
        % Cross-spectrum of y, needed in NxN case, or when Imagingkernel
        for y1 = 1 : nSignalsY
            for y2 = y1 : nSignalsY
                tmp = sum(epY(y1, :, :) .* conj(epY(y2, :, :)), 3);
                Sxy(y1, y2, :) = squeeze(Sxy(y1, y2, :)) + tmp(:);
                Sxy(y2, y1, :) = conj(Sxy(y1, y2, :));
            end
        end        
    end
    nWin = nWin + size(epY, 3);

    %% ===== Case 1xN =====
    if ~isNxN
        %% ===== Compute Sxx =====
        x = Xs{iFile};
        epx = epoching(x, nWinLen, nOverlap);
        epx = bst_bsxfun(@times, epx, win);
        % Zero padding, FFT, keep only positive frequencies
        epX = fft(epx, nFFT, 2);
        epX = epX(:, 1:nKeep, :);
        clear x epx
        % Sum across epochs
        Sxx = Sxx + sum(epX .* conj(epX), 3);
        
        %% ===== Compute Sxy ===== (with loop)
        for ix = 1 : nSignalsX
            for iy = 1 : nSignalsY
                tmp = sum(epX(ix, :, :) .* conj(epY(iy, :, :)), 3);
                Sxy(ix, iy, :) = squeeze(Sxy(ix, iy, :)) + tmp(:);
            end
        end        
%         %% ===== Compute Sxy ===== (vectorized)
%         Sxy2 = complex(zeros(nSignalsX, nSignalsY, length(freq)));
%         Sxy_tmp = complex(ones(nSignalsX, nSignalsY, length(freq), size(epy, 3)));
%         epX_tmp = permute(epX, [1,4,2,3]);
%         epY_tmp = permute(epY, [4,1,2,3]);
%         Sxy_tmp = bst_bsxfun(@times, Sxy_tmp, epX_tmp);
%         Sxy_tmp = bst_bsxfun(@times, Sxy_tmp, conj(epY_tmp));
%         Sxy2 = Sxy2 + sum(Sxy_tmp, 4); 
    end
end

%% ===== Case NxN =====
if isNxN
    % Auto-spectrum (PSD) of y
    Syy = zeros(nSignalsY, length(freq));
    for iFreq = 1:length(freq) 
        Syy(:, iFreq) = abs(diag(Sxy(:,:,iFreq)));
    end
    Sxx = Syy;
end

%% ===== Project in source space =====
if ~isempty(ImagingKernel)  
    nSourcesY = size(ImagingKernel,1);
    bst_progress('text', sprintf('Projecting to source domain [%d>%d]...', nSignalsY, nSourcesY));
    
    %% ===== Case 1xN =====
    if ~isNxN             
        % Initialize Sxy and Syy in source space
        Sxy_sources = complex(zeros(nSignalsX, nSourcesY, length(freq)));
        % Projection for each frequency
        for iFreq = 1:length(freq)
            Sxy_sources(:,:,iFreq) = Sxy(:,:,iFreq) * ImagingKernel';
        end
        % Sxy in source space
        Sxy = Sxy_sources;
    
    %% ===== Case NxN =====
    else 
        % Initialize Sxy and Syy in source space
        Sxy_sources = complex(zeros(nSourcesY, nSourcesY, length(freq)));
        Syy_sources = zeros(nSourcesY, length(freq));
        % Projection for each frequency
        for iFreq = 1:length(freq)
            Sxy_sources(:,:,iFreq) = ImagingKernel * Sxy(:,:,iFreq) * ImagingKernel';
            Syy_sources(:, iFreq)  = abs(diag(Sxy_sources(:,:,iFreq)));
        end
        % Sxy, Syy and Sxx in source space
        Sxy = Sxy_sources;
        Syy = Syy_sources;
        Sxx = Syy;       
    end
    
    clear Sxy_sources Syy_sources
end

% Averages across number of windows
Sxx = Sxx / nWin;
Syy = Syy / nWin;
Sxy = Sxy / nWin;

%% ===== Coherence types =====
bst_progress('set', round(waitStart + 0.90 * waitMax));
% Add dimension to use bsxfunc(@rdivide)
Sxx = permute(Sxx, [1, 3, 2]); % [nSignalsX or nSourcesX, 1, nKeep]
Syy = permute(Syy, [3, 1, 2]); % [1, nSignalsY or nSourcesY, nKeep]
Cxy = Sxy; clear Sxy

% Coherency or complex coherence Cxy = Sxy ./ sqrt(Sxx*Syy)  
Cxy = bst_bsxfun(@rdivide, Cxy, sqrt(Sxx));
Cxy = bst_bsxfun(@rdivide, Cxy, sqrt(Syy));
switch CohMeasure   
    % Magnitude-squared Coherence 
    case 'mscohere'
        % MSC = |C|^2 = C .* conj(C) = |Sxy|^2/(Sxx*Syy)
        Cxy = Cxy .* conj(Cxy);       
    
    % Imaginary Coherence (2019)
    case {'icohere2019'} 
        % IC = Im(C) = Im(Sxy)/sqrt(Sxx*Syy)
        Cxy = abs(imag(Cxy));
    
    % Lagged Coherence (2019)
    case 'lcohere2019'
        % LC = Im(C)/sqrt(1-[Re(C)]^2) = Im(Sxy)/sqrt(Sxx*Syy - [Re(Sxy)]^2)
        Cxy = abs(imag(Cxy)) ./ sqrt(1-real(Cxy).^2);
        
    % Imaginary Coherence (before 2019)
    case 'icohere' % (We only had Imaginary coherence)
        % Parametric estimation of the significance level
        if (Overlap == 0.5)
            pValues = max(0, 1 - abs(Cxy).^2) .^ ((dof-2)/2);  % Schelter 2006 and Bloomfield 1976
        else
            pValues = max(0, 1 - abs(Cxy).^2) .^ floor(nSamples / nFFT);
        end
        % Imaginary Coherence = imag(C)^2 / (1-real(C)^2)
        Cxy = imag(Cxy).^2 ./ (1-real(Cxy).^2);
end

% Make sure that there are no residual imaginary parts due to numerical errors
if ~isreal(Cxy)
    Cxy = abs(Cxy);
end
bst_progress('set', round(waitStart + 0.95 * waitMax));

end

function epx = epoching(x, nEpochLen, nOverlap)
    % Divides the `X` provided as [nSignals, nSamples] into epochs with a 
    % epoch length of `nEpochLen` indicated in samples, and 
    % an overlap of `nOverlap` samples between consecutive epochs.

    % Obtain parameters of the data
    [nSignals, nSamples] = size(x);
    % Number of epochs
    nEpochs = floor( (nSamples - nOverlap) / (nEpochLen - nOverlap) );
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


