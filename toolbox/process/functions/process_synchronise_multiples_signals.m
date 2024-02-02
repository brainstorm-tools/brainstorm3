function varargout = process_synchronise_multiples_signals(varargin)
% process_synchronise_multiples_signals: Synchronise multiple signals based on common event

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
% Authors: Edouard Delaire, 2021-2023
eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Synchronyse files';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Synchronize';
    sProcess.Index       = 681;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    
    %Description of options
    sProcess.options.inputs.Comment = ['For synchronization, please choose an<BR>event type which is available in all datasets.<BR><BR>'];
    sProcess.options.inputs.Type    = 'label';
    
    % Source Event name for synchronization 
    sProcess.options.src.Comment  = 'Sync event name: ';
    sProcess.options.src.Type     = 'text';
    sProcess.options.src.Value    = 'sync';
 
end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs)
    OutputFiles = {};
    
    nInputs = length(sInputs);
    
    % === Sync event management === %
    SyncEventName  = sProcess.options.src.Value;
    
    sOldTiming     = cell(1,nInputs);
    sSync           = cell(1,nInputs);
    fs              = zeros(1, nInputs);
    
    is_raw = strcmp({sInputs.FileType},'raw');
    if ~all(is_raw) && ~all(~is_raw)
        bst_error('Please don\''t mix continous and imported data', 'Synchronize sigal', 0);
        return;
    else
        is_raw = is_raw(1);
    end
    
    bst_progress('start', 'Synchronizing files', 'Loading data...', 0, 3*nInputs);

    for iInput = 1:nInputs
        if strcmp(sInputs(iInput).FileType, 'data')     % Imported data structure
            sData = in_bst_data(sInputs(iInput).FileName, 'Time', 'Events');
            sOldTiming{iInput}.Time = sData.Time;
            sOldTiming{iInput}.Events = sData.Events;
            fs(iInput)       = 1/(sOldTiming{iInput}.Time(2) -  sOldTiming{iInput}.Time(1)) ; % in Hz
        elseif strcmp(sInputs(iInput).FileType, 'raw')  % Continuous data file
            sDataRaw = in_bst_data(sInputs(iInput).FileName, 'Time', 'F');
            sOldTiming{iInput}.Time = sDataRaw.Time;
            sOldTiming{iInput}.Events = sDataRaw.F.events;
            fs(iInput)       = sDataRaw.F.prop.sfreq; % in Hz
        end
        sSync{iInput} = sOldTiming{iInput}.Events(strcmp({sOldTiming{iInput}.Events.label}, SyncEventName));
    end

    bst_progress('inc', nInputs);
    bst_progress('text', 'Synchronizing...');

    new_times       = cell(1,nInputs);
    new_times{1}    = sOldTiming{1}.Time;
    mean_shifting   = zeros(1, nInputs);
    
    % Compute shifiting between file i and first file, and align Time vectores
    for iInput = 2:nInputs
        if length(sSync{iInput}.times) == length(sSync{1}.times)
            shifting = sSync{iInput}.times -  sSync{1}.times;
            
            mean_shifting(iInput) = mean(shifting);
            offsetStd = std(shifting);
        else
            bst_report('Warning', sProcess, sInputs, 'Files doesnt have the same number of trigger. Using approximation');
            % Correlate the trigger signals; need to be at the same
            % frequency. Choose the frequency of the larger signal 
            
            tmp_fs      = max(fs(iInput), fs(1));
            tmp_time_a  = sOldTiming{iInput}.Time(1) : 1/tmp_fs : sOldTiming{iInput}.Time(end);
            tmp_time_b  = sOldTiming{1}.Time(1):1/tmp_fs:sOldTiming{1}.Time(end);

            blocA = zeros(1 , length(tmp_time_a)); 
            for i_event = 1:size(sSync{iInput}.times,2)
                i_intra_event = panel_time('GetTimeIndices', tmp_time_a,  sSync{iInput}.times(i_event) + [0 1]');
                blocA(1,i_intra_event) = 1;
            end
            
            blocB = zeros(1 , length(tmp_time_b)); 
            for i_event = 1:size(sSync{1}.times,2)
               i_intra_event = panel_time('GetTimeIndices', tmp_time_b,  sSync{1}.times(i_event) + [0 1]');
               blocB(1,i_intra_event) = 1;
            end
            
            [c,lags]        = xcorr(blocA,blocB);
            [c_max,colum]   = max(c);
            
            
            mean_shifting(iInput) = lags(colum) / tmp_fs;
            offsetStd = 0;
        end    
        disp(sprintf('Lag difference between %s and %s : %.2f ms (std: %.2f ms)',sInputs(1).Condition, sInputs(iInput).Condition,mean_shifting(iInput)*1000,offsetStd*1000 ));
        new_times{iInput} = sOldTiming{iInput}.Time - mean_shifting(iInput);
    end    
    
    % detect new start and end
    new_start   = max(cellfun(@(x)min(x), new_times));
    new_end     = min(cellfun(@(x)max(x), new_times));

    sNewTiming = sOldTiming;
    pool_events = [];
    
    % New time vectors, and new events
    for iInput = 1:nInputs
        
        index = panel_time('GetTimeIndices', new_times{iInput}, [new_start, new_end]);

        sNewTiming{iInput}.Time    = new_times{iInput}(index) - new_times{iInput}(index(1)) ;
        tmp_event = sNewTiming{iInput}.Events;

        for i_event = 1:length(tmp_event)
            tmp_event(i_event).times = tmp_event(i_event).times - mean_shifting(iInput) - new_times{iInput}(index(1)) ;
            if isempty(pool_events)
                pool_events = tmp_event(i_event);
            elseif ~strcmp(tmp_event(i_event).label,SyncEventName)  || (strcmp(tmp_event(i_event).label,SyncEventName) && ~any(strcmp({pool_events.label},SyncEventName)))
                pool_events = [pool_events tmp_event(i_event)];
            end   
        end  
    end

    % Add event to file
    for iInput = 1:nInputs
        sNewTiming{iInput}.Events = pool_events;
    end

    bst_progress('inc', nInputs);
    bst_progress('text', 'Saving files...');

    % Save data to file
    ProtocolInfo = bst_get('ProtocolInfo');
    for iInput = 1:nInputs
        if ~is_raw
            sDataSync = in_bst_data(sInputs(iInput).FileName);
            % Update times and events
            sDataSync.Time = sNewTiming{iInput}.Time;
            sDataSync.Events = sNewTiming{iInput}.Events;
            % Update data
            index = panel_time('GetTimeIndices', new_times{iInput}, [new_start, new_end]);
            sDataSync.F       = sDataSync.F(:,index);
            sDataSync.Comment = [sDataSync.Comment ' | Synchronized '];
            
            sStudy      = bst_get('Study', sInputs(iInput).iStudy);
            OutputFile  = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), 'data_sync');
            sDataSync.FileName = file_short(OutputFile);
            bst_save(OutputFile, sDataSync, 'v7');

            % Register in database
            db_add_data(sInputs(iInput).iStudy, OutputFile, sDataSync);
        else

            newCondition = [sInputs(iInput).Condition '_synced'];
            iStudy = db_add_condition(sInputs(iInput).SubjectName, newCondition);
            sStudy = bst_get('Study', iStudy);
    
            % Save channel definition
            ChannelMat = in_bst_channel(sInputs(iInput).ChannelFile);
            [tmp, iChannelStudy] = bst_get('ChannelForStudy', iStudy);
            db_set_channel(iChannelStudy, ChannelMat, 0, 0);


            OutputFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), 'data_raw_sync');
            newStudyPath = bst_fullfile(ProtocolInfo.STUDIES, sInputs(iInput).SubjectName,newCondition);

            [tmp, rawBaseOut, rawBaseExt] = bst_fileparts(newStudyPath);
            rawBaseOut = strrep([rawBaseOut rawBaseExt], '@raw', '');
            % Full output filename
            RawFileOut = bst_fullfile(newStudyPath, [rawBaseOut '.bst']);

            sDataRawSync = in_bst_data(sInputs(iInput).FileName, 'F');
            sFileIn = sDataRawSync.F;
            sFileIn.events = sNewTiming{iInput}.Events;
            sFileIn.header.nsamples = length( sNewTiming{iInput}.Time );
            sFileIn.prop.times      = [ sNewTiming{iInput}.Time(1),  sNewTiming{iInput}.Time(end)];
            [sFileOut, errMsg] = out_fopen(RawFileOut, 'BST-BIN', sFileIn, ChannelMat);
            
            % Set Output sFile structure
            sDataSync     = in_bst(sInputs(iInput).FileName, [], 1, 1, 'no');
            sOutMat                 = rmfield(sDataSync, 'F');
            sOutMat.format          = 'BST-BIN';
            sOutMat.DataType        = 'raw'; 
            sOutMat.F               = sFileOut;
            sOutMat.Comment         = [sDataSync.Comment ' | Synchronized'];
            sOutMat                 = bst_history('add', sOutMat, 'process', 'Synchronisation');
            % Update data
            index = panel_time('GetTimeIndices', new_times{iInput}, [new_start, new_end]);
            sDataSync.F       = sDataSync.F(:,index);

            % Save new link to raw .mat file
            bst_save(OutputFile, sOutMat, 'v6');
            % Write block
            out_fwrite(sFileOut, ChannelMat, 1, [], [], sDataSync.F);
            % Register in BST database
            db_add_data(iStudy, OutputFile, sOutMat);
        end
        OutputFiles{iInput} = OutputFile;
        bst_progress('inc', 1);
    end

    bst_progress('stop');
end    