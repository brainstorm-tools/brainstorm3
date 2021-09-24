function [OutputSurfaces, OutputMri] = bst_warp(destPts, srcPts, SurfaceFiles, MriFile, OutputTag, OutputDir, isSurfaceOnly)
%BST_WARP:  Deform an anatomy (MRI+surfaces) to fit a set of landmarks.
%
% USAGE:  bst_warp(destPts, srcPts, SurfaceFiles, MriFile, warped_surface_file, warped_mr_file, isSurfaceOnly)
%
% INPUTS:
%     - destPts      : landmarks in real head coordinates, i.e. from a Polhemus or
%     - srcPts       : landmarks in intial anatomy coordinates
%     - SurfaceFiles : Cell array of the surface files to be warped (full path)
%     - MriFile      : MRI file name (full path)
%     - OutputTag    : Tag to add at the end of the filenames of the wrapped files
%     - OutputDir    : Output directory
%     - isSurfaceOnly: If 1, do not warp the MRI

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
% Authors: Felix Darvas, 2005
%          Louis Hovasse, 2009
%          Francois Tadel, 2010-212

if (nargin < 7) || isempty(isSurfaceOnly)
    isSurfaceOnly = 0;
end
OutputSurfaces = {};
OutputMri = [];


%% ===== COMPUTE WARP PARAMETER =====
% Compute warp transform parameters
[W,A] = warp_transform(srcPts, destPts); 


%% ===== WARP SURFACES =====
% Progress bar
nFiles = length(SurfaceFiles);
bst_progress('start', 'Warp anatomy', 'Warping surfaces...', 0, nFiles);
% Loop on all surface files
for i = 1:length(SurfaceFiles)
    bst_progress('inc', 1);
    % Read input 
    sSurf = in_tess_bst(SurfaceFiles{i});
    % Warp surface
    sSurfNew.Faces    = sSurf.Faces;
    sSurfNew.Vertices = warp_lm(sSurf.Vertices, A, W, srcPts) + sSurf.Vertices;
    sSurfNew.Comment  = [sSurf.Comment ' warped'];
    % Copy previous field
    if isfield(sSurf, 'Atlas') && ~isempty(sSurf.Atlas)
        sSurfNew.Atlas = sSurf.Atlas;
    end
    if isfield(sSurf, 'Reg') && ~isempty(sSurf.Reg)
        sSurfNew.Reg = sSurf.Reg;
    end
    if isfield(sSurf, 'History') && ~isempty(sSurf.History)
        sSurfNew.History = sSurf.History;
    end
    % History: Warp
    sSurfNew = bst_history('add', sSurfNew, 'warp', 'Surface deformed to match the head points from channel file.');
    
    % Output filename
    [tmp__, fileBase, fileExt] = bst_fileparts(SurfaceFiles{i});
    OutputSurfaces{i} = bst_fullfile(OutputDir, [fileBase, OutputTag, fileExt]);
    % Save new file
    bst_save(OutputSurfaces{i}, sSurfNew, 'v7');
end

   
%% ====== WARP MRI ========
bst_progress('start', 'Warp anatomy', 'Preparing MRI...');
% Load MRI
sMriSrc = in_mri_bst(MriFile);
% Transform landmarks into MRI coordinates (meters)
srcPts_mr  = cs_convert(sMriSrc, 'scs', 'voxel', srcPts);
destPts_mr = cs_convert(sMriSrc, 'scs', 'voxel', destPts);
% Compute warp transform in MR coordinates
[Wmr,Amr] = warp_transform(srcPts_mr, destPts_mr); 
% Compute "inverse" warp transform in MR coordinates 
[Wmr_inv,Amr_inv] = warp_transform(destPts_mr, srcPts_mr);

% If not only the surfaces
if ~isSurfaceOnly
    % Process coordinates by blocks: Doing all at once costs too much memory, doing only 1 at a time costs too much time
    bst_progress('start', 'Warp anatomy', 'Warping MRI...', 1, 100);
    sizeMri = size(sMriSrc.Cube);
    if (length(sizeMri) > 3)
        error('No support for 4D volumes. Ask on the Brainstorm for help.');
    end
    newCube = ones(sizeMri);
    nVoxels = numel(newCube);
    BLOCK_SIZE = 10000; 
    nBlocks = ceil(nVoxels / BLOCK_SIZE);
    ix0 = 1;
    for i = 1:nBlocks
        % Increment progress bar
        if (mod(i, round(nBlocks/100)) == 0)
            bst_progress('inc', 1);
        end
        % Get indices in dest volume 
        ix1 = min(ix0 - 1 + BLOCK_SIZE, nVoxels);
        [xv,yv,zv] = ind2sub(sizeMri, ix0:ix1);
        rv = [xv;yv;zv]';
        % Unwarp MRI coordinates
        rv_inv = warp_lm(rv, Amr_inv, Wmr_inv, destPts_mr) + rv;
        % Round coordinates (nearest neighor interpolation)
        rv_inv = round(rv_inv);
        % Remove values that are outside the volume
        iOutside = find(sum((rv_inv < 1) | (rv_inv > repmat(sizeMri,size(rv_inv,1),1)),2) > 0);
        rv_inv(iOutside,:) = 1;
        % Get indices from xyz coordinates
        ix_inv = sub2ind(sizeMri, rv_inv(:,1), rv_inv(:,2), rv_inv(:,3));
        % Get values in initial volume
        newCube(ix0:ix1) = sMriSrc.Cube(ix_inv);
        % Set values outside of the volume to zero
        newCube(iOutside) = 0;
        % Go to next block
        ix0 = ix1 + 1;
    end
    clear rv
    newComment = [sMriSrc.Comment, ' warped'];
else
    newCube = sMriSrc.Cube;
    newComment = sMriSrc.Comment;
end

% ===== WRAP FIDUCIALS =====
% % SCS transformation
% destSCS.NAS = warp_lm(sMriSrc.SCS.NAS, Amr, Wmr, srcPts_mr) + sMriSrc.SCS.NAS;
% destSCS.LPA = warp_lm(sMriSrc.SCS.LPA, Amr, Wmr, srcPts_mr) + sMriSrc.SCS.LPA;
% destSCS.RPA = warp_lm(sMriSrc.SCS.RPA, Amr, Wmr, srcPts_mr) + sMriSrc.SCS.RPA;
% NCS transformation
if isfield(sMriSrc, 'NCS') && isfield(sMriSrc.NCS, 'AC') && ~isempty(sMriSrc.NCS.AC) && ~isempty(sMriSrc.NCS.PC) && ~isempty(sMriSrc.NCS.IH)
    destNCS.AC = warp_lm(sMriSrc.NCS.AC, Amr, Wmr, srcPts_mr) + sMriSrc.NCS.AC;
    destNCS.PC = warp_lm(sMriSrc.NCS.PC, Amr, Wmr, srcPts_mr) + sMriSrc.NCS.PC;
    destNCS.IH = warp_lm(sMriSrc.NCS.IH, Amr, Wmr, srcPts_mr) + sMriSrc.NCS.IH;
    destNCS.R = [];
    destNCS.T = [];
    destNCS.Origin = [];
else
    destNCS = [];
end

%% ===== SAVE NEW MRI ====
bst_progress('start', 'Warp anatomy', 'Saving warped MRI...');
% Create new structure
sMriDest = sMriSrc;
sMriDest.Cube    = newCube;
sMriDest.Comment = newComment;
sMriDest.NCS     = destNCS;

% History: Copy previous field
if isfield(sMriSrc, 'History') && ~isempty(sMriSrc.History)
    sMriDest.History = sMriSrc.History;
end
% History: Warp
sMriDest = bst_history('add', sMriDest, 'warp', 'MRI deformed to match the head points from channel file.');
    
% Output filename
[tmp__, fileBase, fileExt] = bst_fileparts(MriFile);
OutputMri = bst_fullfile(OutputDir, [fileBase, OutputTag, fileExt]);
% Save new MRI
bst_save(OutputMri, sMriDest, 'v7');

bst_progress('stop');

end



%% =====================================================================================
%  ===== HELPER FUNCTIONS ==============================================================
%  =====================================================================================

%% ===== WARP TRANSFORM =====
% Calculates nonlinear transformation coefficents (see Ermer's Thesis)
% INPUT:  
%    - p : Landmarks in system 1
%    - q : Landmarks in system 2
% OUTPUT:
%    - e : Warp energy
function [W,A,e] = warp_transform(p, q)
    N = size(p,1);
    px = repmat(p(:,1), 1, N);
    py = repmat(p(:,2), 1, N);
    pz = repmat(p(:,3), 1, N);
    K = sqrt((px - px').^2 + (py - py').^2 + (pz - pz').^2);

    P = [p, ones(N,1)];
    L = [K P; P' zeros(4,4)];
    D = [q - p; zeros(4,3)];
    warning off
    H = L \ D;
    warning on
    if any(isnan(H))
        H = pinv(L) * D;
    end
    W = H(1:N,:);
    A = H(N+1:end, :);
    e = sum(diag(W' * K * W));
end


%% ===== WARP LANDMARKS: VECTORIZED =====
% Performs warp transformation with linear 3D RFB (see Ermer's Thesis)
function rw = warp_lm(r, A, W, p)
    rw = r * A(1:3,1:3);
    rw = bst_bsxfun(@plus, rw, A(4,:));
    np = size(p,1);
    U = sqrt(bst_bsxfun(@minus, repmat(r(:,1),1,np), p(:,1)') .^ 2 + ...
             bst_bsxfun(@minus, repmat(r(:,2),1,np), p(:,2)') .^ 2 + ...
             bst_bsxfun(@minus, repmat(r(:,3),1,np), p(:,3)') .^ 2);
    rw = rw + U * W;   
end

%% ===== WARP LANDMARKS: LOOP VERSION =====
% This function is twice slower
% function rw = warp_lm(r, A, W, p)
%     rw = r * A(1:3,1:3) + repmat(A(4,:), size(r,1), 1);
%     for i = 1:size(p,1)
%         U = sqrt(sum((r - repmat(p(i,:), size(r,1), 1)) .^ 2, 2));
%         rw = rw + U * W(i,:);
%     end
% end

