function [sMriReg, errMsg, fileTag] = mri_coregister_spm(MriFileSrc, MriFileRef, isReslice)
% MRI_COREGISTER_SPM: Compute a rigid transformation between two volumes with SPM.
%
% USAGE:  [MriFileReg, errMsg, fileTag] = mri_coregister_spm(MriFileSrc, MriFileRef, isReslice=1)
%            [sMriReg, errMsg, fileTag] = mri_coregister_spm(sMriSrc,    sMriRef, ...)
%
% INPUTS:
%    - MriFileSrc : Relative path to the Brainstorm MRI file to register
%    - MriFileRef : Relative path to the Brainstorm MRI file used as a reference
%    - sMriSrc    : Brainstorm MRI structure to register (fields Cube, Voxsize, SCS, NCS...)
%    - sMriRef    : Brainstorm MRI structure used as a reference
%    - isReslice  : If 1, reslice the output volume to match dimensions of the reference volume
%
% OUTPUTS:
%    - MriFileReg : Relative path to the new Brainstorm MRI file (containing the structure sMriReg)
%    - sMriReg    : Brainstorm MRI structure with the registered volume
%    - errMsg     : Error messages if any
%    - fileTag    : Tag added to the comment/filename

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Francois Tadel, Olivier David, 2017

% ===== PARSE INPUTS =====
sMriReg = [];
errMsg = [];
% Parse inputs
if (nargin < 3) || isempty(isReslice)
    isReslice = 1;
end
% Check SPM installation
bst_spm_init();
% Check if SPM is in the path
if ~exist('spm_jobman', 'file')
    errMsg = 'SPM must be in the Matlab path to use this feature.';
    return;
end


% ===== LOAD INPUTS =====
% Progress bar
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'MRI register', 'Loading input volumes...');
end
% USAGE: mri_coregister_spm(sMriSrc, sMriRef)
if isstruct(MriFileSrc)
    sMriSrc = MriFileSrc;
    sMriRef = MriFileRef;
    MriFileSrc = [];
    MriFileRef = [];
% USAGE: mri_coregister_spm(MriFileSrc, MriFileRef)
elseif ischar(MriFileSrc)
    % Get the default MRI for this subject
    if isempty(MriFileRef)
        sSubject = bst_get('MriFile', MriFileSrc);
        MriFileRef = sSubject.Anatomy(sSubject.iAnatomy).FileName;
    end
    sMriSrc = in_mri_bst(MriFileSrc);
    sMriRef = in_mri_bst(MriFileRef);
else
    error('Invalid call.');
end


% ===== SAVE FILES IN TMP FOLDER =====
% Save source MRI in .nii format
NiiSrcFile = bst_fullfile(bst_get('BrainstormTmpDir'), 'spm_src.nii');
out_mri_nii(sMriSrc, NiiSrcFile);
% Save reference MRI in .nii format
NiiRefFile = bst_fullfile(bst_get('BrainstormTmpDir'), 'spm_ref.nii');
out_mri_nii(sMriRef, NiiRefFile);



% ===== CALL SPM COREGISTRATION =====
% Code initially coming from Olivier David's ImaGIN_anat_spm.m function
% Initial translation according to centroids
% Reference volume
Vref = spm_vol(NiiRefFile);
[Iref,XYZref] = spm_read_vols(Vref);
Iindex = find(Iref>max(Iref(:))/6);
Zindex = find(max(XYZref(3,:))-XYZref(3,:)<200);
index = intersect(Iindex,Zindex);
CentroidRef = mean(XYZref(:,index),2);
% Volume to register
V2 = spm_vol(NiiSrcFile);
[I2,XYZ2] = spm_read_vols(V2);
Iindex = find(I2>max(I2(:))/6);
Zindex = find(max(XYZ2(3,:))-XYZ2(3,:)<200);
index = intersect(Iindex,Zindex);
Centroid2 = mean(XYZ2(:,index),2);
% Apply translation
B = [CentroidRef'-Centroid2' 0 0 0 1 1 1 0 0 0];
M = spm_matrix(B);
Mat = spm_get_space(V2.fname);
spm_get_space(V2.fname, M*Mat);

% Create coregistration batch
if isReslice
    % Coreg: Estimate and reslice
    matlabbatch{1}.spm.spatial.coreg.estwrite.ref      = {NiiRefFile};
    matlabbatch{1}.spm.spatial.coreg.estwrite.source   = {NiiSrcFile};
    matlabbatch{1}.spm.spatial.coreg.estwrite.other    = {''};
    matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions = spm_get_defaults('coreg.estimate');
    matlabbatch{1}.spm.spatial.coreg.estwrite.woptions = spm_get_defaults('coreg.write');
    matlabbatch{1}.spm.spatial.coreg.estwrite.woptions.outdir = bst_get('BrainstormTmpDir');
    % Output file
    NiiRegFile = bst_fullfile(bst_get('BrainstormTmpDir'), 'rspm_src.nii');
else
error('This option is not available yet.');
    % Coreg: Estimate
    matlabbatch{1}.spm.spatial.coreg.estimate.ref      = {NiiRefFile};
    matlabbatch{1}.spm.spatial.coreg.estimate.source   = {NiiSrcFile};
    matlabbatch{1}.spm.spatial.coreg.estimate.other    = {''};
    matlabbatch{1}.spm.spatial.coreg.estimate.eoptions = spm_get_defaults('coreg.estimate');
    % Output file
    NiiRegFile = NiiSrcFile;
end
% Run SPM batch
spm_jobman('initcfg');
% spm_jobman('interactive', matlabbatch)
spm_jobman('run',matlabbatch)

% Read output volume
[sMriReg, vox2ras] = in_mri(NiiRegFile, 'ALL', 0, 0);


% ===== UPDATE FIDUCIALS =====
if isReslice
    % Use the reference SCS coordinates
    if isfield(sMriRef, 'SCS')
        sMriReg.SCS = sMriRef.SCS;
    end
    % Use the reference NCS coordinates
    if isfield(sMriRef, 'NCS')
        sMriReg.NCS = sMriRef.NCS;
    end
    
% ===== NO RESLICE: USE ORIGINAL VOLUME =====
else
    if ~isfield(sMriReg, 'InitTransf') || isempty(sMriReg.InitTransf) || ~any(ismember(sMriReg.InitTransf(:,1), 'vox2ras'))
        errMsg = 'No vox2ras transformation available for the registered volume.';
    elseif ~isfield(sMriRef, 'InitTransf') || isempty(sMriRef.InitTransf) || ~any(ismember(sMriRef.InitTransf(:,1), 'vox2ras'))
        errMsg = 'No vox2ras transformation available for the reference volume.';
    else
        % Get transformations
        iTransfReg = find(strcmpi(sMriReg.InitTransf(:,1), 'vox2ras'));
        iTransfRef = find(strcmpi(sMriRef.InitTransf(:,1), 'vox2ras'));
        TransfReg = sMriReg.InitTransf{iTransfReg(1),2};
        TransfRef = sMriRef.InitTransf{iTransfRef(1),2};
        % Apply transformation: reference MRI => SPM RAS/world => registered MRI
        Transf = inv(TransfReg) * TransfRef;
        % Update SCS fiducials
        sMriReg.SCS.NAS = (Transf(1:3,1:3) * sMriRef.SCS.NAS' + Transf(1:3,4))';
        sMriReg.SCS.LPA = (Transf(1:3,1:3) * sMriRef.SCS.LPA' + Transf(1:3,4))';
        sMriReg.SCS.RPA = (Transf(1:3,1:3) * sMriRef.SCS.RPA' + Transf(1:3,4))';
        % Compute new transformation matrices to SCS
        Tscs = [sMriRef.SCS.R, sMriRef.SCS.T; 0 0 0 1] * inv(Transf);
        % Report in the new MRI structure
        sMriReg.SCS.R = Tscs(1:3,1:3);
        sMriReg.SCS.T = Tscs(1:3,4);
%         NewTransf = cs_compute(sMriReg, 'scs');
%         % Report in the new MRI structure
%         sMriReg.SCS.R = NewTransf.R;
%         sMriReg.SCS.T = NewTransf.T;
%         sMriReg.SCS.Origin = NewTransf.Origin;
    end
end
% Handle errors
if ~isempty(errMsg)
    if ~isempty(MriFileSrc)
        bst_error(errMsg, 'MRI reslice', 0);
    end
    return;
end


% ===== SAVE NEW FILE =====
% Add file tag
fileTag = '_spm';
if isReslice
    fileTag = [fileTag, '_reslice'];
end
sMriReg.Comment = [sMriSrc.Comment, fileTag];
% Save output
if ~isempty(MriFileSrc)
    bst_progress('text', 'Saving new file...');
    % Get subject
    [sSubject, iSubject, iMri] = bst_get('MriFile', MriFileSrc);
    % Update comment
    sMriReg.Comment = file_unique(sMriReg.Comment, {sSubject.Anatomy.Comment});
    % Add history entry
    sMriReg = bst_history('add', sMriReg, 'resample', ['MRI co-registered on default file: ' MriFileRef]);
    % Save new file
    newMriFile = file_unique(strrep(file_fullpath(MriFileSrc), '.mat', [fileTag, '.mat']));
    shorMriFile = file_short(newMriFile);
    % Save new MRI in Brainstorm format
    sMriReg = out_mri_bst(sMriReg, newMriFile);

    % Register new MRI
    iAnatomy = length(sSubject.Anatomy) + 1;
    sSubject.Anatomy(iAnatomy) = db_template('Anatomy');
    sSubject.Anatomy(iAnatomy).FileName = shorMriFile;
    sSubject.Anatomy(iAnatomy).Comment  = sMriReg.Comment;
    % Update subject structure
    bst_set('Subject', iSubject, sSubject);
    % Refresh tree
    panel_protocols('UpdateNode', 'Subject', iSubject);
    panel_protocols('SelectNode', [], 'anatomy', iSubject, iAnatomy);
    % Save database
    db_save();
    % Return output filename
    sMriReg = shorMriFile;
end
% Close progress bar
if ~isProgress
    bst_progress('stop');
end



