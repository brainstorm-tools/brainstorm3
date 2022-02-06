function [hout,cout] = tricontour(p,t,Hn,N,hAxes)
% Contouring for functions defined on triangular meshes
%
%   TRICONTOUR(p,t,F,N)
%
% Draws contours of the surface F, where F is defined on the triangulation
% [p,t]. These inputs define the xy co-ordinates of the points and their
% connectivity:
%
%   P = [x1,y1; x2,y2; etc],            - xy co-ordinates of nodes in the 
%                                         triangulation
%   T = [n11,n12,n13; n21,n23,n23; etc] - node numbers in each triangle
%
% The last input N defines the contouring levels. There are several
% options:
%
%   N scalar - N number of equally spaced contours will be drawn
%   N vector - Draws contours at the levels specified in N
%
% A special call with a two element N where both elements are equal draws a
% single contour at that level.
%
%   [C,H] = TRICONTOUR(...)
%
% This syntax can be used to pass the contour matrix C and the contour
% handels H to clabel by adding clabel(c,h) or clabel(c) after the call to
% TRICONTOUR.
%
% TRICONTOUR can also return 3D contours similar to CONTOUR3 by adding
% view(3) after the call to TRICONTOUR.
%
% Type "contourdemo" for some examples.
%
% See also, CONTOUR, CLABEL

% This function does NOT interpolate back onto a Cartesian grid, but
% instead uses the triangulation directly.
%
% If your going to use this inside a loop with the same [p,t] a good
% modification is to make the connectivity "mkcon" once outside the loop
% because usually about 50% of the time is spent in "mkcon".
%
% Darren Engwirda - 2005 (d_engwirda@hotmail.com)
% Updated 15/05/2006

% Some display adaptations by Francois Tadel, 2009-2012

% I/O checking
if (nargin < 4)
    error('Incorrect number of inputs')
end
if nargout>2
    error('Incorrect number of outputs')
end

% Error checking
if (size(p,2) ~= 2) && (size(p,2) ~= 3)
    if (size(p,1) == 2) || (size(p,1) == 3)
        p = p';
    else
        error('Incorrect input dimensions for Vertices');
    end
end
if (size(p,2) == 3)
    ZValues = p(:,3);
    p = p(:,1:2);
else
    ZValues = [];
end
if (size(t,2)~=3)
    if (size(t,1) == 3)
        t = t';
    else
        error('Incorrect input dimensions for Faces');
    end
end
if (size(Hn,2) ~= 1)
    if (size(Hn,1) == 1)
        Hn = Hn';
    else
        error('Incorrect input dimensions for Values');
    end
end
if size(p,1)~=size(Hn,1)
    error('F and p must be the same length')
end
if (max(t(:))>size(p,1)) || (min(t(:))<=0)
    error('t is not a valid triangulation of p')
end
if (size(N,1)>1) && (size(N,2)>1)
    error('N cannot be a matrix')
end

% Make mesh connectivity data structures (edge based pointers)
[e,eINt,e2t] = mkcon(p,t);

numt = size(t,1);       % Num triangles
nume = size(e,1);       % Num edges

% Get axes 
CMap = get(get(hAxes, 'Parent'), 'Colormap');
CLim = get(hAxes, 'CLim');


%==========================================================================
%                Quadratic interpolation to centroids
%==========================================================================

% Nodes
t1 = t(:,1); t2 = t(:,2); t3 = t(:,3);

% FORM FEM GRADIENTS
% Evaluate centroidal gradients (piecewise-linear interpolants)
x23 = p(t2,1)-p(t3,1);  y23 = p(t2,2)-p(t3,2);
x21 = p(t2,1)-p(t1,1);  y21 = p(t2,2)-p(t1,2);

% Centroidal values
Htx = (y23.*Hn(t1) + (y21-y23).*Hn(t2) - y21.*Hn(t3)) ./ (x23.*y21-x21.*y23);
Hty = (x23.*Hn(t1) + (x21-x23).*Hn(t2) - x21.*Hn(t3)) ./ (y23.*x21-y21.*x23);

% Form nodal gradients.
% Take the average of the neighbouring centroidal values
Hnx = 0*Hn; Hny = Hnx; count = Hnx;
for k = 1:numt
    % Nodes
    n1 = t1(k); n2 = t2(k); n3 = t3(k);
    % Current values
    Hx = Htx(k); Hy = Hty(k);
    % Average to n1
    Hnx(n1)   = Hnx(n1)+Hx;
    Hny(n1)   = Hny(n1)+Hy;
    count(n1) = count(n1)+1;
    % Average to n2
    Hnx(n2)   = Hnx(n2)+Hx;
    Hny(n2)   = Hny(n2)+Hy;
    count(n2) = count(n2)+1;
    % Average to n3
    Hnx(n3)   = Hnx(n3)+Hx;
    Hny(n3)   = Hny(n3)+Hy;
    count(n3) = count(n3)+1;
end
iCountZero = (count == 0);
Hnx(~iCountZero) = Hnx(~iCountZero)./count(~iCountZero);
Hny(~iCountZero) = Hny(~iCountZero)./count(~iCountZero);
Hnx(iCountZero) = Inf;
Hny(iCountZero) = Inf;
% Hnx = Hnx./count;
% Hny = Hny./count;

% Centroids [x,y]
pt = (p(t1,:)+p(t2,:)+p(t3,:))/3;

% Take unweighted average of the linear extrapolation from nodes to centroids
Ht = ( Hn(t1) + (pt(:,1)-p(t1,1)).*Hnx(t1) + (pt(:,2)-p(t1,2)).*Hny(t1) + ...
       Hn(t2) + (pt(:,1)-p(t2,1)).*Hnx(t2) + (pt(:,2)-p(t2,2)).*Hny(t2) + ...
       Hn(t3) + (pt(:,1)-p(t3,1)).*Hnx(t3) + (pt(:,2)-p(t3,2)).*Hny(t3) )/3;



% DEAL WITH CONTOURING LEVELS
if length(N)==1
    lev = linspace(max(Ht),min(Ht),N+1);
    num = N;
else
    if (length(N)==2) && (N(1)==N(2))
        lev = N(1);
        num = 1;
    else
        lev = sort(N);
        num = length(N);
        lev = lev(num:-1:1);
    end
end

% MAIN LOOP
c   = [];
h   = [];
in  = false(numt,1);
vec = 1:numt;
old = in;

for v = 1:num       % Loop over contouring levels
    
    % Find centroid values >= current level
    i     = vec(Ht>=lev(v));
    i     = i(~old(i));         % Don't need to check triangles from higher levels
    in(i) = true;
    
    % Locate boundary edges in group
    bnd  = [i; i; i];       % Just to alloc
    next = 1;
    for k = 1:length(i)
        ct    = i(k);
        count = 0;
        for q = 1:3     % Loop through edges in ct
            ce = eINt(ct,q);
            if ~in(e2t(ce,1)) || ((e2t(ce,2)>0)&&~in(e2t(ce,2)))    
                bnd(next) = ce;     % Found bnd edge
                next      = next+1;
            else
                count = count+1;    % Count number of non-bnd edges in ct
            end
        end
        if count==3                 % If 3 non-bnd edges ct must be in middle of group
            old(ct) = true;         % & doesn't need to be checked for the next level
        end
    end
    numb = next-1; bnd(next:end) = [];
    
    % Skip to next lev if empty
    if numb==0
        continue
    end
    
    % Place nodes approximately on contours by interpolating across bnd
    % edges    
    t1  = e2t(bnd,1);
    t2  = e2t(bnd,2);
    ok  = t2>0;
    
    % Get two points for interpolation. Always use t1 centroid and 
    % use t2 centroid for internal edges and bnd midpoint for boundary 
    % edges
    
    % 1st point is always t1 centroid
    H1 = Ht(t1);                                                % Centroid value
    p1 = ( p(t(t1,1),:)+p(t(t1,2),:)+p(t(t1,3),:) )/3;          % Centroid [x,y]
    
    % 2nd point is either t2 centroid or bnd edge midpoint
    i1        = t2(ok);                                         % Temp indexing
    i2        = bnd(~ok);
    H2        = H1;
    H2(ok)    = Ht(i1);                                         % Centroid values internally
    H2(~ok)   = ( Hn(e(i2,1))+Hn(e(i2,2)) )/2;                  % Edge values at boundary
    p2        = p1;
    p2(ok,:)  = ( p(t(i1,1),:)+p(t(i1,2),:)+p(t(i1,3),:) )/3;   % Centroid [x,y] internally
    p2(~ok,:) = ( p(e(i2,1),:)+p(e(i2,2),:) )/2;                % Edge [x,y] at boundary
    
    % Linear interpolation
    r     = (lev(v)-H1)./(H2-H1);
    penew = p1 + [r,r].*(p2-p1);
    
    % Do a temp connection between adjusted node & endpoint nodes in
    % ce so that the connectivity between neighbouring adjusted nodes
    % can be determined
    vecb    = (1:numb)';
    m       = 2*vecb-1;
    c1      = 0*m;
    c2      = 0*m;
    c1(m)   = e(bnd,1);
    c1(m+1) = e(bnd,2);
    c2(m)   = vecb;
    c2(m+1) = vecb;
    
    % Sort connectivity to place connected edges in sucessive rows
    [c1,i] = sort(c1); c2 = c2(i);
    
    % Connect adjacent adjusted nodes
    k    = 1;
    next = 1;
    while k<(2*numb)
        if c1(k)==c1(k+1)
            c1(next) = c2(k);
            c2(next) = c2(k+1);
            next     = next+1;
            k        = k+2;         % Skip over connected edge
        else
            k = k+1;                % Node has only 1 connection - will be picked up above
        end
    end
    ncc          = next-1; 
    c1(next:end) = []; 
    c2(next:end) = [];
    
    
    % Plot the contours
    % If an output is required, extra sorting of the
    % contours is necessary for CLABEL to work.   
    if (nargout >= 2)
        
        % Form connectivity for the contour, connecting 
        % its edges (rows in cc) with its vertices.
        ndx = repmat(1,nume,1);
        n2e = 0*penew;
        for k = 1:ncc
            % Vertices
            n1 = c1(k); n2 = c2(k);
            % Connectivity
            n2e(n1,ndx(n1)) = k; ndx(n1) = ndx(n1)+1;
            n2e(n2,ndx(n2)) = k; ndx(n2) = ndx(n2)+1;
        end
        bndn = n2e(:,2)==0;         % Boundary nodes
        bnde = bndn(c1)|bndn(c2);   % Boundary edges
        
        % Alloc some space
        tmpv = repmat(0,1,ncc);
        
        % Loop through the points at the current contour level (lev(v))
        % Try to assemble the CS data structure introduced in "contours.m"
        % so that clabel will work. Assemble CS by "walking" around each 
        % subcontour segment contiguously.
        ce    = 1;
        start = ce;
        next  = 2;
        cn    = c2(1);
        flag  = false(ncc,1);        
        x     = tmpv; x(1) = penew(c1(ce),1);
        y     = tmpv; y(1) = penew(c1(ce),2);
        for k = 1:ncc
            
            % Checked this edge
            flag(ce) = true;
            
            % Add vertices to patch data
            x(next) = penew(cn,1);
            y(next) = penew(cn,2);
            next    = next+1;
            
            % Find edge (that is not ce) joined to cn
            if ce==n2e(cn,1)
                ce = n2e(cn,2);
            else
                ce = n2e(cn,1);
            end
            
            % Check the new edge
            if (ce==0)||(ce==start)||(flag(ce))     
               
                % Plot current subcontour as a patch and save handles
                x   = x(1:next-1);
                y   = y(1:next-1);
                z   = repmat(lev(v),1,next);
                h   = [h; patch('Xdata',[x,NaN], ...
                                'Ydata',[y,NaN], ...
                                'Zdata',z, ...
                                'Cdata',z, ...
                                'facecolor','none', ...
                                'edgecolor',[1 1 1], ...
                                'Parent', hAxes)]; 
                hold on      
                
                % Update the CS data structure as per "contours.m"
                % so that clabel works
                c = horzcat(c,[lev(v), x; next-1, y]);
                
                if all(flag)    % No more points at lev(v)
                    break
                else            % More points, but need to start a new subcontour
                    
                    % Find the unflagged edges
                    edges = find(~flag);
                    ce    = edges(1);
                    % Try to select a boundary edge so that we are 
                    % not repeatedly running into the boundary
                    for i = 1:length(edges)
                        if bnde(edges(i))
                            ce = edges(i); break
                        end
                    end
                    % Reset counters
                    start = ce;
                    next  = 2;
                    % Get the non bnd node in ce
                    if bndn(c2(ce))
                        cn = c1(ce);
                        % New patch vectors
                        x = tmpv; x(1) = penew(c2(ce),1);
                        y = tmpv; y(1) = penew(c2(ce),2);
                    else
                        cn = c2(ce);
                        % New patch vectors
                        x = tmpv; x(1) = penew(c1(ce),1);
                        y = tmpv; y(1) = penew(c1(ce),2);
                    end                    
                    
                end
            
            else                            
                % Find node (that is not cn) in ce
                if cn==c1(ce)
                    cn = c2(ce);
                else
                    cn = c1(ce);
                end
            end
            
        end
        
    else        % Just plot the contours as is, this is faster...
        
        %z = repmat(lev(v),2,ncc);

        % Get color in colormap
        iColor = round( ((size(CMap,1)-1)/(CLim(2)-CLim(1))) * (lev(v) - CLim(1))) + 1;
        iColor = bst_saturate(iColor, [1 size(CMap,1)]);
        Color  = bst_saturate(CMap(iColor, :) + 0.1, [0 1]);
        
        h = [h, ...
        patch('Xdata',[penew(c1,1),penew(c2,1)]', ...
              'Ydata',[penew(c1,2),penew(c2,2)]', ...
              ...'Zdata',z, ...
              'Zdata', 1e-10*ones(2, length(c1)), ...
              'facecolor', 'none', ...
              'edgecolor', Color , ...
              ... 'edgecolor',[1 1 1], ...
              ... 'edgealpha', .3, ...
              'Tag', 'tricontourPatch', ...
              'Parent', hAxes)]; 
         % ZValues
        hold on
        
    end
    
end

% Assign outputs if needed
if nargout >= 1
    hout = h;
end
if nargout >= 2
    cout = c;
end

return


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [e,eINt,e2t] = mkcon(p,t)

numt = size(t,1);
vect = 1:numt;

% DETERMINE UNIQUE EDGES IN MESH
 
e       = [t(:,[1,2]); t(:,[2,3]); t(:,[3,1])];             % Edges - not unique
vec     = (1:size(e,1))';                                   % List of edge numbers
[e,j,j] = unique(sort(e,2),'rows');                         % Unique edges
vec     = vec(j);                                           % Unique edge numbers
eINt    = [vec(vect), vec(vect+numt), vec(vect+2*numt)];    % Unique edges in each triangle

% DETERMINE EDGE TO TRIANGLE CONNECTIVITY

% Each row has two entries corresponding to the triangle numbers
% associated with each edge. Boundary edges have one entry = 0.
nume = size(e,1);
e2t  = repmat(0,nume,2);
ndx  = repmat(1,nume,1);
for k = 1:numt
    % Edge in kth triangle
    e1 = eINt(k,1); e2 = eINt(k,2); e3 = eINt(k,3);
    % Edge 1
    e2t(e1,ndx(e1)) = k; ndx(e1) = ndx(e1)+1;
    % Edge 2
    e2t(e2,ndx(e2)) = k; ndx(e2) = ndx(e2)+1;
    % Edge 3
    e2t(e3,ndx(e3)) = k; ndx(e3) = ndx(e3)+1;
end

return
