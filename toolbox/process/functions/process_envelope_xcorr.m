function varargout = process_envelope_xcorr( varargin )
% PROCESS_ENVELOPE_XCORR: Computes the phase difference histogram between
% timeseries

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
% Authors: Konstantinos Nasiotis, 2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Hilbert envelope xcorr';
    sProcess.Category    = 'custom';
    sProcess.SubGroup    = {'Peyrache Lab', 'Ripples'};
    sProcess.Index       = 2225;
    sProcess.Description = 'https://www.jstatsoft.org/article/view/v031i10';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Options: Sensor types
    sProcess.options.sensortypesA.Comment = 'A: Sensor types, indices, names or Groups (empty=all): ';
    sProcess.options.sensortypesA.Type    = 'text';
    sProcess.options.sensortypesA.Value   = 'EEG';
    % Options: Sensor types
    sProcess.options.sensortypesB.Comment = 'B: Sensor types, indices, names or Groups (empty=all): ';
    sProcess.options.sensortypesB.Type    = 'text';
    sProcess.options.sensortypesB.Value   = 'EEG';
    % Band-pass filter
    sProcess.options.bandpass.Comment = 'Frequency band (0=ignore): ';
    sProcess.options.bandpass.Type    = 'range';
    sProcess.options.bandpass.Value   = {[200, 400], 'Hz', 1};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end

%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Initialize returned values
    OutputFiles = {};
    % Extract method name from the process name
    strProcess = strrep(strrep(func2str(sProcess.Function), 'process_', ''), 'data', '');
    
    % Add other options
    tfOPTIONS.Method = strProcess;
    if isfield(sProcess.options, 'sensortypesA')
        tfOPTIONS.SensorTypesA = sProcess.options.sensortypesA.Value;
    else
        tfOPTIONS.SensorTypesA = [];
    end
    % Add other options
    if isfield(sProcess.options, 'sensortypesB')
        tfOPTIONS.SensorTypesB = sProcess.options.sensortypesB.Value;
    else
        tfOPTIONS.SensorTypesB = [];
    end

    % === OUTPUT STUDY ===
    % Get output study
    [tmp, iStudy] = bst_process('GetOutputStudy', sProcess, sInputs);
    tfOPTIONS.iTargetStudy = iStudy;
    
    % Check how many event groups we're processing
    listComments = cellfun(@str_remove_parenth, {sInputs.Comment}, 'UniformOutput', 0);
    [uniqueComments,tmp,iData2List] = unique(listComments);
    nLists = length(uniqueComments);
    
    % Process each event group separately
    for iList = 1:nLists
        sCurrentInputs = sInputs(iData2List == iList);
    
        %% Get channel file
        sChannel    = bst_get('ChannelForStudy', iStudy);
        ChannelMat  = in_bst_channel(sChannel.FileName);
        dataMat_channelFlag = in_bst_data(sCurrentInputs(1).FileName, 'ChannelFlag');

        
        iSelectedChannelsA = select_channels(ChannelMat, dataMat_channelFlag.ChannelFlag, sProcess.options.sensortypesA.Value);
        nChannelsA         = length(iSelectedChannelsA); 
        if isempty(iSelectedChannelsA)
            bst_report('Error', sProcess, sCurrentInputs(1), 'No channels to process in group A. Make sure that the Names/Groups assigned are correct');
            return;
        end
        
        % Do the same for ChannelSelection B
        iSelectedChannelsB = select_channels(ChannelMat, dataMat_channelFlag.ChannelFlag, sProcess.options.sensortypesB.Value);
        nChannelsB         = length(iSelectedChannelsB); 
        if isempty(iSelectedChannelsB)
            bst_report('Error', sProcess, sCurrentInputs(1), 'No channels to process in group B. Make sure that the Names/Groups assigned are correct');
            return;
        end
        
        %% Create the label of the file on the database based on the selection
                
        labelsForDropDownMenu = cell(nChannelsA * nChannelsB, 1);
        
        for iChannelA = 1:nChannelsA
            for iChannelB = 1:nChannelsB
                suffixA = ['Ch: ' ChannelMat.Channel(iSelectedChannelsA(iChannelA)).Name];
                suffixB = [' - '  ChannelMat.Channel(iSelectedChannelsB(iChannelB)).Name];
                
                labelsForDropDownMenu{(iChannelA-1)*nChannelsB+ iChannelB} = [suffixA suffixB];
            end
        end
        
        
        %% Make a check that all trials have the same length
        nTrials = length(sCurrentInputs);
        
        allTimeLengths = zeros(nTrials,1);

        for iTrial = 1:nTrials
        	Time_temp = in_bst(sCurrentInputs(iTrial).FileName, 'Time');
            allTimeLengths(iTrial) = length(Time_temp);
        end
        
        if ~all(allTimeLengths == allTimeLengths(1))
        	bst_report('Error', sProcess, sCurrentInputs(1), 'Not all trials have the same time length');
        end
        
        
        Time = linspace(2*Time_temp(1), 2*Time_temp(end), 2*allTimeLengths(1)-1);
        
        %% Accumulate all trials - THIS SHOULDNT CREATE A MEMORY PROBLEM
        progressPos = bst_progress('set',0);
        bst_progress('text', 'Accumulating all trials...');
        
        ALL_TRIALS_files = struct();
        for iFile = 1:nTrials
            DataMat = in_bst(sCurrentInputs(iFile).FileName);
            ALL_TRIALS_files(iFile).F = DataMat.F;
            progressPos = bst_progress('set', iFile/nTrials*100);
        end

        %% Get the cross-correlation between the envelopes
        
        all_xcorrs = zeros(nTrials, length(labelsForDropDownMenu), 2*allTimeLengths(1)-1);
        all_stds   = zeros(length(labelsForDropDownMenu), 2*allTimeLengths(1)-1);

        progressPos = bst_progress('set',0);
        bst_progress('text', 'Computing Hilbert transform and cross-correlation...');
        
        ii = 0;
        for iChannelA = 1:nChannelsA
            for iChannelB = 1:nChannelsB
                ii = ii + 1;
                
                for iFile = 1:nTrials
                    %% Filter the data based on the user input
                    sFreq = round(1/diff(DataMat.Time(1:2)));
                    [filtered_F_A, FiltSpec, Messages] = process_bandpass('Compute', ALL_TRIALS_files(iFile).F(iSelectedChannelsA,:), sFreq, sProcess.options.bandpass.Value{1}(1), sProcess.options.bandpass.Value{1}(2));
                    [filtered_F_B, FiltSpec, Messages] = process_bandpass('Compute', ALL_TRIALS_files(iFile).F(iSelectedChannelsB,:), sFreq, sProcess.options.bandpass.Value{1}(1), sProcess.options.bandpass.Value{1}(2));

                    envelopeA = abs(hilbert(filtered_F_A));
                    envelopeB = abs(hilbert(filtered_F_B));

                    all_xcorrs(iFile, ii, :) = xcorr(filtered_F_A(iChannelA,:), filtered_F_B(iChannelB,:));
                end
                bst_progress('set', round(((iChannelA-1)*nChannelsB + iChannelB) / (nChannelsA*nChannelsB) * 100));
            end
        end
        
%         final_xcorr     = squeeze(mean(all_xcorrs));
        final_xcorr     = squeeze(median(all_xcorrs));
        
        if size(final_xcorr,2) == 1
            final_xcorr = final_xcorr';
        end
        
        disp('DECIDE WHAT TO COMPUTE HERE')
        
        final_std_xcorr = squeeze(std(all_xcorrs));
        
        if size(final_std_xcorr,2) == 1
            final_std_xcorr = final_std_xcorr';
        end
        
        
        %% Build the output file
        tfOPTIONS.ParentFiles = {sCurrentInputs.FileName};

        % Prepare output file structure
        FileMat.Value = final_xcorr;
        FileMat.Std   = final_std_xcorr;
        FileMat.Description = labelsForDropDownMenu;
        FileMat.Time = Time; 
        FileMat.DataType = 'recordings';
        FileMat.ChannelFlag  = ones(length(labelsForDropDownMenu),1);
        FileMat.nAvg         = 1;
        FileMat.Events       = [];
        FileMat.SurfaceFile  = [];
        FileMat.Atlas        = [];
        FileMat.DisplayUnits = [];
        FileMat.Comment = ['Envelope xCorr ' uniqueComments{iList}];
        
        % Add history field
        FileMat = bst_history('add', FileMat, 'compute', ...
            ['xCorr of envelope between signals']);

        % Get output study
        sTargetStudy = bst_get('Study', iStudy);
        % Output filename
        FileName = bst_process('GetNewFilename', bst_fileparts(sTargetStudy.FileName), 'matrix_envelope_xcorr');
        OutputFiles = {FileName};
        % Save output file and add to database
        bst_save(FileName, FileMat, 'v6');
        db_add_data(tfOPTIONS.iTargetStudy, FileName, FileMat);

    end
    % Display report to user
    bst_report('Info', sProcess, sInputs, 'Success');
    disp('BST> process_spiking_phase_locking: Success');
end


function iChannels = select_channels(ChannelMat, ChannelFlag, target)

   % Get channels to process
    iChannels = channel_find(ChannelMat.Channel, target);
    % Check for Group selection
    if ~iscell(target)
        if any(target == ',') || any(target == ';')
            % Split string based on the commas
            target = strtrim(str_split(target, ',;'));
        else
            target = {strtrim(target)};
        end
    end    
    
    %% Select which channels to compute the spiking phase on
    if isempty(iChannels)
        if ~all(cellfun(@isempty,{ChannelMat.Channel.Group})) % In case not all groups are empty
            allGroups = upper(unique({ChannelMat.Channel.Group}));
            % Process all the targets
            for i = 1:length(target)
                % Search by type: return all the channels from this Group
                if ismember(upper(strtrim(target{i})), allGroups)
                    iChan = [];
                    for iChannel = 1:length(ChannelMat.Channel)
                        % Get only good channels
                        if strcmp(upper(strtrim(target{i})), upper(strtrim(ChannelMat.Channel(iChannel).Group))) && ChannelFlag(iChannel) == 1
                            iChan = [iChan, iChannel];
                        end
                    end                             
                end
                % Comment
                if ~isempty(iChan)
                    iChannels = [iChannels, iChan];
                else
                    bst_error('No channels were selected. Make sure that the Group name is spelled properly. Also make sure that not ALL channels in that bank are marked as BAD')
                end
            end
            % Sort channels indices, and remove duplicates
            iChannels = unique(iChannels);
        else
            iChannels = [];
        end
    end
end
