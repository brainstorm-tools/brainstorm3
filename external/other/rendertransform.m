function [T, roffset, V, P, W] = rendertransform(ax)
% Render Transform
%   [T, offset] = rendertransform(AX) returns the 4-by-4 render transform of axes AX
%   and the render offset.
%   The render transform maps data coordinates to pixels locations in the 
%   axes parent coordinate system (with flipped y direction). 
%   The render offset is the [x y z] values to subtract from the data inputs
%   before transforming by the render transform.
%
%   [..., V, P, W] = rendertransform(AX) returns additionally the view,
%   projection and viewport transforms. 

%   Copyright 2014 The MathWorks, Inc.

newgraphics = ishandle(ax) && isprop(handle(ax), 'XTickLabelRotation');
cpos = get(ax,'CameraPosition');
ctar = get(ax,'CameraTarget');
cup = get(ax,'CameraUpVector');
cva = get(ax,'CameraViewAngle');
cvaAuto = strcmp(get(ax,'CameraViewAngleMode'), 'auto');
oldunits = get(ax,'Units');
set(ax,'Units','pixels')
axpos = get(ax,'Position');
set(ax,'Units',oldunits)
if newgraphics
    bottomleft = floor(axpos(1:2)) - 1;
    topright = ceil(axpos(1:2) + axpos(3:4));
else
    bottomleft = round(axpos(1:2)) - 1;
    topright = round(axpos(1:2) - 1 + axpos(3:4));
end
% round position to integer pixels
viewport = [bottomleft (topright - bottomleft)];
pxscale = max(viewport(3), 1);
pyscale = max(viewport(4), 1);

pbar = get(ax,'PlotBoxAspectRatio');
warp = strcmp(get(ax,'PlotBoxAspectRatioMode'),'auto') && ...
    strcmp(get(ax,'DataAspectRatioMode'),'auto') && ...
    strcmp(get(ax,'CameraViewAngleMode'),'auto');
if warp && newgraphics
    pbar = [1 1 1];
end
perspective = strcmp(get(ax,'Projection'), 'perspective');
xreverse = strcmp(get(ax,'XDir'),'reverse');
yreverse = strcmp(get(ax,'YDir'),'reverse');
zreverse = strcmp(get(ax,'ZDir'),'reverse');
dsx = xlim;
dsy = ylim;
dsz = zlim;
dsrange = [diff(dsx) diff(dsy) diff(dsz)];
roffset = [dsx(1) dsy(1) dsz(1)];
ascale = dsrange;
dsoffset = roffset;
if any(isinf([dsx dsy dsz]))
    error('infinite limits not supported')
end
if any(isinf(dsrange))
    error('limits too large')
end
if strcmp(get(ax,'XScale'),'log') || ...
        strcmp(get(ax,'YScale'),'log') || ...
        strcmp(get(ax,'ZScale'),'log') 
    error('log scale not supported')
end

% normalize the camera properties
if xreverse
    roffset(1) = dsx(2);
    cpos(1) = 2*mean(dsx) - cpos(1);
    ctar(1) = 2*mean(dsx) - ctar(1);
    ascale(1) = -ascale(1);
    cup(1) = -cup(1);
end
if yreverse
    roffset(2) = dsy(2);
    cpos(2) = 2*mean(dsy) - cpos(2);
    ctar(2) = 2*mean(dsy) - ctar(2);
    ascale(2) = -ascale(2);
    cup(2) = -cup(2);
end
if zreverse
    roffset(3) = dsz(2);
    cpos(3) = 2*mean(dsz) - cpos(3);
    ctar(3) = 2*mean(dsz) - ctar(3);
    ascale(3) = -ascale(3);
    cup(3) = -cup(3);
end
ncpos = (cpos - dsoffset).*pbar./dsrange;
nctar = (ctar - dsoffset).*pbar./dsrange;
ncup  = cup.*pbar./dsrange;
ncdir = nctar - ncpos;

% make View
dot1 = ncdir*ncdir.';
dot2 = ncdir*ncup.';
u = dot1*ncup - dot2*ncdir;
lat = cross(ncdir, u);
ncdir = ncdir/norm(ncdir);
u = u/norm(u);
lat = lat/norm(lat);
p = ncpos.';
offset = [-lat*p ; -u*p ; -ncdir*p ; 1];
V = [lat.*pbar ; u.*pbar ; ncdir.*pbar ; 0 0 0];
V = [V offset];

% make Projection
P = eye(4);
if perspective
    P(4,4) = 0;
    P(4,3) = 1;
end

% compute size
T = P*V;
cube = [ 0 0 0 0 1 1 1 1   % x
         0 0 1 1 0 0 1 1   % y
         0 1 0 1 0 1 0 1   % z
         1 1 1 1 1 1 1 1]; % w
cube2 = T*cube;
cube3 = cube2;
cube3(1,:) = cube3(1,:) ./ cube2(4,:);
cube3(2,:) = cube3(2,:) ./ cube2(4,:);
width = 2*max(abs(max(cube3(1,:))), abs(min(cube3(1,:))));
height = 2*max(abs(max(cube3(2,:))), abs(min(cube3(2,:))));

% view angle
xConstraint = false;
if cvaAuto
    if abs(pxscale*width) < abs(pyscale*height)
        xConstraint = true;
    end
end

% scale projection
fov = cva*pi/360;
if perspective
    scale = 1/(2*tan(fov));
else
    v = ncpos - nctar;
    len = norm(v);
    scale = 1/(2*tan(fov)*len);
end
P(1,1) = P(1,1)*scale;
P(2,2) = P(2,2)*scale;

% viewport transform
T = P*V;
cube2 = T*cube;
cube3 = cube2;
cube3(1,:) = cube3(1,:) ./ cube2(4,:);
cube3(2,:) = cube3(2,:) ./ cube2(4,:);
width = max(cube3(1,:)) - min(cube3(1,:));
height = max(cube3(2,:)) - min(cube3(2,:));
pxoffset = bottomleft(1);
% flip y in the parent reference frame
parent = get(ax,'Parent');
oldunits = get(parent,'Units');
set(parent,'Units','pixels')
parentpos = get(parent,'Position');
set(parent,'Units',oldunits)
pyoffset = parentpos(4) - bottomleft(2);
ov = [pxoffset+pxscale/2 pyoffset-pyscale/2 0];
if ~warp
    if cvaAuto
        if xConstraint
            scale = pxscale;
        else
            scale = pyscale;
        end
    else
        scale = min(pxscale, pyscale);
    end
    sv = [scale -scale];
else
    xscale = pxscale/width;
    yscale = pyscale/height;
    sv = [xscale -yscale];
end
SC = diag([sv 1 1]);
W = makehgtform('translate',ov) * SC;

NORM = diag([1./ascale 1]);

T = W * P * V * NORM;
roffset = roffset.';

