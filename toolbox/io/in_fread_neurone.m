function F = in_fread_neurone(sFile, SamplesBounds, ChannelsRange)
% IN_FREAD_NEURONE:  Read a block of recordings from a NeurOne session.
%
% USAGE:  F = in_fread_neurone(sFile, SamplesBounds=[], ChannelsRange=[])

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2015

% Parse inputs
if (nargin < 3) || isempty(ChannelsRange)
    ChannelsRange = [1, sFile.header.nChannels];
end
if (nargin < 2) || isempty(SamplesBounds)
    SamplesBounds = sFile.prop.samples;
end

% ===== COMPUTE OFFSETS =====
nChannels     = double(sFile.header.nChannels);
nReadTimes    = SamplesBounds(2) - SamplesBounds(1) + 1;
nReadChannels = double(ChannelsRange(2) - ChannelsRange(1) + 1);
% Everything is stored on 16 bit integers
bytesPerVal = 4;
dataClass = 'int32';
% Time offset
offsetTime = round(SamplesBounds(1) * nChannels * bytesPerVal);
% Channel offset at the beginning and end of each channel block
offsetChannelStart = round((ChannelsRange(1)-1) * bytesPerVal);
offsetChannelEnd   = (nChannels - ChannelsRange(2)) * bytesPerVal;
% Start reading at this point
offsetStart = offsetTime + offsetChannelStart;
% Number of time samples to skip after each channel
offsetSkip = offsetChannelStart + offsetChannelEnd; 

% ===== READ DATA BLOCK =====
% Read only from first file
iBin = 1;
BinFile = sFile.header.bin_files{iBin};
sfid = fopen(BinFile, 'rb', sFile.byteorder);
if (sfid < 0)
    error(['Cannot open file: ' BinFile]);
end
% Position file at the beginning of the trial
fseek(sfid, offsetStart, 'bof');
% Read trial data
% => WARNING: CALL TO FREAD WITH SKIP=0 DOES NOT WORK PROPERLY
if (offsetSkip == 0)
    F = fread(sfid, [nReadChannels, nReadTimes], dataClass);
else
    precision = sprintf('%d*%s', nReadChannels, dataClass);
    F = fread(sfid, [nReadChannels, nReadTimes], precision, offsetSkip);
end
% Close file
fclose(sfid);
% Check that data block was fully read
if (numel(F) < nReadTimes * nReadChannels)
    % Error message
    disp(sprintf('BST> ERROR: File is truncated (%d values were read instead of %d)...', numel(F), nReadTimes * nReadChannels));
    % Pad with zeros 
    Ftmp = zeros(nReadChannels, nReadTimes);
    Ftmp(1:numel(F)) = F(:);
    F = Ftmp;
end

% ===== CALIBRATION ======
% Apply calibration gains
% F = rawMin + (F - rawMin) / (rawMax - rawMin) * (calMax - calMin);
iChan = ChannelsRange(1):ChannelsRange(2);
rawMin = sFile.header.calibration.rawMin(iChan)';
scaleF = (sFile.header.calibration.calMax(iChan)' - sFile.header.calibration.calMin(iChan)') ./ (sFile.header.calibration.rawMax(iChan)' - sFile.header.calibration.rawMin(iChan)');
F = bst_bsxfun(@minus, double(F), rawMin);
F = bst_bsxfun(@times, F, scaleF);
F = bst_bsxfun(@plus, F, rawMin);
% Convert from nanoV to V
F = F .* 1e-9;


