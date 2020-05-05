function F = in_fread_ant(sFile, SamplesBounds)
% IN_FREAD_ANT:  Read a block of recordings from a ANT EEProbe .cnt/.avr file
%
% USAGE:  F = in_fread_ant(sFile, SamplesBounds) : Read all channels

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
% Author: Francois Tadel 2012-2019

% Use the full file if samples not specified
if (nargin < 2) || isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
end
% Check start and stop samples
if (SamplesBounds(1) < 0) || (SamplesBounds(1) > SamplesBounds(2)) || (SamplesBounds(2) >= sFile.header.nsample)
    error('Invalid samples range.');
end
% Read file using EEGLAB plugin
dat = eepv4_read(sFile.filename, SamplesBounds(1) + 1, SamplesBounds(2) + 1);
% Calibrate data (microV to V)
F = dat.samples * 1e-6;




