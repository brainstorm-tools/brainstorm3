function [DataMat, ChannelMat] = in_data_xdf(DataFile)
% IN_DATA_XDF: Read XDF files.
% 
% REFERENCE:  https://github.com/xdf-modules/xdf-Matlab
%             https://github.com/sccn/xdf/wiki/Specifications

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
%          Raymundo Cassani, 2025


%% ===== INSTALL XDF PLUGIN =====
[isInstalled, errMsg] = bst_plugin('Install', 'xdf');
if ~isInstalled
    error(errMsg);
end


%% ===== LOAD DATA =====
% Load file
[streams, fileheader] = load_xdf(DataFile);

% Get stream mandatory elements
parsed_streams = repmat(struct('srate',        0,  ...
                               'nChannels',    0,  ...
                               'format',       '', ...
                               'name',         '', ...
                               'type',         '', ...
                               'channelNames', {}, ...
                               'channelTypes', {}, ...
                               'data',         [], ...
                               'timeVector',   [], ...
                               'timeFirst',    [], ...
                               'timeLast',     [], ...
                               'isContinuous', 0), 1, length(streams));

% Parse each stream
for iStream = 1:length(streams)
    stream = streams{iStream};
    % === Mandatory elements
    % <nominal_rate>
    parsed_streams(iStream).srate = str2double(stream.info.nominal_srate);
    if parsed_streams(iStream).srate ~= 0
        % The stream is considered continuous (regular sampling) if the nominal srate is non-zero
        parsed_streams(iStream).isContinuous = 1;
        % If possible, replace srate with effective_srate or srate derived from timestamps
        if isfield(stream.info, 'effective_srate') && ~isempty(stream.info.effective_srate)
            parsed_streams(iStream).srate = stream.info.effective_srate;
        else
            parsed_streams(iStream).srate = (length((stream.time_stamps)) - 1) / (stream.time_stamps(end) - stream.time_stamps(1));
        end
    end
    % <channel_count>
    parsed_streams(iStream).nChannels = str2double(stream.info.channel_count);
    % <channel_format>
    parsed_streams(iStream).format = stream.info.channel_format;
    % === Some optional elements
    %<name>
    if isfield(stream.info, 'name')
        parsed_streams(iStream).name = stream.info.name;
    end
    %<type>
    if isfield(stream.info, 'type')
        parsed_streams(iStream).type = stream.info.type;
    end
    % === Channel description
    for iChan = 1 : parsed_streams(iStream).nChannels
        if isfield(stream.info, 'desc')
            % Channel <label>
            if isfield(stream.info.desc, 'channels') && isfield(stream.info.desc.channels.channel{iChan}, 'label') && ~isempty(stream.info.desc.channels.channel{iChan}.label)
                parsed_streams(iStream).channelNames{end+1} = [parsed_streams(iStream).name '_' stream.info.desc.channels.channel{iChan}.label];
            else
                % Generate channel name
                if strcmpi(parsed_streams(iStream).format, 'string')
                    % String channel
                    channel_prefix = 'Str';
                else
                    % Numeric channel
                    channel_prefix = 'E';
                end
                parsed_streams(iStream).channelNames{end+1} = [parsed_streams(iStream).name '_' sprintf('%s%02d', channel_prefix, length(parsed_streams(iStream).channelNames)+1)];
            end
            % Channel <type>
            if isfield(stream.info.desc, 'channels') && isfield(stream.info.desc.channels.channel{iChan}, 'type') && ~isempty(stream.info.desc.channels.channel{iChan}.type)
                parsed_streams(iStream).channelTypes{end+1} = stream.info.desc.channels.channel{iChan}.type;
            else
                % Use stream type as channel type
                parsed_streams(iStream).channelTypes{end+1} = parsed_streams(iStream).type;
            end
        end
    end
end

% Get data and timeVector for each Stream
for iStream = 1:length(parsed_streams)
    % Skip non-continuous streams
    if ~parsed_streams(iStream).isContinuous
        continue
    end
    % Get data
    parsed_streams(iStream).data = streams{iStream}.time_series;
    if ~iscell(parsed_streams(iStream).data)
        parsed_streams(iStream).data = double(parsed_streams(iStream).data);
    end
    % Time vector
    % time_stamps are already synced across streams (in load_xdf.m)
    parsed_streams(iStream).timeVector = streams{iStream}.time_stamps;
    parsed_streams(iStream).timeFirst  = parsed_streams(iStream).timeVector(1);
    parsed_streams(iStream).timeLast   = parsed_streams(iStream).timeVector(end);
end

% Find common time vector, and highest sampling rate
iCont = find([parsed_streams.srate] > 0);
if isempty(iCont)
    error('No continuous streams found.');
end
% Find the highest sampling rate and resample all the streams on it
[maxRate, iMax] = max([parsed_streams(iCont).srate]);
% Range of recording
minTimeCommon = parsed_streams(iCont(iMax)).timeFirst;
maxTimeCommon = parsed_streams(iCont(iMax)).timeLast;
% Initialize full data matrix
nChannelsTotal = sum([parsed_streams(iCont).nChannels]);
% Number of samples (the stream with the maximum)
nTime = size(parsed_streams(iCont(iMax)).data, 2);
F = zeros(nChannelsTotal, nTime);
% Common time vector
timeVector = (0:nTime-1) ./ maxRate;
% Event structure for string streams that are not type 'Marker'
sEventsStringSteams = repmat(db_template('event'), [1, 0]);

iF = 0;
for iStream = 1:length(parsed_streams)
    parsed_stream = parsed_streams(iStream);
    % Skip non-continuous streams
    if ~parsed_stream.isContinuous
        continue
    end
    % Check that streams are aligned at Start and End
    isSameIni = abs(parsed_stream.timeFirst - minTimeCommon) < (1/parsed_stream.srate);
    isSameFin = abs(parsed_stream.timeLast  - maxTimeCommon) < (1/parsed_stream.srate);
    strInfo = '';
    if ~isSameIni && ~isSameFin
        strInfo = 'Start and End ';
    elseif ~isSameIni
        strInfo = 'Start ';
    elseif ~isSameFin
        strInfo = 'End ';
    end
    if ~isempty(strInfo)
        error([strInfo, 'for stream "' parsed_stream.name '"not aligned with stream "' parsed_streams(iCont(iMax)).name '"']);
    end
    sz = size(parsed_stream.data);
    % String streams are stored as Events, which channels full of zeros
    if strcmpi(parsed_stream.format, 'string')
        % For string streams, make a channel full of zeros
        F(iF+(1:sz(1)), :) = zeros(sz(1), nTime);
        % Generate event structures
        for iChannel = 1 : parsed_stream.nChannels
            ix = bst_closest(parsed_stream.timeVector - parsed_stream.timeFirst, timeVector);
            sEventsStringSteams(end+1).label  = parsed_stream.channelNames{iChannel};
            sEventsStringSteams(end).epochs   = ones(1, length(ix));
            sEventsStringSteams(end).times    = timeVector(ix);
            sEventsStringSteams(end).channels = repmat({parsed_stream.channelNames(iChannel)}, 1, length(ix));
            sEventsStringSteams(end).notes    = parsed_stream.data(iChannel, :);
        end

    % Numeric streams
    else
        if sz(2) == nTime
            F(iF+(1:sz(1)), :) = parsed_stream.data;
        else
            for iChan = 1:sz(1)
                F(iF + iChan, :) = interp1(parsed_stream.timeVector - parsed_stream.timeFirst, parsed_stream.data(iChan, :), timeVector, 'linear', 0);
            end
        end
    end
    iF = iF + sz(1);
end

% Get filename
[fPath, fBase, fExt] = bst_fileparts(DataFile);
% Initialize returned structure
DataMat = db_template('DataMat');
DataMat.F        = F;
DataMat.Time     = timeVector;
DataMat.Comment  = fBase;
DataMat.Device   = 'BIOPAC';
DataMat.DataType = 'recordings';
DataMat.nAvg     = 1;
DataMat.Events   = sEventsStringSteams;


%% ===== CHANNEL FILE =====
% No bad channels defined in those files: all good
DataMat.ChannelFlag = ones(nChannelsTotal, 1);
% Default channel structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'XDF channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, nChannelsTotal]);
allChannelNames = [parsed_streams(iCont).channelNames];
allChannelTypes = [parsed_streams(iCont).channelTypes];
% For each channel
for i = 1:nChannelsTotal
    ChannelMat.Channel(i).Name    = allChannelNames{i};
    ChannelMat.Channel(i).Type    = allChannelTypes{i};
    ChannelMat.Channel(i).Loc     = [];
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Weight  = 1;
    ChannelMat.Channel(i).Comment = [];
end


%% ===== EVENTS =====
events = repmat(db_template('event'), [1, 0]);
% Convert the non-continuous 'Markers' streams to events
for iStream = 1:length(parsed_streams)
    parsed_stream = parsed_streams(iStream);
    if ~all([~parsed_stream.isContinuous,            ...
            strcmpi(parsed_stream.type, 'Markers'), ...
            ~isempty(parsed_stream.timeVector),     ...
            ~isempty(parsed_stream.data), ~iscell(parsed_stream.data)])
        continue;
    end
    % Create one marker per value
    uniqueVal = unique(parsed_stream.data(1,:));
    for iUnique = 1:length(uniqueVal)
        iEvt = length(events) + 1;
        % Find all the occurrences of event #iEvt
        iOcc = find(cellfun(@(c)isequal(c, uniqueVal{iUnique}), parsed_stream.data(1,:)));
        % Add event structure
        events(iEvt).label   = uniqueVal{iUnique};
        events(iEvt).epochs  = ones(1, length(iOcc));
        ix = bst_closest(parsed_stream.timeVector(iOcc) - parsed_stream.timeFirst, timeVector);
        events(iEvt).times = timeVector(ix);
    end
end

% Add events
if ~isempty(events)
    DataMat.Events = [DataMat.Events, events];
end


