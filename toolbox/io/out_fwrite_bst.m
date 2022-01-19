function out_fwrite_bst(sFile, sfid, SamplesBounds, ChannelsRange, F)
% OUT_FWRITE_BST: Write a block of data in a Brainstorm binary file.
%
% USAGE:  out_fwrite_bst(sFile, sfid, ChannelMat, SamplesBounds, ChannelsRange, F);
%
% INPUTS:
%     - sFile         : Structure for importing files in Brainstorm. Created by in_fopen()
%     - sfid          : Pointer to the opened file
%     - ChannelMat    : Channel file structure
%     - SamplesBounds : [smpStart smpStop], First and last sample to read in epoch #iEpoch
%                       Set to [] to specify all the time definition
%     - ChannelRange  : Beginning and end indices of the range of channels to write
%                       Set to [] to specify all the channels
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
% Authors: Francois Tadel, 2014-2019


%% ===== PARSE INPUTS =====
nTimes    = double(sFile.header.epochsize);
nChannels = double(sFile.header.nchannels);
if isempty(ChannelsRange)
    ChannelsRange = [1, nChannels];
else
    ChannelsRange = double(ChannelsRange);
end
if isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
end
SamplesBounds = SamplesBounds - round(sFile.prop.times(1) .* sFile.prop.sfreq);
iTimes = SamplesBounds(1):SamplesBounds(2);

%% ===== LOOP ON EPOCHS =====
% Detect which epochs are necessary for the range of data selected
epochRange = floor(SamplesBounds ./ nTimes);
epochsToWrite = epochRange(1) : epochRange(2);
iF = 1;
% Write all the needed epochs
for i = 1:length(epochsToWrite)
    % Find the samples to read from this epoch
    BoundsEpoch = nTimes * epochsToWrite(i) + [0, nTimes-1];
    BoundsRead  = [max(BoundsEpoch(1), iTimes(1)), ...
                   min(BoundsEpoch(2), iTimes(end))];
    iTimeWrite = BoundsRead(1):BoundsRead(2);
    % Convert this samples into indices in this very epoch 
    iTimeWrite = iTimeWrite - nTimes * epochsToWrite(i);
    % Indices to write
    iNewF = iF:(iF + length(iTimeWrite) - 1);
    % Read epoch (full or partial)
    bst_write_epoch(sFile, sfid, epochsToWrite(i), iTimeWrite, ChannelsRange, F(:, iNewF));
    % Increment marker
    iF = iF + length(iTimeWrite);
end

end



%% ===== WRITE ONE EPOCH =====
function bst_write_epoch(sFile, sfid, iEpoch, iTimes, ChannelsRange, F)
    % ===== COMPUTE OFFSETS =====
    nTimes    = double(sFile.header.epochsize);
    nChannels = double(sFile.header.nchannels);
    % Everything is stored on 32 bit floats
    bytesPerVal = 4;
    dataClass = 'float32';
    % Offset of the beginning of the recordings in the file
    offsetHeader    = round(sFile.header.hdrsize);
    % Offset of epoch
    offsetEpoch     = round(iEpoch * nTimes * nChannels * bytesPerVal);
    % Channel offset
    offsetChannel   = round((ChannelsRange(1)-1) * nTimes * bytesPerVal);
    % Time offset at the beginning and end of each channel block
    offsetTimeStart = round(iTimes(1) * bytesPerVal);
    offsetTimeEnd   = (nTimes - iTimes(end) - 1) * bytesPerVal;

    % Start writing after the header, the number of skipped epochs, channels and time samples
    offsetStart = offsetHeader + offsetEpoch + offsetChannel + offsetTimeStart;
    % Number of time samples to skip after each channel
    offsetSkip = offsetTimeStart + offsetTimeEnd; 

    % ===== SEEK IN FILE =====
    % Position file at the beginning of the trial
    res = fseek(sfid, offsetStart, 'bof');
    % If it's not possible to seek there (file not big enough): go the end of the file, and appends zeros until we reach the point we want
    if (res == -1)
        fseek(sfid, 0, 'eof');
        nBytes = offsetStart - ftell(sfid);
        if (nBytes > 0)
            fwrite(sfid, 0, 'char', nBytes - 1);
        end
    end
    
    % ===== WRITE DATA BLOCK =====
    % Write epoch data
    if (offsetSkip == 0)
        ncount = fwrite(sfid, F', dataClass);
    else
        % Offset is skipped BEFORE the values are read: so need to write the first value, and then the rest
        ncount = fwrite(sfid, F(1,:), dataClass);
        if (size(F,1) > 1)
            precision = sprintf('%d*%s', length(iTimes), dataClass);
            ncount = ncount + fwrite(sfid, F(2:end,:)', precision, offsetSkip);
        end
    end
    % Check number of values written
    if (ncount ~= numel(F))
        error('Error writing data to file.');
    end
end




