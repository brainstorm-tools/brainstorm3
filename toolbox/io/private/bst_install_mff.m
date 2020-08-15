function errMsg = bst_install_mff(isInteractive)
% BST_INSTALL_MFF Install, configure or update the library mffmatlabio for reading EGI-Philips .mff EEG files

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
% Author: Martin Cousineau, Francois Tadel, 2018-2020

%% ===== PRELIMINARY CHECKS =====
% Initialize returned variables
errMsg = [];
% Check Matlab version
if (bst_get('MatlabVersion') < 803)
    errMsg = 'Importing MFF files requires at least Matlab 2014a.';
    return;
end
% Not available in compiled version of Brainstorm
if (exist('isdeployed', 'builtin') && isdeployed)
    errMsg = 'Importing MFF files is not supported yet with the compiled version of Brainstorm.';
    return;
end
% Check if already available in path
if exist('mff_import', 'file')
    disp([10, 'mffmatlabio path: ', bst_fileparts(which('mff_import')), 10]);
    return;
end

%% ===== CHECK VERSION =====
% Current up-to-date version
mffVer  = 3.5;
zipFile = 'mffmatlabio-3.5.zip';
% Check whether JAR file is in Java path
[jarPath, jarExists] = bst_get('MffJarFile');
mffDir = fileparts(jarPath);
javaPath = javaclasspath('-dynamic');
needToUpdate = 0;
if any(strcmp(javaPath, jarPath))
    % Add library to Matlab path
    addpath(genpath(mffDir));
    % Check whether installed library is up to date
    if GetMffLibVersion() < mffVer
        needToUpdate = 1;
    else
        return;
    end
end

%% ===== DOWNLOAD LIBRARY =====
% Download library if missing
if ~jarExists || needToUpdate
    % Prompt user
    if isInteractive
        if needToUpdate
            diagMsg = 'An update to the MFFMatlabIO library is available.';
        else
            diagMsg = 'Reading MFF files requires to download the MFFMatlabIO library.';
        end
        isOk = java_dialog('confirm', ...
            [diagMsg 10 10 'Would you like to download it right now?'], 'MFF');
        if ~isOk
            errMsg = 'Installation aborted by user.';
            return;
        end
    end

    % If folder exists: delete
    mffDirTmp = bst_fullfile(bst_get('BrainstormUserDir'), 'mffmatlabioNew');
    if isdir(mffDirTmp)
        file_delete(mffDirTmp, 1, 3);
    end
    % Create folder
    mkdir(mffDirTmp);

    % URL to download
    url = ['http://neuroimage.usc.edu/bst/getupdate.php?d=' zipFile];
    % Download file
    zipPath = bst_fullfile(mffDirTmp, zipFile);
    errMsg = gui_brainstorm('DownloadFile', url, zipPath, 'MFF library download');
    if ~isempty(errMsg)
        return;
    end
    % Unzip file
    unzip(zipPath, mffDirTmp);
    % Delete zip
    file_delete(zipPath, 1);
end

% Once downloaded, we need to restart Matlab to refresh the java path
if isInteractive
    java_dialog('warning', ...
        ['The MFF importer was successfully downloaded.' 10 10 ...
         'Both Brainstorm AND Matlab need to be restarted in order to load the JAR file.'], 'MFF');
end
errMsg = 'Please restart Matlab to reload the Java path.';

end


%% ===== GET MFF LIBRARY VERSION =====
function mffver = GetMffLibVersion()
    defaultVer = 1;
    mffver = defaultVer;
    if exist('eegplugin_mffmatlabio', 'file') == 2
        try
            evalc('mffver = eegplugin_mffmatlabio;');
            mffver = str2num(mffver);
            if isempty(mffver)
                mffver = defaultVer;
            end
        catch
        end
    end
end

