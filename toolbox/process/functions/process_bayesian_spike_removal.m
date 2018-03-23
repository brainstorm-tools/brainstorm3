function varargout = process_bayesian_spike_removal( varargin )

% @=============================================================================

% This process removes the spurious correlations between spikes and local
% field potentials based on the method from Zanos et al. 2011

% Konstantinos Nasiotis
% @=============================================================================





% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Konstantinos Nasiotis, 2018

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Bayesian Spike Removal';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Electrophysiology';
    sProcess.Index       = 1201;
    sProcess.Description = 'https://www.ncbi.nlm.nih.gov/pubmed/21068271';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    sProcess.options.despikeLFP.Comment = 'Despike LFP <I><FONT color="#777777"> Highly Recommended if analysis uses SFC or STA</FONT></I>';
    sProcess.options.despikeLFP.Type    = 'checkbox';
    sProcess.options.despikeLFP.Value   = 1;
  
    sProcess.options.paral.Comment     = 'Parallel processing';
    sProcess.options.paral.Type        = 'checkbox';
    sProcess.options.paral.Value       = 1;
    
    
%     sProcess.options.binsize.Comment = 'This will create an LFP.ns2 file';
%     sProcess.options.binsize.Type    = 'value';
% %     sProcess.options.binsize.Value   = {10, 'million samples', 1};
    
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    
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
                bst_report('Error', sProcess, sInputs, 'This process requires the DeriveLFP toolbox.');
                return;
            end
            downloadAndInstallDeriveLFP();
        end
    end
    
    [~, iStudy, ~] = bst_process('GetOutputStudy', sProcess, sInputs);
    sTargetStudy = bst_get('Study', iStudy);
    protocol   = bst_get('ProtocolInfo');
    
    % Get channel file
    sChannel = bst_get('ChannelForStudy', iStudy);
    % Load channel file
    ChannelMat = in_bst_channel(sChannel.FileName);
    
    
    
    
    % Convert all the files that are imported
    for i = 1:length(sInputs)
        DataFile = file_fullpath(sInputs(i).FileName); % E:\brainstorm_db\Playground\data\Monkey\@rawf114a\data_0raw_f114a.mat
                                                                                         
        
        %%%%%%%%%%%%%%%%%%%%%%% THE PATH_TO_LOAD NEEDS TO BE CHANGED TO THE
        %%%%%%%%%%%%%%%%%%%%%%% TEMP FOLDER WHERE THE ELECTRODES ARE
        %%%%%%%%%%%%%%%%%%%%%%% SEPARATED AND STORED
        
        
        %% MAKE SURE THE ELECTRODES ARE DEMULTIPLEXED INTO DIFFERENT FILES
        %  CHECK HOW THIS SHOULD BE DONE IN CONJUCTION WITH THE SPIKE
        %  SORTERS
        
        % Add a condition here that checks if the files are separated per
        % electrode first
        
        
        
        path_to_load = bst_fullfile(bst_get('BrainstormTmpDir'), ...
                       'Unsupervised_Spike_Sorting', ...
                       protocol.Comment, ...
                       sInputs(i).FileName);
        
        
        electrodesAlreadySeparated = ~isempty(dir([path_to_load '\raw_elec*.mat']));
        if ~electrodesAlreadySeparated
            bst_report('Error', sProcess, sInputs, 'The electrodes have not been seperated per electrode first');
            error('The electrodes have not been seperated per electrode yet. Have you run spike-sorting already?') % This assumes that the temp folder has not emptied.
        end
        [pathname, filebase, ~] = bst_fileparts(file_fullpath(sInputs(i).FileName));
        
        
        
        %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        filebase = filebase(7:end); % |f114a| Just the filename without the data_0 prefix and the .mat extention. I will use this to create the events after
        
        DataMat = in_bst_data(DataFile);
        sFile = DataMat.F;
        
        sStudy = bst_get('ChannelFile', sChannel.FileName);
        [~, iSubject] = bst_get('Subject', sStudy.BrainStormSubject, 1);

        
        % Add the header to the file
        add_header(sFile, path_to_load, ChannelMat)
        
        % Add the LFP to the file
        path_to_load = strrep(path_to_load,'/','\'); % The problem was using '/' instead of '\'
        add_lfp(sFile, path_to_load, sProcess.options.despikeLFP.Value, sProcess.options.paral.Value)
        
        

        % Import the RAW file in the database viewer and open it immediately
        OutputFiles = import_raw({[path_to_load '\' sFile.comment(1:end-4) '_LFP.ns2']}, 'EEG-RIPPLE', iSubject);

        empty = convert_downsampled_events(sFile, pathname, filebase);
        
    end
end







function add_header(sFile, path_to_load, ChannelMat)
    % Copy the header from the initial file and then make changes on it
    % where needed.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % THIS ONLY WORKS FOR RIPPLE - BLACKROCK
    % GENERALIZE
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    
    
    finitial = fopen(sFile.filename,'rb');
    initial_header_extended_data = fread(finitial,314 + 66 * sFile.header.ChannelCount + 9); % All the headers together from that file: header, extended header, data header.
    fclose(finitial);

    % Copy that header to the new LFP file and change the Labels of the
    % electrodes to "LFP ichannel"
    
    fid = fopen([path_to_load '/' sFile.comment(1:end-4) '_LFP.ns2'],'w'); %*.ns2:  Continuous LFP data sampled at 1 KHz
    fwrite(fid,initial_header_extended_data);
    
    fseek(fid, 14, 'bof');
    fwrite(fid,'1 ksamp/sec     ','uint8'); % Change the sampling rate on the header (16 LETTERS - don't remove the spaces).
    
    fseek(fid, 290, 'bof');
    fwrite(fid,1000,'uint32'); % Change the sampling rate on the header.
    
    fseek(fid, 314 + 66*(sFile.header.ChannelCount) + 5, 'bof');
    fwrite(fid, ceil(sFile.header.DataPoints/(sFile.header.SamplingFreq/1000)),'uint32'); % Change the number of samples to the about to be filtered signal's length
    
    for ielectrode = 1:sFile.header.ChannelCount
        if strfind(ChannelMat.Channel(ielectrode).Name,'raw')
            fseek(fid,314 + 4 + 66*(ielectrode-1),'bof');
            fwrite(fid,'LFP');
        end
    end
    fclose(fid);
end
   



function add_lfp(sFile, path_to_load, shouldDoDeriveLFP, parallel_processing)

    LFP = zeros(sFile.header.ChannelCount, ceil(sFile.header.DataPoints/(sFile.header.SamplingFreq/1000)),'int16'); %.ns2 is with int16
    
% % % % % %     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % % % %     % Compute g outside of the loop. Save it in the temporary folder I think it should be computed only once per array???
% % % % % %     if shouldDoDeriveLFP
% % % % % %         load('C:\Users\McGill\Desktop\g.mat')
% % % % % %     end
% % % % % %     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
    
    if parallel_processing
        % These are small files, it can be done in parallel.
        p = gcp('nocreate');
        if isempty(p)
            parpool;
        end
        parfor ielectrode = 1:sFile.header.ChannelCount
            if ~shouldDoDeriveLFP
                data_filtered = filter_and_downsample_files(sFile, path_to_load, ielectrode)
                LFP(ielectrode,:) = data_filtered;
            else
                data_derived = BayesianSpikeRemoval(sFile, path_to_load, ielectrode);
                LFP(ielectrode,:) = data_derived;
            end
        end  
    else
        for ielectrode = 1:sFile.header.ChannelCount
            if ~shouldDoDeriveLFP
                data_filtered = filter_and_downsample_files(sFile, path_to_load, ielectrode);
                LFP(ielectrode,:) = data_filtered;
            else
                data_derived = BayesianSpikeRemoval(sFile, path_to_load, ielectrode);
                LFP(ielectrode,:) = data_derived;
            end
        end  
    end
    
    % Convert back to .ns2
    % *.ns2:  Continuous LFP data sampled at 1 KHz
    
    ffinal = fopen([path_to_load '/' sFile.comment(1:end-4) '_LFP.ns2'],'a');

    fwrite(ffinal, LFP,'int16');
    fclose(ffinal);
    
end




function data_filtered = filter_and_downsample_files(sFile, path_to_load, ielectrode)
    %%%% IF THERE ARE CHANNELS THAT ARE NOT ELECTRODES, THIS WILL FAIL
    %%%% CONSIDER COPYING THEM WITHOUT ANY PREPROCESSING

    disp(num2str(ielectrode))

    filename = [path_to_load '/raw_elec' num2str(sFile.header.ChannelID(ielectrode))];
    
    if exist([filename '.bin'], 'file') == 2
        fid = fopen([filename '.bin'], 'r');    
        data = fread(fid, 'int16')';
        fclose(fid);    
    elseif exist([filename '.mat'], 'file') == 2
        load([filename '.mat']);                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% % MAKE SURE THAT THE FILE HAS A VARIABLE NAMED DATA
    end

    [data_filtered, ~, ~] = bst_bandpass_hfilter(data, sFile.header.SamplingFreq, 0.5, 300, 0, 0);
%   [data_filtered, FiltSpec, Messages] = bst_bandpass_hfilter(data, sFile.header.SamplingFreq, HighPass, LowPass, isMirror, isRelax);

    data_filtered = downsample(data_filtered,sFile.header.SamplingFreq/1000);  % The file now has a different sampling rate (fs/30) = 1000Hz. This has to be stored somewhere
    data_filtered = data_filtered*10^6; % Convert V to uV (Brainstorm format should already have everything in V - CONFIRM)

end



function data_derived = BayesianSpikeRemoval(sFile, path_to_load, ielectrode)
    %%%% IF THERE ARE CHANNELS THAT ARE NOT ELECTRODES, THIS WILL FAIL
    %%%% CONSIDER COPYING THEM WITHOUT ANY PREPROCESSING
    
    
                                                load('C:\Users\McGill\Desktop\g.mat') % I temporarily put this in the function since the code was hanging when I used g as an input to the function
    
    
    
    disp(num2str(ielectrode))

    filename = [path_to_load '/raw_elec' num2str(sFile.header.ChannelID(ielectrode))];
    
    if exist([filename '.bin'], 'file') == 2
        fid = fopen([filename '.bin'], 'r');    
        data = fread(fid, 'int16')';
        fclose(fid);    
    elseif exist([filename '.mat'], 'file') == 2
        load([filename '.mat']);                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% % MAKE SURE THAT THE FILE HAS A VARIABLE NAMED DATA
    end
        
    

    %% Instead of filtering and then downsampling, DeriveLFP is used, as in:
    % https://www.ncbi.nlm.nih.gov/pubmed/21068271
    
    % Remove line noise peaks at 60, 180Hz
    data_deligned = delineSignal(data,sFile.prop.sfreq,[60,180]); % This idiotic function plots a figure!!!
    
    % g needs to be computed once, not inside the loop
    % Compute it before the parfor
% % % % % % % % % % % % % % % % % % %     %%
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
    nSegment = sFile.header.SamplingFreq * 0.0025;
    Bs = eye(nSegment); % 60x60
    opts.displaylevel = 0;

    S = zeros(length(data_deligned),1);
    
    allEventLabels = {sFile.events.label};
    iEventforElectrode = find(ismember(allEventLabels, ['Spikes Electrode ' num2str(ielectrode)])); % Find the index of the spike-events that correspond to that electrode (Exact string match)

    if ~isempty(iEventforElectrode) % If there are spikes on that electrode
        spktimes = sFile.events(iEventforElectrode).samples;
        S(spktimes - round(nSegment/3)) = 1; % This assumes the spike starts at 1/3 before the trough of the spike

        data_derived = despikeLFP(data_deligned,S,Bs,g,opts);
        data_derived = data_derived.z';
    else
        data_derived = data_deligned';
    end
    
    data_derived = downsample(data_derived,sFile.header.SamplingFreq/1000);  % The file now has a different sampling rate (fs/30) = 1000Hz. This has to be stored somewhere
    
    data_derived = data_derived*10^6; % Convert V to uV (Brainstorm format should already have everything in V - CONFIRM)
    
end








function empty = convert_downsampled_events(sFile, pathname, filebase)
    
    if exist([pathname '\events.mat'], 'file') == 2
        temp = load([pathname '\events.mat']);
        
        for iEvent = 1:length(temp.events)
            temp.events(iEvent).samples = round(temp.events(iEvent).samples *1000/sFile.header.SamplingFreq);
        end
        events = temp.events;
        save([pathname '_LFP\events_LFP.mat'],'events')
        clear events
        
    end
    
    if exist([pathname '\events_original_batch_sorted_' filebase '.mat'], 'file') == 2
        load([pathname '\events_original_batch_sorted_' filebase '.mat']);
        
        for iEvent = 1:length(events)
            events(iEvent).samples = round(events(iEvent).samples *1000/sFile.header.SamplingFreq);
        end
        
        save([pathname '_LFP\events_original_batch_sorted_LFP_' filebase(5:end) '.mat'],'events')
        clear events
        
    end
    
    if exist([pathname '\events_sorted_' filebase '.mat'], 'file') == 2
        load([pathname '\events_sorted_' filebase '.mat']);
        
        for iEvent = 1:length(events)
            events(iEvent).samples = round(events(iEvent).samples *1000/sFile.header.SamplingFreq);
        end
        
        save([pathname '_LFP\events_sorted_LFP_' filebase(5:end) '.mat'],'events')
        clear events
        
    end
    empty = [];

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



