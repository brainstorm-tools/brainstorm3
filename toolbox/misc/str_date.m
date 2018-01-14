function strDate = str_date(s)
% STR_Date: Reformat date string to dd-MMM-yyyy.

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2018

% Clean string 
s = strtrim(strrep(s, char(0), ''));
% Check various input formats
try
    if isequal(find(s == '/'), [3 6]) && (length(s) == 10)
        strDate = datestr(datenum(s, 'dd/mm/yyyy'));
    elseif isequal(find(s == '.'), [3 6]) && (length(s) == 10)
        strDate = datestr(datenum(s, 'dd.mm.yyyy'));
    elseif isequal(find(s == '-'), [3 6]) && (length(s) == 10)
        strDate = datestr(datenum(s, 'dd-mm-yyyy'));
    elseif isequal(find(s == '-'), [3 7]) && (length(s) == 11)
        strDate = datestr(datenum(s, 'dd-mmm-yyyy'));
    else
        strDate = [];
    end
catch
    strDate = [];
end



