function [S, nWin, Freq, Messages] = bst_xspectrum(A, B, Fs, WinLen, WinOverlap, MaxFreq, KernelB, Func)
% BST_XSPECTRUM : Compute cross-spectrum or orther function of A and B Fourier transforms
%                 used to to further compute connectivity metrics
%
% USAGE:  [S, Freq, Messages] = bst_xspectrum(A, B, Fs, WinLen, Overlap=0.5, MaxFreq=[], KernelB=[], Func)
%
% INPUTS:
%    - A       : Signals A [nSignalsA, nTimeA]
%    - B       : Signals B [nSignalsB, nTimeB] or optionally empty if A=B
%    - Fs      : Sampling frequency of A and B (in Hz)
%    - WinLen  : Length of the window used to estimate the auto- and cross-spectra
%    - WinOverlap : [0-1], percentage of time overlap between two consecutive estimation windows
%    - MaxFreq : Highest frequency of interest
%    - KernelB : If provided, project Fourier transform of B at the source level before applying functions.
%                (The reason we only have K for B is that for connectivity, kernels are only used for "1xN" type, 
%                where N is all sources. Scouts are always pre-multiplied; no atlas-based scout kernels.) 
%    - Func    : Connectivity metric, which determines terms returned in S:
%                'cohere' : Sab, Saa, Sbb (cross-spectrum and psd)  Also used for IC and LC
%                'cohere-econ' : Same but doesn't apply kernel to Sab, for efficiency.
%                'plv'    : Sab (but with "normalized" Fourier transforms, giving a "phase
%                           information cross-spectrum")  Also used for 'ciplv'
%                'pli'    : SgnImSab
%                'wpli'   : ImSab, AbsImSab
%                'dwpli'  : ImSab, AbsImSab, SqImSab
%                'xspec'  : Sab (default)
%
% OUTPUTS:
%    - S    : Structure with fields listed above, summed over windows, for computing the requested connectivity metric. 
%             Most terms, like S.Sab, have size [nSignalsA, nSignalsB, nFreq].
%    - nWin : Number of windows that were summed.
%    - Freq : Frequency vector (length nFreq).
%    - Messages : Text indicating warnings or errors that occured.
%
% Implementation notes:
% Zero frequency is not removed, though probably meaningless in general.

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
%          Raymundo Cassani, Marc Lalancette, 2021-2023


%% ===== INITIALIZATIONS =====
% Default options
if nargin < 8 || isempty(Func)
    Func = 'xspec';
end
if nargin < 7 || isempty(KernelB)
    KernelB = [];
end
if nargin < 6 || isempty(MaxFreq) || MaxFreq == 0
    MaxFreq = [];
end
if nargin < 5 || isempty(WinOverlap)
    WinOverlap = 0.5;
end
if nargin < 4 || isempty(WinLen) || isempty(Fs) || isempty(A)
    error('Invalid call.');
end
S = [];
Messages = [];

isNxN = isempty(B) || isequal(A, B);
isKern = ~isempty(KernelB);
if isNxN && isKern
    error('Conflicting inputs: A=B (not all sources) and ImagingKernel provided (all sources).');
end
% Simplify 'economy' call if no kernel actually present.
if ~isKern && strcmpi(Func, 'cohere-econ')
    Func = 'cohere';
end

%% ===== Compute Fourier transforms and prepare for window loop =====

% Window length and Overlap in samples
nWinLen  = round(WinLen * Fs);
nOverlap = round(nWinLen * WinOverlap);
nFFT = 2 ^ nextpow2(nWinLen * 2);
% Window
win  = transpose(bst_window('hamming', nWinLen));
% Keep only positive frequencies of the spectra
nFreq = (nFFT / 2) + 1;
Freq = (0: nFreq-1) * (Fs / nFFT);
% Keep only upto MaxFreq
if ~isempty(MaxFreq)
    freqLim = find(Freq <= MaxFreq, 1, 'last');
    if ~isempty(freqLim)
        nFreq = freqLim;
        Freq = Freq(1:nFreq);
    end
end

% Epoch into windows
[ep, nWin] = epoching(A, nWinLen, nOverlap);
ep = bsxfun(@times, ep, win);
% Zero padding, FFT, keep only positive frequencies
Fa = fft(ep, nFFT, 2);
Fa = Fa(:, 1:nFreq, :);
if ~isNxN
    % Signals A and B must have same nTime
    if ~isequal(size(A, 2), size(B, 2))
        Messages = 'File A and File B must have the same number of samples.';
        return;
    end
    ep = epoching(B, nWinLen, nOverlap);
    ep = bsxfun(@times, ep, win);
    Fb = fft(ep, nFFT, 2);
    Fb = Fb(:, 1:nFreq, :);
end
clear A B ep

%% ===== Initialize accumulators, and prelim computation =====
nA = size(Fa, 1);
if ~isNxN 
    if ~isKern || strcmpi(Func, 'cohere-econ')
        nB = size(Fb, 1);
    else
        % We have a kernel and not doing "economy" coherence, apply it now.
        nB = size(KernelB, 1);
        Fb = KernelB * Fb;
    end
else
    nB = nA;
end
switch Func
    case {'cohere', 'cohere-econ', 'xspec'}
        % Saa, Sbb don't need window loop thus no initialization.
        S.Sab = complex(zeros(nA, nB, nFreq));
    case {'plv', 'ciplv'}
        % Normalize Fourier transforms to use cross-spectrum formula after.
        Fa = Fa ./ abs(Fa);
        if ~isNxN
            Fb = Fb ./ abs(Fb);
        end
        S.Sab = complex(zeros(nA, nB, nFreq));
    case 'pli'
        S.SgnImSab = zeros(nA, nB, nFreq);
    case 'wpli'
        S.ImSab = zeros(nA, nB, nFreq);
        S.AbsImSab = zeros(nA, nB, nFreq);
    case 'dwpli'
        S.ImSab = zeros(nA, nB, nFreq);
        S.AbsImSab = zeros(nA, nB, nFreq);
        S.SqImSab = zeros(nA, nB, nFreq);
    otherwise
        error('Unknown metric.');
end
    
%% ===== Compute requested functions and sum over windows =====
for iWin = 1:nWin
    % All metrics use the cross-spectrum.
    if isNxN 
        Sab = bsxfun(@times, permute(Fa(:,:,iWin), [1,3,2]), conj(permute(Fa(:,:,iWin), [3,1,2])));
    else
        Sab = bsxfun(@times, permute(Fa(:,:,iWin), [1,3,2]), conj(permute(Fb(:,:,iWin), [3,1,2])));
    end
    switch Func
        case 'pli'
            S.SgnImSab = S.SgnImSab + sign(imag(Sab));
        case 'wpli'
            S.ImSab = S.ImSab + imag(Sab);
            S.AbsImSab = S.AbsImSab + abs(imag(Sab));
        case 'dwpli'
            S.ImSab = S.ImSab + imag(Sab);
            S.AbsImSab = S.AbsImSab + abs(imag(Sab));
            S.SqImSab = S.SqImSab + imag(Sab).^2;
        otherwise % plv, cohere, etc.
            S.Sab = S.Sab + Sab;
    end
end
% Parts that don't need window loop.
if ismember(Func, {'cohere', 'cohere-econ'})
    S.Saa = sum(Fa .* conj(Fa), 3);
    if ~isNxN
        if isKern && strcmpi(Func, 'cohere-econ')
            % Kernel was not applied for Sab, but needed here since we only keep the diagonal of Sbb (PSD).
            Fb = KernelB * Fb;
        end
        S.Sbb = sum(Fb .* conj(Fb), 3);
    end
end

% Dividing by number of windows can be done later.
end

function [epx, nEpochs] = epoching(x, nEpochLen, nOverlap)
    % Divides the A provided as [nSignals, nTime] into epochs with a epoch length of nEpochLen
    % indicated in samples, and an overlap of nOverlap samples between consecutive epochs.

    % Obtain parameters of the data
    [nSignals, nTime] = size(x);
    % Number of epochs
    nEpochs = floor( (nTime - nOverlap) / (nEpochLen - nOverlap) );
    % If not enough data
    if nEpochs == 0
        epx = [];
        return
    end
    % markers indicates where the epochs start
    markers = ((0 : (nEpochs-1)) * (nEpochLen - nOverlap)) + 1;
    epx = zeros(nSignals, nEpochLen, nEpochs, class(x));
    % Divide data in epochs
    for iEpoch = 1 : nEpochs
        epx(:,:,iEpoch) = x(:, markers(iEpoch) : markers(iEpoch) + nEpochLen - 1);
    end
end


