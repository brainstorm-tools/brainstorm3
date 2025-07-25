function [sFile, newEvents] = import_events(sFile, ChannelMat, EventFile, FileFormat, EventName, isInteractive, isDelete)
% IMPORT_EVENTS: Reads events from a file/structure and add them to a Brainstorm raw file structure.
%
% USAGE:  [sFile, newEvents] = import_events(sFile, ChannelMat=[], EventFile, FileFormat, EventName, isInteractive=1, isDelete=0)
%         [sFile, newEvents] = import_events(sFile, ChannelMat=[], EventMat)
%         [sFile, newEvents] = import_events(sFile, ChannelMat=[])  : Opens a dialog box to select the file
% 
% NOTE:  ChannelMat is used only for CTF VideoTime

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
% Authors: Francois Tadel, 2010-2023

%% ===== PARSE INPUTS =====
if (nargin < 7) || isempty(isDelete)
    isDelete = 0;
end
if (nargin < 6) || isempty(isInteractive)
    isInteractive = 1;
end
if (nargin < 5) || isempty(EventName)
    EventName = [];
end
% CALL:  import_events(sFile, [], EventMat)
if (nargin >= 3) && isstruct(EventFile)
    newEvents = EventFile;
    EventFile = [];
    FileFormat = [];
% CALL:  import_events(sFile, ChannelMat)
elseif (nargin < 4)
    EventFile = [];
    FileFormat = [];
    newEvents = [];
% CALL:  import_events(sFile, ChannelMat, EventFile, FileFormat)
else
    newEvents = [];
end
if (nargin < 2) || isempty(ChannelMat)
    ChannelMat = [];
end

%% ===== SELECT FILE =====
if isempty(EventFile) && isempty(newEvents)
    % Get raw path
    [fPath, fBase, fExt] = bst_fileparts(sFile.filename);
    % Get default directories and formats
    %defFileFormat = upper(sFile.format);
    % Get default directories and formats
    DefaultFormats = bst_get('DefaultFormats');
    % Get file
    [EventFiles, FileFormat] = java_getfile( 'open', 'Import events...', ...    % Window title
        fPath, ...                % Default directory
        'multiple', 'files', ...  % Selection mode
        bst_get('FileFilters', 'events'), ...
        DefaultFormats.EventsIn);
    % If no file was selected: exit
    if isempty(EventFiles)
        return
    end
    % Save default export format
    DefaultFormats.EventsIn = FileFormat;
    bst_set('DefaultFormats',  DefaultFormats);
    
    % Call this function recursively for each selected event file, and
    % concatenate the result together
    for iEventFile = 1:length(EventFiles)
        [sFile, events] = import_events(sFile, ChannelMat, EventFiles{iEventFile}, FileFormat, EventName);
        if isempty(newEvents)
            newEvents = events;
        else
            newEvents(end+1:end+length(events)) = events;
        end
    end
    return
end

%% ===== READ FILE =====
if isempty(newEvents)
    % Start progress bar
    isProgress = ~bst_progress('isVisible');
    if isProgress
        bst_progress('start', 'Import events', 'Initializing...');
    end
    bst_progress('text', 'Loading events file...');
    % Switch according to file format
    switch (FileFormat)
        case 'ANT'
            newEvents = in_events_ant(sFile, EventFile);
        case 'BESA'
            newEvents = in_events_besa(sFile, EventFile);
        case 'BIDS'
            newEvents = in_events_bids(sFile, EventFile);
        case 'BRAINAMP'
            newEvents = in_events_brainamp(sFile, ChannelMat, EventFile);
        case 'BST'
            FileMat = load(EventFile);
            % Add missing fields if required
            FileMat.events = struct_fix_events(FileMat.events);
            % Convert structure to local structure
            newEvents = repmat(db_template('event'), 1, length(FileMat.events));
            for iEvt = 1:length(FileMat.events)
                for f = fieldnames(newEvents(1))'
                    newEvents(iEvt).(f{1}) = FileMat.events(iEvt).(f{1});
                end
            end
        case 'FIF'
            newEvents = in_events_fif(sFile, EventFile);
        case 'CARTOOL'
            newEvents = in_events_cartool(sFile, EventFile);
        case 'CTF'
            newEvents = in_events_ctf(sFile, EventFile);
        case 'CURRY'
            newEvents = in_events_curry(sFile, EventFile);
        case 'NEUROSCAN'
            newEvents = in_events_neuroscan(sFile, EventFile);
        case 'OEBIN'
            newEvents = in_events_oebin(sFile, EventFile);
        case 'GRAPH'
            newEvents = in_events_graph(sFile, EventFile);
        case 'TRL'
            newEvents = in_events_trl(sFile, EventFile);
        case 'KIT'
            newEvents = in_events_kit(sFile, EventFile);
        case 'RICOH'
            newEvents = in_events_ricoh(sFile, EventFile);
        case 'KDF'
            newEvents = in_events_kdf(sFile, EventFile);
        case 'PRESENTATION'
            newEvents = in_events_presentation(sFile, EventFile);
        case 'NICOLET'
            newEvents = in_events_nicolet(sFile, EventFile);
        case 'MICROMED'
            newEvents = in_events_micromed(sFile, EventFile);
        case 'XLTEK'
            newEvents = in_events_xltek(sFile, EventFile);
        case 'ARRAY-TIMES'
            newEvents = in_events_array(sFile, EventFile, 'times', EventName, isInteractive);
        case 'ARRAY-SAMPLES'
            newEvents = in_events_array(sFile, EventFile, 'samples', EventName, isInteractive);
        case 'CSV-TIME'
            newEvents = in_events_csv(sFile, EventFile);
        case 'CTFVIDEO'
            newEvents = in_events_video(sFile, ChannelMat, EventFile);
        case 'ANYWAVE'
            newEvents = in_events_anywave(sFile, EventFile);
        otherwise
            error('Unsupported file format.');
    end
    % Progress bar
    if isProgress
        bst_progress('stop');
    end
    % If no new events: return
    if isInteractive && isempty(newEvents)
        bst_error('No events found in this file.', 'Import events', 0);
        return
    end
end
% Fix events structure
if ~isempty(newEvents)
    newEvents = struct_fix_events(newEvents);
end
if ~isempty(sFile.events)
    sFile.events = struct_fix_events(sFile.events);
end
% Delete existing events if requested
if isDelete && ~isempty(newEvents) && ~isempty(sFile.events)
    sFile.events = [];
end

%% ===== MERGE EVENTS LISTS =====
% Add each new event
for iNew = 1:length(newEvents)
    % Look for an existing event
    if ~isempty(sFile.events)
        iEvt = find(strcmpi(newEvents(iNew).label, {sFile.events.label}));
    else
        iEvt = [];
    end
    % Make sure that the sample indices are round values
    newEvents(iNew).times = round(newEvents(iNew).times * sFile.prop.sfreq) ./ sFile.prop.sfreq;
    % If event does not exist yet: add it at the end of the list
    if isempty(iEvt)
        if isempty(sFile.events)
            iEvt = 1;
            sFile.events = newEvents(iNew);
        else
            iEvt = length(sFile.events) + 1;
            sFile.events(iEvt) = newEvents(iNew);
        end
    % Event exists: merge occurrences
    else
        % Convert new event type if required
        sizeTimeWindow = size(sFile.events(iEvt).times, 1);
        sizeNewTimeWindow = size(newEvents(iNew).times, 1);
        if sizeTimeWindow ~= sizeNewTimeWindow
            if sizeTimeWindow == 1
                % Convert to single event
                disp(['BST> Warning: Event type of "', ...
                     sFile.events(iEvt).label, ...
                     '" inconsistent, converting to single event using start time.']);
                newEvents(iNew).times = newEvents(iNew).times(1,:);
            else
                % Convert to extended event
                disp(['BST> Warning: Event type of "', ...
                     sFile.events(iEvt).label, ...
                     '" inconsistent, converting to extended event.']);
                newEvents(iNew).times = [newEvents(iNew).times; newEvents(iNew).times + 0.001];
            end
        end
        % Expand 'channels' field for event occurrences if needed
        if ~isempty(sFile.events(iEvt).channels) || ~isempty(newEvents(iNew).channels)
            if isempty(sFile.events(iEvt).channels)
                sFile.events(iEvt).channels = cell(1, size(sFile.events(iEvt).times, 2));
            end
            if isempty(newEvents(iNew).channels)
                newEvents(iNew).channels = cell(1, size(newEvents(iNew).times, 2));
            end
        end
        % Expand 'notes' field for event occurrences if needed
        if ~isempty(sFile.events(iEvt).notes) || ~isempty(newEvents(iNew).notes)
            if isempty(sFile.events(iEvt).notes)
                sFile.events(iEvt).notes = cell(1, size(sFile.events(iEvt).times, 2));
            end
            if isempty(newEvents(iNew).notes)
                newEvents(iNew).notes = cell(1, size(newEvents(iNew).times, 2));
            end
        end
        % Merge events occurrences
        sFile.events(iEvt).times      = [sFile.events(iEvt).times, newEvents(iNew).times];
        sFile.events(iEvt).epochs     = [sFile.events(iEvt).epochs, newEvents(iNew).epochs];
        sFile.events(iEvt).reactTimes = [sFile.events(iEvt).reactTimes, newEvents(iNew).reactTimes];
        sFile.events(iEvt).channels   = [sFile.events(iEvt).channels, newEvents(iNew).channels];
        sFile.events(iEvt).notes      = [sFile.events(iEvt).notes, newEvents(iNew).notes];
        % Sort by time
        if (size(sFile.events(iEvt).times, 2) > 1)
            [tmp__, iSort] = unique(bst_round(sFile.events(iEvt).times(1,:), 9));
            sFile.events(iEvt).times   = sFile.events(iEvt).times(:,iSort);
            sFile.events(iEvt).epochs  = sFile.events(iEvt).epochs(iSort);
            if ~isempty(sFile.events(iEvt).reactTimes)
                sFile.events(iEvt).reactTimes = sFile.events(iEvt).reactTimes(iSort);
            end
            if ~isempty(sFile.events(iEvt).channels)
                sFile.events(iEvt).channels = sFile.events(iEvt).channels(iSort);
            end
            if ~isempty(sFile.events(iEvt).notes)
                sFile.events(iEvt).notes = sFile.events(iEvt).notes(iSort);
            end
        end
    end
    % Add color if does not exist yet
    if isempty(sFile.events(iEvt).color)
        % Get the default color for this new event
        % sFile.events(iEvt).color = panel_record('GetNewEventColor', iEvt, sFile.events);
        
        % Same code, but without dependencies
        AllEvents = sFile.events;
        ColorTable = ...
            [0     1    0   
            .4    .4    1
             1    .6    0
             0     1    1
            .56   .01  .91
             0    .5    0
            .4     0    0
             1     0    1
            .02   .02   1
            .5    .5   .5];
        % Attribute the first color that of the colortable that is not in the existing events
        for iColor = 1:length(ColorTable)
            if isempty(AllEvents) || ~isstruct(AllEvents) || ~any(cellfun(@(c)isequal(c, ColorTable(iColor,:)), {AllEvents.color}))
                break;
            end
        end
        % If all the colors of the color table are taken: attribute colors cyclically
        if (iColor == length(ColorTable))
            iColor = mod(iEvt-1, length(ColorTable)) + 1;
        end
        sFile.events(iEvt).color = ColorTable(iColor,:);
    end
end

% Merge channels for simultaneous channelwise events
for iEvt = 1:length(sFile.events)
    if isempty(sFile.events(iEvt).channels)
        % Noting to merge
        continue
    end
    iOcc = find(~cellfun(@isempty, sFile.events(iEvt).channels));
    if numel(iOcc) < 2
        % Noting to merge
        continue
    end
    % Only for events with channel info
    [~, ics, ias] = unique(bst_round(sFile.events(iEvt).times(:,iOcc)', 9), 'rows', 'stable');
    for ic = 1 : numel(ics)
        irep = iOcc(ias == ic);
        if numel(irep) < 2
            continue
        end
        % Merge channels if there are not Notes, or all Notes are the same for repeated occurrences
        if isempty(sFile.events(iEvt).notes) || isequal(sFile.events(iEvt).notes{irep})
            % Merge channels in first occurrence
            sFile.events(iEvt).channels{irep(1)} = unique([sFile.events(iEvt).channels{irep}]);
            % Delete merged occurences
            sFile.events(iEvt).channels(irep(2:end)) = [];
            sFile.events(iEvt).times(:, irep(2:end)) = [];
            sFile.events(iEvt).epochs(irep(2:end))   = [];
            if ~isempty(sFile.events(iEvt).notes)
                sFile.events(iEvt).notes(irep(2:end)) = [];
            end
            if ~isempty(sFile.events(iEvt).reactTimes)
                sFile.events(iEvt).reactTimes(irep(2:end)) = [];
            end
        end
    end
end

% %% ===== SORT EVENTS BY LABEL =====
% [tmp__, iSort] = sort({sFile.events.label});
% sFile.events = sFile.events(iSort);
    





