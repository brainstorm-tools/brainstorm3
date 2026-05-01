function tutorial_fastgraph(tutorial_dir, reports_dir)
% TUTORIAL_FASTGRAPH: Script that reproduces the results of the online tutorial "Fastgraph".
%
% CORRESPONDING ONLINE TUTORIALS:
%     https://neuroimage.usc.edu/brainstorm/Tutorials/FastGraph
%
% INPUTS: 
%    - tutorial_dir : Directory where the tutorial_fastgraph.zip file has been unzipped
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
% Authors: Chinmay Chinara, 2026
%          John C. Mosher, 2026

%% ===== PARSE INPUTS =====
% Output folder for reports
if (nargin < 2) || isempty(reports_dir) || ~isfolder(reports_dir)
    reports_dir = [];
end
% You have to specify the folder in which the tutorial dataset is unzipped
if (nargin == 0) || isempty(tutorial_dir) || ~file_exist(tutorial_dir)
    error('The first argument must be the full path to the tutorial dataset folder.');
end
% Subject name
SubjectName = 'Subject01';

%% ===== FILES TO IMPORT =====
% Build the path of the files to import
tutorial_dir = bst_fullfile(tutorial_dir, 'tutorial_fastgraph');
MriFilePre   = bst_fullfile(tutorial_dir, 'anatomy', 'pre_T1.nii.gz');
MriCat12Path = fullfile(tutorial_dir, 'anatomy', 'cat12');
BaselineFile = bst_fullfile(tutorial_dir, 'recordings', 'Baseline.edf');
ElecPosFile  = bst_fullfile(tutorial_dir, 'recordings', 'Subject01_electrodes_mm.tsv');
% Check if the folder contains the required files
if ~file_exist(BaselineFile)
    error(['The folder ' tutorial_dir ' does not contain the folder from the file tutorial_fastgraph.zip.']);
end
isMriSegmented = file_exist(bst_fullfile(MriCat12Path, 'Subject01.nii'));

%% ===== CREATE PROTOCOL =====
% The protocol name has to be a valid folder name (no spaces, no weird characters...)
ProtocolName = 'TutorialFastgraph';
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

%% ===== IMPORT MRI AND CT VOLUMES =====
if ~isMriSegmented
    % Process: Import MRI
    bst_process('CallProcess', 'process_import_mri', [], [], ...
        'subjectname', SubjectName, ...
        'voltype',     'mri', ...
        'comment',     'pre_T1', ...
        'mrifile',     {MriFilePre, 'ALL'}, ...
        'nas',         [107, 176, 105], ...
        'lpa',         [ 34,  89,  74], ...
        'rpa',         [175,  89,  74]);
    % Process: Segment MRI with CAT12
    bst_process('CallProcess', 'process_segment_cat12', [], [], ...
        'subjectname', SubjectName, ...
        'nvertices',   15000, ...
        'tpmnii',      {'', 'Nifti1'}, ...
        'sphreg',      1, ... % Use spherical registration
        'vol',         0, ... % No volume parcellations
        'extramaps',   0, ... % No additional cortical maps
        'cerebellum',  0);
else
    % Process: Import anatomy folder
    bst_process('CallProcess', 'process_import_anatomy', [], [], ...
        'subjectname', SubjectName, ...
        'mrifile',     {MriCat12Path, 'CAT12'}, ...
        'nvertices',   15000, ...
        'nas',         [107, 176, 105], ...
        'lpa',         [ 34,  89,  74], ...
        'rpa',         [175,  89,  74]);
end
% Get filename for imported volumes
[sSubject, iSubject] = bst_get('Subject', SubjectName);
% Reference MRI
DbMriFilePre = sSubject.Anatomy(sSubject.iAnatomy).FileName;

%% ===== CREATE SEEG CONTACT IMPLANTATION =====
iStudyImplantation = db_add_condition(SubjectName, 'Implantation');
% Import locations and convert to subject coordinate system (SCS)
ImplantationChannelFile = import_channel(iStudyImplantation, ElecPosFile, 'BIDS-SCANRAS-MM', 1, 0, 1, 0, 2, DbMriFilePre);
% Snapshot: SEEG electrodes in MRI slices
hFigMri3d = view_channels_3d(ImplantationChannelFile, 'SEEG', 'anatomy', 1, 0);
bst_report('Snapshot', hFigMri3d, ImplantationChannelFile, 'SEEG electrodes in 3D MRI slices');
close(hFigMri3d);

%% ===== ACCESS THE RECORDINGS =====
% Process: Create link to raw file
sFileRaw = bst_process('CallProcess', 'process_import_data_raw', [], [], ...
    'subjectname',    SubjectName, ...
    'datafile',       {BaselineFile, 'EEG-EDF'}, ...
    'channelreplace', 0, ...
    'channelalign',   0);
% Process: Add EEG positions
bst_process('CallProcess', 'process_channel_addloc', sFileRaw, [], ...
    'channelfile', {ImplantationChannelFile, 'BST'}, ...
    'fixunits',    0, ... % No automatic fixing of distance units required
    'vox2ras',     0);    % Do not use the voxel=>subject transformation, already in SCS
% Process: Add EEG positions
bst_process('CallProcess', 'process_channel_addloc', sFileRaw, [], ...
    'channelfile', {ImplantationChannelFile, 'BST'}, ...
    'fixunits',    0, ... % No automatic fixing of distance units required
    'vox2ras',     0);    % Do not use the voxel=>subject transformation, already in SCS

% Process: Customize SPES
bst_process('CallProcess', 'process_customize_spes_nk', sFileRaw, [], ...
                'stimstartlabel', 'SB', ...
                'stimstoplabel',  'SE', ...
                'stimchan',       'DC10', ...
                'stimlabel',      'STIM', ...
                'buffertime',     2, ...      % in s
                'offset',         -0.001, ... % in ms
                'evtaddoddeven',  1);

% Process: Load the Stim Start blocks
sFilesStimStart = bst_process('CallProcess', 'process_import_data_event', sFileRaw, [], ...
                'subjectname', SubjectName, ...
                'condition',   '', ...
                'eventname',   'SB', ...
                'epochtime',   [-2 32], ... % in s
                'createcond',  0, ...
                'ignoreshort', 1, ...
                'usectfcomp',  1, ...
                'usessp',      1, ...
                'freq',        [], ...
                'baseline',    []);

% Process: Remove SPES artifacts
sFilesStimStartClean = bst_process('CallProcess', 'process_remove_spes_artifacts', sFilesStimStart, [], ...
                       'stimevent',  'STIM', ...
                       'cutoff',     2, ...     % in Hz
                       'timeart',    0.005, ... % in ms
                       'timespline', 0.003);    % in ms

% Process: Load the ODD events
sFilesOdd = bst_process('CallProcess', 'process_import_data_event', sFilesStimStartClean, [], ...
                'subjectname', SubjectName, ...
                'condition',   '', ...
                'eventname',   'ODD', ...
                'timewindow',  [-2 32], ...        % in s
                'epochtime',   [-0.100 0.900], ... % in ms
                'createcond',  0, ...
                'ignoreshort', 1, ...
                'usectfcomp',  1, ...
                'usessp',      1, ...
                'freq',        [], ...
                'baseline',    []);

% Process: Load the EVEN events
sFilesEven = bst_process('CallProcess', 'process_import_data_event', sFilesStimStartClean, [], ...
                'subjectname', SubjectName, ...
                'condition',   '', ...
                'eventname',   'EVEN', ...
                'timewindow',  [-2 32], ...        % in s
                'epochtime',   [-0.100 0.900], ... % in ms
                'createcond',  0, ...
                'ignoreshort', 1, ...
                'usectfcomp',  1, ...
                'usessp',      1, ...
                'freq',        [], ...
                'baseline',    []);

% Process: Average of only ODDs (by trial group)
sFilesAvgOdd = bst_process('CallProcess', 'process_average', sFilesOdd, [], ...
    'avgtype',    5, ...  % Trial group (folder average)
    'avg_func',   1, ...  % Arithmetic average:  mean(x)
    'weighted',   0, ...
    'keepevents', 0);

% Process: Average of only evens (by trial group)
sFilesAvgEven = bst_process('CallProcess', 'process_average', sFilesEven, [], ...
    'avgtype',    5, ...  % Trial group (folder average)
    'avg_func',   1, ...  % Arithmetic average:  mean(x)
    'weighted',   0, ...
    'keepevents', 0);

% Process: Average the ODD and EVEN per stimulation site per session
sFilesFastgraph = {};
for i = 1:length(sFilesAvgOdd)
    sFileAvg = bst_process('CallProcess', 'process_average', [sFilesAvgOdd(i),  sFilesAvgEven(i)], [], ...
                'avgtype',    1, ...  % Everything
                'avg_func',   1, ...  % Arithmetic average:  mean(x)
                'weighted',   0, ...
                'keepevents', 0);
    CommentMat = in_bst_data(sFileAvg.FileName, 'Comment');
    % Get the stim site info
    % Example: "Avg: ODD A'2-A'3 4.0 #2 (8 files)" > "A'2-A'3 4.0 #2"
    stimSiteInfo = regexp(sFilesAvgOdd(i).Comment, '^Avg:\s+\w+\s+(.+?)\s*\(.*\)$', 'tokens', 'once');
    CommentMat.Comment = ['Avg: ' stimSiteInfo{1}]; 
    % Save changes
    bst_save(file_fullpath(sFileAvg.FileName), CommentMat,'v7', 1);
    % Register output
    sFilesFastgraph{end+1} = sFileAvg.FileName;
end
db_reload_conditions(iSubject);

% Process: Plot Fastgraph
bst_process('CallProcess', 'process_fastgraph', sFilesFastgraph, [], ...
            'atlas',            'Desikan-Killiany', ...
            'colorscheme',      'Region', ...       % Color figures by region
            'regionprefrontal', 1, ...
            'regionfrontal',    1, ...
            'regioncentral',    1, ...
            'regionparietal',   1, ...
            'regiontemporal',   1, ...
            'regionoccipital',  1, ...
            'regionlimbic',     1, ...
            'atlasscoutlabels', '', ...
            'sortmethod',       1, ...               % "Root Mean Square" to sort data
            'sortwindow',       [0.060, 0.250], ...  % Range (middle latency) to sort the data (in ms)
            'plotwindow',       [-0.100, 0.900], ... % Plot window (in ms)
            'edgealpha',        0.05, ...            % Edge transparency of plot
            'excluderadius',    20);                 % Exclusion zone radius

%% ===== SAVE AND DISPLAY REPORT =====
ReportFile = bst_report('Save', []);
if ~isempty(reports_dir) && ~isempty(ReportFile)
    bst_report('Export', ReportFile, reports_dir);
else
    bst_report('Open', ReportFile);
end

disp([10 'DEMO> Fastgraph tutorial completed' 10]);