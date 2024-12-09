function tutorial_BEst(tutorial_dir, reports_dir)
% TUTORIAL_BEST: Script that runs all the Brain Entropy in space and time introduction tutorials.
%
% CORRESPONDING ONLINE TUTORIAL:
%     https://neuroimage.usc.edu/brainstorm/Tutorials/TutBEst
%
% INPUTS: 
%    - tutorial_dir : Directory where the sample_introduction.zip file has been unzipped
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
% Author: Edouard Delaire,  2024
%         Raymundo Cassani, 2024


% ===== FILES TO IMPORT =====
% Output folder for reports
if (nargin < 2) || isempty(reports_dir) || ~isdir(reports_dir)
    reports_dir = [];
end
% Folder in which the Introduction tutorial dataset is unzipped (if needed)
if (nargin == 0) || isempty(tutorial_dir) || ~file_exist(tutorial_dir)
    tutorial_dir = [];
end

% Re-inialize random number generator
if (bst_get('MatlabVersion') >= 712)
    rng('default');
end


%% ===== VERIFY REQUIRED PROTOCOL =====
ProtocolName    = 'TutorialIntroduction';
SubjectName     = 'Subject01';

iProtocolIntroduction = bst_get('Protocol', ProtocolName);
if isempty(iProtocolIntroduction)
    % Produce the Introduction protocol
    tutorial_introduction(tutorial_dir, reports_dir)
else
    % Select input protocol
    gui_brainstorm('SetCurrentProtocol', iProtocolIntroduction);
end


%% ===== REQUIRED PLUGIN =====
% Install and Load Brain Entropy plugin
[isInstalled, errMsg] = bst_plugin('Install', 'brainentropy');
if ~isInstalled
    error(errMsg);
end


%% ===== FIND FILES =====
% Process: Select recordings in: Subject01/S01_AEF_20131218_01_600Hz_notch
sFiles01 = bst_process('CallProcess', 'process_select_files_data', [], [], ...
    'subjectname', SubjectName, ...
    'condition',   'S01_AEF_20131218_01_600Hz_notch', ...
    'includebad',  0);
% Process: Select file comments with tag: deviant
sFilesAvgDeviant01 = bst_process('CallProcess', 'process_select_tag', sFiles01, [], ...
    'tag',    'Avg: deviant', ...
    'search', 2, ...  % Search the file comments
    'select', 1);     % Select only the files with the tag


%% ===== HEAD MODEL =====
disp([10 'BST> Head model' 10]);

% Process: Generate BEM surfaces
bst_process('CallProcess', 'process_generate_bem', [], [], ...
    'subjectname', SubjectName, ...
    'nscalp',      1922, ...
    'nouter',      1922, ...
    'ninner',      1922, ...
    'thickness',   4, ...
    'method',      'brainstorm');
% Process: Compute head model
bst_process('CallProcess', 'process_headmodel', sFilesAvgDeviant01, [], ...
    'sourcespace', 1, ...  % Cortex surface
    'meg',         4, ...  % OpenMEEG BEM
    'openmeeg',    struct(...
         'BemSelect',    [0, 0, 1], ...
         'BemCond',      [0.33, 0.0165, 0.33], ... 
         'BemNames',     {{'Scalp', 'Skull', 'Brain'}}, ...
         'BemFiles',     {{}}, ...
         'isAdjoint',    1, ...
         'isAdaptative', 1, ...
         'isSplit',      0, ...
         'SplitLength',  4000));


%% ===== SOURCE ESTIMATION =====
% coherent Maximum Entropy on the Mean (cMEM)
disp([10 'BST> Source estimation using cMEM' 10]);

% Process: Compute sources: BEst
mem_option = be_pipelineoptions(be_main, 'cMEM');
mem_option.optional = struct_copy_fields(mem_option.optional, ...
                     struct(...
                             'TimeSegment',     [0.05, 0.15], ...
                             'BaselineType',    {{'within-data'}}, ...
                             'Baseline',        [], ...
                             'BaselineHistory', {{'within'}}, ...
                             'BaselineSegment', [-0.1, 0], ...
                             'groupAnalysis',   0, ...
                             'display',         0));
sAvgSrcMEM = bst_process('CallProcess', 'process_inverse_mem', sFilesAvgDeviant01, [], ...
    'comment', 'MEM', ...
    'mem', struct('MEMpaneloptions', mem_option), ...
    'sensortypes', 'MEG');
% Process: Snapshot: Sources (one time)
bst_process('CallProcess', 'process_snapshot', sAvgSrcMEM, [], ...
    'target',    8, ...  % Sources (one time)
    'modality',  1, ...  % MEG (All)
    'orient',    1, ...  % left
    'time',      83.3*1e-3, ...
    'threshold', 0, ...
    'Comment',   'Average Deviant (cMEM)');


% wavelet Maximum Entropy on the Mean (wMEM)
disp([10 'BST> Source estimation using WMEM' 10]);

% Process: Compute sources: BEst
wMEM_options = be_pipelineoptions(be_main, 'wMEM');
wMEM_options.optional = struct_copy_fields(wMEM_options.optional, ...
                         struct(...
                                 'TimeSegment',     [0.05, 0.15], ...
                                 'BaselineType',    {{'within-data'}}, ...
                                 'Baseline',        [], ...
                                 'BaselineHistory', {{'within'}}, ...
                                 'BaselineSegment', [-0.1, 0], ...
                                 'groupAnalysis',   0, ...
                                 'display',         0));

% 1. Localizing only scale 4: 
wMEM_options.wavelet.selected_scales    = [4];
sAvgSrwMEM_scale4 = bst_process('CallProcess', 'process_inverse_mem', sFilesAvgDeviant01, [], ...
    'comment',     'MEM', ...
    'mem',         struct( 'MEMpaneloptions', wMEM_options), ...
    'sensortypes', 'MEG');
% Process: Snapshot: Sources (one time)
bst_process('CallProcess', 'process_snapshot', sAvgSrwMEM_scale4, [], ...
    'target',    8, ...  % Sources (one time)
    'modality',  1, ...  % MEG (All)
    'orient',    1, ...  % left
    'time',      83.3*1e-3, ...
    'threshold', 0, ...
    'Comment',   'Average Deviant (wMEM - scale 4)');

% 2. Localizing only scale 5: 
wMEM_options.wavelet.selected_scales    = [5];
sAvgSrwMEM_scale5 = bst_process('CallProcess', 'process_inverse_mem', sFilesAvgDeviant01, [], ...
    'comment',     'MEM', ...
    'mem',         struct( 'MEMpaneloptions', wMEM_options), ...
    'sensortypes', 'MEG');
% Process: Snapshot: Sources (one time)
bst_process('CallProcess', 'process_snapshot', sAvgSrwMEM_scale5, [], ...
    'target',    8, ...  % Sources (one time)
    'modality',  1, ...  % MEG (All)
    'orient',    1, ...  % left
    'time',      83.3*1e-3, ...
    'threshold', 0, ...
    'Comment',   'Average Deviant (wMEM - scale 5 )');

% 3. Localizing all scales: 
wMEM_options.wavelet.selected_scales    = [1,2,3,4,5];
sAvgSrwMEM_scaleAll = bst_process('CallProcess', 'process_inverse_mem', sFilesAvgDeviant01, [], ...
    'comment',     'MEM', ...
    'mem',         struct( 'MEMpaneloptions', wMEM_options), ...
    'sensortypes', 'MEG');
% Process: Snapshot: Sources (one time)
bst_process('CallProcess', 'process_snapshot', sAvgSrwMEM_scaleAll, [], ...
    'target',    8, ...  % Sources (one time)
    'modality',  1, ...  % MEG (All)
    'orient',    1, ...  % left
    'time',      83.3*1e-3, ...
    'threshold', 0, ...
    'Comment',   'Average Deviant (wMEM - all scale)');


%% ===== SAVE REPORT =====
% Save and display report
ReportFile = bst_report('Save', []);
if ~isempty(reports_dir) && ~isempty(ReportFile)
    bst_report('Export', ReportFile, reports_dir);
else
    bst_report('Open', ReportFile);
end

disp([10 'BST> tutorial_BEst: Done.' 10]);
