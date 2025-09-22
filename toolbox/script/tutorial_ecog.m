function tutorial_ecog(tutorial_dir, reports_dir)
% TUTORIAL_ECOG: Script that runs ECoG/sEEG tutorial
% https://neuroimage.usc.edu/brainstorm/Tutorials/ECoG
%
% INPUTS:
%    - tutorial_dir : Directory where the sample_ecog.zip file has been unzipped
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
% Author: Raymundo Cassani, 2025


% Output folder for reports
if (nargin < 2) || isempty(reports_dir) || ~isdir(reports_dir)
    reports_dir = [];
end
% You have to specify the folder in which the tutorial dataset is unzipped
if (nargin == 0) || isempty(tutorial_dir) || ~file_exist(tutorial_dir)
    error('The first argument must be the full path to the dataset folder.');
end

%% ===== FILES TO IMPORT =====
% Subject name
SubjectName = 'ecog01';
% Build the path of the files to import
AnatDir    = fullfile(tutorial_dir, 'sample_ecog', 'derivatives', 'freesurfer', 'sub-ecog01_ses-preimp');
PostMri    = fullfile(tutorial_dir, 'sample_ecog', 'sub-ecog01', 'ses-postimp', 'anat', 'sub-ecog01_ses-postimp_T1w.nii.gz');
EegRawFile = fullfile(tutorial_dir, 'sample_ecog', 'sub-ecog01', 'ses-postimp', 'ieeg', 'sub-ecog01_ses-postimp_task-seizure_run-01_ieeg.eeg');
EegLocFile = fullfile(tutorial_dir, 'sample_ecog', 'sub-ecog01', 'ses-postimp', 'ieeg', 'sub-ecog01_ses-postimp_space-ScanRAS_electrodes.tsv');
% Check if the folder contains the required files
if ~file_exist(EegRawFile)
    error(['The folder ' tutorial_dir ' does not contain the folder from the file sample_ecog.zip.']);
end


%% ===== 01: CREATE PROTOCOL ===================================================
%  =============================================================================
disp([10 'DEMO> 01: Create protocol' 10]);
% The protocol name has to be a valid folder name (no spaces, no weird characters...)
ProtocolName = 'TutorialEcog';
% Start brainstorm with GUI
if ~brainstorm('status')
    brainstorm
end
% Delete existing protocol
gui_brainstorm('DeleteProtocol', ProtocolName);
% Create new protocol
gui_brainstorm('CreateProtocol', ProtocolName, 0, 0);
% Start a new report
bst_report('Start');
% Reset colormaps
bst_colormaps('RestoreDefaults', 'eeg');


%% ===== 02: IMPORT ANATOMY ====================================================
%  =============================================================================
disp([10 'DEMO> 02: Import anatomy' 10]);

% === Pre-implantation MRI ===
% Process: Import FreeSurfer folder
bst_process('CallProcess', 'process_import_anatomy', [], [], ...
    'subjectname', SubjectName, ...
    'mrifile',     {AnatDir, 'FreeSurfer'}, ...
    'nvertices',   15000);
% Rename reference MRI
[sSubject, iSubject] = bst_get('Subject', SubjectName);
file_update(file_fullpath(sSubject.Anatomy(sSubject.iAnatomy).FileName), 'Field', 'Comment', 'T1pre');
db_reload_subjects(iSubject);

% === Post-implantation MRI ===
% Process: Import MRI
bst_process('CallProcess', 'process_import_mri', [], [], ...
    'subjectname', SubjectName, ...
    'mrifile',     {PostMri, 'Nifti1'});
sSubject = bst_get('Subject', SubjectName);
iAnatPost = length(sSubject.Anatomy);
file_update(file_fullpath(sSubject.Anatomy(iAnatPost).FileName), 'Field', 'Comment', 'T1post');
db_reload_subjects(iSubject);

% === Coregister and reslice post-implantation with pre-implantation ===
% Coregister (without reslicing)
MriPostReg = mri_coregister(sSubject.Anatomy(iAnatPost).FileName, [], 'SPM', 0);
% Delete post-implantation (without coregistration)
file_delete(file_fullpath(sSubject.Anatomy(iAnatPost).FileName), 1);
db_reload_subjects(iSubject);
sSubject = bst_get('Subject', SubjectName);
% Reslice coregisted post-implantation MRI with world coordinates
iAnatPostReg = find(strcmp(MriPostReg, {sSubject.Anatomy.FileName}));
MriPostRegReslice = mri_reslice(sSubject.Anatomy(iAnatPostReg).FileName, [], 'vox2ras', 'vox2ras');
% Figure: Overlay T1post_spm_reslice on T1pre
hFig = view_mri(sSubject.Anatomy(sSubject.iAnatomy).FileName, MriPostRegReslice);
% Amplitude to 20%
panel_surface('SetDataThreshold', hFig, 1, 0.2);
bst_report('Snapshot', hFig, '', 'Coregistration T1pre on T1post_spm_reslice');
pause(0.5);
close(hFig);

% === Generate BEM surfaces ===
% Process: Generate BEM surfaces
bst_process('CallProcess', 'process_generate_bem', [], [], ...
    'subjectname', SubjectName, ...
    'nscalp',      1922, ...
    'nouter',      1922, ...
    'ninner',      1922, ...
    'thickness',   4, ...
    'method',      'brainstorm');  % Brainstorm
% Set default head surface and update Subject node
[sSubject, iSubject] = bst_get('Subject', SubjectName);
iScalp = find(strcmp('head mask (10000,0,2,18)', {sSubject.Surface.Comment}));
db_surface_default(iSubject, 'Scalp', iScalp, 1);
panel_protocols('UpdateNode', 'Subject', iSubject);
% Figure: BEM surfaces
hFig = view_surface(sSubject.Surface(sSubject.iScalp).FileName);
view_surface(sSubject.Surface(sSubject.iOuterSkull).FileName);
view_surface(sSubject.Surface(sSubject.iInnerSkull).FileName);
view_surface(sSubject.Surface(sSubject.iCortex).FileName);
iTess = 3; % InnerSkull
panel_surface('SetShowSulci',     hFig, iTess, 1);
panel_surface('SetSurfaceColor',  hFig, iTess, [1 0 0]);
figure_3d('SetStandardView', hFig, 'left');
pause(0.5);
bst_report('Snapshot', hFig, '', 'BEM surfaces and Cortex');
close(hFig);


%% ===== 03: ACCESS THE RECORDINGS ==============================================
%  =============================================================================
disp([10 'DEMO> 03: Access the recordings' 10]);
% === Link the recordings ===
% Process: Create link to raw files
sFileRaw = bst_process('CallProcess', 'process_import_data_raw', [], [], ...
    'subjectname',  SubjectName, ...
    'datafile',     {EegRawFile, 'ECOG-ALL'});

% === Edit channel and intracranial electrodes in channel file ===
sChannelMat = in_bst_channel(sFileRaw.ChannelFile);
% ECOG grid 'G'
iIntraElec = find(strcmp('G', {sChannelMat.IntraElectrodes.Name}));
sChannelMat.IntraElectrodes(iIntraElec).Type = 'ECOG';
sChannelMat.IntraElectrodes(iIntraElec).ContactNumber = [8 8];
sChannelMat.IntraElectrodes(iIntraElec).ContactSpacing  = 0.01;  % 10 mm
sChannelMat.IntraElectrodes(iIntraElec).ContactLength   = 0.001; %  1 mm
sChannelMat.IntraElectrodes(iIntraElec).ContactDiameter = 0.004; %  4 mm
% ECOG strips 'IHA', 'IHB' and 'IHC'
[~, iIntraElec] = ismember({'IHA', 'IHB', 'IHC'}, {sChannelMat.IntraElectrodes.Name});
[sChannelMat.IntraElectrodes(iIntraElec).Type] = deal('ECOG-mid');
[sChannelMat.IntraElectrodes(iIntraElec).ContactNumber]   = deal(4);
[sChannelMat.IntraElectrodes(iIntraElec).ContactSpacing]  = deal(0.01);  % 10 mm
[sChannelMat.IntraElectrodes(iIntraElec).ContactLength]   = deal(0.001); %  1 mm
[sChannelMat.IntraElectrodes(iIntraElec).ContactDiameter] = deal(0.004); %  4 mm
% SEEG electrodes 'TA' and 'TB'
% Change groups TA and TB to be type SEEG
iChSeeg = find(strcmp('TA', {sChannelMat.Channel.Group}) | strcmp('TB', {sChannelMat.Channel.Group}));
[sChannelMat.Channel(iChSeeg).Type] = deal('SEEG');
[~, iIntraElec] = ismember({'TA', 'TB'}, {sChannelMat.IntraElectrodes.Name});
[sChannelMat.IntraElectrodes(iIntraElec).Type] = deal('SEEG');
[sChannelMat.IntraElectrodes(iIntraElec).ContactNumber]   = deal(10);
[sChannelMat.IntraElectrodes(iIntraElec).ContactSpacing]  = deal(0.01);   %  10.0 mm
[sChannelMat.IntraElectrodes(iIntraElec).ContactLength]   = deal(0.0025); %   2.5 mm
[sChannelMat.IntraElectrodes(iIntraElec).ContactDiameter] = deal(0.001);  %   1.0 mm
[sChannelMat.IntraElectrodes(iIntraElec).ElecDiameter]    = deal(0.0009); %   0.9 mm
[sChannelMat.IntraElectrodes(iIntraElec).ElecLength]      = deal(0.120);  % 120.0 mm
% Save modified channel file
bst_save(file_fullpath(sFileRaw.ChannelFile), sChannelMat);
% === Edit the contacts positions ===
% Process: Add EEG positions
bst_process('CallProcess', 'process_channel_addloc', sFileRaw, [], ...
    'channelfile', {EegLocFile, 'BIDS-SCANRAS-MM'}, ...
    'usedefault',  '', ...
    'fixunits',    1, ...
    'vox2ras',     1, ...
    'mrifile',     {MriPostReg, 'BST'}, ...
    'fiducials',   []);
% Plot electrodes and open iEEG panel
[hFig, iDS, iFig] = view_channels_3d(sFileRaw.ChannelFile, 'ECOG+SEEG', 'cortex', 1);
bst_report('Snapshot', hFig, sFileRaw.ChannelFile, 'Before projecting ECOG grid on innerskull: ECOG');
% Project ECOG grid 'G' on innerskull surface
panel_ieeg('SetSelectedElectrodes', 'G');
panel_ieeg('ProjectContacts', iDS, iFig, 'innerskull');
bst_report('Snapshot', hFig, sFileRaw.ChannelFile, 'After projecting ECOG grid on innerskull: ECOG');
bst_memory('SaveChannelFile', iDS);
bst_memory('UnloadAll', 'Forced');


%% ===== 04: DISPLAY THE RECORDINGS ============================================
%  =============================================================================
disp([10 'DEMO> 04: Display the recordings' 10]);
% ECoG/sEEG time series
hFig = view_timeseries(sFileRaw.FileName, 'ECOG+SEEG');
% Set the current display mode to 'column'
bst_set('TSDisplayMode', 'column');
panel_record('SetTimeLength', 20);
panel_record('SetStartTime', 888);
panel_montage('SetCurrentMontage', hFig, 'ecog01: ECOG_SEEG (bipolar 1)[tmp]');
pause(0.5);
bst_report('Snapshot', hFig, sFileRaw.FileName, 'Time series: ECOG+SEEG');
close(hFig);

% 2D Layout
hFig2dL = view_topography(sFileRaw.FileName, 'ECOG+SEEG', '2DLayout');
panel_record('SetTimeLength',  2);
panel_record('SetStartTime', 888);
panel_time('SetCurrentTime', 889.6);

% 2D electrodes
hFig2dE = view_topography(sFileRaw.FileName, 'ECOG+SEEG', '2DElectrodes');

% 3D electrodes (MRI)
hFig3dE = view_topography(sFileRaw.FileName, 'ECOG+SEEG', '3DElectrodes-MRI');

% Project activity on cortex
sSubject = bst_get('Subject', SubjectName);
hFigCtx = view_surface_data(sSubject.Surface(sSubject.iCortex).FileName, sFileRaw.FileName, 'ECOG+SEEG');
% Project activity on MRI
% Set Maximum intensity projection (MIP) for projected data)
MriOptions = bst_get('MriOptions');
MriOptions.isMipFunctional = 1;
bst_set('MriOptions', MriOptions);
hFigMri = view_mri(sSubject.Anatomy(sSubject.iAnatomy).FileName, sFileRaw.FileName, 'ECOG+SEEG');

% Set colormap max to 'local' and range [-max,max]
ColormapInfo = getappdata(hFigCtx, 'Colormap');
bst_colormaps('SetMaxMode', ColormapInfo.Type, 'local', []);
bst_colormaps('SetColormapRealMin', ColormapInfo.Type, 0);

pause(0.5);
bst_report('Snapshot', hFig2dL, sFileRaw.FileName, '2D Layout: ECOG+SEEG');
bst_report('Snapshot', hFig2dE, sFileRaw.FileName, '2D Electrodes: ECOG+SEEG');
bst_report('Snapshot', hFig3dE, sFileRaw.FileName, '3D Electrodes: ECOG+SEEG');
bst_report('Snapshot', hFigCtx, sFileRaw.FileName, 'Interpolate on cortex: ECOG+SEEG');
bst_report('Snapshot', hFigMri, sFileRaw.FileName, 'Interpolate on MRI: ECOG+SEEG');
close([hFig2dL, hFig2dE, hFig3dE, hFigCtx, hFigMri]);
MriOptions.isMipFunctional = 0;
bst_set('MriOptions', MriOptions);

% Process: Power spectrum density (Welch)
sFilePsd = bst_process('CallProcess', 'process_psd', sFileRaw, [], ...
    'timewindow',  [], ...
    'win_length',  10, ...
    'win_overlap', 50, ...
    'units',       'physical', ...  % Physical: U2/Hz
    'sensortypes', 'ECOG, SEEG', ...
    'win_std',     0, ...
    'edit',        struct(...
         'Comment',         'Power', ...
         'TimeBands',       [], ...
         'Freqs',           [], ...
         'ClusterFuncTime', 'none', ...
         'Measure',         'power', ...
         'Output',          'all', ...
         'SaveKernel',      0));
% Spectrum figure
hFig = view_spectrum(sFilePsd.FileName);
sOptions = panel_display('GetDisplayOptions');
sOptions.Function = 'log';
panel_display('SetDisplayOptions', sOptions);
xlim(gca, [0, 40]);
pause(0.5);
bst_report('Snapshot', hFig, sFilePsd.FileName, 'Power spectrum (log): ECOG+SEEG');
close(hFig);


%% ===== 05: IMPORT EPOCHS =====================================================
%  =============================================================================
disp([10 'DEMO> 05: Import epochs' 10]);
% Process: Import MEG/EEG: Events
sFilesEpochs = bst_process('CallProcess', 'process_import_data_event', sFileRaw, [], ...
    'subjectname', SubjectName, ...
    'condition',   '', ...
    'eventname',   'seizure', ...
    'timewindow',  [], ...
    'epochtime',   [-10, 20], ...
    'createcond',  0, ...
    'ignoreshort', 1, ...
    'usectfcomp',  1, ...
    'usessp',      1, ...
    'freq',        [], ...
    'baseline',    []);
% TB SEEG electrode time series
hFig = view_timeseries(sFilesEpochs(1).FileName, 'ECOG+SEEG');
% Set the current display mode to 'column'
bst_set('TSDisplayMode', 'column');
panel_montage('SetCurrentMontage', hFig, 'ecog01: TB (bipolar 2)[tmp]');
pause(0.5);
bst_report('Snapshot', hFig, sFileRaw.FileName, 'Time series: electrode TB');
close(hFig);


%% ===== 06: ANATOMICAL LABELLING ==============================================
%  =============================================================================
disp([10 'DEMO> 06: Anatomical labelling' 10]);
TsvFile = bst_fullfile(fileparts(file_fullpath(sFileRaw.FileName)), 'anatomical_labelling.tsv');
export_channel_atlas(sFileRaw.ChannelFile, 'ECOG+SEEG', TsvFile, 3, 1, 0);
% View TSV file
T = readtable(TsvFile, 'FileType', 'text', 'Delimiter', '\t', 'ReadVariableNames', true);
jFrame = view_table(table2cell(T), T.Properties.VariableNames, 'sFileRaw.ChannelFile');
bst_report('Snapshot', jFrame, sFileRaw.ChannelFile, 'Anatomical labelling: ECOG+SEEG');
jFrame.dispose();


%% ===== SAVE REPORT =====
% Save and display report
ReportFile = bst_report('Save', []);
if ~isempty(reports_dir) && ~isempty(ReportFile)
    bst_report('Export', ReportFile, reports_dir);
else
    bst_report('Open', ReportFile);
end
disp([10 'DEMO> Done.' 10]);

