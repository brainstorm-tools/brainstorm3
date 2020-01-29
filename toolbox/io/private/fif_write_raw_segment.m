function  fif_write_raw_segment(sFile, sfid, iTimes, iChannels, F)
% FIF_READ_RAW_SEGMENT:  Read a block of raw data
%
% USAGE:  fif_read_raw_segment(sFile, sfid, iTimes, iChannels)
%
% INPUT:
%    - sFile     : Brainstorm structure for importing files
%    - sfid      : Pointer to an open file to read data from
%    - iTimes    : Indices of the samples to read
%    - iChannels : Indices of the channels to read

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
%   Copyright 2006
%
%   Matti Hamalainen
%   Athinoula A. Martinos Center for Biomedical Imaging
%   Massachusetts General Hospital
%   Charlestown, MA, USA
%
%   No part of this program may be photocopied, reproduced,
%   or translated to another program language without the
%   prior written consent of the author.
%
%   Adaptations for Brainstorm by Francois Tadel, 2013.

global FIFF;
if isempty(FIFF)
    FIFF = fiff_define_constants();
end

me='MNE:fiff_read_raw_segment';

raw = sFile.header.raw;
info = sFile.header.info;
if (nargin < 4)
    iChannels = [];
end
if (nargin < 3)
    from = raw.first_samp;
    to   = raw.last_samp;
else
    from = max(iTimes(1), raw.first_samp);
    to   = min(iTimes(2), raw.last_samp);
end

%  Initial checks
if (from > to)
    error(me,'No data in this range');
end
nchan = info.nchan;
dest  = 1;
% Loop on the records
for k = 1:length(raw.rawdir)
    this = raw.rawdir(k);
    % Do we need this buffer
    if (this.last > from) && ~isempty(this.ent)
        % Read block of data
        tag = fiff_read_tag(sfid, this.ent.pos);
        % Reshape data
        Fold = double(reshape(tag.data, nchan, this.nsamp));

        % We need the whole buffer
        if (to >= this.last) && (from <= this.first)
            first_pick = 1;
            last_pick  = this.nsamp;
        elseif (from > this.first)
            first_pick = from - this.first + 1;
            % Something from the middle
            if (to < this.last)
                last_pick = this.nsamp + to - this.last;
            % From the middle to the end
            else
                last_pick = this.nsamp;
            end
        % From the beginning to the middle
        else
            first_pick = 1;
            last_pick  = to - this.first + 1;
        end
        % Now we are ready to pick
        picksamp = last_pick - first_pick + 1;
        if (picksamp > 0)
            if ~isempty(iChannels)
                Fold(iChannels, first_pick:last_pick) = F(:, dest:dest+picksamp-1);
            else
                Fold(:, first_pick:last_pick) = F(:, dest:dest+picksamp-1);
            end
            dest = dest + picksamp;
            % Convert to initial data type
            eval(['Fold = ' class(tag.data) '(Fold);']);
            % Reshape the matrix back to what it was initially
            tag.data = reshape(Fold, size(tag.data));
            % Seek in the file again at the beginning of the data part of the tag
            fseek(sfid, this.ent.pos + 4*4, 'bof');
            % Get data class
            switch (tag.type)
                case FIFF.FIFFT_BYTE,       dataClass = 'uint8';
                case FIFF.FIFFT_SHORT,      dataClass = 'int16';
                case FIFF.FIFFT_INT,        dataClass = 'int32';
                case FIFF.FIFFT_USHORT,     dataClass = 'uint16';
                case FIFF.FIFFT_UINT,       dataClass = 'uint32';
                case FIFF.FIFFT_FLOAT,      dataClass = 'single';
                case FIFF.FIFFT_DOUBLE,     dataClass = 'double';
                case FIFF.FIFFT_STRING,     dataClass = 'uint8';
                case FIFF.FIFFT_DAU_PACK16, dataClass = 'int16';
                otherwise,                  error('FIF data type not supported for writing.');
            end
            % Write tag back to file
            fwrite(sfid, tag.data, dataClass);
        end
    end
    % Done?
    if (this.last >= to)
        break;
    end
end




