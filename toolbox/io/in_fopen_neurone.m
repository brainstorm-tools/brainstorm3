function [sFile, ChannelMat] = in_fopen_neurone(PhaseDir)
% IN_FOPEN_NEURONE: Open NeurOne EEG file (one phase at a time).
%
% USAGE:  [sFile, ChannelMat] = in_fopen_neurone(PhaseDir)

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
% Authors: Francois Tadel, 2015-2018

%% ===== GET FILES =====
% Get folders
if ~isdir(PhaseDir)
    PhaseDir = bst_fileparts(PhaseDir);
end
[SessionDir, PhaseName] = bst_fileparts(PhaseDir);
[tmp, SessionName] = bst_fileparts(SessionDir);
% Build header files names (xml files in parent folder)
SessionFile  = bst_fullfile(SessionDir, 'Session.xml');
ProtocolFile = bst_fullfile(SessionDir, 'Protocol.xml');
if ~file_exist(SessionFile) || ~file_exist(ProtocolFile)
    error(['Could not find header files:' 10 SessionFile 10 ProtocolFile]);
end

% Find all the 1-9.bin files in this directory
binlist = dir(bst_fullfile(PhaseDir, '*.bin'));
binlist = binlist(ismember({binlist.name}, {'1.bin', '2.bin', '3.bin', '4.bin', '5.bin', '6.bin', '7.bin', '8.bin', '9.bin'}));
% TODO: Add support for long NeurOne recordings with multiple .bin files
if (length(binlist) > 1)
    error(['The support for long NeurOne files with multiple .bin files is not available yet.' 10 'Please post a message on the Brainstorm user forum to ask for this feature.']);
elseif isempty(binlist)
    error('Missing 1.bin file in session folder.');
end
% Only one .bin file 
hdr.bin_files = {bst_fullfile(PhaseDir, binlist(1).name)};
hdr.bin_sizes = [binlist.bytes];

% Get events file
EventsFile = bst_fullfile(PhaseDir, 'events.bin');
if ~file_exist(EventsFile)
    EventsFile = [];
else
    fInfo = dir(EventsFile);
    if (fInfo.bytes < 88)
        EventsFile = [];
        hdr.nEvents = 0;
    else
        hdr.nEvents = floor(fInfo.bytes / 88);
    end
end


%% ===== READ HEADER =====
hdr.Session = in_xml(SessionFile);
hdr.Protocol = in_xml(ProtocolFile);
% Extract basic information
hdr.nChannels = numel(hdr.Protocol.DataSetProtocol.TableInput);
hdr.sfreq = str2double(hdr.Protocol.DataSetProtocol.TableProtocol.ActualSamplingFrequency.text);
% Compute the total number of time samples (int32)
hdr.nSamples = floor(sum(hdr.bin_sizes) / hdr.nChannels / 4);
% Start time
hdr.start_datenum = datenum(hdr.Session.DataSetSession.TableSession.StartDateTime.text(1:end-6),'yyyy-mm-ddTHH:MM:SS');
hdr.start_string  = datestr(hdr.start_datenum,'yyyy-mm-dd HH:MM:SS');


%% ===== CREATE CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'NeurOne channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, hdr.nChannels]);
% Re-order channels
sTableInput = hdr.Protocol.DataSetProtocol.TableInput;
sInputNumber = [sTableInput.InputNumber];
[tmp, I] = sort(str2double({sInputNumber.text}));
sTableInput = sTableInput(I);
% For each channel
for i = 1:hdr.nChannels
    ChannelMat.Channel(i).Name    = sTableInput(i).Name.text;
    ChannelMat.Channel(i).Type    = sTableInput(i).SignalType.text;
    ChannelMat.Channel(i).Loc     = [0; 0; 0];
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Weight  = 1;
    ChannelMat.Channel(i).Comment = [];
end
% Calibration
sRangeMinimum = [sTableInput.RangeMinimum];
sRangeMaximum = [sTableInput.RangeMaximum];
sRangeAsCalibratedMinimum = [sTableInput.RangeAsCalibratedMinimum];
sRangeAsCalibratedMaximum = [sTableInput.RangeAsCalibratedMaximum];
hdr.calibration.rawMin = str2double({sRangeMinimum.text});
hdr.calibration.rawMax = str2double({sRangeMaximum.text});
hdr.calibration.calMin = str2double({sRangeAsCalibratedMinimum.text});
hdr.calibration.calMax = str2double({sRangeAsCalibratedMaximum.text});


%% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder  = 'l';
sFile.filename   = PhaseDir;
sFile.format     = 'EEG-NEURONE';
sFile.device     = 'NeuroOne';
sFile.header     = hdr;
sFile.comment    = [SessionName, '-', PhaseName];
sFile.condition  = [SessionName, '-', PhaseName];
% Consider that the sampling rate of the file is the sampling rate of the first signal
sFile.prop.sfreq = hdr.sfreq;
sFile.prop.times = [0, hdr.nSamples - 1] ./ sFile.prop.sfreq;
sFile.prop.nAvg  = 1;
% No info on bad channels
sFile.channelflag = ones(hdr.nChannels, 1);
% Acquisition date
try
    sFile.acq_date = str_date(hdr.Session.DataSetSession.TableSession.StartDateTime.text(1:10));
catch
end

%% ===== EVENT MARKERS =====
if ~isempty(EventsFile)
    % === READ EVENTS FILE ===
    % Open file
    fid = fopen(EventsFile, 'rb');
    % Read events one by one (structures of 88 bytes)
    ev = repmat(struct(), 1, hdr.nEvents);
    for i = 1:hdr.nEvents
        ev(i).Revision          = fread(fid,1,'int32');
        ev(i).Unused1           = fread(fid,1,'int32');
        ev(i).Type              = fread(fid,1,'int32');
        ev(i).SourcePort        = fread(fid,1,'int32');
        ev(i).ChannelNumber     = fread(fid,1,'int32');
        ev(i).Code              = fread(fid,1,'int32');
        ev(i).StartSampleIndex  = fread(fid,1,'uint64');
        ev(i).StopSampleIndex   = fread(fid,1,'uint64');
        ev(i).DescriptionLength = fread(fid,1,'uint64');
        ev(i).DescriptionOffset = fread(fid,1,'uint64');
        ev(i).DataLength        = fread(fid,1,'uint64');
        ev(i).DataOffset        = fread(fid,1,'uint64');
        ev(i).TimeStamp         = fread(fid,1,'double');
        ev(i).MainUnitIndex     = fread(fid,1,'int32');
        ev(i).Unused2           = fread(fid,1,'int32');
        % Build event label
        switch ev(i).SourcePort
            case 0,    ev(i).Label = 'U'; % 'Unknown';
            case 1,    ev(i).Label = 'A';
            case 2,    ev(i).Label = 'B';
            case 3,    ev(i).Label = 'E'; % 'EightBit';
            case 4,    ev(i).Label = 'S'; % 'Syncbox Button';
            case 5,    ev(i).Label = 'X'; % 'SyncBox EXT';
            otherwise, ev(i).Label = 'U'; % 'Unknown';
        end
        switch ev(i).Type
            case 0,    ev(i).Label = [ev(i).Label, 'U'];
            case 1,    ev(i).Label = [ev(i).Label, 'S'];
            case 2,    ev(i).Label = [ev(i).Label, 'V'];
            case 3,    ev(i).Label = [ev(i).Label, 'M'];
            case 4,    % ev(i).Label = [ev(i).Label, num2str(Code)];
            case 5,    ev(i).Label = [ev(i).Label, 'O'];
            case 6,    ev(i).Label = [ev(i).Label, 'C'];
            otherwise, ev(i).Label = [ev(i).Label, 'U'];
        end
        ev(i).Label = [ev(i).Label, num2str(ev(i).Code)];
    end
    % Close events file
    fclose(fid);

    % === CONVERT TO BRAINSTORM FORMAT ===
    % Get list of events
    allLabels = {ev.Label};
    [uniqueEvt, iUnique] = unique(allLabels);
    uniqueEvt = allLabels(sort(iUnique));
    % Initialize list of events
    events = repmat(db_template('event'), 1, length(uniqueEvt));
    % Format list
    for iEvt = 1:length(uniqueEvt)
        % Find list of occurences of this event
        iOcc = find(strcmpi(allLabels, uniqueEvt{iEvt}));
        % Fill events structure
        events(iEvt).label      = uniqueEvt{iEvt};
        events(iEvt).color      = [];
        events(iEvt).reactTimes = [];
        events(iEvt).select     = 1;
        events(iEvt).times      = [ev(iOcc).StartSampleIndex] ./ sFile.prop.sfreq;
        events(iEvt).epochs     = ones(1, length(events(iEvt).times));   % Epoch: set as 1 for all the occurrences
        events(iEvt).channels   = [];
        events(iEvt).notes      = [];
    end
    % Import this list
    sFile = import_events(sFile, [], events);
end


