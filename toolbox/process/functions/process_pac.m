function varargout = process_pac( varargin )
% PROCESS_PAC: Compute the Phase-Amplitude Coupling in one of several time series (directPAC)
%
% DOCUMENTATION:  For more information, please refer to the method described in the following article
%    Özkurt TE, Schnitzler A, J Neurosci Methods. 2011 Oct 15;201(2):438-43
%    "A critical note on the definition of phase-amplitude cross-frequency coupling"

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
% Authors: Esther Florin, Sylvain Baillet, 2010-2012
%          Francois Tadel, 2013-2014

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Phase-amplitude coupling';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Frequency';
    sProcess.Index       = 660;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/TutPac#PAC_estimation';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw',      'data',     'results',  'matrix'};
    sProcess.OutputTypes = {'timefreq', 'timefreq', 'timefreq', 'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    % ==== INPUT ====
    sProcess.options.label_in.Comment = '<B><U>Input options</U></B>:';
    sProcess.options.label_in.Type    = 'label';
    % === TIME WINDOW
    sProcess.options.timewindow.Comment = 'Time window:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    % === SENSOR SELECTION
    sProcess.options.target_data.Comment    = 'Sensor types or names (empty=all): ';
    sProcess.options.target_data.Type       = 'text';
    sProcess.options.target_data.Value      = 'MEG, EEG';
    sProcess.options.target_data.InputTypes = {'data', 'raw'};
    % === SCOUTS SELECTION
    sProcess.options.scouts.Comment    = 'Use scouts';
    sProcess.options.scouts.Type       = 'scout_confirm';
    sProcess.options.scouts.Value      = {};
    sProcess.options.scouts.InputTypes = {'results'};
    % === SCOUT FUNCTION ===
    sProcess.options.scoutfunc.Comment    = {'Mean', 'Max', 'PCA', 'Std', 'All', 'Scout function:'};
    sProcess.options.scoutfunc.Type       = 'radio_line';
    sProcess.options.scoutfunc.Value      = 1;
    sProcess.options.scoutfunc.InputTypes = {'results'};
    % === SCOUT TIME ===
    sProcess.options.scouttime.Comment    = {'Before', 'After', 'When to apply the scout function:'};
    sProcess.options.scouttime.Type       = 'radio_line';
    sProcess.options.scouttime.Value      = 1;
    sProcess.options.scouttime.InputTypes = {'results'};
    % === ROW NAMES
    sProcess.options.target_tf.Comment    = 'Row names or indices (empty=all): ';
    sProcess.options.target_tf.Type       = 'text';
    sProcess.options.target_tf.Value      = '';
    sProcess.options.target_tf.InputTypes = {'timefreq', 'matrix'};
    % Ignore bad segments
    sProcess.options.ignorebad.Comment    = 'Exclude bad segments and bad channels<BR><FONT color="#707070"><I>(Risks of dimensions mismatch when averaging multiple files)</I></FONT>';
    sProcess.options.ignorebad.Type       = 'checkbox';
    sProcess.options.ignorebad.Value      = 1;
    sProcess.options.ignorebad.InputTypes = {'data', 'raw'};

    % ==== ESTIMATOR ====
    sProcess.options.label_pac.Comment = '<BR><B><U>Estimator options</U></B>:';
    sProcess.options.label_pac.Type    = 'label';
    % === NESTING FREQ
    sProcess.options.nesting.Comment = 'Nesting frequency band (low):';
    sProcess.options.nesting.Type    = 'range';
    sProcess.options.nesting.Value   = {[2, 30], 'Hz', 2};
    % === NESTED FREQ
    sProcess.options.nested.Comment = 'Nested frequency band (high):';
    sProcess.options.nested.Type    = 'range';
    sProcess.options.nested.Value   = {[40, 150], 'Hz', 2};
    % === NESTED FREQ
    sProcess.options.numfreqs.Comment = 'Total number of frequency bins (0=default):';
    sProcess.options.numfreqs.Type    = 'value';
    sProcess.options.numfreqs.Value   = {0, ' ', 0};
    
    % ==== LOOP ====
    sProcess.options.label_loop.Comment = '<BR><B><U>Loop options [expert only]</U></B>:';
    sProcess.options.label_loop.Type    = 'label';
    % === Parallel processing
    sProcess.options.parallel.Comment = 'Use the parallel processing toolbox';
    sProcess.options.parallel.Type    = 'checkbox';
    sProcess.options.parallel.Value   = 0;
    if ~exist('matlabpool', 'file') && ~exist('parpool', 'file')
        sProcess.options.parallel.Hidden = 1;
    end
    % === USE MEX
    sProcess.options.ismex.Comment = 'Use compiled mex-files (may crash on some computers)';
    sProcess.options.ismex.Type    = 'checkbox';
    sProcess.options.ismex.Value   = 1;
    % === MAX_BLOCK_SIZE
    sProcess.options.max_block_size.Comment = 'Number of signals to process at once: ';
    sProcess.options.max_block_size.Type    = 'value';
    sProcess.options.max_block_size.Value   = {1, ' ', 0};

    % ==== OUTPUT ====
    sProcess.options.label_out.Comment = '<BR><U><B>Output configuration</B></U>:';
    sProcess.options.label_out.Type    = 'label';
    % === AVERAGE OUTPUT FILES
    sProcess.options.avgoutput.Comment = 'Save average PAC across trials (one output file only)';
    sProcess.options.avgoutput.Type    = 'checkbox';
    sProcess.options.avgoutput.Value   = 0;
    % === SAVE PAC MAPS
    sProcess.options.savemax.Comment = 'Save only the maximum PAC values';
    sProcess.options.savemax.Type    = 'checkbox';
    sProcess.options.savemax.Value   = 0;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputA) %#ok<DEFNU>
    OutputFiles = {};
    
    % ===== GET OPTIONS =====
    if isfield(sProcess.options, 'timewindow') && isfield(sProcess.options.timewindow, 'Value') && iscell(sProcess.options.timewindow.Value) && ~isempty(sProcess.options.timewindow.Value)
        OPTIONS.TimeWindow = sProcess.options.timewindow.Value{1};
    else
        OPTIONS.TimeWindow = [];
    end
    % Get and check frequencies
    OPTIONS.BandNesting = sProcess.options.nesting.Value{1};
    OPTIONS.BandNested  = sProcess.options.nested.Value{1};
    if (min(OPTIONS.BandNesting) < 0.5)
        bst_report('Error', sProcess, [], 'This function cannot be used to estimate PAC for nesting frequencies below 1Hz.');
        return;
    end
    if (max(OPTIONS.BandNesting) > min(OPTIONS.BandNested))
        bst_report('Error', sProcess, [], 'The low and high frequency band cannot overlap.');
        return;
    end
    % Get target
    if ismember(sInputA(1).FileType, {'data','raw'}) && isfield(sProcess.options, 'target_data') && ~isempty(sProcess.options.target_data.Value)
        OPTIONS.Target = sProcess.options.target_data.Value;
    elseif ismember(sInputA(1).FileType, {'timefreq', 'matrix'}) && isfield(sProcess.options, 'target_tf') && ~isempty(sProcess.options.target_tf.Value)
        OPTIONS.Target = sProcess.options.target_tf.Value;
    else
        OPTIONS.Target = [];
    end
    % Ignore bad segments
    if ismember(sInputA(1).FileType, {'data','raw'}) && isfield(sProcess.options, 'ignorebad') && ~isempty(sProcess.options.ignorebad.Value)
        OPTIONS.isIgnoreBad = sProcess.options.ignorebad.Value;
    else
        OPTIONS.isIgnoreBad = [];
    end
    % All other options
    OPTIONS.NumFreqs     = sProcess.options.numfreqs.Value{1};
    OPTIONS.MaxSignals   = sProcess.options.max_block_size.Value{1};
    OPTIONS.isParallel   = sProcess.options.parallel.Value && ((exist('matlabpool', 'file') ~= 0) || (exist('parpool', 'file') ~= 0));
    OPTIONS.isMex        = sProcess.options.ismex.Value;
    OPTIONS.isSaveMax    = sProcess.options.savemax.Value;
    OPTIONS.isAvgOutput  = sProcess.options.avgoutput.Value;
    if (length(sInputA) == 1)
        OPTIONS.isAvgOutput = 0;
    end

    % ===== GET SCOUTS OPTIONS =====
    if strcmpi(sInputA(1).FileType, 'results') && isfield(sProcess.options, 'scouts') && isfield(sProcess.options.scouts, 'Value')
        % Override scouts function
        switch (sProcess.options.scoutfunc.Value)
            case 1, OPTIONS.ScoutFunc = 'mean';
            case 2, OPTIONS.ScoutFunc = 'max';
            case 3, OPTIONS.ScoutFunc = 'pca';
            case 4, OPTIONS.ScoutFunc = 'std';
            case 5, OPTIONS.ScoutFunc = 'all';
        end
        % Scout function order
        switch (sProcess.options.scouttime.Value)
            case 1, OPTIONS.ScoutTime = 'before';
            case 2, OPTIONS.ScoutTime = 'after';
        end
        % Perform some checks
        if strcmpi(OPTIONS.ScoutTime, 'before') && ismember(OPTIONS.ScoutFunc, {'max', 'std'})
            bst_report('Error', sProcess, [], 'Scout functions MAX and STD should not be applied before estimating the PAC.');
            return;
        end
        if strcmpi(OPTIONS.ScoutTime, 'after') && strcmpi(OPTIONS.ScoutFunc, 'pca')
            bst_report('Error', sProcess, [], 'Scout function PCA cannot be applied after estimating the PAC.');
            return;
        end
        % Selected scouts
        AtlasList = sProcess.options.scouts.Value;
        % Set input/output scouts functions
        if ~isempty(AtlasList)
            OPTIONS.Target = AtlasList;
            % Apply function before: get all the scouts time series in advance
            if strcmpi(OPTIONS.ScoutTime, 'before')
                LoadOptions.TargetFunc = OPTIONS.ScoutFunc;
            % Apply function after: Get all the time series of all the scouts
            elseif strcmpi(OPTIONS.ScoutTime, 'after')
                LoadOptions.TargetFunc = 'all';
            end
        end
    end
    
    % ===== INITIALIZE =====
    % Initialize output variables
    DirectPAC_avg = [];
    LowFreqs  = [];
    HighFreqs = [];
    nAvg = 0;
    % Initialize progress bar
    if bst_progress('isVisible')
        startValue = bst_progress('get');
    else
        startValue = 0;
    end
    % Options for LoadInputFile()
    if strcmpi(sInputA(1).FileType, 'results')
        LoadOptions.LoadFull = 0;  % Load kernel-based results as kernel+data
    else
        LoadOptions.LoadFull = 1;  % Load the full file
    end
    LoadOptions.IgnoreBad   = OPTIONS.isIgnoreBad;  % Ignore the bad segments and bad channels from recordings
    LoadOptions.ProcessName = func2str(sProcess.Function);
    
    % Loop over input files
    for iFile = 1:length(sInputA)
        % ===== LOAD SIGNALS =====
        bst_progress('text', sprintf('PAC: Loading input file (%d/%d)...', iFile, length(sInputA)));
        bst_progress('set', round(startValue + (iFile-1) / length(sInputA) * 100));
        % Load input signals 
        [sInput, nSignals, iRows] = bst_process('LoadInputFile', sInputA(iFile).FileName, OPTIONS.Target, OPTIONS.TimeWindow, LoadOptions);
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
            bst_report('Warning', 'process_pac', [], strMsg);
            % Fix higher frequencyy
            OPTIONS.BandNested(2) = sRate/3;
        end
        % Check the extent of bandNested band
        if (OPTIONS.BandNested(2) <= OPTIONS.BandNested(1))
            bst_report('Error', 'process_pac', [], sprintf('Invalid frequency range: %d-%d Hz', round(OPTIONS.BandNested(1)), round(OPTIONS.BandNested(2))));
            continue;
        end

        % ===== COMPUTE PAC MEASURE =====
        % Number of blocks of signals
        MAX_BLOCK_SIZE = OPTIONS.MaxSignals;
        nBlocks = ceil(nSignals / MAX_BLOCK_SIZE);
        DirectPAC = [];
        % Display processing time
        disp(sprintf('BST> PAC: Processing %d blocks of %d signals each.', nBlocks, MAX_BLOCK_SIZE));
        % Process each block of signals
        for iBlock = 1:nBlocks
            tic
            bst_progress('text', sprintf('PAC: File %d/%d - Block %d/%d', iFile, length(sInputA), iBlock, nBlocks));
            bst_progress('set', round(startValue + (iFile-1)/length(sInputA)*100 + iBlock/nBlocks*100));    
            % Indices of the signals
            iSignals = (iBlock-1)*MAX_BLOCK_SIZE+1 : min(iBlock*MAX_BLOCK_SIZE, nSignals);
            % Get signals to process
            if ~isempty(sInput.ImagingKernel)
                Fblock = sInput.ImagingKernel(iSignals,:) * sInput.Data;
            else
                Fblock = sInput.Data(iSignals,:);
            end
            [DirectPAC_block, LowFreqs, HighFreqs] = bst_pac(Fblock, sRate, OPTIONS.BandNesting, OPTIONS.BandNested, OPTIONS.isParallel, OPTIONS.isMex, OPTIONS.NumFreqs);
            % Initialize output variable
            if isempty(DirectPAC)
                DirectPAC = zeros(nSignals, 1, size(DirectPAC_block,3), size(DirectPAC_block,4));
            end
            % Copy block results to output variable [nSignals, nTime=1, nNestingFreqs, nNestedFreqs]
            DirectPAC(iSignals,:,:,:) = DirectPAC_block;
            % Display processing time
            % disp(sprintf('Block #%d/%d: %fs', iBlock, nBlocks, toc));
        end
                
        % ===== APPLY SOURCE ORIENTATION =====
        % Unconstrained sources => SUM for each point
        if ismember(sInput.DataType, {'results','scout','matrix'}) && ~isempty(sInput.nComponents) && (sInput.nComponents ~= 1)
            [DirectPAC, sInput.GridAtlas, sInput.RowNames] = bst_source_orient([], sInput.nComponents, sInput.GridAtlas, DirectPAC, 'mean', sInput.DataType, sInput.RowNames);
        end
        
        % ===== PROCESS SCOUTS =====
        % Get scouts
        isScout = ~isempty(OPTIONS.Target) && (isstruct(OPTIONS.Target) || iscell(OPTIONS.Target)) && isfield(sInput, 'Atlas') && isfield(sInput.Atlas, 'Scouts') && ~isempty(sInput.Atlas.Scouts);    
        if isScout
            sScouts = sInput.Atlas.Scouts;
        end
        % If the scout function has to be applied AFTER the PAC computation
        if isScout && strcmpi(OPTIONS.ScoutTime, 'after') && ~strcmpi(OPTIONS.ScoutFunc, 'all')
            nScouts = length(sScouts);
            DirectPAC_scouts = zeros(nScouts, size(DirectPAC,2), size(DirectPAC,3), size(DirectPAC,4));
            iVerticesAll = [1, cumsum(cellfun(@length, {sScouts.Vertices})) + 1];
            % For each unique row name: compute a measure over the clusters values
            for iScout = 1:nScouts
                iScoutVert = iVerticesAll(iScout):iVerticesAll(iScout+1)-1;
                F = reshape(DirectPAC(iScoutVert,:,:,:), length(iScoutVert), []);
                F = bst_scout_value(F, OPTIONS.ScoutFunc);
                DirectPAC_scouts(iScout,:,:,:) = reshape(F, [1, size(DirectPAC,2), size(DirectPAC,3), size(DirectPAC,4)]);
            end
            % Save only the requested rows
            sInput.RowNames = {sScouts.Label};
            DirectPAC = DirectPAC_scouts;
        end
        
        % ===== FILE COMMENT =====
        % Base comment
        if OPTIONS.isSaveMax
            Comment = 'MaxPAC';
        else
            Comment = 'PAC';
        end
        % Time window (RAW only)
        if ~isempty(strfind(sInputA(iFile).Condition, '@raw'))
            Comment = [Comment, sprintf('(%ds-%ds)', round(OPTIONS.TimeWindow))];
        end
        % Scouts
        if isScout && (length(sScouts) < 6)
            Comment = [Comment, ':'];
            for is = 1:length(sScouts)
                Comment = [Comment, ' ', sScouts(is).Label];
            end
            Comment = [Comment, ', ', OPTIONS.ScoutFunc];
            if ~strcmpi(OPTIONS.ScoutFunc, 'All')
                 Comment = [Comment, ' ' OPTIONS.ScoutTime];
            end
        % Single input
        elseif (length(sInput.RowNames) == 1)
            if iscell(sInput.RowNames)
                Comment = [Comment, ': ' sInput.RowNames{1}];
            else
                Comment = [Comment, ': #', num2str(sInput.RowNames(1))];
            end
        end
        
        % ===== SAVE FILE / COMPUTE AVERAGE =====
        % Save each as an independent file
        if ~OPTIONS.isAvgOutput
            nAvg = 1;
            OutputFiles{end+1} = SaveFile(DirectPAC, LowFreqs, HighFreqs, nAvg, sInput.iStudy, sInputA(iFile).FileName, sInput, Comment, OPTIONS);
        else
            % Compute online average of the connectivity matrices
            if isempty(DirectPAC_avg)
                DirectPAC_avg = DirectPAC ./ length(sInputA);
            else
                DirectPAC_avg = DirectPAC_avg + DirectPAC ./ length(sInputA);
            end
            nAvg = nAvg + 1;
        end
    end

    % ===== SAVE AVERAGE =====
    if OPTIONS.isAvgOutput
        % Output study, in case of average
        [tmp, iOutputStudy] = bst_process('GetOutputStudy', sProcess, sInputA);
        % Save file
        OutputFiles{1} = SaveFile(DirectPAC_avg, LowFreqs, HighFreqs, nAvg, iOutputStudy, [], sInput, Comment, OPTIONS);
    end
end


%% ========================================================================
%  ===== SUPPORT FUNCTIONS ================================================
%  ========================================================================

%% ===== SAVE FILE =====
function NewFile = SaveFile(DirectPAC, LowFreqs, HighFreqs, nAvg, iOuptutStudy, DataFile, sInput, Comment, OPTIONS)
    % ===== COMPUTE MAXPAC ======
    % Save directPAC values in returned structure only if requested
    if OPTIONS.isSaveMax
        sPAC.DirectPAC = [];
    else        
        sPAC.DirectPAC = DirectPAC;
    end
    % Get the maximum DirectPAC value for each signal
    [sPAC.ValPAC, indmax] = max(reshape(DirectPAC, size(DirectPAC,1), []), [], 2);
    % Find the pair of low/high frequencies for this maximum
    [imaxl, imaxh]   = ind2sub([size(DirectPAC,3), size(DirectPAC,4)], indmax);
    sPAC.NestingFreq = LowFreqs(imaxl)';
    sPAC.NestedFreq  = HighFreqs(imaxh)';
    % Copy list of frequencies 
    sPAC.LowFreqs  = LowFreqs;
    sPAC.HighFreqs = HighFreqs;

    % ===== PREPARE OUTPUT STRUCTURE =====
    % Create file structure
    FileMat = db_template('timefreqmat');
    FileMat.TF        = sPAC.ValPAC;
    FileMat.Comment   = Comment;
    FileMat.DataType  = sInput.DataType;
    FileMat.RowNames  = sInput.RowNames;
    FileMat.Time      = sInput.Time([1,end]);
    FileMat.Method    = 'pac';
    FileMat.Measure   = 'maxpac';
    FileMat.DataFile  = file_win2unix(DataFile);
    FileMat.nAvg      = nAvg;
    FileMat.Freqs     = 0;
    % Atlas 
    if ~isempty(sInput.Atlas)
        FileMat.Atlas = sInput.Atlas;
    end
    if ~isempty(sInput.GridLoc)
        FileMat.GridLoc = sInput.GridLoc;
    end
    if ~isempty(sInput.GridAtlas)
        FileMat.GridAtlas = sInput.GridAtlas;
    end
    if ~isempty(sInput.SurfaceFile)
        FileMat.SurfaceFile = sInput.SurfaceFile;
    end
    % History: Computation
    FileMat = bst_history('add', FileMat, 'compute', 'PAC measure (see the field "Options" for input parameters)');
    % All the PAC fields and options
    FileMat.Options = OPTIONS;
    FileMat.sPAC    = rmfield(sPAC, 'ValPAC');
    
    % ===== SAVE FILE =====
    % Get output study
    sOutputStudy = bst_get('Study', iOuptutStudy);
    % File tag
    if OPTIONS.isSaveMax
        fileTag = 'timefreq_pac';
    else
        fileTag = 'timefreq_pac_fullmaps';
    end
    % Output filename
    NewFile = bst_process('GetNewFilename', bst_fileparts(sOutputStudy.FileName), fileTag);
    % Save file
    bst_save(NewFile, FileMat, 'v6');
    % Add file to database structure
    db_add_data(iOuptutStudy, NewFile, FileMat);
end




