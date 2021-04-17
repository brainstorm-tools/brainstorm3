function Gain = bst_gain_orient(Gain, GridOrient, GridAtlas)
% BST_GAIN_ORIENT: Constrain source orientation on a leadfield matrix
%
% USAGE:  Gain = bst_gain_orient(Gain, GridOrient, GridAtlas)
%
% INPUT: 
%     - Gain       : [nChannels,3*nSources] leadfield matrix
%     - GridOrient : [nSources,3] orientation for each source of the Gain matrix
% OUTPUT:
%     - Gain : [nChannels,nSources] leadfield matrix with fixed orientations

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
% Authors: Francois Tadel, 2009-2014

% Parse inputs
if (nargin < 3) || isempty(GridAtlas)
    GridAtlas = [];
end

% Regular case: 3 orientations => 1 orientation
if isempty(GridAtlas)
    % Create a sparse block diagonal matrix for orientations
    GridOrient = blk_diag(GridOrient', 1);
    % Apply the orientation to the Gain matrix
    Gain = Gain * GridOrient;
% Mixed head model: mixed unconstrained and constrained regions
else
    GainBlocks = {};
    % Loop on all the regions
    for iScout = 1:length(GridAtlas.Scouts)
        % Get the vertices for this scouts
        iGrid = GridAtlas.Scouts(iScout).GridRows;
        iGridGain = sort([3*iGrid-2, 3*iGrid-1, 3*iGrid]);
        % If no vertices to read from this region: skip
        if isempty(iGrid)
            continue;
        end
        % Get correpsonding row indices based on the type of region (constrained or unconstrained)
        switch (GridAtlas.Scouts(iScout).Region(3))
            case 'C'
                % Create a sparse block diagonal matrix for orientations
                GridOrientBlock = blk_diag(GridOrient(iGrid,:)', 1);
                % Apply the orientation to the Gain matrix
                GainBlocks{end+1} = Gain(:,iGridGain) * GridOrientBlock;
            case {'U','L'}
                GainBlocks{end+1} = Gain(:,iGridGain);
            otherwise
                error(['Invalid region "' GridAtlas.Scouts(iScout).Region '"']);
        end
    end
    % Concatenate the blocks
    Gain = cat(2, GainBlocks{:});
end

