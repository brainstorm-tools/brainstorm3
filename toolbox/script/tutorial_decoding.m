function tutorial_decoding(tutorial_dir, reports_dir)
% TUTORIAL_DECODING: Script that runs the Brainstorm decodoing tutorial
% https://neuroimage.usc.edu/brainstorm/Tutorials/Decoding
%
% INPUTS: 
%    - tutorial_dir : Directory where the sample_decoding.zip file has been unzipped
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
% Author: Raymundo Cassani, 2026

% Output folder for reports
if (nargin < 2) || isempty(reports_dir) || ~isfolder(reports_dir)
    reports_dir = [];
end
% You have to specify the folder in which the tutorial dataset is unzipped
if (nargin == 0) || isempty(tutorial_dir) || ~file_exist(tutorial_dir)
    error('The first argument must be the full path to the dataset folder.');
end

% Protocol name
ProtocolName = 'TutorialDecoding';
% Subject name
SubjectName = 'Subject01';

% Build the path of the files to import
MegFileName = fullfile(tutorial_dir, 'sample_decoding', 'subj04NN_sess01-0_tsss.fif');
% Check if the folder contains the required file
if ~file_exist(MegFileName)
    error(['The folder ' tutorial_dir ' does not contain the folder from the file sample_decoding.zip.']);
end


%% ===== CREATE PROTOCOL =====
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


%% ===== IMPORT THE RECORDINGS =====
% Process: Create link to raw files
sFileRaw = bst_process('CallProcess', 'process_import_data_raw', [], [], ...
    'subjectname',  SubjectName, ...
    'datafile',     {MegFileName, 'FIF'}, ...
    'channelalign', 1);


%% ===== EVENT MARKERS =====
% Process: Read from channel
sFileRaw = bst_process('CallProcess', 'process_evt_read', sFileRaw, [], ...
    'stimchan',     'STI101', ...
    'trackmode',    'value', ...  % Value: detect the changes of channel value
    'maskcheck',    0, ...
    'mask',         '0', ...
    'zero',         0, ...
    'min_duration', 0);
% Process: Duplicate / merge events
sFileRaw = bst_process('CallProcess', 'process_evt_merge', sFileRaw, [], ...
    'evtnames', '13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24', ...
    'newname',  'faces', ...
    'delete',   0);

% Process: Duplicate / merge events
sFileRaw = bst_process('CallProcess', 'process_evt_merge', sFileRaw, [], ...
    'evtnames', '49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60', ...
    'newname',  'objects', ...
    'delete',   0);


%% ===== IMPORTING DATA EPOCHS =====
% Process: Import MEG/EEG: Events
sFiles = bst_process('CallProcess', 'process_import_data_event', sFileRaw, [], ...
    'subjectname',   SubjectName, ...
    'condition',     '', ...
    'eventname',     'faces, objects', ...
    'timewindow',    [], ...
    'epochtime',     [-0.2, 0.8], ...
    'split',         0, ...
    'createcond',    0, ...
    'ignoreshort',   1, ...
    'usectfcomp',    1, ...
    'usessp',        1, ...
    'freq',          [], ...
    'baseline',      [-0.2, 0], ...
    'blsensortypes', 'MEG');


%% ===== DECODING WITH CROSS-VALIDATION =====
% Decoding: Over time
% Process: SVM decoding
sDecodeTimePair = bst_process('CallProcess', 'process_decoding_svm', sFiles, [], ...
    'sensortypes',      'MEG', ...
    'ignorebad',        0, ...
    'lowpass',          30, ...
    'num_permutations', 100, ...
    'kfold',            5, ...
    'method',           1, ...  % Pairwise
    'model',            'svm');

% Process: Snapshot: Recordings time series
bst_process('CallProcess', 'process_snapshot', sDecodeTimePair, [], ...
    'type',           'data', ...  % Recordings time series
    'time',           0.1, ...
    'contact_time',   [0, 0.1], ...
    'contact_nimage', 12, ...
    'rowname',        '', ...
    'Comment',        '');

% Decoding: Temporal generalization 
% Process: SVM decoding
sDecodeTimeGen = bst_process('CallProcess', 'process_decoding_svm', sFiles, [], ...
    'sensortypes',      'MEG', ...
    'ignorebad',        0, ...
    'lowpass',          30, ...
    'num_permutations', 100, ...
    'kfold',            5, ...
    'method',           2, ...  % Temporal generalization
    'model',            'svm');

% Snapshot
hFig = view_matrix(sDecodeTimeGen.FileName, 'Image');
bst_report('Snapshot', hFig, sDecodeTimeGen.FileName);
close(hFig);


%% ===== SAVE REPORT =====
% Save and display report
ReportFile = bst_report('Save', []);
if ~isempty(reports_dir) && ~isempty(ReportFile)
    bst_report('Export', ReportFile, reports_dir);
else
    bst_report('Open', ReportFile);
end

disp([10 'DEMO> Decoding tutorial completed' 10]);

