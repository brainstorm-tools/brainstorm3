function [uniqueFile, tag] = file_unique(filename, allFiles, isCaseSensitive)
% FILE_UNIQUE: Make a filename unique by adding a suffix to it (eg. '_01').
%
% USAGE: [uniqueFile, tag] = file_unique(filename, allFiles, isCaseSensitive=0);  : Look for a unique string in a list of strings
%        [uniqueFile, tag] = file_unique(filename);                               : Look for a unique filename on the hard drive
%
% INPUT:
%     - filename : Full path to file to make unique
%     - allFiles : List of reference strings; if not specified, use the file system
% OUTPUT:
%     - uniqueFile : Full path to a file that does not exist yet.
%     - tag        : Tag that was added to the file to make it unique

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
% Authors: Francois Tadel, 2008-2016

% Parse inputs
if (nargin < 3) || isempty(isCaseSensitive)
    isCaseSensitive = 0;
end
if (nargin < 2) || isempty(allFiles)
    allFiles = [];
end
% Decompose filename
if isempty(allFiles)
    [fPath, fBase, fExt] = bst_fileparts(filename);
    if isdir(filename)
        fBase = [fBase, fExt];
        fExt = '';
    end
else
    fBase = filename;
    fPath = '';
    fExt = '';
    % Remove empty cells
    allFiles(cellfun(@isempty, allFiles)) = [];
end
tag = '';

% If file already exist : add a suffix
if test_file(filename, allFiles, isCaseSensitive)
    % Look for a '_' at the end of the filename
    indSeparator = strfind(fBase, '_');
    % If no '_' is found
    if isempty(indSeparator)
        indSeparator = length(fBase) + 1;
        indFile = 1;
        lenInd = 2;
    else
        % If after the last '_' there is a number
        strInd = fBase(indSeparator(end)+1:end);
        indFile = str2double(strInd);
        lenInd = length(strInd);
        % If there is no indice in the filename, default indice = 1
        if isempty(indFile) || isnan(indFile)
            indSeparator = length(fBase) + 1;
            indFile = 1; 
            lenInd = 2;
        end
    end
    % Add a '_i' at the end of the filename, where i is the indice
    while test_file(bst_fullfile(fPath, [fBase, fExt]), allFiles, isCaseSensitive)
        indFile = indFile + 1;
        tag = sprintf(['_%0' num2str(lenInd) 'd'], indFile);
        fBase = [fBase(1:indSeparator(end)-1), tag];
    end
    % Rebuild full filename
    uniqueFile = bst_fullfile(fPath, [fBase, fExt]);

% Else : input filename is already unique
else
    uniqueFile = filename;
end
end


%% ===== HELPER =====
function res = test_file(filename, allFiles, isCaseSensitive)
    if isempty(allFiles)
        res = file_exist(filename);
    elseif isCaseSensitive
        res = ismember(filename, allFiles);
    else
        res = ismember(lower(filename), lower(allFiles));
    end
end

