function iItems = db_add_subfolder(iStudies, FolderName, iParent, isRefresh)
% DB_ADD_SUBFOLDER: Add a subfolder to one or multiple studies
%
% USAGE:  iItems = db_add_subfolder(iStudies, FolderName, isRefresh)
%         iItems = db_add_subfolder(iStudies, FolderName) : Refresh display by default
%         iItems = db_add_subfolder(iStudies)             : Ask FolderName to the user
% INPUT: 
%     - iStudies   : One or more study IDs
%     - FolderName : String, name of the subfolder to add.
%                    If empty or ommitted, asked to the user
%     - iParent    : File ID of the parent folder, or empty if directly in study
%     - isRefresh  : If 0, tree is not refreshed after adding condition
%                    If 1, tree is refreshed
% OUTPUT: 
%     - iItems : Indices of the files that were created. 
%                Returns [] if an error occurs

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
% Authors: Martin Cousineau, 2021


%% ===== PARSE INPUTS =====
iItems = [];
if (nargin < 4) || isempty(isRefresh)
    isRefresh = 1;
end
if (nargin < 3)
    iParent = [];
end
if (nargin < 2) || isempty(FolderName)
    FolderName = java_dialog('input', 'Folder name: ', 'New subfolder', [], 'NewFolder');
    if isempty(FolderName)
        return;
    end
end
if (nargin < 1) || isempty(iStudies)
    error('You must define the first argument "iStudy".');
end

ProtocolInfo = bst_get('ProtocolInfo');
% Normalize names (in order to create a directory out of it)
FolderName = file_standardize(FolderName, 1);
isModified = 0;


%% ===== CREATE FOLDERS =====
sqlConn = sql_connect();
for iStudy = iStudies
    sFile = db_template('FunctionalFile');
    sFile.Study = iStudy;
    sFile.Type = 'folder';
    sFile.Name = FolderName;
    
    if ~isempty(iParent)
        sFile.ParentFile = iParent;
        
        % Get parent name
        sFuncFileParent = db_get(sqlConn, 'FunctionalFile', iParent, 'FileName');
        sFile.FileName = bst_fullfile(sFuncFileParent.FileName, FolderName);
    else
        % Get Subject & Study names
        result = sql_query(sqlConn, ['SELECT Study.Name AS StudyName, Subject.Name AS SubjectName ' ...
            'FROM Study LEFT JOIN Subject ON Subject.Id = Study.Subject ' ...
            'WHERE Study.Id = ' num2str(iStudy)]);
        result.next();
        SubjectName = char(result.getString('SubjectName'));
        StudyName   = char(result.getString('StudyName'));
        result.close();
    
        sFile.FileName = bst_fullfile(SubjectName, StudyName, FolderName);
    end
    
    % Create folder
    FolderPath = bst_fullfile(ProtocolInfo.STUDIES, sFile.FileName);
    if ~file_exist(FolderPath)
        mkdir(FolderPath);
    end
    
    iItem = db_set(sqlConn, 'FunctionalFile', sFile);
    iItems(end + 1) = iItem;
end
sql_close(sqlConn);

%% ===== REFRESH DISPLAY =====
% Set default study to the last added study
ProtocolInfo.iStudy = iStudies(end);
bst_set('ProtocolInfo', ProtocolInfo);
% GUI update
if isRefresh
    % Redraw tree
    panel_protocols('UpdateTree');
end
% Save database
db_save();







