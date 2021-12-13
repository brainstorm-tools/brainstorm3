function [cTsv, ColNames] = in_tsv(TsvFile, ColNames, isWarning, Delimiter, isDecimalComma)
% IN_TSV: Reads specific columns in a .tsv file
%
% USAGE:  [cTsv, ColNames] = in_tsv(TsvFile, ColNames=[all], isWarning=1, Delimiter=[tab], isDecimalComma=0)
%
% INPUTS:
%    - TsvFile   : Full path to input filename
%    - ColNames  : {1 x Ncol} Cell-array of strings (eg. {'col1', 'col2'})
%                  {2 x Ncol} Cell-array of strings, second row describes the format of the data (eg. {'col1', 'col2'; '%d', '%s'})
%                  If empty, read all the columns as strings
%    - isWarning : If 1, display a warning for each missing column name (only if ColNames is set)
%    - Delimiter : Character (eg. sprintf('\t') or ';)
%    - isDecimalComma : If 1, read the entire file, replace all the commas with dots, and then scan it

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
% Authors: Francois Tadel, 2018-2021

% Parse inputs
if (nargin < 5) || isempty(isDecimalComma)
    isDecimalComma = 0;
end
if (nargin < 4) || isempty(Delimiter)
    Delimiter = sprintf('\t');
elseif ~ischar(Delimiter) || (length(Delimiter) ~= 1)
    error('Delimiter must be a single character.');
end
if (nargin < 3) || isempty(isWarning)
    isWarning = 1;
end
Format = [];
if (nargin < 2) || isempty(ColNames)
    ColNames = [];
elseif ~iscell(ColNames)
    error('ColNames must be a cell-array of strings.');
elseif (size(ColNames,1) == 2)   % Reading data format
    Format = ColNames(2,:);
    ColNames = ColNames(1,:);
end
% Intialize returned variable
cTsv = {};
% Open file
fid = fopen(TsvFile, 'r');
if (fid < 0)
    disp(['Error: Cannot open file: ' TsvFile]);
    return;
end
% Skip 3 first characters (and maybe add later if they are expected to be part of the first column's name)
magic = fread(fid, [1 3], 'uint8=>uint8');

% Read header
tsvHeader = str_split(fgetl(fid), Delimiter);
% Format: By default, read only strings
tsvFormat = repmat({'%s'}, 1, length(tsvHeader));
% Otherwise, specify column by column the type of data to read
if ~isempty(Format) && (length(Format) == length(ColNames))
    for iCol = 1:length(ColNames)
        iFormat = find(strcmpi(tsvHeader, ColNames{iCol}));
        if (length(iFormat) == 1)
            tsvFormat{iFormat} = Format{iCol};
        end
    end
end
tsvFormat = sprintf('%s ', tsvFormat{:});
tsvFormat(end) = [];
% Decimal commas
if isDecimalComma
    % Read file
    tsvRaw = fread(fid, [1 Inf], '*char');
    % Close file
    fclose(fid);
    % Replace commas with dots
    tsvRaw(tsvRaw == ',') = '.';
    % Read file
    tsvValues = textscan(tsvRaw, tsvFormat, 'Delimiter', Delimiter);
else
    % Scan file
    tsvValues = textscan(fid, tsvFormat, 'Delimiter', Delimiter);
    % Close file
    fclose(fid);
end

% If no values were read
if isempty(tsvValues) || isempty(tsvValues{1})
    disp(['Error: No values read from file: ' TsvFile]);
    return;
end
% If the first 3 characters where printable: add them to the first column name
indueSkip = magic((magic >= 32) & (magic <= 122));
if ~isempty(indueSkip)
    tsvHeader{1} = [indueSkip, tsvHeader{1}];
end

% Read all columns
if isempty(ColNames)
    ColNames = tsvHeader;
    cTsv = cat(2, tsvValues{:});
% Read selected columns
else
    % Create empty cell array of values
    cTsv = cell(length(tsvValues{1}), length(ColNames));
    % Get the values for each column
    for i = 1:length(ColNames)
        iCol = find(strcmpi(tsvHeader, ColNames{i}));
        if isempty(iCol)
            if isWarning
                disp(['Warning: Column "' ColNames{i} '" not found in file: ' TsvFile]);
            end
        elseif iscell(tsvValues{iCol})
            cTsv(:,i) = tsvValues{iCol};
        else
            cTsv(:,i) = num2cell(tsvValues{iCol});
        end
    end
end

