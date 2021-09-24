function [ strCommon, cutStrList ] = str_common_path( strList, delimiters )
% STR_COMMON_PATH: Extract the common part in all the input strings.
%
% USAGE:  [ strCommon, cutStrList ] = str_common_path( strList )
%
% INPUTS: 
%     - strList : cell array of path (they must have the same depth)
%     - delimiters : String that contains all the characters used to split, default = '/\'
% OUTPUTS:
%     - strCommon  : common substring 
%     - cutStrList : strList without the common beginning string

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
% Authors: Francois Tadel, 2010-2014

% Parse inputs
if (nargin < 2) || isempty(delimiters)
    delimiters = '/\';
end

pathDepth = -1;
commonDepth = -1;
strSplitList = cell(size(strList));
N = numel(strList);

% Split all the paths
for i = 1:N
    strSplitList{i} = str_split(strList{i}, delimiters);
    if (pathDepth == -1) 
        pathDepth = length(strSplitList{i});
    elseif (length(strSplitList{i}) < pathDepth)
        pathDepth = length(strSplitList{i});
    end
end

% Process all path levels
for i = 1:pathDepth
    depthOk = 1;
    for j = 1:N
        if ~strcmpi(strSplitList{j}{i}, strSplitList{1}{i})
            depthOk = 0;
        end
    end
    if depthOk
        commonDepth = i;
    else
        break
    end
end

% ==== Get common part ====
% No common part
if (commonDepth == -1) || (pathDepth == 1)
    strCommon = '';
    cutStrList = strList;
% Paths are identical
elseif (commonDepth == pathDepth)
    strCommon = strList{1};
    cutStrList = repmat({''}, size(strList));
% Common path depth >= 1
else
    strCommon = '';
    for i = 1:commonDepth
        strCommon = [strCommon, strSplitList{1}{i}, delimiters(1)];
    end
    % Remove common part from all paths
    cutStrList = cellfun(@(c)strrep(c, strCommon, ''), strList, 'UniformOutput', 0);
    % Remove last '/' from common part
    strCommon = strCommon(1:end-1);
end
 

 