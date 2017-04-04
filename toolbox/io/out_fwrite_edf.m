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
F(F < 0) = bitcmp(F(F < 0)) + 1;

% Write to file
ncount = fwrite(sfid, F, 'int16');

% Check number of values written
if (ncount ~= numel(F))
    error('Error writing data to file.');
end