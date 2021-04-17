function grid2mri_interp = grid_interp_mri_seeg(GridLoc, MRI)
% GRID_INTERP_MRI_SEEG: Interpolate a grid of points into a MRI.
%
% USAGE:  grid2mri_interp = grid_interp_mri(GridLoc, MRI)
%
% INPUT: 
%     - GridLoc     : [Nx3] matrix, 3D positions of the volume grid points
%     - MRI         : Brainstorm MRI structure
% OUTPUT:
%     - grid2mri_interp : Sparse matrix [nVoxels, nGridLoc]

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
% Authors: Francois Tadel, 2017-2020

% ===== CHECK MRI =====
% Check that MRI SCS is well defined
if ~isfield(MRI,'SCS') || ~isfield(MRI.SCS,'R') || ~isfield(MRI.SCS,'T') || isempty(MRI.SCS.R) || isempty(MRI.SCS.T)
    error(['MRI SCS (Subject Coordinate System) was not defined or subjectimage file is from another version of Brainstorm.' 10 10,...
           'Please define the SCS fiducials on this MRI.']);
end
cubeSize = size(MRI.Cube(:,:,:,1));
% Convert coordinates
GridLoc = cs_convert(MRI, 'scs', 'voxel', GridLoc);


% ===== CHECK VERTICES LOCATION =====
% Get all the vertices that are outside the MRI volume
iOutsideVert = find((GridLoc(:,1) >= cubeSize(1)) | (GridLoc(:,1) < 2) | ...
                    (GridLoc(:,2) >= cubeSize(2)) | (GridLoc(:,2) < 2) | ...
                    (GridLoc(:,3) >= cubeSize(3)) | (GridLoc(:,3) < 2));
% Compute percentage of vertices outside the MRI
percentOutside = length(iOutsideVert) / length(GridLoc);
% If more than 95% vertices are outside the MRI volume : exit with ar error message
if (percentOutside > .95)
    grid2mri_interp = [];
    java_dialog('error', ['SEEG/ECOG contacts are not registered with the MRI.' 10 'Please try to import the position of the contacts again.'], 'SEEG/ECOG -> MRI');
    return;
% If more than 40% vertices are outside the MRI volume : display warning message
elseif (percentOutside > .4)
    java_dialog('warning', 'SEEG/ECOG contacts do not seem to be registered with the MRI.', 'SEEG/ECOG -> MRI');
end


%% ===== COMPUTE INTERPOLATION =====
% Initialize interpolation matrix
N = size(GridLoc,1);
grid2mri_interp = sparse([],[],[], prod(cubeSize), N, N);
% Generate a 3x3 block
[Xs, Ys, Zs] = meshgrid([-1,0,1],[-1,0,1],[-1,0,1]);
% Add entry for each grid point
for i = 1:N
    % Find the closest voxel to the SEEG contact
    P = round(GridLoc(i,:));
    % Add the 3x3 block around the center
    X = min(max(1, P(1)+Xs(:)), cubeSize(1));
    Y = min(max(1, P(2)+Ys(:)), cubeSize(2));
    Z = min(max(1, P(3)+Zs(:)), cubeSize(3));
    indVol = sub2ind(cubeSize, X, Y, Z);
    % Set the voxel value to exactly the contact value
    grid2mri_interp(indVol,i) = 1;
end

