function [Wmat, destGridAtlas, destGridLoc, destGridOrient] = tess_interp_mixed( ResultsMat, WmatSurf, srcSurfMat, destSurfMat, sMriSrc, sMriDest, isInteractive )
% TESS_INTERP_MIXED: Compute an interpolation matrix between two surfaces for a mixed source model.
% 
% WARNING: All the source files must be flattened first (GridAtlas.Grid2Source is an identity matrix).

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
% Authors: Francois Tadel, 2016

% Parse inputs
if (nargin < 7) || isempty(isInteractive)
    isInteractive = 1;
end

% Check the source model
if isfield(ResultsMat, 'nComponents') && (ResultsMat.nComponents ~= 0)
    error('This function is aimed to process only mixed source models.');
end
% Check that the field GridAtlas is available
if ~isfield(ResultsMat, 'GridAtlas') || ~isfield(ResultsMat.GridAtlas, 'Scouts') || isempty(ResultsMat.GridAtlas.Scouts)
    error('The field GridAtlas is missing.');
end
% Get Structures atlas in the destination surface
iStructDest = find(strcmpi({destSurfMat.Atlas.Name}, 'Structures'));
if isempty(iStructDest)
    error('Destination surface must include an atlas "Structures".');
end
% % Get "Source model" atlas in the destination surface
% iModelDest = find(strcmpi({destSurfMat.Atlas.Name}, 'Source model'));

% GridAtlas: Must be updated to fit the destination surface
destGridAtlas = ResultsMat.GridAtlas;
destGridAtlas.Scouts(:) = [];

% Initialize interpolation matrices
Wmat = sparse(1, size(ResultsMat.GridLoc,1));
destGridLoc    = [];
destGridOrient = [];
iVert2Grid = [];
isFirstMniWarning = 1;
hFig1 = [];

% Process each region separately
for iScoutSrc = 1:length(ResultsMat.GridAtlas.Scouts)
    sScoutSrc = ResultsMat.GridAtlas.Scouts(iScoutSrc);
    % Check if the source model has been flattened
    if (sScoutSrc.Region(3) ~= 'C')
        error('Source maps must be flattened before being projected with this function.');
    end
    % Get region in destination surface
    iScoutDest = find(strcmpi(sScoutSrc.Label, {destSurfMat.Atlas(iStructDest).Scouts.Label}));
    if isempty(iScoutDest)
        disp(['PROJECT> Warning: Structure not found in destination surface: ' sScoutSrc.Label]);
        continue;
    end
%     % If there is already an atlas "Source model", make sure the constraints match
%     if ~isempty(iModelDest)
%         iScoutDestModel = find(strcmpi(sScoutSrc.Label, {destSurfMat.Atlas(iModelDest).Scouts.Label}));
%         if isempty(iModelDest) || ~isequal(destSurfMat.Atlas(iModelDest).Scouts(iScoutDestModel).Region, sScoutSrc.Region)
%             error(['The atlas "Source model" has different constraints in the destination surface for region "' sScoutSrc.Label '".']);
%         end
%     end
    % Update scout structure
    sScoutDest = sScoutSrc;
    sScoutDest.Vertices = destSurfMat.Atlas(iStructDest).Scouts(iScoutDest).Vertices(:)';
    sScoutDest.Seed     = destSurfMat.Atlas(iStructDest).Scouts(iScoutDest).Seed;

    % Process depends on region type
    switch (sScoutSrc.Region(2))
        % Volume: Compute a grid
        case 'V'
            % Source grid: Get from the source file
            srcLoc = ResultsMat.GridLoc(sScoutSrc.GridRows,:);
            % Compute a grid based on the destination region
            destLoc = dba_anatmodel(sScoutDest.Vertices, sScoutDest, destSurfMat, 'vol');
            destOri = 0 * destLoc;
            % Convert to MNI coordinates
            srcLocMni  = cs_convert(sMriSrc,  'scs', 'mni', srcLoc);
            destLocMni = cs_convert(sMriDest, 'scs', 'mni', destLoc);
            if (isempty(srcLocMni) || isempty(destLocMni))
                if isFirstMniWarning
                    strWarning = 'For accurate results, compute the MNI transformation for both subjects before running this interpolation.';
                    if isInteractive
                        java_dialog('warning', strWarning);
                    else
                        disp(['PROJECT> Warning: ' strWarning]);
                        bst_report('Warning', 'process_project_sources', [], strWarning);
                    end
                    isFirstMniWarning = 0;
                end
                srcLocMni  = srcLoc;
                destLocMni = destLoc;
            end
            % Set the indices of the regions in the Atlas
            sScoutDest.GridRows = size(destGridLoc,1) + (1:size(destLoc,1));
            % Compute interpolation
            Wmat(sScoutDest.GridRows, sScoutSrc.GridRows) = bst_shepards(destLocMni, srcLocMni, 8, 0);

            % === DISPLAY ALIGNMENT ===
            if isInteractive && ~isequal(sMriSrc, sMriDest)
                % Close previous figures
                if ~isempty(hFig1) && ishandle(hFig1)
                    close(hFig1);
                end
                % Compute convex envelopes
                facesSrc  = convhull(srcLoc);
                facesDest = convhull(destLoc);
                % Display figure
                [hFig1, iDS, iFig, hPatch] = view_surface_matrix(destLoc, facesDest, .4, [1 0 0]);
                set(hPatch, 'EdgeColor', 'r');
                [hFig1, iDS, iFig, hPatch] = view_surface_matrix(srcLoc, facesSrc, .4, [], hFig1);
                set(hPatch, 'EdgeColor', [.6 .6 .6]);
                line(destLoc(:,1), destLoc(:,2), destLoc(:,3), ...
                     'LineStyle',   'none', ...
                     'Color',       [1 1 0], ...
                     'MarkerSize',  2, ...
                     'Marker',      'o');
                line(srcLoc(:,1), srcLoc(:,2), srcLoc(:,3), ...
                     'LineStyle',   'none', ...
                     'Color',       [0 0 1], ...
                     'MarkerSize',  2, ...
                     'Marker',      'o');
                set(hFig1, 'Name', [sScoutSrc.Label ' (source grid)']);
                drawnow;
            end
            
        % Surface: Use the surface-surface interpolation computed previously
        case 'S'
            destLoc = destSurfMat.Vertices(sScoutDest.Vertices, :);
            destOri = destSurfMat.VertNormals(sScoutDest.Vertices, :);
            % Set the indices of the regions in the Atlas
            sScoutDest.GridRows = size(destGridLoc,1) + (1:size(destLoc,1));
            % Re-use surface inteprolation
            Wmat(sScoutDest.GridRows, sScoutSrc.GridRows) = WmatSurf(sScoutDest.Vertices, sScoutSrc.Vertices);
            % Add the match of the vertices in the cortex surface and the GridLoc matrix
            iVert2Grid = [iVert2Grid; sScoutDest.Vertices', sScoutDest.GridRows'];
            
        otherwise
            disp(['PROJECT> Warning: Structure ignored: ' sScoutSrc.Label]);
            continue;
    end
    % Concatenate GridLoc and GridOrient
    destGridLoc    = [destGridLoc;    destLoc];
    destGridOrient = [destGridOrient; destOri]; 
    % Add scout to destination atlas
    destGridAtlas.Scouts(end+1) = sScoutDest;
end

% Create sparse conversion matrices between indices
% Vert2Grid: Correspondance between the vertices of the cortex surface and the GridLoc field
destGridAtlas.Vert2Grid   = logical(sparse(iVert2Grid(:,2), iVert2Grid(:,1), ones(size(iVert2Grid,1),1)));
% Grid2Source: Correspondance between the GridLoc and ImageGridamp matrices (identity matrix because the source maps must be flatten before projecting)
destGridAtlas.Grid2Source = logical(speye(size(destGridLoc,1)));  





