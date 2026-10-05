function [MriFilePvc, errMsg, fileTag] = pet_pvc(PetFile, MriFileRef, fwhm, pvcOpts)
% PET_PVC: Partial volume correction for PET volumes using PETPVE12 (Muller-Gartner method).
%
% USAGE:
%   [MriFilePvc, errMsg, fileTag] = pet_pvc(PetFile, MriFileRef, fwhm)
%   [MriFilePvc, errMsg, fileTag] = pet_pvc(PetFile, MriFileRef, fwhm, pvcOpts)
%
% DESCRIPTION:
%   Performs partial volume correction on a PET volume using the Muller-Gartner
%   method implemented in PETPVE12. The function:
%     1. Exports the reference MRI to NIfTI in a temp directory
%     2. Runs SPM Segment on the MRI to produce probabilistic tissue maps (c1, c2, c3)
%     3. Exports the PET volume to NIfTI in the same temp directory
%     4. Calls PETPVE12's geg_PVEcorrection with the tissue maps and PET
%     5. Imports the corrected PET back into Brainstorm
%     6. Cleans up the temp directory
%
% INPUTS:
%   - PetFile    : PET MRI file to correct (Brainstorm relative path)
%   - MriFileRef : Reference MRI file for tissue segmentation (Brainstorm relative path)
%   - fwhm       : PSF FWHM in mm (scalar or [x y z] vector)
%   - pvcOpts    : (optional) Structure with additional PVC options:
%       .gmThresh    : GM threshold for masking (default: 0.5)
%       .csfZeroing  : If 1, assume CSF signal = 0 (default: 1)
%       .wmcsfMethod : WM/CSF constant estimation method (default: 'threshold')
%                      Options: 'threshold', 'erode'
%       .wmcsfThresh : Threshold/erosion value for WM/CSF estimation (default: 0.5)
%
% OUTPUTS:
%   - MriFilePvc : Relative path to the PVC-corrected PET file in Brainstorm DB
%   - errMsg     : Error message, if any
%   - fileTag    : File tag used for output file
%
% REQUIRES:
%   - SPM12 plugin (for tissue segmentation)
%   - PETPVE12 plugin (for Muller-Gartner PVC)

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

% Initialize outputs
MriFilePvc = [];
errMsg = '';
fileTag = '_pvc';

% ===== PARSE INPUTS =====
if nargin < 3 || isempty(fwhm)
    % No FWHM supplied: derive it from the PET metadata (scanner model + recon
    % filter), falling back to a generic clinical value if the scanner is unknown.
    PET = [];
    try
        w = load(file_fullpath(PetFile), 'PET');
        if isfield(w, 'PET'), PET = w.PET; end
    catch
    end
    [fwhm, fwhmSrc] = pet_helper('ScannerFwhm', PET);
    fprintf('BST> PET PVC: PSF FWHM = %.1f mm [%s]\n', fwhm, fwhmSrc);
end
% Expand scalar FWHM to 3D vector
if isscalar(fwhm)
    fwhm = [fwhm fwhm fwhm];
end
% Default PVC options
if nargin < 4 || isempty(pvcOpts)
    pvcOpts = struct();
end
% ===== METHOD DISPATCH =====
% GTM (regional Rousset) is a native path - corrects all regions, needs neither SPM nor
% PETPVE12 (uses the subject's parcellation directly). MG (default) continues below.
if isfield(pvcOpts, 'method') && strcmpi(pvcOpts.method, 'gtm')
    [MriFilePvc, errMsg] = ComputeGtm(PetFile, fwhm, pvcOpts);
    fileTag = '_gtmpvc';
    return;
end
if ~isfield(pvcOpts, 'gmThresh')    || isempty(pvcOpts.gmThresh),    pvcOpts.gmThresh    = 0.5;         end
if ~isfield(pvcOpts, 'csfZeroing')  || isempty(pvcOpts.csfZeroing),  pvcOpts.csfZeroing  = 1;           end
if ~isfield(pvcOpts, 'wmcsfMethod') || isempty(pvcOpts.wmcsfMethod), pvcOpts.wmcsfMethod = 'threshold'; end
if ~isfield(pvcOpts, 'wmcsfThresh') || isempty(pvcOpts.wmcsfThresh), pvcOpts.wmcsfThresh = 0.5;         end

% ===== CHECK PLUGINS =====
% SPM12: Install if needed, then load
[isOk, errInstall] = bst_plugin('Install', 'spm12', 1);
if ~isOk
    errMsg = ['SPM12 plugin is required: ' errInstall];
    return;
end
bst_plugin('Load', 'spm12');
% PETPVE12: Install if needed, then load
[isOk, errInstall] = bst_plugin('Install', 'petpve12', 1);
if ~isOk
    errMsg = ['PETPVE12 plugin is required: ' errInstall];
    return;
end
bst_plugin('Load', 'petpve12');

% ===== PROGRESS BAR =====
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'PET PVC', 'Loading input volumes...');
end

try
    % ===== LOAD INPUTS =====
    sMriPet = in_mri_bst(PetFile);
    sMriRef = in_mri_bst(MriFileRef);

    % ===== CREATE TEMP DIRECTORY =====
    TmpDir = bst_get('BrainstormTmpDir', 0, 'petpvc');

    % ===== EXPORT REFERENCE MRI TO NIFTI =====
    bst_progress('text', 'Running SPM tissue segmentation...');
    MriNiiFile = bst_fullfile(TmpDir, 'pvc_mri.nii');
    out_mri_nii(sMriRef, MriNiiFile);

    % ===== RUN SPM SEGMENTATION =====
    % Get TPM file from SPM
    TpmFile = bst_get('SpmTpmAtlas');
    if isempty(TpmFile)
        error('Could not find SPM TPM atlas.');
    end
    % Prepare SPM batch for tissue segmentation
    matlabbatch = {};
    matlabbatch{1}.spm.spatial.preproc.channel(1).vols  = {[MriNiiFile ',1']};
    matlabbatch{1}.spm.spatial.preproc.channel(1).biasreg  = 0.001;
    matlabbatch{1}.spm.spatial.preproc.channel(1).biasfwhm = 60;
    matlabbatch{1}.spm.spatial.preproc.channel(1).write = [0 0];
    % Tissue classes: GM, WM, CSF (native space only, no warped)
    for iTiss = 1:3
        matlabbatch{1}.spm.spatial.preproc.tissue(iTiss).tpm    = {[TpmFile, ',' num2str(iTiss)]};
        matlabbatch{1}.spm.spatial.preproc.tissue(iTiss).native = [1 0];
        matlabbatch{1}.spm.spatial.preproc.tissue(iTiss).warped = [0 0];
    end
    % Fix ngaus per tissue class
    matlabbatch{1}.spm.spatial.preproc.tissue(1).ngaus = 1;  % GM
    matlabbatch{1}.spm.spatial.preproc.tissue(2).ngaus = 1;  % WM
    matlabbatch{1}.spm.spatial.preproc.tissue(3).ngaus = 2;  % CSF
    % Remaining tissue classes (skull, scalp, air) - needed by SPM but not used
    for iTiss = 4:6
        matlabbatch{1}.spm.spatial.preproc.tissue(iTiss).tpm    = {[TpmFile, ',' num2str(iTiss)]};
        matlabbatch{1}.spm.spatial.preproc.tissue(iTiss).native = [0 0];
        matlabbatch{1}.spm.spatial.preproc.tissue(iTiss).warped = [0 0];
    end
    matlabbatch{1}.spm.spatial.preproc.tissue(4).ngaus = 3;
    matlabbatch{1}.spm.spatial.preproc.tissue(5).ngaus = 4;
    matlabbatch{1}.spm.spatial.preproc.tissue(6).ngaus = 2;
    % Warp settings
    matlabbatch{1}.spm.spatial.preproc.warp.mrf     = 1;
    matlabbatch{1}.spm.spatial.preproc.warp.cleanup  = 1;
    matlabbatch{1}.spm.spatial.preproc.warp.reg      = [0 0.001 0.5 0.05 0.2];
    matlabbatch{1}.spm.spatial.preproc.warp.affreg   = 'mni';
    matlabbatch{1}.spm.spatial.preproc.warp.fwhm     = 0;
    matlabbatch{1}.spm.spatial.preproc.warp.samp     = 3;
    matlabbatch{1}.spm.spatial.preproc.warp.write    = [0 0];  % No deformation fields needed
    matlabbatch{1}.spm.spatial.preproc.warp.vox      = NaN;
    matlabbatch{1}.spm.spatial.preproc.warp.bb       = [NaN NaN NaN; NaN NaN NaN];
    % Suppress warnings and run
    warning('off', 'MATLAB:RandStream:ActivatingLegacyGenerators');
    spm_jobman('initcfg');
    spm_jobman('run', matlabbatch);
    warning('on', 'MATLAB:RandStream:ActivatingLegacyGenerators');

    % Verify tissue maps were created
    GmFile  = bst_fullfile(TmpDir, 'c1pvc_mri.nii');
    WmFile  = bst_fullfile(TmpDir, 'c2pvc_mri.nii');
    CsfFile = bst_fullfile(TmpDir, 'c3pvc_mri.nii');
    if ~file_exist(GmFile) || ~file_exist(WmFile) || ~file_exist(CsfFile)
        error('SPM tissue segmentation failed: tissue maps not found.');
    end

    % ===== EXPORT PET TO NIFTI =====
    bst_progress('text', 'Running partial volume correction...');
    PetNiiFile = bst_fullfile(TmpDir, 'pvc_pet.nii');
    % The PET has been resliced onto the reference MRI grid, but it can still carry a
    % STALE NIfTI vox2ras from the original (pre-reslice) PET. Exported as-is, the PET
    % and the MRI-derived tissue maps then describe DIFFERENT world geometries, so
    % PETPVE12 warns "images do not all have same orientation/voxel sizes", resamples
    % onto another grid, and the corrected volume comes back misaligned with the
    % T1/atlases. When the PET shares the reference voxel grid (the PVC pipeline always
    % reslices the PET to the T1 first), export it with the reference geometry so both
    % NIfTIs sit on one grid; the correction then stays voxel-aligned.
    if isequal(size(sMriPet.Cube(:,:,:,1)), size(sMriRef.Cube(:,:,:,1))) && ...
            isfield(sMriPet,'SCS') && isfield(sMriRef,'SCS') && ...
            isequal(sMriPet.SCS.R, sMriRef.SCS.R) && isequal(sMriPet.SCS.T, sMriRef.SCS.T)
        sMriPet.Header = sMriRef.Header;
    end
    out_mri_nii(sMriPet, PetNiiFile);

    % ===== BUILD PETPVE12 JOB =====
    job = struct();
    job.PETdata = {PetNiiFile};
    % Probabilistic tissue maps
    job.SegImgs.Tsegs.tiss1 = {GmFile};
    job.SegImgs.Tsegs.tiss2 = {WmFile};
    job.SegImgs.Tsegs.tiss3 = {CsfFile};
    % PVE correction options
    job.PVEopts.fwhm_PSF = fwhm;
    job.PVEopts.gmthresh = pvcOpts.gmThresh;
    job.PVEopts.TissConv = 0;  % Don't save convolved tissue segments
    % CSF signal handling
    if pvcOpts.csfZeroing
        job.PVEopts.CSFsignal.CSFzeroing = 1;
    else
        job.PVEopts.CSFsignal.CSFcalc.tiss3 = {CsfFile};
    end
    % WM/CSF constant activity estimation
    switch lower(pvcOpts.wmcsfMethod)
        case 'threshold'
            job.PVE_Const_opts.type3.wmcsfthresh = pvcOpts.wmcsfThresh;
        case 'erode'
            job.PVE_Const_opts.type4.erothresh = pvcOpts.wmcsfThresh;
        otherwise
            job.PVE_Const_opts.type3.wmcsfthresh = pvcOpts.wmcsfThresh;
    end

    % ===== RUN PETPVE12 =====
    geg_PVEcorrection(job);

    % ===== IMPORT CORRECTED PET =====
    bst_progress('text', 'Importing corrected PET volume...');
    PvcNiiFile = bst_fullfile(TmpDir, 'pvcpvc_pet.nii');
    if ~file_exist(PvcNiiFile)
        error('PETPVE12 correction failed: output file not found.');
    end
    % Import corrected PET volume
    sMriPvc = in_mri(PvcNiiFile, 'ALL', 0, 0);
    % Transfer metadata from original PET
    sMriPvc.SCS    = sMriPet.SCS;
    sMriPvc.NCS    = sMriPet.NCS;
    sMriPvc.Header = sMriPet.Header;

    % ===== CLEAN UP TEMP DIRECTORY =====
    file_delete(TmpDir, 1, 1);

    % ===== SAVE IN BRAINSTORM DATABASE =====
    bst_progress('text', 'Saving corrected PET volume...');
    [sSubject, iSubject] = bst_get('MriFile', PetFile);
    if isempty(sSubject) || ~isfield(sSubject, 'Anatomy')
        error('Could not find subject for the provided PET file.');
    end
    % Build output file path
    [folder, base, ext] = fileparts(file_fullpath(PetFile));
    lastUnderscore = find(base == '_', 1, 'last');
    if ~isempty(lastUnderscore)
        newBase = [base(1:lastUnderscore-1), fileTag, base(lastUnderscore:end)];
    else
        newBase = [base, fileTag];
    end
    MriFilePvcFull = file_unique(fullfile(folder, [newBase, ext]));
    MriFilePvc = file_short(MriFilePvcFull);
    % Update comment
    sMriPvc.Comment = file_unique([sMriPet.Comment, fileTag], {sSubject.Anatomy.Comment});
    % Add history entry
    sMriPvc = bst_history('add', sMriPvc, 'pvc', ...
        sprintf('Partial volume correction (Muller-Gartner, FWHM=[%g %g %g]mm)', fwhm(1), fwhm(2), fwhm(3)));
    % Save new MRI in Brainstorm format
    sMriPvc = out_mri_bst(sMriPvc, MriFilePvcFull);
    % Register new MRI in subject
    iAnatomy = length(sSubject.Anatomy) + 1;
    sSubject.Anatomy(iAnatomy) = db_template('Anatomy');
    sSubject.Anatomy(iAnatomy).FileName = MriFilePvc;
    sSubject.Anatomy(iAnatomy).Comment  = sMriPvc.Comment;
    % Update subject structure
    bst_set('Subject', iSubject, sSubject);
    % Refresh tree
    panel_protocols('UpdateNode', 'Subject', iSubject);
    panel_protocols('SelectNode', [], 'anatomy', iSubject, iAnatomy);
    % Save database
    db_save();

catch ME
    errMsg = ME.message;
    % Attempt cleanup on error
    if exist('TmpDir', 'var') && ~isempty(TmpDir) && file_exist(TmpDir)
        file_delete(TmpDir, 1, 1);
    end
end

% Stop progress bar if we started it
if ~isProgress
    bst_progress('stop');
end
end


%% ===== GTM: GEOMETRIC TRANSFER MATRIX =====
function [MriFileGtm, errMsg, regTable] = ComputeGtm(PetFile, fwhm, gtmOpts)
% Geometric Transfer Matrix (Rousset) regional partial volume correction.
%
% Native Brainstorm implementation of the Rousset 1998 GTM: corrects the regional
% mean activity of EVERY region (cortical + subcortical + WM + CSF + cerebellum) for
% PSF spill-over, by inverting the region-to-region spill-over matrix. Unlike
% Muller-Gartner (method 'mg'), it corrects all tissue classes, not just GM. Operates
% directly on the Brainstorm volume grid (no NIfTI round-trip, no SPM segmentation):
% the parcellation comes from the subject's Desikan-Killiany (aparc+aseg) volume.
%
%   W(i,j) = mean over region i of ( PSF (x) 1_region_j )      % spill-over matrix
%   m(i)   = mean of PET over region i                          % observed regional means
%   t      = W \ m                                              % true (corrected) means
%
% The output is a piecewise-constant volume (each region's voxels set to its corrected
% mean), saved as a Brainstorm anatomy node and voxel-aligned with the input PET, so it
% flows through SUVR rescaling and surface projection unchanged.
%
% USAGE:  [MriFileGtm, errMsg, regTable] = ComputeGtm(PetFile, fwhm, gtmOpts)
%
% INPUTS:
%   PetFile : static (3D) PET volume in the Brainstorm DB.
%   fwhm    : PSF FWHM in mm (scalar). [] -> derived from PET metadata (pet_helper('ScannerFwhm')).
%   gtmOpts : (optional) .AtlasComment (default 'Desikan-Killiany'), .minVox (default 50).
%
% OUTPUTS:
%   MriFileGtm : relative path to the corrected (piecewise-constant) volume node.
%   errMsg     : error message, if any.
%   regTable   : struct with .id .nvox .observed .corrected (per region).
%
% SEE ALSO: pet_pvc, pet_helper
%
% Reference: Rousset OG, Ma Y, Evans AC. Correction for partial volume effects in PET:
%            principle and validation. J Nucl Med 1998;39:904-911.

    MriFileGtm = ''; errMsg = ''; regTable = struct('id',{},'nvox',{},'observed',{},'corrected',{});
    if (nargin < 2), fwhm = []; end
    if (nargin < 3) || isempty(gtmOpts), gtmOpts = struct(); end
    if ~isfield(gtmOpts,'AtlasComment') || isempty(gtmOpts.AtlasComment), gtmOpts.AtlasComment = 'Desikan-Killiany'; end
    if ~isfield(gtmOpts,'minVox')       || isempty(gtmOpts.minVox),       gtmOpts.minVox = 50; end

    isProgress = bst_progress('isVisible');
    if ~isProgress, bst_progress('start', 'PET GTM', 'Loading volumes...'); end
    try
        % ----- load PET + parcellation -----
        [sSubject, iSubject] = bst_get('MriFile', PetFile);
        if isempty(sSubject), error('Subject not found for PET file.'); end
        sMriPet = in_mri_bst(PetFile);
        pet = double(sMriPet.Cube(:,:,:,1));
        cubeSize = size(pet);
        voxsize = sMriPet.Voxsize(1:3);
        iAtl = find(strcmp({sSubject.Anatomy.Comment}, gtmOpts.AtlasComment), 1);
        if isempty(iAtl), error('Parcellation "%s" not found.', gtmOpts.AtlasComment); end
        sAtl = in_mri_bst(sSubject.Anatomy(iAtl).FileName);
        L = double(sAtl.Cube(:,:,:,1));
        if ~isequal(size(L), cubeSize), error('Parcellation grid does not match PET grid.'); end

        % ----- PSF -----
        if isempty(fwhm)
            PET = []; try w = load(file_fullpath(PetFile),'PET'); if isfield(w,'PET'), PET = w.PET; end; catch; end
            [fwhm, fwhmSrc] = pet_helper('ScannerFwhm', PET);
            fprintf('BST> PET GTM: PSF FWHM = %.1f mm [%s]\n', fwhm, fwhmSrc);
        end
        if isscalar(fwhm), fwhm = [fwhm fwhm fwhm]; end
        if any(~isfinite(fwhm)) || any(fwhm <= 0), error('PSF FWHM must be a positive number (mm).'); end

        % ----- regions (complete partition: labels >= minVox, everything else -> "rest" id 0) -----
        bst_progress('text', 'Building GTM regions...');
        ids = unique(L(:)); ids = ids(ids ~= 0);
        keep = ids(arrayfun(@(id) nnz(L==id) >= gtmOpts.minVox, ids));
        nKeep = numel(keep);
        Lr = zeros(cubeSize);                        % relabelled: 1..nKeep = kept brain regions
        for r = 1:nKeep, Lr(L==keep(r)) = r; end
        restMask = (Lr == 0);
        % Split the leftover ("rest") into an EXTRACEREBRAL nuisance region (skull/scalp/
        % meninges - inside the head, outside the brain) and AIR (outside the head), using
        % the subject's scalp surface. Modeling extracerebral signal as its own region lets
        % GTM remove its spill-in into cortex (important for off-target tracers like tau);
        % a single "rest" region would mix near-zero air with nonzero skull/scalp.
        headMask = local_headmask(sSubject, sMriPet, cubeSize);
        if ~isempty(headMask)
            Lr(restMask &  headMask) = nKeep + 1;    % extracerebral tissue
            Lr(restMask & ~headMask) = nKeep + 2;    % air
            regIds = [keep(:); -1; -2];              % -1 = extracerebral, -2 = air
            R = nKeep + 2;
        else
            Lr(restMask) = nKeep + 1;
            regIds = [keep(:); -1];                  % -1 = rest (no scalp surface available)
            R = nKeep + 1;
            fprintf('BST> PET GTM: no scalp surface -> single rest region (extracerebral not modeled).\n');
        end
        idx = cell(R,1); n = zeros(R,1);
        for i = 1:R, idx{i} = find(Lr==i); n(i) = numel(idx{i}); end
        % Drop empty regions (e.g. no air voxels when the head fills the field of view):
        % an empty region gives a 0/0 mean and turns the whole solution into NaN.
        isEmptyReg = (n == 0);
        if any(isEmptyReg)
            idx(isEmptyReg) = []; n(isEmptyReg) = []; regIds(isEmptyReg) = []; R = numel(n);
        end

        % ----- GTM matrix + observed means -----
        bst_progress('text', sprintf('GTM matrix (%d regions)...', R));
        W = zeros(R,R); m = zeros(R,1);
        for i = 1:R, m(i) = sum(pet(idx{i})) / n(i); end
        for j = 1:R
            mj = zeros(cubeSize); mj(idx{j}) = 1;
            hrj = local_gauss3(mj, fwhm, voxsize);
            for i = 1:R, W(i,j) = sum(hrj(idx{i})) / n(i); end
        end

        % ----- solve t = W \ m (robust to ill-conditioning) -----
        c = rcond(W);
        if ~isfinite(c) || (c < 1e-12)
            t = pinv(W) * m;
            fprintf('BST> PET GTM: W ill-conditioned (rcond=%.1e) -> pseudo-inverse.\n', c);
        else
            t = W \ m;
        end

        % ----- piecewise-constant corrected volume -----
        Cout = zeros(cubeSize, 'single');
        for i = 1:R, Cout(idx{i}) = t(i); end
        sGtm = sMriPet;                              % inherit geometry (same grid -> aligned)
        sGtm.Cube = Cout;

        % ----- region table -----
        for i = 1:R
            regTable(i) = struct('id', regIds(i), 'nvox', n(i), 'observed', m(i), 'corrected', t(i)); %#ok<AGROW>
        end

        % ----- save as anatomy node -----
        fileTag = '_gtmpvc';
        sGtm.Comment = file_unique([sMriPet.Comment fileTag], {sSubject.Anatomy.Comment});
        sGtm = bst_history('add', sGtm, 'gtm', sprintf('Rousset GTM PVC, FWHM=%gmm, %d regions, cond=%.1e', fwhm(1), R, 1/max(c,eps)));
        [folder, base, ext] = fileparts(file_fullpath(PetFile));
        u = find(base=='_',1,'last');
        if ~isempty(u), newBase = [base(1:u-1) fileTag base(u:end)]; else, newBase = [base fileTag]; end
        MriFileGtmFull = file_unique(fullfile(folder, [newBase ext]));
        MriFileGtm = file_short(MriFileGtmFull);
        out_mri_bst(sGtm, MriFileGtmFull);
        iAnatomy = length(sSubject.Anatomy) + 1;
        sSubject.Anatomy(iAnatomy) = db_template('Anatomy');
        sSubject.Anatomy(iAnatomy).FileName = MriFileGtm;
        sSubject.Anatomy(iAnatomy).Comment  = file_unique([sMriPet.Comment fileTag], {sSubject.Anatomy.Comment});
        bst_set('Subject', iSubject, sSubject);
        panel_protocols('UpdateNode', 'Subject', iSubject);
        db_save();
    catch ME
        errMsg = ME.message;
    end
    if ~isProgress, bst_progress('stop'); end
end


function headMask = local_headmask(sSubject, sMriRef, cubeSize)
% Voxelize the subject's scalp ("head mask") surface into a filled binary head mask on
% the reference grid. Returns [] if no scalp surface is available.
    headMask = [];
    if ~isfield(sSubject,'Surface') || isempty(sSubject.Surface), return; end
    iScalp = find(strcmpi({sSubject.Surface.SurfaceType}, 'Scalp'), 1);
    if isempty(iScalp), return; end
    try
        tess2mri = tess_interp_mri(sSubject.Surface(iScalp).FileName, sMriRef);
        headMask = logical(tess_mrimask(cubeSize, tess2mri));
    catch
        headMask = [];
    end
end

function vol = local_gauss3(vol, fwhm_mm, voxsize_mm)
    sig = fwhm_mm / 2.35482;
    for d = 1:3
        sv = sig(min(d,numel(sig))) / voxsize_mm(d); r = max(1, ceil(3*sv)); x = -r:r;
        k = exp(-(x.^2)/(2*sv^2)); k = k/sum(k);
        sh = ones(1,3); sh(d) = numel(k);
        vol = convn(vol, reshape(k, sh), 'same');
    end
end
