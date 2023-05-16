function varargout = process_evt_transfer(varargin )
% PROCESS_EVT_TRANSFER: Transfers events from set A to set B

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
% Authors: Martin Voelker, 2015
%          Raymundo Cassani, 2023

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Transfer events (from A to B)';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Synchronize';
    sProcess.Index       = 680;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/EyetrackSynchro';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;
    
    %Description of options
    sProcess.options.inputs.Comment = ['Transfers events from dataset A to dataset B.<BR><BR>' ...
        'For synchronization, please choose an<BR>event type which is available in both datasets.<BR><BR>'];
    sProcess.options.inputs.Type    = 'label';
    
    % Source Event name for synchronization (data set A)
    sProcess.options.src.Comment  = 'Sync event name in set A (source): ';
    sProcess.options.src.Type     = 'text';
    sProcess.options.src.Value    = '5';
    % Destination Event name for synchronization (data set B)
    sProcess.options.dest.Comment = 'Sync event name in set B (destination): ';
    sProcess.options.dest.Type    = 'text';
    sProcess.options.dest.Value   = 'E5';       
end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end

%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputsA, sInputsB)
    OutputFiles = {};
    
    % Names for sync events
    SyncEventName.A = sProcess.options.src.Value;
    SyncEventName.B = sProcess.options.dest.Value;
    
    % Rearrange input files
    sInputs = struct();
    sInputs.A = sInputsA;
    sInputs.B = sInputsB;
    clear sInputsA sInputsB;

    % Load events from datasets A and B
    for set = ['A', 'B']
        for iInput = 1 : length(sInputs.(set))
            % Get file descriptors
            isRaw = strcmpi(sInputs.(set)(iInput).FileType, 'raw');
            if isRaw
                DataMatTmp = in_bst_data(sInputs.(set)(iInput).FileName, 'F');
                sFileTmp = DataMatTmp.F;
                % Error for epoched CTF and NWB files
                if ismember(sFileTmp.format, {'CTF', 'NWB'})
                    bst_report('Error', sProcess, sInputs.(set)(iInput), 'Impossible to process native epoched files. Please import them in database or convert them to continuous.');
                end
                timeExtension(iInput).(set) = sFileTmp.prop.times;
            else
                DataMatTmp = in_bst_data(sInputs.(set)(iInput).FileName, 'Events', 'Time');
                sFileTmp.events = DataMatTmp.Events;
                sFileTmp.prop.sfreq = 1 ./ (DataMatTmp.Time(2) - DataMatTmp.Time(1));
                timeExtension(iInput).(set) = [DataMatTmp.Time(1), DataMatTmp.Time(end)];
            end
            % Concatenate events
            if iInput == 1
                sFile.(set).events = sFileTmp.events;
                sFile.(set).prop.sfreq = sFileTmp.prop.sfreq;
            elseif ~isempty(sFileTmp.events)
                sFile.(set) = import_events(sFile.(set), [], sFileTmp.events);
            end
        end
        % Events used for synchronization
        iSyncEvent.(set) = find(strcmp({sFile.(set).events.label}, SyncEventName.(set)));
        nSyncEvent.(set) = length(sFile.(set).events(iSyncEvent.(set)).times);
    end
    
    % Check for same number of sync events in datasets A and B
    if nSyncEvent.A ~= nSyncEvent.B
        bst_report('Error', sProcess, sInputs.A, 'Cannot process inputs with a different number of synchronization triggers.');
        return;
    end

    % Verify that files in datasets A and B do not overlap in time
    if any(diff([timeExtension.A]) < 0)
        bst_report('Error', sProcess, sInputs.A, 'There is time overlap for A files.');
    end
    if any(diff([timeExtension.B]) < 0)
        bst_report('Error', sProcess, sInputs.B, 'There is time overlap for B files.');
    end

    % Calculation of offset between the two datasets
    Offsets  = sFile.A.events(iSyncEvent.A).times - sFile.B.events(iSyncEvent.B).times;
    tOffsetA  = median(Offsets);
    offsetStd = std(Offsets);
    disp(['The population standard deviation of the offsets is ' num2str(offsetStd*1000) ' ms.']);

    % Apply offset to dataset A events and update their label
    iEventGroupsToTransfer = setdiff(1 : length(sFile.A.events), iSyncEvent.A);
    for ix = 1 : length(iEventGroupsToTransfer)
        sFile.A.events(iEventGroupsToTransfer(ix)).times = sFile.A.events(iEventGroupsToTransfer(ix)).times - tOffsetA;
        sFile.A.events(iEventGroupsToTransfer(ix)).label = ['sync ', sFile.A.events(iEventGroupsToTransfer(ix)).label];
    end

    % Loop files in dataset B, transfer events from dataset A
    for iFilesB = 1 : length(sInputs.B)
        % Load events in B file
        if isRaw
            DataMat = in_bst_data(sInputs.B(iFilesB).FileName, 'F');
            sFileTmp = DataMat.F;
        else
            DataMat = in_bst_data(sInputs.B(iFilesB).FileName);
            sFileTmp.events = DataMat.Events;
            sFileTmp.prop.sfreq = 1 ./ (DataMat.Time(2) - DataMat.Time(1));
        end
        % Transfer events from dataset A to file B, if their occurence belongs to file B
        for ix = 1 : length(iEventGroupsToTransfer)
            newEvents  = sFile.A.events(iEventGroupsToTransfer(ix));
            curreTimes = timeExtension(iFilesB).B;
            validTimes = and(newEvents.times >= curreTimes(1), newEvents.times <= curreTimes(2));
            if any(validTimes)
                newEvents.times  = newEvents.times(validTimes);
                newEvents.epochs = ones(1,length(newEvents.times));
                sFileTmp = import_events(sFileTmp, [], newEvents);
            end
        end
        % Update events and comment in output
        if isRaw
            DataMat.F.events = sFileTmp.events;
        else
            DataMat.Events = sFileTmp.events;
            DataMat.Comment = [DataMat.Comment, ' | sync_events'];
        end
        % Save output file
        bst_save(file_fullpath(sInputs.B(iFilesB).FileName), DataMat, 'v6', 1);
        OutputFiles{iFilesB} = sInputs.B(iFilesB).FileName;
    end
    db_reload_studies(sInputs.B(1).iStudy);
end

