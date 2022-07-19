function lock_release(varargin)
% LOCK_RELEASE: Release (delete) an existing lock.
%
% USAGE:
%    - lock_release(sqlConn, LockIds) or 
%    - lock_release(LockIds) 
%
%
% SEE ALSO lock_acquire lock_read
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
    error(['Usage : lock_release(LockIds) ' 10 '        lock_release(sqlConn, LockIds)']);
end

LockIds = varargin{1};
if isempty(LockIds)
    return;
end

%% ==== DELETE LOCKS ==== 
try
    for i = 1:length(LockIds)
        LockId = LockIds(i);
        sql_query(sqlConn, 'DELETE', 'Lock', struct('Id', LockId));
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
