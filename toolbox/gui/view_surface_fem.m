function [hFig, iDS, iFig] = view_surface_fem(SurfaceFile, SurfAlpha, SurfColor, hFig)
% VIEW_SURFACE_FEM: Display a FEM mesh in a 3DViz figure.
%
% USAGE:  [hFig, iDS, iFig] = view_surface(SurfaceFile)
%         [hFig, iDS, iFig] = view_surface(SurfaceFile, SurfAlpha, SurfColor, 'NewFigure')
%         [hFig, iDS, iFig] = view_surface(SurfaceFile, SurfAlpha, SurfColor, hFig)
%         [hFig, iDS, iFig] = view_surface(SurfaceFile, SurfAlpha, SurfColor, iDS)
%
% INPUT:
%     - SurfaceFile : full path to the surface file to display 
%     - SurfAlpha   : [1,Ntissue] Surface transparency for each tissue (optional)
%     - SurfColor   : [3,Ntissue] Surface color [r,g,b] for each tissue (optional)
%     - "NewFigure" : force new figure creation (do not re-use a previously created figure)
%     - hFig        : Specify the figure in which to display the surface
%     - iDS         : Specify which loaded dataset to use
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
% Authors: Francois Tadel, 2019

global GlobalData;

%% ===== PARSE INPUTS =====
iDS  = [];
iFig = [];
NewFigure = 0;
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


%% ===== DISPLAY FEM MESH =====
% Load the input file
FemMat = load(file_fullpath(SurfaceFile));
if ~isfield(FemMat, 'Vertices') || ~isfield(FemMat, 'Elements') || ~isfield(FemMat, 'Tissue') || ~isfield(FemMat, 'TissueLabels')|| ~isfield(FemMat, 'Comment')
    error('Not a valid FEM mesh.');
end
% Get number of tissues in the file
Ntissue = max(FemMat.Tissue);
% Transparency and color
if (size(SurfColor,2) ~= Ntissue)
    ColorOrder = panel_scout('GetScoutsColorTable');
    SurfColor = ColorOrder(1:Ntissue, :);
    labels = lower(FemMat.TissueLabels);
    % Default skin color
    iSkin = find(ismember(labels, {'skin','scalp','head'}));
    if ~isempty(iSkin)
        SurfColor(iSkin,:) = [255 213 119]/255;
    end
    % Default bone color
    iBone = find(ismember(labels, {'bone','skull','outer','outerskull'}));
    if ~isempty(iBone)
        SurfColor(iBone,:) = [140  85  85]/255;
    end
    % Default CSF color
    iCSF = find(ismember(labels, 'csf'));
    if ~isempty(iCSF)
        SurfColor(iCSF,:) = [202 50 150]/255;
    end
    % Default grey matter color
    iGrey = find(ismember(labels, {'gray','greymatter','gm','cortex','inner','innerskull'}));
    if ~isempty(iGrey)
        SurfColor(iGrey,:) = [150 150 150]/255;
    end
    % Default white matter color
    iWhite = find(ismember(labels, {'gray','greymatter','gm','cortex'}));
    if ~isempty(iWhite)
        SurfColor(iWhite,:) = [250 250 250]/255;
    end
end
if (size(SurfAlpha,2) ~= Ntissue)
    SurfAlpha = zeros(1,Ntissue);
end
% Plot each tissue as a patch object
for iTissue = 1:Ntissue
    % Remove unused vertices
    iSelElem = find(FemMat.Tissue == iTissue);
    iRemoveVert = setdiff(1:size(FemMat.Vertices,1), unique(reshape(FemMat.Elements(iSelElem,:), [], 1)));
    [Vertices, tetraMesh] = tess_remove_vert(FemMat.Vertices, FemMat.Elements(iSelElem,:), iRemoveVert);
    % Convert to triangular mesh
    Faces = [...
        tetraMesh(:,[2,1,3]);
        tetraMesh(:,[1,2,4]);
        tetraMesh(:,[3,1,4]);
        tetraMesh(:,[2,3,4])];
    % Plot as a new surface
    MeshName = [SurfaceFile, '(', FemMat.TissueLabels{iTissue}, ')'];
    [tmp_, tmp_, tmp_, hPatch, hLight] = view_surface_matrix(Vertices, Faces, SurfAlpha(iTissue), SurfColor(iTissue,:), hFig, 1, MeshName);
    % Remove specular lighting
    set(hPatch, 'FaceLighting', 'flat', ...
                'EdgeLighting', 'flat', ...
                'AmbientStrength',  0.5, ...
                'DiffuseStrength',  0.3, ...
                'SpecularStrength', 0.1, ...
                'SpecularExponent', 0.3);
    % Show edges
    panel_surface('SetSurfaceEdges', hFig, iTissue, 1);
    % Set reset to half-way through the head (mid-sagittal)
    panel_surface('ResectSurface', hFig, iTissue, 2, 0.01);
end

% Set figure as current figure
bst_figures('SetCurrentFigure', hFig, '3D');
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


