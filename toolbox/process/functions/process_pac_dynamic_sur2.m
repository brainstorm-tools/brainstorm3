function varargout = process_pac_dynamic_sur2( varargin )
% PROCESS_PAC_DYNAMIC: Compute the Time resolved Phase-Amplitude Coupling
%
% DOCUMENTATION

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
% Authors: Soheila Samiee, Francois Tadel 2013
% 
% Updates:
%   - 1.0.4:  Soheila
%   - 2.0.0: Soheila, based on dpac v.1.1.3 and surrogate 3, June 2016
%   - 2.1:   SS, Based on dpac v2.1.0, Nov. 2016
%   - 3.1:   SS, block resampling (N = 2)
%   - 3.3:   SS, number of blocks for resampling could be more than 2 
%            (default =5 ), May 2017
eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Surrogate tPAC - block resampling - version: 3.4';
    sProcess.FileTag     = '';
%     sProcess.Category    = 'Custom';
%     sProcess.SubGroup    = 'dPAC analysis';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Frequency','Time-resolved Phase-Amplitude Coupling'};
    sProcess.Index       = 660;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw',      'data',     'results',  'matrix'};
    sProcess.OutputTypes = {'timefreq', 'timefreq', 'timefreq', 'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    % === TIME WINDOW
    sProcess.options.timewindow.Comment = 'Time:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    % === NESTING FREQ
    sProcess.options.nesting.Comment = 'Frequency for phase band (low):';
    sProcess.options.nesting.Type    = 'range';
    sProcess.options.nesting.Value   = {[8, 12], 'Hz', 2};
    % === NESTED FREQ
    sProcess.options.nested.Comment = 'Frequency for amplitude band (high):';
    sProcess.options.nested.Type    = 'range';
    sProcess.options.nested.Value   = {[40, 150], 'Hz', 2};
        % Band for fa
%     sProcess.options.label_fa.Comment = 'F_A frequency band:';
%     sProcess.options.label_fa.Type    = 'label';
    sProcess.options.fa_type.Comment = {'   Single band', ...
                                        '   More than one center frequencies (default: 20)' };
    sProcess.options.fa_type.Type    = 'radio';
    sProcess.options.fa_type.Value   = 1;
    
    % === WINDOW LENGTH
    sProcess.options.winLen.Comment = 'Length of sliding time window:';
    sProcess.options.winLen.Type    = 'value';
    sProcess.options.winLen.Value   = {1.10, 'S', 2};
    
    % === NUMBER OF SURROGATE DATASETS
    sProcess.options.Nsurrogate.Comment    = 'Number of surrogate datasets: ';
    sProcess.options.Nsurrogate.Type       = 'value';
    sProcess.options.Nsurrogate.Value      = {100, '', 0};
    
    
    % === SOURCES
    sProcess.options.label5.Comment = '<U><B>Sensors/sources to be investigated :</B></U>';
    sProcess.options.label5.Type    = 'label';
    
    % === CLUSTERS
    sProcess.options.clusters.Comment = '';
    sProcess.options.clusters.Type    = 'scout_confirm';
    sProcess.options.clusters.Value   = {};
    sProcess.options.clusters.InputTypes = {'results'};
    
    % === SENSOR SELECTION
    sProcess.options.target_data.Comment    = 'Sensor types or names (empty=all): ';
    sProcess.options.target_data.Type       = 'text';
    sProcess.options.target_data.Value      = 'MEG, EEG';
    sProcess.options.target_data.InputTypes = {'data', 'raw'};
    % === SOURCE INDICES
    sProcess.options.target_res.Comment    = 'Source indices (empty=all): ';
    sProcess.options.target_res.Type       = 'text';
    sProcess.options.target_res.Value      = '';
    sProcess.options.target_res.InputTypes = {'results'};
    sProcess.options.label6.Comment = '(The indices will only be considered if the scouts are not selected)';
    sProcess.options.label6.Type    = 'label'; 

    % === ROW NAMES
    sProcess.options.target_tf.Comment    = 'Row names or indices (empty=all): ';
    sProcess.options.target_tf.Type       = 'text';
    sProcess.options.target_tf.Value      = '';
    sProcess.options.target_tf.InputTypes = {'timefreq', 'matrix'};

    % === LOOP METHOD
    sProcess.options.label1.Comment = '<U><B>Processing options [expert only]:</B></U>';
    sProcess.options.label1.Type    = 'label';
    % === MAX_BLOCK_SIZE
    sProcess.options.max_block_size.Comment = 'Number of signals to process at once: ';
    sProcess.options.max_block_size.Type    = 'value';
    sProcess.options.max_block_size.Value   = {20, ' ', 0};

    % sProcess.options.filter_sensor.InputTypes = {'results'};
    % === AVERAGE OUTPUT FILES
    sProcess.options.label2.Comment = '<U><B>Output options:</B></U>';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.avgoutput.Comment = 'Save average PAC across trials';
    sProcess.options.avgoutput.Type    = 'checkbox';
    sProcess.options.avgoutput.Value   = 1;
%     % === SAVE PAC MAPS
%     sProcess.options.savefull.Comment = 'Save the full PAC maps';
%     sProcess.options.savefull.Type    = 'checkbox';
%     sProcess.options.savefull.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputsA) %#ok<DEFNU>
tic
    % Get options
    if isfield(sProcess.options, 'timewindow') && isfield(sProcess.options.timewindow, 'Value') && iscell(sProcess.options.timewindow.Value) && ~isempty(sProcess.options.timewindow.Value)
        OPTIONS.TimeWindow = sProcess.options.timewindow.Value{1};
    else
        OPTIONS.TimeWindow = [];
    end
    OPTIONS.FunctionVersion = sProcess.Comment;
    
    % Clusters
    if isfield(sProcess.options, 'clusters') && ~isempty(sProcess.options.clusters) && ~isempty(sProcess.options.clusters.Value)
        OPTIONS.Clusters = sProcess.options.clusters.Value;
    else
        OPTIONS.Clusters = [];
    end
    OPTIONS.BandNesting = sProcess.options.nesting.Value{1};
    OPTIONS.BandNested  = sProcess.options.nested.Value{1};
    OPTIONS.WinLen      = sProcess.options.winLen.Value{1};
    % Get target
    if  ~isempty(OPTIONS.Clusters)         % extract cluster
        OPTIONS.Target = OPTIONS.Clusters;        
    elseif ismember(sInputsA(1).FileType, {'data','raw'}) && isfield(sProcess.options, 'target_data') && ~isempty(sProcess.options.target_data.Value)
        OPTIONS.Target = sProcess.options.target_data.Value;
    elseif strcmpi(sInputsA(1).FileType, 'results') && isfield(sProcess.options, 'target_res') && ~isempty(sProcess.options.target_res.Value)
        OPTIONS.Target = sProcess.options.target_res.Value;
    elseif ismember(sInputsA(1).FileType, {'timefreq', 'matrix'}) && isfield(sProcess.options, 'target_tf') && ~isempty(sProcess.options.target_tf.Value)
        OPTIONS.Target = sProcess.options.target_tf.Value;
    else
        OPTIONS.Target = [];
    end
    % All other options
    OPTIONS.MaxSignals   = sProcess.options.max_block_size.Value{1};
    if (strcmp(sInputsA(1).FileType,'data') && isempty(sProcess.options.target_data.Value)) || ...
            (strcmp(sInputsA(1).FileType,'results') && isempty(sProcess.options.target_res.Value))
        OPTIONS.isFullMaps   = 1; 
    else
        OPTIONS.isFullMaps   = 0; 
    end
    OPTIONS.isAvgOutput  = sProcess.options.avgoutput.Value;
    if (length(sInputsA) == 1)
        OPTIONS.isAvgOutput = 0;
    end
    OPTIONS.HighFreqs    = sProcess.options.fa_type.Value;
    OPTIONS.Nsur = sProcess.options.Nsurrogate.Value{1};

    % ===== INITIALIZE =====
    % Initialize output variables
    OutputFiles = {};
    sPAC_avg = [];
    nAvg = 0;
    % Initialize progress bar
    if bst_progress('isVisible')
        startValue = bst_progress('get');
    else
        startValue = 0;
    end
    % Options for LoadInputFile()
    if strcmpi(sInputsA(1).FileType, 'results')
        LoadOptions.LoadFull = 0;  % Load kernel-based results as kernel+data
    else
        LoadOptions.LoadFull = 1;  % Load the full file
    end
    LoadOptions.IgnoreBad   = 1;  % From raw files: ignore the bad segments
    LoadOptions.ProcessName = func2str(sProcess.Function);
    LoadOptions.TargetFunc = 'all';
    % Start the matlabpool for parallel processing in bst_pac
    
    % Loop over input files
    for iFile = 1:length(sInputsA)

        % ===== LOAD SIGNALS =====
        bst_progress('text', sprintf('PAC: Loading input file (%d/%d)...', iFile, length(sInputsA)));
        bst_progress('set', round(startValue + (iFile-1) / length(sInputsA) * 100));
        
        % Load input signals 
        [sInput, nSignals, iRows] = bst_process('LoadInputFile', sInputsA(iFile).FileName, OPTIONS.Target, OPTIONS.TimeWindow, LoadOptions);
        if isempty(sInput) || isempty(sInput.Data)
            return;
        end
        
        
        % Get sampling frequency
        sRate = 1 / (sInput.Time(2) - sInput.Time(1));
        % Check the nested frequencies
        if (OPTIONS.BandNested(2) > sRate/3)
            % Warning
            strMsg = sprintf('Higher nesting frequency is too high (%d Hz) compared with sampling frequency (%d Hz): Limiting to %d Hz', round(OPTIONS.BandNested(2)), round(sRate), round(sRate/3));
            disp([10 'process_pac> ' strMsg]);
            bst_report('Warning', sProcess, [], strMsg);
            % Fix higher frequencyy
            OPTIONS.BandNested(2) = sRate/3;
        end
        % Check the extent of bandNested band
        if (OPTIONS.BandNested(2) <= OPTIONS.BandNested(1))
            bst_report('Error', sProcess, [], sprintf('Invalid frequency range: %d-%d Hz', round(OPTIONS.BandNested(1)), round(OPTIONS.BandNested(2))));
            continue;
        end

        % ===== COMPUTE PAC MEASURE =====
        % Number of blocks of signals
        MAX_BLOCK_SIZE = OPTIONS.MaxSignals;
        nBlocks = ceil(nSignals / MAX_BLOCK_SIZE);
        sPAC = [];
        % Display processing time
        disp(sprintf('Processing %d blocks of %d signals each.', nBlocks, MAX_BLOCK_SIZE));
        % Process each block of signals
        for iBlock = 1:nBlocks
%             tic
            bst_progress('text', sprintf('PAC: File %d/%d - Block %d/%d', iFile, length(sInputsA), iBlock, nBlocks));
            bst_progress('set', round(startValue + (iFile-1)/length(sInputsA)*100 + iBlock/nBlocks*100));    
            
            % Indices of the signals
            iSignals = (iBlock-1)*MAX_BLOCK_SIZE+1 : min(iBlock*MAX_BLOCK_SIZE, nSignals);
            
            % Get signals to process
            if ~isempty(sInput.ImagingKernel)
                Fblock = sInput.ImagingKernel(iSignals,:) * sInput.Data;
            else
                Fblock = sInput.Data(iSignals,:);
            end
           
            % Defining the options
            PACoptions.doInterpolation = 1;%0               % Applying interpolation in frequency and time domain
            PACoptions.logCenters = 0; %1                   % Choose the center frequencies for f_A with log space in faBand
            PACoptions.overlap = 0.5;                       % Time window over lap (0<= value <1)
            if OPTIONS.HighFreqs ==1
                PACoptions.nHighFreqs = 1;                  % Number of high frequency centers
                PACoptions.doInterpolation = 0;
            else
                PACoptions.nHighFreqs = 20; %4               % Number of high frequency centers
            end
            PACoptions.nSur = OPTIONS.Nsur;
            OPTIONS.PACoptions = PACoptions;
            
            % Estimating DPAC
            sPACblock = Compute(Fblock, sRate,  OPTIONS.BandNested, OPTIONS.BandNesting, OPTIONS.WinLen, PACoptions);
            
            % Check for errors
            if isempty(sPACblock)
                return;
            end
            % Initialize output structure
            nTime = length(sPACblock.TimeOut);
            if isempty(sPAC)
                sPAC.ValPAC      = [];
                sPAC.NestingFreq = [];
                sPAC.NestedFreq  = [];
                sPAC.PhasePAC    = [];
                sPAC.DynamicPAC     = zeros(nSignals, nTime, length(sPACblock.HighFreqs), OPTIONS.Nsur);
                sPAC.DynamicNesting = zeros(nSignals, nTime, length(sPACblock.HighFreqs), OPTIONS.Nsur);
                sPAC.DynamicPhase   = zeros(nSignals, nTime, length(sPACblock.HighFreqs), OPTIONS.Nsur);                
                sPAC.HighFreqs = sPACblock.HighFreqs;
                
                meanInputTime  = OPTIONS.TimeWindow(1)+(sPACblock.TimeOut(end)+OPTIONS.WinLen/2)/2;
                meanOutputTime = (sPACblock.TimeOut(1)+sPACblock.TimeOut(end))/2;
                sPAC.TimeOut   = sPACblock.TimeOut + (meanInputTime - meanOutputTime);
            end
            % Copy block results to output structure
            sPAC.DynamicPAC(iSignals,:,:,:)     = permute(sPACblock.DynamicPAC,[3,2,1,4]);
            sPAC.DynamicNesting(iSignals,:,:,:) = permute(sPACblock.DynamicNesting,[3,2,1,4]);
            sPAC.DynamicPhase(iSignals,:,:,:)   = permute(sPACblock.DynamicPhase,[3,2,1,4]);
        end
                
        % ===== APPLY SOURCE ORIENTATION =====
        if strcmpi(sInput.DataType, 'results') && (sInput.nComponents > 1)
            % Number of values per vertex
            switch (sInput.nComponents)
                case 2
                    sPAC.ValPAC         = (sPAC.ValPAC(1:2:end,:,:)           + sPAC.ValPAC(2:2:end,:,:))           / 2;
                    sPAC.NestingFreq    = (sPAC.NestingFreq(1:2:end,:,:)      + sPAC.NestingFreq(2:2:end,:,:))      / 2;
                    sPAC.NestedFreq     = (sPAC.NestedFreq(1:2:end,:,:)       + sPAC.NestedFreq(2:2:end,:,:))       / 2;
                    sPAC.PhasePAC       = (sPAC.PhasePAC(1:2:end,:,:)         + sPAC.PhasePAC(2:2:end,:,:))         / 2;
                    sPAC.DynamicPAC     = (sPAC.DynamicPAC(1:2:end,:,:,:)     + sPAC.DynamicPAC(2:2:end,:,:,:))     / 2;
                    sPAC.DynamicNesting = (sPAC.DynamicNesting(1:2:end,:,:,:) + sPAC.DynamicNesting(2:2:end,:,:,:)) / 2;
                    sInput.RowNames     = sInput.RowNames(1:2:end);
                    sPAC.DynamicPhase   = (sPAC.DynamicPhase(1:2:end,:,:,:)   + sPAC.DynamicPhase(2:2:end,:,:,:))   / 2;
                    
                case 3
                    sPAC.ValPAC         = (sPAC.ValPAC(1:3:end,:,:)           + sPAC.ValPAC(2:3:end,:,:)           + sPAC.ValPAC(3:3:end,:,:))           / 3;
                    sPAC.NestingFreq    = (sPAC.NestingFreq(1:3:end,:,:)      + sPAC.NestingFreq(2:3:end,:,:)      + sPAC.NestingFreq(3:3:end,:,:))      / 3;
                    sPAC.NestedFreq     = (sPAC.NestedFreq(1:3:end,:,:)       + sPAC.NestedFreq(2:3:end,:,:)       + sPAC.NestedFreq(3:3:end,:,:))       / 3;
                    sPAC.PhasePAC       = (sPAC.PhasePAC(1:3:end,:,:)         + sPAC.PhasePAC(2:3:end,:,:)         + sPAC.PhasePAC(3:3:end,:,:))         / 3;
                    sPAC.DynamicPAC     = (sPAC.DynamicPAC(1:3:end,:,:,:)     + sPAC.DynamicPAC(2:3:end,:,:,:)     + sPAC.DynamicPAC(3:3:end,:,:,:))     / 3;
                    sPAC.DynamicNesting = (sPAC.DynamicNesting(1:3:end,:,:,:) + sPAC.DynamicNesting(2:3:end,:,:,:) + sPAC.DynamicNesting(3:3:end,:,:,:)) / 3;
                    sInput.RowNames     = sInput.RowNames(1:3:end);
                    sPAC.DynamicPhase   = (sPAC.DynamicPhase(1:3:end,:,:,:)   + sPAC.DynamicPhase(2:3:end,:,:,:)   + sPAC.DynamicPhase(3:3:end,:,:,:))   / 3;
                    
            end
        end

        % ===== SAVE FILE =====
        % Detect incomplete lists of sources
        isIncompleteResult = strcmpi(sInput.DataType, 'results') && (length(sInput.RowNames) * sInput.nComponents < nSignals);
        % Comment
        Comment = 'Sur. DynamicPAC';
        if iscell(sInput.RowNames)
            % Find the scout name
            scoutName = sInput.RowNames{1};
            k = strfind(scoutName,'.');               
            if isempty(k)
                Comment = [Comment, ': ' scoutName];      
            else
                Comment = [Comment, ': ' scoutName(1:k-1)];
            end
           
        elseif (length(sInput.RowNames) == 1)
            Comment = [Comment, ': #', num2str(sInput.RowNames(1))];
        elseif isIncompleteResult
            Comment = [Comment, ': ', num2str(length(sInput.RowNames)), ' sources'];
        end
        
        if OPTIONS.isFullMaps
            Comment = [Comment, ' (Full)'];
        end
        % Output data type: if there are not all the sources, switch the datatype to "scout"
        if isIncompleteResult
            sInput.DataType = 'scout';
            % Convert source indices to strings
            if ~iscell(sInput.RowNames)
                sInput.RowNames = cellfun(@num2str, num2cell(sInput.RowNames), 'UniformOutput', 0);
            end
        end
        % Save each as an independent file
        if ~OPTIONS.isAvgOutput
            nAvg = 1;
            OutputFiles{end+1} = SaveFile(sPAC, sInput.iStudy, sInputsA(iFile).FileName, sInput, Comment, nAvg, OPTIONS);
        else
            % Compute online average of the connectivity matrices
            if isempty(sPAC_avg)
                sPAC_avg.ValPAC      = sPAC.ValPAC       ./ length(sInputsA);
                sPAC_avg.NestingFreq = sPAC.NestingFreq  ./ length(sInputsA);
                sPAC_avg.NestedFreq  = sPAC.NestedFreq   ./ length(sInputsA);
                sPAC_avg.PhasePAC(:,:,:,nAvg+1)       =  sPAC.PhasePAC;
                sPAC_avg.DynamicPAC(:,:,:,nAvg+1)     =  sPAC.DynamicPAC;
                sPAC_avg.DynamicNesting(:,:,:,nAvg+1) =  sPAC.DynamicNesting;
                sPAC_avg.DynamicPhase(:,:,:,nAvg+1)   =  sPAC.DynamicPhase;
                
                sPAC_avg.TimeOut     = sPAC.TimeOut;
                sPAC_avg.HighFreqs   = sPAC.HighFreqs;
            else
                sPAC_avg.ValPAC      = sPAC_avg.ValPAC      + sPAC.ValPAC      ./ length(sInputsA);
                sPAC_avg.NestingFreq = sPAC_avg.NestingFreq + sPAC.NestingFreq ./ length(sInputsA);
                sPAC_avg.NestedFreq  = sPAC_avg.NestedFreq  + sPAC.NestedFreq  ./ length(sInputsA);
                sPAC_avg.PhasePAC(:,:,:,nAvg+1)       =  sPAC.PhasePAC;
                sPAC_avg.DynamicPAC(:,:,:,nAvg+1)     =  sPAC.DynamicPAC;
                sPAC_avg.DynamicPhase(:,:,:,nAvg+1)   =  sPAC.DynamicPhase;
                sPAC_avg.DynamicNesting(:,:,:,nAvg+1) =  sPAC.DynamicNesting;                 
            end
            nAvg = nAvg + 1;
        end
    end
    
    % ===== SAVE AVERAGE =====
    if OPTIONS.isAvgOutput
        % Output study, in case of average
        [tmp, iOutputStudy] = bst_process('GetOutputStudy', sProcess, sInputsA);
        % Save file
        OutputFiles{1} = SaveFile(sPAC_avg, iOutputStudy, [], sInput, Comment, nAvg, OPTIONS);
    end
end


%% ========================================================================
%  ===== SUPPORT FUNCTIONS ================================================
%  ========================================================================

%% ===== SAVE FILE =====
function NewFile = SaveFile(sPAC, iOuptutStudy, DataFile, sInput, Comment, nAvg, OPTIONS)
    % ===== PREPARE OUTPUT STRUCTURE =====
    % Create file structure
    FileMat = db_template('timefreqmat');
    FileMat.TF        = sPAC.ValPAC;
    FileMat.Comment   = Comment;
    FileMat.Method    = 'dpac';
    FileMat.Measure   = 'maxpac';
    FileMat.DataFile  = file_win2unix(DataFile);
    FileMat.nAvg      = nAvg;
    FileMat.Freqs     = 0;
    % All the PAC fields
    FileMat.sPAC = rmfield(sPAC, 'ValPAC');
    % Time vector
    FileMat.Time = sPAC.TimeOut;

    % Output data type and Row names
    if isempty(OPTIONS.Target)
        FileMat.DataType = sInput.DataType;
        FileMat.RowNames = sInput.RowNames; 
    elseif strcmpi(sInput.DataType, 'results') && ~isempty(OPTIONS.Target)
        FileMat.DataType = 'matrix';
        if isnumeric(sInput.RowNames)
        	FileMat.RowNames = cellfun(@num2str, num2cell(sInput.RowNames), 'UniformOutput', 0);
        else
            FileMat.RowNames = sInput.RowNames;
        end
    else
        FileMat.DataType = sInput.DataType;
        FileMat.RowNames = sInput.RowNames;
    end
    % Atlas 
    if ~isempty(sInput.Atlas)
        FileMat.Atlas = sInput.Atlas;
    end
    if ~isempty(sInput.SurfaceFile)
        FileMat.SurfaceFile = sInput.SurfaceFile;
    end
    % History: Computation
    FileMat = bst_history('add', FileMat, 'compute', 'PAC measure (see the field "Options" for input parameters)');
    % Save options in the file
    FileMat.Options = OPTIONS;
    
    % ===== SAVE FILE =====
    % Get output study
    sOutputStudy = bst_get('Study', iOuptutStudy);
    % File tag
%     if OPTIONS.isFullMaps
        fileTag = 'timefreq_dpac_fullmaps';
%     else
%         fileTag = 'timefreq_dpac';
%     end
    % Output filename
    NewFile = bst_process('GetNewFilename', bst_fileparts(sOutputStudy.FileName), fileTag);
    % Save file
    bst_save(NewFile, FileMat, 'v6');
    % Add file to database structure
    db_add_data(iOuptutStudy, NewFile, FileMat);
    toc
end




% ===== COMPUTE PAC MEASURE =====
function sPAC = Compute(Xinput, sRate, faBand, fpBand, winLen, Options)
% USAGE:
%   sPAC = dPACestimate(Xinput, sRate, faBand, fpBand, winLen, PLvector)
%
% INPUTS:
%    - Xinput:        [nChannels,nTime] signal to process
%    - sRate:         Sampling frequency (Hz)
%    - faBand:        Nested Band: Minimum and maximum frequency for extraction of frequency for amplitude
%    - fpBand:        Nesting Band: Minimum and maximum frequency for extraction of frequency for phase (Hz)
%    - winLen:        Length of each time window for coupling estimation(S) (default: 1 Sec)
%    - isFullMaps:    If 1, save the full directPAC maps
%
% OUTPUTS:   sPAC structure [for each signal]
%    - TimeOut:        Output time vector (Sec)
%    - HighFreqs:       Frequency for amplitude vector
%    - ValPAC:         [nChannels, nTimeOut] Maximum PAC strength in each  time point
%    - NestedFreq:     [nChannels, nTimeOut] Fnested corresponding to maximum synchronization index in each time point
%    - NestingFreq:    [nChannels, nTimeOut] Fnesting corresponding to maximum synchronization index in each time point
%    - phasePAC:       [nChannels, nTimeOut] Phase corresponding to maximum synchronization index in each time point
%    - DynamicNesting: [nNestedCenters,nTimeOut,nChannels] Estimated nesting frequency for all times, channels and nested intervals
%    - DynamicPAC:     [nNestedCenters,nTimeOut,nChannels] full array of PAC
%
% DESCRIPTION:
%   Estimation of Phase Amplitude Coupling (PAC) with DPAC method.
%
% Author:  Soheila Samiee, 2013
%

if (nargin < 4) || isempty(fpBand)
    fpBand = [4, 8];
end
if (nargin < 5) || isempty(winLen)
    winLen = 1;           
end
if ~isfield(Options, 'overlap')
    Options.overlap = 0.5;
end


if fpBand(2)>faBand(1)
    fpBand(2) = faBand(1)/2;
    error_msg = ['Maximum of Fp should be less than half of the minimum of Fa!' 10 10 ...
        'max{Fp} modified to ', num2str(fpBand(2))];
    bst_report('Error', sProcess, [], error_msg);
    disp(['Warning: ' error_msg]);    
end

if winLen < 2*1/fpBand(1)        
    error_msg = ['Window length is short for extracting this minimum fp!' 10 ...
        'Either increase window length to: ',num2str(2*1/fpBand(1)), ' or increase minimum fp to; ', num2str(2/winLen)];
    bst_report('Error', sProcess, [], error_msg);
    disp(['Warning: ' error_msg]); 
    winLen = 2*1/fpBand(1);
end


% ===== SETTING THE PARAMETERS =====
tStep = winLen*(1-Options.overlap);     % Time step for sliding window on time (Sec) (Overlap: 50%)
margin = 2;%1                       % Margin (in time) for filtering (Sec) --- default: 2sec -> changed to 1 sec in May12,2016
hilMar = 1/5;                       % Percentage of margin for Hilber transform
nTS = size(Xinput,2);               % Number of temporal samples of data
bandNestingLen= max(3,1/(winLen+margin));% Length of band nesting -- considering the resolution in FFT domain with available window length
isMirror = 0;                       % Mirroring the data in filtering
isRelax  = 1;                       % Attenuation of the filter in the stopband (1 => 40 dB, 0 => 60 dB)
minExtracFreq = max(1/winLen, fpBand(1));  % minimum frequency that could be extracted as nestingFreq
sProcess = 'Process_pac_dynamic_sur2';

% Mode = Options.Mode;                % Mode of estimating the coupling (line or map)
doInterpolation = Options.doInterpolation;  % Applying interpolation in frequency and time domain
logCenters = Options.logCenters;    % Choose the center frequencies for f_A with log space in faBand
nHighFreqs = Options.nHighFreqs;    % Number of high frequency centers
% Mode = 'map';                       % Mode of estimating the coupling (line or map)
% doInterpolation = 1;                % Applying interpolation in frequency and time domain
% logCenters = 0; %0                  % Choose the center frequencies for f_A with log space in faBand
% nHighFreqs = 20;%4;                 % Number of high frequency centers
missedPcount = 0;                   % Number of intervals that do not have peak in their F_A envelope PSD 
mirrorEffectSample = 40;            % Number of samples that can be affected due to mirroring effect

N = 5; % Number of blocks for shuffling

% ==== ADDING MARGING TO THE DATA => AVOID EDGE ARTIFACT (FILTERS AND HILBERT TRANSFORM) ====
nMargin = fix(margin*sRate);
nHilMar = fix(nMargin*hilMar);

if (nTS/sRate < 2*winLen)
    error_msg = 'Data length should be at least twice of window length';
    bst_report('Error', 'process_pac_dynamic', [], error_msg);
    disp(['Error: ' error_msg]);
    sPAC = [];
    return
% elseif (nTS < nMargin)
%     tmp = repmat([Xinput(:,end-1:-1:2),Xinput],1,ceil(nMargin/nTS));    
%     Xinput = [tmp(:,end-nMargin+1-size(Xinput,2):end-size(Xinput,2)), Xinput, tmp(:,1:nMargin)];
%     clear tmp
% else
%     Xinput = [Xinput(:,nMargin+1:-1:2), Xinput, Xinput(:,end-1:-1:end-nMargin)];
end

% Zero-padding signal for the margin
Xinput = [zeros(size(Xinput,1),nMargin), Xinput, zeros(size(Xinput,1),nMargin)];



% ==== SETTING THE PARAMETERS OF THE FILTERS ====
if nHighFreqs > 1 %strcmp(Mode,'map')
%     Fconst = (faBand(end)-faBand(1))/nHighFreqs;                     % Frequency distant between successive fAs
    if logCenters
        nestedCenters = logspace(log10(faBand(1)),log10(faBand(end)),nHighFreqs);
    else
        nestedCenters = linspace(faBand(1),faBand(end),nHighFreqs);
    end
    Fstep = diff(nestedCenters)/2;  % the range of frequency around each nested center
    Fstep = [Fstep(1),Fstep,Fstep(end)];
    Fstep = max(Fstep, fpBand(2)/2);  % Minimum band width is defined to cover the whole interval between consecutive centre frequencies and at the same time consider all coupled frequencies to it in the range of interest.        
else
    nestedCenters = mean(faBand);
    Fstep    = abs(faBand-nestedCenters);
end

fArolloff = [];
fProlloff = [];%1          % roll off frequency for filtering
sPAC.HighFreqs = nestedCenters;
nFa = length(nestedCenters);
nSources = size(Xinput,1);
isources = 1:nSources;
nTime = fix((nTS-fix(winLen*sRate))/fix(tStep*sRate))+1;
TimeOut = winLen/2 : tStep : winLen/2+(nTime-1)*tStep;        % Sec
nSur = Options.nSur;                % Number of surrogate itterations
PAC = zeros(nFa,nTime,nSources,nSur);               % PAC measure
nestingFreq = zeros(nFa,nTime,nSources,nSur);
DynamicPhase= zeros(nFa,nTime,nSources);               % PAC measure


% ===== MAIN LOOP ON FA ===== %
% Filtering in Fa band before cutting into smaller time windows
% (=> Higherfrequency resolution + faster process)

for ifreq=1:nFa
    % fA band
    bandNested = [nestedCenters(ifreq)-Fstep(ifreq),nestedCenters(ifreq)+Fstep(ifreq+1)];
    
    % Filtering in fA band
    Xnested = bst_bandpass_hfilter(Xinput, sRate,bandNested(1), bandNested(2), isMirror, isRelax, fArolloff);    % Filtering
    Xnested = Xnested(:,nMargin-nHilMar+1:end-nMargin+nHilMar);               % Removing part of the margin
    
    % Hilbert transform
    Z = hilbert(Xnested')';
    
    % Phase and envelope detection
    nestedEnv_total = abs(Z);             % Envelope of nested frequency rhythms
    nestedEnv_total = nestedEnv_total(:,nHilMar:end-nHilMar);              % Removing the margin
    
    % Loop on Time
    for iTime=1:nTime
        X = Xinput(:, (iTime-1)*fix(tStep*sRate)+[1:fix((2*margin+winLen)*sRate)]);
        nestedEnv = nestedEnv_total(:, (iTime-1)*fix(tStep*sRate)+[1:fix(winLen*sRate)]);
        
        % Time vector and number of samples
        nSample = size(nestedEnv,2);
        nFreq = 2^ceil(log2(nSample)+1);
        
        % Extraction of nesting frequency
        Ffft = abs(fft(nestedEnv-repmat(mean(nestedEnv,2),1,nSample),nFreq,2)).^2/nSample;
        freq = linspace(0,sRate,nFreq);
        x1 = X(:,nMargin+1:nMargin+fix(winLen*sRate));
        FfftSig = abs(fft(x1-repmat(mean(x1,2),1,nSample),nFreq,2)).^2/nSample;
        %%%
        
        % Finding the corresponding frequency component
        ind = bst_closest([minExtracFreq, fpBand(2)], freq);
        if freq(ind(1))<(minExtracFreq-diff(freq(1:2)))
            ind(1) = ind(1)+1;
        end
        if ind(2)>fpBand(2)
            ind(2) = ind(2)-1;
        end
        
                % Add previous and next point to the interval to give the algorithm 
        % to find the local peaks even if they are in the first and last 
        % point of interst in the spectrum
        if ind(1)>1
            ind(1) = ind(1)-1;
        end
        ind(2) = ind(2)+1;
        
        if freq(ind(1))<(minExtracFreq-diff(freq(1:2)))
            ind(1) = ind(1)+1;
        end
        
        indm = zeros(nSources,1);
        for iSource=1:nSources
                        
            % Extracting the peak from envelope's PSD and then confirming
            % with a peak on the original signal
            [pks_env,locs_env] = findpeaks(Ffft(iSource,ind(1):ind(2)),'SORTSTR','descend');
            [pks_orig, locs_orig] = findpeaks(FfftSig(iSource,ind(1):ind(2)),'SORTSTR','descend');  % To check if a peak close to the coupled fp is available in the original signal
%             clear pks_env pks_orig
            
            % Ignore small peaks
            pks_orig = pks_orig/max(pks_orig);
            locs_orig = locs_orig(pks_orig>0.1);

            % Confirming the peak
            max_dist = max(1.5/winLen,1.5);     % maximum acceptable distance between peaks in evelope and the original signal's PSD
            count = 1;
            check_pks = 1;
            fp_loc = [];
            while check_pks && count<=length(locs_env)
                index = bst_closest(freq(locs_env(count)), freq(locs_orig));
                if abs(freq(locs_orig(index))-freq(locs_env(count)))<=max_dist
                    fp_loc = locs_env(count);
                    check_pks = 0;
                else
                    count = count+1;
                end
            end
            % If peak is not approved or no peak
            if isempty(fp_loc)
                fp_loc = 0;    % arbitrary value for fp  ==> will set the pac value to zero
                missedPcount = missedPcount +1;
            end
            
            indm(iSource) = fp_loc(1);
            clear pks_env locs_env
        end
        
        nestingFreq(ifreq,iTime,isources) = freq(ind(1)+indm-1);
        bandNesting = [max([squeeze(nestingFreq(ifreq,iTime,isources))-bandNestingLen/2,zeros(size(nestingFreq,3),1)],[],2),...
            squeeze(nestingFreq(ifreq,iTime,isources))+bandNestingLen/2];
        bandNesting(bandNesting<.15)=.15;

% Filtering in fP band
        if length(unique(bandNesting(:,1)))==1 && length(unique(bandNesting(:,2)))==1
            Xnesting = bst_bandpass_hfilter(X, sRate,bandNesting(1,1), bandNesting(1,2), isMirror, isRelax, fProlloff);    % Filtering
        else
            Xnesting = zeros(size(X));
            for i=1:length(isources)
                Xnesting(i,:) = bst_bandpass_hfilter(X(i,:), sRate, bandNesting(i,1), bandNesting(i,2),isMirror, isRelax, fProlloff);    % Filtering
            end
        end        
        Xnesting = Xnesting(:,nMargin-nHilMar+1:fix((margin+winLen)*sRate)+nHilMar);              % Removing part of the margin        
        % Hilbert transform
        Z = hilbert(Xnesting')';        
        % Phase detection
        nestingPh = angle(Z-repmat(mean(Z,2),1,size(Z,2)));    % Phase of nesting frequency        
        nestingPh = nestingPh(:,nHilMar:fix(winLen*sRate)+nHilMar-1);              % Removing the margin
        
        
        for ii=1:length(isources)           
            iphase = find(diff(sign(nestingPh(ii,:) - nestingPh(ii,1)))==-2 | ...
                sign(nestingPh(ii,2:end)-nestingPh(ii,1))==0 | ...
                -(diff(sign(nestingPh(ii,:) - nestingPh(ii,1)))-1).*diff(nestingPh(ii,:)-nestingPh(ii,1)) >6 )-1;
            if isempty(iphase)
                iphase = length(nestingPh(ii,:));
            end
            amplitude = nestedEnv(ii,1:max(iphase));
            phase = nestingPh(ii,1:max(iphase));
            
            % Block resampling N=2
            numpoints=length(amplitude); %% number of sample points in raw signal

            if N==2
                minskip=numpoints/4; %% time lag must be at least this big
                maxskip=numpoints-numpoints/4; %% time lag must be smaller than this
                skip = ceil(minskip + (maxskip-minskip-1)*rand(2*nSur,1));
                skip(skip>maxskip)=[];
                skip(skip<minskip)=[];
                skip=skip(1:nSur,1);
                
                
                for iSur=1:nSur
                    surrogate_amplitude=[amplitude(skip(iSur):end) amplitude(1:skip(iSur)-1)];
                    PAC(ifreq,iTime,isources(ii),iSur) = sum(surrogate_amplitude.*exp(1i*phase),2)./max(iphase)./sqrt(mean(amplitude.^2,2));
                    DynamicPhase(ifreq,iTime,isources(ii),iSur) = angle(PAC(ifreq,iTime,isources(ii)));
                    
                    if indm(ii)==0 % Fp not confirmed and arbitrary value for fp
                        PAC(ifreq,iTime,isources(ii),iSur) = 0;
                    end
                end
                
            elseif N>2 & N<numpoints/20
                % Block resampling N>2
%                 N = 10;
                numpoints=length(amplitude); %% number of sample points in raw signal
                block_len = fix(numpoints/N);
                remaining = numpoints - block_len*N;
                blocked_amp = reshape(amplitude(1:end-remaining),[block_len,N]);
                
                for iSur=1:nSur
                    order = randperm(N);
                    blocked_amp = blocked_amp(:,order);
                    surrogate_amplitude = [blocked_amp(:)', amplitude(end-remaining+1:end)];
                    PAC(ifreq,iTime,isources(ii),iSur) = sum(surrogate_amplitude.*exp(1i*phase),2)./max(iphase)./sqrt(mean(amplitude.^2,2));
                    DynamicPhase(ifreq,iTime,isources(ii),iSur) = angle(PAC(ifreq,iTime,isources(ii)));
                    
                    if indm(ii)==0 % Fp not confirmed and arbitrary value for fp
                        PAC(ifreq,iTime,isources(ii),iSur) = 0;
                    end
                end
                
            else
                warning('Number of blocks should be at least 2, and less than 5% of data points')
            end
        end
    end
      disp(['iFreq: ', num2str(ifreq),' / ',num2str(nFa)]);
end



% ===== EXTRACTING THE PAC RELATED VALUES ===== %
[PACmax,maxInd] = max(abs(PAC),[],1); 
% Fnested  = squeeze(nestedCenters(maxInd))';
% Sind     = repmat((1:nSources), nTime, 1);           % Source indices
% Tind     = repmat((1:nTime)', 1, nSources);              % Time indices
% linInd   = sub2ind(size(PAC),maxInd(:),Tind(:),Sind(:));
% Fnesting = reshape(nestingFreq(linInd),nTime,nSources)';
% phase    = reshape(angle(PAC(linInd)),nTime,nSources)'/pi*180;
% PACmax   = squeeze(PACmax)';

% ===== Interpolation in time domain for smoothing the results ==== %
if doInterpolation
    % Interpolation of PAC
    if nSources>1       
        [X,Y,Z,W] = ndgrid(nestedCenters,TimeOut,[1:nSources], 1:nSur);
        ny = linspace(TimeOut(1), TimeOut(end), 2*length(TimeOut)-1);
        if logCenters
            nx = logspace(log10(nestedCenters(1)), log10(nestedCenters(end)), 2*nFa-1);
        else
            nx = linspace(nestedCenters(1), nestedCenters(end), 2*nFa-1);
        end
        [nX,nY,nZ,nW] = ndgrid(nx,ny,[1:nSources], 1:nSur);
        PAC = interpn(X,Y,Z,W,abs(PAC),nX,nY,nZ,nW,'linear',0);
        % make the notations similar
        tmp = nx; nx = ny;ny = tmp; clear tmp;
        
    else        
        [X,Y,Z] = meshgrid(TimeOut,nestedCenters,[1:nSur]);
        nx = linspace(TimeOut(1), TimeOut(end), 2*nTime-1);
        if logCenters
            ny = logspace(log10(nestedCenters(1)), log10(nestedCenters(end)), 2*nFa-1);
        else
            ny = linspace(nestedCenters(1), nestedCenters(end), 2*nFa-1);
        end
        [nX,nY,nZ] = meshgrid(nx,ny,[1:nSur]);
        PAC = interp3(X,Y,Z,abs(squeeze(PAC)),nX,nY,nZ,'linear',0);
        PAC = permute(PAC,[1,2,4,3]);    
    end
    TimeOut = nx;
    sPAC.HighFreqs = ny;
    clear nx nX nY nZ X Y Z
       
    % nestingFreq
    tmp = zeros(nFa*2-1, nTime, nSources, nSur);
    tmp(1:2:end,:,:,:) = nestingFreq;
    tmp(2:2:end,:,:,:) = nestingFreq(1:end-1,:,:,:);
    tmp2 = zeros(nFa*2-1, nTime*2-1, nSources, nSur);
    tmp2(:,1:2:end,:,:) = tmp;
    tmp2(:,2:2:end,:,:) = tmp(:,1:end-1,:,:);
    nestingFreq = tmp2; 
    
    
    tmp = zeros(nFa*2-1, nTime, nSources, nSur);
    tmp(1:2:end,:,:,:) = DynamicPhase;
    tmp(2:2:end,:,:,:) = DynamicPhase(1:end-1,:,:,:);
    tmp2 = zeros(nFa*2-1, nTime*2-1, nSources, nSur);
    tmp2(:,1:2:end,:,:) = tmp;
    tmp2(:,2:2:end,:,:) = tmp(:,1:end-1,:,:);
    DynamicPhase = tmp2; 
    clear tmp tmp2
    
end

Fnesting = [];
Fnested = [];
phase = [];

if missedPcount>0
disp(['Missed Peaks:',num2str(missedPcount),'/',num2str(nFa*nTime*nSources)])
end

% ===== OUTPUTS ===== %
if nTime >1
    sPAC.ValPAC = PACmax;
    sPAC.NestingFreq = Fnesting;
    sPAC.NestedFreq  = Fnested;
    sPAC.PhasePAC = phase;
    sPAC.TimeOut  = TimeOut;
    sPAC.DynamicPAC(:,:,1:nSources,:) = abs(PAC);
    sPAC.DynamicNesting(:,:,1:nSources,:)  = nestingFreq;
    sPAC.DynamicPhase(:,:,1:nSources,:)  = DynamicPhase;

        % == Generating two time points for Brainstorm structure ==
else        
    sPAC.ValPAC = [PACmax(:), PACmax(:)];
    sPAC.NestingFreq = [Fnesting(:), Fnesting(:)];
    sPAC.NestedFreq  = [Fnested(:), Fnested(:)];
    sPAC.PhasePAC = [phase(:), phase(:)];
    sPAC.TimeOut  = [TimeOut, TimeOut+0.001];
    sPAC.DynamicPAC(:,1:2,1:nSources,:) = repmat(abs(PAC),[1,2,1]);
    sPAC.DynamicNesting(:,1:2,1:nSources,:)  = repmat(abs(nestingFreq),[1,2,1]);
    sPAC.DynamicPhase(:,1:2,1:nSources,:)  = repmat(abs(DynamicPhase),[1,2,1]);
end

end


