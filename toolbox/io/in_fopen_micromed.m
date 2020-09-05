function [sFile, ChannelMat] = in_fopen_micromed(DataFile)
% IN_FOPEN_MICROMED: Open a Micromed .TRC file (continuous recordings).

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
% Authors:  Guillaume Becq, 2010
%           Adapted by Francois Tadel for Brainstorm, 2018


%% ===== READ HEADER =====
% Open file
byteorder = 'l';
fid = fopen(DataFile, 'rb', byteorder);
if (fid == -1)
    error('Could not open file.');
end
% Patient
hdr.title      = strtrim(fread(fid, [1 32], '*char'));
hdr.laboratory = strtrim(fread(fid, [1 32], '*char'));
hdr.patient.last_name  = strtrim(fread(fid, [1 22], '*char'));
hdr.patient.first_name = strtrim(fread(fid, [1 20], '*char'));
hdr.patient.dob_month  = fread(fid, 1, 'uchar');
hdr.patient.dob_day    = fread(fid, 1, 'uchar');
hdr.patient.dob_year   = fread(fid, 1, 'uchar') + 1900;
hdr.patient.reserved   = fread(fid, [1 19], 'uchar');
% Acquisition
hdr.acquisition.day      = fread(fid, 1, 'uchar');
hdr.acquisition.month    = fread(fid, 1, 'uchar');
hdr.acquisition.year     = fread(fid, 1, 'uchar') + 1900;
hdr.acquisition.hour     = fread(fid, 1, 'uchar');
hdr.acquisition.min      = fread(fid, 1, 'uchar');
hdr.acquisition.sec      = fread(fid, 1, 'uchar');
hdr.acquisition.device   = fread(fid, 1, 'short');
hdr.acquisition.filetype = fread(fid, 1, 'ushort');
% Data
hdr.data_offset   = fread(fid, 1, 'ulong');  % data_start_offset
hdr.num_channels  = fread(fid, 1, 'ushort');
hdr.multiplexer   = fread(fid, 1, 'ushort'); % distance in bytes between successive samples
hdr.sampling_freq = fread(fid, 1, 'ushort'); % Rate_min 64, 128, 256, 512, 1024
hdr.num_bytes     = fread(fid, 1, 'ushort'); % Number of bytes to represent one data sample
hdr.compression   = fread(fid, 1, 'ushort'); % 0=no compression, 1=compression.
hdr.num_montages  = fread(fid, 1, 'ushort'); % Number of specific montages (0..30)
hdr.dvideo_start  = fread(fid, 1, 'ulong'); % Starting sample of digital video
hdr.mpeg_delay    = fread(fid, 1, 'ushort'); % Number of frames per hour of de-synchronization in MPEG acq
reserved_1        = fread(fid, 15, 'uchar');
hdr.header_type   = fread(fid, 1, 'uchar');
if ismember(hdr.header_type, [1 2 3 4 5])
    descript = {...
        'Micromed "System 1" Header type', ...
        'Micromed "System 1" Header type', ...
        'Micromed "System 2" Header type', ...
        'Micromed "System98" Header type', ...
        'Micromed "System98" Header type'};
    hdr.header_desc = descript{hdr.header_type};
else
    hdr.header_desc = 'Unknown';
end

% order (code)
hdr.code_area.name   = strtrim(fread(fid, [1 8], '*char'));
hdr.code_area.start  = fread(fid, 1, 'ulong');
hdr.code_area.length = fread(fid, 1, 'ulong');
% labcode (elec)
hdr.electrode_area.name   = strtrim(fread(fid, [1 8], '*char'));
hdr.electrode_area.start  = fread(fid, 1, 'ulong');
hdr.electrode_area.length = fread(fid, 1, 'ulong');
% note
hdr.note_area.name   = strtrim(fread(fid, [1 8], '*char'));
hdr.note_area.start  = fread(fid, 1, 'ulong');
hdr.note_area.length = fread(fid, 1, 'ulong');
% flags
hdr.flag_area.name   = strtrim(fread(fid, [1 8], '*char'));
hdr.flag_area.start  = fread(fid, 1, 'ulong');
hdr.flag_area.length = fread(fid, 1, 'ulong');
% tronca (redu )
hdr.segment_area.name   = strtrim(fread(fid, [1 8], '*char'));
hdr.segment_area.start  = fread(fid, 1, 'ulong');
hdr.segment_area.length = fread(fid, 1, 'ulong');
% impedB (begi)
hdr.B_impedance_area.name   = strtrim(fread(fid, [1 8], '*char'));
hdr.B_impedance_area.start  = fread(fid, 1, 'ulong');
hdr.B_impedance_area.length = fread(fid, 1, 'ulong');
% impedE (endi)
hdr.E_impedance_area.name   = strtrim(fread(fid, [1 8], '*char'));
hdr.E_impedance_area.start  = fread(fid, 1, 'ulong');
hdr.E_impedance_area.length = fread(fid, 1, 'ulong');
% montage (mont)
hdr.montage_area.name   = strtrim(fread(fid, [1 8], '*char'));
hdr.montage_area.start  = fread(fid, 1, 'ulong');
hdr.montage_area.length = fread(fid, 1, 'ulong');
% Compress
hdr.compression_area.name   = strtrim(fread(fid, [1 8], '*char'));
hdr.compression_area.start  = fread(fid, 1, 'ulong');
hdr.compression_area.length = fread(fid, 1, 'ulong');
% average (res)
hdr.average_area.name   = strtrim(fread(fid, [1 8], '*char'));
hdr.average_area.start  = fread(fid, 1, 'ulong');
hdr.average_area.length = fread(fid, 1, 'ulong');
% history (hist)
hdr.history_area.name   = strtrim(fread(fid, [1 8], '*char'));
hdr.history_area.start  = fread(fid, 1, 'ulong');
hdr.history_area.length = fread(fid, 1, 'ulong');
% dvideo (res2)
hdr.dvideo_area.name   = strtrim(fread(fid, [1 8], '*char'));
hdr.dvideo_area.start  = fread(fid, 1, 'ulong');
hdr.dvideo_area.length = fread(fid, 1, 'ulong');
% event A (eva)
hdr.eventA_area.name   = strtrim(fread(fid, [1 8], '*char'));
hdr.eventA_area.start  = fread(fid, 1, 'ulong');
hdr.eventA_area.length = fread(fid, 1, 'ulong');
% event B (evb)
hdr.eventB_area.name   = strtrim(fread(fid, [1 8], '*char'));
hdr.eventB_area.start  = fread(fid, 1, 'ulong');
hdr.eventB_area.length = fread(fid, 1, 'ulong');
% trigger (trig)
hdr.trigger_area.name   = strtrim(fread(fid, [1 8], '*char'));
hdr.trigger_area.start  = fread(fid, 1, 'ulong');
hdr.trigger_area.length = fread(fid, 1, 'ulong');
% reserved_2 = fread(fid, 224, 'uchar');

% Read channel order
fseek(fid, hdr.code_area.start, 'bof');
for iChannel = 1:hdr.num_channels
    switch (hdr.header_type)
        case 3
            hdr.code(iChannel) = fread(fid, 1, 'uint8');
        otherwise
            hdr.code(iChannel) = fread(fid, 1, 'ushort');
    end
end

% Read electrodes info
for iChannel = 1:hdr.num_channels      % Instead of 1:MAX_LAB (MAX_LAB = 640)
    % Read channel info (re-ordered by "code")
    fseek(fid, hdr.electrode_area.start + 128 * hdr.code(iChannel), -1);
    % Channel status
    hdr.electrode(iChannel).status = fread(fid, 1, 'uchar');  % 0=not acquired, 1=acquired
    % Channel type
    channelType = fread(fid, 1, 'uchar');
    hdr.electrode(iChannel).type_value = channelType;
    % PIL : positive input label
    hdr.electrode(iChannel).PIL = strtrim(fread(fid, [1 6], '*char'));
    hdr.electrode(iChannel).PIL = strtrim(hdr.electrode(iChannel).PIL(hdr.electrode(iChannel).PIL ~= 0));
    % NIL : positive input label
    hdr.electrode(iChannel).NIL = strtrim(fread(fid, [1 6], '*char'));
    hdr.electrode(iChannel).NIL = strtrim(hdr.electrode(iChannel).NIL(hdr.electrode(iChannel).NIL ~= 0));
    % Reference
    if bitget(channelType, 1)
        hdr.electrode(iChannel).reference = ['Bipolar ' hdr.electrode(iChannel).PIL '/' hdr.electrode(iChannel).NIL];
        hdr.electrode(iChannel).label     = strrep(hdr.electrode(iChannel).PIL, '+', '');  % [hdr.electrode(iChannel).PIL '-' hdr.electrode(iChannel).NIL];
    else
        hdr.electrode(iChannel).reference = ['Referred to ' hdr.electrode(iChannel).NIL];
        hdr.electrode(iChannel).label     = hdr.electrode(iChannel).PIL;
    end
    % Type
    hdr.electrode(iChannel).type = '';
    if bitget(channelType, 2)
        hdr.electrode(iChannel).type = [hdr.electrode(iChannel).type 'Marker '];
    end
    if bitget(channelType, 3)
        hdr.electrode(iChannel).type = [hdr.electrode(iChannel).type 'Oxym '];
    end
    if bitget(channelType, 4)
        hdr.electrode(iChannel).type = [hdr.electrode(iChannel).type '16DC '];
    end
    if bitget(channelType, 5)
        hdr.electrode(iChannel).type = [hdr.electrode(iChannel).type 'bip2eeg '];
    end
    if ~isempty(hdr.electrode(iChannel).type)
        hdr.electrode(iChannel).type = hdr.electrode(iChannel).type(1:end-1);
    elseif bitget(channelType, 1)
        hdr.electrode(iChannel).type = 'BIP';
    end
    % Logic minimum
    hdr.electrode(iChannel).logicMin = fread(fid, 1, 'long');
    % Logic maximum
    hdr.electrode(iChannel).logicMax = fread(fid, 1, 'long');
    % Logic ground
    hdr.electrode(iChannel).logicGround = fread(fid, 1, 'long');
    % Physic minimum
    hdr.electrode(iChannel).physicalMin = fread(fid, 1, 'long');
    % Physic maximum
    hdr.electrode(iChannel).physicalMax = fread(fid, 1, 'long');
    % Measurements Units
    hdr.electrode(iChannel).units_value = fread(fid, 1, 'ushort');
    switch (hdr.electrode(iChannel).units_value)
        case -1,   hdr.electrode(iChannel).units = 'nV';       hdr.electrode(iChannel).unit_gain = 1e-9;
        case 0,    hdr.electrode(iChannel).units = 'uV';       hdr.electrode(iChannel).unit_gain = 1e-6;
        case 1,    hdr.electrode(iChannel).units = 'mV';       hdr.electrode(iChannel).unit_gain = 1e-3;
        case 2,    hdr.electrode(iChannel).units = 'V';        hdr.electrode(iChannel).unit_gain = 1;
        case 100,  hdr.electrode(iChannel).units = '%';        hdr.electrode(iChannel).unit_gain = 1;
        case 101,  hdr.electrode(iChannel).units = 'bpm';      hdr.electrode(iChannel).unit_gain = 1;
        case 102,  hdr.electrode(iChannel).units = 'Adim';     hdr.electrode(iChannel).unit_gain = 1;
        otherwise, hdr.electrode(iChannel).units = 'unknown';  hdr.electrode(iChannel).unit_gain = 1;
    end
    % Prefiltering 
    hdr.electrode(iChannel).HiPass_Limit  = fread(fid, 1, 'ushort'); % high pass limit  (value in Hz * 1000)
    hdr.electrode(iChannel).HiPass_Type   = fread(fid, 1, 'ushort'); % high type
    hdr.electrode(iChannel).LowPass_Limit = fread(fid, 1, 'ushort'); % low pass limit  (value in Hz)
    hdr.electrode(iChannel).LowPass_Type  = fread(fid, 1, 'ushort'); % low pass type
    % Rate coef
    hdr.electrode(iChannel).Rate_Coefficient = fread(fid, 1, 'ushort'); % 1, 2, 4 * min. Sampling Rate
    hdr.electrode(iChannel).Position         = fread(fid, 1, 'ushort') + 1; % matlab index instead of C
    hdr.electrode(iChannel).Latitude         = fread(fid, 1, 'float');
    hdr.electrode(iChannel).Longitude        = fread(fid, 1, 'float');
    hdr.electrode(iChannel).presentInMap     = fread(fid, 1, 'uchar');
    hdr.electrode(iChannel).isInAvg          = fread(fid, 1, 'uchar');
    hdr.electrode(iChannel).Description      = char(fread(fid, 32, 'char')');
    hdr.electrode(iChannel).x                = fread(fid, 1, 'float');
    hdr.electrode(iChannel).y                = fread(fid, 1, 'float');
    hdr.electrode(iChannel).z                = fread(fid, 1, 'float');
    hdr.electrode(iChannel).Coordinate_Type  = fread(fid, 1, 'short');
    hdr.electrode(iChannel).Free             = char(fread(fid, 24, 'char')');
end

% Notes
fseek(fid, hdr.note_area.start, -1);
MAX_NOTE = 200; 
for i = 1:MAX_NOTE
    hdr.note(i).sample = fread(fid, 1, 'ulong');
    hdr.note(i).text   = strtrim(fread(fid, [1 40], '*char'));
    hdr.note(i).text((hdr.note(i).text == 0) | (hdr.note(i).text == 32)) = [];
end
% Delete empty notes
iDel = find(([hdr.note.sample] == 0) | cellfun(@isempty, {hdr.note.text}));
hdr.note(iDel) = [];

% % Flags
% fseek(fid, hdr.flag_area.start, -1);
% MAX_FLAG    = 100; 
% for i = 1 : MAX_FLAG
%     hdr.flag(i).begin = fread(fid, 1, 'ulong');
%     hdr.flag(i).end = fread(fid, 1, 'ulong');
% end
% % Segms
% fseek(fid, hdr.segment_area.start, -1);
% MAX_SEGM = 100; 
% for i = 1 : MAX_SEGM
%     hdr.segment(i).time = fread(fid, 1, 'ulong'); % in samples
%     hdr.segment(i).sample = fread(fid, 1, 'ulong');
% end
% % Starting Impedance
% fseek(fid, hdr.B_impedance_area.start, -1);
% for i = 1 : MAX_CAN
%     hdr.B_impedance(i).positive = fread(fid, 1, 'uchar');
%     hdr.B_impedance(i).negative = fread(fid, 1, 'uchar');
% end
% % Ending Impedance
% fseek(fid, hdr.E_impedance_area.start, -1);
% for i = 1 : MAX_CAN
%     hdr.E_impedance(i).positive = fread(fid, 1, 'uchar');
%     hdr.E_impedance(i).negative = fread(fid, 1, 'uchar');
% end
% % Specific montages
% fseek(fid, hdr.montage_area.start, -1);
% MAX_CAN_VIEW = 128;
% MAX_MONT     = 30;
% for i = 1:MAX_MONT
%     hdr.montage(i).lines          = fread(fid, 1, 'ushort');
%     hdr.montage(i).sectors        = fread(fid, 1, 'ushort');
%     hdr.montage(i).base_time      = fread(fid, 1, 'ushort');
%     hdr.montage(i).notch          = fread(fid, 1, 'ushort');
%     hdr.montage(i).colour         = fread(fid, MAX_CAN_VIEW, 'uchar');
%     hdr.montage(i).selection      = fread(fid, MAX_CAN_VIEW, 'uchar');
%     hdr.montage(i).description    = fread(fid, 64, 'char');
%     hdr.montage(i).inputsNonInv   = fread(fid, MAX_CAN_VIEW, 'ushort'); % NonInv : non inverting input
%     hdr.montage(i).inputsInv      = fread(fid, MAX_CAN_VIEW, 'ushort'); % Inv : inverting Input
%     hdr.montage(i).HiPass_Filter  = fread(fid, MAX_CAN_VIEW, 'ulong'); % value in Hz * 100
%     hdr.montage(i).LowPass_Filter = fread(fid, MAX_CAN_VIEW, 'ulong'); % value in Hz
%     hdr.montage(i).reference      = fread(fid, MAX_CAN_VIEW, 'ulong');
%     hdr.montage(i).free           = fread(fid, 1720, 'uchar');
% end

% % Compression
% fseek(fid, hdr.compression_area.start, -1);

% % Average (off-line average process)
% fseek(fid, hdr.average_area.start, -1);
% hdr.average.Mean_Trace    = fread(fid, 1, 'ulong');
% hdr.average.Mean_File     = fread(fid, 1, 'ulong');
% hdr.average.Mean_Prestim  = fread(fid, 1, 'ulong');
% hdr.average.Mean_PostStim = fread(fid, 1, 'ulong');
% hdr.average.Mean_Type     = fread(fid, 1, 'ulong');

% % History
% fseek(fid, hdr.history_area.start, -1);
% MAX_SAMPLE = 128;
% MAX_HISTORY = 30;
% for i = 1:MAX_HISTORY
%     hdr.history(i).nSample        = fread(fid, MAX_SAMPLE, 'ulong');
%     hdr.history(i).lines          = fread(fid, 1, 'ushort');
%     hdr.history(i).sectors        = fread(fid, 1, 'ushort');
%     hdr.history(i).base_time      = fread(fid, 1, 'ushort');
%     hdr.history(i).notch          = fread(fid, 1, 'ushort');
%     hdr.history(i).colour         = fread(fid, MAX_CAN_VIEW, 'uchar');
%     hdr.history(i).selection      = fread(fid, MAX_CAN_VIEW, 'uchar');
%     hdr.history(i).description    = fread(fid, 64, 'char');
%     hdr.history(i).inputsNonInv   = fread(fid, MAX_CAN_VIEW, 'ushort'); % NonInv : non inverting input
%     hdr.history(i).inputsInv      = fread(fid, MAX_CAN_VIEW, 'ushort'); % Inv : inverting Input
%     hdr.history(i).HiPass_Filter  = fread(fid, MAX_CAN_VIEW, 'ulong'); % value in Hz * 100
%     hdr.history(i).LowPass_Filter = fread(fid, MAX_CAN_VIEW, 'ulong'); % value in Hz
%     hdr.history(i).reference      = fread(fid, MAX_CAN_VIEW, 'ulong');
%     hdr.history(i).free           = fread(fid, 1720, 'uchar');
% end

% % DVIDEO
% fseek(fid, hdr.dvideo_area.start, -1);
% MAX_FILE = 1024;
% for i = 1 : MAX_FILE
%     thisReading= fread(fid, 1, 'int32');
%     hdr.dvideo(i).DV_Begin = thisReading;
%     q = mod(i, 4);
%     k = floor((i - 1) / 4) + 1;
%     switch q
%         case 1
%             hdr.video.MS(k,1) = thisReading;  % delay
%         case 2
%             hdr.video.MS(k,2) = thisReading; % duration
%         case 3
%             hdr.video.MS(k,3) = thisReading; % filename ext
%             extension = fullfilename(end-2:end);
%             switch extension
%                 case {'trc', 'TRC'}
%                     pathstr = fileparts(fullfilename);
%                     hdr.video.fullfilename{k} = [pathstr, filesep , ...
%                         'VID' ...
%                         '_' sprintf('%i', thisReading) , '.avi'];
%                 case {'vwr', 'VWR'}
%                     hdr.video.fullfilename{k} = [fullfilename(1:end-4) ...
%                         '_' sprintf('%i', thisReading) , '.avi'];
%             end
%     end
% end

% % Event A
% fseek(fid, hdr.eventA_area.start, -1);
% MAX_EVENT = 100; 
% for i = 1:MAX_EVENT
%     hdr.eventA(i).description = fread(fid, 1, 'ulong');
%     hdr.eventA(i).begin       = fread(fid, 1, 'ulong');
%     hdr.eventA(i).end         = fread(fid, 1, 'ulong');
% end
% % Event B
% fseek(fid, hdr.eventB_area.start, -1);
% for i = 1:MAX_EVENT
%     hdr.eventB(i).description = fread(fid, 1, 'ulong');
%     hdr.eventB(i).begin       = fread(fid, 1, 'ulong');
%     hdr.eventB(i).end         = fread(fid, 1, 'ulong');
% end

% Trigger
fseek(fid, hdr.trigger_area.start, -1);
MAX_TRIGGER = 8192;
for i = 1:MAX_TRIGGER
    hdr.trigger(i).sample = fread(fid, 1, 'ulong');
    hdr.trigger(i).value = fread(fid, 1, 'ushort');
end

% Detect number of samples based on file size
fseek(fid, hdr.data_offset, -1);
datbeg = ftell(fid);
fseek(fid,0,1);
datend = ftell(fid);
hdr.num_samples = floor((datend - datbeg) / (hdr.num_bytes * hdr.num_channels));
% Close file header
fclose(fid);

% Delete invalid triggers
allTrig = [hdr.trigger.sample];
iDel = find((allTrig > hdr.num_samples) | (allTrig < allTrig(1)));
hdr.trigger(iDel) = [];



%% ===== FILL STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder    = byteorder;
sFile.filename     = DataFile;
sFile.format       = 'EEG-MICROMED';
sFile.prop.sfreq   = double(hdr.sampling_freq);
sFile.prop.times   = [0, hdr.num_samples - 1] ./ sFile.prop.sfreq;
sFile.prop.nAvg    = 1;
sFile.channelflag  = ones(hdr.num_channels,1);
sFile.device       = 'Micromed';
sFile.header       = hdr;
% Comment: short filename
[fPath, fBase, fExt] = bst_fileparts(DataFile);
sFile.comment = fBase;
% Acquisition date
sFile.acq_date = datestr(datenum([hdr.acquisition.year, hdr.acquisition.month, hdr.acquisition.day]), 'dd-mmm-yyyy');


%% ===== CREATE EMPTY CHANNEL FILE =====
nChannels = hdr.num_channels;
ChannelMat = db_template('channelmat');
ChannelMat.Comment = [sFile.device ' channels'];
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, nChannels]);
% Separate channels with different amplitude ranges
allGains = [sFile.header.electrode.unit_gain];
minGain = min(allGains);
% For each channel
for iChan = 1:nChannels
    % Type
    if ~isempty(hdr.electrode(iChan).type)
        ChannelMat.Channel(iChan).Type = hdr.electrode(iChan).type;
    else
        if (sFile.header.electrode(iChan).unit_gain == minGain)
            ChannelMat.Channel(iChan).Type = 'EEG';
        elseif strcmp(sFile.header.electrode(iChan).units, '%')
            ChannelMat.Channel(iChan).Type = 'PERCENT';
        else
            ChannelMat.Channel(iChan).Type = upper(sFile.header.electrode(iChan).units);
        end
    end
    % Name
    chname = strrep(hdr.electrode(iChan).label, '.', '');
    chname(chname == 0) = [];
    if ~isempty(chname)
        ChannelMat.Channel(iChan).Name = chname;
    else
        ChannelMat.Channel(iChan).Type = 'MISC';
        ChannelMat.Channel(iChan).Name = sprintf('E%03d', iChan);
    end
    % Group: useful for SEEG setups
    %%%% TODO
    % Position
    ChannelMat.Channel(iChan).Loc = [sFile.header.electrode(iChan).x; ...
                                     sFile.header.electrode(iChan).y; ...
                                     sFile.header.electrode(iChan).z];
    if isequal(ChannelMat.Channel(iChan).Loc, [0;0;0])
        ChannelMat.Channel(iChan).Loc = [];
    end
    % Comment = reference
    ChannelMat.Channel(iChan).Comment = hdr.electrode(iChan).reference;
    % Fields that are not relevant here
    ChannelMat.Channel(iChan).Orient  = [];
    ChannelMat.Channel(iChan).Weight  = 1;
end


%% ===== FORMAT EVENTS =====
% Create full list of events: notes and triggers
allEvt = cat(2, {hdr.note.text}, cellfun(@(c)sprintf('t%d',c), {hdr.trigger.value}, 'UniformOutput', 0));
allSmp = [hdr.note.sample, hdr.trigger.sample];
% Get all the epochs names
uniqueEvt = unique(allEvt);
% Create one category for each event
for iEvt = 1:length(uniqueEvt)
    % Get all the occurrences
    iOcc = find(strcmpi(allEvt, uniqueEvt{iEvt}));
    % Create event structure
    sFile.events(iEvt).label    = uniqueEvt{iEvt};
    sFile.events(iEvt).times    = (sort(allSmp(iOcc)) - 1) ./ sFile.prop.sfreq; % Samples are 1-based in the file, I guess?
    sFile.events(iEvt).epochs   = ones(size(sFile.events(iEvt).times));
    sFile.events(iEvt).select   = 1;
    sFile.events(iEvt).channels = cell(1, size(sFile.events(iEvt).times, 2));
    sFile.events(iEvt).notes    = cell(1, size(sFile.events(iEvt).times, 2));
end



