function [strList, commonBegin, commonEnd] = str_remove_common( strList )
% STR_REMOVE_COMMON: Identify and remove everything that is common to a cell array of strings

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2016

% Initialize returned variables
commonBegin  = '';
commonEnd    = '';
% Parse inputs
if ~iscell(strList)
    error('Invalid call to str_remove_common()');
elseif isempty(strList)
    return;
end
% If all the strings are equal: remove everything
if all(cellfun(@(c)isequal(c,strList{1}), strList))
    commonBegin = strList{1};
    strList = cell(size(strList));
    return;
end

% Get the minimum string size
minLength = min(cellfun(@length, strList));

% Find common beginning
iBegin = 1;
while (iBegin < minLength) && all(cellfun(@(c)isequal(c(iBegin), strList{1}(iBegin)), strList))
    iBegin = iBegin + 1;   
end
% If there is a common beginning: remove it
if (iBegin > 1)
    commonBegin = strList{1}(1:iBegin-1);
    strList = cellfun(@(c)c(iBegin:end), strList, 'UniformOutput', 0);
    % Update the minimum string size
    minLength = min(cellfun(@length, strList));
end

% Find common end
iEnd = 1;
while (iEnd < minLength) && all(cellfun(@(c)isequal(c(length(c)-iEnd+1), strList{1}(length(strList{1})-iEnd+1)), strList))
    iEnd = iEnd + 1;   
end
% If there is a common beginning: remove it
if (iEnd > 1)
    commonEnd = strList{1}(end-iEnd+2:end);
    strList = cellfun(@(c)c(1:end-iEnd+1), strList, 'UniformOutput', 0);
end


