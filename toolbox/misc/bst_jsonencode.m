function outString = bst_jsonencode(inStruct, indent, depth)
% BST_JSONENCODE: Encodes a Matlab structure as JSON text
%
% USAGE: outString = bst_jsonencode(inStruct, 1) : With space indentation
%        outString = bst_jsonencode(inStruct, 0) : Without space indent

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
% Authors: Martin Cousineau, 2018

if nargin < 2
    indent = 1;
end

% If possible, call built-in function
if ~indent && exist('jsonencode', 'builtin') == 5
    outString = jsonencode(inStruct);
    return;
end

if nargin < 3
    depth = 0;
end

outString = '{';
fields  = fieldnames(inStruct);

for iField = 1:length(fields)
    field = fields{iField};
    value = inStruct.(field);

    strFld = stringify(field, indent);
    if isstruct(value)
        strVal = bst_jsonencode(value, indent, depth + 1);
    else
        strVal = stringify(value, indent);
    end

    if iField > 1
        delimiter1 = ',';
    else
        delimiter1 = [];
    end
    delimiter2 = ':';

    if indent
        delimiter1 = [delimiter1 10 createIndent(depth + 1)];
        delimiter2 = [delimiter2 ' '];
    end

    outString = [outString delimiter1 strFld delimiter2 strVal];
end

if indent
    outString = [outString 10 createIndent(depth)];
end
outString = [outString '}'];

end


function str = stringify(val, addDelimiter)
    if nargin < 2
        addDelimiter = 0;
    end

    if ischar(val)
        if ismember(val, {'true', 'false'})
            str = val;
        else
            str = ['"' strrep(val, '"', '\"') '"'];
        end
    elseif isnumeric(val)
        n = length(val);
        if n == 0
            str = '[]';
        elseif n == 1
            str = num2str(val);
        else
            str = '[';
            for i = 1:n
                if i > 1
                    str = [str ','];
                    if addDelimiter
                       str = [str ' '];
                    end
                end
                str = [str num2str(val(i))];
            end
            str = [str ']'];
        end
    else
        error(['Unsupported type: ' class(val)]);
    end
end

function prefix = createIndent(depth)
    prefix = '';
    for i = 1:depth
        prefix = [prefix '    '];
    end
end
