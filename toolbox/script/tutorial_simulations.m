function tutorial_simulations(tutorial_dir, reports_dir)
% TUTORIAL_SIMULATIONS: Script that reproduces the results of the online tutorial "Simulations".
%
% CORRESPONDING ONLINE TUTORIALS:
%     https://neuroimage.usc.edu/brainstorm/Tutorials/Simulations
%
% INPUTS: 
%    - tutorial_dir : Directory where the sample_epilepsy.zip file has been unzipped (NOT USED)
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
% Author: Francois Tadel, 2020


% ===== FILES TO IMPORT =====
% Output folder for reports
if (nargin < 2) || isempty(reports_dir) || ~isdir(reports_dir)
    reports_dir = [];
end

% ===== CREATE PROTOCOL =====
% The protocol name has to be a valid folder name (no spaces, no weird characters...)
ProtocolName = 'TutorialSimulation';
% Start brainstorm without the GUI
if ~brainstorm('status')
    brainstorm nogui
end
% Delete existing protocol
gui_brainstorm('DeleteProtocol', ProtocolName);
% Create new protocol
gui_brainstorm('CreateProtocol', ProtocolName, 1, 0);
% Start a new report
bst_report('Start');
% Create new subject
SubjectName = 'Simulation';
[sSubject, iSubject] = db_add_subject(SubjectName, [], 1, 0);
% Create new folder
FolderName = 'VolumeEEG';
iStudy = db_add_condition(SubjectName, FolderName);

% ===== EXAMPLE 3: VOLUME/UNCONSTRAINED =====

% === 3. FORWARD MODEL ===
% Get EEG template ICBM152/10-10 (65 channels)
eegTemplate = bst_get('EegDefaults', 'icbm152', '10-10 65');
% Set channel file for the simulation folder
ChannelFile = db_set_channel(iStudy, eegTemplate.contents.fullpath, 1, 0);
% Process: Compute head model
bst_process('CallProcess', 'process_headmodel', [], [], ...
    'Comment',     '', ...
    'sourcespace', 2, ...  % MRI volume
    'volumegrid',  struct(...
         'Method',        'isotropic', ...
         'nLayers',       17, ...
         'Reduction',     3, ...
         'nVerticesInit', 4000, ...
         'Resolution',    0.005, ...
         'FileName',      []), ...
    'meg',         1, ...  % 
    'eeg',         3, ...  % OpenMEEG BEM
    'ecog',        1, ...  % 
    'seeg',        1, ...  % 
    'openmeeg',    struct(...
         'BemFiles',     {{}}, ...
         'BemNames',     {{'Scalp', 'Skull', 'Brain'}}, ...
         'BemCond',      [1, 0.0125, 1], ...
         'BemSelect',    [1, 1, 1], ...
         'isAdjoint',    0, ...
         'isAdaptative', 1, ...
         'isSplit',      0, ...
         'SplitLength',  4000), ...
    'channelfile',  ChannelFile);
% Set identity noise covariance
import_noisecov(iStudy, 'Identity');

% === 3. CREATE SCOUT ===
% Load MRI file
sSubject = bst_get('Subject', iSubject);
sMri = in_mri_bst(sSubject.Anatomy(1).FileName);
% Load head model file
sStudy = bst_get('Study', iStudy);
HeadModelFile = sStudy.HeadModel(1).FileName;
HeadModelMat = in_bst_headmodel(HeadModelFile, 0, 'GridLoc');

% Convert grid locations to MNI coordinates
GridLocMni = cs_convert(sMri, 'scs', 'mni', HeadModelMat.GridLoc);
% Find closest grid point to a target MNI point
MniTarget = [-48, -1, -5];
[dist, iVertex] = min(sqrt(sum(bst_bsxfun(@minus, GridLocMni, MniTarget./1000).^2,2)));

% Create new scout structure
DipoleName = 'dip1';
sScout = db_template('scout');
sScout.Vertices = iVertex;
sScout.Seed = iVertex;
sScout.Color = [0 1 0];
sScout.Label = DipoleName;
sScout.Region = 'LT';
% Load cortex surface
TessFile = file_fullpath(sSubject.Surface(sSubject.iCortex).FileName);
TessMat = in_tess_bst(TessFile);
% Get or create a volume atlas and add scout to it
AtlasName = sprintf('Volume %d', size(HeadModelMat.GridLoc,1));
iAtlas = find(strcmpi({TessMat.Atlas.Name}, AtlasName));
if isempty(iAtlas)
    iAtlas = length(TessMat.Atlas) + 1;
end
TessMat.Atlas(iAtlas).Name = AtlasName;
TessMat.Atlas(iAtlas).Scouts = sScout;
TessMat.iAtlas = iAtlas;
% Update cortex surface
bst_save(TessFile, TessMat, 'v7');

% === 3. SIMULATE SIGNALS ===
% Dipole X: (1,0,0)
% Process: Simulate generic signals
sFilesMatrixX = bst_process('CallProcess', 'process_simulate_matrix', [], [], ...
    'subjectname', SubjectName, ...
    'condition',   FolderName, ...
    'samples',     600, ...
    'srate',       600, ...
    'matlab',      ['Data(1,:) = sin(2*pi*t);' 10 'Data(2,:) = 0 * t;' 10 'Data(3,:) = 0 * t;']);
% Process: Set name: Simulated X
sFilesMatrixX = bst_process('CallProcess', 'process_set_comment', sFilesMatrixX, [], ...
    'tag',           'Simulated X', ...
    'isindex',       1);

% Dipole Y: (0,1,0)
% Process: Simulate generic signals
sFilesMatrixY = bst_process('CallProcess', 'process_simulate_matrix', [], [], ...
    'subjectname', SubjectName, ...
    'condition',   FolderName, ...
    'samples',     600, ...
    'srate',       600, ...
    'matlab',      ['Data(1,:) = 0 * t;' 10 'Data(2,:) = sin(2*pi*t);' 10 'Data(3,:) = 0 * t;']);
% Process: Set name: Simulated X
sFilesMatrixY = bst_process('CallProcess', 'process_set_comment', sFilesMatrixY, [], ...
    'tag',           'Simulated Y', ...
    'isindex',       1);

% Dipole Z: (0,0,1)
% Process: Simulate generic signals
sFilesMatrixZ = bst_process('CallProcess', 'process_simulate_matrix', [], [], ...
    'subjectname', SubjectName, ...
    'condition',   FolderName, ...
    'samples',     600, ...
    'srate',       600, ...
    'matlab',      ['Data(1,:) = 0 * t;' 10 'Data(2,:) = 0 * t;' 10 'Data(3,:) = sin(2*pi*t);']);
% Process: Set name: Simulated X
sFilesMatrixZ = bst_process('CallProcess', 'process_set_comment', sFilesMatrixZ, [], ...
    'tag',           'Simulated Z', ...
    'isindex',       1);

% === 3. SIMULATE EEG ===
% Process: Simulate recordings from scouts
sFilesRec = bst_process('CallProcess', 'process_simulate_recordings', [sFilesMatrixX, sFilesMatrixY, sFilesMatrixZ], [], ...
    'scouts',      {AtlasName, {DipoleName}}, ...
    'savedata',    1, ...
    'savesources', 1, ...
    'isnoise',     1, ...
    'noise1',      0.01, ...
    'noise2',      0.01);

% === 3. SCREEN CAPTURES ===
% Process: Snapshot: Sensors/MRI registration
bst_process('CallProcess', 'process_snapshot', sFilesRec(1), [], ...
    'target',         1, ...  % Sensors/MRI registration
    'modality',       4, ...  % EEG
    'orient',         1, ...  % left
    'Comment',        '10-10 electrode cap, 65 electrodes');
% Process: Snapshot: Recordings time series
bst_process('CallProcess', 'process_snapshot', sFilesRec, [], ...
    'target',         5, ...  % Recordings time series
    'modality',       4, ...  % EEG
    'time',           0.223, ...
    'Comment',        '');
% Process: Snapshot: Recordings topography (one time)
bst_process('CallProcess', 'process_snapshot', sFilesRec, [], ...
    'target',         6, ...  % Recordings topography (one time)
    'modality',       4, ...  % EEG
    'time',           0.223, ...
    'Comment',        '');


% ===== EXAMPLE 4: SINGLE DIPOLES =====
% Create new folder
FolderName = 'Dipoles';
iStudy = db_add_condition(SubjectName, FolderName);
% Get EEG template ICBM152/10-10 (65 channels)
eegTemplate = bst_get('EegDefaults', 'icbm152', '10-10 65');
% Set channel file for the simulation folder
db_set_channel(iStudy, eegTemplate.contents.fullpath, 1, 0);
% Set identity noise covariance
import_noisecov(iStudy, 'Identity');

% Process: Simulate generic signals
sFileSim = bst_process('CallProcess', 'process_simulate_matrix', [], [], ...
    'subjectname', SubjectName, ...
    'condition',   FolderName, ...
    'samples',     600, ...
    'srate',       600, ...
    'matlab',      ['Data(1,:) = sin(2*pi*t);' 10 'Data(2,:) = sin(2*pi*t + pi/4);']);
% Process: Set name: Simulated bilateral
sFileSim = bst_process('CallProcess', 'process_set_comment', sFileSim, [], ...
    'tag',           'Simulated bilateral', ...
    'isindex',       0);
% Process: Simulate recordings from dipoles
sFileEeg = bst_process('CallProcess', 'process_simulate_dipoles', sFileSim, [], ...
    'dipoles',  ['-48, -2, -4, 0.2, 1, 0' 10 '48, -2, -4, -0.2, 1, 0'], ...
    'cs',       'mni', ...  % MNI
    'meg',      {''}, ...  % 
    'eeg',      {'openmeeg'}, ...  % OpenMEEG BEM
    'ecog',     {''}, ...  % 
    'seeg',     {''}, ...  % 
    'openmeeg', struct(...
         'BemFiles',     {{}}, ...
         'BemNames',     {{'Scalp', 'Skull', 'Brain'}}, ...
         'BemCond',      [1, 0.0125, 1], ...
         'BemSelect',    [1, 1, 1], ...
         'isAdjoint',    0, ...
         'isAdaptative', 1, ...
         'isSplit',      0, ...
         'SplitLength',  4000), ...
    'isnoise',  1, ...
    'noise1',   0.1, ...
    'noise2',   0.5, ...
    'savedip',  1, ...
    'savedata', 1);

% Process: Snapshot: Recordings time series
bst_process('CallProcess', 'process_snapshot', sFileSim, [], ...
    'target',         5, ...  % Recordings time series
    'time',           0);
% Process: Snapshot: Recordings time series
bst_process('CallProcess', 'process_snapshot', sFileEeg, [], ...
    'target',         5, ...  % Recordings time series
    'modality',       4, ...  % EEG
    'time',           0);
% Process: Snapshot: Recordings topography (contact sheet)
bst_process('CallProcess', 'process_snapshot', sFileEeg, [], ...
    'target',         7, ...  % Recordings topography (contact sheet)
    'modality',       4, ...  % EEG
    'contact_time',   [0, 0.998], ...
    'contact_nimage', 12);

% Process: Select files using search query
sFileDip = bst_process('CallProcess', 'process_select_search', [], [], ...
    'search', '([type EQUALS "Dipoles"])');
% Display dipoles
hFig = view_dipoles(sFileDip.FileName, 'mri3d');
figure_3d('SetStandardView', hFig, 'top');
bst_report('Snapshot', hFig, sFileDip.FileName, 'Two dipoles: MNI(-48,-2,-4) and MNI(+48,-2,-4)', [200, 200, 640, 400]);
figure_3d('SetStandardView', hFig, 'left');
bst_report('Snapshot', hFig, sFileDip.FileName, 'Two dipoles: MNI(-48,-2,-4) and MNI(+48,-2,-4)', [200, 200, 640, 400]);
close(hFig);


% ===== SAVE REPORT =====
% Save and display report
ReportFile = bst_report('Save', []);
if ~isempty(reports_dir) && ~isempty(ReportFile)
    bst_report('Export', ReportFile, reports_dir);
else
    bst_report('Open', ReportFile);
end

disp([10 'BST> tutorial_simulations: Done.' 10]);

