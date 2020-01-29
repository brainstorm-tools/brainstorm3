function [hFig, iDS, iFig] = view_timeseries(DataFile, Modality, RowNames, hFig)
% VIEW_TIMESERIES: Display times series in a new figure.
%
% USAGE: [hFig, iDS, iFig] = view_timeseries(DataFile, Modality=[], RowNames=[], hFig=[])
%        [hFig, iDS, iFig] = view_timeseries(DataFile, Modality=[], RowNames=[], 'NewFigure')
%
% INPUT: 
%     - DataFile  : Path to data file to visualize
%     - Modality  : Modality to display with the input Data file
%     - RowNames  : Cell array of channel names to plot in this figure
%     - "NewFigure" : force new figure creation (do not re-use a previously created figure)
%     - hFig        : Specify the figure in which to display the MRI
%
% OUTPUT : 
%     - hFig : Matlab handle to the 3DViz figure that was created or updated
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
% Authors: Francois Tadel, 2008-2019

%% ===== INITIALIZATION =====
global GlobalData;
% Parse inputs
if (nargin < 3) || isempty(RowNames)
    RowNames = {};
elseif ischar(RowNames)
    RowNames = {RowNames};
end
if (nargin < 2) || isempty(Modality)
    % Get default modality
    [AllMod,DispMod,Modality] = bst_get('ChannelModalities', DataFile);
    % Replace SEEG and ECOG with SEEG+ECOG
    if ~isempty(DispMod) && all(ismember({'SEEG','ECOG'}, DispMod))
        DispMod = cat(2, {'ECOG+SEEG'}, setdiff(DispMod, {'SEEG','ECOG'}));
        if ismember(Modality, {'SEEG','ECOG'})
            Modality = 'ECOG+SEEG';
        end
    elseif ~isempty(AllMod) && ismember(Modality, {'SEEG','ECOG'}) && all(ismember({'SEEG','ECOG'}, AllMod))
        Modality = 'ECOG+SEEG';
        DispMod = union(DispMod, {'ECOG+SEEG','SEEG','ECOG'});
    end
else
    DispMod = [];
end
% Get target figure
if (nargin < 4) || isempty(hFig)
    hFig = [];
    iFig = [];
    NewFigure = 0;
elseif ischar(hFig) && strcmpi(hFig, 'NewFigure')
    hFig = [];
    iFig = [];
    NewFigure = 1;
elseif ishandle(hFig)
    [hFig,iFig,iDS] = bst_figures('GetFigure', hFig);
    NewFigure = 0;
else
    error('Invalid figure handle.');
end


%% ===== GET A DATASET AND LOAD DATA =====
% Get DataFile information
[sStudy, iData, ChannelFile] = bst_memory('GetFileInfo', DataFile);
% If Channel is not defined
if isempty(ChannelFile)
    Modality = 'EEG';
end
% If not loaded yet
if isempty(hFig)
    % Load file
    iDS = bst_memory('LoadDataFile', DataFile);
    % If no DataSet is accessible : error
    if isempty(iDS)
        return
    end
end
% Check that the selected modality can be displayed, if not select another one
if ~isempty(DispMod)
    % List of expected modalities, in order of preference
    AllMod = {'MEG', 'MEG MAG', 'MEG GRAD', 'EEG', 'ECOG', 'SEEG', 'ECOG+SEEG'};
    % Get the list of good modalities 
    GoodMod = unique({GlobalData.DataSet(iDS).Channel(GlobalData.DataSet(iDS).Measures.ChannelFlag == 1).Type});
    GoodMod = intersect(GoodMod, DispMod);
    % Add MEG for Elekta systems
    if any(ismember({'MEG MAG', 'MEG GRAD'}, GoodMod))
        GoodMod{end+1} = 'MEG';
    end
    % Add combined ECOG+SEEG
    if all(ismember({'ECOG', 'SEEG'}, GoodMod))
        GoodMod{end+1} = 'ECOG+SEEG';
    end
    % Get the preferred modalities
    iMod = find(ismember(AllMod, GoodMod));
    GoodMod = AllMod(iMod);
    % If the selected modality is not in the list of the good ones: select the first of the good ones.
    if ~isempty(iMod) && ~ismember(Modality, GoodMod)
        Modality = GoodMod{1};
    end
end


%% ===== CREATE A NEW FIGURE =====
bst_progress('start', 'View time series', 'Loading data...');
if isempty(hFig)
    % Prepare FigureId structure
    FigureId.Type     = 'DataTimeSeries';
    FigureId.SubType  = '';
    FigureId.Modality = Modality;
    % Create TimeSeries figure
    if NewFigure
        [hFig, iFig, isNewFig] = bst_figures('CreateFigure', iDS, FigureId, 'AlwaysCreate', RowNames);
    else
        [hFig, iFig, isNewFig] = bst_figures('CreateFigure', iDS, FigureId, [], RowNames);
    end
    if isempty(hFig)
        bst_error('Could not create figure', 'View time series', 0);
        return;
    end
else
    isNewFig = 0;
end
% Add DataFile to figure appdata
setappdata(hFig, 'DataFile', DataFile);
setappdata(hFig, 'StudyFile',    GlobalData.DataSet(iDS).StudyFile);
setappdata(hFig, 'SubjectFile',  GlobalData.DataSet(iDS).SubjectFile);

%% ===== SELECT ROWS =====
% Select only the channels that we need to plot
if ~isempty(RowNames) 
    % Get the channels normally displayed in this figure
    iSelChanMod = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels;
    AllChannels = {GlobalData.DataSet(iDS).Channel.Name};
    % Remove all spaces
    AllChannels = cellfun(@(c)strrep(c,' ',''), AllChannels, 'UniformOutput', 0);
    RowNames    = cellfun(@(c)strrep(c,' ',''), RowNames,    'UniformOutput', 0);
    % Get the channels that are requested from the command line call (RowNames argument)
    iSelChanCall = [];
    for i = 1:length(RowNames)
        iSelChanCall = [iSelChanCall, find(strcmpi(RowNames{i}, AllChannels))];
    end
    % Keep only the intersection of the two selections (if non-empty)
    if ~isempty(iSelChanCall) && ~isempty(intersect(iSelChanMod, iSelChanCall))
        GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels = intersect(iSelChanMod, iSelChanCall);
    end
    % Redraw position of figures
    if (iFig > 1)
        gui_layout('Update');
    end
end

%% ===== CONFIGURE FIGURE =====
% Static dataset ?
setappdata(hFig, 'isStatic', (GlobalData.DataSet(iDS).Measures.NumberOfSamples <= 2));
% Raw file
isRaw = strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'raw');
% Statistics?
% isStat = strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'stat');
isStat = ~ismember(GlobalData.DataSet(iDS).Measures.DataType, {'recordings', 'raw'});

% Create time-series information structure
if isNewFig
    % Create figure structure
    TsInfo = db_template('TsInfo');
    TsInfo.FileName      = DataFile;
    TsInfo.Modality      = Modality;
    TsInfo.DisplayMode   = bst_get('TSDisplayMode');
    TsInfo.LinesLabels   = {};
    TsInfo.AxesLabels    = {};
    TsInfo.LinesColor    = {};
    TsInfo.RowNames      = RowNames;
    TsInfo.MontageName   = [];
    TsInfo.DefaultFactor = figure_timeseries('GetDefaultFactor', Modality);
    TsInfo.FlipYAxis     = ~isempty(Modality) && ismember(Modality, {'EEG','MEG','MEG GRAD','MEG MAG','SEEG','ECOG','NIRS'}) && ~isStat && bst_get('FlipYAxis');
    TsInfo.AutoScaleY    = bst_get('AutoScaleY');
    TsInfo.NormalizeAmp  = 0;
    TsInfo.Resolution    = [0 0];
    TsInfo.ShowXGrid     = bst_get('ShowXGrid');
    TsInfo.ShowYGrid     = bst_get('ShowYGrid');
    TsInfo.ShowZeroLines = bst_get('ShowZeroLines');
    TsInfo.ShowEventsMode = bst_get('ShowEventsMode');
    % Hide events only for multiple RAW figures
    allId = [GlobalData.DataSet(iDS).Figure(1:iFig-1).Id];
    TsInfo.ShowEvents = ~isRaw || ((iFig == 1) || ~any(strcmpi({allId.Type}, 'DataTimeSeries')));
else
    TsInfo = getappdata(hFig, 'TsInfo');
    TsInfo.FileName = DataFile;
end
setappdata(hFig, 'TsInfo', TsInfo);
% Get default montage
if isNewFig
    sMontage = panel_montage('GetCurrentMontage', Modality);
    % If displaying a SEEG for which a bipolar montage has already been applied: ignore current montage
    if ~isempty(sMontage) && isempty(RowNames) && strcmpi(Modality, 'SEEG') && all(cellfun(@(c)any(c=='-'), {GlobalData.DataSet(iDS).Channel.Name}))
        TsInfo.MontageName = [];
    % Use previous montage
    elseif ~isempty(sMontage) && isempty(RowNames) && (~isStat || strcmpi(sMontage.Type, 'selection')) && ~ismember(sMontage.Name, {'ICA components[tmp]', 'SSP components[tmp]'})
        TsInfo.MontageName = sMontage.Name;
    else
        TsInfo.MontageName = [];
    end
    setappdata(hFig, 'TsInfo', TsInfo);
end
% If no bad channels are available: do not accept bad channels montage
if isequal(TsInfo.MontageName, 'Bad channels') && ~any(GlobalData.DataSet(iDS).Measures.ChannelFlag == -1)
    TsInfo.MontageName = [];
    setappdata(hFig, 'TsInfo', TsInfo);
end
% Default display mode: Force to 'butterfly' if there is only one channel to display
if isequal(TsInfo.MontageName, 'Bad channels')
    nChan = nnz(GlobalData.DataSet(iDS).Measures.ChannelFlag == -1);
else
    nChan = length(GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels);
end
if (nChan == 1) && strcmpi(TsInfo.DisplayMode, 'column')
    TsInfo.DisplayMode = 'butterfly';
    setappdata(hFig, 'TsInfo', TsInfo);
end


%% ===== PLOT TIME SERIES =====
% Update figure selection
bst_figures('SetCurrentFigure', hFig, '2D');
% Plot figure
isOk = figure_timeseries('PlotFigure', iDS, iFig);
% Some error occured during the display procedure: close the window and stop process
if ~isOk
    close(hFig);
    return;
end


%% ===== UPDATE ENVIRONMENT =====
% Uniformize time series scales if required
isUniform = bst_get('UniformizeTimeSeriesScales');
if ~isempty(isUniform) && (isUniform == 1)
    figure_timeseries('UniformizeTimeSeriesScales', 1); 
end
% Set the Y scale factor if necessary
if isRaw && ~isempty(Modality) && (Modality(1) ~= '$')
    newScale = bst_get('FixedScaleY', [Modality, TsInfo.DisplayMode]);
    if ~isempty(newScale)
        figure_timeseries('SetScaleY', iDS, iFig, newScale);
    end
end
% Set figure visible
if strcmpi(get(hFig,'Visible'), 'off')
    set(hFig, 'Visible', 'on');
end
% Set the time label visible
figure_timeseries('SetTimeVisible', hFig, 1);
% Last updates 
if isNewFig
    % Update record tab
    panel_record('UpdateDisplayOptions', hFig);
    % Update stat tab
    if isStat
        panel_stat('CurrentFigureChanged_Callback', hFig);
    % Select Record tab
    else
        gui_brainstorm('SetSelectedTab', 'Record');
    end
else
    % Update figure name
    bst_figures('UpdateFigureName', hFig);
end
% Close progress bar
drawnow;
bst_progress('stop');



