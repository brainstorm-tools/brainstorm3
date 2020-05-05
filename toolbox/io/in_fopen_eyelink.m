function [sFile, ChannelMat] = in_fopen_eyelink(DataFile)
% IN_FOPEN_EYELINK: Open EyeLink eye tracker recordings (.edf).
%
% USAGE:  [sFile, ChannelMat] = in_fopen_eyelink(DataFile)

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
% Authors: Francois Tadel & Martin Voelker, 2015


%% ===== READ HEADER =====
% Windows only
if ~ispc
    error('This format is only supported on Windows systems.');
end
% Read header and events
Trials = edfImport(DataFile, [0 1 1]);
% Get events of interest
Trials = edfExtractInterestingEvents(Trials, '^TRIALID');
Trials = edfExtractMicrosaccades(Trials);
hdr.Headers = [Trials.Header];
% Split filename
[fPath, fBase, fExt] = bst_fileparts(DataFile);
% Cannot handled multiple sampling frequencies
nEpochs = length(hdr.Headers);
allRec = [hdr.Headers.rec];
if (nEpochs > 1) && ~all([allRec.sample_rate] == hdr.Headers(1).rec.sample_rate)
    error('This function cannot handle different sampling frequencies between trials.');
end
% Sampling frequency
sfreq = double(hdr.Headers(1).rec.sample_rate);


%% ===== CREATE CHANNEL FILE =====
% List of data types
chnames = {'flags','px','py','hx','hy','pa','gx','gy','rx','ry','input','buttons','htype','hdata','errors', ...
           'gxvel','gyvel','hxvel','hyvel','rxvel','ryvel','fgxvel','fgyvel','fhxvel','fhyvel','frxvel','fryvel'};
chtypes = {'STATUS','EYE','EYE','EYE','EYE','EYE','EYE','EYE','EYE','EYE','STATUS','STATUS','STATUS','STATUS','STATUS', ...
           'EYE','EYE','EYE','EYE','EYE','EYE','EYE','EYE','EYE','EYE','EYE','EYE'};
% Convert to channels
hdr.chnames = {};
hdr.chtypes = {};
% hdr.chgain  = [];
for i = 1:length(chnames)
    % Channel is not available
    if ~isfield(Trials(1).Samples, chnames{i})
        continue;
    end
%     % Compute channel maximum (as a deviant from the mean)
%     chsamples = double(Trials(1).Samples.(chnames{i}));
%     champ     = max(abs(chsamples),[],2) - abs(mean(chsamples,2));
%     % Channel gain: 1/amplitude (or 0 if the value is constant)
%     chgain = zeros(size(champ));
%     chgain(champ ~= 0) = 1 ./ champ(champ ~= 0);
    % One channel of data per entry
    if (size(Trials(1).Samples.(chnames{i}),1) == 1)
        hdr.chnames{end+1} = chnames{i};
        hdr.chtypes{end+1} = chtypes{i};
%         hdr.chgain(end+1)  = chgain(1);
    % Two channels of data per entry
    else
        % Left eye only OR both eyes
        if (Trials(1).Header.rec.eye == 1) || (Trials(1).Header.rec.eye == 3)
            hdr.chnames{end+1} = [chnames{i}, '_l'];
            hdr.chtypes{end+1} = chtypes{i};
%             hdr.chgain(end+1)  = chgain(1);
        end
        % Right eye only OR both eyes
        if (Trials(1).Header.rec.eye == 2) || (Trials(1).Header.rec.eye == 3)
            hdr.chnames{end+1} = [chnames{i}, '_r'];
            hdr.chtypes{end+1} = chtypes{i};
%             hdr.chgain(end+1)  = chgain(2);
        end
    end
end
nChannels = length(hdr.chnames);
% Create structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'EyeLink channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, nChannels]);
% For each channel
for i = 1:nChannels
    ChannelMat.Channel(i).Name    = hdr.chnames{i};
    ChannelMat.Channel(i).Type    = hdr.chtypes{i};
    ChannelMat.Channel(i).Loc     = [0; 0; 0];
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Weight  = 1;
    ChannelMat.Channel(i).Comment = [];
end


%% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder = 'l';
sFile.filename  = DataFile;
sFile.format    = 'EYELINK';
sFile.device    = 'EyeLink';
sFile.header    = hdr;
sFile.comment   = fBase;
sFile.condition = [];
% Epochs
sFile.epochs = repmat(db_template('epoch'), 1, nEpochs);
for i = 1:nEpochs
    % 1 timestamp = 1 millisecond
    sFile.epochs(i).times   = round((double(hdr.Headers(i).starttime) + [0, double(hdr.Headers(i).duration)-1]) ./ 1000 .* sfreq)  ./ sfreq;
    sFile.epochs(i).label   = sprintf('Trial #%d', i);
    sFile.epochs(i).nAvg    = 1;
    sFile.epochs(i).select  = 1;
    sFile.epochs(i).bad     = 0;
end
% Consider that the sampling rate of the file is the sampling rate of the first signal
sFile.prop.sfreq   = sfreq;
sFile.prop.times   = [min([sFile.epochs.times]), max([sFile.epochs.times])];
sFile.prop.nAvg    = 1;
% No info about bad channels
sFile.channelflag = ones(nChannels, 1);

    
%% ===== EVENT MARKERS =====
% Initialize structure of events
events = repmat(db_template('event'), 1, 6);
iFixL = 1;  events(iFixL).label = 'fixation L';   % eye=0
iFixR = 2;  events(iFixR).label = 'fixation R';   % eye=1
iBliL = 3;  events(iBliL).label = 'blink L';
iBliR = 4;  events(iBliR).label = 'blink R';
iSacL = 5;  events(iSacL).label = 'saccade L';
iSacR = 6;  events(iSacR).label = 'saccade R';
iUsa  = 7;  events(iUsa).label = 'microsaccade';
iBut  = 8;  events(iBut).label  = 'button';
iMessList = {}; % for storing of event numbers of message events

% Create events
for i = 1:nEpochs
    % Fixation
    if isfield(Trials, 'Fixations') && ~isempty(Trials(i).Fixations)
        Ltime = unique(double(Trials(i).StartTime + Trials(i).Fixations.sttime(Trials(i).Fixations.eye == 0)) ./ 1000);
        Rtime = unique(double(Trials(i).StartTime + Trials(i).Fixations.sttime(Trials(i).Fixations.eye == 1)) ./ 1000);
        events(iFixL).times  = [events(iFixL).times, Ltime];
        events(iFixR).times  = [events(iFixR).times, Rtime];
        events(iFixL).epochs = [events(iFixL).epochs, repmat(i, 1, length(Ltime))];
        events(iFixR).epochs = [events(iFixR).epochs, repmat(i, 1, length(Rtime))];
    end
    % Blinks
    if isfield(Trials, 'Blinks') && ~isempty(Trials(i).Blinks)
        Ltime = unique(double(Trials(i).StartTime + Trials(i).Blinks.sttime(Trials(i).Blinks.eye == 0)) ./ 1000);
        Rtime = unique(double(Trials(i).StartTime + Trials(i).Blinks.sttime(Trials(i).Blinks.eye == 1)) ./ 1000);
        events(iBliL).times  = [events(iBliL).times, Ltime];
        events(iBliR).times  = [events(iBliR).times, Rtime];
        events(iBliL).epochs = [events(iBliL).epochs, repmat(i, 1, length(Ltime))];
        events(iBliR).epochs = [events(iBliR).epochs, repmat(i, 1, length(Rtime))];
    end
    % Saccade
    if isfield(Trials, 'Saccades') && ~isempty(Trials(i).Saccades)
        Ltime = unique(double(Trials(i).StartTime + Trials(i).Saccades.sttime(Trials(i).Saccades.eye == 0)) ./ 1000);
        Rtime = unique(double(Trials(i).StartTime + Trials(i).Saccades.sttime(Trials(i).Saccades.eye == 1)) ./ 1000);
        events(iSacL).times  = [events(iSacL).times, Ltime];
        events(iSacR).times  = [events(iSacR).times, Rtime];
        events(iSacL).epochs = [events(iSacL).epochs, repmat(i, 1, length(Ltime))];
        events(iSacR).epochs = [events(iSacR).epochs, repmat(i, 1, length(Rtime))];
    end
    % Button
    if isfield(Trials, 'Buttons') && ~isempty(Trials(i).Buttons)
        Time = unique(double(Trials(i).StartTime + Trials(i).Buttons.time) ./ 1000);
        events(iBut).times  = [events(iBut).times, Time];
        events(iBut).epochs = [events(iBut).epochs, repmat(i, 1, length(Time))];
    end
    % Micro-saccade (separate detection)
    if isfield(Trials, 'Microsaccades') && ~isempty(Trials(i).Microsaccades)
        Time = unique(double(Trials(i).Microsaccades.StartTime) ./ 1000);
        events(iUsa).times  = [events(iUsa).times, Time];
        events(iUsa).epochs = [events(iUsa).epochs, repmat(i, 1, length(Time))];
    end
    
    % Messages send by user (e.g. as sync triggers)
    if isfield(Trials, 'Events') && ~isempty(Trials(i).Events.message)
        messageType = unique(Trials(i).Events.message);
        % Exclude "TRIALID" and empty markers
        for iMess = numel(messageType):-1:1
            if strncmpi(messageType{iMess}, 'TRIALID', 6) || isempty(messageType{iMess})
                messageType(iMess) = [];
            end
        end
        % Store messages into 'event' struct    
        for iMess = 1:numel(messageType)
            if ~isempty(find(strcmp([iMessList{:}], messageType{iMess}), 1)) % if 1, the event type has already a slot in 'events'
                iEvent = find(strcmp([iMessList{:}], messageType{iMess}));
            else                                                % new event type, define index for 'events' struct and label
                iMessList{numel(iMessList)+1} = messageType{iMess};           
                iEvent = numel(events)+1;
                events(iEvent).label = messageType{iMess};
            end
            
            Time = double(Trials(i).Events.sttime(ismember(Trials(i).Events.message, messageType{iMess})==1)) ./ 1000;
            events(iEvent).times  = [events(iEvent).times, Time];
            events(iEvent).epochs = [events(iEvent).epochs, repmat(i, 1, length(Time))];
        end
    end
end
% Additional fixes
for i = 1:length(events)
    % Rounding the times to the nearest sample
    if ~isempty(events(i).times)
        events(i).times = round(events(i).times .* sFile.prop.sfreq) ./ sFile.prop.sfreq;
    end
    % Add channels and notes fields
    events(i).channels = cell(1, size(events(i).times, 2));
    events(i).notes    = cell(1, size(events(i).times, 2));
end

% Import this list
sFile = import_events(sFile, [], events);



