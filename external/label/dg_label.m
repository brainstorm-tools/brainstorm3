function [L,num,sz] = db_label(I,n)
%LABEL Label connected components in 2-D arrays.
%   LABEL is a generalization of BWLABEL: BWLABEL works with 2-D binary
%   images only, whereas LABEL works with 2-D arrays of any class. Use
%   BWLABEL if the input is binary since BWLABEL will be much faster.
%
%   L = LABEL(I,N) returns a matrix L, of the same size as I, containing
%   labels for the connected components in I. Two adjacent components
%   (pixels), of respective indexes IDX1 and IDX2, are connected if I(IDX1)
%   and I(IDX2) are equal.
%
%   N can have a value of either 4 or 8, where 4 specifies 4-connected
%   objects and 8 specifies 8-connected objects; if the argument is
%   omitted, it defaults to 8.
%
%   Important remark:
%   ----------------
%   NaN values are ignored and considered as background. Because LABEL
%   works with arrays of any class, the 0s are NOT considered as the
%   background. 
%
%   Note:
%   ----
%   The elements of L are integer values greater than or equal to 0. The
%   pixels labeled 0 are the background (corresponding to the NaN
%   components of the input array). The pixels labeled 1 make up one
%   object, the pixels labeled 2 make up a second object, and so on.
%
%   [L,NUM] = LABEL(...) returns in NUM the number of connected objects
%   found in I.
%
%   [L,NUM,SZ] = LABEL(...) returns a matrix SZ, of the same size as I,
%   that contains the sizes of the connected objects. For a pixel whose
%   index is IDX, we have: SZ(IDX) = NNZ(L==L(IDX)).
%
%   Class Support
%   -------------
%   I can be logical or numeric. L is double.
%
%   Example
%   -------
%       I = [3 3 3 0 0 0 0 0
%            3 3 1 0 6.1 6.1 9 0
%            1 3 1 3 6.1 6.1 0 0
%            1 3 1 3 0 0 1 0
%            1 3 3 3 3 3 1 0
%            1 3 1 0 0 3 1 0
%            1 3 1 0 0 1 1 0
%            1 1 1 1 1 0 0 0];
%       L4 = label(I,4);
%       L8 = label(I,8);
%       subplot(211), imagesc(L4), axis image off
%       title('Pixels of same color belong to the same region (4-connection)')
%       subplot(212), imagesc(L8), axis image off    
%       title('Pixels of same color belong to the same region (8-connection)')
%
%   Note
%   ----
%       % Comparison between BWLABEL and LABEL:
%       BW = logical([1 1 1 0 0 0 0 0
%                     1 1 1 0 1 1 0 0
%                     1 1 1 0 1 1 0 0
%                     1 1 1 0 0 0 1 0
%                     1 1 1 0 0 0 1 0
%                     1 1 1 0 0 0 1 0
%                     1 1 1 0 0 1 1 0
%                     1 1 1 0 0 0 0 0]);
%       L = bwlabel(BW,4);
%       % The same result can be obtained with LABEL:
%       BW2 = double(BW);
%       BW2(~BW) = NaN;
%       L2 = label(BW2,4);
%
%   See also BWLABEL, BWLABELN, LABEL2RGB
%
%   -- Damien Garcia -- 2010/02, revised 2011/01
%   http://www.biomecardio.com

% Check input arguments
% error(nargchk(1,2,nargin));
if nargin==1, n=8; end

assert(ndims(I)==2,'The input I must be a 2-D array')

% -----
% The Union-Find algorithm is based on the following document:
% http://www.cs.duke.edu/courses/cps100e/fall09/notes/UnionFind.pdf
% -----

% Initialization of the two arrays (ID & SZ) required during the
% Union-Find algorithm.
sizI = size(I);
id = reshape(1:prod(sizI),sizI);
sz = ones(sizI);

% Indexes of the adjacent pixels
vec = @(x) x(:);
if n==4 % 4-connected neighborhood
    idx1 = [vec(id(:,1:end-1)); vec(id(1:end-1,:))];
    idx2 = [vec(id(:,2:end)); vec(id(2:end,:))];
elseif n==8 % 8-connected neighborhood
    idx1 = [vec(id(:,1:end-1)); vec(id(1:end-1,:))];
    idx2 = [vec(id(:,2:end)); vec(id(2:end,:))];
    idx1 = [idx1; vec(id(1:end-1,1:end-1)); vec(id(2:end,1:end-1))];
    idx2 = [idx2; vec(id(2:end,2:end)); vec(id(1:end-1,2:end))];
else
    error('The second input argument must be either 4 or 8.')
end

% Create the groups and merge them (Union/Find Algorithm)
for k = 1:length(idx1)
    root1 = idx1(k);
    root2 = idx2(k);
    
    while root1~=id(root1)
        id(root1) = id(id(root1));
        root1 = id(root1);
    end
    while root2~=id(root2)
        id(root2) = id(id(root2));
        root2 = id(root2);
    end
    
    if root1==root2, continue, end
    % (The two pixels belong to the same group)
    
    N1 = sz(root1); % size of the group belonging to root1
    N2 = sz(root2); % size of the group belonging to root2
    
    if I(root1)==I(root2) % then merge the two groups
        if N1 < N2
            id(root1) = root2;
            sz(root2) = N1+N2;
        else
            id(root2) = root1;
            sz(root1) = N1+N2;
        end
    end
end

while 1
    id0 = id;
    id = id(id);
    if isequal(id0,id), break, end
end
sz = sz(id);

% Label matrix
isNaNI = isnan(I);
id(isNaNI) = NaN;
[id,m,n] = unique(id);
I = 1:length(id);
L = reshape(I(n),sizI);
L(isNaNI) = 0;

if nargout>1, num = nnz(~isnan(id)); end