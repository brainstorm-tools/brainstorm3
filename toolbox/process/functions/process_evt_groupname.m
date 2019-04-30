function varargout = process_evt_groupname( varargin )
% PROCESS_EVT_GROUPNAME: Combine different categories of events into one (by name)
%
% USAGE:  OutputFiles = process_evt_groupname('Run', sProcess, sInputs)

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
% Authors: Francois Tadel, 2013-2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Group by name';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 51;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/EventMarkers#Other_menus';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Event name
    sProcess.options.combine.Comment = ['Example: We have three events (A,B,C) and want to create new combinations:<BR>' ...
                                        '&nbsp;&nbsp;&nbsp;&nbsp;<B>E</B>: Event A and B occurring at the same time<BR>' ...
                                        '&nbsp;&nbsp;&nbsp;&nbsp;<B>F</B>: Event A and C occurring at the same time<BR>' ...
                                        'For that, use the following classification:<BR>' ...
                                        '&nbsp;&nbsp;&nbsp;&nbsp;<B>E</B> = A,B<BR>' ...
                                        '&nbsp;&nbsp;&nbsp;&nbsp;<B>F</B> = A,C<BR>' ...
                                        'You may add as many combinations as needed, one per line.<BR>' ...
                                        'You can rename events with the following syntax: <B>E</B>=A.<BR>' ...
                                        'You can delete or keep the original events (A,B,C) with the checkbox below.<BR><BR>'];
    sProcess.options.combine.Type    = 'textarea';
    sProcess.options.combine.Value   = '';
    % Maximum duration between simulateous events
    sProcess.options.dt.Comment = 'Maximum delay between simultaneous events: ';
    sProcess.options.dt.Type    = 'value';
    sProcess.options.dt.Value   = {0, 'ms', 0};
    % Delete original events
    sProcess.options.delete.Comment = 'Delete the original events';
    sProcess.options.delete.Type    = 'checkbox';
    sProcess.options.delete.Value   = 0;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Return all the input files
    OutputFiles = {};
    
    % ===== GET OPTIONS =====
    % Get the options
    isDelete = sProcess.options.delete.Value;
    dt = sProcess.options.dt.Value{1};
    % Combination string
    combineStr = strtrim(sProcess.options.combine.Value);
    % Split in lines
    combine_lines = str_split(combineStr, [10 13]);
    % Split each line
    combineCell = {};
    for i = 1:length(combine_lines)
        % No information on this line: skip
        combine_lines{i} = strtrim(combine_lines{i});
        if isempty(combine_lines{i})
            continue;
        end
        % Split with "="
        lineCell = str_split(combine_lines{i}, '=');
        if (length(lineCell) ~= 2)
            continue;
        end
        % Split with ";,"
        eventsCell = str_split(lineCell{2}, ';,');
        % Add combination entry
        iComb = size(combineCell,1) + 1;
        combineCell{iComb,1} = strtrim(lineCell{1});
        combineCell{iComb,2} = cellfun(@strtrim, eventsCell, 'UniformOutput', 0);
    end
    % If no combination available
    if isempty(combineCell)
        bst_report('Error', sProcess, [], 'Invalid combinations format.');
        return;
    end
    
    % ===== PROCESS ALL FILES =====
    % For each file
    for iFile = 1:length(sInputs)
        % ===== GET FILE DESCRIPTOR =====
        % Load the raw file descriptor
        isRaw = strcmpi(sInputs(iFile).FileType, 'raw');
        if isRaw
            DataMat = in_bst_data(sInputs(iFile).FileName, 'F');
            sFile = DataMat.F;
        else
            sFile = in_fopen(sInputs(iFile).FileName, 'BST-DATA');
        end
        % If no markers are present in this file
        if isempty(sFile.events)
            bst_report('Error', sProcess, sInputs(iFile), 'This file does not contain any event. Skipping File...');
            continue;
        end
        % Convert the distance in time to distance in samples
        ds = round(dt .* sFile.prop.sfreq);
        % Call the grouping function
        [sFile.events, isModified] = Compute(sInputs(iFile), sFile.events, combineCell, ds, isDelete, sFile.prop.sfreq);

        % ===== SAVE RESULT =====
        % Only save changes if something was change
        if isModified
            % Report changes in .mat structure
            if isRaw
                DataMat.F = sFile;
            else
                DataMat.Events = sFile.events;
            end
            % Save file definition
            bst_save(file_fullpath(sInputs(iFile).FileName), DataMat, 'v6', 1);
        end
        % Return all the input files
        OutputFiles{end+1} = sInputs(iFile).FileName;
    end
end


%% ===== GROUP EVENTS =====
function [eventsNew, isModified] = Compute(sInput, events, combineCell, ds, isDelete, sfreq)
    % No modification
    isModified = 0;
    eventsNew = events;
    removeEvt = zeros(0,2);
    % Loop on the different combinations
    for iComb = 1:size(combineCell,1)
        AllEvt = zeros(2,0);
        iEvtList = [];
        % Get events for this combination
        for iCombEvt = 1:length(combineCell{iComb,2})
            % Find event in the list
            evtLabel = combineCell{iComb,2}{iCombEvt};
            iEvt = find(strcmpi({events.label}, evtLabel));
            % If events are extended events: skip
            if isempty(iEvt)
                bst_report('Warning', 'process_evt_groupname', sInput, ['Event "' evtLabel '" does not exist. Skipping group...']);
                continue;
            end
            % If events are extended events: skip
            if (size(events(iEvt).times,1) > 1)
                bst_report('Error', 'process_evt_groupname', sInput, 'Cannot process extended events. Skipping group...');
                continue;
            end
            % Add to the list of all the processes
            iEvtList(end+1) = iEvt;
            AllEvt = [AllEvt, [round(events(iEvt).times .* sfreq); repmat(iEvt, size(events(iEvt).times))]];
        end
        % Skip combination if one of the events is not found or not a simple event
        if (length(iEvtList) ~= length(combineCell{iComb,2}))
            continue;
        end
        
        % Fix the events times according to the maximum allowed distance between events
        if (ds > 0)
            N = size(AllEvt,2);
            % Calculate distance between all the pairs of events: 
            % [alldist(i,j)=5] means that event #i is 5 samples before event #j
            alldist = repmat(AllEvt(1,:),N,1) - repmat(AllEvt(1,:)',1,N);
            % Get the distances for the different event types only: we don't want to collapse two events of the same category
            diffmask = (repmat(AllEvt(2,:),N,1) ~= repmat(AllEvt(2,:)',1,N));
            % Find the events that can be collapsed
            collapse = ((alldist > 0) & (alldist <= ds)) .* diffmask;
            collapse(:,sum(collapse,1) > 1) = 0;
            collapse(sum(collapse,2) > 1,:) = 0;
            [iBefore, iAfter] = find(collapse);
            % Remove cycles
            iCycles = find(ismember(iBefore, iAfter));
            iBefore(iCycles) = [];
            iAfter(iCycles) = [];
            % Replace the time of the last events with the time of the first event
            if ~isempty(iBefore)
                for iEvt = 1:length(iAfter)
                    smpBefore = round(events(AllEvt(2,iBefore(iEvt))).times .* sfreq);
                    smpAfter = round(events(AllEvt(2,iAfter(iEvt))).times .* sfreq);
                    iOccBefore = find(smpBefore == AllEvt(1,iBefore(iEvt)));
                    iOccAfter  = find(smpAfter == AllEvt(1,iAfter(iEvt)));
                    events(AllEvt(2,iAfter(iEvt))).times(iOccAfter) = events(AllEvt(2,iBefore(iEvt))).times(iOccBefore);
                end
                AllEvt(1,iAfter) = AllEvt(1,iBefore);
            end
        end
        
        % Process each unique time value
        uniqueSamples = unique(AllEvt(1,:));
        for iSmp = 1:length(uniqueSamples)
            % Look for all the events happening at this time
            iEvts = AllEvt(2, (AllEvt(1,:) == uniqueSamples(iSmp)));
            % If only one occurrence: skip to the next time
            if (length(iEvts) < length(iEvtList))
                continue;
            end
            % Remove occurrence from each event type (and build new event name)
            for i = 1:length(iEvts)
                % Find the occurrence indice
                iOcc = find(round(events(iEvts(i)).times .* sfreq) == uniqueSamples(iSmp));
                % Get the values 
                if (i == 1)
                    newTime     = events(iEvts(i)).times(iOcc);
                    newEpoch    = events(iEvts(i)).epochs(iOcc);
                    newChannels = events(iEvts(i)).channels(iOcc);
                    newNotes    = events(iEvts(i)).notes(iOcc);
                end
                % Remove this occurrence
                if isDelete
                    removeEvt(end+1,1:2) = [iEvts(i), iOcc];
                end
            end
            % New event name
            newLabel = combineCell{iComb,1};
            % Find this event in the list
            iNewEvt = find(strcmpi(newLabel, {eventsNew.label}));
            % Create event category if does not exist yet
            if isempty(iNewEvt)
                % Initialize new event
                iNewEvt = length(eventsNew) + 1;
                sEvent = db_template('event');
                sEvent.label = newLabel;
                % Re-use color of renamed event
                if (length(iEvtList) == 1) && isDelete
                    sEvent.color = events(iEvtList(1)).color;
                % Create a new color
                else
                    sEvent.color = panel_record('GetNewEventColor', iNewEvt, eventsNew);
                end
                % Add new event to list
                eventsNew(iNewEvt) = sEvent;
            end
            % Add occurrences
            eventsNew(iNewEvt).times    = [eventsNew(iNewEvt).times,    newTime];
            eventsNew(iNewEvt).epochs   = [eventsNew(iNewEvt).epochs,   newEpoch];
            eventsNew(iNewEvt).channels = [eventsNew(iNewEvt).channels, newChannels];
            eventsNew(iNewEvt).notes    = [eventsNew(iNewEvt).notes,    newNotes];            
            % Sort
            [eventsNew(iNewEvt).times, indSort] = unique(eventsNew(iNewEvt).times);
            eventsNew(iNewEvt).epochs   = eventsNew(iNewEvt).epochs(indSort);
            eventsNew(iNewEvt).channels = eventsNew(iNewEvt).channels(indSort);
            eventsNew(iNewEvt).notes    = eventsNew(iNewEvt).notes(indSort);
            isModified = 1;
        end
    end
    % Remove events that were tagged
    if ~isempty(removeEvt)
        uniqueEvt = unique(removeEvt(:,1));
        for i = 1:length(uniqueEvt)
            iEvt = uniqueEvt(i);
            iOcc = removeEvt(removeEvt(:,1)==iEvt,2)';
            eventsNew(iEvt).times(iOcc)    = [];
            eventsNew(iEvt).epochs(iOcc)   = [];
            eventsNew(iEvt).channels(iOcc) = [];
            eventsNew(iEvt).notes(iOcc)    = [];
        end
        % Remove empty categories
        iEmptyEvt = find(cellfun(@isempty, {eventsNew.times}));
        if ~isempty(iEmptyEvt)
            eventsNew(iEmptyEvt) = [];
        end
    end
end






