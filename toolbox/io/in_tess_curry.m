function TessMat = in_tess_curry( TessFile )
% IN_TESS_CURRY: Read Curry tesselation files

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
% Authors: Francois Tadel, 2012

% Open tesselation file
fid = fopen(TessFile, 'r');
if fid < 0
    error(['Cannot open file ', TessFile]);
end
% Initialize variables 
TessMat = struct('Comment', '', 'Vertices', [], 'Faces', []);
curBlock = [];

% Read file line by line
while 1
    % Read one line
    newLine = fgetl(fid);
    if ~ischar(newLine)
        break;
    end
    % Lines to skip
    if isempty(newLine)
        continue;
    end
    % Identify blocks
    if ~isempty(strfind(newLine, 'LOCATION_LIST START_LIST'))
        curBlock = 'Vertices';
        continue;
    elseif ~isempty(strfind(newLine, 'TRIANGLE_LIST START_LIST'))
        curBlock = 'Faces';
        continue;
    elseif ~isempty(strfind(newLine, 'POINT_DESCRIPTION START_LIST'))
        curBlock = 'Comment';
        continue;
    elseif ~isempty(strfind(newLine, 'END'))
        curBlock = [];
        continue;
    end
    % If no block is open: skip the line
    if isempty(curBlock)
        continue;
    end
    % Numeric values
    if ismember(curBlock, {'Vertices', 'Faces'})
        % Interpret values: 3 values per line
        values = str2num(newLine);
        if (length(values) < 3)
            continue;
        end
        % Add to the list 
        TessMat.(curBlock) = [TessMat.(curBlock); values];
    % Text
    else
        TessMat.(curBlock) = [TessMat.(curBlock), newLine];
        % Read only the first line of the comments
        if strcmpi(curBlock, 'Comment')
            curBlock = [];
        end
    end
end
% Close file
fclose(fid);

% Check that some vertices where loaded
if isempty(TessMat.Vertices)
    error('This file does not contain any Curry BEM surface.');
end
% Rebuild tesselation
if isempty(TessMat.Faces)
    % Get the convex envelope of the points
    TessMat.Faces = convhulln(TessMat.Vertices);
else
    % Convert from 0-based to 1-based indices
    TessMat.Faces = TessMat.Faces + 1;
    % Reverse faces order
    TessMat.Faces = TessMat.Faces(:, [1 3 2]);
end


