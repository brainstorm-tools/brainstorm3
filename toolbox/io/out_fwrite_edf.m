function out_fwrite_edf(sFile, sfid, SamplesBounds, ChannelsRange, F)
% OUT_FWRITE_EDF: Write a block of recordings from a EDF file.

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
% Authors: Martin Cousineau, 2017
%          Francois Tadel, 2019

% ===== PARSE INPUTS =====
[nSignals, nSamples] = size(F);
if isempty(SamplesBounds)
    SamplesBounds = [0, nSamples];
end
if isempty(ChannelsRange)
    ChannelsRange = [1, nSignals];
end

fseek(sfid, 0, 'eof');

% Get the gains of the channels for all the non-Annotation channels
iChanGain = setdiff(1:length(sFile.header.signal), sFile.header.annotchan);
% Apply channel gains before converting to integer
chgain = [sFile.header.signal(iChanGain).unit_gain] ./ ...
            ([sFile.header.signal(iChanGain).physical_max] - [sFile.header.signal(iChanGain).physical_min]) .* ...
            ([sFile.header.signal(iChanGain).digital_max]  - [sFile.header.signal(iChanGain).digital_min]);
F = bst_bsxfun(@times, F, chgain');

% Convert to 2-byte integer in 2's complement
F = int16(F);
negF = F < 0;
F(negF) = bitcmp(abs(F(negF))) + 1;

% Prepare annotations if any.
if sFile.header.annotchan >= 0
    annotations    = 1;
    nAnnots        = numel(sFile.header.annotations);
    nSamplesReal   = round((sFile.prop.times(2) - sFile.prop.times(1)) .* sFile.prop.sfreq);
    nSamplesAnnots = sFile.header.signal(sFile.header.annotchan).nsamples;
    annotThreshold = floor((1:nAnnots) / nAnnots * nSamplesReal);
    annotBounds    = [0, 0];
    
    % Insert annotation in this record only if it contains the required
    % cutoff sample threshold
    for iThr = 1:nAnnots
        if annotThreshold(iThr) >= SamplesBounds(1) && annotThreshold(iThr) <= SamplesBounds(2)
            if annotBounds(1) < 1
                annotBounds(1) = iThr;
            end
            annotBounds(2) = iThr;
        end
    end
    
    if annotBounds(2) < 1
        annotsList = [];
    else
        annotsList = sFile.header.annotations(annotBounds(1) : annotBounds(2));
    end
    
    nAnnots     = numel(annotsList);
    nextAnnot   = 1;
else
    annotations = 0;
end

% Write to file record per record
nSamplesPerRecord = sFile.prop.sfreq * sFile.header.reclen;
nRecords          = ceil((SamplesBounds(2) - SamplesBounds(1)) / nSamplesPerRecord);
ncount            = 0;
bounds            = [1, nSamplesPerRecord];
timeOffset        = SamplesBounds(1) / sFile.prop.sfreq;

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
        ncount = ncount + fwrite(sfid, F(iSig, floor(bounds(1)):floor(bounds(2))), 'int16');
        
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
        while nextAnnot <= nAnnots && bytesLeft >= length(annotsList{nextAnnot})
            bytesLeft = bytesLeft - fprintf(sfid, '%s', annotsList{nextAnnot});
            nextAnnot = nextAnnot + 1;
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


