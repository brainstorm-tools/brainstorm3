function test_tutorial(tutorialNames, dataDir, reportDir, bstUser, bstPwd)
% TEST_TUTORIAL Test Brainstorm by running tutorial scripts
%               If Brainstorm is not running, it is started without GUI and with 'local' database
%
% USAGE: test_brainstorm(tutorialNames, dataDir, reportDir, bstUser, bstPwd)
%
% INPUTS:
%    - tutorialNames : Tutorial or {Tutorials} to run, usually scripts in "./toolbox/scripts"
%    - dataDir       : (opt) Directory wtih tutorial data files               (default = 'pwd'/tmpdir)
%    - reportDir     : (opt) Directory to save reports                        (default = reports are not saved)
%    - bstUser       : (opt) BST user to receive email with report            (default = no email)
%    - bstPwd        : (opt) Password for BST user to download data if needed (default = empty)
%
% For a given tutorial in 'tutorialNames', the script does:
%    1. Find/get the tutorial data (download if bstUser and bstPwd are available)
%    2. Run tutorial script
%    3. Send report by email to bstUser
%
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
% Authors: Raymundo Cassani, 2023-2024


%% ===== PARAMETERS =====
if nargin < 2 || isempty(dataDir)
    dataDir = bst_fullfile(pwd, 'tmpdir');
end
if nargin < 3 || isempty(reportDir)
    reportDir = '';
end
if nargin < 4 || isempty(bstUser)
    bstUser = '';
end
if nargin < 5 || isempty(bstPwd)
    bstPwd = '';
end

% All tutorials
if ischar(tutorialNames)
    if strcmpi(tutorialNames, 'all')
        tutorialNames = {'tutorial_introduction', ...
                         'tutorial_connectivity', ...
                         'tutorial_coherence', ...
                         'tutorial_ephys', ...
                         'tutorial_dba', ...
                         'tutorial_epilepsy', ...
                         'tutorial_epileptogenicity', ...
                         'tutorial_fem_charm', ...
                         'tutorial_fem_tensors', ...
                         'tutorial_frontiers2018', ...
                         'tutorial_visual', ...
                         'tutorial_hcp', ...
                         'tutorial_neuromag', ...
                         'tutorial_omega', ...
                         'tutorial_phantom_ctf', ...
                         'tutorial_phantom_elekta', ...
                         'tutorial_practicalmeeg', ...
                         'tutorial_raw', ...
                         'tutorial_resting', ...
                         'tutorial_simulations', ...
                         'tutorial_yokogawa', ...
                        };
    else
        tutorialNames = {tutorialNames};
    end
end


%% ===== START BRAINSTORM =====
% Check that Brainstorm is in the Matlab path
res = exist('brainstorm.m', 'file');
if res ~=2
    error('Could not find "brainstorm.m" in Matlab path.');
end
% Start Brainstorm without GUI and with local database
stopBstAtEnd = 0;
if ~brainstorm('status')
    brainstorm nogui local
    stopBstAtEnd = 1;
end


%% ===== DATA AND REPORT DIRS =====
% Data directory
if ~exist(dataDir, 'dir')
    mkdir(dataDir);
end
% Report dir
if ~isempty(reportDir) && ~exist(reportDir, 'dir')
    mkdir(reportDir)
end


%% ===== RUN TUTORIALS, SAVE REPORTS AND SEND EMAIL =====
for iTutorial = 1 : length(tutorialNames)
    tutoriallName = tutorialNames{iTutorial};
    % Clean report history
    bst_report('ClearHistory', 0);
    infoStr = 'Error preparing file for tutorial';
    % === Run tutorial
    switch tutoriallName
        case 'tutorial_introduction'
            dataFile = get_tutorial_data(dataDir, 'sample_introduction.zip', bstUser, bstPwd);
            if exist(dataFile, 'file')
                bst_unzip(dataFile, dataDir);
                tutorial_introduction(dataDir);
            end

        case 'tutorial_connectivity'
            tutorial_connectivity();

        case 'tutorial_coherence'
            dataFile = bst_fullfile(dataDir, 'SubjectCMC.zip');
            if ~exist(dataFile, 'file')
                bst_websave(dataFile, 'https://download.fieldtriptoolbox.org/tutorial/SubjectCMC.zip');
            end
            if exist(dataFile, 'file')
                bst_unzip(dataFile, bst_fullfile(dataDir, 'SubjectCMC'));
                tutorial_coherence(dataDir);
            end

        case 'tutorial_dba'
            dataFile = get_tutorial_data(dataDir, 'TutorialDba.zip', bstUser, bstPwd);
            if exist(dataFile, 'file')
                tutorial_dba(dataFile);
            end

        case 'tutorial_ephys'
            dataFile = get_tutorial_data(dataDir, 'sample_ephys.zip', bstUser, bstPwd);
            if exist(dataFile, 'file')
                bst_unzip(dataFile, dataDir);
                tutorial_ephys(dataDir);
            end

        case 'tutorial_epilepsy'
            dataFile = get_tutorial_data(dataDir, 'sample_epilepsy.zip', bstUser, bstPwd);
            if exist(dataFile, 'file')
                bst_unzip(dataFile, dataDir);
                tutorial_epilepsy(dataDir);
            end

        case 'tutorial_epileptogenicity'
            dataFile = get_tutorial_data(dataDir, 'tutorial_epimap_bids.zip', bstUser, bstPwd);
            if exist(dataFile, 'file')
                bst_unzip(dataFile, dataDir);
                tutorial_epileptogenicity(dataDir);
            end

        case 'tutorial_fem_charm'
              infoStr = 'REQUIRES TO INSTALL SimNIBS';
%             tmpDwnFile = mget(bstFtp, '/pub/tutorials/sample_fem.zip', tmpDir);
%             bst_unzip(tmpDwnFile{:}, tmpDir);
%             tutorial_fem_charm(tmpDir);

        case 'tutorial_fem_tensors'
              infoStr = 'REQUIRES TO BrainSuite';
%             dataFile1 = bst_fullfile(dataDir, 'BrainSuiteTutorialSVReg.zip');
%             if ~exist(dataFile1, 'file')
%                 bst_websave(dataFile, 'http://brainsuite.org/WebTutorialData/BrainSuiteTutorialSVReg_Sept16.zip');
%             end
%             dataFile2 = bst_fullfile(dataDir, 'DWI.zip');
%             if ~exist(dataFile2, 'file')
%                 bst_websave(dataFile2, 'http://brainsuite.org/WebTutorialData/DWI_Feb15.zip');
%             end
%             if exist(dataFile1, 'file') && exist(dataFile2, 'file')
%                 bst_unzip(dataFile1, dataDir);
%                 bst_unzip(dataFile2, dataDir);
%                 tutorial_fem_tensors(dataDir);
%             end

        case 'tutorial_frontiers2018'
              infoStr = 'REQUIRES TO DOWNLOAD ~100GB https://openneuro.org/datasets/ds000117';
%             tutorial_frontiers2018(tmpDir);

        case 'tutorial_visual'
              infoStr = 'REQUIRES TO DOWNLOAD ~100GB https://openneuro.org/datasets/ds000117';
%             tutorial_visual(tmpDir);

        case 'tutorial_hcp'
              infoStr = 'REQUIRES TO DOWNLOAD ~20GB  HCP-MEG2 distribution: subject #175237';
%             tutorial_hcp(tmpDir);

        case 'tutorial_neuromag'
            dataFile = get_tutorial_data(dataDir, 'sample_neuromag.zip', bstUser, bstPwd);
            if exist(dataFile, 'file')
                bst_unzip(dataFile, dataDir);
                tutorial_neuromag(dataDir);
            end

        case 'tutorial_omega'
            infoStr = 'REQUIRES TO DOWNLOAD ~12GB  https://openneuro.org/datasets/ds000247';
            % tutorial_omega(tmpDir);

        case 'tutorial_phantom_ctf'
            dataFile = get_tutorial_data(dataDir, 'sample_phantom_ctf.zip', bstUser, bstPwd);
            if exist(dataFile, 'file')
                bst_unzip(dataFile, dataDir);
                tutorial_phantom_ctf(dataDir);
            end

        case 'tutorial_phantom_elekta'
            dataFile = get_tutorial_data(dataDir, 'sample_phantom_elekta.zip', bstUser, bstPwd);
            if exist(dataFile, 'file')
                bst_unzip(dataFile, dataDir);
                tutorial_phantom_elekta(dataDir);
            end

        case 'tutorial_practicalmeeg'
            dataFile = get_tutorial_data(dataDir, 'tutorial_practicalmeeg.zip', bstUser, bstPwd);
            if exist(dataFile, 'file')
                bst_unzip(dataFile, dataDir);
                tutorial_practicalmeeg(bst_fullfile(dataDir, 'tutorial_practicalmeeg'));
            end

        case 'tutorial_raw'
            dataFile = get_tutorial_data(dataDir, 'sample_raw.zip', bstUser, bstPwd);
            if exist(dataFile, 'file')
                bst_unzip(dataFile, dataDir);
                tutorial_raw(dataDir);
            end

        case 'tutorial_resting'
            dataFile = get_tutorial_data(dataDir, 'sample_resting.zip', bstUser, bstPwd);
            if exist(dataFile, 'file')
                bst_unzip(dataFile, dataDir);
                tutorial_resting(dataDir);
            end

        case 'tutorial_simulations'
            tutorial_simulations();

        case 'tutorial_yokogawa'
            dataFile = get_tutorial_data(dataDir, 'sample_yokogawa.zip', bstUser, bstPwd);
            if exist(dataFile, 'file')
                bst_unzip(dataFile, dataDir);
                tutorial_yokogawa(dataDir);
            end
    end

    % Get report (available if tutorial was run)
    [~, ReportFile] = bst_report('GetReport', 'last');
    % Was the tutorial run?
    wasRun = ~isempty(ReportFile);
    % Generate not-executed report
    if ~wasRun
        tmp = struct('Comment', tutoriallName); % Dummy struct to give name to report
        bst_report('Reset');
        bst_report('Add', 'start', [], [], tmp);
        bst_report('Info', '', '', sprintf('"%s" was not executed', tutoriallName));
        bst_report('Info', '', '', infoStr);
        ReportFile = bst_report('Save');
    end

    % === Save report file
    if ~isempty(reportDir) && ~isempty(ReportFile)
        [~, baseName] = bst_fileparts(ReportFile);
        bst_report('Export', ReportFile, bst_fullfile(reportDir, [baseName, '.html']));
    end

    % === Report email
    if ~isempty(bstUser)
        % Tutorial info
        tutorialInfo = sprintf('Tutorial: "%s"', tutoriallName);
        % Hostname and OS
        [~, hostName] = system('hostname');
        hostInfo = sprintf('Host: "%s" with %s', strtrim(hostName), bst_get('OsName'));
        % Matlab info
        matlabInfo = sprintf('Matlab: %s', bst_get('MatlabReleaseName'));
        % Brainstorm info
        bstVersion = bst_get('Version');
        bstVariant = 'source';
        if bst_iscompiled()
            bstVariant = 'standalone';
        end
        bstInfo = sprintf('BST: %s (%s)', bstVersion.Version, bstVariant);
        % Status
        if wasRun
            statusInfo = '[Complete]';
        else
            statusInfo = '[Not exec]';
        end
        % Subject string
        strSubject = [statusInfo, ' ' tutorialInfo, ', ' hostInfo, ', ' matlabInfo, ', ', bstInfo];

        % Process: Send report by email
        bst_process('CallProcess', 'process_report_email', [], [], ...
            'username',   bstUser, ...
            'cc',         '', ...
            'subject',    strSubject, ...
            'reportfile', ReportFile, ...
            'full',       1);
    end
end

% Stop Brainstorm
if stopBstAtEnd
    brainstorm stop
end
end
