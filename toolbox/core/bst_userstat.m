function bst_userstat(isSave)
% BST_USERSTAT: Plot statistics about the Brainstorm users

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2012-2019

% Parse inputs
if (nargin < 1) || isempty(isSave)
    isSave = 0;
end
% Progress bar
if ~isSave
    bst_progress('start', 'User statistics', 'Downloading...');
end
% Get screen height
ScreenDef = bst_get('ScreenDef');
Hs = [ScreenDef(1).matlabPos(2), ScreenDef(1).matlabPos(4)];
hf = 230;
hFig = [];
% Output folder for images
ImgDir = 'C:\Work\Doc\Brainstorm\site\stat';
% Reading function: urlread replaced with webread in Matlab 2014b
if (bst_get('MatlabVersion') <= 803)
    url_read_fcn = @urlread;
else
    url_read_fcn = @webread;
end

% ===== NUMBER OF USERS =====
% Read list of users
str = url_read_fcn('https://neuroimage.usc.edu/bst/get_userdate.php?c=k9w8cX');
% Extract values
dates = textscan(str, '%d %d');
dates = double([dates{1}, dates{2}]);
dates = dates(:,1) + (dates(:,2)-1)./12;
% Create histogram
[nUsers,year] = hist(dates, length(unique(dates)));
nUsersTotal = cumsum(nUsers);
% Plot figure
hFig(end+1) = fig_report(year, nUsersTotal, 0, ...
           [2005, max(year)], [0, ceil(nUsersTotal(end)/1000)*1000], ...
           sprintf('User accounts: %d', length(dates)), [], 'Number of users', ...
           [100, Hs(2) - (length(hFig)+1)*hf], isSave, bst_fullfile(ImgDir, 'users.png'));

       
% ===== LOG ANALYSIS =====
% Read list of users
str = url_read_fcn('https://neuroimage.usc.edu/bst/get_logs.php?c=J7rTwq');
% Extract values
c = textscan(str, '%02d%02d%c');
dates = double([c{1}, c{2}]);
dates = 2000 + dates(:,1) + (dates(:,2) - 1)./12;
action = c{3};
% Create histograms
iUpdate = find((action == 'A') | (action == 'L') | (action == 'D'));
[nUpdate,xUpdate] = hist(dates(iUpdate), length(unique(dates(iUpdate))));
% Look for all dates in the current year (exclude current month)
iAvg = find((xUpdate >= 2019) & (xUpdate < 2020));
% Remove invalid data
iBad = ((nUpdate < 100) | (nUpdate > 4000));
nUpdate(iBad) = interp1(xUpdate(~iBad), nUpdate(~iBad), xUpdate(iBad), 'pchip');

% Plot number of downloads
[hFig(end+1), hAxes] = fig_report(xUpdate(1:end-1), nUpdate(1:end-1), 0, ...
           [2005, max(xUpdate(1:end-1))], [], ...
           sprintf('Downloads per month: Avg(2019)=%d', round(mean(nUpdate(iAvg)))), [], 'Downloads per month', ...
           [100, Hs(2) - (length(hFig)+1)*hf], isSave, bst_fullfile(ImgDir, 'download.png'));
       
% % Create histograms
% iStart  = find(strcmpi(action, 'Startup'));
% [nStart, xStart]  = hist(dates(iStart),  length(unique(dates(iStart))));
% % Plot number of connections
% fig_report(xStart(1:end-1), nStart(1:end-1), 0, ...
%            [], [], ...
%            'Number of connections per month', [], 'Number of connections', ...
%            [165 754]);


% ===== NUMBER OF FORUM POSTS =====
% Read list of users
str = url_read_fcn('https://neuroimage.usc.edu/bst/get_posts.php?c=3Emzpjt0');
% Extract values
dates = textscan(str, '%d %d');
dates = double([dates{1}, dates{2}]);
dates = dates(:,1) + (dates(:,2)-1)./12;
% Create histogram
[nPosts,year] = hist(dates, length(unique(dates)));
% Plot figure
hFig(end+1) = fig_report(year(1:end-1), nPosts(1:end-1), 0, ...
           [2005, max(year)], [0 ceil(max(nPosts(1:end-1))/100)*100], ...
           sprintf('Posts on the forum: %d', length(dates)), [], 'Forum posts per month', ...
           [100, Hs(2) - (length(hFig)+1)*hf], isSave, bst_fullfile(ImgDir, 'posts.png'));

% ===== PUBLICATIONS =====
% Hard coded list of publications
year   = [2000 2001 2002 2003 2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2014 2015 2016 2017 2018]; 
nPubli = [   2    2    1    1    3    5    5   11   10   20   20   32   38   55   78   94  133  214  225];
nPubliCurYear = 237;
% Plot figure
hFig(end+1) = fig_report(year, nPubli, 1, ...
           [2000 max(year)], [], ...
           sprintf('Peer-reviewed articles and book chapters: %d', sum(nPubli) + nPubliCurYear), [], 'Publications per year', ...
           [100, Hs(2) - (length(hFig)+1)*hf], isSave, bst_fullfile(ImgDir, 'publications.png'));
       

% Close progress bar / figures
if isSave
    close(hFig);
else
    % Close all the figures at once
    set(hFig, 'DeleteFcn', @(h,ev)delete(setdiff(hFig,h)));
    % Close progress bar
    bst_progress('stop');
end

end


%% ===== PLOT FUNCTION ====
function [hFig, hAxes] = fig_report(x, y, isMarkers, XLim, YLim, wTitle, xLabel, yLabel, wPos, isSave, filename)
    % Create figure
    hFig = figure(...
        'NumberTitle',   'off', ...
        'Name',          wTitle, ...
        'Toolbar',       'none', ...
        'MenuBar',       'none', ...
        'DockControls',  'off', ...
        'Color',         [1 1 1], ...
        'Position',      [wPos(1), wPos(2), 700, 200]);
    hAxes = gca;
    % Plot data line
    line(x, y, 0*x+1, ...
        'Color',            [.08 .56 0.79], ...
        'LineWidth',        3, ...
        'Marker',           'none', ...
        'LineSmoothing',    'on', ...
        'Parent',           hAxes);
    % Plot data markers
    if isMarkers
        line(x, y, 2*x+1, ...
            'Color',            [.08 .56 0.79], ...
            'LineStyle',        'none', ...
            'LineWidth',        2, ...
            'Marker',           'o', ...
            'MarkerFaceColor',  [.08 .56 0.79], ...
            'LineSmoothing',    'on', ...
            'Parent',           hAxes);
    else
        % Only for Matlab <= 2014a
        if (bst_get('MatlabVersion') <= 803)
            line(x, y, 2*x+1, ...
                'Color',            [.08 .56 0.79], ...
                'LineStyle',        'none', ...
                'LineWidth',        1, ...
                'Marker',           '.', ...
                'MarkerFaceColor',  [.08 .56 0.79], ...
                'LineSmoothing',    'on', ...
                'Parent',           hAxes);
        end
    end
    % Plot filled polygon
    if (bst_get('MatlabVersion') <= 803)
        patch('Vertices',    [[x,x(end),x(1),x(1)]', [y,0,0,y(1)]', 1+[0*x 0 0 0]'], ...
              'Faces',       1:(length(x)+3), ...
              'FaceColor',   [.08 .56 0.79], ...
              'FaceAlpha',   0.15, ...
              'EdgeColor',   'none', ...
              'Parent',   hAxes);
    else
        patch('Vertices',    [[x,x(end),x(1),x(1)]', [y,0,0,y(1)]', 0.5+[0*x 0 0 0]'], ...
              'Faces',       1:(length(x)+3), ...
              'FaceColor',   [0.86, 0.93, 0.97], ...
              'FaceAlpha',   1, ...
              'EdgeColor',   'none', ...
              'Parent',   hAxes);
    end
    % Set limits
    if ~isempty(XLim)
        set(hAxes, 'XLim', XLim);
    else
        XLim = get(hAxes, 'XLim');
    end
    if ~isempty(YLim)
        set(hAxes, 'YLim', YLim);
    else
        YLim = get(hAxes, 'YLim');
    end
    % Set title
    %title(hAxes, wTitle);
    xlabel(hAxes, xLabel);
    ylabel(hAxes, yLabel);
    drawnow;
    % Plot (Y=0) line
    line([XLim(1) XLim(end)], [0.1 0.1], [.5 .5], ...
        'Color',      [0 0 0], ...
        'LineWidth',  1, ...
        'LineSmoothing',    'on', ...
        'Parent',     hAxes);
    % Set XTicks
    XTick = round(XLim(1)):round(XLim(2));
    set(hAxes, 'XTick', XTick);
    % Get YTicks
    YTick = get(hAxes, 'YTick');
    YTick = setdiff(YTick, 0);
    if (bst_get('MatlabVersion') > 900)
        hAxes.YAxis.Exponent = 0;
    end
    % Plot horizontal grid
    for i = 1:length(YTick)
        line([XLim(1) XLim(end)], [YTick(i) YTick(i)], [.5 .5], ...
            'Color',      [.93 .93 .93], ...
            'LineWidth',  1, ...
            'Parent',     hAxes);
    end
    % Change font size
    set(hAxes, ...
        'FontName',   'Default', ...
        'FontSize',   8, ...
        'FontWeight', 'normal');
    set(findall(hFig,'type','text'), ...
        'FontName',   'Helvetica', ...
        'FontSize',   10, ...
        'FontWeight', 'bold');
    
    % Add a label: "No data available"
    if ~isempty(strfind(filename, 'download'))
        hText = text(2006, 300, 2, 'No data available', ...
                     'Color',     [.7 .7 .7], ...
                     'FontName',  'Courier New', ...
                     'FontSize',  10);
    end

    % Save figure
    drawnow;
    if isSave
        % frameGfx = getscreen(hFig);
        % out_image(filename, frameGfx.cdata);
        out_figure_image(hFig, filename);
    end
end
