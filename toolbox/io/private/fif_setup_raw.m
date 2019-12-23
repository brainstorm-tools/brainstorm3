function [data] = fif_setup_raw(sFile, fid, allow_maxshield)
% FIF_SETUP_RAW:  Read information about raw data file
%
% USAGE:  [data] = fif_setup_raw(sFile, fid, allow_maxshield)
%
% INPUT:
%    - sFile           : Brainstorm structure for importing files
%    - fid             : Pointer to an open file
%    - allow_maxshield : Accept unprocessed MaxShield data

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
%   Section about file links copied from MNE-Python 0.19.1


%% ===== PARSE INPUT =====
% FIF Constants
global FIFF;
if isempty(FIFF)
    FIFF = fiff_define_constants();
end
% Other constants
FIFFT_SHORT=2;
FIFFT_INT=3;
FIFFT_FLOAT=4;
FIFFT_DAU_PACK16=16;
me = 'MNE-BST:fif_setup_raw';
% Arguments
if (nargin < 3)
    allow_maxshield = 1;
end
% Get file id
info = sFile.header.info;
meas = sFile.header.meas;


%% ===== LOCATE DATA OF INTEREST =====
raw = fiff_dir_tree_find(meas,FIFF.FIFFB_RAW_DATA);
if isempty(raw) && allow_maxshield
    raw = fiff_dir_tree_find(meas,FIFF.FIFFB_IAS_RAW_DATA);
    %warning('Reading FIFFB_IAS_RAW_DATA.');
end
if isempty(raw)
    raw = fiff_dir_tree_find(meas,FIFF.FIFFB_CONTINUOUS_DATA);
    disp([10 '--------' 10 ...
          'WARNING: This file contains raw Internal Active Shielding data. It may be distorted.' 10 ...
          'Elekta recommends it be run run through MaxFilter to produce reliable results.' 10 ...
          'Consider closing the file and running MaxFilter on the data.' 10 ...
          '--------' 10]);
end
if isempty(raw)
    error(me,'No raw data in file');
end

%
%   Set up the output structure
%
data.first_samp = 0;
data.last_samp  = 0;
%
%   Process the directory
%
dir          = raw.dir;
nent         = raw.nent;
first        = 1;
first_samp   = 0;
first_skip   = 0;
%
%  Get first sample tag if it is there
%
if dir(first).kind == FIFF.FIFF_FIRST_SAMPLE
    tag = fiff_read_tag(fid,dir(first).pos);
    first_samp = tag.data;
    first = first + 1;
end
%
%  Omit initial skip
%
if dir(first).kind == FIFF.FIFF_DATA_SKIP
    %
    %  This first skip can be applied only after we know the buffer size
    %
    tag = fiff_read_tag(fid,dir(first).pos);
    first_skip = tag.data;
    first = first + 1;
end
data.first_samp = first_samp;
%
%   Go through the remaining tags in the directory
%
rawdir = struct('ent',{},'first',{},'last',{},'nsamp',{});
nskip = 0;
ndir  = 0;
for k = first:nent
    ent = dir(k);
    if ent.kind == FIFF.FIFF_DATA_SKIP
        tag = fiff_read_tag(fid,ent.pos);
        nskip = tag.data;
    elseif ent.kind == FIFF.FIFF_DATA_BUFFER
        %
        %   Figure out the number of samples in this buffer
        %
        switch ent.type
            case FIFFT_DAU_PACK16
                nsamp = ent.size/(2*info.nchan);
            case FIFFT_SHORT
                nsamp = ent.size/(2*info.nchan);
            case FIFFT_FLOAT
                nsamp = ent.size/(4*info.nchan);
            case FIFFT_INT
                nsamp = ent.size/(4*info.nchan);
            otherwise
                fclose(fid);
                error(me,'Cannot handle data buffers of type %d',ent.type);
        end
        %
        %  Do we have an initial skip pending?
        %
        if first_skip > 0
            first_samp = first_samp + nsamp*first_skip;
            data.first_samp = first_samp;
            first_skip = 0;
        end
        %
        %  Do we have a skip pending?
        %
        if nskip > 0
            ndir        = ndir+1;
            rawdir(ndir).ent   = [];
            rawdir(ndir).first = first_samp;
            rawdir(ndir).last  = first_samp + nskip*nsamp - 1;
            rawdir(ndir).nsamp = nskip*nsamp;
            first_samp = first_samp + nskip*nsamp;
            nskip = 0;
        end
        %
        %  Add a data buffer
        %
        ndir               = ndir+1;
        rawdir(ndir).ent   = ent;
        rawdir(ndir).first = first_samp;
        rawdir(ndir).last  = first_samp + nsamp - 1;
        rawdir(ndir).nsamp = nsamp;
        first_samp = first_samp + nsamp;
    end
end
data.last_samp  = first_samp - 1;

data.rawdir = rawdir;
%
% fprintf(1,'\tRange : %d ... %d  =  %9.3f ... %9.3f secs\n',...
%     data.first_samp,data.last_samp,...
%     double(data.first_samp)/info.sfreq,...
%     double(data.last_samp)/info.sfreq);


%% ===== GET LINK TO NEXT FILE =====
% Initialize references
data.next_fname = [];
data.next_num = [];
data.next_id = [];
% Find the reference block
ref = fiff_dir_tree_find(meas,FIFF.FIFFB_REF);
if ~isempty(ref)
    for iBlock = 1:length(ref)
        for k = 1:length(ref(iBlock).dir)
            ent = ref(iBlock).dir(k);
            switch (ent.kind)
                case FIFF.FIFF_REF_ROLE
                    % Check the role of the reference: accept only "next file"
                    tag = fiff_read_tag(fid, ent.pos);
                    if (tag.data ~= FIFF.FIFFV_ROLE_NEXT_FILE)
                        break;
                    end
                case FIFF.FIFF_REF_FILE_NAME
                    % Get filename of the next linked file
                    tag = fiff_read_tag(fid, ent.pos);
                    data.next_fname = tag.data;
                case FIFF.FIFF_REF_FILE_NUM
                    % Some files don't have the name, just the number. So we construct the name from the current name.
                    tag = fiff_read_tag(fid, ent.pos);
                    data.next_num = tag.data;
                case FIFF.FIFF_REF_FILE_ID
                    tag = fiff_read_tag(fid, ent.pos);
                    data.next_id = tag.data;
            end
        end
    end
end


