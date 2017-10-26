function out_figure_plotly(hFig)
% OUT_FIGURE_PLOTLY: Send the figure (hFiG) to a plotly server

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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

% Make sure the Plotly credentials exist
[username, apikey] = bst_get('PlotlyCredentials');
if isempty(username) || isempty(apikey)
    % Ask for credentials if they are missing
    java_dialog('msgbox', ['No Plotly credentials saved. ', ...
        'Please enter them in the Brainstorm preferences.']);
    gui_show('panel_options', 'JavaWindow', 'Brainstorm preferences', [], 1, 0, 0);
    
    % If credentials are still missing, cancel
    [username, apikey] = bst_get('PlotlyCredentials');
    if isempty(username) || isempty(apikey)
        bst_progress('stop');
        return;
    end
end

% Clone figure
hTempFig = bst_figures('CloneFigure', hFig);
set(hTempFig, 'Visible', 'off');
drawnow;

% Prepare ax(es) to send to Plotly
bst_progress('start', 'Export figure to Plotly', 'Preparing figure...');
axes = findobj(hTempFig,'Type','axes','-and','Tag','AxesGraph');

for iAx = 1:length(axes)
    % Plotly includes axes without tags
    axes(iAx).Tag = '';
    
    % Remove TimeZeroLine and Cursor objects
    objsToRemove = findobj(axes(iAx),'Tag','TimeZeroLine','-or','Tag','Cursor');
    delete(objsToRemove);
    
    plots = findobj(axes(iAx),'-not','Type','Text','-not','Type','axes','-depth',1);
    for iPlot = 1:length(plots)
        plot_data = get(plots(iPlot));
        
        % If all Z positions are the same, remove Z information to force 2D
        if isfield(plot_data,'ZData') && ~isempty(plot_data.ZData) && all(plot_data.ZData == plot_data.ZData(1))
            plots(iPlot).ZData = [];
        end
        
        % Remove axis line (unnecessary with Plotly)
        if isfield(plot_data,'Type') && strcmpi(plot_data.Type, 'line') && ...
                isfield(plot_data,'YData') && ~isempty(plot_data.YData) && all(plot_data.YData == 0)
            delete(plots(iPlot));
        end
    end
end

% Send figure to Plotly
bst_progress('text', 'Sending figure...');
PlotlyException = [];
try
    p = plotlyfig(hTempFig, 'filename', hTempFig.Name);
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


