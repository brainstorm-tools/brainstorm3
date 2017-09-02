function R = ImaGIN_spm_mesh_to_grid(M, V, T)
% Non-linear interpolation of surface-based data onto a regular grid
% FORMAT R = spm_mesh_to_grid(M, V, T)
% M        - a patch structure with fields 'faces' and 'vertices'
% V        - an spm_vol structure with fields 'dim' and 'mat'
% T        - array of data to be interpolated
%
% R        - interpolated data on grid defined by V
%__________________________________________________________________________
% Copyright (C) 2010 Wellcome Trust Centre for Neuroimaging

% Karl Friston, Guillaume Flandin
% $Id: spm_mesh_to_grid.m 4079 2010-10-07 11:41:54Z guillaume $


%-Precompute interpolation kernel and voxel grid
%==========================================================================

%-Compute a densely sampled triangular mask
%--------------------------------------------------------------------------
[tx, ty]  = meshgrid(0.05:0.1:0.95, 0.05:0.1:0.95);
tx        = tx(:);
ty        = ty(:);
ti        = find(sum([tx ty],2) <= 0.9);
tx        = tx(ti); 
ty        = ty(ti); 
tz        = 1 - tx - ty;

%-Map the dense template triangle onto each face of the surface mesh
%--------------------------------------------------------------------------
P1        = M.vertices(M.faces(:,1),:);
P2        = M.vertices(M.faces(:,2),:);
P3        = M.vertices(M.faces(:,3),:);

If        = speye(size(M.faces,1));

vertDense = kron(If,tx)*P2 + kron(If,ty)*P3 + kron(If,tz)*P1;
kernel    = [tz tx ty];

%-Get voxel indices of all vertices from dense mesh within the image
%--------------------------------------------------------------------------
voxDense  = V.mat\[vertDense';ones(1,size(vertDense,1))];
voxDense  = round(voxDense(1:3,:)');
% Remove = unique([find(voxDense(:,1)<=0); find(voxDense(:,2)<=0);find(voxDense(:,3)<=0)]);         %OD=in case vo
% Keep=setdiff(1:size(voxDense,1),Remove);
% voxDense=voxDense(Keep,:);%OD=in case vo
voxDense(find(voxDense<=0))=1;      %OD, quick fix, don't find the solution
voxDense(find(voxDense(:,1)>V.dim(1)),1)=V.dim(1);      %OD, quick fix, don't find the solution
voxDense(find(voxDense(:,2)>V.dim(2)),2)=V.dim(2);      %OD, quick fix, don't find the solution
voxDense(find(voxDense(:,3)>V.dim(3)),3)=V.dim(3);      %OD, quick fix, don't find the solution
voxInd    = sub2ind(V.dim,voxDense(:,1),voxDense(:,2),voxDense(:,3));
voxInd    = reshape(voxInd,size(kernel,1),[]);


%-Interpolation
%==========================================================================
integralConservation = true;
integralConservation = false;   %OD

%-Normalise vertex data by the number of faces they are in
%--------------------------------------------------------------------------
if integralConservation
    A = spm_mesh_adjacency(M);
    T = spdiags(1./sum(A,2),0,size(A,1),size(A,1)) * T;
end
    
%-Interpolate each dense face data in the voxel grid
%--------------------------------------------------------------------------
R = zeros([V.dim size(T,2)]);
if ~integralConservation, countR = zeros(size(R)); end

for i = 1:size(M.faces,1)
    %- Values at the vertices of the face
    faceVal      = T(M.faces(i,:),:);
%     isData       = any(faceVal);
    if sum(isnan(T)>0)                           %OD
        isData       = sum(isnan(faceVal))<3;
    else
        isData       = any(faceVal);
    end
    if any(isData)
        %- Voxels corresponding to those vertices
        [iV,I,J] = unique(voxInd(:,i));
        for j=find(isData)
            %- Values at the vertices of the dense face
            faceValDense = kernel*faceVal(:,j);
            if integralConservation
                faceValDense = faceValDense * sum(faceVal(:,j))/sum(faceValDense);
            end
            %- Integrating values within voxels
            k = (j-1) * prod(V.dim);
            if integralConservation
                R(iV+k) = R(iV+k) + accumarray(J,faceValDense);
            else
                R(iV+k) = R(iV+k) + accumarray(J,faceValDense,[],@mean);
                countR(iV+k) = countR(iV+k) + 1;
            end
        end
    end
end

if ~integralConservation
    % countR(~countR) = 1;  %OD
    R = R ./ countR;
end

if size(T,2) == 1, R = R(:,:,:,1); end
