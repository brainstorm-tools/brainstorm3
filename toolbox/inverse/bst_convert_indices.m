function [iSourceRows, iRegionScouts, iVertices] = bst_convert_indices(iVertices, nComponents, GridAtlas, isSurfaceInd)
% BST_CONVERT_INDICES: Convert scout indices (in GridLoc or Vertices matrix) to indices in ImageGridAmp/ImagingKernel
%
% USAGE:  [iSourceRows, iRegionScouts, iVertices] = bst_convert_indices(iVertices, nComponents, GridAtlas, isSurfaceInd)
%
% INPUT: 
%    - iVertices    : Array of vertex indices of the source space, to reference to rows in Results.GridLoc (volume) or Surface.Vertices (surface)
%    - nComponents  : Number of entries per vertex in SourceValues (1,2,3)
%                     If 0, the number varies, the properties of each region are defined in input GridAtlas
%    - GridAtlas    : Set of scouts that defines the properties of the source space regions, when nComponents=0
%                     GridAtlas.Scouts(i).Region(2) is the source type (V=volume, S=surface, D=dba, X=exclude)
%                     GridAtlas.Scouts(i).Region(3) is the orientation constrain (U=unconstrained, C=contrained, L=loose)
%    - isSurfaceInd : If 1, the indices iVertices are referring to Surface.Vertices, and require a conversion in the case of mixed models
%                     If 0, the indices iVertices are referring to Results.GridLoc
%
% OUTPUT: 
%    - iSourceRows   : Array of vertex indices of the source space, to reference to rows in Results.GridLoc (volume)
%    - iRegionScouts : List of the scout indices in GridAtlas that are involved in the list of vertices iGridLoc
%    - iVertices     : For mixed source models, grid indices corresponding to input list (if surface vertices provided, some may not match any grid points).

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
% Authors: Francois Tadel, 2014

% Check inputs
if (nargin ~= 4) || isempty(iVertices) || isempty(nComponents) || ((nComponents == 0) && isempty(GridAtlas))
	error('Invalid call');
end
iRegionScouts = [];

% Make sure iVertices is a row vector
iVertices = iVertices(:)';
% Get row numbers corresponding to the selected vertices
switch (nComponents)
    case 0
        % Convert indices from Surface.Vertices to Results.GridLoc
        if isSurfaceInd
            % Remove the vertices that are outside the list of vertices in Vert2Grid
            iVertices(iVertices > size(GridAtlas.Vert2Grid,2)) = [];
            % Surface.Vertices => Results.GridLoc
            iVertices = find(any(GridAtlas.Vert2Grid(:,iVertices), 2))';
        end
        % Get indices in the ImageGridAmp/ImagingKernel matrix
        iSourceRows = find(any(GridAtlas.Grid2Source(:,iVertices), 2))';
        % Find over which regions this vertex selection spans
        if (nargout >= 2)
            iRegionScouts = find(~cellfun(@(c)isempty(intersect(c,iVertices)), {GridAtlas.Scouts.GridRows}));
        end
    case 1
        iSourceRows = sort(iVertices);
    case 2
        iSourceRows = sort([2*iVertices-1, 2*iVertices]);
    case 3
        iSourceRows = sort([3*iVertices-2, 3*iVertices-1, 3*iVertices]);
end




