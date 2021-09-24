function varargout = process_evt_rename( varargin )
% PROCESS_EVT_RENAME: Rename an event.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2015-2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Rename events';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 53;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/EventMarkers#Other_menus';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Event name
    sProcess.options.src.Comment  = 'Rename event(s): ';
    sProcess.options.src.Type     = 'text';
    sProcess.options.src.Value    = '';
    % New name
    sProcess.options.dest.Comment = 'New event name(s): ';
    sProcess.options.dest.Type    = 'text';
    sProcess.options.dest.Value   = '';
    % Help
    sProcess.options.label.Comment = '<FONT COLOR="#777777">To rename multiple events, separate them with commas.</FONT>';
    sProcess.options.label.Type    = 'label';
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
    src  = strtrim(str_split(sProcess.options.src.Value, ',;'));
    dest = strtrim(str_split(sProcess.options.dest.Value, ',;'));
    if isempty(src) || isempty(dest)
        bst_report('Error', sProcess, [], 'The source or destination name is empty.');
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
        [sFile.events, isModified] = Compute(sInputs(iFile), sFile.events, src, dest);

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
function [events, isModified] = Compute(sInput, events, src, dest)
    % No modification
    isModified = 0;
    % Check inputs
    if ischar(src)
        src = {src};
    end
    if ischar(dest)
        dest = {dest};
    end
    if (length(src) ~= length(dest))
        bst_report('Error', 'process_evt_rename', sInput, 'You need to specify the same number of event names in both lists.');
        return;
    end
    % Loop over multiple events
    for i = 1:length(src)
        % Find event in the list
        iEvt = find(strcmpi({events.label}, src{i}));
        if isempty(iEvt)
            bst_report('Warning', 'process_evt_rename', sInput, ['Event "' src{i} '" does not exist.']);
            return;
        end
        % Rename event
        events(iEvt).label = dest{i};
    end
    % File was modified
    isModified = 1;
end






