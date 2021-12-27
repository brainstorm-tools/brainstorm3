function F = in_fread_msr(sFile, sfid, SamplesBounds)
% IN_FREAD_MSR:  Read a block of recordings from a ANT ASA .msm file
%
% USAGE:  F = in_fread_brainamp(sFile, sfid, SamplesBounds=[])

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
% Authors: Francois Tadel, 2017
% Parse inputs
if (nargin < 3) || isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
end

% FORMAT: linear matrix [nChannels x nTime]
nChannels = sFile.header.numchannels;
nTime     = round((sFile.prop.times(2) - sFile.prop.times(1)) .* sFile.prop.sfreq) + 1;
bytesize  = 4;
% Get start position
offsetTime  = SamplesBounds(1) * nChannels * bytesize;
% Number of time values to read for each channel
nTimeToRead = SamplesBounds(2) - SamplesBounds(1) + 1;
% Number of values to skip after each channel
nSkipTimeEnd = (nTime - SamplesBounds(2) - 1) * nChannels * bytesize;
nSkip        = nSkipTimeEnd + offsetTime;
% Position file at the beginning of the data block
fseek(sfid, double(offsetTime), 'bof');
% Read everything at once 
% => WARNING: CALL TO FREAD WITH SKIP=0 DOES NOT WORK PROPERLY
if (nSkip == 0)
    F = fread(sfid, [nChannels, nTime], '*float32');
else
    precision = sprintf('%d*float32=>float32', nTimeToRead * nChannels);
    F = fread(sfid, [nChannels, nTimeToRead], precision, nSkip);
end
            
% Convert from microVolts to Volts
F = 1e-6 * F;
