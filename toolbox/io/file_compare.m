function res = file_compare(f1, f2)
% FILE_COMPARE: Compare filenames (case-sensitive and OS-independent).
%
% USAGE:  res = file_compare(f1, f2);
% 
% INPUT:  f1 and f2 can be either single strings or cell array of strings
%         If both are cell arrays, they must be of the same length
%
% OUTPUT: For each comparison : 1 if filenames are equal
%                               0 if filenames do not point the same file

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
% Authors: Francois Tadel, 2008

% Check for empty inputs
if (isemptycell(f1) && isemptycell(f2))
    res = 1;
    return
elseif (isemptycell(f1) || isemptycell(f2))
    res = 0;
    return
end

if iscell(f1) &&  iscell(f2) && length(f1) ~= length(f2)
    res = 0;
    return
end

% Check for empty matrices in cell arrays
if iscell(f1)
    f1(cellfun(@isempty, f1)) = {''};
end
if iscell(f2)
    f2(cellfun(@isempty, f2)) = {''};
end

% Remove all OS-dependent characters : '\' and '/'
if iscell(f1)
    f1 = strrep(f1, '/', '');
    f1 = strrep(f1, '\', '');
else
    f1((f1 == '\') | (f1 == '/')) = [];
end
if iscell(f2)
    f2 = strrep(f2, '/', '');
    f2 = strrep(f2, '\', '');
else
    f2((f2 == '\') | (f2 == '/')) = [];
end    
% Compare files
res = strcmp(f1, f2);

end


function res = isemptycell(c)
    res = (isempty(c) || (iscell(c) && (length(c) == 1) && isempty(c{1})));
end



    
