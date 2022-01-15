function [sFile, ChannelMat] = in_fopen_plexon(DataFile)
% IN_FOPEN_PLEXON Open Plexon recordings.
% Open data that are saved in a single .plx file

% This function is using the importer developed by Benjamin Kraus (2013)
% https://www.mathworks.com/matlabcentral/fileexchange/42160-readplxfilec


% DESCRIPTION:
%     Reads all the following files available in the same folder.


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
% Authors: Konstantinos Nasiotis, 2018-2021; Martin Cousineau, 2019


%% ===== GET FILES =====
% Get base dataset folder
[rawFolder, rawFile, plexonFormat] = bst_fileparts(DataFile);
if isdir(DataFile)
    hdr.BaseFolder = DataFile;
    plexonFormat = '.plx';
elseif ismember(plexonFormat, {'.plx', '.pl2'})
    hdr.BaseFolder = rawFolder;
else
    error('Invalid Plexon folder.');
end


%% ===== FILE COMMENT =====
% Comment: BaseFolder
Comment = rawFile;


%% ===== READ DATA HEADERS =====
hdr.chan_headers = {};
hdr.chan_files = {};
hdr.extension = plexonFormat;

%% Read using Plexon SDK
if exist('PL2GetFileIndex', 'file') ~= 2
    error(['Please install Plexon''s Matlab offline files SDK.' 10 ...
        'More information here: https://neuroimage.usc.edu/brainstorm/e-phys/Introduction#Importing_PL2_Plexon_files']);
end

% Read metadata
[spikes_tscounts, wfcounts, evcounts, contcounts] = plx_info(DataFile, 0);
%     newHeader = readPLXFileC(DataFile,'events','spikes');
channels_with_timetraces = contcounts>0;

[n, all_Channel_names] = plx_adchan_names(DataFile);
all_Channel_names = cellstr(all_Channel_names); % Convert to cell so it can be used in regexprep

channelsWithTimeseriesNames = all_Channel_names(channels_with_timetraces);

%% ===== CREATE CHANNEL FILE =====

all_signalTypesWithoutNumbers = regexprep(all_Channel_names,'[\d"]','')';
signalTypesWithoutNumbers = regexprep(channelsWithTimeseriesNames,'[\d"]','')';
D = unique(signalTypesWithoutNumbers, 'stable');

% If multiple signal types (Raw, LFP etc.) exist within the Plexon file, let the user
% decide which ones to load. This might need to be revisited if behavioral
% channels need to be loaded simultaneously.
% For now only a single type is allowed to be loaded.
if length(D)>1
    [indx,tf] = listdlg('PromptString',{'Multiple recording types are present in this file.',...
        'Select which one to load:',''},...
        'SelectionMode','single', 'ListSize',[150,30*length(D)], 'ListString',D);
    
    if isempty(indx)
        error(['No timeseries channel type selected']);
    end
    
    selectedSignalType = D{indx};
else
    selectedSignalType = D;
end

iChannels_selected = find(ismember(all_signalTypesWithoutNumbers, selectedSignalType));


% Fill the channelMat
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'Plexon channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, length(iChannels_selected)]);

% Update the channelMat
ii = 0;
for i = iChannels_selected
    ii = ii+1;
    ChannelMat.Channel(ii).Name = all_Channel_names{i};
    ChannelMat.Channel(ii).Loc  = [0; 0; 0];
    ChannelMat.Channel(ii).Type    = 'EEG';
    ChannelMat.Channel(ii).Orient  = [];
    ChannelMat.Channel(ii).Weight  = 1;
    ChannelMat.Channel(ii).Comment = [];
end


%% Get info from the first channel of the selection
[adfreq, n, ts, fn] = plx_ad_gap_info(DataFile,iChannels_selected(1)-1);

%%
Fs = adfreq;

% Extract information needed for opening the file
hdr.FirstTimeStamp    = ts;
hdr.LastTimeStamp     = fn/Fs+ts;
hdr.NumSamples        = fn;
hdr.SamplingFrequency = Fs;

% Assign important fields
hdr.chan_headers   = iChannels_selected;
hdr.ChannelCount   = length(iChannels_selected);


%% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder = 'l';
sFile.filename  = DataFile;
sFile.format    = 'EEG-PLEXON';
sFile.device    = 'Plexon';
sFile.header    = hdr;
sFile.comment   = Comment;
sFile.prop.nAvg  = 1;
sFile.prop.sfreq = Fs;
sFile.prop.times = [ts, (fn - 1)/Fs + ts];

% No info on bad channels
sFile.channelflag = ones(hdr.ChannelCount, 1);

%% ===== READ EVENTS =====

% Event selection
[n,names] = plx_event_names(DataFile);
names = cellstr(names); % Convert to cell so it can be used in regexprep
iPresentEvents = find(logical(evcounts));

% Read the events
if ~isempty(iPresentEvents)
       
    % Get all event channels
    [n, evchans] = plx_event_chanmap(DataFile); % First get the event channels global indices
    % Get all events labels
    event_labels = names(iPresentEvents);

    % Initialize list of events
    events = repmat(db_template('event'), 1, length(iPresentEvents));

    % Store in Brainstorm event structure
    for iEvt = 1:length(iPresentEvents)

        % Get event times
        [n, ts, sv] = plx_event_ts(DataFile, evchans(iPresentEvents(iEvt)));
        times = ts; % In seconds
        % Fill the event fields
        events(iEvt).label      = event_labels{iEvt};
        events(iEvt).color      = rand(1,3);
        events(iEvt).times      = times';
        events(iEvt).epochs     = ones(1, size(events(iEvt).times, 2));
        events(iEvt).reactTimes = [];
        events(iEvt).select     = 1;
        events(iEvt).channels   = cell(1, size(events(iEvt).times, 2));
        events(iEvt).notes      = cell(1, size(events(iEvt).times, 2));
    end
    % Import this list
    sFile = import_events(sFile, [], events);
end


%% Read the Spikes events
if sum(spikes_tscounts(1,:))>0 && ~strcmp(selectedSignalType, 'AI') % If spikes exist and not analog input selected
        
    unique_events = sum(sum(spikes_tscounts(:,2:end)>0)); % First row of spikes_tscounts is ignored

    % Initialize list of events
    events = repmat(db_template('event'), 1, unique_events);
    iEnteredEvent = 1;

    spike_event_prefix = process_spikesorting_supervised('GetSpikesEventPrefix');

    for iChannel = 1:size(spikes_tscounts,2)-1

        nNeurons = sum(spikes_tscounts(:,iChannel+1)>0); % spikes_tscounts: rows = different units on the same channel, columns = channels

        for iNeuron = 1:length(nNeurons)

            if length(nNeurons)>1
                event_label_postfix = [' |' num2str(iNeuron) '|'];
            else
                event_label_postfix = '';
            end

            [n, spikeTimes] = plx_ts(DataFile, iChannel, iNeuron-1);

            % Fill the event fields
            events(iEnteredEvent).label      = [spike_event_prefix ' ' all_Channel_names{iChannels_selected(iChannel)}];
            events(iEnteredEvent).color      = rand(1,3);
            events(iEnteredEvent).times      = spikeTimes';
            events(iEnteredEvent).epochs     = ones(1, size(events(iEnteredEvent).times, 2));
            events(iEnteredEvent).reactTimes = [];
            events(iEnteredEvent).select     = 1;
            events(iEnteredEvent).channels   = cell(1, size(events(iEnteredEvent).times, 2));
            events(iEnteredEvent).notes      = cell(1, size(events(iEnteredEvent).times, 2));
            iEnteredEvent = iEnteredEvent + 1;
        end
    end

    % Import this list
    sFile = import_events(sFile, [], events);
end
end