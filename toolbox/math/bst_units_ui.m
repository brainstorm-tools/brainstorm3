function Value = bst_units_ui(Units, Value)
% BST_UNITS_IU: Scale values to international units (meters)
%
% USAGE:   Value = bst_units_ui(Units, Value)   % Scale values in input
%         Factor = bst_units_ui(Units)          % Returns scaling factor

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
% Authors: Francois Tadel, 2022

% Supported units
switch strtrim(str_remove_spec_chars(lower(Units)))
    case 'mm'
        factor = 0.001;
    case 'cm'
        factor = 0.01;
    case 'm'
        factor = 1;
    otherwise
        disp(['BST> Warning: Unknown units "' Units '"']);
        factor = 1;
end
% Return scaling factor
if (nargin < 2)
    Value = factor;
% Apply scaling factor
elseif (factor ~= 1)
    Value = factor .* Value;
end
