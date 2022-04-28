function [newS, iTrial] = str_remove_trial( s )
% STR_REMOVE_TRIAL: Remove the "_trialxxx" tag and its extension from a filename

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
% Authors: Francois Tadel, 2009-2010

strIndTrial = '';
iTrial = [];
iTagBegin = strfind(lower(s), '_trial');
if isempty(iTagBegin)
    newS = '';
else
    iTagBegin = iTagBegin(1);
    % Find the end of the tag (minimum number of digits: 2)
    iTagEnd = iTagBegin + 6;
    % Find the last dot (extenstion: to be removed)
    iLastDot = strfind(s, '.');
    if isempty(iLastDot)
        iLastDot = length(s) + 1;
    else
        iLastDot = iLastDot(end);
    end
    % Go to the end of the tag
    while ((iTagEnd < iLastDot) && ismember(s(iTagEnd), '0123456789'))
        if (nargout >= 2)
            strIndTrial(end+1) = s(iTagEnd);
        end
        iTagEnd = iTagEnd + 1;
    end
    % If nothing interesting found after the tag
    if (iTagEnd == iLastDot)
        newS = s(1:iTagBegin-1);
    else
        newS = s([1:iTagBegin-1, iTagEnd:iLastDot-1]);
    end
    % Read trial number
    if (nargout >= 2) && ~isempty(strIndTrial)
        iTrial = str2num(strIndTrial);
    end
end

