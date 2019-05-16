function varargout = process_evt_combine( varargin )
% PROCESS_EVT_COMBINE: Combine different categories events into one (stimulus / response)
%
% USAGE:  OutputFiles = process_evt_combine('Run', sProcess, sInputs)

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
% Authors: Francois Tadel, 2012-2013

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Combine stim/response';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 53;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/EventMarkers?highlight=%28Combine+stim%2Fresponse%29#Events';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Event name
    sProcess.options.combine.Comment = ['Example: We have one stim (A) and two responses (B and C).<BR>' ...
                                        'We want to create two new pairs of event categories:<BR>' ...
                                        '&nbsp;&nbsp;&nbsp;&nbsp;<B>A_AB</B>: Event A (followed by B)<BR>' ...
                                        '&nbsp;&nbsp;&nbsp;&nbsp;<B>A_AC</B>: Event A (followed by C)<BR>' ...
                                        '&nbsp;&nbsp;&nbsp;&nbsp;<B>B_AB</B>: Event B (preceded by A)<BR>' ...
                                        '&nbsp;&nbsp;&nbsp;&nbsp;<B>C_AC</B>: Event C (preceded by A)<BR>' ...
                                        'For that, we use the following classification:<BR>' ...
                                        '&nbsp;&nbsp;&nbsp;&nbsp;<B>A_AB</B> , <B>B_AB</B> , A , B<BR>' ...
                                        '&nbsp;&nbsp;&nbsp;&nbsp;<B>A_AC</B> , <B>C_AC</B> , A , C<BR>' ...
                                        'To prevent one category to be created, use "ignore". Example:<BR>' ...
                                        '&nbsp;&nbsp;&nbsp;&nbsp;A_AB , <B>ignore</B> , A , B<BR>' ...
                                        'To create an extended event AB between A and B, use "extend":<BR>' ...
                                        '&nbsp;&nbsp;&nbsp;&nbsp;AB , <B>extend</B> , A , B<BR>' ...
                                        'You may add as many combinations as needed, one per line.<BR><BR>'];
    sProcess.options.combine.Type    = 'textarea';
    sProcess.options.combine.Value   = ['A_AB, B_AB , A , B' 10 'A_AC, C_AC , A , C'];
    % Maximum duration between simulateous events
    sProcess.options.dt.Comment = 'Maximum delay between grouped events: ';
    sProcess.options.dt.Type    = 'value';
    sProcess.options.dt.Value   = {1, 'ms', 0};
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
    dt = sProcess.options.dt.Value{1};
    % Combination string
    combineStr = strtrim(sProcess.options.combine.Value);
    % Split in lines
    combine_lines = str_split(combineStr, [10 13]);
    % Split each line with the ";"
    combineCell = {};
    for i = 1:length(combine_lines)
        % No information on this line: skip
        combine_lines{i} = strtrim(combine_lines{i});
        if isempty(combine_lines{i})
            continue;
        end
        % Split with ";"
        lineCell = str_split(combine_lines{i}, ';,');
        % If there are not 4 elements on this line: ignore
        if (length(lineCell) ~= 4)
            continue;
        end
        % Add combination entry
        iComb = size(combineCell,1) + 1;
        combineCell{iComb,1} = strtrim(lineCell{1});
        combineCell{iComb,2} = strtrim(lineCell{2});
        combineCell{iComb,3} = strtrim(lineCell{3});
        combineCell{iComb,4} = strtrim(lineCell{4});
    end
    % If no combination available
    if isempty(combineCell)
        bst_report('Error', sProcess, [], 'Invalid combinations format.');
        return;
    end
            
    % For each file
    for iFile = 1:length(sInputs)
        % ===== GET FILE DESCRIPTOR =====
        isRaw = strcmpi(sInputs(iFile).FileType, 'raw');
        % Load the raw file descriptor
        if isRaw
            DataMat = in_bst_data(sInputs(iFile).FileName, 'F');
            sFile = DataMat.F;
        else
            DataMat = in_bst_data(sInputs(iFile).FileName, 'Events');
            sFile.events = DataMat.Events;
            sFile.epochs = [];
        end
       
        % Process only continuous files
        if ~isempty(sFile.epochs)
            bst_report('Error', sProcess, sInputs(iFile), 'This function can only process continuous recordings (no epochs). Skipping File...');
            continue;
        end
        % If no markers are present in this file
        if isempty(sFile.events)
            bst_report('Warning', sProcess, sInputs(iFile), 'This file does not contain any event. Skipping File...');
            continue;
        end
        
        % ===== PROCESS EACH COMBINATION =====
        isModified = 0;
        for iComb = 1:size(combineCell,1)
            % === GET EVENTS INVOLVED ===
            % Find all the events in the structure
            evtNewStimName = combineCell{iComb,1};
            evtNewRespName = combineCell{iComb,2};
            iEvtNewStim = find(strcmpi(evtNewStimName, {sFile.events.label}));
            iEvtNewResp = find(strcmpi(evtNewRespName, {sFile.events.label}));
            iEvtStim    = find(strcmpi(combineCell{iComb,3}, {sFile.events.label}));
            iEvtResp    = find(strcmpi(combineCell{iComb,4}, {sFile.events.label}));
            % If any event not available
            if isempty(iEvtStim)
                bst_report('Warning', sProcess, sInputs(iFile), ['Event "' combineCell{iComb,3} '" does not exist in file. Skipping combination...']);
                continue;
            end
            if isempty(iEvtResp)
                bst_report('Warning', sProcess, sInputs(iFile), ['Event "' combineCell{iComb,4} '" does not exist in file. Skipping combination...']);
                continue;
            end
            % If events are extended events: skip
            if (size(sFile.events(iEvtStim).times,1) > 1) || (size(sFile.events(iEvtResp).times,1) > 1)
                bst_report('Error', sProcess, sInputs(iFile), 'Cannot process extended events. Skipping combination...');
                continue;
            end
            
            % === FIND OTHER RESPONSES ===
            % Get all the other possible responses to this stim
            iOtherResp = find(strcmpi(combineCell(:,3), combineCell{iComb,3}));
            % Do not consider the target response
            iOtherResp = setdiff(iOtherResp, iComb);
            % Loop to get all the times of all the other responses
            tOtherResp = [];
            for iOther = 1:length(iOtherResp)
                % Find event
                evtOtherRespName = combineCell{iOtherResp(iOther),4};
                iEvtOtherResp = find(strcmpi(evtOtherRespName, {sFile.events.label}));
                if isempty(iEvtOtherResp) || isempty(sFile.events(iEvtOtherResp).times) || (size(sFile.events(iEvtOtherResp).times,1) > 1)
                    continue;
                end
                % Get times for this response event
                tOtherResp = [tOtherResp, sFile.events(iEvtOtherResp).times];
            end
            
            % === DETECT RESPONSE TO STIM ===
            % Get stim and resp times
            tStim = sFile.events(iEvtStim).times;
            tResp = sFile.events(iEvtResp).times;
            iNewStim = [];
            iNewResp = [];
            % For each stim event, look for a response
            for is = 1:length(tStim)
                % Look a TARGET response event immediately following a stim event
                if (is == length(tStim))
                    ir = find(tResp > tStim(is), 1);
                else
                    ir = find((tResp > tStim(is)) & (tResp < tStim(is+1)), 1);
                end
                % Look an OTHER response event immediately following a stim event
                if (is == length(tStim))
                    ior = find(tOtherResp > tStim(is), 1);
                else
                    ior = find((tOtherResp > tStim(is)) & (tOtherResp < tStim(is+1)), 1);
                end
                % If a response was found, and before any other response type
                if ~isempty(ir) && (isempty(ior) || (tResp(ir) <= tOtherResp(ior))) && (tResp(ir) - tStim(is) < dt)
                    iNewStim(end+1) = is;
                    iNewResp(end+1) = ir;
                end
            end
            
            % === CREATE NEW EVENTS ===
            % If some couples stim/response were detected: create or udpate the correpsonding events
            if ~isempty(iNewStim)
                isModified = 1;
                % === NEW STIM ===
                % Only create new stim event if name is not "ignore"
                if ~strcmpi(evtNewStimName, 'ignore')
                    % If new stim event does not exist: create
                    if isempty(iEvtNewStim)
                        % Initialize new event
                        iEvtNewStim = length(sFile.events) + 1;
                        sEvent = db_template('event');
                        sEvent.label = evtNewStimName;
                        % Get the default color for this new event
                        sEvent.color = panel_record('GetNewEventColor', iEvtNewStim, sFile.events);
                        % Add new event to list
                        sFile.events(iEvtNewStim) = sEvent;
                    end
                    % Add simple events
                    if ~strcmpi(evtNewRespName, 'extend')
                        sFile.events(iEvtNewStim).times    = [sFile.events(iEvtNewStim).times,   sFile.events(iEvtStim).times(iNewStim)];
                        sFile.events(iEvtNewStim).epochs   = [sFile.events(iEvtNewStim).epochs,  sFile.events(iEvtStim).epochs(iNewStim)];
                        sFile.events(iEvtNewStim).channels = [sFile.events(iEvtNewStim).channels,sFile.events(iEvtStim).channels(iNewStim)];
                        sFile.events(iEvtNewStim).notes    = [sFile.events(iEvtNewStim).notes,   sFile.events(iEvtStim).notes(iNewStim)];
                        % Sort
                        [sFile.events(iEvtNewStim).times, indSort] = unique(sFile.events(iEvtNewStim).times);
                        sFile.events(iEvtNewStim).epochs   = sFile.events(iEvtNewStim).epochs(indSort);
                        sFile.events(iEvtNewStim).channels = sFile.events(iEvtNewStim).channels(indSort);
                        sFile.events(iEvtNewStim).notes    = sFile.events(iEvtNewStim).notes(indSort);
                    % Add extended events
                    else
                        sFile.events(iEvtNewStim).times    = [sFile.events(iEvtNewStim).times,   [sFile.events(iEvtStim).times(iNewStim); sFile.events(iEvtResp).times(iNewResp)]];
                        sFile.events(iEvtNewStim).epochs   = [sFile.events(iEvtNewStim).epochs,  sFile.events(iEvtStim).epochs(iNewStim)];
                        sFile.events(iEvtNewStim).channels = [sFile.events(iEvtNewStim).channels,sFile.events(iEvtStim).channels(iNewStim)];
                        sFile.events(iEvtNewStim).notes    = [sFile.events(iEvtNewStim).notes,   sFile.events(iEvtStim).notes(iNewStim)];
                    end
                end
                
                % === NEW RESP ===
                % Only create new response event if name is not "ignore" or "extend"
                if ~strcmpi(evtNewRespName, 'ignore') && ~strcmpi(evtNewRespName, 'extend')
                    % If new stim event does not exist: create
                    if isempty(iEvtNewResp)
                        % Initialize new event
                        iEvtNewResp = length(sFile.events) + 1;
                        sEvent = db_template('event');
                        sEvent.label = evtNewRespName;
                        % Get the default color for this new event
                        sEvent.color = panel_record('GetNewEventColor', iEvtNewResp, sFile.events);
                        % Add new event to list
                        sFile.events(iEvtNewResp) = sEvent;
                    end
                    % Add occurrences
                    sFile.events(iEvtNewResp).times    = [sFile.events(iEvtNewResp).times,    sFile.events(iEvtResp).times(iNewResp)];
                    sFile.events(iEvtNewResp).epochs   = [sFile.events(iEvtNewResp).epochs,   sFile.events(iEvtResp).epochs(iNewResp)];
                    sFile.events(iEvtNewResp).channels = [sFile.events(iEvtNewResp).channels, sFile.events(iEvtResp).channels(iNewResp)];
                    sFile.events(iEvtNewResp).notes    = [sFile.events(iEvtNewResp).notes,    sFile.events(iEvtResp).notes(iNewResp)];
                    % Sort
                    [sFile.events(iEvtNewResp).times, indSort] = unique(sFile.events(iEvtNewResp).times);
                    sFile.events(iEvtNewResp).epochs   = sFile.events(iEvtNewResp).epochs(indSort);
                    sFile.events(iEvtNewResp).channels = sFile.events(iEvtNewResp).channels(indSort);
                    sFile.events(iEvtNewResp).notes    = sFile.events(iEvtNewResp).notes(indSort);
                end
            end
        end

        % ===== SAVE RESULT =====
        % Report results
        if isRaw
            DataMat.F = sFile;
        else
            DataMat.Events = sFile.events;
        end
        % Only save changes if something was change
        if isModified
            bst_save(file_fullpath(sInputs(iFile).FileName), DataMat, 'v6', 1);
        end
        % Return all the input files
        OutputFiles{end+1} = sInputs(iFile).FileName;
    end
end




