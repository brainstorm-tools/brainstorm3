function newTessFile = tess_blend(srcTessFile, destTessFile, phiLim)
% TESS_BLEND: Project the source surface on the destination surface for phi>phiLim

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
% Authors: Francois Tadel, 2013

% Load surfaces
sSrc  = in_tess_bst(srcTessFile);
sDest = in_tess_bst(destTessFile);

% TODO: SURFACE SHOULD BE CENTER BEFORE BEING PARAMETRIZED!

% Convert to spherical coordinates
[s_th,s_phi,s_r] = cart2sph(sSrc.Vertices(:,1),  sSrc.Vertices(:,2),  sSrc.Vertices(:,3));
[d_th,d_phi,d_r] = cart2sph(sDest.Vertices(:,1), sDest.Vertices(:,2), sDest.Vertices(:,3));

% Parametrize the destination surface
p   = .2;
th  = -pi-p   : 0.01 : pi+p;
phi = -pi/2-p : 0.01 : pi/2+p;
r   = tess_parametrize(sDest.Vertices, th, phi);

% Interpolate radius
proj_s_r = interp2(th, phi, r, s_th, s_phi);

% Blending function
blend = zeros(size(s_r));
ramp = 0.15;
blend(s_phi > phiLim - ramp) = 0.5/ramp * s_phi(s_phi > phiLim - ramp) + 0.5;
blend(s_phi > phiLim + ramp) = 1;
% Apply blending between original and projected surface
proj_s_r = blend.*proj_s_r + (1-blend).*s_r;

% Convert back to cartesian coordinates
[projVertices(:,1), projVertices(:,2), projVertices(:,3)]  = sph2cart(s_th, s_phi, proj_s_r);

% Convert back to cartesian coordinates
sNew = db_template('surfacemat');
sNew.Comment  = [sSrc.Comment ' | blend'];
sNew.Vertices = projVertices;
sNew.Faces    = sSrc.Faces;
sNew.Atlas    = sSrc.Atlas;
sNew.iAtlas   = sSrc.iAtlas;
if isfield(sSrc, 'History') && ~isempty(sSrc.History)
    sNew.History  = sSrc.History;
end
if isfield(sSrc, 'Reg') && ~isempty(sSrc.Reg)
    sNew.Reg = sSrc.Reg;
end
% Add history entry
sNew = bst_history('add', sNew, 'blend', 'Blended with another surface file.');

% Save new file
newTessFile = file_unique(strrep(file_fullpath(srcTessFile), '.mat', '_blend.mat'));
bst_save(newTessFile, sNew, 'v7');
% Get subject
[sSubject, iSubject] = bst_get('SurfaceFile', srcTessFile);
% Add to database
db_add_surface(iSubject, newTessFile, sNew.Comment);


