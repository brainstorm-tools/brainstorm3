function strA = str_format( A, isCode, nIndent )
% STR_FORMAT: Format any type of data in a humanly readable way, or for producing a Matlab script.
%
% USAGE:  strA = str_format( A, isCode, nIndent )
%         strA = str_format( A, isCode )
%         strA = str_format( A )
%
% INPUT: 
%    - A      : Any type of Matlab variable (scalar, matrix, struct, cell, string...)
%    - isCode : If 1, prints the full information in the variable in Matlab code conventions
%               If 0, prints a human-readable summary of the variable (not in valid Matlab syntax)

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
% Authors: Francois Tadel, 2010-2016

% Parse inputs
if (nargin < 2) || isempty(isCode)
    isCode = 0;
end
if (nargin < 3) || isempty(nIndent)
    nIndent = 0;
end
% Format variable
if isstruct(A)
    strA = DisplayStruct(A, isCode, nIndent);
else
    strA = FormatValue(A, isCode, nIndent);
end

end


%% ===== FORMAT OTHER CLASSES =====
function strA = FormatValue(A, isCode, nIndent)
    % CHARS 
    if ischar(A)
        A(A == 0) = [];
        if (size(A,1) > 1)
            A = reshape(A',1,[]);
        end
        % If there are breaks: full representation with "['...' 10 '...']"
        if any(A == 10)
            strA = ['[''', strrep(A, char(10), ''' 10 '''), ''']'];
        % Else: simple display between quotes
        else
            strA = ['''' A ''''];
        end
    % NUMBERS
    elseif isnumeric(A) || islogical(A)
        strA = FormatNumericArray(A, isCode, nIndent);
    % CELLS
    elseif iscell(A)
        strA = FormatCellArray(A, isCode, nIndent);
    % STRUCTURES
    elseif isstruct(A)
        strA = DisplayStruct(A, isCode, nIndent + 1);
    elseif isCode
        strA = [];
    else
        strA = '******************************';
    end
end


%% ===== FORMAT STRUCTURES =====
function structString = DisplayStruct(s, isCode, nIndent)
    structString = '';
    [M,N] = size(s);
    % Get fields names
    MatFields = fieldnames(s);
    % Get the maximum length of the options names
    if ~isempty(MatFields)
        maxLength = max(cellfun(@length, MatFields));
    else
        maxLength = 0;
    end
                
    % Matlab code
    if isCode
        indentStr1 = repmat('   ', [1,nIndent+1]);
        % Multiple element
        if (M*N > 1)
            structString = sprintf('[...\n');
            indentStr2 = repmat('   ', [1,nIndent+2]);
        else
            indentStr2 = indentStr1;
        end
        % Process all the elements
        for iElem = 1:numel(s)
            % Starting struct
            if (M*N > 1) || (iElem > 1)
                structString = [structString, indentStr1];
            end
            structString = [structString, sprintf('struct(...\n')];
            % Printing the fields
            for iField = 1:length(MatFields)
                % Format value
                strField = FormatValue(s(iElem).(MatFields{iField}), isCode, nIndent+1);
                % Replace { and } with {{ and }}
                strField = strrep(strField, '{', '{{');
                strField = strrep(strField, '}', '}}');
                % Pad with spaces after the option name so that all the values line up nicely
                strPad = repmat(' ', 1, maxLength - length(MatFields{iField}));
                % Add: 'fieldname', 'fieldvalue'
                structString = [structString, indentStr2, '''', MatFields{iField}, ''', ' strPad, strField];
                if (iField ~= length(MatFields))
                    structString = [structString, sprintf(', ...\n')];
                end
            end
            % Closing the structure
            structString = [structString, ')'];
            % Array of this structure
            if (M*N > 1)
                if (iElem ~= numel(s))
                    structString = [structString, sprintf(', ...\n')];
                else
                    structString = [structString, ']'];
                end
            end
        end
        % If nothing to output (empty struct array)
        if (numel(s) == 0)
            % Opening structure
            structString = [structString, 'repmat(struct('];
            % Printing the fields (all empty)
            for iField = 1:length(MatFields)
                structString = [structString, '''', MatFields{iField}, ''', []'];
                if (iField ~= length(MatFields))
                    structString = [structString, sprintf(', ')];
                end
            end
            % Closing the structure
            structString = [structString, '), 0)'];
        end
    % Human-readable text file
    else
        indentStr = [repmat('  |  ', [1,nIndent]), '  |- '];
        % If no fields
        if isempty(MatFields)
            structString = sprintf(['%dx%d struct array with no fields\n', M, N]);
        % More than one field
        else
            % ONE ELEMENT
            if (M*N == 1)
                structString = [structString, 10];
                % Display all the struct fields
                for iField = 1:length(MatFields)
                    % Get field
                    A = s.(MatFields{iField});
                    % Compute number of tabulations after field name
                    tabulations = repmat(' ', [1, maxLength - length(MatFields{iField})]);
                    % Display indent and field name
                    structString = [structString, indentStr, MatFields{iField}, ': ', tabulations];
                    % Display value
                    structString = [structString, FormatValue(A, isCode, nIndent)];
                    if ~isstruct(A)
                        structString = [structString, 10];
                    end
                end

            % ARRAY OF STRUCTURES
            else
                structString = [structString, sprintf('[%dx%d struct]\n', M, N)];
                % Display each structure of the array
                for i = 1:M*N
                    structString = [structString, sprintf('%s<struct #%d>', indentStr, i)];
                    structString = [structString, FormatValue(s(i), isCode, nIndent)];
                end
            end
        end
    end
end


%% ===== FORMAT CELLS =====
function strC = FormatCellArray(C, isCode, nIndent)
    [M,N] = size(C);

    % Empty cell list
    if (M*N == 0)
        strC = '{}';
               
    % Small array : display values {x,x,x; y,y,y}
    elseif isCode || (M*N <= 4)
        strC = '{';
        % For each row
        for i = 1:M
            % For each column
            for j = 1:N
                % Display A[i,j]
                if isstruct(C{i,j})
                    strC = [strC, 'struct'];
                else
                    strC = [strC, FormatValue(C{i,j}, isCode, nIndent)];
                end
                if (j ~= N)
                    strC = [strC ', '];           
                end
            end
            % If it is not the last row
            if (i ~= M)
                strC = [strC '; '];       
            end
        end
        % Close array string
        strC = [strC '}'];
        
    % Big array : {NxM cell}
    else
        strC = sprintf('{%dx%d cell}', M, N);
    end
end


%% ===== FORMAT NUMERIC =====
function strA = FormatNumericArray(A, isCode, nIndent)
    [M,N,P,Q] = size(A);
    
    % Format class matrix
    if issparse(A)
        strClass = [class(A) ' sparse'];
    else
        strClass = class(A);
    end
    
    % Empty matrix
    if (M*N == 0)
        strA = '[]';
        
    % Scalar value
    elseif (M*N == 1)
        if isCode
            strA = num2str(A, '%10.10g');
        else
            strA = num2str(A);
        end
        
    % 4D array : [NxMxPxQ class]
    elseif (Q > 1)
        strA = sprintf('[%dx%dx%dx%d %s]', M, N, P, Q, strClass);
    % 3D array : [NxMxP class]
    elseif (P > 1)
        strA = sprintf('[%dx%dx%d %s]', M, N, P, strClass);
        
    % Small 2D array : display values [x,x,x; y,y,y]
    elseif isCode || (M*N <= 10)
        strA = '[';
        % For each row
        for i = 1:M
            % For each column
            for j = 1:N
                % Display A[i,j]
                if isCode
                    strA = [strA, num2str(A(i,j), '%10.10g')];
                else
                    strA = [strA, num2str(A(i,j))];
                end
                if (j ~= N)
                    strA = [strA ', '];           
                end
            end
            % If it is not the last row
            if (i ~= M)
                strA = [strA '; '];       
            end
        end
        % Close array string
        strA = [strA ']'];

    % Big 2D array : [NxM class]
    else
        strA = sprintf('[%dx%d %s]', M, N, strClass);
    end
end





