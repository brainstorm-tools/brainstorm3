function [MriFileOut, errMsg, SurfaceFileOut] = pet_process(PetFile, AtlasName, roiName, maskROI, applyMask, doProject)
% PET_PROCESS: Script PET processing pipeline (SUVR rescale and/or masking) with minimal redundant saving.
%
% INPUTS:
%   - PetFile   : PET file path
%   - AtlasFile : Name of anatomical Atlas
%   - roiName   : Name of the ROI for SUVR rescale (string, can be empty)
%   - maskROI   : Name of the ROI for masking (string, can be empty)
%   - applyMask : Logical, true to apply mask, false otherwise
%   - doProject : Logical, true to project PET to surface, false otherwise
%
% OUTPUTS:
%   - MriFileOut    : Output MRI file path (string)
%   - errMsg        : Error message, if any
%   - SurfaceFileOut: Output surface file path (string, if projected)
%
% USAGE:  [MriFileOut, errMsg, SurfaceFileOut] = pet_process(PetFile, AtlasName, roiName, maskROI, applyMask, doProject, pvcOpts)
%         [sMriSuvr, info] = pet_process('ComputeSuvr', sMriPet, sAseg, Opts) : SUVR with a robust reference region
%
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
% Authors: Diellor Basha, 2025

% ===== CALL A SUBFUNCTION =====
if (nargin >= 2) && ischar(PetFile) && strcmp(PetFile, 'ComputeSuvr')
    if (nargin < 3), roiName = []; end
    if (nargin < 4), maskROI = []; end
    [MriFileOut, errMsg] = ComputeSuvr(AtlasName, roiName, maskROI);
    return;
end

MriFileOut = '';
SurfaceFileOut = '';
errMsg = '';
if nargin < 6 || isempty(doProject)
    doProject = 0;
end

try
    % Get Subject for PET file
    [sSubject, iSubject] = bst_get('MriFile', PetFile);
    % Load Atlas file
    [~, iAtlas] = ismember(AtlasName, {sSubject.Anatomy.Comment});
    if iAtlas
        AtlasName = sSubject.Anatomy(iAtlas).FileName;
    end
    sAtlas = in_mri_bst(AtlasName);
    % Load PET file in sMRI structure
    sMri = in_mri_bst(PetFile);
    orgComment = sMri.Comment;

    % --- SUVR Rescale ---
    if ~isempty(roiName)
        [~, sMriRescale, errMsgRescale, fileTagRescale] = mri_rescale(sMri, sAtlas, roiName);
        if ~isempty(errMsgRescale)
            errMsg = errMsgRescale;
            return;
        end
        sMri = sMriRescale;
        fileTag = fileTagRescale;
    else
        fileTag = '';
    end

    % --- Masking (if requested) ---
    if applyMask && ~isempty(maskROI)
        [~, sMriMasked, errMsgMask, fileTagMask] = mri_mask(sMri, sAtlas, maskROI, 1);
        if ~isempty(errMsgMask)
            errMsg = errMsgMask;
            return;
        end
        sMri = sMriMasked;
        % Combine tags for output file
        fileTag = [fileTag, fileTagMask];
    end

    % --- Save output file manually (like mri_realign) ---
    % Insert fileTag before last underscore
    [folder, base, ext] = fileparts(file_fullpath(PetFile));
    lastUnderscore = find(base == '_', 1, 'last');
    if ~isempty(lastUnderscore)
        newBase = [base(1:lastUnderscore-1), fileTag, base(lastUnderscore:end)];
    else
        newBase = [base, fileTag];
    end
    MriFileOutFull = file_unique(fullfile(folder, [newBase, ext]));
    MriFileOut = file_short(MriFileOutFull);

    % Update comment to be unique
    sSubject = bst_get('Subject', iSubject);
    sMri.Comment = file_unique([orgComment, fileTag], {sSubject.Anatomy.Comment});

    % Add history entry
    if ~isempty(roiName)
        sMri = bst_history('add', sMri, 'rescale', sprintf('Rescaled with "%s" (%s)', sAtlas.Comment, roiName));
    end
    if applyMask && ~isempty(maskROI)
        sMri = bst_history('add', sMri, 'mask', sprintf('Masked with "%s" (%s)', sAtlas.Comment, maskROI));
    end

    % Save new MRI in Brainstorm format
    sMri = out_mri_bst(sMri, MriFileOutFull);

    % Register new MRI in subject
    iAnatomy = length(sSubject.Anatomy) + 1;
    sSubject.Anatomy(iAnatomy) = db_template('Anatomy');
    sSubject.Anatomy(iAnatomy).FileName = MriFileOut;
    sSubject.Anatomy(iAnatomy).Comment  = sMri.Comment;
    bst_set('Subject', iSubject, sSubject);

    % Refresh tree and save database
    panel_protocols('UpdateNode', 'Subject', iSubject);
    panel_protocols('SelectNode', [], 'anatomy', iSubject, iAnatomy);
    db_save();

    % --- Overlay processed PET on subject's default MRI ---
    if isfield(sSubject, 'iAnatomy') && ~isempty(sSubject.iAnatomy) && ...
            isfield(sSubject, 'Anatomy') && length(sSubject.Anatomy) >= sSubject.iAnatomy
        refMriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
    else
        refMriFile = sSubject.Anatomy(1).FileName;
    end
    view_mri(refMriFile, MriFileOut);

    % --- Project to surface if requested ---
    if doProject
        % Use the same reference MRI as above
        % Use the subject's name as the condition
        Condition = 'PET';
        DisplayUnits = '';
        ProjFrac = [0.1 0.4 0.5];
        [SurfaceFileOut, errProj] = mri_interp_vol2tess(MriFileOut, refMriFile, Condition, DisplayUnits, ProjFrac);
        if ~isempty(errProj)
            errMsg = ['PET processed, but projection failed: ', errProj];
        end
    end

catch ME
    errMsg = ME.message;
end
end


%% ===== SUVR: ROBUST REFERENCE REGION =====
function [sMriSuvr, info] = ComputeSuvr(sMriPet, sAseg, Opts)
% SUVR normalization with a robust, erosion-cleaned reference region.
%
% Upgrades the plain "mean over an ROI" rescale (mri_rescale) with the two things a reference
% region needs to be trustworthy:
%   - EROSION: peel Opts.Erode voxels off the reference mask so its boundary (which is partial-
%     volume-contaminated by neighbouring tissue/CSF) does not bias the reference downward.
%   - ROBUST estimator: a trimmed mean (default) over the eroded interior, rejecting the residual
%     outlier voxels (mis-segmentation, vessels, spill) that a plain mean is sensitive to.
% SUVR = PET / reference. Reference defaults to the cerebellar cortex (ASEG labels 8 + 47), a
% common amyloid reference (the Centiloid standard itself uses the whole cerebellum). For tau
% the inferior cerebellar GM (SUIT) is
% preferable; pass Opts.RefLabels for the available segmentation.
%
% Both volumes must be on the same grid (PET resliced to the anatomy; ASEG in anatomy space).
%
% USAGE:  [sMriSuvr, info] = pet_process('ComputeSuvr', sMriPet, sAseg, Opts)
%
% INPUTS:
%   sMriPet : (PVC'd) static PET MRI struct, resliced to the anatomy grid.
%   sAseg   : ASEG volume atlas struct (.Cube of integer labels) on the same grid. May be []
%             if Opts.RefMask is supplied.
%   Opts    : .RefMask (precomputed binary reference mask; overrides RefLabels/sAseg)
%             .RefLabels (default [8 47]) .Erode (voxels, 1) .Robust ('trim'|'mean'|'median')
%             .TrimPct (each-tail fraction for 'trim', 0.10).
%
% OUTPUTS:
%   sMriSuvr : SUVR volume (Cube ./ reference), Comment/History updated.
%   info     : struct(.RefValue,.nVoxMask,.nVoxEroded,.RefMean,.RefMedian,.RefTrim,.Erode,.Robust).
%
% SEE ALSO: pet_process, pet_pvc, mri_rescale

    if (nargin<3)||isempty(Opts), Opts=struct(); end
    Def=struct('RefMask',[],'RefLabels',[8 47],'Erode',1,'Robust','trim','TrimPct',0.10);
    fn=fieldnames(Def); for i=1:numel(fn), if ~isfield(Opts,fn{i}), Opts.(fn{i})=Def.(fn{i}); end; end

    cube = double(sMriPet.Cube(:,:,:,1));
    % Reference mask: precomputed (any region, from the caller) or built from ASEG labels.
    if ~isempty(Opts.RefMask)
        mask = logical(Opts.RefMask);
    elseif ~isempty(sAseg)
        mask = ismember(sAseg.Cube, Opts.RefLabels);
    else
        error('pet_process:SuvrRef', 'Provide Opts.RefMask, or sAseg + Opts.RefLabels.');
    end
    if ~isequal(size(cube), size(mask))
        error('pet_process:SuvrGrid', 'PET grid %s != reference mask grid %s (reslice PET to anatomy first).', ...
              mat2str(size(cube)), mat2str(size(mask)));
    end
    er = mask; for k=1:Opts.Erode, er = local_erode(er); end
    if nnz(er) < 50, er = mask; end                      % erosion too aggressive -> fall back

    vals = cube(er); vals = vals(isfinite(vals) & vals>0);
    if isempty(vals)
        error('pet_process:SuvrEmptyref', 'Reference region contains no positive finite PET values.');
    end
    vs = sort(vals); t = round(Opts.TrimPct*numel(vs));
    if (2*t >= numel(vs)), t = 0; end                    % too few voxels to trim
    refTrim = mean(vs(t+1:end-t));
    switch lower(Opts.Robust)
        case 'mean',   ref = mean(vals);
        case 'median', ref = median(vals);
        otherwise,     ref = refTrim;
    end

    sMriSuvr = sMriPet;
    sMriSuvr.Cube = double(sMriPet.Cube) ./ ref;         % double: an integer cube would round the SUVR
    sMriSuvr.Comment = [sMriPet.Comment '_suvr'];
    sMriSuvr = bst_history('add', sMriSuvr, 'suvr', sprintf( ...
        'SUVR ref=%.4g (labels %s, erode %d, %s); mask %d->%d vox', ...
        ref, mat2str(Opts.RefLabels), Opts.Erode, Opts.Robust, nnz(mask), nnz(er)));

    info = struct('RefValue',ref,'nVoxMask',nnz(mask),'nVoxEroded',nnz(er), ...
                  'RefMean',mean(vals),'RefMedian',median(vals),'RefTrim',refTrim, ...
                  'Erode',Opts.Erode,'Robust',Opts.Robust);
end

function e = local_erode(m)
    % 1-voxel 6-connectivity erosion (no Image Processing Toolbox dependency)
    e = m & circshift(m,[1 0 0]) & circshift(m,[-1 0 0]) & circshift(m,[0 1 0]) ...
          & circshift(m,[0 -1 0]) & circshift(m,[0 0 1]) & circshift(m,[0 0 -1]);
end
