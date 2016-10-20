function [x,y,z,R,geo,tri_num] = tesselate(shell,spacing,coverage,R,sensnum);
% TESSELATE tesselate based on the sensor_ring program
% function [x,y,z,R,geo,tri_num] = tesselate(shell,spacing,coverage);
% or
% function [x,y,z,R,geo,tri_num] = tesselate([],[],[],R,sensnum);
% Input: shell is the radius at which to tesselate
%        spacing is the nominal length of one side of the triangle
%        coverage is the theta angle (radians), measured from the
%        z-axis, over which to generate the triangles
%        Coverage may also be 'half' or 'full' for pi/2 or pi coverage.
% Optionally, enter garbage for the first three, then enter your sensor
%  locations and the number of sensors per ring.  This assumes that all
%  locations in R are on a sphere, in circular rings similar to what
%  sensor_ring generates, and sensnum might be for example [1 6 12 18] for
%  the BTi 37 channel system.
% Output: x,y,z are suitable for fill3(x,y,z,z).  All are 3 x # triangles
%  Each column of x represents the x-coordinates of the ith triangle,
%  similarly for y and z.
%  Optionally, use instead:
%  R: is the coordinates of the vertices, one xyz location per row.
%  geo: is the geometry matrix, 3 x # triangles.  Each column has
%   the integer numbers representing the index from R that forms the
%   triangle
%   Ordering from vertice 1 to 2 to 3 is such that the vector from 1 to
%   2  cross the vector from 1 to 3 is "outward" from the sphere.
%  tri_num: the number of triangles in each ring, such that 
%   sum(tri_num) is the total number of triangles.

% Copyright (c) 1994 by John C. Mosher
% Los Alamos National Laboratory
% Group ESA-MT, MS J580
% Los Alamos, NM 87545
% email: mosher@LANL.Gov
%
% Permission is granted to modify and re-distribute this code in any manner
%  as long as this notice is preserved.  All standard disclaimers apply.

% uses: sensor_spacing, sensor_ring

% 3/1/95 author
% 3/24/95 pulled xyz out of the loop, added reording for outward normals
% 3/5/96 added option for user to give R and sensnum

if(exist('sensnum')~= 1),	% user did not give
  % get vertices
  [R,s,sensnum,theta,no_rings] = sensor_spacing(shell,spacing,coverage);
  clear s theta 		% don't need
else 				% user gave R and sensnum
  sensnum = sensnum(:)';	% make sure row
  no_rings = length(sensnum);
end

% R is the vertices, 
% sensnum is vector the number of sensors per ring
% theta is the theta increment
% no_rings is the number of rings (length of sensnum)

% Number of vertices on a closed surface is half the triangles + 2
% Our surface might be possibly open (based on coverage), so I'll
%  just shoot for overkill and reserve a space of three times
%  the vertices, then trim at the end.  Also need three rows per triangle

%xyz = zeros(9*size(R,1),3);	% reserved space for the triangles
geo = zeros(3,3*size(R,1));	% the indices of the triangles
xyzi = 0; 			% indexer to xyz

csensnum = cumsum(sensnum);	% cumulative indexer
csensnum = [0 csensnum];	% to align first ring
tri_num = zeros(1,length(sensnum)-1); % number of triangles per ring

for i = 1:(no_rings-1),		% foreach ring of vertices
  pndx = [1:sensnum(i)] + csensnum(i); 	% index of previous ring
  nndx = [1:sensnum(i+1)] + csensnum(i+1); % index to next ring
  lp = length(pndx); 	% length of previous ring
  ln = length(nndx); 	% length of next ring
  if(lp > 1),			% all but the single point ring
    pndx = [pndx pndx(1)]; % wrap around the ring
    lp = lp + 1;
  end
  if(ln > 1),			% all but the single point ring
    nndx = [nndx nndx(1)]; % wrap around the ring
    ln = ln + 1;
  end
  previ = 1; 			% indexer to previous ring
  nexti = 1;			% indexer to next ring
  
  while((previ < lp) | (nexti < ln)), % while we walk around the ring
    
    if((previ + 1) <= lp),	% we're not all the way around yet
      test_prev = R(pndx(previ+1),:); % next test vertice for previous ring
    else
      test_prev = Inf;		% no more left on this ring
    end

    if((nexti + 1) <= ln), 	% we're not all the way around yet
      test_next = R(nndx(nexti+1),:); % next test vertice for next ring
    else
      test_next = Inf;		% no more left on this ring
    end
    
    % Of the quadrilateral (possibly triangle) prev prev+1 next+1 next
    %  which is the shorter diagonal
    if(norm(R(pndx(previ),:)-test_next) < ...
	  norm(R(nndx(nexti),:)-test_prev)),
      % diagonal from top left to bottom right is winner
%      xyz([1:3]+xyzi,:) = R([pndx(previ) nndx([nexti nexti+1])],:); % vertices
      xyzi = xyzi + 3;		% increment
      geo(:,xyzi/3) = [pndx(previ) nndx([nexti nexti+1])]'; % indices
      nexti = nexti + 1;	% increment
    else
      % winner is bottom left to top right
      % vertices:
%      xyz([1:3]+xyzi,:) = R([pndx(previ) nndx(nexti) pndx(previ+1)],:); 
      xyzi = xyzi + 3;		% increment
      geo(:,xyzi/3) = [pndx(previ) nndx(nexti) pndx(previ+1)]'; % indices
      previ = previ + 1;	% increment
    end				% which diagonal one
    tri_num(i) = tri_num(i) + 1; % number of triangles this ring
  end				% while we are on these rings
    
end				% for all rings

% xyzi represents three times number of triangles
% xyz = xyz(1:xyzi,:);		% trim off the blanks, JCM, pulled out of loop
if(xyzi > 0),			% then we have triangles to consider
  
  geo = geo(:,1:xyzi/3); 	% trim off the blanks
  geo = geo([1 3 2],:); 	% reverse ordering for outward direction


  %x = reshape(xyz(:,1),3,xyzi/3); % the x vertices, JCM, form directly below
  %y = reshape(xyz(:,2),3,xyzi/3); % the y vertices
  %z = reshape(xyz(:,3),3,xyzi/3); % the z vertices
  x = reshape(R(geo(:),1),3,xyzi/3); % the x vertices
  y = reshape(R(geo(:),2),3,xyzi/3); % the x vertices
  z = reshape(R(geo(:),3),3,xyzi/3); % the x vertices
end

while(0)			% other ideas on picture
%%%%%%%%%%%%%
h = fill3(x,y,z,z); 		% return handles of patches
for i = 1:length(h),
  set(h(i),'edgecolor','interp') % no lines
  set(h(i),'facecolor','none')	% mesh grid
end
lightpoint = [-.5 -.5 .25]';		% light source point
C1 = lightpoint*ones(1,size(x,2)) - [x(1,:);y(1,:);z(1,:)];
C1 = colnorm(C1);
C2 = lightpoint*ones(1,size(x,2)) - [x(2,:);y(2,:);z(2,:)];
C2 = colnorm(C2);
C3 = lightpoint*ones(1,size(x,2)) - [x(3,:);y(3,:);z(3,:)];
C3 = colnorm(C3);
C = [C1;C2;C3];			% distances to vertices
%Cl = 1../C; 			% lighting inverse to distance
Cl = 1../(C.*C); 		% inverse distance squared
h = fill3(x,y,z,Cl,'face','none','edge','interp');
%%%%%%%%%%%%%
end

return
