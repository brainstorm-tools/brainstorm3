function ChannelMat = channel_fixunits(ChannelMat, FileUnits)
% CHANNEL_FIXUNITS: Checks the units of the channel file and ask user if the situation is not clear.

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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

iEEG = good_channel(ChannelMat.Channel, [], {'EEG','SEEG','ECOG','Fiducial'});
if (length(iEEG) > 8) || (length(iEEG) == length(ChannelMat.Channel))    
    % Get all EEG locations
    eegLoc = [];
    for k = 1:length(iEEG)
        if ~isempty(ChannelMat.Channel(iEEG(k)).Loc) && ~isequal(ChannelMat.Channel(iEEG(k)).Loc, [0;0;0])
            eegLoc = [eegLoc, ChannelMat.Channel(iEEG(k)).Loc(:,1)];
        end
    end
    % If there are EEG positions
    if ~isempty(eegLoc)
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
            strFactor = java_dialog('question', ...
                ['Warning: The EEG electrodes locations do not seem to be in the expected units (' FileUnits ').' 10 ...
                 'Please select a scaling factor for the units (suggested: ' strFactor '):' 10 10], 'Import channel file', ...
                [], {'0.001', '0.01', '0.1', '1', '10', '100' '1000'}, strFactor);
            % If user accepted to scale
            if ~isempty(strFactor) && ~isequal(strFactor, '1')
                Factor = str2num(strFactor);
                % Apply correction to location values
                for k = 1:length(iEEG)
                    ChannelMat.Channel(iEEG(k)).Loc = ChannelMat.Channel(iEEG(k)).Loc .* Factor;
                end
                % Apply correction to head points
                isHeadPoints = isfield(ChannelMat, 'HeadPoints') && ~isempty(ChannelMat.HeadPoints.Loc);
                if isHeadPoints
                    ChannelMat.HeadPoints.Loc = ChannelMat.HeadPoints.Loc .* Factor;
                end
            end
        end
    end
end