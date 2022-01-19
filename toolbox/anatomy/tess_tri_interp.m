function H = tess_tri_interp(Vertices,Faces,dims,isProgress)
% TRI_INTERP: Compute the interpolation matrix from a cortical tessellation to the MRI volume.
%
% INPUT:
%    - Vertices : [Mx3], Coordinates (integers) of the cortical vertices in the MR cube
%    - Faces : [Nx3], Connectivity matrix of the vertices to form the triangles
%    - dims  : 3-element vector : size of the orginal (MR) volume
% OUTPUT:
%    - H : interpolation matrix from values on triangular tessellation to voxels
% NOTES:
%     H is a one-time computed large but sparse matrix (nvoxels X nvertices) and is used as follows.
%     Values of currents at each MRI voxel are obtained by
%         MRIcurrent = H x SurfaceCurrent
%     SurfaceCurrent is a nvertices-tall vector of estimated currents on the tessellated surface
%     MRIcurrent is a nvoxels-tall vector of 3D-interpolated current values at each MR voxels.
%     The index of each MRIcurrent entry corresponds to the index in the 3D cube of the MR.
%     MRs in Brainstorm are stored as n1 X n2 X n3 data arrays.
%     If my_MRI is one of these, values of current at voxel i is MRIcurrent(i). i is the index
%     in the original volume taken in lexicographical (i.e. Matlab's natural) order. 
%     Don't bother too much about this; the only concern one should have is to have the 
%     vertex coordinates expressed in the proper MR indices. Use PCS2MRI in that respect.

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
% Authors: Sylvain Baillet, 2002
%          Francois Tadel, 2012

% Parse inputs
if (nargin < 4) || isempty(isProgress)
    isProgress = 1;
end

Faces = double(Faces);
Vertices = double(Vertices);
% Check matrices orientation
if (size(Vertices, 2) ~= 3) || (size(Faces, 2) ~= 3)
    error('Faces and Vertices must have 3 columns (X,Y,Z).');
end
% REMOVED 12-JAN-2015: WRONG!!!
% % ADDED 25-JUN-2015: Fix 1mm shift in MRI registration in the Y axis (in MRI coordinates)
% Vertices(:,2) = Vertices(:,2) + 1;


dMAX = 2/sqrt(3); % Distance Max Authorized between any voxel and the plane

u = 1:dims(1);
v = 1:dims(2);
w = 1:dims(3);

nFaces = size(Faces,1);

% Progress bar
if isProgress
    isPreviousBar = bst_progress('isVisible');
    bst_progress('start', 'MRI/surface interpolation', 'Computing the interpolation matrix...', 0, 100);
    pos = 1;
end

X = cell(size(Faces,1),1);
Y = cell(size(Faces,1),1);
MAT = X;

% For every triangle
for tri = 1:nFaces
    % Progress bar
    if isProgress && (tri/nFaces*50 > pos)
        pos = ceil(tri/nFaces*50);
        bst_progress('set', pos);
    end
    
    % Get faces
    faces = (Faces(tri,:));
    % Barycenter
    bary = mean(Vertices(faces,:),1); 
    % Vertex block around the current triangle    
    R = max([abs(Vertices(faces,1)-bary(1)),abs(Vertices(faces,2)-bary(2)),...
            abs(Vertices(faces,3)-bary(3))]); 
    R(R<1) = 1;
    bary(bary<0)=1; %dimitrios/esen fix

    % Find the voxels within the triangle
    I = u(abs(bary(1)-u)<=R(1));
    J = v(abs(bary(2)-v)<=R(2));
    K = w(abs(bary(3)-w)<=R(3));

    [II,JJ,KK] = meshgrid(I,J,K);
    II = squeeze(II);
    JJ = squeeze(JJ);
    KK = squeeze(KK);

    % Triangle vertex coordinates, with regards to 1st vertex
    r13 = Vertices(faces(3),:)' - Vertices(faces(1),:)'; % negative of r31
    r12 = Vertices(faces(2),:)' - Vertices(faces(1),:)'; % from 1 to 2

    N = bst_cross(r12,r13)';
    dArea = norm(N); % Area of the triangle x 2
    if dArea == 0
        N = bst_cross(r12+rand(size(r12)),r13+rand(size(r12)))';
        dArea = norm(N);
    end
    N = N/dArea; % Normal to the triangle

    % Find the voxels "in" the triangle plane
    bary_p = [II(:) - bary(1), JJ(:) - bary(2),KK(:) - bary(3)];
    Iplane = bary_p * N';
    Iplane = find(abs(Iplane)<dMAX);
    II = II(Iplane);
    JJ = JJ(Iplane);
    KK = KK(Iplane);

    % Flag the voxels if they belong to the triangle
    r1p = [II(:) - Vertices(faces(1),1),JJ(:)- Vertices(faces(1),2),KK(:) - Vertices(faces(1),3)]';

    % Barycentric Coordinates
    s = (N*bst_cross(r1p,repmat(r13,1,size(r1p,2))))/dArea;
    is = find(s>=0 & s<=1);

    if isempty(is) %dimitrios/esen patch
        continue
    end

    t = (N*bst_cross(repmat(r12,1,size(r1p(:,is),2)),r1p(:,is)))/dArea;
    it = find(t>=0 & t<=1);

    itmp = is(it);

    r = 1-s(itmp)-t(it);
    ir = find(r>=0 & r<=1);

    if isempty(ir) %dimitrios/esen patch
        continue
    end        

    ind = itmp(ir);
    MAT{tri} =  [r(ir);s(ind);t(it(ir))];

    tmp = repmat(sub2ind(dims,II((ind)),JJ((ind)),KK((ind)))',3,1);
    X{tri} = tmp(:)'; 
    Y{tri} = repmat(faces,1,length(ind));       
end

MAT = [MAT{:}];
MAT = MAT(:);

X = [X{:}];
X = X';

Y = [Y{:}];
Y = Y';

X = double(X);
Y = double(Y);

H = sparse(X, Y, double(MAT), prod(dims),size(Vertices,1)); 

tmp = sum(H,2);
ind = find(tmp>1+10*eps);

if ~isempty(ind)
    tmp = full(1./tmp(ind));

    if isProgress
        bst_progress('text', 'Fixing the interpolation matrix...');
    end

    blocks = unique(round(linspace(10,length(ind),20)));

    for k = 1:length(blocks)
        % Progress bar
        if isProgress && (k/length(blocks)*50 > pos - 50)
            pos = 50 + ceil(k/length(blocks)*50);
            bst_progress('set', pos);
        end

        if k > 1
            vec = blocks(k-1)+1:blocks(k);
        else
            vec = 1:blocks(1);
        end
        H(ind(vec),:) = spdiags(tmp(vec),0,length(vec),length(vec)) * H(ind(vec),:);
    end
end

% Close progress bar
if isProgress && ~isPreviousBar
    bst_progress('stop');
end









