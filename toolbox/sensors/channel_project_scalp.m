function ChanLoc = channel_project_scalp(Vertices, ChanLoc)
% CHANNEL_ALIGN_MANUAL: Align manually an electrodes net on the scalp surface of the subject.
% 
% INPUT:
%     - Vertices : [Mx3] positions of the scalp vertices
%     - ChanLoc  : [Nx3] positions of the EEG electrodes

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
% Authors: Francois Tadel, 2014

% Center the surface on its center of mass
center = mean(Vertices, 1);
Vertices = bst_bsxfun(@minus, Vertices, center);
% Parametrize the surface
p   = .2;
th  = -pi-p   : 0.01 : pi+p;
phi = -pi/2-p : 0.01 : pi/2+p;
rVertices = tess_parametrize(Vertices, th, phi);

% Process each sensor
for iChan = 1:size(ChanLoc,1)
    % Get the closest surface from the point
    c = ChanLoc(iChan,:);
    % Center electrode
    c = c - center;
    % Convert in spherical coordinates
    [c_th,c_phi,c_r] = cart2sph(c(1), c(2), c(3));
    % Interpolate
    c_r = interp2(th, phi, rVertices, c_th, c_phi);
    % Project back in cartesian coordinates
    [c(1),c(2),c(3)] = sph2cart(c_th, c_phi, c_r);
    % Restore initial origin
    c = c + center;
    ChanLoc(iChan,:) = c;
end


