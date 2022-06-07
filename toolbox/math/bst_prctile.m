function value = bst_prctile(vector, percentile)
% BST_PRCTILE: Returns the percentile value in vector
%
% USAGE: value = bst_prctile(vector, percentile)

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
% Authors: Martin Cousineau, 2020
%          Raymundo Cassani, 2022      

% Try to use toolbox function
if exist('prctile','file')
    value = prctile(vector, percentile);
    return;
end

% Check inputs
if ~isvector(vector)
    error('Only vectors supported.');
end
if any(percentile < 0 | percentile > 100)
    error('Input percentile must be a real value between 0 and 100.');
end

% Custom implementation
vector = sort(vector);
rank   = percentile / 100 * length(vector);
lowerRank = floor(rank + 0.5);
upperRank = lowerRank + 1;
fraction  = rank - lowerRank;
lowerRank(lowerRank < 1) = 1;
upperRank(upperRank > length(vector)) = length(vector);
value = 0.5 * (vector(lowerRank) + vector(upperRank));

if fraction ~= 0
    value = value + fraction * (vector(upperRank) - vector(lowerRank));
end
