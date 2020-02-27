function [hFig, iDS, iFig] = view_surface_fem(SurfaceFile, SurfAlpha, SurfColor, Resect, hFig)
% VIEW_SURFACE_FEM: Display a FEM mesh in a 3DViz figure.
%
% USAGE:  [hFig, iDS, iFig] = view_surface(SurfaceFile)
%         [hFig, iDS, iFig] = view_surface(SurfaceFile, SurfAlpha, SurfColor, Resect, 'NewFigure')
%         [hFig, iDS, iFig] = view_surface(SurfaceFile, SurfAlpha, SurfColor, Resect, hFig)
%         [hFig, iDS, iFig] = view_surface(SurfaceFile, SurfAlpha, SurfColor, Resect, iDS)
%
% INPUT:
%     - SurfaceFile : full path to the surface file to display 
%     - SurfAlpha   : [1,Ntissue] Surface transparency for each tissue (optional)
%     - SurfColor   : [3,Ntissue] Surface color [r,g,b] for each tissue (optional)
%     - Resect      : [x y z] Relative coordinates of the resection planes (default = [0 .1 0])
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
% Authors: Francois Tadel, 2019-2020

global GlobalData;

%% ===== PARSE INPUTS =====
iDS  = [];
iFig = [];
NewFigure = 0;
% Get options
if (nargin < 5) || isempty(hFig)
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
% Resection
if (nargin < 4) || isempty(Resect)
    Resect = [];
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
    bst_progress('start', 'View surface', 'Loading FEM mesh...');
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
% Check the mesh format here : tetra ok, hexa ==> convert to tetra ==> need some functions on bst-duneuro/matlab/external/gibbon
if size(FemMat.Elements,2) == 8
    % Install bst_duneuro if needed, for function hex2tet
    if ~exist('bst_duneuro', 'file')
        errMsg = process_generate_fem('InstallDuneuro', 1);
        if ~isempty(errMsg) || ~exist('bst_duneuro', 'file')
            bst_progress('stop');
            return;
        end
    end
    % convert the mesh to tetra for diplay purpose
    [tetraElem,tetraNode,tetraLabel] = hex2tet(double(FemMat.Elements), FemMat.Vertices, double(FemMat.Tissue), 3);
    % updates FemMat for display purpose
    FemMat.Vertices = tetraNode;
    FemMat.Elements = tetraElem;
    FemMat.Tissue = tetraLabel;
end

if ~isfield(FemMat, 'Vertices') || ~isfield(FemMat, 'Elements') || ~isfield(FemMat, 'Tissue') || ~isfield(FemMat, 'TissueLabels')|| ~isfield(FemMat, 'Comment')
    error('Not a valid FEM mesh.');
end
% Get number of tissues in the file
Ntissue = max(FemMat.Tissue);
if isProgress
    bst_progress('start', 'View surface', 'Loading FEM mesh...', 0, Ntissue+2);
end
% Transparency and color
if (size(SurfColor,2) ~= Ntissue)
    ColorOrder = panel_scout('GetScoutsColorTable');
    SurfColor = ColorOrder(1:Ntissue, :);
    labels = lower(FemMat.TissueLabels);
    % Get default color for each layer
    for iTissue = 1:Ntissue
        switch process_generate_fem('GetFemLabel', labels{iTissue})
            case 'white'
                % SurfColor(iTissue,:) = [250 250 250]/255;
                SurfColor(iTissue,:) = [220, 220, 220] ./ 255;
            case 'gray'
                % SurfColor(iTissue,:) = [150 150 150]/255;
                SurfColor(iTissue,:) = [130, 130, 130] ./ 255;
            case 'csf'
                % SurfColor(iTissue,:) = [202 50 150]/255;
                SurfColor(iTissue,:) = [44, 152, 254]/255;
            case 'skull'
                % SurfColor(iTissue,:) = [140  85  85]/255;
                SurfColor(iTissue,:) = [255 255 255] ./ 255;
            case 'scalp'
                % SurfColor(iTissue,:) = [255 213 119]/255;
                SurfColor(iTissue,:) = [255, 205, 184] ./ 255;
        end
    end
end
if (size(SurfAlpha,2) ~= Ntissue)
    SurfAlpha = zeros(1,Ntissue);
end
if (size(Resect,2) ~= Ntissue)
    Resect = [0, 0.01, 0];
end
% Plot each tissue as a patch object
for iTissue = 1:Ntissue
    % Progress bar
    MeshName = [SurfaceFile, '(', FemMat.TissueLabels{iTissue}, ')'];
    if isProgress
        bst_progress('text', ['Creating surface: ' MeshName '...']);
        bst_progress('inc', 1);
    end
    % Select elements of this tissue
    Elements = FemMat.Elements(FemMat.Tissue == iTissue, 1:4);
    % Create a surface for the outside surface of this tissue
    Faces = tess_voledge(FemMat.Vertices, Elements, Resect);
    % Plot as a new surface
    [tmp_, tmp_, tmp_, hPatch, hLight] = view_surface_matrix(FemMat.Vertices, Faces, SurfAlpha(iTissue), SurfColor(iTissue,:), hFig, 1, MeshName);
    % Remove specular lighting
    set(hPatch, 'FaceLighting', 'flat', ...
                'EdgeLighting', 'flat', ...
                'AmbientStrength',  0.5, ...
                'DiffuseStrength',  0.3, ...
                'SpecularStrength', 0.1, ...
                'SpecularExponent', 0.3, ...
                'UserData',         Elements);
    % Show edges
    panel_surface('SetSurfaceEdges', hFig, iTissue, 1);
end
if isProgress
    bst_progress('text', 'Creating figure...');
    bst_progress('inc', 1);
end

% Set figure as current figure
bst_figures('SetCurrentFigure', hFig, '3D');
% Make sure to update the Headlight
camlight(findobj(hFig, 'Tag', 'FrontLight'), 'headlight');
% Camera basic orientation
if isNewFig
    figure_3d('SetStandardView', hFig, 'left');
end
% Show figure
set(hFig, 'Visible', 'on');
if isProgress
    drawnow
    bst_progress('stop');
end
% Select surface tab
if isNewFig
    gui_brainstorm('SetSelectedTab', 'Surface');
end


