function tess2mri_interp = tess_interp_mri(SurfaceFile, MRI)
% TESS_INTERP_MRI: Interpolate a surface or a grid of points into a MRI.
%
% USAGE:  tess2mri_interp = tess_interp_mri(SurfaceFile, MRI)
%
% INPUT: 
%     - SurfaceFile : Full path to a Brainstorm surface file
%     - MRI         : Brainstorm MRI structure
% OUTPUT:
%     - tess2mri_interp : Huge sparse matrix [nbVoxels, nbVertices]

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
% Authors: Sylvain Baillet, 2002
%          Francois Tadel, 2006 (University of Geneva)
%          Francois Tadel, 2008-2011 (USC)


% ===== CHECK MRI =====
% Check that MRI SCS is well defined
if ~isfield(MRI,'SCS') || ~isfield(MRI.SCS,'R') || ~isfield(MRI.SCS,'T') || isempty(MRI.SCS.R) || isempty(MRI.SCS.T)
    error(['MRI SCS (Subject Coordinate System) was not defined or subjectimage file is from another version of Brainstorm.' 10 10,...
           'Please define the SCS fiducials on this MRI.']);
end
cubeSize = size(MRI.Cube);
% Progres bar
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'Compute interpolation: surface/MRI', 'Initialization...');
end

% ===== LOAD SURFACE =====
bst_progress('text', 'Loading surface...');
% Load surface
sSurf = bst_memory('LoadSurface', SurfaceFile);
Vertices = sSurf.Vertices;
Faces    = sSurf.Faces;
% Vertices: SCS->Voxels
Vertices = cs_convert(MRI, 'scs', 'voxel', Vertices);


% ===== CHECK VERTICES LOCATION =====
% Get all the vertices that are outside the MRI volume
iOutsideVert = find((Vertices(:,1) >= cubeSize(1)) | (Vertices(:,1) < 2) | ...
                    (Vertices(:,2) >= cubeSize(2)) | (Vertices(:,2) < 2) | ...
                    (Vertices(:,3) >= cubeSize(3)) | (Vertices(:,3) < 2));
% Compute percentage of vertices outside the MRI
percentOutside = length(iOutsideVert) / length(Vertices);
% If more than 95% vertices are outside the MRI volume : exit with ar error message
if (percentOutside > .95)
    tess2mri_interp = [];
    java_dialog('error', ['Surface is not registered with the MRI.' 10 'Please try to import all your surfaces again.'], 'Surface -> MRI');
    return;
% If more than 10% vertices are outside the MRI volume : display warning message
elseif (percentOutside > .4)
    java_dialog('warning', ['Surface does not seem to be registered with the MRI.', 10 10 ...
                'Please right-click on surface node and execute' 10 ' "Align>Align all surfaces...".'], ...
                'Surface -> MRI');
end


% ===== INTERPOLATION SURFACE -> MRI =====
bst_progress('text', 'Computing interpolation...');
% If interpolation matrix already computed:
if isfield(sSurf, 'tess2mri_interp') && ~isempty(sSurf.tess2mri_interp)
    tess2mri_interp = sSurf.tess2mri_interp;
% Else: Compute it 
else
    % Compute interpolation matrix from tessellation to MRI voxel grid
    tess2mri_interp = tess_tri_interp(Vertices, Faces, cubeSize);
    % Get full surface filename
    SurfaceFile = file_fullpath(SurfaceFile);
    % Save new interpolation matrix into file
    if file_exist(SurfaceFile)
        s.tess2mri_interp = tess2mri_interp;
        bst_save(SurfaceFile, s, 'v7', 1);
    end
end

% Close progress bar
if ~isProgress
    bst_progress('stop');
end


