function [vert, faces] = tess_cylinder(nvert, percentZ, scale, orient, isDouble, DISPLAY)
% TESS_CYLINDER: Create a cylinder with a unit radius.
%
% INPUTS:
%    - nvert    : Number of points in the output cylinder (pair values only)
%    - percentZ : [0,1] Amount of the cylinder that is above the Z=0
%    - scale    : [1x3] Dimension of the cylinder in each direction, before applying orientation (default: [1 1 1])
%    - orient   : [1x3] Orientation vector of the cylinder (default: [0 0 1])
%    - isDouble : Double the layers of points for the circle on each side (to patch the graphic bugs with Matlab < 2014b)

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
% Authors: Francois Tadel, 2014

% Parse inputs
if (nargin < 6) || isempty(DISPLAY)
    DISPLAY = 0;
end
if (nargin < 5) || isempty(isDouble)
    isDouble = 0;
end
if (nargin < 4) || isempty(orient)
    orient = [];
end
if (nargin < 3) || isempty(scale)
    scale = [];
end
if (nargin < 2) || isempty(percentZ)
    percentZ = 0.8;
end
if (nargin < 1) || isempty(nvert)
    nvert = 26;
elseif (mod(nvert, 2) ~= 0)
    error('Number of vertices must be pair.');
end

% Simple layer
if isDouble
    % Define the external circle
    Ncirc1 = round((nvert-2) / 4);
    theta1 = linspace(0, 2*pi, Ncirc1+1);
    theta1 = theta1(1:end-1);
    [X1,Y1] = pol2cart(theta1, ones(size(theta1)));
    % Define the inner circle
    Ncirc2 = round((nvert-2) / 4);
    theta2 = linspace(0, 2*pi, Ncirc2+1);
    theta2 = theta2(1:end-1) + (theta2(2)-theta2(1))/2;
    [X2,Y2] = pol2cart(theta2, 0.98 * ones(size(theta2)));
    % List of vertices for the cylinder
    Zeps = 0.000001;
    vert = [    0,     0, (percentZ-1) - 2*Zeps; 
                0,     0,     percentZ + 2*Zeps; 
            X1(:), Y1(:), (percentZ-1) * ones(Ncirc1,1);
            X2(:), Y2(:), (percentZ-1) * ones(Ncirc2,1) - Zeps;
            X1(:), Y1(:),     percentZ * ones(Ncirc1,1);
            X2(:), Y2(:),     percentZ * ones(Ncirc2,1) + Zeps];
% Simple layer
else
    % Define a circle
    Ncirc = round((nvert-2) / 2);
    theta = linspace(0, 2*pi, Ncirc+1);
    theta = theta(1:end-1);
    [X,Y] = pol2cart(theta, ones(size(theta)));
    % List of vertices for the cylinder
    Zeps = 0.000001;
    vert = [   0,    0, (percentZ-1) - Zeps; 
            X(:), Y(:), (percentZ-1) * ones(Ncirc,1);
               0,    0,     percentZ + Zeps; 
            X(:), Y(:),     percentZ * ones(Ncirc,1)];
end
% Tesselate final cylinder
faces = convhulln(vert);

% Apply scale factor
if ~isempty(scale) && ~isequal(scale, [1,1,1])
    vert = bst_bsxfun(@times, vert, scale);
end
% Apply orientation
if ~isempty(orient) && ~isequal(orient, [0,0,1])
    v1 = [0;0;1];
    v2 = orient(:);
    % Rotation matrix (Rodrigues formula)
    angle = acos(v1'*v2);
    axis  = cross(v1,v2) / norm(cross(v1,v2));
    axis_skewed = [ 0 -axis(3) axis(2) ; axis(3) 0 -axis(1) ; -axis(2) axis(1) 0];
    R = eye(3) + sin(angle)*axis_skewed + (1-cos(angle))*axis_skewed*axis_skewed;
    % Apply rotation to the vertices of the electrode
    vert = vert * R';
end

% Plot surface
if DISPLAY
    % Plot surface
    [hFig, iDS, iFig, hPatch] = view_surface_matrix(vert, faces, 0, [1 0 0]);
    % Configure color and lighting
    VertexRGB   = repmat([.9,.9,0], size(vert,1), 1);
    VertexAlpha = ones(size(vert,1), 1);
    
    set(hPatch, ...
        'FaceColor',           'interp', ...
        'FaceVertexCData',     VertexRGB, ...
        'FaceAlpha',           'interp', ...
        'FaceVertexAlphaData', VertexAlpha, ...
        'AlphaDataMapping',    'none', ...
        'EdgeColor',           'none', ... [1 0 0], ...
        'LineWidth',           1, ...
        'BackfaceLighting',    'unlit', ...
        'AmbientStrength',     0.5, ...
        'DiffuseStrength',     0.6, ...
        'SpecularStrength',    0, ...
        'SpecularExponent',    1, ...
        'SpecularColorReflectance', 0, ...
        'FaceLighting',        'gouraud', ...  'flat', ...
        'EdgeLighting',        'gouraud');
end




