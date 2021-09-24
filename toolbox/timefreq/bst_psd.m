function [TF, FreqVector, Nwin, Messages] = bst_psd( F, sfreq, WinLength, WinOverlap, BadSegments, ImagingKernel, isVariance, PowerUnits )
% BST_PSD: Compute the PSD of a set of signals using Welch method

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
% Authors: Francois Tadel, 2012-2017
%          Marc Lalancette, 2020

% Parse inputs
if (nargin < 8) || isempty(PowerUnits)
    PowerUnits = 'physical';
end
if (nargin < 7) || isempty(isVariance)
    isVariance = 0;
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
FreqVector = [];
Nwin = [];
Var = [];

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


% ===== CALCULATE FFT FOR EACH WINDOW =====
Nbad = 0;
for iWin = 1:Nwin
    % Build indices
    iTimes = (1:Lwin) + (iWin-1)*(Lwin - Loverlap);
    % Check if this segment is outside of ALL the bad segments (either entirely before or entirely after)
    if ~isempty(BadSegments) && (~all((iTimes(end) < BadSegments(1,:)) | (iTimes(1) > BadSegments(2,:))))
        disp(sprintf('BST> Skipping window #%d because it contains a bad segment.', iWin));
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
    % (x2 to recover full power from negative frequencies)
    % Scaling options
    switch PowerUnits
    % Physical units, amplitude independent of window length
        case 'physical'
            % Normalize by the window "noise power gain" and convert "per
            % freq bin (or Hz⋅s)" to "per Hz".
            TFwin = Ffft(:,1:NFFT/2+1) * sqrt(2 ./ (sfreq * WinNoisePowerGain));
            % x2 doesn't apply to DC and Nyquist.
            TFwin(:, [1,end]) = TFwin(:, [1,end]) ./ sqrt(2);
    % Normalized frequencies
        case 'normalized'
            % Normalize by the window "noise power gain".
            TFwin = Ffft(:,1:NFFT/2+1) * sqrt(2 ./ WinNoisePowerGain);
            % x2 doesn't apply to DC and Nyquist.
            TFwin(:, [1,end]) = TFwin(:, [1,end]) ./ sqrt(2);
            FreqVector = 0.5 * linspace(0,1,NFFT/2+1);
    % Pre 2020 fix:
        case 'old'
            % Issues: Factor of 2 applies to power, here it multiplies
            % amplitude. Rectangular window "noise power gain" is Lwin, but
            % here we used Hamming.  Further, it would again divide the
            % power, so would need sqrt here.
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
    
    
%     %%%%% OLD VERSION: MEAN ONLY %%%%%
%     % Add PSD of the window to the average
%     if isempty(TF)
%         TF = TFwin ./ Nwin;
%     else
%         TF = TF + TFwin ./ Nwin;
%     end
%     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %%%%% NEW VERSION: MEAN AND STD %%%%%
    % If file is first of the list: Initialize returned matrices
    if isempty(TF)
        TF = zeros(size(TFwin));
        if isVariance
            Var = zeros(size(TFwin));
        end
    end
    % Compute mean and standard deviation
    TFwin = TFwin - TF;
    R = TFwin ./ iWin;
    if isVariance
        Var = Var + TFwin .* R .* (iWin-1);
    end
    TF = TF + R;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end

% Convert variance to standard deviation
if isVariance
    Var = Var ./ (Nwin - 1);
    TF = sqrt(Var);
end

% Correct the dividing factor if there are bad segments
if (Nbad > 0)
    % TF = TF .* (Nwin ./ (Nwin - Nbad));   % OLD VERSION
    Nwin = Nwin - Nbad;
end
% Format message
if isempty(Messages)
    Messages = [Messages, sprintf('Using %d windows of %d samples each', Nwin, Lwin)];
end
