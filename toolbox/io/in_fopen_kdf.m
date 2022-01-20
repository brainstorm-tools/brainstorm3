function [sFile, ChannelMat] = in_fopen_kdf(DataFile)
% IN_FOPEN_KDF: Open a KRISSMEG KDF file (very similar to BDF).
%
% USAGE:  [sFile, ChannelMat] = in_fopen_kdf(DataFile)

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
% Authors: Francois Tadel, 2014-2018
        

%% ===== READ OTHER FILES =====
% Split .kdf filename
[fPath, fBase, fExt] = bst_fileparts(DataFile);

% Sensor file
SensorFile = bst_fullfile(fPath, [fBase, '.chn']);
if ~file_exist(SensorFile)
    disp('KDF> Warning: Sensor file .chn was not found.');
    SensorDat = [];
else
    SensorDat = load(SensorFile, '-ASCII');
end

% Digitizer file
DigitizerFile = bst_fullfile(fPath, 'Digitizer.txt');
if ~file_exist(DigitizerFile)
    disp('KDF> Warning: File Digitizer.txt was not found.');
    DigitizerFile = [];    
end

% Trigger file
TriggerFile = bst_fullfile(fPath, [fBase, '.trg']);
if ~file_exist(TriggerFile)
    disp('KDF> Warning: Trigger file .trg was not found. Reading status line...');
    TriggerFile = [];
end

    
%% ===== READ KDF HEADER =====
% Open file
fid = fopen(DataFile, 'r', 'ieee-le');
if (fid == -1)
    error('Could not open file');
end
% Read all fields
hdr.version    = fread(fid, [1  8], 'uint8=>char');  % Version of this data format ([255 'KRISS  '])
hdr.patient_id = fread(fid, [1 80], '*char');  % Local patient identification
hdr.rec_id     = fread(fid, [1 80], '*char');  % Local recording identification
hdr.startdate  = fread(fid, [1  8], '*char');  % Startdate of recording (dd.mm.yy)
hdr.starttime  = fread(fid, [1  8], '*char');  % Starttime of recording (hh.mm.ss) 
hdr.hdrlen     = str2double(fread(fid, [1 8], '*char'));  % Number of bytes in header record 
hdr.unknown1   = fread(fid, [1 44], '*char');             % Reserved ('24BIT')
hdr.nrec       = str2double(fread(fid, [1 8], '*char'));  % Number of data records (-1 if unknown)
hdr.reclen     = str2double(fread(fid, [1 8], '*char'));  % Duration of a data record, in seconds 
hdr.nsignal    = str2double(fread(fid, [1 4], '*char'));  % Number of signals in data record
% Check file format
if (uint8(hdr.version(1)) ~= uint8(255)) || ~isequal(hdr.version(2:6), 'KRISS')
    error('This is not a valid KRISS MEG .kdf file.');
end
% Check file integrity
if isnan(hdr.nsignal) || isempty(hdr.nsignal) || (hdr.nsignal ~= round(hdr.nsignal)) || (hdr.nsignal < 0)
    error('File header is corrupted.');
end
% Read values for each nsignal
for i = 1:hdr.nsignal
    hdr.signal(i).label = fread(fid, [1 16], '*char');   % 3 first char: current index,  Rest: name of the sensor
end
for i = 1:hdr.nsignal
    hdr.signal(i).type = strtrim(fread(fid, [1 40], '*char'));    % DIFFERENT FROM BDF
end
for i = 1:hdr.nsignal
    hdr.signal(i).unit = strtrim(fread(fid, [1 8], '*char'));
end
for i = 1:hdr.nsignal
    hdr.signal(i).physical_min = str2double(fread(fid, [1 8], '*char'));
end
for i = 1:hdr.nsignal
    hdr.signal(i).physical_max = str2double(fread(fid, [1 8], '*char'));
end
for i = 1:hdr.nsignal
    hdr.signal(i).digital_min = str2double(fread(fid, [1 8], '*char'));
end
for i = 1:hdr.nsignal
    hdr.signal(i).digital_max = str2double(fread(fid, [1 8], '*char'));
end
% Unused field   (DIFFERENT FROM BDF)
hdr.filters = strtrim(fread(fid, [1 80], '*char'));
% Read number of samples  (DIFFERENT FROM BDF)
hdr.nsamples = str2double(fread(fid, [1 8], '*char'));
% Read last signals field
for i = 1:hdr.nsignal
    hdr.signal(i).unknown2 = fread(fid, [1 32], '*char');
end
% Close file
fclose(fid);


%% ===== RECONSTRUCT INFO =====
% Individual signal gain
for i = 1:hdr.nsignal
    switch (hdr.signal(i).unit)
        case 'mV',                        hdr.signal(i).gain = 1e3;
        case {'uV', char([166 204 86])},  hdr.signal(i).gain = 1e6;
        case 'pT',                        hdr.signal(i).gain = 1e12;
        otherwise,                        hdr.signal(i).gain = 1;
    end
    % Error: The number of samples is not specified
    if isempty(hdr.nsamples)
        error('The number of samples is not specified.');
    end
    hdr.sfreq = hdr.nsamples ./ hdr.reclen;
end
% Preform some checks
if (hdr.nrec == -1)
    error('Cannot handle files where the number of recordings is unknown.');
end
% Find annotations channel
iStatusChan = find(strcmpi(strtrim({hdr.signal.label}), 'Status'), 1);         % Only one "Status" channel allowed in KDF


%% ===== CREATE CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'KRISS MEG channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, hdr.nsignal]);
% For each channel
for i = 1:hdr.nsignal
    % MEG channel
    if isequal(hdr.signal(i).type, 'Axial Gradiometer_50')
        % Fix channel labels: "xxxyyy", xxx=index of the channel in the data file, yyy=label of the channel
        hdr.signal(i).index = strtrim(hdr.signal(i).label(1:3));
        hdr.signal(i).label = strtrim(hdr.signal(i).label(4:end));
        % MEG channel
        ChannelMat.Channel(i).Name    = hdr.signal(i).label;
        ChannelMat.Channel(i).Type    = 'MEG';
        ChannelMat.Channel(i).Comment = 'KRISS system gradiometer size = 20.00  mm base = 50.00  mm';
    % Other channels
    else
        % Fix channel labels
        hdr.signal(i).index = -1;
        hdr.signal(i).label = strtrim(hdr.signal(i).label);
        ChannelMat.Channel(i).Name = hdr.signal(i).label;
        % Annotation channel
        if ~isempty(iStatusChan) && (i == iStatusChan)
            ChannelMat.Channel(i).Name = 'Status';
            ChannelMat.Channel(i).Type = 'KDF';
        % Regular channels
        elseif isempty(hdr.signal(i).type)
            ChannelMat.Channel(i).Type = 'EEG';
        elseif (length(hdr.signal(i).type) == 3)
            ChannelMat.Channel(i).Type = hdr.signal(i).type(hdr.signal(i).type ~= ' ');
        else
            ChannelMat.Channel(i).Type = 'Misc';
        end
    end
    ChannelMat.Channel(i).Loc    = [0; 0; 0];
    ChannelMat.Channel(i).Orient = [];
    ChannelMat.Channel(i).Weight = 1;
end
% If there are only "Misc" and no "EEG" channels: rename to "EEG"
iMisc = find(strcmpi({ChannelMat.Channel.Type}, 'Misc'));
iEeg  = find(strcmpi({ChannelMat.Channel.Type}, 'EEG'));
if ~isempty(iMisc) && isempty(iEeg)
    [ChannelMat.Channel(iMisc).Type] = deal('EEG');
end

%% ===== ADD MEG POSITIONS =====
iChan = channel_find(ChannelMat.Channel, 'MEG');
% Position / orientation
if ~isempty(SensorDat)
    % Split the matrix in sensor and 
    LocAll    = SensorDat(1:size(SensorDat,1)/2, :);
    OrientAll = SensorDat((size(SensorDat,1)/2+1):end, :);
    % Normalize orientation vector
    OrientAll = bst_bsxfun(@rdivide, OrientAll, sqrt(sum(OrientAll.^2,2)));
    % Apply to every sensor
    for i = 1:length(iChan)
        ind = str2double(ChannelMat.Channel(i).Name);
        if ~isempty(ind) && ~isnan(ind) && (ind <= size(LocAll,1))
            ChannelMat.Channel(i).Loc    = LocAll(ind,:)' ./ 1000;
            ChannelMat.Channel(i).Orient = OrientAll(ind,:)';
        end
    end
end
% Add definition of sensors
ChannelMat.Channel = ctf_add_coil_defs(ChannelMat.Channel, 'KRISS');


%% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder  = 'l';
sFile.filename   = DataFile;
sFile.format     = 'KDF';
sFile.device     = 'KRISSMEG';
sFile.header     = hdr;
% Comment: short filename
[tmp__, sFile.comment, tmp__] = bst_fileparts(DataFile);
% Consider that the sampling rate of the file is the sampling rate of the first signal
sFile.prop.sfreq = hdr.sfreq;
sFile.prop.times = [0, hdr.nsamples * hdr.nrec - 1] ./ sFile.prop.sfreq;
sFile.prop.nAvg  = 1;
% No info on bad channels
sFile.channelflag = ones(hdr.nsignal,1);
% Acquisition date
sFile.acq_date = str_date(hdr.startdate);


%% ===== READ DIGITIZER FILE =====
if ~isempty(DigitizerFile)
    % Open file
    fid = fopen(DigitizerFile, 'r');
    % Read values
    DigData = textscan(fid, '%f %f %f %s');
    % Close file
    fclose(fid);
    % Process digitized head points
    if ~isempty(DigData)
        for i = 1:length(DigData{1})
            ChannelMat.HeadPoints.Loc(:,i) = [DigData{1}(i); DigData{2}(i); DigData{3}(i)] ./ 1000;
            ChannelMat.HeadPoints.Label{i} = DigData{4}{i};
            if strcmpi(ChannelMat.HeadPoints.Label{i}, 'NZ')
                ChannelMat.HeadPoints.Type{i}  = 'CARDINAL';
                ChannelMat.SCS.NAS = ChannelMat.HeadPoints.Loc(:,i)';
            elseif strcmpi(ChannelMat.HeadPoints.Label{i}, 'LPA')
                ChannelMat.HeadPoints.Type{i}  = 'CARDINAL';
                ChannelMat.SCS.LPA = ChannelMat.HeadPoints.Loc(:,i)';
            elseif strcmpi(ChannelMat.HeadPoints.Label{i}, 'RPA')
                ChannelMat.HeadPoints.Type{i}  = 'CARDINAL';
                ChannelMat.SCS.RPA = ChannelMat.HeadPoints.Loc(:,i)';
            else
                ChannelMat.HeadPoints.Type{i}  = 'EXTRA';
            end
        end
    end
end


%% ===== READ EVENTS =====
% Read events from trigger file
if ~isempty(TriggerFile)
    sFile.events = in_events_kdf(sFile, TriggerFile);
% Read events from status channel
elseif ~isempty(iStatusChan)
    % Set reading options
    EventsTrackMode = 'ask';
    % Ask how to read the events
    events = process_evt_read('Compute', sFile, ChannelMat, ChannelMat.Channel(iStatusChan).Name, EventsTrackMode);
    if isequal(events, -1)
        sFile = [];
        ChannelMat = [];
        return;
    end
    % Report the events in the file structure
    sFile.events = events;
    % Remove the 'Status: ' string in front of the events
    for i = 1:length(sFile.events)
        sFile.events(i).label = strrep(sFile.events(i).label, 'Status: ', '');
    end
end






