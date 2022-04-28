function out_fwrite_ctf(sFile, iEpoch, SamplesBounds, ChannelsRange, isContinuous, F)
% OUT_FWRITE_CTF: Write a block of data in a CTF file.
%
% USAGE:  out_fwrite_ctf(sFile, iEpoch, SamplesBounds, ChannelsRange, isContinuous, F);
%
% INPUTS:
%     - sFile         : Structure for importing files in Brainstorm. Created by in_fopen()
%     - iEpoch        : Indice of the epoch to write (only one value allowed)
%     - SamplesBounds : [smpStart smpStop], First and last sample to read in epoch #iEpoch
%                       Set to [] to specify all the time definition
%     - ChannelRange  : Beginning and end indices of the range of channels to write
%                       Set to [] to specify all the channels
%     - isContinuous  : 1 if the input is in "continuous mode" (converted by brainstorm), 0 if it is in the original CTF format with epochs
%     - F             : Block of data to write to the file [iChannels x SamplesBounds]

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
% Authors: Francois Tadel, 2011-2013


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
% Make sure that everything is stored in double
ChannelsRange = double(ChannelsRange);
iEpoch = double(iEpoch);
% Block of times/channels to extract
nReadChannels = double(ChannelsRange(2) - ChannelsRange(1) + 1);
nReadTimes    = length(iTimes);


%% ===== WRITE AS CONTINUOUS =====
if isContinuous
    % Detect which epochs are necessary for the range of data selected
    epochRange = ceil(SamplesBounds ./ nTimes);
    epochsToWrite = epochRange(1) : epochRange(2);
    iF = 1;
    % Read all the needed epochs
    for i = 1:length(epochsToWrite)
        % Find the samples to read from this epoch
        iSmpEpochStart = nTimes * (epochsToWrite(i) - 1);
        iEpochBounds = [max(iSmpEpochStart+1, iTimes(1)),  min(iSmpEpochStart+nTimes, iTimes(end))];
        % Convert this samples into indices in this very epoch 
        iEpochBounds = iEpochBounds - nTimes * (epochsToWrite(i) - 1) - 1;
        nEpochsSmp = iEpochBounds(2) - iEpochBounds(1) + 1;
        % Write epoch (full or partial)
        out_fwrite_ctf(sFile, epochsToWrite(i), iEpochBounds, ChannelsRange, 0, F(:, iF:iF+nEpochsSmp-1));
        % Increment marker
        iF = iF + nEpochsSmp;
    end
    % Writing is done
    return
end


%% ===== REMOVE CHANNELS GAIN =====
% Value are stored in integer values, restore those intial values
% Get gains
gain_chan = double(sFile.header.gain_chan(ChannelsRange(1):ChannelsRange(2)));
if (size(gain_chan, 1) == 1)
    gain_chan = gain_chan';
end
% Apply gains
F = round(bst_bsxfun(@times, F, gain_chan));


%% ===== OPEN FILE =====
% Get position of block to write in file
[meg4_file, offsetStart, offsetSkip] = ctf_seek( sFile, iEpoch, iTimes, ChannelsRange );
% Open file
sfid = fopen(meg4_file, 'r+', sFile.byteorder);


%% ===== WRITE DATA =====
% Position file at the beginning of the trial
res = fseek(sfid, offsetStart, 'bof');
% If it's not possible to seek there (file not big enough): go the end of the file, and appends zeros until we reach the point we want
if (res == -1)
    fseek(sfid, 0, 'eof');
    nBytes = offsetStart - ftell(sfid);
    if (nBytes > 0)
        ncount = fwrite(sfid, 0, 'char', nBytes - 1);
    end
end
% Write data
if (offsetSkip == 0)
    ncount = fwrite(sfid, F', 'int32');
else
    % Offset is skipped BEFORE the values are read: so need to write the first value, and then the rest
    ncount = fwrite(sfid, F(1,:), 'int32');
    if (size(F,1) > 1)
        precision = sprintf('%d*int32', nReadTimes);
        ncount = ncount + fwrite(sfid, F(2:end,:)', precision, offsetSkip);
    end
end
% Check number of values written
if (ncount ~= nReadChannels * nReadTimes)
    error(['Error writing data to file: ' meg4_file]);
end

% Close file
fclose(sfid);




