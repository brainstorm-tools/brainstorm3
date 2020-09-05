function [DuneuroExe, errMsg] = duneuro_install(isInteractive)
% DUNEURO_INSTALL: Install DUNEuro executables in $HOME/.brainstorm/duneuro

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
% Author: Francois Tadel 2020

% Parse inputs
if (nargin < 1) || isempty(isInteractive)
    isInteractive = 1;
end
% Initialize variables
DuneuroExe = [];
errMsg = [];
curdir = pwd;

% Get the executable file name
exeFile = ['bst_duneuro_meeg_', bst_get('OsType')];
if ispc
    exeFile = [exeFile, '.exe'];
end
% Check if already available in path
if exist(exeFile, 'file')
    DuneuroExe = which(exeFile);
    return;
end

% === GET CURRENT ONLINE VERSION ===
% Reading function: urlread replaced with webread in Matlab 2014b
if (bst_get('MatlabVersion') <= 803)
    url_read_fcn = @urlread;
else
    url_read_fcn = @webread;
end
% Read online version.txt
try
    str = url_read_fcn('https://neuroimage.usc.edu/bst/getversion_duneuro.php');
catch
    errMsg = 'Could not get current online version of bst_duneuro.';
    return;
end
if (length(str) < 6)
    return;
end
DuneuroVersion = str(1:6);
% Get download URL
url = ['https://neuroimage.usc.edu/bst/getupdate.php?d=bst_duneuro_' DuneuroVersion '.zip'];

% Local folder where to install the program
installDir = bst_fullfile(bst_get('BrainstormUserDir'), 'bst_duneuro');
downloadDir = bst_get('BrainstormUserDir');
% If dir doesn't exist in user folder, try to look for it in the Brainstorm folder
if ~isdir(installDir)
    installDirMaster = bst_fullfile(bst_get('BrainstormHomeDir'), 'bst_duneuro');
    if isdir(installDirMaster)
        installDir = installDirMaster;
    end
end
% Full path to executable
DuneuroExe = bst_fullfile(installDir, 'bin', exeFile);

% URL file defines the current version
urlFile = bst_fullfile(installDir, 'url');
% Read the previous download url information
if isdir(installDir) && file_exist(urlFile)
    fid = fopen(urlFile, 'r');
    prevUrl = fread(fid, [1 Inf], '*char');
    fclose(fid);
else
    prevUrl = '';
end
% If file doesnt exist: download
if ~isdir(installDir) || ~file_exist(DuneuroExe) || ~strcmpi(prevUrl, url)
    % If folder exists: delete
    if isdir(installDir)
        file_delete(installDir, 1, 3);
    end
    % Message
    if isInteractive
        isOk = java_dialog('confirm', ...
            ['bst-duneuro is not installed on your computer (or out-of-date).' 10 10 ...
            'Download and the latest version of bst-duneuro?'], 'bst-duneuro');
        if ~isOk
            errMsg = 'Download aborted by user';
            return;
        end
    end
    % Download file
    zipFile = bst_fullfile(downloadDir, 'bst_duneuro.zip');
    errMsg = gui_brainstorm('DownloadFile', url, zipFile, 'Download bst-duneuro');
    % If file was not downloaded correctly
    if ~isempty(errMsg)
        errMsg = ['Impossible to download bst-duneuro:' 10 errMsg];
        return;
    end
    % Display again progress bar
    bst_progress('text', 'Installing bst-duneuro...');
    % Unzip file
    cd(downloadDir);
    unzip(zipFile);
    file_delete(zipFile, 1, 3);
    cd(curdir);
    % Save download URL in folder
    fid = fopen(urlFile, 'w');
    fwrite(fid, url);
    fclose(fid);
end
% If installed but not in path: add to path
if ~exist(exeFile, 'file')
    addpath(bst_fullfile(installDir, 'bin'));
    % If the executable is still not accessible
    if ~exist(exeFile, 'file')
        DuneuroExe = [];
        errMsg = ['bst-duneuro executable ' exeFile ' could not be found in: ' fullfile(installDir, 'bin')];
        return;      
    end
else
    errMsg = ['bst-duneuro could not be installed in: ' installDir];
end

