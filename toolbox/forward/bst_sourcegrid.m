function GridLoc = bst_sourcegrid(Options, CortexFile, sInner, sEnvelope)
% BST_SOURCEGRID: 3D adaptative gridding of the volume inside a cortex envelope.
%
% USAGE:  GridLoc = bst_sourcegrid(Options, CortexFile)
%         GridLoc = bst_sourcegrid(Options, CortexFile, sInner, sEnvelope)
% 
% INPUTS: 
%    - Options    : Options structure
%    - CortexFile : Full path to a cortex tesselation file
%    - sInner     : Loaded inner skull surface
%    - sEnvelope  : Convex envelope to use as the outermost layer of the grid
%
% OUTPUTS:
%    - GridLoc    : [Nx3] double matrix representing the volume grid.

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
% Authors: Francois Tadel, 2010-2015

% ===== PARSE INPUTS =====
if (nargin <= 2)
    % Create an envelope of the cortex surface
    [sEnvelope, sCortex] = tess_envelope(CortexFile, 'convhull', Options.nVerticesInit, .001, []);
    if isempty(sEnvelope)
        return;
    end
    sInner = [];
end
if (nargin < 1) || isempty(Options)
    Options.Method        = 'adaptive';
    Options.nLayers       = 17;    % Adaptive option
    Options.Reduction     = 3;     % Adaptive option
    Options.nVerticesInit = 4000;  % Adaptive option
    Options.Resolution    = 0.005; % Isotropic option
end

% ===== SAMPLE VOLUME =====
switch lower(Options.Method)
    case 'adaptive'
        % Build scales for each layer
        scaleLayers = linspace(1, 0, Options.nLayers+1);
        scaleLayers = scaleLayers(1:end-1);
        % Build factor of reducepatch for each layer
        reduceLayers = linspace(1, 0, Options.nLayers+1);
        reduceLayers = reduceLayers(1:end-1) .^ Options.Reduction;
        % Sample volume
        GridLoc = SampleVolume(sEnvelope.Vertices, sEnvelope.Faces, scaleLayers, reduceLayers);

    case {'isotropic', 'isohead'}
        % Create a regular grid
        [X,Y,Z] = meshgrid(...
            min(sEnvelope.Vertices(:,1)) : Options.Resolution : (max(sEnvelope.Vertices(:,1))+Options.Resolution), ...
            min(sEnvelope.Vertices(:,2)) : Options.Resolution : (max(sEnvelope.Vertices(:,2))+Options.Resolution), ...
            min(sEnvelope.Vertices(:,3)) : Options.Resolution : (max(sEnvelope.Vertices(:,3))+Options.Resolution));
        GridLoc = [X(:), Y(:), Z(:)];
end

% ===== REMOVE POINTS OUTSIDE OF THE MRI =====
% Get brainmask
[brainmask, sMri] = bst_memory('GetSurfaceMask', CortexFile);
% Convert coordinates: SCS->Voxels
GridLocMri = round(cs_convert(sMri, 'scs', 'voxel', GridLoc));
% Find all the points that are not inside the MRI volume
isOutsideMri = any(GridLocMri < 1,2) | ...
              (GridLocMri(:,1) > size(brainmask,1)) | ...
              (GridLocMri(:,2) > size(brainmask,2)) | ...
              (GridLocMri(:,3) > size(brainmask,3));
% Remove the points that are outside of the MRI
GridLoc(isOutsideMri,:) = [];
GridLocMri(isOutsideMri,:) = [];
% Convert in indices
ind = sub2ind(size(brainmask), GridLocMri(:,1), GridLocMri(:,2), GridLocMri(:,3));
% What is outside of the brain ?
isOutsideBrain = (brainmask(ind) == 0);
% Remove those points
GridLoc(isOutsideBrain,:) = [];

% ===== REMOVE POINTS OUTSIDE OF THE INNER SKULL =====
if ~isempty(sInner) && ismember(lower(Options.Method), {'isotropic', 'adaptive'})
    % Find points outside of the inner skull
    iOutside = find(~inpolyhd(GridLoc, sInner.Vertices, sInner.Faces));
    % Remove the points
    if ~isempty(iOutside)
        GridLoc(iOutside,:) = [];
    end

    % % Show removed points
    % if ~isempty(iOutside)
    %     % Show surface + removed points
    %     view_surface_matrix(sCortex.Vertices, sCortex.Faces, .4, [.6 .6 .6]);
    %     line(GridLoc(iOutside,1), GridLoc(iOutside,2), GridLoc(iOutside,3), 'LineStyle', 'none', ...
    %                 'MarkerFaceColor', [1 0 0], 'MarkerEdgeColor', [1 1 1], 'MarkerSize', 6, 'Marker', 'o');
    %     % Show surface + grid points
    %     view_surface_matrix(sCortex.Vertices, sCortex.Faces, .3, [.6 .6 .6]);
    %     line(GridLoc(~iOutside,1), GridLoc(~iOutside,2), GridLoc(~iOutside,3), 'LineStyle', 'none', ...
    %                 'MarkerFaceColor', [0 1 0], 'MarkerSize', 2, 'Marker', 'o');
    % end
end


end



%% ===== SAMPLE VOLUME =====
function GridLoc = SampleVolume(Vertices, Faces, scaleLayers, reduceLayers)
    % Check matrices orientation
    if (size(Vertices, 2) ~= 3) || (size(Faces, 2) ~= 3)
        error('Faces and Vertices must have 3 columns (X,Y,Z).');
    end
    GridLoc = [];

    % Get center of the best fitting sphere
    center = bst_bfs(Vertices)';
    % Center vertices on it
    Vertices = bst_bsxfun(@minus, Vertices, center);

    % Loop on each layer
    for i = 1:length(scaleLayers)
        LayerVertices = Vertices;
        LayerFaces = Faces;
        % Scale layer
        LayerVertices = scaleLayers(i) * LayerVertices;
        % Downsample layer
        if (reduceLayers(i) > 0) && (reduceLayers(i) < 1)
            [LayerFaces, LayerVertices] = reducepatch(LayerFaces, LayerVertices, reduceLayers(i));
            % Nothing left: return
            if isempty(LayerFaces)
                break;
            end
        end
        % Add layer to the list of grid points
        GridLoc = [GridLoc; LayerVertices];
        % Plot layer
%         if DEBUG
%             [hFig, iDS, iFig, hPatch] = view_surface_matrix(LayerVertices, LayerFaces, 1, [1 0 0], hFig);
%             %set(hPatch, 'EdgeColor', [1 0 0]);
%             set(hPatch, 'EdgeColor', 'none', 'MarkerFaceColor', [0,1,0], 'MarkerEdgeColor', [0,1,0], 'Marker', 'o', 'MarkerSize', 7);
%         end
    end
    % Go back to intial coordinates system
    GridLoc = bst_bsxfun(@plus, GridLoc, center);
    % Remove duplicate points
    GridLoc = unique(GridLoc, 'rows');
end



