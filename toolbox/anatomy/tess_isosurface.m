function [MeshFile, iSurface] = tess_isosurface(iSubject, isoValue, Comment)
% TESS_ISOSURFACE: Reconstruct a thresholded surface mesh from a CT
%
% USAGE:  [MeshFile, iSurface] = tess_isosurface(iSubject, isoValue, Comment)
%         [MeshFile, iSurface] = tess_isosurface(iSubject)
%         [MeshFile, iSurface] = tess_isosurface(CtFile,  isoValue, Comment)
%         [MeshFile, iSurface] = tess_isosurface(CtFile)
%         [Vertices, Faces]    = tess_isosurface(sMri,     isoValue)
%         [Vertices, Faces]    = tess_isosurface(sMri)
%
% INPUT:
%    - iSubject    : Indice of the subject where to add the surface
%    - isoValue    : The value in Housefield Unit to set for thresholding the CT. If this parameter is empty, then a GUI pops up asking the user for the desired value
%    - Comment     : Surface description
% OUTPUT:
%    - MeshFile : indice of the surface that was created in the sSubject structure
%    - iSurface : indice of the surface that was created in the sSubject structure
%    - Vertices : The vertices of the mesh
%    - Faces    : The faces of the mesh
%         
% If input is loaded CT structure, no surface file is created and the surface vertices and faces are returned instead.
%
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
% Inspired by tess_isohead.m
%
% Authors: Chinmay Chinara, 2023-2024

%% ===== PARSE INPUTS =====
% Initialize returned variables
MeshFile = [];
iSurface = [];
isSave = true;

% Parse inputs
if (nargin < 3) || isempty(Comment)
    Comment = [];
end
% CtFile instead of subject index
sMri = [];
if ischar(iSubject)
    CtFile = iSubject;
    [sSubject, iSubject] = bst_get('MriFile', CtFile);
elseif isnumeric(iSubject)
    % Get subject
    sSubject = bst_get('Subject', iSubject);
    CtFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
elseif isstruct(iSubject)
    sMri = iSubject;
    CtFile = sMri.FileName;
    [sSubject, iSubject] = bst_get('MriFile', CtFile);
    % Don't save a surface file, instead return surface directly.
    isSave = false;  
else
    error('Wrong input type.');
end

%% ===== LOAD CT =====
isProgress = ~bst_progress('isVisible');
if isempty(sMri)
    % Load CT
    bst_progress('start', 'Generate thresholded isosurface from CT', 'Loading CT...');
    sMri = bst_memory('LoadMri', CtFile);
    if isProgress
        bst_progress('stop');
    end
end
% Save current scouts modifications
panel_scout('SaveModifications');
% If subject is using the default anatomy: use the default subject instead
if sSubject.UseDefaultAnat
    iSubject = 0;
end
% Check layers
if isempty(sSubject.iAnatomy) || isempty(sSubject.Anatomy)
    bst_error('The surface generation requires at least the CT of the subject.', 'Generate isosurface', 0);
    return
end
% Check that everything is there
if ~isfield(sMri, 'Histogram') || isempty(sMri.Histogram) || isempty(sMri.SCS) || isempty(sMri.SCS.NAS) || isempty(sMri.SCS.LPA) || isempty(sMri.SCS.RPA)
    bst_error('You need to set the fiducial points in the MRI first.', 'Generate isosurface', 0);
    return
end

%% ===== ASK PARAMETERS =====
% Ask user to set the parameters if they are not set
if (nargin < 2) || isempty(isoValue)
    res = java_dialog('input', ['<HTML>Background level guessed from MRI histogram (<B>HU</B>):<BR><B>', num2str(round(sMri.Histogram.bgLevel)), ...
                                '</B><BR>White level guessed from MRI histogram (<B>HU</B>):<BR><B>', num2str(round(sMri.Histogram.whiteLevel)), ...
                                '</B><BR>Max intensity level guessed from MRI histogram (<B>HU</B>):<BR><B>', num2str(round(sMri.Histogram.intensityMax)), ...
                                '</B><BR><BR>Set isoValue for thresholding (<B>HU</B>):' ...
                                '<BR>(estimate below is mean of whitelevel and max intensity)'], ...
                                'Generate isosurface', [], num2str(round((sMri.Histogram.whiteLevel+sMri.Histogram.intensityMax)/2)));

    % If user cancelled: return
    if isempty(res)
        return
    end
    % Get new value isoValue
    isoValue = round(str2double(res));
end
isoRange = double(round([sMri.Histogram.whiteLevel, sMri.Histogram.intensityMax]));

% Check parameters values
% isoValue cannot be < 0 as there cannot be negative intensity in the CT
% isoValue=0 does not makes sense as it means we do not want to do any thresholding
% isoValue cannot be > the maximum intensity of the CT as it means there is nothing to generate or threshold on
if isempty(isoValue) || isoValue <= 0 || isoValue > round(sMri.Histogram.intensityMax)
    bst_error('Invalid ''isoValue''. Enter proper values.', 'Mesh surface', 0);
    return
end


%% ===== CREATE SURFACE =====
% Compute isosurface
bst_progress('start', 'Generate thresholded isosurface from CT', 'Creating isosurface...');
% Find tess_isosurface file computed using the same CT volume
iIsoSurfForThisCt = 0;
iIsoSrfs = find(cellfun(@(x) ~isempty(regexp(x, 'tess_isosurface', 'match')), {sSubject.Surface.FileName}));
for ix = 1 : length(iIsoSrfs)
    CtFileIso = panel_surface('GetIsosurfaceParams', sSubject.Surface(iIsoSrfs(ix)).FileName);
    if strcmp(CtFileIso, CtFile)
        iIsoSurfForThisCt = iIsoSrfs(ix);
    end
end

[sMesh.Faces, sMesh.Vertices] = mri_isosurface(sMri.Cube, isoValue);
bst_progress('inc', 10);
% Downsample to a maximum number of vertices
maxIsoVert = 60000;
if (length(sMesh.Vertices) > maxIsoVert)
    bst_progress('text', 'Downsampling isosurface...');
    [sMesh.Faces, sMesh.Vertices] = reducepatch(sMesh.Faces, sMesh.Vertices, maxIsoVert./length(sMesh.Vertices));
    bst_progress('inc', 10);
end

% Convert to millimeters
sMesh.Vertices = sMesh.Vertices(:,[2,1,3]);
sMesh.Faces    = sMesh.Faces(:,[2,1,3]);
sMesh.Vertices = bst_bsxfun(@times, sMesh.Vertices, sMri.Voxsize);
% Convert to SCS
sMesh.Vertices = cs_convert(sMri, 'mri', 'scs', sMesh.Vertices ./ 1000);

%% ===== SAVE FILES =====
if isSave
    bst_progress('text', 'Saving file...');
    % Create output filenames
    SurfaceDir = bst_fileparts(file_fullpath(CtFile));
    % Create or Overwrite tess_isosurface file
    if iIsoSurfForThisCt == 0
        % Create IsoFile
        MeshFile = file_unique(bst_fullfile(SurfaceDir, 'tess_isosurface.mat'));
        comment = sprintf('isoSurface (ISO_%d)', isoValue);
        isAppend = 0;
    else
        % Get old IsoValue
        [~, oldIsoValue] = panel_surface('GetIsosurfaceParams', sSubject.Surface(iIsoSurfForThisCt).FileName);
        % Overwrite the updated fields, do not delete the file
        MeshFile = file_fullpath(sSubject.Surface(iIsoSurfForThisCt).FileName);
        % Force to be the newest isosurface
        sSubject.Surface(iIsoSurfForThisCt) = [];
        bst_set('Subject', iSubject, sSubject);
        % Get Comment and update it
        sMeshTmp = load(MeshFile, 'Comment', 'History');
        comment = strrep(sMeshTmp.Comment, num2str(oldIsoValue), num2str(isoValue));
        isAppend = 1;
    end
    % Set comment
    sMesh.Comment = comment;
    % Set history
    sMesh = bst_history('add', sMesh, 'threshold_ct', ...
                        sprintf('Thresholded CT: %s threshold = %d minVal = %d maxVal = %d', sMri.FileName, isoValue, isoRange));
    % Save isosurface
    bst_save(MeshFile, sMesh, 'v7', isAppend);
    % Add isosurface to database
    iSurface = db_add_surface(iSubject, MeshFile, sMesh.Comment);
    % Display mesh with 3D orthogonal slices of the default MRI
    MriFile = sSubject.Anatomy(1).FileName;
    hFig = bst_figures('GetFiguresByType', '3DViz');
    if isempty(hFig)
        hFig = view_mri_3d(MriFile, [], 0.3, []);
    end
    view_surface(MeshFile, 0.6, [], hFig, []);    
    panel_surface('SetIsoValue', isoValue);
else
    % Return surface
    MeshFile = sMesh.Vertices;
    iSurface = sMesh.Faces;
end

% Close, success
if isProgress
    bst_progress('stop');
end