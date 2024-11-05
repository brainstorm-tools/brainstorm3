function ChannelMat = channel_fixunits(ChannelMat, FileUnits, isConfirmFix, isVertices)
% CHANNEL_FIXUNITS: Checks the units of the channel file and ask user if the situation is not clear.
% 
% USAGE:  ChannelMat = channel_fixunits(ChannelMat, FileUnits, isConfirmFix=1)
%
% INPUTS:
%    - ChannelMat   : Brainstorm channel file structure, or [Nx3] locations
%    - FileUnits    : String, expected units in the file being read
%    - isConfirmFix : If 1, ask for a confirmation of the scaling factor to apply
%                     If 0, apply automatically the detected scaling factor
%    - isVertices   : Optional, default=0
%                     If 1, update strings 'electrode' -> 'vertices', 'channel' -> 'surface'
%
% OUTPUT:
%    - ChannelMat   : Same type as ChannelMat input

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
% Authors: Francois Tadel, 2017
%          Raymundo Cassani, 2024

% Parse inputs
if (nargin < 4) || isempty(isVertices)
    isVertices = 0;
end
if (nargin < 3) || isempty(isConfirmFix)
    isConfirmFix = 1;
end

if isstruct(ChannelMat)
    % Get EEG channels
    iEEG = good_channel(ChannelMat.Channel, [], {'EEG','SEEG','ECOG','Fiducial'});
    % If not enough channels: nothing to do
    if (length(iEEG) <= 8) && (length(iEEG) ~= length(ChannelMat.Channel))
        return;
    end
    % Get all EEG locations
    eegLoc = [];
    for k = 1:length(iEEG)
        if ~isempty(ChannelMat.Channel(iEEG(k)).Loc) && ~isequal(ChannelMat.Channel(iEEG(k)).Loc, [0;0;0])
            eegLoc = [eegLoc, ChannelMat.Channel(iEEG(k)).Loc(:,1)];
        end
    end
else
    eegLoc = ChannelMat';
end
if isempty(eegLoc)
    return;
end

% Get head center
eegCenter = mean(eegLoc, 2);
% Compute mean distance from head center
meanNorm = mean(sqrt((eegLoc(1,:) - eegCenter(1)) .^ 2 + (eegLoc(2,:) - eegCenter(2)) .^ 2 + (eegLoc(3,:) - eegCenter(3)) .^ 2));
% If distances units do not seem to be in meters (if head mean radius > 200mm or < 30mm)
if (meanNorm > 0.200) || (meanNorm < 0.030)       
    % Detect the best factor possible
    FactorTest = [0.001, 0.01, 0.1, 1, 10, 100, 1000];
    iFactor = bst_closest(0.15, FactorTest .* meanNorm);
    strFactor = num2str(FactorTest(iFactor));
    % Ask user if we should scale the distances
    if isConfirmFix
        % Strings for GUI message
        locType  = 'EEG electrodes';
        fileType = 'channel';
        if isVertices
            locType  = 'vertices';
            fileType = 'surface';
        end
        strFactor = java_dialog('question', ...
            ['Warning: The ' locType ' locations might not be in the expected units (' FileUnits ').' 10 ...
             'Please select a scaling factor for the units (suggested: ' strFactor '):' 10 10], ['Import ' fileType ' file'], ...
            [], {'0.001', '0.01', '0.1', '1', '10', '100' '1000'}, strFactor);
    end
    % If user accepted to scale
    if ~isempty(strFactor) && ~isequal(strFactor, '1')
        Factor = str2num(strFactor);
        % Apply correction to location values
        if isstruct(ChannelMat)
            for k = 1:length(iEEG)
                ChannelMat.Channel(iEEG(k)).Loc = ChannelMat.Channel(iEEG(k)).Loc .* Factor;
            end
            % Apply correction to head points
            isHeadPoints = isfield(ChannelMat, 'HeadPoints') && ~isempty(ChannelMat.HeadPoints.Loc);
            if isHeadPoints
                ChannelMat.HeadPoints.Loc = ChannelMat.HeadPoints.Loc .* Factor;
            end
        else
            ChannelMat = eegLoc' .* Factor;
        end
    end
end

