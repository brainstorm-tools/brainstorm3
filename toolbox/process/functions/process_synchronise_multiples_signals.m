function varargout = process_synchronise_multiples_signals(varargin)
% process_synchronise_multiples_signals: Synchronise two signal based on common event

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
% Authors: Edouard Delaire, 2021
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
    
    
    % === Sync event management === %
    SyncEventNameA = sProcess.options.src.Value;
    
    sData   = cell(1,length(sInputs)); 
    sDataRaw = cell(1,length(sInputs)); 
    sSync   = cell(1,length(sInputs)); 
    fs      = zeros(1, length(sInputs)); 
    
    is_raw = strcmp(sInputs(1).FileType, 'data');

    for i = 1:length(sInputs)
        if strcmp(sInputs(i).FileType, 'data')     % Imported data structure
            sData{i}    = in_bst_data(sInputs(i).FileName);
            sSync{i}    = sData{i}.Events(strcmp({sData{i}.Events.label}, SyncEventNameA));
            fs(i)       = 1/(sData{i}.Time(2) -  sData{i}.Time(1)) ; % in Hz
        elseif strcmp(sInputs(i).FileType, 'raw')  % Continuous data file 
            sData{i}     = in_bst(sInputs(i).FileName, [], 1, 1, 'no');
            sDataRaw{i}    = in_bst_data(sInputs(i).FileName, 'F');

            events      = sDataRaw{i}.F.events;
            sSync{i}    = events(strcmp({events.label}, SyncEventNameA));
            fs(i)       = sDataRaw{i}.F.prop.sfreq; % in Hz
        end
    end

    new_times = cell(1,length(sInputs)); 
    new_times{1} = sData{1}.Time;
    mean_shifting = zeros(1, length(sInputs));
    
    % compute shifiting between file i and first file  
    for iFile = 2:length(sInputs)
        if length(sSync{iFile}.times) == length(sSync{1}.times)
            shifting = sSync{iFile}.times -  sSync{1}.times;
            
            mean_shifting(iFile)=mean(shifting);
            offsetStd=std(shifting);
        
        else
            bst_report('Warning', sProcess, sInputs, 'Files doesnt have the same number of trigger. Using approximation');
            % Correlate the trigger signals; need to be at the same
            % frequency. Choose the frequency of the larger signal 
            
            tmp_fs      = max(fs(iFile), fs(1));
            tmp_time_a  = sData{iFile}.Time(1):1/tmp_fs:sData{iFile}.Time(end);
            tmp_time_b  = sData{1}.Time(1):1/tmp_fs:sData{1}.Time(end);

            blocA = zeros(1 , length(tmp_time_a)); 
            for i_event = 1:size(sSync{iFile}.times,2)
                i_intra_event = panel_time('GetTimeIndices', tmp_time_a,  sSync{iFile}.times(i_event) + [0 1]');
                blocA(1,i_intra_event) = 1;
            end
            
            blocB = zeros(1 , length(tmp_time_b)); 
            for i_event = 1:size(sSync{1}.times,2)
               i_intra_event = panel_time('GetTimeIndices', tmp_time_b,  sSync{1}.times(i_event) + [0 1]');
               blocB(1,i_intra_event) = 1;
            end
            
            [c,lags]        =xcorr(blocA,blocB);
            [c_max,colum]   =max(c);
            
            
            mean_shifting(iFile)=lags(colum) / tmp_fs;
            offsetStd = 0;
        end    
        disp(sprintf('Lag difference between %s and %s : %.2f ms (std: %.2f ms)',sInputs(1).Condition, sInputs(iFile).Condition,mean_shifting(iFile),offsetStd*1000 ));
        new_times{iFile} = sData{iFile}.Time - mean_shifting(iFile);
    end    
    
    % detect new start and end
    new_start   = max(cellfun(@(x)min(x), new_times));
    new_end     = min(cellfun(@(x)max(x), new_times));

    
    
    new_data =  sData; 
    new_data_raw = sDataRaw;

    pool_events = [];

    for iFile = 1:length(sInputs)
        
        index = panel_time('GetTimeIndices', new_times{iFile}, [new_start, new_end]);

        sDataTmp = sData{iFile};

        new_data{iFile}.Time = new_times{iFile}(index) - new_times{iFile}(index(1)) ;
        new_data{iFile}.F = sDataTmp.F(:,index);
        
        tmp_event = new_data{iFile}.Events;
        for i_event = 1:length(tmp_event)
            tmp_event(i_event).times = tmp_event(i_event).times - mean_shifting(iFile) - new_times{iFile}(index(1)) ;
            if isempty(pool_events)
                pool_events = tmp_event(i_event);
            elseif ~strcmp(tmp_event(i_event).label,SyncEventNameA)  || (strcmp(tmp_event(i_event).label,SyncEventNameA) && ~any(strcmp({pool_events.label},SyncEventNameA)))
                pool_events = [pool_events tmp_event(i_event)];
            end   
        end  
    end
    

    for iFile = 1:length(sInputs)
        
        new_data{iFile}.Comment = [sDataTmp.Comment ' | Synchronized '];

        if is_raw
            new_data_raw{1}.F.events = pool_events;
        else
            new_data{iFile}.Events = pool_events;
        end

        sStudy = bst_get('Study', sInputs(iFile).iStudy);
        OutputFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), 'data_sync2');
        new_data{iFile}.FileName = file_short(OutputFile);
        bst_save(OutputFile, new_data{iFile}, 'v7');
        % Register in database
        db_add_data(sInputs(iFile).iStudy, OutputFile, new_data{iFile});
        OutputFiles{iFile} = OutputFile;

    end

end    