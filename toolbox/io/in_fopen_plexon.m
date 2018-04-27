function [sFile, ChannelMat] = in_fopen_plexon(DataFile)
% IN_FOPEN_PLEXON Open Plexon recordings.
% Open data that are saved in a single .plx file

% This function is using the importer developed by Benjamin Kraus (2013)
% https://www.mathworks.com/matlabcentral/fileexchange/42160-readplxfilec


% DESCRIPTION:
%     Reads all the following files available in the same folder.


% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND T
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Konstantinos Nasiotis 2018


%% ===== GET FILES =====
% Get base dataset folder
if isdir(DataFile)
    hdr.BaseFolder = DataFile;
elseif strcmpi(DataFile(end-3:end), '.plx')
    hdr.BaseFolder = bst_fileparts(DataFile);
else
    error('Invalid Plexon folder.');
end


%% ===== FILE COMMENT =====
% Get base folder name
[base_, dirComment, extension] = bst_fileparts(DataFile);
% Comment: BaseFolder + number or files
Comment = dirComment;


%% ===== READ DATA HEADERS =====
hdr.chan_headers = {};
hdr.chan_files = {};

% Read the header
% THIS IMPORTER COMPILES A C FUNCTION BEFORE RUNNING FOR THE FIRST TIME

if ~exist('readPLXFileC.mexw*','file') == 2
    build_readPLXFileC
end

newHeader = readPLXFileC(DataFile,'events','spikes');


% Check for some important fields
if ~isfield(newHeader, 'NumSpikeChannels') || ~isfield(newHeader, 'ContinuousChannels')
    error('Missing fields in the file header');
end


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% % THE LASTTIMESTAMP and ADFREQUENCY fields are for the events!
% Load one channel file and get them from there.


CHANNELS_SELECTED = [newHeader.ContinuousChannels.Enabled]; % Only get the channels that have been enabled. The rest won't load any data
CHANNELS_SELECTED = find(CHANNELS_SELECTED);

one_channel = readPLXFileC(DataFile,'continuous',CHANNELS_SELECTED(1)-1);
channel_Fs = one_channel.ContinuousChannels(1).ADFrequency; % There is a different sampling rate for channels and (events and spikes events)


% Extract information needed for opening the file
hdr.FirstTimeStamp    = 0;
hdr.LastTimeStamp     = length(one_channel.ContinuousChannels(CHANNELS_SELECTED(1)).Values)*one_channel.ContinuousChannels(1).ADFrequency;
hdr.NumSamples        = length(one_channel.ContinuousChannels(CHANNELS_SELECTED(1)).Values); % newHeader.LastTimestamp is in samples. Brainstorm header is in seconds.
hdr.extension         = extension;
hdr.SamplingFrequency = one_channel.ContinuousChannels(1).ADFrequency;

% Get only the channels from electrodes, not auxillary channels %% FIX THIS ON A LATER VERSION
just_recording_channels = newHeader.ContinuousChannels;

% Assign important fields
hdr.chan_headers = just_recording_channels;
hdr.ChannelCount = length(CHANNELS_SELECTED);


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
sFile.prop.sfreq   = hdr.SamplingFrequency;
sFile.prop.samples = [0, hdr.NumSamples - 1];
sFile.prop.times   = sFile.prop.samples ./ sFile.prop.sfreq;
sFile.prop.nAvg    = 1;
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
    ChannelMat.Channel(ii).Type    = 'EEG';
    ChannelMat.Channel(ii).Orient  = [];
    ChannelMat.Channel(ii).Weight  = 1;
    ChannelMat.Channel(ii).Comment = [];
end


%% ===== READ EVENTS =====

% Read the events
if isfield(newHeader, 'EventChannels')
        
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
                %%%%%%%%%%%%%%%%%%%%%%   WARNING   %%%%%%%%%%%%%%%%%%%%%%%%%%%%
                events(iNotEmptyEvents).label      = newHeader.EventChannels(iEvt).Name; % MAKE SURE TO CHECK WHAT THIS MEANS - PLEXON USES DIFFERENT EVENT CHANNEL NAME FOR THE SPIKES, THAN THE ORIGINAL CHANNEL NAME !!!!!!!!!
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                events(iNotEmptyEvents).color      = rand(1,3);
                events(iNotEmptyEvents).samples    = round(double(newHeader.EventChannels(iEvt).Timestamps') * channel_Fs/newHeader.ADFrequency); % The events are sampled with different sampling rate than the Channels
                events(iNotEmptyEvents).times      = events(iNotEmptyEvents).samples/channel_Fs; 
                events(iNotEmptyEvents).reactTimes = [];
                events(iNotEmptyEvents).select     = 1;
                events(iNotEmptyEvents).epochs     = ones(1, length(events(iNotEmptyEvents).samples));
            else
                for iStrobed = uniqueStrobed'
                    iNotEmptyEvents = iNotEmptyEvents + 1;
                    events(iNotEmptyEvents).label      = [newHeader.EventChannels(iEvt).Name ' ' num2str(iStrobed)];
                    events(iNotEmptyEvents).color      = rand(1,3);
                    events(iNotEmptyEvents).samples    = round(double(newHeader.EventChannels(iEvt).Timestamps(double(newHeader.EventChannels(iEvt).Values)==iStrobed)') * channel_Fs/newHeader.ADFrequency); % The events are sampled with different sampling rate than the Channels
                    events(iNotEmptyEvents).times      = events(iNotEmptyEvents).samples/channel_Fs; 
                    events(iNotEmptyEvents).reactTimes = [];
                    events(iNotEmptyEvents).select     = 1;
                    events(iNotEmptyEvents).epochs     = ones(1, length(events(iNotEmptyEvents).samples));
                end
            end
                
        end
    end
    % Import this list
    sFile = import_events(sFile, [], events);
end


% Read the Spikes events
if isfield(newHeader, 'SpikeChannels')
        
    unique_events = 0;
    for i = 1:length(newHeader.SpikeChannels)
        if ~isempty(newHeader.SpikeChannels(i).Timestamps)
            unique_events = unique_events + 1;
        end
    end
    
    for iEvt = 1:length(newHeader.SpikeChannels)
        if ~isempty(newHeader.SpikeChannels(iEvt).Timestamps)
            
            nNeurons = double(unique(newHeader.SpikeChannels(iEvt).Units));
            nNeurons = nNeurons(nNeurons~=0);
            
            for iNeuron = 1:length(nNeurons)
            
                last_event_index = length(events) + 1;
                
                if length(nNeurons)>1
                    event_label_postfix = ['|' num2str(iNeuron) '|'];
                else
                    event_label_postfix = '';
                end
                
                % Fill the event fields
                events(last_event_index).label      = ['Spikes Channel ' newHeader.SpikeChannels(iEvt).Name ' ' event_label_postfix]; % THE SPIKECHANNELS LABEL IS DIFFERENT THAN THE CHANNEL NAME - CHECK THAT!
                events(last_event_index).color      = rand(1,3);
                events(last_event_index).samples    = round(double(newHeader.SpikeChannels(iEvt).Timestamps(double(newHeader.SpikeChannels(iEvt).Units) == iNeuron)') * channel_Fs/newHeader.ADFrequency); % The events are sampled with different sampling rate than the Channels
                events(last_event_index).times      = events(last_event_index).samples/channel_Fs; 
                events(last_event_index).reactTimes = [];
                events(last_event_index).select     = 1;
                events(last_event_index).epochs     = ones(1, length(events(last_event_index).samples));
            end
        end
    end
    % Import this list
    sFile = import_events(sFile, [], events);

end


