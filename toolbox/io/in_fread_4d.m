function F = in_fread_4d(sFile, sfid, iEpoch, SamplesBounds, iChannels)
% IN_FREAD_4D:  Read a block of recordings from a 4D/BTi file
%
% USAGE:  F = in_fread_4d(sFile, sfid, iEpoch, SamplesBounds, iChannels) 
%         F = in_fread_4d(sFile, sfid, iEpoch, SamplesBounds) : Read all channels
%         F = in_fread_4d(sFile, sfid, iEpoch)                : Read all channels, all the times
%         F = in_fread_4d(sFile, sfid)                        : Read all channels, all the times, from epoch 1

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2009-2014
% Based on code from FieldTrip toolbox (Robert Oostenveld)

%% ===== PARSE INPUTS =====
fileSamples = round(sFile.prop.times .* sFile.prop.sfreq);
nTimes = fileSamples(2) - fileSamples(1) + 1;
nChannels = length(sFile.header.channel_data);
if (nargin < 5) || isempty(iChannels)
    iChannels = 1:nChannels;
end
if (nargin < 4) || isempty(SamplesBounds)
    iTimes = 1:nTimes;
else
    SamplesBounds = double(SamplesBounds - fileSamples(1) + 1);
    iTimes = SamplesBounds(1):SamplesBounds(2);
end
if (nargin < 3) || isempty(iEpoch)
    iEpoch = 1;
end
iChannels = double(iChannels);
iEpoch    = double(iEpoch);


%% ===== READ DATA BLOCK =====
% Get the format in which the values are stored
sampletype = lower(sFile.header.header_data.data_format_str);
switch sampletype
    case 'short',  bytesPerVal = 2;
    case 'long',   bytesPerVal = 4;
    case 'float',  bytesPerVal = 4;
    case 'double', bytesPerVal = 8;
    otherwise,     error('Unsupported data format');
end
% 4D/BTi MEG data is multiplexed, can be epoched/discontinuous
epochOffset = sum([sFile.header.epoch_data(1:iEpoch-1).pts_in_epoch]) * nChannels * bytesPerVal;
timeOffset  = (iTimes(1) - 1) * bytesPerVal * nChannels;
offset      = epochOffset + timeOffset;
numsamples  = length(iTimes);
gain        = sFile.header.ChannelGain;
if isfield(sFile.header, 'ChannelUnitsPerBit')
    upb = sFile.header.ChannelUnitsPerBit;
else
    warning('cannot determine ChannelUnitsPerBit');
    upb = ones(1, nChannels);
end
% jump to the desired data
fseek(sfid, offset, 'bof');

% Read the desired data
if length(iChannels)==1
    % read only one channel
    fseek(sfid, (iChannels-1)*bytesPerVal, 'cof');                                  % seek to begin of channel
    F = fread(sfid, numsamples, ['1*' sampletype], (nChannels-1)*bytesPerVal)'; % read one channel, skip the rest
else
    % read all channels
    F = fread(sfid, [nChannels, numsamples], sampletype);
end
if length(iChannels)==1
    % only one channel was selected, which is managed by the code above
    % nothing to do
elseif length(iChannels)==nChannels
    % all channels have been selected
    % nothing to do
else
    % select the desired channel(s)
    F = F(iChannels,:);
end

% determine how to calibrate the data
switch sampletype
    case {'short', 'long'}
        % include both the gain values and the integer-to-double conversion in the calibration
        calib = diag(gain(iChannels) .* upb(iChannels));
    case {'float', 'double'}
        % only include the gain values in the calibration
        calib = diag(gain(iChannels));
    otherwise
        error('unsupported data format');
end
% calibrate the data
F = calib * F;






