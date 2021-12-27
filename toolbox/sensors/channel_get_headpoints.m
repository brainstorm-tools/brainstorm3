function HeadPoints = channel_get_headpoints(ChannelFile, MinHeadPoints, UseEeg) 
% Get digitized head points in a Brainstorm channel file.
% 
% USAGE:  HeadPoints = channel_get_headpoints(ChannelFile, MinHeadPoints=20, UseEeg=1) 
%         HeadPoints = channel_get_headpoints(ChannelMat, MinHeadPoints=20, UseEeg=1) 

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
% Authors: Francois Tadel, 2010


% Parse inputs
if (nargin < 3) || isempty(UseEeg)
    UseEeg = 1;
end
if (nargin < 2) || isempty(MinHeadPoints)
    MinHeadPoints = 20;
end
if ischar(ChannelFile)
    % Load channel file
    ChannelMat = in_bst_channel(file_fullpath(ChannelFile));
else
    ChannelMat = ChannelFile;
end
HeadPoints = [];


% If less than MinHeadPoints
if isempty(ChannelMat) 
    return;
elseif ~isfield(ChannelMat, 'HeadPoints') || ~isfield(ChannelMat.HeadPoints, 'Loc') || (length(ChannelMat.HeadPoints.Loc) < MinHeadPoints)
    % Check if there are EEG channels
    iEeg = good_channel(ChannelMat.Channel, [], 'EEG');
    % Loop and keep only the ones with a valid location
    iGoodEeg = [];
    for i = 1:length(iEeg)
        if ~isempty(ChannelMat.Channel(iEeg(i)).Loc) && ~all(ChannelMat.Channel(iEeg(i)).Loc(:) == 0)
            iGoodEeg(end+1) = iEeg(i);
        end
    end
    iEeg = iGoodEeg;
    % If there is no EEG: return
    if isempty(iEeg) || (length(iEeg) < MinHeadPoints) || ~UseEeg
        return;
    end
    % Convert EEG channels to head points
    HeadPoints.Loc   = [ChannelMat.Channel(iEeg).Loc];
    HeadPoints.Label = {ChannelMat.Channel(iEeg).Name};
    HeadPoints.Type  = repmat({'EXTRA'}, [1,length(HeadPoints.Label)]);
    
% Else: return head points
else
    HeadPoints = ChannelMat.HeadPoints;
end




           