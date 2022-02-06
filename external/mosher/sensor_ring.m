function [R,s,sensnum,th,rings] = sensor_ring(r,th,rings,version)
% SENSOR_RING: Generate rings of sensors about a sphere roughly uniformly spaced.
% function [R,s,sensnum,th,rings] = sensor_ring(r,th,rings,version);
% For radius 'r', angle separation 'theta' (radians), and 
%  'rings' number  of sensor rings:
% Generate R (mx3) location and s (mx3) orientation of 
%  radially oriented sensors.
% If rings is given as a string, 'h' or 'f', then theta is adjusted to give
%   exactly half or full head coverage. Adjusted values are returned in 
%   the output as th and rings.
%
% The first sensor is on the z-axis, at [0 0 r];  Each ring is incremented
%  theta radians down from the z-axis, and the first sensor of each ring is
%  positioned on the x-axis (in spherical coords, the first sensor is at
%  phi=0). 
% The desired sensor spacing is set by the distance from sensor 1 to 2.
% Sensnum is a vector of the number of sensors per ring.  The sensors are
%  spaced about each ring such that the distance between sensors in a given
%  ring are as close as possible to the desired spacing.
% Optionally: if theta has two components, then the first component is the
%   initial offset from the z-axis for the first ring, and the second
%   component is increment between rings. (Option has no effect for 'old'
%   mode, but the second component will be properly interpreted as the
%   increment.) 
%
% Example:
%   [R,s,sensnum] = sensor_ring(0.12,12*(pi/180),4); produces a simulated
%   version of the BTi configuration, which has four rings of sensors,
%   including the center ring of 1 sensor, then 6, then 12, then 18, for a
%   total of 37 sensors.  Each ring is separated from the adjacent ring by
%   about 12 degrees, and the entire array sits on a virtual sphere of radius
%   12 cm (0.12 meters).
%
% OTHER ANGLES AND MORE RINGS MAY GENERATE DIFFERENT PATTERNS THAN THE
%  OLD SENSOR_RING PROGRAM.  The old routine may be activated by the 
%  string 'old' in version, which builds rings of 1, 6, 12, 18, 24, ...
%  Default is the new routine, which builds each ring with a suitable number
%  of sensors to maintain the desired sensor spacing.  For the BTi pattern
%  example above, there is virtually no difference between old and new modes.
%
% See also CONN_DIST for the distance between sensor points, 
%  and SENSOR_SPACING for a convenient method of calling this routine.

% @=============================================================================
% This software is part of The Brainstorm Toolbox
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2010 Brainstorm by the University of Southern California
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPL
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
% Authors: John C. Mosher, ~1992
% ----------------------------- Script History ---------------------------------
% JCM  8-Jun-1994  Modified from old sensor_ring 6/8/94 to give more uniform
%                  spacing over hemisphere.
% JCM 28-Jun-1994  Added two element theta option
% JCM 18-Jan-1995  Reversed ordering around each ring to correspond to HRL numbering scheme.
% JCM  2-Mar-1995  Adjusted 'new' routine to interleave subsequent rings
%                  and therefore make the true distances somewhat more comparable.
%                  Also added 'new' rings option 'half' and 'full', for upperhemisphere
%                  coverage and full sphere coverage.
% JCM 31-Aug-1995  Bug fix with 'full' coverage, was only giving 'half'.
% JCM 19-May-2004 Comments Cleaning
% ------------------------------------------------------------------------------

if (nargin < 4)  	% user gave no version
  version = 'new';	% default is not old
end

if(strcmpi(version,'old')), % user wants old version
  OLD_MODE = 1;
else
  OLD_MODE = 0;			% default mode
end

th_initial = 0;			% initial angle from z-axis
if(length(th)==2),		% user using option
  th_initial = th(1);
  th = th(2);
end

% design first for unit length, then scale to radius

if(OLD_MODE),
  
  R(1,:) = [0 0 1];		% first sensor, "ring" one
  degrees = 180/pi;		% conversion

  deg = 60;			% phi increment in second ring of six sensors

  for j = 2:rings
    phi = -(0:deg:359)' ./ degrees;% phi index this ring, 1/18/95 added '-'sign
    thj = (j-1)*th;		% next theta increment

    % append next ring of sensors
    R = [R;...
	[cos(phi)*sin(thj) ...
	sin(phi)*sin(thj) ones(length(phi),1)*cos(thj)]];
    deg = 60/j;			% phi increment next ring of sensors
  end
  
  sensnum = [1, (1:(rings-1)) * 6]; % old pattern of rings

else
  
  if(ischar(rings)),		% user wants us to calculate parameters
    % first figure for half hemisphere coverage, but not exceeding.
    tmp1 = round((pi/2 - th_initial)/th); % number of rings, except top
    th = ((pi/2)-th_initial)/tmp1;		% new value
    nrings = tmp1;		% number of rings for half coverage
    if(th_initial==0),		% need a top single point also
      nrings = nrings + 1;
    end
    if(rings(1)=='f'), 		% want full coverage
      nrings = tmp1 + nrings; 	% including bottom set ring of 1 sensor
    end
    % now map number of rings over the string rings
    rings = nrings;
  end				% if rings given as string
      
  [x1,y1,z1] = sph2cart(0,pi/2 - th_initial,1); % first sensor, first ring
  [x2,y2,z2] = sph2cart(0,pi/2 - th_initial - th,1); %first sensor, second ring
  d = norm([x2,y2,z2] - [x1,y1,z1]); % distance between, desired distance

  sensnum = zeros(1,rings);	% number of sensors per ring
  R = [];
  for j = 1:rings,
    thj = (j-1)*th + th_initial;% theta this ring
    circum = 2*pi*sin(thj);	% circumference of circle
    sens = max(round(circum/d),1);% number of sensors this ring, minimum 1
    sensnum(j) = sens;
    ph = -(0:(sens-1))' / sens*2*pi;	% phi increments this ring,
    % 1/18/95 added '-' sign to ph
    % 3/2/95 added ph/2 factor for odd numbered rings
    if(rem(j,2) && (sens > 1)),		% odd ring of more than one sensor
      ph = ph + ph(2)/2;	% bump half an increment
    end

    % append next ring of sensors
    R = [R;...
	[cos(ph)*sin(thj) ...
	sin(ph)*sin(thj) ones(length(ph),1)*cos(thj)]];
  end

end

s = R;				% radial orientation of unit length

R = R*r;			% scale to radius

return
