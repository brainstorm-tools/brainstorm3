function varargout = process_convert_raw_to_lfp( varargin )
% PROCESS_CONVERT_RAW_TO_LFP: Convert the raw signals after spike sorting
% to LFP signals.
% The user has the option to perform Bayesian Spike Removal, a method
% described in: https://www.ncbi.nlm.nih.gov/pubmed/21068271

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Konstantinos Nasiotis 2018

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Convert Raw to LFP';
    sProcess.Category    = 'custom';
%     sProcess.FileTag     = 'resample';
    sProcess.SubGroup    = 'Electrophysiology';
    sProcess.Index       = 1203;
    sProcess.Description = 'https://www.ncbi.nlm.nih.gov/pubmed/21068271';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    sProcess.processDim  = 1;    % Process channel by channel

    sProcess.options.despikeLFP.Comment = 'Despike LFP <I><FONT color="#777777"> Highly Recommended if analysis uses SFC or STA</FONT></I>';
    sProcess.options.despikeLFP.Type    = 'checkbox';
    sProcess.options.despikeLFP.Value   = 1;
  
    sProcess.options.paral.Comment     = 'Parallel processing';
    sProcess.options.paral.Type        = 'checkbox';
    sProcess.options.paral.Value       = 1;
    
    sProcess.options.binsizeHelp.Comment = '<I><FONT color="#777777">The memory value below will be used in case the channels were not separated</FONT></I>';
    sProcess.options.binsizeHelp.Type    = 'label';
    
    sProcess.options.binsize.Comment = 'Memory to use for demultiplexing';
    sProcess.options.binsize.Type    = 'value';
    sProcess.options.binsize.Value   = {10, 'GB', 1}; % This is used in case the electrodes are not separated yet (no spike sorting done), ot the temp folder was emptied 
    
end



%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function sInputs = Run(sProcess, sInputs, method) %#ok<DEFNU>
    
    for iInput = 1:length(sInputs)
        sInput = sInputs(iInput);
        %% Parameters
        filterBounds = [0.5, 300];   % Filtering bounds for the LFP
        % Output frequency
        NewFreq = 1000;


        % Get method name
        if (nargin < 3)
            method = [];
        end

        %% Check for dependencies
        % If DespikeLFP is selected, check if it is already installed
        if sProcess.options.despikeLFP.Value
            % Ensure we are including the DeriveLFP folder in the Matlab path
            DeriveLFPDir = bst_fullfile(bst_get('BrainstormUserDir'), 'DeriveLFP');
            if exist(DeriveLFPDir, 'file')
                addpath(genpath(DeriveLFPDir));
            end

            % Install DeriveLFP if missing
            if ~exist('despikeLFP.m', 'file')
                rmpath(genpath(DeriveLFPDir));
                isOk = java_dialog('confirm', ...
                    ['The DeriveLFP toolbox is not installed on your computer.' 10 10 ...
                         'Download and install the latest version?'], 'DeriveLFP');
                if ~isOk
                    bst_report('Error', sProcess, sInput, 'This process requires the DeriveLFP toolbox.');
                    return;
                end
                downloadAndInstallDeriveLFP();
            end
        end

        % Check for Signal Processing toolbox
        if ~bst_get('UseSigProcToolbox')
            bst_report('Warning', sProcess, [], [...
                'The Signal Processing Toolbox is not available. Using the EEGLAB method instead (results may be much less accurate).' 10 ...
                'This method is based on a fft-based low-pass filter, followed by a spline interpolation.' 10 ...
                'Make sure you remove the DC offset before resampling; EEGLAB function does not work well when the signals are not centered.']);
        end


        % Prepare parallel pool, if requested
        if sProcess.options.paral.Value
            try
                poolobj = gcp('nocreate');
                if isempty(poolobj)
                    parpool;
                end
            catch
                sProcess.options.paral.Value = 0;
            end
        else
            poolobj = [];
        end



        %% Initialize

        % Prepare output file
        ProtocolInfo = bst_get('ProtocolInfo');
        ProcessOptions = bst_get('ProcessOptions');
        newCondition = [sInput.Condition, '_LFP'];
    %     newCondition = ['@raw', sFileIn.condition, fileTag];
        [sMat, ~] = in_bst(sInput.FileName, [],0);

        Fs = 1/diff(sMat.Time(1:2)); % This is the original sampling rate


        if mod(Fs,NewFreq)~=0
            % This should never be an issue. Never heard of an acquisition
            % system that doesn't record in multiples of 1kHz.
            warning(['The downsampling might not be accurate. This process downsamples from ' num2str(Fs) ' to ' num2str(NewFreq) ' Hz'])
        end

        % Get new condition name
        newStudyPath = file_unique(bst_fullfile(ProtocolInfo.STUDIES, sInput.SubjectName, newCondition));
        % Output file name derives from the condition name
        [tmp, rawBaseOut] = bst_fileparts(newStudyPath);
        rawBaseOut = strrep(rawBaseOut, '@raw', '');
        % Full output filename
        RawFileOut = bst_fullfile(newStudyPath, [rawBaseOut '.bst']); % ***
        RawFileFormat = 'BST-BIN'; % ***
        ChannelMat = in_bst_channel(sInput.ChannelFile); % ***
        nChannels = length(ChannelMat.Channel);
        % Get input study (to copy the creation date)
        sInputStudy = bst_get('AnyFile', sInput.FileName);

        sStudy = bst_get('ChannelFile', sInput.ChannelFile);
        [~, iSubject] = bst_get('Subject', sStudy.BrainStormSubject, 1);

        % Get new condition name
        [tmp, ConditionName] = bst_fileparts(newStudyPath, 1);
        % Create output condition
        iOutputStudy = db_add_condition(sInput.SubjectName, ConditionName, [], sInputStudy.DateOfStudy);

        ChannelMatOut = ChannelMat;
        sFileTemplate = sMat.F;



        %% Get the transformed channelnames that were used on the signal data naming. This is used in the derive lfp function in order to find the spike events label
        % New channelNames - Without any special characters. Use this
        % transformation throughout the toolbox for temp files
        cleanChannelNames = cellfun(@(c)c(~ismember(c, ' .,?!-_@#$%^&*+*=()[]{}|/')), {ChannelMat.Channel.Name}, 'UniformOutput', 0)';



        %% Update fields before initializing the header on the binary file
        sFileTemplate.prop.samples = floor(sFileTemplate.prop.times * NewFreq);  % Check if FLOOR IS NEEDED HERE
        sFileTemplate.prop.sfreq = NewFreq;
        sFileTemplate.header.sfreq = NewFreq;
        sFileTemplate.header.nsamples = diff(sFileTemplate.prop.samples)+1;

        % Update file
        sFileTemplate.CommentTag     = sprintf('resample(%dHz)', round(NewFreq));
        sFileTemplate.HistoryComment = sprintf('Filter [%0.1f-%0.1f]Hz - Resample from %0.2f Hz to %0.2f Hz (%s)', filterBounds(1), filterBounds(2), Fs, NewFreq, method);
        sFileTemplate.despikeLFP     = sProcess.options.despikeLFP.Value;

        % Convert events to new sampling rate
        newTimeVector = linspace(sFileTemplate.prop.times(1),sFileTemplate.prop.times(2),sFileTemplate.prop.samples(2)+1);
        sFileTemplate.events = panel_record('ChangeTimeVector', sFileTemplate.events, Fs, newTimeVector);

        %% Create an empty Brainstorm-binary file and assign the correct samples-times
        % The sFileOut is what will be the final 
        [sFileOut, errMsg] = out_fopen(RawFileOut, RawFileFormat, sFileTemplate, ChannelMat);


        %% Check if the files are separated per channel. If not do it now.
        % These files will be converted to LFP right after
        sFiles_temp_mat = in_spikesorting_rawelectrodes(sInput,sProcess.options.binsize.Value{1}(1)*1024*1024*1024,sProcess.options.paral.Value);

        %% Filter and derive LFP
        LFP = zeros(length(sFiles_temp_mat), length(downsample(sMat.Time,round(Fs/NewFreq)))); % This shouldn't create a memory problem
        bst_progress('start', 'Spike-sorting', 'Converting RAW signals to LFP...', 0, (sProcess.options.paral.Value == 0) * nChannels);

        if sProcess.options.paral.Value
            if ~sProcess.options.despikeLFP.Value
                parfor iChannel = 1:nChannels
                    LFP(iChannel,:) = filter_and_downsample(sFiles_temp_mat{iChannel},Fs, filterBounds)
                    bst_progress('inc', 1);
                end
                % WRITE OUT
                sFileOut = out_fwrite(sFileOut, ChannelMatOut, [], [], [], LFP);
            else
                tic
                parfor iChannel = 1:nChannels
                    LFP(iChannel,:) = BayesianSpikeRemoval(sFiles_temp_mat{iChannel}, filterBounds, sMat.F,ChannelMat, cleanChannelNames);
                    bst_progress('inc', 1);
                end
                % WRITE OUT
                sFileOut = out_fwrite(sFileOut, ChannelMatOut, [], [], [], LFP);
                disp(['Total time for BayesianSpikeRemoval: ' num2str(toc)])
            end
        else
            if ~sProcess.options.despikeLFP.Value
                for iChannel = 1:nChannels
                    LFP(iChannel,:) = filter_and_downsample(sFiles_temp_mat{iChannel},Fs, filterBounds);
                    bst_progress('inc', 1);
                end
                % WRITE OUT
                sFileOut = out_fwrite(sFileOut, ChannelMatOut, [], [], [], LFP); 
            else
                for iChannel = 1:nChannels
                    LFP(iChannel,:) = BayesianSpikeRemoval(sFiles_temp_mat{iChannel}, filterBounds, sMat.F, ChannelMat, cleanChannelNames);
                    bst_progress('inc', 1);
                end
                % WRITE OUT
                sFileOut = out_fwrite(sFileOut, ChannelMatOut, [], [], [], LFP);
            end
        end

        % Import the RAW file in the database viewer and open it immediately
        OutputFiles = import_raw({sFileOut.filename}, 'BST-BIN', iSubject);




        %% THIS APPROACH BELOW IS WITHOUT SEPARATING THE ELECTRODES
        %  IT SEGMENTS LARGE FILES AND LOADS EVERYTHING STRAIGHT FROM THE
        %  BINARY FILE.

    %     %% START THE CONVERSION
    %     % Do it in segments based on the memory the user selected
    %     nBits_memory = sProcess.options.binsize.Value{1}*1024*1024*1024*8; % User input is in GB
    %     % Loop through file based on the memory requested    
    %     % Initialize sample bounds of the segments
    %     nSamples_segment = ceil(nBits_memory/64/length(ChannelMat.Channel));
    %     nSegments = ceil(sMat.F.prop.samples(2)/nSamples_segment);
    %     timeBounds = zeros(nSegments,2);
    %     for iSeg = 1:nSegments
    %         if iSeg == nSegments
    %             timeBounds(iSeg,:) = sMat.Time([(iSeg-1)*nSamples_segment+1, sMat.F.prop.samples(2)])
    %         else
    %             timeBounds(iSeg,:) = sMat.Time([(iSeg-1)*nSamples_segment+1, iSeg*nSamples_segment]);
    %         end
    %     end
    %     
    %     % Convert timeBounds to sample Bounds with the new sampling frequency
    %     SAMPLEBounds = floor((timeBounds*NewFreq));
    %     
    %     for iSeg = 1:nSegments-1
    %         if SAMPLEBounds(iSeg,2) == SAMPLEBounds(iSeg+1,1)
    %             SAMPLEBounds(iSeg+1,1) = SAMPLEBounds(iSeg+1,1)+1;
    %         end
    %     end



    % %     channelTypes = {ChannelMat.Channel.Type};
    % %     nSpikeChannels = strcmp(channelTypes,'EEG'); % Perform spike sorting only on the channels that are EEG (CONSIDER CHANGING THE ACQUISITION IMPORTERS TO iEEG)



    % % % % % %     iSeg = 1
    % % % % % %     tic
    % % % % % %     [a, ~] = in_bst(sInput.FileName, timeBounds(iSeg,:),1, 1, 'all', 0);
    % % % % % %     disp(['Time to import all files at once: ' num2str(toc)])
    % % % % % % 
    % % % % % %     tic
    % % % % % %     for iChannel = 1:length(ChannelMat.Channel)
    % % % % % %         [F, TimeVector] = in_fread(sMat.F, ChannelMat, 1, SAMPLEBounds, iChannel, []);
    % % % % % %     end
    % % % % % %     disp(['Time to import all filessequentially: ' num2str(toc)])
    % % % % % % 
    % % % % % %     tic
    % % % % % %     parfor iChannel = 1:length(ChannelMat.Channel)
    % % % % % %         [F, TimeVector] = in_fread(sMat.F, ChannelMat, 1, SAMPLEBounds, iChannel, []);
    % % % % % %     end
    % % % % % %     disp(['Time to import all files in parallel: ' num2str(toc)])


    % % %     filename = sInput.FileName;
    % % %     % Do it in segments so there are no memory issues
    % % %     if ~sProcess.options.despikeLFP.Value
    % % %         % If no parallel processing is used, do it in segments. CHECK HOW
    % % %         % TO DEAL WITH THE SAMPLES THAT STITCH THE SEGMENTS TOGETHER
    % % %         if ~sProcess.options.paral.Value
    % % %             for iSeg = 1:nSegments
    % % %                 disp(['iSeg: ' num2str(iSeg)])
    % % %                 [sMatSegment, ~] = in_bst(filename, timeBounds(iSeg,:),1, 1, 'all', 0); % The memory is skyrocketing for no apparent reason here...
    % % % 
    % % %                 % Filter and downsample
    % % %                 [output_signal, ~, ~] = bst_bandpass_hfilter(sMatSegment.F, Fs, filterBounds(1), filterBounds(2), 0, 0);
    % % %                 output_signal = downsample(output_signal',round(Fs/1000))';  % The file now has a different sampling rate (fs/30) = 1000Hz.
    % % % 
    % % %                 %% WRITE OUT
    % % %                 sFileOut = out_fwrite(sFileOut, ChannelMatOut, [], [SAMPLEBounds(iSeg,1) SAMPLEBounds(iSeg,2)], [], output_signal); %clear F
    % % %           %     sFileOut = out_fwrite(sFileOut, ChannelMatOut, iEpoch, SamplesBounds, iRow, sInput.A);
    % % % 
    % % %             end
    % % %         else
    % % %             % If doing things in parallel, load the entire electrode. This
    % % %             % takes the same time as the in_bst function, but doesn't
    % % %             % create any memory problems, and also avoids the "stitching problem"
    % % %             tic
    % % %             parfor iChannel = 1:length(ChannelMat.Channel)
    % % %                 [F, ~] = in_fread(sMat.F, ChannelMat, 1, [], iChannel, []);
    % % %                 %% WRITE OUT
    % % %                 out_fwrite(sFileOut, ChannelMatOut, 1, [0, length(F)-1], iElectrode, F); %clear F
    % % % %               sFile = out_fwrite(sFile, ChannelMat, iEpoch, SamplesBounds, iChannels, F);
    % % %             end
    % % %             toc
    % % %            
    % % %         end
    % % %             
    % % %     else
    % % %         for iSeg = 1:nSegments
    % % %             disp(['iSeg: ' num2str(iSeg)])
    % % %             [output_signal, ~] = BayesianSpikeRemoval(sMat.F, ChannelMat, SAMPLEBounds, iSeg);
    % % %             sFileOut = out_fwrite(sFileOut, ChannelMatOut, [], [SAMPLEBounds(iSeg,1) SAMPLEBounds(iSeg,2)], [], output_signal); %clear F
    % % %         end
    % % %     end
    % % %     
    % % %         
    % % %         
    % % %     % Import the RAW file in the database viewer and open it immediately
    % % %     OutputFiles = import_raw({sFileOut.filename}, 'BST-BIN', iSubject);
    end

end



function data = filter_and_downsample(inputFilename,Fs, filterBounds)
    load(inputFilename) % Make sure that a variable named data is loaded here. This file is saved as an output from the separator 
    [data, ~, ~] = bst_bandpass_hfilter(data', Fs, filterBounds(1), filterBounds(2), 0, 0);
    data = downsample(data',round(Fs/1000))';  % The file now has a different sampling rate (fs/30) = 1000Hz.
end







%% BAYESIAN DESPIKING
function data_derived = BayesianSpikeRemoval(inputFilename, filterBounds, sFile, ChannelMat, cleanChannelNames)

    load(inputFilename) % Make sure that a variable named data is loaded here. This file is saved as an output from the separator 
    
    %% Instead of just filtering and then downsampling, DeriveLFP is used, as in:
    % https://www.ncbi.nlm.nih.gov/pubmed/21068271
    
    % Remove line noise peaks at 60, 180Hz
    data_deligned = delineSignal(data, sr, [60,180]); % This function plots a figure!!!
    
    g = fitLFPpowerSpectrum(data_deligned,filterBounds(1),filterBounds(2),sFile.prop.sfreq);
%     load('C:/Users/McGill/Desktop/g.mat') % this loads a variable g
    
% % % % % % % % % % % % % % % % % % %     %Find a good value for g according to the method shown in the appendix,
% % % % % % % % % % % % % % % % % % %     %fitting to a function with a modest number of free parameters
% % % % % % % % % % % % % % % % % % %     %Usually this takes some fiddling with the parameters
% % % % % % % % % % % % % % % % % % %     g = fitLFPpowerSpectrum(data_deligned,.01,250,sFile.prop.sfreq);
    

    % Assume that a spike lasts 2.5ms
    % We'd like to assume that a spike lasts
    % from -25 samples to +50 samples (2.5 ms) compared to its peak % 
    % for 30000 Hz sampling rate
    % Since spktimes are the time of the peak of each spike, we subtract 15
    % from spktimes to obtain the start times of the spikes
    nSegment = sr * 0.0025;
    Bs = eye(nSegment); % 60x60
    opts.displaylevel = 0;

    S = zeros(length(data_deligned),1);
    
    
    
    %% Get the channel Index of the file that is imported
    [~,ChannelName,~] = fileparts(inputFilename);
    ChannelName = erase(ChannelName,'raw_elec_');
    % I need to find the transformed channelname index that is used at the filename.
    iChannel = find(ismember(cleanChannelNames, ChannelName));
    
    
    % Get the index of the event that show this electrode's spikes
    allEventLabels = {sFile.events.label};
    % First check if there is only one neuron on the channel
    iEventforElectrode = find(ismember(allEventLabels, ['Spikes Channel ' ChannelMat.Channel(iChannel).Name])); % Find the index of the spike-events that correspond to that electrode (Exact string match)
    %Then check if there are multiple
    if isempty(iEventforElectrode)
        iEventforElectrode = find(ismember(allEventLabels, ['Spikes Channel ' ChannelMat.Channel(iChannel).Name ' |1|']));% Find the index of the spike-events that correspond to that electrode (Exact string match)
        if ~isempty(iEventforElectrode)
            iEventforElectrode = find(contains(allEventLabels, ['Spikes Channel ' ChannelMat.Channel(iChannel).Name ' |']));
        end
    end
    
    
    % If there are no neurons picked up from that electrode, continue
    % Apply despiking around the spiking times
    if ~isempty(iEventforElectrode) % If there are spikes on that electrode
        spktimes = sFile.events(iEventforElectrode).samples;
        S(spktimes - round(nSegment/3)) = 1; % This assumes the spike starts at 1/3 before the trough of the spike

        data_derived = despikeLFP(data_deligned,S,Bs,g,opts);
        data_derived = data_derived.z';
    else
        data_derived = data_deligned';
    end
    
    data_derived = downsample(data_derived, sr/1000);  % The file now has a different sampling rate (fs/30) = 1000Hz
    
    
end





%% ===== DOWNLOAD AND INSTALL DeriveLFP =====
function downloadAndInstallDeriveLFP()
    DeriveLFPDir = bst_fullfile(bst_get('BrainstormUserDir'), 'DeriveLFP');
    DeriveLFPTmpDir = bst_fullfile(bst_get('BrainstormUserDir'), 'DeriveLFP_tmp');
    url = 'http://packlab.mcgill.ca/despikingtoolbox.zip';
    % If folders exists: delete
    if isdir(DeriveLFPDir)
        file_delete(DeriveLFPDir, 1, 3);
    end
    if isdir(DeriveLFPTmpDir)
        file_delete(DeriveLFPTmpDir, 1, 3);
    end
    % Create folder
	mkdir(DeriveLFPTmpDir);
    % Download file
    zipFile = bst_fullfile(DeriveLFPTmpDir, 'despikingtoolbox.zip');
    errMsg = gui_brainstorm('DownloadFile', url, zipFile, 'DeriveLFP download'); % This line downloads the file
    if ~isempty(errMsg)
        error(['Impossible to download DeriveLFP:' errMsg]);
    end
    % Unzip file
    bst_progress('start', 'DeriveLFP', 'Installing DeriveLFP...');
    unzip(zipFile, DeriveLFPTmpDir);
    % Get parent folder of the unzipped file
    diropen = dir(fullfile(DeriveLFPTmpDir, 'MATLAB*'));
%     idir = find([diropen.isdir] & ~cellfun(@(c)isequal(c(1),'.'), {diropen.name}), 1);
    newDeriveLFPDir = bst_fullfile(DeriveLFPTmpDir);
    % Move WaveClus directory to proper location
    movefile(newDeriveLFPDir, DeriveLFPDir);
    % Delete unnecessary files
    file_delete(DeriveLFPTmpDir, 1, 3);
    % Add WaveClus to Matlab path
    addpath(genpath(DeriveLFPDir));
end





