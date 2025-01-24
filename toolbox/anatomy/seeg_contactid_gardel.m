function errMsg = seeg_contactid_gardel(iSubject)
% SEEG_CONTACTID_GARDEL: Handle GARDEL tool from Brainstorm
%
% USAGE:  errMsg = seeg_contactid_gardel(iSubject)
%
% INPUT:
%    - iSubject : Indice of the subject where to import the MRI
%                      If iSubject=0 : import MRI in default subject
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
% Author: Chinmay Chinara, 2024

% Initialize returned variables
errMsg = [];

%% ===== CHECK IF GARDEL PLUGIN IS INSTALLED =====
% If GARDEL not installed install it else continue
[isInstalled, errMsg] = bst_plugin('Install', 'gardel');
if ~isInstalled
    return;
end

%% ===== START EXTERNAL GARDEL TOOL =====
% Set process logo
bst_progress('start', 'GARDEL', 'Starting GARDEL external tool');
bst_plugin('SetProgressLogo', 'gardel');

% Create temporary folder for GARDEL
TmpGardelDir = bst_get('BrainstormTmpDir', 0, 'gardel');
% TmpGardelDir = 'C:\Users\chinm\OneDrive\Desktop\study_this\gardel_241117_122450';

% Get current subject
sSubject = bst_get('Subject', iSubject);

ChannelFile = [];
ChannelMat = [];
GardelElectrodeFile = [];

% Save reference MRI in .nii format in tmp folder
MriFileRef = sSubject.Anatomy(sSubject.iAnatomy).FileName;
sMriRef = bst_memory('LoadMri', MriFileRef);
NiiRefMriFile = bst_fullfile(TmpGardelDir, [sMriRef.Comment '.nii']);
% NiiRefMriFile is the MRI file of the subject
out_mri_nii(sMriRef, NiiRefMriFile);

% Save the unprocessed CT in .nii format in tmp folder 
iRawCt = find(cellfun(@(x) ~isempty(regexp(x, '_volct_raw', 'match')), {sSubject.Anatomy.FileName}));
if ~isempty(iRawCt)
    RawCtFileRef = sSubject.Anatomy(iRawCt(1)).FileName;
    sMriRawCt = bst_memory('LoadMri', RawCtFileRef);
    NiiRawCtFile = bst_fullfile(TmpGardelDir, [sMriRawCt.Comment '.nii']);
    % NiiRawCtFile is the unprocessed CT file of the subject
    out_mri_nii(sMriRawCt, NiiRawCtFile);
else
    bst_error('No Raw unprocessed CT found', 'GARDEL', 0);
    return;
end

% GetBrainstorm window
jBstFrame = bst_get('BstFrame');

% Check if SPM12 tissue segmentation data is available
iVolAtlas = find(cellfun(@(x) ~isempty(regexp(x, '_gardel_volatlas', 'match')), {sSubject.Anatomy.FileName})); 
sStudy = bst_get('StudyWithCondition', bst_fullfile(sSubject.Name, 'Gardel'));
if isempty(iVolAtlas) || isempty(sStudy) || isempty(sStudy.Channel)
    % Hide Brainstorm GUI
    jBstFrame.setVisible(0);
    % Call the external GARDEL tool
    bst_call(@GARDEL,'output_dir',TmpGardelDir, ...
        'postimp',NiiRawCtFile, 'preimp',NiiRefMriFile);
else
    % Export the channel file to GARDEL txt format
    ProtocolInfo = bst_get('ProtocolInfo');
    ChannelFile = bst_fullfile(ProtocolInfo.STUDIES, sStudy.Channel.FileName);
    GardelElectrodeFile = bst_fullfile(TmpGardelDir, '\ElectrodesAllCoordinates.txt');
    export_channel(ChannelFile, GardelElectrodeFile, 'GARDEL-TXT', 0);
    % Load the available tissue segmentation data
    TissueMris = extract_tissuemasks(sSubject.Anatomy(iVolAtlas).FileName);
    mkdir([TmpGardelDir '\IntermediateFiles\']);
    for i=1:length(TissueMris)
        switch (TissueMris{i}.Comment)
            case 'scalp',                 newLabel = 'c5';
            case 'skull',                 newLabel = 'c4';
            case 'csf',                   newLabel = 'c3';
            case {'grey','gray','brain'}, newLabel = 'c1';
            case 'white',                 newLabel = 'c2';
        end
        export_mri(TissueMris{i}, bst_fullfile(TmpGardelDir, ['\IntermediateFiles\' newLabel 'coreg_' sMriRef.Comment '.nii']));
    end
    % Hide Brainstorm GUI
    jBstFrame.setVisible(0);
    % Call the external GARDEL tool with already available tissue segmentation data
end

% Set process logo
bst_progress('stop');

% Find the app 'GARDEL_v2.3.7'
% Save data to temporary folder from GARDEL
appName = 'GARDEL_v2.3.7';
disp([appName ' app opened !']);
f = findall(bst_get('groot'),'Type','figure','Name',appName);
waitfor(f);
disp([appName ' app closed !']);

% Show Brainstorm GUI
jBstFrame.setVisible(1);

if isempty(iVolAtlas)
    %% ===== SPM12 TISSUE CLASSIFICATION TO BRAINSTORM =====
    TpmFiles = {...
        bst_fullfile(TmpGardelDir, ['\IntermediateFiles\c2coreg_' sMriRef.Comment '.nii']), ...
        bst_fullfile(TmpGardelDir, ['\IntermediateFiles\c1coreg_' sMriRef.Comment '.nii']), ...
        bst_fullfile(TmpGardelDir, ['\IntermediateFiles\c3coreg_' sMriRef.Comment '.nii']), ...
        bst_fullfile(TmpGardelDir, ['\IntermediateFiles\c4coreg_' sMriRef.Comment '.nii']), ...
        bst_fullfile(TmpGardelDir, ['\IntermediateFiles\c5coreg_' sMriRef.Comment '.nii'])};
    % Import tissue classification in its raw form (no autoadjusting required as it is in CT space)
    bst_progress('start', 'Loading SPM12 tissue segmentations...', 'GARDEL');
    import_mri(iSubject, TpmFiles, 'SPM-TPM', 0, 0, 'tissues_segment_gardel');
end

%% ===== LOAD GARDEL CALCULATED ELECTRODE COORDINATES =====
% Check if electrode coordinates txt file was exported 
GardelElectrodeFile = bst_fullfile(TmpGardelDir, '\ElectrodesAllCoordinates.txt');
if ~exist(GardelElectrodeFile, 'file')
    bst_error('Electrode coordinates file not found. Make sure you export before quitting GARDEL !', 'GARDEL', 0);
    % Comment this line to keep the temporary folder
    file_delete(TmpGardelDir, 1, 1);
    return
end

% Create new channel file for the data from GARDEL 
% Get folder 'Gardel'
conditionName = 'Gardel';
[sStudy, iStudy] = bst_get('StudyWithCondition', bst_fullfile(sSubject.Name, conditionName));
if ~isempty(sStudy)
    % Delete existing Gardel study
    db_delete_studies(iStudy);
end
% Create new folder if needed
iStudy = db_add_condition(sSubject.Name, conditionName, 1);
% Get 'Gardel' study
sStudy = bst_get('Study', iStudy);

% Create an empty channel file for GARDEL data
ChannelMat = db_template('channelmat');
ChannelMat.Channel = db_template('channeldesc');
ChannelMat.Comment = conditionName;

% Parse the electrode coordinates txt file and load it to the channel file
fid = fopen(GardelElectrodeFile);
tline = fgets(fid);
while isempty(strfind(tline,'MRI_voxel'))
    tline = fgets(fid);
end
tline = fgets(fid);
Electrodes = [];
i = 1;
while ischar(tline) && ~contains(tline,'MRI_FS')
    if isempty(strfind(tline,'#'))
        Electrodes = [Electrodes; textscan(tline, '%s %f %f %f %f %f %s %s', 8, 'Delimiter', '\t')];
        i = i+1;
    end
    tline = fgets(fid);
end
fclose(fid);

% Parse the 'Electrodes' variable and put it in the BST format in the channel file
sMri = bst_memory('LoadMri', sSubject.Anatomy(1).FileName);
for ii=1:length(Electrodes)
    a = Electrodes(ii, 1);
    b = Electrodes(ii, 2);
    ChannelMat.Channel(ii).Name = [a{:}{:} num2str(b{:})];

    ChannelMat.Channel(ii).Group = a{:}{:};
    
    x = Electrodes(ii, 3);
    y = Electrodes(ii, 4);
    z = Electrodes(ii, 5);
    xx(1) = x{:};
    xx(2) = y{:};
    xx(3) = z{:};

    % Convert coordinates from GARDEL MRI Voxel space to Brainstorm SCS space
    xx = cs_convert(sMri, 'voxel', 'scs', xx);
    ChannelMat.Channel(ii).Loc = xx';
    ChannelMat.Channel(ii).Type = 'SEEG';
end

% Save the new channel file
ChannelFile = bst_fullfile(bst_fileparts(file_fullpath(sStudy.FileName)), ['channel_' lower(conditionName) '.mat']);
save(ChannelFile, '-struct', 'ChannelMat');

% Reload condition
db_reload_studies(iStudy);

% Delete temporary folder
% Comment this line to keep the temporary folder
file_delete(TmpGardelDir, 0, 1);