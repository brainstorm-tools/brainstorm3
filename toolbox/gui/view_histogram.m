function hFig = view_histogram(varargin)
% VIEW_HISTOGRAM: Compute and view the histogram of one or several brainstorm files.
%
% USAGE:  hFig = view_histogram(FileNames, forceOld);
%
% INPUT:
%    - FileNames : Cell array of relative paths to Brainstorm files
%    - forceOld  : Force usage of old Matlab histogram object (for Plotly)
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
% Authors: Francois Tadel, 2015-2020

FileNames = varargin{1};
if nargin > 1
    forceOld = varargin{2};
else
    forceOld = 0;
end

% Java imports
import org.brainstorm.icon.*;
import java.awt.*;
import javax.swing.*;

% Make sure the input is a cell array
if ~iscell(FileNames)
    FileNames = {FileNames};
end
% Display progress bar
bst_progress('start', 'View histogram', 'Loading files...');


% ===== CREATE FIGURE =====
% Create figure
hFig = figure(...
    'Visible', 'off', ...
    'NumberTitle',   'off', ...
    'IntegerHandle', 'off', ...
    ... 'MenuBar',       'none', ...
    'Toolbar',       'none', ...
    'DockControls',  'on', ...
    'Units',         'pixels', ...
    'Color',         [.8 .8 .8], ...
    'Pointer',       'arrow', ...
    'Tag',           'FigHistograms', ...
    'BusyAction',    'queue', ...
    'Interruptible', 'off', ...
    'ResizeFcn',     @ResizeCallback, ...
    'Name',          'View histogram', ...
    'UserData',      struct('FileNames', FileNames, 'forceOld', forceOld));
% Configure axes
hAxes = axes(...
    'Parent',        hFig, ...
    ... 'Units',         'normalized', ...
    ...'Position',      [.1 .05 .85 .9], ...
    'units', 'pixels', ...
    'Tag',           'AxesHistograms', ...
    'Visible',       'off', ...
    'BusyAction',    'queue', ...
    'Interruptible', 'off');
% Scale figure
Scaling = bst_get('InterfaceScaling') / 100;
    
% ===== TOOLBAR =====
nBins = 9;
% Older version of Matlab (< 2019b): use java components
if bst_get('isJavacomponent')
    isJava = 1;
    % Add toolbar to window
    jToolbar = gui_component('Toolbar', []);
    jToolbar.setPreferredSize(Dimension(100,30*Scaling));
    [jTb, hToolbar] = javacomponent(jToolbar, [0, 0, .1, .1], hFig);
    TB_DIM = Dimension(25*Scaling, 25*Scaling);
    % Buttons
    jButtonEqual = gui_component('ToolbarToggle', jToolbar, [], [], {IconLoader.ICON_TS_SYNCRO, TB_DIM}, 'Display as density of probability', @(h,ev)ToggleAxisType, []);
    jButtonGauss = gui_component('ToolbarToggle', jToolbar, [], [], {IconLoader.ICON_FIND_MAX, TB_DIM},  'Display the corresponding normal distribution', @(h,ev)PlotGaussian, []);
    jButtonEqual.setSelected(1);
    jButtonGauss.setSelected(1);
    jButtonPlotly = gui_component('ToolbarButton', jToolbar, [], [], IconLoader.ICON_PLOTLY,  'Export to Plotly', @(h,ev)bst_call(@out_figure_plotly, hFig), []);
    jToolbar.addSeparator();
    % Edit number of bins
    gui_component('Label', jToolbar, [], '   Number of bins:  ', [], '', [], []);
    jSpinBins = gui_component('Spinner', jToolbar, [], '', [], '', [], []);
    spinmodel = SpinnerNumberModel(nBins, 3, 1000, 2);
    jSpinBins.setModel(spinmodel);
    jSpinBins.setPreferredSize(Dimension(70*Scaling,23*Scaling));
    jSpinBins.setMaximumSize(Dimension(70*Scaling,23*Scaling));
    java_setcb(jSpinBins, 'StateChangedCallback', @NumBinsCallback);
    jToolbar.addSeparator();
    % QQ-plot
    jButtonQQ = gui_component('ToolbarButton', jToolbar, 'right', 'Q-Q plots', [], 'Quantile-quantile plot of the sample quantiles versus theoretical quantiles from a normal distribution', @(h,ev)DisplayQQ, []);
% Newer matlab versions: use dedicated functions
else
    isJava = 0;
    % Add toolbar to window
    hToolbar = uipanel(hFig, 'Position', [0 0 .01 .01], 'Units', 'pixels');
    TB_DIM = 25 * Scaling;
    TEXT_DIM = 100 * Scaling;
    % Buttons
    jButtonEqual = bst_javacomponent(hToolbar, 'toggle', [2, 2, TB_DIM, TB_DIM], [], IconLoader.ICON_TS_SYNCRO, 'Display as density of probability', @(h,ev)ToggleAxisType, [], 1);
    jButtonGauss = bst_javacomponent(hToolbar, 'toggle', [2+1*(TB_DIM+1), 2, TB_DIM, TB_DIM], [], IconLoader.ICON_FIND_MAX, 'Display the corresponding normal distribution', @(h,ev)PlotGaussian, [], 1);
    jButtonPlotly = bst_javacomponent(hToolbar, 'button', [2+2*(TB_DIM+1), 2, TB_DIM, TB_DIM], [], IconLoader.ICON_PLOTLY, 'Export to Plotly', @(h,ev)bst_call(@out_figure_plotly, hFig));

    % Edit number of bins
    bst_javacomponent(hToolbar, 'label', [5+3*(TB_DIM+1), 2, TEXT_DIM, 20*Scaling], 'Number of bins:');
    jSpinBins = bst_javacomponent(hToolbar, 'text', [5+3*(TB_DIM+1)+TEXT_DIM, 8, TB_DIM, TB_DIM-8], num2str(nBins), [], [], @NumBinsCallback);
    % QQ-plot
    jButtonQQ = bst_javacomponent(hToolbar, 'button', [20+4*(TB_DIM+1)+TEXT_DIM, 2, 70*Scaling, TB_DIM], 'Q-Q plots', [], 'Quantile-quantile plot of the sample quantiles versus theoretical quantiles from a normal distribution', @(h,ev)DisplayQQ);
end


% ===== LOAD INPUT FILES =====
% Load all the input files
Values   = cell(1,length(FileNames));
Comments = cell(1,length(FileNames));
bounds   = cell(1,length(FileNames));
u = zeros(1,length(FileNames));
s = zeros(1,length(FileNames));
for iFile = 1:length(FileNames)
    % Load file
    [FileMat, matName] = in_bst(FileNames{iFile});
    % Get data matrix
    Values{iFile} = FileMat.(matName)(:);
    Comments{iFile} = FileMat.Comment;
    % Compute a first histogram
    [fncY, fncX] = hist(Values{iFile}, 100);
    d = fncX(2) - fncX(1);
    % Keep only the bins that have more than a percentage of the max
    iEmpty = find(fncY ./ max(fncY) < 0.001);
    fncY(iEmpty) = [];
    fncX(iEmpty) = [];
    % Get the bounds of the data to display
    bounds{iFile} = [fncX(1) - d/2, fncX(end) + d/2];
    Values{iFile}(Values{iFile} < bounds{iFile}(1) | Values{iFile} > bounds{iFile}(2) | Values{iFile} == 0) = [];
    % Compute mean and standard deviations
    u(iFile) = mean(Values{iFile});
    s(iFile) = std(Values{iFile});
    % Compute Shapiro-Wilk normality test
    [H, pValue, W] = swtest(Values{iFile});
    if H
        strSW = 'NO';
    else
        strSW = 'YES';
    end
    % Prepare legend string
    strLegend{iFile} = sprintf('%s     mean=%1.2e    std=%1.2e\nShapiro-Wilk test:   W=%1.4f    Normal:%s  (p<0.05)', Comments{iFile}, u(iFile), s(iFile), W, strSW);
end


% ===== PLOT HISTOGRAM =====
% Get color order
ColorOrder = get(hAxes, 'ColorOrder');
% Initialize variables
hHist = zeros(1,length(Values));
histY = cell(1,length(Values));
histX = cell(1,length(Values));
hLines = [];
% Compute and display adjusted histogram
for iFile = 1:length(Values)
    % Plot histogram
    if exist('histogram', 'file') && ~forceOld
        hHist(iFile) = histogram(Values{iFile}, 100, ...
            'NumBins',    nBins, ...
            'BinLimits',  bounds{iFile}, ...
            'EdgeColor',  'none', ...
            'Tag',        'HistoPlot');
    else
        % Compute histogram
        [histY{iFile}, histX{iFile}] = hist(Values{iFile}, nBins);
        % Selected color
        iColor = mod(iFile-1, length(ColorOrder)) + 1;
        % Plot histogram
        hHist(iFile) = bar(histX{iFile}, histY{iFile}, ...
            'FaceColor', ColorOrder(iColor,:), ...
            'EdgeColor', 'none', ...
            'BarWidth',  1);
        % Set transparency
        set(get(hHist(iFile), 'Children'), 'FaceAlpha', 0.5);
    end
    hold on;
end
% Get x axis values 
XLim = get(hAxes, 'XLim');
x = linspace(XLim(1), XLim(2), 300);
% Legend
hLegend = legend(hHist, strLegend{:}, 'Location', 'NorthOutside');
set(hLegend, 'Units', 'pixels', 'Interpreter', 'none');
legend boxoff
xlabel('Observed measures');
% Update plots (optional: only to select new options)
ToggleAxisType();
PlotGaussian();
% Make figure visible
set(hFig, 'Visible', 'on');
% Close progress bar
bst_progress('stop');



    %% ===== TOGGLE AXIS TYPE =====
    function ToggleAxisType()
        % Display progress bar
        bst_progress('start', 'View histogram', 'Updating display...');
        % Change display mode
        if (isJava && jButtonEqual.isSelected()) || (~isJava && get(jButtonEqual, 'Value'))
            if exist('histogram', 'file') && ~forceOld
                set(hHist, 'Normalization', 'pdf');
            else
                UpdateBarPlots();
            end
            ylabel('Probability density function');
        else
            if exist('histogram', 'file') && ~forceOld
                set(hHist, 'Normalization', 'count');
            else
                UpdateBarPlots();
            end
            ylabel('Number of observations');
        end
        % Update curves
        PlotGaussian();
        % Close progress bar
        bst_progress('stop');
    end


    %% ===== PLOT GAUSSIAN CURVES =====
    function PlotGaussian()
        % Window was closed
        if ~ishandle(hAxes)
            return;
        end
        % Delete lines
        if ~isempty(hLines)
            delete(hLines);
            hLines = [];
        end
        % If not requested: return
        if (isJava && ~jButtonGauss.isSelected()) || (~isJava && ~get(jButtonGauss, 'Value')) 
            return;
        end
        % Plot normal distributions for each file
        for i = 1:length(Values)
            % Compute the corresponding normal distribution
            y = exp(-(x-u(i)).^2 / (2*s(i)^2)) / (s(i) * sqrt(2*pi));
            % Normalize it to the display
            if (isJava && ~jButtonEqual.isSelected()) || (~isJava && ~get(jButtonEqual, 'Value'))
                if exist('histogram', 'file') && ~forceOld
                    %y = y ./ sum(get(hHist(i),'Values'));
                    tmpX = get(hHist(i),'BinEdges');
                    y = y .* (tmpX(2)-tmpX(1)) * sum(get(hHist(i),'Values'));
                else
                    y = y .* sum(histY{i}) .* (histX{i}(2)-histX{i}(1));
                end
            end
            % Selected color
            iColor = mod(i-1, length(ColorOrder)) + 1;
            % Plot curve
            hLines(i) = plot(hAxes, x, y, 'Color', ColorOrder(iColor,:), 'Tag', 'LineNormal', 'HandleVisibility', 'off');
        end
    end


    %% ===== TEXT BINS CALLBACK =====
    function NumBinsCallback(h,ev)
        % Display progress bar
        bst_progress('start', 'View histogram', 'Updating number of bins...');
        % Window was closed
        if ~ishandle(hAxes)
            return;
        end
        % Get number of bins
        if isJava
            nBins = jSpinBins.getValue();
        else
            nBins = str2num(get(jSpinBins, 'String'));
        end
        % Update histograms
        if exist('histogram', 'file') && ~forceOld
            set(hHist, 'NumBins', nBins);
        else
            % Compute new histogram
            for i = 1:length(Values)
                [histY{i}, histX{i}] = hist(Values{i}, nBins);
            end
            % Update display
            UpdateBarPlots();
        end
        % Update curves
        PlotGaussian();
        % Close progress bar
        bst_progress('stop');
    end


    %% ===== UPDATE BAR PLOTS =====
    function UpdateBarPlots()
        minX = Inf;
        maxX = -Inf;
        for i = 1:length(Values)
            if jButtonEqual.isSelected()
                set(hHist(i), 'XData', histX{i}, 'YData', histY{i} / sum(histY{i}) / (histX{i}(2)-histX{i}(1)));
            else
                set(hHist(i), 'XData', histX{i}, 'YData', histY{i});
            end
            minX = min(minX, 1.5*histX{i}(1) - .5*histX{i}(2));
            maxX = max(maxX, 1.5*histX{i}(end) - .5*histX{i}(end-1));
        end
        set(hAxes, 'XLim', [minX,maxX]);
    end


    %% ===== RESIZE CALLBACK =====
    function ResizeCallback(hFig, ev)
        % Get figure size
        figPos = get(hFig, 'Position');
        % Reposition toolbar
        set(hToolbar, 'Position', [1, figPos(4)-29*Scaling, figPos(3), 30*Scaling]);
        % Reposition axes
        legendH = 35 * length(hHist) * Scaling;
        set(hAxes, 'Position', [70*Scaling, 50*Scaling, max(1,figPos(3)-90*Scaling), max(1,figPos(4)-legendH-100*Scaling)]);
        % Reposition legend
        set(hLegend, 'Position', [50*Scaling, max(1,figPos(4)-30*Scaling-legendH), max(1,figPos(3)-90*Scaling), legendH]);
    end


    %% ===== DISPLAY QQ PLOT =====
    function DisplayQQ()
        % Progress bar
        bst_progress('start', 'Q-Q plot', 'Creating plots...', 0, length(Values));
        % Create figure
        hFig = figure(...
            'NumberTitle',   'off', ...
            'IntegerHandle', 'off', ...
            'MenuBar',       'none', ...
            'Toolbar',       'none', ...
            'DockControls',  'on', ...
            'Units',         'pixels', ...
            'Color',         [.8 .8 .8], ...
            'Tag',           'FigHistograms', ...
            'BusyAction',    'queue', ...
            'Interruptible', 'off', ...
            'Name',          'Q-Q plots');
        drawnow;
        % Display one Q-Q plot per file
        for i = 1:length(Values)
            bst_progress('inc', 1);
            hPlot = subplot(1, length(Values), i);
            qq_plot(Values{i});
            title(hPlot, Comments{i});
            drawnow;
        end
        bst_progress('stop');
    end
end



