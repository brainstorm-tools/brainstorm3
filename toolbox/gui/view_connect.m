function [hFig, iDS, iFig] = view_connect(TimefreqFile, DisplayMode, hFig)
% VIEW_CONNECT: Display a NxN connectivity matrix
%
% USAGE: [hFig, iDS, iFig] = view_connect(TimefreqFile, DisplayMode='GraphFull', hFig=[])
%
% INPUT: 
%     - TimefreqFile : Path to connectivity file to visualize
%     - DisplayMode  : {'GraphFull'}
%     - hFig         : If defined, display file in existing figure
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
% Authors: Francois Tadel, 2012-2016; Martin Cousineau, 2019-2021;
% Helen Lin & Yaqi Li, 2020-2021

%% ===== PARSE INPUTS =====
if (nargin < 2)
    DisplayMode = 'GraphFull';
end
if (nargin < 3) || isempty(hFig) || isequal(hFig,0)
    hFig = [];
    CreateMode = [];
elseif isequal(hFig,'NewFigure')
    hFig = [];
    CreateMode = 'AlwaysCreate';
end

% If fibers are requested, plot the graph as well
if strcmpi(DisplayMode, 'Fibers')
    DisplayMode = 'GraphFull';
    plotFibers = 1;
else
    plotFibers = 0;
end

% Initializations
global GlobalData;
iDS = [];
iFig = [];

if (strcmpi(DisplayMode, 'GraphFull'))
    % Visualization tool only available starting from R2014b
    if bst_get('MatlabVersion') < 804
        bst_error(['The connectivity graph is not available for your version of Matlab.' 10 ...
                   'It is only available starting from MATLAB Release 2014b.'], 'View connectivity graph', 0);
        return;
    end    
end


%% ===== LOAD CONNECT FILE =====
% Find file in database
switch file_gettype(TimefreqFile)
    case 'timefreq'
        [sStudy, iStudy, iTf] = bst_get('TimefreqFile', TimefreqFile);
        if isempty(sStudy)
            error('File is not registered in database.');
        end
        sTimefreq = sStudy.Timefreq(iTf);
        isStat = 0;
    case 'ptimefreq'
        [sStudy, iStudy, iStat] = bst_get('StatFile', TimefreqFile);
        if isempty(sStudy)
            error('File is not registered in database.');
        end
        sTimefreq = sStudy.Stat(iStat);
        isStat = 1;
    otherwise
        error('File type not supported.');
end

% Progress bar
bst_progress('start', 'View connectivity map', 'Loading data...');
% Load file
[iDS, iTimefreq] = bst_memory('LoadTimefreqFile', TimefreqFile);
if isempty(iDS)
    return;
end

% Detect modality
Modality = GlobalData.DataSet(iDS).Timefreq(iTimefreq).Modality;
% Check that the matrix is square, and have same RowNames cannot display [NxM] connectivity matrix where N~=M
if ~isequal(GlobalData.DataSet(iDS).Timefreq(iTimefreq).RefRowNames, GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames) && ~strcmpi(DisplayMode, 'Image')
    bst_error('The connectivity matrix cannot be displayed as the row and column names are not equal', 'View connectivity matrix', 0);
    return;
end


%% ===== DISPLAY AS IMAGE =====
% Display as image
if strcmpi(DisplayMode, 'Image')
    if ismember(GlobalData.DataSet(iDS).Timefreq(iTimefreq).Measure, 'none')
        TfFunction = 'magnitude';
    else
        TfFunction = 'other';
    end
    % Get values
    TF = bst_memory('GetTimefreqValues', iDS, iTimefreq, [], [], [], TfFunction);
    % Get connectivity matrix
    C = bst_memory('ReshapeConnectMatrix', iDS, iTimefreq, TF);
    % Get time vector
    if (size(TF,3) < 2)
        TimeVector = [];
    else
        TimeVector = GlobalData.DataSet(iDS).Timefreq(iTimefreq).Time;
    end
    % In Granger 1xN "in" case: reverse the xlabel/ylabel
    if ismember(GlobalData.DataSet(iDS).Timefreq(iTimefreq).Method, {'granger', 'spgranger'}) && isfield(GlobalData.DataSet(iDS).Timefreq(iTimefreq).Options, 'GrangerDir') ...
            && isequal(GlobalData.DataSet(iDS).Timefreq(iTimefreq).Options.GrangerDir, 'in')
        DimLabels = {'To (A)', 'From (B)'};
    else
        DimLabels = {'From (A)', 'To (B)'};
    end
    % Plot as a flat image
    Labels = {GlobalData.DataSet(iDS).Timefreq(iTimefreq).RefRowNames, ...
              GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames, ...
              TimeVector, ...
              GlobalData.DataSet(iDS).Timefreq(iTimefreq).Freqs};
    [hFig, iDS, iFig] = view_image_reg(C, Labels, [1,2], DimLabels, TimefreqFile, hFig, [], 1, '$freq', GlobalData.DataSet(iDS).Timefreq(iTimefreq).DisplayUnits);
    % Reload call
    ReloadCall = {'view_connect', TimefreqFile, DisplayMode, hFig};
    setappdata(hFig, 'ReloadCall', ReloadCall);
    % Close progress bar and return
    bst_progress('stop');
    return;
end


%% ===== CREATE MATLAB FIGURE =====
if isempty(hFig)
    % Prepare FigureId structure
    FigureId          = db_template('FigureId');
    FigureId.Type     = 'Connect';
    FigureId.SubType  = DisplayMode;
    FigureId.Modality = Modality;
    % Create figure
    [hFig, iFig, isNewFig] = bst_figures('CreateFigure', iDS, FigureId, CreateMode, sTimefreq.FileName);   
    % If figure was not created: Display an error message and return
    if isempty(hFig)
        bst_error('Cannot create figure', 'View connectivity matrix', 0);
        return;
    end
else
    [hFig,iFig,iDS] = bst_figures('GetFigure', hFig);
end
% If it is not a new figure: reinitialize it
if ~isNewFig
    figure_connect('ResetDisplay', hFig);
end

%% ===== DISPLAY FIBERS =====
if plotFibers
    bst_progress('start', 'View connectivity map', 'Loading fibers...');
    % Get necessary surface files
    sSubject = bst_get('Subject', sStudy.BrainStormSubject);
    try
        surfaceFile = sSubject.Surface(sSubject.iCortex).FileName;
        fibersFile = sSubject.Surface(sSubject.iFibers).FileName;
        assert(~isempty(surfaceFile) && ~isempty(fibersFile));
    catch
        bst_error('Cannot display connectivity results on fibers without fibers and cortex files.');
        return;
    end
    
    % Prepare fibers figure
    FigureFibId = db_template('FigureId');
    FigureFibId.Type = '3DViz';
    hFigFib = bst_figures('CreateFigure', iDS, FigureFibId);
    setappdata(hFigFib, 'EmptyFigure', 1);

    % Display fibers
    hFigFib = view_surface(fibersFile, [], [], hFigFib);
    GlobalData.DataSet(iDS).Figure(iFig).Handles.hFigFib = hFigFib;
    
    % Display cortex surface
    panel_surface('AddSurface', hFigFib, surfaceFile);
    % Add transparency to cortex surface
    iSurface = getappdata(hFigFib, 'iSurface');
    panel_surface('SetSurfaceTransparency', hFigFib, iSurface, 0.8);
end


%% ===== INITIALIZE FIGURE =====
% Configure app data
setappdata(hFig, 'DataFile',     GlobalData.DataSet(iDS).DataFile);
setappdata(hFig, 'StudyFile',    GlobalData.DataSet(iDS).StudyFile);
setappdata(hFig, 'SubjectFile',  GlobalData.DataSet(iDS).SubjectFile);
setappdata(hFig, 'plotFibers',   plotFibers);

% Static dataset
isStatic = (GlobalData.DataSet(iDS).Timefreq(iTimefreq).NumberOfSamples <= 1) || ...
           ((GlobalData.DataSet(iDS).Timefreq(iTimefreq).NumberOfSamples == 2) && isequal(GlobalData.DataSet(iDS).Timefreq(iTimefreq).TF(:,1,:,:,:), GlobalData.DataSet(iDS).Timefreq(iTimefreq).TF(:,2,:,:,:)));
setappdata(hFig, 'isStatic', isStatic);
isStaticFreq = (size(GlobalData.DataSet(iDS).Timefreq(iTimefreq).TF,3) <= 1);
setappdata(hFig, 'isStaticFreq', isStaticFreq);

% Get figure data
TfInfo = getappdata(hFig, 'Timefreq');
% Create time-freq information structure
TfInfo.FileName    = sTimefreq.FileName;
TfInfo.Comment     = sTimefreq.Comment;
TfInfo.DisplayMode = DisplayMode;
TfInfo.InputTarget = [];
TfInfo.RowName     = [];
IsDirectionalData = 0;
IsBinaryData = 0;
ThresholdAbsoluteValue = 0;

switch (GlobalData.DataSet(iDS).Timefreq(iTimefreq).Method)
    case 'corr',     TfInfo.Function = 'other';
                     ThresholdAbsoluteValue = 1;
    case 'cohere',   TfInfo.Function = 'other';
    case 'granger',  TfInfo.Function = 'other';
                     IsDirectionalData = 1;
                     IsBinaryData = 1;
    case 'spgranger',TfInfo.Function = 'other';
                     IsDirectionalData = 1;
                     IsBinaryData = 1;
    case 'henv',     TfInfo.Function = 'other';
    case 'pte',  TfInfo.Function = 'other';
                 IsDirectionalData = 1;
    case {'plv', 'plvt', 'ciplv', 'ciplvt', 'wpli', 'wplit'}
        if strcmpi(GlobalData.DataSet(iDS).Timefreq(iTimefreq).Measure, 'other')
            TfInfo.Function = 'other';
        else
            TfInfo.Function = 'magnitude';
        end
    otherwise,       TfInfo.Function = 'other';
end

% Update figure variable
setappdata(hFig, 'Method', GlobalData.DataSet(iDS).Timefreq(iTimefreq).Method);
setappdata(hFig, 'IsDirectionalData', IsDirectionalData);
setappdata(hFig, 'IsBinaryData', IsBinaryData);
setappdata(hFig, 'ThresholdAbsoluteValue', ThresholdAbsoluteValue);
setappdata(hFig, 'is3DDisplay', 0); 

% Frequency selection
if isStaticFreq
    TfInfo.iFreqs = [];
else
    TfInfo.iFreqs = GlobalData.UserFrequencies.iCurrentFreq;
end
% Display units
TfInfo.DisplayUnits = GlobalData.DataSet(iDS).Timefreq(iTimefreq).DisplayUnits;
% Set figure data
setappdata(hFig, 'Timefreq', TfInfo);
% Display options panel (not for stat, as the thresholding is already done)
if ~isStat
    gui_brainstorm('ShowToolTab', 'Display');
end

%% ===== DRAW FIGURE =====
figure_connect('LoadFigurePlot', hFig);

%% ===== UPDATE ENVIRONMENT =====
% Update figure selection
bst_figures('SetCurrentFigure', hFig, 'TF');
% Select display options
panel_display('UpdatePanel', hFig);
% Set figure visible
set(hFig, 'Visible', 'on');
bst_progress('stop');

