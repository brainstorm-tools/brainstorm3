function varargout = process_evt_transfer(varargin )
% PROCESS_EVT_TRANSFER: Transfers events from set A to set B

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
% Authors: Martin Voelker, 2015

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Transfer events (from A to B)';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Synchronize';
    sProcess.Index       = 680;
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
    
    % === GET OPTIONS ===
    strComment = '';
    %...
    
    % === Sync event management === %
    SyncEventName.A = sProcess.options.src.Value;
    SyncEventName.B = sProcess.options.dest.Value;
    
    % ===== LOAD FILES =====   
    sInputs = struct();
    sInputs.A = sInputsA;
    sInputs.B = sInputsB;
    clear sInputsA sInputsB;
    
    % === Load events from dataset(s) in A & B ===
    for set = ['A', 'B'];
        nTrials.(set) = numel(sInputs.(set));
        for iTrial = 1:nTrials.(set)

            % Get file descriptor
            isRaw = strcmpi(sInputs.(set)(iTrial).FileType, 'raw');
            % Load the raw file descriptor
            if isRaw
                sMat.(set)(iTrial) = in_bst_data(sInputs.(set)(iTrial).FileName, 'F');
                sEvents.(set){iTrial} = sMat.(set)(iTrial).F.events;
                sFreq.(set)(iTrial) = sMat.(set)(iTrial).F.prop.sfreq;
            else
                sMat.(set)(iTrial) = in_bst_data(sInputs.(set)(iTrial).FileName, 'Events', 'Time');
                sEvents.(set){iTrial} = sMat.(set)(iTrial).Events;
                sFreq.(set)(iTrial) = 1 ./ (sMat.(set)(iTrial).Time(2) - sMat.(set)(iTrial).Time(1));
            end
            % Look for events
            iEvt = find(strcmp({sEvents.(set){iTrial}.label}, SyncEventName.(set)));
            if isempty(iEvt)
                bst_report('Error', sProcess, sInputs.(set)(iTrial), ['Event "' SyncEventName.(set) '" not found.']);
                return;
            end
            % Save info
            nEvents.(set)(iTrial) = numel(sEvents.(set){iTrial});            
            iSyncEvent.(set)(iTrial) = find(strcmp({sEvents.(set){iTrial}.label}, SyncEventName.(set)));
            nSyncEvent.(set)(iTrial) = numel(sEvents.(set){iTrial}(iSyncEvent.(set)(iTrial)).times);
        end
    end    
    
    %% Make sure the number of synchronization events is the same in both datasets

    % Error if number of sync triggers is not the same in both data sets
    if sum(nSyncEvent.A) ~= sum(nSyncEvent.B)
        bst_report('Error', sProcess, sInputs.A, 'Cannot process inputs with a different number of synchronization triggers.');
        return;
    end
    
    syncCountA = 0;      % keeps track of the sync event was last processed (within current trial of data set A)    
    iTrialA = 1;         % keeps track of the data set(s) A trial currently in use
     
    % === Loop through epochs in set B, transfer events from A to B ===
    nTrials = numel(sInputs.B);    
    for iTrialB = 1:nTrials
        syncCountB = 0;
        
        while syncCountB < nSyncEvent.B(iTrialB)  %loop trough multiple trials in A, if multiple trials are associated with one trial in B
        
            % Decide which trial of data set A must be used
            if nSyncEvent.A(iTrialA) == syncCountA   %last event of this trial already used, skip to next trial
                iTrialA = iTrialA+1;
                syncCountA = 0;
            elseif nSyncEvent.A(iTrialA) < syncCountA % this should hopefully not happen.
                bst_report('Error', sProcess, sInputs.A, 'Error in chosing the right trial in data set A.');
            end            
        
            % === Synchronization ===  
            
            % Calculation of offset between the two data sets
            syncIdcsA = syncCountA+1 : syncCountA + min([nSyncEvent.B(iTrialB) nSyncEvent.A(iTrialA)]);    %find out which sync event indeces in this trial of A to use now
            syncIdcsB = syncCountB+1 : syncCountB + min([nSyncEvent.B(iTrialB) nSyncEvent.A(iTrialA)]);    %find out which sync event indeces in this trial of B to use now
            
            Offsets = sEvents.A{iTrialA}(iSyncEvent.A(iTrialA)).times(syncIdcsA) - sEvents.B{iTrialB}(iSyncEvent.B(iTrialB)).times(syncIdcsB);
            tOffsetA = median(Offsets);
            offsetVar = var(Offsets);
            offsetStd = std(Offsets);
            disp(['The variance of the sample offset is ' num2str(offsetVar*1000) 'ms (std: ' num2str(offsetStd*1000) 'ms)']);
            
            % find current epoch number of set B
            currentEpoch = unique(sEvents.B{iTrialB}(iSyncEvent.B(iTrialB)).epochs(syncIdcsB));
            %Error if more than one epoch...
            if numel(currentEpoch) > 1
                bst_report('Error', sProcess, sInputs.A, 'There is more than one epoch within this sync period. Aborting.');
            end

            % find time window within which to pick events of this trial in set A
            t_min = min([sEvents.B{iTrialB}.times]); % first event time in this trial of set B
            t_max = max([sEvents.B{iTrialB}.times]); % last event time in this trial of set B
            syncWindow = [t_min, t_max] + tOffsetA;        

            % Transfer events, calculate new samples
            for iEventA = 1:nEvents.A(iTrialA)
                
                %find out if this event type is already present in this trial of set B
                if isempty(find(strcmp(sEvents.A{iTrialA}(iEventA).label, {sEvents.B{iTrialB}(:).label}), 1)) %label not found, create new event type    
                    
                    iEventB = nEvents.B(iTrialB)+iEventA; % = new event
                    nEvtExst = 0; %number of existing events of this type = 0                   
                    
                    sEvents.B{iTrialB}(iEventB) = sEvents.A{iTrialA}(iEventA);
                    nTimes = numel(sEvents.B{iTrialB}(iEventB).times);
                    sEvents.B{iTrialB}(iEventB).times    = nan(1,nTimes);
                    sEvents.B{iTrialB}(iEventB).epochs   = ones(1,nTimes)*currentEpoch;
                    sEvents.B{iTrialB}(iEventB).channels = cell(1,nTimes);
                    sEvents.B{iTrialB}(iEventB).notes    = cell(1,nTimes);
                else % label found, use existing event                    
                    iEventB = find(strcmp(sEvents.A{iTrialA}(iEventA).label, {sEvents.B{iTrialB}(:).label}));
                    nEvtExst = numel(sEvents.B{iTrialB}(iEventB).times);
                    
                    nTimes = numel(sEvents.A{iTrialA}(iEventA).times);
                    sEvents.B{iTrialB}(iEventB).times    = [sEvents.B{iTrialB}(iEventB).times,    nan(1,nTimes)];
                    sEvents.B{iTrialB}(iEventB).epochs   = [sEvents.B{iTrialB}(iEventB).epochs,   ones(1,nTimes)*currentEpoch];
                    sEvents.B{iTrialB}(iEventB).channels = [sEvents.B{iTrialB}(iEventB).channels, cell(1,nTimes)]; 
                    sEvents.B{iTrialB}(iEventB).notes    = [sEvents.B{iTrialB}(iEventB).notes,    cell(1,nTimes)]; 
                end
                
                for iTime = 1:numel(sEvents.A{iTrialA}(iEventA).times)
                    % use only events in sync time window
                    if sEvents.A{iTrialA}(iEventA).times(iTime)  > syncWindow(2) % already over maximum, break loop to save time
                        break
                    end

                    if syncWindow(1) <= sEvents.A{iTrialA}(iEventA).times(iTime)
                        % Calculation of samples and timepoints in dataset B.               
                        sEvents.B{iTrialB}(iEventB).times(iTime+nEvtExst) = round((sEvents.A{iTrialA}(iEventA).times(iTime)-tOffsetA) *sFreq.B(iTrialB)) ./ sFreq.B(iTrialB);
                    end                
                end  
                % delete out-of-window times, samples & epochs
                if ~isempty(find(isnan(sEvents.B{iTrialB}(iEventB).times), 1))
                    invalidEvts = find(isnan(sEvents.B{iTrialB}(iEventB).times)); % out of time window
                    sEvents.B{iTrialB}(iEventB).times(invalidEvts) = [];
                    sEvents.B{iTrialB}(iEventB).epochs(invalidEvts) = [];
                    sEvents.B{iTrialB}(iEventB).channels(invalidEvts) = [];
                    sEvents.B{iTrialB}(iEventB).notes(invalidEvts) = [];
                end
           end 

            % Manage sync event counters
            syncCount = numel(syncIdcsA);
            syncCountA = syncCountA + syncCount;
            syncCountB = syncCountB + syncCount;
        end
        
        % Store events in output
        if isRaw
            sMat.B(iTrialB).F.events = sEvents.B{iTrialB};
        else
            sMat.B(iTrialB).Events = sEvents.B{iTrialB};
        end
            
    end
    
    % === CREATE OUTPUT STRUCTURE ===
    % Get output study
%     [sStudy, iStudy] = bst_process('GetOutputStudy', sProcess, [sInputs.A, sInputs.B]);

    % === SAVE FILES ===
    OutputFiles = cell(1, numel(sMat.B));
    for iTrialB = 1:numel(sMat.B)
        % Output filename
        sMat.B(iTrialB).Comment = [sInputs.B(iTrialB).Condition, ' + events(', sInputs.A(1).Condition, ')', strComment];
        
        bst_save(file_fullpath(sInputs.B(iTrialB).FileName), sMat.B(iTrialB), 'v6', 1);
        OutputFiles{iTrialB} = sInputs.B(iTrialB).FileName;

    end
end





