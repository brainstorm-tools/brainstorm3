function F = in_fread_compumedics_pfs(sFile, sfid, SamplesBounds, ChannelsRange)
% IN_FREAD_COMPUMEDICS_PFS:  Read a block of recordings from a Compumedics ProFusion Sleep 4 exported binary file (.sdy/.rda).
%
% USAGE:  F = in_fread_compumedics_pfs(sFile, sfid, SamplesBounds=[], ChannelsRange=[])

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
% Authors: Francois Tadel, 2015

% Parse inputs
if (nargin < 4) || isempty(ChannelsRange)
    ChannelsRange = [1, sFile.header.nchannels];
end
if (nargin < 3) || isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
end

% ===== COMPUTE OFFSETS =====
nChannels     = double(sFile.header.nchannels);
nReadTimes    = SamplesBounds(2) - SamplesBounds(1) + 1;
nReadChannels = double(ChannelsRange(2) - ChannelsRange(1) + 1);
% Everything is stored on 32 bit floats
bytesPerVal = 4;
dataClass = 'single';
% Header offset
offsetHeader = sFile.header.rda.segment(1).pos;
% Time offset
offsetTime = round(SamplesBounds(1) * nChannels * bytesPerVal);
% Channel offset at the beginning and end of each channel block
offsetChannelStart = round((ChannelsRange(1)-1) * bytesPerVal);
offsetChannelEnd   = (nChannels - ChannelsRange(2)) * bytesPerVal;
% Start reading at this point
offsetStart = offsetHeader + offsetTime + offsetChannelStart;
% Number of time samples to skip after each channel
offsetSkip = offsetChannelStart + offsetChannelEnd; 

% ===== READ DATA BLOCK =====
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
% Check that data block was fully read
if (numel(F) < nReadTimes * nReadChannels)
    % Error message
    disp(sprintf('BST> ERROR: File is truncated (%d values were read instead of %d)...', numel(F), nReadTimes * nReadChannels));
    % Pad with zeros 
    Ftmp = zeros(nReadChannels, nReadTimes);
    Ftmp(1:numel(F)) = F(:);
    F = Ftmp;
end



