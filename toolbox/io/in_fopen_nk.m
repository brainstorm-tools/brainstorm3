function [sFile, ChannelMat] = in_fopen_nk(DataFile)
% IN_FOPEN_EDF: Open a Nihon Kohden file (.EEG / .PNT / .LOG / .21E)
%
% USAGE:  [sFile, ChannelMat] = in_fopen_nk(DataFile)

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
%          Inspired from NK2EDF, Teunis van Beelen, 2007-2017
%          and from the BIOSIG-toolbox http://biosig.sf.net/


%% ===== GET FILES =====
% Get base filename for all the files
[fPath, fBase] = bst_fileparts(DataFile);
BaseFile = bst_fullfile(fPath, fBase);
% EEG file (mandatory)
EegFile = [BaseFile '.eeg'];
if ~file_exist(EegFile)
    EegFile = [BaseFile '.EEG'];
    if ~file_exist(EegFile)
        error('Could not find .EEG file.');
    end
end
% PNT file (optional)
PntFile = [BaseFile '.pnt'];
if ~file_exist(PntFile)
    PntFile = [BaseFile '.PNT'];
    if ~file_exist(PntFile)
        disp('NK> Warning: Could not find .PNT file.');
    end
end
% LOG file (optional)
LogFile = [BaseFile '.log'];
if ~file_exist(LogFile)
    LogFile = [BaseFile '.LOG'];
    if ~file_exist(LogFile)
        disp('NK> Warning: Could not find .LOG file.');
    end
end
% 21E file (optional)
ElecFile = [BaseFile '.21e'];
if ~file_exist(ElecFile)
    ElecFile = [BaseFile '.21E'];
    if ~file_exist(ElecFile)
        disp('NK> Warning: Could not find .21E electrodes file.');
    end
end


%% ===== READ EEG FILE =====
% Open file
fid = fopen(DataFile, 'rb');
if (fid == -1)
    error('Could not open EEG file.');
end
% Get deviceblock signature
hdr.device = fread(fid, [1 16], '*char');
if (check_device(hdr.device))
    error(['EEG deviceblock has unknown signature: "' hdr.device '"']);
end
% Get controlblock signature
fseek(fid, 129, 'bof');
hdr.control = fread(fid, [1 16], '*char');
if (check_device(hdr.control))
    error(['EEG controlblock has unknown signature: "' hdr.control '"']);
end
% Get waveformdatablock signature
fseek(fid, 6142, 'bof');
signature = fread(fid, [1 1], '*char');
if (signature ~= 1)
    error('waveformdatablock has wrong signature.');
end
% Get number of blocks
fseek(fid, 145, 'bof');
hdr.ctlblock_cnt = fread(fid, [1 1], 'uint8');
% Get all the pointers to all the blocks
for i = 1:hdr.ctlblock_cnt
    fseek(fid, 146 + (i-1) * 20, 'bof');
    hdr.ctlblock(i).address = fread(fid, 1, 'uint32');
    fseek(fid, hdr.ctlblock(i).address + 23, 'bof');
    hdr.ctlblock(i).datablock_cnt = fread(fid, [1 1], 'uint8');
    hdr.ctlblock(i).datablock = repmat(struct('address', [], 'num_samples', []), 0);
    for j = 1:hdr.ctlblock(i).datablock_cnt
        fseek(fid, hdr.ctlblock(i).address + ((j-1) * 20) + 18, 'bof');
        dataAddr = fread(fid, 1, 'uint32');
        % Add data block only if it points to a valid address in the file
        if (dataAddr > 0)
            iBlock = length(hdr.ctlblock(i).datablock) + 1;
            hdr.ctlblock(i).datablock(iBlock).address = dataAddr;
            % Read the sampling rate
            fseek(fid, hdr.ctlblock(i).datablock(iBlock).address + 26, 'bof');
            hdr.ctlblock(i).datablock(iBlock).sample_rate = bitand(fread(fid, 1, 'uint16'), hex2dec('3fff'));    % Nihon-Kohden int16 format
            % Read the block information: duration (samples)
            fseek(fid, hdr.ctlblock(i).datablock(iBlock).address + 28, 'bof');
            hdr.ctlblock(i).datablock(iBlock).num_records = fread(fid, 1, 'uint32');
            % Read number of channels
            fseek(fid, hdr.ctlblock(i).datablock(iBlock).address + 38, 'bof');
            hdr.ctlblock(i).datablock(iBlock).num_channels = fread(fid, 1, 'uint8') + 1;
            % Read channel order
            for iChan = 1:hdr.ctlblock(i).datablock(iBlock).num_channels
                fseek(fid, hdr.ctlblock(i).datablock(iBlock).address + 39 + (iChan - 1) * 10, 'bof');
                hdr.ctlblock(i).datablock(iBlock).channel_list(iChan) = fread(fid, 1, 'uint8') + 1;
            end
        end
    end
end
% Close file
fclose(fid);

% Current limitation: allow only files with single segments
if (length(hdr.ctlblock) ~= 1) || (length(hdr.ctlblock(1).datablock) ~= 1)
    error(['Files with more than one segments are currently not supported.' 10 ...
           'Please post a message on the Brainstorm forum if you need this feature to be enabled.']);
end
% Copy fields to the central header
dataBlock = hdr.ctlblock(1).datablock(1);
hdr.sample_rate     = dataBlock.sample_rate;
hdr.record_duration = 0.1;   % Everything saved in blocks of 0.1ms
hdr.num_samples     = dataBlock.num_records * dataBlock.sample_rate * hdr.record_duration;
hdr.num_channels    = dataBlock.num_channels;


%% ===== READ LOG FILE =====
if ~isempty(LogFile)
    % Open file
    fid = fopen(LogFile, 'rb');
    if (fid == -1)
        error('Could not open LOG file');
    end
    % Get file signature
    device = fread(fid, [1 16], '*char');
    if (check_device(device))
        error(['LOG file has unknown signature: "' device '"']);
    end
    % Get log blocks 
    fseek(fid, 145, 'bof');
    n_logblocks = fread(fid, 1, 'uint8');
    % Initializations
    total_logs = 0;
    
    % Loop on log blocks
    for i = 1:n_logblocks
        % Read number of logs in this block
        fseek(fid, 146 + ((i-1) * 20) , 'bof');
        logblock_address = fread(fid, 1, 'uint32');
        fseek(fid, logblock_address + 18, 'bof');
        n_logs = fread(fid, 1, 'uint8');
        % Initialization
        fseek(fid, logblock_address + 20, 'bof');
        hdr.logs(i).label = cell(1, n_logs);
        hdr.logs(i).time  = zeros(1, n_logs);
        % Read all the events
        for j = 1:n_logs
            hdr.logs(i).label{j} = strtrim(fread(fid, [1 20], '*char'));
            hdr.logs(i).label{j}(hdr.logs(i).label{j} == 0) = [];
            timeH = str2double(fread(fid, [1 2], '*char'));
            timeM = str2double(fread(fid, [1 2], '*char'));
            timeS = str2double(fread(fid, [1 2], '*char'));
            hdr.logs(i).time(j) = 60*60*timeH + 60*timeM + timeS;
            hdr.logs(i).label2{j} = strtrim(fread(fid, [1 19], '*char'));
        end
            
        % Read sub-events
        try
            % Read number of sub-logs
            fseek(fid, 146 + (((i-1) + 22) * 20) , 'bof');
            sublogblock_address = fread(fid, 1, 'uint32');
            fseek(fid, sublogblock_address + 18, 'bof');
            n_sublogs = fread(fid, 1, 'uint8');
            % Read sub-logs
            if (n_sublogs == n_logs)
                fseek(fid, sublogblock_address + 20, 'bof');
                for j = 1:n_logs
                    hdr.logs(i).sublog{j} = strtrim(fread(fid, [1 45], '*char'));
                    hdr.logs(i).time(j) = hdr.logs(i).time(j) + str2double(['0.' hdr.logs(i).sublog{j}(25:30)]);
                end
            end
        catch
            disp('NK> Could not read sub-events.');
        end
        total_logs = total_logs + n_logs;
    end
    % Close file
    fclose(fid);
end


%% ===== READ 21E FILE =====
% Read the channel names 
ChannelMat = in_channel_nk(ElecFile);

% Gains are fixed for the list of channels: 
%   - uV for channels: 1-42, 75, 76, 79-256
%   - mV for all the others
%   - Calibration = (Physical_max - Physical_min) ./ (Digital_max - Digital_min)
iChanMicro = [1:42, 75, 76, 79:256];
chanGains = 1e-3 * ones(1,256) * ((12002.56+12002.9) / (32767 + 32768));
chanGains(iChanMicro) = 1e-6 * ((3199.902+3200) / (32767 + 32768));

% Keep only the channels saved in the file
iSelChannels = hdr.ctlblock(1).datablock(iBlock).channel_list;
ChannelMat.Channel = ChannelMat.Channel(iSelChannels);
hdr.channel_gains  = chanGains(iSelChannels);

% Last channel: markers/events
ChannelMat.Channel(end).Name    = 'Events';
ChannelMat.Channel(end).Type    = 'STIM';
ChannelMat.Channel(end).Comment = '';
hdr.channel_gains(end) = 1;


%% ===== READ PNT FILE =====
if ~isempty(PntFile)
    % Open file
    fid = fopen(PntFile, 'rb');
    if (fid == -1)
        error('Could not open LOG file');
    end
    % Get file signature
    device = fread(fid, [1 16], '*char');
    if (check_device(device))
        error(['PNT file has unknown signature: "' device '"']);
    end
    % Read patient info: Id
    fseek(fid, 1540, 'bof');
    hdr.patient.Id = strtrim(fread(fid, [1 10], '*char'));
    hdr.patient.Id(hdr.patient.Id == 0) = [];
    % Read patient info: Name
    fseek(fid, 1582, 'bof');
    hdr.patient.Name = strtrim(fread(fid, [1 20], '*char'));
    hdr.patient.Name(hdr.patient.Name == 0) = [];
    % Read patient info: Sex
    fseek(fid, 1610, 'bof');
    hdr.patient.Sex = strtrim(fread(fid, [1 6], '*char'));
    hdr.patient.Sex(hdr.patient.Sex == 0) = [];
    % Read patient info: Birthday
    fseek(fid, 1632, 'bof');
    hdr.patient.Birthday = fread(fid, [1 10], '*char');
    % Read recordings date
    fseek(fid, 64, 'bof');
    numDate = sscanf(fread(fid, [1 14], '*char'), '%04u%02u%02u%02u%02u%02u');
    hdr.startdate = sprintf('%02d/%02d/%04d', numDate(3), numDate(2), numDate(1));
    hdr.starttime = sprintf('%02d:%02d:%02d', numDate(4), numDate(5), numDate(6));
    % Close file
    fclose(fid);
end


%% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder  = 'n';
sFile.filename   = DataFile;
sFile.format     = 'EEG-NK';
sFile.device     = ['Nihon Kohden ' hdr.device];
sFile.header     = hdr;
% Comment: short filename
[tmp__, sFile.comment, tmp__] = bst_fileparts(DataFile);
% Consider that the sampling rate of the file is the sampling rate of the first signal
sFile.prop.sfreq   = hdr.sample_rate;
sFile.prop.samples = [0, hdr.num_samples - 1];
sFile.prop.times   = sFile.prop.samples ./ sFile.prop.sfreq;
sFile.prop.nAvg    = 1;
% No info on bad channels
sFile.channelflag = ones(hdr.num_channels,1);


%% ===== EVENTS =====
% Get all the event types
evtList = hdr.logs(1).label;
% Events list
[uniqueEvt, iUnique] = unique(evtList);
uniqueEvt = evtList(sort(iUnique));
% Initialize events list
sFile.events = repmat(db_template('event'), 1, length(uniqueEvt));
% Build events list
for iEvt = 1:length(uniqueEvt)
    % Find all the occurrences of this event
    iOcc = find(strcmpi(uniqueEvt{iEvt}, evtList));
    % Concatenate all times
    t = hdr.logs(1).time(iOcc);
    % Set event
    sFile.events(iEvt).label   = strtrim(uniqueEvt{iEvt});
    sFile.events(iEvt).times   = t;
    sFile.events(iEvt).samples = round(t .* sFile.prop.sfreq);
    sFile.events(iEvt).epochs  = 1 + 0*t(1,:);
    sFile.events(iEvt).select  = 1;
end




end



%% ===== CHECK DEVICE =====
function isError = check_device(str)
    isError = ~ismember(str, {...
        'EEG-1100A V01.00', ...
        'EEG-1100B V01.00', ...
        'EEG-1100C V01.00', ...
        'QI-403A   V01.00', ...
        'QI-403A   V02.00', ...
        'EEG-2100  V01.00', ...
        'EEG-2100  V02.00', ...
        'DAE-2100D V01.30', ...
        'DAE-2100D V02.00', ...
        'EEG-1100A V02.00', ...
        'EEG-1100B V02.00', ...
        'EEG-1100C V02.00'});
    % Issues with newer systems: 'EEG-1200A V01.00'
end

    
    

