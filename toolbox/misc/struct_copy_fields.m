function sDest = struct_copy_fields(sDest, sSrc, override)
% STRUCT_COPY_FIELDS: Copy the fields from sSrc structure to sDest structure

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
% Authors: Sylvain Baillet, March 2002

if (nargin < 3) || isempty(override)
    override = 1;
end

% No fields to add
if isempty(sSrc)
    return
% No fields in destination structure
elseif isempty(sDest)
    sDest = sSrc;
% Fields in both structures
else
    namesSrc = fieldnames(sSrc);
    for i = 1:length(namesSrc)
        if override || ~isfield(sDest, namesSrc{i})
            sDest.(namesSrc{i}) = sSrc.(namesSrc{i});
        end
    end
end

