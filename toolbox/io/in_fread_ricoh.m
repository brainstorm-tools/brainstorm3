function F = in_fread_ricoh(sFile, iEpoch, SamplesBounds, iChannels)
% IN_FREAD_RICOH:  Read a block of recordings from a RICOH MEG file
%
% USAGE:  F = in_fread_ricoh(sFile, iEpoch=1, SamplesBounds=All, ChannelsRange=[])
%
% This function is based on the Ricoh MEG reader toolbox version 1.0.
% For copyright and license information and software documentation, 
% please refer to the contents of the folder brainstorm3/external/ricoh

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2018

% Parse inputs
if (nargin < 4) || isempty(iChannels)
    iChannels = [];
end
if (nargin < 3) || isempty(SamplesBounds)
    SamplesBounds = sFile.prop.samples;
end
if (nargin < 2) || isempty(iEpoch)
    iEpoch = 1;
end
% Sample bounds: convert from relative values (map with time) to absolute number
SamplesBounds = SamplesBounds - sFile.prop.samples(1);

% Switch depending on the file type
switch (sFile.header.acq.acq_type)
    case {1,2}   % AcqTypeContinuousRaw / AcqTypeEvokedAve
        % Get the length of the segment to read (in samples)
        readLength = SamplesBounds(2) - SamplesBounds(1) + 1;
        % Read from file using Yokogawa library
        F = getRData(sFile.filename, SamplesBounds(1), readLength);

    case 3  % AcqTypeEvokedRaw
        % Read the requested epoch
        F = getRData(sFile.filename, iEpoch, 1);
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




