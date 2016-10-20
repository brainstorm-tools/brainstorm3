function edg = SurfStatEdge( surf )

%Finds edges of a triangular mesh or a lattice.
%
% Usage: edg = SurfStatEdge( surf );
%
% surf.tri = t x 3 matrix of triangle indices, 1-based, t=#triangles.
% or
% surf.lat = 3D logical array, 1=in, 0=out.
%
% edg = e x 2 matrix of edge indices, 1-based, e=#edges.

if isfield(surf,'tri')
    tri=sort(surf.tri,2);
    edg=unique([tri(:,[1 2]); tri(:,[1 3]); tri(:,[2 3])],'rows');
end
if isfield(surf,'lat')
    % See the comments of SurfStatResels for a full explanation:
    [I,J,K]=size(surf.lat);
    IJ=I*J;
    [i,j]=ndgrid(1:int32(I),1:int32(J));
    i=i(:);
    j=j(:);
    n1=(I-1)*(J-1)*6+(I-1)*3+(J-1)*3+1;
    n2=(I-1)*(J-1)*3+(I-1)+(J-1);
    edg=zeros((K-1)*n1+n2,2,'int32');
    for f=0:1
        c1=int32(find(rem(i+j,2)==f & i<I & j<J));
        c2=int32(find(rem(i+j,2)==f & i>1 & j<J));
        c11=int32(find(rem(i+j,2)==f & i==I & j<J));
        c21=int32(find(rem(i+j,2)==f & i==I & j>1));
        c12=int32(find(rem(i+j,2)==f & i<I & j==J));
        c22=int32(find(rem(i+j,2)==f & i>1 & j==J));
        edg0=[c1     c1+1; % bottom slice
            c1     c1+I;
            c1     c1+1+I;
            c2-1   c2;
            c2-1   c2-1+I;
            c2     c2-1+I;
            c11    c11+I;
            c21-I  c21;
            c12    c12+1;
            c22-1  c22];
        edg1=[c1     c1+IJ; % between slices
            c1     c1+1+IJ;
            c1     c1+I+IJ;
            c11    c11+IJ;
            c11    c11+I+IJ;
            c12    c12+IJ;
            c12    c12+1+IJ];
        edg2=[c2-1   c2-1+IJ;
            c2     c2-1+IJ;
            c2-1+I c2-1+IJ;
            c21-I  c21-I+IJ;
            c21    c21-I+IJ;
            c22-1  c22-1+IJ;
            c22    c22-1+IJ];
        if f
            for k=2:2:(K-1)
                edg((k-1)*n1+(1:n1),:)=[edg0; edg2; edg1; IJ 2*IJ]+(k-1)*IJ;
            end
        else
            for k=1:2:(K-1)
                edg((k-1)*n1+(1:n1),:)=[edg0; edg1; edg2; IJ 2*IJ]+(k-1)*IJ;
            end
        end
        if rem(K+1,2)==f
            edg((K-1)*n1+(1:n2),:)=edg0(1:n2,:)+(K-1)*IJ; % top slice
        end
    end
    % index by voxels in the lat
    vid=int32(cumsum(surf.lat(:)).*surf.lat(:));
    % only inside the lat
    edg=vid(edg(all(surf.lat(edg),2),:));
end

return
end