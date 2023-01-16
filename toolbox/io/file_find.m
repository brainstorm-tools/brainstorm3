function [foundFiles, iDepth] = file_find( baseDir, filePattern, maxDepth, isSingle, iDepth )
% FILE_FIND: Find a file recursively.
%
% USAGE:  [foundFiles, iFoundDepth] = file_find( baseDir, filePattern, maxDepth=Inf, isSingle=1 )
% 
% INPUT:
%    - baseDir     : Full path to the directory to search
%    - filePattern : Name of the target file (wild chars allowed)
%    - maxDepth    : Maximum folder depth from the baseDir
%    - isSingle    : If 1, only search for one file, exit when it's found
%    - iDepth      : Current recursion level
%
% OUTPUT:
%    - foundFiles : Full path to files, or [] if no file were found

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
% Authors: Francois Tadel, 2008-2022

% Parse inputs
if (nargin < 5) || isempty(iDepth)
    iDepth = 1;
end
if (nargin < 4) || isempty(isSingle)
    isSingle = 1;
end
if (nargin < 3) || isempty(maxDepth)
    maxDepth = Inf;
end
if (nargin < 2)
    error('foundFiles = file_find( baseDir, filePattern, maxDepth, isSingle );');
end
% Default return value
if isSingle
    foundFiles = [];
else
    foundFiles = {};
end

% Base dir not valid
if isempty(baseDir) || ~isdir(baseDir) || (baseDir(1) == '.')
    return;
% Pattern is a subfolder of the base dir
elseif isSingle && ~any(filePattern == '*') && isdir(fullfile(baseDir, filePattern))
    foundFiles = fullfile(baseDir, filePattern);
    return;
else
    % Try to find required file
    listDir = dir(fullfile(baseDir, filePattern));
    if ~isempty(listDir)
        if isSingle
            foundFiles = fullfile(baseDir, listDir(1).name);
        else
            for i = 1:length(listDir)
                foundFiles = cat(2, foundFiles, {fullfile(baseDir, listDir(i).name)});
            end
        end
        return
    end
    % If reached the recursion limit
    if (maxDepth <= 1)
        return
    end
    % Get subdirectories
    listDir = dir(fullfile(baseDir, '*'));
    listDir([listDir.isdir] == 0) = [];
    % Process each subdirectory
    for i = 1:length(listDir)
        if (listDir(i).name(1) ~= '.')
            newDir = fullfile(baseDir, listDir(i).name);
            [foundRec, iFoundDepth] = file_find(newDir, filePattern, maxDepth - 1, isSingle, iDepth + 1);
            if ~isempty(foundRec)
                iDepth = iFoundDepth;
                % Looking for one file only: return
                if isSingle
                    foundFiles = foundRec;
                    return;
                % Otherwise: Keep searching
                else
                    foundFiles = cat(2, foundFiles, foundRec);
                end
            end
        end
    end
end
iDepth = [];


