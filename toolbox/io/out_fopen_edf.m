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

% Create a new header structure
sFileOut = sFileIn;
sFileOut.filename  = OutputFile;
sFileOut.condition = '';
sFileOut.format    = 'EEG-EDF';
sFileOut.byteorder = 'l';
sFileOut.comment   = fBase;
date = datetime;

header            = struct();
header.version    = 0;
header.patient_id = '';  %TODO: Try to get subject name from file to export?
header.rec_id     = '';  %TODO: see above
header.startdate  = datestr(date, 'dd.mm.yy');
header.starttime  = datestr(date, 'HH.MM.SS');
header.nsignal    = length(ChannelMat.Channel);
header.hdrlen     = 256 + 256 * header.nsignal;
header.unknown1   = '';  %TODO: EDF+ stuff
header.nrec       = (sFileIn.prop.samples(2) - sFileIn.prop.samples(1) + 1) / EpochSize;

% We need to choose a record length that produces a whole number of records
header.reclen     = 1.0;
for i = 1:10
    remainder = mod(header.nrec / header.reclen, 1);
    if remainder > 0 && abs(remainder - 1) > 1e-6
        header.reclen = header.reclen / 10;
    else
        break;
    end
    
    if i == 10
        error('Could not find a valid record length for this data.');
    end
end
header.nrec       = header.nrec / header.reclen;

% Channel information
for i = 1:header.nsignal
    header.signal(i).label        = ChannelMat.Channel(i).Name;
    header.signal(i).type         = ChannelMat.Channel(i).Type;
    header.signal(i).unit         = 'uV';
    header.signal(i).physical_min = 0;  %TODO: how to determine this value?
    header.signal(i).physical_max = 1;  %TODO: see above
    header.signal(i).digital_min  = 0;  %TODO: see above
    header.signal(i).digital_max  = 1;  %TODO: see above
    header.signal(i).filters      = '';
    header.signal(i).nsamples     = (sFileIn.prop.samples(2) - sFileIn.prop.samples(1) + 1) / header.nrec;
    header.signal(i).unknown2     = '';
end

% Copy some values from the original header if possible
if strcmpi(sFileIn.format, sFileOut.format) && ~isempty(sFileIn.header)
    header.patient_id = sFileIn.header.patient_id;
    header.rec_id     = sFileIn.header.rec_id;
    header.startdate  = sFileIn.header.startdate;
    header.starttime  = sFileIn.header.starttime;
    header.unknown1   = sFileIn.header.unknown1;

    for i = 1:header.nsignal
        header.signal(i).label    = sFileIn.header.signal(i).label;
        header.signal(i).type     = sFileIn.header.signal(i).type;
        header.signal(i).filters  = sFileIn.header.signal(i).filters;
        header.signal(i).unknown2 = sFileIn.header.signal(i).unknown2;
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
