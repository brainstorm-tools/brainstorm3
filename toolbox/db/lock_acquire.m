function NewLockId = lock_acquire(varargin)
% LOCK_ACQUIRE: Acquire (create) a new lock.
%
% USAGE:
%    - lock_acquire(sqlConn, args) or 
%    - lock_acquire(args) 
%
% ====== TYPES OF LOCKS ================================================================
%    - sSubjectLock = lock_acquire(LockName, SubjectId)
%    - sStudyLock   = lock_acquire(LockName, SubjectId, StudyId)
%    - sFileLock    = lock_acquire(LockName, SubjectId, StudyId, FileId)
%
%
% SEE ALSO lock_release lock_read
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

% HARD-CODED PARAMETERS:
% How long to wait (in seconds) before querying database again to check if
% lock now available.
waitTime = 30;
% Variability of above wait time (in seconds) in case multiple instances
% started at the same time. i.e. finalWaitTime = waitTime +/- [0, varTime]
varTime = 5;

%% ==== PARSE INPUTS ====
if (nargin > 2) && isjava(varargin{1})
    sqlConn = varargin{1};
    varargin(1) = [];
    handleConn = 0;
elseif (nargin >= 2) && ischar(varargin{1}) 
    sqlConn = sql_connect();
    handleConn = 1;
else
    error(['Usage : lock_acquire(args) ' 10 '        lock_acquire(sqlConn, args)']);
end

LockName = varargin{1};
SubjectId = varargin{2};

% Get subject ID
if ischar(SubjectId)
    sSubject = db_get(sqlConn, 'Subject', struct('Name', SubjectId), 'Id');
    SubjectId = sSubject.Id;
end

% Get study ID
if length(varargin) > 2
    StudyId = varargin{3};
    if ischar(StudyId)
        sStudy = db_get(sqlConn, 'Study', StudyId, 'Id');
        StudyId = sStudy.Id;
    end
else
    StudyId = [];
end

% Get file ID
if length(varargin) > 3
    FileId = varargin{4};
    if ischar(FileId)
        sFuncFile = db_get(sqlConn, 'FunctionalFile', FileId, 'Id');
        FileId = sFuncFile.Id;
    end
else
    FileId = [];
end

isOverride = 0;
isCancel = 0;
NewLockId = [];
isFirst = 1;

try
%%  ==== CREATE LOCK OR WAIT FOR ITS RELEASE ====
    while isFirst || isLocked
        if isFirst
            isFirst = 0;
        else
            % We'll be waiting for lock release, close connection for now.
            sql_close(sqlConn);
            % Open up progress bar with button to override lock
            bst_progress('start', 'Acquiring locks', ...
                ['<HTML>The requested file was locked by ' sLock.Username ' of ' ...
                sLock.Computer ' ' getLockTime(sLock.Time) ' ago.<BR>'  ...
                'Waiting for lock to be released to continue...']);
            bst_progress('setbutton', 'Override lock', @(h,ev) overrideLock(), ...
                'Cancel', @(h,ev) cancelOperation());

            % Wait for ~1 minute.
            elapsedTime = waitTime + randi([-varTime,varTime],1);
            tStart = tic;

            % Busy waiting to check status of override button
            while toc(tStart) < elapsedTime && ~isOverride && ~isCancel
                pause(0.5);
            end
            bst_progress('stop');

            % If cancel button is pressed, stop execution
            if isCancel
                return;
            end
            sqlConn = sql_connect();
            % If override button is pressed, remove existing locks and continue
            if isOverride
                lock_release(sqlConn, sLock.Id);
            end
        end

        % Check whether a lock already exists on this object
        sLock = lock_read(sqlConn, SubjectId, StudyId, FileId);
        isLocked = ~isempty(sLock);
        if isLocked
            continue;
        end

        % Generate lock
        LockData = struct(...
            'Subject',   SubjectId, ...
            'Username',  bst_get('UserName'), ...
            'Computer',  bst_get('ComputerName'), ...
            'Time',      datestr(datetime('now', 'TimeZone', 'UTC')), ...
            'Operation', LockName);
        if ~isempty(StudyId)
            LockData.Study = StudyId;
        end
        if ~isempty(FileId)
            LockData.File = FileId;
        end

        % Add lock
        LockId = sql_query(sqlConn, 'INSERT', 'Lock', LockData);

        % Query again to make sure lock is still unique!
        sLock = lock_read(sqlConn, SubjectId, StudyId, FileId, LockId);
        isLocked = ~isempty(sLock);

        if isLocked
            % Another lock was acquired, abort...
            lock_release(sqlConn, LockId);
        else
            NewLockId = LockId;
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

function overrideLock()
    res = java_dialog('question', ['Are you sure you want to override the existing lock?' 10 ...
        'Only do this if you know what you are doing (for example, Brainstorm crashed).' 10 ...
        'USE AT YOUR OWN RISK, THIS COULD CORRUPT YOUR DATABASE.'], 'Override lock');
    if strcmpi(res, 'yes')
        isOverride = 1;
    end
end

function cancelOperation()
    isCancel = 1;
end
end

function timestr = getLockTime(LockDate)
    % Compare lock time and current time in UTC-0
    lockTime = datetime(LockDate, 'TimeZone', 'UTC');
    currentTime = datetime('now', 'TimeZone', 'UTC');
    lockDuration = currentTime - lockTime;
    
    % Extract hours and minutes
    lockHours = mod(floor(hours(lockDuration)), 24);
    lockMinutes = mod(ceil(minutes(lockDuration)), 60);
    
    timestr = [];
    if lockHours > 0
        timestr = sprintf('%d hour', lockHours);
        if lockHours > 1
            timestr = [timestr 's'];
        end
        timestr = [timestr ' '];
    end
    timestr = [timestr sprintf('%d minute', lockMinutes)];
    if lockMinutes > 1
        timestr = [timestr 's'];
    end
end
