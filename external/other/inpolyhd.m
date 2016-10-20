function is = inpolyhd(R,Rv,N,Nrm,tol)
% INPOLYHD  True for points inside a polyhedron.
%	IS = INPOLYHD(R,RV,N) determines which
%	points of the set R are inside of a multi-
%	dimensional polyhedron with vertices coordinates
%	RV and facets indices N.
%	R is NP by D matrix (NP - number of points,
%	D - dimension),
%	RV - NV by D matrix of polyhedron vertices 
%	coordinates, 
%	N - NF by D matrix, each row specifies the 
%	points in a facet (indices into rows of matrix RV).
%
%	Returns (quasi)-boolean vector IS of the size
%	NP by 1 which is equal to 1 for points inside
%	the simplex and 0 otherwise.
%
%	IS = INPOLYHD(...,TOL) specifies 
%	For points within TOL distance to the boundary
%	(any facets of a polyhedron) IS  is equal to .5
%	Default for TOL is 10*eps.
%	

%  Calls primitive INSPX0 and possibly ROTMAT (which
%  also calls COMBIN, BINARY).

%  Copyright (c) 1995  by Kirill K. Pankratov
%       kirill@plume.mit.edu
%       09/22/95

% Algorithm: Based on the number of ray intersections.
% For each facet:
% Calculate intersections of rays along 1-st coordinate
% with n-dim facet, 
% project along 1-st coordinate into n-1 dimension,
% find whether this intersection point is inside the
% (n-1)-dim simplex, repeat procedure recursively
% till 2-d case.

% Defaults and parameters ...........................
tol_dflt = 10*eps;   % Default for tolerance
mult = .001;         % Fractional coefficient

% Handle input ......................................
if nargin==0, help inpolyhd, return, end
if nargin<3
    error('Not enough input arguments')
end
is_nrm = 0;
if nargin>=4, szNrm = size(Nrm);
else, tol = tol_dflt; end
if nargin==4
    if max(szNrm)>1, is_nrm = 1; tol = tol_dflt;
    else, tol = Nrm;
    end
end


% Sizes and dimensions ..............................
sz = zeros(4,2);
sz = [size(R); size(Rv); size(N)];
if any(diff(sz(:,2)))
    np = max(max(sz));
    op = sparse(sz(:),1,1,np,1);
    d = find(op==3);  % Space dimension must be equal
    if d==[]
        a = ' Matrices R, RV, N must have the same ';
        a = [a 'number of columns'];
        error(a)
    end
    d = min(d);
    % Transpose if necessary ........
    if sz(1,2)~=d, R = R';   sz(1,:) = sz(1,[2 1]); end
    if sz(2,2)~=d, Rv = Rv'; sz(2,:) = sz(2,[2 1]); end
    if sz(3,2)~=d, N = N';   sz(3,:) = sz(3,[2 1]); end
else
    d = sz(1,2);
end
n_pts = sz(1);
nv = sz(2,1);
n_fac = sz(3,1);
if is_nrm
    if all(szNrm==[n_fac d]), Nrm = Nrm';
    elseif ~all(szNrm==[d n_fac])
        a = ' NRM must have the same size as index matrix N';
        error(a)
    end
end


% Auxillary ..........................
od = ones(d,1);
op = ones(n_pts,1);
is = zeros(n_pts,1);
tol = max(tol(1),0);

% Exclude points which are off limits ..............
rmin = min(Rv)-tol;
rmax = max(Rv)+tol;
A = R>=rmin(op,:) & R<=rmax(op,:);
ind = find(all(A'));


% Quick exit if no points within limits
if isempty(ind)
    return
end

% Extract points within limits ........
np = length(ind);
is_out = np<n_pts;
if is_out
    R = R(ind,:);
    is = zeros(np,1);
    op = ones(np,1);
end


% Shift coordinates so that the origin is outside ..
rmin = min(Rv);
rmax = max(Rv);
if any(rmin<=0 & rmax>=0) & ~is_nrm
    rmin = rmax-rmin;
    rmax = (1+rand(1,d)).*rmin;
    R = R+rmax(op,:);
    Rv = Rv+rmax(ones(nv,1),:);
end


% If normals are not input, calculate them ........
if ~is_nrm
    Nrm = zeros(d,n_fac);
    for jj = 1:n_fac
        c_fac = N(jj,:);
        Rs = Rv(c_fac,:);
        Nrm(:,jj) = Rs\od;
    end
end


% Make sure that the first component is not close to 0
while any(abs(Nrm(1,:))<tol)
    A = rotmat(d);  % Rotational matrix
    Nrm = A'*Nrm;
    R = R*A;
    Rv = Rv*A;
end


% For each facet calculate intersections
is  = zeros(np,1);
for jj = 1:n_fac
    c_fac = N(jj,:);
    c_nrm = Nrm(:,jj);
    
    % Find points which can possibly
    % intersect the current facet
    Rs = Rv(c_fac,:);    % Current facet
    rmin = min(Rs)-tol;  % Limits
    rmax = max(Rs)+tol;
    A = R>=rmin(op,:) & R<=rmax(op,:);
    A = A(:,2:d)';
    
    ii = find(all(A));  % Points within all the limits
    Rc = R(ii,:);        % Extract subset of these points
    
    if ~isempty(ii)
        x1 = Rc(:,1);        % Snip the first component
        Rc = Rc(:,2:d);
        Rs = Rs(:,2:d);
        
        % Calculate intersections
        xi = Rc*c_nrm(2:d);
        xi = (1-xi)/c_nrm(1);
        
        % Call INSPX0 with found points ...........
        c_is = inspx0(Rc,Rs,tol);
        
        % Check the first component of intersection
        a = xi-x1;
        ii1 = find(abs(a)<tol);
        a = a>0;
        
        a(ii1) = mult*ones(size(ii1));
        
        c_is = c_is.*a;
        is(ii) = is(ii)+c_is;
        
    end  % End if
    
end  % End for


% Check if even or odd nmb. of intersections ......
op = floor(is);
ii = find(is>op);
op = op-2*floor(op/2);
op(ii) = .5*ones(size(ii));

% Combine with excluded points .........
if is_out
    is = zeros(n_pts,1);
    is(ind) = op;
else     % If weren't any excluded points
    is = op;
end


function is = inspx0(R,Rs,tol)
% INSPX0 True for points inside an n-dimensional simplex.
%	IS = INSPX0(R,RS,TOL)  Accepts coordinates R of 
%	the size NP by D, where NP is a number of points 
%	and D is dimension and coordinates RS (D+1 by D)
%	of the vertices of a simplex; also optional scalar
%	TOL (tolerance for distance to the boundary).
%	Returns (quasi)-boolean vector IS of the size
%	NP by 1 which is equal to 1 for points inside
%	the simplex and 0 otherwise.
%	For points within TOL distance to the boundary
%	(any facets of a simplex) IS  is equal to some
%	fractional number. Default for TOL is 10*eps.
%
%	Primitive for INPOLYHD routine.

%  Copyright (c) 1995  by Kirill K. Pankratov
%       kirill@plume.mit.edu
%       09/22/95

 % Defaults and parameters .........................
tol_dflt = 10*eps;
mult = .001;

 % Handle input ....................................
if nargin<3, tol = tol_dflt; end

 % Sizes and dimensions
[dd,d] = size(Rs);   % Dimension
[np,d1] = size(R);   % Number of points


 % Auxillary .......................................
od = ones(d,1);
op = ones(np,1);
is = zeros(np,1);


 % 2-d case (triangles) ............................
if d==2

  Nrm = Rs([2 3 1],:)-Rs;
  ind = find(abs(Nrm(:,2))>=tol);
  ii = [];
  for jj = 1:length(ind)
    nn = ind(jj);
    b = Nrm(nn,:);
    n1 = (R(:,2)-Rs(nn,2))/b(2);
    xi = Rs(nn,1)+n1*b(1);
    n1 = (n1>=0) & (n1<=1);

    a = xi-R(:,1);
    ii = [ii; find( (abs(a)<tol) & n1 )];
    is = is+(a>0 & n1);
  end

  a = floor(is);
  is = a==1;
  is(ii) = mult*ones(size(ii));   

  return
end


 % Shift coordinates so that the origin is outside
sc = [min(Rs); max(Rs)];
if any(sc(1,:)<=0 & sc(2,:)>=0)
  sc = diff(sc);
  r0 = (1+rand(1,d)).*sc;
  R = R+r0(ones(np,1),:);
  Rs = Rs+r0(ones(d+1,1),:);
end


 % Calculate normals ...................
Nrm = eye(d+1);
for jj=1:d+1
  ii = find(~Nrm(:,jj));
  Nrm(1:d,jj) = Rs(ii,:)\od;
end
Nrm = Nrm(1:d,:)';


 % Check if the first component is not 0
while any(abs(Nrm(:,1))<tol)
  A = rotmat(d);  % Rotational matrix
  Nrm = Nrm*A;
  R = R*A;
  Rs = Rs*A;
end


 % Snip the first component ............
n1 = Nrm(:,1); Nrm = Nrm(:,2:d);
x1 = R(:,1); R = R(:,2:d);
Rs = Rs(:,2:d);

A = ~eye(d+1);
is = zeros(np,1);
for jj = 1:d+1
  r0 = Nrm(jj,:);
  xi = R*r0';
  xi = (1-xi)./n1(jj);

  % Take care of first coordinate
  a = xi-x1;
  ii = find(abs(a)<tol);
  a = a>0;
  a(ii) = mult*ones(size(ii));

  % Recursive call
  io = inspx0(R,Rs(find(A(:,jj)),:));

  io = io.*a;

  is = is+io;

end

 % Check odd or even nmb. of intersections
io = floor(is);
ii = find(is-io);      % Close to boundary
is = io-2*floor(io/2);
is(ii) = mult*ones(size(ii));


function  R = rotmat(d,th)
% Rotational (unitary) matrix.
%	R = ROTMAT(D) produces a random rotation
%	matrix of dimension D.

%  Copyright (c) 1995 by Kirill K. Pankratov
%       kirill@plume.mit.edu
%       09/22/95


 % Handle input .............................
if nargin==0, d = 3; end
if nargin<2, th = []; end

 % Component pairs ..........................
C = combin(d,2);
n = size(C,1);
[i1,i2] = find(C');
i1 = fliplr(reshape(i1,2,n));

 % Angles ....................
thr = (2*rand(n,1)-1)*pi;
thr(1:length(th)) = th;

c = cos(thr);
s = sin(thr);

R = eye(d);
for jj = 1:n
  ii = i1(:,jj);
  cc = c(jj); ss = s(jj);
  A = eye(d);
  A(ii,ii) = [cc ss; -ss cc];
  R = R*A;
end

function  C = combin(n,m)
% COMBIN  Combinations of N choose M.
%	C=COMBIN(M,N) where N>=M, M and N are
%	positive integers returns a matrix C of the
%	size N!/(M!*(N-M)!) by N with rows containing
%	all possible combinations of N choose M.

%  Kirill K. Pankratov,  kirill@plume.mit.edu
%  03/19/95

 % Handle input ..........................
if nargin<2,
  error('  Not enough input arguments.')
end
m = fix(m(1));
n = fix(n(1));
if n<0 | m<0
  error(' In COMBIN(N,M) N and M must be positive integers')
end
if m>n
  error(' In COMBIN(N,M) N must be greater than M')
end

 % Take care of simple cases .............
if m==0,   C = zeros(1,m); return, end
if m==n,   C = ones(1,m);  return, end
if m==1,   C = eye(n);     return, end
if m==n-1, C = ~eye(n);    return, end

 % Calculate sizes and limits ............
n2 = 2^n-1;
m2 = 2^m-1;
mn2 = 2^(m-n)-1;

 % Binary representation .................
C = binary(m2:n2-mn2);

 % Now choose only those with sum equal m
s = sum(C');
C = C(find(s==m),:);

function b = binary(x)

% BINARY  Binary representation of decimal integers.
%	B=BINARY(X) Returns matrx B with rows 
%	representing binary form of each element of
%	vector X.

%  Kirill K. Pankratov, kirill@plume.mit.edu
%  03/02/95

x = x(:);

m2 = nextpow2(max(x));
v2 = 2.^(0:m2);
b = zeros(length(x),m2);
af = x-floor(x);

for jj = m2:-1:1
  a = x>=v2(jj);
  x = x-a*v2(jj);
  b(:,m2-jj+1) = a+1/2*(af>1/v2(jj));
end
