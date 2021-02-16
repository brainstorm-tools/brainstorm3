function [x, y, thetanew, lon] = mollweide_proj(lat, lon, radius)
% Calculate the x, y mollweide projection coordinates from spherical coordinates
%
% INPUT:
%       - lat (double vector): latitude coordinates of the points on the sphere
%       - lon (double vector): lonitude coordinates of the points on the sphere
%       - radius (double): the radius of the sphere
%
% OUTPUT:
%       - x (double matrix): the resulting x coordinates of the points projection in 2D
%       - y (double matrix): the resulting y coordinates of the points projection in 2D
%
%  Written by: Saskia van Heumen, September 2019
%  Written for: Internship at Centre of Pain Medicine, Erasmus MC, Rotterdam

% Back off of the +/- 90 degree points.  This allows
% the differentiation of longitudes at the poles of the transformed
% coordinate system.
epsilon = deg2rad(1e-6);
indx = find(abs(pi/2 - abs(lat)) <= epsilon);
if ~isempty(indx)
    lat(indx) = (pi/2 - epsilon) * sign(lat(indx));
end

% Set convergence paramters
convergence = 1E-10;

maxsteps = 100;
steps = 1;
thetanew = lat;
converged = 0;

% Itertively calculate the value for theta until convergence
while ~converged && (steps <= maxsteps)
    steps = steps + 1;
    thetaold = thetanew;
    deltheta = -(thetaold + sin(thetaold) -pi*sin(lat)) ./ (1 + cos(thetaold));
    if max(abs(deltheta(:))) <= convergence
        converged = 1;
    else
        thetanew = thetaold + deltheta;
    end
end

thetanew = thetanew / 2;

% Get the final x and y coordinates of the projected points
x = sqrt(8) * radius * lon .* cos(thetanew) / pi;
y = sqrt(2) * radius * sin(thetanew);


