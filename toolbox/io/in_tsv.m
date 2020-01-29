function cTsv = in_tsv(TsvFile, ColNames, isWarning)
% IN_TSV: Reads specific columns in a .tsv file

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
% Authors: Francois Tadel, 2018-2019

% Parse inputs
if (nargin < 3) || isempty(isWarning)
    isWarning = 1;
end
% Intialize returned variable
cTsv = {};
% Open file
fid = fopen(TsvFile, 'r');
if (fid < 0)
    disp(['Error: Cannot open file: ' TsvFile]);
    return;
end
    
% Read header
tsvHeader = str_split(fgetl(fid), sprintf('\t'));
tsvFormat = repmat('%s ', 1, length(tsvHeader));
tsvFormat(end) = [];
% Read file
tsvValues = textscan(fid, tsvFormat, 'Delimiter', '\t');
% Close file
fclose(fid);

% If no values were read
if isempty(tsvValues) || isempty(tsvValues{1})
    disp(['Error: No values read from file: ' TsvFile]);
    return;
end

% Create empty cell array of values
cTsv = cell(length(tsvValues{1}), length(ColNames));
% Get the values for each column
for i = 1:length(ColNames)
    iCol = find(strcmpi(tsvHeader, ColNames{i}));
    if ~isempty(iCol)
        cTsv(:,i) = tsvValues{iCol};
    elseif isWarning
        disp(['Error: Column "' ColNames{i} '" not found in file: ' TsvFile]);
    end
end


