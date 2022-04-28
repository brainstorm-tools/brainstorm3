function [chirpF, Freqs] = bst_chirplet(sRate, nTime, chirpCenterFreqs)
% BST_CHIRPLET: Compute the Phase-Amplitude Coupling in one of several time series (directPAC)
%
% INPUTS:
%    - sRate  : Signal sampling rate (in Hz)
%    - nTime  : Number of time points of the signal to filter
%    - chirpCenterFreqs: Center frequencies of the chirplets to calculate
%
% DOCUMENTATION:  
%    - The current code is inspired from Ryan Canolty's code provided originally with the article:
%         Canolty RT, Edwards E, Dalal SS, Soltani M, Nagarajan SS, Kirsch HE, Berger MS, Barbaro NM, Knight RT,
%         "High gamma power is phase-locked to theta oscillations in human neocortex",
%         Science, 2006 Sep 15;313(5793):1626-8.

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
% Authors: Ryan Canolty, 2006
%          Sylvain Baillet, 2011-2013
%          Francois Tadel, 2013

% ===== PARSE INPUTS =====
% To avoid out-of-memeory issues: Check this on your machine, machine-specific threshold
% ***** TODO: EVALUALATE THOSE LINES *****
if (nTime > 2^23)
    nFreq = nTime;
else
    % Fixed parameter for computational ease
    nFreq = 2^ceil(log2(nTime)); 
end
% Raw time_support
Freqs = (sRate/nFreq) * (0:nFreq-1);
inds = Freqs > (sRate/2);
Freqs(inds) = Freqs(inds) - sRate;
% Reduce storage space
% % ***** TODO: EVALUALATE THIS LINES *****
% Freqs = single(Freqs);

% ===== CALCULATE CHIRPLETS =====
% Initialize returned matrix
chirpF = zeros(1, nFreq, length(chirpCenterFreqs));
% Make set of chirplets
fbw = 0.15; 
for iif = 1:length(chirpCenterFreqs)
    % Assign or compute duration parameter
    v0 = chirpCenterFreqs(iif);  % center_frequency
    c0 = 0;  % chirp_rate
    s0 = log((2*log(2)) / (fbw^2*pi*v0^2));
    % Frequency support
    std_multiple = 6;
    vstd = sqrt((exp(-s0) + c0^2*exp(s0)) / (4*pi));
    v = Freqs; % in Hz
    iFreq = find(...
        (v0 - std_multiple * vstd <= v) & ...
        (v <= v0 + std_multiple * vstd));
    % Shorten to include only chirplet support
    v = v(iFreq);
    % Chirplet in frequency domain: 
    Gk = 2^(1/4)*sqrt(-1i*c0+exp(-s0))^-1 * exp(-s0/4 + (exp(s0)*pi*(v-v0).^2)/(-1+1i*c0*exp(s0)));
    n1 = sqrt(length(Freqs)) / norm(Gk);
    % Because of discrete sampling and different time/freq sample numbers
    Gk = n1 * Gk;  % filter
    % Report in returned structures
    chirpF(1, iFreq, iif) = Gk;
end




