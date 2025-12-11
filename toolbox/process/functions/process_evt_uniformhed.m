function varargout = process_evt_uniformhed(varargin)
% PROCESS_EVT_UNIFORMHED: Merge HED tags for same-name events in a Protocol
%
% USAGE:  OutputFiles = process_evt_uniformhed('Run', sProcess, sInput)

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
    % Description the process
    sProcess.Comment     = 'Uniform HED tags in a Protocol';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 67;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import', 'data', 'raw', 'matrix'};
    sProcess.OutputTypes = {'import', 'data', 'raw', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    % Description
    sProcess.options.info.Comment = ['Merge the HED tags for same-name events in all the <BR>' ...
                                     '<B>Data</B> and <B>Matrix</B> files in a Protocol.'];
    sProcess.options.info.Type    = 'label';
    sProcess.options.info.Value   = [];
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
% Output files
    OutputFiles = {sInputs.FileName};

    % Find all Data (raw and non-raw) and Matrix files in Protocol
    pStudies = bst_get('ProtocolStudies');
    sData =   [pStudies.AnalysisStudy.Data,   pStudies.DefaultStudy.Data,   pStudies.Study.Data];
    sData = rmfield(sData, {'Comment', 'BadTrial'});
    sMatrix = [pStudies.AnalysisStudy.Matrix, pStudies.DefaultStudy.Matrix, pStudies.Study.Matrix];
    sMatrix = rmfield(sMatrix, 'Comment');
    [sMatrix.DataType] = deal('matrix');
    sItems = [sData, sMatrix];
    nItems = length(sItems);

    % ===== GATHER ALL EVENTS AND THEIR HED TAGS FOR EACH FILE =====
    itemEvtNames   = cell(nItems,1);
    evtAllNames     = {};
    evtAllHedTags   = {};
    for iItem = 1 : nItems
        % Get type
        isRaw = strcmpi(sItems(iItem).DataType, 'raw');
        % Get events and their HED tags
        if isRaw
            sData = in_bst_data(sItems(iItem).FileName, 'F');
            sEvents = sData.F.events;
        else
            sData = in_bst_data(sItems(iItem).FileName, 'Events');
            sEvents = sData.Events;
        end
        % Nothing to do
        if isempty(sEvents)
            continue
        end
        evtNames   = {sEvents.label};
        evtHedTags = {sEvents.hedTags};
        itemEvtNames{iItem} = evtNames;
        % Append HED tags
        for iEvt = 1 : length(evtNames)
            ix = find(strcmp(evtNames{iEvt}, evtAllNames));
            if isempty(ix)
                evtAllNames{end+1}   = evtNames{iEvt};
                evtAllHedTags{end+1} = evtHedTags{iEvt};
            else
                % Is there a new HED tag?
                newHedTags = setdiff(evtHedTags{iEvt}, evtAllHedTags{ix});
                if ~isempty(newHedTags)
                    evtAllHedTags{ix} = union(evtAllHedTags{ix}, evtHedTags{iEvt});
                end
            end
        end
    end

    % ===== UDPDATE HED TAGS FOR EACH FILE =====
    for iItem = 1 : nItems
        % Nothing to do
        if isempty(itemEvtNames(iItem))
            continue
        end
        % Get type
        isRaw = strcmpi(sItems(iItem).DataType, 'raw');
        % Get events and their HED tags
        if isRaw
            sData = in_bst_data(sItems(iItem).FileName, 'F');
            sEvents = sData.F.events;
        else
            sData = in_bst_data(sItems(iItem).FileName, 'Events');
            sEvents = sData.Events;
        end
        % Update HED tags
        isModified = 0;
        for iEvent = 1 : length(sEvents)
            iHed = find(strcmp(sEvents(iEvent).label, evtAllNames));
            if ~isempty(iHed)
                if ~isequal(sort(sEvents(iEvent).hedTags), sort(evtAllHedTags{iHed}))
                    sEvents(iEvent).hedTags = evtAllHedTags{iHed};
                    isModified = 1;
                end
            end
        end
        % ===== SAVE RESULT =====
        if isModified
            if isRaw
                sData.F.events = sEvents;
            else
                sData.Events = sEvents;
            end
            bst_save(file_fullpath(sItems(iItem).FileName), sData, [], 1);
        end
    end
end
