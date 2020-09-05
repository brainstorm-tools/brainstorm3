function tutorial_ctf(tutorial_dir)
% TUTORIAL_CTF: Run all the scripts related to tutorial CTF.
%
% CORRESPONDING ONLINE TUTORIALS:
%     https://neuroimage.usc.edu/brainstorm/Tutorials/TutImportAnatomy
%     https://neuroimage.usc.edu/brainstorm/Tutorials/TutImportRecordings
%     https://neuroimage.usc.edu/brainstorm/Tutorials/TutExploreRecodings
%     https://neuroimage.usc.edu/brainstorm/Tutorials/TutHeadModel
%     https://neuroimage.usc.edu/brainstorm/Tutorials/TutNoiseCov
%     https://neuroimage.usc.edu/brainstorm/Tutorials/TutSourceEstimation
%
% INPUTS: 
%     tutorial_dir: Directory where the sample_ctf.zip file has been unzipped

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
% Authors: Francois Tadel, 2010-2014


% ===== FILES TO IMPORT =====
% You have to specify the folder in which the tutorial dataset is unzipped
if (nargin == 0) || isempty(tutorial_dir) || ~file_exist(tutorial_dir)
    error('The first argument must be the full path to the tutorial dataset folder.');
end
% Build the path of the files to import
MriFile       = fullfile(tutorial_dir, 'sample_ctf', 'Anatomy', 'nobias_01.nii');
SurfFileHead  = fullfile(tutorial_dir, 'sample_ctf', 'Anatomy', 'BrainVisa', '01_head.mesh');
SurfFileLhemi = fullfile(tutorial_dir, 'sample_ctf', 'Anatomy', 'BrainVisa', '01_Lhemi.mesh');
SurfFileRhemi = fullfile(tutorial_dir, 'sample_ctf', 'Anatomy', 'BrainVisa', '01_Rhemi.mesh');
DsFileRight   = fullfile(tutorial_dir, 'sample_ctf', 'Data', 'somMDYO-18av.ds');
DsFileLeft    = fullfile(tutorial_dir, 'sample_ctf', 'Data', 'somMGYO-18av.ds');
% Check if the folder contains the required files
if ~file_exist(DsFileRight)
    error(['The folder ' tutorial_dir ' does not contain the folder from the file sample_ctf.zip.']);
end

% ===== CREATE PROTOCOL =====
% The protocol name has to be a valid folder name (no spaces, no weird characters...)
ProtocolName = 'TutorialCTF';
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


%% ===== TUTORIAL #3: IMPORT ANATOMY =====
% Subject name
SubjectName = 'Subject01';
% Process: Import MRI
bst_process('CallProcess', 'process_import_mri', [], [], ...
    'subjectname', SubjectName, ...
    'mrifile',     {MriFile}, ...
    'nas',         [115.3, 207.2, 138.8], ...
    'lpa',         [45.9, 128.4, 71.3], ...
    'rpa',         [186.6, 123.8, 83.4], ...
    'ac',          [115.3, 130.3, 132.2], ...
    'pc',          [115.3, 102.2, 133.1], ...
    'ih',          [113.4, 109.7, 184.7]);

% Process: Import surfaces
bst_process('CallProcess', 'process_import_surfaces', [], [], ...
    'subjectname', SubjectName, ...
    'headfile',    {SurfFileHead, 'MESH'}, ...
    'cortexfile1', {SurfFileLhemi, 'MESH'}, ...
    'cortexfile2', {SurfFileRhemi, 'MESH'}, ...
    'nverthead',   7000, ...
    'nvertcortex', 15000);

% ===== DISPLAY ANATOMY =====
% Get subject definition
sSubject = bst_get('Subject', SubjectName);
% Get MRI file and surface files
MriFile    = sSubject.Anatomy(sSubject.iAnatomy).FileName;
CortexFile = sSubject.Surface(sSubject.iCortex).FileName;
HeadFile   = sSubject.Surface(sSubject.iScalp).FileName;
% Display MRI
hFigMri1 = view_mri(MriFile);
hFigMri3 = view_mri_3d(MriFile, [], [], 'NewFigure');
hFigMri2 = view_mri_slices(MriFile, 'x', 20); 
% Close figures
close([hFigMri1 hFigMri2 hFigMri3]);
% Display scalp and cortex
hFigSurf = view_surface(HeadFile);
hFigSurf = view_surface(CortexFile, [], [], hFigSurf);
hFigMriSurf = view_mri(MriFile, CortexFile);
close([hFigSurf hFigMriSurf]);


%% ===== TUTORIAL #4: IMPORT THE RECORDINGS =====
% Process: Import MEG/EEG: Epochs (Right)
sFilesRight = bst_process('CallProcess',  'process_import_data_epoch', [], [], ...
    'datafile',     {DsFileRight, 'CTF'}, ...
    'subjectname',  SubjectName, ...
    'condition',    'Right', ...
    'iepochs',      [], ...   % Import all the epochs
    'createcond',   0, ...
    'channelalign', 1, ...
    'usectfcomp',   1, ...
    'usessp',       1, ...
    'baseline',     [-0.050, -0.008], ...  % Remove baseline: [-50ms,-1ms]
    'freq',         []);
% Process: Import MEG/EEG: Epochs (Left)
sFilesLeft = bst_process('CallProcess',  'process_import_data_epoch', [], [], ...
    'datafile',     {DsFileLeft, 'CTF'}, ...
    'subjectname',  SubjectName, ...
    'condition',    'Left', ...
    'iepochs',      [], ...   % Import all the epochs
    'createcond',   0, ...
    'channelalign', 1, ...
    'usectfcomp',   1, ...
    'usessp',       1, ...
    'baseline',     [-0.050, -0.008], ...  % Remove baseline: [-50ms,-1ms]
    'freq',         []);
% Get the averages (first epoch  of each dataset)
sFilesAvg = [sFilesRight(1), sFilesLeft(1)];

% Process: Snapshot: Sensors/MRI registration
bst_process('CallProcess', 'process_snapshot', sFilesAvg, [], ...
    'target',   1, ...  % Sensors/MRI registration
    'modality', 1, ...  % MEG (All)
    'orient',   1, ...  % left
    'Comment',  'MEG/MRI Registration');

% Process: Snapshot: Recordings time series
bst_process('CallProcess', 'process_snapshot', sFilesAvg, [], ...
    'target',   5, ...  % Recordings time series
    'modality', 1, ...  % MEG (All)
    'Comment',  'Evoked response');

% Process: Snapshot: Recordings topography (contact sheet)
bst_process('CallProcess', 'process_snapshot', sFilesRight(1), [], ...
    'target',   7, ...  % Recordings topography (contact sheet)
    'modality', 1, ...  % MEG
    'orient',   1, ...  % left
    'contact_time',   [0, 0.120], ...
    'contact_nimage', 16, ...
    'Comment',  'Evoked response (Right)');



% ===== GET FILES IN DATABASE =====
% Get the first data file in the Right condition
DataFile = sFilesRight(1).FileName;
% Other alternative to get the same file name, using database requests
[sStudy, iStudy] = bst_get('StudyWithCondition', 'Subject01/Right');
DataFile = sStudy.Data(1).FileName;
% Get channel file for a data file
ChannelFile = bst_get('ChannelFileForStudy', DataFile);
% Alternative: Get it from the sStudy structure
ChannelFile = sStudy.Channel.FileName;

% ===== VIEW SENSORS =====
% View sensors
hFig = view_surface(HeadFile);
hFig = view_channels(ChannelFile, 'MEG', 1, 1, hFig);
% Hide sensors
pause(0.5);
hFig = view_channels(ChannelFile, 'MEG', 0, 0, hFig);
% View coils
hFig = view_channels(ChannelFile, 'CTF', 1, 1, hFig);
% View helmet
pause(1);
hFig = view_helmet(ChannelFile, hFig);
close(hFig);


%% ===== TUTORIAL #5: EXPLORE THE RECORDINGS =====
% Display MEG time series
[hFigTs, iDS, iFig] = view_timeseries(DataFile, 'MEG');
% Display MEG topographies
hFigTp1 = view_topography(DataFile, 'MEG', '2DSensorCap');
hFigTp2 = view_topography(DataFile, 'MEG', '3DSensorCap');
hFigTp3 = view_topography(DataFile, 'MEG', '2DDisc');
hFigTp4 = view_topography(DataFile, 'MEG', '2DLayout');
% Display time contact sheet for a figure
hContactFig = view_contactsheet( hFigTp1, 'time', 'fig', [], 12, [0 0.120] );
pause(0.5);
close(hContactFig);
% Set current time to 46ms
panel_time('SetCurrentTime', 0.046);

% ===== MANIPULATE CHANNELS =====
SelectedChannels = {'MLC31', 'MLC32'};
% Set sensors selection
bst_figures('SetSelectedRows', SelectedChannels);
% View selection in a separated window
view_timeseries(DataFile, [], SelectedChannels);
% Show sensors on 2DSensorCap topography
isMarkers = 1;
isLabels = 0;
figure_3d('ViewSensors', hFigTp1, isMarkers, isLabels);

% ===== COLORMAP =====
ColormapType = 'meg';
% Set 'Meg' colormap to 'jet'
bst_colormaps('SetColormapName', ColormapType, 'jet');
pause(0.5);
% Set 'Meg' colormap to 'rwb'
bst_colormaps('SetColormapName', ColormapType, 'cmap_rbw');
% Set colormap to display absolute values
bst_colormaps('SetColormapAbsolute', ColormapType, 1);
% Normalize colormap for each time frame
bst_colormaps('SetMaxMode', ColormapType, 'local');
% Hide colorbar
bst_colormaps('SetDisplayColorbar', ColormapType, 0);
pause(0.5);
% Restore colormap to default values
bst_colormaps('RestoreDefaults', ColormapType);
% Edit good/bad channel for current file
gui_edit_channelflag(DataFile);
% Unload everything
bst_memory('UnloadAll', 'Forced');



%% ===== TUTORIAL #6: HEADMODEL =====
% Process: Compute head model
bst_process('CallProcess', 'process_headmodel', sFilesAvg, [], ...
    'comment',      '', ...
    'sourcespace',  1, ...
    'meg',          3);  % Overlapping spheres

% Process: Snapshot: Headmodel spheres
sFiles = bst_process('CallProcess', 'process_snapshot', sFilesRight(1), [], ...
    'target',   4, ...  % Headmodel spheres
    'modality', 1, ...  % MEG (All)
    'orient',   1, ...  % left
    'Comment', 'Overlapping spheres');


%% ===== TUTORIAL #7: HEADMODEL =====
% Process: Compute noise covariance
bst_process('CallProcess', 'process_noisecov', sFilesAvg, [], ...
    'baseline', [-0.050, 0.008], ...
    'dcoffset', 1, ...
    'identity', 0, ...
    'copycond', 0, ...
    'copysubj', 0);

% Process: Snapshot: Noise covariance
bst_process('CallProcess', 'process_snapshot', sFilesRight(1), [], ...
    'target',  3, ...  % Noise covariance
    'Comment', 'Noise covariance');


%% ===== TUTORIAL #8: SOURCES =====
% Process: Compute sources
sFilesSrc = bst_process('CallProcess', 'process_inverse', sFilesAvg, [], ...
    'comment', '', ...
    'method',  1, ...  % Minimum norm estimates (wMNE)
    'wmne',    struct(...
         'NoiseCov',      [], ...
         'InverseMethod', 'wmne', ...
         'ChannelTypes',  {{}}, ...
         'SNR',           3, ...
         'diagnoise',     0, ...
         'SourceOrient',  {{'fixed'}}, ...
         'loose',         0.2, ...
         'depth',         1, ...
         'weightexp',     0.5, ...
         'weightlimit',   10, ...
         'regnoise',      1, ...
         'magreg',        0.1, ...
         'gradreg',       0.1, ...
         'eegreg',        0.1, ...
         'ecogreg',       0.1, ...
         'seegreg',       0.1, ...
         'fMRI',          [], ...
         'fMRIthresh',    [], ...
         'fMRIoff',       0.1, ...
         'pca',           1), ...
    'sensortypes', 'MEG', ...
    'output',      2);  % Kernel only: one per file

% Process: Snapshot: Sources (one time)
bst_process('CallProcess', 'process_snapshot', sFilesSrc, [], ...
    'target',   8, ...  % Sources (one time)
    'modality', 1, ...  % MEG (All)
    'orient',   3, ...  % top
    'time',     0.046, ...
    'Comment',  'Source maps at 46ms');


% ===== DISPLAY SOURCES MANUALLY =====
% View on the cortex surface
hFig1 = script_view_sources(sFilesSrc(1).FileName, 'cortex');
% Set current time to 46ms
panel_time('SetCurrentTime', 0.046);
% Set surface threshold to 75% of the maximal value
iSurf = 1;
thresh = .75; 
panel_surface('SetDataThreshold', hFig1, iSurf, thresh);
% Set surface smoothing
panel_surface('SetSurfaceSmooth', hFig1, iSurf, .4, 0);
% Show sulci
panel_surface('SetShowSulci', hFig1, iSurf, 1);

% View sources on MRI (3D orthogonal slices)
hFig2 = script_view_sources(sFilesSrc(1).FileName, 'mri3d');
panel_surface('SetDataThreshold', hFig2, iSurf, thresh);
% Set the position of the cuts in the 3D figure
cutsPosMri = [66.6 99.4 167.8] ./ 1000;
cutsPosVox = round(cutsPosMri ./ .9375 .* 1000);
panel_surface('PlotMri', hFig2, cutsPosVox);

% View sources with MRI Viewer
hFig3 = script_view_sources(sFilesSrc(1).FileName, 'mriviewer');
panel_surface('SetDataThreshold', hFig3, iSurf, thresh);
% Set the position of the cuts in the MRI Viewer (values in millimeters)
figure_mri('SetLocation', 'mri', hFig3, [], cutsPosMri);
% Close figures
close([hFig1 hFig2 hFig3]);


% Save and display report
ReportFile = bst_report('Save', sFilesSrc);
bst_report('Open', ReportFile);





