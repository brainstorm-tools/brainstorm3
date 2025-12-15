function [VertexNormals,VertexArea,FaceNormals,FaceArea]=CalcVertexNormals(FV,FaceNormals) % ,up,vp
    % Very slightly modified for efficiency and convenience, and added normr. Marc L.
%% Summary
%Author: Itzik Ben Shabat
%Last Update: July 2014

%summary: CalcVertexNormals calculates the normals and voronoi areas at each vertex
%INPUT:
%FV - triangle mesh in face vertex structure
%N - face normals
%OUTPUT -
%VertexNormals - [Nv X 3] matrix of normals at each vertex
%Avertex - [NvX1] voronoi area at each vertex
%Acorner - [NfX3] slice of the voronoi area at each face corner

%% Code

if nargin < 2 || isempty(FaceNormals)
    [FaceNormals, FaceArea] = CalcFaceNormals(FV);
end

% disp('Calculating vertex normals... Please wait');
% Get all edge vectors
e0=FV.Vertices(FV.Faces(:,3),:)-FV.Vertices(FV.Faces(:,2),:);
e1=FV.Vertices(FV.Faces(:,1),:)-FV.Vertices(FV.Faces(:,3),:);
e2=FV.Vertices(FV.Faces(:,2),:)-FV.Vertices(FV.Faces(:,1),:);
% Normalize edge vectors
% e0_norm=normr(e0);
% e1_norm=normr(e1);
% e2_norm=normr(e2);

%normalization procedure
%calculate face Area
%edge lengths
de0=sqrt(e0(:,1).^2+e0(:,2).^2+e0(:,3).^2);
de1=sqrt(e1(:,1).^2+e1(:,2).^2+e1(:,3).^2);
de2=sqrt(e2(:,1).^2+e2(:,2).^2+e2(:,3).^2);
l2=[de0.^2 de1.^2 de2.^2];

%using ew to calulate the cot of the angles for the voronoi area
%calculation. ew is the triangle barycenter, I later check if its inside or
%outide the triangle
ew=[l2(:,1).*(l2(:,2)+l2(:,3)-l2(:,1)) l2(:,2).*(l2(:,3)+l2(:,1)-l2(:,2)) l2(:,3).*(l2(:,1)+l2(:,2)-l2(:,3))];

s=(de0+de1+de2)/2;
%Af - face area vector
FaceArea=sqrt(max(0, s.*(s-de0).*(s-de1).*(s-de2)));%herons formula for triangle area, could have also used 0.5*norm(cross(e0,e1))
% if any(~Af) || any(~FaceArea)
%     error('Degenerate faces.');
% end

%calculate weights
Acorner=zeros(size(FV.Faces,1),3);
VertexArea=zeros(size(FV.Vertices,1),1);

% Calculate Vertice Normals
VertexNormals=zeros([size(FV.Vertices,1) 3]);

% up=zeros([size(FV.Vertices,1) 3]);
% vp=zeros([size(FV.Vertices,1) 3]);
for i=1:size(FV.Faces,1)
    %Calculate weights according to N.Max [1999]
    
    wfv1=FaceArea(i)/(de1(i)^2*de2(i)^2);
    wfv2=FaceArea(i)/(de0(i)^2*de2(i)^2);
    wfv3=FaceArea(i)/(de1(i)^2*de0(i)^2);
    
    VertexNormals(FV.Faces(i,1),:)=VertexNormals(FV.Faces(i,1),:)+wfv1*FaceNormals(i,:);
    VertexNormals(FV.Faces(i,2),:)=VertexNormals(FV.Faces(i,2),:)+wfv2*FaceNormals(i,:);
    VertexNormals(FV.Faces(i,3),:)=VertexNormals(FV.Faces(i,3),:)+wfv3*FaceNormals(i,:);
    %Calculate areas for weights according to Meyer et al. [2002]
    %check if the tringle is obtuse, right or acute
    
    if ew(i,1)<=0
        Acorner(i,2)=-0.25*l2(i,3)*FaceArea(i)/(e0(i,:)*e2(i,:)');
        Acorner(i,3)=-0.25*l2(i,2)*FaceArea(i)/(e0(i,:)*e1(i,:)');
        Acorner(i,1)=FaceArea(i)-Acorner(i,2)-Acorner(i,3);
    elseif ew(i,2)<=0
        Acorner(i,3)=-0.25*l2(i,1)*FaceArea(i)/(e1(i,:)*e0(i,:)');
        Acorner(i,1)=-0.25*l2(i,3)*FaceArea(i)/(e1(i,:)*e2(i,:)');
        Acorner(i,2)=FaceArea(i)-Acorner(i,1)-Acorner(i,3);
    elseif ew(i,3)<=0
        Acorner(i,1)=-0.25*l2(i,2)*FaceArea(i)/(e2(i,:)*e1(i,:)');
        Acorner(i,2)=-0.25*l2(i,1)*FaceArea(i)/(e2(i,:)*e0(i,:)');
        Acorner(i,3)=FaceArea(i)-Acorner(i,1)-Acorner(i,2);
    else
        ewscale=0.5*FaceArea(i)/(ew(i,1)+ew(i,2)+ew(i,3));
        Acorner(i,1)=ewscale*(ew(i,2)+ew(i,3));
        Acorner(i,2)=ewscale*(ew(i,1)+ew(i,3));
        Acorner(i,3)=ewscale*(ew(i,2)+ew(i,1));
    end
    VertexArea(FV.Faces(i,1))=VertexArea(FV.Faces(i,1))+Acorner(i,1);
    VertexArea(FV.Faces(i,2))=VertexArea(FV.Faces(i,2))+Acorner(i,2);
    VertexArea(FV.Faces(i,3))=VertexArea(FV.Faces(i,3))+Acorner(i,3);
    
%     %Calculate initial coordinate system
%     up(FV.Faces(i,1),:)=e2_norm(i,:);
%     up(FV.Faces(i,2),:)=e0_norm(i,:);
%     up(FV.Faces(i,3),:)=e1_norm(i,:);
end
VertexNormals=normr(VertexNormals);

% %Calculate initial vertex coordinate system
% for i=1:size(FV.Vertices,1)
%     up(i,:)=cross(up(i,:),VertexNormals(i,:));
%     up(i,:)=up(i,:)/norm(up(i,:));
%     vp(i,:)=cross(VertexNormals(i,:),up(i,:));
% end

% disp('Finished Calculating vertex normals');
end


function [FaceNormals, FaceArea]=CalcFaceNormals(FV)
%% Summary
%Author: Itzik Ben Shabat
%Last Update: July 2014

%CalcFaceNormals recives a list of vrtexes and Faces in FV structure
% and calculates the normal at each face and returns it as FaceNormals
%INPUT:
%FV - face-vertex data structure containing a list of Vertices and a list of Faces
%OUTPUT:
%FaceNormals - an nX3 matrix (n = number of Faces) containng the norml at each face
%% Code
% Get all edge vectors
e0=FV.Vertices(FV.Faces(:,3),:)-FV.Vertices(FV.Faces(:,2),:);
e1=FV.Vertices(FV.Faces(:,1),:)-FV.Vertices(FV.Faces(:,3),:);
% Calculate normal of face
FaceNormalsA=cross(e0,e1);
FaceArea = sqrt(sum(FaceNormalsA.^2, 2)) / 2;
FaceNormals=normr(FaceNormalsA);
end

function V = normr(V)
    V = bsxfun(@rdivide, V, sqrt(sum(V.^2, 2)));
end

