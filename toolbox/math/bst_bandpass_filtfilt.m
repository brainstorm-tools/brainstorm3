function [x,b,a] = bst_bandpass_filtfilt(x, Fs, HighPass, LowPass, isStopBand, FilterType)
% BST_BANDPASS_FILTFILT: Bandpass filter for the signal x, using the filtfilt function (used by default after Nov 2014)
%
% USAGE:  [x,b,a] = bst_bandpass_filtfilt(x, Fs, HighPass, LowPass, isStopBand=0, FilterType='fir')
% 
% INPUT: 
%    - x          : [nChannels,nTime] signal to process
%    - Fs         : Sampling frequency
%    - HighPass   : Frequency below this value are filtered (set to 0 for low-pass filter only)
%    - LowPass    : Frequency above this value are filtered (set to 0 for high-pass filter only)
%    - isStopBand : If 1, create a stop-band filter instead of a pass-band filter
%    - FilterType : 'fir' or 'iir'
%
% OUTPUT:
%    - x   : Filtered signals
%    - b,a : Filter coefficients, as defined in all the Matlab functions
%
% DESCRIPTION: 
%    - A linear phase FIR filter is created and applied both forward and backward using filtfilt.
%    - Function "filtfilt" is used to employ the filtering "mirror" trick, and to reset automatically the group delay.
%    - Function "kaiserord" and "kaiser" are used to set the necessary order for fir1. 
%    - The transition band is hard-coded. 
%    - Requires Signal Processing Toolbox for the following functions: kaiserord, kaiser, ellipord, 
%      If not, using Octave-based alternatives

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
% Authors: John Mosher, Francois Tadel, 2014

% ===== PARSE INPUTS =====
if (nargin < 6) || isempty(FilterType)
    FilterType = 'fir';
end
if (nargin < 5) || isempty(isStopBand)
    isStopBand = 0;
end
if isempty(HighPass)
    HighPass = 0;
end
if isempty(LowPass)
    LowPass = 0;
end
% If both high-pass and low-pass are zero: return signals unaltered
if (HighPass == 0) && (LowPass == 0)
    disp('BST_BANDPASS> Error: No frequency band in input');
    return;
end


% ===== FILTER PARAMETERS =====
PASSBAND_RIPPLE = 5;    % percent pass band ripple
PASSBAND_DB     = 1;    % dB of pass band ripple
STOP_ATTEN_DB   = 40;   % dB of attenuation in the stop band
TRANSITION_BAND = 0.05; % normalized to Nyquist, the allowed transition band
% We use filtfilt, which doubles the effect (attenuation and ripple)
PASSBAND_RIPPLE = PASSBAND_RIPPLE/2;
STOP_ATTEN_DB   = STOP_ATTEN_DB/2;
% Conversion from percent
Ripple = PASSBAND_RIPPLE/100;    
% Stop band attenuation
Atten  = 10^(-STOP_ATTEN_DB/20);

% Convert frequencies to normalized form
Nyquist = Fs/2;
f_highpass = HighPass / Nyquist;
f_lowpass  = LowPass  / Nyquist;
% Reasonable digital transition band
f_highstop = f_highpass - TRANSITION_BAND; 
f_lowstop  = f_lowpass  + TRANSITION_BAND;


% ===== CREATE FILTER =====
switch FilterType
    % ===== FIR =====
    case 'fir'
        % Build the general case first
        fcuts = [f_highstop, f_highpass, f_lowpass, f_lowstop];
        % Stop-band
        if isStopBand
            mags = [1 0 1];               % filter magnitudes
            devs = [Ripple Atten Ripple]; % deviations
        % Pass-band
        else
            mags = [0 1 0];               % filter magnitudes
            devs = [Atten Ripple Atten];  % deviations
        end
        % Now adjust for desired properties
        fcuts = max(0,fcuts);     % Can't go below zero
        fcuts = min(1-eps,fcuts); % Can't go above or equal to 1
        % We have implicitly created a bandpass, but now adjust for desired filter
        if (f_lowpass == 0)  % User didn't want a lowpass
            fcuts(3:4) = [];
            mags(3) = [];
            devs(3) = [];
        end
        if (f_highpass == 0)  % User didn't want a highpass
            fcuts(1:2) = [];
            mags(1) = [];
            devs(1) = [];
        end
        % Generate FIR filter
        [n,Wn,beta,ftype] = kaiserord(fcuts,mags,devs,2);
        n = n + rem(n,2);  % ensure even order
        b = fir1(n,Wn,ftype,kaiser(n+1,beta),'noscale');
        a = 1;
        
    % ===== IIR =====
    case 'iir'
        % Stop-band
        if isStopBand
            ftype = 'stop';
            Ws = [f_highpass f_lowpass]; % the range of stopped
            Wp = [f_highstop f_lowstop]; % the transition band
        % Pass-band
        else
            ftype = 'bandpass';
            Ws = [f_highstop f_lowstop]; % the transition band
            Wp = [f_highpass f_lowpass]; % the passband
        end
        % Now handle extremes
        Ws = max(eps,Ws);   % Can't be zero or less
        Wp = max(eps,Wp);
        Ws = min(1-eps,Ws); % Can't be 1
        Wp = min(1-eps,Wp);
        % Now handle highpass or lowpass only
        if (f_lowpass == 0)  % User didn't want a lowpass
            ftype = 'high';
            Ws(2) = [];
            Wp(2) = [];
        end
        if (f_highpass == 0)  % User didn't want a highpass
            ftype = 'low';
            Ws(1) = [];
            Wp(1) = [];
        end
        % Generate IIR filter
        [n,WP] = ellipord(Wp,Ws,PASSBAND_DB,STOP_ATTEN_DB);
        [b,a]  = ellip(n,PASSBAND_DB,STOP_ATTEN_DB,WP,ftype);
end


% ===== FILTER THE DATA =====
Ntime = size(x,2);
% Remove the mean of the data before filtering, which wrecks most filters
xmean = mean(x,2);
x = bst_bsxfun(@minus, x, xmean)';    % Transposed output (time is now down the columns)
% Using filtfilt to use the mirroring trick and remove group delay
try
    x = filtfilt(b,a,x)';     % Transposed output
    
    % OCTAVE IMPLEMENTATION
    % http://octave-signal.sourcearchive.com/documentation/1.0.8/filtfilt_8m-source.html
catch 
    fprintf('Sequence too short for filtfilt, using alternate approach.\n')  
    xmirror = [flipud(x); x; flipud(x)];      % Mirror either end
    xmirror = filter(b,1,xmirror);            % Filter
    xmirror = flipud(xmirror);                % Reverse in time
    xmirror = flipud(filter(b,1,xmirror));    % Filter and flip again
    x = xmirror(Ntime + (1:Ntime),:)';        % Transposed output
end
% Restore the mean of the signal (only if there is no high-pass filter)
if (f_highpass == 0)
    x = bst_bsxfun(@plus, x, xmean);
end

    