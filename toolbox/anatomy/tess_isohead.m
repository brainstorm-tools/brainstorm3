function [HeadFile, iSurface] = tess_isohead(iSubject, nVertices, erodeFactor, fillFactor, Comment, bgLevel, isGradient)
% TESS_GENERATE: Reconstruct a head surface based on the MRI, based on an isosurface
%
% USAGE:  [HeadFile, iSurface] = tess_isohead(iSubject, nVertices=10000, erodeFactor=0, fillFactor=2, Comment)
%         [HeadFile, iSurface] = tess_isohead(MriFile,  nVertices=10000, erodeFactor=0, fillFactor=2, Comment)
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

%% ===== PARSE INPUTS =====
% Initialize returned variables
HeadFile = [];
iSurface = [];
isSave = true;
% Parse inputs
if (nargin < 7) || isempty(isGradient)
    isGradient = false;
end
if (nargin < 6) || isempty(bgLevel)
    bgLevel = [];
end
if (nargin < 5) || isempty(Comment)
    Comment = [];
end
% MriFile instead of subject index
sMri = [];
if ischar(iSubject)
    MriFile = iSubject;
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

%% ===== ASK PARAMETERS =====
% Ask user to set the parameters if they are not set
if (nargin < 4) || isempty(erodeFactor) || isempty(nVertices)
    res = java_dialog('input', {'Number of vertices [integer]:', 'Erode factor [0,1,2,3]:', 'Fill holes factor [0,1,2,3]:', '<HTML>Background threshold:<BR>(guessed from MRI histogram)'}, 'Generate head surface', [], {'15000', '0', '0', num2str(sMri.Histogram.bgLevel)});
    % If user cancelled: return
    if isempty(res)
        return
    end
    % Get new values
    nVertices   = str2num(res{1});
    erodeFactor = str2num(res{2});
    fillFactor  = str2num(res{3});
    bgLevel     = str2num(res{4});
    if isempty(bgLevel)
        bgLevel = sMri.Histogram.bgLevel;
    end
elseif isempty(bgLevel) && ~isGradient
    bgLevel = sMri.Histogram.bgLevel;
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
    [Grad, VectGrad] = NormGradient(sMri.Cube(:,:,:,1));
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
    % Edit second and second-to-last slices
    Slice = TempMask(2, :, :);
    TempMask(2, :, :) = Slice | (Fill(Slice, 2) & Fill(Slice, 3));
    Slice = TempMask(end-1, :, :);
    TempMask(end-1, :, :) = Slice | (Fill(Slice, 2) & Fill(Slice, 3));
    % Permute back
    headmask = permute(TempMask, Perm);
end
% Fill holes
InsideMask = (Fill(headmask, 1) & Fill(headmask, 2) & Fill(headmask, 3));
headmask = InsideMask | (Dilate(InsideMask) & headmask);
% Keep only central connected volume (trim "beard" or bubbles)
headmask = CenterSpread(headmask);
bst_progress('inc', 15);

% view_mri_slices(headmask, 'x', 20)


%% ===== CREATE SURFACE =====
% Compute isosurface
bst_progress('text', 'Creating isosurface...');
% Could have avoided x-y flip by specifying XYZ in isosurface...
[sHead.Faces, sHead.Vertices] = mri_isosurface(headmask, 0.5);
% Flip x-y back to our voxel coordinates.
sHead.Vertices = sHead.Vertices(:, [2, 1, 3]);
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
[sHead.Vertices, sHead.Faces] = tess_remove_small(sHead.Vertices, sHead.Faces);
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
bst_progress('inc', 20);

% Downsampling isosurface
if (length(sHead.Vertices) > nVertices)
    bst_progress('text', 'Downsampling surface...');
    [sHead.Faces, sHead.Vertices] = reducepatch(sHead.Faces, sHead.Vertices, nVertices./length(sHead.Vertices));
    bst_progress('inc', 15);
end

bst_progress('text', 'Smoothing...');
sHead.Vertices = SurfaceSmooth(sHead.Vertices, sHead.Faces, 2, [], 45, 0, false); % voxel/smoothing size, iterations, freedom (normal), verbose
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
function mask = Fill(mask, dim)
% Modified to exclude boundaries, so we can get rid of external junk as well as
% internal holes easily.

% Initialize two accumulators, for the two directions
acc1 = false(size(mask));
acc2 = false(size(mask));
n = size(mask,dim);
% Process in required direction
switch dim
    case 1
        for i = 2:n
            acc1(i,:,:) = acc1(i-1,:,:) | mask(i-1,:,:);
        end
        for i = n-1:-1:1
            acc2(i,:,:) = acc2(i+1,:,:) | mask(i+1,:,:);
        end
    case 2
        for i = 2:n
            acc1(:,i,:) = acc1(:,i-1,:) | mask(:,i-1,:);
        end
        for i = n-1:-1:1
            acc2(:,i,:) = acc2(:,i+1,:) | mask(:,i+1,:);
        end
    case 3
        for i = 2:n
            acc1(:,:,i) = acc1(:,:,i-1) | mask(:,:,i-1);
        end
        for i = n-1:-1:1
            acc2(:,:,i) = acc2(:,:,i+1) | mask(:,:,i+1);
        end
end
% Combine two accumulators
mask = acc1 & acc2;
end

function mask = Dilate(mask)
% Dilate by 1 voxel in 6 directions, except at volume edges
mask(2:end-1,2:end-1,2:end-1) = mask(1:end-2,2:end-1,2:end-1) | mask(3:end,2:end-1,2:end-1) | ...
    mask(2:end-1,1:end-2,2:end-1) | mask(2:end-1,3:end,2:end-1) | ...
    mask(2:end-1,2:end-1,1:end-2) | mask(2:end-1,2:end-1,3:end);
end

function OutMask = CenterSpread(InMask)
% Similar to Fill, but from a central starting point and intersecting with the input "reference" mask.
OutMask = false(size(InMask));
iStart = round(size(OutMask)/2);
nVox = size(OutMask);
OutMask(iStart(1), iStart(2), iStart(3)) = true;
nPrev = 0;
nOut = 1;
while nOut > nPrev
    % Dilation loop was very slow.
    %     OutMask = OutMask | (Dilate(OutMask) & InMask);
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
end


function [Vol, Vect]  = NormGradient(Vol)
% Norm of the spatial gradient vector field in a regular 3D volume.
[x,y,z] = gradient(Vol);
Vect = cat(4,x,y,z);
Vol = sqrt(sum(Vect.^2, 4));
end
