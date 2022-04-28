function varargout = process_evt_duplicate( varargin )
% PROCESS_EVT_DELETE: Delete a list of events.

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
% Authors: Francois Tadel, 2015-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Duplicate events';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 55;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/EventMarkers#Other_menus';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Event names
    sProcess.options.eventname.Comment  = 'Event names: ';
    sProcess.options.eventname.Type     = 'text';
    sProcess.options.eventname.Value    = '';
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
    EvtNames = strtrim(str_split(sProcess.options.eventname.Value, ',;'));
    if isempty(EvtNames) || isempty(EvtNames)
        bst_report('Error', sProcess, [], 'The list of events to duplicate is empty.');
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
        % Call the deleting function
        [sFile.events, isModified] = Compute(sInputs(iFile), sFile.events, EvtNames);

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
function [events, isModified] = Compute(sInput, events, EvtNames)
    % No modification
    isModified = 0;
    % Loop on events to delete
    iEvtDup = [];
    strNotFound = '';
    for i = 1:length(EvtNames)
        % Find event in the list
        iEvt = find(strcmpi({events.label}, EvtNames{i}));
        % Event was not found
        if isempty(iEvt)
            strNotFound = [strNotFound, ' ' EvtNames{i}];
        % Event was found: add it to the duplicate list
        else
            iEvtDup = [iEvtDup, iEvt];
        end
    end
    % Warning: events not found
    if ~isempty(strNotFound)
        bst_report('Warning', 'process_evt_duplicate', sInput, ['Events not found:' strNotFound]);
    end
    % If there some events were found
    if ~isempty(iEvtDup)

        for i = 1:length(iEvtDup)
            % Get new indice
            iCopy(i) = length(events) + 1;
            % Duplicate event groups
            events(iCopy(i)) = events(iEvtDup(i));
            % Add "copy" tag
            events(iCopy(i)).label = file_unique(events(iCopy(i)).label, {events.label});
            % Set new color
            %events(iCopy(i)).color = GetNewEventColor(iCopy(i), events);
        end
        
        % File was modified
        isModified = 1;
    end
end






