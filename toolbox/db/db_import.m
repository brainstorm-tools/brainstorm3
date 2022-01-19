function nProtocols = db_import(BrainstormDbDir)
% DB_IMPORT: Import a full database from a folder on the hard-drive
%
% USAGE:  db_import(BrainstormDbDir)
%         db_import()                : Ask for the database directory

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

% Authors: Francois Tadel, 2010

% No directory specified
nProtocols = 0;
if (nargin < 1) || isempty(BrainstormDbDir)
    % Default directory
    if ispc
        defDir = 'C:\';
    else
        defDir = bst_get('UserDir');
    end
    % Open 'Select directory' dialog
    BrainstormDbDir = bst_uigetdir(defDir, 'Please select database directory.');
    if isempty(BrainstormDbDir) || ~ischar(BrainstormDbDir)
        return
    end
end

% Get all the subfolders
files = dir(BrainstormDbDir);
dirList = files([files.isdir] == 1);
if isempty(dirList)
    return
end
iProtocols = [];

% Loop on each subfolder
for i = 1:length(dirList)
    % Ignore folders that start with a "."
    if (dirList(i).name(1) == '.')
        continue;
    end
    % Protocol folder
    ProtocolDir = bst_fullfile(BrainstormDbDir, dirList(i).name);
    % Try to get a subject folder and a study folder
    [subjectFile, iDepthSubject] = file_find(ProtocolDir, 'brainstormsubject*.mat', 3);
    [studyFile, iDepthStudy]     = file_find(ProtocolDir, 'brainstormstudy*.mat',   3);
    % If not both files are found, it's not a brainstorm protocol
    if isempty(subjectFile) || isempty(studyFile) || (iDepthSubject ~= 3) || (iDepthSubject ~= 3)
        continue;
    end
    
    % Initialize protocol structure
    sProtocol = db_template('ProtocolInfo');
    [tmp__,sProtocol.Comment] = bst_fileparts(ProtocolDir, 1);
    sProtocol.SUBJECTS = bst_fileparts(bst_fileparts(subjectFile), 1);
    sProtocol.STUDIES  = bst_fileparts(bst_fileparts(studyFile), 1);
    % Load protocol
    tmp = db_edit_protocol('load', sProtocol);
    if ~isempty(tmp) && ~isequal(tmp, -1)
        iProtocols(end+1) = tmp;
    end
end

% Select the last protocol
if ~isempty(iProtocols)
    gui_brainstorm('SetCurrentProtocol', iProtocols(1));
end



