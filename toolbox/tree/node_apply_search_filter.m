function [res, filteredComment] = node_apply_search_filter(iSearchFilter, fileType, fileComment, fileName)
% NODE_CREATE_SUBJECT: Create subject node from subject structure.
%
% USAGE:  TODO
%
% INPUT: 
%     - nodeSubject : TODO

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
% Authors: Martin Cousineau, 2019

filteredComment = fileComment;

% If no filter applied, the file passes by default
if iSearchFilter == 0
    res = 1;
    return;
end

searchParams = panel_protocols('Search', 'get', iSearchFilter);
if isempty(searchParams)
    error(sprintf('Could not find active search #%d', iSearchFilter));
end

for iParam = 1:length(searchParams)    
    % Choose value to search for
    if searchParams(iParam).SearchType == 1
        % Comment
        fileValue = fileComment;
    elseif searchParams(iParam).SearchType == 2
        % Type
        fileValue = fileType;
    elseif searchParams(iParam).SearchType == 3
        % File name
        fileValue = fileName;
    else
        error('Unsupported search type');
    end
    
    % Apply case sensitivity
    searchValue = searchParams(iParam).Value;
    if ~searchParams(iParam).CaseSensitive
        fileValue = lower(fileValue);
        searchValue = lower(searchValue);
    end
    
    % Test for equality
    if searchParams(iParam).EqualityType == 1
        % Contains
        allMatches = strfind(fileValue, searchValue);
        matches = ~isempty(allMatches);
        % Add bold tags to search keyword(s)
        if matches
            filteredComment = '<HTML>';
            keywordSize = length(searchValue);
            totalSize = length(fileComment);
            iCur = 1;
            % Loop through keywords found
            for iMatch = 1:length(allMatches)
                iPos = allMatches(iMatch);
                if iPos >= iCur
                    iNext = iPos + keywordSize;
                    filteredComment = [filteredComment fileComment(iCur:iPos-1) '<B>' fileComment(iPos:iNext-1) '</B>'];
                    iCur = iNext;
                end
            end
            % Add remaining of string, if any
            if iCur < totalSize
                filteredComment = [filteredComment fileComment(iCur:totalSize)];
            end
        end
    elseif searchParams(iParam).EqualityType == 2
        % Equals
        matches = strcmp(fileValue, searchValue);
    else
        error('Unsupported equality type');
    end
    
    % Apply boolean operation if not first filter
    if iParam > 1
        if searchParams(iParam).BooleanType == 1
            % AND
            res = res & matches;
        elseif searchParams(iParam).BooleanType == 2
            % OR
            res = res | matches;
        else
            error('Unsupported boolean type');
        end
    else
        res = matches;
    end
end

