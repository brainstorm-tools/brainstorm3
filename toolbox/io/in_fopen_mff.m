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
if strcmp(DataFile, 'downloadAndInstallMffJar')
    downloadAndInstallMffJar();
    return;
end
if (nargin < 2) || isempty(ImportOptions)
    ImportOptions = db_template('ImportOptions');
end

%% ===== DOWNLOAD JAR =====
downloadAndInstallMffJar();

%% ===== READ MFF FILE WITH EEGLAB PLUGIN =====
hdr = struct();
hdr.filename = DataFile;
hdr.EEG = mff_import(DataFile);

%% ===== IMPORT FILE USING EEGLAB IMPORTER =====
[sFile, ChannelMat] = in_fopen_eeglab(hdr, ImportOptions);
sFile.format       = 'EEG-MFF';
sFile.device       = 'MFF';
if ~isempty(ChannelMat)
    ChannelMat.Comment = strrep(ChannelMat.Comment, 'EEGLAB', 'MFF');
end

end


%% ===== DOWNLOAD MFF JAR FILE =====
function downloadAndInstallMffJar()
    % Check whether JAR file is in Java path
    [jarPath, jarExists] = bst_get('MffJarFile');
    javaPath = javaclasspath('-dynamic');
    if any(strcmp(javaPath, jarPath))
        return;
    end
    
    % Download file if missing
    if ~jarExists
        % Prompt user
        isOk = java_dialog('confirm', ...
            ['The MFF importer requires a ~4.5MB JAR dependency file.' 10 10 ...
             'Would you like to download this file right now?'], 'MFF');
        if ~isOk
            return;
        end

        [jarDir, jarFile, jarExt] = fileparts(jarPath);
        url = ['https://neuroimage.usc.edu/bst/getupdate.php?d=', jarFile, jarExt];
        % If folders exists: delete
        if isdir(jarDir)
            file_delete(jarDir, 1, 3);
        end
        % Create folder
        mkdir(jarDir);
        % Download file
        errMsg = gui_brainstorm('DownloadFile', url, jarPath, 'MFF JAR download');
        if ~isempty(errMsg)
            error(['Impossible to download MFF JAR file: ' errMsg]);
        end
    end
    
    % Once downloaded, we need to restart Matlab to refresh the java path
    java_dialog('warning', ...
        ['The MFF importer was successfully downloaded.' 10 10 ...
         'Both Brainstorm AND Matlab need to be restarted in order to load the JAR file.'], 'MFF');
    error('Please restart Matlab to reload the Java path.');
end
