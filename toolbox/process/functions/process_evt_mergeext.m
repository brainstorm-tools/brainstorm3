function varargout = process_evt_mergeext( varargin )
% PROCESS_EVT_MERGEEXT: Merge expended events with same label if they overlap
%
% USAGE:  OutputFiles = process_evt_mergeext('Run', sProcess, sInputs)
%              events = process_evt_mergeext('Compute', events)

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
% Authors: Raymundo Cassani, 2026

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Merge overlapping extended events';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 54.5;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/EventMarkers#Other_menus';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data', 'matrix'};
    sProcess.OutputTypes = {'raw', 'data', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Event name
    sProcess.options.combine.Comment = 'Merge overlapping extended events within the same event group';
    sProcess.options.combine.Type    = 'label';
    sProcess.options.combine.Value   = [];
    % Event name
    sProcess.options.evtnames.Comment = 'Event names process (separated with commas):';
    sProcess.options.evtnames.Type    = 'text';
    sProcess.options.evtnames.Value   = '';
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

    % Get options
    EvtNames = strtrim(sProcess.options.evtnames.Value);
    isDelete = sProcess.options.delete.Value;
    % Split names
    if ~isempty(EvtNames)
        EvtNames = strtrim(str_split(EvtNames, ',;'));
    end

    % For each file
    for iFile = 1:length(sInputs)
        % ===== GET FILE DESCRIPTOR =====
        % Load the raw file descriptor
        isRaw = strcmpi(sInputs(iFile).FileType, 'raw');
        if isRaw
            DataMat = in_bst_data(sInputs(iFile).FileName, 'F');
            sEvents = DataMat.F.events;
        else
            DataMat = in_bst_data(sInputs(iFile).FileName, 'Events', 'Time');
            sEvents = DataMat.Events;
        end
        % Filter for extended events
        iEvtExt = find(cellfun(@(x) (size(x, 1) == 2), {sEvents.times}));
        % If no markers are present in this file
        if isempty(iEvtExt)
            bst_report('Error', sProcess, sInputs(iFile), 'This file does not contain extended events. Skipping File...');
            continue;
        end
        % Keep only requested extended events
        if ~isempty(EvtNames)
            ExtEvtNames = {sEvents(iEvtExt).label};
            ValidEvtNames = intersect(EvtNames, ExtEvtNames);
            NoValidEvtNames = setdiff(EvtNames, ExtEvtNames);
            NoValdEvtNamesStr = '';
            if ~isempty(NoValidEvtNames)
                NoValdEvtNamesStr = strjoin(cellfun(@(x) ['"', x, '"'], NoValidEvtNames, 'UniformOutput', false), ' and ');
            end
            if isempty(ValidEvtNames)
                bst_report('Error', sProcess, sInputs(iFile), ...
                    ['None of the requested events ' NoValdEvtNamesStr ', is an extended event. Skipping File...']);
                continue
            else
                if ~isempty(NoValdEvtNamesStr)
                    bst_report('Warning', sProcess, sInputs(iFile), ...
                        ['This file does not contain the extended events ' NoValdEvtNamesStr '. Skipping these events...']);
                end
            end
            [~, iEvtExt] = ismember(ValidEvtNames, {sEvents.label});
        end

        % Call the merging function
        [sEventsMerged, ixModified] = Compute(sEvents(iEvtExt));
        isModified = ~isempty(ixModified);
        % Append new event groups, add " | merge_ext"
        if ~isDelete
            for ix = 1 : length(sEventsMerged)
                sEvents(end+1) = sEventsMerged(ix);
                sEvents(end).label = [sEvents(end).label, ' | merge_ext'];
            end
        else
            sEvents(iEvtExt(ixModified)) = sEventsMerged;
        end

        % ===== SAVE RESULT =====
        % Only save changes if something was change
        if isModified
            % Report changes in .mat structure
            if isRaw
                DataMat.F.events = sEvents;
            else
                DataMat.Events = sEvents;
            end
            % Save file definition
            bst_save(file_fullpath(sInputs(iFile).FileName), DataMat, 'v6', 1);
        end
        % Return all the input files
        OutputFiles{end+1} = sInputs(iFile).FileName;
    end
end


%% ===== GROUP EVENTS =====
function [sEventsMerged, ixModified] = Compute(sEvents)
    sEventsMerged = repmat(db_template('event'), 0);
    ixModified    = [];
    evtNamesModified = {};
    for iEvt = 1 : length(sEvents)
        sEvent = sEvents(iEvt);
        % Old begining and ending times
        nOccur = size(sEvent.times, 2);
        oldIni = sEvent.times(1,:);
        oldFin = sEvent.times(2,:);
        oldTimes = [oldIni, oldFin];
        oldFlag  = [repmat(1,1,nOccur), repmat(2,1,nOccur)];
        oldChans = [sEvent.channels, sEvent.channels];
        oldNotes = [sEvent.notes, sEvent.notes];
        oldHeds  = [sEvent.hedTags, sEvent.hedTags];
        % Sort by times
        [oldTimes, ix] = sort(oldTimes);
        oldFlag = oldFlag(ix);
        if ~isempty(oldChans)
            oldChans = oldChans(ix);
            newChans = {};
        end
        if ~isempty(oldNotes)
            oldNotes = oldNotes(ix);
            newNotes = {};
        end
        if ~isempty(oldHeds)
            oldHeds = oldHeds(ix);
            newHeds = {};
        end
        % New begining and ending times
        newIni = [];
        newFin = [];
        nOpen = 0;
        % Merge overlapping extended events
        while ~isempty(oldTimes)
            iDelTime = [];
            for iTime = 1 : length(oldTimes)
                if oldFlag(iTime) == 1
                    if nOpen == 0
                        newIni(end+1) = oldTimes(iTime);
                        if ~isempty(oldChans)
                            newChans(end+1) = oldChans(iTime);
                        end
                        if ~isempty(oldNotes)
                            newNotes(end+1) = oldNotes(iTime);
                        end
                        if ~isempty(oldHeds)
                            newHeds(end+1) = oldHeds(iTime);
                        end
                        nOpen = nOpen + 1;
                        iDelTime = [iDelTime, iTime];
                    else
                        if (isempty(oldChans) || (isempty(newChans{end}) && isempty(oldChans{iTime})) || isequal(newChans{end}, oldChans{iTime}) ) && ...
                           (isempty(oldNotes) || (isempty(newNotes{end}) && isempty(oldNotes{iTime})) || isequal(newNotes{end}, oldNotes{iTime}) ) && ...
                           (isempty(oldHeds)  || (isempty(newHeds{end})  && isempty(oldHeds{iTime}))  || isequal(newHeds{end},  oldHeds{iTime}) )
                            nOpen = nOpen + 1;
                            iDelTime = [iDelTime, iTime];
                        end
                    end
                elseif oldFlag(iTime) == 2
                    if (isempty(oldChans) || (isempty(newChans{end}) && isempty(oldChans{iTime})) || isequal(newChans{end}, oldChans{iTime}) ) && ...
                       (isempty(oldNotes) || (isempty(newNotes{end}) && isempty(oldNotes{iTime})) || isequal(newNotes{end}, oldNotes{iTime}) ) && ...
                       (isempty(oldHeds)  || (isempty(newHeds{end})  && isempty(oldHeds{iTime}))  || isequal(newHeds{end},  oldHeds{iTime}) )
                        nOpen = nOpen - 1;
                        iDelTime = [iDelTime, iTime];
                    end
                    if nOpen == 0
                        newFin(end+1) = oldTimes(iTime);
                        iDelTime = [iDelTime, iTime];
                    end
                end
            end
            oldTimes(iDelTime) = [];
        end
        % Was modified?
        if length(newIni) < length(oldIni) && length(newFin) < length(oldFin)
            ixModified = [ixModified, iEvt];
            sEventsMerged(end+1) = sEvent;
            sEventsMerged(end).times = [newIni; newFin];
            sEventsMerged(end).epochs = ones(1,length(newIni));
            sEventsMerged(end).epochs = ones(1,length(newIni));
            if ~isempty(oldChans)
                sEventsMerged(end).channels = newChans;
            end
            if ~isempty(oldNotes)
                sEventsMerged(end).notes = newNotes;
            end
            if ~isempty(oldHeds)
                sEventsMerged(end).hedTags = newHeds;
            end
        end
    end
end
