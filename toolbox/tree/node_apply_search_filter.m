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

if contains(fileComment, 'MyTest')
    %disp('hey');
end

filteredComment = fileComment;

% If no filter applied, the file passes by default
if iSearchFilter == 0
    if iscell(fileName)
        res = true(1, length(fileName));
    else
        res = 1;
    end
    return;
end

searchRoot = panel_protocols('Search', 'get', iSearchFilter);
if isempty(searchRoot)
    error(sprintf('Could not find active search #%d', iSearchFilter));
end

[res, boldKeywords] = TestSearchTree(searchRoot, fileType, fileComment, fileName);

% Bold contained keywords in node comment
if ~isempty(boldKeywords)
    for iKeyword = 1:length(boldKeywords)
        filteredComment = strrep(filteredComment, boldKeywords{iKeyword}, ['<B>' boldKeywords{iKeyword} '</B>']);
    end
    filteredComment = ['<HTML>' filteredComment];
end
end

function [res, boldKeywords] = TestSearchTree(root, fileType, fileComment, fileName)
    if iscell(fileName)
        res = true(1, length(fileName));
    else
        res = 1;
    end
    nextBool = 0;
    nChildren = length(root.Children);
    boldKeywords = {};
    
    for iChild = 1:nChildren
        switch root.Children(iChild).Type
            case 1 % Search param
                param = root.Children(iChild).Value;
                [curRes, boldKeyword] = TestParam(param, fileType, fileComment, fileName);
                % Save comment 
                if any(curRes) && ~isempty(boldKeyword)
                    boldKeywords{end + 1} = boldKeyword;
                end
            case 2 % Boolean
                nextBool = root.Children(iChild).Value;
                curRes = [];
            case 3 % Nested block, apply test recursively
                [curRes, boldKeywords2] = TestSearchTree(root.Children(iChild), fileType, fileComment, fileName);
                boldKeywords = [boldKeywords, boldKeywords2];
            otherwise
                error('Invalid node type.');
        end
        
        if ~isempty(curRes)
            switch nextBool
                case 1 % AND
                    res = res && curRes;
                case 2 % OR
                    res = res || curRes;
                otherwise
                    res = curRes;
            end
        end
            
    end
end

function [matches, boldKeyword] = TestParam(param, fileType, fileComment, fileName)
    boldKeyword = [];
    % Choose value to search for
    if param.SearchType == 1
        % Comment
        fileValue = fileComment;
    elseif param.SearchType == 2
        % Type
        fileValue = fileType;
    elseif param.SearchType == 3
        % File name
        fileValue = fileName;
    else
        error('Unsupported search type');
    end
    
    % Apply case sensitivity
    searchValue = param.Value;
    if ~param.CaseSensitive
        fileValue = lower(fileValue);
        searchValue = lower(searchValue);
    end
    
    % Detect if we're testing multiple files at once
    if iscell(fileValue)
        nFiles = length(fileValue);
        matches = true(1, nFiles);
    else
        fileValue = {fileValue};
        nFiles = 1;
        matches = 1;
    end
    
    for iFile = 1:nFiles
        % Test for equality
        if param.EqualityType == 1
            % Contains
            allMatches = strfind(fileValue{iFile}, searchValue);
            matches(iFile) = ~isempty(allMatches);
            % Add bold tags to search keyword(s)
            if matches(iFile)
                boldKeyword = searchValue;
            end
        elseif param.EqualityType == 2
            % Equals
            matches(iFile) = any(strcmp(fileValue{iFile}, searchValue));
        else
            error('Unsupported equality type');
        end
    end
end

