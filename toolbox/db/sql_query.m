function result = sql_query(varargin)
% SQL_QUERY: Execute a query on an SQLite database
%
% USAGE :
%    - sql_query(sqlConn, DirectQuery)
%    - sql_query(DirectQuery)
%    - sql_query(sqlConn, Action, Args)
%    - sql_query(Action, Args)
%
% ====== DIRECT QUERY ==========================================================
%    - sql_query(DirectQuery) % Excute a direct Query
%
% ====== SELECT ================================================================
%    - sql_query('SELECT', Table)                              % Get all Fields in all Rows in Table
%    - sql_query('SELECT', Table, Condition)                   % Get all Fields in Rows with Condition
%    - sql_query('SELECT', Table, Condition, Fields)           % Get Fields from Rows with Condition
%    - sql_query('SELECT', Table, Condition, Fields, AddQuery) % Get Fields in Rows with Condition observing AddQuery
%    - sql_query('SELECT', Table, Condition, [], AddQuery)     % Get all Fields in Rows with Condition observing AddQuery
%    - sql_query('SELECT', Table, [], Fields)                  % Get Fields from all Rows
%    - sql_query('SELECT', Table, [], Fields, AddQuery)        % Get Fields in all Rows observing AddQuery
%    - sql_query('SELECT', Table, [], [], AddQuery)            % Get all Fields in Rows observing AddQuery
%
% ====== EXIST =================================================================
%    - sql_query('EXIST', Table, Condition)                    % True if at least one Row with Condition exists
%    - sql_query('EXIST', Table, Condition, AddQuery)          % True if at least one Row with Condition observing AddQuery exists
%
% ====== INSERT ================================================================
%    - sql_query('INSERT', Table, Data)           % Insert Data into Table. Return inserted Id
%    - sql_query('INSERT', Table, Data, AddQuery) % Insert Data into Table observing AddQuery. Return inserted Id
%
% ====== UPDATE ================================================================
%    - sql_query('UPDATE', Table, Data)                      % Set Data into all Rows. Return # updated Rows
%    - sql_query('UPDATE', Table, Data, Condition)           % Set Data into Row with Condition. Return # updated Rows
%    - sql_query('UPDATE', Table, Data, Condition, AddQuery) % Set Data into Row with Condition observing AddQuery. Return # updated Rows
%
% ====== DELETE ================================================================
%    - sql_query('DELETE', Table)                      % Delete entire Table. Return # deleted Rows
%    - sql_query('DELETE', Table, Condition)           % Delete Rows with Condition. Return # deleted Rows
%    - sql_query('DELETE', Table, Condition, AddQuery) % Delete Rows with Condition observing AddQuery. Return # deleted Rows
%    - sql_query('DELETE', Table, [], AddQuery)        % Delete Rows observing AddQuery. Return # deleted Rows
%
% ====== COUNT =================================================================
%    - sql_query('COUNT', Table)                             % Count all Rows in Table
%    - sql_query('COUNT', Table, Condition)                  % Count Rows with Condition
%    - sql_query('COUNT', Table, Condition, Field)           % Count Rows with Condition and non-null values in Field
%    - sql_query('COUNT', Table, Condition, Field, AddQuery) % Count Rows with Condition and non-null values in Field observing AddQuery
%    - sql_query('COUNT', Table, Condition, [], AddQuery)    % Count Rows with Condition observing AddQuery
%    - sql_query('COUNT', Table, [], Field)                  % Count Rows with non-null values in Field
%    - sql_query('COUNT', Table, [], Field, AddQuery)        % Count Rows with non-null values in Field observing AddQuery
%    - sql_query('COUNT', Table, [], [], AddQuery)           % Count Rows observing AddQuery
%    Note: If Field is ['DISTINCT' Field], the returned Count is for unique non-null values
%
% ====== RESET-AUTOINC =========================================================
%    - sql_query('RESET-AUTOINCREMENT', Table)  % Reset ROWID for a given Table
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
%          Raymundo Cassani, 2022

% Set this to 1 if you want to print the query for debugging
debug = 1;

%% ==== PARSE INPUTS ====
if (nargin > 1) && isjava(varargin{1})
    sqlConn = varargin{1};
    varargin(1) = [];
    handleConn = 0;
elseif (nargin >= 1) && ischar(varargin{1})
    sqlConn = sql_connect();
    handleConn = 1;
else
    error(['Usage : sql_query(sqlConn, DirectQuery)' 10 ...
           '        sql_query(DirectQuery)' 10 ...
           '        sql_query(sqlConn, Action, Args)' 10 ...
           '        sql_query(Action, Args)']);
end

try
args = {};
% Following arguments
if length(varargin) > 1
    args = varargin(2:end);
end
nargs = length(args);

%% DIRECT QUERY CASE
if nargs < 1
    dirQuery = varargin{1};
    stmt = sqlConn.createStatement();
    % SELECT statement
    if strncmpi(dirQuery, 'select', 6)
        result = stmt.executeQuery(dirQuery);
    % INSERT, UPDATE, DELETE statements
    else
        result = stmt.executeUpdate(dirQuery);
    end
    
    if debug
        disp(['Query:  ' dirQuery]);
    end
    return;
end

%% NO-DIRECT QUERY CASE
action = lower(varargin{1});

% Argument 1
table  = args{1};

% Argument 2
% Condition or Data structures
if nargs > 1 && ~isempty(args{2}) && isstruct(args{2})
    args{2} = removeEmptyValues(args{2});
    args{2} = removeSkippedValues(args{2}, table);
else
    args{2} = struct(); % Default
end

% Argument 3
% Fields strings, Additional query string or Data structure
if nargs > 2 && ~isempty(args{3})
    if isstruct(args{3})
        args{3} = removeEmptyValues(args{3});
        args{3} = removeSkippedValues(args{3}, table);
    end
else
    args{3} = '';       % Default
end

% Argument 4
% Additional query string
if nargs > 3 && ~isempty(args{4})
    args{4} = [' ' args{4}];
else
    args{4} = '';       % Default
end

% Run required Action
switch action
%% ==== SELECT ====
    % data = sql_query('SELECT', Table, Condition, Fields, AddQuery)
    % bool = sql_query('EXIST' , Table, Condition, AddQuery)
    case {'select', 'exist'}
        % Arguments
        condition = args{2};
        fields    = args{3};
        addQuery  = args{4};
        % Select all columns if not specified
        if isempty(fields), fields = '*'; end
        % Exist case
        if strcmpi(action, 'exist')
            addQuery = [' ' fields];
            fields = '1';
        end
        % String for requested data fields
        if ischar(fields), fields = {fields}; end
        fieldsQry = str_join(fields, ', ');
        % String for condition
        condQry = prepareCondQry(condition);
        % Arrange query
        qry = ['SELECT ' fieldsQry ' FROM ' table ' WHERE 1' condQry addQuery];
        pstmt = sqlConn.prepareStatement(qry);
        % Add condition values to prepared statement
        addParams(pstmt, condition);
        
        % Execute query
        resultSet = pstmt.executeQuery();
        
        % Exist case
        if strcmp(fields{1}, '1')
            result = resultSet.next();
            iResult = result;
        % Select case
        else
            % Prepare output structure
            defValues  = db_template(table);
            fieldTypes = db_template(table, 'fields');
            % All fields
            if strcmp(fields{1}, '*')
                outputStruct = defValues;
                fields = fieldnames(defValues);
            else
                outputStruct = struct();
                for iField = 1:length(fields)
                    outputStruct.(fields{iField}) = defValues.(fields{iField});
                end
            end
            result = repmat(outputStruct, 0);
            % Retrieve rows
            iResult = 1;
            while resultSet.next()
                for iField = 1:length(fields)
                    % Convert to proper type
                    result(iResult).(fields{iField}) = getResultField(resultSet, ...
                          fields{iField}, fieldTypes.(fields{iField}));
                end
                iResult = iResult + 1;
            end
            iResult = iResult - 1;
        end
        resultSet.close();
        pstmt.close();
        
        % Print query for debugging
        if debug
            disp(['Query:  ' toString(qry, condition)]);
            disp(['Result: ' getNRows(iResult) ' returned.']);
        end
    
%% ==== INSERT ====
    % Id = sql_query('INSERT', Table, Data, AddQuery)
    case 'insert'        
        % Arguments
        data     = args{2};
        addQuery = args{3};
        % Build prepared statement
        fieldList  = str_join(fieldnames(data), ', ');
        valueList  = str_join(repmat({'?'}, length(fieldnames(data)), 1), ', ');
        % Arrange query
        qry = ['INSERT INTO ' table '(' fieldList ') VALUES(' valueList ') ' addQuery];
        pstmt = sqlConn.prepareStatement(qry, java.sql.Statement.RETURN_GENERATED_KEYS);
        % Add values to prepared statement
        addParams(pstmt, data);
        
        % Execute query
        result = pstmt.executeUpdate();
        
        % Try to get the inserted row ID
        try
            generatedKeys = pstmt.getGeneratedKeys();
            if generatedKeys.next()
                result = generatedKeys.getLong(1);
            end
        catch
        end
        pstmt.close();
        
        % Print query for debugging
        if debug
            disp(['Query:  ' toString(qry, data)]);
            disp(['Result: Inserted row #' num2str(result) '.']);
        end
        
%% ==== UPDATE ====
    % numUpdatedRows = sql_query('UPDATE', Table, Data, Condition, AddQuery)
    case 'update'
        % Arguments
        data      = args{2};
        condition = args{3};
        addQuery  = args{4};
        if isempty(condition), condition = struct(); end
        % Build prepared statement
        % New data fields
        dataQry = prepareCondQry(data);
        dataQry = regexprep(dataQry, '^\s*AND\s*', ''); % Remove first ' AND '
        dataQry = strrep(dataQry, ' AND', ',');         % Replace ' AND' with ','
        % Condition fields
        condQry = prepareCondQry(condition);
        % Arrange query
        qry = ['UPDATE ' table ' SET ' dataQry ' WHERE 1' condQry addQuery];
        pstmt = sqlConn.prepareStatement(qry);
        % Add values to prepared statement
        addParams(pstmt, data);
        addParams(pstmt, condition, length(fieldnames(data)));

        % Execute query
        result = pstmt.executeUpdate();
        pstmt.close();
        
        % Print query for debugging
        if debug
            disp(['Query:  ' toString(qry, {data, condition})]);
            disp(['Result: ' getNRows(result) ' updated.']);
        end
        
%% ==== DELETE ====
    % numDeletedRows = sql_query('DELETE', Table, Condition, AddQuery)
    case 'delete'
        % Arguments
        condition = args{2};
        addQuery  = args{3};
        % Build prepared statement
        % Condition fields
        condQry = prepareCondQry(condition);
        % Arrange query
        qry = ['DELETE FROM ' table ' WHERE 1 ' condQry addQuery];
        pstmt = sqlConn.prepareStatement(qry);
        % Add values to prepared statement
        addParams(pstmt, condition);

        % Execute query
        result = pstmt.executeUpdate();
        pstmt.close();
        
        % Print query for debugging
        if debug
            disp(['Query:  ' toString(qry, condition)]);
            disp(['Result: ' getNRows(result) ' deleted.']);
        end
        
%% ==== COUNT ====
    % numRows = sql_query('COUNT', Table, Condition, Field, AddQuery)
    case 'count'
        % Arguments
        condition = args{2};
        field     = args{3};
        addQuery  = args{4};
        % Select all columns if not specified
        if isempty(field), field = '*'; end
        % Build prepared statement
        condQry = prepareCondQry(condition);
        % Add values to prepared statement
        qry = ['SELECT COUNT(' field ') AS total FROM ' table ' WHERE 1' condQry addQuery];
        pstmt = sqlConn.prepareStatement(qry);
        % Add conditions to prepared statement
        if ~isempty(condQry)
            addParams(pstmt, condition);
        end
        
        % Execute query
        resultSet = pstmt.executeQuery();
        result = resultSet.getInt('total');
        resultSet.close();
        pstmt.close();
        
        % Print query for debugging
        if debug
            disp(['Query:  ' toString(qry, condition)]);
            disp(['Result: Counted ' getNRows(result) '.']);
        end
        
%% ==== RESET-AUTOINCREMENT ====
    % numRows = sql_query('RESET-AUTOINCREMENT', Table)
    case 'reset-autoincrement'
        % UPDATE statement
        qry = ['UPDATE sqlite_sequence SET seq = 0 WHERE name = "' table '"'];

        % Execute query
        stmt = sqlConn.createStatement();
        result = stmt.executeUpdate(qry);

        % Print query for debugging
        if debug
            disp(['Query2: ' qry]);
            disp(['Result: ' getNRows(result) ' updated.']);
        end

    otherwise
        error('Unsupported query type.');
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
end

%% ==== HELPERS ====
%% Add parameters for prepare statement (pstmt)
function addParams(pstmt, structure, offset)
    if nargin < 3
        offset = 0;
    end
    structFields = fieldnames(structure);
    for i = 1 : length(structFields)
        value = structure.(structFields{i});
        if ischar(value)
            pstmt.setString(i + offset, value);
        elseif iscell(value)
            pstmt.setString(i + offset, value{1});
        else
            pstmt.setDouble(i + offset, value);
        end
    end
end

%% Remove fields with empty values
function values = removeEmptyValues(values)
    fields = fieldnames(values);
    toDel = {};
    for iField = 1:length(fields)
        if isempty(values.(fields{iField}))
            toDel{end + 1} = fields{iField};
        end
    end
    values = rmfield(values, toDel);
end

%% Remove 'skip' fields
function values = removeSkippedValues(values, table)
    fieldTypes = db_template(table, 'fields');
    fields = fieldnames(values);
    toDel = {};
    for iField = 1:length(fields)
        if ~isfield(fieldTypes, fields{iField}) || strcmpi(fieldTypes.(fields{iField}), 'skip')
            toDel{end + 1} = fields{iField};
        end
    end
    values = rmfield(values, toDel);
end

%% Handle Row Columns by Type
function value = getResultField(resultSet, field, type)
    switch type
        case 'int'
            value = resultSet.getInt(field);
        case 'str'
            value = char(resultSet.getString(field));
        case 'bool'
            value = resultSet.getBoolean(field);
        case 'double'
            value = resultSet.getDouble(field);
        case 'skip'
            value = [];
        otherwise
            error('Unsupported field type.');
    end
    
    if resultSet.wasNull()
        value = [];
    end
end

%% Generate string by formatting Query with structures (Data and/or Condition)
function query = toString(query, structures)
    % Structures as cell array of structs
    if isstruct(structures)
        structures = {structures};
    end
    % Extract values from structs
    values = {};
    for iStruct = 1 : length(structures)
        structFields = fieldnames(structures{iStruct});
        for iField = 1 : length(structFields)
            values{end + 1} = structures{iStruct}.(structFields{iField});
        end
    end
    % Sanity check: number of '?' must be equal to number of values
    qMarks = regexp(query, '[\?]{1,}?');
    if length(qMarks) ~= length(values)
        warning('Query string is will not be printed')
        return
    end
    % Replace values in query
    for iQ = 1 : length(qMarks)
        if ischar(values{iQ})
            values{iQ} = ['"' values{iQ} '"'];
        elseif isnumeric(values{iQ}) || islogical(values{iQ})
            values{iQ} = num2str(values{iQ});
        end
        % Find all the instances of '?'
        qMarks = regexp(query, '[\?]{1,}?');
        % Replaces fist instance
        query = [query(1 : qMarks(1)-1), values{iQ}, query(qMarks(1)+1 : end)];
    end
end

%% Concatenate strings using delimiter
function outStr = str_join(cellStr, delimiter)
    outStr = '';
    for iCell = 1:length(cellStr)
        if iCell > 1
            outStr = [outStr delimiter];
        end
        outStr = [outStr cellStr{iCell}];
    end
end

%% Handle plural for Row / Rows
function str = getNRows(n)
    ending = '';
    if n > 1
        ending = 's';
    end
    str = [num2str(n) ' row' ending];
end

%% Generate condition Query string
function condQry = prepareCondQry(condition)
    condQry = '';
    condFields = fieldnames(condition);
    for iField = 1:length(condFields)
        condQry = [condQry ' AND ' condFields{iField} ' = ?'];
    end
end
