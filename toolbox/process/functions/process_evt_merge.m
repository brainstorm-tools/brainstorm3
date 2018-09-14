function varargout = process_evt_merge( varargin )
% PROCESS_EVT_RENAME: Rename an event.

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
% Authors: Francois Tadel, 2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Merge events';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 54;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/EventMarkers#Other_menus';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Event name
    sProcess.options.evtnames.Comment  = 'Events to merge (separated with commas): ';
    sProcess.options.evtnames.Type     = 'text';
    sProcess.options.evtnames.Value    = '';
    % New name
    sProcess.options.newname.Comment = 'New event name: ';
    sProcess.options.newname.Type    = 'text';
    sProcess.options.newname.Value   = '';
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
    NewName  = strtrim(sProcess.options.newname.Value);
    if isempty(EvtNames) || isempty(NewName)
        bst_report('Error', sProcess, [], 'You must enter a list of events to merge and a destination name.');
        return;
    end
    % Split names
    EvtNames = strtrim(str_split(EvtNames, ',;'));
    if (length(EvtNames) < 2) || isempty(EvtNames{1})
        bst_report('Error', sProcess, [], 'You must enter at least to event names to merge.');
        return;
    end

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
        % Call the renaming function
        [sFile.events, isModified] = Compute(sInputs(iFile), sFile.events, EvtNames, NewName);

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


%% ===== RENAME EVENTS =====
function [events, isModified] = Compute(sInput, events, EvtNames, NewName)
    % No modification
    isModified = 0;

    % Check that destination name doesn't already exist
    iEvtNew = find(strcmpi({events.label}, NewName));
    if ~isempty(iEvtNew)
        bst_report('Error', 'process_evt_merge', sInput, ['Event "' NewName '" already exists.']);
        return;
    end
    
    % Find events to merge
    iEvents = [];
    for i = 1:length(EvtNames)
        iEvt = find(strcmpi({events.label}, EvtNames{i}));
        if isempty(iEvt)
            bst_report('Warning', 'process_evt_merge', sInput, ['Event "' EvtNames{i} '" does not exist.']);
        else
            iEvents(end+1) = iEvt;
        end
    end
    % Make sure there are at least two events to merge
    if (length(iEvents) < 2)
        bst_report('Error', 'process_evt_merge', sInput, 'You must enter at least to valid event names to merge.');
        return;
    end

    % Inialize new event group
    newEvent = events(iEvents(1));
    newEvent.label      = NewName;
    newEvent.times      = [events(iEvents).times];
    newEvent.samples    = [events(iEvents).samples];
    newEvent.epochs     = [events(iEvents).epochs];
    % Reaction time: only if all the events have reaction time set
    if all(~cellfun(@isempty, {events(iEvents).reactTimes}))
        newEvent.reactTimes = [events(iEvents).reactTimes];
    else
        newEvent.reactTimes = [];
    end
    % Sort by samples indices, and remove redundant values
    [tmp__, iSort] = unique(newEvent.samples(1,:));
    newEvent.samples = newEvent.samples(:,iSort);
    newEvent.times   = newEvent.times(:,iSort);
    newEvent.epochs  = newEvent.epochs(iSort);
    if ~isempty(newEvent.reactTimes)
        newEvent.reactTimes = newEvent.reactTimes(iSort);
    end
    
    % Remove merged events
    events(iEvents) = [];
    % Add new event
    events(end + 1) = newEvent;

    % File was modified
    isModified = 1;
end






