function [VertConn, GridLoc] = results_vertconn(ResultsFile, isComputeVertConn)
% RESULTS_VERTCONN: Compute a vertex adjacency matrix for a source file.
%
% USAGE:  [VertConn, GridLoc] = results_vertconn(ResultsFile, isComputeVertConn=1)
%
% INPUT: 
%    - ResultsFile : Relative path to a source file
% OUTPUT:
%    - VertConn : [NxN] vertex-vertex connectivity matrix (sparse)
%    - GridLoc  : [Nx3] position of the grid points used for estimating the sources

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2015; Martin Cousineau, 2017

% Parse inputs
if (nargin < 2) || isempty(isComputeVertConn)
    isComputeVertConn = 1;
end

% Load headmodel file name
switch (file_gettype(ResultsFile))
    case {'results', 'link'}
        ResultsMat = in_bst_results(ResultsFile, 0, 'HeadModelType', 'SurfaceFile', 'GridLoc', 'GridAtlas');
        HeadModelType = ResultsMat.HeadModelType;
    case 'timefreq'
        ResultsMat = in_bst_timefreq(ResultsFile, 0, 'SurfaceFile', 'GridLoc', 'GridAtlas');
        if ~isempty(ResultsMat.GridAtlas)
            HeadModelType = 'mixed';
        elseif ~isempty(ResultsMat.GridLoc)
            HeadModelType = 'volume';
        else
            HeadModelType = 'surface';
        end
end

% Get grid points and vertex-vertex connectivity matrix
switch lower(HeadModelType)
    case 'surface'
        % Load vertex connectivity
        CortexMat = in_tess_bst(ResultsMat.SurfaceFile);
        VertConn  = CortexMat.VertConn;
        GridLoc   = CortexMat.Vertices;
    case 'volume'
        % Use the positions of the grid points from the headmodel
        GridLoc = ResultsMat.GridLoc;
        % If we explicitely need the vertex connectivity: Compute from the grid points with Delaunay triangulations
        if isComputeVertConn
            VertConn = grid_vertconn(GridLoc);
        else
            VertConn = [];
        end
    case 'mixed'
        % Load surface vertex connectivity
        CortexMat = in_tess_bst(ResultsMat.SurfaceFile);
        % Use the positions of the grid points from the headmodel
        GridLoc = ResultsMat.GridLoc;
        % If we explicitely need the vertex connectivity: Compute from the grid points with Delaunay triangulations
        if isComputeVertConn && ~isempty(ResultsMat.GridAtlas)
            VertConn = sparse(size(GridLoc,1), size(GridLoc,1));
            % Loop on each region
            for i = 1:length(ResultsMat.GridAtlas.Scouts)
                % Get the points of the grid corresponding to this region
                iGrid     = ResultsMat.GridAtlas.Scouts(i).GridRows;
                iVertices = ResultsMat.GridAtlas.Scouts(i).Vertices;
                % Compute the connectivity depending on the region constrains
                switch (ResultsMat.GridAtlas.Scouts(i).Region(2))
                    case 'S',   VertConn(iGrid,iGrid) = CortexMat.VertConn(iVertices,iVertices);
                    case 'V',   VertConn(iGrid,iGrid) = grid_vertconn(GridLoc(iGrid,:));
                end
            end
        else
            VertConn = [];
        end
end


