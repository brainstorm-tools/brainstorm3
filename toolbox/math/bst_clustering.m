function [clu,sz,mc,v2c] = bst_clustering(X, vc)
% BST_CLUSTERING: Find clusters of data (continuous or on a mesh)
%
% USAGE:  [clu,sz,mc] = clustering(X,vc)
%
% DESCRIPTION:
%    Find clusters of non-zeros values in data vector X according to the
%    connectivity defined by 'vc'
%
% INPUTS:
%    - X  : N-by-1 array of zeros and non-zeros data
%    - vc : Connectivity pattern, can be:
%            [1] -> continuous data (e.g. time samples)
%            vertice_connectivity (cell list)
%            adjacency matrix
%
% OUPUTS:
%    - clu     : Clusters found ss a cell list of indices in X, ordered in decreasing size
%    - sz      : size of each cluster
%    - mc      : mass of each cluster, mc(i)=sum(X(clu{i}))
%    - vtx2clu : N-by-1 array indicating the cluster to which belongs the vertex
%
% EXAMPLE:
%     [clu,sz]=clustering(ImageGridAmp(:,1),vertconn);

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
% Authors: K. N'Diaye (kndiaye01<at>yahoo.fr), 2006

if numel(X)>max(size(X))
    error('X should be a vector, not a matrix')
end

X=X(:);
n=size(X,1);

if isequal(vc,1) || isempty(vc)
    % The '~~' avoids warnings MATLAB:conversionToLogical
    p=logical(~~X);
    dip=diff(cumsum(p),2);
    dp1=find(dip==1)+2;
    dp2=find(dip==-1)+2;
    if isequal(p(1),1)
        % check for siding values
        dp1=[1; dp1];
        if isequal(p(2),0)
            dp2=[2; dp2];
        end
    elseif isequal(p(2),1)
        dp1=[2; dp1];
    end
    if isequal(p(end),1)
        dp2=[dp2; n];
    end
    clu=cell(1,length(dp1));
    sz=dp2-dp1;
    mc=zeros(1,length(dp1));
    for i=1:length(dp1)
        clu{i}=dp1(i):(dp2(i)-1);
        if nargout>2
            mc(i)=sum(X(dp1(i):(dp2(i)-1)));
        end
    end

else
    if size(vc,1) ~= n
        error('Connectivity and number of values in X don''t match')
    end

    A = vc;
    X = double(X);    
    % NaN values
    X(isnan(X)) = 0;

    A = A | speye(size(A));
    lX = (X > 0);
    A = A(lX,lX);
    
    % Compute clusters using matlab's dmperm
    [p,ignore,r,s] = dmperm(A);
    sz = diff(r) .* (diff(r) & diff(s));
    idx = find(sz);
    [ign,idx2] = sort(-sz(idx));
    sz = sz(idx(idx2));
    
    % Initialize returned variables
    clu = cell(1,length(idx2));
    if nargout>2
        mc=zeros(1,length(idx2));
    end
    if nargout > 3 
        v2c=zeros(n,1);
    end
    % Loop on each cluster
    iX = find(lX)';
    for i=1:length(idx2)
        clu{i} = iX(p(r(idx(idx2(i))):(r(idx(idx2(i))+1)-1)));
        if nargout>2
            mc(i)=sum(X(clu{i}));
        end
        if nargout > 3 
            v2c(iX(p(r(idx(idx2(i))):(r(idx(idx2(i))+1)-1)))) = i;
        end
    end    
end
