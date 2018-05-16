function varargout = process_evt_remove_simult( varargin )
% PROCESS_EVT_REMOVE_SIMULT: Remove occurences of an event A occurring at the same time as an event B.
%
% USAGE:  OutputFiles = process_evt_remove_simult('Run', sProcess, sInputs)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Remove simultaneous';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 49;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ArtifactsDetect#Remove_simultaneous_blinks.2Fheartbeats';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Event name: to remove
    sProcess.options.remove.Comment = 'Remove events named: ';
    sProcess.options.remove.Type    = 'text';
    sProcess.options.remove.Value   = 'cardiac';
    % Event name: target
    sProcess.options.target.Comment = 'When too close to events: ';
    sProcess.options.target.Type    = 'text';
    sProcess.options.target.Value   = 'blink';
    % Maximum duration events
    sProcess.options.dt.Comment = 'Minimum delay between events: ';
    sProcess.options.dt.Type    = 'value';
    sProcess.options.dt.Value   = {0.250, 'ms', 0};
    % Delete original events
    sProcess.options.rename.Comment = 'Rename the events instead of deleting them';
    sProcess.options.rename.Type    = 'checkbox';
    sProcess.options.rename.Value   = 0;
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
    isDelete = ~sProcess.options.rename.Value;
    dt = sProcess.options.dt.Value{1};
    evtA = strtrim(sProcess.options.remove.Value);
    evtB = strtrim(sProcess.options.target.Value);
    % Check that the user gave one event in each box
    if isempty(evtA) || isempty(evtB)
        bst_report('Error', sProcess, [], 'Event name is empty.');
        return;
    elseif any(evtA == ',') || any(evtA == ';')  || any(evtB == ',') || any(evtB == ';') 
        bst_report('Error', sProcess, [], 'This event can be used to process only one event type at a time.');
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
        % Call the detection function
        [sFile.events, isModified] = Compute(sInputs(iFile), sFile.events, evtA, evtB, ds, isDelete);

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


%% ===== RENAME SIMULTANEOUS EVENTS =====
function [eventsNew, isModified] = Compute(sInput, events, evtA, evtB, ds, isDelete)
    % Initialize returned variables
    isModified = 0;
    eventsNew = events;
    % Get events names
    iEvtA = find(strcmpi({events.label}, evtA));
    iEvtB = find(strcmpi({events.label}, evtB));
    if isempty(iEvtA)
        bst_report('Error', 'process_evt_remove_simult', sInput, ['Event "' evtA '" does not exist.']);
        return;
    elseif isempty(iEvtB)
        bst_report('Error', 'process_evt_remove_simult', sInput, ['Event "' evtB '" does not exist.']);
        return;
    end
    % If events are extended events: error
    if (size(events(iEvtA).times,1) > 1) || (size(events(iEvtB).times,1) > 1)
        bst_report('Error', 'process_evt_remove_simult', sInput, 'Cannot process extended events.');
        return;
    end
    % Look of all the events A that are too close to event B
    iRemoveA = [];
    for iOcc = 1:size(events(iEvtA).samples,2)
        if any(abs(events(iEvtA).samples(iOcc) - events(iEvtB).samples) <= ds)
            iRemoveA(end+1) = iOcc;
        end
    end
    % No events to remove
    if isempty(iRemoveA)
        return;
    end
    % Display info message with the number of events removed
    bst_report('Info', 'process_evt_remove_simult', sInput, sprintf('Removed %d events "%s" that were less than %d samples away from an event "%s".', length(iRemoveA), evtA, ds, evtB));
    % If we need to rename the events to a new category
    if ~isDelete
        % Create new event name for the removed occurrences
        newLabel = file_unique([evtA '_rm'], {events.label});
        % Create new event
        iEvtRm = length(eventsNew) + 1;
        eventsNew(iEvtRm) = db_template('event');
        eventsNew(iEvtRm).label   = newLabel;
        eventsNew(iEvtRm).color   = [1 0 0];
        eventsNew(iEvtRm).times   = eventsNew(iEvtA).times(:,iRemoveA);
        eventsNew(iEvtRm).samples = eventsNew(iEvtA).samples(:,iRemoveA);
        eventsNew(iEvtRm).epochs  = eventsNew(iEvtA).epochs(iRemoveA);
    end
    % Remove occurrences / remove event
    if isequal(iRemoveA, 1:size(eventsNew(iEvtA).times,2))
        eventsNew(iEvtA) = [];
    else
        eventsNew(iEvtA).times(:,iRemoveA)   = [];
        eventsNew(iEvtA).samples(:,iRemoveA) = [];
        eventsNew(iEvtA).epochs(iRemoveA)    = [];
    end
    isModified = 1;
end






