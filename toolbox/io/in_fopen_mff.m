function [sFile, ChannelMat] = in_fopen_mff(DataFile, ImportOptions)
% IN_FOPEN_MFF: Open a Philips .MFF file

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
% Authors: Martin Cousineau, 2018

if bst_get('MatlabVersion') < 803
    error('Importing MFF files requires at least Matlab 2014a.');
end

%% ===== PARSE INPUTS =====
if strcmp(DataFile, 'downloadAndInstallMffLibrary')
    downloadAndInstallMffLibrary();
    return;
end
if (nargin < 2) || isempty(ImportOptions)
    ImportOptions = db_template('ImportOptions');
end

%% ===== DOWNLOAD JAR =====
downloadAndInstallMffLibrary();

%% ===== READ MFF FILE WITH EEGLAB PLUGIN =====
hdr = struct();
hdr.filename = DataFile;
hdr.EEG = mff_import(DataFile);

%% ===== IMPORT FILE USING EEGLAB IMPORTER =====
[sFile, ChannelMat] = in_fopen_eeglab(hdr, ImportOptions);
sFile.format       = 'EEG-EGI-MFF';
sFile.device       = 'MFF';
if ~isempty(ChannelMat)
    ChannelMat.Comment = strrep(ChannelMat.Comment, 'EEGLAB', 'MFF');
end

end


%% ===== DOWNLOAD MFF JAR FILE =====
function downloadAndInstallMffLibrary()
    % Check whether JAR file is in Java path
    [jarPath, jarExists] = bst_get('MffJarFile');
    mffDir = fileparts(jarPath);
    javaPath = javaclasspath('-dynamic');
    if any(strcmp(javaPath, jarPath))
        % Add library to Matlab path
        addpath(genpath(mffDir));
        return;
    end
    
    % Download library if missing
    if ~jarExists
        % Prompt user
        isOk = java_dialog('confirm', ...
            ['Reading MFF files requires to download the MFFMatlabIO library.' 10 10 ...
             'Would you like to download it right now?'], 'MFF');
        if ~isOk
            return;
        end
        
        % If folders exists: delete
        mffDirTmp = bst_fullfile(bst_get('BrainstormUserDir'), 'mffTmp');
        if isdir(mffDir)
            file_delete(mffDir, 1, 3);
        end
        if isdir(mffDirTmp)
            file_delete(mffDirTmp, 1, 3);
        end
        % Create folder
        mkdir(mffDir);
        mkdir(mffDirTmp);

        zipFile = 'mffmatlabio-1.2.2.zip';
        url = ['https://neuroimage.usc.edu/bst/getupdate.php?d=' zipFile];
        % Download file
        zipPath = bst_fullfile(mffDirTmp, zipFile);
        errMsg = gui_brainstorm('DownloadFile', url, zipPath, 'MFF library download');
        if ~isempty(errMsg)
            error(['Impossible to download MFF library: ' errMsg]);
        end
        % Unzip file
        unzip(zipPath, mffDirTmp);
        % Move content of zip to proper location
        libDir = bst_fullfile(mffDirTmp, 'mffmatlabio-master', '*');
        movefile(libDir, mffDir);
        % Delete zip
        file_delete(mffDirTmp, 1, 3);
    end
    
    % Once downloaded, we need to restart Matlab to refresh the java path
    java_dialog('warning', ...
        ['The MFF importer was successfully downloaded.' 10 10 ...
         'Both Brainstorm AND Matlab need to be restarted in order to load the JAR file.'], 'MFF');
    error('Please restart Matlab to reload the Java path.');
end
