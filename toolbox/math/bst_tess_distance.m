function Dist = bst_tess_distance(SurfaceMat, VerticesA, VerticesB, metric, keepAll)
% bst_tess_distance: Distance computation between two set of vertices (A,
% and B)
%
% USAGE:  W = bst_tess_distance(SurfaceMat, VerticesA, VerticesB, metric, keepAll)
%
% INPUT:
%    - Vertices : SurfaceMat: cortical surface matrix
%    - VerticesA    : Vertices from region A
%    - VerticesB : Vertices from region A
%    - Method   : Metric used to compute the distance {'euclidean', 'geodesic_edge', 'geodesic_length'}
%    - keepAll  : if false, for each vertex in region B, return the minimum
%    distance to region A
% OUPUT:
%    - Dist: distance matrix. D(i,j) is the distance between vertex VerticesA(i), and
%    VerticesB(j). If keepAll = 0, Dist is a nVertexB x 1 vector where
%    Dist(i) is the minimum distance between VerticesB(i) and the region A.
%    
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

    Vertices = SurfaceMat.Vertices;
    if strcmp(metric,'euclidean')
        Dist = zeros(length(VerticesA),length(VerticesB)); 

        x = Vertices(VerticesA,:)'*1000; 
        for i = 1:length(VerticesB)
            y = Vertices(VerticesB(i),:)'*1000; 
            Dist(:,i)=sum((x-y).^2).^0.5; 
        end

    elseif contains(metric,'geodesic') 
        if strcmp(metric,'geodesic_length')
            [vi,vj] = find(SurfaceMat.VertConn);
            nv      = size(Vertices,1);
            x       = Vertices(vi,:)' * 1000;
            y       = Vertices(vj,:)' * 1000;

            D  = sparse(vi, vj, sum((x-y).^2).^0.5, nv, nv);
        else
            D  = SurfaceMat.VertConn;
        end

        G    = graph(D);
        Dist = distances(G, VerticesA,VerticesB);
    end 

    if ~keepAll
        Dist = min(Dist)';
    end
end
