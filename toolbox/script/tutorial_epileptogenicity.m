function tutorial_epileptogenicity(tutorial_dir)
% TUTORIAL_EPILEPTOGENITICY: Script that reproduces the results of the online tutorial "SEEG Epileptogenicity maps".
%
% CORRESPONDING ONLINE TUTORIALS:
%     https://neuroimage.usc.edu/brainstorm/Tutorials/Epileptogenicity
%
% INPUTS: 
%     tutorial_dir: Directory where the tutorial_epimap_bids.zip file has been unzipped

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
% Author: Francois Tadel, 2017-2022


% ===== FILES TO IMPORT =====
% You have to specify the folder in which the tutorial dataset is unzipped
if (nargin == 0) || isempty(tutorial_dir) || ~file_exist(tutorial_dir)
    error('The first argument must be the full path to the tutorial dataset folder.');
end
% Build the path of the files to import
MriFilePre  = fullfile(tutorial_dir, 'tutorial_epimap_bids', 'sub-01', 'ses-preimp',  'anat', 'sub-01_ses-preimp_T1w.nii.gz');
MriFilePost = fullfile(tutorial_dir, 'tutorial_epimap_bids', 'sub-01', 'ses-postimp', 'anat', 'sub-01_ses-postimp_T1w.nii.gz');
Sz1File     = fullfile(tutorial_dir, 'tutorial_epimap_bids', 'sub-01', 'ses-postimp', 'ieeg', 'sub-01_ses-postimp_task-seizure_run-01_ieeg.eeg');
Sz2File     = fullfile(tutorial_dir, 'tutorial_epimap_bids', 'sub-01', 'ses-postimp', 'ieeg', 'sub-01_ses-postimp_task-seizure_run-02_ieeg.eeg');
Sz3File     = fullfile(tutorial_dir, 'tutorial_epimap_bids', 'sub-01', 'ses-postimp', 'ieeg', 'sub-01_ses-postimp_task-seizure_run-03_ieeg.eeg');
ElecPosFile = fullfile(tutorial_dir, 'tutorial_epimap_bids', 'sub-01', 'ses-postimp', 'ieeg', 'sub-01_ses-postimp_space-ScanRAS_electrodes.tsv');
% Check if the folder contains the required files
if ~file_exist(Sz1File)
    error(['The folder ' tutorial_dir ' does not contain the folder from the file tutorial_epimap_bids.zip.']);
end
% Subject name
SubjectName = 'Subject01';


% ===== CREATE PROTOCOL =====
% The protocol name has to be a valid folder name (no spaces, no weird characters...)
ProtocolName = 'TutorialEpimap';
% Start brainstorm without the GUI
if ~brainstorm('status')
    brainstorm nogui
end
% Delete existing protocol
gui_brainstorm('DeleteProtocol', ProtocolName);
% Create new protocol
gui_brainstorm('CreateProtocol', ProtocolName, 0, 0);
% Start a new report
bst_report('Start');


% ===== IMPORT MRI VOLUMES =====
% Create subject
[sSubject, iSubject] = db_add_subject(SubjectName, [], 0, 0);
% Import both volumes
DbMriFilePre = import_mri(iSubject, MriFilePre, 'ALL', 0, 0, 'T1pre');
DbMriFilePost = import_mri(iSubject, MriFilePost, 'ALL', 0, 0, 'T1post');
% Compute the non-linear MNI coordinates for both volumes
[sMriPre, errMsg]  = bst_normalize_mni(DbMriFilePre, 'segment');
% Volumes are not registered: Register with SPM
isRegistered = 1;
if ~isRegistered
    [DbMriFilePostReg, errMsg, fileTag, sMriPostReg] = mri_coregister(DbMriFilePost, DbMriFilePre, 'spm', 0);
% Volumes are registered: Copy SCS and NCS fiducials to post volume
else
    [DbMriFilePostReg, errMsg, fileTag, sMriPostReg] = mri_coregister(DbMriFilePost, DbMriFilePre, 'vox2ras', 0);
end
% Reslice the "post" volume
[DbMriFilePostReslice, errMsg, fileTag, sMriPostReslice] = mri_reslice(DbMriFilePostReg, DbMriFilePre, 'vox2ras', 'vox2ras');

% Compute SPM canonical surfaces
SurfResolution = 3;   %1=5124V, 2=8196V, 3=20484V 4=7861V+hip+amyg
process_generate_canonical('Compute', iSubject, 1, SurfResolution, 0);


% ===== ACCESS THE RECORDINGS =====
% Process: Create link to raw file
sFilesRaw = bst_process('CallProcess', 'process_import_data_raw', [], [], ...
    'subjectname',    SubjectName, ...
    'datafile',       {{Sz1File, Sz2File, Sz3File}, 'SEEG-ALL'}, ...
    'channelreplace', 0, ...
    'channelalign',   0);
% Process: Add EEG positions
bst_process('CallProcess', 'process_channel_addloc', sFilesRaw, [], ...
    'channelfile', {ElecPosFile, 'BIDS-SCANRAS-MM'}, ...
    'fixunits',    0, ...
    'vox2ras',     1, ...
    'mrifile',     {file_fullpath(DbMriFilePostReslice), 'BST'});
% Process: Power spectrum density (Welch)
sFilesPsd = bst_process('CallProcess', 'process_psd', sFilesRaw, [], ...
    'timewindow',  [], ...
    'win_length',  10, ...
    'win_overlap', 50, ...
    'sensortypes', 'SEEG', ...
    'edit', struct(...
         'Comment',         'Power', ...
         'TimeBands',       [], ...
         'Freqs',           [], ...
         'ClusterFuncTime', 'none', ...
         'Measure',         'magnitude', ...
         'Output',          'all', ...
         'SaveKernel',      0));


%% ===== EVENTS AND BAD CHANNELS =====
% Process: Set bad channels
bst_process('CallProcess', 'process_channel_setbad', sFilesRaw(1), [], 'sensortypes', 'v''1, f''1');
bst_process('CallProcess', 'process_channel_setbad', sFilesRaw(2), [], 'sensortypes', 'v''1, t''8');
bst_process('CallProcess', 'process_channel_setbad', sFilesRaw(3), [], 'sensortypes', 'o''1, t''8');
% Define events
sEvt1 = db_template('event');
sEvt1(1).label   = 'Onset';
sEvt1(1).epochs  = 1;
sEvt1(1).channels= [];
sEvt1(1).notes   = [];
sEvt1(2).label   = 'Baseline';
sEvt1(2).epochs  = 1;
sEvt1(2).channels= [];
sEvt1(2).notes   = [];
% SZ1
sEvt1(1).times   = 120.800;
sEvt1(2).times   = [72.800; 77.800];
% SZ2
sEvt2 = sEvt1;
sEvt2(1).times   = 143.510;
sEvt2(2).times   = [103.510; 108.510];
% SZ3
sEvt3 = sEvt1;
sEvt3(1).times   = 120.287;
sEvt3(2).times   = [45.287; 50.287];
% Process: Events: Import from file
bst_process('CallProcess', 'process_evt_import', sFilesRaw(1), [], ...
    'evtfile', {sEvt1, 'struct'}, ...
    'evtname', '');
bst_process('CallProcess', 'process_evt_import', sFilesRaw(2), [], ...
    'evtfile', {sEvt2, 'struct'}, ...
    'evtname', '');
bst_process('CallProcess', 'process_evt_import', sFilesRaw(3), [], ...
    'evtfile', {sEvt3, 'struct'}, ...
    'evtname', '');


% ===== EPOCH RECORDINGS =====
% Import baselines
sFilesBaselines = bst_process('CallProcess', 'process_import_data_event', sFilesRaw, [], ...
    'subjectname', SubjectName, ...
    'eventname',   'Baseline', ...
    'timewindow',  [], ...
    'createcond',  0, ...
    'ignoreshort', 0, ...
    'usessp',      0);
% Import seizures
sFilesOnsets = bst_process('CallProcess', 'process_import_data_event', sFilesRaw, [], ...
    'subjectname', SubjectName, ...
    'eventname',   'Onset', ...
    'epochtime',   [-10, 40], ...
    'timewindow',  [], ...
    'createcond',  0, ...
    'ignoreshort', 0, ...
    'usessp',      0);
% Rename folders
db_rename_condition(bst_fullfile(SubjectName, 'sub-01_ses-postimp_task-seizure_run-01_ieeg'), bst_fullfile(SubjectName, 'run-01'));
db_rename_condition(bst_fullfile(SubjectName, 'sub-01_ses-postimp_task-seizure_run-02_ieeg'), bst_fullfile(SubjectName, 'run-02'));
db_rename_condition(bst_fullfile(SubjectName, 'sub-01_ses-postimp_task-seizure_run-03_ieeg'), bst_fullfile(SubjectName, 'run-03'));
% Search again for files
sFilesBaselines = bst_process('CallProcess', 'process_select_search', [], [], ...
    'search', '([name CONTAINS "Baseline"])');
sFilesOnsets = bst_process('CallProcess', 'process_select_search', [], [], ...
    'search', '([name CONTAINS "Onset"])');


% ===== BIPOLAR MONTAGE =====
MontageName = [SubjectName, ': SEEG (bipolar 2)[tmp]'];
% Apply montage (create new folders)
sFilesBaselinesBip = bst_process('CallProcess', 'process_montage_apply', sFilesBaselines, [], ...
    'montage',    MontageName, ...
    'createchan', 1);
sFilesOnsetsBip = bst_process('CallProcess', 'process_montage_apply', sFilesOnsets, [], ...
    'montage',    MontageName, ...
    'createchan', 1);
% Delete original imported folder
bst_process('CallProcess', 'process_delete', [sFilesBaselines, sFilesOnsets], [], 'target', 2);  % Delete folders
% Replace files with bipolar versions
sFilesBaselines = sFilesBaselinesBip;
sFilesOnsets = sFilesOnsetsBip;


% ===== EPILEPTOGENICITY: SEIZURE #1 =====
% Get options
FreqBand       = [120 200];
Latency        = '0';
TimeConstant   = 3;
TimeResolution = .2;
ThDelay        = 0.05;
OutputType     = 'volume';
% Process: Epileptogenicity index (A=Baseline,B=Seizure)
sFilesEpilepto1 = bst_process('CallProcess', 'process_epileptogenicity', sFilesBaselines(1), sFilesOnsets(1), ...
    'sensortypes',    'SEEG', ...
    'freqband',       FreqBand, ...
    'latency',        Latency, ...
    'timeconstant',   TimeConstant, ...
    'timeresolution', TimeResolution, ...
    'thdelay',        ThDelay, ...
    'type',           OutputType);

% ===== EPILEPTOGENICITY: SEIZURE #2-3 =====
% Get options
FreqBand       = [120 200];
Latency        = '0:2:20';
TimeConstant   = 3;
TimeResolution = .2;
ThDelay        = 0.05;
OutputType     = 'surface';
% Process: Epileptogenicity index (A=Baseline,B=Seizure)
sFilesEpilepto2 = bst_process('CallProcess', 'process_epileptogenicity', sFilesBaselines(2:3), sFilesOnsets(2:3), ...
    'sensortypes',    'SEEG', ...
    'freqband',       FreqBand, ...
    'latency',        Latency, ...
    'timeconstant',   TimeConstant, ...
    'timeresolution', TimeResolution, ...
    'thdelay',        ThDelay, ...
    'type',           OutputType);


% Save and display report
ReportFile = bst_report('Save', []);
bst_report('Open', ReportFile);



