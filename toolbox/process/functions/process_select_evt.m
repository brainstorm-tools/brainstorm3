function varargout = process_select_evt( varargin )
% PROCESS_SELECT_EVT: Keep only the data files within the current selection that have the specified event info.
%
% USAGE:  sProcess = process_select_evt('GetDescription')
%                    process_select_evt('Run', sProcess, sInputs)

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
% Authors: Francois Tadel, 2012-2016
%          Raymundo Cassani, 2025

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Select files: By event info';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 1013.5;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/SelectFiles';
    sProcess.InputTypes  = {'raw', 'data', 'matrix'};
    sProcess.OutputTypes = {'raw', 'data', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 0;
    % === EVENT NAME(S)
    sProcess.options.evtname.Comment = 'Event name(s): ';
    sProcess.options.evtname.Type    = 'text';
    sProcess.options.evtname.Value   = '';
    % === SELECT / IGNORE
    sProcess.options.label2.Comment = 'What to do with these files:';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.select.Comment = {'Select files', 'Ignore files'; 'select', 'ignore'};
    sProcess.options.select.Type    = 'radio_label';
    sProcess.options.select.Value   = 'select';
    % === HELP
    sProcess.options.label.Comment = '<FONT COLOR="#777777">To select multiple events, separate them with commas.</FONT>';
    sProcess.options.label.Type    = 'label';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % Option: Event name
    evtName = strtrim(sProcess.options.evtname.Value);
    if isempty(evtName)
        selMethod = 'with any event';
    else
        selMethod = 'by event name(s)';
    end
    % Option: Ignore/select
    if isfield(sProcess.options, 'select') && isfield(sProcess.options.select, 'Value') && ~isempty(sProcess.options.select.Value)
        Comment = sProcess.options.select.Value;
        Comment(1) = upper(Comment(1));
    end
    % Build comment
    Comment = [Comment ' files ' selMethod '.'];
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Option: Event names
    evtNameStr = strtrim(sProcess.options.evtname.Value);
    if isempty(evtNameStr)
        selMethod = 'with any event';
    else
        selMethod = ['by event name(s): ' evtNameStr];
    end
    evtNames = strtrim(str_split(evtNameStr, ',;'));
    % Option: Ignore/select
    if isfield(sProcess.options, 'select') && isfield(sProcess.options.select, 'Value') && ~isempty(sProcess.options.select.Value)
        isSelect = strcmpi(sProcess.options.select.Value, 'select');
    end
    % For each file
    for iFile = 1:length(sInputs)
        % ===== GET FILE DESCRIPTOR =====
        isRaw = strcmpi(sInputs(iFile).FileType, 'raw');
        if isRaw
            DataMat = in_bst_data(sInputs(iFile).FileName, 'F');
            sEvents = DataMat.F.events;
        else
            DataMat = in_bst_data(sInputs(iFile).FileName, 'Events');
            sEvents = DataMat.Events;
        end
        % If no events are present in this file
        if isempty(sEvents)
            % File does not have any event, found = 0
            isFound(iFile) = 0;
        elseif isempty(evtNames)
            % File has events and requested event name was empty, found = 1
            isFound(iFile) = 1;
        else
            % File has events from the requested event names, found = 1
            isFound(iFile) = any(ismember(evtNames, {sEvents.label}));
        end
    end
    % Select or ignore
    if isSelect
        iFiles = find(isFound);
    else
        iFiles = find(~isFound);
    end
    % Warning: nothing found
    if isempty(iFiles)
        bst_report('Warning', sProcess, [], ['No files found ' selMethod, '.']);
        OutputFiles = {};
        return;
    end
    % Report information
    strReport = sprintf('Files selected for event names(s) "%s": %d/%d', evtNameStr, length(iFiles), length(sInputs));
    bst_report('Info', sProcess, [], strReport);
    % Return only the requested filenames
    OutputFiles = {sInputs(iFiles).FileName};
end



