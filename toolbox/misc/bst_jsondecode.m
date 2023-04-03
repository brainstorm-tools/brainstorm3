function [outStruct, replacedFields] = bst_jsondecode(inString, forceBstVersion)
% BST_JSONDECODE: Decodes a JSON string as a Matlab structure
%
% USAGE: outStruct = bst_jsondecode(inString)
%        outStruct = bst_jsondecode(filename)
%
% Limitations:
%   - requires the "root type" to be an object: a list of key:value pairs
%     enclosed in curly brackets.
%   - only supports arrays of number or string.
%   - escaped special characters \r\n\t are decoded as unicode arrow symbols as
%     MATLAB does. Other escaped characters (other than \\ and \") are kept as is
%     and therefore would not be correctly re-encoded.

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
%
% Authors: Martin Cousineau, 2018-2019; Francois Tadel, 2018; Marc Lalancette, 2021

if nargin < 2 || isempty(forceBstVersion)
    forceBstVersion = 0;
end

% Json allows any string (unicode characters) as a key, unlike Matlab var/field
% names. So some must be renamed.
iReplaced = 0;
replacedFields = cell(0, 2);

% If the input is an existing filename: read it
if exist(inString, 'file')
    jsonFile = inString;
    % Open file
    fid = fopen(jsonFile, 'r');
    if (fid < 0)
        error(['Cannot open JSON file: ' jsonFile]);
    end
    % Read file
    inString = fread(fid, [1, Inf], '*char');
    % Close file
    fclose(fid);
    % Check that something was read
    if isempty(inString)
        error(['File is empty: ' jsonFile]);
    end
else
    jsonFile = [];
end

% If possible, call built-in function
if ~forceBstVersion && exist('jsondecode', 'builtin') == 5
    outStruct = jsondecode(inString);
    return;
end

inString = strtrim(inString);
outStruct = struct();

% States:
STATE.START           = 0;
STATE.START_FIELD     = 1;
%STATE.READ_NEXT_FIELD = 2; % unused
STATE.READ_FIELD      = 3;
STATE.END_FIELD       = 4;
STATE.START_VALUE     = 5; % can also be the start of a string in an existing list
%STATE.READ_NEXT_VALUE = 6; % unused
STATE.READ_VALUE      = 7;
STATE.END_VALUE       = 8;
STATE.START_LIST      = 9;
STATE.END_LIST        = 10;
STATE.END_SUBLEVEL    = 11;

% Supported value types:
% Note: only lists of numbers or strings are supported
VAL.NONE = 0; % to simplify resetting without having to check if empty.
VAL.CHAR = 1;
VAL.NUM  = 2;
VAL.BOOL = 3;
VAL.LIST_NUM = 4;
VAL.LIST_STR = 5;

state = STATE.START;
field = ''; % json key / matlab struct field
value = [];
token = ''; % json string (key, value, or element of array value)
path  = {};
valType = VAL.NONE;
escape = false;
lineNum  = 1;
lineChar = 0;

for iChar = 1:length(inString)
    c = inString(iChar);
    lineChar = lineChar + 1;
    err = 0;
    
    % Process character depending on state
    
    % Reading a string
    if state == STATE.READ_FIELD || ...
            (state == STATE.READ_VALUE && (valType == VAL.CHAR || valType == VAL.LIST_STR))
        if escape
            if c == '"' || c == '\'
                token(end + 1) = c; %#ok<*AGROW>
                % Copy Matlab's hack to decode/encode escaped special characters.
            elseif c == 'n' % newline / linefeed
                token(end + 1) = char(8629); % ↵
            elseif c == 'r' % carriage return
                token(end + 1) = char(8592); % ←
            elseif c == 't' % tab
                token(end + 1) = char(8594); % →
            else
                % Possibly other special character. Keep as is, but won't be properly re-encoded.
                token = [token '\' c];
            end
            escape = false;
        elseif c == '\'
            % Escape character for itself and double quote
            escape = true;
        elseif c == '"'
            if state == STATE.READ_FIELD
                state = STATE.END_FIELD;
            else
                state = STATE.END_VALUE;
            end
        else
            % Any other unicode character is valid in a json string.
            token(end + 1) = c;
        end
        
        % Ignore all white space outside strings.
    elseif c == char(10)
        % Increment line number if we have a line break
        lineNum = lineNum + 1;
        lineChar = 0;
    elseif isspace(c)
        continue;
        
    elseif state == STATE.START
        if c == '{'
            state = STATE.START_FIELD;
        elseif c == '"'
            state = STATE.READ_FIELD;
        else
            err = 1;
        end
    elseif state == STATE.START_FIELD
        %field = '';
        token = '';
        if c == '"'
            state = STATE.READ_FIELD;
        elseif c == '}'
            % This was an empty "sublevel"/object, i.e. {}.
            state = STATE.END_SUBLEVEL;
        else
            err = 1;
        end
    elseif state == STATE.END_FIELD
        % Validate field name is appropriate for matlab.  Need to do it now in
        % case there are sub-fields.
        if ~isvarname(token)
            iReplaced = iReplaced + 1;
            %         field = ['REPLACED_FIELD_', str2double(iReplaced)];
            % Rename like Matlab, though 2 keys could have the same modified name.
            field = matlab.lang.makeValidName(token);
            % Append _ if the field already exists.
            tempPath = 'outStruct';
            for iP = 1:length(path)
                tempPath = [tempPath '.' path{iP}];
            end
            if isfield(eval(tempPath), field)
                field = [field '_'];
            end
            replacedFields(iReplaced, :) = {field, token};
        else
            field = token;
        end
        if c ~= ':'
            err = 1;
        end
        valType = VAL.NONE;
        value = [];
        state = STATE.START_VALUE;
    elseif state == STATE.START_VALUE
        % value was emptied in END_FIELD since we might continue a list of strings.
        if c == '{'
            % Save sub-field. Needed to later check existance of renamed fields.
            outStruct = saveField(outStruct, path, field, [], valType);
            path{end + 1} = field;
            state = STATE.START_FIELD;
        elseif c == '['
            state = STATE.START_LIST;
        elseif c == '"'
            % Check if continuing an existing list of strings
            if valType ~= VAL.LIST_STR
                valType = VAL.CHAR;
            end
            token = '';
            state = STATE.READ_VALUE;
        elseif c >= '0' && c <= '9'
            valType = VAL.NUM;
            token = c;
            state = STATE.READ_VALUE;
            % Detect special values for boolean and null
        elseif findAhead({'true', 'false', 'null'}, inString(iChar:end))
            valType = VAL.BOOL;
            token = c;
            state = STATE.READ_VALUE;
        else
            err = 1;
        end
    elseif state == STATE.READ_VALUE % NUM, BOOL or LIST_NUM
        if valType == VAL.LIST_NUM && (c == ',' || c == ']')
            n = str2double(token);
            token = '';
            if ~isempty(n)
                value(end + 1) = n;
            else
                err = 1;
            end
            if c == ']'
                state = STATE.END_LIST;
            end
        elseif c == ',' || c == '}'
            value = token;
            % Save
            outStruct = saveField(outStruct, path, field, value, valType);
            if c == ','
                state = STATE.START_FIELD;
            elseif c == '}'
                state = STATE.END_SUBLEVEL;
            end
        else % numerical, boolean or null values validated later.
            token(end + 1) = c;
        end
    elseif state == STATE.END_VALUE && valType == VAL.LIST_STR
        value{end + 1} = token;
        if c == ','
            state = STATE.START_VALUE;
        elseif c == ']'
            state = STATE.END_LIST;
        else
            err = 1;
        end
    elseif (state == STATE.END_VALUE && valType == VAL.CHAR) || ...
            state == STATE.END_LIST
        if valType == VAL.CHAR
            value = token;
        end
        % Save
        outStruct = saveField(outStruct, path, field, value, valType);
        if c == ','
            state = STATE.START_FIELD;
        elseif c == '}'
            state = STATE.END_SUBLEVEL;
        else
            err = 1;
        end
    elseif state == STATE.END_SUBLEVEL
        if ~isempty(path) % else this should be the end of the file
            path = path(1:end-1);
        end
        if c == ','
            state = STATE.START_FIELD;
        elseif c == '}'
            state = STATE.END_SUBLEVEL;
        else
            err = 1;
        end
    elseif state == STATE.START_LIST
        if c == '"'
            valType = VAL.LIST_STR;
            token = '';
        else
            valType = VAL.LIST_NUM;
            token = c;
        end
        state = STATE.READ_VALUE;
    else
        err = 1;
    end
    
    % Error management
    if err
        errorMsg = sprintf(...
            ['JSON syntax error. Unexpected character ''%c'' ' ...
            'at line %d, column %d (character %d)'], ...
            c, lineNum, lineChar, iChar);
        if ~isempty(jsonFile)
            errorMsg = [errorMsg ' of file ' jsonFile];
        end
        error(errorMsg);
    end
    
end % character loop

% Warn if there were invalid field names.
if iReplaced > 0
    if nargout > 1
        warning('One or more field names were not valid for MATLAB and were replaced.');
    else
        warning('One or more field names were not valid for MATLAB and were replaced. To see the original names, use bst_jsondecode with a second output argument.');
    end
end


    function outStruct = saveField(outStruct, path, field, value, valType)
        sPath = 'outStruct';
        for iNode = 1:length(path)
            sPath = [sPath '.' path{iNode}];
        end
        
        if isempty(value)
            value = 'struct';
        elseif valType == VAL.CHAR
            % Due to eval later, replace single quotes by 2 single quotes.
            value = ['''' strrep(value, '''', '''''') ''''];
        elseif valType == VAL.LIST_NUM
            elems = value;
            value = '[';
            for iElem = 1:length(elems)
                if iElem > 1
                    value = [value ','];
                end
                value = [value num2str(elems(iElem))];
            end
            value = [value ']'];
        elseif valType == VAL.LIST_STR
            elems = value;
            value = '{';
            for iElem = 1:length(elems)
                if iElem > 1
                    value = [value ','];
                end
                value = [value '''' strrep(elems{iElem}, '''', '''''') ''''];
            end
            value = [value '}'];
        elseif valType == VAL.BOOL
            value = lower(value);
            if strcmp(value, 'null')
                value = '[]';
            elseif ~strcmp(value, 'true') && ~strcmp(value, 'false')
                error(['JSON syntax error. Invalid boolean string: ' value]);
            end
        elseif valType == VAL.NUM && isempty(str2double(value))
            error(['JSON syntax error. Invalid numerical string: ' value]);
        end
        
        try
            eval([sPath '.' field ' = ' value ';']);
        catch ME
            sPath %#ok<*NOPRT>
            field
            value
            rethrow(ME);
        end
        
    end
end

function found = findAhead(needles, haystack)
found = 0;
for iNeedle = 1:length(needles)
    needle = needles{iNeedle};
    if strncmpi(needle, haystack, length(needle))
        found = 1;
        return;
    end
end
end
