function hFig = view_mri_histogram( MriFile )
% VIEW_MRI_HISTOGRAM: Compute and view the histogram of a brainstorm MRI.
%
% USAGE:  hFig = view_mri_histogram( MriFile );
%
% INPUT:
%    - MriFile : Full path to a brainstorm MRI file
% OUTPUT:
%    - hFig    : Matlab handle to the figure where the histogram is displayed
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
% Authors: Francois Tadel, 2006-2020

%% ===== COMPUTE HISTOGRAM =====
% Display progress bar
bst_progress('start', 'View MRI historgram', 'Computing histogram...');
% Load full MRI
MRI = load(MriFile);
% Compute histogram
Histogram = mri_histogram(MRI.Cube(:,:,:,1));
% Save histogram
s.Histogram = Histogram;
bst_save(MriFile, s, 'v7', 1);


%% ===== DISPLAY HISTOGRAM =====
% Create figure
hFig = figure('Name',        'MRI Histogram', ...
              'Color',        get(0,'defaultUicontrolBackgroundColor'), ...
              'Pointer',      'arrow', ...
              'NumberTitle',  'off', ...
              'DockControls', 'off', ...
              'Menubar',      'none', ...
              'Toolbar',      'figure');
% Adapt figure size
figPos = get(hFig, 'Position');
set(hFig, 'Position', figPos+[0 0 20 40]);
% Get maximum value
maxVal = max(cat(1,Histogram.max.y));
% If a maximum value was found, used this value to limit the Y axis
if (maxVal<1)
    maxVal = max(Histogram.smoothFncY);
end
bar(Histogram.fncX + 0.5, Histogram.fncY);
% White background
hWndComponents = get(hFig, 'Children');
i = 1;
while (~isequal(get(hWndComponents(i), 'Type'), 'axes') && (i <= length(hWndComponents)))
    i = i + 1;
end
if (i > length(hWndComponents))
    return;
end
hAxes = hWndComponents(i);
set(hAxes, 'Color', [1 1 1]);
hold on;
% Plot all the curves
plot(Histogram.smoothFncX +0.5, Histogram.smoothFncY, 'r');
plot(Histogram.fncX + 0.5, Histogram.cumulFncY .* maxVal.*1.2, 'g');
plot(cat(1,Histogram.max.x), cat(1,Histogram.max.y), 'r^', 'MarkerFaceColor', 'r', 'MarkerSize', 7);
plot(cat(1,Histogram.min.x), cat(1,Histogram.min.y), 'rv', 'MarkerFaceColor', 'g', 'MarkerSize', 7);
% Define axis labels and limits
xlabel('Intensity value');
ylabel('Number of voxels');
yLimits = [0 maxVal*1.3];
ylim(yLimits);
% Display background and white matter thresholds
line([Histogram.bgLevel, Histogram.bgLevel], yLimits, 'Color','b');
line([Histogram.whiteLevel, Histogram.whiteLevel], yLimits, 'Color','y');
h = legend('MRI hist.','Smoothed hist.','Cumulative hist.','Maxima','Minima',...
    'Scalp or grey thresh.','White m thresh.');
set(h, 'FontSize',  bst_get('FigFont'), ...
       'FontUnits', 'points');

% Hide progress bar
bst_progress('stop');





