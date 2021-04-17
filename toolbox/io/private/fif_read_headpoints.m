function dig = fif_read_headpoints(fid, tree)
% FIF_READ_HEADPOINTS: Read digitized head points from a FIF file.

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


% FIFF Constants
global FIFF;
if isempty(FIFF)
   FIFF = fiff_define_constants();
end

% Get DIG points
isotrak = fiff_dir_tree_find(tree, FIFF.FIFFB_ISOTRAK);
dig=struct('kind',{},'ident',{},'r',{},'coord_frame',{});
if length(isotrak) == 1
    p = 0;
    for k = 1:isotrak.nent
        kind = isotrak.dir(k).kind;
        pos  = isotrak.dir(k).pos;
        if kind == FIFF.FIFF_DIG_POINT
            p = p + 1;
            tag = fiff_read_tag(fid,pos);
            dig(p) = tag.data;
	    dig(p).coord_frame = FIFF.FIFFV_COORD_HEAD;
        end
    end
end





