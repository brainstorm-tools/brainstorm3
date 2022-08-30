function F = in_fread_ctf(sFile, iEpoch, SamplesBounds, ChannelsRange, isContinuous)
% IN_FREAD_CTF:  Read a block of recordings from a CTF file
%
% USAGE:  F = in_fread_ctf(sFile, iEpoch, SamplesBounds, ChannelsRange, isContinuous)
%         F = in_fread_ctf(sFile, iEpoch, SamplesBounds, ChannelsRange)   : Read as epoched data
%         F = in_fread_ctf(sFile, iEpoch, SamplesBounds) : Read all channels
%         F = in_fread_ctf(sFile, iEpoch)                : Read all channels, all the times
%         F = in_fread_ctf(sFile)                        : Read all channels, all the times, from epoch 1

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
% Authors: Sylvain Baillet (2004)
%          Francois Tadel (2008-2014)


%% ===== PARSE INPUTS =====
nTimes    = double(sFile.header.gSetUp.no_samples);
nChannels = double(sFile.header.gSetUp.no_channels);
if (nargin < 5) || isempty(isContinuous)
    isContinuous = 0;
end
if (nargin < 4) || isempty(ChannelsRange)
    ChannelsRange = [1, nChannels];
end
if (nargin < 3) || isempty(SamplesBounds)
    if isContinuous
        SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq) + 1;
        iTimes = SamplesBounds(1):SamplesBounds(2);
    else
        iTimes = 1:nTimes;
        SamplesBounds = [iTimes(1), iTimes(end)];
    end
else
    SamplesBounds = double(SamplesBounds - round(sFile.prop.times(1) .* sFile.prop.sfreq) + 1);
    iTimes = SamplesBounds(1):SamplesBounds(2);
end
if (nargin < 2) || isempty(iEpoch)
    iEpoch = 1;
end
ChannelsRange = double(ChannelsRange);
iEpoch = double(iEpoch);
% Block of times/channels to extract
nReadChannels = double(ChannelsRange(2) - ChannelsRange(1) + 1);
nReadTimes    = length(iTimes);


%% ===== READ AS CONTINUOUS =====
if isContinuous
    % Detect which epochs are necessary for the range of data selected
    epochRange = ceil(SamplesBounds ./ nTimes);
    epochsToRead = epochRange(1) : epochRange(2);
    % Initialize block of data to read
    F = zeros(nReadChannels, length(iTimes));
    % Marker that we increment when we add data to F
    iF = 1;
    % Read all the needed epochs
    for i = 1:length(epochsToRead)
        % Find the samples to read from this epoch
        iSmpEpochStart = nTimes * (epochsToRead(i) - 1);
        iEpochBounds = [max(iSmpEpochStart+1, iTimes(1)),  min(iSmpEpochStart+nTimes, iTimes(end))];
        % Convert this samples into indices in this very epoch 
        iEpochBounds = iEpochBounds - nTimes * (epochsToRead(i) - 1) - 1;
        nEpochsSmp = iEpochBounds(2) - iEpochBounds(1) + 1;
        % Read epoch (full or partial)
        F(:, iF:iF+nEpochsSmp-1) = in_fread_ctf(sFile, epochsToRead(i), iEpochBounds, ChannelsRange, 0);
        % Increment marker
        iF = iF + nEpochsSmp;
    end
    % Return those values
    return
end


%% ===== OPEN FILE =====
% Get position of block to read in file
[meg4_file, offsetStart, offsetSkip] = ctf_seek( sFile, iEpoch, iTimes, ChannelsRange );
% Open file
sfid = fopen(meg4_file, 'r', sFile.byteorder);


%% ===== READ DATA BLOCK =====
% Position file at the beginning of the trial
fseek(sfid, offsetStart, 'bof');
% Read trial data
% => WARNING: CALL TO FREAD WITH SKIP=0 DOES NOT WORK PROPERLY
if (offsetSkip == 0)
    F = fread(sfid, [nReadTimes, nReadChannels], 'int32')';
else
    precision = sprintf('%d*int32=>int32', nReadTimes);
    F = fread(sfid, [nReadTimes, nReadChannels], precision, offsetSkip)';
end
% Check that data block was fully read
if (numel(F) < nReadTimes * nReadChannels)
    error(sprintf('CTF> ERROR: %d time samples were read instead of %d.', floor(numel(F) / nReadChannels), nReadTimes));
end

% Close file
fclose(sfid);


%% ===== APPLY CHANNELS GAIN =====
% Force values in double
F = double(F);
% Replace zeros with small values in gain matrix
iChannels = ChannelsRange(1):ChannelsRange(2);
gain_chan = double(sFile.header.gain_chan(iChannels));
gain_chan(gain_chan == 0) = eps;
if (size(gain_chan, 1) == 1)
    gain_chan = gain_chan';
end
% Set the gain of the Video channel to 1 (not possible with older imports)
if isfield(sFile.header, 'SensorRes')
    iVideo = find([sFile.header.SensorRes(iChannels).sensorTypeIndex] == 12);
    if ~isempty(iVideo)
        gain_chan(iVideo) = 1;
    end
end
% Apply gains
F = bst_bsxfun(@rdivide, F, gain_chan);




