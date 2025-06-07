function tutorial_seizure_fingerprinting(tutorial_dir, reports_dir)
    % TUTORIAL_SEIZURE_FINGERPRINTING: Script that reproduces the results of the online tutorial "Seizure Fingerprinting".
    %
    % CORRESPONDING ONLINE TUTORIALS:
    %     https://neuroimage.usc.edu/brainstorm/Tutorials/SeizureFingerprinting
    %
    % INPUTS: 
    %    - tutorial_dir : Directory where the SubjectCMC.zip file has been unzipped
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
    MriFilePre     = bst_fullfile(tutorial_dir, 'anatomy', 'pre_T1.nii.gz');
    MriFilePost    = bst_fullfile(tutorial_dir, 'anatomy', 'post_CT.nii.gz');
    BaselineFile   = bst_fullfile(tutorial_dir, 'recordings', 'Baseline.edf');
    IctalFile      = bst_fullfile(tutorial_dir, 'recordings', 'ictal_repetitive_spike.edf');
    InterictalFile = bst_fullfile(tutorial_dir, 'recordings', 'interictal_spike.edf');
    LvfaFile       = bst_fullfile(tutorial_dir, 'recordings', 'LVFA_and_wave.edf');
    ElecPosFile    = bst_fullfile(tutorial_dir, 'Subject01_electrodes_mm.tsv');
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
    % Hide scouts
    panel_scout('SetScoutShowSelection', 'none');
    
    %% ===== IMPORT MRI VOLUMES =====
    % Create subject
    [~, iSubject] = db_add_subject(SubjectName, [], 0, 0);
    % Import MRI volume
    DbMriFilePre  = import_mri(iSubject, MriFilePre, 'ALL', 0, 0, 'pre_T1');
    % Set fiducials in MRI
    NAS = [104, 207, 85];
    LPA = [ 26, 113, 78];
    RPA = [176, 113, 78];
    figure_mri('SetSubjectFiducials', iSubject, NAS, LPA, RPA, [], [], []);
    
    % Process: Segment MRI with CAT12
    bst_process('CallProcess', 'process_segment_cat12', [], [], ...
        'subjectname', SubjectName, ...
        'nvertices',   15000, ...
        'tpmnii',      {'', 'Nifti1'}, ...
        'sphreg',      1, ... % Use spherical registration
        'vol',         0, ... % No volume parcellations
        'extramaps',   0, ... % No additional cortical maps
        'cerebellum',  0);
    
    % Import CT volume
    DbCtFilePost = import_mri(iSubject, MriFilePost, 'ALL', 0, 0, 'post_CT');
    % Register CT to MRI and reslice using 'SPM'
    DbCtFilePostRegReslice = mri_coregister(DbCtFilePost, DbMriFilePre, 'spm', 1);
    % Skull strip the MRI volume and apply to the CT using 'SPM'
    DbCtFilePostSkullStrip = mri_skullstrip(DbCtFilePostRegReslice, DbMriFilePre, 'spm');
    
    %% ===== ACCESS THE RECORDINGS =====
    % Process: Create link to raw file
    sFilesRaw = bst_process('CallProcess', 'process_import_data_raw', [], [], ...
        'subjectname',    SubjectName, ...
        'datafile',       {{BaselineFile, LvfaFile, IctalFile, InterictalFile}, 'EEG-EDF'}, ...
        'channelreplace', 0, ...
        'channelalign',   0);
    % Process: Add EEG positions
    bst_process('CallProcess', 'process_channel_addloc', sFilesRaw, [], ...
        'channelfile', {ElecPosFile, 'BIDS-SCANRAS-MM'}, ...
        'fixunits',    0, ... % No automatic fixing of distance units required
        'vox2ras',     2, ... % Apply voxel=>subject transformation and the coregistration transformation
        'mrifile',     {file_fullpath(DbCtFilePostSkullStrip), 'BST'});
    
    % Snapshot: SEEG electrodes in MRI slices
    ChannelFile = bst_get('ChannelFileForStudy', sFilesRaw(1).FileName);
    hFigMri3d = view_channels_3d(ChannelFile, 'SEEG', 'anatomy', 1, 0);
    hAxes = findobj(hFigMri3d, 'Tag', 'Axes3D');
    zoom(hAxes, 1.5);
    bst_report('Snapshot', hFigMri3d, ChannelFile, 'SEEG electrodes in 3D MRI slices', [200, 200, 400, 400]);
    close(hFigMri3d);
    
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
    bst_process('CallProcess', 'process_channel_settype', sFilesRaw, [], 'sensortypes', 'MPS16', 'newtype', 'SEEG_NO_LOC');
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
    MontageName = [SubjectName, ': SEEG (bipolar 2)[tmp]'];
    % Apply montage (create new folders)
    sFilesOnsetBip = bst_process('CallProcess', 'process_montage_apply', sFilesOnset, [], ...
        'montage',    MontageName, ...
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
    bst_report('Snapshot', hFigSurf, BemInnerSkullFile, 'BEM surfaces', [200, 200, 400, 400]);
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
    
    % Snapshots: Sensor and source time series
    SnapshotsSensorSourceTimeSeries(sFileInterictalSpike.FileName, sFileInterictalSpikeSrc.FileName, ...
                              0.041, ...             % First peak of SPS10-SPS11 at 41ms
                              [-0.5 0.5], ...        % Time window: -500ms to 500ms
                              [0.26, 0.56], ...      % Data threshold for cortical activations on (Cortex, MRI Viewer)
                              [200, 200, 400, 400]);

    % ===== Create a Desikan-Killiany atlas with scouts only in the right hemisphere ====
    % Load the surface
    [hFig, iDS, iFig] = view_surface_data([], sFileInterictalSpikeSrc.FileName);
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
    close(hFig);
    
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
    SnapshotsSensorSourceTimeSeries(sFilesOnset(1).FileName, sFileLvfaOnsetSrc.FileName, ...
                              0.270, ...        % Wave activity at 270ms
                              [-0.5 0.5], ...   % Time window: -500ms to 500ms
                              [0.45, 0.45], ... % Data threshold for cortical activations on (Cortex, MRI Viewer)
                              [200, 200, 400, 400]);
    
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
    
    % Snapshots: Sensor time frequency
    SnapshotsSensorSourceTimeFreq(sFilesOnsetBipTf.FileName, ...
                                 0.49, ...        % Brightness 49%
                                 0.65, ...        % Contrast -65%
                                 0.7735, ...      % Time
                                 'SPS8-SPS9', ... % Sensor name  
                                 [200, 200, 600, 400]);
    
    %% ===== MODELING ICTAL ONSET WITH LVFA (SOURCE SPACE) =====
    % Process: Extract scout time series
    sFileLvfaOnsetScoutTs = bst_process('CallProcess', 'process_extract_scout', sFileLvfaOnsetSrc, [], ...
        'timewindow',     [-15, 15], ...
        'scouts',         {'Desikan-Killiany_RH', {sScouts.Label}}, ...
        'flatten',        1, ...
        'scoutfunc',      'pca', ...
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
    
    % Snapshots: Source time frequency
    SnapshotsSensorSourceTimeFreq(sFileLvfaOnsetTf.FileName, ...
                                 0.52, ...              % Brightness 52%
                                 0.63, ...              % Contrast -63%
                                 0.7735, ...            % Time
                                 'postcentral R.3', ... % Source name  
                                 [200, 200, 600, 400]);
    
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
    hFigTs = view_timeseries(sFilesOnsetBip(2).FileName, 'SEEG');
    panel_montage('SetCurrentMontage', hFigTs, [SubjectName ': PIN (orig)[tmp]']);
    panel_time('SetCurrentTime', 7.7325); % High frequency activity
    bst_report('Snapshot', hFigTs, sFilesOnsetBip(2).FileName, 'Sensor time series (PIN bipolar)', [200, 200, 400, 400]);
    
    % Snapshot: Time-frequency maps (one sensor)
    hFigTfMap = view_timefreq(sFilesOnsetTf.FileName, 'SingleSensor');
    sOptions = panel_display('GetDisplayOptions');
    sOptions.RowName = 'PIN5-PIN6';
    sOptions.Function = 'log';
    sOptions.HighResolution = 1; % Smooth display
    panel_display('SetDisplayOptions', sOptions);
    bst_colormaps('SetColormapAbsolute', 'timefreq', 0); % Turn off absolute value
    sColormap = bst_colormaps('GetColormap', hFigTfMap);
    sColormap.Contrast = 0.23; % Contrast = 23
    sColormap.Brightness = 0.60; % Brightness = -60
    sColormap = bst_colormaps('ApplyColormapModifiers', sColormap); % Apply modifiers (for brightness and contrast)
    bst_colormaps('SetColormap', 'timefreq', sColormap); % Save the changes in colormap
    bst_colormaps('FireColormapChanged', 'timefreq'); % Update the colormap in figures
    bst_report('Snapshot', hFigTfMap, sFilesOnsetTf.FileName, 'Time-freq map (PIN5-PIN6)', [200, 200, 600, 400]);
    close([hFigTs hFigTfMap]);
    
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
    
    % Snapshot: Sensor time series (PIN)
    hFigTs = view_timeseries(sFilesOnset(2).FileName, 'SEEG');
    panel_time('SetCurrentTime', 9.719); % Repetitive spiking from 9.719s
    bst_report('Snapshot', hFigTs, sFilesOnset(2).FileName, 'Sensor time series (PIN)', [200, 200, 400, 400]);
    
    % Snapshot: Sources (display on MRI Viewer)
    hFigSrcMri = view_mri(sSubject.Anatomy(sSubject.iAnatomy).FileName, sFilesOnsetSrc.FileName);
    Handles = bst_figures('GetFigureHandles', hFigSrcMri);
    Handles.jRadioRadiological.setSelected(1);
    Handles.jCheckMipFunctional.setSelected(1);
    panel_filter('SetFilters', 1, 55, 1, 5);
    sColormap = bst_colormaps('GetColormap', hFigSrcMri);
    sColormap.MaxMode  = 'custom';
    sColormap.MinValue = 0;
    sColormap.MaxValue = 2;
    bst_colormaps('SetColormap', 'source', sColormap); % Save the changes in colormap
    bst_colormaps('FireColormapChanged', 'source'); % Update the colormap in figures
    panel_surface('SetDataThreshold', hFigSrcMri, 1, 0.33); % Set amplitude threshold 33%
    figure_mri('JumpMaximum', hFigSrcMri);
    bst_report('Snapshot', hFigSrcMri, sFilesOnsetSrc.FileName, 'Sources: Display on MRI viewer', [200, 200, 400, 400]);
    % Close figures
    close(hFigSrcMri);
    
    %% ===== SAVE AND DISPLAY REPORT =====
    ReportFile = bst_report('Save', []);
    if ~isempty(reports_dir) && ~isempty(ReportFile)
        bst_report('Export', ReportFile, reports_dir);
    else
        bst_report('Open', ReportFile);
    end
    
    disp([10 'DEMO> Seizure Fingerpriting tutorial completed' 10]);

    % =================================================================%
    % ===================== NESTED FUNCTIONS ==========================%
    % =================================================================%
    %% ===== SNAPSHOTS: SENSOR AND SOURCE TIME SERIES =====
    function SnapshotsSensorSourceTimeSeries(SensorFile, SourceFile, Time, TimeWindow, DataThreshold, WinPos)
        % Snapshot: Sensor time series (SPS bipolar montage)
        hFigTs = view_timeseries(SensorFile, 'SEEG');
        panel_montage('SetCurrentMontage', hFigTs, [SubjectName ': SPS (bipolar 2)[tmp]']);
        panel_time('SetCurrentTime', Time);
        bst_report('Snapshot', hFigTs, SensorFile, 'Sensor time series (SPS bipolar)', WinPos);
        
        % Snapshot: 2D layout sensor time series
        hFigTopo = view_topography(SensorFile, 'SEEG', '2DLayout');
        figure_topo('SetTopoLayoutOptions', 'TimeWindow', TimeWindow);
        panel_time('SetCurrentTime', Time);
        bst_report('Snapshot', hFigTopo, SensorFile, '2D layout sensor time series', WinPos);
        
        % Snapshot: Sources (display on cortex)
        hFigSrcCortex = view_surface_data(sSubject.Surface(sSubject.iCortex).FileName, SourceFile);
        ChannelFile = bst_get('ChannelFileForStudy', SensorFile);
        hFigSrcCortex = view_channels(ChannelFile, 'SEEG', 0, 0, hFigSrcCortex, 1);
        panel_surface('SetDataThreshold', hFigSrcCortex, 1, DataThreshold(1));
        hAxes = findobj(hFigSrcCortex, 'Tag', 'Axes3D');
        zoom(hAxes, 1.3);
        bst_report('Snapshot', hFigSrcCortex, SourceFile, 'Sources: Display on cortex', WinPos);
        
        % Snapshot: Sources (display on 3D MRI)
        hFigSrcMri3d = view_surface_data(sSubject.Anatomy(sSubject.iAnatomy).FileName, SourceFile);
        hFigSrcMri3d = view_channels(ChannelFile, 'SEEG', 0, 0, hFigSrcMri3d, 1);
        figure_3d('JumpMaximum', hFigSrcMri3d);
        figure_3d('SetStandardView', hFigSrcMri3d, 'right');
        hAxes = findobj(hFigSrcMri3d, 'Tag', 'Axes3D');
        zoom(hAxes, 1.3);
        bst_report('Snapshot', hFigSrcMri3d, SourceFile, 'Sources: Display on 3D MRI', WinPos);
        
        % Snapshot: Sources (display on MRI Viewer)
        hFigSrcMri = view_mri(sSubject.Anatomy(sSubject.iAnatomy).FileName, SourceFile);
        Handles = bst_figures('GetFigureHandles', hFigSrcMri);
        Handles.jRadioRadiological.setSelected(1);
        Handles.jCheckMipFunctional.setSelected(1);
        panel_surface('SetDataThreshold', hFigSrcMri, 1, DataThreshold(2));
        figure_mri('JumpMaximum', hFigSrcMri);
        bst_report('Snapshot', hFigSrcMri, SourceFile, 'Sources: Display on MRI viewer', WinPos);
        close([hFigTs hFigTopo hFigSrcCortex hFigSrcMri3d hFigSrcMri]);
    end
    
    %% ===== SNAPSHOTS: SENSOR AND SOURCE TIME FREQUENCY =====
    function SnapshotsSensorSourceTimeFreq(SensorSourceFile, Brightness, Contrast, Time, SensorSourceName, WinPos)
        % Snapshot: Time frequency maps (all sensors/sources)
        hFigTfMapAll = view_timefreq(SensorSourceFile, 'AllSensors');
        sOptions = panel_display('GetDisplayOptions');
        sOptions.Function = 'log'; % Log power
        sOptions.HighResolution = 1; % Smooth display
        panel_display('SetDisplayOptions', sOptions);
        bst_colormaps('SetColormapAbsolute', 'timefreq', 0); % Turn off absolute value
        sColormap = bst_colormaps('GetColormap', hFigTfMapAll);
        sColormap.Contrast = Brightness;
        sColormap.Brightness = Contrast;
        sColormap = bst_colormaps('ApplyColormapModifiers', sColormap); % Apply modifiers (for brightness and contrast)
        bst_colormaps('SetColormap', 'timefreq', sColormap); % Save the changes in colormap
        bst_colormaps('FireColormapChanged', 'timefreq'); % Update the colormap in figures
        bst_report('Snapshot', hFigTfMapAll, SensorSourceFile, 'Time frequency map (all)', WinPos);
        
        % Snapshot: Time frequency maps (one sensor/source)
        hFigTfMap = view_timefreq(SensorSourceFile, 'SingleSensor');
        sOptions = panel_display('GetDisplayOptions');
        sOptions.RowName = SensorSourceName;
        sOptions.Function = 'log';
        sOptions.HighResolution = 1;
        panel_display('SetDisplayOptions', sOptions);
        bst_report('Snapshot', hFigTfMap, SensorSourceFile, ['Time frequency map (' SensorSourceName ')'], WinPos);
        close([hFigTfMapAll hFigTfMap]);
        
        % Power spectrum and time series
        hFigTf1 = view_spectrum(SensorSourceFile, 'Spectrum', SensorSourceName);
        hFigTf2 = view_spectrum(SensorSourceFile, 'TimeSeries', SensorSourceName);
        panel_freq('SetCurrentFreq', 1, 0);
        panel_time('SetCurrentTime', Time);
        bst_report('Snapshot', hFigTf1, SensorSourceFile, ['Power spectrum (' SensorSourceName ')'], WinPos);
        bst_report('Snapshot', hFigTf2, SensorSourceFile, ['Time series (' SensorSourceName ')'], WinPos);
        close([hFigTf1 hFigTf2]);
    end
end