function [isOk, onlineRel] = bst_check_internet()
% BST_CHECK_INTERNET:  Check if an internet connection is available.

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
% Authors: Francois Tadel, 2009-2019

% Initialize returned values
isOk = 0;
onlineRel = [];
% Reading function: urlread replaced with webread in Matlab 2014b
if (bst_get('MatlabVersion') <= 803)
    url_read_fcn = @urlread;
else
    url_read_fcn = @webread;
end
% Read online version.txt
try
    str = url_read_fcn('http://neuroimage.usc.edu/bst/getversion.php');
catch
    return;
end
if (length(str) < 20)
    return;
end
% Find release date in text file
iParent = strfind(str, '(');
if (length(iParent) ~= 1)
    return;
end
dateStr = str(iParent - 7:iParent - 2);
% Interpetation of date string
onlineRel.year  = str2num(dateStr(1:2));
onlineRel.month = str2num(dateStr(3:4));
onlineRel.day   = str2num(dateStr(5:6));
isOk = 1;
