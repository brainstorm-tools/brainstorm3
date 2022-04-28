function [filtered,tracks,Sinusoids] = bst_sin_remove_new(signal, fs, Sinusoids)
% Track frequencies with desired RBW: This version directly convolves with the desired frequency.
%
% USAGE: [x,tracks] = bst_sin_removal(x, fs, Sinusoids)
%
% INPUTS:
%     - signal      : Signals to process [nChannels x nTime]
%     - fs          : Sampling frequency of the x signal
%     - Sinusoids   : Vector of sinusoids to extract, returned in tracks 
%
% OUTPUTS:
%     - filtered    : Filtered signals [nChannels x nTime]
%     - tracks      : 3D matrix of frequencies extracted
%     - Sinusoids   : corrected interfering frequencies
%
% NOTE: Requires Signal Processing Toolbox

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
% Authors: JC Mosher, 2010-2011
%          Syed Ashrafulla, 2011
%
% Revisions:
%   - Added frequency correction: finds the actual frequency of the
%     interferer given a guess within 0.5Hz
%   - Removes tracks by matched filtering: uses 1-sample DTFT
%   - Amplitude tracking: accounts for slow changes in amplitude of
%                         interferer by matched filtering as opposed to
%                         1 estimate of ampliutde

[nSignals, nTimes] = size(signal);
signalLevel = mean(signal,2);
signal = signal - signalLevel(:,ones(1,nTimes)); % Remove mean temporarily
Sinusoids = Sinusoids(:);
nTracks = length(Sinusoids);

% Set up timepoints for matched filter
t = ((0:nTimes-1)/fs)';
timeMatch = [(t - nTimes/fs); t; (t + nTimes/fs)];

% Find actual frequency given approximate start for each signal
% tic
tolerance = -0.5:0.001:0.5;
delta = tolerance(ones(nTracks,1), :) + Sinusoids(:, ones(length(tolerance),1));
delta = delta'; delta = delta(:)';
% p = reshape(abs(signal * exp(1i*2*pi*t*delta)), nSignals, length(tolerance), nTracks);
% testSignal = signal(1:5,:);
% p = reshape(abs(testSignal * exp(1i*2*pi*t*delta)), 5, length(tolerance), nTracks);
% [tmp, idx] = max(p, [], 2);
testSignal = signal(1,:);
p = reshape(abs(testSignal * exp(1i*2*pi*t*delta)), length(tolerance), nTracks);
[tmp, idx] = max(p);
% disp(['Time to find interfering frequency: ' sprintf('%0.4f', toc) 's']);

% The artifact is common to all sensors at the same frequency, so taking
% the mean will get the most accurate frequency of the real signal
% corrected = tolerance(squeeze(idx)) + repmat(Sinusoids', nSignals, 1);
% corrected = tolerance(squeeze(idx)) + repmat(Sinusoids', 5, 1);
% Sinusoids = median(corrected);
Sinusoids = tolerance(squeeze(idx)) + Sinusoids';

% Pre-allocate
filterBank = cos(2*pi*timeMatch*Sinusoids);
NFFT = 2^nextpow2(nTimes*2);
% freq = fs/2 * linspace(-1,1,NFFT);

% For each matched filter ...
% tic
% tracks = zeros(nTracks, nSignals, nTimes);
% for n = 1:nTracks
%     % ... get the matched component
% %     est = filter( ...
% %       squeeze(filterBank(:,n)) ... % Filter for nth sinusoid
% %       , 1, s').*2./nTimes; % Filter = convolution
%     est = real(ifft( ...
%       fft(signal', NFFT)/NFFT ...
%       .* ...
%       fft(filterBank(:,n*ones(nSignals,1)), NFFT)/NFFT ...
%       , NFFT))*NFFT*5.5;
%     tracks(n,:,:) = est(nTimes + (1:nTimes), :)'; % Discard first samples
% end
% disp(['Time to find tracks in a loop: ' sprintf('%0.4f', toc) 's']);

% tic
signalFFT = fft(signal', NFFT)/nTimes; % Signal FFT for convolution
filterBankFFT = fft(filterBank, NFFT)/nTimes; % Sinusoid FFT for convolution
tracks = real(ifft( ...
  permute(signalFFT(:,:,ones(nTracks,1)), [1 3 2]) ...
  .* ...
  filterBankFFT(:,:,ones(nSignals,1)) ...
  ))*nTimes*2; % Performs convolution in frequency domain
tracks = shiftdim(tracks(nTimes + (1:nTimes), :, :), 1);
% disp(['Time to find tracks by vectorization: ' sprintf('%0.4f', toc) 's']);

% Subtract out all components
filtered = signal - squeeze(sum(tracks, 1));
filtered = filtered + signalLevel(:, ones(1,nTimes));


