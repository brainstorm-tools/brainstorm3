function varargout = process_sync_recordings(varargin)
% process_sync_recordings: Synchronize multiple signals based on common event

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
% Authors: Edouard Delaire, 2021-2023
%          Raymundo Cassani, 2024

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Synchronyze files';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Synchronize';
    sProcess.Index       = 681;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 2;
    
    %Description of options
    sProcess.options.inputs.Comment = ['For synchronization, please choose an<BR>event type ' ...
                                       'which is available in all datasets.<BR><BR>'];
    sProcess.options.inputs.Type    = 'label';
    
    % Source Event name for synchronization 
    sProcess.options.src.Comment  = 'Sync event name: ';
    sProcess.options.src.Type     = 'text';
    sProcess.options.src.Value    = '';
 
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs)
    OutputFiles = {};

    % === Sync event management === %
    syncEventName  = sProcess.options.src.Value;
    nInputs        = length(sInputs);
    sEvtSync       = repmat(db_template('event'), 1, nInputs);
    sOldTiming     = cell(1, nInputs);
    fs             = zeros(1, nInputs);
    
    % Check: Same FileType for all files
    is_raw = strcmp({sInputs.FileType},'raw');
    if ~all(is_raw) && ~all(~is_raw)
        bst_error('Please do not mix continous (raw) and imported data', 'Synchronize signal', 0);
        return;
    end
    is_raw = is_raw(1);
    
    bst_progress('start', 'Synchronizing files', 'Loading data...', 0, 3*nInputs);

    % Get Time vector, events and sampling frequency for each file
    for iInput = 1:nInputs
        if strcmp(sInputs(iInput).FileType, 'data')     % Imported data structure
            sData = in_bst_data(sInputs(iInput).FileName, 'Time', 'Events');
            sOldTiming{iInput}.Time   = sData.Time;
            sOldTiming{iInput}.Events = sData.Events;
        elseif strcmp(sInputs(iInput).FileType, 'raw')  % Continuous data file
            sDataRaw = in_bst_data(sInputs(iInput).FileName, 'Time', 'F');
            sOldTiming{iInput}.Time   = sDataRaw.Time;
            sOldTiming{iInput}.Events = sDataRaw.F.events;
        end
        fs(iInput) = 1/(sOldTiming{iInput}.Time(2) -  sOldTiming{iInput}.Time(1)); % in Hz
        iSyncEvt = strcmp({sOldTiming{iInput}.Events.label}, syncEventName);
        if any(iSyncEvt)
            sEvtSync(iInput) = sOldTiming{iInput}.Events(iSyncEvt);
        end
    end

    % Check: Sync event must be present in all files
    if any(~(strcmp({sEvtSync.label}, syncEventName)))
        bst_error(['Sync event ("' syncEventName '") must be present in all files'], 'Synchronize signal', 0);
        return;
    end

    % Check: Sync event must be simple event
    if any(cellfun(@(x) size(x,1), {sEvtSync.times}) ~= 1)
        bst_error(['Sync event ("' syncEventName '") must be simple event in all the files'], 'Synchronize signal', 0);
        return;
    end

    bst_progress('inc', nInputs);
    bst_progress('text', 'Synchronizing...');

    % First Input is the one wiht highest sampling frequency
    [~, im] = max(fs);
    sInputs([1, im])    = sInputs([im, 1]);
    sEvtSync([1, im])   = sEvtSync([im, 1]);
    sOldTiming([1, im]) = sOldTiming([im, 1]);
    fs([1, im])         = fs([im, 1]);

    % Compute shifiting between file i and first file
    new_times     = cell(1,nInputs);
    new_times{1}  = sOldTiming{1}.Time;
    mean_shifting = zeros(1, nInputs);
    for iInput = 2:nInputs
        if size(sEvtSync(iInput).times, 2) == size(sEvtSync(1).times, 2)
            shifting = sEvtSync(iInput).times - sEvtSync(1).times;
            mean_shifting(iInput) = mean(shifting);
            offsetStd = std(shifting);
        else
            bst_report('Warning', sProcess, sInputs, 'Files doesnt have the same number of sync events. Using approximation');
            % Cross-correlate trigger signals; need to be at the same sampling frequency
            tmp_fs      = max(fs(iInput), fs(1));
            tmp_time_a  = sOldTiming{iInput}.Time(1):1/tmp_fs:sOldTiming{iInput}.Time(end);
            tmp_time_b  = sOldTiming{1}.Time(1):1/tmp_fs:sOldTiming{1}.Time(end);

            blocA = zeros(1 , length(tmp_time_a)); 
            for i_event = 1:size(sEvtSync(iInput).times,2)
                i_intra_event = panel_time('GetTimeIndices', tmp_time_a,  sEvtSync(iInput).times(i_event) + [0 1]');
                blocA(1,i_intra_event) = 1;
            end
            
            blocB = zeros(1 , length(tmp_time_b)); 
            for i_event = 1:size(sEvtSync(1).times,2)
               i_intra_event = panel_time('GetTimeIndices', tmp_time_b,  sEvtSync(1).times(i_event) + [0 1]');
               blocB(1,i_intra_event) = 1;
            end
            
            [c,lags]  = xcorr(blocA,blocB);
            [~,colum] = max(c);

            mean_shifting(iInput) = lags(colum) / tmp_fs;
            offsetStd = 0;
        end    
        new_times{iInput} = sOldTiming{iInput}.Time - mean_shifting(iInput);
        disp(sprintf('Lag difference between %s and %s : %.2f ms (std: %.2f ms)', ...
            sInputs(1).Condition, sInputs(iInput).Condition, mean_shifting(iInput)*1000, offsetStd*1000));
    end    
    
    % New start and new end
    new_start   = max(cellfun(@(x)min(x), new_times));
    new_end     = min(cellfun(@(x)max(x), new_times));

    % Compute new time vectors, and new events times
    sNewTiming = sOldTiming;
    pool_events = [];
    for iInput = 1:nInputs
        index = panel_time('GetTimeIndices', new_times{iInput}, [new_start, new_end]);
        sNewTiming{iInput}.Time = new_times{iInput}(index) - new_times{iInput}(index(1));
        tmp_events = sNewTiming{iInput}.Events;
        for i_event = 1:length(tmp_events)
            % Update event times
            tmp_events(i_event).times = tmp_events(i_event).times - mean_shifting(iInput) - new_times{iInput}(index(1));
            % Remove events outside new time range
            timeRange = [sNewTiming{iInput}.Time(1), sNewTiming{iInput}.Time(end)];
            iEventTimesDel = all(or(tmp_events(i_event).times < timeRange(1), tmp_events(i_event).times > timeRange(2)), 1);
            tmp_events(i_event).times(:,iEventTimesDel)  = [];
            tmp_events(i_event).epochs(iEventTimesDel)   = [];
            if ~isempty(tmp_events(i_event).channels)
                tmp_events(i_event).channels(iEventTimesDel) = [];
            end
            if ~isempty(tmp_events(i_event).notes)
                tmp_events(i_event).notes(iEventTimesDel) = [];
            end
            if ~isempty(tmp_events(i_event).reactTimes)
                tmp_events(i_event).reactTimes(iEventTimesDel) = [];
            end
            % Clip values to time range
            tmp_events(i_event).times(tmp_events(i_event).times < timeRange(1)) = timeRange(1);
            tmp_events(i_event).times(tmp_events(i_event).times > timeRange(2)) = timeRange(2);
            % Aggregate eventes across files
            if isempty(pool_events)
                pool_events = tmp_events(i_event);
            elseif ~strcmp(tmp_events(i_event).label,syncEventName)  || (strcmp(tmp_events(i_event).label,syncEventName) && ~any(strcmp({pool_events.label},syncEventName)))
                pool_events = [pool_events tmp_events(i_event)];
            end   
        end  
    end
    % Update polled events
    for iInput = 1:nInputs
        sNewTiming{iInput}.Events = pool_events;
    end

    bst_progress('inc', nInputs);
    bst_progress('text', 'Saving files...');

    % Save sync data to file
    for iInput = 1:nInputs
        if ~is_raw
            % Load original data
            sDataSync = in_bst_data(sInputs(iInput).FileName);
            % Set new time and events
            sDataSync.Comment = [sDataSync.Comment ' | Synchronized '];
            sDataSync.Time    = sNewTiming{iInput}.Time;
            sDataSync.Events  = sNewTiming{iInput}.Events;
            % Update data
            index = panel_time('GetTimeIndices', new_times{iInput}, [new_start, new_end]);
            sDataSync.F = sDataSync.F(:,index);
            % History: List of sync files
            sDataSync = bst_history('add', sDataSync, 'sync', ['List of synchronized files (event = "', syncEventName , '"):']);
            for ix = 1:nInputs
                sDataSync = bst_history('add', sDataSync, 'sync', [' - ' sInputs(ix).FileName]);
            end
            % Save data
            OutputFile = bst_process('GetNewFilename', bst_fileparts(sInputs(iInput).FileName), 'data_sync');
            sDataSync.FileName = file_short(OutputFile);
            bst_save(OutputFile, sDataSync, 'v7');
            % Register in database
            db_add_data(sInputs(iInput).iStudy, OutputFile, sDataSync);
        else
            % New raw condition
            newCondition = [sInputs(iInput).Condition '_synced'];
            iNewStudy = db_add_condition(sInputs(iInput).SubjectName, newCondition);
            sNewStudy = bst_get('Study', iNewStudy);
            % Sync videos
            sOldStudy = bst_get('Study', sInputs(iInput).iStudy);
            if isfield(sOldStudy,'Image') && ~isempty(sOldStudy.Image)
                for iOldVideo = 1 : length(sOldStudy.Image)
                    sOldVideo = load(file_fullpath(sOldStudy.Image(iOldVideo).FileName));
                    if isempty(sOldVideo.VideoStart)
                        sOldVideo.VideoStart = 0;
                    end
                    iNewVideo = import_video(iNewStudy, sOldVideo.LinkTo);
                    sNewStudy = bst_get('Study', iNewStudy);
                    figure_video('SetVideoStart', file_fullpath(sNewStudy.Image(iNewVideo).FileName), sprintf('%.3f', sOldVideo.VideoStart - mean_shifting(iInput) - new_start));
                end
            end
            newStudyPath = bst_fileparts(file_fullpath(sNewStudy.FileName));
            % Save channel definition
            ChannelMat = in_bst_channel(sInputs(iInput).ChannelFile);
            [~, iChannelStudy] = bst_get('ChannelForStudy', iNewStudy);
            db_set_channel(iChannelStudy, ChannelMat, 0, 0);
            % Link to raw file
            OutputFile = bst_process('GetNewFilename', bst_fileparts(sNewStudy.FileName), 'data_0raw_sync');
            % Raw file
            [~, rawBaseOut, rawBaseExt] = bst_fileparts(newStudyPath);
            rawBaseOut = strrep([rawBaseOut rawBaseExt], '@raw', '');
            RawFileOut = bst_fullfile(newStudyPath, [rawBaseOut '.bst']);
            % Load original link to raw data
            sDataRawSync = in_bst_data(sInputs(iInput).FileName, 'F');
            sFileIn = sDataRawSync.F;
            % Set new time and events
            sFileIn.events = sNewTiming{iInput}.Events;
            sFileIn.header.nsamples = length( sNewTiming{iInput}.Time);
            sFileIn.prop.times      = [ sNewTiming{iInput}.Time(1), sNewTiming{iInput}.Time(end)];
            sFileOut = out_fopen(RawFileOut, 'BST-BIN', sFileIn, ChannelMat);
            % Set Output sFile structure
            sDataSync        = in_bst(sInputs(iInput).FileName, [], 1, 1, 'no');
            sOutMat          = rmfield(sDataSync, 'F');
            sOutMat.format   = 'BST-BIN';
            sOutMat.DataType = 'raw';
            sOutMat.F        = sFileOut;
            sOutMat.Comment  = [sDataSync.Comment ' | Synchronized'];
            % History: List of sync files
            sOutMat = bst_history('add', sOutMat, 'sync', ['List of synchronized files (event = "', syncEventName , '"):']);
            for ix = 1:nInputs
                sOutMat = bst_history('add', sOutMat, 'sync', [' - ' sInputs(ix).FileName]);
            end
            % Update raw data
            index = panel_time('GetTimeIndices', new_times{iInput}, [new_start, new_end]);
            sDataSync.F      = sDataSync.F(:,index);
            % Save new link to raw .mat file
            bst_save(OutputFile, sOutMat, 'v6');
            % Write block
            out_fwrite(sFileOut, ChannelMat, 1, [], [], sDataSync.F);
            % Register in BST database
            db_add_data(iNewStudy, OutputFile, sOutMat);
        end
        OutputFiles{iInput} = OutputFile;
        bst_progress('inc', 1);
    end
    bst_progress('stop');
end

