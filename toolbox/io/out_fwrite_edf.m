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
    nextEvent      = 1;
    nextAnnot      = [];
    nEvents        = length(sFile.events);
    nSamplesAnnots = sFile.header.signal(sFile.header.annotchan).nsamples;
else
    annotations = 0;
end

% Write to file record per record
nSamplesPerRecord    = sFile.prop.sfreq * sFile.header.reclen;
nRecords             = sFile.header.nrec;
[nSignals, nSamples] = size(F);
ncount               = 0;
bounds               = [1, nSamplesPerRecord];
timeOffset           = 0.0;

for iRec = 1:nRecords
    for iSig = 1:nSignals
        ncount = ncount + fwrite(sfid, F(iSig, bounds(1):bounds(2)), 'int16');
    end
    
    % Write annotations if any, split by records
    if annotations
        bytesLeft = nSamplesAnnots * 2;
        
        % The first annotation specifies the time offset
        bytesLeft = bytesLeft - fprintf(sfid, '+%f%c%c%c', timeOffset, char(20), char(20), char(0));
        
        % Write as many annotations as possible in current record
        while bytesLeft >= length(nextAnnot)
            if ~isempty(nextAnnot)
                bytesLeft = bytesLeft - fprintf(sfid, '%s', nextAnnot);
            end
            
            if nextEvent > nEvents
                nextAnnot = [];
                break;
            end
            
            % Prepare the next annotation string
            event = sFile.events(nextEvent);
            startTime = event.times(1);
            nextAnnot = sprintf('+%f', startTime);

            % Add duration if specified.
            if length(event.times) > 1
                duration = event.times(2) - startTime;
                nextAnnot = [nextAnnot sprintf('%c%f', char(21), duration)];
            end

            nextAnnot = [nextAnnot sprintf('%c%s%c%c', char(20), event.label, char(20), char(0))];
            nextEvent = nextEvent + 1;
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
