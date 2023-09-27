function varargout = process_evt_read( varargin )
% PROCESS_EVT_READ: Read the values from one/several stim or response channels and detect triggers.

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
% Authors: Francois Tadel, 2012-2021
%          Raymundo Cassani, 2022
%          Marc Lalancette, 2022

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Read from channel';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 40;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/StimDelays?highlight=%28Read+events+from+channel%29#Detection_of_the_button_responses';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Option: Stim channels
    sProcess.options.stimchan.Comment = 'Event channels: ';
    sProcess.options.stimchan.Type    = 'text';
    sProcess.options.stimchan.Value   = '';
    % Option: Value/Bit
    sProcess.options.trackmode.Comment = {'Value: detect the changes of channel value', ...
                                          'Bit: detect the changes for each bit independently', ...
                                          'TTL: detect peaks of 5V/12V on an analog channel (baseline=0V)', ...
                                          'RTTL: detect peaks of 0V on an analog channel (baseline!=0V)'};
    sProcess.options.trackmode.Type    = 'radio';
    sProcess.options.trackmode.Value   = 1;
    % Option: Accept zeros
    sProcess.options.zero.Comment = 'Accept zeros as trigger values';
    sProcess.options.zero.Type    = 'checkbox';
    sProcess.options.zero.Value   = 0;
    % Option: Min event duration
    sProcess.options.min_duration.Comment = 'Reject events shorter than: ';
    sProcess.options.min_duration.Type    = 'value';
    sProcess.options.min_duration.Value   = {0, 'samples', 0};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput) %#ok<DEFNU>
    % Return all the input files
    OutputFiles = {};
    
    % ===== GET OPTIONS =====
    % Stim channel not specified
    StimChan = sProcess.options.stimchan.Value;
    if isempty(StimChan)
        bst_report('Error', sProcess, [], 'Event channel was not specified.');
        return
    end
    % Event type
    switch (sProcess.options.trackmode.Value)
        case 1,  EventsTrackMode = 'value';
        case 2,  EventsTrackMode = 'bit';
        case 3,  EventsTrackMode = 'ttl';
        case 4,  EventsTrackMode = 'rttl';
    end
    % Other options
    isAcceptZero = sProcess.options.zero.Value;
    MinDuration = sProcess.options.min_duration.Value{1};
    
    % ===== GET FILE DESCRIPTOR =====
    % Load the raw file descriptor
    isRaw = strcmpi(sInput.FileType, 'raw');
    if isRaw
        DataMat = in_bst_data(sInput.FileName, 'F');
        sFile = DataMat.F;
    else
        sFile = in_fopen(sInput.FileName, 'BST-DATA');
    end
    % Load channel file
    ChannelMat = in_bst_channel(sInput.ChannelFile);
    % Check if specified channels are available
    iChannels = channel_find(ChannelMat.Channel, StimChan);
    if isempty(iChannels) 
        bst_report('Error', sProcess, sInput, ['Channel name(s) "' StimChan '" does not exist.']);
        return
    end
        
    % ===== DETECTION =====
    % CTF: Read separately upper and lower bytes
    if ismember(sFile.format, {'CTF', 'CTF-CONTINUOUS'})
        % Detect separately events on the upper and lower bytes of the STIM channel
        eventsU = Compute(sFile, ChannelMat, [StimChan '__U'], EventsTrackMode, isAcceptZero, MinDuration);
        eventsL = Compute(sFile, ChannelMat, [StimChan '__L'], EventsTrackMode, isAcceptZero, MinDuration);
        % If there are events on both: add marker U/L
        if ~isempty(eventsU) && ~isempty(eventsL)
            for iEvt = 1:length(eventsU)
                eventsU(iEvt).label = ['U', eventsU(iEvt).label];
            end
            for iEvt = 1:length(eventsL)
                eventsL(iEvt).label = ['L', eventsL(iEvt).label];
            end
        end
        events = [eventsL, eventsU];
    else
        events = Compute(sFile, ChannelMat, StimChan, EventsTrackMode, isAcceptZero, MinDuration);
    end
    
    % ===== SAVE RESULT =====
    % Only save changes if something was change
    if ~isempty(events)
        % Import new events in file structure
        sFile = import_events(sFile, [], events);
        % Report changes in .mat structure
        if isRaw
            DataMat.F = sFile;
        else
            DataMat.Events = sFile.events;
        end
        % Save file definition
        bst_save(file_fullpath(sInput.FileName), DataMat, 'v6', 1);
        % Report number of detected events
        bst_report('Info', sProcess, sInput, sprintf('%s: %d events detected in %d categories', StimChan, size([events.times],2), length(events)));
    end
    % Return all the input files
    OutputFiles{end+1} = sInput.FileName;
end



%% ===== COMPUTE =====
function [events, EventsTrackMode, StimChan] = Compute(sFile, ChannelMat, StimChan, EventsTrackMode, isAcceptZero, MinDuration)
    % Parse inputs
    if (nargin < 6)
        MinDuration = 0;
    end
    if (nargin < 5)
        isAcceptZero = 0;
    end
    if (nargin < 4)
        EventsTrackMode = 'ask';
    end
    if (nargin < 3)
        StimChan = [];
    end
    % Get some information
    ch_names = {ChannelMat.Channel.Name};
    samplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
    events = [];

    % ===== GET STIM CHANNEL =====
    if isempty(StimChan) || isequal(StimChan, 'ask') || isequal(StimChan, {'ask'})
        % Find possible event channels
        switch (sFile.format)
            case 'FIF'
                % Channel name must contains 'STI'
                iStiChan = find(~cellfun(@isempty, strfind(ch_names, 'STI')));
            case '4D'
                % TRIGGER Channels
                iStiChan = channel_find(ChannelMat.Channel, 'Stim');
            case {'CTF', 'CTF-CONTINUOUS'}
                % TRIGGER Channels
                iStiChan = channel_find(ChannelMat.Channel, 'Stim');
            case 'KDF'
                % Status Channel
                iStiChan = channel_find(ChannelMat.Channel, 'KDF');
            case 'EEG-BDF'
                % Status Channel
                iStiChan = channel_find(ChannelMat.Channel, 'BDF');
        end
        % No valid events channel
        if isempty(iStiChan)
            bst_error('No valid events channel found in this file.', 'Read events', 0);
            return
        end
        % If only one choice: select it by default
        if (length(iStiChan) == 1)
            StimChan = ch_names(iStiChan);
        % Else: offer multiple choices to the user
        else
            StimChan = java_dialog('checkbox', ...
                ['You can try to rebuild the events list using one or more technical tracks, or ' 10 ...
                 'ignore this step and process the file as continuous recordings without events.' 10 10 ...
                 'Available technical tracks: '], ...
                 'Read events', [], ch_names(iStiChan));
            if isempty(StimChan)
                events = [];
                return
            end
        end
    end
    % CTF: Select only upper or lower bytes
    isCtfUp = 0;
    isCtfLow = 0;
    if ismember(sFile.format, {'CTF', 'CTF-CONTINUOUS'}) && (length(StimChan) > 3)
        if strcmp(StimChan(end-2:end), '__U')
            isCtfUp = 1;
            StimChan = StimChan(1:end-3);
        elseif strcmp(StimChan(end-2:end), '__L')
            isCtfLow = 1;
            StimChan = StimChan(1:end-3);
        end
    end

    % ===== ASK READ MODE =====
    if strcmpi(EventsTrackMode, 'ask')
        res = java_dialog('question', ['<HTML>Please select the interpretation mode at each time sample: <BR><BR>' ...
                                       '- <B>Value</B>: detect the changes of value on the trigger channel<BR>' ...
                                       '- <B>Bit</B>: detect the changes for each bit of the channel independently<BR>' ...
                                       '- <B>TTL</B>: detect peaks of 5V/12V on an analog channel (baseline=0V)<BR>' ...
                                       '- <B>RTTL</B>: detect peaks of 0V on an analog channel (baseline!=0V)<BR>' ...
                                       '- <B>Ignore</B>: do not read trigger channel<BR><BR>'], ...
                                       'Type of events', [], {'Value','Bit','TTL','RTTL','Ignore','Cancel'}, 'value');
        if isempty(res) || strcmpi(res, 'Cancel')
            events = -1;
            return
        end
        EventsTrackMode = lower(res);
    end
    % Ignore trigger channel
    if strcmpi(EventsTrackMode, 'ignore')
        return;
    end

    % ===== READ STIM CHANNELS =====
    % Intialize returned events structure
    events = repmat(db_template('event'), 0);
    % Get channel indices
    iChannels = channel_find(ChannelMat.Channel, StimChan);
    if isempty(iChannels)
        disp(['EVENTS> Error: Channel name(s) "' StimChan '" does not exist.']);
    end
    StimChan = {ChannelMat.Channel(iChannels).Name};
    % Define optimal block size for reading
    blockLength = 6000;
    % Adapt block size to FIF block size
    if strcmpi(sFile.format, 'FIF') && isfield(sFile.header, 'raw') && isfield(sFile.header.raw, 'rawdir') && ~isempty(sFile.header.raw.rawdir)
        fifBlockSize = double(sFile.header.raw.rawdir(1).nsamp);
        blockLength = fifBlockSize * max(1, round(blockLength / fifBlockSize));
    end
    % Process by blocks (if not: out of memory)
    totalLength = (samplesBounds(2) - samplesBounds(1) + 1);
    nbBlocks = ceil(totalLength / blockLength);
    % Progress bar, channels
    isProgressBar = bst_progress('isVisible');
    bst_progress('start', 'Import events', 'Reading events channels...', 0, length(iChannels) * nbBlocks);

    tracks_name = {};
    tracks_vals = {};
    tracks_smps = {};
    % Process each channel
    for iChannel = 1 : length(iChannels)
        % Increment progress bar
        track_prev = [];
        track_vals = [];
        track_smps = [];
        % Progress bar, blocks
        bst_progress('text', ['Reading events in channel ' StimChan{iChannel} ' ...']);
        for iBlock = 1:nbBlocks
            % Increment progress bar
            bst_progress('inc', 1);
            % === READ BLOCK ===
            % Get samples indices for this block
            samplesBlock = samplesBounds(1) + [(iBlock - 1) * blockLength, iBlock * blockLength - 1];
            samplesBlock(2) = min(samplesBlock(2), samplesBounds(2));
            % Read block of data
            [track, ~] = in_fread(sFile, ChannelMat, 1, samplesBlock, iChannels(iChannel));
            % Round values
            track = fix(track);
            % Keep only track changes
            if iBlock == 1
                track_smps(1) = 1;
                track_vals(1) = track(1);
                track_prev = track(1);
            end
            % === KEEP ALL CHANGES ===
            ixDiffTrack = find(diff([track_prev, track]));
            track_vals = [track_vals, track(ixDiffTrack)];
            track_smps = [track_smps, samplesBlock(1) + ixDiffTrack];
            % Saving ending state for next block
            track_prev = track(end);
        end

        % CTF: Read separately Upper and Lower bytes
        if ismember(sFile.format, {'CTF', 'CTF-CONTINUOUS'})
            % Events are read as int32, while they are actually uint32: fix negative values
            track_vals(track_vals<0) = track_vals(track_vals<0) + 2^32;
            % Keep only upper or lower bytes
            if isCtfUp
                track_vals = fix(track_vals / 2^16);
            elseif isCtfLow
                track_vals = double(bitand(uint32(track_vals), 2^16-1));
            end
        % Other formats
        else
            % Old code: Might be useless and/or detrimental to the reading of the events
            % tracks = reshape(double(typecast(int16(tracks(:)), 'uint16')), size(tracks));
            % Use the same fix as for CTF files
            track_vals(track_vals<0) = track_vals(track_vals<0) + 2^32;
        end

        % === SEPARATE TRACKS ===
        % Each bit of each channel is interpreted as a track
        switch lower(EventsTrackMode)
            case 'bit'
                % Convert track in binary values
                track_bin = double(fliplr(dec2bin(track_vals))');
                track_bin(track_bin == '0') = 0;
                track_bin(track_bin == '1') = 1;
                nBit = size(track_bin, 1);
                tracks_bit_name = cell(1, nBit);
                tracks_bit_vals = cell(1, nBit);
                tracks_bit_smps = cell(1, nBit);
                % Data for each binary track
                for iBit = 1 : nBit
                    if (length(StimChan) > 1)
                        tracks_bit_name{iBit} = sprintf('%s_%d', StimChan{iChannel}, iBit);
                    else
                        tracks_bit_name{iBit} = sprintf('%d', iBit);
                    end
                    % Keep changes in each binary tracks
                    ixDiffTrackBit = find(diff([track_prev, track_bin(iBit, :)]));
                    tracks_bit_vals{iBit} = track_bin(iBit, ixDiffTrackBit);
                    tracks_bit_smps{iBit} = track_smps(ixDiffTrackBit);
                end
                % Append to other tracks
                tracks_name = [tracks_name, tracks_bit_name];
                tracks_vals = [tracks_vals, tracks_bit_vals];
                tracks_smps = [tracks_smps, tracks_bit_smps];
            case 'value'
                tracks_name{end+1} = StimChan{iChannel};
                tracks_vals{end+1} = track_vals;
                tracks_smps{end+1} = track_smps;
            case {'ttl', 'rttl'}
                tracks_name{end+1} = StimChan{iChannel};
                track_vals = abs(round(track_vals));
                track_vals(track_vals ~= 0) = 1;
                tracks_vals{end+1} = track_vals;
                tracks_smps{end+1} = track_smps;
        end
    end

    % === PROCESS EACH TRACK SEPARATELY ===
    nTooShort = 0;
    for iTrack = 1:length(tracks_name)
        % Get the indices where something happens
        if strcmpi(EventsTrackMode, 'rttl')
            ixs = find(tracks_vals{iTrack} == 0);
        elseif isAcceptZero
            ixs = 1 : length(tracks_vals{iTrack});
        else
            ixs = find(tracks_vals{iTrack} ~= 0);
        end
        % Process each change individually
        for i = 1:length(ixs)
            if i < length(ixs)
                % Skip if shorter than MinDuration
                duration_i = tracks_smps{iTrack}(ixs(i)+1) - tracks_smps{iTrack}(ixs(i));
                if (MinDuration > 0) && (duration_i < MinDuration)
                    nTooShort = nTooShort + 1;
                    % Pass start sample to next event longer than MinDuration
                    tracks_smps{iTrack}(ixs(i)+1) = tracks_smps{iTrack}(ixs(i));
                    continue;
                end
            end
            % Build event name
            switch lower(EventsTrackMode)
                case 'bit'
                    label = tracks_name{iTrack};
                    if (MinDuration == 0) && isAcceptZero
                        if tracks_vals{iTrack}(ixs(i)) == 1
                            label = [label '-set'];
                        else
                            label = [label '-reset'];
                        end
                    end
                case 'value'
                    value = tracks_vals{iTrack}(ixs(i));
                    if (length(StimChan) > 1)
                        label = sprintf('%s_%d', tracks_name{iTrack}, value);
                    else
                        label = sprintf('%d', value);
                    end
                case {'ttl', 'rttl'}
                    label = tracks_name{iTrack};
            end
            % Find this event in list of events
            if ~isempty(events)
                iEvent = find(strcmpi({events.label}, label));
            else
                iEvent = [];
            end
            % If event does not exist yet: add it
            if isempty(iEvent)
                iEvent = length(events) + 1;
                events(iEvent).label      = label;
                events(iEvent).epochs     = [];
                events(iEvent).times      = [];
                events(iEvent).reactTimes = [];
                events(iEvent).select     = 1;
                events(iEvent).channels   = [];
                events(iEvent).notes      = [];
            end
            % Add occurrence of this event
            iOcc = length(events(iEvent).times) + 1;
            events(iEvent).epochs(iOcc)   = 1;
            events(iEvent).times(iOcc)    = (tracks_smps{iTrack}(ixs(i))-1) ./ sFile.prop.sfreq;
        end
    end
    % Display warning with removed events
    if (nTooShort > 0)
        disp(sprintf('BST> %d events shorter than %d sample(s) removed.', nTooShort, MinDuration));
    end
    % Close progress bar
    if ~isProgressBar
        bst_progress('stop');
    end
end
