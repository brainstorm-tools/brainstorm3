function [sMri, errMsg] = bst_normalize_mni(MriFile, Method)
% BST_NORMALIZE_MNI: Compute deformation fields to the MNI ICBM152 space.
%
% USAGE:  [sMri, errMsg] = bst_normalize_mni(MriFile, Method='maff8')
%         [sMri, errMsg] = bst_normalize_mni(sMri,    Method='maff8')
%                          bst_normalize_mni('install')               % Only installs default SPM tpm.nii
%
% INPUTS:
%    - MriFile : Relative path to a MRI file in the Brainstorm database
%    - sMri    : Brainstorm MRI structure
%    - Method  : String defining the method to use for the registration
%                'maff8'   : SPM mutual information algorithm (affine transform)
%                'segment' : SPM12 segment

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
% Authors: Francois Tadel, 2015-2020

%% ===== PARSE INPUTS =====
% Inializations
global GlobalData;
errMsg = [];
% Usage: bst_normalize_mni('install')
if isequal(MriFile, 'install')
    isInstall = 1;
    sMri = [];
else
    isInstall = 0;
    % Usage: bst_normalize_mni(sMri)
    if ~ischar(MriFile)
        sMri = MriFile;
        MriFile = [];
    % Usage: bst_normalize_mni(MriFile)
    else
        sMri = [];
    end
end
% Other parameters
if (nargin < 2) || isempty(Method)
    Method = 'maff8';
end
    
    
%% ===== GET SPM TEMPLATE =====
% Open progress bar
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'MNI normalization', 'Initialization...');
end
% Get template file
TpmFile = bst_get('SpmTpmAtlas');
% If it does not exist: download
if isempty(TpmFile) || ~file_exist(TpmFile)
    % Create folder
    if ~file_exist(bst_fileparts(TpmFile))
        mkdir(bst_fileparts(TpmFile));
    end
    % URL to download
    tmpUrl = 'http://neuroimage.usc.edu/bst/getupdate.php?t=SPM_TPM';
    % Path to downloaded file
    tpmZip = bst_fullfile(bst_get('BrainstormUserDir'), 'defaults', 'spm', 'SPM_TPM');
    % Download file
    errMsg = gui_brainstorm('DownloadFile', tmpUrl, tpmZip, 'Download template');
    % Error message
    if ~isempty(errMsg)
        errMsg = ['Impossible to download template:' 10 errMsg];
        return;
    end
    % Progress bar
    bst_progress('text', 'Importing SPM template...');
    % URL: Download zip file
    try
        unzip(tpmZip, bst_fileparts(tpmZip));
    catch
        errMsg = ['Could not unzip anatomy template: ' 10 10 lasterr];
        disp(['BST> Error: ' errMsg]);
        file_delete(tpmZip, 1);
        if ~isProgress
            bst_progress('stop');
        end
        return;
    end
    % Delete zip file
    file_delete(tpmZip, 1);
    % Get template file
    TpmFile = bst_get('SpmTpmAtlas');
    if isempty(TpmFile) || ~file_exist(TpmFile)
        errMsg = 'Missing file TPM.nii';
        return;
    end
end
% If only installing: exit
if isInstall
    return;
end


%% ===== LOAD ANATOMY =====
if isempty(sMri)
    % Progress bar
    bst_progress('text', 'Loading input MRI...');
    % Check if it is loaded in memory
    [sMri, iLoadedMri] = bst_memory('GetMri', MriFile);
    % If not: load it from the file
    if isempty(sMri)
        sMri = in_mri_bst(MriFile);
    end
else
    iLoadedMri = [];
end

%% ===== MNI NORMALIZATION =====
TpmFiles = [];
try
    switch (Method)
        % SPM12 LINEAR MUTUAL INFORMATION
        case 'maff8'
            % Progress bar
            bst_progress('text', 'Resampling MRI...');
            % Resample volume if needed
            if any(abs(sMri.Voxsize - [1 1 1]) > 0.001)
                [sMriRes, Tres] = mri_resample(sMri, [256 256 256], [1 1 1]);
            else
                sMriRes = sMri;
                Tres = [];
            end
            % Compute affine transformation to MNI space
            Tmni = mri_normalize_maff(sMriRes, TpmFile);
            % Append the resampling transformation matrix
            if ~isempty(Tres)
                Tmni = Tmni * Tres;
            end
            % Save results into the MRI structure
            sMri.NCS.R = Tmni(1:3,1:3);
            sMri.NCS.T = Tmni(1:3,4);
            
        % SPM12 SEGMENT 
        case 'segment'
            % Check SPM installation
            bst_spm_init(0);
            % Progress bar
            bst_progress('text', 'Running SPM batch... (see command window)');
            % Compute non-linear registration to MNI space
            [sMri, TpmFiles] = mri_normalize_segment(sMri, TpmFile);
            if isempty(sMri)
                errMsg = 'SPM Segment failed.';
                return;
            end
    end
catch
    errMsg = ['bst_normalize_mni/' Method ': ' lasterr()];
    sMri = [];
    return;
end


%% ===== SAVE RESULTS =====
bst_progress('text', 'Saving normalization...');
% Compute default fiducials positions based on MNI coordinates
sMri = mri_set_default_fid(sMri, 'maff8');
% Save modifications in the MRI file
if ~isempty(MriFile)
    bst_save(file_fullpath(MriFile), sMri, 'v6');
end


%% ===== UPDATE LOADED FIGURES =====
% If the MRI is currently loaded
if ~isempty(iLoadedMri)
    % Update structures
    GlobalData.Mri(iLoadedMri).NCS.R  = sMri.NCS.R;
    GlobalData.Mri(iLoadedMri).NCS.T  = sMri.NCS.T;
    GlobalData.Mri(iLoadedMri).NCS.AC = sMri.NCS.AC;
    GlobalData.Mri(iLoadedMri).NCS.PC = sMri.NCS.PC;
    GlobalData.Mri(iLoadedMri).NCS.IH = sMri.NCS.IH;
    GlobalData.Mri(iLoadedMri).NCS.Origin = sMri.NCS.Origin;
    if isfield(sMri.NCS,'y') && isfield(sMri.NCS,'iy') && isfield(sMri.NCS,'y_vox2ras')
        GlobalData.Mri(iLoadedMri).NCS.y         = sMri.NCS.y;
        GlobalData.Mri(iLoadedMri).NCS.iy        = sMri.NCS.iy;
        GlobalData.Mri(iLoadedMri).NCS.y_vox2ras = sMri.NCS.y_vox2ras;
    end
    GlobalData.Mri(iLoadedMri).SCS.R   = sMri.SCS.R;
    GlobalData.Mri(iLoadedMri).SCS.T   = sMri.SCS.T;
    GlobalData.Mri(iLoadedMri).SCS.NAS = sMri.SCS.NAS;
    GlobalData.Mri(iLoadedMri).SCS.LPA = sMri.SCS.LPA;
    GlobalData.Mri(iLoadedMri).SCS.RPA = sMri.SCS.RPA;
    GlobalData.Mri(iLoadedMri).SCS.Origin = sMri.SCS.Origin;
end


%% ===== TISSUE CLASSIFICATION =====
% Import tissue classification
if ~isempty(TpmFiles) && ~isempty(MriFile)
    bst_progress('text', 'Loading tissue segmentations...');
    % Get subject
    [sSubject, iSubject] = bst_get('MriFile', MriFile);
    % Import tissue classification
    import_mri(iSubject, TpmFiles, 'SPM-TPM', 0, 1, 'tissues_segment');
end

% Close progress bar
if ~isProgress
    bst_progress('stop');
end



