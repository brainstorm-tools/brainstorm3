function Y = bst_cluster_threshold(X, thd, vc, dim)
% BST_CLUSTER_THRESHOLD: Keep only data which are clustered
%
% USAGE:  Y = cluster_threshold(X, thd, vc/adj, dim);
%
% DESCRIPTION:
%       Finds clusters along dimension dim in matrix X whose mass/area is
%       bigger than (or equal to) thd:
%               for each cluster clu{i}=[ ... ],  sum(X([clu{i}])) >= thd;
%       Adjacency/connectivity must be specified in vc 
%           * use vc=1 for continous data (e.g. time samples)
%           * use a conectivity matrix or cell array of neighbors otherwise
%       By default [dim] is the first non singleton dimension of X
%
%       Outputs Y (of the same size as X) such that Y=X where the clusters
%       match the criterion, Y=0 elsewhere.

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
% Authors: K. N'Diaye (kndiaye01<at>yahoo.fr), 2006

if nargin<4
    [dim,dim]=min(find(size(X)>1));
    if isempty(dim)
        dim=1;
    end
end
if nargin<5
    verbose=1;
end

sX=size(X);
ndX=ndims(X);
Y=permute(X, [dim setdiff(1:ndX,dim)]);
if iscell(vc)
    warning(sprintf('%s\n%s', '''vc'' is provided as a vertices_connectivity cell list.' , ...
        'It will be converted to an adjacency matrix for faster computation.'));
    vc=vertconn2adjacency(vc);
    fprintf('Adjacency matrix now computed\n');
end
    
% if verbose
%     htime=timebar('Finding clusters');    
% end
niter=(prod(sX)/sX(dim));
for i=1:niter
    [clu,sclu] = bst_clustering(Y(:,i),vc);
    y=Y(:,i);    
    Y(:,i)=0;
    Y([clu{sclu>=thd}],i)=y([clu{sclu>=thd}],1);
%     if verbose
%         try,timebar(htime,i/niter);end
%     end
end
% if verbose
%     try;close(htime);end
% end
Y=ipermute(Y, [dim setdiff(1:ndX,dim)]);

