function [x,Hd] = bst_bandpass_sos(x, fs, coef)
% BST_BANDPASS_SOS: Bandpass filter using Matlab SOS filters. 
%
% USAGE:  [x,Hd,tracks] = bst_bandpass_sos(x, fs, coef)
%         [x,Hd,tracks] = bst_bandpass_sos(x, fs)
%
% INPUTS:
%     - x    : Signals to process [nChannels x nTime]
%     - fs   : Sampling frequency of the x signal
%     - coef : Filter coefficients, strucr or class dfilt.df2sos
%              If struct, it may have the following fields: 
%               - Rp: passband ripple (default 0.1)
%               - Rs: stopband attenuation (default 80)
%               - LowPass: low pass edge (default 100)
%               - LowStop: low pass stop (default 120)
%               - HighPass: high pass edge (default 1)
%               - HighStop: high pass stop (default 1 2)
%
% OUTPUTS:
%     - x      : Filtered signals [nChannels x nTime]
%     - Hd     : dfilt.df2sos structure used to filter the data
%
% NOTE: Requires Signal Processing Toolbox

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
% Authors: John Mosher (2010), Francois Tadel (2011)

%% ===== PARSE INPUTS =====
% Filters parameters
if (nargin < 3) || isempty(coef)
    coef = struct();
end
if isstruct(coef)
    % Default values
    defCoef = struct(...
        'Rp',       .1, ...
        'Rs',       80, ... ...
        'HighPass', 2, ...
        'LowPass',  100);
    coef = struct_copy_fields(coef, defCoef, 0);
    ellip_options = [];
    % Compute high stop
    if isempty(coef.HighPass)
        coef.HighStop = [];
        ellip_options = 'low';
    elseif ~isfield(coef, 'HighStop')
        coef.HighStop = coef.HighPass - min(5, coef.HighPass / 2);
    end
    % Compute low stop
    if isempty(coef.LowPass)
        coef.LowStop = [];
        ellip_options = 'high';
    elseif ~isfield(coef, 'LowStop')
        coef.LowStop = coef.LowPass + min(20, coef.LowPass * 0.2);
    end
    Hd = [];
else
    Hd = coef;
end
[nRows, nTime] = size(x);
% Check filter freq vs. sampling freq
if any([coef.LowStop, coef.LowPass, coef.HighStop, coef.HighPass] >= fs/2)
    error('Cutoff frequencies are too high respect with the sampling frequency.');
end


%% ===== BANDPASS FILTER =====
if ~isempty(coef.HighPass) || ~isempty(coef.LowPass) 
    % === BUILD THE BANDPASS FILTER ===
    % If Hd is already a 'dfilt.df2sos' object, nothing to do
    if isempty(Hd)
        [N,Wp] = ellipord([coef.HighPass, coef.LowPass] / (fs/2), ...
                          [coef.HighStop, coef.LowStop] / (fs/2), ...
                          coef.Rp, coef.Rs);
        if isempty(ellip_options)
            [Z,P,K] = ellip(N, coef.Rp, coef.Rs, Wp);
        else
            [Z,P,K] = ellip(N, coef.Rp, coef.Rs, Wp, ellip_options);
        end
        [SOS,G] = zp2sos(Z, P, K);
        Hd = dfilt.df2sos(SOS, G);
        %freqz(Hd,fs*5,fs)
    end

    % === APPLY TUKEY WINDOW ===
%     % Length of the window to apply on the recordings: 4s or 10% of the recordings
%     DAMPFAC = min(4, 0.10*nTime/fs);
%     % Create the window: Tukey window (Hann windows on the end, boxcar in the middle)
%     Window = ones(1,nTime);  
%     % Create rising Hann window
%     lenHanning = round(min(fs*DAMPFAC + 1, nTime/2));
%     DampEnds = hanning(lenHanning)';
%     MidPt = round((length(DampEnds) +1)/2);
%     DampEnds = DampEnds(1:MidPt);  % rising Hann
%     % Suppress the ends
%     Window(1:MidPt) = DampEnds;
%     Window(end-MidPt+1:end) = DampEnds(end:-1:1);
%     % Apply windowing
%     x = bst_bsxfun(@times, x, Window);

    % === MIRROR SIGNAL ===
    % Add 4 seconds of mirrored signal before and after
    Nmirror = min(nTime, round(4*fs));
    x = [x(:,Nmirror:-1:1), x, x(:,end:-1:end-Nmirror+1)];

    % === FILTER SIGNALS ===
    % Filter the data
    x = filter(Hd, x, 2);
    % Reverse the phase
    x = filter(Hd, x(:,end:-1:1), 2);
    % Resequence correctly + keep only the central part of the signal
    %x = x(:,end:-1:1);
    x = x(:,end-Nmirror:-1:Nmirror+1);
end



