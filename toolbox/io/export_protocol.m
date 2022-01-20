function export_protocol(iProtocol, iSubject, OutputFile)
% EXPORT_PROTOCOL: Export a protocol into a zip file.
% 
% USAGE:  export_protocol(iProtocol, iSubject, OutputFile) 
%         export_protocol(iProtocol, iSubject)        : Ask for the output filename
%         export_protocol(iProtocol)                  : Export all the subjects of protocol, ask for the output filename
%         export_protocol()                           : Export current protocol, ask for the output filename

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
% Authors: Francois Tadel, 2012-2015; Martin Cousineau, 2019

global GlobalData;

%% ===== PARSE INPUTS =====
if (nargin < 3)
    OutputFile = [];
end
if (nargin < 2)
    iSubject = [];
end
if (nargin < 1) || isempty(iProtocol)
    iProtocol = bst_get('iProtocol');
else
    gui_brainstorm('SetCurrentProtocol', iProtocol);
end
% Check protocol indice
if isempty(iProtocol) || (iProtocol == 0)
    bst_error('Invalid protocol indice.', 'Export protocol', 0); 
    return
end
% Get protocol description
ProtocolInfo = bst_get('ProtocolInfo');
% Get output filename
if isempty(OutputFile)
    % Get default directories
    LastUsedDirs = bst_get('LastUsedDirs');
	% Default output filename
    if isempty(iSubject)
        OutputFile = bst_fullfile(LastUsedDirs.ExportProtocol, file_standardize([ProtocolInfo.Comment, '.zip']));
    else
        sSubject = bst_get('Subject', iSubject);
        OutputFile = bst_fullfile(LastUsedDirs.ExportProtocol, file_standardize([ProtocolInfo.Comment, '_', sSubject.Name, '.zip']));
    end
    % File selection
    OutputFile = java_getfile('save', 'Export protocol', OutputFile, 'single', 'files', ...
                              {{'.zip'}, 'Zip files (*.zip)', 'ZIP'}, 1);
    if isempty(OutputFile)
        return
    end
    % Save new default export path
    LastUsedDirs.ExportProtocol = bst_fileparts(OutputFile);
    bst_set('LastUsedDirs', LastUsedDirs);
end
% Force saving database
db_save(1);


%% ===== ZIP FILES =====
% Progress bar
bst_progress('start', 'Export protocol', 'Creating zip file...');
% Cd to protocol folder
prevFolder = pwd;
cd(bst_fileparts(ProtocolInfo.SUBJECTS, 1));
% Prefixes to add to the folders
[tmp__, anatFolder] = bst_fileparts(ProtocolInfo.SUBJECTS, 1);
[tmp__, dataFolder] = bst_fileparts(ProtocolInfo.STUDIES, 1);
% Build list of files to zip
if isempty(iSubject)
    % Add the entire subject folder
    ListZip = {anatFolder};
    % List files in studies: add all files
    allFiles = dir(ProtocolInfo.STUDIES);
    for i = 1:length(allFiles)
        if (allFiles(i).name(1) ~= '.')
            ListZip{end+1} = bst_fullfile(dataFolder, allFiles(i).name);
        end
    end
else
    % Get default study for this subject
    sSubject = bst_get('Subject', iSubject, 1);
    sStudy   = bst_get('AnalysisIntraStudy', iSubject);
    % Create a temporary protocol.mat for future database update information
    ProtocolMat = struct();
    ProtocolMat.ProtocolInfo      = GlobalData.DataBase.ProtocolInfo(iProtocol);
    ProtocolMat.ProtocolSubjects  = GlobalData.DataBase.ProtocolSubjects(iProtocol);
    ProtocolMat.ProtocolStudies   = GlobalData.DataBase.ProtocolStudies(iProtocol);
    ProtocolMat.DbVersion         = GlobalData.DataBase.DbVersion;
    ProtocolMat.LastAccessDate    = datestr(now);
    ProtocolMat.LastAccessUserDir = bst_get('UserDir');
    % Remove useless fields
    StudyDir = ProtocolMat.ProtocolInfo.STUDIES;
    ProtocolMat.ProtocolInfo = rmfield(ProtocolMat.ProtocolInfo, 'STUDIES');
    ProtocolMat.ProtocolInfo = rmfield(ProtocolMat.ProtocolInfo, 'SUBJECTS');
    ProtocolMat.ProtocolSubjects.Subject = ProtocolMat.ProtocolSubjects.Subject(iSubject);
    [sStudies, iStudies] = bst_get('StudyWithSubject', ProtocolMat.ProtocolSubjects.Subject.FileName, 'default_study', 'intra_subject');
    ProtocolMat.ProtocolStudies.Study = ProtocolMat.ProtocolStudies.Study(iStudies);
    ProtocolFile = bst_fullfile(dataFolder, 'protocol.mat');
    bst_save(ProtocolFile, ProtocolMat, 'v7');
    % List all files that might be useful for this subject
    ListZip = {bst_fullfile(anatFolder, bst_fileparts(sSubject.FileName)), ...
               bst_fullfile(anatFolder, bst_get('DirDefaultSubject')), ...
               bst_fullfile(dataFolder, bst_fileparts(bst_fileparts(sStudy.FileName))), ...
               bst_fullfile(dataFolder, bst_get('DirDefaultStudy')), ...
               bst_fullfile(dataFolder, bst_get('DirAnalysisInter')), ...
               ProtocolFile};
end
% Zip
zip(OutputFile, ListZip);
% Restore protocol file
if ~isempty(iSubject)
    % Remove temporary protocol file
    file_delete(bst_fullfile(StudyDir, 'protocol.mat'), 1);
    % Save again the original one
    GlobalData.DataBase.isProtocolModified(iProtocol) = 1;
    db_save(1);
end
% Restore initial folder
cd(prevFolder);
% Close progress bar
bst_progress('stop');



