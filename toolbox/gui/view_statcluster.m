function [hFig, iDS, iFig] = view_statcluster( StatFile, DisplayMode, Modality, hFig )
% VIEW_STATCLUSTER: Display the significant clusters in cluster-based stat file.
%
% USAGE: [hFig, iDS, iFig] = view_statcluster(StatFile, DisplayMode=[], Modality=[], hFig=[])
%
% INPUT: 
%     - StatFile    : Relative path to stat file to visualize
%     - DisplayMode : {'clustindex_time', 'clustsize_time', 'longest'}
%     - hFig        : If defined, display file in existing figure
%
% OUTPUT : 
%     - hFig : Matlab handle to the figure that was created or updated
%     - iDS  : DataSet index in the GlobalData variable
%     - iFig : Indice of returned figure in the GlobalData(iDS).Figure array

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2015

global GlobalData;

% ===== READ INPUTS =====
if (nargin < 4) || isempty(hFig)
    hFig = [];
end
if (nargin < 3) || isempty(Modality)
    Modality = [];
end
if (nargin < 2) || isempty(DisplayMode)
    DisplayMode = [];
end
iDS = [];
iFig = [];


% ===== LOAD DATA =====
FileType = file_gettype(StatFile);
switch (FileType)
    case 'pdata'
        % Load data file
        iDS = bst_memory('LoadDataFile', StatFile);
        if isempty(iDS)
            return;
        end
        bst_memory('LoadRecordingsMatrix', iDS);
        % Get clusters
        StatClusters = GlobalData.DataSet(iDS).Measures.StatClusters;
        % Row names = channel names
        RowNames = {GlobalData.DataSet(iDS).Channel.Name};
        nRows = length(RowNames);
        % Default display
        if isempty(DisplayMode)
            DisplayMode = 'clustindex_time';
        end
        FreqLabels = [];
        
    case 'presults'
        % Load results file
        [iDS, iRes] = bst_memory('LoadResultsFileFull', StatFile);
        if isempty(iDS)
            return;
        end
        % Get clusters
        StatClusters = GlobalData.DataSet(iDS).Results(iRes).StatClusters;
        nRows = size(GlobalData.DataSet(iDS).Results(iRes).ImageGridAmp,1);
        RowNames = 1:nRows;
        % Default display
        if isempty(DisplayMode)
            DisplayMode = 'clustsize_time';
        end
        FreqLabels = [];
        
    case 'ptimefreq'
        % Load timefreq file
        [iDS, iTf] = bst_memory('LoadTimefreqFile', StatFile);
        if isempty(iDS)
            return;
        end
        % Get clusters
        StatClusters = GlobalData.DataSet(iDS).Timefreq(iTf).StatClusters;
        RowNames     = GlobalData.DataSet(iDS).Timefreq(iTf).RowNames;
        nRows = length(RowNames);
        % Default display
        if isempty(DisplayMode)
            DisplayMode = 'clustsize_time';
        end
        FreqLabels = panel_freq('FormatFreqLabels', GlobalData.DataSet(iDS).Timefreq(iTf).Freqs);
        
    case 'pmatrix'
        % Load matrix file
        [iDS, iMat] = bst_memory('LoadMatrixFile', StatFile);
        if isempty(iDS)
            return;
        end
        % Get clusters
        StatClusters = GlobalData.DataSet(iDS).Matrix(iMat).StatClusters;
        RowNames     = GlobalData.DataSet(iDS).Matrix(iMat).Description;
        nRows = length(RowNames);
        % Default display
        if isempty(DisplayMode)
            DisplayMode = 'clustindex_time';
        end
        FreqLabels = [];
        
    otherwise
        error('Unsupported file type.');
end
% No clusters available
if isempty(StatClusters)
    error(['No cluster information available from this file:' StatFile]);
end
% Get time vector
Time = bst_memory('GetTimeVector', iDS);


% ===== THRESHOLD CLUSTER MAPS =====
% Get significant clusters
[sClusters, PosClust, NegClust] = panel_stat('GetSignificantClusters', StatClusters);
% Set all the values that are not is a signficant cluster to zero
if isempty(PosClust)
    StatClusters.posclusterslabelmat = zeros(nRows, length(Time));
else
    StatClusters.posclusterslabelmat(~ismember(StatClusters.posclusterslabelmat, [PosClust.ind])) = 0;
end
if isempty(NegClust)
    StatClusters.negclusterslabelmat = zeros(nRows, length(Time));
else
    StatClusters.negclusterslabelmat(~ismember(StatClusters.negclusterslabelmat, [NegClust.ind])) = 0;
end


% ===== BUILD CLUSTER IMAGE =====
% Switch display mode
switch lower(DisplayMode)
    case 'clustindex_time'
        % Combine the two maps into one
        ClusterMap = StatClusters.posclusterslabelmat - StatClusters.negclusterslabelmat;
        % Apply function to map cluster indices with colors in the same way as the panel Stat
        clustPos = ClusterMap(ClusterMap > 0);
        ClusterMap(ClusterMap > 0) = max(clustPos(:)) - clustPos + 1;
        clustNeg = abs(ClusterMap(ClusterMap < 0));
        ClusterMap(ClusterMap < 0) = -(max(clustNeg(:)) - clustNeg + 1);
        % Replace non-stat values with NaN
        ClusterMap(ClusterMap == 0) = NaN;
        % Create the labels
        Labels = cell(1,4);
        Labels{1} = RowNames;
        Labels{2} = [];
        Labels{3} = Time;
        Labels{4} = FreqLabels;
        % Create the image volume: [N1 x N2 x Ntime x Nfreq]
        M = reshape(ClusterMap, size(ClusterMap,1), 1, size(ClusterMap,2), size(ClusterMap,3));
        % Show the image
        [hFig, iDS, iFig] = view_image_reg(M, Labels, [1,3], {'Signals','Time (s)'}, StatFile, hFig, 'cluster', 1, '$freq');
        % Configure the colormap to show positive and negative values
        bst_colormaps('SetColormapAbsolute', 'Image', 0);

    case 'clustsize_time'
        % For each cluster, compute the number of channels/sources involved at each time point
        if ~isempty(sClusters)
            F = zeros(length(sClusters), length(Time));
            LinesColor = cell(length(sClusters), 1);
            LinesLabels = cell(length(sClusters), 1);
            for i = 1:length(sClusters)
                F(i,:) = sum(sum(double(sClusters(i).mask), 1), 3);
                LinesColor{i} = sClusters(i).color;
                LinesLabels{i} = sprintf('p=%1.5f, c=%d, s=%d', sClusters(i).prob, round(sClusters(i).clusterstat), sClusters(i).clustsize);
            end
        else
            F = zeros(1, length(Time));
            LinesColor{1} = [0 0 0];
            LinesLabels{1} = 'Empty';
        end
        % Display signals
        [hFig, iDS, iFig] = view_timeseries_matrix(StatFile, F, [], 'Clusters', 'Cluster size', LinesLabels, LinesColor, hFig, []);
        
    % Topography or source map with longest values for each cluster
    case 'longest'
        % Plot topography/source map
        switch (FileType)
            case 'pdata'
                % For each cluster, compute the number of significant time points for each channel/source
                if ~isempty(sClusters)
                    F = zeros(nRows, 1);
                    for i = 1:length(sClusters)
                        [lenMax, iRow] = max(sum(sClusters(i).mask,2));
                        F(iRow,:) = lenMax;
                    end
                else
                    F = zeros(nRows, 1);
                end

                % Get channels from selected modality
                iChannels = channel_find(GlobalData.DataSet(iDS).Channel, Modality);
                % Display topography
                [hFig, iDS, iFig] = view_topography(StatFile, Modality, '2DSensorCap', F(iChannels,:), 0, 'NewFigure', []);
                % Set colormap
                bst_colormaps('ConfigureColorbar', hFig, 'timefreq', 'samples', 'samples');
                ColormapInfo = getappdata(hFig, 'Colormap');
                ColormapInfo.Type = 'timefreq';
                ColormapInfo.AllTypes = {'timefreq'};
                ColormapInfo.DisplayUnits = 'samples';
                setappdata(hFig, 'Colormap', ColormapInfo);
                
            case 'presults'
                % Display surface
                [hFig, iDS, iFig] = view_surface_data(GlobalData.DataSet(iDS).Results(iRes).SurfaceFile, StatFile, [], hFig);
                % Get axes object
                hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
                % Get surface in memory
                % sSurf = bst_memory('GetSurface', GlobalData.DataSet(iDS).Results(iRes).SurfaceFile);
                % Get displayed surface
                hPatch = findobj(hAxes, '-depth', 1, 'Tag', 'AnatSurface');
                Vertices = get(hPatch, 'Vertices');
                % Remove previous markers
                delete(findobj(hAxes, '-depth', 1, 'Tag', 'ptClusterMax'));
                % Search maximum duration for each cluster
                for i = 1:length(sClusters)
                    % Get maximum
                    [lenMax, iRow] = max(sum(sClusters(i).mask,2));
                    if (lenMax == 0)
                        continue;
                    end
                    % Get point coordinates 
                    pt = Vertices(iRow,:);
                    % Mark new point
                    line(pt(1)*1.005, pt(2)*1.005, pt(3)*1.005, ...
                         'MarkerFaceColor', sClusters(i).color, ...
                         'MarkerEdgeColor', sClusters(i).color, ...
                         'Marker',          '+',  ...
                         'MarkerSize',      12, ...
                         'LineWidth',       2, ...
                         'Parent',          hAxes, ...
                         'Tag',             'ptClusterMax');
                end
                
            otherwise
                error('Not supported.');
        end
    otherwise
        error(['Invalid display mode: "' DisplayMode '"']);
end

% Add tag in the figure appdata
StatInfo.StatFile    = StatFile;
StatInfo.DisplayMode = DisplayMode;
setappdata(hFig, 'StatInfo', StatInfo);

% Show "stat" tab
gui_brainstorm('ShowToolTab', 'Stat');
% Update figure selection
bst_figures('SetCurrentFigure', hFig, '2D');

% Save reload call
ReloadCall = {'view_statcluster', StatFile, DisplayMode, Modality, hFig};
setappdata(hFig, 'ReloadCall', ReloadCall);

% Stat panel: reload clusters list
panel_stat('CurrentFigureChanged_Callback', hFig);

% Last update for topography
if strcmpi(DisplayMode, 'longest')
    if strcmpi(FileType, 'pdata')
        figure_topo('ColormapChangedCallback', iDS, iFig);
        figure_topo('CurrentTimeChangedCallback', iDS, iFig);
%     elseif strcmpi(FileType, 'presults')
%         panel_surface('UpdateSurfaceData', hFig, 1);
    end
end
