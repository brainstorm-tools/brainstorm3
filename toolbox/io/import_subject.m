function import_subject(ZipFile)
% IMPORT_SUBJECT Import subjects from a zip file into the current protocol.
% 
% USAGE:  import_subject(ZipFile=[ask])

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
% Authors: Francois Tadel, 2015; Martin Cousineau, 2019

global GlobalData

%% ===== PARSE INPUTS =====
if (nargin < 1)
    ZipFile = [];
end
% File selection
if isempty(ZipFile)
    % Select folder file
    ZipFile = java_getfile('open', 'Import subjects...', '', 'single', 'files', {{'.zip'}, 'Brainstorm subjects (*.zip)', 'protocol'}, 1);
    if isempty(ZipFile)
        return
    end
end
% Get current protocol folders
ProtocolInfo = bst_get('ProtocolInfo');
iProtocol = bst_get('iProtocol');


%% ===== UNZIP =====
% Get temporary folder
ProtocolDir = bst_fullfile(bst_get('BrainstormTmpDir'), 'LoadedProtocol');
% Delete existing folder
if file_exist(ProtocolDir)
    file_delete(ProtocolDir, 1, 3);
end
% Create output folder
isOk = mkdir(ProtocolDir);
if ~isOk
    bst_error(['Could not create folder: ' ProtocolDir], 'Import subjects', 0);
    return
end
% Progress bar
bst_progress('start', 'Import subjects', 'Unzipping file...');
% Unzip file
isOk = org.brainstorm.file.Unpack.unzip(ZipFile, ProtocolDir);
if ~isOk
    bst_error('Could not unzip file.', 'Import subjects', 0);
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
    return;
end
% Extract first level of subdir
subjectDirList = str_split(strrep(subjectFile, ProtocolDir, ''));
studyDirList   = str_split(strrep(studyFile, ProtocolDir, ''));
tmpSUBJECTS = bst_fullfile(ProtocolDir, subjectDirList{1});
tmpSTUDIES  = bst_fullfile(ProtocolDir, studyDirList{1});
% Get list of subjects
subjectFolders = dir(bst_fullfile(tmpSUBJECTS, '*'));
subjectNames = {};
for i = 1:length(subjectFolders)
    % Not a subject folder: skip
    if (~subjectFolders(i).isdir) || (subjectFolders(i).name(1) == '.') || isequal(subjectFolders(i).name, bst_get('DirDefaultSubject'))
        continue;
    end
    % Add to the list of subject names
    subjectNames{end+1} = subjectFolders(i).name;
end

%% ===== COPY SUBJECTS =====
errMsg = [];
isReload = 0;
% Loop on subjects
for i = 1:length(subjectNames)
    bst_progress('text', ['Copying subject "' subjectNames{i} '"...']);
    % Subject folders
    tmpSubjectDir = bst_fullfile(tmpSUBJECTS, subjectNames{i});
    tmpStudyDir   = bst_fullfile(tmpSTUDIES, subjectNames{i});
    % If the folder does not exist both in the anat and data folders: skip
    if ~file_exist(tmpSubjectDir) || ~file_exist(tmpStudyDir)
        errMsg = [errMsg, 'Invalid protocol structure for subject "' subjectNames{i} '". Skipping...' 10 ];
        continue;
    end
    % Get the subject file
    SubjectFile = file_find(tmpSubjectDir, 'brainstormsubject*.mat', 1);
    if isempty(SubjectFile)
        errMsg = [errMsg, 'Invalid protocol structure for subject "' subjectNames{i} '". Skipping...' 10 ];
        continue;
    end
    % Check the subject configuration
    SubjectMat = load(SubjectFile);
    if (SubjectMat.UseDefaultAnat == 1) || (SubjectMat.UseDefaultChannel == 1)
        errMsg = [errMsg, 'Subjects using a default anatomy or channel file cannot be imported in an existing protocol.' 10 ...
                          'Use the menu: File > Load protocol > Load from zip file.'];
        continue;
    end
    % If the subject name already exists in current protocol
    sSubject = bst_get('Subject', subjectNames{i});
    if ~isempty(sSubject)
        errMsg = [errMsg, 'Subject "' subjectNames{i} '" already exists in current protocol. Skipping...'];
        continue;
    end
    % Get destination folders
    destSubjectDir = bst_fullfile(ProtocolInfo.SUBJECTS, subjectNames{i});
    destStudyDir   = bst_fullfile(ProtocolInfo.STUDIES, subjectNames{i});
    % If the destination folders already exist: error
    if file_exist(destSubjectDir) || file_exist(destStudyDir)
        errMsg = [errMsg, 'Subject "' subjectNames{i} '" already exists in current protocol. Skipping...'];
        continue;
    end
    % Copy the anat folder
    isOk = file_copy(tmpSubjectDir, destSubjectDir);
    if ~isOk
        errMsg = [errMsg, 'Could not create subject folder: ' destSubjectDir];
        continue;
    end
    % Copy the data folder
    isOk = file_copy(tmpStudyDir, destStudyDir);
    if ~isOk
        errMsg = [errMsg, 'Could not create study folder: ' destStudyDir];
        continue;
    end
    % Reload the database
    isReload = 1;
end
% Reload the database
if isReload
    db_reload_database(iProtocol);
end
% If an error occured: display a message
if ~isempty(errMsg)
    bst_error(errMsg, 'Import subjects', 0);
end

%% ===== UPDATE SUBJECT DATABASE =====
protocolFile = bst_fullfile(ProtocolDir, 'data', 'protocol.mat');
CurrentDbVersion = [];
if file_exist(protocolFile)
    ProtocolMat = load(protocolFile);
    if isfield(ProtocolMat, 'DbVersion') && ~isempty(ProtocolMat.DbVersion)
        CurrentDbVersion = ProtocolMat.DbVersion;
    end
end
if isempty(CurrentDbVersion)
    % No protocol file in extracted subject, meaning this was before
    % db_update 2019, so assume it is the previous major database version
    CurrentDbVersion = 4.0;
end
LatestDbVersion = GlobalData.DataBase.DbVersion;
GlobalData.DataBase.DbVersion = CurrentDbVersion;
db_update(LatestDbVersion, iProtocol, 0);
GlobalData.DataBase.DbVersion = LatestDbVersion;

% Delete temporary folder
file_delete(ProtocolDir, 1, 3);
% Close progress bar
bst_progress('stop');


