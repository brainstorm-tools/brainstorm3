function [fv,new_org,a,rtrue,rest,shell] = ...
   hsdig2fv(hsdig,order,spacing,ANG_WIDTH,verbose)
% HSDIG2FV Tesselate based on arbitrary 3D head-shaped data
% function [fv,new_org,a,rtrue,rest,shell] = ...
%    hsdig2fv(hsdig,order,spacing,ANG_WIDTH,verbose)
% Given hsdig, head shaped digitized data, one three-d Cartesian point per
%              row of hsdig, in nominal head-coordinate system
%              (x-axis through nasion, y-axis near left prearic, z-axis up);
%       order, the harmonic order to fit (0 = sphere);
%       spacing, the nominal length of one side of the triangles;
%       ANG_WIDTH is angular radian width to find lower edge of the
%         head-shaped data (try 20*pi/180 for dense data, larger for more
%         sparse data). hsdig is assumed to be somewhat uniformly sampled
%         along the lower edge of the head shape.
% (optional) verbose, to tell you what's happening and plot a picture.
% if spacing is given as fv, then use it instead of making new tesselation
% (i.e. create one surface, then use it with another)
% Output:
% fv is faces vertices structure of Matlab

%  rtrue is the distance from the translated origin NEW_ORG to the given
%   data in hsdig.
%  rest is the estimated distance to the same data.  plot([rtrue rest])
%   gives an idea of the quality of the fit.
%  a is the coefficients used to fit the spherical harmonics
%  new_org is the new origin, found as the best fitting sphere.

% Copyright (c) 1995-2009 by John C. Mosher
%
% Permission is granted to modify and re-distribute this code in any manner
%  as long as this notice is preserved.  All standard disclaimers apply.

% uses: tesselate (sensor_spacing, sensor_ring), sphererr, windfind,
%       bar_scale

% March 2, 1995 author
% 4/6/95 JCM adjusted so that all vertices must be above the helmet line
% 9/16/09 JCM made it FV form, just upper triangles

% Future upgrade: fit the center of expansion as well for the full order.
%  Here, we simply fit a zeroth order (sphere).

% uses old cart2rtp, a spherical coordinate convention from polhemus data.
% Should use standard cart2sph of matlab


if(exist('verbose','var') ~= 1),
   verbose = 0;			% silent running
end

%% find the best fitting sphere
% We use this center to fit the spherical harmonics

new_org = fminsearch('sphererr',[0;0;0],[],hsdig); % returns best center
[err,shell] = sphererr(new_org,hsdig); % get final fit error and radius
new_org = new_org'; % row convention

if(verbose),
   disp(['Best fitting sphere origin:' sprintf(' %.2f',new_org)])
   disp(sprintf('Best fitting sphere radius: %.2f',shell));
   disp(sprintf('Arbitrary error in fitting: %f',err));
end

hsdig = hsdig - new_org(ones(size(hsdig,1),1),:); % subtract

rtp = cart2rtp(hsdig); 		% convert to spherical

rtp(:,2:3) = rtp(:,2:3)*pi/180;	% degrees to radian

%% Create the tesselated sphere
if isstruct(spacing)
   % we gave a predetermined list of Vertices, just use that
   Vertices = spacing.vertices;
   Faces = spacing.faces'; % note transpose
else
   % triangles on a sphere, upto max theta
   % TODO: Why do I need single on shell? Aug 2009
   [xs,ys,zs,Vertices,Faces] = tesselate(single(shell),spacing,'full'); % get full coverage
end


rtp_sphere = cart2rtp(Vertices); % in spherical
rtp_sphere(:,2:3) = rtp_sphere(:,2:3)*pi/180;	% degrees to radian


ndx = 0;
for l = 0:order,
   for m = -l:l,
      ndx = ndx + 1;
      PUp(:,ndx) = spherharm(rtp_sphere(:,2),rtp_sphere(:,3),l,m); % the upper region
      Prtp(:,ndx) = spherharm(rtp(:,2),rtp(:,3),l,m); % the original data
   end
end

rtrue = rtp(:,1);		% true distances

a = Prtp\rtrue; 		% fit of distances

rest = abs(Prtp*a); 		% estimated distances

rUp = abs(PUp*a); 		% refit to interpolations

% all of the interpolated points
VerticesFitted = rtp2cart([rUp rtp_sphere(:,2:3)*180/pi]);


%% Now find the faces below the lower edge of the digitization points, and
%% remove them
if ~isstruct(spacing),

   % as a function of phi (azimuth), find the largest theta (smallest
   %  elevation).
   [data_ph,tmp] = sort(rtp(:,3));	% sort the azimuth
   data_th = rtp(tmp,2);		% same order for elevation

   ndx = find(~diff(data_ph)); 	% where I have repetitions
   while(any(ndx)),
      data_ph(ndx) = [];
      % take max of the two and drop the other
      data_th(ndx+1) = max([data_th(ndx) data_th(ndx+1)]')';
      data_th(ndx) = [];
      ndx = find(~diff(data_ph)); 	% where I have repetitions still
   end

   mean_ph = mean(diff(data_ph));	% average increment in azimuth
   win_pts = round(ANG_WIDTH/mean_ph);	% width of window
   if(~rem(win_pts,2)),		% it's even
      win_pts = win_pts + 1;	% want odd points
   end
   win_pts2 = (win_pts-1)/2;	% one side of window
   tot_pts = length(data_ph);	% number of data points
   data_slide = hankel(data_th([[-win_pts2:0]+tot_pts [1:win_pts2]]),...
      data_th([[win_pts2:tot_pts] [1:(win_pts2-1)]]));
   mx_th = max(data_slide).';	% gives maximum theta as func of phi

   % interpolate the corresponding theta val, pad front and back for wrap
   n_ph = length(data_ph);
   data_ph = [data_ph(n_ph)-2*pi;data_ph;2*pi+data_ph(1)]; % wrap both ends
   mx_th = [mx_th(n_ph);mx_th;mx_th(1)];

   % now interpolate the phi
   tsi = interp1(data_ph,mx_th,rtp_sphere(:,3));
   trim = find(rtp_sphere(:,2) > tsi); 	% values below the data
   % keep = [1:size(Vertices,1)];
   % keep(trim) = []; % the vertices to keep

   for i = 1:length(trim),
      [ignore,Col] = find(Faces == trim(i));
      Faces(:,Col) = []; % remove this triangle
   end

   % now we only have the upper faces corresponding to the vertices we like
   
   % cleanup routine, suggested by Francois Tadel.
   % Note I have Faces and Vertices reversed in definitions here.

    iUnusedVertices = setdiff(1:length(VerticesFitted), unique(Faces(:)));

    [VerticesFitted, Faces] = tess_remove_vert(VerticesFitted, Faces', iUnusedVertices);

    Faces = Faces';


   
   
   % the other faces are still numbered to all vertices, just leave alone for
   % now

end

%% Generate the output structure

fv = struct('faces',[],'vertices',[]);

fv.vertices = VerticesFitted;
fv.faces = Faces';
cnorm = sqrt(sum(fv.vertices.^2,2)); % row norms
% shift back to original coordinate system
fv.vertices = fv.vertices + new_org(ones(size(fv.vertices,1),1),:);
hsdig = hsdig + new_org(ones(size(hsdig,1),1),:); % subtract

%% Visualize
if(verbose)
   disp(sprintf('Generated %.0f triangles interpolated through your data',...
      size(VerticesFitted,1)));
   figure(windfind('Tesselation Results'));
   clf
   % give almost black edges (so they don't invert on print)
   colormap(hot(64));
   patch(fv,'edgecolor','k','facecolor','interp','FaceVertexCData',cnorm)
   cax = caxis;
   caxis([cax(1)*.9 cax(2)*1.1]);	% not quite from black to hot
   hold on
   hp=plot3(hsdig(:,1),hsdig(:,2),hsdig(:,3),'go');
   hold off
   title(sprintf(...
      'Tesselation Results, order %.0f, on a %.2f sphere',...
      order,shell));
   xlabel('X-axis')
   ylabel('Y-axis')
   zlabel('Z-axis')
   axis('square')
   axis('equal')
   view([75 5])			% somewhat off to the subject's right side
   colorbar
   % bar_scale;
   view(3)
   axis equal
   axis vis3d
end





