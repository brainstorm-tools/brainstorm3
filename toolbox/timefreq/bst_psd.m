function [TF, FreqVector, Nwin, Messages, TFbis] = bst_psd( F, sfreq, WinLength, WinOverlap, BadSegments, ImagingKernel, WinFunc, PowerUnits, IsRelative )
% BST_PSD: Compute the PSD of a set of signals using Welch method

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
% Authors: Francois Tadel, 2012-2017
%          Marc Lalancette, 2020
%          Pauline Amrouche, 2024

% Parse inputs
if (nargin < 9) || isempty(IsRelative)
    IsRelative = 0;
end
if (nargin < 8) || isempty(PowerUnits)
    PowerUnits = 'physical';
end
if (nargin < 7) || isempty(WinFunc)
    WinFunc = 'mean';
end
if (nargin < 6) || isempty(ImagingKernel)
    ImagingKernel = [];
end
if (nargin < 5) || isempty(BadSegments)
    BadSegments = [];
end
if (nargin < 4) || isempty(WinOverlap)
    WinOverlap = 50;
end
if (nargin < 3) || isempty(WinLength) || (WinLength == 0)
    WinLength = size(F,2) ./ sfreq;
end

Messages = '';
% Get sampling frequency
nTime = size(F,2);
% Initialize returned values
TF = [];
TFbis = [];
% Initialize frequency and number of windows
FreqVector = [];
Nwin = [];

% ===== FUNCTION ACROSS WINDOWS =====
% Backward compatibility with previous versions where winFunc could be 0 (mean) or 1 (std)
switch lower(WinFunc)
    case {0, 'mean'},     WinFunc = 'mean';
    case {1, 'std'},      WinFunc = 'std';
    case {2, 'mean+std'}, WinFunc = 'mean+std';
    otherwise,  bst_error(['Invalid window aggregating function: ' num2str(lower(WinFunc))]); return
end
computeStd = ~isempty(strfind(WinFunc,'std'));

% ===== WINDOWING =====
Lwin  = round(WinLength * sfreq);
Loverlap = round(Lwin * WinOverlap / 100);
% If window is too small
if (Lwin < 50)
    Messages = ['Time window is too small, please increase it and run the process again.' 10];
    return;
% If window is bigger than the data
elseif (Lwin > nTime)
    Lwin = size(F,2);
    Lwin = Lwin - mod(Lwin,2); % Make sure the number of samples is even
    Loverlap = 0;
    Nwin = 1;
    Messages = ['Time window is too large, using the entire recordings to estimate the spectrum.' 10];
% Else: there is at least one full time window
else
    Lwin = Lwin - mod(Lwin,2);    % Make sure the number of samples is even
    Nwin = floor((nTime - Loverlap) ./ (Lwin - Loverlap));
end
% Next power of 2 from length of signal
% NFFT = 2^nextpow2(Lwin);      % Function fft() pads the signal with zeros before computing the FT
NFFT = Lwin;                    % No zero-padding: Nfft = Ntime 
% Positive frequency bins spanned by FFT
FreqVector = sfreq / 2 * linspace(0,1,NFFT/2+1);

% ===== INITIALIZE INTERMEDIATE SUM MATRICES =====
if ~isempty(ImagingKernel)
    nChannels = size(ImagingKernel,1);
else
    nChannels = size(F,1);
end
% Sum of the FFTs for each channel and each frequency bin
S1 = zeros(nChannels, 1, NFFT/2+1);
% Sum of the squares of the FFTs for each channel and each frequency bin
if computeStd
    S2 = zeros(nChannels, 1, NFFT/2+1);
end

% ===== CALCULATE FFT FOR EACH WINDOW =====
Nbad = 0;
for iWin = 1:Nwin
    % Build indices
    iTimes = (1:Lwin) + (iWin-1)*(Lwin - Loverlap);
    % Check if this segment is outside of ALL the bad segments (either entirely before or entirely after)
    if ~isempty(BadSegments) && (~all((iTimes(end) < BadSegments(1,:)) | (iTimes(1) > BadSegments(2,:))))
        fprintf('BST> Skipping window #%d because it contains a bad segment.\n', iWin);
        Nbad = Nbad + 1;
        continue;
    end
    % Select indices
    Fwin = F(:,iTimes);
    % No need to enforce removing DC component (0 frequency).
    Fwin = bst_bsxfun(@minus, Fwin, mean(Fwin,2));
    % Apply a hamming window to signal
    Win = bst_window('hamming', Lwin)';
    WinNoisePowerGain = sum(Win.^2);
    Fwin = bst_bsxfun(@times, Fwin, Win);
    % Compute FFT
    Ffft = fft(Fwin, NFFT, 2);
    % One-sided spectrum (keep only first half)
    % (x2 to recover full power from positive and negative frequencies)
    % Scaling options
    switch PowerUnits
    % Physical units, amplitude independent of window length
        case 'physical'
            % Normalize by the window "noise power gain" and convert "per
            % freq bin (or Hz⋅s)" to "per Hz".
            TFwin = Ffft(:,1:NFFT/2+1) * sqrt(2 ./ (sfreq * WinNoisePowerGain));
            % x2 doesn't apply to first (DC) and last frequency bins.
            TFwin(:, [1,end]) = TFwin(:, [1,end]) ./ sqrt(2);
    % Normalized frequencies
        case 'normalized'
            % Normalize by the window "noise power gain".
            TFwin = Ffft(:,1:NFFT/2+1) * sqrt(2 ./ WinNoisePowerGain);
            % x2 doesn't apply to first (DC) and last frequency bins.
            TFwin(:, [1,end]) = TFwin(:, [1,end]) ./ sqrt(2);
            FreqVector = 0.5 * linspace(0,1,NFFT/2+1);
    % Pre 2020 fix:
        case 'old'
            % Issues: Factor of 2 applies to power, here it multiplies amplitude.
            % Rectangular window "noise power gain" is Lwin, but here we used Hamming.
            % Further, it should again divide the power, so would need sqrt here.
            TFwin = 2 * Ffft(:,1:NFFT/2+1) ./ Lwin;
        otherwise
            error('Unknown power spectrum units option.');
    end
    
    % Apply imaging kernel
    if ~isempty(ImagingKernel)
        TFwin = ImagingKernel * TFwin;
    end
    % Permute dimensions: time and frequency
    TFwin = permute(TFwin, [1 3 2]);
    % Convert to power
    TFwin = process_tf_measure('Compute', TFwin, 'none', 'power');
    % Convert to relative power
    if IsRelative
        TFwin = TFwin ./ sum(TFwin, 3);
    end
    % Compute sum and sum of squares
    S1 = S1 + TFwin;
    if computeStd
        S2 = S2 + TFwin.^2;
    end
end

% Correct the dividing factor if there are bad segments
if (Nbad > 0)
    Nwin = Nwin - Nbad;
end
% Compute mean and standard deviation
TFmean = S1 ./ Nwin;
if computeStd
    Var = S2 ./ Nwin - TFmean.^2;
    TFstd = sqrt(Var);
end

% Define the matrices to return
switch WinFunc
    case 'mean',     TF = TFmean; TFbis = [];
    case 'std',      TF = TFstd;  TFbis = [];
    case 'mean+std', TF = TFmean; TFbis = TFstd;
end

% Format message
if isempty(Messages)
    Messages = [Messages, sprintf('Using %d windows of %d samples each', Nwin, Lwin)];
end
