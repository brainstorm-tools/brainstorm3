function headPos = head_surface_fixunits(headPos, units, isConfirmFix)
% HEAD_SURFACE_FIXUNITS: Checks the units of the head surface vertices and ask user if the situation is not clear.
% 
% USAGE:  headPos = head_surface_fixunits(headPos, units, isConfirmFix=1)
%
% INPUTS:
%    - headPos      : the vertices of the head surface
%    - units        : String, expected units (default: 'm')
%    - isConfirmFix : If 1, ask for a confirmation of the scaling factor to apply
%                     If 0, apply automatically the detected scaling factor
%
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
% inspired by 'channel_fixunits.m'
%
% Authors: Chinmay Chinara, 2024

% Parse inputs
if (nargin < 3) || isempty(isConfirmFix)
    isConfirmFix = 1;
end
if (nargin < 2) || isempty(units)
    units = 'm';
    isConfirmFix = 1;
end
if isempty(headPos)
    return;
end

% Get head center
headCenter = mean(headPos, 2);
% Compute mean distance from head center
meanNorm = mean(sqrt((headPos(1,:) - headCenter(1)) .^ 2 + (headPos(2,:) - headCenter(2)) .^ 2 + (headPos(3,:) - headCenter(3)) .^ 2));
% If distances units do not seem to be in meters (if head mean radius > 200mm or < 30mm)
if (meanNorm > 0.200) || (meanNorm < 0.030)       
    % Detect the best factor possible
    FactorTest = [0.001, 0.01, 0.1, 1, 10, 100, 1000];
    iFactor = bst_closest(0.15, FactorTest .* meanNorm);
    strFactor = num2str(FactorTest(iFactor));
    % Ask user if we should scale the distances
    if isConfirmFix
        strFactor = java_dialog('question', ...
            ['Warning: The head surface vertices might not be in the expected units (' units ').' 10 ...
             'Please select a scaling factor for the units (suggested: ' strFactor '):' 10 10], 'Import channel file', ...
            [], {'0.001', '0.01', '0.1', '1', '10', '100' '1000'}, strFactor);
    end
    % If user accepted to scale
    if ~isempty(strFactor) && ~isequal(strFactor, '1')
        Factor = str2num(strFactor);
        % Apply correction to position values
        headPos = headPos .* Factor;
    end
end

