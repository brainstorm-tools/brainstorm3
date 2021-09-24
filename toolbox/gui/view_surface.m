function [hFig, iDS, iFig] = view_surface(SurfaceFile, SurfAlpha, SurfColor, hFig, isScouts)
% VIEW_SURFACE: Display a surface in a 3DViz figure.
%
% USAGE:  [hFig, iDS, iFig] = view_surface(SurfaceFile, SurfAlpha=0, SurfColor=[.6,.6,.6], TargetFigure=[], isScouts=0)
%
% INPUT:
%     - SurfaceFile : full path to the surface file to display 
%     - SurfAlpha   : value that indicates surface transparency (optional)
%     - SurfColor   : Surface color [r,g,b] (optional)
%     - TargetFigure:
%        |- "NewFigure" : Force new figure creation (do not re-use a previously created figure)
%        |- hFig        : Specify the figure in which to display the surface
%        |- iDS         : Specify which loaded dataset to use
%        |- []          : Get an existing 3D figure for the subject identified from SurfaceFile
%     - isScouts    : If 1, displays scouts for the loaded surface
%
% OUTPUT : 
%     - hFig : Matlab handle to the 3DViz figure that was created or updated
%     - iDS  : DataSet index in the GlobalData variable
%     - iFig : Indice of returned figure in the GlobalData(iDS).Figure array
% If an error occurs : all the returned variables are set to an empty matrix []

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
% Authors: Francois Tadel, 2008-2021

global GlobalData;

%% ===== PARSE INPUTS =====
iDS  = [];
iFig = [];
NewFigure = 0;
% By default: show scouts
if (nargin < 5) || isempty(isScouts)
    isScouts = 1;
end
% Get options
if (nargin < 4) || isempty(hFig)
    hFig = [];
elseif ischar(hFig) && strcmpi(hFig, 'NewFigure')
    hFig = [];
    NewFigure = 1;
elseif ishandle(hFig)
    [hFig,iFig,iDS] = bst_figures('GetFigure', hFig);
elseif (round(hFig) == hFig) && (hFig <= length(GlobalData.DataSet))
    iDS = hFig;
    hFig = [];
else
    error('Invalid figure handle.');
end
% Color & Transparency
if (nargin < 3) || isempty(SurfColor)
    SurfColor = [];
end
if (nargin < 2) || isempty(SurfAlpha)
    SurfAlpha = [];
end

%% ===== GET INFORMATION =====
% Get Subject that holds this surface
[sSubject, iSubject, iSurface] = bst_get('SurfaceFile', SurfaceFile);
% If this surface does not belong to any subject
if isempty(iDS)
    if isempty(sSubject)
        % Check that the SurfaceFile really exist as an absolute file path
        if ~file_exist(SurfaceFile)
            bst_error(['File not found : "', SurfaceFile, '"'], 'Display surface');
            return
        end
        % Create an empty DataSet
        SubjectFile = '';
        iDS = bst_memory('GetDataSetEmpty');
    else
        % Get GlobalData DataSet associated with subjectfile (create if does not exist)
        SubjectFile = sSubject.FileName;
        iDS = bst_memory('GetDataSetSubject', SubjectFile, 1);
    end
    iDS = iDS(1);
else
    SubjectFile = sSubject.FileName;
end

%% ===== CREATE NEW FIGURE =====
% Display progress bar
isProgress = ~bst_progress('isVisible');
if isProgress
    bst_progress('start', 'View surface', 'Loading surface file...');
end
if isempty(hFig)
    % Prepare FigureId structure
    FigureId = db_template('FigureId');
    FigureId.Type     = '3DViz';
    FigureId.SubType  = '';
    FigureId.Modality = '';
    % Create figure
    if NewFigure
        [hFig, iFig, isNewFig] = bst_figures('CreateFigure', iDS, FigureId, 'AlwaysCreate');
    else
        [hFig, iFig, isNewFig] = bst_figures('CreateFigure', iDS, FigureId);
    end
    % If figure was not created
    if isempty(hFig)
        bst_error('Could not create figure.', 'View surface', 0);
        return;
    end
else
    isNewFig = 0;
end
% Set application data
setappdata(hFig, 'SubjectFile',  SubjectFile);
    
%% ===== DISPLAY SURFACE =====
% Add surface to figure
[iSurf, TessInfo] = panel_surface('AddSurface', hFig, SurfaceFile);
if isempty(iSurf)
    return
end
% Set color
if ~isempty(SurfColor)
    panel_surface('SetSurfaceColor', hFig, iSurf, SurfColor);
end
% Set transparency
if ~isempty(SurfAlpha)
    panel_surface('SetSurfaceTransparency', hFig, iSurf, SurfAlpha);
end
% % Cortex: Set default Sulci/Smooth parameters
% if strcmpi(sSubject.Surface(iSurface).SurfaceType, 'Cortex')
%     % Get defaults for surface display
%     DefaultSurfaceDisplay = bst_get('DefaultSurfaceDisplay');
%     % Set default smooth parameter
%     panel_surface('SetSurfaceSmooth', hFig, iSurf, DefaultSurfaceDisplay.SurfSmoothValue, 0);
%     % Set default for sulci (on/off)
%     panel_surface('SetShowSulci', hFig, iSurf, DefaultSurfaceDisplay.SurfShowSulci);
% end

% Set figure as current figure
bst_figures('SetCurrentFigure', hFig, '3D');
% Display scouts
if isScouts
    % If the default atlas is "Source model" or "Structures": Switch it back to "User scouts"
    sAtlas = panel_scout('GetAtlas', SurfaceFile);
    if ~isempty(sAtlas) && ismember(sAtlas.Name, {'Structures', 'Source model'}) && isequal(TessInfo(iSurf).Name, 'Cortex')
        panel_scout('SetCurrentAtlas', 1);
    end
    % Show all scouts for this surface (for cortex only)
    if (iSurf > 1)
        panel_scout('ReloadScouts', hFig);
    else
        panel_scout('SetDefaultOptions');
        panel_scout('PlotScouts', [], hFig);
        panel_scout('UpdateScoutsDisplay', hFig);
    end
end
% Make sure to update the Headlight
camlight(findobj(hFig, 'Tag', 'FrontLight'), 'headlight');
% Camera basic orientation
if isNewFig
    figure_3d('SetStandardView', hFig, 'top');
end
% Show figure
set(hFig, 'Visible', 'on');
if isProgress
    bst_progress('stop');
end
% Select surface tab
if isNewFig
    gui_brainstorm('SetSelectedTab', 'Surface');
end


