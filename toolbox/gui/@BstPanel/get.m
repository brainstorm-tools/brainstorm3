function [propValue, srcObj] = get(obj, propName)
% Accessor for reading BstPanel attributes.

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

% Check if the field propName exists in the object
if (ismember(propName, fields(obj)))
    % If it exists, try to return its value
    if (length(obj) == 1)
        propValue = obj.(propName);
        srcObj    = obj;
    else
        propValue = {obj.(propName)};
        srcObj    = obj;
    end
   
else
    %iPanel = find(cellfun(@(f)isfield(f, propName), obj.sControls), 1);
    if isfield(obj.sControls, propName)
        propValue = obj.sControls.(propName);
        srcObj    = obj;
    else
        propValue = [];
        srcObj    = [];
    end
end

end


