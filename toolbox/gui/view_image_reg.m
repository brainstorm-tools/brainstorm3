function [hFig, iDS, iFig] = view_image_reg(Data, Labels, iDims, DimLabels, FileName, hFig, ColormapType, ShowLabels, PageName, DisplayUnits)
% VIEW_IMAGE_REG: Display an image, with possible variations in time and frequencies.
%
% USAGE: [hFig, iDS, iFig] = view_image_reg(Data, Labels=[], iDims=[1,2], DimLabels=[], FileName=[], hFig=[], ColormapType='image', ShowLabels=0, PageName=[first], DisplayUnits=[])
%
% INPUT: 
%     - Data         : [N1 x N2 x Ntime x Nfreq] numeric matrix to display
%     - Labels       : [1x4] cell array with the labels of the entries of each dimentions
%     - iDims        : Indices of the dimensions that are displayed along axes x and y
%     - DimLabels    : [1x4] cell array with the description of each dimension
%     - FileName     : Relative path to the file to display
%     - hFig         : Re-use an existing figure
%     - ColormapType : Name of the colormap to use for this figure
%     - ShowLabels   : If 1, show the labels on the Y axis
%     - PageName     : Name of the page that is currently displayed in the file
%                      Set to '$freq' to link the 4th dimension of the data to the frequency slider
%     - DisplayUnits : Units to display below the colorbar
%
% OUTPUT : 
%     - hFig : Matlab handle to the figure that was created or updated
%     - iDS  : DataSet index in the GlobalData variable
%     - iFig : Indice of returned figure in the GlobalData(iDS).Figure array

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
% Authors: Francois Tadel, 2014-2016


%% ===== INITIALIZATION =====
global GlobalData;
% Parse inputs
if (nargin < 10) || isempty(DisplayUnits)
    DisplayUnits = [];
end
if (nargin < 9) || isempty(PageName)
    PageName = [];
end
if (nargin < 8) || isempty(ShowLabels)
    ShowLabels = [];
end
if (nargin < 7) || isempty(ColormapType)
    ColormapType = 'image';
end
if (nargin < 6) || isempty(hFig)
    hFig = [];
    CreateMode = 'AlwaysCreate';
else
    CreateMode = '';
end
if (nargin < 5) || isempty(FileName)
    FileName = [];
end
if (nargin < 3) || (length(iDims) ~= 2)
    iDims = [1 2];
end
if (nargin < 4) || (length(DimLabels) ~= 2)
    DimLabels = {sprintf('Dimension %d', iDims(1)), sprintf('Dimension %d', iDims(2))};
end
if (nargin < 2) || isempty(Labels)
    Labels = [];
end
if isempty(Labels)
    ShowLabels = 0;
elseif isempty(ShowLabels)
    ShowLabels = 0;
end

%% ===== GET ALL ACCESSIBLE DATA =====
iDS = [];
iTimefreq = [];
% Re-use existing figure
if ~isempty(hFig)
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    StudyFile = GlobalData.DataSet(iDS).StudyFile;
% If display is related to a file
elseif ~isempty(FileName)
    % Get study
    [sStudy, iStudy, iFile, DataType] = bst_get('AnyFile', FileName);
    if isempty(sStudy)
        error('File is not registered in database.');
    end
    StudyFile = sStudy.FileName;
    % Get existing dataset
    switch (DataType)
        case {'data','pdata'}
            iDS = bst_memory('GetDataSetData', FileName);
        case {'results', 'link', 'presults'}
            iDS = bst_memory('GetDataSetResult', FileName);
        case {'timefreq', 'ptimefreq'}
            [iDS, iTimefreq] = bst_memory('GetDataSetTimefreq', FileName);
        case {'matrix', 'pmatrix'}
            iDS = bst_memory('GetDataSetMatrix', FileName);
    end
    if isempty(iDS)
        iDS = bst_memory('GetDataSetStudy', StudyFile);
    end
    % Create new dataset
    if isempty(iDS)
        iDS = bst_memory('GetDataSetEmpty');
        GlobalData.DataSet(iDS).SubjectFile = file_short(sStudy.BrainStormSubject);
        GlobalData.DataSet(iDS).StudyFile   = file_short(sStudy.FileName);
    else
        iDS = iDS(1);
    end
else
    % Create new dataset
    iDS = bst_memory('GetDataSetEmpty');
    StudyFile = [];
end


%% ===== CREATE A NEW FIGURE =====
if isempty(hFig)
    % Prepare FigureId structure
    FigureId.Type     = 'Image';
    FigureId.SubType  = '';
    FigureId.Modality = '';
    % Create TimeSeries figure
    [hFig, iFig] = bst_figures('CreateFigure', iDS, FigureId, CreateMode, StudyFile);
    if isempty(hFig)
        bst_error('Cannot create figure', 'View image', 0);
        return;
    end
    % First page displayed = first row
    if isempty(PageName) && ~isempty(Labels{4})
        PageName = Labels{4}{1};
    end
% Frequency figures
elseif isempty(GlobalData.DataSet(iDS).Figure(iFig).Handles.PageName) || isequal(GlobalData.DataSet(iDS).Figure(iFig).Handles.PageName, '$freq')
    PageName = GlobalData.DataSet(iDS).Figure(iFig).Handles.PageName;
% ERPimage figures
else
    if ismember(GlobalData.DataSet(iDS).Figure(iFig).Handles.PageName, Labels{4})
        PageName = GlobalData.DataSet(iDS).Figure(iFig).Handles.PageName;
    else
        PageName = Labels{4}{1};
    end
end
% Connectivity matrix: use equal axes
if ~isempty(FileName) && strcmpi(file_gettype(FileName), 'timefreq') && ~isempty(strfind(FileName, '_connectn'))
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'AxesImage');
    set(hAxes, 'DataAspectRatio', [1 1 1]);
end


%% ===== INITIALIZE FIGURE =====
% Save data and labels
GlobalData.DataSet(iDS).Figure(iFig).Handles.Data         = Data;
GlobalData.DataSet(iDS).Figure(iFig).Handles.Labels       = Labels;
GlobalData.DataSet(iDS).Figure(iFig).Handles.iDims        = iDims;
GlobalData.DataSet(iDS).Figure(iFig).Handles.DimLabels    = DimLabels;
GlobalData.DataSet(iDS).Figure(iFig).Handles.ColormapType = ColormapType;
GlobalData.DataSet(iDS).Figure(iFig).Handles.ShowLabels   = ShowLabels;
GlobalData.DataSet(iDS).Figure(iFig).Handles.PageName     = PageName;
% Only for connectivity files
if ~isempty(iTimefreq) && ~isempty(GlobalData.DataSet(iDS).Timefreq(iTimefreq).RefRowNames)
    % If there are some self-connectivity values in the displayed matrix
    if any(ismember(GlobalData.DataSet(iDS).Timefreq(iTimefreq).RefRowNames, GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames))
        GlobalData.DataSet(iDS).Figure(iFig).Id.SubType = 'self_connect';
        GlobalData.DataSet(iDS).Figure(iFig).Handles.HideSelfConnect = 1;
    else
        GlobalData.DataSet(iDS).Figure(iFig).Id.SubType = '';
        GlobalData.DataSet(iDS).Figure(iFig).Handles.HideSelfConnect = 0;
    end
end
% By default: link the 4th dimension of the data to the frequency slider
isFreq = isequal(PageName, '$freq');
% Configure figure
isStatic = (size(Data,3) <= 1) || ...
           ((size(Data,3) == 2) && isequal(Data(:,:,1,:,:), Data(:,:,2,:,:)));
setappdata(hFig, 'isStatic', isStatic);
setappdata(hFig, 'isStaticFreq', ~isFreq || size(Data,4) < 2);
setappdata(hFig, 'FileName', FileName);
% Set colormap
bst_colormaps('AddColormapToFigure', hFig, ColormapType, DisplayUnits);


%% ===== PLOT RESULTS =====
% Plot image
figure_image('UpdateFigurePlot', hFig, 1);
% Update figure title
bst_figures('UpdateFigureName', hFig);
% Set figure visible
set(hFig, 'Visible', 'on');
bst_progress('stop');

% Update figure selection
bst_figures('SetCurrentFigure', hFig, '2D');








