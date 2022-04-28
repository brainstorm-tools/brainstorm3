function [hFig, iDS, iFig] = view_fem_tensors(FemFile, DisplayMode, iTissues, AnatFile, hFig)
% VIEW_FEM_TENSORS: Display FEM conductivity tensors.
%
% USAGE:  [hFig, iDS, iFig] = view_fem_tensors(FemFile, DisplayMode='ellipse', iTissues=[ask], AnatFile=[default MRI], hFig=[NewFigure])
%
% INPUT:
%     - FemFile     : full path to the FEM mesh file to display 
%     - DisplayMode : {'ellipse', 'arrow'}
%     - iTissues    : List of tissues to display in the file (if not defined, ask the user)
%     - AnatFile    : Path to a MRI or FEM file in the database
%     - hFig        : Specify the figure in which to display the surface (otherwise creates a new figure)
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
% Authors: Francois Tadel, Takfarinas Medani, 2020


%% ===== PARSE INPUTS =====
iDS  = [];
iFig = [];
% Get options
if (nargin < 5) || isempty(hFig)
    hFig = [];
elseif ishandle(hFig)
    [hFig,iFig,iDS] = bst_figures('GetFigure', hFig);
else
    error('Invalid figure handle.');
end
% Parse inputs
if (nargin < 4) || isempty(AnatFile)
    AnatFile = [];
end
if (nargin < 3) || isempty(iTissues)
    % Load the tissue names
    FemMat = load(file_fullpath(FemFile), 'TissueLabels');
    [res, isCancel] = java_dialog('checkbox', 'Select the tissues to display:', 'Select Tissues', [], FemMat.TissueLabels, [1, zeros(1,length(FemMat.TissueLabels)-1)]);
    if isCancel || ~any(res)
        return;
    end
    iTissues = find(res);
end
if (nargin < 2) || isempty(DisplayMode)
    DisplayMode = 'ellipse';
end


%% ===== GET INFORMATION =====
% Get Subject that holds this surface
sSubject = bst_get('SurfaceFile', FemFile);
% If this surface does not belong to any subject
if isempty(iDS)
    if isempty(sSubject)
        % Check that the SurfaceFile really exist as an absolute file path
        if ~file_exist(FemFile)
            bst_error(['File not found : "', FemFile, '"'], 'Display surface');
            return
        end
        % Create an empty DataSet
        SubjectFile = '';
        iDS = bst_memory('GetDataSetEmpty');
    else
        % Get DataSet associated with subjectfile (create if does not exist)
        SubjectFile = sSubject.FileName;
        iDS = bst_memory('GetDataSetSubject', SubjectFile, 1);
    end
    iDS = iDS(1);
else
    SubjectFile = sSubject.FileName;
end

%% ===== GET MRI REFERENCE =====
% Use default MRI for this subject
if isempty(AnatFile)
    if isempty(sSubject.Anatomy) || isempty(sSubject.iAnatomy)
        error('No MRI available for this subject.');
    end
    AnatFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
end
% Get reference MRI
AnatType = file_gettype(AnatFile);
switch (AnatType)
    case 'subjectimage'
        MriFile = AnatFile;
        FigSubType = 'TensorsMri';
        CoordSystem = 'voxel';
    case 'fem'
        MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
        FigSubType = 'TensorsFem';
        CoordSystem = 'scs';
    otherwise
        error('Unsupported file type.');
end


%% ===== CREATE NEW FIGURE =====
% If target figure is not specified
if isempty(hFig)
    % Prepare FigureId structure
    FigureId = db_template('FigureId');
    FigureId.Type     = '3DViz';
    FigureId.SubType  = FigSubType;
    FigureId.Modality = '';
    % Create figure
    [hFig, iFig, isNewFig] = bst_figures('CreateFigure', iDS, FigureId, 'AlwaysCreate');
    % If figure was not created
    if isempty(hFig)
        bst_error('Could not create figure.', 'View tensors', 0);
        return;
    end
else
    isNewFig = 0;
end
% Set application data
setappdata(hFig, 'SubjectFile',  SubjectFile);

%% ===== DISPLAY ANATOMY =====
if isNewFig
    switch (AnatType)
        case 'subjectimage'
            view_mri_3d(AnatFile, [], 0.7, hFig);           
        case 'fem'
            alphaLayer = zeros(length(FemMat.TissueLabels));
            alphaLayer(iTissues) = 0.5;
            view_surface_fem(AnatFile, alphaLayer, [], [], hFig);
    end
end

%% ===== LOAD FEM TENSORS =====
% Display progress bar
isProgress = ~bst_progress('isVisible');
if isProgress
    bst_progress('start', 'View surface', 'Loading FEM mesh...');
end
% Load the input file
FemMat = load(file_fullpath(FemFile));
if ~isfield(FemMat, 'Tensors') || any(size(FemMat.Tensors) < 12)
    error('No FEM conductivity tensor in this file.');
end
% Load MRI
sMri = bst_memory('LoadMri', MriFile);
% Select tissues to display
bst_progress('text', 'Preparing tensors display...');
iElemTissue = find(ismember(FemMat.Tissue, iTissues));
TensorDisplay.Tensors = FemMat.Tensors(iElemTissue,:);
disp(['BST> Selected tissues:' sprintf(' %s', FemMat.TissueLabels{iTissues}) ' (' num2str(length(iElemTissue)) ' elements)']);

% Compute element centroids
nElem = length(iElemTissue);
nMesh = size(FemMat.Elements, 2);
TensorDisplay.ElemCenter = zeros(nElem, 3);
for i = 1:3
    TensorDisplay.ElemCenter(:,i) = sum(reshape(FemMat.Vertices(FemMat.Elements(iElemTissue,:),i), nElem, nMesh), 2) / nMesh;
end
% Compute average distance between element center and vertices
TensorDisplay.tol = 0.5 .* sqrt(mean(sum(bst_bsxfun(@minus, FemMat.Vertices(FemMat.Elements(iElemTissue(1:10:end),1),:), TensorDisplay.ElemCenter(1:10:end,:)) .^ 2, 2)));
% For MRI: Tolerance factor must be scaled and in mm
if strcmpi(AnatType, 'subjectimage')
    TensorDisplay.tol = TensorDisplay.tol .* max(sMri.Voxsize) .* 1000;
end
% Convert FEM element centers to voxel coordinates
TensorDisplay.ElemCenterAnat = cs_convert(sMri, 'scs', CoordSystem, TensorDisplay.ElemCenter);
% Save display mode
TensorDisplay.DisplayMode = DisplayMode;
% Scaling factor for tensor object size
TensorDisplay.Factor = 4 / 100;
% Initialize other properties
TensorDisplay.CutPosition = [];
TensorDisplay.CutDim = [];
TensorDisplay.isRelative = [];
% Save display info in figure handles
Handles = bst_figures('GetFigureHandles', hFig);
Handles.TensorDisplay = TensorDisplay;
bst_figures('SetFigureHandles', hFig, Handles);


%% ===== UPDATE INTERFACE =====
bst_progress('text', 'Creating figure...');
% Plot one slice of tensors
switch (AnatType)
    % MRI: Plot initial Z slice
    case 'subjectimage'
        TessInfo = getappdata(hFig, 'Surface');
        figure_3d('PlotTensorCut', hFig, TessInfo(1).CutsPosition(3), 3, 0);
    % FEM mesh: Plot mid-saggital plane (Y=0)
    case 'fem'
        figure_3d('PlotTensorCut', hFig, 0, 2, 1);
end
% Set figure as current figure
bst_figures('SetCurrentFigure', hFig, '3D');
% Finish creating new figure
if isNewFig
    % Make sure to update the Headlight
    camlight(findobj(hFig, 'Tag', 'FrontLight'), 'headlight');
    % Camera basic orientation
    figure_3d('SetStandardView', hFig, 'top');
    % Select surface tab
    gui_brainstorm('SetSelectedTab', 'Surface');
end
% Show figure
set(hFig, 'Visible', 'on');
if isProgress
    drawnow
    bst_progress('stop');
end
