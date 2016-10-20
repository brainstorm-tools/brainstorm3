function rtp = cart2rtp(cart);
% function rtp = cart2rtp(cart);
% Convert each row of Cartesian coordinates into rho, theta, phi
% This format compatible with the 'PPI' defination of spherical coords.
% theta and phi are returned in positive degrees.

% Copyright (c) 1994 by John C. Mosher
% Los Alamos National Laboratory
% Group ESA-6, MS J580
% Los Alamos, NM 87545
% email: mosher@LANL.Gov
%
% Permission is granted to modify and re-distribute this 
% code in any manner as long as this notice is preserved. 
% All standard disclaimers apply. 

% 12/3/93 author

[mcart,ncart] = size(cart);

rtp = zeros(mcart,3);		% spherical coords

% matlab's cart2sph returns azimuth, elevation, and range respectively
% However, ppi wants radius, theta (90 - elev), and phi (az)

[rtp(:,3),rtp(:,2),rtp(:,1)] = cart2sph(cart(:,1),cart(:,2),cart(:,3));

rtp(:,2:3) = rtp(:,2:3) * 180/pi; % ppi_select uses degrees

rtp(:,2) = 90 - rtp(:,2);	% also uses angle from z-axis, not elevation

rtp(:,3) = rem(rtp(:,3)+360,360); % ppi_select uses positive angles

