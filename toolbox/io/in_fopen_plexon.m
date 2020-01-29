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
% Authors: Konstantinos Nasiotis, 2018-2019; Martin Cousineau, 2019


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

if strcmpi(plexonFormat, '.plx')
    %% Read using Kraus importer
    % Read the header
    % THIS IMPORTER COMPILES A C FUNCTION BEFORE RUNNING FOR THE FIRST TIME
    if exist('readPLXFileC','file') ~= 3
        current_path = pwd;
        plexon_path = bst_fileparts(which('build_readPLXFileC'));
        cd(plexon_path);
        ME = [];
        try
            build_readPLXFileC();
        catch ME
        end
        cd(current_path);
        if ~isempty(ME)
            rethrow(ME);
        end
    end

    newHeader = readPLXFileC(DataFile,'events','spikes');
    
    % Load one channel file to get required event fields
    CHANNELS_SELECTED = find([newHeader.ContinuousChannels.Enabled]); % Only get the channels that have been enabled. The rest won't load any data
    if isempty(CHANNELS_SELECTED)
        error('No continuous recordings available in this file.');
    end
    isMiscChannels = ~isDataChannel({newHeader.ContinuousChannels(CHANNELS_SELECTED).Name});

    one_channel = readPLXFileC(DataFile,'continuous',CHANNELS_SELECTED(1)-1);
    channel_Fs = one_channel.ContinuousChannels(1).ADFrequency; % There is a different sampling rate for channels and (events and spikes events)


    % Extract information needed for opening the file
    hdr.FirstTimeStamp    = 0;
    hdr.LastTimeStamp     = length(one_channel.ContinuousChannels(CHANNELS_SELECTED(1)).Values)*one_channel.ContinuousChannels(1).ADFrequency;
    hdr.NumSamples        = length(one_channel.ContinuousChannels(CHANNELS_SELECTED(1)).Values); % newHeader.LastTimestamp is in samples. Brainstorm header is in seconds.
    hdr.SamplingFrequency = one_channel.ContinuousChannels(1).ADFrequency;

    % Get only the channels from electrodes, not auxillary channels
    just_recording_channels = newHeader.ContinuousChannels;

    % Assign important fields
    hdr.chan_headers   = just_recording_channels;
    hdr.ChannelCount   = length(CHANNELS_SELECTED);
    hdr.isMiscChannels = isMiscChannels;
    
elseif strcmpi(plexonFormat, '.pl2')
    %% Read using Plexon SDK
    if exist('PL2GetFileIndex', 'file') ~= 2
        error(['Please install Plexon''s Matlab offline files SDK.' 10 ...
            'More information here: https://neuroimage.usc.edu/brainstorm/e-phys/Introduction#Importing_PL2_Plexon_files']);
    end
    
    % Read metadata
    newHeader = PL2GetFileIndex(DataFile);
    hdr.chan_headers = cell2mat(newHeader.AnalogChannels);
    newHeader.EventChannels = cell2mat(newHeader.EventChannels);
    CHANNELS_SELECTED = find([hdr.chan_headers.Enabled]);
    one_channel = hdr.chan_headers(CHANNELS_SELECTED(1));
    isMiscChannels = ~isDataChannel({hdr.chan_headers(CHANNELS_SELECTED).Name});
    
    % Extract header
    hdr.NumSamples        = one_channel.NumValues;
    hdr.SamplingFrequency = one_channel.SamplesPerSecond;
    hdr.FirstTimeStamp    = 0;
    hdr.LastTimeStamp     = hdr.NumSamples / hdr.SamplingFrequency;
    hdr.ChannelCount      = length(CHANNELS_SELECTED);
    hdr.EnabledChannels   = CHANNELS_SELECTED;
    hdr.isMiscChannels    = isMiscChannels;
end

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
% Consider that the sampling rate of the file is the sampling rate of the first signal
sFile.prop.sfreq = hdr.SamplingFrequency;
sFile.prop.times = [0, hdr.NumSamples - 1] ./ sFile.prop.sfreq;
sFile.prop.nAvg  = 1;
% No info on bad channels
sFile.channelflag = ones(hdr.ChannelCount, 1);


%% ===== CREATE EMPTY CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'Plexon channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, hdr.ChannelCount]);
% For each channel

ii = 0;
for i = CHANNELS_SELECTED
    ii = ii+1;
    ChannelMat.Channel(ii).Name    = hdr.chan_headers(i).Name;
    ChannelMat.Channel(ii).Loc     = [0; 0; 0];
    if hdr.isMiscChannels(ii)
        ChannelMat.Channel(ii).Type    = 'Misc';
    else
        ChannelMat.Channel(ii).Type    = 'EEG';
    end
    ChannelMat.Channel(ii).Orient  = [];
    ChannelMat.Channel(ii).Weight  = 1;
    ChannelMat.Channel(ii).Comment = [];
end


%% ===== READ EVENTS =====

% Read the events
if isfield(newHeader, 'EventChannels')
    if strcmpi(plexonFormat, '.plx')
        % General events
        unique_events = 0;
        for i = 1:length(newHeader.EventChannels)
            if ~isempty(newHeader.EventChannels(i).Values)
                unique_events = unique_events + 1;
            end
        end


        %% Plexon has an event named: Strobed
        % This takes different values (it works like a parallel port event generator).
        % Create a unique event for each of these values.
        iStrobed = find(strcmp({newHeader.EventChannels.Name},'Strobed'));
        if ~isempty(iStrobed)
            uniqueStrobed = double(sort(unique(newHeader.EventChannels(iStrobed).Values)));
            unique_events = unique_events+length(uniqueStrobed)-1;
        end

        % Initialize list of events
        events = repmat(db_template('event'), 1, unique_events);

        % Format list
        iNotEmptyEvents = 0;

        for iEvt = 1:length(newHeader.EventChannels)
            if ~isempty(newHeader.EventChannels(iEvt).Timestamps)
                % Fill the event fields

                if ~strcmp(newHeader.EventChannels(iEvt).Name, 'Strobed')
                    iNotEmptyEvents = iNotEmptyEvents + 1;
                    samples = round(double(newHeader.EventChannels(iEvt).Timestamps') * channel_Fs/newHeader.ADFrequency); % The events are sampled with different sampling rate than the Channels
                    events(iNotEmptyEvents).label      = newHeader.EventChannels(iEvt).Name;
                    events(iNotEmptyEvents).color      = rand(1,3);
                    events(iNotEmptyEvents).epochs     = ones(1, length(samples));
                    events(iNotEmptyEvents).times      = samples / channel_Fs;
                    events(iNotEmptyEvents).reactTimes = [];
                    events(iNotEmptyEvents).select     = 1;
                    events(iNotEmptyEvents).channels   = cell(1, size(events(iNotEmptyEvents).times, 2));
                    events(iNotEmptyEvents).notes      = cell(1, size(events(iNotEmptyEvents).times, 2));
                else
                    for iStrobed = uniqueStrobed'
                        iNotEmptyEvents = iNotEmptyEvents + 1;
                        samples = round(double(newHeader.EventChannels(iEvt).Timestamps(double(newHeader.EventChannels(iEvt).Values)==iStrobed)') * channel_Fs/newHeader.ADFrequency); % The events are sampled with different sampling rate than the Channels
                        events(iNotEmptyEvents).label      = [newHeader.EventChannels(iEvt).Name ' ' num2str(iStrobed)];
                        events(iNotEmptyEvents).color      = rand(1,3);
                        events(iNotEmptyEvents).epochs     = ones(1, length(samples));
                        events(iNotEmptyEvents).times      = samples / channel_Fs;
                        events(iNotEmptyEvents).reactTimes = [];
                        events(iNotEmptyEvents).select     = 1;
                        events(iNotEmptyEvents).channels   = cell(1, size(events(iNotEmptyEvents).times, 2));
                        events(iNotEmptyEvents).notes      = cell(1, size(events(iNotEmptyEvents).times, 2));
                    end
                end

            end
        end

    elseif strcmpi(plexonFormat, '.pl2')
        % General events
        nEvents = length(newHeader.EventChannels);
        unique_events = 0;
        for iEvent = 1:nEvents
            if newHeader.EventChannels(iEvent).NumEvents > 0
                unique_events = unique_events + 1;
            end
        end

        % Initialize list of events
        events = repmat(db_template('event'), 1, unique_events);

        iEnteredEvent = 0;
        for iEvent = 1:length(newHeader.EventChannels)
            if newHeader.EventChannels(iEvent).NumEvents
                iEnteredEvent = iEnteredEvent + 1;
                TheEventsInSeconds = PL2EventTs(DataFile, iEvent);
                times = TheEventsInSeconds.Ts';

                events(iEnteredEvent).label      = newHeader.EventChannels(iEvent).Name;
                events(iEnteredEvent).color      = rand(1,3);
                events(iEnteredEvent).epochs     = ones(1,length(times));
                events(iEnteredEvent).times      = times;
                events(iEnteredEvent).reactTimes = [];
                events(iEnteredEvent).select     = 1;
                events(iEnteredEvent).channels   = cell(1, size(events(iEnteredEvent).times, 2));
                events(iEnteredEvent).notes      = cell(1, size(events(iEnteredEvent).times, 2));
            end
        end
    end
    
    % Import this list
    sFile = import_events(sFile, [], events);
end


%% Read the Spikes events
if isfield(newHeader, 'SpikeChannels')
    if strcmpi(plexonFormat, '.plx')
        unique_events = 0;
        for i = 1:length(newHeader.SpikeChannels)
            if ~isempty(newHeader.SpikeChannels(i).Timestamps)
                unique_events = unique_events + 1;
            end
        end
        
        % Initialize list of events
        events = repmat(db_template('event'), 1, unique_events);
        iEnteredEvent = 1;

        spike_event_prefix = process_spikesorting_supervised('GetSpikesEventPrefix');

        for iEvt = 1:length(newHeader.SpikeChannels)
            if ~isempty(newHeader.SpikeChannels(iEvt).Timestamps)

                nNeurons = double(unique(newHeader.SpikeChannels(iEvt).Units));
                nNeurons = nNeurons(nNeurons~=0);

                for iNeuron = 1:length(nNeurons)

                    if length(nNeurons)>1
                        event_label_postfix = [' |' num2str(iNeuron) '|'];
                    else
                        event_label_postfix = '';
                    end

                    samples = round(double(newHeader.SpikeChannels(iEvt).Timestamps(double(newHeader.SpikeChannels(iEvt).Units) == iNeuron)') * channel_Fs/newHeader.ADFrequency); % The events are sampled with different sampling rate than the Channels

                    % Fill the event fields
                    events(iEnteredEvent).label      = [spike_event_prefix ' ' hdr.chan_headers(iEvt).Name event_label_postfix]; % THE SPIKECHANNELS LABEL IS DIFFERENT THAN THE CHANNEL NAME - CHECK THAT!
                    events(iEnteredEvent).color      = rand(1,3);
                    events(iEnteredEvent).epochs     = ones(1, length(samples));
                    events(iEnteredEvent).times      = samples / channel_Fs;
                    events(iEnteredEvent).reactTimes = [];
                    events(iEnteredEvent).select     = 1;
                    events(iEnteredEvent).channels   = cell(1, size(events(iEnteredEvent).times, 2));
                    events(iEnteredEvent).notes      = cell(1, size(events(iEnteredEvent).times, 2));
                    iEnteredEvent = iEnteredEvent + 1;
                end
            end
        end


    elseif strcmpi(plexonFormat, '.pl2')
        % Enabled spikes channels holds the indices of the channels that have
        % spikes
        enabledSpikesChannels = [];
        nNeurons = []; % Holds the number of neurons that were picked up on each channel
        for iSpikesChannel = 1:length(newHeader.SpikeChannels)
            if newHeader.SpikeChannels{iSpikesChannel}.Enabled
                enabledSpikesChannels = [enabledSpikesChannels iSpikesChannel];
                nNeurons = [nNeurons newHeader.SpikeChannels{iSpikesChannel}.NumberOfUnits];
            end
        end
        
        events = db_template('event');
        iEnteredEvent = 1;
        spike_event_prefix = process_spikesorting_supervised('GetSpikesEventPrefix');
        
        for iSpikesChannel = 1:length(enabledSpikesChannels)
            for iNeuron = 1:nNeurons(iSpikesChannel)
                if nNeurons(iSpikesChannel) > 1
                    event_label_postfix = [' |' num2str(iNeuron) '|'];
                else
                    event_label_postfix = '';
                end
                
                times = PL2Ts(DataFile, iSpikesChannel, iNeuron)';
                
                events(iEnteredEvent).label      = [spike_event_prefix ' ' newHeader.AnalogChannels{iSpikesChannel}.Name event_label_postfix];
                events(iEnteredEvent).color      = rand(1,3);
                events(iEnteredEvent).epochs     = ones(1,length(times));
                events(iEnteredEvent).times      = times;
                events(iEnteredEvent).reactTimes = [];
                events(iEnteredEvent).select     = 1;
                events(iEnteredEvent).channels   = cell(1, size(events(iEnteredEvent).times, 2));
                events(iEnteredEvent).notes      = cell(1, size(events(iEnteredEvent).times, 2));
                iEnteredEvent = iEnteredEvent + 1;
            end
        end
    end
    
    % Import this list
    sFile = import_events(sFile, [], events);
end
end


function isData = isDataChannel(channelNames)
    dataChannelPrefixes = {'WB', 'AD'};
    nPrefixes = length(dataChannelPrefixes);
    prefixLens = cellfun('length', dataChannelPrefixes);
    
    nChannels = length(channelNames);
    isData = zeros(1,nChannels);
    
    for iChannel = 1:length(channelNames)
        for iPrefix = 1:nPrefixes
            if strncmpi(channelNames{iChannel}, dataChannelPrefixes{iPrefix}, prefixLens(iPrefix))
                isData(iChannel) = 1;
                break;
            end
        end
    end
end
