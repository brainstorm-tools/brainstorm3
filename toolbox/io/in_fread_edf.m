function F = in_fread_edf(sFile, sfid, SamplesBounds, ChannelsRange)
% IN_FREAD_EDF:  Read a block of recordings from a EDF/BDF file
%
% USAGE:  F = in_fread_edf(sFile, sfid, SamplesBounds, ChannelsRange)
%         F = in_fread_edf(sFile, sfid, SamplesBounds)               : Read all channels
%         F = in_fread_edf(sFile, sfid)                              : Read all channels, all the times

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
% Authors: Francois Tadel, 2012-2023

%% ===== PARSE INPUTS =====
nChannels      = sFile.header.nsignal;
iChanAnnot     = find(strcmpi({sFile.header.signal.label}, 'EDF Annotations'));
iBadChan       = find(sFile.channelflag == -1);
iChanSignal    = setdiff(1:nChannels, iChanAnnot);
iChanWrongRate = find([sFile.header.signal(iChanSignal).sfreq] ~= max([sFile.header.signal(setdiff(iChanSignal,iBadChan)).sfreq]));   
iChanSkip      = union(iChanAnnot, iChanWrongRate);
% By default: Read all the channels
if (nargin < 4) || isempty(ChannelsRange)
    ChannelsRange = [1, nChannels];
end
% By default: Read all the file, at the main file frequency
if (nargin < 3) || isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
end

% Block of times/channels to extract
nReadChannels = double(ChannelsRange(2) - ChannelsRange(1) + 1);
% Read annotations instead of real data ?
isAnnotOnly = ~isempty(iChanAnnot) && (ChannelsRange(1) == ChannelsRange(2)) && ismember(ChannelsRange(1), iChanAnnot);
isBdfStatus = strcmpi(sFile.format, 'EEG-BDF') && (ChannelsRange(1) == ChannelsRange(2)) && strcmpi(sFile.header.signal(ChannelsRange(1)).label, 'Status');
% Data channels to read
if isAnnotOnly
    % Read only on annotation channel
    iChanF = 1;
else
    % Remove all the annotation channels from the list of channels to read
    iChanF = setdiff(ChannelsRange(1):ChannelsRange(2), iChanSkip) - ChannelsRange(1) + 1;
%     if any(diff(iChanF) ~= 1)
%         error('All the data channels to read from the file must be contiguous (EDF Annotation channels must be at the end of the list).');
%     end
    if any(diff(iChanF) ~= 1)
        iChanLast = find(diff(iChanF) ~= 1, 1);
        iChanF = iChanF(1:iChanLast);
    else
        iChanLast = length(iChanF);
    end
    ChannelsRange = [iChanF(1), iChanF(iChanLast)] + ChannelsRange(1) - 1;
end
% Cannot read channels with different sampling rates at the same time
if (ChannelsRange(1) ~= ChannelsRange(2))
    allFreq = [sFile.header.signal(ChannelsRange(1):ChannelsRange(2)).nsamples];
    if any(allFreq ~= allFreq(1))
        error(['Cannot read channels with mixed sampling rates at the same time.' 10 ...
               'Mark as bad channels with different sampling rates than EEG.' 10 ...
               '(right-click on data file > Good/bad channels > Edit good/bad channels)']);
    end
end
% Number of time samples to read
nTimes = round(sFile.header.reclen * sFile.header.signal(ChannelsRange(1)).sfreq);
iTimes = SamplesBounds(1):SamplesBounds(2);


%% ===== READ ALL NEEDED EPOCHS =====
% Detect which epochs are necessary for the range of data selected
epochRange = floor(SamplesBounds ./ nTimes);
epochsToRead = epochRange(1) : epochRange(2);
% Initialize block of data to read
if isAnnotOnly
    F = zeros(nReadChannels, 2 * length(iTimes));
else
    F = zeros(nReadChannels, length(iTimes));
end
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
    if isAnnotOnly
        iNewF = iF:(iF + 2*length(iTimeRead) - 1);
    else
        iNewF = iF:(iF + length(iTimeRead) - 1);
    end
    % Read epoch (full or partial)
    F(iChanF,iNewF) = edf_read_epoch(sFile, sfid, epochsToRead(i), iTimeRead, ChannelsRange, isAnnotOnly, isBdfStatus);
    % Increment marker
    iF = iF + length(iTimeRead);
end



end



%% ===== READ ONE EPOCH =====
function F = edf_read_epoch(sFile, sfid, iEpoch, iTimes, ChannelsRange, isAnnotOnly, isBdfStatus)
    % ===== COMPUTE OFFSETS =====
    nTimes        = sFile.header.reclen * [sFile.header.signal.sfreq];
    nReadTimes    = length(iTimes);
    nReadChannels = double(ChannelsRange(2) - ChannelsRange(1) + 1);
    iChannels     = ChannelsRange(1):ChannelsRange(2);
    % Check that all the channels selected have the same freq rate
    if any(nTimes(iChannels) ~= nTimes(iChannels(1)))
        error('Cannot read at the same signals with different sampling frequency.');
    end
    % Size of one value 
    if strcmpi(sFile.format, 'EEG-BDF')
        % BDF: int24 => 3 bytes
        bytesPerVal = 3;
        % Reading status or regular channel
        if isBdfStatus
            dataClass = 'ubit24';
        else
            dataClass = 'bit24';
        end
    else
        % EDF: int16 => 2 bytes
        bytesPerVal = 2;
        dataClass = 'int16';
        isBdfStatus = 0;
    end
    % Offset of the beginning of the recordings in the file
    offsetHeader    = round(sFile.header.hdrlen);
    % Offset of epoch
    offsetEpoch     = round(iEpoch * sum(nTimes) * bytesPerVal);
    % Channel offset
    offsetChannel   = round(sum(nTimes(1:ChannelsRange(1)-1)) * bytesPerVal);
    % Time offset at the beginning and end of each channel block
    offsetTimeStart = round(iTimes(1) * bytesPerVal);
    offsetTimeEnd   = round((nTimes(ChannelsRange(1)) - iTimes(end) - 1) * bytesPerVal);
    % ALL THE "ROUND" CALLS WERE ADDED AFTER DISCOVERING THAT THERE WERE SOMETIMES ROUNDING ERRORS IN THE MULTIPLICATIONS
    
    % Where to start reading in the file ?
    % => After the header, the number of skipped epochs, channels and time samples
    offsetStart = offsetHeader + offsetEpoch + offsetChannel + offsetTimeStart;
    % Number of time samples to skip after each channel
    offsetSkip = offsetTimeStart + offsetTimeEnd; 

    
    % ===== READ DATA BLOCK =====
    % Position file at the beginning of the trial
    fseek(sfid, offsetStart, 'bof');
    % Read annotation data (char)
    if isAnnotOnly
        dataClass = 'uint8';
        nReadTimes = bytesPerVal * nReadTimes;  % 1 byte instead of 2
    end
    % Read trial data
    % => WARNING: CALL TO FREAD WITH SKIP=0 DOES NOT WORK PROPERLY
    if (offsetSkip == 0)
        F = fread(sfid, [nReadTimes, nReadChannels], dataClass)';
    elseif (bytesPerVal == 2)
        precision = sprintf('%d*%s', nReadTimes, dataClass);
        F = fread(sfid, [nReadTimes, nReadChannels], precision, offsetSkip)';
    % => WARNING: READING USING ubit24 SOMETIMES DOESNT WORK => DOING IT MANUALLY
    elseif (bytesPerVal == 3)
        % Reading each bit independently
        precision = sprintf('%d*%s', 3*nReadTimes, 'uint8');
        F = fread(sfid, [3*nReadTimes, nReadChannels], precision, offsetSkip)';
        % Grouping the 3 bits together
        F = F(:,1:3:end) + F(:,2:3:end)*256 + F(:,3:3:end)*256*256;
        % 2-Complement (negative value indicated by most significant bit)
        if strcmpi(dataClass, 'bit24')
            iNeg = (F >= 256*256*128);
            F(iNeg) = F(iNeg) - 256*256*256;
        end
    end
    % Check that data block was fully read
    if (numel(F) < nReadTimes * nReadChannels)
        % Number of full time samples that were read
        nTimeTrunc = max(0, floor(numel(F) / nReadChannels) - 1);
        % Error message
        disp(sprintf('EDF> ERROR: File is truncated (%d time samples were read instead of %d). Padding with zeros...', nTimeTrunc, nReadTimes));
        % Pad data with zeros 
        Ftmp = zeros(nReadTimes, nReadChannels);
        F = F';
        Ftmp(1:numel(F)) = F(:);
        F = Ftmp';
    end

    % Processing for BDF status file
    if isBdfStatus
        % Mask to keep only the first 16 bits (Triggers bits)
        % Bit 16    : High when new Epoch is started
        % Bit 17-19 : Speed bits 0 1 2
        % Bit 20 	: High when CMS is within range
        % Bit 21 	: Speed bit 3
        % Bit 22 	: High when battery is low
        % Bit 23    : High if ActiveTwo MK2
        F = bitand(F, hex2dec('00FFFF'));
    % Processing for real data
    elseif ~isAnnotOnly
        % Convert to double
        F = double(F);
        % Apply gains
        F = bst_bsxfun(@rdivide, F, [sFile.header.signal(iChannels).gain]');
% IN THEORY: THIS OFFSET SECTION IS USEFUL, BUT IN PRACTICE IT LOOKS LIKE THE VALUES IN ALL THE FILES ARE CENTERED ON ZERO
%         % Add offset 
%         if isfield(sFile.header.signal, 'offset') && ~isempty(sFile.header.signal(1).offset)
%             % ...
%         end
    end
end

