function varargout = process_evt_multiresp( varargin )
% PROCESS_EVT_MULTIRESP: Detect multiple response events.
%
% USAGE:  OutputFiles = process_evt_multiresp('Run', sProcess, sInputs)

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
% Authors: Francois Tadel, 2015

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Detect multiple responses';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 50;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/EventMarkers#Other_menus';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Event name: to remove
    sProcess.options.responses.Comment = 'Response events (separated with commas): ';
    sProcess.options.responses.Type    = 'text';
    sProcess.options.responses.Value   = '';
    % Minimum delay between events
    sProcess.options.dt.Comment = 'Minimum delay between events: ';
    sProcess.options.dt.Type    = 'value';
    sProcess.options.dt.Value   = {0.500, 'ms', 0};
    % Which events to keep
    sProcess.options.action.Comment = {'Keep only the first event', 'Keep only the last event', 'Remove all the multiple responses'};
    sProcess.options.action.Type    = 'radio';
    sProcess.options.action.Value   = 1;
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
    % Get maximum response delay
    dt = sProcess.options.dt.Value{1};
    % Get event names
    respEvts = str_split(strtrim(sProcess.options.responses.Value), ',;');
    % Check that the user entered an event
    if isempty(respEvts)
        bst_report('Error', sProcess, [], 'Event list is empty.');
        return;
    end
    % Remove space chars from all the event names
    respEvts = cellfun(@strtrim, respEvts, 'UniformOutput', 0);
    % Action to perform
    switch (sProcess.options.action.Value)
        case 1, Method = 'first';
        case 2, Method = 'last';
        case 3, Method = 'delete';
    end
    isDelete = ~sProcess.options.rename.Value;
    
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
        [sFile.events, isModified] = Compute(sInputs(iFile), sFile.events, respEvts, ds, Method, isDelete, sFile.prop.sfreq);

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
function [eventsNew, isModified] = Compute(sInput, events, respEvts, ds, Method, isDelete, sfreq)
    % Initialize returned variables
    isModified = 0;
    eventsNew = events;
    
    % Get events names and samples
    iEvts = [];
    AllTimes  = [];
    AllEvt    = [];
    AllOcc    = [];
    AllEpochs = [];
    AllChannels = {};
    AllNotes    = {};
    
    for i = 1:length(respEvts)
        iTmp = find(strcmpi({events.label}, respEvts{i}));
        if ~isempty(iTmp)
            iEvts(end+1) = iTmp;
            AllTimes   = [AllTimes,   mean(events(iTmp).times, 1)];   % Average to take the middle of extended events
            AllEpochs  = [AllEpochs,  events(iTmp).epochs];
            AllChannels= [AllChannels, events(iTmp).channels];
            AllNotes   = [AllNotes, events(iTmp).notes];
            AllEvt     = [AllEvt, repmat(iTmp, [1, size(events(iTmp).times,2)])];
            AllOcc     = [AllOcc, 1:size(events(iTmp).times,2)];
        else
            bst_report('Warning', 'process_evt_multiresp', sInput, ['Event "' respEvts{i} '" does not exist.']);
        end
    end
    if isempty(iEvts)
        bst_report('Error', 'process_evt_multiresp', sInput, 'No valid response events could be found.');
        return;
    elseif isempty(AllTimes)
        bst_report('Info', 'process_evt_multiresp', sInput, 'No multiple responses were found.');
        return;
    elseif any(AllEpochs ~= 1)
        bst_report('Info', 'process_evt_multiresp', sInput, 'Epoched recordings cannot be processed with this process, convert to continuous first.');
        return;
    end
    
    % Sort samples
    [AllTimes, iSort] = sort(AllTimes);
    AllEvt    = AllEvt(iSort);
    AllOcc    = AllOcc(iSort);
    AllEpochs = AllEpochs(iSort);
    AllChannels = AllChannels(iSort);
    AllNotes    = AllNotes(iSort);
    % Compute distance matrix
    dist = ones(length(AllTimes), 1) * round(AllTimes .* sfreq);
    dist = dist - dist';
    % Find the events that are too close to each other
    dist = (abs(dist) < ds) - eye(length(AllTimes));
    % Find the events to process
    iMulti = find(any(dist, 1));
    % No events are process
    if isempty(iMulti)
        bst_report('Info', 'process_evt_multiresp', sInput, 'No multiple responses were found.');
        return;
    end
    % Loop to process events
    iKeep   = [];
    iRemove = [];
    for i = 1:length(iMulti)
        % Get first event of the group of simultaneous events
        iFirst = iMulti(i);
        % If it was already processed: ignore
        if any(iFirst == [iKeep, iRemove])
            continue;
        end
        % Get the other events in the same group
        iOther = find(dist(iFirst,:));
        % Keep or remove the simulatenous events, depending on the selected method
        switch (Method)
            case 'first'
                iKeep   = [iKeep,   iFirst];
                iRemove = [iRemove, iOther];
            case 'last'
                iKeep   = [iKeep,   iOther(end)];
                iRemove = [iRemove, iFirst, iOther(1:end-1)];
            case 'delete'
                iRemove = [iRemove, iFirst, iOther];
        end
    end
    % Display info message with the number of events removed
    bst_report('Info', 'process_evt_multiresp', sInput, sprintf('Removed %d events that were less than %d samples away from other similar events.', length(iRemove), ds));
    % If we need to move the events to a new category
    if ~isDelete && ~isempty(iRemove)
        % Create new event name for the removed occurrences
        newLabel = file_unique('Multiple', {events.label});
        % Create new event
        iEvtRm = length(eventsNew) + 1;
        eventsNew(iEvtRm) = db_template('event');
        eventsNew(iEvtRm).label  = newLabel;
        eventsNew(iEvtRm).color  = [1 0 0];
        eventsNew(iEvtRm).times  = AllTimes(iRemove);
        eventsNew(iEvtRm).epochs = AllEpochs(iRemove);
        eventsNew(iEvtRm).channels = AllChannels(iRemove);
        eventsNew(iEvtRm).notes    = AllNotes(iRemove);
    end
    % Get all the events in which cuts are necessary
    iEvts = unique(AllEvt(iRemove));
    % Remove occurrences
    for i = 1:length(iEvts)
        iRmEvt = find(AllEvt(iRemove) == iEvts(i));
        iOcc = AllOcc(iRemove(iRmEvt));
        eventsNew(iEvts(i)).times(:,iOcc) = [];
        eventsNew(iEvts(i)).epochs(iOcc)  = [];
        eventsNew(iEvts(i)).channels(iOcc)= [];
        eventsNew(iEvts(i)).notes(iOcc)   = [];
    end
    isModified = 1;
end






