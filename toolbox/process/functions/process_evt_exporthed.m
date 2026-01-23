function varargout = process_evt_exporthed(varargin)
% PROCESS_EVT_EXPORTHED: Export HED tags from Brainstorm data files to a JSON sidecar
%
% USAGE:  OutputFiles = process_evt_exporthed('Run', sProcess, sInput)

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
% Authors: Anna Zaidi, 2024
%          Raymundo Cassani, 2025

eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    sProcess.Comment     = 'Export HED tags (BIDS _events.json)';
    sProcess.FileTag     = [];
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 66;
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'raw', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % JSON sidecar file
    SelectOptions = {...
        '', ...                               % Filename
        '', ...                               % FileFormat
        'save', ...                           % Dialog type: {open,save}
        'Export HED JSON sidecar...', ...     % Window title
        'ExportData', ...                     % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                         % Selection mode: {single,multiple}
        'files', ...                          % Selection mode: {files,dirs,files_and_dirs}
        {{'_events.json'}, {'HED tags (*_events.json)'}, 'JSON'}, ...
        ''};
    sProcess.options.sidecar.Type    = 'filename';
    sProcess.options.sidecar.Comment = 'JSON sidecar';
    sProcess.options.sidecar.Value   = SelectOptions;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs)
    % Output files
    OutputFiles = {sInputs.FileName};

    % ===== GET OPTIONS =====
    % JSON sidecar file with HED tags
    outJson = sProcess.options.sidecar.Value{1};

    % Check: Same FileType for all files
    isRaw = strcmp({sInputs.FileType},'raw');
    if ~all(isRaw) && ~all(~isRaw)
        bst_report('Error', sProcess, sInputs, 'Do not mix ''raw'' and ''imported'' data')
        return;
    end
    isRaw = isRaw(1);

    % ===== GATHER ALL EVENTS AND THEIR HED TAGS =====
    evtAllNames   = {};
    evtAllHedTags = {};
    for iInput = 1 : length(sInputs)
        % Get events and their HED tags
        if isRaw
            sData = in_bst_data(sInputs(iInput).FileName, 'F');
            sEvents = sData.F.events;
        else
            sData = in_bst_data(sInputs(iInput).FileName, 'Events');
            sEvents = sData.Events;
        end
        evtNames   = {sEvents.label};
        evtHedTags = {sEvents.hedTags};
        % Check for uniformity of events and HED tags
        for iEvt = 1 : length(evtNames)
            ix = find(strcmp(evtNames{iEvt}, evtAllNames));
            if ~isempty(ix) && ~isequal(sort(evtHedTags{iEvt}), sort(evtAllHedTags{ix}))
                bst_report('Error', sProcess, sInputs, 'HED tags must be uniform across input files');
                return
            else
                evtAllNames{end+1}   = evtNames{iEvt};
                evtAllHedTags{end+1} = evtHedTags{iEvt};
            end
        end
    end
    % Nothing to save
    if all(cellfun(@isempty, evtAllHedTags))
        bst_report('Warning', sProcess, sInputs, 'Events do not have HED tags');
        return
    end

    % ===== SAVE HED TAGS TO SIDECAR FILE =====
    jsonStr = events2json(evtAllNames, evtAllHedTags);
    fid = fopen(outJson, 'w');
    fwrite(fid, jsonStr);
    fclose(fid);
end

function jsonStr = events2json(evtNames, evtHedTags)
    % Generate maps for Level and HED
    levelsMap = containers.Map('KeyType','char','ValueType','char');
    hedMap    = containers.Map('KeyType','char','ValueType','char');
    for iEvt = 1 : length(evtNames)
        evtName   = evtNames{iEvt};
        evtHedStr = '';
        if ~isempty(evtHedTags{iEvt})
            evtHedStr = strjoin(evtHedTags{iEvt}, ', ');
        end
        levelsMap(evtName) = sprintf('Brainstorm event "%s" label exported for HED tags', evtName);
        hedMap(evtName)    = evtHedStr;
    end
    % Generate structure to be written as JSON sidecar
    sSidecar = struct('trial_type', struct('Levels', levelsMap, 'HED', hedMap));
    % Write JSON sidecar
    jsonStr = bst_jsonencode(sSidecar, 1);
end