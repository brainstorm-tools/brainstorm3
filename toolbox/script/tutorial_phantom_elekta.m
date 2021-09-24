function tutorial_phantom_elekta(tutorial_dir)
% TUTORIAL_PHANTOM_ELEKTA: Script that runs the tests for the Elekta phantom.
%
% CORRESPONDING ONLINE TUTORIAL:
%     https://neuroimage.usc.edu/brainstorm/Tutorials/PhantomElekta
%
% INPUTS: 
%     tutorial_dir: Directory where the sample_phantom.zip file has been unzipped

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
% Author: Ken Taylor, John C Mosher, Francois Tadel, 2016

% ===== FILES TO IMPORT =====
% Does the sample folder exist
if ~exist(sprintf('%s',fullfile(tutorial_dir,'sample_phantom_elekta')),'dir'),
    error(sprintf('Missing ''sample_phantom_elekta'' folder in the tutorial directory ''%s''',tutorial_dir));
end
% Build the path of the files to import
FifFile{1} = fullfile(tutorial_dir, 'sample_phantom_elekta', 'kojak_all_2000nAm_pp_no_chpi_no_ms_raw.fif');
FifFile{2} = fullfile(tutorial_dir, 'sample_phantom_elekta', 'kojak_all_200nAm_pp_no_chpi_no_ms_raw.fif');
FifFile{3} = fullfile(tutorial_dir, 'sample_phantom_elekta', 'kojak_all_20nAm_pp_no_chpi_no_ms_raw.fif');
% Select which file is processed with this script: 1=2000nAm, 2=200nAm, 3=20nAm
iFile = 2;
% Check if the folder contains the required files
if ~file_exist(FifFile{iFile})
    error(['The folder ' tutorial_dir ' does not contain the folder from the file sample_phantom_elekta.zip.']);
end


% ===== CREATE PROTOCOL =====
% The protocol name has to be a valid folder name (no spaces, no weird characters...)
ProtocolName = 'TutorialPhantomElekta';
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


% ===== ANATOMY =====
% Subject name
SubjectName = 'Kojak';
% Generate the phantom anatomy
DipTrueFile = generate_phantom_elekta(SubjectName);

% ===== LINK CONTINUOUS FILES =====
% Process: Create link to raw files
sFilesKojak = bst_process('CallProcess', 'process_import_data_raw', [], [], ...
    'subjectname',  SubjectName, ...
    'datafile',     {FifFile{iFile}, 'FIF'}, ...
    'channelalign', 0);

% ===== READ EVENTS =====
% Process: Read from channel
bst_process('CallProcess', 'process_evt_read', sFilesKojak, [], ...
    'stimchan',  'STI201', ...
    'trackmode', 1, ...  % Value: detect the changes of channel value
    'zero',      0);
% Process: Delete spurious other events unrelated to dipoles
bst_process('CallProcess', 'process_evt_delete', sFilesKojak, [], ...
    'eventname', '256, 768, 1792, 3840, 4096, 6144, 7168, 7680, 7936');
% Process: Rename events to have a leading zero, for proper sorting
for i = 1:9
    bst_process('CallProcess', 'process_evt_rename', sFilesKojak, [], ...
        'src',  sprintf('%.0f',i), ...
        'dest', sprintf('%02.0f',i));
end
% Delete the first event of the first category (there is always an artifact)
LinkFile = file_fullpath(sFilesKojak(1).FileName);
LinkMat = load(LinkFile, 'F');
if ~isempty(LinkMat.F.events) && ~isempty(LinkMat.F.events(1).times)
    LinkMat.F.events(1).times(1)   = [];
    LinkMat.F.events(1).epochs(1)  = [];
    LinkMat.F.events(1).channels(1)= [];
    LinkMat.F.events(1).notes(1)   = [];
end
bst_save(LinkFile, LinkMat, 'v6', 1);

% ===== IMPORT EVENTS =====
% Process: Import MEG/EEG: Events
%          DC offset correction: [-100ms,-10ms]
%          Resample: 100Hz
sFilesEpochs = bst_process('CallProcess', 'process_import_data_event', sFilesKojak, [], ...
    'subjectname', SubjectName, ...
    'condition',   '', ...
    'eventname',   ['01' sprintf(',%02.0f',2:32)], ...
    'timewindow',  [], ...
    'epochtime',   [-0.1, 0.3], ...
    'createcond',  0, ...
    'ignoreshort', 1, ...
    'usectfcomp',  0, ...
    'usessp',      0, ...
    'freq',        100, ...
    'baseline',    [-0.1, -0.001]);

% Process: Average: By trial group (folder average)
sAvgKojak = bst_process('CallProcess', 'process_average', sFilesEpochs, [], ...
    'avgtype',    5, ...  % By trial group (folder average)
    'avg_func',   1, ...  % Arithmetic average:  mean(x)
    'weighted',   0, ...
    'keepevents', 0);

% ===== SOURCE ESTIMATION =====
% Process: Compute covariance (noise or data)
bst_process('CallProcess', 'process_noisecov', sFilesEpochs, [], ...
    'baseline',       [-0.1, -0.01], ...
    'datatimewindow', [0, 0.3], ...
    'sensortypes',    'MEG', ...
    'target',         1, ...  % Noise covariance     (covariance over baseline time window)
    'dcoffset',       1, ...  % Block by block, to avoid effects of slow shifts in data
    'identity',       0, ...
    'copycond',       0, ...
    'copysubj',       0, ...
    'replacefile',    1);  % Replace
% Process: Compute head model
bst_process('CallProcess', 'process_headmodel', sAvgKojak, [], ...
    'Comment',     '', ...
    'sourcespace', 2, ...  % MRI volume
    'meg',         3, ...  % Overlapping spheres
    'volumegrid',  struct(...
         'Method',        'isotropic', ...
         'nLayers',       17, ...
         'Reduction',     3, ...
         'nVerticesInit', 4000, ...
         'Resolution',    0.0025, ...
         'FileName',      []));
% Process: Compute sources [2018]
sAvgSrcKojak = bst_process('CallProcess', 'process_inverse_2018', sAvgKojak, [], ...
    'output',  1, ...  % Kernel only: shared
    'inverse', struct(...
         'Comment', 'Dipoles: MEG GRAD', ...
         'InverseMethod', 'gls', ...
         'InverseMeasure', 'performance', ...
         'SourceOrient', {{'free'}}, ...
         'Loose', 0.2, ...
         'UseDepth', 0, ...
         'WeightExp', 0.5, ...
         'WeightLimit', 10, ...
         'NoiseMethod', 'none', ...
         'NoiseReg', 0.1, ...
         'SnrMethod', 'rms', ...
         'SnrRms', 0, ...
         'SnrFixed', 3, ...
         'ComputeKernel', 1, ...
         'DataTypes', {{'MEG GRAD'}}));
     
 % ===== DIPOLE SCANNING =====
% Process: Dipole scanning
sDipScan = bst_process('CallProcess', 'process_dipole_scanning', sAvgSrcKojak, [], ...
    'timewindow', [0.06, 0.06], ...
    'scouts',     {});
% Merge all 32 dipoles together
DipMergeFile = dipoles_merge({sDipScan.FileName});

% Flip orientations
dip = load(DipMergeFile);
for i = 1:32
    dip.Dipole(i).Amplitude = dip.Dipole(i).Amplitude * sign(dip.Dipole(i).Amplitude(3));
end
dip.Comment = [dip.Comment ' | flipped'];
DipFlipFile = db_add(sDipScan(1).iStudy, dip);

% Merge with true locations
DipAllFile = dipoles_merge({DipTrueFile, DipFlipFile});
% visualize on the MRI 3D
view_dipoles(DipAllFile, 'Mri3D');


% ===== REPORT =====
% Get the True Dipole Locations
TrueDipoles = load(file_fullpath(DipTrueFile));
true_loc    = [TrueDipoles.Dipole.Loc];
true_orient = [TrueDipoles.Dipole.Amplitude];

% Display stats
fprintf('\n Dipole stats\n\n')
fprintf(' Dipole      Loc (mm)      Amp (nA-m)  Gof     Perf       Chi2     RChi2\n')
fprintf('--------------------------------------------------------------------------\n')
for i = 1:32
    fprintf('  %02.0f - [%5.1f %5.1f %5.1f]   %5.1f   %5.1f%%    %5.1f  %5.0f (%3.0f)   %.2f\n',...
        i, dip.Dipole(i).Loc*1000, norm(dip.Dipole(i).Amplitude)*1e9, ...
        dip.Dipole(i).Goodness*100, dip.Dipole(i).Perform, ...
        dip.Dipole(i).Khi2, dip.Dipole(i).DOF, dip.Dipole(i).Khi2/dip.Dipole(i).DOF),
end

% Compare errors, but dependent on order being correct
fprintf('\n Location errors from true\n\n')
fprintf(' Dipole      Loc (mm)            True (mm)         Diff [x y z]     Norm (mm)\n')
fprintf('------------------------------------------------------------------------------\n')
for i = 1:32
    temp_diff = dip.Dipole(i).Loc-true_loc(:,i);
    fprintf('  %02.0f - [%5.1f %5.1f %5.1f] [%5.1f %5.1f %5.1f] [%5.1f %5.1f %5.1f]   (%5.1f)\n',...
        i, dip.Dipole(i).Loc*1000, true_loc(:,i)*1000, temp_diff*1000, norm(temp_diff)*1000);
end

% Orientation errors
fprintf('\n Orientation errors from true\n\n')
fprintf(' Dipole  Amp (nA-m)      [X Y Z]              TRUE [X Y Z]     Degrees\n')
fprintf('------------------------------------------------------------------------\n')
for i = 1:32
    Amp    = dip.Dipole(i).Amplitude; 
    nAmp   = norm(Amp); 
    Orient = Amp / nAmp;
    fprintf('  %02.0f -    (%5.1f)  [%5.2f %5.2f %5.2f] vs [%5.2f %5.2f %5.2f] (%5.1f )\n',...
        i, nAmp*1e9, Orient, true_orient(:,i), (subspace(Orient,true_orient(:,i)))*180/pi);
end

% Save and display report
ReportFile = bst_report('Save', []);
bst_report('Open', ReportFile);











