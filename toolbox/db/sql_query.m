function result = sql_query(sqlConnection, type, table, data, condition, addQuery)
% SQL_QUERY: Execute a query on an SQL database

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

if isempty(sqlConnection)
    closeConnection = 1;
    sqlConnection = sql_connect();
else
    closeConnection = 0;
end

% Direct query
if nargin < 3
    stmt = sqlConnection.createStatement();
    if strncmpi(type, 'select', 6) % SELECT query
        result = stmt.executeQuery(type);
    else % INSERT/UPDATE/DELETE query
        result = stmt.executeUpdate(type);
    end
    
    if closeConnection
        sql_close(sqlConnection);
    end
    
    if debug
        if type(end) ~= ';'
            type = [type ';'];
        end
        disp(['Query: ' type]);
    end
    
    return;
end
% Get additional query part
if nargin < 6 || isempty(addQuery)
    addQuery = '';
else
    addQuery = [' ' addQuery];
end

switch type
    case 'select'
        % Get fields to select
        allFields = 0;
        checkExistence = 0;
        if nargin < 4 || isempty(data)
            allFields = 1;
            dataQry = '*';
        elseif ischar(data)
            dataQry = data;
            if strcmp(data, '*')
                allFields = 1;
            elseif strcmp(data, '1')
                checkExistence = 1;
            else
                data = {data};
            end
        else
            dataQry = '';
            for iField = 1:length(data)
                if iField > 1
                    dataQry = [dataQry ', '];
                end
                dataQry = [dataQry data{iField}];
            end
        end
        
        % Get condition
        if nargin < 5 || isempty(condition)
            condition = struct();
            condQry = '';
        else
            condition = removeEmptyValues(condition);
            condQry = ' WHERE ';
            condFields = fieldnames(condition);
            for iField = 1:length(condFields)
                if iField > 1
                    condQry = [condQry ' AND '];
                end
                condQry = [condQry condFields{iField} ' = ?'];
            end
        end
        
        qry = ['SELECT ' dataQry ' FROM ' table condQry addQuery];
        pstmt = sqlConnection.prepareStatement(qry);
        
        % Add conditions to prepared statement
        if nargin > 4 && ~isempty(condQry)
            for iCond = 1:length(condFields)
                addParam(pstmt, iCond, condition.(condFields{iCond}));
            end
        end
        
        % Execute query
        resultSet = pstmt.executeQuery();
        
        % Special case: check only existence of row
        if checkExistence
            result = resultSet.next();
            resultSet.close();
            return;
        end
        
        % Prepare output structure
        defValues = db_template(table);
        fieldTypes = db_template(table, 'fields');
        if allFields
            outputStruct = defValues;
            data = fieldnames(defValues);
        else
            outputStruct = struct();
            for iField = 1:length(data)
                outputStruct.(data{iField}) = defValues.(data{iField});
            end
        end
        result = repmat(outputStruct, 0);
        
        % Retrieve rows
        iResult = 1;
        while resultSet.next()
            for iField = 1:length(data)
                result(iResult).(data{iField}) = getResultField(resultSet, ...
                    data{iField}, fieldTypes.(data{iField}));
            end
            iResult = iResult + 1;
        end
        resultSet.close();
        
        % Print query for debugging
        if debug
            disp(['Query:  ' toString(type, table, dataQry, condition, addQuery)]);
            disp(['Result: ' getNRows(iResult - 1) ' returned.']);
        end
    
    case 'insert'        
        data = removeEmptyValues(data);
        data = removeSkippedValues(data, table);
        % Build prepared statement
        fieldList = '';
        valueList = '';
        dataFields = fieldnames(data);
        for iField = 1:length(dataFields)
            if iField > 1
                fieldList = [fieldList ', '];
                valueList = [valueList ', '];
            end
            fieldList = [fieldList dataFields{iField}];
            valueList = [valueList '?'];
        end
        
        qry = ['INSERT INTO ' table '(' fieldList ') VALUES(' valueList ');'];
        pstmt = sqlConnection.prepareStatement(qry, java.sql.Statement.RETURN_GENERATED_KEYS);
        
        % Add values to prepared statement
        for iField = 1:length(dataFields)
            addParam(pstmt, iField, data.(dataFields{iField}));
        end
        
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
            qry = toString(type, table, '', data, addQuery);
            disp(['Query:  ' qry]);
            disp(['Result: Inserted row #' num2str(result) '.']);
        end
        
    case 'update'
        if nargin < 5
            condition = struct();
        end
        
        data = removeEmptyValues(data);
        data = removeSkippedValues(data, table);
        condition = removeEmptyValues(condition);
        % Build prepared statement
        % New data fields
        dataQry = '';
        dataFields = fieldnames(data);
        nFields = length(dataFields);
        for iField = 1:nFields
            if iField > 1
                dataQry = [dataQry ', '];
            end
            dataQry = [dataQry dataFields{iField} ' = ?'];
        end
        % Condition fields
        condFields = fieldnames(condition);
        if isempty(condFields)
            condQry = '1';
        else
            condQry = '';
            for iCond = 1:length(condFields)
                if iCond > 1
                    condQry = [condQry ' AND '];
                end
                condQry = [condQry condFields{iCond} ' = ?'];
            end
        end
        
        qry = ['UPDATE ' table ' SET ' dataQry ' WHERE ' condQry];        
        pstmt = sqlConnection.prepareStatement(qry);
        
        % Add values to prepared statement
        for iField = 1:length(dataFields)
            addParam(pstmt, iField, data.(dataFields{iField}));
        end
        for iCond = 1:length(condFields)
            addParam(pstmt, iCond + nFields, condition.(condFields{iCond}));
        end
        
        result = pstmt.executeUpdate();
        pstmt.close();
        
        % Print query for debugging
        if debug                
            disp(['Query:  ' toString(type, table, data, condition, addQuery)]);
            disp(['Result: ' getNRows(result) ' updated.']);
        end
        
    case 'delete'
        if nargin > 3
            condition = removeEmptyValues(data);
        else
            condition = struct();
        end
        
        % Build prepared statement
        % Condition fields
        condQry = '';
        condFields = fieldnames(condition);
        for iCond = 1:length(condFields)
            if iCond == 1
                condQry = ' WHERE ';
            else
                condQry = [condQry ' AND '];
            end
            condQry = [condQry condFields{iCond} ' = ?'];
        end
        
        qry = ['DELETE FROM ' table condQry];
        pstmt = sqlConnection.prepareStatement(qry);
        
        % Add values to prepared statement
        for iCond = 1:length(condFields)
            addParam(pstmt, iCond, condition.(condFields{iCond}));
        end
        
        result = pstmt.executeUpdate();
        pstmt.close();
        
        % Print query for debugging
        if debug
            disp(['Query:  ' toString(type, table, '', condition, addQuery)]);
            disp(['Result: ' getNRows(result) ' deleted.']);
        end
        
    case 'count'        
        % Get condition
        if nargin < 4 || isempty(data)
            condQry = '';
        else
            data = removeEmptyValues(data);
            condQry = ' WHERE ';
            condFields = fieldnames(data);
            for iField = 1:length(condFields)
                if iField > 1
                    condQry = [condQry ' AND '];
                end
                condQry = [condQry condFields{iField} ' = ?'];
            end
        end
        
        % Get additional query
        if nargin < 5 || isempty(condition)
            addQuery = '';
        else
            addQuery = [' ' condition];
        end
        
        qry = ['SELECT COUNT(*) AS total FROM ' table condQry addQuery];
        pstmt = sqlConnection.prepareStatement(qry);
        
        % Add conditions to prepared statement
        if nargin > 3 && ~isempty(data)
            for iCond = 1:length(condFields)
                addParam(pstmt, iCond, data.(condFields{iCond}));
            end
        end
        
        % Execute query
        resultSet = pstmt.executeQuery();
        result = resultSet.getInt('total');
        resultSet.close();
        
        % Print query for debugging
        if debug
            if nargin < 4
                data = struct();
            end
            disp(['Query:  ' toString('SELECT', table, 'COUNT(*)', data, addQuery)]);
            disp(['Result: Counted ' getNRows(result) '.']);
        end
        
    otherwise
        if closeConnection
            sql_close(sqlConnection);
        end
        error('Unsupported query type.');
end

if closeConnection
    sql_close(sqlConnection);
end

end

function addParam(pstmt, i, value)
    if ischar(value)
        pstmt.setString(i, value);
    elseif iscell(value)
        pstmt.setString(i, value{1});
    else
        pstmt.setDouble(i, value);
    end
end

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

function qry = toString(type, table, dataQry, condition, addQuery)
    if strcmpi(type, 'insert')
        fieldQry = '';
        valueQry = '';
        fields = fieldnames(condition);
        for iField = 1:length(fields)
            if iField > 1
                fieldQry = [fieldQry ', '];
                valueQry = [valueQry ', '];
            end
            fieldQry = [fieldQry fields{iField}];
            value = condition.(fields{iField});
            if ischar(value)
                valueQry = [valueQry '"' value '"'];
            else
                valueQry = [valueQry num2str(value)];
            end
        end
        qry = ['INSERT INTO ' table '(' fieldQry ') VALUES (' valueQry ');'];
    else
        outStr = {'', ''};
        for i=1:2
            if i == 1
                inStruct = dataQry;
                if ~strcmpi(type, 'update')
                    continue
                end
            else
                inStruct = condition;
            end
            
            if isempty(inStruct)
                continue
            end
            
            condFld = fieldnames(inStruct);
            for iCond = 1:length(condFld)
                if iCond == 1
                    outStr{i} = [outStr{i} ' '];
                else
                    outStr{i} = [outStr{i} ' AND '];
                end
                value = inStruct.(condFld{iCond});
                if ischar(value)
                    value = ['"' value '"'];
                elseif iscell(value)
                    value = ['"' value{1} '"'];
                else
                    value = num2str(value);
                end
                outStr{i} = [outStr{i} condFld{iCond} ' = ' value];
            end
                
        end
        if ~isempty(outStr{2})
            condQry = [' WHERE' outStr{2}];
        else
            condQry = '';
        end
        if ~isempty(outStr{1})
            dataQry = outStr{1};
        elseif ~isempty(dataQry)
            dataQry = [' ' dataQry];
        end

        if strcmpi(type, 'update')
            qry = ['UPDATE ' table ' SET' dataQry condQry addQuery ';'];
        else
            qry = [upper(type) dataQry ' FROM ' table condQry addQuery ';'];
        end
    end
end

function str = getNRows(n)
    if n == 1
        str = '1 row';
    else
        str = [num2str(n) ' rows'];
    end
end