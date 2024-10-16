function errorMsg = seeg_contactid_gardel(iSubject, BsDir, nVertices, isInteractive, sFid, isVolumeAtlas, isKeepMri)
% SEEG_CONTACTID_GARDEL: Handle GARDEL data manipulation.
%
% USAGE:  errorMsg = export_import_gardel(iSubject, BsDir=[ask], nVertices=[ask], isInteractive=1, sFid=[], isVolumeAtlas=1, isKeepMri=0)
%
% INPUT:
%    - iSubject      : Indice of the subject where to import the MRI
%                      If iSubject=0 : import MRI in default subject
%    - BsDir         : Full filename of the BrainSuite folder to import
%    - nVertices     : Number of vertices in the file cortex surface
%    - isInteractive : If 0, no input or user interaction
%    - sFid          : Structure with the fiducials coordinates
%                      Or full MRI structure with fiducials defined in the SCS structure, to be registered with the FS MRI
%    - isVolumeAtlas : If 1, imports the svreg atlas as a set of surfaces
%    - isKeepMri     : 0=Delete all existing anatomy files
%                      1=Keep existing MRI volumes (when running segmentation from Brainstorm)
%                      2=Keep existing MRI and surfaces
% OUTPUT:
%    - errorMsg : String: error message if an error occurs

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

%% ===== PARSE INPUTS =====
% Keep MRI
if (nargin < 7) || isempty(isKeepMri)
    isKeepMri = 0;
end
% Import volume atlas
if (nargin < 6) || isempty(isVolumeAtlas)
    isVolumeAtlas = 1;
end
% Fiducials
if (nargin < 5) || isempty(sFid)
    sFid = [];
end
% Interactive / silent
if (nargin < 4) || isempty(isInteractive)
    isInteractive = 1;
end
% Ask number of vertices for the cortex surface
if (nargin < 3) || isempty(nVertices)
    nVertices = [];
end
% Initialize returned variables
errorMsg = [];

%% CHECK IF GARDEL PLUGIN IS INSTALLED
% If GARDEL not installed install it else continue
[isInstalled, errMsg] = bst_plugin('Install', 'gardel');
if ~isInstalled
    return;
end

%% START EXTERNAL GARDEL TOOL
% Set process logo
bst_progress('start', 'GARDEL', 'Starting GARDEL external tool');
bst_plugin('SetProgressLogo', 'gardel');

% create temporary folder for GARDEL
TmpGardelDir = bst_get('BrainstormTmpDir', 0, 'gardel');

% Get current subject
sSubject = bst_get('Subject', iSubject);

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

% Hide Brainstorm window
jBstFrame = bst_get('BstFrame');
jBstFrame.setVisible(0);

% Call the external GARDEL tool
bst_call(@GARDEL);
% bst_call(@GARDEL,'output_dir',TmpGardelDir, ...
%     'postimp',NiiRawCtFile, 'preimp',NiiRefMriFile);

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

% TODO: Load data from temp directory back to Brainstorm 
%% Check if electrode coordinates txt file was exported 
electrodes_file_path = [TmpGardelDir '\ElectrodesAllCoordinates.txt'];
if ~exist(electrodes_file_path, 'file')
    bst_error('Electrode coordinates file not found. Make sure you export before quitting GARDEL !', 'GARDEL', 0);
    % comment this line to keep the temporary folder
    file_delete(TmpGardelDir, 1, 1);
    return
end

%% Make a new empty channel file for the subject
% Get subject
sSubject = bst_get('Subject', iSubject);
SubjectName = sSubject.Name;
sMri = bst_memory('LoadMri', sSubject.Anatomy(1).FileName);

% Get current date/time
c = clock;
% Create a unique channel file each time we try running GARDEL from BST (may not be required in future) 
for i = 1:99
    % Generate new condition name
    ConditionName = sprintf('%s_%02d%02d%02d_%02d', SubjectName, c(1), c(2), c(3), i);
    % Get condition
    [sStudy, ~] = bst_get('StudyWithCondition', [SubjectName '/' ConditionName]);
    % If condition doesn't exist: ok, keep this one
    if isempty(sStudy)
        break;
    end
end
% Create condition
iStudy = db_add_condition(SubjectName, ConditionName);
sStudy = bst_get('Study', iStudy);

%% Create an empty channel file in GARDEL
ChannelMat = db_template('channelmat');
ChannelMat.Channel = db_template('channeldesc');
ChannelMat.Comment = ConditionName;

%% Parse the electrode coordinates txt file and load it to the channel file
fid = fopen(electrodes_file_path);
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

% Parse the 'Electrodes' variable and put it in the BST format in the channel file
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

    % Convert from GARDEL MRI Voxel space to BST SCS coordinates
    xx = cs_convert(sMri, 'voxel', 'scs', xx);
    ChannelMat.Channel(ii).Loc = xx';

    ChannelMat.Channel(ii).Type = 'SEEG';
end

%% Save the new channel file
ChannelFile = bst_fullfile(bst_fileparts(file_fullpath(sStudy.FileName)), ['channel_' ConditionName '.mat']);
save(ChannelFile, '-struct', 'ChannelMat');

% Reload condition
db_reload_studies(iStudy);

% delete temporary folder
% comment this line to keep the temporary folder
% file_delete(TmpGardelDir, 1, 1);