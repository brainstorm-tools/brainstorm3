function [P, Transf] = cs_convert(sMri, src, dest, P, isNanAllowed)
% CS_CONVERT: Convert 3D points between coordinates systems.
%
% USAGE:       P = cs_convert(sMri, src, dest, P, isNanAllowed=0)
%         Transf = cs_convert(sMri, src, dest)
%
% INPUT: 
%     - sMri         : Brainstorm MRI structure
%     - src          : Current coordinate system {'voxel','mri','scs','mni','acpc','world','captrak'}
%     - dest         : Target coordinate system {'voxel','mri','scs','mni','acpc','world','captrak'}
%     - P            : a Nx3 matrix of point coordinates to convert
%     - isNanAllowed : If 0, throw an error and if the conversion of some points P leads to NaN,
%                      and if there is no linear MNI registration to be used instead
%                      (case of non-linear MNI registration with points outside of the defined area)
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
%     - mni   : MNI coordinates based on SPM affine or non-linear registration
%     - acpc  : Based on: Anterior commissure (AC), Posterior commissure (PC) and an interhemisperic point (IH)
%               Origin: AC
%               Axis X: From the origin towards the right
%               Axis Y: Negative y-axis is passing from AC through PC
%               Axis Z: Passing through a mid-hemispheric point in the superior direction
%     - world : Transformation available in the initial file loaded as the default MRI (vox2ras/qform/world transformation)
%     - captrak: RAS orientation and the origin approximately between LPA and RPA
%               Axis X: From LPA through RPA exactly
%               Axis Y: Orthogonal to the X-axis through the nasion (NAS)
%               Axis Z: Orthogonal to the XY-plane through the vertex of the head

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
% Authors: Francois Tadel, 2008-2022

% Throw errors by default if NaN
if (nargin < 5) || isempty(isNanAllowed)
    isNanAllowed = 0;
end
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
% Keep track of points that cannot be transformed
iMissing = [];
isApplied = 0;
Porig = P;
% Transform to homogeneous coordinates
if ~isempty(P)
    P = [P'; ones(1,size(P,1))];
end

% ===== GET MRI=>WORLD TRANSFORMATION =====
if strcmpi(src, 'world') || strcmpi(dest, 'world') || (strcmpi(src, 'mni') && isfield(sMri,'NCS') && isfield(sMri.NCS,'y') && ~isempty(sMri.NCS.y))
    % Get the vox2ras transformation
    if isempty(sMri) || isempty(sMri.InitTransf)
        P = [];
        return;
    end
    iTransf = find(strcmpi(sMri.InitTransf(:,1), 'vox2ras'));
    if isempty(iTransf)
        P = [];
        return;
    end
    vox2ras = sMri.InitTransf{iTransf,2};
    % 2nd operation: Change reference from (0,0,0) to (1,1,1)
    vox2ras = vox2ras * [1 0 0 -1; 0 1 0 -1; 0 0 1 -1; 0 0 0 1];
    % 1st operation: Convert from MRI(mm) to voxels
    vox2ras = vox2ras * diag(1 ./ [sMri.Voxsize, 1]);
    % Convert to meters: transformation MRI=>WORLD (in meters)
    mri2world = vox2ras .* [ones(3,3), 1e-3.*ones(3,1); ones(1,4)];
    % Compute inverse transformation WORLD=>MRI (in meters)
    world2mri = inv(mri2world);
end

% ===== COMPUTE ACPC TRANSFORMATION =====
if strcmpi(src, 'acpc') || strcmpi(dest, 'acpc')
    tACPC = cs_compute(sMri, 'acpc');
    if isempty(tACPC) || isempty(tACPC.R)
        P = [];
        return;
    end
    scs2acpc = [tACPC.R, tACPC.T; 0 0 0 1];
end

% ===== COMPUTE CAPTRAK TRANSFORMATION =====
if strcmpi(src, 'captrak') || strcmpi(dest, 'captrak')
    tCapTrak = cs_compute(sMri, 'captrak');
    if isempty(tCapTrak) || isempty(tCapTrak.R)
        P = [];
        return;
    end
    scs2captrak = [tCapTrak.R, tCapTrak.T; 0 0 0 1];
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
        % Transformation of each point by indirection in the deformation field y
        if ~isempty(P) && isfield(sMri,'NCS') && isfield(sMri.NCS,'y') && ~isempty(sMri.NCS.y)
            % Convert MNI => voxel space of the registration matrix
            P_reg = inv(sMri.NCS.y_vox2ras) * (P .* [1000;1000;1000;1]);
            % Convert from 0-based to 1-based??
            % => This solution was obtained empirically by minimizing: 
            %    sqrt(sum((cs_convert(sMri, 'mri', 'mni', cs_convert(sMri, 'mni', 'mri', P)) - P).^2)).*1000 => around 0.003 with this adjustment
            P_reg = P_reg + [1;1;1;0];
            % Convert Voxel => World
            P_world = [...
                interp3(sMri.NCS.y(:,:,:,1), P_reg(2,:), P_reg(1,:), P_reg(3,:), 'linear', NaN); ...
                interp3(sMri.NCS.y(:,:,:,2), P_reg(2,:), P_reg(1,:), P_reg(3,:), 'linear', NaN); ...
                interp3(sMri.NCS.y(:,:,:,3), P_reg(2,:), P_reg(1,:), P_reg(3,:), 'linear', NaN)] ./ 1000;
            % Check if some points could not be converted
            if ~isNanAllowed
                iMissing = find(any(isnan(P_world),1));
            end
            % Convert World => MRI
            P = world2mri * [double(P_world); ones(1, size(P_world,2))];
            RT1 = eye(4);
        elseif isfield(sMri,'NCS') && isfield(sMri.NCS,'R') && ~isempty(sMri.NCS.R) && isfield(sMri.NCS,'T') && ~isempty(sMri.NCS.T)
            RT1 = inv([sMri.NCS.R, sMri.NCS.T./1000; 0 0 0 1]);
        else
            P = [];
            return;
        end
    case 'acpc'
        % ACPC => SCS => MRI
        RT1 = inv(scs2acpc);
    case 'captrak'
        % CapTrak => SCS => MRI
        RT1 = inv(scs2captrak);
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
        % Using non-linear MNI normalization: Transformation of each point by indirection in the deformation field iy
        if ~isempty(P) && isfield(sMri,'NCS') && isfield(sMri.NCS,'iy') && ~isempty(sMri.NCS.iy)
            % Convert: src => MRI => voxel
            P_vox = diag([1000 ./ sMri.Voxsize(:); 1]) * RT1 * P;
            % Get values from the iy volumes
            Pmni = [interp3(sMri.NCS.iy(:,:,:,1), P_vox(2,:), P_vox(1,:), P_vox(3,:), 'linear', NaN); ...
                 interp3(sMri.NCS.iy(:,:,:,2), P_vox(2,:), P_vox(1,:), P_vox(3,:), 'linear', NaN); ...
                 interp3(sMri.NCS.iy(:,:,:,3), P_vox(2,:), P_vox(1,:), P_vox(3,:), 'linear', NaN)] ./ 1000;
            % Check if some points could not be converted
            if ~isNanAllowed
                iMissing = find(any(isnan(Pmni),1));
            end
            % Transpose the matrix back
            P = double(Pmni');
            Transf = [];
            isApplied = 1;
        elseif isfield(sMri,'NCS') && isfield(sMri.NCS,'R') && ~isempty(sMri.NCS.R) && isfield(sMri.NCS,'T') && ~isempty(sMri.NCS.T)
            RT2 = [sMri.NCS.R, sMri.NCS.T./1000; 0 0 0 1];
        else
            P = [];
            return;
        end
    case 'acpc'
        % MRI => SCS => ACPC
        RT2 = scs2acpc;
    case 'captrak'
        % MRI => SCS => CapTrak
        RT2 = scs2captrak;
    case 'world'
        RT2 = mri2world;
    otherwise
        error(['Invalid coordinate system: ' dest]);
end

% If the final transformation is not already applied
if ~isApplied
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
end

% If there are NaN points from non-linear MNI: Try to fix them with linear MNI
if ~isempty(iMissing)
    % If there is a linear transformation available as well, use it for missing points (same code as below)
    if isfield(sMri,'NCS') && isfield(sMri.NCS,'R') && ~isempty(sMri.NCS.R) && isfield(sMri.NCS,'T') && ~isempty(sMri.NCS.T)
        % Remove the non-linear transformation, so that it forces using the linear one
        sMri.NCS.iy = [];
        sMri.NCS.y = [];
        P(iMissing,:) = cs_convert(sMri, src, dest, Porig(iMissing,:), isNanAllowed);
    % If NaN not allowed and no linear transformation: check for missing values
    elseif ~isNanAllowed
        error(['Some points are outside the definition of the non-linear MNI registration.' 10 'Please compute a linear MNI normalization to convert these points.']);
    end
end
