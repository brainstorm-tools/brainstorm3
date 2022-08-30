function sFix = struct_fix(sTemplate, sData)
% STRUCT_FIX: Convert a structure to a template (fix the list of fields)

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
% Authors: Francois Tadel, 2016

% Error if invalid inputs
if ~isstruct(sTemplate) || (~isstruct(sData) && ~isequal(sData, []))
    error('Input must be structures');
end

% Get the output field names
if ~isequal(sData, [])
    namesScr = fieldnames(sData);
else
    namesScr = {};
end
namesDest = fieldnames(sTemplate);
% If the structures are equal: nothing to change
if isequal(namesScr, namesDest)
    sFix = sData;
    return;
end

% Initialize the output structures
sFix = repmat(sTemplate, size(sData));
% Empty structure: return
if isempty(sFix)
    return;
end

% Keep only the names of the fields that are in both structures
names = intersect(namesDest, namesScr);

% Loop on the elements
for i = 1:length(sData)
    % Loop on the fields
    for iField = 1:length(names)
        % Copy only if the fiel
        sFix(i).(names{iField}) = sData(i).(names{iField});
    end
end



