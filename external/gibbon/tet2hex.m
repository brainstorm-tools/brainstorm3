function [varargout]=tet2hex(varargin)



%%
switch nargin
    case 2
        E=varargin{1};
        V=varargin{2};
        tet2HexMethod=1; 
    case 3
        E=varargin{1};
        V=varargin{2};        
        tet2HexMethod=varargin{3};         
end

%% Mid edge sets
edgeMat=[E(:,[1 2]); E(:,[2 3]);  E(:,[3 1]);... %bottom         
         E(:,[1 4]); E(:,[2 4]);  E(:,[3 4]);];   %top-bottom edges

E_sort=sort(edgeMat,2); %Sorted edges matrix
[~,ind1,~]=unique(E_sort,'rows');
edgeMat=edgeMat(ind1,:);

numPoints = size(V,1);
numEdges = size(edgeMat,1);

% Get indices of the four edges associated with each face
A = sparse(edgeMat(:,1),edgeMat(:,2),(1:numEdges)+numPoints,numPoints,numPoints,numEdges);
A = max(A,A'); %Copy symmetric

%Indices for A matrix
indA_12=E(:,1)+(E(:,2)-1)*numPoints;
indA_23=E(:,2)+(E(:,3)-1)*numPoints;
indA_31=E(:,3)+(E(:,1)-1)*numPoints;

indA_14=E(:,1)+(E(:,4)-1)*numPoints;
indA_24=E(:,2)+(E(:,4)-1)*numPoints;
indA_34=E(:,3)+(E(:,4)-1)*numPoints;

%Get indices for vertex array
indV_12=full(A(indA_12));
indV_23=full(A(indA_23));
indV_31=full(A(indA_31));

indV_14=full(A(indA_14));
indV_24=full(A(indA_24));
indV_34=full(A(indA_34));

%% Mid element
indV_mid=(1:1:size(E,1))'+numPoints+size(edgeMat,1);

%% Mid face

%Element faces matrix
F =[E(:,[1 2 3]);... %top
    E(:,[1 2 4]);... %side 1
    E(:,[2 3 4]);... %side 2
    E(:,[3 1 4]);... %side 3
    ]; 

F_sort=sort(F,2); %Sorted edges matrix
[~,ind1,ind2]=unique(F_sort,'rows');
F=F(ind1,:);

indV_midFace=(1:1:size(F_sort,1))';
indOffset=numPoints+size(edgeMat,1)+size(E,1);

indV_midFace123=ind2(indV_midFace((1-1)*size(E,1)+(1:size(E,1))))+indOffset;
indV_midFace124=ind2(indV_midFace((2-1)*size(E,1)+(1:size(E,1))))+indOffset;
indV_midFace234=ind2(indV_midFace((3-1)*size(E,1)+(1:size(E,1))))+indOffset;
indV_midFace314=ind2(indV_midFace((4-1)*size(E,1)+(1:size(E,1))))+indOffset;

%% Create element array

 Es=[E(:,1) indV_12 indV_midFace123 indV_31 indV_14  indV_midFace124 indV_mid indV_midFace314;...%Corner hex 1
    indV_12  E(:,2) indV_23 indV_midFace123 indV_midFace124 indV_24 indV_midFace234 indV_mid;...%Corner hex 2
     indV_midFace123 indV_23 E(:,3) indV_31 indV_mid indV_midFace234 indV_34 indV_midFace314;...%Corner hex 3
     indV_14  indV_midFace124 indV_mid indV_midFace314 E(:,4) indV_24 indV_midFace234 indV_34;...%Corner hex 4
    ];
% Es=Es(:,[4 3 2 1 8 7 6 5]);

%% Create vertex arrays

%new mid-edge points
Vn=0.5*(V(edgeMat(:,1),:)+V(edgeMat(:,2),:));
     
switch tet2HexMethod
    case 1        
        %new mid-element points
        Vm=zeros(size(E,1),3);
        for q=1:1:size(V,2)
            X=V(:,q);
            if size(E,1)==1
                Vm(:,q)=mean(X(E)',2);
            else
                Vm(:,q)=mean(X(E),2);
            end
        end
        
        %new mid-face points
        Vf=zeros(size(F,1),3);
        for q=1:1:size(V,2)
            X=V(:,q);
            Vf(:,q)=mean(X(F),2);
        end
    case 2        
        %new mid-element points
        TET=triangulation(E,V);
        Vm = incenter(TET,(1:size(E,1))');
        
        %new mid-face points
        TR=triangulation(F,V);
        Vf = incenter(TR,(1:size(F,1))');     
end

Vs=[V; Vn; Vm; Vf]; %Join point sets

CVs=[0*ones(size(V,1),1); 1*ones(size(Vn,1),1); 2*ones(size(Vm,1),1); 3*ones(size(Vf,1),1);];

%%

varargout{1}=Es;
varargout{2}=Vs;
varargout{3}=CVs;
 
%% 
% _*GIBBON footer text*_ 
% 
% License: <https://github.com/gibbonCode/GIBBON/blob/master/LICENSE>
% 
% GIBBON: The Geometry and Image-based Bioengineering add-On. A toolbox for
% image segmentation, image-based modeling, meshing, and finite element
% analysis.
% 
% Copyright (C) 2019  Kevin Mattheus Moerman
% 
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.
