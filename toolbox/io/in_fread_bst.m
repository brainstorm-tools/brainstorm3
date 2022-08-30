function F = in_fread_bst(sFile, sfid, SamplesBounds, ChannelsRange)
% IN_FREAD_BST:  Read a block of recordings from a CTF file
%
% USAGE:  F = in_fread_bst(sFile, sfid, SamplesBounds=[], ChannelsRange=[])

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
if (nargin < 4) || isempty(ChannelsRange)
    ChannelsRange = [1, nChannels];
else
    ChannelsRange = double(ChannelsRange);
end
if (nargin < 3) || isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
end
SamplesBounds = SamplesBounds - round(sFile.prop.times(1) .* sFile.prop.sfreq);
iTimes = SamplesBounds(1):SamplesBounds(2);
% Number of channels to read
nReadChan = ChannelsRange(2) - ChannelsRange(1) + 1;


%% ===== READ ALL NEEDED EPOCHS =====
% Detect which epochs are necessary for the range of data selected
epochRange = floor(SamplesBounds ./ nTimes);
epochsToRead = epochRange(1) : epochRange(2);
% Initialize block of data to read
F = zeros(nReadChan, length(iTimes));
% Marker that we increment when we add data to F
iF = 1;
% Read all the needed epochs
for i = 1:length(epochsToRead)
    % Find the samples to read from this epoch
    BoundsEpoch = nTimes * epochsToRead(i) + [0, nTimes-1];
    BoundsRead  = [max(BoundsEpoch(1), iTimes(1)), ...
                   min(BoundsEpoch(2), iTimes(end))];
    iTimeRead = BoundsRead(1):BoundsRead(2);
    % Convert this samples into indices in this very epoch 
    iTimeRead = iTimeRead - nTimes * epochsToRead(i);
    % New indices to read
    iNewF = iF:(iF + length(iTimeRead) - 1);
    % Read epoch (full or partial)
    F(:,iNewF) = bst_read_epoch(sFile, sfid, epochsToRead(i), iTimeRead, ChannelsRange);
    % Increment marker
    iF = iF + length(iTimeRead);
end



end



%% ===== READ ONE EPOCH =====
function F = bst_read_epoch(sFile, sfid, iEpoch, iTimes, ChannelsRange)
    % ===== COMPUTE OFFSETS =====
    nTimes    = double(sFile.header.epochsize);
    nChannels = double(sFile.header.nchannels);
    nReadTimes    = length(iTimes);
    nReadChannels = double(ChannelsRange(2) - ChannelsRange(1) + 1);
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
    
    % ===== READ DATA BLOCK =====
    % Position file at the beginning of the trial
    fseek(sfid, offsetStart, 'bof');
    % Read trial data
    % => WARNING: CALL TO FREAD WITH SKIP=0 DOES NOT WORK PROPERLY
    if (offsetSkip == 0)
        F = fread(sfid, [nReadTimes, nReadChannels], dataClass)';
    else
        precision = sprintf('%d*%s', nReadTimes, dataClass);
        F = fread(sfid, [nReadTimes, nReadChannels], precision, offsetSkip)';
    end
    % Check that data block was fully read
    if (numel(F) < nReadTimes * nReadChannels)
        % Number of full time samples that were read
        nTimeTrunc = max(0, floor(numel(F) / nReadChannels) - 1);
        % Error message
        disp(sprintf('BST> ERROR: File is truncated (%d time samples were read instead of %d). Padding with zeros...', nTimeTrunc, nReadTimes));
        % Pad data with zeros 
        Ftmp = zeros(nReadTimes, nReadChannels);
        F = F';
        Ftmp(1:numel(F)) = F(:);
        F = Ftmp';
    end
end

