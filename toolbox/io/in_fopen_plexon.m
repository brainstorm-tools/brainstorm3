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

newHeader = readPLXFileC(DataFile,'events');   % THE LASTTIMESTAMP IS WRONG !!!!. SAME FOR ADFREQUENCY


% Check for some important fields
if ~isfield(newHeader, 'NumSpikeChannels') || ~isfield(newHeader, 'ContinuousChannels')
    error('Missing fields in the file header');
end


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% % THE LASTTIMESTAMP and ADFREQUENCY fields are wrong.
% Load one channel file and get them from there.

one_channel = readPLXFileC(DataFile,'continuous',0);
newHeader.ADFrequency   = one_channel.ContinuousChannels(1).ADFrequency;
newHeader.LastTimestamp = length(one_channel.ContinuousChannels(1).Values);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



% Extract information needed for opening the file
hdr.FirstTimeStamp    = 0;
hdr.LastTimeStamp     = newHeader.LastTimestamp*newHeader.ADFrequency;
hdr.NumSamples        = newHeader.LastTimestamp; % newHeader.LastTimestamp is in samples. Brainstorm header is in seconds.
hdr.extension         = extension;
hdr.SamplingFrequency = newHeader.ADFrequency; 

% Get only the channels from electrodes, not auxillary channels %% FIX THIS ON A LATER VERSION
just_recording_channels = newHeader.SpikeChannels;

% Assign important fields
hdr.chan_headers = just_recording_channels;
hdr.ChannelCount = length(hdr.chan_headers);


%% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder = 'l';
sFile.filename  = hdr.BaseFolder;  %!!!!!!!!!!!!!!!
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
for i = 1:hdr.ChannelCount
    ChannelMat.Channel(i).Name    = just_recording_channels(i).Name;
    ChannelMat.Channel(i).Loc     = [0; 0; 0];
    ChannelMat.Channel(i).Type    = 'EEG';
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Weight  = 1;
    ChannelMat.Channel(i).Comment = [];
end


%% ===== READ EVENTS =====
% Events are saved in the file Events.nev
if isfield(newHeader, 'EventChannels')
        
    unique_events = 0;
    for i = 1:length(newHeader.EventChannels)
        if ~isempty(newHeader.EventChannels(i).Values)
            unique_events = unique_events + 1;
        end
    end
    
    % Initialize list of events
    events = repmat(db_template('event'), 1, unique_events);
    
    % Format list
    iNotEmptyEvents = 0;
    
    for iEvt = 1:length(newHeader.EventChannels)
        if ~isempty(newHeader.EventChannels(iEvt).Timestamps)
            iNotEmptyEvents = iNotEmptyEvents + 1;
            % Fill the event fields
            events(iNotEmptyEvents).label      = newHeader.EventChannels(iNotEmptyEvents).Name;
            events(iNotEmptyEvents).color      = rand(1,3);
            events(iNotEmptyEvents).samples    = newHeader.EventChannels(iNotEmptyEvents).Timestamps';
            events(iNotEmptyEvents).times      = events(iNotEmptyEvents).samples * hdr.SamplingFrequency;
            events(iNotEmptyEvents).reactTimes = [];
            events(iNotEmptyEvents).select     = 1;
            events(iNotEmptyEvents).epochs     = ones(1, length(events(iNotEmptyEvents).samples));
        end
    end
    % Import this list
    sFile = import_events(sFile, [], events);
end
end


