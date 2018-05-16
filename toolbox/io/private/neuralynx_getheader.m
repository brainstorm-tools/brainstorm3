function hdr = neuralynx_getheader(filename)
% NEURALYNX_GETHEADER Reads the 16384 byte header from any Neuralynx file (FieldTrip).

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors:  Robert Oostenveld, 2007, as part of the FieldTrip toolbox
%           Francois Tadel, 2015, for the Brainstorm integration

% ===== CONSTANTS =====
% Get file extension
[tmp,tmp,fExt] = bst_fileparts(filename);
% Standard header size
hdr.HeaderSize = 16*1024;
% Sandard record size (in bytes)
switch lower(fExt)
    case '.ncs'
        hdr.FileExtension = 'NCS';
        hdr.RecordSize = 1044;
    case '.nse'
        hdr.FileExtension = 'NSE';
        hdr.RecordSize = 112;
    case '.nst'
        hdr.FileExtension = 'NST';
        hdr.RecordSize = 304;
    case '.nts'
        hdr.FileExtension = 'NTS';
        hdr.RecordSize = 8;
    case '.ntt'
        hdr.FileExtension = 'NTT';
        hdr.RecordSize = 304;
end

% ===== READ HEADER =====
% Open Neuralynx file
fid = fopen(filename, 'rb', 'ieee-le');
% Read ASCII header
buf = fread(fid, [1 hdr.HeaderSize], 'uint8=>char');

% Get file size
fseek(fid, 0, 'eof');
hdr.FileSize = ftell(fid);
% NCS: Read first and last timestamps
if strcmpi(fExt, '.ncs')
    % Read first time stamp
    fseek(fid, hdr.HeaderSize, 'bof');
    hdr.FirstTimeStamp = fread(fid, 1, '*uint64');
    % Read last time stamp
    fseek(fid, -hdr.RecordSize, 'eof');
    hdr.LastTimeStamp = fread(fid, 1, '*uint64');
% NSE: Read all the time samples
elseif strcmpi(fExt, '.nse')
    % Compute number of records
    hdr.NumSamples = (hdr.RecordSize - 48) / 2;
    hdr.NumRecords = floor((hdr.FileSize - hdr.HeaderSize) / hdr.RecordSize);
    % Initialize the variables to read from the header
    hdr.SpikeTimeStamps = zeros(1, hdr.NumRecords, 'uint64');
        SpikeScNumber   = zeros(1, hdr.NumRecords, 'int32');
        SpikeCellNumber = zeros(1, hdr.NumRecords, 'int32');
    hdr.SpikeParam      = zeros(8, hdr.NumRecords, 'int32');
    % Loop on the records to get all the timestamps
    for iRec = 1:hdr.NumRecords
        % Seek at the beginning of the record
        fseek(fid, hdr.HeaderSize + (iRec-1) * hdr.RecordSize, 'bof');
        % Read header of the record
        hdr.SpikeTimeStamps(iRec) = fread(fid, 1, '*uint64');
            SpikeScNumber(iRec)   = fread(fid, 1, 'int32');    % Do not save in the header
            SpikeCellNumber(iRec) = fread(fid, 1, 'int32');    % Do not save in the header
        hdr.SpikeParam(:,iRec)    = fread(fid, 8, 'int32');
    end
end
% Close file
fclose(fid);


% ===== INTERPRET HEADER =====
% Remove special chars
buf(buf == 9)  = ' ';
buf(buf == 13) = [];
buf(buf == 0)  = [];
buf(buf == char(181)) = 'u';
% Split in lines
hdrlines = str_split(buf, 10);
% Loop over lines
for i = 1:length(hdrlines)
    % Line is empty
    if numel(hdrlines{i})==0
        continue;
    % Line contains a comment
    elseif (hdrlines{i}(1) == '#')
        continue;
    end
    % Strip the '-' sign
    while (hdrlines{i}(1) == '-')
        hdrlines{i} = hdrlines{i}(2:end);
    end
    % Cut into pieces
    item = textscan(hdrlines{i}, '%s');
    % Ignore line if there are less or more than two items
    if (length(item) ~= 1) || (length(item{1}) ~= 2)
        continue;
    end
    % Item1=key, Item2=value
    key = item{1}{1};
    val = item{1}{2};
    if any(val(1) == '-01234567989')
        % Try to convert to number
        val = str2num(val);
        % Revert to the original text
        if isempty(val)
            val = item{1}{2};
        end
    end
    % Remove unuseable characters from the variable name (key)
    key = key(key ~= ':');
    % Assign the value to the header structure
    hdr.(key) = val;
end

