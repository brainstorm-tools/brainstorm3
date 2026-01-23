function varargout = process_select_evthed( varargin )
% PROCESS_SELECT_EVTHED: Keep only the data files within the current selection that have the specified HED tags in event info.
%
% USAGE:  sProcess = process_select_evthed('GetDescription')
%                    process_select_evthed('Run', sProcess, sInputs)

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
    sProcess.Comment     = 'Select files: By HED tags';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 1013.6;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/SelectFiles';
    sProcess.InputTypes  = {'raw', 'data', 'matrix'};
    sProcess.OutputTypes = {'raw', 'data', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 0;
    % === HED TAG(S)
    sProcess.options.hedname.Comment = 'HED tag(s): ';
    sProcess.options.hedname.Type    = 'text';
    sProcess.options.hedname.Value   = '';
    % === SELECT / IGNORE
    sProcess.options.label2.Comment = 'What to do with these files:';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.select.Comment = {'Select files', 'Ignore files'; 'select', 'ignore'};
    sProcess.options.select.Type    = 'radio_label';
    sProcess.options.select.Value   = 'select';
    % === HELP
    sProcess.options.label.Comment = '<FONT COLOR="#777777">To select multiple HED tags, separate them with commas.</FONT>';
    sProcess.options.label.Type    = 'label';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % Option: HED tag
    hedName = strtrim(sProcess.options.hedname.Value);
    if isempty(hedName)
        selMethod = 'with any event with HED tag';
    else
        selMethod = 'by HED tag(s)';
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
    % Option: HED tag
    hedNameStr = strtrim(sProcess.options.hedname.Value);
    if isempty(hedNameStr)
        selMethod = 'with any event with HED tag';
    else
        selMethod = ['by HED tag(s): ' hedNameStr];
    end
    hedNames = strtrim(str_split(hedNameStr, ',;'));
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
        % If no events, no HED tags are present in this file
        if isempty(sEvents)
            % File does not have any event, found = 0
            isFound(iFile) = 0;
        else
            allHedTags = [sEvents.hedTags];
            if isempty(hedNames)
                % File has events, select if there are events with HED tags, found = 1
                isFound(iFile) = ~isempty(allHedTags);
            else
                % File has events, check for requested HED tags, found = 1
                isFound(iFile) = any(ismember(hedNames, allHedTags));
            end
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
    strReport = sprintf('Files selected for HED tags(s) "%s": %d/%d', hedNameStr, length(iFiles), length(sInputs));
    bst_report('Info', sProcess, [], strReport);
    % Return only the requested filenames
    OutputFiles = {sInputs(iFiles).FileName};
end
