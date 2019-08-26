function [sMri, errMsg] = bst_normalize_mni(MriFile)
% BST_NORMALIZE_MNI:  Normalize the subject anatomy to the MNI ICBM152 template 
%                     using SPM mutual information algorithm (affine transform).
% 
% USAGE:  [sMri, errMsg] = bst_normalize_mni(MriFile)
%         [sMri, errMsg] = bst_normalize_mni(sMri)
%                          bst_normalize_mni('install')

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2015-2019

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

%% ===== GET SPM TEMPLATE =====
% Open progress bar
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'Normalize anatomy', 'Initialization...');
end
% Get template file
tpmFile = bst_get('SpmTpmAtlas');
% If it does not exist: download
if isempty(tpmFile) || ~file_exist(tpmFile)
    % Create folder
    if ~file_exist(bst_fileparts(tpmFile))
        mkdir(bst_fileparts(tpmFile));
    end
    % URL to download
    tmpUrl = 'https://neuroimage.usc.edu/bst/getupdate.php?t=SPM_TPM';
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
% Progress bar
bst_progress('text', 'Resampling MRI...');
% Resample volume if needed
if any(abs(sMri.Voxsize - [1 1 1]) > 0.001)
    [sMriRes, Tres] = mri_resample(sMri, [256 256 256], [1 1 1]);
else
    sMriRes = sMri;
    Tres = [];
end


%% ===== ESTIMATE MNI TRANSFORMATION =====
% Compute affine transformation to MNI space
try
    Tmni = mri_register_maff(sMriRes);
    % Transf = mri_register_ls(sMri);
catch
    errMsg = ['mri_register_maff: ' lasterr()];
    sMri = [];
    return;
end
% Append the resampling transformation matrix
if ~isempty(Tres)
    Tmni = Tmni * Tres;
end


%% ===== SAVE RESULTS =====
bst_progress('text', 'Saving normalization...');
% Save results into the MRI structure
sMri.NCS.R = Tmni(1:3,1:3);
sMri.NCS.T = Tmni(1:3,4);
% Compute default fiducials positions based on MNI coordinates
sMri = mri_set_default_fid(sMri);
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
    GlobalData.Mri(iLoadedMri).SCS.R   = sMri.SCS.R;
    GlobalData.Mri(iLoadedMri).SCS.T   = sMri.SCS.T;
    GlobalData.Mri(iLoadedMri).SCS.NAS = sMri.SCS.NAS;
    GlobalData.Mri(iLoadedMri).SCS.LPA = sMri.SCS.LPA;
    GlobalData.Mri(iLoadedMri).SCS.RPA = sMri.SCS.RPA;
    GlobalData.Mri(iLoadedMri).SCS.Origin = sMri.SCS.Origin;
end
% Close progress bar
if ~isProgress
    bst_progress('stop');
end

end    


