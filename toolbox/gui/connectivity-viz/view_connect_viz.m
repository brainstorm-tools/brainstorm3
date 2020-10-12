function [hFig, iDS, iFig] = view_connect_viz(TimefreqFile, DisplayMode, hFig)
% VIEW_CONNECT_VIZ: Display a NxN connectivity matrix
%
% USAGE: [hFig, iDS, iFig] = view_connect_viz(TimefreqFile, DisplayMode='GraphFull', hFig=[])
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
% Authors: Francois Tadel, 2012-2016; Martin Cousineau, 2019; Helen Lin &
% Yaqi Li, 2020



%% ===== PARSE INPUTS =====

disp('view_connect_viz.m reached') % @TODO: remove test

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

% Initializations
global GlobalData;
iDS = [];
iFig = [];

% @TODO: remove once OpenGL is no longer needed
% Check if OpenGL is activated
if strcmpi(DisplayMode, 'GraphFull')
%     if (bst_get('DisableOpenGL') == 1)
%         bst_error(['Connectivity graphs require the OpenGL rendering to be enabled.' 10 ...
%                    'Please go to File > Edit preferences...'], 'View connectivity matrix', 0);
%         return;
%     else
    if ~exist('org.brainstorm.connect.GraphicsFramework', 'class')
        bst_error(['The OpenGL connectivity graph is not available for your version of Matlab.' 10 10 ...
                   'You can use these tools by running the compiled version: ' 10 ...
                   'see the Installation page on the Brainstorm website.'], 'View connectivity matrix', 0);
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
    case 'ptimefreq'
        [sStudy, iStudy, iStat] = bst_get('StatFile', TimefreqFile);
        if isempty(sStudy)
            error('File is not registered in database.');
        end
        sTimefreq = sStudy.Stat(iStat);
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
% Check that the matrix is square: cannot display [NxM] connectivity  where N~=M
if (length(GlobalData.DataSet(iDS).Timefreq(iTimefreq).RefRowNames) ~= length(GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames)) && ~strcmpi(DisplayMode, 'Image')
    bst_error(sprintf('The connectivity matrix size is [%dx%d].\nThis graph display can be used only for square matrices (NxN).', ...
              length(GlobalData.DataSet(iDS).Timefreq(iTimefreq).RefRowNames), length(GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames)), ...
              'View connectivity matrix', 0);
    return;
end

%% ===== CREATE MATLAB FIGURE =====
if isempty(hFig)
    % Prepare FigureId structure
    FigureId          = db_template('FigureId');
    FigureId.Type     = 'ConnectViz';
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
    figure_connect_viz('ResetDisplay', hFig);
end


%% ===== INITIALIZE FIGURE =====
% Configure app data
setappdata(hFig, 'DataFile',     GlobalData.DataSet(iDS).DataFile);
setappdata(hFig, 'StudyFile',    GlobalData.DataSet(iDS).StudyFile);
setappdata(hFig, 'SubjectFile',  GlobalData.DataSet(iDS).SubjectFile);
setappdata(hFig, 'plotFibers',   0); %TODO: remove entirely once no dependencies

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
    case {'plv','plvt'}
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
setappdata(hFig, 'is3DDisplay', 0); %TODO: remove entirely once no dependencies

% Frequency selection
if isStaticFreq
    TfInfo.iFreqs = [];
else
    TfInfo.iFreqs = GlobalData.UserFrequencies.iCurrentFreq;
end
% Set figure data
setappdata(hFig, 'Timefreq', TfInfo);
% Display options panel
gui_brainstorm('ShowToolTab', 'Display');

%% ===== DRAW FIGURE =====
figure_connect_viz('LoadFigurePlot', hFig);

%% ===== UPDATE ENVIRONMENT =====
% Update figure selection
bst_figures('SetCurrentFigure', hFig, 'TF');
% Select display options
panel_display('UpdatePanel', hFig);
% Set figure visible
set(hFig, 'Visible', 'on');
bst_progress('stop');

