function [ U ] = dba_coord_axes( tess )
% 
% Get coordinates of the main inertia axes
% 
% Yohan Attal - HM-TC project 2011

try
    % subsampling the mesh for faster svd computation
    fv.faces = double(tess.Faces);
    fv.vertices = double(tess.Vertices);
    [nf nv] = reducepatch( fv , 0.1);
catch
    nv = double(tess.Vertices);
end
% centring the coordinates
mx = sum(nv(1,:)) / length(nv);
my = sum(nv(2,:)) / length(nv);
mz = sum(nv(3,:)) / length(nv);
Mx = mx * ones(1,length(nv));
My = my * ones(1,length(nv));
Mz = mz * ones(1,length(nv));
M = [Mx;My;Mz];
C = nv' - M ;

% main axes
[U,S,V] = svd( C ) ;




 