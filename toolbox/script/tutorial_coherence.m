function tutorial_corticomuscular_coh(tutorial_dir, reports_dir)
% TUTORIAL_CORTICOMUSCULAR_COH: Script that runs the Brainstorm corticomuscular coherence tutorial
% https://neuroimage.usc.edu/brainstorm/Tutorials/CorticomuscularCoherence
%
% INPUTS: 
%    - tutorial_dir : Directory where the SubjectCMC.zip. file has been unzipped
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
% Author: Raymundo Cassani, 2022

% ===== FILES TO IMPORT =====
% Output folder for reports
if (nargin < 2) || isempty(reports_dir) || ~isfolder(reports_dir)
    reports_dir = [];
end
% You have to specify the folder in which the tutorial dataset is unzipped
if (nargin == 0) || isempty(tutorial_dir) || ~file_exist(tutorial_dir)
    error('The first argument must be the full path to the dataset folder.');
end

% Subject name
SubjectName = 'Subject01';
% Name of the Cortex surface to use for source localization
cortexName = 'central_15002V';
% Coherence process options
src_channel = 'EMGlft';   % Name of EMG channel
cohmeasure  = 'mscohere'; % Magnitude-squared Coherence|C|^2 = |Cxy|^2/(Cxx*Cyy)
win_length  =  0.5;       % 500ms
overlap     = 50;         % 50%
maxfreq     = 80;         % 80Hz
% TODO Ask for isBigRam as argument?
isBigRam = 0;
% TODO Ask for username as argument?
username = 'Raymundo.Cassani';

% Build the path of the files to import
MriFilePath = fullfile(tutorial_dir, 'SubjectCMC', 'SubjectCMC.mri');
MegFilePath = fullfile(tutorial_dir, 'SubjectCMC', 'SubjectCMC.ds');
% Check if the folder contains the required files
if ~file_exist(MegFilePath) || ~file_exist(MegFilePath)
    error(['The folder ' tutorial_dir ' does not contain the folder from the file SubjectCMC.zip.']);
end
% Re-initialize random number generator
if (bst_get('MatlabVersion') >= 712)
    rng('default');
end

% User should have CAT12 and SPM12 installed as per the Tutorial webpage
% Load needed plugins
InstPlugs = bst_plugin('GetInstalled');
% Reload SPM(12) plugin is an different version is found
if any(strcmpi({InstPlugs.Name}, 'spm12')) 
    if (exist('spm', 'file') == 2) && isempty(strfind(spm('ver'), 'SPM12')) %#ok<STREMP>
        bst_plugin('Unload', 'spm12');
    end
    PlugDesc = bst_plugin('GetInstalled', 'spm12'); 
    if ~PlugDesc.isLoaded
        bst_plugin('LoadInteractive', 'spm12');
    end    
end
% Load CAT12 
if any(strcmpi({InstPlugs.Name}, 'cat12'))
    PlugDesc = bst_plugin('GetInstalled', 'cat12'); 
    if ~PlugDesc.isLoaded
        bst_plugin('LoadInteractive', 'cat12');
    end    
else
    disp('Error: Plugin CAT12 is not installed. See the requirements for this tutorial.');
end


%% ===== 1. CREATE PROTOCOL =====
disp([10 'DEMO> 1. Create protocol' 10]);
% The protocol name has to be a valid folder name (no spaces, no weird characters...)
ProtocolName = 'TutorialCMC';
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
% Reset colormaps
bst_colormaps('RestoreDefaults', 'meg');


%% ===== 2. IMPORT AND PROCESS ANATOMY =====
disp([10 'DEMO> 2. Import and process anatomy' 10]);
% Process: Import MRI
bst_process('CallProcess', 'process_import_mri', [], [], ...
    'subjectname', SubjectName, ...
    'mrifile',     {MriFilePath, 'ALL'}, ...
    'nas',         [0, 0, 0], ...
    'lpa',         [0, 0, 0], ...
    'rpa',         [0, 0, 0], ...
    'ac',          [0, 0, 0], ...
    'pc',          [0, 0, 0], ...
    'ih',          [0, 0, 0]);
% Get subject definition
sSubject = bst_get('Subject', SubjectName);
% Get MRI file
MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
% Display MRI
hFigMri = view_mri(MriFile);
pause(0.5);
% Close figure
close(hFigMri);

% Process: Segment MRI with CAT12
bst_process('CallProcess', 'process_segment_cat12', [], [], ...
    'subjectname', SubjectName, ...
    'nvertices',   15000, ...
    'tpmnii',      {'', 'Nifti1'}, ...
    'sphreg',      1, ...
    'vol',         1, ...
    'extramaps',   0, ...
    'cerebellum',  0);
% Get subject definition
[sSubject, iSubject] = bst_get('Subject', SubjectName);
% Set default Cortex
[~, iSurface] = ismember(cortexName, {sSubject.Surface.Comment});
db_surface_default(iSubject, 'Cortex', iSurface);
panel_protocols('RepaintTree');
% Get surface files
CortexFile = sSubject.Surface(sSubject.iCortex).FileName;
HeadFile   = sSubject.Surface(sSubject.iScalp).FileName;
% Display scalp and cortex
hFigSurf = view_surface(HeadFile);
hFigSurf = view_surface(CortexFile, [], [], hFigSurf);
figure_3d('SetStandardView', hFigSurf, 'left');
hFigMriSurf = view_mri(MriFile, CortexFile);
pause(0.5);
% Close figures
close([hFigSurf hFigMriSurf]);


%% ===== 4. LINK TO RAW FILE AND DISPLAY CHANNEL FILE =====
disp([10 'DEMO> 4. Link to raw file and display channel file ' 10]);
% Set Functional data view for Database explorer
panel_protocols('SetExplorationMode', 'StudiesSubj');
% Process: Create link to raw files
sFilesMeg = bst_process('CallProcess', 'process_import_data_raw', [], [], ...
    'subjectname',  SubjectName, ...
    'datafile',     {MegFilePath, 'CTF'}, ...
    'channelalign', 1);
sFileRaw = sFilesMeg;
% Process: Snapshot: Sensors/MRI registration
bst_process('CallProcess', 'process_snapshot', sFilesMeg, [], ...
    'target',   1, ...  % Sensors/MRI registration
    'modality', 1, ...  % MEG (All)
    'orient',   1, ...  % left
    'Comment',  'MEG/MRI Registration');

% View CTF helmet
hFigHel = view_surface(HeadFile);
hFigHel = view_helmet(sFilesMeg.ChannelFile, hFigHel);
figure_3d('SetStandardView', hFigHel, 'left');
% View MEG sensors
hFigMeg = view_surface(HeadFile);
hFigMeg = view_channels(sFilesMeg.ChannelFile, 'MEG', 1, 1, hFigMeg);
figure_3d('SetStandardView', hFigMeg, 'left');
pause(0.5);
% Unload everything
bst_memory('UnloadAll', 'Forced');


%% ===== 5. REVIEW MEG AND EMG RECORDINGS =====
disp([10 'DEMO> 5. Review MEG and EMG recordings' 10]);
% Process: Convert to continuous (CTF): Continuous
bst_process('CallProcess', 'process_ctf_convert', sFileRaw, [], ...
    'rectype', 2);  % Continuous
% View recordings
hFigMeg = view_timeseries(sFilesMeg.FileName, 'MEG');
panel_record('SetTimeLength', 3);
panel_record('SetDisplayMode', hFigMeg, 'butterfly');
hFigEmg = view_timeseries(sFilesMeg.FileName, 'EMG');
panel_record('SetDisplayMode', hFigEmg, 'butterfly');
pause(0.5);
% Close figures
close([hFigMeg hFigEmg]);


%% ===== 6. EVENT MARKERS =====
% Process: Read from channel
disp([10 'DEMO> 6. Event markers' 10]);
sFileRaw = bst_process('CallProcess', 'process_evt_read', sFileRaw, [], ...
    'stimchan',     'Stim', ...
    'trackmode',    1, ...  % Value: detect the changes of channel value
    'zero',         0, ...
    'min_duration', 0);
% Load all Event group labels
DataMat = in_bst_data(sFileRaw.FileName, 'F');
eventList = {DataMat.F.events.label};
% Labels for Event groups to keep
eventKeep = cell(25,1);
for i = 1:25
    eventKeep{i} = ['U', num2str(i)];
end
% Reject trial #7
eventKeep(7) = [];
% Find useless Events
eventDelete = setdiff(eventList, eventKeep);
% Process: Delete events
sFileRaw = bst_process('CallProcess', 'process_evt_delete', sFileRaw, [], ...
    'eventname', strjoin(eventDelete, ', '));
% Process: Merge events
sFileRaw = bst_process('CallProcess', 'process_evt_merge', sFileRaw, [], ...
    'evtnames', strjoin(eventKeep, ', '), ...
    'newname',  'Left_01');
% Duplicate group 7 times 
nDuplicates = 7;
DataMat = in_bst_data(sFileRaw.FileName);
events = DataMat.F.events;
colorTable = lines(nDuplicates);
eventDuplicates = {nDuplicates, 1};
for i = 1 : nDuplicates
    iCopy = length(events) + 1;
    events(iCopy) = events(1);
    % Add "copy" tag
    events(iCopy).label = file_unique(events(iCopy).label, {events.label});
    eventDuplicates{i} = events(iCopy).label;
    % Set new color (based on Matlab current 
    events(iCopy).color = colorTable(i, :);
end
DataMat.F.events = events;
bst_save(file_fullpath(sFileRaw.FileName), DataMat, 'v6', 1);
%  Add time offset 
for i = 1 : nDuplicates
    % Process: Add time offset
    sFileRaw = bst_process('CallProcess', 'process_evt_timeoffset', sFileRaw, [], ...
    'info',      [], ...
    'eventname', eventDuplicates{i}, ...
    'offset',    1 * i);
end
% Merge all Left_XX as Left
eventLeft = [{'Left_01'}, eventDuplicates];
% Process: Merge events
sFileRaw = bst_process('CallProcess', 'process_evt_merge', sFileRaw, [], ...
    'evtnames', strjoin(eventLeft, ', '), ...
    'newname',  'Left');
% View recordings
hFigMeg = view_timeseries(sFilesMeg.FileName, 'MEG');
pause(0.5);
% Close figure
close(hFigMeg);

%% ===== 7. CTF COMPENSATION =====
% Process: Apply SSP & CTF compensation
disp([10 'DEMO> 7. Apply CTF compensation' 10]);
sFileRawClean = bst_process('CallProcess', 'process_ssp_apply', sFileRaw, []);

%% ===== 8. REMOVAL OF POWER LINE ARTIFACTS =====
disp([10 'DEMO> 8. Removal of power line artifacts' 10]);
% Process: Notch filter: 50Hz 100Hz 150Hz
sFileRawCleanNotch = bst_process('CallProcess', 'process_notch', sFileRawClean, [], ...
    'freqlist',    [50, 100, 150], ...
    'sensortypes', 'MEG, EMG', ...
    'read_all',    0);
% Process: Power spectrum density (Welch)
sFilesPsd = bst_process('CallProcess', 'process_psd', [sFileRawClean, sFileRawCleanNotch], [], ...
    'timewindow',  [0 330], ...
    'win_length',  10, ...
    'win_overlap', 50, ...
    'clusters',    {}, ...
    'sensortypes', 'MEG, EMG', ...
    'edit', struct(...
         'Comment',    'Power', ...
         'TimeBands',  [], ...
         'Freqs',      [], ...
         'ClusterFuncTime', 'none', ...
         'Measure',    'power', ...
         'Output',     'all', ...
         'SaveKernel', 0));
% Process: Snapshot: Frequency spectrum
bst_process('CallProcess', 'process_snapshot', sFilesPsd, [], ...
    'target',   10, ...  % Frequency spectrum
    'modality', 1, ...   % MEG (All)
    'Comment',  'Power spectrum density');


%% ===== 9. EMG PRE-PROCESSING =====
disp([10 'DEMO> 9. EMG pre-processing' 10]);
% Process: High-pass:10Hz
sFileRawCleanNotchHigh = bst_process('CallProcess', 'process_bandpass', sFileRawCleanNotch, [], ...
    'sensortypes', 'EMG', ...
    'highpass',    10, ...
    'lowpass',     0, ...
    'tranband',    0, ...
    'attenuation', 'strict', ...  % 60dB
    'ver',         '2019', ...  % 2019
    'mirror',      0, ...
    'read_all',    0);
% Process: Absolute values
sFileRawCleanNotchHighAbs = bst_process('CallProcess', 'process_absolute', sFileRawCleanNotchHigh, [], ...
    'sensortypes', 'EMG');
% Process: Delete folders
bst_process('CallProcess', 'process_delete', [sFileRawCleanNotch, sFileRawCleanNotchHigh], [], ...
    'target', 2);  % Delete folders
% Pre-processed file
sFilePreProc = sFileRawCleanNotchHighAbs;


%% ===== 10. MEG PRE-PROCESSING =====
disp([10 'DEMO> 10. MEG pre-processing' 10]);
% Process: Detect eye blinks
bst_process('CallProcess', 'process_evt_detect_eog',  sFilePreProc, [], ...
    'channelname', 'EOG', ...
    'timewindow',  [0 330], ...
    'eventname',   'blink');
% Process: SSP EOG: blink
bst_process('CallProcess', 'process_ssp_eog', sFilePreProc, [], ...
    'eventname',   'blink', ...
    'sensortypes', 'MEG', ...
    'usessp',      1, ...
    'select',      [1]);
% Process: Detect other artifacts
bst_process('CallProcess', 'process_evt_detect_badsegment', sFilePreProc, [], ...
    'timewindow',  [0 330], ...
    'sensortypes', 'MEG', ...
    'threshold',   3, ...  % 3
    'isLowFreq',   1, ...
    'isHighFreq',  1);
% Process: Rename event (1-7Hz > bad_1-7Hz)
bst_process('CallProcess', 'process_evt_rename', sFilePreProc, [], ...
    'src',  '1-7Hz', ...
    'dest', 'bad_1-7Hz');
% Process: Rename event (40-240Hz > bad_40-240Hz)
bst_process('CallProcess', 'process_evt_rename', sFilePreProc, [], ...
    'src',  '40-240Hz', ...
    'dest', 'bad_40-240Hz');
% Process: Snapshot: SSP projectors
bst_process('CallProcess', 'process_snapshot', sFilePreProc, [], ...
    'target',  2, ...  % SSP projectors
    'Comment', 'SSP projectors');


%% ===== 11. IMPORTING DATA EPOCHS =====
disp([10 'DEMO> 11. Import data epochs' 10]);
% Process: Import MEG/EEG: Events
sFilesEpochs = bst_process('CallProcess', 'process_import_data_event', sFilePreProc, [], ...
    'subjectname', SubjectName, ...
    'condition',   'SubjectCMC_preprocessed', ...
    'eventname',   'Left', ...
    'timewindow',  [0 330], ...
    'epochtime',   [0 1], ...
    'createcond',  0, ...
    'ignoreshort', 1, ...
    'usectfcomp',  1, ...
    'usessp',      1, ...
    'freq',        [], ...
    'baseline',    [0, 1]);

% View recordings, trial 1
hFigMeg = view_timeseries(sFilesEpochs(1).FileName, 'MEG', 'MRC21');
hFigEmg = view_timeseries(sFilesEpochs(1).FileName, 'EMG');
pause(0.5);
% Close figures
close([hFigMeg, hFigEmg]);


%% ===== 12. COHERENCE 1xN (SENSOR LEVEL) =====
disp([10 'DEMO> 12. Coherence 1xN (sensor level)' 10]);
% Process: Coherence 1xN [2021]
sFileCoh1N = bst_process('CallProcess', 'process_cohere1_2021', {sFilesEpochs.FileName}, [], ...
    'timewindow',   [], ...
    'src_channel',  src_channel, ...
    'dest_sensors', 'MEG', ...
    'includebad',   0, ...
    'removeevoked', 0, ...
    'cohmeasure',   cohmeasure, ...
    'win_length',   win_length, ...
    'overlap',      overlap, ...
    'maxfreq',      maxfreq, ...
    'outputmode',   'avgcoh');  % Average cross-spectra of input files (one output file)
% Process: Snapshot: Frequency spectrum
bst_process('CallProcess', 'process_snapshot', sFileCoh1N, [], ...
    'target',         10, ...  % Frequency spectrum
    'modality',       1, ...  % MEG (All)
    'orient',         1, ...  % left
    'time',           0, ...
    'rowname',        '', ...
    'Comment',        '');
% View coherence 1xN (sensor level)
hFigCohSpcA = view_spectrum(sFileCoh1N.FileName, 'Spectrum');
hFigCohSpc1 = view_spectrum(sFileCoh1N.FileName, 'Spectrum', 'MRC21');
hFigCohTop = view_topography(sFileCoh1N.FileName);
% TODO Show sensor locations in topoplot
% TODO Set frequency slider to 17.58 Hz
% TODO Selet MRC21
pause(0.5);
% Close figures
close([hFigCohSpcA, hFigCohSpc1, hFigCohTop]);

% Process: Group in time or frequency bands
sFileCoh1NBand = bst_process('CallProcess', 'process_tf_bands', sFileCoh1N, [], ...
    'isfreqbands', 1, ...
    'freqbands',   {'cmc_band', '15, 20', 'mean'}, ...
    'istimebands', 0, ...
    'timebands',   '', ...
    'overwrite',   0);

hFigCohTop = view_topography(sFileCoh1NBand.FileName);
% TODO Show sensor locations in topoplot
% TODO Set frequency slider to 17.58 Hz
% TODO Selet MRC21
pause(0.5);
% Close figure
close(hFigCohTop);

%% ===== 13. MEG SOURCE MODELLING =====
disp([10 'DEMO> 13. MEG source modelling' 10]);
% Process: Compute covariance (noise or data)
bst_process('CallProcess', 'process_noisecov', sFilePreProc, [], ...
    'baseline',       [18, 30], ...
    'datatimewindow', [18, 30], ...
    'sensortypes',    'MEG', ...
    'target',         1, ...  % Noise covariance     (covariance over baseline time window)
    'dcoffset',       1, ...  % Block by block, to avoid effects of slow shifts in data
    'identity',       0, ...
    'copycond',       1, ...
    'copysubj',       0, ...
    'copymatch',      0, ...
    'replacefile',    1);  % Replace
% Set default Cortex surface
[sSubject, isSubject] = bst_get('Subject', SubjectName);
[~, iSurface] = ismember(cortexName, {sSubject.Surface.Comment});
if sSubject.iCortex ~= iSurface
    db_surface_default(isSubject, 'Cortex', iSurface);
    panel_protocols('RepaintTree');
end
% Process: Compute head model (surface)
bst_process('CallProcess', 'process_headmodel', sFilesEpochs(1).FileName, [], ...
    'Comment',      'Overlapping spheres (surface)', ...
    'sourcespace',  1, ... % Cortex
    'meg',          3);    % Overlapping spheres
% Process: Compute head model (volume)
bst_process('CallProcess', 'process_headmodel', sFilesEpochs(1).FileName, [], ...
    'Comment',     'Overlapping spheres (volume)', ...
    'sourcespace', 2, ...  % MRI volume
    'volumegrid',  struct(...
         'Method',        'isotropic', ...
         'nLayers',       17, ...
         'Reduction',     3, ...
         'nVerticesInit', 4000, ...
         'Resolution',    0.005, ...
         'FileName',      []), ...
    'meg',         3 );  % Overlapping spheres


%% ===== 14. SOURCE ESTIMATION =====
disp([10 'DEMO> 14. Source estimation' 10]);
% iStudy for current imported data epochs
iStudy = sFilesEpochs(1).iStudy;
% ===== SURFACE SPACE =====
% Set (surface) head model as default
sStudy = bst_get('Study', iStudy);
[~, iHeadModel] = ismember('Overlapping spheres (surface)', {sStudy.HeadModel.Comment});
% Save in database selected file
sStudy.iHeadModel = iHeadModel;
bst_set('Study', iStudy, sStudy);
% Repaint tree
panel_protocols('RepaintTree');
% Compute inversion kernels for Constrained and Unconstrained sources
kernelSourceOrients = {'fixed', 'free'}; % Constr == fixed; Unconstr == free
for ix = 1 : length(kernelSourceOrients)
    kernelSourceOrient = kernelSourceOrients{ix};
    % Process: Compute sources [2018]
    bst_process('CallProcess', 'process_inverse_2018', sFilesEpochs(1).FileName, [], ...
        'output',  1, ...  % Kernel only: shared
        'inverse', struct(...
             'Comment',        'MN: MEG (surface)', ...
             'InverseMethod',  'minnorm', ...
             'InverseMeasure', 'amplitude', ...
             'SourceOrient',   {{kernelSourceOrient}}, ...
             'Loose',          0.2, ...
             'UseDepth',       1, ...
             'WeightExp',      0.5, ...
             'WeightLimit',    10, ...
             'NoiseMethod',    'reg', ...
             'NoiseReg',       0.1, ...
             'SnrMethod',      'fixed', ...
             'SnrRms',         1e-06, ...
             'SnrFixed',       3, ...
             'ComputeKernel',  1, ...
             'DataTypes',      {{'MEG'}}));
end

% ===== VOLUME SPACE =====
% Set (volume) head model as default
sStudy = bst_get('Study', iStudy);
[~, iHeadModel] = ismember('Overlapping spheres (volume)', {sStudy.HeadModel.Comment});
% Save in database selected file
sStudy.iHeadModel = iHeadModel;
bst_set('Study', iStudy, sStudy);
% Repaint tree
panel_protocols('RepaintTree');
% Compute inversion kernel Unconstrained sources
% Process: Compute sources [2018]
bst_process('CallProcess', 'process_inverse_2018', sFilesEpochs(1).FileName, [], ...
    'output',  1, ...  % Kernel only: shared
    'inverse', struct(...
         'Comment',        'MN: MEG (volume)', ...
         'InverseMethod',  'minnorm', ...
         'InverseMeasure', 'amplitude', ...
         'SourceOrient',   {{'free'}}, ...
         'Loose',          0.2, ...
         'UseDepth',       1, ...
         'WeightExp',      0.5, ...
         'WeightLimit',    10, ...
         'NoiseMethod',    'reg', ...
         'NoiseReg',       0.1, ...
         'SnrMethod',      'fixed', ...
         'SnrRms',         1e-06, ...
         'SnrFixed',       3, ...
         'ComputeKernel',  1, ...
         'DataTypes',      {{'MEG'}}));

     
%% ===== 15. COHERENCE 1xN (SOURCE LEVEL) =====
disp([10 'DEMO> 15. Coherence 1xN (source level)' 10]);
% Process: Select data files
sFilesRecEmg = bst_process('CallProcess', 'process_select_files_data', [], [], ...
    'subjectname',   SubjectName, ...
    'condition',     '', ...
    'tag',           'Left', ...
    'includebad',    0, ...
    'includeintra',  0, ...
    'includecommon', 0);
% Coherence between EMG signal and sources (for different source types)
sFileCoh1Ns = [];
sourceTypes = {'(surface)(Constr)', '(surface)(Unconstr)', '(volume)(Unconstr)'};
for ix = 1 :  length(sourceTypes)
    sourceType = sourceTypes{ix};
    % Process: Select results files
    sFilesResMeg = bst_process('CallProcess', 'process_select_files_results', [], [], ...
        'subjectname',   SubjectName, ...
        'condition',     '', ...
        'tag',           sourceType, ...
        'includebad',    0, ...
        'includeintra',  0, ...
        'includecommon', 0);
    % Process: Coherence AxB [2021]
    sFileCoh1N = bst_process('CallProcess', 'process_cohere2_2021', sFilesRecEmg, sFilesResMeg, ...
        'timewindow',   [], ...
        'src_channel',  src_channel, ...
        'dest_scouts',  {}, ...
        'scoutfunc',    1, ...  % Mean
        'scouttime',    2, ...  % After
        'removeevoked', 0, ...
        'cohmeasure',   cohmeasure, ...
        'win_length',   win_length, ...
        'overlap',      overlap, ...
        'maxfreq',      maxfreq, ...
        'outputmode',   'avgcoh');  % Average cross-spectra of input files (one output file)
    % Process: Add tag
    sFileCoh1N = bst_process('CallProcess', 'process_add_tag', sFileCoh1N, [], ...
        'tag',           sourceType, ...
        'output',        1);  % Add to file name    
    sFileCoh1Ns = [sFileCoh1Ns; sFileCoh1N];
end

% View coherence 1xN (source level)
hFigs = [];
for ix = 1 : length(sFileCoh1Ns)
    sFileCoh1N = sFileCoh1Ns(ix);
    sourceType = sourceTypes{ix};
    % Surface results
    if ~isempty(strfind(sourceType, 'surface'))
        hFigs = [hFigs; view_surface_data([], sFileCoh1N.FileName)];
        % TODO Set frequency slider to 14.65 Hz
    % Volume results
    elseif ~isempty(strfind(sourceType, 'volume'))
        % Get subject definition
        sSubject = bst_get('Subject', SubjectName);
        hFigs = [hFigs; view_mri(sSubject.Anatomy(sSubject.iAnatomy).FileName, sFileCoh1N.FileName, 'MEG')];
        % TODO Set frequency slider to 14.65 Hz
        % TODO Got to SCS [X:38.6, Y:-21.3 and Z:115.5]
        % TODO Set transparencey 30%
    end
end
pause(0.5);
% Close figures
close(hFigs);


%% ===== 16. COHERENCE 1xN (SCOUT LEVEL) =====
disp([10 'DEMO> 16. Coherence 1xN (scout level)' 10]);
% Process: Select data files
sFilesRecEmg = bst_process('CallProcess', 'process_select_files_data', [], [], ...
    'subjectname',   SubjectName, ...
    'condition',     '', ...
    'tag',           'Left', ...
    'includebad',    0, ...
    'includeintra',  0, ...
    'includecommon', 0);
% Only performed for (surface)(Constrained)
sourceType = '(surface)(Constr)';
sFilesResSrfUnc = bst_process('CallProcess', 'process_select_files_results', [], [], ...
    'subjectname',   SubjectName, ...
    'condition',     '', ...
    'tag',           sourceType, ...
    'includebad',    0, ...
    'includeintra',  0, ...
    'includecommon', 0);
% Coherence between EMG signal and scouts (for different "when to apply the scout function")
sFileCoh1Ns = [];
scoutFuntcTimes = {'Bef', 'Aft'}; % Before and After     
for ix = 1 : length(scoutFuntcTimes)
    scoutFuntcTime = scoutFuntcTimes{ix};
    switch scoutFuntcTime
        case 'Bef'
            scouttime = 1;
        case 'Aft'
            scouttime = 2;
            if ~isBigRam
                continue
            end
    end
    % Process: Coherence AxB [2021]
    sFileCoh1N = bst_process('CallProcess', 'process_cohere2_2021', sFilesRecEmg, sFilesResSrfUnc, ...
        'timewindow',   [], ...
        'src_channel',  'EMGlft', ...
        'dest_scouts',  {'Schaefer_100_17net', {'Background+FreeSurfer_Defined_Medial_Wall L', 'Background+FreeSurfer_Defined_Medial_Wall R', 'ContA_IPS_1 L', 'ContA_IPS_1 R', 'ContA_PFCl_1 L', 'ContA_PFCl_1 R', 'ContA_PFCl_2 L', 'ContA_PFCl_2 R', 'ContB_IPL_1 R', 'ContB_PFCld_1 R', 'ContB_PFClv_1 L', 'ContB_PFClv_1 R', 'ContB_Temp_1 R', 'ContC_Cingp_1 L', 'ContC_Cingp_1 R', 'ContC_pCun_1 L', 'ContC_pCun_1 R', 'ContC_pCun_2 L', 'DefaultA_IPL_1 R', 'DefaultA_PFCd_1 L', 'DefaultA_PFCd_1 R', 'DefaultA_PFCm_1 L', 'DefaultA_PFCm_1 R', 'DefaultA_pCunPCC_1 L', 'DefaultA_pCunPCC_1 R', 'DefaultB_IPL_1 L', 'DefaultB_PFCd_1 L', 'DefaultB_PFCd_1 R', 'DefaultB_PFCl_1 L', 'DefaultB_PFCv_1 L', 'DefaultB_PFCv_1 R', 'DefaultB_PFCv_2 L', 'DefaultB_PFCv_2 R', 'DefaultB_Temp_1 L', 'DefaultB_Temp_2 L', 'DefaultC_PHC_1 L', 'DefaultC_PHC_1 R', 'DefaultC_Rsp_1 L', 'DefaultC_Rsp_1 R', 'DorsAttnA_ParOcc_1 L', 'DorsAttnA_ParOcc_1 R', 'DorsAttnA_SPL_1 L', 'DorsAttnA_SPL_1 R', 'DorsAttnA_TempOcc_1 L', 'DorsAttnA_TempOcc_1 R', 'DorsAttnB_FEF_1 L', 'DorsAttnB_FEF_1 R', 'DorsAttnB_PostC_1 L', 'DorsAttnB_PostC_1 R', 'DorsAttnB_PostC_2 L', 'DorsAttnB_PostC_2 R', 'DorsAttnB_PostC_3 L', 'LimbicA_TempPole_1 L', 'LimbicA_TempPole_1 R', 'LimbicA_TempPole_2 L', 'LimbicB_OFC_1 L', 'LimbicB_OFC_1 R', 'SalVentAttnA_FrMed_1 L', 'SalVentAttnA_FrMed_1 R', 'SalVentAttnA_Ins_1 L', 'SalVentAttnA_Ins_1 R', 'SalVentAttnA_Ins_2 L', 'SalVentAttnA_ParMed_1 L', 'SalVentAttnA_ParMed_1 R', 'SalVentAttnA_ParOper_1 L', 'SalVentAttnA_ParOper_1 R', 'SalVentAttnB_IPL_1 R', 'SalVentAttnB_PFCl_1 L', 'SalVentAttnB_PFCl_1 R', 'SalVentAttnB_PFCmp_1 L', 'SalVentAttnB_PFCmp_1 R', 'SomMotA_1 L', 'SomMotA_1 R', 'SomMotA_2 L', 'SomMotA_2 R', 'SomMotA_3 R', 'SomMotA_4 R', 'SomMotB_Aud_1 L', 'SomMotB_Aud_1 R', 'SomMotB_Cent_1 L', 'SomMotB_Cent_1 R', 'SomMotB_S2_1 L', 'SomMotB_S2_1 R', 'SomMotB_S2_2 L', 'SomMotB_S2_2 R', 'TempPar_1 L', 'TempPar_1 R', 'TempPar_2 R', 'TempPar_3 R', 'VisCent_ExStr_1 L', 'VisCent_ExStr_1 R', 'VisCent_ExStr_2 L', 'VisCent_ExStr_2 R', 'VisCent_ExStr_3 L', 'VisCent_ExStr_3 R', 'VisCent_Striate_1 L', 'VisPeri_ExStrInf_1 L', 'VisPeri_ExStrInf_1 R', 'VisPeri_ExStrSup_1 L', 'VisPeri_ExStrSup_1 R', 'VisPeri_StriCal_1 L', 'VisPeri_StriCal_1 R'}}, ...
        'scoutfunc',    1, ...  % Mean
        'scouttime',    scouttime, ... 
        'removeevoked', 0, ...
        'cohmeasure',   cohmeasure, ...
        'win_length',   win_length, ...
        'overlap',      overlap, ...
        'maxfreq',      maxfreq, ...
        'outputmode',   'avgcoh');  % Average cross-spectra of input files (one output file)
    % Process: Add tag
    sFileCoh1N = bst_process('CallProcess', 'process_add_tag', sFileCoh1N, [], ...
        'tag',           [sourceType, '(', scoutFuntcTime, 'Sct)'], ...
        'output',        1);  % Add to file name     
    sFileCoh1Ns = [sFileCoh1Ns; sFileCoh1N];   
end

% View coherence 1xN (scout level)
hFigs = [];
for ix = 1 : length(sFileCoh1Ns)
    sFileCoh1N = sFileCoh1Ns(ix);
    hFigs = [hFigs; view_spectrum(sFileCoh1N.FileName, 'Spectrum')];
    hFigs = [hFigs; view_connect(sFileCoh1N.FileName, 'Image')];
    % TODO Select SomMotA_2 R scout
    % TODO Set frequency slider to 14.65 Hz
end
pause(0.5);
% Close figures
close(hFigs);


%% ===== 17. COHERENCE NxN, CONNECTOME (SCOUT LEVEL) =====
disp([10 'DEMO> 17. Coherence NxN, connectome (scout level)' 10]);
% Only performed for (surface)(Constrained)
sourceType = '(surface)(Constr)';
sFilesResSrfUnc = bst_process('CallProcess', 'process_select_files_results', [], [], ...
    'subjectname',   SubjectName, ...
    'condition',     '', ...
    'tag',           sourceType, ...
    'includebad',    0, ...
    'includeintra',  0, ...
    'includecommon', 0);
% Coherence between EMG signal and scouts (for different "when to apply the scout function")
sFileCoh1Ns = [];
scoutFuntcTimes = {'Bef', 'Aft'}; % Before and After     
for ix = 1 : length(scoutFuntcTimes)
    scoutFuntcTime = scoutFuntcTimes{ix};
    switch scoutFuntcTime
        case 'Bef'
            scouttime = 1;
        case 'Aft'
            scouttime = 2;
            if ~isBigRam
                continue
            end
    end
    % Process: Coherence NxN [2021]
    sFileCoh1N = bst_process('CallProcess', 'process_cohere1n_2021', sFilesResSrfUnc, [], ...
        'timewindow',   [], ...
        'scouts',       {'Schaefer_100_17net', {'Background+FreeSurfer_Defined_Medial_Wall L', 'Background+FreeSurfer_Defined_Medial_Wall R', 'ContA_IPS_1 L', 'ContA_IPS_1 R', 'ContA_PFCl_1 L', 'ContA_PFCl_1 R', 'ContA_PFCl_2 L', 'ContA_PFCl_2 R', 'ContB_IPL_1 R', 'ContB_PFCld_1 R', 'ContB_PFClv_1 L', 'ContB_PFClv_1 R', 'ContB_Temp_1 R', 'ContC_Cingp_1 L', 'ContC_Cingp_1 R', 'ContC_pCun_1 L', 'ContC_pCun_1 R', 'ContC_pCun_2 L', 'DefaultA_IPL_1 R', 'DefaultA_PFCd_1 L', 'DefaultA_PFCd_1 R', 'DefaultA_PFCm_1 L', 'DefaultA_PFCm_1 R', 'DefaultA_pCunPCC_1 L', 'DefaultA_pCunPCC_1 R', 'DefaultB_IPL_1 L', 'DefaultB_PFCd_1 L', 'DefaultB_PFCd_1 R', 'DefaultB_PFCl_1 L', 'DefaultB_PFCv_1 L', 'DefaultB_PFCv_1 R', 'DefaultB_PFCv_2 L', 'DefaultB_PFCv_2 R', 'DefaultB_Temp_1 L', 'DefaultB_Temp_2 L', 'DefaultC_PHC_1 L', 'DefaultC_PHC_1 R', 'DefaultC_Rsp_1 L', 'DefaultC_Rsp_1 R', 'DorsAttnA_ParOcc_1 L', 'DorsAttnA_ParOcc_1 R', 'DorsAttnA_SPL_1 L', 'DorsAttnA_SPL_1 R', 'DorsAttnA_TempOcc_1 L', 'DorsAttnA_TempOcc_1 R', 'DorsAttnB_FEF_1 L', 'DorsAttnB_FEF_1 R', 'DorsAttnB_PostC_1 L', 'DorsAttnB_PostC_1 R', 'DorsAttnB_PostC_2 L', 'DorsAttnB_PostC_2 R', 'DorsAttnB_PostC_3 L', 'LimbicA_TempPole_1 L', 'LimbicA_TempPole_1 R', 'LimbicA_TempPole_2 L', 'LimbicB_OFC_1 L', 'LimbicB_OFC_1 R', 'SalVentAttnA_FrMed_1 L', 'SalVentAttnA_FrMed_1 R', 'SalVentAttnA_Ins_1 L', 'SalVentAttnA_Ins_1 R', 'SalVentAttnA_Ins_2 L', 'SalVentAttnA_ParMed_1 L', 'SalVentAttnA_ParMed_1 R', 'SalVentAttnA_ParOper_1 L', 'SalVentAttnA_ParOper_1 R', 'SalVentAttnB_IPL_1 R', 'SalVentAttnB_PFCl_1 L', 'SalVentAttnB_PFCl_1 R', 'SalVentAttnB_PFCmp_1 L', 'SalVentAttnB_PFCmp_1 R', 'SomMotA_1 L', 'SomMotA_1 R', 'SomMotA_2 L', 'SomMotA_2 R', 'SomMotA_3 R', 'SomMotA_4 R', 'SomMotB_Aud_1 L', 'SomMotB_Aud_1 R', 'SomMotB_Cent_1 L', 'SomMotB_Cent_1 R', 'SomMotB_S2_1 L', 'SomMotB_S2_1 R', 'SomMotB_S2_2 L', 'SomMotB_S2_2 R', 'TempPar_1 L', 'TempPar_1 R', 'TempPar_2 R', 'TempPar_3 R', 'VisCent_ExStr_1 L', 'VisCent_ExStr_1 R', 'VisCent_ExStr_2 L', 'VisCent_ExStr_2 R', 'VisCent_ExStr_3 L', 'VisCent_ExStr_3 R', 'VisCent_Striate_1 L', 'VisPeri_ExStrInf_1 L', 'VisPeri_ExStrInf_1 R', 'VisPeri_ExStrSup_1 L', 'VisPeri_ExStrSup_1 R', 'VisPeri_StriCal_1 L', 'VisPeri_StriCal_1 R'}}, ...
        'scoutfunc',    1, ...  % Mean
        'scouttime',    scouttime, ... 
        'removeevoked', 0, ...
        'cohmeasure',   cohmeasure, ...
        'win_length',   win_length, ...
        'overlap',      overlap, ...
        'maxfreq',      maxfreq, ...
        'outputmode',   'avgcoh');  % Average cross-spectra of input files (one output file)    
    % Process: Add tag
    sFileCoh1N = bst_process('CallProcess', 'process_add_tag', sFileCoh1N, [], ...
        'tag',           sourceType, ...
        'output',        1);  % Add to file name     
    sFileCoh1Ns = [sFileCoh1Ns; sFileCoh1N];       
end

% View coherence NxN (scout level)
hFigs = [];
for ix = 1 : length(sFileCoh1Ns)
    sFileCoh1N = sFileCoh1Ns(ix);
    hFigs = [hFigs; view_connect(sFileCoh1N.FileName, 'GraphFull')];
    hFigs = [hFigs; view_connect(sFileCoh1N.FileName, 'Image')];
    % TODO Set frequency slider to 14.65 Hz
    % TODO Define and set intensity threhold for Graph figure
end
pause(0.5);
% Close figures
close(hFigs);

%% ===== SAVE REPORT =====
disp([10 'DEMO> Save report' 10]);
% Save and display report
ReportFile = bst_report('Save', []);
if ~isempty(reports_dir) && ~isempty(ReportFile)
    bst_report('Export', ReportFile, reports_dir);
else
    bst_report('Open', ReportFile);
end

disp([10 'DEMO> Corticomuscular coherence tutorial completed' 10]);

% Process: Send report by email
bst_process('CallProcess', 'process_report_email', [], [], ...
    'username',   username, ...
    'cc',         '', ...
    'subject',    'Corticomuscular coherence tutorial completed', ...
    'reportfile', ReportFile, ...
    'full',       1);
