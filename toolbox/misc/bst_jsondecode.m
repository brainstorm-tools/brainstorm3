function outStruct = bst_jsondecode(inString)
% BST_JSONDECODE: Decodes a JSON string as a Matlab structure
%
% USAGE: outStruct = bst_jsondecode(inString)
%        outStruct = bst_jsondecode(filename)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Martin Cousineau, Francois Tadel, 2018

% If the input is an existing filename: read it
if exist(inString, 'file')
    % Open file
    fid = fopen(inString, 'r');
    if (fid < 0)
        error(['Cannot open JSON file: ' inString]);
    end
    % Read file
    inString = fread(fid, [1, Inf], '*char');
    % Close file
    fclose(fid);
    % Check that something was read
    if isempty(inString)
        error(['File is empty: ' inString]);
    end
end

% If possible, call built-in function
if exist('jsondecode', 'builtin') == 5
    outStruct = jsondecode(inString);
    return;
end

inString = strtrim(inString);
outStruct = struct();

% States:
STATE.START           = 0;
STATE.START_FIELD     = 1;
STATE.READ_NEXT_FIELD = 2;
STATE.READ_FIELD      = 3;
STATE.END_FIELD       = 4;
STATE.START_VALUE     = 5;
STATE.READ_NEXT_VALUE = 6;
STATE.READ_VALUE      = 7;
STATE.END_VALUE       = 8;

% Supported value types:
% Note: only lists of numbers are supported
VAL.CHAR = 1;
VAL.NUM  = 2;
VAL.BOOL = 3;
VAL.LIST = 4;

state = 0;
field = [];
value = [];
path  = {};
valType = [];
escape = 0;

for iChar = 1:length(inString)
    c = inString(iChar);
    err = 0;
    
    % Go through state machine depending on character
    if c == '{'
        if state == STATE.READ_VALUE && valType == VAL.CHAR
            value = [value c];
        elseif state == STATE.START
            state = STATE.START_FIELD;
        elseif state == STATE.START_VALUE
            path{end + 1} = field;
            field = [];
            state = STATE.START_FIELD;
        else
            err = 1;
        end
    elseif c == '}'
        if state == STATE.READ_VALUE && valType == VAL.CHAR
            value = [value c];
        elseif state == STATE.READ_VALUE || state == STATE.END_VALUE
            % Save if not done already (no comma at the end of group)
            if ~isempty(field)
                outStruct = saveField(outStruct, path, field, value, valType);
                if ~isempty(path)
                    path = {path{1:end-1}};
                end
                field = [];
                value = [];
                state = STATE.END_VALUE;
            end
        else
            err = 1;
        end
    elseif c == '\'
        % Escape character for itself and double quote
        if state == STATE.READ_VALUE && valType == VAL.CHAR
            if escape
                value = [value '\'];
                escape = 0;
            else
                escape = 1;
            end
        else
            err = 1;
        end
    elseif c == '"'
        if state == STATE.START || state == STATE.START_FIELD
            state = STATE.READ_NEXT_FIELD;
        elseif state == STATE.READ_FIELD
            state = STATE.END_FIELD;
        elseif state == STATE.START_VALUE
            valType = VAL.CHAR;
            state = STATE.READ_VALUE;
        elseif state == STATE.READ_VALUE
            if escape
                value = [value '"'];
                escape = 0;
            else
                state = STATE.END_VALUE;
            end
        else
            err = 1;
        end
    elseif c == ':'
        if state == STATE.READ_VALUE && valType == VAL.CHAR
            value = [value c];
        elseif state == STATE.READ_FIELD || state == STATE.END_FIELD
            valType = [];
            state = STATE.START_VALUE;
        else
            err = 1;
        end
    elseif c == ','
        if state == STATE.READ_VALUE && valType == VAL.CHAR
            value = [value c];
        elseif state == STATE.READ_VALUE || state == STATE.END_VALUE
            if valType == VAL.LIST
                if ~isempty(token) && ~isempty(num2str(token))
                    value(end + 1) = str2num(token);
                    token = [];
                else
                    err = 1;
                end
            else
                outStruct = saveField(outStruct, path, field, value, valType);
                field = [];
                value = [];
                state = STATE.START_FIELD;
            end
        else
            err = 1;
        end
    elseif c == '['
        if state == STATE.READ_VALUE && valType == VAL.CHAR
            value = [value c];
        elseif state == STATE.START_VALUE
            valType = VAL.LIST;
            token = [];
            state = STATE.READ_VALUE;
        else
            err = 1;
        end
    elseif c == ']'
        if state == STATE.READ_VALUE && valType == VAL.CHAR
            value = [value c];
        elseif state == STATE.READ_VALUE && valType == VAL.LIST
            if ~isempty(token)
                n = str2num(token);
                if ~isempty(n)
                    value(end + 1) = n;
                else
                    err = 1;
                end
            end
            state = STATE.END_VALUE;
        else
            err = 1;
        end
    elseif ~isspace(c)
        % Read non-special characters
        if state == STATE.READ_NEXT_FIELD || state == STATE.READ_FIELD
            state = STATE.READ_FIELD;
            field = [field c];
        elseif state == STATE.READ_NEXT_VALUE || state == STATE.READ_VALUE
            state = STATE.READ_VALUE;
            if valType == VAL.LIST
                token = [token c];
            else
                value = [value c];
            end
        % Detect special values for boolean and null
        elseif state == STATE.START_VALUE && findAhead({'true', 'false', 'null'}, inString(iChar:end))
            state = STATE.READ_VALUE;
            valType = VAL.BOOL;
            value = c;
        elseif state == STATE.START_VALUE && c >= '0' && c <= '9'
            state = STATE.READ_VALUE;
            valType = VAL.NUM;
            value = c;
        else
            err = 1;
        end
    elseif isspace(c) && ~isempty(valType) && valType == VAL.CHAR && (state == STATE.READ_NEXT_VALUE || state == STATE.READ_VALUE)
        % Only read spaces for character values
        value = [value c];
    end
    
    % Error management
    if err
        error(['JSON syntax error. Unexpected character: ' c]);
    end
end

function outStruct = saveField(outStruct, path, field, value, valType)
    sPath = 'outStruct';
    for iNode = 1:length(path)
        sPath = [sPath '.' path{iNode}];
    end
    
    if valType == VAL.CHAR
        value = ['''' value ''''];
    elseif valType == VAL.LIST
        elems = value;
        value = '[';
        for iElem = 1:length(elems)
            if iElem > 1
                value = [value ','];
            end
            value = [value num2str(elems(iElem))];
        end
        value = [value ']'];
    elseif valType == VAL.BOOL
        if strcmpi(value, 'true')
            value = '1';
        elseif strcmpi(value, 'false')
            value = '0';
        elseif strcmpi(value, 'null')
            value = '[]';
        else
            error(['JSON syntax error. Invalid string: ' value]);
        end
    elseif valType == VAL.NUM && isempty(str2num(value))
        error(['JSON syntax error. Invalid string: ' value]);
    end
    
    eval([sPath '.' field ' = ' value ';']);
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
