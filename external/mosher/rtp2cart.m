function cart = rtp2cart(rtp);
% RTP2CART Convert from rho, theta, phi to Cartesian
% function cart = rtp2cart(rtp);
% Convert each row of rho, theta, phi coordinates into Cart
% This format compatible with the 'PPI' defination of spherical coords.
% theta and phi are in positive degrees.
% See cart2rtp

% Copyright (c) 1995 by John C. Mosher
% Los Alamos National Laboratory
% Group ESA-6, MS J580
% Los Alamos, NM 87545
% email: mosher@LANL.Gov
%
% Permission is granted to modify and re-distribute this 
% code in any manner as long as this notice is preserved. 
% All standard disclaimers apply. 

% 3/1/95 author

[mrtp,nrtp] = size(rtp);

cart = zeros(mrtp,3);		% cartesian coords

% matlab's cart2sph returns azimuth, elevation, and range respectively
% However, we want radius, theta (90 - elev), and phi (az)
% Conversely, matlab's sph2cart wants az,el,r.

rtp(:,2) = 90 - rtp(:,2);	% wants elevation, not from z-axis
rtp(:,2:3) = rtp(:,2:3) * pi/180; % degrees to radians

[cart(:,1),cart(:,2),cart(:,3)] = sph2cart(rtp(:,3),rtp(:,2),rtp(:,1));

return
