function value = bst_saturate( value, bounds, isInterval )
% BST_SATURATE: Constrain a value to be in a given interval.
%
% USAGE:  value = bst_saturate( value, bounds, isInterval=0 )
%
% INPUT:
%    - value      : value to saturate
%    - bounds     : [b1,b2] lower and upper bounds of the interval
%    - isInterval : If 1, consider value as an interval
% OUTPUT:
%    - value  : value forced in the input bounds

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
% Authors: Francois Tadel, 2008-2014

if (nargin < 3) || isempty(isInterval)
    isInterval = 0;
end

% Saturate values
if ~isInterval
    value(value < bounds(1)) = bounds(1);
    value(value > bounds(2)) = bounds(2);
% Saturate intervals
else
    interval = value;
    % If interval is longer than the bounds segment
    if (interval(2) - interval(1) >= bounds(2) - bounds(1))
        value = bounds;
    % If interval begins before the bound
    elseif (interval(1) < bounds(1))
        value = [bounds(1), ...
                 bounds(1) + interval(2) - interval(1)];
    % If interval stops after the bound
    elseif (interval(2) > bounds(2))
        value(1) = interval(1) - (interval(2) - bounds(2));
        value(2) = value(1) + interval(2) - interval(1);   
    else
        value = interval;
    end
end


    