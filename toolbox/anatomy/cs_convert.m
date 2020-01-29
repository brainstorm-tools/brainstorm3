function [P, Transf] = cs_convert(sMri, src, dest, P)
% CS_CONVERT: Convert 3D points between coordinates systems.
%
% USAGE:       P = cs_convert(sMri, src, dest, P)
%         Transf = cs_convert(sMri, src, dest)
%
% INPUT: 
%     - sMri  : Brainstorm MRI structure
%     - src   : Current coordinate system {'voxel','mri','scs','mni','world'}
%     - dest  : Target coordinate system {'voxel','mri','scs','mni','world'}
%     - P     : a Nx3 matrix of point coordinates to convert
%
% DESCRIPTION:   https://neuroimage.usc.edu/brainstorm/CoordinateSystems
%     - voxel : X=left>right,  Y=posterior>anterior,   Z=bottom>top
%               Coordinate of the center of the first voxel at the bottom-left-posterior of the MRI volume: (1,1,1)
%     - mri   : Same as 'voxel' but in millimeters instead of voxels:  mriXYZ = voxelXYZ * Voxsize
%     - scs   : Based on: Nasion, left pre-auricular point (LPA), and right pre-auricular point (RPA).
%               Origin: Midway on the line joining LPA and RPA
%               Axis X: From the origin towards the Nasion (exactly through)
%               Axis Y: From the origin towards LPA in the plane defined by (NAS,LPA,RPA), and orthogonal to X axis
%               Axiz Z: From the origin towards the top of the head 
%     - mni   : MNI coordinates based on SPM affine registration
%     - world : Transformation available in the initial file loaded as the default MRI (vox2ras/qform/world transformation)

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
% Authors: Francois Tadel, 2008-2019

% Check matrices orientation
if (nargin < 4) || isempty(P)
    P = [];
elseif (size(P,2) ~= 3) && (size(P,1) == 3)
    P = P';
elseif (size(P,2) ~= 3)
    error('P must have 3 columns (X,Y,Z).');
end
% If the coordinate system didn't change
if strcmpi(src, dest)
    return;
end
% Transform to homogeneous coordinates
if ~isempty(P)
    P = [P'; ones(1,size(P,1))];
end

% ===== GET MRI=>WORLD TRANSFORMATION =====
if strcmpi(src, 'world') || strcmpi(dest, 'world')
    % Get the vox2ras transformation
    if isempty(sMri.InitTransf)
        P = [];
        return;
    end
    iTransf = find(strcmpi(sMri.InitTransf(:,1), 'vox2ras'));
    if isempty(iTransf)
        P = [];
        return;
    end
    vox2ras = sMri.InitTransf{iTransf,2};
    % 2nd operation: Change reference from (0,0,0) to (.5,.5,.5)
    vox2ras = vox2ras * [1 0 0 -.5; 0 1 0 -.5; 0 0 1 -.5; 0 0 0 1];
    % 1st operation: Convert from MRI(mm) to voxels
    vox2ras = vox2ras * diag(1 ./ [sMri.Voxsize, 1]);
    % Convert to meters: transformation MRI=>WORLD (in meters)
    mri2world = vox2ras .* [ones(3,3), 1e-3.*ones(3,1); ones(1,4)];
    % Compute inverse transformation WORLD=>MRI (in meters)
    world2mri = inv(mri2world);
end

% ===== CONVERT SRC => MRI =====
% Evaluate the transformation to apply
switch lower(src)
    case 'voxel'
        RT1 = diag([sMri.Voxsize(:) ./ 1000; 1]);
    case 'mri'
        RT1 = eye(4);
    case 'scs'
        if ~isfield(sMri,'SCS') || ~isfield(sMri.SCS,'R') || isempty(sMri.SCS.R) || ~isfield(sMri.SCS,'T') || isempty(sMri.SCS.T)
            P = [];
            return;
        end
        RT1 = inv([sMri.SCS.R, sMri.SCS.T./1000; 0 0 0 1]);
    case 'mni'
        if ~isfield(sMri,'NCS') || ~isfield(sMri.NCS,'R') || isempty(sMri.NCS.R) || ~isfield(sMri.NCS,'T') || isempty(sMri.NCS.T)
            P = [];
            return;
        end
        RT1 = inv([sMri.NCS.R, sMri.NCS.T./1000; 0 0 0 1]);
    case 'world'
        RT1 = world2mri;
    otherwise
        error(['Invalid coordinate system: ' src]);
end

% ===== CONVERT MRI => DEST =====
% Evaluate the transformation to apply
switch lower(dest)
    case 'voxel'
        RT2 = diag([1000 ./ sMri.Voxsize(:); 1]);
    case 'mri'
        RT2 = eye(4);
    case 'scs'
        if ~isfield(sMri,'SCS') || ~isfield(sMri.SCS,'R') || isempty(sMri.SCS.R) || ~isfield(sMri.SCS,'T') || isempty(sMri.SCS.T)
            P = [];
            return;
        end
        RT2 = [sMri.SCS.R, sMri.SCS.T./1000; 0 0 0 1];
    case 'mni'
        if ~isfield(sMri,'NCS') || ~isfield(sMri.NCS,'R') || isempty(sMri.NCS.R) || ~isfield(sMri.NCS,'T') || isempty(sMri.NCS.T)
            P = [];
            return;
        end
        RT2 = [sMri.NCS.R, sMri.NCS.T./1000; 0 0 0 1];
    case 'world'
        RT2 = mri2world;
    otherwise
        error(['Invalid coordinate system: ' dest]);
end
% Compute the final transformation matrix
Transf = RT2 * RT1;

% Apply the transformation matrix to the points
if ~isempty(P)
    % Apply rotation-translation
    P = Transf * P;
    % Remove the last coordinate and transpose the matrix back
    P = P(1:3,:)';
else
    P = Transf;
end


