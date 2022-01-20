function [hFig, iDS, iFig] = view_timefreq(TimefreqFile, DisplayMode, RowName, isNewFigure, Function)
% VIEW_TIMEFREQ: Display times frequency maps in a new figure.
%
% USAGE: [hFig, iDS, iFig] = view_timefreq(TimefreqFile, DisplayMode='SingleSensor', RowName=[], isNewFigure=0, Function=[])
%
% INPUT: 
%     - TimefreqFile : Path to time-frequency file to visualize
%     - DisplayMode  : {'SingleSensor', 'AllSensors', '2DLayout', '2DLayoutOpt'}
%     - RowName      : Name of the row to display from the input timefreq file
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
% Authors: Francois Tadel, 2010-2014


%% ===== INITIALIZATION =====
% GlobalData : create if not existing yet
global GlobalData;
% Parse inputs
if (nargin < 2)
    DisplayMode = 'SingleSensor';
end
if (nargin < 3) || isempty(RowName)
    RowName = [];
elseif iscell(RowName)
    RowName = RowName{1};
end
if (nargin < 4) || isempty(isNewFigure) || (isNewFigure == 0)
    CreateMode = '';
else
    CreateMode = 'AlwaysCreate';
end
if (nargin < 5) || isempty(Function)
    Function = [];
end

if ~isempty(strfind(lower(TimefreqFile), 'spike_field_coherence')) ...
        || ~isempty(strfind(lower(TimefreqFile), 'noise_correlation')) ...
        || ~isempty(strfind(lower(TimefreqFile), 'rasterplot'))...
        || ~isempty(strfind(lower(TimefreqFile), 'spiking_phase_locking'))
    isEphysFile = 1;
    GlobalData.UserFrequencies.HideFreqPanel = 1;
else
    isEphysFile = 0;
end

%% ===== GET ALL ACCESSIBLE DATA =====
% Get study
[sStudy, iStudy, iItem, DataType, sTimefreq] = bst_get('AnyFile', TimefreqFile);
if isempty(sStudy)
    error('File is not registered in database.');
end

%% ===== LOAD TIME-FREQUENCY FILE =====
bst_progress('start', 'View time-frequency map', 'Loading data...');
% Load file
[iDS, iTimefreq] = bst_memory('LoadTimefreqFile', TimefreqFile);
if isempty(iDS)
    % error('Cannot load timefreq file.');
    hFig = [];
    iFig = [];
    return
end
% If there is only one row available: for DisplayMode to 'SingleSensor'
if (length(GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames) == 1)
    DisplayMode = 'SingleSensor';
end
% Detect modality
Modality = GlobalData.DataSet(iDS).Timefreq(iTimefreq).Modality;
AllModalities = GlobalData.DataSet(iDS).Timefreq(iTimefreq).AllModalities;
LayoutRows = [];
% Get the all row names for this file
AllRows = figure_timefreq('GetRowNames', GlobalData.DataSet(iDS).Timefreq(iTimefreq).RefRowNames, GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames);
% Check display type
if any(strcmpi(DisplayMode, {'2DLayout', '2DLayoutOpt'}))
    % Sensor types that cannot be displayed
    if ~isempty(Modality) && ~ismember(Modality, {'MEG','MEG GRAD','MEG MAG','EEG','NIRS'})
        disp(['TIMEFREQ> Error: Cannot display 2DLayout for modality "' Modality '", using AllSensors instead.']);
        DisplayMode = 'AllSensors';
    % If there are multiple modalities available in the file
    elseif isempty(Modality) && ~isempty(AllModalities)
        % Check for main sensor categories
        DispMod = intersect(AllModalities, {'MEG','MEG GRAD','MEG MAG','EEG','ECOG','NIRS'});
        % No available display types
        if isempty(DispMod)
            Modality = [];
        % If there are multiple modalities but one only that can be displayed as a topography
        elseif (length(DispMod) == 1)
            Modality = DispMod{1};
        % Else: ask user what to display
        elseif ~isempty(DispMod)
            res = java_dialog('question', ['This file contains multiple sensor types.' 10 'Which modality would you like to display?'], 'Select sensor type', [], DispMod);
            if isempty(res) || strcmpi(res, 'Cancel')
                return;
            else
                Modality = res;
            end
        end
        % Get the displayed rows only
        if ~isempty(Modality)
            iChan = channel_find(GlobalData.DataSet(iDS).Channel, Modality);
            LayoutRows = intersect(AllRows, {GlobalData.DataSet(iDS).Channel(iChan).Name});
        end
    end
    % No solution found
    if isempty(Modality)
        disp('TIMEFREQ> Error: Cannot display 2DLayout for this file, using AllSensors instead.');
        DisplayMode = 'AllSensors';
    end
end
% Make sure that the required row names are available
if ~isempty(RowName) && ischar(RowName) && ~ismember(RowName, AllRows)
    error(['There is no entry "' RowName '" in this file.']);
end


%% ===== CREATE A NEW FIGURE =====
% Prepare FigureId structure
FigureId.Type     = 'Timefreq';
FigureId.SubType  = DisplayMode;
FigureId.Modality = Modality;
% Create TimeSeries figure
[hFig, iFig] = bst_figures('CreateFigure', iDS, FigureId, CreateMode, sTimefreq.FileName);
if isempty(hFig)
    error('Cannot create figure');
end

%% ===== INITIALIZE FIGURE =====
% Configure app data
setappdata(hFig, 'DataFile',     GlobalData.DataSet(iDS).DataFile);
setappdata(hFig, 'StudyFile',    GlobalData.DataSet(iDS).StudyFile);
setappdata(hFig, 'SubjectFile',  GlobalData.DataSet(iDS).SubjectFile);
% Static dataset
setappdata(hFig, 'isStatic',     (GlobalData.DataSet(iDS).Timefreq(iTimefreq).NumberOfSamples <= 2));
%setappdata(hFig, 'isStaticFreq', (size(GlobalData.DataSet(iDS).Timefreq(iTimefreq).TF,3) <= 1));
setappdata(hFig, 'isStaticFreq', 0);
% Get figure data
TfInfo = getappdata(hFig, 'Timefreq');
% Create options structure
TfInfo.FileName    = sTimefreq.FileName;
TfInfo.Comment     = sTimefreq.Comment;
TfInfo.DisplayMode = DisplayMode;
TfInfo.iFreqs      = [];
if ismember(TfInfo.DisplayMode, {'2DLayout', '2DLayoutOpt', 'AllSensors'})
    TfInfo.RowName = LayoutRows;
elseif ~isempty(RowName)
    TfInfo.RowName = RowName;
elseif iscell(AllRows)
    TfInfo.RowName = AllRows{1};
else
    TfInfo.RowName = AllRows(1);
end
% Default function
if isEphysFile
    TfInfo.Function = 'power';
    TfInfo.DisplayMeasure = 0;
    TfInfo.DisableHideEdgeEffects = 1;
elseif ~isempty(Function)
    TfInfo.Function = Function;
else
    TfInfo.Function = process_tf_measure('GetDefaultFunction', GlobalData.DataSet(iDS).Timefreq(iTimefreq));
end
% EPhys specific fields
if ~isempty(strfind(lower(TimefreqFile), 'noise_correlation'))
    DataMat = in_bst_data(TimefreqFile, 'NeuronNames');
    TfInfo.NeuronNames = DataMat.NeuronNames;
elseif ~isempty(strfind(lower(TimefreqFile), 'rasterplot'))
    TfInfo.DisplayAsDots = 1;
    TfInfo.DisableSmoothDisplay = 1;
elseif ~isempty(strfind(lower(TimefreqFile), 'spiking_phase_locking'))
    TfInfo.DisplayAsPhase = 1;
end
% Set figure data
setappdata(hFig, 'Timefreq', TfInfo);
% Add colormap (stat or timefreq)
if ~isempty(GlobalData.DataSet(iDS).Timefreq(iTimefreq).ColormapType)
    ColormapType = GlobalData.DataSet(iDS).Timefreq(iTimefreq).ColormapType;
elseif strcmpi(file_gettype(TimefreqFile), 'ptimefreq') || ~isempty(strfind(lower(TimefreqFile), 'zscore')) || ~isempty(strfind(lower(TimefreqFile), 'ersd'))
    ColormapType = 'stat2';
else
    ColormapType = 'timefreq';
end
% Display units
DisplayUnits = GlobalData.DataSet(iDS).Timefreq(iTimefreq).DisplayUnits;
% Add colormap to figure
bst_colormaps('AddColormapToFigure', hFig, ColormapType, DisplayUnits);
% Display options panel
isDisplayTab = ~strcmpi(TfInfo.Function, 'other') || (~isempty(TfInfo.RowName) && (ischar(TfInfo.RowName) || iscell(TfInfo.RowName)));
if isDisplayTab
    gui_brainstorm('ShowToolTab', 'Display');
end


%% ===== PLOT DATA =====
% Plot time-freq map
figure_timefreq('UpdateFigurePlot', hFig);
% Update figure name
bst_figures('UpdateFigureName', hFig);


%% =====  DISPLAY FIGURE =====
% Reset selected figure, so that the following figure selection can update the timefreq panel
bst_figures('SetCurrentFigure', [], 'TF');
% Set selected figure
bst_figures('SetCurrentFigure', hFig, 'TF');
% Select display options
if isDisplayTab
    panel_display('UpdatePanel', hFig);
end
% Set figure visible
set(hFig, 'Visible', 'on');
bst_progress('stop');



end





