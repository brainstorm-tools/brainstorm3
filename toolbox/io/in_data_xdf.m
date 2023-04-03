function [DataMat, ChannelMat] = in_data_xdf(DataFile)
% IN_DATA_XDF: Read XDF files.
% 
% REFERENCE:  https://github.com/xdf-modules/xdf-Matlab

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
% Authors: Francois Tadel, 2022


%% ===== INSTALL XDF PLUGIN =====
[isInstalled, errMsg] = bst_plugin('Install', 'xdf');
if ~isInstalled
    error(errMsg);
end


%% ===== LOAD DATA =====
% Load file
[streams, fileheader] = load_xdf(DataFile);

% Get sampling rates (0=discrete data) and channel names
srates = zeros(1, length(streams));
nChannels = zeros(1, length(streams));
chNames = {};
chTypes = {};
for iStream = 1:length(streams)
    stream = streams{iStream};
    % The stream is considered continuous if the nominal srate is non-zero
    if str2double(stream.info.nominal_srate) == 0
        srates(iStream) = 0;
    elseif isfield(stream.info, 'effective_srate') && ~isempty(stream.info.effective_srate)
        srates(iStream) = stream.info.effective_srate;
    else
        srates(iStream) = (length((stream.time_stamps)) - 1) / (stream.time_stamps(end) - stream.time_stamps(1));
    end
    % Do not consider as data channel if srate=0
    if (srates(iStream) == 0)
        continue;
    end
    % Number of signals in this stream
    nChannels(iStream) = size(stream.time_series, 1);
    for iChan = 1:nChannels(iStream)
        if isfield(stream.info.desc, 'channels') && isfield(stream.info.desc.channels.channel{iChan}, 'label') && ~isempty(stream.info.desc.channels.channel{iChan}.label)
            chNames{end+1} = [stream.info.name '_' stream.info.desc.channels.channel{iChan}.label];
        else
            chNames{end+1} = [stream.info.name '_' sprintf('E%02d', length(chNames)+1)];
        end
        if isfield(stream.info.desc, 'channels') && isfield(stream.info.desc.channels.channel{iChan}, 'type') && ~isempty(stream.info.desc.channels.channel{iChan}.type)
            chTypes{end+1} = stream.info.desc.channels.channel{iChan}.type;
        else
            chTypes{end+1} = 'EEG';
        end
    end
end

% Find continuous channels
iCont = find(srates > 0);
if isempty(iCont)
    error('No continuous streams found.');
end
% Find the highest sampling rate and resample all the streams on it
[maxRate, iMax] = max(srates(iCont));
% Initialize full data matrix
nChannels = length(chNames);
nTime = size(streams{iCont(iMax)}.time_series, 2);
F = zeros(nChannels, nTime);
% Fill data matrix
iF = 0;
for iStream = iCont
    sz = size(streams{iStream}.time_series);
    % Correct number of samples
    if sz(2) == nTime
        F(iF + 1:sz(1), :) = streams{iStream}.time_series;
    % Requires resampling
    else
        error('TODO: Please post a message on the Brainstorm user forum and share this XDF file as an example.');
        for iChan = 1:sz(1)
            F(iF + iChan, :) = interp1(linspace(0,1,sz(2)), streams{iStream}.time_series, linspace(0,1,nTime));
        end
    end
    iF = iF + sz(1);
end

% Get filename
[fPath, fBase, fExt] = bst_fileparts(DataFile);
% Initialize returned structure
DataMat = db_template('DataMat');
DataMat.F        = F;
DataMat.Time     = (0:nTime-1) ./ maxRate;
DataMat.Comment  = fBase;
DataMat.Device   = 'BIOPAC';
DataMat.DataType = 'recordings';
DataMat.nAvg     = 1;


%% ===== CHANNEL FILE =====
% No bad channels defined in those files: all good
DataMat.ChannelFlag = ones(nChannels, 1);
% Default channel structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'XDF channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, nChannels]);
% For each channel
for i = 1:nChannels
    ChannelMat.Channel(i).Name    = chNames{i};
    ChannelMat.Channel(i).Type    = chTypes{i};
    ChannelMat.Channel(i).Loc     = [];
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Weight  = 1;
    ChannelMat.Channel(i).Comment = [];
end


%% ===== EVENTS =====
events = repmat(db_template('event'), [1, 0]);
tZero = streams{iCont(iMax)}.time_stamps(1);
% Convert the non-continuous streams to events
for iStream = find(srates == 0)
    s = streams{iStream};
    if ~strcmpi(s.info.type, 'Markers') || ~isfield(s, 'time_stamps') || ~isfield(s, 'time_series') || ~iscell(s.time_series)
        continue;
    end
    % Create one marker per value
    uniqueVal = unique(s.time_series(1,:));
    for iUnique = 1:length(uniqueVal)
        iEvt = length(events) + 1;
        % Find all the occurrences of event #iEvt
        iOcc = find(cellfun(@(c)isequal(c, uniqueVal{iUnique}), s.time_series(1,:)));
        % Add event structure
        events(iEvt).label   = uniqueVal{iUnique};   %  [s.info.name '_' uniqueVal{iUnique}]
        events(iEvt).epochs  = ones(1, length(iOcc));   
        samples = round((s.time_stamps(iOcc) - tZero) .* maxRate);
        events(iEvt).times      = samples ./ maxRate;
        events(iEvt).reactTimes = [];
        events(iEvt).select     = 1;
        events(iEvt).channels   = [];
        events(iEvt).notes      = [];
    end
end
if ~isempty(events)
    DataMat.Events = events;
end


