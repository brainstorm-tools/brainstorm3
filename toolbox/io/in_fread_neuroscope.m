function F = in_fread_neuroscope(sFile, sfid, SamplesBounds)
% IN_FREAD_NEUROSCOPE:  Read a block of recordings from a NeuroScope/Klusters LFP .eeg/.xml file.
%
% USAGE:  F = in_fread_neuroscope(sFile, sfid, SamplesBounds)  : Read all channels
%         F = in_fread_neuroscope(sFile, sfid)                 : Read all channels, all the times

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
% Authors: Francois Tadel, 2014

if (nargin < 3) || isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
end

% Read data block
nChannels = sFile.header.nChannels;
nTimes = SamplesBounds(2) - SamplesBounds(1) + 1;
% Time offset
timeOffset = sFile.header.byteSize * SamplesBounds(1) * nChannels;

% Set position in file
fseek(sfid, timeOffset, 'bof');
% Read value
F = fread(sfid, [nChannels,nTimes], sFile.header.byteFormat);

% Apply gains
F = bst_bsxfun(@rdivide, double(F), double(sFile.header.Gain));





