function sqlConn = sql_connect(dbInfo)
% SQL_CONNECT: Connect to a SQL database with JDBC

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

debug = 1;
if nargin < 1 || isempty(dbInfo)
    dbInfo = sql_get_info();
end

if isempty(dbInfo.Location)
    error('No SQL database in memory.');
end

switch (dbInfo.Rdbms)
    case 'sqlite'
        % Create connection with JDBC
        sqliteDriver = org.sqlite.JDBC();
        props = java.util.Properties();
        sqlConn = sqliteDriver.connect(['jdbc:sqlite:' dbInfo.Location], props);
        
        % Set some SQLite properties to speed up remote queries
        statement = sqlConn.createStatement();
        statement.execute('PRAGMA synchronous=OFF; PRAGMA temp_store=MEMORY;');

    otherwise
        error('Unsupported relational database management system.');
end

if debug
    disp('DB> CONNECTED');
end