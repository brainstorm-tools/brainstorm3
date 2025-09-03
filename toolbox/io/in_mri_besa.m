function sMri = in_mri_besa(MriFile)
% Read BESA MRI files

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
% Authors: Raymundo Cassani, 2024
%
% Based on BrainVoyager .vmr format file
% https://web.archive.org/web/20230926222047/https://support.brainvoyager.com/brainvoyager/automation-development/84-file-formats/343-developer-guide-2-6-the-format-of-vmr-files

fid     = fopen(MriFile);
header  = fread(fid, 5, 'uint16');      % [?, ?, dimX, dimY, dimZ] uint16
dims    = header(3:5);
nVoxels = prod(dims);
cube    = fread(fid, nVoxels, 'uint8'); % Voxels
fclose(fid);

% Data in .vmr by BrainVoyager (BV) is organized in three loops DimZ, DimY, DimX
% BV Z left -> right = X in Tal space
% BV Y top -> bottom = Z in Tal space
% BV X front -> back = Y in Tal space
cube = reshape(cube, dims');
% Re-order axes
% Step 1:    From BV   (RIP) to ACPC (RAS): Permute [1,3,2], Reverse Axes 2 and 3
% Step 2:    From ACPC (RAS) to BST  (ALS): Permute [2,1,3], Reverse Axis 2
% Steps 1+2: From BV   (RIP) to BST  (ALS): Permute [3,1,2], Reverse All Axes
cube = permute(cube, [3, 1, 2]);
cube = cube(end:-1:1, end:-1:1, end:-1:1);

% Brainstorm MRI structure
sMri = db_template('mrimat');
sMri.Cube    = cube;
sMri.Voxsize = [1, 1, 1];
sMri.Comment = 'MRI';
sMri.Header  = header;