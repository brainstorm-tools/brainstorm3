function [sMriT1, TpmFiles] = mri_normalize_segment(sMriT1, TpmFile, sMriT2)
% MRI_NORMALIZE_SEGMENT: Non-linear normalization to the MNI ICBM152 space 
% and tissue segmentation using SPM's Segment batch.
%
% USAGE:  [sMriT1, TpmFiles] = mri_normalize_segment(sMriT1, TpmFile, sMriT2=[])
%
% The MNI152 space depends on the TPM.nii file given in input:
%    - Default in SPM12 : IXI549 template

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
% Authors: Francois Tadel, 2020-2023

% === PARSE INPUTS ===
if (nargin < 3) || isempty(sMriT2)
    sMriT2 = [];
end

% === SAVE FILES IN TMP FOLDER ===
% Output variables
TpmFiles = [];
% Save T1 MRI in .nii format
baseName = 'spm_segment_T1.nii';
TmpDir = bst_get('BrainstormTmpDir', 0, 'spmsegment');
T1Nii = bst_fullfile(TmpDir, baseName);
out_mri_nii(sMriT1, T1Nii);
% Save T2 MRI in .nii format
if ~isempty(sMriT2)
    T2Nii = bst_fullfile(TmpDir, 'spm_segment_T2.nii');
    out_mri_nii(sMriT1, T2Nii);
else
    T2Nii = [];
end

% === RUN SPM SEGMENT ===
% Disable warnings
warning('off', 'MATLAB:RandStream:ActivatingLegacyGenerators');
% Prepare SPM batch
matlabbatch{1}.spm.spatial.preproc.channel(1).vols = {[T1Nii ',1']};
matlabbatch{1}.spm.spatial.preproc.channel(1).biasreg = 0.001;
matlabbatch{1}.spm.spatial.preproc.channel(1).biasfwhm = 60;
matlabbatch{1}.spm.spatial.preproc.channel(1).write = [0 0];
if ~isempty(T2Nii)
    matlabbatch{1}.spm.spatial.preproc.channel(2).vols = {[T2Nii ',1']};
    matlabbatch{1}.spm.spatial.preproc.channel(2).biasreg = 0.001;
    matlabbatch{1}.spm.spatial.preproc.channel(2).biasfwhm = 60;
    matlabbatch{1}.spm.spatial.preproc.channel(2).write = [0 0];
end
matlabbatch{1}.spm.spatial.preproc.tissue(1).tpm = {[TpmFile, ',1']};
matlabbatch{1}.spm.spatial.preproc.tissue(1).ngaus = 1;
matlabbatch{1}.spm.spatial.preproc.tissue(1).native = [1 0];
matlabbatch{1}.spm.spatial.preproc.tissue(1).warped = [0 0];
matlabbatch{1}.spm.spatial.preproc.tissue(2).tpm = {[TpmFile, ',2']};
matlabbatch{1}.spm.spatial.preproc.tissue(2).ngaus = 1;
matlabbatch{1}.spm.spatial.preproc.tissue(2).native = [1 0];
matlabbatch{1}.spm.spatial.preproc.tissue(2).warped = [0 0];
matlabbatch{1}.spm.spatial.preproc.tissue(3).tpm = {[TpmFile, ',3']};
matlabbatch{1}.spm.spatial.preproc.tissue(3).ngaus = 2;
matlabbatch{1}.spm.spatial.preproc.tissue(3).native = [1 0];
matlabbatch{1}.spm.spatial.preproc.tissue(3).warped = [0 0];
matlabbatch{1}.spm.spatial.preproc.tissue(4).tpm = {[TpmFile, ',4']};
matlabbatch{1}.spm.spatial.preproc.tissue(4).ngaus = 3;
matlabbatch{1}.spm.spatial.preproc.tissue(4).native = [1 0];
matlabbatch{1}.spm.spatial.preproc.tissue(4).warped = [0 0];
matlabbatch{1}.spm.spatial.preproc.tissue(5).tpm = {[TpmFile, ',5']};
matlabbatch{1}.spm.spatial.preproc.tissue(5).ngaus = 4;
matlabbatch{1}.spm.spatial.preproc.tissue(5).native = [1 0];
matlabbatch{1}.spm.spatial.preproc.tissue(5).warped = [0 0];
matlabbatch{1}.spm.spatial.preproc.tissue(6).tpm = {[TpmFile, ',6']};
matlabbatch{1}.spm.spatial.preproc.tissue(6).ngaus = 2;
matlabbatch{1}.spm.spatial.preproc.tissue(6).native = [1 0];
matlabbatch{1}.spm.spatial.preproc.tissue(6).warped = [0 0];
matlabbatch{1}.spm.spatial.preproc.warp.mrf = 1;
matlabbatch{1}.spm.spatial.preproc.warp.cleanup = 1;
matlabbatch{1}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
matlabbatch{1}.spm.spatial.preproc.warp.affreg = 'mni';
matlabbatch{1}.spm.spatial.preproc.warp.fwhm = 0;
matlabbatch{1}.spm.spatial.preproc.warp.samp = 3;
matlabbatch{1}.spm.spatial.preproc.warp.write = [1 1];
matlabbatch{1}.spm.spatial.preproc.warp.vox = NaN;
matlabbatch{1}.spm.spatial.preproc.warp.bb = [NaN NaN NaN; NaN NaN NaN];
% Run SPM batch
spm_jobman('initcfg');
spm_jobman('run',matlabbatch)
% Restore warnings
warning('off', 'MATLAB:RandStream:ActivatingLegacyGenerators');

% === LOAD DEFORMATION ===
bst_progress('text', 'Loading deformation fields...');
% Output files
RegFile = bst_fullfile(TmpDir, ['y_' baseName]);
RegInvFile = bst_fullfile(TmpDir, ['iy_' baseName]);
if ~file_exist(RegFile) || ~file_exist(RegInvFile)
    disp('BST> SPM Segment failed.');
    sMriT1 = [];
    return;
end
% Import deformation fields
sMriT1 = import_mnireg(sMriT1, RegFile, RegInvFile, 'segment');

% === LOAD TISSUES ===
TpmFiles = {...
    bst_fullfile(TmpDir, ['c2' baseName]), ...
    bst_fullfile(TmpDir, ['c1' baseName]), ...
    bst_fullfile(TmpDir, ['c3' baseName]), ...
    bst_fullfile(TmpDir, ['c4' baseName]), ...
    bst_fullfile(TmpDir, ['c5' baseName]), ...
    bst_fullfile(TmpDir, ['c6' baseName])};
if ~all(cellfun(@file_exist, TpmFiles))
    TpmFiles = [];
end

% Files must not be deleted because TPM files are returned by the function
% They must be deleted in the calling function
