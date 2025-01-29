function [HeadFile, iSurface] = tess_isohead(iSubject, nVertices, erodeFactor, fillFactor, bgLevel, Comment, isGradient, Method)
% TESS_GENERATE: Reconstruct a head surface based on the MRI, based on an isosurface
%
% USAGE:  [HeadFile, iSurface] = tess_isohead(iSubject, nVertices=10000, erodeFactor=0, fillFactor=2, bgLevel=GuessFromHistorgram, Comment)
%         [HeadFile, iSurface] = tess_isohead(MriFile,  nVertices=10000, erodeFactor=0, fillFactor=2, bgLevel=GuessFromHistorgram, Comment)
%         [Vertices, Faces]    = tess_isohead(sMri,     nVertices=10000, erodeFactor=0, fillFactor=2)
%
% If input is loaded MRI structure, no surface file is created and the surface vertices and faces are returned instead.

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
% Authors: Francois Tadel, 2012-2022

% Work in progress: Marc Lalancette 2022-2025 
% modified quite a bit, erode and fill factors no longer used. See my notes in OneNote

% To visualize steps for debugging.
isDebugVis = false;
nDebugVisSlices = 9; %#ok<NASGU>

%% ===== PARSE INPUTS =====
% Initialize returned variables
HeadFile = [];
iSurface = [];
isSave = true;
% Parse inputs
if (nargin < 8) || isempty(Method)
    Method = 'simplify';
end
if strcmpi(Method, 'simplify')
    % Check if Lidar Toolbox is installed (requires image processing + computer vision)
    isLidarToolbox = exist('surfaceMesh', 'file') == 2;
    if ~isLidarToolbox
        bst_error('Lidar toolbox required for method ''simplify''.');
    end
end
if (nargin < 7) || isempty(isGradient)
    isGradient = false;
end
if (nargin < 6)
    if nargin == 5
        % Handle legacy call: tess_isohead(iSubject, nVertices, erodeFactor, fillFactor, Comment)
        if ischar(bgLevel)
            Comment = bgLevel;
            bgLevel = [];
        % Parameter 'bgLevel' is provided: tess_isohead(iSubject, nVertices, erodeFactor, fillFactor, bgLevel)
        else
            Comment = [];
        end
    % Call tess_isohead(iSubject, nVertices, erodeFactor, fillFactor)
    else
        bgLevel = [];
        Comment = [];
    end
end
% MriFile instead of subject index
sMri = [];
if ischar(iSubject)
    MriFile = file_short(iSubject);
    [sSubject, iSubject] = bst_get('MriFile', MriFile);
elseif isnumeric(iSubject)
    % Get subject
    sSubject = bst_get('Subject', iSubject);
    MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
elseif isstruct(iSubject)
    sMri = iSubject;
    MriFile = sMri.FileName;
    [sSubject, iSubject] = bst_get('MriFile', MriFile);
    % Don't save a surface file, instead return surface directly.
    isSave = false;  
else
    error('Wrong input type.');
end

%% ===== LOAD MRI =====
isProgress = ~bst_progress('isVisible');
if isempty(sMri)
    % Load MRI
    bst_progress('start', 'Generate head surface', 'Loading MRI...');
    sMri = bst_memory('LoadMri', MriFile);
    if isProgress
        bst_progress('stop');
    end
end
% Save current scouts modifications
panel_scout('SaveModifications');
% If subject is using the default anatomy: use the default subject instead
if sSubject.UseDefaultAnat
    iSubject = 0;
end
% Check layers
if isempty(sSubject.iAnatomy) || isempty(sSubject.Anatomy)
    bst_error('The generate of the head surface requires at least the MRI of the subject.', 'Head surface', 0);
    return
end
% Check that everything is there
if ~isfield(sMri, 'Histogram') || isempty(sMri.Histogram) || isempty(sMri.SCS) || isempty(sMri.SCS.NAS) || isempty(sMri.SCS.LPA) || isempty(sMri.SCS.RPA)
    bst_error('You need to set the fiducial points in the MRI first.', 'Head surface', 0);
    return
end
% Guess background level
if isempty(bgLevel)
    bgLevel = sMri.Histogram.bgLevel;
end

%% ===== ASK PARAMETERS =====
% Ask user to set the parameters if they are not set
if (nargin < 4) || isempty(erodeFactor) || isempty(nVertices)
    res = java_dialog('input', {'Number of vertices [integer]:', 'Erode factor [0,1,2,3]:', 'Fill holes factor [0,1,2,3]:', '<HTML>Background threshold:<BR>(guessed from MRI histogram)'}, 'Generate head surface', [], {'15000', '0', '0', num2str(bgLevel)});
    % If user cancelled: return
    if isempty(res)
        return
    end
    % Get new values
    nVertices   = str2double(res{1});
    erodeFactor = str2double(res{2});
    fillFactor  = str2double(res{3});
    bgLevel     = str2double(res{4});
    if isempty(bgLevel)
        bgLevel = sMri.Histogram.bgLevel;
    end
end
% Check parameters values
if isempty(nVertices) || (nVertices < 50) || (nVertices ~= round(nVertices)) || isempty(erodeFactor) || ~ismember(erodeFactor,[0,1,2,3]) || isempty(fillFactor) || ~ismember(fillFactor,[0,1,2,3])
    bst_error('Invalid parameters.', 'Head surface', 0);
    return
end


%% ===== CREATE HEAD MASK =====
% Progress bar
bst_progress('start', 'Generate head surface', 'Creating head mask...', 0, 100);
% Threshold mri to the level estimated in the histogram
if isGradient
    isGradLocalMax = false;
    % Compute gradient
    % Find appropriate threshold from gradient histogram
    % TODO: need to find a robust way to do this.  Only verified on one
    % relatively bad MRI sequence with preprocessing (debias, denoise).
    [Grad, VectGrad] = NormGradient(sMri.Cube(:,:,:,1)); %#ok<ASGLU>
    if isempty(bgLevel)
        Hist = mri_histogram(Grad, [], 'headgrad');
        bgLevel = Hist.bgLevel;
    end
    if isGradLocalMax
        % Index gymnastics... Is there a simpler way to do this (other than looping)?
        nVol = [1, cumprod(size(Grad))]';
        [unused, UpDir] = max(abs(reshape(VectGrad, nVol(4), [])), [], 2); % (nVol, 1)
        UpDirSign = sign(VectGrad((1:nVol(4))' + (UpDir-1) * nVol(4)));
        % Get neighboring value of the gradient in the increasing gradiant direction.
        % Using linear indices shaped as 3d array, which will give back a 3d array.
        iUpGrad = zeros(size(Grad));
        iUpGrad(:) = UpDirSign .* nVol(UpDir); % change in index: +-1 along appropriate dimension for each voxel, in linear indices
        % Removing problematic indices at edges.
        iUpGrad([1, end], :, :) = 0;
        iUpGrad(:, [1, end], :) = 0;
        iUpGrad(:, :, [1, end]) = 0;
        iUpGrad(:) = iUpGrad(:) + (1:nVol(4))'; % adding change to each element index
        UpGrad = Grad(iUpGrad); 
        headmask = Grad > bgLevel & Grad >= UpGrad;
    else        
        headmask = Grad > bgLevel;
    end
else
    headmask = sMri.Cube(:,:,:,1) > bgLevel;
end
% Closing all the faces of the cube
headmask(1,:,:)   = 0; %*headmask(1,:,:);
headmask(end,:,:) = 0; %*headmask(1,:,:);
headmask(:,1,:)   = 0; %*headmask(:,1,:);
headmask(:,end,:) = 0; %*headmask(:,1,:);
headmask(:,:,1)   = 0; %*headmask(:,:,1);
headmask(:,:,end) = 0; %*headmask(:,:,1);
if isDebugVis
    view_mri_slices(headmask, 'x', nDebugVisSlices); %#ok<*UNRCH>
end
% Erode + dilate, to remove small components
% if (erodeFactor > 0)
%     headmask = headmask & ~mri_dilate(~headmask, erodeFactor);
%     headmask = mri_dilate(headmask, erodeFactor);
% end
% bst_progress('inc', 10);

% Remove isolated voxels (dots or holes) from 5 out of 6 sides
% isFill = false(size(headmask));
% isFill(2:end-1,2:end-1,2:end-1) = (headmask(1:end-2,2:end-1,2:end-1) + headmask(3:end,2:end-1,2:end-1) + ...
%     headmask(2:end-1,1:end-2,2:end-1) + headmask(2:end-1,3:end,2:end-1) + ...
%     headmask(2:end-1,2:end-1,1:end-2) + headmask(2:end-1,2:end-1,3:end)) >= 5 & ...
%     ~headmask(2:end-1,2:end-1,2:end-1);
% headmask(isFill) = 1;
% isFill = false(size(headmask));
% isFill(2:end-1,2:end-1,2:end-1) = (headmask(1:end-2,2:end-1,2:end-1) + headmask(3:end,2:end-1,2:end-1) + ...
%     headmask(2:end-1,1:end-2,2:end-1) + headmask(2:end-1,3:end,2:end-1) + ...
%     headmask(2:end-1,2:end-1,1:end-2) + headmask(2:end-1,2:end-1,3:end)) <= 1 & ...
%     headmask(2:end-1,2:end-1,2:end-1);
% headmask(isFill) = 0;

% Fill neck holes (bones, etc.) where it is cut at edge of volume. 
bst_progress('text', 'Filling holes and removing disconnected parts...');
% if isDebugVis
%     figure; imagesc(headmask(:,:,2)); colormap('gray'); axis equal;
% end
% Brainstorm reorients MRI so voxels are in RAS. But do all faces in case the bounding box was too
% small and another part is cut (e.g. nose).

% Number of slices to average to smooth out noise in low SNR regions (e.g. around neck and chin). 
% 4,3 worked ok in noisy scan, but probably best to denoise entire scan first.
nSlices = 1; % 1 = no averaging.
FillThresh = 1; %min(nSlices, floor(nSlices/2)+1);
if FillThresh > nSlices || FillThresh < floor(nSlices/2)
    error('Bad hard-coded FillThresh.');
end
for iDim = 1:3
    % Swap slice dimension into first position.
    switch iDim 
        case 1
            Perm = 1:3;
        case 2
            Perm = [2, 1, 3];
        case 3
            Perm = [3, 2, 1];
    end
    TempMask = permute(headmask, Perm);
    % Edit second and second-to-last slices. Flip the array to reuse code with same indices.
    for isFlip = [false, true]
        if isFlip
            TempMask = flip(TempMask, 1);
        end
        % Skip if just background (e.g. above or behind head)
        if ~any(any(squeeze(TempMask(2, :, :))))
            % Flip back and move on
            if isFlip 
                TempMask = flip(TempMask, 1);
            end
            continue;
        end
        if isDebugVis
            figure; imagesc(squeeze(TempMask(2,:,:))); colormap('gray'); axis equal; title(sprintf('Dim %d, Flip %d', iDim, isFlip));
        end
        Slice = sum(TempMask(2:2+nSlices-1, :, :), 1);
        if isDebugVis && nSlices > 1
            figure; imagesc(squeeze(Slice)); colormap('gray'); axis equal; title(sprintf('Dim %d, Flip %d, Avg %d slices', iDim, isFlip, nSlices));
        end
        Slice = Slice >= FillThresh;
        % Skip if just background (previous check had just some noise)
        if ~any(any(squeeze(Slice)))
            if isFlip
                TempMask = flip(TempMask, 1);
            end
            continue;
        end
        Slice = FillConcaveVolume(Slice, true); % isClean
        % Slice = Slice | (Fill(Slice, 2) & Fill(Slice, 3));
        if isDebugVis
            figure; imagesc(squeeze(Slice)); colormap('gray'); axis equal; title(sprintf('Dim %d, Flip %d, Filled', iDim, isFlip));
        end
        Slice = CenterSpread(Slice);
        if isDebugVis
            figure; imagesc(squeeze(Slice)); colormap('gray'); axis equal; title(sprintf('Dim %d, Flip %d, Center spread', iDim, isFlip));
        end
        TempMask(2, :, :) = Slice;
        if isFlip
            TempMask = flip(TempMask, 1);
        end
    end
    % Permute back
    headmask = permute(TempMask, Perm);
end
% if isDebugVis
%     figure; imagesc(headmask(:,:,2)); colormap('gray'); axis equal;
% end
% Fill holes
headmask = FillConcaveVolume(headmask, true); % clean, which may remove a few more original 1-voxel-wide or noise bits
if isDebugVis
    view_mri_slices(headmask, 'x', nDebugVisSlices); title('Filled');
end
% Keep only central connected volume (trim "beard" or bubbles)
headmask = CenterSpread(headmask);
bst_progress('inc', 15);

if isDebugVis
    view_mri_slices(headmask, 'x', nDebugVisSlices); title('Center spread');
end




%% ===== CREATE SURFACE =====
% Compute isosurface
bst_progress('text', 'Creating isosurface...');

switch Method
    case 'iso2mesh'
        method = 'cgalsurf';
        opt.radbound = 4; % max radius of the Delaunay sphere - adjust to get desired vertex numbers
        opt.distbound = 1; % max distance from isosurface
        dofix = 1; % don't know if needed

        [sHead.Vertices, sHead.Faces, regions, holes] = vol2surf(headmask, ...
            1:size(headmask,1), 1:size(headmask,2), 1:size(headmask,3), opt, dofix, method); % ,isovalues
        if size(regions, 1) > 1
            bst_error('Multiple regions returned.\n');
            return;
        elseif ~isempty(holes)
            bst_error('Holes present.\n');
            return;
        end
        % Remove region label
        sHead.Faces(:,4) = [];
        if isDebugVis
            fprintf('iso2mesh surface\n');
            [isOk, Info] = tess_check(sHead.Vertices, sHead.Faces, true, false, true); % verbose, not open, show
            title('iso2mesh surface', 'color', 'white');
        end
        bst_progress('inc', 45);

    case {'reducepatch', 'simplify'}
        % Could have avoided x-y flip by specifying XYZ in isosurface...
        [sHead.Faces, sHead.Vertices] = mri_isosurface(headmask, 0.5);
        % Flip x-y back to our voxel coordinates
        sHead.Vertices = sHead.Vertices(:, [2, 1, 3]);
        % Flip to have desired face orientations (seems inconsistent if needed or not).
        % sHead.Faces = sHead.Faces(:, [2, 1, 3]);
        if isDebugVis
            fprintf('mri_isohead surface\n');
            [isOk, Info] = tess_check(sHead.Vertices, sHead.Faces, true, false, true); % verbose, not open, show
            title('isosurface', 'color', 'white');
        end
        bst_progress('inc', 10);
        % Downsample to a maximum number of vertices
        % maxIsoVert = 60000;
        % if (length(sHead.Vertices) > maxIsoVert)
        %     bst_progress('text', 'Downsampling isosurface...');
        %     [sHead.Faces, sHead.Vertices] = reducepatch(sHead.Faces, sHead.Vertices, maxIsoVert./length(sHead.Vertices));
        %     bst_progress('inc', 10);
        % end

        % Remove small objects
        bst_progress('text', 'Removing small patches...');
        nVertTemp = size(sHead.Vertices, 1);
        [sHead.Vertices, sHead.Faces] = tess_remove_small(sHead.Vertices, sHead.Faces);
        if isDebugVis && nVertTemp > size(sHead.Vertices, 1) % only if something was removed in previous step
            fprintf('BST>Some disconnected small patches removed (%d vertices).\n', nVertTemp - size(sHead.Vertices, 1));
            [isOk, Info] = tess_check(sHead.Vertices, sHead.Faces, true, false, true); %#ok<ASGLU> % verbose, not open, show
            title('isosurface & small removed', 'color', 'white');
        end
        bst_progress('inc', 15);

        % Clean final surface
        % This is very strange, it doesn't look at face locations, only the normals.
        % After isosurface, many many faces are parallel.
        % bst_progress('text', 'Fill: Cleaning surface...');
        % [sHead.Vertices, sHead.Faces] = tess_clean(sHead.Vertices, sHead.Faces);

        % Smooth voxel artefacts, but preserve shape and volume.
        bst_progress('text', 'Smoothing voxel artefacts...');
        % Should normally use 1 as voxel size, but using a larger value smooths.
        % Restrict iterations to make it faster, smooth a bit more (normal to surface
        % only) after downsampling.
        sHead.Vertices = SurfaceSmooth(sHead.Vertices, sHead.Faces, 2, [], 5, [], false); % voxel/smoothing size, iterations, verbose
        if isDebugVis
            fprintf('mildly smoothed isosurface\n');
            [isOk, Info] = tess_check(sHead.Vertices, sHead.Faces, true, false, true); % verbose, not open, show
            title('mildly smoother isosurface', 'color', 'white');
        end
        bst_progress('inc', 20);
end

% Downsampling surface
if (length(sHead.Vertices) > 1.5* nVertices)
    bst_progress('text', 'Downsampling surface...');
    % Modified tess_downsize to accept sHead
    sHead = tess_downsize(sHead, nVertices, Method);
    if isDebugVis
        fprintf('reduced surface (%s)\n', Method);
        [isOk, Info] = tess_check(sHead.Vertices, sHead.Faces, true, false, true); % verbose, not open, show
        title('reduced', 'color', 'white')
    end
    % Fix this patch
    if ~strcmpi(Method, 'iso2mesh') % I don't think iso2mesh returns multiple disconnected regions.
        nVertTemp = size(sHead.Vertices, 1);
        [sHead.Vertices, sHead.Faces] = tess_remove_small(sHead.Vertices, sHead.Faces);
        if isDebugVis && nVertTemp > size(sHead.Vertices, 1) % only if something was removed in previous step
            fprintf('BST>Some disconnected small patches removed (%d vertices).\n', nVertTemp - size(sHead.Vertices, 1));
            fprintf('reduced surface (small disconnected parts removed)\n');
            [isOk, Info] = tess_check(sHead.Vertices, sHead.Faces, true, false, true); %#ok<ASGLU> % verbose, not open, show
            title('reduced & small removed', 'color', 'white')
        end
    end
end
bst_progress('inc', 15);

bst_progress('text', 'Smoothing...');
sHead.Vertices = SurfaceSmooth(sHead.Vertices, sHead.Faces, 1.5, [], 45, 0, false); % voxel/smoothing size, iterations, freedom (normal), verbose
if isDebugVis
    fprintf('final smoothed surface\n');
    [isOk, Info] = tess_check(sHead.Vertices, sHead.Faces, true, false, true); % verbose, not open, show
end
bst_progress('inc', 10);

% Convert to SCS
sHead.Vertices = cs_convert(sMri, 'voxel', 'scs', sHead.Vertices);
% Flip face order to Brainstorm convention
sHead.Faces = sHead.Faces(:,[2,1,3]);

% % Smooth isosurface
% bst_progress('text', 'Fill: Smoothing surface...');
% VertConn = tess_vertconn(Vertices, Faces);
% Vertices = tess_smooth(Vertices, 1, 10, VertConn, 0);
% % One final round of smoothing
% VertConn = tess_vertconn(Vertices, Faces);
% Vertices = tess_smooth(Vertices, 0.2, 3, VertConn, 0);
%
% % Reduce the final size of the meshed volume
% erodeFinal = 3;
% % Fill holes in surface
% if (fillFactor > 0)
%     bst_progress('text', 'Filling holes...');
%     [sHead.Vertices, sHead.Faces] = tess_fillholes(sMri, sHead.Vertices, sHead.Faces, fillFactor, erodeFinal);
%     bst_progress('inc', 30);
% end


%% ===== SAVE FILES =====
if isSave
    bst_progress('text', 'Saving new file...');
    % Create output filenames
    ProtocolInfo = bst_get('ProtocolInfo');
    SurfaceDir   = bst_fullfile(ProtocolInfo.SUBJECTS, bst_fileparts(MriFile));
    HeadFile  = file_unique(bst_fullfile(SurfaceDir, 'tess_head_mask.mat'));
    % Save head
    if ~isempty(Comment)
        sHead.Comment = Comment;
    else
        sHead.Comment = sprintf('head mask (%d,%d,%d,%d)', nVertices, erodeFactor, fillFactor, round(bgLevel));
    end
    sHead = bst_history('add', sHead, 'bem', 'Head surface generated with Brainstorm');
    bst_save(HeadFile, sHead, 'v7');
    iSurface = db_add_surface( iSubject, HeadFile, sHead.Comment);
else
    % Return surface
    HeadFile = sHead.Vertices;
    iSurface = sHead.Faces;
end

% Close, success
if isProgress
    bst_progress('stop');
end
end

%% ===== Subfunctions =====
function mask = FillConcaveVolume(mask, isClean)
    if nargin < 2 || isempty(isClean)
        % Default to not remove any of the original mask.
        isClean = false;
    end

    % % Dimensions that have thickness, not singleton
    % isThk = size(mask, [1,2,3]) > 1;
    % nThk = sum(isThk);
% for iDim = 1:3
%     % Swap slice dimension into first position.
%     switch iDim 
%         case 1
%             Perm = 1:3;
%         case 2
%             Perm = [2, 1, 3];
%         case 3
%             Perm = [3, 2, 1];
%     end
%     TempMask = permute(headmask, Perm);
% 
    % "First to last" fill
    % Fill from first to last 1-voxels along each direction and keep intersection across 3 dimensions.
    % This can result in very narrow deep "tunnels", which we fix with the "surround" fill step next.
    mask = (Fill(mask, 1, true) & Fill(mask, 2, true) & Fill(mask, 3, true));
    % This was because fill was previously not including the "first and last" voxels, probably to
    % exclude single voxels, but we added it back anyway so added.
    % mask = InsideMask | (Dilate(InsideMask) & mask); % filled region or original adjacent 1s.

    % "Surround" fill
    % Fill a voxel if it's surrounded by 1
    % 4 adjacent voxels in a plane (not diagonals) for 3d, 2 adjacent voxels in a line for 2d.
    % Repeat for filling intersections. Twice ok for 2d or 3d.
    mask = Surrounded(mask, true);
    mask = Surrounded(mask, true);

    if isClean
        % Apply inverse "surround" to remove noise and small protrusions.
        % Erase voxel if surrounded by 0 in a plane. Could do before "first to last" above to clean
        % noise first, but could also erase more parts in low SNR areas. We later keep only
        % connected central part so no need to iterate this step.
        mask = Surrounded(mask, false);
    end
end


function mask = Surrounded(mask, Value)
    % Find voxels that are surrounded by a value and add them (if Value=true) or remove them (false).
    % 4 adjacent voxels in a plane (not diagonals) for 3d, 2 adjacent voxels in a line for 2d.

    if nargin < 2 || isempty(Value)
        Value = true;
    end
    % Flip the mask if we're looking for false.
    if ~Value
        mask = ~mask;
    end

    % Indices for dimensions excluding ends (2:end-1), except if thin dimension, then it's just 1 or [1 2].
    nVox = size(mask, [1,2,3]);
    iVox = {min(2, nVox(1)):max(nVox(1)-1, 1), min(2, nVox(2)):max(nVox(2)-1, 1), min(2, nVox(3)):max(nVox(3)-1, 1)};
    S = zeros(nVox - (nVox > 2)*2);

    % Loop so it works on 2d or 3d
    nDim = 0;
    for iDim = 1:3
        if size(mask, iDim) > 2 % Skip singleton dimensions
            nDim = nDim + 1;
            switch iDim
                case 1
                    S = S + (mask(1:end-2,iVox{2},iVox{3}) & mask(3:end,iVox{2},iVox{3}));
                case 2
                    S = S + (mask(iVox{1},1:end-2,iVox{3}) & mask(iVox{1},3:end,iVox{3}));
                case 3
                    S = S + (mask(iVox{1},iVox{2},1:end-2) & mask(iVox{1},iVox{2},3:end));
            end
        end
    end

    % Modify original mask by adding (true) or removing (false)
    mask(iVox{1},iVox{2},iVox{3}) = mask(iVox{1},iVox{2},iVox{3}) | S >= nDim - 1;
    if ~Value
        mask = ~mask;
    end
end


function mask = Fill(mask, dim, isFullSingl)
    % Modified to exclude boundaries, so we can get rid of external junk as well as
    % internal holes easily.
    if nargin < 3 || isempty(isFullSingl)
        % Return original mask for singleton dim by default.
        isFullSingl = false;
    end

    % Initialize two accumulators, for the two directions
    acc1 = mask;
    acc2 = mask;
    n = size(mask,dim);
    % Skip singleton dimensions
    if n == 1
        if isFullSingl
            % Return all true, e.g. to combine with Fill in other directions.
            mask = true(size(mask));
        end
        return;
    end

    % Process in required direction
    switch dim
        case 1
            for i = 2:n
                acc1(i,:,:) = acc1(i,:,:) | acc1(i-1,:,:);
            end
            for i = n-1:-1:1
                acc2(i,:,:) = acc2(i,:,:) | acc2(i+1,:,:);
            end
        case 2
            for i = 2:n
                acc1(:,i,:) = acc1(:,i,:) | acc1(:,i-1,:);
            end
            for i = n-1:-1:1
                acc2(:,i,:) = acc2(:,i,:) | acc2(:,i+1,:);
            end
        case 3
            for i = 2:n
                acc1(:,:,i) = acc1(:,:,i) | acc1(:,:,i-1);
            end
            for i = n-1:-1:1
                acc2(:,:,i) = acc2(:,:,i) | acc2(:,:,i+1);
            end
    end
    % Combine two accumulators
    mask = acc1 & acc2;
end


% function mask = Dilate(mask)
%     % Dilate by 1 voxel in 6 directions, except at volume edges
%     % Indices for dimensions excluding ends (2:end-1), except if thin dimension, then it's just 1 or [1 2].
%     nVox = size(mask, [1,2,3]);
%     iVox = {min(2, nVox(1)):max(nVox(1)-1, 1), min(2, nVox(2)):max(nVox(2)-1, 1), min(2, nVox(3)):max(nVox(3)-1, 1)};
% 
%     % Loop so it works on 2d or 3d
%     for iDim = 1:3
%         if nVox(iDim) > 2 % Skip thin dimensions (size 1 or 2)
%             switch iDim
%                 case 1
%                     DilateMask = mask(1:end-2,iVox{2},iVox{3}) | mask(3:end,iVox{2},iVox{3});
%                 case 2
%                     DilateMask = mask(iVox{1},1:end-2,iVox{3}) | mask(iVox{1},3:end,iVox{3});
%                 case 3
%                     DilateMask = mask(iVox{1},iVox{2},1:end-2) | mask(iVox{1},iVox{2},3:end);
%             end
%             mask(iVox{1},iVox{2},iVox{3}) = mask(iVox{1},iVox{2},iVox{3}) | DilateMask;
%         end
%     end
% end


function OutMask = CenterSpread(InMask)
% Similar to Fill, but from a central starting point and intersecting with the input "reference" mask.
% This should work on slices as well as volumes.
OutMask = false(size(InMask));
iStart = max(1,round(size(OutMask)/2));
nVox = size(OutMask);
% Force starting center point to be 1, and spread from there. But this will still fail if it's fully
% surrounded by 0s.
OutMask(iStart(1), iStart(2), iStart(3)) = true;
nPrev = 0;
nOut = 1;
while nOut > nPrev
    % Dilation loop was very slow.
    %     OutMask = OutMask | (Dilate(OutMask) & InMask);
    % Instead, propagate as far as possible in each direction (3 dim, forward & back) at each step
    % of the main loop.
    for x = 2:nVox(1)
        OutMask(x,:,:) = OutMask(x,:,:) | (OutMask(x-1,:,:) & InMask(x,:,:));
    end
    for x = nVox(1)-1:-1:1
        OutMask(x,:,:) = OutMask(x,:,:) | (OutMask(x+1,:,:) & InMask(x,:,:));
    end
    for y = 2:nVox(2)
        OutMask(:,y,:) = OutMask(:,y,:) | (OutMask(:,y-1,:) & InMask(:,y,:));
    end
    for y = nVox(2)-1:-1:1
        OutMask(:,y,:) = OutMask(:,y,:) | (OutMask(:,y+1,:) & InMask(:,y,:));
    end
    for z = 2:nVox(3)
        OutMask(:,:,z) = OutMask(:,:,z) | (OutMask(:,:,z-1) & InMask(:,:,z));
    end
    for z = nVox(3)-1:-1:1
        OutMask(:,:,z) = OutMask(:,:,z) | (OutMask(:,:,z+1) & InMask(:,:,z));
    end
    nPrev = nOut;
    nOut = sum(OutMask(:));
end
if nOut == 1
    % Remove "forced" initial vertex, everything else is now gone.
    OutMask(iStart(1), iStart(2), iStart(3)) = false;
    warning('CenterSpread failed: starting center point is not part of the mask.');
end
end


function [Vol, Vect]  = NormGradient(Vol)
% Norm of the spatial gradient vector field in a regular 3D volume.
[x,y,z] = gradient(Vol);
Vect = cat(4,x,y,z);
Vol = sqrt(sum(Vect.^2, 4));
end


% Modified version to detect duplicate faces based on vertex indices, not strange alignment of face
% normals. 
% TODO: DELETE just started, probably won't keep.
% function [Vertices, Faces, remove_vertices, remove_faces, Atlas] = tess_clean(Vertices, Faces, Atlas)
% % TESS_CLEAN: Check the integrity of a tesselation.
% %
% % USAGE:  [Vertices, Faces, remove_vertices, Atlas] = tess_clean(Vertices, Faces, Atlas)
% %
% % DESCRIPTION:
% %      Check in a tesselation if there are some identical faces and remove the bad_oriented one.
% %      Moreover it removes isolated triangles and some other pathological configurations.
% %
% % INPUTS:
% %    - Vertices : Mx3 double matrix
% %    - Faces    : Nx3 double matrix
% % OUTPUTS:
% %    - Vertices : Corrected vertices structure
% %    - Faces    : Corrected faces structure
% 
% % Authors: Julien Lefevre, 2007
% %          Francois Tadel, 2008-2014
% %          Marc Lalancette, 2025
% 
% % Parse inputs
% if (nargin < 3) || isempty(Atlas)
%     Atlas = [];
% end
% % Check matrix orientation
% if (size(Vertices, 2) ~= 3) || (size(Faces, 2) ~= 3)
%     error('Faces and Vertices must have 3 columns (X,Y,Z).');
% end
% 
% % Face connectivity matrix for edges
% [~, FaceConn] = tess_faceconn(Faces, 2);
% 
% % Items to remove
% remove_faces=[];
% remove_vertices=[];
% 
% % Sort face vertex indices to identify duplicates.
% FacesSrt = sort(Faces, 2);
% [~, iFace, iUniqFace] = unique(FacesSrt, 'rows');
% % UniqFaces = Faces(iFace), Faces = UniqFaces(iUniqFace)
% % For each unique item, check if multiple copies in iUniqFace
% for iU = 1:numel(iFace)
%     if sum(iUniqFace == iU) > 1
%         isFaceSuspect = iUniqFace == iU;
% 
%         iRemoveFace(end+1) = i
% 
% TessArea = tess_area(Vertices, Faces);
% [~, FaceNormals] = tess_normals(Vertices, Faces);
% 
% sort_crossprod = sortrows(abs([FaceNormals,(1:size(FaceNormals,1))']));
% diff_sort_crossprod = diff(sort_crossprod);
% indices = find((diff_sort_crossprod(:,1) < tol) & ...
%                (diff_sort_crossprod(:,2) < tol) & ...
%                (diff_sort_crossprod(:,3) < tol));
% % Indices of redundant triangles (same coordinates, two different orientations)
% indices_tri1 = sort_crossprod(indices,4); 
% indices_tri2 = sort_crossprod(indices+1,4);
% 
% [VertFacesConn, FaceConn] = tess_faceconn(Faces);
% 
% % For each suspected face we compute the mean of normals of neighbouring faces
% scal=zeros(length(indices_tri1),2);
% 
% % We remove faces whose normal is not in the same direction as their neighbouring faces
% for i=1:length(indices_tri1)
%     neighbours = find(FaceConn(indices_tri1(i),:));
%     neighbours = setdiff(neighbours, indices_tri2(i));
%     % Isolated faces
%     if isempty(neighbours) 
%         remove_faces    = [remove_faces,    indices_tri1(i), indices_tri2(i)];
%         remove_vertices = [remove_vertices, Faces(indices_tri1(i),:)];
%     else
%         normal_mean = mean(FaceNormals(neighbours,:) .* repmat(TessArea(neighbours),1,3),1);
%         norm_i = FaceNormals(indices_tri1(i),:);
%         scal(i,1) = normal_mean*norm_i'/(norm(normal_mean));
% 
%         if scal(i,1)>0
%             remove_faces = [remove_faces,indices_tri2(i)];
%             scal(i,2) = indices_tri2(i);
%         else
%             if scal(i,1)<0
%                 remove_faces = [remove_faces,indices_tri1(i)];
%                 scal(i,2) = indices_tri1(i);
%             else
%                 remove_faces = [remove_faces,indices_tri1(i),indices_tri2(i)];
%                 remove_vertices = [remove_vertices, Faces(indices_tri1(i),:)];
%             end
%         end
%     end
% end
% 
% % Find all the isolated faces
% FaceConn(remove_faces, :) = 0;
% FaceConn(:, remove_faces) = 0;
% iIsolatedFaces = find(sum(FaceConn) <= 1);
% remove_faces = union(remove_faces', iIsolatedFaces);
% % Remove faces
% Faces(remove_faces, :) = [];
% 
% % Find the vertices that are not used in any face
% VertConn = tess_vertconn(Vertices, Faces);
% iIsolatedVert = find(sum(VertConn) <= 1);
% remove_vertices = union(remove_vertices, iIsolatedVert);
% % Remove vertices
% [Vertices, Faces, Atlas] = tess_remove_vert(Vertices, Faces, remove_vertices, Atlas);
% 
% end

