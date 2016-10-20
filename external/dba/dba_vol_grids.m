function [SourceLoc] = dba_vol_grids(tess)
% function [SourceLoc] = vol_grids(tess)
%
% Function to create a 3D grid inside a surfacic mesh
%
% input : tess is a surfacic mesh:
%           - tess.Vertices [nbVert x 3]
%           - tess.Faces [nbFacs x 3]
%
% output: SourceLoc is the matrix of positions [nbLoc x 3]
%
% Yohan Attal - HM-TC project 2011

fac  = tess.Faces;
vert = tess.Vertices;

% Creation of the volumic grid with a step "p" in a rectangular
% parallelepipede containing the surfacic mesh
Xmax = max(vert(:,1));
Xmin = min(vert(:,1));
Ymax = max(vert(:,2));
Ymin = min(vert(:,2));
Zmax = max(vert(:,3));
Zmin = min(vert(:,3));

% compute volume of the mesh in order to define the grid step
V = dba_mesh_volume(tess);
V = V*10e6;

if V<5
    p = 0.002;
elseif V<15
    p = 0.003;
else
    p = 0.004;
end
[x,y,z] = meshgrid(Xmin:p:Xmax,Ymin:p:Ymax,Zmin:p:Zmax);

% Creation of the cube localization vector : NbSources x 3
[nx ny nz] = size(x);
Nbsources = nx*ny*nz;
SourceLoc = zeros(Nbsources,3);
c=0;
for i=1:nx
    for j=1:ny
        for k=1:nz
            c=c+1;
            SourceLoc(c,:) = [x(i,j,k) y(i,j,k) z(i,j,k)];
        end
    end
end
clear x y z

% Removal of external points sources
IS = inpolyhd(SourceLoc,vert,fac);
II = find(IS == 0);
%size(II)
k=0;
for i=1:length(II)
    SourceLoc = [SourceLoc(1:II(i,1)-1-k,:);SourceLoc(II(i,1)+1-k:end,:)];
    k=k+1;
end 
% disp(sprintf('DBA> Number of sources in the created 3D grid : %d',length(SourceLoc)))


