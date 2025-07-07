function bst_userstat(isSave, PlugName)
% BST_USERSTAT: Plot statistics about the Brainstorm users
% 
% USAGE:  bst_userstat(isSave=0, PlugName=[])
%         bst_userstat(1)        :
%         bst_userstat(PlugName) : Display the download statistics for a specific plugin
% INPUTS:
%    - isSave   : If 0, display the usage statistics in Matlab figures
%                 If 1, save usage statistics figures on user directory
%    - PlugName : If string, display the download statistics of a specific plugin
%                 If empty, display Brainstorm statistics: users, downloads, forum posts, publications

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
% Authors: Francois Tadel,   2012-2023
%          Raymundo Cassani, 2023

% Parse inputs
if (nargin < 2) || isempty(PlugName)
    PlugName = [];
end
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
ImgDir = bst_get('BrainstormUserDir');
boldMoinMoin = ['''', '''', ''''];
italMoinMoin = ['''', ''''];

% ===== NUMBER OF USERS =====
if isempty(PlugName)
    % Read list of users
    str = bst_webread('https://neuroimage.usc.edu/bst/get_userdate.php?c=k9w8cX');
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
    % String for MoinMoin website
    strWebsite = sprintf('Number of user accounts registered on the website: %s%.3f%s\r', boldMoinMoin, length(dates)/1000, boldMoinMoin);
    fprintf(strrep(strWebsite, '.', ','));
end
       
% ===== LOG ANALYSIS =====
if isempty(PlugName)
    % Read list of users
    str = bst_webread('https://neuroimage.usc.edu/bst/get_logs.php?c=J7rTwq');
    % Replace actions ['i' and 'j'] with 'x' so it is not read as imaginary in textscan
    str = strrep(str, 'i', 'x');
    str = strrep(str, 'j', 'x');
    % Extract values
    c = textscan(str, '%02d%02d%c');
    dates = double([c{1}, c{2}]);
    dates = 2000 + dates(:,1) + (dates(:,2) - 1)./12;
    action = c{3};
    % Create histograms
    iUpdate = find((action == 'A') | (action == 'L') | (action == 'D'));
    [nUpdate,xUpdate] = hist(dates(iUpdate), length(unique(dates(iUpdate))));
    % Look for all dates in last 12 months (exclude current month)
    t = datetime('today');
    finRollAvg = t.Year + ((t.Month -1) ./12);
    iniRollAvg = finRollAvg - 1;
    iAvg = find((xUpdate >= iniRollAvg) & (xUpdate < finRollAvg));
    % Remove invalid data
    iBad = ((nUpdate < 100) | (nUpdate > 4000));
    nUpdate(iBad) = interp1(xUpdate(~iBad), nUpdate(~iBad), xUpdate(iBad), 'pchip');
    % Plot number of downloads
    [hFig(end+1), hAxes] = fig_report(xUpdate(1:end-1), nUpdate(1:end-1), 0, ...
               [2005, max(xUpdate(1:end-1))], [], ...
               sprintf('Downloads per month: 12-month Avg=%d', round(mean(nUpdate(iAvg)))), [], 'Downloads per month', ...
               [100, Hs(2) - (length(hFig)+1)*hf], isSave, bst_fullfile(ImgDir, 'download.png'));
    % String for MoinMoin website
    fprintf('Number of software downloads per month: (12-month average = %s%d/month%s)\r', boldMoinMoin, round(mean(nUpdate(iAvg))), boldMoinMoin);
end


% ===== NUMBER OF FORUM POSTS =====
if isempty(PlugName)
    % Read list of users
    str = bst_webread('https://neuroimage.usc.edu/bst/get_posts.php?c=3Emzpjt0');
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
    % String for MoinMoin website
    strWebsite = sprintf('Number of messages posted on the forum: %s%.3f%s\r', boldMoinMoin, length(dates)/1000, boldMoinMoin);
    fprintf(strrep(strWebsite, '.', ','));
end

% ===== PUBLICATIONS =====
if isempty(PlugName)
    % Up to December 2022, citation count was manually curated
    year_man   = [2000 2001 2002 2003 2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022];
    nPubli_man = [   2    2    1    1    3    5    5   11   10   20   20   32   38   55   78   94  133  214  224  290  382  393  478];
    % nPubliCurYear = 118; % January to March 2023
    % strPubDate = 'Up to March 2023';

    % From January 2023 onwards, citation count is obtained from Google Scholar, and posted in:
    % https://neuroimage.usc.edu/bst/citations_count.html
    % Read list of users
    str = bst_webread('https://neuroimage.usc.edu/bst/citations_count.html');
    % Extract values YYYY#nPubli
    year_Npubli_gs = regexp(str, '[0-9]+#[0-9]+', 'match');
    year_Npubli_gs = sort(year_Npubli_gs);
    year_gs = [];
    nPubli_gs = [];
    for iRow = 1 : length(year_Npubli_gs)
        C = textscan(year_Npubli_gs{iRow}, '%d#%d');
        if C{1} >= 2023
            year_gs(end+1) = C{1};
            nPubli_gs(end+1) = C{2};
        end
    end
    % Publications current year (last year in array)
    nPubliCurYear = nPubli_gs(end);
    % Remove current year from graph
    nPubli_gs(end) = [];
    year_gs(end)   = [];

    % Get month of last update
    dateCount = regexp(str, 'UpdatedOn#([^<]*)', 'tokens', 'once');
    C = str_split(dateCount{1}, '-');
    strPubDate = sprintf('Up to %s %s', C{2}, C{3});

    % Aggregate manual and automatic citation counts
    year   = [year_man, year_gs];
    nPubli = [nPubli_man, nPubli_gs];
    % Plot figure
    hFig(end+1) = fig_report(year, nPubli, 1, ...
               [2000 max(year)], [], ...
               sprintf('Peer-reviewed articles and book chapters: %d', sum(nPubli) + nPubliCurYear), [], 'Publications per year', ...
               [100, Hs(2) - (length(hFig)+1)*hf], isSave, bst_fullfile(ImgDir, 'publications.png'));
    % String for MoinMoin website
    strWebsite = sprintf('Number of peer-reviewed articles and book chapters published using Brainstorm: %s%d%s', boldMoinMoin, sum(nPubli) + nPubliCurYear, boldMoinMoin);
    fprintf([strWebsite, ' <<BR>> ', sprintf('%s(%s)%s\r', italMoinMoin, strPubDate, italMoinMoin)]);
end

% ===== PLUGINS =====
if ~isempty(PlugName)
    % Download statistics
    url = sprintf('https://neuroimage.usc.edu/bst/pluglog.php?c=K8Yda7B&plugname=%s&action=install&list=1', PlugName);
    str =  bst_webread(url);

    if isempty(str)
        bst_progress('stop');
        return;
    end
    % Process report
    str = str_split(str, char(10));
    nTotal = length(str);
    dates = cellfun(@(x)str_split(x,':'), str, 'UniformOutput', 0);
    year = cellfun(@(x)str2double(x{1}(1:4)), dates);
    month = cellfun(@(x)str2double(x{1}(6:7)), dates);
    % Create histogram
    dates = year + (month-1)./12;
    [nUpdate,xUpdate] = hist(dates, length(unique(dates)));
    % Plot figure
    if (length(nUpdate) == 1)
        java_dialog('msgbox', sprintf('Total number of downloads: %d', nTotal), 'Downloads');
    else
        hFig(end+1) = fig_report(xUpdate(1:end-1), nUpdate(1:end-1), 0, ...
                   [2021, max(xUpdate(1:end-1))], [], ...
                   sprintf('Total number of downloads: %d', nTotal), [], 'Downloads', ...
                   [100, Hs(2) - (length(hFig)+1)*hf], 0, ['plugin_' PlugName]);
    end
end

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
    elseif ~isempty(strfind(filename, 'plugin'))
        hText = text(2021.01, 10, 2, 'No data available', ...
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
