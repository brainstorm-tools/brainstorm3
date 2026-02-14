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
isInteractive = 1;

% Load FEM layer names
FemFullFile = file_fullpath(FemFileName);
if ~file_exist(FemFullFile)
    return
else
    FemMat = load(FemFullFile, 'TissueLabels');
end

% Ask the user for layer name
[NewElemLabel, isCancel] = java_dialog('input', 'Please enter the new label for the elements', 'Name element label');
if isCancel
    return
end
% Check if elements will be concatenated
isConcatLayer = 0;
if ismember(NewElemLabel, FemMat.TissueLabels)
    [res, isCancel] = java_dialog('question', ['The new label "' NewElemLabel '" already exist.'  10 ...
                                  'Renamed FEM elements will concatenated to current layer.' 10 10 ...
                                  'Continue?'], 'Rename FEM elements');
    if isCancel || strcmpi(res, 'no')
        return
    end
    isConcatLayer = 1;
end

% Load iso2mesh plugin
PlugUnload = 0;
PlugDesc = bst_plugin('GetDescription', 'iso2mesh');
if ~PlugDesc.isLoaded
    % Install/load iso2mesh plugin
    [isInstalled, errMsg] = bst_plugin('Install', 'iso2mesh', 0);
    if ~isInstalled
        bst_error(errMsg);
        return
    end
    PlugUnload = 1;
end

% === Load target FEM meshes
bst_progress('start', 'Rename FEM elements', 'Loading the FEM mesh ');
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
% List of valid surfaces (not fibers, not FEM) for subject, sorted as in GUI
SortedSurfaces = db_surface_sort(sSubject.Surface);
iSorted = [SortedSurfaces.IndexScalp, SortedSurfaces.IndexOuterSkull, SortedSurfaces.IndexInnerSkull, ...
           SortedSurfaces.IndexCortex, SortedSurfaces.IndexOther];
surfFileNames = {sSubject.Surface(iSorted).FileName};
surfComments  = {sSubject.Surface(iSorted).Comment};
% Add geometric surfaces to list
surfGeoPrimitive = {'Sphere', 'Ellipsoid', 'Cube', 'Cylinder', 'Cone'};
surfGeoComments = cellfun(@(x) [x, ' (primitive surface)'], surfGeoPrimitive, 'UniformOutput', 0);
surfComments  = [surfGeoComments, surfComments];
surfFileNames = [repmat({''}, 1, length(surfGeoComments)), surfFileNames];
% Ask user to select the ROI area
[surfSelectComment, isCancel] = java_dialog('combo', [...
    'Select either a primitive or anatomy surface from the Subject.' 10 ...
    '1) Edit the surface position and size (if needed), then' 10 ...
    '2) Click on the [OK] button on figure toolbar.' 10 10 ...
    'Select the surface to rename FEM elements inside it.' 10], ...
    'Rename FEM elements within a surface', [], surfComments, surfComments{1});
if isempty(surfSelectComment) || isCancel
    bst_progress('stop');
    return
end
% Get surface file
iComment = find(strcmp(surfSelectComment, surfComments), 1);
if iComment <= length(surfGeoComments)
    % New surface file
    SurfaceFile = tess_generate_primitive(iSubject, surfGeoPrimitive{iComment});
    SurfaceFullFile = file_fullpath(SurfaceFile);
else
    % Make a copy of present surface
    SurfaceFullFile = file_unique(file_fullpath(surfFileNames{iComment}));
    if ~file_copy(file_fullpath(surfFileNames{iComment}), SurfaceFullFile)
        errMsg = sprintf(['Could not copy file: ' 10 SurfaceFullFile]);
        if isInteractive
            bst_error(errMsg);
        end
        return
    end
    SurfaceFile = file_short(SurfaceFullFile);
end
% Update comment for surface reference to rename FEM elements
sTmp = load(SurfaceFullFile, 'Comment');
sTmp.Comment = [sTmp.Comment ' | Rename FEM elem: ' NewElemLabel];
bst_save(SurfaceFullFile, sTmp, [], 1);
db_reload_subjects(iSubject);

% Open the GUI for ROI alignement on the FEM Mesh, and wait until closed to continue
global gTessAlign;
tess_align_manual(FemFullFile, file_fullpath(SurfaceFile), 0);
waitfor(gTessAlign.hFig)

% Find all FEM mesh vertices within the ROI surface
centroid = meshcentroid(FemMat.Vertices, FemMat.Elements);
% Unload plugin: 'iso2mesh'
if PlugUnload
    bst_plugin('Unload', 'iso2mesh', 1);
end
% Find elements outside of the ROI surface
sSurf = in_tess_bst(SurfaceFile, 0);
iOutside = find(~inpolyhd(centroid, sSurf.Vertices, sSurf.Faces));
iInside = 1:length(centroid);
% Remove the outside points
if ~isempty(iOutside)
    iInside(iOutside) = [];
end
% Nothing to do
if isempty(iInside)
    errMsg = sprintf(['No FEM elements were found inside surface: ' 10 SurfaceFullFile]);
    if isInteractive
        bst_error(errMsg);
    end
    return
end
% Rename elements inside surface
if isConcatLayer
    iLayerRename = find(strcmp(FemMat.TissueLabels, NewElemLabel));
else
    iLayerRename = max(unique(FemMat.Tissue)) + 1;
    FemMat.TissueLabels = [FemMat.TissueLabels NewElemLabel];
end
FemMat.Tissue(iInside) = iLayerRename;

% === Save FEM mesh with renamed elements
bst_progress('text', 'Saving FEM mesh ...');
% File comment
FemMat.Comment = [FemMat.Comment ' | ' NewElemLabel ];
% Add history
FemMat = bst_history('add', FemMat, ...
    sprintf('Assign FEM elements inside "%s" to "%s" layer', SurfaceFile, NewElemLabel));
% Save to database
FemFile = file_unique(bst_fullfile(bst_fileparts(FemFullFile), sprintf('tess_fem_%dV.mat', length(FemMat.Vertices))));
bst_save(FemFile, FemMat, 'v7');
db_add_surface(iSubject, FemFile, FemMat.Comment);
bst_progress('stop');
% Return success
isOk = 1;

end
