function sLock = lock_read(varargin)
% LOCK_READ: Reads an active lock on a given subject/study/file.
%
% USAGE:
%    - lock_read(sqlConn, args) or 
%    - lock_read(args) 
%
% ====== TYPES OF LOCKS ================================================================
%    - sSubjectLock   = lock_read(SubjectId)
%    - sStudyLock     = lock_read(SubjectId, StudyId)
%    - sFileLock      = lock_read(SubjectId, StudyId, FileId)
%    - sDifferentLock = lock_read(SubjectId, StudyId, FileId, ExistingLockId)
%
%
% SEE ALSO lock_acquire lock_release
%
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
%          Raymundo Cassani, 2021

%% ==== PARSE INPUTS ====
if (nargin > 1) && isjava(varargin{1})
    sqlConn = varargin{1};
    varargin(1) = [];
    handleConn = 0;
elseif (nargin >= 1) && isnumeric(varargin{1}) 
    sqlConn = sql_connect();
    handleConn = 1;
else
    error(['Usage : lock_read(args) ' 10 '        lock_read(sqlConn, args)']);
end

SubjectId = varargin{1};

StudyId = [];
FileId = [];
IdQuery = '';

if length(varargin) > 1
    StudyId = varargin{2};
    if length(varargin) > 2
        FileId = varargin{3};
        % Exclude an existing lock ID from query if requested
        if length(varargin) > 3 
            IdQuery = ['AND Id <> ' num2str(varargin{4})];
        end
    end
end    

try
    %%  ==== READ LOCK ====
    % Check for subject lock
    if isempty(StudyId) && isempty(FileId)
        % We want a new whole subject lock, make sure no existing lock
        % relates to this subject
        sLock = sql_query(sqlConn, 'SELECT', 'Lock', struct('Subject', SubjectId), '*', IdQuery);
    else
        % Check for existing whole subject lock
        sLock = sql_query(sqlConn, 'SELECT', 'lock', struct('Subject', SubjectId), '*', ...
            [IdQuery ' AND Study IS NULL AND File IS NULL']);
    end

    % Check for whole study lock
    if isempty(sLock) && ~isempty(StudyId)
        if isempty(FileId)
            % We want a whole new study lock, make sure no existing lock
            % relates to this study
            sLock = sql_query(sqlConn, 'SELECT', 'Lock', struct('Study', StudyId), '*', IdQuery);
        else
            % Check for existing whole study lock
            sLock = sql_query(sqlConn, 'SELECT', 'Lock', struct('Study', StudyId), '*', ...
                [IdQuery ' AND File IS NULL']);
        end
    end

    % Check for file lock
    if isempty(sLock) && ~isempty(FileId)
        sLock = sql_query(sqlConn, 'SELECT', 'Lock', struct('File', FileId), '*', IdQuery);
    end

    % Check for parent file lock
    if isempty(sLock) && ~isempty(FileId)
        ParentId = FileId;
        while 1
            sFuncFileParent = db_get(sqlConn, 'FunctionalFile', ParentId, 'ParentFile');
            if isempty(sFuncFileParent) || isempty(sFuncFileParent.ParentFile)
                break;
            end

            ParentId = sFuncFileParent.ParentFile;
            sLock = sql_query(sqlConn, 'SELECT', 'Lock', struct('File', ParentId), '*', IdQuery);
            if ~isempty(sLock)
                break;
            end
        end
    end
catch ME
    % Close SQL connection if error
    sql_close(sqlConn);
    rethrow(ME)
end

% Close SQL connection if it was created
if handleConn
    sql_close(sqlConn);
end
