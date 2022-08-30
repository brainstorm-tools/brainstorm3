function [sFile, ChannelMat] = in_fopen_adicht(DataFile, isInteractive)
% IN_FOPEN_ADICHT: Open a .adicht file (ADInstruments LabChart)

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
% Authors: Francois Tadel, 2021


%% ===== INSTALL ADI-SDK =====
[isInstalled, errMsg] = bst_plugin('Install', 'adi-sdk', isInteractive);
if ~isInstalled
    error(errMsg); 
end
bst_plugin('SetProgressLogo', 'adi-sdk');

%% ===== READ HEADER =====
% Read file header
objFile = adi.readFile(DataFile);
hdr.nEpochs = length(objFile.records);
hdr.nChannels = objFile.n_channels;
% Check sampling frequency
if (length(objFile.records) > 1) && ~all([objFile.records.tick_fs] == objFile.records(1).tick_fs)
    hdr.nEpochs = 1;
    disp('BST> Error: Cannot read multiple records if they have different sampling rates.');
end


%% ===== FILL STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder  = 'l';
sFile.filename   = DataFile;
sFile.format     = 'EEG-ADICHT';
sFile.prop.sfreq = double(objFile.records(1).tick_fs);
sFile.prop.nAvg  = 1;
sFile.channelflag= ones(hdr.nChannels,1);
sFile.device     = 'ADI';
sFile.header     = hdr;
% Comment: short filename
[fPath, fBase, fExt] = bst_fileparts(DataFile);
sFile.comment = fBase;
% Acquisition date
if (length(objFile.records(1).data_start_str) >= 11)
    sFile.acq_date = str_date(objFile.records(1).data_start_str(1:11));
end

%% ===== EPOCHS =====
% Multiple records
if (hdr.nEpochs > 1)
    sFile.epochs = repmat(db_template('epoch'), 1, hdr.nEpochs);
    for i = 1:hdr.nEpochs
        sFile.epochs(i).times   = [0, objFile.records(i).n_ticks - 1] ./ sFile.prop.sfreq;
        sFile.epochs(i).label   = sprintf('Record #%d', i);
        sFile.epochs(i).nAvg    = 1;
        sFile.epochs(i).select  = 1;
        sFile.epochs(i).bad     = 0;
    end
    sFile.prop.times = [min([sFile.epochs.times]), max([sFile.epochs.times])];
% Single record
else
    sFile.prop.times = [0, objFile.records(1).n_ticks - 1] ./ sFile.prop.sfreq;
end


%% ===== CREATE CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'LabChart channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, hdr.nChannels]);
% For each channel
for i = 1:hdr.nChannels
    if ~isempty(objFile.channel_names{i})
        ChannelMat.Channel(i).Name = objFile.channel_names{i};
    else
        ChannelMat.Channel(i).Name = sprintf('E%d', i);
    end
    ChannelMat.Channel(i).Type = 'EEG';
end


