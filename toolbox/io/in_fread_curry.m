function F = in_fread_curry(sFile, sfid, iEpoch, SamplesBounds, ChannelsRange)
% IN_FREAD_CURRY:  a Curry 6-7 (.dat/.dap/.rs3) or Curry 8 (.cdt/.dpa)
%
% USAGE:  F = in_fread_curry(sFile, sfid, iEpoch, SamplesBounds=[], ChannelsRange=[])

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
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
% Authors: Initial code from EEGLAB plugin loadcurry 2.0: Matt Pontifex, pontifex@msu.edu
%          Adaptation for Brainstorm 3: Francois Tadel, 2018

% Parse inputs
if (nargin < 3)
    iEpoch = 1;
end
if (nargin < 4) || isempty(SamplesBounds)
    if ~isempty(sFile.epochs)
        SamplesBounds = sFile.epochs(iEpoch).samples;
    else
        SamplesBounds = sFile.prop.samples;
    end
end
if (nargin < 5) || isempty(ChannelsRange)
    ChannelsRange = [1, sFile.header.nChannels];
end

% Ascii files not supported
if (hdr.nASCII == 1)
    error('ASCII files not supported yet: post a message on the Brainstorm user forum to request this feature.');
end

% ===== COMPUTE OFFSETS =====
nChannels     = double(sFile.header.nChannels);
nTimes        = SamplesBounds(2) - SamplesBounds(1) + 1;
nReadChannels = double(ChannelsRange(2) - ChannelsRange(1) + 1);
% Everything is stored on 32 bit floats
bytesPerVal = 4;
dataClass = 'float32';

% Data stored channel by channel
if (sFile.header.nMultiplex == 0)
    % No header offset
    offsetHeader = 0;
    % Time offset
    offsetTime = round(SamplesBounds(1) * nChannels * bytesPerVal);
    % Offset of epoch
    offsetEpoch = (iEpoch - 1) * nTimes * nChannels * bytesPerVal;
    % Channel offset at the beginning and end of each channel block
    offsetChannelStart = round((ChannelsRange(1)-1) * bytesPerVal);
    offsetChannelEnd   = (nChannels - ChannelsRange(2)) * bytesPerVal;
    % Start reading at this point
    offsetStart = offsetHeader + offsetEpoch + offsetTime + offsetChannelStart;
    % Number of time samples to skip after each channel
    offsetSkip = offsetChannelStart + offsetChannelEnd;
% Multiplexed file
else
    error('Multiplexed data not supported yet: post a message on the Brainstorm forum to request this feature.');
end

% ===== READ DATA BLOCK =====
% Position file at the beginning of the trial
fseek(sfid, offsetStart, 'bof');
% Read trial data
% => WARNING: CALL TO FREAD WITH SKIP=0 DOES NOT WORK PROPERLY
if (offsetSkip == 0)
    F = fread(sfid, [nReadChannels, nTimes], dataClass);
else
    precision = sprintf('%d*%s', nReadChannels, dataClass);
    F = fread(sfid, [nReadChannels, nTimes], precision, offsetSkip);
end
% Check that data block was fully read
if (numel(F) < nTimes * nReadChannels)
    % Error message
    disp(sprintf('BST> ERROR: File is truncated (%d values were read instead of %d)...', numel(F), nTimes * nReadChannels));
    % Pad with zeros 
    Ftmp = zeros(nReadChannels, nTimes);
    Ftmp(1:numel(F)) = F(:);
    F = Ftmp;
end



