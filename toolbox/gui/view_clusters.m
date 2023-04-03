function [hFig, iDS, iFig] = view_clusters(DataFiles, ClusterLabels, hFig, ClustersOptions)
% VIEW_CLUSTERS: Display time series for all the clusters selected in the JList.
%
% USAGE:  [hFig, iDS, iFig] = view_clusters(DataFiles, ClusterLabels=[selected], hFig=[], ClustersOptions=[])
%         [hFig, iDS, iFig] = view_clusters(DataFiles, iClusters, hFig=[], ClustersOptions=[])

% INPUTS:
%    - DataFiles     : Cell-array of input data files
%    - ClusterLabels : Cell-array of labels of the clusters to display
%    - iClusters     : Indices of the clusters to display from the list in the Clusters tab
%    - hFig          : Re-use existing figure
%    - ClustersOptions: struct()
%        |- function          : {'Mean','Max','Power','PCA','FastPCA', 'All'} ?
%        |- overlayClusters   : {0, 1}
%        |- overlayConditions : {0, 1}

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
% Authors: Francois Tadel, 2009-2023

global GlobalData;  

%% ===== GET CLUSTERS LIST =====
% Get clusters options from GUI
if (nargin < 4) || isempty(ClustersOptions)
    ClustersOptions = [];
end
% No figure in input: create a new one
if (nargin < 3) || isempty(hFig)
    hFig = [];
end
% Get clusters currently loaded in the Clusters tab
sClustersTab = panel_cluster('GetClusters');
% No cluster in input: get selected clusters
if (nargin < 2) || isempty(ClusterLabels)
    sClustersSel = panel_cluster('GetSelectedClusters');
    if ~isempty(sClustersSel)
        ClusterLabels = {sClustersSel.Label};
    else
        ClusterLabels = {};
    end
% Clusters passed as indices (iCluster)
elseif isnumeric(ClusterLabels)
    iClusters = ClusterLabels;
    ClusterLabels = {sClustersTab(iClusters).Label};
end
% Warning message if no cluster selected
if isempty(ClusterLabels)
    java_dialog('warning', 'No cluster selected.', 'Display clusters time series');
    return;
end


%% ===== GET DATA FILES =====
% Look for the loaded datasets with data files and the selected clusters available
if (nargin == 0) || isempty(DataFiles)
    DataFiles = {};
    for iDS = 1:length(GlobalData.DataSet)
        if isempty(GlobalData.DataSet(iDS).DataFile) || isempty(GlobalData.DataSet(iDS).Channel) || isempty(GlobalData.DataSet(iDS).Figure)
            continue;
        end
        % Cluster label is found directly in the loaded dataset
        if ~isempty(GlobalData.DataSet(iDS).Clusters) && all(ismember(ClusterLabels, {GlobalData.DataSet(iDS).Clusters.Label}))
            DataFiles{end+1} = GlobalData.DataSet(iDS).DataFile;
        % Otherwise, look in the clusters loaded in the Cluster tab
        else
            % Get selected clusters
            iClustersSel = find(ismember({sClustersTab.Label}, ClusterLabels));
            % All the sensors of all these clusters must be available in the channel file
            if all(ismember([sClustersTab(iClustersSel).Sensors], {GlobalData.DataSet(iDS).Channel.Name}))
                DataFiles{end+1} = GlobalData.DataSet(iDS).DataFile;
            end
        end
    end
end
% No dataset loaded with selected sensors
if isempty(DataFiles)
    error('No data files can be found with the selected channels.');
end


%% ===== PREPARE DATA TO DISPLAY =====
% Initialize common descriptors (between all files)
SubjectFile    = '*';
StudyFile      = '*';

% ===== Get display options =====        
% ClustersOptions:
%    |- function          : {'Mean','Max','Power','PCA','FastPCA', 'All'} ?
%    |- overlayClusters   : {0, 1}
%    |- overlayConditions : {0, 1}
if isempty(ClustersOptions)
    ClustersOptions = panel_cluster('GetClusterOptions');
end
if (length(ClusterLabels) == 1)
    ClustersOptions.overlayClusters = 0;
end
if (length(DataFiles) == 1)
    ClustersOptions.overlayConditions = 0;
end
% Initialize data to display
clustersActivity = cell(length(DataFiles), length(ClusterLabels));
clustersStd      = cell(length(DataFiles), length(ClusterLabels));
clustersLabels   = cell(length(DataFiles), length(ClusterLabels));
clustersColors   = cell(length(DataFiles), length(ClusterLabels));
axesLabels       = cell(length(DataFiles), length(ClusterLabels));
% Process each Data file
for iFile = 1:length(DataFiles)
    % ===== GET/CREATE DATASET =====
    bst_progress('start', 'Display clusters time series', ['Loading recordings file: "' DataFiles{iFile} '"...']);
    % Create dataset
    iDS = bst_memory('LoadDataFile', DataFiles{iFile}, 0);
    % Load data matrix
    if isempty(GlobalData.DataSet(iDS).Measures.F)
        bst_memory('LoadRecordingsMatrix', iDS);
    end
    % Is a stat file or regular file
    isStat = strcmpi(file_gettype(DataFiles{iFile}), 'pdata');

    % Get data subjectName/condition (FOR TITLE ONLY)
    [sStudy,   iStudy]   = bst_get('Study',   GlobalData.DataSet(iDS).StudyFile);
    [sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject);
    isInterSubject = (iStudy == -2);
    % Get identification of figure
    if ~isempty(SubjectFile)
        if (SubjectFile(1) == '*')
            SubjectFile = sStudy.BrainStormSubject;
        elseif ~file_compare(SubjectFile, sStudy.BrainStormSubject)
            SubjectFile = [];
        end
    end
    if ~isempty(StudyFile)
        if (StudyFile(1) == '*')
            StudyFile = GlobalData.DataSet(iDS).StudyFile;
        elseif ~file_compare(StudyFile, GlobalData.DataSet(iDS).StudyFile)
            StudyFile = [];
        end
    end
    % If no study loaded: ignore file
    if isempty(sStudy)
        error(['No study registered for file: ' strrep(DataFiles{iFile},'\\','\')]);
    end
   
    % ===== Prepare cell array containing time series to display =====
    for k = 1:length(ClusterLabels)
        % ===== GET DATA TO DISPLAY =====
        sCluster = [];
        % Look for the cluster in the loaded dataset
        if ~isempty(GlobalData.DataSet(iDS).Clusters)
            iCluster = find(strcmp(ClusterLabels{k}, {GlobalData.DataSet(iDS).Clusters.Label}));
            if ~isempty(iCluster)
                sCluster = GlobalData.DataSet(iDS).Clusters(iCluster(1));
            end
        end
        % If cluster is not defined in the dataset, look for the clusters available in the Cluster tab
        if isempty(sCluster)
            iCluster = find(ismember({sClustersTab.Label}, ClusterLabels{k}));
            if ~isempty(iCluster)
                sCluster = sClustersTab(iCluster(1));
            end
        end
        if isempty(sCluster)
            error(['Cluster "' ClusterLabels{k} '" not found in data file: ' GlobalData.DataSet(iDS).DataFile]);
        end

        % Get cluster channels
        [iChannel, Modality] = panel_cluster('GetChannelsInCluster', sCluster, GlobalData.DataSet(iDS).Channel, GlobalData.DataSet(iDS).Measures.ChannelFlag);
        if isempty(iChannel)
            return;
        end
        % Get time indices
        [TimeVector, iTime] = bst_memory('GetTimeVector', iDS, [], 'UserTimeWindow');
        % Get data (over current time window)
        [DataToPlot, DataStd] = bst_memory('GetRecordingsValues', iDS, iChannel, iTime);       
        % Compute the cluster values
        if ~isStat
            ClusterFunction = sCluster.Function;
        else
            ClusterFunction = 'stat';
        end
        separator = strfind(ClusterFunction, '+');
        if ~isempty(separator)
            StdFunction     = ClusterFunction(separator+1:end);
            ClusterFunction = ClusterFunction(1:separator-1);
        else
            StdFunction = [];
        end
        clustersActivity{iFile,k} = bst_scout_value(DataToPlot, ClusterFunction);
        if ~isempty(StdFunction)
            clustersStd{iFile, k} = bst_scout_value(DataToPlot, StdFunction);
        elseif ~isempty(DataStd) && all(size(clustersActivity{iFile,k}) == size(DataStd))
            clustersStd{iFile, k} = DataStd;
        else
            clustersStd{iFile, k} = [];
        end

        % === AXES LABELS ===
        % Format: SubjectName/Cond1/.../CondN/(DataComment)/(ClusterName)
        strAxes = '';
        if ~isempty(sSubject) && (iSubject > 0)
            strAxes = sSubject.Name;
        end
        if ~isempty(sStudy)
            % If inter-subject node
            if isInterSubject
                strAxes = [strAxes, 'Inter'];
            % Else: display conditions name
            else
                for i=1:length(sStudy.Condition)
                    strAxes = [strAxes, '/', sStudy.Condition{i}];
                end
            end
        end
        % If more than one data file in this study : display current data comments
        if (length(sStudy.Data) > 1) || isInterSubject
            % Find DataFile in current study
            iData = find(file_compare({sStudy.Data.FileName}, DataFiles{iFile}));
            % Add Data comment
            strAxes = [strAxes, '/', sStudy.Data(iData).Comment];
        end
        axesLabels{iFile,k} = strAxes;

        % === CLUSTERS LABELS/COLORS ===
        clustersLabels{iFile,k} = sCluster.Label;
        clustersColors{iFile,k} = sCluster.Color;
    end
end

% ===== DISPLAY STATIC VALUES =====
% Get the number of time samples for all the clusters
nbTimes = cellfun(@(c)size(c,2), clustersActivity(:));
% If both real clusters and static values
if ((max(nbTimes) > 2) && any(nbTimes == 2))
    iCellToExtend = find(nbTimes == 2);
    for i = 1:length(iCellToExtend)
        clustersActivity{iCellToExtend(i)} = repmat(clustersActivity{iCellToExtend(i)}(:,1), [1,max(nbTimes)]);
        clustersStd{iCellToExtend(i)} = repmat(clustersStd{iCellToExtend(i)}(:,1), [1,max(nbTimes)]);
    end
end


%% ===== LEGENDS =====
% Get common beginning part in all the axesLabels
[ strAxesCommon, axesLabels ] = str_common_path( axesLabels );
% === NO OVERLAY ===
% Display all timeseries (DataFiles/Clusters) in different axes on the same figure
if (~ClustersOptions.overlayClusters && ~ClustersOptions.overlayConditions)
    % One graph for each line => Ngraph, Nclusters*Ncond
    % Clusters activity = cell-array {1, Ngraph} of doubles [1,Nt]
    clustersActivity = clustersActivity(:)';
    clustersStd = clustersStd(:)';
    % Axes labels (subj/cond) = cell-array of strings {1, Ngraph}
    axesLabels = axesLabels(:)';
    % Clusters labels = cell-array of strings {1, Ngraph}
    clustersLabels = clustersLabels(:)';
    clustersColors = clustersColors(:)';
    
% === OVERLAY CLUSTERS AND CONDITIONS ===
elseif (ClustersOptions.overlayClusters && ClustersOptions.overlayConditions)
    % Only one graph with Nlines = Nclusters*Ncond
    nbTraces = numel(clustersActivity);
    % Clusters activity = double [Nlines, Nt] 
    clustersActivity = cat(1, clustersActivity{:});
    clustersStd = cat(1, clustersStd{:});
    % Clusters labels = cell-array {Nlines}
    % => "clusterName @ subject/condition"
    for iTrace = 1:nbTraces
        if ~isempty(axesLabels{iTrace})
            clustersLabels{iTrace} = [clustersLabels{iTrace} ' @ ' axesLabels{iTrace}];
        end
    end
    clustersLabels = clustersLabels(:);
    clustersColors = [];
    % Only one graph => legend is common clusters parts
    if ~isempty(strAxesCommon)
        axesLabels = {strAxesCommon};
    else
        axesLabels = {'Mixed subjects'};
    end
    
% === OVERLAY CLUSTERS ONLY ===
elseif ClustersOptions.overlayClusters
    % One graph per condition => Ngraph = Ncond
    % Clusters activity = cell-array {1, Ncond} of doubles [Nclusters, Nt]
    for i = 1:size(clustersActivity,1)
        clustersActivityTmp(i) = {cat(1, clustersActivity{i,:})};
        clustersStdTmp(i) = {cat(1, clustersStd{i,:})};
    end
    clustersActivity = clustersActivityTmp;
    clustersStd = clustersStdTmp;
    % Axes labels (subj/cond) = cell-array of strings {1, Ncond} 
    axesLabels   = axesLabels(:,1)';
    % Clusters labels = cell-array of strings {Ncluster, Ncond} 
    clustersLabels = clustersLabels';
    clustersColors = clustersColors';
    
% === OVERLAY CONDITIONS ONLY ===
elseif ClustersOptions.overlayConditions
    % One graph per cluster => Ngraph = Ncluster
    % Clusters activity = cell-array {1, Ncluster} of doubles [Ncond, Nt]
    for j = 1:size(clustersActivity,2)
        clustersActivityTmp(j) = {cat(1, clustersActivity{:,j})};
        clustersStdTmp(j) = {cat(1, clustersStd{:,j})};
    end
    clustersActivity = clustersActivityTmp;
    clustersStd = clustersStdTmp;
    % Axes labels (cluster names @ common_subject/cond part) = cell-array of strings {1, Ncluster} 
    tmpAxesLabels = axesLabels;
    axesLabels = clustersLabels(1,:);
    % Lines labels (subject/condition) = cell-array of strings {Ncond, Ncluster}  
    clustersLabels = tmpAxesLabels;
    clustersColors = [];
end

% Close progress bar
 bst_progress('stop');

 
%% ===== CALL DISPLAY FUNCTION ====
% Plot time series
[hFig, iDS, iFig] = view_timeseries_matrix(DataFiles{1}, clustersActivity, [], ['$' Modality], axesLabels, clustersLabels, clustersColors, hFig, clustersStd);
% Store results files in figure appdata
setappdata(hFig, 'DataFiles', DataFiles);
setappdata(hFig, 'ClusterLabels', ClusterLabels);
% Update figure name
bst_figures('UpdateFigureName', hFig);
% Set the time label visible
figure_timeseries('SetTimeVisible', hFig, 1);



end

 
