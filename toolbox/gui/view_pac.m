function [hFig, iDS, iFig] = view_pac(PacFile, RowName, PACMode, DisplayMode, isNewFigure)
% VIEW_PAC: Display the directPAC maps calculated for one signal.
%
% USAGE: [hFig, iDS, iFig] = view_pac(PacFile, RowName, PACMode='PAC', DisplayMode='SingleSensor', isNewFigure=0)
%        [hFig, iDS, iFig] = view_pac(PacFile)
%
% INPUT: 
%     - PacFile : Path to time-frequency file to visualize
%     - RowName      : Name of the row to display from the input timefreq file
%                      If empty, displays everything
%     - PACMode      : {'PAC', 'DynamicPAC', 'DynamicNesting'}
%     - DisplayMode  : {'SingleSensor', '2DLayout', '2DLayoutOpt', 'AllSensors', 'TimeSeries', 'Spectrum'}
%     - isNewFigure  : If 1, force the creation of a new figure
%
% OUTPUT : 
%     - hFig : Matlab handle to the figure that was created or updated
%     - iDS  : DataSet index in the GlobalData variable
%     - iFig : Indice of returned figure in the GlobalData(iDS).Figure array

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
% Authors: Francois Tadel, 2013


%% ===== INITIALIZATION =====
global GlobalData;
% Parse inputs
if (nargin < 5) || isempty(isNewFigure) || (isNewFigure == 0)
    isNewFigure = 0;
    CreateMode = '';
else
    CreateMode = 'AlwaysCreate';
end
if (nargin < 4) || isempty(DisplayMode)
    DisplayMode = 'SingleSensor';
end
if (nargin < 3) || isempty(PACMode)
    PACMode = 'PAC';
end
if (nargin < 2) || isempty(RowName)
    RowName = [];
elseif ischar(RowName)
    RowName = {RowName};
end

   
%% ===== GET ALL ACCESSIBLE DATA =====
% Get study
[sStudy, iStudy, iTf] = bst_get('TimefreqFile', PacFile);
if isempty(sStudy)
    error('File is not registered in database.');
end

%% ===== LOAD PAC FILE =====
bst_progress('start', 'View PAC map', 'Loading data...');
% Unload previously loaded files
if ~isempty(strfind(PacFile, '_dpac_fullmaps'))
    iDS = bst_memory('GetDataSetTimefreq', PacFile);
    if ~isempty(iDS)
        bst_memory('UnloadDataSets', iDS);
    end
end
% Load file
if ~isempty(strfind(PacFile, '_dpac_fullmaps')) && strcmpi(PACMode, 'DynamicPAC')
    [iDS, iTimefreq] = bst_memory('LoadTimefreqFile', PacFile, [], [], 1, 'DynamicPAC');
elseif ~isempty(strfind(PacFile, '_dpac_fullmaps')) && strcmpi(PACMode, 'DynamicNesting')
    [iDS, iTimefreq] = bst_memory('LoadTimefreqFile', PacFile, [], [], 1, 'DynamicNesting');
else
    [iDS, iTimefreq] = bst_memory('LoadTimefreqFile', PacFile);
end
% Check for errors
if isempty(iDS)
    hFig = [];
    iFig = [];
    return
end
% Detect modality
Modality = GlobalData.DataSet(iDS).Timefreq(iTimefreq).Modality;
% No row defined: display the first one
if isempty(RowName) && strcmpi(DisplayMode, 'SingleSensor')
    if iscell(GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames)
        RowName = GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames{1};
    else
        RowName = GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames(1);
    end
end

%% ===== DYNAMIC PAC FIGURES =====
% DynamicPAC: Create a pseudo-TF file from the fields DynamicPAC or DynamicNesting
if ~isempty(strfind(PacFile, '_dpac_fullmaps'))
    if ismember(DisplayMode, {'SingleSensor', '2DLayout', '2DLayoutOpt', 'AllSensors'})
        [hFig, iDS, iFig] = view_timefreq(PacFile, DisplayMode, RowName, isNewFigure);
    elseif ismember(DisplayMode, {'TimeSeries', 'Spectrum'})
        [hFig, iDS, iFig] = view_spectrum(PacFile, DisplayMode, RowName, isNewFigure);
    elseif ismember(DisplayMode, {'3DSensorCap', '2DSensorCap', '2DDisc'})
        [hFig, iDS, iFig] = view_topography(PacFile, [], DisplayMode, [], 0);
    end
    return;
end


%% ===== CREATE A NEW FIGURE =====
% Prepare FigureId structure
FigureId.Type     = 'Pac';
FigureId.SubType  = '';
FigureId.Modality = Modality;
% Create TimeSeries figure
[hFig, iFig] = bst_figures('CreateFigure', iDS, FigureId, CreateMode, sStudy.Timefreq(iTf).FileName);
if isempty(hFig)
    bst_error('Cannot create figure', 'View DirectPAC', 0);
    return;
end

%% ===== INITIALIZE FIGURE =====
% Configure app data
setappdata(hFig, 'DataFile',     GlobalData.DataSet(iDS).DataFile);
setappdata(hFig, 'StudyFile',    GlobalData.DataSet(iDS).StudyFile);
setappdata(hFig, 'SubjectFile',  GlobalData.DataSet(iDS).SubjectFile);
% Static dataset
setappdata(hFig, 'isStatic', (GlobalData.DataSet(iDS).Timefreq(iTimefreq).NumberOfSamples <= 2));
isStaticFreq = (size(GlobalData.DataSet(iDS).Timefreq(iTimefreq).TF,3) <= 1);
setappdata(hFig, 'isStaticFreq', isStaticFreq);
% Get figure data
TfInfo = getappdata(hFig, 'Timefreq');
% Create time-freq information structure
TfInfo.FileName = sStudy.Timefreq(iTf).FileName;
TfInfo.Comment  = sStudy.Timefreq(iTf).Comment;
TfInfo.RowName  = RowName;
TfInfo.Function = 'directpac';
% Set figure data
setappdata(hFig, 'Timefreq', TfInfo);
% Set colormap: PAC
bst_colormaps('AddColormapToFigure', hFig, 'pac');
% Display options panel
% isDisplayTab = (length(GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames) > 1);
isDisplayTab = 1;
if isDisplayTab
    gui_brainstorm('ShowToolTab', 'Display');
end


%% ===== PLOT RESULTS =====
figure_pac('UpdateFigurePlot', hFig);


%% ===== UPDATE ENVIRONMENT =====
% Update figure selection
bst_figures('SetCurrentFigure', hFig, 'TF');
% Select display options
if isDisplayTab
    panel_display('UpdatePanel', hFig);
end
% Set figure visible
set(hFig, 'Visible', 'on');
bst_progress('stop');








