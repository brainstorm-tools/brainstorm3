function F = in_fread_eeg(sFile, sfid, iEpoch, SamplesBounds)
% IN_FREAD_EEG:  Read an epoch from a Neuroscan .eeg file (list of epochs).
%
% USAGE:  F = in_fread_eeg(sFile, sfid, iEpoch, SamplesBounds)
%         F = in_fread_eeg(sFile, sfid, iEpoch)

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
% Author: Francois Tadel, 2009-2011

fileSamples = round(sFile.prop.times .* sFile.prop.sfreq);
% Parse inputs
if (nargin < 4) || isempty(SamplesBounds)
    SamplesBounds = fileSamples;
% Check start and stop samples
elseif (SamplesBounds(1) < fileSamples(1)) || (SamplesBounds(1) > SamplesBounds(2)) || (SamplesBounds(2) > fileSamples(2))
    error('Invalid samples range.');
end

% Get some information on the file
nChannels = sFile.header.epochs(iEpoch).datasize(1);
% Position cursor in file to read this data block
startSample = SamplesBounds(1) - fileSamples(1);
pos = double(sFile.header.epochs(iEpoch).datapos) + startSample * nChannels * double(sFile.header.data.bytes_per_samp);
fseek(sfid, double(pos), 'bof');
% Read [nChannels, nSamples]
F = fread(sfid, [nChannels, SamplesBounds(2) - SamplesBounds(1) + 1], sFile.header.data.dataformat);
% Calibrate data
F = neuroscan_apply_calibration(F, sFile.header);






