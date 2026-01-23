function varargout = process_evt_channelinfo( varargin )
% PROCESS_EVT_CHANNELINFO: Updates the channel info for event groups
%
% USAGE:  OutputFiles = process_evt_channelinfo('Run', sProcess, sInput)

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
% Authors: Raymundo Cassani, 2025

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Set channel info';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 64;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/EventMarkers#Other_menus';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    % Description
    sProcess.options.info.Comment = ['Set the channel info for all occurrences for the indicated event names.<BR>' ...
                                     'Channel info will be <B>replaced</B>, be careful as there is not undo.<BR><BR>'];
    sProcess.options.info.Type    = 'label';
    sProcess.options.info.Value   = [];
    % Event names
    sProcess.options.eventname.Comment = 'Event names:';
    sProcess.options.eventname.Type    = 'text';
    sProcess.options.eventname.Value   = '';
    % Channel names
    sProcess.options.channelname.Comment = 'Channel names: (empty = All channels)';
    sProcess.options.channelname.Type    = 'text';
    sProcess.options.channelname.Value   = '';
    % Suffix to append to backup events name
    sProcess.options.suffix.Comment = 'Backup suffix: ';
    sProcess.options.suffix.Type    = 'text';
    sProcess.options.suffix.Value   = '';
    sProcess.options.suffix.Group   = 'output';
     % Explanations
    sProcess.options.comment1.Comment = '<FONT color="#707070"><I>If a suffix is set, event "A" is copied to "A-suffix" before being modified.</I></FONT>';
    sProcess.options.comment1.Type    = 'label';
    sProcess.options.comment1.Group   = 'output';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFile = Run(sProcess, sInput) %#ok<DEFNU>
    % Return all the input files
    OutputFile = {sInput.FileName};

    % ===== GET OPTIONS =====
    % Get events to be processed
    EvtNames = strtrim(str_split(sProcess.options.eventname.Value, ',;'));
    ChanNames = strtrim(str_split(sProcess.options.channelname.Value, ',;'));
    Suffix = sProcess.options.suffix.Value;

    % Event names
    if isempty(EvtNames)
        bst_report('Error', sProcess, sInput, 'No events selected.');
        return;
    end
    isRaw = strcmpi(sInput.FileType, 'raw');
    if isRaw
        DataMat = in_bst_data(sInput.FileName, 'F', 'History');
        sEvents = DataMat.F.events;
    else
        DataMat = in_bst_data(sInput.FileName, 'Events', 'Time', 'History');
        sEvents = DataMat.Events;
    end
    if isempty(sEvents)
        bst_report('Error', sProcess, sInput, 'No events to process.');
        return;
    end
    % Find event names
    iEvts = [];
    for i = 1:length(EvtNames)
        iEvt = find(strcmpi(EvtNames{i}, {sEvents.label}));
        if ~isempty(iEvt)
            iEvts(end+1) = iEvt;
        else
            bst_report('Warning', sProcess, sInput, ['This file does not contain any event "' EvtNames{i} '".']);
        end
    end
    % Find channel names
    if isempty(ChanNames)
        chanInfo = [];
    else
        ChannelMat = in_bst_channel(sInput.ChannelFile);
        [isChan, iChans] = ismember(ChanNames, {ChannelMat.Channel.Name});
        if any(~isChan)
            bst_report('Error', sProcess, sInput, ...
                ['Channel names: "' strjoin(ChanNames(~isChan), ',') '" are not in the channel file.']);
            return
        end
        chanInfo = {{ChannelMat.Channel(iChans).Name}};
    end

    % ===== PROCESS EVENTS =====
    for i = 1:length(iEvts)
        % No suffix: Overwrite existing events
        if isempty(Suffix)
            iEvt = iEvts(i);
        % Suffix: Create new events
        else
            iEvt = length(sEvents) + 1;
            sEvents(iEvt) = sEvents(iEvts(i));
            sEvents(iEvts(i)).label = file_unique([sEvents(iEvts(i)).label, '-', Suffix], {sEvents.label});
        end
        % Edit channel info
        if isempty(chanInfo)
            sEvents(iEvt).channels = chanInfo;
        else
            sEvents(iEvt).channels = repmat(chanInfo, 1, size(sEvents(iEvt).times, 2));
        end
    end

    % ===== SAVE RESULT =====
    % Report results
    if isRaw
        DataMat.F.events = sEvents;
    else
        DataMat.Events = sEvents;
    end

    % Add history entry
    chanInfoStr = '[]';
    if ~isempty(chanInfo)
        chanInfoStr = strjoin(ChanNames, ',');
    end
    DataMat = bst_history('add', DataMat, 'channelinfo', [sprintf('Updated channel info "%s" to events: ', chanInfoStr), sprintf('%s ', EvtNames{:})]);
    % Only save changes if something was change
    bst_save(file_fullpath(sInput.FileName), DataMat, 'v6', 1);
end
