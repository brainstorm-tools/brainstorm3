function bst_extract_fieldtrip_spm()
% BST_EXTRACT_FIELDTRIP_SPM Make a copy of some of the FieldTrip and SPM
% functions used by Brainstorm in the deployment folder, aimed to be included in
% the MCC compilation of Brainstorm.
%
% Requirements: Run spm_make_standalone first
%
% Brainstorm features using external SPM functions:
%  - Anatomy: Import MRI > DICOM converter
%  - Anatomy: Import MRI > MRI coregistration (SPM)
%      => Error: Missing spm_cfg
%  - Input: Read SPM .mat/.dat recordings
%  - Output: Save SPM .mat/.dat recordings
%  - Process1: Import > Import anatomy > Generate SPM canonical surfaces
%    => Missing TPM.nii
%  - Process1: Epilepsy > Epileptogenicity maps
%    => Error:  Undefined function 'list' for input arguments of type 'cell' >cfg_util.m>local_getcjid2subs at 1365
%  - Process1: Test > Apply statistic threshold
%  
% Brainstorm features using external FieldTrip:
%  - Input: Read FieldTrip data structure
%  - Process1: Import > Import anatomy > FieldTrip: ft_volumesegment
%    => Add Image Processing + Parallel toolboxes to Matlab 2015b
%  - Process1: Frequency > FieldTrip: ft_mtmconvol (multitaper)
%  - Process1: Standardize > FieldTrip: ft_channelrepair
%  - Process1: Standardize > FieldTrip: ft_scalpcurrentdensity
%  - Process1: Sources > FieldTrip: ft_prepare_leadfield
%    => cfg.template, cfg.tmp?
%    => Missing eeg_leadfield4
%    => MRI: Undefined function or variable 'GridLoc'
%  - Process1: Sources > FieldTrip: ft_dipolefitting
%  - Process1: Sources > FieldTrip: ft_sourceanalysis
%  - Process2: Test > FieldTrip: ft_timelockstatistics
%    =>  could not find the corresponding function for cfg.method="montecarlo"
%  - Process2: Test > FieldTrip: ft_sourcestatistics
%    =>
%  - Process2: Test > FieldTrip: ft_freqstatistics
%    =>

% @=============================================================================
% This software is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPL
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
% Authors: Francois Tadel, 2019


% ===== CONFIGURATION =====
% Source folders 
FieldTripDir ='C:\Work\Dev\Divers\fieldtrip-20190211';
SpmDir = 'C:\Work\Dev\Divers\spm12';
% Destination folder
IncludeDir = 'C:\Work\Dev\brainstorm3_deploy\spmtrip';
PrivateDir = fullfile(IncludeDir, 'private');

% List required functions
needFunc = {
    fullfile(FieldTripDir, 'ft_defaults.m'), ...
    fullfile(FieldTripDir, 'fileio', 'ft_read_headshape.m'), ...
    fullfile(FieldTripDir, 'forward', 'ft_apply_montage.m'), ...
    fullfile(FieldTripDir, 'forward', 'ft_convert_units.m'), ...
    fullfile(FieldTripDir, 'forward', 'ft_compute_leadfield.m'), ...
    fullfile(FieldTripDir, 'ft_channelrepair.m'), ...
    fullfile(FieldTripDir, 'ft_dipolefitting.m'), ...
    fullfile(FieldTripDir, 'ft_freqstatistics.m'), ...
    fullfile(FieldTripDir, 'ft_prepare_headmodel.m'), ...
    fullfile(FieldTripDir, 'ft_prepare_leadfield.m'), ...
    fullfile(FieldTripDir, 'ft_prepare_neighbours.m'), ...
    fullfile(FieldTripDir, 'ft_prepare_sourcemodel.m'), ...
    fullfile(FieldTripDir, 'ft_scalpcurrentdensity.m'), ...
    fullfile(FieldTripDir, 'ft_sourceanalysis.m'), ...
    fullfile(FieldTripDir, 'ft_sourcestatistics.m'), ...
    fullfile(FieldTripDir, 'ft_timelockanalysis.m'), ...
    fullfile(FieldTripDir, 'ft_timelockstatistics.m'), ...
    fullfile(FieldTripDir, 'ft_statistics_montecarlo.m'), ...
    fullfile(FieldTripDir, 'ft_volumesegment.m'), ...
    fullfile(FieldTripDir, 'plotting', 'ft_plot_mesh.m'), ...
    fullfile(FieldTripDir, 'plotting', 'ft_plot_sens.m'), ...
    fullfile(FieldTripDir, 'plotting', 'ft_plot_vol.m'), ...
    fullfile(FieldTripDir, 'specest', 'ft_specest_mtmconvol.m'), ...
    fullfile(FieldTripDir, 'utilities', 'ft_datatype_sens.m'), ...
    ...
    fullfile(SpmDir, 'spm.m'), ...
    fullfile(SpmDir, 'spm_affine_priors.m'), ...
    fullfile(SpmDir, 'spm_bsplinc.m'), ...
    fullfile(SpmDir, 'spm_data_read.m'), ...
    fullfile(SpmDir, 'spm_dicom_convert.m'), ...
    fullfile(SpmDir, 'spm_dicom_header.m'), ...
    fullfile(SpmDir, 'spm_dicom_text_to_dict.m'), ...
    fullfile(SpmDir, 'spm_dilate.m'), ...
    fullfile(SpmDir, 'spm_eeg_inv_mesh.m'), ...
    fullfile(SpmDir, 'spm_eeg_inv_spatnorm.m'), ...
    fullfile(SpmDir, 'spm_eeg_load.m'), ...
    fullfile(SpmDir, 'spm_eeg_morlet.m'), ...
    fullfile(SpmDir, 'spm_eeg_specest_mtmconvol.m'), ...
    fullfile(SpmDir, 'spm_figure.m'), ...
    fullfile(SpmDir, 'spm_fileparts.m'), ...
    fullfile(SpmDir, 'spm_get_defaults.m'), ...
    fullfile(SpmDir, 'spm_get_space.m'), ...
    fullfile(SpmDir, 'spm_global.m'), ...
    fullfile(SpmDir, 'spm_input.m'), ...
    fullfile(SpmDir, 'spm_jobman.m'), ...
    fullfile(SpmDir, 'spm_matrix.m'), ...
    fullfile(SpmDir, 'spm_mesh_smooth.m'), ...
    fullfile(SpmDir, 'spm_plot_convergence.m'), ...
    fullfile(SpmDir, 'spm_read_vols.m'), ...
    fullfile(SpmDir, 'spm_sample_vol.m'), ...
    fullfile(SpmDir, 'spm_select.m'), ...
    fullfile(SpmDir, 'spm_slice_vol.m'), ...
    fullfile(SpmDir, 'spm_str_manip.m'), ...
    fullfile(SpmDir, 'spm_swarp.m'), ...
    fullfile(SpmDir, 'spm_type.m'), ...
    fullfile(SpmDir, 'spm_u.m'), ...
    fullfile(SpmDir, 'spm_uc.m'), ...
    fullfile(SpmDir, 'spm_uc_Bonf.m'), ...
    fullfile(SpmDir, 'spm_vol.m'), ...
    fullfile(SpmDir, 'spm_write_vol.m'), ...
    fullfile(SpmDir, 'config', 'spm_cfg.m'), ...
};

% Extra data files
extraFiles = {...
    fullfile(SpmDir, 'spm_dicom_dict.txt'), ...
    fullfile(SpmDir, 'Contents.txt'), ...
    };

% ===== FILTER LIST =====
% Initalize FieldTrip
tic;
addpath(FieldTripDir);
ft_defaults;
% Initalize SPM
addpath(SpmDir);
addpath(fullfile(SpmDir, 'matlabbatch'));

% Detect missing functions
iMissing = find(~cellfun(@(c)exist(c,'file'), needFunc));
if iMissing
    for i = 1:length(iMissing)
        disp(['ERROR: Missing function: ', needFunc{iMissing(i)}]);
    end
    return;
end

% Destination folder (empty existing)
if isdir(IncludeDir)
    rmdir(IncludeDir, 's');
end
mkdir(IncludeDir);
mkdir(PrivateDir);

% Get all dependencies
disp('Building dependendy list...');
listDep = matlab.codetools.requiredFilesAndProducts(needFunc);

% Remove everything not coming from the SPM or FieldTrip folder
iExclude = find(cellfun(@(c)isempty(strfind(c,FieldTripDir)), listDep) & cellfun(@(c)isempty(strfind(c,SpmDir)), listDep));
listDep(iExclude) = [];

% Remove all the classes
iClass = find(~cellfun(@(c)isempty(strfind(c, '@')), listDep));
listDep(iClass) = [];

% Add all the 64bit versions of all the included mex-files
iMex = find(~cellfun(@(c)isempty(strfind(c, '.mexw64')), listDep));
for i = 1:length(iMex)
    for ext = {'.mexa64', '.mexmaci64'}
        extFile = strrep(listDep{iMex(i)}, '.mexw64', ext{1});
        if exist(extFile, 'file') && ~ismember(extFile, listDep)
            listDep{end+1} = extFile;
        end
    end
end

% Add extra data files
listDep = {listDep{:}, extraFiles{:}};

% Make sure the list contains unique files
listDep = unique(listDep);


% ===== COPY FILES =====
disp('Copying files...');
% Copy the FieldTrip class folders entirely
for className = {'@config'}
    system(['xcopy "' fullfile(FieldTripDir, className{1}), '" "', fullfile(IncludeDir, className{1}), '" /s /e /y /q /i']);
end
% Copy the SPM class folders entirely
for className = {'@file_array', '@gifti', '@meeg', '@nifti', '@xmltree'}
    system(['xcopy "' fullfile(SpmDir, className{1}), '" "', fullfile(IncludeDir, className{1}), '" /s /e /y /q /i']);
end
for className = {'@cfg_branch', '@cfg_const', '@cfg_dep', '@cfg_entry', '@cfg_exbranch', '@cfg_intree', '@cfg_item', '@cfg_leaf', '@cfg_menu', '@cfg_repeat'}
    system(['xcopy "' fullfile(SpmDir, 'matlabbatch', className{1}), '" "', fullfile(IncludeDir, className{1}), '" /s /e /y /q /i']);
end

% Copy all the dependency files
for i = 1:length(listDep)
    % If file shadows a Matlab builtin function: skip
    [fPath, fBase, fExt] = fileparts(listDep{i});
    if exist(fBase, 'builtin')
        disp(['Removed (Matlab builtin): ' listDep{i}]);
        continue;
    end
    % Copy file to include folder
    if ~isempty(strfind(listDep{i}, '\private\'))
        destDir = PrivateDir;
    else
        destDir = IncludeDir;
    end
    copyfile(listDep{i}, destDir);
    % Replace references to TPM.nii with Brainstorm's version
    if ismember(fBase, {'spm_cfg_norm', 'spm_cfg_preproc8', 'spm_cfg_preproc8', 'spm_cfg_tissue_volumes', 'spm_rewrite_job', ...
            'ft_volumebiascorrect', 'ft_volumenormalise', 'ft_volumesegment', 'spm_deface', 'spm_deformations', ...
            'spm_eeg_inv_spatnorm', 'spm_get_matdim', 'spm_dartel_norm_fun', 'spm_klaff', 'spm_shoot_norm'})
        % Read file
        ScriptFile = fullfile(destDir, [fBase, '.m']);
        fid = fopen(ScriptFile, 'rt');
        txtScript = fread(fid, [1, Inf], '*char');
        fclose(fid);
        % Replace references to TPM.nii
        txtScript = strrep(txtScript, 'spm(''dir''),''tpm'',''TPM.nii''', 'bst_get(''BrainstormUserDir''), ''defaults'', ''spm'', ''TPM.nii''');
        txtScript = strrep(txtScript, 'spm(''Dir''),''tpm'',''TPM.nii''', 'bst_get(''BrainstormUserDir''), ''defaults'', ''spm'', ''TPM.nii''');
        txtScript = strrep(txtScript, 'spm(''dir''),''tpm'',''TPM.nii,''', 'bst_get(''BrainstormUserDir''), ''defaults'', ''spm'', ''TPM.nii,''');
        txtScript = strrep(txtScript, 'spm(''dir''), ''tpm'', ''TPM.nii''', 'bst_get(''BrainstormUserDir''), ''defaults'', ''spm'', ''TPM.nii''');
        % Save modified script
        fid = fopen(ScriptFile, 'wt');
        fwrite(fid, txtScript);
        fclose(fid);
    end
end

% Print list of input directories
disp(sprintf('\nCopied %d files to %s', length(listDep), IncludeDir));
disp('List of source folders:');
dirList = unique(cellfun(@fileparts, listDep, 'UniformOutput', 0));
for i = 1:length(dirList)
    disp(['  ' dirList{i}]);
end

toc


