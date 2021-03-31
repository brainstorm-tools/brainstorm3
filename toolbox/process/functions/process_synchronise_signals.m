function varargout = process_synchronise_signals(varargin)
% process_synchronise_signals: Synchronise two signal based on common event

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
    sProcess.Comment     = 'Synchronyse files A and B';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Synchronize';
    sProcess.Index       = 681;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;
    
    %Description of options
    sProcess.options.inputs.Comment = ['For synchronization, please choose an<BR>event type which is available in both datasets.<BR><BR>'];
    sProcess.options.inputs.Type    = 'label';
    
    % Source Event name for synchronization (data set A)
    sProcess.options.src.Comment  = 'Sync event name in set A: ';
    sProcess.options.src.Type     = 'text';
    sProcess.options.src.Value    = '5';
    % Destination Event name for synchronization (data set B)
    sProcess.options.dest.Comment = 'Sync event name in set B: ';
    sProcess.options.dest.Type    = 'text';
    sProcess.options.dest.Value   = 'E5';       
end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputsA, sInputsB)
    OutputFiles = {};
    
    
    % === Sync event management === %
    SyncEventNameA = sProcess.options.src.Value;
    SyncEventNameB = sProcess.options.dest.Value;
    
    
    % Load recordings
    if strcmp(sInputsA.FileType, 'data')     % Imported data structure
        sDataA = in_bst_data(sInputsA.FileName);
    elseif strcmp(sInputsA.FileType, 'raw')  % Continuous data file       
        sDataA = in_bst(sInputsA.FileName, [], 1, 1, 'no');
    end
    
    if strcmp(sInputsB.FileType, 'data')     % Imported data structure
        sDataB = in_bst_data(sInputsB.FileName);
    elseif strcmp(sInputs.FileType, 'raw')  % Continuous data file       
        sDataB = in_bst(sInputsB.FileName, [], 1, 1, 'no');
    end
    
    
    
    
    % set sampling rate
    fs_A = 1/(sDataA.Time(2) -  sDataA.Time(1)) ; % in Hz
    fs_B  = 1/(sDataB.Time(2) -  sDataB.Time(1)) ; % in Hz
        
    SyncA = sDataA.Events(strcmp({sDataA.Events.label}, SyncEventNameA));
    SyncB = sDataB.Events(strcmp({sDataB.Events.label}, SyncEventNameB));

    if ~length(SyncA.times)== length(SyncB.times)
          bst_report('Error', sProcess, sInputsA, 'Cannot process inputs with a different number of synchronization triggers.');
    end
    
    % Check if the time shifting is unique
    shifting = SyncB.times - SyncA.times;
    
    offsetVar=mean(shifting);
    offsetStd=std(shifting);
    
%     figure; ax1=subplot(1,2,1);
%     hold on; plot(SyncA.times,SyncB.times); plot(SyncA.times,SyncA.times)
%     ax2=subplot(1,2,2);
%     hold on; plot(SyncA.times,SyncB.times-offsetVar); plot(SyncA.times,SyncA.times)
%     linkaxes([ax1,ax2],'x');linkaxes([ax1,ax2],'y');
    
    % How many sample should we shift B to be aligned with A
    offsetSample = round(offsetVar*fs_B);

    disp(['The variance of the sample offset is ' num2str(offsetVar) 's (std: ' num2str(offsetStd*1000) 'ms)']);
    
    % First we align the starting point
    if offsetSample > 0
    
        signal_B_aligned = sDataB.F(:,offsetSample:end);
        time_B_aligned =  0:1/fs_B:((size(signal_B_aligned,2)-1)/fs_B);
        
        signal_A_aligned = sDataA.F;
        time_A_aligned   = sDataA.Time;
    else
        
        signal_A_aligned = sDataA.F(:,offsetSample:end);
        time_A_aligned =  0:1/fs_A:((size(signal_A_aligned,2)-1)/fs_A);
    
        signal_B_aligned = sDataB.F;
        time_B_aligned   = sDataB.Time;
    end    
        
    % We stop each signal at the same point
    
    if time_B_aligned(end) > time_A_aligned(end)  % A stoped before B
        
        N_sample= find(time_B_aligned == time_A_aligned(end));
        time_B_aligned=time_B_aligned(1:N_sample);
        signal_B_aligned=signal_B_aligned(:,1:N_sample);
        
    elseif length(time_A_aligned) > length(time_B_aligned)
        
        N_sample= find(time_A_aligned == time_B_aligned(end));
        time_A_aligned=time_A_aligned(1:N_sample);
        signal_A_aligned=signal_A_aligned(:,1:N_sample);
    end % Note if length(time_A_aligned) == length(time_B_aligned), we don't do anything
    
    
    sDataA_aligned = sDataA;
    sDataA_aligned.Comment = [sDataA.Comment ' | Synchronized '];
    sDataA_aligned.Time = time_A_aligned;
    sDataA_aligned.F = signal_A_aligned;
    
    sDataB_aligned = sDataB;
    sDataB_aligned.Comment = [sDataB.Comment ' | Synchronized '];
    sDataB_aligned.Time = time_B_aligned;
    sDataB_aligned.F = signal_B_aligned;
    
    for i_event = 1:length(sDataB.Events)
        sDataB_aligned.Events(i_event).times = sDataB_aligned.Events(i_event).times - offsetVar; 
    end 
    sDataB_aligned.Events  = [ sDataB_aligned.Events sDataA_aligned.Events];
    
        
    sStudy = bst_get('Study', sInputsA.iStudy);
    OutputFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), 'data_sync');
    sDataA_aligned.FileName = file_short(OutputFile);
    bst_save(OutputFile, sDataA_aligned, 'v7');
    % Register in database
    db_add_data(sInputsA.iStudy, OutputFile, sDataA_aligned);
    OutputFiles{1} = OutputFile;
    
    sStudy = bst_get('Study', sInputsB.iStudy);
    OutputFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), 'data_sync');
    sDataB_aligned.FileName = file_short(OutputFile);
    bst_save(OutputFile, sDataB_aligned, 'v7');
    % Register in database
    db_add_data(sInputsB.iStudy, OutputFile, sDataB_aligned);
    OutputFiles{2} = OutputFile;
    
end    