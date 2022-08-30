function [a, el] = test_bandpass(a_init, sfreq, HighPass, LowPass)
% TEST_BANDPASS: Test all the methods available in Brainstorm for frequency filtering.
% 
% USAGE:  test_bandpass(a_init, sfreq, HighPass, LowPass)
%         test_bandpass(FileName)
%         test_bandpass()
%         [a, el] = test_bandpass();
%
% INPUT: 
%     - a_init   : Signal to filter
%     - HighPass : High-pass filter
%     - LowPass  : Low-pass filter
%
% OUTPUT:
%     - a  : Cell-array oo the filtered signals for each method
%     - el : Computation time for each method
%
% EXAMPLES:
% HighPass = 0.5;
% LowPass  = 40;
% test_bandpass('SinRemoval/MedianNerve/matrix_140715_1502.mat', [], HighPass, LowPass);
% test_bandpass('SinRemoval/Auditory/matrix_140715_1557.mat', [], HighPass, LowPass);
% test_bandpass('SinRemoval/ECG/matrix_140716_1026.mat', [], HighPass, LowPass);
% test_bandpass('SinRemoval/BoxSignals/matrix_140715_1805.mat', [], HighPass, LowPass);
% test_bandpass('SinRemoval/EEG/matrix_140716_1752.mat', [], HighPass, LowPass);
% test_bandpass('SinRemoval/EEG/matrix_140716_1754.mat', [], HighPass, LowPass);
% test_bandpass('SinRemoval/EEG/matrix_140716_1756.mat', [], HighPass, LowPass);

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
% Authors: Francois Tadel, 2011-2016

% Define input signal
if (nargin < 1)
    % Define time vector
    sfreq  = 1000;
    Time = (1:5000) ./ sfreq;
    % Define signal
    t = Time*2*pi;
    a_init = 2 + cos(4*t) + cos(30*t+1)*.4 + randn(1,length(t))*.05;
    HighPass = 1.5;
    LowPass  = 20;
% Read input file
elseif ischar(a_init)
    FileName = a_init;
    [sMatrix, matname] = in_bst(FileName);
    a_init = sMatrix.(matname);
    a_init = a_init(1,:);
    Time = sMatrix.Time;
    sfreq = 1./(Time(2) - Time(1));
else
    Time = (1:size(a_init,2)) / sfreq;
end
% List of available methods
list_methods = {'bst-hfilter-2019', 'bst-hfilter-2016', 'bst-fft', 'bst-fft-fir', 'bst-filtfilt-fir', 'bst-filtfilt-iir', 'bst-sos'};
% Intialize arrays
a  = cell(1,length(list_methods));
el = a;
isFigCreated = 0;
% Loop on all the methods
for i = 1:length(list_methods)
    try
        % Method selection
        method = list_methods{i};
        % Resample
        tic;
        a{i} = process_bandpass('Compute', a_init, sfreq, HighPass, LowPass, method, 0, 0); 
        el{i} = toc;
        % Plot initial signal
        if ~isFigCreated
            isFigCreated = 1;
            % Create figure: signal
            hFigSignal = figure('Name', 'Filter: signal', 'NumberTitle', 'off', 'Toolbar', 'figure', 'Units', 'normalized', 'Position', [0 0 1 1]);
            zoom on
            % Plot signal
            hAxesSignal(1) = PlotSignal(hFigSignal, 1, 'Initial signal', Time, a_init);
            % Create figure: signal
            hFigSpect(1) = figure('Name', 'Filter: |fft|', 'NumberTitle', 'off', 'Toolbar', 'figure', 'Units', 'normalized', 'Position', [0 0 1 1]);
            zoom on
            % Plot spectrum
            hAxesSpect(1) = PlotSpectrum(hFigSpect, 1, sprintf('Initial signal'), sfreq, a_init);
        end
        % Plot resampled signal
        axesTitle = sprintf('%s (%3.4fs)', method, el{i});
        hAxesSignal(i+1) = PlotSignal(hFigSignal, i+1, axesTitle, Time, a{i});
        % Plot resampled spectrum
        hAxesSpect(i+1) = PlotSpectrum(hFigSpect, i+1, axesTitle, sfreq, a{i});
    catch
        disp(['Method "' method '" crashed.']);
    end
end
% Keep only the valid handles
hAxesSignal = hAxesSignal(ishandle(hAxesSignal));
hAxesSpect = hAxesSpect(ishandle(hAxesSpect));
% Get max YLim: Signals
maxYLim = get(hAxesSignal, 'YLim');
YLim = [min([maxYLim{:}]), max([maxYLim{:}])];
set(hAxesSignal(1), 'YLim', YLim);
% Get max YLim: Spectrum
maxYLim = get(hAxesSpect, 'YLim');
YLim = [min([maxYLim{:}]), max([maxYLim{:}])];
set(hAxesSpect(1), 'YLim', YLim);
% Link all the axes
linkaxes(hAxesSignal);
linkaxes(hAxesSpect);


% Plot a figure with everything overlayed
try
    figure('Name', 'Notch: Signal overlay', 'NumberTitle', 'off', 'Toolbar', 'figure', 'Units', 'normalized', 'Position', [0 0 1 1]);
    plot([a_init', cat(1, a{:})']);
    legend_str = {'initial'};
    for i = 1:length(a)
        legend_str{end+1} = sprintf('%s: %1.4fs', list_methods{i}, el{i});
    end
    legend(legend_str, 'Interpreter', 'none');
    zoom on
catch
end
    

function hAxes = PlotSignal(hFig, iPlot, axesTitle, Time, x)
    hAxes = subplot(2, 4, iPlot, 'Parent', hFig);
    plot(hAxes, Time, x);
    title(hAxes, axesTitle, 'Interpreter', 'none');

function hAxes1 = PlotSpectrum(hFig, iPlot, axesTitle, sfreq, x)
    % FFT
    if 0
        ntime = size(x,2);
        nfft = 2^nextpow2(ntime);
        Y = fft(x',nfft)' / ntime;
        f = sfreq * linspace(0, 1, nfft);
    % PSD
    else
        WinLength = max(length(x)/sfreq/10, 5);
        [Y, f] = bst_psd(x, sfreq, WinLength, 50 );
        Y = reshape(Y,1,[]);
    end
    % Plot PSD
    hAxes1 = subplot(2, 4, iPlot, 'Parent', hFig(1));
    %plot(hAxes1, f, 2 * log(max(abs(Y'),1e-5))); 
    plot(hAxes1, f, 2 * log(abs(Y')));
    
    title(hAxes1, axesTitle, 'Interpreter', 'none');
    
    
