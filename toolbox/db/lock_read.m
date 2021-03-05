function sLock = lock_read(sqlConnection, SubjectId, StudyId, FileId, ExcludeLockId)
% LOCK_READ: Reads an active lock on a given subject/study/file.
%
% USAGE: sSubjectLock   = lock_read(sqlConn, SubjectId)
%        sStudyLock     = lock_read(sqlConn, SubjectId, StudyId)
%        sFileLock      = lock_read(sqlConn, SubjectId, StudyId, FileId)
%        sDifferentLock = lock_read(sqlConn, SubjectId, StudyId, FileId, ExistingLockId)

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
% Authors: Martin Cousineau, 2020

if isempty(sqlConnection)
    closeConnection = 1;
    sqlConnection = sql_connect();
else
    closeConnection = 0;
end

% Exclude an existing lock ID from query if requested
if nargin < 5 || isempty(ExcludeLockId)
    IdQuery = '';
else
    IdQuery = ['AND Id <> ' num2str(ExcludeLockId)];
end

% Parse other inputs
if nargin < 4
    FileId = [];
end
if nargin < 3
    StudyId = [];
end

% Check for subject lock
if isempty(StudyId) && isempty(FileId)
    % We want a new whole subject lock, make sure no existing lock
    % relates to this subject
    sLock = sql_query(sqlConnection, 'select', 'lock', '*', struct('Subject', SubjectId), IdQuery);
else
    % Check for existing whole subject lock
    sLock = sql_query(sqlConnection, 'select', 'lock', '*', struct('Subject', SubjectId), ...
        [IdQuery ' AND Study IS NULL AND File IS NULL']);
end

% Check for whole study lock
if isempty(sLock) && ~isempty(StudyId)
    if isempty(FileId)
        % We want a whole new study lock, make sure no existing lock
        % relates to this study
        sLock = sql_query(sqlConnection, 'select', 'lock', '*', struct('Study', StudyId), IdQuery);
    else
        % Check for existing whole study lock
        sLock = sql_query(sqlConnection, 'select', 'lock', '*', struct('Study', StudyId), ...
            [IdQuery ' AND File IS NULL']);
    end
end

% Check for file lock
if isempty(sLock) && ~isempty(FileId)
    sLock = sql_query(sqlConnection, 'select', 'lock', '*', struct('File', FileId), IdQuery);
end

if closeConnection
    sql_close(sqlConnection);
end
