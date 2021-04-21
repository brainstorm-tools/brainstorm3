function [sMriT1, errMsg] = bst_normalize_mni(T1File, Method, T2File)
% BST_NORMALIZE_MNI: Compute deformation fields to the MNI ICBM152 space.
%
% USAGE:  [sMriT1, errMsg] = bst_normalize_mni(T1File, Method='maff8', T2File=[])
%         [sMriT1, errMsg] = bst_normalize_mni(sMriT1, Method='maff8', sMriT2=[])
%                            bst_normalize_mni('install')               % Only installs default SPM tpm.nii
%
% INPUTS:
%    - T1File : Relative path to a T1 MRI file in the Brainstorm database
%    - sMriT1 : Brainstorm T1 MRI structure
%    - Method : String defining the method to use for the registration
%               'maff8'   : SPM mutual information algorithm (affine transform)
%               'segment' : SPM12 segment
%    - T2File : Relative path to a T2 MRI file in the Brainstorm database
%    - sMriT2 : Brainstorm T2 MRI structure

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
% Authors: Francois Tadel, 2015-2021

%% ===== PARSE INPUTS =====
% Inializations
global GlobalData;
errMsg = [];
% Usage: bst_normalize_mni('install')
if isequal(T1File, 'install')
    isInstall = 1;
    sMriT1 = [];
else
    isInstall = 0;
    % Usage: bst_normalize_mni(sMriT1)
    if ~ischar(T1File)
        sMriT1 = T1File;
        T1File = [];
    % Usage: bst_normalize_mni(T1File)
    else
        sMriT1 = [];
    end
end
% Default method
if (nargin < 2) || isempty(Method)
    Method = 'maff8';
end
% T2 MRI
if (nargin < 3) || isempty(T2File)
    T2File = [];
    sMriT2 = [];
else
    if ~ischar(T2File)
        sMriT2 = T2File;
        T2File = [];
    else
        sMriT2 = [];
    end
end


%% ===== GET SPM TEMPLATE =====
% Open progress bar
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'MNI normalization', 'Initialization...');
end
bst_plugin('SetProgressLogo', 'spm12');
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
% T1 MRI
if isempty(sMriT1)
    % Progress bar
    bst_progress('text', 'Loading input MRI...');
    % Check if it is loaded in memory
    [sMriT1, iLoadedMri] = bst_memory('GetMri', T1File);
    % If not: load it from the file
    if isempty(sMriT1)
        sMriT1 = in_mri_bst(T1File);
    end
else
    iLoadedMri = [];
end
% T2 MRI
if isempty(sMriT2) && ~isempty(T2File)
    sMriT2 = in_mri_bst(T2File);
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
            if any(abs(sMriT1.Voxsize - [1 1 1]) > 0.001)
                [sMriRes, Tres] = mri_resample(sMriT1, [256 256 256], [1 1 1], 'linear');
            else
                sMriRes = sMriT1;
                Tres = [];
            end
            % Compute affine transformation to MNI space
            Tmni = mri_normalize_maff(sMriRes, TpmFile);
            % Append the resampling transformation matrix
            if ~isempty(Tres)
                Tmni = Tmni * Tres;
            end
            % Save results into the MRI structure
            sMriT1.NCS.R = Tmni(1:3,1:3);
            sMriT1.NCS.T = Tmni(1:3,4);
            
        % SPM12 SEGMENT 
        case 'segment'
            % Initialize SPM
            [isInstalled, errMsg] = bst_plugin('Install', 'spm12');
            if ~isInstalled
                return;
            end
            % Progress bar
            bst_progress('text', 'Running SPM batch... (see command window)');
            % Compute non-linear registration to MNI space
            [sMriT1, TpmFiles] = mri_normalize_segment(sMriT1, TpmFile, sMriT2);
            if isempty(sMriT1)
                errMsg = 'SPM Segment failed.';
                return;
            end
    end
catch
    errMsg = ['bst_normalize_mni/' Method ': ' lasterr()];
    sMriT1 = [];
    return;
end


%% ===== SAVE RESULTS =====
bst_progress('text', 'Saving normalization...');
% Compute default fiducials positions based on MNI coordinates
sMriT1 = mri_set_default_fid(sMriT1, 'maff8');
% Save modifications in the MRI file
if ~isempty(T1File)
    bst_save(file_fullpath(T1File), sMriT1, 'v6');
end


%% ===== UPDATE LOADED FIGURES =====
% If the MRI is currently loaded
if ~isempty(iLoadedMri)
    % Update structures
    GlobalData.Mri(iLoadedMri).NCS.R  = sMriT1.NCS.R;
    GlobalData.Mri(iLoadedMri).NCS.T  = sMriT1.NCS.T;
    GlobalData.Mri(iLoadedMri).NCS.AC = sMriT1.NCS.AC;
    GlobalData.Mri(iLoadedMri).NCS.PC = sMriT1.NCS.PC;
    GlobalData.Mri(iLoadedMri).NCS.IH = sMriT1.NCS.IH;
    GlobalData.Mri(iLoadedMri).NCS.Origin = sMriT1.NCS.Origin;
    if isfield(sMriT1.NCS,'y') && isfield(sMriT1.NCS,'iy') && isfield(sMriT1.NCS,'y_vox2ras')
        GlobalData.Mri(iLoadedMri).NCS.y         = sMriT1.NCS.y;
        GlobalData.Mri(iLoadedMri).NCS.iy        = sMriT1.NCS.iy;
        GlobalData.Mri(iLoadedMri).NCS.y_vox2ras = sMriT1.NCS.y_vox2ras;
    end
    GlobalData.Mri(iLoadedMri).SCS.R   = sMriT1.SCS.R;
    GlobalData.Mri(iLoadedMri).SCS.T   = sMriT1.SCS.T;
    GlobalData.Mri(iLoadedMri).SCS.NAS = sMriT1.SCS.NAS;
    GlobalData.Mri(iLoadedMri).SCS.LPA = sMriT1.SCS.LPA;
    GlobalData.Mri(iLoadedMri).SCS.RPA = sMriT1.SCS.RPA;
    GlobalData.Mri(iLoadedMri).SCS.Origin = sMriT1.SCS.Origin;
end


%% ===== TISSUE CLASSIFICATION =====
% Import tissue classification
if ~isempty(TpmFiles) && ~isempty(T1File)
    bst_progress('text', 'Loading tissue segmentations...');
    % Get subject
    [sSubject, iSubject] = bst_get('MriFile', T1File);
    % Import tissue classification
    import_mri(iSubject, TpmFiles, 'SPM-TPM', 0, 1, 'tissues_segment');
end

% Close progress bar
bst_plugin('SetProgressLogo', []);
if ~isProgress
    bst_progress('stop');
end



