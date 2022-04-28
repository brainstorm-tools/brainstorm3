function [meg4_file, offsetStart, offsetSkip] = ctf_seek( sFile, iEpoch, iTimes, ChannelsRange )
% CTF_SEEK: Return the file and position in the file where a given piece of information is located.

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
% Authors: Francois Tadel, 2011


%% ===== LOCATE MEG4 FILE =====
% Look for the meg4 in which this epoch is stored
if isfield(sFile.header, 'meg4_files') && ~isempty(sFile.header.meg4_files)
    iFile = [];
    % Review all the MEG4 files available for this .ds
    for i = 1:length(sFile.header.meg4_files)
        % Look for the trial #iEpoch
        iEpochInFile = find(sFile.header.meg4_epochs{i} == iEpoch);
        if ~isempty(iEpochInFile)
            iFile = i;
            break;
        end
    end
    % If epoch was not found
    if isempty(iFile)
        error(sprintf('Epoch #%d is not accessible in any of the meg4 files of this dataset.', iEpoch));
    end
    meg4_file = sFile.header.meg4_files{iFile};
else
    iEpochInFile = iEpoch;
    meg4_file = sFile.filename;
end


%% ===== LOCATE IN THE FILE =====
% MEG4 files in CTF .ds folders are simple binary files with a 8 bytes header.
% Values are stored channel after channel, ie. the first nTimes values are all the times values for channel #1
nTimes    = double(sFile.header.gSetUp.no_samples);
nChannels = double(sFile.header.gSetUp.no_channels);
% Size of one value (int32 => 4 bytes)
bytesPerVal = 4;
% Offset of the beginning of the recordings in the file
offsetHeader = 8;
% Offset of epoch
offsetEpoch = (iEpochInFile - 1) * nTimes * nChannels * bytesPerVal;
% Channel offset
offsetChannel = (ChannelsRange(1)-1) * nTimes * bytesPerVal;
% Time offset at the beginning and end of each channel block
offsetTimeStart = (iTimes(1) - 1) * bytesPerVal;
offsetTimeEnd   = (nTimes - iTimes(end)) * bytesPerVal;

% Where to start reading in the file ?
% => After the header, the number of skipped epochs, channels and time samples
offsetStart = offsetHeader + offsetEpoch + offsetChannel + offsetTimeStart;
% Number of time samples to skip after each channel
offsetSkip = offsetTimeStart + offsetTimeEnd; 



