function F = in_fread_cnt(sFile, sfid, SamplesBounds)
% IN_FREAD_CNT:  Read a block of recordings from a Neuroscan .cnt file
%
% USAGE:  F = in_fread_cnt(sFile, sfid, SamplesBounds) : Read all channels

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
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
% Author: Francois Tadel 2009-2015

% Check start and stop samples
if (nargin < 3) || isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
elseif (SamplesBounds(1) < 0) || (SamplesBounds(1) > SamplesBounds(2)) || (SamplesBounds(2) > sFile.header.data.numsamples)
    error('Invalid samples range.');
end
% Get some information on the file
nChannels = sFile.header.data.nchannels;
% Position cursor in file to read this data block
pos = sFile.header.data.datapos + SamplesBounds(1) * nChannels * sFile.header.data.bytes_per_samp;
fseek(sfid, double(pos), 'bof');
% Read [nChannels, nSamples]
F = fread(sfid, [nChannels, SamplesBounds(2) - SamplesBounds(1) + 1], sFile.header.data.dataformat);
% Calibrate data
F = neuroscan_apply_calibration(F, sFile.header);




