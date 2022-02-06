function [ r ] = dm_tiedrank(X,dim)
% r = dm_tiedrank(X,dim)
%
% Ranks X along dimension dim. Where values are the same the mean rank is 
% given, e.g. [99 110 50 13 99] goes to [ 3.5 5 2 1 3.5]
%
% Code is fully vectorised.
%
% DM, Jan 2012
% http://www.mathworks.com/matlabcentral/fileexchange/34560-tiedrank--x-dim-

%[Step 0a]: force dim to be 1, and compress everything else into a single 
%dimension. We will reverse this process at the end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Added FT 19-May-2016
if (nargin < 2) || isempty(dim)
    dim = 1;
end
if (size(X,dim) < 3)
    error('This function works with a minimum of 3 values in the sorted dimension.');
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if dim > 1 
	otherDims = 1:length(size(X));
	otherDims(dim) = [];
    perm = [dim otherDims];
    X = permute(X,perm);
end
originalSiz = size(X);
X = reshape(X,originalSiz(1),[]);
siz = size(X);

%[Step 1]: sort and get sorting indicies
[X,Ind] = sort(X,1);

%[Step 2]: create matrix [D], which has +1 at the start of consecutive runs
% and -1 at the end, with zeros elsewhere.
D = zeros(siz,'int8');
D(2:end-1,:) = diff(X(1:end-1,:) == X(2:end,:));
D(1,:) = X(1,:) == X(2,:);
D(end,:) = -( X(end,:) == X(end-1,:) );

clear X

%[Step 3]: calculate the averaged rank for each consecutive run
[a,~] = find(D);
a = reshape(a,2,[]);
h = sum(a,1)/2;

%[Step 4]: insert the troublseome ranks in the relevant places
L = zeros(siz);
L(D==1) = h;
L(D==-1) = -h;
L = cumsum(L);
L(D==-1) = h; %cumsum set these ranks to zero, but we wanted them to be h

clear D h

%[Step 5]: insert the simple ranks (i.e. the ones that didn't clash)
[L(~L),~] = find(~L);

%[Step 6]: assign the ranks to the relevant position in the matrix
Ind = bsxfun(@plus,Ind,(0:siz(2)-1)*siz(1)); %equivalent to using sub2ind + repmat
r(Ind) = L;

%[Step 0b]: As promissed, we reinstate the correct dimensional shape and order
r = reshape(r,originalSiz);
if dim > 1
    r = ipermute(r,perm);
end


end