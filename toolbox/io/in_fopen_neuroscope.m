function [sFile, ChannelMat] = in_fopen_neuroscope(DataFile)
% IN_FOPEN_NEUROSCOPE: Open a NeuroScope/Klusters LFP .eeg/.dat file

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
% Authors: Francois Tadel, 2014
        

%% ===== READ HEADER =====
% Get file type
[fPath, fBase, fExt] = bst_fileparts(DataFile);
if strcmpi(fExt, '.dat')
    hdr.isDat = 1;
    XmlFile = strrep(DataFile, '.dat', '.xml');
elseif strcmpi(fExt, '.eeg')
    hdr.isDat = 0;
    XmlFile = strrep(DataFile, '.eeg', '.xml');
else
    error('Input file must have a .eeg or .dat extension.');
end
% If doesn't exist: error
if ~file_exist(XmlFile)
    error('Cannot open file: Missing .xml header file');
end
% Read header
sXml = in_xml(XmlFile);
% Read interesting information
try
    hdr.nBits     = str2num(sXml.parameters.acquisitionSystem.nBits.text);
    hdr.nChannels = str2num(sXml.parameters.acquisitionSystem.nChannels.text);
    hdr.sRateOrig = str2num(sXml.parameters.acquisitionSystem.samplingRate.text);
    hdr.Gain      = str2num(sXml.parameters.acquisitionSystem.amplification.text);
    hdr.sRateLfp  = str2num(sXml.parameters.fieldPotentials.lfpSamplingRate.text);
catch
    error(['Cannot open file: Missing information in .xml header file.' 10 lasterr()]);
end
% Get data type
switch lower(hdr.nBits)
    case 16;
        hdr.byteSize   = 2;
        hdr.byteFormat = 'int16';
    case 32;
        hdr.byteSize   = 4;
        hdr.byteFormat = 'int32';
end
% Guess the number of time points based on the file size
dirInfo = dir(DataFile);
hdr.nSamples = floor(dirInfo.bytes ./ (hdr.nChannels * hdr.byteSize));


%% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder  = 'l';
sFile.filename   = DataFile;
sFile.format     = 'EEG-NEUROSCOPE';
sFile.comment    = [fBase, fExt];
sFile.condition  = [fBase, fExt];
sFile.device     = 'LFP';
sFile.header     = hdr;
% Consider that the sampling rate of the file is the sampling rate of the first signal
if hdr.isDat
    sFile.prop.sfreq = hdr.sRateOrig;
else
    sFile.prop.sfreq = hdr.sRateLfp;
end
sFile.prop.times = [0, hdr.nSamples - 1] ./ sFile.prop.sfreq;
sFile.prop.nAvg  = 1;
% No info on bad channels
sFile.channelflag = ones(hdr.nChannels, 1);


%% ===== CREATE EMPTY CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'NeuroScope channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, hdr.nChannels]);
% For each channel
for i = 1:hdr.nChannels
    ChannelMat.Channel(i).Name = sprintf('E%d', i);
    ChannelMat.Channel(i).Loc = [0; 0; 0];
    ChannelMat.Channel(i).Type    = 'EEG';
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Weight  = 1;
    ChannelMat.Channel(i).Comment = [];
end


%% ===== READ SPIKE EVENTS =====
% Find all the .res files
dirres = dir(fullfile(fPath, [fBase, '*.res*']));
% Read each file
for iFile = 1:length(dirres)
    % Build filenames
    ResFile = fullfile(fPath, dirres(iFile).name);
    CluFile = strrep(ResFile, '.res', '.clu');
    if ~file_exist(CluFile)
        CluFile = [];
    end
    % Read spike times
    fid = fopen(ResFile, 'r');
    if (fid < 0)
        continue;
    end
    spikeSmp = fscanf(fid,'%d')';
    fclose(fid);
    % Read spike clusters
    if ~isempty(CluFile)
        fid = fopen(CluFile, 'r');
        if (fid < 0)
            continue;
        end
        nClusters = fscanf(fid, '%d', 1);
        spikeClu = fscanf(fid,'%d')';
        fclose(fid);
        % Remove clusters artifact and noise clusters (0 & 1)
        iRemove = find(spikeClu <= 1);
        if ~isempty(iRemove)
            spikeClu(iRemove) = [];
            spikeSmp(iRemove) = [];
        end
    else
        spikeClu = [];
    end
    % Nothing in this file: next
    if isempty(spikeSmp)
        continue;
    end
    % For the .eeg file: convert spike samples from original sampling rate to LFP sampling rate
    if ~hdr.isDat
        spikeSmp = round((spikeSmp ./ hdr.sRateOrig) .* hdr.sRateLfp);
    end
    % If the clusters are defined: One event per cluster
    if ~isempty(spikeClu)
        % Get list of clusters
        uniqueClu = unique(spikeClu);
        % Initialize list of events
        events = repmat(db_template('event'), 1, length(uniqueClu));
        % One event per cluster
        for iClu = 1:length(uniqueClu)
            iTime = find(spikeClu == uniqueClu(iClu));
            events(iClu).label      = sprintf('C%dS%d', uniqueClu(iClu), iFile);
            events(iClu).color      = [];
            events(iClu).reactTimes = [];
            events(iClu).select     = 1;
            events(iClu).times      = spikeSmp(iTime) ./ sFile.prop.sfreq;
            events(iClu).epochs     = ones(1, length(iTime));
            events(iClu).channels   = [];
            events(iClu).notes      = [];
        end
    % No clusters: one event per file
    else
        events = db_template('event');
        events.label = sprintf('S%d', iFile);
        events.color      = [];
        events.reactTimes = [];
        events.select     = 1;
        events.times      = spikeSmp ./ sFile.prop.sfreq;
        events.epochs     = ones(1, length(spikeSmp));
        events.channels   = [];
        events.notes      = [];
    end
    % Import this list
    sFile = import_events(sFile, [], events);
end



