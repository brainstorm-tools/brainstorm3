function errMsg = seeg_contactid_gardel(iSubject)
% SEEG_CONTACTID_GARDEL: Handle GARDEL tool from Brainstorm
%
% USAGE:  errMsg = seeg_contactid_gardel(iSubject)
%
% INPUT:
%    - iSubject : Indice of the subject where to import the MRI
%                 If iSubject=0 : import MRI in default subject
% OUTPUT:
%    - errMsg   : String: error message if an error occurs

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
% Author: Chinmay Chinara, 2025

%% ===== PARSE INPUTS =====
% Intializations
errMsg = [];
isEdit = 0;
if ~isnumeric(iSubject) || (iSubject < 0)
    error('Invalid subject indice.');
end

%% ===== START EXTERNAL GARDEL TOOL FROM BRAINSTORM =====
if ~java_dialog('confirm', ['Warning: Switching from Brainstorm to GARDEL external tool.' 10 ...
                            'This will close all figures and hide the Brainstorm GUI.' 10 10 ...
                            'Do you want to continue?'], 'Start GARDEL tool')
    return
end

% Unload everything
bst_memory('UnloadAll', 'Forced');

% Check for GARDEL plugin installation
[isInstalledGardel, errMsg] = bst_plugin('Install', 'gardel');
if ~isInstalledGardel
    errMsg = bst_error(errMsg, 'GARDEL', 0);
    return;
end

% Get current subject and study
sSubject = bst_get('Subject', iSubject);
sStudy   = bst_get('StudyWithCondition', bst_fullfile(sSubject.Name, 'Implantation_Gardel'));

% Folders and files for GARDEL
TmpGardelDir = bst_get('BrainstormTmpDir', 0, 'gardel');
IntermediateFilesDir = bst_fullfile(TmpGardelDir, 'IntermediateFiles');
GardelElectrodeFile  = bst_fullfile(TmpGardelDir, '\ElectrodesAllCoordinates.txt');

% If editing using GARDEL, warn user that the existing channel data will be overwritten 
if ~isempty(sStudy) && ~isempty(sStudy.Channel)
    [isEdit, isCancel] = java_dialog('confirm', ['Warning: the existing "Gardel" implantation for this Subject will be overwritten.' 10 10 ...
                                               'Do do you want to overwrite the existing implantation?'], ...
                                               'Edit implantation using GARDEL tool');
    if ~isEdit || isCancel
        % Delete temporary folder
        file_delete(TmpGardelDir, 1, 1);
        return
    else
        % Export the Brainstorm channel file to GARDEL electrode .txt file
        ChannelFile = bst_fullfile(bst_get('ProtocolInfo').STUDIES, sStudy.Channel.FileName);
        export_channel(ChannelFile, GardelElectrodeFile, 'GARDEL-TXT', 0); 
    end
end

% Get Brainstorm window
jBstFrame = bst_get('BstFrame');

% Save reference MRI in .nii format in 'TmpGardelDir' folder
MriFileRef = sSubject.Anatomy(sSubject.iAnatomy).FileName;
sMriRef = bst_memory('LoadMri', MriFileRef);
NiiRefMriFile = bst_fullfile(TmpGardelDir, [sMriRef.Comment '.nii']);
% NiiRefMriFile is the MRI file of the subject
out_mri_nii(sMriRef, NiiRefMriFile);

% Save the unprocessed raw CT in .nii format in 'TmpGardelDir' folder 
iRawCt = find(cellfun(@(x) ~isempty(regexp(x, '_volct_raw', 'match')), {sSubject.Anatomy.FileName}));
if ~isempty(iRawCt)
    RawCtFileRef = sSubject.Anatomy(iRawCt(1)).FileName;
    sMriRawCt = bst_memory('LoadMri', RawCtFileRef);
    NiiRawCtFile = bst_fullfile(TmpGardelDir, [sMriRawCt.Comment '.nii']);
    % NiiRawCtFile is the unprocessed raw CT file of the subject
    out_mri_nii(sMriRawCt, NiiRawCtFile);
else
    errMsg = bst_error('No unprocessed raw CT found.', 'GARDEL', 0);
    % Delete temporary files
    file_delete(TmpGardelDir, 1, 1);
    return;
end

% Check if SPM12 tissue segmentation data is available
iVolAtlas = find(cellfun(@(x) ~isempty(regexp(x, '_gardel_volatlas', 'match')), {sSubject.Anatomy.FileName})); 
if ~isempty(iVolAtlas)
    % Extract the available tissue segmentation and export as MRI for GARDEL 
    TissueMris = extract_tissuemasks(sSubject.Anatomy(iVolAtlas(1)).FileName);
    mkdir(IntermediateFilesDir); 
    for i=1:length(TissueMris)
        switch (TissueMris{i}.Comment)
            case {'grey','gray','brain'}, newLabel = 'c1';
            case 'white',                 newLabel = 'c2';
            case 'csf',                   newLabel = 'c3';
            case 'skull',                 newLabel = 'c4';
            case 'scalp',                 newLabel = 'c5';            
        end
        export_mri(TissueMris{i}, bst_fullfile(IntermediateFilesDir, [newLabel 'coreg_' sMriRef.Comment '.nii']));
    end
end

% Hide Brainstorm GUI and set process logo
jBstFrame.setVisible(0);
bst_progress('start', 'GARDEL', 'Starting GARDEL external tool...');
bst_plugin('SetProgressLogo', 'gardel');

% Start GARDEL external tool 
if ~isEdit
    % Call the external GARDEL tool
    bst_call(@GARDEL, 'output_dir', TmpGardelDir, ...
        'postimp', NiiRawCtFile, 'preimp', NiiRefMriFile, 'bs_flag', '1');
else
    % Call the external GARDEL tool with the exported electrode coordinates 
    bst_call(@GARDEL, 'output_dir', TmpGardelDir, ...
        'postimp', NiiRawCtFile, 'preimp', NiiRefMriFile, 'bs_flag', '1', 'electrodes', GardelElectrodeFile);
end

% Stop process logo
bst_progress('stop');

% Find the MATLAB app 'GARDEL' and wait till user exits it
hFig = findall(bst_get('groot'), 'Type', 'figure');
iGardel = find(cellfun(@(x) ~isempty(regexp(x, 'GARDEL', 'match')), {hFig.Name}));
if ~isempty(iGardel)
    disp('GARDEL tool opened.');
    waitfor(hFig(iGardel(1)));
    disp('GARDEL tool closed.');
else
    errMsg = bst_error('GARDEL tool not found.', 'GARDEL', 0);
    % Delete temporary files
    file_delete(TmpGardelDir, 1, 1);
    return;
end

% Show Brainstorm GUI
jBstFrame.setVisible(1);

%% ===== PARSE AND LOAD GARDEL COMPUTED DATA TO BRAINSTORM =====
bst_progress('start', 'GARDEL', 'Loading GARDEL data to Brainstorm...');
% If no tissue data available, import SPM12 tissue masks in its raw form as computed by GARDEL
if isempty(iVolAtlas)
    % c2=WM, c1=GM, c3=CSF, c4=Skull, c5=Scalp
    labels = {'c2', 'c1', 'c3', 'c4', 'c5'};
    TpmFiles = cellfun(@(label) bst_fullfile(IntermediateFilesDir, [label 'coreg_' sMriRef.Comment '.nii']), labels, 'UniformOutput', false);
    bst_progress('text',  'Loading SPM12 tissue segmentations...');
    % No autoadjusting required as it is in the unprocessed raw CT space
    import_mri(iSubject, TpmFiles, 'SPM-TPM', 0, 0, 'tissues_segment_gardel');
end

% Check if electrode coordinates txt file was exported 
if ~exist(GardelElectrodeFile, 'file')
    errMsg = bst_error('Electrode coordinates file not found. Make sure you export before quitting GARDEL.', 'GARDEL', 0);
    % Delete temporary files
    file_delete(TmpGardelDir, 1, 1);
    return;
end

% Create new channel file for the data from GARDEL 
% Get GARDEL folder
conditionName = 'Implantation_Gardel';
[~, iStudy] = bst_get('StudyWithCondition', bst_fullfile(sSubject.Name, conditionName));
if isEdit
    % Delete existing 'Gardel' study
    db_delete_studies(iStudy);
end
% Create new folder if needed
iStudy = db_add_condition(sSubject.Name, conditionName, 1);
% Get 'Gardel' study
sStudy = bst_get('Study', iStudy);
% Load GARDEL exported electrode coordinates file
ChannelMat = in_channel_gardel(GardelElectrodeFile);
% Convert coordinates: VOXEL => SCS 
sMri = bst_memory('LoadMri', sSubject.Anatomy(1).FileName);
fcnTransf = @(Loc)cs_convert(sMri, 'voxel', 'scs', Loc')';
AllChannelMats = channel_apply_transf(ChannelMat, fcnTransf, [], 0);
ChannelMat = AllChannelMats{1};
% Save the new channel file
ChannelFile = bst_fullfile(bst_fileparts(file_fullpath(sStudy.FileName)), 'channel.mat');
save(ChannelFile, '-struct', 'ChannelMat');
% Reload condition
db_reload_studies(iStudy);

% Stop process logo
bst_progress('stop');

% Delete temporary folder
file_delete(TmpGardelDir, 1, 1);