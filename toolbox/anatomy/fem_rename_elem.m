function [isOk, errMsg] = fem_rename_elem(FemFileName)
% FEM_RENAME_ELEM: Rename the 3D FEM elements inside a given surface

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
% Authors: Takfarinas Medani, 2025
%          Raymundo Cassnai, 2026
%    

isOk = 0;
errMsg = '';

% Ask the user if he wants to relabel the defined area
% Why this: it is possible that the ROI can be relabled and defined as
% different tissue such a tumor, stroke (core or penumbra)  or ablation area ...
 [NewTissueLabel, isCancel] = java_dialog('input', 'Please enter the label for the new tissue', 'Name for the new tissue');
if isCancel
    return;
end
% === Install/load required plugin: 'iso2mesh'
[isInstalled, errMsg] = bst_plugin('Install', 'iso2mesh', 1);
if ~isInstalled
    errMsg = ['Could not install or load plugin: iso2mesh' 10 errMsg];
    if isInteractive
        bst_error(errMsg);
    end
    return
end
% === Load target FEM meshes
bst_progress('start', 'Define FEM mesh ','Loading the FEM mesh ');
FemFullFile = file_fullpath(FemFileName);
FemMat = load(FemFullFile);
bst_progress('stop');
% Hexahedral meshes not supported
if (size(FemMat.Elements,2) > 4)
    errMsg = ['Hexahedral FEM meshes are not supported.' 10 ...
              'Try converting them to tetrahedral FEM meshes with the popup menu option.'];
    if isInteractive
        bst_error(errMsg);
    end
    return
end
% Get file in database
[sSubject, iSubject] = bst_get('SurfaceFile', FemFileName);
% === Identify points to insert into the mesh {the elements centroides} for each method

% Ask for surface and allow user to manual position the ROI
% List of all the available surfaces in the subject database
surfFileNames = {sSubject.Surface.FileName};
surfComments  = {sSubject.Surface.Comment};
% Ignore target FEM meshes
iSurfFem = strcmpi({sSubject.Surface.SurfaceType}, 'fem');
surfFileNames(iSurfFem) = [];
surfComments(iSurfFem)  = [];
% Add geometric surfaces
surfGeoComments = { 'Sphere (radius 10 mm)', ...
                    'Sphere (radius 25 mm)',...
                    'Cylinder (radius 1 mm, length 10mm)'}; % add disc [vert, faces] = tess_disc()
surfFileNames = [repmat({''}, 1, length(surfGeoComments)), surfFileNames];
surfComments  = [surfGeoComments, surfComments];
% Ask user to select the ROI area
[surfSelectComment, isCancel] = java_dialog('combo', [...
    'The ROI can be a geometric surface or a surface in the Subject.' 10 ...
    '1) Edit the ROI (if needed), then' 10 ...
    '2) Click on the [OK] button on figure toolbar.' 10 10 ...
    'Select the ROI to apply the definement.' 10], ...
    'define FEM mesh(es) within a specific ROI', [], surfComments, surfComments{1});
if isempty(surfSelectComment) || isCancel
    bst_progress('stop');
    return
end
% Generate geometric surface if needed
if ismember(surfSelectComment, surfGeoComments)
    switch surfSelectComment
        case {'Sphere (radius 10 mm)', 'Sphere (radius 25 mm)'}
            % Sphere with 250 vertices
            [geo_vert, geo_faces] = tess_sphere(250);
            % Get radius
            r = sscanf(surfSelectComment, 'Sphere (radius %f mm');
            geo_vert = r * geo_vert / 1000;
        case {'Cylinder (radius 1 mm, length 10mm)'}
            % default inputs:
            %   c0, c1:  cylinder axis end points
            c0 = [0 0 0];
            c1 = [0 0 10];
            %   r:   radius of the cylinder; if r contains two elements, it outputs
            %        a cone trunk, with each r value specifying the radius on each end
            r0 = 1; r1 = 1; r = ([r0 r1]);
            %   tsize: maximum surface triangle size on the sphere
            tsize = mean(r)/5;
            %   maxvol: maximu volume of the tetrahedral elements
            maxvol = tsize*tsize*tsize;
            %   ndiv: approximate the cylinder surface into ndiv flat pieces,
            % ndiv = norm(c0-c1);
            ndiv = 20;
            % Generate the mesh
            [geo_vert,geo_faces]= meshacylinder(c0,c1,r,tsize,maxvol,ndiv);
            geo_vert = geo_vert/1000;
        otherwise
            % Geometric surface not supported
    end

    % Save geometric surface ROI
    tag = sprintf('_%dV', size(geo_vert, 1));
    OutputMat.Comment  = [surfSelectComment, tag];
    OutputMat.Vertices = geo_vert;
    OutputMat.Faces    = geo_faces;
    % Output filename
    OutputFile = bst_fullfile(bst_fileparts(FemFullFile), 'tess_roi_define.mat');
    OutputFile = file_unique(OutputFile);
    % Save file
    bst_save(OutputFile, OutputMat, 'v7');
    db_add_surface(iSubject, OutputFile, OutputMat.Comment);
    % Add filename to surfFileNames
    iSurf = strcmp(surfSelectComment, surfComments);
    surfFileNames{iSurf} = file_short(OutputFile);
end

% Open the GUI for ROI alignement on the FEM Mesh
SurfaceFile = surfFileNames{strcmp(surfSelectComment, surfComments)};
% Get the handle of the figure and wait until closed to continue
global gTessAlign;
tess_align_manual(FemFullFile, file_fullpath(SurfaceFile), 0);
waitfor(gTessAlign.hFig)

% Find all FEM mesh vertices within the ROI surface
centroid = meshcentroid(FemMat.Vertices, FemMat.Elements);
% Load ROI surface
sSurf = in_tess_bst(SurfaceFile, 0);
% Find points outside of the boundary
iOutside = find(~inpolyhd(centroid, sSurf.Vertices, sSurf.Faces));
iInside = 1:length(centroid);

% Remove the outside points
if ~isempty(iOutside)
    centroid(iOutside,:) = [];
    iInside(iOutside) = [];
end
 

% Unload plugin: 'iso2mesh'
bst_plugin('Unload', 'iso2mesh', 1);

% === Save defined FEM mesh
bst_progress('text', 'Saving defined mesh ...');

% Tissue labels
newID = max(unique(FemMat.Tissue)) + 1;
% FemMat.Tissue(iOutside) =  FemMat.Tissue;
FemMat.Tissue(iInside) =  newID;
FemMat.TissueLabels  = [FemMat.TissueLabels NewTissueLabel];
 
% File comment    
FemMat.Comment = [FemMat.Comment ' | ' NewTissueLabel ];
% Add history
FemMat = bst_history('add', FemMat, 'set new roi');
% Save to database
FemFile = file_unique(bst_fullfile(bst_fileparts(FemFullFile), sprintf('tess_fem_%dV.mat', length(FemMat.Vertices))));
bst_save(FemFile, FemMat, 'v7');
db_add_surface(iSubject, FemFile, FemMat.Comment);
bst_progress('stop');
% Return success
isOk = 1;

end
