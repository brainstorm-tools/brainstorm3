function F = in_fread_kit(sFile, iEpoch, SamplesBounds, iChannels)
% IN_FREAD_KIT:  Read a block of recordings from a Yokogawa/KIT file
%
% USAGE:  F = in_fread_kit(sFile, iEpoch=1, SamplesBounds=All, ChannelsRange=[])
%
% This function is based on the Yokogawa MEG reader toolbox version 1.4.
% For copyright and license information and software documentation, 
% please refer to the contents of the folder brainstorm3/external/yokogawa

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
% Authors: Francois Tadel (2013)

% Parse inputs
if (nargin < 4) || isempty(iChannels)
    iChannels = [];
end
if (nargin < 3) || isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
end
if (nargin < 2) || isempty(iEpoch)
    iEpoch = 1;
end
% Sample bounds: convert from relative values (map with time) to absolute number
SamplesBounds = SamplesBounds - round(sFile.prop.times(1) .* sFile.prop.sfreq);

% Switch depending on the file type
switch (sFile.header.acq.acq_type)
    case {1,2}   % AcqTypeContinuousRaw / AcqTypeEvokedAve
        % Get the length of the segment to read (in samples)
        readLength = SamplesBounds(2) - SamplesBounds(1) + 1;
        % Read from file using Yokogawa library
        F = getYkgwData(sFile.filename, SamplesBounds(1), readLength);

    case 3  % AcqTypeEvokedRaw
        % Read the requested epoch
        F = getYkgwData(sFile.filename, iEpoch, 1);
        % Keep only the required samples
        iTimes = (SamplesBounds(1):SamplesBounds(2)) + 1;
        if (length(iTimes) ~= size(F,2))
            F = F(:,iTimes);
        end
end

% Return selected channels only
if ~isempty(iChannels)
    F = F(iChannels, :);
end




