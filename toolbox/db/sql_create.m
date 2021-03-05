function sql_create(sqlConnection, tables, dbInfo)
% SQL_CLOSE: Create SQL tables

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

% Set this to 1 if you want to print the query for debugging
debug = 1;

if nargin < 3 || isempty(dbInfo)
    dbInfo = sql_get_info();
end

if isempty(sqlConnection)
    closeConnection = 1;
    sqlConnection = sql_connect(dbInfo);
else
    closeConnection = 0;
end

% Find order in which to create tables that respects foreign keys
nTables = length(tables);
tablesLeft = 1:nTables;
iTables = [];
i = 0;
while ~isempty(tablesLeft)
    % Get first table in queue
    iTable = tablesLeft(1);
    tablesLeft(1) = [];
    foundConflict = 0;
    
    % Find foreign keys
    for iField = 1:length(tables(iTable).Fields)
        if ~isempty(tables(iTable).Fields(iField).ForeignKey)
            % Make sure table of foreign key already exists
            foreignTable = tables(iTable).Fields(iField).ForeignKey{1};
            if ~strcmp(tables(iTable).Name, foreignTable) && ...
                    ~ismember(foreignTable, {tables(iTables).Name})
                foundConflict = 1;
                break;
            end
        end
    end
    
    % If we have a conflict, send table to back of the queue
    if foundConflict
        tablesLeft(end + 1) = iTable;
    else
        iTables(end + 1) = iTable;
    end
    
    % Track iteration to avoid infinite loops
    i = i + 1;
    if i > 1000
        error('Could not resolve foreign key conflicts.');
    end
end
tables = tables(iTables);

switch (dbInfo.Rdbms)
    case 'sqlite'
        % Generate SQLite CREATE TABLE query
        sqlQry = '';
        for iTable = 1:length(tables)
            tblQry = ['CREATE TABLE IF NOT EXISTS "' tables(iTable).Name '" ('];
            foreignQry = '';
            foundPrimaryKey = 0;
            for iField = 1:length(tables(iTable).Fields)
                if iField > 1
                    tblQry = [tblQry ', '];
                end
                % Figure out the field type
                switch lower(tables(iTable).Fields(iField).Type)
                    case {'str', 'text'}
                        fieldType = 'TEXT';
                    case {'int', 'integer', 'bool', 'boolean'}
                        fieldType = 'INTEGER';
                    case {'real', 'float', 'double'}
                        fieldType = 'REAL';
                    otherwise
                        error(['Unsupported field type: ' tables(iTable).Fields(iField).Type]);
                end
                tblQry = [tblQry '"' tables(iTable).Fields(iField).Name '" ' fieldType];
                
                if strcmpi(tables(iTable).PrimaryKey, tables(iTable).Fields(iField).Name)
                    tblQry = [tblQry ' PRIMARY KEY'];
                    foundPrimaryKey = 1;
                end
                if tables(iTable).Fields(iField).AutoIncrement
                    tblQry = [tblQry ' AUTOINCREMENT'];
                end
                if ~isempty(tables(iTable).Fields(iField).DefaultValue)
                    if isnumeric(tables(iTable).Fields(iField).DefaultValue)
                        tblQry = [tblQry ' DEFAULT ' num2str(tables(iTable).Fields(iField).DefaultValue)];
                    else
                        tblQry = [tblQry ' DEFAULT "' tables(iTable).Fields(iField).DefaultValue '"'];
                    end
                end
                if tables(iTable).Fields(iField).NotNull
                    tblQry = [tblQry ' NOT NULL'];
                end
                if ~isempty(tables(iTable).Fields(iField).ForeignKey)
                    foreignQry = [foreignQry ', FOREIGN KEY ("' tables(iTable).Fields(iField).Name '")' ...
                        ' REFERENCES "' tables(iTable).Fields(iField).ForeignKey{1} '"' ...
                        '("' tables(iTable).Fields(iField).ForeignKey{2} '") ON DELETE CASCADE'];
                end
                
            end
            
            if ~foundPrimaryKey && ~isempty(tables(iTable).PrimaryKey)
                error(['Could not find primary key of table ' tables(iTable).Name]);
            end
            
            tblQry = [tblQry foreignQry ');'];
            
            % Execute CREATE query using JDBC
            stmt = sqlConnection.createStatement();
            stmt.execute(tblQry);
            
            if debug
                disp(['Query: ' tblQry]);
            end
        end

    otherwise
        error('Unsupported relational database management system.');
end

if closeConnection
    sql_close(sqlConnection);
end
