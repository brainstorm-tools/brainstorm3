% function tutorial_phantom_elekta_lcmv(tutorial_dir)
% TUTORIAL_PHANTOM_ELEKTA_LCMV: Script that runs the tests for the Elekta phantom (Mosher's LCMV validation).
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

%% ========= Parameters ===========
% The important criteria for CAPON is the data included in
% the data covariance calculation. We will test various sets of data for
% use in this calculation

DipNdx = [1:4:32]; % targeted dipoles for testing
% for smaller set used for data covariance calculations
RefDip = [5 13 17 25]; % widely separated and shallow in each quad
% RefDip = [4 12 20 28]; % widely separated and deep in each quad

DipNdx = sort(DipNdx); % other brainstorm routines end up sorting the index, so ensure


% pick one:
%SUBARRAY = 'MEG'; % all sensors
SUBARRAY = 'MEG GRAD';
%SUBARRAY = 'MEG MAG';

% Set the noise and data covariance intervals
Baseline = [-0.1 -0.01];
DataWindow = [0 .150];
sampling_rate = 100; % phantom data is collected at 1000 fs, can resample here
% epochs will be collected from beginning of baseline to end of data window

%% ===== FILES TO IMPORT =====

if ~exist('tutorial_dir','var'),
    tutorial_dir = '/Users/mosher'; % default
end

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
    error(['The folder ' tutorial_dir ' does not contain the data from the file sample_phantom_elekta.zip.']);
end

%%  ===== CREATE PROTOCOL =====
% The protocol name has to be a valid folder name (no spaces, no weird characters...)
ProtocolName = sprintf('TutorialPhantomElekta_LCMV_%.0f',iFile);

% Subject name
SubjectName = 'Kojak';

% Start brainstorm without the GUI
if ~brainstorm('status')
    brainstorm nogui
end
% Delete existing protocol

iProtocol = bst_get('Protocol', ProtocolName);
% If protocol exists
YorN = 'n'; % default to delete an existing protocol

if false, % only if we care to delete
    if ~isempty(iProtocol)
        % Set as current protocol
        gui_brainstorm('SetCurrentProtocol', iProtocol)
        
        YorN = input(sprintf('Protocol %s already exists, delete and rebuild (y/n): ',ProtocolName),'s');
        
    end
end

if isempty(iProtocol) || strncmp(YorN,'y',1),
    % build protocol
    
    if strncmp(YorN,'y',1), % first delete it
        gui_brainstorm('DeleteProtocol', ProtocolName);
    end
    
    % Create new protocol
    gui_brainstorm('CreateProtocol', ProtocolName, 0, 0);
    
    % ===== ANATOMY =====
    
    % Generate the phantom anatomy
    DipTrueFile = generate_phantom_elekta(SubjectName);
    
else
    % or whatever the true name is from previous run
    DipTrueFile = fullfile(SubjectName,'TrueDipoles','dipoles_160816_1755.mat');
    
end

% Start a new report
% bst_report('Start');


%% ===== LINK CONTINUOUS FILES =====
% Process: Create link to raw files
sFilesKojak = bst_process('CallProcess', 'process_import_data_raw', [], [], ...
    'subjectname',  SubjectName, ...
    'datafile',     {FifFile{iFile}, 'FIF'}, ...
    'channelalign', 0);

%% ===== READ EVENTS =====
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

%%  ===== IMPORT EVENTS =====
% Process: Import MEG/EEG: Events
%          DC offset correction: [-100ms,-10ms]
%          Resample: 100Hz
sFilesEpochs = bst_process('CallProcess', 'process_import_data_event', sFilesKojak, [], ...
    'subjectname', SubjectName, ...
    'condition',   '', ...
    'eventname',   ['01' sprintf(',%02.0f',2:32)], ...
    'timewindow',  [], ...
    'epochtime',   [Baseline(1), DataWindow(2)], ...
    'createcond',  0, ...
    'ignoreshort', 1, ...
    'usectfcomp',  0, ...
    'usessp',      0, ...
    'freq',        sampling_rate, ...
    'baseline',    Baseline);

%%  Process: Average: By trial group (folder average)
sAvgKojak = bst_process('CallProcess', 'process_average', sFilesEpochs, [], ...
    'avgtype',    5, ...  % By trial group (folder average)
    'avg_func',   1, ...  % Arithmetic average:  mean(x)
    'weighted',   0, ...
    'keepevents', 0);



%% Process: Compute Head Model
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

%% ===== SOURCE ESTIMATION =====


%% First, we use the prestim, to establish a baseline with GLS method


fprintf('\n GLS METHOD Calculating full noise prestim from all %.0f epochs.\n\n',length(sFilesEpochs))

% Process: Compute covariance (noise or data)
bst_process('CallProcess', 'process_noisecov', sFilesEpochs, [], ...
    'baseline',       Baseline, ...
    'datatimewindow', DataWindow, ... 
    'sensortypes',    'MEG', ...
    'target',         1, ...  % Noise covariance     (covariance over baseline time window)
    'dcoffset',       1, ...  % Block by block, to avoid effects of slow shifts in data
    'identity',       0, ...
    'copycond',       0, ...
    'copysubj',       0, ...
    'replacefile',    1);  % Replace

% Process: Compute covariance (noise or data)
bst_process('CallProcess', 'process_noisecov', sFilesEpochs, [], ...
    'baseline',       Baseline, ...
    'datatimewindow', DataWindow, ... 
    'sensortypes',    'MEG', ...
    'target',         2, ...  % Data covariance      (covariance over data time window)
    'dcoffset',       1, ...  % Block by block, to avoid effects of slow shifts in data
    'identity',       0, ...
    'copycond',       0, ...
    'copysubj',       0, ...
    'replacefile',    1);  % Replace


% and now run the source estimation and display the results

tutorial_phantom_elekta_lcmv_src(sAvgKojak,DipNdx,'gls',SUBARRAY,DipTrueFile)

%% Now the proper LCMV with same noise and data covariances
% and now run the source estimation and display the results

fprintf('\nResults using all data as covariance\n')

tutorial_phantom_elekta_lcmv_src(sAvgKojak,DipNdx,'lcmv',SUBARRAY,DipTrueFile)



%% Testing Brainstorm's LCMV vs pseudoLCMV(GLS) routine

fprintf('\n GLS USED TO GENERATE LCMV Calculating the Noise as the full data covariance from all %.0f epochs.\n\n',length(sFilesEpochs))

% Process: Compute covariance (noise or data)
bst_process('CallProcess', 'process_noisecov', sFilesEpochs, [], ...
    'baseline',       DataWindow, ...
    'datatimewindow', DataWindow, ...
    'sensortypes',    'MEG', ...
    'target',         1, ...  % Noise covariance     (covariance over baseline time window)
    'dcoffset',       1, ...  % Block by block, to avoid effects of slow shifts in data
    'identity',       0, ...
    'copycond',       0, ...
    'copysubj',       0, ...
    'replacefile',    1);  % Replace

% Process: Compute covariance (noise or data)
bst_process('CallProcess', 'process_noisecov', sFilesEpochs, [], ...
    'baseline',       DataWindow, ...
    'datatimewindow', DataWindow, ... 
    'sensortypes',    'MEG', ...
    'target',         2, ...  % Data covariance      (covariance over data time window)
    'dcoffset',       1, ...  % Block by block, to avoid effects of slow shifts in data
    'identity',       0, ...
    'copycond',       0, ...
    'copysubj',       0, ...
    'replacefile',    1);  % Replace


% and now run the source estimation and display the results

fprintf('\nResults using  data as covariances and running as GLS:\n')

tutorial_phantom_elekta_lcmv_src(sAvgKojak,DipNdx,'gls',SUBARRAY,DipTrueFile)

%% Testing Brainstorm's LCMV vs pseudoLCMV(GLS) routine

fprintf('\n LCMV USED FOR GLS Calculating the Data Covariance as the  noise covariance from all %.0f epochs.\n\n',length(sFilesEpochs))

% Process: Compute covariance (noise or data)
bst_process('CallProcess', 'process_noisecov', sFilesEpochs, [], ...
    'baseline',       Baseline, ...
    'datatimewindow', Baseline, ... 
    'sensortypes',    'MEG', ...
    'target',         1, ...  % Noise covariance     (covariance over baseline time window)
    'dcoffset',       1, ...  % Block by block, to avoid effects of slow shifts in data
    'identity',       0, ...
    'copycond',       0, ...
    'copysubj',       0, ...
    'replacefile',    1);  % Replace

% Process: Compute covariance (noise or data)
bst_process('CallProcess', 'process_noisecov', sFilesEpochs, [], ...
    'baseline',       Baseline, ...
    'datatimewindow', Baseline, ... 
    'sensortypes',    'MEG', ...
    'target',         2, ...  % Data covariance      (covariance over data time window)
    'dcoffset',       1, ...  % Block by block, to avoid effects of slow shifts in data
    'identity',       0, ...
    'copycond',       0, ...
    'copysubj',       0, ...
    'replacefile',    1);  % Replace

% and now run the source estimation and display the results

fprintf('\nResults using prestim as covariance and running as LCMV:\n')

tutorial_phantom_elekta_lcmv_src(sAvgKojak,DipNdx,'lcmv',SUBARRAY,DipTrueFile)



%% DISABLED: Now estimate the noise covariance from just the selected reference dipoles, to establish again a baseline

if false, % if desired, not really different from full baseline
    % want just the epochs of the Reference Dipole
    EpochNdx = []; % find all of the corresponding epochs
    for i = 1:length(RefDip),
        EpochNdx = [EpochNdx find(strncmp(sprintf('%02.0f',RefDip(i)),{sFilesEpochs.Comment},2))];
    end
    
    % Set the baseline to the prestim
    
    fprintf('\nCalculating the prestim baseline from just dipole %.0f for %.0f epochs\n\n',RefDip,length(EpochNdx))
    
 % Process: Compute covariance (noise or data)
bst_process('CallProcess', 'process_noisecov', sFilesEpochs, [], ...
    'baseline',       Baseline, ...
    'datatimewindow', DataWindow, ... 
    'sensortypes',    'MEG', ...
    'target',         1, ...  % Noise covariance     (covariance over baseline time window)
    'dcoffset',       1, ...  % Block by block, to avoid effects of slow shifts in data
    'identity',       0, ...
    'copycond',       0, ...
    'copysubj',       0, ...
    'replacefile',    1);  % Replace

% Process: Compute covariance (noise or data)
bst_process('CallProcess', 'process_noisecov', sFilesEpochs, [], ...
    'baseline',       Baseline, ...
    'datatimewindow', DataWindow, ...
    'sensortypes',    'MEG', ...
    'target',         2, ...  % Data covariance      (covariance over data time window)
    'dcoffset',       1, ...  % Block by block, to avoid effects of slow shifts in data
    'identity',       0, ...
    'copycond',       0, ...
    'copysubj',       0, ...
    'replacefile',    1);  % Replace
   
    fprintf('\nBaseline results a few dipole prestims as noise covariance\n')
    
    tutorial_phantom_elekta_lcmv_src(sAvgKojak,DipNdx,'gls',SUBARRAY,DipTrueFile)
    
end

%% Now estimate the data covariance from just the reference dipoles

EpochNdx = []; % find all of the corresponding epochs
for i = 1:length(RefDip),
    EpochNdx = [EpochNdx find(strncmp(sprintf('%02.0f',RefDip(i)),{sFilesEpochs.Comment},2))];
end

fprintf('\nReference Dipole set: %.0f',RefDip(1)), fprintf(', %.0f',RefDip(2:end)), fprintf('\n')
fprintf('Calculating the data covariance from %.0f epochs\n\n',length(EpochNdx))

% Process: Compute covariance (noise or data)
bst_process('CallProcess', 'process_noisecov', sFilesEpochs(EpochNdx), [], ...
    'baseline',       Baseline, ...
    'datatimewindow', DataWindow, ... 
    'sensortypes',    'MEG', ...
    'target',         1, ...  % Noise covariance     (covariance over baseline time window)
    'dcoffset',       1, ...  % Block by block, to avoid effects of slow shifts in data
    'identity',       0, ...
    'copycond',       0, ...
    'copysubj',       0, ...
    'replacefile',    1);  % Replace

% Process: Compute covariance (noise or data)
bst_process('CallProcess', 'process_noisecov', sFilesEpochs(EpochNdx), [], ...
    'baseline',       Baseline, ...
    'datatimewindow', DataWindow, ... 
    'sensortypes',    'MEG', ...
    'target',         2, ...  % Data covariance      (covariance over data time window)
    'dcoffset',       1, ...  % Block by block, to avoid effects of slow shifts in data
    'identity',       0, ...
    'copycond',       0, ...
    'copysubj',       0, ...
    'replacefile',    1);  % Replace

fprintf('\nLCMV results a few dipoles for their own data covariance\n\n')

tutorial_phantom_elekta_lcmv_src(sAvgKojak,DipNdx,'lcmv',SUBARRAY,DipTrueFile)



%% Now sum the reference set for a new data set, to show beamformer operation

% use sAvgKojak from above
 
% which files have the reference dipoles
FileNdx = [];
for ii = 1:length(RefDip),
    STR = sprintf('data_%02.0f',RefDip(ii)); % search string
    for i = 1:length(sAvgKojak),
        if ~isempty(strfind(sAvgKojak(i).FileName,STR)),
            FileNdx = [FileNdx i];
        end
    end
end

sFilesRef = sAvgKojak(FileNdx);

% % Input files
% sFiles = {...
%     'Kojak/kojak_all_200nAm_pp_no_chpi_no_ms_raw/data_05_average_160817_1419.mat', ...
%     'Kojak/kojak_all_200nAm_pp_no_chpi_no_ms_raw/data_13_average_160817_1419.mat', ...
%     'Kojak/kojak_all_200nAm_pp_no_chpi_no_ms_raw/data_17_average_160817_1419.mat', ...
%     'Kojak/kojak_all_200nAm_pp_no_chpi_no_ms_raw/data_25_average_160817_1419.mat'};


% Process: Scale each one by the total number in preparation of "mean"
sFilesRef = bst_process('CallProcess', 'process_scale', sFilesRef, [], ...
    'factor',      length(RefDip), ...
    'sensortypes', '', ...
    'overwrite',   0);

% Process: Average: By folder (subject average). Each signal maintains its
% strength
sFilesRefAvg = bst_process('CallProcess', 'process_average', sFilesRef, [], ...
    'avgtype',    3, ...  % By folder (subject average)
    'avg_func',   1, ...  % Arithmetic average:  mean(x)
    'weighted',   0, ...
    'keepevents', 0);




%%
% Save and display report
%ReportFile = bst_report('Save', []);
%bst_report('Open', ReportFile);











