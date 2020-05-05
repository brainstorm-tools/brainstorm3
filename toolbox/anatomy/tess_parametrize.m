function paramVert = tess_parametrize(surf, Radius, Phi_step, Theta_step, Theta_lim, GRAPHICS)
% TESS_PARAMETRIZE:  Create a spheric parametrization of the input surface.
%
% USAGE:  paramVert = tess_parametrize(surf, Phi_scale, Theta_scale, Theta_lim)
%
% INPUT:
%    - surf       : Structure of the head surface (Faces,Vertices)
%    - Radius     : Radius of the projection
%    - Phi_step   : Step between two horizontal reference points
%    - Theta_step : Step between two vertical reference points
%    - Theta_lim  : Limit for Theta values (default = pi/2)
%
% OUTPUT:
%    - paramVert  : Coordinates (x,y,z) of the parametrized vertices

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
% Authors:  Louis Hovasse, 2009
%           Francois Tadel, 2010


%% ===== PARSE INPUTS =====
if (nargin < 6) || isempty(GRAPHICS)
    GRAPHICS = 0;
end
if (nargin < 6) || isempty(Theta_lim)
    Theta_lim = pi/2;
end
if (nargin < 4) || isempty(Theta_step)
    Theta_step = 0.18;
end
if (nargin < 3) || isempty(Phi_step)
    Phi_step = 0.18;
end
if (nargin < 2) || isempty(Radius)
    % 4 x avg distance between origin and points
    [az,elev,r] = cart2sph(surf.Vertices(:,1), surf.Vertices(:,2), surf.Vertices(:,3));
    Radius = 4*  mean(r);
end

%% ===== INTERPOLATE POINTS =====
% Define Theta and Phi values
Theta_list = Theta_step : Theta_step : Theta_lim;
Phi_list = 0 : Phi_step : 2*pi;
% Progress bar
nbLoops = length(Theta_list) * length(Phi_list);
bst_progress('start', 'Warp anatomy', 'Interpolation of points', 0, nbLoops);
% Initialize returned vertices list
paramVert = zeros(0, 3);
% Radius = 4 * dist(origin-nasion)
for Theta = Theta_list
    for Phi = Phi_list
        bst_progress('inc', 1);
        % Compute ray to be projected on surface (vector from (0,0,0))
        ray = [Radius * sin(Theta) * sin(Phi), ...
               Radius * sin(Theta) * cos(Phi), ...
               Radius * cos(Theta)];
        % Project ray on surface
        vRay = tess_ray_intersect(surf.Vertices, surf.Faces, [0,0,0], ray);
        if ~isempty(vRay)
            paramVert(end+1,:) = vRay;
        end
    end
end
% Close progress bar
bst_progress('stop');


%% ===== DISPLAY PARAMETRIZED SURFACE =====
% Display result if needed
if GRAPHICS
    figure();
    Faces = convhulln(paramVert, {'Qt', 'Pp'});
    trisurf(Faces, paramVert(:,1), paramVert(:,2), paramVert(:,3));
    axis equal vis3d
    rotate3d;
end




