function [F, TimeVector] = fif_read_evoked(sFile, sfid, iEpoch)
% FIF_READ_EVOKED:  Read one evoked data set
%
% USAGE:  [F, TimeVector] = fif_read_evoked(sFile, sfid, iEpoch)
%
% INPUT:
%    - sFile  : Brainstorm structure for importing files
%    - sfid   : Pointer to an open file to read data from
%    - iEpoch : Indices of the sets to read from this file

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
%   Adaptations for Brainstorm by Francois Tadel, 2009-2019


global FIFF;
if isempty(FIFF)
    FIFF = fiff_define_constants();
end

me='MNE:fiff_read_evoked';

if (nargin < 3)
    iEpoch = 1;
elseif iEpoch <= 0
    error(me,'Data set selector must be positive');
end

info = sFile.header.info;
meas = sFile.header.meas;
fname = sFile.filename;

%
%   Locate the data of interest
%
evoked = fiff_dir_tree_find(meas,FIFF.FIFFB_EVOKED);
if length(evoked) == 0
    fclose(sfid);
    error(me,'Could not find evoked data');
end
%
%   Identify the aspects
%
naspect = 0;
is_smsh = [];
for k = 1:length(evoked)
    sets(k).aspects = fiff_dir_tree_find(evoked(k),FIFF.FIFFB_ASPECT);
    sets(k).naspect = length(sets(k).aspects);
    if sets(k).naspect > 0
        is_smsh = [ is_smsh zeros(1,sets(k).naspect) ];
        naspect = naspect + sets(k).naspect;
    end
    saspects  = fiff_dir_tree_find(evoked(k), FIFF.FIFFB_IAS_ASPECT);
    nsaspects = length(saspects);
    if nsaspects > 0
        sets(k).naspect = sets(k).naspect + nsaspects;
        sets(k).aspects = [ sets(k).aspects saspects ];
        is_smsh = [ is_smsh ones(1,sets(k).naspect) ];
        naspect = naspect + nsaspects;
    end
end
fprintf(1,'\t%d evoked data sets containing a total of %d data aspects in %s\n',length(evoked),naspect,fname);
if iEpoch > naspect || iEpoch < 1
    fclose(sfid);
    error(me,'Data set selector out of range');
end
%
%   Next locate the evoked data set
%
p = 0;
goon = true;
for k = 1:length(evoked)
    for a = 1:sets(k).naspect
        p = p + 1;
        if p == iEpoch
            my_evoked = evoked(k);
            my_aspect = sets(k).aspects(a);
            goon = false;
            break;
        end
    end
    if ~goon
        break;
    end
end
%
%   The desired data should have been found but better to check
%
if ~exist('my_evoked','var') || ~exist('my_aspect','var')
    fclose(sfid);
    error(me,'Desired data set not found');
end
%
%   Now find the data in the evoked block
%
nchan = 0;
sfreq = -1;
q = 0;
for k = 1:my_evoked.nent
    kind = my_evoked.dir(k).kind;
    pos  = my_evoked.dir(k).pos;
    switch kind
        case FIFF.FIFF_COMMENT
            tag = fiff_read_tag(sfid,pos);
            comment = tag.data;
        case FIFF.FIFF_FIRST_SAMPLE
            tag = fiff_read_tag(sfid,pos);
            first = tag.data;
        case FIFF.FIFF_LAST_SAMPLE
            tag = fiff_read_tag(sfid,pos);
            last = tag.data;
        case FIFF.FIFF_NCHAN
            tag = fiff_read_tag(sfid,pos);
            nchan = tag.data;
        case FIFF.FIFF_SFREQ
            tag = fiff_read_tag(sfid,pos);
            sfreq = tag.data;
        case FIFF.FIFF_CH_INFO
            q = q+1;
            tag = fiff_read_tag(sfid,pos);
            chs(q) = tag.data;
    end
end
if ~exist('comment','var')
    comment = 'No comment';
end
%
%   Local channel information?
%
if nchan > 0
    if ~exist('chs','var')
        fclose(sfid);
        error(me, ...
            'Local channel information was not found when it was expected.');
    end
    if length(chs) ~= nchan
        fclose(sfid);
        error(me, ...
            'Number of channels and number of channel definitions are different');
    end
    info.chs   = chs;
    info.nchan = nchan;
    fprintf(1, ...
        '\tFound channel information in evoked data. nchan = %d\n',nchan);
    if sfreq > 0
        info.sfreq = sfreq;
    end
end
nsamp = last-first+1;
fprintf(1,'\tFound the data of interest:\n');
fprintf(1,'\t\tt = %10.2f ... %10.2f ms (%s)\n',...
    1000*first/info.sfreq,1000*last/info.sfreq,comment);
if ~isempty(info.comps)
    fprintf(1,'\t\t%d CTF compensation matrices available\n',length(info.comps));
end
%
% Read the data in the aspect block
%
nepoch = 0;
nAvg = 1;
for k = 1:my_aspect.nent
    kind = my_aspect.dir(k).kind;
    pos  = my_aspect.dir(k).pos;
    switch kind
        case FIFF.FIFF_COMMENT
            tag = fiff_read_tag(sfid,pos);
            comment = tag.data;
        case FIFF.FIFF_ASPECT_KIND
            tag = fiff_read_tag(sfid,pos);
            aspect_kind = tag.data;
        case FIFF.FIFF_NAVE
            tag = fiff_read_tag(sfid,pos);
            nAvg = tag.data;
        case FIFF.FIFF_EPOCH
            nepoch = nepoch + 1;
            tag = fiff_read_tag(sfid,pos);
            epoch(nepoch) = tag;
    end
end
fprintf(1,'\t\tnAvg = %d aspect type = %d\n', nAvg, aspect_kind);
if nepoch ~= 1 && nepoch ~= info.nchan
    fclose(sfid);
    error(me,'Number of epoch tags is unreasonable (nepoch = %d nchan = %d)',nepoch,info.nchan);
end
%
%   Put the old style epochs together
%
if nepoch == 1
    all = epoch(1).data;
else
    all = epoch(1).data';
    for k = 2:nepoch
        all = [ all ; epoch(k).data' ];
    end
end
if size(all,2) ~= nsamp
    fclose(sfid);
    error(me,'Incorrect number of samples (%d instead of %d)', size(all,2),nsamp);
end


F = all;
TimeVector = double(first:1:last)/info.sfreq;


