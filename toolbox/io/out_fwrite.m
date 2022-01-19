function sFile = out_fwrite(sFile, ChannelMat, iEpoch, SamplesBounds, iChannels, F)
% OUT_FWRITE: Write a block of data in a file.
%
% USAGE:  sFile = out_fwrite(sFile, ChannelMat, iEpoch, SamplesBounds, iChannels, F);
%
% INPUTS:
%     - sFile         : Structure for importing files in Brainstorm. Created by in_fopen()
%     - ChannelMat    : Channel file structure
%     - iEpoch        : Indice of the epoch to read (only one value allowed)
%     - SamplesBounds : [smpStart smpStop], First and last sample to read in epoch #iEpoch
%                       Set to [] to specify all the time definition
%     - iChannels     : Array of indices of the channels to import
%                       Set to [] to specify all the channels
%     - F             : Block of data to write to the file [iChannels x SamplesBounds]

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
% Authors: Francois Tadel, 2009-2019


%% ===== PARSE INPUTS =====
if isempty(iEpoch)
    iEpoch = 1;
end
% Write channel ranges for faster disk access
isChanRange = ismember(sFile.format, {'CTF', 'CTF-CONTINUOUS', 'EEG-EGI-RAW', 'BST-BIN', 'EEG-EDF'});
if isChanRange
    if isempty(iChannels)
        ChannelRange = [];
    else
        ChannelRange = [iChannels(1), iChannels(end)];
        if ~isequal(ChannelRange(1):ChannelRange(2), iChannels)
            error('Cannot write non-consecutive channels.');
        end
    end
end


%% ===== OPEN FILE =====
% Except for CTF, because file is open in the out_fwrite_ctf function (to handle multiple .meg4 files)
if ~ismember(sFile.format, {'CTF-CONTINUOUS', 'SPM-DAT'})
    % If file does not exist: Create it
    if ~file_exist(sFile.filename)
        sfid = fopen(sFile.filename, 'w', sFile.byteorder);
        if (sfid == -1)
            error('Could not create output file.');
        end
        fclose(sfid);
    end
    % Open file
    sfid = fopen(sFile.filename, 'r+', sFile.byteorder);
    if (sfid == -1)
        error(['Could not open output file: "' sFile.filename '".']);
    end
else
    sfid = [];
end
% Find EDF/BDF annotation channels
% if ~isempty(ChannelMat) && ismember(sFile.format, {'EEG-EGI-RAW', 'EEG-BRAINAMP'})
%     iAnnot = channel_find(ChannelMat.Channel, {'EDF', 'BDF', 'KDF'});
%     % Removing the EDF/BDF annotation channels
%     if ~isempty(iAnnot)
%         if (max(iAnnot) <= size(F,1))
%             F(iAnnot,:) = 0 .* F(iAnnot,:);
%         else
%             Ftmp = zeros(max(iAnnot), size(F,2));
%             Ftmp(1:size(F,1),:) = F;
%             F = Ftmp;
%         end
%     end
% end


%% ===== WRITE RECORDINGS BLOCK =====
switch (sFile.format)
    case 'EEG-EGI-RAW'
        out_fwrite_egi(sFile, sfid, SamplesBounds, ChannelRange, F);
    case 'EEG-BRAINAMP'
        out_fwrite_brainamp(sFile, sfid, SamplesBounds, F);
    case 'BST-BIN'
        out_fwrite_bst(sFile, sfid, SamplesBounds, ChannelRange, F);
    case 'SPM-DAT'
        out_fwrite_spm(sFile, SamplesBounds, iChannels, F);
    case 'FIF'
        out_fwrite_fif(sFile, sfid, iEpoch, SamplesBounds, iChannels, F);
    case 'CTF-CONTINUOUS'
        isContinuous = strcmpi(sFile.format, 'CTF-CONTINUOUS');
        out_fwrite_ctf(sFile, iEpoch, SamplesBounds, ChannelRange, isContinuous, F);
    case 'EEG-EDF'
        out_fwrite_edf(sFile, sfid, SamplesBounds, ChannelRange, F);
    otherwise
        error('Unsupported file format.');
end

%% ===== CLOSE FILE =====
if ~isempty(sfid) && ~isempty(fopen(sfid))
    fclose(sfid);
end



