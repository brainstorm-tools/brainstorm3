function [F, TimeVector] = fif_read_raw_segment(sFile, sfid, iTimes, iChannels)
% FIF_READ_RAW_SEGMENT:  Read a block of raw data
%
% USAGE:  [F, TimeVector] = fif_read_raw_segment(sFile, sfid, iTimes, iChannels)
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
%   Adaptations for Brainstorm by Francois Tadel, 2009.



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


%
%  Initial checks
%
if from > to
    error(me,'No data in this range');
end
% fprintf(1,'Reading %d ... %d  =  %9.3f ... %9.3f secs...', ...
%    from, to, double(from)/info.sfreq, double(to)/info.sfreq);
%
%  Initialize the data and calibration vector
%
nchan = info.nchan;
dest  = 1;
%
if isempty(iChannels)
    F = zeros(nchan,to-from+1);
else
    F = zeros(length(iChannels),to-from+1);
end
do_debug=false;
for k = 1:length(raw.rawdir)
    this = raw.rawdir(k);
    %
    %  Do we need this buffer
    %
    if this.last > from
        if isempty(this.ent)
            %
            %  Take the easy route: skip is translated to zeros
            %
            if do_debug
                fprintf(1,'S');
            end
            if isempty(iChannels)
                one = zeros(nchan,this.nsamp);
            else
                one = zeros(length(iChannels),this.nsamp);
            end
        else
            tag = fiff_read_tag(sfid,this.ent.pos);
            %
            %   Depending on the state of the projection and selection
            %   we proceed a little bit differently
            %
            if isempty(iChannels)
                one = double(reshape(tag.data,nchan,this.nsamp));
            else
                one = double(reshape(tag.data,nchan,this.nsamp));
                one = one(iChannels,:);
            end
            
        end
        %
        %  The picking logic is a bit complicated
        %
        if to >= this.last && from <= this.first
            %
            %    We need the whole buffer
            %
            first_pick = 1;
            last_pick  = this.nsamp;
            if do_debug
                fprintf(1,'W');
            end
        elseif from > this.first
            first_pick = from - this.first + 1;
            if to < this.last
                %
                %   Something from the middle
                %
                last_pick = this.nsamp + to - this.last;
                if do_debug
                    fprintf(1,'M');
                end
            else
                %
                %   From the middle to the end
                %
                last_pick = this.nsamp;
                if do_debug
                    fprintf(1,'E');
                end
            end
        else
            %
            %    From the beginning to the middle
            %
            first_pick = 1;
            last_pick  = to - this.first + 1;
            if do_debug
                fprintf(1,'B');
            end
        end
        %
        %   Now we are ready to pick
        %
        picksamp = last_pick - first_pick + 1;
        if picksamp > 0
            F(:,dest:dest+picksamp-1) = one(:,first_pick:last_pick);
            dest = dest + picksamp;
        end
    end
    %
    %   Done?
    %
    if this.last >= to
        %       fprintf(1,' [done]\n');
        break;
    end
end

TimeVector = from:to;
TimeVector = double(TimeVector) / info.sfreq;






