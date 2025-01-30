function varargout = process_convert_raw_to_lfp( varargin )
% PROCESS_CONVERT_RAW_TO_LFP: Convert the raw signals after spike sorting
% to LFP signals.
% The user has the option to perform Bayesian Spike Removal, a method
% described in: https://www.ncbi.nlm.nih.gov/pubmed/21068271

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
% Authors: Konstantinos Nasiotis 2018
%          Francois Tadel, 2022-2023

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Convert Raw to LFP';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Electrophysiology';
    sProcess.Index       = 1205;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/e-phys/RawToLFP';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    sProcess.processDim  = 1;    % Process channel by channel

    % === Demultiplexing
    sProcess.options.demultlabel.Comment = '<B>Demultiplexing options:</B>';
    sProcess.options.demultlabel.Type    = 'label';
    % RAM limitation
    sProcess.options.binsize.Comment ='Maximum RAM to use: ';
    sProcess.options.binsize.Type    = 'value';
    sProcess.options.binsize.Value   = {2, 'GB', 1}; % This is used in case the electrodes are not separated yet (no spike sorting done), ot the temp folder was emptied
    % Use SSP/ICA
    sProcess.options.usessp.Comment = 'Apply the existing SSP/ICA projectors';
    sProcess.options.usessp.Type    = 'checkbox';
    sProcess.options.usessp.Value   = 1;
    % === LFP options
    sProcess.options.lfplabel.Comment = '<BR><B>LFP computation options:</B>';
    sProcess.options.lfplabel.Type    = 'label';
    % Downsample
    sProcess.options.LFP_fs.Comment = 'Sampling rate of the LFP signals: ';
    sProcess.options.LFP_fs.Type    = 'value';
    sProcess.options.LFP_fs.Value   = {1000, 'Hz', 0};
    % Notch filter
    sProcess.options.freqlist.Comment = 'Notch filter (Hz): ';
    sProcess.options.freqlist.Type    = 'value';
    sProcess.options.freqlist.Value   = {[], 'list', 2};
    % Band-pass filter
    sProcess.options.filterbounds.Comment = 'Band-pass filter: ';
    sProcess.options.filterbounds.Type    = 'range';
    sProcess.options.filterbounds.Value   = {[0.5, 150], 'Hz', 1};
    % Despike
    sProcess.options.despikeLFP.Comment = 'Despike LFP&nbsp;&nbsp;<I><FONT color="#777777">(Highly Recommended if analysis uses SFC or STA)</FONT></I>';
    sProcess.options.despikeLFP.Type    = 'checkbox';
    sProcess.options.despikeLFP.Value   = 1;
    % Parallel processing
    sProcess.options.parallel.Comment = 'Parallel processing';
    sProcess.options.parallel.Type    = 'checkbox';
    sProcess.options.parallel.Value   = 1;

end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput)
    OutputFiles = {};
    
    % ===== OPTIONS =====
    isDespike = sProcess.options.despikeLFP.Value;
    BandPass = sProcess.options.filterbounds.Value{1}; % Filtering bounds for the LFP
    NotchFreqs = sProcess.options.freqlist.Value{1}; % Notch Filter frequencies for the LFP
    LFP_fs = sProcess.options.LFP_fs.Value{1}; % Output frequency
    BinSize = sProcess.options.binsize.Value{1};
    isParallel = sProcess.options.parallel.Value;
    UseSsp = sProcess.options.usessp.Value;
    % Get protocol info
    ProtocolInfo = bst_get('ProtocolInfo');
    
    % ===== DEPENDENCIES =====
    % Not available in the compiled version
    if bst_iscompiled()
        error('This function is not available in the compiled version of Brainstorm.');
    end
    % Despike requirements
    if isDespike
        % Check for the Optimization toolbox
        if exist('fminunc', 'file') ~= 2
            bst_report('Error', sProcess, sInput, 'This process requires the Optimization Toolbox.');
            return;
        end
        % Install plugin
        [isInstalled, errMsg] = bst_plugin('Install', 'derivelfp');
        if ~isInstalled
            bst_report('Error', sProcess, [], errMsg);
            return;
        end
    end

    % ===== LOAD INPUTS =====
    % Load input file
    DataMat = in_bst(sInput.FileName, [], 0);
    sFileIn = DataMat.F;
    Fs = sFileIn.prop.sfreq;   % Original sampling rate
    % Check sampling rate
    if (Fs < LFP_fs)
        bst_report('Error', sProcess, sInput, 'The requested LFP sampling rate is higher than the RAW signal sampling rate. No need to use this function');
        return;
    elseif mod(round(Fs),round(LFP_fs)) ~= 0
        % This should never be an issue. Never heard of an acquisition system that doesn't record in multiples of 1kHz.
        bst_report('Warning', sProcess, sInput, ['The downsampling might not be accurate. This process downsamples from ' num2str(Fs) ' to ' num2str(LFP_fs) ' Hz']);
    end
    % Create temporary folder
    TmpDir = bst_get('BrainstormTmpDir', 0, 'raw2lfp');
    % Demultiplex channels
    demultiplexDir = bst_fullfile(TmpDir, 'Unsupervised_Spike_Sorting', ProtocolInfo.Comment, sInput.FileName);
    ElecFiles = out_demultiplex(sInput.FileName, sInput.ChannelFile, demultiplexDir, UseSsp, BinSize * 1e9, isParallel);
    % Load channel file
    ChannelMat = in_bst_channel(sInput.ChannelFile);
    nChannels = length(ChannelMat.Channel);

    % ===== OUTPUT FILE =====
    % Get input study
    sStudyInput = bst_get('AnyFile', sInput.FileName);
    % New study path
    newStudyPath = file_unique(bst_fullfile(bst_fileparts(bst_fileparts(file_fullpath(sStudyInput.FileName))), [sInput.Condition, '_LFP']));
    % New folder name
    [tmp, newCondition] = bst_fileparts(newStudyPath);
    % Create output folder
    iOutputStudy = db_add_condition(sInput.SubjectName, newCondition, [], sStudyInput.DateOfStudy);
    if isempty(iOutputStudy)
        bst_report('Error', sProcess, sInput, ['Output folder could not be created:' 10 newPath]);
        return;
    end
    sOutputStudy = bst_get('Study', iOutputStudy);

    % Get new condition name
    newStudyPath = bst_fileparts(file_fullpath(sOutputStudy.FileName));
    % Full output filename
    RawFileOut = bst_fullfile(newStudyPath, [strrep(newCondition, '@raw', '') '.bst']); % ***
    RawFileFormat = 'BST-BIN';

    % Number of time points in output file
    newTimeVector = process_resample('Compute', DataMat.Time, linspace(0, length(DataMat.Time)/Fs, length(DataMat.Time)), LFP_fs);
    nTimeOut = length(newTimeVector);
    % Template structure for the creation of the output raw file
    sFileTemplate = sFileIn;
    sFileTemplate.prop.sfreq = LFP_fs;
    sFileTemplate.prop.times = [newTimeVector(1), newTimeVector(end)];
    sFileTemplate.header.sfreq = LFP_fs;
    sFileTemplate.header.nsamples = nTimeOut;
    % Convert events to new sampling rate
    sFileTemplate.events = panel_record('ChangeTimeVector', sFileTemplate.events, Fs, newTimeVector);
    % Update file comment
    sFileTemplate.CommentTag = sprintf('resample(%dHz)', round(LFP_fs));
    % History
    sFileTemplate = bst_history('add', sFileTemplate, 'raw2lfp', sprintf('Filter [%0.1f-%0.1f]Hz - Resample from %0.2f Hz to %0.2f Hz', BandPass(1), BandPass(2), Fs, LFP_fs));

    % ===== DERIVE LFP =====
    % Get channel names with no special characters
    cleanChannelNames = str_remove_spec_chars({ChannelMat.Channel.Name});
    % Inialize LFP matrix
    LFP = zeros(length(ElecFiles), nTimeOut); % This shouldn't create a memory problem
    % Process with or without the Parallel toolbox
    if isParallel
        bst_progress('start', 'Raw2LFP', 'Converting raw signals to LFP...');
        parfor iChannel = 1:nChannels
            LFP(iChannel,:) = ProcessChannel(ElecFiles{iChannel}, isDespike, NotchFreqs, BandPass, sFileIn, ChannelMat, cleanChannelNames, LFP_fs);
        end
    else
        bst_progress('start', 'Raw2LFP', 'Converting raw signals to LFP...', 0, nChannels);
        for iChannel = 1:nChannels
            LFP(iChannel,:) = ProcessChannel(ElecFiles{iChannel}, isDespike, NotchFreqs, BandPass, sFileIn, ChannelMat, cleanChannelNames, LFP_fs);
            bst_progress('inc', 1);
        end
    end

    % ===== SAVE OUTPUT FILE =====
    % Open RAW file for writing
    [sFileOut, errMsg] = out_fopen(RawFileOut, RawFileFormat, sFileTemplate, ChannelMat);
    if ~isempty(errMsg)
        bst_report('Error', sProcess, sInput, ['Output file could not be created:' 10 errMsg]);
        return;
    end
    % Save data to output raw file
    sFileOut = out_fwrite(sFileOut, ChannelMat, [], [], [], LFP);
    % Get subject index
    [tmp, iSubject] = bst_get('Subject', sStudyInput.BrainStormSubject, 1);
    % Import the output RAW file in the database
    OutputFiles = import_raw({sFileOut.filename}, 'BST-BIN', iSubject);

    % Delete the temporary files
    file_delete(TmpDir, 1, 1);
end


%% ===== PROCESS CHANNEL =====
function data = ProcessChannel(ElecFile, isDespike, NotchFreqs, BandPass, sFileIn, ChannelMat, cleanChannelNames, LFP_fs)
    % Load electrode file
    load(ElecFile, 'data', 'sr');
    % Convert column vector to row vector
    data = data';
    % Apply notch filter
    if ~isempty(NotchFreqs)
        data = process_notch('Compute', data, sr, NotchFreqs);
    end
    % Spike removal
    if isDespike
        % Get channel name from electrode file name
        [tmp, ChannelName] = fileparts(ElecFile);
        ChannelName = strrep(ChannelName, 'raw_elec_', '');
        data = BayesianSpikeRemoval(ChannelName, data', sr, sFileIn, ChannelMat, cleanChannelNames, BandPass);
        data = data';
    end
    % Band-pass filter
    data = bst_bandpass_hfilter(data, sr, BandPass(1), BandPass(2), 0, 0);
    % Resample
    data = process_resample('Compute', data, linspace(0, size(data,2)/sr, size(data,2)), LFP_fs);
end


%% ===== BAYESIAN SPIKE REMOVAL =====
% Reference: https://www.ncbi.nlm.nih.gov/pubmed/21068271
function data_derived = BayesianSpikeRemoval(ChannelName, data, Fs, sFile, ChannelMat, cleanChannelNames, BandPass)
    % Assume that a spike lasts 3ms
    nSegment = round(Fs * 0.003);
    Bs = eye(nSegment); % 60x60
    opts.displaylevel = 0; % 0 gets rid of all the outputs
                           % 2 shows the optimization steps

    % Find the transformed channelname index that is used at the filename.
    iChannel = find(ismember(cleanChannelNames, ChannelName));
    % Get the index of the event that show this electrode's spikes
    allEventLabels = {sFile.events.label};
    spike_event_prefix = panel_spikes('GetSpikesEventPrefix');
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
  
        if mod(length(data),2)~=0
            data_temp = [data; 0];
            g = fitLFPpowerSpectrum(data_temp,BandPass(1),BandPass(2),sFile.prop.sfreq);
            S = zeros(length(data_temp),1);
            iSpk = round(spkSamples - nSegment/2);
            iSpk = iSpk(iSpk > 0); % Only keep positive indices
            S(iSpk) = 1; % This assumes the spike starts at 1/2 before the trough of the spike
            data_derived = despikeLFP(data_temp,S,Bs,g,opts);
            data_derived = data_derived.z;
        else
            g = fitLFPpowerSpectrum(data,BandPass(1),BandPass(2),sFile.prop.sfreq);
            S = zeros(length(data),1);
            iSpk = round(spkSamples - nSegment/2);
            iSpk = iSpk(iSpk > 0); % Only keep positive indices
            S(iSpk) = 1; % This assumes the spike starts at 1/2 before the trough of the spike

            data_derived = despikeLFP(data,S,Bs,g,opts);
            data_derived = data_derived.z;
        end
    else
        data_derived = data;
    end
end
