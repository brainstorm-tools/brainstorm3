function generate_phantom_ctf(SubjectName)
% GENERATE_PHANTOM_CTF Create the MRI and surfaces corresponding to the CTF electric phantom.
% 
% PHANTOM DESCRIPTION:
%    - Plastic sphere containing saline water and a movable dipole.
%    - Inner diameter of the sphere: 130mm  ("Brain")
%    - Outer diamrter of the sphere: 140mm  ("Head", skull thickness: 5mm)
%    - Center of the sphere = (0,0,0)
%    - Distance from center of the sphere to center of the coils: 74.6mm (7mm radius + 3mm pedestal + 1.6mm coil half-width)

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
% Authors: Francois Tadel, 2016


% ===== CREATE SUBJECT =====
% Subject name
if (nargin < 1) || isempty(SubjectName)
    SubjectName = 'PhantomCTF';
end
% Get subject
[sSubject, iSubject] = bst_get('Subject', SubjectName);
if ~isempty(sSubject)
    error(['Subject "' SubjectName '" already exists.']);
end
% Create subject
[sSubject, iSubject] = db_add_subject(SubjectName, [], 0, 0);

% ===== PHANTOM DIMENSIONS =====
Rin  = 0.065;   % Phantom inner radius
Rout = 0.070;   % Phantom outer radius
Rfid = 0.0746;  % Phantom outer radius + 3mm (pedestal) + 1.6mm (half of coil width)

% ===== HEAD =====
sHead = db_template('surfacemat');
[sHead.Vertices, sHead.Faces] = tess_sphere(2000);
sHead.Vertices = Rout * sHead.Vertices;
sHead.Comment  = 'Phantom head (sphere)';
% Save file
SurfaceFile = bst_fullfile(bst_fileparts(file_fullpath(sSubject.FileName)), 'tess_head.mat');
save(SurfaceFile, '-struct', 'sHead');
db_add_surface(iSubject, SurfaceFile, sHead.Comment);

% ===== CORTEX =====
sCortex = db_template('surfacemat');
[sCortex.Vertices, sCortex.Faces] = tess_sphere(2000);
sCortex.Vertices = Rin * sCortex.Vertices;
sCortex.Comment  = 'Phantom cortex';
% Save file
SurfaceFile = bst_fullfile(bst_fileparts(file_fullpath(sSubject.FileName)), 'tess_cortex.mat');
save(SurfaceFile, '-struct', 'sCortex');
db_add_surface(iSubject, SurfaceFile, sCortex.Comment);

% ===== MRI =====
n = 256;
sMri = db_template('mrimat');
sMri.Comment = 'Phantom MRI';
sMri.Cube    = zeros(n,n,n);
sMri.Voxsize = [1 1 1];
% Create list of points
[Y,X,Z] = meshgrid(1:n, 1:n, 1:n);
Orig = n/2 + 0.5;
V = ([X(:), Y(:), Z(:)] - Orig) ./ 1000;
R = sqrt(sum(V.^2, 2));
% Find points in the junction between the top and bottom parts of the phantom
sMri.Cube((V(:,3) <= 0.005) & (V(:,3) >= -0.005) & (sqrt(V(:,1).^2 + V(:,2).^2) <= Rout + 0.010)) = 2;
% Add marks for the figucials
sMri.Cube((V(:,1) >  Rout + 0.003) & (abs(V(:,2)) < 0.010)) = 0;
sMri.Cube((V(:,1) < -Rout - 0.003) & (abs(V(:,2)) < 0.010)) = 0;
sMri.Cube((V(:,2) >  Rout + 0.003) & (abs(V(:,1)) < 0.010)) = 0;
% Find points inside the outer sphere (head)
sMri.Cube(R <= Rout) = 2;
% Find points inside the inner sphere (cortex)
sMri.Cube(R <= Rin) = 1;
% Dilate, to compensate for the shrinking when the head surface is generated
edgeMask = (sMri.Cube > 0);
edgeMask = mri_dilate(edgeMask) & ~edgeMask;
sMri.Cube(edgeMask) = 0.2;
% MRI Fiducials
NAS = [ 0     Rfid 0];
LPA = [-Rfid  0    0];
RPA = [ Rfid  0    0];
sMri.SCS.NAS  = NAS * 1000 + Orig;
sMri.SCS.LPA  = LPA * 1000 + Orig;
sMri.SCS.RPA  = RPA * 1000 + Orig;
% Compute transformation
scsTransf = cs_compute(sMri, 'scs');
sMri.SCS.R      = scsTransf.R;
sMri.SCS.T      = scsTransf.T;
sMri.SCS.Origin = scsTransf.Origin;
% Place AC/PC/IH points
sMri.NCS.AC = [0,  10,  0] + Orig;
sMri.NCS.PC = [0, -10,  0] + Orig;
sMri.NCS.IH = [0,   0, 40] + Orig;
% Save volume
db_add(iSubject, sMri);

% ===== GENERATE HEAD SURFACE =====
% Create surface
[HeadFile, iSurface] = tess_isohead(iSubject, 10000, 0, 0, 'Phantom head (mask)');







