function [a, time_in, time_out, el] = test_resample(a_init, sfreq_out, sfreq_in)
% TEST_RESAMPLE: Test all the methods available in Brainstorm for resamlping.
% 
% USAGE:  test_resample(a_init, sfreq_out, sfreq_in)
%         test_resample(a_init)
%         test_resample()
%         [a, time_in, time_out, el] = test_resample();
%
% INPUT: 
%     - a_init    : Signal to resample
%                   Default: [cos(t);sin(t)], with t=-pi:.0001:pi
%     - sfreq_out : Output sampling frequency
%                   Default: 4217
%     - sfreq_in  : Initial sampling frequency
%                   Default: 5000
%
% OUTPUT:
%     - a        : Cell-array oo the resampled signals for each method
%     - time_in  : Input time vector (scalar)
%     - time_out : Resampled time vector for each method 
%     - el       : Computation time for each method

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
% Authors: Francois Tadel, 2011

% Define input signal
if (nargin < 1)
    t = -pi:.0001:pi;
    a_init = [cos(t);sin(t)];
end
if (nargin < 3)
    sfreq_in  = 5000;
    sfreq_out = 4217;
end
time_in = (1:size(a_init,2)) / sfreq_in;

% List of available methods
list_methods = {'resample', 'resample-rational', 'resample-cascade', 'interp-decimate-cascade', 'fft-spline'};

% Intialize arrays
a        = cell(1,length(list_methods));
time_out = a;
el       = a;
isFigCreated = 0;
% Loop on all the methods
for i = 1:length(list_methods)
    % Method selection
    method = list_methods{i};
    % Resample
    tic; 
    [a{i}, time_out{i}] = process_resample('Compute', a_init, time_in, sfreq_out, method); 
    el{i} = toc;
    % Plot initial signal
    if ~isFigCreated
        isFigCreated = 1;
        % Create figure: signal
        hFigSignal = figure('Name', 'Resample: signal', 'NumberTitle', 'off', 'Toolbar', 'figure', 'Units', 'normalized', 'Position', [0 0 1 1]);
        zoom on
        % Plot signal
        hAxesSignal(1) = PlotSignal(hFigSignal, 1, sprintf('Initial signal (%5.3fHz)', sfreq_in), time_in, a_init);
        % Create figure: signal
        hFigSpect(1) = figure('Name', 'Resample: |fft|', 'NumberTitle', 'off', 'Toolbar', 'figure', 'Units', 'normalized', 'Position', [0 0 1 1]);
        zoom on
        % Plot spectrum
        hAxesSpect(1) = PlotSpectrum(hFigSpect, 1, sprintf('Initial signal (%5.3fHz)', sfreq_in), sfreq_in, a_init);
    end
    % Plot resampled signal
    sfreq_out_effective = 1./diff(time_out{i}([1,2]));
    axesTitle = sprintf('%s (%5.3fHz, %3.4fs)', method, sfreq_out_effective, el{i});
    hAxesSignal(i+1) = PlotSignal(hFigSignal, i+1, axesTitle, time_out{i}, a{i});
    % Plot resampled spectrum
    hAxesSpect(i+1) = PlotSpectrum(hFigSpect, i+1, axesTitle, sfreq_out_effective, a{i});
end
% Link all axes
linkaxes(hAxesSignal);
linkaxes(hAxesSpect(2:end));


function hAxes = PlotSignal(hFig, iPlot, axesTitle, t, x)
    hAxes = subplot(2, 4, iPlot, 'Parent', hFig);
    plot(hAxes, t, x);
    title(hAxes, axesTitle);

function hAxes1 = PlotSpectrum(hFig, iPlot, axesTitle, sfreq_in, x)
    % Compute FFT
    ntime = size(x,2);
    nfft = 2^nextpow2(ntime);
    Y = fft(x',nfft)' / ntime;
    f = sfreq_in * linspace(0, 1, nfft);
    % Plot |FFT|
    hAxes1 = subplot(2, 4, iPlot, 'Parent', hFig(1));
    plot(hAxes1, f, 2 * log(max(abs(Y'),1e-5))); 
    title(hAxes1, axesTitle);

    
    
    