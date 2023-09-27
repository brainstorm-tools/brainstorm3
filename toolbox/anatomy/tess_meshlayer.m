function [OutputFiles, iSurface] = tess_meshlayer(TissueFile, TissueLabels, nVertices, erodeFactor, fillFactor, Comment)
% TESS_MESHLAYER: Reconstruct an envelope based on segmented tissues
%
% USAGE:  [OutputFiles, iSurface] = tess_meshlayer(TissueFile, TissueLabels, nVertices=10000, erodeFactor=0, fillFactor=2, Comment)

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
% Authors: Francois Tadel, 2021

%% ===== PARSE INPUTS =====
% Initialize returned variables
OutputFiles = {};
iSurface = [];
% Parse inputs
if (nargin < 6) || isempty(Comment)
    Comment = [];
end
% Get subject
[sSubject, iSubject] = bst_get('MriFile', TissueFile);


%% ===== LOAD TISSUE SEGMENTATION =====
% Load MRI 
bst_progress('start', 'Generate mesh', 'Loading tissues...');
sMri = bst_memory('LoadMri', TissueFile);
bst_progress('stop');
% Save current scouts modifications
panel_scout('SaveModifications');
% Check that this is a tissue segmentation
if ~isfield(sMri, 'Labels') || isempty(sMri.Labels)
    bst_error('Invalid tissue segmentation: missing labels.', 'Generate mesh', 0);
    return;
end


%% ===== ASK PARAMETERS =====
% Ask layer
if (nargin < 2) || isempty(TissueLabels)
    listLayers = sMri.Labels(fliplr(find([sMri.Labels{:,1}] > 0)), 2)';
    sel = java_dialog('checkbox', 'Layers to mesh:', 'Generate mesh', [], listLayers, ones(size(listLayers)));
    % If user cancelled: return
    if isempty(sel)
        return
    end
    TissueLabels = listLayers(logical(sel));
elseif ischar(TissueLabels)
    TissueLabels = {TissueLabels};
end
% Ask user to set the parameters if they are not set
if (nargin < 5) || isempty(nVertices) || isempty(erodeFactor) || isempty(fillFactor)
    res = java_dialog('input', {'Number of vertices [integer]:', 'Erode factor [0,1,2,3]:', 'Fill holes factor [0,1,2,3]:'}, 'Generate mesh', [], {'10000', '0', '2'});
    % If user cancelled: return
    if isempty(res)
        return
    end
    % Get new values
    nVertices   = str2num(res{1});
    erodeFactor = str2num(res{2});
    fillFactor  = str2num(res{3});
end
% Check parameters values
if isempty(nVertices) || (nVertices < 50) || (nVertices ~= round(nVertices)) || isempty(erodeFactor) || ~ismember(erodeFactor,[0,1,2,3]) || isempty(fillFactor) || ~ismember(fillFactor,[0,1,2,3])
    bst_error('Invalid parameters.', 'Generate mesh', 0);
    return
end


%% ===== CREATE HEAD MASK =====
% Progress bar
bst_progress('start', 'Generate mesh', 'Initializing...', 0, 100*length(TissueLabels));
for iTissue = 1:length(TissueLabels)
    bst_progress('text', 'Generate mesh', ['Layer #' num2str(iTissue) ': Creating envelope...'], 0, 100);
    % Get layer
    iLayer = find(strcmpi(sMri.Labels(:,2), TissueLabels{iTissue}));
    if isempty(iLayer)
        bst_error(['Layer not found: ' TissueLabels{iTissue}], 'Generate mesh', 0);
        return;
    end
    % Threshold mri to the level estimated in the histogram
    mask = (sMri.Cube == sMri.Labels{iLayer,1});
    % Closing all the faces of the cube
    mask(1,:,:)   = 0*mask(1,:,:);
    mask(end,:,:) = 0*mask(1,:,:);
    mask(:,1,:)   = 0*mask(:,1,:);
    mask(:,end,:) = 0*mask(:,1,:);
    mask(:,:,1)   = 0*mask(:,:,1);
    mask(:,:,end) = 0*mask(:,:,1);
    % Erode + dilate, to remove small components
    if (erodeFactor > 0)
        mask = mask & ~mri_dilate(~mask, erodeFactor);
        mask = mri_dilate(mask, erodeFactor);
    end
    bst_progress('inc', 10);
    % Fill holes
    bst_progress('text', ['Layer #' num2str(iTissue) ': Filling holes...']);
    mask = (mri_fillholes(mask, 1) & mri_fillholes(mask, 2) & mri_fillholes(mask, 3));
    bst_progress('inc', 10);
    % Error if mask is empty
    if (nnz(mask) == 0)
        bst_error(['Layer is empty after eroding: ' TissueLabels{iTissue}], 'Generate mesh', 0);
        return;
    end

    % view_mri_slices(mask, 'x', 20)


    %% ===== CREATE SURFACE =====
    % Compute isosurface
    bst_progress('text', ['Layer #' num2str(iTissue) ': Creating isosurface...']);
    [sLayer.Faces, sLayer.Vertices] = mri_isosurface(mask, 0.5);
    bst_progress('inc', 10);
    % Downsample to a maximum number of vertices
    maxIsoVert = 60000;
    if (length(sLayer.Vertices) > maxIsoVert)
        bst_progress('text', ['Layer #' num2str(iTissue) ': Downsampling isosurface...']);
        [sLayer.Faces, sLayer.Vertices] = reducepatch(sLayer.Faces, sLayer.Vertices, maxIsoVert./length(sLayer.Vertices));
        bst_progress('inc', 10);
    end
    % Remove small objects
    bst_progress('text', ['Layer #' num2str(iTissue) ': Removing small patches...']);
    [sLayer.Vertices, sLayer.Faces] = tess_remove_small(sLayer.Vertices, sLayer.Faces);
    bst_progress('inc', 10);

    % Downsampling isosurface
    bst_progress('text', ['Layer #' num2str(iTissue) ': Downsampling surface...']);
    [sLayer.Faces, sLayer.Vertices] = reducepatch(sLayer.Faces, sLayer.Vertices, nVertices./length(sLayer.Vertices));
    bst_progress('inc', 10);
    % Convert to millimeters
    sLayer.Vertices = sLayer.Vertices(:,[2,1,3]);
    sLayer.Faces    = sLayer.Faces(:,[2,1,3]);
    sLayer.Vertices = bst_bsxfun(@times, sLayer.Vertices, sMri.Voxsize);
    % Convert to SCS
    sLayer.Vertices = cs_convert(sMri, 'mri', 'scs', sLayer.Vertices ./ 1000);

    % Reduce the final size of the meshed volume
    erodeFinal = 3;
    % Fill holes in surface
    %if (fillFactor > 0)
        bst_progress('text', ['Layer #' num2str(iTissue) ': Filling holes...']);
        [sLayer.Vertices, sLayer.Faces] = tess_fillholes(sMri, sLayer.Vertices, sLayer.Faces, fillFactor, erodeFinal);
        bst_progress('inc', 30);
    % end


    %% ===== SAVE FILES =====
    bst_progress('text', ['Layer #' num2str(iTissue) ': Saving new file...']);
    % Create output filenames
    ProtocolInfo = bst_get('ProtocolInfo');
    SurfaceDir   = bst_fullfile(ProtocolInfo.SUBJECTS, bst_fileparts(TissueFile));
    TessFile  = file_unique(bst_fullfile(SurfaceDir, 'tess_head_mask.mat'));
    % Save head
    SurfaceType = 'Other';
    if ~isempty(Comment)
        sLayer.Comment = Comment;
    else
        switch (lower(TissueLabels{iTissue}))
            case 'scalp',                 newLabel = 'head';       SurfaceType = 'Scalp';
            case 'skull',                 newLabel = 'outerskull'; SurfaceType = 'OuterSkull';
            case 'csf',                   newLabel = 'innerskull'; SurfaceType = 'InnerSkull';
            case {'grey','gray','brain'}, newLabel = 'cortex';     SurfaceType = 'Cortex';
            case 'white',                 newLabel = 'white';      SurfaceType = 'Cortex';
            otherwise,                    newLabel = lower(TissueLabels{iTissue});
        end
        sLayer.Comment = sprintf('%s (%d,%d,%d)', newLabel, nVertices, erodeFactor, fillFactor);
    end
    sLayer = bst_history('add', sLayer, 'bem', 'Head surface generated with Brainstorm');
    bst_save(TessFile, sLayer, 'v7');
    iSurface = [iSurface, db_add_surface(iSubject, TessFile, sLayer.Comment, SurfaceType)];
    % Return new files
    OutputFiles{end+1} = TessFile;
    bst_progress('inc', 10);
end

% Close, success
bst_progress('stop');




