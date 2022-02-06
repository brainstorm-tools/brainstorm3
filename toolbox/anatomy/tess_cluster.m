function Labels = tess_cluster(VertConn, nClusters, isRandom, VERBOSE)
% TESS_CLUSTER: Spatial clustering of connected cortical nodes of a surface tessellation.
%
% INPUTS: 
%     - VertConn  : A cell-array of vertex connectivity of the nodes (see vertices_connectivity.m)
%     - nClusters : Number of clusters to achieve
%     - isRandom  : if 1, shuffles the indices of the vertices before processing
%     - VERBOSE   : if 1, displays message while processing
%
% OUTPUTS:
%     - Labels : A vector specifying the cluster for each node in the tessellation 

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
% Authors: John C. Mosher, Sylvain Baillet, 2001-2004
%          Francois Tadel, 2008-2012
%          Guiomar Niso, 2014

% Parse inputs
if (nargin < 4) || isempty(VERBOSE)
    VERBOSE = 0;
end
if (nargin < 3) || isempty(isRandom)
    isRandom = 0;
end

% Number of sources per class
nVert = size(VertConn,1);
maxVert = floor(nVert / nClusters); 
% Indices of the sources in every class
ic = cell(1,nClusters); 
% Initialize class index before filling the cells if ic (indexed by class)
iCluster = 1; 
% Select 
if isRandom
    iUnsorted = randperm(nVert); 
else
    iUnsorted = 1:nVert; 
end

if VERBOSE
    disp('Parsing cortical surface in classes...');
end
% Define new patches as long as there are unlabelled nodes
while ~isempty(iUnsorted)
    if VERBOSE
        fprintf('Growing cluster No %d\n',iCluster);
    end
    % Pick-up the seed of the new cluster
    iref = iUnsorted(1);
    ic{iCluster} = iref;
    GROW = 1;

    % Grow all possible conitguous patches regardless of the final number of patches
    % (will fuse them together to achieve maxVert patches later)
    % So just grow until maximum number of nodes is achieved or until there is no unlabelled nodes anymore in the
    % surroundings of current growing patch
    % While the maximum number of nodes in the cluster is not achieved
    while GROW
        % Grow current cluster by looking for their unlabelled neigbors (ie that do not belong to any cluster)
        if iCluster > 1
            % Unlabelled neighbors, on ne garde que les dipoles inclus dans les nouvelles regions
            uneighbors = intersect(tess_scout_swell(ic{iCluster},VertConn),iUnsorted); 
        else
            uneighbors = tess_scout_swell(ic{iCluster},VertConn);
        end
        if ~isempty(uneighbors)
            ic{iCluster} = [ic{iCluster},uneighbors];
            if length(ic{iCluster}) > maxVert
                ic{iCluster} = ic{iCluster}(1:maxVert);
                GROW = 0;
            end
        else
            GROW = 0;
        end
    end
    % Remaining sources not linked to a cluster
    iUnsorted = setdiff(iUnsorted,[ic{:}]);
    iCluster = iCluster + 1;
    if VERBOSE
        fprintf('Number of nodes left to classify %d\n',length(iUnsorted));
    end
end

% If there are too many clusters: Fuse
FUSE = (length(ic) > nClusters);
% Indice du plus petit cortex à fusionner
ppcaf = 1;    
% Remove smaller patches by fusion with largest ones
while FUSE
    sizc = zeros(1,length(ic));
    % Length of clusters
    for k =1:length(ic) 
        sizc(k) = length(ic{k});
    end
    % Start fusion of smallest clusters with largest
    [sizc,Is] = sort(sizc);
    % Take the smallest one
    iCluster = Is(ppcaf); 

    % Get neighbors
    neighbors = tess_scout_swell(ic{iCluster}, VertConn); 
    % Check intersection with other clusters
    int = intersect(neighbors, [ic{(1:length(ic)) ~= iCluster}]); 
    
    % If the class is independent
    if isempty(int)
        if (ppcaf < length(Is))
            ppcaf = ppcaf + 1;
        else
            FUSE = 0;
        end
        continue;
    end

    % Find classes that intersect with neighbors of this cluster
    for k = 1:length(int)
        for indice = 1 : length(ic)
            if find(ic{indice} == int(k))
                ic_class(k) = indice;
            end
        end
    end

    % Reassign nodes from cluster ic{iCluster} to the iCluster which has the most intersecting nodes ic{iCluster}'s neighbors
    ic_class = sort(ic_class);
    TMP = unique(ic_class);
    [tmp,k] = intersect(ic_class,TMP);
    % k contains the number of occurrence of each intersecting class
    k = [k(1),diff(k(:)')]; 
    % Find the largest intersection
    [tmp, class_max] = max(k);
    % Corresponding class number
    class_max = TMP(class_max);

    % Then concatenates the former class with cluster class_max
    ic{class_max} = [ic{class_max}, ic{iCluster}];
    % Reorganize remaining classes
    ic = ic((1:length(ic)) ~= iCluster);

    % Still too many classes
    FUSE = (length(ic) > nClusters);
    if VERBOSE
        fprintf('Number of clusters left to fuse: %d\n', length(ic)-nClusters)
    end
end
% On remet à 0 le vecteur Labels
taille = size(VertConn);
for indice = 1:taille(1)
    Labels(taille) = 0;
end
% Assign class code to each node
for iCluster = 1:nClusters 
    Labels(ic{iCluster}) = iCluster;
end
taille = size(ic{nClusters});
% Si la region nClusters ne contient pas de dipoles, on recupere le nombre de regions
if ~taille(2)
    indice = 1;
    while ic{indice}
        indice = indice+1;
    end
end



