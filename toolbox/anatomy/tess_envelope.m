function [sEnvelope, sSurface] = tess_envelope(SurfaceFile, method, nvert, scale, MriFile, isRemesh, dilateMask, DEBUG)
% TESS_ENVELOPE: Compute a regular envelope of a tesselation.
%
% USAGE:  [sEnvelope, sSurface] = tess_envelope(SurfaceFile, method, nvert, scale=0, MriFile=[], isRemesh=1, dilateMask=-2)
%         [sEnvelope, sSurface] = tess_envelope(SurfaceFile, method, nvert, scale)
%         [sEnvelope, sSurface] = tess_envelope(SurfaceFile, method, nvert)
%         [sEnvelope, sSurface] = tess_envelope(SurfaceFile)
%         
% INPUT:
%    - SurfaceFile : File name to process
%    - method      : {'convhull', 'mask_cortex', 'mask_head'}
%    - nvert       : Number of vertices in the output mesh (approximated to the closest possible number by tess_sphere)
%    - scale       : Scale factor to increase the volume of the envelope, in meters (default: 0)
%    - MriFile     : Mri file can be specified, in case the surface being processed is not in the database
%    - isRemesh    : If 1, call tess_remesh for producing a smoothe surface
%    - dilateMask  : If >1, dilate N times the surface mask (only when computing a mask)
%                    If <1, erode N times the surface mask (only when computing a mask)
% OUTPUT:
%    - sEnvelope : Structure with Vertices and Faces fields of the envelope
%    - sSurface  : Structure with Vertices and Faces fields of the initial file

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
% Authors: Francois Tadel, 2010-2017

%% ===== PARSE INPUTS =====
if (nargin < 8) || isempty(DEBUG)
    DEBUG = 0;
end
if (nargin < 7) || isempty(dilateMask)
    dilateMask = -2;
end
if (nargin < 6) || isempty(isRemesh)
    isRemesh = 1;
end
if (nargin < 5) || isempty(MriFile)
    MriFile = [];
end
if (nargin < 4) || isempty(scale)
    scale = [];
end
if (nargin < 3) || isempty(nvert)
    nvert = [];
end
if (nargin < 2) || isempty(method)
    method = 'convhull';
end

% Returned structures
sEnvelope = [];
sSurface = [];
% Progress bar
isProgress = ~bst_progress('isVisible');
if isProgress
    bst_progress('start', 'Create envelope', 'Initialization');
end

%% ===== LOAD SURFACE =====
bst_progress('text', 'Envelope: Loading surface...');
% Get MRI file
if isempty(MriFile)
    sSubject = bst_get('SurfaceFile', SurfaceFile);
    if isempty(sSubject.iAnatomy)
        bst_error('Please define all the fiducials (AC,PC,IH) in the MRI volume.', 'Surface envelope', 0);
        return;
    end
    MriFile = file_fullpath(sSubject.Anatomy(sSubject.iAnatomy).FileName);
end
% Load surface
sSurface = in_tess_bst(SurfaceFile, 0);
% Load NCS structures from MRIs (contains the fiducials AC,PC,IH)
sMri = load(MriFile, 'NCS', 'SCS');
% Copy all the fiducials in the surface structure
if ~isfield(sMri,'NCS') || ~isfield(sMri.NCS,'AC') || isempty(sMri.NCS.AC)
    bst_error('Please define all the fiducials (AC,PC,IH) in the MRI volume.', 'Surface envelope', 0);
    return;
end


%% ===== SURFACE ENVELOPE =====
switch lower(method)
    % Using convex hull of the surface
    case 'convhull'
        bst_progress('text', 'Envelope: Computing convex hull...');
        % Compute the convex envelope of the surface
        env_vert = double(sSurface.Vertices);
        Faces = convhulln(env_vert);
        % Get the vertices that are used
        iVert = unique(Faces(:));
        % Remove the unused vertices
        iRemoveVert = setdiff(1:length(env_vert), iVert);
        [env_vert, env_faces] = tess_remove_vert(env_vert, Faces, iRemoveVert);
        % Smooth envelope
        % bst_progress('text', 'Envelope: Smoothing surface...');
        % env_vertconn = tess_vertconn(env_vert, env_faces);
        % env_vert = tess_smooth(env_vert, 1, 2, env_vertconn);
        % Refine the faces that are too big
        [env_vert, env_faces] = tess_refine(env_vert, env_faces, 3);
        [env_vert, env_faces] = tess_refine(env_vert, env_faces, 3);

    % Using an MRI mask
    case {'mask_cortex', 'mask_head'}
        % Compute/get MRI mask for the surface
        bst_progress('text', 'Envelope: Computing MRI mask...');
        [mrimask, sMri] = bst_memory('GetSurfaceMask', SurfaceFile, MriFile);
        % Fill holes
        bst_progress('text', 'Envelope: Filling holes...');
        if strcmpi(method, 'mask_cortex')
            mrimask = mri_fillholes(mrimask, 3);
        else
            mrimask = mri_fillholes(mrimask, 2);
            mrimask = mri_fillholes(mrimask, 1);
        end
        % Closing all the faces of the cube
        mrimask(1,:,:)   = 0*mrimask(1,:,:);
        mrimask(end,:,:) = 0*mrimask(1,:,:);
        mrimask(:,1,:)   = 0*mrimask(:,1,:);
        mrimask(:,end,:) = 0*mrimask(:,1,:);
        mrimask(:,:,1)   = 0*mrimask(:,:,1);
        mrimask(:,:,end) = 0*mrimask(:,:,1);
        % Erode/dilate ]the mask
        for i = 1:abs(dilateMask)
            if (dilateMask > 0)
                mrimask = mri_dilate(mrimask, 1);
            else
                mrimask = mrimask & ~mri_dilate(~mrimask, 1);
            end
        end
        % Compute isosurface
        bst_progress('text', 'Envelope: Creating isosurface...');
        [env_faces, env_vert] = mri_isosurface(mrimask, 0.5);
        % Swap faces
        env_faces = env_faces(:,[2 1 3]);
        % Smooth isosurface
        bst_progress('text', 'Envelope: Smoothing surface...');
        env_vertconn = tess_vertconn(env_vert, env_faces);
        env_vert = tess_smooth(env_vert, 1, 10, env_vertconn, 0);
        % Downsampling isosurface
        bst_progress('text', 'Envelope: Downsampling surface...');
        [env_faces, env_vert] = reducepatch(env_faces, env_vert, 10000./length(env_vert));
        % Convert in millimeters
        env_vert = env_vert(:,[2,1,3]);
        env_vert = bst_bsxfun(@times, env_vert, sMri.Voxsize);
        % Convert in SCS coordinates
        env_vert = cs_convert(sMri, 'mri', 'scs', env_vert ./ 1000);
end


%% ===== RE-ORIENT ENVELOPE =====
% Compute the center of the head
head_center = mean(env_vert);
% Center head on (0,0,0)
env_vert = bst_bsxfun(@minus, env_vert, head_center);
% Orient in Talairach coordinate system
Transf = cs_compute(sMri, 'tal');
if isempty(Transf)
    error('Could not compute the MRI=>TAL transformation.');
end
R = Transf.R';
T = Transf.T';
env_vert = env_vert * R;


%% ===== REMESH ENVELOPE =====
if isRemesh
    bst_progress('text', 'Envelope: Remeshing surface...');
    [sph_vert, sph_faces] = tess_remesh(double(env_vert), nvert);
else
    bst_progress('text', 'Envelope: Downsampling surface...');
    [sph_faces, sph_vert] = reducepatch(env_faces, env_vert, nvert / size(env_vert,1));
end

if isempty(sph_vert)
    bst_error('The number of vertices chosen produces an empty envelope.', 'Surface envelope', 0);
    return;
end

%% ===== CREATE OUTPUT STRUCTURE =====
% Rescale
if ~isempty(scale)
    % Convert to spherical coordinates
    [sph_th,sph_phi,sph_r] = cart2sph(sph_vert(:,1), sph_vert(:,2), sph_vert(:,3));
    % Apply scale to radius
    sph_r = sph_r + scale;
    % Convert back to cartesian coordinates
    [sph_vert(:,1),sph_vert(:,2),sph_vert(:,3)] = sph2cart(sph_th, sph_phi, sph_r);
end
% Restore initial coordinate system
sph_vert = sph_vert * inv(R);
sph_vert = bst_bsxfun(@plus, sph_vert, head_center);
% Create returned structure
sEnvelope.Vertices = sph_vert;
sEnvelope.Faces    = sph_faces;
sEnvelope.R        = R;
sEnvelope.T        = T;
sEnvelope.center   = head_center;
sEnvelope.NCS      = sMri.NCS;
sEnvelope.SCS      = sMri.SCS;
% Close progress bar
if isProgress
    bst_progress('stop');
end
% Debug display of input and output surfaces
if DEBUG
    hFig = view_surface_matrix(sSurface.Vertices, sSurface.Faces, 0);
    [hFig, iDS, iFig, hPatch] = view_surface_matrix(sEnvelope.Vertices, sEnvelope.Faces, .7, [1 0 0], hFig);
    set(hPatch, 'EdgeColor', [1 0 0]);
end



