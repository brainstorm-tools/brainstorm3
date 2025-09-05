function varargout = process_evt_uniformcolors( varargin )
% PROCESS_EVT_UNIFORMCOLORS: Standardize the event colors in a Protocol
%
% USAGE:  OutputFiles = process_evt_uniformcolors('Run', sProcess, sInput)

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
    sProcess.Comment     = 'Uniform event colors';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 61;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/EventMarkers#Other_menus';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw', 'matrix'};
    sProcess.OutputTypes = {'data', 'raw', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Description
    sProcess.options.info.Comment = ['Uniform the event colors in all the <B>Data</B> and <B>Matrix</B> files in a Protocol.<BR><BR>' ...
                                     'The event colors in the input <B><U>file</U></B> are used as reference.<BR><BR>'];
    sProcess.options.info.Type    = 'label';
    sProcess.options.info.Value   = [];
    % Event names
    sProcess.options.eventname.Comment = 'Event names: (empty = All events)';
    sProcess.options.eventname.Type    = 'text';
    sProcess.options.eventname.Value   = '';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFile = Run(sProcess, sInput) %#ok<DEFNU>
    % Return all the input files
    OutputFile = {sInput.FileName};
    % Only one file is used as reference
    if length(sInput) ~= 1
        bst_report('Error', sProcess, sInput, 'This process requires exactly one input file.');
        return
    end

    % ===== GET OPTIONS =====
    % Get events to be processed
    EvtNamesRef = strtrim(str_split(sProcess.options.eventname.Value, ',;'));
    isRaw = strcmpi(sInput.FileType, 'raw');
    if isRaw
        DataMat = in_bst_data(sInput.FileName, 'F', 'History');
        sEventsRef = DataMat.F.events;
    else
        DataMat = in_bst_data(sInput.FileName, 'Events', 'Time', 'History');
        sEventsRef = DataMat.Events;
    end
    if ~isempty(EvtNamesRef)
        [~, iEvts] = ismember(EvtNamesRef, {sEventsRef.label});
        sEventsRef = sEventsRef(iEvts);
    end
    if isempty(sEventsRef)
        bst_report('Error', sProcess, sInput, 'No events to process.');
        return;
    end

    % Find all Data (raw and non-raw) and Matrix files in Protocol
    pStudies = bst_get('ProtocolStudies');
    sData =   [pStudies.AnalysisStudy.Data,   pStudies.DefaultStudy.Data,   pStudies.Study.Data];
    sData = rmfield(sData, {'Comment', 'BadTrial'});
    sMatrix = [pStudies.AnalysisStudy.Matrix, pStudies.DefaultStudy.Matrix, pStudies.Study.Matrix];
    sMatrix = rmfield(sMatrix, 'Comment');
    [sMatrix.DataType] = deal('matrix');
    sItems = [sData, sMatrix];
    % Do not process the reference file
    iDel = strcmp(sInput.FileName, {sItems.FileName});
    sItems(iDel) = [];

    for iItem = 1 : length(sItems)
        % Get type
        isRaw = strcmpi(sItems(iItem).DataType, 'raw');
        % Load file descriptor
        if isRaw
            DataMat = in_bst_data(sItems(iItem).FileName, 'F');
            sEvents = DataMat.F.events;
        else
            DataMat = in_bst_data(sItems(iItem).FileName, 'Events');
            sEvents = DataMat.Events;
        end
        % Nothing to do
        if isempty(sEvents)
            continue
        end
        % Update colors
        updateFile = 0;
        for iEvtRef = 1 : length(sEventsRef)
            iEvt = find(strcmpi(sEventsRef(iEvtRef).label, {sEvents.label}));
            if ~isempty(iEvt) && ~all(sEvents(iEvt).color == sEventsRef(iEvtRef).color)
                sEvents(iEvt).color = sEventsRef(iEvtRef).color;
                updateFile = 1;
            end
        end
        % Only save changes if something was change
        if updateFile
            if isRaw
                DataMat.F.events = sEvents;
            else
                DataMat.Events = sEvents;
            end
            bst_save(file_fullpath(sItems(iItem).FileName), DataMat, 'v6', 1);
        end
    end
end
