function [hFig, iDS, iFig, hPatch, hLight] = view_surface_matrix(Vertices, Faces, SurfAlpha, SurfColor, hFig, isFem, SurfaceFile)
% VIEW_SURFACE_MATRIX: Display a surface in a 3DViz figure.
%
% USAGE:  [hFig, iDS, iFig, hPatch, hLight] = view_surface_matrix(Vertices, Faces, SurfAlpha=0, SurfColor=[], hFig=[], isFem=0, SurfaceFile=[])
%         [hFig, iDS, iFig, hPatch, hLight] = view_surface_matrix(sSurf)
%
% INPUT:
%     - Vertices    : [Nvx3] matrix with vertices
%     - Faces       : [Nfx3] matrix with faces description
%     - SurfAlpha   : value that indicates surface transparency (optional)
%     - SurfColor   : Surface color [r,g,b] or FaceVertexCData matrix (optional)
%     - hFig        : Specify the figure in which to display the surface (optional)
%     - isFem       : Set to 1 if displaying tetrahedral meshes
%     - SurfaceFile : Filename of the surface
%
% OUTPUT: 
%     - hFig   : Matlab handle to the 3DViz figure that was created or updated
%     - iDS    : DataSet index in the GlobalData variable
%     - iFig   : Indice of returned figure in the GlobalData(iDS).Figure array
%     - hPatch : handle to the surface (graphical object: patch)
%     - hLight : handles to light objects
% If an error occurs : all the returned variables are set to an empty matrix []

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
% Authors: Francois Tadel, 2008-2019
%          Chinmay Chinara, 2024

%% ===== PARSE INPUTS =====
global GlobalData

iDS  = [];
% If full surface structure is passed
if isstruct(Vertices)
    sSurf = Vertices;
    Vertices = sSurf.Vertices;
    Faces    = sSurf.Faces;
else
    sSurf = [];
end
% At least 2 parameters
if (nargin < 1)
    error('Usage: [hFig, iDS, iFig, hPatch, hLight] = view_surface_matrix(Vertices, Faces, SurfAlpha, SurfColor, hFig)');
end
% Check matrices orientation
if (size(Vertices, 2) ~= 3) || (size(Faces, 2) ~= 3)
    error('Faces and Vertices must have 3 columns (X,Y,Z).');
end
% Other arguments
if (nargin < 3) || isempty(SurfAlpha)
    SurfAlpha = 0;
end
if (nargin < 4) || isempty(SurfColor)
    SurfColor = [];
end
if (nargin < 5)
    hFig = [];
end
if (nargin < 6) || isempty(isFem)
    isFem = 0;
end
if (nargin < 7) || isempty(SurfaceFile)
    SurfaceFile = [];
end

% ===== If surface file is defined =====
if ~isempty(SurfaceFile) && ~isFem
    % Get Subject that holds this surface
    sSubject = bst_get('SurfaceFile', SurfaceFile);
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
end


% ===== Create new 3DViz figure =====
isProgress = ~bst_progress('isVisible');
if isProgress
    bst_progress('start', 'View surface', 'Loading surface file...');
end

if isempty(hFig)
    if isempty(SurfaceFile)
        % Create a new empty DataSet
        iDS = bst_memory('GetDataSetEmpty');
    end
    % Prepare FigureId structure
    FigureId = db_template('FigureId');
    FigureId.Type     = '3DViz';
    FigureId.SubType  = '';
    FigureId.Modality = '';
    % Create figure
    [hFig, iFig, isNewFig] = bst_figures('CreateFigure', iDS, FigureId, 'AlwaysCreate');
    if isempty(hFig)
        bst_error('Cannot create figure', 'View surface', 0);
        return;
    end
else
    [iDS, iFig] = bst_figures('GetFigure', hFig);
    isNewFig = 0;
end

if ~isempty(SurfaceFile) && ~isFem
    % Set application data
    setappdata(hFig, 'SubjectFile',  SubjectFile);
end


% ===== Create a pseudo-surface =====
% Surface type
if isFem
    SurfType = 'FEM';
else
    SurfType = 'Other';
end
% Surface file name
if isempty(SurfaceFile)
    SurfaceFile = sprintf('view_surface_matrix(%d,%d,%d)', size(Faces, 1), size(Vertices, 1), length(GlobalData.Surface)+1);
end
% Create a surface in GlobalData.Surface
sLoadedSurf = db_template('LoadedSurface');
sLoadedSurf.Name        = SurfType;
sLoadedSurf.Comment     = 'User_surface';
sLoadedSurf.Vertices    = Vertices;
sLoadedSurf.Faces       = Faces;
if ~isempty(SurfColor)
    sLoadedSurf.Color = SurfColor;
end
if ~isempty(sSurf)
    sLoadedSurf.VertConn    = sSurf.VertConn;
    sLoadedSurf.VertNormals = sSurf.VertNormals;
    sLoadedSurf.SulciMap    = sSurf.SulciMap;
    [tmp, sLoadedSurf.VertArea] = tess_area(sLoadedSurf.Vertices, sLoadedSurf.Faces);
    sLoadedSurf.Atlas       = panel_scout('FixAtlasStruct', sSurf.Atlas);
else
    % Do not compute normals or sulci map for FEM tetrahedral meshes
    if isFem
        sLoadedSurf.VertConn    = [];
        sLoadedSurf.VertNormals = [];
        sLoadedSurf.SulciMap    = [];
    else
        sLoadedSurf.VertConn    = tess_vertconn(Vertices, Faces);
        sLoadedSurf.VertNormals = tess_normals(Vertices, Faces, sLoadedSurf.VertConn);
        sLoadedSurf.SulciMap    = tess_sulcimap(sLoadedSurf);
    end
end
% Create unique filename for this new entry
sLoadedSurf.FileName = ['#' SurfaceFile];
if ~isempty(GlobalData.Surface)
    sLoadedSurf.FileName = file_unique(sLoadedSurf.FileName, {GlobalData.Surface.FileName});
end
% Register in the GUI
GlobalData.Surface(end + 1) = sLoadedSurf;

% ===== Add target surface =====
% Get figure appdata (surfaces configuration)
TessInfo = getappdata(hFig, 'Surface');
% Add a new surface at the end of the figure's surfaces list
iSurface = length(TessInfo) + 1;
TessInfo(iSurface) = db_template('TessInfo');
% Set the surface name and properties
TessInfo(iSurface).Name                = SurfType;
TessInfo(iSurface).SurfaceFile         = sLoadedSurf.FileName;
TessInfo(iSurface).DataSource.Type     = '';
TessInfo(iSurface).DataSource.FileName = '';
TessInfo(iSurface).nFaces        = size(Faces, 1);
TessInfo(iSurface).nVertices     = size(Vertices, 1);
TessInfo(iSurface).SurfAlpha     = SurfAlpha;
if isempty(SurfColor)
    SurfColor = TessInfo(iSurface).AnatomyColor(2,:);
else
    TessInfo(iSurface).AnatomyColor = [.75 .* SurfColor; SurfColor];
end

% ===== DISPLAY SURFACE PATCH ======
% Create and display surface patch
[hFig, hPatch] = figure_3d('PlotSurface', hFig, Faces, Vertices, SurfColor, SurfAlpha);
% Store handle to surface patch
TessInfo(iSurface).hPatch = hPatch;
% Update figure's surfaces list and current surface pointer
setappdata(hFig, 'Surface',  TessInfo);
setappdata(hFig, 'iSurface', iSurface);
% Find light handles (to be compatible with old function view_surface)
hLight = findobj(hFig, 'type', 'light');
% Update figure selection
bst_figures('SetCurrentFigure', hFig, '3D');

% Display scouts
if ~isempty(sLoadedSurf.Atlas)
    % If the default atlas is "Source model" or "Structures": Switch it back to "User scouts"
    sAtlas = panel_scout('GetAtlas', SurfaceFile);
    if ~isempty(sAtlas) && ismember(sAtlas.Name, {'Structures', 'Source model'})
        panel_scout('SetCurrentAtlas', 1);
    end
    % Show all scouts for this surface (for cortex only)
    if (iSurface > 1)
        panel_scout('ReloadScouts', hFig);
    else
        panel_scout('SetDefaultOptions');
        panel_scout('PlotScouts', [], hFig);
        panel_scout('UpdateScoutsDisplay', hFig);
    end
end

% Camera basic orientation
if isNewFig
    figure_3d('SetStandardView', hFig, 'top');
end
% Set figure visible
set(hFig, 'Visible', 'on');
if isProgress
    bst_progress('stop');
end
% Update "surface" panel
panel_surface('UpdatePanel');
% Select surface tab
if isNewFig
    gui_brainstorm('SetSelectedTab', 'Surface');
end

end
