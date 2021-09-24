function [sFile, ChannelMat] = in_fopen_oebin(DataFile)
% IN_FOPEN_OEBIN: Open a .dat/.oebin file.
%
% USAGE:  [sFile, ChannelMat] = in_fopen_oebin(DataFile)
%
% DOCUMENTATION:
%    https://open-ephys.atlassian.net/wiki/spaces/OEW/pages/166789121/Flat+binary+format

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
% Authors: Francois Tadel, 2020

%% ===== GET FILES =====
% Build header and markers files names
procDir = bst_fileparts(DataFile);
[contDir, procName] = bst_fileparts(procDir);
recDir = bst_fileparts(contDir);
expDir = bst_fileparts(recDir);
[parentDir, expName] = bst_fileparts(expDir);
[tmp, parentName] = bst_fileparts(parentDir);
% Timestamp file
TimeFile = bst_fullfile(procDir, 'timestamps.npy');
if ~file_exist(TimeFile)
    error(['Could not find timestamp file: ' TimeFile]);
end
% OEBIN JSON header
OebinFile = bst_fullfile(recDir, 'structure.oebin');
if ~file_exist(OebinFile)
    error(['Could not find header file: ' OebinFile]);
end
% Event files
EvtFiles = file_find(bst_fullfile(recDir, 'events'), 'timestamps.npy', 3, 0);


%% ===== READ HEADER =====
% Read JSON file
hdr = bst_jsondecode(OebinFile);
% If there are multiple processors in the same recording: find the one corresponding to this .dat file
if (length(hdr.continuous) > 1)
    iRec = find(strcmpi({hdr.continuous.folder_name}, [procName, '/']));
    if isempty(iRec)
        iRec = find(~cellfun(@(c)isempty(strfind(c, procName)), {hdr.continuous.folder_name}), 1);
    end
    if isempty(iRec)
        error(['Could not find header for processor "' procName '".']);
    end
% Only one process: use this one
elseif (length(hdr.continuous) == 1)
    iRec = 1;
% If there are not continuous files: error
else
    error('Recordings do not contain continuous data.');
end
hdr.continuous = hdr.continuous(iRec);
% Read time stamps
TimeStamps = readNPY(TimeFile);


%% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder  = 'l';
sFile.filename   = DataFile;
sFile.format     = 'EEG-OEBIN';
sFile.device     = procName;
% Comment: parent filename
sFile.comment = parentName;
sFile.condition = parentName;
% Consider that the sampling rate of the file is the sampling rate of the first signal
sFile.prop.sfreq   = hdr.continuous.sample_rate;
sFile.prop.times   = double([TimeStamps(1), TimeStamps(1) + length(TimeStamps) - 1]) ./ sFile.prop.sfreq;
sFile.prop.nAvg    = 1;
% No info on bad channels
sFile.channelflag = ones(hdr.continuous.num_channels, 1);


%% ===== CREATE EMPTY CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = [procName ' channels'];
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, hdr.continuous.num_channels]);
hdr.chgain = ones(1, hdr.continuous.num_channels);
% For each channel
for i = 1:hdr.continuous.num_channels
    if ~isempty(hdr.continuous.channels(i).channel_name)
        ChannelMat.Channel(i).Name = hdr.continuous.channels(i).channel_name;
    else
        ChannelMat.Channel(i).Name = sprintf('E%d', i);
    end
    if ~isempty(strfind(ChannelMat.Channel(i).Name, 'ADC'))
        ChannelMat.Channel(i).Type = 'ADC';
    else
        ChannelMat.Channel(i).Type = 'EEG';
    end
    ChannelMat.Channel(i).Loc     = [];
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Weight  = 1;
    ChannelMat.Channel(i).Comment = hdr.continuous.channels(i).description;
    % Channel gain
    switch lower(hdr.continuous.channels(i).units)
        case {'uv', '�v', 'microv'}, hdr.chgain(i) = hdr.continuous.channels(i).bit_volts / 1e6;
        case {'mv', 'milliv'},       hdr.chgain(i) = hdr.continuous.channels(i).bit_volts / 1e3;
        otherwise,                   hdr.chgain(i) = hdr.continuous.channels(i).bit_volts;
    end
end
% Save header
sFile.header = hdr;


%% ===== READ EVENTS =====
for iFile = 1:length(EvtFiles)
    sFile = import_events(sFile, [], EvtFiles{iFile}, 'OEBIN', [], 0);
end





