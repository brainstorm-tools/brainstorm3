function [R,s,sensnum,th,rings] = sensor_spacing(shell,spacing,coverage);
% SENSOR_SPACING generate sites roughly evenly spaced about a hemisphere.
% function [R,s,sensnum,th,rings] = sensor_spacing(shell,spacing,coverage);
% Given a sphere of radius SHELL, and a desired separation between sites of
% distance SPACING, generate sites in matrix R with radial directions S over
% the sphere with coverage of COVERAGE radians measured from the positive
% z-axis (e.g., upper hemisphere has coverage of pi/2 radians.
% Optionally, COVERAGE may be 'half' or 'full' to indicate upperhemisphere
%  or full sphere coverage.
% 
% See sensor_ring for algorithm and explanation of SENSNUM.
% 
% Output args THETA and RINGS can be used to run SENSOR_RINGS for same
% result.

% Copyright (c) 1994 by John C. Mosher
% Los Alamos National Laboratory
% Group ESA-6, MS J580
% Los Alamos, NM 87545
% email: mosher@LANL.Gov
%
% Permission is granted to modify and re-distribute this 
% code in any manner as long as this notice is preserved. 
% All standard disclaimers apply. 

% uses: sensor_ring

% July 27, 1994 author
% March 2, 1995 JCM: added 'half' and 'full' options for coverage
% March 6, 1995 Reversed shell and spacing inputs for consistency

if(spacing > shell),		% test for change in input order error
  error(...
  'Your spacing is greater than the shell radius.  Inputs probably reversed');
end

th = asin(spacing/shell); 	% angular separation of rings

if(isstr(coverage)),		% we will calculate
  rings = coverage;		% valid are 'h' and 'f'
else
  rings = round(coverage/th) + 1; % includes top point as a ring
end

[R,s,sensnum,th,rings] = sensor_ring(shell,th,rings);
% returns the actual th and rings used


return
