function hFig = view_mri_histogram( MriFile, isInteractive )
% VIEW_MRI_HISTOGRAM: Compute and view the histogram of a brainstorm MRI.
%
% USAGE:  hFig = view_mri_histogram(MriFile, isInteractive=false);
%
% INPUT:
%    - MriFile : Full path to a brainstorm MRI file
%    - isInteractive : If true, clicking on the figure will update the background threshold value, 
%                      and offer saving when closing the figure.
% OUTPUT:
%    - hFig    : Matlab handle to the figure where the histogram is displayed
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
% Authors: Francois Tadel, 2006-2020, Marc Lalancette 2025

%% ===== LOAD OR COMPUTE HISTOGRAM =====
% Display progress bar
bst_progress('start', 'View MRI historgram', 'Computing histogram...');
if isstruct(MriFile) && isfield(MriFile, 'intensityMax')
    Histogram = MriFile;
else
    % Load full MRI
    MRI = load(MriFile);
    % Compute histogram if missing
    if ~isfield(MRI, 'Histogram') || isempty(MRI.Histogram) || ~isfield(MRI.Histogram, 'intensityMax')
        Histogram = mri_histogram(MRI.Cube(:,:,:,1));
        % Save histogram
        s.Histogram = Histogram;
        bst_save(MriFile, s, 'v7', 1); % isAppend
    else
        Histogram = MRI.Histogram;
    end
end

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
% Keep original level to check if it changes.
bgLevel = Histogram.bgLevel;
hBg = line([Histogram.bgLevel, Histogram.bgLevel], yLimits, 'Color','b');
line([Histogram.whiteLevel, Histogram.whiteLevel], yLimits, 'Color','y');
h = legend('MRI hist.','Smoothed hist.','Cumulative hist.','Maxima','Minima',...
    'Scalp or grey thresh.','White m thresh.');
set(h, 'FontSize',  bst_get('FigFont'), ...
       'FontUnits', 'points');

% Set interactive callbacks
if isInteractive
    set(hAxes, 'ButtonDownFcn', @clickCallback);
    set(hFig, 'CloseRequestFcn', @(src, event) closeFigureCallback());
end

% Hide progress bar
bst_progress('stop');



function clickCallback(~, event)
    % Extract the x-coordinate of the click
    bgLevel = event.IntersectionPoint(1);
    % fprintf('Clicked at x = %.4f\n', x);
    if bgLevel ~= Histogram.bgLevel
        set(hBg, xdata, [bgLevel, bgLevel]);
        % drawnow % needed?
    end
end

function closeFigureCallback()
    if bgLevel ~= Histogram.bgLevel
        % Request save confirmation.
        [Proceed, isCancel] = java_dialog('confirm', sprintf(...
            'MRI background intensity threshold changed (%d > %d). Save?', Histogram.bgLevel, bgLevel), ...
            'MRI background threshold');
        if isCancel
            return;
        elseif Proceed
            % Save histogram
            Histogram.bgLevel = bgLevel;
            s.Histogram = Histogram;
            bst_save(MriFile, s, 'v7', 1); % isAppend
            % Close figure
            delete(fig);
        end
    else
        % Close figure
        delete(fig);
    end
end

end


