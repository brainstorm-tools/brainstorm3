function [sFile, ChannelMat] = in_fopen_blackrock(DataFile)
% IN_FOPEN_BLACKROCK Open Blackrock NeuroPort recordings (.nev and .nsX).
% 
% DESCRIPTION:
%     Reading these files requires the Blackrock NPMK toolbox in the Matlab path:
%         https://github.com/BlackrockMicrosystems/NPMK/releases
%
%     Description of the files that this function can read:
%         - *.nev:  Event markers and spiking information
%         - *.ns1:  Continuous LFP data sampled at 500 Hz
%         - *.ns2:  Continuous LFP data sampled at 1 KHz
%         - *.ns3:  Continuous LFP data sampled at 2 KHz
%         - *.ns4:  Continuous LFP data sampled at 10 KHz
%         - *.ns5:  Continuous LFP data sampled at 30 KHz
%     Description of the Blackrock files on the FieldTrip website: 
%         http://www.fieldtriptoolbox.org/getting_started/blackrock
        
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
% Authors: Francois Tadel, 2015

%% ===== CHECK FOR NPMK TOOLBOX =====
if ~exist('openNSx', 'file')
    error(['Reading Blackrock files requires the NPMK toolbox:' 10 ...
           ' - Download the latest at: https://github.com/BlackrockMicrosystems/NPMK/releases' 10 ...
           ' - Add the NPMK folder and sub-folders to your Matlab path.']);
end


%% ===== READ HEADER =====
[fPath, fBase, fExt] = bst_fileparts(DataFile);
% Try to get .nev file with similar name
NevFile = bst_fullfile(fPath, [fBase, '.nev']);
if ~file_exist(NevFile)
    disp(['Event file could not be found: ' NevFile]);
    NevFile = [];
end
% Disable the 'uV' warning (otherwise 'noread' and 'uv' are incompatible, and we have a necessary input from the command line)
disp('BST> Disabling NPMKSettings:ShowuVWarning...');
NPMKSettings = settingsManager;
NPMKSettings.ShowuVWarning = 0;
settingsManager(NPMKSettings);
% Read the firs two samples of the file to get the header information
rec = openNSx(DataFile, 'noread');
% Read useful information from there
hdr = rec.MetaTags;
% Display warning when there are multiple records
if (length(hdr.DataPoints))
    disp(['BST> WARNING: The file "' DataFile '" contains ' num2str(length(hdr.DataPoints)) ' blocks of recordings.' 10 '     All the data blocks will appear concatenated in Brainstorm.']);
end


%% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder = 'l';
sFile.filename  = DataFile;
sFile.format    = 'EEG-BLACKROCK';
sFile.device    = 'Blackrock';
sFile.header    = hdr;
sFile.comment   = [fBase, fExt];
% Consider that the sampling rate of the file is the sampling rate of the first signal
sFile.prop.sfreq   = hdr.SamplingFreq;
sFile.prop.times   = [0, sum(hdr.DataPoints) - 1] ./ sFile.prop.sfreq;
sFile.prop.nAvg    = 1;
% No info on bad channels
sFile.channelflag = ones(hdr.ChannelCount, 1);


%% ===== CREATE EMPTY CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'Blackrock channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, hdr.ChannelCount]);
% For each channel
for i = 1:hdr.ChannelCount
    chname = rec.ElectrodesInfo(i).Label;
    chname(chname == 0) = [];
    ChannelMat.Channel(i).Name    = strtrim(chname);
    ChannelMat.Channel(i).Loc     = [0; 0; 0];
    ChannelMat.Channel(i).Type    = 'EEG';
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Weight  = 1;
    ChannelMat.Channel(i).Comment = strtrim(rec.ElectrodesInfo(i).Type);
end


%% ===== READ EVENTS =====
% Events are saved in the .nev file
if ~isempty(NevFile)
    % Read the NEV file
    nev = openNEV('read', NevFile, 'nomat', 'nosave');
    % Initialize list of events
    events = repmat(db_template('event'), 0);
    % Time factor 
    tFactor = double(rec.MetaTags.SamplingFreq) / double(nev.MetaTags.TimeRes);
    % Get spike event BST prefix
    spikeEventPrefix = process_spikesorting_supervised('GetSpikesEventPrefix');
    
    % Use spikes
    if ~isempty(nev.Data.Spikes.TimeStamp)
        % Get on which electrode the spike is happening
        uniqueType = unique(nev.Data.Spikes.Electrode);
        % Create one group per electrode
        for i = 1:length(uniqueType)
            iEvt = length(events) + 1;
            iOcc = (nev.Data.Spikes.Electrode == uniqueType(i));
            events(iEvt).label      = sprintf([spikeEventPrefix ' raw %d'], uniqueType(i));
            events(iEvt).color      = [];
            events(iEvt).reactTimes = [];
            events(iEvt).select     = 1;
            events(iEvt).times      = round((double(nev.Data.Spikes.TimeStamp(iOcc)) - 1) * tFactor) ./ sFile.prop.sfreq;
            events(iEvt).epochs     = ones(1, length(iOcc));
            events(iEvt).channels   = cell(1, size(events(iEvt).times, 2));
            events(iEvt).notes      = cell(1, size(events(iEvt).times, 2));
        end
    end
    
    % Use digitial IO
    if ~isempty(nev.Data.SerialDigitalIO.TimeStamp)
        % Get on which electrode the spike is happening
        allTypes = [nev.Data.SerialDigitalIO.Type', nev.Data.SerialDigitalIO.Value'];
        uniqueType = unique(allTypes, 'rows');
        % Create one group per electrode
        for i = 1:size(uniqueType,1)
            iEvt = length(events) + 1;
            iOcc = ((allTypes(:,1) == uniqueType(i,1)) & (allTypes(:,2) == uniqueType(i,2)));
            events(iEvt).label      = sprintf('%d-%d', uniqueType(i,1), uniqueType(i,2));
            events(iEvt).color      = [];
            events(iEvt).reactTimes = [];
            events(iEvt).select     = 1;
            events(iEvt).times      = round((double(nev.Data.SerialDigitalIO.TimeStamp(iOcc)) - 1) * tFactor) ./ sFile.prop.sfreq;
            events(iEvt).epochs     = ones(1, length(iOcc));
            events(iEvt).channels   = cell(1, size(events(iEvt).times, 2));
            events(iEvt).notes      = cell(1, size(events(iEvt).times, 2));
        end
    end
    
    % Use comments
    if ~isempty(nev.Data.Comments.TimeStamp)
        % Get on which electrode the spike is happening
        uniqueType = unique({nev.Data.Comments.Text});
        % Create one group per electrode
        for i = 1:length(uniqueType)
            iEvt = length(events) + 1;
            iOcc = strcmpi({nev.Data.Comments.Text}, uniqueType{i});
            events(iEvt).label      = strtrim(uniqueType{i});
            events(iEvt).color      = [];
            events(iEvt).reactTimes = [];
            events(iEvt).select     = 1;
            events(iEvt).times      = round((double(nev.Data.Comments.TimeStamp(iOcc)) - 1) * tFactor) ./ sFile.prop.sfreq;
            events(iEvt).epochs     = ones(1, length(iOcc));
            events(iEvt).channels   = cell(1, size(events(iEvt).times, 2));
            events(iEvt).notes      = cell(1, size(events(iEvt).times, 2));
        end
    end
    
    % Use patient triggers
    if ~isempty(nev.Data.PatientTrigger.TimeStamp)
        % Get on which electrode the spike is happening
        uniqueType = unique(nev.Data.PatientTrigger.TriggerType);
        % Create one group per electrode
        for i = 1:length(uniqueType)
            iEvt = length(events) + 1;
            iOcc = (nev.Data.PatientTrigger.TriggerType == uniqueType(i));
            events(iEvt).label      = sprintf('T%d', uniqueType(i));
            events(iEvt).color      = [];
            events(iEvt).reactTimes = [];
            events(iEvt).select     = 1;
            events(iEvt).times      = round((double(nev.Data.PatientTrigger.TimeStamp(iOcc)) - 1) * tFactor) ./ sFile.prop.sfreq;
            events(iEvt).epochs     = ones(1, length(iOcc));
            events(iEvt).channels   = cell(1, size(events(iEvt).times, 2));
            events(iEvt).notes      = cell(1, size(events(iEvt).times, 2));
        end
    end

    % Import all the identified events
    if ~isempty(events)
        sFile = import_events(sFile, [], events);
    end
end


% Add events to indicate block separations
if (length(hdr.DataPoints) > 1)
    events = repmat(db_template('event'), 1, length(hdr.DataPoints));
    timeBlocks = [0, cumsum(hdr.DataPoints(1:end-1)) - 1] ./ sFile.prop.sfreq;
    for iEvt = 1:length(hdr.DataPoints)
        events(iEvt).label      = sprintf('Block%02d', iEvt);
        events(iEvt).color      = [];
        events(iEvt).reactTimes = [];
        events(iEvt).select     = 1;
        events(iEvt).times      = timeBlocks(iEvt);
        events(iEvt).epochs     = 1;
        events(iEvt).channels   = {[]};
        events(iEvt).notes      = {[]};
    end
    sFile = import_events(sFile, [], events);
end

