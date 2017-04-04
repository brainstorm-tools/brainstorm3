function P = cs_convert(sMri, src, dest, P)
% CS_CONVERT: Convert 3D points between coordinates systems.
%
% INPUT: 
%     - sMri  : Brainstorm MRI structure
%     - src   : Current coordinate system {'voxel','mri','scs','mni'}
%     - dest  : Target coordinate system {'voxel','mri','scs','mni'}
%     - P     : a Nx3 matrix of point coordinates to convert
%
% DESCRIPTION:   http://neuroimage.usc.edu/brainstorm/CoordinateSystems
%     - voxel : X=left>right,  Y=posterior>anterior,   Z=bottom>top
%               Coordinate of the center of the first voxel at the bottom-left-posterior of the MRI volume: (1,1,1)
%     - mri   : Same as 'voxel' but in millimeters instead of voxels:  mriXYZ = voxelXYZ * Voxsize
%     - scs   : Based on: Nasion, left pre-auricular point (LPA), and right pre-auricular point (RPA).
%               Origin: Midway on the line joining LPA and RPA
%               Axis X: From the origin towards the Nasion (exactly through)
%               Axis Y: From the origin towards LPA in the plane defined by (NAS,LPA,RPA), and orthogonal to X axis
%               Axiz Z: From the origin towards the top of the head 
%     - mni   : MNI coordinates based on SPM affine registration

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2015

% Check matrices orientation
if (size(P,2) ~= 3) && (size(P,1) == 3)
    P = P';
elseif (size(P,2) ~= 3)
    error('P must have 3 columns (X,Y,Z).');
end
% If the coordinate system didn't change
if strcmpi(src, dest)
    return;
end
% Transform to homogeneous coordinates
P = [P'; ones(1,size(P,1))];


% ===== CONVERT SRC => MRI =====
% Evaluate the transformation to apply
Factor1 = [];
RT1 = [];
switch lower(src)
    case 'voxel'
        Factor1 = [sMri.Voxsize(:) ./ 1000; 1];
    case 'mri'
        % Nothing to do
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
    otherwise
        error(['Invalid coordinate system: ' src]);
end
% Apply factor
if ~isempty(Factor1)
    P = bst_bsxfun(@times, P, Factor1);
end
% Apply rotation-translation
if ~isempty(RT1)
    P = RT1 * P;
end


% ===== CONVERT MRI => DEST =====
% Evaluate the transformation to apply
Factor2 = [];
RT2 = [];
switch lower(dest)
    case 'voxel'
        Factor2 = [1000 ./ sMri.Voxsize(:); 1];
    case 'mri'
        % Nothing to do
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
    otherwise
        error(['Invalid coordinate system: ' dest]);
end
% Apply factor
if ~isempty(Factor2)
    P = bst_bsxfun(@times, P, Factor2);
end
% Apply rotation-translation
if ~isempty(RT2)
    P = RT2 * P;
end

% Remove the last coordinate and transpose the matrix back
P = P(1:3,:)';


