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
% Authors: Francois Tadel, 2015-2021


%% ===== INSTALL NPMK LIBRARY =====
if ~exist('openNSx', 'file')
    [isInstalled, errMsg] = bst_plugin('Install', 'blackrock');
    if ~isInstalled
        error(errMsg);
    end
end
openNSxVer = openNSx('ver');

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
readOptions = {};
NPMKSettings.ShowuVWarning = 0;
if isfield(NPMKSettings, 'ShowZeroPadWarning')
    NPMKSettings.ShowZeroPadWarning = 0;
    % 'nozeropad' is needed for verions before 7.4.4.0 (April 2023),
    % after that no zeropadding is the default behaviour and 'nozeropad' is not a valid argument
    if bst_plugin('CompareVersions', openNSxVer, '7.4.4.0') < 0
        readOptions{end+1} = 'nozeropad';
    end
end
settingsManager(NPMKSettings);
% Read the firs two samples of the file to get the header information
rec = openNSx(DataFile, 'noread', readOptions{:});
% Read useful information from there
hdr = rec.MetaTags;
% Display warning when there are multiple records
if (length(hdr.DataPoints) > 1)
    disp(['BST> WARNING: The file "' DataFile '" contains ' num2str(length(hdr.DataPoints)) ' blocks of recordings.']);
    disp('     All the data blocks will appear concatenated in Brainstorm, event latencies might be wrong.');
end
% Time factor
tFactorNsx = double(hdr.SamplingFreq) / double(hdr.TimeRes);
% Samples in real life (including discontinuities) / samples in the file (all blocks contiguous starting from 0)
hdr.RealSamples = round(double(hdr.Timestamp) * tFactorNsx);
hdr.FileSamples = [0, cumsum(hdr.DataPoints(1:end-1)) - 1];
% Some files have file Timestamp that are not usable here
if (length(hdr.RealSamples) > 1) && any(diff(hdr.RealSamples) <= 0)
    hdr.RealSamples = hdr.FileSamples;
end

%% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder = 'l';
sFile.filename  = DataFile;
sFile.format    = 'EEG-BLACKROCK';
sFile.device    = 'Blackrock';
sFile.header    = [];   % Not saving header, it can save a few Gb
sFile.comment   = [fBase, fExt];
% Consider that the sampling rate of the file is the sampling rate of the first signal
sFile.prop.sfreq   = hdr.SamplingFreq;
sFile.prop.times   = [0, sum(hdr.DataPoints) - 1] ./ sFile.prop.sfreq;
sFile.prop.nAvg    = 1;
% Acquisition time
sFile.acq_date = datestr(datenum(hdr.DateTime), 'dd-mmm-yyyy');
% No info on bad channels
nChannels = hdr.ChannelCount;
sFile.channelflag = ones(nChannels, 1);


%% ===== CREATE EMPTY CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'Blackrock channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, nChannels]);
% For each channel
for i = 1:nChannels
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
    tFactorNev = double(hdr.SamplingFreq) / double(nev.MetaTags.TimeRes);
    % Get spike event BST prefix
    spikeEventPrefix = panel_spikes('GetSpikesEventPrefix');
    
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
            events(iEvt).times      = FixSamples(hdr, round((double(nev.Data.Spikes.TimeStamp(iOcc)) - 1) * tFactorNev)) ./ sFile.prop.sfreq;
            events(iEvt).epochs     = ones(1, size(events(iEvt).times, 2));
            events(iEvt).channels   = [];
            events(iEvt).notes      = [];
        end
    end
    
    % Use digitial IO
    if ~isempty(nev.Data.SerialDigitalIO.TimeStamp)
        % Get events
        if ~isempty(nev.Data.SerialDigitalIO.Value) && ~isempty(nev.Data.SerialDigitalIO.Type)
            allTypes = [nev.Data.SerialDigitalIO.Type', nev.Data.SerialDigitalIO.Value'];
            isUnparsed = 0;
        elseif ~isempty(nev.Data.SerialDigitalIO.UnparsedData)
            eventCodes = double(nev.Data.SerialDigitalIO.UnparsedData);
            eventCodes = eventCodes - min(eventCodes);
            eventCodes(eventCodes == 0) = [];
            nev.Data.SerialDigitalIO.TimeStamp(eventCodes == 0) = [];
            allTypes = repmat(eventCodes(:), 1, 2);
            isUnparsed = 1;
        else
            allTypes = [];
        end
        uniqueType = unique(allTypes, 'rows');
        % Create one group per electrode
        for i = 1:size(uniqueType,1)
            iEvt = length(events) + 1;
            iOcc = ((allTypes(:,1) == uniqueType(i,1)) & (allTypes(:,2) == uniqueType(i,2)));
            if isUnparsed
                events(iEvt).label = sprintf('D%d', uniqueType(i,1));
            else
                events(iEvt).label = sprintf('%d-%d', uniqueType(i,1), uniqueType(i,2));
            end
            events(iEvt).color      = [];
            events(iEvt).reactTimes = [];
            events(iEvt).select     = 1;
            events(iEvt).times      = FixSamples(hdr, round((double(nev.Data.SerialDigitalIO.TimeStamp(iOcc)) - 1) * tFactorNev)) ./ sFile.prop.sfreq;
            events(iEvt).epochs     = ones(1, size(events(iEvt).times, 2));
            events(iEvt).channels   = [];
            events(iEvt).notes      = [];
        end
    end
    
    % Use comments
    if ~isempty(nev.Data.Comments.TimeStamp)
        % Get comment text
        if (length(nev.Data.Comments.TimeStamp) > 1)
            comments = mat2cell(nev.Data.Comments.Text, ones(1,size(nev.Data.Comments.Text,1)), size(nev.Data.Comments.Text,2))';
        else
            comments = {nev.Data.Comments.Text};
        end
        % Remove useless characters
        comments = cellfun(@(c)strtrim(c(c~=0)), comments, 'UniformOutput', 0);
        % Create one group of markers per comment
        uniqueType = unique(comments);
        for i = 1:length(uniqueType)
            iEvt = length(events) + 1;
            iOcc = strcmpi(comments, uniqueType{i});
            events(iEvt).label      = strtrim(uniqueType{i});
            events(iEvt).color      = [];
            events(iEvt).reactTimes = [];
            events(iEvt).select     = 1;
            events(iEvt).times      = FixSamples(hdr, round((double(nev.Data.Comments.TimeStamp(iOcc)) - 1) * tFactorNev)) ./ sFile.prop.sfreq;
            events(iEvt).epochs     = ones(1, size(events(iEvt).times, 2));
            events(iEvt).channels   = [];
            events(iEvt).notes      = [];
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
            events(iEvt).times      = FixSamples(hdr, round((double(nev.Data.PatientTrigger.TimeStamp(iOcc)) - 1) * tFactorNev)) ./ sFile.prop.sfreq;
            events(iEvt).epochs     = ones(1, size(events(iEvt).times, 2));
            events(iEvt).channels   = [];
            events(iEvt).notes      = [];
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
        events(iEvt).label      = sprintf('Block%02d-%1.3fs', iEvt, hdr.RealSamples(iEvt) ./ sFile.prop.sfreq);
        events(iEvt).color      = [];
        events(iEvt).reactTimes = [];
        events(iEvt).select     = 1;
        events(iEvt).times      = timeBlocks(iEvt);
        events(iEvt).epochs     = 1;
        events(iEvt).channels   = [];
        events(iEvt).notes      = [];
    end
    sFile = import_events(sFile, [], events);
end

end


%% ====== FIX TIMESTAMPS =====
% Adjust events samples when there are multiple recording blocks
function smp = FixSamples(hdr, smp)
    % Only one block: Nothing to fix
    if (length(hdr.RealSamples) == 1)
        return;
    end
    % Prepare a list of offsets for each sample
    smpOffset = zeros(size(smp));
    % Loop on all the blocks
    for iBlock = 1:length(hdr.RealSamples)
        % Get events in this block
        if (iBlock == length(hdr.RealSamples))
            blockSmp = (smp >= hdr.RealSamples(iBlock));
        else
            blockSmp = ((smp >= hdr.RealSamples(iBlock)) & (smp < hdr.RealSamples(iBlock+1)));
        end
        % Replace real time (including discontinuities) with file time (all blocks contiguous)
        smpOffset(blockSmp) = hdr.FileSamples(iBlock) - hdr.RealSamples(iBlock);
    end
    % Add offset
    smp = smp + smpOffset;
end


