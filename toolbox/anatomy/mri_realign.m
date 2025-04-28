function  [MriRealign, fileTag] = mri_realign (MriFile, Method, FWHM, Aggregation)
% MRI_REALIGN: Extract frames from dynamic volumes and realign with optional smoothing and aggregation
%
% USAGE:  [MriFileRealign, fileTag] = mri_realign(MriFile, Method, FWHM, Aggregation)
%            [sMriRealign, fileTag] = mri_realign(sMri,    Method, FWHM, Aggregation)
%
% INPUTS:
%    - MriFile : Relative path to the Brainstorm MRI file to realign
%    - sMri    : Brainstorm MRI structure to realign (fields Cube, Voxsize, SCS, NCS...)
%    - Method  : Method used for the realignment of the volume:
%                'spm_realign' :  Uses the SPM plugin
%    - FWHM    : Size of smoothing kernel in mm, as full-width at half maximum of Gaussian kernel
%                Default = 0;
%    - Aggregation: Method to use for aggregating dynamic volume
%                'mean', 'median', 'max', 'min', 'zscore', 'first', 'last', 'ignore' (default)
%
% OUTPUTS:
%
%   - MriFileRealign : Relative path to the new Brainstorm realigned MRI file (containing the structure sMriRealign)
%   - sMriRealign    : Brainstorm MRI structure with realigned MRI
%   - fileTag        : Tag added to the comment/filename
%
% DEFAULTS: 
%
%         - FWHM    : No smoothing by default, FWHM = 0
%                     // Example: [MriFileRealign, fileTag] = mri_realign(MriFile, Method)
%                                    [sMriRealign, fileTag] = mri_realign(MriFile, Method)
%         - Aggregation: No aggregation by default; returns dynamic (4D) realigned volume
%                     // Example: [MriFileRealign, fileTag] = mri_realign(MriFile, Method, FWHM)
%                                      [sMriAlign, fileTag] = mri_realign(MriFile, Method, FWHM)
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
%          Raymundo Cassani, 2025

% ===== LOAD INPUTS =====
% Parase inputs
if (nargin < 4) || isempty(Aggregation)
    Aggregation = 'ignore'; % Ignores aggregation, returns realigned dynamic volume
end
if (nargin < 3) || isempty(FWHM)
    FWHM = 0; % Default 0 mm smoothing
end
FWHM = FWHM * [1 1 1];

% Progress bar
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'Realignment', 'Loading input volumes...');
end
if isstruct(MriFile) % USAGE: [sMriAlign, fileTag] = mri_realign(sMri, Method)
    sMri = MriFile;
elseif ischar(MriFile) % USAGE: [MriFileAlign, fileTag] = mri_realign(MriFile, Method)
    % Get volume in bst format
    sMri = in_mri_bst(MriFile);
else
    bst_progress('stop');
    error('Invalid call.');
end

% Initialize returned variables
MriRealign = []; sMriAlign = []; 
Comment=sMri.Comment; History=sMri.History;
fileTag   = '';

if size(sMri.Cube, 4) == 1
    MriRealign = sMri;  
    errMsg = 'Source volume is static (3D)';
      disp(['BST> Warning: ' errMsg]);
      disp(['BST> Skipping Realignment - Returned original volume' ]);
      bst_progress('stop');
      return;
end

% Define temporary directory for exporting nifti files
TmpDir = bst_get('BrainstormTmpDir', 0, 'mri_frames');
% Initialize output file names
sMriOutNii = bst_fullfile(TmpDir, 'orig.nii');

% ====== ALIGN FRAMES =======
nFrames = size(sMri.Cube, 4);  % Number of frames
if nFrames==1 % If nFrames is 1, volume is static
    return
else
    % Remove NaN
    sMri.Cube(isnan(sMri.Cube)) = 0;
    out_mri_nii (sMri, sMriOutNii);% Export as Nifti to TmpDir
end

if ~isempty(Method)
    switch lower(Method)

        % ===== METHOD: SPM ALIGN =====
        case 'spm_realign'
            % Initialize SPM
            [isInstalled, errMsg] = bst_plugin('Install', 'spm12');
            if ~isInstalled
                if ~isProgress
                    bst_progress('stop');
                end
                return;
            end
            bst_plugin('SetProgressLogo', 'spm12');
    
            % === CALL SPM REALIGN ===
            bst_progress('text', sprintf('Aligning %d frames using SPM Realign...', nFrames));
            matlabbatch = {};
            if ~isempty(FWHM) && isequal (FWHM, [0, 0, 0]) % Create realign batch, skip smoothing
                MriFileRealign = bst_fullfile(TmpDir, 'orig.nii'); % SPM output: dynamic volume with realigned frames
                matlabbatch{1}.cfg_basicio.file_dir.file_ops.file_fplist.dir = {TmpDir};
                matlabbatch{1}.cfg_basicio.file_dir.file_ops.file_fplist.filter = 'orig';
                matlabbatch{1}.cfg_basicio.file_dir.file_ops.file_fplist.rec = 'FPList';
                matlabbatch{2}.spm.util.exp_frames.files(1) = cfg_dep('File Selector (Batch Mode): Selected Files (orig)', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files'));
                matlabbatch{2}.spm.util.exp_frames.frames = Inf;
                matlabbatch{3}.spm.spatial.realign.estwrite.data{1}(1) = cfg_dep('Expand image frames: Expanded filename list.', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files'));
                matlabbatch{3}.spm.spatial.realign.estwrite.eoptions.quality = 0.9;
                matlabbatch{3}.spm.spatial.realign.estwrite.eoptions.sep = 4;
                matlabbatch{3}.spm.spatial.realign.estwrite.eoptions.fwhm = 5;
                matlabbatch{3}.spm.spatial.realign.estwrite.eoptions.rtm = 0;
                matlabbatch{3}.spm.spatial.realign.estwrite.eoptions.interp = 3;
                matlabbatch{3}.spm.spatial.realign.estwrite.eoptions.wrap = [0 0 0];
                matlabbatch{3}.spm.spatial.realign.estwrite.eoptions.weight = '';
                matlabbatch{3}.spm.spatial.realign.estwrite.roptions.which = [2 1];
                matlabbatch{3}.spm.spatial.realign.estwrite.roptions.interp = 4;
                matlabbatch{3}.spm.spatial.realign.estwrite.roptions.wrap = [0 0 0];
                matlabbatch{3}.spm.spatial.realign.estwrite.roptions.mask = 0;
                matlabbatch{3}.spm.spatial.realign.estwrite.roptions.prefix = 'r';
            else
                MriFileRealign = bst_fullfile(TmpDir, 'sorig.nii'); % SPM output: dynamic volume with realigned frames
                matlabbatch{1}.cfg_basicio.file_dir.file_ops.file_fplist.dir = {TmpDir};
                matlabbatch{1}.cfg_basicio.file_dir.file_ops.file_fplist.filter = 'orig';
                matlabbatch{1}.cfg_basicio.file_dir.file_ops.file_fplist.rec = 'FPList';
                matlabbatch{2}.spm.util.exp_frames.files(1) = cfg_dep('File Selector (Batch Mode): Selected Files (orig)', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files'));
                matlabbatch{2}.spm.util.exp_frames.frames = Inf;
                matlabbatch{3}.spm.spatial.smooth.data(1) = cfg_dep('Expand image frames: Expanded filename list.', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files'));
                matlabbatch{3}.spm.spatial.smooth.fwhm = FWHM;
                matlabbatch{3}.spm.spatial.smooth.dtype = 0;
                matlabbatch{3}.spm.spatial.smooth.im = 0;
                matlabbatch{3}.spm.spatial.smooth.prefix = 's';
                matlabbatch{4}.spm.spatial.realign.estwrite.data{1}(1) = cfg_dep('Smooth: Smoothed Images', substruct('.','val', '{}',{3}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files'));
                matlabbatch{4}.spm.spatial.realign.estwrite.eoptions.quality = 0.9;
                matlabbatch{4}.spm.spatial.realign.estwrite.eoptions.sep = 4;
                matlabbatch{4}.spm.spatial.realign.estwrite.eoptions.fwhm = 5;
                matlabbatch{4}.spm.spatial.realign.estwrite.eoptions.rtm = 0;
                matlabbatch{4}.spm.spatial.realign.estwrite.eoptions.interp = 2;
                matlabbatch{4}.spm.spatial.realign.estwrite.eoptions.wrap = [0 0 0];
                matlabbatch{4}.spm.spatial.realign.estwrite.eoptions.weight = '';
                matlabbatch{4}.spm.spatial.realign.estwrite.roptions.which = [2 1];
                matlabbatch{4}.spm.spatial.realign.estwrite.roptions.interp = 4;
                matlabbatch{4}.spm.spatial.realign.estwrite.roptions.wrap = [0 0 0];
                matlabbatch{4}.spm.spatial.realign.estwrite.roptions.mask = 0;
                matlabbatch{4}.spm.spatial.realign.estwrite.roptions.prefix = 'r';
            end
            spm('defaults', 'PET');
            spm_jobman('run', matlabbatch);
            sMriAlign = in_mri(MriFileRealign, 'Nifti1', 0, 0, 1);  % Import the realigned dynamic volume
    end

    % ===== UPDATE HISTORY ========
    fileTag = ['_' Method]; % Output file tag
    sMriAlign.History=History; 
    sMriAlign.Comment=Comment;
    sMriAlign = bst_history('add', sMriAlign, 'realign', sprintf(['Realigned %d frames in dynamic volume using ' Method ' '], nFrames));   % Add history entry
    if FWHM > 0
        sMri= bst_history('add', sMri, 'smooth', sprintf('Volume smoothed with %d mm kernel ', FWHM(1)));
    end
else
    sMriAlign = sMri;
end

% ===== FRAME AGGREGATION ========
if ~isempty(Aggregation) && ~strcmpi(Aggregation, 'ignore')
    [sMriAlign, aggregateFileTag] = mri_aggregate(sMriAlign, Aggregation);
    fileTag = [fileTag, aggregateFileTag];
end

file_delete(TmpDir, 1, 1);

% ===== SAVE NEW FILE =====
sMriAlign.Comment = [sMri.Comment, fileTag]; % Add file tag
% Save output
if ~isempty(MriFile) && ischar(MriFile) % If input is path to Brainstorm MRI file
    [sSubject, iSubject, ~] = bst_get('MriFile', MriFile);
    % Save new MRI in Brainstorm format
    MriFileFull = file_unique(strrep(file_fullpath(MriFile), '.mat', [fileTag '.mat']));
    out_mri_bst(sMriAlign, MriFileFull);
    % Register new MRI
    iAnatomy = length(sSubject.Anatomy) + 1;
    sSubject.Anatomy(iAnatomy) = db_template('Anatomy');
    sSubject.Anatomy(iAnatomy).FileName = file_short(MriFileFull);
    sSubject.Anatomy(iAnatomy).Comment  = sMriAlign.Comment;
    % Update subject structure
    bst_set('Subject', iSubject, sSubject);
    % Refresh tree
    panel_protocols('UpdateNode', 'Subject', iSubject);
    panel_protocols('SelectNode', [], 'anatomy', iSubject, iAnatomy);
    % Save database
    db_save();
    % Return new MRI file
    MriRealign = file_short(MriFileFull);
else
    % Return output structure
    MriRealign = sMriAlign;
end

% Close progress bar
if ~isProgress
    bst_progress('stop');
end
end