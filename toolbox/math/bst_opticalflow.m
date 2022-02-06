function [flowField, int_dF, errorData, errorReg, poincare, interval] = ...
  bst_opticalflow(F, FV, Time, tStart, tEnd, hornSchunck)
% BST_OPTICALFLOW: Computes the optical flow of MEG/EEG activities on the cortical surface.
%
% USAGE:  [flow, dEnergy, int_dI, errorData, errorReg, index] = ...
%   bst_opticalflow(dataFile, channelFile, tStart, tEnd, hornSchunck)
%
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
% Authors: Julien Lef�vre, 2006-2010
%          Syed Ashrafulla, 2010

% INPUTS
%   F                 - Reconstructed sources
%   FV                - Tesselation for calculating spatial derivatives
%   Time              - Time points of sampling of recordings
%   tStart            - First time point for optical flow analysis
%   tEnd              - Last time point for optical flow analysis
%   hornSchunck       - Parameter to tune optical flow calculation
%   segment           - Flag to split data into stable and transient states
% OUTPUTS
%   flowField         - Optical flow field
%                       dimension (# of vertices) X length(tStart:tEnd)
%   int_dF            - Constant term in variational formulation
%   errorData         - Error in fit to data
%   errorReg          - Energy in regularization
%   poincare          - Poincar� index

%/---Script Authors---------------------\
%|                                      | 
%|   *** J.Lef�vre, PhD                 |  
%|   julien.lefevre@chups.jussieu.fr    |
%|                                      | 
%\--------------------------------------/

dimension = 3; % 2 for projected maps
Faces = FV.Faces; Vertices = FV.Vertices; VertNormals = FV.VertNormals;
nVertices = size(Vertices,1); % VertNormals = FV.VertNormals';
nFaces = size(Faces,1);
tStartIndex = find(Time < tStart-eps, 1, 'last')+1; % Index of first time point for flow calculation
if isempty(tStartIndex)
    [tmp, tStartIndex] = min(Time);
    tStartIndex = tStartIndex + 1;
end
tEndIndex = find(Time < tEnd-eps, 1, 'last')+1; % Index of last time point for flow calculation
if isempty(tEndIndex)
    [tmp, tEndIndex] = max(Time);
    tEndIndex = tEndIndex + 1;
end
if tEndIndex > size(Time, 2)
    tEndIndex = size(Time, 2);
end
interval = Time(tStartIndex:tEndIndex); % Interval of flow calculations
intervalLength = tEndIndex-tStartIndex+1; % Length of time interval for calculations
M = max(max(abs(F(:,tStartIndex-1:tEndIndex)))); F = F/M; % Scale values to avoid precision error
flowField = zeros(nVertices, dimension, intervalLength);
dEnergy = zeros(1, intervalLength);
errorData = zeros(1, intervalLength);
errorReg = zeros(1, intervalLength);
int_dF = zeros(1, intervalLength);

[regularizerOld, gradientBasis, tangentPlaneBasisCell, tangentPlaneBasis, ...
  triangleAreas, FaceNormals, sparseIndex1, sparseIndex2]= ...
  regularizing_matrix(Faces, Vertices, VertNormals, dimension); % 2 for projected maps
regularizer = hornSchunck * regularizerOld;

% Projection of flow on triangle (for Poincar� index)
Pn = zeros(3,3,nFaces);
for facesIdx = 1:nFaces
    Pn(:,:,facesIdx) = eye(3) - ...
      (FaceNormals(facesIdx,:)'*FaceNormals(facesIdx,:));
end
poincare = zeros(nFaces, intervalLength);

% Optical flow calculations
bst_progress('start', 'Optical Flow', ...
  'Computing optical flow ...', tStartIndex-1, tEndIndex);
for timePoint = tStartIndex:tEndIndex
  timeIdx = timePoint-tStartIndex+1;
  
  % Solve for flow
  dF = F(:,timePoint)-F(:,timePoint-1);
  [dataFit, B] = data_fit_matrix(Faces, nVertices, ...
    gradientBasis, triangleAreas, tangentPlaneBasisCell, ...
    F(:,timePoint), dF, dimension, ...
    sparseIndex1, sparseIndex2);
  X = (dataFit + regularizer) \ B;
  
  % Save flows correctly (for 3D surface, have to project back to 3D)
  if dimension == 3 % X coordinates are in tangent space
      flowField(:,:,timeIdx) = ...
        repmat(X(1:end/2), [1,3]) .* tangentPlaneBasis(:,:,1) ...
        + repmat(X(end/2+1:end), [1,3]) .* tangentPlaneBasis(:,:,2);
  else % X coordinates are in R^2
      flowField(:,:,timeIdx) = [X zeros(nVertices,1)];
  end
  
  errorData(timeIdx)= X'*dataFit*X - 2*B'*X; % Data fit error
  errorReg(timeIdx)= X'*regularizer*X; % Regularization error

  % Variational formulation constant
  dF12=(dF(Faces(:,1),:)+dF(Faces(:,2))).^2;
  dF23=(dF(Faces(:,2),:)+dF(Faces(:,3))).^2;
  dF13=(dF(Faces(:,1),:)+dF(Faces(:,3))).^2;
  int_dF(timeIdx) = sum(triangleAreas.*(dF12+dF23+dF13)) / 24;
  
  % Precompute flowfield with faces to save time in the loop.
  FacesFlowField = reshape(flowField(Faces', :, timeIdx)', [3,3,nFaces]);
  
  % Poincare Index of each triangle
  for facesIdx=1:nFaces
      poincare(facesIdx,timeIdx) = ... % projection of flowField(f,:,t) on triangle f
          poincare_index(Pn(:,:,facesIdx) * FacesFlowField(:,:,facesIdx));
  end

  % Displacement energy
  v12 = sum((flowField(Faces(:,1),:,timeIdx)+flowField(Faces(:,2),:,timeIdx)).^2,2) / 4;
  v23 = sum((flowField(Faces(:,2),:,timeIdx)+flowField(Faces(:,3),:,timeIdx)).^2,2) / 4;
  v13 = sum((flowField(Faces(:,1),:,timeIdx)+flowField(Faces(:,3),:,timeIdx)).^2,2) / 4;
  dEnergy(timeIdx) = sum(triangleAreas.*(v12+v23+v13));
  
  bst_progress('inc', 1); % Update progress bar
end 

bst_progress('stop');
  
end

% =========================================================================
% =====  EXTERNAL FUNCTIONS ===============================================
% =========================================================================

%% ===== TESSELATION NORMALS =====
function [gradientBasis, triangleAreas, FaceNormals] = ...
  geometry_tesselation(Faces, Vertices, dimension)
% GEOMETRY_TESSELATION    Computes some geometric quantities from a surface
% 
% INPUTS:
%   Faces           - triangles of tesselation
%   Vertices        - coordinates of nodes
%   dimension       - 3 for scalp or cortical surface (default)
%                     2 for plane (channel cap, etc)
% OUTPUTS:
%   gradientBasis   - gradient of basis function (FEM) on each triangle
%   triangleAreas 	- area of each triangle
%   FaceNormals    - normal of each triangle 

% Edges of each triangles
u = Vertices(Faces(:,2),:)-Vertices(Faces(:,1),:);
v = Vertices(Faces(:,3),:)-Vertices(Faces(:,2),:);
w = Vertices(Faces(:,1),:)-Vertices(Faces(:,3),:);

% Length of each edges and angles bewteen edges
uu = sum(u.^2,2);
vv = sum(v.^2,2);
ww = sum(w.^2,2);
uv = sum(u.*v,2);
vw = sum(v.*w,2);
wu = sum(w.*u,2);

% 3 heights of each triangle and their norm
h1 = w-((vw./vv)*ones(1,dimension)).*v;
h2 = u-((wu./ww)*ones(1,dimension)).*w;
h3 = v-((uv./uu)*ones(1,dimension)).*u;
hh1 = sum(h1.^2,2);
hh2 = sum(h2.^2,2);
hh3 = sum(h3.^2,2);

% Gradient of the 3 basis functions on a triangle 
gradientBasis = cell(1,dimension);
gradientBasis{1} = h1./(hh1*ones(1,dimension));
gradientBasis{2} = h2./(hh2*ones(1,dimension));
gradientBasis{3} = h3./(hh3*ones(1,dimension));

% Remove pathological gradients
indices1 = find(sum(gradientBasis{1}.^2,2)==0|isnan(sum(gradientBasis{1}.^2,2)));
indices2 = find(sum(gradientBasis{2}.^2,2)==0|isnan(sum(gradientBasis{2}.^2,2)));
indices3 = find(sum(gradientBasis{3}.^2,2)==0|isnan(sum(gradientBasis{3}.^2,2)));

min_norm_grad = min([ ...
  sum(gradientBasis{1}(sum(gradientBasis{1}.^2,2) > 0,:).^2,2); ...
  sum(gradientBasis{2}(sum(gradientBasis{2}.^2,2) > 0,:).^2,2); ...
  sum(gradientBasis{3}(sum(gradientBasis{3}.^2,2) > 0,:).^2,2) ...
  ]);

gradientBasis{1}(indices1,:) = repmat([1 1 1]/min_norm_grad, length(indices1), 1);
gradientBasis{2}(indices2,:) = repmat([1 1 1]/min_norm_grad, length(indices2), 1);
gradientBasis{3}(indices3,:) = repmat([1 1 1]/min_norm_grad, length(indices3), 1);

% Area of each face
triangleAreas = sqrt(hh1.*vv)/2;
triangleAreas(isnan(triangleAreas)) = 0;

% Calculate normals to surface at each face
if dimension == 3
    FaceNormals = cross(w,u);
    FaceNormals = FaceNormals./repmat(sqrt(sum(FaceNormals.^2,2)),1,3);
else
    FaceNormals = [];
end

% % Calculate normals to surface at each vertex (from normals at each face)
% VertNormals = zeros(size(Vertices,1),3);
% bst_progress('start', 'Optical Flow', ...
%   'Computing normals to surface at every vertex ...', 1, size(Faces,1));
% for facesIdx=1:size(Faces,1); 
%   VertNormals(Faces(facesIdx,:),:) = ...
%     VertNormals(Faces(facesIdx,:),:) + ...
%     repmat(FaceNormals(facesIdx,:), [3 1]);
%   
%   if mod(facesIdx,20) == 0
%     bst_progress('inc', 20); % Update progress bar
%   end
% end 
% bst_progress('stop');
% 
% % Normalize perpendicular-to-surface vectors for each vertex
% VertNormals = VertNormals ./ ...
%   repmat(sqrt(sum(VertNormals.^2,2)),1,3);
% VertNormals(isnan(VertNormals)) = 0; % For pathological anatomy

end

%% ===== TESSELATION TANGENT BUNDLE =====
function tangentPlaneBasis = basis_vertices(VertNormals)
% BASIS_VERTICES  Gives an orthonormal basis orthogonal to several vectors
%
% INPUTS:
%   VertNormals       - list of 3D vectors
%   type              - 'uniform' for normal structure of orthonormal
%                       'polar' for R/theta structure of the orthonormal
% OUTPUTS:
%   tangentPlaneBasis - for each vertex, a pair of vectors defining
%                       the orthonormal basis to that vertex using
%                       the normal to the surface at that vertex
% The cheat: if [x y z] is the normal-to-surface, then the tangent plane
% includes the vector [z-y x-z y-x]

nVertices = size(VertNormals,1); VertNormals = -VertNormals;
tangentPlaneBasis = zeros(nVertices, 3, 2); % Initialize

% First vector in basis: [3-2 1-3 2-1]
tangentPlaneBasis(:,:,1) = diff(VertNormals(:, [2 3 1 2]).').';

% Correct for [1 1 1]-ish vertices: use [y -x 0]
bad = abs(dot(VertNormals, ones(nVertices,3)/sqrt(3), 2)) > 0.97;
tangentPlaneBasis(bad,:,1) = ...
    [VertNormals(bad,2) -VertNormals(bad,1) zeros(sum(bad),1)];

% Second vector in basis by cross product
tangentPlaneBasis(:,:,2) = cross(VertNormals, tangentPlaneBasis(:,:,1));

% Normalize to get orthonormal basis
tangentPlaneBasisNorm = sqrt(sum(tangentPlaneBasis.^2,2));
tangentPlaneBasis = tangentPlaneBasis ./ tangentPlaneBasisNorm(:,[1 1 1],:);

end

%% ===== HORN-SCHUNCK REGULARIZATION MATRIX (FOR MANIFOLD) =====
function [regularizer, gradientBasis, tangentPlaneBasisCell, ...
  tangentPlaneBasis, triangleAreas, FaceNormals, ...
  sparseIndex1,sparseIndex2] = ...
  regularizing_matrix(Faces, Vertices, VertNormals, dimension)
% REGULARIZING_MATRIX: Computation of the regularizing part in the
%                      variationnal approach (SS grad(v_k)grad(v_k')) and
%                      other geometrical quantities.
%
% USAGE: [regularizer, gradientBasis, tangentPlaneBasisCell, ...
%        tangentPlaneBasis, triangleAreas, FaceNormals, ...
%        VertNormals, sparseIndex1, sparseIndex2] = ...
%        regularizing_matrix(tri, coord, dim)
%
% INPUTS
%   Faces                   - triangles of the tesselation
%   Vertices                - vertices of the tesselation
%   VertNormals             - normals to surface at each vertex
%   dimension               - 3 for scalp or cortical surface
%                             2 for flat surface
% OUTPUTS :
%   regularizer             - regularizing matrix
%   gradientBasis           - gradient of the basis functions in FEM
%   tangentPlaneBasisCell   - basis of the tangent plane at a surface node
%                             --> nodes listed according to tesselation
%   tangentPlaneBasis       - basis of the tangent plane at a node
%   triangleAreas           - area of the triangles
%   FaceNormals             - normal of each triangle
%   sparseIndex1            - 1st index of sparse tangent basis magnitudes
%   sparseIndex2            - 2nd index of sparse tangent basis magnitudes
%
%/---Script Authors---------------------\
%|                                      | 
%|   *** J.Lef�vre, PhD                 |  
%|   julien.lefevre@chups.jussieu.fr    |
%|                                      | 
%\--------------------------------------/

nVertices = size(Vertices,1); % Number of nodes
[gradientBasis, triangleAreas, FaceNormals] = ...
  geometry_tesselation(Faces, Vertices, dimension);

% Basis of the tangent plane at each vertex
tangentPlaneBasis = basis_vertices(VertNormals);
tangentPlaneBasisCell = cell(2,3); % similar structure to gradientBasis
% 2 = # of basis vectors, 3 = # of nodes in each element (triangle)

tangentPlaneBasisCell{1,1} = tangentPlaneBasis(Faces(:,1),:,1);
tangentPlaneBasisCell{1,2} = tangentPlaneBasis(Faces(:,2),:,1);
tangentPlaneBasisCell{1,3} = tangentPlaneBasis(Faces(:,3),:,1);

tangentPlaneBasisCell{2,1} = tangentPlaneBasis(Faces(:,1),:,2);
tangentPlaneBasisCell{2,2} = tangentPlaneBasis(Faces(:,2),:,2);
tangentPlaneBasisCell{2,3} = tangentPlaneBasis(Faces(:,3),:,2);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% Regularizing matrix SS grad(v_k)grad(v_k') %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
sparseIndex1 = [Faces(:,1) Faces(:,1) Faces(:,2)];
sparseIndex2 = [Faces(:,2) Faces(:,3) Faces(:,3)];
gradientBasisSum = [sum(gradientBasis{1}.*gradientBasis{2},2) ...
  sum(gradientBasis{1}.*gradientBasis{3},2) ...
  sum(gradientBasis{2}.*gradientBasis{3},2)];

tang_scal_11 = [ ...
  sum(tangentPlaneBasisCell{1,1}.*tangentPlaneBasisCell{1,2},2) ...
  sum(tangentPlaneBasisCell{1,1}.*tangentPlaneBasisCell{1,3},2) ...
  sum(tangentPlaneBasisCell{1,2}.*tangentPlaneBasisCell{1,3},2) ...
  ] .* gradientBasisSum .* repmat(triangleAreas, [1 3]);
tang_scal_12 = [ ...
  sum(tangentPlaneBasisCell{1,1}.*tangentPlaneBasisCell{2,2},2) ...
  sum(tangentPlaneBasisCell{1,1}.*tangentPlaneBasisCell{2,3},2) ...
  sum(tangentPlaneBasisCell{1,2}.*tangentPlaneBasisCell{2,3},2) ...
  ] .* gradientBasisSum .* repmat(triangleAreas, [1 3]);
tang_scal_21 = [ ...
  sum(tangentPlaneBasisCell{2,1}.*tangentPlaneBasisCell{1,2},2) ...
  sum(tangentPlaneBasisCell{2,1}.*tangentPlaneBasisCell{1,3},2) ...
  sum(tangentPlaneBasisCell{2,2}.*tangentPlaneBasisCell{1,3},2) ...
  ] .* gradientBasisSum .* repmat(triangleAreas, [1 3]);
tang_scal_22 = [ ...
  sum(tangentPlaneBasisCell{2,1}.*tangentPlaneBasisCell{2,2},2) ...
  sum(tangentPlaneBasisCell{2,1}.*tangentPlaneBasisCell{2,3},2) ...
  sum(tangentPlaneBasisCell{2,2}.*tangentPlaneBasisCell{2,3},2) ...
  ] .* gradientBasisSum .* repmat(triangleAreas, [1 3]);

termes_diag = repmat(triangleAreas, [1 3]) .* [ ...
  sum(gradientBasis{1}.^2,2) ...
  sum(gradientBasis{2}.^2,2) ...
  sum(gradientBasis{3}.^2,2) ]; 

D = sparse(Faces, Faces, termes_diag, nVertices, nVertices);
E11=sparse(sparseIndex1, sparseIndex2, tang_scal_11, nVertices, nVertices);
E11=E11+E11'+D;
E22=sparse(sparseIndex1,sparseIndex2,tang_scal_22,nVertices,nVertices);
E22=E22+E22'+D;
E12=sparse(sparseIndex1,sparseIndex2,tang_scal_12,nVertices,nVertices);
E21=sparse(sparseIndex1,sparseIndex2,tang_scal_21,nVertices,nVertices);

regularizer = [E11 E12+E21'; ...
               E12'+E21 E22];

end

%% ===== HORN-SCHUNCK DATA FIT MATRIX (FOR MANIFOLD) =====
function [dataFit, B] = data_fit_matrix(Faces, nVertices, ...
  gradientBasis, triangleAreas, tangentPlaneBasisCell, F, dF, ...
  dimension, sparseIndex1, sparseIndex2)
% DATA_FIT_MATRIX   Computation of data-fit matrices of the variational 
%                   formulation
% INPUTS:
%   Faces                   - triangles
%   nVertices               - number of nodes
%   gradientBasis           - gradient of the basis functions
%   triangleAreas           - area of each triangle
%   tangentPlaneBasisCell 	- basis of each tangent plane
%   F                       - activity at time step t
%   dF                      - change in activity at time step t
%   dimension               - 3 for scalp or cortical surface
%                             2 for channel surface or cap
%   sparseIndex1            - 1st index of sparse tangent basis magnitudes
%   sparseIndex2            - 2nd index of sparse tangent basis magnitudes
% OUTPUTS:
%   dataFit                 - fit to data matrix:
%                             SS (grad(F).w_k)(grad(F).w_k')
%   B                       - fit to data vector:
%                             -2SS(dF/dt)(grad(F).v_k)

% Gradient of intensity obtained through interpolation
grad_F = repmat(F(Faces(:,1)), 1, dimension) .* gradientBasis{1} ...
  + repmat(F(Faces(:,2)), 1, dimension) .* gradientBasis{2} ...
  + repmat(F(Faces(:,3)), 1, dimension) .* gradientBasis{3};

% Projection of the gradient of F on the tangent space
P_grad_F=cell(1,3); % same structure as gradientBasis : size = nFaces,3 ;
for s=1:3
    for k=1:2
       P_grad_F{s}(:,k)=sum(grad_F.*tangentPlaneBasisCell{k,s},2);
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% Construction of B %%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%

% m�thode Guillaume Obosinski

B = zeros(2*nVertices, 1);
for k = 1:2
   for s = 1:3
     B(Faces(:,s)+(k-1)*nVertices) = ...
       B(Faces(:,s)+(k-1)*nVertices) + ...
       (-1/12 * triangleAreas .* (P_grad_F{s}(:,k)) .* (dF(Faces(:,s))+sum(dF(Faces),2)));
   end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%   Construction of dataFit   %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% scal_F_11=[];
% scal_F_22=[];
% scal_F_12=[];
% scal_F_21=[];
% scal_F_diag_11=[];
% scal_F_diag_22=[];
% scal_F_diag_12=[];

scal_F_11 = [ ...
  P_grad_F{1}(:,1).*P_grad_F{2}(:,1) ...
  P_grad_F{1}(:,1).*P_grad_F{3}(:,1) ...
  P_grad_F{2}(:,1).*P_grad_F{3}(:,1) ...
  ] .* repmat(triangleAreas, [1 3])/12;
scal_F_12 = [ ...
  P_grad_F{1}(:,1).*P_grad_F{2}(:,2) ...
  P_grad_F{1}(:,1).*P_grad_F{3}(:,2) ...
  P_grad_F{2}(:,1).*P_grad_F{3}(:,2) ...
  ] .* repmat(triangleAreas, [1 3])/12;
scal_F_21 = [ ...
  P_grad_F{1}(:,2).*P_grad_F{2}(:,1) ...
  P_grad_F{1}(:,2).*P_grad_F{3}(:,1) ...
  P_grad_F{2}(:,2).*P_grad_F{3}(:,1) ...
  ] .* repmat(triangleAreas, [1 3])/12;
scal_F_22 = [ ...
  P_grad_F{1}(:,2).*P_grad_F{2}(:,2) ...
  P_grad_F{1}(:,2).*P_grad_F{3}(:,2) ...
  P_grad_F{2}(:,2).*P_grad_F{3}(:,2) ...
  ] .* repmat(triangleAreas, [1 3])/12;

scal_F_diag_11 = [ ...
  P_grad_F{1}(:,1).*P_grad_F{1}(:,1) ...
  P_grad_F{2}(:,1).*P_grad_F{2}(:,1) ...
  P_grad_F{3}(:,1).*P_grad_F{3}(:,1) ...
  ] .* repmat(triangleAreas, [1 3])/6;
scal_F_diag_22 = [ ...
  P_grad_F{1}(:,2).*P_grad_F{1}(:,2) ...
  P_grad_F{2}(:,2).*P_grad_F{2}(:,2) ...
  P_grad_F{3}(:,2).*P_grad_F{3}(:,2) ...
  ] .* repmat(triangleAreas, [1 3])/6;
scal_F_diag_12 = [ ...
  P_grad_F{1}(:,1).*P_grad_F{1}(:,2) ...
  P_grad_F{2}(:,1).*P_grad_F{2}(:,2) ...
  P_grad_F{3}(:,1).*P_grad_F{3}(:,2) ...
  ] .* repmat(triangleAreas, [1 3])/6;

S11=sparse(sparseIndex1, sparseIndex2, scal_F_11, nVertices, nVertices);
S22=sparse(sparseIndex1, sparseIndex2, scal_F_22, nVertices, nVertices);
S12=sparse(sparseIndex1, sparseIndex2, scal_F_12, nVertices, nVertices);
S21=sparse(sparseIndex1, sparseIndex2, scal_F_21, nVertices, nVertices);

D11=sparse(Faces, Faces, scal_F_diag_11, nVertices, nVertices); 
D22=sparse(Faces, Faces, scal_F_diag_22, nVertices, nVertices);
D12=sparse(Faces, Faces, scal_F_diag_12, nVertices, nVertices);

dataFit = [S11+S11'+D11 S12+S21'+D12; ...
  S12'+S21+D12 S22+S22'+D22];

end

%% ===== POINCARE INDEX OF FLOW FIELD =====
function index = poincare_index(flowField)
% Compute the index of a vector field VF along a curve (whose it is not
% necessary to give the coordinates !!)
% VF has dimension 2*nbr vectors
  theta = myangle(flowField);
  difftheta = diffangle([theta(2),theta(3),theta(1)], theta);
  index = sum(difftheta)/(2*pi);
end

% gives the good angle of a vector (between 0 and 2pi)
function theta = myangle(flowField) 
  normv=sqrt(sum(flowField.^2,1));
  c=flowField(1,:)./normv;
  s=flowField(2,:)./normv;
  theta = acos(c);

  for ii=1:size(flowField,2)
    if s(ii) < 0
      theta(ii)= -theta(ii) + 2*pi;
    end
  end
end

% Difference of two angles (result between -pi and pi)
function theta = diffangle(theta2, theta1)
  theta = theta2 - theta1;
  for ii=1:length(theta)
    if theta(ii) < -pi
      theta(ii) = theta(ii) + 2*pi;
    elseif theta(ii) > pi
        theta(ii) = theta(ii) - 2*pi;
    end
  end
end