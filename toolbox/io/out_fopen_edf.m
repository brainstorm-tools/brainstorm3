function sFileOut = out_fopen_edf(OutputFile, sFileIn, ChannelMat, EpochSize)
% OUT_FOPEN_EDF: Saves the header of a new empty EDF file.

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
header.nrec       = (sFileIn.prop.samples(2) - sFileIn.prop.samples(1) + 1) / EpochSize;

% We need to choose a record length that produces a whole number of records
% and a record size less than 61440 bytes (at 2 bytes per sample).
header.reclen     = 1.0;
epsilon           = 1e-8;
for i = 1:10
    remainder     = mod(header.nrec / header.reclen, 1);
    recordSize    = header.reclen * EpochSize * header.nsignal * 2;
    
    if (remainder > epsilon && abs(remainder - 1) > epsilon) || recordSize > 61440
        header.reclen = header.reclen / 10;
    else
        break;
    end
    
    if i == 10
        error('Could not find a valid record length for this data.');
    end
end
header.nrec       = header.nrec / header.reclen;

% Add an additional channel at the end to save events if necessary.
if ~isempty(sFileIn.events)
    header.nsignal     = header.nsignal + 1;
    header.annotchan   = header.nsignal;
    
    % Some EDF+ fields are required by strict viewers such as EDFbrowser
    header.unknown1    = 'EDF+C';
    header.patient_id  = 'UNKNOWN M 01-JAN-1900 Unknown_Patient';
    header.rec_id      = ['Startdate ', upper(datestr(date, 'dd-mmm-yyyy')), ...
                          ' Unknown_Hospital Unknown_Technician Unknown_Equipment'];
else
    header.annotchan   = -1;
    header.unknown1    = '';
    header.patient_id  = '';
    header.rec_id      = '';
end
header.hdrlen = 256 + 256 * header.nsignal;

% Channel information
for i = 1:header.nsignal
    header.signal(i).unit         = 'uV';
    header.signal(i).physical_min = -2^15;
    header.signal(i).physical_max = 2^15 - 1;
    header.signal(i).digital_min  = -2^15;
    header.signal(i).digital_max  = 2^15 - 1;
    header.signal(i).filters      = '';
    header.signal(i).unknown2     = '';
    
    % Approximate size of annotation channel
    if i == header.annotchan
        header.signal(i).label    = 'EDF Annotations';
        header.signal(i).type     = '';
        header.signal(i).nsamples = 12 * header.nrec; % For first annotation of each record
        maxEventSize              = 0;
        
        for j = 1:length(sFileIn.events)
            eventSize = length(sFileIn.events(j).label) + 25;
            header.signal(i).nsamples = header.signal(i).nsamples + eventSize;
            
            if eventSize > maxEventSize
                maxEventSize = eventSize;
            end
        end
        header.signal(i).nsamples = int64(header.signal(i).nsamples / header.nrec);
        
        % The annotation record cannot be smaller than the largest event
        % plus the first annotation (12 bytes) of the record
        if header.signal(i).nsamples < maxEventSize + 12
            header.signal(i).nsamples = maxEventSize + 12;
        end
        
        % Convert chars (1-byte) to 2-byte integers, the size of a sample
        header.signal(i).nsamples = int64((header.signal(i).nsamples + 1) / 2);
    else
        header.signal(i).label    = ChannelMat.Channel(i).Name;
        header.signal(i).type     = ChannelMat.Channel(i).Type;
        header.signal(i).nsamples = (sFileIn.prop.samples(2) - sFileIn.prop.samples(1) + 1) / header.nrec;
    end

end

% Copy some values from the original header if possible
if strcmpi(sFileIn.format, sFileOut.format) && ~isempty(sFileIn.header)
    header.patient_id = sFileIn.header.patient_id;
    header.rec_id     = sFileIn.header.rec_id;
    header.startdate  = sFileIn.header.startdate;
    header.starttime  = sFileIn.header.starttime;
    header.unknown1   = sFileIn.header.unknown1;

    for i = 1:sFileIn.header.nsignal
        header.signal(i).label        = sFileIn.header.signal(i).label;
        header.signal(i).type         = sFileIn.header.signal(i).type;
        header.signal(i).filters      = sFileIn.header.signal(i).filters;
        header.signal(i).unknown2     = sFileIn.header.signal(i).unknown2;
        header.signal(i).physical_min = sFileIn.header.signal(i).physical_min;
        header.signal(i).physical_max = sFileIn.header.signal(i).physical_max;
        header.signal(i).digital_min  = sFileIn.header.signal(i).digital_max;
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
