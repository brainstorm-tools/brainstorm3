function [ Vtot ] = dba_mesh_volume(tess)
% function [ Vtot ] = mesh_volume(tess)
%
% Volume Calculation of a mesh in m3
% from Zang et al. "EFFICIENT FEATURE EXTRACTION FOR 2D/3D OBJECTS IN MESH REPRESENTATION"
%
% Yohan Attal - 2006 

surface_faces = double(tess.Faces);
surface_vertices = double(tess.Vertices);

% fv.faces = surface_faces;
% fv.vertices = surface_vertices;
% [FaceNormal, FaceArea, FaceCenter, VertexNormal, VertexArea] = tessellation_stats(fv,1); % FV.vertices of size numVert x 3 and FV.faces of size numTri x 3

V = zeros(1,length(surface_faces));
% it = index of tetrahedron i (ie face i )
for it=1:length(surface_faces)
    
    % Vertex of the it faces 
    x1 = surface_vertices(surface_faces(it,1),1); y1 = surface_vertices(surface_faces(it,1),2); z1 = surface_vertices(surface_faces(it,1),3);
    x2 = surface_vertices(surface_faces(it,2),1); y2 = surface_vertices(surface_faces(it,2),2); z2 = surface_vertices(surface_faces(it,2),3);
    x3 = surface_vertices(surface_faces(it,3),1); y3 = surface_vertices(surface_faces(it,3),2); z3 = surface_vertices(surface_faces(it,3),3);
    % S = [x1;y1;z1]*FaceNormal(:,it);% Calculation of signed
    % Volume of the tetrahedron
    V(1,it) = (1/6)*( -(x3*y2*z1)+(x2*y3*z1)+(x3*y1*z2)-(x1*y3*z2)-(x2*y1*z3)+(x1*y2*z3) );
end
%Volume total
Vtot = abs(sum(V));


