function [U, A, H, Vcurl, Vdiv, index] = bst_opticalflow_hhd(opticalFlow, FV, depthHHD)

% BST_OPTICALFLOW_HHD: Computes the Helmhlotz-Hodge Decomposition of the
% optical flow of MEG/EEG activities on the cortical surface.
%
% USAGE:  [U, A, H, Vcurl, Vdiv, index] = 
% bst_opticalflow_hhd(opticalFlow, FV, depthHHD)
%
% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors:  Léo Nouvelle, 2020
%           Sheraz Khan, 2008
%           Julien Lefevre, 2006-2010
%          
% INPUTS
%   opticalFlow       - Optical Flow motion field
%   FV                - Tesselation for calculating spatial derivatives
%   depthHHD          - Recursive depth of the Helmholtz-Hodge decomposition
% OUTPUTS
%   U                 - Potential Field associated to the curl-free
%                       component of the HH decomposition
%   A                 - Potential Field associated to the divergence-free
%                       component of the HH decomposition
%   H                 - Harmonic component of the HH decomposition
%   Vcurl             - Divergence-free component of the HHD
%   Vdiv              - Curl-free component of the HHD

index = 1:size(opticalFlow,3);
nVertices = size(FV.Vertices,1);

U=zeros(nVertices,length(index));
A=zeros(nVertices,length(index));
Vcurl=zeros(nVertices,3,length(index));
Vdiv=zeros(nVertices,3,length(index));
H=zeros(nVertices,3,length(index));

% Calculating geometric features of the tessalation
[cont_grad_v,cont_grad_vb,grad_v,aires,norm_tri,VertFaceConn,Pn1]=geometry_tesselation(FV.Faces,FV.Vertices,3);

faces=FV.Faces;
vertices=FV.Vertices;

bst_progress('start', 'Helmholtz Hodge Decomposition', ...
  'Computing Helmhlotz Hodge Decomposition ...', 0, length(index));

%% Désactivé en l'absence de Parralel Computing Toolbox

% parpool
% try
%     poolobj = gcp('nocreate');
%     if isempty(poolobj)
%         parpool;
%     end
% catch
%     disp (' ')
% end
%parfor ii=index(1):index(end) 
%Toolbox

% Ui=zeros(length(vertices),length(index),recur);
% Ai=zeros(length(vertices),length(index),recur);
% Vcurli=zeros(length(vertices),3,length(index),recur);
% Vdivi=zeros(length(vertices),3,length(index),recur);
% Hi=zeros(length(vertices),3,length(index),recur);

%%

for ii = index
    Ui=zeros(length(vertices),depthHHD);
    Ai=zeros(length(vertices),depthHHD);
    Vcurli=zeros(length(vertices),3,depthHHD);
    Vdivi=zeros(length(vertices),3,depthHHD);
    Hi=zeros(length(vertices),3,depthHHD);
    Ui=zeros(length(vertices),depthHHD);
        for i=1:depthHHD
          if i==1         
                [Ui(:,i), Ai(:,i), Hi(:,:,i), Vcurli(:,:,i), Vdivi(:,:,i)]=hhdr(opticalFlow(:,:,ii),1,0,cont_grad_v,cont_grad_vb,grad_v,aires,norm_tri,VertFaceConn,Pn1,faces,vertices);
            else
                [Ui(:,i), Ai(:,i), Hi(:,:,i), Vcurli(:,:,i), Vdivi(:,:,i)]=hhdr(Hi(:,:,i-1),1,0,cont_grad_v,cont_grad_vb,grad_v,aires,norm_tri,VertFaceConn,Pn1,faces,vertices); 
          end
        end %recur
    U(:,ii)=sum(Ui,2);
    A(:,ii)=sum(Ai,2);
    Vcurl(:,:,ii)=sum(Vcurli,3);
    Vdiv(:,:,ii)=sum(Vdivi,3);
    H(:,:,ii)=Hi(:,:,depthHHD);

    bst_progress('inc', 1); % Update progress bar
end % index
% matlabpool close
bst_progress('stop');


end

% =========================================================================
% RECURSIVE FUNCTION
% =========================================================================

function [U, A, H, Vcurl, Vdiv, index]=hhdr(V,range,verbose,cont_grad_v,cont_grad_vb,grad_v,aires,norm_tri,VertFaceConn,Pn1,faces,vertices)

%Routine to calculate U, V and H component of the vector field
% Jflowc contain all the information including optical flow
% range contain Time period on which decomposition required e.g.
% range=500:700
% U,V,H are the component of HHD of a vector field


%% Extracting information from Jflowc and initialization
% Time=Jflowc.t;
FV.Vertices=vertices;
FV.Faces=faces;
clear faces vertices
if nargin<2 
index=1:length(Time);
else
index=range;
end

U=zeros(length(FV.Vertices),length(index));
A=zeros(length(FV.Vertices),length(index));
Vcurl=zeros(length(FV.Vertices),3,length(index));
Vdiv=zeros(length(FV.Vertices),3,length(index));
H=zeros(length(FV.Vertices),3,length(index));

% calculating U, V and H

if verbose==1
h = waitbar(0,'Computing U,V and H');
end

for ii=index
    if verbose==1
waitbar((ii-(index(1)-1))/length(index));
    end
FieldV=V(:,:,ii);

B=zeros(length(FV.Vertices),1);
B2=zeros(length(FV.Vertices),1);

for i=1:size(FV.Faces,1)
    % projection of flows.V(i,:,t) on the triangle i
    Pn=eye(3)-(norm_tri(i,:)'*norm_tri(i,:));
    nodes=FV.Faces(i,:);
    VV=mean(FieldV(nodes,:),1);
    projectV=VV*Pn;
    for s=1:3
        B(nodes(s),1)=B(nodes(s),1)+sum(projectV.*grad_v{s}(i,:)*aires(i),2);
        B2(nodes(s),1)=B2(nodes(s),1)+sum(projectV.*cross(grad_v{s}(i,:),norm_tri(i,:))*aires(i),2);
    end  
end

% Léo 02/2020 : Conditioning phase

[P,R,C] = equilibrate(cont_grad_v);
[P2,R2,C2] = equilibrate(cont_grad_vb);

K = P*R*cont_grad_v*C;
Kb = P2*R2*cont_grad_vb*C2;
[L1,U1] = ilu(K,struct('type','ilutp','droptol',1e-2,'thresh',0));
[L2,U2] = ilu(Kb,struct('type','ilutp','droptol',1e-2,'thresh',0));
Y = P*R*B;
Y2 = P2*R2*B2;

% Linear system inversion

U(:,ii-(index(1)-1))= C*lsqr(K,Y,1e-20,10000, L1, U1);
% % error1 = norm(cont_grad_v*U(:,ii-(index(1)-1))-B)/norm(B);
% disp(append('actual error is ', int2str(error1)))
A(:,ii-(index(1)-1))= C2*lsqr(Kb,Y2,1e-20,10000, L2, U2);
% error2 = norm(cont_grad_vb*A(:,ii-(index(1)-1))-B2)/norm(B2);
% disp(append('actual error is ', int2str(error2)))

Vd=curl(U(:,ii-(index(1)-1)),FV,grad_v);
Vc=curl(A(:,ii-(index(1)-1)),FV,grad_v,norm_tri);

Vcurl(:,:,ii-(index(1)-1))=tri2vert(Vc,VertFaceConn,Pn1);
Vdiv(:,:,ii-(index(1)-1))=tri2vert(Vd,VertFaceConn,Pn1);

H(:,:,ii-(index(1)-1))=V(:,:,ii)-Vcurl(:,:,ii-(index(1)-1))-Vdiv(:,:,ii-(index(1)-1));

end % for
if verbose==1
delete(h)
end


end

% =========================================================================
% EXTERNAL FUNCTIONS
% =========================================================================

function [cont_grad_v,cont_grad_vb,grad_v,aires,norm_tri,VertFaceConn,Pn1]=geometry_tesselation(tri,coord,dim)

% Computation of the regularizing part in the variationnal approach (SS grad(v_k)grad(v_k')) and
% other geometrical quantities.
% INPUTS :
% tri : triangles of the tesselation
% coord : coordinates of the tesselation
% dim : 3, scalp or cortical surface, 2 flat surface
%%%%%
% OUTPUTS :
% cont_grad_v, cont_grad_vb : regularizing matrices
% grad_v : gradient of the basis functions in Finite Element Methods
% aires : area of the triangles
% norm_tri : normal of each triangle
% Pn1 : Projector matrix on surface's triangular meshes

nbr_capt=size(coord,1); % Number of nodes

%% Geometric quantities

[grad_v,aires,norm_tri]=carac_tri(tri,coord,dim);
norm_coord=carac_coord(tri,coord,norm_tri);

% Regularizing matrix SS grad(v_k)grad(v_k')

index1=[];   
index2=[];
termes_diag=[];
termes_diag_b=[];
tang_scal_11=[];
tang_scal_11_b=[];

for k=1:3 
    for j=k+1:3
       index1=[index1,tri(:,k)];
       index2=[index2,tri(:,j)];
      tang_scal_11=[tang_scal_11,sum(grad_v{k}.*grad_v{j},2).*aires];
      tang_scal_11_b=[tang_scal_11_b,sum(cross(grad_v{k},norm_tri).*cross(grad_v{j},norm_tri),2).*aires];
    end
     termes_diag=[termes_diag,sum(grad_v{k}.^2,2).*aires]; 
     termes_diag_b=[termes_diag_b,sum(cross(grad_v{k},norm_tri).^2,2).*aires];
end

D=sparse(tri,tri,termes_diag,nbr_capt,nbr_capt);
Db=sparse(tri,tri,termes_diag_b,nbr_capt,nbr_capt);

E11=sparse(index1,index2,tang_scal_11,nbr_capt,nbr_capt);
E11=E11+E11'+D;
cont_grad_v=E11;

E11b=sparse(index1,index2,tang_scal_11_b,nbr_capt,nbr_capt);
E11b=E11b+E11b'+Db;
cont_grad_vb=E11b;

% Vertice to triangular mesh connectivity
VertFaceConn=cell(size(coord,1),1);
for tt=1:size(tri,1)
    for ind=tri(tt,:)
        VertFaceConn{ind,1}=[VertFaceConn{ind,1};tt];
    end
end

Pn1 = zeros(3,3,size(coord,1));

% Projection matrices on triangular mesh
for ii=1:size(coord,1)
   Pn1(:,:,ii)=eye(3)-(norm_coord(ii,:)'*norm_coord(ii,:)); 
end

end

function [grad,aires,vectoriel]=carac_tri(tri,coord,dim)
% Computes some geometric quantities from a surface
% INPUTS 
% tri : triangles of tesselation
% coord : coordinates of nodes
% dim : deefault 3, 2 for projection on a plane
%
% OUTPUTS 
% grad : gradient of basis function (Finite Elements Method) on each triangle
% aires : area of each triangle
% vectoriel : normal of each triangle 

% Edges of each triangles
u=coord(tri(:,2),:)-coord(tri(:,1),:);
v=coord(tri(:,3),:)-coord(tri(:,2),:);
w=coord(tri(:,1),:)-coord(tri(:,3),:);

% Length of each edges and angles bewteen edges
uu=sum(u.^2,2);
vv=sum(v.^2,2);
ww=sum(w.^2,2);
uv=sum(u.*v,2);
vw=sum(v.*w,2);
wu=sum(w.*u,2);

% 3 heights of each triangle and their norm
h1=w-((vw./vv)*ones(1,dim)).*v;
h2=u-((wu./ww)*ones(1,dim)).*w;
h3=v-((uv./uu)*ones(1,dim)).*u;
hh1=sum(h1.^2,2);
hh2=sum(h2.^2,2);
hh3=sum(h3.^2,2);

% Gradient of the 3 basis functions on a triangle 
grad=cell(1,dim);
grad{1}=h1./(hh1*ones(1,dim));
grad{2}=h2./(hh2*ones(1,dim));
grad{3}=h3./(hh3*ones(1,dim));

% Prevents from pathological gradients

indices1=find(sum(grad{1}.^2,2)==0|isnan(sum(grad{1}.^2,2)));
indices2=find(sum(grad{2}.^2,2)==0|isnan(sum(grad{2}.^2,2)));
indices3=find(sum(grad{3}.^2,2)==0|isnan(sum(grad{3}.^2,2)));
indices21=find(sum(grad{1}.^2,2));
indices22=find(sum(grad{2}.^2,2));
indices23=find(sum(grad{3}.^2,2));

min_norm_grad=min([sum(grad{1}(indices21,:).^2,2);sum(grad{2}(indices22,:).^2,2);sum(grad{3}(indices23,:).^2,2)]);

grad{1}(indices1,:)=repmat([1 1 1]/min_norm_grad,length(indices1),1);
grad{2}(indices2,:)=repmat([1 1 1]/min_norm_grad,length(indices2),1);
grad{3}(indices3,:)=repmat([1 1 1]/min_norm_grad,length(indices3),1);


% Area of triangles and normals of each triangle
aires=sqrt(hh1.*vv)/2;
indices=isnan(aires);
aires(indices)=0;

if dim==3
    vectoriel=cross(w,u);
    vectoriel=vectoriel./repmat(sqrt(sum(vectoriel.^2,2)),1,3);
else
    vectoriel=[];
end
end

function norm_coord=carac_coord(tri,coord,norm_tri)
% Normal at each node of the tesselation
% INPUTS :
% tri : triangles
% coord : coordinates of each node
% norm_tri : normal of each triangle
norm_coord=zeros(size(coord,1),3);
for i=1:size(tri,1)
    for k=1:3
        norm_coord(tri(i,k),:)=norm_coord(tri(i,k),:)+norm_tri(i,:);
    end
end

norm_coord=norm_coord./repmat(sqrt(sum(norm_coord.^2,2)),1,3);

% Not very satisfying solution to the problem of pathological anatomy

indices=isnan(norm_coord);
norm_coord(indices)=0;
end

function [V]=curl(X,FV,grad_v,normals)
% Builds curl-free and divergence-free components from the associated
% potential fields

grad_X=repmat(X(FV.Faces(:,1)),1,3).*grad_v{1}+repmat(X(FV.Faces(:,2)),1,3).*grad_v{2}+repmat(X(FV.Faces(:,3)),1,3).*grad_v{3};
if nargin<4 %just compute the gradient of the scalar field X
    V=grad_X;
else %curl of the scalar field X
    V=cross(grad_X,normals);
end
end

function Vv =tri2vert(Vt,VertFaceConn,Pn)
% Transfers the motion fields calculated on the triangular meshes on the
% vertices

Vv = zeros(size(VertFaceConn,1),3);
card = zeros(1,size(VertFaceConn,1));

for ii=1:size(VertFaceConn,1)
    Vv(ii,:)=(sum(Vt(VertFaceConn{ii},:),1))*Pn(:,:,ii); %average + projection 
    card(ii)=length(VertFaceConn{ii});
end

Vv=Vv./repmat(card',1,3);
end