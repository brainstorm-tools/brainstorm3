function tables = sql_generate_db()
% SQL_GENERATE_DB: Generate SQL structure for whole database

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

tables = repmat(db_template('sqltable'), 0);

% Protocol table
table = generateTable('Protocol', 1);
table.Name = 'Protocol';
table.PrimaryKey = 'Name';
tables(end + 1) = table;

% Subject table
table = generateTable('Subject', 0);
editField('Id', 'AutoIncrement');
editField('Name', 'NotNull');
editField('FileName', 'NotNull');
editField('UseDefaultAnat', 'NotNull');
editField('UseDefaultChannel', 'NotNull');
table.PrimaryKey = 'Id';
tables(end + 1) = table;

% Study table
table = generateTable('Study', 0);
table.Name = 'Study';
editField('Id', 'AutoIncrement');
editField('Name', 'NotNull');
editField('Subject', 'ForeignKey', {'Subject', 'Id'});
editField('Subject', 'NotNull');
editField('FileName', 'NotNull');
table.PrimaryKey = 'Id';
tables(end + 1) = table;

% Functional File table
table = generateTable('FunctionalFile', 0);
editField('Id', 'AutoIncrement');
editField('ParentFile', 'ForeignKey', {'FunctionalFile', 'Id'});
editField('Study', 'ForeignKey', {'Study', 'Id'});
editField('Study', 'NotNull');
editField('Type', 'NotNull');
editField('FileName', 'NotNull');
editField('Name', 'NotNull');
editField('NumChildren', 'NotNull');
table.PrimaryKey = 'Id';
tables(end + 1) = table;

% Anatomy File table
table = generateTable('AnatomyFile', 1);
editField('Id', 'AutoIncrement');
editField('SurfaceType', 'NotNull', 0);
editField('Subject', 'ForeignKey', {'Subject', 'Id'});
table.PrimaryKey = 'Id';
tables(end + 1) = table;

% Locks table
table = generateTable('Lock', 1);
editField('Id', 'AutoIncrement');
editField('Study', 'NotNull', 0);
editField('File', 'NotNull', 0);
table.PrimaryKey = 'Id';
tables(end + 1) = table;

function addField(Name, Type, NotNull, AutoIncrement, ForeignKey, DefaultValue)
    field = db_template('sqlfield');
    field.Name = Name;
    field.Type = Type;
    if nargin > 2 && ~isempty(NotNull)
        field.NotNull = NotNull;
    end
    if nargin > 3 && ~isempty(AutoIncrement)
        field.AutoIncrement = AutoIncrement;
    end
    if nargin > 4 && ~isempty(ForeignKey)
        field.ForeignKey = ForeignKey;
    end
    if nargin > 5 && ~isempty(DefaultValue)
        field.DefaultValue = DefaultValue;
    end
    
    table.Fields(end + 1) = field;
end

function editField(fieldName, attribute, value)
    fields = {table.Fields.Name};
    iField = find(strcmpi(fields, fieldName));
    if isempty(iField)
        error(['Field ' fieldName ' not found.']);
    end
    
    if nargin < 3
        value = 1;
    end
    
    table.Fields(iField).(attribute) = value;    
end
end

% Generate a table SQL structure from its template
function table = generateTable(dbTemplate, NotNull)
    table = db_template('sqltable');
    table.Name = dbTemplate;
    sTypes  = db_template(dbTemplate, 'fields');
    sValues = db_template(dbTemplate, 'values');
    fields = fieldnames(sTypes);
    
    iNext = 1;
    for iField = 1:length(fields)
        field = db_template('sqlfield');
        field.Name = fields{iField};
        field.Type = sTypes.(fields{iField});
        field.NotNull = NotNull;
        field.DefaultValue = sValues.(fields{iField});
        if ~strcmpi(field.Type, 'skip')
            table.Fields(iNext) = field;
            iNext = iNext + 1;
        end
    end
end
