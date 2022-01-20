function [a, el] = test_sin_remove(a_init, sfreq, FreqList, FreqWidth)
% TEST_SIN_REMOVE: Test all the methods available in Brainstorm for sinusoid removal.
% 
% USAGE:  test_sin_remove(a_init, sfreq, FreqList, FreqWidth)
%         test_sin_remove(FileName)
%         test_sin_remove()
%         [a, el] = test_sin_remove();
%
% INPUT: 
%     - a_init : Signal to filter
%                Default: [cos(t)+cos(t*50)*.1; sin(t)+rand(1,length(t))*.1], with t=-pi:.0001:pi
%     - FreqList  : Frequencies to remove
%
% OUTPUT:
%     - a  : Cell-array of the filtered signals for each method
%     - el : Computation time for each method
%
% EXAMPLES:
% FreqList = [60 120 180];
% FreqWidth = 1;
% test_sin_remove('SinRemoval/MedianNerve/matrix_140715_1502.mat', [], FreqList, FreqWidth);
% test_sin_remove('SinRemoval/Auditory/matrix_140715_1557.mat', [], FreqList, FreqWidth);
% test_sin_remove('SinRemoval/ECG/matrix_140716_1026.mat', [], FreqList, FreqWidth);
% test_sin_remove('SinRemoval/BoxSignals/matrix_140715_1805.mat', [], FreqList, FreqWidth);
% test_sin_remove('SinRemoval/EEG/matrix_140716_1752.mat', [], 50, FreqWidth);
% test_sin_remove('SinRemoval/EEG/matrix_140716_1754.mat', [], [60 120 240], 1.5);
% test_sin_remove('SinRemoval/EEG/matrix_140716_1756.mat', [], [60 120 180 240], 1.5);


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
% Authors: Francois Tadel, 2011-2014

% Default frequencies to remove
if (nargin < 3) || isempty(FreqList)
    FreqList = 60;
    FreqWidth = 1;
end
% Define input signal
if (nargin < 1) 
    % Define time vector
    sfreq  = 1000;
    Time = (1:5000) ./ sfreq;
    % Define signal
    t = Time*2*pi;
    a_init = 2 + cos(4*t) + cos(30*t+pi/4)*.4 + randn(1,length(t))*.05;
    FreqList = 30.0;
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
%list_methods = {'mosher_sym', 'moshermosher_extrap', 'moshermosher_sym', 'sin_removal_new', 'fieldtrip_bandstop'};
list_methods = {'moshermosher_extrap', 'fieldtrip_butter', 'iirnotch'};
                
% Intialize arrays
a  = cell(1,length(list_methods));
el = a;
isFigCreated = 0;
% Loop on all the methods
for i = 1:length(list_methods);
    try
        % Method selection
        method = list_methods{i};
        % Run procesing function
        tic;
        switch (method)
            case {'mosher', 'moshermosher', 'mosher_extrap', 'moshermosher_extrap', 'mosher_sym', 'moshermosher_sym', 'sin_removal_new'}
                a{i} = process_sin_remove('Compute', a_init, sfreq, FreqList, method); 
            case {'fieldtrip_butter', 'fieldtrip_firws'}
                a{i} = process_bandstop('Compute', a_init, sfreq, FreqList, FreqWidth, method); 
            case 'iirnotch'
                a{i} = process_notch('Compute', a_init, sfreq, FreqList); 
        end
        el{i} = toc;
        % Plot initial signal
        if ~isFigCreated
            isFigCreated = 1;
            % Create figure: signal
            hFigSignal = figure('Name', 'Notch: Signals', 'NumberTitle', 'off', 'Toolbar', 'figure', 'Units', 'normalized', 'Position', [0 0 1 1]);
            zoom on
            % Plot signal
            hAxesSignal(1) = PlotSignal(hFigSignal, 1, 'Initial signal', Time, a_init);
            % Create figure: signal
            hFigSpect(1) = figure('Name', 'Notch: PSD', 'NumberTitle', 'off', 'Toolbar', 'figure', 'Units', 'normalized', 'Position', [0 0 1 1]);
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
% Link all axes
linkaxes(hAxesSignal(ishandle(hAxesSignal)));
linkaxes(hAxesSpect(ishandle(hAxesSpect)));

% Plot a figure with everything overlayed
try
    figure('Name', 'Notch: Signal overlay', 'NumberTitle', 'off', 'Toolbar', 'figure', 'Units', 'normalized', 'Position', [0 0 1 1]);
    plot(Time, [a_init', cat(1, a{:})']);
    legend_str = {'initial'};
    for i = 1:length(a)
        legend_str{end+1} = sprintf('%s: %1.4fs', list_methods{i}, el{i});
    end
    legend(legend_str, 'Interpreter', 'none');
    zoom on
catch
end
    

function hAxes = PlotSignal(hFig, iPlot, axesTitle, Time, x)
    hAxes = subplot(2, 3, iPlot, 'Parent', hFig);
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
    hAxes1 = subplot(2, 3, iPlot, 'Parent', hFig(1));
    %plot(hAxes1, f, 2 * log(max(abs(Y'),1e-5))); 
    plot(hAxes1, f, 2 * log(abs(Y')));
    
    title(hAxes1, axesTitle, 'Interpreter', 'none');
    
    
    