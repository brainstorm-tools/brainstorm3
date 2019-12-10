function varargout = process_convert_raw_to_lfp( varargin )
% PROCESS_CONVERT_RAW_TO_LFP: Convert the raw signals after spike sorting
% to LFP signals.
% The user has the option to perform Bayesian Spike Removal, a method
% described in: https://www.ncbi.nlm.nih.gov/pubmed/21068271

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
% Authors: Konstantinos Nasiotis 2018

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Convert Raw to LFP';
    sProcess.Category    = 'custom';
    sProcess.SubGroup    = 'Electrophysiology';
    sProcess.Index       = 1203;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/e-phys/RawToLFP';
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
    
    sProcess.options.filterbounds.Comment = 'LFP filtering limits';
    sProcess.options.filterbounds.Type    = 'range';
    sProcess.options.filterbounds.Value   = {[0.5, 150],'Hz',1};
    
    % Definition of the options
    % === Freq list
    sProcess.options.freqlist.Comment = 'Notch filter Frequencies (Hz):';
    sProcess.options.freqlist.Type    = 'value';
    sProcess.options.freqlist.Value   = {[], 'list', 2};
    sProcess.options.freqlistHelp.Comment = '<I><FONT color="#777777">Frequencies for notch filter (leave empty for no selection)</FONT></I>';
    sProcess.options.freqlistHelp.Type    = 'label';
    
    sProcess.options.paral.Comment     = 'Parallel processing';
    sProcess.options.paral.Type        = 'checkbox';
    sProcess.options.paral.Value       = 1;
    
    sProcess.options.binsizeHelp.Comment = '<I><FONT color="#777777">The memory value below will be used in case the channels were not separated</FONT></I>';
    sProcess.options.binsizeHelp.Type    = 'label';
    
    sProcess.options.binsize.Comment = 'Memory to use for demultiplexing';
    sProcess.options.binsize.Type    = 'value';
    sProcess.options.binsize.Value   = {1, 'GB', 1}; % This is used in case the electrodes are not separated yet (no spike sorting done), ot the temp folder was emptied 
    
end



%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs, method) %#ok<DEFNU>
    OutputFiles = {};
    
    for iInput = 1:length(sInputs)
        sInput = sInputs(iInput);
        %% Parameters
        filterBounds = sProcess.options.filterbounds.Value{1}; % Filtering bounds for the LFP
        notchFilterFreqs = sProcess.options.freqlist.Value{1}; % Notch Filter frequencies for the LFP
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
            if exist(DeriveLFPDir, 'dir')
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
                'This method is based on a FFT-based low-pass filter, followed by a spline interpolation.' 10 ...
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
                poolobj = [];
            end
        else
            poolobj = [];
        end

        %% Initialize

        % Prepare output file
        ProtocolInfo = bst_get('ProtocolInfo');
        newCondition = [sInput.Condition, '_LFP'];
        sMat = in_bst(sInput.FileName, [], 0);
        Fs = 1 / diff(sMat.Time(1:2)); % This is the original sampling rate

        if mod(Fs,NewFreq) ~= 0
            % This should never be an issue. Never heard of an acquisition
            % system that doesn't record in multiples of 1kHz.
            warning(['The downsampling might not be accurate. This process downsamples from ' num2str(Fs) ' to ' num2str(NewFreq) ' Hz'])
        end

        % Get new condition name
        newStudyPath = file_unique(bst_fullfile(ProtocolInfo.STUDIES, sInput.SubjectName, newCondition));
        % Output file name derives from the condition name
        [tmp, rawBaseOut, rawBaseExt] = bst_fileparts(newStudyPath);
        rawBaseOut = strrep([rawBaseOut rawBaseExt], '@raw', '');
        % Full output filename
        RawFileOut = bst_fullfile(newStudyPath, [rawBaseOut '.bst']); % ***
        RawFileFormat = 'BST-BIN'; % ***
        ChannelMat = in_bst_channel(sInput.ChannelFile); % ***
        nChannels = length(ChannelMat.Channel);
        % Get input study (to copy the creation date)
        sInputStudy = bst_get('AnyFile', sInput.FileName);

        sStudy = bst_get('ChannelFile', sInput.ChannelFile);
        [tmp, iSubject] = bst_get('Subject', sStudy.BrainStormSubject, 1);

        % Get new condition name
        [tmp, ConditionName] = bst_fileparts(newStudyPath, 1);
        % Create output condition
        iOutputStudy = db_add_condition(sInput.SubjectName, ConditionName, [], sInputStudy.DateOfStudy);

        ChannelMatOut = ChannelMat;
        sFileTemplate = sMat.F;

        %% Get the transformed channelnames that were used on the signal data naming. This is used in the derive lfp function in order to find the spike events label
        % New channelNames - Without any special characters.
        cleanChannelNames = str_remove_spec_chars({ChannelMat.Channel.Name});

        %% Update fields before initializing the header on the binary file
        sFileTemplate.prop.sfreq = NewFreq;
        sFileTemplate.header.sfreq = NewFreq;
        sFileTemplate.header.nsamples = round((sFileTemplate.prop.times(2) - sFileTemplate.prop.times(1)) .* NewFreq) + 1;

        % Update file
        sFileTemplate.CommentTag     = sprintf('resample(%dHz)', round(NewFreq));
        sFileTemplate.HistoryComment = sprintf('Filter [%0.1f-%0.1f]Hz - Resample from %0.2f Hz to %0.2f Hz (%s)', filterBounds(1), filterBounds(2), Fs, NewFreq, method);
        sFileTemplate.despikeLFP     = sProcess.options.despikeLFP.Value;

        % Convert events to new sampling rate
        newTimeVector = panel_time('GetRawTimeVector', sFileTemplate);
        sFileTemplate.events = panel_record('ChangeTimeVector', sFileTemplate.events, Fs, newTimeVector);

        %% Create an empty Brainstorm-binary file and assign the correct samples-times
        % The sFileOut is what will be the final 
        [sFileOut, errMsg] = out_fopen(RawFileOut, RawFileFormat, sFileTemplate, ChannelMat);


        %% Check if the files are separated per channel. If not do it now.
        % These files will be converted to LFP right after
        sFiles_temp_mat = in_spikesorting_rawelectrodes(sInput, sProcess.options.binsize.Value{1}(1) * 1e9, sProcess.options.paral.Value);

        %% Filter and derive LFP
        LFP = zeros(length(sFiles_temp_mat), length(downsample(sMat.Time,round(Fs/NewFreq)))); % This shouldn't create a memory problem
        bst_progress('start', 'Spike-sorting', 'Converting RAW signals to LFP...', 0, (sProcess.options.paral.Value == 0) * nChannels);

        if sProcess.options.despikeLFP.Value
            if sProcess.options.paral.Value
                parfor iChannel = 1:nChannels
                    LFP(iChannel,:) = BayesianSpikeRemoval(sFiles_temp_mat{iChannel}, filterBounds, sMat.F, ChannelMat, cleanChannelNames, notchFilterFreqs);
                end
            else
                for iChannel = 1:nChannels
                    LFP(iChannel,:) = BayesianSpikeRemoval(sFiles_temp_mat{iChannel}, filterBounds, sMat.F, ChannelMat, cleanChannelNames, notchFilterFreqs);
                    bst_progress('inc', 1);
                end
            end
        else
            if sProcess.options.paral.Value
                parfor iChannel = 1:nChannels
                    LFP(iChannel,:) = filter_and_downsample(sFiles_temp_mat{iChannel}, Fs, filterBounds, notchFilterFreqs);
                end
            else
                for iChannel = 1:nChannels
                    LFP(iChannel,:) = filter_and_downsample(sFiles_temp_mat{iChannel}, Fs, filterBounds, notchFilterFreqs);
                    bst_progress('inc', 1);
                end
            end
        end
        
        % WRITE OUT
        sFileOut = out_fwrite(sFileOut, ChannelMatOut, [], [], [], LFP);

        % Import the RAW file in the database viewer and open it immediately
        RawFile = import_raw({sFileOut.filename}, 'BST-BIN', iSubject);
        RawFile = RawFile{1};
        
        % Modify it slightly since this is an LFP raw file
        [sStudy, iStudy] = bst_get('DataFile', RawFile);
        RawMat = load(RawFile);
        RawMat.Comment = 'Link to LFP file';
        RawNewFile = strrep(RawFile, 'data_0raw', 'data_0lfp');
        bst_save(RawNewFile, RawMat, 'v6');
        OutputFiles{end + 1} = RawNewFile;
        delete(RawFile);
        db_reload_studies(iStudy);
    end
end


function data = filter_and_downsample(inputFilename, Fs, filterBounds, notchFilterFreqs)
    sMat = load(inputFilename); % Make sure that a variable named data is loaded here. This file is saved as an output from the separator 
    
    if ~isempty(notchFilterFreqs)
        % Apply notch filter
        data = process_notch('Compute', sMat.data, sMat.sr, notchFilterFreqs)';
    else
        data = sMat.data';
    end
    
    % Aplly final filter
    data = bst_bandpass_hfilter(data, Fs, filterBounds(1), filterBounds(2), 0, 0);
    data = downsample(data, round(Fs/1000));  % The file now has a different sampling rate (fs/30) = 1000Hz.
end


%% BAYESIAN DESPIKING
function data_derived = BayesianSpikeRemoval(inputFilename, filterBounds, sFile, ChannelMat, cleanChannelNames, notchFilterFreqs)

    sMat = load(inputFilename); % Make sure that a variable named data is loaded here. This file is saved as an output from the separator 
    
    %% Instead of just filtering and then downsampling, DeriveLFP is used, as in:
    % https://www.ncbi.nlm.nih.gov/pubmed/21068271
    
    if ~isempty(notchFilterFreqs)
        % Apply notch filter
        data_deligned = process_notch('Compute', sMat.data, sMat.sr, notchFilterFreqs);
    else
        data_deligned = sMat.data;
    end
    
    Fs = sMat.sr;
    % Assume that a spike lasts 3ms
    nSegment = sMat.sr * 0.003;
    Bs = eye(nSegment); % 60x60
    opts.displaylevel = 0; % 0 gets rid of all the outputs
                           % 2 shows the optimization steps

    %% Get the channel Index of the file that is imported
    [tmp, ChannelName] = fileparts(inputFilename);
    ChannelName = strrep(ChannelName, 'raw_elec_', '');
    % I need to find the transformed channelname index that is used at the filename.
    iChannel = find(ismember(cleanChannelNames, ChannelName));
    
    
    % Get the index of the event that show this electrode's spikes
    allEventLabels = {sFile.events.label};
    spike_event_prefix = process_spikesorting_supervised('GetSpikesEventPrefix');
    % First check if there is only one neuron on the channel
    iEventforElectrode = find(ismember(allEventLabels, [spike_event_prefix ' ' ChannelMat.Channel(iChannel).Name])); % Find the index of the spike-events that correspond to that electrode (Exact string match)
    %Then check if there are multiple
    if isempty(iEventforElectrode)
        iEventforElectrode = find(ismember(allEventLabels, [spike_event_prefix ' ' ChannelMat.Channel(iChannel).Name ' |1|']));% Find the index of the spike-events that correspond to that electrode (Exact string match)
        if ~isempty(iEventforElectrode)
            iEventforElectrode = find(not(cellfun('isempty', strfind(allEventLabels, [spike_event_prefix ' ' ChannelMat.Channel(iChannel).Name ' |']))));
        end
    end
    
    
    % If there are no neurons picked up from that electrode, continue
    % Apply despiking around the spiking times
    if ~isempty(iEventforElectrode) % If there are spikes on that electrode
        spkSamples = ([sFile.events(iEventforElectrode).times] .* sFile.prop.sfreq); % All spikes, from all neurons on that electrode
        
        % We'd like to assume that a spike lasts
        % from-10 samples to +19 samples (3 ms) for 10000 Hz sampling rate compared to its peak
        % Since spktimes are the time of the peak of each spike, we subtract 15
        % from spktimes to obtain the start times of the spikes
  
        if mod(length(data_deligned),2)~=0
            
            data_deligned_temp = [data_deligned;0];
            g = fitLFPpowerSpectrum(data_deligned_temp,filterBounds(1),filterBounds(2),sFile.prop.sfreq);
            S = zeros(length(data_deligned_temp),1);
            iSpk = round(spkSamples - nSegment/2);
            iSpk = iSpk(iSpk > 0); % Only keep positive indices
            S(iSpk) = 1; % This assumes the spike starts at 1/2 before the trough of the spike
            data_derived = despikeLFP(data_deligned_temp,S,Bs,g,opts);
            data_derived = data_derived.z';
            data_derived = bst_bandpass_hfilter(data_derived, Fs, filterBounds(1), filterBounds(2), 0, 0);

            
        else
            g = fitLFPpowerSpectrum(data_deligned,filterBounds(1),filterBounds(2),sFile.prop.sfreq);
            S = zeros(length(data_deligned),1);
            iSpk = round(spkSamples - nSegment/2);
            iSpk = iSpk(iSpk > 0); % Only keep positive indices
            S(iSpk) = 1; % This assumes the spike starts at 1/2 before the trough of the spike

            data_derived = despikeLFP(data_deligned,S,Bs,g,opts);
            data_derived = data_derived.z';
            data_derived = bst_bandpass_hfilter(data_derived, Fs, filterBounds(1), filterBounds(2), 0, 0);

            
        end
    else
        data_derived = data_deligned';
        data_derived = bst_bandpass_hfilter(data_derived, Fs, filterBounds(1), filterBounds(2), 0, 0);
    end
    
    data_derived = downsample(data_derived, sMat.sr/1000);  % The file now has a different sampling rate (fs/30) = 1000Hz
    
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
    newDeriveLFPDir = bst_fullfile(DeriveLFPTmpDir);
    % Move directory to proper location
    file_move(newDeriveLFPDir, DeriveLFPDir);
    % Delete unnecessary files
    file_delete(DeriveLFPTmpDir, 1, 3);
    % Add to Matlab path
    addpath(genpath(DeriveLFPDir));
end

