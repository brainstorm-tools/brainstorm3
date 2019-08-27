function sFileOut = out_fopen_edf(OutputFile, sFileIn, ChannelMat, EpochSize, iChannels)
% OUT_FOPEN_EDF: Saves the header of a new empty EDF file.

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
% Authors: Martin Cousineau & Francois Tadel, 2017-2019


%% ===== PARSE INPUTS =====
% iChannels is set only if exporting only a subset of the input channels
if (nargin < 5) || isempty(iChannels)
    iChannels = [];
end
% Reject files with epochs
if (length(sFileIn.epochs) > 1)
    error('Cannot export epoched files to continuous EDF files.');
end
% Is the input file a native EDF file
fileSamples = round(sFileIn.prop.times .* sFileIn.prop.sfreq);
isRawEdf = strcmpi(sFileIn.format, 'EEG-EDF') && ~isempty(sFileIn.header) && isfield(sFileIn.header, 'patient_id') && isfield(sFileIn.header, 'signal');
nSamples = fileSamples(2) - fileSamples(1) + 1;
% Modify input headers (EDF export reuses the input header info directly)
if isRawEdf && ~isempty(iChannels)
    sFileIn.header.nsignal = length(iChannels);
    sFileIn.header.signal = sFileIn.header.signal(iChannels);
end


%% ===== GET MAXIMUM VALUES =====
if ~isRawEdf
    % Extracts the minimum and maximum values for each sensor over all the file (by blocks of 1s).
    % This helps optimizing the conversion of the recordings to int16 values.
    BlockSize = sFileIn.prop.sfreq; % 1-second blocks
    nBlocks = ceil(nSamples ./ BlockSize);
    % Initialize min/max matrices
    Fmax = 0 * ones(length(ChannelMat.Channel), 1);
    % Loop on all the blocks
    for iBlock = 1:nBlocks
        bst_progress('text', sprintf('Finding maximum values [%d%%]', round(iBlock/nBlocks*100)));
        % Get sample indices for a block of 1s
        SamplesBounds = [(iBlock - 1) * BlockSize + fileSamples(1), min(fileSamples(2), fileSamples(1) + iBlock * BlockSize)];
        % Read the block from the file
        Fblock = in_fread(sFileIn, ChannelMat, 1, SamplesBounds);
        % Keep only the files to be saved in the output file
        if ~isempty(iChannels)
            Fblock = Fblock(iChannels, :);
        end
        % Extract absolute max
        Fmax = max(Fmax, max(abs(Fblock),[],2));
    end
    % Make sure we don't have cases where the maximum is zero
    Fmax(Fmax == 0) = 1;
else
    Fmax =  1 * ones(length(ChannelMat.Channel), 1);
end


%% ===== WRITE EDF HEADER =====
bst_progress('text', 'Writing EDF+ header...');
% Get file comment
[fPath, fBase, fExt] = bst_fileparts(OutputFile);

% Initialize output file
sFileOut = sFileIn;
sFileOut.filename  = OutputFile;
sFileOut.condition = '';
sFileOut.format    = 'EEG-EDF';
sFileOut.byteorder = 'l';
sFileOut.comment   = fBase;
date = datetime;

% Create a new header structure
header            = struct();
header.version    = 0;
header.startdate  = datestr(date, 'dd.mm.yy');
header.starttime  = datestr(date, 'HH.MM.SS');
header.nsignal    = length(ChannelMat.Channel);
header.nrec       = nSamples / sFileIn.prop.sfreq;

% We need to choose a record length that produces a  record size less than
% 61440 bytes (at 2 bytes per sample).
% We'll enforce this only if the epoch size is divisible to avoid problems.
header.reclen = EpochSize / sFileIn.prop.sfreq;
factors = full_factors(EpochSize);

for iFactor = 1:length(factors)
    header.reclen = EpochSize / sFileIn.prop.sfreq / factors(iFactor);
    recordSize = EpochSize / factors(iFactor) * header.nsignal * 2;
    
    if recordSize <= 61440
        break;
    end
end
header.nrec = ceil(header.nrec / header.reclen);

% Add an additional channel at the end to save events if necessary.
% if ~isempty(sFileIn.events)
    % If the last channel is not already an Annotation channel: add it
    if ~strcmpi(ChannelMat.Channel(end).Name, 'Annotations') || ~strcmpi(ChannelMat.Channel(end).Type, 'EDF')
        header.nsignal = header.nsignal + 1;
        Fmax(end+1) = 1;
    end
    header.annotchan = header.nsignal;

    % Some EDF+ fields are required by strict viewers such as EDFbrowser
    header.unknown1    = 'EDF+C';
    header.patient_id  = 'UNKNOWN M 01-JAN-1900 Unknown_Patient';
    header.rec_id      = ['Startdate ', upper(datestr(date, 'dd-mmm-yyyy')), ...
                          ' Unknown_Hospital Unknown_Technician Unknown_Equipment'];

    % Compute annotations
    header.annotations = {};
    maxAnnotLength     = 0;
    
    for iEvt = 1:numel(sFileIn.events)
        event = sFileIn.events(iEvt);
        % EDF file start at 0s: removed the start file time
        event.times = event.times - sFileIn.prop.times(1);
        
        for iEpc = 1:length(event.epochs)
            startTime = event.times(1,iEpc);
            annot = sprintf('+%f', startTime);
            
            if (size(event.times,1) == 2)
                duration = event.times(2,iEpc) - startTime;
                annot    = [annot, sprintf('%c%f', char(21), duration)];
            end
            
            annot = [annot, sprintf('%c%s%c%c', char(20), event.label, char(20), char(0))];
            header.annotations{end + 1} = annot;
            
            if length(annot) > maxAnnotLength
                maxAnnotLength = length(annot);
            end
        end
    end
% else
%     header.annotchan   = -1;
%     header.unknown1    = '';
%     header.patient_id  = '';
%     header.rec_id      = '';
% end
header.hdrlen = 256 + 256 * header.nsignal;

% Channel information
for i = 1:header.nsignal
    if ~isRawEdf
        % Choose unit based on maximal value
        if Fmax(i) > 1
            header.signal(i).unit = 'V';
            header.signal(i).unit_gain = 1;
        elseif Fmax(i) * 1e3 > 1
            header.signal(i).unit = 'mV';
            header.signal(i).unit_gain = 1e3;
        else
            header.signal(i).unit = 'uV';
            header.signal(i).unit_gain = 1e6;
        end
        
        chScale = 2^15 / Fmax(i);
        header.signal(i).digital_min  = -2^15;
        header.signal(i).digital_max  = 2^15 - 1;
        header.signal(i).physical_min = header.signal(i).digital_min / chScale .* header.signal(i).unit_gain;
        header.signal(i).physical_max = header.signal(i).digital_max / chScale .* header.signal(i).unit_gain;
        header.signal(i).filters      = '';
        header.signal(i).unknown2     = '';
    end
    
    % Approximate size of annotation channel
    header.signal(i).type  = '';
    if i == header.annotchan
        header.signal(i).label    = 'EDF Annotations';
        eventsPerRecord           = ceil(numel(header.annotations) / header.nrec);
        header.signal(i).nsamples = eventsPerRecord * maxAnnotLength + 15; % For first annotation of each record
        % Convert chars (1-byte) to 2-byte integers, the size of a sample
        header.signal(i).nsamples = int64((header.signal(i).nsamples + 1) / 2);
    else
        if strcmpi(ChannelMat.Channel(i).Type, 'EEG_NO_LOC')
            header.signal(i).label = ['EEG ', ChannelMat.Channel(i).Name];
        else
            header.signal(i).label = [ChannelMat.Channel(i).Type, ' ', ChannelMat.Channel(i).Name];
        end
        header.signal(i).nsamples = header.reclen * sFileIn.prop.sfreq;
    end
end

% Copy some values from the original header if possible
if isRawEdf
    header.patient_id = sFileIn.header.patient_id;
    header.rec_id     = sFileIn.header.rec_id;
    header.startdate  = sFileIn.header.startdate;
    header.starttime  = sFileIn.header.starttime;
    header.unknown1   = sFileIn.header.unknown1;
    for i = 1:sFileIn.header.nsignal
        header.signal(i).label        = sFileIn.header.signal(i).label;
        header.signal(i).type         = sFileIn.header.signal(i).type;
        header.signal(i).filters      = sFileIn.header.signal(i).filters;
        header.signal(i).unit         = sFileIn.header.signal(i).unit;
        header.signal(i).unknown2     = sFileIn.header.signal(i).unknown2;
        header.signal(i).physical_min = sFileIn.header.signal(i).physical_min;
        header.signal(i).physical_max = sFileIn.header.signal(i).physical_max;
        header.signal(i).digital_min  = sFileIn.header.signal(i).digital_min;
        header.signal(i).digital_max  = sFileIn.header.signal(i).digital_max;
        
        switch (header.signal(i).unit)
            case 'mV',                        header.signal(i).unit_gain = 1e3;
            case {'uV', char([166 204 86])},  header.signal(i).unit_gain = 1e6;
            otherwise,                        header.signal(i).unit_gain = 1;
        end
    end
end

% Open file
fid = fopen(OutputFile, 'w+', sFileOut.byteorder);
if (fid == -1)
    error('Could not open output file.');
end

% Write header
fwrite(fid, str_zeros(header.version, 8));
fwrite(fid, str_zeros(header.patient_id, 80));
fwrite(fid, str_zeros(header.rec_id, 80));
fwrite(fid, header.startdate);
fwrite(fid, header.starttime);
fwrite(fid, str_zeros(header.hdrlen, 8));
fwrite(fid, str_zeros(header.unknown1, 44));
fwrite(fid, str_zeros(header.nrec, 8));
fwrite(fid, str_zeros(header.reclen, 8));
fwrite(fid, str_zeros(header.nsignal, 4));

% Channel information
for i = 1:header.nsignal
    fwrite(fid, str_zeros(header.signal(i).label, 16));
end
for i = 1:header.nsignal
    fwrite(fid, str_zeros(header.signal(i).type, 80));
end
for i = 1:header.nsignal
    fwrite(fid, str_zeros(header.signal(i).unit, 8));
end
for i = 1:header.nsignal
    fwrite(fid, str_zeros(header.signal(i).physical_min, 8));
end
for i = 1:header.nsignal
    fwrite(fid, str_zeros(header.signal(i).physical_max, 8));
end
for i = 1:header.nsignal
    fwrite(fid, str_zeros(header.signal(i).digital_min, 8));
end
for i = 1:header.nsignal
    fwrite(fid, str_zeros(header.signal(i).digital_max, 8));
end
for i = 1:header.nsignal
    fwrite(fid, str_zeros(header.signal(i).filters, 80));
end
for i = 1:header.nsignal
    fwrite(fid, str_zeros(header.signal(i).nsamples, 8));
end
for i = 1:header.nsignal
    fwrite(fid, str_zeros(header.signal(i).unknown2, 32));
end

% Sanity check on the written header
assert(ftell(fid) == header.hdrlen);

% Close file
fclose(fid);
% Copy header to the sFile structure
sFileOut.header = header;

end


%% ===== HELPER FUNCTIONS =====
function sout = str_zeros(sin, N)
    if (isnumeric(sin))
        sin = num2str(sin);
    end

    sout = char(double(' ') * ones(1,N));
    if (length(sin) <= N)
        sout(1:length(sin)) = sin;
    else
        sout = sin(1:N);
    end
end

% This extracts a subset of the full factors of a number, not just the
% prime factors like factors() returns.
% E.g.: factor(100)      = [2,2,5,5]
%       full_factors(100) = [2,4,5,10,20,25,50]
function factors = full_factors(n)
    factors = factor(n);
    if length(factors) == 1
        factors = [];
        return;
    end
    [occurences, factors] = hist(factors, unique(factors));
    factors = factors(occurences > 0);
    occurences = occurences(occurences > 0);
    nFactors = length(factors);
    possibleFactors = ones(sum(occurences) * nFactors * nFactors);
    iPos = 1;
    for iFactor = 1:nFactors
        for iOcc = 1:occurences(iFactor)
            fact = factors(iFactor) ^ iOcc;
            possibleFactors(iPos) = fact;
            iPos = iPos + 1;
            for iFactor2 = 1:nFactors
                if iFactor ~= iFactor2
                    possibleFactors(iPos) = fact * factors(iFactor2);
                    iPos = iPos + 1;
                end
            end
        end
    end
    factors = unique(possibleFactors(1:iPos-1));
end
