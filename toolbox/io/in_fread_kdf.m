function F = in_fread_kdf(sFile, sfid, SamplesBounds, ChannelsRange)
% IN_FREAD_KDF:  Read a block of recordings from a KRISS MEG .kdf file
%
% USAGE:  F = in_fread_kdf(sFile, sfid, SamplesBounds, ChannelsRange)
%         F = in_fread_kdf(sFile, sfid, SamplesBounds)               : Read all channels
%         F = in_fread_kdf(sFile, sfid)                              : Read all channels, all the times

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
% Authors: Francois Tadel, 2014


%% ===== PARSE INPUTS =====
nChannels  = sFile.header.nsignal;
if (nargin < 4) || isempty(ChannelsRange)
    ChannelsRange = [1, nChannels];
end
if (nargin < 3) || isempty(SamplesBounds)
    SamplesBounds = [0, sFile.header.nrec * sFile.header.nsamples - 1];
end
nTimes = sFile.header.reclen * sFile.header.sfreq;
iTimes = SamplesBounds(1):SamplesBounds(2);
% Block of times/channels to extract
nReadChannels = double(ChannelsRange(2) - ChannelsRange(1) + 1);
% Read status line instead of real data ?
isStatus = (ChannelsRange(1) == ChannelsRange(2)) && strcmpi(sFile.header.signal(ChannelsRange(1)).label, 'Status');
% Data channels to read
iChanF = (ChannelsRange(1):ChannelsRange(2)) - ChannelsRange(1) + 1;
ChannelsRange = [iChanF(1), iChanF(end)] + ChannelsRange(1) - 1;


%% ===== READ ALL NEEDED EPOCHS =====
% Detect which epochs are necessary for the range of data selected
epochRange = floor(SamplesBounds ./ nTimes);
epochsToRead = epochRange(1) : epochRange(2);
% Initialize block of data to read
F = zeros(nReadChannels, length(iTimes));
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
    F(iChanF,iNewF) = kdf_read_epoch(sFile, sfid, epochsToRead(i), iTimeRead, ChannelsRange, isStatus);
    % Increment marker
    iF = iF + length(iTimeRead);
end



end



%% ===== READ ONE EPOCH =====
function F = kdf_read_epoch(sFile, sfid, iEpoch, iTimes, ChannelsRange, isStatus)
    % ===== COMPUTE OFFSETS =====
    nTimes        = sFile.header.reclen * sFile.header.sfreq;
    nChannels     = sFile.header.nsignal;
    nReadTimes    = length(iTimes);
    nReadChannels = double(ChannelsRange(2) - ChannelsRange(1) + 1);
    iChannels     = ChannelsRange(1):ChannelsRange(2);
    % KDF: int24 => 3 bytes
    bytesPerVal = 3;
    % Reading status or regular channel
    if isStatus
        dataClass = 'ubit24';
    else
        dataClass = 'bit24';
    end
    % Offset of the beginning of the recordings in the file
    offsetHeader    = round(sFile.header.hdrlen);
    % Offset of epoch
    offsetEpoch     = round(iEpoch * nChannels * nTimes * bytesPerVal);
    % Channel offset
    offsetChannel   = round((ChannelsRange(1) - 1) * nTimes * bytesPerVal);
    % Time offset at the beginning and end of each channel block
    offsetTimeStart = round(iTimes(1) * bytesPerVal);
    offsetTimeEnd   = round((nTimes - iTimes(end) - 1) * bytesPerVal);
    % ALL THE "ROUND" CALLS WERE ADDED AFTER DISCOVERING THAT THERE WERE SOMETIMES ROUNDING ERRORS IN THE MULTIPLICATIONS
    
    % Where to start reading in the file ?
    % => After the header, the number of skipped epochs, channels and time samples
    offsetStart = offsetHeader + offsetEpoch + offsetChannel + offsetTimeStart;
    % Number of time samples to skip after each channel
    offsetSkip = offsetTimeStart + offsetTimeEnd; 

    
    % ===== READ DATA BLOCK =====
    % Position file at the beginning of the trial
    fseek(sfid, offsetStart, 'bof');
    % Read trial data (code from KRISS)
    % Reading each bit independently
    precision = sprintf('%d*%s', 3*nReadTimes, 'uint8=>double');
    F = fread(sfid, [3*nReadTimes, nReadChannels], precision, offsetSkip);
    % Convert series of 3 bytes (24bit int) into double values
    F = [1, 2^8, 2^16] * reshape(F, 3, []);
    % Reformat to [nChannels x nTime]
    F = reshape(F, nReadTimes, nReadChannels)';

    % Check that data block was fully read
    if (numel(F) < nReadTimes * nReadChannels)
        % Number of full time samples that were read
        nTimeTrunc = max(0, floor(numel(F) / nReadChannels) - 1);
        % Error message
        disp(sprintf('KDF> ERROR: File is truncated (%d time samples were read instead of %d). Padding with zeros...', nTimeTrunc, nReadTimes));
        % Pad data with zeros 
        Ftmp = zeros(nReadTimes, nReadChannels);
        F = F';
        Ftmp(1:numel(F)) = F(:);
        F = Ftmp';
    end
    
    % Processing for status line
    if isStatus
        % 2-Complement (negative value indicated by most significant bit)
        if strcmpi(dataClass, 'bit24')
            iNeg = (F >= 256*256*128);
            F(iNeg) = F(iNeg) - 256*256*256;
        end
        % Mask to keep only the first 15 bits (Triggers bits)
        % Bit 16    : High when new Epoch is started
        % Bit 17-19 : Speed bits 0 1 2
        % Bit 20 	: High when CMS is within range
        % Bit 21 	: Speed bit 3
        % Bit 22 	: High when battery is low
        % Bit 23    : High if ActiveTwo MK2
        F = bitand(F, bin2dec('000000000111111111111111'));
    % Process regular channels
    else
        % Get channel config
        PhysMin = [sFile.header.signal(iChannels).physical_min]';
        PhysMax = [sFile.header.signal(iChannels).physical_max]';
        DigMin  = [sFile.header.signal(iChannels).digital_min]';
        DigMax  = [sFile.header.signal(iChannels).digital_max]';
        % Apply channel gains
        R = rem(F, 2^23);        % remainder after being divided by 2^23
        Q = floor(F / 2^23);     % quotient after being divided by 2^23, 0 for positive case, 1 for negative case
        F = R - Q * 2^23;        % to convert unsigned raw data into signed integer data
        scale = bst_bsxfun(@times, 1-Q, 10/DigMax*PhysMax) + bst_bsxfun(@times, Q, 10/DigMin*PhysMin);   % scale factor to convert digital->V->pT
        F = -F .* scale;
        % Apply units
        F = bst_bsxfun(@rdivide, F, [sFile.header.signal(iChannels).gain]');
    end
end

