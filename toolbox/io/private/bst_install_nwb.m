function errMsg = bst_install_nwb(isInteractive)
% BST_INSTALL_NWB Install, configure or update the library reading NWB files

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
% Author: Konstantinos Nasiotis, Francois Tadel, 2019-2020

%% ===== VERSION =====
% url = 'https://github.com/NeurodataWithoutBorders/matnwb/archive/v2.2.5.0.zip';
url = 'https://github.com/NeurodataWithoutBorders/matnwb/archive/196b569626343804b7d64b0f1c279b5b84539908.zip';


%% ===== PRELIMINARY CHECKS =====
% Initialize returned variables
errMsg = [];
% Not available in compiled version of Brainstorm
if (exist('isdeployed', 'builtin') && isdeployed)
    errMsg = 'Importing MFF files is not supported yet with the compiled version of Brainstorm.';
    return;
end
% Check if already available in path
if exist('nwbRead', 'file')
    disp([10, 'NWB path: ', bst_fileparts(which('nwbRead')), 10]);
    return;
end
% Check if the NWB builder has already been downloaded, and is up-to-date
NWBDir = bst_fullfile(bst_get('BrainstormUserDir'), 'NWB');
NWBTmpDir = bst_fullfile(bst_get('BrainstormUserDir'), 'NWB_tmp');
if exist(bst_fullfile(NWBDir, 'nwbRead.m'), 'file')
    % URL file defines the current version
    urlFile = bst_fullfile(NWBDir, 'url');
    % Read the previous download url information
    if file_exist(urlFile)
        fid = fopen(urlFile, 'r');
        prevUrl = fread(fid, [1 Inf], '*char');
        fclose(fid);
    else
        prevUrl = '';
    end
    % If the version is OK, simply add folder to the path, otherwise delete and download again
    if strcmpi(prevUrl, url)
        addpath(genpath(NWBDir));
        return;
    end
end


%% ===== ASK USER CONFIRMATION =====
if isInteractive
    isOk = java_dialog('confirm', ...
        ['The NWB SDK is not installed on your computer or outdated.' 10 10 ...
             'Download and install the latest version?'], 'Neurodata Without Borders');
    if ~isOk
        errMsg = 'Installation aborted by user.';
        return;
    end
end


%% ===== INSTALL NWB LIBRARY =====
% If folders exists: delete
if isdir(NWBDir)
    file_delete(NWBDir, 1, 3);
end
if isdir(NWBTmpDir)
    file_delete(NWBTmpDir, 1, 3);
end
% Create folder
mkdir(NWBTmpDir);
% Download file
zipFile = bst_fullfile(NWBTmpDir, 'NWB.zip');
errMsg = gui_brainstorm('DownloadFile', url, zipFile, 'NWB download');

% Check if the download was succesful and try again if it wasn't
time_before_entering = clock;
updated_time = clock;
time_out = 60;% timeout within 60 seconds of trying to download the file

% Keep trying to download until a timeout is reached
while etime(updated_time, time_before_entering) <time_out && ~isempty(errMsg)
    % Try to download until the timeout is reached
    pause(0.1);
    errMsg = gui_brainstorm('DownloadFile', url, zipFile, 'NWB download');
    updated_time = clock;
end
% If the timeout is reached and there is still an error, abort
if etime(updated_time, time_before_entering) >time_out && ~isempty(errMsg)
    errMsg = ['Impossible to download NWB.' 10 errMsg];
    return;
end

% Unzip file
bst_progress('start', 'NWB', 'Installing NWB...');
unzip(zipFile, NWBTmpDir);
% Get parent folder of the unzipped file
diropen = dir(NWBTmpDir);
idir = find([diropen.isdir] & ~cellfun(@(c)isequal(c(1),'.'), {diropen.name}), 1);
newNWBDir = bst_fullfile(NWBTmpDir, diropen(idir).name);
% Move NWB directory to proper location
file_move(newNWBDir, NWBDir);
% Delete unnecessary files
file_delete(NWBTmpDir, 1, 3);

% Matlab needs to restart before initialization
NWB_initialized = 0;
save(bst_fullfile(NWBDir,'NWB_initialized.mat'), 'NWB_initialized');

% Once downloaded, we need to restart Matlab to refresh the java path
if isInteractive
    java_dialog('warning', ...
        ['The NWB importer was successfully downloaded.' 10 10 ...
         'Both Brainstorm AND Matlab need to be restarted in order to load the JAR file.'], 'NWB');
end
errMsg = 'Please restart Matlab to reload the Java path.';




