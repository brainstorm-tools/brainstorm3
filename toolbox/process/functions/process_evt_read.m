function varargout = process_evt_read( varargin )
% PROCESS_EVT_READ: Read the values from one/several stim or response channels and detect triggers.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2012-2019

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
    % Accept zeros
    isAcceptZero = sProcess.options.zero.Value;
    
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
    events = Compute(sFile, ChannelMat, StimChan, EventsTrackMode, isAcceptZero);

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
function [events, EventsTrackMode] = Compute(sFile, ChannelMat, StimChan, EventsTrackMode, isAcceptZero)
    % Parse inputs
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
    % Progress bar
    isProgressBar = bst_progress('isVisible');
    if isProgressBar
        bst_progress('start', 'Import events', 'Reading events channels...', 0, nbBlocks);
    end

    trackPrev = [];
    % For each block
    for iBlock = 1:nbBlocks
        % Increment progress bar
        if isProgressBar
            bst_progress('inc', 1);
        end
        % === READ BLOCK ===
        % Get samples indices for this block
        samplesBlock = samplesBounds(1) + [(iBlock - 1) * blockLength, iBlock * blockLength - 1];
        samplesBlock(2) = min(samplesBlock(2), samplesBounds(2));
        % Read block of data
        [tracks, times] = in_fread(sFile, ChannelMat, 1, samplesBlock, iChannels);
        % Convert events values to uint16
        tracks = reshape(double(typecast(int16(tracks(:)), 'uint16')), size(tracks));

        % === ADD INITIAL STATE ===
        % Add the initial status of the tracks
        if isempty(trackPrev)
            tracks = [tracks(:,1), tracks];
        else
            tracks = [trackPrev, tracks];
        end
        % Saving ending state for next block
        trackPrev = tracks(:,end);

        % === SEPARATE TRACKS ===
        % Each bit of each channel is interpreted as a track
        switch lower(EventsTrackMode)
            case 'bit'
                tracks_tmp = [];
                tracks_name = {};
                for iTrack = 1:size(tracks, 1)
                    % Convert track in binary values
                    track_bin = double(fliplr(dec2bin(tracks(iTrack, :)))');
                    track_bin(track_bin == '0') = 0;
                    track_bin(track_bin == '1') = 1;
                    % Add those binary tracks to the list
                    tracks_tmp = [tracks_tmp; track_bin];
                    % Save name of the tracks
                    for iBit = 1:size(track_bin, 1)
                        if (length(StimChan) > 1)
                            tracks_name{end+1} = sprintf('%s_%d', StimChan{iTrack}, iBit);
                        else
                            tracks_name{end+1} = sprintf('%d', iBit);
                        end
                    end
                end
                tracks = tracks_tmp;
            case 'value'
                tracks_name = StimChan;
            case {'ttl', 'rttl'}
                tracks_name = StimChan;
                tracks = abs(round(tracks));
                tracks(tracks ~= 0) = 1;
        end

        % === GET EVENTS ===
        % Get the changes on each track
        diffTrack = diff(tracks, [], 2);
        % Remove intial state from tracks
        tracks(:,1) = [];
        % Process each track separately
        for iTrack = 1:size(tracks, 1)
            % Get the samples where something happens
            if strcmpi(EventsTrackMode, 'rttl')
                iSmp = find((diffTrack(iTrack,:) ~= 0) & ((tracks(iTrack,:) == 0)));
            elseif isAcceptZero
                iSmp = find((diffTrack(iTrack,:) ~= 0));
            else
                iSmp = find((diffTrack(iTrack,:) ~= 0) & ((tracks(iTrack,:) ~= 0)));
            end
            % Process each change individually
            for i = 1:length(iSmp)
                % Build event name
                switch lower(EventsTrackMode)
                    case 'bit'
                        label = tracks_name{iTrack};
                    case 'value'
                        value = tracks(iTrack, iSmp(i));
                        if (length(StimChan) > 1)
                            label = sprintf('%s_%d', StimChan{iTrack}, value);
                        else
                            label = sprintf('%d', value);
                        end
                    case {'ttl', 'rttl'}
                        label = StimChan{iTrack};
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
                    events(iEvent).channels   = {};
                    events(iEvent).notes      = {};
                end
                % Add occurrence of this event
                iOcc = length(events(iEvent).times) + 1;
                events(iEvent).epochs(iOcc)   = 1;
                events(iEvent).times(iOcc)    = (iSmp(i) + samplesBlock(1) - 1) ./ sFile.prop.sfreq;
                events(iEvent).channels{iOcc} = {};
                events(iEvent).notes{iOcc}    = [];
            end
        end
    end

    % Close progress bar
    if isProgressBar
        bst_progress('stop');
    end
end




