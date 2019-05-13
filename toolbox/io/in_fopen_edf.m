function [sFile, ChannelMat] = in_fopen_edf(DataFile, ImportOptions)
% IN_FOPEN_EDF: Open a BDF/EDF file (continuous recordings)
%
% USAGE:  [sFile, ChannelMat] = in_fopen_edf(DataFile, ImportOptions)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2012-2018
        

% Parse inputs
if (nargin < 2) || isempty(ImportOptions)
    ImportOptions = db_template('ImportOptions');
end


%% ===== READ HEADER =====
% Open file
fid = fopen(DataFile, 'r', 'ieee-le');
if (fid == -1)
    error('Could not open file');
end
% Read all fields
hdr.version    = fread(fid, [1  8], 'uint8=>char');  % Version of this data format ('0       ' for EDF, [255 'BIOSEMI'] for BDF)
hdr.patient_id = fread(fid, [1 80], '*char');  % Local patient identification
hdr.rec_id     = fread(fid, [1 80], '*char');  % Local recording identification
hdr.startdate  = fread(fid, [1  8], '*char');  % Startdate of recording (dd.mm.yy)
hdr.starttime  = fread(fid, [1  8], '*char');  % Starttime of recording (hh.mm.ss) 
hdr.hdrlen     = str2double(fread(fid, [1 8], '*char'));  % Number of bytes in header record 
hdr.unknown1   = fread(fid, [1 44], '*char');             % Reserved ('24BIT' for BDF)
hdr.nrec       = str2double(fread(fid, [1 8], '*char'));  % Number of data records (-1 if unknown)
hdr.reclen     = str2double(fread(fid, [1 8], '*char'));  % Duration of a data record, in seconds 
hdr.nsignal    = str2double(fread(fid, [1 4], '*char'));  % Number of signals in data record
% Check file integrity
if isnan(hdr.nsignal) || isempty(hdr.nsignal) || (hdr.nsignal ~= round(hdr.nsignal)) || (hdr.nsignal < 0)
    error('File header is corrupted.');
end
% Read values for each nsignal
for i = 1:hdr.nsignal
    hdr.signal(i).label = strtrim(fread(fid, [1 16], '*char'));
end
for i = 1:hdr.nsignal
    hdr.signal(i).type = strtrim(fread(fid, [1 80], '*char'));
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
for i = 1:hdr.nsignal
    hdr.signal(i).filters = strtrim(fread(fid, [1 80], '*char'));
end
for i = 1:hdr.nsignal
    hdr.signal(i).nsamples = str2num(fread(fid, [1 8], '*char'));
end
for i = 1:hdr.nsignal
    hdr.signal(i).unknown2 = fread(fid, [1 32], '*char');
end
% Unknown record size, determine correct nrec
if (hdr.nrec == -1)
    datapos = ftell(fid);
    fseek(fid, 0, 'eof');
    endpos = ftell(fid);
    hdr.nrec = floor((endpos - datapos) / (sum([hdr.signal.nsamples]) * 2));
end
% Close file
fclose(fid);


%% ===== RECONSTRUCT INFO =====
% Individual signal gain
for i = 1:hdr.nsignal
    % Interpet units
    switch (hdr.signal(i).unit)
        case 'mV',                        unit_gain = 1e3;
        case {'uV', char([166 204 86])},  unit_gain = 1e6;
        otherwise,                        unit_gain = 1;
    end
    % Check min/max values
    if isempty(hdr.signal(i).digital_min) || isnan(hdr.signal(i).digital_min)
        disp(['EDF> Warning: The digitial minimum is not set for channel "' hdr.signal(i).label '".']);
        hdr.signal(i).digital_min = -2^15;
    end
    if isempty(hdr.signal(i).digital_max) || isnan(hdr.signal(i).digital_max)
        disp(['EDF> Warning: The digitial maximum is not set for channel "' hdr.signal(i).label '".']);
        hdr.signal(i).digital_max = -2^15;
    end
    if isempty(hdr.signal(i).physical_min) || isnan(hdr.signal(i).physical_min)
        disp(['EDF> Warning: The physical minimum is not set for channel "' hdr.signal(i).label '".']);
        hdr.signal(i).physical_min = hdr.signal(i).digital_min;
    end
    if isempty(hdr.signal(i).physical_max) || isnan(hdr.signal(i).physical_max)
        disp(['EDF> Warning: The physical maximum is not set for channel "' hdr.signal(i).label '".']);
        hdr.signal(i).physical_max = hdr.signal(i).digital_max;
    end
    if (hdr.signal(i).physical_min >= hdr.signal(i).physical_max)
        disp(['EDF> Warning: Physical maximum larger than minimum for channel "' hdr.signal(i).label '".']);
        hdr.signal(i).physical_min = hdr.signal(i).digital_min;
        hdr.signal(i).physical_max = hdr.signal(i).digital_max;
    end
    % Calculate and save channel gain
    hdr.signal(i).gain   = unit_gain ./ (hdr.signal(i).physical_max - hdr.signal(i).physical_min) .* (hdr.signal(i).digital_max - hdr.signal(i).digital_min);
    hdr.signal(i).offset = hdr.signal(i).physical_min ./ unit_gain - hdr.signal(i).digital_min ./ hdr.signal(i).gain;
    % Error: The number of samples is not specified
    if isempty(hdr.signal(i).nsamples)
        % If it is not the first electrode: try to use the previous one
        if (i > 1)
            disp(['EDF> Warning: The number of samples is not specified for channel "' hdr.signal(i).label '".']);
            hdr.signal(i).nsamples = hdr.signal(i-1).nsamples;
        else
            error(['The number of samples is not specified for channel "' hdr.signal(i).label '".']);
        end
    end
    hdr.signal(i).sfreq = hdr.signal(i).nsamples ./ hdr.reclen;
end
% Find annotations channel
iAnnotChans = find(strcmpi({hdr.signal.label}, 'EDF Annotations'));  % Mutliple "EDF Annotation" channels allowed in EDF+
iStatusChan = find(strcmpi({hdr.signal.label}, 'Status'), 1);        % Only one "Status" channel allowed in BDF
iOtherChan = setdiff(1:hdr.nsignal, [iAnnotChans iStatusChan]);
% % Remove channels with lower sampling rates
% iIgnoreChan = find([hdr.signal(iOtherChan).sfreq] < max([hdr.signal(iOtherChan).sfreq]));    % Ignore all the channels with lower sampling rate
% if ~isempty(iIgnoreChan)
%     iOtherChan = setdiff(iOtherChan, iIgnoreChan);
% end
% Get all the other channels
if isempty(iOtherChan)
    error('This file does not contain any data channel.');
end
% Read events preferencially from the EDF Annotations track
if ~isempty(iAnnotChans)
    iEvtChans = iAnnotChans;
elseif ~isempty(iStatusChan)
    iEvtChans = iStatusChan;
else
    iEvtChans = [];
end
% % Detect channels with inconsistent sampling frenquency
% iErrChan = find([hdr.signal(iOtherChan).sfreq] ~= hdr.signal(iOtherChan(1)).sfreq);
% iErrChan = setdiff(iErrChan, iAnnotChans);
% if ~isempty(iErrChan)
%     error('Files with mixed sampling rates are not supported yet.');
% end
% Detect interrupted signals (time non-linear)
hdr.interrupted = ischar(hdr.unknown1) && (length(hdr.unknown1) >= 5) && isequal(hdr.unknown1(1:5), 'EDF+D');
if hdr.interrupted
    if ImportOptions.DisplayMessages
        [res, isCancel] = java_dialog('question', ...
            ['Interrupted EDF file ("EDF+D") detected. It is recommended to convert it' 10 ...
            'to a continuous ("EDF+C") file first. Do you want to continue reading this' 10 ...
            'file as continuous and attempt to fix the timing of event markers?' 10 ...
            'NOTE: This may not work as intended, use at your own risk!']);
        hdr.fixinterrupted = ~isCancel && strcmpi(res, 'yes');
    else
        hdr.fixinterrupted = 1;
    end
    if ~hdr.fixinterrupted
        warning(['Interrupted EDF file ("EDF+D"): requires conversion to "EDF+C". ' 10 ...
             'Brainstorm will read this file as a continuous file ("EDF+C"), the timing of the samples after the first discontinuity will be wrong.' 10 ...
             'This may not cause any major problem unless there are time markers in the file, they might be inaccurate in all the segments >= 2.']);
    end
end


%% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder  = 'l';
sFile.filename   = DataFile;
if (uint8(hdr.version(1)) == uint8(255))
    sFile.format = 'EEG-BDF';
    sFile.device = 'BDF';
else
    sFile.format = 'EEG-EDF';
    sFile.device = 'EDF';
end
sFile.header = hdr;
% Comment: short filename
[tmp__, sFile.comment, tmp__] = bst_fileparts(DataFile);
% No info on bad channels
sFile.channelflag = ones(hdr.nsignal,1);
% Acquisition date
sFile.acq_date = str_date(hdr.startdate);



%% ===== PROCESS CHANNEL NAMES/TYPES =====
% Try to split the channel names in "TYPE NAME"
SplitType = repmat({''}, 1, hdr.nsignal);
SplitName = repmat({''}, 1, hdr.nsignal);
for i = 1:hdr.nsignal
    % Removing trailing dots (eg. "Fc5." instead of "FC5", as in: https://www.physionet.org/pn4/eegmmidb/)
    if (hdr.signal(i).label(end) == '.') && (length(hdr.signal(i).label) > 1)
        hdr.signal(i).label(end) = [];
        if (hdr.signal(i).label(end) == '.') && (length(hdr.signal(i).label) > 1)
            hdr.signal(i).label(end) = [];
            if (hdr.signal(i).label(end) == '.') && (length(hdr.signal(i).label) > 1)
                hdr.signal(i).label(end) = [];
            end
        end
    end
    % Remove extra spaces
    signalLabel = strrep(hdr.signal(i).label, ' - ', '-');
    % Find space chars (label format "Type Name")
    iSpace = find(signalLabel == ' ');
    % Only if there is one space only
    if (length(iSpace) == 1) && (iSpace >= 3)
        SplitName{i} = signalLabel(iSpace+1:end);
        SplitType{i} = signalLabel(1:iSpace-1);
    % Accept also 2 spaces
    elseif (length(iSpace) == 2) && (iSpace(1) >= 3)
        SplitName{i} = strrep(signalLabel(iSpace(1)+1:end), ' ', '_');
        SplitType{i} = signalLabel(1:iSpace(1)-1);
    end
end
% Remove the classification if it makes some names non unique
uniqueNames = unique(SplitName);
for i = 1:length(uniqueNames)
    if ~isempty(uniqueNames{i})
        iName = find(strcmpi(SplitName, uniqueNames{i}));
        if (length(iName) > 1)
            [SplitName{iName}] = deal('');
            [SplitType{iName}] = deal('');
        end
    end
end


%% ===== CREATE EMPTY CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = [sFile.device ' channels'];
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, hdr.nsignal]);
chRef = {};
% For each channel
for i = 1:hdr.nsignal
    % If is the annotation channel
    if ~isempty(iAnnotChans) && ismember(i, iAnnotChans)
        ChannelMat.Channel(i).Type = 'EDF';
        ChannelMat.Channel(i).Name = 'Annotations';
    elseif ~isempty(iStatusChan) && (i == iStatusChan)
        ChannelMat.Channel(i).Type = 'BDF';
        ChannelMat.Channel(i).Name = 'Status';
    % Regular channels
    else
        % If there is a pair name/type already detected
        if ~isempty(SplitName{i}) && ~isempty(SplitType{i})
            ChannelMat.Channel(i).Name = SplitName{i};
            ChannelMat.Channel(i).Type = SplitType{i};
        else
            % Channel name
            ChannelMat.Channel(i).Name = hdr.signal(i).label(hdr.signal(i).label ~= ' ');
            % Channel type
            if ~isempty(hdr.signal(i).type)
                if (length(hdr.signal(i).type) == 3)
                    ChannelMat.Channel(i).Type = hdr.signal(i).type(hdr.signal(i).type ~= ' ');
                elseif isequal(hdr.signal(i).type, 'Active Electrode') || isequal(hdr.signal(i).type, 'AgAgCl electrode')
                    ChannelMat.Channel(i).Type = 'EEG';
                else
                    ChannelMat.Channel(i).Type = 'Misc';
                end
            else
                ChannelMat.Channel(i).Type = 'EEG';
            end
        end
        % Extract reference name (at the end of the channel name, separated with a "-", eg. "-REF")
        iDash = find(ChannelMat.Channel(i).Name == '-');
        if ~isempty(iDash) && (iDash(end) < length(ChannelMat.Channel(i).Name))
            chRef{end+1} = ChannelMat.Channel(i).Name(iDash(end):end);
        end
    end
    ChannelMat.Channel(i).Loc     = [0; 0; 0];
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Weight  = 1;
    % ChannelMat.Channel(i).Comment = hdr.signal(i).type;
end

% If the same reference is indicated for all the channels: remove it
if (length(chRef) >= 2) 
    % Get the shortest reference tag
    lenRef = cellfun(@length, chRef);
    minLen = min(lenRef);
    % Check if all the ref names are equal (up to the max length - some might be cut because the channel name is too long)
    if all(cellfun(@(c)strcmpi(c(1:minLen), chRef{1}(1:minLen)), chRef))
        % Remove the reference tag from all the channel names
        for i = 1:length(ChannelMat.Channel)
            ChannelMat.Channel(i).Name = strrep(ChannelMat.Channel(i).Name, chRef{1}, '');
            ChannelMat.Channel(i).Name = strrep(ChannelMat.Channel(i).Name, chRef{1}(1:minLen), '');
        end
    end
end

% If there are only "Misc" and no "EEG" channels: rename to "EEG"
iMisc = find(strcmpi({ChannelMat.Channel.Type}, 'Misc'));
iEeg  = find(strcmpi({ChannelMat.Channel.Type}, 'EEG'));
if ~isempty(iMisc) && isempty(iEeg)
    [ChannelMat.Channel(iMisc).Type] = deal('EEG');
    iEeg = iMisc;
end


%% ===== DETECT MULTIPLE SAMPLING RATES =====
% Use the first "EEG" channel as the reference sampling rate (or the first channel if no "EEG" channels available)
if ~isempty(iEeg) && ismember(iEeg(1), iOtherChan)
    iChanFreqRef = iEeg(1);
else
    iChanFreqRef = iOtherChan(1);
end
% Mark as bad channels with sampling rates different from EEG
iChanWrongRate = find([sFile.header.signal.sfreq] ~= sFile.header.signal(iChanFreqRef).sfreq);
iChanWrongRate = intersect(iChanWrongRate, iOtherChan);
if ~isempty(iChanWrongRate)
    sFile.channelflag(iChanWrongRate) = -1;
end

% Consider that the sampling rate of the file is the sampling rate of the first signal
sFile.prop.sfreq = hdr.signal(iChanFreqRef).sfreq;
sFile.prop.times = [0, hdr.signal(iChanFreqRef).nsamples * hdr.nrec - 1] ./ sFile.prop.sfreq;
sFile.prop.nAvg  = 1;




%% ===== READ EDF ANNOTATION CHANNEL =====
if ~isempty(iEvtChans) % && ~isequal(ImportOptions.EventsMode, 'ignore')
    % Set reading options
    ImportOptions.ImportMode = 'Time';
    ImportOptions.UseSsp     = 0;
    ImportOptions.UseCtfComp = 0;
    % Read EDF annotations
    if strcmpi(sFile.format, 'EEG-EDF')
        evtList = {};
        % In EDF+, the first annotation channel has epoch time stamps (EDF
        % calls epochs records).  So read all annotation channels per epoch.
        for irec = 1:hdr.nrec
            for ichan = 1:length(iEvtChans)
                bst_progress('text', sprintf('Reading annotations... [%d%%]', round((ichan + (irec-1)*length(iEvtChans))/length(iEvtChans)/hdr.nrec*100)));
                % Sample indices for the current epoch (=record)
                SampleBounds = [irec-1,irec] * sFile.header.signal(iEvtChans(ichan)).nsamples - [0,1];
                % Read record
                F = char(in_fread(sFile, ChannelMat, 1, SampleBounds, iEvtChans(ichan), ImportOptions));
                % Split after removing the 0 values
                Fsplit = str_split(F(F~=0), 20);
                if isempty(Fsplit)
                    continue;
                end
                if ichan == 1
                    % Get record time stamp
                    t0_rec = str2double(char(Fsplit{1}));
                    if (irec == 1)
                        t0_file = t0_rec;
                    % Find discontinuities
                    elseif abs(t0_rec - prev_rec - hdr.reclen) > 1e-8
                        % Brainstorm fills partial/interrupted records with zeros
                        bstTime = prev_rec + hdr.reclen;
                        timeDiff = bstTime - t0_rec;
                        % If we want to fix timing, apply skip to initial timestamp
                        if hdr.fixinterrupted
                            t0_file = t0_file - timeDiff;
                        end
                        % Warn user of discontinuity
                        if timeDiff > 0
                            expectMsg = 'blank data';
                        else
                            expectMsg = 'skipped data';
                        end
                        startTime = min(t0_rec - t0_file - [0, timeDiff]); % before and after t0_file adjustment
                        endTime  = max(t0_rec - t0_file - [0, timeDiff]);
                        fprintf('WARNING: Found discontinuity between %.3fs and %.3fs, expect %s in between.\n', startTime, endTime, expectMsg);
                        % Create event for users information
                        if timeDiff < 0
                            endTime = startTime; % no extent in this case, there is skipped time.
                        end
                        evtList(end+1,:) = {'EDF+D Discontinuity', [startTime; endTime]};
                    end
                    prev_rec = t0_rec;
                end
                
                %% FIXME: There can be multiple text annotations (separated by 20) for a single onset/duration.
                %% The zero characters should not be removed above as they delimit the TALs (Time-stamped Annotations Lists)
                % If there is an initial time: 3 values (ex: "+44.00000+44.47200Event1Event2)
                if (mod(length(Fsplit),2) == 1) && (length(Fsplit) >= 3)
                    iStart = 2;
                % If there is no initial time: 2 values (ex: "+44.00000Epoch1)
                elseif (mod(length(Fsplit),2) == 0)
                    iStart = 1;
                else
                    continue;
                end
                % If there is information on this channel
                for iAnnot = iStart:2:length(Fsplit)
                    % If there are no 2 values, skip
                    if (iAnnot == length(Fsplit))
                        break;
                    end
                    % Split time in onset/duration
                    t_dur = str_split(Fsplit{iAnnot}, 21);
                    % Get time and label
                    t = str2double(t_dur{1});
                    label = Fsplit{iAnnot+1};
                    if (length(t_dur) > 1)
                        duration = str2double(t_dur{2});
                        % Exclude 1-sample long events
                        if (round(duration .* sFile.prop.sfreq) <= 1)
                            duration = 0;
                        end
                    else
                        duration = 0;
                    end
                    if isempty(t) || isnan(t) || isempty(label) || (~isempty(duration) && isnan(duration))
                        continue;
                    end
                    % Add to list of read events
                    evtList(end+1,:) = {label, (t-t0_file) + [0;duration]};
                end
            end
        end
        
        % If there are events: create a create an events structure
        if ~isempty(evtList)
            % Initialize events list
            sFile.events = repmat(db_template('event'), 0);
            % Events list
            [uniqueEvt, iUnique] = unique(evtList(:,1));
            uniqueEvt = evtList(sort(iUnique),1);
            % Build events list
            for iEvt = 1:length(uniqueEvt)
                % Find all the occurrences of this event
                iOcc = find(strcmpi(uniqueEvt{iEvt}, evtList(:,1)));
                % Concatenate all times
                t = [evtList{iOcc,2}];
                % If second row is equal to the first one (no extended events): delete it
                if all(t(1,:) == t(2,:))
                    t = t(1,:);
                end
                % Set event
                sFile.events(iEvt).label    = strtrim(uniqueEvt{iEvt});
                sFile.events(iEvt).times    = round(t .* sFile.prop.sfreq) ./ sFile.prop.sfreq;
                sFile.events(iEvt).epochs   = 1 + 0*t(1,:);
                sFile.events(iEvt).select   = 1;
                sFile.events(iEvt).channels = cell(1, size(sFile.events(iEvt).times, 2));
                sFile.events(iEvt).notes    = cell(1, size(sFile.events(iEvt).times, 2));
            end
        end
        
    % BDF Status line
    elseif strcmpi(sFile.format, 'EEG-BDF')
        % Ask how to read the events
        events = process_evt_read('Compute', sFile, ChannelMat, ChannelMat.Channel(iEvtChans).Name, ImportOptions.EventsTrackMode);
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
        % Group events by time
        % sFile.events = process_evt_grouptime('Compute', sFile.events);
    end
end

    
    

