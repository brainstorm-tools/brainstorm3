function DipoleFile = generate_phantom_elekta(SubjectName)
% GENERATE_PHANTOM_ELEKTA Create the MRI and surfaces corresponding to the Elekta-Neuromag phantom.
% 
% PHANTOM DESCRIPTION:
%    - Plastic hemisphere containing 32 triangular current dipoles
%    - Radius of the sphere: 80mm
%    - Dipoles arranged at 65, 55, 45, and 35 mm from center
%    - Center of the sphere = (0,0,0)
%    - Four HPI coils at nominally (+/- 79.5,0,0) and (0, +/- 79.5,0) mm
%
% REFERENCE: 
%    Elekta Neuromag System Hardware User's Manual
%    Revision G, September 2005
%    NM20215A-G Date: 29.6.2005
%    Page 76, Table 2: Phantom Data

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
% Authors: Francois Tadel, 2016, for the CTF Phantom
% Adapted by John Mosher 2016 for the Neuromag Phantom


% ===== CREATE SUBJECT =====
% Subject name
if (nargin < 1) || isempty(SubjectName)
    SubjectName = 'Kojak';
end
% Get subject
[sSubject, iSubject] = bst_get('Subject', SubjectName);
if ~isempty(sSubject)
    error(['Subject "' SubjectName '" already exists.']);
end
% Create subject
[sSubject, iSubject] = db_add_subject(SubjectName, [], 0, 0);

% ===== PHANTOM DIMENSIONS =====
Rin  = 0.072;   % Phantom inner radius
Rout = 0.079;   % Phantom outer radius
Rfid = 0.0836;  % Phantom outer radius + 3mm (pedestal) + 1.6mm (half of coil width)

% ===== HEAD =====
% Make a generic half sphere
[Vertices, Faces] = tess_sphere(2000);
Vertices(Vertices(:,3) < 0,3) = 0;
Faces = convhull(Vertices(:,1),Vertices(:,2),Vertices(:,3));
Faces = Faces(:,[1 3 2]);
% Create head surface structure
sHead = db_template('surfacemat');
sHead.Vertices = Rout * Vertices;
sHead.Faces    = Faces;
sHead.Comment  = 'Phantom head (hemisphere)';
% Save file
SurfaceFile = bst_fullfile(bst_fileparts(file_fullpath(sSubject.FileName)), 'tess_head.mat');
save(SurfaceFile, '-struct', 'sHead');
db_add_surface(iSubject, SurfaceFile, sHead.Comment, 'Scalp');

% ===== CORTEX =====
sCortex = db_template('surfacemat');
sCortex.Vertices = Rin * Vertices;
sCortex.Faces    = Faces;
sCortex.Comment  = 'Phantom cortex';
% Save file
SurfaceFile = bst_fullfile(bst_fileparts(file_fullpath(sSubject.FileName)), 'tess_cortex.mat');
save(SurfaceFile, '-struct', 'sCortex');
db_add_surface(iSubject, SurfaceFile, sCortex.Comment, 'Cortex');

% ===== INNER SKULL =====
[skullVert, skullFaces] = tess_sphere(2000);
% Full sphere, for accurate computation of best spheres
sInner = db_template('surfacemat');
sInner.Vertices = (Rin + Rout) ./ 2 .* skullVert;
sInner.Faces    = skullFaces;
sInner.Comment  = 'Phantom inner skull';
% Save file
SurfaceFile = bst_fullfile(bst_fileparts(file_fullpath(sSubject.FileName)), 'tess_innerskull.mat');
save(SurfaceFile, '-struct', 'sInner');
db_add_surface(iSubject, SurfaceFile, sInner.Comment, 'InnerSkull');


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
% Add marks to indicate the fiducials
sMri.Cube((V(:,1) >  Rout) & (V(:,1) <  Rout + 0.005) & (abs(V(:,2)) < 0.005) & (V(:,3) <= 0.005)) = 2;
sMri.Cube((V(:,1) < -Rout) & (V(:,1) > -Rout - 0.005) & (abs(V(:,2)) < 0.005) & (V(:,3) <= 0.005)) = 2;
sMri.Cube((V(:,2) >  Rout) & (V(:,2) <  Rout + 0.005) & (abs(V(:,1)) < 0.005) & (V(:,3) <= 0.005)) = 2;
% Find points inside the outer sphere (head)
sMri.Cube(R <= Rout) = 2;
% Find points inside the inner sphere (cortex)
sMri.Cube(R <= Rin) = 1;
% Remove the lower half of the sphere
sMri.Cube(V(:,3) < 0) = 0;

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



% ===== TRUE LOCATIONS OF DIPOLES =====
% true_dipole_mat is in brainstorm template form
% true_loc is 3 x 32 dipole locations in the Brainstorm SCS
% true_orient is the 3 x 32 corresponding dipole orientations in the SCS

% Get the locations of the neuromag phantom dipoles
true_loc = PhantomDipoles();
% Convert to CTF Coordinate System
true_loc = true_loc([2 1 3],:);
true_loc(2,:) = -true_loc(2,:);
% Re-create the true orientations (tangential to location, in the plane of the location)
nDipoles = size(true_loc,2); 
true_orient = zeros(3,nDipoles);
for i = 1:nDipoles  
    nz = true_loc(:,i) ~= 0; % non-zero values
    tmp_o = null(true_loc(nz,i)'); % 2 D tangential
    true_orient(nz,i) = tmp_o;
end

% Create a Brainstorm dipole structure
DipoleMat = db_template('dipolemat');
DipoleMat.Comment     = 'True phantom dipoles';
DipoleMat.Time        = 0;
DipoleMat.DipoleNames = cell(1,nDipoles);
DipoleMat.Subset = 1;
for i = 1:nDipoles
    DipoleMat.DipoleNames{i} = sprintf('D%02.0f',i);
    DipoleMat.Dipole(i).Index     = i;
    DipoleMat.Dipole(i).Time      = 0;
    DipoleMat.Dipole(i).Origin    = [0 0 0];
    DipoleMat.Dipole(i).Loc       = true_loc(:,i);
    DipoleMat.Dipole(i).Amplitude = true_orient(:,i);
    DipoleMat.Dipole(i).Goodness  = 1;
    DipoleMat.Dipole(i).Errors    = 0;
    DipoleMat.Dipole(i).Khi2      = 0;
end

% Create a new condition
iStudy = db_add_condition(SubjectName, 'TrueDipoles');
% Save the dipoles files in it
DipoleFile = db_add(iStudy, DipoleMat);

end



%% ===== PHANTOM DIPOLES =====
%PHANTOM_DIPOLES Give locations of Kojak's dipole locations
% Loc is 3 x 32, for 32 dipoles, in meters.
% 
% Copied from Neuromag Excel file for accuracy.
% Note locations are for the newer Vectorview Phantom with a white cover,
% not the older exposed Phantom delivered in the 1990s.
function Loc = PhantomDipoles()
    Loc = [
        1	59.7	0	22.9	64
        2	48.6	0	23.5	54
        3	35.8	0	25.5	44
        4	24.8	0	23.1	34
        5	37.2	0	52	64
        6	27.5	0	46.4	54
        7	15.8	0	41	44
        8	7.9	0	33	34
        9	0	-59.7	22.9	64
        10	0	-48.6	23.5	54
        11	0	-35.8	25.5	44
        12	0	-24.8	23.1	34
        13	0	-37.2	52	64
        14	0	-27.5	46.4	54
        15	0	-15.8	41	44
        16	0	-7.9	33	34
        17	-46.1	0	44.4	64
        18	-41.9	0	34	54
        19	-38.3	0	21.6	44
        20	-31.5	0	12.7	34
        21	-13.9	0	62.4	64
        22	-16.2	0	51.5	54
        23	-20	0	39.1	44
        24	-19.3	0	27.9	34
        25	0	46.1	44.4	64
        26	0	41.9	34	54
        27	0	38.3	21.6	44
        28	0	31.5	12.7	34
        29	0	13.9	62.4	64
        30	0	16.2	51.5	54
        31	0	20	39.1	44
        32	0	19.3	27.9	34
        ];
    % Return just the locations, in meters
    Loc = Loc(:,2:4)' ./ 1000;  
end



