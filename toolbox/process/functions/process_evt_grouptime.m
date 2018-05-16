function varargout = process_evt_grouptime( varargin )
% PROCESS_EVT_GROUPTIME: Group events that are co-occurring into a new category
%
% USAGE:  OutputFiles = process_evt_grouptime('Run', sProcess, sInputs)
%              events = process_evt_grouptime('Compute', events)

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
% Authors: Francois Tadel, 2012

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Group by time';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 52;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/EventMarkers#Other_menus';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'raw', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Event name
    sProcess.options.combine.Comment = 'Detect and group events that are occurring at the same instant';
    sProcess.options.combine.Type    = 'label';
    sProcess.options.combine.Value   = [];
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Return all the input files
    OutputFiles = {};
    
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
        % Call the grouping function
        [sFile.events, isModified] = Compute(sFile.events);

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
function [events, isModified] = Compute(events)
    % List of all the events [indices; 
    AllEvt = zeros(2,0);
    isModified = 0;
    % Keep only the single events
    for iEvt = 1:length(events)
        % Skip extended events
        if (size(events(iEvt).times,1) > 1)
            continue;
        end
        % Add to the list of all the processes
        AllEvt = [AllEvt, [events(iEvt).samples; repmat(iEvt, size(events(iEvt).samples))]];
    end
    % Process each unique time value
    uniqueSamples = unique(AllEvt(1,:));
    for iSmp = 1:length(uniqueSamples)
        % Look for all the events happening at this time
        iEvts = AllEvt(2, (AllEvt(1,:) == uniqueSamples(iSmp)));
        % If only one occurrence: skip to the next time
        if (length(iEvts) < 2)
            continue;
        end
        % Remove occurrence from each event type (and build new event name)
        newLabel = events(iEvts(1)).label;
        for i = 1:length(iEvts)
            % Find the occurrence indice
            iOcc = find(events(iEvts(i)).samples == uniqueSamples(iSmp));
            % Get the values 
            if (i == 1)
                newTime   = events(iEvts(i)).times(iOcc);
                newSample = events(iEvts(i)).samples(iOcc);
                newEpoch  = events(iEvts(i)).epochs(iOcc);
            % Add all the labels to the new event category
            else
                % Try to convert to numerical values
                numOldLabel = str2num(events(iEvts(i)).label);
                numNewLabel = str2num(newLabel);
                % If events are not numerical: concatenate as text
                if isempty(numOldLabel) || isempty(numNewLabel)
                    newLabel = [newLabel, ' & ', events(iEvts(i)).label];
                % Else: sum all the values
                else
                    newLabel = num2str(numOldLabel + numNewLabel);
                end
            end
            % Remove this occurrence
            events(iEvts(i)).times(iOcc)   = [];
            events(iEvts(i)).samples(iOcc) = [];
            events(iEvts(i)).epochs(iOcc)  = [];
        end
        
        % Find this event in the list
        iNewEvt = find(strcmpi(newLabel, {events.label}));
        % Create event category if does not exist yet
        if isempty(iNewEvt)
            % Initialize new event
            iNewEvt = length(events) + 1;
            sEvent = db_template('event');
            sEvent.label = newLabel;
            % Color
            sEvent.color = panel_record('GetNewEventColor', iNewEvt, events);
            % Add new event to list
            events(iNewEvt) = sEvent;
        end
        % Add occurrences
        events(iNewEvt).times   = [events(iNewEvt).times,   newTime];
        events(iNewEvt).samples = [events(iNewEvt).samples, newSample];
        events(iNewEvt).epochs  = [events(iNewEvt).epochs,  newEpoch];
        % Sort
        [events(iNewEvt).times, indSort] = unique(events(iNewEvt).times);
        events(iNewEvt).samples = events(iNewEvt).samples(indSort);
        events(iNewEvt).epochs  = events(iNewEvt).epochs(indSort);
        isModified = 1;
    end
end



