function  [sMriAlign, sMriMean, fileTag] = mri_realign (MriFile, Method, FWHM)
% MRI_REALIGN: Extract frames from dynamic volumes, realign and compute the mean across frames.
%
% USAGE:  [sMriAlign, sMriMean, fileTag] = mri_realign(MriFile, Method, FWHM)
%         [sMriAlign, sMriMean, fileTag] = mri_realign(MriFile)
%         [sMriAlign, sMriMean, fileTag] = mri_realign(sMri)
%         [sMriAlign, sMriMean, fileTag] = mri_realign(MriFile, Method)
%         [sMriAlign, sMriMean, fileTag] = mri_realign(sMri, Method)
%
% INPUTS:
%    - MriFile : Relative path to the Brainstorm Mri file to realign
%    - Method  : Method used for the realignment of the volume (default is spm_realign): 
%                       -'spm_realign' :        uses the SPM plugin  
%                       -'fs_realign'  :        uses Freesurfer - TO DO
%
% OUTPUTS:
%    - sMriRealign      : Dynamic Brainstorm Mri structure with realigned frames
%    - sMriMean         : Static Brainstorm Mri structure with mean frame
%    - MriFileMean      : Relative path to the Brainstorm MRI file containing the computed frame mean - static volume (dim4=1) 
%    - MriFileRealign   : Relative path Brainstorm MRI file containing realigned frames - dynamic volume (dim4>1)
%    - errMsg           : Error messages if any
%    - fileTag          : Tag added to the comment/filename

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
% WARRANTY, EXPRESS OR IMPLIED, IN>CLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Diellor Basha, 2024    
%          Chinmay Chinara, 2023
%          Francois Tadel, 2016-2023
%          

% ===== LOAD INPUTS =====
% Parse inputs
if (nargin < 3) || isempty(FWHM)
    FWHM = repelem(6, 3); % Default 6 mm smoothing
else
    FWHM = repelem(FWHM, 3);
end
if (nargin < 2) || isempty(Method)
    Method = 'spm_align';
end

% Progress bar
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'Realignment', 'Loading input volumes...');
end
    if isstruct(MriFile) % USAGE: [sMriMean, sMriAlign, fileTag] = mri_realign(sMri, Method)
        sMri = MriFile; 
        MriFile = [];
    elseif ischar(MriFile) % USAGE: [MriFileMean, MriFileAlign, fileTag, sMriMean] = mri_realign(MriFile, Method)
        % Get volume in bst format
        sMri = in_mri_bst(MriFile);
    else 
        bst_progress('stop');
        error('Invalid call.');
    end
% Initialize returned variables
    sMriAlign = sMri;
    sMriAlign.Cube=zeros(size(sMri.Cube));
    sMriMean  = [];
    fileTag   = '';
% Define temporary directory for exporting nifti files
    TmpDir = bst_get('BrainstormTmpDir', 0, 'mri_frames');
% Initialize output file names
    sMriOutNii = bst_fullfile(TmpDir, 'orig.nii'); 
    MriFileMean = bst_fullfile(TmpDir, 'meansorig.nii'); % SPM output: static volume with mean of realigned frames
    MriFileRealign = bst_fullfile(TmpDir, 'sorig.nii'); % SPM output: dynamic volume with realigned frames

% ====== ALIGN FRAMES =======
numFrames = size(sMri.Cube, 4);  % Number of frames
    if numFrames==1 % If numFrames is 1, volume is static 
        return
    else
        % Remove NaN
        if any(isnan(sMri.Cube(:)))
            sMri.Cube(isnan(sMri.Cube)) = 0;
        end
        out_mri_nii (sMri, sMriOutNii);% Export as Nifti to TmpDir
    end 

switch lower(Method)

    % ===== METHOD: SPM ALIGN =====
    case 'spm_align'
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
  bst_progress('text', sprintf('Aligning %d frames using SPM Realign...', numFrames));
      matlabbatch = {};
  if ~isempty(FWHM) && isequal (FWHM, [0, 0, 0])     % Create realign batch, skip smoothing
      MriFileMean = bst_fullfile(TmpDir, 'meanorig.nii'); % SPM output: static volume with mean of realigned frames
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
    MriFileMean = bst_fullfile(TmpDir, 'meansorig.nii'); % SPM output: static volume with mean of realigned frames
    MriFileRealign = bst_fullfile(TmpDir, 'sorig.nii'); % SPM output: dynamic volume with realigned frames
    matlabbatch{1}.cfg_basicio.file_dir.file_ops.file_fplist.dir = {TmpDir};
    matlabbatch{1}.cfg_basicio.file_dir.file_ops.file_fplist.filter = 'orig';
    matlabbatch{1}.cfg_basicio.file_dir.file_ops.file_fplist.rec = 'FPList';
    matlabbatch{2}.spm.util.exp_frames.files(1) = cfg_dep('File Selector (Batch Mode): Selected Files (orig)', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files'));
    matlabbatch{2}.spm.util.exp_frames.frames = Inf;
    matlabbatch{3}.spm.spatial.smooth.data(1) = cfg_dep('Expand image frames: Expanded filename list.', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files'));
    matlabbatch{3}.spm.spatial.smooth.fwhm = [6 6 6];
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
sMriAlign = in_mri(MriFileRealign, 'ALL', 0, 0);  % Import the realigned dynamic volume     
sMriMean = in_mri_nii(MriFileMean, 0, 1, 1); % Import mean and apply multiplicative rescaling, if any           
    case 'freesurfer'
        % TO DO
end

% ===== UPDATE HISTORY ========       
fileTag = '_spm_realign'; % Output file tag
sMriAlign.Comment = [sMriAlign.Comment, fileTag]; % Add file tag
sMriAlign = bst_history('add', sMriAlign, 'realign', ['PET Frames realigned using (' Method '): ']);   % Add history entry
sMriMean.Comment = [fileTag, '_mean']; % Add file tag
sMriMean = bst_history('add', sMriMean, 'realign', ['PET Frames realigned using (' Method '): ']);
sMriMean = bst_history('add', sMriMean, 'mean realigned', ['Mean of realigned PET using (' Method '): ']);

file_delete(TmpDir, 1, 1);

% Close progress bar
if ~isProgress
    bst_progress('stop');
end
end