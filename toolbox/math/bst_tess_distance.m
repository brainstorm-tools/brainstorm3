function Dist = bst_tess_distance(SurfaceMat, VerticesA, VerticesB, metric)
% bst_tess_distance: Distance computation between two set of vertices (A and B)
%
% USAGE:  W = bst_tess_distance(SurfaceMat, VerticesA, VerticesB, metric)
%
% INPUT:
%    - SurfaceMat : Cortical surface matrix
%    - VerticesA  : Vertices from region A
%    - VerticesB  : Vertices from region B
%    - Method     : Metric used to compute the distance {'euclidean', 'geodesic_edge', 'geodesic_dist'}
% OUPUT:
%    - Dist: distance matrix. D(i,j) is the distance between vertex VerticesA(i), and
%    VerticesB(j). 

%
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
% Authors: Edouard Delaire 2023

    Vertices   = SurfaceMat.Vertices;
    
    if strcmp(metric,'euclidean')
        Dist = zeros(length(VerticesA),length(VerticesB)); 
        x = Vertices(VerticesA,:)';
        for i = 1:length(VerticesB)
            y = Vertices(VerticesB(i),:)';
            Dist(:,i) = sum((x-y).^2).^0.5; % m
        end

    elseif ~isempty(strfind(metric,'geodesic'))
        if strcmp(metric,'geodesic_dist')
            [vi,vj] = find(SurfaceMat.VertConn);
            nv      = size(Vertices,1);
            x       = Vertices(vi,:)';
            y       = Vertices(vj,:)';
            D = sparse(vi, vj, sum((x-y).^2).^0.5, nv, nv); % m
        else
            D = SurfaceMat.VertConn;                        % edges
        end

        G    = graph(D);
        Dist = distances(G, VerticesA, VerticesB);
    end 
end
