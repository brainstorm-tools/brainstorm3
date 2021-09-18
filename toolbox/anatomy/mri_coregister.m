function [MriFileReg, errMsg, fileTag, sMriReg] = mri_coregister(MriFileSrc, MriFileRef, Method, isReslice, isAtlas)
% MRI_COREGISTER: Compute the linear transformations on both input volumes, then register the first on the second.
%
% USAGE:  [MriFileReg, errMsg, fileTag] = mri_coregister(MriFileSrc, MriFileRef, Method, isReslice)
%            [sMriReg, errMsg, fileTag] = mri_coregister(sMriSrc,    sMriRef, ...)
%
% INPUTS:
%    - MriFileSrc : Relative path to the Brainstorm MRI file to register
%    - MriFileRef : Relative path to the Brainstorm MRI file used as a reference
%    - sMriSrc    : Brainstorm MRI structure to register (fields Cube, Voxsize, SCS, NCS...)
%    - sMriRef    : Brainstorm MRI structure used as a reference
%    - Method     : Method used for the coregistration of the volume: 'spm', 'mni', 'vox2ras'
%    - isReslice  : If 1, reslice the output volume to match dimensions of the reference volume
%    - isAtlas    : If 1, perform only integer/nearest neighbors interpolations (MNI and VOX2RAS registration only)
%
% OUTPUTS:
%    - MriFileReg : Relative path to the new Brainstorm MRI file (containing the structure sMriReg)
%    - sMriReg    : Brainstorm MRI structure with the registered volume
%    - errMsg     : Error messages if any
%    - fileTag    : Tag added to the comment/filename

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
% Authors: Francois Tadel, 2016-2021

% ===== LOAD INPUTS =====
% Parse inputs
if (nargin < 5) || isempty(isAtlas)
    isAtlas = 0;
end
% Initialize returned variables
MriFileReg = [];
errMsg = [];
fileTag = '';
sMriReg = [];
% Progress bar
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'MRI register', 'Loading input volumes...');
end
% USAGE: mri_coregister(sMriSrc, sMriRef, ...)
if isstruct(MriFileSrc)
    sMriSrc = MriFileSrc;
    sMriRef = MriFileRef;
    MriFileSrc = [];
    MriFileRef = [];
% USAGE: mri_coregister(MriFileSrc, MriFileRef, ...)
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
% % Not available for multiple volumes
% if (size(sMriRef.Cube, 4) > 1) || (size(sMriSrc.Cube, 4) > 1)
%     errMsg = 'The input files cannot contain multiple volumes.';
%     return;
% end
% Inialize various variables
isUpdateScs = 0;
isUpdateNcs = 0;
TransfReg = [];
TransfRef = [];

% ===== REGISTER VOLUMES =====
switch lower(Method)
    
    % ===== METHOD: SPM =====
    case 'spm'
        % Initialize SPM
        [isInstalled, errMsg] = bst_plugin('Install', 'spm12');
        if ~isInstalled
            return;
        end
        bst_plugin('SetProgressLogo', 'spm12');
        
        % === SAVE FILES IN TMP FOLDER ===
        bst_progress('text', 'Saving temporary files...');
        % Empty temporary folder
        gui_brainstorm('EmptyTempFolder');
        % Save source MRI in .nii format
        NiiSrcFile = bst_fullfile(bst_get('BrainstormTmpDir'), 'spm_src.nii');
        out_mri_nii(sMriSrc, NiiSrcFile);
        % Save reference MRI in .nii format
        NiiRefFile = bst_fullfile(bst_get('BrainstormTmpDir'), 'spm_ref.nii');
        out_mri_nii(sMriRef, NiiRefFile);

        % === CALL SPM COREGISTRATION ===
        bst_progress('text', 'Calling SPM batch...');
        % Code initially coming from Olivier David's ImaGIN_anat_spm.m function
        % Initial translation according to centroids
        % Reference volume
        Vref = spm_vol([NiiRefFile, ',1']);
        [Iref,XYZref] = spm_read_vols(Vref);
        Iindex = find(Iref>max(Iref(:))/6);
        Zindex = find(max(XYZref(3,:))-XYZref(3,:)<200);
        index = intersect(Iindex,Zindex);
        CentroidRef = mean(XYZref(:,index),2);
        % Volume to register
        V2 = spm_vol([NiiSrcFile, ',1']);
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
            matlabbatch{1}.spm.spatial.coreg.estwrite.ref      = {[NiiRefFile, ',1']};
            matlabbatch{1}.spm.spatial.coreg.estwrite.source   = {[NiiSrcFile, ',1']};
            matlabbatch{1}.spm.spatial.coreg.estwrite.other    = {''};
            matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions = spm_get_defaults('coreg.estimate');
            matlabbatch{1}.spm.spatial.coreg.estwrite.woptions = spm_get_defaults('coreg.write');
            matlabbatch{1}.spm.spatial.coreg.estwrite.woptions.outdir = bst_get('BrainstormTmpDir');
            % Output file
            NiiRegFile = bst_fullfile(bst_get('BrainstormTmpDir'), 'rspm_src.nii');
        else
            % Coreg: Estimate
            matlabbatch{1}.spm.spatial.coreg.estimate.ref      = {[NiiRefFile, ',1']};
            matlabbatch{1}.spm.spatial.coreg.estimate.source   = {[NiiSrcFile, ',1']};
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
        % If an error occurred in SPM
        if isempty(sMriReg)
            errMsg = 'An unknown error occurred while executing SPM. See the logs in the command window.';
            return;
        end
        % Output file tag
        fileTag = '_spm';
        % Remove logo
        bst_plugin('SetProgressLogo', []);
        
        % === UPDATE FIDUCIALS ===
        if isReslice
            % Use the reference SCS coordinates
            if isfield(sMriRef, 'SCS')
                sMriReg.SCS = sMriRef.SCS;
            end
            % Use the reference NCS coordinates
            if isfield(sMriRef, 'NCS')
                sMriReg.NCS = sMriRef.NCS;
            end
        else
            isUpdateScs = 1;
            isUpdateNcs = 1;
        end

    % ===== METHOD: MNI =====
    case 'mni'
        % === COMPUTE MNI TRANSFORMATIONS ===
        % Source MRI
        if ~isfield(sMriSrc, 'NCS') || ~isfield(sMriSrc.NCS, 'R') || ~isfield(sMriSrc.NCS, 'T') || isempty(sMriSrc.NCS.R) || isempty(sMriSrc.NCS.T)
            [sMriSrc,errMsg] = bst_normalize_mni(sMriSrc, 'maff8');
        end
        % Reference MRI
        if ~isfield(sMriRef, 'NCS') || ~isfield(sMriRef.NCS, 'R') || ~isfield(sMriRef.NCS, 'T') || isempty(sMriRef.NCS.R) || isempty(sMriRef.NCS.T)
            [sMriRef,errMsg] = bst_normalize_mni(sMriRef, 'maff8');
        end
        % Handle errors
        if ~isempty(errMsg)
            return;
        end
        % Get MNI transformations
        TransfSrc = [sMriSrc.NCS.R, sMriSrc.NCS.T; 0 0 0 1];
        TransfRef = [sMriRef.NCS.R, sMriRef.NCS.T; 0 0 0 1];

        % === RESLICE VOLUME ===
        if isReslice
            % Reslice the volume
            [sMriReg, errMsg] = mri_reslice(sMriSrc, sMriRef, TransfSrc, TransfRef, isAtlas);
        else
            % Save the original input volume
            sMriReg = sMriSrc;
            TransfReg = TransfSrc;
            isUpdateScs = 1;
            isUpdateNcs = 0;
        end
        % Output file tag
        fileTag = '_mni';
        
    % ===== VOX2RAS =====
    case 'vox2ras'
        % Nothing to do, just reslice if needed
        if isReslice
            % Reslice the volume
            [sMriReg, errMsg] = mri_reslice(sMriSrc, sMriRef, 'vox2ras', 'vox2ras', isAtlas);
            % Output file tag
            if ~isempty(strfind(sMriSrc.Comment, '_spm'))
                fileTag = '';
            else
                fileTag = '_vox2ras';
            end
        else
            % Save the original input volume
            sMriReg = sMriSrc;
            isUpdateScs = 1;
            isUpdateNcs = 1;
            fileTag = '';
        end
end
% Handle errors
if ~isempty(errMsg)
    return;
end

% ===== REMOVE NEW NEGATIVE VALUES =====
% If some negative values appeared just because of the registration/reslicing: remove them
if any(sMriReg.Cube(:) < 0) && ~any(sMriSrc.Cube(:) < 0)
    sMriReg.Cube(sMriReg.Cube < 0) = 0;
end

% ===== UPDATE FIDUCIALS =====
if isUpdateScs || isUpdateNcs
    % Use vox2ras transformation unless otherwise specified
    if isempty(TransfReg) || isempty(TransfRef)
        if ~isfield(sMriReg, 'InitTransf') || isempty(sMriReg.InitTransf) || ~any(ismember(sMriReg.InitTransf(:,1), 'vox2ras'))
            errMsg = 'No vox2ras transformation available for the registered volume.';
        elseif ~isfield(sMriRef, 'InitTransf') || isempty(sMriRef.InitTransf) || ~any(ismember(sMriRef.InitTransf(:,1), 'vox2ras'))
            errMsg = 'No vox2ras transformation available for the reference volume.';
        % If SCS coordinates are defined
        elseif isfield(sMriRef, 'SCS') && all(isfield(sMriRef.SCS, {'NAS','LPA','RPA','T','R'})) && ~isempty(sMriRef.SCS.NAS) && ~isempty(sMriRef.SCS.LPA) && ~isempty(sMriRef.SCS.RPA) && ~isempty(sMriRef.SCS.R) && ~isempty(sMriRef.SCS.T)
            % Get transformation MRI=>WORLD
            TransfReg = cs_convert(sMriReg, 'mri', 'world');
            TransfRef = cs_convert(sMriRef, 'mri', 'world');
            % Convert to millimeters (to match the fiducials storage)
            TransfReg(1:3,4) = TransfReg(1:3,4) .* 1000;
            TransfRef(1:3,4) = TransfRef(1:3,4) .* 1000;
        end
    end
    % Transform the reference SCS coordinates if possible
    if isUpdateScs && ~isempty(TransfReg) && ~isempty(TransfRef) && isfield(sMriRef, 'SCS') && all(isfield(sMriRef.SCS, {'NAS','LPA','RPA','T','R'})) && ~isempty(sMriRef.SCS.NAS) && ~isempty(sMriRef.SCS.LPA) && ~isempty(sMriRef.SCS.RPA) && ~isempty(sMriRef.SCS.R) && ~isempty(sMriRef.SCS.T)
        % Apply transformation: reference MRI => SPM RAS/world => registered MRI
        Transf = inv(TransfReg) * (TransfRef);
        % Update SCS fiducials
        sMriReg.SCS.NAS = (Transf(1:3,1:3) * sMriRef.SCS.NAS' + Transf(1:3,4))';
        sMriReg.SCS.LPA = (Transf(1:3,1:3) * sMriRef.SCS.LPA' + Transf(1:3,4))';
        sMriReg.SCS.RPA = (Transf(1:3,1:3) * sMriRef.SCS.RPA' + Transf(1:3,4))';
        % Compute new transformation matrices to SCS
        Tscs = [sMriRef.SCS.R, sMriRef.SCS.T; 0 0 0 1] * inv(Transf);
        % Report in the new MRI structure
        sMriReg.SCS.R = Tscs(1:3,1:3);
        sMriReg.SCS.T = Tscs(1:3,4);
    end
    % Transform the reference NCS coordinates if possible
    if isUpdateNcs && ~isempty(TransfReg) && ~isempty(TransfRef) && isfield(sMriRef, 'NCS') && all(isfield(sMriRef.NCS, {'AC','PC','IH','T','R'})) && ~isempty(sMriRef.NCS.AC) && ~isempty(sMriRef.NCS.PC) && ~isempty(sMriRef.NCS.IH) && ~isempty(sMriRef.NCS.R) && ~isempty(sMriRef.NCS.T)
        % Apply transformation: reference MRI => SPM RAS/world => registered MRI
        Transf = inv(TransfReg) * (TransfRef);
        % Update SCS fiducials
        sMriReg.NCS.AC = (Transf(1:3,1:3) * sMriRef.NCS.AC' + Transf(1:3,4))';
        sMriReg.NCS.PC = (Transf(1:3,1:3) * sMriRef.NCS.PC' + Transf(1:3,4))';
        sMriReg.NCS.IH = (Transf(1:3,1:3) * sMriRef.NCS.IH' + Transf(1:3,4))';
        % Compute new transformation matrices to SCS
        Tncs = [sMriRef.NCS.R, sMriRef.NCS.T; 0 0 0 1] * inv(Transf);
        % Report in the new MRI structure
        sMriReg.NCS.R = Tncs(1:3,1:3);
        sMriReg.NCS.T = Tncs(1:3,4);
    end
end


% ===== SAVE NEW FILE =====
% Add file tag
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
    sMriReg = bst_history('add', sMriReg, 'resample', ['MRI co-registered on default file (' Method '): ' MriFileRef]);
    % Save new file
    MriFileRegFull = file_unique(strrep(file_fullpath(MriFileSrc), '.mat', [fileTag '.mat']));
    MriFileReg = file_short(MriFileRegFull);
    % Save new MRI in Brainstorm format
    sMriReg = out_mri_bst(sMriReg, MriFileRegFull);

    % Register new MRI
    iAnatomy = length(sSubject.Anatomy) + 1;
    sSubject.Anatomy(iAnatomy) = db_template('Anatomy');
    sSubject.Anatomy(iAnatomy).FileName = MriFileReg;
    sSubject.Anatomy(iAnatomy).Comment  = sMriReg.Comment;
    % Update subject structure
    bst_set('Subject', iSubject, sSubject);
    % Refresh tree
    panel_protocols('UpdateNode', 'Subject', iSubject);
    panel_protocols('SelectNode', [], 'anatomy', iSubject, iAnatomy);
    % Save database
    db_save();
else
    % Return output structure
    MriFileReg = sMriReg;
end
% Close progress bar
if ~isProgress
    bst_progress('stop');
end

