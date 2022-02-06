function sNew = str_remove_parenth( s, parType )
% STR_REMOVE_PARENTH: Remove everything after the last occurrence of parType in a string s.

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
% Authors: Francois Tadel, 2008-2010

% Default returned string is original string
%sNew = deblank(s);
sNew = s;
% Default parenthesis type is '('
if (nargin < 2)
    parType = '(';
end
% Get opening/closing parenthesis
switch parType
    case '(',  chOpen = '('; chClose = ')';
    case '[',  chOpen = '['; chClose = ']';
    case '{',  chOpen = '{'; chClose = '}';
    otherwise, error('Invalid parenthesis type');
end

% Find the occurrences of opening and closing parethesis
iParOpen  = find(sNew == chOpen);
iParClose = find(sNew == chClose);
if isempty(iParOpen) || isempty(iParClose)
    return
end

% Process each opening parenthesis
iRmInd = [];
for i = 1:length(iParOpen)
    iNext = find(iParClose > iParOpen(i), 1);
    if ~isempty(iNext)
        iRmInd = [iRmInd, iParOpen(i):iParClose(iNext)];
    end
end
% Remove characters
sNew(iRmInd) = [];
sNew = strtrim(sNew);


