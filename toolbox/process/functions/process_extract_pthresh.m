function varargout = process_extract_pthresh( varargin )
% PROCESS_EXTRACT_PTHRESH Apply a statistical threshold to a stat file.
%
% USAGE:  OutputFiles = process_extract_pthresh('Run', sProcess, sInput)
%           threshmap = process_extract_pthresh('Compute', StatMat, StatThreshOptions)

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
% Authors: Francois Tadel, 2013-2019
%          Thomas Vincent, 2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Apply statistic threshold';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Test';
    sProcess.Index       = 711;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Statistics#Convert_statistic_results_to_regular_files';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.OutputTypes = {'data',  'results',  'timefreq',  'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Define options
    sProcess = DefineOptions(sProcess);
end


%% ===== DEFINE OPTIONS =====
function sProcess = DefineOptions(sProcess)
    % === P-VALUE THRESHOLD
    sProcess.options.pthresh.Comment = 'Significance level &alpha;: ';
    sProcess.options.pthresh.Type    = 'value';
    sProcess.options.pthresh.Value   = {0.05,'',4};
    % === DURATION THRESHOLD
    sProcess.options.durthresh.Comment = 'Minimum duration (ms): ';
    sProcess.options.durthresh.Type    = 'value';
    sProcess.options.durthresh.Value   = {0,'',0};
    % === CORRECTION
    sProcess.options.label1.Comment = '<BR>Correction for multiple comparisons:';
    sProcess.options.label1.Type    = 'label';
    sProcess.options.correction.Comment = {'Uncorrected', 'Bonferroni', 'False discovery rate (FDR)'};
    sProcess.options.correction.Type    = 'radio';
    sProcess.options.correction.Value   = 1;
    % === CONTROL 
    sProcess.options.label2.Comment = '<BR>Contol over dimensions:';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.control1.Comment = '1: Signals';
    sProcess.options.control1.Type    = 'checkbox';
    sProcess.options.control1.Value   = 1;
    sProcess.options.control2.Comment = '2: Time';
    sProcess.options.control2.Type    = 'checkbox';
    sProcess.options.control2.Value   = 1;
    sProcess.options.control3.Comment = '3: Frequency';
    sProcess.options.control3.Type    = 'checkbox';
    sProcess.options.control3.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % Get options
    [StatThreshOptions, strCorrect] = GetOptions(sProcess);
    % Final process string
    Comment = [sProcess.Comment ': ' strCorrect];
end


%% ===== GET OPTIONS =====
function [StatThreshOptions, strCorrect] = GetOptions(sProcess)
    % Get threshold
    StatThreshOptions.pThreshold = sProcess.options.pthresh.Value{1};
    StatThreshOptions.durThreshold = sProcess.options.durthresh.Value{1} / 1000;
    % Get controlled dimensions
    StatThreshOptions.Control = [];
    if (sProcess.options.control1.Value == 1)
        StatThreshOptions.Control(end+1) = 1;
    end
    if (sProcess.options.control2.Value == 1)
        StatThreshOptions.Control(end+1) = 2;
    end
    if (sProcess.options.control3.Value == 1)
        StatThreshOptions.Control(end+1) = 3;
    end
    % Get type of correction
    switch (sProcess.options.correction.Value)
        case 1
            strCorrect = '';
            StatThreshOptions.Correction = 'no';
        case 2
            strCorrect = ' (Bonferroni:';
            StatThreshOptions.Correction = 'bonferroni';
        case 3
            strCorrect = ' (FDR:';
            StatThreshOptions.Correction = 'fdr';
    end
    % Format string for correction
    if isempty(strCorrect) || isempty(StatThreshOptions.Control)
        strCorrect = '';
    else
        for i = 1:length(StatThreshOptions.Control)
            if (i == length(StatThreshOptions.Control))
                strCorrect = [strCorrect, num2str(StatThreshOptions.Control(i)), ')'];
            else
                strCorrect = [strCorrect, num2str(StatThreshOptions.Control(i)), ','];
            end
        end
    end
    % Final process string
    strCorrect = ['alpha=' num2str(StatThreshOptions.pThreshold) strCorrect];
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput) %#ok<DEFNU>
    % Get options
    [StatThreshOptions, strCorrect] = GetOptions(sProcess);
    % Process separately the three types of files
    switch (sInput.FileType)
        case 'pdata'
            % Load input stat file
            StatMat = in_bst_data(sInput.FileName, 'pmap', 'tmap', 'df', 'Comment', 'ChannelFlag', 'Time', 'History', 'ColormapType');
            sizeF = size(StatMat.tmap);
            % Load channel file
            ChannelMat = in_bst_channel(sInput.ChannelFile);
            % Get only relevant sensors as multiple tests
            iChannels = good_channel(ChannelMat.Channel, StatMat.ChannelFlag, {'MEG', 'EEG', 'SEEG', 'ECOG', 'NIRS'});
            if isfield(StatMat, 'pmap') && ~isempty(StatMat.pmap)
                StatMat.pmap = StatMat.pmap(iChannels,:,:);
            end
            if isfield(StatMat, 'tmap') && ~isempty(StatMat.tmap)
                StatMat.tmap = StatMat.tmap(iChannels,:,:);
            end
            % Create a new data file structure
            DataMat = db_template('datamat');
            DataMat.F            = zeros(sizeF);
            DataMat.F(iChannels,:,:) = Compute(StatMat, StatThreshOptions);
            DataMat.Comment      = [StatMat.Comment ' | ' strCorrect];
            DataMat.ChannelFlag  = StatMat.ChannelFlag;
            DataMat.Time         = StatMat.Time;
            DataMat.DataType     = 'tmap';
            DataMat.Device       = 'stat';
            DataMat.Events       = [];
            DataMat.History      = StatMat.History;
            DataMat.ColormapType = StatMat.ColormapType;
            
        case 'presults'
            % Load input stat file
            StatMat = in_bst_results(sInput.FileName, 0, 'pmap', 'tmap', 'df', 'Comment', 'ChannelFlag', 'Time', 'History', 'ColormapType', 'GoodChannel', 'SurfaceFile', 'Atlas', 'GridLoc', 'nComponents', 'HeadModelType', 'SPM');
            % New results structure
            DataMat = db_template('resultsmat');
            DataMat.ImageGridAmp  = Compute(StatMat, StatThreshOptions);
            DataMat.ImagingKernel = [];
            DataMat.Comment       = [StatMat.Comment ' | ' strCorrect];
            DataMat.Function      = 'pthresh';
            DataMat.Time          = StatMat.Time;
            DataMat.DataFile      = [];
            DataMat.HeadModelFile = [];
            DataMat.HeadModelType = StatMat.HeadModelType;
            DataMat.nComponents   = StatMat.nComponents;
            DataMat.GridLoc       = StatMat.GridLoc;
            DataMat.Atlas         = StatMat.Atlas;
            DataMat.SurfaceFile   = StatMat.SurfaceFile;
            DataMat.GoodChannel   = StatMat.GoodChannel;
            DataMat.ChannelFlag   = StatMat.ChannelFlag;
            DataMat.History       = StatMat.History;
            DataMat.ColormapType  = StatMat.ColormapType;
            
        case 'ptimefreq'
            % Load input stat file
            StatMat = in_bst_timefreq(sInput.FileName, 0,  'pmap', 'tmap', 'df', 'Type', 'Comment', 'ChannelFlag', 'Time', 'History', 'ColormapType', 'GoodChannel', 'SurfaceFile', 'Atlas', 'GridLoc', 'nComponents', 'HeadModelType', 'DataType', 'TimeBands', 'Freqs', 'RefRowNames', 'RowNames', 'Measure', 'Method', 'Options');
            % New results structure
            DataMat = db_template('timefreqmat');
            DataMat.TF            = Compute(StatMat, StatThreshOptions);
            DataMat.Comment       = [StatMat.Comment ' | ' strCorrect];
            DataMat.Options       = StatMat.Options;
            DataMat.Type          = StatMat.Type;
            DataMat.Time          = StatMat.Time;
            DataMat.ChannelFlag   = StatMat.ChannelFlag;
            DataMat.HeadModelType = StatMat.HeadModelType;
            DataMat.GridLoc       = StatMat.GridLoc;
            DataMat.GoodChannel   = StatMat.GoodChannel;
            DataMat.ColormapType  = StatMat.ColormapType;
            DataMat.DataFile      = [];
            DataMat.Atlas         = StatMat.Atlas;
            DataMat.History       = StatMat.History;
            DataMat.DataType      = StatMat.DataType;
            DataMat.SurfaceFile   = StatMat.SurfaceFile;
            DataMat.TimeBands     = StatMat.TimeBands;
            DataMat.Freqs         = StatMat.Freqs;
            DataMat.RefRowNames   = StatMat.RefRowNames;
            DataMat.RowNames      = StatMat.RowNames;
            DataMat.Measure       = StatMat.Measure;
            DataMat.Method        = StatMat.Method;
            DataMat.Options       = StatMat.Options;
            
        case 'pmatrix'
            % Load input stat file
            StatMat = in_bst_matrix(sInput.FileName, 'pmap', 'tmap', 'df', 'Comment', 'Description', 'Time', 'History');
            % Create a new data file structure
            DataMat = db_template('matrixmat');
            DataMat.Value       = Compute(StatMat, StatThreshOptions);
            DataMat.Comment     = [StatMat.Comment ' | ' strCorrect];
            DataMat.Description = StatMat.Description;
            DataMat.Time        = StatMat.Time;
            DataMat.ChannelFlag = [];
            DataMat.Events      = [];
            DataMat.Atlas       = [];
            DataMat.History     = StatMat.History;
    end
    
    % Add history entry
    DataMat = bst_history('add', DataMat, 'pthresh', ['Setting the stat threshold: ' strCorrect]);
    DataMat = bst_history('add', DataMat, 'pthresh', ['Original file: ' sInput.FileName]);
    % Output file tag
    fileTag = bst_process('GetFileTag', sInput.FileName);
    fileTag = [fileTag(2:end) '_pthresh'];
    % Output filename
    DataFile = bst_process('GetNewFilename', bst_fileparts(sInput.FileName), fileTag);
    % Save on disk
    bst_save(DataFile, DataMat, 'v6');
    % Register in database
    db_add_data(sInput.iStudy, DataFile, DataMat);
    % Return data file
    OutputFiles{1} = DataFile;
end


%% ===== APPLY THRESHOLD =====
function [threshmap, tThreshUnder, tThreshOver] = Compute(StatMat, StatThreshOptions)
    % If options not provided, read them from the interface
    if (nargin < 2) || isempty(StatThreshOptions)
        StatThreshOptions = bst_get('StatThreshOptions');
    end
    % Check if matrix is already corrected
    if ~strcmpi(StatThreshOptions.Correction, 'no') && isfield(StatMat, 'Correction') && ~isempty(StatMat.Correction) && ~strcmpi(StatMat.Correction, 'no')
        % disp('BST> Statistics maps are already corrected for multiple comparisons.');
        StatThreshOptions.Correction = 'no';
    end
    tThreshOver = [];
    tThreshUnder = [];
    testSide = '';
    % Connectivity matrices: remove diagonal
    if isfield(StatMat, 'RefRowNames') && (length(StatMat.RefRowNames) > 1)
        StatMat.tmap = process_compress_sym('RemoveDiagonal', StatMat.tmap, length(StatMat.RowNames));
        if isfield(StatMat, 'pmap') && ~isempty(StatMat.pmap)
            StatMat.pmap = process_compress_sym('RemoveDiagonal', StatMat.pmap, length(StatMat.RowNames));
        end
        if isfield(StatMat, 'df') && ~isempty(StatMat.df)
            StatMat.df = process_compress_sym('RemoveDiagonal', StatMat.df, length(StatMat.RowNames));
        end
    end
    % Get or calculate p-values map
    if isfield(StatMat, 'pmap') && ~isempty(StatMat.pmap)
        pmap = StatMat.pmap;
        % Correction for multiple comparisons
        [pmask, pthresh] = bst_stat_thresh(pmap, StatThreshOptions);
    elseif isfield(StatMat, 'df') && ~isempty(StatMat.df)
        pmap = process_test_parametric2('ComputePvalues', StatMat.tmap, StatMat.df, 't', 'two');
        % Correction for multiple comparisons
        [pmask, pthresh] = bst_stat_thresh(pmap, StatThreshOptions);
    elseif isfield(StatMat, 'SPM') && ~isempty(StatMat.SPM)
        % Initialize SPM
        bst_spm_init();
        % SPM must be installed
        if ~exist('spm_uc', 'file')
            warning('SPM must be in the Matlab path to compute the statistical thresold for this file.');
            pmask = ones(size(StatMat.tmap));
        else
            % Compute threshold for statistical map
            df = [StatMat.SPM.xCon(1).eidf, StatMat.SPM.xX.erdf];
            S = StatMat.SPM.xVol.S;    %-search Volume {voxels}
            R = StatMat.SPM.xVol.R;    %-search Volume {resels}
            % Correction
            switch (StatThreshOptions.Correction)
                % Note: always one-sided t-test, really the case?
                case {'none', 'no'}
                    tThreshOver = spm_u(StatThreshOptions.pThreshold, df, 'T');
                case 'bonferroni'
                    tThreshOver = spm_uc_Bonf(StatThreshOptions.pThreshold, df, 'T', S, 1);
                case 'fdr'
                    tThreshOver = spm_uc(StatThreshOptions.pThreshold, df, 'T', R, 1, S);
            end
            % Activated voxels
            pmask = (StatMat.tmap >= tThreshOver);
            tThreshUnder = [];
        end
    else
        error('Missing information to apply a statistical threshold.');
    end
    % Compute pseudo-recordings file : Threshold tmap with pmask
    threshmap = zeros(size(StatMat.tmap));
    % Apply duration threshold if applicable
    if isfield(StatThreshOptions, 'durThreshold') && (StatThreshOptions.durThreshold > 0) && isfield(StatMat, 'Time') && (length(StatMat.Time) > 2)
        if (size(pmask,3) >= 2)
            disp('Warning: Duration threshold is not supported for time-frequency results at the moment.');
        else
            pmask = filter_timewin_signif(pmask, StatThreshOptions.durThreshold / (StatMat.Time(2)-StatMat.Time(1)));
        end
    end
    % Return significant values
    threshmap(pmask) = StatMat.tmap(pmask);
    
    % Connectivity matrices: add diagonal back
    if isfield(StatMat, 'RefRowNames') && (length(StatMat.RefRowNames) > 1)
        threshmap = process_compress_sym('AddDiagonal', threshmap, length(StatMat.RowNames));
    end
    
    % Only for t-test: get min and max threshold values for adjusting the colormapping
    if isfield(StatMat, 'DisplayUnits') && ~isempty(StatMat.DisplayUnits) && strcmpi(StatMat.DisplayUnits, 't')
        % Detect lower and higher t-value thresholds
        allTval = threshmap(:);
        if isempty(StatMat.df) || length(setdiff(unique(StatMat.df), 0)) > 1 % df is not constant -> no unique theoretical t_threshold
            % Use lowest and highest non-zero t_values as thresholds
            tThreshUnder = getMaxNonZeroNegative(allTval);
            tThreshOver = getMinNonZeroPositive(allTval);
        elseif isempty(tThreshUnder) && isempty(tThreshUnder) 

            df = max(StatMat.df(:));
            [t_tmp, i_t_tmp] = getMinNonZeroPositive(abs(allTval)); %#ok<ASGLU>
            t_tmp = allTval(i_t_tmp);
            if ~isempty(t_tmp) % There is at least one non-zero t value
                tol = 1e-10;
                if pmap(i_t_tmp) < 1e-8
                    tol = eps;
                end
                if isempty(testSide)
                    if (abs(pmap(i_t_tmp) - process_test_parametric2('ComputePvalues', t_tmp, df, 't', 'two')) < tol)
                        testSide = 'two';
                    elseif (t_tmp > 0) && (abs(pmap(i_t_tmp) - process_test_parametric2('ComputePvalues', t_tmp, df, 't', 'one+')) < tol)
                        testSide = 'one+';
                    elseif abs(pmap(i_t_tmp) - process_test_parametric2('ComputePvalues', t_tmp, StatMat.df(i_t_tmp), 't', 'one-')) < tol
                        testSide = 'one-';
                    else
                        testSide = '';
                    end
                end
            end
            meanPthresh = mean(pthresh(:));
            switch(testSide)
                case 'one-'
                    tThreshUnder = fzero(@(t) 0.5 .* ( 1 + sign(t) .* betainc( t.^2 ./ (df + t.^2), 0.5, 0.5.*df ) ) - meanPthresh, 0);
                    tThreshOver = [];
                case 'two'
                    t_thresh = fzero(@(t) betainc( df ./ (df + t .^ 2), df./2, 0.5) - meanPthresh, 0);
                    if t_thresh < 0
                        tThreshUnder = t_thresh;
                        tThreshOver = -t_thresh;
                    else
                        tThreshUnder = -t_thresh;
                        tThreshOver = t_thresh;
                    end
                case 'one+'
                    tThreshOver = fzero(@(t) 0.5 .* ( 1 - sign(t) .* betainc( t.^2 ./ (df + t.^2), 0.5, 0.5.*df ) ) - meanPthresh, 0);
                    tThreshUnder = [];
                otherwise
                    warning('Cannot determine t-test side');
                    tThreshUnder = [];
                    tThreshOver = [];                
            end   
        end
    end
end

function [minOver, iMinOver] = getMinNonZeroPositive(values)
values(values<=0) = Inf;
[minOver, iMinOver] = min(values);
if isinf(minOver)
    minOver = [];
    iMinOver = [];
end
end

function [maxUnder, iMaxUnder] = getMaxNonZeroNegative(values)
values(values>=0) = -Inf;
[maxUnder, iMaxUnder] = max(values);
if isinf(maxUnder)
    maxUnder = [];
    iMaxUnder = [];
end
end
