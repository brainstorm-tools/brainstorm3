function [hFig, iDS, iFig] = view_timeseries_matrix(BaseFiles, F, TimeVector, Modality, AxesLabels, LinesLabels, LinesColor, hFig, Std)
% VIEW_TIMESERIES_MATRIX: Display times series matrix in a new figure.
%
% USAGE:  [hFig, iDS, iFig] = view_timeseries_matrix(BaseFiles, F, TimeVector=[], Modality=[], AxesLabels=[], LinesLabels=[], LinesColor=[], hFig=[], Std=[])
%         [hFig, iDS, iFig] = view_timeseries_matrix(iDS,       F, TimeVector=[], Modality=[], AxesLabels=[], LinesLabels=[], LinesColor=[], hFig=[], Std=[])
%
% INPUT:
%   - BaseFiles   : Files that figure will be associated with
%   - F           : Cell-array of data matrices to display ([NbRows x NbTime])  {1 x nbData}
%   - TimeVector  : Time vector that match the graphs in F
%   - Modality    : {'MEG', 'MEG MAG', 'MEG GRAD', 'EEG', 'NIRS', 'Other', 'Source', ...}
%   - LinesLabels : Cell array of strings {NbRows}
%   - LinesColor  : Cell array of RGB colors 
%   - hFig        : Specify the figure to draw in
%   - Std         : Standard deviation attached to the F matrix (if F is an average)
%
% OUTPUT: 
%     - hFig : Matlab handle to the 3DViz figure that was created or updated
%     - iDS  : DataSet index in the GlobalData variable
%     - iFig : Indice of returned figure in the GlobalData(iDS).Figure array

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
% Authors: Francois Tadel, 2008-2014


%% ===== PARSE INPUTS =====
global GlobalData;
% Parse inputs
if (nargin < 9) || isempty(Std)
    Std = [];
end
if (nargin < 8) || isempty(hFig)
    hFig = [];
end
if (nargin < 7) || isempty(LinesColor)
    LinesColor = [];
end
if (nargin < 6) || isempty(LinesLabels)
    LinesLabels = {};
end
if (nargin < 5) || isempty(AxesLabels)
    AxesLabels = {};
end
if (nargin < 4) || isempty(Modality)
    Modality = '';
end
if (nargin < 3) || isempty(TimeVector)
    TimeVector = [];
end
if (nargin < 2)
    error('Usage : [hFig, iDS, iFig] = view_timeseries_matrix(BaseFile, F, TimeVector, Modality, AxesLabels, LinesLabels, LinesColor)');
end
% Initialize
ResultsFile = [];
iDS = [];
% BaseFiles: cell list or char
if isempty(BaseFiles)
    BaseFile = [];
elseif iscell(BaseFiles)
    BaseFile = BaseFiles{1};
elseif ischar(BaseFiles)
    BaseFile = BaseFiles;
    BaseFiles = {BaseFiles};
elseif isnumeric(BaseFiles)
    iDS = BaseFiles;
    BaseFile = [];
    BaseFiles = [];
end
% Make sure that F is in a cell array
if ~iscell(F)
    F = {F};
end
if ~isempty(Std) && ~iscell(Std)
    Std = {Std};
end
if ~iscell(AxesLabels)
    AxesLabels = {AxesLabels};
end;
iFig = [];


%% ===== GET A DATASET AND LOAD DATA =====
if ~isempty(iDS)
    FileType = 'matrix';
    FigureType = 'ResultsTimeSeries';
else
    % Get filetype
    FileType = file_gettype(BaseFile);
    % Load file
    switch (FileType)
        case {'data', 'pdata'}
            iDS = bst_memory('LoadDataFile', BaseFile);
            if ~isempty(Modality) && ~strcmpi(Modality, 'Clusters')
                FigureType = 'DataTimeSeries';
            else
                FigureType = 'ResultsTimeSeries';
            end
        case {'results', 'link', 'presults'}
            iDS = bst_memory('LoadResultsFile', BaseFile);
            FigureType = 'ResultsTimeSeries';
            ResultsFile = BaseFile;
        case {'timefreq', 'ptimefreq'}
            iDS = bst_memory('LoadTimefreqFile', BaseFile);
            FigureType = 'ResultsTimeSeries';
            ResultsFile = BaseFile;
        case {'matrix', 'pmatrix'}
            iDS = bst_memory('LoadMatrixFile', BaseFile);
            FigureType = 'ResultsTimeSeries';
        otherwise
            error('Cannot display this file as time series.');
    end
    % If no DataSet is accessible : error
    if isempty(iDS)
        return
    end
end

%% ===== CREATE A NEW FIGURE =====
bst_progress('start', 'View time series', 'Loading data...');
% Use existing figure
if ~isempty(hFig)
     [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
     isNewFig = 0;
% Create new figure
else
    % Prepare FigureId structure
    FigureId.Type     = FigureType;
    FigureId.SubType  = '';
    FigureId.Modality = Modality;
    % Create TimeSeries figure
    [hFig, iFig, isNewFig] = bst_figures('CreateFigure', iDS, FigureId, [], BaseFiles);
    if isempty(hFig)
        bst_error('Cannot create figure', 'View time series matrix', 0);
        return;
    end
end
% Add DataFile to figure appdata
setappdata(hFig, 'DataFile',     GlobalData.DataSet(iDS).DataFile);
setappdata(hFig, 'StudyFile',    GlobalData.DataSet(iDS).StudyFile);
setappdata(hFig, 'SubjectFile',  GlobalData.DataSet(iDS).SubjectFile);
if ~isempty(ResultsFile)
    setappdata(hFig, 'ResultsFile', ResultsFile);
end

%% ===== CONFIGURE FIGURE =====
% Static dataset ?
setappdata(hFig, 'isStatic', (GlobalData.DataSet(iDS).Measures.NumberOfSamples <= 2));
% Get default montage
MontageName = [];
if strcmpi(FileType, 'data')
    sMontage = panel_montage('GetCurrentMontage', Modality);
    if ~isempty(sMontage)
        MontageName = sMontage.Name;
    end
end
% Create topography information structure
TsInfo = db_template('TsInfo');
TsInfo.FileName      = BaseFile;
TsInfo.Modality      = Modality;
TsInfo.AxesLabels    = AxesLabels;
TsInfo.LinesLabels   = LinesLabels;
TsInfo.LinesColor    = LinesColor;
TsInfo.RowNames      = LinesLabels;
TsInfo.MontageName   = MontageName;
TsInfo.NormalizeAmp  = 0;
TsInfo.Resolution    = [0 0];
TsInfo.ShowXGrid     = bst_get('ShowXGrid');
TsInfo.ShowYGrid     = bst_get('ShowYGrid');
TsInfo.ShowZeroLines = bst_get('ShowZeroLines');
TsInfo.ShowEventsMode = bst_get('ShowEventsMode');
if ~isNewFig
    oldTsInfo = getappdata(hFig, 'TsInfo');
    TsInfo.DisplayMode   = oldTsInfo.DisplayMode;
    TsInfo.FlipYAxis     = oldTsInfo.FlipYAxis;
    TsInfo.AutoScaleY    = oldTsInfo.AutoScaleY;
    TsInfo.DefaultFactor = oldTsInfo.DefaultFactor;
    TsInfo.ShowLegend    = oldTsInfo.ShowLegend;
elseif ~isempty(Modality) && ismember(Modality, {'$EEG','$MEG','$MEG GRAD','$MEG MAG','$SEEG','$ECOG'})
    TsInfo.DisplayMode   = bst_get('TSDisplayMode');
    TsInfo.FlipYAxis     = bst_get('FlipYAxis');
    TsInfo.AutoScaleY    = bst_get('AutoScaleY');
    TsInfo.DefaultFactor = figure_timeseries('GetDefaultFactor', Modality);
else
    TsInfo.DisplayMode   = 'butterfly';
    TsInfo.FlipYAxis     = 0;
    TsInfo.AutoScaleY    = 1;
    TsInfo.DefaultFactor = figure_timeseries('GetDefaultFactor', Modality);
end
if ~isempty(strfind(BaseFile, 'matrix_decoding_'))
    TsInfo.YLabel = 'Decoding accuracy (%)';
else
    TsInfo.YLabel = '';
end
setappdata(hFig, 'TsInfo', TsInfo);
% Update figure name
bst_figures('UpdateFigureName', hFig);
% Reset min/max values
if TsInfo.AutoScaleY
    [GlobalData.DataSet(iDS).Figure(iFig).Handles.DataMinMax] = deal([]);
end


%% ===== PLOT TIME SERIES =====
% if isNewFig
%     isFastUpdate = 0;
% else
%     isFastUpdate = 1;
% end
isFastUpdate = 0;
% Plot figure
figure_timeseries('PlotFigure', iDS, iFig, F, TimeVector, isFastUpdate, Std);


%% ===== UPDATE ENVIRONMENT =====
% Uniformize time series scales if required
if isNewFig || isequal(TsInfo.AutoScaleY, 1)
    isUniform = bst_get('UniformizeTimeSeriesScales');
    if ~isempty(isUniform) && (isUniform == 1)
        figure_timeseries('UniformizeTimeSeriesScales', 1); 
    end
end

% Update figure selection
bst_figures('SetCurrentFigure', hFig, '2D');
% Set figure visible
set(hFig, 'Visible', 'on');
bst_progress('stop');


end






