function F = in_ascii(DataFile, SkipLines, isText)
% IN_ASCII: Read an ASCII file containing a matrix of floats or integers.
%
% USAGE:  F = in_ascii(DataFile, SkipLines=0, isText=0)
%         F = in_ascii(DataFile)
%
% INPUT: 
%    - DataFile  : Full path to an ASCII file
%    - SkipLines : Number of lines to skip at the beginning of the file (default: 0)
%    - isText    : If 1, read entries as text instead of values
% OUTPUT:
%    - F : Matrix read from the files (single)

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
% Authors: Francois Tadel, 2009-2022

% Parse inputs 
if (nargin < 2) || isempty(SkipLines)
    SkipLines = 0;
end
if (nargin < 3) || isempty(isText)
    isText = 0;
end

% If no lines to skip at the beginning of the file: use Matlab's "load" function
if (SkipLines == 0) && ~isText
    try 
        F = double(load(DataFile, '-ascii'));  % FT 11-Jan-10: Remove "single"
    catch
        F = [];
    end
% Else use the "txt2mat" function
else
    if ~isText
        F = double(txt2mat(DataFile, SkipLines));  % FT 11-Jan-10: Remove "single"
    else
        % Initialize output cell array
        F = {};
        % Open file
        fid = fopen(DataFile, 'r');
        if (fid < 0)
            error('Cannot open file.');
        end
        % Read line by line
        i = 0;
        iF = 0;
        while ~feof(fid)
            % Read next line
            i = i + 1;
            strLine = fgetl(fid);
            % Skip header lines
            if (i <= SkipLines) || isempty(strtrim(strLine))
                continue;
            end
            % If there are more commas than spaces or tabs: this is a CSV file
            if nnz(strLine == ',') > (nnz(strLine == ' ') + nnz(strLine == sprintf('\t')))
                tmp{1} = str_split(strLine, ',');
            % Else: Split line with tabs and spaces
            else
                tmp = textscan(strLine, '%s');
            end
            if isempty(tmp)
                continue;
            end
            % Add to returned cell array
            iF = iF + 1;
            F(iF, 1:length(tmp{1})) = tmp{1}';
        end
        % Close file
        fclose(fid);
    end
end



            