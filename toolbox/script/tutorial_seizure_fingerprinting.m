function tutorial_seizure_fingerprinting(tutorial_dir, reports_dir)
% TUTORIAL_SEIZURE_FINGERPRINTING: Script that reproduces the results of the online tutorial "Seizure Fingerprinting".
%
% CORRESPONDING ONLINE TUTORIALS:
%     https://neuroimage.usc.edu/brainstorm/Tutorials/SeizureFingerprinting
%
% INPUTS: 
%    - tutorial_dir : Directory where the tutorial_seizure_fingerprinting.zip file has been unzipped
%    - reports_dir  : Directory where to save the execution report (instead of displaying it)

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
% Authors: Chinmay Chinara, 2025
%          Yash Shashank Vakilna, 2025
%          Raymundo Cassani, 2025

%% ===== PARSE INPUTS =====
% Output folder for reports
if (nargin < 2) || isempty(reports_dir) || ~isfolder(reports_dir)
    reports_dir = [];
end
% You have to specify the folder in which the tutorial dataset is unzipped
if (nargin == 0) || isempty(tutorial_dir) || ~file_exist(tutorial_dir)
    error('The first argument must be the full path to the tutorial dataset folder.');
end

%% ===== FILES TO IMPORT =====
% Build the path of the files to import
tutorial_dir   = bst_fullfile(tutorial_dir, 'tutorial_seizure_fingerprinting');
MriFilePre     = bst_fullfile(tutorial_dir, 'anatomy',    'pre_T1.nii.gz');
CtFilePost     = bst_fullfile(tutorial_dir, 'anatomy',    'post_CT.nii.gz');
BaselineFile   = bst_fullfile(tutorial_dir, 'recordings', 'Baseline.edf');
IctalFile      = bst_fullfile(tutorial_dir, 'recordings', 'ictal_repetitive_spike.edf');
InterictalFile = bst_fullfile(tutorial_dir, 'recordings', 'interictal_spike.edf');
LvfaFile       = bst_fullfile(tutorial_dir, 'recordings', 'LVFA_and_wave.edf');
ElecPosFile    = bst_fullfile(tutorial_dir, 'recordings', 'Subject01_electrodes_mm.tsv');
% Check if the folder contains the required files
if ~file_exist(BaselineFile)
    error(['The folder ' tutorial_dir ' does not contain the folder from the file tutorial_seizure_fingerprinting.zip.']);
end
% Subject name
SubjectName = 'Subject01';

%% ===== CREATE PROTOCOL =====
% The protocol name has to be a valid folder name (no spaces, no weird characters...)
ProtocolName = 'TutorialSeizureFingerprinting';
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
% Reset visualization filters
panel_filter('SetFilters', 0, [], 0, [], 0, [], 0, 0);
% Reset colormaps
bst_colormaps('RestoreDefaults', 'timefreq');
bst_colormaps('RestoreDefaults', 'source');
% Set the current time series display mode to 'column'
bst_set('TSDisplayMode', 'column');
% Hide scouts
panel_scout('SetScoutShowSelection', 'none');

%% ===== IMPORT MRI AND CT VOLUMES =====
% Process: Import MRI
bst_process('CallProcess', 'process_import_mri', [], [], ...
    'subjectname', SubjectName, ...
    'voltype',     'mri', ...  % MRI
    'comment',     'pre_T1', ...
    'mrifile',     {MriFilePre, 'ALL'}, ...
    'nas',         [104, 207, 85], ...
    'lpa',         [ 26, 113, 78], ...
    'rpa',         [176, 113, 78]);
% Process: Segment MRI with CAT12
bst_process('CallProcess', 'process_segment_cat12', [], [], ...
    'subjectname', SubjectName, ...
    'nvertices',   15000, ...
    'tpmnii',      {'', 'Nifti1'}, ...
    'sphreg',      1, ... % Use spherical registration
    'vol',         0, ... % No volume parcellations
    'extramaps',   0, ... % No additional cortical maps
    'cerebellum',  0);
% Process: Import CT
bst_process('CallProcess', 'process_import_mri', [], [], ...
    'subjectname', SubjectName, ...
    'voltype',     'ct', ...  % CT
    'comment',     'post_CT', ...
    'mrifile',     {CtFilePost, 'ALL'});
% Get filename for imported volumes
sSubject = bst_get('Subject', SubjectName);
% Reference MRI
DbMriFilePre = sSubject.Anatomy(sSubject.iAnatomy).FileName;
% Imported CT (last volume)
DbCtFilePost = sSubject.Anatomy(end).FileName;
% Register and reslice CT to reference MRI using 'SPM'
DbCtFilePostRegReslice = mri_coregister(DbCtFilePost, DbMriFilePre, 'spm', 1);
% Skull strip the CT volume using 'SPM'
DbCtFilePostSkullStrip = mri_skullstrip(DbCtFilePostRegReslice, DbMriFilePre, 'spm');

%% ===== CREATE SEEG CONTACT IMPLANTATION =====
iStudyImplantation = db_add_condition(SubjectName, 'Implantation');
% Import locations and convert to subject coordinate system (SCS)
ImplantationChannelFile = import_channel(iStudyImplantation, ElecPosFile, 'BIDS-SCANRAS-MM', 1, 0, 1, 0, 2, DbCtFilePostSkullStrip);
% Snapshot: SEEG electrodes in MRI slices
hFigMri3d = view_channels_3d(ImplantationChannelFile, 'SEEG', 'anatomy', 1, 0);
bst_report('Snapshot', hFigMri3d, ImplantationChannelFile, 'SEEG electrodes in 3D MRI slices');
close(hFigMri3d);

%% ===== ACCESS THE RECORDINGS =====
% Process: Create link to raw file
sFilesRaw = bst_process('CallProcess', 'process_import_data_raw', [], [], ...
    'subjectname',    SubjectName, ...
    'datafile',       {{BaselineFile, LvfaFile, IctalFile, InterictalFile}, 'EEG-EDF'}, ...
    'channelreplace', 0, ...
    'channelalign',   0);
% Process: Add EEG positions
bst_process('CallProcess', 'process_channel_addloc', sFilesRaw, [], ...
    'channelfile', {ImplantationChannelFile, 'BST'}, ...
    'fixunits',    0, ... % No automatic fixing of distance units required
    'vox2ras',     0);    % Do not use the voxel=>subject transformation, already in SCS

%% ===== REVIEW RECORDINGS =====
% Process: Power spectrum density (Welch)
sFilesPsd = bst_process('CallProcess', 'process_psd', sFilesRaw, [], ...
    'timewindow',  [], ...
    'win_length',  5, ...
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

% Process: Snapshot: PSD with power line noise
panel_display('SetDisplayFunction', 'log');
bst_process('CallProcess', 'process_snapshot', sFilesPsd, [], ...
    'target',   10, ...  % Frequency spectrum
    'modality', 6, ...   % SEEG
    'Comment',  'Power spectrum density');

% Process: Set channels type
% 'MPS16' channel needs to be excluded because for BEM head modeling it lies outside the inner skull
bst_process('CallProcess', 'process_channel_settype', sFilesRaw, [], ...
    'sensortypes', 'MPS16', ...
    'newtype',     'SEEG_NO_LOC');
% Define event: LVFA & wave and ictal repetitive spike
sEvt1 = db_template('event');
sEvt1.label  = 'sEEG onset';
sEvt1.epochs = 1;
sEvt1.times  = 15;
% Define event: Interictal spike
sEvt2 = db_template('event');
sEvt2.label  = 'Interictal spike';
sEvt2.epochs = 1; 
sEvt2.times  = 5;
% Process: Events: Import from file
bst_process('CallProcess', 'process_evt_import', sFilesRaw(2:3), [], ...
    'evtfile', {sEvt1, 'struct'}, ...
    'evtname', '');
bst_process('CallProcess', 'process_evt_import', sFilesRaw(4), [], ...
    'evtfile', {sEvt2, 'struct'}, ...
    'evtname', '');

%% ===== IMPORT RECORDINGS =====
% Process: Import SEEG event for LVFA & wave and ictal repetitive spike to database
sFilesOnset = bst_process('CallProcess', 'process_import_data_event', sFilesRaw(2:3), [], ...
    'subjectname',   SubjectName, ...
    'eventname',     'sEEG onset', ...
    'epochtime',     [-15, 15], ...
    'createcond',    0, ...
    'ignoreshort',   0, ...
    'usessp',        0, ...
    'baseline',      'all', ... % Remove DC offset: All recordings
    'blsensortypes', 'SEEG');   % Sensor types to remove DC offset
% Process: Import SEEG event for interictal spike to database
sFileInterictalSpike = bst_process('CallProcess', 'process_import_data_event', sFilesRaw(4), [], ...
    'subjectname',   SubjectName, ...
    'eventname',     'Interictal spike', ...
    'epochtime',     [-5, 5], ...
    'createcond',    0, ...
    'ignoreshort',   0, ...
    'usessp',        0, ...
    'baseline',      'all', ... % Remove DC offset: All recordings
    'blsensortypes', 'SEEG');   % Sensor types to remove DC offset
% ===== Bipolar Montage =====
MontageSeegBipName = [SubjectName, ': SEEG (bipolar 2)[tmp]'];
% Apply montage (create new folders)
sFilesOnsetBip = bst_process('CallProcess', 'process_montage_apply', sFilesOnset, [], ...
    'montage',    MontageSeegBipName, ...
    'createchan', 1);

%% ===== HEAD MODELING =====
% Process: Generate BEM surfaces
bst_process('CallProcess', 'process_generate_bem', [], [], ...
    'subjectname', SubjectName, ...
    'nscalp',      1922, ...
    'nouter',      1922, ...
    'ninner',      1922, ...
    'thickness',   4, ...
    'method',      'brainstorm');

% Snapshot: BEM surfaces
sSubject = bst_get('Subject', SubjectName);
BemInnerSkullFile = sSubject.Surface(sSubject.iInnerSkull).FileName;
BemOuterSkullFile = sSubject.Surface(sSubject.iOuterSkull).FileName;
BemScalpFile      = sSubject.Surface(sSubject.iScalp).FileName;
hFigSurf = view_surface(BemInnerSkullFile);
hFigSurf = view_surface(BemOuterSkullFile, [], [], hFigSurf);
hFigSurf = view_surface(BemScalpFile, [], [], hFigSurf);
figure_3d('SetStandardView', hFigSurf, 'left'); % Set orientation (left)
bst_report('Snapshot', hFigSurf, BemInnerSkullFile, 'BEM surfaces');
close(hFigSurf);

% Process: Compute head model
bst_process('CallProcess', 'process_headmodel', sFileInterictalSpike, [], ...
    'comment',     '', ...
    'sourcespace', 1, ... % Cortex surface
    'meg',         1, ... % None
    'eeg',         1, ... % None
    'ecog',        1, ... % None
    'seeg',        2, ... % OpenMEEG BEM
    'openmeeg',    struct(...
         'BemSelect',    [0, 0, 1], ... % Only compute on BEM inner skull
         'BemCond',      [1, 0.0125, 1], ...
         'BemNames',     {{'Scalp', 'Skull', 'Brain'}}, ...
         'BemFiles',     {{}}, ...
         'isAdjoint',    0, ...
         'isAdaptative', 1, ...
         'isSplit',      0, ...
         'SplitLength',  4000));
% Copy head model to other folders
sHeadModel = bst_get('HeadModelForStudy', sFileInterictalSpike.iStudy);
db_set_headmodel(sHeadModel.FileName, 'AllConditions');
% Process: Compute noise covariance in Baseline
bst_process('CallProcess', 'process_noisecov', sFilesRaw(1), [], ...
    'baseline', [0, 300.9995], ...
    'dcoffset', 1, ... % Block by block, to avoid effects of slow shifts in data
    'identity', 0, ...
    'copycond', 1, ... % Copy to other folders
    'copysubj', 0);

% Process: Snapshot: Noise covariance
bst_process('CallProcess', 'process_snapshot', sFilesRaw(1), [], ...
    'target',  3, ...  % Noise covariance
    'Comment', 'Noise covariance');

%% ===== MODELING INTERICTAL SPIKES =====
% Process: Compute sources [2018] (SEEG)
sFileInterictalSpikeSrc = bst_process('CallProcess', 'process_inverse_2018', sFileInterictalSpike, [], ...
    'output',  1, ...  % Kernel only: shared
    'inverse', struct(...
         'Comment',        '', ...
         'InverseMethod',  'minnorm', ...
         'InverseMeasure', 'sloreta', ...
         'SourceOrient',   {{'fixed'}}, ...
         'UseDepth',       0, ...
         'NoiseMethod',    'diag', ...
         'SnrMethod',      'fixed', ...
         'SnrRms',         1e-06, ...
         'SnrFixed',       3, ...
         'ComputeKernel',  1, ...
         'DataTypes',      {{'SEEG'}}));

% Interictal: Snapshots
Time       = 0.041;        % First peak of SPS10-SPS11 at 41ms
TimeWindow = [-0.5 0.5];   % Time window: -500ms to 500ms
DataThresh = 0.26;         % Source threshold (percentage)
GetSnapshotSensorTimeSeries(sFileInterictalSpike.FileName, [SubjectName, ': SPS (bipolar 2)[tmp]'], Time, TimeWindow);
GetSnapshotSensor2DLayout(sFileInterictalSpike.FileName, Time, TimeWindow);
GetSnapshotsSources(sFileInterictalSpikeSrc.FileName, 'srf3d', Time, DataThresh);
GetSnapshotsSources(sFileInterictalSpikeSrc.FileName, 'mri3d', Time, DataThresh);
GetSnapshotsSources(sFileInterictalSpikeSrc.FileName, 'mri2d', Time, DataThresh);

% ===== Create a Desikan-Killiany atlas with scouts only in the right hemisphere ====
% Load the surface
[hFigSurf, iDS, iFig] = view_surface_data([], sFileInterictalSpikeSrc.FileName);
% Show the SEEG electrodes
figure_3d('PlotSensors3D', iDS, iFig);
% Set Desikan-Killiany as the current atlas
[~, ~, sSurf] = panel_scout('GetAtlas');
iAtlas = find(strcmpi('Desikan-Killiany', {sSurf.Atlas.Name}));
panel_scout('SetCurrentAtlas', iAtlas);
% Set scout options to display all the scouts
panel_scout('SetScoutsOptions', 0, 0, 1, 'all', 0.7, 1, 0, 0);
% Select the scouts in the right hemisphere
iScoutsR = find(cellfun(@(s) ~isempty(regexp(s, 'R$', 'once')), {sSurf.Atlas(iAtlas).Scouts.Label}));
panel_scout('SetSelectedScouts', iScoutsR);
% Create a new atlas from selected scouts
panel_scout('CreateAtlasSelected', 0, 0);
% Rename the atlas
[sAtlas, iAtlas] = panel_scout('GetAtlas');
sAtlas.Name = 'Desikan-Killiany_RH';
panel_scout('SetAtlas', [], iAtlas, sAtlas);
% Subdivide the new atlas to get scouts with 5 cm sq. area each
panel_scout('SubdivideScouts', 1, 'area', 5);
% Get the scouts
sScouts = panel_scout('GetScouts');
% Close the figure
close(hFigSurf);

%% ===== MODELING ICTAL WAVE =====
% Process: Compute sources [2018] (SEEG)
sFileLvfaOnsetSrc = bst_process('CallProcess', 'process_inverse_2018', sFilesOnset(1), [], ...
    'output',  1, ...  % Kernel only: shared
    'inverse', struct(...
         'Comment',        '', ...
         'InverseMethod',  'minnorm', ...
         'InverseMeasure', 'sloreta', ...
         'SourceOrient',   {{'fixed'}}, ...
         'UseDepth',       0, ...
         'NoiseMethod',    'diag', ...
         'SnrMethod',      'fixed', ...
         'SnrRms',         1e-06, ...
         'SnrFixed',       3, ...
         'ComputeKernel',  1, ...
         'DataTypes',      {{'SEEG'}}));

% Snapshots: Sensor and source time series
Time       = 0.270;        % % Wave activity at 270ms
TimeWindow = [-0.5 0.5];   % Time window: -500ms to 500ms
DataThresh = 0.45;         % Source threshold (percentage)
GetSnapshotSensorTimeSeries(sFilesOnset(1).FileName, [SubjectName, ': SPS (bipolar 2)[tmp]'], Time, TimeWindow);
GetSnapshotSensor2DLayout(sFilesOnset(1).FileName, Time, TimeWindow);
GetSnapshotsSources(sFileLvfaOnsetSrc.FileName, 'srf3d', Time, DataThresh);
GetSnapshotsSources(sFileLvfaOnsetSrc.FileName, 'mri3d', Time, DataThresh);
GetSnapshotsSources(sFileLvfaOnsetSrc.FileName, 'mri2d', Time, DataThresh);


%% ===== MODELING ICTAL ONSET WITH LVFA (SENSOR SPACE) =====
% Process: Time-frequency (Morlet wavelets)
sFilesOnsetBipTf = bst_process('CallProcess', 'process_timefreq', sFilesOnsetBip(1), [], ...
    'sensortypes', 'SEEG', ...
    'edit',        struct(...
         'Comment',         'Power,1-100Hz', ...
         'TimeBands',       [], ...
         'Freqs',           [1, 2.1, 3.3, 4.7, 6.1, 7.8, 9.6, 11.5, 13.7, 16.1, 18.7, 21.6, 24.8, ...
                             28.3, 32.1, 36.4, 41.1, 46.2, 51.9, 58.1, 64.9, 72.5, 80.8, 89.9, 100], ...
         'MorletFc',        1, ...
         'MorletFwhmTc',    6, ...
         'ClusterFuncTime', 'none', ...
         'Measure',         'power', ...
         'Output',          'all', ...
         'SaveKernel',      0, ...
         'Method',          'morlet'), ...
    'normalize2020', 'multiply2020');  % Spectral flattening: Multiply output power values by frequency


% Snapshots: timefrequency map for sensor
Brightness = 0.65;      % Brightness -65%
Contrast   = 0.49;      % Contrast    49%
TFpoint    = [0.6, 65]; % TimeFreq point [s, Hz]
GetSnapshotTimeFreq(sFilesOnsetBipTf.FileName, 'AllSensors', TFpoint, 0, Brightness, Contrast);
GetSnapshotTimeFreq(sFilesOnsetBipTf.FileName,  'SPS8-SPS9', TFpoint, 1, Brightness, Contrast);

%% ===== MODELING ICTAL ONSET WITH LVFA (SOURCE SPACE) =====
% Process: Extract scout time series
sFileLvfaOnsetScoutTs = bst_process('CallProcess', 'process_extract_scout', sFileLvfaOnsetSrc, [], ...
    'timewindow',     [-15, 15], ...
    'scouts',         {'Desikan-Killiany_RH', {sScouts.Label}}, ...
    'flatten',        0, ...
    'scoutfunc',      'pca', ...  % PCA
    'pcaedit',        struct(...
         'Method',         'pcai', ...
         'Baseline',       [NaN, NaN], ...
         'DataTimeWindow', [-15, 15], ...
         'RemoveDcOffset', 'none'), ...
    'isflip',         1, ...
    'isnorm',         0, ...
    'concatenate',    1, ...
    'save',           1, ...
    'addrowcomment',  1, ...
    'addfilecomment', []);

% Snapshot: Scout time series
bst_process('CallProcess', 'process_snapshot', sFileLvfaOnsetScoutTs, [], ...
    'target',   5, ...  % Data
    'modality', 6, ...  % SEEG
    'Comment',  'Scout time series (matrix)');

%% Process: Time-frequency (Morlet wavelets)
sFileLvfaOnsetTf = bst_process('CallProcess', 'process_timefreq', sFileLvfaOnsetScoutTs, [], ...
    'sensortypes', 'SEEG', ...
    'edit',        struct(...
         'Comment',         'Power,1-100Hz', ...
         'TimeBands',       [], ...
         'Freqs',           [1, 2.1, 3.3, 4.7, 6.1, 7.8, 9.6, 11.5, 13.7, 16.1, 18.7, 21.6, 24.8, ...
                             28.3, 32.1, 36.4, 41.1, 46.2, 51.9, 58.1, 64.9, 72.5, 80.8, 89.9, 100], ...
         'MorletFc',        1, ...
         'MorletFwhmTc',    6, ...
         'ClusterFuncTime', 'none', ...
         'Measure',         'power', ...
         'Output',          'all', ...
         'SaveKernel',      0, ...
         'Method',          'morlet'), ...
    'normalize2020', 'multiply2020');  % Spectral flattening: Multiply output power values by frequency

% Snapshots: Time-frequency map for scouts
Brightness = 0.65;      % Brightness -65%
Contrast   = 0.49;      % Contrast    49%
TFpoint    = [0.6, 65]; % TimeFreq point [s, Hz]
GetSnapshotTimeFreq(sFileLvfaOnsetTf.FileName, 'AllSensors',      TFpoint, 0, Brightness, Contrast);
GetSnapshotTimeFreq(sFileLvfaOnsetTf.FileName, 'postcentral R.3', TFpoint, 1, Brightness, Contrast);

%% ===== MODELING ICTAL ONSET WITH REPETITIVE SPIKING (SENSOR SPACE) =====
% Process: Time-frequency (Morlet wavelets)
sFilesOnsetTf = bst_process('CallProcess', 'process_timefreq', sFilesOnsetBip(2), [], ...
    'sensortypes', 'PIN5-PIN6', ...
    'edit',        struct(...
         'Comment',         'Power,1-100Hz', ...
         'TimeBands',       [], ...
         'Freqs',           [1, 2.1, 3.3, 4.7, 6.1, 7.8, 9.6, 11.5, 13.7, 16.1, 18.7, 21.6, 24.8, ...
                             28.3, 32.1, 36.4, 41.1, 46.2, 51.9, 58.1, 64.9, 72.5, 80.8, 89.9, 100], ...
         'MorletFc',        1, ...
         'MorletFwhmTc',    6, ...
         'ClusterFuncTime', 'none', ...
         'Measure',         'power', ...
         'Output',          'all', ...
         'SaveKernel',      0, ...
         'Method',          'morlet'), ...
    'normalize2020', 'multiply2020');  % Spectral flattening: Multiply output power values by frequency

% Snapshot: Sensor time series (PIN bipolar montage)
Time = 7.7325;
GetSnapshotSensorTimeSeries(sFilesOnsetBip(2).FileName, [SubjectName ': PIN (orig)[tmp]'], Time);

% Snapshot: Time-frequency maps (one sensor)
Brightness = 0.60; % Brightness  -60%
Contrast   = 0.23; % Contrast     23%
TFpoint    = [Time, 25]; % TimeFreq point [s, Hz]
GetSnapshotTimeFreq(sFilesOnsetTf.FileName, 'PIN5-PIN6', TFpoint, 1, Brightness, Contrast);

%% ===== MODELING ICTAL ONSET WITH REPETITIVE SPIKING (SOURCE SPACE) =====
% Process: Compute sources [2018] (SEEG)
sFilesOnsetSrc = bst_process('CallProcess', 'process_inverse_2018', sFilesOnset(2), [], ...
    'output',  1, ...  % Kernel only: shared
    'inverse', struct(...
         'Comment',        '', ...
         'InverseMethod',  'minnorm', ...
         'InverseMeasure', 'sloreta', ...
         'SourceOrient',   {{'fixed'}}, ...
         'UseDepth',       0, ...
         'NoiseMethod',    'diag', ...
         'SnrMethod',      'fixed', ...
         'SnrRms',         1e-06, ...
         'SnrFixed',       3, ...
         'ComputeKernel',  1, ...
         'DataTypes',      {{'SEEG'}}));

% Set freq filters
panel_filter('SetFilters', 1, 55, 1, 5, 0, [], 0, 0);
% Set colormap for sources
sColormapSrc = bst_colormaps('GetColormap', 'source');
sColormapSrc.MaxMode  = 'custom';
sColormapSrc.MinValue = 0;
sColormapSrc.MaxValue = 2e-8;
bst_colormaps('SetColormap', 'source', sColormapSrc); % Save the changes in colormap
% Snapshot: Sensor time series (PIN)
Time       = 9.719;
TimeWindow = [-0.5, 0.5] + Time;
DataThresh = 0.33;
GetSnapshotSensorTimeSeries(sFilesOnset(2).FileName, [SubjectName ': PIN (orig)[tmp]'], Time, TimeWindow);
% Snapshot: Sources (display on MRI Viewer)
GetSnapshotsSources(sFilesOnsetSrc.FileName, 'mri2d', Time, DataThresh);
% Reset freq filters and colormap for sources
panel_filter('SetFilters', 0, [], 0, [], 0, [], 0, 0);
bst_colormaps('RestoreDefaults', 'source');

%% ===== SAVE AND DISPLAY REPORT =====
ReportFile = bst_report('Save', []);
if ~isempty(reports_dir) && ~isempty(ReportFile)
    bst_report('Export', ReportFile, reports_dir);
else
    bst_report('Open', ReportFile);
end

disp([10 'DEMO> Seizure Fingerpriting tutorial completed' 10]);

% =================================================================%
% ===================== SNAPSHOTS FUNCTIONS =======================%
% =================================================================%
%% ===== SNAPSHOTS: SENSOR TIME SERIES =====
function GetSnapshotSensorTimeSeries(SensorFile, MontageName, Time, TimeWindow)
    if nargin < 4
        TimeWindow = [];
    end
    % Figure: Sensor time series (set montage)
    hFig = view_timeseries(SensorFile, 'SEEG');
    panel_montage('SetCurrentMontage', hFig, MontageName);
    if ~isempty(TimeWindow)
        h1 = findobj(hFig, 'Tag','AxesGraph','-or','Tag','AxesEventsBar');
        xlim(h1, TimeWindow);
    end
    panel_time('SetCurrentTime', Time);
    bst_report('Snapshot', hFig, SensorFile, 'Sensor time series (SPS bipolar)', [200, 200, 400, 400]);
    close(hFig);
end

%% ===== SNAPSHOTS: SENSOR 2D LAYOUT TIME SERIES =====
function GetSnapshotSensor2DLayout(SensorFile, Time, TimeWindow)
    % Snapshot: 2D layout sensor time series
    hFig = view_topography(SensorFile, 'SEEG', '2DLayout');
    figure_topo('SetTopoLayoutOptions', 'TimeWindow', TimeWindow);
    panel_time('SetCurrentTime', Time);
    bst_report('Snapshot', hFig, SensorFile, '2D layout sensor time series', [200, 200, 400, 400]);
    close(hFig);
end

%% ===== SNAPSHOTS: SOURCES TIME SLICE =====
function GetSnapshotsSources(SourceFile, FigType, Time, DataThreshold)
    [sStudy, iStudy] = bst_get('AnyFile', SourceFile);
    % Get MRI reference
    if ~isempty(regexp(FigType, '^mri', 'once'))
        sSubjectFig = bst_get('Subject', sStudy.BrainStormSubject);
        MriFile = sSubjectFig.Anatomy(sSubjectFig.iAnatomy).FileName;
    end
    % Get ChannelFile
    if ~isempty(regexp(FigType, '3d$', 'once'))
        ChanFile = bst_get('ChannelForStudy', iStudy);
    end

    switch FigType
        % Display sources on its default surface (cortex)
        case 'srf3d'
            hFig = view_surface_data([], SourceFile);
            panel_time('SetCurrentTime', Time);
            hFig = view_channels(ChanFile.FileName, 'SEEG', 0, 0, hFig, 1);
            panel_surface('SetDataThreshold', hFig, 1, DataThreshold);
            displayStr = 'cortex';

        % Display sources on display on 3D MRI
        case 'mri3d'
            hFig = view_surface_data(MriFile, SourceFile);
            panel_time('SetCurrentTime', Time);
            hFig = view_channels(ChanFile.FileName, 'SEEG', 0, 0, hFig, 1);
            figure_3d('JumpMaximum', hFig);
            figure_3d('SetStandardView', hFig, 'right');
            displayStr = '3D MRI';

        % Display sources on MRI Viewer
        case 'mri2d'
            hFig = view_mri(MriFile, SourceFile);
            panel_time('SetCurrentTime', Time);
            bst_figures('GetFigureHandles', hFig);
            figure_mri('JumpMaximum', hFig);
            displayStr = 'MRI viewer';
    end
    panel_surface('SetDataThreshold', hFig, 1, DataThreshold);
    bst_report('Snapshot', hFig, SourceFile, ['Sources: Display on ' displayStr], [200, 200, 400, 400]);
    close(hFig);
end

%% ===== SNAPSHOTS: TIME-FREQUENCY =====
function GetSnapshotTimeFreq(TimefreqFile, RowName, TimeFreqPoint, doSlices, Brightness, Contrast)
    WinPos = [200, 200, 600, 400];
    if nargin < 4 || isempty(doSlices)
        doSlices = 0;
    end
    % TimeFreq display mode
    DisplayMode = 'SingleSensor';
    if strcmpi(RowName, 'AllSensors')
        DisplayMode = RowName;
    end
    % Snapshot: Time frequency maps (all sensors/sources)
    hFigTF = view_timefreq(TimefreqFile, DisplayMode);
    sOptions = panel_display('GetDisplayOptions');
    sOptions.Function = 'log';   % Log power
    sOptions.HighResolution = 1; % Smooth display
    if ~strcmpi(RowName, 'AllSensors')
        sTimefreq = in_bst_timefreq(TimefreqFile, 0, 'RowNames');
        iRow = ~cellfun(@isempty, regexp(sTimefreq.RowNames, ['^' RowName]));
        sOptions.RowName = sTimefreq.RowNames{iRow};
    end
    panel_display('SetDisplayOptions', sOptions);
    bst_colormaps('SetColormapAbsolute', 'timefreq', 0); % Turn off absolute value
    sColormap = bst_colormaps('GetColormap', hFigTF);
    sColormap.Contrast = Contrast;
    sColormap.Brightness = Brightness;
    % Apply modifiers (for brightness and contrast)
    sColormap = bst_colormaps('ApplyColormapModifiers', sColormap);
    % Save the changes in colormap
    bst_colormaps('SetColormap', 'timefreq', sColormap);
    % Update the colormap in figures
    bst_colormaps('FireColormapChanged', 'timefreq');
    % Select Time-Frequency point
    if length(TimeFreqPoint) == 2
        panel_time('SetCurrentTime', TimeFreqPoint(1));
        panel_freq('SetCurrentFreq', TimeFreqPoint(2), 0);
    end
    bst_report('Snapshot', hFigTF, TimefreqFile, ['Time frequency map (' RowName ')'], WinPos);
    % Power time series and power spectrum from TF representation
    if doSlices && length(TimeFreqPoint) == 2 && ~strcmpi(RowName, 'AllSensors')
        hFigT = view_spectrum(TimefreqFile, 'TimeSeries', sOptions.RowName);
        hFigF = view_spectrum(TimefreqFile, 'Spectrum',   sOptions.RowName);
        bst_report('Snapshot', hFigF, TimefreqFile, ['Time series (' RowName ')'], WinPos);
        bst_report('Snapshot', hFigT, TimefreqFile, ['Power spectrum (' RowName ')'], WinPos);
        close([hFigT hFigF]);
    end
    close(hFigTF);
end
end