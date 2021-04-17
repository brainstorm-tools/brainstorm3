function varargout = process_pac_ir_dynamic( varargin )
% PROCESS_PAC_DYNAMIC: Compute the Time resolved Phase-Amplitude Coupling
%
% DOCUMENTATION
 
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
% Authors: Soheila Samiee, Francois Tadel 2013
%
%  v 1.0.4 --> change in interpolated time definition
%  v 1.0.5 --> accept clusters
%  v 1.0.6 --> find peaks instead of maximum
%  v 1.0.7 --> PSD of fp signal effective in fp* detection, Sep 2014
%  v 1.0.8 --> accept cluster for seed, Sep 2014
%   - 1.0.9:  Soheila, finding peaks instead of maximum
%   - 1.0.10: Soheila, Effect of main signal PSD in fp selection + interpolation of Fa to 2xnFa-1
%   - 1.1.0:  Selection of scouts became available with new format of Brainstorm
%   - 1.1.1:  A small bug in defining the Output time is fixed 
%   - 1.1.2:  HTML format for display changed - options are added to
%   compute function, April 2015
%   - 1.1.3: A problem in selecting one seed vertex is fixed
%   - 1.1.4: Soheila, Single or multiple band for fA can be selected in
%   the input window, October 2015
%
%   - 1.1.5: Soheila, Single time window is accepted!!!!
%   - 1.1.6: Soheila, (isFull) tag is fixed, june 2016
%
%   - 2.0.1: SS : MAJOR CHANGES (Oct. 2016)
%                - Loop on Fa before time => faster + Less edge artifact
%                - Filters bandwidth and stop band: modified
%                    * FA: Band width:: max(difference between centre
%                      frequency, highest fp of interest), stopband: 5 Hz
%                    * FP: Band width:: max(1,1/window length)
%                
%   - 2.0.2: SS Oct. 2016
%                - Detection of Fp => Not multiplied by normalizing vector
%                  but check if any peak available in PSD of original 
%                  signal close by
%                  
%   - 2.1.0: SS, Nov. 2016
%                - Filters are all updated to new filters in Brainstorm (bst_bandpass_hfilter)
%   - 2.1.1: SS, Dec. 2016
%                - Improve in confirmation of fp* selected in the algorithm
%
%   - 2.2.0: SS, Dec. 2016
%                - Complete saving of phase info.
%
%   - 2.3.0: SS. Dec. 2016
%                - Adding the possibility of importing data with margin
%                included in it
%   - 2.3.1: SS. Feb. 2016
%                - Number of points for Fourier transform is changed
%
%   - 2.4:   SS. Aug. 2017 
%                - "dpac" name changed to "tPAC"
%
%   - 2.4.1: SS. Dec. 2017 
%                - a bug related to pac estimation for single time-window
%                is fixed!
%
%   - 2.5: SS. Aug. 2018: Bug fix
%                - Adding TimeInit for files with "all recording" option
%                checked
%                - Fixing the iPhase estimation in compute function 

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Inter-regional tPAC';
    sProcess.FileTag     = '';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Frequency','Time-resolved Phase-Amplitude Coupling'};
    sProcess.Index       = 660;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw',      'data',     'results',  'matrix'};
    sProcess.OutputTypes = {'timefreq', 'timefreq', 'timefreq', 'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    
    % === TIME WINDOW
    sProcess.options.timewindow.Comment = 'Time:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];

    % === Margin for filtering
    sProcess.options.label0.Comment = '<U><B>Buffer:</B></U> Is 2 seconds of extra data for buffer (from both sides) included in input time window?';
    sProcess.options.label0.Type    = 'label';
    sProcess.options.margin.Comment = {'No', 'Yes'};
    sProcess.options.margin.Type    = 'radio';
    sProcess.options.margin.Value   = 1;
    
    % === WINDOW LENGTH
    sProcess.options.winLen.Comment = 'Length of sliding time window:';
    sProcess.options.winLen.Type    = 'value';
    sProcess.options.winLen.Value   = {1.10, 's', 2};
    
%     sProcess.options.singleT.Comment = 'Single time window, if yes specify the range below (should be shorter than time window from both sides)';
%     sProcess.options.singleT.Type    = 'checkbox';
%     sProcess.options.singleT.Value   = 0;

    % === NESTING FREQ
    sProcess.options.nesting.Comment = 'Frequency for phase band (f_P):';
    sProcess.options.nesting.Type    = 'range';
    sProcess.options.nesting.Value   = {[8, 12], 'Hz', 2};
    % === NESTED FREQ
    sProcess.options.nested.Comment = 'Frequency for amplitude band (f_A):';
    sProcess.options.nested.Type    = 'range';
    sProcess.options.nested.Value   = {[40, 150], 'Hz', 2};
        % Band for fa
%     sProcess.options.label_fa.Comment = 'F_A frequency band:';
%     sProcess.options.label_fa.Type    = 'label';
    sProcess.options.fa_type.Comment = {'   Single band', ...
                                        '   More than one center frequencies (default: 20)' };
    sProcess.options.fa_type.Type    = 'radio';
    sProcess.options.fa_type.Value   = 2;    
    % === COUPLING TYPE
    sProcess.options.label3.Comment = '<U><B>Inter-regional coupling type:</B></U>';
    sProcess.options.label3.Type    = 'label';
    sProcess.options.coupling_type.Comment = {'Coupling between one source for f_P (seed) and a series of sources for f_A', ...
                                         'Coupling between one source for f_A (seed) and a series of sources for f_P'};
    sProcess.options.coupling_type.Type    = 'radio';
    sProcess.options.coupling_type.Value   = 1;
    
    % === SEED SELECTION ===
    sProcess.options.label4.Comment = '<U><B>Seed:</B></U>';
    sProcess.options.label4.Type    = 'label';

        % === Options: CLUSTERS
    sProcess.options.seedClusters.Comment = 'Select the seed scout:';
    sProcess.options.seedClusters.Type    = 'scout_confirm';
    sProcess.options.seedClusters.Value   = {};
    sProcess.options.seedClusters.InputTypes = {'results'};    

        % === SENSOR SELECTION
    sProcess.options.seed_data.Comment    = 'Sensor name : ';
    sProcess.options.seed_data.Type       = 'text';
    sProcess.options.seed_data.Value      = '';
    sProcess.options.seed_data.InputTypes = {'data', 'raw'};
        % === SOURCE INDICES
    sProcess.options.seed_res.Comment    = 'Source index : ';
    sProcess.options.seed_res.Type       = 'text';
    sProcess.options.seed_res.Value      = '';
    sProcess.options.seed_res.InputTypes = {'results'};
        % === ROW NAMES
    sProcess.options.seed_tf.Comment    = 'Row name or index : ';
    sProcess.options.seed_tf.Type       = 'text';
    sProcess.options.seed_tf.Value      = '';
    sProcess.options.seed_tf.InputTypes = {'timefreq', 'matrix'};

    % === OTHER SOURCES
    sProcess.options.label5.Comment = '<U><B>Sensors/sources to be investigated :</B></U>';
    sProcess.options.label5.Type    = 'label'; 
        
        % === Options: CLUSTERS
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
    sProcess.options.max_block_size.Value   = {44, ' ', 0};

    % sProcess.options.filter_sensor.InputTypes = {'results'};
    % === AVERAGE OUTPUT FILES
    sProcess.options.label2.Comment = '<U><B>Output options:</B></U>';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.avgoutput.Comment = 'Save average PAC across trials';
    sProcess.options.avgoutput.Type    = 'checkbox';
    sProcess.options.avgoutput.Value   = 0;
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
    % Get options
    if isfield(sProcess.options, 'timewindow') && isfield(sProcess.options.timewindow, 'Value') && iscell(sProcess.options.timewindow.Value) && ~isempty(sProcess.options.timewindow.Value)
        OPTIONS.TimeWindow = sProcess.options.timewindow.Value{1};
    else
        OPTIONS.TimeWindow = [];
    end
    OPTIONS.BandNesting = sProcess.options.nesting.Value{1};
    OPTIONS.BandNested  = sProcess.options.nested.Value{1};
    OPTIONS.WinLen      = sProcess.options.winLen.Value{1};
    OPTIONS.HighFreqs    = sProcess.options.fa_type.Value;
    OPTIONS.margin_included = sProcess.options.margin.Value-1;
    
    % ===== TARGET =====
    if isfield(sProcess.options, 'clusters') && ~isempty(sProcess.options.clusters) && ~isempty(sProcess.options.clusters.Value)
        OPTIONS.Clusters = sProcess.options.clusters.Value;
    else
        OPTIONS.Clusters = [];
    end
    % Get target     
    if ~isempty(OPTIONS.Clusters)    
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
    
    % ===== SEED =====
    if isfield(sProcess.options, 'seedClusters') && ~isempty(sProcess.options.seedClusters) && ~isempty(sProcess.options.seedClusters.Value)
        OPTIONS.seedClusters = sProcess.options.seedClusters.Value;
    else
        OPTIONS.seedClusters = [];
    end
    OPTIONS.FunctionVersion = sProcess.Comment;
    % Get seed
    if ~isempty(OPTIONS.seedClusters)
        OPTIONS.Seed = OPTIONS.seedClusters;
    elseif ismember(sInputsA(1).FileType, {'data','raw'}) && isfield(sProcess.options, 'seed_data') && ~isempty(sProcess.options.seed_data.Value)
        OPTIONS.Seed = sProcess.options.seed_data.Value;
    elseif strcmpi(sInputsA(1).FileType, 'results') && isfield(sProcess.options, 'seed_res') && ~isempty(sProcess.options.seed_res.Value)
        OPTIONS.Seed = sProcess.options.seed_res.Value;
    elseif ismember(sInputsA(1).FileType, {'timefreq', 'matrix'}) && isfield(sProcess.options, 'seed_tf') && ~isempty(sProcess.options.seed_tf.Value)
        OPTIONS.Seed = sProcess.options.seed_tf.Value;
    else
        OPTIONS.Seed = [];
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
        [sInput, nSignals] = bst_process('LoadInputFile', sInputsA(iFile).FileName, OPTIONS.Target, OPTIONS.TimeWindow, LoadOptions);
        if isempty(sInput) || isempty(sInput.Data)
            bst_report('Error', sProcess, [], 'Could not read input data.');
            return;
        end
        % Load the seed signal
        sSeedInput = bst_process('LoadInputFile', sInputsA(iFile).FileName, OPTIONS.Seed, OPTIONS.TimeWindow, LoadOptions);
        if isempty(sSeedInput) || isempty(sSeedInput.Data)
            bst_report('Error', sProcess, [], 'Could not read input seed data.');
            return;
        end
        % Get seed vertex (for scouts only)
        if ~isempty(OPTIONS.Seed) && iscell(OPTIONS.Seed)
            % Load the scouts structures from the surface file
            sScouts = process_extract_scout('GetScoutsInfo', sProcess, sInputsA(iFile), sSeedInput.SurfaceFile, OPTIONS.Seed);
            if (length(sScouts) ~= 1)
                bst_report('Error', sProcess, [], 'Only one scout should be selected as the seed in this process.');
                return;
            end
            % Look for the index of the seed in the list of the scout vertices
            iSeed = find(sScouts(1).Vertices == sScouts(1).Seed);
            % Get the data from the seed
            sSeedInput.Data = sSeedInput.Data(iSeed,:);
            % Keep the seed index for later (file comment)
            seedComment = sSeedInput.RowNames{iSeed};
        elseif ~isempty(OPTIONS.Seed) && ~iscell(OPTIONS.Seed)
            seedComment = OPTIONS.Seed;
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
            tic
            bst_progress('text', sprintf('PAC: File %d/%d - Block %d/%d', iFile, length(sInputsA), iBlock, nBlocks));
            bst_progress('set', round(startValue + (iFile-1)/length(sInputsA)*100 + iBlock/nBlocks*100));    
            % Indices of the signals
            iSignals = (iBlock-1)*MAX_BLOCK_SIZE+1 : min(iBlock*MAX_BLOCK_SIZE, nSignals);
            % Get target signals to process
            if ~isempty(sInput.ImagingKernel)
                Fblock = sInput.ImagingKernel(iSignals,:) * sInput.Data;
            else
                Fblock = sInput.Data(iSignals,:);
            end             
            % Get seed signals to process
            if ~isempty(sSeedInput.ImagingKernel)
                FblockSeed = sSeedInput.ImagingKernel(1,:) * sSeedInput.Data;
            else
                FblockSeed = sSeedInput.Data(1,:);
            end
            % Prepare the inputs for slow (modulator) and fast (modulated) oscillations
            if isfield(sProcess.options, 'coupling_type')
                switch(sProcess.options.coupling_type.Value)
                    case 1,  
                        FblockA = Fblock;
                        FblockP = repmat(FblockSeed,size(Fblock,1),1);
                    case 2,  
                        FblockP = Fblock;
                        FblockA = repmat(FblockSeed,size(Fblock,1),1);
                end
            else
                FblockA = Fblock;
                FblockP = repmat(FblockSeed,size(Fblock,1),1);
            end
            
            %Defining the options
            PACoptions.doInterpolation = 1;                % Applying interpolation in frequency and time domain
            PACoptions.logCenters = 0;                     % Choose the center frequencies for f_A with log space in faBand
            PACoptions.overlap = 0.5;                       % Time window over lap (0<= value <1)
            PACoptions.margin = 2;                             % Margin in filtering
            PACoptions.margin_included = OPTIONS.margin_included;
            
            if OPTIONS.HighFreqs ==1
                PACoptions.nHighFreqs = 1;                  % Number of high frequency centers
                PACoptions.doInterpolation = 0;
            else
                PACoptions.nHighFreqs = 20; %20               % Number of high frequency centers
            end
            OPTIONS.PACoptions = PACoptions;
            
            % Estimating tPAC
            sPACblock = Compute(FblockA, FblockP, sRate,  OPTIONS.BandNested, OPTIONS.BandNesting, OPTIONS.WinLen, PACoptions);
            % Check for errors
            if isempty(sPACblock)
                return;
            end
            % Initialize output structure
            nTime = length(sPACblock.TimeOut);
            if isempty(sPAC)
                sPAC.ValPAC      = zeros(nSignals, nTime);
                sPAC.NestingFreq = zeros(nSignals, nTime);
                sPAC.NestedFreq  = zeros(nSignals, nTime);
                sPAC.PhasePAC    = zeros(nSignals, nTime);
                sPAC.DynamicPAC = zeros(nSignals, nTime, length(sPACblock.HighFreqs), 1);
                sPAC.DynamicNesting = zeros(nSignals, nTime, length(sPACblock.HighFreqs), 1);
                sPAC.DynamicPhase = zeros(nSignals, nTime, length(sPACblock.HighFreqs), 1);                
                sPAC.HighFreqs = sPACblock.HighFreqs;

                if ~isempty(OPTIONS.TimeWindow)
                    TimeInit = OPTIONS.TimeWindow(1);
                else
                    TimeInit = 0;
                end
                
                if PACoptions.margin_included
                    meanInputTime  = PACoptions.margin+TimeInit+(sPACblock.TimeOut(end)+OPTIONS.WinLen*(1-PACoptions.overlap))/2; 
                else
                    meanInputTime  = TimeInit+(sPACblock.TimeOut(end)+OPTIONS.WinLen*(1-PACoptions.overlap))/2;
                end
                meanOutputTime = (sPACblock.TimeOut(1)+sPACblock.TimeOut(end))/2;
                sPAC.TimeOut   = sPACblock.TimeOut + (meanInputTime - meanOutputTime);
            end
            % Copy block results to output structure
            sPAC.ValPAC(iSignals,:)      = sPACblock.ValPAC;
            sPAC.NestingFreq(iSignals,:) = sPACblock.NestingFreq;
            sPAC.NestedFreq(iSignals,:)  = sPACblock.NestedFreq;
            sPAC.PhasePAC(iSignals,:)    = sPACblock.PhasePAC;
            sPAC.DynamicPAC(iSignals,:,:,:)     = permute(sPACblock.DynamicPAC,[3,2,1]);
            sPAC.DynamicNesting(iSignals,:,:,:) = permute(sPACblock.DynamicNesting,[3,2,1]);
            sPAC.DynamicPhase(iSignals,:,:,:)   = permute(sPACblock.DynamicPhase,[3,2,1]);                    
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
                    sPAC.DynamicPhase   = (sPAC.DynamicPhase(1:2:end,:,:,:)   + sPAC.DynamicPhase(2:2:end,:,:,:))   / 2;
                    sInput.RowNames     = sInput.RowNames(1:2:end);
                case 3
                    sPAC.ValPAC         = (sPAC.ValPAC(1:3:end,:,:)           + sPAC.ValPAC(2:3:end,:,:)           + sPAC.ValPAC(3:3:end,:,:))           / 3;
                    sPAC.NestingFreq    = (sPAC.NestingFreq(1:3:end,:,:)      + sPAC.NestingFreq(2:3:end,:,:)      + sPAC.NestingFreq(3:3:end,:,:))      / 3;
                    sPAC.NestedFreq     = (sPAC.NestedFreq(1:3:end,:,:)       + sPAC.NestedFreq(2:3:end,:,:)       + sPAC.NestedFreq(3:3:end,:,:))       / 3;
                    sPAC.PhasePAC       = (sPAC.PhasePAC(1:3:end,:,:)         + sPAC.PhasePAC(2:3:end,:,:)         + sPAC.PhasePAC(3:3:end,:,:))         / 3;
                    sPAC.DynamicPAC     = (sPAC.DynamicPAC(1:3:end,:,:,:)     + sPAC.DynamicPAC(2:3:end,:,:,:)     + sPAC.DynamicPAC(3:3:end,:,:,:))     / 3;
                    sPAC.DynamicNesting = (sPAC.DynamicNesting(1:3:end,:,:,:) + sPAC.DynamicNesting(2:3:end,:,:,:) + sPAC.DynamicNesting(3:3:end,:,:,:)) / 3;
                    sPAC.DynamicPhase   = (sPAC.DynamicPhase(1:3:end,:,:,:)   + sPAC.DynamicPhase(2:3:end,:,:,:)   + sPAC.DynamicPhase(3:3:end,:,:,:))   / 3;
                    sInput.RowNames     = sInput.RowNames(1:3:end);
            end
        end

        % ===== SAVE FILE =====
        % Detect incomplete lists of sources
        isIncompleteResult = strcmpi(sInput.DataType, 'results') && (length(sInput.RowNames) * sInput.nComponents < nSignals);
        % Comment
        Comment = 'IRtPAC - ';
        
        if isfield(sProcess.options, 'coupling_type')
                switch(sProcess.options.coupling_type.Value)
                    case 1, 
                        if iscell(sSeedInput.RowNames)
                            Comment = [Comment, 'Modulator: #',sSeedInput.RowNames{1},', Modulated: '];
                        else
                            Comment = [Comment, 'Modulator: #',seedComment,', Modulated: '];
                        end
                    case 2,  
                        if iscell(sInput.RowNames)
                            Comment = [Comment, 'Modulated: #',sSeedInput.RowNames{1},', Modulator: '];
                        else
                            Comment = [Comment, 'Modulated: #',seedComment,', Modulator: '];%sProcess.options.seed_data.Value];                        
                        end
                end
            else
        end                    
        
        if iscell(sInput.RowNames)
            % Find the scout name
            scoutName = sInput.RowNames{1};
            k = strfind(scoutName,'.');               
            Comment = [Comment, scoutName(1:k-1)];            
        elseif (length(sInput.RowNames) == 1)
            Comment = [Comment, ' #', num2str(sInput.RowNames(1))];
        elseif isIncompleteResult
            Comment = [Comment, num2str(length(sInput.RowNames)), ' sources'];
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
                sPAC_avg.PhasePAC(:,:,:,nAvg+1)    =  sPAC.PhasePAC;
                sPAC_avg.DynamicPAC  = sPAC.DynamicPAC   ./ length(sInputsA);
                sPAC_avg.DynamicNesting(:,:,:,nAvg+1) = sPAC.DynamicNesting;
                sPAC_avg.DynamicPhase(:,:,:,nAvg+1)   =  sPAC.DynamicPhase;
                sPAC_avg.TimeOut     = sPAC.TimeOut;
                sPAC_avg.HighFreqs   = sPAC.HighFreqs;
            else
                sPAC_avg.ValPAC      = sPAC_avg.ValPAC      + sPAC.ValPAC      ./ length(sInputsA);
                sPAC_avg.NestingFreq = sPAC_avg.NestingFreq + sPAC.NestingFreq ./ length(sInputsA);
                sPAC_avg.NestedFreq  = sPAC_avg.NestedFreq  + sPAC.NestedFreq  ./ length(sInputsA);
                sPAC_avg.PhasePAC(:,:,:,nAvg+1)    =  sPAC.PhasePAC;
                sPAC_avg.DynamicPAC = sPAC_avg.DynamicPAC + sPAC.DynamicPAC    ./ length(sInputsA);                
                sPAC_avg.DynamicPhase(:,:,:,nAvg+1)   =  sPAC.DynamicPhase;
                sPAC_avg.DynamicNesting(:,:,:,nAvg+1)  = sPAC.DynamicNesting;                
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
    FileMat.Method    = 'tPAC';
    FileMat.Measure   = 'maxpac';
    FileMat.DataFile  = file_win2unix(DataFile);
    FileMat.nAvg      = nAvg;
    FileMat.Freqs     = 0;
    % All the PAC fields
    FileMat.sPAC = sPAC;%rmfield(sPAC, 'ValPAC');
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
    
%     % IF WE HAVE A SCOUT    
%     FileMat.DataType  = 'matrix';
%     % Row names
%     FileMat.RowNames = cellfun(@num2str, num2cell(sInput.RowNames), 'UniformOutput', false);
%     
%     % OTHERWISE:
%     FileMat.DataType  = sInput.DataType;
%     % Row names
%     FileMat.RowNames = sInput.RowNames;
    
    % Atlas 
    if ~isempty(sInput.Atlas)
        FileMat.Atlas = sInput.Atlas;
    end
    if ~isempty(sInput.SurfaceFile)
        FileMat.SurfaceFile = sInput.SurfaceFile;
    end
    % History: Computation
    FileMat = bst_history('add', FileMat, 'compute', 'IRPAC measure (see the field "Options" for input parameters)');
    % Save options in the file
    FileMat.Options = OPTIONS;
    
    % ===== SAVE FILE =====
    % Get output study
    sOutputStudy = bst_get('Study', iOuptutStudy);
    % File tag
%     if OPTIONS.isFullMaps
        fileTag = 'timefreq_dpac_fullmaps';
    % Output filename
    NewFile = bst_process('GetNewFilename', bst_fileparts(sOutputStudy.FileName), fileTag);
    % Save file
    bst_save(NewFile, FileMat, 'v6');
    % Add file to database structure
    db_add_data(iOuptutStudy, NewFile, FileMat);
end




% ===== COMPUTE PAC MEASURE =====
function sPAC = Compute(XinputA, XinputP, sRate, faBand, fpBand, winLen, Options)
%
% INPUTS:
%    - XinputA:       [nChannels,nTime] signal to process (signal for amplitude)
%    - XinputP:       [nChannels,nTime] signal to process (signal for phase) 
%    *  In local coupling estimation XinputA = XinputP
%    - sRate:         Sampling frequency (Hz)
%    - faBand:        Nested Band: Minimum and maximum frequency for extraction of frequency for amplitude
%    - fpBand:        Nesting Band: Minimum and maximum frequency for extraction of frequency for phase (Hz)
%    - winLen:        Length of each time window for coupling estimation(S) (default: 1 Sec)
%    - Options
%
% OUTPUTS:   sPAC structure [for each signal]
%    - TimeOut:        Output time vector (Sec)
%    - HighFreqs:       Frequency for amplitude vector
%    - ValPAC:         [nChannels, nTimeOut] Maximum PAC strength in each  time point
%    - NestedFreq:     [nChannels, nTimeOut] Fnested corresponding to maximum synchronization index in each time point
%    - NestingFreq:    [nChannels, nTimeOut] Fnesting corresponding to maximum synchronization index in each time point
%    - phasePAC:       [nChannels, nTimeOut] Phase corresponding to maximum
%                      synchronization index in each time point (rad)
%    - DynamicNesting: [nNestedCenters,nTimeOut,nChannels] Estimated nesting frequency (fP) for all times, channels and nested intervals
%    - DynamicPAC:     [nNestedCenters,nTimeOut,nChannels] full array of PAC
%    - DynamicPhase:   [nNestedCenters,nTimeOut,nChannels] Preferred phase
%                      of coupling for all times, channels and nested intervals (rad)
%
% DESCRIPTION:
%   Estimation of inter-regional Phase Amplitude Coupling (PAC) with tPAC method.
%
% Author:  Soheila Samiee, 2013-2017
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
sProcess_name = 'Process_pac_ir_dynamic';

if fpBand(2)>faBand(1)
    fpBand(2) = faBand(1)/2;
    error_msg = ['Maximum of Fp should be less than half of the minimum of Fa!' 10 10 ...
        'max{Fp} modified to ', num2str(fpBand(2))];
    bst_report('Error', sProcess_name, [], error_msg);
    disp(['Warning: ' error_msg]);    
end

if winLen < 1/fpBand(1)        
    error_msg = ['Window length is short for extracting this minimum fp!' 10 ...
        'Either increase window length to: ',num2str(2*1/fpBand(1)), ' or increase minimum fp to; ', num2str(2/winLen)];
    bst_report('Error', sProcess_name, [], error_msg);
    disp(['Warning: ' error_msg]); 
    winLen = 2*1/fpBand(1);
end

if ~size(XinputA)==size(XinputP)
    disp('Error in size of inputs')
    return
end

% Use the signal processing toolbox?
if bst_get('UseSigProcToolbox')
    hilbert_fcn = @hilbert;
else
    hilbert_fcn = @oc_hilbert;
end

% ===== SETTING THE PARAMETERS =====
tStep = winLen*(1-Options.overlap); % Time step for sliding window on time (Sec) (Overlap: 50%)
margin = Options.margin;                         % Margin (in time) for filtering (Sec) --- default: 2sec -> changed to 1 sec in May12,2016
hilMar = 1/5;                       % Percentage of margin for Hilber transform
bandNestingLen= max(2,1/(winLen+margin));                  % Length of band nesting (Hz)
isMirror = 0;                       % Mirroring the data in filtering
isRelax  = 1;                       % Attenuation of the filter in the stopband (1 => 40 dB, 0 => 60 dB)
minExtracFreq = max(1/winLen, fpBand(1));  % minimum frequency that could be extracted as nestingFreq

doInterpolation = Options.doInterpolation;  % Applying interpolation in frequency and time domain
logCenters = Options.logCenters;    % Choose the center frequencies for f_A with log space in faBand
nHighFreqs = Options.nHighFreqs;    % Number of high frequency centers
missedPcount = 0;
% mirrorEffectSample = 40;            % Number of samples that can be affected due to mirroring effect


% ==== ADDING MARGING TO THE DATA => AVOID EDGE ARTIFACT (FILTERS AND HILBERT TRANSFORM) ====
nMargin = fix(margin*sRate);
nHilMar = fix(nMargin*hilMar);
if Options.margin_included
    nTS = size(XinputA,2)-fix(2*Options.margin*sRate);               % Number of temporal samples of data
    
else
    nTS = size(XinputA,2);               % Number of temporal samples of data
    % Zero-padding of the data for the margin
    XinputA = [zeros(size(XinputA,1),nMargin), XinputA, zeros(size(XinputA,1),nMargin)];
    XinputP = [zeros(size(XinputP,1),nMargin), XinputP, zeros(size(XinputP,1),nMargin)];
end

if (nTS/sRate < winLen) && ~Options.margin_included
    error_msg = 'Data length should be at least twice of window length';
    bst_report('Error', sProcess_name, [], error_msg);
    disp(['Warning: ' error_msg]);
    sPAC = [];
    return
end


% ==== SETTING THE PARAMETERS OF THE FILTERS ====
if nHighFreqs > 1 %strcmp(Mode,'map')
    if logCenters
        nestedCenters = logspace(log10(faBand(1)),log10(faBand(end)),nHighFreqs);
    else
        nestedCenters = linspace(faBand(1),faBand(end),nHighFreqs);
    end    
    Fstep = diff(nestedCenters)/2;  % the range of frequency around each nested center
    Fstep = [Fstep(1),Fstep,Fstep(end)];
    Fstep = max(Fstep, fpBand(2));  % Minimum band width is defined to cover the whole interval between consecutive centre frequencies and at the same time consider all coupled frequencies to it in the range of interest.
    fArolloff = [];
else
    nestedCenters = mean(faBand);
    Fstep    = abs(faBand-nestedCenters);
    fArolloff = [];
end

fProlloff = [];          % roll off frequency for filteringsPAC.HighFreqs = nestedCenters;
nFa = length(nestedCenters);
nSources = size(XinputA,1);
isources = 1:nSources;
nTime = fix((nTS-fix(winLen*sRate))/fix(tStep*sRate))+1;
TimeOut = winLen/2 : tStep : winLen/2+(nTime-1)*tStep;        % seconds
PAC = zeros(nFa,nTime,nSources);                              % PAC measure
nestingFreq = zeros(nFa,nTime,nSources);
DynamicPhase= zeros(nFa,nTime,nSources);         

if nTime ==1
    doInterpolation = 0;
end

% ===== MAIN LOOP ON FA ===== 
for ifreq=1:nFa    
    % fA band
    bandNested = [nestedCenters(ifreq)-Fstep(ifreq),nestedCenters(ifreq)+Fstep(ifreq+1)];
    
    % Filtering in fA band
    Xnested = bst_bandpass_hfilter(XinputA, sRate,bandNested(1), bandNested(2), isMirror, isRelax, [], fArolloff);    % Filtering
    Xnested = Xnested(:,nMargin-nHilMar+1:end-nMargin+nHilMar);               % Removing part of the margin
    
    % Hilbert transform
    Z = hilbert_fcn(Xnested')';
    
    % Phase and envelope detection
    nestedEnv_total = abs(Z);                                              % Envelope of nested frequency rhythms
    nestedEnv_total = nestedEnv_total(:,nHilMar:end-nHilMar);              % Removing the margin
    
    % Sliding time window
    for iTime=1:nTime
        
        XP = XinputP(:, (iTime-1)*fix(tStep*sRate)+1:(iTime-1)*fix(tStep*sRate)+fix((2*margin+winLen)*sRate));
        nestedEnv = nestedEnv_total(:, (iTime-1)*fix(tStep*sRate)+(1:fix(winLen*sRate)));
        
        % Time vector and number of samples
        nSample = size(nestedEnv,2);
        nFreq = 2^ceil(log2(nSample)+1);
        
        % Fourier Transform of the fA's envelope
        Ffft = abs(fft(nestedEnv-repmat(mean(nestedEnv,2),1,nSample),nFreq,2)).^2/nSample;
        freq = linspace(0,sRate,nFreq);
 
        % Finding the corresponding frequency component
        ind = bst_closest([minExtracFreq, fpBand(2)], freq);
        % Removing the points that are outside the range of interest
        if ind(1)<fpBand(1)
            ind(1) = ind(1)+1;
        end
        if ind(2)>fpBand(2)
            ind(2) = ind(2)-1;
        end
        
        % Adding one point to the beginning and the end of interval to give the algorithm 
        % to find the local peaks even if they are in the first and last 
        % point of interst in the spectrum
        if ind(1)>1
            ind(1) = ind(1)-1;
        end
        ind(2) = ind(2)+1;
        
        if freq(ind(1))<(minExtracFreq-diff(freq(1:2)))
            ind(1) = ind(1)+1;
        end
        
        % Finding power spectrum of the fP signal
        x1 = XP(:,nMargin+1:nMargin+fix(winLen*sRate));
        FfftSig = abs(fft(x1-repmat(mean(x1,2),1,nSample),nFreq,2)).^2/nSample;

        % Extracting the dominant peak of the PSD
        indm = zeros(nSources,1);
        for iSource=1:nSources
            % Extracting the peak from envelope's PSD and then confirming 
            % with a peak on the original signal
            if bst_get('UseSigProcToolbox')
                [pks_env,locs_env] = findpeaks(Ffft(iSource,ind(1):ind(2)),'SORTSTR','descend');
                [pks_orig, locs_orig] = findpeaks(FfftSig(iSource,ind(1):ind(2)),'SORTSTR','descend');  % To check if a peak close to the coupled fp is available in the original signal
            else
                [locs_env, pks_env] = peakseek(Ffft(iSource,ind(1):ind(2)));
                [locs_orig, pks_orig] = peakseek(FfftSig(iSource,ind(1):ind(2)));  % To check if a peak close to the coupled fp is available in the original signal
                % Sort peaks in descending order
                [pks_env, I] = sort(pks_env, 'descend');
                locs_env = locs_env(I);
                [pks_orig, I] = sort(pks_orig, 'descend');
                locs_orig = locs_orig(I);
            end
            
            % Ignore small peaks
            pks_orig = pks_orig/max(pks_orig);
            locs_orig = locs_orig(pks_orig>0.1);

            
            % Confirming the peak
            max_dist = max(1.5/winLen,1.5);     % maximum acceptable distance between peaks in evelope and the original signal's PSD
            count = 1;
            check_pks = 1;
            fp_loc = [];
            while check_pks && count<length(locs_env) && ~isempty(locs_orig) 
                index = bst_closest(freq(locs_env(count)), freq(locs_orig));                                
                if freq(locs_orig(index))-freq(locs_env(count))<=max_dist                    
                    fp_loc = locs_env(count);
                    check_pks = 0;
                else
                    count = count+1;
                end
            end            
            % If peak is not approved or no peak
            if isempty(fp_loc)
                fp_loc = ind(2)-ind(1)+1;    % arbitrary value for fp  ==> will set the pac value to zero              
                missedPcount = missedPcount +1;
            end                        
            
            indm(iSource) = fp_loc(1);
            clear pks_env locs_env
        end
        
        nestingFreq(ifreq,iTime,isources) = freq(ind(1)+indm-1);     
        bandNesting = [max([squeeze(nestingFreq(ifreq,iTime,isources))-bandNestingLen/2,zeros(size(nestingFreq,3),1)],[],2),...
            squeeze(nestingFreq(ifreq,iTime,isources))+bandNestingLen/2];
        bandNesting(bandNesting<.15)=.15;
        
        % Filtering in nesting band
        if length(unique(bandNesting(:,1)))==1 && length(unique(bandNesting(:,2)))==1
            Xnesting = bst_bandpass_hfilter(XP, sRate,bandNesting(1,1), bandNesting(1,2), isMirror, isRelax, [], fProlloff);    % Filtering
        else
            Xnesting = zeros(size(XP));
            for i=1:length(isources)
                Xnesting(i,:) = bst_bandpass_hfilter(XP(i,:), sRate, bandNesting(i,1), bandNesting(i,2),isMirror, isRelax, [], fProlloff);    % Filtering
            end
        end        
        Xnesting = Xnesting(:,nMargin-nHilMar+1:fix((margin+winLen)*sRate)+nHilMar);              % Removing part of the margin        
        % Hilbert transform
        Z = hilbert_fcn(Xnesting')';        
        % Phase detection
        nestingPh = angle(Z-repmat(mean(Z,2),1,size(Z,2)));    % Phase of nesting frequency        
        nestingPh = nestingPh(:,nHilMar:fix(winLen*sRate)+nHilMar-1);              % Removing the margin
                
        for ii=1:length(isources)
            iphase = find(diff(sign(nestingPh(ii,:) - nestingPh(ii,1)))==2 | ...
                     sign(nestingPh(ii,2:end)-nestingPh(ii,1))==0)-1;

%             iphase = find(diff(sign(nestingPh(ii,:) - nestingPh(ii,1)))==-2 | ...
%                      sign(nestingPh(ii,2:end)-nestingPh(ii,1))==0 | ...
%                     -(diff(sign(nestingPh(ii,:) - nestingPh(ii,1)))-1).*diff(nestingPh(ii,:)-nestingPh(ii,1)) >6 )-1;
            if isempty(iphase)
                iphase = length(nestingPh(ii,:));
            end
            PAC(ifreq,iTime,isources(ii)) = sum(nestedEnv(ii,1:max(iphase)).*exp(1i*nestingPh(ii,1:max(iphase))),2)...
                ./max(iphase)./sqrt(mean(nestedEnv(ii,1:max(iphase)).^2,2));
            
            if indm(ii)==ind(2)-ind(1)+1 % Fp not confirmed and arbitrary value for fp
                PAC(ifreq,iTime,isources(ii)) = 0;
            end
            DynamicPhase(ifreq,iTime,isources(ii)) = angle(PAC(ifreq,iTime,isources(ii)));

        end
        
    end
end

% ===== EXTRACTING THE PAC RELATED VALUES ===== %
[tmp,maxInd] = max(abs(PAC),[],1); clear tmp
Fnested  = reshape(squeeze(nestedCenters(maxInd)),nTime,nSources)';
Sind     = repmat((1:nSources)', 1, nTime);           % Source indices
Tind     = repmat(1:nTime, nSources, 1);              % Time indices
linInd   = sub2ind(size(PAC),maxInd(:),Tind(:),Sind(:));
Fnesting = reshape(nestingFreq(linInd),nTime,nSources)';
Phase    = reshape(angle(PAC(linInd)),nTime,nSources)';
PACmax   = reshape(abs(PAC(linInd)),nTime,nSources)';


% ===== Interpolation in time domain for smoothing the results ==== %
if doInterpolation
    % Interpolation of PAC
    if nSources>1
        [X,Y,Z] = meshgrid(TimeOut,nestedCenters,[1:nSources]);
        nx = linspace(TimeOut(1), TimeOut(end), 2*nTime-1);
        ny = linspace(nestedCenters(1), nestedCenters(end), 2*nFa-1);
        [nX,nY,nZ] = meshgrid(nx,ny,[1:nSources]);
        PAC = interp3(X,Y,Z,abs(PAC),nX,nY,nZ,'linear',0);
    else
        [X,Y] = meshgrid(TimeOut,nestedCenters);
        nx = linspace(TimeOut(1), TimeOut(end), 2*nTime-1);
        ny = linspace(nestedCenters(1), nestedCenters(end), 2*nFa-1);
        [nX,nY] = meshgrid(nx,ny);
        PAC = interp2(X,Y,abs(PAC(:,:,1)),nX,nY,'linear',0);
    end
    TimeOut = nx;
    sPAC.HighFreqs = ny;
    clear nx nX nY nZ X Y Z
    
    % Phase
    tmp = zeros(nSources, nTime*2-1);
    tmp(:, 1:2:end) = Phase;
    tmp(:, 2:2:end) = Phase(:,1:end-1);
    Phase = tmp; 
    
    % nestingFreq
    tmp = zeros(nFa*2-1, nTime, nSources);
    tmp(1:2:end,:,:) = nestingFreq;
    tmp(2:2:end,:,:) = nestingFreq(1:end-1,:,:);
    tmp2 = zeros(nFa*2-1, nTime*2-1, nSources);
    tmp2(:,1:2:end,:) = tmp;
    tmp2(:,2:2:end,:) = tmp(:,1:end-1,:);
    nestingFreq = tmp2; 
    clear tmp tmp2    
    
    % DynamicPhase
    tmp = zeros(nFa*2-1, nTime, nSources);
    tmp(1:2:end,:,:) = DynamicPhase;
    tmp(2:2:end,:,:) = DynamicPhase(1:end-1,:,:);
    tmp2 = zeros(nFa*2-1, nTime*2-1, nSources);
    tmp2(:,1:2:end,:) = tmp;
    tmp2(:,2:2:end,:) = tmp(:,1:end-1,:);
    DynamicPhase = tmp2; 
    clear tmp tmp2
    
    % nesting frequency, nested frequency and PACmax
    [PACmax,maxInd] = max(abs(PAC),[],1); 
    Fnested  = squeeze(ny(maxInd))';
    Sind     = repmat(1:nSources, nTime*2-1, 1);           % Source indices
    Tind     = repmat((1:nTime*2-1)', 1, nSources);        % Time indices
    linInd   = sub2ind(size(PAC),maxInd(:),Tind(:),Sind(:));
    Fnesting = reshape(nestingFreq(linInd),nTime*2-1,nSources)';
    PACmax   = squeeze(PACmax)';  
else
    sPAC.HighFreqs = nestedCenters;
end

if missedPcount>0
disp(['Missed Peaks:',num2str(missedPcount),'/',num2str(nFa*nTime*nSources)])
end

% ===== OUTPUTS ===== %
if nTime >1
    sPAC.ValPAC = PACmax;
    sPAC.NestingFreq = Fnesting;
    sPAC.NestedFreq  = Fnested;
    sPAC.PhasePAC = Phase;
    sPAC.TimeOut  = TimeOut;
    sPAC.DynamicPAC(:,:,1:nSources) = abs(PAC);
    sPAC.DynamicNesting(:,:,1:nSources)  = nestingFreq;
    sPAC.DynamicPhase(:,:,1:nSources)  = DynamicPhase;
    
        % == Generating two time points for Brainstorm structure ==
else        
    sPAC.ValPAC = [PACmax(:), PACmax(:)];
    sPAC.NestingFreq = [Fnesting(:), Fnesting(:)];
    sPAC.NestedFreq  = [Fnested(:), Fnested(:)];
    sPAC.PhasePAC = [Phase(:), Phase(:)];
    sPAC.TimeOut  = [TimeOut, TimeOut+0.001];
    sPAC.DynamicPAC(:,1:2,1:nSources) = repmat(abs(PAC),[1,2,1]);
    sPAC.DynamicNesting(:,1:2,1:nSources)  = repmat(abs(nestingFreq),[1,2,1]);
    sPAC.DynamicPhase(:,1:2,1:nSources)  = repmat(abs(DynamicPhase),[1,2,1]);
end  

end


