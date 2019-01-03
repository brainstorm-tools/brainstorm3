function [x, FiltSpec, Messages] = bst_bandpass_hfilter_cascade(x, Fs, HighPass, LowPass, isMirror, isRelax, UpTranBand, Function, Rolloff)
% BST_BANDPASS_HFILTER Linear phase FIR bandpass filter.
% 
% USAGE:  [x, FiltSpec, Messages] = bst_bandpass_hfilter_cascade(x,  Fs, HighPass, LowPass, isMirror=0, isRelax=0, UpTranBand=0.05, Function=[detect], Rolloff=[])
%         [~, FiltSpec, Messages] = bst_bandpass_hfilter_cascade([], Fs, HighPass, LowPass, isMirror=0, isRelax=0, UpTranBand=0.05, Function=[detect], Rolloff=[])
%                               x = bst_bandpass_hfilter_cascade(x,  Fs, FiltSpec)
%
% DESCRIPTION:
%    - A linear phase FIR filter is created. 
%    - High pass filter: Function "kaiserord" and "kaiser" are used to set the necessary order for fir1.
%    - Low pass filter: Function "firpmord" is used to set the necessary order for firpm.
%    - The lower transition band is hard-coded.
%    - The upper transition band is defined by user. 
%    - Requires Signal Processing Toolbox for the following functions:
%      kaiserord, kaiser, fir1, firpmord, firpm, fftfilt. If not, using "bst_bandpass_hfilter" function by Octave-based alternatives .
%
% INPUT:
%    - x          : [nChannels,nTime] input signal  (empty to only get the filter specs)
%    - Fs         : Sampling frequency
%    - HighPass   : Frequency below this value are filtered in Hz (set to 0 for low-pass filter only)
%    - LowPass    : Frequency above this value are filtered in Hz (set to 0 for high-pass filter only)
%    - isMirror   : isMirror (default = 0 no mirroring) 
%    - isRelax    : Change ripple and attenuation coefficients (default=0 no relaxation)
%    - UpTranBand : Define upper transition width where f_lowstop  = (1+UpTranBand) * f_lowpass (default = 0.05)
%    - Function   : 'fftfilt', filtering in frequency domain (default) 
%                   'filter', filtering in time domain
%                    If not specified, detects automatically the fastest option based on the filter order
%    - Rolloff    : Width of the transition band in Hz
%
% OUTPUT: 
%    - x        : Filtered signals
%    - FiltSpec : Filter specifications (coefficients, length, ...)
%    - Messages : Warning messages, if any

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Hossein Shahabi, Francois Tadel, John Mosher, Richard Leahy, 2019


%% ===== PARSE INPUTS =====
% Filter is already computed
if (nargin == 3)
    FiltSpec = HighPass;
% Default filter options
else
    if (nargin < 9) || isempty(Rolloff)
        Rolloff = [];
    end
    if (nargin < 8) || isempty(Function)
        Function = [];  % Auto-detection based on the filter order later in the code
    end
    if (nargin < 7) || isempty(UpTranBand)
        UpTranBand = 0.05;  % Default value for transition band 
    end
    if (nargin < 6) || isempty(isRelax)
        isRelax = 0;
    end
    if (nargin < 5) || isempty(isMirror)
        isMirror = 0;
    end
    FiltSpec = [];
end
Messages = [];


%% ===== CREATE FILTER =====
if isempty(FiltSpec)
    % ===== FILTER SPECIFICATIONS =====
    Nyquist = Fs/2;
    % High-pass filter
    if ~isempty(HighPass) && (HighPass ~= 0)
        f_highpass = HighPass / Nyquist;    % Change frequency from Hz to normalized scale (0-1)
        % Default transition band
        if isempty(Rolloff)
            if (HighPass <= 5)   % Relax the transition band if HighPass<5 Hz 
                f_highstop = .5 * f_highpass;
            else
                f_highstop = .85 * f_highpass;
            end
        % Specified manually
        else
            f_highstop = max(0.2, Highpass - Rolloff) / Nyquist;
        end
    else
        f_highpass = 0; 
        f_highstop = 0;
    end
    % Low-pass filter
    if ~isempty(LowPass) && (LowPass ~= 0)
        f_lowpass = LowPass / Nyquist;
        % Default transition band
        if isempty(Rolloff)
            f_lowstop  = (1+UpTranBand) * f_lowpass;
        else
            f_lowstop = min(Fs/2 - 0.2, Lowpass + Rolloff) / Nyquist;
        end
    else
        f_lowpass  = 0;
        f_lowstop  = 0;
    end
    % If both high-pass and low-pass are zero
    if (f_highpass == 0) && (f_lowpass == 0)
        Messages = ['No frequency band in input.' 10];
        return;
    % Input frequencies are too high
    elseif (f_highpass >= 1) || (f_lowpass >= 1)
        Messages = sprintf('Cannot filter above %dHz.\n', Nyquist);
        return;
    end
    % Transition parameters
    if isRelax
        Ripple = 10^(-2);   % pass band ripple
        Atten  = 10^(-2);   % Equals 40db
    else
        Ripple = 10^(-3);   % pass band ripple
        Atten  = 10^(-3);   % Equals 60db
    end

    % ===== DESIGN FILTER =====
    % Build the general case first
    fcuts = [f_highstop, f_highpass, f_lowpass, f_lowstop];
    mags  = [0 1 0];               % filter magnitudes
    devs  = [Atten Ripple Atten];  % deviations
    % Now adjust for desired properties
    fcuts = max(0,fcuts);      % Can't go below zero
    fcuts = min(1-eps, fcuts); % Can't go above or equal to 1

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
    % Using Matlab's Signal Processing toolbox
    if bst_get('UseSigProcToolbox')
        if f_lowpass == 0   %HPF (Kaiser window)
            [n,Wn,beta,ftype] = kaiserord(fcuts, mags, devs, 2);
            n = n + rem(n,2);  % ensure even order
            b = fir1(n, Wn, ftype, kaiser(n+1,beta), 'noscale');
        elseif f_highpass == 0  %LPF (Equiripple filter)
            [n,fo,ao,w] = firpmord(fcuts,mags,devs);
            b = firpm(n,fo,ao,w);
        else %BPF
            [n,Wn,beta,ftype] = kaiserord(fcuts(1:2), mags(1:2), devs(1:2), 2);
            n = n + rem(n,2);  % ensure even order
            b_HP = fir1(n, Wn, ftype, kaiser(n+1,beta), 'noscale');
            [n,fo,ao,w] = firpmord(fcuts(3:4),mags(2:3),devs(2:3));
            b_LP = firpm(n,fo,ao,w);
            b = conv(b_HP,b_LP) ; 
            n = length(b)-1 ; 
        end
    % Using Octave-based functions (Old version 2016-2018)
    else
        [x, FiltSpec, Messages] = bst_bandpass_hfilter(x, Fs, HighPass, LowPass, isMirror, isRelax, Function, Rolloff) ; 
        Messages = [Messages,'The old version of filtering (Oct 2016-18) is used in absence of the' ...
            ' Signal Processing Toolbox'] ; 
        return ; 
    end

    % Filtering function: Detect the fastest option, if not explicitely defined
    if isempty(Function)
        % The filter() function is a bit faster for low-order filters, but much slower for high-order filters
        if (n > 800)  % Empirical threshold
            Function = 'fftfilt';
        else
            Function = 'filter';
        end
    end

    % Compute the cumulative energy of the impulse response
    E = b((n/2)+1:end) .^ 2 ;  
    E = cumsum(E) ;
    E = E ./ max(E) ;
    % Compute the effective transient: Number of samples necessary for having 99% of the impulse response energy
    [tmp, iE99] = min(abs(E - 0.99)) ;

    % Output structure
    FiltSpec.b              = b;
    FiltSpec.a              = 1;
    FiltSpec.order          = n;
    FiltSpec.transient      = iE99 / Fs ;         % Start up and end transients in seconds (Effective) 
    % FiltSpec.transient_full = n / (2*Fs) ;        % Start up and end transients in seconds (Actual) 
    FiltSpec.f_highpass     = f_highpass;
    FiltSpec.f_lowpass      = f_lowpass;
    FiltSpec.fcuts          = fcuts * Nyquist ;   % Stop and pass bands in Hz (instead of normalized)
    FiltSpec.function       = Function;
    FiltSpec.mirror         = isMirror;
    % If empty input: just return the filter specs
    if isempty(x)
        return;
    end
end

%% ===== FILTER SIGNALS =====
% Transpose signal: [time,channels]
[nChan, nTime] = size(x);
% Half of filter length 
M = FiltSpec.order / 2;
% If filter length > 10% of data length
edgePercent = 2*FiltSpec.transient / (nTime / Fs);
if (edgePercent > 0.1)
    Messages = [Messages, sprintf('Start up and end transients (%.2fs) represent %.1f%% of your data.\n', 2*FiltSpec.transient, 100*edgePercent)]; 
end

% Remove the mean of the data before filtering
xmean = mean(x,2); 
x = bst_bsxfun(@minus, x, xmean); 

% Mirroring requires the data to be longer than the filter
if (FiltSpec.mirror) && (nTime < M)
    Messages = [Messages, 'Warning: Data is too short for mirroring. Option is ignored...' 10];
    FiltSpec.mirror = 0;
end
% Mirror signals
if (FiltSpec.mirror)
    x = [fliplr(x(:,1:M)), x, fliplr(x(:,end-M+1:end))];
% Zero-padding
else
    x = [zeros(nChan,M), x, zeros(nChan,M)] ;
end

% Filter signals
switch (FiltSpec.function)
    case 'fftfilt'
        if bst_get('UseSigProcToolbox')
            x = fftfilt(FiltSpec.b, x')';
        else
            x = oc_fftfilt(FiltSpec.b, x')';
        end
    case 'filter'
        x = filter(FiltSpec.b, FiltSpec.a, x, [], 2);
end

% Remove extra data
x = x(:,2*M+1:end);
% Restore the mean of the signal (only if there is no high-pass filter)
if (FiltSpec.f_highpass == 0)
    x = bst_bsxfun(@plus, x, xmean);
end

