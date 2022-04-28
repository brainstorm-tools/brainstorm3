function F_filt = bst_freqfilter(F, freq_filter, freq_support, F_fft)
% BST_FREQFILTER: Apply a frequency filter to a signal.
%
% INPUTS:
%    - F            : [nSignals x nTime]  Signals to filter
%    - freq_filter  : [nSignals x nFreq]  Filter to apply to the signals
%    - freq_support : [1 x nFreq] List of frequencies, support of freq_filter
%    - F_fft        : Optional, FFT of the signals if already calculated

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
% Authors: Francois Tadel, 2013

% Filter signals if not available yet
if (nargin < 4) || isempty(F_fft)
    % Transform sensor time series into analytic signals
    F_fft = fft(F, length(freq_support), 2);
    % This step scales analytic signal such that: real(analytic_signal) = raw_signal
    % but note that analytic signal energy is double that of raw signal energy
    F_fft(:,freq_support<0) = 0;
    F_fft(:,freq_support>0) = 2 * F_fft(:, freq_support>0);
end

% Filter signal in frequency domain
F_fft = bst_bsxfun(@times, F_fft(:,:,ones(1,size(freq_filter,3))), freq_filter);
% Convert back to time domain
nTime = size(F,2);
F_filt = ifft(F_fft, length(freq_support), 2);
F_filt = F_filt(:, 1:nTime, :);



