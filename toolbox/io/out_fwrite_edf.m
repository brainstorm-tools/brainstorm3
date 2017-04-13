function out_fwrite_edf(sFile, sfid, SamplesBounds, ChannelsRange, F)
% OUT_FWRITE_EDF: Write a block of recordings from a EDF file.

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Martin Cousineau, 2017

% ===== PARSE INPUTS =====
[nSignals, nSamples] = size(F);
if isempty(SamplesBounds)
    SamplesBounds = [0, nSamples];
end
if isempty(ChannelsRange)
    ChannelsRange = [1, nSignals];
end

fseek(sfid, 0, 'eof');

% Convert V to uV to avoid precision loss
F = F * 1e6;

% Convert to 2-byte integer in 2's complement
F = int16(F);
negF = F < 0;
F(negF) = bitcmp(abs(F(negF))) + 1;

% Prepare annotations if any.
if sFile.header.annotchan >= 0
    annotations    = 1;
    nEvents        = length(sFile.events);
    nSamplesAnnots = sFile.header.signal(sFile.header.annotchan).nsamples;

    global nextEdfEvent;
    if nextEdfEvent.event < 0
        nextEdfEvent.event = 1;
        nextEdfEvent.epoch = 1;
        nextEdfEvent.annot = [];
    end
else
    annotations = 0;
end

% Write to file record per record
nSamplesPerRecord = sFile.prop.sfreq * sFile.header.reclen;
nRecords          = ceil((SamplesBounds(2) - SamplesBounds(1)) / nSamplesPerRecord);
ncount            = 0;
bounds            = [1, nSamplesPerRecord];
timeOffset        = SamplesBounds(1) / nSamplesPerRecord;

for iRec = 1:nRecords
    % Special case when we don't have enough data to fill the last record
    if bounds(2) > nSamples
        if iRec ~= nRecords
            error('Ran out of data before last record.');
        end
        writeZeros = bounds(2) - nSamples;
        bounds(2)  = nSamples;
    else
        writeZeros = 0;
    end

    % Write data
    for iSig = ChannelsRange(1):ChannelsRange(2)
        ncount = ncount + fwrite(sfid, F(iSig, bounds(1):bounds(2)), 'int16');
        
        % Fill rest of the record with 0s if required
        if writeZeros
            fwrite(sfid, zeros(writeZeros, 1), 'int16');
        end
    end
    
    % Write annotations if any, split by records
    if annotations
        bytesLeft = nSamplesAnnots * 2;
        
        % The first annotation specifies the time offset
        bytesLeft = bytesLeft - fprintf(sfid, '+%f%c%c%c', timeOffset, char(20), char(20), char(0));
        
        % Write as many annotations as possible in current record
        while bytesLeft >= length(nextEdfEvent.annot)
            if ~isempty(nextEdfEvent.annot)
                bytesLeft = bytesLeft - fprintf(sfid, '%s', nextEdfEvent.annot);
            end
            
            if nextEdfEvent.event > nEvents
                nextEdfEvent.annot = [];
                break;
            end
            
            % Prepare the next annotation string
            event = sFile.events(nextEdfEvent.event);
            startTime = event.times(nextEdfEvent.epoch);
            nextEdfEvent.annot = sprintf('+%f', startTime);

            % Add duration if specified.
            if numel(event.epochs) ~= numel(event.times)
                nextEdfEvent.epoch = nextEdfEvent.epoch + 1;
                duration = event.times(nextEdfEvent.epoch) - startTime;
                nextEdfEvent.annot = [nextEdfEvent.annot, ...
                    sprintf('%c%f', char(21), duration)];
            end

            nextEdfEvent.epoch = nextEdfEvent.epoch + 1;
            nextEdfEvent.annot = [nextEdfEvent.annot, ...
                sprintf('%c%s%c%c', char(20), event.label, char(20), char(0))];

            % If this is the last epoch of the event, go to next event
            if nextEdfEvent.epoch > numel(event.times)
                nextEdfEvent.event = nextEdfEvent.event + 1;
                nextEdfEvent.epoch = 1;
            end
        end
        
        % Fill remaining of record with 0-bytes.
        fprintf(sfid, '%s', repmat(char(0), 1, bytesLeft));
    end
    
    % Get ready for next record
    bounds     = bounds + nSamplesPerRecord;
    timeOffset = timeOffset + sFile.header.reclen;
end

% Check number of values written
if (ncount ~= numel(F))
    error('Error writing data to file.');
end
