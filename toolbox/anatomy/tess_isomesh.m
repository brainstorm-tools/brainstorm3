function [MeshFile, iSurface] = tess_isomesh(iSubject, isoValue, Comment)
% TESS_GENERATE: Reconstruct a surface mesh based on the MRI/CT, based on an isosurface
%
% USAGE:  [MeshFile, iSurface] = tess_isomesh(iSubject, isoValue=1900, Comment)
%         [MeshFile, iSurface] = tess_isomesh(MriFile,  isoValue=1900, Comment)
%         [Vertices, Faces]    = tess_isomesh(sMri,     isoValue=1900)
%
% If input is loaded MRI/CT structure, no surface file is created and the surface vertices and faces are returned instead.

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
% Authors: Chinmay Chinara, 2023

%% ===== PARSE INPUTS =====
% Initialize returned variables
MeshFile = [];
iSurface = [];
isSave = true;
% Parse inputs
if (nargin < 3) || isempty(Comment)
    Comment = [];
end
% MriFile instead of subject index
sMri = [];
if ischar(iSubject)
    MriFile = iSubject;
    [sSubject, iSubject] = bst_get('MriFile', MriFile);
elseif isnumeric(iSubject)
    % Get subject
    sSubject = bst_get('Subject', iSubject);
    MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
elseif isstruct(iSubject)
    sMri = iSubject;
    MriFile = sMri.FileName;
    [sSubject, iSubject] = bst_get('MriFile', MriFile);
    % Don't save a surface file, instead return surface directly.
    isSave = false;  
else
    error('Wrong input type.');
end

%% ===== LOAD MRI =====
isProgress = ~bst_progress('isVisible');
if isempty(sMri)
    % Load MRI
    bst_progress('start', 'Generate mesh from CT/MRI', 'Loading MRI...');
    sMri = bst_memory('LoadMri', MriFile);
    % if isProgress
    %     bst_progress('stop');
    % end
end
% Save current scouts modifications
panel_scout('SaveModifications');
% If subject is using the default anatomy: use the default subject instead
if sSubject.UseDefaultAnat
    iSubject = 0;
end
% Check layers
if isempty(sSubject.iAnatomy) || isempty(sSubject.Anatomy)
    bst_error('The generate of the head surface requires at least the MRI of the subject.', 'Head surface', 0);
    return
end
% Check that everything is there
if ~isfield(sMri, 'Histogram') || isempty(sMri.Histogram) || isempty(sMri.SCS) || isempty(sMri.SCS.NAS) || isempty(sMri.SCS.LPA) || isempty(sMri.SCS.RPA)
    bst_error('You need to set the fiducial points in the MRI first.', 'Head surface', 0);
    return
end

%% ===== ASK PARAMETERS =====
% Ask user to set the parameters if they are not set
if (nargin < 2) || isempty(isoValue)
    res = java_dialog('input', {'<HTML>Background level (HU):<BR>(guessed from MRI histogram)', '<HTML>White level (HU):<BR>(guessed from MRI histogram)', '<HTML>Set isoValue (HU):'}, ...
                                'Generate isosurface', ...
                                [], ...
                                {num2str(sMri.Histogram.bgLevel), num2str(sMri.Histogram.whiteLevel), num2str(1900)});
    % If user cancelled: return
    if isempty(res) || strcmpi(res{3},'0')
        return
    end
    % Get new values
    isoValue   = str2num(res{3});
else
    isoValue = sMri.Histogram.whiteLevel;
end
% Check parameters values
if isempty(isoValue)
    bst_error('Invalid parameters.', 'Mesh surface', 0);
    return
end


%% ===== CREATE SURFACE =====
% Compute isosurface
bst_progress('text', 'Creating isosurface...');
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
    bst_progress('text', 'Saving new file...');
    % Create output filenames
    ProtocolInfo = bst_get('ProtocolInfo');
    SurfaceDir   = bst_fullfile(ProtocolInfo.SUBJECTS, bst_fileparts(MriFile));
    MeshFile  = file_unique(bst_fullfile(SurfaceDir, 'tess_head_mask.mat'));
    % Save isosurface
    sMesh.Comment = sprintf('isoSurface (ISO_%d)', isoValue);
    sMesh = bst_history('add', sMesh, 'bem', 'MRI/CT mesh isosurface generated with Brainstorm');
    bst_save(MeshFile, sMesh, 'v7');
    iSurface = db_add_surface(iSubject, MeshFile, sMesh.Comment);
    view_surface(MeshFile);
else
    % Return surface
    MeshFile = sMesh.Vertices;
    iSurface = sMesh.Faces;
end

% Close, success
if isProgress
    bst_progress('stop');
end

% %% Manipulate mesh
% % Show Coordinates panel
% gui_show('panel_coordinates_seeg', 'JavaWindow', 'Get coordinates', [], 0, 1, 0);
% % Start point selection
% panel_coordinates_seeg('SetSelectionState', 1);

% Show ieeg panel
% gui_show('panel_ieeg', 'JavaWindow', 'sEEG', [], 0, 1, 0);