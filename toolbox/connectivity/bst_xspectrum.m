function [S, Freq, Messages] = bst_xspectrum(X, Y, Fs, WinLen, Overlap, MaxFreq, ImagingKernel, SFunc)
% BST_XSPECTRUM : Compute cross-spectrum or orther function of X and Y Fourier transforms
%                 used to to further compute connectivity metrics
%
% USAGE:  [S, freq, nFFT, Messages] = bst_xspectrum(Xs, Ys, Fs, WinLen, Overlap=0.5, MaxFreq=[], ImagingKernel=[], SFunc)
%
% INPUTS:
%    - X      : Signals X [nSignalsX, nTimeX] or optionally empty if X=Y
%    - Y      : Signals Y [nSignalsY, nTimeY]
%    - Fs     : Sampling frequency of X and Y (in Hz)
%    - WinLen        : Length of the window used to estimate the auto- and cross-spectra
%    - Overlap       : [0-1], percentage of time overlap between two consecutive estimation windows
%    - MaxFreq       : Highest frequency of interest
%    - ImagingKernel : If provided, project Fourier transform of Y at the source level before applying functions.
%    - SFunc  : Structure containing functions of 2 or 3 variables: Fourier transforms of X and Y, and optionally the imaging Kernel.
%               Default is cross-spectrum and auto-spectra (PSD): Sxx, Syy [nSignals, nFreq] and Sxy [nSignalsX, nSignalsY, nFreq],
%               where ImagingKernel is only applied to Syy, since it can be applied directly to Sxy after averaging.
%
% OUTPUTS:
%    - S      : Structure containing requested functions.
%    - Freq   : Frequency vector (length nFreq).

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
    % Trick to apply kernel as 3rd input when empty and SFunc expects only 2 inputs.
    ImagingKernel = {};
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
S = [];
Messages = [];

isNxN = isempty(X) || isequal(X, Y);

% Default functions
if (nargin < 7) || isempty(SFunc)
    SFunc.Syy = @(Fx,Fy,Ky) (Ky * Fy) .* conj((Ky * Fy));
    if isNxN
        % Not applying kernel on purpose here, for efficiency.
        SFunc.Sxy = @(Fx,Fy,Ky) bsxfun(@times, permute(Fy, [1,3,2]), conj(permute(Fy, [3,1,2])));
    else
        SFunc.Sxx = @(Fx,Fy,Ky) Fx .* conj(Fx);
        % Not applying kernel on purpose here, for efficiency.
        SFunc.Sxy = @(Fx,Fy,Ky) bsxfun(@times, permute(Fx, [1,3,2]), conj(permute(Fy, [3,1,2])));
    end
end
% Prepare functions
FuncNames = fieldnames(SFunc);
nFunc = numel(FuncNames);

%% ===== Compute Fourier transforms and prepare for window loop ======

% Window length and Overlap in samples
nWinLen  = round(WinLen * Fs);
nOverlap = round(nWinLen * Overlap);
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

% Epoch into windows
[ep, S.nWin] = epoching(Y, nWinLen, nOverlap);
ep = bst_bsxfun(@times, ep, win);
% Zero padding, FFT, keep only positive frequencies
Fy = fft(ep, nFFT, 2);
Fy = Fy(:, 1:nKeep, :);
if ~isNxN
    % Signals X and Y must have same nTime
    if ~isequal(size(X, 2), size(Y, 2))
        Messages = 'File A and File B must have the same number of samples.';
        return;
    end
    ep = epoching(X, nWinLen, nOverlap);
    ep = bst_bsxfun(@times, ep, win);
    Fx = fft(ep, nFFT, 2);
    Fx = Fx(:, 1:nKeep, :);
end
clear X Y ep

%% ===== Compute requested functions and sum over windows ======
for iWin = 1:S.nWin
    for iF = 1:nFunc
        if iWin == 1
            % Initialize accumulators (unknown sizes so use result from first window)
            if isNxN
                S.(FuncNames{iF}) = SFunc.(FuncNames{iF})([], Fy(:,:,iWin), ImagingKernel);
            else
                S.(FuncNames{iF}) = SFunc.(FuncNames{iF})(Fx(:,:,iWin), Fy(:,:,iWin), ImagingKernel);
            end
        else
            if isNxN
                S.(FuncNames{iF}) = S.(FuncNames{iF}) + SFunc.(FuncNames{iF})([], Fy(:,:,iWin), ImagingKernel);
            else
                S.(FuncNames{iF}) = S.(FuncNames{iF}) + SFunc.(FuncNames{iF})(Fx(:,:,iWin), Fy(:,:,iWin), ImagingKernel);
            end
        end
    end
end

% Averages across number of windows can be done later.
% for iF = 1:nFunc
%     S.(FuncNames{iF}) = S.(FuncNames{iF}) / S.nWin;
% end
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


