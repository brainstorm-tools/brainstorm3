function tutorial_visual_old_copy(ProtocolNameSingle, ProtocolNameGroup, reports_dir)
% TUTORIAL_VISUAL_OLD_COPY: Copy the subject averages for the Brainstorm/SPM group tutorial into a new protocol (old distribution).
%
% ONLINE TUTORIALS: 
%    - https://neuroimage.usc.edu/brainstorm/Tutorials/VisualSingleOrig
%    - https://neuroimage.usc.edu/brainstorm/Tutorials/VisualGroupOrig
%
% INPUTS:
%    - ProtocolNameSingle : Name of the protocol created with all the data imported (TutorialVisual)
%    - ProtocolNameGroup  : Name of the protocol with just the averages, downsampled to 275Hz (TutorialGroup)
%    - reports_dir        : If defined, exports all the reports as HTML to this folder

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Author: Francois Tadel, Elizabeth Bock, 2016

% ===== CHECK PROTOCOL =====
% Start brainstorm without the GUI
if ~brainstorm('status')
    brainstorm nogui
end
% Output folder for reports
if (nargin < 3) || isempty(reports_dir) || ~isdir(reports_dir)
    reports_dir = [];
end
% You have to specify the folder in which the tutorial dataset is unzipped
if (nargin < 2) || isempty(ProtocolNameSingle) || isempty(ProtocolNameGroup)
    ProtocolNameSingle = 'TutorialVisual';
    ProtocolNameGroup  = 'TutorialGroup';
end
% Input protocol: Check that it exists
iProtocolSingle = bst_get('Protocol', ProtocolNameSingle);
if isempty(iProtocolSingle)
    error(['Unknown protocol: ' ProtocolNameSingle]);
end
% Output protocol: Delete existing protocol
gui_brainstorm('DeleteProtocol', ProtocolNameGroup);
% Output protocol: Create new protocol
iProtocolGroup = gui_brainstorm('CreateProtocol', ProtocolNameGroup, 0, 0);
% Output protocol: Get protocol information
ProtocolInfoGroup = bst_get('ProtocolInfo');
% Select input protocol 
gui_brainstorm('SetCurrentProtocol', iProtocolSingle);
% Input protocol: Get protocol information
ProtocolInfoSingle = bst_get('ProtocolInfo');
% Start a new report (one report per subject)
bst_report('Start');

% ===== COPY ONLY GOOD SUBJECTS =====
% List of good subjects: all but sub001, sub005 and sub016
iSubjList = setdiff(1:19, [1 5 16]);
% Loop on subjects
for iSubj = iSubjList
    % Subject folders
    AnatSrc  = bst_fullfile(ProtocolInfoSingle.SUBJECTS, sprintf('sub%03d', iSubj));
    DataSrc  = bst_fullfile(ProtocolInfoSingle.STUDIES,  sprintf('sub%03d', iSubj));
    AnatDest = bst_fullfile(ProtocolInfoGroup.SUBJECTS,  sprintf('sub%03d', iSubj));
    DataDest = bst_fullfile(ProtocolInfoGroup.STUDIES,   sprintf('sub%03d', iSubj));
    % If subject folder doesn't exist: skip
    if ~file_exist(AnatSrc) || ~file_exist(DataSrc)
        disp(sprintf('Subject "sub%03d" does not exist or is incomplete.', iSubj));
        continue;
    end
    % Copy anatomy files
    mkdir(AnatDest);
    disp(['Copying: ' AnatSrc ' to ' AnatDest '...']);
    copyfile(bst_fullfile(AnatSrc, '*.mat'), AnatDest);
    % Copy analysis folders
    mkdir(bst_fullfile(DataDest, '@default_study'));
    mkdir(bst_fullfile(DataDest, '@intra'));
    disp(['Copying: ' DataSrc ' to ' DataDest '...']);
    copyfile(bst_fullfile(DataSrc, '@default_study', '*.mat'), bst_fullfile(DataDest, '@default_study'));
    copyfile(bst_fullfile(DataSrc, '@intra', '*.mat'), bst_fullfile(DataDest, '@intra'));
    % Loop on runs
    for iRun = 1:6
        % Run folders
        RunSrc  = bst_fullfile(DataSrc,  sprintf('run_%02d_sss_notch', iRun));
        RunDest = bst_fullfile(DataDest, sprintf('run_%02d_sss_notch', iRun));
        % If run folder doesn't exist: skip
        if ~file_exist(RunSrc)
            disp(sprintf('Run "sub%03d/run_%02d_sss_notch" does not exist or is incomplete.', iSubj, iRun));
            continue;
        end
        % Copy files
        mkdir(RunDest);
        disp(['Copying: ' RunSrc ' to ' RunDest '...']);
        copyfile(bst_fullfile(RunSrc, 'brainstormstudy.mat'), RunDest);
        copyfile(bst_fullfile(RunSrc, 'channel_*.mat'), RunDest);
        copyfile(bst_fullfile(RunSrc, '*_average_*.mat'), RunDest);
        if ~isempty(dir(bst_fullfile(RunSrc, 'headmodel_*.mat')))
            copyfile(bst_fullfile(RunSrc, 'headmodel_*.mat'), RunDest);
        end
        if ~isempty(dir(bst_fullfile(RunSrc, 'noisecov_full.mat')))
            copyfile(bst_fullfile(RunSrc, 'noisecov_full.mat'), RunDest);
        end
        if ~isempty(dir(bst_fullfile(RunSrc, 'results_*.mat')))
            copyfile(bst_fullfile(RunSrc, 'results_*.mat'), RunDest);
        end
        if ~isempty(dir(bst_fullfile(RunSrc, 'timefreq_*.mat')))
            copyfile(bst_fullfile(RunSrc, 'timefreq_*.mat'), RunDest);
        end
    end
end

% ===== RELOAD =====
% Reload output protocol
db_reload_database(iProtocolGroup);
% Select output protocol 
gui_brainstorm('SetCurrentProtocol', iProtocolGroup);

% ===== DOWNSAMPLE TO 275HZ =====
% Process: Select data files in: */*
sDataAll = bst_process('CallProcess', 'process_select_files_data', [], []);
% Process: Resample: 275Hz
sDataAll = bst_process('CallProcess', 'process_resample', sDataAll, [], ...
    'freq',      275, ...
    'overwrite', 1);
% Process: Select time-frequency files in: */*
sTimefreqAll = bst_process('CallProcess', 'process_select_files_timefreq', [], []);
% Process: Resample: 275Hz
if ~isempty(sTimefreqAll)
    sTimefreqAll = bst_process('CallProcess', 'process_resample', sTimefreqAll, [], ...
        'freq',      275, ...
        'overwrite', 1);
end

% ===== RENAME: DATA =====
% Process: Select data files in: */*
sDataAll = bst_process('CallProcess', 'process_select_files_data', [], []);
% Rename data files
for i = 1:length(sDataAll)
    % Remove all the processing tags
    iTag = strfind(sDataAll(i).Comment, ' |');
    if isempty(iTag)
        continue;
    end
    newComment = sDataAll(i).Comment(1:iTag-1);
    % Process: Set comment: AA
    bst_process('CallProcess', 'process_set_comment', sDataAll(i), [], ...
        'tag',     newComment, ...
        'isindex', 0);
end

% ===== RENAME: TIME-FREQ =====
% Process: Select time-frequency files in: */*
sTimefreqAll = bst_process('CallProcess', 'process_select_files_timefreq', [], []);
% Rename timefreq files
%AllConditions = {'Famous', 'Scrambled', 'Unfamiliar'};
for i = 1:length(sTimefreqAll)
    % Remove all the processing tags
    iTag = strfind(sTimefreqAll(i).Comment, ' |');
    if isempty(iTag)
        continue;
    end
    newComment = sTimefreqAll(i).Comment(1:iTag-1);
    %newComment = ['Avg: ', AllConditions{sTimefreqAll(i).iItem}, ', Power, 6-60Hz'];
    % Process: Set comment
    bst_process('CallProcess', 'process_set_comment', sTimefreqAll(i), [], ...
        'tag',     newComment, ...
        'isindex', 0);
end

% Save report
ReportFile = bst_report('Save', []);
if ~isempty(reports_dir) && ~isempty(ReportFile)
    bst_report('Export', ReportFile, bst_fullfile(reports_dir, ['report_' ProtocolNameGroup '_copy.html']));
end





