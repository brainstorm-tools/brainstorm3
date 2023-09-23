function Dist = bst_tess_distance(SurfaceMat, VerticesA, VerticesB, metric)
% bst_tess_distance: For every vertex B, return the minimum distance to the vertices A using
% either the euclidean metric (metric = euclidean), or geodesic mesuring the distance either as
% number of edge (metric = geodesic_edge) or path lenght (geodesic_length)
% When using the geodesic distance, if two nodes are not
% connected, the distance is infinite. 
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
        Dist = zeros(length(VerticesB),1); 

        y = Vertices(VerticesA,:)'*1000; 
        for i = 1:length(VerticesB)
            x = Vertices(VerticesB(i),:)'*1000; 
            Dist(i)=min( sum((y-x).^2).^0.5); %euclidean distance calculation
        end

    elseif contains(metric,'geodesic') 

        [vi,vj] = find(SurfaceMat.VertConn);

        if strcmp(metric,'geodesic_length')
            nv = size(Vertices,1);
            x  = Vertices(vi,:)' * 1000;
            y  = Vertices(vj,:)' * 1000;

            D  = sparse(vi, vj, sum((x-y).^2).^0.5, nv, nv);
        else
            D  = SurfaceMat.VertConn;
        end

        G    = graph(D);
        Dist = min(distances(G, VerticesA,VerticesB))';

    end 
end
