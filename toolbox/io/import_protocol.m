function import_protocol(ZipFile)
% IMPORT_PROTOCOL: Import a protocol from a zip file.
% 
% USAGE:  import_protocol(ZipFile)
%         import_protocol()             : Ask for the protocol filename

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2012-2019

global GlobalData;

%% ===== PARSE INPUTS =====
if (nargin < 1)
    ZipFile = [];
end
% File selection
if isempty(ZipFile)
    % Select folder file
    ZipFile = java_getfile('open', 'Load protocol...', '', 'single', 'files', {{'.zip'}, 'Brainstorm protocol (*.zip)', 'protocol'}, 1);
    if isempty(ZipFile)
        return
    end
end
% Get database folder
BrainstormDbDir = bst_get('BrainstormDbDir');


%% ===== CHECK PROTOCOL =====
% Get protocol name
[tmp__, ProtocolName] = bst_fileparts(ZipFile);
% Check if existing protocol with this name
while any(strcmpi({GlobalData.DataBase.ProtocolInfo.Comment}, ProtocolName))
    ProtocolName = java_dialog('input', ['Protocol "' ProtocolName '" already exists in database.' 10 10 ...
                      'Please enter another name for the loaded protocol:'], 'Load protocol', [], ProtocolName);
    if isempty(ProtocolName)
        return;
    end
end
% Build protocol folder
ProtocolDir = bst_fullfile(BrainstormDbDir, ProtocolName);
% Check if folder already exist
if file_exist(ProtocolDir)
    bst_error(sprintf(['Folder ''%s'' already exists in database.' 10 ...
                       'Please rename the zip file before importing it.'], ProtocolDir), 'Load protocol', 0);     
    return;
end

%% ===== UNZIP =====
% Progress bar
bst_progress('start', 'Load protocol', 'Unzipping file...');
% Create output folder
isOk = mkdir(ProtocolDir);
if ~isOk
    bst_error(['Could not create folder: ' ProtocolDir], 'Load protocol', 0);
    return
end
% Unzip file
isOk = org.brainstorm.file.Unpack.unzip(ZipFile, ProtocolDir);
if ~isOk
    bst_error('Could not unzip file.', 'Load protocol', 0);
    return
end


%% ===== DETECT FOLDERS =====
% Detect anatomy and datasets folders
subjectFile = file_find(ProtocolDir, 'brainstormsubject*.mat', 3);
studyFile   = file_find(ProtocolDir, 'brainstormstudy*.mat',   4);
% If not both files are found, exit
if isempty(subjectFile) || isempty(studyFile)
    bst_error(['Selected directory is not a valid protocol directory.' 10 10 ...
               'A protocol directory must contain at least two subdirectories: ' 10 ...
               'one for the subjects'' anatomies, and one for the recordings/results.'], ...
              'Import subjects', 0);
    file_delete(ProtocolDir, 1, 3);
    return
end
% Extract first level of subdir
subjectDirList = str_split(strrep(subjectFile, ProtocolDir, ''));
studyDirList   = str_split(strrep(studyFile, ProtocolDir, ''));
subjectDir = bst_fullfile(ProtocolDir, subjectDirList{1});
studyDir   = bst_fullfile(ProtocolDir, studyDirList{1});
bst_progress('stop');

        
%% ===== LOAD PROTOCOL =====
% Create protocol structure
sProtocol = db_template('ProtocolInfo');
sProtocol.Comment  = ProtocolName;
sProtocol.SUBJECTS = subjectDir;
sProtocol.STUDIES  = studyDir;
% Copy informatin from the protocol.mat in this protocol
protocolFile = bst_fullfile(ProtocolDir, 'data', 'protocol.mat');
if file_exist(protocolFile)
    ProtocolMat = load(protocolFile);
    if isfield(ProtocolMat, 'ProtocolInfo')
        if isfield(ProtocolMat.ProtocolInfo, 'iStudy') && ~isempty(ProtocolMat.ProtocolInfo.iStudy)
            sProtocol.iStudy = ProtocolMat.ProtocolInfo.iStudy;
        end
        if isfield(ProtocolMat.ProtocolInfo, 'UseDefaultAnat') && ~isempty(ProtocolMat.ProtocolInfo.UseDefaultAnat)
            sProtocol.UseDefaultAnat = ProtocolMat.ProtocolInfo.UseDefaultAnat;
        end
        if isfield(ProtocolMat.ProtocolInfo, 'UseDefaultChannel') && ~isempty(ProtocolMat.ProtocolInfo.UseDefaultChannel)
            sProtocol.UseDefaultChannel = ProtocolMat.ProtocolInfo.UseDefaultChannel;
        end
    end
end
% Load the protocol in Brainstorm database
iProtocol = db_edit_protocol('load', sProtocol);
% Set current protocol
gui_brainstorm('SetCurrentProtocol', iProtocol);


end


