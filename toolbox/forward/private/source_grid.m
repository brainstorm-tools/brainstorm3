function [L1,L2,L3,L4,L5,L6,L7,L8,L9] = ...
    source_grid(sensor_r,source_maxr,source_minr,Factor,STATS,VERBOSE)
% SOURCE_GRID: generate variable grid of possible source locations
% function [L1,L2,L3,L4,L5,L6,L7,L8,L9] = ...
%     source_grid(sensor_r,source_maxr,source_minr,Factor,STATS,VERBOSE);
% Given the scalar radius to the sensors sensor_r, 
%  the maximum scalar radius to the sources source_rmax, 
%  the minimum scalar radius to the sources source_rmin,
%  then generate possible dipole source locations L in the upper hemisphere.
% 
% Optional Factor is the fraction considered significant, default 0.1;
% Optional STATS flag means prepend stats onto the first rows of L
% Optional VERBOSE flag means describe the results.
% Optional [L1,L2,L3,...,L9] = source_grid(...
%  generate higher order expansion points.
%
% If(STATS), then in each location matrix, 
%  L(1) give the number of surfaces used, 
%  L(2,:) to L(L(1)+1,:) are statistics.  The first column of the statistics
%  rows gives the radial distance of the surface, the second column gives
%  the spacing used on that surface, and the third gives the number of
%  source points assigned on that surface.  Thus delete L(1:(L(1)+1),:) 
%  after viewing or extracting the statistics.


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
% Authors: John C. Mosher, 1995
% ----------------------------- Script History ---------------------------------
% JCM 2/27/95 cleanup from test version to production
% JCM 7/26/95 move first gridding surface down somewhat below the source_maxr
% ------------------------------------------------------------------------------

if(exist('Factor') ~= 1),	% user gave no Factor
  Factor = 0.1; 		% what Factor is considered insignificant
end
if(exist('STATS') ~= 1),	% user did not give
  STATS = 0; 			% do not prepend statistics
end
if(exist('VERBOSE') ~= 1),	% user did not give
  VERBOSE = 0; 			% silent running
end

for order = 1:nargout,		% foreach requested expansion order

  % Theory is that an uncovered source is min_d from the nearest sensor.  We
  % want to be b_offset below this source, such that b_offset + min_d provide
  % sufficient coverage.  The radius of coverage is such that two
  % intersecting circles intersect such that the radius by distance is still
  % equivalent to the Factor.  So radius of coverage = Factor *
  % (min_d+offset). Spacing = sqrt(2)*radius of coverage. Interlace
  % sensor_ring routine by 1/2 the spacing on every other surface.
  
  next_source_r = source_maxr; % initialize first source surface
  Rdip = [];			% source locations
  Rstat = [];			% statistics
  isurfaces = 0;		% number of surfaces used
  
  while(next_source_r > source_minr), 	% for appropriate spherical surfaces
    % minimum distance between source and sensor
    min_d = sensor_r - next_source_r; 
    % calculate radius of coverage of these expansions
    if(isurfaces == 0),		% first surface only
      b_offset = min_d/((1/Factor)*sqrt(2)-1);
    else
      b_offset = min_d/((1/Factor)-1);
    end
    radius_of_coverage = Factor*(min_d+b_offset);
    % set our expansion surface
    next_expan_r = next_source_r - b_offset;
    % keep sensible
    next_expan_r = max(next_expan_r,0);

    % create equally spaced expansion points on this surface,
    %  spaced sqrt(2)*radius_of_coverage apart
    isurfaces = isurfaces + 1;
    % spacing between sensors on this expansion surface
    spacing = sqrt(2)*radius_of_coverage; % (equal to the b_offset*2)
    if(spacing > (2*next_expan_r)),	% spacing is bigger than radius
      Rn = [0 0 next_expan_r];	% single sensor point
    else			% radius bigger than spacing
      theta_inc = acos(1 - 0.5*(spacing/next_expan_r)^2); % sensor increment

      if(rem(isurfaces,2)), 	% if an odd numbered surface
	Rn = sensor_ring(next_expan_r,theta_inc,'half');
	theta_inc_old = theta_inc; % drop into old bucke
      else			% interleave from previous theta_inc
	Rn = sensor_ring(next_expan_r,[theta_inc_old/2 theta_inc],'half');
      end
    
    end				% generate spacing on surface
    Rdip = [Rdip;Rn]; 		% add these source locations
    % what was the radius and spacing and how many
    Rstat = [Rstat; [next_expan_r spacing size(Rn,1)]]; % statistics

    % next surface of uncovered sources is at least b_offset below this
    %   surface.
    next_source_r = next_expan_r - b_offset;
    % then repeat for this source radius
  end

  if(STATS),			% user wants statistics as well
    eval(sprintf('L%.0f = [isurfaces 0 0;Rstat;Rdip];',order));
  else				% use doesn't want stats
    eval(sprintf('L%.0f = [Rdip];',order));
  end  
  
  if(VERBOSE),
    disp(' ')
    disp(sprintf('Order %.0f, %.0f surfaces, %.0f sources.',...
	order,isurfaces,size(Rdip,1)));
    disp(['Surface distances' sprintf(' %.1f',Rstat(:,1)*1000) ' (mm)'])
    disp(['Surface spacings ' sprintf(' %.1f',Rstat(:,2)*1000) ' (mm)'])
  end
  
end

if(STATS && VERBOSE),		% wanted statistics and verbosity
  disp(' ')
  disp(...
   'Remember to delete the first "surfaces + 1" statistical rows of each L')
end

return
