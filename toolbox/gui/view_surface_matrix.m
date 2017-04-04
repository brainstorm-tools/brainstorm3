function [hFig, iDS, iFig, hPatch, hLight] = view_surface_matrix(Vertices, Faces, SurfAlpha, SurfColor, hFig)
% VIEW_SURFACE_MATRIX: Display a surface in a 3DViz figure.
%
% USAGE:  [hFig, iDS, iFig, hPatch, hLight] = view_surface_matrix(Vertices, Faces, SurfAlpha, SurfColor, hFig)
%         [hFig, iDS, iFig, hPatch, hLight] = view_surface_matrix(Vertices, Faces)
%         [hFig, iDS, iFig, hPatch, hLight] = view_surface_matrix(sSurf)
%
% INPUT:
%     - Vertices  : [Nvx3] matrix with vertices
%     - Faces     : [Nfx3] matrix with faces description
%     - SurfAlpha : value that indicates surface transparency (optional)
%     - SurfColor : Surface color [r,g,b] or FaceVertexCData matrix (optional)
%     - hFig      : Specify the figure in which to display the surface (optional)
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
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2013

%% ===== PARSE INPUTS =====
global GlobalData;
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
% Argument: SurfAlpha
if (nargin < 3) || isempty(SurfAlpha)
    SurfAlpha = 0;
end
% Argument: SurfColor
if (nargin < 4) || isempty(SurfColor)
    SurfColor = [];
end
% Argument: hFig
if (nargin < 5)
    hFig = [];
end

% ===== Create new 3DViz figure =====
bst_progress('start', 'View surface', 'Loading surface file...');
if isempty(hFig)
    % Create a new empty DataSet
    iDS = bst_memory('GetDataSetEmpty');
    % Prepare FigureId structure
    FigureId = db_template('FigureId');
    FigureId.Type     = '3DViz';
    FigureId.SubType  = '';
    FigureId.Modality = '';
    % Create figure
    [hFig, iFig] = bst_figures('CreateFigure', iDS, FigureId, 'AlwaysCreate');
    if isempty(hFig)
        bst_error('Cannot create figure', 'View surface', 0);
        return;
    end
else
    [iDS, iFig] = bst_figures('GetFigure', hFig);
end

% ===== Create a pseudo-surface =====
% Create a surface in GlobalData.Surface
sLoadedSurf = db_template('LoadedSurface');
sLoadedSurf.FileName    = sprintf('view_surface_matrix(%d,%d,%d)', size(Faces, 1), size(Vertices, 1), length(GlobalData.Surface)+1);
sLoadedSurf.Name        = 'Other';
sLoadedSurf.Comment     = 'User_surface';
sLoadedSurf.Vertices    = Vertices;
sLoadedSurf.Faces       = Faces;
if ~isempty(sSurf)
    sLoadedSurf.VertConn    = sSurf.VertConn;
    sLoadedSurf.VertNormals = sSurf.VertNormals;
    sLoadedSurf.SulciMap    = sSurf.SulciMap;
else
    sLoadedSurf.VertConn    = tess_vertconn(Vertices, Faces);
    sLoadedSurf.VertNormals = tess_normals(Vertices, Faces, sLoadedSurf.VertConn);
    sLoadedSurf.SulciMap    = tess_sulcimap(sLoadedSurf);
end
GlobalData.Surface(end + 1) = sLoadedSurf;
    
% ===== Add target surface =====
% Get figure appdata (surfaces configuration)
TessInfo = getappdata(hFig, 'Surface');
% Add a new surface at the end of the figure's surfaces list
iSurface = length(TessInfo) + 1;
TessInfo(iSurface) = db_template('TessInfo');
% Set the surface name and properties
TessInfo(iSurface).Name                = 'Other';
TessInfo(iSurface).SurfaceFile         = sLoadedSurf.FileName;
TessInfo(iSurface).DataSource.Type     = '';
TessInfo(iSurface).DataSource.FileName = '';
TessInfo(iSurface).nFaces        = size(Faces, 1);
TessInfo(iSurface).nVertices     = size(Vertices, 1);
TessInfo(iSurface).SurfAlpha     = SurfAlpha;
if isempty(SurfColor)
    SurfColor = TessInfo(iSurface).AnatomyColor(2,:);
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
% Camera basic orientation
figure_3d('SetStandardView', hFig, 'top');
% Set figure visible
set(hFig, 'Visible', 'on');
bst_progress('stop');
% Update "surface" panel
panel_surface('UpdatePanel');

end
