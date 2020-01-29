function out_figure_plotly(hFig)
% OUT_FIGURE_PLOTLY: Send the figure (hFiG) to a plotly server

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
% Authors: Martin Cousineau, 2017

% Ensure we are including the Plotly folder in the Matlab path
plotlyDir = bst_fullfile(bst_get('BrainstormUserDir'), 'plotly');
if exist(plotlyDir, 'file')
    addpath(genpath(plotlyDir));
end

% Install Plotly if missing
if ~exist('plotlyfig', 'file')
    rmpath(genpath(plotlyDir));
    isOk = java_dialog('confirm', ...
        ['The Plotly Matlab wrapper is not installed on your computer.' 10 10 ...
             'Download and install the latest version?'], 'Plotly');
    if ~isOk
        return;
    end
    downloadAndInstallPlotly();
end

% Confirm Plotly credentials
[username, apikey, domain] = bst_get('PlotlyCredentials');
[res, isCancel] = java_dialog('input', ...
    {['<html><body><p>Please enter your Plotly credentials</p><br>', ...
    '<p>Username:</p></body></html>'], 'API Key:', 'Domain (optional):'}, ...
    'Plotly Credentials', [], {username, apikey, domain});
if isCancel || isempty(res{1}) || isempty(res{2})
    bst_progress('stop');
    return;
end
bst_set('PlotlyCredentials', res{1}, res{2}, res{3});

% For histogram plots, we need to use the old Matlab histogram objects as
% the newer ones are not supported by Plotly
if strcmpi(get(hFig, 'Tag'), 'FigHistograms')
    figData = get(hFig, 'UserData');
    figData.forceOld = 1;
    set(hFig, 'UserData', figData);
end

% Clone figure
hTempFig = bst_figures('CloneFigure', hFig);
set(hTempFig, 'Visible', 'off');
drawnow;

% Prepare ax(es) to send to Plotly
bst_progress('start', 'Export figure to Plotly', 'Preparing figure...');
axes = findobj(hTempFig, 'Type', 'axes', '-and', ...
    {'Tag', 'AxesGraph', ...
     '-or', 'Tag', 'AxesTimefreq', ...
     '-or', 'Tag', '', ...
    });

for iAx = 1:length(axes)
    % Plotly includes axes without tags
    axes(iAx).Tag = '';
    
    % Remove TimeZeroLine and Cursor objects
    objsToRemove = findobj(axes(iAx),'Tag','TimeZeroLine','-or','Tag','Cursor');
    delete(objsToRemove);
    
    plots = findobj(axes(iAx),'-not','Type','Text','-not','Type','axes','-depth',1);
    for iPlot = 1:length(plots)
        plot_data = get(plots(iPlot));
        
        % Remove line breaks in names
        if isfield(plot_data,'DisplayName') && ~isempty(plot_data.DisplayName)
            plots(iPlot).DisplayName = strrep(plot_data.DisplayName, char(10), ' ');
        end
        
        % If all Z positions are the same, remove Z information to force 2D
        if isfield(plot_data,'ZData') && ~isempty(plot_data.ZData) && all(all(plot_data.ZData == plot_data.ZData(1)))
            plots(iPlot).ZData = [];
        end
        
        % Remove axis line (unnecessary with Plotly)
        if isfield(plot_data,'Type') && strcmpi(plot_data.Type, 'line') && ...
                isfield(plot_data,'YData') && ~isempty(plot_data.YData) && all(plot_data.YData == 0)
            delete(plots(iPlot));
        end
    end
end

% Plotly treats slashes in figure name as folders, but does not support
% creating folders with free accounts on its default domain (http://plot.ly).
% Therefore, slashes will be removed for now.
figName = strrep(hTempFig.Name, '/', ' - ');

% Max length of figure name
if length(figName) > 100
    figName = figName(1:100);
end

% Send figure to Plotly
bst_progress('text', 'Sending figure...');
PlotlyException = [];
try
    % Prepare figure
    p = plotlyfig(hTempFig, 'filename', figName);
    
    % ===== Last minute tweaking =====
    % Remove height and width so that Plotly automatically resizes the fig
    p.layout = rmfield(p.layout, {'width', 'height'});
    % Add margins so that X axis label and title are readable
    p.layout.margin.t = 10;
    p.layout.margin.b = 20;
    
    % Send figure
    response = p.plotly;
catch PlotlyException
end

% Close cloned figure
close(hTempFig);
bst_progress('stop');

% Check whether an error or warning occurred
if ~isempty(PlotlyException)
    rethrow(PlotlyException);
elseif ~isempty(response.error)
    error(response.error);
elseif ~isempty(response.warning)
    disp([10, 'Warning: ', response.warning]);
elseif isempty(response.url) && ~isempty(response.message)
    error(response.message);
elseif isempty(response.url)
    error('Could not send figure to Plotly. An unknown error occured.');
end

% Display figure URL
disp(['Plotly figure available at: ', response.url]);

end

%% ===== DOWNLOAD AND INSTALL PLOTLY TOOLBOX =====
function downloadAndInstallPlotly()
    plotlyDir = bst_fullfile(bst_get('BrainstormUserDir'), 'plotly');
    plotlyTmpDir = bst_fullfile(bst_get('BrainstormUserDir'), 'plotly_tmp');
    url = 'https://github.com/plotly/MATLAB-Online/archive/master.zip';
    % If folders exists: delete
    if isdir(plotlyDir)
        file_delete(plotlyDir, 1, 3);
    end
    if isdir(plotlyTmpDir)
        file_delete(plotlyTmpDir, 1, 3);
    end
    % Create folder
	mkdir(plotlyTmpDir);
    % Download file
    zipFile = bst_fullfile(plotlyTmpDir, 'plotly.zip');
    errMsg = gui_brainstorm('DownloadFile', url, zipFile, 'Plotly download');
    if ~isempty(errMsg)
        error(['Impossible to download Plotly: ' errMsg]);
    end
    % Unzip file
    bst_progress('start', 'Plotly', 'Installing Plotly...');
    unzip(zipFile, plotlyTmpDir);
    % Get parent folder of the unzipped file
    diropen = dir(fullfile(plotlyTmpDir, 'MATLAB*'));
    idir = find([diropen.isdir] & ~cellfun(@(c)isequal(c(1),'.'), {diropen.name}), 1);
    newPlotlyDir = bst_fullfile(plotlyTmpDir, diropen(idir).name, 'plotly');
    % Move plotly directory to proper location
    file_move(newPlotlyDir, plotlyDir);
    % Delete unnecessary files
    file_delete(plotlyTmpDir, 1, 3);
    % Add Plotly to Matlab path
    addpath(genpath(plotlyDir));
end

